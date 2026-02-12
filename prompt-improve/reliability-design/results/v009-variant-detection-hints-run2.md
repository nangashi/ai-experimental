# Reliability Design Review: TravelHub System

## Phase 1: Structural Analysis

### System Components
1. **API Gateway**: Entry point for mobile/web clients
2. **Booking Service**: Orchestrates external provider APIs (Amadeus, Expedia, car rental APIs)
3. **Payment Service**: Handles payment processing via Stripe and PayPal
4. **Itinerary Service**: Manages confirmed itineraries and monitors flight status
5. **Notification Service**: Delivers notifications via email (SendGrid), push (FCM), SMS (Twilio), and WebSocket (Socket.IO)

### Dependencies and Integration Points
- **External Service Dependencies (Critical)**:
  - Amadeus Flight API (search, booking, flight status polling)
  - Expedia Hotel API
  - Multiple car rental vendor APIs
  - Stripe API, PayPal REST API
  - SendGrid, Firebase Cloud Messaging, Twilio

- **Data Stores**:
  - PostgreSQL 15 (RDS Multi-AZ): Transactional data (bookings, payments, itineraries)
  - MongoDB 6.0 (DocumentDB): Search result cache (30min TTL)
  - Redis 7.2 (ElastiCache 3-node cluster): Session management, rate limiting

- **Messaging Infrastructure**:
  - Apache Kafka 3.6: Event-driven communication (BookingConfirmed, FlightDelayed events)

### Data Flow Paths
1. **Booking Flow**: User → Booking Service → Parallel external API calls → MongoDB cache → Payment Service → Kafka event → Itinerary Service → Notification Service
2. **Flight Delay Response Flow**: Background job (5min polling) → Amadeus API → Kafka event → Itinerary Service (alternative flight search) → Notification Service

### Explicitly Mentioned Reliability Mechanisms
- Resilience4j circuit breaker for external API failures
- Blue-Green deployment with ALB target group switching
- RDS Multi-AZ with automatic failover (60 seconds)
- ElastiCache 3-node cluster mode
- Spring Retry (library mentioned but no configuration details)
- Structured logging with correlation IDs

---

## Phase 2: Problem Detection

### Tier 1: Critical Issues (System-Wide Impact)

#### C-1: Transaction Boundary Ambiguity in Distributed Booking Confirmation
**Severity**: Critical
**Component**: Booking Service → Payment Service → Itinerary Service coordination

**Problem Description**:
The booking confirmation flow spans three services and two databases (PostgreSQL and Kafka) without explicit distributed transaction coordination:
1. Payment Service calls Stripe API
2. On success, Payment Service calls back to Booking Service
3. Booking Service updates PostgreSQL (status: CONFIRMED)
4. Booking Service publishes BookingConfirmed to Kafka
5. Itinerary Service consumes Kafka event and creates itinerary record

**Failure Scenarios**:
- **Scenario A**: Stripe charge succeeds, but callback to Booking Service fails (network partition) → User charged but booking remains PENDING
- **Scenario B**: PostgreSQL update succeeds, but Kafka publish fails → Booking confirmed in DB but no itinerary created, no confirmation email sent
- **Scenario C**: Kafka publish succeeds, but Itinerary Service consumer crashes before processing → Event lost if not using durable consumer groups with offset management

**Operational Impact**:
- Financial reconciliation issues: Payment collected but booking unconfirmed
- Customer experience degradation: Charged without confirmation email
- Data inconsistency requiring manual intervention and customer support escalation
- Recovery complexity: High - requires correlation of Stripe transaction logs with PostgreSQL state

**Countermeasures**:
1. **Implement Outbox Pattern**: Store BookingConfirmed event in same PostgreSQL transaction as booking status update, use CDC (Debezium) or scheduled job to publish to Kafka
2. **Add Idempotency Keys**: Include payment transaction_id as idempotency key in Booking Service callback to prevent duplicate charges during retries
3. **Implement Saga Pattern**: Define compensating transactions (refund payment if itinerary creation fails) with explicit saga state tracking
4. **Add Booking Status Reconciliation Job**: Periodic job to detect CONFIRMED bookings without corresponding itineraries and trigger recovery flow

**Reference**: Section 3 (Data Flow - 予約フロー), Section 4 (payments table with transaction_id)

---

#### C-2: Missing Idempotency Keys for Retry-Safe Booking Creation
**Severity**: Critical
**Component**: POST /api/v1/bookings endpoint, external provider API calls

**Problem Description**:
The design document specifies Spring Retry library usage but provides no idempotency mechanism for booking creation requests. When network timeouts occur during external provider API calls (Amadeus, Expedia), automatic retries may create duplicate bookings:

1. User submits POST /api/v1/bookings
2. Booking Service calls Amadeus API to create flight reservation
3. Amadeus API succeeds but response is lost due to network timeout
4. Spring Retry triggers automatic retry
5. Second Amadeus API call creates duplicate flight reservation with different provider_booking_ref

**Failure Scenarios**:
- **Scenario A**: Double-booking on provider side → User charged twice, requires manual cancellation
- **Scenario B**: Partial failure recovery → Some items (flight) duplicated, others (hotel) not, causing data inconsistency
- **Scenario C**: Retry storm during provider API degradation → Exponential increase in duplicate bookings

**Operational Impact**:
- Financial loss: Unnecessary cancellation fees for duplicate bookings
- Customer trust damage: Unexpected double charges
- Support team overload: Manual reconciliation required
- Provider relationship risk: Excessive cancellation requests may trigger rate limiting or account suspension

**Countermeasures**:
1. **Implement Client-Generated Idempotency Keys**: Add `idempotency_key` UUID to booking creation request, store in PostgreSQL bookings table with UNIQUE constraint
2. **Provider API Idempotency Headers**: Include idempotency key in Amadeus/Expedia API requests (check provider API documentation for header name)
3. **Duplicate Detection Window**: Cache processed idempotency keys in Redis with 24-hour TTL for fast duplicate rejection before DB query
4. **Audit Log for Retry Attempts**: Log all retry attempts with original request ID for forensic analysis

**Reference**: Section 5 (POST /api/v1/bookings), Section 6 (Spring Retry library mention)

---

#### C-3: Missing Timeout Specifications for External Provider APIs
**Severity**: Critical
**Component**: Booking Service external API integration

**Problem Description**:
The design specifies 30-second timeout for POST /api/v1/search endpoint but does not define individual timeouts for external provider API calls (Amadeus, Expedia, car rental vendors). The parallel search execution using CompletableFuture has a 5-second timeout, but other integration points lack timeout configuration:

1. POST /api/v1/bookings → External provider booking API (no timeout specified)
2. Itinerary Service → Amadeus Flight Status API polling (5-minute interval but no per-request timeout)
3. Payment Service → Stripe/PayPal API (no timeout specified)

**Failure Scenarios**:
- **Scenario A**: Slow provider API (>30s) during booking creation → Request exceeds user-facing 30s timeout, but backend thread remains blocked, exhausting connection pool
- **Scenario B**: Provider API network partition → Indefinite blocking of ECS task threads, preventing new request processing
- **Scenario C**: Cascading timeout → Payment Service blocks waiting for Stripe, Booking Service blocks waiting for Payment callback, user sees 504 Gateway Timeout

**Operational Impact**:
- Thread pool exhaustion → Complete service outage
- Database connection pool depletion → Secondary service failures
- Unpredictable latency → SLO violations (p95 < 500ms target missed)
- Recovery difficulty: Requires container restart to release stuck threads

**Countermeasures**:
1. **Define Hierarchical Timeout Strategy**:
   - Provider booking APIs: 20-second timeout (within user-facing 30s budget)
   - Provider search APIs: 4-second timeout (within 5s CompletableFuture timeout + 1s buffer)
   - Payment APIs: 15-second timeout
   - Flight status polling: 10-second timeout
2. **Configure RestTemplate/WebClient Timeouts**: Set `connectTimeout` and `readTimeout` explicitly in Spring HTTP client configuration
3. **Circuit Breaker Coordination**: Configure Resilience4j `slowCallDurationThreshold` to match timeout values (e.g., 90% of timeout duration)
4. **Add Timeout Monitoring**: CloudWatch metric for timeout occurrences per provider, alert on >10% timeout rate

**Reference**: Section 5 (API Design - タイムアウト: 30秒), Section 3 (検索API並列実行 - 5秒でタイムアウト)

---

#### C-4: Cache Invalidation Strategy Gap for Flight Delay Events
**Severity**: Critical
**Component**: MongoDB search_cache, Itinerary Service flight status monitoring

**Problem Description**:
The design uses MongoDB to cache search results with 30-minute TTL (Section 3, Data Flow). When flight delays or cancellations occur, the cached search results become stale but are not invalidated:

1. User searches for flights at 10:00, results cached until 10:30
2. Flight AF123 (in cached results) is cancelled at 10:15
3. Background job detects cancellation at 10:20 (5-minute polling interval)
4. User retrieves same search at 10:25 → Receives stale cache with cancelled flight
5. User attempts booking → External provider API rejects (flight unavailable)

**Failure Scenarios**:
- **Scenario A**: User books cancelled flight from cache → Booking creation fails, poor user experience
- **Scenario B**: Price increase not reflected in cache → User sees lower price, booking fails during confirmation due to price mismatch
- **Scenario C**: Schedule changes (gate, terminal) not reflected → Itinerary displays incorrect departure information

**Operational Impact**:
- Booking conversion rate degradation: Failed booking attempts increase bounce rate
- Customer support escalation: Users complain about "disappeared" flights
- Provider API rate limit risk: Repeated booking attempts for unavailable inventory
- SLA violation: Booking success rate target (>99%) at risk

**Countermeasures**:
1. **Event-Driven Cache Invalidation**: When FlightDelayed/FlightCancelled Kafka events are published, trigger cache invalidation job:
   - Query MongoDB for search_cache documents containing affected flight number
   - Delete matching cache entries or update TTL to immediate expiration
2. **Cache Entry Metadata**: Add `affected_flights: [flight_number]` field to search_cache for efficient invalidation queries
3. **Stale-While-Revalidate Pattern**: Return cached result but trigger background refresh if TTL < 5 minutes remaining
4. **Provider API Polling Frequency**: Reduce flight status polling interval from 5 minutes to 2 minutes for flights departing within 24 hours
5. **Cache Version Tags**: Include timestamp in cache key, invalidate all caches older than last known provider API update

**Reference**: Section 3 (Data Flow - MongoDB検索結果キャッシュ30分TTL), Section 4 (MongoDB search_cache collection), Section 3 (フライト遅延対応フロー - 5分間隔ポーリング)

---

#### C-5: WebSocket Connection Recovery Strategy Not Defined
**Severity**: Critical
**Component**: Notification Service WebSocket (Socket.IO) integration

**Problem Description**:
The design specifies WebSocket for real-time updates (Section 3, Notification Service) but does not address connection recovery, state synchronization, or message delivery guarantees:

1. User connected via WebSocket receives flight delay notification
2. Network interruption causes WebSocket disconnection (mobile user in subway)
3. User reconnects 10 minutes later
4. Missing recovery mechanism → User unaware of subsequent updates (gate change, alternative flight proposal)

**Failure Scenarios**:
- **Scenario A**: Long-lived disconnection during critical updates → User misses flight due to gate change notification loss
- **Scenario B**: Rapid reconnection attempts during network instability → Server resource exhaustion from connection handshake overhead
- **Scenario C**: Duplicate message delivery after reconnection → User receives multiple identical notifications, confusion

**Operational Impact**:
- Customer safety risk: Missed critical travel updates
- Customer experience degradation: Perceived unreliability of real-time notifications
- Server stability risk: Connection storm during mass disconnection events (AWS region network issue)
- Support escalation: Users claim "app didn't notify me"

**Countermeasures**:
1. **Implement Reconnection Strategy**:
   - Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
   - Add jitter (±20%) to prevent thundering herd
   - Maximum 10 retry attempts before prompting user to manually refresh
2. **Session State Synchronization**:
   - Store WebSocket session state in Redis: `ws_session:{user_id}` → `{last_ack_message_id, connected_at}`
   - On reconnection, query missed messages: `SELECT * FROM notifications WHERE user_id = ? AND created_at > ?`
   - Send backlog as batch (max 50 messages) with `type: "backlog"`
3. **Message Delivery Guarantees**:
   - Implement at-least-once delivery with client-side deduplication
   - Include `message_id` (UUID) in all WebSocket messages
   - Client maintains `last_processed_message_id` in localStorage
   - Server-side notification table tracks `delivery_status` (PENDING/DELIVERED/ACKNOWLEDGED)
4. **Connection Health Monitoring**:
   - Heartbeat ping/pong every 30 seconds
   - Detect zombie connections (no pong response within 60s) and force disconnect
   - CloudWatch metric: `websocket_reconnection_rate`, alert on >20% reconnections within 5min window

**Reference**: Section 3 (Notification Service - WebSocket接続によるリアルタイム更新 Socket.IO)

---

#### C-6: Database Schema Backward Compatibility Not Addressed for Rolling Updates
**Severity**: Critical
**Component**: Blue-Green deployment strategy, Flyway migrations

**Problem Description**:
The design specifies Blue-Green deployment (Section 6) but does not define database schema migration strategy for rolling updates. During deployment:

1. Version N (old) running with schema V1
2. Flyway migration to schema V2 applied
3. Version N+1 (new) deployed to Green environment, starts using V2 schema
4. Blue-to-Green traffic switch occurs gradually
5. Version N instances still running attempt to read V2 schema → Incompatibility errors

**Failure Scenarios**:
- **Scenario A**: New column with NOT NULL constraint added → Old code fails INSERT operations (no value provided)
- **Scenario B**: Column renamed → Old code queries non-existent column, SQL exceptions
- **Scenario C**: JSONB field structure change (e.g., adding required nested key) → Old code parses incomplete JSON, NullPointerException
- **Scenario D**: Rollback after schema change → New schema incompatible with old code, rollback blocked

**Operational Impact**:
- Deployment failure requiring emergency rollback
- Data corruption if old code writes invalid data to new schema
- Zero-downtime deployment goal violated (requires full outage for schema-incompatible changes)
- Rollback complexity: Database schema rollback required (risky operation)

**Countermeasures**:
1. **Implement Expand-Contract Pattern**:
   - **Phase 1 (Expand)**: Add new column/table without breaking old code (e.g., add nullable column)
   - **Phase 2 (Migrate)**: Deploy code reading from both old and new schema
   - **Phase 3 (Contract)**: Remove old column/table after all traffic on new code
2. **Schema Change Review Checklist**:
   - Is new column nullable or has default value?
   - Are renamed columns aliased in SQL queries for backward compatibility?
   - Are deleted columns soft-deleted first (mark as deprecated, remove in next release)?
3. **Flyway Migration Validation**:
   - Staging environment schema applied 24 hours before production
   - Automated integration tests run against both V1 and V2 schemas
   - Schema compatibility test: Old code binary tested against new schema
4. **Rollback Data Compatibility**:
   - Add schema version tracking: `schema_versions` table with `applied_at` timestamp
   - Document maximum rollback window (e.g., 7 days) based on schema change history
   - Pre-deployment validation: Check if new schema allows rollback to previous version

**Reference**: Section 6 (デプロイメント方針 - Blue-Green デプロイメント, Flyway)

---

### Tier 2: Significant Issues (Partial System Impact)

#### S-1: Retry Strategy Lacks Exponential Backoff and Jitter Configuration
**Severity**: Significant
**Component**: Spring Retry configuration for external API calls

**Problem Description**:
The design mentions Spring Retry library usage (Section 2) but does not specify retry configuration (backoff strategy, max attempts, jitter). Default retry behavior may exacerbate provider API failures:

1. Provider API experiences degradation (latency spike)
2. Multiple TravelHub instances trigger immediate retries
3. Synchronized retry attempts create thundering herd
4. Provider API receives burst traffic, further degradation
5. Circuit breaker opens but damage already done

**Failure Scenarios**:
- **Scenario A**: Fixed retry intervals → All instances retry simultaneously, amplifying load on struggling provider
- **Scenario B**: No jitter → Retry waves synchronized with monitoring intervals (e.g., every 5 minutes), periodic traffic spikes
- **Scenario C**: Excessive retry attempts → Provider API rate limiting triggers, legitimate traffic rejected

**Operational Impact**:
- Provider relationship damage: TravelHub flagged as abusive traffic source
- Extended outage duration: Retry storms prevent provider API recovery
- SLA violation: Booking service unavailable during provider API degradation
- Cost increase: Unnecessary API calls consume quota/billable requests

**Countermeasures**:
1. **Configure Exponential Backoff with Jitter**:
   ```java
   @Retryable(
     maxAttempts = 3,
     backoff = @Backoff(
       delay = 1000,        // Initial delay 1s
       multiplier = 2,      // Exponential: 1s, 2s, 4s
       maxDelay = 10000,    // Cap at 10s
       random = true        // Add jitter
     )
   )
   ```
2. **Selective Retry by Error Type**:
   - Retry on: 503 Service Unavailable, 504 Gateway Timeout, network errors
   - Do NOT retry on: 400 Bad Request, 401 Unauthorized, 404 Not Found (client errors)
3. **Circuit Breaker Integration**:
   - Configure Resilience4j `slowCallRateThreshold` (50% slow calls → circuit opens)
   - `waitDurationInOpenState`: 30 seconds before half-open state
   - Coordinate with retry: Circuit breaker should open before exhausting retry attempts
4. **Retry Budget Tracking**:
   - CloudWatch metric: `external_api_retry_rate` per provider
   - Alert on retry rate >20% (indicates systemic provider issue)
   - Implement client-side rate limiting: Max 10 retries/second per provider across all instances

**Reference**: Section 2 (主要ライブラリ - Spring Retry), Section 6 (エラーハンドリング方針 - Resilience4j サーキットブレーカー)

---

#### S-2: Missing Dead Letter Queue Handling for Kafka Consumer Failures
**Severity**: Significant
**Component**: Kafka event processing (BookingConfirmed, FlightDelayed events)

**Problem Description**:
The design uses Kafka for event-driven communication (Section 2, Section 3) but does not address failed message processing:

1. Itinerary Service consumes BookingConfirmed event
2. Processing fails (e.g., PostgreSQL connection timeout, validation error)
3. Default Kafka consumer retry exhausted
4. Message not processed, no itinerary created
5. No mechanism to detect or recover from processing failure

**Failure Scenarios**:
- **Scenario A**: Transient database failure → Multiple events lost during outage window
- **Scenario B**: Poison message (malformed JSON, schema mismatch) → Consumer repeatedly crashes, blocks subsequent events in partition
- **Scenario C**: Silent failure → Message marked as processed but side effects (itinerary creation, email) not executed

**Operational Impact**:
- Data loss: Confirmed bookings without itineraries
- Customer experience degradation: No confirmation email received
- Support team overload: Manual itinerary creation required
- Debugging difficulty: No visibility into failed message content

**Countermeasures**:
1. **Implement Dead Letter Queue (DLQ)**:
   - Create Kafka topic: `booking-events-dlq`
   - On processing failure after 3 retries, publish to DLQ with error metadata:
     ```json
     {
       "original_topic": "booking-confirmed",
       "original_message": {...},
       "error_type": "DatabaseTimeoutException",
       "error_message": "Connection timeout after 10s",
       "retry_count": 3,
       "timestamp": "2026-02-11T10:00:00Z"
     }
     ```
2. **DLQ Monitoring and Recovery**:
   - CloudWatch alarm: DLQ message count >0 → PagerDuty alert
   - Admin dashboard: View DLQ messages, trigger manual reprocessing
   - Automated retry job: Attempt DLQ reprocessing every 6 hours with exponential backoff
3. **Poison Message Detection**:
   - If same message fails >5 times, quarantine to separate topic: `booking-events-poison`
   - Manual review required before reprocessing
   - Add schema validation before business logic execution
4. **Processing Guarantee Tracking**:
   - Add `processing_status` column to bookings table: PENDING_EVENT/PROCESSED/FAILED
   - Reconciliation job: Detect CONFIRMED bookings with PENDING_EVENT status >10 minutes old
   - Trigger manual event replay or direct processing bypass

**Reference**: Section 2 (メッセージング - Apache Kafka 3.6), Section 3 (Data Flow - Kafkaイベント発行/消費)

---

#### S-3: Missing Bulkhead Isolation Between Critical and Non-Critical Operations
**Severity**: Significant
**Component**: ECS task resource allocation, thread pool configuration

**Problem Description**:
The design specifies ECS Auto Scaling (CPU 70% threshold, 3-20 tasks) but does not isolate resource pools for critical vs. non-critical operations:

1. Background flight status polling job (non-critical) executes every 5 minutes
2. Polling iterates over all active itineraries (potentially thousands)
3. Thread pool exhaustion from polling operations
4. Incoming booking creation requests (critical) blocked waiting for available threads
5. Revenue-generating operations starved by operational monitoring tasks

**Failure Scenarios**:
- **Scenario A**: Flash sale traffic spike → All threads busy processing bookings, health check endpoint times out, ALB marks instance unhealthy, cascading failure
- **Scenario B**: Slow external API during polling → Threads blocked on Amadeus Flight Status API, new booking requests queue indefinitely
- **Scenario C**: Memory leak in background job → Gradual memory exhaustion affects all operations equally, no isolation

**Operational Impact**:
- Revenue loss: Critical booking endpoints unavailable during high traffic
- SLA violation: API availability drops below 99.9% target
- Monitoring blind spots: Health check failures prevent accurate capacity planning
- Recovery complexity: Difficult to identify which operation type caused resource exhaustion

**Countermeasures**:
1. **Implement Thread Pool Bulkheads**:
   ```java
   // Critical operations (user-facing APIs)
   ThreadPoolExecutor bookingExecutor = new ThreadPoolExecutor(
     10,  // core threads
     50,  // max threads
     60, TimeUnit.SECONDS,
     new LinkedBlockingQueue<>(100)
   );

   // Non-critical operations (background jobs)
   ThreadPoolExecutor monitoringExecutor = new ThreadPoolExecutor(
     2,   // core threads
     5,   // max threads (limited)
     300, TimeUnit.SECONDS,
     new LinkedBlockingQueue<>(10)
   );
   ```
2. **Resource Quota Enforcement**:
   - Booking operations: 80% CPU/memory quota
   - Background jobs: 15% CPU/memory quota
   - Health checks: 5% CPU/memory quota (highest priority)
3. **Separate ECS Services for Background Jobs**:
   - Deploy flight status polling as dedicated ECS service
   - Independent scaling policy (based on itinerary count, not CPU)
   - Failure isolation: Background job crash does not affect user-facing services
4. **Circuit Breaker for Background Jobs**:
   - If background job execution time >2x expected duration, skip current iteration
   - CloudWatch alarm: `background_job_skip_rate` >10% → Investigate scaling issues

**Reference**: Section 7 (可用性・スケーラビリティ - ECS Auto Scaling, CPU使用率70%), Section 3 (フライト遅延対応フロー - 5分間隔ポーリング)

---

#### S-4: Rate Limiting Configuration Missing for Self-Protection
**Severity**: Significant
**Component**: API Gateway, Redis rate limiting

**Problem Description**:
The design mentions Redis for rate limiting (Section 2) but does not specify rate limit configuration, enforcement points, or backpressure handling:

1. Partner application (corporate travel agency) integrates with TravelHub API
2. Partner bug causes infinite retry loop (1000 req/sec)
3. No rate limiting → All requests forwarded to backend services
4. Database connection pool exhausted
5. Legitimate user requests fail (503 Service Unavailable)

**Failure Scenarios**:
- **Scenario A**: Abuse/DDoS attack → API overwhelmed, SLA violated for all users
- **Scenario B**: Internal service misconfiguration → Inter-service calls trigger cascading overload
- **Scenario C**: No backpressure signal → Client continues sending requests at high rate, exacerbating problem

**Operational Impact**:
- Service outage affecting all users (not just abusive client)
- Revenue loss during outage window
- Provider API quota exhaustion (billable overage charges)
- Reputation damage: News coverage of "TravelHub down"

**Countermeasures**:
1. **Implement Tiered Rate Limiting**:
   - **Anonymous users**: 10 req/min per IP
   - **Authenticated users**: 100 req/min per user_id
   - **Corporate partners**: 1000 req/min per API key
   - **Internal services**: 5000 req/min per service (circuit breaker coordination)
2. **Rate Limit Enforcement Points**:
   - API Gateway (Spring Cloud Gateway): Filter `RedisRateLimiter` before routing
   - Service-level (Resilience4j RateLimiter): Protect specific endpoints (POST /bookings)
   - Database level: pg_bouncer connection pooling with max connections per user
3. **Backpressure Signaling**:
   - Return `429 Too Many Requests` with `Retry-After` header (seconds until quota reset)
   - Include rate limit headers in all responses:
     ```
     X-RateLimit-Limit: 100
     X-RateLimit-Remaining: 42
     X-RateLimit-Reset: 1644598800
     ```
4. **Adaptive Rate Limiting**:
   - During high load (CPU >80%), reduce rate limits by 50%
   - CloudWatch metric: `rate_limit_rejections` per client
   - Auto-ban: >1000 rejections in 1 minute → 1-hour IP block

**Reference**: Section 2 (データベース - Redis 7.2 レート制限), Section 7 (SLA - 99.9% 稼働率)

---

#### S-5: Connection Pool Configuration Gap During Auto Scaling Events
**Severity**: Significant
**Component**: PostgreSQL connection pool, ECS Auto Scaling coordination

**Problem Description**:
The design specifies PostgreSQL connection pool max 100 connections (Section 7) and ECS Auto Scaling 3-20 tasks, but does not address connection pool sizing during scale-out:

1. Traffic spike triggers ECS Auto Scaling (3 tasks → 10 tasks)
2. Each task configures 100-connection pool
3. Total connections: 10 × 100 = 1000 connections
4. RDS instance max_connections limit (default for db.r6g.xlarge: 500) exceeded
5. New task startup fails with "FATAL: too many connections"
6. Auto Scaling ineffective, SLA violated

**Failure Scenarios**:
- **Scenario A**: Scale-out during traffic spike → New tasks cannot connect to database, remain unhealthy
- **Scenario B**: Connection leak in application → Gradual connection exhaustion, no capacity for new tasks
- **Scenario C**: Uneven connection distribution → Some tasks hold 100 connections (idle), others queue requests

**Operational Impact**:
- Auto Scaling failure: Additional capacity unusable
- SLA violation: p95 latency degrades despite horizontal scaling
- Revenue loss: Booking requests fail during peak traffic
- Operational complexity: Manual intervention required to restart tasks with adjusted connection pool

**Countermeasures**:
1. **Dynamic Connection Pool Sizing**:
   - Calculate per-task connections: `max_connections = RDS_MAX_CONNECTIONS / MAX_ECS_TASKS`
   - Example: 500 / 20 = 25 connections per task
   - Configure HikariCP:
     ```properties
     spring.datasource.hikari.maximum-pool-size=25
     spring.datasource.hikari.minimum-idle=5
     ```
2. **Connection Pool Monitoring**:
   - CloudWatch custom metric: `db_connections_active` per ECS task
   - Alert on `total_connections > RDS_MAX_CONNECTIONS * 0.8` (400/500)
   - Publish connection pool stats to CloudWatch every 60 seconds
3. **RDS Connection Limit Increase**:
   - Review RDS instance max_connections parameter (formula: `DBInstanceClassMemory / 9531392`)
   - For db.r6g.xlarge (32GB): `(32 * 1024^3) / 9531392 ≈ 3600` connections possible
   - Increase `max_connections` RDS parameter to 500-1000 based on load testing
4. **Connection Pooler (PgBouncer)**:
   - Deploy PgBouncer between ECS tasks and RDS (transaction pooling mode)
   - PgBouncer holds 25 connections to RDS, serves 100 application connections per task
   - Reduces RDS connection count while maintaining application throughput

**Reference**: Section 7 (パフォーマンス目標 - PostgreSQL接続プール最大100接続), Section 7 (スケーリング - 最小3タスク、最大20タスク)

---

#### S-6: Graceful Degradation Paths Not Defined for Dependency Failures
**Severity**: Significant
**Component**: Booking Service external provider API integration

**Problem Description**:
The design specifies circuit breaker with fallback to alternative providers "when possible" (Section 6) but does not define specific graceful degradation strategies:

1. Amadeus Flight API circuit breaker opens (error rate >50%)
2. Design mentions fallback but does not specify:
   - Which alternative providers exist?
   - Fallback selection criteria (price, availability, latency)?
   - How to handle no available alternatives?
3. User sees generic error "Service temporarily unavailable"

**Failure Scenarios**:
- **Scenario A**: All flight providers unavailable → Complete booking service outage
- **Scenario B**: Fallback provider has different data schema → Parsing errors, incorrect flight details displayed
- **Scenario C**: Fallback provider has lower rate limit → Circuit breaker thrashing (primary fails → fallback saturated → primary retried)

**Operational Impact**:
- Poor user experience: No actionable error message
- Revenue loss: Users abandon booking during provider outage
- Support escalation: Users unclear if outage is temporary or permanent
- Recovery complexity: Manual coordination with multiple providers to restore service

**Countermeasures**:
1. **Define Provider Priority Matrix**:
   ```yaml
   flight_providers:
     primary: amadeus
     fallback_tier1: [skyscanner, kayak]
     fallback_tier2: [google_flights]

   hotel_providers:
     primary: expedia
     fallback_tier1: [booking_com]
     fallback_tier2: [agoda]
   ```
2. **Implement Degraded Mode Responses**:
   - **Scenario A (Partial availability)**: Return results from available providers only, display banner "Limited results: Some providers unavailable"
   - **Scenario B (Complete outage)**: Return cached popular routes from Redis (last 24 hours of successful searches), mark as "Estimated availability"
   - **Scenario C (Critical failure)**: Disable booking creation, allow search-only mode with disclaimer
3. **Provider Health Scoring**:
   - Track per-provider metrics: `success_rate`, `p95_latency`, `circuit_breaker_state`
   - Dynamic provider selection: Route to healthiest provider first, fallback to next tier
   - Avoid fallback thrashing: Once fallback activated, maintain for minimum 5 minutes before re-trying primary
4. **User Communication Strategy**:
   - Clear error messages: "Flight search temporarily limited. Booking service available for hotels and car rentals."
   - Status page integration: Publish provider health status to public status page
   - Proactive notification: Email users with pending PENDING bookings if provider outage exceeds 30 minutes

**Reference**: Section 6 (エラーハンドリング方針 - 外部API障害時は代替プロバイダーへフォールバック)

---

#### S-7: Replication Lag Monitoring Missing for RDS Multi-AZ Read Operations
**Severity**: Significant
**Component**: PostgreSQL RDS Multi-AZ, read replica lag (if future feature)

**Problem Description**:
The design specifies RDS Multi-AZ with automatic failover (Section 7) but does not address replication lag monitoring. While Multi-AZ uses synchronous replication (no lag), the design may expand to read replicas for scalability:

1. Future: Read replica added for analytics queries
2. Replication lag occurs (network partition, high write load)
3. User creates booking (writes to primary)
4. Immediately queries itinerary from read replica
5. Itinerary not yet replicated → User sees "Booking not found" error

**Failure Scenarios**:
- **Scenario A**: Read-after-write inconsistency → User refreshes booking confirmation page, sees "pending" status inconsistently
- **Scenario B**: Analytics report uses stale data → Revenue metrics incorrect, business decisions impacted
- **Scenario C**: Monitoring query lag → Health check queries read replica, reports stale status, triggers false alerts

**Operational Impact**:
- Customer experience degradation: Intermittent "booking not found" errors
- Data integrity perception issues: Users distrust platform reliability
- Operational complexity: Debugging read-after-write consistency is difficult
- Monitoring accuracy issues: Health checks report false negatives

**Countermeasures**:
1. **Implement Read-Your-Writes Consistency**:
   - After write operation, store `last_write_timestamp` in user session (Redis)
   - On read request, compare replica lag with `last_write_timestamp`
   - If replica lag > session write time, route read to primary (consistency > performance)
2. **Replication Lag Monitoring**:
   - CloudWatch metric: `ReplicaLag` (available from RDS)
   - Alert on lag >5 seconds (indicates issue)
   - Dashboard: Per-replica lag visualization
3. **Lag-Aware Query Routing**:
   - Label queries by consistency requirement:
     - `STRONG`: Always route to primary (booking creation confirmation)
     - `EVENTUAL`: Allow replica with lag <10s (search history, analytics)
     - `NONE`: Allow any replica (marketing content)
4. **Failover Lag Handling**:
   - During Multi-AZ failover, standby may have replication lag (rare but possible)
   - Implement retry with primary-read-only mode detection
   - Display banner: "Booking service in read-only mode during maintenance" if primary unavailable

**Reference**: Section 7 (可用性・スケーラビリティ - RDS Multi-AZ 構成、自動フェイルオーバー)

---

### Tier 3: Moderate Issues (Operational Improvement)

#### M-1: SLO Error Budget Not Defined for Proactive Alerting
**Severity**: Moderate
**Component**: CloudWatch monitoring, SLO definition

**Problem Description**:
The design specifies SLO targets (API availability >99.9%, p95 latency <500ms, payment success rate >99%) in Section 7 but does not define error budgets or burn rate alerting:

1. SLO: 99.9% availability = 43 minutes downtime per month
2. Partial outage: 5% error rate for 2 hours = 6 minutes of error budget consumed
3. No proactive alert until hard threshold crossed (error rate >5% in current design)
4. Error budget exhausted mid-month without early warning

**Operational Impact**:
- Reactive alerting: Incident detected after SLO breach
- SLA financial penalties: Unable to prevent customer-facing SLA violations
- Insufficient prioritization: Engineering team unaware of error budget status when planning maintenance

**Countermeasures**:
1. **Define Error Budget Policy**:
   ```yaml
   slo:
     availability: 99.9%
     measurement_window: 30 days
     error_budget: 43 minutes/month

   burn_rate_alerts:
     critical: 10x burn rate (4.3 min/hour) → PagerDuty
     high: 5x burn rate (2.15 min/hour) → Slack
     moderate: 2x burn rate (0.86 min/hour) → Email
   ```
2. **Error Budget Tracking Dashboard**:
   - CloudWatch dashboard: Current error budget remaining (minutes)
   - Burn rate graph: Last 24 hours, 7 days, 30 days
   - Projected exhaustion date based on current burn rate
3. **Error Budget Policy Enforcement**:
   - If error budget <25%, freeze non-critical deployments
   - If error budget <10%, declare incident and prioritize reliability work
   - If error budget exhausted, trigger blameless postmortem
4. **Multi-Window Alerting** (Google SRE approach):
   - 1-hour window: Fast detection of severe issues
   - 6-hour window: Moderate issues
   - 3-day window: Slow degradation trends

**Reference**: Section 7 (監視・アラート - SLO定義)

---

#### M-2: Distributed Tracing Not Configured for Cross-Service Debugging
**Severity**: Moderate
**Component**: Structured logging, correlation IDs

**Problem Description**:
The design specifies correlation_id in structured logs (Section 6) but does not implement distributed tracing to track requests across service boundaries:

1. User booking request fails with "Payment processing error"
2. Correlation ID logged: `abc-123`
3. Engineer searches logs across Booking Service, Payment Service, Stripe
4. Manual correlation required: No automated trace visualization
5. Debugging time: 30 minutes for simple issue

**Operational Impact**:
- Slow incident resolution: Mean time to detect (MTTD) and mean time to resolve (MTTR) increase
- Incomplete root cause analysis: Difficult to identify exact failure point in distributed flow
- Operational overhead: Manual log aggregation across multiple services

**Countermeasures**:
1. **Implement AWS X-Ray Distributed Tracing**:
   - Integrate Spring Cloud Sleuth with X-Ray exporter
   - Automatic trace ID propagation across service calls
   - Visualize trace map: User request → API Gateway → Booking Service → Payment Service → Stripe
2. **Trace Sampling Strategy**:
   - Sample 100% of failed requests (status code >=400)
   - Sample 10% of successful requests (reduce cost)
   - Sample 100% of requests with p99 latency (>1s)
3. **Custom Trace Annotations**:
   - Add business context: `booking_id`, `payment_method`, `provider` as trace metadata
   - Enable filtering in X-Ray console: "Show all traces where payment_method=STRIPE and status=FAILED"
4. **Tracing for Background Jobs**:
   - Generate trace context for Kafka consumer processing
   - Link parent trace (booking creation) to child trace (itinerary creation)

**Reference**: Section 6 (ロギング方針 - correlation_id トレース用UUID)

---

#### M-3: Health Check Design Lacks Multi-Level Dependency Verification
**Severity**: Moderate
**Component**: ALB health checks, service health endpoints

**Problem Description**:
The design mentions health checks (Section 7 - ALB monitors instance health) but does not specify health check design with dependency verification:

1. Health check: GET /health → Returns 200 OK if service process running
2. PostgreSQL connection pool exhausted (all connections leaking)
3. Service process healthy, but cannot serve requests
4. ALB marks instance healthy → Routes traffic to broken instance
5. All user requests fail with 500 Internal Server Error

**Failure Scenarios**:
- **Scenario A**: Database connectivity lost → Service reports healthy, requests fail
- **Scenario B**: Redis unavailable → Session management broken, users cannot authenticate
- **Scenario C**: Kafka producer blocked → Events not published, itineraries not created

**Operational Impact**:
- False healthy signals: ALB routes traffic to non-functional instances
- Cascading failures: Broken instances remain in rotation, overload other instances
- Slow failure detection: Requires user-facing error rate increase to trigger alerts

**Countermeasures**:
1. **Implement Tiered Health Checks**:
   ```
   GET /health/liveness  → Basic process health (ALB uses this)
   GET /health/readiness → Dependency health (used for routing decision)
   GET /health/deep      → Full integration test (manual debugging)
   ```
2. **Readiness Check Dependencies**:
   - PostgreSQL: Execute `SELECT 1` query, verify response <100ms
   - Redis: Execute `PING` command, verify response <50ms
   - Kafka: Check producer buffer availability (not full)
   - Return 503 Service Unavailable if any dependency fails
3. **Liveness vs. Readiness Separation**:
   - ALB target group health check: Use `/health/liveness` (simple, fast)
   - ECS task health check: Use `/health/readiness` (comprehensive)
   - Prevents ECS from killing tasks during transient dependency failures
4. **Health Check Timeout Configuration**:
   - Liveness: 2-second timeout, 3 consecutive failures to mark unhealthy
   - Readiness: 5-second timeout (allows for dependency checks)
   - Health check interval: 10 seconds (ALB default 30s may be too slow)

**Reference**: Section 7 (監視・アラート - 記述なし)

---

#### M-4: Incident Response Runbooks Not Documented
**Severity**: Moderate
**Component**: Operational procedures, on-call playbooks

**Problem Description**:
The design specifies monitoring and alerting (Section 7) but does not document incident response procedures:

1. 3:00 AM: PagerDuty alert "API error rate >5%"
2. On-call engineer woken up
3. No runbook available: Engineer unfamiliar with TravelHub architecture
4. Guessing: Restart ECS tasks? Check external provider status?
5. Incident resolution delayed by 45 minutes (trial and error)

**Operational Impact**:
- Extended MTTR: Lack of documented procedures prolongs outages
- Human error risk: Tired engineers make mistakes without clear guidance
- Knowledge silos: Only senior engineers know how to resolve complex issues

**Countermeasures**:
1. **Create Incident Response Runbooks**:
   - **High API Error Rate**: Check external provider circuit breaker status → Review CloudWatch logs for error patterns → Restart ECS tasks if memory leak suspected
   - **Database Connection Exhaustion**: Query `pg_stat_activity` for long-running queries → Kill blocking queries → Scale up ECS tasks if load-related
   - **Payment Processing Failures**: Check Stripe API status page → Review payment service logs → Contact Stripe support with transaction IDs
2. **Runbook Integration**:
   - Link runbooks in PagerDuty alert descriptions
   - Store runbooks in Git repository (version controlled)
   - Regular runbook review: Quarterly update based on recent incidents
3. **Automated Remediation**:
   - Auto-restart: If ECS task health check fails >3 times, auto-restart task
   - Auto-scale: If CPU >90% for 5 minutes, trigger emergency scale-out (ignore normal 70% threshold)
   - Auto-failover: If primary RDS unreachable, trigger manual failover command (requires approval)
4. **Blameless Postmortem Process**:
   - After each incident, document timeline, root cause, action items
   - Share learnings: Weekly incident review meeting
   - Track action items: Jira tickets linked to incident reports

**Reference**: Section 7 (監視・アラート - PagerDuty 通知)

---

#### M-5: Backup Validation and RPO/RTO Testing Not Defined
**Severity**: Moderate
**Component**: RDS automated backups, disaster recovery

**Problem Description**:
The design specifies RDS Multi-AZ (Section 7) but does not address backup validation or disaster recovery testing:

1. RDS automated backups enabled (default: 7-day retention)
2. No restore testing performed
3. Disaster scenario: Accidental `DROP TABLE bookings` in production
4. Restore attempt from backup
5. Discovery: Backup corrupted or restore process unknown

**Operational Impact**:
- Data loss risk: Untested backups may be unusable during crisis
- Extended RTO: Learning restore procedure during incident prolongs downtime
- Compliance violation: Financial regulations (PCI DSS) require tested backup procedures

**Countermeasures**:
1. **Define RPO/RTO Targets**:
   - **RPO (Recovery Point Objective)**: 5 minutes (via RDS automated backups + transaction log shipping)
   - **RTO (Recovery Time Objective)**: 4 hours (restore from backup + validation)
2. **Automated Backup Validation**:
   - Monthly job: Restore latest RDS backup to test environment
   - Run automated test suite against restored database
   - Verify data integrity: Row counts, foreign key constraints, JSONB schema
3. **Disaster Recovery Drill**:
   - Quarterly DR exercise: Simulate production outage
   - Practice restore procedure: Document time taken for each step
   - Update runbooks based on lessons learned
4. **Backup Monitoring**:
   - CloudWatch alarm: RDS backup failure (rare but possible)
   - Verify backup retention: Ensure 7-day backups not accidentally deleted
   - Cross-region backup replication: Copy daily backup to secondary AWS region (protect against regional outage)

**Reference**: Section 7 (可用性・スケーラビリティ - RDS Multi-AZ 構成)

---

#### M-6: Capacity Planning and Load Testing Not Addressed
**Severity**: Moderate
**Component**: ECS Auto Scaling, database sizing

**Problem Description**:
The design specifies Auto Scaling (3-20 tasks) but does not address capacity planning or load testing methodology:

1. Launch: System scaled to 3 ECS tasks (minimum)
2. Holiday season traffic spike: 10x expected load
3. Auto Scaling insufficient: Max 20 tasks cannot handle load
4. Database becomes bottleneck: CPU >95%, queries queuing
5. Service outage during peak revenue period

**Operational Impact**:
- Revenue loss: Booking service unavailable during critical business periods
- Poor user experience: Slow response times, timeouts
- Emergency scaling: Manual intervention required, delayed response

**Countermeasures**:
1. **Establish Load Testing Practice**:
   - Monthly load test: Simulate expected peak traffic (2x current baseline)
   - Quarterly stress test: Identify breaking point (10x baseline)
   - Tools: JMeter, Gatling for HTTP load generation
   - Scenarios: Booking creation flow (most resource-intensive)
2. **Capacity Planning Model**:
   - Metric: Requests per second (RPS) per ECS task
   - Current capacity: 3 tasks × 50 RPS = 150 RPS minimum
   - Peak capacity: 20 tasks × 50 RPS = 1000 RPS maximum
   - Traffic projection: Analyze historical data, project growth (20% YoY)
   - Buffer: Maintain 40% headroom (max capacity should be 1.4x expected peak)
3. **Database Capacity Planning**:
   - Current: RDS instance class not specified (assume db.r6g.xlarge)
   - Monitor: CPU, IOPS, connection count during load test
   - Identify bottleneck: If CPU >80% before reaching target RPS, upgrade instance class
   - Vertical scaling runway: Plan upgrade path (xlarge → 2xlarge → 4xlarge)
4. **Auto Scaling Policy Refinement**:
   - Review 70% CPU threshold: May be too conservative (triggers unnecessary scaling)
   - Add custom metric scaling: Scale based on request queue depth or p95 latency
   - Pre-scale for known events: Manually scale up before marketing campaigns

**Reference**: Section 7 (スケーリング - 最小3タスク、最大20タスク)

---

### Tier 4: Minor Improvements and Positive Aspects

#### Positive Aspects
1. **Circuit Breaker Implementation**: Resilience4j integration for external API fault isolation demonstrates proactive reliability design
2. **Multi-AZ Database Configuration**: PostgreSQL RDS Multi-AZ with automatic failover provides strong availability foundation
3. **Structured Logging with Correlation IDs**: Enables request tracing across service boundaries, critical for distributed debugging
4. **Blue-Green Deployment Strategy**: Zero-downtime deployment approach with rollback capability (10 minutes) reduces deployment risk
5. **Multiple Notification Channels**: Redundancy in notification delivery (email, push, SMS, WebSocket) improves communication reliability

#### Minor Improvements
1. **Configuration as Code**: Consider using AWS CDK or Terraform to version control infrastructure configuration (ECS task definitions, RDS parameters, ALB rules)
2. **Feature Flags**: Implement feature flag system (LaunchDarkly, AWS AppConfig) for progressive rollout of risky changes, enabling faster rollback without deployment
3. **Canary Deployment**: Enhance Blue-Green strategy with canary deployment (route 5% traffic to new version, monitor for 30 minutes before full rollout)
4. **Log Retention Policy**: Define CloudWatch Logs retention period (default: infinite retention, costly) - recommend 90 days for operational logs, 1 year for audit logs
5. **Secrets Management**: Document secrets rotation strategy for Stripe API keys, database credentials (use AWS Secrets Manager automatic rotation)

---

## Summary of Critical Recommendations

The TravelHub design demonstrates strong foundational reliability practices (circuit breakers, Multi-AZ databases, structured logging) but has significant operational readiness gaps:

**Immediate Priority (Pre-Launch Blockers)**:
1. Implement distributed transaction coordination (outbox pattern) for booking confirmation flow to prevent payment/booking inconsistency
2. Add idempotency keys to booking creation API to prevent double-booking during retries
3. Define explicit timeout configuration for all external API calls (Amadeus, Stripe, Expedia)
4. Implement cache invalidation strategy for flight delay events to prevent stale search results
5. Design WebSocket reconnection strategy with message backlog delivery for real-time notification reliability
6. Adopt expand-contract pattern for database schema changes to enable zero-downtime deployments

**High Priority (Launch Week)**:
7. Configure retry strategies with exponential backoff and jitter for external API calls
8. Implement dead letter queue handling for Kafka consumer failures
9. Add bulkhead isolation between critical (booking) and non-critical (monitoring) operations
10. Configure rate limiting for API self-protection and abuse prevention
11. Coordinate connection pool sizing with ECS Auto Scaling limits

**Post-Launch Improvements**:
12. Establish error budget tracking and burn rate alerting for proactive SLO management
13. Implement distributed tracing (AWS X-Ray) for cross-service debugging
14. Create multi-level health checks with dependency verification
15. Document incident response runbooks and establish on-call rotation
16. Establish regular backup validation and disaster recovery testing procedures

The design's architecture is fundamentally sound, but these reliability enhancements are essential for production readiness at 99.9% SLA scale.
