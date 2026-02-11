# Performance Architecture Review: Medical Device Management Platform

## Executive Summary

This review evaluates the medical device management platform design from a performance architecture perspective. The system handles real-time streaming data from thousands of medical devices with critical performance and scalability requirements.

**Overall Assessment**: The design demonstrates several strengths in defining performance targets but has **critical architectural gaps** in data lifecycle management, caching strategy, and resource optimization that could severely impact long-term scalability and operational costs.

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 3/5 | Basic data model present but no index design specified for time-series queries |
| I/O & Network Efficiency | 2/5 | Dashboard polling pattern inefficient; no batch processing design for writes |
| Caching Strategy | 1/5 | **Critical**: No caching strategy defined despite high-frequency access patterns |
| Memory & Resource Management | 2/5 | Connection pooling not specified; WebSocket resource lifecycle unclear |
| Data Lifecycle & Capacity Planning | 1/5 | **Critical**: No retention/archival/purging strategy for continuously growing vital_data |
| Latency, Throughput Design & Scalability | 3/5 | Good SLA definitions but missing asynchronous processing and write optimization |

**Average Score: 2.0/5**

---

## Critical Issues

### 1. **Missing Data Lifecycle Strategy for Time-Series Data** (Severity: CRITICAL)

**Issue**: The `vital_data` table receives 5000 records/second (432 million records/day) with no defined retention, archival, or purging strategy.

**Impact**:
- **Storage Growth**: At ~100 bytes/record → 43.2 GB/day → 1.3 TB/month → 15.7 TB/year
- **Query Performance Degradation**: PostgreSQL table scans will slow dramatically as table size grows
- **Index Bloat**: B-tree indexes on timestamp/patient_id will degrade over time
- **Backup/Recovery Time**: Exponentially increasing backup windows and RTO

**Missing Elements**:
- No definition of how long vital data should remain in active (hot) storage
- No archival strategy for moving old data to cold storage (S3, Glacier)
- No purging policy for data no longer required for regulatory/clinical purposes
- No capacity projections showing expected storage growth over 1/3/5 years
- No query performance benchmarks against projected data volumes

**Recommendations**:
1. **Define Tiered Retention Policy**:
   - Hot storage (PostgreSQL): Last 30 days for real-time dashboards
   - Warm storage (S3 Standard): 31-365 days for historical reports
   - Cold storage (S3 Glacier): 1-7 years for regulatory compliance
   - Auto-purge after 7 years (or per regulatory requirement)

2. **Implement Partitioning Strategy**:
   ```sql
   -- Monthly partitioning on vital_data
   CREATE TABLE vital_data_2026_02 PARTITION OF vital_data
   FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
   ```
   - Automatic partition pruning for time-range queries
   - Detach old partitions for archival without table locks

3. **Archival Pipeline**:
   - Daily batch job to export partitions older than 30 days to Parquet on S3
   - Update queries to fall back to S3 Select for historical data beyond 30 days
   - Estimated cost reduction: Hot storage 43 GB vs. 15.7 TB = **99.7% reduction**

4. **Capacity Projection**:
   - Document expected growth: "With 5000 devices @ 1 record/sec, we expect 1.3 TB/month growth, requiring monthly archival to maintain <50 GB hot storage"

**Reference**: Section 4 (Data Model - vital_data table), Section 7 (Performance - 5000 records/sec throughput)

---

### 2. **No Caching Strategy Defined** (Severity: CRITICAL)

**Issue**: Despite high-frequency access patterns (dashboard polling every 5s, alert rule lookups for every data point), no caching layer is mentioned.

**Impact**:
- **Database Overload**: 5000 writes/sec + continuous read queries will saturate RDS connection pool
- **Latency Violations**: 500ms p95 latency target unachievable with cold PostgreSQL queries
- **Unnecessary Read Replicas**: Without caching, the design will require excessive (and expensive) read replicas

**Missing Cache Targets**:
1. **Alert Rules** (`alert_rules` table):
   - Read-heavy (checked against every incoming data point = 5000 reads/sec)
   - Write-rarely (rules change infrequently)
   - Perfect for Redis with TTL=3600s, invalidate on rule updates

2. **Latest Vital Data** (`/api/patients/{id}/vitals/latest`):
   - Accessed every 5s by all active dashboards
   - Stale data acceptable (already 5s polling lag)
   - Cache in Redis with TTL=5s, write-through on new data arrival

3. **Device Metadata** (`devices` table):
   - Moderate read frequency (dashboard listings, device authentication)
   - Write-occasionally (status updates, patient assignment)
   - Cache with TTL=300s, invalidate on updates

4. **Active Patients List** (`/api/dashboard/active-patients`):
   - Heavy read (all staff dashboards)
   - Moderate write (patient admissions/discharges)
   - Cache with TTL=60s

**Recommendations**:
1. **Add Redis Cluster** to architecture diagram:
   ```
   [WebSocket Server] → [Redis Cache] → [PostgreSQL]
                              ↓
                       [REST API Server]
   ```

2. **Cache Configuration**:
   - `alert_rules`: Write-through, TTL=3600s, ~10 KB total
   - `latest_vitals`: Write-through, TTL=5s, ~5000 keys × 500 bytes = 2.5 MB
   - `devices`: Cache-aside, TTL=300s, ~5000 keys × 200 bytes = 1 MB
   - Total memory: <10 MB for critical hot data

3. **Estimated Impact**:
   - Alert rule lookups: 5000 DB queries/sec → 0.3 queries/sec (99.99% hit rate)
   - Latest vitals API: 100% cache hit (assuming 5s polling matches cache TTL)
   - Reduces RDS load by ~80%, enables 500ms p95 latency target

**Reference**: Section 5 (API Design - high-frequency endpoints), Section 3 (Data Flow - 5s polling)

---

## Significant Issues

### 3. **Inefficient Dashboard Data Retrieval Pattern** (Severity: HIGH)

**Issue**: Dashboards poll REST API every 5 seconds (`GET /api/patients/{id}/vitals/latest`) for each monitored patient. No WebSocket push mechanism for dashboard updates.

**Impact**:
- **Unnecessary Network Roundtrips**: For 100 concurrent patients × 100 active dashboards = 10,000 HTTP requests every 5 seconds = 2,000 req/sec
- **Client-Server Inefficiency**: Data is already flowing through WebSocket Server but dashboards don't subscribe to it
- **Increased Latency**: 5-second polling lag vs. instant push updates

**Recommendations**:
1. **Implement Server-Sent Events (SSE) or WebSocket for Dashboards**:
   ```
   [WebSocket Server] → [Pub/Sub (Redis)] → [Dashboard SSE Endpoint]
   ```
   - Publish vital data updates to Redis Pub/Sub channel per patient
   - Dashboard subscribes to relevant patient channels
   - Eliminates 2,000 req/sec polling traffic

2. **Fallback Pattern**:
   - Use SSE for modern browsers, fall back to polling for older clients
   - Reduce polling frequency to 30s as fallback (not primary mechanism)

3. **Estimated Impact**:
   - Reduces API server load by 80-90%
   - Improves dashboard update latency from 5s average to <100ms
   - Reduces ALB data transfer costs

**Reference**: Section 3 (Data Flow - step 5: "ダッシュボードがREST APIでデータを定期ポーリング（5秒間隔）")

---

### 4. **PostgreSQL Not Optimized for Time-Series Workload** (Severity: HIGH)

**Issue**: Using standard PostgreSQL for high-velocity time-series data without time-series optimizations (TimescaleDB, partitioning, specialized indexes).

**Impact**:
- **Write Amplification**: Each insert updates multiple indexes (PRIMARY KEY, FK indexes on device_id, patient_id, timestamp)
- **Index Bloat**: B-tree indexes on timestamp will bloat rapidly with insert-only workload
- **Query Performance**: Range queries (`WHERE timestamp BETWEEN ...`) will require index scans over billions of rows
- **Vacuum Overhead**: Continuous writes create dead tuples requiring frequent autovacuum

**Recommendations**:
1. **Consider TimescaleDB Extension**:
   - Automatic time-based partitioning (hypertables)
   - Compression for old chunks (10x storage reduction)
   - Optimized time-range query planner
   - Continuous aggregates for dashboard summary queries

2. **If Staying with Standard PostgreSQL**:
   - Implement declarative partitioning (monthly partitions as shown in Issue #1)
   - Use BRIN indexes instead of B-tree for timestamp column (90% smaller, faster writes)
   - Create composite index: `(patient_id, timestamp DESC)` for latest-vitals queries
   - Configure aggressive autovacuum for vital_data table

3. **Alternative Architecture**:
   - Use InfluxDB/TimescaleDB for vital_data (time-series optimized)
   - Keep PostgreSQL for relational data (patients, devices, alert_rules)
   - Estimated write performance: 50,000 writes/sec vs. current 5,000 writes/sec limit

**Reference**: Section 2 (Technology Stack - "時系列データ: PostgreSQL"), Section 4 (vital_data table schema)

---

### 5. **No Batch Write Strategy for Vital Data** (Severity: HIGH)

**Issue**: Design implies one DB write per incoming data point (5,000 individual INSERT statements/second).

**Impact**:
- **Connection Pool Exhaustion**: Each INSERT holds a connection for ~10ms → requires 50+ connections just for writes
- **Transaction Overhead**: 5,000 transactions/sec create significant WAL write amplification
- **Replication Lag**: Synchronous replication to standby will bottleneck on commit rate

**Recommendations**:
1. **Implement Micro-Batching**:
   ```java
   // Collect 100ms of data before batch insert
   @Scheduled(fixedDelay = 100)
   public void flushVitalDataBatch() {
       vitalDataRepository.saveAll(batchBuffer); // 500 records per batch
   }
   ```
   - Reduces 5,000 INSERTs/sec → 50 batch INSERTs/sec
   - Reduces connection usage by 99%
   - Adds max 100ms latency (acceptable given 5s dashboard polling)

2. **Use COPY Protocol for Bulk Inserts**:
   - PostgreSQL COPY is 5-10x faster than individual INSERTs
   - Spring Data JPA doesn't support COPY natively, use JDBC template:
   ```java
   pgConnection.getCopyAPI().copyIn(
       "COPY vital_data FROM STDIN WITH CSV",
       csvInputStream
   );
   ```

3. **Asynchronous Write Queue**:
   - WebSocket handler writes to in-memory queue (non-blocking)
   - Background thread drains queue in batches
   - Prevents device connection backpressure from DB write latency

**Reference**: Section 3 (Data Flow - step 3: "DBに即時保存"), Section 7 (Performance - 5000 records/sec)

---

## Moderate Issues

### 6. **Missing Index Design for Query Patterns** (Severity: MEDIUM)

**Issue**: Data model defines tables but no indexes specified for known access patterns.

**Critical Missing Indexes**:
1. `vital_data(patient_id, timestamp DESC)` - for latest vitals query
2. `vital_data(device_id, timestamp)` - for device-specific history
3. `vital_data(timestamp, data_type, value)` - for alert scanning
4. `devices(hospital_id, status)` - for dashboard active device listings

**Recommendations**: Document index design in schema definition with query justification.

---

### 7. **Alert Service Pub/Sub Architecture Unspecified** (Severity: MEDIUM)

**Issue**: "Alert Serviceが異常値を検知し、Pub/Sub経由で通知" mentioned but no details on implementation.

**Questions**:
- What Pub/Sub system? (SNS, Redis Pub/Sub, internal event bus?)
- How does Alert Service consume vital data? (Polling DB? Subscribe to data stream?)
- What happens if Alert Service is down? (Alert delivery guarantee?)

**Recommendations**:
- Clarify Pub/Sub implementation (suggest Redis Pub/Sub for low latency)
- Alert Service should subscribe to data stream, not poll DB
- Define alert delivery SLA (e.g., "95% of alerts delivered within 2 seconds")

---

### 8. **WebSocket Connection Resource Management Unclear** (Severity: MEDIUM)

**Issue**: With 5,000 concurrent WebSocket connections, resource management details are missing.

**Missing Details**:
- Connection timeout configuration (idle devices)
- Heartbeat/ping mechanism to detect stale connections
- Memory allocation per connection (buffer sizes)
- How are connections cleaned up when devices disconnect ungracefully?

**Recommendations**:
- Configure idle timeout (e.g., 60s without data = force disconnect)
- Implement PING/PONG heartbeat every 30s
- Set receive buffer size limit (e.g., 4KB to prevent memory exhaustion)
- Document expected memory footprint: 5,000 connections × 64KB/connection = 320 MB

**Reference**: Section 3 (WebSocket Server component)

---

### 9. **Report Generation Performance Not Addressed** (Severity: MEDIUM)

**Issue**: "定期レポートの生成（バッチ処理）" mentioned but no performance considerations for long-running aggregation queries.

**Concerns**:
- Daily/weekly reports will query millions of vital_data records
- Aggregation queries will compete with real-time writes for DB resources
- No mention of read replicas for reporting workload

**Recommendations**:
1. Route report queries to dedicated read replica
2. Use materialized views or pre-aggregated summary tables
3. Generate reports from archived S3 data (not hot DB) for historical periods
4. Define report generation SLA (e.g., "daily reports complete within 30 minutes")

**Reference**: Section 3 (Report Generator component), Section 5 (POST /api/reports/generate)

---

## Minor Issues & Observations

### 10. **Auto-Scaling Trigger May Be Too Late** (Severity: LOW)

**Current**: "ECSタスク数の自動スケーリング（CPU使用率70%で追加）"

**Concern**: At 70% CPU, response time may already be degraded. Network-bound services often need earlier scaling.

**Recommendation**: Consider multi-metric scaling (CPU 60% OR active connection count > 4000).

---

### 11. **Database Connection Pool Sizing Not Specified** (Severity: LOW)

**Issue**: No mention of connection pool configuration despite high concurrency requirements.

**Recommendation**: Document connection pool sizing (e.g., HikariCP max pool size = 50, connection timeout = 5s).

---

## Positive Aspects

1. **Clear Performance SLAs**: Well-defined targets (p95 latency, throughput, concurrent devices) enable validation
2. **Multi-AZ RDS**: Good availability design with automatic failover
3. **Auto-Scaling**: ECS auto-scaling based on CPU usage shows awareness of dynamic load
4. **Load Testing Plan**: JMeter with 1,000 concurrent devices demonstrates performance validation intent
5. **Read Replica Mentioned**: Shows understanding of read/write workload separation

---

## Summary of Recommendations (Prioritized)

### Immediate (Required for Launch)
1. Define and implement data retention/archival/purging strategy for vital_data
2. Add Redis caching layer for alert rules and latest vitals
3. Implement batch write strategy for vital data ingestion
4. Specify index design for all critical query patterns

### High Priority (Performance Risk)
5. Replace dashboard polling with Server-Sent Events or WebSocket push
6. Evaluate TimescaleDB or implement PostgreSQL partitioning for time-series optimization
7. Clarify Alert Service Pub/Sub architecture and delivery guarantees
8. Document WebSocket connection resource management (timeouts, heartbeats, memory)

### Medium Priority (Operational Improvement)
9. Design report generation strategy (read replicas, pre-aggregation, archival queries)
10. Refine auto-scaling metrics (multi-metric triggers)
11. Specify database connection pool configuration

---

## Overall Assessment

The design demonstrates good awareness of performance targets and includes several positive architectural decisions (multi-AZ, auto-scaling, read replicas). However, **critical gaps in data lifecycle management and caching strategy pose severe risks** to the system's ability to meet its 5,000 device, 5,000 writes/sec requirements at scale.

**Without addressing Issues #1 (data lifecycle) and #2 (caching)**, the system will likely:
- Exceed storage budgets within 6 months
- Fail to meet 500ms p95 latency SLA within 3 months
- Require expensive emergency re-architecture to handle growth

**Recommendation**: Address critical issues #1-5 before proceeding to implementation. These are not "optimizations" but fundamental architectural requirements for a high-velocity time-series system.
