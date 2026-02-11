# Reliability Design Review: IoT Device Management Platform

## Critical Issues

### C-1: Kafka Streams State Store Recovery Not Designed
**Severity: Critical**

**Issue:**
The Stream Processing Service using Kafka Streams (section 3) lacks explicit design for state store recovery and changelog topic configuration. When processing node failures occur, state reconstruction timing and completeness are undefined.

**Impact:**
- Potential data loss during state store recovery if changelog topics are not properly configured
- Undefined recovery time may violate the P95 < 500ms API response SLO during failover
- Anomaly detection logic may produce inconsistent results during state reconstruction

**Countermeasure:**
- Define changelog topic replication factor (minimum 3) and retention policies
- Specify state store recovery behavior and expected RTO
- Design graceful degradation: disable anomaly detection during state reconstruction or use last-known-good state
- Document standby replica configuration for faster failover

**Reference:** Section 3 "Stream Processing Service"

---

### C-2: TimescaleDB Write Path Has No Fault Isolation
**Severity: Critical**

**Issue:**
The data flow (section 3, step 4) shows Kafka Streams writing directly to TimescaleDB with no circuit breaker, timeout specification, or backpressure handling. Database unavailability or slow writes will block stream processing.

**Impact:**
- Single database issue cascades to entire ingestion pipeline (100,000 msg/sec stalls)
- Kafka Streams consumer lag accumulates, potentially triggering rebalancing
- No mechanism to preserve data during extended TimescaleDB outages

**Countermeasure:**
- Implement circuit breaker pattern (Resilience4j) with half-open retry strategy
- Define write timeout (e.g., 3 seconds) and failure handling
- Add dead-letter queue (DLQ) for failed writes to prevent data loss
- Consider buffering layer (e.g., separate Kafka topic) for decoupling

**Reference:** Section 3 "Data Flow" step 4, Section 2 mentions Resilience4j but usage is not specified

---

### C-3: Firmware Update Rollback Lacks Atomicity Guarantee
**Severity: Critical**

**Issue:**
The Firmware Update Service mentions rollback functionality (section 3) but does not specify how partial rollback failures are handled. The `device_update_status` table (section 4) tracks status per device but has no transaction coordination mechanism.

**Impact:**
- Inconsistent fleet state if rollback succeeds on some devices but fails on others
- No clear recovery path if devices become unreachable during rollback
- Potential for devices stuck in intermediate states with incompatible firmware/configuration

**Countermeasure:**
- Define rollback workflow with explicit timeout windows
- Implement compensation logic for partial rollback failures (e.g., retry queue, manual intervention flag)
- Add `rollback_attempt_count` and `max_rollback_attempts` to track exhausted retries
- Design health check to detect firmware/backend version mismatches after rollback

**Reference:** Section 3 "Firmware Update Service", Section 4 `device_update_status` table

---

### C-4: Single-Region Deployment Creates Data Loss Risk
**Severity: Critical**

**Issue:**
The infrastructure design (section 2) specifies only `ap-northeast-1` region with no multi-region failover, backup strategy, or disaster recovery plan. RPO/RTO are undefined.

**Impact:**
- Regional outage causes complete service unavailability (violates 99.9% SLA - 43 min/month)
- No mechanism to recover device state, firmware update progress, or time-series data
- Devices may continue sending data with no ingestion endpoint during outage

**Countermeasure:**
- Define RPO (e.g., 5 minutes) and RTO (e.g., 1 hour) targets
- Implement cross-region RDS replication for PostgreSQL (async is acceptable for metadata)
- Configure S3 cross-region replication for firmware packages
- Document failover procedures including DNS/MQTT endpoint updates
- Consider active-active architecture for Kafka (MirrorMaker 2) if RPO < 5 min is required

**Reference:** Section 2 "Infrastructure", Section 7 "Availability" (99.9% target)

---

## Significant Issues

### S-1: PostgreSQL Connection Pool Exhaustion Not Mitigated
**Severity: Significant**

**Issue:**
The Device Management API and Kafka Streams both write to PostgreSQL (section 3) with no connection pool sizing, timeout, or bulkhead isolation specified. A slow query or connection leak will starve other components.

**Impact:**
- API requests fail with connection timeout during database contention
- Kafka Streams processing stalls if metadata writes (e.g., device `last_seen_at` updates) block
- Partial system outage difficult to diagnose without clear fault boundaries

**Countermeasure:**
- Define separate connection pools for API (e.g., 20 connections) and Kafka Streams (e.g., 10)
- Configure connection timeout (e.g., 30s), query timeout (e.g., 10s), and leak detection
- Implement bulkhead pattern: isolate critical paths (device registration) from read-heavy queries
- Add metric: `db_connection_pool_utilization` with alerting at 80%

**Reference:** Section 3 "Backend API" → PostgreSQL interaction

---

### S-2: MQTT Broker Failure Behavior Undefined
**Severity: Significant**

**Issue:**
AWS IoT Core is shown as a single component (section 3) with no specification of device retry behavior, queuing limits, or fallback when the broker is unavailable.

**Impact:**
- Device firmware may not implement exponential backoff, causing thundering herd on recovery
- No visibility into message loss if devices abandon retries
- Undefined whether devices buffer data locally during outage (potential data gap)

**Countermeasure:**
- Specify device-side retry policy: exponential backoff (e.g., 1s → 2s → 4s, max 5 minutes)
- Define device local buffer size (e.g., 1 hour of data) and overflow behavior
- Add device-side metrics for "messages dropped due to broker unavailability"
- Consider MQTT persistent sessions for QoS 1+ delivery guarantees

**Reference:** Section 3 "Device Ingestion Service"

---

### S-3: Redis Cache Failure Degrades to Unspecified Behavior
**Severity: Significant**

**Issue:**
Redis is shown in the architecture (section 3) but has no defined role, cache-miss handling strategy, or behavior when Redis is unavailable.

**Impact:**
- If used for session storage: user re-authentication required, disrupting operations
- If used for read-through cache: undefined latency impact when falling back to PostgreSQL
- No specification of cache invalidation strategy may lead to stale data

**Countermeasure:**
- Explicitly document Redis usage (e.g., device metadata cache, session store)
- Implement circuit breaker: fail open to PostgreSQL after 3 consecutive Redis timeouts
- Define cache TTL and invalidation events (e.g., device update → invalidate cache)
- Add metric: `redis_fallback_rate` to detect degraded mode

**Reference:** Section 3 architecture diagram includes Redis but usage not specified

---

### S-4: JWT Token Revocation Mechanism Missing
**Severity: Significant**

**Issue:**
API authentication uses JWT with 24-hour expiration (section 5) but no revocation mechanism is described. Compromised tokens remain valid until expiration.

**Impact:**
- Compromised admin token can issue firmware updates or delete devices for up to 24 hours
- No ability to invalidate sessions during incident response
- RBAC changes (e.g., role downgrade) do not take effect until token refresh

**Countermeasure:**
- Implement token revocation list (Redis-backed, TTL = token expiration time)
- Reduce token lifetime to 1 hour with refresh token pattern
- Add "last password change timestamp" claim to force re-authentication on credential rotation
- Document emergency revocation procedure (e.g., rotate signing key)

**Reference:** Section 5 "Authentication"

---

### S-5: Kafka Consumer Group Rebalancing Impact Not Addressed
**Severity: Significant**

**Issue:**
Kafka Streams Processor (section 3) has no specification for partition assignment strategy, rebalancing timeout, or processing guarantees during scaling events.

**Impact:**
- During deployment or autoscaling, rebalancing may cause processing lag spikes
- Exactly-once semantics may be violated if transactions are not properly configured
- Duplicate anomaly alerts may fire during rebalancing if idempotency is not enforced

**Countermeasure:**
- Enable exactly-once semantics (`processing.guarantee=exactly_once_v2`)
- Configure `max.poll.interval.ms` to accommodate slow processing (e.g., 5 minutes)
- Implement graceful shutdown: drain current records before pod termination (k8s `preStop` hook)
- Add metric: `kafka_rebalance_duration` to detect prolonged disruptions

**Reference:** Section 3 "Stream Processing Service"

---

## Moderate Issues

### M-1: No Specification for Idempotent Firmware Update Status Writes
**Severity: Moderate**

**Issue:**
The `device_update_status` table (section 4) has no unique constraint or idempotency key. Retried status updates may create inconsistent state.

**Impact:**
- Retry logic (e.g., Resilience4j) may write duplicate `started_at` timestamps
- Race conditions if multiple update attempts are tracked simultaneously
- Operational confusion when auditing update history

**Countermeasure:**
- Add unique constraint on `(device_id, update_id, status)` or use upsert semantics
- Include idempotency key in update requests (e.g., `request_id UUID`)
- Design status transitions as state machine: only allow valid transitions (e.g., `pending` → `in_progress` → `completed`)

**Reference:** Section 4 `device_update_status` table

---

### M-2: TimescaleDB Retention Policy Not Automated
**Severity: Moderate**

**Issue:**
Data retention (section 7) specifies 90-day hot data and 2-year cold data, but no automated job or policy is described. Manual execution introduces operational risk.

**Impact:**
- Disk exhaustion if retention job is forgotten
- Operational burden and inconsistent execution timing
- Potential compliance issues if data is retained beyond legal requirements

**Countermeasure:**
- Implement TimescaleDB retention policy: `SELECT add_retention_policy('sensor_measurements', INTERVAL '90 days');`
- Configure S3 lifecycle policy for automatic archival
- Add monitoring: `table_size_bytes` metric with alerting
- Document restore procedure for archived data

**Reference:** Section 7 "Data retention period"

---

### M-3: Deployment Rollback Procedure Not Documented
**Severity: Moderate**

**Issue:**
Section 6 specifies Kubernetes Rolling Update but does not describe rollback triggers, validation checks, or database migration rollback compatibility.

**Impact:**
- Unclear decision criteria for aborting deployment
- Database schema changes may prevent rollback (forward-only migrations)
- Prolonged incident if rollback is attempted manually without tested procedure

**Countermeasure:**
- Define rollback triggers: error rate > 5%, P95 latency > 2x baseline, health check failures
- Implement automated rollback in CI/CD pipeline (e.g., GitHub Actions abort condition)
- Enforce backward-compatible migrations: new code must support N-1 schema
- Add smoke tests as deployment gate (e.g., Kubernetes readiness probe with /health endpoint)

**Reference:** Section 6 "Deployment strategy"

---

### M-4: No SLO Definition for Device Data Ingestion Lag
**Severity: Moderate**

**Issue:**
Performance targets (section 7) specify throughput (100,000 msg/sec) but not end-to-end latency from device send to TimescaleDB write.

**Impact:**
- Anomaly detection may trigger late if processing lag is unbounded
- Dashboard displays stale data without visible indicator
- Difficult to diagnose whether delays are due to network, Kafka, or stream processing

**Countermeasure:**
- Define SLO: P95 ingestion lag < 5 seconds (device timestamp to DB write)
- Implement watermark tracking: embed device timestamp in messages
- Add metric: `ingestion_lag_seconds` with alerting at P95 > 10s
- Display "data freshness" indicator on dashboard

**Reference:** Section 7 "Performance goals"

---

### M-5: Health Check Endpoint Not Designed
**Severity: Moderate**

**Issue:**
Section 8 mentions monitoring infrastructure and application metrics but does not specify health check endpoints for Kubernetes liveness/readiness probes.

**Impact:**
- Failed containers may remain in rotation, serving errors
- Deployment may proceed even if new pods cannot connect to dependencies
- Difficult to distinguish "pod starting up" from "pod healthy but overloaded"

**Countermeasure:**
- Design `/health/live` (liveness): returns 200 if JVM is running
- Design `/health/ready` (readiness): checks PostgreSQL, Redis, Kafka connectivity with 5s timeout
- Configure Kubernetes probes: `initialDelaySeconds=30, periodSeconds=10, failureThreshold=3`
- Add `/health/metrics` exposing Micrometer data for scraping

**Reference:** Section 8 "Monitoring" does not mention health checks

---

## Minor Improvements

### I-1: Structured Logging Does Not Specify Trace Context
**Severity: Minor**

**Issue:**
Section 6 specifies structured JSON logging but does not mention distributed tracing (trace ID, span ID) for correlating logs across services.

**Impact:**
- Difficult to trace request flow from API → Kafka → TimescaleDB
- Increased MTTR during multi-component incidents

**Recommendation:**
- Integrate OpenTelemetry or similar (e.g., Spring Cloud Sleuth)
- Inject trace context into Kafka message headers for end-to-end correlation
- Include `trace_id` in all log entries

**Reference:** Section 6 "Logging"

---

### I-2: No Mention of Rate Limiting for API Endpoints
**Severity: Minor**

**Issue:**
API design (section 5) does not specify rate limiting policies to protect against abusive clients or runaway scripts.

**Impact:**
- Bulk operations (e.g., device registration) may starve other users
- Unintentional DoS from buggy client code

**Recommendation:**
- Implement token bucket rate limiting (e.g., 100 req/min per user, 1000 req/min globally)
- Return HTTP 429 with `Retry-After` header
- Design separate limits for read vs. write operations

**Reference:** Section 5 API design

---

## Positive Aspects

1. **Resilience4j library included**: Section 2 lists Resilience4j, indicating awareness of fault tolerance patterns (implementation details needed)
2. **Structured monitoring approach**: Section 8 defines clear alert severity levels (P1/P2/P3) and escalation paths
3. **Comprehensive test strategy**: Section 6 includes unit, integration, and E2E tests with specific tools
4. **Security fundamentals**: TLS encryption, certificate-based device authentication, and JWT are properly specified
5. **Time-series optimization**: TimescaleDB with appropriate indexing (`idx_device_time`) shows understanding of query patterns
