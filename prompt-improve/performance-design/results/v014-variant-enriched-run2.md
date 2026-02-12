# Performance Design Review: Real Estate Property Management Platform

## Document Structure Analysis

The design document provides comprehensive coverage across most architectural concerns:

**Present sections:**
- System overview with user scale (50-500 properties per organization)
- Technology stack (Spring Boot, PostgreSQL, Redis, RabbitMQ)
- Layered architecture with defined components
- Complete data model with entity relationships
- RESTful API specifications
- NFR section with performance targets (500 concurrent users, <500ms API response, 3s payment processing)
- Infrastructure design (AWS ECS, RDS, multi-AZ deployment)
- Auto-scaling configuration (CPU-based at 70% threshold)

**Missing or incomplete aspects:**
- Database indexing strategy for query optimization
- Specific caching strategy and cache invalidation patterns
- Data access implementation details (potential N+1 query risks)
- Batch processing vs. synchronous processing boundaries
- Monitoring and observability strategy beyond basic logging
- Capacity planning for data growth over time
- Connection pooling configuration

## Performance Issue Detection

### Critical Issues

#### C1. Missing Database Indexing Strategy

**Location:** Section 4 (Data Model), Section 5.1-5.5 (API Design)

**Issue Description:**
The data model defines seven core entities with various foreign key relationships, but no database indexes are specified. Multiple API endpoints execute queries with filtering and sorting that will cause full table scans as data volumes grow:

- `/api/v1/properties` filters by `owner_id` and `property_type` (Section 5.1)
- `/api/v1/tenants/{id}/payment-history` queries Payment table by `tenant_id` (Section 5.2)
- `/api/v1/properties/{id}/financial-summary` requires aggregation across Property → Unit → Tenant → Payment relationships (Section 5.1)
- `/api/v1/reports/occupancy` filters by `property_id` and date range (Section 5.5)

**Impact Analysis:**
For a property management company managing 500 properties with an average of 20 units each (10,000 units), with 5 years of payment history at 12 payments/year, the Payment table will contain 600,000 records. Without an index on `tenant_id`:
- Payment history queries will degrade from <10ms to 500-1000ms as the table grows
- Financial summary aggregations will execute multiple unindexed queries, potentially exceeding the 500ms target
- At scale (multiple organizations), these queries will cause database CPU saturation during peak hours (9-11 AM, 5-7 PM with 500 concurrent users)

**Recommendations:**
1. Add composite index on Payment(`tenant_id`, `payment_date`) to optimize payment history queries and date-based aggregations
2. Add index on Unit(`property_id`, `status`) to optimize property unit listings and vacancy calculations
3. Add index on MaintenanceRequest(`unit_id`, `status`, `created_at`) to optimize maintenance request filtering and status-based queries
4. Add index on Tenant(`unit_id`) to support the 1:1 current lease lookup
5. Add index on Property(`owner_id`, `property_type`) to optimize the property listing query
6. Add index on Document(`entity_type`, `entity_id`) to optimize document retrieval by entity

#### C2. N+1 Query Risk in Financial Summary Endpoint

**Location:** Section 5.1 (`GET /api/v1/properties/{id}/financial-summary`)

**Issue Description:**
The financial summary endpoint aggregates data across a four-level entity hierarchy (Property → Unit → Tenant → Payment). The typical JPA implementation pattern would load the property, iterate through units, load each unit's tenant, then iterate through each tenant's payments. This creates a cascading N+1 query problem.

**Impact Analysis:**
For a property with 50 units:
1. 1 query to load Property
2. 50 queries to load each Unit's Tenant relationship
3. 50 queries to aggregate Payments for each Tenant
Total: 101 database round-trips

At 10ms per query (optimistic with indexes), this operation would take 1010ms, exceeding the 500ms target. During peak hours with 500 concurrent users, if 10% are property managers viewing dashboards, this creates 50 concurrent multi-second queries, saturating database connection pools (typical pool size: 10-20 connections).

**Recommendations:**
1. Implement a single aggregation query using SQL JOIN across Property → Unit → Tenant → Payment relationships with SUM aggregations
2. Use Spring Data JPA's `@Query` annotation with native SQL or JPQL JOIN FETCH to execute as a single database round-trip
3. Consider caching financial summaries with 15-minute TTL (data changes infrequently, acceptable for dashboard views)
4. Example query structure:
```sql
SELECT
  SUM(p.amount) FILTER (WHERE p.status = 'COMPLETED') as total_collected,
  SUM(p.amount) FILTER (WHERE p.status = 'PENDING') as outstanding
FROM Property prop
JOIN Unit u ON u.property_id = prop.id
JOIN Tenant t ON t.unit_id = u.id
LEFT JOIN Payment p ON p.tenant_id = t.id
WHERE prop.id = ? AND t.lease_end_date > CURRENT_DATE
```

#### C3. Missing Data Retention and Archival Strategy

**Location:** Section 7.4 (Data Retention)

**Issue Description:**
The document specifies retention policies (7 years for payments, 3 years for applications, indefinite for maintenance requests) but provides no implementation strategy for archiving or partitioning historical data. The Payment table will grow unboundedly:

- 500 properties × 20 units × 12 payments/year × 7 years = 840,000 payment records per organization
- If the platform serves 100 organizations, this scales to 84 million payment records
- Maintenance requests are retained "indefinitely," creating similar unbounded growth

**Impact Analysis:**
Unbounded table growth causes multiple performance degradations:
1. **Query performance:** Even indexed queries slow down as table size increases. B-tree indexes become deeper, requiring more I/O operations.
2. **Backup duration:** PostgreSQL pg_dump operations will grow from minutes to hours, potentially exceeding backup windows
3. **Index maintenance:** INSERT/UPDATE operations slow down as indexes grow larger
4. **Vacuum operations:** PostgreSQL autovacuum will take longer, potentially causing table bloat

For an 84-million-row Payment table:
- Table size: ~10 GB (assuming 120 bytes per row)
- Index size: ~3 GB per index (3 indexes = 9 GB)
- Query performance degradation: 2-3x slower than a partitioned table with current-year data

**Recommendations:**
1. Implement PostgreSQL table partitioning for Payment table by year using declarative partitioning:
   - Active partition: current year + prior year (for queries spanning year boundary)
   - Archive partitions: older years on separate tablespace or moved to cold storage
2. Implement MaintenanceRequest partitioning by status and created year:
   - Hot partition: SUBMITTED, ASSIGNED, IN_PROGRESS (current operations)
   - Warm partition: COMPLETED requests from last 2 years
   - Cold partition: COMPLETED requests older than 2 years
3. Configure partition pruning to ensure queries only scan relevant partitions
4. Implement automated archive job to move completed maintenance requests older than 2 years to S3 in Parquet format for compliance/analytics
5. Add TTL-based deletion for soft-deleted records (currently 90-day retention) using background job

#### C4. Synchronous External API Calls on Request Path

**Location:** Section 5.2 (POST `/api/v1/tenants/applications`), Section 5.3 (POST `/api/v1/payments/process`)

**Issue Description:**
Two critical user-facing API endpoints make synchronous calls to external services on the request path:

1. Tenant application endpoint "triggers background check via Checkr API" (Section 5.2) - despite the word "background," the implementation description suggests synchronous triggering
2. Payment processing endpoint "calls Stripe API to process payment" (Section 5.3)

External API calls typically have 500ms-2s latency (network + processing), plus risk of timeout/failure.

**Impact Analysis:**

**Payment Processing:**
- Stripe API latency: 500-1500ms typical, up to 3s for 3D Secure flows
- Target: 3 seconds (Section 7.1) - leaves minimal margin for retries or fallback logic
- If Stripe experiences degraded performance (99th percentile latency spikes), payment requests will time out, blocking user transactions
- During month-end payment rush (when automated payments execute), concurrent Stripe calls will consume all available request threads

**Tenant Application:**
- Checkr API latency: 1-3 seconds for initial submission, longer for full background check
- No explicit timeout configuration mentioned (Section 3.3 mentions "retry logic" but not timeouts)
- Risk: A slow or hanging Checkr API call could block the request thread indefinitely, exhausting the thread pool

**Recommendations:**
1. **Payment Processing:**
   - Return immediate response to user with `status: "PROCESSING"` and payment_id
   - Execute Stripe API call asynchronously using RabbitMQ (already in stack, Section 2.1)
   - Implement webhook handler for Stripe payment status updates
   - Update Payment status via webhook callback, notify user via NotificationService
   - This reduces user-facing latency from 500-1500ms to <100ms (database write only)

2. **Tenant Application:**
   - Submit Checkr API request asynchronously via background job
   - Return `status: "PENDING"` immediately to applicant
   - Implement Checkr webhook to receive background check results
   - Notify property manager when results are available (Section 2.3 SendGrid integration)

3. **Timeout Configuration:**
   - Add explicit timeout configuration for all external API clients (Stripe, DocuSign, Checkr, SendGrid)
   - Recommended: 5s connection timeout, 10s read timeout for external APIs
   - Implement circuit breaker pattern (e.g., Resilience4j) to prevent cascading failures when external services are degraded

### Significant Issues

#### S1. Missing Connection Pooling Configuration

**Location:** Section 3.3 (Data Flow), Section 2.1 (Technology Stack)

**Issue Description:**
The architecture specifies "Database queries with JPA" (Section 3.3) and PostgreSQL 15 as the database (Section 2.1), but no connection pool configuration is documented. Spring Boot uses HikariCP by default, but the sizing and timeout configuration directly impact performance under load.

**Impact Analysis:**
With 500 concurrent users (Section 7.1) and typical web application behavior (5% concurrent database operations), the system needs to handle 25 concurrent queries during peak load. Default HikariCP configuration (10 connections) will cause connection starvation:

- Requests exceeding pool size will block waiting for available connections
- Default connection timeout (30 seconds) is far too long for interactive operations
- Under-provisioned pools cause request thread exhaustion as threads block on connection acquisition

If the financial summary endpoint (Issue C2) is not optimized and executes 100+ queries, it will monopolize the entire connection pool, starving other operations.

**Recommendations:**
1. Configure HikariCP connection pool explicitly:
   - Maximum pool size: 20 connections (based on expected concurrent query load)
   - Minimum idle connections: 10 (to avoid connection establishment latency)
   - Connection timeout: 5000ms (fail fast rather than blocking request threads)
   - Max lifetime: 30 minutes (to handle database connection recycling)
   - Leak detection threshold: 60 seconds (to identify connection leaks during development)

2. Implement connection pool monitoring via Spring Boot Actuator metrics:
   - Expose `hikaricp.connections.active`, `hikaricp.connections.pending` metrics
   - Alert when active connections exceed 80% of pool size (indicates need to scale)

3. Configure separate connection pool for reporting queries (owner statements, occupancy reports) to prevent long-running analytical queries from blocking transactional operations

#### S2. Missing Caching Strategy for Frequently Accessed Data

**Location:** Section 2.1 mentions Redis 7.0 but Section 3 (Architecture Design) provides no caching implementation details

**Issue Description:**
Redis is included in the technology stack (Section 2.1) but the architecture design does not specify what data is cached, cache invalidation strategies, or TTL policies. Several data access patterns are ideal caching candidates:

1. **Property metadata:** Property and Unit entities are read frequently (every dashboard load, financial summary) but change rarely
2. **User authentication data:** JWT validation requires user/role lookups on every authenticated request
3. **Owner statements:** PDF generation (Section 5.5) is computationally expensive but statements are immutable once generated for a past month

**Impact Analysis:**
Without caching:
- Property dashboard loads execute 5-10 database queries per page load
- Financial summaries re-query Property/Unit data on every request
- Owner statement PDF generation repeats expensive aggregations for identical requests

With 500 concurrent users during peak hours:
- 50-100 property managers loading dashboards = 250-1000 queries/second just for property metadata
- This load is entirely avoidable through caching

**Recommendations:**
1. **Property/Unit Caching:**
   - Cache Property and Unit entities by ID with 1-hour TTL (data changes infrequently)
   - Invalidate cache on property/unit updates using Spring Cache `@CacheEvict`
   - Estimated impact: Reduces dashboard query load by 60-70%

2. **Financial Summary Caching:**
   - Cache financial summary results by property_id with 15-minute TTL
   - Acceptable staleness: Dashboard data does not need real-time accuracy
   - Invalidate on payment status change for the specific property
   - Estimated impact: Reduces multi-table aggregation queries by 80-90% during peak hours

3. **Owner Statement Caching:**
   - Cache generated PDF URLs by (owner_id, month, year) indefinitely (historical statements are immutable)
   - Store S3 key in Redis to avoid re-generating PDFs for identical requests
   - Estimated impact: Eliminates redundant PDF generation (expensive report aggregations + PDF rendering)

4. **Authentication Caching:**
   - Cache User entity and roles by user_id with 15-minute TTL (matches JWT expiration)
   - Invalidate on role/permission changes
   - Estimated impact: Reduces authentication query load by 95%

5. **Cache Eviction Strategy:**
   - Configure Redis `maxmemory-policy: allkeys-lru` to prevent memory exhaustion
   - Set `maxmemory` to 1-2 GB (sufficient for metadata caching at expected scale)
   - Monitor cache hit rate via Redis INFO stats (target: >80% hit rate for property metadata)

#### S3. Missing Capacity Planning for Real-Time Communication Scalability

**Location:** Section 3.2 (NotificationService), Section 5.4 (Maintenance APIs)

**Issue Description:**
The NotificationService sends email/SMS notifications for payment reminders and maintenance request updates (Section 3.2). Several scenarios involve broadcasting to multiple recipients:

1. **Automated rent reminders:** Monthly job sends reminders to all tenants (Section 1.4: "Monthly: Automated rent payment processing, late fee assessment, tenant communication")
2. **Maintenance status updates:** Notifies tenant and property manager when contractor updates request status

With 500 properties × 20 units = 10,000 tenants per organization, a monthly reminder job sends 10,000 emails. If the platform serves 100 organizations, this scales to 1 million emails/month (33,000/day during month-end).

**Impact Analysis:**
SendGrid free tier: 100 emails/day. Even paid plans have rate limits (e.g., Enterprise plan: ~1,000 emails/second).

Without rate limiting and queuing:
- Synchronous email sending on month-end will take hours (33,000 emails at 10/second = 55 minutes per organization)
- If notifications are sent synchronously on the request path, maintenance update API calls will block for 100-500ms per SendGrid API call
- Concurrent month-end jobs across 100 organizations will hit SendGrid rate limits, causing 429 errors and notification failures

**Recommendations:**
1. Implement asynchronous notification delivery using RabbitMQ (already in stack):
   - PublishNotificationEvent to queue instead of direct SendGrid API call
   - Separate consumer processes notifications with rate limiting (10 emails/second)
   - Implement retry logic with exponential backoff for SendGrid 429 errors

2. Batch notification jobs:
   - Schedule monthly reminder job to execute over 4-hour window (not all at once)
   - Spread load: Process 2,500 tenants/hour instead of 10,000 concurrent requests
   - Use database pagination to process tenants in batches of 100

3. Implement notification throttling:
   - Track SendGrid API rate limit consumption via Redis counter
   - Implement leaky bucket algorithm to smooth burst traffic
   - Configure separate queue priorities (URGENT for password resets, NORMAL for payment reminders, LOW for marketing)

4. Add notification delivery monitoring:
   - Track delivery success/failure rates by notification type
   - Alert on delivery failure rate >5% (indicates SendGrid API issues or rate limiting)
   - Implement dead letter queue for failed notifications with manual review process

#### S4. Report Generation Blocking Request Threads

**Location:** Section 5.5 (`GET /api/v1/reports/owner-statement`)

**Issue Description:**
The owner statement endpoint "generates PDF statement with rental income, expenses, net income" and returns a statement URL (Section 5.5). PDF generation involves:
1. Multi-table aggregation query (Property → Unit → Tenant → Payment + expenses)
2. Data transformation and calculation (net income, expense categorization)
3. PDF rendering (CPU-intensive operation)

These operations are executed synchronously on the request path (no mention of asynchronous processing).

**Impact Analysis:**
Owner statement generation complexity:
- Database aggregation: 200-500ms for a property with 50 units and 1 year of data
- PDF rendering: 500-1000ms for a 5-page statement (depending on library: iText, PDFBox)
- Total: 1-2 seconds per statement

With 500 properties and property managers generating statements weekly (Section 1.4: "Weekly: Property manager reviews financial reports, generates owner statements"):
- ~500 statement requests/week = ~70/day
- If property managers generate statements interactively during peak hours (morning review workflow)
- ~10-20 concurrent statement requests during 9-11 AM peak
- 10 concurrent 2-second PDF renders = 20 seconds of CPU time, blocking 10 request threads for extended duration

This causes:
1. Request thread pool exhaustion (typical thread pool: 200 threads, 10 blocked for 2s each reduces available capacity by 5%)
2. Increased API response time for all concurrent requests (thread starvation)
3. Database connection pool pressure (long-running aggregation queries hold connections)

**Recommendations:**
1. Implement asynchronous PDF generation:
   - Return immediate response with `status: "GENERATING"` and report_id
   - Submit PDF generation job to RabbitMQ
   - Worker process generates PDF, uploads to S3, updates status to "READY"
   - Frontend polls `/api/v1/reports/{report_id}/status` or uses WebSocket for completion notification

2. Cache generated reports:
   - Historical statements (prior months) are immutable - cache indefinitely
   - Store S3 key in database indexed by (owner_id, month, year)
   - Check cache before generating: if statement exists for requested month, return immediately

3. Implement report generation rate limiting:
   - Limit to 5 concurrent PDF generation jobs per organization (prevent resource exhaustion)
   - Queue additional requests for sequential processing
   - Estimated impact: Prevents CPU saturation during peak usage

4. Optimize PDF generation:
   - Pre-aggregate monthly payment data in nightly batch job (eliminates real-time aggregation)
   - Store monthly rollup summaries: `MonthlyPropertySummary(property_id, year, month, total_rent, total_expenses, net_income)`
   - PDF generation queries summary table (fast) instead of aggregating 600,000 payment records
   - Estimated impact: Reduces PDF generation latency from 1-2s to <500ms

### Moderate Issues

#### M1. Inefficient Pagination Implementation

**Location:** Section 5.1 (`GET /api/v1/properties`), Section 3.3 (Data Flow)

**Issue Description:**
The property listing API supports pagination with `page` and `size` query parameters (Section 5.1) but no pagination strategy is specified. Common JPA pagination patterns have performance characteristics that degrade with page offset:

- **OFFSET/LIMIT pattern:** `SELECT * FROM property OFFSET 1000 LIMIT 20` requires scanning and discarding 1000 rows
- For deep pagination (page 50 of 20 items/page = offset 1000), database scans 1020 rows to return 20

**Impact Analysis:**
For a property management company with 500 properties:
- Page 1 (offset 0): 10ms query time
- Page 10 (offset 200): 15ms query time
- Page 25 (offset 500): 25ms query time (2.5x degradation)

While 25ms is still acceptable, the pattern degrades linearly with offset. If pagination is used for reporting/export workflows (e.g., exporting all properties), deep pagination becomes prohibitively slow.

**Recommendations:**
1. Implement cursor-based pagination for forward traversal:
   - Replace `page` parameter with `cursor` (last seen property ID)
   - Query: `SELECT * FROM property WHERE id > ? ORDER BY id LIMIT 20`
   - This maintains constant query time regardless of dataset size
   - Trade-off: Cannot jump to arbitrary pages (acceptable for most use cases)

2. Keep offset-based pagination for UI display (user rarely navigates beyond page 5):
   - Limit maximum offset to 200 (10 pages of 20 items)
   - Return error for deeper pages with message: "Use search filters to narrow results"

3. Add total count caching:
   - Response includes `total: number` which requires `COUNT(*)` query
   - Cache count by filter combination (owner_id, property_type) with 5-minute TTL
   - Avoids redundant count queries on every page navigation

#### M2. Missing Query Timeout Configuration

**Location:** Section 3.3 (Data Flow), Section 6.1 (Error Handling)

**Issue Description:**
The architecture describes "Database queries with JPA" (Section 3.3) but no query timeout configuration is specified. Long-running queries (e.g., unoptimized aggregations, missing indexes) can block database connections indefinitely.

**Impact Analysis:**
Without query timeouts:
- A single unoptimized query (e.g., unindexed financial summary) can hold a database connection for 10+ seconds
- With 20-connection pool (Issue S1 recommendation), 2-3 slow queries can exhaust 10-15% of capacity
- Cascading effect: Other queries queue waiting for connections, increasing end-to-end latency

Example scenario:
1. Property manager runs unoptimized financial summary query (10s duration)
2. Query holds database connection for 10s
3. 5 concurrent requests arrive, all execute slow queries
4. Connection pool saturates (all 20 connections in use)
5. New requests block waiting for connections, causing timeout errors

**Recommendations:**
1. Configure JPA query timeout globally:
   ```yaml
   spring.jpa.properties.javax.persistence.query.timeout: 5000  # 5 seconds
   ```

2. Set statement timeout at PostgreSQL level as fallback:
   ```sql
   ALTER DATABASE property_management SET statement_timeout = '10s';
   ```

3. Override timeout for known long-running queries (reports):
   ```java
   @QueryHints(@QueryHint(name = "javax.persistence.query.timeout", value = "30000"))
   ```

4. Implement slow query logging:
   - Log queries exceeding 1 second with full SQL + parameters
   - Use `log_min_duration_statement = 1000` in PostgreSQL configuration
   - Alert on slow query frequency >10/hour (indicates missing index or N+1 problem)

#### M3. Lack of Monitoring and Observability Strategy

**Location:** Section 6.2 (Logging), Section 7 (Non-Functional Requirements)

**Issue Description:**
The document specifies structured logging (Section 6.2) and health check endpoints (Section 6.4), but no comprehensive monitoring strategy for performance observability:

- No mention of latency percentile tracking (p50, p95, p99)
- No database query performance monitoring
- No external API latency tracking (Stripe, DocuSign, Checkr)
- No cache hit rate monitoring
- No connection pool utilization metrics

**Impact Analysis:**
Without performance monitoring:
- Performance degradations go unnoticed until users complain
- No data to validate whether <500ms API target (Section 7.1) is achieved in production
- Cannot identify which APIs or queries are slow
- Capacity planning decisions are based on guesswork instead of data
- Incident response lacks diagnostic data (e.g., "Was the database slow or was Stripe slow?")

**Recommendations:**
1. Implement request latency tracking with percentiles:
   - Instrument all API endpoints with Micrometer metrics
   - Track p50, p95, p99 latency by endpoint and HTTP status code
   - Alert on p95 latency exceeding 500ms for >5 minutes

2. Add database query performance monitoring:
   - Enable Spring Boot Actuator database metrics (query count, query duration)
   - Track slow queries via PostgreSQL `pg_stat_statements` extension
   - Dashboard: Top 10 slowest queries by total time and call frequency

3. Instrument external API calls:
   - Track latency and error rate for each external service (Stripe, DocuSign, Checkr, SendGrid)
   - Implement distributed tracing with Spring Cloud Sleuth + Zipkin
   - Identify which external dependency contributes most to end-to-end latency

4. Monitor cache effectiveness:
   - Track Redis cache hit rate, miss rate, and eviction rate
   - Alert on hit rate <80% (indicates cache misconfiguration or insufficient TTL)
   - Monitor Redis memory usage and key count

5. Add infrastructure metrics:
   - ECS task CPU/memory utilization (already configured for auto-scaling, Section 7.3)
   - RDS CPU/memory/IOPS utilization
   - Connection pool active/idle/waiting connections

6. Implement centralized metrics dashboard:
   - Use CloudWatch Dashboards or Grafana to visualize metrics
   - Create SLO dashboard tracking compliance with <500ms API target
   - Week-over-week latency trend charts to detect gradual performance degradation

#### M4. Concurrency Control Gaps in Payment Processing

**Location:** Section 5.3 (Payment APIs), Section 4.1 (Payment entity)

**Issue Description:**
The Payment entity includes status transitions (PENDING → COMPLETED/FAILED) but no concurrency control mechanism is specified. Potential race conditions:

1. **Duplicate payment processing:** If a user double-clicks "Submit Payment" and two concurrent requests are processed, both might create separate Payment records and call Stripe API twice
2. **Concurrent status updates:** Webhook handler updating payment status concurrently with user-initiated retry could cause status inconsistency

**Impact Analysis:**
Without idempotency controls:
- Users could be double-charged (Stripe API called twice for same logical payment)
- Payment status could flip between COMPLETED and FAILED if webhook arrives during retry attempt
- Difficult to debug: "Did the payment succeed or fail?" becomes ambiguous

Financial impact:
- Double charging 1% of payments = 120 double charges/year per organization (10,000 tenants × 12 payments × 0.01)
- Even with refund process, this creates customer dissatisfaction and support overhead

**Recommendations:**
1. Implement idempotency key for payment processing:
   ```java
   @PostMapping("/api/v1/payments/process")
   public PaymentResponse processPayment(@RequestBody PaymentRequest request) {
       String idempotencyKey = generateKey(request.tenant_id, request.amount, request.payment_date);
       // Check if payment with this key already exists
       Payment existing = paymentRepository.findByIdempotencyKey(idempotencyKey);
       if (existing != null) {
           return PaymentResponse.from(existing);  // Return existing result
       }
       // Process payment...
   }
   ```

2. Add unique constraint on Payment entity:
   - Composite unique index: `(tenant_id, payment_date, amount)` for monthly rent payments
   - Database constraint prevents duplicate payment insertion even if application logic fails

3. Use optimistic locking for payment status updates:
   ```java
   @Entity
   public class Payment {
       @Version
       private Long version;  // JPA optimistic locking
       // ...
   }
   ```
   - Prevents concurrent status updates from overwriting each other
   - Update will fail with OptimisticLockException if version mismatch, triggering retry

4. Implement Stripe idempotency headers:
   - Stripe API supports `Idempotency-Key` header to prevent duplicate charges
   - Generate key from `payment_id` and include in Stripe API call
   - Even if application calls Stripe twice, Stripe deduplicates based on idempotency key

5. Add payment processing state machine:
   - Define valid transitions: PENDING → PROCESSING → COMPLETED/FAILED
   - Reject invalid transitions (e.g., COMPLETED → PENDING)
   - Prevents status corruption from race conditions

#### M5. Auto-Scaling Configuration Lacks Leading Indicators

**Location:** Section 7.3 (Availability & Scalability)

**Issue Description:**
The document specifies "Auto-scaling for ECS tasks based on CPU utilization (70% threshold)" but CPU is a lagging indicator of load. By the time CPU reaches 70%, request latency has already degraded significantly.

**Impact Analysis:**
CPU-based scaling reaction time:
1. Traffic spike occurs (0:00)
2. CPU utilization increases to 70% (0:30 - 1:00)
3. Auto-scaling triggers (1:00)
4. New ECS task launches and becomes ready (1:30 - 2:00)
5. Load balancer routes traffic to new task (2:00)

Total delay: 2-3 minutes from spike to capacity increase. During this window:
- Request latency increases as existing tasks are overloaded
- Users experience slow page loads or timeouts
- Potential violation of 500ms API target (Section 7.1)

**Recommendations:**
1. Implement request-based scaling in addition to CPU-based:
   - Scale on Application Load Balancer RequestCountPerTarget metric
   - Threshold: 500 requests/minute per ECS task (assumes 500ms average latency = 4 concurrent requests)
   - This triggers scaling before CPU saturation occurs

2. Use target tracking scaling with multiple metrics:
   - Primary: ALB RequestCountPerTarget (leading indicator)
   - Secondary: ECS CPU utilization 70% (safety threshold)
   - Tertiary: Custom metric - p95 latency >500ms (SLO violation trigger)

3. Implement scheduled scaling for predictable peaks:
   - Section 7.1 specifies peak hours: 9-11 AM, 5-7 PM
   - Pre-scale to 2x capacity at 8:45 AM and 4:45 PM
   - Scale down at 11:30 AM and 7:30 PM
   - Eliminates cold start delay during known high-traffic periods

4. Configure aggressive scale-out, conservative scale-in:
   - Scale out: Add 2 tasks when threshold exceeded (rapid capacity increase)
   - Scale in: Remove 1 task at a time with 10-minute cooldown (gradual reduction)
   - Prevents thrashing (rapid scale up/down cycles)

5. Set minimum task count appropriately:
   - Minimum: 2 tasks (multi-AZ deployment, Section 7.3)
   - Maximum: 20 tasks (handles 10,000 req/min at 500 req/min per task)
   - Reserve capacity: Run at 50-60% utilization during steady state to handle micro-bursts

## Positive Architectural Decisions

The design demonstrates several strong performance-oriented choices:

1. **Technology stack alignment:** PostgreSQL 15 with proper indexing (once added per recommendations) is well-suited for transactional workloads with complex queries. Redis provides high-performance caching layer.

2. **Multi-AZ deployment:** Section 7.3 specifies multi-AZ for both RDS and ECS, ensuring availability without sacrificing performance during single-AZ failures.

3. **Connection reuse through AWS infrastructure:** Using ECS Fargate with RDS in same VPC minimizes network latency between application and database tiers.

4. **Async processing infrastructure:** RabbitMQ inclusion in stack (Section 2.1) provides foundation for async processing, though not yet utilized in API design.

5. **Realistic performance targets:** <500ms API response time and 3s payment processing (Section 7.1) are achievable with recommended optimizations.

6. **Document storage on S3:** Offloading binary storage from database (Section 2.2) prevents database bloat and leverages S3's scalability.

## Summary

The design document provides a solid architectural foundation with realistic performance targets and appropriate technology selections. However, critical gaps in database optimization, caching strategy, and asynchronous processing patterns must be addressed before production deployment:

**Must-Fix Before Production (Critical):**
- C1: Database indexing strategy for all query patterns
- C2: Eliminate N+1 queries in financial summary endpoint
- C3: Implement data partitioning/archival for unbounded table growth
- C4: Move external API calls (Stripe, Checkr) to asynchronous processing

**High-Priority Optimizations (Significant):**
- S1: Connection pooling configuration and monitoring
- S2: Implement caching strategy for property metadata and financial summaries
- S3: Asynchronous notification delivery with rate limiting
- S4: Move PDF generation to background jobs

**Performance Improvements (Moderate):**
- M1: Cursor-based pagination for large result sets
- M2: Query timeout configuration to prevent connection starvation
- M3: Comprehensive monitoring (latency percentiles, slow queries, cache hit rates)
- M4: Idempotency controls for payment processing
- M5: Request-based auto-scaling with predictable peak handling

**Estimated Impact:** Implementing critical and significant recommendations will reduce average API latency by 60-70% (from ~800ms to <300ms for complex operations) and enable the system to scale to 5-10x current target load (500 → 2500-5000 concurrent users) without architectural changes.
