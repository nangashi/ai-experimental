# Performance Design Review: オンライン診療予約システム

## Executive Summary

This performance evaluation identifies **critical capacity planning gaps**, **missing scalability requirements**, and **database performance risks** in the design document. The system targets 500 concurrent sessions but lacks essential NFR specifications for load handling, monitoring strategy, and database optimization for expected growth.

**Overall Assessment**: The design demonstrates basic awareness of scalability (auto-scaling at 70% CPU) but requires substantial enhancement to ensure production readiness at the stated scale.

---

## Critical Issues (Priority 1)

### C1: No Capacity Planning or Growth Projections

**Issue**: The design specifies "最大500セッション" (max 500 concurrent sessions) but provides **no foundation for this number**. Critical capacity planning elements are absent:

- No expected user base size or growth trajectory
- No data volume projections (appointments/day, patients, medical records growth)
- No resource sizing calculations (CPU/memory per task, database storage requirements)
- No rationale for 500 session limit vs. actual medical institution needs

**Impact**:
- Risk of severe under-provisioning or wasteful over-provisioning
- No basis for infrastructure cost estimation
- Cannot validate if ECS auto-scaling thresholds (70% CPU) align with actual load patterns
- Medical institutions cannot assess if system meets their patient volume requirements

**Recommendations**:
1. Define expected user base: number of patients, medical institutions, concurrent users during peak hours (e.g., morning appointment rush)
2. Project data growth: appointments per day/month, medical record accumulation rate over 1-3 years
3. Calculate resource requirements based on load testing results (e.g., memory per concurrent session, database IOPS for N appointments/second)
4. Document capacity planning assumptions and review cycles (quarterly capacity review)

**Severity**: **CRITICAL** - Production deployment without capacity planning leads to unpredictable failures or cost overruns

**Score Impact**: Latency/Throughput Design & Scalability score severely affected

---

### C2: Missing Performance SLA Definitions

**Issue**: No Service Level Agreement (SLA) or performance targets are specified:

- No response time requirements (e.g., "予約作成APIは95%ile 500ms以内")
- No throughput targets (e.g., "予約作成を100 req/sec処理可能")
- No percentile metrics (p50, p95, p99) for latency measurement
- No availability calculation basis (99.5% target exists but no performance component)

**Impact**:
- No objective criteria to validate if design meets user expectations
- Cannot determine if 70% CPU auto-scaling threshold is appropriate
- Performance regression during deployment cannot be detected
- Medical staff cannot assess if system meets clinic workflow timing requirements (e.g., "受付対応時に3秒以内で予約確認")

**Recommendations**:
1. Define response time SLAs per endpoint priority:
   - High priority (予約作成, 予約可能枠取得): p95 < 500ms, p99 < 1000ms
   - Medium priority (予約一覧取得): p95 < 1000ms
   - Low priority (診察履歴取得): p95 < 2000ms
2. Specify throughput targets based on expected peak load (e.g., "朝8-9時に予約作成100 req/min処理")
3. Define performance acceptance criteria for deployment (e.g., "p95レスポンスが前バージョン比20%以内")

**Severity**: **CRITICAL** - Without SLAs, no way to validate if system is production-ready

**Score Impact**: Latency/Throughput Design & Scalability score severely affected

---

### C3: No Monitoring & Observability Strategy

**Issue**: Section 6 includes logging strategy (SLF4J + Logback, request ID tracking) but **monitoring and observability are completely absent**:

- No performance metrics collection strategy (response time, throughput, error rate tracking)
- No alerting thresholds or incident detection (e.g., "p95レスポンスが1秒超過でアラート")
- No distributed tracing design despite multi-component architecture (ALB → API Gateway → Application Server → PostgreSQL/Redis/S3)
- No database performance monitoring (query execution time, connection pool usage)

**Impact**:
- Performance degradation goes undetected until user complaints
- Cannot diagnose bottlenecks in multi-layer architecture (API slow due to DB? Network? Application logic?)
- Auto-scaling based on CPU alone may miss memory leaks, connection pool exhaustion, or I/O bottlenecks
- No data to validate capacity planning assumptions or optimize resource allocation

**Recommendations**:
1. Implement distributed tracing:
   - Use AWS X-Ray or OpenTelemetry to trace requests across ALB → API Gateway → ECS → PostgreSQL
   - Correlate with X-Request-ID for end-to-end visibility
2. Define performance metrics and alerting:
   - Application: API response time (p50/p95/p99), throughput, error rate per endpoint
   - Database: Query execution time, connection pool utilization, slow query log (>1s)
   - Infrastructure: ECS CPU/memory per task, ALB latency, Redis hit rate
   - Alerting thresholds: p95 > SLA threshold, error rate > 1%, connection pool > 80%
3. Implement dashboard for real-time monitoring (CloudWatch Dashboard or Grafana)
4. Establish performance baseline during load testing and set regression alerts

**Severity**: **CRITICAL** - Blind operation without monitoring leads to undetected outages and poor user experience

**Score Impact**: All criteria affected; most severely Latency/Throughput Design & Scalability

---

## Significant Issues (Priority 2)

### S1: Database Scalability Strategy Missing

**Issue**: PostgreSQL is designated as "メインDB" but lacks scalability design for expected growth:

- No read/write separation strategy (read replicas for診察履歴取得 etc.)
- No sharding or partitioning strategy for growing appointments/medical_records tables
- No database connection pooling configuration (pool size, timeout, max connections)
- Index design is absent despite foreign key-heavy schema (appointments has patient_id, doctor_id FKs)

**Impact**:
- As appointment and medical record data accumulates, query performance degrades
- Read-heavy endpoints (診察履歴一覧取得, 予約一覧取得) may overwhelm single PostgreSQL instance
- Write bottleneck during peak appointment creation (朝8-9時) as all writes go to single primary
- Missing indexes on frequently queried columns (e.g., appointments.appointment_date, appointments.status) cause full table scans

**Recommendations**:
1. **Read/Write Separation**:
   - Deploy PostgreSQL read replicas for read-heavy endpoints (GET /api/medical-records, GET /api/appointments lists)
   - Configure Spring Data JPA with @Transactional(readOnly=true) to route read queries to replicas
2. **Indexing Strategy**:
   - Add composite index on appointments(doctor_id, appointment_date, status) for "医師の日別予約一覧取得"
   - Add index on appointments(patient_id, status) for "患者の予約一覧取得"
   - Add index on medical_records(patient_id, created_at DESC) for "診察履歴一覧取得"
3. **Partitioning for Growth**:
   - Partition appointments table by appointment_date (monthly or quarterly) to manage growth
   - Archive old medical_records (>5 years) to separate cold storage table
4. **Connection Pooling**:
   - Configure HikariCP (Spring Boot default): pool size based on (CPU cores × 2) + effective_spindle_count
   - Set connection timeout, max lifetime, and leak detection thresholds

**Severity**: **SIGNIFICANT** - Database bottleneck will emerge as data grows; planning required before production

**Score Impact**: I/O & Network Efficiency, Latency/Throughput Design & Scalability

---

### S2: Potential N+1 Query Problem in Appointment Retrieval

**Issue**: API endpoint `GET /api/appointments?patient_id={id}` likely suffers N+1 query problem:

- Appointments table has foreign keys to patients, doctors
- Typical implementation fetches appointments list, then queries doctors table N times for doctor details
- No mention of eager loading or JOIN FETCH strategy in ORM configuration

**Impact**:
- A patient with 20 appointments triggers 1 appointment query + 20 doctor queries (21 total)
- Latency increases linearly with appointment count
- Database load multiplies unnecessarily during list retrieval
- Particularly problematic for "医師の日別予約一覧取得" which may return 50+ appointments

**Recommendations**:
1. Use JPA JOIN FETCH in repository query:
   ```java
   @Query("SELECT a FROM Appointment a JOIN FETCH a.doctor WHERE a.patientId = :patientId")
   List<Appointment> findByPatientIdWithDoctor(@Param("patientId") Long patientId);
   ```
2. Configure FetchType.LAZY for associations and use DTOs with explicit JOIN FETCH only when needed
3. Consider API design: if doctor details are not always needed, separate endpoints or use GraphQL-style field selection
4. Monitor query count in integration tests to detect N+1 regressions

**Severity**: **SIGNIFICANT** - Common ORM pitfall that significantly degrades response time

**Score Impact**: I/O & Network Efficiency, Algorithm & Data Structure Efficiency

---

### S3: No Rate Limiting or Circuit Breaker Design

**Issue**: NFR section mentions "最大500セッション" but lacks protective mechanisms:

- No rate limiting per user or per endpoint to prevent abuse or runaway clients
- No circuit breaker for external dependencies (Amazon SNS for notifications)
- No timeout configuration for downstream calls (DB query timeout, SNS publish timeout)
- No backpressure handling if notification queue grows

**Impact**:
- Single malicious or buggy client can exhaust connection pool by sending 1000 req/sec
- If SNS experiences outage, appointment creation may hang indefinitely waiting for notification
- Cascading failures: slow notification service blocks application threads, causing timeout on all endpoints
- No protection against "retry storm" if clients aggressively retry failed requests

**Recommendations**:
1. **API Rate Limiting**:
   - Implement per-user rate limits (e.g., 10 req/sec per user, 100 req/min per IP)
   - Use Spring Cloud Gateway rate limiter or AWS ALB-level rate limiting
2. **Circuit Breaker for External Services**:
   - Use Resilience4j circuit breaker for NotificationService → SNS calls
   - Circuit opens after 50% failure rate over 10 requests, prevent further SNS calls for 30s
   - Fallback: log notification failure and queue for retry, but allow appointment creation to succeed
3. **Timeout Configuration**:
   - Database query timeout: 5s for writes, 3s for reads
   - SNS publish timeout: 2s (notifications should not block appointment creation)
   - HTTP client timeout for any future external APIs: connection 1s, read 3s
4. **Backpressure & Queue Limits**:
   - If notification queue exceeds 1000 messages, reject new appointment creation with 503 Service Unavailable
   - Monitor queue depth and alert if exceeds 500

**Severity**: **SIGNIFICANT** - Essential for system stability under adverse conditions

**Score Impact**: Latency/Throughput Design & Scalability, Memory & Resource Management

---

### S4: Session Management Strategy Unclear

**Issue**: Redis is designated as "セッションストア" but session management design is incomplete:

- No specification of session data size, TTL, or eviction policy
- No justification for Redis vs. stateless JWT-only design
- JWT has 24-hour validity, but unclear if Redis session is separate or redundant
- No session persistence strategy if Redis fails (failover, backup)

**Impact**:
- If session data grows large (storing full patient context), Redis memory may be exhausted
- 500 concurrent sessions × 10KB per session = 5MB (trivial), but if session stores medical history cache, could balloon
- If Redis evicts sessions prematurely, users experience unexpected logout despite valid JWT
- Single Redis instance is single point of failure for session state

**Recommendations**:
1. **Clarify Session Strategy**:
   - If using stateless JWT, eliminate Redis session store to simplify architecture
   - If storing server-side session (e.g., for security - ability to revoke tokens), document what data is stored and why
2. **Redis Configuration**:
   - Set explicit TTL for session keys (align with JWT 24-hour validity)
   - Configure eviction policy: noeviction (fail writes when full) or allkeys-lru (least-recently-used)
   - Estimate max memory: 500 sessions × expected session size + 50% buffer
3. **High Availability**:
   - Use Amazon ElastiCache for Redis with Multi-AZ replication for automatic failover
   - Implement session read fallback: if Redis miss, validate JWT and recreate session

**Severity**: **SIGNIFICANT** - Session management confusion risks security (cannot revoke tokens) or performance (unnecessary Redis dependency)

**Score Impact**: Memory & Resource Management, Caching Strategy

---

## Moderate Issues (Priority 3)

### M1: Missing Index on appointments.status

**Issue**: Appointment queries likely filter by status frequently (e.g., "active appointments only, exclude cancelled") but no index on status column is specified.

**Impact**:
- Query like `SELECT * FROM appointments WHERE patient_id = ? AND status = 'scheduled'` performs index scan on patient_id, then filters status in application layer
- For patients with long appointment history (50+ entries, including cancelled/completed), unnecessary data transfer and filtering overhead

**Recommendations**:
- Add composite index on (patient_id, status) or (doctor_id, status) depending on query patterns
- Alternatively, create partial index: `CREATE INDEX idx_active_appointments ON appointments(patient_id) WHERE status = 'scheduled';`

**Severity**: MODERATE - Affects users with long history; less critical than system-wide issues

**Score Impact**: I/O & Network Efficiency

---

### M2: No Asynchronous Processing for Notifications

**Issue**: Dataflow (Section 3) indicates notification sending is synchronous:
- Step 5: "NotificationServiceが確認メールを送信" occurs after Step 4 (save to DB)
- No mention of message queue or async processing

**Impact**:
- If SNS publish takes 500ms, appointment creation latency includes this delay
- If SNS is slow or unavailable, user waits unnecessarily for non-critical notification
- Notification failure causes entire appointment creation to fail (unless explicitly handled)

**Recommendations**:
1. Use asynchronous processing for notifications:
   - After saving appointment, publish event to SQS queue
   - Separate NotificationWorker (ECS task or Lambda) consumes queue and sends SNS
   - Appointment API returns immediately after DB save
2. Implement retry logic in worker with exponential backoff
3. Monitor notification queue depth and delivery success rate

**Severity**: MODERATE - Improves user experience but workaround exists (fast SNS usually)

**Score Impact**: Latency/Throughput Design & Scalability

---

### M3: No Caching for Available Slots Query

**Issue**: `GET /api/schedules/available-slots?doctor_id={id}&date={date}` is likely read frequently (patients browsing appointment times) but no caching strategy is mentioned.

**Impact**:
- Each patient browsing available slots triggers fresh database query
- During peak hours (multiple patients booking simultaneously), same doctor's slots queried repeatedly
- Modest latency increase and database load

**Recommendations**:
1. Cache available slots in Redis with short TTL (1-5 minutes):
   - Key: `available_slots:{doctor_id}:{date}`
   - Value: JSON array of time slots
   - TTL: 1 minute (balance freshness vs. cache hit rate)
2. Invalidate cache on appointment creation/cancellation for affected doctor/date
3. Implement cache-aside pattern: check Redis first, miss → query DB + populate cache

**Severity**: MODERATE - Performance improvement opportunity, not critical bottleneck

**Score Impact**: Caching Strategy, I/O & Network Efficiency

---

### M4: JWT Refresh Token Strategy Not Detailed

**Issue**: Section 5 mentions "リフレッシュトークンによる自動更新機能あり" but no design details:
- Where is refresh token stored? (HttpOnly cookie, localStorage)
- How is refresh token validated? (database lookup, separate JWT)
- What is refresh token TTL and rotation strategy?

**Impact**:
- If refresh token stored in localStorage, vulnerable to XSS
- If refresh token never expires, cannot revoke long-term access
- If refresh logic requires database query per API call, performance overhead

**Recommendations**:
1. Store refresh token in HttpOnly, Secure cookie to prevent XSS
2. Use separate refresh token with longer TTL (7 days) and rotation on use
3. Implement refresh endpoint `/api/auth/refresh` that validates refresh token and issues new access token
4. Monitor refresh token usage to detect anomalies (e.g., same refresh token used from multiple IPs)

**Severity**: MODERATE - Security-performance tradeoff; needs clarification

**Score Impact**: Memory & Resource Management (if DB-based validation)

---

## Minor Improvements (Priority 4)

### I1: Consider Batch API for Multiple Appointment Retrieval

If future features require retrieving multiple appointments by ID (e.g., bulk operations), consider batch endpoint `POST /api/appointments/batch` to reduce round trips.

**Score Impact**: I/O & Network Efficiency (+0.5)

---

### I2: Document Retry and Idempotency Strategy

For appointment creation, specify idempotency key design (e.g., patient_id + doctor_id + appointment_date + time_slot) to allow safe retries without duplicate appointments.

**Score Impact**: I/O & Network Efficiency (+0.5)

---

### I3: Consider Read-Through Cache for Patient/Doctor Master Data

Patient and doctor entities are read frequently but change rarely. Implement read-through cache in Redis with longer TTL (1 hour) to reduce database load.

**Score Impact**: Caching Strategy (+0.5)

---

## Positive Aspects

1. **Auto-scaling Configuration**: ECS auto-scaling at 70% CPU threshold demonstrates awareness of dynamic load handling
2. **JWT Authentication**: Stateless authentication reduces session management overhead
3. **Health Check Endpoint**: `/actuator/health` enables proper load balancer health checks for availability
4. **Request ID Tracking**: X-Request-ID in MDC facilitates distributed debugging
5. **Blue-Green Deployment**: Reduces deployment risk and enables fast rollback

---

## Score Summary

| Evaluation Criterion | Score | Justification |
|----------------------|-------|---------------|
| **1. Algorithm & Data Structure Efficiency** | **3/5** | Foreign key-heavy schema without comprehensive index design. Potential N+1 query problem in ORM usage. No evidence of inappropriate algorithm choices, but optimization opportunities exist. |
| **2. I/O & Network Efficiency** | **2/5** | **Critical**: No database read/write separation for read-heavy workload. Likely N+1 queries in appointment retrieval. Missing index on frequently queried columns. Synchronous notification processing blocks API response. |
| **3. Caching Strategy** | **2/5** | Redis session store exists but purpose unclear (conflicts with stateless JWT claim). No caching for frequently-read data (available slots, patient/doctor master). No cache invalidation strategy documented. |
| **4. Memory & Resource Management** | **3/5** | Connection pooling not configured (Spring Boot defaults may suffice but not validated). Session size and eviction policy undefined. No resource leak prevention strategy documented beyond standard Spring practices. |
| **5. Latency, Throughput Design & Scalability** | **1/5** | **CRITICAL**: No capacity planning, performance SLA, or monitoring strategy. Auto-scaling threshold (70% CPU) has no validation basis. No rate limiting or circuit breaker for stability. Concurrent session target (500) lacks rationale. Database scalability plan absent. |

**Overall Weighted Score: 2.2/5**

(Weighted average: Criteria 2, 5 double-weighted due to severity)

---

## Summary of Recommendations by Priority

### Immediate Action Required (Before Production):
1. **Define capacity planning and performance SLAs** (C1, C2)
2. **Implement monitoring and distributed tracing** (C3)
3. **Design database scalability strategy** (S1): read replicas, indexing, connection pooling
4. **Add rate limiting and circuit breakers** (S3)

### High Priority (First Post-Launch Iteration):
5. **Fix N+1 query problems with JOIN FETCH** (S2)
6. **Clarify session management strategy** (S4)
7. **Implement async notification processing** (M2)

### Medium Priority (Performance Optimization):
8. **Add caching for available slots** (M3)
9. **Create composite indexes** (M1)
10. **Document JWT refresh token security** (M4)

---

## Conclusion

The design document demonstrates foundational understanding of scalable architecture (ECS auto-scaling, stateless design, layered architecture) but **lacks critical non-functional requirements specification**. The absence of capacity planning, performance SLAs, and monitoring strategy creates unacceptable risk for production deployment.

**Key strengths**: Modern tech stack, awareness of horizontal scaling, health check design
**Key weaknesses**: No NFR foundation (capacity, SLA, observability), database scalability gaps, missing protective mechanisms (rate limiting, circuit breakers)

**Recommendation**: **Do not proceed to implementation** until NFR section is substantially expanded with capacity planning, performance targets, monitoring strategy, and database optimization design. Current design is **60% complete** for production readiness.
