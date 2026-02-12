# Reliability Design Review: Smart Energy Management System

## Phase 1: Structural Analysis

### System Components
1. **Ingestion Service**: MQTT message validation and Kafka forwarding
2. **Aggregation Service**: Kafka Streams consumer for rollup computation
3. **Forecast Service**: ML-based load prediction (15-min intervals)
4. **DR Coordinator**: Demand response event handler with BMS integration
5. **API Gateway**: REST API for dashboards and data exports
6. **Frontend**: React SPA with 30-second polling

### Data Stores
- **PostgreSQL**: Facility metadata, DR events, load forecasts (single primary instance)
- **InfluxDB**: Time-series sensor data (15-second granularity)
- **Redis**: Caching layer (10-second TTL for current readings)
- **Kafka**: Event streaming backbone (sensor-readings topic, partitioned by facility_id)

### External Dependencies (Critical Path)
1. **AWS IoT Core**: Smart meter connectivity (MQTT ingestion point)
2. **WeatherAPI.com**: Forecast model inputs
3. **Utility Grid API**: DR event webhook notifications
4. **BMS SOAP API**: HVAC/lighting control commands

### Data Flow Paths
1. **Monitoring Path**: Smart meters → IoT Core → Ingestion Service → Kafka → Aggregation Service → InfluxDB → API Gateway → Frontend
2. **Forecasting Path**: InfluxDB + WeatherAPI → Forecast Service → PostgreSQL → API Gateway
3. **Demand Response Path**: Utility webhook → DR Coordinator → Forecast query → BMS commands

### Explicitly Mentioned Reliability Mechanisms
- Multi-AZ deployment (3 zones)
- Rolling update strategy (maxUnavailable: 1)
- Prometheus/Grafana monitoring
- Exponential backoff for WeatherAPI retries (max 3 attempts)
- CloudWatch structured logging with correlation IDs

---

## Phase 2: Problem Detection

### **TIER 1: CRITICAL ISSUES (System-Wide Impact)**

#### **C1: PostgreSQL Single Point of Failure with No Failover**
**Reference**: Section 2 (Databases), Section 7 (Availability & Scalability: "PostgreSQL: Single primary instance (no read replicas)")

**Failure Scenario**:
PostgreSQL stores business-critical data (DR events, forecasts, facility metadata). A database failure causes:
- Complete loss of DR Coordinator functionality (cannot query forecasts or update event status)
- API Gateway unable to serve historical data or forecast endpoints
- Frontend dashboard unusable for historical analysis
- Risk of multi-hour outage waiting for AWS RDS automated backups to restore

**Operational Impact**:
- **Data Path Failures**: DR event processing halts completely (safety-critical for grid stability)
- **Recovery Complexity**: Manual failover to standby requires DNS updates, connection pool resets, application restarts
- **RTO Risk**: Without automated failover, RTO likely exceeds 30 minutes (violates any reasonable DR event response SLA)

**Countermeasures**:
1. **Immediate**: Deploy PostgreSQL with Multi-AZ automatic failover (AWS RDS automated standby)
2. **Read Replicas**: Add 1-2 read replicas to offload dashboard query traffic from primary
3. **Connection Pooling**: Implement pgBouncer with transaction-mode pooling and automatic reconnection
4. **Health Checks**: Add database connectivity checks to Kubernetes liveness probes to trigger pod restarts on connection loss
5. **Failover Testing**: Quarterly chaos engineering drills with forced failover to validate RTO < 60 seconds

---

#### **C2: No Transaction Boundary Definition for DR Event Processing**
**Reference**: Section 3 (Data Flow step 5), Section 4 (dr_events table schema)

**Failure Scenario**:
DR Coordinator workflow involves multiple state changes:
1. Receive utility webhook → 2. Query forecast → 3. Calculate reduction strategy → 4. Send BMS commands → 5. Update dr_events.status to 'active'

Without explicit transaction boundaries:
- BMS commands may execute while dr_events record remains 'scheduled' (inconsistent state)
- Partial failures leave orphaned events (BMS executing load reduction with no database record)
- Retry logic undefined → duplicate BMS commands possible (lights/HVAC toggled multiple times)

**Operational Impact**:
- **Data Inconsistency**: DR event status does not reflect actual BMS command state
- **Audit Trail Loss**: Compliance reporting broken (cannot prove DR participation)
- **Cascading Failures**: Duplicate commands may cause BMS controller rejection/lockout

**Countermeasures**:
1. **Two-Phase Commit Pattern**:
   - Phase 1: Update dr_events.status = 'pending_execution' in DB transaction
   - Phase 2: Send BMS commands with idempotency key (event_id + timestamp)
   - Phase 3: Update status = 'active' on BMS acknowledgment
2. **Idempotency Keys**: Include `X-Idempotency-Key: {event_id}` header in BMS API calls to prevent duplicate execution
3. **Dead Letter Queue**: Route failed DR events to DLQ after 3 retry attempts with exponential backoff
4. **Compensating Transaction**: On BMS command failure, revert dr_events.status to 'failed' and trigger alert for manual intervention
5. **Event Sourcing**: Log all state transitions (scheduled → pending_execution → active → completed) with timestamps for audit trail

---

#### **C3: Missing Circuit Breaker for BMS Integration**
**Reference**: Section 3 (DR Coordinator component), Section 6 (Error Handling: "BMS Controller logs command failures but does not retry")

**Failure Scenario**:
BMS SOAP API becomes unresponsive (network partition, service overload, credential expiration). Without circuit breaker:
- DR Coordinator continues attempting BMS calls with default HTTP timeout (potentially 30-60 seconds)
- Thread pool exhaustion blocks all concurrent DR events across facilities
- Cascading failure: API Gateway threads blocked waiting for DR event status updates

**Operational Impact**:
- **Blast Radius**: Single facility BMS failure impacts all facilities' DR capability
- **Resource Exhaustion**: Go goroutine leak from hanging SOAP calls
- **Inability to Degrade**: No fallback mechanism (e.g., skip non-critical facilities, alert operators)

**Countermeasures**:
1. **Circuit Breaker (Go: sony/gobreaker)**:
   - Failure threshold: 5 consecutive failures or 50% failure rate over 10 requests
   - Half-open state: Single test request after 30-second cooldown
   - Open state action: Return cached BMS command status + alert on-call engineer
2. **Aggressive Timeouts**:
   - Connection timeout: 2 seconds
   - Request timeout: 5 seconds (total BMS call budget)
   - Context deadline propagation through call chain
3. **Bulkhead Isolation**:
   - Separate goroutine pools per facility (max 10 concurrent BMS calls per facility)
   - Prevents one slow facility from blocking others
4. **Fallback Strategy**:
   - On circuit open: Mark dr_events.status = 'degraded', send critical alert
   - Manual override UI for operators to directly control BMS
5. **BMS Health Endpoint**: Implement lightweight ping endpoint (non-SOAP HTTP GET) for proactive failure detection

---

#### **C4: No Backup and Restore Validation for Time-Series Data**
**Reference**: Section 2 (InfluxDB retention policy), Section 7 (Availability: "90 days granular data, 2 years downsampled")

**Failure Scenario**:
InfluxDB disk corruption or accidental data deletion (e.g., misconfigured retention policy). Design states:
- S3 archival of "daily snapshots" but no restore procedure documented
- No RPO/RTO definitions for time-series data recovery
- Unknown: Snapshot format (full backup vs incremental?), restore time for 90 days of 15-second data

**Operational Impact**:
- **Compliance Risk**: Historical energy data required for utility billing disputes, audits
- **Forecast Model Failure**: ML models depend on 30+ days of historical data for training
- **Revenue Loss**: Cannot bill customers for DR participation without verified baseline calculations

**Countermeasures**:
1. **RPO/RTO Definition**:
   - **RPO**: 1 hour (acceptable data loss window)
   - **RTO**: 4 hours (time to restore 90 days of data from S3)
2. **Automated Backup Validation**:
   - Weekly restore drill: Spin up test InfluxDB instance, restore latest S3 snapshot, verify record count
   - Alert on restore failure or record count mismatch
3. **Incremental Snapshots**:
   - Hourly incremental backups to S3 (use InfluxDB OSS backup API)
   - Daily full backups for baseline recovery
4. **Replication for Critical Data**:
   - Real-time replication to standby InfluxDB cluster in separate AZ
   - Read-only standby for disaster recovery
5. **Runbook Documentation**:
   - Step-by-step restore procedure with estimated time per 10GB of data
   - Tested during quarterly DR drills

---

#### **C5: Missing Distributed Transaction Coordination for Kafka → InfluxDB Writes**
**Reference**: Section 3 (Data Flow step 3), Section 3 (Aggregation Service component)

**Failure Scenario**:
Aggregation Service consumes from Kafka, computes rollups, writes to InfluxDB. Current design lacks:
- Exactly-once semantics coordination between Kafka offset commits and InfluxDB writes
- If InfluxDB write fails but Kafka offset commits → data loss
- If Kafka offset doesn't commit but InfluxDB write succeeds → duplicate rollups

**Operational Impact**:
- **Silent Data Loss**: Missing 15-minute aggregates break forecast model accuracy
- **Billing Errors**: Duplicate rollups inflate energy consumption totals (customer disputes)
- **Audit Trail Corruption**: Cannot trust historical data for compliance reporting

**Countermeasures**:
1. **Idempotent Writes with Deduplication**:
   - Generate deterministic rollup IDs: `{facility_id}-{timestamp}-{granularity}`
   - Store last processed offset per partition in Redis
   - Skip processing if rollup ID already exists in InfluxDB
2. **Transactional Outbox Pattern** (if exact-once required):
   - Write rollups to PostgreSQL outbox table in same transaction as offset commit
   - Separate worker drains outbox → InfluxDB with retry logic
3. **At-Least-Once with Deduplication**:
   - Commit Kafka offset only after InfluxDB write confirmed (200 OK)
   - On restart, reprocess last 100 messages with dedup logic
4. **Monitoring**:
   - Alert on Kafka offset lag spike (> 10,000 messages as configured)
   - Track duplicate write rate metric (should be < 0.1%)
5. **Backfill Capability**:
   - Store raw sensor-readings in S3 (via Kafka Connect sink)
   - Runbook for reprocessing raw data on aggregation corruption

---

#### **C6: No Timeout Configuration for Kafka/InfluxDB/Redis Calls**
**Reference**: Section 6 (Error Handling: mentions WeatherAPI retries only), Section 3 (Component responsibilities)

**Failure Scenario**:
Design explicitly mentions timeout/retry for WeatherAPI but silent on:
- Kafka producer/consumer timeouts (Ingestion Service → Kafka, Aggregation Service consumer)
- InfluxDB write timeouts (Aggregation Service batch writes)
- Redis cache read timeouts (API Gateway current reading endpoint)

Without timeouts:
- Slow InfluxDB writes block Aggregation Service indefinitely (Kafka lag spirals)
- Redis connection leak causes goroutine pool exhaustion in API Gateway
- Frontend 30-second polling receives no response (browser timeout, poor UX)

**Operational Impact**:
- **Cascading Latency**: Slow backend calls propagate to API Gateway → Frontend
- **Resource Leak**: Unbounded goroutines waiting for stuck network calls
- **Monitoring Blindness**: No clear signal for "operation took too long" vs "operation succeeded"

**Countermeasures**:
1. **Explicit Timeout Budget Allocation**:
   - **Kafka Producer** (Ingestion Service): 5-second write timeout
   - **InfluxDB Writes** (Aggregation Service): 10-second timeout for batch writes (1000 points)
   - **Redis Reads** (API Gateway): 100ms timeout (cache miss fallback to InfluxDB)
   - **PostgreSQL Queries** (API Gateway): 2-second timeout for dashboard queries
2. **Context Deadline Propagation**:
   - API Gateway sets request context deadline (500ms for p95 SLA)
   - All downstream calls inherit parent context deadline
3. **Graceful Degradation on Timeout**:
   - Redis timeout → Bypass cache, query InfluxDB directly (slower but functional)
   - InfluxDB timeout → Return stale Redis cached value with `X-Cache-Stale: true` header
4. **Timeout Metrics**:
   - Prometheus histogram: `operation_timeout_seconds{service="api-gateway",operation="redis_get"}`
   - Alert on timeout rate > 1% for any operation
5. **Load Shedding**:
   - Reject new API requests with 503 Service Unavailable when p99 latency > 2 seconds

---

#### **C7: Kafka Consumer Group Rebalancing Risk During Deployment**
**Reference**: Section 6 (Deployment: "rolling update strategy maxUnavailable: 1"), Section 3 (Aggregation Service consumes Kafka)

**Failure Scenario**:
Rolling update kills Aggregation Service pods one at a time. Each pod termination triggers Kafka consumer group rebalance:
- Rebalance duration: 10-30 seconds per pod (default Kafka settings)
- During rebalance, no messages consumed → Kafka lag spikes
- If deployment takes 5 minutes (10 pods × 30 seconds), lag accumulates to 300,000 messages (at 10,000/sec ingestion rate)

**Operational Impact**:
- **SLA Violation**: Dashboard shows stale data for 5+ minutes during deployment
- **Alert Fatigue**: Kafka lag alert (> 10,000 threshold) fires on every deployment
- **Cascading Impact**: Forecast Service queries incomplete InfluxDB data → inaccurate predictions

**Countermeasures**:
1. **Graceful Shutdown with Cooperative Rebalancing**:
   - Use Kafka protocol cooperative-sticky rebalancing (Kafka 2.4+)
   - PreStop hook: Close Kafka consumer cleanly before SIGTERM (30-second grace period)
   - Reduces rebalance time to < 3 seconds per pod
2. **Static Consumer Group Assignment** (if partition count stable):
   - Manually assign partitions to pods based on pod ordinal (StatefulSet)
   - Eliminates rebalancing entirely (pod N always handles partition N)
3. **Deployment Pacing**:
   - Set `minReadySeconds: 30` in Kubernetes Deployment to pause between pod rollouts
   - Allows consumer lag to drain before next pod termination
4. **Canary Deployment**:
   - Deploy 1 pod with new version, monitor lag for 5 minutes
   - Rollback if lag > 50,000 messages sustained
5. **Backfill After Deployment**:
   - Temporarily scale Aggregation Service to 2x replicas post-deployment
   - Drain lag faster, return to normal scale after 10 minutes

---

### **TIER 2: SIGNIFICANT ISSUES (Partial System Impact)**

#### **S1: WeatherAPI Failure Breaks Forecast Service with No Fallback**
**Reference**: Section 6 (Error Handling: "Forecast Service retries WeatherAPI calls with exponential backoff (max 3 attempts)")

**Failure Scenario**:
WeatherAPI.com downtime or API quota exceeded. After 3 retry attempts:
- Forecast Service has no fallback data source
- No forecasts generated for 24-hour window
- DR Coordinator cannot calculate optimal load reduction (depends on forecast query)

**Operational Impact**:
- **DR Participation Failure**: Cannot respond to utility demand events (revenue loss, grid stability risk)
- **Dashboard Degradation**: Forecast chart shows "No Data" (poor user experience)
- **Recovery Time**: May require hours for WeatherAPI to restore service

**Countermeasures**:
1. **Multi-Provider Failover**:
   - Primary: WeatherAPI.com
   - Secondary: OpenWeatherMap API (fallback on primary failure)
   - Tertiary: Use NOAA public API (free, no quota limits)
2. **Cached Historical Weather**:
   - Store last 7 days of weather forecasts in PostgreSQL
   - On API failure, use "persistence forecast" (assume today's weather = yesterday's weather)
3. **Degraded Mode for DR**:
   - DR Coordinator uses simple heuristic (reduce 20% across all HVAC zones) instead of optimized calculation
   - Mark forecast as 'degraded' in API responses
4. **Proactive Monitoring**:
   - Synthetic check: Query WeatherAPI every 5 minutes with canary location
   - Alert on 2 consecutive failures before production impact
5. **SLA with Provider**:
   - Negotiate 99.9% uptime SLA with penalty credits
   - Document escalation path for outages

---

#### **S2: BMS Controller No-Retry Policy Creates Operational Blind Spots**
**Reference**: Section 6 (Error Handling: "BMS Controller logs command failures but does not retry (manual intervention required)")

**Failure Scenario**:
BMS command fails due to transient network issue (1-2 second blip). Current design:
- Logs failure but never retries
- dr_events.status remains 'scheduled' (inconsistent with reality)
- Operator must manually detect failure in logs, assess impact, resend command

**Operational Impact**:
- **Silent DR Failures**: Utility expects load reduction, facility doesn't deliver (financial penalties)
- **Operational Burden**: Manual log monitoring required during DR events
- **No Automatic Recovery**: Transient issues (99% success rate) require human intervention

**Countermeasures**:
1. **Retry with Idempotency**:
   - Retry transient failures (network timeout, 503 errors) up to 3 times with exponential backoff
   - Include idempotency key to prevent duplicate commands
   - Only skip retry for permanent failures (401 auth, 400 invalid payload)
2. **Status Reconciliation Loop**:
   - Poll BMS every 30 seconds during active DR event to verify command execution
   - Update dr_events.achieved_reduction_kw with actual measured reduction
   - Alert if achieved < 80% of target after 5 minutes
3. **Dead Letter Queue for Failures**:
   - Publish failed commands to `bms-failures` Kafka topic
   - Separate consumer retries with increasing delays (1min, 5min, 15min)
   - After exhausting retries, escalate to on-call engineer
4. **Manual Override UI**:
   - Dashboard panel for operators to view failed commands
   - One-click retry button with real-time BMS status feedback
5. **BMS Acknowledgment Protocol**:
   - Require BMS to return command_execution_id in response
   - Query BMS status endpoint with execution_id to confirm completion

---

#### **S3: No Rate Limiting or Backpressure on Webhook Endpoint**
**Reference**: Section 5 (Webhook POST /webhooks/utility/dr-notification), Section 6 (Error Handling: "Returns 200 immediately (async processing)")

**Failure Scenario**:
Utility grid operator sends burst of DR notifications (e.g., 1000 facilities in single webhook batch or repeated webhook retries). Without rate limiting:
- DR Coordinator goroutine pool spawns 1000+ concurrent BMS calls
- Thread pool exhaustion + memory pressure
- Kubernetes OOMKilled or cascading pod restarts

**Operational Impact**:
- **Service Unavailability**: API Gateway shares infrastructure with DR Coordinator (pod crash affects both)
- **DR Processing Failure**: Legitimate events dropped during overload
- **Noisy Neighbor**: Kafka broker/BMS controller overwhelmed by spike

**Countermeasures**:
1. **Rate Limiting at Webhook Endpoint**:
   - Token bucket: 100 requests/second per utility API key
   - Return 429 Too Many Requests with Retry-After header
   - Prometheus metric: `webhook_rate_limit_rejections_total`
2. **Bounded Queue for DR Events**:
   - Publish webhook payloads to Kafka topic `dr-events-inbound` (buffered)
   - DR Coordinator consumes at fixed rate (10 events/second)
   - Queue depth limit: 10,000 events (reject older events on overflow)
3. **Backpressure to Utility**:
   - Return 503 Service Unavailable when queue depth > 8,000
   - Utility retries with exponential backoff (their responsibility)
4. **Priority Queue**:
   - Critical facilities (hospitals, data centers) processed first
   - Priority field in webhook payload determines queue ordering
5. **Horizontal Scaling**:
   - HPA scales DR Coordinator pods based on Kafka queue depth
   - Target: 1000 messages per pod capacity

---

#### **S4: No Health Checks for Kafka/InfluxDB/PostgreSQL Dependencies**
**Reference**: Section 6 (Deployment: mentions Flyway migrations), Section 7 (Monitoring: metrics only, no health checks mentioned)

**Failure Scenario**:
Kubernetes liveness probes not configured for backend dependencies. Pod reports "Ready" even when:
- Kafka broker unreachable (Aggregation Service cannot consume)
- InfluxDB write path broken (data loss)
- PostgreSQL connection pool exhausted (API Gateway serves 500 errors)

**Operational Impact**:
- **Traffic Sent to Unhealthy Pods**: Load balancer routes requests to broken pods
- **Delayed Failure Detection**: Relies on user reports instead of proactive monitoring
- **Slow Recovery**: Pod never restarts automatically, requires manual kubectl intervention

**Countermeasures**:
1. **Kubernetes Health Check Endpoints**:
   - **Liveness Probe** (`/healthz`): Returns 503 if critical dependency unreachable
     - Check: Can establish TCP connection to Kafka/PostgreSQL/InfluxDB
     - Failure threshold: 3 consecutive failures → pod restart
   - **Readiness Probe** (`/ready`): Returns 503 if service cannot handle traffic
     - Check: Kafka consumer lag < 100,000, database connection pool has available connections
     - Removes pod from service load balancing on failure
2. **Dependency Health Check Library**:
   - Go library: health.AddCheck("kafka", kafkaHealthCheck) with timeout
   - Aggregate status: Healthy only if all dependencies pass
3. **Startup Probe** (separate from liveness):
   - Slower initial checks during pod boot (60-second timeout)
   - Validates database migrations completed, Kafka topics exist
4. **Circuit Breaker Integration**:
   - Health check fails when circuit breaker open for critical dependency
   - Forces pod restart to clear stale connection state
5. **Health Check Metrics**:
   - Prometheus: `dependency_health_check_failures_total{dependency="kafka"}`
   - Alert on sustained failures across multiple pods (systemic issue)

---

#### **S5: Poison Message Handling Missing for Kafka Consumers**
**Reference**: Section 3 (Aggregation Service consumes sensor-readings), Section 6 (Error Handling: Ingestion Service logs malformed MQTT but continues)

**Failure Scenario**:
Corrupted message in Kafka topic `sensor-readings` (e.g., invalid JSON, schema mismatch). Aggregation Service:
- Attempts to deserialize message → error
- Kafka consumer stuck on same message offset (cannot progress)
- All downstream partitions blocked (if processing order enforced)

**Operational Impact**:
- **Data Processing Halt**: Affects single facility (partition) or all facilities (depending on error handling)
- **Kafka Lag Spiral**: Lag grows indefinitely until manual intervention
- **Dashboard Staleness**: Affected facilities show no data updates

**Countermeasures**:
1. **Dead Letter Topic (DLT)**:
   - On deserialization error, publish raw message to `sensor-readings-dlt`
   - Commit Kafka offset to continue processing
   - Separate consumer for DLT analysis and alerting
2. **Poison Pill Detection**:
   - Track per-message retry count in consumer state (Redis)
   - After 3 consecutive failures on same offset, auto-skip and alert
3. **Schema Validation at Ingestion**:
   - Ingestion Service validates against Avro/Protobuf schema before Kafka publish
   - Rejects invalid messages with 400 Bad Request to IoT Core
4. **Message Quarantine UI**:
   - Dashboard panel for viewing DLT messages
   - Operator can reprocess after fixing schema issue
5. **Monitoring**:
   - Alert on DLT topic growth rate > 10 messages/minute
   - Prometheus metric: `kafka_poison_messages_total{topic="sensor-readings"}`

---

#### **S6: No Mechanism for Database Schema Backward Compatibility**
**Reference**: Section 6 (Deployment: "Database migrations: Flyway SQL scripts run before deployment")

**Failure Scenario**:
Flyway migration adds non-nullable column to `dr_events` table before rolling deployment completes. Old pods:
- Execute INSERT without new column → constraint violation error
- API Gateway returns 500 for POST /api/dr-events
- Rollback blocked by irreversible schema change

**Operational Impact**:
- **Deployment Failure**: Requires manual database schema rollback
- **Downtime Window**: Cannot serve DR event creation during migration
- **Rollback Complexity**: New column may already contain production data (cannot drop)

**Countermeasures**:
1. **Expand-Contract Pattern**:
   - **Phase 1** (Deploy N): Add column as nullable with default value
   - **Phase 2** (Deploy N+1): Application writes to new column
   - **Phase 3** (Deploy N+2): Backfill existing rows, add NOT NULL constraint
2. **Feature Flags for Schema Changes**:
   - New columns gated by feature flag (default: disabled)
   - Enable flag only after all pods updated
3. **Blue-Green Database Migration**:
   - Run migration on read replica first
   - Promote replica to primary after validation
4. **Migration Smoke Tests**:
   - Run test suite against migrated schema before production deployment
   - Validates old code compatible with new schema
5. **Rollback Scripts**:
   - Every Flyway migration paired with down migration script
   - Tested in staging before production

---

#### **S7: Redis Cache Stampede Risk on Current Readings Endpoint**
**Reference**: Section 5 (GET /api/facilities/{facility_id}/current with Redis cache, 10-second TTL)

**Failure Scenario**:
High-traffic facility dashboard (100 concurrent users polling every 30 seconds). Cache expires:
- First request finds cache miss, queries InfluxDB
- Remaining 99 concurrent requests also see cache miss (TTL just expired)
- 100 simultaneous InfluxDB queries (thundering herd)
- InfluxDB query queue saturates, latency spikes to 5+ seconds

**Operational Impact**:
- **API Latency Spike**: p95 latency violates 500ms SLA
- **InfluxDB Overload**: Starves other queries (forecast service, aggregation writes)
- **Cascading Failure**: API Gateway connection pool exhaustion

**Countermeasures**:
1. **Cache Stampede Prevention (Locking)**:
   - Use Redis SETNX for distributed lock: `cache-lock:{facility_id}`
   - First request acquires lock, queries InfluxDB, populates cache
   - Concurrent requests wait on lock (500ms timeout), then read fresh cache
2. **Probabilistic Early Expiration**:
   - Refresh cache at random time between 8-10 seconds (jitter)
   - Reduces likelihood of simultaneous expirations
3. **Background Refresh (Cache Warming)**:
   - Separate worker queries top 100 facilities every 5 seconds
   - Proactively refreshes cache before TTL expiration
   - Only serves stale cache on InfluxDB timeout
4. **Request Coalescing**:
   - Deduplicate concurrent requests for same facility_id in API Gateway
   - Use singleflight pattern (Go: golang.org/x/sync/singleflight)
5. **Stale-While-Revalidate**:
   - Return stale cache value immediately (HTTP header: Cache-Control: stale-while-revalidate=30)
   - Trigger async background refresh for next request

---

#### **S8: Missing SPOF Analysis for AWS IoT Core Ingestion**
**Reference**: Section 2 (Infrastructure: AWS IoT Core for smart meter connectivity), Section 3 (Data Flow: smart meters publish to IoT Core)

**Failure Scenario**:
AWS IoT Core service degradation or regional outage. Single ingestion path:
- Smart meters cannot publish readings (MQTT connection refused)
- No alternative ingestion path (e.g., direct HTTP API, backup MQTT broker)
- Data loss for duration of outage (no queuing at meter level)

**Operational Impact**:
- **Data Gap**: Historical data incomplete (impacts billing, compliance)
- **Forecast Degradation**: ML models trained on incomplete data
- **Monitoring Blindness**: Cannot detect facility issues during outage

**Countermeasures**:
1. **Dual Ingestion Paths**:
   - Primary: AWS IoT Core (MQTT)
   - Secondary: REST API endpoint for smart meters with local buffering
   - Meters try MQTT first, fall back to HTTP POST on connection failure
2. **Local Buffering at Edge**:
   - Smart meters buffer last 1 hour of readings in local storage
   - Replay buffer to IoT Core when connectivity restored
3. **Multi-Region Failover**:
   - Deploy secondary IoT Core instance in different AWS region
   - Meters configured with failover endpoint (DNS-based routing)
4. **IoT Core Health Monitoring**:
   - Synthetic canary device publishes test messages every 60 seconds
   - Alert on 3 consecutive publish failures
5. **Data Reconciliation**:
   - Post-outage: Query meter local logs, backfill missing readings
   - Automated script to detect gaps in InfluxDB, request backfill from meters

---

### **TIER 3: MODERATE ISSUES (Operational Improvement)**

#### **M1: No SLO/SLA Definitions Beyond Uptime Target**
**Reference**: Section 7 (Availability: "Target uptime: 99.5%"), Section 7 (Performance: p95 latency goal)

**Improvement Opportunity**:
99.5% uptime is vague. Missing:
- Error budget calculation (how many minutes/month can fail?)
- SLIs for key user journeys (dashboard load time, DR event latency)
- Tiered SLAs for different facility types (critical vs standard)

**Operational Impact**:
- **Ambiguous Success Criteria**: Cannot objectively measure reliability
- **No Prioritization Framework**: All incidents treated equally
- **Difficult Customer Conversations**: No contractual SLA to reference

**Recommendations**:
1. **Define SLOs with Error Budgets**:
   - **Dashboard Availability**: 99.5% uptime = 3.6 hours downtime/month
   - **API Latency**: p95 < 500ms, p99 < 1000ms
   - **DR Event Response**: 90% of events processed within 60 seconds
2. **Tiered SLAs**:
   - **Critical Facilities** (hospitals): 99.9% uptime, 15-minute support response
   - **Standard Facilities**: 99.5% uptime, 4-hour support response
3. **Error Budget Policy**:
   - Burn rate > 2x budget → freeze feature releases, focus on reliability
   - Monthly SLO review in engineering all-hands
4. **SLI Dashboards**:
   - Grafana dashboard with real-time SLO compliance per service
   - Historical trend charts (30-day, 90-day rolling windows)
5. **Postmortem Triggers**:
   - Any incident consuming > 10% of monthly error budget requires RCA document

---

#### **M2: Insufficient Distributed Tracing Coverage**
**Reference**: Section 6 (Logging: correlation IDs propagated from API requests)

**Improvement Opportunity**:
Correlation IDs mentioned for API requests but unclear:
- Do correlation IDs propagate through Kafka messages?
- Are BMS SOAP calls tagged with trace IDs?
- Can operators trace a DR event from webhook → forecast query → BMS command?

**Operational Impact**:
- **Slow Incident Response**: Cannot quickly identify bottleneck in multi-service workflows
- **Blame Game**: Difficult to determine if issue is in Forecast Service vs DR Coordinator
- **Incomplete Context**: Logs show individual service errors without full request context

**Recommendations**:
1. **OpenTelemetry Integration**:
   - Instrument all services with OTEL SDK
   - Propagate trace context through HTTP headers (traceparent)
   - Inject trace ID into Kafka message headers
2. **Critical Path Tracing**:
   - **DR Event Workflow**: webhook → forecast query → BMS call (single trace)
   - **Dashboard Query**: API Gateway → Redis → InfluxDB fallback
3. **Trace Sampling Strategy**:
   - 100% sampling for errors (status >= 400)
   - 10% sampling for successful requests (manage cost)
   - Force sampling for DR events (always critical)
4. **Jaeger/Tempo Backend**:
   - Store traces in Grafana Tempo (S3 backend)
   - Retention: 7 days for quick debugging
5. **Trace-Driven Alerts**:
   - Alert on trace spans exceeding SLA budget (e.g., BMS call > 5 seconds)

---

#### **M3: No Incident Response Runbooks**
**Reference**: Section 7 (Monitoring: alerts configured), Section 6 (Error Handling: BMS manual intervention)

**Improvement Opportunity**:
Alerts configured but no documented response procedures. Unclear:
- What does on-call engineer do when "Kafka lag > 10,000" fires?
- How to manually trigger DR event if webhook processing fails?
- What is escalation path for database failover?

**Operational Impact**:
- **Slow MTTR**: On-call engineers guess at solutions instead of following playbook
- **Knowledge Silos**: Only senior engineers know how to handle edge cases
- **Inconsistent Response**: Different responders take different actions

**Recommendations**:
1. **Runbook for Each Alert**:
   - **Kafka Lag Alert**: Check consumer pod logs → restart pod → verify lag decreasing
   - **InfluxDB Disk Usage**: Trigger manual retention policy execution → provision larger disk
   - **API Error Rate Spike**: Check recent deployments → rollback if correlation found
2. **DR Event Manual Override Procedure**:
   - Step 1: Query forecast via API
   - Step 2: Calculate reduction strategy
   - Step 3: Submit BMS commands via admin UI
   - Step 4: Update dr_events table via SQL (with audit log)
3. **Escalation Paths**:
   - L1 (On-call engineer): Follow runbook, resolve common issues
   - L2 (Senior engineer): Complex diagnosis, multi-service failures
   - L3 (AWS support): Infrastructure issues (RDS failover, IoT Core outage)
4. **Runbook Validation**:
   - Quarterly game days: Randomly assign junior engineer to follow runbook
   - Update runbook based on feedback
5. **Runbook Storage**:
   - GitHub wiki or PagerDuty Runbooks integration
   - Link from Grafana alert annotations

---

#### **M4: No Capacity Planning or Load Testing Validation**
**Reference**: Section 7 (Performance: throughput targets), Section 7 (Auto-scaling: HPA based on CPU 70%)

**Improvement Opportunity**:
Targets defined (10,000 readings/sec, 100 facilities forecast in 5 min) but unclear:
- Has system been load tested at 2x target capacity?
- What is max capacity before database/Kafka saturation?
- Is CPU-based autoscaling sufficient, or should use custom metrics (Kafka lag)?

**Operational Impact**:
- **Growth Blindness**: No early warning when approaching capacity limits
- **Black Friday Surprise**: System collapses during unexpected traffic spike
- **Wasted Resources**: Over-provisioning due to guesswork

**Recommendations**:
1. **Load Testing Suite**:
   - Simulate 20,000 readings/sec (2x target) for 1 hour
   - Inject 500 concurrent DR events
   - Measure p99 latency, error rate, resource utilization
2. **Capacity Model**:
   - Document max capacity per bottleneck:
     - Kafka: 50,000 msgs/sec per broker
     - InfluxDB: 100,000 writes/sec per node
     - PostgreSQL: 5,000 queries/sec
   - Alert when utilization > 60% of max capacity
3. **Custom HPA Metrics**:
   - Scale Aggregation Service based on Kafka lag (not CPU)
   - Scale API Gateway based on request rate (not CPU)
4. **Quarterly Load Tests**:
   - Run in staging environment before peak season (summer cooling, winter heating)
   - Validate autoscaling triggers work as expected
5. **Traffic Shaping**:
   - Rate limit low-priority endpoints (historical exports) during high load
   - Prioritize real-time monitoring and DR event processing

---

#### **M5: Redis Sentinel Not Mentioned for Cache Availability**
**Reference**: Section 2 (Databases: Redis 7.0 for caching), Section 5 (Cache with 10-second TTL)

**Improvement Opportunity**:
Redis used for session management and caching but no HA configuration mentioned. Single Redis instance:
- Restart for upgrades causes cache flush (thundering herd on InfluxDB)
- Node failure loses all session data (user re-login required)

**Operational Impact**:
- **User Experience Degradation**: Forced logouts during Redis maintenance
- **Database Overload**: Cache misses cause InfluxDB query spike
- **Deployment Complexity**: Must schedule Redis upgrades during maintenance window

**Recommendations**:
1. **Redis Sentinel Deployment**:
   - 1 primary + 2 replicas across 3 AZs
   - Automatic failover on primary failure (< 30 seconds)
2. **Persistent Sessions**:
   - Use Redis AOF (Append-Only File) persistence
   - Allows session recovery after restart
3. **Cache Warming on Startup**:
   - Pre-populate cache with top 100 facilities before serving traffic
   - Reduces initial cache miss rate
4. **Client-Side Failover**:
   - Go Redis client configured with Sentinel endpoints
   - Automatic reconnection to new primary
5. **Monitoring**:
   - Alert on Redis replication lag > 1 second
   - Track cache hit rate (should be > 90%)

---

#### **M6: No Feature Flags for Progressive Rollout**
**Reference**: Section 6 (Deployment: rolling update strategy)

**Improvement Opportunity**:
Rolling updates deploy to all pods sequentially but no gradual feature activation. Risky for:
- New DR Coordinator BMS integration logic
- ML model version updates (forecast accuracy changes)
- API schema changes (breaking changes to frontend)

**Operational Impact**:
- **All-or-Nothing Risk**: Bug in new code affects all users immediately
- **Slow Rollback**: Must deploy previous version to all pods (10+ minutes)
- **Difficult A/B Testing**: Cannot compare old vs new behavior in production

**Recommendations**:
1. **Feature Flag Service** (LaunchDarkly, Unleash, or custom):
   - `enable_new_bms_protocol`: Percentage rollout (0% → 10% → 50% → 100%)
   - `forecast_model_version`: Target specific facilities for testing
2. **Canary Releases**:
   - Deploy new version to 1 pod (10% traffic)
   - Monitor error rate, latency for 30 minutes
   - Auto-rollback if SLI degradation detected
3. **User-Level Toggles**:
   - Beta users opt into new dashboard UI
   - Gradual migration without forced upgrades
4. **Kill Switch**:
   - Emergency flag to disable new feature without redeployment
   - Triggered by on-call engineer or automated SLO violation
5. **Flag Lifecycle Management**:
   - Remove feature flag after 30 days of 100% rollout
   - Prevent flag debt accumulation

---

#### **M7: Lack of Chaos Engineering Validation**
**Reference**: Section 7 (Multi-AZ deployment), Section 6 (Error Handling mentions some retry logic)

**Improvement Opportunity**:
Design includes resilience mechanisms (Multi-AZ, retries) but no validation that they work. Unclear:
- Does system actually survive AZ failure?
- What happens when PostgreSQL fails over mid-transaction?
- How long does it take to detect and recover from Kafka broker failure?

**Operational Impact**:
- **False Confidence**: Resilience features untested until real incident
- **Surprise Failures**: Edge cases not discovered until production outage
- **Inadequate Recovery**: RTO/RPO assumptions not validated

**Recommendations**:
1. **Quarterly Chaos Drills**:
   - **Week 1**: Terminate random Kafka broker, measure lag recovery time
   - **Week 2**: Force PostgreSQL failover during DR event processing
   - **Week 3**: Simulate AWS IoT Core 503 errors (block IoT Core endpoint in firewall)
   - **Week 4**: Network partition between API Gateway and InfluxDB (add latency)
2. **Automated Chaos Experiments** (Chaos Mesh, Litmus):
   - Random pod termination (1 pod/hour during business hours)
   - Network delay injection (100ms latency to 10% of requests)
3. **Game Day Scenarios**:
   - Team exercise: Respond to multi-component failure
   - Validate runbooks, communication procedures
4. **Metrics Collection During Chaos**:
   - Track SLO compliance during experiments
   - Identify resilience gaps (e.g., RTO exceeded)
5. **Blameless Postmortems**:
   - Document learnings from chaos experiments
   - Track action items for resilience improvements

---

### **TIER 4: MINOR IMPROVEMENTS & POSITIVE ASPECTS**

#### **Minor Improvement 1: Log Retention Policy May Be Too Short**
**Reference**: Section 6 (Logging: CloudWatch Logs with 30-day retention)

**Context**: 30-day retention may be insufficient for:
- Long-term trend analysis (seasonal energy patterns)
- Compliance audits (may require 90-day retention)
- Post-incident investigation of slow-burn issues

**Recommendation**: Extend to 90 days or archive to S3 for cost-effective long-term storage.

---

#### **Minor Improvement 2: No Mention of Database Connection Pooling Configuration**
**Reference**: Section 2 (PostgreSQL 15), Section 3 (API Gateway queries PostgreSQL)

**Context**: Go applications should configure pgx/pgbouncer connection pools with:
- Max connections (prevent database overload)
- Connection timeout (detect broken connections)
- Idle connection reaping (prevent resource leaks)

**Recommendation**: Document connection pool settings in deployment configuration.

---

#### **Positive Aspect 1: Multi-AZ Deployment for Infrastructure Resilience**
**Reference**: Section 2 (Infrastructure: Kubernetes on AWS EKS, 3 availability zones)

**Strength**: Design demonstrates awareness of infrastructure-level redundancy. Three AZs provides resilience against zone-level failures (data center power loss, network issues).

---

#### **Positive Aspect 2: Correlation ID Propagation for Debugging**
**Reference**: Section 6 (Logging: correlation IDs propagated from API requests)

**Strength**: Trace IDs enable cross-service request tracking, significantly improving MTTR during incident response. This is a best practice for distributed systems observability.

---

#### **Positive Aspect 3: Structured Logging with JSON Format**
**Reference**: Section 6 (Logging: Structured JSON logs)

**Strength**: JSON logs enable automated parsing, aggregation in CloudWatch Insights, and integration with SIEM tools. Superior to unstructured text logs.

---

#### **Positive Aspect 4: Separation of Time-Series and Relational Data**
**Reference**: Section 2 (InfluxDB for sensor data, PostgreSQL for metadata)

**Strength**: Appropriate technology choice. InfluxDB optimized for high-frequency writes and time-based queries. PostgreSQL provides ACID guarantees for business-critical data (DR events, forecasts).

---

## Summary of Findings

### Critical Issues (7)
1. PostgreSQL single point of failure with no automated failover
2. Missing transaction boundaries for DR event processing
3. No circuit breaker for BMS integration (cascading failure risk)
4. Backup/restore procedures for InfluxDB not validated
5. Exactly-once semantics missing for Kafka → InfluxDB pipeline
6. No timeout configurations for critical paths (Kafka, InfluxDB, Redis)
7. Kafka consumer rebalancing causes lag spikes during deployment

### Significant Issues (8)
1. WeatherAPI failure breaks forecasting with no fallback
2. BMS no-retry policy creates operational blind spots
3. Missing rate limiting on webhook endpoint
4. No health checks for backend dependencies
5. Poison message handling missing for Kafka consumers
6. Database schema changes not backward compatible
7. Redis cache stampede risk on high-traffic endpoints
8. AWS IoT Core is single point of failure for ingestion

### Moderate Issues (7)
1. No SLO/SLA definitions with error budgets
2. Insufficient distributed tracing coverage
3. Missing incident response runbooks
4. No capacity planning or load testing validation
5. Redis Sentinel not configured for cache availability
6. No feature flags for progressive rollout
7. Lack of chaos engineering validation

### Key Recommendations Priority Order
1. **Immediate (Week 1)**: Enable PostgreSQL Multi-AZ failover, add circuit breaker for BMS calls, configure timeouts for all external dependencies
2. **Short-term (Month 1)**: Implement transaction coordination for DR events, add health checks to Kubernetes probes, configure WeatherAPI fallback provider
3. **Medium-term (Quarter 1)**: Deploy distributed tracing, create incident runbooks, implement feature flag infrastructure, validate backup/restore procedures
4. **Ongoing**: Quarterly chaos engineering drills, load testing before peak seasons, SLO review and error budget tracking
