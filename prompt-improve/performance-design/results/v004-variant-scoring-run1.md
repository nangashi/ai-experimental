# Performance Architecture Evaluation Report
**Variant**: S2a (Round 004, Broad Mode)
**Test Document**: Medical Device Management Platform System Design
**Date**: 2026-02-11

---

## Executive Summary

This medical device monitoring platform faces **critical performance and scalability issues** that could lead to system failure under production load. The design lacks essential strategies for handling time-series data growth, exhibits severe database bottlenecks, and has no capacity planning for the stated 5,000 concurrent device connections.

**Overall Assessment**: Requires immediate redesign of data storage, query patterns, and scalability architecture before production deployment.

---

## Scoring Summary

| Criterion | Score | Level | Priority |
|-----------|-------|-------|----------|
| 1. Algorithm & Data Structure Efficiency | 3 | Acceptable | Moderate |
| 2. I/O & Network Efficiency | 2 | Poor | Significant |
| 3. Caching Strategy | 2 | Poor | Significant |
| 4. Memory & Resource Management | 3 | Acceptable | Moderate |
| 5. Data Lifecycle & Capacity Planning | 1 | Critical | **CRITICAL** |
| 6. Latency, Throughput Design & Scalability | 2 | Poor | Significant |

---

## Critical Issues (Score 1-2)

### 1. Data Lifecycle & Capacity Planning: Score 1 (CRITICAL)

**Issue**: Unbounded time-series data growth with no retention, archival, or purging strategy.

**Impact Analysis**:
- **Data Volume Projection**: With 5,000 devices sending data at 1-second intervals, the system will accumulate:
  - **432 million records/day** (5,000 devices × 86,400 seconds × ~1 record/second)
  - **13 billion records/month**
  - **157 billion records/year**
- **Storage Growth**: At ~100 bytes/record, this translates to ~15TB/year of raw data
- **Query Degradation**: PostgreSQL will experience severe performance degradation as `vital_data` table grows beyond hundreds of millions of rows. Even with proper indexing, queries spanning multiple days will become prohibitively slow within 3-6 months.
- **Backup/Restore Impact**: Database backups will grow unmanageably large, making disaster recovery impractical

**Current Design Problems**:
- Section 4 (Data Model) shows no retention policy or archival strategy
- No mention of data lifecycle in Section 7 (Non-functional Requirements)
- BIGSERIAL primary key will eventually hit practical limits
- No partitioning strategy for time-series data

**Recommendations** (IMMEDIATE ACTION REQUIRED):
1. **Implement Time-Based Table Partitioning**:
   - Partition `vital_data` by day or week (e.g., `vital_data_2026_02_01`)
   - Enable automatic partition creation and dropping
   - PostgreSQL native partitioning: `PARTITION BY RANGE (timestamp)`

2. **Define Data Retention Policy**:
   - Hot data (0-7 days): Full-resolution data in PostgreSQL, optimized for real-time queries
   - Warm data (8-90 days): Downsampled to 1-minute averages, stored in PostgreSQL read replicas
   - Cold data (91 days - 3 years): Archived to S3 in Parquet format, queryable via Athena
   - Purge data older than 3 years (or per compliance requirements)

3. **Implement Automated Archival Pipeline**:
   - Daily batch job to aggregate/downsample data older than 7 days
   - Weekly job to export data older than 90 days to S3
   - Automated partition dropping after archival

4. **Alternative: Consider Time-Series Database**:
   - Migrate `vital_data` to TimescaleDB (PostgreSQL extension) or InfluxDB
   - Provides automatic downsampling, retention policies, and compression
   - Can reduce storage by 10-20× with built-in compression

**Document References**: Section 4 (vital_data table), Section 7 (Performance Goals)

---

### 2. I/O & Network Efficiency: Score 2 (POOR)

**Issue A: Severe N+1 Query Problem in Dashboard**

**Problem Description**:
Section 3 describes: "ダッシュボードがREST APIでデータを定期ポーリング（5秒間隔）" combined with Section 5's `GET /api/dashboard/active-patients` endpoint.

This pattern will likely result in:
1. Query to fetch list of active patients (1 query)
2. For each patient, query latest vital data (N queries)
3. For each patient, query active alerts (N queries)

With 100 active patients being monitored simultaneously, this creates **200+ queries every 5 seconds** = **40 queries/second** just for dashboard polling.

**Impact**:
- Database connection pool exhaustion during peak hours
- Increased p95 latency (likely exceeding the 500ms SLA)
- Unnecessary read load on PostgreSQL primary

**Recommendation**:
```sql
-- Replace N+1 pattern with single JOIN query
SELECT
  p.patient_id, p.patient_name,
  d.device_id, d.device_type,
  DISTINCT ON (v.device_id) v.timestamp, v.data_type, v.value
FROM patients p
JOIN devices d ON p.patient_id = d.patient_id
LEFT JOIN LATERAL (
  SELECT * FROM vital_data
  WHERE device_id = d.device_id
  ORDER BY timestamp DESC
  LIMIT 1
) v ON true
WHERE d.status = 'ACTIVE'
ORDER BY p.patient_id, v.device_id, v.timestamp DESC;
```

**Issue B: Polling-Based Dashboard Updates**

**Problem**: 5-second polling from client creates unnecessary network traffic and server load.

**Impact**:
- With 100 concurrent dashboard users, 20 requests/second for potentially unchanged data
- Wastes bandwidth, especially when no updates have occurred
- Prevents true "real-time" monitoring experience

**Recommendation**:
- Implement WebSocket push notifications from server to dashboard
- Server pushes updates only when new vital data arrives or alerts trigger
- Reduces network traffic by 70-90% during normal operation
- Provides sub-second update latency instead of 5-second polling delay

**Document References**: Section 3 (Data Flow step 5), Section 5 (Dashboard API endpoints)

---

### 3. Caching Strategy: Score 2 (POOR)

**Problem**: No caching layer specified for frequently accessed data patterns.

**Missing Cache Opportunities**:

1. **Patient-Device Mappings** (High Impact):
   - Current: Every vital data write requires JOIN to verify `device_id → patient_id` relationship
   - Access Pattern: Read on every WebSocket message (5,000 reads/second)
   - Recommendation: Cache in Redis with 5-minute TTL, invalidate on device assignment changes

2. **Alert Rules** (High Impact):
   - Current: Section 4 shows `alert_rules` table, likely queried on every vital data point
   - Access Pattern: Read 5,000 times/second, updated infrequently (weekly or less)
   - Recommendation: Load all rules into application memory on startup, refresh every 5 minutes

3. **Device Status Information** (Medium Impact):
   - API endpoint `GET /api/devices` and dashboard queries will repeatedly fetch device list
   - Recommendation: Redis cache with 1-minute TTL, invalidate on status updates

4. **Latest Vital Data** (Medium Impact):
   - `GET /api/patients/{patientId}/vitals/latest` is a prime caching candidate
   - Recommendation: Redis cache with 5-second TTL, invalidate on new data writes

**Impact of Missing Cache**:
- Database query load unnecessarily high (5,000-10,000 queries/second vs. achievable 500-1,000)
- Difficulty meeting 500ms p95 latency SLA under load
- Increased RDS instance cost due to over-provisioning to handle cache-miss load

**Implementation Recommendation**:
- Add Redis cluster (ElastiCache) with 3-node setup for high availability
- Use Spring Cache abstraction with Redis backend
- Implement cache-aside pattern with explicit invalidation on writes

**Document References**: Section 3 (Data Flow), Section 7 (Performance Goals)

---

### 4. Latency, Throughput Design & Scalability: Score 2 (POOR)

**Issue A: Synchronous WebSocket Write Bottleneck**

**Problem**: Section 3 states "WebSocket Serverがデータを受信し、DBに即時保存"

**Impact**:
- At 5,000 devices × 1 message/second = 5,000 synchronous database INSERTs per second
- Each WebSocket handler thread blocks on database write (~5-10ms per write)
- With 5,000 concurrent devices, requires 5,000 threads or serialized writes causing latency spikes
- PostgreSQL write throughput will become bottleneck (typical limit: 3,000-5,000 writes/sec on single instance)

**Recommendation**:
1. **Implement Write-Behind Queue**:
   - WebSocket handler writes to in-memory queue (Redis Streams or Kafka)
   - Dedicated consumer batch-writes to PostgreSQL (1,000 records per transaction)
   - Reduces database write load by 100× and frees WebSocket threads immediately

2. **Batch Processing**:
   ```java
   // Pseudo-code
   queue.consume(messages -> {
     jdbcTemplate.batchUpdate(
       "INSERT INTO vital_data (...) VALUES (...)",
       messages,
       batchSize = 1000
     );
   });
   ```

3. **PostgreSQL Tuning**:
   - Set `synchronous_commit = off` for vital_data table (acceptable risk for monitoring data)
   - Increase `wal_buffers` and `shared_buffers` for write-heavy workload

**Issue B: Lack of Horizontal Scaling Strategy**

**Problem**: Section 7 mentions "ECSタスク数の自動スケーリング" but design does not address:
- How WebSocket sessions are distributed across scaled instances
- Session affinity/stickiness requirements for WebSocket connections
- How device reconnections are handled after instance scaling

**Impact**:
- Devices may lose connection during scale-down events
- Uneven load distribution if ALB session affinity is misconfigured

**Recommendation**:
- Implement stateless WebSocket handlers (store session state in Redis)
- Use ALB session stickiness based on device_id hash
- Design graceful connection draining during scale-down (30-60 second delay)

**Issue C: Read Replica Utilization Not Specified**

**Problem**: Section 7 mentions "データベースリードレプリカ" but does not specify read/write splitting strategy.

**Recommendation**:
- Route all dashboard queries and report generation to read replicas
- Route only vital_data writes and alert rule reads to primary
- Use Spring `@Transactional(readOnly = true)` to enforce routing

**Document References**: Section 3 (WebSocket Data Flow), Section 7 (Scalability)

---

## Moderate Issues (Score 3)

### 5. Algorithm & Data Structure Efficiency: Score 3 (ACCEPTABLE)

**Current State**: The design uses straightforward relational data models with standard indexing, which is appropriate for the problem domain. However, some optimization opportunities exist.

**Missing Index Definitions**:
Section 4 (Data Model) does not specify any indexes beyond primary keys. Critical indexes needed:

```sql
-- Critical for vital data queries
CREATE INDEX idx_vital_data_patient_ts ON vital_data(patient_id, timestamp DESC);
CREATE INDEX idx_vital_data_device_ts ON vital_data(device_id, timestamp DESC);

-- Critical for alert processing
CREATE INDEX idx_vital_data_type_ts ON vital_data(data_type, timestamp DESC);

-- For dashboard queries
CREATE INDEX idx_devices_status_patient ON devices(status, patient_id) WHERE status = 'ACTIVE';
```

**Impact**: Without these indexes, queries in Section 5 (`GET /api/patients/{patientId}/vitals/history`) will perform full table scans, causing 10-100× slower response times.

**Positive Aspects**:
- Use of BIGSERIAL for `vital_data` primary key is appropriate for high-volume inserts
- Device-patient relationship model is normalized correctly
- Alert rule structure supports efficient threshold checking

**Minor Optimization**:
Consider adding `BRIN` index for `timestamp` column after implementing partitioning, as it is more space-efficient for time-series data.

**Document References**: Section 4 (Data Model)

---

### 6. Memory & Resource Management: Score 3 (ACCEPTABLE)

**Current State**: Section 6 mentions database connection retry and WebSocket exponential backoff, which are good practices. However, some resource management details are missing.

**Missing Specifications**:

1. **Connection Pool Sizing**:
   - No mention of HikariCP (or equivalent) pool configuration
   - Recommendation: Set `maximumPoolSize = 20` per application instance, `minimumIdle = 5`, `connectionTimeout = 10000ms`

2. **WebSocket Connection Limits**:
   - With 5,000 concurrent devices, each ECS task should limit connections (e.g., 1,000 per instance)
   - Set ALB idle timeout to 300 seconds (WebSocket recommendation)

3. **Memory Allocation**:
   - No JVM heap size or container memory limits specified
   - Recommendation: 4GB heap per ECS task (8GB container memory with `-Xmx4g -Xms4g`)

**Positive Aspects**:
- Exponential backoff for device reconnection prevents thundering herd
- Database retry logic with max 3 attempts prevents cascading failures
- Use of CloudWatch Logs prevents local disk space exhaustion

**Document References**: Section 6 (Error Handling)

---

## NFR & Scalability Checklist Analysis

### Addressed Requirements:
- ✅ Performance SLA: 95th percentile 500ms specified
- ✅ Monitoring: CloudWatch Logs, Slack alerts for critical errors
- ✅ Horizontal Scaling: ECS auto-scaling based on CPU 70% threshold
- ✅ High Availability: RDS Multi-AZ, ALB load balancing

### Missing Requirements:
- ❌ **Capacity Planning**: No analysis of required RDS instance size for 5,000 writes/sec + query load
  - **Recommendation**: Start with db.r6g.2xlarge (8 vCPU, 64GB RAM), evaluate with load testing
- ❌ **Circuit Breakers**: No mention of Resilience4j or similar library for fault tolerance
- ❌ **Rate Limiting**: No protection against misbehaving devices sending excessive data
  - **Recommendation**: Implement token bucket rate limiter (max 2 messages/second per device)
- ❌ **Distributed Tracing**: No mention of X-Ray or OpenTelemetry for latency debugging
- ❌ **Database Sharding**: Not addressed (likely not needed at 5,000 device scale, but document decision)

---

## Positive Performance Aspects

1. **Appropriate Technology Choices**:
   - Spring WebSocket with STOMP is production-proven for this scale
   - PostgreSQL can handle the workload if properly tuned and partitioned
   - ECS Fargate provides elastic scaling without EC2 management overhead

2. **Load Testing Plan**:
   - Section 6 specifies JMeter testing with 1,000 concurrent devices
   - **Recommendation**: Increase to 7,500 devices (1.5× production target) for safety margin

3. **Deployment Safety**:
   - Blue/Green deployments and canary releases minimize production impact
   - Automatic rollback on health check failure is critical for healthcare application

---

## Summary of Recommendations by Priority

### CRITICAL (Implement Before Production):
1. Design and implement time-series data retention/archival strategy
2. Implement table partitioning for `vital_data`
3. Add write-behind queue for WebSocket data ingestion
4. Fix N+1 query pattern in dashboard API

### HIGH (Significant Performance Impact):
5. Implement Redis caching layer for device mappings and alert rules
6. Add comprehensive database indexes
7. Implement WebSocket-based dashboard updates (replace polling)
8. Configure read replica routing strategy

### MEDIUM (Important for Scalability):
9. Add rate limiting for device connections
10. Specify connection pool and resource limits
11. Implement circuit breaker patterns
12. Add distributed tracing

---

## Conclusion

This design requires **immediate architectural revision** in the data lifecycle management area (Score 1) before proceeding to implementation. The unbounded data growth issue will cause system failure within 6-12 months of production deployment.

The I/O patterns, caching, and scalability designs (Score 2) have significant problems that will prevent meeting the stated 500ms p95 SLA under production load, but are addressable with the recommended changes.

Once the critical and high-priority issues are addressed, the architecture can support the stated requirements of 5,000 concurrent devices with appropriate hardware provisioning.

**Estimated Effort to Address Issues**:
- Critical issues: 2-3 weeks of architectural redesign + implementation
- High priority: 1-2 weeks
- Total before production readiness: 4-5 weeks
