# Reliability Design Review - MediConnect Appointment Scheduling System
**Review Date:** 2026-02-11
**Reviewer:** reliability-design-reviewer
**Variant:** v003-variant-min-detection (Run 2)

## Executive Summary

This review identifies **14 distinct reliability issues** across fault recovery, data consistency, availability, monitoring, and deployment safety. The design shows critical gaps in circuit breaker implementation, retry logic, distributed transaction handling, and operational readiness measures. While the system includes basic redundancy (2 AZs, RDS backups), it lacks explicit fault isolation, graceful degradation, and comprehensive monitoring strategies required for production healthcare systems.

---

## Critical Issues (System-Wide Failure Risk)

### C1. No Circuit Breaker Pattern for External Service Failures
**Affected Components:** Notification Service (Twilio/SendGrid), EHR Integration Service (HL7 FHIR APIs)
**Reference:** Section 3 (Key Components), Section 2 (Technology Stack)

**Issue:**
The design states "Notification Service...Retries on failures" and "EHR Integration Service...operates on a nightly batch schedule" but provides no circuit breaker mechanism. When Twilio/SendGrid experience prolonged outages, continuous retry attempts will exhaust thread pools, cause cascading failures to healthy components, and potentially exhaust RabbitMQ message queue capacity (10,000 message alert threshold per Section 7).

**Impact:**
- **Cascading Failure:** Single external service outage degrades entire notification subsystem
- **Resource Exhaustion:** Unbounded retry loops consume database connections, memory, CPU
- **Queue Overflow:** RabbitMQ queue depth exceeds 10K threshold, blocking new appointment creation

**Countermeasures:**
1. Implement circuit breaker pattern with three states (CLOSED → OPEN → HALF_OPEN):
   - OPEN state after 5 consecutive failures or 50% error rate over 10s window
   - 60-second timeout before HALF_OPEN probe
   - 3 successful probes required to return to CLOSED state
2. Define fallback behavior:
   - Notification failures: Persist to dead-letter queue with admin dashboard for manual retry
   - EHR sync failures: Skip failed records, log for manual reconciliation, continue batch processing
3. Expose circuit breaker state as CloudWatch custom metrics with alerts

### C2. Missing Idempotency Design for Critical Write Operations
**Affected Components:** Appointment Service, Notification Service
**Reference:** Section 5 (POST /api/v1/appointments), Section 3 (Notification Service)

**Issue:**
The POST /appointments endpoint lacks idempotency token support. Network timeouts or client retries will create duplicate appointments. Similarly, notification retry logic (Section 3: "Retries on failures") does not specify duplicate detection, risking multiple SMS/email sends for a single appointment.

**Impact:**
- **Data Corruption:** Duplicate appointments violate provider capacity constraints (max_daily_appointments)
- **Financial Loss:** Duplicate SMS charges from Twilio (healthcare systems average $0.0075 per SMS)
- **Patient Confusion:** Multiple reminder notifications erode trust in system reliability

**Countermeasures:**
1. **Appointment Creation Idempotency:**
   - Add `idempotency_key` (UUID) to request header or body
   - Create database table: `idempotent_requests (key UUID PK, response_json JSONB, created_at TIMESTAMP)`
   - Check key existence before processing; return cached response if found
   - Set 24-hour TTL on idempotency records (matches JWT expiration)
2. **Notification Idempotency:**
   - Add `message_id` (UUID) column to notification tracking table
   - Before sending SMS/email, check if message_id already has successful delivery status
   - Use RabbitMQ message deduplication plugin or application-level dedup with Redis SET

### C3. No Distributed Transaction Handling for Appointment + Waitlist Workflow
**Affected Components:** Appointment Service, Waitlist Rebooking Logic
**Reference:** Section 5 (DELETE /api/v1/appointments - "Triggers waitlist rebooking logic")

**Issue:**
Appointment cancellation triggers waitlist rebooking, but the design specifies no transaction boundary or compensating action. If waitlist rebooking succeeds but the original cancellation fails (database write conflict, constraint violation), the system enters inconsistent state with orphaned waitlist appointments.

**Impact:**
- **Double-Booking:** Waitlist patient receives appointment slot still held by original patient
- **Data Inconsistency:** Appointment status = CANCELLED but waitlist_entry.status = REBOOKED creates audit trail gaps
- **Capacity Violations:** Provider max_daily_appointments limit bypassed when both appointments count toward quota

**Countermeasures:**
1. Implement Saga pattern with compensating transactions:
   - Phase 1: Mark original appointment as CANCELLING (soft delete)
   - Phase 2: Attempt waitlist rebooking with timeout (5 seconds)
   - Phase 3a (success): Finalize cancellation to CANCELLED
   - Phase 3b (failure): Rollback to SCHEDULED, log error for manual intervention
2. Use PostgreSQL advisory locks to prevent race conditions:
   ```sql
   SELECT pg_advisory_xact_lock(hashtext(provider_id || appointment_time))
   ```
3. Add `cancellation_saga_state` enum column to Appointment table for observability

### C4. Single Redis Instance Creates Session Data SPOF
**Affected Components:** Redis (Session Management)
**Reference:** Section 7 (Availability - "Redis runs in single-instance mode for session storage")

**Issue:**
Redis single-instance mode means all authenticated users lose sessions during Redis failures (instance restart, memory exhaustion, network partition). The design states "99.9% uptime target" but Redis single-instance availability is typically 95-98% on AWS ElastiCache.

**Impact:**
- **Cascading Authentication Failures:** All active users (patients, providers, admins) logged out simultaneously
- **Appointment Booking Disruption:** Mid-booking workflows lose state, requiring restart
- **SLA Violation:** 99.9% target (43 minutes/month downtime) unachievable with 95% Redis availability (36 hours/month)

**Countermeasures:**
1. **Immediate:** Upgrade to Redis Cluster mode with:
   - 3-node cluster across 2 AZs (minimum)
   - Automatic failover with 30-second detection timeout
   - Read replicas for session validation queries
2. **Alternative:** Implement session fallback hierarchy:
   - Primary: Redis (fast path)
   - Fallback: PostgreSQL session table (slower but durable)
   - Grace period: Accept expired-but-valid JWTs for 5 minutes during Redis outage
3. Monitor Redis memory usage with 80% threshold alert (prevent eviction-based session loss)

---

## Significant Issues (Partial Failure Impact)

### S1. Database Connection Pool Exhaustion Under Load
**Affected Components:** All ECS Tasks
**Reference:** Section 7 (Scalability - "HikariCP with max 20 connections per instance")

**Issue:**
20 connections per ECS task × 3 tasks = 60 total connections. However, long-running operations (EHR nightly batch, waitlist scans, reminder polling every 5 minutes) will hold connections for extended periods. Peak load (e.g., 8 AM appointment rush) may exhaust pool, causing timeout exceptions.

**Impact:**
- **Request Failures:** HTTP 500 errors when connection acquisition exceeds timeout (default 30s)
- **Latency Degradation:** p95 latency exceeds 500ms target due to connection wait time
- **Partial Outage:** Only write-heavy endpoints (POST /appointments) affected; reads may succeed

**Countermeasures:**
1. Implement connection pool monitoring:
   - Expose HikariCP metrics: `hikaricp_connections_active`, `hikaricp_connections_pending`
   - Alert when active > 15 (75% utilization) or pending > 5
2. Separate connection pools by workload:
   - Pool 1 (size 15): API request handling
   - Pool 2 (size 5): Background jobs (reminder polling, EHR batch)
3. Set aggressive connection timeout: `connection-timeout=10000` (10s) to fail fast
4. Add database-level connection limit monitoring (PostgreSQL `max_connections`)

### S2. RabbitMQ Single Point of Failure for Notifications
**Affected Components:** RabbitMQ, Notification Service
**Reference:** Section 2 (Message Queue: RabbitMQ 3.12), Section 3 (Notification Service consumes from RabbitMQ)

**Issue:**
No mention of RabbitMQ clustering or high availability configuration. Single RabbitMQ instance failure stops all notification delivery. The 5-minute reminder polling interval means up to 5 minutes of reminders accumulate in the database unprocessed during outage.

**Impact:**
- **Reminder Delivery SLA Breach:** "All reminders within 30 minutes" target fails if outage lasts 10+ minutes
- **Queue Message Loss:** Non-durable queues lose in-flight messages during restart
- **Delayed Waitlist Notifications:** Cancellation-triggered waitlist rebooking notifications delayed

**Countermeasures:**
1. Deploy RabbitMQ cluster with:
   - 3-node quorum queues (durable, replicated across AZs)
   - Automatic leader election on node failure
   - Lazy queues for reminder messages (reduce memory pressure)
2. Implement publisher confirms:
   - Reminder Service waits for RabbitMQ acknowledgment before marking database record as "enqueued"
   - Retry enqueue on NACK (network failure, queue unavailable)
3. Add fallback notification path:
   - If RabbitMQ unavailable for >5 minutes, Reminder Service directly calls Twilio/SendGrid (with circuit breaker)

### S3. No Rollback Plan for Database Migrations
**Affected Components:** Deployment Process
**Reference:** Section 6 (Deployment - "Database migrations executed manually before deployment using Flyway")

**Issue:**
"Blue-green deployment" allows rollback of application code, but manual Flyway migrations lack rollback scripts. Schema changes (adding NOT NULL columns, changing data types) cannot be reverted, forcing forward-only recovery during deployment failures.

**Impact:**
- **Extended Downtime:** Failed deployment requires emergency hotfix instead of instant rollback
- **Data Inconsistency:** New schema incompatible with rolled-back application code causes runtime errors
- **Deployment Risk:** Teams hesitate to deploy during business hours, slowing incident response

**Countermeasures:**
1. **Backward-Compatible Migration Strategy:**
   - Phase 1: Add new column as nullable, deploy application reading from both old/new columns
   - Phase 2 (after soak time): Backfill data, add NOT NULL constraint
   - Phase 3: Remove old column reference from code
2. **Automated Rollback Scripts:**
   - Every Flyway migration (V###__description.sql) requires corresponding undo script (U###__description.sql)
   - CI/CD validates rollback script exists before allowing merge
3. **Migration Testing:**
   - Staging environment tests both upgrade and downgrade paths
   - Rollback rehearsal in pre-production before prod deployment

### S4. Missing Timeout Configuration for External API Calls
**Affected Components:** EHR Integration Service, Notification Service
**Reference:** Section 2 (External Services: Twilio, SendGrid, EHR vendor APIs)

**Issue:**
No timeout specifications for Twilio, SendGrid, or HL7 FHIR API calls. Slow EHR vendor responses (30+ seconds during their maintenance windows) will block nightly batch threads indefinitely, preventing completion before business hours.

**Impact:**
- **Thread Starvation:** Blocked threads prevent new appointment bookings (share thread pool with API layer)
- **Batch Incompletion:** EHR sync fails to complete overnight, causing data staleness in partner systems
- **Cascading Delays:** Next night's batch inherits backlog, creating multi-day synchronization lag

**Countermeasures:**
1. Set service-specific timeouts based on SLA:
   - Twilio/SendGrid SMS: 5s connection, 10s read (they advertise p99 < 3s)
   - HL7 FHIR APIs: 10s connection, 30s read (healthcare APIs typically slower)
2. Implement timeout-aware retry logic:
   - Retry on timeout exception (network issue), not on slow response (server overload)
   - Use exponential backoff: 1s, 2s, 4s with max 3 retries
3. Monitor external API latency with percentile metrics (p50, p95, p99)

---

## Moderate Issues (Operational Improvement Opportunities)

### M1. Insufficient Health Check Coverage
**Affected Components:** ECS Tasks, Load Balancer
**Reference:** Section 2 (Infrastructure - AWS ALB), Section 7 (Monitoring)

**Issue:**
Design mentions ALB but does not specify health check endpoint implementation. Shallow health checks (HTTP 200 on `/health`) miss critical dependency failures (PostgreSQL read-only mode, RabbitMQ queue full, Redis eviction).

**Impact:**
- **False Healthy State:** ALB routes traffic to tasks unable to process requests (degraded performance, not total failure)
- **Slow Failure Detection:** Dependency issues discovered through user-facing errors instead of proactive health checks
- **Manual Intervention Required:** Operations team manually drains unhealthy tasks

**Countermeasures:**
1. Implement multi-level health checks:
   - `/health/liveness`: Process alive (for ALB target health - always returns 200)
   - `/health/readiness`: Check PostgreSQL (SELECT 1), Redis (PING), RabbitMQ connection
   - `/health/deep`: Execute sample queries (recent appointment count, queue depth)
2. Configure ALB health check:
   - Path: `/health/readiness`
   - Interval: 10s, Timeout: 5s, Healthy threshold: 2, Unhealthy threshold: 3
3. Expose health check metrics in CloudWatch (dependency check success rate)

### M2. No Bulkhead Isolation Between Workloads
**Affected Components:** ECS Tasks (monolithic deployment)
**Reference:** Section 3 (Overall Structure - "layered monolithic architecture")

**Issue:**
Reminder polling, notification processing, and API request handling share the same ECS task resources (CPU, memory, thread pool). Runaway reminder processing (e.g., bug causing infinite loop) degrades API response times.

**Impact:**
- **Noisy Neighbor:** Background jobs starve API requests of CPU/memory
- **Blast Radius:** Bug in one subsystem (e.g., EHR batch crash) forces restart of entire task, disrupting all workflows
- **Capacity Planning Complexity:** Cannot scale reminder workers independently from API servers

**Countermeasures:**
1. **Immediate (Process-Level Isolation):**
   - Separate thread pools: API (50 threads), Reminder (10 threads), EHR Batch (5 threads)
   - Set CPU quotas using cgroups if running multiple processes per container
2. **Long-Term (Service Decomposition):**
   - Split into 3 ECS services: AppointmentAPI, ReminderWorker, EHRBatchSync
   - Independent scaling policies (API: CPU-based, Worker: queue depth-based)
   - Separate deployment cycles reduce change risk
3. Monitor per-subsystem resource usage with Micrometer tags

### M3. Missing SLO-Based Alerting Strategy
**Affected Components:** Monitoring System
**Reference:** Section 7 (Monitoring - "Application metrics...exported to CloudWatch")

**Issue:**
Design collects RED metrics (request rate, error rate, latency) but does not define alert thresholds tied to SLO. The "99.9% uptime target" and "p95 < 500ms" requirements lack corresponding alert rules.

**Impact:**
- **Delayed Incident Response:** Operations team discovers SLO breach through weekly report, not real-time alert
- **Alert Fatigue:** Without SLO-based thresholds, teams set arbitrary limits causing false positives
- **Lack of Error Budget Visibility:** Cannot track burn rate or justify maintenance windows

**Countermeasures:**
1. Define SLO-based alerts:
   - Availability SLO (99.9%): Alert if error rate > 0.1% over 5-minute window
   - Latency SLO (p95 < 500ms): Alert if p95 > 500ms for 3 consecutive minutes
   - Error budget: Calculate remaining budget = (1 - actual_uptime / SLO_target) × 100%
2. Implement multi-window alerting to reduce false positives:
   - Fast burn (2% error rate, 1-hour window): Page immediately
   - Slow burn (0.5% error rate, 24-hour window): Ticket to on-call
3. Create CloudWatch dashboard showing:
   - Current error budget remaining (%)
   - Projected budget exhaustion date
   - Top 5 error contributors by endpoint

### M4. No Graceful Degradation for Non-Critical Features
**Affected Components:** Insurance Verification, EHR Synchronization
**Reference:** Section 1 (Key Features - "insurance verification"), Section 3 (EHR Integration Service)

**Issue:**
Insurance verification (likely external API call) is part of booking flow but design does not specify fallback behavior. Similarly, EHR sync failures do not define degraded mode (e.g., manual reconciliation).

**Impact:**
- **Booking Blockage:** If insurance API slow/down, patients cannot book appointments even for providers not requiring pre-verification
- **Operational Overhead:** EHR sync failure requires manual investigation; no self-service retry mechanism for clinic admins
- **Revenue Loss:** Extended outage of insurance check blocks new patient acquisition

**Countermeasures:**
1. **Insurance Verification Degradation:**
   - Circuit breaker on insurance API (5 failures → open for 60s)
   - Fallback: Accept booking with "pending verification" status, async verify later
   - Admin dashboard to manually approve/reject pending appointments
2. **EHR Sync Degradation:**
   - On batch failure, send summary email to clinic admins with failed record count
   - Provide CSV export of failed records for manual upload to EHR
   - Implement incremental sync (retry only failed records on next run)
3. Add feature flag system (LaunchDarkly, custom solution) to disable non-critical features during incidents

### M5. Inadequate Capacity Planning for Autoscaling
**Affected Components:** ECS Task Autoscaling
**Reference:** Section 7 (Scalability - "ECS task count adjusts based on CPU utilization (target 70%)")

**Issue:**
CPU-based autoscaling alone misses I/O-bound workloads (database queries, RabbitMQ processing). During high appointment creation periods (8-9 AM), database connection pool exhaustion occurs before CPU reaches 70%, preventing scale-out.

**Impact:**
- **Missed Scaling Events:** System remains at 3 tasks despite increasing latency/error rate
- **Poor User Experience:** p95 latency degrades to 2000ms before autoscaling triggers
- **Reactive Scaling:** Cold start time (30-60s) means first wave of users experiences degraded performance

**Countermeasures:**
1. Implement composite scaling metrics:
   - Primary: CPU > 70% OR p95 latency > 400ms (80% of SLO budget)
   - Secondary: Database connection pool utilization > 75%
   - Tertiary: RabbitMQ queue depth > 5,000 messages (50% of alert threshold)
2. Add predictive scaling:
   - CloudWatch scheduled actions for known peak hours (8-9 AM, 1-2 PM)
   - Pre-warm capacity 15 minutes before expected traffic spike
3. Monitor scale-out lag time (event trigger → new task ready) and alert if exceeds 90s

---

## Minor Improvements & Positive Aspects

### Minor Improvement 1: Add Distributed Tracing for Cross-Service Workflows
The design includes correlation IDs for logging but does not mention distributed tracing (AWS X-Ray, Jaeger). For multi-step workflows (appointment creation → waitlist check → notification send → EHR sync), tracing would identify performance bottlenecks and failure injection points.

### Minor Improvement 2: Implement Rate Limiting at Multiple Layers
Current design specifies "100 requests/minute per user" but does not define enforcement layer (Redis counters at API gateway vs. application layer). Consider adding:
- Global rate limit (10,000 req/min total) to prevent DDoS
- Per-endpoint limits (POST /appointments: 10/min, GET /availability: 50/min)
- Burst allowance with token bucket algorithm

### Positive Aspect 1: Optimistic Locking for Concurrent Appointment Booking
The Appointment table includes `version` column (Section 4), indicating optimistic locking implementation. This prevents lost updates when multiple patients attempt to book the same slot simultaneously. Well-designed for high-concurrency scenarios.

### Positive Aspect 2: Structured Logging with Correlation IDs
Section 6 specifies correlation ID inclusion in logs, enabling request tracing across service boundaries. This supports efficient incident investigation and root cause analysis.

### Positive Aspect 3: Comprehensive Testing Strategy
The design includes unit tests, integration tests with Testcontainers, and load testing with JMeter (Section 6). This demonstrates awareness of quality assurance requirements beyond functional correctness.

---

## Summary of Reliability Gaps

| Category | Critical | Significant | Moderate | Minor | Total |
|----------|----------|-------------|----------|-------|-------|
| Fault Recovery Design | 1 (C1) | 2 (S2, S4) | 1 (M2) | 1 | 5 |
| Data Consistency & Idempotency | 2 (C2, C3) | 0 | 0 | 0 | 2 |
| Availability & Redundancy | 1 (C4) | 1 (S1) | 0 | 0 | 2 |
| Monitoring & Alerting | 0 | 0 | 2 (M1, M3) | 2 | 4 |
| Deployment & Rollback | 0 | 1 (S3) | 0 | 0 | 1 |
| **Total Issues** | **4** | **4** | **3** | **3** | **14** |

## Recommended Prioritization

**Phase 1 (Pre-Production Blocker):**
- C1: Implement circuit breakers for external services
- C2: Add idempotency keys to appointment creation and notifications
- C4: Upgrade Redis to cluster mode
- S3: Create backward-compatible migration process

**Phase 2 (Post-Launch Hardening):**
- C3: Implement Saga pattern for appointment cancellation
- S1: Separate connection pools by workload
- S2: Deploy RabbitMQ cluster
- M1: Implement deep health checks

**Phase 3 (Operational Maturity):**
- S4: Add timeout configurations
- M3: Define SLO-based alerting
- M4: Implement graceful degradation
- M5: Enhance autoscaling with composite metrics
