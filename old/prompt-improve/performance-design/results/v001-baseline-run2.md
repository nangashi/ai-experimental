# Performance Review: Smart Building Management System

## Overall Assessment

This design document presents a smart building management system with several critical performance bottlenecks that could severely limit scalability and responsiveness. The system collects sensor data at 1-minute intervals from multiple floors and provides real-time dashboard functionality, but the architecture shows fundamental inefficiencies in data access patterns, lack of caching strategy, and insufficient scalability planning.

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 2/5 | No indexing strategy specified for time-series queries; missing optimization for high-cardinality sensor data lookups |
| I/O & Network Efficiency | 2/5 | Critical N+1 query risks in dashboard API; individual sensor data inserts likely causing excessive write overhead |
| Caching Strategy | 1/5 | No caching layer defined despite "real-time dashboard" requirements and frequent read patterns |
| Memory & Resource Management | 3/5 | Connection pooling not mentioned; Celery worker resource limits undefined; potential memory issues with Pandas aggregations |
| Latency, Throughput Design & Scalability | 2/5 | Vertical-scaling-only approach unsuitable for IoT workload; synchronous sensor data writes; no sharding or partitioning strategy |

**Overall Score: 2.0/5** - Significant performance issues requiring immediate architectural revision.

---

## Critical Issues

### 1. **No Time-Series Database Indexing Strategy**

**Issue**: SensorData table lacks explicit index design for the primary query pattern (time-range queries grouped by sensor_id). With 1-minute data collection intervals, this table will accumulate approximately 525,600 rows per sensor per year. For a building with 100 sensors, that's 52.5M rows annually.

**Impact**:
- Dashboard queries like `GET /api/dashboard/floor/{floor_id}/history?from={start}&to={end}` will perform full table scans or inefficient index lookups
- Query latency will degrade exponentially as data accumulates (likely exceeding the 500ms target within 3-6 months)
- The 2-second dashboard load time target becomes unattainable

**Recommendation**:
```sql
-- Essential composite index for time-series queries
CREATE INDEX idx_sensor_data_sensor_timestamp
ON sensor_data (sensor_id, timestamp DESC);

-- Consider table partitioning by timestamp for long-term scalability
CREATE TABLE sensor_data (
  ...
) PARTITION BY RANGE (timestamp);
```

**References**: Section 4 (SensorData table), Section 5 (Dashboard API endpoints), Section 7 (500ms API response target)

---

### 2. **N+1 Query Pattern in Dashboard API**

**Issue**: The dashboard endpoint `GET /api/dashboard/floor/{floor_id}` returns "latest_value" and "latest_timestamp" for each sensor. The natural implementation would be:
1. Query all sensors for the floor
2. For each sensor, query the latest SensorData row

This is a classic N+1 problem. For a floor with 20 sensors, this becomes 21 queries.

**Impact**:
- Multiplies database round-trips by sensor count
- Dashboard load time scales linearly with sensor density (violates 2-second load target)
- Database connection pool exhaustion under concurrent dashboard access

**Recommendation**:
```sql
-- Single optimized query using DISTINCT ON
SELECT DISTINCT ON (s.id)
  s.id, s.sensor_type, sd.value, sd.timestamp
FROM sensors s
LEFT JOIN sensor_data sd ON s.id = sd.sensor_id
WHERE s.floor_id = ?
ORDER BY s.id, sd.timestamp DESC;

-- Or use window functions
SELECT s.*, latest.value, latest.timestamp
FROM sensors s
JOIN LATERAL (
  SELECT value, timestamp
  FROM sensor_data
  WHERE sensor_id = s.id
  ORDER BY timestamp DESC
  LIMIT 1
) latest ON true
WHERE s.floor_id = ?;
```

**References**: Section 5 (GET /api/dashboard/floor/{floor_id} response structure)

---

### 3. **No Caching Layer Despite Real-Time Requirements**

**Issue**: The system claims "real-time dashboard" functionality but has no caching strategy. Redis is listed only for Celery broker and session management. Dashboard data is read from PostgreSQL on every request, despite sensor data only updating every 1 minute.

**Impact**:
- Repeated expensive queries for data that changes only once per minute
- Database becomes bottleneck for read-heavy workload (dashboards are viewed more frequently than data updates)
- Cannot achieve "real-time" responsiveness under concurrent user load

**Recommendation**:
1. **Application-level caching** for dashboard endpoints:
   ```python
   # Cache latest sensor values with 60-second TTL
   @cache(key="floor:{floor_id}:latest", ttl=60)
   async def get_floor_dashboard(floor_id: UUID):
       ...
   ```

2. **Materialized view** for latest sensor states:
   ```sql
   CREATE MATERIALIZED VIEW latest_sensor_values AS
   SELECT DISTINCT ON (sensor_id)
     sensor_id, value, timestamp
   FROM sensor_data
   ORDER BY sensor_id, timestamp DESC;

   -- Refresh via trigger or periodic job
   REFRESH MATERIALIZED VIEW CONCURRENTLY latest_sensor_values;
   ```

3. **Cache invalidation** on sensor data POST to ensure consistency

**References**: Section 3 (Redis usage listed as Celery broker only), Section 1 ("real-time dashboard"), Section 7 (2-second load time target)

---

### 4. **Inefficient Single-Row Sensor Data Inserts**

**Issue**: The `POST /api/sensors/data` endpoint accepts data from one sensor at a time, but the description states sensors collect data at 1-minute intervals. For 100 sensors, this means 100 separate HTTP requests and 100 separate INSERT statements per minute.

**Impact**:
- HTTP overhead multiplied by sensor count
- Database write performance degradation (cannot leverage batch insert optimizations)
- Increased transaction overhead and WAL (Write-Ahead Log) pressure in PostgreSQL
- IoT gateway network efficiency poor

**Recommendation**:
1. **Batch insert API**:
   ```json
   POST /api/sensors/data/batch
   {
     "readings": [
       {"sensor_id": "...", "timestamp": "...", "data": {...}},
       {"sensor_id": "...", "timestamp": "...", "data": {...}},
       ...
     ]
   }
   ```

2. **Bulk INSERT implementation**:
   ```python
   # Use executemany or COPY protocol
   await conn.executemany(
       "INSERT INTO sensor_data (sensor_id, timestamp, value, unit) VALUES ($1, $2, $3, $4)",
       batch_values
   )
   ```

3. **Consider async buffering** if IoT gateway cannot batch (trade-off: slight latency for write efficiency)

**References**: Section 3 (data flow: "センサーデータ → IoTゲートウェイ → POST /api/sensors/data"), Section 1 (1-minute data collection interval)

---

### 5. **Single EC2 Instance Creates Single Point of Performance Failure**

**Issue**: Architecture specifies `EC2 (t3.large x1)` as the sole compute resource with a "vertical scaling" strategy. T3 instances are burstable and designed for moderate workloads, not sustained high I/O operations typical of IoT data collection.

**Impact**:
- CPU credit exhaustion under sustained load (T3 burst model penalty)
- No redundancy for compute-intensive tasks (PDF report generation via Pandas will block API responsiveness)
- Vertical scaling requires downtime and has hard limits (cannot scale beyond largest instance size)
- Single instance cannot achieve 99.9% availability target (requires multi-AZ deployment)

**Recommendation**:
1. **Immediate**: Switch to compute-optimized non-burstable instances (c5/c6i family) for predictable performance
2. **Short-term**: Separate workloads:
   - API servers (stateless, horizontally scalable behind ALB)
   - Celery workers (dedicated instances for report generation)
   - Database (managed RDS Multi-AZ for reliability)
3. **Long-term**: Design for horizontal scalability:
   - Stateless API design (already using JWT, good foundation)
   - Read replicas for dashboard queries
   - Time-series database consideration (e.g., TimescaleDB, InfluxDB) for sensor data

**References**: Section 2 (EC2 t3.large x1), Section 7 (99.9% availability target, vertical scaling policy)

---

## Significant Issues

### 6. **Lack of Database Connection Pooling Configuration**

**Issue**: No mention of connection pool sizing, despite FastAPI's async nature requiring careful connection management. Default pool sizes are often insufficient for concurrent API requests.

**Impact**:
- Connection exhaustion under load (100 concurrent users × multiple queries per request)
- Increased latency due to connection acquisition waits
- Potential for cascading failures

**Recommendation**:
```python
# Example with asyncpg
pool = await asyncpg.create_pool(
    dsn=DATABASE_URL,
    min_size=10,
    max_size=50,  # Tune based on load testing
    command_timeout=60
)
```

Monitor with metrics: `pool_connections_active`, `pool_connections_idle`, `connection_acquisition_time`.

**References**: Section 2 (PostgreSQL database), Section 7 (100 concurrent users)

---

### 7. **Unbounded Pandas Aggregation in Report Generation**

**Issue**: Celery tasks use Pandas for "data aggregation and analysis" but no mention of memory limits or data chunking strategies. Monthly reports querying millions of sensor readings could cause OOM errors.

**Impact**:
- Celery worker crashes during report generation
- Memory exhaustion affecting other services on shared instance
- Unpredictable report generation times

**Recommendation**:
1. **Stream processing** instead of loading full dataset:
   ```python
   for chunk in pd.read_sql(query, conn, chunksize=10000):
       process_chunk(chunk)
   ```

2. **Database-side aggregation** for simple metrics:
   ```sql
   SELECT
     DATE_TRUNC('hour', timestamp) as hour,
     sensor_id,
     AVG(value) as avg_value
   FROM sensor_data
   WHERE timestamp BETWEEN ? AND ?
   GROUP BY hour, sensor_id;
   ```

3. **Set memory limits** on Celery workers and monitor usage

**References**: Section 2 (Pandas for data aggregation), Section 3 (report generation Celery task)

---

### 8. **No Asynchronous Processing for Sensor Data Writes**

**Issue**: Data collection API appears synchronous. Each POST request waits for database write completion before responding. This couples IoT gateway latency to database write performance.

**Impact**:
- Increased gateway timeout risk during database slowdowns
- Backpressure on sensor data collection
- Reduced overall system throughput

**Recommendation**:
1. **Message queue for sensor data ingestion**:
   - IoT gateway → POST to API → enqueue to Redis/RabbitMQ → immediate 202 Accepted response
   - Background workers batch-process queue → bulk INSERT to database
2. **Trade-off**: Slight delay in data availability (acceptable for 1-minute refresh intervals)
3. **Benefits**: Decouples ingestion from storage, enables batching, improves fault tolerance

**References**: Section 3 (data collection flow shows synchronous PostgreSQL save)

---

## Moderate Issues

### 9. **Missing Index on Sensor.floor_id**

**Issue**: Dashboard queries by floor_id likely require joining or filtering sensors by floor, but no foreign key index is explicitly mentioned.

**Impact**: Slower JOIN operations in dashboard queries

**Recommendation**:
```sql
CREATE INDEX idx_sensors_floor_id ON sensors(floor_id);
```

**References**: Section 4 (Sensor table with floor_id FK)

---

### 10. **JSONB Parameter Column in ControlHistory Lacks Indexing**

**Issue**: If queries need to filter control history by specific parameters (e.g., "all temperature changes to 25°C"), JSONB queries without GIN index will be slow.

**Impact**: Report generation or audit queries on control history will degrade as data grows

**Recommendation**:
```sql
CREATE INDEX idx_control_history_parameter ON control_history USING GIN (parameter);
```

Only add if queries actually filter on parameter contents; avoid premature indexing.

**References**: Section 4 (ControlHistory table)

---

### 11. **No Rate Limiting on Sensor Data API**

**Issue**: No mention of rate limiting on `POST /api/sensors/data`. Malfunctioning sensor or compromised gateway could flood the system.

**Impact**:
- Database write saturation
- Denial of service for legitimate sensor data
- Increased storage costs

**Recommendation**:
- Implement per-sensor rate limits (e.g., max 2 requests per minute, aligned with 1-minute collection interval)
- Return 429 Too Many Requests for violations
- Alert on rate limit violations (potential sensor malfunction)

**References**: Section 5 (POST /api/sensors/data endpoint)

---

### 12. **Potential Memory Leak from Unclosed Database Cursors**

**Issue**: FastAPI with async database drivers requires careful cursor/connection lifecycle management. No mention of context managers or explicit resource cleanup.

**Impact**: Gradual memory leaks, connection leaks

**Recommendation**:
```python
# Use async context managers
async with pool.acquire() as conn:
    async with conn.transaction():
        await conn.execute(...)
```

Ensure all database operations use proper cleanup patterns.

**References**: Section 2 (FastAPI + PostgreSQL)

---

## Minor Improvements

### 13. **EBS gp3 Volume Performance May Be Underspecified**

**Issue**: EBS gp3 defaults to 3,000 IOPS and 125 MB/s. For a write-heavy IoT workload with 100 sensors writing every minute plus dashboard reads, this may become a bottleneck as data grows.

**Recommendation**:
- Monitor EBS performance metrics: `VolumeReadOps`, `VolumeWriteOps`, `VolumeQueueLength`
- Consider provisioned IOPS (io2) if sustained high throughput is needed
- Alternatively, use RDS instead of self-managed PostgreSQL on EC2 for better I/O optimization

**References**: Section 2 (EBS gp3 500GB)

---

### 14. **No Mention of Database Query Performance Monitoring**

**Issue**: No mention of query performance monitoring tools (e.g., pg_stat_statements, slow query logging).

**Recommendation**: Enable PostgreSQL query logging and monitoring:
```sql
-- Enable slow query logging
ALTER SYSTEM SET log_min_duration_statement = 1000; -- Log queries >1s
ALTER SYSTEM SET pg_stat_statements.track = 'all';
```

Use APM tools (e.g., Datadog, New Relic) to correlate API latency with database queries.

**References**: Section 7 (500ms API response target)

---

### 15. **JWT Token Validation Overhead**

**Issue**: JWT validation on every API request adds computational overhead. With 100 concurrent users and dashboard refresh every few seconds, this is non-trivial.

**Impact**: Minor latency increase per request (typically 1-5ms)

**Recommendation**:
- Cache validated JWT claims in Redis (short TTL matching token structure)
- Use efficient JWT libraries (e.g., python-jose with cryptography backend)

**References**: Section 5 (JWT authentication on all APIs)

---

## Positive Aspects

1. **Asynchronous Task Queue for Reports**: Using Celery for report generation correctly offloads CPU-intensive work from API servers.

2. **Stateless API Design**: JWT-based authentication enables horizontal scaling of API servers without session affinity requirements.

3. **Structured Logging**: JSON-formatted logs with request IDs facilitate performance troubleshooting and tracing.

4. **Appropriate Use of BIGSERIAL**: SensorData and ControlHistory use BIGSERIAL for high-cardinality sequential IDs, suitable for tables expecting millions of rows.

---

## Summary of Critical Actions Required

1. **Add time-series indexes** to SensorData table immediately
2. **Implement caching layer** for dashboard APIs (Redis with 60s TTL)
3. **Refactor dashboard queries** to eliminate N+1 patterns
4. **Change to batch sensor data ingestion** API
5. **Revise infrastructure architecture** away from single T3 instance to horizontally scalable design
6. **Add database connection pooling** configuration
7. **Implement memory-safe Pandas processing** for reports

Without addressing these critical issues, the system will fail to meet its performance targets (500ms API response, 2-second dashboard load) within the first few months of operation as sensor data accumulates.
