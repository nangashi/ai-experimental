# Performance Design Review - Round 015 Baseline Run 2

## Document Structure Analysis

The design document covers:
- **Present**: Overview, technology stack, architecture design, data model, API design, implementation details, NFR specifications
- **Architecture aspects documented**: Microservices architecture, component dependencies, data flow, authentication/authorization
- **Infrastructure**: AWS deployment (ECS Fargate, RDS, ElastiCache), load balancing, CDN, blue-green deployment
- **Missing/Incomplete**: Specific performance SLAs (latency targets, throughput requirements), capacity planning details, detailed caching strategy, connection pooling configuration

## Performance Issues Detected (Critical-First Order)

### CRITICAL ISSUES

#### C1. Missing Performance SLAs and Capacity Planning
**Severity**: Critical
**Location**: Section 7 (NFR) - Performance targets not specified

The design lacks explicit performance targets despite being a "large-scale" platform serving "millions of daily active users":
- No latency SLA for search operations (critical for UX)
- No throughput requirements (requests per second)
- No concurrent user handling targets
- No data volume planning (how many millions of products?)

**Impact**: Without defined performance targets, it's impossible to validate whether the current architecture can meet business requirements. The system may be over-engineered or critically under-provisioned.

**Recommendation**:
- Define explicit SLAs: Search latency (e.g., p95 < 200ms), recommendation latency (e.g., p95 < 500ms)
- Specify throughput targets: Peak search QPS, recommendation requests per minute
- Document expected data scale: Product count, daily interaction events, review volume growth
- Create capacity model based on these targets to validate infrastructure sizing

---

#### C2. N+1 Query Problem in Search Results
**Severity**: Critical
**Location**: Section 6 (Product Search Implementation, lines 184-189)

The search implementation has a severe N+1 query antipattern:
> "For each product in the results, the service fetches full details from PostgreSQL"

For a typical search returning 20 products, this creates 21 database queries (1 for Elasticsearch + 20 individual PostgreSQL queries).

**Impact**:
- At scale (thousands of concurrent searches), this creates massive database load
- Linear scaling problem: 100 concurrent searches = 2000+ database queries
- Database connection pool exhaustion risk
- Unacceptable search latency (assuming 10ms per query = 200ms+ just for database access)

**Recommendation**:
- Implement batch fetching: Single PostgreSQL query with `WHERE product_id IN (...)` for all search results
- Store essential product details directly in Elasticsearch index to eliminate PostgreSQL queries for search results
- Use Redis caching for frequently accessed product details with TTL based on update frequency

---

#### C3. Unbounded Database Query in Price Alert Processing
**Severity**: Critical
**Location**: Section 6 (Price Alert Processing, line 210)

The scheduled job retrieves "all active price alerts from the database" without pagination or batching:

**Impact**:
- As the platform scales, active alerts could reach millions
- Single query loading millions of rows causes:
  - Memory exhaustion (OOM in application server)
  - Database query timeout
  - Prolonged table lock preventing other operations
- 15-minute processing window may be insufficient at scale

**Recommendation**:
- Implement cursor-based pagination: Process alerts in batches (e.g., 1000 at a time)
- Add database index on `(status, created_at)` for efficient filtering
- Consider distributed processing: Partition alerts by user_id hash and process in parallel workers
- Add circuit breaker: If batch processing takes >10 minutes, pause and resume next cycle

---

#### C4. Real-Time Rating Calculation Without Aggregation
**Severity**: Critical
**Location**: Section 6 (Review Aggregation, lines 202-206)

Rating aggregation is computed on-demand for every product display:
> "When displaying a product, the system queries all reviews for that product"

**Impact**:
- For popular products with thousands of reviews, every product view triggers a full table scan
- Popular product pages become bottlenecks (e.g., homepage featuring 50 products = 50 aggregation queries)
- Database CPU saturation under traffic spikes
- Exponential cost as review volume grows

**Recommendation**:
- Pre-calculate and store aggregated ratings in Product table (`avg_rating`, `review_count` columns)
- Update aggregates incrementally on review submission using database triggers or application logic
- Cache aggregated ratings in Redis with 5-minute TTL
- Add database index on `(product_id, created_at)` for Review table

---

### SIGNIFICANT ISSUES

#### S1. Missing Database Connection Pooling Configuration
**Severity**: Significant
**Location**: Section 2 (Technology Stack) - Database configuration not specified

The document mentions "Spring Data JPA for database access" but doesn't specify connection pooling:

**Impact**:
- Default HikariCP settings may be insufficient for high-traffic scenarios
- Connection exhaustion under load causes cascading failures
- Without tuning, connection timeout errors affect user experience

**Recommendation**:
- Explicitly configure HikariCP pool size based on service instance count and expected load:
  - Formula: `connections_per_instance = (core_count * 2) + effective_spindle_count`
  - For 10 service instances with 4 cores: minimum 100 connections
- Set connection timeout (30s), max lifetime (30 min), idle timeout (10 min)
- Monitor connection pool metrics (active, idle, waiting threads) in CloudWatch

---

#### S2. Missing Elasticsearch Index on Critical Query Fields
**Severity**: Significant
**Location**: Section 4 (Data Model) and Section 5 (API Design)

PostgreSQL indexes are not defined for frequently queried foreign keys and filter columns:

**Missing indexes**:
- `Review.product_id` (for rating aggregation)
- `UserInteraction.user_id` (for recommendation generation)
- `UserInteraction.timestamp` (for recent interaction queries)
- `PriceAlert.status` (for scheduled job filtering)
- `Product.category_id` (for category filtering)

**Impact**:
- Full table scans for common operations (review lookup, interaction history)
- Recommendation service latency degrades as UserInteraction table grows
- Price alert job becomes slower over time

**Recommendation**:
```sql
CREATE INDEX idx_review_product_id ON Review(product_id);
CREATE INDEX idx_review_product_created ON Review(product_id, created_at);
CREATE INDEX idx_interaction_user ON UserInteraction(user_id, timestamp DESC);
CREATE INDEX idx_interaction_product ON UserInteraction(product_id, timestamp DESC);
CREATE INDEX idx_alert_status ON PriceAlert(status, created_at);
CREATE INDEX idx_product_category ON Product(category_id);
```

---

#### S3. Inefficient Recommendation Algorithm Implementation
**Severity**: Significant
**Location**: Section 6 (Recommendation Engine, lines 191-200)

The recommendation process has multiple performance issues:
1. "Retrieves user's interaction history from PostgreSQL" (unbounded query)
2. "Fetches similar users' purchase patterns from PostgreSQL" (N+1 problem)
3. "Calculates similarity scores for all products" (O(n) computation per request)

**Impact**:
- Recommendation latency increases linearly with product catalog size
- For 1M products, computing similarity for all products per request is infeasible
- Database queries dominate response time (network + query execution)
- No ability to serve recommendations at low latency (<100ms)

**Recommendation**:
- Pre-compute user similarity matrices offline (batch job every 6-24 hours)
- Store top-N similar users per user in Redis: `user:{id}:similar_users`
- Pre-compute product affinities and store in Redis: `user:{id}:recommendations`
- Use approximate nearest neighbor algorithms (e.g., FAISS, Annoy) for real-time scoring
- Limit interaction history query: Only recent 90 days, max 1000 interactions per user
- Implement result caching: 15-minute TTL for recommendation lists

---

#### S4. Synchronous Kafka Event Consumption in Critical Path
**Severity**: Significant
**Location**: Section 3 (Data Flow, line 68) and Section 6 (Recommendation Engine, line 194)

User interactions are published to Kafka and consumed by Recommendation Service, but the architecture doesn't clarify if this is asynchronous:

**Concern**: If user interaction events block the user-facing request:
- Kafka producer latency (10-50ms) adds to every product view
- Kafka cluster issues directly impact frontend performance
- User experience degrades with event processing delays

**Impact**:
- Increased latency for user-facing operations (product views, clicks)
- Coupled availability: Kafka downtime breaks core functionality
- Recommendation model updates lag in real-time scenarios

**Recommendation**:
- Ensure Kafka publishing is **fully asynchronous** (fire-and-forget with local buffering)
- Use separate thread pool for event publishing to avoid blocking request threads
- Implement circuit breaker: Degrade gracefully if Kafka is unavailable (log events locally for replay)
- Document event processing SLA separately (e.g., "Recommendations reflect interactions within 5 minutes")

---

#### S5. Shared Redis Cache Without Partitioning Strategy
**Severity**: Significant
**Location**: Section 3 (Component Dependencies, line 61) - "All services → Redis (shared cache)"

All microservices share a single Redis instance/cluster without documented partitioning:

**Impact**:
- Cache key collisions between services (namespace conflicts)
- No isolation: One service's cache stampede affects all services
- Single Redis instance becomes bottleneck for all services
- Memory eviction policy affects unrelated services (LRU evicts critical keys)
- No ability to scale cache independently per service

**Recommendation**:
- Implement logical database separation: Use Redis database numbers (0-15) or keyspace prefixes per service
  - `product:*` for Product Service
  - `search:*` for Search Service
  - `recommendations:*` for Recommendation Service
- Consider deploying separate Redis clusters per service for critical services (Search, Recommendation)
- Define cache eviction policies per use case:
  - Product details: TTL 10 minutes, volatile-ttl eviction
  - Recommendations: TTL 15 minutes, allkeys-lru eviction
- Document cache capacity planning: Expected cache size, hit rate targets

---

### MODERATE ISSUES

#### M1. Missing Timeout Configuration for External Calls
**Severity**: Moderate
**Location**: Section 6 (Error Handling, line 219)

The document mentions "Circuit breaker pattern for external service calls" but doesn't specify timeout configurations:

**Impact**:
- Without explicit timeouts, hanging connections consume resources indefinitely
- Thread pool exhaustion from blocked threads
- Cascading latency propagation across services

**Recommendation**:
- Define timeout hierarchy:
  - Elasticsearch queries: 1s read timeout
  - PostgreSQL queries: 5s statement timeout
  - Inter-service HTTP calls: 3s connection timeout, 10s read timeout
  - Kafka producer: 5s send timeout
- Implement at multiple levels: Connection pool, ORM configuration, HTTP client
- Monitor timeout occurrences and adjust thresholds based on p99 latencies

---

#### M2. Inefficient Polling-Based Price Alert System
**Severity**: Moderate
**Location**: Section 6 (Price Alert Processing, lines 209-214)

15-minute polling interval for price alerts is inefficient:

**Impact**:
- Wasted compute resources: 96 jobs per day check millions of alerts even when prices haven't changed
- Alert delivery latency: Up to 15 minutes from price change to notification
- Database load spikes every 15 minutes
- Inability to provide "instant" price drop notifications

**Recommendation**:
- Implement event-driven architecture: Trigger price checks on product price update events
- Use Kafka topic for product price changes → Price Alert Service consumes events
- Only check alerts for products with actual price changes
- Maintain real-time alert matching in memory (e.g., sorted set in Redis: `price_alerts:{product_id}`)
- Batch notifications to reduce Notification Service load

---

#### M3. Missing Read Replica Strategy for Read-Heavy Operations
**Severity**: Moderate
**Location**: Section 7 (Scalability, line 245) - "Database read replicas for read-heavy operations"

Read replicas are mentioned but not integrated into the architecture:

**Impact**:
- All read traffic hits primary database (single point of contention)
- Write operations compete with heavy read load
- Inability to scale read throughput independently
- Primary database becomes bottleneck

**Recommendation**:
- Implement explicit read/write routing:
  - Use Spring's `@Transactional(readOnly = true)` for read operations
  - Configure separate DataSource for read replicas
  - Route search result detail fetching to read replicas
  - Route recommendation history queries to read replicas
- Document replication lag tolerance per use case:
  - Product search: 1-second lag acceptable
  - User interaction history: 5-second lag acceptable
  - Order/payment operations: Read from primary only
- Monitor replication lag and fail over to primary if lag > threshold

---

#### M4. JWT Token Expiration Creates Unnecessary Load
**Severity**: Moderate
**Location**: Section 5 (Authentication & Authorization, line 177) - "24-hour token expiration"

24-hour JWT expiration with no refresh token strategy:

**Impact**:
- Users forced to re-authenticate daily (poor UX)
- Authentication service load spikes as tokens expire (batch expiration)
- No ability to revoke compromised tokens before expiration

**Recommendation**:
- Implement refresh token pattern:
  - Short-lived access tokens (15 minutes)
  - Long-lived refresh tokens (7 days) stored in Redis with user_id index
- Enable token revocation: Store active refresh tokens in Redis with blacklist for revoked tokens
- Reduce User Service load: Client-side token refresh before expiration
- Document token rotation policy and revocation SLA

---

#### M5. Elasticsearch Result Set Without Cursor-Based Pagination
**Severity**: Moderate
**Location**: Section 5 (Search Endpoint, lines 125-128)

Search API uses offset-based pagination (`page` parameter):

**Impact**:
- Deep pagination inefficiency: Fetching page 100 requires Elasticsearch to process first 2000 results
- "Last page" attacks: Malicious users requesting high page numbers cause resource exhaustion
- Poor performance for users browsing deep into results

**Recommendation**:
- Implement cursor-based pagination using Elasticsearch's `search_after`:
  - Return cursor token in response
  - Client includes cursor in subsequent requests
  - Constant-time performance regardless of depth
- Add pagination limits: Max page size = 100, max offset = 10,000
- Provide "search within results" for deep exploration rather than pagination

---

### MINOR IMPROVEMENTS

#### I1. Positive: Appropriate Use of Elasticsearch for Search
The design correctly delegates full-text search to Elasticsearch rather than using PostgreSQL, avoiding LIKE query performance issues.

#### I2. Positive: Multi-AZ Deployment for High Availability
Multi-AZ deployment for RDS and ElastiCache provides fault tolerance without sacrificing performance.

#### I3. Positive: CDN Usage for Static Assets
CloudFront CDN offloads static asset delivery from application servers, reducing backend load.

#### I4. Opportunity: Add Monitoring for Performance Metrics
Enhance existing CloudWatch monitoring with application-level performance metrics:
- API endpoint latency (p50, p95, p99)
- Database query execution time by query type
- Cache hit/miss rates per service
- Elasticsearch query latency distribution
- Recommendation generation time

#### I5. Opportunity: Consider Materialized Views for Analytics
For merchant reporting and analyst queries (Section 1, line 19), implement PostgreSQL materialized views:
- Pre-aggregate sales data by product/category/time
- Refresh incrementally (every hour) to avoid impacting transactional workload
- Separate reporting database replica for analytical queries

---

## Summary

**Critical Issues Identified**: 4
- Missing performance SLAs/capacity planning
- N+1 query in search results (20x database load)
- Unbounded price alert query (memory exhaustion risk)
- On-demand rating aggregation (exponential cost)

**Significant Issues Identified**: 5
- Missing connection pooling configuration
- Missing database indexes on critical paths
- Inefficient recommendation algorithm (O(n) per request)
- Synchronous event processing concerns
- Shared cache without partitioning

**Moderate Issues Identified**: 5
- Missing timeout configurations
- Inefficient polling-based alerts
- Read replica integration not defined
- JWT expiration strategy
- Offset-based pagination inefficiency

**Priority Recommendations**:
1. **Immediate**: Fix N+1 query in search (C2), add database indexes (S2), implement batch fetching for price alerts (C3)
2. **Short-term**: Define performance SLAs and validate capacity (C1), pre-compute rating aggregates (C4)
3. **Medium-term**: Re-architect recommendation engine with pre-computation (S3), partition Redis cache (S5)
4. **Long-term**: Migrate to event-driven price alerts (M2), implement cursor pagination (M5)
