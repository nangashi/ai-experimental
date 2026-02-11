# Performance Architecture Review: Smart Building Management System

## Overall Performance Assessment

This design exhibits multiple critical performance bottlenecks that will significantly impact system scalability and user experience. The most severe issues are in data access patterns, lack of caching strategy, and insufficient scalability planning for time-series data growth.

---

## Critical Issues

### 1. Algorithm & Data Structure Efficiency: Score 2/5 (Critical)

**Critical Issue: Inefficient Time-Series Data Storage in Relational Database**

- SensorData table uses BIGSERIAL as primary key and stores 1-minute interval data in PostgreSQL without any time-series optimization
- With 1-minute intervals, a single sensor generates 1,440 records/day, 525,600 records/year
- For a typical building with 200 sensors (50 per floor × 4 floors), this generates:
  - 288,000 records/day (200 sensors × 1,440)
  - 105,120,000 records/year
- Single-year retention means the SensorData table will contain 100M+ rows, causing severe query performance degradation
- Range queries on timestamp without proper partitioning will result in full table scans
- Expected impact: Dashboard history queries will exceed 10-second response times within 6 months of operation

**Recommendation:**
- Migrate to TimescaleDB (PostgreSQL extension for time-series) with automatic partitioning by timestamp (weekly or monthly chunks)
- Create hypertable on SensorData with timestamp as partitioning key
- Implement continuous aggregates for common query patterns (hourly/daily rollups)
- Add composite index on (sensor_id, timestamp DESC) for efficient sensor-specific time-range queries
- Expected improvement: 10-100x query performance improvement, consistent sub-second response times even with 100M+ records

**Critical Issue: No Index Strategy Defined**

- Design document does not specify any indexes beyond implied primary keys
- Common query patterns require joins between SensorData and Sensors tables (via sensor_id), and Sensors to Floors (via floor_id)
- Dashboard endpoint `/api/dashboard/floor/{floor_id}` requires multiple joins without index coverage
- Expected impact: Every dashboard request will trigger full table scans, causing 5-10 second response times with moderate data volume

**Recommendation:**
- Add indexes:
  - `CREATE INDEX idx_sensor_data_sensor_timestamp ON sensor_data(sensor_id, timestamp DESC)`
  - `CREATE INDEX idx_sensors_floor ON sensors(floor_id)`
  - `CREATE INDEX idx_control_history_device_time ON control_history(device_id, executed_at DESC)`
- Monitor query performance with pg_stat_statements extension
- Plan for quarterly index review and optimization

---

### 2. I/O & Network Efficiency: Score 2/5 (Critical)

**Critical Issue: N+1 Query Pattern in Dashboard Endpoint**

- `GET /api/dashboard/floor/{floor_id}` retrieves "latest_value" and "latest_timestamp" for each sensor on a floor
- The design implies individual queries per sensor to fetch latest data from SensorData table
- For a floor with 50 sensors, this generates 51 queries (1 for sensors list + 50 for latest values)
- Expected impact: 500-1000ms latency per dashboard load (10-20ms per query × 50), unacceptable for real-time monitoring
- Under concurrent load (50 users viewing dashboards), this generates 2,500+ queries/second to PostgreSQL

**Recommendation:**
- Implement a denormalized `sensors_latest_data` table with `sensor_id`, `timestamp`, `value` updated via trigger on SensorData insert
- Use single query with JOIN: `SELECT s.*, sld.value, sld.timestamp FROM sensors s JOIN sensors_latest_data sld ON s.id = sld.sensor_id WHERE s.floor_id = ?`
- This reduces 51 queries to 1 query, achieving sub-100ms response time
- Alternative: Use PostgreSQL LATERAL JOIN with LIMIT 1 to fetch latest data inline

**Significant Issue: No Batch API Design**

- `POST /api/sensors/data` accepts single sensor reading per request
- IoT gateway collecting data from 200 sensors every minute generates 200 HTTP requests/minute
- Each request incurs HTTP overhead (connection setup, TLS handshake, headers)
- Expected impact: 200 requests/minute creates unnecessary network overhead and increases latency from gateway to backend

**Recommendation:**
- Redesign API to accept batch sensor data: `POST /api/sensors/data/batch` with array of readings
- Implement bulk insert using SQLAlchemy `bulk_insert_mappings` or raw SQL `INSERT ... VALUES (...), (...)`
- Reduce 200 requests/minute to 1 request/minute with 200 readings in payload
- Expected improvement: 10x reduction in network overhead, 50% reduction in data ingestion latency

---

### 3. Caching Strategy: Score 2/5 (Critical)

**Critical Issue: No Caching Layer for Dashboard Data**

- Dashboard data is read-heavy with minimal write frequency (sensor data updated every 1 minute)
- Every dashboard page load triggers PostgreSQL queries even when data hasn't changed
- Multiple users viewing the same floor generate redundant identical queries
- Expected impact: Database becomes bottleneck at 50+ concurrent users, cannot handle traffic spikes

**Recommendation:**
- Implement Redis cache with 30-second TTL for dashboard data
- Cache key pattern: `dashboard:floor:{floor_id}:current`
- Use cache-aside pattern: check Redis first, query PostgreSQL on miss, store result in Redis
- Implement cache warming: background job refreshes dashboard cache every 30 seconds
- Expected improvement: 95% cache hit rate, sub-10ms response time for cached reads, 20x reduction in database load

**Critical Issue: No Cache Invalidation Strategy for Configuration Changes**

- Sensor configuration (status, location) can be updated but design doesn't specify cache invalidation
- Stale cache entries will display outdated sensor status to users
- Expected impact: Users see incorrect sensor status until TTL expires, causing operational confusion

**Recommendation:**
- Implement event-driven cache invalidation using Redis pub/sub or message queue
- On sensor configuration update, publish invalidation event to delete related cache keys
- Add cache version tags to handle bulk invalidation scenarios

---

### 4. Memory & Resource Management: Score 3/5 (Significant)

**Significant Issue: Report Generation Memory Risk**

- Report generation uses Pandas for data aggregation without specified memory limits
- Monthly report for 200 sensors loads 8,640,000 records (200 sensors × 1,440/day × 30 days) into memory
- Estimated memory consumption: 500MB-1GB per report depending on data structure
- Concurrent report generation requests can exhaust EC2 instance memory (t3.large has 8GB RAM)
- Expected impact: OOM errors during concurrent report generation, potential system crashes

**Recommendation:**
- Implement streaming data processing using PostgreSQL server-side cursors
- Use SQLAlchemy `yield_per()` to fetch data in batches (1000 records at a time)
- Implement report generation queue with concurrency limit (max 2 concurrent reports)
- Add memory monitoring with alerts at 80% usage threshold
- Consider using database-side aggregation with `GROUP BY` before Pandas processing

**Moderate Issue: No Connection Pooling Configuration Specified**

- Design mentions "single EC2 instance" but doesn't specify database connection pool settings
- Default connection pool may be insufficient for FastAPI async workers + Celery workers
- Expected impact: Connection exhaustion under moderate load (50+ concurrent requests)

**Recommendation:**
- Configure SQLAlchemy connection pool: `pool_size=20`, `max_overflow=10`, `pool_pre_ping=True`
- Set PostgreSQL `max_connections=100` with reserved connections for admin access
- Monitor connection usage with CloudWatch metrics

---

### 5. Latency, Throughput Design & Scalability: Score 2/5 (Critical)

**Critical Issue: Vertical-Only Scaling Strategy Inadequate**

- Design specifies "vertical scaling only" (increasing instance size)
- Vertical scaling hits hard limits (largest EC2 instance), cannot handle exponential growth
- Single instance creates single point of failure for entire system
- PostgreSQL on single EBS volume becomes I/O bottleneck as data grows
- Expected impact: System cannot scale beyond 500-1000 concurrent users or 10+ buildings

**Recommendation:**
- Design for horizontal scalability from the start:
  - Deploy multiple FastAPI instances behind ALB with auto-scaling (2-10 instances)
  - Use stateless design (sessions in Redis, not in-memory)
  - Migrate to RDS PostgreSQL with read replicas (1 primary + 2 read replicas)
  - Route read queries (dashboard, reports) to read replicas
- This enables scaling to 10,000+ concurrent users and 100+ buildings
- Add auto-scaling triggers: CPU > 70% for 5 minutes

**Critical Issue: No Asynchronous Processing for Sensor Data Ingestion**

- `POST /api/sensors/data` processes synchronously: validation → database write → anomaly detection
- Anomaly detection logic (not detailed in design) runs inline during HTTP request
- Expected impact: Sensor data ingestion latency increases as anomaly detection complexity grows
- IoT gateway may timeout waiting for response, causing data loss

**Recommendation:**
- Split ingestion into two phases:
  1. Fast path: Validate and insert to database, return 202 Accepted immediately
  2. Async path: Trigger Celery task for anomaly detection processing
- Use message queue (SQS or Redis Streams) to decouple ingestion from processing
- Expected improvement: 5x faster ingestion response time (50ms vs 250ms)

**Significant Issue: No Query Timeout or Rate Limiting**

- API design doesn't specify query timeouts or rate limiting
- Long-running history queries can monopolize database connections
- Expected impact: Single slow query can cascade to system-wide degradation

**Recommendation:**
- Set statement timeout: `SET statement_timeout = '10s'` for all queries
- Implement rate limiting with Redis: 100 requests/minute per user, 1000 requests/minute per IP
- Add pagination to history endpoint: `GET /api/dashboard/floor/{floor_id}/history?limit=1000&offset=0`
- Enforce maximum time range: 7 days per query for raw data, longer ranges require aggregated data

---

## Moderate Issues

### 6. Missing Performance Observability

**Moderate Issue: No Performance Monitoring Strategy**

- Design specifies logging but not performance metrics collection
- Cannot detect performance degradation trends without metrics
- Expected impact: Performance issues discovered reactively by users, not proactively

**Recommendation:**
- Implement CloudWatch metrics for:
  - API response time per endpoint (p50, p95, p99)
  - Database query duration (pg_stat_statements)
  - Cache hit rate (Redis INFO stats)
  - Background job queue length (Celery inspect)
- Set up CloudWatch Alarms: p95 latency > 1000ms for 5 minutes
- Add APM tool (e.g., New Relic, Datadog) for request tracing

---

## Positive Aspects

1. **Good Asynchronous Design for Reports**: Report generation correctly uses Celery for async processing, preventing blocking of API request threads
2. **Appropriate Technology Stack**: FastAPI's async capabilities and Celery provide good foundation for scalable architecture
3. **Structured Data Model**: Clear separation of Sensors, SensorData, and ControlHistory tables supports future optimization

---

## Summary and Priority Recommendations

**Immediate Action Required (Pre-Launch):**
1. Migrate to TimescaleDB for time-series data with partitioning and continuous aggregates
2. Add comprehensive index strategy (sensor_id + timestamp, floor_id, device_id)
3. Implement Redis caching layer for dashboard data with 30-second TTL
4. Redesign dashboard endpoint to eliminate N+1 queries (denormalized latest data table)
5. Implement batch sensor data ingestion API

**Short-Term (First 3 Months):**
1. Implement horizontal scaling architecture (multiple FastAPI instances + RDS read replicas)
2. Add connection pooling configuration and memory limits for report generation
3. Implement rate limiting and query timeouts
4. Add performance monitoring with CloudWatch metrics and alerts

**Medium-Term (6-12 Months):**
1. Implement data retention policy with automated archival to S3 for old sensor data
2. Add query result caching for frequently accessed historical data
3. Consider event-driven architecture for real-time sensor data streaming (WebSocket or SSE)

Without addressing the critical issues, this system will fail to meet its performance target of "500ms average API response time" and "100 concurrent users" within 3 months of production deployment.
