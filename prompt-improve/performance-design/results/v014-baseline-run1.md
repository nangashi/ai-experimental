# Performance Evaluation Report: Real Estate Property Management Platform

## Executive Summary

This evaluation identifies critical performance bottlenecks and architectural inefficiencies in the property management platform design. The analysis reveals significant gaps in caching strategy, data access optimization, and scalability planning that could severely impact system performance under the expected load of 500 concurrent users managing up to 500 properties per organization.

## Critical Issues

### C-1: Missing Database Indexing Strategy

**Issue Description:**
The data model section (4.1, 4.2) defines core entities and relationships but provides no indexing strategy for frequently queried columns. Given the access patterns described in the API design (Section 5), several queries will perform full table scans without proper indexes.

**Performance Impact:**
- Property queries filtered by `owner_id` and `property_type` (GET /api/v1/properties) will scan entire Property table
- Unit lookups by `property_id` (GET /api/v1/properties/{id}/units) will scan entire Unit table
- Tenant lookups by `unit_id` will cause O(n) scans
- Payment history queries by `tenant_id` (GET /api/v1/tenants/{id}/payment-history) will become progressively slower as payment records accumulate
- MaintenanceRequest queries by `unit_id` and `status` will degrade with scale

**Expected Impact at Scale:**
For a property manager with 500 properties averaging 4 units each (2000 units), unindexed queries could take 500ms-2s per request, violating the 500ms API response target. Financial summary endpoints aggregating data across properties will timeout.

**Recommendations:**
1. Add composite index on `Property(owner_id, property_type, deleted_at)` for filtered property listings
2. Add index on `Unit(property_id, deleted_at)` for property-unit lookups
3. Add index on `Unit(status, deleted_at)` for vacancy tracking
4. Add composite index on `Tenant(unit_id, lease_end_date)` for active lease queries
5. Add composite index on `Payment(tenant_id, payment_date)` for payment history with temporal sorting
6. Add composite index on `MaintenanceRequest(unit_id, status, priority)` for maintenance dashboard queries
7. Add index on `Document(entity_type, entity_id)` for document retrieval by parent entity

### C-2: N+1 Query Problem in Financial Summary API

**Issue Description:**
The financial summary endpoint (GET /api/v1/properties/{id}/financial-summary) aggregates rent collected, outstanding, and expenses across all units in a property. With the described layered architecture using JPA (Section 3.1, 3.2), the typical implementation pattern would load the property, iterate through units, and query payments/expenses for each unit individually.

**Performance Impact:**
For a 50-unit property, this results in:
- 1 query to load property
- 1 query to load units
- 50 queries for payment totals per unit
- 50 queries for outstanding balances per unit
- Total: 102 database round trips

At 10ms per query, this is 1000ms just for database I/O, exceeding the 500ms API target before including business logic, network latency, and serialization.

**Recommendations:**
1. Implement aggregate queries using JPA @Query with JOIN FETCH and GROUP BY:
   ```sql
   SELECT p.id,
          SUM(CASE WHEN pay.status = 'COMPLETED' THEN pay.amount ELSE 0 END) as collected,
          SUM(CASE WHEN pay.status = 'PENDING' THEN pay.amount ELSE 0 END) as outstanding
   FROM Property p
   JOIN Unit u ON u.property_id = p.id
   JOIN Tenant t ON t.unit_id = u.id
   LEFT JOIN Payment pay ON pay.tenant_id = t.id
   WHERE p.id = :propertyId AND p.deleted_at IS NULL
   GROUP BY p.id
   ```
2. Define custom repository method `PropertyRepository.findFinancialSummary(UUID propertyId)` returning DTO
3. Cache financial summary results with 15-minute TTL since data changes infrequently

### C-3: Unbounded Result Sets Without Pagination

**Issue Description:**
Several API endpoints return unbounded result sets:
- GET /api/v1/properties/{id}/units (Section 5.1) - no pagination despite properties potentially having 100+ commercial units
- GET /api/v1/tenants/{id}/payment-history (Section 5.2) - no pagination despite 7-year retention policy (84+ payment records per tenant)
- Maintenance request queries - no pagination described

The properties endpoint includes pagination (page, size parameters) but other collection endpoints do not.

**Performance Impact:**
- A commercial property with 200 units would return 200 unit records in a single response (~50KB payload)
- A long-term tenant's payment history could include 100+ records (~30KB payload)
- Database memory consumption grows linearly with result set size, causing buffer pool thrashing
- Large JSON payloads increase serialization time and network transfer time
- Frontend performance degrades when rendering large lists

**Recommendations:**
1. Add pagination to GET /api/v1/properties/{id}/units with default page size of 50
2. Add pagination to GET /api/v1/tenants/{id}/payment-history with default page size of 12 (one year)
3. Add cursor-based pagination for maintenance requests filtered by status
4. Implement query result limits at repository layer as safety mechanism (max 1000 records)
5. Consider adding summary counts separate from paginated detail queries

### C-4: Missing Query Timeout Configuration

**Issue Description:**
Section 3.3 mentions "timeout configurations for external calls" are missing, but there is also no mention of database query timeouts. Long-running queries (e.g., report generation, financial summaries without proper indexes) can hold database connections indefinitely.

**Performance Impact:**
- Complex reporting queries (occupancy reports, owner statements) could hold connections for 30+ seconds
- With connection pool exhaustion, all API requests would fail with "Cannot get JDBC connection" errors
- Default PostgreSQL statement timeout is 0 (infinite), allowing queries to run indefinitely
- A single slow query can cascade to complete service outage if connection pool is sized at 20-50 connections

**Recommendations:**
1. Configure `spring.datasource.hikari.connection-timeout=10000` (10s max wait for connection)
2. Configure `spring.jpa.properties.hibernate.query.query_timeout=30` (30s statement timeout)
3. Set PostgreSQL `statement_timeout=30000` at database level as safety net
4. Implement separate connection pool for reporting queries with higher timeout (60s)
5. Add connection pool metrics monitoring (active connections, wait time) to CloudWatch

## Significant Issues

### S-1: Missing Redis Caching Strategy Definition

**Issue Description:**
Section 2.1 lists Redis 7.0 as part of the technology stack, but there is no caching strategy defined anywhere in the design document. No mention of what data should be cached, cache expiration policies, cache invalidation triggers, or cache hit/miss monitoring.

**Performance Impact:**
Without strategic caching:
- Property metadata queries execute on every dashboard load (100+ req/min during peak hours)
- User role/permission lookups hit database for every authenticated API request (50,000 req/hour at 500 concurrent users)
- Financial summary calculations re-execute expensive aggregation queries repeatedly
- Document metadata queries for S3 keys hit database instead of cache

**Recommendations:**
1. **Authentication/Authorization Cache** (TTL: 15 minutes, aligned with JWT expiration):
   - Cache user roles and permissions by user_id
   - Cache organization membership for property access checks
   - Invalidate on role changes or user updates

2. **Property Metadata Cache** (TTL: 1 hour):
   - Cache property details by property_id (address, type, owner)
   - Cache unit lists by property_id (units change infrequently)
   - Invalidate on property/unit updates

3. **Financial Summary Cache** (TTL: 30 minutes):
   - Cache financial summary by property_id
   - Invalidate on payment status changes or new payments

4. **Tenant Profile Cache** (TTL: 1 hour):
   - Cache tenant details by tenant_id
   - Invalidate on lease modifications

5. **Reporting Cache** (TTL: 24 hours):
   - Cache occupancy reports by property_id + date range
   - Cache owner statements by owner_id + month
   - Invalidate at midnight for daily reports

6. Implement cache-aside pattern with Redis for all caches above
7. Add cache hit rate metrics (target >80% hit rate for repeated queries)

### S-2: Synchronous Third-Party API Calls in Request Path

**Issue Description:**
Section 3.3 describes a synchronous data flow where "API requests routed through API Gateway → Business logic execution → Database queries → Response." The API design (Section 5) shows several endpoints making synchronous calls to external services:

- POST /api/v1/tenants/applications triggers Checkr API for background checks
- POST /api/v1/payments/process calls Stripe API
- POST /api/v1/maintenance/requests sends notifications via SendGrid
- GET /api/v1/reports/owner-statement generates PDF with DocuSign integration

**Performance Impact:**
- Stripe payment processing typically takes 1-3 seconds; if Stripe API is slow (99th percentile: 5s), payment requests timeout
- Checkr background checks can take 2-5 seconds for API response
- SendGrid email API adds 200-500ms latency to maintenance request submission
- User-facing request latency is bound by slowest external API response
- Circuit breaker failures on external services cause cascading failures

**Recommendations:**
1. **Async Background Job Processing**:
   - Use RabbitMQ (already in stack, Section 2.1) for async job queue
   - POST /api/v1/tenants/applications returns `{ application_id, status: "PENDING" }` immediately, triggers background job for Checkr API
   - POST /api/v1/payments/process returns `{ payment_id, status: "PROCESSING" }` immediately, processes Stripe call asynchronously
   - Implement WebSocket or SSE for real-time status updates to frontend

2. **Notification Decoupling**:
   - NotificationService should publish events to RabbitMQ instead of synchronous SendGrid calls
   - Background worker processes notification queue with retry logic

3. **Report Generation Offloading**:
   - GET /api/v1/reports/owner-statement should return `{ job_id, status: "GENERATING" }` immediately
   - Background worker generates PDF and uploads to S3
   - Polling endpoint GET /api/v1/reports/jobs/{job_id} returns status and download URL when ready

4. **External API Timeout Configuration**:
   - Set aggressive timeouts for all external HTTP clients (3s connection timeout, 10s read timeout)
   - Implement circuit breaker pattern with Resilience4j (already Spring Boot ecosystem)

### S-3: Missing Connection Pool Configuration

**Issue Description:**
Section 3.1 mentions "Integration Layer: External API clients with retry logic" but provides no connection pooling configuration for external HTTP clients or database connections. Section 2.2 specifies RDS for PostgreSQL but doesn't define connection pool sizing.

**Performance Impact:**
- Default HikariCP pool size (10 connections) is insufficient for 500 concurrent users
- Each API request requires 1-2 database connections; 10 connections support max 5-10 concurrent requests
- Connection starvation causes requests to queue, adding 5-10s wait time
- External HTTP clients without connection pooling create new TCP connections for each request, adding TLS handshake overhead (50-100ms per request)
- DocuSign, Stripe, Checkr API calls without pooling cause resource exhaustion

**Recommendations:**
1. **Database Connection Pool Sizing**:
   - Set HikariCP `maximum-pool-size=50` for general API workload
   - Formula: `max_pool_size = (core_count × 2) + effective_spindle_count`
   - For 4 vCPU ECS tasks: 50 connections = (4 × 2 + 42) rounded for safety
   - Configure `minimum-idle=10` for baseline connections

2. **HTTP Client Connection Pooling**:
   - Configure RestTemplate/WebClient with connection pool: `maxConnections=200`, `maxConnectionsPerRoute=50`
   - Reuse HttpClient instances (singleton beans)
   - Set `validateAfterInactivity=5000` to prevent stale connections

3. **Connection Pool Monitoring**:
   - Export HikariCP metrics to CloudWatch: `hikaricp.connections.active`, `hikaricp.connections.pending`
   - Alert when active connections >80% of pool size
   - Alert when connection wait time >100ms

### S-4: Stateful Architecture Limiting Horizontal Scaling

**Issue Description:**
Section 3.3 describes JWT refresh token rotation, but there's no specification of where refresh tokens are stored. If stored in application memory (stateful sessions), this prevents horizontal scaling. Additionally, RabbitMQ message consumers may maintain in-memory job state.

**Performance Impact:**
- Stateful session storage requires sticky sessions, preventing effective load balancing
- Uneven load distribution across ECS tasks (some tasks at 90% CPU, others at 20%)
- Scaling out requires session migration or user re-authentication
- Container restarts invalidate all refresh tokens, forcing mass re-login
- Message processing state lost on container restart, causing job failures

**Recommendations:**
1. **Stateless Token Management**:
   - Store refresh tokens in Redis with TTL matching token expiration (7-30 days typical)
   - Key format: `refresh_token:{user_id}:{token_hash}`
   - On token refresh, atomically delete old token and store new token in Redis

2. **Stateless Job Processing**:
   - Store job state in database (Job table: job_id, type, status, payload, created_at)
   - RabbitMQ consumers update job status in database, not memory
   - Failed jobs can be retried by different consumer instances

3. **Session-less Architecture**:
   - Remove server-side session storage entirely
   - Use JWT claims for user context (user_id, role, organization_id)
   - Validate JWT signature on every request (cheap cryptographic operation: <1ms)

### S-5: Inefficient Financial Reporting Query Pattern

**Issue Description:**
Section 5.5 describes GET /api/v1/reports/owner-statement generating PDF statements with rental income, expenses, and net income for a specific month. With data model showing Property → Unit → Tenant → Payment relationships (Section 4), the query pattern likely involves:
1. Fetch all properties for owner
2. For each property, fetch units
3. For each unit, fetch tenants
4. For each tenant, fetch payments in date range
5. Aggregate results and generate PDF

**Performance Impact:**
- For owner with 20 properties × 5 units × 1 tenant = 100 tenants, this is 100+ queries
- Payment aggregation across 100 tenants for 1 month = 100 additional queries
- Total query time: 2-5 seconds before PDF generation
- PDF generation adds 1-3 seconds
- Total request time: 3-8 seconds, exceeding 500ms target by 6-16x

**Recommendations:**
1. **Materialized View for Owner Financials**:
   ```sql
   CREATE MATERIALIZED VIEW owner_monthly_financials AS
   SELECT p.owner_id,
          DATE_TRUNC('month', pay.payment_date) as month,
          SUM(pay.amount) FILTER (WHERE pay.status = 'COMPLETED') as total_collected,
          SUM(pay.amount) FILTER (WHERE pay.status = 'PENDING') as total_pending,
          COUNT(DISTINCT t.id) as tenant_count
   FROM Property p
   JOIN Unit u ON u.property_id = p.id
   JOIN Tenant t ON t.unit_id = u.id
   LEFT JOIN Payment pay ON pay.tenant_id = t.id
   GROUP BY p.owner_id, DATE_TRUNC('month', pay.payment_date);
   ```

2. **Scheduled Refresh**:
   - Refresh materialized view nightly at 2 AM via cron job
   - For current month, use real-time query with 15-minute cache TTL

3. **Pre-generated Reports**:
   - Background job generates PDF reports for all owners on 1st of month
   - Store PDFs in S3 with keys like `owner-statements/{owner_id}/{year}-{month}.pdf`
   - API endpoint returns pre-generated PDF URL if available, else triggers generation job

## Moderate Issues

### M-1: Suboptimal Pagination Implementation

**Issue Description:**
GET /api/v1/properties (Section 5.1) uses offset-based pagination with `page` and `size` parameters. For large property portfolios, offset-based pagination becomes inefficient as page numbers increase.

**Performance Impact:**
- Page 20 with size 25 (offset 500) requires database to scan 500 rows and discard them: `LIMIT 25 OFFSET 500`
- PostgreSQL must fetch 525 rows, sort them, then skip 500
- For properties sorted by created_at, this requires scanning 500+ rows even with index
- Query time increases linearly with page number: page 1 (20ms), page 10 (150ms), page 50 (800ms)

**Recommendations:**
1. Implement cursor-based pagination for property listings:
   - Response includes `next_cursor` token (encoded last property ID)
   - Next request uses `cursor` parameter instead of `page`: GET /api/v1/properties?cursor={token}&size=25
   - Query becomes: `SELECT * FROM Property WHERE id > :cursor ORDER BY id LIMIT 25`
   - Constant O(1) performance regardless of position in dataset

2. For UI requiring page numbers (e.g., "Page 3 of 20"), cache total count separately:
   - Cache property count per owner with 1-hour TTL
   - Show approximate page numbers: "Page ~3 of ~20" to avoid expensive COUNT(*) queries

### M-2: Lack of Read Replica Strategy

**Issue Description:**
Section 2.2 specifies "Multi-AZ deployment for RDS" but doesn't define read replica usage for read-heavy workloads. The usage scenarios (Section 1.4) indicate read-heavy patterns: property managers reviewing reports, tenants viewing payment history, daily maintenance request checks.

**Performance Impact:**
- All reads and writes hit primary RDS instance
- Report generation queries (occupancy analytics, financial summaries) compete for CPU/memory with transactional writes
- During monthly rent processing (1st of month), heavy write load degrades read performance
- Primary database CPU utilization spikes to 80-90% during report generation
- API response times increase from 200ms average to 2-3s during peak load

**Recommendations:**
1. **Read Replica Configuration**:
   - Deploy 1 read replica per AZ (2 total for Multi-AZ)
   - Configure Spring Boot with separate DataSource for read operations:
     - `@Transactional(readOnly=true)` routes to read replica
     - Write operations route to primary

2. **Query Routing Strategy**:
   - ReportingService queries → Read replica
   - Payment history queries → Read replica (tolerate <5s replication lag)
   - Property/Unit list queries → Read replica
   - Write operations (payments, maintenance requests) → Primary
   - Financial summaries requiring consistency → Primary

3. **Replication Lag Monitoring**:
   - Monitor `ReplicaLag` metric in CloudWatch (alert if >10 seconds)
   - Fallback to primary if replica lag exceeds 30 seconds

### M-3: Missing Query Result Caching for Reporting

**Issue Description:**
Section 5.5 describes occupancy reports (GET /api/v1/reports/occupancy) with date range parameters. Historical occupancy data doesn't change once the time period is past, but the design doesn't specify result caching.

**Performance Impact:**
- Occupancy report for Q1 2024 executes same complex aggregation query every time it's requested
- Query scans all lease records within date range and aggregates by property/unit
- For 500 properties, occupancy calculation requires scanning 2000+ lease records
- Query execution time: 1-3 seconds for historical date ranges
- Multiple users requesting same report execute redundant queries

**Recommendations:**
1. **HTTP Cache-Control Headers**:
   - For historical date ranges (end_date < today): `Cache-Control: public, max-age=86400` (24 hours)
   - For current month: `Cache-Control: private, max-age=900` (15 minutes)
   - CloudFront CDN caching based on query parameters

2. **Server-side Result Cache**:
   - Cache occupancy reports in Redis with key: `report:occupancy:{property_id}:{start_date}:{end_date}`
   - TTL: 24 hours for historical, 15 minutes for current period
   - Invalidate cache on lease modifications for affected date ranges

3. **Pre-computed Aggregates**:
   - Nightly job computes occupancy metrics for previous day
   - Store in `occupancy_metrics` table: property_id, date, occupancy_rate, vacant_units
   - Report queries use pre-computed table for historical data, real-time query only for current period

### M-4: File Upload Performance Constraints

**Issue Description:**
Section 7.1 specifies "File upload support up to 10 MB per document" but provides no details on upload mechanism. Section 3.2 shows DocumentService managing uploads, suggesting uploads go through Spring Boot application server before S3 storage.

**Performance Impact:**
- 10 MB file upload through application server consumes memory: 10 MB × 50 concurrent uploads = 500 MB heap
- Upload time at 10 Mbps connection: 8 seconds, holding API connection open
- Spring Boot request timeout (default 30s) may cut off large uploads on slow connections
- ECS task memory (typical 2-4 GB) constrains concurrent upload capacity
- Multipart file parsing in Spring Boot creates temporary files, consuming disk I/O

**Recommendations:**
1. **Presigned S3 URLs for Direct Upload**:
   - POST /api/v1/documents/upload-url returns presigned S3 PUT URL
   - Client uploads directly to S3 using presigned URL (bypassing application server)
   - Client calls POST /api/v1/documents with S3 key after successful upload
   - Benefits: No application server memory consumption, faster uploads, reduced backend load

2. **Chunked Upload for Large Files**:
   - Use S3 multipart upload API for files >5 MB
   - Split file into 5 MB chunks on client side
   - Upload chunks in parallel (3-5 concurrent connections)
   - 10 MB file uploads in 2-3 seconds instead of 8 seconds

3. **Upload Progress Tracking**:
   - Return upload_id from POST /api/v1/documents/upload-url
   - Polling endpoint GET /api/v1/documents/upload-status/{upload_id} for progress
   - WebSocket notification when upload completes and document record is created

### M-5: Inefficient Maintenance Request Status Polling

**Issue Description:**
Section 5.4 describes maintenance request workflow with status updates (SUBMITTED → ASSIGNED → IN_PROGRESS → COMPLETED). The design doesn't specify how users are notified of status changes. Typical pattern would be client-side polling: GET /api/v1/maintenance/requests/{id} every 5-10 seconds.

**Performance Impact:**
- 100 active maintenance requests × polling every 10 seconds = 600 requests/minute
- 90% of polling requests return "no change" (wasted database queries)
- Database load from status polling: 600 req/min × 20ms query time = 200 concurrent queries/second
- API Gateway rate limit (100 req/min per user) may be exhausted by polling alone

**Recommendations:**
1. **Server-Sent Events (SSE) for Status Updates**:
   - GET /api/v1/maintenance/requests/{id}/events endpoint returns SSE stream
   - Backend publishes status change events to Redis Pub/Sub
   - SSE handler subscribes to Redis channel and pushes events to client
   - Eliminates polling, reduces to 1 long-lived connection per active request

2. **WebSocket Alternative**:
   - If broader real-time features are needed, implement WebSocket connection
   - Client subscribes to maintenance request channel on connection
   - Backend pushes status updates through WebSocket

3. **Webhook Notifications**:
   - For contractor mobile apps, implement webhook delivery
   - POST status updates to contractor-provided webhook URL
   - Reduces mobile app background polling, improves battery life

## Minor Improvements & Positive Aspects

### Positive Aspects

**P-1: Appropriate Auto-scaling Configuration**
Section 7.3 specifies "Auto-scaling for ECS tasks based on CPU utilization (70% threshold)." This is a reasonable baseline, though could be enhanced with additional metrics (memory, request count, response time).

**P-2: Multi-AZ Deployment for High Availability**
Multi-AZ deployment for RDS and ECS (Section 7.3) ensures fault tolerance, reducing impact of single-AZ failures.

**P-3: JWT Short Expiration Reduces Token Theft Impact**
15-minute JWT expiration (Section 3.3) limits damage from token theft, though adds burden of frequent refresh.

**P-4: Structured Error Handling**
Standardized error response format (Section 6.1) enables consistent client-side error handling.

### Minor Improvements

**I-1: Database Connection Validation**
Consider adding connection validation query (`SELECT 1`) before borrowing from pool to detect stale connections: `spring.datasource.hikari.connection-test-query=SELECT 1`

**I-2: API Response Compression**
Enable GZIP compression for API responses >1 KB to reduce network transfer time: `server.compression.enabled=true`, `server.compression.mime-types=application/json`

**I-3: Prepared Statement Caching**
Enable PostgreSQL prepared statement caching to reduce query parsing overhead: `spring.jpa.properties.hibernate.query.plan_cache_max_size=2048`

**I-4: Lazy Loading Optimization**
Configure JPA fetch strategies to avoid default lazy loading N+1 problems: Use `@EntityGraph` or `JOIN FETCH` for known access patterns.

**I-5: S3 Transfer Acceleration**
For users in distant geographic regions, enable S3 Transfer Acceleration for faster document uploads/downloads (50-500% faster for international transfers).

## Summary of Recommended Priority Actions

**Immediate (Block Production Launch):**
1. Define and implement database indexing strategy (C-1)
2. Add query timeouts to prevent connection pool exhaustion (C-4)
3. Implement pagination on unbounded endpoints (C-3)

**High Priority (Deploy Within Sprint):**
1. Refactor financial summary to eliminate N+1 queries (C-2)
2. Define and implement Redis caching strategy (S-1)
3. Async processing for external API calls (S-2)
4. Configure database connection pooling (S-3)

**Medium Priority (Next Quarter):**
1. Implement read replica strategy (M-2)
2. Direct S3 uploads with presigned URLs (M-4)
3. Real-time notifications replacing polling (M-5)
4. Optimize financial reporting with materialized views (S-5)

**Performance Monitoring Requirements:**
- Database query performance (slow query log, >100ms threshold)
- Cache hit rates (target >80%)
- Connection pool utilization (alert at 80%)
- External API response times (p50, p95, p99)
- API endpoint latency distribution
- Auto-scaling trigger frequency
