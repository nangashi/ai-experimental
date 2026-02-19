# Performance Architecture Review: Medical Device Management Platform

## Executive Summary

This design contains **critical performance risks** that require immediate attention before production deployment. The system aims to handle 5,000 concurrent device connections streaming vital signs data, but fundamental design choices create unbounded data growth, severe database bottlenecks, and scalability limitations that will cause system degradation under normal operation.

**Overall Assessment: Score 1-2 (Critical to Poor) across multiple criteria**

---

## Evaluation Scores by Criterion

| Criterion | Score | Severity |
|-----------|-------|----------|
| Algorithm & Data Structure Efficiency | 3 | Moderate |
| I/O & Network Efficiency | 2 | Significant |
| Caching Strategy | 2 | Significant |
| Memory & Resource Management | 3 | Moderate |
| Data Lifecycle & Capacity Planning | **1** | **CRITICAL** |
| Latency, Throughput Design & Scalability | 2 | Significant |

---

## Critical Issues (Score 1: Requires Immediate Redesign)

### 1. Data Lifecycle & Capacity Planning: Score 1 (CRITICAL)

**Issue: Unbounded Data Growth with No Retention Strategy**

The `vital_data` table will accumulate time-series data at 5,000 records/second (5,000 devices × 1 record/second) with **no defined retention, archival, or purging strategy**. This creates multiple cascading failures:

**Capacity Impact:**
- **Daily growth**: 432 million records/day (5,000 devices × 86,400 seconds)
- **Monthly growth**: ~13 billion records/month
- **Storage projection**: Assuming 100 bytes per record = 1.3TB/month of raw data growth
- **Index overhead**: B-tree indexes on `timestamp`, `device_id`, `patient_id` will grow proportionally, adding 30-50% storage overhead

**Query Performance Degradation:**
- Historical queries (`GET /api/patients/{patientId}/vitals/history`) will scan increasingly large tables
- Even with proper indexes, range scans over billions of rows will degrade from milliseconds to seconds within weeks
- The 95th percentile API response target of 500ms becomes unachievable after ~30 days of operation

**Operational Impact:**
- Vacuum/analyze operations on multi-billion row tables will take hours, blocking concurrent writes
- Backup windows will expand from minutes to hours
- Database maintenance becomes a multi-day operation requiring downtime

**Missing Design Elements:**
- No retention policy definition (e.g., "keep raw data for 90 days, hourly aggregates for 1 year")
- No archival strategy (e.g., move data older than 90 days to S3 with Parquet compression)
- No purging mechanism (e.g., automated deletion of data beyond retention period)
- No data aggregation strategy (e.g., store 1-second data for 7 days, then downsample to 1-minute averages)

**Recommendation:**
Implement a multi-tier data lifecycle strategy:

1. **Hot tier** (PostgreSQL): Last 7 days of raw 1-second data
2. **Warm tier** (PostgreSQL or TimescaleDB): 8-90 days as 1-minute aggregates
3. **Cold tier** (S3 Parquet + Athena): 91 days-3 years as hourly aggregates
4. **Archival tier** (S3 Glacier): 3+ years for compliance

Use PostgreSQL table partitioning by timestamp (daily partitions) with automated partition dropping after 7 days. Implement background jobs to:
- Aggregate 1-second data to 1-minute summaries (runs hourly)
- Export partitions older than 7 days to S3 Parquet (runs daily)
- Drop exported partitions (runs daily)

This reduces active database size from 13B rows/month to ~350M rows maximum (7 days × 50M rows/day).

---

## Significant Issues (Score 2: Serious Impact on Production Performance)

### 2. I/O & Network Efficiency: Score 2 (POOR)

**Issue A: Synchronous Write-per-Record Pattern**

The design specifies "WebSocket Server receives data and **immediately saves to DB**" with 5,000 writes/second. This creates several bottlenecks:

**Database Connection Pressure:**
- Each write requires a database round-trip (~1-5ms on RDS)
- At 5,000 writes/sec with 5ms latency, you need 25+ concurrent database connections to avoid queuing
- RDS connection limits (typically 100-200 for standard instances) will be exhausted quickly
- No connection pooling configuration is specified

**Write Amplification:**
- PostgreSQL WAL (Write-Ahead Log) overhead: each INSERT generates ~200-300 bytes of WAL traffic
- At 5,000 writes/sec = 1-1.5 MB/sec of WAL traffic, saturating disk I/O bandwidth
- Frequent fsync operations block concurrent transactions

**Impact on Dashboard Queries:**
- Read queries for `/api/patients/{patientId}/vitals/latest` compete with continuous writes for locks and I/O bandwidth
- No read/write separation strategy specified beyond "read replicas" (which won't help for latest data due to replication lag)

**Recommendation:**
Implement **micro-batching** in the WebSocket server:

1. Buffer incoming vital_data records in memory (max 1000 records or 200ms window)
2. Flush batches using `COPY` or multi-row INSERT statements
3. This reduces database round-trips from 5,000/sec to 50/sec (100x reduction)
4. Implement asynchronous write queues (e.g., in-memory ring buffer) so WebSocket handler doesn't block on DB writes

Example configuration:
```yaml
vital_data_buffer:
  max_size: 1000 records
  max_latency: 200ms
  flush_strategy: whichever_comes_first
```

This maintains sub-second latency while reducing database connection usage by 95%.

**Issue B: Dashboard Polling Anti-Pattern**

The design specifies "Dashboard polls REST API every 5 seconds" for real-time updates. For a dashboard showing 20 active patients:

- **Polling frequency**: 20 requests every 5 seconds = 4 requests/sec per user
- **Multi-user impact**: 100 concurrent users = 400 requests/sec to API server
- **Database load**: Each poll queries `vital_data` table for latest records
- **Wasted bandwidth**: 99% of polls return no new data (devices send data every 1 second, polls every 5 seconds)

**Recommendation:**
Use **server-pushed updates** instead of polling:

1. Leverage existing WebSocket infrastructure to push vital_data updates to dashboard clients
2. Implement Pub/Sub pattern: WebSocket server publishes new data to Redis channel, dashboard subscribes to relevant patient channels
3. Fallback to SockJS polling only for incompatible browsers

This eliminates 99% of redundant API requests and reduces database query load by 100x.

### 3. Caching Strategy: Score 2 (POOR)

**Issue: No Caching for High-Frequency Read Paths**

Several API endpoints will be accessed repeatedly with identical parameters but lack caching:

**Missing Cache Targets:**

1. **`GET /api/devices` (device list)**: Accessed by every dashboard refresh, changes infrequently (only when devices are added/removed)
   - **Access pattern**: 100 users × 1 request/5sec = 20 requests/sec
   - **Change frequency**: ~10 times/day
   - **Cache opportunity**: 99.99% hit rate with 5-minute TTL

2. **`GET /api/patients/{patientId}/vitals/latest`**: Repeatedly queried for same patient
   - **Access pattern**: 20 patients × 100 users × 1 request/5sec = 400 requests/sec
   - **Database impact**: Each query scans vital_data with `ORDER BY timestamp DESC LIMIT 1`
   - **Cache opportunity**: 1-second TTL would reduce database load by 80% (5-second polling vs 1-second cache)

3. **Alert rules** (`alert_rules` table): Read on every incoming vital_data record to check thresholds
   - **Access pattern**: 5,000 reads/sec (once per incoming vital record)
   - **Change frequency**: ~5 times/day
   - **Cache opportunity**: In-memory cache with 5-minute TTL, 99.99% hit rate

**Recommendation:**
Implement multi-tier caching strategy:

1. **Application-level cache** (Caffeine/Guava for Spring Boot):
   - Cache `alert_rules` in memory (100% hit rate, invalidate on update)
   - Cache device list with 5-minute TTL

2. **Distributed cache** (Redis/Elasticache):
   - Cache latest vital data per patient with 1-second TTL
   - Cache patient dashboard metadata with 1-minute TTL
   - Use Redis Pub/Sub for cache invalidation on data updates

3. **HTTP caching headers**:
   - Set `Cache-Control: max-age=300` for device lists
   - Use `ETag` for patient vital history queries

Expected impact: 70-80% reduction in database query load, improved API response times from ~100ms to <10ms for cached requests.

### 4. Latency, Throughput Design & Scalability: Score 2 (POOR)

**Issue A: Lack of Asynchronous Processing for Non-Critical Paths**

The design treats all operations synchronously, creating unnecessary latency:

1. **Report Generation** (`POST /api/reports/generate`):
   - Report generation scans large date ranges of vital_data (potentially millions of rows)
   - No indication this is processed asynchronously
   - **Impact**: If synchronous, API request will timeout (typical HTTP timeout: 30-60 seconds)

2. **Alert Notification**:
   - Design mentions "Pub/Sub for notifications" but doesn't specify async processing
   - If alert delivery (Slack, email, SMS) is synchronous, network failures will block vital_data ingestion

**Recommendation:**
- Implement async job queue (AWS SQS or RabbitMQ) for:
  - Report generation: Return job ID immediately, poll for completion
  - Alert notifications: Fire-and-forget message queue
  - Firmware updates: Background job with status tracking

**Issue B: Missing Horizontal Scaling Strategy Details**

The design mentions "ECS auto-scaling at 70% CPU" but lacks critical details:

- **WebSocket server scaling**: WebSocket connections are stateful. How are existing connections handled when scaling down?
- **Session affinity**: No mention of sticky sessions on ALB for WebSocket connections
- **Connection distribution**: How are 5,000 device connections distributed across ECS tasks?
- **Database connection limits**: As ECS tasks scale from 5→20 tasks, database connections scale 4x. Is RDS instance sized accordingly?

**Recommendation:**
1. Configure ALB with sticky sessions (source IP-based) for WebSocket routes
2. Implement graceful shutdown: on scale-down, drain connections over 30-second window
3. Use separate ECS services for WebSocket (stateful, scale based on connection count) vs REST API (stateless, scale on CPU/memory)
4. Calculate maximum database connections: `(max_ecs_tasks × connections_per_task) < rds_max_connections × 0.8`

**Issue C: No Database Index Strategy Specified**

The data model defines tables but doesn't specify indexes for critical query paths:

**Missing Indexes:**
- `vital_data(patient_id, timestamp DESC)` - required for `/vitals/latest` and `/vitals/history` queries
- `vital_data(device_id, timestamp DESC)` - required for device-specific queries
- `devices(hospital_id, status)` - required for filtered device listings
- `devices(patient_id)` - required for "which device is assigned to patient X" lookups

**Impact**: Without proper indexes, even simple queries will perform full table scans, degrading from <10ms to >1000ms as data grows beyond 10M rows.

**Recommendation:**
Define composite indexes in schema:
```sql
CREATE INDEX idx_vital_patient_time ON vital_data(patient_id, timestamp DESC);
CREATE INDEX idx_vital_device_time ON vital_data(device_id, timestamp DESC);
CREATE INDEX idx_devices_hospital_status ON devices(hospital_id, status);
CREATE INDEX idx_devices_patient ON devices(patient_id) WHERE patient_id IS NOT NULL;
```

Monitor index usage with `pg_stat_user_indexes` and adjust based on actual query patterns.

---

## Moderate Issues (Score 3: Requires Attention)

### 5. Algorithm & Data Structure Efficiency: Score 3 (ACCEPTABLE)

**Positive Aspects:**
- Use of PostgreSQL BIGSERIAL for `data_id` is appropriate for high-volume inserts
- JSON format for WebSocket messages is reasonable for medical device interoperability
- STOMP protocol choice is standard for publish/subscribe patterns

**Areas for Improvement:**

**Issue: No Aggregation Strategy for Dashboard Queries**

The design stores raw 1-second granularity data but doesn't specify aggregation for dashboard displays. A typical vital signs chart shows 1-hour of data with 1-second granularity = 3,600 data points per metric per patient.

For 20 patients × 5 metrics × 3,600 points = 360,000 data points transferred to browser every dashboard refresh. This creates:
- High bandwidth usage (assuming 20 bytes per point = 7MB per refresh)
- Slow browser rendering (Chart.js rendering 360K points takes >1 second)

**Recommendation:**
Implement server-side downsampling:
- For time ranges >1 hour: downsample to 1-minute averages (60x reduction)
- For time ranges >24 hours: downsample to 5-minute averages (300x reduction)
- Use PostgreSQL window functions or pre-computed aggregation tables

**Issue: Inefficient Alert Rule Evaluation**

The design fetches all `alert_rules` for every incoming vital_data record (5,000 times/sec) and evaluates them in application code. This creates unnecessary database queries and CPU overhead.

**Recommendation:**
- Cache all alert_rules in application memory (typically <1000 rules, <100KB)
- Use hash map lookup by `data_type` for O(1) threshold checking
- Reload cache only on rule updates (event-driven invalidation)

### 6. Memory & Resource Management: Score 3 (ACCEPTABLE)

**Positive Aspects:**
- Docker containerization enables resource limits per service
- ECS Fargate provides memory isolation between tasks
- Automatic rollback on health check failures prevents resource leak accumulation

**Areas for Improvement:**

**Issue: No WebSocket Connection Limits Specified**

The design targets 5,000 concurrent device connections but doesn't specify:
- Maximum connections per ECS task
- Memory allocation per connection
- Backpressure handling when connection limit is reached

At 1KB per WebSocket connection (session data + buffers), 5,000 connections = 5MB baseline memory, but buffering messages can increase this to 50-100MB.

**Recommendation:**
- Set explicit connection limits per ECS task (e.g., 1,000 connections/task)
- Configure task memory limits: `memory = (connections × buffer_size × 2) + heap_size`
- Implement connection rejection with 503 status when capacity is reached
- Add CloudWatch alerts for connection count approaching limits

**Issue: No Database Connection Pool Configuration**

The design mentions "connection pooling" but doesn't specify:
- Pool size (min/max connections)
- Connection timeout settings
- Idle connection eviction policy

**Recommendation:**
Configure HikariCP (Spring Boot default) explicitly:
```yaml
spring.datasource.hikari:
  maximum-pool-size: 20  # Limit per ECS task
  minimum-idle: 5
  connection-timeout: 5000ms  # Fail fast on pool exhaustion
  idle-timeout: 300000ms  # Close idle connections after 5 min
  max-lifetime: 1800000ms  # Recycle connections every 30 min
```

This prevents connection leaks and ensures predictable database load.

---

## NFR & Scalability Checklist Analysis

### Addressed Requirements

✅ **Performance SLA**: Response time target (p95 < 500ms) is defined
✅ **Horizontal Scaling**: ECS auto-scaling policy specified (70% CPU threshold)
✅ **Resource Limits**: Connection timeouts and retry policies mentioned
✅ **Monitoring**: CloudWatch Logs, Slack alerts for critical errors
✅ **Database Scalability**: Read replicas for read/write separation

### Missing or Inadequate Requirements

❌ **Capacity Planning - Data Volume Growth**: No retention/archival strategy (CRITICAL)
❌ **Capacity Planning - User Load**: No analysis of peak concurrent users or growth projections
⚠️ **Performance SLA - Percentile Metrics**: Only p95 specified; p50 and p99 targets missing
⚠️ **Monitoring - Performance Metrics**: No mention of distributed tracing, APM tools, or query performance monitoring
⚠️ **Resource Limits - Rate Limiting**: No API rate limiting strategy specified
⚠️ **Database Scalability - Sharding**: No sharding strategy for multi-tenant isolation (hospital_id partitioning)

---

## Positive Performance Aspects

Despite the critical issues, the design demonstrates some sound performance choices:

1. **Appropriate Database Technology**: PostgreSQL is suitable for time-series workloads with proper partitioning
2. **Load Balancing**: ALB configuration enables horizontal scaling of stateless API servers
3. **Multi-AZ RDS**: Automatic failover prevents availability impact from database failures
4. **Blue/Green Deployment**: Minimizes deployment-related downtime
5. **Separation of Concerns**: WebSocket server separated from REST API server allows independent scaling

---

## Recommended Priority of Implementation

### Phase 1: Critical (Implement Before Launch)
1. **Data lifecycle strategy** with partitioning and archival (Issue #1)
2. **Micro-batching for vital_data writes** (Issue #2A)
3. **Database indexes** for critical query paths (Issue #4C)

### Phase 2: High Priority (Implement Within First Month)
4. **Replace polling with WebSocket push** for dashboard (Issue #2B)
5. **Application-level caching** for alert_rules and device lists (Issue #3)
6. **Async job queue** for reports and alerts (Issue #4A)

### Phase 3: Medium Priority (Optimize After Initial Load Testing)
7. **Server-side downsampling** for dashboard queries (Issue #5)
8. **WebSocket connection limits** and backpressure handling (Issue #6)
9. **Distributed caching** with Redis for latest vital data (Issue #3)
10. **Comprehensive monitoring** with distributed tracing and query performance tracking

---

## Conclusion

This design requires **significant architectural changes** before production deployment. The absence of a data lifecycle strategy (#1) creates an existential risk that will cause system failure within 30-60 days of operation. The synchronous write-per-record pattern (#2A) and lack of caching (#3) will prevent the system from meeting its performance SLAs under normal load.

Implementing the Phase 1 critical recommendations will transform the system from a Score 1-2 (Critical/Poor) to a Score 3-4 (Acceptable/Good) baseline suitable for production use. Phase 2 and 3 optimizations will achieve the target Score 4-5 (Good/Excellent) performance profile capable of scaling to 10,000+ concurrent devices.

**Estimated effort to address critical issues: 3-4 weeks of architectural refactoring.**
