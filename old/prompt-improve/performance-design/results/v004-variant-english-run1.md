# Performance Design Review: Medical Device Management Platform

## Executive Summary

This performance evaluation identifies **critical architectural bottlenecks** that will severely limit scalability and cause system-wide performance degradation under production load. The design assumes PostgreSQL can handle 5000 writes/sec from time-series data while simultaneously serving real-time queries, lacks proper data lifecycle management for unbounded growth, and relies on inefficient polling patterns for real-time updates.

**Overall Performance Risk: HIGH**

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 3/5 | No time-series optimized storage; inefficient polling patterns |
| I/O & Network Efficiency | 2/5 | 5-second polling creates unnecessary load; no batch processing for writes |
| Caching Strategy | 2/5 | No caching layer defined for frequently accessed data |
| Memory & Resource Management | 3/5 | Basic connection pooling mentioned but no sizing or lifecycle details |
| Data Lifecycle & Capacity Planning | 1/5 | **Critical**: No retention policy, archival strategy, or purging mechanism for continuously growing time-series data |
| Latency, Throughput & Scalability | 2/5 | **Critical**: Write throughput target (5000/sec) conflicts with PostgreSQL limitations; no read/write separation for time-series workload |

---

## Critical Issues (Must Address)

### 1. Unbounded Time-Series Data Growth Without Lifecycle Management

**Severity: CRITICAL**
**Reference: Section 4 (vital_data table), Section 7 (Performance targets)**

**Issue:**
The `vital_data` table receives 5000 records/second (432 million records/day) with no defined retention, archival, or purging strategy. At this rate:
- **Daily growth**: ~43GB (assuming 100 bytes/record)
- **Monthly growth**: ~1.3TB
- **Annual growth**: ~15TB

Without data lifecycle management:
- Query performance will degrade exponentially as the table grows beyond billions of rows
- Index maintenance costs will escalate
- Backup/restore times will become impractical
- Storage costs will balloon unnecessarily

**Impact:**
- Within 3-6 months, query latency will exceed the 500ms p95 SLA
- Dashboard queries will time out as historical data accumulates
- Database maintenance windows will extend beyond acceptable downtime

**Recommendation:**
Implement a tiered data lifecycle strategy:

1. **Active/Hot Tier** (PostgreSQL, 7-30 days):
   - Keep recent data for real-time queries
   - Partition by timestamp (daily/weekly partitions)
   - Automatic partition creation and attachment

2. **Warm Tier** (Compressed storage, 1-12 months):
   - Move to TimescaleDB hypertables with compression
   - Or export to Parquet on S3 with Athena for ad-hoc queries
   - 10x storage reduction via compression

3. **Cold/Archive Tier** (S3 Glacier, 1-7 years):
   - Regulatory compliance retention (3 years for access logs mentioned)
   - Rare access, batch restore only

4. **Purging** (After 7 years):
   - Automated deletion for non-regulatory data

**Capacity projection table:**
| Period | Records | Storage (Hot) | Storage (Warm) | Query Impact |
|--------|---------|---------------|----------------|--------------|
| 1 month | 13B | 1.3TB | - | Acceptable |
| 6 months | 78B | 7.8TB | - | Degraded (>1s queries) |
| 1 year | 157B | 15.7TB | - | Severe (>5s queries) |
| 1 year (with tiering) | 2.6B (30d hot) | 260GB | 1.4TB (compressed) | Acceptable |

---

### 2. PostgreSQL Time-Series Write Bottleneck

**Severity: CRITICAL**
**Reference: Section 2 (Data storage), Section 7 (5000 records/sec target)**

**Issue:**
Using standard PostgreSQL for 5000 writes/second time-series ingestion will hit performance limits:

- **Single-table sequential writes**: PostgreSQL can sustain ~10k-15k writes/sec on well-provisioned hardware, but this assumes:
  - No concurrent read queries (dashboard queries will compete for locks)
  - No index maintenance overhead (vital_data has multiple foreign keys and likely needs indexes on timestamp, patient_id, device_id)
  - No WAL replication lag (RDS Multi-AZ synchronous replication adds latency)

- **Foreign key validation overhead**: Each insert validates `device_id` and `patient_id` foreign keys, adding round-trip lookups

- **Index contention**: Concurrent writes to B-tree indexes (timestamp, patient_id) cause lock contention and page splits

**Impact:**
- Write latency will increase from <10ms to >100ms as table grows
- WebSocket server buffers will accumulate backlog during peak load
- Data loss risk if write buffers overflow
- Dashboard queries will slow down due to lock contention

**Recommendation:**

**Option A: Migrate to TimescaleDB (Recommended)**
- TimescaleDB is PostgreSQL-native, minimal migration effort
- Hypertables automatically partition by timestamp
- Achieves 100k+ inserts/sec via chunk-level parallelism
- Native compression reduces storage by 10-20x
- Continuous aggregates for pre-computed rollups (dashboard queries)

**Option B: Hybrid architecture**
- Keep PostgreSQL for metadata (devices, patients, alert_rules)
- Use time-series DB for vital_data:
  - **InfluxDB**: Purpose-built for IoT/monitoring data, 500k writes/sec
  - **AWS Timestream**: Managed service, auto-scaling, built-in tiering
- Trade-off: Dual database complexity, no foreign key enforcement

**Option C: Write optimization for PostgreSQL (Short-term mitigation)**
- Implement batch inserts (buffer 100-1000 records, insert as array)
- Use `UNLOGGED` tables for initial ingestion, then copy to logged table asynchronously
- Partition vital_data by timestamp (daily or weekly partitions)
- Remove foreign keys, validate in application layer
- Use connection pooling (PgBouncer) with transaction mode

---

### 3. Inefficient Polling Pattern for Real-Time Dashboard

**Severity: SIGNIFICANT**
**Reference: Section 3 (Data flow, "5-second polling")**

**Issue:**
The dashboard polls the REST API every 5 seconds for updates, even though devices send data every 1 second via WebSocket. This design creates:

- **Unnecessary load**: 1000 concurrent dashboard users = 200 requests/sec with mostly redundant data
- **Increased latency**: 5-second delay violates the "real-time monitoring" requirement; critical alerts could be delayed by up to 5 seconds
- **Database query overhead**: Each poll triggers queries to fetch latest data, competing with write workload
- **Scalability bottleneck**: Polling load scales linearly with user count, not data change rate

**Impact:**
- Alert response time degradation (5-second worst-case delay)
- Database query load increases proportionally with active users
- Inefficient use of network bandwidth (fetching unchanged data)

**Recommendation:**

**Option A: WebSocket for dashboard updates (Recommended)**
- Push vital data updates to dashboard via WebSocket
- Server-side filtering: Only send data for patients user is monitoring
- Reduces query load by 95% (only on initial page load)
- Sub-second latency for critical alerts

**Option B: Server-Sent Events (SSE)**
- Simpler than WebSocket, one-way push
- Automatically reconnects on disconnect
- Better firewall compatibility than WebSocket

**Implementation pattern:**
```
Dashboard connects -> Subscribe to patient IDs -> Receive push notifications
Only when device sends new data -> Dashboard updates immediately
```

**Fallback**: Keep polling as fallback for clients with WebSocket restrictions, but increase interval to 30 seconds.

---

## Significant Issues

### 4. Missing Caching Layer for Hot Data

**Severity: SIGNIFICANT**
**Reference: Section 5 (API endpoints), Section 7 (500ms p95 latency target)**

**Issue:**
No caching strategy is defined for frequently accessed data:

- **Latest vitals** (`GET /api/patients/{patientId}/vitals/latest`): Queried on every dashboard refresh, hits database every time
- **Active patients list** (`GET /api/dashboard/active-patients`): Aggregation query scans devices table
- **Alert rules**: Fetched on every vital data validation
- **Device metadata**: Looked up on every WebSocket message

Without caching:
- Database becomes the bottleneck for read-heavy workloads
- Read replicas still face query overhead for simple lookups
- Latency target (500ms p95) difficult to achieve under load

**Impact:**
- Read latency increases proportionally with concurrent users
- Database CPU utilization spikes during peak hours
- Increased RDS costs due to IOPS consumption

**Recommendation:**

**Cache tier architecture:**

1. **Redis cache layer** (AWS ElastiCache):
   - **Latest vitals per patient**: TTL 5 seconds, updated on every write
   - **Active patients list**: TTL 30 seconds, invalidate on status change
   - **Device metadata**: TTL 1 hour, invalidate on update
   - **Alert rules**: TTL 1 hour, invalidate on rule change

2. **Cache-aside pattern** for latest vitals:
   ```
   1. Dashboard requests latest vitals
   2. Check Redis: if hit, return immediately (latency <1ms)
   3. If miss, query PostgreSQL, store in Redis, return
   ```

3. **Write-through pattern** for WebSocket ingestion:
   ```
   1. Device sends vital data
   2. Write to PostgreSQL (durability)
   3. Update Redis cache (latest vitals)
   4. Trigger push notification to dashboard
   ```

**Expected impact:**
- 90%+ cache hit rate for latest vitals queries
- Latency reduction from 50-200ms (DB query) to <1ms (cache hit)
- Database read load reduction by 80%

---

### 5. No Read/Write Separation for Time-Series Workload

**Severity: SIGNIFICANT**
**Reference: Section 2 (Database architecture), Section 7 (Read replicas mentioned)**

**Issue:**
The design mentions "read replicas for load distribution" but doesn't specify how they're used for the time-series workload. The mixed read/write pattern on the same vital_data table will cause:

- **Replication lag**: 5000 writes/sec generates significant WAL traffic; read replicas may lag 5-30 seconds behind primary
- **Inconsistent reads**: Dashboard may show stale data if querying replica
- **Lock contention**: Dashboard queries on primary compete with inserts

**Impact:**
- Dashboard displays outdated vitals during peak write load
- Increased query latency due to lock waits on primary
- Replication lag compounds with table growth

**Recommendation:**

**Strategy A: Functional separation** (if using standard PostgreSQL)
- **Primary**: Write-only for vital_data inserts
- **Replica**: Read-only for dashboard queries, reports
- Application routes queries based on operation type
- Accept eventual consistency (5-10 second lag acceptable for historical queries, NOT for latest vitals)
- **Critical**: Latest vitals must query primary OR use Redis cache (see issue #4)

**Strategy B: Time-based partitioning** (if using TimescaleDB)
- Write to current partition (today's chunk)
- Read from recent partitions (no lock contention)
- Replicas serve historical queries (older partitions, no lag impact)

---

### 6. Lack of Batch Processing for Write Throughput

**Severity: SIGNIFICANT**
**Reference: Section 3 (Data flow, "即時保存")**

**Issue:**
The design states that vital data is "immediately saved to DB" upon receipt. Individual INSERT statements for 5000 records/sec will cause:

- **Network round-trips**: 5000 round-trips/sec between application and database
- **Transaction overhead**: Each INSERT commits separately (assuming auto-commit)
- **WAL write amplification**: 5000 fsync calls/sec (limited by disk IOPS)

**Impact:**
- Write latency per record increases from <1ms (batch) to 5-20ms (individual)
- Database connection pool exhaustion (1 connection per in-flight write)
- CPU overhead from transaction management

**Recommendation:**

**Batch insertion strategy:**

1. **Micro-batching in WebSocket server**:
   - Buffer incoming vital data for 100-500ms
   - Insert as single `INSERT INTO ... VALUES (row1), (row2), ..., (rowN)` statement
   - Batch size: 100-500 records (balance latency vs throughput)

2. **Async write queue**:
   - WebSocket server enqueues data to in-memory buffer (ring buffer)
   - Dedicated writer threads batch-insert from queue
   - Backpressure handling: If queue fills, reject new connections (circuit breaker)

3. **Trade-off analysis**:
   - Latency increase: 100ms average (buffering time)
   - Throughput gain: 10-50x (batch vs individual)
   - Data loss risk: In-memory buffer lost on crash (mitigate with WAL or Kafka if unacceptable)

**Expected impact:**
- Write throughput: 50k-100k records/sec (10-20x improvement)
- Database connection usage: 10-20 connections (vs 1000+ for individual writes)
- CPU utilization: 30-50% reduction

---

## Moderate Issues

### 7. Missing Index Strategy for Time-Series Queries

**Severity: MODERATE**
**Reference: Section 4 (vital_data table)**

**Issue:**
The `vital_data` table schema shows primary key on `data_id` (BIGSERIAL) but no explicit index definitions for query patterns:

- **Latest vitals query**: `SELECT * FROM vital_data WHERE patient_id = ? ORDER BY timestamp DESC LIMIT 1`
  - Requires composite index on `(patient_id, timestamp DESC)`
- **History range query**: `SELECT * FROM vital_data WHERE patient_id = ? AND timestamp BETWEEN ? AND ?`
  - Requires composite index on `(patient_id, timestamp)`
- **Device query**: `SELECT * FROM vital_data WHERE device_id = ? AND timestamp > ?`
  - Requires composite index on `(device_id, timestamp)`

Without proper indexes:
- Table scans on multi-billion row table (minutes per query)
- Index-only scans not possible (must fetch from heap)

**Impact:**
- Query latency exceeds 500ms SLA within days of operation
- Dashboard timeouts under load

**Recommendation:**

**Index strategy:**
```sql
-- Primary query pattern: Latest vitals per patient
CREATE INDEX idx_vital_patient_ts_desc ON vital_data (patient_id, timestamp DESC)
  INCLUDE (data_type, value, unit, device_id);

-- Historical range queries
CREATE INDEX idx_vital_device_ts ON vital_data (device_id, timestamp);

-- Alert processing (if querying by data_type)
CREATE INDEX idx_vital_type_ts ON vital_data (data_type, timestamp);
```

**If using TimescaleDB**:
- Automatic time-based indexing on hypertables
- No need for manual timestamp indexes

**Trade-off:**
- Write performance impact: 10-15% slowdown due to index maintenance
- Storage overhead: 30-50% additional space for indexes
- **Benefit**: Query speedup from O(n) table scan to O(log n) index seek

---

### 8. Alert Service Design Lacks Throttling and Deduplication

**Severity: MODERATE**
**Reference: Section 3 (Alert Service), Section 4 (alert_rules)**

**Issue:**
The Alert Service "detects anomalies and notifies medical staff via Pub/Sub" but doesn't address:

- **Alert storm**: If a patient's heart rate oscillates around a threshold (e.g., 99-101 bpm, threshold 100), it could trigger thousands of alerts
- **Notification fatigue**: Staff overwhelmed by duplicate alerts for the same condition
- **No temporal context**: Single anomalous reading may not warrant immediate alert (transient sensor error vs sustained condition)

**Impact:**
- Alert fatigue reduces response effectiveness
- Pub/Sub queue overload during alert storms
- Notification costs spike (SMS/push notification services)

**Recommendation:**

**Alert processing pipeline:**

1. **Temporal windowing**: Require N consecutive anomalous readings (e.g., 3 readings over 10 seconds) before triggering alert
2. **Deduplication**: Track active alerts per patient; suppress duplicates until condition resolves
3. **Rate limiting**: Maximum 1 alert per patient per condition per 5 minutes
4. **Severity-based routing**:
   - **HIGH severity**: Immediate push notification
   - **MEDIUM severity**: Batch every 30 seconds
   - **LOW severity**: Dashboard indicator only, no notification

**Implementation:**
- Use Redis sorted sets to track alert state and cooldown periods
- Example:
  ```
  ZADD active_alerts:{patient_id} {current_timestamp} {alert_type}
  EXPIRE active_alerts:{patient_id} 300  # 5-minute cooldown
  ```

---

### 9. No Connection Pool Sizing Strategy

**Severity: MODERATE**
**Reference: Section 7 (5000 concurrent devices), Section 2 (ECS, RDS)**

**Issue:**
The design mentions "connection pooling" but provides no sizing guidance. With 5000 concurrent WebSocket connections, improper pool sizing will cause:

- **Under-provisioning**: Connection exhaustion, request queuing, timeouts
- **Over-provisioning**: Database memory exhaustion (each connection consumes ~10MB), reduced cache buffer efficiency

**Impact:**
- Connection timeouts during peak load
- Database OOM (Out Of Memory) if connections exceed max_connections
- Degraded query performance due to reduced shared_buffers

**Recommendation:**

**Connection pool sizing formula:**

For RDS PostgreSQL:
- **Max connections**: `(DBInstanceRAM / 9531392) - 10` (AWS formula)
- Example: db.r5.4xlarge (128GB RAM) = ~13,800 max connections

**Application pool sizing:**

1. **WebSocket servers** (write-heavy):
   - Use batch writes (see issue #6)
   - Pool size per instance: 20-50 connections
   - Total: 5 ECS tasks × 50 = 250 connections

2. **REST API servers** (read-heavy):
   - Pool size per instance: 50-100 connections
   - Total: 10 ECS tasks × 100 = 1,000 connections

3. **Batch/Report services**:
   - Pool size: 10-20 connections

**Total connection budget**: ~1,500 connections (well below RDS limit)

**Pool configuration** (HikariCP):
```yaml
hikari:
  maximum-pool-size: 50
  minimum-idle: 10
  connection-timeout: 30000
  idle-timeout: 600000
  max-lifetime: 1800000
```

---

### 10. Report Generation May Block on Large Data Scans

**Severity: MODERATE**
**Reference: Section 3 (Report Generator), Section 5 (POST /api/reports/generate)**

**Issue:**
"Daily/weekly patient summary reports" will require scanning millions of vital_data records. Synchronous generation will:

- Hold database connections for minutes
- Block connection pool availability
- Timeout if report exceeds request timeout (typically 30-60s)

**Impact:**
- Report generation failures for busy patients
- Connection pool starvation during report runs
- Poor user experience (long wait times)

**Recommendation:**

**Async report generation workflow:**

1. **POST /api/reports/generate** returns immediately with `report_id` and status `PENDING`
2. Background worker processes report:
   - Query data in batches (pagination)
   - Stream results to S3 in chunks
   - Update status to `COMPLETED` or `FAILED`
3. **GET /api/reports/{reportId}** returns status; if `COMPLETED`, includes S3 download URL

**Optimization strategies:**
- **Pre-aggregation**: Use materialized views or TimescaleDB continuous aggregates for hourly/daily rollups
  - Example: Instead of scanning 86,400 raw records for daily heart rate average, query 24 pre-computed hourly averages
- **Incremental reports**: For recurring reports, only process delta since last run
- **Partition pruning**: Leverage time-based partitioning to scan only relevant partitions

---

## Minor Improvements

### 11. WebSocket Connection State Management

**Reference: Section 3 (WebSocket Server)**

**Observation:**
No mention of connection state persistence or recovery. If WebSocket server crashes/restarts:
- Device connections drop
- Reconnection storm (5000 devices reconnecting simultaneously)
- Data loss during reconnection window (1-second data intervals)

**Suggestion:**
- Implement connection registry in Redis (device_id -> server_id mapping)
- Graceful shutdown: Send GOAWAY frame to clients, wait for clean disconnect
- Connection draining during deployment (don't terminate active connections)
- Client-side retry with exponential backoff + jitter to prevent thundering herd

---

### 12. Missing Database Backup and Recovery Strategy

**Reference: Section 7 (99.9% availability, Multi-AZ)**

**Observation:**
Multi-AZ provides HA for hardware failures but doesn't address:
- Accidental data deletion (human error)
- Logical corruption (application bug writes bad data)
- Ransomware/malicious deletion

**Suggestion:**
- **Point-in-time recovery** (PITR): RDS automatic backups (7-35 days retention)
- **Snapshot retention**: Weekly snapshots retained for 1 year (regulatory compliance)
- **Backup testing**: Monthly restore drill to verify RTO/RPO
- **Cross-region replication**: Disaster recovery for regional outages

**Recovery objectives:**
- RTO (Recovery Time Objective): 1 hour
- RPO (Recovery Point Objective): 5 minutes (based on WAL archiving frequency)

---

## Positive Aspects

1. **Multi-AZ RDS configuration**: Provides automatic failover for high availability
2. **Read replicas**: Good foundation for read scaling (needs routing strategy)
3. **Auto-scaling ECS tasks**: Responds to CPU utilization spikes
4. **Performance SLA definition**: Clear p95 latency target (500ms) enables measurement
5. **Comprehensive authentication**: JWT for users, API key for devices
6. **Blue/Green deployment**: Minimizes deployment downtime risk

---

## Summary and Prioritized Recommendations

### Must-Fix (Before Production Launch)

1. **Implement data lifecycle management** (Issue #1): Partition, archive, and purge strategy to prevent unbounded growth
2. **Migrate to time-series optimized storage** (Issue #2): TimescaleDB or dedicated TSDB to handle 5000 writes/sec
3. **Replace polling with WebSocket push** (Issue #3): Reduce latency and database load for dashboard updates

### High Priority (Within First Month)

4. **Add Redis caching layer** (Issue #4): Cache latest vitals, active patients list
5. **Implement batch writes** (Issue #6): 10-50x throughput improvement
6. **Define index strategy** (Issue #7): Prevent query performance degradation

### Medium Priority (Within First Quarter)

7. **Alert throttling and deduplication** (Issue #8): Prevent alert fatigue
8. **Connection pool sizing** (Issue #9): Document and configure pool limits
9. **Async report generation** (Issue #10): Prevent blocking on large scans

### Nice-to-Have

10. **Connection state management** (Issue #11): Graceful shutdowns and reconnections
11. **Backup/recovery strategy** (Issue #12): Define RTO/RPO, test recovery procedures

---

## Performance Risk Assessment

| Risk Area | Current State | Risk Level | Mitigation Priority |
|-----------|---------------|------------|---------------------|
| Data growth | No lifecycle plan | **CRITICAL** | Must-fix |
| Write throughput | Standard PostgreSQL, 5000/sec target | **CRITICAL** | Must-fix |
| Read latency | No caching, polling pattern | **HIGH** | Must-fix |
| Query performance | No index strategy | **HIGH** | High priority |
| Alert processing | No throttling | **MEDIUM** | Medium priority |
| Connection management | Undefined pool sizing | **MEDIUM** | Medium priority |

**Conclusion**: The current design will encounter severe performance bottlenecks within 30-90 days of production deployment. Addressing the critical issues (data lifecycle, time-series storage, and caching) is essential before launch.
