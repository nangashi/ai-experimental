# Performance Design Review - FinTech Investment Advisory Platform

## Executive Summary

This design document presents a microservices-based investment advisory platform but contains **critical performance design gaps** that could severely impact system reliability and user experience at scale. The most severe issues include missing performance SLAs, N+1 query risks in portfolio operations, unbounded historical data queries, lack of batch processing design for rebalancing operations, and absence of caching strategies for high-frequency market data access.

---

## Critical Issues

### 1. Missing Performance SLAs and Latency Targets

**Issue:** Section 7.3 mentions scalability goals but lacks quantitative performance requirements (latency targets, throughput specifications, concurrent user capacity).

**Impact:**
- Cannot validate whether architectural decisions meet user expectations
- Unable to set meaningful performance monitoring thresholds
- Risk of discovering performance inadequacy only in production
- Portfolio recommendation and rebalancing operations may have unbounded execution times

**Recommendation:**
Define specific performance SLAs by operation type:
- **User-facing reads** (GET /portfolios/{id}/holdings): < 200ms p95
- **Portfolio performance calculation** (GET /portfolios/{id}/performance): < 500ms p95
- **Rebalancing computation** (POST /portfolios/{id}/rebalance): < 2s p95
- **Real-time price updates** (WebSocket): < 100ms delivery latency
- **System throughput**: Support 10,000 concurrent users, 1,000 rebalance requests/minute
- **Market data ingestion**: Process 50,000 price updates/second during market hours

### 2. N+1 Query Problem in Portfolio Operations

**Issue:** The holdings retrieval endpoint (GET /portfolios/{account_id}/holdings) returns "real-time values" but the schema shows individual holding records without batch query optimization.

**Impact:**
- For a portfolio with 50 holdings, this could trigger 50+ separate queries to fetch current prices from `market_prices`
- Query execution time scales linearly with portfolio size (O(n) database queries)
- User experience degradation: 50 holdings × 20ms per query = 1000ms+ response time
- Database connection pool exhaustion under concurrent load

**Recommendation:**
```python
# Antipattern (N+1 queries)
holdings = Holdings.objects.filter(account_id=account_id)
for holding in holdings:
    current_price = MarketPrices.objects.get(asset_symbol=holding.asset_symbol)
    holding.current_value = holding.quantity * current_price

# Optimized approach
holdings = Holdings.objects.filter(account_id=account_id).select_related()
symbols = [h.asset_symbol for h in holdings]
prices = MarketPrices.objects.filter(asset_symbol__in=symbols).in_bulk(field_name='asset_symbol')
for holding in holdings:
    holding.current_value = holding.quantity * prices[holding.asset_symbol].price
```

Add explicit design note: "Portfolio value calculation must use batch price fetching with WHERE asset_symbol IN (...) to prevent N+1 queries."

### 3. Unbounded Historical Data Queries

**Issue:** The market history endpoint (GET /api/v1/market/history/{asset_symbol}?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD) accepts arbitrary date ranges without result limits or pagination.

**Impact:**
- A query spanning 30 years of daily data returns 7,500+ records
- Database memory consumption: 7,500 rows × 64 bytes = 480 KB per request
- With 100 concurrent backtesting operations: 48 MB memory, increased I/O wait
- Response payload bloat causes slow JSON serialization and client-side parsing delays
- PostgreSQL query planner may choose full table scans for large date ranges

**Recommendation:**
- Enforce maximum date range: "Historical queries limited to 5 years per request"
- Add pagination parameters: `?start_date=...&end_date=...&limit=1000&offset=0`
- Return result count in response headers: `X-Total-Count: 7500`
- Document pagination requirement in API specification
- Consider pre-aggregating common timeframes (1Y, 5Y, 10Y) in materialized views

### 4. Missing Index Design Specification

**Issue:** The data model shows table schemas but lacks explicit index definitions for high-frequency query patterns.

**Impact:**
- **holdings** table queries by `account_id`: Without index, full table scans occur (O(n) lookup time)
- **market_prices** lookups by `asset_symbol` + `timestamp`: Missing composite index causes inefficient filtering
- **transactions** status filtering (`WHERE status = 'pending'`): Full table scan for pending transaction monitoring
- **historical_prices** date range queries: Missing BRIN or B-tree index on `date` column degrades query performance as data grows

**Performance degradation examples:**
- 10M holdings records, query by account_id without index: 500ms → 5000ms
- 100M market_prices records, latest price lookup: 100ms → 2000ms+

**Recommendation:**
Add explicit index design section:
```sql
-- Critical indexes for query performance
CREATE INDEX idx_holdings_account_id ON holdings(account_id);
CREATE INDEX idx_holdings_account_asset ON holdings(account_id, asset_symbol);
CREATE INDEX idx_market_prices_symbol_time ON market_prices(asset_symbol, timestamp DESC);
CREATE INDEX idx_transactions_account_status ON transactions(account_id, status) WHERE status != 'completed';
CREATE INDEX idx_historical_prices_symbol_date ON historical_prices(asset_symbol, date);

-- Consider partial index for active transactions
CREATE INDEX idx_active_transactions ON transactions(account_id, status) WHERE status IN ('pending', 'processing');
```

### 5. Lack of Caching Strategy for Market Data

**Issue:** The Market Data Service integrates with external providers (Bloomberg, Reuters) but the document does not specify caching policies for high-frequency price lookups.

**Impact:**
- Portfolio valuation endpoint (GET /portfolios/{id}/holdings) requires current prices for all assets
- Without caching: 50 holdings × external API call (100ms latency) = 5000ms response time
- External API rate limits (e.g., 1000 requests/minute) become bottleneck
- Unnecessary cost from redundant API calls for popular assets (SPY, AAPL fetched by thousands of users)
- Risk of service throttling or ban from data providers

**Recommendation:**
Design tiered caching strategy:
```
1. Redis cache layer (TTL based on market hours):
   - During market hours: 1-second TTL for actively traded assets
   - After-hours: 1-hour TTL for stale data tolerance
   - Cache key pattern: "price:{symbol}:{timestamp_bucket}"

2. Application-level cache:
   - In-memory LRU cache (10,000 symbols) for sub-millisecond access
   - Prefetch top 100 most-held assets every second

3. Cache warming:
   - Preload prices for all user holdings at session start
   - Background refresh task for portfolio assets before market open

4. Fallback strategy:
   - On cache miss: Batch fetch from external API (group requests)
   - Update cache asynchronously to avoid blocking response
```

Add cache invalidation design: "Invalidate asset price cache on disconnect from real-time price stream (failover scenario)."

### 6. Batch Rebalancing Operations Without Concurrency Control

**Issue:** Section 3.2 states "Processes rebalancing requests from scheduled jobs" but lacks design for handling thousands of concurrent rebalancing calculations.

**Impact:**
- Daily rebalancing job for 100,000 user accounts triggers simultaneous:
  - 100,000 portfolio evaluations (database queries)
  - 100,000 optimization calculations (CPU-intensive mean-variance optimization)
  - Database connection pool exhaustion (default pool size ~100)
  - Memory pressure from loading all holdings data into memory simultaneously
- System-wide latency spike affects user-facing operations during rebalancing window
- Risk of timeout failures causing partial rebalancing completion

**Recommendation:**
Design batch processing with rate limiting:
```python
# Chunked processing with concurrency limit
from celery import group
from celery.canvas import chunks

# Process 1000 accounts per batch, max 10 concurrent batches
rebalance_tasks = [
    rebalance_portfolio.si(account_id)
    for account_id in accounts_to_rebalance
]
job = chunks(rebalance_tasks, 1000)()  # 100K accounts → 100 batches
```

Add design specifications:
- "Rebalancing jobs process accounts in batches of 1000, max 10 concurrent workers"
- "Rebalancing window: 2AM-6AM (off-peak), estimated 100K accounts in 4 hours = 7 accounts/second"
- "Circuit breaker: Pause rebalancing if database connection pool utilization > 80%"

### 7. Real-time WebSocket Scalability Design Missing

**Issue:** Section 5.2 mentions "Real-time price updates via WebSocket" (WS /api/v1/market/stream) but lacks design for handling persistent connections at scale.

**Impact:**
- WebSocket connections are stateful and long-lived (memory per connection: ~64KB)
- 10,000 concurrent users subscribing to price streams: 640 MB memory minimum
- Each price update broadcast requires iterating all connected clients (O(n) complexity)
- Node.js Socket.io service becomes single point of contention
- No design for subscription filtering (users interested in different asset sets)

**Recommendation:**
Design horizontally scalable WebSocket architecture:
```
1. Subscription management:
   - Users subscribe to specific asset symbols: ws.emit('subscribe', ['AAPL', 'TSLA'])
   - Server maintains symbol → subscriber_list mapping
   - Only broadcast updates to interested subscribers (O(k) where k = subscribers per symbol)

2. Load distribution:
   - Deploy multiple Socket.io instances behind load balancer
   - Use Redis pub/sub for inter-node message broadcasting
   - Sticky sessions for WebSocket connection affinity

3. Connection limits:
   - Max 50 symbol subscriptions per connection (prevent abuse)
   - Idle connection timeout: 5 minutes without heartbeat
   - Graceful degradation: Fall back to HTTP polling if WebSocket unavailable

4. Backpressure handling:
   - If broadcast queue depth > 1000 messages: Drop non-critical updates
   - Batch updates within 100ms window to reduce message frequency
```

Add capacity planning: "Target: 50,000 concurrent WebSocket connections across 10 Node.js instances (5,000 connections per instance)."

---

## Significant Issues

### 8. Missing Connection Pooling Configuration

**Issue:** Infrastructure section mentions RabbitMQ, PostgreSQL, Redis, but connection pooling parameters are not specified.

**Impact:**
- Default PostgreSQL pool size (100 connections) insufficient for microservices architecture (7 services × 50 connections = 350 needed)
- Connection exhaustion causes request queueing and timeout failures
- Improper pool configuration leads to connection leaks and resource exhaustion

**Recommendation:**
Specify connection pooling per service:
```yaml
# Database connection pools (per service instance)
PostgreSQL:
  min_pool_size: 10
  max_pool_size: 50
  connection_timeout: 5s
  idle_timeout: 300s
  max_lifetime: 1800s

Redis:
  max_connections: 100
  connection_timeout: 2s

RabbitMQ:
  channel_pool_size: 20
  prefetch_count: 10
```

### 9. Tax-Loss Harvesting Endpoint Lacks Query Optimization

**Issue:** GET /api/v1/users/{user_id}/tax-loss-opportunities requires complex calculation (compare purchase price vs. current price for all holdings) but no optimization strategy is documented.

**Impact:**
- Requires joining `holdings` + `market_prices` + `transactions` tables
- For users with 100+ holdings and 1000+ historical transactions: Full table scans
- Calculation involves:
  1. Fetching all holdings (50-200 records)
  2. Computing unrealized losses per holding (50-200 price lookups)
  3. Checking wash sale rules (30-day transaction history per symbol)
- Without optimization: 2-5 seconds per request, database CPU spike

**Recommendation:**
```sql
-- Materialized view for tax-loss opportunities (refresh nightly)
CREATE MATERIALIZED VIEW tax_loss_opportunities AS
SELECT
    h.account_id,
    h.asset_symbol,
    h.quantity,
    h.purchase_price,
    mp.price AS current_price,
    (h.purchase_price - mp.price) * h.quantity AS unrealized_loss,
    h.purchase_date
FROM holdings h
JOIN LATERAL (
    SELECT price FROM market_prices
    WHERE asset_symbol = h.asset_symbol
    ORDER BY timestamp DESC LIMIT 1
) mp ON true
WHERE h.purchase_price > mp.price * 1.05; -- Only losses > 5%

CREATE INDEX idx_tax_loss_account ON tax_loss_opportunities(account_id);
```

Add caching: "Tax-loss opportunities cached with 1-hour TTL, recalculated on portfolio rebalancing."

### 10. Portfolio Performance Calculation Lacks Aggregation Strategy

**Issue:** GET /api/v1/portfolios/{account_id}/performance returns "historical performance metrics, returns, volatility" but no design for efficient time-series aggregation.

**Impact:**
- Calculating 1-year daily returns requires 252 trading days × holdings count queries
- Volatility calculation (standard deviation) requires loading all historical values into memory
- For 50 holdings: 12,600 data points to process on every request
- Without pre-aggregation: 3-10 second response time, high database load

**Recommendation:**
Pre-aggregate performance metrics:
```sql
-- Daily portfolio performance snapshots
CREATE TABLE portfolio_performance_snapshots (
    account_id UUID,
    date DATE,
    total_value DECIMAL(15,2),
    daily_return DECIMAL(8,4),
    ytd_return DECIMAL(8,4),
    PRIMARY KEY (account_id, date)
);

-- Background job: Calculate and store snapshots daily at market close
-- API reads from snapshot table instead of recalculating
```

Add API response specification:
- "Performance endpoint returns pre-calculated snapshots (max 1-day staleness)"
- "Real-time performance available via separate endpoint with 30-second cache TTL"

### 11. Missing Timeout Configurations for External Services

**Issue:** Section 6.1 mentions "Circuit breaker pattern for external service calls" but lacks explicit timeout values.

**Impact:**
- Without timeouts, hung connections to Bloomberg/Reuters APIs block thread pools indefinitely
- Cascading failures: Slow external API causes request backlog in Django service
- User-facing requests waiting on market data fetch experience unbounded latency

**Recommendation:**
```python
# External service timeout configuration
EXTERNAL_API_TIMEOUTS = {
    'market_data_providers': {
        'connect_timeout': 2.0,  # TCP connection establishment
        'read_timeout': 5.0,     # Response reading
        'total_timeout': 10.0    # End-to-end request timeout
    },
    'payment_gateway': {
        'connect_timeout': 3.0,
        'read_timeout': 10.0
    }
}

# Circuit breaker thresholds
CIRCUIT_BREAKER_CONFIG = {
    'failure_threshold': 5,      # Open circuit after 5 failures
    'recovery_timeout': 60,      # Retry after 60 seconds
    'expected_exception': RequestTimeout
}
```

### 12. Recommendation Engine ML Inference Latency Not Addressed

**Issue:** Section 3.2 describes "ML-based risk profiling" and "mean-variance optimization" but does not specify inference latency or computational resource requirements.

**Impact:**
- Portfolio optimization is NP-hard problem; complexity increases exponentially with asset universe size
- Mean-variance optimization with 1000+ assets: 5-30 seconds computation time
- Synchronous ML inference in API request path causes timeout failures
- CPU-intensive computation competes with I/O-bound web serving tasks

**Recommendation:**
Design asynchronous recommendation generation:
```
1. Request flow:
   POST /api/v1/portfolios/{account_id}/recommendations
   → Returns: { "job_id": "uuid", "status": "processing", "estimated_time": 15 }

   GET /api/v1/jobs/{job_id}
   → Returns: { "status": "completed", "recommendations": [...] }

2. Processing architecture:
   - Offload optimization to dedicated worker pool (Celery with separate CPU-optimized instances)
   - Pre-compute recommendations for common risk profiles (cache for 24 hours)
   - Use approximate optimization algorithms for <2s response time constraint

3. Resource allocation:
   - Recommendation workers: 8 vCPU instances (CPU-bound workload)
   - Web serving instances: 4 vCPU instances (I/O-bound workload)
   - Separate scaling policies for each workload type
```

---

## Moderate Issues

### 13. Session Management with Redis Lacks Expiration Strategy

**Issue:** Section 5.4 mentions "Session management with Redis" but does not define TTL, renewal policies, or maximum session count per user.

**Impact:**
- Indefinite session storage leads to Redis memory bloat (100K users × 10 KB session data = 1 GB)
- Stale sessions allow unauthorized access after password changes
- No protection against session fixation attacks

**Recommendation:**
```
Session configuration:
- TTL: 30 minutes idle timeout, 8 hours absolute timeout
- Renewal: Extend TTL on each authenticated request
- Max sessions per user: 5 (revoke oldest on new login)
- Session key pattern: "session:{user_id}:{session_id}"
- Memory limit: 2 GB with LRU eviction policy
```

### 14. Missing Database Query Result Pagination Design

**Issue:** API endpoints like GET /api/v1/portfolios/{account_id}/holdings do not specify pagination parameters despite potentially large result sets.

**Impact:**
- User with 500+ holdings receives 500 records in single response (100+ KB payload)
- JSON serialization time increases linearly with record count
- Client-side rendering lag from processing large DOM updates
- Mobile app memory pressure from large response objects

**Recommendation:**
```
Standardize pagination across all list endpoints:
GET /api/v1/portfolios/{account_id}/holdings?limit=50&offset=0

Response format:
{
  "data": [...],
  "pagination": {
    "total": 523,
    "limit": 50,
    "offset": 0,
    "has_next": true
  }
}

Default limits:
- Holdings: 100 records per page
- Transactions: 50 records per page
- Market history: 1000 records per page
```

### 15. Elasticsearch Usage Lacks Performance Considerations

**Issue:** Infrastructure mentions Elasticsearch but does not specify what is being indexed or query optimization strategies.

**Impact:**
- Unclear which entities are searchable (users? transactions? market data?)
- Risk of full-text search on high-cardinality fields causing slow queries
- Missing design for index refresh intervals (real-time vs. near-real-time tradeoff)

**Recommendation:**
```
Elasticsearch index design:
1. Indexed entities:
   - User profiles (search by name, email)
   - Investment strategies (full-text search on descriptions)
   - Audit logs (compliance investigations)

2. Performance tuning:
   - Refresh interval: 30s (near-real-time, reduces indexing overhead)
   - Replica count: 1 (balance search throughput vs. storage)
   - Disable _source storage for large text fields (reduce index size)

3. Query patterns:
   - Use filters instead of queries for exact matches (better caching)
   - Limit result size: max 1000 documents per search
   - Highlight fragment size: 150 characters (reduce response payload)
```

### 16. InfluxDB Time-Series Data Retention Not Defined

**Issue:** Infrastructure lists InfluxDB for market data history but lacks retention policies for time-series data lifecycle.

**Impact:**
- Unbounded data growth: 5000 symbols × 252 trading days/year × 10 years = 12.6M records/year
- InfluxDB storage costs increase linearly without downsampling
- Query performance degrades as data volume grows (full scans on old data)

**Recommendation:**
```
InfluxDB retention policies:
1. High-resolution (1-minute OHLC):
   - Retention: 90 days
   - Used for: Recent performance analysis, live charts

2. Daily aggregates:
   - Retention: 10 years
   - Downsampled from high-resolution data
   - Used for: Backtesting, historical performance

3. Continuous queries:
   CREATE CONTINUOUS QUERY "downsample_daily" ON "market_data"
   BEGIN
     SELECT mean(close) AS close, max(high) AS high, min(low) AS low
     INTO "daily_prices"
     FROM "minute_prices"
     GROUP BY time(1d), asset_symbol
   END

Storage estimation:
- 90 days × 5000 symbols × 1440 min/day = 648M records → ~50 GB
- 10 years × 5000 symbols × 365 days/year = 18.25M records → ~2 GB
```

---

## Minor Issues & Positive Aspects

### 17. Multi-Currency Support Lacks Exchange Rate Caching

**Issue:** Section 1.2 mentions "Multi-currency support for international investments" but no design for currency conversion performance.

**Impact:**
- Every portfolio valuation in non-USD requires forex rate lookup
- Moderate performance impact (additional database query per currency)

**Recommendation:**
- Cache exchange rates with 5-minute TTL (sufficient for valuation purposes)
- Pre-fetch top 20 currency pairs (USD, EUR, JPY, GBP, etc.) on application startup

### 18. Positive: Event-Driven Architecture for Scalability

**Strength:** Section 7.3 mentions "Event-driven architecture for asynchronous processing" which is appropriate for:
- Portfolio rebalancing triggers (scheduled events)
- Market data ingestion (high-throughput event streams)
- Notification delivery (decoupled from transaction execution)

This design choice effectively prevents long-running operations from blocking user-facing requests.

### 19. Positive: Read Replicas for Query Load Distribution

**Strength:** Section 7.3 includes "Database read replicas for query load distribution" which is critical for:
- High-volume read operations (portfolio valuations, market data queries)
- Separating OLTP writes from OLAP analytics queries
- Reducing contention on primary database instance

Ensure replica lag is monitored and queries with strong consistency requirements (e.g., transaction status checks) are routed to primary.

### 20. Positive: Blue-Green Deployment for Zero-Downtime

**Strength:** Section 6.4 specifies "Blue-green deployment strategy" which prevents performance degradation during releases by:
- Warming up new environment before traffic cutover
- Validating performance metrics before switching load balancer
- Enabling instant rollback without downtime

Consider adding: "Run performance smoke tests on blue environment before promoting to production."

---

## Summary

This design document establishes a solid architectural foundation with microservices, appropriate technology choices (PostgreSQL for transactional data, InfluxDB for time-series, Redis for caching), and scalability patterns (read replicas, horizontal scaling, event-driven processing). However, the **absence of quantitative performance requirements, missing optimization strategies for high-frequency operations, and lack of batch processing controls** pose significant risks to production performance.

**Highest Priority Actions:**
1. Define performance SLAs with specific latency/throughput targets (Critical Issue #1)
2. Design batch price fetching to prevent N+1 queries in portfolio operations (Critical Issue #2)
3. Add pagination and result limits to all list/historical data endpoints (Critical Issues #3, #14)
4. Specify database index design for all high-frequency query patterns (Critical Issue #4)
5. Design tiered caching strategy for market data access (Critical Issue #5)
6. Add concurrency controls and rate limiting for batch rebalancing (Critical Issue #6)

Addressing these issues will prevent performance bottlenecks from becoming production incidents and ensure the system can meet the demands of retail investors expecting real-time responsiveness.
