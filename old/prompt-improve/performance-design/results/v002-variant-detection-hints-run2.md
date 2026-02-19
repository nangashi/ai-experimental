# Performance Design Review: オンライン診療予約システム

## Overall Assessment

This medical appointment system design document presents a reasonable architectural foundation but exhibits several critical and significant performance issues that could severely impact scalability, user experience, and operational efficiency under production load. The design lacks essential performance considerations in database query patterns, caching strategies, resource management, and monitoring infrastructure.

---

## Evaluation by Criteria

### 1. Algorithm & Data Structure Efficiency: 3/5

**Strengths:**
- Basic relational data model is appropriate for the domain
- Primary key usage is correctly applied with AUTO_INCREMENT

**Critical Issues:**

**P01: Missing index strategy for time-series queries**
- **Issue**: The appointments table lacks composite indexes for critical query patterns. Sections 5 and 4 show queries like `GET /api/appointments?doctor_id={id}&date={date}` and `GET /api/appointments?patient_id={id}`, but the schema (Section 4) only defines foreign keys without explicit index definitions.
- **Impact**: Linear scan of appointments table as it grows. With expected load of 500 concurrent users across multiple clinics, the appointments table could reach millions of rows within months. Query response time will degrade from milliseconds to seconds, causing poor UX and potential timeout failures.
- **Recommendation**: Define composite indexes:
  - `INDEX idx_appointments_doctor_date ON appointments(doctor_id, appointment_date, time_slot)` for doctor schedule queries
  - `INDEX idx_appointments_patient_status ON appointments(patient_id, status, appointment_date)` for patient appointment list queries
  - `INDEX idx_appointments_date_status ON appointments(appointment_date, status)` for daily load queries

**Significant Issues:**

**P02: Potential N+1 query problem in medical records retrieval**
- **Issue**: API endpoint `GET /api/medical-records?patient_id={id}` (Section 5) likely requires joining patient, doctor, and appointment tables. Without explicit batch fetching strategy, the ORM (Hibernate, Section 2) may execute separate queries for each related entity.
- **Impact**: For a patient with 10 medical records, this could generate 1 (records) + 10 (appointments) + 10 (doctors) = 21 queries. Latency increases linearly with record count, making historical data retrieval slow.
- **Recommendation**:
  - Configure JPA `@EntityGraph` or explicit JOIN FETCH in repository queries
  - Define DTO projections that fetch only required fields in a single query
  - Add `@BatchSize(size = 50)` annotation on collection associations

---

### 2. I/O & Network Efficiency: 2/5

**Critical Issues:**

**P03: Notification service lacks batch processing design**
- **Issue**: NotificationService (Section 3) sends confirmation emails/SMS via Amazon SNS, but no batch processing or asynchronous queue design is described. The data flow (Section 3, step 5) shows notification as synchronous part of appointment creation.
- **Impact**:
  - Synchronous SNS API calls add 200-500ms latency to every appointment creation request
  - Network failures or SNS throttling directly impact user-facing API response times
  - During peak hours (e.g., morning opening time when many users book simultaneously), SNS rate limits could cause appointment creation failures
- **Recommendation**:
  - Implement asynchronous message queue (Amazon SQS) for notification events
  - Batch multiple notifications into single SNS PublishBatch API calls (up to 10 messages per call)
  - Return appointment creation response immediately, process notifications asynchronously
  - Add retry logic with exponential backoff for transient failures

**P04: Missing database connection pool configuration**
- **Issue**: Section 2 specifies Spring Data JPA but provides no connection pool settings. PostgreSQL has default max_connections limit (typically 100), and ECS tasks may exhaust connections under load.
- **Impact**: Under 500 concurrent sessions (Section 7), with default HikariCP settings (10 connections per instance) and multiple ECS tasks, connection exhaustion will cause "Too many connections" errors, bringing the service down.
- **Recommendation**:
  - Explicitly configure HikariCP: `maximum-pool-size: 20`, `minimum-idle: 5`, `connection-timeout: 30000`, `idle-timeout: 600000`
  - Set PostgreSQL `max_connections` to accommodate all ECS tasks: (num_tasks × pool_size) + buffer
  - Implement connection leak detection: `leak-detection-threshold: 60000`
  - Monitor active connections via `/actuator/metrics/hikaricp.connections.active`

**Significant Issues:**

**P05: API call strategy for available slots lacks optimization**
- **Issue**: Endpoint `GET /api/schedules/available-slots?doctor_id={id}&date={date}` (Section 5) must query all appointments for the day and calculate free slots. Without explicit implementation details, this likely performs separate queries for schedule template and existing appointments.
- **Impact**: Multiple round-trips to database for each available slot query. During high-traffic periods when many patients search for appointments simultaneously, database load spikes.
- **Recommendation**:
  - Pre-calculate and cache available slots for the next 7-14 days during low-traffic periods (nightly batch or queue-based)
  - Use single SQL query with LEFT JOIN to fetch schedule template and appointments in one round-trip
  - Implement Redis caching for frequently queried slots (TTL: 5-10 minutes)

---

### 3. Caching Strategy: 2/5

**Critical Issues:**

**P06: Redis session store mentioned but no application-level caching design**
- **Issue**: Section 2 mentions Redis for session storage, but no caching strategy is defined for frequently accessed reference data (doctor lists, clinic information, specialty master) or computed data (available slots).
- **Impact**: Every API call requiring doctor or clinic information hits PostgreSQL, multiplying database load unnecessarily. Reference data changes infrequently but is read on every appointment creation and search operation.
- **Recommendation**:
  - Cache doctor and clinic master data with TTL of 1-24 hours (updated on write operations)
  - Cache available slots calculation results with short TTL (5-15 minutes)
  - Implement cache-aside pattern: check Redis first, fallback to PostgreSQL, populate cache on miss
  - Use Redis key patterns: `doctor:{doctor_id}`, `available_slots:{doctor_id}:{date}`, `clinic:{clinic_id}`

**Significant Issues:**

**P07: No cache invalidation strategy specified**
- **Issue**: If Redis caching is implemented, the design lacks invalidation strategy for consistency. When doctor schedules change or appointments are created/cancelled, cached available slots become stale.
- **Impact**: Users may see and select time slots that are no longer available, leading to booking failures and poor UX. Race conditions between cache and database state.
- **Recommendation**:
  - Implement write-through or write-behind cache invalidation on appointment mutations
  - Use Redis pub/sub to broadcast cache invalidation events to all application instances
  - Add cache versioning: include timestamp or version number in cache keys
  - Set conservative TTLs for critical data (available slots: 5-10 minutes)

---

### 4. Memory & Resource Management: 3/5

**Strengths:**
- JWT token-based authentication (Section 5) is stateless, reducing server memory footprint

**Significant Issues:**

**P08: No pagination specified for list endpoints**
- **Issue**: Endpoints like `GET /api/appointments?patient_id={id}` and `GET /api/medical-records?patient_id={id}` (Section 5) have no pagination parameters. Patients with long treatment history could have hundreds of records.
- **Impact**:
  - Single request could load hundreds of entities into memory, causing excessive heap usage
  - Large JSON responses consume network bandwidth and increase serialization time
  - Multiple simultaneous requests for large datasets can trigger OutOfMemoryError
- **Recommendation**:
  - Add pagination parameters: `?page=0&size=20&sort=appointment_date,desc`
  - Implement default page size (20-50 items) and maximum limit (100 items)
  - Use cursor-based pagination for real-time data (appointments) to handle concurrent modifications
  - Return pagination metadata in response: `total_count`, `page`, `page_size`, `has_next`

**P09: Missing resource release patterns for external service calls**
- **Issue**: NotificationService integrates with Amazon SNS (Section 2), but no timeout, circuit breaker, or connection pool management is specified.
- **Impact**: If SNS API becomes slow or unresponsive, threads waiting for responses accumulate, exhausting the thread pool. This cascades to complete service outage affecting all users.
- **Recommendation**:
  - Configure HTTP client timeouts for SNS SDK: `connectionTimeout: 3000ms`, `requestTimeout: 5000ms`
  - Implement circuit breaker pattern (Resilience4j) to fail fast when SNS is unhealthy
  - Use dedicated thread pool for notification processing, isolated from main request handling threads
  - Add fallback mechanism: log notification failures to database for later retry

---

### 5. Latency, Throughput Design & Scalability: 2/5

**Critical Issues:**

**P10: Auto-scaling threshold of 70% CPU usage is too high**
- **Issue**: Section 7 specifies "ECSタスク数の自動増減（CPU使用率70%を閾値）" but provides no scaling-up speed, cooldown period, or capacity buffer.
- **Impact**:
  - At 70% CPU, performance degradation has already begun, causing increased latency
  - ECS task startup time (container pull + health check) takes 1-2 minutes, during which degraded performance continues
  - During sudden traffic spikes (e.g., new appointment slots opened), system cannot scale fast enough
- **Recommendation**:
  - Lower scale-out threshold to 50-60% CPU for proactive scaling
  - Configure aggressive scale-out: add 2-3 tasks immediately when threshold is crossed
  - Set conservative scale-in: remove 1 task only after sustained low usage (15+ minutes under 30% CPU)
  - Maintain minimum 2 tasks at all times for high availability
  - Add request count or response time metrics as additional scaling triggers

**P11: No read/write separation or database scaling approach**
- **Issue**: Single PostgreSQL instance serves all read and write operations. Section 7 mentions horizontal scaling for application servers but not for database layer.
- **Impact**:
  - PostgreSQL becomes bottleneck as system scales beyond initial 500 concurrent users
  - Heavy read queries (appointment lists, medical records, available slot calculations) compete with critical write operations (appointment creation)
  - Database CPU and I/O saturation causes cascading failures across all operations
- **Recommendation**:
  - Implement read replica architecture: write to primary, read from 2+ replicas using Spring Data JPA's `@Transactional(readOnly=true)`
  - Route read-heavy endpoints (appointment lists, available slots, medical records) to read replicas
  - Use connection pooling per database role (write pool: 10, read pool: 20)
  - Consider Aurora PostgreSQL for built-in read scaling and automatic failover
  - Plan for vertical scaling: upgrade instance type based on metrics (connections, IOPS, CPU)

**Significant Issues:**

**P12: No performance requirements or SLA definitions for critical operations**
- **Issue**: Section 7 defines 99.5% availability but no latency SLA for appointment creation, search, or retrieval operations.
- **Impact**: Without performance targets, it's impossible to detect degradation before it impacts users. No clear baseline for monitoring alerts or optimization priorities.
- **Recommendation**:
  - Define latency SLAs:
    - Appointment creation: p95 < 500ms, p99 < 1000ms
    - Available slots query: p95 < 300ms, p99 < 600ms
    - Appointment list retrieval: p95 < 400ms, p99 < 800ms
  - Set throughput targets: support 50 appointments/second during peak hours
  - Establish database query time budgets: no query should exceed 100ms at p95

**P13: No monitoring and alerting strategy specified**
- **Issue**: Deployment section (Section 6) mentions health check endpoint but no application performance monitoring (APM), query performance tracking, or alerting thresholds.
- **Impact**:
  - Performance degradation goes unnoticed until users complain
  - No visibility into slow queries, cache hit rates, or external API latency
  - Impossible to perform root cause analysis during incidents
  - Cannot identify optimization targets based on actual usage patterns
- **Recommendation**:
  - Implement APM solution: AWS X-Ray or Datadog for distributed tracing
  - Monitor critical metrics:
    - API response times (per endpoint, p50/p95/p99)
    - Database connection pool utilization and wait time
    - Redis cache hit/miss rates
    - SNS API call latency and error rates
    - Active database queries and slow query log (> 100ms)
  - Set up alerts:
    - CRITICAL: API p99 latency > 2000ms, database connection pool exhaustion (> 90%)
    - WARNING: cache hit rate < 80%, API p95 latency > 1000ms
  - Add custom metrics via Micrometer: appointment creation success rate, slot search frequency

**P14: No asynchronous processing pattern for reminder notifications**
- **Issue**: Section 1 mentions "予約リマインダー通知（メール・SMS）" but no implementation approach is described. If implemented as cron job or scheduled task, it may impact application server performance.
- **Impact**: Sending reminder notifications for hundreds of appointments scheduled for the next day creates significant load. If processed synchronously during business hours, it competes with user-facing requests for resources.
- **Recommendation**:
  - Implement reminder processing as separate background job using AWS Lambda or ECS scheduled task
  - Query appointments for next day in batches (e.g., 100 at a time) to avoid memory pressure
  - Send notifications via SQS → Lambda → SNS pipeline for parallel, isolated processing
  - Schedule execution during low-traffic hours (e.g., 2:00 AM for same-day 8:00 AM appointments)

---

## Summary of Critical Issues

The design document contains **6 critical performance issues** that must be addressed before production deployment:

1. **P01**: Missing database indexes for time-series queries
2. **P03**: Synchronous notification processing blocking API responses
3. **P04**: No database connection pool configuration
4. **P06**: No application-level caching strategy
5. **P10**: Inadequate auto-scaling configuration
6. **P11**: No database read/write separation or scaling approach

These issues will directly cause poor response times, service outages, and inability to scale beyond the initial 500-user target.

---

## Positive Aspects

- JWT-based stateless authentication design supports horizontal scaling well
- ECS Fargate choice eliminates server management overhead and supports auto-scaling
- TestContainers for integration testing shows commitment to quality assurance
- Blue-green deployment strategy minimizes downtime risk
- Request ID logging (X-Request-ID) supports distributed tracing

---

## Overall Score: 2.4/5

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 3/5 | Missing critical indexes for query patterns |
| I/O & Network Efficiency | 2/5 | Synchronous notification, no connection pooling, batch processing gaps |
| Caching Strategy | 2/5 | Redis mentioned but no application caching design or invalidation strategy |
| Memory & Resource Management | 3/5 | No pagination, missing resource release patterns for external services |
| Latency, Throughput & Scalability | 2/5 | Poor auto-scaling config, no DB scaling, missing SLAs and monitoring |

**Recommendation**: This design requires significant revision before proceeding to implementation. Prioritize addressing the 6 critical issues listed above, particularly P03 (async notifications), P04 (connection pooling), P06 (caching), and P11 (database scaling).
