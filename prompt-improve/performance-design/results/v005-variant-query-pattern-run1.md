# Performance Design Review: Medical Appointment Platform

**Evaluation Date**: 2026-02-11
**Reviewer**: performance-design-reviewer (v005-variant-query-pattern)
**Document**: test-document-round-005.md

---

## Executive Summary

This design document exhibits **critical performance issues** centered around unbounded data retrieval operations and N+1 query patterns that will cause severe performance degradation at scale. With expected traffic of 500K patients and 50K appointments/day, the current design lacks pagination, query limits, and efficient data access patterns necessary for production operation.

**Severity Distribution**:
- Critical Issues: 3
- Significant Issues: 4
- Moderate Issues: 2
- Minor Issues: 1

---

## Critical Issues

### C1: Unbounded Patient Appointment History Retrieval

**Location**: Section 5, `GET /api/patients/{patient_id}/appointments`

**Issue Description**:
The endpoint explicitly states "Returns complete history without pagination" (line 174). This means the API will attempt to retrieve and serialize ALL appointments for a patient across their entire lifetime usage of the system.

**Impact Analysis**:
- A patient using the system for 10 years with monthly check-ups = 120 appointments
- 500K active patients × average 50 appointments = 25M appointment records in database
- Database query execution time grows linearly with patient appointment count
- Memory consumption in application server scales with result set size
- Network payload size increases proportionally, causing API response times to degrade from milliseconds to seconds
- JSON serialization overhead becomes significant for large result sets

**Performance Metrics**:
- Query execution: Expected O(n) where n = appointment count per patient
- Memory usage: ~500 bytes per appointment × 120 appointments = 60KB per request
- Network transfer: 60KB+ per API call with no compression mentioned

**Recommendations**:
1. **Immediate**: Implement pagination with default page size of 20-50 appointments
2. Add query parameter `?limit=50&offset=0` to API signature
3. Include pagination metadata in response: `{ "data": [...], "total": 120, "page": 1, "page_size": 50 }`
4. Consider adding date range filters: `?start_date=2025-01-01&end_date=2025-12-31`
5. Add database index on `(patient_id, appointment_date DESC)` for efficient pagination queries

---

### C2: Unbounded Medical Records Retrieval

**Location**: Section 5, `GET /api/patients/{patient_id}/medical-records`

**Issue Description**:
The endpoint "Returns complete medical history" (line 188) without any pagination or filtering mechanism. Medical records accumulate over a patient's lifetime and include diagnosis text, prescriptions, and lab report URLs.

**Impact Analysis**:
- 7-year retention requirement (line 236) means minimum 7 years of records per patient
- Average patient with chronic condition: 2 visits/month × 12 months × 7 years = 168 records
- Database table size: 500K patients × 168 records = 84M medical records
- Each record contains text fields (diagnosis, prescription) averaging 500-2000 bytes
- Query execution time: O(n) where n = number of records per patient
- API response time will exceed acceptable latency (>2 seconds) for patients with extensive medical history

**Performance Metrics**:
- Memory per request: ~1KB per record × 168 records = 168KB
- Database query time: Estimated 500-2000ms for patients with >100 records
- JSON serialization overhead: Significant for text-heavy records

**Recommendations**:
1. **Mandatory**: Implement pagination with default limit of 20-30 records
2. Default to most recent records first (ORDER BY created_at DESC)
3. Add filtering options: `?from_date=2025-01-01&category=prescription`
4. Consider summary view vs. detailed view endpoints:
   - `GET /api/patients/{id}/medical-records/summary` - returns count and recent 5 records
   - `GET /api/patients/{id}/medical-records?page=1` - full paginated access
5. Create composite index on `(patient_id, created_at DESC)` for efficient retrieval

---

### C3: Search Results Without Pagination

**Location**: Section 5, `GET /api/appointments/search`

**Issue Description**:
The appointment search endpoint "Returns all matching appointments in a single response" (line 158) without pagination or result limits. When patients search for appointments by specialization or location, the result set size is unbounded.

**Impact Analysis**:
- Query: "Find cardiologists in New York" could match 500+ doctors
- Each doctor has multiple available slots per day (e.g., 20 slots/day × 7 days = 140 slots)
- Total result set: 500 doctors × 140 slots = 70,000 time slot records
- Database query execution: Full table scan on DoctorSchedule without LIMIT clause
- Application memory consumption: 70KB - 700KB per search request
- API response time: 3-10 seconds for popular specializations in metro areas
- Client-side rendering performance: Browser struggles to render 70K DOM elements

**Performance Metrics**:
- Database query complexity: O(n) where n = matching doctors × slots
- Expected result set for "general practitioner": 1000+ doctors = 140K+ slots
- Network payload: 500KB - 5MB depending on match count
- API latency: Estimated 5-15 seconds for large result sets

**Recommendations**:
1. **Critical**: Implement pagination with maximum page size of 50-100 slots
2. Add default sorting by relevance (distance from patient, rating, earliest availability)
3. Implement query limit: `LIMIT 100` at database level to prevent catastrophic queries
4. Add query parameters: `?page=1&page_size=50&sort_by=earliest_available`
5. Consider implementing cursor-based pagination for better performance with large offsets
6. Add database indexes:
   - `(specialization, day_of_week, is_available)` for specialization searches
   - `(doctor_id, is_available, day_of_week)` for doctor-specific queries

---

## Significant Issues

### S1: N+1 Query Pattern in Appointment Search

**Location**: Section 3, Data Flow step 2 (lines 87-88)

**Issue Description**:
The appointment search flow states "System queries doctor schedules from database" but doesn't specify the query strategy. Based on the API response requirement "List of available time slots **with doctor information**" (line 157), the implementation likely follows this pattern:

1. Query all matching DoctorSchedule records
2. **For each schedule record**, retrieve associated Doctor details (name, specialization, fee, clinic)
3. **For each doctor**, retrieve Clinic information (if clinic_id foreign key is followed)

This is a classic N+1 query pattern where 1 query fetches schedules and N queries fetch doctor details.

**Impact Analysis**:
- Search returns 100 available slots from 20 different doctors
- Naive implementation: 1 query for schedules + 20 queries for doctors + 20 queries for clinics = **41 database queries per API call**
- Database round-trip latency: 5ms × 41 queries = 205ms just in network latency
- Connection pool saturation: 50K appointments/day ÷ 86400 seconds = 0.58 requests/sec → 24 concurrent DB connections needed just for search queries
- Under load (peak hours with 10x traffic): 240 concurrent connections exhausted

**Performance Metrics**:
- Query count per search: 1 + N + N where N = number of unique doctors (typically 10-50)
- Database connection hold time: 200-500ms per request
- API latency contribution: +200-500ms compared to optimized query

**Recommendations**:
1. **Immediate**: Use JOIN queries to fetch related data in single query:
   ```sql
   SELECT ds.*, d.full_name, d.specialization, d.consultation_fee, c.name as clinic_name
   FROM DoctorSchedule ds
   INNER JOIN Doctor d ON ds.doctor_id = d.id
   INNER JOIN Clinic c ON d.clinic_id = c.id
   WHERE d.specialization = ? AND ds.is_available = true
   LIMIT 100
   ```
2. Use JPA fetch joins or `@EntityGraph` to eager-load associations
3. Implement DTO projection to fetch only required fields (avoid loading entire entities)
4. Add query logging with statistics to monitor and detect N+1 patterns in development

---

### S2: N+1 Query Pattern in Patient Dashboard

**Location**: Section 5, `GET /api/patients/{patient_id}/appointments` (line 172)

**Issue Description**:
The endpoint returns "All appointments for a patient" which must include doctor information for display in the patient's appointment list (doctor name, specialization, clinic location). Without explicit JOIN strategy, this creates an N+1 pattern:

1. Query: `SELECT * FROM Appointment WHERE patient_id = ?`
2. **For each appointment** (100+ records), query: `SELECT * FROM Doctor WHERE id = ?`
3. **For each doctor**, potentially query clinic details

**Impact Analysis**:
- Patient with 100 appointments triggers 1 + 100 + up to 100 = **201 database queries**
- Query execution time: 5ms × 201 = 1005ms (over 1 second just in round-trip time)
- Database connection held for 1+ seconds under high load
- Connection pool exhaustion: With 100 concurrent users viewing their appointments, need 100+ database connections
- PostgreSQL default max_connections = 100, system will hit connection limit during normal operation

**Performance Metrics**:
- Query multiplication factor: N+1 where N = appointment count
- Worst case (patient with 500 appointments): 1001 queries, ~5 second execution time
- Connection pool starvation probability: HIGH during peak hours

**Recommendations**:
1. **Critical**: Implement JOIN query or batch fetch strategy:
   ```sql
   SELECT a.*, d.full_name, d.specialization, c.name as clinic_name
   FROM Appointment a
   INNER JOIN Doctor d ON a.doctor_id = d.id
   LEFT JOIN Clinic c ON d.clinic_id = c.id
   WHERE a.patient_id = ?
   ORDER BY a.appointment_date DESC, a.appointment_time DESC
   LIMIT 50 OFFSET 0
   ```
2. Use Spring Data JPA `@Query` with JOIN FETCH or `@EntityGraph`
3. Implement pagination (already recommended in C1) to limit result set size
4. Monitor slow query log for queries executed >10ms and query count per request

---

### S3: Missing Cache Strategy for Frequently Accessed Data

**Location**: Section 3, Core Components (lines 59-84); Section 2, Session storage: Redis (line 32)

**Issue Description**:
The design mentions Redis for session storage but doesn't specify caching strategy for frequently accessed, rarely changing data:
- Doctor profiles (specialization, fee, license number) - read frequently, change rarely
- Clinic information - read on every appointment search/booking, changes infrequently
- DoctorSchedule (weekly schedules) - read hundreds of times per day, typically updated weekly

Without caching, every appointment search, booking, and dashboard view hits PostgreSQL for this reference data.

**Impact Analysis**:
- 50K appointments/day means 50K+ doctor profile lookups per day
- Appointment search with 100 results = 100 doctor profile reads per search
- Database load: Estimated 500K-1M reads/day for reference data that changes <1% per day
- PostgreSQL CPU utilization: +30-50% compared to cached scenario
- API latency: +20-50ms per request due to database round-trips
- Database connection pool utilization: 50-70% for read queries that could be cached

**Performance Metrics**:
- Cache hit rate potential: 95-99% for doctor profiles and clinic data
- Latency reduction: 20-50ms per request (database round-trip eliminated)
- Database load reduction: 70-90% for read queries on reference tables
- Memory requirement: ~10MB for 10K doctor profiles in Redis

**Recommendations**:
1. **Implement multi-level caching strategy**:
   - **L1 (Application-level)**: Caffeine cache with 5-minute TTL for doctor profiles
   - **L2 (Redis)**: Distributed cache with 1-hour TTL for clinic and schedule data
2. **Cache key design**:
   - Doctor profile: `doctor:profile:{doctor_id}` - TTL 1 hour
   - Clinic data: `clinic:info:{clinic_id}` - TTL 1 hour
   - Doctor schedule: `doctor:schedule:{doctor_id}:{week}` - TTL 1 day
3. **Cache invalidation strategy**:
   - On doctor profile update: evict `doctor:profile:{doctor_id}`
   - On schedule change: evict specific week key `doctor:schedule:{doctor_id}:{week}`
   - Use Spring Cache `@Cacheable`, `@CacheEvict` annotations
4. **Monitoring**: Track cache hit rate (target >90%) and cache memory usage

---

### S4: Notification Service Potential Bottleneck

**Location**: Section 3, Notification Service (lines 75-78); Section 3, Data Flow step 5 (line 91)

**Issue Description**:
The design states "Notification service sends confirmation to both parties" immediately after appointment creation. This implies synchronous notification sending during the appointment booking API request flow. With 50K appointments/day and 2 notifications per appointment (patient + doctor), the system must send 100K notifications/day.

**Impact Analysis**:
- API request flow: Client → Create Appointment → **Wait for 2× email/SMS sends** → Return response
- Email sending via AWS SES: 100-300ms per email
- SMS sending via Twilio: 200-500ms per SMS
- Total notification time: 400-800ms per appointment booking request
- API response time: 400-800ms added latency for user-facing operation
- External service failures: If SES or Twilio is slow/down, appointment booking fails or times out
- Connection timeout risk: User abandons request after 5+ second wait

**Performance Metrics**:
- Synchronous notification overhead: +400-800ms per booking
- P95 latency impact: Booking request P95 increases from 200ms to 1000ms
- Throughput limitation: Max throughput limited by external service rate limits
- Failure coupling: Notification service downtime prevents appointment booking

**Recommendations**:
1. **Critical**: Decouple notification sending using asynchronous processing:
   - Implement message queue (AWS SQS or RabbitMQ)
   - Appointment service publishes notification events to queue
   - Separate notification worker consumes queue and sends emails/SMS
2. **API response flow**: Create appointment → Publish event → Return 201 Created immediately
3. **Reliability**: Implement retry logic with exponential backoff for failed notifications
4. **Monitoring**: Track notification queue depth and processing latency
5. **User experience**: Display "Appointment created, confirmation will be sent shortly" message
6. **Implementation**: Use Spring `@Async` with dedicated thread pool or Spring Cloud Stream

---

## Moderate Issues

### M1: Missing Index Strategy for Core Queries

**Location**: Section 4, Data Model (lines 97-150)

**Issue Description**:
The data model defines entities and primary keys but doesn't specify indexes for frequently executed queries. Based on the API design, these query patterns will execute thousands of times per day without supporting indexes:

- Appointment lookup by patient: `WHERE patient_id = ?` (no index on patient_id)
- Appointment lookup by doctor: `WHERE doctor_id = ?` (no index on doctor_id)
- Appointment by status: `WHERE status = ?` (no index on status)
- Medical records by patient: `WHERE patient_id = ?` (MedicalRecord table)
- Doctor schedule lookup: `WHERE doctor_id = ? AND day_of_week = ? AND is_available = ?`

**Impact Analysis**:
- Query execution without indexes: Full table scan = O(N) where N = total rows
- With 50K appointments/day × 365 days = 18M appointment records per year
- Full table scan on 18M rows: 500-2000ms query execution time
- Database CPU utilization: 80-95% during peak hours
- Connection pool exhaustion: Slow queries hold connections for seconds instead of milliseconds

**Performance Metrics**:
- Indexed query: 5-20ms execution time
- Unindexed query: 500-2000ms execution time (100-400x slower)
- Impact on API latency: +500-2000ms per request
- Database I/O: 100x more disk reads without indexes

**Recommendations**:
1. **Mandatory indexes**:
   ```sql
   -- Appointment table
   CREATE INDEX idx_appointment_patient ON Appointment(patient_id, appointment_date DESC);
   CREATE INDEX idx_appointment_doctor ON Appointment(doctor_id, appointment_date, appointment_time);
   CREATE INDEX idx_appointment_status ON Appointment(status, appointment_date);

   -- MedicalRecord table
   CREATE INDEX idx_medicalrecord_patient ON MedicalRecord(patient_id, created_at DESC);
   CREATE INDEX idx_medicalrecord_appointment ON MedicalRecord(appointment_id);

   -- DoctorSchedule table
   CREATE INDEX idx_schedule_doctor ON DoctorSchedule(doctor_id, day_of_week, is_available);
   CREATE INDEX idx_schedule_availability ON DoctorSchedule(is_available, day_of_week);

   -- User table
   CREATE INDEX idx_user_email ON User(email); -- For login queries
   ```
2. Include index definitions in database migration scripts (Flyway/Liquibase)
3. Monitor query performance with `EXPLAIN ANALYZE` during development
4. Use `pg_stat_statements` extension to identify slow queries in production

---

### M2: JWT Token Expiry Too Long

**Location**: Section 5, Authentication (lines 194-197)

**Issue Description**:
The design specifies "Token expiry: 24 hours" with "Refresh token mechanism not implemented". This creates a performance and security trade-off:

- 24-hour tokens mean clients don't need to re-authenticate frequently (reduces authentication API load)
- However, no refresh token mechanism means when token expires, user must log in again with full credential validation
- Expected authentication load: 500K patients × (1 login per day minimum) = 500K authentication requests/day

**Impact Analysis**:
- Peak login time (8-10 AM): 150K logins in 2 hours = 20+ logins/second
- Each login performs BCrypt password hash verification (computationally expensive, 100-300ms CPU time)
- CPU utilization spike during peak hours: +40-60% on application servers
- Database queries: User lookup + session creation per login = 100K+ queries during peak

**Performance Metrics**:
- BCrypt verification: 100-300ms CPU time per login
- Peak concurrent logins: 20-50 per second
- CPU cores required: 3-5 cores dedicated to authentication during peak hours
- Database connection usage: 20-50 connections during login surge

**Recommendations**:
1. **Implement refresh token mechanism**:
   - Access token expiry: 15 minutes
   - Refresh token expiry: 7 days
   - Refresh endpoint: `POST /api/auth/refresh` (no BCrypt verification, just token validation)
2. **Benefits**:
   - Reduces expensive BCrypt operations by 95% (1 login per week vs. 1 per day)
   - CPU utilization reduction: -30-40% during peak hours
   - Improved user experience: Automatic token refresh, no mid-session logouts
3. **Implementation**:
   - Store refresh tokens in Redis with TTL (fast lookup)
   - Access token refresh is 10-20ms operation vs. 100-300ms full authentication
4. **Security**: Shorter access token expiry reduces compromise window while maintaining user convenience

---

## Minor Issues

### I1: Missing Connection Pool Configuration

**Location**: Section 2, Database: PostgreSQL 15 (line 31)

**Issue Description**:
The design specifies PostgreSQL as the primary database but doesn't mention connection pool configuration. Default Spring Boot HikariCP configuration may not be optimal for the expected load (50K appointments/day).

**Impact Analysis**:
- Default HikariCP pool size: 10 connections
- With identified N+1 patterns and synchronous processing, connection hold time can be 500-1000ms
- Connection pool utilization: 10 connections ÷ 1 second hold time = 10 requests/second maximum throughput
- Expected throughput: 50K appointments/day ÷ 86400 seconds = 0.58 rps (within capacity)
- **However**: Peak hours (10x average) = 5.8 rps, N+1 patterns = 10x connection usage → **pool exhaustion during peaks**

**Recommendations**:
1. Configure connection pool based on expected load:
   ```yaml
   spring:
     datasource:
       hikari:
         maximum-pool-size: 30
         minimum-idle: 10
         connection-timeout: 20000
         idle-timeout: 300000
         max-lifetime: 1200000
   ```
2. Monitor connection pool metrics: active connections, pending requests, wait time
3. Set connection timeout (20 seconds) to fail fast when pool is exhausted
4. After fixing N+1 patterns and implementing async notifications, connection pool pressure will decrease significantly

---

## Positive Aspects

1. **Technology stack alignment**: PostgreSQL + Redis is appropriate for transactional + caching workload
2. **Reasonable data model**: UUID primary keys suitable for distributed systems, appropriate use of JSONB for medical history
3. **Infrastructure choices**: Kubernetes enables horizontal scaling when performance issues are addressed

---

## Summary of Performance Risks

| Severity | Issue | Impact | Priority |
|----------|-------|--------|----------|
| Critical | Unbounded appointment history retrieval | API latency >5s for active patients | P0 |
| Critical | Unbounded medical records retrieval | Memory exhaustion, API timeouts | P0 |
| Critical | Search results without pagination | 5-15s response time for popular searches | P0 |
| Significant | N+1 query in appointment search | 200-500ms added latency, connection pool saturation | P1 |
| Significant | N+1 query in patient dashboard | 1+ second query time, connection exhaustion | P1 |
| Significant | Missing cache strategy | +30-50% database CPU, +20-50ms per request | P1 |
| Significant | Synchronous notification sending | 400-800ms added booking latency | P1 |
| Moderate | Missing index strategy | 100-400x slower queries without indexes | P2 |
| Moderate | Long JWT expiry without refresh tokens | +40-60% CPU during peak login hours | P2 |
| Minor | Missing connection pool config | Pool exhaustion during peak hours | P3 |

---

## Recommended Implementation Priority

### Phase 1 (Week 1): Critical Query Fixes
1. Add pagination to all list endpoints (C1, C2, C3)
2. Implement default LIMIT clauses at database level
3. Add core indexes for patient_id, doctor_id, appointment_date

### Phase 2 (Week 2): N+1 Query Elimination
1. Refactor appointment search to use JOIN queries (S1)
2. Refactor patient dashboard to use JOIN queries (S2)
3. Enable query logging and review for remaining N+1 patterns

### Phase 3 (Week 3): Asynchronous Processing
1. Implement message queue for notification service (S4)
2. Decouple notification sending from booking API flow
3. Add retry logic and monitoring

### Phase 4 (Week 4): Caching Layer
1. Implement Redis caching for doctor profiles and clinic data (S3)
2. Configure cache TTL and invalidation strategy
3. Monitor cache hit rates

### Phase 5 (Week 5): Infrastructure Optimization
1. Complete index strategy implementation (M1)
2. Implement refresh token mechanism (M2)
3. Configure connection pool settings (I1)
4. Load testing and performance validation

---

## Conclusion

The Medical Appointment Platform design demonstrates a solid understanding of business requirements and functional architecture, but exhibits **critical performance deficiencies** that will prevent successful operation at the stated scale of 500K patients and 50K appointments/day.

The most severe issues—unbounded data retrieval and N+1 query patterns—must be addressed before production deployment. These issues are not edge cases; they will manifest immediately under normal usage and cause user-facing latency in the range of 5-15 seconds, well beyond acceptable thresholds for healthcare applications.

**Estimated Impact of Fixes**:
- API latency improvement: 5-15 seconds → 50-200ms (20-100x improvement)
- Database CPU utilization: -50-70% reduction
- Application memory usage: -80% reduction for list endpoints
- System throughput capacity: 10x increase after N+1 elimination

All identified issues have clear, actionable solutions that follow industry best practices. Implementation of the recommended changes in the priority order outlined above will result in a production-ready system capable of handling the expected scale.
