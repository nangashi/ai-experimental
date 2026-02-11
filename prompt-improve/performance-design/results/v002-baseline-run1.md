# Performance Design Review: オンライン診療予約システム

## Overall Assessment

This design document presents a medical appointment booking system with a standard three-tier architecture using Spring Boot and PostgreSQL. While the basic architecture is sound, several critical performance bottlenecks and scalability limitations have been identified that could significantly impact system performance under production load.

## Critical Issues

### 1. N+1 Query Problem in Appointment Listings

**Severity: Critical**

**Location:** Section 5 (API Design) - `GET /api/appointments?patient_id={id}` and `GET /api/appointments?doctor_id={id}&date={date}`

**Issue:**
The design uses Spring Data JPA (Hibernate) but does not specify fetch strategies for related entities. The appointment listing endpoints will likely trigger N+1 queries when loading patient, doctor, and potentially medical record associations.

**Impact:**
- For a patient with 20 appointments, this could result in 1 + 20 + 20 = 41 database queries instead of 1-2 optimized queries
- Under load (500 concurrent sessions), this multiplies database connection usage unnecessarily
- Latency increases linearly with the number of appointments returned

**Recommendation:**
- Explicitly specify `JOIN FETCH` or `@EntityGraph` for appointment list queries
- Define DTOs with only required fields to avoid lazy loading cascades
- Document the fetch strategy in Section 6 (Implementation Guidelines)

**Score Impact:** I/O & Network Efficiency: 2/5

---

### 2. Real-time Availability Check Without Optimistic Locking

**Severity: Critical**

**Location:** Section 3 (Architecture Design) - AppointmentService data flow, Section 4 (Data Model) - appointments table

**Issue:**
The data flow describes "checking appointment availability" before saving, but the appointments table lacks version control or optimistic locking columns. Under concurrent load, multiple users could check availability simultaneously for the same time slot and create duplicate bookings.

**Impact:**
- Race condition window between availability check and insert
- Double-booking probability increases with concurrent users
- System cannot handle 500 concurrent sessions reliably without explicit concurrency control
- Database integrity violations or business logic failures

**Recommendation:**
- Add `version` column (BIGINT) to appointments table for optimistic locking
- Implement `@Version` annotation in JPA entity
- Add unique constraint on `(doctor_id, appointment_date, time_slot)` to enforce database-level prevention
- Handle `OptimisticLockException` with user-friendly retry messaging

**Score Impact:** Latency, Throughput Design & Scalability: 2/5

---

### 3. Missing Database Indexing Strategy

**Severity: Critical**

**Location:** Section 4 (Data Model) - All entity tables

**Issue:**
The data model defines table structures but provides no indexing strategy. Critical query patterns are not supported by indexes:
- `appointments` table: no index on `(doctor_id, appointment_date)` for schedule lookups
- `appointments` table: no index on `(patient_id, appointment_date)` for patient history
- `medical_records` table: no index on `patient_id` for history retrieval
- `doctors` table: no index on `clinic_id` for clinic-based queries

**Impact:**
- Full table scans on appointment lookups (O(n) instead of O(log n))
- Query performance degrades proportionally with data growth
- As appointment records accumulate (thousands per month), response times will increase from milliseconds to seconds
- The 99.5% availability target becomes unachievable under growth

**Recommendation:**
- Add composite index: `CREATE INDEX idx_appointments_doctor_date ON appointments(doctor_id, appointment_date, time_slot)`
- Add composite index: `CREATE INDEX idx_appointments_patient ON appointments(patient_id, appointment_date DESC)`
- Add index: `CREATE INDEX idx_medical_records_patient ON medical_records(patient_id, created_at DESC)`
- Add index: `CREATE INDEX idx_doctors_clinic ON doctors(clinic_id)`
- Document index maintenance strategy in Section 6

**Score Impact:** Algorithm & Data Structure Efficiency: 2/5

---

## Significant Issues

### 4. Inefficient Available Slots Calculation

**Severity: Significant**

**Location:** Section 5 (API Design) - `GET /api/schedules/available-slots?doctor_id={id}&date={date}`

**Issue:**
The available slots endpoint likely calculates availability by:
1. Fetching all possible time slots for the doctor (application logic)
2. Fetching all existing appointments for the date (database query)
3. Computing the difference in application memory

This approach requires full data transfer and application-side computation for every availability check.

**Impact:**
- High CPU usage on application server for simple set operations
- Unnecessary data transfer from database to application
- Cannot leverage database query optimization
- Scales poorly when users browse multiple dates or multiple doctors

**Recommendation:**
- Pre-generate time slots in a `schedule_slots` table with status flags
- Update slot status atomically during appointment creation/cancellation
- Use database query to filter available slots: `SELECT * FROM schedule_slots WHERE doctor_id = ? AND date = ? AND status = 'available'`
- Alternative: Use database query with `NOT EXISTS` subquery to compute availability server-side

**Score Impact:** Algorithm & Data Structure Efficiency: 3/5, I/O & Network Efficiency: 2/5

---

### 5. Missing Caching Layer for Reference Data

**Severity: Significant**

**Location:** Section 2 (Technology Stack) - Redis is used only for session storage, Section 3 (Architecture Design) - Service layer design

**Issue:**
Redis is present in the stack but only used for session storage. Frequently accessed, read-heavy data is not cached:
- Doctor profiles and specialties (read-heavy, infrequently changed)
- Clinic information (read-heavy, rarely changed)
- Available time slot templates (read-heavy, semi-static)

Every API request fetches this reference data from PostgreSQL, increasing database load unnecessarily.

**Impact:**
- Unnecessary database load for read-heavy, rarely-changing data
- Increased query latency (Redis: ~1ms vs PostgreSQL: ~5-20ms)
- Database connection pool exhaustion under peak load
- Missed opportunity for 10-20x performance improvement on reference data queries

**Recommendation:**
- Implement read-through caching for doctor and clinic entities with 1-hour TTL
- Cache available slot templates per doctor with 24-hour TTL, invalidated on schedule updates
- Use Redis as a cache-aside pattern with explicit cache invalidation on master data updates
- Document cache invalidation strategy in Section 6

**Score Impact:** Caching Strategy: 2/5

---

### 6. Synchronous Notification Blocking Request Completion

**Severity: Significant**

**Location:** Section 3 (Architecture Design) - Data flow step 5, Section 3 (Components) - NotificationService

**Issue:**
The data flow shows notification sending as step 5 in the synchronous request path: "NotificationService sends confirmation email." If SNS email/SMS delivery is synchronous, the API response is blocked until notification completes (typically 500ms-2s).

**Impact:**
- API response latency increases by 500ms-2s per appointment operation
- External service failures (SNS timeout) directly impact user experience
- Cannot meet typical user expectation of <500ms response time
- System availability depends on third-party notification service availability

**Recommendation:**
- Implement asynchronous notification pattern using message queue (SQS or Redis queue)
- Immediately return success response after database commit
- Process notifications in background worker
- Implement retry logic and dead letter queue for failed notifications
- Update data flow diagram to show async pattern

**Score Impact:** Latency, Throughput Design & Scalability: 3/5

---

## Moderate Issues

### 7. Missing Connection Pool Configuration

**Severity: Moderate**

**Location:** Section 2 (Technology Stack) - PostgreSQL 15, Section 6 (Implementation Guidelines)

**Issue:**
The design mentions PostgreSQL but does not specify connection pool configuration (HikariCP settings). Default settings are often inadequate for production load.

**Impact:**
- Under-provisioned pool (default ~10 connections) causes connection wait times under load
- Over-provisioned pool exhausts database connection limits
- No connection timeout configuration leads to indefinite hangs on database issues

**Recommendation:**
- Define explicit HikariCP settings in Section 6:
  - `maximum-pool-size`: 20-30 (based on ECS task count × connections per task)
  - `minimum-idle`: 10
  - `connection-timeout`: 30000ms
  - `idle-timeout`: 600000ms
  - `max-lifetime`: 1800000ms
- Monitor connection pool metrics in production

**Score Impact:** Memory & Resource Management: 3/5

---

### 8. Missing Query Result Pagination

**Severity: Moderate**

**Location:** Section 5 (API Design) - `GET /api/appointments?patient_id={id}` and `GET /api/medical-records?patient_id={id}`

**Issue:**
Appointment listing and medical record history endpoints do not specify pagination parameters. Long-term patients could accumulate hundreds or thousands of records, and unbounded queries will:
- Load entire result sets into memory
- Transfer large JSON payloads over network
- Cause client-side rendering performance issues

**Impact:**
- Memory spike on application server when long-term patients query history
- Slow response times proportional to patient history length
- Potential OutOfMemoryError on JVM with insufficient heap
- Poor mobile app performance when loading large datasets

**Recommendation:**
- Add pagination parameters: `?page=0&size=20&sort=appointment_date,desc`
- Implement Spring Data Pageable interface
- Return page metadata: `{ "content": [...], "totalElements": 145, "totalPages": 8, "number": 0 }`
- Set reasonable default page size (20-50 records)

**Score Impact:** Memory & Resource Management: 3/5, I/O & Network Efficiency: 3/5

---

### 9. Inefficient Auto-scaling Metric

**Severity: Moderate**

**Location:** Section 7 (Non-functional Requirements) - Auto-scaling: "CPU usage rate 70% threshold"

**Issue:**
CPU-based auto-scaling is reactive and has inherent lag:
1. Load spike occurs
2. CPU increases above 70%
3. Scaling decision triggered
4. New ECS task starts (60-90s cold start)
5. Task becomes healthy and receives traffic

During steps 3-5, existing tasks handle excess load, causing degraded performance for 1-2 minutes.

**Impact:**
- 60-90 second delay before new capacity becomes available
- User experience degradation during traffic spikes
- Potential cascading failure if existing tasks become overloaded during scale-out lag
- Difficulty meeting 99.5% availability target during peak periods

**Recommendation:**
- Implement predictive auto-scaling based on appointment booking patterns (known peak hours)
- Add ALB request count metric for faster response to traffic changes
- Pre-warm additional capacity during known peak hours (morning, lunch break)
- Consider scheduled scaling rules for predictable daily patterns

**Score Impact:** Latency, Throughput Design & Scalability: 3/5

---

## Minor Improvements

### 10. JWT Token Storage Location Not Specified

**Severity: Minor**

**Location:** Section 5 (API Design) - Authentication method, Section 2 (Technology Stack) - Redis for session storage

**Issue:**
The design uses JWT with 24-hour expiration and refresh tokens, but does not specify whether tokens are stored in Redis or are stateless. If Redis is used for token storage, every API request requires a Redis lookup for validation.

**Impact:**
- Minor latency overhead (~1-2ms) per request if using Redis token store
- Potential for token validation to become bottleneck under extreme load
- Missed opportunity for stateless JWT benefits

**Recommendation:**
- Clarify token storage strategy in Section 5
- If using stateless JWT: verify signature only (no Redis lookup needed)
- If using Redis token store: implement caching layer in application memory with 5-minute TTL for token validation results

**Score Impact:** I/O & Network Efficiency: 3/5

---

### 11. Missing Database Query Timeout Configuration

**Severity: Minor**

**Location:** Section 2 (Technology Stack) - PostgreSQL, Section 6 (Implementation Guidelines)

**Issue:**
No query timeout configuration is specified. Long-running or inefficient queries could monopolize database connections indefinitely.

**Impact:**
- Slow queries prevent connection pool from recycling connections
- Cascading failure risk when inefficient queries accumulate
- Difficult to detect and diagnose performance issues in production

**Recommendation:**
- Set statement timeout in PostgreSQL: `SET statement_timeout = '30s'`
- Configure Spring Data JPA query hints: `@QueryHints(@QueryHint(name = "jakarta.persistence.query.timeout", value = "30000"))`
- Monitor slow query logs and optimize queries exceeding threshold

**Score Impact:** Memory & Resource Management: 4/5

---

## Positive Aspects

### Stateless Application Design
The use of ECS Fargate with JWT authentication enables stateless application design, which is excellent for horizontal scalability. This architectural choice supports the auto-scaling strategy effectively.

### Appropriate Use of Managed Services
Leveraging AWS managed services (ALB, RDS, SNS, S3) reduces operational overhead and provides built-in reliability features. This is appropriate for the target scale (500 concurrent sessions).

### Clear Separation of Concerns
The layered architecture (Presentation, Application, Domain, Infrastructure) provides good separation of concerns, which will facilitate performance optimization efforts without extensive refactoring.

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| **Algorithm & Data Structure Efficiency** | **2/5** | Critical issues: no indexing strategy, inefficient available slots calculation. Time complexity not considered for core query patterns. |
| **I/O & Network Efficiency** | **2/5** | Critical N+1 query problem, no batch processing design, synchronous notification blocking, missing pagination. |
| **Caching Strategy** | **2/5** | Redis present but underutilized. No caching for reference data (doctors, clinics). Missed optimization opportunities. |
| **Memory & Resource Management** | **3/5** | Missing connection pool configuration, no result pagination, but generally acceptable resource lifecycle management. |
| **Latency, Throughput Design & Scalability** | **2/5** | Critical concurrency control issue, synchronous operations blocking throughput, reactive auto-scaling only, no performance SLA defined. |

**Overall Performance Score: 2.2/5**

---

## Summary

The design presents a structurally sound architecture but requires significant performance enhancements before production deployment. The most critical issues—N+1 queries, lack of optimistic locking, and missing database indexes—could cause severe performance degradation and data consistency problems under the stated 500 concurrent session target. Addressing the critical and significant issues is essential for meeting the 99.5% availability requirement and ensuring acceptable user experience under production load.

**Immediate Action Required:**
1. Add database indexing strategy
2. Implement optimistic locking for appointments
3. Resolve N+1 query patterns with explicit fetch strategies
4. Implement asynchronous notification processing
5. Add caching layer for reference data

These changes will improve the overall performance score from 2.2/5 to an estimated 4.0/5, making the system production-ready for the stated scale requirements.
