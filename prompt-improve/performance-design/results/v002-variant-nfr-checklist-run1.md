# Performance Design Review - Online Medical Appointment System

## Overall Assessment

This design document presents a medical appointment system with a solid foundation, but exhibits several **critical performance and scalability gaps** at the architecture level. While the basic technology choices are reasonable, the document lacks essential NFR specifications, capacity planning, and performance-aware design patterns needed for a production healthcare system.

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 2/5 | No discussion of data structure choices for critical operations; missing index strategy for appointment queries |
| I/O & Network Efficiency | 2/5 | Classic N+1 query risks in appointment listings; no batch processing or caching strategy for repetitive queries |
| Caching Strategy | 1/5 | Redis mentioned only as session store; no caching design for doctor schedules, available slots, or patient data |
| Memory & Resource Management | 2/5 | No connection pool configuration, resource limit definitions, or memory management strategy |
| Latency, Throughput & Scalability | 2/5 | Missing SLA definitions, no asynchronous processing design, inadequate auto-scaling criteria, no database scalability strategy |

**Overall Score: 1.8/5** - Requires significant architecture-level improvements before production deployment.

---

## Critical Issues (Priority 1)

### C1. Missing Database Read/Write Separation Strategy
**Severity**: Critical
**Impact**: Single-point database bottleneck will cause system-wide performance degradation under moderate load
**Location**: Section 2 (Database), Section 3 (Architecture Design)

The design specifies PostgreSQL as "メインDB" without any read/write separation or read replica strategy. With expected 500 concurrent sessions and appointment query patterns (patient listing appointments, doctor viewing daily schedules, admin dashboard), the single database instance will become a severe bottleneck.

**Consequences**:
- Write operations (appointment creation/updates) will block read queries
- Dashboard and listing queries will degrade appointment booking latency
- No path to horizontal scaling for read-heavy workload

**Recommendation**:
```
Primary DB (Write):
- Master PostgreSQL instance for appointments, patients, doctors tables
- Handles CREATE/UPDATE/DELETE operations

Read Replicas (Read):
- 2+ read replicas with replication lag monitoring (<500ms target)
- Route GET /api/appointments, GET /api/medical-records to replicas
- Route GET /api/schedules/available-slots to replicas
- Implement connection routing logic in Repository layer
```

---

### C2. No Capacity Planning or Performance SLA Defined
**Severity**: Critical
**Impact**: Cannot validate design adequacy or set monitoring thresholds
**Location**: Section 7 (Non-functional Requirements)

The document states "最大500セッション" but provides no other capacity metrics:
- No definition of **concurrent requests per second**
- No **data volume growth projection** (appointments/day, total patients, medical records accumulation)
- No **response time requirements** (p50, p95, p99 latencies)
- No **throughput targets** (appointments created per hour during peak times)

**Consequences**:
- Cannot size ECS task count, database resources, or connection pools
- No basis for alerting thresholds or performance regression detection
- Risk of under-provisioning during initial launch or over-provisioning (cost waste)

**Recommendation**:
Define the following NFR specifications:
```
Capacity Requirements:
- Peak load: 50 appointments/minute (lunch hour, 12:00-13:00)
- Data volume: 10,000 patients, 50 doctors, 200 appointments/day
- Growth: 20% YoY patient growth, 3-year retention of medical_records

Performance SLA:
- API Response Time (p95):
  - POST /api/appointments: <500ms
  - GET /api/appointments: <200ms
  - GET /api/schedules/available-slots: <300ms
- Database Query Time (p99): <100ms
- Availability: 99.5% (13.5 min downtime/month)

Resource Sizing:
- ECS Tasks: 4 initial (2 vCPU, 4GB each), scale to 10 max
- PostgreSQL: db.r6g.xlarge (4 vCPU, 32GB), 500GB SSD
- Redis: cache.r6g.large (2 vCPU, 13GB)
- Connection Pool: 20 connections/task = 80 total (200 max)
```

---

### C3. Missing Monitoring & Observability Strategy
**Severity**: Critical
**Impact**: Cannot detect performance degradation or debug production issues
**Location**: Section 6 (Implementation Policy - Logging), Section 7 (Non-functional Requirements)

The logging policy mentions request ID tracking but provides no performance monitoring strategy:
- No mention of **CloudWatch metrics collection** (API latency, database query time, error rates)
- No **distributed tracing** implementation (AWS X-Ray, OpenTelemetry)
- No **alerting thresholds** for performance degradation
- No **database query performance monitoring** (slow query log analysis)

**Consequences**:
- Cannot identify which API endpoints cause latency spikes
- No visibility into N+1 query problems in production
- Cannot correlate user complaints with specific performance issues
- Reactive incident response instead of proactive detection

**Recommendation**:
```
Metrics Collection:
- CloudWatch custom metrics:
  - API endpoint latency (p50, p95, p99) per endpoint
  - Database query duration per query type
  - Connection pool usage (active/idle/wait count)
  - Redis cache hit/miss rates
- Annotation: Use Micrometer with Spring Boot Actuator

Distributed Tracing:
- AWS X-Ray integration for request flow visualization
- Trace sampling: 100% for errors, 5% for success (high traffic)
- Custom segments for: DB query, Redis access, SNS notification

Alerting Thresholds:
- API latency p95 > 1000ms for 5 min → PagerDuty alert
- Database CPU > 80% for 3 min → Warning
- Connection pool exhaustion (wait count > 0) → Critical
- Cache miss rate > 30% → Investigation ticket

Dashboard:
- Grafana dashboard with 7-day latency trends per endpoint
- Real-time DB query performance (top 10 slowest queries)
- ECS task count and auto-scaling activity
```

---

### C4. Appointment Query N+1 Problem
**Severity**: Critical
**Impact**: Patient appointment listing will execute 1+N doctor queries; O(N) latency increase
**Location**: Section 5 (API Design - `/api/appointments?patient_id={id}`)

The API design shows `GET /api/appointments?patient_id={id}` returning appointment list. With JPA default lazy loading, the typical implementation will:
1. Query: `SELECT * FROM appointments WHERE patient_id = ?`
2. For each appointment, query: `SELECT * FROM doctors WHERE doctor_id = ?`

With 10 appointments per patient, this becomes 11 database round-trips instead of 1-2.

**Consequences**:
- Linear latency increase with appointment count: 10 appointments = 10x overhead
- Multiplied impact with concurrent users: 50 users listing appointments = 550 queries/second
- Database connection pool exhaustion under moderate load

**Recommendation**:
```java
// Implement JOIN FETCH in Repository layer
@Query("SELECT a FROM Appointment a " +
       "JOIN FETCH a.doctor d " +
       "JOIN FETCH a.patient p " +
       "WHERE a.patient.patientId = :patientId " +
       "ORDER BY a.appointmentDate DESC, a.timeSlot ASC")
List<Appointment> findByPatientIdWithDetails(@Param("patientId") Long patientId);

// Similarly for doctor's daily appointments:
@Query("SELECT a FROM Appointment a " +
       "JOIN FETCH a.patient p " +
       "WHERE a.doctor.doctorId = :doctorId " +
       "AND a.appointmentDate = :date " +
       "ORDER BY a.timeSlot ASC")
List<Appointment> findByDoctorIdAndDateWithPatient(
    @Param("doctorId") Long doctorId,
    @Param("date") LocalDate date
);
```

Also add composite indexes:
```sql
CREATE INDEX idx_appointments_patient_date
ON appointments(patient_id, appointment_date DESC, time_slot);

CREATE INDEX idx_appointments_doctor_date
ON appointments(doctor_id, appointment_date, time_slot);
```

---

## Significant Issues (Priority 2)

### S1. No Caching Strategy for Doctor Schedules and Available Slots
**Severity**: Significant
**Impact**: Repeated database queries for schedule data; unnecessary load on primary database
**Location**: Section 5 (API Design - `/api/schedules/available-slots`)

Redis is allocated only for session storage. The `GET /api/schedules/available-slots?doctor_id={id}&date={date}` endpoint likely involves:
1. Query doctor's working hours
2. Query existing appointments for that date
3. Calculate available time slots (set difference operation)

This calculation is identical for all patients viewing the same doctor's schedule on the same date, yet no caching strategy is defined.

**Consequences**:
- Redundant database queries when multiple patients browse the same doctor
- Higher latency for slot availability checks (impacts booking UX)
- Unnecessary load on PostgreSQL read replicas

**Recommendation**:
```
Cache Strategy (Redis):

1. Available Slots Cache
   Key: "slots:doctor:{doctor_id}:date:{date}"
   Value: JSON array of available time slots
   TTL: 5 minutes
   Invalidation: On appointment creation/cancellation for that doctor+date

2. Doctor Profile Cache
   Key: "doctor:{doctor_id}"
   Value: JSON with name, specialty, clinic_id
   TTL: 1 hour
   Invalidation: On doctor profile update (rare)

3. Patient Profile Cache (Read-Through)
   Key: "patient:{patient_id}"
   Value: JSON with name, email, phone
   TTL: 15 minutes
   Invalidation: On patient profile update

Implementation:
- Use Spring Cache abstraction with Redis backend
- Add @Cacheable("availableSlots") annotation to ScheduleService
- Implement @CacheEvict on AppointmentService.createAppointment()
```

**Expected Impact**:
- Available slots query: 95% cache hit rate → 50ms → 5ms (10x improvement)
- Database query reduction: ~80% for schedule-related queries

---

### S2. Missing Circuit Breaker and Rate Limiting for External Services
**Severity**: Significant
**Impact**: SNS notification failures can cascade to appointment booking failures
**Location**: Section 3 (Architecture - NotificationService), Section 6 (Deployment Policy)

The design mentions Amazon SNS for email/SMS notifications but has no fault isolation strategy. If SNS experiences latency spikes or throttling:
- Synchronous notification sending will block appointment creation
- No retry mechanism defined (transient failures become permanent)
- No bulkhead pattern to isolate notification failures

**Consequences**:
- Appointment booking fails even though booking succeeded in DB
- Poor user experience (timeout errors)
- SNS API rate limits (10,000 SMS/day in sandbox) not addressed

**Recommendation**:
```
Circuit Breaker (Resilience4j):
- Failure threshold: 50% error rate over 10 requests
- Open state duration: 30 seconds
- Half-open state: Allow 3 probe requests
- Fallback: Log notification failure, return success to user

Rate Limiting:
- Token bucket per notification type:
  - Email: 100/second
  - SMS: 10/second (AWS SNS default limit)
- Implement using Resilience4j RateLimiter

Asynchronous Processing:
- Change NotificationService to publish to SQS queue
- Separate notification worker (ECS task) consumes from queue
- Decouple appointment booking from notification delivery
- Implement exponential backoff retry (3 attempts, 1s/3s/9s delays)

Resource Limits:
- NotificationService connection pool: 5 max connections to SNS
- Timeout: 3 seconds per SNS API call
- Bulkhead: Separate thread pool (5 threads) for notifications
```

---

### S3. Insufficient Auto-Scaling Configuration
**Severity**: Significant
**Impact**: Cannot handle sudden traffic spikes; risk of service degradation during peak hours
**Location**: Section 7 (Availability & Scalability)

The design states "CPU使用率70%を閾値" for ECS auto-scaling, but provides no other scaling configuration:
- No **scale-out/scale-in speed** (how fast to add/remove tasks)
- No **cooldown period** (risk of thrashing)
- No **target tracking policy** (CPU alone insufficient for request-driven load)
- No **scheduled scaling** (predictable morning appointment rush)

**Consequences**:
- Slow reaction to traffic spikes (5+ minutes to scale from 2→4 tasks)
- CPU threshold reached only after user experience degrades
- Potential cost waste from delayed scale-in during off-peak hours

**Recommendation**:
```
Auto-Scaling Policy:

1. Target Tracking (Primary):
   - Metric: ALB RequestCountPerTarget
   - Target: 100 requests/target/minute
   - Scale-out cooldown: 60 seconds
   - Scale-in cooldown: 300 seconds (avoid thrashing)

2. CPU-Based (Secondary):
   - Metric: ECS Task CPU Utilization
   - Target: 60% (not 70% - leave headroom)
   - Scale-out cooldown: 120 seconds

3. Scheduled Scaling (Predictable Patterns):
   - Mon-Fri 09:00-12:00: Min 4 tasks (morning appointment rush)
   - Mon-Fri 18:00-22:00: Min 2 tasks (evening usage)
   - Sat-Sun: Min 2 tasks (lower traffic)

4. Task Limits:
   - Minimum: 2 tasks (HA requirement)
   - Maximum: 10 tasks (cost guardrail)
   - Desired: 4 tasks (normal operation)

CloudWatch Alarms:
- Task count at maximum for >10 min → Investigate capacity
- Scale-out events >10/hour → Review scaling policy
```

---

### S4. Missing Index Strategy and Query Optimization
**Severity**: Significant
**Impact**: Full table scans on appointments table; latency increases with data growth
**Location**: Section 4 (Data Model)

The data model defines tables but specifies no indexes beyond primary keys. Critical query patterns are unoptimized:

1. `GET /api/appointments?patient_id={id}` → Full table scan on appointments
2. `GET /api/appointments?doctor_id={id}&date={date}` → Full table scan on appointments
3. `GET /api/medical-records?patient_id={id}` → Full table scan on medical_records
4. Available slots calculation → Multiple sequential queries without composite indexes

**Consequences**:
- Query latency: O(N) instead of O(log N) with B-tree index
- Example: 200 appointments/day × 365 days = 73,000 rows/year
  - Without index: ~100ms query time (full scan)
  - With index: ~5ms query time (index seek)
- Database CPU spikes during peak hours

**Recommendation**:
```sql
-- Critical Indexes (Add to migration script):

-- Patient appointment listing (covers patient_id + date sort):
CREATE INDEX idx_appointments_patient_date
ON appointments(patient_id, appointment_date DESC, time_slot DESC);

-- Doctor daily schedule (covers doctor_id + date filter):
CREATE INDEX idx_appointments_doctor_date_status
ON appointments(doctor_id, appointment_date, time_slot)
WHERE status != 'cancelled';

-- Medical records by patient (covers patient_id + date sort):
CREATE INDEX idx_medical_records_patient
ON medical_records(patient_id, created_at DESC);

-- Appointment uniqueness check (prevent double booking):
CREATE UNIQUE INDEX idx_appointments_doctor_slot
ON appointments(doctor_id, appointment_date, time_slot)
WHERE status = 'scheduled';

-- Email lookup for authentication:
CREATE INDEX idx_patients_email ON patients(email);
CREATE INDEX idx_doctors_email ON doctors(email);

-- Clinic's doctors listing:
CREATE INDEX idx_doctors_clinic ON doctors(clinic_id, specialty);
```

**Expected Impact**:
- Appointment listing query: 100ms → 5ms (20x improvement)
- Available slots calculation: 150ms → 20ms (7.5x improvement)
- Supports 3-year data retention without performance degradation

---

## Moderate Issues (Priority 3)

### M1. No Database Connection Pool Sizing Strategy
**Severity**: Moderate
**Impact**: Risk of connection exhaustion or resource waste
**Location**: Section 2 (Database), Section 6 (Implementation Policy)

The design does not specify HikariCP configuration. With ECS auto-scaling (2-10 tasks), connection pool sizing is critical:
- Too small: Connection wait timeouts under load
- Too large: Exceeds PostgreSQL `max_connections` limit, memory waste

**Recommendation**:
```yaml
# application.yml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20        # Per ECS task
      minimum-idle: 5               # Keep warm connections
      connection-timeout: 3000      # 3 seconds max wait
      idle-timeout: 600000          # 10 minutes idle
      max-lifetime: 1800000         # 30 minutes max connection age
      leak-detection-threshold: 60000  # Warn if connection held >60s

# PostgreSQL max_connections calculation:
# Max ECS tasks (10) × pool size (20) + admin overhead (20) = 220
# Set PostgreSQL max_connections = 250
```

Monitor connection pool metrics:
- `hikaricp.connections.active` (should stay <80% of max)
- `hikaricp.connections.pending` (should be 0)

---

### M2. No Asynchronous Processing for Non-Critical Operations
**Severity**: Moderate
**Impact**: Synchronous operations increase API latency unnecessarily
**Location**: Section 3 (Data Flow), Section 5 (API Design)

The data flow shows synchronous execution: "NotificationServiceが確認メールを送信" happens in the request path. Email/SMS delivery is not critical for appointment booking success.

**Recommendation**:
```
Decouple with SQS:
1. POST /api/appointments → Save to DB → Publish to SQS → Return 201 Created
2. NotificationWorker (separate ECS task) → Consume from SQS → Send via SNS

Benefits:
- API response time: 500ms → 200ms (60% reduction)
- Fault isolation: SNS failures don't impact booking
- Retry mechanism: SQS DLQ for failed notifications

Implementation:
- SQS queue: appointment-notifications (FIFO, 5-minute visibility timeout)
- Worker concurrency: 3 consumers (handle 10 messages/second)
- Dead Letter Queue: 3 retry attempts, then move to DLQ for manual investigation
```

---

### M3. Missing JWT Token Refresh Strategy Details
**Severity**: Moderate
**Impact**: Risk of user session interruption during active usage
**Location**: Section 5 (Authentication/Authorization)

The design mentions "リフレッシュトークンによる自動更新機能あり" but lacks implementation details:
- No specification of refresh token lifetime
- No storage strategy for refresh tokens (DB? Redis?)
- No rotation policy (security best practice)

**Recommendation**:
```
JWT Configuration:
- Access token lifetime: 15 minutes (not 24 hours - reduce exposure)
- Refresh token lifetime: 7 days
- Storage: Redis (key: "refresh:{user_id}:{token_id}", TTL: 7 days)

Token Rotation:
- On refresh, issue new access + refresh token
- Invalidate old refresh token (prevent replay)
- Implement refresh token family tracking (detect stolen tokens)

API Endpoint:
- POST /api/auth/refresh
  Request: { "refresh_token": "..." }
  Response: { "access_token": "...", "refresh_token": "..." }

Frontend Logic:
- Intercept 401 responses → Auto-refresh → Retry original request
- Implement exponential backoff if refresh fails
```

---

### M4. No Database Backup and Disaster Recovery Strategy
**Severity**: Moderate
**Impact**: Potential data loss in case of database failure; extended downtime during recovery
**Location**: Section 7 (Non-functional Requirements)

The design specifies 99.5% availability but provides no backup/recovery strategy. Medical appointment data is critical (appointments, medical_records).

**Recommendation**:
```
Backup Strategy:
- RDS Automated Backups: Enabled, 7-day retention
- Backup window: 03:00-04:00 JST (lowest traffic period)
- Point-in-time recovery: Up to 5 minutes before failure

Disaster Recovery:
- RPO (Recovery Point Objective): 5 minutes (transaction log replay)
- RTO (Recovery Time Objective): 1 hour (restore from snapshot + apply logs)
- Multi-AZ deployment: Enable for automatic failover (<2 min)

Testing:
- Quarterly DR drill: Restore to separate test environment
- Verify backup integrity: Run SELECT COUNT(*) on all tables
- Document runbook: Step-by-step recovery procedure
```

---

## Minor Improvements (Priority 4)

### I1. Consider Pagination for Large Result Sets
**Recommendation**: Add pagination to `GET /api/appointments?patient_id={id}` and `GET /api/medical-records?patient_id={id}` to prevent unbounded response sizes (e.g., patients with 100+ appointments).

```
GET /api/appointments?patient_id={id}&page=0&size=20&sort=appointment_date,desc
```

---

### I2. Implement API Response Compression
**Recommendation**: Enable gzip compression in ALB for JSON responses >1KB to reduce network transfer time (typical improvement: 60-80% size reduction).

---

### I3. Add Database Query Timeout Configuration
**Recommendation**: Set statement timeout to prevent runaway queries:
```sql
ALTER DATABASE appointment_db SET statement_timeout = '5s';
```

---

## Positive Aspects

1. **Appropriate Technology Stack**: Spring Boot 3.1 + PostgreSQL is a solid choice for transactional healthcare systems
2. **Stateless Design**: JWT authentication and ECS Fargate enable horizontal scaling
3. **Infrastructure Choices**: ALB + ECS + RDS is a proven pattern for moderate-scale systems
4. **Request ID Tracking**: Mentioned in logging policy, supports distributed tracing foundation
5. **Blue-Green Deployment**: Reduces deployment risk and enables fast rollback

---

## Summary and Recommendations

### Critical Action Items (Must-Fix Before Production)
1. **Add database read replica strategy** with connection routing logic (C1)
2. **Define comprehensive capacity planning and SLA metrics** (C2)
3. **Implement monitoring strategy** with CloudWatch + X-Ray + alerting (C3)
4. **Fix N+1 query problem** with JOIN FETCH and composite indexes (C4)

### High-Priority Improvements (Implement in First Iteration)
5. **Add Redis caching layer** for doctor schedules and available slots (S1)
6. **Implement circuit breaker and rate limiting** for SNS integration (S2)
7. **Configure detailed auto-scaling policies** with target tracking and scheduled scaling (S3)
8. **Add comprehensive index strategy** for all query patterns (S4)

### Recommended Enhancements (Second Iteration)
9. **Size connection pools and set resource limits** (M1)
10. **Decouple notifications with SQS** for asynchronous processing (M2)
11. **Clarify JWT refresh token strategy** and reduce access token lifetime (M3)
12. **Document backup/DR procedures** and enable Multi-AZ (M4)

### Architecture-Level Concerns
- **Scalability**: Current design cannot handle 10x growth without major refactoring
- **Observability**: Cannot debug production performance issues with current instrumentation
- **Resilience**: No fault isolation for external dependencies (SNS)
- **Performance**: Missing caching layer will cause unnecessary database load

**Overall Recommendation**: This design requires significant architecture-level improvements (especially C1-C4, S1-S4) before production deployment. Prioritize implementing monitoring and capacity planning first, then address database scalability and caching strategies.
