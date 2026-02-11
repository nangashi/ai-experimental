# Performance Design Review: Polyglot Connect システム設計書

## Document Structure Analysis

The design document covers:
- **Present sections**: Project overview, technology stack, architecture design, data model, API design, implementation policies, and non-functional requirements
- **Explicitly documented aspects**: Performance targets (latency/throughput SLAs), scalability targets (concurrent sessions), technology choices, data flow, error handling, deployment strategy
- **Missing/incomplete aspects**: Capacity planning details, database indexing strategy, caching invalidation logic, horizontal scaling implementation, WebSocket connection management at scale, concurrency control mechanisms

The system aims to support 1,000-10,000 concurrent users across real-time translation scenarios with sub-500ms latency requirements.

---

## Critical Issues (System-Wide Bottlenecks & Production Viability Risks)

### C-1: Unbounded Translation History Growth Without Lifecycle Management

**Issue Location**: Section 4 (TranslationHistory テーブル), Section 7 (非機能要件)

**Description**:
The TranslationHistory table uses BIGSERIAL for its primary key and stores full translation text for every utterance. With stated scenarios of 1,000-10,000 concurrent users and real-time audio translation (potentially dozens of utterances per minute per session), this table will experience exponential growth:
- 10,000 user event × 20 participants × 60 min session × 10 utterances/min = 1.2M records per event
- At 1KB average per record, this is 1.2GB per major event
- No archival, partitioning, or retention strategy is defined beyond "30日間保持" for personal data

**Performance Impact**:
- Query performance degradation as table size grows (Section 5 shows `GET /api/sessions/{id}/history` with no pagination limit specified)
- Index bloat causing slower writes during high-traffic sessions
- Backup/restore times increasing linearly with data volume
- Elasticsearch sync lag if full-text search is expected on unbounded dataset

**Recommendations**:
1. Implement table partitioning by `translated_at` (monthly or weekly partitions)
2. Define explicit pagination limits for history retrieval API (e.g., max 100 records per request)
3. Add automated archival job moving records older than 30 days to cold storage (S3 + Athena for analytical queries)
4. Consider separate "hot" and "cold" tables, with hot table limited to last 7 days
5. Add composite index on `(session_id, translated_at DESC)` to optimize history queries

### C-2: Missing NFR for Translation API Rate Limits and Quota Exhaustion

**Issue Location**: Section 3 (External Services), Section 7 (非機能要件)

**Description**:
The design shows dependency on Google Cloud Translation API as the primary engine with DeepL as fallback (Section 6). However, there are no specifications for:
- Expected translation request volume (requests/sec at peak load)
- Google Translation API quota limits for the chosen pricing tier
- Rate limiting strategy when approaching quota
- Fallback trigger conditions beyond "API失敗時"

With 10,000 concurrent users scenario, if each utterance requires translation to 5 different languages (multilingual session), that's 50,000 translation API calls per wave of utterances.

**Performance Impact**:
- Quota exhaustion causing complete service outage during peak events
- Cascading fallback to DeepL potentially exhausting secondary quota
- No backpressure mechanism to throttle requests, causing unbounded retry loops (Section 6 mentions 3 retries with exponential backoff, but no circuit breaker)
- User-facing latency spikes or failures with no graceful degradation

**Recommendations**:
1. Define explicit API quota budgets and monitor consumption rates (CloudWatch metrics)
2. Implement client-side rate limiting with token bucket algorithm before API calls
3. Add circuit breaker pattern (e.g., fail-fast after 5 consecutive API errors, half-open retry after 30s)
4. Design graceful degradation: queue translation requests and process asynchronously when quota is near limit
5. Pre-purchase sufficient API quota for 2x peak load headroom
6. Add real-time quota usage dashboard and automated alerts at 70%/90% thresholds

---

## Significant Issues (High-Impact Scalability & Latency Problems)

### S-1: WebSocket Broadcast Fanout Inefficiency for Large Sessions

**Issue Location**: Section 3 (データフロー - チャット翻訳フロー), Section 5 (WebSocket Events)

**Description**:
The chat translation flow (Section 3) shows "全参加者に配信" pattern where Translation Service broadcasts each translated message to all session participants. For large sessions (stated scenario: 1,000-10,000 viewers for international events), this creates O(N) broadcast overhead per message:
- A single message in a 10,000-participant session requires 10,000 individual WebSocket sends
- If 20 messages/second are sent during active discussion, that's 200,000 WebSocket frames/second from a single server
- No mention of pub/sub architecture or message broker to distribute this load

**Performance Impact**:
- Server CPU exhaustion on the WebSocket server handling large sessions
- Increased message delivery latency as queue depth grows (target: 500ms translation response becomes 2-3 seconds with broadcast delay)
- Single WebSocket server becoming a bottleneck, preventing horizontal scaling
- Memory pressure from maintaining 10,000 concurrent WebSocket connections on one server instance

**Recommendations**:
1. Introduce Redis Pub/Sub or AWS SNS/SQS for message distribution:
   - Translation Service publishes once to topic
   - Multiple WebSocket server instances subscribe and broadcast to their connected clients
2. Implement connection affinity/sharding: partition users across multiple WebSocket servers by session_id hash
3. Use Server-Sent Events (SSE) for read-only participants (viewers) to reduce bidirectional connection overhead
4. Add message batching: collect messages over 100ms window and send as batch to reduce syscall overhead
5. Monitor per-server connection counts and auto-scale WebSocket servers when exceeding 1,000 connections/instance

### S-2: Stateful WebSocket Connection Management Preventing Horizontal Scaling

**Issue Location**: Section 3 (Session Management Service - WebSocket接続管理), Section 7 (可用性・スケーラビリティ)

**Description**:
The Session Management Service is responsible for "WebSocket接続管理" (Section 3), implying connection state is stored in the application server. When scaling horizontally with ECS (Section 2), this creates sticky session requirements:
- If User A's WebSocket is on Server 1, messages for User A must route to Server 1
- ECS auto-scaling (Section 7: CPU 70% triggers scale-out) will create new servers, but existing connections cannot migrate
- No mention of shared connection registry (Redis/DynamoDB) for cross-server message routing

**Performance Impact**:
- Load imbalance: old servers remain fully loaded while new scaled servers sit idle
- Inability to drain connections during deployments (Blue-Green strategy in Section 6 requires connection migration)
- Single server failure disconnects all its clients, breaking 99.9% SLA (Section 7)
- ALB sticky sessions reducing load distribution effectiveness

**Recommendations**:
1. Store WebSocket connection metadata in Redis:
   - Key: `ws:user:{user_id}` → Value: `{server_id, connection_id, session_id}`
   - On message publish, query Redis to find target server, route via internal message bus
2. Implement graceful connection draining:
   - Before server shutdown, send `reconnect` command to all clients with new server endpoint
   - Set 30-second grace period for migration
3. Use consistent hashing for initial connection assignment to minimize reshuffling during scale events
4. Add health check for WebSocket endpoint: mark server unhealthy if connection count > 5,000
5. Consider AWS API Gateway WebSocket ($1.00/million messages) to offload connection management

### S-3: N+1 Query Problem in Participant Language Resolution

**Issue Location**: Section 3 (データフロー - チャット翻訳フロー), Section 4 (Participant テーブル)

**Description**:
The chat translation flow states "各参加者の言語に翻訳" (Step 2), which implies iterating over participants to retrieve their language preference. Given the Participant table (Section 4) stores individual language per session participation, the likely implementation is:

```python
for participant in session.participants:
    target_lang = db.query(Participant).filter_by(id=participant.id).first().language
    translate(message, target_lang)
```

For a 20-participant session, this executes 21 queries (1 for participant list + 20 individual fetches).

**Performance Impact**:
- At 20 messages/second (active discussion), this is 420 queries/second per session
- With 1,000 concurrent sessions, this is 420,000 queries/second to PostgreSQL
- Even with connection pooling, this exceeds typical RDS r6g.2xlarge capacity (~10,000 QPS)
- Added latency of 10-20ms per query delays translation response time

**Recommendations**:
1. Use JOIN or eager loading to fetch participants with languages in single query:
   ```sql
   SELECT p.user_id, p.language FROM Participant p WHERE p.session_id = ?
   ```
2. Cache participant language map in Redis at session start:
   - Key: `session:{session_id}:languages` → Value: `{user_id: language, ...}`
   - TTL: session duration + 1 hour
   - Invalidate on participant join/leave events
3. Add composite index on Participant table: `(session_id, user_id) INCLUDE (language)`
4. Batch translation requests by target language to reduce API calls:
   - Group participants by language, translate once per language, multicast result

### S-4: Missing Database Indexes on Critical Query Paths

**Issue Location**: Section 4 (データモデル), Section 5 (REST API Endpoints)

**Description**:
The data model shows only primary keys and foreign key constraints, with no explicit index definitions. Critical query paths are missing indexes:

1. `GET /api/sessions/{id}/history`: Queries TranslationHistory by `session_id` (foreign key, likely indexed), but sorting by `translated_at DESC` for chronological display requires `(session_id, translated_at)` composite index
2. User login query: `SELECT * FROM User WHERE email = ?` requires unique index on `email` (marked UNIQUE so likely indexed, but not explicit)
3. Session participant lookup: `SELECT * FROM Participant WHERE session_id = ? AND user_id = ?` for checking duplicate joins needs composite index
4. Glossary lookup: `SELECT * FROM CustomGlossary WHERE organization_id = ? AND source_language = ? AND target_language = ?` for term matching requires composite index

**Performance Impact**:
- Full table scans on TranslationHistory (millions of rows) causing 5-10 second query times
- Glossary lookup adding 200-500ms latency per translation request if not indexed
- Participant duplicate checking becoming O(N) instead of O(1), causing race conditions on concurrent joins

**Recommendations**:
1. Add indexes in migration files:
   ```sql
   CREATE INDEX idx_translation_history_session_time ON TranslationHistory(session_id, translated_at DESC);
   CREATE INDEX idx_participant_session_user ON Participant(session_id, user_id);
   CREATE INDEX idx_glossary_lookup ON CustomGlossary(organization_id, source_language, target_language, source_term);
   ```
2. Use PostgreSQL's `EXPLAIN ANALYZE` on all API query paths to validate index usage
3. Monitor slow query log (queries > 100ms) and add indexes proactively
4. Consider partial index for active sessions: `WHERE ended_at IS NULL` for faster lookups

### S-5: Synchronous Translation API Calls Blocking WebSocket Event Loop

**Issue Location**: Section 3 (データフロー), Section 7 (パフォーマンス)

**Description**:
The translation flow shows sequential steps: receive audio → Speech-to-Text → Translation API → save to DB → broadcast. The performance requirement states "翻訳レスポンスタイム: 平均500ms以内" (Section 7). If Translation Service makes synchronous HTTP calls to Google Translation API (typical RTT: 100-300ms), and the WebSocket server runs on Python's async event loop (FastAPI + Socket.IO), blocking calls will stall the entire event loop.

With 1,000 concurrent sessions, if 100 sessions simultaneously send messages, that's 100 blocked event loop iterations, causing cascading delays.

**Performance Impact**:
- Head-of-line blocking: slow translation requests delay all subsequent WebSocket events
- WebSocket heartbeat/ping timeouts causing false disconnections
- Increased P95 latency from 500ms target to 2-5 seconds under load
- Server appears unresponsive during API call bursts

**Recommendations**:
1. Use async HTTP client (aiohttp/httpx) for all external API calls:
   ```python
   async with httpx.AsyncClient() as client:
       response = await client.post(translation_api_url, json=payload)
   ```
2. Implement request queuing with worker pool:
   - WebSocket handler publishes to Redis queue
   - Separate worker processes (Celery/RQ) consume and call Translation API
   - Workers publish results back to Redis Pub/Sub for WebSocket broadcast
3. Add timeout for Translation API calls (max 3 seconds) to prevent indefinite blocking
4. Use circuit breaker to fail-fast when API is slow/down, return cached/fallback translation
5. Monitor event loop lag metrics (uvloop exposes this) and alert if > 100ms

---

## Moderate Issues (Performance Problems Under Specific Conditions)

### M-1: Missing Translation Cache Invalidation Strategy

**Issue Location**: Section 3 (Translation Service - 翻訳結果のキャッシング), Section 2 (Cache: Redis 7)

**Description**:
The Translation Service mentions "翻訳結果のキャッシング" (Section 3) and Redis is designated as cache layer (Section 2), but there are no specifications for:
- Cache key structure (hash of source text + source/target language pair?)
- TTL strategy (how long to cache translations)
- Invalidation triggers (custom glossary updates should invalidate affected translations)
- Cache size limits (Redis memory eviction policy)

Custom glossary updates (Section 5: `PUT /api/glossaries/{id}`) could cause stale translations if cache is not invalidated.

**Performance Impact**:
- Stale translations served after glossary updates, degrading user experience
- Cache memory exhaustion if no TTL/eviction policy, causing Redis OOM and service crash
- Cache stampede: if popular translation expires, multiple simultaneous requests hit API
- Inconsistent translations across participants if some hit cache and others hit API after glossary change

**Recommendations**:
1. Define cache key structure: `translation:{md5(original_text)}:{source_lang}:{target_lang}:{glossary_version}`
2. Set TTL based on content type:
   - Real-time chat/audio: 5 minutes (low reuse probability)
   - Document translations: 24 hours (high reuse probability)
3. Implement cache invalidation on glossary updates:
   - Increment `glossary_version` counter in Redis when glossary changes
   - Old cache entries automatically miss on version mismatch
4. Use Redis `maxmemory-policy allkeys-lru` with 80% memory threshold alert
5. Add cache hit rate monitoring (target: >60% for document translations, >20% for real-time)

### M-2: Lack of Idempotency in Session Join Operations

**Issue Location**: Section 5 (WebSocket Events - join_session), Section 4 (Participant テーブル)

**Description**:
The WebSocket event `join_session` (Section 5) likely inserts a record into the Participant table (Section 4). If the client experiences network instability and sends duplicate `join_session` events (common in mobile networks), without idempotency checks, this could create duplicate participant records:
- No unique constraint on `(session_id, user_id)` pair in Participant table
- WebSocket auto-reconnect (Section 6: "最大5回") could trigger repeated joins

**Performance Impact**:
- Duplicate participant records causing incorrect participant counts
- Broadcast fanout sending duplicate messages to same user (2x bandwidth usage)
- Translation requests multiplied per duplicate (2x API cost)
- Query performance degradation with inflated participant counts (N+1 query issue S-3 amplified)

**Recommendations**:
1. Add unique constraint on Participant table:
   ```sql
   ALTER TABLE Participant ADD CONSTRAINT uq_participant_session_user UNIQUE(session_id, user_id);
   ```
2. Use PostgreSQL `INSERT ... ON CONFLICT DO NOTHING` for idempotent joins:
   ```sql
   INSERT INTO Participant (session_id, user_id, language, joined_at)
   VALUES (?, ?, ?, NOW())
   ON CONFLICT (session_id, user_id) DO NOTHING;
   ```
3. Add idempotency key to WebSocket events (client-generated UUID), track in Redis with 5-minute TTL
4. Return 200 OK for duplicate join requests instead of 409 Conflict (client shouldn't retry on success)

### M-3: Missing Connection Pooling Configuration Details

**Issue Location**: Section 2 (データベース - PostgreSQL, Redis), Section 3 (Google Cloud Translation API連携)

**Description**:
The design mentions PostgreSQL, Redis, and external Translation API, but does not specify connection pooling parameters:
- Database connection pool size (min/max connections)
- Connection timeout settings
- Idle connection eviction policy
- Redis connection pool configuration
- HTTP connection pool for Translation API (max connections, keepalive settings)

FastAPI's default database client (SQLAlchemy) defaults to 5 connections per pool, which is insufficient for 1,000 concurrent sessions.

**Performance Impact**:
- Connection exhaustion under load: requests blocked waiting for available connection
- Increased latency from repeated connection establishment (TCP handshake + TLS negotiation)
- Database server resource waste from short-lived connections (connection churn)
- Translation API rate limiting due to connection reuse limits

**Recommendations**:
1. Configure PostgreSQL connection pool (SQLAlchemy settings):
   ```python
   pool_size=50,  # Max concurrent queries expected
   max_overflow=20,  # Burst capacity
   pool_timeout=30,  # Fail fast if all connections busy
   pool_pre_ping=True,  # Validate connections before use
   ```
2. Set Redis connection pool in FastAPI startup:
   ```python
   redis_pool = redis.ConnectionPool(max_connections=100, socket_timeout=5)
   ```
3. Configure HTTP client connection pool for Translation API:
   ```python
   httpx.AsyncClient(limits=httpx.Limits(max_connections=200, max_keepalive_connections=50))
   ```
4. Monitor connection pool metrics (active/idle connections) and tune based on actual load
5. Add connection pool exhaustion alerts (CloudWatch custom metric)

### M-4: Race Condition in Session End Time Update

**Issue Location**: Section 4 (Session テーブル - ended_at), Section 5 (WebSocket Events)

**Description**:
The Session table has `ended_at` column (nullable, Section 4), which likely gets updated when the last participant leaves or organizer explicitly ends the session. If multiple participants leave simultaneously (common when meeting host clicks "End for all"), concurrent updates to `ended_at` could cause race conditions:
- Two requests read `ended_at = NULL`, both believe they are the last participant
- Both attempt to `UPDATE Session SET ended_at = NOW() WHERE id = ?`
- No optimistic locking (version column) or transaction isolation specification

**Performance Impact**:
- Duplicate "session ended" events broadcast to all participants
- Duplicate cleanup tasks triggered (archival jobs, analytics aggregation)
- Potential for session state corruption if cleanup logic assumes single execution
- Database deadlocks if concurrent updates on same session row

**Recommendations**:
1. Use optimistic locking with version column:
   ```sql
   ALTER TABLE Session ADD COLUMN version INTEGER DEFAULT 1;
   UPDATE Session SET ended_at = NOW(), version = version + 1
   WHERE id = ? AND version = ? AND ended_at IS NULL;
   ```
2. Implement transaction isolation level `SERIALIZABLE` for session end operations
3. Use database advisory lock for session closure:
   ```sql
   SELECT pg_advisory_lock(hashtext(session_id));
   -- Check and update ended_at
   SELECT pg_advisory_unlock(hashtext(session_id));
   ```
4. Use single-responsibility pattern: only organizer can end session, participant leave is separate event
5. Add idempotency check: if `ended_at IS NOT NULL`, return success without updating

---

## Minor Issues & Positive Observations

### Minor Observations

**MI-1: Load Test Scope May Not Cover International Event Scenario**
- Section 6 states "Locustで同時接続500セッション検証"
- However, Section 1 scenario includes "国際イベントのリアルタイム字幕配信（視聴者数: 1,000-10,000）"
- Load test should validate 10,000 concurrent connections in single session, not just 500 sessions
- Recommendation: Add scenario-specific load tests (small meetings, large events, sustained load)

**MI-2: Logging Full Translation Requests May Cause Storage Bloat**
- Section 6 specifies "翻訳リクエスト・レスポンスの全量ロギング"
- For 10,000-user events with continuous translation, this could generate 10GB+ logs per hour
- Recommendation: Use sampling (1% of requests) or only log errors and slow requests (>1s)

**MI-3: Missing Monitoring for Translation Quality Metrics**
- Section 1 mentions "翻訳品質フィードバック収集" feature
- No specification for how this feedback is stored, analyzed, or used to improve caching/glossaries
- Recommendation: Store feedback in separate table with translation_history_id FK, build analytics dashboard

### Positive Design Aspects

1. **Explicit Performance SLAs Defined**: Section 7 specifies measurable targets (500ms translation, 95th percentile 1s API response), enabling performance regression detection

2. **Fallback Translation Engine**: Section 6 shows DeepL API fallback for Google API failures, providing resilience against single vendor outages

3. **Auto-scaling Strategy**: Section 7 defines CPU-based scaling trigger (70% threshold), enabling automatic capacity adjustment

4. **Retry with Exponential Backoff**: Section 6 mentions 3 retries with exponential backoff for API errors, reducing failure impact

5. **CDN Integration**: Section 2 shows CloudFront CDN usage, reducing static asset latency for global users

6. **Structured Logging**: Section 6 specifies JSON-format structured logging, improving log parsing and analysis efficiency

---

## Summary and Recommendations

### Critical Priority (Immediate Action Required)
1. Implement TranslationHistory table partitioning and archival strategy to prevent unbounded growth (C-1)
2. Define Translation API quota budgets and implement circuit breaker to prevent quota exhaustion outages (C-2)

### High Priority (Address Before Production Launch)
3. Introduce message broker (Redis Pub/Sub) for WebSocket broadcast distribution to handle large sessions (S-1)
4. Implement shared connection registry in Redis to enable horizontal WebSocket scaling (S-2)
5. Fix N+1 query in participant language resolution with caching or JOIN optimization (S-3)
6. Add database indexes on TranslationHistory, Participant, CustomGlossary tables (S-4)
7. Convert synchronous Translation API calls to async to prevent event loop blocking (S-5)

### Medium Priority (Optimize During Initial Operations)
8. Define cache invalidation strategy with TTL and glossary version tracking (M-1)
9. Add unique constraint and idempotency logic for session join operations (M-2)
10. Configure connection pooling parameters for database and HTTP clients (M-3)
11. Implement optimistic locking for session end operations (M-4)

### Performance Testing Recommendations
- Expand load tests to cover 10,000 concurrent users in single session scenario
- Conduct soak tests with 1,000 sessions sustained for 4+ hours to identify memory leaks
- Simulate Translation API quota limits and fallback behavior in staging environment
- Benchmark database query performance with projected 6-month data volume (100M+ translation records)

The design demonstrates good architectural fundamentals with clear NFR specifications and resilience strategies. Addressing the critical and high-priority issues will ensure the system can reliably scale to the stated 1,000-10,000 user scenarios while maintaining sub-500ms latency targets.
