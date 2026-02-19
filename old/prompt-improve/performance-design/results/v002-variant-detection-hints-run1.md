# Performance Design Review: オンライン診療予約システム

**Review Date**: 2026-02-11
**Reviewer**: performance-design-reviewer (v002-variant-detection-hints)
**Document**: test-document-round-002.md

---

## Executive Summary

This design document describes an online medical appointment system with significant **architectural performance gaps** that could lead to scalability issues, user experience degradation, and operational difficulties. The most critical concerns are:

1. **No database read/write separation** - All read/write traffic hits a single PostgreSQL instance with no read replica strategy
2. **Inadequate capacity planning** - 500 concurrent sessions is insufficient for multi-clinic operations during peak hours
3. **Missing monitoring and alerting strategy** - No performance metrics, SLA tracking, or proactive issue detection
4. **N+1 query risk** - JPA usage without explicit batch fetching or query optimization strategy
5. **No caching strategy** - Frequently accessed data (doctor schedules, available slots) retrieved from database on every request

---

## Performance Evaluation by Criterion

### 1. Algorithm & Data Structure Efficiency: 3/5

**Score Justification**: The design uses appropriate relational modeling with foreign keys and indexes implied, but lacks explicit discussion of query optimization strategies and index design for critical access patterns.

**Issues Identified**:

**P01 - No explicit index design for critical queries** (Moderate)
- The appointments table will be frequently queried by `(patient_id, appointment_date)`, `(doctor_id, appointment_date)`, and `status`
- No composite indexes are specified for these access patterns
- **Impact**: Full table scans on appointments table as data grows beyond 10,000 records
- **Recommendation**: Define composite indexes:
  ```sql
  CREATE INDEX idx_appointments_patient_date ON appointments(patient_id, appointment_date);
  CREATE INDEX idx_appointments_doctor_date ON appointments(doctor_id, appointment_date);
  CREATE INDEX idx_appointments_status ON appointments(status) WHERE status = 'scheduled';
  ```

**P02 - Potential inefficiency in available slot calculation** (Moderate)
- `GET /api/schedules/available-slots` endpoint must compute availability by comparing doctor schedules against existing appointments
- No algorithm described for this critical operation
- **Impact**: If implemented naively (fetch all doctor's appointments, then compute gaps), performance degrades as appointment history grows
- **Recommendation**: Pre-compute available slots and cache them, or use database-level set operations with appropriate indexes

**Positive Aspects**:
- Appropriate use of AUTO_INCREMENT for primary keys
- Reasonable data type choices (BIGINT for IDs, DATE/TIME for temporal data)

---

### 2. I/O & Network Efficiency: 2/5

**Score Justification**: Critical N+1 query risks with JPA/Hibernate usage and no batch processing strategy for common operations. No optimization for network round-trips.

**Issues Identified**:

**P03 - N+1 query problem with JPA lazy loading** (Critical)
- The design specifies Spring Data JPA (Hibernate) but provides no fetch strategy
- Endpoints like `GET /api/appointments?patient_id={id}` will fetch appointments, then lazy-load related `doctor` and `clinic` data
- **Impact**: For a patient with 50 appointments, this generates 1 query for appointments + 50 queries for doctors + 50 queries for clinics = 101 database round-trips
- **Recommendation**:
  - Use `@EntityGraph` or JPQL `JOIN FETCH` for appointment list queries
  - Define DTOs with explicit projections to avoid loading unnecessary associations
  - Example: `SELECT a, d, c FROM Appointment a JOIN FETCH a.doctor d JOIN FETCH d.clinic c WHERE a.patient_id = :patientId`

**P04 - No batch processing for notification sending** (Significant)
- NotificationService sends confirmation emails/SMS individually via Amazon SNS
- Reminder notifications likely iterate through upcoming appointments and send one-by-one
- **Impact**: For 1,000 daily appointments, this generates 1,000 individual SNS API calls with network latency overhead
- **Recommendation**:
  - Batch notifications into groups (e.g., 100 messages per batch)
  - Use SNS `PublishBatch` API (up to 10 messages per call)
  - Implement async queue (SQS) to decouple notification sending from booking flow

**P05 - No database connection pooling configuration** (Moderate)
- The design mentions "connection pooling" in resource management context but provides no configuration
- Default Spring Boot HikariCP settings may be inadequate for 500 concurrent sessions
- **Impact**: Connection exhaustion during peak load, causing request timeouts
- **Recommendation**: Explicitly configure:
  ```yaml
  spring.datasource.hikari:
    maximum-pool-size: 50
    minimum-idle: 10
    connection-timeout: 30000
    idle-timeout: 600000
  ```

---

### 3. Caching Strategy: 1/5

**Score Justification**: No caching strategy is defined despite clear candidates for caching (doctor schedules, clinic data, available slots). Redis is mentioned only for session storage.

**Issues Identified**:

**P06 - No caching for frequently accessed reference data** (Critical)
- Doctor and clinic information is read-heavy and changes infrequently
- `GET /api/schedules/available-slots` likely hits the database on every request
- **Impact**: Database becomes bottleneck during peak hours (morning appointment rush)
- **Recommendation**:
  - Cache doctor/clinic data in Redis with 1-hour TTL
  - Cache available slots for next 7 days with 15-minute TTL
  - Invalidate slot cache when appointments are created/cancelled
  ```java
  @Cacheable(value = "availableSlots", key = "#doctorId + '-' + #date")
  public List<TimeSlot> getAvailableSlots(Long doctorId, LocalDate date)
  ```

**P07 - Inefficient session management** (Moderate)
- Redis used for "session store" but JWT tokens are also mentioned (24-hour validity)
- Unclear if Redis is used for token validation on every request
- **Impact**: If every API call validates JWT against Redis, this adds 5-10ms latency per request
- **Recommendation**:
  - Use stateless JWT validation (signature verification) for most endpoints
  - Only check Redis for logout/revocation scenarios
  - Cache user permissions in JWT claims to avoid database lookups

---

### 4. Memory & Resource Management: 3/5

**Score Justification**: Basic resource lifecycle is mentioned but lacks specifics on memory optimization, large result set handling, and resource cleanup patterns.

**Issues Identified**:

**P08 - No pagination strategy for list endpoints** (Significant)
- `GET /api/medical-records?patient_id={id}` returns all historical records for a patient
- Long-term patients may accumulate hundreds of records
- **Impact**: Memory exhaustion on application server when loading large result sets into memory
- **Recommendation**:
  - Implement cursor-based pagination: `GET /api/medical-records?patient_id={id}&limit=20&after={cursor}`
  - Add database-level LIMIT/OFFSET with streaming results
  - Set maximum result set size (e.g., 100 records per page)

**P09 - No file upload size limits or streaming for S3** (Moderate)
- S3 mentioned for "image storage" but no details on upload handling
- If diagnostic images are uploaded through application server, large files consume memory
- **Impact**: 10MB image upload × 50 concurrent users = 500MB memory pressure
- **Recommendation**:
  - Implement presigned S3 URLs for direct client-to-S3 uploads
  - Set maximum file size limit (e.g., 10MB)
  - Use streaming upload instead of buffering entire file in memory

**Positive Aspects**:
- Connection pooling mentioned (though not configured)
- Proper use of TIMESTAMP for audit fields

---

### 5. Latency, Throughput Design & Scalability: 2/5

**Score Justification**: The design includes horizontal scaling via ECS, but lacks critical components: read replica strategy, capacity planning for expected load, monitoring/alerting, and asynchronous processing patterns.

**Issues Identified**:

**P10 - No database read/write separation** (Critical)
- Single PostgreSQL instance handles all read and write traffic
- Medical records and appointment history queries compete with booking transactions
- **Impact**: Write transactions block read queries during peak hours; database becomes single point of bottleneck
- **Recommendation**:
  - Implement PostgreSQL read replicas (at least 2 for high availability)
  - Route read-heavy queries (`GET /api/medical-records`, historical appointments) to replicas
  - Use write-through caching for frequently accessed data to reduce read replica load

**P11 - Inadequate capacity planning** (Critical)
- "Maximum 500 concurrent sessions" is specified, but no analysis of expected load
- Regional healthcare system serving multiple clinics could easily exceed this during morning hours (8-10 AM)
- **Impact**: Users experience 503 errors or extreme latency during peak hours; lost revenue and poor user experience
- **Recommendation**:
  - Perform capacity analysis: Calculate expected concurrent users based on clinic count × avg daily appointments
  - Plan for 3-5× headroom above average load
  - Define auto-scaling policy: Scale out at 50% CPU, scale in at 20% CPU (not 70% which is too late)

**P12 - Missing monitoring and alerting strategy** (Critical)
- No mention of performance metrics, SLA tracking, or alerting
- "99.5% availability" SLA defined but no monitoring to verify it
- **Impact**: Performance degradation goes undetected until users complain; no data-driven optimization
- **Recommendation**:
  - Implement CloudWatch metrics for:
    - P95/P99 API latency per endpoint
    - Database connection pool utilization
    - ECS task CPU/memory usage
    - Error rate (4xx/5xx responses)
  - Set alerts for:
    - P95 latency > 500ms
    - Error rate > 1%
    - Database connection pool > 80% utilized
  - Dashboard for business metrics: appointments/hour, cancellation rate

**P13 - No asynchronous processing for non-critical operations** (Significant)
- Notification sending blocks appointment creation flow
- QR code generation likely synchronous
- **Impact**: User waits for email sending latency (200-500ms) during booking flow
- **Recommendation**:
  - Decouple notification sending via SQS message queue
  - Return appointment confirmation immediately, send notifications asynchronously
  - Implement retry logic for failed notifications (exponential backoff)

**P14 - No query timeout configuration** (Moderate)
- Long-running queries (e.g., misconfigured medical record search) could hold database connections indefinitely
- **Impact**: Connection pool exhaustion if slow queries accumulate
- **Recommendation**:
  - Set statement timeout: `spring.jpa.properties.hibernate.query.timeout: 10000` (10 seconds)
  - Implement circuit breaker for external services (SNS notifications)

**Positive Aspects**:
- Horizontal scaling capability via ECS Fargate
- Stateless application design (suitable for scaling)
- Blue-green deployment strategy reduces downtime

---

## Critical Issue Summary

The following **critical issues** must be addressed before production deployment:

1. **P10 - No database read/write separation**: Implement read replicas immediately
2. **P11 - Inadequate capacity planning**: Re-evaluate concurrent session limits and scaling thresholds
3. **P12 - Missing monitoring and alerting**: Implement comprehensive observability before launch
4. **P06 - No caching for frequently accessed data**: Add caching layer for doctor schedules and available slots
5. **P03 - N+1 query problem**: Define explicit fetch strategies for all list endpoints

These issues, if left unaddressed, will cause:
- **User experience degradation** during peak hours (morning appointment rush)
- **Database bottleneck** under moderate load (>200 concurrent users)
- **Inability to detect and respond** to performance issues proactively
- **Scalability ceiling** far below expected growth trajectory

---

## Recommendations Summary

### Immediate Actions (Pre-Launch)
1. Implement PostgreSQL read replicas and route read queries appropriately
2. Add Redis caching for doctor/clinic data and available slots
3. Configure database connection pool sizing and statement timeouts
4. Define composite indexes for critical query patterns
5. Implement comprehensive monitoring and alerting (CloudWatch metrics)

### Short-Term Improvements (Post-Launch)
6. Add pagination to all list endpoints
7. Implement asynchronous notification processing via SQS
8. Use SNS batch APIs for notification sending
9. Optimize JPA fetch strategies to prevent N+1 queries
10. Implement presigned S3 URLs for direct uploads

### Long-Term Optimizations (6-12 months)
11. Consider database sharding strategy if multi-clinic growth exceeds 100 clinics
12. Evaluate CDC (Change Data Capture) for real-time cache invalidation
13. Implement GraphQL for flexible client-driven queries (reduce overfetching)

---

## Overall Performance Assessment

**Overall Score: 2.5/5** (Significant performance risks that must be addressed)

The design demonstrates basic understanding of modern web application architecture (microservices, horizontal scaling, JWT authentication), but **lacks critical performance engineering components** necessary for a production healthcare system.

The most concerning gap is the **absence of a monitoring and observability strategy**—without metrics and alerting, the team will be unable to validate the 99.5% SLA or detect performance degradation before it impacts users.

The **single-database bottleneck** (no read replicas) and **lack of caching** will limit scalability far below the stated 500-concurrent-session target, especially during peak hours when patients rush to book morning appointments.

**Recommendation**: Conduct a performance testing phase with realistic load profiles before production launch. Use tools like JMeter or Gatling to simulate 500+ concurrent users and identify bottlenecks empirically.
