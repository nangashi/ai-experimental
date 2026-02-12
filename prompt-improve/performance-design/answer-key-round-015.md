# Answer Key - Round 015

## Execution Context
- **Perspective**: performance
- **Target**: design
- **Embedded Problems**: 10

## Embedded Problems

### P01: SLA/Performance Target Definition Missing
- **Category**: Performance Requirements / SLA
- **Severity**: Critical
- **Location**: Section 7 (Non-Functional Requirements)
- **Problem Description**: The design document lacks quantitative performance targets (response time, throughput, latency percentiles) despite being a high-traffic e-commerce platform serving millions of daily active users. No SLA is defined for critical user-facing operations like search, product detail retrieval, or recommendation generation.
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of quantitative performance targets (e.g., search latency, API response time, p95/p99 percentiles) or SLA definitions, and explains why this is critical for a high-traffic platform
  - △ (Partial): Mentions performance monitoring or the need for performance metrics, but does not specifically call out the missing SLA or quantitative targets
  - × (Missed): No mention of performance requirements or SLA definitions

### P02: N+1 Query Problem in Search Results
- **Category**: Query Efficiency / I/O Optimization
- **Severity**: Critical
- **Location**: Section 6 (Implementation Details - Product Search Implementation)
- **Problem Description**: The search flow retrieves product IDs from Elasticsearch, then fetches full details from PostgreSQL for each product individually. For a typical search result page of 20 products, this causes 1 (Elasticsearch query) + 20 (PostgreSQL queries) = 21 database round trips, creating severe latency under high load.
- **Detection Criteria**:
  - ○ (Detected): Identifies the N+1 query pattern in the search result retrieval process and explains the performance impact (multiple round trips for each search result page)
  - △ (Partial): Mentions that fetching product details from PostgreSQL may be inefficient, but does not explicitly identify the N+1 pattern or quantify the number of queries
  - × (Missed): No mention of query efficiency issues in the search flow

### P03: Missing Cache Strategy
- **Category**: Cache & Memory Management
- **Severity**: Critical
- **Location**: Section 3 (Architecture Design) and Section 6 (Implementation Details)
- **Problem Description**: Despite Redis being listed in the tech stack, there is no cache strategy defined. Hot products (frequently searched/viewed), search results, and recommendation results are not cached. Every request hits the database directly, causing unnecessary load on PostgreSQL and Elasticsearch.
- **Detection Criteria**:
  - ○ (Detected): Points out that no cache usage strategy is defined despite Redis being available, and identifies specific cacheable entities (hot products, search results, recommendations)
  - △ (Partial): Mentions that caching should be considered or that Redis is underutilized, but does not identify specific entities that should be cached
  - × (Missed): No mention of cache strategy or Redis usage

### P04: Unbounded Query in Recommendation Engine
- **Category**: Query Efficiency / Data Structure
- **Severity**: Significant
- **Location**: Section 6 (Implementation Details - Recommendation Engine)
- **Problem Description**: The recommendation algorithm "retrieves user's interaction history" and "fetches similar users' purchase patterns" from PostgreSQL without any limit or time window. As users accumulate months/years of interaction history, these unbounded queries will cause severe performance degradation and memory pressure.
- **Detection Criteria**:
  - ○ (Detected): Identifies that user interaction history and similar user pattern queries are unbounded (no limit, no time window), and explains the long-term performance degradation risk as data accumulates
  - △ (Partial): Mentions that the recommendation engine may have performance issues with large datasets, but does not specifically point out the unbounded nature of the queries
  - × (Missed): No mention of query scope issues in the recommendation engine

### P05: Synchronous Real-Time Calculation in Recommendation
- **Category**: Latency & Throughput / Algorithm Complexity
- **Severity**: Significant
- **Location**: Section 6 (Implementation Details - Recommendation Engine)
- **Problem Description**: The recommendation service calculates similarity scores for "all products" in real-time when a recommendation request arrives. With millions of products in the catalog, this O(n) calculation will cause unacceptable latency and cannot scale. Recommendations should be pre-computed asynchronously.
- **Detection Criteria**:
  - ○ (Detected): Identifies that recommendation similarity scores are calculated in real-time for all products, causing latency issues, and suggests pre-computation or asynchronous processing
  - △ (Partial): Mentions that the recommendation algorithm may be slow or computationally expensive, but does not specifically identify the real-time calculation for all products as the bottleneck
  - × (Missed): No mention of recommendation calculation performance issues

### P06: Missing Database Index Design
- **Category**: Query Efficiency / Database Design
- **Severity**: Significant
- **Location**: Section 4 (Data Model)
- **Problem Description**: No indexes are defined for high-frequency query columns such as `UserInteraction.user_id`, `Review.product_id`, `PriceAlert.user_id`, etc. Without proper indexes, queries filtering by these columns will perform full table scans, causing severe performance degradation as data grows.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of index definitions for frequently queried columns (e.g., user_id, product_id in UserInteraction/Review/PriceAlert tables), and explains the full table scan risk
  - △ (Partial): Mentions that database indexing should be considered, but does not identify specific missing indexes
  - × (Missed): No mention of database indexing

### P07: User Interaction Data Growth Strategy Missing
- **Category**: Data Lifecycle & Capacity Planning
- **Severity**: Significant
- **Location**: Section 4 (Data Model - UserInteraction table)
- **Problem Description**: The `UserInteraction` table uses BIGSERIAL as the primary key and logs every view/click/cart/purchase event. With millions of daily active users, this table will grow unbounded (potentially billions of rows within months). No data archival, partitioning, or retention policy is defined, leading to query performance degradation and storage cost explosion.
- **Detection Criteria**:
  - ○ (Detected): Identifies the unbounded growth of the UserInteraction table and the lack of data lifecycle management (partitioning, archival, retention policy), explaining the long-term performance and cost impact
  - △ (Partial): Mentions that the UserInteraction table may grow large and could cause performance issues, but does not specifically call out the missing data lifecycle strategy
  - × (Missed): No mention of data growth or lifecycle management

### P08: Synchronous Review Aggregation on Every Product View
- **Category**: Query Efficiency / Cache Management
- **Severity**: Medium
- **Location**: Section 6 (Implementation Details - Review Aggregation)
- **Problem Description**: The design states "Product ratings are aggregated on-demand" by querying all reviews for a product and calculating the average in real-time whenever the product is displayed. For products with hundreds or thousands of reviews, this causes slow page loads and unnecessary database load. Aggregated ratings should be pre-computed or cached.
- **Detection Criteria**:
  - ○ (Detected): Identifies the on-demand aggregation pattern and explains the performance issue (querying all reviews + calculating average on every product view), and suggests pre-computation or caching
  - △ (Partial): Mentions that review aggregation might be slow for products with many reviews, but does not identify the on-demand calculation pattern or suggest alternatives
  - × (Missed): No mention of review aggregation performance

### P09: Polling-Based Price Alert Check
- **Category**: Latency & Throughput / Scalability
- **Severity**: Medium
- **Location**: Section 6 (Implementation Details - Price Alert Processing)
- **Problem Description**: The price alert system uses a scheduled job that polls all active price alerts every 15 minutes, fetching current prices one by one from PostgreSQL. As the number of active alerts grows (potentially millions), this batch polling pattern will cause significant database load spikes every 15 minutes and increase notification latency. An event-driven approach (price change events) would be more scalable.
- **Detection Criteria**:
  - ○ (Detected): Identifies the polling-based design (scheduled job querying all alerts every 15 minutes) and explains the scalability issue (database load spikes, latency increase with growing alert count), and suggests event-driven alternatives
  - △ (Partial): Mentions that the price alert processing may have performance issues or should be improved, but does not specifically identify the polling pattern or scalability concern
  - × (Missed): No mention of price alert performance or scalability

### P10: Lack of Performance-Specific Monitoring Metrics
- **Category**: Performance Requirements / Monitoring
- **Severity**: Minor
- **Location**: Section 7 (Non-Functional Requirements - Monitoring)
- **Problem Description**: The monitoring section only mentions infrastructure-level metrics (CPU, memory, network) and generic application logging. There is no mention of performance-specific metrics such as API response time, search latency, recommendation generation time, database query time, cache hit rate, or throughput (requests per second). Without these metrics, performance degradation cannot be detected early.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of performance-specific monitoring metrics (API latency, database query time, cache hit rate, throughput) and explains why they are necessary for performance management
  - △ (Partial): Mentions that more detailed monitoring should be added or that current monitoring is insufficient, but does not specifically identify the missing performance metrics
  - × (Missed): No mention of monitoring or metrics issues

## Bonus Problems

Reviewers may receive bonus points for detecting the following issues, which are not explicitly in the answer key but demonstrate deeper analysis:

| ID | Category | Description | Bonus Condition |
|----|---------|-------------|----------------|
| B01 | API Call Efficiency | Recommendation endpoint may fetch product details one-by-one for each recommended product, causing N+1 pattern | Points out that the recommendation API likely has an N+1 issue when fetching full product details for recommended items |
| B02 | Connection Pool | No connection pool configuration mentioned for PostgreSQL/Elasticsearch clients | Identifies the absence of connection pooling strategy and explains the connection exhaustion risk under high load |
| B03 | Elasticsearch Query Optimization | Search queries may not use proper filters/scoring optimization, causing slow search performance | Points out that Elasticsearch query construction details are missing (e.g., filter vs query context, scoring optimization) |
| B04 | Redis Connection Pool | Redis cache access pattern does not mention connection pooling | Identifies potential Redis connection management issues |
| B05 | CDN Strategy | CDN mentioned only for static assets, but API responses or search results could benefit from edge caching | Suggests edge caching for API responses or search results |
| B06 | Batch Processing | Price alert processing could benefit from batch price fetching instead of individual queries | Points out the opportunity for batch fetching in price alert processing |
| B07 | Kafka Consumer Lag | No mention of Kafka consumer lag monitoring or handling in Recommendation Service | Identifies the risk of event processing lag in the recommendation engine |
