# Reliability Design Review: Payment Gateway System

## Executive Summary

This review evaluates the Payment Gateway System design document from a reliability and operational readiness perspective. The evaluation identified **3 critical issues**, **8 significant issues**, **6 moderate issues**, and several positive aspects. The most severe concerns involve data consistency under failure conditions, missing circuit breaker implementation, and insufficient disaster recovery planning.

---

## Critical Issues

### C-1: Idempotency Design Missing for Payment Operations

**Issue:**
The design lacks explicit idempotency mechanisms for payment operations. Payment APIs (POST /v1/payments, POST /v1/payments/{id}/capture, POST /v1/payments/{id}/refund) do not document idempotency key handling. This creates severe risk in retry scenarios.

**Impact:**
- Merchants retrying failed requests (due to network timeout or 5xx errors) may create duplicate charges
- Users could be charged multiple times for the same purchase
- Refund operations could be applied multiple times, leading to over-refunding
- Financial reconciliation becomes extremely complex

**Countermeasures:**
1. Add `idempotency_key` field to all payment mutation APIs (required header or request field)
2. Store idempotency keys in Redis with 24-hour TTL, mapped to transaction IDs
3. Before processing payment requests, check if idempotency key exists:
   - If exists and transaction is final state (CAPTURED/FAILED/REFUNDED): return cached response
   - If exists and transaction is pending: return current transaction status
   - If not exists: proceed with new transaction creation
4. Document idempotency behavior in API specification with explicit retry guidance for merchants
5. Implement idempotency key validation (minimum length, uniqueness per merchant)

**Reference:** Section 5.1 (API design), Section 6.1 (Error handling)

---

### C-2: No Circuit Breaker Implementation for Provider APIs

**Issue:**
While Resilience4j is mentioned for retry and timeout (Section 7.4), there is no explicit circuit breaker design to prevent cascading failures when external payment providers (Stripe, PayPal, bank APIs) experience outages or degraded performance.

**Impact:**
- During provider outages, continuous retry attempts will exhaust thread pools and database connections
- System-wide resource exhaustion could bring down the entire payment gateway
- Merchants experience degraded latency even for transactions using healthy providers
- Incident response becomes reactive rather than proactive (no automatic failure isolation)

**Countermeasures:**
1. Configure Resilience4j CircuitBreaker for each provider with:
   - Failure rate threshold: 50% over 10-second window
   - Slow call threshold: 80% exceeding 5-second duration
   - Half-open state: 5 permitted calls to test recovery
   - Open state duration: 60 seconds before attempting recovery
2. Implement fallback behavior when circuit is open:
   - Return HTTP 503 with provider-specific error code (e.g., "STRIPE_UNAVAILABLE")
   - Store transaction in PENDING state with retry scheduled via Pub/Sub delayed message
3. Expose circuit breaker state as Prometheus metrics:
   - `circuit_breaker_state{provider="stripe"}` (closed=0, open=1, half_open=2)
   - `circuit_breaker_failures_total{provider="stripe"}`
4. Create runbook procedures for circuit breaker open states, including manual circuit reset commands
5. Dashboard alert when circuit breaker remains open >5 minutes

**Reference:** Section 7.4 (Fault recovery), Section 3.2 (Provider Gateway component)

---

### C-3: Database Transaction Boundaries Undefined for Critical Operations

**Issue:**
The design mentions PostgreSQL ACID guarantees (Section 7.6) but does not specify transaction boundaries for complex operations like refunds, capture, and webhook processing. Without explicit transaction scopes, partial failures can leave data in inconsistent states.

**Impact:**
- Refund operation might update Refunds table but fail to update Transactions status, leading to accounting mismatches
- Webhook processing could update transaction status without recording audit trail, making incident investigation impossible
- Concurrent operations (e.g., refund while capture is processing) may lead to lost updates or dirty reads
- Compensation logic becomes unclear when mid-operation failures occur

**Countermeasures:**
1. Define explicit transaction boundaries for each operation:
   - **Payment creation**: Single transaction covering Transactions insert + audit log insert
   - **Capture operation**: Transaction covering Transactions update (AUTHORIZED → CAPTURED) + provider API call record + webhook queue publish
   - **Refund operation**: Transaction covering Refunds insert + Transactions status check + refund amount validation + audit log
   - **Webhook processing**: Transaction covering Transactions update + webhook event log insert + merchant notification queue publish
2. Use optimistic locking (`version` column) on Transactions table to detect concurrent modifications
3. For operations spanning external API calls, implement Saga pattern with compensation:
   - Store compensation commands in `transaction_saga` table
   - Background job polls for timed-out sagas and executes compensations
4. Document rollback behavior and data consistency guarantees in API specification
5. Implement integration tests with fault injection to verify transaction rollback correctness

**Reference:** Section 7.6 (Data consistency), Section 4.1 (Data model), Section 3.3 (Data flow)

---

## Significant Issues

### S-1: No Distributed Transaction Coordination for Provider API Failures

**Issue:**
The data flow (Section 3.3) describes calling Provider Gateway APIs and updating transaction status, but does not address scenarios where provider API succeeds but local database update fails, or vice versa.

**Impact:**
- Provider charges customer but local transaction remains in PENDING state → merchant never receives payment confirmation
- Local database marks transaction CAPTURED but provider API call failed → merchant ships goods without actual payment
- Manual reconciliation required, delaying payment confirmations and increasing operational costs

**Countermeasures:**
1. Implement idempotent reconciliation batch job:
   - Hourly scan for transactions in PENDING/AUTHORIZED state older than 15 minutes
   - Query provider APIs for actual transaction status
   - Update local database to match provider state
   - Alert operations team for discrepancies requiring manual investigation
2. Add `reconciliation_status` column to Transactions table:
   - `SYNCED`: Local and provider states match
   - `PENDING_RECONCILIATION`: Status update failed, awaiting background reconciliation
   - `MANUAL_REVIEW`: Discrepancy detected, requires human intervention
3. Implement provider webhook as authoritative source:
   - Treat webhook events as source of truth for final transaction status
   - Log all webhook events to immutable audit log for forensic analysis
4. Store provider API response payloads in `provider_responses` table for debugging
5. Create operations dashboard showing reconciliation lag and manual review queue

**Reference:** Section 3.3 (Data flow), Section 7.7 (Batch processing)

---

### S-2: Webhook Delivery to Merchants Lacks Retry and Failure Handling

**Issue:**
The design mentions sending webhook notifications to merchants (Section 1.2, Section 3.3) but does not specify retry strategy, timeout handling, or failure scenarios when merchant endpoints are unavailable.

**Impact:**
- Merchant systems miss critical payment notifications (CAPTURED, REFUNDED events)
- Merchants cannot update order status, leading to unfulfilled orders or customer complaints
- No visibility into webhook delivery failures for troubleshooting
- Potential data inconsistency between gateway and merchant systems

**Countermeasures:**
1. Implement webhook delivery system with exponential backoff retry:
   - Initial attempt: immediate
   - Retry schedule: 1m, 5m, 15m, 1h, 6h, 24h (7 attempts over 31 hours)
   - HTTP timeout: 10 seconds per attempt
   - Success criteria: HTTP 2xx response
2. Store webhook delivery attempts in `webhook_delivery_logs` table:
   - `webhook_id`, `merchant_id`, `transaction_id`, `event_type`, `attempt_count`, `last_attempt_at`, `next_retry_at`, `status`, `response_code`, `response_body`
3. Expose webhook delivery metrics:
   - `webhook_delivery_success_total{merchant_id, event_type}`
   - `webhook_delivery_failure_total{merchant_id, event_type, error_type}`
   - `webhook_delivery_latency_seconds{merchant_id}`
4. Create merchant dashboard showing webhook delivery health and failed events
5. Provide webhook replay API endpoint for merchants to request re-delivery of missed events
6. Alert operations team when merchant webhook failure rate exceeds 10% over 1-hour window

**Reference:** Section 3.3 (Data flow), Section 1.2 (Webhook notification)

---

### S-3: No Timeout Specification for External Provider API Calls

**Issue:**
Section 7.4 mentions "timeout is set per provider but specific values will be determined during implementation phase." This defers critical reliability decisions, risking production incidents where slow provider APIs exhaust connection pools.

**Impact:**
- Unbounded API calls can tie up threads indefinitely during provider incidents
- Thread pool exhaustion leads to cascading failures affecting all merchants
- P95 latency SLO (500ms) becomes impossible to meet without timeout guardrails
- Incident response becomes reactive (discovering appropriate timeouts under production load)

**Countermeasures:**
1. Define timeout values during design phase based on provider SLAs:
   - Stripe API: 5 seconds (connect timeout: 2s, read timeout: 5s)
   - PayPal API: 10 seconds (connect timeout: 3s, read timeout: 10s)
   - Bank Transfer APIs: 15 seconds (connect timeout: 5s, read timeout: 15s)
   - Rationale: Bank APIs typically slower due to regulatory checks
2. Configure separate timeouts for different operation types:
   - Payment authorization: shorter timeout (user waiting for response)
   - Capture/refund: longer timeout (asynchronous operation)
3. Implement timeout monitoring metrics:
   - `provider_api_timeout_total{provider, operation}`
   - Alert when timeout rate exceeds 1% over 5-minute window
4. Document timeout values in Provider Gateway interface and enforce via resilience4j configuration
5. Load test with timeout scenarios to validate thread pool sizing (e.g., 1000 TPS with 10% provider API timeouts)

**Reference:** Section 7.4 (Fault recovery), Section 7.1 (Performance goals)

---

### S-4: Batch Settlement Job Has Manual Recovery Process

**Issue:**
Section 7.7 states that batch job failures trigger alerts and require manual recovery the next morning. For a payment system, this creates unacceptable operational risk.

**Impact:**
- Delayed settlement affects merchant cash flow (SLA breach)
- Manual recovery during business hours increases pressure on operations team
- Failure root causes may be unclear without automated diagnostics
- Repeated failures indicate systemic issues not being addressed

**Countermeasures:**
1. Implement automatic batch job retry with checkpointing:
   - Spring Batch restart capability with database-backed JobRepository
   - Chunk size: 1000 transactions per chunk
   - Skip policy: Skip individual transaction processing failures, log to error table
   - Retry policy: Retry chunk failures up to 3 times with 5-minute delay
2. Create `batch_execution_errors` table to track failed transactions:
   - `job_execution_id`, `transaction_id`, `error_type`, `error_message`, `retry_count`, `created_at`
3. Implement batch health checks:
   - Pre-flight check: Verify database connectivity, provider API availability
   - Post-execution validation: Compare SETTLED transaction count against expected count from previous states
4. Add batch observability:
   - `batch_job_duration_seconds{job_name="settlement"}`
   - `batch_processed_transactions_total{job_name, status}` (success/failed/skipped)
   - `batch_last_success_timestamp_seconds{job_name}`
5. Create automated runbook playbook:
   - If batch fails 3 times: Page on-call engineer
   - Include diagnostic queries and common resolution steps in alert
6. Schedule backup settlement window (e.g., 6 AM JST) that auto-triggers if 2 AM run failed

**Reference:** Section 7.7 (Batch processing)

---

### S-5: No Health Check Design for Kubernetes Readiness/Liveness

**Issue:**
The design mentions Kubernetes deployment (Section 2.3) and rolling updates (Section 6.4) but does not specify health check endpoints or criteria. Without proper health checks, Kubernetes may route traffic to unhealthy pods or fail to detect application-level failures.

**Impact:**
- During rolling deployment, new pods receive traffic before database connection pool is initialized → 5xx errors
- Application deadlock or thread exhaustion not detected by Kubernetes → pod continues receiving traffic
- Pod eviction/restart decisions based solely on process liveness, missing application-level failures
- Increased P95 latency during deployments due to premature traffic routing

**Countermeasures:**
1. Implement `/health/liveness` endpoint (GET):
   - Purpose: Detect if application process is deadlocked or unrecoverable
   - Checks: Thread pool not exhausted, no circular locking detected
   - Failure action: Kubernetes restarts pod
   - Timeout: 5 seconds
2. Implement `/health/readiness` endpoint (GET):
   - Purpose: Detect if application can serve traffic
   - Checks:
     - Database connection pool has available connections (min 2)
     - Redis connection healthy (PING command succeeds)
     - Critical downstream dependencies available (cached circuit breaker state)
   - Failure action: Kubernetes removes pod from service load balancer
   - Timeout: 3 seconds
3. Configure Kubernetes probes in deployment manifest:
   - Liveness probe: initialDelaySeconds=30, periodSeconds=10, failureThreshold=3
   - Readiness probe: initialDelaySeconds=15, periodSeconds=5, failureThreshold=2
4. Add startup probe for slow initialization:
   - Path: `/health/startup`
   - Checks: Database schema migration completed, cache warmed up
   - Configuration: initialDelaySeconds=0, periodSeconds=5, failureThreshold=30 (150 seconds max startup time)
5. Expose health check metrics:
   - `health_check_duration_seconds{endpoint, status}`
   - `health_check_failures_total{endpoint, reason}`

**Reference:** Section 2.3 (Infrastructure), Section 6.4 (Deployment), Section 3.1 (Architecture)

---

### S-6: No Disaster Recovery Plan or Backup Strategy Details

**Issue:**
Section 7.6 mentions PostgreSQL ACID guarantees but does not document backup strategy, RPO/RTO targets, or disaster recovery procedures. For a payment system, data loss is unacceptable.

**Impact:**
- Database corruption or accidental deletion without tested recovery path → permanent financial data loss
- No documented RTO leads to extended downtime during disaster recovery
- Compliance violations (PCI DSS requires backup and restore procedures)
- Untested recovery procedures may fail during actual disaster

**Countermeasures:**
1. Define and document RPO/RTO targets:
   - **RPO (Recovery Point Objective)**: 5 minutes (maximum acceptable data loss)
   - **RTO (Recovery Time Objective)**: 1 hour (maximum acceptable downtime)
2. Implement multi-tier backup strategy:
   - **Continuous backup**: Cloud SQL automated backups with point-in-time recovery (PITR) enabled
   - **Daily full backup**: Retained for 30 days, stored in separate GCS region
   - **Weekly backup**: Retained for 1 year, stored in cold storage for compliance
3. Document and test disaster recovery runbook:
   - Database restoration procedure with step-by-step commands
   - Validation queries to verify data integrity post-restore
   - Communication plan for notifying merchants during outage
   - Quarterly disaster recovery drill with documented test results
4. Implement transaction audit log with immutable append-only design:
   - Store all state transitions in separate `transaction_audit_log` table
   - Replicate audit log to separate Cloud SQL instance in different region
   - Audit log used to reconstruct transaction state if primary database corrupted
5. Add backup monitoring:
   - `backup_last_success_timestamp_seconds{backup_type}`
   - `backup_size_bytes{backup_type}`
   - Alert if backup fails or size deviates >20% from recent average
6. Document backup retention policy and legal compliance requirements

**Reference:** Section 7.6 (Data integrity), Section 2.2 (Database)

---

### S-7: No Capacity Planning or Load Shedding Strategy

**Issue:**
The design specifies 1000 TPS throughput target and HPA for autoscaling (Section 7.3) but does not document capacity limits, load shedding strategies, or graceful degradation under overload.

**Impact:**
- Traffic spikes (e.g., flash sales, Black Friday) may exceed system capacity → complete outage rather than graceful degradation
- Database connection pool exhaustion leads to cascading failures
- No prioritization mechanism → high-value merchants and low-value merchants compete equally for resources
- Incident response becomes reactive (discovering capacity limits under production load)

**Countermeasures:**
1. Implement rate limiting with tiered limits:
   - Per-merchant rate limit stored in Redis (e.g., 100 requests/minute per merchant)
   - Global system rate limit to protect backend resources (e.g., 10,000 requests/minute total)
   - Return HTTP 429 with `Retry-After` header when limit exceeded
2. Add merchant tier prioritization:
   - Tag merchants with tier (platinum/gold/silver/bronze) in Merchants table
   - Higher tiers get higher rate limits and priority queue processing
   - During overload, reject bronze tier requests first (503 with graceful error message)
3. Implement graceful degradation:
   - Disable non-critical features under load (e.g., detailed analytics in API responses)
   - Batch webhook notifications during peak load instead of immediate delivery
   - Read-only mode: Accept transaction queries but reject new payment creation
4. Define capacity limits in design document:
   - Database connection pool: 200 connections per pod, max 10 pods = 2000 total connections
   - Cloud SQL instance: 4 vCPU, 16 GB RAM → estimated max 5000 TPS sustainable
   - Pub/Sub: No practical limit, but message processing lag monitored
5. Conduct load testing before production:
   - Test sustained 2x target load (2000 TPS) for 1 hour
   - Test spike scenarios (10x load for 5 minutes)
   - Verify graceful degradation behavior and alert accuracy
6. Expose capacity metrics:
   - `rate_limit_exceeded_total{merchant_id}`
   - `connection_pool_usage_percent{pool_name}`
   - `load_shedding_active{reason}`

**Reference:** Section 7.3 (Scalability), Section 7.1 (Performance)

---

### S-8: No Alerting Strategy or SLO-Based Thresholds

**Issue:**
Section 7.5 lists monitoring metrics (request count, response time, error rate, DB connections) but does not define alerting rules, escalation policies, or SLO-based alert thresholds.

**Impact:**
- Operations team overwhelmed by noisy alerts (alert fatigue)
- Critical incidents not escalated appropriately → delayed response
- No objective criteria for when to page on-call engineer vs. create ticket
- Alerts not aligned with user-facing impact (monitor system metrics instead of SLOs)

**Countermeasures:**
1. Define SLIs (Service Level Indicators) and SLOs (Service Level Objectives):
   - **Availability SLO**: 99.9% of payment requests return non-5xx response
   - **Latency SLO**: 95% of payment requests complete within 500ms
   - **Success Rate SLO**: 99% of payment requests succeed (excluding merchant errors)
2. Implement error budget-based alerting:
   - Calculate 30-day error budget consumption rate
   - Alert severity tiers:
     - **P1 (Page immediately)**: Error budget consumption rate >5x normal (e.g., outage consuming 1 month budget in 6 days)
     - **P2 (Page during business hours)**: Error budget consumption rate >2x normal
     - **P3 (Ticket)**: Error budget consumption rate >1.5x normal
3. Define alert rules with actionable symptoms:
   - **Critical alert**: "Payment API error rate >5% for 5 minutes" → Investigate provider circuit breaker state, check database connectivity
   - **Warning alert**: "Payment API p95 latency >1s for 10 minutes" → Check provider API latency, review slow query log
   - **Info alert**: "Webhook delivery failure rate >10% for 1 hour" → Review merchant webhook endpoint health
4. Document escalation policy:
   - P1 alerts: Page on-call engineer immediately via PagerDuty
   - P2 alerts: Slack notification to team channel, escalate to on-call if not acknowledged in 15 minutes
   - P3 alerts: Create Jira ticket for investigation during business hours
5. Implement alert suppression during maintenance windows
6. Create dashboard showing real-time SLO compliance and error budget remaining

**Reference:** Section 7.5 (Monitoring & alerting), Section 7.3 (Availability)

---

## Moderate Issues

### M-1: Missing Feature Flag Design for Gradual Rollout

**Issue:**
The design describes rolling update deployment (Section 6.4) but does not mention feature flags for progressive rollout or emergency kill switches.

**Impact:**
- Cannot decouple deployment from feature activation
- Cannot perform canary testing with subset of merchants
- No emergency mechanism to disable problematic features without full rollback
- Increased risk for high-impact changes (e.g., new provider integration)

**Countermeasures:**
1. Integrate feature flag library (e.g., Unleash, LaunchDarkly, or simple database-backed implementation)
2. Define feature flag strategy:
   - **Provider rollout**: Enable new provider (e.g., PayPal integration) for 5% of merchants, gradually increase to 100%
   - **New API version**: Roll out v2 endpoints to subset of merchants
   - **Circuit breaker override**: Manual flag to force circuit breaker open for maintenance
3. Store feature flags in Redis with real-time updates (no deployment required)
4. Expose feature flag metrics: `feature_flag_enabled{flag_name, merchant_id}`
5. Document feature flag lifecycle in runbook (creation, rollout, cleanup)

**Reference:** Section 6.4 (Deployment)

---

### M-2: No Distributed Tracing Design

**Issue:**
Section 6.2 mentions correlation_id for logging but does not specify distributed tracing across service boundaries (Payment API → Provider Gateway → External Provider APIs).

**Impact:**
- Difficult to diagnose latency issues spanning multiple services
- Cannot identify bottlenecks in end-to-end transaction flow
- Debugging production incidents requires manual log correlation across multiple systems
- Cannot measure provider API contribution to overall latency

**Countermeasures:**
1. Implement OpenTelemetry distributed tracing:
   - Generate trace_id for each incoming request
   - Propagate trace_id via HTTP headers (W3C Trace Context standard) to provider APIs
   - Record spans for each operation (request handling, DB query, provider API call)
2. Export traces to observability platform (e.g., Google Cloud Trace, Jaeger)
3. Tag spans with transaction_id, merchant_id, provider for filtering
4. Instrument critical paths:
   - Payment creation flow (API → Transaction Manager → Provider Gateway → Database)
   - Webhook processing flow (Provider → Webhook Processor → Database → Merchant notification)
5. Create trace-based latency analysis dashboard

**Reference:** Section 6.2 (Logging), Section 3.3 (Data flow)

---

### M-3: Insufficient Transaction Status Definition

**Issue:**
Section 4.1 defines transaction statuses (PENDING, AUTHORIZED, CAPTURED, SETTLED, FAILED, REFUNDED) but does not document valid state transitions or terminal states. This can lead to invalid state changes.

**Impact:**
- Application code may transition from FAILED to CAPTURED (invalid)
- Difficult to reason about transaction lifecycle in incident investigation
- Database may contain transactions in inconsistent states
- Refund logic may incorrectly handle partially captured transactions

**Countermeasures:**
1. Document finite state machine for transaction statuses:
   - **Initial state**: PENDING
   - **Valid transitions**:
     - PENDING → AUTHORIZED (authorization success)
     - PENDING → FAILED (authorization failure)
     - AUTHORIZED → CAPTURED (capture success)
     - AUTHORIZED → FAILED (capture failure or timeout)
     - CAPTURED → SETTLED (batch settlement completion)
     - SETTLED → REFUNDED (refund completion)
   - **Terminal states**: FAILED, SETTLED, REFUNDED
2. Implement state transition validation in Transaction Manager:
   - Reject invalid state transitions with IllegalStateException
   - Log all state transition attempts for audit
3. Add database constraint to enforce valid statuses (CHECK constraint or ENUM type)
4. Add `previous_status` column to track transitions for debugging
5. Create integration tests for all valid and invalid state transitions

**Reference:** Section 4.1 (Data model), Section 3.3 (Data flow)

---

### M-4: No Runbook Documentation Mentioned

**Issue:**
The design does not mention incident response procedures, runbooks, or on-call playbooks for common failure scenarios.

**Impact:**
- Inconsistent incident response across different on-call engineers
- Longer mean time to resolution (MTTR) as engineers discover resolution steps during incidents
- Repeated mistakes during high-pressure incident response
- New team members lack guidance for production troubleshooting

**Countermeasures:**
1. Create runbook documentation covering common scenarios:
   - **Provider API timeout spike**: Check circuit breaker state, review provider status page, consider manual circuit open
   - **Database connection pool exhaustion**: Review slow query log, check for connection leaks, emergency scale-up procedure
   - **Batch settlement job failure**: Review error logs, identify failed transaction subset, manual recovery SQL queries
   - **Webhook delivery failure spike**: Check merchant endpoint health, review rate limit status, replay webhook events
2. Include runbook links in alert notifications (PagerDuty, Slack)
3. Document escalation contacts (provider support, database SRE team)
4. Maintain incident postmortem log with action items and runbook updates
5. Conduct quarterly incident response drills to validate runbook accuracy

**Reference:** Section 7.5 (Monitoring), Section 6.4 (Deployment)

---

### M-5: Database Index Strategy Not Documented

**Issue:**
The data model (Section 4.1) defines tables but does not specify indexes. Missing indexes on high-traffic queries can cause performance degradation and database lock contention.

**Impact:**
- Slow transaction queries by merchant_id → increased API latency
- Table scans on status column during batch settlement → database CPU spike
- Webhook processing queries without index → delayed notification delivery
- Potential deadlocks due to full table scans holding row locks

**Countermeasures:**
1. Define indexes for Transactions table:
   - `idx_transactions_merchant_id` (for merchant queries)
   - `idx_transactions_status` (for batch processing)
   - `idx_transactions_provider_transaction_id` (for provider webhook lookups)
   - `idx_transactions_created_at` (for time-range queries and reconciliation)
   - Composite index: `idx_transactions_merchant_status_created` (merchant_id, status, created_at) for merchant dashboard queries
2. Define indexes for Refunds table:
   - `idx_refunds_transaction_id` (foreign key lookup)
   - `idx_refunds_status` (for failed refund monitoring)
3. Monitor index usage:
   - Periodically review pg_stat_user_indexes for unused indexes
   - Review slow query log for missing index recommendations
4. Test index performance with realistic data volume (10M+ transactions)
5. Document index maintenance strategy (REINDEX schedule for B-tree bloat)

**Reference:** Section 4.1 (Data model), Section 7.1 (Performance)

---

### M-6: No Pub/Sub Message Ordering or Duplicate Handling

**Issue:**
The design uses Google Cloud Pub/Sub for message queue (Section 2.3) but does not address message ordering or duplicate delivery scenarios. Pub/Sub guarantees at-least-once delivery, which can cause duplicate webhook processing.

**Impact:**
- Webhooks processed out of order (e.g., REFUNDED event processed before CAPTURED) → incorrect final transaction state
- Duplicate webhook events processed → duplicate merchant notifications
- Race conditions in concurrent webhook processing → lost updates

**Countermeasures:**
1. Implement idempotent webhook processing:
   - Store provider webhook event IDs in `webhook_events` table with unique constraint
   - Before processing webhook, check if event_id already processed
   - If duplicate: Log and acknowledge without processing
2. Use Pub/Sub message ordering if supported:
   - Configure ordering key as `transaction_id` to ensure sequential processing per transaction
   - Note: This may reduce parallelism, monitor processing lag
3. Add optimistic locking to transaction status updates:
   - Use `version` column in Transactions table
   - Increment version on each update
   - Retry failed updates with fresh version read
4. Document webhook event ordering guarantees in API specification
5. Create integration test with out-of-order webhook delivery simulation

**Reference:** Section 2.3 (Infrastructure), Section 3.3 (Data flow)

---

## Positive Aspects

### P-1: Resilience4j Integration for Fault Tolerance
The design explicitly includes Resilience4j (Section 7.4) for retry and timeout handling on external provider APIs, demonstrating awareness of fault recovery requirements.

### P-2: Structured Logging with Correlation ID
Section 6.2 specifies structured logging (JSON format) with correlation_id for request tracing, which is essential for distributed system debugging.

### P-3: Sensitive Data Masking in Logs
Section 6.2 explicitly mentions masking sensitive information (card numbers, API keys) in logs, showing security and operational awareness.

### P-4: PCI DSS Compliance Awareness
Section 7.2 mentions PCI DSS compliance with tokenization approach (not storing card data), which reduces security and operational risk.

### P-5: Integration Testing with Testcontainers
Section 6.3 mentions Testcontainers for integration testing, which helps validate fault tolerance and data consistency behavior before production.

---

## Summary and Recommendations

### Critical Path to Production Readiness

To achieve production readiness for a payment gateway system, address issues in this priority order:

**Phase 1 (Pre-Launch Blockers):**
1. **C-1**: Implement idempotency mechanism for all payment APIs
2. **C-2**: Configure circuit breakers for all external provider integrations
3. **C-3**: Define and document transaction boundaries with rollback behavior
4. **S-5**: Implement Kubernetes health checks (readiness/liveness probes)
5. **S-6**: Document and test disaster recovery procedures with RPO/RTO targets

**Phase 2 (Launch Week 1):**
6. **S-1**: Implement transaction reconciliation batch job
7. **S-2**: Build webhook delivery retry system with failure tracking
8. **S-3**: Define and enforce timeout values for all provider APIs
9. **S-8**: Define SLOs and implement error budget-based alerting

**Phase 3 (Month 1):**
10. **S-4**: Automate batch job recovery with checkpointing
11. **S-7**: Implement rate limiting and capacity planning
12. **M-1**: Add feature flags for progressive rollout capability
13. **M-4**: Create runbook documentation for common incidents

### Operational Readiness Checklist

Before production launch, verify:
- [ ] All critical and significant issues addressed
- [ ] Disaster recovery procedures tested with actual data restore
- [ ] Load testing completed at 2x target capacity
- [ ] Circuit breaker behavior validated under provider outage simulation
- [ ] On-call rotation established with runbook training
- [ ] Alerting rules validated (no false positives in pre-production)
- [ ] Provider sandbox testing completed for all failure scenarios
- [ ] Idempotency behavior documented and tested with merchant SDK

### Architecture-Level Recommendations

1. **Adopt Saga Pattern**: For operations spanning multiple state changes and external APIs, implement the Saga pattern with compensation logic to handle partial failures gracefully.

2. **Implement Event Sourcing for Audit Trail**: Store all transaction state transitions as immutable events in an append-only audit log. This provides:
   - Complete forensic history for financial disputes
   - Ability to reconstruct state after database corruption
   - Foundation for CQRS if read scalability becomes bottleneck

3. **Consider Multi-Region Deployment**: For 99.9% availability target, single-region deployment may be insufficient. Plan for active-active or active-standby multi-region architecture with data replication.

4. **Provider Abstraction with Adapter Pattern**: Ensure Provider Gateway uses consistent interface across all payment providers, making it easy to add new providers or switch providers without changing core business logic.

---

## Evaluation Methodology Note

This evaluation was conducted following the reliability-design-reviewer agent guidelines (v004-baseline), prioritizing critical issues that could lead to data loss or system-wide failures, followed by significant operational risks. The assessment focused on architecture-level design decisions rather than implementation details, and evaluated fault tolerance, data consistency, availability, monitoring, and deployment safety as specified in the evaluation criteria.
