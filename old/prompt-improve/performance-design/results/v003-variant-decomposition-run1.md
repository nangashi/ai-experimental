# Performance Design Review: LiveStream Pro システム設計書

## Step 1: Structural Analysis

### Major Components Identified
1. **API Gateway**: Single entry point for HTTP requests
2. **Stream Manager**: Manages stream lifecycle and viewer counts
3. **Chat Service**: WebSocket-based real-time messaging
4. **Archive Service**: Post-stream video processing and S3 storage
5. **Payment Service**: Stripe integration for donations
6. **Notification Service**: User notifications for stream events
7. **Data Layer**: PostgreSQL (metadata), Redis (sessions/state), S3 (archives)
8. **Media Infrastructure**: Ant Media Server (WebRTC), CloudFront CDN

### Architectural Decisions Present
- **Tech Stack**: Go/Gin backend, React/Next.js frontend, WebSocket for real-time
- **Deployment**: AWS ECS Fargate, RDS Multi-AZ, CloudFront CDN
- **Auto-scaling**: ECS CPU/memory-based scaling (minimum 2 tasks)
- **Caching**: Redis for sessions and stream state
- **Storage Lifecycle**: S3 Standard → Glacier after 90 days

### Scope and Expected Scale
- **Concurrent streams**: 500
- **Concurrent viewers**: 50,000
- **Monthly active users**: 100,000
- **System size**: Medium-scale live streaming platform

### Performance Information Status
**Present:**
- Basic infrastructure choices (ECS, RDS Multi-AZ, CloudFront)
- Redis for session/state management
- Auto-scaling configuration (CPU/memory-based)
- Chat message TTL (5 minutes)

**Absent:**
- Detailed capacity planning and resource sizing
- Performance SLA definitions (latency, throughput targets)
- Database query optimization strategies (indexes, query patterns)
- Caching strategies beyond basic session storage
- Specific bottleneck analysis for high-load scenarios
- Monitoring and observability design
- Rate limiting and circuit breaker configurations
- Connection pool sizing
- Broadcast message fan-out optimization strategies

---

## Step 2: Detailed Problem Detection

### Evaluation Scores and Findings

#### 1. Algorithm & Data Structure Efficiency: 2/5

**Critical Issue: Inefficient Follow Notification Broadcasting**

**Location**: Section 3.3 - 配信開始フロー, Step 5

**Problem**: The notification service sends individual notifications to "all followers" synchronously during stream start flow. With the system's scale (100,000 MAU), popular streamers could have 10,000+ followers.

**Impact Analysis**:
- **Latency**: Stream start operation blocks on notification completion, potentially adding 10-30 seconds for popular streamers
- **Throughput**: Serial notification processing creates a bottleneck limiting concurrent stream starts
- **User Experience**: Streamers experience delayed "stream started" confirmation

**Computational Complexity**: Current O(n) sequential notification where n = follower count. Each notification likely involves:
- Database query to fetch follower preferences
- API calls to notification services (email, push, in-app)
- Potential external service timeouts

**Recommendation**:
1. **Decouple notification from stream start**: Move notification to asynchronous background queue (e.g., AWS SQS, Redis Queue)
2. **Batch processing**: Process notifications in batches of 100-500 with parallel workers
3. **Implement fan-out pattern**: Use message queue with multiple consumer workers (5-10 workers)
4. **Priority tiering**: Send notifications to recently active users first, defer inactive users
5. **Add timeout protection**: Set maximum wait time of 500ms for stream start API, continue notification in background

**Estimated Improvement**: Stream start latency reduced from 10-30s to <1s, enabling smooth concurrent stream launches.

---

**Significant Issue: Potentially Inefficient Follower Query Pattern**

**Location**: Section 4.2 - follows table, Section 5.1 - `/api/users/{user_id}/followers` endpoint

**Problem**: The `follows` table design does not specify indexes. Querying followers/following lists will result in full table scans without proper indexing.

**Impact Analysis**:
- **Query Performance**: O(n) table scan for follower lists, especially problematic for popular streamers
- **Scalability**: As user base grows to 100,000 MAU, follow relationships could reach 1M+ records
- **Latency**: Follower/following list queries could take 500ms-5s without indexes

**Recommendation**:
1. **Add composite indexes**:
   - `CREATE INDEX idx_follows_following ON follows(following_id, created_at DESC)` for follower lists
   - `CREATE INDEX idx_follows_follower ON follows(follower_id, created_at DESC)` for following lists
2. **Consider covering indexes** if frequently accessed columns are needed in results
3. **Implement pagination** with cursor-based pagination to avoid OFFSET performance degradation

---

#### 2. I/O & Network Efficiency: 2/5

**Critical Issue: N+1 Query Problem in Stream List API**

**Location**: Section 5.1 - `GET /api/streams` endpoint

**Problem**: The design does not specify how stream list retrieval joins with user information. Typical implementation would fetch streams, then query users table separately for each stream's creator details (N+1 pattern).

**Impact Analysis**:
- **Database Load**: For a list of 50 streams, this generates 1 initial query + 50 user queries = 51 queries
- **Latency**: Each query adds 5-10ms, totaling 250-500ms additional latency
- **Scalability**: Under high traffic (thousands of requests/minute), this amplifies database load unnecessarily

**Recommendation**:
1. **Use JOIN queries**: Fetch streams with user information in a single query:
   ```sql
   SELECT s.*, u.username, u.user_id
   FROM streams s
   JOIN users u ON s.user_id = u.user_id
   WHERE s.status = 'live'
   ORDER BY s.started_at DESC
   LIMIT 50
   ```
2. **Implement database query caching**: Cache the "live streams" list in Redis with 10-second TTL
3. **Add GraphQL or selective field loading** to avoid over-fetching if only basic stream info is needed

---

**Significant Issue: Missing Batch API Strategy for Archive Processing**

**Location**: Section 3.2 - Archive Service

**Problem**: The archive service design does not specify how it handles multiple concurrent stream endings. If 50 streams end simultaneously (peak traffic scenario), 50 separate FFmpeg transcode jobs may start simultaneously.

**Impact Analysis**:
- **Resource Exhaustion**: FFmpeg is CPU and memory intensive; 50 parallel jobs could crash the service
- **Throughput Degradation**: Without job queuing, transcoding may fail or cause cascading failures
- **Storage I/O**: Concurrent S3 uploads without rate limiting could hit AWS service limits

**Recommendation**:
1. **Implement job queue**: Use Redis Queue or AWS SQS to serialize archive processing
2. **Worker pool pattern**: Limit concurrent FFmpeg processes to 5-10 based on available CPU cores
3. **Progressive processing**: Prioritize popular streams (high viewer count) for faster archive availability
4. **Resource reservation**: Allocate dedicated worker tasks for archive processing separate from API services

---

**Significant Issue: WebSocket Broadcast Message Fan-out Inefficiency**

**Location**: Section 3.3 - チャット送信フロー, Step 4

**Problem**: The design specifies broadcasting chat messages to "all viewers watching the same stream" but does not detail the implementation strategy. Naive implementation would iterate through all connected WebSocket connections, checking stream_id for each.

**Impact Analysis**:
- **Latency**: For a stream with 5,000 viewers, naive O(n) iteration takes 50-500ms per message
- **CPU Usage**: High CPU load for popular streams with active chat (10-50 messages/second)
- **Scalability**: Does not scale beyond single Chat Service instance (horizontal scaling blocked)

**Recommendation**:
1. **Implement Pub/Sub pattern**: Use Redis Pub/Sub to distribute messages across multiple Chat Service instances
   - Each Chat Service instance subscribes to channels matching hosted stream IDs
   - Message sender publishes to Redis channel `chat:{stream_id}`
   - All subscribers receive and broadcast to their local WebSocket connections
2. **Connection grouping**: Maintain in-memory map of `stream_id → []websocket.Conn` for O(1) group lookup
3. **Horizontal scaling**: Enable multiple Chat Service instances by using sticky sessions or shared Pub/Sub backend
4. **Rate limiting**: Implement per-user message rate limit (e.g., 5 messages/10 seconds) to prevent spam-induced load

---

#### 3. Caching Strategy: 2/5

**Significant Issue: Missing Cache Strategy for High-Traffic Read Operations**

**Location**: Section 5.1 - API endpoints, Section 2.2 - Redis usage

**Problem**: Redis is only used for sessions and stream state. High-traffic read operations like user profiles, stream metadata, and follower counts are not cached, resulting in repeated database queries.

**Impact Analysis**:
- **Database Load**: Popular streamer profiles could be queried 1000+ times/minute
- **Latency**: Every user profile fetch requires database round-trip (10-50ms)
- **Scalability**: Database becomes bottleneck under high traffic

**Recommendations**:
1. **User Profile Cache**: Cache user data with 5-minute TTL
   - Key: `user:{user_id}`, Value: JSON user object
   - Invalidate on user update operations
2. **Stream Metadata Cache**: Cache active stream list with 10-second TTL
   - Key: `streams:active`, Value: JSON array of live streams
   - Update on stream start/end events
3. **Follower Count Cache**: Cache follower/following counts
   - Key: `user:{user_id}:follower_count`, TTL: 1 minute
   - Update asynchronously after follow/unfollow operations
4. **Archive List Cache**: Cache per-user archive lists with 1-hour TTL (archives are immutable)

---

**Moderate Issue: Inefficient Chat Message Cache Design**

**Location**: Section 3.3 - チャット送信フロー, Step 3 - Redis 5-minute TTL

**Problem**: Chat messages are stored in Redis with 5-minute TTL for "temporary storage" but the purpose is unclear. If this is for chat history replay when users join mid-stream, storing all messages is inefficient.

**Impact Analysis**:
- **Memory Usage**: A popular stream (5,000 viewers) with 10 messages/second generates 3,000 messages over 5 minutes
- **Redis Memory**: At ~500 bytes per message = 1.5MB per active stream × 500 concurrent streams = 750MB+ Redis memory
- **Latency**: Fetching 3,000 messages on user join adds 100-500ms latency

**Recommendation**:
1. **Limit chat history size**: Store only last 50-100 messages per stream (circular buffer)
2. **Use Redis LIST structure**: `LPUSH chat:{stream_id}` and `LTRIM chat:{stream_id} 0 99` to maintain fixed size
3. **Implement lazy loading**: Send only last 20 messages on connection, fetch older messages on scroll
4. **Consider removing TTL**: Messages naturally expire when stream ends (delete by stream_id)

---

#### 4. Memory & Resource Management: 3/5

**Significant Issue: No Connection Pool Configuration Specified**

**Location**: Section 2.2 - PostgreSQL, Redis connections

**Problem**: The design does not specify connection pool settings for PostgreSQL and Redis. Default connection pooling may be insufficient for expected scale (50,000 concurrent viewers).

**Impact Analysis**:
- **Connection Exhaustion**: PostgreSQL default max_connections = 100; insufficient for multiple ECS tasks
- **Latency Spikes**: Connection creation overhead (50-100ms) on every request if pool exhausted
- **Cascading Failures**: Connection pool saturation can cause request timeouts and service degradation

**Recommendation**:
1. **PostgreSQL Connection Pool Sizing**:
   - Set max_open_conns = 25 per ECS task
   - Set max_idle_conns = 10 per ECS task
   - Set conn_max_lifetime = 5 minutes (to handle DB failover gracefully)
   - RDS max_connections = (Number of ECS tasks × 25) + 20 (admin buffer)
2. **Redis Connection Pool**:
   - Use redis-go connection pool with pool_size = 50 per task
   - Set min_idle_conns = 10 for faster response
3. **Monitor pool metrics**: Emit metrics for pool utilization, wait time, and connection errors

---

**Moderate Issue: WebSocket Connection Lifecycle Management Unclear**

**Location**: Section 3.2 - Chat Service

**Problem**: The design does not specify how WebSocket connections are closed, how idle connections are detected, or how memory is cleaned up when users disconnect.

**Impact Analysis**:
- **Memory Leaks**: Unclosed connections or unreleased buffers can accumulate over time
- **Resource Waste**: Idle connections (users who left without closing tab) consume server memory
- **Scalability**: Memory leaks cause service crashes after 24-48 hours of operation

**Recommendation**:
1. **Implement connection timeout**: Close WebSocket after 5 minutes of inactivity
2. **Ping/Pong heartbeat**: Send ping every 30 seconds, close connection if no pong response
3. **Graceful shutdown handling**: On service shutdown, send close frame to all connections with 5-second grace period
4. **Resource cleanup**: Ensure deferred cleanup of connection maps and buffers in goroutines
5. **Memory profiling**: Use Go pprof to monitor goroutine and memory growth in production

---

#### 5. Latency, Throughput Design & Scalability: 2/5

**Critical Issue: Missing Performance SLA Definitions**

**Location**: Section 7 - Non-functional requirements

**Problem**: The design does not define performance SLA (Service Level Agreement) for latency, throughput, or uptime. Without quantified targets, it is impossible to evaluate if the architecture meets user expectations.

**Impact Analysis**:
- **No Success Criteria**: Cannot determine if system performance is acceptable
- **No Monitoring Baselines**: Cannot set meaningful alerting thresholds
- **Optimization Blind**: Cannot prioritize performance improvements without target metrics

**Recommendation**:
Define specific SLAs for key operations:

1. **Latency SLAs**:
   - API response time: p50 < 100ms, p95 < 300ms, p99 < 500ms
   - Stream start latency: < 1 second (from API call to viewer can join)
   - Chat message delivery: < 200ms (sender to all recipients)
   - Video playback startup: < 2 seconds (initial buffering)

2. **Throughput SLAs**:
   - API Gateway: 10,000 requests/second
   - Chat messages: 50,000 messages/second (across all streams)
   - Concurrent WebSocket connections: 50,000+

3. **Availability SLA**:
   - System uptime: 99.9% (43 minutes downtime/month)
   - Stream interruption rate: < 0.1% of live minutes

---

**Critical Issue: No Database Index Strategy**

**Location**: Section 4.2 - Table designs

**Problem**: None of the table designs specify indexes beyond primary keys. Query performance will degrade significantly as data volume grows.

**Impact Analysis**:
- **Query Degradation**: Critical queries will slow from milliseconds to seconds as tables grow
- **Scalability Blocker**: System cannot handle expected load without indexes
- **Database CPU Saturation**: Full table scans will consume excessive database CPU

**Recommendation**:
Implement the following indexes:

1. **streams table**:
   - `CREATE INDEX idx_streams_user_status ON streams(user_id, status, started_at DESC)` - for user's stream history
   - `CREATE INDEX idx_streams_status_started ON streams(status, started_at DESC)` - for active streams list

2. **follows table** (as mentioned earlier):
   - `CREATE INDEX idx_follows_following ON follows(following_id, created_at DESC)`
   - `CREATE INDEX idx_follows_follower ON follows(follower_id, created_at DESC)`

3. **archives table**:
   - `CREATE INDEX idx_archives_stream ON archives(stream_id)` - for stream-to-archive lookup
   - `CREATE INDEX idx_archives_created ON archives(created_at DESC)` - for recent archives list

4. **users table**:
   - `CREATE INDEX idx_users_email ON users(email)` - for login lookup (if not already enforced by UNIQUE)

5. **Analyze query patterns**: Use PostgreSQL `EXPLAIN ANALYZE` to validate index effectiveness

---

**Significant Issue: No Rate Limiting or Circuit Breaker Design**

**Location**: Section 5 - API Design, Section 6.1 - Error Handling

**Problem**: The design does not include rate limiting for API endpoints or circuit breakers for external service calls (Stripe API, Ant Media Server). This leaves the system vulnerable to abuse and cascading failures.

**Impact Analysis**:
- **DoS Vulnerability**: Without rate limiting, malicious users can overwhelm the system
- **Stripe API Failures**: Stripe API outages or slow responses can cause Payment Service timeouts to cascade to API Gateway
- **Resource Exhaustion**: Uncontrolled request rates can exhaust database connections and memory

**Recommendation**:

1. **API Rate Limiting**:
   - Per-user rate limit: 100 requests/minute (general endpoints)
   - Per-IP rate limit: 1000 requests/minute (unauthenticated endpoints)
   - Implement using Redis sliding window counter or token bucket algorithm
   - Return HTTP 429 (Too Many Requests) with Retry-After header

2. **Circuit Breaker for External Services**:
   - Implement circuit breaker pattern (using libraries like `gobreaker`) for:
     - Stripe API calls (Payment Service)
     - Ant Media Server API calls (Stream Manager)
   - Circuit breaker states: Closed → Open (after 5 failures) → Half-Open (after 30s timeout)
   - Fallback: Return cached data or graceful error message

3. **Timeout Configurations**:
   - Stripe API: 5-second timeout with 2 retries (exponential backoff)
   - Ant Media Server: 3-second timeout with 1 retry
   - Database queries: 10-second timeout
   - WebSocket operations: 30-second read/write deadline

---

**Significant Issue: Insufficient Horizontal Scaling Strategy**

**Location**: Section 7.2 - ECS auto-scaling based on CPU/memory

**Problem**: The design relies solely on CPU/memory-based auto-scaling for ECS tasks. This is insufficient for real-time systems where latency and connection count are more critical metrics.

**Impact Analysis**:
- **Delayed Scaling**: CPU-based scaling reacts after system is already degraded (high CPU = already slow)
- **Connection Limits**: WebSocket connection count may hit limits before CPU saturation
- **Uneven Load**: Chat Service instances may have unequal connection distribution

**Recommendation**:

1. **Custom Scaling Metrics**:
   - Scale based on active WebSocket connection count (target: 5,000 connections per task)
   - Scale based on API Gateway request count (target: 1,000 requests/second per task)
   - Scale based on p95 latency (trigger scale-up if p95 > 300ms for 2 minutes)

2. **Predictive Scaling**:
   - Use AWS Application Auto Scaling predictive scaling for scheduled events (e.g., popular streamer's scheduled broadcast)

3. **Connection Load Balancing**:
   - Use Application Load Balancer with sticky sessions for WebSocket
   - Implement connection draining (30-second grace period) during scale-down

4. **Database Scaling**:
   - Implement read replicas for PostgreSQL to offload read queries
   - Route read operations (stream list, user profile) to read replicas
   - Route writes (stream start, transactions) to primary instance

---

**Moderate Issue: No Monitoring and Observability Strategy**

**Location**: Section 6.2 - Logging, Section 7 - NFR

**Problem**: The design specifies logging (CloudWatch Logs) but does not define metrics collection, distributed tracing, or alerting strategy. Without observability, performance degradation cannot be detected or diagnosed efficiently.

**Impact Analysis**:
- **Blind Operations**: Performance issues go unnoticed until user complaints
- **Slow Incident Response**: Lack of tracing makes debugging distributed system issues difficult
- **No Proactive Optimization**: Cannot identify performance bottlenecks without metrics

**Recommendation**:

1. **Metrics Collection** (use CloudWatch Metrics or Prometheus):
   - **API Gateway**: Request count, error rate, latency (p50/p95/p99), requests/second
   - **Stream Manager**: Active stream count, stream start/end rate, viewer count distribution
   - **Chat Service**: WebSocket connection count, message rate, broadcast latency
   - **Database**: Query latency, connection pool utilization, slow query count
   - **Redis**: Memory usage, command latency, hit/miss ratio

2. **Distributed Tracing** (use AWS X-Ray or OpenTelemetry):
   - Trace full request flow: API Gateway → Stream Manager → Database → Notification Service
   - Identify slow components in request path
   - Set trace sampling rate (10% of requests to reduce overhead)

3. **Alerting Thresholds**:
   - API p95 latency > 500ms for 5 minutes
   - Error rate > 1% for 5 minutes
   - Active WebSocket connections > 45,000 (90% of capacity)
   - Database connection pool utilization > 90%
   - Stream start failure rate > 5%

4. **Dashboards**: Create CloudWatch dashboards for real-time system health visualization

---

## NFR & Scalability Checklist

### Capacity Planning: ❌ Not Adequately Addressed
- **Expected Load**: Defined (500 concurrent streams, 50,000 viewers)
- **Resource Sizing**: Not specified (ECS task CPU/memory, RDS instance type, Redis cluster size)
- **Data Growth Projections**: Not specified (database growth rate, storage requirements)

**Recommendation**: Define resource sizing based on load calculations:
- ECS tasks: 15-20 tasks (2.5k-3.3k viewers per task) with auto-scaling up to 50 tasks
- RDS instance: db.r5.2xlarge (8 vCPU, 64GB RAM) for expected query load
- Redis: cache.r5.large (2 vCPU, 13GB RAM) for session and stream state
- Estimate database growth: ~1GB/month for metadata, ~500GB/month for archived videos

---

### Horizontal/Vertical Scaling: ⚠️ Partially Addressed
- **Stateless Design**: ✅ Mentioned for ECS tasks
- **Load Balancing**: Not specified (ALB configuration missing)
- **Auto-scaling Policies**: ⚠️ Only CPU/memory-based, missing connection-based and latency-based scaling

**Recommendation**: As described in "Insufficient Horizontal Scaling Strategy" section above.

---

### Performance SLA: ❌ Not Defined
- **Response Time Requirements**: Not specified
- **Throughput Targets**: Not specified
- **Percentile Metrics**: Not specified

**Recommendation**: As described in "Missing Performance SLA Definitions" section above.

---

### Monitoring & Observability: ⚠️ Minimal (Logs Only)
- **Performance Metrics**: Not specified
- **Alerting Thresholds**: Not specified
- **Distributed Tracing**: Not specified

**Recommendation**: As described in "No Monitoring and Observability Strategy" section above.

---

### Resource Limits: ❌ Not Specified
- **Connection Pool Sizing**: Not specified
- **Rate Limiting**: Not specified
- **Timeout Configurations**: Not specified
- **Circuit Breakers**: Not specified

**Recommendation**: As described in "No Connection Pool Configuration" and "No Rate Limiting or Circuit Breaker Design" sections above.

---

### Database Scalability: ⚠️ Partially Addressed
- **Read/Write Separation**: Not specified (RDS Multi-AZ provides failover but not read scaling)
- **Sharding Strategy**: Not applicable at current scale
- **Index Optimization**: ❌ No indexes specified

**Recommendation**:
1. Implement read replicas for scaling read operations
2. Add indexes as specified in "No Database Index Strategy" section
3. Consider future sharding strategy if scaling beyond 100k MAU (shard by user_id for users/streams/follows tables)

---

## Positive Aspects

1. **Appropriate Tech Stack**: Go for backend provides good concurrency handling for WebSocket connections; React/Next.js is suitable for interactive UI
2. **Redis for State Management**: Using Redis for stream state and sessions is appropriate for low-latency access
3. **CDN for Video Delivery**: CloudFront CDN will significantly improve video delivery latency and reduce origin load
4. **S3 Lifecycle Policy**: Glacier migration after 90 days is cost-effective for infrequently accessed archives
5. **Multi-AZ Database**: RDS Multi-AZ provides good availability guarantees
6. **Asynchronous Chat Design**: Separating Chat Service with WebSocket is architecturally sound for real-time messaging

---

## Summary: Priority Issues to Address

### Must Fix (Before Launch)
1. Decouple notification from stream start (async queue)
2. Add database indexes for all tables (streams, follows, archives)
3. Define and implement performance SLA targets
4. Implement connection pool sizing for PostgreSQL and Redis
5. Add rate limiting for API endpoints

### Should Fix (Before Production Traffic)
6. Implement Redis Pub/Sub for WebSocket broadcast scaling
7. Add circuit breakers for external service calls (Stripe, Ant Media)
8. Fix N+1 query problem in stream list API (use JOINs)
9. Implement monitoring metrics and distributed tracing
10. Add read replicas for PostgreSQL to scale read operations

### Nice to Have (Post-Launch Optimization)
11. Optimize follower notification with batch processing and priority tiering
12. Implement custom auto-scaling metrics (connection count, latency)
13. Optimize chat message cache size (limit to 50-100 messages)
14. Add predictive scaling for scheduled events

---

## Conclusion

The LiveStream Pro system design provides a solid foundation with appropriate technology choices (Go, PostgreSQL, Redis, WebSocket, CDN). However, the design lacks critical performance engineering details required for a production-ready live streaming platform at the specified scale.

The most severe performance risks are:
1. **Synchronous follower notification blocking stream start** (could add 10-30s latency)
2. **Missing database indexes** (queries will degrade as data grows)
3. **Undefined performance SLAs** (no success criteria or monitoring baselines)
4. **Lack of connection pooling and rate limiting** (risk of connection exhaustion and DoS)

These issues must be addressed before launch to ensure the system can handle 500 concurrent streams and 50,000 concurrent viewers reliably. The recommended optimizations will improve stream start latency from 10-30s to <1s, reduce API latency to <300ms (p95), and enable horizontal scaling to support growth beyond initial targets.

**Overall Performance Architecture Score: 2.2/5**

The low score reflects missing critical performance engineering details, not fundamental architectural flaws. With the recommended improvements implemented, the architecture is capable of meeting the stated requirements.
