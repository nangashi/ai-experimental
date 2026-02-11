# Answer Key - Round 007

## Execution Context
- **Perspective**: performance
- **Target**: design
- **Embedded Problem Count**: 10

## Embedded Problems

### P01: Missing Performance SLA and Metrics Definition
- **Category**: Performance Requirements / SLA Definition (NFR)
- **Severity**: Critical
- **Location**: Section 7 (Non-Functional Requirements)
- **Problem Description**: The design document lacks specific performance targets for critical operations. While scalability targets mention "50 clinics, 500 doctors, 100,000 patients", there are no SLA definitions for response time, throughput, or latency requirements. For a medical appointment system where real-time availability checks and booking confirmations are critical, missing SLA definitions can lead to poor user experience and business impact.
- **Detection Criteria**:
  - ○ (Detected): Explicitly identifies the absence of performance SLA/metrics (e.g., "no response time targets defined", "missing latency requirements for booking API", "throughput goals not specified")
  - △ (Partial): Mentions general performance concerns but does not specifically call out missing SLA/metrics (e.g., "performance considerations needed", "should define performance goals")
  - × (Not Detected): No mention of missing SLA/metrics

### P02: N+1 Query Problem in Appointment History Retrieval
- **Category**: I/O Efficiency / Query Optimization
- **Severity**: Critical
- **Location**: Section 5 (API Design - GET /api/appointments/patient/{patientId})
- **Problem Description**: The endpoint retrieves appointment list with embedded doctor and clinic names, suggesting individual queries for each appointment record to fetch related doctor/clinic data. For patients with extensive appointment history (e.g., chronic disease patients with 50+ appointments), this creates an N+1 query problem that severely impacts response time.
- **Detection Criteria**:
  - ○ (Detected): Identifies N+1 query risk in appointment history retrieval and suggests JOIN operations or batch loading (e.g., "N+1 problem when loading doctor/clinic names", "should use JOIN to fetch appointments with related entities")
  - △ (Partial): Mentions query efficiency concerns but does not specifically identify N+1 pattern (e.g., "multiple queries may impact performance", "database access optimization needed")
  - × (Not Detected): No mention of N+1 query issue

### P03: Missing Cache Strategy for Doctor Availability Slots
- **Category**: Cache / Memory Management
- **Severity**: Critical
- **Location**: Section 5 (API Design - GET /api/appointments/available-slots)
- **Problem Description**: The available slots endpoint queries `doctor_schedule_templates` and `appointments` table on every request. For popular doctors, this endpoint will be hit frequently (hundreds of patients checking availability simultaneously). Without caching, database load will be excessive. Doctor schedule templates rarely change (weekly patterns), making them ideal cache candidates. Current appointments should use short-lived cache (1-5 minutes) with invalidation on new bookings.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing cache for availability slots and suggests caching strategy with invalidation logic (e.g., "should cache doctor schedule templates", "availability slots should use short-lived cache with invalidation on booking")
  - △ (Partial): Mentions caching is needed but lacks specific strategy (e.g., "caching would improve performance", "consider caching doctor data")
  - × (Not Detected): No mention of caching for availability checks

### P04: Medical Record List Unbounded Query
- **Category**: Query Optimization / Pagination
- **Severity**: Medium
- **Location**: Section 5 (API Design - GET /api/patients/{id}/records)
- **Problem Description**: The medical record retrieval endpoint has no pagination or limit parameter. Long-term patients (e.g., 10+ years of history) may accumulate hundreds or thousands of medical records (prescriptions, lab reports, imaging). Loading all records in a single query causes excessive memory consumption, slow response times, and potential timeouts. The endpoint should implement pagination with default limits (e.g., 20 records per page).
- **Detection Criteria**:
  - ○ (Detected): Identifies missing pagination/limits on medical record endpoint and recommends pagination implementation (e.g., "unbounded medical record query", "should implement pagination with default page size", "no limit on record count retrieval")
  - △ (Partial): Mentions concern about large data retrieval but does not specifically call out missing pagination (e.g., "large record sets may impact performance", "data volume considerations needed")
  - × (Not Detected): No mention of pagination or unbounded query issue

### P05: Inefficient Medical Record Access Flow - S3 URL Generation Per Record
- **Category**: I/O Efficiency / API Call Optimization
- **Severity**: Medium
- **Location**: Section 3 (Data Flow - Medical Record Access Flow)
- **Problem Description**: The design describes generating a pre-signed S3 URL for each medical record individually ("For each record, frontend fetches document URL from Medical Record Service"). For patients with 50+ records, this results in 50+ sequential API calls. This should be batched: frontend sends list of record IDs, Medical Record Service returns all pre-signed URLs in a single response.
- **Detection Criteria**:
  - ○ (Detected): Identifies inefficient per-record S3 URL generation and recommends batch API (e.g., "should batch S3 URL generation", "multiple sequential API calls for records", "implement batch endpoint for pre-signed URLs")
  - △ (Partial): Mentions API efficiency concerns but does not specifically identify batch opportunity (e.g., "too many API calls", "API optimization needed")
  - × (Not Detected): No mention of batch optimization

### P06: Missing Database Index Design
- **Category**: Database Design / Index Optimization
- **Severity**: Medium
- **Location**: Section 4 (Data Model)
- **Problem Description**: The data model defines tables and columns but lacks index specifications. Critical query patterns (e.g., appointments by patient_id, appointments by doctor_id and date range, medical_records by patient_id) will perform full table scans without proper indexes. For a system targeting 100,000 patients and high appointment volume, missing indexes will cause severe query performance degradation. Composite indexes on (doctor_id, appointment_date), (patient_id, created_at) are essential.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing index definitions and recommends specific indexes for key query patterns (e.g., "no indexes defined on appointments table", "should add composite index on (doctor_id, appointment_date)", "missing index on patient_id for medical_records")
  - △ (Partial): Mentions indexing as a general concern but does not specify missing indexes (e.g., "indexing strategy needed", "database performance considerations")
  - × (Not Detected): No mention of index design

### P07: Notification Reminder Processing at Scale
- **Category**: Latency / Asynchronous Processing
- **Severity**: Medium
- **Location**: Section 3 (Data Flow - Appointment Booking Flow, Step 6)
- **Problem Description**: The design states "Notification Service queues reminder notifications (1 day before, 1 hour before)" but does not specify the processing mechanism. For a system with 50 clinics and high appointment volume (e.g., 1000 appointments/day), processing reminders synchronously during booking would add significant latency. Additionally, the batch reminder processing strategy (e.g., daily cron job scanning all appointments scheduled for tomorrow) is not defined. Without asynchronous job queue design and batch processing optimization, the notification system will become a bottleneck.
- **Detection Criteria**:
  - ○ (Detected): Identifies need for asynchronous processing or batch job design for reminder notifications (e.g., "reminder processing strategy missing", "should use background job for notification scheduling", "batch reminder processing not defined")
  - △ (Partial): Mentions notification concerns but does not specifically address processing strategy (e.g., "notification system scalability", "reminder delivery performance")
  - × (Not Detected): No mention of notification processing design

### P08: Connection Pool Configuration Missing
- **Category**: Memory Management / Resource Optimization
- **Severity**: Medium
- **Location**: Section 2 (Technology Stack - Database)
- **Problem Description**: The design specifies PostgreSQL and Redis usage but does not define connection pool settings. For a microservices architecture with 6 services, each making database queries, uncontrolled connection creation can lead to connection exhaustion (PostgreSQL default max_connections = 100). With ECS auto-scaling, connection pool configuration (min/max pool size, timeout, validation) is critical to prevent connection leaks and ensure efficient resource utilization.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing connection pool configuration and recommends defining pool settings (e.g., "connection pool settings not defined", "should specify max pool size per service", "connection management strategy missing")
  - △ (Partial): Mentions database connection concerns but does not specifically call out pool configuration (e.g., "database connection optimization needed", "resource management considerations")
  - × (Not Detected): No mention of connection pool design

### P09: Appointment History Data Growth Strategy Missing
- **Category**: Scalability / Data Lifecycle Management
- **Severity**: Medium
- **Location**: Section 4 (Data Model - appointments table)
- **Problem Description**: The appointments table will accumulate historical data indefinitely. With 50 clinics, 500 doctors, and 100,000 patients, assuming average 4 appointments/patient/year, the table will grow by 400,000 records annually. Over 5 years, this becomes 2+ million records. Without data archiving or partitioning strategy (e.g., partition by appointment_date, archive completed appointments older than 2 years), query performance will degrade significantly. Analytics queries scanning historical data will cause full table scans.
- **Detection Criteria**:
  - ○ (Detected): Identifies long-term data growth risk and recommends partitioning or archiving strategy (e.g., "appointments table growth not addressed", "should implement table partitioning by date", "historical data archiving strategy missing")
  - △ (Partial): Mentions data volume concerns but does not specifically address lifecycle management (e.g., "data will grow over time", "large dataset considerations")
  - × (Not Detected): No mention of data growth or lifecycle strategy

### P10: Concurrent Appointment Booking Race Condition
- **Category**: Concurrency Control
- **Severity**: Low
- **Location**: Section 5 (API Design - POST /api/appointments)
- **Problem Description**: The booking API validates availability and creates appointment records, but the design does not specify concurrency control mechanism. When multiple patients attempt to book the same time slot simultaneously (common for popular doctors or newly released slots), race conditions can occur: both requests pass availability validation before either creates the record, resulting in double-booking. The design should specify optimistic locking (version column on doctor_schedule_templates) or pessimistic locking (database row-level lock with SELECT FOR UPDATE) to prevent conflicts.
- **Detection Criteria**:
  - ○ (Detected): Identifies race condition risk in concurrent bookings and suggests locking mechanism (e.g., "concurrent booking race condition", "should implement optimistic locking", "missing SELECT FOR UPDATE for availability check")
  - △ (Partial): Mentions concurrency concerns but does not specify locking strategy (e.g., "concurrent access considerations", "booking conflicts possible")
  - × (Not Detected): No mention of concurrency control

## Bonus Problem List

Bonus points are awarded for detecting issues outside the primary embedded problems but relevant to performance optimization:

| ID | Category | Content | Bonus Condition |
|----|----------|---------|-----------------|
| B01 | Read-Write Splitting | Analytics Service queries impacting production database performance | Suggests read replica for Analytics Service queries to avoid impacting transactional workload |
| B02 | CloudFront Optimization | Static asset delivery optimization missing | Mentions CloudFront cache TTL configuration, compression settings, or edge location optimization |
| B03 | RabbitMQ Configuration | Message queue performance tuning not specified | Identifies missing queue configuration (prefetch count, acknowledgment mode, durable/transient queue settings) |
| B04 | JWT Validation Overhead | JWT validation on every request without caching | Suggests caching decoded JWT or using API gateway for centralized validation |
| B05 | Pre-signed URL Expiration Strategy | 1-hour S3 URL expiration may cause UX issues | Discusses trade-off between security and UX, suggests dynamic expiration based on record sensitivity |
| B06 | Waitlist Feature Performance | Waitlist management implementation not defined | Identifies missing design for efficient waitlist processing (priority queue, notification triggers) |
| B07 | Search Functionality | Doctor/clinic search performance not addressed | Suggests search index (Elasticsearch) or optimized search query design for multi-field searches |
| B08 | Rate Limiting | API rate limiting strategy missing | Recommends rate limiting per user/IP to prevent API abuse and ensure fair resource allocation |
| B09 | Database Transaction Scope | Transaction boundaries not defined | Suggests minimizing transaction scope to reduce lock contention and improve throughput |
| B10 | Monitoring Metrics | Performance monitoring strategy missing | Identifies need for APM tools, query performance monitoring, or custom metrics (booking latency, availability check time) |
