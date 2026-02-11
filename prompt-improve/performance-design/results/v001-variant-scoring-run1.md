# Performance Design Review: Smart Building Management System

## Executive Summary

This performance review evaluates the architecture-level design of a smart building management system. The evaluation identifies critical scalability limitations, significant I/O inefficiencies, and missing performance infrastructure that will severely impact system usability under production workloads.

**Overall Risk Level**: High - Multiple critical issues that will prevent the system from meeting its performance objectives

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 3/5 | Basic data structures chosen but no analysis of query patterns or indexing strategy |
| I/O & Network Efficiency | 1/5 | Critical N+1 query problems in dashboard API; no batching or optimization strategies |
| Caching Strategy | 1/5 | No caching mechanism defined despite read-heavy workload patterns |
| Memory & Resource Management | 2/5 | Missing connection pooling configuration; unbounded data loading risks |
| Latency, Throughput Design & Scalability | 1/5 | Single-instance architecture with no horizontal scaling path; fundamentally unscalable |

**Total Score**: 8/25 (32%)

---

## Critical Issues (Priority 1)

### 1. Fundamentally Unscalable Single-Instance Architecture
**Severity**: Critical
**Category**: Latency, Throughput Design & Scalability
**Score Impact**: 1/5

**Issue Description**:
The design specifies a single EC2 instance (t3.large x1) with vertical scaling as the only growth path (line 33, 224). This creates an absolute ceiling on system capacity and introduces multiple single points of failure.

**Performance Impact**:
- Maximum capacity limited to single-instance CPU/memory bounds
- No ability to distribute load during peak usage (e.g., morning dashboard checks by 100+ users)
- Database becomes a bottleneck as all queries funnel through one connection pool
- Sensor data ingestion rate capped at ~1000 sensors (1/minute) before single-instance processing saturates
- Vertical scaling requires downtime and has hard limits (largest instance type)

**Actionable Recommendations**:
1. **Immediate**: Design for horizontal scalability from the start:
   - Use AWS Auto Scaling Group with minimum 2 instances for redundancy
   - Implement stateless API design (already using JWT, good foundation)
   - Use ALB session affinity if needed, but avoid server-side session state

2. **Database scaling strategy**:
   - Implement read replicas for dashboard queries (90% read workload)
   - Consider time-series database (TimescaleDB on PostgreSQL or dedicated like InfluxDB) for sensor data
   - Separate OLTP (real-time data ingestion) from OLAP (reporting/analytics) workloads

3. **Define horizontal scaling triggers**:
   - Scale out when CPU > 70% for 5 minutes
   - Scale out when request latency p95 > 1000ms
   - Scale out when active connections > 80% of pool size

**References**: Lines 33 (infrastructure), 224 (scaling policy), 209-212 (performance goals)

---

### 2. N+1 Query Problem in Dashboard API
**Severity**: Critical
**Category**: I/O & Network Efficiency
**Score Impact**: 1/5

**Issue Description**:
The dashboard API endpoint `GET /api/dashboard/floor/{floor_id}` (lines 123, 156-171) will execute one query to get sensors, then N additional queries to get the latest value for each sensor. For a typical floor with 20-30 sensors, this results in 21-31 database round trips.

**Performance Impact**:
- With 30 sensors per floor and 10ms per query: 300ms+ just for database I/O
- Violates the 500ms average API response target (line 210)
- Scales linearly with sensor count (50 sensors = 500ms+ database time alone)
- Each dashboard page load from 100 concurrent users generates 2000-3000 queries/second
- Database connection pool exhaustion under moderate load

**Actionable Recommendations**:
1. **Implement single JOIN query**:
```sql
SELECT s.sensor_id, s.sensor_type,
       FIRST_VALUE(sd.value) OVER (PARTITION BY s.sensor_id ORDER BY sd.timestamp DESC) as latest_value,
       FIRST_VALUE(sd.timestamp) OVER (PARTITION BY s.sensor_id ORDER BY sd.timestamp DESC) as latest_timestamp
FROM sensors s
LEFT JOIN sensor_data sd ON s.sensor_id = sd.sensor_id
WHERE s.floor_id = :floor_id
  AND sd.timestamp > NOW() - INTERVAL '5 minutes'
```

2. **Alternative: Maintain materialized view**:
   - Create `sensor_latest_readings` materialized view
   - Refresh on sensor data insert (trigger or application layer)
   - Query complexity: O(1) vs O(N) queries

3. **Add database index**:
   - `CREATE INDEX idx_sensor_data_latest ON sensor_data (sensor_id, timestamp DESC)`
   - Supports efficient latest-value retrieval

**References**: Lines 123-124 (API endpoint), 156-171 (response format), 210 (performance target)

---

### 3. No Caching Strategy for Read-Heavy Workload
**Severity**: Critical
**Category**: Caching Strategy
**Score Impact**: 1/5

**Issue Description**:
The system has no defined caching mechanism despite being read-heavy (dashboard refreshes every 30-60 seconds, hundreds of reads per write). Redis is listed for Celery and sessions (line 40) but not utilized for data caching.

**Performance Impact**:
- Every dashboard request hits PostgreSQL (30+ queries with N+1 problem)
- 100 concurrent users refreshing every 30s = 6000 queries/minute to database
- Database becomes bottleneck even with query optimization
- Latest sensor readings change only every 1 minute (line 9) but queried every second
- Unnecessary database load prevents scaling to stated 100 concurrent users

**Actionable Recommendations**:
1. **Implement tiered caching strategy**:
   - **L1 (Redis)**: Cache latest sensor readings per floor
     - Key pattern: `floor:{floor_id}:sensors:latest`
     - TTL: 60 seconds (matches sensor update interval)
     - Invalidate on sensor data POST

   - **L2 (Application memory)**: Cache sensor metadata (rarely changes)
     - Sensor types, locations, floor mappings
     - TTL: 5 minutes
     - Invalidate on sensor configuration change

2. **Cache warming strategy**:
   - Pre-populate cache for all active floors on application startup
   - Background job refreshes cache every 60 seconds
   - Ensures cache hit ratio > 95%

3. **Historical data caching**:
   - Cache time-series query results (1-hour, 1-day aggregations)
   - Key pattern: `floor:{floor_id}:history:{timerange}:{granularity}`
   - TTL: 15 minutes for recent data, 24 hours for historical

**References**: Line 40 (Redis available), line 9 (1-minute sensor interval), lines 123-124 (dashboard API)

---

## Significant Issues (Priority 2)

### 4. Missing Database Connection Pooling Configuration
**Severity**: Significant
**Category**: Memory & Resource Management
**Score Impact**: 2/5

**Issue Description**:
The design mentions PostgreSQL but provides no connection pooling configuration, pool size limits, or connection lifecycle management strategy.

**Performance Impact**:
- Default connection limits may be too small (PostgreSQL default: 100 connections)
- With 100 concurrent users + Celery workers + background jobs: 150-200 connections needed
- Connection exhaustion causes cascading failures (users see 500 errors)
- Each connection consumes ~10MB PostgreSQL memory (200 connections = 2GB overhead)
- No connection timeout strategy leads to resource leaks

**Actionable Recommendations**:
1. **Configure explicit connection pooling**:
   - FastAPI application pool: 20-30 connections (per instance)
   - Celery worker pool: 5-10 connections (per worker)
   - Set `max_overflow=10` for burst capacity
   - Set `pool_timeout=30s` to fail fast vs. waiting indefinitely

2. **Use PgBouncer** for connection pooling:
   - Transaction-mode pooling for API requests (1000+ logical connections → 100 physical)
   - Reduces PostgreSQL connection overhead
   - Better connection reuse across application restarts

3. **Monitor connection metrics**:
   - Track active connections, idle connections, waiting connections
   - Alert when utilization > 80%
   - Include in deployment readiness checklist

**References**: Line 29 (PostgreSQL mentioned), line 212 (100 concurrent users target)

---

### 5. Unbounded Data Loading in Report Generation
**Severity**: Significant
**Category**: Memory & Resource Management
**Score Impact**: 2/5

**Issue Description**:
Report generation service (lines 64-66) loads sensor data for aggregation using Pandas (line 38). No pagination, streaming, or memory limits are specified. A monthly report for 500 sensors at 1-minute intervals = 21.6M data points.

**Performance Impact**:
- Monthly report: 21.6M rows × 40 bytes/row = ~860MB in memory
- Annual report: 10+ GB memory requirement
- Single Celery worker processing large report consumes all available memory
- Other tasks queue up, delaying time-sensitive operations (alerts, real-time control)
- Pandas DataFrame operations on 10M+ rows take minutes, not seconds
- Risk of OOM kills on t3.large (8GB memory)

**Actionable Recommendations**:
1. **Implement chunked processing**:
```python
def generate_monthly_report(year, month):
    chunk_size = 100000  # 100k rows at a time
    aggregates = []

    for chunk in pd.read_sql_query(query, engine, chunksize=chunk_size):
        daily_agg = chunk.groupby('date').agg({'value': ['mean', 'max', 'min']})
        aggregates.append(daily_agg)

    final_report = pd.concat(aggregates).groupby('date').mean()
```

2. **Use database-side aggregation**:
   - PostgreSQL can aggregate 21M rows faster than Python+Pandas
   - Push computation to database, fetch only aggregated results (30 daily summaries vs 21M rows)
   - Example: `SELECT DATE(timestamp), AVG(value), MAX(value) FROM sensor_data WHERE ... GROUP BY DATE(timestamp)`

3. **Implement report size limits**:
   - Warn if report exceeds 50MB estimated memory
   - Require admin approval for reports > 100MB
   - Archive old sensor data to cold storage (S3) after 90 days

**References**: Lines 64-66 (report service), line 38 (Pandas usage), line 225 (1-year data retention)

---

### 6. No Index Strategy for Time-Series Queries
**Severity**: Significant
**Category**: Algorithm & Data Structure Efficiency
**Score Impact**: 3/5

**Issue Description**:
The SensorData table (lines 88-96) has no index definitions for the primary query patterns: timestamp range queries and sensor_id lookups. Time-series queries without proper indexes perform full table scans.

**Performance Impact**:
- Historical data query (line 124) scans entire SensorData table (millions of rows)
- Query time grows linearly with data volume: 1-month data (21M rows) = 10-30 second scans
- Violates 2-second dashboard initial display target (line 211)
- Blocks concurrent queries (table-level locks during scans)
- Makes pagination inefficient (OFFSET requires scanning skipped rows)

**Actionable Recommendations**:
1. **Create composite indexes** for time-series access patterns:
```sql
-- Primary time-series index (most selective first)
CREATE INDEX idx_sensor_data_time_series
ON sensor_data (sensor_id, timestamp DESC);

-- Floor-level aggregation queries
CREATE INDEX idx_sensor_data_floor_time
ON sensor_data (sensor_id, timestamp DESC)
INCLUDE (value);
```

2. **Consider partitioning strategy** for large tables:
   - Partition SensorData by month (range partitioning on timestamp)
   - Query planner automatically prunes irrelevant partitions
   - Monthly reports query only 1 partition vs full table
   - Enables fast DROP of old partitions vs slow DELETE

3. **Add BRIN index** for timestamp column (block range index):
   - Efficient for naturally sorted time-series data
   - Much smaller than B-tree: 1/100th the size
   - Good for range queries: `WHERE timestamp BETWEEN x AND y`

**References**: Lines 88-96 (SensorData schema), line 124 (history API), line 211 (2-second target)

---

## Moderate Issues (Priority 3)

### 7. Synchronous Sensor Data Ingestion Without Batching
**Severity**: Moderate
**Category**: I/O & Network Efficiency
**Score Impact**: 1/5

**Issue Description**:
The data collection API (line 119) accepts sensor data via HTTP POST but the design doesn't specify batching strategy. With 1-minute intervals (line 9) and 500 sensors, the system receives 500 requests/minute = ~8 req/second.

**Performance Impact**:
- 8 HTTP requests/second is manageable but inefficient (8 database transactions/second)
- Each request has HTTP overhead (TLS handshake, parsing, routing)
- No backpressure handling if IoT gateway sends bursts
- Scaling to 5000 sensors (large building) = 80 req/second, still synchronous processing
- Lost data if API is down during sensor reading window

**Actionable Recommendations**:
1. **Implement batch ingestion API**:
```json
POST /api/sensors/data/batch
{
  "readings": [
    {"sensor_id": "...", "timestamp": "...", "value": 22.5},
    {"sensor_id": "...", "timestamp": "...", "value": 55.2},
    // ... up to 100 readings
  ]
}
```
   - Reduces HTTP overhead by 100x
   - Single database transaction for batch (ACID guarantees)
   - Gateway sends data every 60 seconds in one batch

2. **Use async processing** for ingestion:
   - POST endpoint returns 202 Accepted immediately
   - Celery task processes validation + database insert
   - Provides backpressure handling (task queue absorbs bursts)

3. **Add message queue** for reliability:
   - IoT gateway → MQTT → AWS IoT Core → SQS → Lambda → Database
   - Decouples ingestion from processing
   - Automatic retry on failure
   - Preserves data during API deployment/downtime

**References**: Line 119 (sensor data API), line 9 (1-minute interval), lines 136-153 (API format)

---

### 8. Missing Asynchronous Patterns for Control Operations
**Severity**: Moderate
**Category**: Latency, Throughput Design & Scalability
**Score Impact**: 1/5

**Issue Description**:
The control API endpoints (lines 131-132) are synchronous HTTP requests, but the design doesn't specify whether the API waits for device acknowledgment or returns immediately. Typical HVAC control protocols (BACnet, Modbus) can take 2-10 seconds for command execution.

**Performance Impact**:
- If synchronous: User waits 2-10 seconds for temperature change confirmation
- HTTP timeout risk if device is slow to respond
- Frontend UI appears frozen during control operations
- No batch control capability (cannot adjust 10 ACs simultaneously)

**Actionable Recommendations**:
1. **Implement async control pattern**:
```json
POST /api/control/hvac/{device_id}
Response 202 Accepted:
{
  "command_id": "abc-123",
  "status": "pending",
  "status_url": "/api/control/commands/abc-123"
}

GET /api/control/commands/abc-123
Response 200 OK:
{
  "command_id": "abc-123",
  "status": "completed",  // or "pending", "failed"
  "executed_at": "2026-02-11T10:05:23Z"
}
```

2. **Use WebSocket for real-time status updates**:
   - Frontend subscribes to device status channel
   - Backend pushes status updates when device responds
   - Better UX than polling

3. **Add batch control endpoint**:
   - `POST /api/control/batch` with array of commands
   - Useful for "set all floor 5 ACs to 22°C" scenarios

**References**: Lines 131-132 (control API), line 210 (500ms average response target)

---

## Minor Issues & Observations

### 9. No Performance Monitoring Strategy Defined
**Severity**: Minor
**Category**: Latency, Throughput Design & Scalability

The design specifies performance targets (lines 209-212) but no monitoring, alerting, or observability strategy to validate whether targets are met in production.

**Recommendations**:
- Implement APM (Application Performance Monitoring): AWS X-Ray, Datadog, or New Relic
- Track key metrics: API latency (p50, p95, p99), database query time, cache hit ratio, error rate
- Set up alerts: p95 latency > 800ms, error rate > 1%, cache hit ratio < 80%
- Include performance metrics in deployment go/no-go criteria

---

### 10. Pandas May Not Be Optimal for Time-Series Aggregation
**Severity**: Minor
**Category**: Algorithm & Data Structure Efficiency

Pandas (line 38) is convenient but not optimized for large-scale time-series operations. For 10M+ row aggregations, specialized tools perform better.

**Recommendations**:
- Consider PostgreSQL window functions for aggregations (5-10x faster than Pandas for large datasets)
- Evaluate TimescaleDB continuous aggregates (pre-computed rollups)
- Use Polars instead of Pandas for large dataframes (5-20x faster, better memory efficiency)

---

## Positive Aspects

### Well-Designed Asynchronous Report Generation
The use of Celery for report generation (lines 64-66, 127-128) is appropriate. Reports are long-running tasks that should not block API responses.

### Appropriate Technology Choices for Base Scale
FastAPI, PostgreSQL, and React are solid choices for the stated 100-user scale. These technologies can handle 10x growth with proper optimization.

### Clear Performance Targets Defined
Unlike many design documents, this one specifies concrete performance targets (500ms API, 2s dashboard, 100 concurrent users). This enables objective validation.

---

## Summary and Prioritized Action Plan

### Immediate Actions (Before Development Starts)
1. **Redesign for horizontal scalability**: Multi-instance architecture with ALB + Auto Scaling
2. **Add Redis caching layer**: For latest sensor readings and metadata
3. **Fix N+1 query problem**: Single JOIN query for dashboard API
4. **Define database indexes**: Time-series composite indexes on sensor_data table

### Before Production Launch
5. **Implement connection pooling**: Explicit pool configuration + PgBouncer
6. **Add batch sensor ingestion API**: Reduce HTTP overhead by 100x
7. **Implement chunked report processing**: Prevent OOM on large reports
8. **Add async control pattern**: Improve UX for device control operations

### Post-Launch Optimization
9. **Add performance monitoring**: APM + alerting for SLA violations
10. **Evaluate time-series database**: TimescaleDB or InfluxDB for better sensor data performance

---

## Risk Assessment

**Without addressing critical issues (1-3)**:
- System will **not meet** 500ms API response target under 100 concurrent users
- Database will become bottleneck at ~20-30 concurrent users
- No growth path beyond single-instance limits (~500 sensors, ~50 users)

**With critical fixes implemented**:
- System can comfortably handle stated 100-user goal
- Clear scaling path to 500+ users and 5000+ sensors
- Performance targets achievable with 80-90% reliability

---

**Reviewer**: Performance Design Reviewer
**Review Date**: 2026-02-11
**Document Version**: test-document-round-001
**Benchmark Variant**: v001-variant-scoring (S2a)
