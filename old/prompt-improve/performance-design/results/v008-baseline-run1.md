# Performance Design Review - FinTech Investment Advisory Platform

## Executive Summary

This performance review identifies **8 critical issues**, **6 significant issues**, and **5 moderate issues** in the design document. The most severe concerns involve unbounded database queries, missing indexes on high-frequency access patterns, N+1 query risks in portfolio operations, and absence of performance SLA specifications. The architecture shows awareness of scalability (horizontal scaling, read replicas) but lacks concrete implementation details for key performance-critical paths.

---

## Critical Issues

### C-1: Unbounded Queries Without Pagination (Data Access Antipattern)

**Location:** API Design (Section 5)

**Issue:**
The following endpoints lack pagination or result size limits:
- `GET /api/v1/portfolios/{account_id}/holdings` - Could return thousands of holdings for institutional accounts
- `GET /api/v1/portfolios/{account_id}/performance` - Historical metrics without time bounds
- `GET /api/v1/market/history/{asset_symbol}` - Date range parameters exist but no max result limit specified

**Impact:**
- **Latency:** Query execution time grows linearly with data volume (O(n))
- **Memory:** Risk of OOM errors when loading large result sets into application memory
- **Throughput degradation:** Database connection pool exhaustion under concurrent unbounded queries
- **User experience:** Frontend timeouts (typical browser timeout: 30-60s)

**Recommendation:**
```
Implement mandatory pagination:
- Add `?page=N&page_size=M` parameters (default page_size=100, max=1000)
- For /market/history, enforce max_days=365 or max_records=10000
- Return pagination metadata: { "data": [...], "total": N, "page": M, "page_size": K }
- Document pagination requirements in API specification
```

---

### C-2: Missing Database Indexes on High-Frequency Query Patterns

**Location:** Data Model (Section 4)

**Issue:**
The schema definitions lack explicit index declarations for predictable query patterns:

**Critical missing indexes:**
1. `holdings.account_id` - Queried on every portfolio view (full table scan risk)
2. `holdings.asset_symbol` - Required for aggregations across accounts
3. `market_prices.asset_symbol` - Real-time price lookups for portfolio valuation
4. `market_prices.timestamp` - Time-range queries for charting
5. `historical_prices.asset_symbol, date` - Already has composite PK, but reverse lookups by date need consideration
6. `transactions.account_id` - Transaction history queries
7. `transactions.status` - Filtering pending/failed transactions
8. `transactions.executed_at` - Time-based transaction reports

**Impact:**
- **Performance degradation:** Sequential scans on tables with millions of rows
- **Latency multiplication:** Each unindexed query adds 100ms-10s depending on table size
- **Lock contention:** Longer-running queries hold shared locks, blocking writes
- **Scalability ceiling:** Query performance degrades non-linearly as data grows

**Recommendation:**
```sql
-- Portfolio queries (critical path)
CREATE INDEX idx_holdings_account_id ON holdings(account_id);
CREATE INDEX idx_holdings_asset_symbol ON holdings(asset_symbol);
CREATE INDEX idx_holdings_account_asset ON holdings(account_id, asset_symbol);

-- Market data lookups
CREATE INDEX idx_market_prices_symbol_time ON market_prices(asset_symbol, timestamp DESC);
CREATE INDEX idx_market_prices_timestamp ON market_prices(timestamp) WHERE timestamp > NOW() - INTERVAL '1 day';

-- Transaction processing
CREATE INDEX idx_transactions_account_id ON transactions(account_id, executed_at DESC);
CREATE INDEX idx_transactions_status ON transactions(status) WHERE status != 'completed';

-- Consider partial indexes for hot data (last 90 days)
CREATE INDEX idx_recent_holdings ON holdings(last_updated) WHERE last_updated > NOW() - INTERVAL '90 days';
```

---

### C-3: N+1 Query Problem in Portfolio Holdings Retrieval

**Location:** API Design Section 5.1 - `GET /api/v1/portfolios/{account_id}/holdings`

**Issue:**
The endpoint returns "List of current holdings with real-time values." This implies:
1. Fetch holdings from database: `SELECT * FROM holdings WHERE account_id = ?`
2. For each holding, fetch current market price: `SELECT price FROM market_prices WHERE asset_symbol = ?`

This creates N+1 queries where N = number of holdings (typically 10-100 per account, potentially 1000+ for institutional accounts).

**Impact:**
- **Latency:** 10 holdings × 5ms per query = 50ms additional latency (vs. 5ms for single batch query)
- **Database load:** 100 concurrent users with 20 holdings each = 2000 QPS (vs. 100 QPS with batch fetching)
- **Network overhead:** Multiple round-trips between application and database

**Recommendation:**
```python
# Anti-pattern (N+1)
holdings = Holdings.objects.filter(account_id=account_id)
for holding in holdings:
    holding.current_price = MarketPrice.objects.get(asset_symbol=holding.asset_symbol).price

# Correct approach (single join query or batch fetch)
holdings = Holdings.objects.filter(account_id=account_id).select_related('market_price')

# Or use subquery:
SELECT h.*,
       (SELECT mp.price FROM market_prices mp
        WHERE mp.asset_symbol = h.asset_symbol
        ORDER BY mp.timestamp DESC LIMIT 1) as current_price
FROM holdings h
WHERE h.account_id = ?;

# Or batch fetch in application:
holdings = Holdings.objects.filter(account_id=account_id)
symbols = [h.asset_symbol for h in holdings]
prices = MarketPrice.objects.filter(asset_symbol__in=symbols).order_by('timestamp').distinct('asset_symbol')
price_map = {p.asset_symbol: p.price for p in prices}
for holding in holdings:
    holding.current_price = price_map.get(holding.asset_symbol)
```

---

### C-4: Missing Performance SLA Specifications (Architectural Antipattern)

**Location:** Section 7.3 (Scalability) - NFR section lacks concrete performance targets

**Issue:**
The document specifies "99.9% uptime target" but omits critical performance SLAs:
- No latency requirements (p50, p95, p99 response times)
- No throughput targets (requests/second, concurrent users)
- No data volume planning (expected growth: users, transactions, market data points)
- No query performance budgets for critical paths

**Impact:**
- **Unvalidated architecture:** Cannot verify if design choices (PostgreSQL, Redis, InfluxDB) meet requirements
- **Optimization blindness:** No baseline to measure improvements against
- **Scalability unknown:** "Horizontal scaling" mentioned but no capacity planning
- **Production incidents:** Reactive firefighting instead of proactive monitoring

**Recommendation:**
```markdown
## 7.4 Performance Requirements

### Latency SLAs
- Portfolio holdings retrieval: p95 < 200ms, p99 < 500ms
- Real-time price updates (WebSocket): < 100ms from market source to client
- Rebalancing calculation: < 2s for portfolios with <100 holdings, < 10s for <1000 holdings
- Transaction execution API: p95 < 500ms (excluding external brokerage latency)
- User profile queries: p95 < 100ms

### Throughput Requirements
- Peak concurrent users: 50,000 (market open hours)
- API requests: 10,000 req/s sustained, 25,000 req/s peak
- Real-time price updates: 500 symbols × 1 update/sec = 500 events/sec
- Batch rebalancing: Process 100,000 accounts in 4-hour overnight window

### Data Volume Projections (Year 1 → Year 3)
- Users: 100K → 1M
- Accounts: 150K → 1.5M
- Holdings records: 3M → 30M
- Daily transactions: 50K → 500K
- Market price data points: 10M/day → 50M/day
- Historical data retention: 10 years (regulatory requirement)

### Query Performance Budgets
- Single-record lookups: < 5ms
- Aggregation queries (dashboard): < 200ms
- Complex analytics (tax-loss harvesting): < 5s
- Batch jobs (nightly rebalancing): Complete within 4-hour window
```

---

### C-5: Real-Time Market Data Synchronization Without Rate Limiting

**Location:** Section 3.2 (Market Data Service) and Section 5.2 (WebSocket API)

**Issue:**
The design specifies "Real-time price streaming to connected clients" via WebSocket but lacks:
- Rate limiting strategy for price update broadcasts
- Throttling mechanism for high-frequency updates
- Client-side update batching strategy

**Impact:**
- **WebSocket connection saturation:** Broadcasting every price tick (potentially 10-100 updates/sec per symbol) to 50,000 concurrent users
- **Bandwidth costs:** 100 bytes/update × 100 updates/sec × 50,000 users = 500 MB/sec = 4 Gbps
- **Client-side performance:** JavaScript event loop blocking from high-frequency DOM updates
- **Unnecessary precision:** Most users don't need millisecond-level price updates for investment decisions

**Recommendation:**
```javascript
// Implement adaptive rate limiting:
- Throttle updates to max 1/sec per symbol for standard users (99% use case)
- VIP/active traders: 10 updates/sec with WebSocket compression
- Batch multiple symbol updates in single message:
  { "type": "price_batch", "updates": [{"symbol": "AAPL", "price": 150.25}, ...] }

// Server-side throttling (Redis + sliding window):
function shouldBroadcastUpdate(symbol, price, lastBroadcastTime) {
    const minInterval = 1000; // 1 second
    const timeSinceLastBroadcast = Date.now() - lastBroadcastTime;
    const significantPriceChange = Math.abs(price - lastPrice) / lastPrice > 0.001; // 0.1%

    return timeSinceLastBroadcast > minInterval || significantPriceChange;
}

// Client-side update batching (React optimization):
const [prices, setPrices] = useState({});
useEffect(() => {
    const buffer = [];
    const flushInterval = 200; // Batch updates every 200ms

    ws.onmessage = (event) => {
        buffer.push(JSON.parse(event.data));
    };

    const interval = setInterval(() => {
        if (buffer.length > 0) {
            setPrices(prev => ({ ...prev, ...Object.fromEntries(buffer) }));
            buffer.length = 0;
        }
    }, flushInterval);

    return () => clearInterval(interval);
}, []);
```

---

### C-6: Portfolio Rebalancing Without Async Processing (Long-Running Operation)

**Location:** Section 5.1 - `POST /api/v1/portfolios/{account_id}/rebalance`

**Issue:**
The API design suggests synchronous response: "Response: List of recommended trades." However, rebalancing involves:
1. Fetching current holdings (N queries)
2. Calculating target allocations (ML model inference + optimization solver)
3. Evaluating tax implications for each potential trade
4. Generating trade orders with transaction cost minimization

For portfolios with 50-100 holdings, this computation can take 5-30 seconds.

**Impact:**
- **Request timeout:** Synchronous API calls block for 5-30s, exceeding typical timeout thresholds
- **Resource exhaustion:** Long-running requests tie up web server threads/processes
- **Poor UX:** User waits with loading spinner for 30s (perceived as application freeze)
- **Retry storms:** Timeout → client retry → duplicate rebalancing calculations

**Recommendation:**
```
Implement async processing pattern:

1. POST /api/v1/portfolios/{account_id}/rebalance
   Response: 202 Accepted
   { "job_id": "uuid", "status": "pending", "estimated_completion": "2024-01-15T10:05:30Z" }

2. GET /api/v1/jobs/{job_id}
   Response:
   { "job_id": "uuid", "status": "completed", "result": { "trades": [...] } }
   Status: pending | processing | completed | failed

3. WebSocket notification when complete:
   { "type": "rebalance_complete", "job_id": "uuid", "account_id": "..." }

4. Background worker implementation:
   - Use RabbitMQ (already in tech stack) for job queue
   - Celery workers for rebalancing computation
   - Redis for job status tracking
   - Set timeout: 60s for computation, auto-fail if exceeded

5. Frontend handling:
   - Optimistic UI: Show "Calculating recommendations..." status
   - Poll job status every 2s (exponential backoff)
   - Enable user to navigate away and return later
```

---

### C-7: Missing Connection Pool Configuration for Database and External Services

**Location:** Infrastructure (Section 2.3) and Architecture (Section 3)

**Issue:**
The design specifies PostgreSQL, Redis, MongoDB, and external market data providers (Bloomberg, Reuters) but lacks connection pool configuration:
- No pool size specifications
- No connection timeout settings
- No retry/backoff strategies for pool exhaustion

**Impact:**
- **Connection exhaustion under load:** Default pool sizes (often 10-20) insufficient for 10,000 req/s
- **Latency spikes:** Requests queued waiting for available connections
- **Cascading failures:** Slow queries hold connections, blocking other requests
- **External API rate limit violations:** Unbounded concurrent calls to Bloomberg/Reuters

**Recommendation:**
```python
# PostgreSQL connection pool (using psycopg2/Django)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'OPTIONS': {
            'connect_timeout': 5,
            'options': '-c statement_timeout=30000',  # 30s query timeout
        },
        'CONN_MAX_AGE': 600,  # Connection reuse: 10 minutes
    }
}

# Application-level pool (using pgbouncer recommended)
# Deploy pgbouncer as sidecar for connection multiplexing:
# - Pool mode: transaction (balance connection reuse and transaction safety)
# - Max client connections: 10,000
# - Default pool size: 100 (tune based on RDS instance vCPU count)
# - Reserve pool: 10 (emergency connections)

# Redis connection pool (redis-py)
redis_pool = redis.ConnectionPool(
    host='redis.example.com',
    port=6379,
    max_connections=200,  # 2x expected concurrent requests / avg request duration
    socket_connect_timeout=5,
    socket_timeout=5,
    retry_on_timeout=True,
)

# External API rate limiting (using aiohttp for market data)
from aiohttp import ClientSession, TCPConnector

market_data_session = ClientSession(
    connector=TCPConnector(
        limit=50,  # Max concurrent connections to market data provider
        limit_per_host=10,  # Per-provider limit (Bloomberg, Reuters)
        ttl_dns_cache=300,
    ),
    timeout=ClientTimeout(total=10, connect=3),
)

# Implement circuit breaker for external services (using pybreaker):
from pybreaker import CircuitBreaker

market_data_breaker = CircuitBreaker(
    fail_max=5,  # Open circuit after 5 failures
    timeout_duration=60,  # Try again after 60s
)
```

---

### C-8: Tax-Loss Harvesting Without Transaction Cost Modeling

**Location:** Section 3.2 (Recommendation Engine) - "Tax-loss harvesting opportunity identification"

**Issue:**
The design mentions tax-loss harvesting but doesn't address transaction cost trade-offs:
- Selling positions incurs brokerage fees ($5-$10/trade typical)
- Wash sale rule requires 30-day waiting period
- Reinvesting in similar securities requires correlation analysis
- Small tax losses (<$100) may not justify transaction costs

**Impact:**
- **Negative ROI recommendations:** Algorithm recommends selling $500 position with $50 loss, incurring $15 in fees, netting $35 benefit (but user experience may perceive as unnecessary churn)
- **Excessive trading:** Triggering harvesting on every small loss generates high fee drag
- **Wash sale violations:** Without proper tracking, repurchases within 30 days disallow tax deductions

**Recommendation:**
```python
# Transaction cost model for tax-loss harvesting
class TaxLossHarvestingEngine:
    def evaluate_opportunity(self, holding, current_price):
        unrealized_loss = (holding.purchase_price - current_price) * holding.quantity

        # Model all costs
        transaction_costs = self.calculate_transaction_costs(holding)
        tax_benefit = unrealized_loss * holding.account.tax_rate  # e.g., 24% marginal rate
        opportunity_cost = self.calculate_opportunity_cost(holding)  # Expected return if held

        # Net benefit calculation
        net_benefit = tax_benefit - transaction_costs - opportunity_cost

        # Threshold: Only recommend if net benefit > $100 AND > 10% of position value
        if net_benefit > 100 and net_benefit / holding.current_value > 0.10:
            return {
                "action": "harvest",
                "net_benefit": net_benefit,
                "replacement_securities": self.find_similar_securities(holding.asset_symbol),
                "wash_sale_clear_date": holding.last_trade_date + timedelta(days=30)
            }

        return None

    def calculate_transaction_costs(self, holding):
        brokerage_fee = 7.99  # Per-trade fee
        sec_fee = holding.current_value * 0.0000221  # SEC regulatory fee for sales
        spread_cost = holding.quantity * (self.get_bid_ask_spread(holding.asset_symbol) / 2)

        # Round-trip cost (sell + buy replacement)
        return 2 * (brokerage_fee + sec_fee + spread_cost)
```

---

## Significant Issues

### S-1: Historical Price Data Growth Without Archival Strategy (Missing Data Lifecycle Management)

**Location:** Section 4.3 (Market Data) - `historical_prices` table

**Issue:**
The `historical_prices` table stores OHLCV data with composite PK `(asset_symbol, date)`. Assuming:
- 5,000 tracked assets
- 10 years of history (regulatory requirement mentioned in context)
- 252 trading days/year
- 60 bytes/row (rough estimate)

Current data volume: 5,000 × 10 × 252 × 60 bytes = 756 MB (manageable)
Growth rate: 5,000 × 252 × 60 bytes/year = 75.6 MB/year

However, if expanding to minute-level data for backtesting (common requirement):
- 5,000 × 252 × 390 minutes × 60 bytes = 28.8 GB/year
- After 10 years: 288 GB in single table

**Impact:**
- **Query performance degradation:** Full table scans become expensive as data grows
- **Backup duration:** Daily backups take hours instead of minutes
- **Index bloat:** B-tree indexes grow proportionally, slowing inserts and updates
- **Storage costs:** Premium SSD storage pricing for rarely-accessed historical data

**Recommendation:**
```sql
-- Implement time-based partitioning (PostgreSQL 12+)
CREATE TABLE historical_prices (
    asset_symbol VARCHAR(20),
    date DATE,
    open DECIMAL(10, 2),
    high DECIMAL(10, 2),
    low DECIMAL(10, 2),
    close DECIMAL(10, 2),
    volume BIGINT
) PARTITION BY RANGE (date);

-- Create partitions (automate with pg_partman extension)
CREATE TABLE historical_prices_2024 PARTITION OF historical_prices
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE historical_prices_2023 PARTITION OF historical_prices
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

-- Archival strategy
1. Hot tier (last 2 years): PostgreSQL primary database (fast queries)
2. Warm tier (2-5 years): Read-replica or separate RDS instance
3. Cold tier (5-10 years): S3 Glacier with on-demand restore (compliance retention)

-- Automate archival with scheduled job:
-- Move partitions older than 2 years to separate RDS instance
-- Export partitions older than 5 years to Parquet files in S3
-- Implement query router: Check date range, fetch from appropriate tier

-- Consider InfluxDB for time-series optimization:
-- The design already includes InfluxDB—migrate historical_prices there
-- InfluxDB provides automatic downsampling (1-min → 1-hour → 1-day aggregates)
-- Better compression (10x typical) and query performance for time-series analytics
```

---

### S-2: Current Portfolio Value Calculation Without Caching (Frequent Computation)

**Location:** Section 4.2 (Holdings) - `current_value` field in `holdings` table

**Issue:**
The schema stores `current_value` as a database column, but the API endpoint `GET /api/v1/portfolios/{account_id}/holdings` returns "real-time values." This implies:

**Option A (anti-pattern):** Recompute on every query
```python
for holding in holdings:
    holding.current_value = holding.quantity * get_latest_price(holding.asset_symbol)
```
This causes N+1 queries and repeated computation for the same portfolio accessed by multiple concurrent requests.

**Option B (stale data):** Use stored `current_value`, which becomes outdated as prices change throughout the trading day.

**Impact:**
- **Redundant computation:** Same portfolio viewed 100 times/hour performs identical calculations
- **Database write amplification:** Updating `current_value` on every price tick for all holdings (millions of writes/sec)
- **Inconsistent user experience:** Two users viewing same portfolio see different values due to race conditions

**Recommendation:**
```python
# Implement multi-tier caching strategy

# Tier 1: Redis cache for portfolio valuations (TTL: 60 seconds)
def get_portfolio_holdings(account_id):
    cache_key = f"portfolio:holdings:{account_id}"
    cached = redis.get(cache_key)

    if cached:
        return json.loads(cached)

    # Fetch holdings from database
    holdings = Holdings.objects.filter(account_id=account_id).values()

    # Batch fetch current prices (avoid N+1)
    symbols = [h['asset_symbol'] for h in holdings]
    prices = get_latest_prices_batch(symbols)  # Single query or Redis lookup

    # Compute valuations
    for holding in holdings:
        holding['current_value'] = holding['quantity'] * prices[holding['asset_symbol']]
        holding['unrealized_pnl'] = holding['current_value'] - (holding['quantity'] * holding['purchase_price'])

    # Cache for 60 seconds
    redis.setex(cache_key, 60, json.dumps(holdings, default=str))

    return holdings

# Tier 2: Price cache (TTL: 1 second, updated by market data service)
def get_latest_prices_batch(symbols):
    pipe = redis.pipeline()
    for symbol in symbols:
        pipe.get(f"price:{symbol}")
    prices = pipe.execute()

    # Build symbol → price map
    return {symbol: float(price) if price else fetch_from_db(symbol)
            for symbol, price in zip(symbols, prices)}

# Tier 3: Remove current_value from database schema
# It's a derived field—don't store it, always compute from (quantity × price)
ALTER TABLE holdings DROP COLUMN current_value;

# Optimization: Pre-compute portfolio snapshots for dashboard (background job)
# Run every 5 minutes during market hours, cache results for 5 minutes
# This amortizes computation cost across all users viewing dashboard
```

---

### S-3: Rebalancing Threshold Evaluation Without Efficient Index

**Location:** Section 4.2 (Portfolio Targets) and Section 3.2 (Portfolio Engine)

**Issue:**
The `portfolio_targets` table stores `rebalance_threshold` (e.g., 5% deviation triggers rebalancing). The nightly rebalancing job must:
1. For each account, compute current asset allocation percentages
2. Compare against target percentages
3. Identify accounts exceeding threshold

The document mentions "Processes rebalancing requests from scheduled jobs" but doesn't specify the query strategy.

**Inefficient query pattern (O(N × M) where N=accounts, M=holdings/account):**
```python
for account in accounts:
    holdings = Holdings.objects.filter(account_id=account.id)
    targets = PortfolioTargets.objects.filter(account_id=account.id)
    current_allocation = calculate_allocation(holdings)
    if needs_rebalancing(current_allocation, targets):
        trigger_rebalancing(account)
```

This requires loading all holdings for all accounts into memory (100K accounts × 20 holdings = 2M rows).

**Impact:**
- **Batch job duration:** 2M row scans may take 30-60 minutes
- **Memory pressure:** Loading all holdings into application memory
- **Database load:** Long-running transactions during batch processing

**Recommendation:**
```sql
-- Strategy 1: Materialized view for current allocations (refresh every 5 minutes)
CREATE MATERIALIZED VIEW portfolio_allocations AS
SELECT
    h.account_id,
    h.asset_symbol,
    SUM(h.quantity * mp.price) as current_value,
    SUM(h.quantity * mp.price) / SUM(SUM(h.quantity * mp.price)) OVER (PARTITION BY h.account_id) as current_percentage
FROM holdings h
JOIN LATERAL (
    SELECT price
    FROM market_prices
    WHERE asset_symbol = h.asset_symbol
    ORDER BY timestamp DESC
    LIMIT 1
) mp ON true
GROUP BY h.account_id, h.asset_symbol;

CREATE INDEX idx_portfolio_allocations_account ON portfolio_allocations(account_id);

-- Strategy 2: Push-down computation to database (single query for all accounts)
WITH current_allocations AS (
    SELECT account_id, asset_symbol, current_percentage
    FROM portfolio_allocations
),
threshold_breaches AS (
    SELECT
        ca.account_id,
        COUNT(*) as breached_targets
    FROM current_allocations ca
    JOIN portfolio_targets pt ON ca.account_id = pt.account_id
        AND ca.asset_symbol = pt.asset_symbol
    WHERE ABS(ca.current_percentage - pt.target_percentage) > pt.rebalance_threshold
    GROUP BY ca.account_id
)
SELECT account_id
FROM threshold_breaches
WHERE breached_targets > 0;

-- Strategy 3: Event-driven incremental evaluation
-- Instead of nightly batch, evaluate on each price update:
-- 1. Price changes → Update materialized view incrementally
-- 2. Detect threshold breach → Publish event to RabbitMQ
-- 3. Worker consumes events → Trigger rebalancing for specific accounts
-- This distributes computation throughout the day instead of 4-hour batch window
```

---

### S-4: Market Data Provider Integration Without Circuit Breaker Details

**Location:** Section 6.1 (Error Handling) - "Circuit breaker pattern for external service calls"

**Issue:**
The document mentions circuit breaker pattern but lacks implementation specifics:
- No failure threshold definition (how many failures trigger circuit open?)
- No timeout configuration (how long before attempting recovery?)
- No fallback strategy (what happens when Bloomberg API is down?)

**Impact:**
- **Cascading failures:** If Bloomberg API degrades (500ms → 30s response time), all market data requests hang
- **Thread pool exhaustion:** Hanging requests tie up worker threads, blocking other operations
- **User-visible errors:** Portfolio valuations fail during market data provider outages
- **No graceful degradation:** System becomes unusable when external dependency fails

**Recommendation:**
```python
# Implement circuit breaker with fallback strategy (using pybreaker + Redis for distributed state)

from pybreaker import CircuitBreaker
import redis

redis_client = redis.Redis(host='cache.example.com', decode_responses=True)

class MarketDataCircuitBreaker:
    def __init__(self, provider_name):
        self.provider = provider_name
        self.breaker = CircuitBreaker(
            fail_max=10,  # Open circuit after 10 consecutive failures
            timeout_duration=60,  # Half-open after 60 seconds
            expected_exception=MarketDataException,
            listeners=[self.on_state_change],
            state_storage=RedisStorage(redis_client, f"circuit:{provider_name}")
        )

    @self.breaker
    def fetch_price(self, symbol):
        # Primary: Bloomberg API
        response = requests.get(
            f"{BLOOMBERG_API}/prices/{symbol}",
            timeout=5  # Fail fast
        )
        response.raise_for_status()
        return response.json()['price']

    def fetch_price_with_fallback(self, symbol):
        try:
            return self.fetch_price(symbol)
        except CircuitBreakerError:
            # Circuit open—use fallback strategy
            return self.fallback_price_fetch(symbol)

    def fallback_price_fetch(self, symbol):
        # Fallback tier 1: Secondary provider (Reuters)
        try:
            return secondary_provider.fetch_price(symbol, timeout=5)
        except:
            # Fallback tier 2: Last known price from cache (with staleness warning)
            cached_price = redis_client.get(f"price:last_known:{symbol}")
            if cached_price:
                logger.warning(f"Using stale price for {symbol}")
                return {
                    "price": float(cached_price),
                    "stale": True,
                    "timestamp": redis_client.get(f"price:timestamp:{symbol}")
                }
            # Fallback tier 3: Fail gracefully with error message
            raise MarketDataUnavailableError(f"All providers unavailable for {symbol}")

    def on_state_change(self, breaker, old_state, new_state):
        if new_state == 'open':
            # Alert: Circuit opened, provider failing
            alert_ops_team(f"Market data provider {self.provider} circuit OPEN")
        elif new_state == 'half_open':
            logger.info(f"Attempting recovery for {self.provider}")

# Monitoring and alerting
# - Emit circuit state metrics to CloudWatch
# - Alert when circuit opens (PagerDuty notification)
# - Dashboard showing: request success rate, latency p99, circuit state, fallback usage %
```

---

### S-5: User-Generated Content Storage Without Search Performance Optimization

**Location:** Section 2.2 (Database) - "MongoDB for user-generated content (notes, strategies)"

**Issue:**
The design specifies MongoDB for user notes and investment strategies, and Elasticsearch for search, but lacks integration details:
- How is data synchronized between MongoDB and Elasticsearch?
- What is the indexing latency?
- How are search queries routed?

The social investment community feature (Section 1.2 - "follow expert strategies") implies:
- Full-text search on strategy descriptions
- Filtering by performance metrics, risk profile, asset classes
- Sorting by popularity, returns, recency

Without proper index design, searches over millions of strategies become slow.

**Impact:**
- **Search latency:** Full collection scans in MongoDB can take seconds for complex queries
- **Stale search results:** If Elasticsearch sync is async, users may not find newly published strategies
- **Resource contention:** Heavy search queries compete with write operations in MongoDB

**Recommendation:**
```javascript
// Strategy 1: Change Data Capture (CDC) pipeline for real-time indexing
// Use MongoDB Change Streams → RabbitMQ → Elasticsearch indexer service

// MongoDB schema with search-optimized fields
{
  "_id": ObjectId("..."),
  "strategy_name": "Dividend Growth Portfolio",
  "author_id": "uuid",
  "description": "Long-term dividend aristocrats with 5%+ yield",
  "asset_classes": ["stocks", "reits"],
  "risk_profile": "conservative",
  "performance": {
    "ytd_return": 0.12,
    "sharpe_ratio": 1.5,
    "max_drawdown": 0.08
  },
  "followers": 1250,
  "created_at": ISODate("2024-01-15"),
  "updated_at": ISODate("2024-02-10"),
  "tags": ["dividend", "income", "defensive"],
  "visibility": "public"
}

// Elasticsearch mapping with performance optimizations
PUT /investment_strategies
{
  "mappings": {
    "properties": {
      "strategy_name": { "type": "text", "analyzer": "english" },
      "description": { "type": "text", "analyzer": "english" },
      "asset_classes": { "type": "keyword" },  // Exact match for filtering
      "risk_profile": { "type": "keyword" },
      "performance.ytd_return": { "type": "float" },
      "performance.sharpe_ratio": { "type": "float" },
      "followers": { "type": "integer" },
      "created_at": { "type": "date" },
      "tags": { "type": "keyword" }
    }
  },
  "settings": {
    "number_of_shards": 3,  // Distribute load across shards
    "number_of_replicas": 1,
    "refresh_interval": "5s"  // Balance freshness vs. indexing overhead
  }
}

// Query example with filters and sorting
GET /investment_strategies/_search
{
  "query": {
    "bool": {
      "must": [
        { "match": { "description": "dividend income" } }
      ],
      "filter": [
        { "terms": { "asset_classes": ["stocks", "bonds"] } },
        { "term": { "risk_profile": "conservative" } },
        { "range": { "performance.ytd_return": { "gte": 0.08 } } }
      ]
    }
  },
  "sort": [
    { "followers": { "order": "desc" } },
    { "_score": { "order": "desc" } }
  ],
  "from": 0,
  "size": 20
}

// Monitoring: Track sync lag between MongoDB and Elasticsearch
// - Emit metric: time between MongoDB insert and Elasticsearch index
// - Alert if lag > 10 seconds (indicates indexing bottleneck)
```

---

### S-6: Multi-Currency Support Without Exchange Rate Caching

**Location:** Section 1.2 (Key Features) - "Multi-currency support for international investments"

**Issue:**
The document mentions multi-currency support and the schema includes `currency` field in `user_accounts` table, but lacks:
- Exchange rate data model
- Rate update frequency specification
- Currency conversion caching strategy

Typical usage pattern: User with USD account views portfolio containing EUR, GBP, JPY holdings. Each view requires:
1. Fetch holdings (multiple currencies)
2. Fetch exchange rates for each currency
3. Convert to user's base currency (USD)
4. Sum total portfolio value

**Impact:**
- **Redundant API calls:** Fetching same exchange rates (e.g., EUR/USD) for every user request
- **External API rate limits:** Currency data providers often have strict rate limits (e.g., 1000 requests/hour for free tiers)
- **Latency addition:** 50-200ms per exchange rate lookup

**Recommendation:**
```python
# Exchange rate data model (add to schema)
CREATE TABLE exchange_rates (
    rate_id UUID PRIMARY KEY,
    base_currency VARCHAR(3),
    quote_currency VARCHAR(3),
    rate DECIMAL(12, 6),
    timestamp TIMESTAMP,
    source VARCHAR(50),
    UNIQUE(base_currency, quote_currency, timestamp)
);

CREATE INDEX idx_exchange_rates_pair_time ON exchange_rates(base_currency, quote_currency, timestamp DESC);

# Caching strategy (multi-tier)
class CurrencyConverter:
    def __init__(self):
        self.redis = redis.Redis()

    def get_exchange_rate(self, base, quote):
        # Tier 1: Redis cache (TTL: 5 minutes for most pairs, 1 minute during high volatility)
        cache_key = f"fx:{base}:{quote}"
        cached_rate = self.redis.get(cache_key)

        if cached_rate:
            return float(cached_rate)

        # Tier 2: Database (recent rates from last 24 hours)
        rate = ExchangeRate.objects.filter(
            base_currency=base,
            quote_currency=quote,
            timestamp__gte=datetime.now() - timedelta(hours=24)
        ).order_by('-timestamp').first()

        if rate and self.is_rate_fresh(rate.timestamp):
            # Cache for 5 minutes
            self.redis.setex(cache_key, 300, str(rate.rate))
            return rate.rate

        # Tier 3: Fetch from external API (with rate limiting)
        return self.fetch_and_cache_rate(base, quote)

    def fetch_and_cache_rate(self, base, quote):
        # Rate limiting: Use token bucket algorithm
        if not self.can_call_external_api():
            # Use stale rate with warning
            stale_rate = self.get_stale_rate(base, quote)
            logger.warning(f"Using stale FX rate {base}/{quote}: {stale_rate}")
            return stale_rate

        # Fetch from external provider (e.g., OpenExchangeRates API)
        rate = external_api.get_rate(base, quote)

        # Store in database
        ExchangeRate.objects.create(
            base_currency=base,
            quote_currency=quote,
            rate=rate,
            timestamp=datetime.now(),
            source='openexchangerates'
        )

        # Cache in Redis
        self.redis.setex(f"fx:{base}:{quote}", 300, str(rate))

        return rate

    def convert_portfolio_value(self, holdings, user_base_currency):
        # Batch fetch all required exchange rates
        required_pairs = set((h.currency, user_base_currency) for h in holdings)
        rates = {pair: self.get_exchange_rate(*pair) for pair in required_pairs}

        # Single pass conversion
        total_value = sum(
            h.value * rates.get((h.currency, user_base_currency), 1.0)
            for h in holdings
        )

        return total_value

# Background job: Pre-warm cache for popular currency pairs
# Run every 4 minutes (before 5-minute TTL expires)
# Popular pairs: USD/EUR, USD/GBP, USD/JPY, USD/CNY (covers 80% of users)
def prewarm_fx_cache():
    popular_pairs = [('USD', 'EUR'), ('USD', 'GBP'), ('USD', 'JPY'), ('USD', 'CNY')]
    for base, quote in popular_pairs:
        converter.fetch_and_cache_rate(base, quote)
```

---

## Moderate Issues

### M-1: Missing Query Timeout Configuration

**Location:** Infrastructure (Section 2.3) - PostgreSQL configuration

**Issue:**
No statement timeout specified. Runaway queries (e.g., missing WHERE clause, inefficient joins) can run indefinitely, consuming database resources.

**Recommendation:**
```sql
-- Set statement timeout at database level
ALTER DATABASE investment_platform SET statement_timeout = '30s';

-- For long-running analytics queries, set session-level timeout
SET statement_timeout = '5min';

-- Application-level timeout (Django ORM)
from django.db import connection
connection.cursor().execute("SET statement_timeout = '30s'")
```

---

### M-2: Authentication Session Management Without TTL Strategy

**Location:** Section 5.4 (Authentication) - "Session management with Redis"

**Issue:**
No session expiration policy specified. Indefinite sessions increase:
- Memory usage in Redis (millions of active sessions)
- Security risk (stolen tokens remain valid indefinitely)

**Recommendation:**
```python
# Implement sliding session expiration
SESSION_COOKIE_AGE = 3600 * 24 * 30  # 30 days
SESSION_SAVE_EVERY_REQUEST = True  # Extend TTL on each request

# JWT token expiration
JWT_ACCESS_TOKEN_LIFETIME = timedelta(minutes=15)  # Short-lived access tokens
JWT_REFRESH_TOKEN_LIFETIME = timedelta(days=30)  # Long-lived refresh tokens

# Redis session storage with TTL
redis_client.setex(
    f"session:{session_id}",
    SESSION_COOKIE_AGE,
    session_data
)
```

---

### M-3: WebSocket Connection Scaling Without Connection Limit

**Location:** Section 3.2 (Market Data Service) - Real-time price streaming

**Issue:**
No max connection limit specified. Under DDoS or bot attacks, unlimited WebSocket connections can exhaust server resources.

**Recommendation:**
```javascript
// Implement connection limits per IP and globally
const WebSocket = require('ws');

const wss = new WebSocket.Server({
  port: 8080,
  perMessageDeflate: true,  // Compression to reduce bandwidth
  clientTracking: true,
  maxPayload: 100 * 1024,  // 100KB max message size
});

// Global limit: 100,000 concurrent connections
// Per-IP limit: 50 connections (mitigate abuse)
const connections = new Map();

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  const ipConnections = connections.get(ip) || 0;

  if (ipConnections >= 50) {
    ws.close(1008, 'Too many connections from IP');
    return;
  }

  if (wss.clients.size >= 100000) {
    ws.close(1008, 'Server at capacity');
    return;
  }

  connections.set(ip, ipConnections + 1);

  ws.on('close', () => {
    connections.set(ip, connections.get(ip) - 1);
  });
});
```

---

### M-4: Notification Service Without Delivery Queue Management

**Location:** Section 3.1 (Architecture) - Notification Service

**Issue:**
The architecture includes a Notification Service but lacks details on:
- Delivery queue persistence (what if service crashes?)
- Retry strategy for failed deliveries
- Dead letter queue for permanently failed notifications

**Impact:**
- **Lost notifications:** Service restart during processing loses in-memory queue
- **Duplicate notifications:** Retry without idempotency key sends duplicates
- **User experience:** Critical alerts (portfolio rebalance complete, transaction executed) not delivered

**Recommendation:**
```python
# Use RabbitMQ (already in tech stack) for notification queue
import pika

# Durable queue with persistent messages
channel.queue_declare(queue='notifications', durable=True)

channel.basic_publish(
    exchange='',
    routing_key='notifications',
    body=json.dumps(notification),
    properties=pika.BasicProperties(
        delivery_mode=2,  # Persistent message
        message_id=notification_id,  # Idempotency
    )
)

# Consumer with retry and DLQ
def process_notification(ch, method, properties, body):
    try:
        send_notification(json.loads(body))
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        # Retry with exponential backoff (max 3 attempts)
        retry_count = properties.headers.get('x-retry-count', 0)
        if retry_count < 3:
            ch.basic_publish(
                exchange='',
                routing_key='notifications',
                body=body,
                properties=pika.BasicProperties(
                    headers={'x-retry-count': retry_count + 1},
                    delivery_mode=2
                )
            )
            ch.basic_ack(delivery_tag=method.delivery_tag)
        else:
            # Move to dead letter queue for manual review
            ch.basic_publish(
                exchange='',
                routing_key='notifications_dlq',
                body=body,
                properties=pika.BasicProperties(delivery_mode=2)
            )
            ch.basic_ack(delivery_tag=method.delivery_tag)
            logger.error(f"Notification permanently failed: {properties.message_id}")
```

---

### M-5: Monitoring and Alerting Without Performance Metrics

**Location:** Section 6.2 (Logging) - mentions CloudWatch but no performance monitoring

**Issue:**
Logging infrastructure exists but no mention of:
- Application performance monitoring (APM)
- Query performance tracking
- Latency percentile tracking (p50, p95, p99)

**Recommendation:**
```python
# Integrate APM solution (e.g., DataDog, New Relic, or AWS X-Ray)
from ddtrace import tracer

@tracer.wrap(service='portfolio-engine', resource='calculate_rebalancing')
def calculate_rebalancing(account_id):
    # Automatically tracks execution time, errors, throughput
    pass

# Custom metrics for business-critical operations
import statsd
metrics = statsd.StatsClient('localhost', 8125)

def get_portfolio_holdings(account_id):
    with metrics.timer('api.portfolios.holdings.duration'):
        holdings = fetch_holdings(account_id)

    metrics.incr('api.portfolios.holdings.requests')
    metrics.gauge('api.portfolios.holdings.count', len(holdings))

    return holdings

# CloudWatch custom metrics
import boto3
cloudwatch = boto3.client('cloudwatch')

cloudwatch.put_metric_data(
    Namespace='InvestmentPlatform',
    MetricData=[
        {
            'MetricName': 'RebalancingDuration',
            'Value': duration_seconds,
            'Unit': 'Seconds',
            'Dimensions': [
                {'Name': 'AccountSize', 'Value': 'large' if holdings > 100 else 'small'}
            ]
        }
    ]
)

# Set up alarms for performance degradation
# - P95 latency > 500ms for 5 consecutive minutes → Alert
# - Error rate > 1% → Alert
# - Database connection pool usage > 80% → Warning
```

---

## Positive Aspects

The design demonstrates several performance-aware architectural decisions:

1. **Appropriate database selection:** PostgreSQL for transactional data, InfluxDB for time-series, MongoDB for documents—each database chosen for its strengths
2. **Caching layer:** Redis included for session management and caching (though implementation details need enhancement)
3. **Message queue:** RabbitMQ for asynchronous processing enables decoupling and load smoothing
4. **Horizontal scaling:** Microservices architecture with stateless services supports scaling
5. **Read replicas:** Database read replicas mentioned for query load distribution
6. **Event-driven patterns:** Acknowledgment of async processing needs (though rebalancing API needs improvement)
7. **CDN usage:** CloudFront for static asset delivery reduces latency for global users

---

## Summary and Prioritization

**Immediate Action Required (Critical):**
1. Add database indexes for all foreign keys and high-frequency query patterns
2. Implement pagination for all list endpoints
3. Define performance SLAs and query performance budgets
4. Refactor rebalancing API to async processing pattern
5. Fix N+1 query pattern in portfolio holdings retrieval
6. Configure connection pools for all database and external service connections

**High Priority (Significant):**
1. Implement data archival strategy for historical prices
2. Add caching for portfolio value calculations
3. Design circuit breaker with fallback for market data providers
4. Optimize rebalancing threshold evaluation with materialized views
5. Cache exchange rates for multi-currency support

**Medium Priority (Moderate):**
1. Set statement timeouts for database queries
2. Implement session TTL strategy
3. Add WebSocket connection limits
4. Configure notification queue with DLQ
5. Set up performance monitoring and alerting

The architecture shows solid foundational choices but requires detailed performance engineering in data access patterns, caching strategies, and operational specifications to meet the demands of a production FinTech platform handling thousands of concurrent users and millions of financial transactions.
