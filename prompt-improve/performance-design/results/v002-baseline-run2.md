# Performance Design Review: Online Medical Appointment System

## Executive Summary

This performance review evaluates the architectural design of an online medical appointment system serving regional healthcare facilities. The system targets 500 concurrent sessions with 99.5% availability. The analysis identifies **3 critical issues**, **4 significant issues**, and **2 moderate issues** that could impact system performance, latency, and scalability.

---

## Critical Issues

### C1. N+1 Query Problem in Appointment List Retrieval

**Severity**: Critical
**Criterion**: I/O & Network Efficiency
**Score**: 2/5

**Issue Description**:
The API endpoint `GET /api/appointments?patient_id={id}` retrieves appointment lists but lacks explicit join strategy documentation. With Spring Data JPA's default LAZY loading, this will trigger N+1 queries when accessing related doctor and patient information during list operations.

**Impact Analysis**:
- Each appointment record requires 2 additional queries (doctor, patient lookup)
- For a patient with 10 appointments: 1 (initial) + 20 (N+1) = 21 database round trips
- At 500 concurrent sessions, database connection pool exhaustion becomes likely
- Response latency increases linearly with appointment count
- Database CPU utilization spikes during peak hours

**Optimization Recommendations**:
1. Implement explicit JOIN FETCH in repository queries:
   ```java
   @Query("SELECT a FROM Appointment a JOIN FETCH a.doctor JOIN FETCH a.patient WHERE a.patient.id = :patientId")
   ```
2. Use Entity Graphs for complex fetch strategies
3. Consider DTO projections for list views to fetch only required fields
4. Add database query monitoring to detect N+1 patterns in production

**Reference**: Section 5 (API Design) - `/api/appointments` endpoints

---

### C2. Missing Database Indexing Strategy

**Severity**: Critical
**Criterion**: Latency, Throughput Design & Scalability
**Score**: 2/5

**Issue Description**:
The data model (Section 4) defines table schemas but does not specify any indexing strategy beyond primary keys. Critical query patterns lack index support:
- `appointments.patient_id` (frequent patient appointment lookups)
- `appointments.doctor_id` + `appointment_date` (daily schedule queries)
- `appointments.status` (status-based filtering)
- `medical_records.patient_id` (patient history retrieval)

**Impact Analysis**:
- Full table scans on appointment queries as data grows
- O(n) query performance degradation proportional to appointment count
- At 10,000 appointments, unindexed patient_id lookup scans entire table
- Response time increases from milliseconds to seconds
- Database CPU bottleneck prevents horizontal scaling
- Violates 99.5% availability target during peak load

**Optimization Recommendations**:
1. **Mandatory Indexes**:
   ```sql
   CREATE INDEX idx_appointments_patient_id ON appointments(patient_id);
   CREATE INDEX idx_appointments_doctor_date ON appointments(doctor_id, appointment_date);
   CREATE INDEX idx_appointments_status ON appointments(status);
   CREATE INDEX idx_medical_records_patient_id ON medical_records(patient_id);
   ```
2. Consider composite index for common filter combinations:
   ```sql
   CREATE INDEX idx_appointments_patient_status ON appointments(patient_id, status);
   ```
3. Add EXPLAIN ANALYZE monitoring for slow queries
4. Define index creation as part of migration scripts

**Reference**: Section 4 (Data Model)

---

### C3. Synchronous Email/SMS Notification Blocking Request Path

**Severity**: Critical
**Criterion**: Latency, Throughput Design & Scalability
**Score**: 2/5

**Issue Description**:
The data flow (Section 3) shows NotificationService sending confirmation emails synchronously within the appointment creation request path (Step 5). Amazon SNS API calls typically take 100-500ms, blocking the HTTP response.

**Impact Analysis**:
- Appointment creation latency increases by 100-500ms per notification
- SNS API timeout/throttling directly impacts user-facing response time
- At 500 concurrent sessions, SNS rate limits (default 30,000 SMS/day) may be reached
- Reduced throughput: server threads blocked waiting for external API
- Poor user experience: users wait for email delivery before seeing confirmation

**Optimization Recommendations**:
1. **Implement asynchronous notification processing**:
   - Add message queue (Amazon SQS) between AppointmentService and NotificationService
   - Return HTTP 201 immediately after database commit
   - Process notifications in background workers
2. **Architecture Pattern**:
   ```
   AppointmentService → (publish event) → SQS Queue
                                             ↓
                                       Notification Worker (polls queue)
                                             ↓
                                         Amazon SNS
   ```
3. Add retry logic and dead-letter queue for failed notifications
4. Consider notification batching for efficiency

**Reference**: Section 3 (Data Flow), Section 2 (Technology Stack)

---

## Significant Issues

### S1. Missing Caching Strategy for Frequently Accessed Data

**Severity**: Significant
**Criterion**: Caching Strategy
**Score**: 2/5

**Issue Description**:
Redis is listed as a session store (Section 2) but the design lacks caching strategy for frequently accessed, rarely modified data:
- Doctor master data (name, specialty, clinic)
- Available time slots for upcoming dates
- Patient profile information
- Medical facility information

The `GET /api/schedules/available-slots` endpoint likely performs complex calculations on every request without caching.

**Impact Analysis**:
- Repeated database queries for identical doctor/schedule information
- Available slots calculation overhead on every user request
- Increased database load preventing effective horizontal scaling
- Wasted network bandwidth and response latency (50-100ms per uncached query)
- Poor resource utilization: computing same results repeatedly

**Optimization Recommendations**:
1. **Implement multi-layer caching**:
   - **Application cache**: Doctor/clinic master data (TTL: 1 hour, invalidate on update)
   - **Redis cache**: Available slots calculation (TTL: 5 minutes, key: `slots:{doctor_id}:{date}`)
   - **HTTP cache**: Public API responses with Cache-Control headers
2. **Cache invalidation strategy**:
   - Invalidate doctor cache on master data updates
   - Invalidate slot cache on appointment creation/cancellation
   - Use cache tags for bulk invalidation
3. **Implementation**:
   ```java
   @Cacheable(value = "doctor", key = "#doctorId")
   public Doctor getDoctorById(Long doctorId) { ... }

   @Cacheable(value = "availableSlots", key = "#doctorId + ':' + #date")
   public List<TimeSlot> getAvailableSlots(Long doctorId, LocalDate date) { ... }
   ```

**Reference**: Section 2 (Technology Stack - Redis), Section 5 (API Design)

---

### S2. Inadequate Connection Pooling Configuration

**Severity**: Significant
**Criterion**: Memory & Resource Management
**Score**: 3/5

**Issue Description**:
The design specifies PostgreSQL and Redis usage but does not define connection pool configuration. Default HikariCP settings may be insufficient for 500 concurrent sessions.

**Impact Analysis**:
- Connection pool exhaustion under peak load (default: 10 connections)
- Request queuing and timeout errors (default timeout: 30 seconds)
- Database connection overhead: repeated connection creation/teardown
- Cascading failures when pool is exhausted
- Unable to meet 99.5% availability target during traffic spikes

**Optimization Recommendations**:
1. **Define explicit connection pool configuration**:
   ```yaml
   spring:
     datasource:
       hikari:
         maximum-pool-size: 50  # Based on 500 sessions / ~10 requests per session
         minimum-idle: 10
         connection-timeout: 20000
         idle-timeout: 600000
         max-lifetime: 1800000
   ```
2. **Calculate pool size** based on Little's Law:
   - Connections = (500 sessions × 0.1 requests/sec × 0.1 sec avg query time) ≈ 50
3. Add connection pool monitoring metrics
4. Configure separate pools for read-replica if implementing read scaling

**Reference**: Section 2 (Technology Stack), Section 7 (Scalability)

---

### S3. Missing Rate Limiting and Request Throttling

**Severity**: Significant
**Criterion**: Latency, Throughput Design & Scalability
**Score**: 2/5

**Issue Description**:
The API design (Section 5) lacks rate limiting specification. Without throttling, malicious or misconfigured clients can overwhelm the system with appointment creation/query requests.

**Impact Analysis**:
- Vulnerability to resource exhaustion attacks
- Single user can consume all 500 session capacity
- Database and application server overload
- Degraded performance for legitimate users
- Inability to enforce fair resource allocation
- SLA violations during abuse scenarios

**Optimization Recommendations**:
1. **Implement token bucket rate limiting**:
   - Per-user limits: 100 requests/minute for general APIs
   - Appointment creation: 5 requests/minute per patient
   - Available slots query: 20 requests/minute per user
2. **Use Redis for distributed rate limiting**:
   ```java
   @RateLimiter(key = "#userId", rate = 100, duration = 60)
   public void handleRequest(Long userId) { ... }
   ```
3. Return HTTP 429 (Too Many Requests) with Retry-After header
4. Implement exponential backoff guidance in API documentation

**Reference**: Section 5 (API Design), Section 7 (Non-functional Requirements)

---

### S4. Lack of Database Query Timeout Configuration

**Severity**: Significant
**Criterion**: Memory & Resource Management
**Score**: 3/5

**Issue Description**:
The design does not specify query timeout settings for database operations. Long-running queries (e.g., unindexed appointment history scans) can hold connections indefinitely and exhaust the connection pool.

**Impact Analysis**:
- Single slow query blocks connection pool thread
- Cascading timeout errors as pool is exhausted
- Unable to cancel runaway queries
- Reduced system throughput during database performance degradation
- Difficult to diagnose performance issues without timeout boundaries

**Optimization Recommendations**:
1. **Configure statement timeout**:
   ```yaml
   spring:
     jpa:
       properties:
         javax.persistence.query.timeout: 10000  # 10 seconds
         hibernate.query.plan_cache_max_size: 512
   ```
2. Set connection-level timeout:
   ```properties
   spring.datasource.hikari.connection-timeout=5000
   spring.datasource.hikari.validation-timeout=3000
   ```
3. Implement circuit breaker pattern for database calls
4. Add slow query logging (queries > 1 second)

**Reference**: Section 2 (Technology Stack - PostgreSQL), Section 6 (Implementation Policy)

---

## Moderate Issues

### M1. Inefficient QR Code Generation Strategy

**Severity**: Moderate
**Criterion**: Algorithm & Data Structure Efficiency
**Score**: 3/5

**Issue Description**:
The design mentions "診察券QRコード発行" (medical card QR code issuance) but does not specify when/how QR codes are generated. Real-time generation on every appointment view would be inefficient.

**Impact Analysis**:
- CPU overhead for repeated QR encoding of identical data
- Increased response latency for appointment detail views (50-100ms per generation)
- Wasted computational resources generating same QR code multiple times
- Potential inconsistency if QR code format changes mid-appointment lifecycle

**Optimization Recommendations**:
1. **Generate QR code once at appointment creation**:
   - Store pre-generated QR code image URL in `appointments` table
   - Upload image to S3 during appointment creation
   - Return S3 URL in appointment response
2. **Alternative: Generate on-demand with caching**:
   - Cache QR code images in Redis (key: `qr:{appointment_id}`, TTL: 24 hours)
   - Generate only if cache miss
3. Consider using deterministic QR content (appointment_id + signature) for verification

**Reference**: Section 1 (Overview - Main Features)

---

### M2. Missing Pagination for List Endpoints

**Severity**: Moderate
**Criterion**: I/O & Network Efficiency
**Score**: 3/5

**Issue Description**:
API endpoints like `GET /api/appointments?patient_id={id}` and `GET /api/medical-records?patient_id={id}` do not specify pagination parameters. Without pagination, long-term patients with 100+ appointments will cause large result sets.

**Impact Analysis**:
- Unbounded memory allocation for large result sets
- Network bandwidth waste transmitting unnecessary data
- Poor client-side rendering performance with large arrays
- Database memory pressure from ORDER BY + full result set loading
- Increased response time proportional to patient history length

**Optimization Recommendations**:
1. **Implement cursor-based pagination**:
   ```
   GET /api/appointments?patient_id={id}&limit=20&cursor={last_id}
   ```
2. **Add pagination parameters**:
   - Default page size: 20 records
   - Maximum page size: 100 records
   - Return total count and pagination metadata
3. **Response format**:
   ```json
   {
     "data": [...],
     "pagination": {
       "next_cursor": "MTIzNDU2",
       "has_more": true,
       "total": 156
     }
   }
   ```
4. Add index on `created_at` for efficient cursor pagination

**Reference**: Section 5 (API Design - Appointment and Medical Records APIs)

---

## Positive Aspects

1. **Stateless Architecture**: ECS Fargate with horizontal scaling enables clean scalability model
2. **Appropriate Technology Choices**: PostgreSQL for transactional data, Redis for sessions shows sound architectural judgment
3. **Separation of Concerns**: Layered architecture (Presentation/Application/Domain/Infrastructure) supports maintainability
4. **Container-based Deployment**: Enables consistent environments and efficient resource utilization
5. **JWT Authentication**: Stateless token-based auth reduces session storage burden

---

## Evaluation Criteria Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 3/5 | QR code generation strategy undefined; otherwise acceptable |
| I/O & Network Efficiency | 2/5 | **Critical N+1 query problem, missing pagination, synchronous notifications** |
| Caching Strategy | 2/5 | **Redis underutilized; no application-level caching for master data or computed results** |
| Memory & Resource Management | 3/5 | **Connection pooling undefined, query timeouts missing; otherwise sound** |
| Latency, Throughput Design & Scalability | 2/5 | **Missing indexes, synchronous I/O blocking, no rate limiting; horizontal scaling architecture is positive** |

**Overall Performance Design Score**: 2.4/5

---

## Priority Action Items

1. **[CRITICAL]** Add database indexes for patient_id, doctor_id, appointment_date, status columns
2. **[CRITICAL]** Implement asynchronous notification processing with message queue
3. **[CRITICAL]** Fix N+1 query problems with explicit JOIN FETCH strategies
4. **[SIGNIFICANT]** Define connection pool configuration (50-100 connections for 500 sessions)
5. **[SIGNIFICANT]** Implement caching layer for doctor master data and available slots
6. **[SIGNIFICANT]** Add API rate limiting (per-user and per-endpoint)
7. **[MODERATE]** Add pagination to all list endpoints with default page size 20

---

## Conclusion

The system architecture shows solid foundational choices (stateless design, appropriate tech stack, layered architecture) but **lacks critical performance optimizations** required to meet the 99.5% availability and 500 concurrent session targets. The three critical issues (N+1 queries, missing indexes, synchronous I/O) will cause severe performance degradation under production load and **must be addressed before deployment**.

The significant issues (caching, connection pooling, rate limiting, timeouts) impact scalability and resilience but are addressable through configuration and middleware additions. With the recommended optimizations implemented, the system can achieve the stated performance requirements.
