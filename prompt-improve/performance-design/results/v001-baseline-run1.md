# Performance Design Review: スマートビルディング管理システム

## Executive Summary

This performance review evaluates the smart building management system design from an architecture and design perspective. The review identifies **3 critical issues**, **4 significant issues**, and **2 moderate issues** that could severely impact system scalability, latency, and resource utilization under production load.

**Overall Risk Assessment**: HIGH - Multiple critical bottlenecks identified that will prevent the system from meeting stated performance goals (500ms average API response, 100 concurrent users).

---

## Critical Issues

### C1: N+1 Query Problem in Dashboard API (Severity: CRITICAL)

**Location**: Section 5 - `GET /api/dashboard/floor/{floor_id}`

**Issue Description**:
The dashboard API returns all sensors for a floor with their latest values. The current design likely implements this by:
1. Querying all sensors for the floor (1 query)
2. For each sensor, querying the latest value from SensorData table (N queries)

With typical deployments of 20-50 sensors per floor, this results in 21-51 database queries per dashboard request.

**Performance Impact**:
- **Latency**: Each query adds ~10-30ms. With 30 sensors: 300-900ms in database time alone, exceeding the 500ms API target
- **Throughput**: Database connection pool exhaustion under concurrent load (100 users × 30+ queries = 3000+ concurrent queries)
- **Scalability**: Linear degradation with sensor count increase

**Score Impact**: I/O & Network Efficiency = 2/5

**Recommendation**:
```sql
-- Use a window function or lateral join to fetch latest values in a single query
SELECT s.sensor_id, s.sensor_type,
       sd.value as latest_value,
       sd.timestamp as latest_timestamp
FROM sensors s
LEFT JOIN LATERAL (
  SELECT value, timestamp
  FROM sensor_data
  WHERE sensor_id = s.id
  ORDER BY timestamp DESC
  LIMIT 1
) sd ON true
WHERE s.floor_id = :floor_id
```

Alternatively, maintain a `sensor_latest_values` materialized view updated on each sensor data insert.

---

### C2: Unbounded Time-Series Query Without Pagination (Severity: CRITICAL)

**Location**: Section 5 - `GET /api/dashboard/floor/{floor_id}/history?from={start}&to={end}`

**Issue Description**:
The history endpoint accepts arbitrary time ranges without limit or pagination. With 1-minute data intervals:
- 1 day = 1,440 records per sensor
- 30 sensors × 30 days = 1,296,000 records
- No mention of aggregation, downsampling, or pagination

**Performance Impact**:
- **Memory**: Loading millions of rows into memory for Pandas processing will consume 500MB+ per request
- **Latency**: Query execution time scales linearly with time range (30+ seconds for month-long queries)
- **Resource Exhaustion**: Concurrent month-long queries from multiple users will crash the EC2 instance (t3.large = 8GB RAM)

**Score Impact**: Memory & Resource Management = 1/5, Latency & Throughput = 1/5

**Recommendation**:
1. **Implement pagination**: Max 10,000 records per response with cursor-based pagination
2. **Time-based aggregation**: For ranges > 24 hours, auto-aggregate to hourly averages
3. **Pre-computed rollups**: Create daily/hourly aggregation tables populated by Celery tasks
4. **Query timeout**: Set database query timeout to 5 seconds

```python
# Example aggregation logic
if (end - start) > timedelta(days=1):
    # Return hourly aggregates
    interval = '1 hour'
else:
    # Return raw 1-minute data with limit
    limit = 10000
```

---

### C3: Single PostgreSQL Instance with No Partitioning (Severity: CRITICAL)

**Location**: Section 2, Section 4 - SensorData table

**Issue Description**:
The SensorData table will accumulate massive volumes:
- 50 sensors × 60 measurements/hour × 24 hours × 365 days = 26,280,000 records/year
- With 1-year retention: 26M+ rows in a single table
- No table partitioning mentioned
- Queries on `timestamp` and `sensor_id` will become increasingly slow

**Performance Impact**:
- **Query Performance**: Full table scans despite indexes (PostgreSQL index efficiency degrades beyond 10M rows)
- **Insert Performance**: Index maintenance overhead increases with table size
- **Vacuum/Maintenance**: VACUUM operations take hours, causing bloat and performance degradation

**Score Impact**: Scalability = 2/5, I/O Efficiency = 2/5

**Recommendation**:
1. **Implement table partitioning**: Partition SensorData by month using PostgreSQL native partitioning
```sql
CREATE TABLE sensor_data (
  ...
) PARTITION BY RANGE (timestamp);

CREATE TABLE sensor_data_2026_02 PARTITION OF sensor_data
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
```

2. **Automated partition management**: Celery task to create next month's partition and drop old partitions beyond retention period
3. **Partition pruning**: Queries with time ranges will only scan relevant partitions (10-100x speedup)

---

## Significant Issues

### S1: No Caching Strategy for Dashboard Data (Severity: SIGNIFICANT)

**Location**: Section 3, Section 5 - Dashboard API

**Issue Description**:
The dashboard displays real-time sensor data updated every minute, yet the design shows no caching layer. Redis is only used for Celery brokering and session management. Every dashboard request hits PostgreSQL directly.

**Performance Impact**:
- **Database Load**: 100 concurrent users refreshing dashboards every 10 seconds = 10 queries/second baseline load
- **Unnecessary Computation**: Latest sensor values are recomputed on every request despite changing only every minute
- **Latency**: Database round-trip adds 20-50ms even for simple queries

**Score Impact**: Caching Strategy = 1/5

**Recommendation**:
1. **Cache latest sensor values in Redis** with 60-second TTL:
```python
# On sensor data insert
redis.setex(f"sensor:latest:{sensor_id}", 60, json.dumps({
    "value": value,
    "timestamp": timestamp
}))

# Dashboard API
cached = redis.mget([f"sensor:latest:{sid}" for sid in sensor_ids])
```

2. **Cache floor-level aggregates** (average temperature, total occupancy) with 60-second TTL
3. **WebSocket push updates**: For truly real-time dashboards, push updates to connected clients instead of polling

Expected improvement: 80% reduction in database queries, dashboard latency reduced from 200ms to 10-20ms.

---

### S2: Synchronous Report Generation Blocking User Experience (Severity: SIGNIFICANT)

**Location**: Section 3, Section 5 - Report generation

**Issue Description**:
While report generation is delegated to Celery (async), the design doesn't specify:
- Whether users must poll `GET /api/reports/{report_id}` for status
- No WebSocket or push notification when reports complete
- Report generation involves heavy Pandas aggregation over millions of rows without optimization hints

**Performance Impact**:
- **User Experience**: Users must manually refresh status page or implement client-side polling
- **Computation Time**: Monthly reports aggregating 1M+ rows with Pandas can take 30-60 seconds
- **Resource Spikes**: Multiple concurrent report requests can saturate CPU

**Score Impact**: Latency & Throughput = 2/5

**Recommendation**:
1. **Pre-aggregate data**: Create daily summary tables populated by nightly Celery tasks
```sql
CREATE TABLE daily_energy_summary (
  date DATE,
  floor_id UUID,
  total_kwh FLOAT,
  avg_temperature FLOAT,
  ...
);
```

2. **Incremental aggregation**: Only process new data since last report
3. **Report caching**: Cache generated PDFs for 24 hours for identical report parameters
4. **WebSocket notifications**: Push completion events to connected clients
5. **Query optimization**: Use database-native aggregation instead of Pandas where possible

```python
# Instead of: df = pd.read_sql(query); df.groupby(...).agg(...)
# Use SQL aggregation:
SELECT date_trunc('day', timestamp) as day,
       avg(value) as avg_value,
       sum(energy_kwh) as total_energy
FROM sensor_data
WHERE timestamp BETWEEN :start AND :end
GROUP BY date_trunc('day', timestamp)
```

---

### S3: Missing Index Strategy for Time-Series Queries (Severity: SIGNIFICANT)

**Location**: Section 4 - SensorData table

**Issue Description**:
The design specifies table schemas but doesn't define indexes. Time-series queries will filter by:
- `sensor_id` + `timestamp` (for history queries)
- `timestamp` + `sensor_id` (for latest value queries)

Without proper indexes, queries will perform sequential scans.

**Performance Impact**:
- **Query Latency**: Full table scans on 26M row table = 5-10 second queries
- **Index Bloat**: Wrong index order can prevent index-only scans

**Score Impact**: Algorithm & Data Structure Efficiency = 3/5

**Recommendation**:
```sql
-- For latest value queries (ORDER BY timestamp DESC LIMIT 1)
CREATE INDEX idx_sensor_data_latest
ON sensor_data (sensor_id, timestamp DESC);

-- For time-range queries
CREATE INDEX idx_sensor_data_range
ON sensor_data (timestamp, sensor_id)
WHERE timestamp > NOW() - INTERVAL '30 days';  -- Partial index for recent data

-- Consider BRIN index for timestamp on partitioned tables
CREATE INDEX idx_sensor_data_timestamp_brin
ON sensor_data USING BRIN (timestamp);
```

---

### S4: No Connection Pool Sizing or Timeout Configuration (Severity: SIGNIFICANT)

**Location**: Section 2, Section 3 - PostgreSQL configuration

**Issue Description**:
The design mentions PostgreSQL but doesn't specify:
- Connection pool size
- Connection timeout settings
- Statement timeout limits
- Max query execution time

With 100 concurrent users and potential N+1 queries, connection exhaustion is guaranteed.

**Performance Impact**:
- **Connection Exhaustion**: Default PostgreSQL max_connections (100) will be exceeded
- **Resource Leaks**: Long-running queries hold connections indefinitely
- **Cascading Failures**: New requests fail with "too many connections" errors

**Score Impact**: Memory & Resource Management = 2/5

**Recommendation**:
```python
# SQLAlchemy engine configuration
engine = create_engine(
    database_url,
    pool_size=20,              # Base pool size
    max_overflow=10,           # Burst capacity
    pool_timeout=30,           # Connection wait timeout
    pool_recycle=3600,         # Recycle connections every hour
    pool_pre_ping=True,        # Verify connections before use
    connect_args={
        "options": "-c statement_timeout=10000"  # 10 second query timeout
    }
)
```

PostgreSQL configuration:
```
max_connections = 200
shared_buffers = 2GB  # 25% of RAM for t3.large
effective_cache_size = 6GB
work_mem = 16MB
maintenance_work_mem = 512MB
```

---

## Moderate Issues

### M1: No Rate Limiting on Data Ingestion Endpoint (Severity: MODERATE)

**Location**: Section 5 - `POST /api/sensors/data`

**Issue Description**:
IoT gateways send data every minute, but the API has no rate limiting or request throttling. A malicious or misconfigured gateway could flood the system.

**Performance Impact**:
- **DoS Risk**: Unlimited request rate can saturate API server and database
- **Resource Exhaustion**: Burst traffic spikes consume all available connections

**Score Impact**: Latency & Throughput = 2/5

**Recommendation**:
1. **Implement rate limiting**: 120 requests/minute per sensor (2x normal rate for buffer)
```python
from slowapi import Limiter
limiter = Limiter(key_func=lambda: request.json["sensor_id"])

@app.post("/api/sensors/data")
@limiter.limit("120/minute")
async def ingest_sensor_data(data: SensorData):
    ...
```

2. **Batch insertion**: Accept multiple sensor readings per request to reduce HTTP overhead
3. **Async insertion**: Use background tasks for database writes to return response immediately

---

### M2: No Asynchronous Processing for Anomaly Detection (Severity: MODERATE)

**Location**: Section 3 - Data Collection API, "異常検知ロジックの実行"

**Issue Description**:
Anomaly detection runs synchronously during sensor data ingestion. As detection logic complexity increases (statistical models, ML inference), this will block the insertion API.

**Performance Impact**:
- **Latency**: Anomaly detection adds 50-200ms to every sensor data POST request
- **Scalability**: Cannot scale detection logic independently from ingestion

**Score Impact**: Latency & Throughput = 3/5

**Recommendation**:
1. **Decouple detection**: Insert data first, trigger async Celery task for anomaly detection
```python
@app.post("/api/sensors/data")
async def ingest_sensor_data(data: SensorData):
    await db.insert(data)  # Fast path
    detect_anomaly.delay(data.sensor_id, data.timestamp)  # Async
    return {"status": "success"}

@celery.task
def detect_anomaly(sensor_id, timestamp):
    # Run complex detection logic
    ...
```

2. **Batch anomaly detection**: Run detection on 5-minute windows instead of per-record
3. **Alert aggregation**: Prevent alert storms by rate-limiting notifications per sensor

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| **Algorithm & Data Structure Efficiency** | 3/5 | No major algorithmic issues, but missing critical indexes. Table structure is reasonable but lacks partitioning strategy. |
| **I/O & Network Efficiency** | 2/5 | Critical N+1 query problem in dashboard API. No batch optimization. Unbounded time-series queries will cause massive data transfer. |
| **Caching Strategy** | 1/5 | No application-level caching despite Redis availability. Every request hits database unnecessarily. |
| **Memory & Resource Management** | 2/5 | No connection pool configuration. Unbounded query result sets can exhaust memory. No resource limits on report generation. |
| **Latency, Throughput & Scalability** | 2/5 | Multiple bottlenecks prevent meeting 500ms latency target. Single-instance vertical scaling only. No horizontal scale strategy. Database will hit limits at 50M+ rows. |

**Overall Performance Score: 2.0/5.0**

---

## Positive Aspects

1. **Async Task Architecture**: Using Celery for report generation demonstrates understanding of async patterns
2. **Appropriate Tech Stack**: FastAPI, PostgreSQL, Redis are solid choices for this workload
3. **Clear Data Model**: Well-defined schema with proper foreign keys and constraints
4. **Structured Logging**: JSON logging with request IDs will aid performance debugging

---

## Summary of Recommendations (Prioritized)

### Immediate (Pre-Launch):
1. Fix N+1 query in dashboard API (C1) - **Critical blocker**
2. Implement time-series pagination and aggregation (C2) - **Critical blocker**
3. Add SensorData table partitioning (C3) - **Critical blocker**
4. Implement dashboard caching with Redis (S1) - **High impact, low effort**
5. Configure connection pooling and timeouts (S4) - **Prevents production failures**

### Short-Term (First Month):
6. Create indexes on SensorData (S3)
7. Pre-aggregate data for report generation (S2)
8. Add rate limiting to ingestion API (M1)
9. Decouple anomaly detection to async tasks (M2)

### Medium-Term (3-6 Months):
10. Implement WebSocket real-time updates
11. Add read replicas for analytics queries
12. Evaluate time-series database (TimescaleDB extension) for SensorData table
13. Implement horizontal scaling with load balancer and multiple app instances

---

## Conclusion

The current design will **not meet stated performance goals** (500ms API latency, 100 concurrent users) due to critical architectural issues. The three critical issues (N+1 queries, unbounded time-series queries, lack of partitioning) must be resolved before production deployment. With the recommended changes, the system can achieve target performance and scale to 500+ sensors and 500+ concurrent users.
