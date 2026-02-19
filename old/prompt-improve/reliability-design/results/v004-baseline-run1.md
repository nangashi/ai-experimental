# Reliability Design Review - Payment Gateway System

## Critical Issues

### C-1: No Circuit Breaker Design Despite Resilience4j Integration

**Finding:**
While Resilience4j is listed as a dependency for retry and timeout handling (Section 2.4, 7.4), there is no explicit circuit breaker design. The system will continue attempting to call failing provider APIs without implementing failure isolation or cascading failure prevention.

**Impact:**
Without circuit breakers, a sustained outage or degradation of a single payment provider (e.g., Stripe API returning 500 errors for 5 minutes) will cause:
- Thread pool exhaustion as requests pile up waiting for retries
- Resource starvation affecting other payment providers
- Complete system unavailability even for healthy providers
- Cascading failures to dependent systems

**Countermeasure:**
Implement circuit breaker patterns per provider:
```
Circuit Breaker Configuration (per provider):
- Failure threshold: 50% error rate over 10 requests
- Open state duration: 30 seconds
- Half-open state: Allow 3 probe requests
- Bulkhead isolation: Separate thread pools per provider (Stripe: 20 threads, PayPal: 20 threads, Bank: 10 threads)
```
Document fallback behavior when circuit is open (e.g., return 503 with retry-after header, queue for async processing).

**Reference:** Section 2.4 (Resilience4j), Section 7.4 (リトライ処理)

---

### C-2: Missing Idempotency Design for Payment Operations

**Finding:**
The API design (Section 5.1) does not specify idempotency keys or mechanisms for safely retrying payment requests. Network failures or timeout scenarios can result in duplicate payment authorizations.

**Impact:**
Scenario: Merchant submits payment request → API calls Stripe → Stripe authorizes payment → Network timeout before response reaches our system → Merchant retries → Second authorization occurs → Customer charged twice.

Recovery complexity:
- Requires manual refund processing
- Customer support escalation
- Potential regulatory violations (PCI DSS, consumer protection laws)
- Reputational damage

**Countermeasure:**
1. Add `idempotency_key` (UUID) to POST /v1/payments request schema
2. Store idempotency_key in Transactions table with unique constraint
3. Implement 24-hour idempotency window: Return existing transaction if duplicate key detected
4. Document idempotency behavior in API specification:
   ```
   Header: Idempotency-Key: <client-generated-uuid>
   - Required for POST /v1/payments, POST /v1/payments/{id}/capture, POST /v1/payments/{id}/refund
   - 24-hour deduplication window
   - Returns 200 with original response if duplicate detected
   ```

**Reference:** Section 5.1 (POST /v1/payments), Section 7.6 (データ整合性設計)

---

### C-3: No Webhook Delivery Retry Strategy

**Finding:**
Section 3.3 describes sending webhook notifications to merchants, but no retry mechanism or dead-letter handling is documented for failed webhook deliveries.

**Impact:**
When merchant webhook endpoints are temporarily unavailable (network issues, deployment, rate limiting):
- Merchants miss critical payment status updates (CAPTURED, SETTLED, FAILED)
- Merchants cannot update order status or trigger fulfillment
- Data inconsistency between payment gateway and merchant systems
- No mechanism for merchants to recover missed events

**Countermeasure:**
Implement webhook delivery reliability:
```
Retry Strategy:
- Initial delivery attempt: synchronous with 5-second timeout
- Retry schedule: 1min, 5min, 30min, 2hr, 6hr, 24hr (exponential backoff with max 7 retries)
- Dead Letter Queue: Pub/Sub topic for failed deliveries after exhausting retries
- Webhook dashboard: UI for merchants to view delivery status and manually replay events
- Webhook event log retention: 30 days with GET /v1/webhook-events API for merchant-initiated recovery
```

Document webhook reliability guarantees in API specification (at-least-once delivery semantics).

**Reference:** Section 3.3 (加盟店にWebhook通知を送信), Section 3.2 (Webhook Processor)

---

### C-4: Undefined Data Consistency Model for Distributed State

**Finding:**
The system stores transaction state in PostgreSQL while using Redis for caching (Section 2.2), but the design does not specify:
- Cache invalidation strategy when transactions are updated
- Consistency guarantees between PostgreSQL and Redis
- Handling of cache-database divergence scenarios

**Impact:**
Scenario: Transaction status updated from AUTHORIZED → CAPTURED in PostgreSQL → Redis cache still shows AUTHORIZED → GET /v1/payments/{id} returns stale status → Merchant initiates duplicate capture attempt.

Additional risks:
- Race conditions during concurrent status updates (refund + capture)
- Lost updates if cache write fails after database commit
- Inconsistent view across API instances reading from different cache nodes

**Countermeasure:**
1. Define explicit consistency model:
   ```
   Primary Source: PostgreSQL (source of truth)
   Cache Strategy: Cache-aside with write-through invalidation
   - On transaction status update: Write to PostgreSQL, then invalidate Redis key
   - On read: Check Redis → If miss, read PostgreSQL and populate cache (TTL: 60 seconds)
   - Critical paths (capture, refund): Always read from PostgreSQL, bypass cache
   ```

2. Implement optimistic locking:
   ```sql
   ALTER TABLE transactions ADD COLUMN version INTEGER DEFAULT 0;
   UPDATE transactions SET status = ?, version = version + 1
   WHERE id = ? AND version = ?;
   ```

3. Add cache monitoring:
   - Cache hit/miss rate metrics
   - Cache-database consistency validation (periodic audit job)

**Reference:** Section 2.2 (PostgreSQL, Redis), Section 7.6 (データ整合性設計)

---

### C-5: No Defined RPO/RTO or Disaster Recovery Plan

**Finding:**
While Section 7.3 specifies 99.9% availability target, there is no Recovery Point Objective (RPO) or Recovery Time Objective (RTO) definition, and no disaster recovery procedures are documented.

**Impact:**
In catastrophic failure scenarios (regional GKE outage, database corruption, accidental data deletion):
- No defined acceptable data loss window (RPO)
- No defined recovery time commitment (RTO)
- No documented backup/restore procedures
- No tested failover mechanism to alternate region
- Potential for hours or days of downtime

Business impact:
- Violation of merchant SLAs
- Revenue loss during outage
- Regulatory compliance violations if payment data is lost
- Inability to reconstruct financial records for settled transactions

**Countermeasure:**
1. Define RPO/RTO targets:
   ```
   RPO: < 5 minutes (maximum acceptable data loss)
   RTO: < 1 hour (maximum downtime)
   ```

2. Implement disaster recovery strategy:
   ```
   Database Backup:
   - Automated continuous backup (Cloud SQL point-in-time recovery)
   - Cross-region backup replication to alternate GCP region
   - Monthly restore testing with validation checklist

   Multi-Region Failover:
   - Active-passive deployment (primary: asia-northeast1, secondary: us-central1)
   - Cloud SQL read replica in secondary region (< 5 minute replication lag)
   - DNS-based failover with 60-second TTL
   - Runbook for manual failover trigger (documented step-by-step procedure)
   ```

3. Create disaster recovery runbook covering:
   - Regional outage detection and escalation
   - Failover decision criteria and approval process
   - Step-by-step failover procedure with rollback steps
   - Post-recovery validation checklist (data consistency, provider connectivity)

**Reference:** Section 7.3 (可用性目標), Section 2.3 (Kubernetes GKE)

---

## Significant Issues

### S-1: Missing Timeout Configuration Specifics

**Finding:**
Section 7.4 states "タイムアウトは、プロバイダーごとに異なる値を設定する予定だが、具体的な値は実装フェーズで決定する" (timeout values will be decided during implementation phase).

**Impact:**
Deferring timeout configuration to implementation phase risks:
- Default infinite timeouts causing thread starvation under provider latency
- Inconsistent timeout values across providers leading to unpredictable user experience
- Inability to calculate end-to-end SLOs without timeout budget

**Countermeasure:**
Define timeout values in design phase based on provider SLAs:
```
Timeout Configuration (99th percentile + buffer):
- Stripe API: 10 seconds (connect: 3s, read: 10s)
- PayPal API: 15 seconds (connect: 3s, read: 15s)
- Bank Transfer API: 30 seconds (connect: 5s, read: 30s)
- Webhook delivery: 5 seconds (per attempt)
- Database query: 5 seconds (with query optimization SLO)

Total request budget: Provider timeout + retry overhead + processing time < 45 seconds
Return 504 Gateway Timeout to merchant if budget exceeded
```

**Reference:** Section 7.4 (障害回復設計)

---

### S-2: Insufficient Rate Limiting Design

**Finding:**
Section 2.2 mentions Redis for "レート制限カウンタ" (rate limit counters), but no rate limiting strategy or thresholds are defined.

**Impact:**
Without defined rate limits:
- No protection against merchant abuse or runaway scripts
- Risk of exceeding provider API quotas (Stripe: 100 req/sec, PayPal: varies by tier)
- Noisy neighbor problem: One merchant monopolizing system resources
- Inability to enforce fair usage policies

**Countermeasure:**
Design multi-layer rate limiting:
```
Layer 1 - Per-Merchant Rate Limits:
- 100 requests/second per merchant API key
- 10,000 requests/hour per merchant
- Algorithm: Token bucket (burst allowance: 200 tokens)
- Response: 429 Too Many Requests with Retry-After header

Layer 2 - Provider Quota Management:
- Reserve 80% of provider quota for distribution across merchants
- 20% buffer for retry traffic and operational margin
- Circuit breaker trips if provider returns 429 (quota exhausted)

Layer 3 - System-Wide Backpressure:
- Global QPS limit: 800 requests/second (80% of 1000 TPS target)
- Load shedding: Reject requests with 503 when system saturation > 90%
- Priority queue: Capture/refund operations prioritized over new payments
```

Implement rate limit bypass mechanism for approved high-volume merchants (documented approval process).

**Reference:** Section 2.2 (Redis), Section 7.1 (1000 TPS target)

---

### S-3: Single Point of Failure in Batch Settlement Process

**Finding:**
Section 7.7 describes a nightly batch process to transition CAPTURED → SETTLED, but states "処理中に障害が発生した場合は、アラートを発報し、翌朝手動でリカバリを行う" (manual recovery next morning if failure occurs).

**Impact:**
Manual recovery introduces:
- Delayed settlement affecting merchant cash flow (SLA violations)
- Human error risk during manual intervention
- No automatic retry or self-healing capability
- Operational burden on on-call engineers
- Potential for multi-day backlogs if recovery is delayed

Recovery scenario: Batch fails at 2:30 AM → Alert fires → On-call engineer wakes up at 8:00 AM → Investigates root cause until 10:00 AM → Manually triggers re-run → 8-hour settlement delay.

**Countermeasure:**
Implement automated batch resilience:
```
Spring Batch Configuration:
- Chunk-based processing (chunk size: 1000 transactions)
- Skip policy: Log and skip individual failed items, continue processing
- Retry policy: 3 retries with exponential backoff for transient failures
- Automatic restart: If batch fails, auto-restart from last successful checkpoint (JobRepository tracking)
- Idempotent design: CAPTURED → SETTLED transition safe to retry

Failure Scenarios:
- Partial completion: JobRepository tracks processed transaction IDs, restart processes remaining
- Database deadlock: Retry chunk with randomized backoff
- Complete failure: Auto-retry 3 times with 10-minute interval, then escalate alert

Monitoring:
- Settlement completion SLO: 99% complete by 3:00 AM JST
- Alert escalation: PagerDuty escalation to manager if not resolved by 6:00 AM
- Dashboard: Real-time batch progress (X of Y transactions processed)
```

**Reference:** Section 7.7 (バッチ処理設計)

---

### S-4: Missing SLO/SLA Definitions for Critical User Journeys

**Finding:**
Section 7.1 defines generic performance targets (p95 < 500ms), but there are no Service Level Objectives (SLOs) or Service Level Agreements (SLAs) for specific user journeys or error budget policies.

**Impact:**
Without SLOs:
- No objective measure for "system health" or release go/no-go decisions
- Cannot prioritize reliability work vs. feature development
- No error budget to guide risk-taking (should we deploy on Friday?)
- Merchant expectations not clearly set (what uptime can they expect?)

**Countermeasure:**
Define SLIs/SLOs/SLAs per user journey:
```
SLI Definition (Service Level Indicators):
1. Payment Creation Success Rate = (successful 200 responses) / (total requests) [excluding 4xx client errors]
2. Payment Latency = p95 latency for POST /v1/payments
3. Webhook Delivery Success Rate = (successful deliveries within 1 hour) / (total webhooks)
4. System Availability = (uptime minutes) / (total minutes)

SLO Targets (Service Level Objectives - internal targets):
1. Payment Creation Success Rate > 99.9% (measured over 28-day window)
2. Payment Latency p95 < 500ms, p99 < 1000ms
3. Webhook Delivery Success Rate > 99.5% within 1 hour
4. System Availability > 99.95% (21 minutes downtime/month)

SLA Commitments (Service Level Agreements - contractual):
1. System Availability: 99.9% (43 minutes downtime/month)
2. Payment Success Rate: 99.5%
3. SLA credits: 10% monthly fee credit if below 99.9%, 25% if below 99.5%

Error Budget Policy:
- 28-day error budget = (1 - 0.999) * total requests
- If error budget exhausted: Freeze feature releases, focus on reliability
- If 50% error budget remaining: Normal release cadence
- If 90% error budget remaining: Aggressive feature velocity permitted
```

Implement automated SLO tracking dashboard with burn rate alerting (alert if consuming error budget 10x faster than sustainable rate).

**Reference:** Section 7.1 (パフォーマンス目標), Section 7.3 (99.9% availability)

---

### S-5: No Distributed Tracing for Cross-Service Debugging

**Finding:**
Section 6.2 mentions correlation_id in logs, but there is no distributed tracing design for debugging complex failures across Payment API → Provider Gateway → External Provider → Webhook processing flow.

**Impact:**
Debugging production issues requires:
- Manually correlating logs across multiple services using correlation_id
- No visibility into external provider latency breakdown
- Inability to identify bottlenecks in multi-hop async flows (webhook → Pub/Sub → processor)
- Mean Time To Resolution (MTTR) increases for complex failures

Example: Merchant reports "payment stuck in PENDING for 5 hours" → Need to trace: API request → Database insert → Provider API call (where did it stall?) → Webhook received? → Processing delay? Without tracing, requires grep across multiple log streams.

**Countermeasure:**
Implement distributed tracing:
```
Technology: OpenTelemetry + Cloud Trace (GCP native)

Instrumentation:
- Auto-instrumentation: Spring Boot WebFlux (HTTP requests/responses)
- Manual spans:
  * Provider API calls (span attributes: provider, amount, payment_method)
  * Database queries (span attributes: query type, table, row count)
  * Pub/Sub publish/consume (span attributes: topic, message_id)
  * Webhook delivery attempts (span attributes: merchant_id, attempt_number)

Trace Context Propagation:
- HTTP: W3C Trace Context headers (traceparent, tracestate)
- Pub/Sub: Trace context embedded in message attributes
- Database: Add trace_id to SQL comments for correlation

Sampling Strategy:
- 100% sampling for errors and latency > 2 seconds
- 10% sampling for successful requests < 500ms
- 100% sampling for transactions > 100,000 JPY (high-value monitoring)

Trace Retention: 30 days with query interface for support team
```

**Reference:** Section 6.2 (correlation_id), Section 3.3 (データフロー)

---

## Moderate Issues

### M-1: Missing Replication Lag Monitoring for Cloud SQL

**Finding:**
Section 7.3 mentions Cloud SQL (managed service) but does not address replication lag monitoring if read replicas are used, or point-in-time recovery lag for backup scenarios.

**Impact:**
- Stale data served from read replicas causing inconsistent transaction status views
- RPO violations if backup replication lag exceeds acceptable window
- No alerting when replication falls behind

**Countermeasure:**
Even for managed Cloud SQL, implement:
```
Monitoring:
- Cloud SQL replication lag metric (if using read replicas)
- Alert threshold: Replication lag > 10 seconds
- Backup validation: Verify point-in-time recovery lag < 5 minutes (RPO target)

Read Replica Strategy (if implemented):
- Write: Primary instance only
- Read: Route non-critical queries (reports, dashboards) to replicas
- Critical reads: Always use primary (transaction status for capture/refund decisions)
```

**Reference:** Section 2.2 (PostgreSQL), Section 7.3 (Cloud SQL)

---

### M-2: No Graceful Degradation Strategy for Provider Outages

**Finding:**
No design for system behavior when a payment provider has a complete outage (e.g., Stripe status page shows incident).

**Impact:**
All payment requests to the affected provider fail, but merchants have no alternative path or guidance.

**Countermeasure:**
Implement graceful degradation:
```
Option 1 - Provider Fallback (if feasible):
- Allow merchants to configure primary + secondary provider preferences
- Automatically retry with secondary provider if primary circuit breaker is open
- Document fallback behavior and limitations (fee differences, settlement timing)

Option 2 - Queued Processing (if fallback not feasible):
- When circuit breaker opens, enqueue payment requests to Pub/Sub dead-letter topic
- Return 503 with Retry-After: 300 (5 minutes) to merchant
- Automated replay when provider circuit closes
- Merchant notification: "Payment queued due to provider outage, will process when available"

Health Check Endpoint:
GET /v1/health/providers → Returns per-provider status (UP/DEGRADED/DOWN)
```

**Reference:** Section 3.2 (Provider Gateway), Critical Issue C-1 (Circuit Breaker)

---

### M-3: Insufficient Database Connection Pool Configuration Guidance

**Finding:**
Section 7.5 mentions monitoring "データベース接続数" but no connection pool sizing strategy is documented.

**Impact:**
- Under-provisioned pool → Connection exhaustion under load → 500 errors
- Over-provisioned pool → Idle connections consuming database resources

**Countermeasure:**
Define connection pool configuration:
```
HikariCP Configuration (per pod):
- Maximum pool size: 20 connections (calculated from: 1000 TPS target / 50ms avg query time / 10 pods = 10 connections + buffer)
- Minimum idle: 10 connections
- Connection timeout: 5 seconds
- Idle timeout: 10 minutes
- Max lifetime: 30 minutes (prevent stale connections)

Cloud SQL Limits:
- Max connections: 500 (verify instance tier supports target)
- Reserved connections: 50 (admin access, batch jobs)
- Monitoring: Alert if active connections > 400 (80% utilization)

Auto-scaling consideration:
If HPA scales to 30 pods → 30 * 20 = 600 connections → Exceeds limit
Solution: Reduce max pool size to 15, or upgrade Cloud SQL tier
```

**Reference:** Section 7.5 (データベース接続数), Section 7.3 (Horizontal Pod Autoscaler)

---

### M-4: No Webhook Signature Algorithm Versioning Strategy

**Finding:**
Section 5.2 mentions HMAC signature verification for webhooks but no versioning or algorithm rotation strategy.

**Impact:**
- Cannot rotate HMAC secrets without breaking existing merchant integrations
- Cannot upgrade to stronger algorithms (SHA256 → SHA512) without coordination
- Security vulnerabilities if algorithm is compromised

**Countermeasure:**
Implement signature versioning:
```
Webhook Signature Header:
X-Webhook-Signature: v1=<hmac-sha256-hex>,v2=<hmac-sha512-hex>

Verification Logic:
1. Parse all signatures from header
2. Verify using highest version supported by both sides
3. Accept if any valid signature matches

Migration Path:
- Phase 1: Add v2 signatures alongside v1 (dual signing)
- Phase 2: Document v2 in API docs, encourage merchant migration
- Phase 3: Deprecate v1 (6 months notice)
- Phase 4: Remove v1 signature generation

Secret Rotation:
- Per-merchant webhook secrets (stored in Merchants table)
- Rotation API: POST /v1/merchants/{id}/rotate-webhook-secret
- Grace period: Accept both old and new secret for 24 hours after rotation
```

**Reference:** Section 5.2 (HMAC署名検証)

---

### M-5: Missing Capacity Planning for Seasonal Traffic

**Finding:**
Section 7.1 specifies 1000 TPS throughput, but no capacity planning for seasonal peaks (e.g., Black Friday, year-end shopping).

**Impact:**
- Traffic spikes exceed provisioned capacity
- Auto-scaling lag causes temporary degraded performance
- Unpredictable cost overruns without budget approval

**Countermeasure:**
Document capacity planning process:
```
Traffic Forecasting:
- Baseline: 1000 TPS (average daily peak)
- Seasonal multiplier: 3x (Black Friday, December)
- Sustained peak capacity: 3000 TPS
- Burst capacity: 5000 TPS (5-minute window)

Auto-scaling Parameters:
- Target CPU utilization: 70% (allows headroom for burst)
- Min replicas: 5 (maintain baseline capacity)
- Max replicas: 30 (cost guardrail)
- Scale-up velocity: Add 5 pods/minute
- Scale-down velocity: Remove 1 pod/5 minutes (gradual)

Pre-event Preparation (Black Friday):
- Load test 1 week prior: Simulate 5000 TPS for 1 hour
- Pre-scale: Increase min replicas to 15 before event
- Provider quota verification: Confirm Stripe/PayPal quota sufficient
- Runbook: On-call escalation process if auto-scaling insufficient
```

**Reference:** Section 7.1 (1000 TPS), Section 7.3 (Horizontal Pod Autoscaler)

---

## Minor Improvements

### I-1: Add Health Check Endpoint Specification

While Kubernetes liveness/readiness probes are likely planned, document the health check design explicitly:
```
GET /health/live → 200 if process is running (liveness probe)
GET /health/ready → 200 if ready to serve traffic (database connected, critical dependencies available)

Readiness criteria:
- PostgreSQL connection pool has at least 1 available connection
- Redis reachable (ping succeeds)
- Not in graceful shutdown state
```

---

### I-2: Consider Structured Logging Schema Documentation

Section 6.2 mentions structured JSON logging. Document the log schema for consistency:
```
Standard Log Fields:
- timestamp (ISO8601)
- level (ERROR, WARN, INFO, DEBUG)
- correlation_id (UUID)
- service (payment-api, webhook-processor, batch-settlement)
- transaction_id (if applicable)
- merchant_id (if applicable)
- provider (stripe/paypal/bank)
- error_code (if error)
- latency_ms (for API requests)
```

---

### I-3: Positive Aspect - Good Separation of Concerns

The layered architecture (API Gateway → Application → Integration → Data) provides clear fault isolation boundaries. This design supports independent scaling and targeted reliability improvements per layer.

---

## Summary

This payment gateway design demonstrates awareness of reliability concerns (retry logic, monitoring, availability targets) but has critical gaps in fault tolerance mechanisms, distributed system consistency guarantees, and operational recovery procedures.

**Highest Priority Actions:**
1. **Implement circuit breakers** (C-1) to prevent cascading failures across payment providers
2. **Design idempotency mechanism** (C-2) to prevent duplicate charges
3. **Define webhook retry strategy** (C-3) for reliable merchant notifications
4. **Specify data consistency model** (C-4) for PostgreSQL-Redis interaction
5. **Document disaster recovery plan** (C-5) with RPO/RTO targets and tested procedures

**Reliability Readiness Assessment:**
This design is **not production-ready** in its current state. The critical issues identified pose significant risks of data loss, duplicate charges, and unrecoverable failures. Addressing these issues will require architectural additions (circuit breakers, idempotency layer) and operational processes (DR runbooks, error budget tracking) before launch.

The good news: The technical foundation (Spring Boot, Resilience4j, managed Cloud SQL) supports implementing these reliability patterns. The team should allocate 3-4 weeks to address critical and significant issues before proceeding to implementation.
