# Answer Key - Round 014

## Execution Context
- **Perspective**: performance
- **Target**: design
- **Embedded Issues**: 9 problems

## Embedded Issues

### P01: Missing Performance Requirements / SLA Definition
- **Category**: Performance Requirements (NFR)
- **Severity**: Critical
- **Location**: Section 7.1 Performance
- **Issue Description**: Performance targets are partially defined (response time < 500ms, payment processing < 3s) but lack comprehensive SLA definition including throughput requirements, percentile-based response time targets (p50, p95, p99), and concurrent transaction capacity. Expected load (500 concurrent users) is mentioned but without corresponding throughput targets (requests per second), making capacity planning and scalability validation impossible.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of throughput SLA (e.g., requests per second, transactions per minute) or percentile-based response time targets (p95, p99) for critical operations (payment processing, report generation, search queries). Explicitly mentions that average response time alone is insufficient for SLA definition.
  - △ (Partial Detection): Mentions performance requirements are incomplete or vague, but does not specifically identify the lack of throughput targets or percentile-based metrics.
  - × (Not Detected): No mention of performance requirements or SLA definition issues.

### P02: N+1 Query Problem in Property Financial Summary
- **Category**: I/O & Network Efficiency
- **Severity**: Critical
- **Location**: Section 5.1 - GET /api/v1/properties/{id}/financial-summary
- **Issue Description**: The financial summary API endpoint aggregates total rent, collected amounts, outstanding payments, and expenses for a property. Without explicit mention of join queries or aggregation strategy, this design implies fetching property units individually, then fetching tenants and payments for each unit, resulting in N+1 queries (1 property query + N unit queries + M tenant queries + P payment queries). For properties with 50-100 units, this creates severe database load and response time degradation.
- **Detection Criteria**:
  - ○ (Detected): Identifies that the financial summary endpoint will trigger N+1 queries when aggregating data from property → units → tenants → payments hierarchy, and explicitly recommends using JOIN queries or database-level aggregation (e.g., SUM, GROUP BY) to fetch data in a single query.
  - △ (Partial Detection): Mentions potential inefficiency in data aggregation or query optimization for financial reporting without specifically identifying the N+1 query pattern in the property-unit-tenant-payment hierarchy.
  - × (Not Detected): No mention of query efficiency issues in financial summary or reporting endpoints.

### P03: Missing Cache Strategy
- **Category**: Cache & Memory Management
- **Severity**: Critical
- **Severity Justification**: Frequently accessed property and tenant data without caching will cause excessive database load. Redis is mentioned in tech stack but no usage strategy is defined, leading to performance degradation under load.
- **Location**: Section 2.1 Technology Stack (Redis listed) and Section 3.3 Data Flow (no cache layer mentioned)
- **Issue Description**: Redis is listed in the technology stack but cache strategy is undefined. Property portfolio data, tenant profiles, and unit availability status are frequently read operations that would benefit from caching. No mention of cache invalidation strategy, TTL settings, or cache-aside pattern implementation.
- **Detection Criteria**:
  - ○ (Detected): Points out that Redis is listed but no cache strategy is defined for frequently accessed data (property listings, tenant profiles, unit availability). Recommends implementing cache-aside or read-through pattern with appropriate TTL and invalidation strategy.
  - △ (Partial Detection): Mentions caching would improve performance but does not identify that Redis is already listed in tech stack without usage strategy, or lacks specific cache implementation recommendations.
  - × (Not Detected): No mention of caching strategy or Redis usage.

### P04: Unbounded Query in Payment History API
- **Category**: I/O & Network Efficiency
- **Severity**: Significant
- **Location**: Section 5.2 - GET /api/v1/tenants/{id}/payment-history
- **Issue Description**: The payment history endpoint returns all payments for a tenant without pagination or date range filtering. For long-term tenants (3-5 years of monthly payments = 36-60 records), this grows unbounded. Combined with Section 7.4's 7-year payment retention policy, a single tenant could have 84+ payment records. Without pagination, response payload size increases linearly, degrading API performance and client-side rendering.
- **Detection Criteria**:
  - ○ (Detected): Identifies that the payment history endpoint lacks pagination or date range filtering, and points out that with 7-year retention policy, this will result in unbounded query results and large response payloads. Recommends adding pagination (page, size parameters) or date range filtering.
  - △ (Partial Detection): Mentions pagination is needed for payment history or queries in general without specifically connecting to the 7-year retention policy and the unbounded growth problem.
  - × (Not Detected): No mention of unbounded query issues or pagination requirements.

### P05: Synchronous External API Call in Tenant Application Flow
- **Category**: Latency & Throughput Design
- **Severity**: Significant
- **Location**: Section 5.2 - POST /api/v1/tenants/applications
- **Issue Description**: The tenant application endpoint "triggers background check via Checkr API" during request processing. External API calls to Checkr (background check service) typically take 3-15 seconds due to third-party processing time. Executing this synchronously blocks the HTTP request thread, degrading API throughput and creating poor user experience. During peak application periods (first week of month), this blocks critical server resources.
- **Detection Criteria**:
  - ○ (Detected): Identifies that the background check API call to Checkr should be asynchronous (e.g., using message queue like RabbitMQ which is listed in tech stack) to avoid blocking HTTP request threads. Explicitly mentions the long execution time of external API calls (3-15 seconds) and the need for immediate response with status polling or webhook callback.
  - △ (Partial Detection): Mentions external API calls should be asynchronous or optimized but does not specifically identify the Checkr background check call as a blocking operation or recommend specific async implementation (message queue, webhook).
  - × (Not Detected): No mention of asynchronous processing or external API call optimization.

### P06: Missing Database Index Design
- **Category**: Latency & Throughput Design
- **Severity**: Significant
- **Location**: Section 4 Data Model
- **Issue Description**: No index design is specified for high-frequency query columns. Critical query patterns include: property lookup by owner_id (GET /api/v1/properties), unit lookup by property_id and status (vacancy search), tenant lookup by unit_id (lease retrieval), payment lookup by tenant_id and payment_date (payment history, reporting), maintenance request lookup by unit_id and status (request tracking). Without indexes on these foreign keys and composite columns, table scans will occur as data grows beyond 10,000 records per table, severely degrading query performance.
- **Detection Criteria**:
  - ○ (Detected): Identifies specific columns that require indexes based on API query patterns (e.g., owner_id in Property, property_id + status in Unit, tenant_id + payment_date in Payment, unit_id + status in MaintenanceRequest). Mentions that without indexes, performance will degrade as data volume grows.
  - △ (Partial Detection): Mentions index design is missing or important for query performance without identifying specific tables/columns that need indexing based on the documented query patterns.
  - × (Not Detected): No mention of database indexing or query optimization at the database level.

### P07: Missing Time-Series Data Growth Strategy
- **Category**: Scalability Design
- **Severity**: Significant
- **Location**: Section 4.1 Data Model - Payment and MaintenanceRequest tables, Section 7.4 Data Retention
- **Issue Description**: Payment records (retained for 7 years per Section 7.4) and maintenance request history (retained indefinitely per Section 7.4) will grow unbounded over time. For an organization managing 500 properties with 50 units each (25,000 units), assuming 90% occupancy, monthly payment records alone generate 22,500 records/month = 270,000 records/year = 1.89 million records over 7 years. No partitioning strategy (time-based table partitioning, archival to cold storage) or read-write separation is defined. As the payment and maintenance request tables grow beyond 1 million rows, query performance for reporting and search will degrade significantly.
- **Detection Criteria**:
  - ○ (Detected): Identifies that payment and maintenance request data will grow indefinitely (or for 7 years per retention policy) and recommends time-based table partitioning, data archival strategy, or read-write separation (e.g., CQRS with read replicas for reporting queries). Explicitly mentions the long-term data volume growth problem.
  - △ (Partial Detection): Mentions data retention or archival strategy is needed without specifically identifying the time-series data growth problem in payment and maintenance request tables or recommending partitioning/archival solutions.
  - × (Not Detected): No mention of data lifecycle, archival, or time-series data management.

### P08: Missing File Upload Batch Processing for Documents
- **Category**: I/O & Network Efficiency
- **Severity**: Significant
- **Location**: Section 3.2 DocumentService, Section 5 API Design (no document upload API specified)
- **Issue Description**: DocumentService manages file uploads to S3 (Section 3.2), and Section 7.1 specifies support for 10 MB documents. However, no document upload API is defined in Section 5, and no mention of multi-file upload or batch processing capability. Common scenarios (lease signing, property inspection) require uploading multiple documents simultaneously (lease agreement + income verification + ID documents = 3-5 files). Processing each file sequentially (separate S3 PutObject calls per file) creates network round-trip overhead and poor user experience. No mention of multipart upload for large files or batch upload optimization.
- **Detection Criteria**:
  - ○ (Detected): Identifies that document upload scenarios involve multiple files (lease workflow, inspection reports) and recommends batch upload processing (concurrent S3 uploads) or multipart upload for large files (> 5 MB). Mentions reducing network round-trips for multiple file uploads.
  - △ (Partial Detection): Mentions file upload optimization or S3 upload efficiency without specifically identifying the multi-file upload scenario or recommending batch processing.
  - × (Not Detected): No mention of file upload optimization or S3 upload efficiency.

### P09: Missing Concurrent Rent Payment Handling Strategy
- **Category**: Latency & Throughput Design
- **Severity**: Medium
- **Location**: Section 5.3 - POST /api/v1/payments/process
- **Issue Description**: No mention of race condition handling when processing rent payments. During peak payment periods (1st-5th of month, due to monthly rent cycle), thousands of tenants submit payments concurrently. If a tenant double-clicks the payment button or network retry occurs, duplicate payment processing could happen. Without optimistic locking, database-level uniqueness constraints (tenant_id + payment_month composite unique index), or idempotency key validation, duplicate charges to Stripe may occur. Section 3.3 mentions transaction management but doesn't specify concurrency control strategy for payment processing.
- **Detection Criteria**:
  - ○ (Detected): Identifies the risk of duplicate payment processing during concurrent requests (double-click, network retry) and recommends idempotency key implementation, optimistic locking, or database uniqueness constraints (e.g., tenant_id + payment_month unique index) to prevent duplicate charges.
  - △ (Partial Detection): Mentions concurrency control or transaction isolation is needed for payment processing without specifically identifying duplicate payment risk or recommending idempotency key / uniqueness constraint implementation.
  - × (Not Detected): No mention of concurrent payment handling or race condition prevention.

## Bonus Issues

Bonus issues are detection opportunities for out-of-scope but valuable observations. Award +0.5 points for each detected bonus issue (non-duplicate, valid concern).

| ID | Category | Issue | Bonus Condition |
|----|---------|-------|----------------|
| B01 | I/O Efficiency | Connection pooling not explicitly configured for RDS PostgreSQL | Mentions connection pool sizing or configuration for database connections beyond generic "transaction management" |
| B02 | Scalability | No horizontal scaling strategy for stateful components (RabbitMQ, Redis) | Points out that Redis/RabbitMQ are single points of failure or lack clustering/replication strategy |
| B03 | Latency | Static asset delivery optimization missing | Recommends CloudFront configuration for React SPA bundle optimization (compression, cache headers) or image optimization |
| B04 | Throughput | API rate limiting (100 req/min) may be insufficient during peak load | Points out that 500 concurrent users × API calls per workflow may exceed 100 req/min per user limit |
| B05 | I/O Efficiency | Batch notification sending via SendGrid not mentioned | Recommends batching email notifications (payment reminders, maintenance updates) instead of individual API calls |
| B06 | Monitoring | Performance monitoring metrics not defined | Points out missing APM metrics (database query latency, external API call duration, cache hit rate) for performance tracking |
| B07 | Cache | Redis cache eviction policy not specified | Mentions LRU/LFU eviction policy configuration or cache memory limits |
| B08 | Scalability | Read replica for reporting queries not considered | Recommends read-write separation for heavy reporting workloads (owner statements, occupancy reports) |
