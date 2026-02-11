# Performance Design Review - Medical Device Management Platform

## Overall Performance Assessment

**Critical Performance Risk: 6/10** - The system has fundamental scalability and data lifecycle issues that will severely impact long-term operations.

---

## Evaluation Criteria Scores

### 1. Algorithm & Data Structure Efficiency: 3/5

**Issues Identified:**

- **BIGSERIAL primary key on high-velocity time-series table**: The `vital_data` table uses `BIGSERIAL` for `data_id`, which becomes a write bottleneck at 5000 writes/second. Sequential ID generation creates lock contention in PostgreSQL.
- **No index strategy defined**: Critical queries like "latest vital data per patient" and "vital history by time range" will require full table scans without proper indexing on (`patient_id`, `timestamp`) or (`device_id`, `timestamp`).

**Recommendations:**

- Consider partitioning strategy instead of single BIGSERIAL sequence (e.g., composite key with device_id + timestamp)
- Define explicit index strategy: composite index on (`patient_id`, `timestamp` DESC) for dashboard queries
- Consider TimescaleDB or time-series optimized database extensions for PostgreSQL

### 2. I/O & Network Efficiency: 2/5

**Critical Issues:**

- **Dashboard polling at 5-second intervals**: With 5000 active devices across multiple patients, the REST API will be hammered by polling requests. At scale (e.g., 50 concurrent dashboard users), this creates 10 queries/second just for polling.
- **No batch write strategy for vital data**: WebSocket Server writes each vital record immediately ("DBに即時保存"). At 5000 devices × 1 record/second = 5000 individual INSERT operations/second. This will exhaust database connection pool and create I/O bottlenecks.
- **Potential N+1 query problem**: The `/api/dashboard/active-patients` endpoint likely needs to join `patients`, `devices`, and `vital_data` tables. Without explicit eager loading strategy, this will trigger N+1 queries.

**Recommendations:**

- Replace polling with WebSocket push for dashboard updates
- Implement batch write buffering: collect 10-100 vital records and write in batches
- Use Spring Data JPA fetch joins or entity graphs to prevent N+1 queries
- Consider write-ahead log pattern with async flushing to reduce I/O latency

### 3. Caching Strategy: 1/5

**Critical Omission:**

- **No caching layer defined**: Despite high read frequency for dashboard and latest vitals, there is no mention of Redis, in-memory cache, or any caching strategy.
- **Repeated queries for static data**: `alert_rules`, `devices` metadata, and `patients` information are read frequently but change infrequently—perfect cache candidates.
- **Latest vitals query inefficiency**: The `/api/patients/{patientId}/vitals/latest` endpoint will repeatedly hit the database even though data only changes every 5 seconds.

**Recommendations:**

- Introduce Redis for caching:
  - Latest vital data per patient (TTL: 5 seconds)
  - Alert rules (invalidate on update)
  - Device metadata (invalidate on update)
- Implement Spring Cache abstraction with Redis backend
- Use cache-aside pattern for dashboard queries

### 4. Memory & Resource Management: 3/5

**Issues Identified:**

- **WebSocket connection memory footprint**: 5000 concurrent WebSocket connections × 1 message/second will accumulate in server memory if not properly managed. No mention of connection pooling limits or memory configuration.
- **Database connection pool sizing**: Spring Boot default (HikariCP ~10 connections) is insufficient for 5000 writes/second workload. No connection pool configuration specified.
- **Report generation memory risk**: The Report Generator creates "日次・週次の患者サマリ" but doesn't specify pagination/streaming strategy. Loading entire patient vital history into memory will cause OOM errors.

**Recommendations:**

- Configure WebSocket server memory limits and backpressure handling
- Increase HikariCP connection pool size to match workload (e.g., 50-100 connections)
- Implement streaming report generation with ResultSet streaming or cursor-based pagination
- Define heap size and GC tuning for ECS tasks (not just "Docker, ECS (Fargate)")

### 5. Data Lifecycle & Capacity Planning: 1/5

**CRITICAL DEFICIENCY:**

This is the most severe omission in the design document.

**Missing Data Lifecycle Strategy:**

- **No retention policy**: At 5000 records/second, the `vital_data` table will accumulate **432 million records per day** (5000 × 86400). After 1 year: **157 billion records**.
- **No archival strategy**: The design stores all historical vital data in the same PostgreSQL table indefinitely. This will:
  - Degrade query performance exponentially as table grows
  - Exhaust RDS storage (even with auto-scaling, cost will skyrocket)
  - Make index maintenance unbearably slow
- **No purging policy**: No mention of when/how to delete old vital data. Medical regulations typically require 7-10 years retention, but active operational data should be much shorter (e.g., 90 days).
- **No capacity projections**: The design mentions "データ書き込みスループット: 5000レコード/秒" but doesn't project:
  - Storage growth: ~157 billion records/year × ~100 bytes/record = **15.7 TB/year** (uncompressed)
  - Query performance degradation timeline: When will latest vitals queries start timing out?
  - Cost projection: RDS storage, IOPS, backup costs

**Impact Analysis:**

- **6-12 months to system failure**: Without partitioning/archival, query latency will breach SLA (500ms p95) within months
- **Cost explosion**: AWS RDS storage costs will grow linearly, potentially reaching thousands of dollars/month
- **Operational nightmare**: Manual data purging will require table locks, causing downtime

**Recommendations:**

- **Immediate**: Implement PostgreSQL table partitioning by timestamp (monthly partitions)
  - Old partitions can be detached and archived to S3 as Parquet files
  - Active queries only scan recent partitions (e.g., last 90 days)
- **Data Retention Policy**:
  - Active operational data: 90 days in PostgreSQL (real-time queries)
  - Warm archive: 91 days - 2 years in S3 + Athena (historical analysis)
  - Cold archive: 2-7 years in S3 Glacier (compliance)
  - Purge: After 7 years (or per hospital policy)
- **Automated Lifecycle Management**:
  - Daily job to detach old partitions and upload to S3
  - Weekly job to purge partitions older than 7 years
- **Capacity Monitoring**:
  - Alert when active partition size exceeds threshold (e.g., 100 GB)
  - Dashboard showing storage growth rate and projected exhaustion date

### 6. Latency, Throughput Design & Scalability: 3/5

**Issues Identified:**

- **No asynchronous processing for alerts**: The Alert Service "検知し、Pub/Sub経由で通知" but doesn't specify whether detection is synchronous (blocking write path) or asynchronous (event-driven). Synchronous detection will add latency to vital data writes.
- **Read replica strategy underutilized**: The design mentions "データベースリードレプリカ（読み取り負荷分散）" but doesn't specify query routing strategy. Dashboard queries hitting primary will bottleneck writes.
- **Stateless design unclear**: No mention of session affinity requirements for WebSocket connections. If WebSocket server pods are not truly stateless, horizontal scaling will fail.
- **No sharding strategy**: At 5000 devices, a single PostgreSQL instance may suffice, but scaling to 50,000+ devices (multi-hospital) will require sharding by `hospital_id` or `patient_id`.

**Positive Aspects:**

- ECS auto-scaling based on CPU usage is appropriate
- Blue/Green deployment strategy reduces downtime risk
- p95 latency target (500ms) is well-defined

**Recommendations:**

- Make alert detection asynchronous: write vital data → emit event → Alert Service consumes event
- Explicitly route read queries (dashboard, reports) to read replica; write queries to primary
- Document WebSocket session storage strategy (in-memory only, no sticky sessions)
- Plan sharding strategy for future scaling (even if not implemented now)

---

## NFR & Scalability Checklist Assessment

### Capacity Planning: ❌ CRITICAL FAILURE
- ✅ Expected user load defined (5000 devices)
- ❌ **Data volume growth projections missing** (157 billion records/year)
- ❌ **Resource sizing insufficient** (no connection pool, cache, partition strategy)

### Horizontal/Vertical Scaling: ⚠️ PARTIAL
- ✅ ECS auto-scaling defined
- ⚠️ Stateless design unclear (WebSocket session handling)
- ❌ Database sharding strategy missing

### Performance SLA: ✅ GOOD
- ✅ Response time requirements defined (p95 < 500ms)
- ✅ Throughput targets defined (5000 records/sec)

### Monitoring & Observability: ⚠️ PARTIAL
- ✅ CloudWatch Logs integration
- ❌ No mention of distributed tracing (critical for debugging latency issues)
- ❌ No performance metrics collection strategy (e.g., JVM metrics, query latency distribution)

### Resource Limits: ❌ INSUFFICIENT
- ❌ Connection pool sizing not specified
- ❌ Rate limiting not mentioned (API abuse risk)
- ❌ Timeout configurations not defined
- ❌ Circuit breaker pattern not mentioned

### Database Scalability: ⚠️ PARTIAL
- ✅ Read/write separation planned (read replica)
- ❌ Index optimization strategy missing
- ❌ Sharding strategy missing

---

## Priority Recommendations Summary

### Critical (Implement Immediately)
1. **Define and implement data lifecycle management** (retention/archival/purging)
2. **Add table partitioning for `vital_data`** (monthly partitions)
3. **Implement batch write buffering** (replace immediate writes with batching)
4. **Introduce caching layer** (Redis for latest vitals, alert rules, device metadata)

### High Priority (Implement Before Production)
5. **Replace dashboard polling with WebSocket push**
6. **Define and implement index strategy** (composite indexes on vital_data)
7. **Configure connection pool sizing** (HikariCP tuning)
8. **Add distributed tracing** (Spring Cloud Sleuth + Zipkin/Jaeger)

### Medium Priority (Optimize Post-Launch)
9. **Make alert detection asynchronous** (event-driven architecture)
10. **Implement rate limiting and circuit breakers**
11. **Plan database sharding strategy for future scaling**

---

## Conclusion

The design has solid infrastructure foundation (ECS, ALB, RDS multi-AZ) and well-defined SLA targets. However, **data lifecycle management is critically absent**, which will cause system failure within 6-12 months due to unbounded storage growth and query performance degradation.

The lack of caching strategy, batch write optimization, and asynchronous processing will prevent the system from meeting its 5000 devices/second target under sustained load.

**Overall Severity: HIGH** - Requires major revisions to data lifecycle and performance architecture before production deployment.
