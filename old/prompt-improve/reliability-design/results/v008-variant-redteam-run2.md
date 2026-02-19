# Reliability Design Review: Smart Energy Management System (Red Team Analysis - Run 2)

**Review Date:** 2026-02-11
**Reviewer:** reliability-design-reviewer (v008-variant-redteam)
**Document:** test-document-round-008.md

---

## Phase 1: Structural Analysis

### System Components
- **Data Ingestion Path**: Smart Meters → AWS IoT Core (MQTT) → Ingestion Service → Kafka → Aggregation Service → InfluxDB
- **Forecasting Path**: InfluxDB + WeatherAPI → Forecast Service → PostgreSQL
- **Demand Response Path**: Utility Webhook → DR Coordinator → BMS Controller → HVAC/Lighting Systems
- **User Interface Path**: React Frontend → API Gateway → PostgreSQL/InfluxDB/Redis

### Key Dependencies
- **Critical External Services**: AWS IoT Core, WeatherAPI.com, Utility Grid API, BMS SOAP API
- **Data Stores**: PostgreSQL (single primary), InfluxDB, Redis, Kafka
- **Infrastructure**: AWS EKS (3 AZs), Application Load Balancer, S3

### State Transitions
- DR Events: scheduled → active → completed/failed
- Sensor data: raw (15s) → aggregated (1min/15min/hourly) → archived (S3)
- Forecasts: Generated every 15 minutes, stored with confidence intervals

### Explicitly Mentioned Reliability Mechanisms
- Multi-AZ deployment (3 zones)
- Auto-scaling (HPA based on CPU 70%)
- Rolling updates (maxUnavailable: 1)
- Exponential backoff for WeatherAPI retries (max 3 attempts)
- Redis caching (10s TTL for current readings)

---

## Phase 2: Red Team Problem Detection

### TIER 1: CRITICAL ISSUES (System-Wide Impact)

#### C1. PostgreSQL Single Point of Failure - Cascading System Collapse
**Reference:** Section 2 (Databases), Section 7 (Availability & Scalability: "PostgreSQL: Single primary instance (no read replicas)")

**Red Team Scenario - Total Control Plane Failure:**
The PostgreSQL database is a **single primary instance with no replication**, yet it stores critical control plane data including:
- Facility metadata (required for all data processing)
- DR event coordination state (scheduled/active/completed)
- Load forecasts (required for DR decision-making)

**Worst-Case Failure Path:**
1. PostgreSQL instance fails (hardware failure, AZ outage, or disk corruption)
2. **All new API requests fail immediately** (no facility metadata, no authentication context)
3. **DR Coordinator cannot process new DR events** from utility webhook (cannot query forecasts or update event status)
4. **Active DR events enter undefined state** - BMS commands may have been sent, but system cannot track completion or rollback
5. **Forecast Service continues generating predictions but cannot persist them** - 15-minute ML job execution wasted
6. **Recovery requires database restore from backup** - AWS RDS automated backups have 5-minute backup intervals at best, meaning potential loss of:
   - DR event state changes (could lose tracking of which facilities reduced load)
   - Forecast predictions (could require 24+ hours to rebuild forecast history)
   - User configuration changes

**Cascading Business Impact:**
- **Regulatory compliance violation**: Lost DR event tracking means inability to prove demand response participation to utility (financial penalties)
- **Energy cost spike**: Without forecasts, facilities cannot perform peak shaving or load shifting during recovery period
- **Operational blindness**: Dashboard becomes read-only for cached data, zero visibility into system health

**Recovery Complexity Under Stress:**
- RTO realistically 15-30 minutes for automated RDS failover IF using Multi-AZ (not specified)
- Without Multi-AZ: Manual restoration from backup could take 2-4 hours including validation
- Data loss (RPO) of 5-60 minutes depending on backup strategy (not specified)
- **Disaster during peak demand period**: If PostgreSQL fails during active DR event, facilities may continue load reduction indefinitely (BMS commands not rolled back) or fail to reduce at all (lost event state)

**Countermeasures:**
1. **IMMEDIATE**: Deploy PostgreSQL Multi-AZ with synchronous replication (RDS Multi-AZ or self-managed streaming replication)
2. **Read Replica Strategy**: Add 2+ read replicas across AZs for query load distribution, automatic promotion capability
3. **State Externalization**: Store DR event active state in Redis with persistence (AOF + RDB) as fast failover path
4. **Circuit Breaker for Database**: API Gateway must fail fast with 503 when PostgreSQL unavailable (prevent request queue buildup)
5. **Forecast Persistence Fallback**: Buffer forecast results in Kafka topic if PostgreSQL write fails, replay on recovery
6. **RPO/RTO Definition**: Document acceptable data loss (suggest RPO < 1 minute, RTO < 5 minutes) and validate with chaos testing

---

#### C2. DR Coordinator State Management - No Transactional Boundaries
**Reference:** Section 3 (DR Coordinator workflow), Section 6 (Implementation: "BMS Controller logs command failures but does not retry")

**Red Team Scenario - Partial Execution with State Corruption:**
The DR Coordinator workflow has **no defined transaction boundaries**:
1. Receives utility webhook → immediate 200 response
2. Queries forecast from PostgreSQL
3. Calculates load reduction strategy
4. Sends BMS commands (HVAC/lighting adjustments)
5. Updates dr_events table status

**Worst-Case Failure Combinations:**
- **Network partition during BMS command**: Commands sent to subset of HVAC units → partial load reduction → database still records "completed" status (inaccurate achieved_reduction_kw)
- **PostgreSQL failure after BMS commands sent**: Physical HVAC changes applied, but no record in database → facilities stuck in reduced-load mode indefinitely
- **BMS SOAP API timeout with ambiguous response**: Did the command apply or not? Design states "does not retry" → potential duplicate commands on manual retry OR no action taken

**Implicit Assumption Violation:**
The webhook handler returns 200 immediately ("async processing") but provides **no acknowledgment mechanism back to utility**. If DR Coordinator crashes after 200 but before BMS commands, utility assumes participation but facility takes no action → compliance violation.

**Cascading Consequences:**
- **Energy cost penalty**: Utility charges non-compliance fees if expected load reduction not achieved
- **Equipment damage risk**: HVAC systems stuck in reduced mode could cause temperature excursions (data center cooling failure, industrial process disruption)
- **Audit trail corruption**: dr_events.achieved_reduction_kw may not match actual smart meter readings → reporting discrepancies

**Recovery Complexity:**
- **No automated rollback**: Design requires "manual intervention" for BMS failures → operations team must manually inspect HVAC state across potentially hundreds of facilities
- **State reconciliation**: After recovery, system must compare dr_events table against actual InfluxDB load readings to detect discrepancies → manual data cleanup

**Countermeasures:**
1. **Implement Saga Pattern**: Break DR workflow into compensatable steps with explicit rollback commands (undo HVAC changes if database update fails)
2. **Idempotency Keys**: Add idempotency_token to BMS commands (safe retry if response ambiguous)
3. **Two-Phase Commit Alternative**: Store DR event as "pending" → send BMS commands → poll BMS for confirmation → mark "active" → verify load reduction via InfluxDB → mark "completed"
4. **BMS Command Timeout**: Add explicit 30-second timeout with circuit breaker (current design has no timeout specification for SOAP API)
5. **Reconciliation Service**: Background job compares dr_events.achieved_reduction_kw against actual InfluxDB measurements, alerts on >10% discrepancy
6. **Utility Callback**: Implement callback to utility API after BMS commands confirmed (replace fire-and-forget webhook)

---

#### C3. InfluxDB Write Failure - Silent Data Loss with Monitoring Blind Spots
**Reference:** Section 3 (Aggregation Service), Section 7 (Monitoring: "InfluxDB write throughput")

**Red Team Scenario - Stealthy Degradation:**
The Aggregation Service consumes from Kafka and writes to InfluxDB, but design provides **no specification for write failure handling**.

**Hidden Failure Modes:**
1. **InfluxDB backpressure**: Write throughput drops below 10,000 readings/sec → Aggregation Service slows down → Kafka consumer lag increases
2. **Partial write failure**: InfluxDB accepts batch write but silently drops some points (network timeout, schema validation failure on subset)
3. **InfluxDB disk full**: Section 7 alerts on "disk usage > 80%" but **no action specified** → writes start failing at ~95% → gap in time-series data
4. **Retention policy edge case**: 90-day granular data deletion happens during high-load period → compaction storm → write latency spike

**Worst-Case Cascade:**
- Kafka consumer lag exceeds monitoring threshold (10,000 messages) → alert fires
- Operations team investigates, finds InfluxDB write latency degraded
- During investigation (15-30 minutes), Kafka continues accumulating messages
- **Consumer lag reaches Kafka retention limit (default 7 days)** → oldest messages deleted → **permanent data loss for affected time periods**
- Dashboard shows gaps in historical graphs
- **Forecast Service uses incomplete data** → predictions become inaccurate → DR events based on bad forecasts → suboptimal load reduction

**Monitoring Blind Spot:**
Current alert: "Kafka lag > 10,000 messages" is a **lagging indicator**. By the time alert fires, data loss may already be occurring (if InfluxDB rejecting writes).

**Implicit Assumption:**
Design assumes InfluxDB writes are "fast enough" and Kafka consumer can always keep up. No discussion of write throughput limits, batch size tuning, or failure modes.

**Countermeasures:**
1. **Dead Letter Queue for InfluxDB Writes**: On write failure, publish failed batches to Kafka DLQ topic → retry with exponential backoff → alert if DLQ depth > 1000
2. **InfluxDB Write Timeout**: Add explicit 5-second write timeout in Aggregation Service (current design has no timeout)
3. **Monitoring Enhancement**: Alert on InfluxDB write error rate (not just throughput) and p99 write latency (not just Kafka lag)
4. **Backpressure Handling**: If InfluxDB write latency > 1 second, pause Kafka consumer temporarily → prevent unbounded memory growth in Aggregation Service
5. **Disk Space Automation**: At 85% InfluxDB disk usage, trigger automatic retention policy adjustment (downsample more aggressively) or volume expansion
6. **Data Validation**: After batch write, sample-verify records actually persisted to InfluxDB (detect silent drops)
7. **Kafka Retention Tuning**: Increase retention to 14+ days for sensor-readings topic (buy time for operations to fix InfluxDB issues)

---

#### C4. Ingestion Service Kafka Connectivity Loss - Infinite Message Queue
**Reference:** Section 3 (Data Flow: "Ingestion Service forwards to Kafka"), Section 6 (Error Handling: "logs malformed MQTT messages to CloudWatch, continues processing")

**Red Team Scenario - Memory Exhaustion Attack via Operational Failure:**
Ingestion Service acts as bridge between AWS IoT Core (MQTT) and Kafka. Design states malformed messages are logged and processing continues, but **no specification for Kafka connectivity failures**.

**Failure Cascade Path:**
1. Kafka cluster becomes unavailable (rolling restart, AZ failure, network partition)
2. Ingestion Service cannot publish to `sensor-readings` topic
3. **AWS IoT Core continues delivering MQTT messages** at 10,000/second (Section 7 performance requirement)
4. Ingestion Service has two bad options:
   - **Buffer in memory** → OOM crash within minutes (10k msgs/sec * 60 sec * 1KB avg = 600MB/min)
   - **Drop messages** → permanent data loss (no dead letter, no replay mechanism specified)
5. Even if Ingestion Service scales horizontally (HPA), **all replicas hit same Kafka unavailability** → entire pod fleet crashes or drops data

**Worst-Case Timing:**
- Kafka outage during DR event → no real-time load monitoring → cannot verify if BMS commands achieving target reduction → blind operation
- Operations discovers data loss after Kafka restored → gaps in InfluxDB → historical analysis corrupted → regulatory audit failure

**Implicit Assumptions:**
- Kafka is always available (no circuit breaker, no fallback path)
- MQTT delivery is optional (acceptable to drop messages)
- Ingestion Service has infinite memory to buffer during outages

**Countermeasures:**
1. **Circuit Breaker for Kafka**: After 10 consecutive write failures, Ingestion Service should open circuit → return MQTT PUBACK failure → AWS IoT Core re-queues messages (leverage QoS 1)
2. **Local Persistent Queue**: Use embedded storage (e.g., BadgerDB, RocksDB) in Ingestion Service to buffer messages during Kafka outages (size limit: 10GB per pod)
3. **Backpressure to IoT Core**: Implement MQTT flow control (pause acknowledgments) when buffer exceeds 80% capacity
4. **Health Check Integration**: Kubernetes liveness probe must check Kafka connectivity → unhealthy pods removed from load balancer → prevent cascading OOM
5. **Alert on Buffer Depth**: Monitor Ingestion Service memory usage and buffer depth → alert if approaching limits (proactive Kafka restoration)
6. **Kafka High Availability**: Deploy Kafka across 3 AZs with min.insync.replicas=2 (design does not specify Kafka replication factor)

---

#### C5. WeatherAPI Dependency - Forecast Generation Complete Failure
**Reference:** Section 3 (Forecast Service: "queries WeatherAPI every 15 minutes"), Section 6 (Error Handling: "retries with exponential backoff, max 3 attempts")

**Red Team Scenario - Third-Party Prolonged Outage:**
Forecast Service depends on WeatherAPI.com for weather data, which feeds LSTM models for 24-hour load predictions. Design specifies **3 retry attempts with exponential backoff**, but no fallback strategy.

**Worst-Case Failure Path:**
1. WeatherAPI.com experiences extended outage (DDoS, service degradation, API rate limiting changes)
2. All 3 retry attempts fail within ~1 minute (exponential backoff: 1s, 2s, 4s typical)
3. **Forecast Service cannot generate new predictions** → PostgreSQL load_forecasts table becomes stale
4. DR Coordinator receives utility webhook → queries forecast → gets **outdated 24-hour-old prediction** → calculates suboptimal load reduction strategy
5. **Facility reduces wrong systems** (e.g., HVAC reduction when load spike actually coming from production equipment) → fails to meet DR target → compliance penalty

**Cascading Operational Impact:**
- **Dashboard shows stale forecasts** (no timestamp freshness check in API design) → users make bad operational decisions
- **Peak shaving fails** → facilities exceed contract_demand_kw limit → utility demand charges spike (can be 10-50% of monthly bill)
- **Competitive disadvantage** → facilities cannot participate in time-of-use pricing optimization

**Implicit Assumptions:**
- WeatherAPI is "reliable enough" (no SLA discussion)
- Historical weather patterns are acceptable fallback (not mentioned in design)
- 3 retries within 1 minute will handle transient failures (ignores multi-hour outages)

**Recovery Complexity:**
- **No automated degradation mode**: Forecast Service either produces predictions or fails silently
- **No staleness indicators**: API consumers (DR Coordinator, dashboard) have no way to detect forecast quality degradation

**Countermeasures:**
1. **Fallback to Historical Patterns**: If WeatherAPI fails, use same-weekday average from past 4 weeks as baseline forecast (with wider confidence intervals)
2. **Multi-Provider Strategy**: Integrate secondary weather API (OpenWeatherMap, NOAA) with automatic failover
3. **Forecast Staleness Metadata**: Add `last_updated` and `data_quality_score` to load_forecasts table → DR Coordinator must check staleness before using
4. **Grace Period Extension**: Increase retry window to 15 minutes (match forecast generation interval) with longer backoff
5. **Circuit Breaker with Timeout**: Open circuit after 5 minutes of WeatherAPI failures → prevent resource waste on retry attempts
6. **Monitoring Alert**: Alert if forecast lag exceeds 30 minutes (proactive notification before DR event)
7. **Manual Override Interface**: Allow facility managers to input expected load profile during WeatherAPI outages

---

### TIER 2: SIGNIFICANT ISSUES (Partial System Impact)

#### S1. Frontend Polling Without Server-Sent Events - Dashboard Inconsistency During Failures
**Reference:** Section 3 (Data Flow: "Frontend polls API Gateway every 30 seconds")

**Red Team Scenario - Stale Data Masking Critical Failures:**
Dashboard uses 30-second polling interval, which creates **dangerous staleness window** during operational incidents.

**Failure Scenario:**
1. Facility experiences sudden load spike (equipment malfunction, unauthorized load)
2. Smart meter publishes reading to IoT Core
3. **API Gateway fails or times out** during poll (database overload, network issue)
4. Frontend receives last successful response (up to 30 seconds old) → dashboard shows normal operation
5. **Facility exceeds contract_demand_kw** → utility demand charges triggered
6. Facility manager unaware of problem for 30+ seconds (potentially 60+ if next poll also fails)

**Cascading Problem:**
- Active DR event: BMS commands reducing load, but dashboard not updating → operator thinks commands failed → manual override causes over-reduction → process disruption
- Alert fatigue: If API Gateway intermittently fails, operators see "stale data" warnings frequently → ignore genuine staleness during critical events

**Implicit Assumption:**
30-second refresh is "fast enough" for operational decision-making (contradicts real-time monitoring claim in Section 1)

**Countermeasures:**
1. **WebSocket or Server-Sent Events**: Push updates to frontend when threshold crossed (e.g., >90% contract demand, DR event status change)
2. **Staleness Indicator**: Frontend must display "Last Updated: X seconds ago" and alert icon if >45 seconds
3. **Polling Failure Handling**: On API timeout, immediately retry (don't wait 30 seconds) and show prominent error banner
4. **Threshold-Based Polling**: Increase poll frequency to 5 seconds during active DR events or when load >80% contract demand
5. **Optimistic UI Updates**: Show predicted values between polls (based on recent trend) with visual indicator "estimated"

---

#### S2. BMS SOAP API - No Timeout or Circuit Breaker
**Reference:** Section 2 (BMS SOAP API), Section 6 (BMS Controller: "logs command failures but does not retry, manual intervention required")

**Red Team Scenario - Blocked Thread Pool Exhaustion:**
BMS Controller sends HVAC commands via SOAP API during DR events, but design specifies **no timeout** and **no retry logic**.

**Failure Path:**
1. DR event triggered for 50 facilities simultaneously (utility-wide demand response)
2. BMS SOAP API for Facility A becomes unresponsive (network congestion, SOAP service hang)
3. **BMS Controller thread blocks indefinitely** waiting for response
4. Subsequent DR commands for Facilities B-Z either queue up (thread pool exhaustion) or fail immediately
5. **Cascading DR failure**: Multiple facilities miss DR participation window → utility-wide compliance failure

**Additional Failure Mode:**
- SOAP API returns HTTP 500 after 60 seconds (transient error) → design says "does not retry" → facility excluded from DR event unnecessarily

**Implicit Assumptions:**
- BMS SOAP API is responsive (no discussion of vendor SLA)
- Single command failure doesn't affect other facilities (assumes separate threads/connections)

**Countermeasures:**
1. **Explicit Timeout**: 30-second timeout on SOAP API calls (with connection timeout 10s, read timeout 20s)
2. **Bulkhead Pattern**: Separate thread pool per facility (limit 2 threads per facility) → one slow BMS doesn't block others
3. **Circuit Breaker**: After 3 consecutive timeouts for specific BMS, open circuit for 5 minutes (prevent thread exhaustion)
4. **Retry with Idempotency**: Retry SOAP commands up to 2 times with 5-second delay (add idempotency key to prevent duplicate HVAC changes)
5. **Async Command Pattern**: Send BMS command, return immediately, poll for confirmation via separate status endpoint
6. **Fallback Notification**: If BMS commands fail, send email/SMS to facility manager with manual override instructions

---

#### S3. Kafka Consumer Lag Handling - No Rebalancing Strategy
**Reference:** Section 3 (Aggregation Service consumes from Kafka), Section 7 (Monitoring: "Kafka lag > 10,000 messages")

**Red Team Scenario - Consumer Group Death Spiral:**
Aggregation Service consumes `sensor-readings` topic partitioned by facility_id. Design does not specify:
- Number of Kafka partitions
- Consumer group configuration
- Rebalancing behavior during scaling

**Failure Cascade:**
1. Aggregation Service pod crashes (OOM, application bug)
2. Kafka triggers consumer group rebalance → partitions redistributed to remaining consumers
3. **Remaining consumers now handle more partitions** → throughput per consumer increases → CPU/memory pressure rises
4. Another pod crashes under load → rebalance again → **death spiral** until all consumers gone
5. Kafka lag accumulates → alert fires → auto-scaling adds pods → rebalance storm → new pods crash immediately (cold start under load)

**Implicit Assumptions:**
- Consumer scaling is seamless (ignores rebalancing disruption)
- Each consumer can handle arbitrary partition load (no capacity planning discussion)

**Countermeasures:**
1. **Over-Partitioning**: Use 3x partitions vs. expected max consumers (e.g., 30 partitions for 10 consumer pods) → smoother rebalancing
2. **Cooperative Rebalancing**: Use Kafka cooperative-sticky assignor (reduce stop-the-world rebalancing)
3. **Rate Limiting Per Consumer**: Limit each consumer to process 5,000 messages/sec max → prevent individual overload
4. **Graceful Shutdown**: Add SIGTERM handler to commit offsets and cleanly leave consumer group (reduce rebalance time)
5. **Pod Disruption Budget**: Set PDB minAvailable=50% → prevent too many simultaneous pod evictions
6. **Backlog Processing Mode**: If lag > 50,000, switch to batch processing (reduce write frequency, increase batch size)

---

#### S4. Redis Cache Invalidation - Stale Data During Database Failover
**Reference:** Section 5 (API endpoint caching: "Redis, 10-second TTL")

**Red Team Scenario - Cache Coherency Violation:**
API endpoint `/api/facilities/{facility_id}/current` caches responses in Redis with 10-second TTL. During PostgreSQL failover:

**Failure Sequence:**
1. Primary PostgreSQL fails → read replica promoted to primary
2. **In-flight API requests return cached Redis values** (facility metadata, contract limits)
3. Facility metadata was updated in PostgreSQL primary 5 seconds before failure → **update lost** (not replicated to replica)
4. Dashboard shows **incorrect contract_demand_kw value** → facility manager makes bad decision (allows load spike beyond actual contract)
5. Redis cache expires after 10 seconds → new reads hit new PostgreSQL primary → **data suddenly changes in UI** without explanation

**Additional Problem - Cache Stampede:**
- All cached values expire simultaneously (fixed 10-second TTL)
- If API Gateway receives 1000 requests during cache miss → **1000 simultaneous PostgreSQL queries** → database overload during recovery

**Countermeasures:**
1. **Cache Versioning**: Include database transaction ID or timestamp in cache key → invalidate all caches on failover
2. **Jittered TTL**: Randomize TTL between 8-12 seconds → prevent thundering herd
3. **Cache-Aside with Locking**: Use Redis SETNX for lock-based cache population (only one request queries database)
4. **Stale-While-Revalidate**: Serve stale cache up to 60 seconds during database unavailability, async refresh in background
5. **Circuit Breaker Integration**: On PostgreSQL circuit open, increase cache TTL to 5 minutes (preserve availability over consistency)

---

#### S5. S3 Archival - No Restoration Testing
**Reference:** Section 2 (Infrastructure: "S3 for historical data archival, daily snapshots")

**Red Team Scenario - Unvalidated Backup Chain:**
Design specifies daily snapshots to S3 but provides **no details on restoration procedure or testing cadence**.

**Hidden Failure Modes:**
1. **S3 Lifecycle Policy Misconfiguration**: Snapshots transition to Glacier after 30 days → 12-hour retrieval time if needed urgently
2. **Snapshot Corruption**: Daily job writes corrupt Parquet/CSV files → not detected until restoration attempt months later
3. **Incomplete Schema Capture**: Snapshot missing InfluxDB measurement schema → restoration fails due to tag/field mismatch
4. **Access Control Change**: IAM role used for snapshot creation revoked → 90 days of snapshots inaccessible

**Regulatory Risk:**
Energy industry compliance often requires 7-year data retention. If archival process broken and only discovered during audit, potential **multi-million dollar penalties**.

**Countermeasures:**
1. **Monthly Restoration Drill**: Restore random 24-hour snapshot to test environment, validate data integrity
2. **Snapshot Validation Job**: After S3 upload, immediately download and checksum-verify file completeness
3. **Schema Versioning**: Store InfluxDB schema metadata alongside data snapshots (tag keys, field types, retention policies)
4. **Lifecycle Policy Review**: Keep 90-day snapshots in S3 Standard, use Glacier only for >1 year data (balance cost vs. retrieval speed)
5. **Immutable Backups**: Enable S3 Object Lock to prevent accidental deletion during retention period

---

### TIER 3: MODERATE ISSUES (Operational Improvement)

#### M1. Distributed Tracing - Missing Correlation ID Propagation Path
**Reference:** Section 6 (Logging: "correlation IDs (trace_id propagated from API requests)")

**Issue:** Design states trace_id is propagated from API requests, but the architecture includes multiple async boundaries where correlation context can be lost:

- MQTT messages from smart meters (no trace_id at ingestion point)
- Kafka messages (must manually propagate in message headers)
- Utility webhook (external system may not provide trace_id)

**Impact:** Debugging cross-service issues (e.g., "why did this specific DR event fail?") requires manually correlating logs across services using timestamps and facility_id.

**Recommendations:**
1. Generate trace_id at Ingestion Service for MQTT messages (include in Kafka message headers)
2. Extract or generate trace_id in webhook handler (utility_request_id from webhook payload or generate new)
3. Document trace_id propagation contract for each service boundary
4. Use OpenTelemetry SDK for automatic context propagation

---

#### M2. Autoscaling HPA Based Solely on CPU
**Reference:** Section 7 (Availability: "HPA based on CPU utilization, target 70%")

**Issue:** CPU-based autoscaling may not trigger during I/O-bound failures:
- InfluxDB write backpressure (high write latency, low CPU)
- PostgreSQL slow query (database lock contention, low application CPU)
- Kafka consumer lag (network-bound, low CPU)

**Scenario:** Aggregation Service experiences InfluxDB write timeouts → Kafka lag accumulates → CPU remains at 50% → HPA does not scale → manual intervention required.

**Recommendations:**
1. Add custom metrics to HPA: Kafka consumer lag, API p95 latency, InfluxDB write error rate
2. Use KEDA (Kubernetes Event-Driven Autoscaling) for Kafka lag-based scaling
3. Set minimum replicas=3 for critical services (prevent single-point-of-failure during scale-up delay)

---

#### M3. Database Migration Rollback Strategy Not Specified
**Reference:** Section 6 (Deployment: "Flyway SQL scripts run before deployment")

**Issue:** Migrations run before application deployment, but no rollback strategy defined if:
- Application deployment fails after migration applied
- Migration introduces breaking schema change that new code depends on

**Scenario:** Migration adds NOT NULL column to `facilities` table → old application version crashes on SELECT → zero-downtime deployment violated.

**Recommendations:**
1. Use expand-contract pattern: Add nullable column first, populate data, make NOT NULL in future migration
2. Test migrations against production snapshot in staging environment
3. Document rollback SQL scripts for each migration (Flyway doesn't auto-generate)
4. Consider blue-green database strategy for high-risk schema changes

---

#### M4. Forecast Confidence Intervals Not Used in DR Decision
**Reference:** Section 4 (load_forecasts table includes confidence_interval_upper/lower), Section 3 (DR Coordinator calculates load reduction strategy)

**Issue:** Design stores forecast confidence intervals but does not specify how DR Coordinator uses them in decision-making.

**Scenario:** Forecast predicts 500kW load with ±200kW confidence interval (wide uncertainty due to weather variability). DR Coordinator requests 100kW reduction based on point estimate → actual load comes in at 300kW (lower bound) → unnecessary load reduction disrupts operations.

**Recommendations:**
1. Use confidence_lower for DR strategy calculation (conservative approach)
2. Add `forecast_quality` score to DR event record (audit decision rationale)
3. Alert facility managers when confidence interval >30% of predicted load (manual review)

---

#### M5. CloudWatch Log Retention 30 Days - Insufficient for Incident Analysis
**Reference:** Section 6 (Logging: "30-day retention")

**Issue:** Complex incidents (e.g., subtle data corruption, billing disputes) may require log analysis beyond 30-day window.

**Scenario:** Utility claims facility failed DR participation 45 days ago → logs already deleted → cannot prove compliance or dispute charges.

**Recommendations:**
1. Archive structured logs to S3 after 30 days (retain 2 years for compliance)
2. Use tiered retention: DEBUG logs 7 days, INFO logs 90 days, ERROR logs 1 year
3. Export DR event audit logs to immutable storage (S3 Object Lock) immediately

---

### TIER 4: MINOR IMPROVEMENTS

#### N1. Metrics Collection Method Not Specified
**Reference:** Section 7 (Monitoring: "Metrics collected via Prometheus")

**Observation:** Design states Prometheus metrics but does not specify:
- Pull vs. push model
- Service discovery mechanism (Kubernetes annotations?)
- Metric naming conventions

**Recommendation:** Document Prometheus exporter endpoints (`/metrics`), use standard naming (e.g., `energy_api_request_duration_seconds`).

---

#### N2. Auth0 JWT Validation Details Missing
**Reference:** Section 7 (Security: "API authentication via JWT tokens (Auth0)")

**Observation:** No discussion of:
- JWT signature validation (JWKS endpoint configuration)
- Token expiration handling (refresh token flow)
- Authorization claims mapping (facility_id scoping)

**Recommendation:** Document JWT validation middleware configuration, specify required claims (e.g., `facility_ids[]` for access control).

---

## Summary

This red team reliability analysis identified **5 critical system-wide failure scenarios** that could lead to data loss, compliance violations, or prolonged outages:

1. **PostgreSQL SPOF** - Complete control plane collapse requiring Multi-AZ replication
2. **DR workflow state management** - Partial execution risks requiring Saga pattern
3. **InfluxDB write failures** - Silent data loss requiring DLQ and enhanced monitoring
4. **Ingestion service Kafka dependency** - Memory exhaustion requiring circuit breakers
5. **WeatherAPI outage** - Forecast failure requiring multi-provider fallback

The analysis also found **5 significant issues** with partial impact (dashboard staleness, BMS timeouts, Kafka rebalancing, cache invalidation, backup validation) and **5 moderate operational improvements**.

**Highest Priority Countermeasures:**
1. Deploy PostgreSQL Multi-AZ with read replicas (addresses C1)
2. Implement DR Coordinator saga pattern with idempotency (addresses C2)
3. Add InfluxDB write DLQ and enhanced alerting (addresses C3)
4. Implement circuit breakers for all external dependencies (addresses C4, C5, S2)
5. Add comprehensive timeout configurations across all service boundaries

The red team approach successfully uncovered cascading failure scenarios (e.g., PostgreSQL failure during active DR event) and implicit assumptions (e.g., "Kafka is always available") that standard reviews might overlook.
