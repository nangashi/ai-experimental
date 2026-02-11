# Performance Design Review: FinTech Investment Advisory Platform

## Review Metadata
- **Reviewer**: performance-design-reviewer (v008-variant-nfr-concurrency)
- **Review Date**: 2026-02-11
- **Document**: test-document-round-008.md

---

## Executive Summary

This design exhibits **critical concurrency control gaps** in transaction execution and rebalancing workflows that could lead to data corruption and financial errors under concurrent access. Additionally, the system lacks explicit NFR specifications for latency/throughput and demonstrates several architectural antipatterns that pose significant scalability risks for a FinTech platform handling real-time market data and automated trading.

**Severity Distribution:**
- **Critical Issues**: 3 (concurrency control, race conditions, portfolio consistency)
- **Significant Issues**: 5 (NFR gaps, N+1 queries, missing indexes, synchronous I/O, missing timeouts)
- **Moderate Issues**: 4 (caching strategy, unbounded queries, monitoring gaps, connection pooling)

---

## Critical Issues

### C1. Missing Concurrency Control for Transaction Execution

**Issue**: The `transactions` table and API design (`POST /api/v1/portfolios/{account_id}/rebalance`) lack any concurrency control mechanism to prevent race conditions when multiple clients or automated processes attempt to execute trades on the same account simultaneously.

**Impact**:
- **Double execution risk**: Rebalancing triggered by both automated jobs and manual user actions could result in duplicate trades, causing portfolio drift and financial losses
- **Inventory conflicts**: Concurrent sell orders could attempt to sell more shares than available (e.g., two parallel processes both check balance shows 100 shares, both sell 80 shares → oversell)
- **Account balance corruption**: Parallel updates to `user_accounts.balance` without locking will result in lost writes (classic read-modify-write race condition)

**Evidence**:
- Transactions table (lines 147-159) has `status` field but no version column, lock timestamp, or idempotency key
- Section 3.2 Portfolio Engine describes "Processes rebalancing requests from scheduled jobs" (line 61) but provides no synchronization mechanism
- No mention of optimistic/pessimistic locking strategy in any section

**Recommendation**:
```sql
-- Add optimistic locking with version column
ALTER TABLE transactions ADD COLUMN version INT DEFAULT 1;
ALTER TABLE user_accounts ADD COLUMN version INT DEFAULT 1;

-- Add idempotency key for duplicate request detection
ALTER TABLE transactions ADD COLUMN idempotency_key VARCHAR(64) UNIQUE;

-- Add distributed lock tracking
CREATE TABLE rebalance_locks (
    account_id UUID PRIMARY KEY,
    locked_at TIMESTAMP,
    lock_holder VARCHAR(100),
    expires_at TIMESTAMP
);
```

Implement distributed locking (Redis SETNX or PostgreSQL advisory locks) before rebalancing operations:
```python
def rebalance_portfolio(account_id: UUID, idempotency_key: str):
    # Acquire distributed lock with 30-second timeout
    with RedisLock(f"rebalance:{account_id}", timeout=30):
        # Check idempotency
        if Transaction.objects.filter(idempotency_key=idempotency_key).exists():
            return  # Already processed

        # Execute rebalancing with transaction isolation
        with transaction.atomic():
            account = UserAccount.objects.select_for_update().get(id=account_id)
            # ... rebalancing logic with optimistic locking checks
```

---

### C2. Race Conditions in Holdings Updates During Market Data Refresh

**Issue**: The `holdings.current_value` field (line 111) is updated based on market price changes, but there's no mechanism to prevent concurrent modification conflicts when market data updates overlap with rebalancing operations or user-initiated trades.

**Scenario**:
1. Market Data Service updates `holdings.current_value` for all positions at 10:00:00.000
2. Rebalancing job reads `holdings` at 10:00:00.050 to calculate drift
3. User executes manual trade at 10:00:00.100, modifying `holdings.quantity`
4. Rebalancing job commits trade orders at 10:00:00.200 based on stale holdings snapshot
5. **Result**: Trade orders based on incorrect portfolio state, causing over/under-trading

**Impact**:
- **Portfolio drift**: Rebalancing calculations using stale data result in incorrect target allocations
- **Regulatory risk**: Inaccurate portfolio reporting due to lost updates violates fiduciary duty standards
- **Financial loss**: Cascading errors from inconsistent state could trigger stop-loss orders or liquidations

**Evidence**:
- No transaction isolation level specified in Section 2.2 (PostgreSQL default READ COMMITTED allows non-repeatable reads)
- Market Data Service (3.2) "Updates stock prices" without coordination with Portfolio Engine
- GET `/api/v1/portfolios/{account_id}/holdings` (line 167) likely performs multiple queries without snapshot isolation

**Recommendation**:
- **Implement MVCC snapshot isolation for portfolio read operations:**
```python
# Use REPEATABLE READ isolation for portfolio calculations
with transaction.atomic(isolation_level='REPEATABLE READ'):
    holdings = Holdings.objects.filter(account_id=account_id).select_for_update()
    targets = PortfolioTargets.objects.filter(account_id=account_id)
    # Calculate rebalancing trades with consistent snapshot
```

- **Add event sourcing for holdings changes:**
```sql
CREATE TABLE holdings_events (
    event_id BIGSERIAL PRIMARY KEY,
    holding_id UUID,
    event_type VARCHAR(20), -- 'trade', 'price_update', 'split', 'dividend'
    quantity_delta DECIMAL(15, 6),
    price DECIMAL(10, 2),
    timestamp TIMESTAMP,
    causation_id UUID -- links related events
);
```

- **Implement read-your-writes consistency**: After trade execution, return holdings snapshot from the same transaction context to avoid showing stale data to users.

---

### C3. No Atomic Portfolio Target Updates with Rebalancing

**Issue**: The `portfolio_targets` table (lines 115-121) can be modified independently of rebalancing operations, creating temporal inconsistency where a rebalancing job executes against old targets while the user is updating their allocation preferences.

**Impact**:
- **Conflicting trades**: User changes target from 60% stocks/40% bonds to 40% stocks/60% bonds, but rebalancing job already in-flight executes opposite trades
- **Regulatory compliance violation**: Cannot prove which allocation strategy was in effect for audit trails
- **User trust erosion**: Platform executes trades that contradict user's current preferences

**Evidence**:
- No version linkage between `portfolio_targets` and `transactions` tables
- PUT `/api/v1/users/{user_id}/profile` (line 199) allows risk tolerance changes without coordinating with rebalancing
- Section 3.2 Portfolio Engine processes "scheduled jobs" but doesn't describe coordination with user updates

**Recommendation**:
```sql
-- Add versioning to portfolio targets
ALTER TABLE portfolio_targets ADD COLUMN effective_from TIMESTAMP DEFAULT NOW();
ALTER TABLE portfolio_targets ADD COLUMN effective_until TIMESTAMP;

-- Link transactions to target version
ALTER TABLE transactions ADD COLUMN target_version_id UUID REFERENCES portfolio_targets(target_id);

-- Create target change log
CREATE TABLE target_change_log (
    change_id UUID PRIMARY KEY,
    account_id UUID,
    old_targets JSONB,
    new_targets JSONB,
    applied_at TIMESTAMP,
    applied_by VARCHAR(100) -- 'user' or 'system'
);
```

Implement optimistic locking for coordinated updates:
```python
def update_portfolio_targets(account_id: UUID, new_targets: dict):
    with transaction.atomic():
        # Lock account to prevent concurrent rebalancing
        account = UserAccount.objects.select_for_update(nowait=True).get(id=account_id)

        # Check for in-flight rebalancing
        if RebalanceLock.objects.filter(account_id=account_id, expires_at__gt=now()).exists():
            raise ConflictException("Rebalancing in progress, try again in 30 seconds")

        # Archive old targets and create new version
        old_targets = PortfolioTargets.objects.filter(account_id=account_id)
        old_targets.update(effective_until=now())
        # ... create new target records
```

---

## Significant Issues

### S1. Missing Performance NFRs (SLA, Latency Targets, Throughput)

**Issue**: Section 7.3 defines 99.9% uptime but provides **no quantitative specifications** for latency, throughput, or query performance despite real-time market data requirements and automated trading use cases.

**Impact**:
- **Cannot validate design adequacy**: No basis to assess if caching strategy, index design, or async processing are sufficient
- **Production blind spots**: No SLA to guide monitoring, alerting, or capacity planning
- **Competitive disadvantage**: Slow portfolio valuations or delayed trade execution erode user trust in FinTech applications

**Critical Missing Metrics**:
- Portfolio holdings API (`GET /api/v1/portfolios/{account_id}/holdings`) - No p99 latency target despite need for real-time valuation display
- Rebalancing execution time - No upper bound despite scheduled job constraints
- Market data ingestion lag - No specification despite "real-time price streaming" claim (line 69)
- Concurrent user capacity - No throughput target (critical for "social investment community" feature)

**Recommendation**:
Define explicit NFRs:
```yaml
Performance SLAs:
  API Response Times (p99):
    - GET /portfolios/{id}/holdings: <200ms
    - POST /portfolios/{id}/rebalance: <3s (calculation only, async execution)
    - GET /market/prices/{symbol}: <50ms (cached)
    - WS /market/stream: <100ms end-to-end latency

  Throughput:
    - Concurrent users: 50,000 active WebSocket connections
    - API requests: 10,000 req/s peak (market hours)
    - Market data ingestion: 100,000 price updates/s

  Batch Operations:
    - Nightly rebalancing: Process 100,000 accounts in <2 hours
    - Tax-loss harvesting scan: Complete for all users in <30 minutes
```

---

### S2. N+1 Query Problem in Portfolio Holdings Valuation

**Issue**: The GET `/api/v1/portfolios/{account_id}/holdings` endpoint (line 166) returns "real-time values" which requires joining each holding with current market prices. The typical implementation would query holdings first, then iterate through each `asset_symbol` to fetch current prices.

**Impact**:
- **Latency explosion**: Portfolio with 50 holdings requires 51 queries (1 holdings query + 50 price lookups) → ~500ms latency instead of <50ms
- **Database overload**: Peak market hours with 10,000 concurrent users = 500,000 queries/s instead of 20,000 queries/s
- **Poor user experience**: Delayed portfolio updates during high volatility when users need real-time data most

**Evidence**:
- Data model shows separate `holdings` (lines 103-113) and `market_prices` (lines 125-132) tables with no denormalization or materialized view
- Section 3.2 Market Data Service describes updates but no mention of batch query optimization
- No caching strategy defined for frequently accessed price data

**Recommendation**:
```python
# BAD: N+1 query pattern
def get_holdings_with_values(account_id):
    holdings = Holdings.objects.filter(account_id=account_id)
    for holding in holdings:
        current_price = MarketPrices.objects.get(asset_symbol=holding.asset_symbol)  # N queries
        holding.current_value = holding.quantity * current_price.price

# GOOD: Single batch query
def get_holdings_with_values(account_id):
    holdings = Holdings.objects.filter(account_id=account_id).select_related()
    symbols = [h.asset_symbol for h in holdings]

    # Single query with IN clause
    prices = MarketPrices.objects.filter(asset_symbol__in=symbols).in_bulk(field_name='asset_symbol')

    for holding in holdings:
        holding.current_value = holding.quantity * prices[holding.asset_symbol].price
```

Additionally, implement Redis caching:
```python
# Cache prices with 1-second TTL for high-frequency access
cache_key = f"price:{asset_symbol}"
price = redis.get(cache_key)
if not price:
    price = fetch_from_db(asset_symbol)
    redis.setex(cache_key, 1, price)  # 1-second cache
```

---

### S3. Missing Database Indexes on Critical Query Paths

**Issue**: The schema definitions (Section 4) lack index specifications for frequently queried columns, particularly foreign keys and time-range queries on `transactions` and `market_prices` tables.

**Impact**:
- **Full table scans**: Query like `SELECT * FROM transactions WHERE account_id = ? AND created_at > ?` without composite index requires scanning entire transactions table
- **Rebalancing delays**: Portfolio Engine queries on `holdings.account_id` and `portfolio_targets.account_id` without indexes cause 10-100x slowdown as user base grows
- **Market data queries**: Historical price queries (`GET /api/v1/market/history/{asset_symbol}?start_date=...`) scan millions of rows without (asset_symbol, date) index

**Missing Indexes**:
```sql
-- Critical foreign key indexes
CREATE INDEX idx_holdings_account_id ON holdings(account_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_portfolio_targets_account_id ON portfolio_targets(account_id);

-- Composite indexes for time-range queries
CREATE INDEX idx_transactions_account_status_created ON transactions(account_id, status, created_at DESC);
CREATE INDEX idx_market_prices_symbol_timestamp ON market_prices(asset_symbol, timestamp DESC);

-- Index for rebalancing job queries
CREATE INDEX idx_holdings_account_updated ON holdings(account_id, last_updated);

-- Index for tax-loss harvesting
CREATE INDEX idx_holdings_account_purchase_date ON holdings(account_id, purchase_date)
    WHERE (current_value < purchase_price * quantity);  -- Partial index for losses
```

**Recommendation**:
Add indexes with monitoring:
- Use PostgreSQL `pg_stat_user_tables` to identify sequential scans in production
- Implement query performance testing in CI/CD with realistic data volumes (100K users, 5M holdings)
- Set slow query log threshold to 100ms and alert on violations

---

### S4. Synchronous I/O in High-Throughput Path (Market Data Integration)

**Issue**: Section 3.2 Market Data Service describes integration with external providers (Bloomberg, Reuters) but provides no design for asynchronous processing. Real-time price updates (line 69) likely block request threads while waiting for external API responses.

**Impact**:
- **Throughput bottleneck**: Synchronous HTTP calls to Bloomberg API with 200ms latency limit server to 5 price updates/second per thread (need 100,000 updates/s per NFR recommendation)
- **Thread pool exhaustion**: Django default 50 threads exhausted under load → cascading failures across all API endpoints
- **Cascading latency**: Slow market data provider response (500ms) blocks user-facing portfolio queries, violating SLA

**Evidence**:
- Section 2.1 lists "Real-time services: Node.js with Socket.io" but Section 3.2 describes Django Portfolio Engine accessing market data synchronously
- WebSocket endpoint `WS /api/v1/market/stream` (line 189) requires async event loop, incompatible with Django synchronous views
- No mention of async/await patterns or background workers for I/O-bound operations

**Recommendation**:
Implement async I/O with event-driven architecture:

```python
# Market data ingestion worker (separate from API server)
import asyncio
import aiohttp

async def fetch_prices_async(symbols: list[str]):
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_single_price(session, symbol) for symbol in symbols]
        results = await asyncio.gather(*tasks, return_exceptions=True)
    return results

async def fetch_single_price(session, symbol):
    url = f"https://api.bloomberg.com/prices/{symbol}"
    async with session.get(url, timeout=aiohttp.ClientTimeout(total=5)) as response:
        data = await response.json()
        # Write to Redis pub/sub for real-time streaming
        await redis.publish(f"price:{symbol}", json.dumps(data))
        # Batch write to PostgreSQL
        await price_buffer.add(symbol, data)
```

Architecture changes:
- **Separate ingestion service**: Dedicated async worker pool for market data fetching (RabbitMQ consumer)
- **Push model**: External API pushes to webhook instead of polling (reduce latency from 200ms to <50ms)
- **Read path optimization**: API servers read from Redis/cache only, never block on external I/O

---

### S5. Missing Timeout Configurations for External Service Calls

**Issue**: Section 6.1 mentions circuit breaker for external services (line 216) but provides no timeout specifications for market data provider calls, brokerage API integrations, or OAuth providers.

**Impact**:
- **Indefinite hangs**: Default socket timeout (no timeout) causes threads to wait indefinitely if Bloomberg API becomes unresponsive
- **Resource exhaustion**: Hung connections accumulate, exhausting connection pools and file descriptors
- **User-facing failures**: Lack of fail-fast behavior means users wait 30+ seconds before receiving error responses

**Critical Timeout Requirements**:
- **Market data API calls**: 3-second total timeout (1s connect, 2s read)
- **Brokerage trade execution**: 10-second timeout with retry (critical path)
- **OAuth provider callbacks**: 5-second timeout (non-critical path)
- **Database queries**: 30-second statement timeout for expensive analytics queries

**Recommendation**:
```python
# HTTP client configuration
import httpx

market_data_client = httpx.AsyncClient(
    timeout=httpx.Timeout(
        connect=1.0,  # Socket connect timeout
        read=2.0,     # Time to first byte
        write=1.0,    # Write timeout
        pool=0.5      # Acquiring connection from pool
    ),
    limits=httpx.Limits(
        max_connections=100,
        max_keepalive_connections=20,
        keepalive_expiry=30.0
    )
)

# Database timeout at connection level
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'OPTIONS': {
            'connect_timeout': 5,
            'options': '-c statement_timeout=30000'  # 30s
        }
    }
}

# Circuit breaker configuration (using resilience4j pattern)
@circuit_breaker(
    failure_threshold=5,        # Open after 5 failures
    recovery_timeout=60,        # Try again after 60s
    expected_exception=TimeoutError
)
async def fetch_market_data(symbol: str):
    # ... call with timeout
```

Monitor timeout metrics:
- Track p99 latency for each external dependency
- Alert when timeout rate exceeds 1% of requests
- Implement fallback strategies (stale cache for market data, manual intervention for trades)

---

## Moderate Issues

### M1. Undefined Caching Strategy for Market Data

**Issue**: Redis is specified (Section 2.2, line 36) but no explicit caching policy is defined for market data, which requires high read throughput with acceptable staleness tolerance.

**Impact**:
- **Database overload**: Every portfolio holdings request fetches market prices from PostgreSQL instead of cache
- **Inconsistent performance**: Cache-aside pattern without TTL strategy causes unpredictable latency spikes on cache misses
- **Wasted memory**: No eviction policy defined → Redis OOM kills or evicts random keys

**Recommendation**:
```python
# Market price caching strategy
CACHE_POLICIES = {
    'market_prices': {
        'ttl': 1,  # 1 second for active trading hours
        'ttl_off_hours': 60,  # 1 minute outside market hours
        'eviction': 'allkeys-lru',
        'max_memory': '8GB'
    },
    'historical_prices': {
        'ttl': 3600,  # 1 hour (immutable data)
        'eviction': 'noeviction',  # Historical data never evicted
        'storage': 'InfluxDB'  # Separate time-series DB
    },
    'portfolio_snapshots': {
        'ttl': 5,  # 5 seconds
        'eviction': 'volatile-lru',
        'write_through': True  # Update cache on every trade
    }
}
```

---

### M2. Unbounded Queries Without Pagination

**Issue**: API endpoints like `GET /api/v1/portfolios/{account_id}/holdings` (line 166) and `GET /api/v1/market/history/{asset_symbol}` (line 186) have no pagination parameters or result limits.

**Impact**:
- **Memory exhaustion**: User with 1,000 holdings (possible for institutional accounts) returns 1,000-row result set → 100MB response payload
- **Slow query**: Historical data query without date range limit scans 10 years of daily data (2,500 rows per symbol)
- **DoS vulnerability**: Malicious actor requests history for all symbols → crashes application servers

**Recommendation**:
```python
# Add pagination to all list endpoints
GET /api/v1/portfolios/{account_id}/holdings?limit=100&offset=0
GET /api/v1/market/history/{asset_symbol}?start_date=2024-01-01&end_date=2024-12-31&limit=365

# Enforce default limits
DEFAULT_PAGE_SIZE = 100
MAX_PAGE_SIZE = 1000
MAX_DATE_RANGE_DAYS = 365

# Add database query limits
queryset = Holdings.objects.filter(account_id=account_id)[:MAX_PAGE_SIZE]
```

---

### M3. Missing Performance Monitoring and Alerting Strategy

**Issue**: Section 6.2 describes logging but provides no performance monitoring strategy (metrics collection, SLA violation alerts, anomaly detection).

**Impact**:
- **Invisible degradation**: Gradual performance regression (e.g., slow query creep) undetected until user complaints
- **Blind capacity planning**: No data to forecast when horizontal scaling is needed
- **Incident response delays**: No actionable alerts when rebalancing jobs exceed SLA

**Recommendation**:
```yaml
Key Performance Metrics:
  - API latency (p50, p95, p99) by endpoint
  - Database query time by table and query type
  - Market data ingestion lag (time from provider timestamp to DB write)
  - Rebalancing job duration and success rate
  - Redis cache hit ratio and eviction rate
  - WebSocket connection count and message throughput

Alerting Rules:
  - Critical: Portfolio API p99 > 1s (page oncall)
  - Warning: Rebalancing job duration > 10 minutes (ticket)
  - Info: Cache hit ratio < 80% (investigate)
```

Implement with Prometheus + Grafana:
```python
from prometheus_client import Histogram, Counter

portfolio_latency = Histogram('portfolio_api_latency_seconds', 'Portfolio API latency')
rebalance_failures = Counter('rebalance_failures_total', 'Rebalancing job failures')

@portfolio_latency.time()
def get_holdings(account_id):
    # ... implementation
```

---

### M4. Missing Connection Pooling Configuration Details

**Issue**: Section 2.2 mentions PostgreSQL and Redis but provides no connection pool sizing, timeout, or health check configuration.

**Impact**:
- **Connection exhaustion**: Default Django pool size (1 connection per thread) insufficient for microservices with 50+ workers
- **Leaked connections**: No idle timeout → connections remain open indefinitely after traffic spikes
- **Cascading failures**: Unhealthy database connections not detected by health checks → requests fail silently

**Recommendation**:
```python
# PostgreSQL connection pool (using pgbouncer)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'OPTIONS': {
            'pool': {
                'min_size': 10,
                'max_size': 50,
                'max_queries': 50000,  # Recycle after 50k queries
                'max_idle': 300,       # Close idle connections after 5 min
            },
            'health_checks': True
        }
    }
}

# Redis connection pool
REDIS_POOL = redis.ConnectionPool(
    host='redis.example.com',
    port=6379,
    max_connections=100,
    socket_timeout=1.0,
    socket_connect_timeout=0.5,
    retry_on_timeout=True,
    health_check_interval=30
)
```

---

## Positive Aspects

### P1. Event-Driven Architecture for Asynchronous Processing

The design appropriately uses RabbitMQ (Section 2.3, line 41) for decoupling services, which supports the required asynchronous workflows for rebalancing and notifications.

**Recommendation**: Document explicit message queue design patterns (task queues for rebalancing, pub/sub for market data streaming) to ensure consistency across services.

---

### P2. Separation of Time-Series Data Storage

Using InfluxDB for historical market data (Section 2.2, line 36) is a strong architectural choice that prevents PostgreSQL from being overwhelmed by high-cardinality time-series queries.

**Recommendation**: Define explicit retention policies for InfluxDB (e.g., 1-minute resolution for 7 days, 1-hour resolution for 5 years) and ensure historical queries are routed to InfluxDB rather than PostgreSQL.

---

### P3. Multi-Region Deployment for Disaster Recovery

Section 7.2 (line 243) correctly identifies multi-region deployment as a requirement, which is critical for meeting 99.9% uptime SLA for a financial services platform.

**Recommendation**: Specify active-active vs. active-passive strategy, particularly for handling stateful operations like transaction execution and portfolio locking during regional failover.

---

## Summary and Prioritization

**Critical Blockers** (must fix before production):
1. **C1**: Implement distributed locking and idempotency for transaction execution
2. **C2**: Add snapshot isolation and event sourcing for holdings consistency
3. **C3**: Implement version control and coordination for portfolio target updates

**High-Priority Issues** (significant risk if unaddressed):
1. **S1**: Define quantitative NFRs for latency, throughput, and capacity
2. **S2**: Eliminate N+1 query problem in portfolio valuation API
3. **S3**: Add missing database indexes on all foreign keys and time-range queries
4. **S4**: Implement async I/O for market data integration
5. **S5**: Configure timeouts for all external service calls

**Moderate-Priority Improvements**:
1. **M1**: Define explicit caching policies with TTL and eviction strategies
2. **M2**: Add pagination and result limits to all list endpoints
3. **M3**: Implement performance monitoring and SLA alerting
4. **M4**: Document connection pool configurations

**Overall Assessment**: The architecture demonstrates good high-level design choices (microservices, event-driven, separate time-series storage) but exhibits **critical gaps in concurrency control** that pose data integrity risks for financial operations. The system requires significant hardening around transactional consistency, query optimization, and NFR specification before production deployment. Estimated effort: 3-4 sprint cycles to address critical and significant issues.
