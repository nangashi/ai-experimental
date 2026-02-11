# Reliability Review: MediConnect Appointment Scheduling System

**Review Date:** 2026-02-11
**Reviewer Agent:** reliability-design-reviewer
**Prompt Version:** v003-baseline
**Test Document:** test-document-round-003.md

---

## Executive Summary

This reliability review identifies **7 critical issues**, **5 significant issues**, and **4 moderate issues** in the MediConnect system design. The most severe concerns involve single points of failure, missing fault recovery mechanisms, unclear data consistency guarantees, and insufficient operational safety controls. The design demonstrates basic architectural awareness but lacks explicit reliability engineering practices required for a healthcare appointment system.

---

## Critical Issues

### C-1: Redis Single Point of Failure for Session Management

**Location:** Section 2 (Database), Section 7 (Availability)

**Issue:**
Redis operates in "single-instance mode" for session storage (line 216), creating a critical single point of failure. If Redis becomes unavailable, all user sessions are lost, causing complete service disruption for authenticated operations.

**Impact:**
- Immediate logout of all active users (patients and providers)
- Inability to authenticate any requests until Redis recovers
- Complete system unavailability despite healthy application and database layers
- Healthcare providers unable to access appointment schedules during outage

**Countermeasures:**
1. Deploy Redis in cluster mode with automatic failover (Redis Sentinel or AWS ElastiCache with Multi-AZ)
2. Implement session persistence to database as fallback with lazy rehydration
3. Consider JWT stateless sessions with refresh token rotation stored in PostgreSQL
4. Add Redis health checks to ALB target groups to prevent routing to instances without cache connectivity

**References:** Lines 31, 216

---

### C-2: No Circuit Breaker for External Service Dependencies

**Location:** Section 3 (Key Components), Section 5 (API Design)

**Issue:**
The design lacks circuit breaker patterns for external service calls (Twilio, SendGrid, EHR vendor APIs). The Notification Service mentions "retries on failures" (line 93) but no failure isolation strategy exists. Without circuit breakers, slow or failing external services can exhaust thread pools and cause cascading failures.

**Impact:**
- Twilio API slowdown causing exhaustion of notification worker threads
- Blocking entire reminder processing pipeline while waiting for timeouts
- Cascading failure affecting unrelated appointment booking operations
- No automatic recovery when external services return to health

**Countermeasures:**
1. Implement Resilience4j circuit breakers for all external HTTP clients (Twilio, SendGrid, EHR APIs)
2. Configure circuit breaker thresholds (e.g., 50% error rate over 10 requests, 30-second open state)
3. Define fallback behaviors: mark notification as "failed-retry-later", skip non-critical EHR sync
4. Add bulkhead isolation using separate thread pools for external service calls
5. Configure explicit timeouts for all external API calls (e.g., 5s connect, 10s read)

**References:** Lines 37, 93, 95-96

---

### C-3: Missing Idempotency Design for Appointment Creation

**Location:** Section 5 (API Design), Section 4 (Data Model)

**Issue:**
The `POST /api/v1/appointments` endpoint (lines 138-158) lacks idempotency guarantees. If a client retries after a network timeout, duplicate appointments can be created for the same patient-provider-time combination. The data model includes no idempotency key or unique constraint to prevent duplicates.

**Impact:**
- Double-booking when clients retry failed requests (common in mobile apps with poor connectivity)
- Provider schedules showing conflicting appointments for the same time slot
- Patient confusion receiving multiple confirmation codes
- Revenue loss from duplicate appointment conflicts forcing cancellations

**Countermeasures:**
1. Add idempotency key header (`Idempotency-Key: client-generated-uuid`) to booking API
2. Store idempotency keys in database with 24-hour TTL, return cached response for duplicate keys
3. Add unique constraint: `UNIQUE(provider_id, appointment_time, duration_minutes)` to prevent slot conflicts
4. Implement optimistic locking check on provider's daily appointment count
5. Document idempotency behavior in API contract with HTTP 409 for conflicts

**References:** Lines 138-158, 103-114

---

### C-4: Nightly Batch EHR Sync Creates 24-Hour Data Inconsistency Window

**Location:** Section 3 (EHR Integration Service)

**Issue:**
EHR synchronization operates on a "nightly batch schedule" (line 96) with no real-time consistency mechanism. Appointments created/cancelled during the day are invisible to EHR systems until the next batch run, creating a 24-hour window where healthcare providers see stale data in their primary clinical systems.

**Impact:**
- Providers arriving at clinic seeing outdated schedules in EHR, missing same-day appointments
- Patient check-in failures due to appointment not existing in EHR system
- Medication history checks based on wrong appointment status
- Compliance violations if EHR is system of record for regulatory reporting

**Countermeasures:**
1. Implement near-real-time event-driven EHR sync using FHIR webhooks or message queue
2. Add status field to track EHR sync state: `PENDING_SYNC`, `SYNCED`, `SYNC_FAILED`
3. Implement compensating transaction pattern for EHR sync failures with dead letter queue
4. For critical operations (appointment creation/cancellation), require EHR sync confirmation before returning success
5. Add monitoring alert when EHR sync lag exceeds 15 minutes

**References:** Line 95-96

---

### C-5: No Database Migration Rollback or Backward Compatibility Strategy

**Location:** Section 6 (Deployment)

**Issue:**
Database migrations are executed "manually before deployment using Flyway" (line 199) with no mention of rollback procedures or backward compatibility requirements. The blue-green deployment strategy cannot roll back if migrations are incompatible with the previous application version.

**Impact:**
- Failed deployments requiring manual database schema rollback under time pressure
- Data corruption if rollback migrations are not tested
- Extended downtime if migration issues discovered after traffic cutover
- Inability to quickly revert to old application version after bad deployment

**Countermeasures:**
1. Enforce expand-contract migration pattern: all schema changes maintain backward compatibility for N-1 version
2. Implement three-phase migration process:
   - Phase 1: Add new columns/tables (compatible with old code)
   - Phase 2: Deploy new application version
   - Phase 3: Remove old columns/tables after validation period
3. Require automated rollback migration testing in CI pipeline
4. Add pre-deployment migration dry-run validation against production snapshot
5. Document maximum migration duration SLA (e.g., <5 minutes) to minimize lock windows

**References:** Line 199

---

### C-6: Undefined Appointment Conflict Resolution for Concurrent Bookings

**Location:** Section 3 (Appointment Service), Section 4 (Data Model)

**Issue:**
The design mentions "conflict detection for booking attempts" (line 87) and uses optimistic locking (version field, line 114), but does not specify the conflict resolution strategy when concurrent requests attempt to book the same provider time slot. Race conditions can lead to double-booking or inconsistent availability responses.

**Impact:**
- Two patients successfully booking the same provider time slot within milliseconds
- Provider schedule showing overlapping appointments
- Patient frustration when arriving at clinic for "confirmed" appointment that doesn't exist
- Loss of trust in system reliability

**Countermeasures:**
1. Implement pessimistic locking using PostgreSQL `SELECT FOR UPDATE` on provider's time slots during booking transaction
2. Define explicit conflict detection query: check for overlapping appointments within transaction isolation level `SERIALIZABLE`
3. Add database-level exclusion constraint using `btree_gist`: `EXCLUDE USING gist (provider_id WITH =, tsrange(appointment_time, appointment_time + duration_minutes * interval '1 minute') WITH &&)`
4. Return HTTP 409 Conflict with available alternative slots when concurrent booking detected
5. Implement short-term slot reservation pattern (hold slot for 5 minutes during booking flow)

**References:** Lines 87, 103-114

---

### C-7: No Rate Limiting Implementation for Booking Endpoints

**Location:** Section 7 (Security), Section 5 (API Design)

**Issue:**
The design specifies "API rate limiting: 100 requests/minute per user" (line 210) but provides no implementation details. The Appointment Service (lines 83-84) lacks backpressure mechanisms to protect against denial-of-service through legitimate appointment booking spam or retry storms.

**Impact:**
- Malicious user exhausting provider availability through rapid booking/cancellation cycles
- Retry storm from mobile client bug overwhelming database connection pool
- Service degradation affecting all users when single user floods booking endpoint
- Database connection pool exhaustion (20 connections per instance, line 220) leading to complete service unavailability

**Countermeasures:**
1. Implement rate limiting using Redis Sliding Window Counter pattern (not token bucket due to single Redis instance)
2. Configure tiered rate limits: 100 req/min per user, 1000 req/min per IP, 5000 req/min global
3. Add application-level queue depth monitoring with rejection at 80% capacity (fail fast)
4. Implement priority queuing: cancel operations higher priority than new bookings during overload
5. Add CAPTCHA challenge after 3 failed booking attempts to prevent automated abuse
6. Define graceful degradation strategy: disable waitlist processing when load exceeds 70% capacity

**References:** Lines 210, 83-84, 220

---

## Significant Issues

### S-1: Missing Timeout Configuration for External API Calls

**Location:** Section 3 (Notification Service, EHR Integration Service)

**Issue:**
External service integrations (Twilio, SendGrid, EHR FHIR APIs) lack explicit timeout specifications. The design mentions "retries on failures" (line 93) but undefined timeouts can cause indefinite blocking.

**Impact:**
- Worker threads blocked indefinitely waiting for unresponsive EHR API
- Notification processing halted while waiting for slow Twilio response
- RabbitMQ queue buildup as consumers hang on slow external calls

**Countermeasures:**
1. Configure explicit timeouts for all HTTP clients: 5s connection timeout, 10s read timeout
2. Implement total request deadline (30s) including retries using Resilience4j TimeLimiter
3. Add separate timeout monitoring metrics to CloudWatch
4. Define timeout-specific retry policy (don't retry 30s timeouts, only fast failures)

**References:** Lines 93, 95-96

---

### S-2: Reminder Service Polling Creates Message Duplication Risk

**Location:** Section 3 (Reminder Service)

**Issue:**
The Reminder Service "polls the database every 5 minutes" (line 90) with no mechanism to prevent duplicate reminder processing if multiple worker instances run concurrently or a worker crashes mid-processing.

**Impact:**
- Patients receiving duplicate SMS reminders for same appointment
- Unnecessary Twilio charges for duplicate message delivery
- Patient confusion and trust degradation from spam-like notifications

**Countermeasures:**
1. Add `reminder_sent_at` timestamp and status field to Appointment table: `PENDING`, `SENT`, `FAILED`
2. Use PostgreSQL `SELECT FOR UPDATE SKIP LOCKED` for distributed work claiming
3. Implement idempotency key per reminder attempt (appointment_id + scheduled_time + channel)
4. Add maximum 3 retry attempts before moving to dead letter queue
5. Switch from polling to event-driven architecture using database triggers or CDC (Debezium)

**References:** Line 90-91

---

### S-3: No Health Check Mechanism for Service Dependencies

**Location:** Section 3 (Architecture Design), Section 7 (Monitoring)

**Issue:**
The design lacks explicit health check endpoints or dependency health monitoring. ALB can route traffic to ECS tasks with failed database connections or unreachable RabbitMQ, causing user-facing errors.

**Impact:**
- ALB routing requests to instances unable to connect to PostgreSQL
- Partial service degradation appearing as random 500 errors
- Difficult troubleshooting due to intermittent failures across healthy/unhealthy instances

**Countermeasures:**
1. Implement `/health` endpoint with deep dependency checks (PostgreSQL, Redis, RabbitMQ)
2. Configure ALB target group health checks: `GET /health` with 3 consecutive successes required
3. Implement circuit breaker pattern for health check itself (don't overwhelm failed dependencies)
4. Return HTTP 503 with detailed status when critical dependencies unavailable
5. Add separate `/health/live` (process alive) and `/health/ready` (dependencies healthy) endpoints

**References:** Section 3, Section 7

---

### S-4: Waitlist Rebooking Logic Lacks Failure Handling

**Location:** Section 5 (DELETE /api/v1/appointments)

**Issue:**
Appointment cancellation "triggers waitlist rebooking logic" (line 161) with no specification of transactional boundaries or failure recovery. If rebooking fails after cancellation commits, the time slot remains empty despite waitlist demand.

**Impact:**
- Provider schedule gaps despite patients waiting for appointments
- Lost revenue from unfilled appointment slots
- Patient dissatisfaction when not rebooked despite waitlist position

**Countermeasures:**
1. Implement eventual consistency: publish cancellation event to RabbitMQ, process rebooking asynchronously
2. Store waitlist entries with position tracking and expiration time
3. Add compensation logic: if rebooking notification fails, mark slot as "available-waitlist" for retry
4. Implement saga pattern with explicit rollback for multi-step rebooking flow
5. Monitor waitlist processing lag and alert if reprocessing queue exceeds 1 hour

**References:** Lines 160-163

---

### S-5: Undefined RPO/RTO Targets and Recovery Procedures

**Location:** Section 7 (Disaster Recovery)

**Issue:**
The design mentions "Point-in-time recovery supported within backup retention window" (line 227) but provides no Recovery Point Objective (RPO) or Recovery Time Objective (RTO) targets, and no documented recovery runbook.

**Impact:**
- Undefined acceptable data loss window during disaster recovery
- No tested procedure for restoring from backups under time pressure
- Unclear accountability and escalation paths during incidents
- Potential 7-day data loss if recovery procedures are not tested

**Countermeasures:**
1. Define explicit RPO (e.g., 1 hour) and RTO (e.g., 4 hours) targets aligned with business requirements
2. Document detailed disaster recovery runbook with step-by-step procedures
3. Schedule quarterly disaster recovery drills with timed restoration exercises
4. Implement cross-region backup replication for geographic redundancy
5. Add monitoring alerts for backup age and restore test failures

**References:** Line 226-227

---

## Moderate Issues

### M-1: Missing SLO/SLA Definitions for Core Operations

**Location:** Section 7 (Non-Functional Requirements)

**Issue:**
Performance targets exist for specific operations (p95 < 500ms booking, line 204) but lack SLO/SLA definitions with error budgets, success rate targets, or availability calculations.

**Impact:**
- No objective criteria for declaring incidents or triggering escalations
- Inability to make data-driven tradeoff decisions between feature velocity and reliability
- No contractual basis for customer compensation during outages

**Countermeasures:**
1. Define SLOs for core user journeys: 99.9% success rate for appointment bookings, 99.5% reminder delivery
2. Calculate error budget: (1 - 0.999) × requests/month = allowed failed requests
3. Implement SLO alerting: trigger on-call when 50% of monthly error budget consumed
4. Document SLA terms with external customers including credits for SLO breaches

**References:** Lines 203-205

---

### M-2: Optimistic Locking Version Field Without Retry Guidance

**Location:** Section 4 (Data Model)

**Issue:**
The Appointment table includes a version field for optimistic locking (line 114) but the design does not specify retry strategy when version conflicts occur.

**Impact:**
- Client applications receiving 409 Conflict without guidance on how to retry
- Poor user experience if UI does not implement exponential backoff
- Potential infinite retry loops in poorly implemented clients

**Countermeasures:**
1. Document expected client retry behavior: exponential backoff with jitter, max 3 attempts
2. Return `Retry-After` header with suggested delay on version conflicts
3. Implement server-side retry with conflict resolution for internal service-to-service calls
4. Add CloudWatch metric tracking version conflict rate to detect contention hotspots

**References:** Line 114

---

### M-3: RabbitMQ Queue Depth Alert Threshold Lacks Response Action

**Location:** Section 7 (Scalability)

**Issue:**
The design specifies alerting "when queue size exceeds 10,000 messages" (line 221) but provides no automated response action or manual runbook for handling queue buildup.

**Impact:**
- Alert fatigue if queue depth spikes during normal operations without clear action
- Delayed response to genuine failures causing notification delays
- Unclear whether to scale consumers, throttle producers, or investigate root cause

**Countermeasures:**
1. Implement tiered alerting: warning at 5,000 messages, critical at 10,000
2. Add automatic consumer scaling trigger: add ECS tasks when queue depth > 7,500
3. Document runbook: check consumer health, verify external service status, enable producer throttling
4. Implement dead letter queue for messages exceeding 5 retry attempts

**References:** Line 221-222

---

### M-4: No Distributed Tracing for Cross-Service Request Flows

**Location:** Section 6 (Logging)

**Issue:**
Structured logging includes "request correlation IDs for tracing" (line 191) but lacks distributed tracing across asynchronous boundaries (RabbitMQ messages, background jobs).

**Impact:**
- Inability to trace end-to-end flow: appointment creation → reminder scheduled → notification sent
- Difficult debugging of notification delivery failures when correlation IDs lost at RabbitMQ boundary
- No visibility into latency distribution across service boundaries

**Countermeasures:**
1. Implement OpenTelemetry with trace context propagation across RabbitMQ message headers
2. Add trace spans for critical operations: database queries, external API calls, queue publishing
3. Configure sampling strategy: 100% for errors, 1% for successful requests
4. Integrate with AWS X-Ray or export to distributed tracing backend (Jaeger, Tempo)

**References:** Line 191

---

## Positive Aspects

1. **Optimistic Locking:** The Appointment table includes a version field (line 114), indicating awareness of concurrent modification risks.

2. **Multi-AZ Deployment:** ECS tasks run across 2 Availability Zones (line 214), providing basic infrastructure redundancy.

3. **Automated Backups:** PostgreSQL automated backups with 7-day retention (line 227) provide basic disaster recovery capability.

4. **Blue-Green Deployment:** The deployment strategy (line 199) supports zero-downtime deployments at the infrastructure level.

5. **Load Testing:** Inclusion of JMeter load testing scripts (line 196) indicates performance validation before production.

---

## Summary of Recommendations by Priority

### Immediate Action Required (Critical)
1. Deploy Redis in cluster mode with automatic failover
2. Implement circuit breakers for all external service calls
3. Add idempotency key support to appointment booking API
4. Design real-time or near-real-time EHR synchronization
5. Implement expand-contract database migration pattern
6. Add pessimistic locking or exclusion constraints for concurrent booking prevention
7. Implement multi-tier rate limiting with backpressure handling

### High Priority (Significant)
1. Configure explicit timeouts for all external HTTP clients
2. Implement distributed work claiming for reminder processing
3. Add deep health check endpoints for ALB target groups
4. Design saga pattern for waitlist rebooking with compensation
5. Define RPO/RTO targets and document disaster recovery runbook

### Medium Priority (Moderate)
1. Define SLOs with error budgets and implement SLO-based alerting
2. Document retry strategy for optimistic locking conflicts
3. Create runbooks for queue depth alerts with automated scaling
4. Implement distributed tracing with OpenTelemetry

---

## Conclusion

The MediConnect system design demonstrates foundational architectural patterns but lacks the explicit reliability engineering required for a healthcare appointment platform. The seven critical issues identified pose significant risks of data loss, service unavailability, and operational failures. Immediate attention to fault recovery mechanisms (circuit breakers, timeouts), data consistency guarantees (idempotency, conflict resolution), and single point of failure elimination (Redis clustering) is essential before production deployment.

The design would benefit from adopting industry-standard reliability patterns documented in the Site Reliability Engineering (SRE) handbook: error budgets, graceful degradation, bulkhead isolation, and comprehensive observability. Healthcare applications demand higher reliability standards due to the impact on patient care and regulatory compliance requirements.
