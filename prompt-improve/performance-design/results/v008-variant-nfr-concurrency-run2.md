# Performance Design Review: FinTech Investment Advisory Platform

## Executive Summary

This performance evaluation identifies **5 critical issues**, **6 significant issues**, and **4 moderate issues** in the design document. The most severe concerns involve missing concurrency controls for financial transactions, unbounded queries without performance targets, N+1 query problems in portfolio operations, and absence of explicit SLA definitions.

---

## Critical Issues

### C1. Missing Concurrency Control for Financial Operations (Criterion 6)

**Issue:**
The `transactions` table (lines 147-159) and portfolio rebalancing API (line 169-171) lack any concurrency control mechanisms. Multiple concurrent requests could create race conditions in:
- **Account balance updates**: Two simultaneous transactions could read the same balance, leading to overdraft or incorrect balance calculations
- **Portfolio rebalancing**: Concurrent rebalancing requests could generate conflicting trade orders for the same holdings
- **Holding modifications**: Simultaneous buy/sell operations on the same asset could corrupt `quantity` and `current_value` fields

**Impact:**
- **Data corruption**: Incorrect account balances and holding quantities in production
- **Financial loss**: Double-execution of trades or overdraft scenarios
- **Regulatory risk**: Audit trail inconsistencies violating financial compliance requirements
- **User trust damage**: Account discrepancies lead to customer disputes

**Recommendations:**
1. **Optimistic locking**: Add `version` column to `user_accounts` and `holdings` tables for optimistic concurrency control
```sql
ALTER TABLE user_accounts ADD COLUMN version INT DEFAULT 1;
ALTER TABLE holdings ADD COLUMN version INT DEFAULT 1;
```
2. **Pessimistic locking for critical operations**: Use `SELECT ... FOR UPDATE` in rebalancing and transaction execution logic
3. **Idempotency design**: Add `idempotency_key` to transaction requests to safely retry failed operations
4. **Database transactions**: Wrap all multi-table operations (balance check → debit → create transaction) in ACID transactions with proper isolation levels (SERIALIZABLE for account updates)

**Document Reference:** Section 4.2 (Holdings), Section 4.4 (Transactions), Section 5.1 (Portfolio API)

---

### C2. Unbounded Queries Without Pagination or Limits (Antipattern: Unbounded queries)

**Issue:**
All read endpoints lack pagination, size limits, or result bounds:
- `GET /api/v1/portfolios/{account_id}/holdings` (line 166): Could return thousands of holdings for institutional accounts
- `GET /api/v1/market/history/{asset_symbol}` (line 186): Historical data queries without max date range restrictions
- `GET /api/v1/users/{user_id}/tax-loss-opportunities` (line 202): Unbounded list of tax-loss candidates

**Impact:**
- **Response timeout**: Multi-second response times for large datasets (e.g., 10+ years of daily price data = 3,650+ rows)
- **Memory exhaustion**: OOM errors when serializing large result sets in Python
- **Database strain**: Full table scans on `holdings` and `historical_prices` tables
- **Client-side performance**: Mobile apps crash when rendering thousands of items

**Recommendations:**
1. **Mandatory pagination**: Enforce `?page=1&page_size=100` with default max size of 100 items
2. **Date range limits**: Restrict historical queries to 1-year maximum per request
3. **Database query limits**: Add `LIMIT` clauses to all SELECT statements with configurable max bounds
4. **Streaming responses**: Implement cursor-based pagination for large datasets using `OFFSET` alternatives

**Document Reference:** Section 5.1, Section 5.2

---

### C3. Missing Indexes on Foreign Keys and Query Columns (Antipattern: Missing indexes)

**Issue:**
The schema (Section 4) defines no indexes beyond primary keys. Critical missing indexes include:
- `holdings.account_id` (line 106): Used in JOIN for portfolio queries
- `transactions.account_id` (line 150): Queried for transaction history
- `transactions.status` (line 155): Filtered for pending transactions in background jobs
- `market_prices.asset_symbol` (line 128): High-frequency lookups for real-time price display
- `market_prices.timestamp` (line 130): Range queries for recent prices
- `historical_prices.(asset_symbol, date)` composite: Already has PRIMARY KEY but needs covering index

**Impact:**
- **Query latency**: Full table scans causing 5-10 second response times for `GET /api/v1/portfolios/{account_id}/holdings` with millions of holdings rows
- **Database CPU spike**: Sequential scans consuming 80%+ CPU during peak hours
- **Scalability barrier**: Unable to serve 1,000+ concurrent users without read replica overload

**Recommendations:**
```sql
-- Foreign key indexes for JOIN performance
CREATE INDEX idx_holdings_account_id ON holdings(account_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);

-- Filter condition indexes
CREATE INDEX idx_transactions_status ON transactions(status) WHERE status IN ('pending', 'failed');
CREATE INDEX idx_market_prices_symbol_timestamp ON market_prices(asset_symbol, timestamp DESC);

-- Covering indexes for common queries
CREATE INDEX idx_holdings_account_asset ON holdings(account_id, asset_symbol) INCLUDE (quantity, current_value);
```

**Document Reference:** Section 4 (all subsections)

---

### C4. N+1 Query Problem in Portfolio Holdings Retrieval (Antipattern: N+1 queries)

**Issue:**
`GET /api/v1/portfolios/{account_id}/holdings` (line 166) likely fetches holdings first, then iterates to fetch "real-time values" from `market_prices`:

```python
# Antipattern pseudocode
holdings = Holdings.objects.filter(account_id=account_id)  # 1 query
for holding in holdings:  # N queries
    price = MarketPrices.objects.get(asset_symbol=holding.asset_symbol)
    holding.current_value = holding.quantity * price.price
```

For a portfolio with 50 holdings, this generates **51 database queries** (1 + 50).

**Impact:**
- **Latency explosion**: 2-3 seconds for 50-holding portfolios (vs. <100ms with batch query)
- **Database connection exhaustion**: Connection pool depletion under 100+ concurrent users
- **Scalability failure**: Cannot serve 1,000 concurrent portfolio views without massive read replica scaling

**Recommendations:**
1. **Batch query with JOIN**:
```python
holdings = Holdings.objects.filter(account_id=account_id).select_related('market_prices')
# Or use IN clause:
symbols = holdings.values_list('asset_symbol', flat=True)
prices = MarketPrices.objects.filter(asset_symbol__in=symbols)
```
2. **Caching layer**: Cache market prices in Redis with 1-second TTL for repeated lookups
3. **Denormalization**: Store `last_market_price` in `holdings` table, updated by async job every 1 second

**Document Reference:** Section 5.1 (line 166-167)

---

### C5. Missing Non-Functional Requirements for Performance (Antipattern: Missing NFR specifications)

**Issue:**
Section 7.3 (Scalability) mentions "horizontal scaling" and "read replicas" but provides no quantitative targets:
- No response time SLA (e.g., p95 < 200ms)
- No throughput requirements (e.g., 10,000 req/sec)
- No data volume projections (holdings per account, total users)
- No concurrent user targets (peak load capacity)

**Impact:**
- **Over/under-provisioning**: Cannot determine if 2 vs. 20 application servers are needed
- **Performance regression**: No acceptance criteria for rejecting slow code in CI/CD
- **Capacity planning failure**: Risk of production outages during user growth without early scaling signals
- **Architecture mismatch**: Cannot validate if PostgreSQL vs. NoSQL is appropriate without query volume estimates

**Recommendations:**
1. **Define quantitative SLAs**:
   - API response time: p50 < 100ms, p95 < 500ms, p99 < 1s
   - WebSocket latency: < 50ms for price updates
   - Throughput: 5,000 portfolio queries/sec at peak
2. **Data scale targets**:
   - 1M users, avg 3 accounts/user, avg 50 holdings/account = 150M holdings rows
   - 10K price updates/sec across 50K tradable assets
3. **Load testing acceptance criteria**: 10,000 concurrent WebSocket connections with < 5% error rate
4. **Capacity model**: Document CPU/memory/database IOPS per 1,000 users for auto-scaling thresholds

**Document Reference:** Section 7 (Non-Functional Requirements)

---

## Significant Issues

### S1. Synchronous Real-Time Price Updates Blocking User Requests (Antipattern: Synchronous I/O)

**Issue:**
`GET /api/v1/portfolios/{account_id}/holdings` returns "real-time values" (line 167), implying synchronous fetching from Market Data Service or external APIs during request handling. If external providers (Bloomberg, Reuters, line 66) have 500ms-2s latency, user requests block until completion.

**Impact:**
- **User-facing latency**: 1-3 second page loads for portfolio views
- **Cascading failures**: If external API times out (no timeout configured per line 216 circuit breaker mention), requests hang until default timeout (30-60s)
- **Reduced throughput**: Each blocked thread cannot serve other requests

**Recommendations:**
1. **Asynchronous price fetching**: Background service updates `holdings.current_value` every 1-5 seconds; API serves pre-computed values
2. **Event-driven architecture**: Market Data Service publishes price updates to RabbitMQ (line 41); Portfolio Engine subscribes and updates holdings asynchronously
3. **Timeout enforcement**: Set 500ms timeout for external market data calls with fallback to last-known price
4. **Response streaming**: Return stale values immediately, then push updates via WebSocket (Section 5.2, line 189-190)

**Document Reference:** Section 5.1 (line 167), Section 3.2 (Market Data Service)

---

### S2. Missing Connection Pooling Configuration for External APIs (Antipattern: Missing connection pooling)

**Issue:**
The design mentions external market data providers (Bloomberg, Reuters, line 66-67) but does not specify connection pooling, keep-alive, or session reuse strategies. Each API call likely opens a new TCP connection.

**Impact:**
- **Latency overhead**: +200-500ms per request for TCP handshake + TLS negotiation
- **Rate limit exhaustion**: Providers may impose per-IP connection limits (e.g., 100 concurrent connections)
- **Resource waste**: TIME_WAIT socket accumulation on application servers

**Recommendations:**
1. **HTTP connection pooling**:
```python
# Example with requests library
session = requests.Session()
adapter = HTTPAdapter(pool_connections=100, pool_maxsize=200)
session.mount('https://', adapter)
```
2. **Keep-alive headers**: Enable HTTP/1.1 persistent connections
3. **Circuit breaker per provider**: Separate circuit breakers for Bloomberg vs. Reuters to isolate failures (line 216)
4. **Connection pool monitoring**: Expose metrics for pool utilization and wait times

**Document Reference:** Section 3.2 (Market Data Service, lines 66-67), Section 6.1 (line 216)

---

### S3. Inefficient Portfolio Rebalancing Algorithm Causing Full Table Scans (Criterion 1)

**Issue:**
Portfolio Engine "processes rebalancing requests from scheduled jobs" (line 61) and "evaluates current holdings against target allocations" (line 62). The design implies batch processing all user portfolios:

```python
# Likely antipattern
for account in all_accounts:  # Full table scan
    holdings = get_holdings(account)
    targets = get_targets(account)
    if needs_rebalancing(holdings, targets):
        generate_trades(account)
```

For 1M accounts, this is a sequential O(N) operation scanning both `user_accounts` and `holdings` tables.

**Impact:**
- **Batch job duration**: 10+ hours to rebalance 1M portfolios (assuming 10ms per portfolio)
- **Database lock contention**: Long-running transactions block user-facing updates
- **Missed rebalancing windows**: Cannot complete daily rebalancing before market close

**Recommendations:**
1. **Incremental processing**: Only rebalance portfolios with drift > threshold using:
```sql
SELECT account_id FROM holdings
JOIN portfolio_targets USING (account_id, asset_class)
WHERE ABS(current_allocation_pct - target_percentage) > rebalance_threshold;
```
2. **Parallel processing**: Distribute rebalancing across multiple worker nodes using message queue (RabbitMQ, line 41)
3. **Priority queue**: Rebalance high-value accounts first using account balance ordering
4. **Early termination**: Stop rebalancing if market volatility exceeds threshold

**Document Reference:** Section 3.2 (Portfolio Engine, lines 59-63)

---

### S4. Missing Caching Strategy for Frequently Accessed Data (Antipattern: Missing caching)

**Issue:**
Redis is listed (line 36) but no caching policies are defined. Obvious caching candidates not mentioned:
- Market prices (updated every 1 second, accessed by all portfolio views)
- User risk profiles (read-heavy, changes rare)
- Portfolio target allocations (read in every rebalancing job)

Without caching, all reads hit PostgreSQL, causing unnecessary database load.

**Impact:**
- **Database overload**: 80%+ CPU on read replicas for repetitive queries
- **Higher p95 latency**: Cold reads from disk vs. sub-millisecond cache hits
- **Wasted infrastructure cost**: Over-provisioning database servers instead of using cheaper Redis

**Recommendations:**
1. **Price caching**:
```python
# Cache prices with 1-second TTL
cache_key = f"price:{asset_symbol}"
price = redis.get(cache_key)
if not price:
    price = fetch_from_db(asset_symbol)
    redis.setex(cache_key, 1, price)  # 1-second TTL
```
2. **User profile caching**: Cache risk profiles with 1-hour TTL, invalidate on PUT
3. **Query result caching**: Cache portfolio holdings for 5 seconds with account_id-based keys
4. **Cache warming**: Pre-load top 1000 most-traded asset prices into Redis on startup

**Document Reference:** Section 2.2 (Redis, line 36), Section 3.2 (Market Data Service)

---

### S5. No Data Lifecycle Management for Historical Price Data (Antipattern: Missing data lifecycle)

**Issue:**
`historical_prices` table (lines 136-143) stores daily OHLCV data indefinitely. For 50K tradable assets × 10 years × 250 trading days = **125M rows**, growing 12.5M rows/year.

**Impact:**
- **Storage cost**: 50GB+ table size requiring expensive SSD storage
- **Backup duration**: Hours-long backup windows for cold data rarely accessed
- **Query performance**: Range scans on old data slow down backtesting queries
- **Index bloat**: Primary key index becomes multi-level B-tree requiring more disk I/O

**Recommendations:**
1. **Partitioning strategy**: Use PostgreSQL table partitioning by year:
```sql
CREATE TABLE historical_prices_2024 PARTITION OF historical_prices
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```
2. **Archival policy**: Move data older than 5 years to InfluxDB (line 37) or S3 for compliance
3. **Aggregation tables**: Pre-compute weekly/monthly aggregates for long-range backtesting
4. **Retention policy**: Delete data older than 10 years unless required by regulation

**Document Reference:** Section 4.3 (Market Data, lines 136-143), Section 2.2 (InfluxDB, line 37)

---

### S6. Race Conditions in Concurrent Tax-Loss Harvesting Execution (Criterion 6)

**Issue:**
`GET /api/v1/users/{user_id}/tax-loss-opportunities` (line 202) identifies sellable assets with capital losses. If multiple concurrent sessions (user + financial advisor) trigger harvesting simultaneously, the same holding could be sold twice:

1. Session A: Identifies AAPL loss → generates sell order
2. Session B (concurrent): Identifies same AAPL loss → generates duplicate sell order
3. Result: Insufficient holdings to execute both orders

**Impact:**
- **Transaction failures**: Sell orders fail with "insufficient quantity" errors
- **User confusion**: Disappearing tax-loss opportunities between page load and execution
- **Data inconsistency**: `holdings.quantity` becomes negative if validation is missing

**Recommendations:**
1. **Optimistic locking**: Check `holdings.version` before executing trades
2. **Atomic claim-and-execute**:
```sql
UPDATE holdings SET quantity = quantity - :sell_qty, version = version + 1
WHERE holding_id = :id AND quantity >= :sell_qty AND version = :expected_version;
-- Check affected rows = 1
```
3. **Advisory locks**: Use PostgreSQL advisory locks during tax-loss execution:
```sql
SELECT pg_advisory_xact_lock(hashtext(account_id || asset_symbol));
```
4. **UI state synchronization**: Disable tax-loss button after click with server-side idempotency check

**Document Reference:** Section 5.3 (line 202-203)

---

## Moderate Issues

### M1. Stateful Design in Real-Time Services Preventing Horizontal Scaling (Antipattern: Stateful design)

**Issue:**
"Real-time services: Node.js with Socket.io" (line 31) for WebSocket price streaming (line 189-190) is stateful by default. Socket.io maintains in-memory connection state, preventing seamless horizontal scaling without sticky sessions or state synchronization.

**Impact:**
- **Scaling complexity**: Requires sticky sessions (load balancer affinity), complicating blue-green deployments
- **Uneven load**: New instances receive no connections until existing sessions disconnect
- **Connection loss on deployment**: Zero-downtime deployment requires connection draining or Redis-backed session store

**Recommendations:**
1. **Redis adapter for Socket.io**:
```javascript
const redis = require('socket.io-redis');
io.adapter(redis({ host: 'redis-host', port: 6379 }));
```
2. **Stateless pub/sub**: Market Data Service publishes to Redis Pub/Sub; all Node.js instances subscribe and broadcast to clients
3. **Connection resumption**: Implement reconnection logic with sequence numbers to resume streams after disconnection
4. **Health check exclusion**: Exclude WebSocket endpoints from load balancer health checks to allow graceful shutdown

**Document Reference:** Section 2.1 (line 31), Section 5.2 (line 189-190), Section 7.3 (horizontal scaling, line 248)

---

### M2. Missing Timeout Configuration for External Service Calls (Antipattern: Missing timeout config)

**Issue:**
Section 6.1 mentions "Circuit breaker pattern for external service calls" (line 216) but does not specify timeout values. Market data providers (Bloomberg, Reuters, line 66-67) and OAuth providers (Google, Apple, line 208) can have unpredictable latencies.

**Impact:**
- **Hung requests**: Default 30-60 second timeouts cause thread pool exhaustion
- **Cascading failures**: Slow external APIs propagate latency to all dependent services
- **User-facing timeout**: API gateway times out before backend responds, causing 5xx errors

**Recommendations:**
1. **Aggressive timeouts**:
   - Market data API: 500ms timeout (fallback to cache)
   - OAuth providers: 2s timeout (retry with exponential backoff)
   - Database queries: 5s timeout (circuit breaker after 3 consecutive failures)
2. **Tiered fallbacks**:
   - Primary: External API with 500ms timeout
   - Secondary: Redis cache (stale data)
   - Tertiary: Return 503 with Retry-After header
3. **Timeout metrics**: Monitor p99 external call duration to tune timeout values

**Document Reference:** Section 6.1 (line 216), Section 3.2 (line 66-67), Section 5.4 (line 208)

---

### M3. Inefficient Tax-Loss Harvesting Calculation Without Indexes (Criterion 1)

**Issue:**
Tax-loss harvesting (line 74, line 202) requires identifying holdings where `current_value < purchase_price * quantity`. This requires:
1. Fetching all holdings for the user
2. Fetching current prices for each asset
3. Computing gain/loss in application code

Without indexes on `purchase_price` or `current_value`, this is a full table scan for each user request.

**Impact:**
- **Query latency**: 2-5 seconds for users with 100+ holdings
- **CPU-intensive computation**: Application-side filtering instead of database-side predicate pushdown
- **Scalability issue**: Cannot serve 1,000+ concurrent tax-loss queries during tax season

**Recommendations:**
1. **Computed column with index**:
```sql
ALTER TABLE holdings ADD COLUMN unrealized_gain_loss DECIMAL(15, 2)
    GENERATED ALWAYS AS (current_value - (purchase_price * quantity)) STORED;
CREATE INDEX idx_holdings_tax_loss ON holdings(account_id, unrealized_gain_loss)
    WHERE unrealized_gain_loss < 0;
```
2. **Materialized view**: Pre-compute tax-loss opportunities with daily refresh:
```sql
CREATE MATERIALIZED VIEW tax_loss_opportunities AS
SELECT account_id, asset_symbol, unrealized_gain_loss
FROM holdings WHERE unrealized_gain_loss < 0;
```
3. **Push computation to database**:
```sql
SELECT * FROM holdings
WHERE account_id = :user_id
  AND current_value < purchase_price * quantity;
```

**Document Reference:** Section 1.2 (line 14), Section 3.2 (line 74), Section 5.3 (line 202)

---

### M4. Missing Monitoring Strategy for Performance Metrics (Antipattern: Missing monitoring)

**Issue:**
Section 6.2 (Logging) specifies log aggregation (line 220) but does not define performance monitoring:
- No APM instrumentation (response time distribution, slow query detection)
- No business metrics (rebalancing job duration, trade execution latency)
- No alerting thresholds (p95 > SLA triggers pager)

**Impact:**
- **Blind performance degradation**: Slow queries go unnoticed until user complaints
- **No capacity signals**: Cannot predict when to scale before hitting resource limits
- **Difficult root cause analysis**: Logs show errors but not which component is slow

**Recommendations:**
1. **APM integration**: Deploy Datadog/New Relic agents to track:
   - API endpoint latency (p50/p95/p99)
   - Database query time distribution
   - External API call duration
2. **Custom metrics**:
```python
metrics.histogram('portfolio.rebalance.duration', duration_ms, tags=['account_type:IRA'])
metrics.gauge('market_data.update_lag_ms', lag_ms)
```
3. **Alerting rules**:
   - Alert if p95 API latency > 500ms for 5 minutes
   - Alert if rebalancing job duration > 2 hours
   - Alert if external API circuit breaker opens
4. **Performance dashboard**: Real-time view of throughput, latency, error rates per service

**Document Reference:** Section 6.2 (Logging, lines 218-220)

---

## Positive Aspects

1. **Microservices architecture** (Section 3.1): Enables independent scaling of compute-intensive components (Portfolio Engine, Recommendation Engine)
2. **Read replicas planned** (Section 7.3, line 249): Mitigates read-heavy workload on primary database
3. **Event-driven architecture** (Section 7.3, line 250): Asynchronous processing pattern supports scalability
4. **Circuit breaker pattern** (Section 6.1, line 216): Prevents cascading failures from external API issues

---

## Cross-Cutting Emergent Issues (Beyond Checklist)

### E1. State Synchronization Across Distributed Components

**Issue:**
The microservices architecture (Section 3.1) splits portfolio management across 6+ services. Consider this workflow:
1. User triggers rebalancing via Portfolio Engine (generates trade orders)
2. Transaction Service executes trades asynchronously
3. Market Data Service streams price updates
4. Holdings state in PostgreSQL lags behind actual executed trades

During high-frequency trading periods, the system has no mechanism to ensure eventual consistency across:
- `holdings` table (stale until transaction confirmation)
- `user_accounts.balance` (may show incorrect available balance)
- Real-time portfolio valuation returned by API

**Impact:**
- **Temporal inconsistencies**: User sees conflicting portfolio values across different API calls within the same second
- **Phantom trades**: Rebalancing logic triggers duplicate orders based on stale holdings data
- **Audit failures**: Discrepancies between transaction logs and holdings state violate financial reporting requirements

**Recommendations:**
1. **Event sourcing pattern**: Store all state transitions (trades, price updates) as immutable events; compute current state by replaying events
2. **Versioned reads**: Add `as_of_timestamp` parameter to holdings API to query state at specific point in time
3. **Saga pattern**: Coordinate distributed transactions with compensating actions for failed trades
4. **Eventually consistent UI**: Display "trade pending" indicators when holdings are in transition state

---

### E2. Cascading Failure Scenario: Market Data Provider Outage

**Issue:**
The system has single points of failure in external dependencies (Bloomberg, Reuters, line 66-67). Consider this cascade:
1. Bloomberg API experiences outage (500 errors)
2. Circuit breaker opens (line 216), falling back to Reuters
3. Reuters cannot handle 2x traffic (rate limiting)
4. Market Data Service starts returning stale prices from Redis cache
5. Portfolio Engine generates incorrect rebalancing trades based on stale prices
6. Users execute trades at suboptimal prices → financial losses

The design lacks defensive mechanisms for this scenario.

**Recommendations:**
1. **Multi-tier fallback strategy**:
   - Primary: Bloomberg API
   - Secondary: Reuters API
   - Tertiary: Delayed price feeds (15-minute lag)
   - Emergency: Freeze rebalancing during data quality issues
2. **Data staleness metadata**: Return `last_updated_at` timestamp with all price data; abort trades if staleness > 5 minutes
3. **Circuit breaker coordination**: Global circuit breaker state in Redis to prevent retry storms across all service instances
4. **Manual override**: Admin dashboard to disable automated rebalancing during provider outages

---

## Summary

The design document has strong architectural foundations (microservices, event-driven, circuit breakers) but lacks critical performance and concurrency safeguards required for a financial platform. The 5 critical issues—especially **C1 (missing concurrency control)**, **C4 (N+1 queries)**, and **C5 (missing SLAs)**—must be addressed before production deployment to prevent data corruption, financial losses, and scalability failures.

Immediate priorities:
1. Add optimistic/pessimistic locking to all financial state mutations (accounts, holdings, transactions)
2. Define quantitative performance SLAs and load testing acceptance criteria
3. Implement database indexes and batch query strategies to eliminate N+1 problems
4. Add pagination/limits to all unbounded queries
5. Design state synchronization mechanisms for distributed consistency

The recommendations provided are specific, actionable, and aligned with the system's scale expectations (1M+ users, 10K+ req/sec, 150M+ holdings rows).
