# Reliability Design Review: Smart Home Energy Management System

**Review Date**: 2026-02-11
**Reviewer Profile**: Reliability Engineer (Fault Tolerance, Operational Readiness, Production System Design)
**Document Version**: System Design Document v1.0

---

## Phase 1: Structural Analysis

### System Components Inventory
1. **API Gateway** (Go) - Request routing, JWT validation, rate limiting, WebSocket management
2. **Device Manager** (Go) - Device registration, MQTT command dispatch, state sync (Redis), firmware updates
3. **Analytics Engine** (Go) - Historical aggregation, ML model execution, recommendations, reporting
4. **MQTT Broker** (AWS IoT Core) - Bidirectional device communication, topic routing, device shadows
5. **Kinesis Stream** - Real-time event ingestion and fanout
6. **PostgreSQL 15 + TimescaleDB** - Primary database for user data, device registry, time-series sensor data
7. **Redis 7.0 Cluster** - Real-time device state, session management
8. **Mobile App & Web Dashboard** - User interfaces

### Data Flow Paths
- **Real-time Sensor Data**: Device → MQTT → Kinesis → TimescaleDB + Redis
- **User Command**: Mobile App → API Gateway → Device Manager → MQTT → Device
- **Analytics Query**: Web Dashboard → API Gateway → Analytics Engine → TimescaleDB
- **Prediction**: Analytics Engine → TensorFlow Model → Recommendation API

### External Dependencies (Criticality)
- **Critical**: AWS IoT Core (MQTT), PostgreSQL, Redis (all real-time operations depend on these)
- **High**: Kinesis (event streaming), TimescaleDB (analytics queries)
- **Medium**: CloudWatch Logs (logging), S3 (backups)

### Explicitly Mentioned Reliability Mechanisms
- Rate limiting (1000 req/min per user)
- Retry logic: Analytics Engine retries failed DB queries 3x with exponential backoff (1s, 2s, 4s)
- Deployment: Blue-green for API Gateway/backend, rolling updates with readiness probes, canary for Analytics Engine
- Backup: PostgreSQL daily full + WAL archiving, Redis RDB snapshots every 6h
- DR: Active-passive (us-east-1 primary, us-west-2 DR), RPO 1h, RTO 4h
- Auto-scaling: Kubernetes HPA at 70% CPU
- Read replicas: 2 PostgreSQL replicas for analytics queries
- Redis Cluster: 3 master + 3 replica nodes

---

## Phase 2: Problem Detection (Organized by Severity)

---

## TIER 1: CRITICAL ISSUES (System-Wide Impact)

### 1. Missing Idempotency Design for Device Commands (Critical)

**Issue Description**:
The device command API (`POST /api/v1/devices/{id}/commands`) lacks idempotency guarantees. The design shows a `device_commands` table tracking command status (`pending`, `sent`, `acked_at`), but there is no mechanism to prevent duplicate command execution if:
- The client retries due to network timeout (command was sent to device but acknowledgment lost)
- The Device Manager crashes after sending MQTT message but before updating database
- MQTT message is delivered multiple times (MQTT QoS 1 allows duplicate delivery)

**Failure Scenario**:
A user sends a command to turn on a high-power device (e.g., water heater). The API responds with a timeout. The mobile app retries. The device receives two commands and executes both. In the worst case:
- Financial impact: Double execution of expensive operations (e.g., preheating twice)
- Safety impact: Repeated on/off cycles could damage equipment or violate safety constraints
- User trust: Unpredictable behavior erodes confidence in the system

**Operational Impact**: High - Affects all device control operations, core system functionality

**Countermeasures**:
1. **Add idempotency keys**: Require clients to provide a unique `idempotency_key` (UUID) with each command. Store in `device_commands` table with a unique constraint.
2. **Command deduplication**: Device Manager checks if a command with the same idempotency key already exists. If status is `sent` or `acked`, return the existing command_id instead of creating a new record.
3. **MQTT QoS 1 with device-side deduplication**: Devices should maintain a sliding window of recently executed command IDs (e.g., last 100 commands) and ignore duplicates.
4. **Timeout semantics**: Document that API Gateway timeout does NOT mean command failed—clients must poll `/api/v1/devices/{id}/commands/{command_id}` to check final status before retrying.

**Reference**: Section 5 (API Design) - `POST /api/v1/devices/{id}/commands`

---

### 2. No Circuit Breaker Pattern for External Dependencies (Critical)

**Issue Description**:
The design does not specify circuit breakers for any external service calls:
- Device Manager → MQTT Broker (AWS IoT Core)
- Analytics Engine → PostgreSQL/TimescaleDB
- API Gateway → Device Manager / Analytics Engine (inter-service calls)
- All components → Redis

When an external dependency becomes slow or unavailable, the system is vulnerable to:
- **Thread pool exhaustion**: All worker threads block waiting for timeouts
- **Cascading failures**: Slow database queries cause API Gateway request queue buildup, leading to memory exhaustion
- **Amplified load**: Retries without backoff multiply the load on an already-struggling service

**Failure Scenario**:
PostgreSQL experiences a query lock contention issue, causing all queries to take 30+ seconds. The Analytics Engine's retry logic (3 attempts with exponential backoff) means each request holds resources for up to 60 seconds. With 10,000 concurrent users requesting analytics:
1. API Gateway exhausts connection pool to Analytics Engine
2. WebSocket connections start timing out, triggering mobile app reconnections
3. Reconnection storm amplifies load on API Gateway
4. System enters a death spiral requiring manual intervention to recover

**Operational Impact**: Critical - Single component failure can trigger system-wide cascading failure

**Countermeasures**:
1. **Implement circuit breakers** (use library like `sony/gobreaker` for Go):
   - Wrap all external calls: PostgreSQL, Redis, MQTT, Kinesis, inter-service HTTP
   - Configure failure thresholds (e.g., 50% error rate over 10 seconds → open circuit)
   - Half-open state: Test recovery with limited traffic before fully closing circuit
2. **Timeout configurations**: Explicitly define and document timeouts for every external call:
   - PostgreSQL query timeout: 5s (analytics queries), 1s (transactional queries)
   - Redis operations: 500ms
   - MQTT publish: 2s
   - HTTP inter-service calls: 3s
3. **Bulkhead isolation**: Separate thread pools for critical vs. non-critical paths (e.g., device commands vs. analytics queries should not share connection pools)
4. **Graceful degradation**: When circuit is open, return cached data or fallback responses instead of hard failures

**Reference**: Section 3 (Architecture Design), Section 6 (Error Handling)

---

### 3. Transaction Boundaries Undefined for Multi-Step Operations (Critical)

**Issue Description**:
Several operations span multiple data stores but lack explicit transaction boundary definitions:

**Operation 1: Device Command Dispatch** (Device Manager)
- Write to `device_commands` table (PostgreSQL): status = 'pending'
- Publish MQTT message to device
- Update Redis with latest device state
- Update `device_commands` status to 'sent'

**Operation 2: Sensor Data Ingestion** (Kinesis consumer)
- Write to TimescaleDB `energy_consumption` table
- Update Redis `device_state` cache with latest reading

**Operation 3: Device Registration**
- Insert into `devices` table (PostgreSQL)
- Create MQTT topic subscription
- Initialize Redis device state entry

The design does not specify:
- Are these operations atomic? What happens if step 3 fails but steps 1-2 succeeded?
- Is eventual consistency acceptable, or are stronger guarantees needed?
- How are partial failures detected and reconciled?

**Failure Scenario (Device Command Dispatch)**:
1. Device Manager writes command to PostgreSQL (`status = 'pending'`)
2. MQTT publish succeeds, device executes command
3. PostgreSQL connection drops before status update to 'sent'
4. User polls command status, sees 'pending', assumes command failed
5. User retries → duplicate command execution (see Issue #1)

**Operational Impact**: Critical - Data inconsistency can lead to duplicate operations, lost commands, or incorrect system state

**Countermeasures**:
1. **Device Command Dispatch** - Use **Transactional Outbox Pattern**:
   - Within a single PostgreSQL transaction: Insert command into `device_commands` AND insert into `outbox` table
   - Separate worker process polls `outbox` table, publishes to MQTT, updates command status on success
   - Guarantees at-least-once delivery (idempotency keys prevent duplicates)
2. **Sensor Data Ingestion** - Accept eventual consistency:
   - TimescaleDB write is primary (durable storage)
   - Redis update is best-effort (cache miss triggers database fallback)
   - Add replication lag monitoring to detect delays
3. **Device Registration** - Make idempotent:
   - Generate device UUID client-side (deterministic from device serial number)
   - Use `INSERT ... ON CONFLICT DO NOTHING` to make database insert idempotent
   - MQTT topic creation is idempotent (AWS IoT Core allows duplicate subscriptions)
4. **Document consistency model**: Add a "Data Consistency Guarantees" section to the design doc specifying ACID vs. BASE model for each operation type

**Reference**: Section 3 (Data Flow), Section 4 (Data Model)

---

### 4. Missing Health Check Failure Isolation (Critical)

**Issue Description**:
The design mentions "Kubernetes rolling updates with readiness probes" but does not specify:
- What conditions constitute a failed health check?
- What happens when health checks fail during normal operation (not deployment)?
- How are false positives (transient failures) distinguished from true failures?

**Specific Gap**: If a pod's PostgreSQL connection pool is exhausted due to a slow query, the readiness probe likely fails. Kubernetes removes the pod from load balancing. But:
- The pod is not restarted (liveness probe not triggered)
- The pod continues to consume cluster resources
- If all pods hit this condition simultaneously (e.g., due to a bad database migration), the entire service becomes unavailable with no automatic recovery

**Failure Scenario**:
A database migration introduces a slow query that locks a table. All API Gateway pods experience connection pool exhaustion within 30 seconds:
1. Readiness probes fail across all pods
2. Kubernetes removes all pods from load balancer
3. No traffic is routed → service is completely down
4. Pods are not restarted (liveness probes still pass because the process is running)
5. On-call engineer must manually identify the issue, roll back migration, and restart pods

**Operational Impact**: Critical - Entire service outage with no automatic recovery path

**Countermeasures**:
1. **Multi-level health checks**:
   - **Liveness probe**: Process-level health (HTTP 200 on `/healthz` endpoint, checks if service can handle *any* request)
   - **Readiness probe**: Dependency health (checks PostgreSQL, Redis, MQTT connectivity with fast queries)
   - **Startup probe**: Slow initialization (allows up to 60s for initial connections)
2. **Fail-fast liveness probe**: If readiness probe fails for >2 minutes continuously, trigger liveness probe failure to force pod restart
3. **Circuit breaker integration**: Health check should report degraded (but not failed) when circuit breakers are open but fallback mechanisms are working
4. **Database connection pool monitoring**: Expose metrics for pool utilization; alert when >80% to detect issues before health check failures
5. **Graceful degradation**: Readiness probe should pass even when non-critical dependencies fail (e.g., Redis cache down but PostgreSQL healthy → readiness = true, circuit breaker handles Redis failures)

**Reference**: Section 6 (Deployment) - "Kubernetes rolling updates with readiness probes"

---

### 5. Backup Restore Procedure Untested (Critical)

**Issue Description**:
The design specifies backup mechanisms (PostgreSQL daily full + WAL archiving, Redis RDB snapshots every 6h) with RPO 1h and RTO 4h. However:
- No mention of tested restore procedures
- No validation that RPO/RTO targets are achievable
- No documentation of restore steps or runbooks

**Industry Reality**: Untested backups are not backups. Common failure modes:
- Backup files corrupted and undetected until restore attempt
- WAL archiving misconfigured → point-in-time recovery fails
- Restore process takes 12 hours instead of 4 hours due to missing network bandwidth or instance size limitations
- Dependencies between PostgreSQL and Redis not documented → restored data is inconsistent

**Failure Scenario**:
A database corruption incident occurs at 2 PM. At 3 PM, the team decides to restore from backup:
1. They attempt to restore the most recent full backup (from 2 AM)
2. WAL replay fails due to a missing segment (archiving silently failed 2 days ago)
3. They fall back to 1-day-old backup, losing 26 hours of data (RPO violated)
4. Restore takes 8 hours due to slow S3 download speeds (RTO violated)
5. After restore, Redis cache contains device states from 3 PM, but PostgreSQL is from 2 days ago → severe data inconsistency
6. Team must manually reconstruct lost data from application logs and customer support tickets

**Operational Impact**: Critical - In a real disaster, the system may not be recoverable within the stated RTO, or data loss may exceed RPO

**Countermeasures**:
1. **Monthly disaster recovery drills**:
   - Restore full production data to a staging environment from backups
   - Measure actual restore time and validate RPO/RTO achievability
   - Document any discrepancies and update procedures
2. **Automated backup validation**:
   - Daily automated restore test of a random subset of tables
   - Checksum validation to detect corruption
   - Alert if restore test fails
3. **Restore runbooks**:
   - Step-by-step instructions for PostgreSQL + Redis coordinated restore
   - Include steps to verify data consistency between systems
   - Document expected restore times for different failure scenarios (single table vs. full database)
4. **Point-in-time recovery testing**:
   - Validate WAL archiving by performing a PITR to a specific transaction ID
   - Test cross-region restore (us-east-1 backup → us-west-2 restore)
5. **Backup monitoring**:
   - Prometheus metrics for backup job success/failure
   - Alert on missing WAL segments or failed RDB snapshots
   - Dashboard showing time since last successful restore test

**Reference**: Section 7 (Disaster Recovery)

---

## TIER 2: SIGNIFICANT ISSUES (Partial System Impact)

### 6. MQTT Poison Message Handling Missing (Significant)

**Issue Description**:
The Kinesis consumer ingests sensor data from MQTT bridge but lacks poison message handling. If a device sends malformed data:
- JSON parsing fails
- Kinesis consumer crashes (depending on error handling implementation)
- OR consumer gets stuck in an infinite retry loop on the same bad message
- Blocks processing of all subsequent messages in the shard

**Failure Scenario**:
A device with buggy firmware sends a malformed JSON payload with a syntax error. The Kinesis consumer:
1. Attempts to parse the message → JSON parser error
2. Retries (assuming retry logic exists) → fails again
3. Without a dead letter queue or skip mechanism, the consumer is stuck
4. All sensor data from devices in the same Kinesis shard stops being processed
5. TimescaleDB stops receiving updates → analytics dashboard shows stale data
6. Users report "device offline" issues, but devices are functioning normally

**Operational Impact**: Significant - Single malformed message can block data ingestion for a subset of devices

**Countermeasures**:
1. **Dead Letter Queue (DLQ)**: Configure Kinesis consumer to move unparseable messages to a DLQ (e.g., SQS queue) after 3 failed attempts
2. **Schema validation**: Validate sensor data against a JSON schema before processing; log validation errors with device_id for debugging
3. **Poison message detection**: Track parse failure count per message; if >3 failures, automatically quarantine to DLQ and skip to next message
4. **Alerting**: Alert when DLQ size > 100 messages or DLQ message age > 1 hour
5. **Replay mechanism**: Build tooling to reprocess DLQ messages after fixing data issues (idempotent ingestion required)
6. **Firmware validation**: Device registration process should validate firmware version and reject known-buggy versions

**Reference**: Section 3 (Data Flow) - "Device → MQTT → Kinesis → TimescaleDB"

---

### 7. No Rate Limiting or Backpressure for Device Command Queue (Significant)

**Issue Description**:
The design specifies API-level rate limiting (1000 req/min per user) but does not address:
- Rate limiting for MQTT message publishing to devices
- Backpressure when Device Manager → MQTT broker queue is full
- Protection against a single user flooding the system with commands to their devices

**Specific Gap**: A user (or compromised account) could:
- Send 1000 commands/min to 100 devices = 100,000 MQTT messages/min
- Overwhelm the Device Manager's MQTT client connection
- Cause message queue buildup, increasing command latency for all users

**Failure Scenario**:
A user's home automation script malfunctions and sends a device command every 60ms (1000/min, within API rate limit). With 50 devices, this generates 50,000 MQTT messages/min. The Device Manager:
1. Cannot publish messages fast enough to MQTT broker
2. In-memory command queue grows unbounded
3. Device Manager process runs out of memory → crashes
4. Kubernetes restarts pod, but same commands are retried (if no deduplication) → crash loop
5. All users experience delayed device commands or failures

**Operational Impact**: Significant - Single abusive user can degrade service for all users

**Countermeasures**:
1. **Per-device rate limiting**: Limit commands to 10/min per device (separate from user-level API rate limit)
2. **MQTT publish backpressure**:
   - Use bounded channel/queue for outbound MQTT messages (size: 10,000 messages)
   - If queue is full, reject new commands with HTTP 503 "Service Unavailable" and `Retry-After` header
3. **MQTT broker rate limiting**: Configure AWS IoT Core publish rate limits per client connection
4. **Monitoring**: Expose metrics for Device Manager queue depth; alert when >80% full
5. **Graceful degradation**: When under heavy load, prioritize high-priority commands (e.g., safety shutoff) over low-priority commands (e.g., status queries)
6. **User notification**: If a user hits rate limits repeatedly, send in-app notification suggesting they review their automation scripts

**Reference**: Section 3 (Device Manager), Section 5 (API Gateway rate limiting)

---

### 8. Redis Cluster Failover Behavior Undefined (Significant)

**Issue Description**:
The design specifies "Redis Cluster: 3 master + 3 replica nodes" but does not address:
- Automatic failover behavior when a master node fails
- Client-side handling of failover (connection retry logic)
- Data loss window during failover (Redis replication is asynchronous by default)
- Impact on real-time device state reads during failover

**Failure Scenario**:
A Redis master node crashes due to an OOM error. Redis Cluster promotes a replica to master (typical failover time: 10-30 seconds):
1. During failover window, writes to the failed master are lost (asynchronous replication)
2. API Gateway's Redis client detects connection failure, attempts to reconnect
3. If client does not implement cluster-aware failover, it may continue trying to connect to the dead master
4. Device state queries return errors → mobile app shows "device unavailable"
5. WebSocket connections may break, triggering reconnection storms

**Potential Data Loss**: Device state updates written in the 1-2 seconds before master crash are lost (not yet replicated). Example: User turns off device, but Redis failover loses the state update → app shows device as "on" incorrectly.

**Operational Impact**: Significant - Temporary service degradation and potential state inconsistency during failover

**Countermeasures**:
1. **Cluster-aware Redis client**: Use a Go Redis client with cluster support (e.g., `go-redis/redis` cluster mode) that automatically handles failover
2. **Retry logic**: Implement exponential backoff retries (3 attempts, 100ms, 200ms, 400ms) for Redis operations
3. **Fallback to PostgreSQL**: If Redis is unavailable, query device state from PostgreSQL (accept slower response time)
4. **Monitoring**:
   - Alert on Redis cluster node failures
   - Track failover events and measure actual failover time
   - Monitor replication lag to detect delays
5. **Optional: Redis Sentinel**: If using Redis in non-cluster mode, deploy Redis Sentinel for automated failover orchestration
6. **Optional: Wait for replication**: For critical state updates, use `WAIT` command to ensure data is replicated to at least 1 replica before acknowledging write (trades latency for durability)

**Reference**: Section 7 (Availability & Scalability) - "Redis Cluster: 3 master + 3 replica nodes"

---

### 9. Database Migration Rollback Strategy Missing (Significant)

**Issue Description**:
The design mentions "Flyway with backward-compatible schema changes" but does not specify:
- How to roll back a migration if it causes production issues
- What "backward-compatible" means in practice (expand-contract pattern?)
- How to handle data migrations (not just schema changes)

**Specific Gap**: Flyway does not support automatic rollback. Once a migration is applied, rolling back requires manually writing a reverse migration. In a high-pressure incident, this is error-prone.

**Failure Scenario**:
A migration adds a new `NOT NULL` column to the `devices` table without a default value. During rolling deployment:
1. New pods (with migration) start successfully
2. Old pods (without migration) attempt to insert into `devices` table
3. Insert fails due to missing required column → device registration broken
4. On-call engineer realizes the issue, needs to roll back
5. Rolling back the deployment does not roll back the database migration
6. Engineer must manually write and apply a reverse migration under time pressure
7. Or, engineer must complete the rolling deployment and fix the issue forward (deploy a hotfix)

**Operational Impact**: Significant - Schema migration issues can cause partial service outage and require complex manual recovery

**Countermeasures**:
1. **Expand-contract pattern** (document explicitly):
   - **Phase 1 (Expand)**: Add new column as nullable, deploy application code
   - **Phase 2 (Migrate)**: Backfill data, add constraints
   - **Phase 3 (Contract)**: Remove old column after confirming new code is stable
2. **Migration testing in staging**:
   - Apply migration to staging environment with production-like data volume
   - Run full test suite against staging
   - Perform a rolling deployment in staging to verify backward compatibility
3. **Automated rollback scripts**:
   - For every forward migration, generate a reverse migration script (even if not fully automated)
   - Store reverse scripts in version control for quick access during incidents
4. **Migration observability**:
   - Log migration start/completion times
   - Alert if migration takes longer than expected (could indicate locking issues)
   - Monitor database lock contention during migrations
5. **Feature flags for schema-dependent features**: If a feature depends on a new schema, gate it with a feature flag to allow quick disable without rollback

**Reference**: Section 6 (Deployment) - "Database migrations: Flyway with backward-compatible schema changes"

---

### 10. No Distributed Tracing for Cross-Service Debugging (Significant)

**Issue Description**:
The design mentions "Structured JSON logging with correlation IDs" but does not specify:
- How correlation IDs are generated and propagated across services
- Whether distributed tracing is implemented (e.g., OpenTelemetry, Jaeger)
- How to trace a user request through the entire system (API Gateway → Device Manager → MQTT → Device)

**Why This Matters**: Without distributed tracing, debugging production issues is extremely difficult. Example questions that cannot be answered easily:
- "A user reports their device command took 10 seconds. Where was the delay?"
- "Why did 5% of analytics queries timeout yesterday between 2-3 PM?"
- "Which service is causing the spike in MQTT publish failures?"

**Failure Scenario**:
Users report intermittent device command delays (commands take 5-10 seconds instead of <500ms). The on-call engineer:
1. Checks API Gateway logs → sees normal response times (<200ms)
2. Checks Device Manager logs → cannot correlate requests without correlation IDs
3. Checks MQTT broker logs → AWS IoT Core logs are separate, difficult to correlate
4. Checks PostgreSQL slow query log → no clear culprit
5. Investigation takes 3 hours, requiring manual log analysis and correlation
6. Root cause: MQTT broker occasionally has 5-second publish latency spikes, but no tooling to detect this

**Operational Impact**: Significant - Extended MTTR (mean time to recovery) due to difficult debugging

**Countermeasures**:
1. **Implement OpenTelemetry distributed tracing**:
   - API Gateway generates a trace ID for each request, includes in response headers
   - Propagate trace ID across all service boundaries (HTTP headers, MQTT message metadata)
   - Export traces to Jaeger or AWS X-Ray
2. **Span annotations**: Add spans for key operations:
   - API Gateway: HTTP request handling
   - Device Manager: Database query, Redis operation, MQTT publish
   - Analytics Engine: TimescaleDB query, ML model execution
3. **Correlation ID format**: Use a structured format (e.g., `{trace_id}-{span_id}-{parent_span_id}`) to enable reconstruction of the full request path
4. **MQTT metadata**: Include trace ID in MQTT message payload or user properties (MQTT 5.0) to trace end-to-end latency
5. **Dashboards**: Create Grafana dashboards showing:
   - Request latency percentiles by service
   - Error rate by service
   - Service dependency map with latency annotations

**Reference**: Section 6 (Logging) - "Structured JSON logging with correlation IDs for distributed tracing"

---

## TIER 3: MODERATE ISSUES (Operational Improvement)

### 11. SLO/SLA Definitions Incomplete (Moderate)

**Issue Description**:
The design specifies performance goals (p95 < 200ms, 99.9% uptime) but does not define:
- **SLIs** (Service Level Indicators): Which metrics are measured? (availability, latency, error rate?)
- **SLOs** (Service Level Objectives): What are the target values for each SLI over a measurement window?
- **Error budgets**: How much downtime is allowed per month before escalation?
- **SLAs** (Service Level Agreements): What are the customer-facing guarantees and penalties?

**Why This Matters**: Without clear SLOs:
- On-call engineers do not know when to escalate vs. when to tolerate transient issues
- Product/engineering trade-off decisions lack data (e.g., "Can we skip this reliability improvement to ship faster?")
- Incident severity classification is subjective

**Example Gap**: The design states "Target uptime: 99.9%". Does this mean:
- 99.9% of API requests succeed?
- 99.9% of time at least one pod is healthy?
- 99.9% of device commands are delivered successfully?

Without specificity, teams may measure different things and arrive at different uptime calculations.

**Countermeasures**:
1. **Define SLIs** for each service:
   - API Gateway: Request success rate (non-5xx responses), p95 latency
   - Device Manager: Command delivery success rate, command latency
   - Analytics Engine: Query success rate, p95 query latency
2. **Set SLOs** with measurement windows:
   - Example: "API Gateway request success rate ≥99.9% over any 30-day window"
   - Example: "Device command delivery latency p95 ≤500ms over any 24-hour window"
3. **Calculate error budgets**:
   - 99.9% uptime = 43.8 minutes downtime/month
   - Track error budget consumption in Grafana dashboards
   - Alert when 50% of monthly error budget is consumed
4. **Document SLA commitments** (if applicable for B2B customers):
   - Free tier: Best effort, no SLA
   - Paid tier: 99.9% uptime SLA, prorated refund if violated
5. **Incident severity levels** tied to SLO violations:
   - SEV-1: SLO violated and error budget exhausted
   - SEV-2: SLO violated but error budget remains
   - SEV-3: SLO at risk but not yet violated

**Reference**: Section 7 (Non-functional Requirements)

---

### 12. Incident Response Runbooks Missing (Moderate)

**Issue Description**:
The design does not mention incident response procedures, runbooks, or escalation policies. Common production incidents that require predefined runbooks:
- Database connection pool exhaustion
- Kinesis shard throughput exceeded
- Redis cluster failover
- MQTT broker connectivity issues
- Disk space exhaustion on TimescaleDB
- Certificate expiration for MQTT device authentication

**Why This Matters**: During high-pressure incidents, on-call engineers do not have time to research solutions. Runbooks provide step-by-step checklists to reduce MTTR.

**Countermeasures**:
1. **Create runbooks for common incidents** (store in internal wiki or PagerDuty):
   - **High API Latency**: Steps to check database slow queries, Redis latency, Kinesis lag
   - **Device Command Failures**: Steps to check MQTT broker health, Device Manager logs, certificate validity
   - **Database Connection Pool Exhaustion**: Steps to identify slow queries, kill long-running transactions, scale up replicas
2. **Escalation policy**:
   - L1 (on-call engineer): Respond within 15 minutes, follow runbooks
   - L2 (senior engineer): Escalate after 30 minutes if issue unresolved
   - L3 (engineering manager): Escalate after 1 hour for customer-impacting incidents
3. **Blameless postmortem template**:
   - Timeline of events
   - Root cause analysis (5 whys)
   - Action items with owners and due dates
   - Document in shared repository for organizational learning
4. **Quarterly incident response drills**: Simulate common incidents (e.g., database failover) and measure team response time

**Reference**: Section 7 (Non-functional Requirements) - missing Operational Readiness section

---

### 13. Capacity Planning and Load Testing Strategy Undefined (Moderate)

**Issue Description**:
The design mentions "Load testing: k6 for API endpoints (target: 10,000 concurrent users)" but does not specify:
- What load scenarios are tested? (steady state, spike traffic, gradual ramp-up?)
- How are bottlenecks identified and addressed?
- What is the plan for capacity growth? (when to scale up database, add Redis nodes, etc.)

**Why This Matters**: Without proactive capacity planning, the system will hit scalability limits unexpectedly during peak usage, causing outages or degraded performance.

**Potential Scenarios**:
- Black Friday promotion drives 10x normal traffic → API Gateway auto-scales but PostgreSQL connection pool is exhausted
- TimescaleDB storage grows faster than expected → disk full, writes fail
- Kinesis shard limit reached → event ingestion throttled

**Countermeasures**:
1. **Load testing scenarios**:
   - **Steady state**: Simulate 10,000 concurrent users for 1 hour
   - **Spike traffic**: Ramp from 1,000 → 20,000 users in 5 minutes
   - **Gradual growth**: Simulate 6-month user growth trajectory
2. **Capacity monitoring**:
   - Database connection pool utilization (alert at >70%)
   - Kinesis shard throughput (alert at >80% of limit)
   - TimescaleDB disk usage (alert at >70% full)
   - Redis memory usage (alert at >75% of max memory)
3. **Auto-scaling policies**:
   - API Gateway / Device Manager: Kubernetes HPA based on CPU + custom metrics (request queue depth)
   - PostgreSQL: Read replica auto-scaling based on query latency
   - Kinesis: Shard auto-scaling based on throughput
4. **Quarterly capacity reviews**: Analyze growth trends and adjust scaling policies before limits are reached
5. **Cost vs. performance trade-offs**: Document decisions (e.g., "We accept 1% of analytics queries may timeout to avoid over-provisioning read replicas")

**Reference**: Section 6 (Testing) - "Load testing: k6 for API endpoints"

---

### 14. No Chaos Engineering or Failure Injection Testing (Moderate)

**Issue Description**:
The design does not mention chaos engineering practices to validate resilience. Common failure scenarios that should be tested:
- Kill a random pod during peak traffic (Kubernetes resilience)
- Introduce 5-second latency on PostgreSQL queries (timeout handling)
- Fail a Redis master node (failover behavior)
- Simulate AWS region failure (DR failover)
- Introduce packet loss on MQTT connections (retry logic)

**Why This Matters**: Reliability mechanisms often have bugs that only manifest during actual failures. Example: Circuit breaker logic looks correct in code review but has an off-by-one error that prevents it from opening.

**Countermeasures**:
1. **Adopt chaos engineering tools**:
   - **Chaos Mesh** (Kubernetes): Inject pod failures, network delays, disk I/O errors
   - **AWS Fault Injection Simulator**: Test AWS service failures (RDS failover, EKS node termination)
2. **Quarterly chaos experiments**:
   - Experiment 1: Kill 50% of API Gateway pods during load test → verify auto-scaling and no user-visible errors
   - Experiment 2: Introduce 10-second PostgreSQL query latency → verify circuit breaker opens and fallback works
   - Experiment 3: Fail Redis master → verify failover completes within 30 seconds and no data loss
3. **GameDay exercises**: Schedule a "failure Friday" where the team deliberately introduces failures and practices incident response
4. **Blast radius limits**: Use Kubernetes namespaces, resource quotas, and pod disruption budgets to limit chaos experiment impact
5. **Rollback plan**: Have a kill switch to immediately stop any chaos experiment if it causes unexpected issues

**Reference**: Section 6 (Testing) - no mention of chaos engineering

---

### 15. Log Aggregation and Retention Policy Undefined (Moderate)

**Issue Description**:
The design mentions "Centralized logging via CloudWatch Logs" but does not specify:
- Log retention period (how long are logs kept?)
- Log volume management (what happens if log volume exceeds budget?)
- Sensitive data redaction (are PII or credentials logged accidentally?)
- Query performance for incident investigation (can engineers quickly search 1TB of logs?)

**Why This Matters**: Poor log management leads to:
- High costs (CloudWatch Logs is expensive for high-volume logging)
- Inability to investigate old incidents (logs deleted before postmortem)
- Compliance violations (PII logged and retained beyond legal limits)

**Countermeasures**:
1. **Log retention tiers**:
   - Hot storage (CloudWatch Logs): 7 days, fast queries
   - Warm storage (S3 + Athena): 90 days, slower queries
   - Cold storage (S3 Glacier): 1 year, archive only
2. **Structured logging with levels**:
   - DEBUG: Disabled in production (enable temporarily for specific pods)
   - INFO: Business events (user login, device command sent)
   - WARN: Recoverable errors (retry succeeded after 1 failure)
   - ERROR: Non-recoverable errors (database connection failed after 3 retries)
3. **Sensitive data redaction**:
   - Automatically redact fields like `password`, `api_key`, `jwt_token` from logs
   - Use structured logging library with built-in redaction (e.g., `zap` for Go)
4. **Log sampling for high-volume events**:
   - Log 100% of errors
   - Log 10% of INFO-level sensor data ingestion events (sample deterministically by device_id hash)
5. **Monitoring**: Track log volume per service; alert if it spikes unexpectedly (could indicate a bug causing log spam)

**Reference**: Section 6 (Logging) - "Centralized logging via CloudWatch Logs"

---

## TIER 4: MINOR IMPROVEMENTS & POSITIVE ASPECTS

### 16. Positive: Comprehensive Deployment Strategy

**Observation**: The design specifies multiple deployment safety mechanisms:
- Blue-green deployment for API Gateway
- Rolling updates with readiness probes
- Canary releases for Analytics Engine (10% → 50% → 100%)

**Impact**: This multi-layered approach significantly reduces the risk of deployment-related outages.

**Recommendation**: Add automated rollback triggers based on SLI degradation (e.g., if error rate >1% during canary, auto-rollback). Document the rollback decision criteria explicitly.

---

### 17. Positive: Appropriate Database Technology Choices

**Observation**: The design uses TimescaleDB for time-series data and PostgreSQL for relational data, which is well-suited for the use case.

**Impact**: Avoids common anti-patterns (e.g., storing time-series data in a document database without efficient time-based queries).

**Minor Recommendation**: Consider adding continuous aggregates in TimescaleDB to pre-compute common analytics queries (e.g., hourly energy consumption summaries) for faster dashboard loading.

---

### 18. Positive: Explicit Rate Limiting

**Observation**: The design specifies rate limiting (1000 req/min per user) at the API Gateway level.

**Impact**: Protects the system from unintentional abuse and runaway automation scripts.

**Recommendation**: Extend rate limiting to cover device-level commands (see Issue #7) and document the rate limit values in API documentation so users can design their integrations accordingly.

---

### 19. Minor Improvement: Add Replication Lag Monitoring

**Observation**: The design uses PostgreSQL read replicas for analytics queries but does not mention replication lag monitoring.

**Risk**: If replication lag grows to >5 minutes, analytics dashboards show stale data, confusing users.

**Recommendation**: Add Prometheus metric for replication lag; alert if >30 seconds. Document that analytics queries may be slightly stale (eventual consistency).

---

### 20. Minor Improvement: Feature Flags for Progressive Rollout

**Observation**: The design mentions canary releases but does not mention feature flags.

**Benefit**: Feature flags allow even safer rollouts by decoupling deployment from feature activation. If a canary deployment succeeds but a new feature causes issues, the feature can be disabled instantly without redeployment.

**Recommendation**: Add a feature flag service (e.g., LaunchDarkly, or build a simple in-house solution with Redis) and gate new features behind flags for the first 2 weeks after launch.

---

## Summary & Risk Assessment

### Critical Risks (Immediate Action Required)
1. **Idempotency gaps** (Issue #1) - Duplicate device commands can cause financial/safety issues
2. **No circuit breakers** (Issue #2) - Single dependency failure can cascade system-wide
3. **Undefined transaction boundaries** (Issue #3) - Data inconsistency and lost operations
4. **Health check failure isolation** (Issue #4) - Entire service outage with no auto-recovery
5. **Untested backups** (Issue #5) - RPO/RTO targets may not be achievable in real disaster

### Significant Risks (Address in Next Sprint)
6. Poison message handling (Issue #6)
7. Device command queue backpressure (Issue #7)
8. Redis failover behavior (Issue #8)
9. Database migration rollback (Issue #9)
10. Distributed tracing (Issue #10)

### Operational Improvements (Address in Q2 2026 Roadmap)
11. SLO/SLA definitions (Issue #11)
12. Incident response runbooks (Issue #12)
13. Capacity planning (Issue #13)
14. Chaos engineering (Issue #14)
15. Log retention policy (Issue #15)

### System Reliability Score
- **Current State**: 4/10 (Critical gaps in fault tolerance and consistency)
- **After Tier 1 Fixes**: 7/10 (Acceptable for production launch)
- **After Tier 2 Fixes**: 9/10 (Production-ready with strong operational resilience)

**Recommendation**: Do not proceed to production launch until all Tier 1 (Critical) issues are resolved. Tier 2 issues should be addressed within 1 month after launch. Tier 3 issues can be tackled incrementally over 6 months.
