# Reliability Design Review: TravelHub システム設計書

## Phase 1: Structural Analysis

### System Components
1. **Frontend Layer**: Mobile (React Native), Web (React/Next.js)
2. **API Gateway**: Spring Cloud Gateway
3. **Backend Services**:
   - Booking Service (search, inventory, reservation coordination)
   - Payment Service (Stripe/PayPal integration)
   - Itinerary Service (trip management, flight monitoring)
   - Notification Service (email, push, SMS, WebSocket)
4. **Data Stores**:
   - PostgreSQL (bookings, users, payments, itineraries)
   - MongoDB (search cache)
   - Redis (sessions, rate limiting)
   - Kafka (event-driven messaging)
5. **External Dependencies** (Critical):
   - Amadeus Flight API (search, booking, status monitoring)
   - Expedia Hotel API
   - Car rental provider APIs
   - Stripe API / PayPal API
   - SendGrid, Firebase Cloud Messaging, Twilio, Socket.IO

### Data Flow Paths
1. **Booking Flow**: User search → Booking Service → parallel external API calls → MongoDB cache → tentative booking (PostgreSQL PENDING) → Payment Service → Stripe → callback → PostgreSQL CONFIRMED → Kafka event → Itinerary Service → Notification
2. **Flight Delay Response**: Background job (5-minute polling) → Amadeus Flight Status API → delay detection → Kafka event → Itinerary Service → alternative flight search → Notification

### State Transitions
- Booking states: PENDING → CONFIRMED / CANCELLED
- Payment states: PENDING → COMPLETED / FAILED / REFUNDED
- Booking item states: ACTIVE → CANCELLED / MODIFIED
- Itinerary states: ACTIVE → COMPLETED / DISRUPTED

### Explicitly Mentioned Reliability Mechanisms
- Resilience4j circuit breaker for external API failures
- Spring Retry capability
- Blue-Green deployment with ALB target group switching
- RDS Multi-AZ with automatic failover (within 60 seconds)
- ElastiCache 3-node cluster mode
- Auto scaling (3-20 ECS tasks based on CPU 70%)
- Structured logging with correlation_id
- CloudWatch metrics and PagerDuty alerting

---

## Phase 2: Problem Detection

### TIER 1: CRITICAL ISSUES (System-Wide Impact)

#### C1. Missing Distributed Transaction Coordination for Multi-Provider Bookings
**Reference**: Section 3 (Data Flow), Section 4 (Data Model), Section 5 (API Design - POST /api/v1/bookings)

**Problem**:
The design describes a multi-step booking flow involving external provider APIs (airlines, hotels, car rentals) followed by payment processing, but lacks explicit distributed transaction coordination. The booking flow is:
1. External provider APIs create tentative reservations
2. PostgreSQL writes PENDING state
3. Payment Service processes payment
4. On success, Booking Service updates PostgreSQL to CONFIRMED

**Failure Scenario**:
If payment succeeds (Stripe confirms) but the Booking Service callback fails (network partition, service crash, database unavailable), the system enters an inconsistent state:
- Stripe has charged the customer
- External providers hold tentative reservations
- PostgreSQL still shows PENDING status
- No Kafka event is published, so Itinerary Service never creates the trip record
- Customer receives no confirmation email

This creates **data loss** (confirmed booking not recorded) and **financial inconsistency** (charged but no confirmed booking).

**Operational Impact**:
- Manual reconciliation required between Stripe transactions and booking records
- Customer complaints due to charged payments without confirmations
- Support team burden to manually verify and recreate bookings
- Potential refund processing without actual cancellation at provider side

**Countermeasures**:
1. **Implement Saga Pattern with Compensation**: Design a booking saga coordinator that orchestrates the multi-step transaction:
   - Step 1: Create tentative booking at providers (compensate: cancel provider bookings)
   - Step 2: Process payment (compensate: refund payment)
   - Step 3: Confirm booking in PostgreSQL (compensate: mark as CANCELLED)
   - Step 4: Publish Kafka event (compensate: publish cancellation event)

2. **Use Transactional Outbox Pattern**: When updating booking status to CONFIRMED, write both the state update and Kafka event to PostgreSQL in the same transaction, then use a separate outbox publisher to guarantee event delivery.

3. **Add Booking State Recovery Job**: Implement a scheduled job to detect orphaned states:
   - Query Stripe for completed payments without corresponding CONFIRMED bookings
   - Query PostgreSQL for PENDING bookings older than 30 minutes
   - Reconcile and either complete or cancel the booking with compensation

4. **Implement Idempotency Keys**: Ensure all operations are idempotent with stored idempotency keys (Stripe provides this; extend to provider APIs if supported).

---

#### C2. No Idempotency Guarantees for Booking Confirmation
**Reference**: Section 5 (POST /api/v1/bookings/{id}/confirm), Section 3 (Data Flow)

**Problem**:
The design states "Payment Service が決済成功後に内部呼び出し" (Payment Service calls internally after payment success), but does not specify idempotency handling. If the Payment Service callback to `POST /api/v1/bookings/{id}/confirm` retries due to network timeout or 5xx error, the confirmation may be processed multiple times.

**Failure Scenario**:
1. Payment succeeds at Stripe
2. Payment Service calls `POST /api/v1/bookings/{id}/confirm`
3. Booking Service updates PostgreSQL and publishes Kafka event
4. Response times out before Payment Service receives it
5. Payment Service retries the confirmation call
6. Duplicate Kafka `BookingConfirmed` event is published
7. Itinerary Service consumes the event twice → two itinerary records created
8. Notification Service sends duplicate confirmation emails

**Operational Impact**:
- Duplicate itineraries confuse users and support teams
- Duplicate notifications erode trust and trigger spam complaints
- Database integrity issues with multiple itinerary records per booking

**Countermeasures**:
1. **Add Idempotency Key Header**: Require `Idempotency-Key` header on `POST /api/v1/bookings/{id}/confirm`. Store processed keys in Redis (24-hour TTL) or PostgreSQL. Return cached response if duplicate key is detected.

2. **Database-Level Idempotency Check**: Use PostgreSQL unique constraint on `(booking_id, confirmed_at)` or add a `confirmation_token` column with unique constraint. Catch constraint violations and return success (already confirmed).

3. **Kafka Event Deduplication**: Include idempotency key in Kafka event payload. Consumers should check for duplicate events before processing (using Redis cache or database query).

---

#### C3. Missing Timeout and Circuit Breaker Configuration for External Provider APIs
**Reference**: Section 3 (Booking Service dependencies), Section 6 (Error Handling - "Resilience4j サーキットブレーカー")

**Problem**:
While the design mentions Resilience4j circuit breaker for external API failures, it does not specify:
- Timeout values for each external provider API (Amadeus, Expedia, car rental APIs)
- Circuit breaker thresholds (failure rate, slow call rate, wait duration)
- Fallback behavior when circuit is open

The search API has a 30-second timeout (Section 5), but individual provider call timeouts are not defined. Without proper timeouts, a single slow provider can block threads and cascade to service-wide unavailability.

**Failure Scenario**:
1. Amadeus Flight API experiences degradation (responds in 25 seconds instead of 2 seconds)
2. Search requests accumulate, blocking Booking Service threads
3. Thread pool exhaustion prevents processing of hotel/car search requests
4. All search functionality becomes unavailable despite other providers being healthy
5. Users perceive complete system outage

**Operational Impact**:
- **Cascading failure**: Slow external dependency impacts unrelated functionality
- **Thread exhaustion**: Service becomes unresponsive even to health checks
- **Difficult recovery**: Requires service restart, not automatic recovery
- **Extended outage**: Circuit breaker won't open if calls eventually succeed (just slowly)

**Countermeasures**:
1. **Define Per-Provider Timeouts**: Set aggressive timeouts for each external API (e.g., 3 seconds for search, 5 seconds for booking). Document in configuration:
   ```yaml
   resilience4j:
     timelimiter:
       instances:
         amadeusFlightSearch:
           timeoutDuration: 3s
         expediaHotelSearch:
           timeoutDuration: 3s
   ```

2. **Configure Circuit Breaker Thresholds**:
   ```yaml
   resilience4j:
     circuitbreaker:
       instances:
         amadeusFlightApi:
           failureRateThreshold: 50
           slowCallRateThreshold: 50
           slowCallDurationThreshold: 2s
           waitDurationInOpenState: 30s
   ```

3. **Implement Bulkhead Isolation**: Use separate thread pools for each provider to prevent one slow provider from exhausting all threads:
   ```yaml
   resilience4j:
     bulkhead:
       instances:
         amadeusFlightApi:
           maxConcurrentCalls: 10
   ```

4. **Define Graceful Degradation**: When circuit is open, return cached results (from MongoDB) with staleness warning, or exclude the unavailable provider from search results rather than failing the entire search.

---

#### C4. Payment Service Callback Failure Leaves Unrecoverable Inconsistency
**Reference**: Section 3 (Booking flow), Section 4 (payments table)

**Problem**:
The payment flow relies on synchronous callback from Stripe to Payment Service, then from Payment Service to Booking Service. If the Booking Service is unavailable when Payment Service attempts to call `POST /api/v1/bookings/{id}/confirm`, the payment is marked COMPLETED in the payments table but the booking remains PENDING forever.

The design mentions "予約状態をPENDINGのまま保持（30分後に自動キャンセル）" for payment failures, but does not address the inverse case: payment succeeds but booking confirmation fails.

**Failure Scenario**:
1. User initiates payment for booking_id=123
2. Stripe successfully charges customer ($500)
3. Payment Service writes payment record with status=COMPLETED
4. Payment Service attempts to call Booking Service to confirm booking
5. Booking Service is down (deployment in progress, crash, network partition)
6. Payment Service retries fail (no retry policy specified in design)
7. 30 minutes elapse → booking auto-cancelled due to PENDING timeout
8. Customer charged $500 but booking is cancelled

**Operational Impact**:
- **Financial loss**: Customer charged without service provided
- **Compliance risk**: PCI DSS and consumer protection regulations require accurate charge-to-service mapping
- **High refund rate**: Manual investigation and refund processing required
- **Unrecoverable state**: Without explicit reconciliation, these orphaned payments may never be detected

**Countermeasures**:
1. **Implement Asynchronous Event-Driven Confirmation**: Instead of synchronous callback, Payment Service should publish `PaymentCompleted` event to Kafka after Stripe success. Booking Service consumes the event and updates booking status. This decouples services and provides natural retry via Kafka.

2. **Add Payment-to-Booking Reconciliation Job**: Scheduled job (every 5 minutes) to detect:
   - Payments with status=COMPLETED where booking status != CONFIRMED
   - Automatically trigger booking confirmation or alert for manual review
   - Query Stripe API to verify payment actually succeeded (avoid acting on stale database state)

3. **Implement Webhook Fallback**: Register Stripe webhook for `payment_intent.succeeded` event as backup. If callback fails, webhook delivery (with automatic Stripe retry) ensures eventual consistency.

4. **Add Payment Hold-to-Capture Pattern**: Instead of immediate charge, use Stripe payment authorization (hold) during booking creation, then capture only after successful booking confirmation. This prevents charging customers for unconfirmed bookings.

---

#### C5. Missing RPO/RTO Definition and Backup Testing for PostgreSQL
**Reference**: Section 7 (Availability), Tier 1 Checklist (Data Integrity - Backup and restore procedures with tested recovery paths, RPO/RTO definitions and validation)

**Problem**:
The design specifies "RDS Multi-AZ 構成、自動フェイルオーバー（60秒以内）" for availability but does not define:
- Recovery Point Objective (RPO): Maximum acceptable data loss duration
- Recovery Time Objective (RTO): Maximum acceptable downtime
- Backup frequency and retention policy
- Restore testing procedures

Without tested recovery procedures, the system cannot guarantee data recovery in disaster scenarios (region-wide outage, data corruption, accidental deletion).

**Failure Scenario**:
1. Database corruption occurs due to application bug (e.g., batch job deletes all bookings due to SQL logic error)
2. Corruption is detected 2 hours later
3. Team attempts to restore from RDS automated backup
4. Discover that backups are not tested → restoration fails due to missing configuration
5. Or: Backup succeeds but loses 2 hours of booking data (thousands of transactions)
6. No documented procedure for notifying affected customers or reconstructing lost bookings

**Operational Impact**:
- **Catastrophic data loss**: Bookings, payments, itineraries permanently lost
- **Legal liability**: Financial transactions lost without audit trail
- **Business continuity failure**: Cannot recover to operational state within SLA
- **Reputational damage**: Customers lose trust after data loss incident

**Countermeasures**:
1. **Define RPO/RTO Targets**:
   - RPO: 5 minutes (maximum acceptable data loss)
   - RTO: 1 hour (maximum acceptable recovery time)
   - Document in disaster recovery plan

2. **Configure RDS Automated Backups**:
   - Enable automated daily backups with 7-day retention
   - Enable point-in-time recovery (PITR) to meet 5-minute RPO
   - Configure backup window during low-traffic period (e.g., 03:00-04:00 JST)

3. **Implement Cross-Region Backup Replication**:
   - Use RDS snapshot copy to secondary region (e.g., us-west-2 as backup for ap-northeast-1)
   - Protects against region-wide outages

4. **Establish Quarterly Restore Testing**:
   - Schedule quarterly disaster recovery drills
   - Restore RDS snapshot to non-production environment
   - Validate data integrity (row counts, key transaction checks)
   - Measure actual recovery time and compare to RTO
   - Document restoration procedure in runbook

5. **Implement Logical Backup for Critical Tables**:
   - Daily pg_dump of bookings, payments, itineraries tables
   - Store in S3 with versioning enabled
   - Provides defense against logical corruption (vs. physical backup)

---

#### C6. No Conflict Resolution Strategy for Concurrent Booking Modifications
**Reference**: Section 1 (Feature 6 - "マルチベンダー予約の一括キャンセル・変更"), Section 3 (Itinerary Service - "関連予約の整合性チェック")

**Problem**:
The design mentions "関連予約の整合性チェック" but does not specify conflict resolution when concurrent modifications occur. Examples:
- User manually changes hotel check-in date via UI
- Simultaneously, Itinerary Service auto-adjusts hotel due to flight delay
- Both attempt to update the same booking_item record

Without optimistic locking or conflict detection, last-write-wins behavior causes silent data loss.

**Failure Scenario**:
1. User's original itinerary: Flight NRT→CDG on June 1, Hotel check-in June 1
2. Flight is delayed to June 2 (morning notification)
3. User opens UI at 09:00, sees June 1 flight, decides to cancel hotel
4. At 09:01, background job detects delay, auto-updates hotel to June 2
5. At 09:02, user clicks "Cancel Hotel" (still seeing stale June 1 data)
6. User's cancellation overwrites the auto-adjustment
7. User arrives June 2 without hotel reservation (auto-adjustment lost)

**Operational Impact**:
- **Silent data corruption**: User actions overwrite automated adjustments without warning
- **Degraded customer experience**: Users arrive at hotels without valid reservations
- **Support escalation**: Complex debugging to understand what happened

**Countermeasures**:
1. **Implement Optimistic Locking**: Add `version` column to booking_items table:
   ```sql
   ALTER TABLE booking_items ADD COLUMN version INTEGER NOT NULL DEFAULT 0;
   ```
   Update queries must include version check:
   ```sql
   UPDATE booking_items
   SET status = 'CANCELLED', version = version + 1
   WHERE id = ? AND version = ?
   ```
   If no rows are updated, throw `OptimisticLockException` and return 409 Conflict to client.

2. **Define Conflict Resolution Policy**:
   - User modifications always take precedence over automated adjustments
   - When conflict is detected, notify user: "This booking was automatically modified. Please review and resubmit."
   - Provide option to view change history

3. **Implement Event Sourcing for Critical State Transitions**: Store all booking modification events (UserCancelled, AutoAdjustedDueToDelay) in append-only event log. Reconstruct current state from events, making conflicts detectable and resolvable.

4. **Use Distributed Locks for Multi-Item Updates**: When updating multiple related booking_items (e.g., cascading flight → hotel → car changes), acquire Redis distributed lock on booking_id to prevent concurrent modifications.

---

### TIER 2: SIGNIFICANT ISSUES (Partial System Impact)

#### S1. Missing Dead Letter Queue for Kafka Event Processing Failures
**Reference**: Section 3 (Data Flow - Kafka event consumption), Section 2 (Apache Kafka 3.6)

**Problem**:
The design uses Kafka for event-driven communication (BookingConfirmed, FlightDelayed events) but does not specify dead letter queue (DLQ) handling for unprocessable messages. If Itinerary Service encounters a poison message or persistent processing error, the consumer may:
- Endlessly retry the same message, blocking the queue
- Skip the message silently, causing data loss
- Crash repeatedly, requiring manual intervention

**Failure Scenario**:
1. Booking Service publishes malformed `BookingConfirmed` event due to bug (missing required field)
2. Itinerary Service attempts to consume event → deserialization fails
3. Consumer retries indefinitely (default Kafka behavior)
4. All subsequent events in the partition are blocked
5. New bookings are confirmed but itineraries are never created
6. Customers receive payment confirmation but no trip details

**Operational Impact**:
- **Queue blockage**: All events in affected partition are delayed
- **Cascading delay**: Notification emails are not sent, customer dashboard shows no trips
- **Manual intervention required**: On-call engineer must identify poison message and manually skip offset

**Countermeasures**:
1. **Configure Kafka Dead Letter Topic**: Create DLT for each topic:
   - `booking-events` → `booking-events-dlt`
   - `flight-delay-events` → `flight-delay-events-dlt`

2. **Implement Retry-with-Backoff and DLT Forwarding**:
   ```java
   @KafkaListener(topics = "booking-events")
   public void handleBookingEvent(ConsumerRecord<String, BookingEvent> record) {
       try {
           processEvent(record.value());
       } catch (RecoverableException e) {
           // Retry with exponential backoff (max 3 attempts)
           throw e; // Let Spring Kafka retry
       } catch (NonRecoverableException e) {
           // Send to DLT immediately
           kafkaTemplate.send("booking-events-dlt", record);
           logger.error("Unprocessable event sent to DLT", e);
       }
   }
   ```

3. **Monitor DLT and Alert**: Set up CloudWatch alarm when DLT receives messages → trigger PagerDuty alert for investigation.

4. **Implement DLT Replay Mechanism**: After fixing the root cause, provide admin API or script to replay messages from DLT back to main topic for reprocessing.

---

#### S2. No Rate Limiting for External Provider API Calls
**Reference**: Section 3 (Booking Service - external API dependencies), Section 7 (SLA - 99.9% uptime)

**Problem**:
The design mentions Redis for rate limiting (Section 2) but does not specify:
- Rate limits for outbound calls to external provider APIs
- Quota tracking to avoid exceeding provider limits
- Backpressure mechanism when approaching quota

External APIs typically have rate limits (e.g., 100 requests/minute). Without quota tracking, TravelHub may:
- Exceed provider limits → API key banned → all searches/bookings fail
- Cause provider-side throttling → cascading failures

**Failure Scenario**:
1. Marketing campaign drives 10x traffic spike
2. Search API receives 1000 requests/minute
3. Booking Service makes parallel calls to Amadeus (1000 flights + 1000 hotels = 2000 requests/minute)
4. Exceeds Amadeus rate limit (500 requests/minute)
5. Amadeus returns 429 Too Many Requests → bans API key for 1 hour
6. All flight searches fail for 1 hour → violates 99.9% SLA

**Operational Impact**:
- **Service degradation**: Core functionality (search, booking) becomes unavailable
- **SLA breach**: 1-hour outage exceeds monthly budget (43 minutes)
- **Revenue loss**: Customers cannot complete bookings during high-traffic period

**Countermeasures**:
1. **Implement Token Bucket Rate Limiter for Each Provider**:
   ```java
   @Service
   public class AmadeusApiClient {
       private final RateLimiter rateLimiter = RateLimiter.create(8.0); // 480 requests/minute

       public FlightSearchResponse search(FlightSearchRequest request) {
           rateLimiter.acquire(); // Block until token available
           return restTemplate.postForObject(url, request, FlightSearchResponse.class);
       }
   }
   ```

2. **Track Quota Usage in Redis**:
   - Increment counter on each API call: `INCR amadeus:quota:2026-02-11:14:00`
   - Set TTL to 1 minute: `EXPIRE amadeus:quota:2026-02-11:14:00 60`
   - Check before calling API: if count > threshold (e.g., 450), apply backpressure

3. **Implement Backpressure Strategy**:
   - Return cached results from MongoDB if quota is exhausted
   - Return HTTP 503 Service Unavailable with `Retry-After` header to client
   - Show UI message: "High demand - using cached results from 5 minutes ago"

4. **Monitor Quota Usage and Alert**: Track quota utilization (e.g., 80% of limit) → CloudWatch alarm → Slack notification to operations team.

---

#### S3. Missing Health Check Validation for External Dependencies
**Reference**: Section 7 (Availability), Tier 2 Checklist (Health checks at multiple levels)

**Problem**:
The design does not specify health check endpoints or dependency health validation. ECS Auto Scaling and ALB target group health checks likely only verify that the service process is alive, not that critical dependencies (PostgreSQL, Kafka, external APIs) are reachable.

**Failure Scenario**:
1. RDS Multi-AZ failover occurs (60-second outage)
2. Booking Service health check continues to return 200 OK (process is alive)
3. ALB routes traffic to unhealthy instances
4. All booking requests fail with database connection errors
5. Users see 500 Internal Server Error
6. Auto-scaling doesn't trigger because health checks pass

**Operational Impact**:
- **Traffic routing to unhealthy instances**: ALB sends requests to services that cannot process them
- **User-facing errors**: Customers see errors instead of graceful degradation
- **Delayed incident detection**: Monitoring alerts only after error rate exceeds threshold (5%)

**Countermeasures**:
1. **Implement Comprehensive Health Check Endpoint**:
   ```java
   @GetMapping("/actuator/health")
   public ResponseEntity<HealthStatus> health() {
       boolean dbHealthy = checkDatabaseConnection();
       boolean kafkaHealthy = checkKafkaConnection();
       boolean redisHealthy = checkRedisConnection();

       if (!dbHealthy || !kafkaHealthy || !redisHealthy) {
           return ResponseEntity.status(503).body(new HealthStatus("UNHEALTHY"));
       }
       return ResponseEntity.ok(new HealthStatus("HEALTHY"));
   }
   ```

2. **Configure Shallow and Deep Health Checks**:
   - Shallow check (every 5 seconds): Process liveness only (fast, for ALB)
   - Deep check (every 30 seconds): Database query, Kafka metadata fetch, Redis ping (for monitoring)

3. **Define Dependency Health Thresholds**:
   - Critical dependencies (PostgreSQL, Kafka): Failure → health check fails immediately
   - Non-critical dependencies (MongoDB cache): Failure → log warning but health check passes (graceful degradation)

4. **Implement Circuit Breaker-Aware Health**: If Amadeus circuit breaker is OPEN, return 503 to prevent accepting search requests that will fail anyway.

---

#### S4. No Exponential Backoff for Amadeus Flight Status Polling
**Reference**: Section 3 (Flight Delay Response - "バックグラウンドジョブ（5分間隔）がAmadeus Flight Status APIをポーリング")

**Problem**:
The design specifies fixed 5-minute polling interval for flight status. This approach:
- Wastes API quota when flight is on-time (no changes expected)
- Delays detection when flight is already delayed (should poll more frequently)
- Does not adapt to Amadeus rate limits or API degradation

**Failure Scenario**:
1. System monitors 10,000 active flights (next 24 hours)
2. Fixed 5-minute polling = 2,000 API calls/hour to Amadeus
3. Amadeus rate limit is 1,000 calls/hour
4. Polling job fails with 429 Too Many Requests
5. All flight delay detection stops
6. Customers are not notified of delays

**Operational Impact**:
- **Rate limit exhaustion**: Polling consumes all quota, preventing on-demand status checks
- **Delayed notifications**: 5-minute interval means users may not receive timely delay alerts
- **Scaling limitations**: Cannot support more than 2,000 flights without hitting limits

**Countermeasures**:
1. **Implement Adaptive Polling Strategy**:
   - On-time flights (departure > 4 hours away): Poll every 30 minutes
   - Approaching departure (1-4 hours): Poll every 10 minutes
   - Near departure (< 1 hour): Poll every 2 minutes
   - Already delayed: Poll every 5 minutes until updated

2. **Use Amadeus Push Notifications**: Check if Amadeus offers webhook/push API for flight status updates instead of polling. This eliminates polling overhead entirely.

3. **Implement Exponential Backoff on API Errors**:
   ```java
   int backoffSeconds = 60;
   while (true) {
       try {
           checkFlightStatus();
           backoffSeconds = 60; // Reset on success
       } catch (RateLimitException e) {
           logger.warn("Rate limited, backing off for {} seconds", backoffSeconds);
           Thread.sleep(backoffSeconds * 1000);
           backoffSeconds = Math.min(backoffSeconds * 2, 3600); // Max 1 hour
       }
   }
   ```

4. **Prioritize Critical Flights**: Poll flights with higher business impact first (e.g., flights departing within 2 hours, premium customers) to ensure critical notifications are not delayed by quota limits.

---

#### S5. Missing Database Connection Pool Timeout and Retry Configuration
**Reference**: Section 7 (Performance - "PostgreSQL接続プール最大100接続、コネクションタイムアウト10秒")

**Problem**:
The design specifies connection pool size (100) and timeout (10 seconds) but does not address:
- What happens when all 100 connections are exhausted
- Retry behavior when connection acquisition times out
- Connection validation (to detect stale connections after RDS failover)

**Failure Scenario**:
1. Traffic spike causes all 100 connections to be in use
2. New request attempts to acquire connection
3. Waits 10 seconds → timeout → throws exception
4. Application returns 500 Internal Server Error to user
5. User retries → same failure
6. No automatic recovery mechanism

**Operational Impact**:
- **User-facing errors**: Customers see transient failures during high load
- **Cascading failures**: Slow queries hold connections longer → exhausts pool faster
- **Extended outage after RDS failover**: Stale connections are not detected until used → first 100 requests after failover fail

**Countermeasures**:
1. **Configure Connection Pool with Validation and Retry**:
   ```yaml
   spring:
     datasource:
       hikari:
         maximum-pool-size: 100
         connection-timeout: 10000
         validation-timeout: 5000
         leak-detection-threshold: 30000
         connection-test-query: SELECT 1
         minimum-idle: 10
   ```

2. **Implement Connection Acquisition Retry with Backoff**:
   ```java
   @Retryable(
       value = {CannotGetJdbcConnectionException.class},
       maxAttempts = 3,
       backoff = @Backoff(delay = 100, multiplier = 2)
   )
   public Booking createBooking(BookingRequest request) {
       return bookingRepository.save(new Booking(request));
   }
   ```

3. **Add Connection Pool Monitoring and Alerting**:
   - Expose Hikari metrics: `hikaricp.connections.active`, `hikaricp.connections.pending`
   - Alert when pending connections > 10 for 1 minute (pool exhaustion warning)

4. **Implement Circuit Breaker for Database Calls**:
   - If connection timeouts exceed 50% for 10 seconds, open circuit to prevent thread exhaustion
   - Return cached data or 503 instead of blocking all threads

---

#### S6. No Rollback Testing for Database Migrations
**Reference**: Section 6 (Deployment - "Flyway による自動適用、本番デプロイ前にステージング環境で検証")

**Problem**:
The design specifies forward migration testing (staging → production) but does not mention rollback testing. Flyway supports rollback (paid version) or manual down-migration scripts, but without testing, rollbacks during incidents may fail.

**Failure Scenario**:
1. Deploy new version with database migration (add column to bookings table)
2. Application has critical bug → need to rollback within 10 minutes (SLA requirement)
3. Attempt to rollback application to previous version
4. Previous version's code does not recognize new database column → fails to start
5. Database schema rollback script was never tested → script has syntax error
6. System is stuck between versions → extended outage

**Operational Impact**:
- **Extended downtime**: Cannot roll back application without rolling back database
- **Data loss risk**: Attempting untested schema rollback may corrupt data
- **Panic-driven decisions**: On-call engineer must debug migration scripts under pressure

**Countermeasures**:
1. **Implement Expand-Contract Migration Pattern**:
   - Phase 1 (Deploy N): Add new column (nullable), deploy code that writes to both old and new columns
   - Phase 2 (Deploy N+1): Migrate data from old to new column
   - Phase 3 (Deploy N+2): Remove old column
   - Each phase can be rolled back independently

2. **Require Rollback Scripts for All Migrations**:
   - For each `V001__add_booking_status.sql`, create `U001__remove_booking_status.sql`
   - Store rollback scripts in version control alongside forward migrations

3. **Test Rollback in Staging**:
   - After forward migration succeeds in staging, immediately test rollback
   - Verify application starts and functions correctly after rollback
   - Include rollback testing in deployment checklist

4. **Document Rollback Procedure in Runbook**:
   - Step-by-step instructions for rolling back application and database
   - Include SQL commands, Flyway commands, and verification steps
   - Practice quarterly disaster recovery drills

---

### TIER 3: MODERATE ISSUES (Operational Improvement)

#### M1. Missing Distributed Tracing Implementation
**Reference**: Section 6 (Logging - "correlation_id（トレース用UUID）を全ログに付与"), Tier 3 Checklist (Distributed tracing for debugging production issues)

**Problem**:
The design mentions correlation_id for log correlation but does not specify distributed tracing implementation. In a microservice architecture with 4+ services and external dependencies, debugging production issues (slow requests, failures) requires tracing across service boundaries.

**Countermeasures**:
1. **Integrate AWS X-Ray or OpenTelemetry**:
   - Instrument all HTTP clients, Kafka producers/consumers, database calls
   - Propagate trace context across service boundaries (via HTTP headers, Kafka headers)

2. **Define Key Traces**:
   - End-to-end booking flow (search → booking → payment → confirmation)
   - Flight delay detection → notification pipeline
   - Measure latency at each hop to identify bottlenecks

3. **Set Trace Sampling Rate**: Use adaptive sampling (100% for errors, 10% for successful requests) to balance observability and cost.

---

#### M2. Missing RED Metrics for Critical Endpoints
**Reference**: Section 7 (Monitoring), Tier 3 Checklist (RED metrics for key endpoints)

**Problem**:
The design specifies SLO for API availability and latency but does not mention RED metrics (Request rate, Error rate, Duration) at endpoint granularity. Without per-endpoint metrics, diagnosing which API is degrading is difficult.

**Countermeasures**:
1. **Expose Micrometer Metrics for Each Endpoint**:
   ```java
   @Timed(value = "api.bookings.create", histogram = true)
   @PostMapping("/api/v1/bookings")
   public ResponseEntity<Booking> createBooking(@RequestBody BookingRequest request) {
       // ...
   }
   ```

2. **Create CloudWatch Dashboards**:
   - One dashboard per service showing RED metrics for all endpoints
   - Include p50, p95, p99 latency distributions

3. **Set Per-Endpoint SLOs**:
   - Search API: p95 < 5s, error rate < 1%
   - Booking API: p95 < 500ms, error rate < 0.5%
   - Payment API: p95 < 1s, error rate < 0.1%

---

#### M3. Missing Error Budget Tracking
**Reference**: Section 7 (SLO definitions), Tier 3 Checklist (SLO/SLA definitions with error budgets)

**Problem**:
The design defines SLOs (99.9% availability, p95 < 500ms, payment success rate > 99%) but does not mention error budget calculation or consumption tracking. Without error budgets, teams cannot make informed risk decisions (e.g., should we delay feature release to fix bugs?).

**Countermeasures**:
1. **Calculate Monthly Error Budget**:
   - 99.9% availability = 43.2 minutes downtime/month allowed
   - Track actual downtime daily, project end-of-month budget consumption

2. **Create Error Budget Burn Rate Alerts**:
   - If burning > 10% of monthly budget in 1 day → escalate to engineering leadership
   - Trigger incident response process

3. **Use Error Budget to Gate Releases**:
   - If error budget < 20% remaining, freeze feature releases, focus on reliability improvements

---

#### M4. Missing Capacity Planning and Load Testing Baseline
**Reference**: Section 7 (Performance, Scalability), Tier 3 Checklist (Capacity planning and load testing)

**Problem**:
The design specifies auto-scaling (3-20 ECS tasks at CPU 70%) but does not mention:
- Expected peak traffic (requests/second)
- Load testing results to validate scaling configuration
- Headroom calculation (can the system handle 2x expected peak?)

**Countermeasures**:
1. **Define Expected Load**:
   - Normal: 100 requests/second
   - Peak (holiday season): 500 requests/second
   - Burst (marketing campaign): 1,000 requests/second

2. **Conduct Load Testing**:
   - Use JMeter or Gatling to simulate peak load
   - Validate that 20 ECS tasks can handle 1,000 req/s with p95 < 500ms
   - Test database connection pool (100 connections sufficient?)

3. **Calculate Headroom**:
   - If 20 tasks handle 1,000 req/s, headroom is 2x (can scale to handle 2,000 req/s)
   - Document in capacity plan

4. **Schedule Quarterly Load Tests**: Re-run load tests after major feature releases to detect performance regressions.

---

#### M5. Missing Incident Response Runbook
**Reference**: Tier 3 Checklist (Incident response runbooks and escalation procedures)

**Problem**:
The design mentions PagerDuty alerts but does not specify incident response procedures, escalation paths, or runbooks for common failure scenarios.

**Countermeasures**:
1. **Create Runbooks for Common Incidents**:
   - "Payment Service Down": Steps to verify Stripe status, rollback application, enable read-only mode
   - "External Provider API Degradation": Steps to identify affected provider, enable fallback, communicate to customers
   - "Database Failover": Steps to verify RDS failover completed, check connection pool, validate data integrity

2. **Define Escalation Policy**:
   - L1 (On-call engineer): Respond within 15 minutes, mitigate within 1 hour
   - L2 (Senior engineer): Escalate if unresolved after 1 hour
   - L3 (Engineering manager): Escalate if unresolved after 2 hours or revenue impact > $10k

3. **Establish Blameless Postmortem Process**: After each incident, publish postmortem within 48 hours with root cause, timeline, action items.

---

#### M6. Missing Configuration Management and Versioning
**Reference**: Tier 3 Checklist (Configuration as code with version control)

**Problem**:
The design does not mention how configuration (database URLs, API keys, timeouts, circuit breaker settings) is managed. Hardcoded or environment-specific configuration can cause production incidents.

**Countermeasures**:
1. **Use Centralized Configuration Service**:
   - AWS Systems Manager Parameter Store or AWS Secrets Manager for sensitive configuration
   - Spring Cloud Config Server for non-sensitive configuration

2. **Version Control All Configuration**:
   - Store configuration in Git repository (separate from application code)
   - Require pull request review for configuration changes

3. **Implement Configuration Validation**:
   - On application startup, validate that all required configuration keys are present
   - Fail fast if critical configuration is missing (database URL, API keys)

4. **Use Feature Flags for Risky Features**:
   - Implement LaunchDarkly or custom feature flag service
   - Enable gradual rollout (10% users → 50% → 100%)

---

#### M7. Missing Autoscaling Policy for Database Read Replicas
**Reference**: Section 7 (Availability - RDS Multi-AZ), Section 7 (Performance - connection pool)

**Problem**:
The design uses RDS Multi-AZ for write availability but does not mention read replicas for scaling read-heavy workloads (search results, itinerary viewing). During traffic spikes, read queries may overwhelm the primary database.

**Countermeasures**:
1. **Add RDS Read Replicas**:
   - Create 2 read replicas (separate AZs)
   - Route read queries (`/api/v1/itineraries/{id}`) to replicas using Spring `@Transactional(readOnly = true)`

2. **Monitor Replication Lag**:
   - CloudWatch metric: `ReplicaLag`
   - Alert if lag > 30 seconds (stale data risk)

3. **Implement Replica Autoscaling**:
   - Use RDS Aurora if possible (automatic read replica scaling)
   - Or: Monitor CPU and manually add replicas during peak seasons

---

### TIER 4: MINOR IMPROVEMENTS & POSITIVE OBSERVATIONS

#### P1. Strong Circuit Breaker and Retry Foundation
The design explicitly mentions Resilience4j for circuit breakers and Spring Retry, which demonstrates awareness of fault tolerance patterns. With proper configuration (added in C3 countermeasures), this provides strong resilience.

#### P2. Comprehensive Alerting Integration
PagerDuty for critical alerts and Slack for warnings shows appropriate severity-based routing. Expanding to cover additional failure modes (DLT messages, quota exhaustion) will complete the alerting strategy.

#### P3. Blue-Green Deployment with Fast Rollback
The design's Blue-Green deployment with 10-minute rollback capability is a strong safety mechanism for deployment failures. Adding database migration rollback testing (S6) will make this even more robust.

#### P4. Multi-AZ Database Configuration
RDS Multi-AZ with automatic failover demonstrates production-grade availability design. Adding RPO/RTO definitions and backup testing (C5) ensures disaster recovery completeness.

---

## Summary

This reliability review identified **6 critical issues** with system-wide impact, **6 significant issues** with partial system impact, and **7 moderate improvements**. The most severe risks are:

1. **Distributed transaction coordination gaps** (C1, C2): Multi-provider bookings lack saga pattern or compensation, risking financial inconsistency.
2. **Timeout and circuit breaker configuration missing** (C3): External API failures can cascade to service-wide outages.
3. **Payment-booking inconsistency** (C4): Callback failures leave unrecoverable orphaned payments.
4. **Backup and disaster recovery untested** (C5): No validated RPO/RTO or restore procedures.
5. **Concurrent modification conflicts** (C6): Optimistic locking missing for booking updates.

Addressing critical and significant issues is essential before production launch to prevent data loss, financial inconsistency, and extended outages.
