# Reliability Design Review: Smart Energy Management System

## Phase 1: Structural Analysis

### System Components
1. **Data Ingestion Layer**
   - Smart Meters (MQTT publishers)
   - AWS IoT Core (MQTT broker)
   - Ingestion Service (validator/forwarder)
   - Kafka Topic: sensor-readings (partitioned by facility ID)

2. **Processing Layer**
   - Aggregation Service (Kafka consumer, rollup computation)
   - Forecast Service (ML model execution, 15-minute intervals)
   - DR Coordinator (webhook listener, BMS command orchestrator)

3. **Storage Layer**
   - PostgreSQL 15 (single primary instance - metadata, forecasts, DR events)
   - InfluxDB 2.x (time-series data)
   - Redis 7.0 (caching, sessions)
   - S3 (daily snapshots)

4. **API & Presentation Layer**
   - API Gateway (REST endpoints)
   - Application Load Balancer
   - React Frontend (30-second polling)

### External Dependencies & Criticality
- **Critical**: Utility Grid API (DR event webhooks) - operational necessity for core feature
- **Critical**: BMS SOAP API (HVAC/lighting control) - required for DR event execution
- **High**: AWS IoT Core (data ingestion entry point) - single point of failure for all sensor data
- **High**: WeatherAPI.com (forecast inputs) - required for predictive models
- **Moderate**: Auth0 (authentication) - impacts user access but not sensor data flow

### Data Flow Paths
1. **Sensor Data Path**: Meters → IoT Core → Ingestion → Kafka → Aggregation → InfluxDB
2. **Forecast Path**: InfluxDB + WeatherAPI → Forecast Service → PostgreSQL
3. **DR Event Path**: Utility Webhook → DR Coordinator → PostgreSQL + BMS API
4. **User Query Path**: Frontend → API Gateway → PostgreSQL/InfluxDB/Redis

### Explicitly Mentioned Reliability Mechanisms
- Multi-AZ deployment (3 zones) for services
- HPA based on CPU (70% target)
- Exponential backoff for WeatherAPI retries (max 3 attempts)
- Prometheus/Grafana monitoring with alerts (Kafka lag, API error rate, disk usage)
- Rolling update deployment (maxUnavailable: 1)
- InfluxDB retention policy (90 days granular, 2 years downsampled)

---

## Phase 2: Problem Detection

### **TIER 1: CRITICAL ISSUES (System-Wide Impact)**

#### **C1: No Distributed Transaction Coordination for DR Event Execution**
**Reference**: Section 3 (DR Coordinator), Section 4 (dr_events table), Section 6 (Error Handling)

**Failure Scenario**:
When DR Coordinator processes a utility webhook, it must:
1. Create/update `dr_events` record in PostgreSQL
2. Send HVAC/lighting control commands to BMS API
3. Update `achieved_reduction_kw` and status after execution

The design lacks coordination between these steps. If BMS API call succeeds but PostgreSQL update fails (network partition, database failure), the system will have physically executed load reduction without recording it. This creates:
- Inconsistent state between physical world and database
- Inability to accurately report DR compliance to utility
- Revenue loss (unreported DR participation cannot be billed)
- Incorrect baseline calculations for future events

**Operational Impact**:
- **Data Integrity**: Financial records (achieved_reduction_kw) out of sync with reality
- **Recovery Complexity**: No mechanism to detect or reconcile divergence
- **Compliance Risk**: Regulatory reporting inaccuracies

**Countermeasures**:
1. **Implement Saga Pattern**:
   - Step 1: Write `dr_events` record with `status=scheduled`
   - Step 2: Send BMS commands
   - Step 3: Update `status=active` with timestamp
   - Step 4: Poll BMS for confirmation, update `achieved_reduction_kw`
   - Compensating transaction: If Step 2 fails, mark `status=failed` and log reason

2. **Add Outbox Pattern for BMS Commands**:
   - Write intended BMS commands to `bms_command_queue` table in same transaction as `dr_events` insert
   - Separate worker process reads queue and executes BMS API calls
   - Mark commands as `sent`/`acknowledged`/`failed` with timestamps
   - Enables audit trail and retry logic

3. **Idempotency for BMS Commands**:
   - Include `dr_event_id` in BMS command payloads
   - BMS Controller should check for duplicate commands within event window
   - Store command execution log with timestamps to prevent double-execution

---

#### **C2: Single Point of Failure - PostgreSQL Primary Instance**
**Reference**: Section 2 (Databases), Section 7 (Availability & Scalability)

**Failure Scenario**:
Design explicitly states "PostgreSQL: Single primary instance (no read replicas)". If this instance fails:
- **Complete loss of write capability** for facilities, users, DR events, forecasts
- **API Gateway failures** for all queries requiring facility metadata or forecast data
- **DR Coordinator cannot create new events** or update statuses
- **Forecast Service cannot store predictions**, breaking 15-minute pipeline

With 99.5% uptime target, this allows **43.8 hours of downtime per year**. PostgreSQL instance failure could easily exceed this budget during recovery from:
- Hardware failure requiring instance replacement (15-60 minutes)
- OS/PostgreSQL patch requiring restart (10-30 minutes)
- Data corruption requiring point-in-time recovery from S3 snapshots (potentially hours)

**Operational Impact**:
- **Revenue Impact**: Cannot participate in DR events during outage (lost incentive payments)
- **User Impact**: Dashboard completely unavailable (all facility metadata in PostgreSQL)
- **Recovery Complexity**: Manual failover process, no automated high availability

**Countermeasures**:
1. **Deploy PostgreSQL with Synchronous Replication**:
   - Primary + synchronous standby in different AZs
   - Use Patroni or AWS RDS Multi-AZ for automated failover (30-60 second failover time)
   - Ensures zero data loss (RPO = 0) for committed transactions

2. **Implement Read Replicas for Query Offloading**:
   - Route forecast queries and dashboard reads to replicas
   - Reduces primary load, improves query performance
   - Enables read availability during primary maintenance windows

3. **Add Connection Pooling with Failover Logic**:
   - Use PgBouncer or application-level connection pools with health checks
   - Configure automatic retry to standby endpoint on primary failure
   - Set appropriate timeout values (connection timeout < 10s)

4. **Define RPO/RTO and Test Recovery**:
   - Document target RPO (recommend: 0 seconds with sync replication)
   - Document target RTO (recommend: <2 minutes with automated failover)
   - Schedule quarterly failover drills to validate automation

---

#### **C3: Missing Idempotency Keys for Kafka Message Processing**
**Reference**: Section 3 (Data Flow), Section 3 (Aggregation Service)

**Failure Scenario**:
Aggregation Service consumes from Kafka topic `sensor-readings` and writes rollups to InfluxDB. The design does not specify:
- Idempotency mechanism for duplicate message processing
- Consumer offset management strategy
- Handling of Kafka consumer rebalances

If Aggregation Service crashes after writing to InfluxDB but before committing Kafka offset:
- Consumer restarts and reprocesses same messages
- **Duplicate rollup writes to InfluxDB** (overwrites may corrupt `max_power_kw` calculations if using additive operations)
- **Incorrect energy totals** (`total_energy_kwh` double-counted)
- **Financial impact**: Overreported consumption leads to inaccurate cost optimization recommendations

If network partition causes consumer group rebalance during processing:
- Multiple consumers may process same partitions concurrently
- Race conditions in InfluxDB writes
- Non-deterministic rollup values

**Operational Impact**:
- **Data Accuracy**: Core metrics (energy consumption, cost) unreliable
- **User Trust**: Dashboard showing inflated/deflated values erodes confidence
- **Debugging Difficulty**: Intermittent duplicate processing hard to trace

**Countermeasures**:
1. **Add Deduplication at Ingestion**:
   - Include `message_id` (UUID) in MQTT payload from smart meters
   - Ingestion Service writes `message_id` to Redis with 5-minute TTL before forwarding to Kafka
   - Check Redis before forwarding; skip duplicates

2. **Implement Exactly-Once Kafka Semantics**:
   - Enable Kafka idempotent producer for Ingestion Service
   - Use Kafka Streams with exactly-once processing guarantee for Aggregation Service
   - Commit offsets transactionally with InfluxDB writes (requires InfluxDB 2.x transactional writes or external coordination)

3. **Add Idempotency at InfluxDB Write Layer**:
   - Include `message_id` as tag in InfluxDB points
   - Use InfluxDB's native duplicate detection (overwrites with same timestamp+tags)
   - For rollups, compute based on raw readings query, not incremental updates

4. **Implement At-Least-Once with Idempotent Operations**:
   - Design rollup calculations as pure functions of query results (not incremental state)
   - Example: `SELECT mean(active_power_kw) FROM energy_readings WHERE time >= $start AND time < $end GROUP BY time(15m)`
   - Reprocessing same time window produces identical result

---

#### **C4: No Circuit Breaker for External API Dependencies**
**Reference**: Section 2 (Key External Dependencies), Section 6 (Error Handling)

**Failure Scenario**:
The design has critical dependencies on external APIs:
1. **WeatherAPI.com**: Forecast Service queries every 15 minutes for 100 facilities (potentially 100+ API calls)
2. **Utility Grid API**: Webhook source for DR events (design assumes availability)
3. **BMS SOAP API**: Receives control commands from DR Coordinator

Current error handling: "Forecast Service retries WeatherAPI calls with exponential backoff (max 3 attempts)"

If WeatherAPI.com experiences degradation (slow responses, partial failures):
- **Cascading failure**: All Forecast Service instances wait for timeouts, exhausting thread pools
- **Resource exhaustion**: Goroutines blocked on HTTP calls, memory pressure from queued requests
- **Service-wide unavailability**: Forecast Service cannot process any facilities, even those with cached weather data
- **Downstream impact**: DR Coordinator cannot calculate optimal load reduction without forecasts

If BMS API is down during DR event:
- Design states "logs command failures but does not retry (manual intervention required)"
- **DR event failure** with no automated recovery
- **Revenue loss** from missed utility DR program participation
- **Manual intervention required** during time-critical event windows (typical DR notice: 15-30 minutes)

**Operational Impact**:
- **Availability**: External service failure causes internal service failure (violates fault isolation principle)
- **Recovery**: No graceful degradation; complete feature outage
- **Operational Burden**: Manual intervention required during time-sensitive events

**Countermeasures**:
1. **Implement Circuit Breaker Pattern**:
   - Use library like `gobreaker` or `hystrix-go` for each external dependency
   - Configuration:
     - WeatherAPI: Open circuit after 5 consecutive failures or 50% error rate in 1-minute window; half-open after 30 seconds
     - BMS API: Open circuit after 3 consecutive failures; half-open after 10 seconds (shorter window for time-critical DR events)
   - When circuit open, fail fast (return cached data or error) instead of waiting for timeout

2. **Add Timeout Configuration**:
   - WeatherAPI: 5-second connection timeout, 10-second read timeout
   - BMS API: 3-second connection timeout, 5-second command execution timeout
   - Utility Grid API webhook: Return 200 within 5 seconds to prevent webhook retry storms

3. **Implement Graceful Degradation**:
   - **Forecast Service**: If WeatherAPI unavailable, use historical average weather data or previous day's pattern
   - **DR Coordinator**: If BMS API unavailable, attempt direct MQTT command to meters (requires adding backup protocol) or escalate to manual notification system
   - Mark degraded predictions/actions with confidence flag in database

4. **Add Bulkhead Isolation**:
   - Separate goroutine pools for WeatherAPI vs. BMS API calls
   - Limit concurrent external API calls (e.g., max 10 concurrent WeatherAPI requests)
   - Prevent single dependency failure from exhausting all resources

---

#### **C5: Missing Timeout Configuration for Database Queries**
**Reference**: Section 3 (Component Responsibilities), Section 5 (API Endpoints)

**Failure Scenario**:
Design does not specify timeout values for database operations:
- InfluxDB queries for dashboard current readings
- PostgreSQL queries for facility metadata, forecasts, DR events
- Redis cache lookups

If InfluxDB experiences slow query performance (large time range scan, high cardinality aggregation):
- **API Gateway goroutines blocked** waiting for InfluxDB response
- **Resource exhaustion**: All API Gateway workers occupied, cannot serve new requests
- **Cascading failure**: Frontend 30-second polling accumulates retries, multiplying load
- **Complete API unavailability** even for endpoints not using InfluxDB

Example problematic query from dashboard:
```
GET /api/facilities/{facility_id}/current
→ Queries InfluxDB for "latest 15-second reading"
→ If no time bound specified, may scan entire retention window (90 days)
→ With 15-second granularity: 518,400 points per facility
```

**Operational Impact**:
- **User Experience**: Dashboard freezes, appears completely broken
- **Availability**: Single slow query can take down entire API layer
- **Debugging Difficulty**: Requires correlating slow query logs across databases and application logs

**Countermeasures**:
1. **Add Context-Based Timeouts for All Database Operations**:
   ```go
   ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
   defer cancel()
   result, err := influxClient.Query(ctx, query)
   ```
   - InfluxDB queries: 2-second timeout (fast time-series scans)
   - PostgreSQL queries: 5-second timeout for complex joins, 1-second for primary key lookups
   - Redis operations: 500ms timeout (should be in-memory fast)

2. **Enforce Query Time Bounds**:
   - Always specify `WHERE time >= $start AND time < $end` in InfluxDB queries
   - For "current reading" endpoint, query last 1 minute only: `WHERE time >= now() - 1m`
   - Add database-level query timeout settings (PostgreSQL `statement_timeout`, InfluxDB `query-timeout`)

3. **Implement Query Result Size Limits**:
   - Add `LIMIT` clauses to prevent unbounded result sets
   - Configure InfluxDB `max-row-limit` to prevent OOM from large aggregations
   - API layer should paginate large result sets

4. **Add Slow Query Monitoring**:
   - Log queries exceeding threshold (e.g., >500ms)
   - Alert on p99 query latency degradation
   - Include query text and parameters in slow query logs for debugging

---

#### **C6: No Backup/Restore Validation for PostgreSQL**
**Reference**: Section 2 (Infrastructure - S3 for daily snapshots), Section 7 (Availability)

**Failure Scenario**:
Design mentions "S3 for historical data archival (daily snapshots)" but does not specify:
- **Backup scope**: Are these PostgreSQL backups, InfluxDB exports, or both?
- **Backup validation**: Are snapshots tested for recoverability?
- **Restore procedure**: How to restore from S3 snapshots?
- **RPO/RTO**: Design states these should be defined but does not provide values

If PostgreSQL database becomes corrupted (disk failure, bug in migration script, accidental DELETE):
- **Without tested restore procedure**: Recovery time could be hours or days
- **Without validated backups**: Snapshots may be corrupt/incomplete but only discovered during emergency
- **Without defined RPO**: Unclear how much data loss is acceptable (last snapshot was 24 hours ago?)

Real-world failure mode:
1. Flyway migration script runs during deployment (Section 6: "run before deployment")
2. Script contains bug that corrupts foreign key constraints
3. Corruption discovered 6 hours later when DR event fails
4. Attempt to restore from S3 snapshot
5. Snapshot restore fails (missing WAL files, wrong PostgreSQL version)
6. Production outage extends 12+ hours while debugging backup issues

**Operational Impact**:
- **Data Loss Risk**: Unvalidated backups may be unrecoverable
- **Extended Downtime**: Recovery time unknown without tested procedures
- **Compliance**: Cannot meet 99.5% uptime target without reliable DR

**Countermeasures**:
1. **Define and Document RPO/RTO**:
   - **Recommended RPO**: 5 minutes (continuous WAL archival to S3)
   - **Recommended RTO**: 30 minutes (automated restore from S3 + WAL replay)
   - Align with 99.5% uptime target (43.8 hours/year = ~3.6 hours/month)

2. **Implement Point-in-Time Recovery (PITR)**:
   - Enable PostgreSQL continuous archiving: `archive_mode = on`, `archive_command` to S3
   - Take daily base backups + continuous WAL shipping
   - Test restore to specific timestamp (e.g., "5 minutes before corruption")

3. **Automate Backup Validation**:
   - Schedule weekly restore tests in isolated environment
   - Verify restored database integrity: `pg_dump` checksum, row counts, foreign key validation
   - Alert on backup failure or validation failure
   - Document validation results (restore duration, data integrity checks passed)

4. **Add Pre-Deployment Migration Validation**:
   - Test Flyway migrations against production snapshot in staging environment
   - Require manual approval for migrations affecting >10% of rows
   - Implement automatic backup trigger before running migrations
   - Add migration rollback scripts for each forward migration

---

#### **C7: Missing Replication Lag Monitoring and Handling**
**Reference**: Section 2 (Databases - InfluxDB, PostgreSQL), Section 7 (Monitoring)

**Failure Scenario**:
Design does not address replication lag despite having:
- Multi-AZ deployment (implies data replication across zones)
- InfluxDB time-series data with high write throughput (10,000 readings/second)
- Real-time dashboard requirements (30-second polling)

If network partition or resource contention causes InfluxDB replication lag:
- **Dashboard shows stale data** (readings from 5+ minutes ago appear "current")
- **DR Coordinator makes decisions on outdated forecasts** (forecasts based on lagged data)
- **Users perceive incorrect system state** ("power consumption normal" when actually exceeding contract demand)
- **No alerting on staleness** - design only alerts on write throughput, not replication health

PostgreSQL replication lag (if implemented per C2 countermeasures):
- Read replicas serve stale forecast data to API
- DR event status queries return outdated information
- Race condition: Create DR event on primary, immediate query to replica returns 404

**Operational Impact**:
- **Data Correctness**: Decisions based on stale data lead to suboptimal outcomes
- **User Trust**: Dashboard inaccuracies erode confidence in system
- **Incident Detection Delay**: Alerts fire on lagged metrics, missing real-time issues

**Countermeasures**:
1. **Add Replication Lag Monitoring**:
   - InfluxDB: Monitor `replication_lag` metric via Prometheus
   - PostgreSQL: Query `pg_stat_replication.replay_lag` and expose as metric
   - Alert on lag >30 seconds (exceeds dashboard polling interval)
   - Include lag metrics in Grafana dashboard for operational visibility

2. **Implement Read-Your-Writes Consistency**:
   - After creating DR event on primary, use primary for subsequent reads within same request context
   - Add `prefer-primary` query hint for time-sensitive operations
   - Set `synchronous_commit = remote_apply` for PostgreSQL critical writes (trades latency for consistency)

3. **Add Staleness Indicators to API Responses**:
   - Include `data_timestamp` in GET /api/facilities/{id}/current response
   - Frontend highlights stale data (>60 seconds old) with warning indicator
   - API returns 503 if data staleness exceeds acceptable threshold (e.g., >5 minutes)

4. **Implement Lag-Aware Query Routing**:
   - If replication lag >1 minute, automatically route reads to primary (sacrifice read scalability for correctness)
   - Exponential backoff on replica queries during lag spikes
   - Document expected lag during normal operations (baseline for alerting)

---

### **TIER 2: SIGNIFICANT ISSUES (Partial System Impact)**

#### **S1: No Dead Letter Queue for Kafka Poison Messages**
**Reference**: Section 6 (Error Handling - "logs malformed MQTT messages, continues processing")

**Failure Scenario**:
Ingestion Service handles malformed MQTT messages by logging to CloudWatch and continuing. However, if Aggregation Service encounters poison message in Kafka (corrupted data, schema change, edge case bug):
- **Consumer stuck in retry loop**: Processes message, fails, offset not committed, reprocesses same message
- **Partition blocked**: All subsequent messages in partition cannot be processed (head-of-line blocking)
- **Cascading lag**: Kafka consumer lag grows unbounded, triggers alerts
- **Data loss**: Valid messages behind poison message never processed

Example: Smart meter firmware bug sends malformed JSON after power surge affecting 50 meters (all in same facility, same Kafka partition). Aggregation Service cannot parse, blocks partition for that facility. Dashboard shows no data updates for facility, appears as complete outage.

**Operational Impact**:
- **Partial Outage**: Specific facilities affected by poison message have no data updates
- **Manual Intervention**: Requires developer to skip offsets or deploy hotfix
- **Incident Duration**: Could last hours if occurs outside business hours

**Countermeasures**:
1. **Implement Dead Letter Queue (DLQ) Pattern**:
   - After 3 failed processing attempts, move message to `sensor-readings-dlq` topic
   - Commit offset and continue processing subsequent messages
   - Separate consumer monitors DLQ for manual investigation

2. **Add Poison Message Detection**:
   - Track consecutive failures per partition
   - If same offset fails >3 times, automatic DLQ movement
   - Include original message, error details, stack trace in DLQ payload

3. **Implement Schema Validation at Ingestion**:
   - Define JSON schema for MQTT message payload
   - Validate schema before writing to Kafka
   - Reject invalid messages with 400-style response (if protocol supports)
   - Log validation failures with meter ID for meter health monitoring

4. **Add Message Skipping Capability**:
   - Operational endpoint: `POST /admin/kafka/skip-offset` with partition/offset parameters
   - Requires authentication and audit logging
   - Enables quick recovery during incidents without code deployment

---

#### **S2: Insufficient Rate Limiting and Backpressure**
**Reference**: Section 7 (Performance - ingestion throughput: 10,000 readings/second)

**Failure Scenario**:
Design specifies throughput target (10,000 readings/sec) but does not describe:
- What happens when meters exceed this rate (malfunction, attack, flash crowd)
- Backpressure mechanism to protect downstream systems
- Rate limiting per facility or per meter

If facility experiences sensor malfunction causing 100x message rate:
- **Kafka partition hotspot**: Single facility partition overwhelmed (10,000 msg/sec from one source)
- **InfluxDB write queue overflow**: Cannot keep up with write rate, in-memory buffer grows
- **OOM crash**: Aggregation Service crashes from memory pressure
- **Service restart loop**: Kubernetes restarts service, immediately overwhelmed again
- **Collateral damage**: Other facilities sharing same Aggregation Service instance affected

If malicious actor compromises meter credentials:
- **Resource exhaustion attack**: Flood system with bogus readings
- **Cost implications**: AWS IoT Core charges per message, unbounded cost
- **Data pollution**: Garbage data corrupts aggregates and forecasts

**Operational Impact**:
- **Availability**: Single misbehaving meter can crash entire ingestion pipeline
- **Cost**: Uncontrolled message volume increases infrastructure costs
- **Data Quality**: Bad data poisons ML models and analytics

**Countermeasures**:
1. **Implement Multi-Level Rate Limiting**:
   - **Meter-level**: 10 messages/second per meter (15-second interval = 0.067 msg/sec expected, 150x headroom)
   - **Facility-level**: 1,000 messages/second per facility (assumes <100 meters per facility)
   - **System-level**: 10,000 messages/second global (design target)
   - Use token bucket algorithm with Redis for distributed rate limiting

2. **Add Backpressure to Ingestion Service**:
   - Monitor Kafka producer buffer utilization
   - When buffer >80% full, return `503 Service Unavailable` to IoT Core
   - IoT Core will buffer messages and implement exponential backoff (MQTT QoS 1)
   - Prevents cascading failure to downstream services

3. **Implement Kafka Quota Management**:
   - Configure per-client quotas in Kafka (limit produce rate)
   - Set quota to 150% of expected rate per facility
   - Kafka will throttle producers exceeding quota, protecting brokers

4. **Add Anomaly Detection for Message Rates**:
   - Track per-meter message rate in 1-minute windows
   - Alert on >10x baseline rate (potential malfunction)
   - Automatic meter quarantine: Add to Redis blocklist, reject messages for 15 minutes
   - Notification to facility manager for manual inspection

---

#### **S3: No Health Checks for Kubernetes Deployments**
**Reference**: Section 2 (Infrastructure - Kubernetes on EKS), Section 7 (Availability - Multi-AZ, HPA)

**Failure Scenario**:
Design describes Kubernetes deployment but does not specify:
- Liveness probes (detect crashed/deadlocked processes)
- Readiness probes (detect not-yet-ready or degraded instances)
- Startup probes (handle slow-starting services like Forecast Service with ML model loading)

Without health checks:
- **Kubernetes routes traffic to failed instances**: Pod process crashes but container still running → 50% of requests fail
- **Deployment rollout serves traffic to broken pods**: New version has bug in initialization → all traffic routed to broken pods immediately
- **Cascading failures**: HPA scales up during high load, new pods serve traffic before Kafka consumers join group → connection errors
- **Extended outages**: Liveness probe would restart pod in 30 seconds, without it pod stays broken until manual intervention

Real scenario:
1. Forecast Service pod starts
2. Loads 500MB ML model from S3 (takes 60 seconds)
3. Kubernetes immediately marks pod as Ready
4. API Gateway routes forecast queries to pod
5. Pod returns 500 errors ("model not loaded")
6. Load balancer continues sending traffic for several minutes

**Operational Impact**:
- **Availability**: Traffic routed to unhealthy pods causes user-facing errors
- **Deployment Risk**: Bad deployments cause immediate full outages
- **Recovery Time**: Manual intervention required instead of automatic restart

**Countermeasures**:
1. **Implement Kubernetes Probes for All Services**:

   **Ingestion Service**:
   ```yaml
   livenessProbe:
     httpGet:
       path: /health/live
       port: 8080
     periodSeconds: 10
     failureThreshold: 3
   readinessProbe:
     httpGet:
       path: /health/ready  # checks Kafka connectivity
       port: 8080
     periodSeconds: 5
     failureThreshold: 2
   ```

   **Forecast Service**:
   ```yaml
   startupProbe:  # Allow 2 minutes for model loading
     httpGet:
       path: /health/startup
       port: 8080
     periodSeconds: 10
     failureThreshold: 12
   livenessProbe:
     httpGet:
       path: /health/live
       port: 8080
     periodSeconds: 30
   readinessProbe:
     httpGet:
       path: /health/ready  # checks InfluxDB, PostgreSQL, WeatherAPI
       port: 8080
     periodSeconds: 10
     failureThreshold: 2
   ```

2. **Implement Deep Health Checks**:
   - `/health/live`: Process alive, goroutines not deadlocked
   - `/health/ready`: Dependencies reachable (Kafka, databases, critical APIs)
   - Return 200 only if service can successfully handle requests
   - Include dependency status in response body for debugging

3. **Configure Graceful Shutdown**:
   - Handle SIGTERM signal from Kubernetes
   - Stop accepting new requests immediately
   - Drain in-flight requests (timeout: 30 seconds)
   - Close database connections and Kafka consumers gracefully
   - Return from main() to trigger clean pod termination

4. **Add Deployment Safety via Readiness Gates**:
   - Configure `minReadySeconds: 30` to wait before marking pod available
   - Use progressive rollout: 1 pod → wait 2 minutes → next pod (detect issues early)
   - Integrate with Prometheus metrics: Fail readiness if error rate >5% in last minute

---

#### **S4: Missing Retry Logic and Error Handling for DR Coordinator**
**Reference**: Section 6 (Error Handling - "BMS Controller logs command failures but does not retry")

**Failure Scenario**:
DR Coordinator receives utility webhook and must send HVAC/lighting commands to BMS API. Design states failures are logged but not retried, requiring manual intervention.

Typical DR event timeline:
- T-15min: Utility sends webhook notification
- T-0min: Event start time
- T+60min: Event end time

If BMS API call fails at T-10min due to transient network issue:
- **No automated retry**: DR event cannot be executed
- **Manual intervention required**: On-call engineer paged
- **Time-sensitive response needed**: Only 10 minutes remain to execute load reduction
- **Revenue loss**: Missed DR participation (typical incentive: $500-5000 per event depending on facility size)
- **Utility relationship damage**: Unreliable DR participant may be excluded from future programs

Common transient failures:
- BMS API gateway restart (30-second outage)
- Network packet loss (single request timeout)
- BMS system busy (returns 503, retry after 10 seconds)

**Operational Impact**:
- **Financial**: Direct revenue loss from missed DR events
- **Operational Burden**: Requires 24/7 on-call for time-critical manual intervention
- **Reliability**: Single transient failure causes feature outage

**Countermeasures**:
1. **Implement Retry with Exponential Backoff for BMS Commands**:
   ```go
   maxAttempts := 5
   baseDelay := 2 * time.Second
   for attempt := 1; attempt <= maxAttempts; attempt++ {
       err := sendBMSCommand(cmd)
       if err == nil {
           return success
       }
       if !isRetriable(err) {  // e.g., 400 Bad Request
           return failure
       }
       if attempt < maxAttempts {
           delay := baseDelay * time.Duration(math.Pow(2, attempt-1))
           jitter := time.Duration(rand.Int63n(int64(delay / 2)))
           time.Sleep(delay + jitter)
       }
   }
   ```

2. **Add Retry Deadline Based on Event Timeline**:
   - Calculate retry deadline: `event_start - 5 minutes` (need buffer for command execution)
   - Stop retrying if current time exceeds deadline
   - Escalate to manual notification if deadline approached and retries failing

3. **Implement Fallback Mechanisms**:
   - **Primary**: BMS SOAP API (current design)
   - **Fallback 1**: BMS REST API (if available, often more reliable than legacy SOAP)
   - **Fallback 2**: Direct MQTT commands to smart meters (requires pre-configured DR profiles on meters)
   - **Fallback 3**: Send SMS/email alert to facility manager with manual override instructions

4. **Add Retry Observability**:
   - Log each retry attempt with attempt number, error, next retry time
   - Metric: `bms_command_retry_count` with labels for success/failure
   - Alert if retry exhaustion rate >10% (indicates systemic BMS reliability issue)

---

#### **S5: No Database Connection Pool Configuration**
**Reference**: Section 2 (Databases), Section 7 (Auto-scaling: HPA based on CPU 70%)

**Failure Scenario**:
Design enables HPA to scale API Gateway and services based on CPU utilization, but does not specify database connection pool settings.

If load spike triggers scale-up from 3 → 20 API Gateway pods:
- **Each pod opens default connection pool** (e.g., Go `database/sql` default: unlimited connections)
- **20 pods × 10 connections/pod = 200 connections to PostgreSQL**
- **PostgreSQL default `max_connections`: 100** → new pods cannot connect
- **Connection acquisition failures**: `pq: sorry, too many clients already`
- **API requests fail with 500 errors** despite successful scale-up
- **User-visible outage**: Dashboard unusable during peak demand

InfluxDB connection exhaustion scenario:
- 20 Aggregation Service pods each open persistent InfluxDB client
- Each client maintains connection pool
- InfluxDB hits file descriptor limit (ulimit) or memory limit
- New connections rejected, writes fail
- Kafka consumer lag grows unbounded

**Operational Impact**:
- **Scale-Up Failures**: Auto-scaling makes problem worse instead of better
- **Availability**: Outage during peak load (worst possible time)
- **Resource Waste**: Kubernetes pods running but unable to serve requests

**Countermeasures**:
1. **Configure Connection Pools with Limits**:
   ```go
   // PostgreSQL connection pool (per pod)
   db.SetMaxOpenConns(5)  // Limit per pod
   db.SetMaxIdleConns(2)  // Keep some warm connections
   db.SetConnMaxLifetime(30 * time.Minute)  // Refresh connections
   db.SetConnMaxIdleTime(5 * time.Minute)   // Close idle connections
   ```

   With 20 pods: `20 pods × 5 conns = 100 total connections` → under PostgreSQL limit

2. **Use External Connection Pooler (PgBouncer)**:
   - Deploy PgBouncer in front of PostgreSQL
   - Configure transaction pooling mode (connections shared across transactions)
   - Support 1000+ client connections with only 20 backend connections
   - Enables much higher scale-out without database resource exhaustion

3. **Add Connection Health Checks**:
   - Ping database connection before use (`db.PingContext()`)
   - Include database connectivity in readiness probe
   - Pods fail readiness if cannot acquire connection → Kubernetes stops routing traffic

4. **Implement Connection Circuit Breaker**:
   - Track connection acquisition failures
   - Open circuit after 5 consecutive failures
   - Return 503 immediately instead of blocking on connection pool
   - Allows fast failure and retry at load balancer level

5. **Document Connection Budget**:
   ```
   PostgreSQL max_connections: 200 (increased from default 100)
   - API Gateway: 10 pods × 5 conns = 50
   - Forecast Service: 5 pods × 5 conns = 25
   - DR Coordinator: 3 pods × 5 conns = 15
   - Reserved for admin/monitoring: 10
   - Reserve for scale-up: 100
   ```

---

#### **S6: No Correlation ID Propagation for Distributed Tracing**
**Reference**: Section 6 (Logging - "correlation IDs (trace_id propagated from API requests)")

**Failure Scenario**:
Design mentions trace_id propagation from API requests but does not specify:
- Trace ID generation at system entry points (IoT Core, webhooks)
- Propagation mechanism through Kafka, external APIs
- Trace ID inclusion in database queries, external API calls

When debugging production issue (e.g., "Why did DR event #12345 fail?"):
- **API logs have trace_id** from POST /api/dr-events request
- **DR Coordinator logs missing trace_id** (triggered by webhook, not API)
- **BMS API calls not tagged** (cannot correlate to originating event)
- **Kafka messages not tagged** (cannot correlate sensor readings to facility)
- **InfluxDB queries not logged with trace_id** (cannot identify slow queries for specific user request)

This forces manual correlation:
1. Search CloudWatch logs for event_id
2. Find timestamp range
3. Search all services' logs in that time range
4. Manually correlate by guessing which log lines relate to the incident
5. Process takes 30+ minutes for what should be 30-second trace lookup

**Operational Impact**:
- **Debugging Time**: 10-50x slower incident investigation
- **Incident Duration**: Extended MTTR (Mean Time To Resolution)
- **Knowledge Loss**: Difficult to perform root cause analysis post-incident

**Countermeasures**:
1. **Generate Trace ID at All Entry Points**:
   - **API requests**: Extract from `X-Trace-Id` header, generate UUID if missing
   - **Utility webhooks**: Generate UUID at webhook handler entry
   - **MQTT messages**: Extract from message metadata or generate at Ingestion Service
   - **Scheduled jobs**: Generate UUID per job execution

2. **Propagate Trace ID Through All Hops**:
   - **Kafka messages**: Include `trace_id` in message headers (not payload)
   - **External API calls**: Add `X-Trace-Id` header to WeatherAPI, BMS API requests
   - **Database queries**: Include trace_id in SQL comments for query log correlation
     ```sql
     /* trace_id: 550e8400-e29b-41d4-a716-446655440000 */
     SELECT * FROM facilities WHERE id = $1
     ```
   - **Goroutine spawning**: Copy trace_id to child context

3. **Structured Logging with Trace Context**:
   ```go
   log.WithFields(logrus.Fields{
       "trace_id": ctx.Value("trace_id"),
       "facility_id": facilityID,
       "event_id": eventID,
   }).Info("Sending BMS command")
   ```

4. **Integrate Distributed Tracing System**:
   - Deploy Jaeger or AWS X-Ray
   - Instrument code with OpenTelemetry SDK
   - Create spans for: HTTP handlers, Kafka consume/produce, database queries, external API calls
   - Visualize complete request flow from entry to completion
   - Enable query by trace_id to see all related operations across services

---

#### **S7: Insufficient Forecast Service Error Handling**
**Reference**: Section 3 (Forecast Service - runs every 15 minutes), Section 6 (Error Handling - WeatherAPI retry)

**Failure Scenario**:
Forecast Service runs ML model every 15 minutes to predict next 24 hours. Design only mentions error handling for WeatherAPI calls, not:
- Model inference failures (NaN/Inf values, model file corruption, OOM during inference)
- InfluxDB query failures (missing data, query timeout)
- PostgreSQL write failures (unique constraint violation, disk full)

If InfluxDB has no data for facility (new facility, sensor outage):
- **Query returns empty result set**
- **LSTM model receives insufficient input sequence** (requires minimum historical window, e.g., 7 days)
- **Model inference fails** or produces garbage output (extrapolates from 0 data points)
- **Garbage forecast written to PostgreSQL** (`predicted_load_kw = NaN` or negative values)
- **DR Coordinator uses invalid forecast** → calculates impossible load reduction strategy
- **DR event fails** with confusing error messages

If model file corrupted in production (rare but happens: disk bit flip, incomplete S3 download):
- **All facilities fail forecasting** (shared model file)
- **No forecasts generated for 15 minutes** (until next run)
- **DR events cannot be executed** (missing dependency)
- **No automated recovery** (requires manual model redeployment)

**Operational Impact**:
- **DR Feature Outage**: Cannot execute demand response without forecasts
- **Data Quality**: Invalid forecasts pollute database
- **Silent Failures**: Errors not visible until downstream component fails

**Countermeasures**:
1. **Add Input Validation for Model Inference**:
   ```go
   // Check sufficient historical data
   if len(historicalReadings) < minRequiredDataPoints {
       log.Warn("Insufficient data for forecast", "facility_id", facilityID)
       return ErrInsufficientData  // Skip forecast, retry next cycle
   }

   // Validate input ranges
   for _, reading := range historicalReadings {
       if reading.PowerKW < 0 || reading.PowerKW > maxPhysicallyPossible {
           return ErrInvalidInputData
       }
   }
   ```

2. **Add Output Validation for Model Predictions**:
   ```go
   // Validate model output
   if math.IsNaN(prediction.LoadKW) || math.IsInf(prediction.LoadKW, 0) {
       log.Error("Model produced invalid output", "facility_id", facilityID)
       return ErrInvalidPrediction
   }

   // Sanity check against historical range
   if prediction.LoadKW > facility.ContractDemandKW * 2 {
       log.Warn("Prediction exceeds 2x contract demand", "facility_id", facilityID)
       // Use fallback: historical average for same time period
   }
   ```

3. **Implement Forecast Fallback Strategy**:
   - **Primary**: LSTM model prediction
   - **Fallback 1**: Previous week same time (seasonal pattern)
   - **Fallback 2**: Previous day same time (daily pattern)
   - **Fallback 3**: Historical average for time-of-day
   - Store fallback method used in `load_forecasts` table for audit

4. **Add Model Health Checks**:
   - Verify model file checksum on startup
   - Run inference on synthetic test data during initialization
   - Track per-facility forecast success rate
   - Alert if facility forecast failure rate >20% over 1 hour

5. **Graceful Handling of Partial Failures**:
   - Process facilities independently (failure for facility A doesn't block facility B)
   - Use goroutine pool with panic recovery
   - Write successful forecasts even if some facilities fail
   - Separate metric: `forecast_success_count` vs `forecast_failure_count` by facility

---

### **TIER 3: MODERATE ISSUES (Operational Improvement)**

#### **M1: No SLO/SLA Definitions with Error Budgets**
**Reference**: Section 7 (Performance - latency targets), Section 7 (Availability - 99.5% uptime target)

**Gap Analysis**:
Design provides performance targets (p95 latency, throughput) and availability target (99.5%) but lacks:
- **Service Level Indicators (SLIs)**: Specific metrics measured to track service quality
- **Service Level Objectives (SLOs)**: Target values for SLIs
- **Error budgets**: Allowed failure rate derived from SLOs
- **Alerting strategy**: When to page on-call vs file ticket

Current metrics (Section 7):
- Dashboard API latency: p95 < 500ms
- Kafka consumer lag
- API error rate > 5% alert

These are disconnected targets, not cohesive SLO framework.

**Impact**:
- **Unclear reliability expectations**: 99.5% uptime allows 43.8 hours downtime/year, but when is it acceptable?
- **Alert fatigue**: No error budget means every incident triggers same urgency
- **No prioritization**: All failures treated equally (API timeout = database outage = slow query)

**Recommendations**:
1. **Define SLIs/SLOs for Each Critical User Journey**:

   **User Journey 1: Dashboard Monitoring**
   - SLI: Availability of GET /api/facilities/{id}/current
   - SLO: 99.5% of requests return 200 status with latency <1s (measured over 30-day window)
   - Error budget: 0.5% = 216 minutes of errors per 30 days

   **User Journey 2: DR Event Execution**
   - SLI: Success rate of DR event execution (BMS commands delivered)
   - SLO: 99.9% of DR events successfully execute load reduction
   - Error budget: 0.1% = 1 failed event per 1000 events

   **User Journey 3: Data Freshness**
   - SLI: Percentage of facilities with data updated within 60 seconds
   - SLO: 99% of facilities have fresh data
   - Error budget: 1% = up to 10 facilities (out of 1000) can have stale data

2. **Implement Error Budget Policy**:
   - **100-75% budget remaining**: Normal operations, focus on feature development
   - **75-25% budget remaining**: Slow down risky changes, increase testing
   - **25-0% budget remaining**: Freeze feature deployments, focus on reliability improvements
   - **Budget exhausted**: Incident review, mandatory reliability sprint

3. **Align Alerting with Error Budgets**:
   - **Page on-call**: Error budget burn rate predicts budget exhaustion in <4 hours
   - **File ticket**: Error budget burn rate predicts exhaustion in 4-24 hours
   - **Monitor only**: Error budget burn rate within normal consumption

4. **Track and Report SLO Compliance**:
   - Daily dashboard: Current error budget consumption vs remaining
   - Monthly review: SLO compliance, budget spent, largest incidents
   - Quarterly: Adjust SLOs based on actual performance (too strict = unnecessary toil, too loose = poor user experience)

---

#### **M2: Missing Capacity Planning and Load Testing**
**Reference**: Section 7 (Performance targets), Section 7 (Auto-scaling: HPA based on CPU)

**Gap Analysis**:
Design specifies performance targets (10,000 readings/sec, p95 < 500ms) but does not describe:
- **Capacity validation**: Has the system been load tested to these targets?
- **Resource sizing**: How many pods/nodes required for target throughput?
- **Bottleneck analysis**: Which component fails first under load?
- **Growth planning**: What happens when facilities scale 2x, 10x?

Auto-scaling based on CPU (70% target) is insufficient because:
- **CPU may not be bottleneck**: Database connections, memory, network could saturate first
- **No scale-up testing**: Does scaling from 3 → 10 pods actually increase throughput?
- **Kafka consumer group lag**: Adding consumers doesn't help if already at partition count limit

**Impact**:
- **Unvalidated performance claims**: Cannot guarantee SLOs under load
- **Production surprises**: Black Friday-style traffic spikes cause unexpected failures
- **Inefficient scaling**: Auto-scale triggers but doesn't improve throughput (waste cost)

**Recommendations**:
1. **Conduct Load Testing for Each Service**:

   **Ingestion Service Load Test**:
   - Simulate 10,000 MQTT messages/second from test harness
   - Measure: Kafka produce latency, message drop rate, CPU/memory utilization
   - Identify bottleneck: Network I/O, Kafka client buffer, goroutine count
   - Document: "Ingestion Service handles 10K msg/sec on 3 pods (2 CPU, 4GB RAM each)"

   **API Gateway Load Test**:
   - Simulate 1,000 concurrent users polling dashboard (GET /current)
   - Measure: p50/p95/p99 latency, error rate, database connection pool saturation
   - Identify breaking point: "API Gateway sustains 500 req/sec per pod before connection pool exhaustion"

   **Forecast Service Load Test**:
   - Run model inference for 100 facilities concurrently
   - Measure: Completion time, memory peak, InfluxDB query duration
   - Validate: "Completes within 5-minute target with 5 pods"

2. **Document Capacity Model**:
   ```
   Target: 1000 facilities, 10,000 sensors
   Sensor data rate: 10K readings/sec (peak), 5K avg

   Required capacity:
   - Ingestion: 3 pods (2 CPU, 4GB) for 10K peak
   - Aggregation: 5 pods (4 CPU, 8GB) for Kafka processing + InfluxDB writes
   - API Gateway: 10 pods (1 CPU, 2GB) for 500 req/sec = 5000 req/sec total
   - Forecast Service: 5 pods (8 CPU, 16GB) for ML model inference

   Growth headroom:
   - 2x growth: No changes required (within auto-scale limits)
   - 10x growth: Increase Kafka partitions (32 → 320), InfluxDB sharding required
   ```

3. **Implement Multi-Metric Auto-scaling**:
   - **Current**: CPU >70% → scale up
   - **Enhanced**:
     - CPU >70% OR memory >80% OR Kafka lag >5000 → scale up
     - Custom metric: API request queue depth >100 → scale up
     - Scale-up cooldown: 3 minutes (prevent thrashing)
     - Scale-down cooldown: 10 minutes (smooth load decreases)

4. **Schedule Regular Load Testing**:
   - Quarterly load test in staging environment
   - Increase load by 20% each quarter (stress test growth scenarios)
   - Document performance regression if latency degrades
   - Update capacity model based on test results

---

#### **M3: Missing Incident Response Runbooks**
**Reference**: Section 7 (Monitoring - alerts configured)

**Gap Analysis**:
Design configures alerts (Kafka lag, API error rate, disk usage) but does not specify:
- **Incident response procedures**: What should on-call engineer do when paged?
- **Escalation paths**: When to escalate to senior engineer, vendor support, management?
- **Diagnostic playbooks**: How to debug common failure scenarios?
- **Recovery procedures**: Step-by-step restoration instructions

When on-call receives alert "Kafka lag > 10,000 messages":
- **No context**: Is this normal during deployment? Poison message? Consumer crash?
- **No investigation steps**: Check consumer logs? Inspect Kafka topic? Restart pods?
- **No mitigation**: Should I scale up consumers? Skip offsets? Drain topic?
- **Result**: On-call spends 30 minutes Googling instead of following documented procedure

**Impact**:
- **Extended MTTR**: Incident resolution takes 2-5x longer without procedures
- **Inconsistent response**: Different on-call engineers try different approaches
- **Knowledge loss**: Tribal knowledge not documented, lost when engineers leave

**Recommendations**:
1. **Create Runbooks for Each Alert**:

   **Alert: Kafka Consumer Lag > 10,000**
   ```markdown
   ## Context
   - Normal lag: <1000 messages (15 seconds of data)
   - Warning threshold: 5000 messages (trigger ticket)
   - Critical threshold: 10,000 messages (page on-call)

   ## Investigation Steps
   1. Check consumer group status:
      kubectl logs -l app=aggregation-service --tail=100 | grep ERROR
   2. Identify stuck partition:
      kafka-consumer-groups --describe --group aggregation-service
   3. Check for poison message:
      kafka-console-consumer --topic sensor-readings --partition X --offset Y --max-messages 1

   ## Common Causes
   - Poison message in partition → See "Poison Message Runbook"
   - Consumer pod crash loop → Check pod events, resource limits
   - InfluxDB write slowness → Check InfluxDB query performance dashboard

   ## Mitigation
   - Short-term: Scale up Aggregation Service pods (HPA override)
   - Medium-term: Skip poison message offset (see runbook)
   - Long-term: Deploy fix for message parsing bug

   ## Escalation
   - If lag continues growing after 30 minutes → Page senior engineer
   - If affects >50% of facilities → Trigger incident response (severity 1)
   ```

2. **Document Common Incident Scenarios**:
   - **Database failover procedure** (PostgreSQL primary failure)
   - **DR event execution failure** (BMS API down)
   - **InfluxDB data loss recovery** (restore from S3 snapshots)
   - **Deployment rollback** (new version causing errors)
   - **External API outage** (WeatherAPI, Utility Grid API)

3. **Create Troubleshooting Decision Trees**:
   ```
   Dashboard shows no data for facility X:
   ├─ Check last InfluxDB write timestamp
   │  ├─ No recent writes → Check Aggregation Service logs
   │  │  ├─ Consumer not processing partition → Restart consumer pod
   │  │  └─ Writes failing → Check InfluxDB disk space, connectivity
   │  └─ Recent writes exist → Check Redis cache
   │     └─ Cache serving stale data → Flush Redis key for facility X
   ```

4. **Establish On-Call Escalation Policy**:
   - **L1 (Primary on-call)**: Respond within 15 minutes, follow runbooks
   - **L2 (Senior engineer)**: Escalate if runbook doesn't resolve in 30 minutes
   - **L3 (Engineering manager)**: Escalate if customer-facing impact >2 hours
   - **Vendor support**: Engage AWS support for infrastructure issues, InfluxDB support for database issues

---

#### **M4: No Feature Flags for Gradual Rollout**
**Reference**: Section 6 (Deployment - rolling update, Flyway migrations)

**Gap Analysis**:
Design uses rolling update deployment strategy but lacks feature flag system for:
- **Gradual feature rollout**: Enable new functionality for subset of users/facilities
- **Emergency kill switch**: Disable broken feature without full deployment rollback
- **A/B testing**: Compare different algorithm implementations (e.g., forecast model versions)
- **Decoupling deploy from release**: Deploy code in disabled state, enable when ready

Example risk scenario:
- New LSTM model version deployed to improve forecast accuracy
- Model has bug causing 20% of facilities to get NaN predictions
- Bug only manifests with specific usage patterns (not caught in testing)
- **Current mitigation**: Full rollback (15-minute deployment cycle)
- **With feature flags**: Disable new model in 10 seconds, revert to old model

**Impact**:
- **Deployment risk**: All-or-nothing releases increase blast radius
- **Slow rollback**: 15-minute deployment cycle to revert changes
- **No experimentation**: Cannot safely test changes on production traffic subset

**Recommendations**:
1. **Implement Feature Flag System**:
   - Use managed service (LaunchDarkly, Split.io) or open-source (Unleash, Flagr)
   - Store flag state in Redis (fast access, centralized)
   - Evaluate flags at runtime (no code deployment needed to change)

2. **Define Feature Flag Categories**:

   **Release Flags** (temporary, remove after rollout):
   - `forecast_model_v2_enabled`: Switch between LSTM v1 and v2
   - `bms_mqtt_fallback_enabled`: Enable fallback protocol for BMS commands
   - Default: false (new code disabled)
   - Rollout: 1% → 10% → 50% → 100% of facilities over 1 week

   **Operational Flags** (long-lived):
   - `dr_event_auto_execution_enabled`: Kill switch for automated DR participation
   - `weather_api_circuit_breaker_enabled`: Enable/disable circuit breaker
   - Default: true (operational features enabled)
   - Use: Disable during incidents

   **Experiment Flags** (A/B testing):
   - `forecast_algorithm`: Enum values ["lstm_v1", "lstm_v2", "random_forest"]
   - Random assignment: 33% per variant
   - Track forecast accuracy metrics per variant

3. **Integrate Flags into Deployment Process**:
   ```go
   // Forecast Service code
   func generateForecast(facilityID string) Forecast {
       if featureFlag.IsEnabled("forecast_model_v2_enabled", facilityID) {
           return lstmV2Model.Predict(facilityID)
       }
       return lstmV1Model.Predict(facilityID)  // Safe fallback
   }
   ```

4. **Define Flag Rollout Strategy**:
   - **Canary deployment**: Enable for 1% of facilities for 24 hours
   - **Monitor**: Track SLO metrics (forecast accuracy, error rate, latency)
   - **Expand**: If metrics healthy, increase to 10% → 50% → 100%
   - **Rollback**: If SLO violation, disable flag immediately (no code deployment needed)

5. **Add Flag Evaluation Logging**:
   - Log flag evaluation decisions for audit (which facility got which variant)
   - Include flag state in distributed traces
   - Enable debugging: "Why did facility X get forecast from model v1 instead of v2?"

---

#### **M5: Insufficient Observability for DR Events**
**Reference**: Section 4 (dr_events table), Section 7 (Monitoring)

**Gap Analysis**:
DR events are mission-critical feature (revenue generation, utility relationship) but design lacks comprehensive observability:
- **No DR event success rate metric**: What % of events successfully execute?
- **No latency tracking**: How long from webhook receipt to BMS command execution?
- **No achievement tracking**: How close is actual reduction to target?
- **No financial impact**: Revenue earned per event not tracked

Current data model stores:
- `target_reduction_kw`, `achieved_reduction_kw`, `status`

But no metrics, dashboards, or alerts specifically for DR event health.

**Impact**:
- **Hidden revenue loss**: Missed DR events not visible until monthly utility report
- **No proactive alerting**: DR failures discovered reactively
- **No optimization data**: Cannot improve DR strategy without performance metrics

**Recommendations**:
1. **Add DR Event Metrics**:
   ```
   dr_event_success_rate{facility_id, utility} = 99.2%
   dr_event_execution_latency_seconds{facility_id} = histogram (p50/p95/p99)
   dr_event_reduction_achievement_ratio{facility_id} = 0.98 (achieved/target)
   dr_event_revenue_estimate_usd{facility_id, utility} = $1250
   ```

2. **Create DR Operations Dashboard**:
   - **Overview Panel**: Total events this month, success rate, estimated revenue
   - **Facility Panel**: Per-facility success rate, average achievement ratio
   - **Timeline Panel**: Event execution timeline (webhook → BMS ack → event end)
   - **Failure Panel**: Recent failures with reason codes (BMS timeout, forecast unavailable, etc.)

3. **Implement DR Event Alerting**:
   - **Critical**: DR event execution failed → Page on-call immediately
   - **Warning**: DR achievement <80% of target → File ticket for investigation
   - **Info**: DR event completed successfully → Slack notification with revenue estimate

4. **Add DR Event Audit Trail**:
   Extend `dr_events` table:
   ```sql
   ALTER TABLE dr_events ADD COLUMN webhook_received_at TIMESTAMP;
   ALTER TABLE dr_events ADD COLUMN bms_command_sent_at TIMESTAMP;
   ALTER TABLE dr_events ADD COLUMN bms_command_acked_at TIMESTAMP;
   ALTER TABLE dr_events ADD COLUMN failure_reason TEXT;
   ALTER TABLE dr_events ADD COLUMN forecast_id BIGINT;  -- Link to forecast used
   ```

   Enables analysis:
   - Execution latency: `bms_command_sent_at - webhook_received_at`
   - Command round-trip: `bms_command_acked_at - bms_command_sent_at`
   - Failure patterns: GROUP BY failure_reason

5. **Track Financial Impact**:
   - Store utility incentive rate in `facilities` table
   - Calculate estimated revenue: `achieved_reduction_kw * event_duration_hours * incentive_rate_per_kwh`
   - Monthly report: Total DR revenue, per-facility contribution, missed opportunity from failures

---

#### **M6: No Database Schema Backward Compatibility Strategy**
**Reference**: Section 6 (Deployment - Flyway migrations run before deployment)

**Gap Analysis**:
Design runs database migrations before deploying new code (standard Flyway practice) but does not specify:
- **Backward compatibility**: Can old code run with new schema?
- **Rollback strategy**: What happens if deployment must be reverted after migration?
- **Coordination**: How to ensure migration completes before new code deployed?

Example breaking scenario:
1. Migration adds `NOT NULL` column to `facilities` table
2. Migration runs successfully
3. New code deploys (expects column to exist)
4. Rolling update in progress: 50% pods old code, 50% new code
5. **Old code attempts INSERT without new column** → Database constraint violation
6. **API requests fail** for half of traffic
7. Attempt to rollback deployment
8. **Migration cannot be reverted** (data written to new column would be lost)

**Impact**:
- **Deployment failures**: Incompatible schema changes break rolling updates
- **Extended outages**: Cannot safely rollback after migration
- **Data loss risk**: Reverting migrations may delete data

**Recommendations**:
1. **Implement Expand-Contract Migration Pattern**:

   **Phase 1 - Expand** (make schema backward compatible):
   ```sql
   -- Add new column as nullable, no default
   ALTER TABLE facilities ADD COLUMN peak_demand_kw DECIMAL;

   -- Deploy this migration and validate old code still works
   -- Old code: Ignores new column (no SELECT, no INSERT)
   -- New code: Can read/write new column
   ```

   **Phase 2 - Migrate** (backfill data, deploy new code):
   ```sql
   -- Backfill historical data
   UPDATE facilities SET peak_demand_kw = contract_demand_kw * 0.8;

   -- Deploy new code version that uses peak_demand_kw
   -- Rolling update: Old and new code coexist safely
   ```

   **Phase 3 - Contract** (enforce constraints after deployment complete):
   ```sql
   -- After new code 100% deployed, add constraints
   ALTER TABLE facilities ALTER COLUMN peak_demand_kw SET NOT NULL;
   ALTER TABLE facilities ADD CONSTRAINT check_peak_demand
       CHECK (peak_demand_kw > 0 AND peak_demand_kw <= contract_demand_kw);
   ```

2. **Add Migration Safety Checks**:
   - **Pre-flight validation**: Test migration on production snapshot in staging
   - **Require explicit approval**: Migrations affecting >10,000 rows require manual review
   - **Automated rollback migrations**: For each forward migration, provide rollback script
   - **Lock timeout**: Set `lock_timeout = '5s'` to prevent long-running DDL blocking production

3. **Coordinate Deployment with Migration**:
   ```yaml
   # Kubernetes Job for migration
   apiVersion: batch/v1
   kind: Job
   metadata:
     name: flyway-migrate-v1.2.3
   spec:
     template:
       spec:
         containers:
         - name: flyway
           image: flyway/flyway:9
           command: ["flyway", "migrate"]
         restartPolicy: OnFailure
     backoffLimit: 0  # Do not retry failed migrations

   # Deployment waits for migration job completion
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: api-gateway
   spec:
     template:
       metadata:
         annotations:
           migration-version: "v1.2.3"  # Document required migration
   ```

4. **Document Migration Rollback Procedure**:
   ```markdown
   ## Rollback Procedure for Migration V5

   ### Scenario: Deployment v1.2.3 must be reverted

   1. Check if migration V5 has run:
      SELECT version FROM flyway_schema_history WHERE version = '5';

   2. If migration ran, execute rollback:
      flyway undo  # Runs V5__undo_peak_demand.sql

   3. Verify rollback:
      SELECT column_name FROM information_schema.columns
      WHERE table_name = 'facilities' AND column_name = 'peak_demand_kw';
      -- Should return empty

   4. Redeploy previous code version:
      kubectl rollout undo deployment/api-gateway
   ```

---

#### **M7: Missing Resource Quotas and Autoscaling Limits**
**Reference**: Section 7 (Auto-scaling: HPA based on CPU 70%)

**Gap Analysis**:
Design enables HPA but does not specify:
- **Minimum/maximum replica counts**: How many pods at minimum? Maximum before cost runaway?
- **Resource requests/limits**: CPU/memory requests for scheduling, limits for OOM prevention
- **Node autoscaling**: Does EKS cluster scale nodes when pods pending?
- **Cost guardrails**: What prevents autoscaling from creating $10K/day cloud bill?

Without limits, failure scenarios:
- **DDoS attack**: Malicious traffic triggers HPA scale-up to 100s of pods
- **Cost explosion**: AWS bill jumps from $5K/month to $50K in one day
- **Cluster resource exhaustion**: All nodes fully utilized, legitimate pods evicted
- **Cascading failures**: Runaway scaling consumes all IP addresses in VPC subnet

**Impact**:
- **Financial risk**: Uncontrolled cloud costs
- **Availability risk**: Resource exhaustion affects other services in cluster
- **Operational chaos**: Emergency response needed to prevent cost overrun

**Recommendations**:
1. **Configure HPA with Min/Max Replicas**:
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: api-gateway-hpa
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: api-gateway
     minReplicas: 3   # Maintain baseline capacity
     maxReplicas: 20  # Cost guardrail: 20 pods * 1 CPU = 20 CPU max
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 70
     behavior:
       scaleUp:
         stabilizationWindowSeconds: 60  # Wait 1 min before scale-up
         policies:
         - type: Percent
           value: 50
           periodSeconds: 60  # Max 50% increase per minute (prevents runaway)
       scaleDown:
         stabilizationWindowSeconds: 300  # Wait 5 min before scale-down
   ```

2. **Set Resource Requests and Limits**:
   ```yaml
   resources:
     requests:
       cpu: 500m      # Guaranteed CPU for scheduling
       memory: 1Gi    # Guaranteed memory for scheduling
     limits:
       cpu: 2000m     # Max CPU (throttled if exceeded)
       memory: 2Gi    # Max memory (OOM killed if exceeded)
   ```

   **Rationale**:
   - Requests: Ensure predictable performance, inform scheduler decisions
   - Limits: Prevent single pod from consuming entire node resources
   - Ratio: 4x headroom (500m request → 2000m limit) allows traffic spikes

3. **Configure Cluster Autoscaler**:
   ```yaml
   # EKS Node Group configuration
   minSize: 3   # Minimum nodes for multi-AZ (1 per zone)
   maxSize: 10  # Maximum nodes to prevent cost runaway

   # Cost estimation:
   # 10 nodes * m5.2xlarge * $0.384/hr * 730 hr/month = $2,803/month max
   ```

4. **Implement Cost Alerting**:
   - **CloudWatch Billing Alert**: Email if projected monthly cost >$5,000
   - **Pod count alert**: Slack notification if any deployment >50 replicas
   - **Node count alert**: Page on-call if EKS cluster >8 nodes (approaching limit)

5. **Add Resource Quotas per Namespace**:
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: energy-mgmt-quota
     namespace: production
   spec:
     hard:
       requests.cpu: "40"      # Max 40 CPU cores requested
       requests.memory: 80Gi   # Max 80GB memory requested
       pods: "100"             # Max 100 pods total
   ```

---

### **TIER 4: MINOR IMPROVEMENTS & POSITIVE ASPECTS**

#### **Positive Aspects**
1. **Multi-AZ Deployment**: Design correctly uses 3 availability zones for fault tolerance
2. **Structured Logging with Correlation IDs**: Enables distributed debugging (though propagation needs improvement per S6)
3. **Retry with Exponential Backoff**: WeatherAPI retry logic follows best practices
4. **Monitoring Foundation**: Prometheus + Grafana with key metrics configured
5. **InfluxDB Retention Policy**: Appropriate data lifecycle (90 days granular, 2 years downsampled)
6. **Kafka Partitioning**: Partitioning by facility ID enables horizontal scaling
7. **S3 Archival**: Daily snapshots provide data durability (though restore procedure needs documentation per C6)

#### **Minor Improvements**

**I1: Add Cache Warming for Critical Data**
Current: Redis cache with 10-second TTL for facility current readings.
Enhancement: Pre-populate cache on service startup to avoid cold-start cache misses. Implement background job to refresh cache for all facilities every 5 seconds (before TTL expiration).

**I2: Implement Log Sampling for High-Volume Events**
Current: All sensor readings logged (10,000/second = 864 million/day).
Enhancement: Sample sensor reading logs at 1% rate for INFO level, 100% for ERROR/WARN. Reduces CloudWatch costs by 99% while maintaining error visibility.

**I3: Add Database Query Performance Logging**
Current: No query performance tracking mentioned.
Enhancement: Log queries exceeding 100ms with execution plan. Enables proactive optimization before queries degrade to timeout levels.

**I4: Implement Configuration Hot-Reload**
Current: Configuration via ConfigMaps (requires pod restart for changes).
Enhancement: Watch ConfigMap changes and reload without restart for non-critical settings (log levels, cache TTLs, retry counts). Reduces deployment cycle time for operational tuning.

**I5: Add Metrics for External API Latency**
Current: WeatherAPI and BMS API calls not tracked for latency.
Enhancement: Add histograms for external API call duration. Enables SLA enforcement and vendor accountability (e.g., "WeatherAPI p95 latency increased from 200ms to 2s, investigate").

---

## Summary

This design document demonstrates strong foundational architecture decisions (multi-AZ deployment, Kafka for data streaming, appropriate database choices) but has critical reliability gaps that must be addressed before production deployment.

### Critical Reliability Risks (Must Fix)
- **C1**: Distributed transaction coordination missing for DR event execution (financial/compliance risk)
- **C2**: Single point of failure in PostgreSQL (availability risk, exceeds SLO budget)
- **C3**: No idempotency for Kafka message processing (data accuracy risk)
- **C4**: Missing circuit breakers for external APIs (cascading failure risk)
- **C5**: No database query timeouts (availability risk from runaway queries)
- **C6**: Unvalidated backup/restore procedures (data loss risk)
- **C7**: No replication lag monitoring (stale data risk)

### Significant Operational Gaps (Should Fix)
- **S1-S7**: Various partial-failure scenarios (DLQ, rate limiting, health checks, DR retry, connection pools, distributed tracing, forecast error handling)

### Recommended Immediate Actions
1. **Week 1-2**: Implement C2 (PostgreSQL HA), C4 (circuit breakers), C5 (query timeouts), S3 (health checks)
2. **Week 3-4**: Implement C1 (DR transaction coordination), C3 (Kafka idempotency), S2 (rate limiting)
3. **Week 5-6**: Implement C6 (backup validation), C7 (replication monitoring), S4 (DR retry logic)
4. **Ongoing**: Address moderate and minor issues incrementally (M1-M7, I1-I5)

The design shows promise for a production-grade energy management system, but the identified critical issues represent unacceptable operational risks that would likely manifest as production incidents within the first month of deployment.
