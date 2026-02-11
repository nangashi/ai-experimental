# Performance Design Review - Polyglot Connect システム設計書

## Executive Summary

This performance evaluation identifies **8 critical issues**, **5 significant issues**, and **4 moderate issues** in the Polyglot Connect real-time translation platform design. The most severe concerns include unbounded TranslationHistory growth without archival strategy, missing concurrency control for real-time operations, lack of SLA definitions for user-facing metrics, and N+1 query antipatterns in participant-based operations.

---

## Critical Issues (Severity: High)

### C-1: Unbounded TranslationHistory Growth Without Data Lifecycle Management

**Issue Description:**
The TranslationHistory table uses BIGSERIAL primary key but lacks any data retention, archival, or partitioning strategy (lines 129-139). Given the scale requirements (1,000-10,000 concurrent viewers for international events, line 19), this table will experience exponential growth:
- A 2-hour event with 5,000 viewers and 100 messages = 500,000 translation records
- Multiple daily events → multi-million records per week

**Performance Impact:**
- Query degradation: Full table scans on `/api/sessions/{id}/history` endpoint (line 170) will exceed 1-second SLA (line 214) within weeks
- Index bloat: Foreign key indexes on session_id and speaker_id will degrade from O(log n) to near-linear lookup times
- Backup/restore failures: Daily backups will grow beyond operational windows
- Storage costs: Unbounded TEXT columns (original_text, translated_text) will consume TBs annually

**Recommended Solution:**
1. **Immediate**: Implement time-based table partitioning (monthly partitions, PostgreSQL native partitioning)
2. **Archival Policy**: Move sessions older than 30 days (aligns with stated retention policy in line 219) to AWS S3 + Athena for compliance queries
3. **Retention Policy**: Hard-delete sessions older than 90 days (legal review required)
4. **Monitoring**: Alert when partition size exceeds 50GB or query latency > 500ms

**Document Reference:** Section 4 (Data Model), Section 7 (Non-functional Requirements - missing data lifecycle)

---

### C-2: Missing Race Condition Protection in Real-Time Translation Workflow

**Issue Description:**
The real-time translation workflows (lines 87-99) lack concurrency control mechanisms for critical race conditions:

1. **Participant duplicate join**: Multiple `join_session` events from the same user (network retry, multi-device) can create duplicate Participant records (lines 120-127) with no UNIQUE constraint on (session_id, user_id)
2. **Translation deduplication**: Simultaneous `send_message` events with identical content can trigger duplicate Translation API calls and database writes (line 92-93)
3. **Session state transitions**: Concurrent session termination (organizer leaves + auto-timeout) can create orphaned WebSocket connections and inconsistent ended_at timestamps (line 118)

**Performance Impact:**
- **Cost explosion**: Duplicate Translation API calls waste quota (Google Translation API charges per character)
- **Data inconsistency**: Participant count discrepancies break billing and capacity planning
- **WebSocket overhead**: Ghost connections consume server memory and broadcast bandwidth

**Recommended Solution:**
1. **Database constraints**: Add UNIQUE constraint on Participant(session_id, user_id, ended_at) with partial index for active participants
2. **Idempotency keys**: Implement client-generated idempotency tokens for translation requests (Redis-based deduplication with 60-second TTL)
3. **Distributed locking**: Use Redis SETNX for session state transitions with 5-second lease timeout
4. **Transaction isolation**: Use SERIALIZABLE isolation level for participant join operations to prevent phantom reads

**Document Reference:** Section 3 (Architecture Design - missing concurrency specification), Section 5 (API Design - no idempotency mention)

---

### C-3: Missing Non-Functional Requirement Specifications for Production Viability

**Issue Description:**
The design lacks critical NFR specifications required for production operations:

1. **No SLA targets for translation latency**: Line 212 states "平均500ms以内" but no P50/P95/P99 breakdown or worst-case upper bound
2. **No throughput requirements**: Missing messages/second capacity targets for different user scales (5-20 person meetings vs 10,000-viewer events)
3. **No monitoring strategy**: No mention of performance metrics collection, alerting thresholds, or dashboards (only logging strategy in lines 194-197)
4. **No capacity planning model**: Auto-scaling triggers (line 223) use CPU % but ignore memory, WebSocket connection count, or Translation API quota
5. **No data retention clarity**: Line 219 mentions "30日間" for translation history but doesn't address Session/Participant archival or backup retention

**Performance Impact:**
- **Unpredictable latency**: Without P95/P99 targets, 5% of requests could exceed 5 seconds while meeting "average 500ms"
- **Scaling failures**: CPU-only auto-scaling can miss memory exhaustion from WebSocket connections or Redis cache bloat
- **Incident response delays**: Missing monitoring delays detection of Translation API quota exhaustion or database connection pool saturation

**Recommended Solution:**
1. **SLA Definition**: Specify P50 < 300ms, P95 < 800ms, P99 < 2s for translation latency; separate SLAs for voice (P95 < 1s) vs text (P95 < 500ms)
2. **Throughput Targets**: Define 50 msg/s for small meetings, 500 msg/s for medium events, 2000 msg/s for large events (with corresponding infrastructure sizing)
3. **Monitoring Requirements**:
   - Application metrics: translation_latency, websocket_connection_count, api_quota_remaining
   - Infrastructure metrics: ECS task memory %, RDS connection pool usage, Redis memory usage
   - Alerts: P95 latency > 1s, error rate > 1%, API quota < 10%
4. **Capacity Model**: Document linear scaling assumptions (e.g., 1 ECS task per 100 concurrent sessions, 1 Redis node per 10k cached translations)

**Document Reference:** Section 7 (Non-functional Requirements - incomplete)

---

### C-4: N+1 Query Problem in Translation Distribution to Participants

**Issue Description:**
The chat translation flow (lines 95-99) broadcasts translated messages to "all participants" but the implementation pattern will cause N+1 queries:
```python
# Implied implementation from data flow description
participants = db.query(Participant).filter(session_id=session_id).all()  # Query 1
for participant in participants:  # N queries
    language = db.query(User).get(participant.user_id).preferred_language
    translated_text = translate(original_text, language)
    send_to_websocket(participant.websocket_id, translated_text)
```

For a 20-person meeting, this creates 21 database queries per message. At 10 messages/minute, this generates 3,600 queries/hour from one session.

**Performance Impact:**
- **Database overload**: 1,000 concurrent sessions × 10 msg/min × 21 queries = 210,000 queries/hour = 58 queries/second just for chat translation
- **Latency spikes**: Sequential queries add 10-20ms × 20 = 200-400ms overhead, potentially violating 500ms average latency target (line 212)
- **Connection pool exhaustion**: PostgreSQL RDS connection limit (e.g., 150 for db.t3.medium) exhausted during peak usage

**Recommended Solution:**
1. **Batch query**: Use JOIN to fetch all participant languages in single query:
   ```sql
   SELECT p.user_id, u.preferred_language, p.websocket_id
   FROM Participant p JOIN User u ON p.user_id = u.id
   WHERE p.session_id = ? AND p.ended_at IS NULL
   ```
2. **Session-level caching**: Cache participant metadata (user_id → language mapping) in Redis with session TTL, invalidate on participant join/leave
3. **Translation batch**: Group participants by target language (e.g., 5 users want English, 3 want Japanese) → make 2 Translation API calls instead of 8
4. **Connection pooling**: Configure SQLAlchemy pool_size=50, max_overflow=20, pool_pre_ping=True to prevent connection starvation

**Document Reference:** Section 3 (Data Flow - lines 95-99)

---

### C-5: Synchronous Translation API Calls in High-Throughput WebSocket Path

**Issue Description:**
The real-time translation flow (lines 87-93) calls Google Translation API synchronously:
```
2. Translation Service: 音声をテキストに変換（Speech-to-Text）
3. Translation Service: テキストを翻訳（Google Translation API）
```

This blocks the WebSocket event loop for 200-500ms per message (Google Translation API latency), preventing the FastAPI server from processing other WebSocket messages during this time.

**Performance Impact:**
- **Head-of-line blocking**: A single slow translation (e.g., 1-second API timeout) blocks all subsequent messages in the same worker thread
- **Throughput bottleneck**: Single-threaded event loop limits throughput to ~2-5 translations/second per worker, requiring 100-250 workers for 500 msg/s target
- **Cascading failures**: Translation API slowdown (e.g., regional outage) causes WebSocket message queue buildup → memory exhaustion → service crash

**Recommended Solution:**
1. **Async API client**: Replace synchronous google-cloud-translate with aiohttp-based async client to enable concurrent translation requests
2. **Worker pool**: Offload translation to dedicated worker pool (e.g., Celery + Redis queue) with 50-100 workers, return immediately from WebSocket handler
3. **Circuit breaker**: Implement circuit breaker pattern (e.g., using pybreaker library) to fail fast when Translation API error rate > 10% or latency > 2s
4. **Timeout configuration**: Set aggressive timeouts (connect: 1s, read: 2s) with fallback to cached similar translations or "translation unavailable" placeholder

**Document Reference:** Section 3 (Data Flow - lines 87-93), Section 6 (Implementation - mentions retry but no async design)

---

### C-6: Missing Database Index Design for Primary Access Patterns

**Issue Description:**
The data model (Section 4) defines table schemas but provides no index specifications beyond implied primary keys and foreign keys. Critical missing indexes:

1. **TranslationHistory.session_id**: Unindexed FK for `/api/sessions/{id}/history` query (line 170)
2. **TranslationHistory.translated_at**: No index for time-range queries (e.g., "last 24 hours")
3. **Participant(session_id, joined_at)**: Composite index missing for active participant queries
4. **CustomGlossary(organization_id, source_language, target_language)**: No index for term lookup during translation

**Performance Impact:**
- **Sequential scans**: PostgreSQL query planner will use sequential scan for TranslationHistory queries when session has > 1,000 records, causing 10-100x slowdown
- **History API timeout**: `/api/sessions/{id}/history` will exceed 1-second SLA (line 214) for sessions with > 5,000 translation records
- **Translation delay**: Glossary term lookup adds 50-200ms per translation when scanning 10,000+ organization terms

**Recommended Solution:**
1. **Create covering indexes**:
   ```sql
   CREATE INDEX idx_translation_history_session_time
     ON TranslationHistory(session_id, translated_at DESC)
     INCLUDE (original_text, translated_text, original_language, target_language);

   CREATE INDEX idx_participant_session_active
     ON Participant(session_id, joined_at)
     WHERE ended_at IS NULL;

   CREATE INDEX idx_glossary_lookup
     ON CustomGlossary(organization_id, source_language, target_language, source_term);
   ```
2. **Index monitoring**: Track index usage with pg_stat_user_indexes, drop unused indexes after 30 days
3. **VACUUM strategy**: Configure autovacuum_vacuum_scale_factor=0.05 for high-churn tables (TranslationHistory, Participant)

**Document Reference:** Section 4 (Data Model - no index specifications)

---

### C-7: Single Point of Failure in Session State Management

**Issue Description:**
The architecture diagram (lines 45-66) shows Redis as cache layer but doesn't specify clustering/replication configuration. The Session Management Service (lines 76-79) stores "Session Cache" in Redis, implying critical session state (WebSocket connection mapping, active participant list) resides only in Redis.

If Redis node fails:
- All active WebSocket connections lose session context
- New join attempts fail (no session lookup)
- Translation Service cannot route messages to participants

The 99.9% availability target (line 222) allows 43 minutes of downtime per month, but single-instance Redis has MTTR of 5-15 minutes during failover.

**Performance Impact:**
- **Session disruption**: All 1,000 concurrent sessions disconnect simultaneously during Redis failover
- **Thundering herd**: Automatic client reconnection (line 192) causes 1,000 sessions × 20 participants = 20,000 simultaneous reconnect attempts, overwhelming API gateway
- **Data loss**: In-flight translation messages (queued in Redis) are lost during failover

**Recommended Solution:**
1. **Redis Cluster**: Deploy AWS ElastiCache Redis in cluster mode with 3 nodes (1 primary, 2 replicas) across availability zones
2. **Persistent session state**: Write critical session state (participant list, language preferences) to PostgreSQL synchronously, use Redis only for hot cache (WebSocket connection IDs)
3. **Graceful degradation**: On Redis failure, fall back to PostgreSQL queries with 200ms timeout, return error if DB also unavailable
4. **Backpressure mechanism**: Implement connection rate limiting (max 100 reconnects/second per worker) with exponential backoff to prevent thundering herd

**Document Reference:** Section 3 (Architecture - line 61, no Redis HA specification)

---

### C-8: Missing Transaction Isolation Strategy for Concurrent Document Edits

**Issue Description:**
The Document Service (lines 81-84) supports "共同編集の同期処理" (collaborative editing synchronization) but provides no details on conflict resolution, operational transformation, or transaction isolation levels. Without proper concurrency control:

1. **Lost updates**: User A and User B simultaneously edit the same document paragraph → last write wins, silently discarding one user's changes
2. **Read-modify-write race**: User A reads document v1, User B updates to v2, User A saves based on v1 → User B's changes overwritten
3. **Version number collision**: Two concurrent edits both increment version from 3 to 4 → version history corruption

**Performance Impact:**
- **User trust loss**: Silent data loss from concurrent edits causes users to abandon collaborative features
- **Conflict resolution overhead**: Implementing post-hoc conflict detection requires full document diffing (O(n²) for document length n)
- **Lock contention**: Naive row-level locking on document table blocks all readers during edit operations, violating real-time expectations

**Recommended Solution:**
1. **Operational Transformation (OT) or CRDT**: Implement OT library (e.g., ot.py) for character-level concurrent edit resolution without locking
2. **Optimistic locking with version**: Add version BIGINT column to Document table, increment on each update:
   ```sql
   UPDATE Document SET content = ?, version = version + 1
   WHERE id = ? AND version = ?  -- Atomic compare-and-swap
   ```
   Return 409 Conflict on version mismatch, client rebases changes on latest version
3. **Row-level locking for metadata**: Use SELECT FOR UPDATE SKIP LOCKED for document metadata updates (title, permissions) to prevent deadlocks
4. **WebSocket-based coordination**: Broadcast edit intentions (character insertions/deletions) via WebSocket before DB commit, allow 100ms conflict resolution window

**Document Reference:** Section 3 (Document Service - line 84, no concurrency mechanism specified)

---

## Significant Issues (Severity: Medium-High)

### S-1: Missing Translation Cache Invalidation Strategy

**Issue Description:**
The design mentions "翻訳結果をキャッシュ" (caching translation results, line 98) and Redis as cache layer (line 31, 61) but provides no cache invalidation or TTL strategy. Two critical scenarios:

1. **Glossary updates**: Organization updates CustomGlossary term (line 180: PUT /api/glossaries/{id}) but cached translations using old terminology remain in Redis
2. **Stale translation**: Translation API improves output quality (e.g., Google updates neural model) but cached translations serve outdated results indefinitely

**Performance Impact:**
- **Cache pollution**: Without TTL, Redis memory grows unbounded until eviction policy (e.g., LRU) randomly discards active session data
- **Inconsistent translations**: Same source text translated differently within 5 minutes due to glossary update, confusing users
- **Cache miss storm**: Setting aggressive TTL (e.g., 1 hour) causes all 1,000 sessions to experience cache misses simultaneously at hour boundaries

**Recommended Solution:**
1. **Tiered TTL strategy**:
   - Glossary-affected translations: 24-hour TTL, invalidate by org_id + language_pair key pattern on glossary update
   - Non-glossary translations: 7-day TTL (balance freshness vs API cost)
   - Session-specific cache: Expire 1 hour after session ends
2. **Cache key design**: `translation:{org_id}:{source_lang}:{target_lang}:{hash(source_text)}` to enable pattern-based invalidation
3. **Lazy invalidation**: On glossary update, set invalidation marker in Redis, purge matching keys asynchronously via background worker
4. **Memory limits**: Configure Redis maxmemory=8GB with allkeys-lru eviction policy, monitor eviction rate (target < 1% of keys)

**Document Reference:** Section 3 (Translation Service - line 73, no invalidation spec)

---

### S-2: Unbounded Query in Translation History API Without Pagination

**Issue Description:**
The REST API endpoint `GET /api/sessions/{id}/history` (line 170) retrieves translation history with no documented pagination, filtering, or result limit. For a 2-hour international event session (10,000 viewers, 200 chat messages), this query returns 2,000,000 translation records (200 messages × 10,000 target viewers).

**Performance Impact:**
- **Memory exhaustion**: Loading 2M records × 500 bytes average (TEXT columns) = 1GB per request, OOM-killing ECS task
- **Network saturation**: Transferring 1GB JSON response takes 8+ seconds on 1Gbps link, violating 1-second API SLA (line 214)
- **Database load**: Full table scan with 2M rows locks PostgreSQL I/O, degrading concurrent queries by 10-50x

**Recommended Solution:**
1. **Mandatory pagination**: Add query parameters `?limit=100&offset=0`, reject requests without pagination (HTTP 400)
2. **Cursor-based pagination**: Use translated_at + id as cursor for stable pagination across concurrent inserts:
   ```sql
   SELECT * FROM TranslationHistory
   WHERE session_id = ? AND (translated_at, id) > (?, ?)
   ORDER BY translated_at, id LIMIT 100
   ```
3. **Result limits**: Hard-cap at 1,000 records per request, require time-range filtering for sessions > 10,000 records
4. **Streaming API**: Offer alternative WebSocket endpoint for real-time history streaming during active sessions (avoids batch query)

**Document Reference:** Section 5 (API Design - line 170)

---

### S-3: Missing Connection Pooling Configuration for External Services

**Issue Description:**
The design mentions Google Cloud Translation API usage (lines 36, 71-72) but provides no connection pooling, rate limiting, or quota management strategy. Google Translation API has quotas:
- Default: 500,000 characters/minute
- Maximum: 10M characters/minute (requires quota increase)

Without connection pooling:
- Each translation request creates new HTTPS connection → TCP handshake + TLS negotiation overhead (50-100ms)
- Concurrent requests from 1,000 sessions exhaust socket limits (default ulimit: 1,024 file descriptors)

**Performance Impact:**
- **Quota exhaustion**: Sudden traffic spike (e.g., viral event with 10,000 viewers) consumes full quota in minutes, causing total translation service outage
- **Latency overhead**: Connection establishment adds 100ms to every translation, doubling end-to-end latency from 500ms to 1s
- **Socket exhaustion**: Worker processes exhaust file descriptors, causing "Too many open files" errors and request failures

**Recommended Solution:**
1. **HTTP connection pooling**: Configure google-cloud-translate client with persistent connection pool:
   ```python
   import google.cloud.translate_v3 as translate
   client = translate.TranslationServiceClient()
   # Uses default gRPC connection pooling (10 channels)
   ```
2. **Client-side rate limiting**: Implement token bucket rate limiter (450,000 chars/min with 10% safety margin), queue excess requests with 5-second timeout
3. **Quota monitoring**: Track remaining quota via Cloud Monitoring API, trigger alert at 80% usage, enable automatic quota increase request
4. **Connection lifecycle**: Set HTTP keep-alive timeout to 60s (matches Google API idle timeout), max connections per worker = 50
5. **Fallback configuration**: Pre-configure DeepL API connection pool (mentioned as fallback in line 191) with same rate limiting strategy

**Document Reference:** Section 6 (Implementation - line 191 mentions fallback, no pooling strategy)

---

### S-4: Inefficient WebSocket Broadcast Pattern for Large Events

**Issue Description:**
The translation distribution flow (lines 93-94: "全参加者にWebSocketで配信") broadcasts every translation to all session participants. For large events (10,000 viewers, line 19), this creates:
- 10,000 WebSocket send operations per translated message
- 100 messages/minute × 10,000 viewers = 1,000,000 message deliveries/minute = 16,666 msg/sec

This architectural pattern doesn't scale beyond 1,000 concurrent participants on typical ECS task (2 vCPU, 4GB RAM).

**Performance Impact:**
- **Memory pressure**: Buffering 10,000 outbound messages (avg 500 bytes) = 5MB per translation event, causing memory spikes and GC pauses
- **CPU saturation**: WebSocket message serialization (JSON encoding + compression) for 10,000 connections consumes 500-1000ms CPU time, blocking event loop
- **Latency inflation**: Last participant receives message 5-10 seconds after first participant, violating real-time expectations

**Recommended Solution:**
1. **Publish-Subscribe pattern**: Replace direct WebSocket broadcast with Redis Pub/Sub:
   - Translation Service publishes to Redis channel: `session:{session_id}:translations`
   - Multiple WebSocket server instances subscribe and distribute to local connections only
   - Horizontal scaling: 10 WebSocket servers × 1,000 connections each = 10,000 capacity
2. **Message batching**: Group translations by target language, broadcast to language-specific channels to reduce redundant encoding:
   - Channel `session:{id}:lang:en` for English viewers
   - Channel `session:{id}:lang:ja` for Japanese viewers
3. **Selective subscription**: For view-only participants (non-speakers in large events), offer "summary mode" with 1 translation/5 seconds instead of real-time
4. **WebSocket load balancing**: Use AWS ALB WebSocket support with sticky sessions (source IP affinity), distribute 10,000 connections across 10+ ECS tasks

**Document Reference:** Section 3 (Data Flow - line 94), Section 7 (Scalability - line 224 mentions 1,000 sessions but unclear if total sessions or per-node)

---

### S-5: Missing Fallback Translation Engine Coordination Logic

**Issue Description:**
The implementation policy (line 191) states "Translation API失敗時: フォールバック翻訳エンジン（DeepL API）を使用" (use DeepL API as fallback) but provides no specification for:
- Failure detection criteria (timeout? specific HTTP error codes?)
- Fallback triggering logic (per-request? circuit breaker?)
- Consistency guarantees (Google and DeepL produce different translations for same input)
- Capacity planning (is DeepL API quota sufficient for failover traffic?)

**Performance Impact:**
- **Thundering herd on fallback**: All 1,000 concurrent sessions simultaneously failover to DeepL API during Google Translation outage, exhausting DeepL quota in seconds
- **Inconsistent user experience**: Same conversation translated by Google (pre-failure) and DeepL (post-failure), confusing participants with different terminology
- **Increased latency**: DeepL API has 800ms average latency vs Google's 300ms, degrading P95 latency from 500ms to 1.2s

**Recommended Solution:**
1. **Gradual failover**: Implement circuit breaker with half-open state:
   - Closed (healthy): 100% Google API
   - Half-open (testing): 90% Google, 10% DeepL to verify fallback works
   - Open (failed): 100% DeepL
   - Auto-recovery: After 60 seconds in open state, transition to half-open
2. **Failure criteria**: Trigger failover when Google API error rate > 10% or P95 latency > 2 seconds over 60-second window
3. **Quota management**: Pre-purchase DeepL quota = 50% of Google quota (handles partial failover, not full 100% traffic)
4. **Translation consistency**: Maintain session-level affinity (entire session uses same engine), display banner "Translation engine changed" on fallback
5. **Monitoring**: Track fallback trigger rate, DeepL quota consumption, latency differential between engines

**Document Reference:** Section 6 (Implementation - line 191)

---

## Moderate Issues (Severity: Medium)

### M-1: Inefficient Full-Text Search Strategy in Elasticsearch Integration

**Issue Description:**
The architecture includes Elasticsearch 8 for "Translation History Search" (line 32, 62) but provides no indexing strategy, query optimization, or data synchronization approach. Typical inefficiencies:

1. **Full document indexing**: Indexing entire TranslationHistory records (including TEXT columns) causes index size = 2-3x database size
2. **No search field prioritization**: Searching across all fields (original_text, translated_text, speaker name, session title) produces low-relevance results
3. **Missing data sync strategy**: How are new translations indexed? (Kafka CDC? Polling? API-driven?)

**Performance Impact:**
- **Storage cost**: Elasticsearch cluster storage = 3x PostgreSQL size for full history index
- **Indexing latency**: Synchronous indexing adds 50-100ms to translation write path, degrading real-time performance
- **Query quality**: No scoring weights causes irrelevant results (e.g., common words like "hello" match millions of documents)

**Recommended Solution:**
1. **Selective field indexing**: Index only original_text, translated_text, session_id, translated_at; exclude speaker_id, language codes
2. **Field weighting**: Configure boosting: original_text^3, translated_text^2, session.title^1 for relevance tuning
3. **Asynchronous indexing**: Use Kafka CDC (Debezium PostgreSQL connector) to stream TranslationHistory changes to Elasticsearch with 5-second lag SLA
4. **Index partitioning**: Use time-based indices (monthly: translations-2025-01) with ILM policy (delete after 90 days, matching retention policy)
5. **Query optimization**: Use bool queries with must (session_id) + should (text match) structure to reduce search scope

**Document Reference:** Section 2 (Technology Stack - line 32), Section 3 (Data Layer - line 62)

---

### M-2: Missing Capacity Planning for Translation API Quota Consumption

**Issue Description:**
The design specifies usage of Google Cloud Translation API (line 36) but provides no analysis of quota requirements vs. expected traffic. Given the scale targets:
- 1,000 concurrent sessions (line 224)
- Average 10 messages/minute per session (inferred from "real-time chat")
- Average message length: 100 characters (typical chat message)

Expected consumption:
- Peak load: 1,000 sessions × 10 msg/min × 100 chars × 50 target languages = **50M characters/minute**
- Google's maximum quota: 10M characters/minute

The design exceeds quota by 5x at peak load.

**Performance Impact:**
- **Service outage**: API quota exhaustion causes complete translation service failure (no fallback queue)
- **Unpredictable costs**: Google Translation API charges $20 per 1M characters → $1,000 per minute at peak = $43,200/hour
- **Throttling cascades**: Rate limiting by Google API causes request backlog → WebSocket message queue overflow → client disconnections

**Recommended Solution:**
1. **Quota budgeting**: Calculate required quota per user tier:
   - Small meetings (5-20 users): 200K chars/min
   - Medium events (100-500 users): 2M chars/min
   - Large events (1,000-10,000 users): 50M chars/min
2. **Request Google quota increase**: Submit quota increase request to 50M chars/min (requires business justification, 5-10 business days processing)
3. **Tiered translation**: Offer quality levels:
   - Real-time: Google Neural MT (high cost, low latency)
   - Batch: DeepL API (lower cost, 2-second latency)
   - Economy: Microsoft Translator (lowest cost, community glossary only)
4. **Client-side batching**: Accumulate messages for 500ms, translate as single batch to reduce API call overhead
5. **Cost monitoring**: Alert when daily spend exceeds $1,000, implement spending cap circuit breaker

**Document Reference:** Section 7 (Non-functional Requirements - missing cost/quota analysis)

---

### M-3: Suboptimal Redis Cache Key Design Without Namespace Isolation

**Issue Description:**
The design uses Redis for multiple purposes (line 61: "Session Cache, Translation Cache") but provides no cache key naming convention or namespace strategy. Potential collisions:

- Session ID (UUID): `550e8400-e29b-41d4-a716-446655440000`
- User ID (UUID): `550e8400-e29b-41d4-a716-446655440000` (same UUID by chance)
- Translation cache key: `"Hello world"` (string as key)

Without namespacing:
- `GET 550e8400...` retrieves session data when user data expected (type mismatch error)
- `EXPIRE "Hello world" 3600` expires translation cache unintentionally affects unrelated key

**Performance Impact:**
- **Cache poisoning**: Overlapping keys cause wrong data type retrieval (e.g., GET returns string when hash expected), causing application errors
- **Debugging complexity**: Cache issues manifest as intermittent data corruption, difficult to trace without key pattern analysis
- **Inefficient eviction**: Cannot selectively purge "all session caches" or "all translation caches" without scanning entire keyspace (O(n) operation)

**Recommended Solution:**
1. **Hierarchical key naming**:
   ```
   session:{session_id}:metadata          # Hash
   session:{session_id}:participants      # Set
   translation:{org_id}:{lang_pair}:{hash} # String
   user:{user_id}:profile                 # Hash
   websocket:{connection_id}:session      # String
   ```
2. **Key expiration by type**: Session keys TTL = session duration + 1 hour, translation keys TTL = 7 days, user profile TTL = 24 hours
3. **Namespace monitoring**: Track key count by prefix using `SCAN` with pattern matching, alert if any namespace exceeds 100K keys
4. **Atomic operations**: Use Redis transactions (MULTI/EXEC) for related keys (e.g., session metadata + participant set) to prevent partial updates

**Document Reference:** Section 3 (Data Layer - line 61, no cache schema specified)

---

### M-4: Missing Timeout Configuration for External API Calls

**Issue Description:**
The error handling policy (line 190) specifies "3回リトライ（指数バックオフ）" for API integration errors but doesn't define timeout values for individual requests. The design mentions multiple external services:
- Google Cloud Translation API (line 36)
- Speech-to-Text API (implied from line 90)
- DeepL API fallback (line 191)

Without timeouts:
- A slow API response (e.g., Google Translation API p99 latency = 5 seconds) blocks WebSocket handler indefinitely
- Network partition causes HTTP client to wait for TCP timeout (default 60-120 seconds)

**Performance Impact:**
- **Thread exhaustion**: Workers blocked on slow API calls cannot process new WebSocket events, reducing effective throughput by 50-90%
- **Cascading failures**: Upstream slowness propagates to all dependent services, violating 500ms average latency target (line 212)
- **User abandonment**: 30-second page load time during API timeout causes users to abandon sessions

**Recommended Solution:**
1. **Aggressive timeout configuration**:
   ```python
   translation_client.translate(
       text=text,
       timeout=2.0,  # 2-second hard deadline
       retry=retry.Retry(
           initial=0.1, maximum=1.0, multiplier=2, deadline=5.0  # Total 5-second budget including retries
       )
   )
   ```
2. **Timeout budget by operation type**:
   - Real-time chat translation: 1-second total budget (500ms per request, 2 retries)
   - Document translation: 30-second budget (10-second per request, 3 retries)
   - Glossary term lookup: 200ms budget (no retries, fail to default translation)
3. **Circuit breaker integration**: Open circuit when timeout rate > 5% over 60-second window
4. **Monitoring**: Track timeout events per API endpoint, alert if timeout rate > 1%

**Document Reference:** Section 6 (Implementation - line 190, no timeout specification)

---

## Positive Observations

1. **Appropriate caching layer**: Redis integration for session and translation caching is well-suited for read-heavy access patterns
2. **Retry strategy**: Exponential backoff retry policy (line 190) prevents thundering herd on transient failures
3. **Auto-scaling awareness**: CPU-based auto-scaling (line 223) provides foundation for horizontal scaling (requires multi-metric enhancement per C-3)
4. **Latency targets defined**: 500ms average translation latency (line 212) provides measurable performance goal (requires P95/P99 breakdown per C-3)
5. **Failover strategy**: DeepL API fallback (line 191) demonstrates resilience thinking (requires coordination logic per S-5)

---

## Summary of Required Actions by Priority

### Immediate (Pre-Production Blockers)
1. **C-1**: Implement TranslationHistory table partitioning and 30-day archival policy
2. **C-2**: Add Participant table UNIQUE constraint and Redis-based idempotency for translations
3. **C-3**: Define comprehensive SLA targets (P50/P95/P99), monitoring strategy, and capacity planning model
4. **C-4**: Refactor participant query to single JOIN, implement Redis session cache
5. **C-5**: Convert Translation API calls to async pattern with worker pool
6. **C-6**: Create database indexes for TranslationHistory, Participant, CustomGlossary
7. **C-7**: Deploy Redis Cluster with 3-node HA configuration
8. **C-8**: Implement optimistic locking with version numbers for Document collaborative editing

### High Priority (First Month Post-Launch)
9. **S-1**: Design translation cache invalidation strategy with tiered TTL
10. **S-2**: Add mandatory pagination to translation history API
11. **S-3**: Configure connection pooling for Translation API clients
12. **S-4**: Implement Redis Pub/Sub for WebSocket broadcast scaling
13. **S-5**: Build circuit breaker for Google/DeepL Translation API fallback

### Medium Priority (Performance Optimization Phase)
14. **M-1**: Optimize Elasticsearch indexing with selective fields and async CDC
15. **M-2**: Calculate Translation API quota requirements, submit increase request
16. **M-3**: Standardize Redis cache key naming with namespace isolation
17. **M-4**: Add timeout configuration to all external API clients

---

## Document Evaluation Summary

**Document Completeness**: 70% - Architecture and data model are well-defined, but critical NFR specifications (SLAs, monitoring, capacity planning) and concurrency control mechanisms are missing.

**Performance Risk Level**: **High** - The design contains 8 critical issues that could cause production outages or severe performance degradation under expected load. Most critical: unbounded data growth (C-1), missing race condition protection (C-2), synchronous I/O in hot path (C-5).

**Recommended Next Steps**:
1. Address all critical issues (C-1 through C-8) before production deployment
2. Conduct load testing with 1,000 concurrent sessions to validate capacity planning assumptions
3. Document detailed SLAs, monitoring dashboards, and incident response playbooks (C-3)
4. Review concurrency control strategy with database architect (C-2, C-8)
