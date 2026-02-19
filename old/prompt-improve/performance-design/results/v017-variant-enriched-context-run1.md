# Performance Review: Video Game Achievement Tracking Platform

## Executive Summary

This design contains **13 critical performance issues** that will prevent the system from meeting its stated scalability target (100,000 concurrent users, 10,000 unlocks/min). The most severe problems are:

1. **Synchronous leaderboard recalculation on every unlock** - unbounded computational cost growing quadratically with player base
2. **N+1 query patterns** in statistics aggregation and dashboard endpoints
3. **Unbounded result sets** without pagination across all read endpoints
4. **Missing indexes** on critical query paths
5. **Absence of caching** for read-heavy operations (leaderboards, statistics)
6. **Blocking synchronous operations** in the achievement unlock critical path
7. **No capacity planning** or SLA definitions despite stating NFR targets

The design demonstrates fundamental misunderstandings about scalability: recalculating global rankings for millions of players on every unlock, fetching unbounded historical data, and synchronous processing of operations that must be asynchronous at scale.

---

## Critical Issues (P0 - System Cannot Scale)

### 1. Leaderboard Recalculation on Every Unlock

**Location**: Section 6.2 - "Leaderboards are recalculated on every achievement unlock"

**Problem**: The design states leaderboards are fully recalculated on every unlock event. With 10,000 unlocks/min and potentially millions of players, this means:
- Scanning entire player base (potentially millions of rows)
- Sorting by total_points (O(n log n) operation)
- Calculating rank for every player
- Performing this 167 times per second

**Impact**:
- Computational cost grows O(n log n) with player count - 1M players = ~20M comparisons per unlock
- Database CPU exhaustion within hours at stated load (10K unlocks/min)
- Lock contention on leaderboards table prevents horizontal scaling
- Latency grows unboundedly - unlock API response time degrades from milliseconds to seconds

**Why This Matters**: Leaderboard calculation is the single most expensive operation. At scale, naive recalculation creates a throughput ceiling far below requirements. This is compounded by being synchronous in the unlock flow.

**Recommendation**:
- **Async processing**: Move leaderboard updates to background queue (Celery workers)
- **Incremental updates**: Calculate only affected rank changes (player and neighbors)
- **Materialized ranks**: Store pre-calculated ranks, update incrementally
- **Batch processing**: Group updates into periodic recalculation windows (e.g., every 30s)
- **Approximate rankings**: Use HyperLogLog or other probabilistic structures for rough rankings, exact only on-demand
- **Redis sorted sets**: Use Redis ZADD/ZRANK for O(log n) rank operations instead of full table scans

---

### 2. Synchronous Achievement Processing Blocks Request Path

**Location**: Section 6.1 - "Achievement unlock events are processed synchronously through the API"

**Problem**: The unlock flow performs multiple synchronous operations:
1. Validate unlock (database query)
2. Record unlock (database write)
3. Send notification (WebSocket broadcast)
4. Update leaderboard (Issue #1 - expensive recalculation)
5. Update statistics (database write)

All of these block the API response. With 10,000 unlocks/min (167/sec), this creates:
- Thread pool exhaustion (FastAPI workers blocked waiting for DB/calculation)
- Cascading failures (slow operations cause request queue buildup)
- Unacceptable latency (users wait for leaderboard calculation to complete)

**Impact**:
- API response times spike to seconds under load
- Request timeouts (typical API gateway timeout = 30s)
- Cannot achieve 100ms-200ms user-facing latency requirement
- Thread starvation prevents handling new requests

**Why This Matters**: User-facing operations have strict latency budgets (~100-200ms). Synchronous operations in request paths violate this constraint. Leaderboard calculation and statistics updates are background concerns - players don't need them to complete before receiving unlock confirmation.

**Recommendation**:
- Validate and record unlock synchronously (required for correctness)
- Return success immediately: `{"success": true, "achievement": {...}}`
- Queue all side effects (notification, leaderboard, statistics) to RabbitMQ for async processing
- Use WebSocket for eventual notification delivery
- Remove `new_rank` from sync response (calculate async, push via WebSocket)

---

### 3. N+1 Query Pattern in Statistics Dashboard

**Location**: Section 5.3 - `GET /api/v1/players/{player_id}/dashboard`

**Problem**: Response includes `"recent_achievements": [...]` which likely requires:
1. Fetch player's games (1 query)
2. For each game, fetch recent achievements (N queries)

Similarly, Section 6.3 states "Dashboard endpoint aggregates statistics from all games" - this implies iterative fetching:
```python
games = db.query(PlayerStatistics).filter_by(player_id=player_id).all()
for game in games:
    achievements = db.query(PlayerAchievements).filter_by(
        player_id=player_id, game_id=game.game_id
    ).all()
```

**Impact**:
- Player with 12 games = 13 queries (1 + 12)
- Query count grows linearly with games owned
- Database connection exhaustion (100K concurrent users × 13 queries = 1.3M queries)
- Response time grows linearly with player's game library

**Why This Matters**: Dashboard is likely a high-traffic endpoint (landing page). N+1 patterns cause multiplicative query counts and connection pool exhaustion. With 100K concurrent users, even small multiplicative factors become critical.

**Recommendation**:
- Use JOIN or subquery to fetch all data in single query:
```sql
SELECT ps.*, pa.achievement_id, pa.unlocked_at, a.name, a.points
FROM player_statistics ps
LEFT JOIN player_achievements pa ON ps.player_id = pa.player_id AND ps.game_id = pa.game_id
LEFT JOIN achievements a ON pa.achievement_id = a.id
WHERE ps.player_id = ? AND pa.unlocked_at > NOW() - INTERVAL '7 days'
ORDER BY pa.unlocked_at DESC
LIMIT 10
```
- Consider denormalizing frequently accessed aggregates (total_achievements, total_playtime) into player table

---

### 4. Unbounded Result Sets Without Pagination

**Location**: Multiple endpoints lack pagination:
- `GET /api/v1/players/{player_id}/achievements` - returns ALL achievements (potentially hundreds)
- `GET /api/v1/leaderboards/{game_id}` - returns top 100 but no pagination for full leaderboard browsing
- `GET /api/v1/players/{player_id}/statistics` - returns ALL games (unbounded)

**Problem**:
- Queries fetch entire result sets into memory
- No LIMIT clauses evident in design
- Player with 500 achievements across 50 games = 500+ row fetches per request
- Memory allocation grows with individual player's data

**Impact**:
- Memory exhaustion on application servers (500 bytes/row × 500 rows × 1000 concurrent requests = 250 MB just for serialization)
- Slow queries as data grows (full table scans for sorting)
- Unpredictable response times (depends on user's data volume)
- Database load grows linearly with player progression

**Why This Matters**: Unbounded queries create unpredictable resource consumption. As players accumulate achievements over months/years, response times degrade. Memory exhaustion causes out-of-memory errors and service crashes.

**Recommendation**:
- Implement cursor-based pagination for all list endpoints:
```
GET /api/v1/players/{player_id}/achievements?limit=50&cursor=<token>
```
- Use `LIMIT` and `OFFSET` (or cursor) in all queries
- Default page size: 50 items, max: 100
- Add `total_count` to responses for UI pagination controls
- Consider infinite scroll pattern for dashboards (lazy loading)

---

### 5. Missing Critical Database Indexes

**Location**: Section 4 - Data Model shows tables but no index specifications

**Problem**: Based on API design, these queries require indexes but none are specified:
- `player_achievements.player_id` - queried on every dashboard/achievements endpoint
- `player_achievements.achievement_id` - join key
- `leaderboards.game_id` - filtered on leaderboard queries
- `leaderboards.total_points` - sorted for ranking
- `player_statistics.player_id, player_statistics.game_id` - composite key for lookups
- `achievements.game_id` - filtered when loading game achievements
- `player_achievements.unlocked_at` - sorted for "recent achievements"

Without indexes, PostgreSQL performs full table scans:
- 1M player_achievements rows = 1M row examination per query
- Sorting without index = O(n log n) in-memory sort

**Impact**:
- Query time grows linearly/exponentially with table size
- Leaderboard queries with sorting become catastrophically slow (full table scan + sort)
- Achievement lookup for validation (duplicate check) scans entire player_achievements table
- Database CPU at 100% under minimal load

**Why This Matters**: Missing indexes are the most common performance killer in database-backed applications. Even well-designed queries become unusable without indexes. Query planner defaults to sequential scans which scale catastrophically.

**Recommendation**:
Create indexes immediately:
```sql
-- Foreign key indexes (required for joins)
CREATE INDEX idx_player_achievements_player ON player_achievements(player_id);
CREATE INDEX idx_player_achievements_achievement ON player_achievements(achievement_id);
CREATE INDEX idx_player_achievements_unlocked ON player_achievements(unlocked_at);

-- Composite index for duplicate check
CREATE UNIQUE INDEX idx_player_achievement_unique ON player_achievements(player_id, achievement_id);

-- Leaderboard indexes
CREATE INDEX idx_leaderboards_game ON leaderboards(game_id);
CREATE INDEX idx_leaderboards_game_points ON leaderboards(game_id, total_points DESC);

-- Statistics indexes
CREATE INDEX idx_player_statistics_player_game ON player_statistics(player_id, game_id);

-- Achievements by game
CREATE INDEX idx_achievements_game ON achievements(game_id);
```

---

### 6. Missing Cache Layer for Read-Heavy Operations

**Location**: No caching strategy described; Redis mentioned only for "Session management" (Section 2.3)

**Problem**: The platform is read-heavy:
- Leaderboards: same data requested by thousands of users simultaneously
- Player profiles/statistics: repeatedly fetched for social features (friend comparisons)
- Achievement definitions: static data fetched on every unlock

Yet no caching strategy is defined. Every request hits PostgreSQL:
- Leaderboard query: expensive sort + filter operation repeated for every viewer
- Player dashboard: aggregation repeated for every page load
- Achievement metadata: same 100-record lookup performed thousands of times

**Impact**:
- Database becomes bottleneck (cannot handle 100K concurrent read queries)
- Read replicas help but don't eliminate repeated computation
- Response times degrade linearly with load
- Cannot achieve stated scalability target without caching

**Why This Matters**: Read operations outnumber writes 100:1 in typical platforms. Databases excel at consistency but are expensive for repeated identical queries. Caching is mandatory for read-heavy systems to achieve target throughput. Leaderboard recalculation (Issue #1) is especially critical - calculated once, read thousands of times.

**Recommendation**:
Implement multi-layer caching:

**1. Redis for hot data (short TTL):**
```python
# Leaderboard - 60s TTL
cache_key = f"leaderboard:{game_id}:{region}"
leaderboard = redis.get(cache_key)
if not leaderboard:
    leaderboard = calculate_leaderboard(game_id, region)
    redis.setex(cache_key, 60, leaderboard)

# Player rank - 30s TTL
rank_key = f"rank:{game_id}:{player_id}"
```

**2. Application-level cache for static data:**
```python
# Achievement definitions - 1 hour TTL
@cached(ttl=3600)
def get_achievements_by_game(game_id):
    return db.query(Achievements).filter_by(game_id=game_id).all()
```

**3. CDN for API responses (aggressive caching):**
- Cache-Control headers for public leaderboards: `max-age=30`
- ETags for conditional requests

**4. Cache invalidation strategy:**
- Invalidate leaderboard cache on rank changes (async queue)
- Use cache tags for related entity invalidation
- Implement cache warming for popular games (pre-calculate top games' leaderboards)

---

### 7. Historical Statistics Queries Are Unbounded

**Location**: Section 6.3 - "Historical trends are calculated by retrieving all player_statistics records"

**Problem**: `player_statistics` table uses `recorded_at` timestamp, suggesting time-series data. The design states "retrieving all records" to calculate trends. This means:
- No time window filtering (fetches months/years of data)
- No aggregation at storage time (raw data points)
- Query result size grows unboundedly over time
- 1 data point per day per game × 365 days × 12 games = 4,380 rows per player

**Impact**:
- Memory exhaustion when loading historical data
- Query time grows linearly with platform age
- Response time unpredictable (depends on how long player has been active)
- Trend calculation (client-side?) wastes bandwidth and CPU

**Why This Matters**: Time-series data without lifecycle management creates unbounded growth. Query performance degrades over time in production. "Historical trends" should be pre-aggregated (hourly/daily rollups) and time-windowed (last 30/90 days) to bound resource consumption.

**Recommendation**:
- Add time window to queries: `WHERE recorded_at > NOW() - INTERVAL '90 days'`
- Implement data retention policy: archive statistics older than 1 year
- Pre-aggregate trends at write time:
  - Daily rollups: `player_statistics_daily` (aggregate hourly data)
  - Monthly rollups: `player_statistics_monthly` (aggregate daily data)
- Use aggregation tables for trend queries instead of raw data
- Implement data lifecycle: raw (7 days) → daily rollup (90 days) → monthly rollup (2 years) → archive

---

## High-Severity Issues (P1 - Performance Degradation)

### 8. Missing Connection Pooling Configuration

**Location**: Section 2.3 mentions "SQLAlchemy: ORM" but no connection pool sizing

**Problem**: With 100,000 concurrent users and potential N+1 query patterns, connection pool sizing is critical. Default SQLAlchemy pool (5 connections) will immediately saturate. No configuration mentioned for:
- Pool size
- Max overflow
- Pool timeout
- Connection lifecycle

**Impact**:
- Connection exhaustion under load (requests wait for available connections)
- Database connection limit exhaustion (PostgreSQL default = 100 connections)
- Cascading failures (timeouts cause retries, amplifying load)

**Why This Matters**: Connection establishment is expensive (~10ms per connection). Creating connections per-request wastes resources and doesn't scale. Properly sized connection pools are mandatory for database-backed applications at scale.

**Recommendation**:
```python
# SQLAlchemy configuration
engine = create_engine(
    DATABASE_URL,
    pool_size=20,              # Base connection pool
    max_overflow=10,           # Burst capacity
    pool_timeout=30,           # Wait 30s for connection
    pool_recycle=3600,         # Recycle connections hourly
    pool_pre_ping=True         # Validate connections before use
)
```
- Calculate pool size based on: `(expected concurrent queries / query duration) × 1.2 safety factor`
- Monitor pool utilization and tune based on actual load
- Consider pgBouncer for connection pooling at PostgreSQL level (transaction-level pooling)

---

### 9. WebSocket Notification Broadcast Lacks Scalability Strategy

**Location**: Section 3.2 - "Notification sent to player via WebSocket" and Section 5.4 WebSocket events

**Problem**: Design shows WebSocket notifications but doesn't address:
- How notifications are delivered in multi-server deployment (socket connections are server-local)
- Broadcasting to all friends when achievement is unlocked (fan-out problem)
- Persistent connections at 100K concurrent users scale

With Docker containers and load balancer (Section 2.2), Socket.IO connections are distributed across servers. When achievement unlocks:
1. Request hits Server A
2. Player's WebSocket connection may be on Server B
3. No pub/sub mechanism described to bridge servers

**Impact**:
- Notifications fail silently (connection on different server)
- Sticky sessions required (breaks load balancing effectiveness)
- Cannot horizontally scale WebSocket servers
- Broadcasting to friends (social features) creates N×M problem (N friends × M mutual unlocks)

**Why This Matters**: WebSocket connections are stateful and server-local. Multi-server deployments require pub/sub infrastructure to route messages. Leaderboard update notifications (Section 5.4) amplify this - every unlock potentially notifies hundreds of players watching same leaderboard.

**Recommendation**:
- Implement Redis pub/sub for WebSocket message routing:
```python
# Publisher (achievement unlock handler)
redis.publish('notifications', json.dumps({
    'player_id': player_id,
    'event': 'achievement.unlocked',
    'data': achievement_data
}))

# Subscriber (Socket.IO server process)
pubsub = redis.pubsub()
pubsub.subscribe('notifications')
for message in pubsub.listen():
    socketio.emit(message['event'], message['data'], room=message['player_id'])
```
- Use Socket.IO rooms for targeted delivery (join player to room = player_id)
- Implement notification queuing for offline players (store in database, deliver on reconnect)
- Consider fan-out limits for social broadcasts (notify max 50 friends per unlock, truncate rest)
- Monitor WebSocket connection count and implement connection limits per server

---

### 10. Regional Leaderboards Calculated via Table Scan

**Location**: Section 6.2 - "Regional leaderboards are calculated by filtering players based on region field"

**Problem**: Two issues:
1. Data model shows no `region` field in players or leaderboards table
2. Filtering entire player base by region + sorting = full table scan even with index

The design suggests:
```sql
SELECT * FROM leaderboards
WHERE game_id = ? AND player.region = ?
ORDER BY total_points DESC
```

This requires joining leaderboards to players (to get region), filtering, and sorting - even with indexes, examines all leaderboard rows for that game.

**Impact**:
- Regional leaderboard queries scale O(n) with total player base, not regional player count
- Join + filter + sort more expensive than direct index access
- Multiple regional views requested simultaneously amplifies cost
- Defeats purpose of regional optimization (still processes global data)

**Why This Matters**: Regional leaderboards should be a performance optimization (smaller data set), but the design makes them equally expensive as global leaderboards. Filtering after join wastes query planner effort.

**Recommendation**:
- Denormalize region into leaderboards table: add `region` column
- Create separate leaderboard records per region:
```python
# On unlock, update all applicable leaderboards
update_leaderboard(game_id, player_id, 'global')
update_leaderboard(game_id, player_id, player.region)
```
- Add composite index: `CREATE INDEX idx_leaderboards_game_region ON leaderboards(game_id, region, total_points DESC)`
- Query becomes: `SELECT * FROM leaderboards WHERE game_id = ? AND region = ? ORDER BY total_points DESC LIMIT 100`
- Eliminates join, filter operates on indexed column, benefits from covering index

---

### 11. Statistics Update on Every Unlock Causes Write Amplification

**Location**: Section 6.3 - "Player statistics are updated when achievement is unlocked"

**Problem**: Every achievement unlock triggers statistics update:
- `achievement_count` incremented
- `completion_percentage` recalculated
- `last_played` updated
- `recorded_at` timestamp updated

With 10,000 unlocks/min across potentially many games, this creates:
- 10,000 writes/min to player_statistics
- Lock contention on frequently updated rows
- Index maintenance overhead
- Write amplification if statistics span multiple games

Additionally, Section 4.1 shows `player_statistics` uses `recorded_at` for time-series, but updates suggest modification in place rather than append-only.

**Impact**:
- Write contention on hot rows (popular players unlocking achievements frequently)
- Update locks block concurrent reads
- Index fragmentation from frequent updates
- Mixing real-time updates with historical time-series creates schema confusion

**Why This Matters**: High-frequency updates to same rows create lock contention and index churn. Statistics updates are non-critical (don't need to be synchronous or exactly real-time) but design treats them as critical-path updates.

**Recommendation**:
- Separate real-time statistics from historical time-series:
  - `player_statistics_current` - single row per player/game, updated on unlock
  - `player_statistics_history` - append-only daily snapshots
- Batch statistics updates via async queue (update every 10s, not every unlock)
- Use Redis for real-time counters, periodically flush to PostgreSQL:
```python
# Increment in Redis
redis.hincrby(f"stats:{player_id}:{game_id}", 'achievement_count', 1)

# Periodic flush (Celery beat task every 60s)
for key in redis.scan_iter('stats:*'):
    stats = redis.hgetall(key)
    db.update(PlayerStatistics, stats)
    redis.delete(key)
```
- Consider append-only event log, materialize statistics via aggregation query

---

## Medium-Severity Issues (P2 - Missing Best Practices)

### 12. No Performance Monitoring or SLA Tracking

**Location**: Section 7.1/7.2 states targets but no monitoring strategy in Section 6.5

**Problem**: Design specifies:
- 100,000 concurrent users
- 10,000 unlocks/min
- 99.5% uptime

But monitoring section (6.5) only mentions:
- API request logging (timestamp, endpoint, response time)
- Error logging

Missing:
- Response time percentiles (p50, p95, p99)
- Throughput metrics (requests/sec, unlocks/min)
- Database query performance (slow query log)
- Cache hit rates
- Queue depth and processing lag
- Resource utilization (CPU, memory, connections)
- SLA violation tracking

**Impact**:
- Cannot detect performance degradation until user complaints
- No data for optimization decisions
- Unable to validate if system meets NFR targets
- Blind to bottlenecks in production

**Why This Matters**: Without explicit performance requirements tracking, there's no accountability. Systems need defined SLAs, capacity metrics, and monitoring to detect degradation early. Logging alone doesn't provide actionable performance insights.

**Recommendation**:
Implement comprehensive observability:

**1. APM metrics (Prometheus/Grafana):**
```python
from prometheus_client import Counter, Histogram

achievement_unlocks = Counter('achievement_unlocks_total', 'Total achievement unlocks')
api_latency = Histogram('api_request_duration_seconds', 'API request latency')

@app.post('/achievements/unlock')
async def unlock(request):
    with api_latency.time():
        result = process_unlock(request)
        achievement_unlocks.inc()
        return result
```

**2. Database monitoring:**
- Enable PostgreSQL slow query log (queries > 100ms)
- Track connection pool utilization
- Monitor replication lag

**3. Queue monitoring:**
- RabbitMQ queue depth
- Message processing rate
- Consumer lag

**4. SLA tracking dashboard:**
- Achievement unlock latency: p95 < 200ms
- Leaderboard load time: p99 < 500ms
- API availability: 99.5% uptime (43.8 hours downtime/year)

**5. Alerting:**
- Alert when p95 latency > 300ms (degradation warning)
- Alert when queue depth > 10,000 (processing lag)
- Alert when database connections > 80% pool (saturation)

---

### 13. No Capacity Planning for Data Growth

**Location**: Section 7.1 specifies user targets but no data volume planning

**Problem**: Design specifies 100K concurrent users and 10K unlocks/min but doesn't address:
- Expected data growth rate (achievements, statistics, leaderboards)
- Storage capacity planning
- Query performance degradation over time
- Data retention policies

Example calculations missing:
- 10K unlocks/min × 60 min × 24 hr = 14.4M unlocks/day
- player_achievements: 14.4M rows/day × 365 days = 5.25B rows/year
- player_statistics (if time-series): similar unbounded growth
- No archival or purging strategy

**Impact**:
- Database size grows unboundedly
- Query performance degrades as tables grow (even with indexes)
- Storage costs balloon
- Backups and maintenance windows grow proportionally
- No planning for when to shard or partition

**Why This Matters**: Data accumulation is inevitable. Without lifecycle management, performance degrades over time and operational costs escalate. Capacity planning identifies scaling thresholds (when to partition, when to archive) before emergency intervention is required.

**Recommendation**:
Implement data lifecycle management:

**1. Retention policies:**
- player_achievements: retain forever (core feature)
- player_statistics_history: 2 years detailed, 5 years aggregated
- API request logs: 90 days
- Error logs: 1 year

**2. Partitioning strategy (PostgreSQL 15 supports declarative partitioning):**
```sql
-- Partition player_achievements by unlock date
CREATE TABLE player_achievements (
    id UUID PRIMARY KEY,
    player_id UUID,
    achievement_id UUID,
    unlocked_at TIMESTAMP
) PARTITION BY RANGE (unlocked_at);

CREATE TABLE player_achievements_2024_01 PARTITION OF player_achievements
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
-- Create monthly partitions via automation
```

**3. Archival process:**
- Monthly job: move data older than retention to archive storage (S3)
- Maintain archive index for compliance queries
- Drop old partitions after archival

**4. Capacity monitoring:**
- Track table growth rates
- Project when storage will reach limits
- Alert when growth exceeds projections (anomaly detection)

**5. Growth projections:**
- Calculate expected row counts at 6mo, 1yr, 2yr
- Identify when to implement sharding (e.g., when player_achievements > 1B rows)
- Plan re-architecture triggers (when single-database design no longer viable)

---

## Summary and Prioritization

### Immediate Action Required (P0):
1. **Move leaderboard calculation async** - blocking bottleneck, system cannot scale
2. **Decouple synchronous operations** - achievement unlock must return immediately
3. **Add database indexes** - queries will fail at any meaningful load
4. **Implement pagination** - prevent unbounded result sets
5. **Add caching layer** - mandatory for read-heavy workload
6. **Fix N+1 queries** - dashboard will fail under concurrent load
7. **Add time windows to historical queries** - prevent unbounded data fetching

### High Priority (P1):
8. **Configure connection pooling** - required for database stability
9. **Implement WebSocket pub/sub** - notifications will fail in multi-server deployment
10. **Optimize regional leaderboards** - current design defeats purpose
11. **Batch statistics updates** - reduce write contention

### Medium Priority (P2):
12. **Add performance monitoring** - cannot validate system meets targets
13. **Implement data lifecycle management** - prevent long-term degradation

### Architectural Recommendations:

The system requires a **fundamental shift from synchronous to asynchronous processing**:

```
[Current - Synchronous]
Client → API → (validate + record + calculate + notify + update) → Response
         ↑_______________ All blocking _______________↑

[Recommended - Async]
Client → API → (validate + record) → Response ⚡ 50ms
                    ↓
               [RabbitMQ Queue]
                    ↓
    Worker Pool: calculate ranks, send notifications, update stats
```

**Technology additions recommended:**
- Redis: caching layer + real-time counters + WebSocket pub/sub
- Materialized views or scheduled aggregation jobs for leaderboards
- pgBouncer: connection pooling at database layer
- Celery workers: async task processing (already listed but underutilized)
- Prometheus + Grafana: metrics and monitoring
- Partitioning strategy: time-based for historical data

Without these changes, the system will fail to meet its stated scalability targets and will experience cascading failures under production load.
