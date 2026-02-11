# Performance Review: LiveStream Pro System Design

## Evaluation Summary

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 3/5 | Basic structures are reasonable, but lacks indexing strategy and query optimization details |
| I/O & Network Efficiency | 2/5 | Critical N+1 query patterns and batch processing issues not addressed |
| Caching Strategy | 2/5 | Limited caching design; only Redis for session/chat, missing critical read-heavy data caching |
| Memory & Resource Management | 3/5 | Basic resource management present, but lacks explicit connection pooling and lifecycle details |
| Data Lifecycle & Capacity Planning | 1/5 | **Critical deficiency**: Minimal data lifecycle strategy, no capacity projections for growing datasets |
| Latency, Throughput Design & Scalability | 2/5 | Auto-scaling mentioned but lacks performance SLAs, sharding strategy, and async processing details |

**Overall Assessment**: The design has significant performance gaps, particularly in data lifecycle management, I/O optimization, and scalability planning. Critical issues must be addressed before production deployment.

---

## Critical Issues (Priority 1)

### C1: No Long-term Data Growth Strategy for Time-Series Data

**Severity**: Critical
**Category**: Data Lifecycle & Capacity Planning

**Issue Description**:
The design document provides no comprehensive data lifecycle management for continuously growing datasets:

- **Archives table**: Stores metadata indefinitely with no purging strategy. As the platform scales to 100,000 monthly active users with 500 concurrent streams, archive metadata will grow unboundedly (estimated 15,000-50,000 new records monthly).
- **Streams table**: Retains all historical stream metadata "indefinitely" (section 7.3) with no archival or purging plan. With 500 concurrent streams and potentially thousands of streams daily, this table will become massive within months.
- **Follows table**: No consideration for inactive relationship cleanup. As user base grows, this table will expand without bounds.
- **Transactions table**: Payment records must be retained for legal/accounting purposes, but no strategy for moving old data to cheaper storage tiers.

**Current Mention**:
Section 7.3 only states:
- "配信メタデータ: 無期限保持" (Stream metadata: unlimited retention)
- "アーカイブ動画: S3 Standard (90日後にS3 Glacierに移行)" (Archive videos: S3 Standard → Glacier after 90 days)

This addresses S3 storage costs but ignores database table growth.

**Impact Analysis**:
1. **Query Performance Degradation**: Without partitioning or archival, queries on `streams` and `archives` tables will slow down linearly with data growth. Within 6-12 months, full table scans for user-specific queries will become prohibitively slow.
2. **Index Bloat**: Primary and foreign key indexes will grow significantly, increasing index maintenance overhead and slowing down insert operations.
3. **Backup/Restore Time**: Database backups will take increasingly longer, impacting RTO (Recovery Time Objective).
4. **Cost**: PostgreSQL RDS storage costs will scale linearly without tiering or purging.

**Capacity Projection Example**:
- 500 concurrent streams → assume 5,000 streams/day (average 2.88 hours each)
- 30 days: 150,000 new stream records
- 365 days: 1,825,000 records
- After 2 years: 3.65M records (with associated `archives` records)

At this scale, queries like `SELECT * FROM streams WHERE user_id = ? ORDER BY created_at DESC LIMIT 10` will require scanning millions of rows without proper index + partition strategy.

**Recommendations**:
1. **Define Retention Policies**:
   - **Hot Data** (0-90 days): Keep in primary PostgreSQL with full indexing
   - **Warm Data** (91-365 days): Move to separate partition or archive table with reduced indexing
   - **Cold Data** (>365 days): Move to S3-backed data warehouse (e.g., Redshift Spectrum, Athena) for compliance/analytics queries only

2. **Implement Table Partitioning**:
   - Partition `streams` and `archives` tables by `created_at` (monthly partitions recommended)
   - Use PostgreSQL declarative partitioning (available since PostgreSQL 10)
   - Set up automated partition creation script (monthly cron job)

3. **Archive/Purge Strategy**:
   - `streams` table: After 90 days, move to `streams_archive` table with compressed storage
   - `archives` table: After 365 days, move metadata to S3-backed storage (keep only archive_id, s3_key, created_at in PostgreSQL for lookups)
   - `follows` table: Purge relationships where both users are inactive for >2 years

4. **Capacity Monitoring**:
   - Implement CloudWatch metrics for table row counts and storage size
   - Set up alerts when tables exceed 80% of projected partition thresholds
   - Document expected growth rate in operations runbook

**References**:
- Section 7.3 (Data Retention Policy) - requires expansion
- Section 4.2 (Table Design) - missing partition strategy

---

### C2: Follower Notification Fan-Out Without Batching or Rate Limiting

**Severity**: Critical
**Category**: I/O & Network Efficiency

**Issue Description**:
Section 3.3 describes the stream start notification flow as "Notification Serviceがフォロワー全員に通知を送信" (Notification Service sends notifications to all followers). This design implies a synchronous fan-out pattern without batching, which will cause severe performance bottlenecks:

- A popular streamer with 10,000 followers would trigger 10,000 individual notification sends on every stream start.
- If notification delivery involves external API calls (email via SES, push notifications via FCM/APNs), each call adds 50-200ms latency.
- Total notification time: 10,000 × 100ms = 1,000 seconds (16+ minutes) if done sequentially.
- Even with parallelization (goroutines), this creates massive I/O contention and potential API rate limit violations.

**Current Design Gaps**:
- No mention of notification batching or queue-based processing
- No rate limiting for external API calls
- No async processing pattern for notification delivery
- No mention of message queue (SQS, RabbitMQ, etc.)

**Impact Analysis**:
1. **Stream Start Latency**: If notifications are sent synchronously before returning success to the streamer, stream start API will timeout (assuming 30s HTTP timeout).
2. **API Rate Limits**: External notification APIs (SES, FCM) typically have rate limits (e.g., SES: 14 emails/sec in sandbox). Fan-out bursts will hit rate limits immediately.
3. **Database Connection Pool Exhaustion**: Fetching 10,000 follower records in a single query and processing them in goroutines will exhaust database connections if not properly bounded.
4. **Cascading Failures**: If notification service crashes during fan-out, partial delivery with no retry mechanism leads to inconsistent user experience.

**Recommendations**:
1. **Implement Async Queue-Based Notification**:
   - Stream Manager publishes a single message to SQS/SNS: `{stream_id, user_id, event: "stream_started"}`
   - Separate Notification Worker service consumes queue messages
   - Worker fetches followers in batches (e.g., 1,000 at a time) and sends notifications asynchronously

2. **Batch Notification API Calls**:
   - Use SES SendBulkTemplatedEmail (up to 50 recipients per call)
   - Use FCM batch sending (up to 500 tokens per request)
   - Reduces API calls by 10-50x

3. **Rate Limiting & Circuit Breakers**:
   - Implement token bucket rate limiter for external API calls
   - Add circuit breaker pattern (e.g., using `go-resiliency/circuitbreaker`) to prevent cascading failures when notification APIs are down

4. **Follower Count-Based Strategy**:
   - For users with <100 followers: Send notifications immediately (low latency UX)
   - For users with >100 followers: Queue for batch processing (acceptable 1-2 minute delay)

5. **Add `sent_at` Timestamp to Notifications**:
   - Track notification delivery status to enable retries and delivery guarantees
   - Prevents duplicate sends on retry

**References**:
- Section 3.3 "配信開始フロー" (Stream Start Flow) - Step 5
- Section 3.2 "Notification Service" component

---

### C3: Missing Index Strategy for High-Frequency Queries

**Severity**: Critical
**Category**: Algorithm & Data Structure Efficiency

**Issue Description**:
The table design in section 4.2 defines primary keys and foreign keys but provides no index design for expected query patterns. Critical missing indexes include:

1. **streams table**:
   - `GET /api/streams` (list all live streams): Requires index on `status` column. Without it, full table scan on potentially millions of rows.
   - User's stream history (`GET /api/streams?user_id=X`): Requires composite index on `(user_id, created_at DESC)` for efficient pagination.

2. **archives table**:
   - `GET /api/archives?user_id=X`: Requires index on `user_id` (via `stream_id` join) + `created_at`. Without it, fetching a user's archive list involves full table scan.

3. **follows table**:
   - Follower list query: Requires index on `following_id` (currently only `follower_id` is likely indexed via FK).
   - Following list query: Requires index on `follower_id`.
   - Bi-directional lookups require composite indexes.

**Impact Analysis**:
- **Live Stream Discovery**: Without `status` index, the home page query to fetch all live streams will scan the entire `streams` table. At 1.8M records after 1 year, this query could take 5-10 seconds.
- **Archive Pagination**: User archive listing without proper indexing will cause O(n) scans, degrading to 1-2 second response times for users with 100+ past streams.
- **Follower Queries**: Fetching follower/following lists for popular users (10,000+ followers) will require full table scans, causing 10+ second query times.

**Query Performance Estimates** (without proper indexes, at 1 year scale):
| Query | Expected Rows Scanned | Estimated Latency | With Index |
|-------|----------------------|-------------------|-----------|
| List live streams | 1.8M (full table) | 5-10s | <100ms |
| User's stream history (pagination) | 1.8M (full table) | 3-5s | <50ms |
| User's followers list | 500K (half of follows table) | 2-4s | <100ms |

**Recommendations**:
1. **Add Critical Indexes**:
   ```sql
   -- streams table
   CREATE INDEX idx_streams_status ON streams(status) WHERE status = 'live';
   CREATE INDEX idx_streams_user_created ON streams(user_id, created_at DESC);

   -- archives table
   CREATE INDEX idx_archives_stream_created ON archives(stream_id, created_at DESC);

   -- follows table
   CREATE INDEX idx_follows_following ON follows(following_id, created_at DESC);
   CREATE INDEX idx_follows_follower ON follows(follower_id, created_at DESC);
   ```

2. **Add Composite Index for Joins**:
   - For queries joining `streams` and `archives`: Consider composite index on `streams.stream_id` + `streams.user_id`

3. **Partial Indexes for Status Queries**:
   - Use `WHERE status = 'live'` clause in index creation to reduce index size (only 500 concurrent live streams need fast lookup)

4. **Document Index Maintenance**:
   - Monitor index bloat with `pg_stat_user_indexes`
   - Schedule periodic `REINDEX` operations during low-traffic hours

**References**:
- Section 4.2 (Table Design)
- Section 5.1 (API Endpoints) - query patterns

---

## Significant Issues (Priority 2)

### S1: No Caching Strategy for Read-Heavy Data

**Severity**: High
**Category**: Caching Strategy

**Issue Description**:
Redis is only used for session management and temporary chat storage (section 2.2). Critical read-heavy data paths have no caching layer:

1. **User Profile Cache**: `GET /api/users/{user_id}` is called on every page load and every API request (for JWT validation). Without caching, this hits PostgreSQL on every request.
2. **Stream Metadata Cache**: Live stream metadata (title, viewer count, streamer info) is fetched repeatedly by thousands of viewers. No caching means database reads scale linearly with viewer count.
3. **Follower Count Cache**: Popular user profiles display follower counts. Each profile view requires `COUNT(*)` query on `follows` table without caching.
4. **Archive List Cache**: User archive listings are read-heavy (viewers browsing past streams). No mention of caching this data.

**Impact Analysis**:
- **Database Load**: With 50,000 concurrent viewers and average 10 API calls/minute per viewer, this generates 8,333 requests/second. If 30% require user profile lookups, that's 2,500 PostgreSQL reads/second.
- **Read Replica Saturation**: Even with RDS read replicas, this query rate will saturate connection pools (default max_connections: 100-200).
- **Response Latency**: Cold database reads add 10-50ms per request. With multiple uncached reads per API call, total latency increases by 50-200ms.

**Current Redis Usage**:
- Session management (good)
- Chat messages (5 min TTL) (appropriate for temporary data)
- Stream state (mentioned in section 3.3, step 4)

**Missing Caching**:
- User profiles
- Stream metadata (title, thumbnail, streamer info)
- Follower/following counts
- Archive lists

**Recommendations**:
1. **Add User Profile Cache**:
   - Cache key: `user:{user_id}`
   - TTL: 5 minutes (balance between freshness and DB load)
   - Invalidation: On user profile update

2. **Cache Stream Metadata**:
   - Cache key: `stream:{stream_id}:metadata`
   - TTL: 30 seconds (to reflect viewer count updates)
   - Store: stream title, streamer info, current viewer count

3. **Cache Aggregate Counts**:
   - Cache key: `user:{user_id}:follower_count`
   - TTL: 10 minutes (tolerable staleness for counts)
   - Invalidation: On follow/unfollow (increment/decrement cached value)

4. **Cache Archive Listings**:
   - Cache key: `user:{user_id}:archives`
   - TTL: 1 hour (archive data rarely changes)
   - Invalidation: On new archive creation

5. **Implement Cache-Aside Pattern**:
   ```go
   func GetUserProfile(userID string) (*User, error) {
       // Try cache first
       cached, err := redis.Get(ctx, "user:" + userID).Result()
       if err == nil {
           return unmarshal(cached), nil
       }

       // Cache miss: fetch from DB
       user, err := db.GetUser(userID)
       if err != nil {
           return nil, err
       }

       // Store in cache
       redis.Set(ctx, "user:" + userID, marshal(user), 5*time.Minute)
       return user, nil
   }
   ```

**References**:
- Section 2.2 (Database) - Redis usage
- Section 3.2 (Components) - API Gateway, Stream Manager

---

### S2: Viewer Count Management Lacks Atomic Operations and Race Condition Handling

**Severity**: High
**Category**: Memory & Resource Management / Algorithm Efficiency

**Issue Description**:
Section 3.3 describes viewer count as "視聴者数カウントをRedisでインクリメント" (increment viewer count in Redis). However, the design does not specify:

1. **Atomic increment operations**: If using `GET` + increment + `SET` pattern, race conditions will cause inaccurate counts.
2. **Decrement on disconnect**: No mention of how viewer count is decremented when WebSocket disconnects occur.
3. **Sync with PostgreSQL**: The `streams` table has `viewer_count` column. No strategy for syncing Redis counts with PostgreSQL.
4. **Timeout handling**: If a viewer's connection drops without clean disconnect, the count will remain inflated.

**Impact Analysis**:
- **Inaccurate Viewer Counts**: Race conditions during concurrent viewer joins/leaves will cause counts to drift from reality. For popular streams with 5,000+ viewers and frequent joins/leaves, drift can reach 10-20% error rate.
- **Stale Database Counts**: If PostgreSQL `streams.viewer_count` is only updated at stream end, real-time metrics dashboards and analytics will be inaccurate.
- **Memory Leaks**: Without timeout-based cleanup, disconnected WebSocket sessions will leave stale viewer count entries in Redis.

**Recommendations**:
1. **Use Redis Atomic Commands**:
   ```go
   // Increment on viewer join
   redis.Incr(ctx, "stream:" + streamID + ":viewers")

   // Decrement on viewer leave
   redis.Decr(ctx, "stream:" + streamID + ":viewers")
   ```

2. **Implement WebSocket Heartbeat**:
   - Send ping every 30 seconds
   - If no pong received within 45 seconds, consider connection dead and decrement count

3. **Periodic PostgreSQL Sync**:
   - Every 60 seconds, sync Redis viewer count to `streams.viewer_count` column
   - Use background goroutine to batch-update all active streams

4. **Use Redis Sorted Set for Timeout Cleanup**:
   ```go
   // On viewer join, add to sorted set with current timestamp
   redis.ZAdd(ctx, "stream:" + streamID + ":viewers_set", &redis.Z{
       Score: float64(time.Now().Unix()),
       Member: viewerID,
   })

   // Periodic cleanup: remove entries older than 2 minutes
   cutoff := time.Now().Add(-2 * time.Minute).Unix()
   redis.ZRemRangeByScore(ctx, "stream:" + streamID + ":viewers_set", "-inf", strconv.FormatInt(cutoff, 10))

   // Get accurate count
   count, _ := redis.ZCard(ctx, "stream:" + streamID + ":viewers_set").Result()
   ```

**References**:
- Section 3.3 "視聴者参加フロー" - Step 4
- Section 4.2 `streams` table - `viewer_count` column

---

### S3: No Database Connection Pooling Configuration Specified

**Severity**: High
**Category**: Memory & Resource Management

**Issue Description**:
The design mentions PostgreSQL and Redis but provides no details on connection pool sizing, timeout configuration, or connection lifecycle management. At the expected scale (50,000 concurrent viewers, 500 concurrent streams), improper connection pooling will cause:

1. **Connection exhaustion**: Default PostgreSQL `max_connections` is 100. If each API request holds a connection for 200ms and QPS is 2,000, you need at least 400 connections (2,000 × 0.2 = 400).
2. **Connection leak**: Without proper connection release, long-running transactions or forgotten connections will exhaust the pool.
3. **Thundering herd**: If all ECS tasks reconnect simultaneously after a database failover, connection storms will overload the database.

**Expected Load**:
- 50,000 concurrent viewers
- Each viewer generates ~10 API calls/minute = 8,333 requests/second
- Average query time: 50ms
- Required connections: 8,333 × 0.05 = ~417 connections

**Recommendations**:
1. **Configure PostgreSQL Connection Pool (pgxpool)**:
   ```go
   config, _ := pgxpool.ParseConfig("postgres://...")
   config.MaxConns = 50              // Max connections per ECS task
   config.MinConns = 10              // Keep-alive connections
   config.MaxConnLifetime = 1 * time.Hour
   config.MaxConnIdleTime = 5 * time.Minute
   config.HealthCheckPeriod = 1 * time.Minute
   pool, _ := pgxpool.NewWithConfig(context.Background(), config)
   ```

2. **Scale Connection Pool with ECS Tasks**:
   - 10 ECS tasks × 50 connections/task = 500 total connections
   - Increase RDS `max_connections` parameter to 600 (20% headroom)

3. **Configure Redis Connection Pool**:
   ```go
   redis.NewClient(&redis.Options{
       PoolSize:     50,    // Max connections per ECS task
       MinIdleConns: 10,    // Pre-warmed connections
       MaxRetries:   3,     // Retry on network errors
       DialTimeout:  5 * time.Second,
       ReadTimeout:  3 * time.Second,
       WriteTimeout: 3 * time.Second,
   })
   ```

4. **Implement Connection Pool Monitoring**:
   - Expose Prometheus metrics: `db_connections_active`, `db_connections_idle`, `db_connection_wait_duration`
   - Alert when `db_connections_active / MaxConns > 0.8`

**References**:
- Section 2.2 (Database)
- Section 1.3 (Target Scale) - 50,000 concurrent viewers

---

## Moderate Issues (Priority 3)

### M1: No Async Processing for Archive Video Transcoding

**Severity**: Medium
**Category**: Latency, Throughput Design & Scalability

**Issue Description**:
Section 3.2 mentions "Archive Service: 配信終了後の録画ファイル処理とS3保存" (processes recording files and saves to S3 after stream ends). However, the design does not specify whether FFmpeg transcoding runs synchronously or asynchronously.

If transcoding is synchronous:
- A 2-hour stream produces a ~4GB raw video file.
- FFmpeg transcoding to multiple quality levels (1080p, 720p, 480p) takes 30-60 minutes on a single CPU core.
- During transcoding, the Archive Service process is blocked, preventing other streams from being archived.

**Impact Analysis**:
- **Archive Backlog**: With 500 concurrent streams, if even 10% end simultaneously (50 streams), a single Archive Service instance will take 25-50 hours to process all archives sequentially.
- **Resource Contention**: FFmpeg is CPU-intensive. Running multiple transcodes on the same ECS task will cause CPU throttling and OOM kills.

**Recommendations**:
1. **Implement Async Queue-Based Transcoding**:
   - Stream Manager publishes archive request to SQS on stream end
   - Separate Archive Worker service (ECS Fargate Spot instances) consumes queue
   - Each worker processes one transcode job at a time

2. **Use AWS MediaConvert**:
   - Managed transcoding service with auto-scaling
   - Eliminates need for FFmpeg infrastructure management
   - Pay-per-minute pricing aligns with usage

3. **Prioritize Transcoding**:
   - High-priority: Streams with >1,000 viewers (process within 10 minutes)
   - Low-priority: Streams with <100 viewers (process within 2 hours)

**References**:
- Section 3.2 "Archive Service"
- Section 2.4 "FFmpeg"

---

### M2: Missing Performance SLA and Monitoring Strategy

**Severity**: Medium
**Category**: Latency, Throughput Design & Scalability

**Issue Description**:
Section 7 defines security and availability requirements but provides no performance SLA (Service Level Agreement) or monitoring strategy. Critical missing elements:

1. **No Response Time Targets**: What is the acceptable latency for API endpoints? (e.g., p95 < 500ms)
2. **No Throughput Requirements**: What is the expected QPS per endpoint?
3. **No Monitoring Metrics**: Which performance metrics will be tracked? (latency percentiles, error rate, database query time)
4. **No Alerting Thresholds**: When should the operations team be alerted about performance degradation?

**Impact Analysis**:
- **Undetected Performance Regression**: Without defined SLAs, gradual performance degradation will go unnoticed until user complaints arise.
- **No Capacity Planning Baseline**: Without throughput metrics, it's impossible to predict when to scale infrastructure.
- **Slow Incident Response**: Without alerting, outages or slowdowns will only be discovered through manual checks or user reports.

**Recommendations**:
1. **Define Performance SLAs**:
   - API Response Time: p50 < 200ms, p95 < 500ms, p99 < 1s
   - Stream Start Latency: < 3 seconds (from API call to stream URL returned)
   - Chat Message Delivery: < 500ms (from send to broadcast)
   - Archive Processing: < 2 hours for 95% of streams

2. **Implement Distributed Tracing**:
   - Use AWS X-Ray or OpenTelemetry to trace request flows
   - Identify slow database queries, external API calls, and service bottlenecks

3. **Add CloudWatch Metrics**:
   - API latency (per endpoint, per status code)
   - Database query time (per table, per query type)
   - WebSocket connection count, message rate
   - Redis cache hit/miss rate

4. **Configure CloudWatch Alarms**:
   - Alert: API p95 latency > 500ms for 2 consecutive minutes
   - Alert: Database CPU > 80% for 5 minutes
   - Alert: ECS task CPU > 90% for 3 minutes
   - Alert: Redis memory usage > 85%

**References**:
- Section 7 (Non-Functional Requirements)
- Section 6.2 (Logging Policy)

---

### M3: No Sharding or Read Replica Strategy for Database Scalability

**Severity**: Medium
**Category**: Latency, Throughput Design & Scalability

**Issue Description**:
Section 7.2 mentions "RDS Multi-AZ構成" (RDS Multi-AZ configuration) for availability, but this only provides failover capability, not read scalability. At the target scale (100,000 monthly active users, 50,000 concurrent viewers), a single PostgreSQL instance will struggle with read load:

- Expected read QPS: 6,000-8,000 (viewer profile lookups, stream metadata fetches)
- Expected write QPS: 500-1,000 (stream starts/ends, user actions)
- Single RDS instance limit: ~5,000 QPS (depending on instance size)

**Impact Analysis**:
- **Read Bottleneck**: Without read replicas, all read queries compete with write transactions for database resources, increasing latency.
- **Write Contention**: High write volume on `follows`, `streams`, and `transactions` tables will cause row-level lock contention.
- **No Geographic Distribution**: All database traffic routes to a single AWS region, increasing latency for international users.

**Recommendations**:
1. **Implement Read Replicas**:
   - Deploy 2-3 RDS read replicas in the same region
   - Route read-only queries (`SELECT`) to replicas using pgx connection pools
   - Route write queries (`INSERT`, `UPDATE`, `DELETE`) to primary instance

2. **Use Read/Write Query Splitting**:
   ```go
   type DBCluster struct {
       primary *pgxpool.Pool
       replicas []*pgxpool.Pool
       replicaIdx int
   }

   func (c *DBCluster) QueryReplica(ctx context.Context, query string) (*pgx.Rows, error) {
       replica := c.replicas[c.replicaIdx % len(c.replicas)]
       c.replicaIdx++
       return replica.Query(ctx, query)
   }

   func (c *DBCluster) ExecPrimary(ctx context.Context, query string) error {
       _, err := c.primary.Exec(ctx, query)
       return err
   }
   ```

3. **Consider Future Sharding Strategy**:
   - If user base exceeds 1M users, shard `users`, `follows`, and `streams` tables by `user_id` hash
   - Use Vitess or Citus for transparent sharding

4. **Add Database Proxy (PgBouncer)**:
   - Deploy PgBouncer in transaction pooling mode to reduce connection overhead
   - Enables 10x more concurrent connections without increasing RDS connections

**References**:
- Section 7.2 (Availability & Scalability)
- Section 1.3 (Target Scale)

---

## Minor Improvements (Priority 4)

### I1: Consider WebSocket Connection Pooling and Message Batching

**Severity**: Low
**Category**: Network Efficiency

**Issue Description**:
Chat messages are sent individually over WebSocket (section 3.3, step 4). For active chat streams with 100+ messages/second, this creates significant overhead:

- Each message requires separate broadcast to all viewers (N broadcasts per message)
- Small message payloads (50-200 bytes) suffer from TCP overhead
- No mention of message compression (gzip, zstd)

**Recommendations**:
- Batch chat messages every 100ms before broadcasting (reduces broadcasts by 10x)
- Enable WebSocket compression (`permessage-deflate` extension)
- For large streams (>5,000 viewers), use Redis Pub/Sub for message fan-out instead of in-process broadcasting

**References**:
- Section 3.3 "チャット送信フロー"

---

### I2: Add Database Query Timeout Configuration

**Severity**: Low
**Category**: Resource Management

**Issue Description**:
No mention of database query timeout settings. Long-running queries (e.g., accidental full table scans) will block connection pool threads indefinitely.

**Recommendations**:
- Set `statement_timeout = 10s` in PostgreSQL configuration
- Add query context timeout in Go: `ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)`

**References**:
- Section 6.1 (Error Handling Policy)

---

## Positive Aspects

1. **Appropriate Redis Usage**: Using Redis for session management and temporary chat storage is a good design choice for ephemeral data.
2. **S3 Lifecycle Policy**: The plan to move archives from S3 Standard to Glacier after 90 days shows awareness of storage cost optimization.
3. **Multi-AZ RDS**: Using Multi-AZ for database availability is appropriate for the target reliability requirements.
4. **JWT Authentication**: Stateless JWT authentication aligns well with horizontal scaling requirements.

---

## Summary

The LiveStream Pro design has several critical performance deficiencies that must be addressed:

**Must-Fix Before Production**:
1. **Data Lifecycle Management**: Add partitioning, archival, and purging strategies for time-series data (streams, archives, follows tables)
2. **Notification Fan-Out**: Implement async queue-based notification with batching to handle popular streamer followers
3. **Index Strategy**: Define and implement critical indexes for high-frequency queries
4. **Caching Layer**: Add Redis caching for read-heavy data (user profiles, stream metadata, counts)

**High-Priority Improvements**:
5. **Connection Pooling**: Configure and document connection pool settings for PostgreSQL and Redis
6. **Viewer Count Management**: Use atomic Redis operations with timeout-based cleanup
7. **Async Archive Processing**: Implement queue-based transcoding workflow

**Recommended Enhancements**:
8. **Performance SLA**: Define response time targets and monitoring strategy
9. **Read Replicas**: Scale database reads with read replicas and query routing
10. **Async Processing**: Use message queues (SQS) for background jobs (notifications, transcoding)

Addressing these issues will significantly improve the system's scalability, reliability, and performance at the target scale of 50,000 concurrent viewers and 100,000 monthly active users.
