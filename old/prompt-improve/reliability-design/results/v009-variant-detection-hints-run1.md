# Reliability Design Review: TravelHub システム設計書

## Phase 1: Structural Analysis

### System Components Identified
1. **API Gateway**: Entry point for mobile/web clients
2. **Booking Service**: Orchestrates external provider APIs (Amadeus, Expedia, car rental)
3. **Payment Service**: Handles Stripe/PayPal integration
4. **Itinerary Service**: Manages confirmed itineraries, monitors flight status
5. **Notification Service**: Sends email (SendGrid), push (FCM), SMS (Twilio), WebSocket (Socket.IO)

### Data Flow Paths
- **Search Flow**: Client → API Gateway → Booking Service → Parallel external API calls → MongoDB cache (30min TTL)
- **Booking Flow**: Booking creation (PENDING) → Payment → Callback → CONFIRMED → Kafka event → Itinerary creation → Notification
- **Flight Delay Flow**: Background job (5min polling) → Flight Status API → Kafka event → Alternative flight search → User notification

### External Dependencies (Critical)
- **Payment**: Stripe API, PayPal API
- **Flight**: Amadeus Flight API, Amadeus Flight Status API
- **Hotel**: Expedia Hotel API
- **Car Rental**: Multiple vendor APIs
- **Notifications**: SendGrid, Firebase Cloud Messaging, Twilio
- **Infrastructure**: PostgreSQL RDS Multi-AZ, MongoDB DocumentDB, Redis ElastiCache

### Explicitly Mentioned Reliability Mechanisms
- Resilience4j circuit breaker for external API failures
- Spring Retry library (not detailed)
- RDS Multi-AZ with automatic failover (within 60s)
- Redis ElastiCache cluster mode with 3 nodes
- Blue-Green deployment with ALB target group switching
- Connection pool: PostgreSQL max 100, timeout 10s
- Search API timeout: 30s
- Provider API parallel execution with 5s timeout

---

## Phase 2: Problem Detection

### Tier 1: Critical Issues (System-Wide Impact)

#### C-1: Transaction Boundary Ambiguity in Distributed Booking-Payment Flow
**Severity**: Critical
**Reference**: Section 3 (データフロー), Section 4 (データモデル)

**Problem**:
The booking confirmation flow spans multiple services (Booking Service, Payment Service) and databases (PostgreSQL for bookings, external Stripe/PayPal) without explicit distributed transaction coordination. The design describes:
1. Create booking (status: PENDING) in PostgreSQL
2. Execute payment via Payment Service → Stripe API
3. Payment Service callbacks to Booking Service on success → Update to CONFIRMED → Kafka event

**Failure Scenarios**:
- Payment succeeds at Stripe but callback fails due to network partition → Booking remains PENDING, user charged but no confirmation
- Kafka event publish fails after PostgreSQL update → Itinerary Service never receives BookingConfirmed event, no confirmation email sent
- Booking Service crashes between PostgreSQL update and Kafka publish → Inconsistent state

**Impact**: Data loss (confirmed bookings without itineraries), financial discrepancies (charged users with PENDING bookings), customer trust damage.

**Countermeasures**:
- Implement **Transactional Outbox Pattern**: Store Kafka events in PostgreSQL within the same transaction as booking updates, use dedicated publisher to read outbox and publish to Kafka
- Add **idempotency keys** to Stripe payment requests (using `booking_id`) to safely retry failed payments
- Define **compensation logic** for payment success + booking update failure: automated refund trigger with manual review queue
- Implement **webhook reconciliation**: Periodic job (every 10min) queries Stripe for successful payments without corresponding CONFIRMED bookings, triggers manual investigation

---

#### C-2: Missing Idempotency Keys for Retry-Safe Operations
**Severity**: Critical
**Reference**: Section 5 (API設計), Section 6 (エラーハンドリング方針)

**Problem**:
The design mentions Spring Retry but does not specify idempotency mechanisms for critical operations:
- `POST /api/v1/bookings` (booking creation with external provider APIs)
- `POST /api/v1/payments` (payment execution)
- `POST /api/v1/bookings/{id}/confirm` (booking confirmation)

**Failure Scenarios**:
- Network timeout during `POST /api/v1/bookings` → Client retries → Duplicate bookings created at external providers (double-charged user)
- Payment Service retry after transient Stripe error → Duplicate charges
- Kafka consumer (Itinerary Service) reprocesses BookingConfirmed event due to rebalancing → Duplicate notification emails

**Impact**: Financial loss (duplicate payments), data corruption (duplicate bookings), customer dissatisfaction (multiple confirmation emails).

**Countermeasures**:
- Add **`Idempotency-Key` header** (client-generated UUID) to all POST/PUT endpoints, store processed keys in Redis (24-hour TTL) with response caching
- For external provider API calls, use **provider-specific idempotency keys** (booking_id) to prevent duplicate reservations
- Implement **Kafka consumer offset management** with at-least-once semantics + application-level deduplication (store processed event IDs in PostgreSQL)
- Add **database unique constraints**: `UNIQUE(provider_code, provider_booking_ref)` on `booking_items` to prevent duplicate external bookings

---

#### C-3: Lack of Graceful Degradation for Dependency Failures
**Severity**: Critical
**Reference**: Section 6 (エラーハンドリング方針)

**Problem**:
The design mentions circuit breaker fallback to alternative providers for search, but does not address graceful degradation for other critical dependencies:
- **Payment Service unavailable**: No fallback payment method or queued retry mechanism
- **Notification Service failures**: Email/SMS failures do not prevent booking confirmation, but no retry strategy specified
- **Kafka unavailable**: Booking confirmation blocked if Kafka event publish fails (assuming synchronous publish)

**Failure Scenarios**:
- Payment Service circuit breaker opens → All booking confirmations blocked → Revenue loss during peak travel season
- SendGrid API rate limit exceeded → Confirmation emails dropped → Users do not receive booking details
- Kafka broker failure → Booking Service cannot confirm bookings → System-wide booking outage

**Impact**: Complete booking outage, revenue loss, customer abandonment.

**Countermeasures**:
- **Payment Service**: Implement **asynchronous payment processing** with job queue (Redis-backed Celery equivalent) for retries, expose payment status polling endpoint
- **Notification Service**: Store unsent notifications in PostgreSQL with retry queue, implement **exponential backoff** (1min, 5min, 30min, 2h) for 24 hours
- **Kafka**: Adopt **Transactional Outbox Pattern** (see C-1) to decouple Kafka availability from booking confirmation
- Define **read-only mode**: If all external providers fail circuit breakers, display cached search results with "booking temporarily unavailable" message

---

#### C-4: Missing Conflict Resolution Strategy for Eventual Consistency
**Severity**: Critical
**Reference**: Section 3 (データフロー), Section 4 (MongoDB コレクション)

**Problem**:
The design uses MongoDB for search result caching (30min TTL) but does not address conflicts when:
- External provider price changes between search and booking (price staleness)
- Concurrent bookings deplete inventory cached in MongoDB (overselling risk)
- Flight status updates lag behind real-time changes (flight already departed when delay notification sent)

**Failure Scenarios**:
- User searches at 10:00 (cache hit, price $500), books at 10:25 (provider price now $600) → Payment amount mismatch
- Two users simultaneously book the last available hotel room from cached search results → One booking fails after payment

**Impact**: Revenue loss (honored lower cached prices), customer disputes, booking failures after payment.

**Countermeasures**:
- Implement **price verification step** before payment: Re-query external provider API for current price, display price change notification if mismatch > threshold (e.g., 5%)
- Add **optimistic locking** to booking_items: Include version number, fail booking if provider returns "sold out" → Trigger immediate cache invalidation
- For flight status monitoring, implement **push-based updates** (webhook subscriptions with Amadeus) instead of 5-minute polling to reduce lag
- Add **cache invalidation triggers**: When booking confirmed, invalidate search cache for same provider+item to prevent overselling

---

#### C-5: Backup and Restore Procedures Without Tested Recovery
**Severity**: Critical
**Reference**: Section 7 (可用性・スケーラビリティ)

**Problem**:
The design specifies RDS Multi-AZ but does not mention:
- Backup retention policy
- Point-in-time recovery (PITR) testing procedures
- Recovery Time Objective (RTO) / Recovery Point Objective (RPO) definitions
- Cross-region disaster recovery (DR) for regional AWS outages

**Failure Scenarios**:
- Accidental `DELETE FROM bookings` without WHERE clause → No tested restore procedure → Data loss
- Primary region (e.g., ap-northeast-1) outage → No cross-region replica → Multi-hour outage

**Impact**: Permanent data loss, prolonged outages violating 99.9% SLA, regulatory compliance failures.

**Countermeasures**:
- Define **RPO/RTO targets**: RPO ≤ 5 minutes (via continuous backup), RTO ≤ 1 hour (automated restore scripts)
- Enable **automated backups** with 30-day retention, test quarterly restore to staging environment with data validation
- Implement **cross-region read replica** in secondary region (e.g., us-east-1) with automated failover runbook
- Add **soft delete pattern** for bookings: Mark as deleted instead of physical deletion, scheduled purge after 90 days

---

#### C-6: Cache Invalidation Strategy Gaps for Event-Driven Data Updates
**Severity**: Critical
**Reference**: Section 3 (データフロー), Section 4 (MongoDB search_cache)

**Problem**:
The MongoDB search cache uses fixed 30-minute TTL but does not handle invalidation for:
- **Late-arriving data**: Flight schedule changes published after search (e.g., flight time moved forward by 2 hours)
- **Backdated corrections**: Hotel availability corrected retroactively (e.g., maintenance closes rooms booked yesterday)
- **Price model changes**: Dynamic pricing updates during high-demand periods (surge pricing not reflected in cache)

**Failure Scenarios**:
- User books flight at 14:00 departure (cached at 10:00), airline moved flight to 12:00 at 10:15 → User misses flight
- Hotel oversold due to maintenance closure not reflected in cache → Booking rejected after payment
- Flash sale ends but cache still shows discounted price → Booking fails with price mismatch error

**Impact**: Customer dissatisfaction (wrong information), booking failures, revenue loss (honoring stale prices).

**Countermeasures**:
- Implement **event-driven cache invalidation**: Subscribe to provider webhook events (schedule changes, price updates) → Invalidate specific cache entries by search_params_hash
- Add **cache version tag**: Include provider's last_updated timestamp in cache, validate on booking creation, reject if stale
- For high-value bookings (>$1000), implement **cache bypass**: Always query live provider API for latest data
- Add **cache staleness monitoring**: Alert if cache age > 15 minutes for active search sessions (user navigating results)

---

### Tier 2: Significant Issues (Partial System Impact)

#### S-1: Retry Without Exponential Backoff and Jitter
**Severity**: Significant
**Reference**: Section 2 (主要ライブラリ), Section 6 (エラーハンドリング方針)

**Problem**:
The design lists "Spring Retry" as a library but does not specify:
- Retry interval configuration (fixed vs exponential backoff)
- Jitter implementation to prevent thundering herd
- Maximum retry attempts and timeout strategy

**Failure Scenarios**:
- External provider API experiences brief 10-second outage → All 100 ECS tasks retry simultaneously without jitter → Amplified load prevents recovery (thundering herd)
- Stripe API responds with 429 (rate limit) → Fixed-interval retries continue hitting rate limit → Payment failures

**Impact**: Prolonged outages due to retry storms, cascading failures.

**Countermeasures**:
- Configure **exponential backoff with jitter**: Base delay 100ms, multiplier 2x, max 5 retries → Delays: 100ms, 200ms, 400ms, 800ms, 1600ms (±25% jitter)
- Implement **retry budget**: Limit retries to 10% of request volume per minute, fail fast when budget exhausted
- Add **retry-after header handling**: Respect Retry-After from provider 429 responses
- Define **non-retryable errors**: 4xx client errors (except 429) should fail immediately without retry

---

#### S-2: Rate Limiting and Backpressure Mechanisms Undefined
**Severity**: Significant
**Reference**: Section 2 (Redis 7.2 レート制限), Section 7 (SLA)

**Problem**:
The design mentions Redis for rate limiting but does not specify:
- Rate limit thresholds per user/endpoint
- Backpressure handling when external providers throttle requests
- Protection against abusive search patterns (e.g., bot scraping flight prices)

**Failure Scenarios**:
- Competitor bot scrapes search API 1000x/second → External provider APIs rate limit TravelHub account → Legitimate users blocked
- Black Friday traffic spike → Booking Service overwhelms Stripe API → All payments fail
- Runaway background job sends 10k notifications/second → SendGrid suspends account

**Impact**: Service suspension by external providers, legitimate user impact, account penalties.

**Countermeasures**:
- Implement **API rate limits**: 100 requests/hour per user (search), 10 requests/hour per user (booking), return 429 with Retry-After header
- Add **provider-side rate limiting**: Track provider API quota in Redis, implement **token bucket algorithm** (e.g., Amadeus: 500 req/min), queue excess requests
- Implement **circuit breaker for rate limits**: If provider returns 429 > 50% for 1 minute, open circuit for 5 minutes to allow quota recovery
- Add **CAPTCHA for anomalous behavior**: Trigger challenge if search requests > 20/minute from single IP

---

#### S-3: Dead Letter Queue Handling for Unprocessable Messages
**Severity**: Significant
**Reference**: Section 2 (Apache Kafka 3.6)

**Problem**:
The design uses Kafka for event-driven communication but does not specify:
- Dead Letter Queue (DLQ) configuration for failed message processing
- Poison message detection (messages that repeatedly fail processing)
- Manual intervention procedures for DLQ messages

**Failure Scenarios**:
- Malformed BookingConfirmed event (missing user_id) → Itinerary Service crashes on deserialization → Kafka consumer group stalled
- Bug in Notification Service causes all FlightDelayed events to fail → Messages reprocessed infinitely → Consumer lag grows unbounded

**Impact**: Message processing stalls, user notifications never sent, cascading Kafka consumer group failures.

**Countermeasures**:
- Configure **DLQ topic** per consumer group (e.g., `itinerary-service-dlq`), route messages after 3 failed processing attempts
- Implement **poison message detection**: If same message fails 3+ times with deserialization error, send to DLQ without retry
- Add **DLQ monitoring**: Alert if DLQ message count > 10, provide admin dashboard for DLQ message inspection and manual reprocessing
- Implement **schema validation**: Validate Kafka event schema at producer (fail fast on publish) and consumer (send to DLQ on validation failure)

---

#### S-4: Single Point of Failure at Process and Service Levels
**Severity**: Significant
**Reference**: Section 3 (アーキテクチャ設計), Section 7 (スケーラビリティ)

**Problem**:
The design specifies ECS Auto Scaling (min 3, max 20 tasks) for compute but does not address:
- **Notification Service SPOF**: WebSocket (Socket.IO) requires sticky sessions → Single task failure disconnects all active users
- **Background job SPOF**: Flight status polling job (5min interval) not explicitly redundant → Job failure stops all delay monitoring
- **API Gateway SPOF**: ALB configuration (single AZ vs multi-AZ) not specified

**Failure Scenarios**:
- Notification Service task crashes → All WebSocket connections lost → Users do not receive real-time flight updates
- Background job instance terminates during deployment → 10-minute gap in flight status monitoring → Missed delay notifications

**Impact**: Real-time notification outages, delayed incident response, SLA violations.

**Countermeasures**:
- **WebSocket HA**: Implement **Redis Pub/Sub** for WebSocket message broadcasting across multiple Notification Service tasks, use ALB with sticky session affinity
- **Background job redundancy**: Deploy as **Kubernetes CronJob** with concurrency control (use PostgreSQL advisory locks to prevent duplicate execution)
- **ALB Multi-AZ**: Configure ALB across 3 availability zones with cross-zone load balancing enabled
- Add **health checks at multiple levels**: Process (HTTP /health), service (dependency checks), infrastructure (ECS task health)

---

#### S-5: WebSocket Connection Recovery Strategy Not Defined
**Severity**: Significant
**Reference**: Section 3 (Notification Service - Socket.IO)

**Problem**:
The design mentions WebSocket for real-time updates but does not specify:
- Client-side reconnection strategy (exponential backoff, max retries)
- State synchronization after reconnection (missed messages during disconnection)
- Message delivery guarantees (at-most-once, at-least-once, exactly-once)

**Failure Scenarios**:
- User's mobile app loses network for 30 seconds → Misses critical flight cancellation notification → WebSocket reconnects but no backfill
- Notification Service deployment (Blue-Green) → All WebSocket connections forcibly closed → Clients reconnect simultaneously (thundering herd)

**Impact**: Missed critical notifications, user confusion, poor mobile experience.

**Countermeasures**:
- Implement **client-side reconnection logic**: Exponential backoff (1s, 2s, 4s, 8s, 16s), max 10 retries before switching to polling fallback
- Add **message sequence numbering**: Each WebSocket message includes sequence number, client requests backfill via REST API if gap detected
- Implement **connection drain during deployment**: Send "server shutting down" event 30s before task termination, clients proactively reconnect to new tasks
- Store **recent notifications in Redis**: 5-minute sliding window per user, deliver on reconnection via catch-up endpoint

---

#### S-6: Database Schema Backward Compatibility Not Addressed
**Severity**: Significant
**Reference**: Section 6 (デプロイメント方針 - Flyway)

**Problem**:
The design specifies Blue-Green deployment with Flyway migrations but does not address:
- **Schema backward compatibility**: New schema version must support old application code during Blue-Green transition
- **Rollback-specific data compatibility**: If Green deployment fails and rolled back to Blue, can Blue handle data written by Green?

**Failure Scenarios**:
- Migration adds `NOT NULL` column without default → Old application code (Blue) crashes when writing to new schema → Cannot roll back without data loss
- New code writes JSON to `details` column with new required field → Rollback to old code fails to deserialize → Application crashes

**Impact**: Failed deployments, rollback-induced outages, data corruption.

**Countermeasures**:
- Adopt **expand-contract pattern**:
  - Deploy 1: Add new column as nullable, old code ignores it
  - Deploy 2: New code writes to both old and new columns
  - Deploy 3: Migrate data, deprecate old column
  - Deploy 4: Remove old column
- Add **schema version compatibility checks**: Application startup fails if schema version > application supported version
- For JSONB `details` column, implement **graceful deserialization**: Ignore unknown fields, use default values for missing fields
- Test **rollback scenarios in staging**: After each migration, simulate rollback and verify old code functionality

---

#### S-7: Missing Rollback Data Compatibility Validation
**Severity**: Significant
**Reference**: Section 6 (デプロイメント方針)

**Problem**:
The design mentions "rollback to previous version via ALB target group switch (within 10 minutes)" but does not address:
- Validation that previous version can read data written by new version
- Handling of new enum values or status codes introduced by new version

**Failure Scenarios**:
- New version adds `booking.status = 'PENDING_REVIEW'` → Rollback to old version → Old code treats unknown status as error → Booking updates fail
- New version changes `payment_method` enum format (STRIPE → STRIPE_V2) → Old version cannot process refunds

**Impact**: Rollback failures, operational panic, extended outages.

**Countermeasures**:
- Implement **forward-compatible enum handling**: Old code treats unknown enum values as valid (log warning, proceed with default behavior)
- Add **data migration reversibility checks**: For each migration, define reverse migration and test in staging
- Implement **feature flags for breaking changes**: New enum values behind feature flag, disabled during rollback
- Add **rollback validation tests**: Automated tests that deploy new version, write test data, rollback, verify old version functionality

---

#### S-8: Auto Scaling Resource Coordination Gaps
**Severity**: Significant
**Reference**: Section 7 (パフォーマンス目標 - PostgreSQL接続プール最大100接続, ECS Auto Scaling 最大20タスク)

**Problem**:
The design specifies connection pool max 100 connections and ECS max 20 tasks, but does not address:
- **Connection pool exhaustion during scale-out**: If 20 tasks × 100 connections = 2000 connections, exceeds typical RDS connection limit (~1000 for db.r5.xlarge)
- **Connection pool configuration per task**: Should each task have 100 connections (total 2000) or is 100 shared limit?

**Failure Scenarios**:
- Black Friday traffic → ECS scales to 20 tasks → Each opens 100 connections → PostgreSQL max_connections (1000) exceeded → New connections rejected → 500 errors
- New tasks start during scale-out → Connection pool initialization takes 30s → Traffic routed before ready → Timeout errors

**Impact**: Connection exhaustion, cascading failures, SLA violations.

**Countermeasures**:
- **Right-size connection pool per task**: If max 20 tasks, limit each task to 50 connections (20 × 50 = 1000, leaves buffer for admin connections)
- Configure **RDS max_connections parameter**: Increase to 2000 for target RDS instance class (requires db.r5.2xlarge or larger)
- Implement **connection pool warmup**: Initialize connections during ECS task startup, health check passes only after pool ready
- Add **connection pool exhaustion alerts**: Monitor `active_connections / max_connections > 80%`, trigger scale-up or connection limit increase

---

#### S-9: Missing Automated Rollback Triggers Based on SLI Degradation
**Severity**: Significant
**Reference**: Section 6 (デプロイメント方針), Section 7 (監視・アラート)

**Problem**:
The design specifies Blue-Green deployment with manual rollback but does not define:
- Automated rollback triggers based on SLI thresholds (error rate, latency)
- Canary deployment for gradual rollout with automatic health checks

**Failure Scenarios**:
- New deployment introduces memory leak → 30 minutes later, all tasks OOM crash → Manual rollback takes 10 minutes → 40-minute outage
- New code has race condition → 5% of bookings fail → Detected 2 hours later in daily metrics review → Customer impact amplified

**Impact**: Prolonged outages, amplified customer impact, slow incident response.

**Countermeasures**:
- Implement **automated rollback triggers**: If within 10 minutes of deployment:
  - API error rate > 5% → Automatic rollback
  - API p95 latency > 2× baseline → Automatic rollback
  - ECS task crash rate > 20% → Automatic rollback
- Add **canary deployment stage**: Route 10% traffic to new version for 5 minutes, monitor SLIs, proceed to full deployment if healthy
- Implement **progressive rollout**: 10% → 30 min bake → 50% → 30 min bake → 100%, rollback at any stage if SLI degrades
- Add **deployment dashboard**: Real-time SLI comparison (old version vs new version) visible to on-call engineer

---

### Tier 3: Moderate Issues (Operational Improvement)

#### M-1: Insufficient RED Metrics Coverage for Critical Endpoints
**Severity**: Moderate
**Reference**: Section 7 (監視・アラート)

**Problem**:
The design specifies SLO for "API availability > 99.9%" and "API p95 latency < 500ms" but does not detail:
- **Rate (Requests per second)**: Per-endpoint traffic patterns, anomaly detection
- **Errors**: Granular error classification (4xx client errors vs 5xx server errors), error budget tracking
- **Duration**: Latency percentiles per endpoint (p50, p95, p99), not just aggregate

**Missing Coverage**: No explicit monitoring for:
- `POST /api/v1/payments` (critical payment endpoint)
- External provider API latency (Amadeus, Expedia)
- Kafka consumer lag per consumer group

**Impact**: Delayed incident detection, inability to identify root cause (which endpoint/dependency degraded).

**Countermeasures**:
- Implement **per-endpoint RED metrics**: Tag CloudWatch metrics with `endpoint`, `method`, `status_code` dimensions
- Add **external dependency monitoring**: Track latency and error rate for each provider API (Amadeus Flight API, Stripe API, etc.)
- Implement **error budget tracking**: Define monthly error budget (0.1% = 43 minutes downtime), consume budget on SLO violations, freeze deployments if budget exhausted
- Add **Kafka consumer lag monitoring**: Alert if lag > 1000 messages or lag duration > 5 minutes

---

#### M-2: Database-Specific Operational Monitoring Gaps
**Severity**: Moderate
**Reference**: Section 2 (PostgreSQL 15), Section 7 (監視・アラート)

**Problem**:
The design uses PostgreSQL and MongoDB but does not specify operational monitoring for:
- **PostgreSQL read replica lag**: RDS Multi-AZ failover may expose replica lag (seconds to minutes)
- **Connection pool saturation**: HikariCP active connections vs idle connections
- **Slow query detection**: Queries exceeding threshold (e.g., 1s)
- **MongoDB document size growth**: `search_cache` JSONB documents may exceed 16MB limit

**Failure Scenarios**:
- Read replica lag spikes to 5 minutes → Itinerary Service reads stale data → User sees outdated flight status
- Connection pool saturated → New requests wait 10s for available connection → API timeout errors

**Impact**: Degraded user experience, operational blind spots, unexpected failures.

**Countermeasures**:
- Add **PostgreSQL replica lag monitoring**: Alert if `pg_stat_replication.replay_lag > 30s`
- Monitor **connection pool metrics**: Track `active_connections`, `idle_connections`, `wait_time_ms`, alert if wait time > 1s
- Enable **slow query logging**: Log queries exceeding 500ms, integrate with CloudWatch Logs Insights for analysis
- Add **MongoDB document size validation**: Reject search result caching if document size > 10MB (leave 6MB buffer)

---

#### M-3: Health Check Design Gaps (Multi-Level Checks)
**Severity**: Moderate
**Reference**: Section 7 (監視・アラート)

**Problem**:
The design mentions CloudWatch metrics but does not define health check endpoints:
- **Process-level**: Is the JVM running?
- **Service-level**: Can the service reach its dependencies (PostgreSQL, Redis, Kafka)?
- **Infrastructure-level**: Is the ECS task healthy (not OOM, not CPU throttled)?

**Failure Scenarios**:
- PostgreSQL connection pool exhausted → Health check still returns 200 OK → ALB routes traffic to unhealthy task → All requests fail
- Kafka connection lost → Booking confirmations fail silently → Health check does not detect

**Impact**: Traffic routed to unhealthy instances, prolonged partial outages.

**Countermeasures**:
- Implement **multi-level health checks**:
  - `GET /health/liveness` (shallow): Returns 200 if JVM alive (ECS task health check)
  - `GET /health/readiness` (deep): Checks PostgreSQL, Redis, Kafka connectivity, returns 503 if any dependency unavailable (ALB target health check)
- Configure **ALB health check**: Use `/health/readiness`, interval 10s, threshold 2 consecutive failures → Remove from target group
- Add **dependency health caching**: Cache dependency health status for 5s to avoid thundering herd during health checks
- Implement **startup probe**: Separate `/health/startup` endpoint that passes only after connection pool initialization complete

---

#### M-4: Missing Capacity Planning and Load Testing
**Severity**: Moderate
**Reference**: Section 7 (スケーラビリティ)

**Problem**:
The design specifies ECS Auto Scaling (max 20 tasks) and database connection limits but does not mention:
- Load testing to validate capacity under peak traffic (e.g., holiday season)
- Capacity planning for external provider API rate limits (Amadeus, Expedia quotas)
- Database sizing validation (PostgreSQL IOPS, storage growth rate)

**Failure Scenarios**:
- Black Friday traffic 10× normal → ECS scales to 20 tasks but RDS CPU saturates at 100% → Database becomes bottleneck
- Amadeus API quota exhausted mid-day → All flight searches fail → No alternative provider fallback capacity

**Impact**: Unexpected outages during peak traffic, revenue loss.

**Countermeasures**:
- Conduct **annual load testing**: Simulate 10× peak traffic (1000 req/s search, 100 req/s booking) for 2 hours, identify bottlenecks
- Implement **capacity planning dashboard**: Track current usage vs limits (ECS tasks, RDS connections, provider API quotas), alert if usage > 70%
- Define **external provider quota allocation**: Amadeus 10k searches/day, Expedia 5k searches/day → Alert if daily usage > 80%, trigger fallback to alternative providers
- Right-size **RDS instance**: Based on load test results, upgrade from db.r5.xlarge to db.r5.2xlarge if CPU > 70% sustained

---

#### M-5: Incident Response Runbooks Not Defined
**Severity**: Moderate
**Reference**: Section 7 (監視・アラート)

**Problem**:
The design specifies PagerDuty alerts for API error rate > 5% but does not mention:
- Incident response runbooks (step-by-step troubleshooting guides)
- Escalation procedures (L1 → L2 → Engineering on-call)
- Blameless postmortem process

**Failure Scenarios**:
- New on-call engineer receives alert "RDS CPU > 90%" → No runbook → Spends 30 minutes investigating → Escalates too late
- Payment Service outage → No escalation procedure → Incident sits in queue for 2 hours

**Impact**: Prolonged incident resolution, inconsistent response quality.

**Countermeasures**:
- Create **runbooks for common incidents**:
  - "API error rate > 5%": Check recent deployments, review logs for errors, rollback if within 10 minutes
  - "RDS CPU > 90%": Identify slow queries, kill long-running transactions, scale up RDS instance
  - "External provider API timeout > 50%": Verify provider status page, open circuit breaker, notify users
- Define **escalation policy**: L1 (5 min) → L2 (15 min) → Engineering on-call (immediate)
- Implement **blameless postmortem template**: Timeline, root cause, contributing factors, action items with owners and deadlines
- Conduct **quarterly incident response drills**: Simulate outage, test runbook effectiveness, iterate

---

#### M-6: Missing Distributed Tracing for Debugging Production Issues
**Severity**: Moderate
**Reference**: Section 6 (ロギング方針)

**Problem**:
The design specifies structured logging with correlation_id but does not mention:
- Distributed tracing system (e.g., AWS X-Ray, Jaeger) for cross-service request tracking
- Trace context propagation across services (Booking → Payment → Notification)

**Failure Scenarios**:
- User reports "booking failed after payment" → Engineer reviews logs across 3 services using correlation_id → Manual correlation takes 30 minutes → Root cause identified: Payment Service → Booking Service callback timeout

**Impact**: Slow incident resolution, difficulty debugging distributed system failures.

**Countermeasures**:
- Implement **AWS X-Ray integration**: Add X-Ray SDK to all services, propagate trace context via HTTP headers (`X-Amzn-Trace-Id`)
- Add **trace sampling**: 100% for errors, 10% for successful requests (to reduce cost)
- Create **trace visualization dashboard**: Link from PagerDuty alerts to X-Ray trace for incident context
- Add **trace-based SLI monitoring**: Track p95 end-to-end latency (API Gateway → Booking → Payment → Notification) from traces

---

#### M-7: Configuration Management and Version Control Gaps
**Severity**: Moderate
**Reference**: Section 6 (デプロイメント方針)

**Problem**:
The design mentions Flyway for database schema versioning but does not specify:
- Application configuration management (environment variables, feature flags)
- Configuration version control and audit trail
- Secret management (database credentials, API keys)

**Failure Scenarios**:
- Engineer manually updates Redis connection string in production ECS task definition → No audit trail → Connection string typo causes outage
- Feature flag accidentally enabled in production → New untested code path activated → Booking failures

**Impact**: Configuration drift, audit compliance failures, accidental misconfigurations.

**Countermeasures**:
- Implement **configuration as code**: Store all environment variables in Git (encrypted), deploy via AWS Systems Manager Parameter Store
- Use **AWS Secrets Manager** for secrets (database passwords, API keys), rotate credentials quarterly
- Implement **feature flag service** (e.g., LaunchDarkly, AWS AppConfig): Centralized flag management with audit log, gradual rollout capabilities
- Add **configuration validation**: Application startup fails if required configuration missing or malformed

---

### Tier 4: Minor Improvements and Positive Aspects

#### Positive: Circuit Breaker Implementation
The design explicitly mentions Resilience4j circuit breaker for external API failures with fallback to alternative providers, which is a strong fault isolation pattern.

#### Positive: Multi-AZ Database Configuration
RDS Multi-AZ with automatic failover (within 60s) provides good availability for the primary database dependency.

#### Positive: Structured Logging with Correlation IDs
The logging strategy includes correlation_id propagation, which is essential for distributed tracing and incident investigation.

#### Positive: Blue-Green Deployment Strategy
The deployment approach with ALB target group switching enables low-risk deployments with quick rollback capability.

#### Minor: Add Resource Quotas and Autoscaling Policies Documentation
The design specifies ECS Auto Scaling thresholds (CPU 70%) but could benefit from:
- Memory-based scaling thresholds (e.g., scale out if memory > 80%)
- Cooldown periods to prevent flapping (e.g., 5-minute cooldown after scale-out)
- Maximum scale-out rate limits (e.g., max 5 new tasks per 2 minutes)

#### Minor: Add Coordinated Release Procedures
For multi-service deployments (e.g., Booking Service + Payment Service schema changes), document coordination requirements:
- Deployment order (database first, then services)
- Backward compatibility validation checklist
- Communication procedures (notify dependent teams 48 hours before breaking changes)

---

## Summary

This reliability review identified **6 critical issues** requiring immediate attention:
1. Distributed transaction coordination gaps (booking-payment flow)
2. Missing idempotency mechanisms for retry-safe operations
3. Lack of graceful degradation for dependency failures
4. Undefined conflict resolution for eventual consistency
5. Untested backup and restore procedures
6. Cache invalidation strategy gaps for event-driven updates

**9 significant issues** require near-term resolution:
1. Retry strategies without exponential backoff/jitter
2. Undefined rate limiting and backpressure mechanisms
3. Missing dead letter queue handling
4. Single points of failure (WebSocket, background jobs)
5. WebSocket connection recovery strategy gaps
6. Database schema backward compatibility not addressed
7. Rollback data compatibility validation missing
8. Auto Scaling resource coordination issues
9. No automated rollback triggers based on SLI degradation

**7 moderate issues** represent operational improvement opportunities, and **4 positive aspects** demonstrate strong foundational design patterns.

The most critical gaps center around distributed system data consistency (transactions, idempotency, cache invalidation) and operational resilience (graceful degradation, rollback safety, resource coordination). Addressing the Tier 1 and Tier 2 issues will significantly improve the system's production readiness and operational stability.
