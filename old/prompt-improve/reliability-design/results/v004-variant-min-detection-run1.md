# Reliability Design Review: Payment Gateway System

## Review Metadata
- Reviewer: reliability-design-reviewer
- Document: test-document-round-004.md
- Prompt Version: v004-variant-min-detection
- Review Date: 2026-02-11

---

## Executive Summary

This review identified **10 reliability issues** ranging from critical to minor severity. The payment gateway system design demonstrates some foundational reliability considerations (Resilience4j for retries, structured logging, basic monitoring) but exhibits significant gaps in fault recovery design, data consistency guarantees, operational readiness, and deployment safety. Critical issues include lack of circuit breaker implementation, missing idempotency design, absence of distributed transaction coordination, undefined rollback procedures, and insufficient monitoring coverage.

---

## Critical Issues (System-Wide Failure Risk)

### Issue 1: Missing Circuit Breaker Implementation Despite Library Inclusion

**Location**: Section 7.4 (障害回復設計), Section 2.4 (主要ライブラリ)

**Description**:
While Resilience4j is listed as a primary library (Section 2.4), the fault recovery design (Section 7.4) only specifies retry logic (3 attempts with exponential backoff) without implementing circuit breaker patterns. This creates cascading failure risk when external payment providers experience sustained outages.

**Impact**:
- **Cascading Failures**: Without circuit breakers, the system will continue attempting requests to failing providers, exhausting connection pools and thread resources
- **Resource Exhaustion**: Each retry attempt consumes database connections (for transaction status updates), Redis connections (for rate limiting), and worker threads
- **Degraded Recovery**: When the provider recovers, the system remains in retry loops for all accumulated requests, delaying recovery to normal operation
- **No Fast-Fail Capability**: Merchants receive slow timeout responses (up to 30+ seconds with 3 retries × 10s max backoff) rather than immediate failure notifications

**Failure Scenario**:
1. Stripe API experiences 100% failure rate at 10:00 AM
2. All incoming Stripe payment requests (assume 500 TPS) trigger retry logic
3. Each request waits 1s + 2s + 10s = 13s minimum before final failure
4. Thread pool exhaustion occurs within 30 seconds (assuming 200 worker threads)
5. New requests (including healthy PayPal/bank transfers) start queuing, causing system-wide latency degradation
6. Database connection pool saturates from blocking transaction updates
7. System becomes unresponsive across all payment providers

**Countermeasures**:
1. **Implement Circuit Breaker per Provider**: Configure Resilience4j CircuitBreaker for each provider gateway:
   ```java
   CircuitBreakerConfig config = CircuitBreakerConfig.custom()
     .failureRateThreshold(50) // Open at 50% failure rate
     .waitDurationInOpenState(Duration.ofSeconds(30)) // Wait 30s before half-open
     .slidingWindowSize(20) // Evaluate last 20 calls
     .minimumNumberOfCalls(10) // Require 10 calls before evaluation
     .build();
   ```
2. **Define Fallback Strategies**: Specify behavior for each circuit state:
   - **OPEN**: Return cached provider status, queue request for async retry, or redirect to alternative provider
   - **HALF_OPEN**: Gradually restore traffic with health check requests
3. **Provider-Level Isolation**: Ensure circuit breaker state is isolated per provider (Stripe failure doesn't affect PayPal availability)
4. **Circuit State Monitoring**: Expose circuit breaker metrics (state transitions, failure rates) to Prometheus for alerting
5. **Graceful Degradation Documentation**: Define merchant-facing error codes for circuit-open scenarios (e.g., `PROVIDER_TEMPORARILY_UNAVAILABLE`)

---

### Issue 2: No Idempotency Design for Critical Operations

**Location**: Section 5.1 (API設計), Section 3.3 (データフロー), Section 7.6 (データ整合性設計)

**Description**:
The API design lacks explicit idempotency mechanisms for payment operations. While Section 7.4 specifies retry logic for provider API calls, there is no discussion of idempotency keys, duplicate request detection, or safe retry guarantees. This creates risk of duplicate charges during network failures or client retries.

**Impact**:
- **Duplicate Charges**: If a merchant retries `POST /v1/payments` after network timeout, the system creates multiple transaction records and charges the customer multiple times
- **Inconsistent Refunds**: Retry of `POST /v1/payments/{id}/refund` may create duplicate refund records (Section 4.1 shows Refunds table lacks uniqueness constraint)
- **Race Conditions**: Concurrent capture requests (`POST /v1/payments/{id}/capture`) may result in multiple capture attempts to the provider
- **Audit Trail Corruption**: Duplicate transactions pollute financial reconciliation and reporting

**Failure Scenario**:
1. Merchant submits payment request for 10,000 JPY
2. Payment API Service creates transaction record (status: PENDING) and calls Stripe API
3. Stripe processes payment successfully but response is lost due to network partition
4. Merchant HTTP client times out and automatically retries request
5. Payment API Service treats it as new request, creates second transaction record
6. Second Stripe API call succeeds, charging customer 20,000 JPY total
7. Merchant receives two successful transaction IDs, customer disputes duplicate charge

**Countermeasures**:
1. **Require Idempotency Keys**: Mandate `Idempotency-Key` header for all mutating operations:
   ```
   POST /v1/payments
   Headers:
     X-API-Key: merchant_key
     Idempotency-Key: unique_request_identifier_from_merchant
   ```
2. **Implement Idempotency Store**: Create `idempotency_keys` table:
   ```sql
   CREATE TABLE idempotency_keys (
     key VARCHAR(255) PRIMARY KEY,
     merchant_id UUID NOT NULL,
     request_hash VARCHAR(64), -- SHA256 of request body
     response_status INT,
     response_body TEXT,
     created_at TIMESTAMP,
     expires_at TIMESTAMP,
     CONSTRAINT uk_merchant_key UNIQUE (merchant_id, key)
   );
   CREATE INDEX idx_expires_at ON idempotency_keys(expires_at); -- For TTL cleanup
   ```
3. **Idempotent Request Processing Flow**:
   - Check if idempotency key exists in store
   - If exists with matching request hash: Return cached response (409 Conflict or original 200/201)
   - If exists with different request hash: Return 422 Unprocessable Entity (key reuse error)
   - If not exists: Process request, store key + response atomically in transaction
4. **Set Key Expiration**: Implement 24-hour TTL for idempotency keys (balance replay protection vs. storage growth)
5. **Provider-Level Idempotency**: Forward idempotency semantics to provider APIs (Stripe/PayPal support idempotency keys)
6. **Document Idempotency Guarantees**: Specify in API documentation which operations are idempotent and key requirements

---

### Issue 3: Absence of Distributed Transaction Coordination

**Location**: Section 3.3 (データフロー), Section 7.6 (データ整合性設計)

**Description**:
The system involves distributed state across PostgreSQL (transaction records), Redis (session/cache), provider APIs (payment state), and message queues (Pub/Sub). Section 7.6 claims "決済トランザクションはPostgreSQLのACID特性により整合性を保証する" but this only covers local database transactions, not distributed consistency between database state and external provider state.

**Impact**:
- **Permanent State Divergence**: Database shows `AUTHORIZED` but provider never received authorization request (failure between steps 2-3 in Section 3.3)
- **Lost Updates**: Provider webhook arrives (step 5) before provider API response (step 4), causing state machine violation
- **Orphaned Provider Transactions**: Database transaction record fails to create (DB outage at step 2) after provider charge succeeds, creating untracked revenue
- **Reconciliation Complexity**: Manual reconciliation required between local transaction records and provider settlement reports

**Failure Scenario** (Two-Phase Commit Violation):
1. Transaction Manager creates record in PostgreSQL (status: PENDING)
2. Provider Gateway calls Stripe API → Stripe responds with successful authorization
3. Before database update to AUTHORIZED, PostgreSQL connection fails (network partition)
4. Transaction remains PENDING in database, AUTHORIZED in Stripe
5. Merchant queries transaction status → receives PENDING
6. Merchant retries payment, creating duplicate charge
7. Daily settlement batch (Section 7.7) skips this transaction (only processes CAPTURED state)
8. Stripe settles payment, but system never updates to SETTLED → Revenue leakage

**Countermeasures**:
1. **Implement Saga Pattern for Distributed Transactions**: Design compensating transactions for each step:
   - Step 2 failure: No compensation needed (no external state changed)
   - Step 3 failure after provider success: Automatic void/cancel API call to provider
   - Step 4 failure: Provider webhook will eventually update state (implement webhook replay)
2. **Introduce Outbox Pattern for Reliable State Propagation**:
   ```sql
   CREATE TABLE outbox_events (
     id UUID PRIMARY KEY,
     aggregate_id UUID, -- transaction_id
     event_type VARCHAR(50), -- 'AUTHORIZATION_REQUESTED', 'AUTHORIZATION_COMPLETED'
     payload JSONB,
     created_at TIMESTAMP,
     processed_at TIMESTAMP
   );
   ```
   - Insert transaction record + outbox event in single local transaction
   - Background worker polls outbox and calls provider API
   - Mark event as processed only after provider confirms + DB update succeeds
3. **Implement Reconciliation Service**:
   - Scheduled job (every 15 minutes) queries provider APIs for authorizations not in local DB
   - Compare local PENDING transactions (older than 5 minutes) against provider state
   - Automatic correction for divergent states (with alerting)
   - Daily full reconciliation against provider settlement reports
4. **Add State Machine Enforcement**: Validate status transitions in Transaction Manager:
   ```
   PENDING → AUTHORIZED | FAILED
   AUTHORIZED → CAPTURED | FAILED
   CAPTURED → SETTLED | REFUNDED
   SETTLED → REFUNDED
   ```
   - Reject invalid transitions (e.g., PENDING → SETTLED) with error logging
5. **Webhook Deduplication and Ordering**: Store webhook event IDs and sequence numbers to handle out-of-order delivery
6. **Define RTO for Divergence Detection**: Specify maximum acceptable time before inconsistency is detected (e.g., 15 minutes via reconciliation job)

---

### Issue 4: Undefined Rollback Procedures and Deployment Safety Mechanisms

**Location**: Section 6.4 (デプロイメント方針)

**Description**:
Section 6.4 specifies Kubernetes rolling updates with pod replacement and traffic shifting, but provides no rollback strategy, health check configuration, deployment validation criteria, or zero-downtime verification procedures. This creates risk of undetected bad deployments causing sustained production impact.

**Impact**:
- **Silent Bad Deployments**: New version deploys successfully but introduces bugs (e.g., payment authorization logic error) that are not detected until customer complaints accumulate
- **Extended Downtime**: No automated rollback means manual intervention required, increasing MTTR from minutes to hours
- **Data Corruption**: Schema migration issues (e.g., new column constraints incompatible with old code) cause application errors during mixed-version operation
- **Revenue Loss**: Payment processing failures go undetected during gradual rollout, resulting in lost transactions

**Failure Scenario**:
1. New version deployed with bug in Provider Gateway (Stripe API call uses wrong endpoint)
2. Rolling update repletes 50% of pods over 10 minutes
3. New pods return 500 errors for all Stripe payments (50% error rate for Stripe traffic)
4. Prometheus records elevated error rate but no alert fires (threshold set at 10%, Section 7.5 only monitors "エラー率" without SLO definition)
5. Deployment continues to 100% completion over 20 minutes
6. All Stripe payments now failing, merchants contact support
7. Engineering team identifies issue 30 minutes later, begins manual rollback
8. Rollback takes 15 minutes (image pull + pod restart)
9. Total impact: 45 minutes of 100% Stripe payment failure

**Countermeasures**:
1. **Implement Readiness and Liveness Probes**:
   ```yaml
   readinessProbe:
     httpGet:
       path: /health/ready
       port: 8080
     initialDelaySeconds: 30
     periodSeconds: 10
     failureThreshold: 3
   livenessProbe:
     httpGet:
       path: /health/live
       port: 8080
     initialDelaySeconds: 60
     periodSeconds: 30
     failureThreshold: 3
   ```
   - `/health/ready`: Verify database connectivity, Redis connectivity, and critical dependencies
   - `/health/live`: Verify application process health (non-blocking check)
2. **Define Deployment Success Criteria (Automated Rollback Triggers)**:
   - Error rate threshold: p95 error rate < 1% for 5 consecutive minutes after rollout
   - Latency threshold: p95 latency < 600ms (20% margin above SLO of 500ms)
   - Provider success rate: Each provider success rate > 95%
   - Database connection pool: < 80% utilization
   - Implement automated rollback if any threshold violated within 10 minutes post-deployment
3. **Progressive Rollout Strategy**:
   - Stage 1 (10% traffic, 10 minutes): Deploy to 10% of pods, monitor key metrics
   - Stage 2 (50% traffic, 10 minutes): If Stage 1 passes, expand to 50%
   - Stage 3 (100% traffic): Full deployment
   - Pause between stages requires manual approval or automated validation pass
4. **Implement Blue-Green Deployment for High-Risk Changes**:
   - Database schema changes
   - Provider API integration changes
   - Authentication/authorization logic changes
   - Deploy full new environment (green), run smoke tests, then switch traffic
5. **Database Migration Backward Compatibility Strategy**:
   - Phase 1: Add new columns/tables (old code ignores, new code writes to both old and new)
   - Phase 2 (after 1 week): Deploy code using new schema
   - Phase 3 (after 1 week): Remove old columns/tables in separate migration
   - Rollback capability maintained for 1 week between phases
6. **Runbook for Rollback Procedures**:
   - Document rollback command: `kubectl rollout undo deployment/payment-api -n production`
   - Define rollback decision criteria (who can trigger, under what conditions)
   - Specify rollback validation steps (verify traffic recovery, check error rates)
   - Include communication template for incident notifications
7. **Smoke Tests Post-Deployment**:
   - Automated test suite runs against production (using test merchant account):
     - Create payment → Verify AUTHORIZED status
     - Capture payment → Verify CAPTURED status
     - Refund payment → Verify REFUNDED status
     - Query transaction → Verify data consistency
   - Tests must pass before considering deployment successful

---

## Significant Issues (Partial Failure Impact)

### Issue 5: Insufficient Monitoring Coverage and Missing SLI/SLO Definitions

**Location**: Section 7.5 (監視・アラート設計), Section 7.1 (パフォーマンス目標)

**Description**:
Section 7.5 specifies Prometheus/Grafana for monitoring "HTTP リクエスト数・レスポンスタイム, エラー率, データベース接続数" but lacks comprehensive SLI/SLO definitions, provider-specific health metrics, business-critical signals (payment success rate by provider), and alerting strategy. Section 7.1 defines performance targets (p95 < 500ms, 1000 TPS) but these are not translated into operational SLOs with error budgets.

**Impact**:
- **Delayed Incident Detection**: Critical payment failures may go unnoticed if generic error rate threshold is too high (e.g., 5% threshold allows 50 failed payments per 1000 TPS)
- **Alert Fatigue**: Lack of SLO-based alerting leads to noisy alerts on non-actionable metrics (e.g., single database connection spike)
- **Insufficient Diagnostic Information**: When incident occurs, responders lack visibility into which provider failed, which merchant is affected, or which operation type is problematic
- **No Capacity Planning Data**: Absence of resource saturation metrics prevents proactive scaling decisions

**Missing Metrics**:
- Payment success rate per provider (Stripe/PayPal/Bank)
- Authorization vs. capture vs. refund success rates
- Provider API latency (p50/p95/p99) and timeout rates
- Webhook processing lag and failure rate
- Idempotency key collision rate (once Issue 2 is addressed)
- Circuit breaker state changes (once Issue 1 is addressed)
- Transaction state machine violation errors
- Reconciliation job discrepancy count
- Redis cache hit rate and eviction rate

**Countermeasures**:
1. **Define Service-Level Indicators (SLIs)**:
   - **Availability SLI**: Percentage of successful payment requests (HTTP 2xx for `POST /v1/payments`)
     - Target: 99.9% (aligned with Section 7.3 availability goal)
   - **Latency SLI**: 95th percentile payment request latency
     - Target: < 500ms (from Section 7.1)
   - **Correctness SLI**: Percentage of transactions matching provider settlement reports (measured by reconciliation job)
     - Target: 99.99% (max 1 discrepancy per 10,000 transactions)
2. **Define Service-Level Objectives (SLOs) with Error Budgets**:
   - Availability SLO: 99.9% over 30-day rolling window
     - Error budget: 43.2 minutes of downtime per month (aligns with Section 7.3)
     - Budget consumption triggers:
       - 50% consumed → Review incident trends
       - 80% consumed → Freeze non-critical releases
       - 100% consumed → Incident postmortem required
3. **Implement Four Golden Signals + Payment-Specific Metrics**:
   - **Latency**: Track p50/p95/p99 for each endpoint and provider
   - **Traffic**: Requests per second, segmented by provider and operation type
   - **Errors**: Error rate by error code (`PAYMENT_FAILED`, `PROVIDER_TIMEOUT`, etc.)
   - **Saturation**: Database connection pool usage, Redis memory usage, CPU/memory per pod
   - **Payment Success Rate**: `(AUTHORIZED + CAPTURED) / Total Requests` per provider
4. **Configure Actionable Alerts**:
   - **Critical**: Payment success rate < 95% for any provider (5-minute window) → Page on-call engineer
   - **Critical**: API error rate > 5% (5-minute window) → Page on-call
   - **Warning**: p95 latency > 700ms (10-minute window) → Slack notification
   - **Warning**: Database connection pool > 80% (5-minute window) → Slack notification
   - **Info**: Circuit breaker state change to OPEN → Slack notification
5. **Distributed Tracing Implementation**:
   - Instrument code with OpenTelemetry for end-to-end request tracing
   - Trace spans: API Gateway → Transaction Manager → Provider Gateway → External API
   - Include correlation_id (already mentioned in Section 6.2) in all logs and traces
   - Export traces to backend (e.g., Google Cloud Trace, Jaeger)
6. **Business Metrics Dashboard**:
   - Real-time payment volume and revenue by provider
   - Top 10 merchants by transaction volume
   - Daily reconciliation discrepancy report
   - Error distribution by merchant and provider

---

### Issue 6: No Rate Limiting or Backpressure Design Beyond Redis Counter

**Location**: Section 2.2 (データベース), Section 7.1 (パフォーマンス目標)

**Description**:
Section 2.2 mentions Redis for "レート制限カウンタ" but provides no details on rate limiting strategy (per-merchant quotas, per-provider limits, global system limits), no backpressure mechanisms for queue overload, and no load shedding strategy when approaching capacity. Section 7.1 specifies 1000 TPS target but doesn't address behavior when this is exceeded.

**Impact**:
- **Noisy Neighbor Problem**: Single high-volume merchant can consume all system capacity, starving other merchants
- **Provider API Quota Exhaustion**: System may exceed provider rate limits (e.g., Stripe 100 req/sec), causing widespread 429 errors
- **Queue Saturation**: Pub/Sub queue (Section 2.3) fills up during traffic spikes, causing message delivery delays or drops
- **Database Overload**: Uncontrolled request rate can saturate PostgreSQL connection pool, causing cascading failures

**Countermeasures**:
1. **Implement Multi-Level Rate Limiting**:
   - **Per-Merchant**: Limit each merchant to 100 TPS (adjustable per merchant tier)
   - **Per-Provider**: Limit requests to each provider (Stripe: 90 req/sec, PayPal: 50 req/sec) with 10% safety margin
   - **Global System**: Limit total ingress to 1200 TPS (20% above target capacity for burst tolerance)
2. **Rate Limiter Implementation** (Token Bucket Algorithm in Redis):
   ```java
   @Component
   public class RedisRateLimiter {
     public boolean allowRequest(String merchantId, int maxTokens, Duration window) {
       String key = "rate_limit:" + merchantId;
       // Lua script for atomic token bucket check-and-decrement
       // Return true if tokens available, false otherwise
     }
   }
   ```
3. **Graceful Degradation on Rate Limit Exceed**:
   - Return `429 Too Many Requests` with `Retry-After` header
   - Include rate limit headers in all responses:
     ```
     X-RateLimit-Limit: 100
     X-RateLimit-Remaining: 45
     X-RateLimit-Reset: 1609459200
     ```
4. **Backpressure Mechanisms**:
   - **Queue Depth Monitoring**: Alert when Pub/Sub queue depth > 10,000 messages
   - **Rejection at Gateway**: If database connection pool > 90%, reject new requests with 503 Service Unavailable
   - **Priority Queues**: Implement separate queues for critical operations (capture/refund) vs. non-critical (queries)
5. **Load Shedding Strategy**:
   - Shed lowest-priority traffic first (query requests before mutations)
   - Implement merchant tier prioritization (enterprise merchants prioritized over free tier)
   - Circuit breaker opens for non-critical endpoints when CPU > 90%
6. **Capacity Planning and Autoscaling**:
   - Configure HPA (Horizontal Pod Autoscaler) with target CPU 70%:
     ```yaml
     apiVersion: autoscaling/v2
     kind: HorizontalPodAutoscaler
     spec:
       minReplicas: 5
       maxReplicas: 50
       metrics:
       - type: Resource
         resource:
           name: cpu
           target:
             type: Utilization
             averageUtilization: 70
     ```
   - Load test system to validate autoscaling behavior under 1500 TPS (150% of target)

---

## Moderate Issues (Operational Improvement Opportunities)

### Issue 7: Insufficient Timeout Configuration and Partial Definition

**Location**: Section 7.4 (障害回復設計)

**Description**:
Section 7.4 mentions "タイムアウトは、プロバイダーごとに異なる値を設定する予定だが、具体的な値は実装フェーズで決定する." This defers critical reliability decisions to implementation phase without architectural guidance. Additionally, only provider API timeouts are mentioned—no specification for database query timeouts, Redis operation timeouts, or webhook processing timeouts.

**Impact**:
- **Inconsistent Timeout Behavior**: Developers may choose arbitrary timeout values, leading to misaligned timeout cascades (e.g., HTTP client timeout > circuit breaker timeout)
- **Thread Pool Exhaustion**: Long-running operations without timeouts can block worker threads indefinitely
- **User Experience Degradation**: Merchants experience unpredictable response times depending on which provider they use

**Countermeasures**:
1. **Define Timeout Hierarchy** (each layer should be shorter than the layer above):
   ```
   User-facing API timeout: 30 seconds
   ├─ Transaction Manager timeout: 25 seconds
   │  ├─ Provider Gateway timeout: 20 seconds
   │  │  ├─ Stripe HTTP client timeout: 15 seconds
   │  │  │  ├─ Connection timeout: 5 seconds
   │  │  │  └─ Read timeout: 10 seconds
   │  │  ├─ PayPal HTTP client timeout: 18 seconds
   │  │  └─ Bank API HTTP client timeout: 25 seconds (CRITICAL: longer than parent!)
   │  └─ Database query timeout: 5 seconds
   └─ Redis operation timeout: 1 second
   ```
2. **Provider-Specific Timeout Recommendations** (based on typical latency):
   - Stripe: Connection 5s, Read 10s (total 15s)
   - PayPal: Connection 5s, Read 13s (total 18s)
   - Bank APIs: Connection 10s, Read 20s (total 30s, requires architectural review)
3. **Configure Resilience4j TimeLimiter**:
   ```java
   TimeLimiterConfig config = TimeLimiterConfig.custom()
     .timeoutDuration(Duration.ofSeconds(15)) // Stripe example
     .cancelRunningFuture(true) // Cancel thread on timeout
     .build();
   ```
4. **Database Connection Pool Timeout**:
   ```
   spring.datasource.hikari.connection-timeout=5000 # 5s to acquire connection
   spring.datasource.hikari.validation-timeout=3000 # 3s to validate connection
   ```
5. **Webhook Processing Timeout**:
   - Set 30-second deadline for webhook processing
   - If processing exceeds timeout, publish to dead-letter queue for manual review
   - Respond to provider webhook with 200 OK immediately after queuing (prevent webhook retry storm)

---

### Issue 8: Manual Batch Recovery Process Without Automation

**Location**: Section 7.7 (バッチ処理設計)

**Description**:
Section 7.7 states "処理中に障害が発生した場合は、アラートを発報し、翌朝手動でリカバリを行う." This manual recovery approach introduces operational risk and delays financial settlement processes. No specification for batch job checkpointing, partial progress tracking, or automatic retry logic.

**Impact**:
- **Delayed Financial Settlement**: Failed batch job delays merchant payouts until manual intervention (potentially 8+ hours if failure occurs at 2 AM)
- **Human Error Risk**: Manual recovery may apply incorrect corrections, skip transactions, or double-process records
- **Audit Compliance Issues**: Manual interventions are harder to audit and may violate financial regulations

**Countermeasures**:
1. **Implement Spring Batch Restart Capability**:
   ```java
   @Bean
   public Job settlementJob() {
     return jobBuilderFactory.get("settlementJob")
       .incrementer(new RunIdIncrementer())
       .start(settlementStep())
       .build();
   }

   @Bean
   public Step settlementStep() {
     return stepBuilderFactory.get("settlementStep")
       .<Transaction, Transaction>chunk(100) // Process 100 transactions per commit
       .reader(transactionReader())
       .processor(settlementProcessor())
       .writer(transactionWriter())
       .faultTolerant()
       .retryLimit(3)
       .retry(TransientDataAccessException.class)
       .skipLimit(10) // Skip up to 10 failed records
       .skip(ProviderApiException.class)
       .listener(new SettlementStepListener()) // Log skipped items
       .build();
   }
   ```
2. **Automatic Retry on Transient Failures**:
   - Retry entire batch job up to 3 times with 15-minute delay between attempts
   - Use Spring Batch's `JobOperator.restart(executionId)` for automatic restart
3. **Checkpointing and Partial Progress Tracking**:
   - Spring Batch automatically checkpoints after each chunk (100 transactions)
   - On restart, batch resumes from last successful checkpoint
   - Implement `ItemReader` with cursor-based pagination to avoid reprocessing
4. **Dead-Letter Queue for Failed Transactions**:
   - Transactions that fail after 3 retries are written to `failed_settlements` table
   - Separate monitoring dashboard for failed settlements with manual review workflow
5. **Batch Monitoring and Alerting**:
   - **Critical Alert**: Batch job fails after all retries → Page on-call engineer (even at 2 AM)
   - **Warning Alert**: Batch job has > 5 skipped transactions → Slack notification
   - **Info Notification**: Batch job completes successfully → Post summary to #finance-ops channel
6. **Define RTO for Batch Recovery**: Specify 2-hour maximum recovery time (automate recovery to avoid waiting until morning)

---

### Issue 9: Missing Health Check Mechanisms for External Dependencies

**Location**: Section 7.5 (監視・アラート設計), Section 3.2 (主要コンポーネント)

**Description**:
While Section 7.5 includes database connection monitoring, there is no mention of health checks for external payment provider APIs, Redis availability, Pub/Sub queue connectivity, or webhook delivery status. This creates blind spots where dependency failures may not trigger alerts until customer impact occurs.

**Impact**:
- **Late Detection of Provider Outages**: System may continue accepting payment requests for a failed provider until merchant complaints arrive
- **Silent Redis Failures**: If Redis becomes unavailable, rate limiting fails open or closed depending on implementation, causing either no protection or false rejections
- **Webhook Delivery Black Holes**: Merchant webhook endpoints may be down for hours without detection, causing missed payment notifications

**Countermeasures**:
1. **Implement Provider Health Check Endpoint** (`/health/ready`):
   ```java
   @Component
   public class ProviderHealthIndicator implements HealthIndicator {
     @Override
     public Health health() {
       Map<String, Object> details = new HashMap<>();
       // Call lightweight health check endpoint for each provider
       details.put("stripe", checkStripeHealth()); // /v1/health or lightweight API call
       details.put("paypal", checkPayPalHealth());
       details.put("bank", checkBankHealth());

       boolean allHealthy = details.values().stream().allMatch(v -> v.equals("UP"));
       return allHealthy ? Health.up().withDetails(details).build()
                         : Health.down().withDetails(details).build();
     }
   }
   ```
2. **Passive Health Monitoring** (complement active health checks):
   - Track provider API success rate per minute
   - If success rate < 50% for 5 minutes, mark provider as unhealthy
   - Automatically trigger circuit breaker (Issue 1) and alert on-call
3. **Redis Health Check**:
   - Implement periodic PING command with 1-second timeout
   - If Redis unavailable, degrade gracefully:
     - Rate limiting: Fail open (allow requests) with logging
     - Session cache: Fall back to database session lookup
4. **Pub/Sub Queue Health**:
   - Monitor message publish latency (should be < 100ms)
   - Alert if publish failures > 1% for 5 minutes
   - Implement retry logic for failed publishes (exponential backoff, max 5 attempts)
5. **Webhook Delivery Monitoring**:
   - Track webhook delivery success rate per merchant
   - Retry failed webhooks with exponential backoff (1min, 5min, 30min, 2h, 8h)
   - Alert merchant after 3 failed delivery attempts
   - Provide webhook delivery status in merchant dashboard

---

## Minor Improvements and Positive Aspects

### Issue 10: Webhook Signature Verification Details Not Specified

**Location**: Section 5.2 (認証・認可方式)

**Description**:
Section 5.2 mentions "Webhook検証: HMAC署名検証" but does not specify the HMAC algorithm (SHA256, SHA512), signature header format, timestamp validation to prevent replay attacks, or signature verification failure handling.

**Impact**:
- **Replay Attack Risk**: Without timestamp validation, captured webhook payloads can be replayed indefinitely
- **Implementation Inconsistency**: Different developers may implement different HMAC schemes

**Countermeasures**:
1. **Specify HMAC Signature Scheme**:
   - Algorithm: HMAC-SHA256
   - Signature header: `X-Webhook-Signature: t=<timestamp>,v1=<signature>`
   - Signature payload: `timestamp + "." + request_body`
   - Verification:
     ```java
     String computedSignature = HMAC_SHA256(webhookSecret, timestamp + "." + requestBody);
     boolean valid = constantTimeEquals(receivedSignature, computedSignature);
     ```
2. **Timestamp Validation**: Reject webhooks with timestamps older than 5 minutes (prevents replay attacks)
3. **Multiple Signature Versions**: Support versioned signatures (v1, v2) for algorithm upgrades
4. **Merchant Webhook Signature**: Apply same HMAC scheme when sending webhooks to merchants (Section 3.3 step 6)

---

### Positive Aspects

The design demonstrates several reliability best practices:

1. **Structured Logging with Correlation IDs** (Section 6.2): Facilitates distributed tracing and incident investigation
2. **Sensitive Data Masking** (Section 6.2): Prevents accidental logging of card numbers and API keys
3. **Resilience4j Integration** (Section 2.4): Foundation for implementing retry and circuit breaker patterns
4. **Managed Database Service** (Section 7.3): Leverages Cloud SQL for built-in backups and high availability
5. **PCI DSS Compliance Approach** (Section 7.2): Token-based architecture avoids storing sensitive card data
6. **Testcontainers for Integration Testing** (Section 6.3): Enables realistic testing of database and Redis interactions
7. **Horizontal Pod Autoscaling** (Section 7.3): Provides automatic capacity scaling based on load

---

## Summary of Recommendations

**Immediate Priority** (Critical Issues - Implement Before Production):
1. Implement circuit breaker patterns for all external provider calls (Issue 1)
2. Design and implement idempotency mechanisms for all mutating operations (Issue 2)
3. Implement distributed transaction coordination with Saga/Outbox patterns (Issue 3)
4. Define and implement deployment safety mechanisms with automated rollback (Issue 4)

**High Priority** (Significant Issues - Implement Within First Month):
5. Define comprehensive SLIs/SLOs with error budgets and actionable alerts (Issue 5)
6. Implement multi-level rate limiting and backpressure mechanisms (Issue 6)

**Medium Priority** (Moderate Issues - Implement Within First Quarter):
7. Specify and implement timeout hierarchy across all layers (Issue 7)
8. Automate batch job recovery with checkpointing and retry logic (Issue 8)
9. Implement health checks for all external dependencies (Issue 9)

**Low Priority** (Minor Issues - Best Practice Improvements):
10. Specify webhook signature verification scheme details (Issue 10)

---

## Conclusion

This payment gateway design requires significant reliability hardening before production deployment. While foundational elements (managed infrastructure, retry logic, logging) are present, critical gaps in fault isolation, distributed consistency, operational observability, and deployment safety create unacceptable risk for a financial transaction system. Implementing the recommended countermeasures—particularly circuit breakers, idempotency design, distributed transaction coordination, and deployment safety mechanisms—is essential to achieve the 99.9% availability target and maintain data consistency guarantees expected of payment processing systems.
