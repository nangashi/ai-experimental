# Performance Design Review: Smart Energy Management System

**Review Date**: 2026-02-11
**Reviewer**: Performance Design Reviewer (v006-variant-decomposition)
**Document**: Smart Energy Management System - System Design Document

---

## Step 1: Document Structure Analysis

### Sections Present
The design document contains the following sections:
- **Overview**: Project background, key features, target users
- **Technology Stack**: Backend, database, infrastructure, key libraries
- **Architecture Design**: Overall architecture, component responsibilities
- **Data Model**: Primary entities with SQL schemas
- **API Design**: Authentication, key endpoints
- **Implementation Guidelines**: Data ingestion flow, aggregation process, alert processing, analytics report generation, error handling, logging, testing strategy, deployment
- **Non-Functional Requirements**: Scalability, availability, data retention

### Architectural Aspects Explicitly Documented
- Microservices architecture with component separation
- Technology choices (FastAPI, TimescaleDB, Redis, Celery)
- Data model with time-series optimization
- Asynchronous processing via Celery
- Load balancing and health checks
- Blue-green deployment strategy
- Scale targets (50 buildings/tenant, 1000 sensors/building, 10M readings/day)
- Availability target (99.5%)

### Missing or Incomplete Architectural Concerns
- **No explicit performance SLAs** for API response times or ingestion latency
- **No monitoring/observability strategy** beyond centralized logging
- **No database indexing strategy** despite complex queries expected
- **No caching strategy details** despite Redis being part of the stack
- **No connection pooling configuration** for database connections
- **No rate limiting or backpressure mechanisms** for ingestion spikes
- **No query optimization guidelines** for time-series data access
- **No autoscaling policies** for ECS Fargate services
- **No disaster recovery/backup strategy** beyond data retention policy

---

## Step 2: Performance Issue Detection

### CRITICAL ISSUES

#### C1: Synchronous Analytics Report Generation Blocks API Thread
**Location**: Section 6 - Analytics Report Generation (lines 245-250)

**Issue**: The analytics report generation process is described as synchronous: "API Service synchronously calls Analytics Service" → loads historical data → applies ML models → generates PDF → returns. This blocks the API thread for potentially minutes while ML model inference and PDF generation complete.

**Impact**:
- API timeout risk for reports covering long time periods (quarter/year)
- Thread pool exhaustion under concurrent report requests
- Poor user experience with browser connection timeouts
- Cascading failures as API workers become unavailable

**Expected Performance**: For a quarterly report analyzing 1000 sensors × 90 days = 90,000 data points with ML forecasting + PDF rendering, this could take 30-120 seconds, far exceeding typical API gateway timeouts (30s).

**Recommendation**:
1. Convert to asynchronous job pattern: API returns 202 Accepted with job_id immediately
2. Use Celery to process report generation in background
3. Add GET /api/v1/reports/{job_id}/status endpoint for polling
4. Notify user via WebSocket or email when report completes
5. Store generated PDF in S3 with signed URL for download

---

#### C2: N+1 Query Problem in Tenant Buildings List API
**Location**: Section 5 - Get Tenant Buildings List (lines 212-221)

**Issue**: The endpoint returns `sensor_count` per building, but the schema shows sensors table with `building_id` foreign key. With no explicit batch query design, this likely executes 1 query for buildings list + N queries for sensor counts (one per building).

**Impact**:
- For 50 buildings/tenant: 1 + 50 = 51 database queries
- Linear latency increase with building count
- Database connection pool exhaustion under concurrent tenant requests
- Potential for query timeout with large tenant portfolios

**Expected Performance**: Assuming 10ms per query, 51 queries = 510ms minimum latency vs. 10-20ms for optimized query.

**Recommendation**:
1. Use SQL JOIN with COUNT aggregate:
```sql
SELECT b.id, b.name, COUNT(s.id) as sensor_count
FROM buildings b
LEFT JOIN sensors s ON s.building_id = b.id AND s.is_active = true
WHERE b.tenant_id = ?
GROUP BY b.id, b.name
```
2. Add index on `sensors(building_id, is_active)` for query performance
3. Document batch query pattern in Implementation Guidelines

---

#### C3: Alert Processing Creates Query Thundering Herd
**Location**: Section 6 - Alert Processing (lines 239-242)

**Issue**: "Every 15 minutes, Processing Service queries latest readings" and "For each building exceeding threshold, sends email notification". With 50 tenants × 50 buildings = 2,500 buildings, this executes 2,500+ queries every 15 minutes (one per building to fetch latest readings and compare against thresholds).

**Impact**:
- Database CPU spike every 15 minutes (thundering herd pattern)
- Inefficient time-series scan without optimization
- Email service rate limiting/queueing issues with burst of notifications
- Delays in alert delivery during processing bottleneck

**Expected Performance**: At scale (2,500 buildings × 1000 sensors = 2.5M sensors), querying latest readings individually is catastrophically slow. Even with 1ms per sensor lookup, that's 2,500 seconds (41 minutes) of serial query time.

**Recommendation**:
1. Use TimescaleDB continuous aggregates to maintain real-time summary view:
```sql
CREATE MATERIALIZED VIEW latest_building_consumption
WITH (timescaledb.continuous) AS
SELECT building_id, time_bucket('15 minutes', timestamp) AS bucket,
       SUM(value_kwh) as total_kwh
FROM energy_readings r JOIN sensors s ON r.sensor_id = s.id
GROUP BY building_id, bucket;
```
2. Single query joins latest_building_consumption with alert_configs to find violations
3. Batch email notifications (aggregate multiple alerts per tenant into digest)
4. Add index on `alert_configs(building_id, is_enabled)` for join performance

---

#### C4: Missing Index Strategy for Time-Series Queries
**Location**: Section 4 - Data Model (lines 119-130)

**Issue**: While TimescaleDB hypertable is created on `energy_readings`, there's no documentation of indexes for common query patterns. The API endpoint at lines 164-180 requires filtering by `building_id` and `timestamp` range, but current schema only has composite primary key `(sensor_id, timestamp)`.

**Impact**:
- Full table scan when querying by building_id across date range
- Slow response for "Get Building Energy Data" API (potentially 10-30 seconds for 90-day query)
- Index-only scan optimization opportunities missed
- Aggregation queries (hourly/daily summaries) inefficient without proper indexes

**Expected Performance**: Querying 90 days of data for 1000-sensor building (90 × 24 × 1000 = 2.16M rows) without building_id index requires full sequential scan. At TimescaleDB's ~100K rows/sec scan rate, this takes 21+ seconds per building query.

**Recommendation**:
1. Add composite index on `energy_readings(sensor_id, timestamp DESC)` for sensor-level time-range queries
2. Add index on `sensors(building_id)` for building → sensor joins
3. Consider space-partitioned index on `(building_id, timestamp)` if queries primarily filter by building first
4. Document index strategy in Data Model section
5. Use EXPLAIN ANALYZE to validate query plans in testing

---

#### C5: Aggregation Process Single-Transaction Risk
**Location**: Section 6 - Aggregation Process (lines 233-237)

**Issue**: "All aggregation runs in a single database transaction". For hourly aggregation processing 10M readings/day ÷ 24 hours = ~417K readings/hour, a single transaction locks affected rows and holds transaction ID for extended duration.

**Impact**:
- Transaction lock timeout risk with concurrent queries
- PostgreSQL MVCC bloat from long-running transaction (vacuum cannot reclaim tuples)
- Rollback catastrophe: hour of computation lost if transaction fails at 99% completion
- Blocks autovacuum on aggregated tables
- High risk of OOM if aggregation holds large intermediate result set in memory

**Expected Performance**: Processing 417K readings with pandas DataFrame operations + database writes could take 30-120 seconds. During this time, all aggregated rows are locked and transaction ID is held, causing bloat accumulation.

**Recommendation**:
1. Batch aggregation into micro-transactions (e.g., process 10-minute windows separately)
2. Use TimescaleDB continuous aggregates for incremental materialized view updates:
```sql
CREATE MATERIALIZED VIEW hourly_summaries
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', timestamp) AS hour,
       sensor_id, AVG(value_kwh), SUM(value_kwh)
FROM energy_readings GROUP BY hour, sensor_id;
```
3. Configure continuous aggregate refresh policy for automatic incremental updates
4. Implement idempotent aggregation logic to enable safe retry on failure
5. Add monitoring for transaction duration (alert if >10 seconds)

---

### SIGNIFICANT ISSUES

#### S1: No Connection Pool Configuration Defined
**Location**: Section 2 - Technology Stack (SQLAlchemy mentioned at line 46)

**Issue**: SQLAlchemy ORM is specified but no connection pooling configuration is documented. With 4 microservices (Ingestion, Processing, Analytics, API) each potentially running multiple instances, uncontrolled connection pool sizing can exhaust PostgreSQL's max_connections limit.

**Impact**:
- Database connection exhaustion under load (PostgreSQL default max_connections = 100)
- Connection acquisition timeout errors in application
- Failed deployments if new service instances cannot acquire connections
- No connection reuse optimization configured

**Expected Performance**: At scale with autoscaling: 4 services × 5 instances × 20 connections/instance = 400 connections needed, far exceeding default limits. Connection acquisition timeout typically set to 30s, causing 30s API latency spikes when pool exhausted.

**Recommendation**:
1. Configure SQLAlchemy connection pool per service:
   - Ingestion Service: pool_size=10, max_overflow=5 (write-heavy)
   - API Service: pool_size=20, max_overflow=10 (read-heavy, user-facing)
   - Processing/Analytics: pool_size=5, max_overflow=5 (background jobs)
2. Set pool_pre_ping=True to handle stale connections
3. Configure pool_recycle=3600 to prevent connection timeout
4. Document in Implementation Guidelines
5. Configure PostgreSQL max_connections=200 and connection pooler (PgBouncer) if needed

---

#### S2: Redis Cache Layer Undefined Despite Technology Choice
**Location**: Section 2 - Database (Redis 7 specified at line 34)

**Issue**: Redis is listed in technology stack for caching but no caching strategy is documented. The system has clear high-cache-hit-ratio opportunities (building metadata, sensor configurations, alert configs) that are likely queried repeatedly.

**Impact**:
- Repeated database queries for immutable/slowly-changing data
- Unnecessary database load for reference data lookups
- Missed opportunity for API response time optimization (potential 10-50ms database query → 1-2ms cache hit)
- Redis resource underutilization despite infrastructure cost

**Expected Performance**: Building metadata query for dashboard: without cache, 20-30ms database query on every page load. With cache (99% hit ratio), average 1-2ms. For 1000 requests/sec, this saves 18-28ms × 1000 = 18-28 CPU-seconds per second of database load.

**Recommendation**:
1. Implement read-through cache pattern for:
   - Building metadata (TTL: 1 hour, invalidate on update)
   - Sensor configurations (TTL: 1 hour, invalidate on update)
   - Alert configurations (TTL: 15 minutes, invalidate on update)
   - Tenant settings (TTL: 24 hours)
2. Use cache-aside pattern for:
   - Recent energy readings (last 24 hours, TTL: 5 minutes)
   - Dashboard summary statistics (TTL: 5 minutes)
3. Implement cache key versioning for safe invalidation
4. Monitor cache hit ratio (target >95% for reference data)
5. Document caching strategy in Implementation Guidelines

---

#### S3: No Query Optimization for Get Building Energy Data API
**Location**: Section 5 - Get Building Energy Data (lines 164-180)

**Issue**: The endpoint allows resolution=hour|day|month but no aggregation strategy is documented. Querying hourly data for a year (365 × 24 × 1000 sensors = 8.76M rows) and aggregating in application layer is inefficient.

**Impact**:
- Massive data transfer from database to application (8.76M rows × ~50 bytes = 438 MB)
- Application memory pressure from large result sets
- Network bandwidth waste
- Slow response times (10-60 seconds for large date ranges)

**Expected Performance**: Transferring 438 MB over AWS network at 1 Gbps = 3.5 seconds for network alone, plus serialization/deserialization overhead. Application-side aggregation with pandas could add 10-30 seconds.

**Recommendation**:
1. Push aggregation to database using TimescaleDB time_bucket:
```sql
SELECT time_bucket('1 day', timestamp) as day,
       SUM(value_kwh) as consumption_kwh
FROM energy_readings r
JOIN sensors s ON r.sensor_id = s.id
WHERE s.building_id = ? AND timestamp BETWEEN ? AND ?
GROUP BY day ORDER BY day;
```
2. For month resolution, use `time_bucket('1 month', timestamp)`
3. Leverage pre-computed materialized views (hourly_summaries, daily_summaries) when available
4. Add pagination for large result sets (max 1000 data points per response)
5. Implement query result caching in Redis (TTL based on data freshness requirements)

---

#### S4: Ingestion Pipeline Lacks Backpressure Mechanism
**Location**: Section 6 - Data Ingestion Flow (lines 226-230)

**Issue**: Flow is described as "return 202 Accepted response immediately" after writing to TimescaleDB, with no mechanism to handle write throughput spikes. At 10M readings/day (116 writes/sec average), bursts could reach 10-100x during coordinated sensor transmissions.

**Impact**:
- Database write saturation during sensor data bursts
- Celery queue buildup if aggregation cannot keep pace
- Memory exhaustion in Ingestion Service from buffering
- Data loss risk if write buffer overflows with no backpressure signal

**Expected Performance**: Burst scenario: 5000 buildings × 1000 sensors × synchronized 15-minute transmission = 5M writes in <1 minute = 83K writes/sec. PostgreSQL can handle ~10-20K inserts/sec on typical hardware, causing 4-8x overload.

**Recommendation**:
1. Implement batch ingestion endpoint (already exists at line 199-209) and enforce its use
2. Add rate limiting at API Gateway (e.g., 1000 requests/sec per tenant)
3. Implement backpressure: return 429 Too Many Requests when database write queue exceeds threshold
4. Use TimescaleDB insert buffer with batching (batch_size=1000, flush_interval=1s)
5. Add metrics for ingestion queue depth and alert on backlog >10k readings
6. Consider Kafka/Kinesis as ingestion buffer for write spikes (decouple API from database)

---

#### S5: No Autoscaling Policy for ECS Fargate Services
**Location**: Section 2 - Infrastructure (ECS Fargate mentioned at line 38)

**Issue**: ECS Fargate is specified as container platform but no autoscaling policy is documented. This is critical for handling variable load patterns (weekday vs. weekend, business hours vs. night).

**Impact**:
- Over-provisioning during low-traffic periods (wasted infrastructure cost)
- Under-provisioning during peak periods (degraded performance, timeout errors)
- No automatic response to traffic spikes
- Manual intervention required for scaling events

**Expected Performance**: Without autoscaling, system must be provisioned for peak load (10M readings/day = 116 writes/sec average, 1000+ reads/sec during business hours). This results in 5-10x over-provisioning during off-peak hours.

**Recommendation**:
1. Configure ECS Service Auto Scaling for each service:
   - **Ingestion Service**: Scale on custom metric (ingestion queue depth), target 1000 messages/task
   - **API Service**: Scale on ALB RequestCountPerTarget, target 500 requests/task
   - **Processing Service**: Scale on Celery queue length, target 100 tasks/worker
   - **Analytics Service**: Scale on CPU utilization, target 70%
2. Set min/max task count per service (e.g., API: min=2, max=20)
3. Configure scale-in cooldown period (300s) to prevent flapping
4. Implement predictive scaling for known daily patterns
5. Document autoscaling policies in Implementation Guidelines

---

### MODERATE ISSUES

#### M1: Aggregation Hourly Schedule May Lag During High Load
**Location**: Section 6 - Aggregation Process (line 233)

**Issue**: "Celery task runs every hour" assumes each aggregation completes within 1 hour. If processing 417K readings/hour takes >60 minutes during peak load, aggregation jobs queue up and lag increases.

**Impact**:
- Stale daily_summaries data if aggregation falls behind
- Dashboard shows outdated metrics
- Alert detection delays (relies on aggregated data)
- Cascading delays as backlog accumulates

**Recommendation**:
1. Use TimescaleDB continuous aggregates instead of scheduled batch processing
2. If retaining Celery approach, add monitoring for task duration and queue depth
3. Implement priority queues (real-time alerts > aggregation > batch analytics)
4. Add circuit breaker: skip aggregation cycle if previous job still running
5. Configure Celery worker autoscaling based on queue backlog

---

#### M2: PDF Report Generation in-process Memory Risk
**Location**: Section 6 - Analytics Report Generation (line 249)

**Issue**: "Generates PDF report" within Analytics Service implies in-memory PDF rendering. For comprehensive reports with charts/graphs over large time periods, this consumes significant memory per request.

**Impact**:
- Memory spike per report generation (potentially 100-500 MB per report)
- OOM risk if multiple concurrent reports requested
- Slow garbage collection pauses affecting other requests in same process

**Recommendation**:
1. Offload PDF generation to separate worker pool with memory limits
2. Stream report data to temp file instead of in-memory buffer
3. Set worker memory limit (e.g., 2 GB) with graceful restart on threshold
4. Implement report queue with concurrency limit (max 5 concurrent PDF generations)
5. Consider serverless function (Lambda) for isolated PDF rendering

---

#### M3: No Explicit SLA for API Response Times
**Location**: Section 7 - Non-Functional Requirements (lines 272-288)

**Issue**: NFRs define scalability targets and 99.5% availability but no latency SLAs (p50, p95, p99 response times) for API endpoints.

**Impact**:
- No objective metric for performance regression detection
- Cannot validate if optimization efforts are successful
- No basis for alert thresholds on response time degradation
- Difficult to diagnose "slow performance" complaints without baseline

**Recommendation**:
1. Define endpoint-specific SLAs:
   - GET /buildings/{id}/energy: p95 < 200ms, p99 < 500ms
   - POST /sensors/readings/batch: p95 < 100ms, p99 < 300ms
   - GET /analytics/report: Async (202 response < 50ms), generation < 60s
   - GET /tenants/{id}/buildings: p95 < 100ms, p99 < 200ms
2. Instrument API Service with response time histograms
3. Configure CloudWatch alarms for p95/p99 SLA violations
4. Include performance SLA validation in testing strategy

---

#### M4: Daily Summary Aggregation Logic Unclear
**Location**: Section 4 - Daily Summary Schema (lines 133-142)

**Issue**: The daily_summaries table includes `cost_estimate` but no design documentation explains how this is calculated. If this requires external API call to utility provider, it introduces latency and failure modes not addressed.

**Impact**:
- If synchronous: aggregation blocked on external API response time (potential 1-10 second delay per building)
- If API rate limited: aggregation job failures
- If API unavailable: silent data gaps in cost estimates
- No caching strategy for utility rate data

**Recommendation**:
1. Clarify cost calculation approach in Implementation Guidelines
2. If using utility provider API: cache rate schedules (update daily), calculate costs locally
3. If rate schedules change infrequently: store in database table with version tracking
4. Make cost calculation optional/best-effort (allow aggregation to succeed even if cost unavailable)
5. Add retry logic with exponential backoff for rate API calls

---

#### M5: No Database Query Timeout Configuration
**Location**: Section 6 - Error Handling (lines 253-255)

**Issue**: Database connection retry is documented (max 3 attempts) but no query timeout is specified. Long-running queries can hold connections and resources indefinitely.

**Impact**:
- Connection pool exhaustion from queries waiting on slow table scans
- Cascading failures as connection waits pile up
- No protection against accidental full table scans
- User requests hang waiting for slow query completion

**Recommendation**:
1. Configure SQLAlchemy query timeout (e.g., 30s for API queries, 300s for batch jobs)
2. Set statement_timeout in PostgreSQL for per-role timeout enforcement
3. Different timeouts per service type:
   - API Service: 10s (user-facing, must be fast)
   - Ingestion Service: 5s (simple inserts)
   - Analytics Service: 300s (complex batch queries allowed)
4. Monitor slow query log (log queries >1s)
5. Document timeout configuration in Implementation Guidelines

---

### MINOR IMPROVEMENTS

#### I1: Consider Read Replicas for Analytics Queries
**Location**: Section 2 - Database (PostgreSQL 15 mentioned at line 32)

**Observation**: Analytics Service runs heavy read queries (historical data loading, forecasting) on the same database instance as real-time writes. This creates resource contention.

**Recommendation**: Consider PostgreSQL read replicas for Analytics and API Services, reserving primary for writes. This provides read scalability and isolates analytical workload from operational queries.

---

#### I2: Compression for Archived Time-Series Data
**Location**: Section 7 - Data Retention (lines 285-288)

**Observation**: Raw readings archived to S3 after 90 days. TimescaleDB supports native compression that could reduce storage costs before archival.

**Recommendation**: Enable TimescaleDB compression on energy_readings chunks older than 7 days. This can achieve 10-20x compression ratio, reducing database size and S3 transfer costs.

---

#### I3: Structured Logging Fields for Query Performance Analysis
**Location**: Section 6 - Logging (lines 257-260)

**Observation**: Structured JSON logging is planned but no specific fields mentioned. Including query execution time in log structure enables performance analysis.

**Recommendation**: Add structured fields: `query_duration_ms`, `query_rows_returned`, `cache_hit` (true/false) to all database query logs. This enables automated detection of slow query patterns.

---

## Summary

This design document demonstrates solid architectural choices (TimescaleDB for time-series, microservices separation, async processing) but contains critical performance vulnerabilities that will manifest under production load:

**Critical Risks**:
1. Synchronous analytics report generation will cause timeout failures and thread exhaustion
2. N+1 query patterns and missing indexes will degrade linearly with data growth
3. Alert processing thundering herd will create periodic database saturation
4. Single-transaction aggregation creates lock contention and rollback risk

**Recommended Priority Actions**:
1. Convert analytics report to async job pattern (C1)
2. Implement batch query optimization and add necessary indexes (C2, C4)
3. Redesign alert processing with continuous aggregates (C3)
4. Replace single-transaction aggregation with TimescaleDB continuous aggregates (C5)
5. Define and implement caching strategy for Redis (S2)
6. Configure connection pooling and autoscaling policies (S1, S5)

The design shows awareness of scale requirements (10M readings/day, 50K sensors) but lacks implementation details for mechanisms required to achieve those targets efficiently. Addressing the critical and significant issues identified above is essential before production deployment.
