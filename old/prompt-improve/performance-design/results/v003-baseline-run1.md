# Performance Design Review: LiveStream Pro System

## Overall Performance Assessment

| Criterion | Score | Justification |
|-----------|-------|---------------|
| Algorithm & Data Structure Efficiency | 2/5 | Multiple inefficient patterns: linear scan for follower notifications, lack of indexing strategy, no pagination design |
| I/O & Network Efficiency | 2/5 | Critical N+1 problem in notification flow, lack of batch processing, no connection pooling design |
| Caching Strategy | 2/5 | Minimal caching design, viewer count read pattern not optimized, no CDN strategy for metadata |
| Memory & Resource Management | 2/5 | No connection pool sizing, WebSocket connection limits undefined, FFmpeg process management unclear |
| Latency, Throughput Design & Scalability | 2/5 | Missing capacity planning, no performance SLA, insufficient scalability design, monitoring strategy absent |

**Overall Risk Level: HIGH** - Multiple critical performance bottlenecks that will severely impact system scalability and user experience under expected load.

---

## Critical Issues (P1)

### C1. Follower Notification N+1 Query Problem
**Severity: Critical | Impact: High Latency, Database Overload**

**Location**: Section 3.3 - 配信開始フロー, Step 5

**Issue Description**:
The notification flow "Notification Serviceがフォロワー全員に通知を送信" implies a linear iteration over all followers. With popular streamers having thousands of followers, this creates an N+1 query problem:
1. Query to fetch all follower IDs for a given streamer
2. N individual queries or API calls to send notifications to each follower

**Impact Analysis**:
- For a streamer with 10,000 followers, this could generate 10,000+ database queries or notification API calls
- Stream start latency could exceed 10-30 seconds under load
- Database connection pool exhaustion risk
- Cascading failures when multiple popular streamers start simultaneously

**Recommendation**:
1. Implement batch notification processing:
   - Queue notification jobs to a message queue (SQS/RabbitMQ)
   - Process notifications asynchronously in batches of 100-500
   - Use batch API endpoints if the notification provider supports them
2. Add rate limiting to prevent notification storms
3. Consider notification fanout patterns with pub/sub architecture

**NFR Gap**: Missing capacity planning for notification throughput, no SLA for notification delivery time

---

### C2. Missing Database Indexing Strategy
**Severity: Critical | Impact: Query Performance Degradation**

**Location**: Section 4.2 - テーブル設計

**Issue Description**:
No index definitions beyond primary keys. Critical queries will perform full table scans:
- **streams table**: No index on `user_id` (配信者の配信一覧取得)
- **streams table**: No index on `status` (進行中配信一覧)
- **follows table**: No compound index on `follower_id` or `following_id` (フォロワー一覧取得)
- **archives table**: No index on `stream_id` (配信のアーカイブ取得)

**Impact Analysis**:
- Query latency will grow linearly with data volume (O(n) instead of O(log n))
- At 100,000 users with 500 concurrent streams, `GET /api/streams` (進行中配信一覧) could take 500ms-2s
- Follow/follower queries will become unusably slow for popular streamers (10,000+ followers)

**Recommendation**:
1. Add critical indexes:
   ```sql
   CREATE INDEX idx_streams_user_id ON streams(user_id);
   CREATE INDEX idx_streams_status ON streams(status);
   CREATE INDEX idx_streams_started_at ON streams(started_at DESC);
   CREATE INDEX idx_follows_follower ON follows(follower_id);
   CREATE INDEX idx_follows_following ON follows(following_id);
   CREATE INDEX idx_archives_stream_id ON archives(stream_id);
   ```
2. Add compound indexes for common query patterns:
   ```sql
   CREATE INDEX idx_streams_status_started ON streams(status, started_at DESC);
   ```
3. Monitor index usage and query performance with PostgreSQL `pg_stat_statements`

**NFR Gap**: No database scalability planning, missing index optimization strategy

---

### C3. Missing Pagination Design
**Severity: Critical | Impact: Memory Exhaustion, Poor UX**

**Location**: Section 5.1 - API設計

**Issue Description**:
All list endpoints (`GET /api/streams`, `GET /api/archives`, `GET /api/users/{user_id}/followers`, `GET /api/users/{user_id}/following`) lack pagination parameters. Endpoints will return unbounded result sets.

**Impact Analysis**:
- A popular streamer's `/followers` endpoint could return 100,000+ records (100MB+ response)
- Frontend rendering freezes with large datasets
- API server memory exhaustion when handling concurrent requests
- Network bandwidth waste for mobile users

**Recommendation**:
1. Implement cursor-based pagination for all list endpoints:
   ```
   GET /api/streams?limit=20&cursor=<last_stream_id>
   ```
2. Enforce maximum page size (e.g., `limit` max = 100)
3. Add response metadata:
   ```json
   {
     "data": [...],
     "pagination": {
       "next_cursor": "uuid-here",
       "has_more": true
     }
   }
   ```
4. Use efficient pagination queries:
   ```sql
   SELECT * FROM streams WHERE stream_id > $cursor ORDER BY stream_id LIMIT $limit;
   ```

**NFR Gap**: No API response size limits defined, missing pagination standards

---

### C4. Undefined Connection Pool Limits
**Severity: Critical | Impact: Resource Exhaustion**

**Location**: Section 2.2, 2.4 - データベース設計

**Issue Description**:
No connection pool configuration specified for PostgreSQL or Redis. Default pool sizes are often insufficient for production workloads.

**Impact Analysis**:
- PostgreSQL default max connections = 100, but with 50,000 concurrent viewers + API requests, connection exhaustion is inevitable
- ECS autoscaling to 10+ tasks without pool limits → 1000+ connections → database crash
- Redis connection exhaustion → chat service failures

**Recommendation**:
1. Define connection pool configuration:
   ```go
   // PostgreSQL pool sizing
   db.SetMaxOpenConns(25)      // Per ECS task
   db.SetMaxIdleConns(5)
   db.SetConnMaxLifetime(5 * time.Minute)

   // Redis pool sizing
   redis.PoolSize = 20         // Per ECS task
   redis.MinIdleConns = 5
   ```
2. Calculate pool sizing based on capacity planning:
   - Max ECS tasks × connections per task < PostgreSQL max_connections (300-500)
   - Account for connection overhead from admin tools, monitoring
3. Implement connection monitoring and alerts

**NFR Gap**: Missing resource limit definitions, no connection pool sizing strategy

---

### C5. Missing Performance SLA and Monitoring Strategy
**Severity: Critical | Impact: No Performance Observability**

**Location**: Section 7.2 - 可用性・スケーラビリティ

**Issue Description**:
No performance SLA defined (response time, throughput targets). Monitoring strategy only mentions generic CloudWatch Logs without performance metrics collection.

**Impact Analysis**:
- No objective criteria to detect performance degradation
- Cannot validate if system meets user expectations (e.g., stream start latency < 2s)
- No proactive alerting before user-facing performance issues
- Cannot measure impact of optimizations

**Recommendation**:
1. Define performance SLA targets:
   ```
   - API response time: p95 < 200ms, p99 < 500ms
   - Stream start latency: p95 < 3s
   - Chat message delivery: p95 < 100ms
   - Throughput: 500 concurrent streams, 50,000 viewers
   ```
2. Implement comprehensive monitoring:
   - **Metrics**: API latency (p50/p95/p99), error rate, throughput (req/sec)
   - **Database**: Query latency, connection pool usage, slow query log
   - **Redis**: Hit/miss ratio, memory usage, eviction count
   - **Infrastructure**: CPU/memory/network per ECS task
3. Set up alerting:
   - Alert when p95 latency > SLA threshold
   - Alert when database connection pool > 80% utilization
   - Alert when Redis memory > 80%
4. Consider distributed tracing (AWS X-Ray, OpenTelemetry) for request flow visibility

**NFR Gap**: Performance SLA undefined, monitoring strategy incomplete, no distributed tracing

---

## Significant Issues (P2)

### S1. WebSocket Connection Limits Undefined
**Severity: Significant | Impact: Scalability Bottleneck**

**Location**: Section 3.2 - Chat Service

**Issue Description**:
No specification of WebSocket connection limits per ECS task or scaling policy. With 50,000 concurrent viewers, WebSocket connection management becomes critical.

**Impact Analysis**:
- Default Go WebSocket limits (gorilla/websocket) may not handle 10,000+ connections per task
- Memory consumption: ~10KB per WebSocket connection → 50,000 connections = 500MB+ per task
- ECS task memory limits (512MB-2GB) could be exhausted
- No plan for WebSocket load balancing across tasks

**Recommendation**:
1. Define WebSocket connection limits per ECS task:
   - Max connections per task: 5,000-10,000 (based on memory limits)
   - Configure ALB/NLB with WebSocket sticky sessions
2. Implement connection limit monitoring and graceful rejection:
   ```go
   if activeConnections >= maxConnectionsPerTask {
       return http.StatusServiceUnavailable
   }
   ```
3. Horizontal scaling strategy for Chat Service:
   - Scale ECS tasks based on active WebSocket connection count
   - Use Redis pub/sub for cross-task message broadcasting
4. Consider dedicated WebSocket gateway (Socket.io clusters, AWS API Gateway WebSocket)

---

### S2. Redis Memory Eviction Strategy Undefined
**Severity: Significant | Impact: Data Loss, Performance Degradation**

**Location**: Section 2.2 - Redis 7.0

**Issue Description**:
Redis is used for session management, stream state, and chat messages without defining eviction policy or memory limits.

**Impact Analysis**:
- Default eviction policy (`noeviction`) → Redis refuses new writes when memory full → service outages
- Chat messages with 5-minute TTL could consume unbounded memory during traffic spikes
- 50,000 concurrent viewers × session data → potential memory exhaustion

**Recommendation**:
1. Define Redis eviction policy:
   - Session/stream state: `allkeys-lru` (evict least recently used)
   - Chat messages: `volatile-ttl` (evict keys with TTL first)
2. Set memory limits per use case:
   - Session cache: 2GB
   - Stream state: 1GB
   - Chat messages: 4GB (with TTL)
3. Monitor Redis memory usage and eviction count
4. Consider separate Redis instances for different use cases (session vs. chat)

---

### S3. Stream Metadata Read N+1 Problem
**Severity: Significant | Impact: High Latency for List Views**

**Location**: Section 5.1 - `GET /api/streams` (配信一覧取得)

**Issue Description**:
Stream list endpoint likely requires join with `users` table to display streamer information (username, avatar). Without explicit join design, this becomes an N+1 query:
1. Fetch all streams
2. For each stream, fetch user information by `user_id`

**Impact Analysis**:
- 100 streams per page × 2 queries (stream + user) = 200 queries
- API latency: 500ms-2s for list view
- Database connection pool exhaustion under high traffic

**Recommendation**:
1. Use SQL JOIN to fetch stream and user data in a single query:
   ```sql
   SELECT s.*, u.username, u.avatar_url
   FROM streams s
   JOIN users u ON s.user_id = u.user_id
   WHERE s.status = 'live'
   ORDER BY s.started_at DESC
   LIMIT 20;
   ```
2. Cache stream list in Redis for 30-60 seconds to reduce database load
3. Implement materialized view or denormalization for hot paths

---

### S4. Viewer Count Synchronization Bottleneck
**Severity: Significant | Impact: Contention, Latency**

**Location**: Section 3.3 - 視聴者参加フロー, Step 4

**Issue Description**:
"視聴者数カウントをRedisでインクリメント" → Every viewer join/leave triggers a Redis write operation. For popular streams with thousands of concurrent viewers joining/leaving, this creates a single-key hotspot.

**Impact Analysis**:
- Redis single-key write throughput limit: ~100,000 ops/sec, but with network latency, effective throughput is lower
- For viral streams with 1,000 viewers joining per second, Redis could become a bottleneck
- Viewer count lag or inconsistency during traffic spikes

**Recommendation**:
1. Use Redis HyperLogLog for approximate viewer count (trades precision for performance):
   ```
   PFADD stream:{stream_id}:viewers {user_id}
   PFCOUNT stream:{stream_id}:viewers
   ```
2. Batch viewer count updates (aggregate 100 joins/leaves before incrementing)
3. Implement client-side buffering to reduce Redis write frequency
4. Consider eventual consistency model (update count every 5-10 seconds instead of real-time)

---

### S5. No Archive Transcoding Queue Design
**Severity: Significant | Impact: Resource Contention**

**Location**: Section 3.2 - Archive Service, Section 2.4 - FFmpeg

**Issue Description**:
Archive Service uses FFmpeg for transcoding without specifying async job queue or resource limits. FFmpeg is CPU/memory intensive and blocking.

**Impact Analysis**:
- Synchronous FFmpeg transcoding blocks API responses → stream end latency increases
- Multiple concurrent transcoding jobs (10+ streams ending simultaneously) → CPU exhaustion
- ECS task CPU limits → transcoding failures or very slow processing
- No retry mechanism for failed transcoding

**Recommendation**:
1. Implement async transcoding with job queue:
   - Push transcoding jobs to SQS
   - Dedicated worker fleet (separate ECS tasks) for transcoding
   - Decouple API latency from transcoding time
2. Set FFmpeg resource limits:
   ```bash
   ffmpeg -i input.mp4 -threads 2 -preset fast output.mp4
   ```
3. Implement job retry logic with exponential backoff
4. Consider AWS MediaConvert or Elastic Transcoder for managed transcoding

**NFR Gap**: No resource management strategy for CPU-intensive tasks

---

### S6. Missing Database Read/Write Separation
**Severity: Significant | Impact: Scalability Limitation**

**Location**: Section 2.2 - PostgreSQL 15, Section 7.2 - RDS Multi-AZ

**Issue Description**:
Design uses single PostgreSQL primary instance for all read/write operations. No read replicas mentioned. With 50,000 concurrent viewers, read traffic (stream metadata, user profiles, archives) will overwhelm the primary.

**Impact Analysis**:
- Read queries compete with write queries for primary database resources
- Viewer-facing queries (stream list, user profile) slow down during write-heavy periods (stream starts, transactions)
- Vertical scaling limits (RDS instance size maxes out)

**Recommendation**:
1. Set up RDS read replicas:
   - 2-3 read replicas for read-heavy traffic
   - Route read queries (GET endpoints) to replicas
   - Route write queries (POST/PUT/DELETE) to primary
2. Implement database connection routing:
   ```go
   // Read-only queries → replica
   db.Replica().Find(&streams)

   // Write queries → primary
   db.Primary().Create(&stream)
   ```
3. Monitor replication lag and alert if > 1 second
4. Consider Amazon Aurora for auto-scaling read replicas

---

## Moderate Issues (P3)

### M1. No API Rate Limiting
**Severity: Moderate | Impact: Abuse, Resource Exhaustion**

**Issue Description**: No rate limiting mentioned for API endpoints. Vulnerable to abuse (spam, DDoS).

**Recommendation**:
1. Implement rate limiting per user:
   - 100 requests/minute for authenticated users
   - 20 requests/minute for unauthenticated users
2. Use Redis-based rate limiter or AWS API Gateway throttling
3. Return `429 Too Many Requests` with `Retry-After` header

---

### M2. JWT Token Expiration Too Long
**Severity: Moderate | Impact: Security vs. Performance Trade-off**

**Issue Description**: 24-hour JWT expiration (Section 5.3) is long. If token is stolen, attacker has 24 hours of access. However, shorter expiration requires more frequent token refresh → increased API traffic.

**Recommendation**:
1. Reduce access token expiration to 1 hour
2. Implement refresh token mechanism (7-day expiration)
3. Cache user session in Redis to avoid database lookups on every request

---

### M3. Missing Timeout Configurations
**Severity: Moderate | Impact: Cascading Failures**

**Issue Description**: No timeout configurations for external API calls (Stripe, Ant Media Server) or database queries.

**Recommendation**:
1. Set timeouts for all external dependencies:
   - HTTP client timeout: 5-10 seconds
   - Database query timeout: 3 seconds
   - WebSocket ping timeout: 30 seconds
2. Implement circuit breaker pattern for Stripe API
3. Add timeout monitoring and alerts

---

### M4. No Caching for User Profile Data
**Severity: Moderate | Impact: Database Load**

**Issue Description**: User profile data (username, avatar) is likely fetched repeatedly for stream lists, chat messages, etc. No caching strategy mentioned.

**Recommendation**:
1. Cache user profile data in Redis:
   - Key: `user:{user_id}`
   - TTL: 1 hour
   - Invalidate on user profile update
2. Use cache-aside pattern with fallback to database
3. Monitor cache hit ratio (target > 80%)

---

### M5. CloudFront CDN Underutilized
**Severity: Moderate | Impact: Missed Optimization Opportunity**

**Issue Description**: CloudFront is only mentioned for video delivery. Could also cache API responses (stream lists, user profiles).

**Recommendation**:
1. Cache read-only API responses in CloudFront:
   - `GET /api/streams` (公開配信一覧): 30-second cache
   - `GET /api/users/{user_id}` (公開プロフィール): 5-minute cache
2. Use `Cache-Control` headers to control CDN behavior
3. Invalidate cache on data updates via CloudFront invalidation API

---

## Minor Issues (P4)

### I1. No Horizontal Scaling Policy Details
**Issue**: Section 7.2 mentions CPU/memory-based autoscaling but lacks specifics (target utilization %, min/max tasks, scale-up/down cooldown).

**Recommendation**: Define autoscaling policy:
- Target CPU: 70%, Memory: 80%
- Min tasks: 2, Max tasks: 20
- Scale-up cooldown: 60s, Scale-down cooldown: 300s

---

### I2. S3 Glacier Migration Policy Unclear
**Issue**: Section 7.3 mentions 90-day S3 Glacier migration but doesn't specify retrieval strategy for old archives.

**Recommendation**: Clarify archive retrieval:
- Use S3 Intelligent-Tiering instead of manual Glacier migration
- Document Glacier retrieval SLA (3-5 hours) for old archive access

---

## Positive Aspects

1. **Good Technology Choices**: Go for backend (high concurrency), PostgreSQL (ACID compliance), Redis (fast cache)
2. **Separation of Concerns**: Clear service boundaries (Stream Manager, Chat Service, Archive Service)
3. **Multi-AZ Database**: RDS Multi-AZ provides high availability
4. **JWT Authentication**: Stateless authentication reduces database load
5. **Managed Services**: Stripe API for payments (PCI DSS compliance), Ant Media Server for WebRTC

---

## Summary of NFR & Scalability Gaps

The following critical NFR elements are missing or underspecified:

- ❌ **Capacity Planning**: No detailed load projections, resource sizing, or traffic patterns
- ❌ **Performance SLA**: No response time requirements, throughput targets, or percentile metrics
- ❌ **Monitoring & Observability**: No performance metrics collection, alerting thresholds, or distributed tracing
- ❌ **Resource Limits**: Connection pool sizing, rate limiting, timeout configurations undefined
- ⚠️ **Horizontal Scaling**: Autoscaling mentioned but lacks detailed policy configuration
- ⚠️ **Database Scalability**: Multi-AZ setup present, but no read/write separation or sharding strategy

**Recommendation**: Prioritize defining performance SLA and implementing comprehensive monitoring BEFORE production launch. Without observability, you cannot validate if the system meets user expectations or identify performance regressions.

---

## Recommended Implementation Priority

1. **Immediate (P1)**: Database indexing, pagination, connection pooling, performance monitoring
2. **Short-term (P2)**: WebSocket scaling strategy, Redis eviction policy, read replicas, async transcoding
3. **Medium-term (P3)**: API rate limiting, CDN caching expansion, timeout configurations

**Critical Path**: Address C2 (indexing) and C5 (monitoring/SLA) first. These have the highest impact on production readiness and provide the foundation for performance optimization.
