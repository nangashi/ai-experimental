# Answer Key - Round 008

## Execution Conditions
- **Perspective**: performance
- **Target**: design
- **Embedded Problems**: 10

## Embedded Problems

### P01: Missing Performance SLA Definitions
- **Category**: Performance Requirements
- **Severity**: Critical
- **Location**: Section 7 (Non-Functional Requirements)
- **Problem Description**: The design document specifies security, availability, and scalability requirements but lacks concrete performance SLA definitions. No target values are defined for API response time, portfolio rebalancing execution time, or market data update latency. For a FinTech advisory platform where users expect real-time portfolio updates and rapid trade executions, the absence of performance baselines creates operational risks and prevents effective monitoring.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of specific performance SLA targets (response time, latency, throughput) in NFR section or throughout the design document
  - △ (Partial): Mentions general need for performance monitoring or metrics without identifying the missing SLA definitions
  - × (Not Detected): No mention of missing performance requirements

### P02: Portfolio Holdings N+1 Query Problem
- **Category**: Query Efficiency (I/O Efficiency)
- **Severity**: Critical
- **Location**: Section 4.2 (Portfolio Holdings), Section 5.1 (GET /api/v1/portfolios/{account_id}/holdings)
- **Problem Description**: The holdings table references account_id, and the API endpoint returns "current holdings with real-time values." The design implies fetching all holdings for an account and then separately fetching current market prices for each asset_symbol from market_prices table. For accounts with 50-100 holdings (typical diversified portfolios), this creates 50-100+ individual price queries. This N+1 pattern causes severe latency for portfolio view operations, which are among the most frequent user actions.
- **Detection Criteria**:
  - ○ (Detected): Identifies N+1 query risk in holdings retrieval with real-time price lookups, mentions need for batch price queries or JOIN optimization
  - △ (Partial): Mentions inefficient data access in portfolio operations without specifically identifying the N+1 pattern between holdings and prices
  - × (Not Detected): No mention of query efficiency issues in portfolio holdings

### P03: Missing Cache Strategy for Market Data
- **Category**: Cache/Memory Management
- **Severity**: Critical
- **Location**: Section 3.2 (Market Data Service), Section 4.3 (market_prices table)
- **Problem Description**: Market prices are stored in market_prices table and frequently accessed for portfolio valuation, performance calculation, and real-time updates. Popular assets (S&P 500 stocks, major currency pairs) will be queried thousands of times per minute. The design mentions Redis as available infrastructure but provides no caching strategy for market data. Without caching, every portfolio view and rebalancing calculation hits the database, causing severe load and latency issues.
- **Detection Criteria**:
  - ○ (Detected): Points out missing cache layer for frequently accessed market prices, specifically mentions Redis utilization for price data
  - △ (Partial): Mentions general caching need or Redis underutilization without specifically identifying market price caching
  - × (Not Detected): No mention of caching issues for market data

### P04: Unbounded Query on Historical Price Data
- **Category**: Query Efficiency (I/O Efficiency)
- **Severity**: Medium
- **Severity**: Medium
- **Location**: Section 5.2 (GET /api/v1/market/history/{asset_symbol}?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD)
- **Problem Description**: The historical price endpoint accepts arbitrary date ranges without documented limits. Users performing backtesting or historical analysis could request 10+ years of daily data (3650+ rows per asset). With high-frequency users or multiple concurrent backtesting requests, this creates memory pressure and slow response times. The design lacks pagination, row limits, or pre-aggregated data for long-term historical queries.
- **Detection Criteria**:
  - ○ (Detected): Identifies unbounded historical data retrieval risk, recommends pagination, maximum date range limits, or data aggregation strategies
  - △ (Partial): Mentions large dataset handling concerns without specifically addressing historical price query limits
  - × (Not Detected): No mention of historical data query constraints

### P05: Recommendation Engine Computation Efficiency
- **Category**: Algorithm Efficiency
- **Severity**: Medium
- **Location**: Section 3.2 (Recommendation Engine)
- **Problem Description**: The recommendation engine performs mean-variance optimization, which involves computing covariance matrices across all available assets. For a universe of 5000+ investable assets, the naive approach requires O(n²) operations (25M+ calculations). The design does not specify asset filtering, dimensionality reduction, or pre-computed covariance matrices. Combined with real-time recommendation requests (Section 5.1), this creates computation bottlenecks and extended response times.
- **Detection Criteria**:
  - ○ (Detected): Identifies computational complexity issues in mean-variance optimization, mentions need for asset filtering, precomputed matrices, or approximate algorithms
  - △ (Partial): Mentions general algorithm efficiency concerns without addressing specific optimization complexity
  - × (Not Detected): No mention of recommendation engine performance issues

### P06: Transaction History Unbounded Growth
- **Category**: Data Lifecycle/Capacity Planning
- **Severity**: Medium
- **Location**: Section 4.4 (transactions table)
- **Problem Description**: The transactions table stores all buy/sell orders indefinitely with no archival or partitioning strategy. For active traders executing 10-20 trades/day, this accumulates 3650-7300 rows/year. Over 5-10 years of platform operation with 100K+ users, the table grows to billions of rows. Queries for recent transaction status (critical for order tracking) suffer from table scan overhead. The design lacks time-based partitioning, archival policies, or separate hot/cold storage for old transactions.
- **Detection Criteria**:
  - ○ (Detected): Identifies long-term data growth issues in transactions table, recommends partitioning, archival strategy, or tiered storage
  - △ (Partial): Mentions general data growth concerns without specifically addressing transaction history management
  - × (Not Detected): No mention of transaction data lifecycle issues

### P07: Missing Index on Historical Prices Query Pattern
- **Category**: Database Design (I/O Efficiency)
- **Severity**: Medium
- **Location**: Section 4.3 (historical_prices table)
- **Problem Description**: The historical_prices table uses (asset_symbol, date) as composite primary key. However, the API endpoint GET /api/v1/market/history/{asset_symbol}?start_date=X&end_date=Y performs range queries filtering by symbol AND date range. Without explicit mention of index strategy, queries must scan all rows for the asset_symbol to find dates within the range. For assets with 10+ years of daily data (3650+ rows per symbol), this creates slow backtest operations and analytical query bottlenecks.
- **Detection Criteria**:
  - ○ (Detected): Identifies need for optimized index on (asset_symbol, date) for range queries or mentions composite index optimization for the historical query pattern
  - △ (Partial): Mentions general indexing needs without specifically addressing historical price range query pattern
  - × (Not Detected): No mention of index optimization for historical data

### P08: Real-time WebSocket Connection Scaling
- **Category**: Scalability Design
- **Severity**: Medium
- **Location**: Section 5.2 (WS /api/v1/market/stream), Section 2.3 (Node.js with Socket.io)
- **Problem Description**: The design specifies WebSocket streaming for real-time price updates using Node.js with Socket.io. For a platform with 100K concurrent users monitoring portfolios, a single Node.js instance typically handles 10K-15K WebSocket connections before memory/CPU saturation. The design does not specify connection distribution strategy, pub/sub architecture for message broadcasting, or sticky session management for WebSocket upgrades. Without horizontal scaling strategy for WebSocket servers, the platform cannot support peak traffic during market volatility events.
- **Detection Criteria**:
  - ○ (Detected): Identifies WebSocket connection scaling concerns, mentions need for load balancing, pub/sub pattern (e.g., Redis pub/sub), or connection pooling strategies
  - △ (Partial): Mentions general real-time service scaling without addressing WebSocket-specific connection management
  - × (Not Detected): No mention of WebSocket scaling issues

### P09: Concurrent Rebalancing Race Condition
- **Category**: Concurrency Control
- **Severity**: Medium
- **Location**: Section 3.2 (Portfolio Engine), Section 5.1 (POST /api/v1/portfolios/{account_id}/rebalance)
- **Problem Description**: The rebalancing endpoint allows users to trigger portfolio rebalancing. The Portfolio Engine "evaluates current holdings against target allocations" and "generates trade orders." If a user triggers rebalancing multiple times rapidly (e.g., clicking button twice, or automated scheduled rebalancing coinciding with manual trigger), two concurrent processes may read the same holdings state, both generate conflicting trade orders, leading to over-trading or incorrect final allocations. The design lacks mention of locking mechanism, idempotency keys, or rebalancing job deduplication.
- **Detection Criteria**:
  - ○ (Detected): Identifies race condition risk in concurrent rebalancing requests, recommends locking, idempotency, or job deduplication
  - △ (Partial): Mentions general concurrency concerns without specifically addressing rebalancing race conditions
  - × (Not Detected): No mention of concurrent rebalancing issues

### P10: Missing Performance Monitoring Infrastructure
- **Category**: Observability (Performance Metrics)
- **Severity**: Minor
- **Location**: Section 6.2 (Logging), Section 7 (Non-Functional Requirements)
- **Problem Description**: The design specifies logging infrastructure (CloudWatch) and testing policies but lacks dedicated performance monitoring. Critical metrics like API latency percentiles (p50, p95, p99), database query execution time, portfolio calculation duration, and rebalancing job completion time are not addressed. Without performance-specific observability, the team cannot detect degradation trends or validate SLA compliance (once SLAs are defined). Logging alone is insufficient for real-time performance tracking.
- **Detection Criteria**:
  - ○ (Detected): Points out missing performance-specific metrics collection (latency, throughput, resource utilization), recommends APM tools or custom metric instrumentation
  - △ (Partial): Mentions general monitoring needs without specifically identifying performance metric gaps
  - × (Not Detected): No mention of performance monitoring infrastructure

## Bonus Problems

Bonus problems are NOT included in the answer key but will be awarded bonus points if detected by the reviewer agent.

| ID | Category | Content | Bonus Condition |
|----|---------|---------|-----------------|
| B01 | API Design | Batch price lookup API missing (GET /api/v1/market/prices with multiple symbols in query param) for efficient multi-asset price retrieval | Recommends batch API endpoint to reduce N+1 queries |
| B02 | Cache Strategy | Cache invalidation strategy for market prices undefined (time-based TTL vs event-driven invalidation) | Mentions cache TTL, invalidation policy, or staleness tolerance for price data |
| B03 | Database Connection | Connection pooling strategy not specified for PostgreSQL access from multiple microservices | Recommends database connection pool configuration or mentions connection exhaustion risk |
| B04 | Data Partitioning | Time-series data (historical_prices) not using specialized storage optimization (e.g., TimescaleDB, partitioning by date ranges) | Suggests table partitioning, TimescaleDB, or time-series optimized storage |
| B05 | Message Queue | RabbitMQ mentioned but no specification for async job processing patterns (rebalancing, tax-loss harvesting computation) | Recommends async job processing via message queue for long-running operations |
| B06 | Rate Limiting | No rate limiting strategy for external market data provider API calls (Bloomberg, Reuters) to avoid quota exhaustion and cost overruns | Points out need for rate limiting on external API calls |
| B07 | Read Replica | Database read replicas mentioned but no query routing strategy (write to primary, read from replicas) specified | Recommends explicit read/write splitting strategy for query load distribution |
| B08 | Search Performance | Elasticsearch mentioned but no specification of indexed fields or query optimization for investment strategy search | Suggests Elasticsearch index design for efficient search operations |
| B09 | CDN Usage | CloudFront mentioned but static asset optimization strategy (compression, caching headers, asset versioning) not detailed | Recommends CDN configuration optimization for static asset delivery |
| B10 | Rebalancing Frequency | No specification of rebalancing execution frequency or trigger conditions (scheduled daily/weekly, threshold-based) affecting system load patterns | Points out need to define rebalancing trigger strategy for predictable load management |
