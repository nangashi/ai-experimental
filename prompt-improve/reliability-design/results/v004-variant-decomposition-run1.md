# Reliability Design Review - Payment Gateway System

## Phase 1: Structural Analysis

### System Components Identified

**Core Services:**
- Payment API Service (entry point for payment requests)
- Transaction Manager (transaction state management)
- Provider Gateway (payment provider API abstraction)
- Webhook Processor (asynchronous notification handler)
- Batch Settlement Service (daily settlement processing)

**Data Stores:**
- PostgreSQL 15 (primary database for transactions and merchants)
- Redis 7.2 (session cache and rate limiting counters)

**External Dependencies (Critical):**
- Stripe API (credit card processing)
- PayPal REST API (PayPal payment processing)
- Bank APIs (bank transfer processing)
- Google Cloud Pub/Sub (message queue)

**Infrastructure:**
- Kubernetes (GKE) for container orchestration
- Horizontal Pod Autoscaler for scaling
- Cloud SQL (managed PostgreSQL)

### Data Flow Paths Mapped

**Primary Payment Flow:**
1. Merchant → Payment API Service (payment request)
2. Transaction Manager → PostgreSQL (create transaction record, status: PENDING)
3. Provider Gateway → External Provider API (authorization request)
4. External Provider → Provider Gateway (authorization response)
5. Transaction Manager → PostgreSQL (update status: AUTHORIZED/FAILED)
6. External Provider → Webhook Processor (asynchronous settlement notification)
7. Webhook Processor → PostgreSQL (update status: CAPTURED/SETTLED)
8. Webhook Processor → Merchant (webhook notification)

**Refund Flow:**
1. Merchant → Payment API Service (refund request)
2. Transaction Manager → PostgreSQL (validate original transaction status = SETTLED)
3. Transaction Manager → PostgreSQL (create refund record, status: PENDING)
4. Provider Gateway → External Provider API (refund request)
5. External Provider → Provider Gateway (refund response)
6. Transaction Manager → PostgreSQL (update refund status: COMPLETED/FAILED)

**Batch Settlement Flow:**
1. Batch Settlement Service → PostgreSQL (query CAPTURED transactions)
2. Batch Settlement Service → PostgreSQL (update status: SETTLED)

### State Transitions Identified

**Transaction Status:**
- PENDING → AUTHORIZED (synchronous provider response)
- PENDING → FAILED (synchronous provider response)
- AUTHORIZED → CAPTURED (webhook notification)
- AUTHORIZED → SETTLED (webhook notification or batch processing)
- CAPTURED → SETTLED (batch processing)
- SETTLED → REFUNDED (refund operation)

**Refund Status:**
- PENDING → COMPLETED (provider refund success)
- PENDING → FAILED (provider refund failure)

### Reliability Mechanisms Explicitly Mentioned

- Resilience4j for retry logic (3 retries, exponential backoff 1s-10s)
- HMAC signature verification for webhook authentication
- Correlation ID for request tracing
- Structured logging with PII masking
- Horizontal Pod Autoscaler for load-based scaling
- ACID guarantees via PostgreSQL transactions
- Application-layer refund validation (status checks, amount limits)

---

## Phase 2: Problem Detection

### CRITICAL ISSUES

#### C1: No Circuit Breaker for Provider API Failures (Fault Recovery)

**Problem Description:**
While Resilience4j is mentioned for retry logic, there is no explicit circuit breaker design. When external provider APIs (Stripe, PayPal, bank APIs) experience prolonged outages or degraded performance, the system will continuously retry failed requests, potentially exhausting connection pools, threads, and causing cascading failures across the payment system.

**Failure Scenario:**
1. Stripe API experiences a 10-minute outage
2. All payment requests targeting Stripe retry 3 times with exponential backoff (up to 10 seconds)
3. Thread pool exhaustion occurs as requests accumulate
4. Redis connection pool depletes as rate limiting checks pile up
5. System becomes unresponsive for ALL payment providers, not just Stripe
6. Recovery requires manual service restart after provider recovery

**Impact Analysis:**
- Cross-provider contamination: Single provider failure affects all payment types
- Resource exhaustion: Thread pools, connection pools, memory pressure
- Recovery time: 10-30 minutes after provider recovers (service restart + health check + traffic ramp-up)
- Business impact: Complete payment outage across all providers during critical sales periods

**Countermeasures:**
1. Implement circuit breaker per provider using Resilience4j `CircuitBreaker` module
   - Failure threshold: 50% error rate over 10 requests
   - Open duration: 60 seconds
   - Half-open test requests: 3
2. Add bulkhead isolation per provider (separate thread pools)
   - Stripe pool: 50 threads
   - PayPal pool: 50 threads
   - Bank API pool: 30 threads
3. Implement fallback strategy in open circuit state:
   - Return `503 Service Unavailable` with `Retry-After` header
   - Log provider unavailability for manual investigation
   - Queue payment requests in Pub/Sub for delayed processing (optional)

**Design Document References:**
- Section 3.2 (Provider Gateway component)
- Section 7.4 (Failure recovery design - only mentions retry, no circuit breaker)

---

#### C2: Webhook Delivery Failure Handling Not Designed (Data Consistency)

**Problem Description:**
The design relies on webhooks for critical state transitions (AUTHORIZED → CAPTURED, CAPTURED → SETTLED) but does not specify how webhook delivery failures are handled. If the Webhook Processor fails to receive or process provider notifications, transaction status becomes permanently inconsistent with the provider's actual state.

**Failure Scenario:**
1. Stripe successfully captures a payment (status: captured at Stripe)
2. Webhook delivery to the system fails due to:
   - Network partition between Stripe and GKE
   - Webhook Processor pod restart during deployment
   - Message loss in Pub/Sub (acknowledged but not processed)
3. Transaction remains in `AUTHORIZED` status in PostgreSQL
4. Merchant never receives payment confirmation webhook
5. Customer's card is charged, but order is not fulfilled
6. Manual reconciliation required to identify and fix inconsistent transactions

**Impact Analysis:**
- Data inconsistency duration: Indefinite (until manual reconciliation)
- Business impact: Revenue loss (unfulfilled orders despite successful payment), customer disputes, refund processing overhead
- Detection difficulty: No alerting mechanism for webhook delivery failures
- Recovery complexity: Requires manual investigation of each provider's dashboard and database state comparison

**Countermeasures:**
1. Implement polling reconciliation batch job:
   - Run every 15 minutes
   - Query transactions in `AUTHORIZED` or `CAPTURED` status older than 30 minutes
   - Call provider APIs to fetch current status
   - Update database state if mismatch detected
   - Alert on status mismatches for manual investigation
2. Add webhook retry mechanism:
   - Store webhook payloads in Pub/Sub with 24-hour retention
   - Configure dead letter queue for failed webhook processing
   - Implement exponential backoff retry (5 attempts over 6 hours)
3. Add idempotency key support:
   - Store webhook event IDs in database
   - Skip processing if event ID already exists
   - Prevent duplicate status updates from retry logic
4. Implement webhook delivery monitoring:
   - SLO: 99% of webhooks processed within 5 minutes
   - Alert on webhook processing lag > 15 minutes
   - Dashboard showing webhook delivery rate per provider

**Design Document References:**
- Section 3.3 (Data flow, step 5 - webhook status update)
- Section 3.2 (Webhook Processor component)
- No section addressing webhook failure scenarios

---

#### C3: Batch Settlement Failure Recovery Manual Process (Availability)

**Problem Description:**
The batch settlement process (Section 7.7) states that failures trigger alerts for manual morning recovery. This design creates a critical operational gap where payment settlement is delayed by 8+ hours (from 2 AM failure to morning manual intervention), potentially violating merchant settlement SLAs and regulatory requirements.

**Failure Scenario:**
1. Batch Settlement Service starts at 2:00 AM JST
2. Database connection timeout occurs at 2:15 AM (Cloud SQL maintenance, network issue, connection pool exhaustion)
3. Batch processing fails and alert is triggered
4. On-call engineer receives alert but no detailed runbook guidance
5. Manual recovery attempt at 9:00 AM (7-hour delay)
6. If root cause is complex (e.g., data corruption), recovery may take several hours
7. Merchant settlement reports are delayed, affecting cash flow visibility

**Impact Analysis:**
- Settlement delay: 7-24 hours depending on failure timing and complexity
- Regulatory risk: Potential violation of payment industry settlement deadlines
- Merchant trust: Delayed settlement affects merchant cash flow planning
- Operational burden: Requires manual intervention for every batch failure

**Countermeasures:**
1. Implement automated batch retry mechanism:
   - Retry failed batch job every 30 minutes for 4 hours (8 attempts)
   - Use Spring Batch restart capability with job execution ID persistence
   - Implement skip logic for already-settled transactions (idempotency)
2. Add partial failure handling:
   - Process transactions in chunks (e.g., 1000 records per chunk)
   - Commit successful chunks independently
   - Track failed transaction IDs for retry
   - Ensure batch job can resume from last successful chunk
3. Implement batch job monitoring and automated diagnostics:
   - Pre-flight checks: Database connectivity, sufficient disk space, lock acquisition
   - Progress tracking: Record processed transaction count every 1000 records
   - Post-failure diagnostics: Capture error logs, database state snapshot, connection pool metrics
4. Design batch job fallback schedule:
   - Primary schedule: 2:00 AM JST
   - Automatic retry schedule: Every 30 minutes until 6:00 AM
   - Secondary fallback: Trigger manual review at 6:00 AM if still failing
5. Create comprehensive runbook:
   - Common failure scenarios and resolution steps
   - Database query scripts for identifying stuck transactions
   - Rollback procedures if partial settlement occurred
   - Contact information for Cloud SQL support escalation

**Design Document References:**
- Section 7.7 (Batch processing design)
- Section 3.2 (Batch Settlement Service component)

---

#### C4: Database Connection Pool Exhaustion Not Addressed (Availability)

**Problem Description:**
The design does not specify database connection pool sizing, timeout configurations, or connection leak detection. Under high load (1000 TPS target) or during provider API slowdowns (retry backoff delays), database connections may be held for extended periods, leading to connection pool exhaustion and system-wide unavailability.

**Failure Scenario:**
1. Stripe API experiences high latency (5-10 second response times)
2. Payment API Service holds database connections open during provider API calls (synchronous processing)
3. Retry logic with exponential backoff (up to 10 seconds) further increases connection hold time
4. Connection pool (default Spring Boot size: 10 connections) exhausts within seconds at 1000 TPS
5. New payment requests fail with "Connection timeout" errors
6. Health check endpoint also fails due to inability to acquire database connection
7. Kubernetes marks pods as unhealthy and restarts them, causing further disruption

**Impact Analysis:**
- Outage duration: 5-15 minutes (pod restart cycle, connection pool recovery)
- Cascading effect: Affects all payment types and query operations
- Detection difficulty: Connection pool exhaustion symptoms mimic database outage
- Recovery complexity: Requires pod restarts and connection pool drain/refill

**Countermeasures:**
1. Implement explicit connection pool configuration:
   ```yaml
   spring.datasource.hikari:
     maximum-pool-size: 50  # Based on Cloud SQL instance capacity
     minimum-idle: 10
     connection-timeout: 5000  # 5 seconds
     idle-timeout: 300000  # 5 minutes
     max-lifetime: 1800000  # 30 minutes
     leak-detection-threshold: 60000  # 60 seconds
   ```
2. Separate connection pools by operation type:
   - Write pool: 30 connections (payment creation, status updates)
   - Read pool: 20 connections (transaction queries, merchant queries)
   - Prevents query operations from being blocked by write-heavy traffic
3. Implement connection release optimization:
   - Use Spring WebFlux reactive patterns to release connections during external API calls
   - Transaction boundary optimization: Minimize transaction scope to database operations only
   - Avoid holding connections during provider API calls (use `@Transactional` carefully)
4. Add connection pool monitoring:
   - Metrics: Active connections, idle connections, pending connection requests, connection wait time
   - SLO: Connection acquisition time p99 < 100ms
   - Alert: Active connections > 80% of pool size for > 2 minutes
5. Implement connection leak detection:
   - Enable HikariCP leak detection (already configured above: 60 seconds)
   - Log stack traces of leaked connections
   - Alert on connection leak events for code review

**Design Document References:**
- Section 2.2 (Database - PostgreSQL mentioned but no connection configuration)
- Section 7.3 (Scalability - mentions Cloud SQL but no connection pooling)
- Section 7.1 (Performance target: 1000 TPS, but no capacity planning for database connections)

---

#### C5: No Idempotency Design for Payment Creation API (Data Consistency)

**Problem Description:**
The POST /v1/payments endpoint (Section 5.1) does not specify idempotency key support. If a merchant's payment request times out at the network layer but succeeds on the server side, the merchant will retry the request, resulting in duplicate transactions and double-charging customers.

**Failure Scenario:**
1. Merchant submits payment request for 10,000 JPY
2. Payment API Service successfully creates transaction (status: PENDING, DB committed)
3. Provider Gateway calls Stripe API and receives authorization success
4. Transaction status updated to AUTHORIZED in database
5. Network timeout occurs before HTTP response reaches merchant (e.g., load balancer timeout, network partition)
6. Merchant's client library automatically retries the request (standard HTTP client behavior)
7. Second transaction created with same amount, charged to same customer card
8. Customer is double-charged 20,000 JPY
9. Merchant must manually identify and refund duplicate transaction

**Impact Analysis:**
- Customer impact: Double charges, degraded trust, support inquiry overhead
- Merchant impact: Refund processing costs, chargeback risk, integration complexity
- Detection difficulty: Duplicate transactions may not be immediately obvious (different transaction IDs)
- Business risk: Regulatory compliance issues (PCI DSS, consumer protection laws)

**Countermeasures:**
1. Add idempotency key support to POST /v1/payments:
   - Accept `Idempotency-Key` header in request
   - Store idempotency key with transaction record in database (unique constraint)
   - Return cached response if idempotency key already exists (24-hour retention)
   - Implementation:
     ```java
     @PostMapping("/v1/payments")
     public ResponseEntity<PaymentResponse> createPayment(
         @RequestHeader("Idempotency-Key") String idempotencyKey,
         @RequestBody PaymentRequest request) {
       // Check if idempotency key exists
       Optional<Transaction> existing = transactionRepository
         .findByIdempotencyKey(idempotencyKey);
       if (existing.isPresent()) {
         return ResponseEntity.ok(toPaymentResponse(existing.get()));
       }
       // Create new transaction with idempotency key
       Transaction transaction = transactionService.createPayment(request, idempotencyKey);
       return ResponseEntity.ok(toPaymentResponse(transaction));
     }
     ```
2. Add database schema changes:
   - Add `idempotency_key` column to Transactions table (VARCHAR(64), unique index)
   - Add `idempotency_expires_at` column for cleanup (TIMESTAMP)
3. Implement idempotency key cleanup:
   - Batch job to delete idempotency keys older than 24 hours
   - Prevent indefinite database growth
4. Document idempotency key requirements in API documentation:
   - Best practice: Use UUIDv4 or merchant-generated unique request ID
   - Required for payment creation, optional for idempotent query operations
   - Same idempotency key returns same response (cached for 24 hours)

**Design Document References:**
- Section 5.1 (POST /v1/payments endpoint - no idempotency key mentioned)
- Section 7.6 (Data consistency design - no idempotency discussion)
- Section 3.3 (Data flow - no duplicate request handling)

---

### SIGNIFICANT ISSUES

#### S1: Timeout Configuration Deferred to Implementation Phase (Fault Recovery)

**Problem Description:**
Section 7.4 states "タイムアウトは、プロバイダーごとに異なる値を設定する予定だが、具体的な値は実装フェーズで決定する" (timeout values per provider will be determined during implementation phase). This defers a critical reliability decision, risking incorrect timeout values that could cause request pile-ups, resource exhaustion, or unnecessary failures.

**Failure Scenario:**
1. Implementation team sets conservative timeout (e.g., 30 seconds) for all providers
2. Stripe API typically responds in 200-500ms, but PayPal sometimes takes 5-8 seconds
3. PayPal timeout triggers prematurely at 30 seconds during peak load (instead of 90th percentile + buffer)
4. Retry logic triggers (3 retries × 30 seconds = 90 seconds total)
5. Customer experiences 90-second payment delay, abandons checkout
6. Post-deployment, timeout tuning requires code change, testing, and redeployment

**Impact Analysis:**
- Conversion loss: Customers abandon checkout during long timeout periods
- Resource waste: Threads held for unnecessarily long durations
- Provider relationship: Excessive premature timeouts may violate API usage terms
- Deployment risk: Timeout tuning post-deployment requires production hotfixes

**Countermeasures:**
1. Define timeout values in design phase based on provider SLAs:
   - **Stripe API**: 5 seconds (documented 99th percentile: 2 seconds)
   - **PayPal API**: 10 seconds (documented 99th percentile: 5 seconds)
   - **Bank APIs**: 15 seconds (varies by bank, conservative estimate)
   - **Webhook delivery**: 30 seconds (low priority, async processing)
2. Implement timeout hierarchy:
   - Connection timeout: 2 seconds (TCP connection establishment)
   - Read timeout: Provider-specific values above
   - Total request timeout: Read timeout + retry overhead (e.g., Stripe: 5s × 3 retries × 2x backoff = 30s max)
3. Make timeout values externalized configuration (application.yml):
   ```yaml
   payment.providers:
     stripe:
       connect-timeout: 2s
       read-timeout: 5s
       retry-max-attempts: 3
     paypal:
       connect-timeout: 2s
       read-timeout: 10s
       retry-max-attempts: 3
     bank:
       connect-timeout: 2s
       read-timeout: 15s
       retry-max-attempts: 2
   ```
4. Add timeout monitoring and alerting:
   - Metric: Timeout rate per provider (timeouts / total requests)
   - SLO: Timeout rate < 0.1% under normal conditions
   - Alert: Timeout rate > 1% for > 5 minutes (indicates provider degradation or misconfiguration)

**Design Document References:**
- Section 7.4 (Failure recovery design - explicitly defers timeout decisions)

---

#### S2: No Distributed Transaction Handling for Refunds (Data Consistency)

**Problem Description:**
Section 7.6 states refund validation occurs at application layer (checking SETTLED status and amount limits), but the design does not address distributed transaction handling between the database (refund record creation) and provider API (refund request). If the provider refund succeeds but the database update fails (or vice versa), the system enters an inconsistent state.

**Failure Scenario:**
1. Merchant initiates refund for transaction_id=ABC (amount: 10,000 JPY)
2. Application validates: Transaction status = SETTLED, no prior refunds
3. Refund record created in PostgreSQL (status: PENDING)
4. Provider Gateway sends refund request to Stripe API
5. Stripe successfully processes refund (customer card credited)
6. Database update to set refund status = COMPLETED fails due to:
   - PostgreSQL connection timeout
   - Transaction deadlock with concurrent update
   - Pod termination during deployment
7. Refund record remains in PENDING status indefinitely
8. Merchant dashboard shows refund as "pending", but customer already received money
9. Reconciliation reveals inconsistency, but manual investigation required

**Impact Analysis:**
- Inconsistency detection time: Hours to days (depends on reconciliation frequency)
- Customer impact: Confusion if merchant retries refund (potential double refund)
- Operational overhead: Manual reconciliation of provider vs. database state
- Compliance risk: Inaccurate financial records for auditing

**Countermeasures:**
1. Implement Saga pattern for refund processing:
   - **Step 1**: Create refund record (status: PENDING) with idempotency key
   - **Step 2**: Call provider API with idempotency key (provider-side deduplication)
   - **Step 3**: Update refund status (status: COMPLETED) or (status: FAILED)
   - **Compensation**: If Step 3 fails after Step 2 succeeds, polling reconciliation (countermeasure in C2) will detect and fix inconsistency
2. Add refund reconciliation to polling batch job (from C2):
   - Query refund records in PENDING status older than 1 hour
   - Call provider API to check refund status (using provider_transaction_id)
   - Update database status based on provider response
   - Alert if provider and database states are inconsistent beyond reconciliation threshold (24 hours)
3. Store provider refund ID in database:
   - Add `provider_refund_id` column to Refunds table
   - Store provider's refund transaction ID after successful provider API call
   - Enables exact reconciliation without ambiguity
4. Implement refund idempotency at provider gateway layer:
   - Use merchant-provided idempotency key for provider API calls
   - If retry occurs, provider deduplicates based on idempotency key
   - Prevents double refunds even if application retries

**Design Document References:**
- Section 7.6 (Data consistency design - only mentions application-layer validation, no distributed transaction handling)
- Section 5.1 (POST /v1/payments/{transaction_id}/refund endpoint - no idempotency or consistency mechanism)

---

#### S3: No Rate Limiting Design to Prevent Resource Exhaustion (Fault Recovery)

**Problem Description:**
While Redis is mentioned for "レート制限カウンタ" (rate limiting counters) in Section 2.2, there is no actual rate limiting design specified. Without rate limiting, malicious or misconfigured merchants can overwhelm the system with excessive requests, causing resource exhaustion and impacting all merchants.

**Failure Scenario:**
1. Merchant's e-commerce site experiences bot attack (credential stuffing, scraping)
2. Malicious bots submit 10,000 payment requests per second (10x normal system capacity)
3. Payment API Service accepts all requests (no rate limiting)
4. Database connection pool exhausts (issue C4 amplified)
5. Provider API quota exhausts (e.g., Stripe API rate limit: 100 requests/second)
6. Circuit breaker opens for all merchants (issue C1 amplified)
7. Legitimate merchants cannot process payments due to resource exhaustion
8. System-wide outage for 10-30 minutes until bot attack is manually blocked

**Impact Analysis:**
- Blast radius: Single merchant attack affects all merchants (no tenant isolation)
- Revenue loss: All merchants unable to process payments during attack
- Provider relationship: API quota exhaustion may trigger provider rate limit penalties
- Recovery complexity: Requires manual identification and blocking of malicious merchant

**Countermeasures:**
1. Implement multi-level rate limiting:
   - **Global rate limit**: 1000 TPS (matches Section 7.1 performance target)
   - **Per-merchant rate limit**: 100 requests/minute (configurable per merchant tier)
   - **Per-IP rate limit**: 10 requests/minute for suspicious IPs (abuse prevention)
2. Use Redis for distributed rate limiting:
   - Token bucket algorithm implementation
   - Key format: `ratelimit:{merchant_id}:{window}`
   - Window: 1 minute sliding window
   - Atomic increment operations to prevent race conditions
3. Rate limit response headers (RFC 6585):
   ```
   HTTP/1.1 429 Too Many Requests
   X-RateLimit-Limit: 100
   X-RateLimit-Remaining: 0
   X-RateLimit-Reset: 1640000000
   Retry-After: 60
   ```
4. Add rate limit monitoring and adaptive throttling:
   - Metric: Rate limit hit rate per merchant
   - Alert: Single merchant hitting rate limit for > 10 minutes (potential bot attack or misconfiguration)
   - Adaptive throttling: Temporarily reduce limits for merchants showing abuse patterns
5. Implement priority queuing for critical merchants:
   - Tiered rate limits: Enterprise (1000 req/min), Business (100 req/min), Starter (10 req/min)
   - Separate processing queues with priority scheduling
   - Ensures high-value merchants are not affected by lower-tier merchant abuse

**Design Document References:**
- Section 2.2 (Redis for rate limiting counters mentioned but no design)
- Section 7.1 (Performance target: 1000 TPS, but no overload protection)

---

#### S4: Webhook Processor Single Point of Failure (Availability)

**Problem Description:**
Section 3.2 describes the Webhook Processor as a single component responsible for processing all provider webhooks. If webhook processing falls behind due to high load, deployment, or bugs, webhook events will be lost or delayed, causing transaction status inconsistencies.

**Failure Scenario:**
1. Black Friday sales surge: 5000 payment requests in 5 minutes
2. Webhook Processor receives 5000 webhook events from providers
3. Webhook Processor has insufficient pod replicas (e.g., 2 pods, 10 events/second capacity each = 20 events/second)
4. Webhook event processing lag increases to 5+ minutes
5. Kubernetes pod restart occurs during deployment (rolling update)
6. In-flight webhook processing is interrupted, events are not acknowledged to Pub/Sub
7. Pub/Sub redelivers events, causing duplicate processing attempts
8. Some events exceed Pub/Sub acknowledgement deadline (10 minutes default) and are dead-lettered
9. Transaction status inconsistencies require manual reconciliation (issue C2 amplified)

**Impact Analysis:**
- Processing lag: Minutes to hours during peak load
- Data consistency risk: Lost or duplicate webhook processing
- Merchant experience: Delayed payment confirmation notifications
- Operational burden: Manual reconciliation of failed webhook deliveries

**Countermeasures:**
1. Implement horizontal scaling for Webhook Processor:
   - Configure Horizontal Pod Autoscaler based on Pub/Sub message backlog
   - Scaling metric: `pubsub.googleapis.com/subscription/num_undelivered_messages`
   - Target: < 100 undelivered messages per pod
   - Min replicas: 3, Max replicas: 20
2. Add webhook processing idempotency (expanded from C2):
   - Store webhook event ID in database (unique constraint)
   - Skip processing if event ID already exists
   - Prevents duplicate status updates from Pub/Sub redelivery
3. Implement graceful shutdown for webhook pods:
   - Configure `preStop` hook to finish processing in-flight webhooks
   - Set `terminationGracePeriodSeconds: 60` in pod spec
   - Ensure Pub/Sub acknowledgement before pod termination
4. Add webhook processing monitoring:
   - Metric: Webhook processing lag (time from event timestamp to processing completion)
   - SLO: p95 webhook processing lag < 5 seconds
   - Alert: Webhook processing lag > 1 minute for > 5 minutes
5. Configure Pub/Sub dead letter queue:
   - Max delivery attempts: 5
   - Acknowledgement deadline: 10 minutes (allows for retry + backoff)
   - Dead letter topic: `webhooks-dlq` for manual investigation
   - Alert on dead letter queue message arrival

**Design Document References:**
- Section 3.2 (Webhook Processor component - no scaling or failure handling)
- Section 2.3 (Google Cloud Pub/Sub mentioned but no configuration)

---

#### S5: Insufficient Monitoring Coverage for Reliability Signals (Monitoring & Alerting)

**Problem Description:**
Section 7.5 lists basic monitoring items (request count, response time, error rate, DB connections) but does not cover critical reliability signals from the Google SRE Four Golden Signals or RED metrics frameworks. Without comprehensive monitoring, reliability issues will be detected late or not at all.

**Failure Scenario:**
1. Provider Gateway experiences intermittent Stripe API timeouts (5% error rate)
2. Basic monitoring shows overall error rate: 0.5% (below alert threshold: 1%)
3. Per-provider error rate not monitored (Stripe: 5%, PayPal: 0.1%, Bank: 0.2%)
4. Stripe-specific failures continue undetected for hours
5. Circuit breaker threshold not reached (requires 50% error rate from C1)
6. Merchant complaints escalate: "Stripe payments failing randomly"
7. Investigation reveals Stripe API timeout issue, but root cause unclear without detailed latency percentiles
8. Post-incident analysis hampered by lack of request-level distributed tracing

**Impact Analysis:**
- Issue detection time: Hours to days (relies on merchant complaints)
- Root cause analysis difficulty: Insufficient granularity in metrics
- Customer impact: Intermittent failures degrade trust and conversion
- SLO compliance risk: Cannot validate 99.9% availability target without proper instrumentation

**Countermeasures:**
1. Implement Four Golden Signals monitoring (Google SRE):
   - **Latency**: p50, p95, p99 response times per endpoint and per provider
   - **Traffic**: Request rate per endpoint, per merchant, per provider
   - **Errors**: Error rate by status code (4xx, 5xx), by provider, by error type (timeout, circuit open, validation failure)
   - **Saturation**: CPU utilization, memory utilization, DB connection pool usage, Redis connection usage, thread pool queue depth
2. Add RED metrics per provider (from proposal prompt):
   - **Rate**: Requests per second to each provider (Stripe, PayPal, Bank APIs)
   - **Errors**: Error rate per provider (timeout, 4xx, 5xx, circuit open)
   - **Duration**: Latency percentiles per provider (p50, p95, p99)
3. Implement distributed tracing:
   - Use Spring Cloud Sleuth + Zipkin or Google Cloud Trace
   - Trace ID propagation: correlation_id (already mentioned in Section 6.2) → trace context
   - Span coverage: API Gateway → Transaction Manager → Provider Gateway → External Provider
   - Enables end-to-end request visualization and bottleneck identification
4. Define SLIs and SLOs based on monitored metrics:
   - **SLI**: Success rate = (total requests - 5xx errors) / total requests
   - **SLO**: 99.9% success rate over 30-day rolling window
   - **Error budget**: 0.1% failure allowance = ~43 minutes downtime per month (matches Section 7.3 availability target)
5. Implement SLO-based alerting:
   - Alert trigger: Error budget burn rate > 10x (predicts SLO violation within 3 days)
   - Multi-window burn rate alerts: 1-hour window (immediate issues) + 6-hour window (trend issues)
   - Alert routing: PagerDuty for critical, Slack for warnings
6. Add business metrics monitoring:
   - Payment success rate per payment method (card, bank transfer, e-money)
   - Average transaction value (detects anomalies)
   - Settlement lag (time from AUTHORIZED to SETTLED)
   - Refund rate per merchant (detects fraud or quality issues)

**Design Document References:**
- Section 7.5 (Monitoring & alerting design - insufficient coverage)
- Section 7.3 (Availability target 99.9% specified but no SLI/SLO framework)
- Proposal prompt Section 99-108 (Google SRE Four Golden Signals - not reflected in design)

---

### MODERATE ISSUES

#### M1: Deployment Strategy Lacks Health Check and Rollback Criteria (Deployment & Rollback)

**Problem Description:**
Section 6.4 mentions Kubernetes rolling update with pod replacement and traffic shifting, but does not specify health check endpoints, readiness/liveness probe configurations, or automated rollback criteria. Without these, faulty deployments may be rolled out completely before detection, causing prolonged outages.

**Failure Scenario:**
1. New deployment introduces database query performance regression (N+1 query bug)
2. Rolling update starts: 3 old pods, 3 new pods (50/50 traffic split)
3. Liveness probe only checks HTTP 200 response (not database connectivity or response time)
4. New pods pass health checks, continue rolling out
5. All 6 pods replaced with buggy version within 5 minutes
6. API response time degrades from 200ms to 5 seconds (p95)
7. Monitoring alerts trigger, but automatic rollback not configured
8. Manual rollback initiated after 10 minutes of investigation
9. Rollback takes 5 minutes (rolling update in reverse)
10. Total outage window: 15 minutes

**Impact Analysis:**
- Outage duration: 10-20 minutes (detection + rollback time)
- Blast radius: 100% of traffic affected (no canary or blue-green isolation)
- Detection delay: Relies on monitoring alerts, not automated health checks
- Business impact: Payment failures during rollout affect all merchants

**Countermeasures:**
1. Implement comprehensive health check endpoints:
   - **Liveness probe** (`/health/live`): Basic HTTP 200, checks if process is running
   - **Readiness probe** (`/health/ready`): Checks database connectivity, Redis connectivity, external provider reachability (optional)
   - **Startup probe** (`/health/startup`): Extended timeout for application initialization (30 seconds)
2. Configure Kubernetes probes:
   ```yaml
   livenessProbe:
     httpGet:
       path: /health/live
       port: 8080
     initialDelaySeconds: 30
     periodSeconds: 10
     failureThreshold: 3
   readinessProbe:
     httpGet:
       path: /health/ready
       port: 8080
     initialDelaySeconds: 10
     periodSeconds: 5
     failureThreshold: 2
   startupProbe:
     httpGet:
       path: /health/startup
       port: 8080
     initialDelaySeconds: 0
     periodSeconds: 10
     failureThreshold: 30
   ```
3. Implement automated rollback based on SLI degradation:
   - Use Flagger or Argo Rollouts for progressive delivery
   - Canary deployment: 10% → 25% → 50% → 100% traffic shift over 20 minutes
   - Automated rollback triggers:
     - Error rate > 1% for > 2 minutes
     - p95 latency > 1 second for > 2 minutes
     - Health check failure rate > 10%
4. Add deployment smoke tests:
   - Run automated E2E test suite against canary pods before traffic shift
   - Test critical paths: Payment creation, refund, transaction query
   - Block deployment if smoke tests fail
5. Implement deployment observability:
   - Deployment dashboard showing: Version, replica count, error rate, latency, health check status
   - Annotation in Grafana: Mark deployment timestamp for correlation with metric changes
   - Slack notification: Deployment started, canary promoted, rollback triggered

**Design Document References:**
- Section 6.4 (Deployment strategy - only mentions rolling update, no health checks or rollback)

---

#### M2: No Capacity Planning for 1000 TPS Target (Capacity Planning)

**Problem Description:**
Section 7.1 specifies a performance target of 1000 TPS but does not provide capacity planning calculations for database, Redis, Pod replicas, or external provider API quotas. Without capacity planning, the system may be under-provisioned and fail to meet the stated performance target under load.

**Failure Scenario:**
1. System launched with default configuration (3 Pod replicas, Cloud SQL shared core instance)
2. Black Friday traffic surge: 800 TPS sustained load
3. Database CPU utilization reaches 95% (Cloud SQL throttling begins)
4. Query latency increases from 10ms to 500ms
5. API response time increases from 200ms to 2 seconds (p95)
6. Customers experience slow checkout, cart abandonment increases
7. Emergency vertical scaling of Cloud SQL requires 5-10 minutes downtime
8. HPA triggers pod scale-out, but database remains bottleneck

**Impact Analysis:**
- Performance target miss: Cannot sustain 1000 TPS without capacity planning
- Customer experience: Slow checkout during peak traffic
- Revenue loss: Cart abandonment during critical sales periods
- Operational overhead: Emergency scaling during incidents

**Countermeasures:**
1. Perform load testing and capacity planning before production launch:
   - Load test scenarios: 500 TPS, 1000 TPS, 1500 TPS (50% headroom)
   - Test duration: 30 minutes sustained load + 5-minute spike to 2000 TPS
   - Measure resource utilization: CPU, memory, DB connections, Redis connections, network I/O
2. Calculate required resources for 1000 TPS target:
   - **Database**: Cloud SQL instance sizing
     - Estimated queries per transaction: 5 (insert, 2 updates, 2 selects)
     - Total queries per second: 1000 TPS × 5 = 5000 QPS
     - Cloud SQL instance: db-n1-standard-4 (4 vCPU, 15GB RAM, supports 10,000 QPS)
   - **Redis**: Connection and memory sizing
     - Estimated Redis operations per transaction: 3 (rate limit check, session lookup, cache write)
     - Total operations per second: 1000 TPS × 3 = 3000 OPS
     - Redis instance: 4GB memory, 5000 connections
   - **Pod replicas**: CPU and memory sizing
     - CPU per transaction: ~50ms (estimated from similar workloads)
     - Total CPU time: 1000 TPS × 50ms = 50 CPU-seconds/second = 50 cores
     - Pod CPU request: 2 cores per pod
     - Required pods: 50 / 2 = 25 pods (with 50% headroom = 38 pods max)
     - HPA configuration: Min 10 pods, Max 40 pods, target CPU 60%
   - **Provider API quotas**: Verify with providers
     - Stripe API: 100 requests/second (requires quota increase to 1000 req/s)
     - PayPal API: 50 requests/second (requires quota increase to 500 req/s)
     - Bank APIs: Varies by bank (negotiate SLAs with each bank)
3. Implement resource utilization monitoring and alerting:
   - Alert: Database CPU > 70% for > 5 minutes (trigger vertical scaling)
   - Alert: Pod CPU > 80% for > 5 minutes (trigger horizontal scaling)
   - Alert: Redis memory usage > 80% (trigger eviction policy review or instance upgrade)
4. Document scaling playbook:
   - Horizontal scaling: Add pod replicas via HPA (automatic)
   - Vertical scaling: Upgrade Cloud SQL instance (requires maintenance window)
   - Database read scaling: Add read replicas if query pattern is read-heavy
   - Provider quota scaling: Contact provider support 2 weeks before expected traffic increase

**Design Document References:**
- Section 7.1 (Performance target 1000 TPS specified but no capacity planning)
- Section 7.3 (Mentions HPA but no replica sizing calculations)
- Section 2.2 (Database and Redis mentioned but no instance sizing)

---

#### M3: Message Queue Failure Handling Not Designed (Fault Recovery)

**Problem Description:**
Section 2.3 mentions Google Cloud Pub/Sub as the message queue but does not specify its role in the architecture or how message delivery failures are handled. If Pub/Sub is used for asynchronous processing (e.g., webhook delivery to merchants), message loss or delays could cause merchant notification failures.

**Failure Scenario:**
1. Webhook Processor publishes merchant notification to Pub/Sub topic
2. Merchant Notification Service subscribes to Pub/Sub topic
3. Pub/Sub experiences regional outage (rare but possible: 2 hours)
4. Messages are queued but not delivered
5. After Pub/Sub recovers, message backlog is delivered in burst
6. Merchant Notification Service overwhelmed by 2 hours of queued messages
7. Some merchant webhook URLs timeout or fail (merchant server capacity exceeded)
8. Merchant webhook delivery failures not retried (no retry policy)
9. Merchants miss critical payment completion notifications

**Impact Analysis:**
- Notification delay: Hours (during Pub/Sub outage)
- Merchant experience: Missing payment notifications, degraded trust
- Operational burden: Manual investigation of failed notifications
- Compliance risk: Contract SLA violations if notification delivery is guaranteed

**Countermeasures:**
1. Clarify Pub/Sub usage in architecture design:
   - Document which asynchronous processes use Pub/Sub (e.g., merchant webhooks, settlement notifications, audit logs)
   - Define message schema and topic/subscription naming conventions
2. Implement Pub/Sub message delivery guarantees:
   - Configure message retention: 7 days (allows for extended outage recovery)
   - Configure acknowledgement deadline: 10 minutes (allows for retry + backoff)
   - Configure dead letter queue: Max 5 delivery attempts, then move to DLQ for manual investigation
3. Add Pub/Sub monitoring and alerting:
   - Metric: Oldest unacknowledged message age
   - Alert: Oldest message age > 5 minutes (indicates subscriber lag or failure)
   - Metric: Dead letter queue message count
   - Alert: DLQ message count > 0 (indicates persistent delivery failure)
4. Implement subscriber retry and backoff:
   - Use exponential backoff for transient failures (network timeout, merchant server 5xx)
   - Max retry attempts: 5 (after which message is dead-lettered)
   - Backoff schedule: 1s, 2s, 4s, 8s, 16s (total 31 seconds before DLQ)
5. Add Pub/Sub failover strategy:
   - Use multi-region Pub/Sub topics for critical notifications (if regional outage risk is unacceptable)
   - Implement fallback notification channel (e.g., email notification if webhook fails)

**Design Document References:**
- Section 2.3 (Pub/Sub mentioned but no usage details or failure handling)
- Section 3.2 (Webhook Processor component but no Pub/Sub integration details)

---

#### M4: No Graceful Degradation Strategy for Provider Outages (Availability)

**Problem Description:**
While circuit breaker design is recommended in C1, the overall system behavior during provider outages is not defined. The design does not specify whether the system should queue payments, reject payments, or offer alternative payment methods when a provider is unavailable.

**Failure Scenario:**
1. Stripe API experiences complete outage (duration: 30 minutes)
2. Circuit breaker opens for Stripe provider (from C1 recommendation)
3. All credit card payment requests return 503 Service Unavailable
4. Merchants have no alternative payment flow
5. Customers abandon checkout (cannot complete purchase)
6. Revenue loss for all merchants using Stripe as primary payment method
7. Competitor advantage: Merchants without alternative payment methods lose sales

**Impact Analysis:**
- Revenue loss: 100% of Stripe-dependent merchant revenue during outage
- Customer experience: Hard failure with no alternative payment options
- Merchant churn risk: Merchants may switch to competitors with better reliability
- Business continuity: No graceful degradation strategy

**Countermeasures:**
1. Design graceful degradation strategy for provider outages:
   - **Option 1: Payment queueing**
     - Queue payment requests in Pub/Sub during circuit open state
     - Process queued payments when circuit closes (provider recovers)
     - Notify customer: "Payment processing delayed, confirmation email will be sent"
     - Timeout: 15 minutes (after which payment request expires)
   - **Option 2: Alternative provider routing**
     - If Stripe circuit is open, route credit card payments to backup provider (e.g., PayPal card processing)
     - Requires merchant configuration: Primary provider + backup provider
     - Transparent to customer (no checkout flow change)
   - **Option 3: Payment method fallback**
     - Suggest alternative payment methods (e.g., "Credit card unavailable, use bank transfer or e-money")
     - Requires frontend integration for payment method switching
2. Implement provider health dashboard:
   - Real-time status: Green (operational), Yellow (degraded), Red (circuit open)
   - Merchant-facing dashboard: Show provider availability before payment submission
   - Admin dashboard: Provider error rate, latency, circuit breaker state
3. Add provider outage notification:
   - Webhook to merchants: Provider outage detected, alternative payment methods recommended
   - Customer-facing banner: "Credit card payments temporarily unavailable, please use alternative payment method"
4. Define SLA for provider outage handling:
   - Degradation mode activation: Within 1 minute of circuit breaker opening
   - Queued payment processing: Within 30 minutes of provider recovery
   - Merchant notification: Within 5 minutes of provider outage detection

**Design Document References:**
- Section 7.4 (Failure recovery design - only mentions retry, no graceful degradation)
- Section 3.2 (Provider Gateway component - no outage handling strategy)

---

### MINOR IMPROVEMENTS

#### I1: Correlation ID Tracing Not Enforced at Boundaries

**Observation:**
Section 6.2 mentions correlation_id for request tracing but does not specify enforcement at system boundaries (API Gateway, Provider Gateway, Webhook Processor). Without enforcement, some requests may lack correlation IDs, making distributed tracing incomplete.

**Recommendation:**
- Generate correlation_id at API Gateway ingress (if not provided by merchant)
- Propagate correlation_id to all downstream services (Transaction Manager, Provider Gateway)
- Include correlation_id in all external provider API calls (Stripe, PayPal custom headers)
- Include correlation_id in all log entries and error responses
- Add HTTP header: `X-Correlation-ID` in API responses

---

#### I2: No Audit Log Design for Compliance

**Observation:**
The design does not mention audit logging for compliance purposes (PCI DSS, financial regulations). Payment systems typically require immutable audit logs for transaction lifecycle events.

**Recommendation:**
- Implement append-only audit log table (or use Cloud Logging with retention policy)
- Log events: Payment created, authorized, captured, settled, refunded, failed
- Include: transaction_id, merchant_id, user_id, timestamp, action, before_state, after_state, actor (API key or system)
- Retention: 7 years (typical financial regulation requirement)
- Access control: Audit log read-only for security and compliance teams

---

#### I3: Database Backup and Restore Procedures Not Documented

**Observation:**
Section 7.3 mentions Cloud SQL (managed service) but does not document backup strategy, RPO/RTO targets, or restore procedures.

**Recommendation:**
- Enable Cloud SQL automated backups: Daily snapshots at 2:00 AM (before batch settlement)
- Enable Point-in-Time Recovery (PITR): Transaction log retention for 7 days
- Define RPO: Maximum 1 hour of data loss (transaction log backup frequency)
- Define RTO: Maximum 1 hour to restore service (failover to read replica + promotion)
- Test restore procedure: Quarterly disaster recovery drill (restore to staging environment)
- Document restore runbook: Step-by-step instructions for database failover and recovery

---

#### I4: Feature Flag System for Progressive Rollout Not Designed

**Observation:**
The design does not mention feature flags for progressive rollout of new payment providers or features. Feature flags enable safer deployments and faster rollback without code changes.

**Recommendation:**
- Implement feature flag system (e.g., LaunchDarkly, Unleash, or custom Redis-based flags)
- Use cases:
  - New payment provider rollout: Enable for 1% of merchants → 10% → 50% → 100%
  - New refund validation logic: Enable for low-risk merchants first
  - Circuit breaker threshold tuning: Adjust thresholds without code deployment
- Flag evaluation: Check flag state before routing payment to provider
- Monitoring: Alert if flag evaluation latency > 10ms (indicates feature flag service degradation)

---

## Summary and Priority Recommendations

### Critical Issues Requiring Immediate Design Changes (5)

1. **C1: Circuit Breaker Implementation** - Prevents cascading failures from provider outages
2. **C2: Webhook Delivery Failure Handling** - Ensures data consistency through polling reconciliation
3. **C3: Automated Batch Retry Mechanism** - Eliminates 8+ hour settlement delays
4. **C4: Database Connection Pool Configuration** - Prevents resource exhaustion at 1000 TPS load
5. **C5: Idempotency Key Support for Payments** - Prevents double-charging customers

### Significant Issues for Production Readiness (5)

1. **S1: Define Timeout Values in Design Phase** - Prevents post-deployment hotfixes
2. **S2: Distributed Transaction Handling for Refunds** - Ensures refund consistency
3. **S3: Multi-Level Rate Limiting Design** - Protects against merchant abuse
4. **S4: Webhook Processor Horizontal Scaling** - Handles peak load without message loss
5. **S5: Comprehensive Monitoring Implementation** - Enables proactive issue detection

### Moderate Issues for Operational Excellence (4)

1. **M1: Automated Deployment Rollback** - Reduces deployment-related outage duration
2. **M2: Capacity Planning for 1000 TPS** - Ensures performance target is achievable
3. **M3: Pub/Sub Failure Handling Design** - Prevents notification delivery failures
4. **M4: Graceful Degradation Strategy** - Maintains partial service during provider outages

### Assessment

This payment gateway design demonstrates solid foundational architecture with appropriate technology choices (Spring Boot, PostgreSQL, Kubernetes, Resilience4j). However, **critical reliability gaps exist in fault isolation, data consistency, and operational recovery mechanisms**.

The most severe risks are:
- **Cascading failure propagation** due to missing circuit breakers and bulkhead isolation
- **Permanent data inconsistency** from webhook delivery failures without reconciliation
- **Operational dependency on manual intervention** for batch settlement failures
- **Double-charging risk** from lack of idempotency support

Addressing the 5 critical issues (C1-C5) before production launch is essential to prevent system-wide outages, data loss, and customer trust degradation. The significant and moderate issues should be prioritized based on expected traffic patterns and business risk tolerance.
