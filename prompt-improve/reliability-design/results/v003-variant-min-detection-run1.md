# Reliability Design Review: MediConnect Appointment Scheduling System
**Review Date:** 2026-02-11
**Reviewer:** reliability-design-reviewer (v003-variant-min-detection)
**Document:** test-document-round-003.md

---

## Executive Summary

This reliability review identified **15 distinct reliability issues** across fault recovery, data consistency, availability, monitoring, and deployment domains. The design document presents a cloud-based appointment scheduling system with several critical gaps in fault tolerance and operational readiness that could lead to data inconsistencies, cascading failures, and difficult recovery scenarios in production.

---

## Critical Issues (Priority 1)

### C-1: Missing Idempotency Design for Appointment Creation
**Reference:** Section 5 (API Design), Section 3 (Appointment Service)

**Issue Description:**
The POST /api/v1/appointments endpoint lacks explicit idempotency design. The document states that unhandled exceptions return standardized errors but does not specify how duplicate requests are prevented when clients retry on network failures or timeouts.

**Impact Analysis:**
- **Data Inconsistency Risk:** A patient experiencing network timeout on appointment creation may retry, resulting in duplicate appointments for the same time slot
- **Provider Overbooking:** Without idempotency keys, concurrent retries can bypass conflict detection and create double-bookings
- **Financial Impact:** Double-bookings lead to appointment cancellations, patient dissatisfaction, and potential revenue loss
- **Recovery Complexity:** Identifying and reconciling duplicate appointments requires manual intervention

**Countermeasures:**
1. Implement idempotency key mechanism: require clients to provide `Idempotency-Key` header for POST requests
2. Store idempotency keys with expiration (24-48 hours) in Redis to prevent duplicate processing
3. Return cached response for duplicate requests within expiration window
4. Add database unique constraint on (patient_id, appointment_time, provider_id, status) to catch race conditions
5. Document idempotency behavior in API specification with retry guidance

---

### C-2: No Circuit Breaker Pattern for External Service Dependencies
**Reference:** Section 3 (Notification Service, EHR Integration Service), Section 2 (External Services)

**Issue Description:**
The design mentions "Retries on failures" for Notification Service but does not specify circuit breaker implementation for Twilio, SendGrid, or EHR vendor APIs. When external services experience outages, the system may continue attempting requests indefinitely.

**Impact Analysis:**
- **Cascading Failure Risk:** Repeated failures to external services can exhaust connection pools, blocking threads, and degrading performance for unrelated operations
- **Resource Exhaustion:** Without circuit breakers, notification workers may accumulate in blocked state, consuming memory and CPU
- **Cascading Impact:** EHR sync failures during nightly batch can block appointment operations if sync logic lacks timeout protection
- **Recovery Delay:** Manual intervention required to identify and reset stuck workers

**Countermeasures:**
1. Implement circuit breaker pattern using Resilience4j library for all external service calls
2. Configure circuit breaker thresholds:
   - Open circuit after 5 consecutive failures or 50% failure rate in 10-second window
   - Half-open state after 30-second wait period
   - Close circuit after 2 successful calls in half-open state
3. Implement fallback strategies:
   - Notification Service: Retry message to queue with exponential backoff (max 3 retries)
   - EHR Integration: Mark sync status as "PENDING_RETRY" and schedule retry in next batch window
4. Expose circuit breaker metrics (state, failure count) to CloudWatch for monitoring
5. Document runbook for manual circuit reset procedures

---

### C-3: Missing Transaction Boundaries and Consistency Guarantees
**Reference:** Section 3 (Appointment Service), Section 4 (Data Model), Section 6 (Error Handling)

**Issue Description:**
The design does not explicitly define transaction boundaries for appointment operations. The document mentions "optimistic locking version" in Appointment table but lacks specification of transaction scope for operations involving multiple tables (Appointment + Availability coordination, waitlist rebooking).

**Impact Analysis:**
- **Data Inconsistency:** Appointment creation failure after availability validation can leave orphaned availability locks or inconsistent state
- **Race Conditions:** Concurrent booking attempts may bypass conflict detection without proper transaction isolation
- **Waitlist Corruption:** Cancellation triggering waitlist rebooking lacks atomicity guarantees, risking double-bookings or lost waitlist entries
- **Recovery Difficulty:** Inconsistent states require manual database inspection and correction

**Countermeasures:**
1. Define explicit transaction boundaries for all multi-step operations:
   - Appointment creation: Single transaction covering availability check, appointment insert, and availability update
   - Appointment cancellation: Transaction covering appointment status update and waitlist rebooking trigger
2. Specify isolation level for transactions (recommend READ_COMMITTED minimum, REPEATABLE_READ for booking operations)
3. Implement compensating transactions for distributed operations (e.g., EHR sync failures)
4. Add database-level constraints to enforce data integrity:
   - Foreign key constraints for patient_id, provider_id, clinic_id
   - Check constraint: appointment_time + duration_minutes within provider availability
5. Document rollback behavior and partial failure scenarios in implementation guide

---

### C-4: Single Point of Failure - Redis Session Store
**Reference:** Section 2 (Database - Redis), Section 7 (Availability)

**Issue Description:**
Redis runs in "single-instance mode for session storage" without replication or failover design. Redis failure causes all active user sessions to be invalidated, requiring re-authentication.

**Impact Analysis:**
- **Service Unavailability:** Redis outage blocks all authenticated API requests, causing complete service disruption
- **User Experience Degradation:** All logged-in users forced to re-authenticate simultaneously, creating login service spike
- **Cascading Load:** Mass re-authentication after Redis recovery can overload OAuth2 service
- **RPO/RTO Impact:** Session data loss means zero RPO impossible, RTO depends on Redis restart time (minutes to hours)

**Countermeasures:**
1. Deploy Redis in cluster mode with replication:
   - AWS ElastiCache Redis with Multi-AZ enabled (automatic failover)
   - Configure 1 primary + 2 replica nodes across Availability Zones
2. Implement session persistence fallback:
   - Store session metadata in PostgreSQL with longer TTL
   - Use Redis as cache with database as source of truth
3. Add health checks for Redis connectivity in application startup and readiness probes
4. Implement graceful degradation: allow limited read-only operations with expired tokens during Redis outage
5. Configure session token refresh mechanism to reduce re-authentication frequency

---

### C-5: No Distributed Tracing for Cross-Service Debugging
**Reference:** Section 6 (Logging), Section 3 (Architecture Design)

**Issue Description:**
The design mentions "request correlation IDs for tracing" but does not specify distributed tracing implementation. For asynchronous workflows (reminder → notification → SMS/email), correlation IDs alone are insufficient to reconstruct failure scenarios.

**Impact Analysis:**
- **MTTR Increase:** Production failures involving RabbitMQ message processing require manual log correlation across multiple services
- **Root Cause Blind Spots:** Cannot trace end-to-end latency for reminder delivery (database poll → queue enqueue → notification worker → external API)
- **Performance Debugging Difficulty:** No visibility into which stage of asynchronous pipeline contributes to latency spikes
- **Operational Overhead:** Engineers must manually query logs across ECS tasks, RabbitMQ, and external service logs

**Countermeasures:**
1. Implement distributed tracing using OpenTelemetry or AWS X-Ray:
   - Instrument HTTP requests with trace context propagation (W3C Trace Context)
   - Add RabbitMQ message headers for trace ID propagation
   - Instrument external API calls (Twilio, SendGrid, EHR APIs)
2. Configure trace sampling strategy:
   - 100% sampling for errors and high-latency requests (>2 seconds)
   - 10% sampling for successful requests to reduce overhead
3. Store traces in AWS X-Ray or third-party APM (Datadog, New Relic)
4. Create trace-based dashboards for key workflows:
   - Appointment creation end-to-end latency
   - Reminder delivery pipeline breakdown
   - EHR sync batch processing duration
5. Add trace ID to error logs and customer support tickets for faster incident response

---

## Significant Issues (Priority 2)

### S-1: Missing Timeout Specifications for External API Calls
**Reference:** Section 3 (EHR Integration Service, Notification Service), Section 2 (External Services)

**Issue Description:**
The design does not specify timeout configurations for Twilio, SendGrid, or EHR vendor API calls. Without timeouts, blocked external API calls can cause thread starvation and worker accumulation.

**Impact Analysis:**
- **Resource Exhaustion:** Stuck API calls consume thread pool resources, blocking new requests
- **Cascading Delay:** EHR sync without timeout can block nightly batch for hours if vendor API hangs
- **Queue Backlog:** Notification workers stuck on external calls stop consuming RabbitMQ messages, causing queue depth growth
- **Alert Fatigue:** Queue depth alerts (>10,000 messages) triggered by worker starvation rather than actual load

**Countermeasures:**
1. Define timeout policies for all external service categories:
   - Real-time APIs (Twilio SMS, SendGrid email): 5-second connection timeout, 10-second read timeout
   - Batch APIs (EHR FHIR sync): 30-second connection timeout, 2-minute read timeout
2. Implement timeout enforcement at HTTP client level (configure RestTemplate or WebClient)
3. Add timeout monitoring metrics: track timeout occurrences per service
4. Configure retry behavior after timeout: exponential backoff with jitter (1s, 2s, 4s)
5. Document timeout values in external service integration runbook

---

### S-2: Insufficient Monitoring Coverage for Critical Reliability Signals
**Reference:** Section 7 (Monitoring), Section 7 (Non-Functional Requirements - Performance)

**Issue Description:**
Monitoring section mentions "request rate, error rate, latency" and "daily appointment creation count" but lacks SLO-based alerting, dependency health checks, and resource saturation metrics critical for reliability.

**Impact Analysis:**
- **Late Failure Detection:** No SLO-based alerts means degradation detected only after customer complaints
- **Blind Spots:** Missing metrics for queue depth trend, database connection pool utilization, external service error rates
- **Capacity Planning Gap:** No monitoring for CPU/memory trends, making autoscaling reactive rather than proactive
- **Incident Response Delay:** Lack of dependency health dashboards slows root cause identification

**Countermeasures:**
1. Define SLOs with measurable thresholds and error budgets:
   - Appointment booking success rate: 99.5% (error budget: 0.5%)
   - API latency p95: <500ms (already specified, add alert threshold: >600ms)
   - Reminder delivery SLO: 95% within 30 minutes, 99.9% within 60 minutes
2. Implement RED metrics (Rate, Error, Duration) for all API endpoints:
   - Monitor per-endpoint error rates (4xx, 5xx separately)
   - Track latency distribution (p50, p95, p99)
3. Add resource saturation metrics:
   - Database connection pool utilization (alert at >80%)
   - RabbitMQ queue depth with trend analysis (alert at >5,000 and growth rate >1,000/minute)
   - ECS task CPU/memory utilization per-task (alert at >85% sustained for 5 minutes)
4. Create dependency health checks:
   - PostgreSQL read/write latency monitoring
   - Redis connectivity check (ping command success rate)
   - External service circuit breaker state monitoring
5. Build composite reliability dashboard aggregating SLO compliance, error budget burn rate, and dependency health

---

### S-3: Missing Retry Strategy with Exponential Backoff and Jitter
**Reference:** Section 3 (Notification Service)

**Issue Description:**
The design states "Retries on failures" for Notification Service but does not specify retry strategy details: maximum retry count, backoff algorithm, or jitter to prevent thundering herd.

**Impact Analysis:**
- **Thundering Herd Risk:** Simultaneous retries after external service recovery can cause overload and re-failure
- **Infinite Retry Loop:** Without maximum retry limit, messages can circulate indefinitely, consuming resources
- **Resource Waste:** Aggressive retry without backoff delays wastes CPU and network bandwidth on doomed requests
- **Queue Visibility Loss:** Failed messages without dead letter queue (DLQ) handling disappear silently

**Countermeasures:**
1. Implement exponential backoff with jitter for all retry logic:
   - Base delay: 1 second
   - Maximum delay: 5 minutes
   - Jitter: ±25% randomization to spread retry load
   - Formula: `delay = min(300, base * 2^attempt) * (1 + random(-0.25, 0.25))`
2. Set maximum retry limits per message type:
   - SMS notifications: 3 retries (total 4 attempts)
   - Email notifications: 5 retries (total 6 attempts)
   - EHR sync: 3 retries, then manual intervention
3. Configure RabbitMQ dead letter queue (DLQ) for exhausted retries:
   - Route failed messages to DLQ after max retries exceeded
   - Set up monitoring alert for DLQ depth (alert at >10 messages)
4. Add retry metadata to messages: attempt count, first attempt timestamp, last error message
5. Document retry behavior in operations runbook with manual DLQ processing procedures

---

### S-4: Lack of Bulkhead Isolation Between Critical and Non-Critical Operations
**Reference:** Section 3 (Architecture Design), Section 7 (Scalability)

**Issue Description:**
The monolithic architecture with shared thread pools means non-critical operations (reminder polling, EHR batch sync) can starve resources from critical operations (appointment booking API).

**Impact Analysis:**
- **Service Degradation Risk:** EHR sync batch consuming excessive database connections can block appointment booking
- **Cascading Failure:** Reminder Service polling database every 5 minutes can degrade performance during high load
- **Priority Inversion:** Non-urgent background jobs compete equally with real-time API requests for resources
- **Blast Radius:** Single component failure (e.g., reminder processing bug) can impact entire application

**Countermeasures:**
1. Implement bulkhead isolation using separate thread pools:
   - API request thread pool: 50 threads (high priority)
   - Notification worker thread pool: 10 threads (medium priority)
   - Reminder polling thread pool: 2 threads (low priority)
   - EHR sync thread pool: 5 threads (low priority, scheduled)
2. Configure separate database connection pools per component:
   - API operations: 15 connections (from total 20 per instance)
   - Background jobs: 5 connections
   - Set connection timeout and queue limits to fail fast
3. Add rate limiting for background jobs:
   - Reminder polling: maximum 1,000 appointments processed per batch
   - EHR sync: maximum 500 requests/minute to vendor API
4. Implement graceful degradation policies:
   - Disable reminder polling during high API load (CPU >80%)
   - Pause EHR sync if database connection pool exhaustion detected
5. Monitor thread pool metrics: active threads, queued tasks, rejected tasks

---

### S-5: Missing Rollback Criteria and Automated Rollback Mechanism
**Reference:** Section 6 (Deployment), Section 7 (Availability)

**Issue Description:**
The design specifies "Blue-green deployment on AWS ECS" but does not document rollback criteria, automated rollback procedures, or rollback testing. Manual Flyway migrations executed before deployment lack rollback plan.

**Impact Analysis:**
- **Deployment Risk:** Bad deployments detected late (after blue-green switch) require manual rollback, increasing downtime
- **Data Migration Failure:** Irreversible Flyway migrations can block rollback to previous application version
- **MTTR Increase:** Manual rollback procedures during incident response introduce human error risk
- **Confidence Erosion:** Lack of automated rollback reduces team confidence in frequent deployments

**Countermeasures:**
1. Define automated rollback criteria with specific thresholds:
   - Error rate increase: >5% compared to pre-deployment baseline (5-minute window)
   - Latency degradation: p95 latency >800ms sustained for 3 minutes
   - Health check failures: >10% of tasks failing health checks
2. Implement automated rollback mechanism:
   - Configure ECS blue-green deployment with automatic rollback on CloudWatch alarm
   - Use AWS CodeDeploy lifecycle hooks for pre-traffic and post-traffic health validation
3. Design backward-compatible database migrations:
   - Phase 1: Add new columns as nullable, deploy application version supporting both schemas
   - Phase 2: Backfill data, then make columns non-nullable (separate deployment)
   - Document rollback procedure for each migration script
4. Create rollback runbook with manual procedures:
   - ECS task definition version rollback steps
   - Database migration rollback SQL scripts (test in staging)
   - Cache invalidation procedures (Redis flush if schema changes)
5. Test rollback procedures in staging environment before production deployment

---

## Moderate Issues (Priority 3)

### M-1: Missing Health Check Design at Multiple Levels
**Reference:** Section 7 (Availability), Section 3 (Key Components)

**Issue Description:**
The design does not specify health check endpoints or health check implementation strategy. Without multi-level health checks (liveness, readiness, dependency health), orchestration platform cannot reliably detect unhealthy tasks.

**Impact Analysis:**
- **Traffic Routing to Unhealthy Tasks:** ALB continues routing requests to tasks with degraded dependencies (Redis down, database connection pool exhausted)
- **Cascading Failure Risk:** Tasks with circuit breakers open still receive traffic, returning 5xx errors
- **Slow Failure Detection:** ECS relies on application exit to detect failures, missing degraded states
- **Maintenance Risk:** Database maintenance requires manual task drain rather than automatic readiness probe failure

**Countermeasures:**
1. Implement multi-level health check endpoints:
   - `GET /health/liveness`: Returns 200 if application process is running (shallow check)
   - `GET /health/readiness`: Returns 200 only if all critical dependencies are healthy (deep check)
   - `GET /health/dependencies`: Returns detailed status of PostgreSQL, Redis, RabbitMQ connectivity
2. Configure ALB target group health checks:
   - Health check path: `/health/readiness`
   - Interval: 30 seconds, Timeout: 5 seconds, Unhealthy threshold: 2 consecutive failures
3. Configure ECS task health checks:
   - Liveness probe: `/health/liveness` (interval: 10s, failure threshold: 3)
   - Startup probe: `/health/readiness` (interval: 5s, failure threshold: 30, allows 150s startup time)
4. Implement dependency health check logic:
   - PostgreSQL: Execute `SELECT 1` query with 2-second timeout
   - Redis: Execute `PING` command with 1-second timeout
   - RabbitMQ: Check connection status in connection pool
5. Add circuit breaker state to readiness check: return unhealthy if critical circuit breakers are open

---

### M-2: Insufficient Capacity Planning and Load Shedding Strategy
**Reference:** Section 7 (Scalability), Section 7 (Security - API rate limiting)

**Issue Description:**
The design specifies autoscaling based on CPU utilization (70% target) and per-user rate limiting (100 req/min) but lacks system-wide capacity limits, load shedding strategy for overload scenarios, or capacity planning model.

**Impact Analysis:**
- **Overload Risk:** Sudden traffic spikes (e.g., clinic opening time) can overwhelm system before autoscaling responds
- **Database Bottleneck:** Application autoscaling does not protect PostgreSQL from connection exhaustion
- **Cost Runaway:** Uncapped autoscaling can lead to excessive ECS task creation during DDoS or traffic anomalies
- **Degraded Experience:** No priority-based load shedding means critical operations (provider schedule access) degraded equally with lower-priority operations (report generation)

**Countermeasures:**
1. Define system-wide capacity limits and thresholds:
   - Maximum ECS task count: 20 tasks (protects cost and database capacity)
   - Database connection hard limit: 300 connections (PostgreSQL max_connections minus admin reserve)
   - RabbitMQ memory limit: 4GB (set high watermark to prevent disk write overhead)
2. Implement load shedding strategy with priority classes:
   - Priority 1 (critical): Appointment booking API, provider schedule access (never shed)
   - Priority 2 (important): Appointment cancellation, patient dashboard (shed at >90% capacity)
   - Priority 3 (best-effort): Report generation, analytics queries (shed at >80% capacity)
3. Add global rate limiting at ALB level:
   - System-wide rate limit: 5,000 requests/second (adjust based on load testing)
   - Return HTTP 503 with Retry-After header when limit exceeded
4. Create capacity planning model:
   - Baseline: 1,000 appointments/hour = 3 ECS tasks + 50 database connections
   - Peak capacity: 5,000 appointments/hour = 15 ECS tasks + 250 database connections
   - Document autoscaling lag time (5-10 minutes) and pre-scaling procedures for known traffic events
5. Monitor capacity metrics: ECS task count, database connection utilization, queue depth, request rejection rate

---

### M-3: Missing Incident Response Runbooks and Escalation Procedures
**Reference:** Section 6 (Implementation Strategy), Section 7 (Monitoring)

**Issue Description:**
The design does not reference incident response procedures, on-call escalation policies, or operational runbooks for common failure scenarios. Without documented procedures, MTTR increases due to ad-hoc troubleshooting.

**Impact Analysis:**
- **MTTR Increase:** Engineers unfamiliar with system architecture require longer time to diagnose and resolve incidents
- **Inconsistent Response:** Lack of standardized procedures leads to varied incident handling quality
- **Escalation Delays:** Undefined escalation paths cause delays in engaging appropriate expertise
- **Knowledge Loss:** Operational knowledge remains tribal, creating bus factor risk

**Countermeasures:**
1. Create incident response runbooks for common failure scenarios:
   - **Runbook: Appointment Booking 5xx Errors**
     - Check PostgreSQL connection pool utilization
     - Check Redis connectivity status
     - Review recent deployment history
     - Rollback procedure if deployment-related
   - **Runbook: Reminder Delivery Delay**
     - Check RabbitMQ queue depth and consumer status
     - Verify Twilio/SendGrid API status (circuit breaker metrics)
     - Check Notification Service worker thread pool saturation
   - **Runbook: Database Connection Pool Exhaustion**
     - Identify long-running queries via PostgreSQL pg_stat_activity
     - Check for connection leaks in application logs
     - Temporarily increase connection limit if needed
     - Scale up ECS tasks to distribute load
2. Define alert escalation policy with severity tiers:
   - **SEV-1 (Critical):** Service unavailable, data loss, security breach → Page on-call immediately, escalate to senior engineer after 15 minutes
   - **SEV-2 (High):** Degraded performance, partial outage → Slack notification, page if unresolved after 30 minutes
   - **SEV-3 (Medium):** Non-urgent issues, capacity warnings → Slack notification, resolve within 24 hours
3. Document on-call rotation schedule and contact information in incident management tool
4. Create operational dashboards linked from runbooks:
   - System health overview (SLO compliance, error rates, dependency status)
   - Component-specific dashboards (database, queue, external services)
5. Conduct quarterly incident response drills to validate runbook accuracy

---

### M-4: Missing Backup and Restore Testing Procedures
**Reference:** Section 7 (Disaster Recovery)

**Issue Description:**
The design specifies "PostgreSQL automated backups retained for 7 days" with "Point-in-time recovery supported" but does not mention backup testing, restore time objectives (RTO), or restore procedures.

**Impact Analysis:**
- **Untested Backups Risk:** Backups may be corrupted or incomplete, discovered only during actual disaster recovery
- **RTO Uncertainty:** Restore duration unknown, making SLA commitments unreliable
- **Data Loss Risk:** No validation that backup snapshots contain consistent data
- **Operational Panic:** Engineers lack confidence in disaster recovery procedures during incidents

**Countermeasures:**
1. Establish backup testing schedule:
   - Monthly: Restore most recent backup to staging environment, verify data integrity
   - Quarterly: Perform point-in-time recovery test to specific timestamp
   - Annually: Full disaster recovery drill (restore to new environment, switch traffic)
2. Document restore procedures with step-by-step instructions:
   - RDS snapshot restore process (console and CLI commands)
   - Connection string updates for restored instance
   - Data validation queries to verify restore completeness
   - Estimated restore time based on database size (document baseline: e.g., 100GB = 30 minutes)
3. Define RPO/RTO targets explicitly:
   - RPO: 5 minutes (RDS automated backup continuous archival)
   - RTO: 2 hours (restore time + validation + traffic switch)
4. Automate backup integrity validation:
   - Weekly Lambda function to restore latest backup to test instance
   - Run smoke test queries (row count validation, foreign key constraint checks)
   - Alert if validation fails
5. Document data retention policy: 7-day backup retention justification and extension criteria for compliance

---

### M-5: Missing Rate Limiting and Backpressure for Background Jobs
**Reference:** Section 3 (Reminder Service), Section 3 (EHR Integration Service)

**Issue Description:**
The design specifies Reminder Service "polls the database every 5 minutes" and EHR Integration "operates on a nightly batch schedule" but does not specify rate limiting, batch size limits, or backpressure mechanisms to prevent resource exhaustion.

**Impact Analysis:**
- **Database Overload:** Reminder polling scanning large appointment tables can cause lock contention and slow down API queries
- **Memory Exhaustion:** Loading unbounded result sets into memory can cause OOM errors
- **Batch Duration Creep:** Nightly EHR sync duration increases over time as appointment volume grows, eventually exceeding maintenance window
- **Queue Flooding:** Reminder Service enqueuing thousands of messages simultaneously can overwhelm RabbitMQ and Notification workers

**Countermeasures:**
1. Implement batch size limits for polling operations:
   - Reminder Service: Process maximum 1,000 appointments per poll iteration
   - Use pagination with OFFSET/LIMIT or cursor-based pagination
   - Add `last_processed_at` column to track polling progress across iterations
2. Add rate limiting for external API calls:
   - EHR sync: Maximum 500 FHIR API calls per minute (adjust based on vendor rate limits)
   - Use token bucket algorithm to smooth traffic
3. Implement backpressure signaling:
   - Check RabbitMQ queue depth before enqueuing reminder messages
   - Pause polling if queue depth exceeds 5,000 messages (wait 60 seconds before retry)
   - Monitor Notification worker lag to detect processing bottlenecks
4. Optimize database queries for background jobs:
   - Add index on `(appointment_time, status)` for reminder polling
   - Add index on `(updated_at, sync_status)` for EHR sync
   - Use `SELECT FOR UPDATE SKIP LOCKED` for parallel worker processing
5. Monitor background job metrics: batch duration, records processed per iteration, queue enqueue rate, database query latency

---

## Minor Improvements and Positive Aspects

### Positive: Optimistic Locking for Concurrency Control
The design includes a `version` column in the Appointment table for optimistic locking, which helps prevent lost updates during concurrent modifications. This is an appropriate choice for appointment booking scenarios where conflicts are relatively rare.

**Recommendation:** Document the retry behavior when optimistic locking conflicts occur (HTTP 409 response with client retry guidance).

---

### Positive: Multi-AZ Deployment for Infrastructure Resilience
The design specifies "ECS tasks run across 2 Availability Zones" and PostgreSQL RDS with automated backups, demonstrating awareness of infrastructure-level fault tolerance.

**Recommendation:** Extend multi-AZ strategy to Redis (ElastiCache Multi-AZ) to eliminate remaining SPOF.

---

### Positive: Structured Logging with Correlation IDs
The design includes "request correlation IDs for tracing" using structured logging (SLF4J with Logback), which aids in troubleshooting and incident response.

**Recommendation:** Extend correlation ID propagation to RabbitMQ messages and external API calls to enable end-to-end tracing.

---

## Summary

This reliability review identified **15 distinct issues** requiring attention before production deployment:

**Critical (5 issues):**
- Missing idempotency design for appointment creation (data inconsistency risk)
- No circuit breaker pattern for external service dependencies (cascading failure risk)
- Missing transaction boundaries and consistency guarantees (data corruption risk)
- Single point of failure in Redis session store (service unavailability risk)
- No distributed tracing for cross-service debugging (high MTTR)

**Significant (5 issues):**
- Missing timeout specifications for external API calls
- Insufficient monitoring coverage for critical reliability signals
- Missing retry strategy with exponential backoff and jitter
- Lack of bulkhead isolation between critical and non-critical operations
- Missing rollback criteria and automated rollback mechanism

**Moderate (5 issues):**
- Missing health check design at multiple levels
- Insufficient capacity planning and load shedding strategy
- Missing incident response runbooks and escalation procedures
- Missing backup and restore testing procedures
- Missing rate limiting and backpressure for background jobs

The design demonstrates awareness of some reliability practices (optimistic locking, multi-AZ deployment, structured logging) but requires significant additions to achieve production-grade operational readiness. Priority should be given to addressing critical issues (C-1 through C-5) before launch to prevent data inconsistencies, cascading failures, and service unavailability scenarios.
