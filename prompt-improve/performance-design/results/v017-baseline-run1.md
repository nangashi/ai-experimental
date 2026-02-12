# Performance Design Review - Video Game Achievement Tracking Platform

## Executive Summary

This design contains **critical performance bottlenecks** that will prevent the system from meeting its stated scalability targets (100,000 concurrent users, 10,000 unlocks/minute). The primary issues stem from synchronous processing patterns, inefficient leaderboard recalculation, unbounded data retrieval, and missing performance infrastructure.

**Severity Classification:**
- **Critical (P0)**: 5 issues - will cause immediate system failure under target load
- **High (P1)**: 4 issues - will cause severe degradation under normal use
- **Medium (P2)**: 3 issues - will impact user experience and operational costs

---

## Critical Performance Issues (P0)

### 1. Synchronous Leaderboard Recalculation on Every Achievement Unlock

**Location:** Section 6.2 - "Leaderboards are recalculated on every achievement unlock"

**Problem Description:**
The design specifies that leaderboard recalculation happens synchronously during the achievement unlock flow. At 10,000 unlocks/minute (167/second), this requires:
- Fetching all player scores for ranking calculation (Section 3.2 step 2: "System retrieves all player scores")
- Sorting operations across potentially millions of players
- Updating rank fields in the database
- All blocking the unlock API response

**Impact Analysis:**
- **Latency:** Each unlock will wait for O(n log n) sorting operation where n = total players
- **Throughput:** Database will face write contention on leaderboard table (167 writes/sec minimum)
- **Scalability:** Linear degradation as player base grows - 1M players means sorting 1M records 167 times per second
- **User Experience:** Achievement unlocks will take 5-10+ seconds instead of milliseconds

**Recommended Solution:**
1. **Immediate:** Decouple leaderboard updates via async processing
   - Send unlock event to message queue (RabbitMQ already in stack)
   - Return success response immediately after recording unlock
   - Process leaderboard updates in background workers with batching

2. **Efficient Calculation:** Use incremental ranking updates
   - Maintain sorted sets in Redis (ZADD O(log n) vs full sort O(n log n))
   - Update only affected rank ranges, not entire leaderboard
   - Periodically reconcile Redis cache with PostgreSQL authoritative data

3. **Query Optimization:** Add composite indexes
   ```sql
   CREATE INDEX idx_leaderboard_game_points ON leaderboards(game_id, total_points DESC);
   ```

**Expected Improvement:** Response time: 5-10s → <100ms, Throughput: 10x increase

---

### 2. Missing Database Indexes for Core Query Patterns

**Location:** Section 4.1 - Data Model shows no index definitions beyond primary keys

**Problem Description:**
The schema lacks indexes for high-frequency query patterns:

**Critical Missing Indexes:**
1. `player_achievements(player_id, unlocked_at)` - for achievement history queries (section 5.1 GET endpoint)
2. `player_achievements(achievement_id)` - for duplicate unlock checks (section 6.1)
3. `player_statistics(player_id, game_id)` - for statistics lookups (section 5.3)
4. `leaderboards(game_id, total_points DESC, player_id)` - for leaderboard ranking (section 5.2)

**Impact Analysis:**
Without these indexes:
- **Achievement history queries:** Full table scan on every player profile view - O(n) where n = total unlocks across all players (potentially 100M+ records)
- **Duplicate checks:** Sequential scan for each unlock attempt - 167 table scans/second at peak
- **Statistics queries:** Cannot efficiently join player_statistics with games
- **Leaderboard queries:** Cannot use index-only scans for ranking

At 100,000 concurrent users with even modest query patterns, database will saturate CPU before reaching 10% of target load.

**Recommended Solution:**
```sql
-- Achievement queries
CREATE INDEX idx_player_achievements_player ON player_achievements(player_id, unlocked_at DESC);
CREATE INDEX idx_player_achievements_achievement ON player_achievements(achievement_id);
CREATE UNIQUE INDEX idx_player_achievements_unique ON player_achievements(player_id, achievement_id);

-- Statistics queries
CREATE INDEX idx_player_statistics_player_game ON player_statistics(player_id, game_id);
CREATE INDEX idx_player_statistics_recorded_at ON player_statistics(player_id, recorded_at DESC);

-- Leaderboard queries
CREATE INDEX idx_leaderboard_game_points ON leaderboards(game_id, total_points DESC) INCLUDE (player_id);
CREATE INDEX idx_leaderboard_player ON leaderboards(player_id, game_id);
```

**Expected Improvement:** Query time: seconds → milliseconds, CPU utilization: -90%

---

### 3. Unbounded Result Sets Without Pagination

**Location:**
- Section 3.2: "System retrieves all player scores"
- Section 5.1: GET /players/{player_id}/achievements - no pagination parameters
- Section 5.3: GET /players/{player_id}/statistics - returns all games
- Section 6.3: "Historical trends are calculated by retrieving all player_statistics records"

**Problem Description:**
Multiple endpoints retrieve unbounded datasets:

1. **Achievement history:** No limit on achievements per player (active players may have 1000+ achievements across games)
2. **Statistics history:** Retrieves ALL historical records - if recorded daily, that's 365 records per game per year
3. **Leaderboard calculation:** Loads entire player base into memory for sorting
4. **Dashboard aggregation:** Processes all games without limits

**Impact Analysis:**
- **Memory:** Single dashboard request can load 10K+ database rows into application memory
- **Network:** Transferring megabytes of JSON per request
- **Database:** Full table scans consuming I/O bandwidth
- **Client:** Browser hangs rendering large datasets

With 100,000 concurrent users, even 1% requesting dashboards simultaneously = 1000 requests × 10MB = 10GB concurrent memory usage just for this endpoint.

**Recommended Solution:**

**API Changes:**
```python
# Add pagination to all list endpoints
GET /api/v1/players/{player_id}/achievements?limit=50&offset=0
GET /api/v1/players/{player_id}/statistics?game_id={id}&period=30d
GET /api/v1/leaderboards/{game_id}?limit=100&offset=0  # Already limited to 100, document it
```

**Query Patterns:**
```python
# Achievement history with pagination
SELECT * FROM player_achievements
WHERE player_id = ?
ORDER BY unlocked_at DESC
LIMIT 50 OFFSET 0;

# Statistics with time windows
SELECT * FROM player_statistics
WHERE player_id = ? AND recorded_at > NOW() - INTERVAL '30 days'
ORDER BY recorded_at DESC;

# Dashboard aggregation - use SQL aggregation, not application
SELECT
  COUNT(DISTINCT game_id) as games_owned,
  SUM(achievement_count) as total_achievements,
  AVG(completion_percentage) as average_completion
FROM player_statistics
WHERE player_id = ?;
```

**Expected Improvement:** Memory usage: -95%, Response payload size: -90%, Response time: -80%

---

### 4. N+1 Query Pattern in Dashboard Endpoint

**Location:** Section 5.3 - GET /api/v1/players/{player_id}/dashboard

**Problem Description:**
The dashboard response includes `recent_achievements` array. Based on the data model, this requires:
1. Query player_statistics to get game list (1 query)
2. For each game, query player_achievements to get recent unlocks (N queries where N = number of games)
3. For each achievement, query achievements table for details (M queries where M = achievements per game)

Typical pattern:
```python
# Anti-pattern
stats = db.query(PlayerStatistics).filter_by(player_id=player_id).all()
for stat in stats:
    achievements = db.query(PlayerAchievement).filter_by(
        player_id=player_id,
        game_id=stat.game_id
    ).order_by(unlocked_at.desc()).limit(5).all()
    for achievement in achievements:
        detail = db.query(Achievement).get(achievement.achievement_id)
```

**Impact Analysis:**
- **Query Count:** 1 + N + (N × 5) = 1 + 12 + 60 = 73 queries for a player with 12 games
- **Latency:** 73 × 5ms (typical query time) = 365ms minimum, before application processing
- **Database Load:** At 100,000 concurrent users with 1% on dashboard = 1000 × 73 = 73,000 queries/second
- **Connection Pool:** Will exhaust database connections under load

**Recommended Solution:**

**Use JOIN queries to fetch all data in 1-2 queries:**
```python
# Efficient approach
recent_achievements = db.query(
    PlayerAchievement, Achievement
).join(
    Achievement, PlayerAchievement.achievement_id == Achievement.id
).filter(
    PlayerAchievement.player_id == player_id
).order_by(
    PlayerAchievement.unlocked_at.desc()
).limit(20).all()

# Or use subquery for per-game limits
subq = db.query(
    PlayerAchievement.achievement_id,
    ROW_NUMBER().over(
        partition_by=PlayerAchievement.game_id,
        order_by=PlayerAchievement.unlocked_at.desc()
    ).label('rn')
).filter(
    PlayerAchievement.player_id == player_id
).subquery()

results = db.query(Achievement).join(
    subq, Achievement.id == subq.c.achievement_id
).filter(subq.c.rn <= 5).all()
```

**Add composite index:**
```sql
CREATE INDEX idx_player_achievements_recent ON player_achievements(player_id, unlocked_at DESC)
INCLUDE (achievement_id, game_id);
```

**Expected Improvement:** Query count: 73 → 2, Latency: 365ms → <20ms, DB load: -95%

---

### 5. Missing Connection Pooling Configuration

**Location:** Section 2.3 lists SQLAlchemy but no connection pool settings mentioned

**Problem Description:**
The design doesn't specify database connection pooling parameters. Default SQLAlchemy settings are:
- Pool size: 5
- Max overflow: 10
- Total max connections: 15

At target load (100,000 concurrent users), even with modest database query patterns:
- Each API request needs 1-3 database queries
- Request duration: 100-500ms
- Concurrent requests: 100,000 × 0.01 (1% making requests simultaneously) = 1,000
- Required connections: 1,000 × 1.5 (avg queries per request) = 1,500

**Impact Analysis:**
- **Connection Exhaustion:** 15 available vs 1,500 needed = 99% of requests waiting for connections
- **Timeout Cascade:** Default timeout 30s means requests pile up exponentially
- **Database Overhead:** Connection thrashing (constant open/close) when pool is saturated
- **User Experience:** Requests fail with "QueuePool limit exceeded" errors

**Recommended Solution:**

**Configure connection pooling:**
```python
# config/database.py
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,              # Base connection pool
    max_overflow=30,           # Additional connections under load
    pool_timeout=10,           # Fail fast instead of 30s default
    pool_recycle=3600,         # Recycle connections every hour
    pool_pre_ping=True,        # Verify connections before use
    echo_pool=True             # Log pool metrics for monitoring
)
```

**Calculate requirements:**
```
Required connections = (Peak RPS × Avg Query Time × Avg Queries Per Request) / 1000
= (1000 RPS × 50ms × 2 queries) / 1000 = 100 connections
```

**Infrastructure:**
- Set PostgreSQL `max_connections = 200` (2x calculated requirement for safety)
- Use PgBouncer for connection pooling at database layer:
  - Pool mode: transaction
  - Max client connections: 1000
  - Default pool size: 25 per database

**Expected Improvement:** Eliminates connection timeouts, enables target throughput

---

## High Priority Issues (P1)

### 6. WebSocket Scalability Architecture Missing

**Location:** Section 2.1 - "WebSocket: Socket.IO" with no architecture details

**Problem Description:**
Real-time notifications (section 5.4) require persistent WebSocket connections for 100,000 concurrent users. The design doesn't address:
- How WebSocket connections are distributed across multiple application servers
- Session affinity requirements (Socket.IO requires sticky sessions)
- Message broadcasting mechanism when player's connection is on different server than event origin
- Memory overhead of maintaining 100K connections

**Impact Analysis:**
- **Memory:** Each WebSocket connection: ~5KB = 100,000 × 5KB = 500MB per server
- **Load Balancer:** AWS ALB sticky sessions required, limits horizontal scaling effectiveness
- **Broadcasting:** Achievement unlocks must notify all online friends - without pub/sub, requires server-to-server messaging
- **Failover:** Connection state lost on server failure, no reconnection token mechanism

**Recommended Solution:**

**Use Redis Pub/Sub for WebSocket clustering:**
```python
# Broadcast achievement to all servers
redis_client.publish(
    f'player:{player_id}:notifications',
    json.dumps({
        'type': 'achievement.unlocked',
        'data': achievement_data
    })
)

# Each server subscribes and forwards to local WebSocket clients
```

**Architecture components:**
1. **Session Affinity:** Enable ALB sticky sessions with 1-hour duration
2. **Redis Pub/Sub:** Already have Redis for sessions, add pub/sub channels
3. **Connection Registry:** Track which server holds each player's connection
   ```python
   redis_client.setex(f'ws:player:{player_id}', 3600, server_instance_id)
   ```
4. **Graceful Shutdown:** On server restart, notify clients to reconnect with exponential backoff

**Resource Planning:**
- 100,000 connections ÷ 5 servers = 20,000 connections per server
- Memory per server: 20,000 × 5KB = 100MB for WebSocket state
- Redis pub/sub throughput: ~50,000 messages/sec (sufficient for notification volume)

**Expected Improvement:** Enables horizontal scaling, eliminates notification delivery failures

---

### 7. Missing Caching Strategy for High-Frequency Reads

**Location:** Section 2.2 lists ElastiCache but no usage patterns defined

**Problem Description:**
Multiple high-frequency, read-heavy endpoints have no caching:

1. **Leaderboard queries:** Section 5.2 - same top 100 list requested by thousands of users
2. **Achievement metadata:** Section 4.1 - static data (name, description, points) queried repeatedly
3. **Player profiles:** Username, stats queried for every leaderboard view and friend comparison
4. **Game metadata:** Likely queried for every statistics display

Without caching:
- Leaderboard endpoint: Same PostgreSQL query executed 1000s of times/minute
- Achievement details: N+1 pattern amplified (see issue #4)
- Database read load: Unnecessarily saturates read replicas

**Impact Analysis:**
- **Database Load:** 80% of queries are repeated reads of same data
- **Latency:** 50-100ms database round-trips for data that changes infrequently
- **Costs:** Paying for read replica capacity to serve cacheable data
- **Scalability:** Read replicas become bottleneck before application servers

**Recommended Solution:**

**Implement multi-layer caching strategy:**

**Layer 1: Application-level cache (short TTL, high hit rate)**
```python
# Cache leaderboard top 100 for 30 seconds
@cache(ttl=30)
async def get_leaderboard(game_id: str, region: Optional[str] = None):
    cache_key = f"leaderboard:{game_id}:{region or 'global'}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    # Query database
    results = db.query(Leaderboard).filter_by(game_id=game_id).order_by(
        Leaderboard.total_points.desc()
    ).limit(100).all()

    await redis.setex(cache_key, 30, json.dumps(results))
    return results
```

**Layer 2: Static data cache (long TTL, invalidate on update)**
```python
# Cache achievement metadata for 1 hour
@cache(ttl=3600)
async def get_achievement(achievement_id: str):
    cache_key = f"achievement:{achievement_id}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    achievement = db.query(Achievement).get(achievement_id)
    await redis.setex(cache_key, 3600, json.dumps(achievement))
    return achievement
```

**Layer 3: CDN caching for API responses**
- Cache leaderboard API responses at CloudFront (already in stack)
- Use Cache-Control headers: `max-age=30, s-maxage=10`
- Vary by query parameters (game_id, region)

**Cache Invalidation:**
```python
# On achievement unlock
async def invalidate_caches(player_id: str, game_id: str):
    await redis.delete(
        f"leaderboard:{game_id}:global",
        f"leaderboard:{game_id}:{player_region}",
        f"player:{player_id}:achievements",
        f"player:{player_id}:stats"
    )
```

**Expected Improvement:**
- Database read load: -70%
- API response time: 100ms → 5ms (cache hit)
- Read replica utilization: -80%

---

### 8. Regional Leaderboard Implementation is Inefficient

**Location:** Section 6.2 - "Regional leaderboards are calculated by filtering players based on region field"

**Problem Description:**
Regional leaderboards require filtering by region THEN sorting by points. However, the data model (section 4.1) doesn't include a `region` field in the `leaderboards` table. This implies:

1. Joining leaderboards with players table to get region
2. Filtering in application code or database WHERE clause
3. Sorting filtered results

Query pattern:
```sql
SELECT l.*, p.username, p.region
FROM leaderboards l
JOIN players p ON l.player_id = p.id
WHERE l.game_id = ? AND p.region = ?
ORDER BY l.total_points DESC
LIMIT 100;
```

**Impact Analysis:**
- **Join Overhead:** Every regional leaderboard query requires join across potentially millions of rows
- **Index Inefficiency:** Cannot use index on (game_id, total_points) because region is in different table
- **Cache Complexity:** Need separate cache entries for every region × game combination
- **Scalability:** Query cost grows O(n) with total player count, not regional player count

**Recommended Solution:**

**Denormalize region into leaderboards table:**
```sql
ALTER TABLE leaderboards ADD COLUMN region VARCHAR(10);

-- Update existing data
UPDATE leaderboards l
SET region = p.region
FROM players p
WHERE l.player_id = p.id;

-- Add composite index
CREATE INDEX idx_leaderboard_regional ON leaderboards(game_id, region, total_points DESC);
```

**Query optimization:**
```sql
-- Now can use single-table index scan
SELECT * FROM leaderboards
WHERE game_id = ? AND region = ?
ORDER BY total_points DESC
LIMIT 100;
```

**Maintain consistency:**
```python
# On player region change (rare event)
async def update_player_region(player_id: str, new_region: str):
    db.query(Leaderboard).filter_by(player_id=player_id).update({
        'region': new_region
    })
    # Invalidate regional leaderboard caches
```

**Alternative:** Use materialized views
```sql
CREATE MATERIALIZED VIEW leaderboard_regional_cache AS
SELECT game_id, region, player_id, total_points,
       ROW_NUMBER() OVER (PARTITION BY game_id, region ORDER BY total_points DESC) as rank
FROM leaderboards l JOIN players p ON l.player_id = p.id;

CREATE UNIQUE INDEX ON leaderboard_regional_cache(game_id, region, rank);
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_regional_cache;
```

**Expected Improvement:** Query time: 200ms → 10ms, Eliminates expensive joins

---

### 9. Statistics Collection Synchronously Updates on Every Achievement

**Location:** Section 6.3 - "Player statistics are updated when achievement is unlocked"

**Problem Description:**
The achievement unlock flow (section 3.2) already includes:
1. Validate and record unlock
2. Send notification
3. Update leaderboard
4. **Update statistics**

Adding statistics update to the synchronous path means:
```python
# Achievement unlock handling (current design)
def unlock_achievement(player_id, achievement_id):
    # 1. Record unlock (write to player_achievements)
    record_unlock(player_id, achievement_id)

    # 2. Send notification (WebSocket broadcast)
    send_notification(player_id, achievement_id)

    # 3. Update leaderboard (write to leaderboards table)
    update_leaderboard(player_id, game_id)

    # 4. Update statistics (write to player_statistics)
    update_statistics(player_id, game_id)

    return response
```

**Impact Analysis:**
- **Latency:** Each unlock waits for 4 sequential operations (1 read + 3 writes)
- **Database Contention:** player_statistics table receives 167 writes/sec at peak (same as unlock rate)
- **Transaction Complexity:** Multi-table write increases deadlock risk
- **Rollback Complexity:** If statistics update fails, what happens to notification already sent?

**Recommended Solution:**

**Move statistics updates to async processing:**
```python
# Immediate response path
def unlock_achievement(player_id, achievement_id):
    # 1. Record unlock (critical path)
    unlock = record_unlock(player_id, achievement_id)

    # 2. Send notification (critical path for UX)
    send_notification(player_id, achievement_id)

    # 3. Queue background work (non-critical path)
    celery.send_task('update_player_stats', args=[player_id, game_id])
    celery.send_task('update_leaderboard', args=[player_id, game_id])

    return {"success": True, "achievement": unlock}

# Background worker
@celery.task
def update_player_stats(player_id, game_id):
    # Batch multiple updates if unlocks happen rapidly
    stats = calculate_current_stats(player_id, game_id)
    db.query(PlayerStatistics).filter_by(
        player_id=player_id,
        game_id=game_id
    ).update(stats)
```

**Benefits:**
- Unlock API response time: <50ms instead of 200-500ms
- Database write pressure distributed over time via batching
- Failure isolation: Stats calculation failure doesn't affect unlock
- Can implement debouncing: If player unlocks 5 achievements in 10 seconds, update stats once

**Expected Improvement:** Response time: -75%, Write throughput: +50% via batching

---

## Medium Priority Issues (P2)

### 10. Missing Performance Monitoring and Observability

**Location:** Section 6.5 mentions logging but no performance metrics collection

**Problem Description:**
The design logs "response time" (section 6.5) but doesn't specify:
- Percentile tracking (p50, p95, p99 latencies)
- Database query performance metrics
- Cache hit/miss rates
- Queue depth and processing lag
- Resource utilization (CPU, memory, connections)

Without these metrics, cannot:
- Detect performance degradation before users complain
- Identify which queries need optimization
- Validate that caching strategy is working
- Capacity plan for growth

**Impact Analysis:**
- **Reactive:** Only discover performance issues after system is degraded
- **Blind Optimization:** Cannot measure impact of performance improvements
- **Incident Response:** Slow root cause analysis during outages
- **Capacity Planning:** No data to predict when to scale

**Recommended Solution:**

**Implement comprehensive metrics collection:**

**Application Metrics (Prometheus + Grafana):**
```python
from prometheus_client import Histogram, Counter, Gauge

# Request latency histogram
http_request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint', 'status']
)

# Database query metrics
db_query_duration = Histogram(
    'db_query_duration_seconds',
    'Database query latency',
    ['query_type', 'table']
)

# Cache metrics
cache_hits = Counter('cache_hits_total', 'Cache hit count', ['cache_key_pattern'])
cache_misses = Counter('cache_misses_total', 'Cache miss count', ['cache_key_pattern'])

# Queue depth
queue_depth = Gauge('celery_queue_depth', 'Pending tasks in queue', ['queue_name'])
```

**Database Metrics (pg_stat_statements):**
```sql
-- Enable query statistics
CREATE EXTENSION pg_stat_statements;

-- Monitor slow queries
SELECT query, calls, mean_exec_time, max_exec_time
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC
LIMIT 20;
```

**Alerting Rules:**
```yaml
# Prometheus alerting
groups:
  - name: performance
    rules:
      - alert: HighAPILatency
        expr: histogram_quantile(0.95, http_request_duration_seconds) > 1.0
        for: 5m

      - alert: DatabaseSlowQueries
        expr: rate(db_query_duration_seconds_sum[5m]) > 0.5
        for: 5m

      - alert: LowCacheHitRate
        expr: rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m])) < 0.7
        for: 10m
```

**Expected Improvement:** Enables proactive performance management, 50% faster incident resolution

---

### 11. No Data Lifecycle Management Strategy

**Location:** Section 4.1 shows tables with timestamps but no retention policies

**Problem Description:**
Tables accumulate unbounded historical data:
- `player_achievements.unlocked_at` - grows forever (each unlock is permanent)
- `player_statistics.recorded_at` - new record potentially every day per player per game
- Logs (section 6.5) - "all API requests logged" with no rotation policy

**Growth Projections:**
- 100,000 active users × 10 games × 50 achievements = 50M player_achievements records/year
- player_statistics: 100,000 users × 10 games × 365 days = 365M records/year
- API logs: 1000 RPS × 86,400 sec/day × 365 days = 31.5B log entries/year

**Impact Analysis:**
- **Storage Costs:** Exponential growth of database size (100GB → 1TB → 10TB)
- **Query Performance:** Indexes become less effective as tables grow to billions of rows
- **Backup/Recovery:** Longer backup windows, slower restore times
- **Operational:** Vacuum operations take hours, blocking queries

**Recommended Solution:**

**Implement tiered data retention:**

**Hot Data (PostgreSQL - last 90 days):**
```sql
-- Partition player_statistics by month
CREATE TABLE player_statistics (
    -- columns
    recorded_at TIMESTAMP NOT NULL
) PARTITION BY RANGE (recorded_at);

CREATE TABLE player_statistics_2024_01 PARTITION OF player_statistics
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Auto-create partitions
CREATE EXTENSION pg_partman;
SELECT partman.create_parent('public.player_statistics', 'recorded_at', 'native', 'monthly');
```

**Warm Data (S3 - 90 days to 2 years):**
```python
# Monthly archival job
def archive_old_statistics():
    # Export to S3
    old_data = db.query(PlayerStatistics).filter(
        PlayerStatistics.recorded_at < datetime.now() - timedelta(days=90)
    ).all()

    s3_client.put_object(
        Bucket='achievement-platform-archive',
        Key=f'statistics/2024/01/data.parquet',
        Body=to_parquet(old_data)
    )

    # Drop old partitions
    db.execute("DROP TABLE player_statistics_2024_01")
```

**Cold Data (Glacier - >2 years):**
- Lifecycle policy to transition S3 → Glacier after 2 years
- Delete after 7 years (compliance retention)

**Achievement Data (permanent):**
- player_achievements table remains, but rarely queried beyond recent
- Create indexed view for recent achievements:
```sql
CREATE MATERIALIZED VIEW recent_achievements AS
SELECT * FROM player_achievements
WHERE unlocked_at > NOW() - INTERVAL '90 days';

CREATE INDEX ON recent_achievements(player_id, unlocked_at DESC);
```

**Expected Improvement:**
- Database size: -70% after 1 year
- Query performance: Stable as active dataset size remains bounded
- Storage costs: -80% via S3/Glacier tiering

---

### 12. Missing Rate Limiting for Expensive Operations

**Location:** Section 7.3 mentions "Rate limiting: 100 requests per minute per user" but no differentiation by endpoint cost

**Problem Description:**
The design applies uniform rate limiting (100 req/min) across all endpoints, but different operations have vastly different costs:

**Cheap operations:** GET /leaderboards (cached) - 5ms, minimal resources
**Expensive operations:**
- GET /players/{id}/dashboard - 73 queries (issue #4), 365ms
- POST /achievements/unlock - 4 writes + notification + leaderboard update, 200ms+
- GET /statistics (with historical trends) - unbounded query (issue #3)

A malicious or buggy client could:
- Make 100 dashboard requests/minute = 7,300 database queries/minute = 120 queries/sec from single user
- Exhaust database connection pool (issue #5)
- Trigger cache stampede on expensive queries

**Impact Analysis:**
- **Abuse:** Single user can cause disproportionate load
- **Cascading Failure:** One slow endpoint causes timeouts in others (shared connection pool)
- **Cost:** Paying for database capacity to handle abuse rather than legitimate traffic

**Recommended Solution:**

**Implement tiered rate limiting by operation cost:**

**Endpoint Categories:**
```python
# Rate limit configuration
RATE_LIMITS = {
    # Cached reads - high limit
    'leaderboard:read': '1000/minute',
    'achievement:list': '500/minute',

    # Uncached reads - moderate limit
    'player:profile': '200/minute',
    'statistics:view': '100/minute',

    # Expensive aggregations - low limit
    'dashboard:view': '20/minute',     # Issue #4: 73 queries per request
    'statistics:historical': '10/minute',  # Issue #3: unbounded queries

    # Writes - lowest limit
    'achievement:unlock': '60/minute',  # Max 1/second
    'player:update': '30/minute'
}
```

**Middleware implementation:**
```python
from fastapi import Request, HTTPException
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.get("/api/v1/players/{player_id}/dashboard")
@limiter.limit("20/minute")  # Expensive operation
async def get_dashboard(player_id: str):
    ...

@app.get("/api/v1/leaderboards/{game_id}")
@limiter.limit("1000/minute")  # Cheap cached read
async def get_leaderboard(game_id: str):
    ...
```

**Additional Protection - Cost-based Token Bucket:**
```python
# Each user gets 1000 "cost tokens" per minute
# Different operations consume different tokens:
OPERATION_COSTS = {
    'leaderboard:read': 1,
    'achievement:list': 2,
    'dashboard:view': 50,      # Expensive
    'statistics:historical': 100,  # Very expensive
}

async def check_rate_limit(user_id: str, operation: str):
    cost = OPERATION_COSTS[operation]
    consumed = await redis.incrby(f"rate_limit:{user_id}:tokens", cost)
    if consumed > 1000:
        raise HTTPException(429, "Rate limit exceeded")
    await redis.expire(f"rate_limit:{user_id}:tokens", 60)
```

**Expected Improvement:** Prevents single-user abuse, protects shared resources

---

## Additional Recommendations

### Load Testing Requirements

Before production deployment, conduct load testing to validate:

**Scenario 1: Peak Achievement Unlock**
- 10,000 unlocks/minute (167 RPS)
- Verify <100ms p95 latency after async optimization
- Confirm queue processing keeps up with ingestion rate

**Scenario 2: Concurrent Dashboard Views**
- 1,000 simultaneous dashboard requests
- Verify database connection pool adequacy
- Confirm memory usage stays within limits

**Scenario 3: WebSocket Scale**
- 100,000 concurrent connections
- Broadcast 1,000 notifications/sec
- Verify Redis pub/sub throughput and server memory

**Scenario 4: Leaderboard Query Storm**
- 10,000 concurrent leaderboard requests (cache miss scenario)
- Verify cache warming strategy
- Confirm database can handle fallback queries

---

## Performance SLA Recommendations

Based on the issues identified, proposed SLAs should be:

**API Latency (after optimizations):**
- p50: <50ms
- p95: <200ms
- p99: <500ms

**WebSocket Notification Delivery:**
- p95: <1 second from unlock to notification

**Database:**
- Read query p95: <20ms
- Write query p95: <50ms
- Connection pool utilization: <70%

**Cache:**
- Hit rate: >90% for leaderboards
- Hit rate: >95% for achievement metadata

**Queue Processing:**
- Lag: <5 seconds at p95
- Throughput: 500 tasks/second minimum

---

## Summary of Expected Improvements

Implementing the recommended optimizations will achieve:

| Metric | Current (Projected) | After Optimization | Improvement |
|--------|-------------------|-------------------|-------------|
| Achievement unlock latency | 5-10 seconds | <100ms | 50-100x |
| Dashboard query count | 73 queries | 2 queries | 36x |
| Database read load | 100% | 30% | -70% |
| Memory per request | 10MB | 500KB | -95% |
| Connection pool utilization | 1500 needed / 15 available | 100 needed / 200 available | Feasible |
| Leaderboard query time | 200ms | 10ms | 20x |
| WebSocket scalability | Single server | Horizontal | Unlimited |

**Critical Path Forward:**
1. Implement async processing (Issue #1, #9) - enables basic functionality
2. Add database indexes (Issue #2) - enables acceptable query performance
3. Configure connection pooling (Issue #5) - prevents connection exhaustion
4. Add pagination (Issue #3) - prevents memory issues
5. Implement caching (Issue #7) - achieves target latency

Without these changes, **the system cannot meet the stated NFRs** (100,000 concurrent users, 10,000 unlocks/minute).
