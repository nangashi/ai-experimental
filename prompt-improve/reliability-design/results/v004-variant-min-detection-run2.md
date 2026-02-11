# Reliability Design Review: Payment Gateway System

## Executive Summary

This review evaluates the Payment Gateway System design from a reliability engineering perspective, focusing on fault tolerance, operational readiness, and production system resilience. The analysis identifies **11 reliability issues** across critical, significant, and moderate severity levels, organized by evaluation criteria.

---

## Critical Issues

### Issue 1: Missing Circuit Breaker Implementation for Provider API Calls

**Severity:** Critical
**Category:** Fault Recovery Design
**Location:** Section 7.4 (障害回復設計)

**Description:**
The design specifies retry logic with exponential backoff but lacks circuit breaker patterns for external provider API calls. Without circuit breakers, the system will continue retrying failed provider APIs even when the provider is experiencing widespread outages, leading to:
- Thread pool exhaustion from blocking retry operations
- Cascading failures as upstream requests queue behind failing provider calls
- Inability to fail fast and provide alternative responses to merchants

**Impact Analysis:**
In a scenario where Stripe API experiences a 5-minute outage:
1. All payment requests targeting Stripe will attempt 3 retries with exponential backoff (1s, 2s, 4s = ~7s per request)
2. With 1000 TPS target, this creates 7000 concurrent blocked operations within seconds
3. Thread pool exhaustion causes the entire API service to become unresponsive
4. Healthy provider requests (PayPal, bank transfers) are also impacted
5. System-wide outage occurs despite only one provider being down

**Countermeasures:**
1. Implement Resilience4j CircuitBreaker with the following configuration:
   - **Failure threshold:** 50% error rate over 10 requests (sliding window)
   - **Open state duration:** 30 seconds before attempting half-open state
   - **Half-open test requests:** 5 requests to validate recovery
2. Return fast-fail responses when circuit is open (HTTP 503 with provider-specific error code)
3. Implement provider health endpoints that check circuit breaker states
4. Design fallback strategies:
   - For payment authorization: Return explicit "provider unavailable" error to merchant
   - For webhook processing: Queue messages for delayed retry after circuit closes
5. Add circuit breaker state metrics to Grafana dashboards with alerts on state transitions

**References:** Section 7.4 mentions Resilience4j but only specifies retry configuration, not circuit breaker patterns

---

### Issue 2: No Idempotency Design for Payment Operations

**Severity:** Critical
**Category:** Data Consistency & Idempotency
**Location:** Section 5.1 (API設計), Section 7.6 (データ整合性設計)

**Description:**
The design lacks explicit idempotency mechanisms for payment operations. The API endpoints do not require or support idempotency keys, and there is no duplicate detection strategy. This creates significant risks:
- Network timeouts cause merchants to retry requests, potentially charging customers multiple times
- Webhook replay (common during provider infrastructure issues) can trigger duplicate refund processing
- Race conditions between concurrent capture/refund operations on the same transaction

**Impact Analysis:**
Consider a scenario where a merchant's payment request times out after 30 seconds:
1. Transaction record is created in database (status: PENDING)
2. Provider API call succeeds but response is lost due to network timeout
3. Merchant receives HTTP 504 timeout error and retries the request
4. Second request creates a new transaction, charges the customer again
5. Customer is double-charged; merchant faces chargeback disputes
6. No automated way to detect or reconcile the duplicate charges

For webhook processing:
1. Provider sends successful payment webhook
2. Webhook Processor updates transaction to CAPTURED and triggers merchant notification
3. Network glitch causes provider to retry webhook (standard practice)
4. Second webhook processing attempts to capture the same payment again
5. Without idempotency checks, this could trigger duplicate merchant notifications or accounting entries

**Countermeasures:**
1. **Require Idempotency-Key header** for all mutating operations (POST /v1/payments, /capture, /refund):
   ```
   X-Idempotency-Key: <client-generated-uuid>
   ```
2. **Implement idempotency key storage**:
   - Create `idempotency_keys` table: (key, response_body, response_status, created_at, expires_at)
   - Set 24-hour retention for idempotency records
   - On duplicate key, return cached response with HTTP 200 (not 409 Conflict)
3. **Add unique constraint** on critical operations:
   - Transactions table: Add unique index on (merchant_id, merchant_order_id) if merchant provides order ID
   - Refunds table: Add unique index on (transaction_id, refund_request_id)
4. **Design webhook idempotency**:
   - Store provider webhook event IDs in `processed_webhook_events` table
   - Check event ID before processing; skip if already processed
   - Return HTTP 200 for duplicate events (idempotent acknowledgment)
5. **Add operation-level locks** for critical state transitions:
   - Use Redis distributed locks (SETNX) with 30-second TTL during capture/refund operations
   - Lock key pattern: `lock:transaction:{transaction_id}:operation`

**References:** Section 5.1 defines API endpoints without idempotency requirements; Section 7.6 mentions consistency but not duplicate prevention

---

### Issue 3: No Explicit Timeout Configuration for Provider APIs

**Severity:** Critical
**Category:** Fault Recovery Design
**Location:** Section 7.4 (障害回復設計)

**Description:**
The design defers timeout configuration to "implementation phase" without specifying concrete values or timeout strategy. This is a critical reliability gap because:
- Missing timeouts cause indefinite blocking on unresponsive provider APIs
- Default HTTP client timeouts (often 60-120 seconds) are too long for payment systems
- Different providers have different SLAs requiring different timeout configurations
- Without documented timeouts, operations teams cannot set appropriate monitoring thresholds

**Impact Analysis:**
In a production scenario where a provider API becomes unresponsive (e.g., DNS resolution hangs, TCP connection half-open):
1. Payment API thread blocks indefinitely waiting for response
2. With 1000 TPS, within 10 seconds all available threads are exhausted
3. Kubernetes liveness probe fails (typically 30-second threshold)
4. Pod is killed and restarted, but immediately enters same failure mode
5. CrashLoopBackoff state is reached; entire payment system becomes unavailable

**Countermeasures:**
1. **Define provider-specific timeout configurations**:
   ```
   Stripe API:
   - Connection timeout: 3 seconds
   - Read timeout: 10 seconds
   - Total request timeout: 15 seconds

   PayPal API:
   - Connection timeout: 5 seconds
   - Read timeout: 15 seconds
   - Total request timeout: 20 seconds

   Bank APIs:
   - Connection timeout: 5 seconds
   - Read timeout: 30 seconds (bank APIs are typically slower)
   - Total request timeout: 40 seconds
   ```
2. **Implement hierarchical timeout strategy**:
   - API Gateway timeout: 45 seconds (must exceed longest provider timeout)
   - Provider Gateway timeout: Provider-specific (as above)
   - Resilience4j TimeLimiter: Wrap provider calls with total timeout enforcement
3. **Add timeout monitoring**:
   - Track timeout occurrence rate per provider
   - Alert on timeout rate > 1% for any provider
   - Dashboard showing timeout distribution (connection vs. read timeouts)
4. **Document timeout rationale** in design document:
   - Link timeouts to provider SLA documentation
   - Explain buffer calculations for cascading timeouts
   - Define timeout tuning procedures based on production metrics

**References:** Section 7.4 explicitly defers timeout configuration: "タイムアウトは、プロバイダーごとに異なる値を設定する予定だが、具体的な値は実装フェーズで決定する"

---

## Significant Issues

### Issue 4: Single Database Instance Creates Single Point of Failure

**Severity:** Significant
**Category:** Availability, Redundancy & Disaster Recovery
**Location:** Section 2.2 (データベース), Section 7.3 (可用性・スケーラビリティ)

**Description:**
The design specifies "Cloud SQL (managed service)" for the PostgreSQL database but does not explicitly document:
- High availability configuration (e.g., regional standby replicas)
- Failover strategy and Recovery Time Objective (RTO)
- Read replica setup for query load distribution
- Backup/restore procedures and Recovery Point Objective (RPO)

While managed services provide some HA capabilities, the design must explicitly specify the HA configuration and failover behavior to ensure the 99.9% availability SLA can be met.

**Impact Analysis:**
Assuming standard Cloud SQL configuration without explicit HA:
1. Primary database instance failure occurs (e.g., node hardware failure, zone outage)
2. Automatic failover to standby takes 60-120 seconds (typical Cloud SQL HA failover time)
3. During failover window:
   - All payment operations fail (cannot read/write transaction state)
   - 1000 TPS × 90 seconds = 90,000 failed payment requests
   - No visibility into in-flight transaction states
4. After failover:
   - Application layer must handle connection re-establishment
   - In-flight transactions may be in inconsistent state (PENDING without provider confirmation)
   - Reconciliation batch job required to verify transaction states with providers

For availability calculation:
- 99.9% SLA allows 43 minutes downtime per month
- A single 90-second database failover event = 2.5% of monthly error budget
- Multiple failover events or prolonged recovery could breach SLA

**Countermeasures:**
1. **Enable Cloud SQL High Availability**:
   - Configure regional HA with synchronous replication to standby instance in different zone
   - Document expected failover time: 60-120 seconds
   - Set up automatic failover with health check interval: 10 seconds
2. **Implement read replicas**:
   - Create 2 read replicas for transaction query operations (GET /v1/payments/{id})
   - Configure application to route read operations to replicas
   - Accept eventual consistency (typically <1 second lag) for non-critical reads
3. **Define and test failover procedures**:
   - RTO target: 2 minutes (includes detection + failover + validation)
   - RPO target: 0 seconds (synchronous replication ensures zero data loss)
   - Document application-layer failover handling:
     - Connection pool must support automatic DNS re-resolution
     - Spring Boot application properties: `spring.datasource.hikari.connection-timeout=10000`
     - Implement retry logic for transient database connection errors
4. **Design transaction reconciliation process**:
   - After database failover, run reconciliation job to identify PENDING transactions
   - Query provider APIs to retrieve actual transaction states
   - Update local database to reflect provider-of-record states
5. **Implement database backup strategy**:
   - Automated daily backups with 30-day retention
   - Transaction log backups every 5 minutes (RPO: 5 minutes for disaster scenarios)
   - Quarterly restore testing to validate backup integrity
   - Document restore procedure runbook

**References:** Section 7.3 mentions managed Cloud SQL but lacks HA configuration details

---

### Issue 5: No Defined SLO/SLA Metrics or Error Budget Strategy

**Severity:** Significant
**Category:** Monitoring & Alerting Design
**Location:** Section 7.1 (パフォーマンス目標), Section 7.5 (監視・アラート設計)

**Description:**
The design specifies performance targets (p95 < 500ms, 1000 TPS) and availability goals (99.9%) but lacks:
- Formal Service Level Indicators (SLIs) definition
- Service Level Objectives (SLOs) with measurement methodology
- Error budget calculation and consumption tracking
- SLO-based alerting thresholds (vs. symptom-based alerts)
- Release velocity decisions based on error budget

This is a significant operational readiness gap because without SLOs:
- No objective criteria for "system health" during incidents
- No data-driven approach to prioritize reliability work vs. feature development
- Difficult to justify deployment rollbacks or release freezes
- Lack of alignment between engineering and business on acceptable reliability levels

**Impact Analysis:**
In a scenario where a new deployment introduces a latency regression:
1. p95 latency increases from 400ms to 700ms (30% degradation)
2. No SLO threshold defined, so it's unclear if this requires immediate rollback
3. Engineering debates: "Is 700ms acceptable? Most requests are still fast (p50 remains at 200ms)"
4. Without error budget, no framework to decide: "We've consumed 50% of monthly budget, we must roll back"
5. Incident response is delayed by debate; customer impact accumulates
6. Post-incident, no clear metrics to track recovery or prevent recurrence

For availability:
1. 99.9% availability allows 43 minutes downtime per month
2. Without SLO tracking, there's no visibility into error budget consumption
3. If 20 minutes of downtime occurs in week 1, is it safe to deploy risky changes in week 3?
4. Without error budget tracking, team has no data to inform risk decisions

**Countermeasures:**
1. **Define formal SLIs**:
   ```
   Availability SLI:
   - Numerator: Count of successful API responses (HTTP 2xx, 3xx)
   - Denominator: Count of all API responses
   - Measurement: Per-minute aggregation from API Gateway logs

   Latency SLI:
   - Metric: Server-side request duration (p95)
   - Measurement: From Spring Boot Micrometer timer metrics
   - Scope: Measured at API Gateway layer before provider latency

   Correctness SLI:
   - Numerator: Transactions with consistent provider vs. local state
   - Denominator: All completed transactions
   - Measurement: Daily reconciliation batch job
   ```

2. **Define SLOs with business alignment**:
   ```
   Tier 1 SLOs (Critical - Affects Immediate Revenue):
   - Payment Creation API Availability: 99.9% (43 min/month)
   - Payment Creation API Latency: 95% of requests < 500ms

   Tier 2 SLOs (Important - Affects Operations):
   - Transaction Query API Availability: 99.5% (3.6 hours/month)
   - Webhook Delivery Success Rate: 99% (allows retry logic)

   Tier 3 SLOs (Best Effort):
   - Admin Console Availability: 99% (7.2 hours/month)
   - Reporting API Latency: 95% < 2 seconds
   ```

3. **Implement error budget tracking**:
   - Calculate error budget consumption in real-time:
     ```
     Error Budget Consumption = (1 - Actual SLI) / (1 - SLO Target)
     Example: If Availability SLO is 99.9% and actual is 99.8%:
     Consumption = (1 - 0.998) / (1 - 0.999) = 0.002 / 0.001 = 200% (budget exceeded)
     ```
   - Dashboard showing:
     - Current error budget remaining (%)
     - Projected end-of-month consumption
     - Top error budget consumers (by API endpoint, by failure type)
   - Alert when error budget consumption > 50% within any 7-day window

4. **Define error budget policy**:
   ```
   Error Budget Remaining > 50%:
   - Normal release cadence (daily deployments allowed)
   - Feature development prioritized

   Error Budget Remaining 20-50%:
   - Release freeze for non-critical changes
   - All deployments require approval + extra canary monitoring
   - Reliability tasks prioritized over new features

   Error Budget Remaining < 20%:
   - Full release freeze except critical bug fixes
   - Incident review required before any deployment
   - Mandatory postmortem for all SLO violations
   ```

5. **Implement SLO-based alerting**:
   - Replace symptom-based alerts ("error rate > 5%") with SLO-based alerts:
     - **Burn rate alerts**: "At current error rate, we'll exhaust error budget in 2 days"
     - Multi-window approach:
       - Fast burn (1-hour window): Detect severe outages immediately
       - Slow burn (24-hour window): Detect gradual degradation
   - Example Prometheus alert:
     ```
     alert: FastBurnRateAlert
     expr: (1 - avg_over_time(availability_sli[1h])) / (1 - 0.999) > 14.4
     annotation: Consuming error budget 14.4x faster than sustainable rate
     ```

**References:** Section 7.1 defines performance targets but not SLOs; Section 7.5 lists monitoring metrics but lacks SLO framework

---

### Issue 6: Webhook Delivery Has No Retry or Dead Letter Queue Strategy

**Severity:** Significant
**Category:** Fault Recovery Design
**Location:** Section 3.3 (データフロー), Section 3.2 (主要コンポーネント - Webhook Processor)

**Description:**
The design includes webhook notification to merchants (step 6 in data flow) but does not specify:
- Retry strategy for failed webhook deliveries
- Timeout configuration for merchant webhook endpoints
- Dead letter queue for permanently failed webhooks
- Webhook delivery status tracking and observability
- Merchant notification of webhook delivery failures

This creates reliability risks:
- Merchant systems are temporarily down → Payment notifications are lost
- Network issues during webhook delivery → No retry mechanism
- Slow merchant endpoints → Webhook processor thread exhaustion
- No way for merchants to query missed webhooks

**Impact Analysis:**
In a scenario where a merchant's webhook endpoint experiences a 10-minute outage:
1. 100 successful payments occur during the outage window
2. Webhook Processor attempts to deliver 100 notifications
3. All webhook deliveries fail (connection timeout, HTTP 503, etc.)
4. Without retry strategy, all 100 notifications are lost
5. Merchant's system never learns about successful payments
6. Customer support tickets flood in: "I paid but order isn't confirmed"
7. Merchant must manually reconcile by polling GET /v1/payments API for all recent transactions

For slow merchant endpoints:
1. Merchant webhook endpoint is responding slowly (10 seconds per request)
2. Webhook Processor synchronously waits for response
3. With 1000 TPS, webhook threads are exhausted within seconds
4. New payment processing is blocked waiting for webhook delivery
5. System-wide latency degradation affects all merchants

**Countermeasures:**
1. **Implement asynchronous webhook delivery with retry**:
   - Use Google Cloud Pub/Sub for webhook delivery queue
   - Webhook Processor publishes to `webhook-delivery` topic
   - Separate webhook delivery worker subscribes and processes
   - Decouples payment processing from webhook delivery latency

2. **Define webhook retry policy**:
   ```
   Retry Strategy:
   - Max retries: 10 attempts
   - Backoff: Exponential with jitter
     - Attempt 1: Immediate
     - Attempt 2: 1 minute
     - Attempt 3: 10 minutes
     - Attempt 4: 1 hour
     - Attempts 5-10: Every 6 hours
   - Total retry window: 60 hours

   Retry Conditions:
   - Connection timeout
   - HTTP 5xx errors
   - HTTP 429 (rate limit)

   Non-Retriable Conditions:
   - HTTP 4xx errors (except 429)
   - TLS certificate validation failure
   - Invalid merchant webhook URL
   ```

3. **Implement webhook timeout and circuit breaker**:
   - Webhook delivery timeout: 10 seconds
   - Circuit breaker per merchant (not global):
     - Open circuit after 5 consecutive failures
     - Half-open state after 5 minutes
     - Prevents cascading failures from one merchant's broken endpoint

4. **Design Dead Letter Queue (DLQ) strategy**:
   - After 10 failed retries, move webhook event to DLQ
   - Store in `failed_webhook_deliveries` table:
     - merchant_id, transaction_id, webhook_payload, failure_reason, retry_attempts, created_at
   - Provide merchant API endpoint to retrieve failed webhooks:
     - `GET /v1/webhooks/failed?since=<timestamp>`
   - Send email notification to merchant after webhook moves to DLQ

5. **Add webhook delivery observability**:
   - Metrics:
     - Webhook delivery success rate (per merchant, per event type)
     - Webhook delivery latency (p50, p95, p99)
     - Retry queue depth
     - DLQ size
   - Dashboard:
     - Top merchants by webhook failure rate
     - Webhook delivery funnel (success, retry, DLQ)
   - Alerts:
     - Webhook delivery success rate < 95% for any merchant over 1 hour
     - DLQ size > 1000 events

**References:** Section 3.3 step 6 mentions webhook notification but lacks delivery guarantees; Section 3.2 describes Webhook Processor without retry logic

---

## Moderate Issues

### Issue 7: No Rate Limiting or Backpressure Mechanisms

**Severity:** Moderate
**Category:** Fault Recovery Design
**Location:** Section 2.2 (Redis for レート制限カウンタ), Section 7.3 (スケーラビリティ)

**Description:**
The design mentions "レート制限カウンタ" in Redis but does not specify:
- Rate limiting strategy (per-merchant quotas, global system limits)
- Rate limit thresholds and enforcement points
- Backpressure mechanisms when system approaches capacity
- Load shedding strategy during overload conditions
- Response to clients when rate limits are exceeded

Without explicit rate limiting design:
- Misbehaving merchants can exhaust system resources
- No protection against DDoS or retry storms
- System cannot gracefully degrade under overload

**Impact Analysis:**
In a scenario where a merchant's system has a bug causing retry storms:
1. Merchant's buggy code retries failed payments 100x per second
2. Without rate limiting, all 100 requests are processed
3. Failed payments consume database connections, provider API quotas
4. Other merchants experience latency degradation (noisy neighbor problem)
5. Provider APIs start rate-limiting the gateway (e.g., Stripe 429 errors)
6. All merchants are now affected by one merchant's bug

During a traffic spike (e.g., flash sale):
1. Traffic increases from 1000 TPS to 5000 TPS
2. Horizontal Pod Autoscaler scales pods, but takes 2-3 minutes
3. During scaling window, system is overloaded
4. Database connection pool exhaustion occurs
5. All requests fail with 500 errors (0% success rate)
6. Better to reject 80% with 503 and succeed on 20% than fail 100%

**Countermeasures:**
1. **Implement merchant-level rate limiting**:
   ```
   Rate Limits:
   - Standard merchants: 100 requests/second, 10,000 requests/hour
   - Premium merchants: 500 requests/second, 50,000 requests/hour
   - Burst allowance: 2x sustained rate for 10 seconds

   Implementation:
   - Use Redis token bucket algorithm
   - Key pattern: rate_limit:{merchant_id}:{window}
   - Return HTTP 429 with Retry-After header when exceeded
   ```

2. **Implement global system rate limiting**:
   ```
   System Limits:
   - Total payment creation: 5000 TPS (50% above target capacity)
   - Per-provider limits based on provider quotas:
     - Stripe: 2000 TPS
     - PayPal: 1500 TPS
     - Bank APIs: 500 TPS
   ```

3. **Design load shedding strategy**:
   - Monitor system health indicators:
     - Database connection pool utilization
     - Pod CPU/memory usage
     - Provider API error rates
   - When health indicator exceeds threshold, enable load shedding:
     - Reject lowest priority traffic first (e.g., admin console queries)
     - Accept payment creation requests (revenue-critical)
     - Return HTTP 503 with Retry-After: 60 seconds
   - Gradual recovery: Reduce rejection rate as health improves

4. **Implement backpressure propagation**:
   - If provider API returns 429 rate limit, propagate to merchant immediately
   - Don't retry provider rate limits (wastes retry attempts)
   - Implement provider quota monitoring to predict rate limit approach

5. **Add rate limiting observability**:
   - Metrics: Rate limit rejections per merchant, per endpoint
   - Dashboard: Top merchants by rejection rate
   - Alert: Rate limit rejections > 5% for any merchant over 10 minutes

**References:** Section 2.2 mentions rate limit counters but lacks strategy; Section 7.3 describes autoscaling but not overload protection

---

### Issue 8: Insufficient Monitoring Coverage for Payment System Reliability

**Severity:** Moderate
**Category:** Monitoring & Alerting Design
**Location:** Section 7.5 (監視・アラート設計)

**Description:**
The monitoring design lists basic metrics (request count, response time, error rate, DB connections) but is missing critical payment system-specific observability:

**Missing Monitoring Dimensions:**
1. **Provider-specific health metrics**: Success rate, latency, timeout rate per provider (Stripe, PayPal, bank APIs)
2. **Transaction state distribution**: Count of transactions in each state (PENDING, AUTHORIZED, CAPTURED, etc.)
3. **Transaction aging alerts**: Transactions stuck in PENDING for > 5 minutes
4. **Reconciliation metrics**: Mismatch rate between local DB and provider state
5. **Webhook processing metrics**: Delivery success rate, retry queue depth
6. **Business metrics**: Successful payment rate, refund rate, average transaction value

Without these metrics, operators cannot:
- Quickly identify which provider is causing failures
- Detect stuck transactions requiring manual intervention
- Measure actual business impact of incidents

**Impact Analysis:**
During a partial provider outage:
1. Stripe API returns intermittent 500 errors (50% failure rate)
2. Generic "error rate" metric increases from 1% to 25%
3. On-call engineer receives alert but cannot identify root cause
4. Manual investigation required: Check logs, correlate timestamps, query each provider
5. Mean Time to Detect (MTTD) = 15 minutes (delayed by investigation)
6. Mean Time to Resolve (MTTR) = 30 minutes (includes time to identify Stripe as culprit)

With provider-specific metrics:
- Dashboard immediately shows "Stripe success rate: 50%"
- MTTD reduced to < 1 minute
- Operations team can immediately: Enable circuit breaker for Stripe, notify merchants, contact Stripe support

**Countermeasures:**
1. **Implement RED metrics per provider**:
   ```
   Metrics (labeled by provider):
   - payment_requests_total{provider="stripe", status="success|failure"}
   - payment_request_duration_seconds{provider="stripe"}
   - payment_errors_total{provider="stripe", error_type="timeout|5xx|4xx"}
   ```

2. **Add transaction state monitoring**:
   ```
   Metrics:
   - transactions_by_state{state="PENDING|AUTHORIZED|CAPTURED|SETTLED|FAILED"}
   - transaction_state_duration_seconds{state="PENDING"} (histogram)

   Alerts:
   - Transaction stuck in PENDING > 5 minutes: Investigate provider API
   - Transaction stuck in AUTHORIZED > 24 hours: Auto-void authorization
   - Spike in FAILED state (> 5% rate): Page on-call
   ```

3. **Implement reconciliation monitoring**:
   ```
   Daily batch job metrics:
   - reconciliation_mismatch_count (expected vs. actual states)
   - reconciliation_duration_seconds
   - reconciliation_success_rate

   Alert if mismatch count > 10 per day
   ```

4. **Add business-level dashboards**:
   - Real-time payment success rate (target: > 98%)
   - Hourly revenue (detect revenue drops immediately)
   - Top failure reasons by count
   - Provider comparison: Success rate, latency, cost per transaction

5. **Implement distributed tracing**:
   - Use OpenTelemetry or similar for end-to-end request tracing
   - Trace critical flows:
     - Payment creation: API Gateway → Transaction Manager → Provider Gateway → Provider API
     - Webhook processing: Provider → Webhook Processor → Database → Merchant notification
   - Store traces for 7 days to support incident investigation

6. **Define alert escalation policy**:
   ```
   Severity 1 (Page immediately):
   - Payment success rate < 90% for > 5 minutes
   - All providers failing simultaneously
   - Database connection failures

   Severity 2 (Notify on-call, 15-min response SLA):
   - Single provider success rate < 80% for > 10 minutes
   - Transaction reconciliation mismatch > 50 per hour
   - Webhook delivery success rate < 80%

   Severity 3 (Ticket for business hours):
   - Provider latency p95 > 2x baseline
   - Redis connection issues (graceful degradation)
   - Admin console errors
   ```

**References:** Section 7.5 lists generic monitoring items but lacks payment-specific observability

---

### Issue 9: Batch Settlement Process Lacks Fault Tolerance and Recovery Design

**Severity:** Moderate
**Category:** Fault Recovery Design
**Location:** Section 7.7 (バッチ処理設計)

**Description:**
The batch settlement process design has significant reliability gaps:
1. **Manual recovery requirement**: "障害が発生した場合は、アラートを発報し、翌朝手動でリカバリを行う"
2. **No retry or partial success handling**: If batch fails midway, unclear how to resume
3. **No idempotency design**: Rerunning batch may duplicate state transitions
4. **Single-threaded processing**: No mention of partition strategy for scale
5. **No visibility into batch progress**: Operators don't know how many transactions are pending settlement

**Impact Analysis:**
In a scenario where the batch settlement job fails after processing 50% of transactions:
1. Batch starts at 2:00 AM, processes 5,000 of 10,000 CAPTURED transactions
2. Database connection timeout occurs (e.g., Cloud SQL maintenance window)
3. Batch job crashes, sends alert
4. Operations team sees alert at 9:00 AM (7-hour delay)
5. Unclear which transactions were successfully settled:
   - No checkpoint mechanism to track progress
   - No way to identify "already processed" vs. "needs processing"
6. Operations must manually query database to determine state
7. Decision: Re-run entire batch? Risk of duplicate settlement
8. Manual investigation takes 2 hours; customer support is fielded questions about "missing" settlements

For scale concerns:
- If transaction volume grows to 100,000 per day, single-threaded batch may not complete within maintenance window
- No partition strategy (e.g., by merchant, by time window) to parallelize processing

**Countermeasures:**
1. **Implement batch job checkpointing**:
   ```
   Spring Batch Configuration:
   - Chunk-oriented processing: Commit every 100 transactions
   - Job execution metadata stored in batch_job_execution table
   - On failure, restart from last committed chunk (not from beginning)
   ```

2. **Design batch idempotency**:
   - Before updating transaction status, check current state:
     ```sql
     UPDATE transactions
     SET status = 'SETTLED', updated_at = NOW()
     WHERE id = ? AND status = 'CAPTURED'
     ```
   - WHERE clause ensures idempotent update (only updates if still CAPTURED)
   - If already SETTLED, skip silently (safe retry)

3. **Implement partition strategy for scale**:
   ```
   Partitioning:
   - Partition by merchant_id hash (10 partitions)
   - Each partition runs as separate Spring Batch step
   - Parallel execution with thread pool (5 concurrent partitions)
   - Total batch time = (Total transactions / Partitions / Chunk size) * Processing time per chunk

   Example:
   - 100,000 transactions / 10 partitions / 100 chunk size = 100 chunks per partition
   - At 1 second per chunk, 100 seconds per partition
   - With 5 parallel threads, total time = 200 seconds (3.3 minutes)
   ```

4. **Add batch job monitoring and alerting**:
   ```
   Metrics:
   - batch_settlement_duration_seconds (histogram)
   - batch_settlement_processed_count
   - batch_settlement_failed_count
   - batch_settlement_success_rate

   Alerts:
   - Batch job failure (immediate page)
   - Batch duration > 30 minutes (warning, may not complete)
   - Batch success rate < 99% (investigate failed transactions)

   Dashboard:
   - Current batch status: Running/Completed/Failed
   - Progress indicator: X of Y transactions processed
   - ETA to completion
   - Historical batch duration trend
   ```

5. **Design automated retry strategy**:
   - On failure, automatically retry up to 3 times with 5-minute delay
   - If retry fails, send alert for manual intervention
   - Include failure context in alert:
     - Exception message
     - Last successful chunk number
     - Count of remaining transactions to process

6. **Document manual recovery runbook**:
   ```
   Recovery Steps:
   1. Query batch_job_execution to find last successful chunk
   2. Identify unprocessed transactions: SELECT id FROM transactions WHERE status='CAPTURED'
   3. Restart batch job with parameter: --restart --job-execution-id=<id>
   4. Monitor progress via admin dashboard
   5. After completion, reconcile with provider APIs to validate settlements
   ```

**References:** Section 7.7 explicitly states manual recovery: "アラートを発報し、翌朝手動でリカバリを行う"

---

### Issue 10: No Explicit Transaction Timeout or Automatic Cancellation Policy

**Severity:** Moderate
**Category:** Data Consistency & Idempotency
**Location:** Section 4.1 (Transactions テーブル), Section 3.3 (データフロー)

**Description:**
The design does not specify what happens to transactions that remain in PENDING or AUTHORIZED states indefinitely:
- No TTL (time-to-live) policy for PENDING transactions
- No automatic cancellation for expired payment authorizations
- No background job to clean up stale transactions
- Unclear merchant behavior when transaction is stuck

This creates operational and data consistency issues:
- Database accumulates stale PENDING transactions
- Merchants cannot distinguish between "processing" vs. "stuck" transactions
- Authorized funds remain held on customer cards indefinitely (poor UX, regulatory issues)

**Impact Analysis:**
In a scenario where provider webhook is never delivered (rare but happens):
1. Payment authorization succeeds at provider (Stripe returns HTTP 200)
2. Local transaction status: AUTHORIZED
3. Provider's webhook delivery fails permanently (e.g., incorrect webhook URL configuration)
4. Transaction remains in AUTHORIZED state forever
5. Customer's funds are held on their card but never captured
6. After 7 days, Stripe automatically voids the authorization (standard practice)
7. Local database still shows AUTHORIZED, creating state mismatch
8. Merchant attempts to capture → fails with "authorization not found" error
9. Customer support escalation required

For PENDING transactions:
1. Payment request is created, transaction enters PENDING state
2. Provider API call times out or fails before completion
3. Transaction remains in PENDING state
4. Merchant polls GET /v1/payments/{id} repeatedly → always returns PENDING
5. No automated cleanup, so PENDING transactions accumulate in database
6. Over time, millions of stale PENDING records degrade query performance

**Countermeasures:**
1. **Define transaction timeout policy**:
   ```
   Transaction State TTL:
   - PENDING: 5 minutes (if no provider response, mark as FAILED)
   - AUTHORIZED: 7 days (after which, auto-void to match provider behavior)
   - CAPTURED: 30 days (after which, mark as SETTLED via daily batch)
   ```

2. **Implement background cleanup job**:
   ```
   Scheduled Job (every 5 minutes):
   - Query: SELECT id FROM transactions WHERE status='PENDING' AND created_at < NOW() - INTERVAL '5 minutes'
   - For each expired PENDING transaction:
     1. Query provider API to check actual status
     2. If provider has no record → Update to FAILED
     3. If provider has success record → Update to AUTHORIZED/CAPTURED
     4. If provider has failure record → Update to FAILED
   - Metrics: Count of expired transactions, auto-failure count, reconciliation count
   ```

3. **Implement authorization expiry handling**:
   ```
   Daily Job (AM 3:00 JST):
   - Query: SELECT id FROM transactions WHERE status='AUTHORIZED' AND created_at < NOW() - INTERVAL '7 days'
   - For each expired authorization:
     1. Query provider API to verify authorization status
     2. If authorization still valid → Log warning, extend monitoring
     3. If authorization voided → Update local status to EXPIRED
     4. Send merchant notification: "Authorization expired, cannot capture"
   ```

4. **Add transaction timeout to API responses**:
   ```json
   POST /v1/payments response:
   {
     "transaction_id": "uuid",
     "status": "PENDING",
     "created_at": "2024-01-01T00:00:00Z",
     "expires_at": "2024-01-01T00:05:00Z"  // +5 minutes
   }
   ```
   - Merchant can use expires_at to implement client-side timeout
   - After expires_at, merchant should query transaction status, not assume success

5. **Add transaction timeout monitoring**:
   ```
   Metrics:
   - transactions_expired_total{state="PENDING|AUTHORIZED"}
   - transaction_state_age_seconds{state="PENDING"} (histogram)

   Alerts:
   - Expired PENDING transactions > 100 per hour (indicates provider API issues)
   - AUTHORIZED transactions approaching 7-day limit (> 1000 transactions at 6.5 days)
   ```

**References:** Section 4.1 defines transaction status enum but lacks lifecycle policy; Section 3.3 data flow doesn't specify timeout handling

---

### Issue 11: No Disaster Recovery or Backup Strategy for Redis Cache

**Severity:** Moderate
**Category:** Availability, Redundancy & Disaster Recovery
**Location:** Section 2.2 (データベース - Redis)

**Description:**
The design specifies Redis for session storage and rate limiting counters but does not address:
- Redis high availability configuration (e.g., Redis Sentinel, Redis Cluster)
- Backup and restore strategy for Redis data
- Failover behavior when Redis becomes unavailable
- Impact of cache loss on system functionality

While Redis is often treated as ephemeral cache, in this design it stores:
1. **Rate limiting counters**: Loss causes rate limit reset (security risk)
2. **Session data**: Loss may cause authentication disruption

**Impact Analysis:**
In a scenario where Redis instance fails (e.g., node crash, zone outage):
1. Redis becomes unavailable, all cache operations fail
2. **Rate limiting failure**:
   - If application fails open: No rate limiting enforced (DDoS vulnerability)
   - If application fails closed: All requests rejected (availability impact)
3. **Session storage failure**:
   - If sessions are lost: All merchants must re-authenticate (disruption)
   - If session validation fails open: Potential unauthorized access
4. **Recovery**:
   - New Redis instance provisioned (5-10 minutes)
   - All rate limit counters reset to zero
   - Potential for rate limit bypass during recovery window

For rate limiting specifically:
- If Redis fails and application continues without rate limiting, a single merchant can overwhelm the system
- If rate limiting fails closed (safe default), all merchants are impacted by Redis failure

**Countermeasures:**
1. **Enable Redis High Availability**:
   ```
   Configuration:
   - Use Google Cloud Memorystore (managed Redis) with HA enabled
   - Standard Tier: Automatic failover with < 2 minute RTO
   - Replication: Primary + replica in different zones
   - Automatic failover: Managed by Google Cloud
   ```

2. **Implement graceful degradation for Redis failures**:
   ```
   Rate Limiting Fallback:
   - On Redis connection failure, use in-memory rate limiter per pod:
     - Caffeine cache with TTL-based expiry
     - Note: This is per-pod, not global, so limits are less strict
     - Better than no rate limiting
   - Log Redis failures for investigation

   Session Storage Fallback:
   - Store session data in database (slower but reliable)
   - Cache-aside pattern: Check Redis → fallback to DB on miss
   - On Redis recovery, warm cache from DB
   ```

3. **Design Redis backup strategy**:
   ```
   Backup:
   - Enable RDB snapshots every 6 hours
   - AOF (Append-Only File) with fsync every second (RPO: 1 second)
   - Store backups in Cloud Storage with 30-day retention

   Disaster Recovery:
   - RPO: 1 second (AOF persistence)
   - RTO: 10 minutes (provision new instance + restore from backup)
   - Quarterly DR drill: Restore Redis from backup, validate data integrity
   ```

4. **Add Redis monitoring**:
   ```
   Metrics:
   - redis_up (availability probe)
   - redis_connected_clients
   - redis_memory_used_bytes
   - redis_commands_total (throughput)
   - redis_command_duration_seconds (latency)

   Alerts:
   - Redis unavailable for > 1 minute (page on-call)
   - Redis memory usage > 80% (risk of OOM eviction)
   - Redis connection pool exhaustion
   ```

5. **Document Redis failure runbook**:
   ```
   Response Steps:
   1. Verify Redis availability via Cloud Console
   2. Check application logs for Redis connection errors
   3. If failover in progress, monitor automatic recovery (< 2 minutes)
   4. If manual intervention required:
      - Promote replica to primary (if using self-managed Redis)
      - Update application connection string
      - Restart application pods to refresh connections
   5. Post-recovery:
      - Validate rate limiting is enforced
      - Check for any anomalous traffic during outage
   ```

**References:** Section 2.2 mentions Redis for cache but lacks HA and DR strategy

---

## Positive Aspects

The design demonstrates several reliability strengths:

1. **Resilience4j Integration**: The use of Resilience4j for retry logic with exponential backoff shows awareness of fault tolerance patterns, though it needs expansion to include circuit breakers and timeouts.

2. **Structured Logging with Correlation IDs**: The logging design (Section 6.2) includes correlation IDs for request tracing, which is essential for distributed system debugging.

3. **Separation of Concerns**: The layered architecture (API Gateway, Application, Integration, Data layers) provides clear failure isolation boundaries.

4. **Managed Services**: The use of Cloud SQL and Google Cloud Pub/Sub reduces operational burden and leverages proven infrastructure reliability.

5. **Testcontainers for Integration Testing**: The test strategy (Section 6.3) includes Testcontainers for PostgreSQL and Redis, enabling reliable local testing that mirrors production behavior.

---

## Summary and Recommendations

This review identified **11 reliability issues** across three severity levels:

**Critical (3 issues):**
- Missing circuit breaker implementation
- No idempotency design for payment operations
- Undefined timeout configuration for provider APIs

**Significant (3 issues):**
- Single database instance SPOF without explicit HA design
- Missing SLO/SLA framework and error budget tracking
- Webhook delivery lacks retry and DLQ strategy

**Moderate (5 issues):**
- No rate limiting or backpressure mechanisms
- Insufficient payment-specific monitoring coverage
- Batch settlement process lacks fault tolerance
- No transaction timeout or auto-cancellation policy
- Redis lacks disaster recovery strategy

**Immediate Action Items:**
1. Define and implement circuit breaker patterns for all provider API calls
2. Design idempotency key mechanism for all mutating API operations
3. Document explicit timeout values for each provider API
4. Specify Cloud SQL HA configuration and failover strategy
5. Define formal SLOs with error budget tracking and alerting

**Operational Readiness:**
The design is **not yet production-ready** without addressing the critical issues. The missing circuit breaker, idempotency, and timeout configurations represent fundamental reliability gaps that would lead to cascading failures and data inconsistencies in production.

Addressing the critical and significant issues would bring the system to a baseline production-ready state. The moderate issues can be prioritized based on expected traffic scale and business risk tolerance.
