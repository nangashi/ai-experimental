# Performance Design Review - Real Estate Property Management Platform

## Document Structure Analysis

The design document provides comprehensive coverage across multiple architectural dimensions:

**Explicitly Documented Sections:**
- System overview with clear usage scenarios and target user scale (50-500 properties per org)
- Technology stack with specific versions and infrastructure components
- Layered architecture with defined component responsibilities
- Detailed data model with entity relationships
- RESTful API design with endpoint specifications
- Non-functional requirements including performance targets and availability SLAs
- Security controls and data retention policies

**Notable Gaps:**
- Database indexing strategy not specified
- Caching implementation details limited (Redis mentioned but usage undefined)
- Data access patterns and query optimization strategy not detailed
- Monitoring and performance tracking approach not defined
- Capacity planning for data growth not addressed (particularly for historical data)

## Performance Issue Detection

### CRITICAL ISSUES

#### C1: Missing Database Index Strategy on High-Traffic Query Paths

**Location:** Section 4 (Data Model), Section 5 (API Design)

**Issue Description:**
The data model defines entity relationships but does not specify database indexes for frequently queried columns. Several API endpoints imply queries that will perform full table scans without proper indexing:

- `GET /api/v1/properties` filters by `owner_id` and `property_type` (Section 5.1) - no index specified on Property.owner_id or Property.property_type
- `GET /api/v1/tenants/{id}/payment-history` (Section 5.2) - no index on Payment.tenant_id
- Financial summary endpoint aggregating payments - no composite index on Payment.tenant_id + Payment.status + Payment.payment_date
- Maintenance request queries filtering by unit_id and status - no index on MaintenanceRequest.unit_id or MaintenanceRequest.status

**Performance Impact:**
Without indexes, PostgreSQL will perform sequential scans on these tables. For a property management company with 500 properties and average occupancy:
- ~500 properties × 20 units = 10,000 units
- ~10,000 tenants × 12 payments/year × 7 years retention = 840,000 payment records
- Full table scan on Payment table will degrade from <10ms (indexed) to 500-2000ms (sequential scan) as data accumulates

This directly threatens the "< 500ms average response time" SLA specified in Section 7.1.

**Recommendation:**
Define the following index strategy in the data model:

```sql
-- Property queries
CREATE INDEX idx_property_owner_id ON Property(owner_id);
CREATE INDEX idx_property_type ON Property(property_type);

-- Unit queries
CREATE INDEX idx_unit_property_id ON Unit(property_id);
CREATE INDEX idx_unit_status ON Unit(status);

-- Tenant queries
CREATE INDEX idx_tenant_user_id ON Tenant(user_id);
CREATE INDEX idx_tenant_unit_id ON Tenant(unit_id);

-- Payment queries (critical - high cardinality table)
CREATE INDEX idx_payment_tenant_id ON Payment(tenant_id);
CREATE INDEX idx_payment_status ON Payment(status);
CREATE INDEX idx_payment_date ON Payment(payment_date);
CREATE INDEX idx_payment_tenant_status_date ON Payment(tenant_id, status, payment_date DESC);

-- Maintenance queries
CREATE INDEX idx_maintenance_unit_id ON MaintenanceRequest(unit_id);
CREATE INDEX idx_maintenance_tenant_id ON MaintenanceRequest(tenant_id);
CREATE INDEX idx_maintenance_status ON MaintenanceRequest(status);
CREATE INDEX idx_maintenance_contractor_id ON MaintenanceRequest(contractor_id) WHERE contractor_id IS NOT NULL;

-- Document queries
CREATE INDEX idx_document_entity ON Document(entity_type, entity_id);
```

---

#### C2: Unbounded Data Growth Without Retention/Archival Strategy

**Location:** Section 7.4 (Data Retention)

**Issue Description:**
Section 7.4 specifies retention policies for some data types but contains a critical gap:

- Payment records retained for 7 years ✓
- Tenant applications retained for 3 years ✓
- **Maintenance request history retained indefinitely** ← Critical issue
- Deleted tenant data purged after 90 days ✓

The platform targets property managers handling 50-500 properties. For a mid-sized property management company:
- 200 properties × 20 units = 4,000 units
- Average 2 maintenance requests per unit per year = 8,000 maintenance requests/year
- After 10 years: 80,000 maintenance records with associated photos and updates

Additionally, the Payment table has a 7-year retention policy but no archival mechanism is defined. After 7 years:
- 4,000 tenants × 12 payments/year × 7 years = 336,000 active payment records
- Without partitioning or archival, all queries against Payment table will scan this entire dataset

**Performance Impact:**
- Database table size growth degrades query performance even with indexes (larger index tree traversal, reduced cache hit rates)
- Backup/restore operations become progressively slower (7-day retention specified in Section 7.3 means restores could take hours for multi-GB databases)
- Storage costs increase linearly without compression or tiering strategy

**Recommendation:**

1. **Define archival policy for maintenance requests:**
   - Archive maintenance requests older than 5 years to cold storage (AWS S3)
   - Maintain summary metadata in primary database for reporting, move detailed records to archive

2. **Implement table partitioning for Payment table:**
   ```sql
   -- Partition Payment table by payment_date (monthly partitions)
   CREATE TABLE Payment (
     ...
   ) PARTITION BY RANGE (payment_date);

   -- Create partitions for current + previous 7 years, drop partitions older than 7 years
   ```

3. **Implement automated data lifecycle:**
   - Scheduled job (monthly) to archive records beyond retention periods
   - Partition pruning to improve query performance on recent data
   - Compression strategy for archived data

---

#### C3: Synchronous External API Calls Blocking Request Threads

**Location:** Section 3.2 (Core Components), Section 5 (API Design)

**Issue Description:**
Multiple API endpoints perform synchronous calls to external services within the request-response path:

1. **Tenant Application Processing** (Section 5.2):
   - `POST /api/v1/tenants/applications` "triggers background check via Checkr API"
   - Response immediately includes `status: "PENDING"`, implying synchronous initiation
   - Checkr API calls typically take 2-5 seconds for real-time identity verification

2. **Payment Processing** (Section 5.3):
   - `POST /api/v1/payments/process` "calls Stripe API to process payment"
   - Section 7.1 specifies "payment processing should complete within 3 seconds"
   - Stripe API calls (payment intent creation + confirmation) typically take 1-2 seconds
   - No timeout configuration mentioned - risks thread exhaustion if Stripe is slow/unavailable

3. **Owner Statement Generation** (Section 5.5):
   - `GET /api/v1/reports/owner-statement` "generates PDF statement"
   - PDF generation is CPU-intensive and performs database queries for financial aggregation
   - No indication this is asynchronous despite being a batch-style operation

**Performance Impact:**
For 500 concurrent users (specified in Section 7.1) during peak hours:
- If 10% are processing payments concurrently (50 requests), each blocking for 2 seconds average
- With typical thread pool of 200 threads, sustained high payment volume could exhaust threads
- When Stripe experiences latency spikes (500ms → 5 seconds), request threads are blocked proportionally
- Missing timeout means indefinite blocking on network failures, causing cascading thread exhaustion

The architecture uses "ECS Fargate for compute" (Section 2.2) with likely default Spring Boot configuration (200 threads). Thread exhaustion will cause request queuing, violating the "< 500ms average response time" SLA.

**Recommendation:**

1. **Make external API calls asynchronous using RabbitMQ** (already in stack, Section 2.1):

   ```java
   // Tenant application - async background check
   @PostMapping("/api/v1/tenants/applications")
   public ResponseEntity<ApplicationResponse> submitApplication(@RequestBody ApplicationRequest request) {
       Application app = applicationService.createPendingApplication(request);
       messagingService.sendToQueue("background-check-queue", app.getId());
       return ResponseEntity.accepted().body(new ApplicationResponse(app.getId(), "PENDING"));
   }

   // Separate consumer processes background checks asynchronously
   @RabbitListener(queues = "background-check-queue")
   public void processBackgroundCheck(UUID applicationId) {
       // Call Checkr API here, update application status
   }
   ```

2. **Implement timeout configurations for all external API calls:**

   ```java
   // Stripe client configuration
   RestTemplate stripeClient = new RestTemplateBuilder()
       .setConnectTimeout(Duration.ofSeconds(2))
       .setReadTimeout(Duration.ofSeconds(5))
       .build();
   ```

3. **Move report generation to async job queue:**
   - `GET /api/v1/reports/owner-statement` should initiate PDF generation job and return job ID
   - Client polls separate endpoint for completion status and retrieves PDF URL when ready
   - Or use WebSocket for real-time notification when PDF is available

---

#### C4: Missing Connection Pooling Configuration

**Location:** Section 2.1 (Core Technologies), Section 3.3 (Data Flow)

**Issue Description:**
The design specifies "PostgreSQL 15" and "Database queries with JPA" but does not define database connection pooling configuration. Section 3.2 mentions "Integration Layer: External API clients with retry logic" but no connection pooling mentioned for Stripe/DocuSign/Checkr HTTP clients.

For database connections:
- Default HikariCP (Spring Boot default) settings may be insufficient for specified load
- Section 7.1 specifies 500 concurrent users during peak hours
- No specification of connection pool size, connection timeout, or idle timeout

For external HTTP clients:
- No connection pooling mentioned for Stripe/DocuSign/Checkr API clients
- Default Java HttpClient creates new connections per request (3-way TCP handshake + TLS handshake = 100-200ms overhead per call)

**Performance Impact:**
- **Database**: Without explicit pool sizing, default HikariCP pool size (10 connections) will cause connection starvation under 500 concurrent users
  - Connection acquisition timeout will cause requests to fail or queue
  - Violates "< 500ms average response time" SLA

- **External APIs**: Creating new HTTPS connections for each Stripe payment call adds 100-200ms latency
  - For target "payment processing within 3 seconds", this consumes 3-7% of latency budget unnecessarily
  - Stripe recommends connection pooling to avoid rate limiting

**Recommendation:**

1. **Define explicit HikariCP configuration** in application properties:

   ```yaml
   spring:
     datasource:
       hikari:
         maximum-pool-size: 50  # Based on expected concurrent DB operations
         minimum-idle: 10
         connection-timeout: 3000  # 3 seconds
         idle-timeout: 300000      # 5 minutes
         max-lifetime: 600000      # 10 minutes
         leak-detection-threshold: 60000  # Detect connection leaks
   ```

2. **Configure HTTP connection pooling for external API clients:**

   ```java
   // Stripe client with connection pooling
   PoolingHttpClientConnectionManager connectionManager =
       new PoolingHttpClientConnectionManager();
   connectionManager.setMaxTotal(100);
   connectionManager.setDefaultMaxPerRoute(20);

   CloseableHttpClient httpClient = HttpClients.custom()
       .setConnectionManager(connectionManager)
       .setKeepAliveStrategy((response, context) -> 30 * 1000)
       .build();
   ```

3. **Add monitoring for connection pool metrics:**
   - HikariCP pool active/idle connections
   - HTTP client connection pool utilization
   - Alert when pool utilization exceeds 80%

---

### SIGNIFICANT ISSUES

#### S1: N+1 Query Pattern in Financial Summary Endpoint

**Location:** Section 5.1 - `GET /api/v1/properties/{id}/financial-summary`

**Issue Description:**
The endpoint `GET /api/v1/properties/{id}/financial-summary` returns aggregated financial data:
```json
{
  "total_rent": number,
  "collected": number,
  "outstanding": number,
  "expenses": number
}
```

Based on the data model (Section 4), the likely implementation would be:
1. Fetch Property by ID
2. Fetch all Units for Property (1 query)
3. For each Unit, fetch associated Tenant (N queries - one per unit)
4. For each Tenant, fetch Payment records and aggregate (N queries - one per tenant)

For a property with 100 units:
- 1 query for property
- 1 query for units
- 100 queries for tenants (N+1 pattern #1)
- 100 queries for payment aggregation (N+1 pattern #2)
- **Total: 202 queries** for a single API request

**Performance Impact:**
Even with connection pooling and indexes, each query has overhead:
- 202 queries × 5ms average = 1,010ms total query time
- This exceeds the "< 500ms average response time" SLA specified in Section 7.1
- Under concurrent load (500 users), database CPU will spike due to excessive query volume

**Recommendation:**

Use JOIN queries or batch fetching to eliminate N+1 patterns:

```java
// Optimal implementation with single query
@Query("""
    SELECT new com.example.dto.FinancialSummary(
        COALESCE(SUM(t.monthly_rent), 0) as totalRent,
        COALESCE(SUM(CASE WHEN p.status = 'COMPLETED' THEN p.amount ELSE 0 END), 0) as collected,
        COALESCE(SUM(CASE WHEN p.status = 'PENDING' THEN p.amount ELSE 0 END), 0) as outstanding
    )
    FROM Property prop
    JOIN Unit u ON u.property_id = prop.id
    LEFT JOIN Tenant t ON t.unit_id = u.id
    LEFT JOIN Payment p ON p.tenant_id = t.id
    WHERE prop.id = :propertyId
    AND p.payment_date >= :startDate
    AND p.payment_date <= :endDate
""")
FinancialSummary getFinancialSummary(@Param("propertyId") UUID propertyId,
                                     @Param("startDate") LocalDate startDate,
                                     @Param("endDate") LocalDate endDate);
```

This reduces 202 queries to **1 query**, improving response time from ~1000ms to <50ms.

---

#### S2: Missing Redis Caching Strategy Despite Cache Layer in Stack

**Location:** Section 2.1 (Core Technologies), Section 3.2 (Core Components)

**Issue Description:**
Redis 7.0 is specified in the technology stack (Section 2.1) but no caching strategy is defined. Several use cases would benefit significantly from caching:

1. **Property listings** (`GET /api/v1/properties`):
   - Property data changes infrequently (address, unit count are mostly static)
   - Heavy read traffic (property managers reviewing portfolios multiple times daily)
   - No cache invalidation strategy defined

2. **Financial reports** (`GET /api/v1/reports/occupancy`, `/owner-statement`):
   - Computationally expensive aggregation queries across Payment and Tenant tables
   - Same reports often requested multiple times (monthly owner statements)
   - Reports are point-in-time snapshots - cacheable for the reporting period

3. **User session data**:
   - JWT tokens with 15-minute expiration (Section 3.3)
   - Validating token permissions on every API request requires database lookup for roles
   - Caching user permissions for token lifetime would reduce database load

**Performance Impact:**
Without caching:
- Financial report generation repeatedly executes expensive aggregation queries (potentially scanning hundreds of thousands of payment records)
- Property listing queries hit database on every request despite data rarely changing
- For 500 concurrent users, repeated identical queries waste database CPU

Opportunity cost:
- Effective caching could reduce database query volume by 40-60% for read-heavy operations
- Response times for cacheable endpoints could improve from 200-500ms to 10-50ms
- Database CPU could be reserved for write operations and complex transactional queries

**Recommendation:**

1. **Define caching strategy for frequently accessed, slowly changing data:**

   ```java
   // Property listings - cache for 1 hour
   @Cacheable(value = "properties", key = "#ownerId", unless = "#result == null")
   public List<Property> getPropertiesByOwner(UUID ownerId) {
       // Database query
   }

   // Invalidate cache on property update
   @CacheEvict(value = "properties", key = "#property.ownerId")
   public Property updateProperty(Property property) {
       // Save to database
   }
   ```

2. **Cache financial reports with time-based keys:**

   ```java
   // Owner statement - cache for 24 hours (monthly reports are static once generated)
   @Cacheable(value = "owner-statements",
              key = "#ownerId + '-' + #month + '-' + #year",
              unless = "#result == null")
   public OwnerStatement generateOwnerStatement(UUID ownerId, int month, int year) {
       // Expensive aggregation query
   }
   ```

3. **Cache user permissions for JWT token lifetime:**

   ```java
   // Cache permissions for 15 minutes (matches token expiration)
   @Cacheable(value = "user-permissions", key = "#userId",
              unless = "#result == null", ttl = 900) // 15 minutes in seconds
   public Set<Permission> getUserPermissions(UUID userId) {
       // Database query for roles and permissions
   }
   ```

4. **Define cache eviction policies:**
   - Properties: Evict on update/delete operations
   - Reports: Time-based expiration (no eviction needed - reports are immutable snapshots)
   - Permissions: Time-based expiration matching JWT token lifetime

---

#### S3: Missing Pagination Limits on Potentially Unbounded Queries

**Location:** Section 5.1, 5.2 (API Design)

**Issue Description:**
Several API endpoints return collections without documented maximum result limits:

1. `GET /api/v1/properties/{id}/units` - Returns "list of units for a specific property"
   - Commercial properties could have 100+ units
   - No pagination parameters specified

2. `GET /api/v1/tenants/{id}/payment-history` - Returns payment history
   - 7-year retention policy means single tenant could have 84 payment records (monthly payments)
   - No pagination specified - entire history returned in single response

3. `GET /api/v1/properties` has pagination (page, size parameters) ✓

The inconsistency suggests some endpoints may return unbounded results.

**Performance Impact:**
- Large result sets consume memory during serialization (potentially 1-10 MB per response for payment history with 7 years of data)
- Network transfer time increases linearly with response size
- Client-side rendering of large lists causes UI performance degradation
- Database query performance degrades when returning full result sets (no LIMIT clause optimization)

For payment history endpoint under 500 concurrent users:
- 50 concurrent payment history requests × 1 MB per response = 50 MB memory consumption
- Default Spring Boot max request size (2 MB) may be exceeded for users with extensive payment history
- Response serialization time increases from 10ms (paginated 20 records) to 200ms (full 84 records)

**Recommendation:**

1. **Add pagination to all collection endpoints:**

   ```java
   // Payment history endpoint
   @GetMapping("/api/v1/tenants/{id}/payment-history")
   public ResponseEntity<PaymentHistoryResponse> getPaymentHistory(
       @PathVariable UUID id,
       @RequestParam(defaultValue = "0") int page,
       @RequestParam(defaultValue = "20") int size,
       @RequestParam(defaultValue = "50") int maxSize  // Hard limit
   ) {
       size = Math.min(size, maxSize);  // Enforce maximum
       Page<Payment> payments = paymentService.getPaymentHistory(id, PageRequest.of(page, size));
       // Return paginated response
   }
   ```

2. **Document pagination parameters in API specification:**
   - Add to Section 5.2: "Query parameters: page (default: 0), size (default: 20, max: 50)"

3. **Set default and maximum page sizes:**
   - Default: 20 records (balances usability and performance)
   - Maximum: 50 records (prevents abuse and excessive memory consumption)

---

#### S4: Missing Timeout and Circuit Breaker Configuration for External APIs

**Location:** Section 3.2 (Integration Layer)

**Issue Description:**
Section 3.2 mentions "External API clients with retry logic" but does not specify:
- Timeout values for external API calls (Stripe, DocuSign, Checkr, SendGrid)
- Circuit breaker pattern to prevent cascading failures
- Retry strategy details (max retries, backoff strategy)

The system integrates with 4 external services (Section 2.3), each representing a potential failure point:
- **Stripe API**: Payment processing (critical path)
- **DocuSign API**: E-signature requests (less critical, asynchronous workflow)
- **Checkr API**: Background checks (asynchronous workflow)
- **SendGrid**: Email notifications (non-critical, can be queued)

**Performance Impact:**
Without proper timeout and circuit breaker configuration:

1. **Cascading failures**: If Stripe experiences an outage, requests to `/api/v1/payments/process` will hang indefinitely (or until default socket timeout of 60+ seconds)
   - For 500 concurrent users, sustained payment failures would exhaust all request threads within minutes
   - System becomes completely unavailable, not just payment processing

2. **Resource exhaustion**: Threads blocked waiting for slow/failing external APIs cannot serve other requests
   - Violates "99.5% availability" SLA (Section 7.3) - external service downtime cascades to platform downtime

3. **User experience degradation**: Long timeout values cause slow failures
   - Better to fail fast (2-3 second timeout) and show error message than hang for 60 seconds

**Recommendation:**

1. **Implement circuit breaker pattern using Resilience4j:**

   ```java
   @CircuitBreaker(name = "stripe", fallbackMethod = "paymentFallback")
   @Retry(name = "stripe")
   @Timeout(name = "stripe")
   public PaymentResult processPayment(PaymentRequest request) {
       return stripeClient.createPaymentIntent(request);
   }

   public PaymentResult paymentFallback(PaymentRequest request, Exception e) {
       // Log failure, return user-friendly error
       return PaymentResult.failed("Payment service temporarily unavailable. Please try again.");
   }
   ```

2. **Define timeout and retry configuration per service:**

   ```yaml
   resilience4j:
     circuitbreaker:
       instances:
         stripe:
           failure-rate-threshold: 50
           wait-duration-in-open-state: 30s
           sliding-window-size: 10
     retry:
       instances:
         stripe:
           max-attempts: 3
           wait-duration: 1s
           exponential-backoff-multiplier: 2
     timelimiter:
       instances:
         stripe:
           timeout-duration: 5s  # Fail fast for payment processing
         checkr:
           timeout-duration: 10s  # More lenient for background checks
   ```

3. **Implement degradation strategies:**
   - **Stripe (payment processing)**: Return error immediately, allow user to retry
   - **SendGrid (notifications)**: Queue failed emails for retry, don't block request
   - **DocuSign/Checkr**: Asynchronous workflows - timeout and retry in background job

---

#### S5: Stateful WebSocket Architecture Not Addressed for Real-Time Features

**Location:** Section 1.2 (Core Features), Section 3 (Architecture Design)

**Issue Description:**
The system requirements imply real-time notifications (Section 3.2: "NotificationService: Sends email/SMS notifications for payment reminders, request updates"), but the architecture only describes RESTful APIs and email/SMS notifications.

However, for optimal user experience in a property management platform, certain updates should be real-time:
- Maintenance request status updates (contractor accepts assignment → property manager sees immediate notification)
- Payment status updates (tenant pays rent → property manager dashboard updates instantly)
- New maintenance requests (tenant submits request → property manager sees notification without page refresh)

The architecture specifies:
- "ECS Fargate for compute" with "Auto-scaling based on CPU utilization" (Section 7.3)
- No mention of sticky sessions or stateful connection management
- No mention of WebSocket support or Server-Sent Events

**Scalability Impact:**
If WebSocket connections are added later without architectural planning:

1. **Stateful connections prevent horizontal scaling**:
   - WebSocket connections are persistent and stateful
   - ECS auto-scaling will create new containers, but existing WebSocket connections remain on old containers
   - No load balancing strategy defined for distributing persistent connections

2. **Connection scaling limits**:
   - Default AWS ALB supports 128,000 concurrent connections per target
   - For 500 concurrent users with WebSocket connections, this is sufficient
   - However, no planning for future growth to 5,000+ users

3. **Reconnection storm during deployments**:
   - Blue-green deployment (Section 6.4) will disconnect all WebSocket clients simultaneously
   - 500 concurrent users reconnecting simultaneously could overwhelm new containers
   - No gradual connection migration strategy

**Recommendation:**

1. **If real-time notifications are required, define WebSocket architecture:**

   ```java
   // Use Redis pub/sub for horizontal scaling
   @Configuration
   public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
       @Override
       public void configureMessageBroker(MessageBrokerRegistry config) {
           config.enableStompBrokerRelay("/topic")
               .setRelayHost("redis-host")
               .setRelayPort(6379);
       }
   }
   ```

2. **Use Redis as message broker for WebSocket scaling:**
   - Redis (already in stack) can act as pub/sub broker for distributing messages across ECS containers
   - Allows stateless WebSocket handling - any container can receive published messages

3. **Alternative: Use Server-Sent Events (SSE) if unidirectional updates are sufficient:**
   - Simpler than WebSocket (HTTP-based, easier load balancing)
   - Suitable for notification-style updates (server → client only)

4. **If real-time updates are not required:**
   - Document explicit decision to use polling or email/SMS only
   - Avoids future architecture mismatch when real-time features are requested

---

### MODERATE ISSUES

#### M1: Missing Query Optimization Strategy for Reporting Endpoints

**Location:** Section 5.5 (Reporting APIs)

**Issue Description:**
The reporting endpoints perform complex aggregations across large datasets:

1. `GET /api/v1/reports/occupancy` - Occupancy rate over time period
   - Requires joining Unit and Tenant tables
   - Calculating occupancy rate for each day/week in the time range
   - For 1-year report: 365 data points, each requiring count of occupied vs total units

2. `GET /api/v1/reports/owner-statement` - Monthly financial summary
   - Aggregates Payment records (potentially 1,000+ records for large portfolios)
   - Calculates rental income, expenses, net income
   - Generates PDF (CPU-intensive)

No optimization strategy is specified:
- No mention of pre-aggregated summary tables
- No read replicas for reporting queries (could offload from primary database)
- No query result caching strategy (reports are point-in-time snapshots)

**Performance Impact:**
Under concurrent load:
- Multiple property managers generating monthly owner statements simultaneously (end-of-month scenario)
- Each statement queries Payment table (840,000 records for 7-year retention)
- Aggregation queries consume database CPU, competing with transactional queries
- Could degrade response times for all API endpoints during reporting periods

**Recommendation:**

1. **Create materialized views or summary tables for reporting:**

   ```sql
   -- Monthly summary table (pre-aggregated)
   CREATE TABLE monthly_financial_summary (
       property_id UUID,
       month DATE,
       total_rent DECIMAL,
       collected DECIMAL,
       outstanding DECIMAL,
       expenses DECIMAL,
       PRIMARY KEY (property_id, month)
   );

   -- Updated monthly by scheduled job
   CREATE INDEX idx_monthly_summary_property ON monthly_financial_summary(property_id);
   ```

2. **Use database read replicas for reporting queries:**
   - Section 2.2 specifies "RDS for PostgreSQL"
   - Create read replica specifically for reporting workload
   - Route `/api/v1/reports/*` endpoints to read replica
   - Prevents reporting queries from impacting transactional performance

3. **Cache generated PDF reports:**
   - Once generated, monthly owner statements are immutable
   - Cache PDF in S3 with key: `owner-{ownerId}-statement-{year}-{month}.pdf`
   - Subsequent requests for same statement retrieve from cache (10ms) vs regenerating (2-5 seconds)

---

#### M2: Missing Database Connection Leak Detection and Monitoring

**Location:** Section 6.2 (Logging), Section 7.1 (Performance)

**Issue Description:**
The design specifies logging strategy (structured JSON logging, CloudWatch aggregation) but does not mention database connection monitoring or leak detection.

Common causes of connection leaks in JPA/Spring applications:
- Streams not closed in repository queries
- Manual transaction management without proper cleanup
- Exception handling that bypasses connection release

Without monitoring:
- Connection leaks accumulate silently until pool exhaustion
- First symptom is sudden request failures ("Cannot get JDBC connection")
- No proactive alerting before reaching critical state

**Performance Impact:**
- Connection pool exhaustion causes request failures (violates 99.5% availability SLA)
- Difficult to diagnose in production without proper monitoring
- Requires application restart to recover (downtime)

**Recommendation:**

1. **Enable HikariCP leak detection** (mentioned in C4 recommendation):

   ```yaml
   spring:
     datasource:
       hikari:
         leak-detection-threshold: 60000  # Warn if connection held >60s
   ```

2. **Add connection pool metrics to monitoring:**

   ```java
   @Configuration
   public class MetricsConfig {
       @Bean
       public MeterBinder hikariMetrics(DataSource dataSource) {
           return new HikariMetricsBinder((HikariDataSource) dataSource, "db-pool");
       }
   }
   ```

3. **Configure CloudWatch alarms:**
   - Alert when active connections > 80% of pool size
   - Alert on connection acquisition timeout errors
   - Alert on leak detection warnings

---

#### M3: Missing Bulk Operation Optimization for Batch Workflows

**Location:** Section 1.4 (Usage Scenarios), Section 5.3 (Payment APIs)

**Issue Description:**
Section 1.4 describes monthly automated workflows:
- "Monthly: Automated rent payment processing, late fee assessment, tenant communication"

For a property management company with 500 properties × 20 units = 10,000 tenants:
- Processing 10,000 rent payments monthly
- Assessing late fees for non-payment
- Sending payment reminder notifications

No bulk operation strategy is defined:
- No batch payment processing API
- No database batch insert/update optimization mentioned
- No discussion of job parallelization or queue-based processing

**Performance Impact:**
If implemented naively with individual API calls:
- 10,000 individual `POST /api/v1/payments/process` calls
- Each call: HTTP overhead + database insert + Stripe API call
- Sequential processing: 10,000 × 2 seconds = 5.5 hours total time
- Database: 10,000 individual INSERT statements vs 1 batch INSERT

**Recommendation:**

1. **Implement batch payment processing API:**

   ```java
   @PostMapping("/api/v1/payments/process-batch")
   public ResponseEntity<BatchPaymentResponse> processBatch(
       @RequestBody List<PaymentRequest> payments
   ) {
       // Process in parallel using RabbitMQ (already in stack)
       payments.forEach(payment ->
           messagingService.sendToQueue("payment-processing-queue", payment)
       );
       return ResponseEntity.accepted().body(new BatchPaymentResponse(jobId));
   }
   ```

2. **Use JPA batch operations for bulk database inserts:**

   ```yaml
   spring:
     jpa:
       properties:
         hibernate:
           jdbc.batch_size: 50
           order_inserts: true
           order_updates: true
   ```

3. **Parallelize batch jobs using RabbitMQ:**
   - Partition 10,000 payments into batches of 100
   - Multiple worker instances process queue in parallel
   - Reduces processing time from hours to minutes

---

#### M4: Missing Performance Testing and Capacity Planning Strategy

**Location:** Section 6.3 (Testing), Section 7.1 (Performance)

**Issue Description:**
Section 6.3 defines comprehensive testing strategy (unit tests, integration tests, E2E tests) but does not mention performance testing or load testing.

Section 7.1 specifies performance targets:
- "500 concurrent users during peak hours"
- "< 500ms average response time"
- "Payment processing within 3 seconds"

However, there is no validation strategy:
- How will these targets be verified before production deployment?
- What is the performance testing approach (load testing, stress testing, soak testing)?
- No mention of capacity planning for future growth

**Risk:**
- Performance targets are aspirational without validation
- Issues like connection pool exhaustion, thread starvation, or N+1 queries may only surface in production
- No baseline metrics to detect performance regressions during development

**Recommendation:**

1. **Add performance testing to CI/CD pipeline:**

   ```yaml
   # GitHub Actions workflow
   - name: Performance Test
     run: |
       # Use JMeter or Gatling for load testing
       mvn gatling:test -Dgatling.simulationClass=LoadTest

       # Assert performance targets
       # - 500 concurrent users
       # - 95th percentile response time < 500ms
   ```

2. **Define load test scenarios matching production usage:**

   ```scala
   // Gatling load test
   scenario("Peak Hour Load")
     .exec(
       http("List Properties").get("/api/v1/properties"),
       http("Get Financial Summary").get("/api/v1/properties/${propertyId}/financial-summary"),
       http("Submit Maintenance Request").post("/api/v1/maintenance/requests")
     )

   setUp(
     scenario.inject(
       rampUsers(500).during(60.seconds),  // Ramp to 500 concurrent users
       constantUsersPerSec(500).during(10.minutes)  // Sustain load
     )
   ).assertions(
     global.responseTime.percentile(95).lt(500),  // 95th percentile < 500ms
     global.successfulRequests.percent.gt(99.5)   // 99.5% success rate
   )
   ```

3. **Establish performance baseline and track trends:**
   - Store performance test results in time-series database
   - Track key metrics across releases (response time, throughput, error rate)
   - Alert on performance regressions (>10% increase in p95 latency)

---

#### M5: Inefficient Document Storage Pattern Without CDN Caching Strategy

**Location:** Section 2.2 (Infrastructure), Section 3.2 (DocumentService)

**Issue Description:**
The design specifies:
- "File Storage: AWS S3 for documents and images"
- "CDN: CloudFront for static assets" (Section 2.2)
- DocumentService "manages file uploads, storage in S3, retrieval" (Section 3.2)

However, it's unclear whether document retrieval uses CloudFront or direct S3 access:
- If direct S3 access: Latency varies by user location (50-200ms from S3, vs 10-50ms from CloudFront edge)
- No mention of CDN cache strategy for documents (time-to-live, invalidation)
- No discussion of signed URL expiration for secure document access

**Performance Impact:**
For document-heavy workflows (lease agreements, inspection reports):
- Direct S3 access from distant regions: 150-200ms latency
- CloudFront with edge caching: 10-50ms latency (3-4x improvement)
- Bandwidth costs: S3 data transfer pricing vs CloudFront pricing (CloudFront often cheaper for high-traffic files)

**Recommendation:**

1. **Route document retrieval through CloudFront:**

   ```java
   public String getDocumentUrl(UUID documentId) {
       Document doc = documentRepository.findById(documentId);

       // Generate signed CloudFront URL (not direct S3 URL)
       String cloudFrontUrl = "https://cdn.example.com/" + doc.s3Key;
       return signUrl(cloudFrontUrl, 1.hours);  // Signed URL expires in 1 hour
   }
   ```

2. **Configure CloudFront caching for immutable documents:**

   ```yaml
   # CloudFront cache behavior
   CacheBehavior:
     PathPattern: /documents/*
     CachePolicyId:
       MinTTL: 86400        # Cache for 1 day
       MaxTTL: 31536000     # Cache up to 1 year
       DefaultTTL: 86400
   ```

3. **Use S3 versioning for document updates:**
   - Documents are typically immutable (lease agreements don't change after signing)
   - If updates are needed, store new version with new S3 key
   - Old CloudFront cache entries remain valid (no invalidation needed)

---

### MINOR IMPROVEMENTS

#### I1: Consider Redis Pub/Sub for Real-Time Notification Distribution

**Location:** Section 3.2 (NotificationService)

**Issue Description:**
The NotificationService is defined as "Sends email/SMS notifications for payment reminders, request updates." This suggests a push-based notification system.

If real-time in-app notifications are added (e.g., property manager dashboard shows live updates), Redis (already in the stack) can be leveraged for pub/sub distribution across multiple ECS containers.

**Optimization Opportunity:**
Using Redis pub/sub allows:
- Efficient fan-out of notifications to multiple connected clients
- Horizontal scaling of WebSocket/SSE servers (notifications published to Redis, all containers receive)
- Decoupling of notification generation from delivery

**Recommendation:**
If real-time notifications are planned, document Redis pub/sub architecture:

```java
// Publish notification when maintenance request is created
redisTemplate.convertAndSend("notifications.property-manager." + propertyManagerId,
                             new MaintenanceRequestNotification(requestId));

// All containers subscribed to this channel receive notification and push to connected WebSocket clients
```

---

#### I2: Consider Database Connection Routing for Read/Write Splitting

**Location:** Section 2.2 (Infrastructure), Section 4 (Data Model)

**Issue Description:**
The architecture uses "RDS for PostgreSQL" but doesn't specify whether read replicas are used. Many operations are read-heavy (property listings, financial reports, payment history).

**Optimization Opportunity:**
- Configure Spring Boot to route read-only queries to read replicas
- Route transactional queries to primary instance
- Reduces load on primary database, improving write performance

**Recommendation:**

```java
@Configuration
public class DatabaseRoutingConfig {
    @Bean
    public DataSource dataSource() {
        RoutingDataSource routingDataSource = new RoutingDataSource();

        DataSource primary = primaryDataSource();
        DataSource readReplica = readReplicaDataSource();

        Map<Object, Object> dataSourceMap = new HashMap<>();
        dataSourceMap.put("primary", primary);
        dataSourceMap.put("read", readReplica);

        routingDataSource.setTargetDataSources(dataSourceMap);
        routingDataSource.setDefaultTargetDataSource(primary);

        return routingDataSource;
    }
}

// Use @Transactional(readOnly = true) for read queries to route to replica
@Transactional(readOnly = true)
public List<Property> getAllProperties() {
    // Routes to read replica
}
```

---

#### I3: Positive Design Aspects

The design demonstrates several strong performance-oriented practices:

1. **Explicit pagination on primary listing endpoint** (`GET /api/v1/properties` with page/size parameters) prevents unbounded result sets

2. **Appropriate technology choices**:
   - PostgreSQL for relational data with ACID guarantees
   - Redis for caching layer (though strategy needs definition)
   - RabbitMQ for asynchronous processing (though usage needs expansion)

3. **Data retention policies defined** (Section 7.4) showing awareness of long-term data growth (though execution strategy needs refinement)

4. **JWT with short expiration** (15 minutes) balances security and performance (reduces database lookups for session validation)

5. **Multi-AZ deployment and auto-scaling** (Section 7.3) shows scalability planning at infrastructure level

6. **Soft delete pattern** (deleted_at timestamp) allows data recovery without performance penalty of hard deletes with foreign key cascades

---

## Summary and Prioritization

### Critical Issues Requiring Immediate Attention (Before Implementation)

1. **Database indexing strategy** (C1) - Will cause immediate SLA violations as data grows
2. **Data retention/archival implementation** (C2) - Unbounded growth risks long-term viability
3. **Asynchronous external API calls** (C3) - Thread exhaustion risk under load
4. **Connection pooling configuration** (C4) - Will cause failures at specified 500 concurrent user load

### Significant Issues to Address During Design Phase

5. **N+1 query elimination** (S1) - Immediate impact on financial summary endpoint performance
6. **Redis caching strategy definition** (S2) - Significant optimization opportunity
7. **Pagination limits on all endpoints** (S3) - Prevents unbounded resource consumption
8. **Circuit breakers and timeouts** (S4) - Essential for 99.5% availability SLA
9. **WebSocket architecture planning** (S5) - If real-time features are required

### Moderate Issues to Address During Implementation

10. **Query optimization for reporting** (M1)
11. **Connection leak detection** (M2)
12. **Bulk operation optimization** (M3)
13. **Performance testing strategy** (M4)
14. **CDN strategy for documents** (M5)

### Overall Assessment

The design document provides a solid foundation with appropriate technology choices and clear awareness of scalability requirements (multi-AZ, auto-scaling, data retention policies). However, critical performance implementation details are missing, particularly around database optimization (indexing, query patterns), connection management, and external API resilience.

The most significant risk is the gap between defined SLAs (500ms response time, 99.5% availability) and the architectural details needed to achieve them (indexing, caching, connection pooling, circuit breakers). Addressing the 4 critical issues and 5 significant issues before implementation will substantially improve the likelihood of meeting performance targets in production.

**Estimated Performance Impact of Addressing Critical Issues:**
- C1 (Indexing): 80-90% improvement in query-heavy endpoints (500ms → 50-100ms)
- C2 (Archival): Prevents long-term degradation, maintains query performance as data ages
- C3 (Async APIs): Prevents thread exhaustion, enables handling 500 concurrent users
- C4 (Connection pooling): Enables target load, prevents connection starvation

With these issues addressed, the architecture can confidently support the specified load of 500 concurrent users with <500ms response times.
