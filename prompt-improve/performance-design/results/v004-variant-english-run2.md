# Performance Design Review: Medical Device Management Platform

## Executive Summary

This review evaluates the performance architecture of a medical device monitoring platform handling real-time vital sign data from thousands of connected devices. The analysis identifies **4 critical issues**, **3 significant issues**, and **2 moderate issues** that require attention to meet the stated performance goals and ensure system scalability.

**Critical Severity:** The current design exhibits fundamental architectural bottlenecks in time-series data management, database write patterns, and real-time data delivery that will prevent achieving the stated performance targets (5000 devices, 5000 records/sec throughput, <500ms p95 latency).

---

## Evaluation Scores by Criterion

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 2/5 | PostgreSQL used for time-series data without time-series optimizations; polling-based dashboard updates instead of push architecture |
| I/O & Network Efficiency | 2/5 | Individual record writes for each vital sign (5000 writes/sec); 5-second polling creates redundant API calls; no batch processing strategy |
| Caching Strategy | 1/5 | No caching layer defined; every dashboard request hits the database; no cache for frequently accessed data (latest vitals, alert rules) |
| Memory & Resource Management | 3/5 | Connection pooling not specified; WebSocket connection limits undefined; no memory management strategy for concurrent connections |
| Data Lifecycle & Capacity Planning | 1/5 | **Critical gap:** No retention, archival, or purging strategy for continuously growing vital_data table; unbounded data growth will degrade query performance over time |
| Latency, Throughput Design & Scalability | 2/5 | Read replica mentioned but write bottleneck unaddressed; no sharding strategy; stateless design not explicitly confirmed; no async processing for heavy operations |

**Overall Assessment: 11/30 (37%)**

---

## Critical Issues (System-Wide Impact)

### C-1: Missing Time-Series Data Management Strategy

**Severity:** CRITICAL
**Impact:** System failure within 6-12 months due to unbounded data growth

**Problem Description:**

The `vital_data` table stores time-series data with 1-second granularity from 5000 devices. With no retention, archival, or purging strategy defined:

- **Daily growth:** 5000 devices × 86,400 seconds × 3-5 vital types = **1.3-2.2 billion records/day**
- **90-day data:** ~200 billion records (~20TB+ storage)
- **Query degradation:** Range queries on the `vital_data` table will experience exponential slowdown as the table grows, even with proper indexing

**Why This Matters:**

- PostgreSQL is not optimized for time-series data at this scale
- Table bloat will cause vacuum/autovacuum overhead
- Index maintenance costs will increase proportionally
- Query planner performance will degrade
- Backup/restore windows will become unmanageable

**Referenced Sections:**
- Section 4: vital_data table definition (no TTL or partitioning mentioned)
- Section 7: Performance targets (5000 records/sec throughput) without corresponding data lifecycle strategy

**Recommendations:**

1. **Immediate:** Define data retention policy:
   - Hot data (1-7 days): Full-resolution in primary database
   - Warm data (8-90 days): Downsampled to 1-minute granularity, move to partitioned tables or time-series DB
   - Cold data (>90 days): Archive to S3 Glacier with 5-minute granularity or aggregate summaries only

2. **Database Strategy Options:**
   - **Option A:** Migrate to TimescaleDB (PostgreSQL extension for time-series) with automatic data retention policies
   - **Option B:** Implement PostgreSQL table partitioning by timestamp (daily/weekly partitions) with automated partition drop
   - **Option C:** Hybrid architecture: Use InfluxDB/TimescaleDB for time-series data, PostgreSQL for metadata

3. **Implementation Pattern:**
   ```sql
   -- Example: Table partitioning with retention
   CREATE TABLE vital_data (
     data_id BIGSERIAL,
     device_id VARCHAR(50) NOT NULL,
     timestamp TIMESTAMP NOT NULL,
     data_type VARCHAR(20) NOT NULL,
     value NUMERIC(10,2) NOT NULL,
     unit VARCHAR(10) NOT NULL
   ) PARTITION BY RANGE (timestamp);

   -- Automated partition management
   CREATE TABLE vital_data_2026_02 PARTITION OF vital_data
     FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

   -- Drop old partitions with cron job
   DROP TABLE IF EXISTS vital_data_2025_11; -- After 90 days
   ```

4. **Capacity Planning:** Document expected storage growth and query performance thresholds in Section 7.

---

### C-2: Database Write Bottleneck (Individual Record Inserts)

**Severity:** CRITICAL
**Impact:** Cannot achieve 5000 records/sec write throughput; database connection exhaustion under load

**Problem Description:**

Section 3 describes: "WebSocket Server receives data and immediately saves to DB" with 1-second intervals from 5000 devices.

**Current Pattern (Presumed):**
- Each vital sign measurement triggers individual INSERT statement
- No batch processing mentioned
- With 3-5 vital types per device: **15,000-25,000 INSERT/sec** required

**Performance Analysis:**
- PostgreSQL INSERT latency: ~1-5ms per transaction (including network + disk fsync)
- Single-threaded write: Max ~200-1000 TPS per connection
- **Gap:** Need 25,000 TPS but design likely achieves <5,000 TPS

**Why This Matters:**
- Database connections will be exhausted waiting for write completion
- WebSocket receive buffers will overflow, dropping data
- Unable to meet the stated "5000 records/sec throughput" requirement (Section 7)

**Referenced Sections:**
- Section 3: Data flow description (immediate DB save)
- Section 7: Performance targets (5000 records/sec throughput)

**Recommendations:**

1. **Implement Batch Write Pattern:**
   - Buffer incoming vital data in-memory (with size and time-based flush triggers)
   - Use JDBC batch inserts: `INSERT INTO vital_data VALUES (...), (...), (...)` (100-1000 rows per batch)
   - Expected throughput improvement: 10-50x (5,000 → 50,000+ records/sec)

2. **Architecture Pattern:**
   ```java
   // Example: Batch accumulator
   @Component
   public class VitalDataBatchWriter {
       private final ConcurrentLinkedQueue<VitalData> buffer = new ConcurrentLinkedQueue<>();
       private static final int BATCH_SIZE = 500;
       private static final Duration FLUSH_INTERVAL = Duration.ofMillis(200);

       @Scheduled(fixedDelay = 200)
       public void flushBatch() {
           List<VitalData> batch = new ArrayList<>(BATCH_SIZE);
           for (int i = 0; i < BATCH_SIZE && !buffer.isEmpty(); i++) {
               batch.add(buffer.poll());
           }
           if (!batch.isEmpty()) {
               jdbcTemplate.batchUpdate("INSERT INTO vital_data ...", batch);
           }
       }
   }
   ```

3. **Add Write-Ahead Log (WAL) / Message Queue:**
   - Introduce Amazon Kinesis or Kafka as write buffer
   - WebSocket servers publish to Kinesis stream
   - Separate consumer service batches and writes to PostgreSQL
   - Benefit: Decouples ingestion from database write performance

4. **Connection Pool Sizing:**
   - Document connection pool configuration in Section 2
   - Recommended: 20-50 connections for write operations, 50-100 for reads

---

### C-3: Polling-Based Dashboard Updates (Inefficient Real-Time Data Delivery)

**Severity:** CRITICAL
**Impact:** Excessive database load; unable to scale beyond 100-200 concurrent dashboard users

**Problem Description:**

Section 3 states: "Dashboard polls REST API at 5-second intervals"

**Load Analysis:**
- 100 concurrent users × 12 polls/minute = **1,200 API requests/minute** = 20 QPS
- 500 concurrent users = **100 QPS** to fetch latest vitals
- Each request executes query: `SELECT * FROM vital_data WHERE patient_id = ? ORDER BY timestamp DESC LIMIT 1`

**Why This Is Inefficient:**
- 90% of polls return unchanged data (vital signs at 1-second granularity but polled at 5-second intervals)
- Database executes redundant queries even when no new data exists
- REST API servers must handle polling connections constantly
- Network bandwidth wasted on repeated requests

**Referenced Sections:**
- Section 3: Data flow description (5-second polling interval)
- Section 7: Performance targets (API response time <500ms p95)

**Recommendations:**

1. **Migrate to Push Architecture Using Existing WebSocket Infrastructure:**
   - Dashboard clients establish WebSocket connection to server
   - Server pushes vital data updates only when new data arrives
   - Eliminate 90% of redundant API requests

2. **Implementation Pattern:**
   ```java
   // Server-side: Push to dashboard when new data arrives
   @MessageMapping("/vital-stream")
   public void streamVitals(@Payload VitalData data) {
       // Save to DB (batched)
       vitalDataService.saveBatch(data);

       // Push to subscribed dashboard clients
       messagingTemplate.convertAndSend(
           "/topic/patient/" + data.getPatientId(),
           data
       );
   }

   // Client-side: Subscribe to patient's vital stream
   stompClient.subscribe('/topic/patient/12345', (message) => {
       updateDashboard(JSON.parse(message.body));
   });
   ```

3. **Fallback for Compatibility:**
   - Keep REST API for initial page load (latest snapshot)
   - Use WebSocket push for real-time updates
   - Implement HTTP long-polling as fallback for clients without WebSocket support

4. **Benefit Analysis:**
   - **Database load:** 100 QPS → ~5 QPS (20x reduction)
   - **Latency:** 5-second delay → <100ms real-time delivery
   - **Scalability:** Support 5,000+ concurrent dashboard users with same infrastructure

---

### C-4: No Caching Layer for Frequently Accessed Data

**Severity:** CRITICAL
**Impact:** Database overload during peak hours; cannot meet <500ms p95 latency requirement

**Problem Description:**

No caching strategy is defined in the design document. Analysis of API endpoints reveals highly cacheable data patterns:

**High-Frequency Access Patterns:**
- `GET /api/patients/{patientId}/vitals/latest` - Polled every 5 seconds per active dashboard
- `GET /api/dashboard/active-patients` - Accessed by all dashboard users on load
- `GET /api/dashboard/alerts` - Polled frequently by staff interfaces
- Alert rules (read from DB for every vital data point to check thresholds)

**Performance Impact Without Caching:**
- Every request executes database query (even for unchanged data)
- Alert rule checks execute SELECT query 5,000 times/second
- Database connections consumed by read operations, blocking write operations
- p95 latency likely exceeds 500ms under moderate load (200+ concurrent users)

**Referenced Sections:**
- Section 5: API endpoints (no caching headers or cache invalidation strategy)
- Section 7: Performance target (p95 <500ms) unachievable without caching

**Recommendations:**

1. **Implement Multi-Layer Caching Strategy:**

   **Layer 1: Application-Level Cache (Redis)**
   - Latest vitals per patient: TTL 2-5 seconds
   - Active patient list: TTL 10 seconds
   - Alert rules: TTL 5 minutes (invalidate on rule update)
   - Device metadata: TTL 1 hour

   ```java
   // Example: Cache latest vitals
   @Cacheable(value = "latestVitals", key = "#patientId")
   public VitalData getLatestVitals(Integer patientId) {
       return vitalDataRepository.findLatestByPatientId(patientId);
   }

   @CacheEvict(value = "latestVitals", key = "#data.patientId")
   public void saveVitalData(VitalData data) {
       vitalDataRepository.save(data);
   }
   ```

   **Layer 2: HTTP Response Caching**
   - CDN caching for static dashboard assets (S3 + CloudFront already in place)
   - Cache-Control headers on API responses:
     - Latest vitals: `max-age=2, stale-while-revalidate=5`
     - Historical data: `max-age=3600` (immutable past data)

2. **Cache Invalidation Strategy:**
   - **Write-through:** Update cache when new vital data arrives
   - **TTL-based:** Short TTL for real-time data (2-5 seconds)
   - **Event-driven:** Invalidate specific cache keys on data updates using pub/sub

3. **Expected Performance Improvement:**
   - Database read load: 100 QPS → 10-20 QPS (5-10x reduction)
   - API response time: 100-300ms → 5-20ms for cached data
   - p95 latency: Easily achievable <100ms with proper caching

4. **Infrastructure Addition:**
   - Add Redis cluster (ElastiCache) to Section 2 technology stack
   - Document cache sizing: 4-8 GB for 10,000 patients × 5 vitals × 5-second window

---

## Significant Issues (High Impact on Specific Subsystems)

### S-1: Alert Service Missing Async Processing and Rate Limiting

**Severity:** SIGNIFICANT
**Impact:** Alert processing becomes bottleneck; notification delays during high alert volumes

**Problem Description:**

Section 3 mentions "Alert Service detects abnormal values and notifies via Pub/Sub", but no details on:
- How alert rules are evaluated (per-record or batched?)
- Notification delivery mechanism (synchronous or async?)
- Rate limiting for notification floods (e.g., device malfunction triggering hundreds of alerts)

**Performance Risks:**
- If alerts are processed synchronously in the write path, alert processing latency blocks vital data ingestion
- No deduplication: Same alert condition may trigger 60 notifications in 1 minute (1-second data granularity)
- External notification services (Slack, email, SMS) have rate limits that can fail silently

**Referenced Sections:**
- Section 3: Alert Service description (lacks implementation details)
- Section 4: alert_rules table (no deduplication or rate limit fields)

**Recommendations:**

1. **Decouple Alert Processing from Write Path:**
   - Use message queue (Amazon SQS or Kinesis) for alert evaluation
   - Batch process incoming vital data every 1-5 seconds
   - Async notification delivery (non-blocking)

2. **Implement Alert Deduplication and Rate Limiting:**
   ```sql
   -- Add to alert_rules table
   ALTER TABLE alert_rules ADD COLUMN cooldown_seconds INTEGER DEFAULT 300;

   -- Add alert_history table for deduplication
   CREATE TABLE alert_history (
       alert_id SERIAL PRIMARY KEY,
       patient_id INTEGER NOT NULL,
       rule_id INTEGER NOT NULL,
       triggered_at TIMESTAMP NOT NULL,
       acknowledged_at TIMESTAMP,
       INDEX idx_dedup (patient_id, rule_id, triggered_at)
   );
   ```

3. **Alert Processing Logic:**
   - Check last alert timestamp before triggering notification
   - Default cooldown: 5 minutes (prevent notification spam)
   - Escalation rules: If alert persists >15 minutes, re-notify with higher priority

4. **Performance Targets:**
   - Alert detection latency: <2 seconds from data arrival
   - Notification delivery: Best-effort async (don't block data pipeline)

---

### S-2: Report Generation Lacks Async Job Queue and Resource Isolation

**Severity:** SIGNIFICANT
**Impact:** Report generation blocks API requests; potential database overload from long-running queries

**Problem Description:**

Section 5 shows `POST /api/reports/generate` endpoint but doesn't specify:
- Synchronous or asynchronous processing?
- How are long-running report queries isolated from real-time operations?
- Resource limits for report generation?

**Performance Risks:**
- Large date range reports (e.g., 30-day patient summary) execute expensive queries:
  ```sql
  SELECT * FROM vital_data
  WHERE patient_id = ? AND timestamp BETWEEN ? AND ?
  ORDER BY timestamp;
  -- Potential: 2.6M rows for 30 days (1 patient × 86,400 sec × 30 days)
  ```
- If synchronous: API response timeout (likely >30 seconds for large reports)
- If no isolation: Report queries compete with real-time dashboard queries for database connections

**Referenced Sections:**
- Section 3: Report Generator mentioned as batch process
- Section 5: Report API endpoints (no job queue mentioned)

**Recommendations:**

1. **Implement Async Job Queue Pattern:**
   ```json
   POST /api/reports/generate
   {
     "patientId": 12345,
     "startDate": "2026-01-01",
     "endDate": "2026-01-31",
     "reportType": "daily_summary"
   }

   Response 202 Accepted:
   {
     "jobId": "report-abc123",
     "status": "QUEUED",
     "estimatedCompletionTime": "2026-02-11T10:35:00Z"
   }

   GET /api/reports/jobs/report-abc123
   {
     "jobId": "report-abc123",
     "status": "COMPLETED",
     "downloadUrl": "https://s3.../report-abc123.pdf"
   }
   ```

2. **Resource Isolation Strategy:**
   - Use separate database read replica exclusively for report queries
   - Set query timeout: 60 seconds max
   - Connection pool: Dedicated pool with 5-10 connections for reports

3. **Report Optimization:**
   - Pre-aggregate daily/hourly summaries in separate tables
   - Generate reports from aggregated data instead of raw vital_data
   - Example aggregation table:
     ```sql
     CREATE TABLE vital_data_hourly_summary (
         patient_id INTEGER,
         hour_timestamp TIMESTAMP,
         data_type VARCHAR(20),
         avg_value NUMERIC(10,2),
         min_value NUMERIC(10,2),
         max_value NUMERIC(10,2),
         sample_count INTEGER,
         PRIMARY KEY (patient_id, hour_timestamp, data_type)
     );
     ```

4. **Job Processing Infrastructure:**
   - Use AWS Step Functions or Spring Batch for job orchestration
   - Store job status in database (report_jobs table)
   - Notification on completion (email/webhook)

---

### S-3: Missing Index Strategy for Critical Query Patterns

**Severity:** SIGNIFICANT
**Impact:** Query performance degradation as data grows; unable to meet <500ms p95 latency target

**Problem Description:**

Section 4 defines database schema but does not specify indexes beyond primary keys. Analysis of API endpoints reveals critical query patterns that require compound indexes:

**Critical Query Patterns:**
1. Latest vitals: `SELECT * FROM vital_data WHERE patient_id = ? ORDER BY timestamp DESC LIMIT 1`
2. Historical range: `SELECT * FROM vital_data WHERE patient_id = ? AND timestamp BETWEEN ? AND ?`
3. Device data lookup: `SELECT * FROM vital_data WHERE device_id = ? AND timestamp > ?`
4. Alert processing: `SELECT * FROM vital_data WHERE data_type = ? AND timestamp > ? AND value > ?`

**Without Proper Indexes:**
- Query 1 performs sequential scan on multi-billion row table (>10 seconds)
- Query 2 requires timestamp range scan without index (5-30 seconds)
- Queries compete for I/O bandwidth during concurrent access

**Referenced Sections:**
- Section 4: Data model (no index definitions)
- Section 5: API endpoints (query patterns implicit in endpoint design)

**Recommendations:**

1. **Essential Indexes for vital_data:**
   ```sql
   -- Latest vitals query optimization
   CREATE INDEX idx_vital_patient_time DESC ON vital_data (patient_id, timestamp DESC);

   -- Historical range queries
   CREATE INDEX idx_vital_patient_time_type ON vital_data (patient_id, timestamp, data_type);

   -- Device-based queries
   CREATE INDEX idx_vital_device_time ON vital_data (device_id, timestamp DESC);

   -- Alert processing (if queries filter by value)
   CREATE INDEX idx_vital_type_time_value ON vital_data (data_type, timestamp, value)
   WHERE value IS NOT NULL; -- Partial index for efficiency
   ```

2. **Index Maintenance Strategy:**
   - Monitor index bloat with pg_stat_user_indexes
   - Rebuild indexes on partitioned tables after partition drop
   - Consider BRIN indexes for timestamp columns in very large tables (lower maintenance cost)

3. **Query Performance Targets with Indexes:**
   - Latest vitals: <10ms (index-only scan)
   - Historical range (1 day): <100ms (index scan + sequential read)
   - Historical range (30 days): <2 seconds (batch retrieval from aggregated tables recommended)

4. **Add to Section 4:** Document index strategy and expected query performance characteristics.

---

## Moderate Issues

### M-1: WebSocket Connection Limits and Memory Management Not Specified

**Severity:** MODERATE
**Impact:** Potential memory exhaustion when scaling to 5000 concurrent device connections

**Problem Description:**

Section 7 specifies "5000 simultaneous device connections" but Section 3 doesn't address:
- Maximum WebSocket connections per ECS task
- Memory allocated per connection (buffers)
- Connection lifecycle management (idle timeout, heartbeat)

**Capacity Planning:**
- Assume 64KB buffer per WebSocket connection (send + receive)
- 5000 connections × 64KB = **320MB** just for connection buffers
- Add application memory (Spring Boot overhead, JVM heap): ~512MB-1GB per task
- ECS task sizing not specified (likely need 2GB+ memory per task)

**Referenced Sections:**
- Section 3: WebSocket Server component (no sizing details)
- Section 7: Performance targets (5000 simultaneous connections)

**Recommendations:**

1. **Document WebSocket Configuration:**
   - Max connections per task: 1,000-2,000 (run 3-5 tasks for 5000 devices)
   - Connection idle timeout: 5 minutes (disconnect inactive devices)
   - Heartbeat interval: 30 seconds (detect dead connections)
   - Receive buffer size: 16KB (sufficient for JSON vital data)

2. **ECS Task Sizing:**
   - Memory: 2GB per task (500MB heap + 500MB off-heap + 1GB buffer/overhead)
   - CPU: 1 vCPU per task (WebSocket I/O is network-bound, not CPU-bound)
   - Task count: 5 tasks for 5000 connections (1000 connections/task)

3. **Connection Pool Management:**
   ```java
   // Example: WebSocket config
   @Configuration
   public class WebSocketConfig implements WebSocketConfigurer {
       @Override
       public void registerStompEndpoints(StompEndpointRegistry registry) {
           registry.addEndpoint("/ws")
               .setAllowedOrigins("*")
               .withSockJS()
               .setClientLibraryUrl("https://cdn.jsdelivr.net/sockjs/1.5.0/sockjs.min.js")
               .setHeartbeatTime(30000) // 30 second heartbeat
               .setDisconnectDelay(5000);
       }

       @Override
       public void configureWebSocketTransport(WebSocketTransportRegistration registration) {
           registration
               .setMessageSizeLimit(16 * 1024) // 16KB max message
               .setSendBufferSizeLimit(512 * 1024) // 512KB send buffer
               .setSendTimeLimit(20 * 1000); // 20 second timeout
       }
   }
   ```

4. **Monitoring:** Add CloudWatch metrics for WebSocket connection count, memory usage per task, and connection errors.

---

### M-2: Database Connection Pool Sizing Not Defined

**Severity:** MODERATE
**Impact:** Potential connection exhaustion under load; suboptimal resource utilization

**Problem Description:**

Section 2 mentions Spring Data JPA but doesn't specify database connection pool configuration. With the described workload:

**Connection Requirements:**
- WebSocket servers writing vital data: 20-50 connections (batch writes)
- REST API servers for dashboard: 50-100 connections (read queries)
- Report generation: 5-10 connections (isolated pool)
- Alert processing: 10-20 connections

**Total: 85-180 connections** required across all services.

**PostgreSQL Default Limits:**
- RDS db.t3.large: max_connections = 100 (insufficient)
- RDS db.m5.xlarge: max_connections = 200 (marginal)

**Referenced Sections:**
- Section 2: Technology stack (Spring Data JPA mentioned, no connection pool config)
- Section 3: Multiple components accessing database concurrently

**Recommendations:**

1. **Define Connection Pool Strategy:**
   ```yaml
   # application.yml
   spring:
     datasource:
       hikari:
         maximum-pool-size: 50  # Per service instance
         minimum-idle: 10
         connection-timeout: 5000  # 5 seconds
         idle-timeout: 300000  # 5 minutes
         max-lifetime: 600000  # 10 minutes
         leak-detection-threshold: 60000  # Detect connection leaks
   ```

2. **Database Sizing:**
   - RDS instance: db.m5.xlarge (max_connections = 200)
   - Connection allocation:
     - WebSocket services (3 tasks × 20 connections): 60
     - REST API services (5 tasks × 30 connections): 150
     - Reserved for admin/maintenance: 10
     - Total: 220 connections → **Upgrade to db.m5.2xlarge (max_connections = 400)**

3. **Connection Efficiency Patterns:**
   - Use read replicas for dashboard queries (offload read traffic)
   - Implement connection pooling at application level (HikariCP already bundled with Spring Boot)
   - Monitor connection utilization with CloudWatch RDS metrics

4. **Add to Section 2:** Document connection pool configuration and database instance sizing rationale.

---

## NFR & Scalability Gaps

The following required NFR elements are **missing** from Section 7:

### Missing: Horizontal Scaling Configuration
- **Auto-scaling policy details:** CPU threshold (70% mentioned) but no scale-up/down timing, cooldown periods, or task count limits specified
- **Recommendation:** Define min/max task counts (e.g., WebSocket: 3-10 tasks, REST API: 5-20 tasks) and scale-up trigger (sustained 70% CPU for 2 minutes)

### Missing: Distributed Tracing
- **Issue:** With multiple ECS tasks and database replicas, debugging latency issues requires distributed tracing
- **Recommendation:** Add AWS X-Ray for request tracing across WebSocket → Database → REST API flows

### Missing: Circuit Breaker for External Dependencies
- **Issue:** Alert notification failures (Slack, email services) can cascade into main application
- **Recommendation:** Implement Resilience4j circuit breaker pattern for external service calls

### Missing: Database Query Timeout Configuration
- **Issue:** Runaway queries (e.g., unbounded report generation) can lock database connections
- **Recommendation:** Set query timeout: 30 seconds for API queries, 60 seconds for reports

---

## Positive Aspects

Despite the identified issues, the design demonstrates several sound performance practices:

1. **Read Replica Strategy:** Section 7 mentions read replicas for load distribution (good foundation, though underutilized without proper caching)
2. **Auto-Scaling Enabled:** ECS auto-scaling based on CPU usage shows awareness of horizontal scalability
3. **Appropriate Technology Choices:** Spring Boot, PostgreSQL, and AWS managed services are solid foundations for medical-grade systems
4. **Multi-AZ RDS:** High availability configuration will prevent performance degradation during failover scenarios

---

## Summary of Recommended Actions (Priority Order)

| Priority | Issue | Action | Expected Impact |
|----------|-------|--------|-----------------|
| 1 | C-1: Time-series data lifecycle | Implement partitioning + retention policy | Prevent system failure, maintain query performance |
| 2 | C-2: Write bottleneck | Implement batch writes (500-1000 records/batch) | 10-50x write throughput improvement |
| 3 | C-4: No caching | Add Redis caching layer | 5-10x read load reduction, <100ms p95 latency |
| 4 | C-3: Polling overhead | Migrate to WebSocket push for dashboard | 20x reduction in API requests |
| 5 | S-3: Missing indexes | Create compound indexes on vital_data | 100-1000x query speedup |
| 6 | S-1: Alert processing | Async alert queue + deduplication | Decouple alert latency from ingestion path |
| 7 | S-2: Report generation | Async job queue + read replica isolation | Prevent reports from blocking real-time queries |
| 8 | M-2: Connection pool | Define pool sizing + upgrade RDS instance | Prevent connection exhaustion |
| 9 | M-1: WebSocket limits | Document connection limits + task sizing | Ensure 5000 device capacity is achievable |

---

## Conclusion

The current design requires **significant architectural revisions** to meet the stated performance goals. The four critical issues (time-series data management, write bottleneck, polling overhead, and lack of caching) represent fundamental architectural gaps that will prevent the system from scaling to 5000 concurrent devices and achieving <500ms p95 latency.

**Immediate Next Steps:**
1. Revise Section 4 to include time-series data partitioning and retention strategy
2. Revise Section 3 to specify batch write processing and WebSocket push architecture
3. Add Redis caching layer to Section 2 technology stack
4. Document index strategy and connection pool configuration

**Timeline Estimate:**
- Critical fixes (C-1 through C-4): 6-8 weeks of architectural rework
- Significant fixes (S-1 through S-3): 4-6 weeks
- Moderate fixes (M-1, M-2): 2-3 weeks

Without addressing these issues, the system will likely fail to meet performance SLAs within 6-12 months of production deployment due to data growth and scalability bottlenecks.
