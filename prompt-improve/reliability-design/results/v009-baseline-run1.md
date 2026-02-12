# TravelHub Reliability Design Review - v009-baseline-run1

## Phase 1: Structural Analysis

### System Components
1. **API Gateway**: Entry point for mobile/web clients
2. **Booking Service**: Orchestrates search, inventory, pricing, and reservation state management
3. **Payment Service**: Handles payment processing via Stripe/PayPal
4. **Itinerary Service**: Manages confirmed itineraries, monitors flight status, proposes alternatives
5. **Notification Service**: Sends email/push/SMS/WebSocket notifications

### External Dependencies (Critical Path)
- **Flight API** (Amadeus): Search, booking, flight status monitoring
- **Hotel API** (Expedia): Search and booking
- **Car Rental APIs**: Multiple vendor integrations
- **Payment Gateways**: Stripe, PayPal
- **Notification Providers**: SendGrid (email), Firebase (push), Twilio (SMS)

### Data Flow Paths
1. **Booking Flow**: User → Booking Service → External APIs (parallel) → MongoDB cache → PostgreSQL (PENDING) → Payment Service → Stripe → Booking Service callback → PostgreSQL (CONFIRMED) → Kafka → Itinerary Service → Notification Service
2. **Flight Delay Response Flow**: Background job (5min interval) → Amadeus Flight Status API → Kafka (FlightDelayed) → Itinerary Service → Alternative search → Notification Service

### State Transitions
- **Booking**: PENDING → CONFIRMED / CANCELLED
- **Payment**: PENDING → COMPLETED / FAILED / REFUNDED
- **Itinerary**: ACTIVE → COMPLETED / DISRUPTED

### Explicitly Mentioned Reliability Mechanisms
- Resilience4j circuit breaker for external APIs
- Spring Retry
- RDS Multi-AZ with automatic failover (60 seconds)
- ElastiCache cluster mode (3 nodes)
- ECS Auto Scaling (3-20 tasks, 70% CPU threshold)
- Blue-Green deployment with ALB target group switching
- Flyway database migrations
- Structured logging with correlation_id

---

## Phase 2: Problem Detection

## Critical Issues (Tier 1)

### C-1: Distributed Transaction Consistency Gap in Booking Confirmation Flow

**Problem Description:**
The booking confirmation flow spans multiple external systems and databases without explicit distributed transaction coordination or compensation mechanisms. The flow includes:
1. External provider API creates provisional booking
2. PostgreSQL writes booking record (PENDING)
3. Kafka event published
4. Payment Service calls Stripe API
5. Callback to Booking Service updates PostgreSQL (CONFIRMED)
6. Kafka event published (BookingConfirmed)
7. Itinerary Service creates itinerary record
8. Notification Service sends confirmation email

**Failure Scenarios:**
- **Scenario 1**: Payment succeeds at Stripe but callback to Booking Service fails (network partition, service crash) → User charged but booking remains PENDING → No confirmation email sent → Customer support incident
- **Scenario 2**: PostgreSQL update succeeds but Kafka publish fails → Itinerary Service never creates itinerary record → User cannot access trip details
- **Scenario 3**: Kafka event consumed twice due to consumer restart → Duplicate itinerary records or duplicate notification emails

**Impact:** Data inconsistency leading to financial discrepancies, customer service escalations, and potential regulatory compliance issues. Recovery requires manual database reconciliation and customer refunds.

**Countermeasures:**
1. **Implement Transactional Outbox Pattern**:
   - Store Kafka events in PostgreSQL within the same transaction as booking updates
   - Use a dedicated outbox table with columns: `id`, `aggregate_id`, `event_type`, `payload`, `published_at`
   - Implement a separate publisher process that reads unpublished events and sends to Kafka with at-least-once semantics
   - Mark events as published after successful Kafka acknowledgment

2. **Payment Webhook Idempotency**:
   - Add `idempotency_key` column to `payments` table (UNIQUE constraint)
   - Accept Stripe's idempotency key in callback endpoint
   - Use `INSERT ... ON CONFLICT DO NOTHING` pattern to prevent duplicate processing

3. **Compensating Transaction for Payment Failures**:
   - Implement automatic refund logic if booking confirmation fails after successful payment
   - Add `compensation_status` column to track refund attempts
   - Set up dead letter queue for failed compensation actions requiring manual intervention

4. **Saga Orchestration Alternative**:
   - Consider implementing Saga pattern with explicit compensation steps
   - Define rollback procedures for each step (e.g., cancel provider booking if payment fails)
   - Store saga state in PostgreSQL for crash recovery

### C-2: Missing Idempotency Keys for External Provider API Calls

**Problem Description:**
The design does not specify idempotency mechanisms for external provider API calls (Amadeus, Expedia, car rental APIs). When the Booking Service creates a provisional booking at a provider and receives a network timeout, it cannot safely retry without risking duplicate bookings.

**Failure Scenarios:**
- Client submits booking request → Booking Service calls Amadeus API → Amadeus processes request successfully but response is lost due to network timeout → Booking Service retries → Duplicate flight reservation created at Amadeus → User double-charged or inventory incorrectly reserved

**Impact:** Financial loss due to duplicate reservations, inventory inconsistencies, customer confusion when receiving multiple confirmation codes from providers.

**Countermeasures:**
1. **Generate Client-Side Idempotency Keys**:
   - Add `idempotency_key` column to `booking_items` table
   - Generate UUID for each external API request before the first attempt
   - Include idempotency key in provider API calls (if supported by provider APIs)
   - Store provider response with idempotency key to detect and deduplicate retries

2. **Provider Booking Reference Deduplication**:
   - Add UNIQUE constraint on `(provider_code, provider_booking_ref)` in `booking_items`
   - If provider returns same booking reference on retry, treat as successful idempotent retry rather than error

3. **Timeout and Retry Strategy**:
   - Set aggressive timeout (e.g., 10 seconds) for provider API calls
   - Implement exponential backoff with jitter (initial: 1s, max: 30s, max attempts: 3)
   - After max retries, mark booking item as `PENDING_CONFIRMATION` and queue for background reconciliation job

4. **Background Reconciliation Job**:
   - Periodically query provider APIs for booking status using stored idempotency keys
   - Reconcile local database state with provider state
   - Alert operations team for unresolvable discrepancies

### C-3: No RPO/RTO Validation or Tested Backup Recovery Procedures

**Problem Description:**
The design mentions RDS Multi-AZ configuration but lacks:
- Explicit RPO (Recovery Point Objective) and RTO (Recovery Time Objective) definitions
- Documented and tested backup restoration procedures
- Validation that automated RDS snapshots meet recovery requirements
- Disaster recovery runbook for regional outages

**Failure Scenarios:**
- **Scenario 1**: RDS instance suffers data corruption (application bug writes corrupt data) → Automated failover switches to standby with same corrupt data → No recent validated backup available → Data loss spans hours or days
- **Scenario 2**: AWS region outage affects both primary and standby RDS instances → Team attempts cross-region recovery but has never tested the procedure → Extended downtime while troubleshooting
- **Scenario 3**: Accidental deletion of critical booking records (application bug or operator error) → RDS point-in-time recovery attempted but never tested → Recovery process takes longer than expected → SLA violation

**Impact:** Potential data loss of customer bookings and payments, extended service outages exceeding 99.9% SLA, regulatory compliance violations (financial transaction data retention requirements).

**Countermeasures:**
1. **Define Explicit RPO/RTO Targets**:
   - RPO: ≤ 5 minutes (acceptable data loss window)
   - RTO: ≤ 30 minutes for critical services (booking, payment)
   - Document these targets in operational runbooks

2. **Implement and Test Cross-Region Backup Strategy**:
   - Enable automated RDS snapshots with 7-day retention
   - Copy daily snapshots to secondary AWS region (us-west-2 if primary is us-east-1)
   - Schedule quarterly disaster recovery drills with the following steps:
     - Restore snapshot to new RDS instance in secondary region
     - Verify data integrity (row counts, critical transaction checksums)
     - Measure actual RTO and document gaps
   - Create runbook with step-by-step recovery procedures

3. **Point-in-Time Recovery Testing**:
   - Test PITR monthly in non-production environment
   - Simulate data corruption scenarios and measure recovery time
   - Document recovery procedures in incident response playbook

4. **Application-Level Backup Validation**:
   - Implement daily backup validation job that:
     - Restores a recent snapshot to temporary RDS instance
     - Runs data integrity checks (foreign key constraints, critical business rule validations)
     - Alerts operations team if validation fails

5. **MongoDB Disaster Recovery**:
   - Define backup strategy for MongoDB (currently not specified)
   - Since MongoDB stores search cache (TTL 30 minutes), acceptable to lose this data, but document the warm-up procedure
   - For critical data in MongoDB, implement replica set with delayed secondary (e.g., 1-hour delay) to protect against data corruption

### C-4: Circuit Breaker Configuration Lacks Bulkhead Isolation and Timeout Specification

**Problem Description:**
The design mentions "Resilience4j circuit breaker" for external APIs but does not specify:
- Thread pool or semaphore-based bulkhead isolation to limit concurrent calls
- Timeout configurations for each external dependency
- Circuit breaker thresholds (failure rate, slow call duration)
- Fallback strategies when circuit is open

Without bulkheads, a slow or unresponsive external API can exhaust all threads in the service, causing cascading failure to unrelated functionality.

**Failure Scenarios:**
- Expedia Hotel API experiences degradation (5-second response times instead of normal 200ms) → All booking service threads blocked waiting for Expedia responses → Flight search requests start failing even though Amadeus API is healthy → Complete service outage instead of partial degradation

**Impact:** Cascading failure causing complete service unavailability instead of graceful degradation. Violates 99.9% SLA due to blast radius extending beyond the failing dependency.

**Countermeasures:**
1. **Implement Bulkhead Isolation Per External Dependency**:
   - Configure separate thread pools for each external API category:
     - Amadeus Flight API: max 20 threads
     - Expedia Hotel API: max 15 threads
     - Car Rental APIs: max 10 threads
     - Payment APIs (Stripe/PayPal): max 25 threads
   - Use Resilience4j `Bulkhead` with semaphore-based isolation for lightweight operations
   - Queue size: 50 (reject requests when thread pool + queue full)

2. **Define Explicit Timeout Configuration**:
   ```java
   // Example configuration
   External API Timeouts:
   - Amadeus Flight Search: 10s (read timeout), 5s (connect timeout)
   - Expedia Hotel Search: 8s (read timeout), 3s (connect timeout)
   - Stripe Payment: 15s (read timeout), 5s (connect timeout)
   - Flight Status Poll: 5s (read timeout), 2s (connect timeout)
   ```

3. **Circuit Breaker Thresholds**:
   ```yaml
   resilience4j.circuitbreaker:
     flight-api:
       failure-rate-threshold: 50%
       slow-call-rate-threshold: 50%
       slow-call-duration-threshold: 5s
       minimum-number-of-calls: 10
       sliding-window-size: 100
       wait-duration-in-open-state: 30s
   ```

4. **Graceful Degradation Strategies**:
   - **Search API**: If one provider's circuit is open, continue with responses from healthy providers; include notice to user that results are partial
   - **Payment API**: If Stripe circuit is open and PayPal is healthy, automatically route to PayPal; if both open, return 503 with retry-after header
   - **Flight Status Monitoring**: If Amadeus Status API circuit is open, increase polling interval to reduce load and alert operations team

5. **Connection Pool Configuration**:
   - Set max connections per external API client library
   - Configure connection timeout (3-5s) and idle connection timeout (30s)
   - Enable connection pool monitoring metrics

### C-5: Kafka Consumer Group Rebalancing and Poison Message Handling Not Addressed

**Problem Description:**
The design uses Kafka for event-driven communication (BookingConfirmed, FlightDelayed events) but does not address:
- Consumer group rebalancing impact on in-flight message processing
- Poison message handling (malformed events or events causing repeated processing failures)
- Exactly-once vs. at-least-once delivery semantics choice
- Dead letter queue (DLQ) strategy for unprocessable messages

**Failure Scenarios:**
- **Scenario 1**: Itinerary Service consumes BookingConfirmed event and begins processing → Consumer group rebalances (pod restart, new deployment) → Event reprocessed by another consumer → Duplicate itinerary record created
- **Scenario 2**: Malformed JSON in FlightDelayed event causes Itinerary Service consumer to crash repeatedly → Event blocking entire partition → All subsequent flight delay events for that partition stuck → Users not notified of flight disruptions
- **Scenario 3**: Bug in Itinerary Service causes consistent failure when processing specific event structure → Infinite retry loop consuming resources → Service degradation

**Impact:** Duplicate data processing leading to inconsistent state, message processing backlog causing delayed notifications (critical for time-sensitive flight delays), potential service instability due to poison messages.

**Countermeasures:**
1. **Implement Idempotent Event Consumers**:
   - Add `processed_events` table: `(event_id UUID PRIMARY KEY, event_type VARCHAR, processed_at TIMESTAMP)`
   - Before processing event, check if `event_id` exists in table
   - Insert event_id and process business logic in same database transaction
   - Use `INSERT ... ON CONFLICT DO NOTHING` to handle reprocessing safely

2. **Poison Message Detection and Quarantine**:
   - Configure max retry attempts per message (e.g., 3 retries with exponential backoff)
   - After max retries, move message to dead letter topic (DLT): `booking-events-dlt`
   - Include error metadata in DLT: `original_topic`, `consumer_group`, `exception_type`, `exception_message`, `retry_count`
   - Implement monitoring dashboard for DLT messages with alert threshold (>10 messages/hour)

3. **Kafka Consumer Configuration**:
   ```yaml
   spring.kafka.consumer:
     enable-auto-commit: false  # Manual commit after successful processing
     isolation-level: read_committed  # For exactly-once semantics
     max-poll-records: 50  # Limit batch size to prevent timeout during processing
     session-timeout-ms: 30000  # Allow time for processing before rebalance
     heartbeat-interval-ms: 10000
   ```

4. **Consumer Rebalancing Safety**:
   - Use `ConsumerRebalanceListener` to commit offsets and gracefully finish processing before rebalance
   - Implement cooperative sticky assignor to minimize partition movement
   - Set `max.poll.interval.ms` to 5 minutes (allow time for processing large batches)

5. **Message Schema Validation**:
   - Validate event schema before processing (JSON Schema or Avro)
   - Reject malformed messages immediately to DLT instead of retrying
   - Version event schemas and handle backward compatibility

6. **Manual DLT Replay Process**:
   - Create operational runbook for reviewing and replaying DLT messages
   - Implement admin API endpoint to replay specific message from DLT after bug fix
   - Include alerting when DLT accumulates messages

---

## Significant Issues (Tier 2)

### S-1: Retry Strategy Missing Exponential Backoff and Jitter Configuration

**Problem Description:**
The design mentions "Spring Retry" but does not specify retry strategy details:
- Exponential backoff parameters (initial delay, multiplier, max delay)
- Jitter to prevent thundering herd problem
- Retry eligibility criteria (which HTTP status codes trigger retry)
- Maximum retry attempts

**Failure Scenarios:**
- External API experiences temporary overload → TravelHub instances simultaneously retry with fixed intervals → Synchronized retry storm amplifies load on recovering API → Extended outage instead of quick recovery

**Impact:** Prolonged service degradation due to retry storms, potential ban from external provider APIs for aggressive retry behavior, poor user experience with inconsistent timeout durations.

**Countermeasures:**
1. **Configure Exponential Backoff with Jitter**:
   ```java
   @Retryable(
     value = {RestClientException.class},
     maxAttempts = 4,
     backoff = @Backoff(
       delay = 1000,      // 1s initial delay
       multiplier = 2.0,  // 2x each retry (1s, 2s, 4s)
       maxDelay = 15000,  // 15s max delay
       random = true      // Enable jitter
     )
   )
   ```

2. **Retry Eligibility Rules**:
   - **Retry**: 408 (Request Timeout), 429 (Too Many Requests), 500, 502, 503, 504
   - **Do Not Retry**: 400 (Bad Request), 401, 403, 404, 409 (Conflict), 422
   - Respect `Retry-After` header when present (429, 503 responses)

3. **Differentiate Retry Strategies by Operation**:
   - **Idempotent GETs** (flight status check): Aggressive retry (max 5 attempts)
   - **Non-idempotent POSTs** (create booking): Conservative retry (max 2 attempts) with idempotency key
   - **Payment operations**: No automatic retry; require explicit user action

4. **Circuit Breaker Integration**:
   - Disable retries when circuit is half-open or open
   - Count retry attempts toward circuit breaker failure threshold

### S-2: Rate Limiting Strategy Insufficient for Self-Protection and Abuse Prevention

**Problem Description:**
The design mentions "Redis for rate limiting" but lacks details on:
- Rate limit tiers (per-user, per-IP, global service limits)
- Rate limit algorithms (token bucket, sliding window)
- Differentiated limits for authenticated vs. anonymous users
- Rate limit for internal service-to-service calls to external APIs (preventing quota exhaustion)

**Failure Scenarios:**
- **Scenario 1**: Malicious actor or misconfigured client submits thousands of search requests → Booking Service forwards all requests to external provider APIs → Provider rate limit quota exhausted → Legitimate user requests rejected
- **Scenario 2**: Popular flight route goes on sale → Thousands of users simultaneously search and book → No per-user rate limiting → Database connection pool exhausted → Service outage

**Impact:** Service unavailability for legitimate users, potential provider API account suspension, increased infrastructure costs from processing abusive traffic.

**Countermeasures:**
1. **Implement Multi-Tier Rate Limiting**:
   - **Anonymous users** (per-IP): 10 search requests/minute, 1 booking request/minute
   - **Authenticated users** (per-user): 60 search requests/minute, 5 booking requests/minute
   - **Global service limits**: 10,000 external API calls/minute per provider (to stay within provider quotas)

2. **Use Token Bucket Algorithm in Redis**:
   ```java
   // Pseudocode
   key = "ratelimit:search:{userId}"
   current = INCR key
   if current == 1:
       EXPIRE key 60  // 60-second window
   if current > 60:
       return 429 Too Many Requests
   ```

3. **Provider API Quota Management**:
   - Track global API call count per provider in Redis
   - Implement pre-call check: if approaching quota limit (e.g., 90% of daily quota), degrade to cached results or return partial results
   - Alert operations team at 80% quota utilization

4. **Rate Limit Response Headers**:
   - Include standard headers in API responses:
     ```
     X-RateLimit-Limit: 60
     X-RateLimit-Remaining: 42
     X-RateLimit-Reset: 1625097600
     Retry-After: 30  (in 429 responses)
     ```

5. **Backpressure Mechanism**:
   - When global rate limit approaches threshold, return 503 with Retry-After header
   - Implement priority queuing: prioritize booking confirmations over search requests during high load

### S-3: Health Check Design Lacks Depth and Dependency Awareness

**Problem Description:**
The design does not specify health check implementation. AWS ALB requires health checks for target group management, but shallow health checks (e.g., simple HTTP 200 on `/health`) can mark unhealthy instances as healthy, leading to failed requests.

**Failure Scenarios:**
- **Scenario 1**: Booking Service loses database connectivity → Health check endpoint returns 200 (only checks HTTP server status) → ALB continues routing traffic → All requests fail with 500 errors
- **Scenario 2**: Circuit breaker to critical external API (Amadeus) is open → Health check still returns 200 → Service cannot fulfill core functionality but receives traffic

**Impact:** Increased error rates and latency as traffic routes to degraded instances, user-facing errors instead of graceful failover.

**Countermeasures:**
1. **Implement Liveness and Readiness Endpoints**:
   - **Liveness** (`/health/live`): Indicates if process should be restarted
     - Check: Can application accept traffic? (basic process health)
     - Used by: ECS task health check
   - **Readiness** (`/health/ready`): Indicates if instance can handle requests
     - Check: Are critical dependencies healthy?
     - Used by: ALB target group health check

2. **Readiness Check Dependencies**:
   ```java
   /health/ready checks:
   - PostgreSQL connectivity: Execute `SELECT 1` with 2s timeout
   - Redis connectivity: Execute `PING` command with 1s timeout
   - Kafka producer availability: Check if producer is ready
   - Circuit breaker status: If all critical external APIs (Amadeus, Expedia) have open circuits, return 503
   ```

3. **Graceful Degradation Indicators**:
   - Return 200 with degraded status if non-critical dependencies are down
   - Include health check response body:
     ```json
     {
       "status": "UP",  // or "DOWN", "DEGRADED"
       "components": {
         "db": "UP",
         "redis": "UP",
         "amadeus-api": "CIRCUIT_OPEN"
       }
     }
     ```

4. **Health Check Timeouts**:
   - ALB health check: 5-second interval, 2 consecutive successes to mark healthy, 2 consecutive failures to mark unhealthy
   - Health endpoint timeout: 3 seconds (faster than ALB timeout)
   - If health check times out, fail-safe to unhealthy status

5. **Startup Probes for Slow Initialization**:
   - Implement separate startup probe (`/health/startup`) with longer timeout
   - Used during application startup to allow time for connection pool initialization

### S-4: Database Migration Backward Compatibility Not Explicitly Addressed

**Problem Description:**
The design specifies Flyway for database migrations and Blue-Green deployment but does not address schema backward compatibility during rolling updates. If Blue and Green environments run simultaneously with different schema versions, application crashes or data corruption can occur.

**Failure Scenarios:**
- **Scenario 1**: Migration adds NOT NULL column without default value → Green environment (new version) expects column to exist → Blue environment (old version) writes records without the column → Migration fails on Blue environment startup → Deployment stuck
- **Scenario 2**: Migration renames column `status` to `booking_status` → Green environment uses new column name → Blue environment still writes to old column → Data split across two columns → Inconsistent state

**Impact:** Failed deployments requiring emergency rollback, data inconsistency requiring manual reconciliation, extended downtime during troubleshooting.

**Countermeasures:**
1. **Adopt Expand-Contract Migration Pattern**:
   - **Expand phase** (backward-compatible changes):
     - Add new columns as nullable
     - Add new tables
     - Create new indexes
     - Deploy application version that writes to both old and new schemas
   - **Contract phase** (breaking changes):
     - After all instances run new version, remove old columns/tables
     - Add NOT NULL constraints
     - Deploy application version that only uses new schema

2. **Example: Renaming Column**:
   - **Migration 1** (expand): Add `booking_status` column as nullable, copy data from `status`
   - **Deploy v1**: Application writes to both `status` and `booking_status`, reads from `booking_status` if present, else `status`
   - **Wait for all instances to run v1** (Blue-Green switch complete)
   - **Migration 2** (contract): Drop `status` column
   - **Deploy v2**: Application only uses `booking_status`

3. **Schema Validation in Deployment Pipeline**:
   - Run automated tests that:
     - Start application with N-1 schema version
     - Verify application starts successfully and passes smoke tests
     - This validates backward compatibility

4. **Flyway Migration Conventions**:
   - Use versioned migrations: `V1__initial_schema.sql`, `V2__add_booking_status.sql`
   - Never modify existing migrations after deployment to production
   - Include rollback scripts for each migration (stored separately for emergency use)

5. **Database Replication Lag Monitoring**:
   - Monitor RDS read replica lag during migrations
   - Delay application deployment until replication lag < 5 seconds

### S-5: SPOF in Background Flight Status Polling Job

**Problem Description:**
The design specifies a "background job (5-minute interval) that polls Amadeus Flight Status API" but does not specify:
- How many instances of this job run concurrently
- Leader election mechanism to prevent duplicate polling
- Failure recovery if the polling job crashes

If only one instance runs the job, it's a single point of failure. If multiple instances run without coordination, duplicate API calls waste quota and may trigger rate limiting.

**Failure Scenarios:**
- **Scenario 1**: Single instance running polling job crashes → No flight status updates until instance restarts (could be 5-10 minutes if ECS takes time to detect and restart) → Users not notified of flight delays → Poor customer experience
- **Scenario 2**: All Itinerary Service instances independently poll flight status → 10 instances × 100 flights = 1000 API calls every 5 minutes → Amadeus rate limit exhausted → Service banned

**Impact:** Delayed flight disruption notifications leading to customer complaints and potential flight rebooking failures, excessive external API costs, potential provider account suspension.

**Countermeasures:**
1. **Implement Distributed Leader Election**:
   - Use Redis SETNX for leader election:
     ```java
     key = "flight-status-poller-leader"
     lock = SETNX key instanceId
     if lock == 1:
         EXPIRE key 300  // 5-minute lease
         runFlightStatusPoll()
     ```
   - Lease duration matches polling interval to ensure automatic failover

2. **Alternative: ShedLock for Distributed Job Coordination**:
   ```java
   @Scheduled(cron = "0 */5 * * * *")
   @SchedulerLock(
       name = "flightStatusPoller",
       lockAtMostFor = "4m",  // Max execution time
       lockAtLeastFor = "2m"  // Min time between executions
   )
   public void pollFlightStatus() { ... }
   ```

3. **Partition-Based Polling**:
   - Divide flights into partitions (e.g., based on hash of flight ID)
   - Each Itinerary Service instance polls assigned partitions
   - Use consistent hashing to distribute load evenly
   - On instance failure, remaining instances automatically cover orphaned partitions

4. **Kafka-Based Alternative**:
   - Instead of polling, emit "ScheduleFlightStatusCheck" events to Kafka topic with 5-minute delay
   - Itinerary Service consumes events and checks status for specific flight
   - Leverages Kafka consumer group rebalancing for automatic failover

5. **Monitoring and Alerting**:
   - Emit CloudWatch metric: `flight_status_polls_completed` (count per 5-minute window)
   - Alert if metric drops to 0 for 2 consecutive windows (indicates polling job failure)
   - Dashboard showing polling job leader instance ID and last poll timestamp

### S-6: Payment Idempotency and Duplicate Charge Prevention Insufficient

**Problem Description:**
The design stores payment transactions with `transaction_id` from Stripe/PayPal but does not specify:
- How duplicate payment requests from users (double-click, browser back button) are prevented
- Idempotency key generation and storage for payment API calls
- Reconciliation process between TravelHub payment records and provider payment records

**Failure Scenarios:**
- **Scenario 1**: User clicks "Pay" button, request times out, user clicks again → Two payment requests sent to Stripe → User double-charged → Refund required, customer support overhead
- **Scenario 2**: Payment succeeds at Stripe but response lost → TravelHub marks payment as FAILED → User attempts payment again → Double charge

**Impact:** Financial loss due to refunds and chargeback fees, customer trust erosion, regulatory compliance risk (PCI DSS requires accurate transaction records).

**Countermeasures:**
1. **Client-Side Idempotency Key Generation**:
   - Frontend generates UUID when "Pay" button clicked
   - Include idempotency key in payment request header: `Idempotency-Key: <uuid>`
   - Frontend disables "Pay" button after click and stores key in localStorage to prevent duplicate submissions

2. **Server-Side Idempotency Key Enforcement**:
   - Add `idempotency_key` column to `payments` table (UNIQUE constraint)
   - Before calling Stripe API:
     ```sql
     INSERT INTO payments (id, booking_id, amount, idempotency_key, status, created_at)
     VALUES (?, ?, ?, ?, 'PENDING', NOW())
     ON CONFLICT (idempotency_key) DO NOTHING
     RETURNING id;
     ```
   - If INSERT returns no rows, payment already processed → Return existing payment result

3. **Stripe Idempotency Key Usage**:
   - Pass idempotency key to Stripe API:
     ```java
     RequestOptions options = RequestOptions.builder()
         .setIdempotencyKey(idempotencyKey)
         .build();
     PaymentIntent.create(params, options);
     ```
   - Stripe guarantees idempotent processing for 24 hours

4. **Background Payment Reconciliation Job**:
   - Daily job queries Stripe API for all payments in last 7 days
   - Compare Stripe transaction IDs with local `payments` table
   - Alert on discrepancies:
     - Payment in Stripe but not in database → Potential data loss
     - Payment in database as COMPLETED but FAILED in Stripe → Incorrect booking confirmation
   - Generate reconciliation report for finance team

5. **Payment State Machine Enforcement**:
   - Prevent invalid state transitions (e.g., COMPLETED → PENDING)
   - Use database CHECK constraint:
     ```sql
     ALTER TABLE payments ADD CONSTRAINT valid_status_transition
     CHECK (
       (status = 'PENDING' AND previous_status IS NULL) OR
       (status = 'COMPLETED' AND previous_status = 'PENDING') OR
       (status = 'FAILED' AND previous_status = 'PENDING') OR
       (status = 'REFUNDED' AND previous_status = 'COMPLETED')
     );
     ```

---

## Moderate Issues (Tier 3)

### M-1: SLO/SLA Definitions Lack Error Budget and Actionable Alerting Thresholds

**Problem Description:**
The design defines SLO targets (99.9% availability, p95 latency < 500ms, 99% payment success rate) but does not specify:
- Error budget calculation and tracking
- Alerting thresholds based on error budget consumption rate
- Decision framework for when to halt feature releases due to SLO violations

**Impact:** Reactive incident response instead of proactive reliability management, unclear prioritization of reliability work vs. feature development.

**Countermeasures:**
1. **Error Budget Calculation**:
   - 99.9% availability SLO → 0.1% error budget → 43.2 minutes downtime per month
   - Track error budget consumption in real-time:
     ```
     Error budget remaining = 1 - (actual error rate / allowed error rate)
     Example: If current error rate is 0.05% → 50% error budget consumed
     ```

2. **Multi-Tier Alerting Based on Error Budget Burn Rate**:
   - **Critical alert** (page on-call): Burn rate > 10x (error budget exhausted in 3 days)
     - Current error rate > 1% (10x the 0.1% budget)
   - **Warning alert** (Slack notification): Burn rate > 5x (budget exhausted in 6 days)
     - Current error rate > 0.5%
   - Review alert at next business day: Burn rate > 1x

3. **Release Freeze Policy**:
   - If error budget < 20% remaining, halt non-critical feature releases
   - Focus engineering capacity on reliability improvements
   - Require SRE approval for emergency deployments during freeze

4. **SLO Dashboard**:
   - Real-time error budget visualization (gauge chart showing % remaining)
   - Historical error budget consumption chart (30-day trend)
   - Top error contributors (endpoint, dependency causing most SLO violations)

5. **Latency SLO Alerting**:
   - Define windows: 1-hour and 24-hour
   - Alert if p95 latency > 500ms for:
     - 10% of requests in 1-hour window (fast burn)
     - 5% of requests in 24-hour window (slow burn)

### M-2: Distributed Tracing and Correlation ID Propagation Not Fully Specified

**Problem Description:**
The design mentions "correlation_id (trace UUID) in all logs" but lacks:
- Tracing instrumentation for external API calls
- Span context propagation across Kafka events
- Integration with distributed tracing system (X-Ray, Jaeger, Zipkin)

**Impact:** Difficult to debug production issues spanning multiple services, long incident resolution times, inability to identify root cause of latency spikes.

**Countermeasures:**
1. **Integrate AWS X-Ray or OpenTelemetry**:
   - Instrument all HTTP clients, database queries, Kafka producers/consumers
   - Automatic span creation for Spring Boot controllers and services
   - Use Spring Cloud Sleuth for automatic correlation ID injection

2. **Correlation ID Propagation**:
   - **HTTP**: Propagate via `X-Correlation-ID` header (generate at API Gateway if not present)
   - **Kafka**: Include `correlation_id` in event payload header
   - **Database**: Store `correlation_id` in relevant tables for data lineage tracking

3. **Critical Path Tracing**:
   - Instrument booking flow end-to-end:
     - `POST /bookings` → External provider API calls → PostgreSQL write → Kafka publish → Payment Service → Stripe API → Booking confirmation
   - Identify slow spans with latency > 1s
   - Create latency breakdown dashboard (time spent in each service/dependency)

4. **Sampling Strategy**:
   - 100% sampling for requests with errors
   - 10% sampling for successful requests (reduce cost)
   - 100% sampling for requests exceeding latency threshold (p95 + 50%)

5. **Log-Trace Correlation**:
   - Include trace ID and span ID in structured logs
   - Link from log aggregation (CloudWatch Logs Insights) to trace viewer
   - Example log entry:
     ```json
     {
       "timestamp": "2026-02-11T10:30:00Z",
       "level": "ERROR",
       "correlation_id": "abc-123-def",
       "trace_id": "1-abc-123",
       "span_id": "def-456",
       "message": "Stripe API timeout"
     }
     ```

### M-3: Capacity Planning and Load Testing Strategy Missing

**Problem Description:**
The design specifies ECS Auto Scaling (3-20 tasks, 70% CPU threshold) but lacks:
- Peak load capacity calculations (expected requests per second during sale events)
- Load testing validation of scaling thresholds
- Database connection pool sizing justification (100 connections per instance)

**Impact:** Risk of insufficient capacity during traffic spikes (Black Friday sales, viral social media posts), potential over-provisioning leading to unnecessary costs.

**Countermeasures:**
1. **Define Peak Load Targets**:
   - Normal load: 50 requests/second
   - Peak load (2x normal): 100 requests/second
   - Extreme peak (flash sales): 500 requests/second for 10 minutes
   - Design target: 3x normal sustained load + 5x normal burst for 10 minutes

2. **Load Testing Scenarios**:
   - **Baseline test**: Sustained 50 req/s for 30 minutes → Validate p95 latency < 500ms
   - **Peak test**: Ramp from 50 to 500 req/s over 5 minutes, sustain for 10 minutes → Validate auto-scaling behavior
   - **Soak test**: Sustained 150 req/s for 4 hours → Identify memory leaks and connection pool exhaustion
   - **Spike test**: Instant jump to 1000 req/s → Validate graceful degradation (503 responses instead of crashes)

3. **Connection Pool Sizing Calculation**:
   - Formula: `connections = (core_count * 2) + effective_spindle_count`
   - For typical web service: 10-20 connections per instance
   - Current config (100 connections) may be excessive → Risk of exhausting RDS max connections
   - Recommendation: 20 connections per ECS task, 50 connection timeout
   - RDS max connections: 1000 (adjust based on instance class)
   - Reserve 200 connections for maintenance operations

4. **Auto-Scaling Threshold Validation**:
   - Current threshold: CPU > 70% → May be too reactive
   - Add custom CloudWatch metric: `active_request_count`
   - Scale out when: `active_requests / instance_count > 20` OR CPU > 70%
   - Scale in when: CPU < 40% AND `active_requests / instance_count < 10` for 10 minutes

5. **Database Capacity Planning**:
   - Estimate: 500 bookings/hour peak → 0.14 writes/second + 1 write/second for reads
   - RDS instance class: Validate db.r5.xlarge can handle load
   - Monitor RDS Performance Insights for CPU, IOPS, connection count

### M-4: Feature Flag Infrastructure Not Specified for Progressive Rollout

**Problem Description:**
The design mentions Blue-Green deployment but does not specify feature flag capabilities for progressive rollout and quick rollback of specific features without full deployment.

**Impact:** Risk of deploying defective features to all users simultaneously, inability to perform A/B testing for business-critical changes, slow rollback process requiring full deployment.

**Countermeasures:**
1. **Integrate Feature Flag Service**:
   - Use LaunchDarkly, Split.io, or AWS AppConfig
   - Centralized flag management with real-time updates (no deployment required)
   - Support for percentage rollouts and user targeting

2. **Critical Features to Flag**:
   - New payment provider integration (Stripe → PayPal fallback)
   - Alternative flight search algorithm
   - Auto-rebooking logic for flight disruptions
   - New rate limiting rules

3. **Flag Evaluation Strategy**:
   - Cache flag values in-memory with 30-second TTL (reduce latency)
   - Default to safe value (feature disabled) if flag service unavailable
   - Log flag evaluation decisions for debugging

4. **Gradual Rollout Process**:
   - Day 1: Enable for internal users only (10 users)
   - Day 2: Enable for 1% of production users, monitor error rates
   - Day 3: Increase to 10% if error rate < 0.5%
   - Day 5: Increase to 50% if error rate remains low
   - Day 7: Enable for 100% of users

5. **Flag Lifecycle Management**:
   - Document flag owner and removal date
   - Remove flags after 30 days of 100% rollout (prevent technical debt)
   - Alert if flag older than 60 days still exists

### M-5: Incident Response Runbooks and Escalation Procedures Undefined

**Problem Description:**
The design specifies monitoring and alerting but lacks operational runbooks for common incident scenarios.

**Impact:** Prolonged incident resolution time due to ad-hoc troubleshooting, inconsistent incident response across team members, increased stress during on-call shifts.

**Countermeasures:**
1. **Create Runbooks for Common Incidents**:
   - **High error rate alert**:
     - Check CloudWatch logs for error spike in specific service
     - Check external provider status pages (Amadeus, Expedia, Stripe)
     - If provider outage: Enable circuit breaker fallback manually
     - If application bug: Rollback to previous version
   - **Database high CPU**:
     - Check RDS Performance Insights for slow queries
     - Check for long-running transactions (`pg_stat_activity`)
     - Consider temporary read replica promotion if primary unresponsive
   - **Payment processing failures**:
     - Check Stripe dashboard for service status
     - Reconcile payment records with provider
     - Manually process stuck transactions if needed

2. **Escalation Policy**:
   - L1 (on-call engineer): First responder, 15-minute response time
   - L2 (senior engineer): Escalate if unresolved after 30 minutes
   - L3 (engineering manager): Escalate for customer-impacting outages > 1 hour
   - Executive escalation: SLA breach imminent (> 40 minutes downtime in month)

3. **Incident Severity Definitions**:
   - **SEV1** (Critical): Service completely unavailable or payment processing down
     - Response time: 15 minutes, resolve within 4 hours
   - **SEV2** (High): Degraded functionality, partial service outage
     - Response time: 30 minutes, resolve within 8 hours
   - **SEV3** (Medium): Minor feature broken, workaround available
     - Response time: Next business day

4. **Communication Templates**:
   - Status page update templates
   - Customer notification email templates
   - Internal incident Slack channel structure

5. **Blameless Postmortem Process**:
   - Required for all SEV1/SEV2 incidents
   - Template: Timeline, root cause, impact, action items
   - Review in weekly engineering meeting
   - Track action items in backlog with high priority

### M-6: Configuration Management and Secret Rotation Strategy Missing

**Problem Description:**
The design does not specify how configuration is managed across environments or how secrets (API keys, database passwords) are rotated.

**Impact:** Risk of secrets leakage through version control, manual configuration errors during deployment, inability to quickly rotate compromised credentials.

**Countermeasures:**
1. **Use AWS Systems Manager Parameter Store or Secrets Manager**:
   - Store all secrets in Secrets Manager with automatic rotation enabled
   - Store non-sensitive config in Parameter Store
   - Application fetches secrets at startup (cache with 1-hour TTL)

2. **Secret Rotation Policy**:
   - Database passwords: Rotate every 90 days automatically
   - API keys (Stripe, Amadeus): Rotate annually or immediately if compromised
   - JWT signing keys: Rotate every 30 days with 7-day overlap period (support N and N-1 keys)

3. **Configuration as Code**:
   - Store environment-specific config in Git repo (separate from application code)
   - Use Terraform or CloudFormation for infrastructure configuration
   - Implement GitOps workflow: Config changes deployed via CI/CD pipeline

4. **Environment Parity**:
   - Use same configuration structure across dev/staging/production
   - Override values using environment variables or parameter paths (e.g., `/travelhub/prod/db-password`)

5. **Secret Scanning**:
   - Enable GitHub secret scanning to prevent accidental commit of secrets
   - Run truffleHog in CI pipeline to detect secrets in code

---

## Minor Improvements and Positive Aspects (Tier 4)

### Positive Aspects

1. **Resilience4j Integration**: Proactive inclusion of circuit breaker library demonstrates reliability awareness.

2. **Multi-AZ Database Configuration**: RDS Multi-AZ with automatic failover provides good baseline availability.

3. **Structured Logging with Correlation ID**: Clear logging strategy will aid troubleshooting.

4. **Blue-Green Deployment**: Safe deployment strategy with quick rollback capability.

5. **Comprehensive Technology Stack**: Modern, production-ready stack (Spring Boot 3.2, PostgreSQL 15, Kafka 3.6).

6. **Security Considerations**: PCI DSS compliance through Stripe tokenization, TLS 1.3, RDS encryption.

### Minor Improvements

1. **Redis Persistence Configuration**: Specify Redis persistence strategy (AOF vs. RDB) for session data durability after ElastiCache node failure.

2. **Database Query Timeout**: Add statement timeout configuration (e.g., 10 seconds) to prevent long-running queries from blocking connections.

3. **Kafka Topic Retention Policy**: Define retention period for Kafka topics (e.g., 7 days for audit compliance).

4. **API Gateway Timeout Configuration**: Specify ALB idle timeout (should be > max API processing time).

5. **Monitoring Dashboard Links**: Include links to relevant dashboards in alert notifications for faster troubleshooting.

6. **Chaos Engineering**: Consider implementing chaos experiments (e.g., using AWS Fault Injection Simulator) to validate failure recovery procedures.

---

## Summary

This TravelHub design demonstrates solid foundational reliability practices but has critical gaps in distributed system consistency, idempotency, and disaster recovery validation. The most severe risks involve data inconsistency during the booking-payment-confirmation flow, lack of transactional outbox pattern for Kafka events, and untested backup recovery procedures.

**Immediate Action Items (Critical Priority)**:
1. Implement transactional outbox pattern for Kafka event publishing
2. Add idempotency keys to all external provider API calls and payment operations
3. Define and test RPO/RTO with quarterly disaster recovery drills
4. Configure bulkhead isolation and explicit timeouts for all external dependencies
5. Implement Kafka consumer idempotency and poison message handling

**High-Priority Follow-Ups (Significant)**:
1. Configure retry strategies with exponential backoff and jitter
2. Implement multi-tier rate limiting for self-protection
3. Add deep health checks with dependency awareness
4. Adopt expand-contract pattern for database migrations
5. Implement distributed leader election for flight status polling job
6. Enhance payment idempotency with reconciliation job

Addressing these issues will significantly improve system resilience and reduce operational risk during high-traffic scenarios and external dependency failures.
