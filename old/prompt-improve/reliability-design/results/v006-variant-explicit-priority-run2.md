# Reliability Design Review: Smart Home Energy Management System

**Review Date**: 2026-02-11
**Reviewer**: Reliability Design Reviewer (v006-variant-explicit-priority)
**Document**: test-document-round-006.md

---

## Phase 1: Structural Analysis

### System Components
1. **API Gateway** - Request routing, JWT validation, rate limiting, WebSocket management
2. **Device Manager** - Device registration, MQTT command dispatch, state sync, firmware updates
3. **Analytics Engine** - Historical aggregation, ML predictions, recommendations, reporting
4. **MQTT Broker (AWS IoT Core)** - Device communication, topic routing, device shadows
5. **Kinesis Stream** - Event ingestion and fanout
6. **PostgreSQL + TimescaleDB** - User data, device registry, time series sensor data
7. **Redis Cluster** - Device state cache, session management

### Data Flow Paths
1. **Sensor ingestion**: Device → MQTT → Kinesis → TimescaleDB + Redis
2. **Command execution**: Mobile App → API Gateway → Device Manager → MQTT → Device
3. **Analytics queries**: Dashboard → API Gateway → Analytics Engine → TimescaleDB
4. **ML predictions**: Analytics Engine → TensorFlow → Recommendation API

### External Dependencies
- **Critical**: AWS IoT Core (MQTT), Kinesis, EKS, PostgreSQL, Redis
- **Data Sources**: Smart meters, IoT devices (sensors, actuators)
- **Client Applications**: Mobile apps, web dashboard

### Explicitly Mentioned Reliability Mechanisms
- Blue-green deployment for API Gateway and backend services
- Kubernetes rolling updates with readiness probes
- Database migrations with backward-compatible schema changes
- Canary releases for Analytics Engine (10% → 50% → 100%)
- PostgreSQL read replicas (2 replicas)
- Redis Cluster (3 master + 3 replica nodes)
- Cross-region failover (active-passive: us-east-1 primary, us-west-2 DR)
- Daily PostgreSQL backups + WAL archiving
- Redis RDB snapshots every 6 hours
- RPO: 1 hour, RTO: 4 hours
- Analytics Engine retry logic (3 attempts with exponential backoff: 1s, 2s, 4s)

---

## Phase 2: Problem Detection

### Tier 1: Critical Issues

#### C1. Distributed Transaction Consistency Violation in Command Flow
**Component**: Device Manager → MQTT → Device Command Log

**Failure Scenario**:
The command execution flow (`POST /api/v1/devices/{id}/commands`) writes to the `device_commands` table with status "pending", then publishes to MQTT. If the MQTT publish fails or times out, the database record remains in "pending" state indefinitely. There is no distributed transaction coordination (Saga, outbox pattern) to ensure atomicity between database write and MQTT publish.

**Impact Analysis**:
- User-initiated commands may silently fail without notification
- Database accumulates stale "pending" commands that never execute
- No automatic reconciliation mechanism to detect divergence between command log and actual device state
- Dead commands consume monitoring resources and complicate operational troubleshooting

**Countermeasures**:
1. **Implement Transactional Outbox Pattern**:
   - Store commands in `device_commands` table with "pending" status
   - Use separate worker process to poll pending commands and publish to MQTT
   - Update status to "sent" only after successful MQTT publish
   - Ensure idempotency by including command_id in MQTT payload

2. **Add Command Timeout and Reconciliation**:
   - Implement background job to scan commands stuck in "pending" > 60 seconds
   - Retry or mark as "failed" based on retry policy
   - Expose command status to users via WebSocket or polling endpoint

3. **Define Transaction Boundaries**:
   - Document whether commands use at-least-once or exactly-once delivery
   - Implement idempotency keys if devices may receive duplicate commands

**Reference**: Section 6 (Implementation Strategy - Error Handling), Section 5 (API Design - Device Management)

---

#### C2. Missing Circuit Breaker for Critical External Dependencies
**Component**: Device Manager → MQTT Broker, Analytics Engine → TimescaleDB

**Failure Scenario**:
All external service calls (MQTT publish, TimescaleDB queries, Kinesis writes) lack circuit breaker patterns. If MQTT Broker becomes slow (not down, just degraded), Device Manager threads will block indefinitely waiting for responses. This creates cascading failures:
- Thread pool exhaustion in Device Manager
- API Gateway request queue overflow
- WebSocket connection storm as clients retry
- Redis state cache becomes stale, causing incorrect device status displays

**Impact Analysis**:
- **Cascading failure**: Single service degradation brings down entire system
- **Resource exhaustion**: Blocked goroutines consume memory until OOM
- **User-facing impact**: Dashboard shows stale data, commands fail silently
- **Recovery complexity**: Requires manual service restarts across entire cluster

**Countermeasures**:
1. **Implement Circuit Breaker for All External Calls**:
   - Use library like `go-resilience/circuitbreaker` or `hystrix-go`
   - Configuration per dependency:
     - MQTT: 50% error rate over 10 requests → OPEN circuit for 30s
     - TimescaleDB: 30% error rate over 20 requests → OPEN circuit for 60s
     - Kinesis: 40% error rate over 15 requests → OPEN circuit for 45s

2. **Define Fallback Behaviors**:
   - **Device Manager**: Return 503 with "device service temporarily unavailable" message
   - **Analytics Engine**: Serve cached predictions from Redis (mark as stale in response)
   - **Command dispatch**: Queue commands in local database for retry when circuit closes

3. **Add Timeout Configurations**:
   - MQTT publish: 5s timeout
   - TimescaleDB query: 30s timeout
   - Kinesis PutRecords: 10s timeout
   - Document timeouts in architecture design section

**Reference**: Section 3 (Architecture Design - Component Responsibilities), Section 6 (Implementation Strategy - Error Handling)

---

#### C3. Data Loss Risk in Kinesis Stream Without DLQ
**Component**: Kinesis Stream → TimescaleDB + Redis ingestion

**Failure Scenario**:
Real-time sensor data flows through Kinesis to multiple consumers (TimescaleDB writer, Redis updater). If TimescaleDB writer encounters errors (schema validation failure, connection timeout, constraint violation), events are either:
- **Lost silently** if consumer does not implement retry logic
- **Reprocessed infinitely** if consumer retries without exponential backoff, causing Kinesis shard throttling

The design does not mention dead letter queue (DLQ) handling for poison messages.

**Impact Analysis**:
- **Data integrity violation**: Energy consumption gaps in historical database
- **Billing errors**: Incomplete consumption data leads to incorrect cost calculations
- **Analytics failures**: ML models trained on incomplete datasets produce inaccurate predictions
- **Compliance risk**: Energy utility B2B integrations may require complete audit trails

**Countermeasures**:
1. **Implement DLQ for Kinesis Consumers**:
   - Configure SQS queue as DLQ for failed events after 3 retry attempts
   - Store original event payload + error metadata + retry count
   - Build admin dashboard to inspect/reprocess DLQ messages

2. **Add Poison Message Detection**:
   - Track per-event-type error rates in Prometheus
   - If specific `device_id` causes > 10 consecutive failures, quarantine all events from that device
   - Alert operations team for manual investigation

3. **Implement Idempotent Consumers**:
   - Use `(device_id, timestamp)` as natural deduplication key in TimescaleDB
   - Add `ON CONFLICT DO NOTHING` clause to INSERT statements
   - Store Kinesis sequence numbers in consumer checkpoint table to prevent reprocessing

**Reference**: Section 3 (Data Flow), Section 4 (Data Model - Energy Consumption)

---

#### C4. Backup Restore Procedures Not Tested or Documented
**Component**: PostgreSQL + TimescaleDB, Redis

**Failure Scenario**:
While backups are configured (PostgreSQL daily full + WAL, Redis RDB snapshots every 6 hours), there is no documentation of:
- **Restore procedures** (step-by-step runbooks)
- **Restore testing cadence** (quarterly disaster recovery drills?)
- **Point-in-time recovery (PITR)** process for PostgreSQL
- **Data validation** after restore (how to verify data integrity?)

If primary database fails and team attempts DR failover to us-west-2, they may discover:
- WAL archives are corrupted or incomplete
- Restore takes 8+ hours (exceeds 4-hour RTO)
- TimescaleDB hypertable metadata is not restored correctly
- Redis RDB snapshots are missing recent writes (> 6 hour data loss)

**Impact Analysis**:
- **RTO violation**: Actual recovery time unknown until disaster occurs
- **RPO violation**: Redis 6-hour snapshot interval exceeds stated 1-hour RPO
- **Data consistency risk**: Partial restore may leave system in inconsistent state (user records present but device history missing)
- **Operational panic**: Untested runbooks fail during high-stress incident response

**Countermeasures**:
1. **Document Detailed Restore Runbooks**:
   - Step-by-step PostgreSQL PITR procedure using WAL archives
   - Redis RDB restore process with data validation steps
   - TimescaleDB hypertable verification queries
   - Cross-region DNS failover procedure

2. **Implement Quarterly DR Drills**:
   - Restore backups to isolated staging environment
   - Measure actual RTO (target: < 4 hours)
   - Validate data integrity with checksums and row counts
   - Document lessons learned and update runbooks

3. **Reduce Redis RPO**:
   - Change RDB snapshot interval to 1 hour (aligns with stated RPO)
   - Enable Redis AOF (Append-Only File) for sub-second durability
   - Document trade-off between durability and write performance

**Reference**: Section 7 (Non-functional Requirements - Disaster Recovery)

---

### Tier 2: Significant Issues

#### S1. Missing Dead Letter Queue for MQTT Command Failures
**Component**: Device Manager → MQTT Broker → Devices

**Failure Scenario**:
When Device Manager publishes commands to MQTT but receives no acknowledgment (device offline, network partition, QoS 0 message loss), the `device_command_errors` table logs the failure. However, there is no automated retry mechanism or dead letter queue for:
- Commands that fail due to transient network issues
- Commands sent to devices that are temporarily offline
- Commands that exceed maximum retry attempts

**Impact Analysis**:
- **Partial system failure**: Critical commands (e.g., emergency shutoff) may not execute
- **User experience degradation**: Users see "command sent" but device does not respond
- **Manual intervention required**: Operations team must manually identify and resend failed commands
- **No priority handling**: Urgent commands (safety-critical) treated same as routine commands (schedule adjustment)

**Countermeasures**:
1. **Implement MQTT Command DLQ**:
   - Create SQS queue for commands that fail after 3 automatic retry attempts
   - Store command metadata: `device_id`, `command_type`, `payload`, `retry_count`, `last_error`
   - Build admin UI to view/reprocess DLQ commands

2. **Add Retry Logic with Exponential Backoff**:
   - Retry failed MQTT publishes: 1s, 5s, 15s intervals
   - Use exponential backoff with jitter to prevent thundering herd
   - Stop retrying after 3 attempts and move to DLQ

3. **Implement Command Priority Queue**:
   - Add `priority` field to `device_commands` table (HIGH, NORMAL, LOW)
   - Process HIGH priority commands first in retry queue
   - Define command timeout TTL (e.g., discard stale commands after 5 minutes)

**Reference**: Section 6 (Implementation Strategy - Error Handling), Section 4 (Data Model - Device Command Log)

---

#### S2. Single Point of Failure in Analytics Engine
**Component**: Analytics Engine

**Failure Scenario**:
The architecture diagram shows Analytics Engine as a single component without explicit redundancy. If this service crashes, experiences memory leaks, or gets overwhelmed by expensive ML inference requests:
- **Historical analytics unavailable**: Dashboard cannot display consumption trends
- **Prediction API fails**: Optimization recommendations do not generate
- **Report generation stops**: Scheduled daily/weekly reports fail to send
- **No automatic recovery**: Kubernetes may restart pod, but requires manual investigation if crashes persist

**Impact Analysis**:
- **Service degradation**: Core product feature (analytics/predictions) becomes unavailable
- **User churn risk**: Homeowners cannot view energy insights during peak usage hours
- **B2B impact**: Energy utility provider integrations fail SLA commitments
- **Recovery time**: Manual debugging and redeployment required (estimated 30-60 minutes)

**Countermeasures**:
1. **Deploy Multiple Analytics Engine Replicas**:
   - Run 3+ replicas behind load balancer
   - Configure Kubernetes HPA to scale based on:
     - CPU utilization (target 70%)
     - Request queue depth (scale up if > 100 pending requests)
     - P95 latency (scale up if > 2s)

2. **Implement Health Checks at Multiple Levels**:
   - **Liveness probe**: HTTP GET `/health` endpoint (5s interval)
   - **Readiness probe**: Verify TimescaleDB connection + Redis cache hit (10s interval)
   - **Startup probe**: Wait for ML model loading (60s timeout)

3. **Add Bulkhead Isolation for ML Inference**:
   - Separate thread pool for TensorFlow model execution (max 10 concurrent)
   - If ML pool saturates, serve cached predictions from Redis (with staleness indicator)
   - Implement timeout for ML inference (5s max, fallback to historical average)

**Reference**: Section 3 (Architecture Design - Component Responsibilities), Section 7 (Performance Goals)

---

#### S3. Zero-Downtime Deployment Risk for Database Schema Changes
**Component**: PostgreSQL + TimescaleDB schema migrations

**Failure Scenario**:
The design mentions "backward-compatible schema changes" but does not specify the expand-contract pattern for rolling deployments. If a schema migration adds a new NOT NULL column without a default value:
1. **Deploy Phase 1**: New application code expects column to exist
2. **Migration applies**: Existing rows violate NOT NULL constraint
3. **Old pods still running**: Cannot INSERT new rows (constraint violation)
4. **Rollback required**: Database migration must be manually reverted

This breaks the blue-green deployment strategy and causes production downtime.

**Impact Analysis**:
- **Deployment failure**: Rolling update halts mid-deployment
- **Data integrity risk**: Inconsistent application behavior between old/new pods
- **Manual intervention required**: Database administrator must fix schema and data
- **Extended downtime**: 15-30 minutes while troubleshooting and rolling back

**Countermeasures**:
1. **Enforce Expand-Contract Migration Pattern**:
   - **Phase 1 (Expand)**: Add new column as NULLABLE or with DEFAULT value
   - **Deploy application**: Code reads from new column, writes to both old and new
   - **Phase 2 (Backfill)**: Background job migrates data from old to new column
   - **Phase 3 (Contract)**: Remove old column in separate migration after full rollout

2. **Add Pre-Deployment Migration Validation**:
   - Run migrations in staging environment with production-like data volume
   - Use Flyway validate command in CI/CD pipeline
   - Require database change approval from DBA before production deployment

3. **Implement Schema Compatibility Testing**:
   - Automated tests verify old application code works with new schema
   - Automated tests verify new application code works with old schema
   - Gate deployment on passing compatibility matrix

**Reference**: Section 6 (Implementation Strategy - Deployment)

---

#### S4. Rate Limiting Insufficient for Abuse and Cascade Failure Prevention
**Component**: API Gateway

**Failure Scenario**:
API Gateway implements rate limiting at 1000 req/min per user, but lacks:
- **Global rate limits** to prevent total system overload (e.g., 100k req/min across all users)
- **Endpoint-specific limits** for expensive operations (analytics queries cost 100x more than device status checks)
- **Backpressure signaling** to downstream services when approaching capacity
- **429 retry guidance** in error responses (Retry-After header)

If a B2B energy utility integration misconfigures polling interval and sends 10,000 req/sec:
- Per-user limit (1000/min = 16.6/sec) is ineffective against distributed attack from 1000+ users
- Analytics Engine becomes overwhelmed by expensive queries
- Other users experience degraded performance (noisy neighbor problem)

**Impact Analysis**:
- **Partial system failure**: Analytics Engine CPU saturation causes timeouts
- **Resource exhaustion**: Database connection pool depleted by concurrent queries
- **User-facing impact**: Legitimate users receive 503 errors due to noisy neighbor
- **No self-healing**: System does not automatically shed load or throttle bad actors

**Countermeasures**:
1. **Implement Multi-Tier Rate Limiting**:
   - **Per-user**: 1000 req/min (existing)
   - **Per-endpoint**: Analytics queries limited to 10 req/min per user
   - **Global**: 100,000 req/min across all users (shed excess load with 503)
   - **IP-based**: 5000 req/min per source IP (defense against distributed scripts)

2. **Add Backpressure Mechanism**:
   - API Gateway checks Analytics Engine queue depth before routing requests
   - If queue > 200, return 503 with Retry-After: 30 header
   - Implement token bucket algorithm for smooth rate limiting (not fixed window)

3. **Define Rate Limit Response Format**:
   ```json
   {
     "error": "rate_limit_exceeded",
     "message": "Exceeded 10 analytics requests per minute",
     "retry_after": 30,
     "limit": 10,
     "remaining": 0,
     "reset": "2026-02-11T10:35:00Z"
   }
   ```

**Reference**: Section 3 (Component Responsibilities - API Gateway), Section 7 (Performance Goals)

---

### Tier 3: Moderate Issues

#### M1. Missing SLO/SLA Definitions with Error Budget
**Component**: System-wide

**Failure Scenario**:
The design specifies performance targets (p95 < 200ms, 99.9% uptime) but lacks:
- **Formal SLO definitions** (Service Level Objectives) with measurement methodology
- **Error budget allocation** (how much downtime/errors are acceptable per month?)
- **SLI tracking** (Service Level Indicators) in monitoring dashboards
- **Alerting thresholds** tied to SLO burn rate (when to wake up on-call engineer?)

Without SLOs, the team cannot prioritize reliability work vs. new features. If uptime drops to 99.8% (35 minutes downtime), is this acceptable or a crisis?

**Impact Analysis**:
- **Operational ambiguity**: No objective criteria for "production is healthy"
- **Incident response confusion**: Unclear when to escalate vs. defer to business hours
- **Reliability regression**: No early warning system for gradual degradation
- **Stakeholder misalignment**: Engineering and product teams have different expectations

**Countermeasures**:
1. **Define Formal SLOs for Critical User Journeys**:
   - **Device command execution**: 99.5% success rate (measured as commands acknowledged by device within 5s)
   - **Analytics dashboard load**: 99.9% availability, p95 < 2s latency
   - **Real-time data ingestion**: 99.9% of sensor events ingested within 10s
   - **API Gateway**: p95 latency < 200ms, p99 < 500ms

2. **Calculate Error Budgets**:
   - **Example**: 99.9% uptime = 43 minutes downtime/month
   - Track budget consumption in Grafana dashboard
   - If budget exhausted, freeze feature launches until reliability improves

3. **Implement SLO-Based Alerting**:
   - **Fast burn alert** (page immediately): 5% error budget consumed in 1 hour
   - **Slow burn alert** (ticket for next business day): 10% error budget consumed in 24 hours
   - Use Prometheus recording rules for efficient SLI calculation

**Reference**: Section 7 (Non-functional Requirements - Performance Goals, Availability & Scalability)

---

#### M2. Incident Response Runbooks and Escalation Procedures Missing
**Component**: Operational processes

**Failure Scenario**:
When production incidents occur (database failover, MQTT broker outage, Analytics Engine crash), the design does not specify:
- **Incident response runbooks** (step-by-step troubleshooting guides)
- **Escalation procedures** (when to wake up senior engineer vs. CTO?)
- **Communication templates** (how to notify users during outages?)
- **Postmortem process** (blameless retrospectives? action item tracking?)

If MQTT broker fails at 2 AM on Saturday, on-call engineer may:
- Spend 45 minutes finding AWS IoT Core dashboard URL
- Unsure whether to failover to DR region (us-west-2) or restart service
- Not know how to communicate status to users (email? in-app banner?)

**Impact Analysis**:
- **Extended MTTR** (Mean Time To Repair): Lack of runbooks increases diagnosis time
- **Escalation delays**: On-call engineer unsure when to involve senior staff
- **User trust erosion**: Silent failures without status page updates
- **Repeat incidents**: Lack of postmortem process means same issues recur

**Countermeasures**:
1. **Create Incident Response Runbooks**:
   - **Database Failover**: Step-by-step PostgreSQL PITR + DNS update
   - **MQTT Broker Outage**: AWS IoT Core health check + device reconnection verification
   - **Analytics Engine Crash Loop**: Common causes (OOM, DB connection leak) + mitigation steps
   - **Kinesis Stream Lag**: Identify bottleneck consumer + manual scaling procedure

2. **Define Escalation Policy**:
   - **Severity 1** (system-wide outage): Page on-call + engineering manager immediately
   - **Severity 2** (partial degradation): On-call handles, escalate if unresolved in 30 minutes
   - **Severity 3** (performance degradation): Create ticket for next business day
   - Document on-call rotation schedule and contact information

3. **Implement Blameless Postmortem Process**:
   - All Severity 1/2 incidents require postmortem document within 48 hours
   - Template: Timeline, Root Cause, Impact, Action Items with DRI (Directly Responsible Individual)
   - Review action items weekly in engineering team meeting

**Reference**: Section 7 (Non-functional Requirements - Availability & Scalability)

---

#### M3. Capacity Planning and Resource Quota Gaps
**Component**: Kubernetes HPA, PostgreSQL, Redis, Kinesis

**Failure Scenario**:
The design mentions autoscaling based on CPU utilization (target 70%) but lacks:
- **Load testing results** to validate capacity assumptions (k6 load tests mentioned but no results documented)
- **Resource quotas** per namespace/pod (CPU/memory limits)
- **Kinesis shard capacity planning** (100k events/sec requires how many shards?)
- **Database connection pool sizing** (how many concurrent connections per service?)
- **Redis memory capacity planning** (device state cache size estimation?)

If the system launches and onboards 10x expected users (100k devices instead of 10k):
- Kinesis shards throttle (1MB/sec or 1000 records/sec per shard limit)
- PostgreSQL connection pool exhausted (default 100 connections)
- Redis memory full, triggers eviction of active device states
- Kubernetes pods OOM-killed due to missing memory limits

**Impact Analysis**:
- **Sudden capacity cliff**: System fails at 10x scale without warning
- **Resource contention**: Services starve each other (Analytics Engine consumes all database connections)
- **Unpredictable costs**: AWS bill spikes due to unplanned autoscaling
- **Operational firefighting**: Team reactively adds resources during production incident

**Countermeasures**:
1. **Conduct Load Testing with Documented Results**:
   - Use k6 to simulate 10k, 50k, 100k concurrent users
   - Measure breaking points for each component (database, Redis, Kinesis)
   - Document findings: "System supports 50k devices with current configuration, requires 10 Kinesis shards for 100k"

2. **Define Resource Quotas and Limits**:
   - **Kubernetes pods**: Set CPU limit (1 core), memory limit (2GB) for each service
   - **PostgreSQL**: Connection pool per service (API Gateway: 50, Analytics: 30, Device Manager: 20)
   - **Redis**: Set maxmemory limit (16GB) with `allkeys-lru` eviction policy
   - **Kinesis**: Start with 5 shards, autoscale based on incoming data rate

3. **Implement Capacity Monitoring and Alerts**:
   - **Kinesis shard utilization**: Alert if > 80% of shard capacity
   - **Database connections**: Alert if > 80% of pool used
   - **Redis memory**: Alert if > 90% of maxmemory
   - Create capacity planning spreadsheet with growth projections (quarterly review)

**Reference**: Section 7 (Non-functional Requirements - Performance Goals, Availability & Scalability)

---

#### M4. Distributed Tracing for Production Debugging Not Fully Specified
**Component**: Logging and observability

**Failure Scenario**:
The design mentions "correlation IDs for distributed tracing" but lacks:
- **Trace propagation mechanism** (W3C Trace Context headers? OpenTelemetry?)
- **Trace storage backend** (Jaeger? AWS X-Ray? Tempo?)
- **Sampling strategy** (trace 100% of requests? 1%? Dynamic sampling?)
- **Trace retention period** (7 days? 30 days?)

When debugging production issue "User reports device command took 5 minutes to execute", engineer cannot:
- Trace request through API Gateway → Device Manager → MQTT → Kinesis → Redis
- Identify which service introduced latency (database slow query? MQTT timeout?)
- Correlate logs across multiple services for single user request

**Impact Analysis**:
- **Extended MTTR**: Debugging distributed system issues requires manual log correlation
- **Customer support friction**: Cannot provide detailed explanation for user-reported issues
- **Performance regression blindness**: Gradual latency increases not detected until users complain
- **Operational overhead**: Engineers waste hours manually stitching together logs from CloudWatch

**Countermeasures**:
1. **Implement Full Distributed Tracing Stack**:
   - **Library**: OpenTelemetry SDKs for Go and React
   - **Propagation**: W3C Trace Context headers (traceparent, tracestate)
   - **Backend**: AWS X-Ray or self-hosted Jaeger
   - **Sampling**: 100% for errors, 10% for successful requests, dynamic sampling if > 10k req/sec

2. **Instrument Critical Code Paths**:
   - API Gateway: Create root span for incoming requests
   - Device Manager: Create child span for MQTT publish
   - Analytics Engine: Create span for database queries + ML inference
   - MQTT Bridge: Propagate trace context in MQTT message metadata

3. **Define Trace Retention and Access Policies**:
   - Store traces for 14 days (balance between cost and debugging needs)
   - Create Grafana dashboard with "slow request" traces (p99 latency > 1s)
   - Build Slack alert for traces with errors (auto-post to #incidents channel)

**Reference**: Section 6 (Implementation Strategy - Logging)

---

## Summary

### Critical Issues Requiring Immediate Attention (Tier 1)
The design has **4 critical reliability gaps** that could cause system-wide failures or data loss:
1. Distributed transaction consistency violation in command flow (no outbox pattern)
2. Missing circuit breakers for MQTT, TimescaleDB, Kinesis calls (cascading failure risk)
3. Data loss risk in Kinesis ingestion without DLQ (energy consumption gaps)
4. Untested backup/restore procedures (RTO/RPO violations during actual disaster)

### Significant Issues Requiring Design Changes (Tier 2)
**4 significant issues** that impact partial system availability:
1. Missing DLQ for MQTT command failures (critical commands may not execute)
2. Single point of failure in Analytics Engine (no redundancy)
3. Zero-downtime deployment risk for schema migrations (missing expand-contract pattern)
4. Insufficient rate limiting (no protection against noisy neighbor or global overload)

### Moderate Issues for Operational Improvement (Tier 3)
**4 moderate issues** to improve operational maturity:
1. Missing SLO/SLA definitions with error budgets (no objective health metrics)
2. No incident response runbooks or escalation procedures (extended MTTR)
3. Capacity planning gaps (no documented load testing results, resource quotas)
4. Distributed tracing not fully specified (limited production debugging capability)

### Overall Assessment
The design demonstrates solid understanding of basic reliability mechanisms (backups, replicas, failover) but **lacks defense-in-depth for distributed system failures**. The absence of circuit breakers, DLQs, and transaction patterns creates significant risk of cascading failures and data inconsistencies. Recommend prioritizing Tier 1 issues before production launch.
