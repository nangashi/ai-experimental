# Performance Design Review: Smart Building Management System

## Overall Assessment

This design document presents a smart building management system with several critical performance bottlenecks that will severely impact scalability and user experience. The architecture shows fundamental issues in data access patterns, caching strategy, and resource management that require immediate attention before implementation.

---

## 1. I/O & Network Efficiency: Score 1/5 (Critical)

### Critical Issue 1: N+1 Query Pattern in Dashboard Endpoint

**Location**: Section 5 - API Design, `GET /api/dashboard/floor/{floor_id}`

The design shows that the dashboard retrieves the latest sensor value for each sensor in a floor. With typical commercial building deployments (20-50 sensors per floor), this creates a severe N+1 query problem:

- Initial query fetches all sensors for the floor
- For each sensor, a separate query retrieves `latest_value` and `latest_timestamp` from the SensorData table
- With 30 sensors per floor: 31 database queries per dashboard load
- With 100 concurrent users: 3,100 queries/second for dashboard viewing alone

**Impact Analysis**:
- Expected latency: 300-600ms per dashboard load (10-20ms per query * 30 queries)
- The stated performance goal of "2秒以内" (within 2 seconds) is barely achievable under zero load
- Database connection pool exhaustion at modest traffic levels (100 users exceed typical pool size of 20-50 connections)
- Violates the stated performance target of "全エンドポイント平均500ms以下" (average 500ms for all endpoints)

**Recommendation**:
- Implement a single optimized query using window functions to fetch the latest sensor reading:
  ```sql
  SELECT DISTINCT ON (sensor_id)
    s.sensor_id, s.sensor_type, sd.value as latest_value, sd.timestamp as latest_timestamp
  FROM sensors s
  LEFT JOIN sensor_data sd ON s.id = sd.sensor_id
  WHERE s.floor_id = ?
  ORDER BY sensor_id, timestamp DESC
  ```
- This reduces 31 queries to 1 query, improving latency from 300-600ms to 10-20ms
- Add a composite index on `(sensor_id, timestamp DESC)` in SensorData table for optimal query performance
- Consider implementing a materialized view that updates every 1 minute (matching sensor collection interval)

### Critical Issue 2: Unbounded Time-Series Query

**Location**: Section 5 - `GET /api/dashboard/floor/{floor_id}/history?from={start}&to={end}`

The API design allows arbitrary date ranges without pagination or result size limits. Given the data collection rate of 1 minute intervals:

- 1 sensor, 1 day: 1,440 records
- 30 sensors, 1 month: 1,296,000 records
- A user querying 1 year of data for a full floor could retrieve 15.8 million records

**Impact Analysis**:
- Memory consumption: 15.8M records * ~50 bytes/record = 790 MB for a single request
- Network transfer: Several hundred MB of JSON payload
- Database query time: 10-30 seconds for large scans
- Risk of OOM errors on EC2 t3.large instance (8 GB RAM) with concurrent requests

**Recommendation**:
- Implement mandatory pagination with max limit of 10,000 records per request
- Add data aggregation for time ranges exceeding 7 days (e.g., hourly averages for monthly queries)
- Implement query timeout (5 seconds) and return 408 Request Timeout for oversized queries
- Add query cost estimation and rejection for queries exceeding threshold
- Document recommended query patterns (e.g., "For historical analysis over 1 month, use daily aggregates endpoint")

### Critical Issue 3: Synchronous PDF Report Generation

**Location**: Section 3 - "レポート生成サービス（Celeryタスク）", Section 5 - `POST /api/reports/generate`

While the design mentions Celery for report generation, the data flow (Section 3) shows "PostgreSQL集計 → PDFレポート生成" as part of the Celery task, but the aggregation query complexity is not addressed:

- Monthly reports require scanning all sensor data for 30 days
- For a 10-floor building with 30 sensors/floor: 12.96 million records to aggregate
- The design uses Pandas for aggregation (Section 2), which loads entire datasets into memory

**Impact Analysis**:
- Memory usage: 12.96M records * ~100 bytes/record (DataFrame overhead) = 1.3 GB per report generation
- Processing time: 60-120 seconds for Pandas groupby/aggregate operations
- Concurrent report generation by 3 users can consume 3.9 GB, leaving insufficient memory for API operations on t3.large
- PostgreSQL experiences high load during aggregation scans, impacting API response times

**Recommendation**:
- Pre-aggregate data at database level using time-bucket functions:
  - Create hourly aggregates table with daily background job
  - Create daily aggregates table with monthly background job
- Report generation should query pre-aggregated tables instead of raw sensor data
- Use PostgreSQL's built-in aggregation instead of loading data into Pandas
- Limit concurrent report generation tasks (max 2) using Celery rate limits
- Expected improvement: Report generation time from 60-120s to 2-5s, memory usage from 1.3 GB to <100 MB

---

## 2. Caching Strategy: Score 1/5 (Critical)

### Critical Issue: No Caching Layer for High-Frequency Reads

**Location**: Section 2 - Technical Stack, Section 3 - Architecture Design

The design mentions Redis only for "Celeryブローカー、セッション管理" (Celery broker and session management), with no caching strategy for API responses despite highly cacheable data patterns:

- Sensor configuration (Section 4 - Sensors table): Static data, changes infrequently
- Floor/Building metadata (Section 4 - Floors table): Static data
- Latest sensor readings: 1-minute update cycle, same data served to all users within 1-minute window
- Dashboard displays are read-heavy (estimated 1000:1 read-to-write ratio)

**Impact Analysis**:
- Every dashboard load generates 31 database queries (see N+1 issue)
- With 100 concurrent users refreshing dashboards every 10 seconds: 310 queries/second
- PostgreSQL on single EC2 instance can handle ~1000-2000 queries/second, leaving minimal headroom
- Cannot handle traffic spikes during incidents when all managers open dashboards
- Violates stated performance target of "同時接続ユーザー数: 100ユーザー" (100 concurrent users)

**Recommendation**:
- Implement Redis caching with the following strategy:
  - **Sensor metadata cache**: TTL 1 hour, invalidate on sensor configuration changes
    - Key pattern: `sensor:{sensor_id}`, `sensors:floor:{floor_id}`
    - Expected hit rate: >95%
  - **Latest readings cache**: TTL 60 seconds (matches collection interval)
    - Key pattern: `sensor:latest:{sensor_id}`
    - Update via write-through pattern when new sensor data arrives
    - Expected hit rate: >90%
  - **Floor metadata cache**: TTL 24 hours
    - Key pattern: `floor:{floor_id}`, `building:{building_id}`
    - Expected hit rate: >98%
- Expected improvement:
  - Database query reduction: 90% (from 310 queries/s to 31 queries/s for dashboard traffic)
  - Dashboard load latency: 300-600ms → 20-50ms (Redis response time: 1-2ms per key)
  - Capacity increase: Can support 1000+ concurrent users with current infrastructure

**Positive Aspect**:
- The design already includes Redis infrastructure, making cache integration straightforward
- The 1-minute sensor data collection interval provides a natural cache TTL boundary

---

## 3. Algorithm & Data Structure Efficiency: Score 2/5 (Significant)

### Significant Issue 1: Inefficient Time-Series Data Storage

**Location**: Section 4 - Data Model, SensorData Table

The design uses a generic relational table with BIGSERIAL primary key and individual TIMESTAMP records. With the stated data collection rate (1 minute intervals) and retention policy (1 year):

- 1 sensor, 1 year: 525,600 records
- 300 sensors, 1 year: 157.68 million records
- Table size estimation: 157.68M * ~50 bytes/record ≈ 7.9 GB
- Index size on (sensor_id, timestamp): ~3.2 GB
- Total storage: ~11 GB (within 500GB EBS limit, but inefficient)

**Problems**:
- B-tree index overhead grows with record count (log N lookup time)
- Range scans for time-series queries involve random I/O due to scattered physical storage
- No data compression despite highly compressible time-series data
- Vacuum operations become slower as table grows

**Impact Analysis**:
- Query performance degrades over time as data accumulates
- By year 2, with 315 million records, query times increase by 30-50%
- Index maintenance overhead impacts INSERT performance (sensor data writes)

**Recommendation**:
- Use PostgreSQL TimescaleDB extension or implement table partitioning:
  - **Option A (TimescaleDB - Preferred)**:
    - Convert SensorData to hypertable partitioned by timestamp (monthly chunks)
    - Enable compression (achieves 10-20x compression ratio for time-series data)
    - Expected storage reduction: 11 GB → 600 MB - 1.1 GB
    - Query performance: 40-60% improvement for time-range queries due to chunk exclusion
  - **Option B (Native Partitioning)**:
    - Partition SensorData table by month (LIST partitioning)
    - Create separate indexes per partition
    - Implement automated partition creation/dropping for data retention
- Add composite index on (sensor_id, timestamp DESC, value) to support latest-value queries efficiently

### Significant Issue 2: No Mention of Connection Pooling Configuration

**Location**: Section 2 - Technical Stack (PostgreSQL), Section 3 - Architecture Design

The design does not specify database connection pooling configuration. With the identified N+1 query patterns and 100 concurrent users:

- Potential connection count: 100 users * 1 connection/user = 100 connections (if no pooling)
- PostgreSQL default max_connections = 100, but effective limit is lower (reserve for maintenance)

**Impact Analysis**:
- Risk of "too many connections" errors at stated concurrency target (100 users)
- Connection exhaustion causes cascading failures (all API requests fail)
- No connection reuse increases overhead (connection setup: 10-20ms per connection)

**Recommendation**:
- Configure connection pooling with PgBouncer or SQLAlchemy pool:
  - Pool size: 20-30 connections (sufficient after N+1 fix)
  - Max overflow: 10 connections
  - Pool timeout: 30 seconds
  - Connection lifetime: 1 hour (prevent long-running idle connections)
- Add connection pool monitoring metrics (active connections, wait time)
- Document expected connection count per API endpoint in design

---

## 4. Memory & Resource Management: Score 2/5 (Significant)

### Significant Issue 1: Pandas Usage for Large Dataset Aggregation

**Location**: Section 2 - "Pandas（データ集計・分析）", Section 3 - Report Generation Service

The design specifies Pandas for data aggregation, which requires loading entire datasets into memory. As detailed in the I/O Efficiency section:

- Monthly report: 1.3 GB memory consumption per report generation
- Pandas DataFrame overhead: 2-3x raw data size
- No memory limits specified for Celery workers

**Impact Analysis**:
- On t3.large (8 GB RAM), concurrent operations can cause OOM:
  - 2 report generations: 2.6 GB
  - API operations + PostgreSQL: ~3 GB
  - OS overhead: ~1 GB
  - Remaining: 1.4 GB (insufficient buffer)
- Risk of OOM killer terminating Python processes, requiring restart
- Swap usage degrades performance significantly (EBS swap: 100-200 IOPS limit on gp3)

**Recommendation**:
- Replace Pandas with database-level aggregation (as detailed in I/O Efficiency recommendations)
- If Pandas is still needed for complex transformations:
  - Process data in chunks (e.g., 1 day at a time, aggregate incrementally)
  - Set Celery worker memory limit (celeryd_max_tasks_per_child=10 to restart workers regularly)
  - Add memory monitoring and alerts (>80% usage)
  - Use `dask` instead of Pandas for out-of-core processing if needed

### Significant Issue 2: No Database Connection Release Strategy

**Location**: Section 6 - Implementation Guidelines (no mention of connection lifecycle)

The design does not specify how database connections are managed across request lifecycles, particularly for long-running operations:

- Celery tasks may hold connections for 60-120 seconds during report generation
- No mention of connection timeout or explicit release
- FastAPI dependency injection pattern not specified

**Impact Analysis**:
- Long-running tasks deplete connection pool, starving API requests
- Idle connections consume PostgreSQL backend memory (~10 MB per connection)
- Risk of connection leaks if exceptions occur during request processing

**Recommendation**:
- Implement explicit connection lifecycle management:
  - Use FastAPI's dependency injection with `yield` pattern for automatic cleanup
  - Set statement timeout (30 seconds) and connection timeout (60 seconds) in PostgreSQL
  - Celery tasks should close connections explicitly in `finally` blocks
  - Use separate connection pools for API vs. Celery (prevent task impact on API)
- Add connection leak detection in testing (fail tests if connections not returned to pool)

---

## 5. Latency, Throughput Design & Scalability: Score 2/5 (Significant)

### Significant Issue 1: Single-Instance Vertical Scaling Strategy Inadequate

**Location**: Section 7 - "スケーリング方針: 初期は単一EC2インスタンス、負荷増加時にインスタンスサイズを拡大（垂直スケーリング）"

The design specifies vertical scaling (increasing EC2 instance size) as the scaling strategy. Given the identified performance issues:

- Current bottleneck: Database query count (310 queries/s for 100 users)
- Vertical scaling impact: Increasing CPU/RAM does not reduce query count
- PostgreSQL write throughput limited by single-instance disk I/O (gp3: 16,000 IOPS baseline)
- Sensor data ingestion rate: 300 sensors * 60 writes/hour = 18,000 writes/hour = 5 writes/second (manageable, but no headroom for growth)

**Impact Analysis**:
- Vertical scaling provides 20-30% performance improvement but does not address architectural bottlenecks
- Cost inefficiency: t3.2xlarge (8 vCPU, 32 GB) costs 4x more than t3.large but provides <2x effective performance
- Single point of failure: All operations fail if EC2 instance fails
- Deployment downtime: Vertical scaling requires instance restart (5-10 minutes downtime, violates 99.9% SLA)

**Recommendation**:
- Implement horizontal scaling with load balancing:
  - Add ALB (already in tech stack) with 2-3 EC2 instances for API layer
  - Separate stateless API instances from stateful database layer
  - Implement read replicas for PostgreSQL (offload dashboard queries to replica)
- Implement caching layer (as detailed in Caching Strategy section) to reduce database load before scaling
- Add autoscaling policies based on metrics:
  - Scale out trigger: CPU >70% for 5 minutes OR connection pool >80% utilized
  - Scale in trigger: CPU <30% for 15 minutes
- Expected improvement: Can handle 500-1000 concurrent users with 3 instances after implementing cache

### Significant Issue 2: No Index Optimization for Critical Queries

**Location**: Section 4 - Data Model (no index definitions provided)

The design does not specify indexes beyond primary keys and foreign keys. Critical queries identified:

- Latest sensor value per sensor (ORDER BY timestamp DESC)
- Time-range queries for history endpoint
- Floor-level sensor lookups

**Impact Analysis**:
- Without composite indexes, PostgreSQL performs full table scans or inefficient index scans
- Query time: 100-500ms per query (with 157M records)
- Cannot meet "全エンドポイント平均500ms以下" target without indexes

**Recommendation**:
- Add the following indexes:
  ```sql
  -- For latest value queries (supports N+1 query optimization)
  CREATE INDEX idx_sensor_data_latest
    ON sensor_data (sensor_id, timestamp DESC)
    INCLUDE (value, unit);

  -- For time-range queries
  CREATE INDEX idx_sensor_data_time_range
    ON sensor_data (timestamp, sensor_id);

  -- For floor-based sensor lookup
  CREATE INDEX idx_sensors_floor
    ON sensors (floor_id)
    INCLUDE (sensor_type, status);
  ```
- Monitor index usage with `pg_stat_user_indexes` and remove unused indexes
- Expected improvement: Query time from 100-500ms to 5-20ms

### Moderate Issue: Synchronous Alert Processing

**Location**: Section 3 - "異常検知ロジックの実行" in Data Collection API

The design shows that anomaly detection logic runs synchronously during sensor data ingestion (POST /api/sensors/data). If alert logic involves complex calculations or external API calls (email/SMS notifications):

- Sensor data write latency increases by alert processing time
- IoT gateway may timeout if response exceeds 5-10 seconds
- Alert processing failures block data ingestion

**Impact Analysis**:
- Risk of data loss if IoT gateway retries are not properly implemented
- Limited impact if alert logic is simple (threshold check: <10ms)
- Becomes critical if alert logic evolves to include ML models or external API calls

**Recommendation**:
- Move alert processing to async Celery task:
  - POST /api/sensors/data returns immediately after database write
  - Publish sensor data to Redis pub/sub or message queue
  - Celery worker subscribes and processes alerts asynchronously
- This decouples data ingestion from alert delivery
- Add alert queue monitoring (queue depth, processing lag)

---

## Summary of Findings

### Critical Issues (Must Fix Before Production)
1. **N+1 Query Pattern** - Dashboard endpoint generates 31 queries per load (Section 1)
2. **Unbounded Time-Series Query** - History endpoint allows 15M+ record queries without limits (Section 1)
3. **No Caching Layer** - Missing Redis cache despite read-heavy workload and Redis infrastructure (Section 2)
4. **Inefficient Report Generation** - Pandas loads 1.3 GB into memory per monthly report (Section 1, 4)

### Significant Issues (Address During Implementation)
5. **Inefficient Time-Series Storage** - Should use TimescaleDB or partitioning (Section 3)
6. **No Connection Pooling** - Risk of connection exhaustion at 100 users (Section 3)
7. **Vertical Scaling Inadequacy** - Cannot handle stated 100 concurrent users without cache (Section 5)
8. **Missing Indexes** - Critical queries will take 100-500ms without optimization (Section 5)

### Positive Aspects
- Redis infrastructure already planned (easy cache integration)
- Celery for async processing (good foundation for alert/report decoupling)
- 1-minute sensor interval provides natural cache TTL boundary
- Reasonable data retention policy (1-3 years)

---

## Priority Recommendations

**Before Implementation (Critical Priority)**:
1. Redesign dashboard API query pattern to eliminate N+1 queries (single query with window function)
2. Implement Redis caching layer for sensor metadata and latest readings
3. Add pagination and aggregation to history endpoint
4. Migrate report generation from Pandas to database-level aggregation with pre-aggregated tables

**During Implementation (High Priority)**:
5. Add composite indexes for critical query patterns
6. Configure connection pooling (PgBouncer or SQLAlchemy pool: 20-30 connections)
7. Implement TimescaleDB or table partitioning for SensorData
8. Set up horizontal scaling with ALB + 2-3 EC2 instances + PostgreSQL read replica

Addressing these issues will enable the system to meet stated performance targets (500ms avg response, 100 concurrent users, 2s dashboard load) and provide a foundation for future scaling beyond initial deployment.
