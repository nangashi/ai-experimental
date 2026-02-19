# Reliability Design Review: MediConnect Appointment Scheduling System

## Executive Summary

This reliability evaluation identifies critical gaps in fault tolerance, data consistency, and operational readiness that pose significant risks to production operations. The design shows some positive elements (optimistic locking, multi-AZ deployment) but lacks essential distributed systems patterns and operational safeguards required for a healthcare scheduling system.

---

## Critical Issues

### C-1: Missing Idempotency Design for Critical Operations

**Issue**: The appointment creation and cancellation APIs lack explicit idempotency mechanisms. Network retries or client-side failures could result in duplicate appointments or double-cancellations, directly impacting patient care.

**Impact**:
- Patient arrives for cancelled appointment after retry creates duplicate cancellation
- Double-booking when retry creates second appointment
- Waitlist logic triggered multiple times, causing cascade rebooking errors

**Evidence**: Section 5 shows POST/DELETE endpoints without idempotency keys. Section 4 includes optimistic locking (`version` column) but no request deduplication identifiers.

**Recommendation**:
- Add `idempotency_key` column to Appointment table with UNIQUE constraint
- Require `Idempotency-Key` header on mutating operations (POST/DELETE)
- Return cached response for duplicate requests within 24-hour window
- Document idempotency guarantees in API specification

---

### C-2: No Circuit Breaker for External Service Dependencies

**Issue**: Direct calls to Twilio, SendGrid, and EHR APIs lack circuit breaker protection. Cascading failures from external service degradation will exhaust connection pools and block critical appointment operations.

**Impact**:
- EHR API timeout (Section 3: "nightly batch schedule") blocks appointment sync indefinitely
- Twilio outage prevents notification dispatch and fills RabbitMQ queues
- Thread starvation in notification workers prevents reminder delivery

**Evidence**: Section 3 mentions "Retries on failures" for Notification Service but no circuit breaker, timeout configuration, or bulkhead isolation.

**Recommendation**:
- Implement circuit breaker pattern (Resilience4j) for all external HTTP clients
- Configure failure thresholds: 50% error rate over 10 requests → OPEN state
- Set explicit timeouts: Twilio/SendGrid 5s, EHR APIs 30s
- Use separate thread pools (bulkhead pattern) for each external service

---

### C-3: Single Point of Failure in Redis Session Storage

**Issue**: Redis runs in "single-instance mode" (Section 7) for session management. Redis failure immediately invalidates all user sessions, requiring full re-authentication across all patients and providers.

**Impact**:
- Complete service outage for authenticated operations during Redis downtime
- Mass logout event during maintenance or crash
- No automatic recovery mechanism documented

**Evidence**: Section 2 and Section 7 explicitly state single-instance Redis configuration.

**Recommendation**:
- Deploy Redis in cluster mode with ElastiCache replication (1 primary + 2 replicas)
- Enable automatic failover with Multi-AZ configuration
- Implement session data persistence (AOF or RDB snapshots)
- Add health check with graceful degradation (allow critical operations with database-backed fallback)

---

### C-4: Nightly Batch EHR Synchronization Without Failure Recovery

**Issue**: EHR integration operates on "nightly batch schedule" (Section 3) with no documented failure recovery, retry strategy, or data reconciliation mechanism.

**Impact**:
- Silent data loss if batch job fails during network partition
- EHR systems show stale appointment data until next successful run (up to 24h lag)
- No alerting for synchronization failures, violating healthcare compliance requirements

**Evidence**: Section 3 states "nightly batch schedule" with no mention of retry logic, dead-letter queues, or reconciliation processes.

**Recommendation**:
- Add EHR sync status tracking table with last_success_timestamp and failure_count columns
- Implement exponential backoff retry (3 attempts: immediate, +5min, +30min)
- Create alert for sync failures exceeding 2-hour threshold
- Design incremental sync with change data capture to handle partial failures
- Document manual reconciliation runbook for extended outages

---

### C-5: Missing Transaction Boundaries for Appointment Booking

**Issue**: Appointment creation (Section 5) involves coordination between Appointment Service and Availability Service with no documented transaction management or distributed consistency strategy.

**Impact**:
- Race condition: Two concurrent requests book the same time slot
- Orphaned availability records if appointment creation fails after availability lock
- Inconsistent state between appointment and availability tables

**Evidence**: Section 3 describes separate services coordinating booking logic, but Section 6 provides no details on transaction boundaries or consistency mechanisms.

**Recommendation**:
- Use database-level distributed transactions (XA) or Saga pattern with compensating transactions
- Implement row-level locking: `SELECT ... FOR UPDATE` on availability slots during booking
- Add booking_status column with PENDING → CONFIRMED → COMPLETED state machine
- Design timeout-based cleanup job for PENDING appointments older than 5 minutes

---

### C-6: No Rollback Strategy or Deployment Safety Mechanisms

**Issue**: Blue-green deployment (Section 6) executes database migrations "manually before deployment" with no rollback procedures, backward compatibility strategy, or feature flags.

**Impact**:
- Failed deployment requires manual database rollback with potential data loss
- Incompatible schema changes block rollback to previous application version
- No mechanism to incrementally enable new features or A/B test changes

**Evidence**: Section 6 mentions Flyway migrations executed manually but no rollback documentation or safety mechanisms.

**Recommendation**:
- Implement backward-compatible migration strategy (additive changes only)
- Use feature flags (LaunchDarkly or AWS AppConfig) for new functionality
- Document rollback procedures including database migration reversion
- Add pre-deployment validation: execute migrations in staging with automated rollback test
- Define rollback criteria (error rate > 5%, latency p95 > 1s)

---

## Significant Issues

### S-1: Missing SLO/SLA Definitions and Error Budget Tracking

**Issue**: Section 7 specifies performance targets (p95 < 500ms) and availability (99.9%) but no SLO definitions, error budget tracking, or alert thresholds tied to business impact.

**Impact**:
- No objective criteria for incident escalation
- Difficult to prioritize reliability improvements vs. feature development
- Compliance risk for healthcare SLA requirements

**Recommendation**:
- Define SLOs: Availability 99.9% (43 min downtime/month), Booking API latency p95 < 500ms, Reminder delivery success rate > 99%
- Implement error budget tracking: Alert when 50% of monthly budget consumed
- Create SLO dashboard with burn rate analysis
- Document escalation policy: Page on-call engineer when error budget exhausted

---

### S-2: Insufficient Monitoring for Distributed System Signals

**Issue**: Monitoring (Section 7) collects basic RED metrics but lacks critical distributed systems signals: queue depth trends, external service latency/error rates, database replication lag, connection pool saturation.

**Impact**:
- Cannot detect RabbitMQ message backlog indicating notification delivery failure
- No visibility into external service degradation before complete failure
- Database replication lag goes undetected, causing stale reads in multi-AZ setup

**Recommendation**:
- Add queue depth monitoring: Alert on RabbitMQ messages > 10,000 or growth rate > 1000/min
- Track external service metrics: Twilio/SendGrid/EHR API error rates, latency percentiles, circuit breaker state changes
- Monitor database connection pool: Alert on active connections > 80% of max pool size
- Implement distributed tracing (AWS X-Ray) for end-to-end request visibility

---

### S-3: Waitlist Rebooking Logic Without Duplicate Prevention

**Issue**: Appointment cancellation "triggers waitlist rebooking logic" (Section 3) with no documented duplicate prevention or idempotency guarantees.

**Impact**:
- Multiple waitlist patients notified for same cancelled slot if cancellation retried
- Race condition between manual booking and automatic rebooking
- Infinite loop if rebooking fails and triggers retry

**Recommendation**:
- Use distributed lock (Redis) for waitlist processing with TTL = 60 seconds
- Add processed_at timestamp to waitlist table to prevent reprocessing
- Implement rebooking as asynchronous job with explicit retry policy (3 attempts, exponential backoff)
- Log waitlist processing events for audit trail

---

### S-4: Missing Rate Limiting and Backpressure Mechanisms

**Issue**: API rate limiting (Section 7) is per-user (100 req/min) but no system-wide backpressure, load shedding, or priority queuing for critical operations.

**Impact**:
- Flash crowd during provider availability release overwhelms system
- Non-critical operations (availability queries) starve critical operations (cancellations)
- Database connection pool exhaustion prevents administrative operations

**Recommendation**:
- Implement system-wide rate limiting: Max 1000 req/sec total capacity
- Add priority queuing: Cancellations > Bookings > Availability queries
- Configure load shedding: Return 503 when CPU > 90% or DB connections > 90% max
- Use token bucket algorithm with burst capacity for legitimate traffic spikes

---

### S-5: No Health Check Design for Service Dependencies

**Issue**: No health check endpoints or dependency health monitoring described in the design.

**Impact**:
- Load balancer cannot detect unhealthy ECS tasks
- Deployment proceeds even when database connection fails
- No automatic recovery from transient failures

**Recommendation**:
- Implement `/health` endpoint: Check database connectivity, Redis connection, RabbitMQ availability
- Add `/ready` endpoint: Validate external service circuit breakers not in OPEN state
- Configure ALB health checks: 3 consecutive failures → remove from rotation
- Design graceful shutdown: Drain in-flight requests before ECS task termination

---

## Moderate Issues

### M-1: Reminder Service Polling Inefficiency and Race Conditions

**Issue**: Reminder Service "polls the database every 5 minutes" (Section 3) for upcoming appointments. This design creates race conditions when multiple instances poll simultaneously.

**Impact**:
- Duplicate reminder delivery if two instances process same appointment
- 5-minute polling interval causes delivery delays approaching SLA boundary (30 min target)
- Database load increases linearly with appointment volume

**Recommendation**:
- Replace polling with event-driven design: Enqueue reminder message when appointment created
- Use RabbitMQ delayed message plugin for scheduled delivery
- Add sent_at timestamp to prevent duplicate sends
- Implement advisory locks (PostgreSQL `pg_advisory_lock`) if polling retained

---

### M-2: Inadequate Connection Pool Configuration

**Issue**: HikariCP connection pool sized at "max 20 connections per instance" (Section 7) with no documented justification or overflow handling strategy.

**Impact**:
- 3 ECS instances × 20 connections = 60 connections to PostgreSQL
- No headroom for connection spikes during scale-up or batch jobs
- Connection exhaustion during traffic surges causes 5xx errors

**Recommendation**:
- Resize pool: (2 × CPU cores) + effective spindle count = ~10 connections per instance
- Configure timeout: `connectionTimeout=30s`, `maxLifetime=30min`
- Add connection pool metrics: Alert on wait time > 100ms or active connections > 80%
- Implement connection retry with exponential backoff

---

### M-3: Missing Capacity Planning and Autoscaling Strategy

**Issue**: Autoscaling based solely on "CPU utilization (target 70%)" (Section 7) without consideration for database connection limits, queue depth, or request latency.

**Impact**:
- Scaling up adds ECS tasks but exceeds PostgreSQL connection limit
- High queue depth (slow consumers) doesn't trigger scale-up if CPU low
- Latency degradation not addressed until CPU threshold reached

**Recommendation**:
- Use multi-metric autoscaling: CPU > 70% OR ALB request count > 1000/min OR target response time > 400ms
- Set max task count based on database connection limit: maxTasks = (dbMaxConnections - buffer) / connectionsPerTask
- Implement predictive scaling for known traffic patterns (business hours)
- Add manual scaling procedures for anticipated events (provider schedule releases)

---

### M-4: Insufficient Backup Testing and RPO/RTO Definition

**Issue**: PostgreSQL automated backups retained for 7 days (Section 7) with point-in-time recovery, but no documented Recovery Point Objective (RPO), Recovery Time Objective (RTO), or restore testing procedures.

**Impact**:
- Unknown actual recovery time during disaster
- Untested restores may fail during actual incident
- Ambiguity on acceptable data loss window

**Recommendation**:
- Define RPO/RTO: RPO = 15 minutes (automated backup frequency), RTO = 4 hours (manual restore)
- Schedule quarterly restore drills to validate backup integrity
- Document restoration runbook with step-by-step procedures
- Monitor backup success and alert on failures within 1 hour

---

### M-5: Inadequate Retry Strategy Documentation

**Issue**: Notification Service "retries on failures" (Section 3) with no specified retry limits, backoff strategy, or dead-letter queue handling.

**Impact**:
- Infinite retry loops for permanent failures (invalid phone number)
- Retry storms during external service outage
- No mechanism to investigate or manually reprocess failed messages

**Recommendation**:
- Implement exponential backoff with jitter: 1s, 2s, 4s, 8s, 16s max
- Set retry limit: Max 5 attempts before moving to dead-letter queue (DLQ)
- Configure DLQ monitoring: Alert when DLQ depth > 100 messages
- Create admin interface for manual DLQ message inspection and reprocessing

---

## Minor Improvements and Positive Aspects

### Positive: Optimistic Locking for Concurrency Control
The design includes `version` column (Section 4) for optimistic locking, correctly addressing concurrent appointment updates.

### Positive: Correlation ID for Request Tracing
Structured logging with correlation IDs (Section 6) enables end-to-end request tracing across distributed components.

### Positive: Multi-AZ Deployment
ECS tasks across 2 Availability Zones (Section 7) provides basic redundancy against zone failures.

### Minor: Database Migration Automation
Flyway integration (Section 6) provides version-controlled schema management, though execution is manual and lacks rollback strategy.

### Minor: Testcontainers for Integration Testing
Integration tests with Testcontainers (Section 6) validate database and messaging integration, improving deployment confidence.

---

## Summary and Prioritization

**Immediate Action Required (Critical):**
1. Implement idempotency for appointment create/cancel (C-1)
2. Add circuit breakers for external services (C-2)
3. Upgrade Redis to cluster mode with replication (C-3)
4. Design EHR sync failure recovery (C-4)
5. Implement transaction boundaries for booking (C-5)
6. Document rollback procedures and add feature flags (C-6)

**High Priority (Significant):**
7. Define SLOs and error budget tracking (S-1)
8. Enhance monitoring for distributed systems (S-2)
9. Add waitlist rebooking duplicate prevention (S-3)
10. Implement system-wide backpressure (S-4)
11. Design health checks for dependencies (S-5)

**Medium Priority (Moderate):**
12. Replace reminder polling with event-driven design (M-1)
13. Optimize connection pool configuration (M-2)
14. Improve autoscaling strategy (M-3)
15. Test backup procedures and define RPO/RTO (M-4)
16. Document retry strategies with DLQ (M-5)

The design shows foundational understanding of reliability concerns but requires significant enhancements before production deployment in a healthcare context.
