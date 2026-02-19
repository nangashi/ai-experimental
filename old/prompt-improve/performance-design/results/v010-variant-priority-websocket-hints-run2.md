# Performance Design Review - Polyglot Connect システム設計書

## Document Structure Analysis

The design document comprehensively covers:
- System overview and use case definition (Section 1)
- Technology stack specification (Section 2)
- Architecture design with component responsibilities (Section 3)
- Data model with table schemas (Section 4)
- API design including WebSocket events and REST endpoints (Section 5)
- Implementation policies (error handling, logging, testing, deployment) (Section 6)
- Non-functional requirements including performance targets (Section 7)

Missing or incomplete architectural concerns:
- Real-time communication capacity planning and WebSocket connection scaling strategy
- Database indexing strategy for frequently queried data
- Caching invalidation and expiration policies
- Detailed resource capacity planning (connection pools, database connections, memory limits)
- Concurrency control mechanisms for shared resources

---

## Performance Issue Detection

### CRITICAL ISSUES

#### C1: Translation API Rate Limiting Not Addressed - System-Wide Bottleneck Risk

**Issue**: The design relies on Google Cloud Translation API as the primary translation engine with DeepL as fallback (Section 6), but lacks any rate limiting strategy, quota management, or graceful degradation mechanism. For a system supporting 1,000-10,000 concurrent users in international events (Section 1), uncontrolled API calls could result in:
- Immediate quota exhaustion causing complete service failure
- Cascading failures when the fallback DeepL API also hits quota limits
- Unpredictable translation costs without budget controls

**Impact**: Under peak load scenarios (international events with 10,000 viewers), translation API quotas could be exhausted within minutes, causing complete platform failure. Without request throttling or queuing, all concurrent translation requests would fail simultaneously.

**Recommendations**:
1. Implement API quota management with monitoring and alerting at 70%, 85%, and 95% thresholds
2. Design request queuing and prioritization (real-time voice > chat > document translation)
3. Add circuit breaker patterns for both primary and fallback translation APIs
4. Establish per-session and per-user rate limits to prevent quota exhaustion
5. Define graceful degradation strategy (e.g., disable low-priority features when approaching quota limits)

**References**: Section 3 (Translation Service), Section 6 (Error Handling), Section 7 (NFR - Performance targets defined but quota management missing)

---

#### C2: Unbounded Translation History Growth Without Data Lifecycle Management

**Issue**: The TranslationHistory table (Section 4) uses BIGSERIAL for auto-incrementing IDs but lacks partitioning strategy, archival policies, or retention enforcement mechanisms. With 30-day retention mentioned in security requirements (Section 7), but no implementation of automated deletion:
- Table size will grow unbounded (estimated 100M+ rows in 6 months for 1,000 concurrent sessions)
- Query performance will degrade exponentially over time
- Storage costs will escalate without control

**Impact**: After 6 months of operation at 1,000 concurrent sessions, the TranslationHistory table could exceed 100 million rows, causing:
- Full table scans during unoptimized queries, blocking database operations
- Index maintenance overhead increasing write latency by 10-50x
- Database storage exhaustion leading to complete system failure

**Recommendations**:
1. Implement table partitioning by translated_at (monthly partitions)
2. Create automated archival jobs to move >30-day data to cold storage (S3 + Athena for historical analysis)
3. Add database-level retention policies or scheduled cleanup jobs
4. Implement data lifecycle monitoring with alerts for partition size thresholds
5. Consider time-series database (TimescaleDB) for translation history if query patterns support it

**References**: Section 4 (TranslationHistory table schema), Section 7 (Security - 30-day retention policy defined but not implemented)

---

### SIGNIFICANT ISSUES

#### S1: N+1 Query Problem in Participant Language Retrieval

**Issue**: The chat translation flow (Section 3) states "各参加者の言語に翻訳" (translate to each participant's language), requiring participant language lookup. With current schema design (Participant table in Section 4), retrieving languages for all participants in a session likely involves:
- One query to fetch participant list per session
- Iterative queries to fetch language preference per participant
- This creates N+1 query problem for sessions with 5-20 participants

**Impact**: For a 20-participant session, translation of each message requires 21 database queries (1 for participant list + 20 for individual language lookups), adding 20-100ms latency per message. Under high message frequency (10 messages/second), this generates 200+ queries/second per session, potentially saturating database connections.

**Recommendations**:
1. Modify participant retrieval to use JOIN query fetching all languages in single query:
   ```sql
   SELECT p.user_id, p.language FROM Participant p WHERE p.session_id = ?
   ```
2. Cache participant language preferences per session in Redis with session lifecycle TTL
3. Invalidate cache only on participant join/leave events
4. Monitor query execution plans to verify single-query optimization

**References**: Section 3 (Chat Translation Flow - step 2), Section 4 (Participant table schema)

---

#### S2: Missing Database Indexes on High-Frequency Query Paths

**Issue**: The data model (Section 4) defines table schemas but does not specify any indexes beyond primary keys. Critical query paths lacking indexes include:
- `TranslationHistory.session_id` - queried on every history retrieval (GET /api/sessions/{id}/history)
- `Participant.session_id` - queried on every message translation to fetch participant list
- `Participant.user_id` - queried for user session participation lookup
- `CustomGlossary.organization_id` + `source_language` + `target_language` - queried on every translation request with custom glossary

**Impact**: Without indexes, each translation history retrieval performs full table scan. For a 10,000-row TranslationHistory table, query latency increases from <10ms (indexed) to 500-2000ms (full scan). Under concurrent load (100 simultaneous history requests), database CPU utilization would spike to 100%, blocking all operations.

**Recommendations**:
1. Add composite index on `TranslationHistory(session_id, translated_at DESC)` for history retrieval queries
2. Add index on `Participant(session_id)` for participant list lookups
3. Add index on `Participant(user_id)` for user session queries
4. Add composite index on `CustomGlossary(organization_id, source_language, target_language)` for glossary lookups
5. Monitor index usage with database query performance tools (pg_stat_user_indexes) and adjust as needed

**References**: Section 4 (All table schemas), Section 5 (API endpoints requiring these queries)

---

#### S3: Synchronous Translation API Calls Blocking WebSocket Message Delivery

**Issue**: The real-time translation flow (Section 3) shows synchronous processing:
1. Receive message via WebSocket
2. Call Translation API (blocking)
3. Save to database (blocking)
4. Broadcast to participants

This synchronous design means that Translation API latency (average 500ms target per Section 7, but potentially 1-3 seconds under load or API throttling) directly blocks the WebSocket event loop, preventing:
- Processing of other incoming messages during translation
- Timely delivery of already-translated messages to other sessions
- Handling of connection lifecycle events (joins, disconnects)

**Impact**: If Translation API experiences 3-second latency spike (common during quota throttling or regional outages), the WebSocket server becomes unresponsive for all sessions. A single slow translation request can block message delivery for hundreds of concurrent sessions, creating cascading delays.

**Recommendations**:
1. Implement asynchronous translation processing using task queue (Celery + Redis)
2. WebSocket handler should immediately:
   - Acknowledge message receipt to sender
   - Enqueue translation task
   - Return control to event loop
3. Translation worker processes API calls asynchronously and broadcasts results when complete
4. Add timeout controls for translation tasks (5-second hard timeout with degraded response)
5. Monitor task queue depth and worker utilization to detect API performance degradation

**References**: Section 3 (Real-time translation flow, Chat translation flow), Section 7 (NFR - 500ms average translation latency)

---

#### S4: WebSocket Connection Scaling Strategy Not Defined

**Issue**: The design specifies WebSocket-based real-time communication (Section 2, 3) with target capacity of 1,000 concurrent sessions and 1,000-10,000 concurrent users for international events (Section 1, 7). However, there is no architectural strategy for:
- WebSocket connection distribution across multiple server instances
- Stateful connection management during horizontal scaling
- Broadcast fanout optimization for large-scale events (10,000 viewers receiving same translated content)
- Connection lifecycle management (heartbeat, timeout, graceful degradation under load)

**Impact**:
- Single WebSocket server instance typically supports 5,000-10,000 concurrent connections; target load approaches hardware limits
- Without connection state synchronization, horizontal scaling fails (users connected to different servers cannot communicate)
- Broadcast operations for 10,000-viewer events create O(N) fanout load, potentially saturating network bandwidth and CPU
- Connection failures during scaling events cause user disconnections and session disruptions

**Recommendations**:
1. **Horizontal Scaling Architecture**:
   - Implement Redis Pub/Sub or AWS EventBridge for cross-instance message routing
   - Design sticky session routing (ALB target group with cookie-based affinity) to maintain connection stability during scale-out
   - Add connection count monitoring per instance with auto-scaling trigger at 70% capacity (e.g., 7,000 connections per 10,000-connection instance)

2. **Broadcast Optimization**:
   - For large events (>100 viewers), implement room-based pub/sub pattern instead of point-to-point fanout
   - Cache translated content in Redis and distribute via CDN for static content delivery
   - Consider read replica pattern for high-fanout scenarios (single translation → multi-region distribution)

3. **Connection Management**:
   - Implement heartbeat mechanism (30-second ping/pong) to detect stale connections
   - Add graceful degradation (reject new connections when at 90% capacity, return 503 with retry-after header)
   - Design connection state persistence (Redis) for graceful server shutdown and connection migration

**References**: Section 1 (target scale: 1,000-10,000 concurrent users), Section 2 (WebSocket technology choice), Section 3 (Session Management Service - connection management responsibility undefined), Section 7 (NFR - 1,000 concurrent sessions target)

---

#### S5: Missing Translation Cache Invalidation and Expiration Strategy

**Issue**: Section 3 specifies "翻訳結果をキャッシュ" (cache translation results) in the chat translation flow, but the design lacks:
- Cache key design (how to handle same source text with different context/glossaries)
- Cache expiration policy (TTL strategy)
- Cache invalidation triggers (e.g., when custom glossary is updated)
- Cache size limits and eviction policy

**Impact**: Without cache expiration, stale translations persist indefinitely. If a custom glossary is updated (PUT /api/glossaries/{id} in Section 5), previously cached translations using old glossary terms will be served incorrectly. Without size limits, cache memory consumption grows unbounded, potentially exhausting available memory and causing Redis eviction of more critical session state data.

**Recommendations**:
1. Define cache key structure including context: `translation:{org_id}:{source_lang}:{target_lang}:{hash(source_text)}:{glossary_version}`
2. Set reasonable TTL (e.g., 24 hours for general translations, 1 hour for glossary-customized translations)
3. Implement cache invalidation on glossary updates (invalidate all keys matching `translation:{org_id}:*:*:*:{old_glossary_version}`)
4. Configure Redis maxmemory-policy (recommend `allkeys-lru` for translation cache)
5. Monitor cache hit rate and memory usage; adjust TTL based on usage patterns

**References**: Section 3 (Translation Service responsibilities, Chat translation flow step 3), Section 5 (Glossary management API)

---

### MODERATE ISSUES

#### M1: Missing Connection Pooling Configuration for External Services

**Issue**: The architecture relies on multiple external services (PostgreSQL, Redis, Elasticsearch, Google Translation API - Section 2), but Section 6 implementation policies do not specify connection pooling strategies. Without explicit connection pool limits:
- Database connections may be exhausted under load (PostgreSQL default max_connections = 100)
- Each FastAPI worker may create separate connection pools, multiplying total connections
- Translation API client connections lack reuse, adding TLS handshake overhead (50-100ms per request)

**Impact**: If deploying 10 FastAPI workers with default connection pool size (10 per worker), total database connections reach 100, exhausting the default PostgreSQL connection limit. Additional connection requests fail immediately, causing 500 errors for users. Under 500 QPS load, lack of Translation API connection pooling adds 25-50 seconds of cumulative TLS handshake overhead per second.

**Recommendations**:
1. Configure explicit connection pool sizes based on capacity planning:
   - PostgreSQL: Pool size = 5 per worker (50 total for 10 workers, leaving headroom for admin connections)
   - Redis: Pool size = 10 per worker (Redis supports higher concurrency)
   - HTTP connection pool for Translation API: 20 connections with keep-alive enabled
2. Set connection pool timeouts (max wait time 5 seconds, raise error if pool exhausted)
3. Monitor connection pool utilization metrics and adjust based on observed usage
4. Document connection pool configuration in deployment documentation

**References**: Section 2 (Technology stack - PostgreSQL, Redis, Elasticsearch, Google Translation API), Section 6 (Implementation policies - connection pooling not mentioned)

---

#### M2: Potential Race Conditions in Concurrent Translation Requests

**Issue**: The chat translation flow (Section 3) processes messages concurrently for multiple participants. When the same source message is sent simultaneously to multiple language targets, race conditions may occur:
- Multiple concurrent translation requests for the same source text
- Duplicate cache writes for identical translations
- Potential for inconsistent translation results if glossary is updated mid-request

Without explicit concurrency control (optimistic locking, idempotency keys, distributed locks), the system may:
- Waste Translation API quota on duplicate requests
- Create cache inconsistencies if concurrent writes complete in unpredictable order

**Impact**: In a 20-participant session with 10 different target languages, each message generates 10 concurrent translation requests. If 5 participants use the same target language, the system may execute 5 duplicate Translation API calls instead of 1, multiplying API costs by 5x. Under high message frequency (10 messages/second), this represents 40 wasted API calls per second per session.

**Recommendations**:
1. Implement distributed lock (Redis SETNX) for cache-miss scenarios:
   - Before calling Translation API, acquire lock on cache key
   - If lock acquisition fails, wait briefly and retry cache lookup (likely populated by concurrent request)
   - Release lock after cache write
2. Add idempotency keys to translation requests based on content hash
3. Consider request deduplication at application layer (batch concurrent requests for same source text)
4. For glossary updates, use versioning to ensure consistency (include glossary_version in cache key as recommended in S5)

**References**: Section 3 (Chat translation flow - concurrent translation to multiple languages), Section 4 (TranslationHistory table - no optimistic locking version field)

---

#### M3: Elasticsearch Indexing Strategy for Translation History Search Not Defined

**Issue**: Section 2 specifies Elasticsearch 8 for translation history search, and Section 5 defines `GET /api/sessions/{id}/history` endpoint, but the design does not specify:
- What fields are indexed in Elasticsearch (full-text search on original_text, translated_text, or both?)
- Indexing delay and synchronization strategy (real-time vs. batch indexing)
- How search results are ranked and filtered
- Query performance targets for search operations

**Impact**: Without explicit indexing strategy, developers may implement inefficient full-text indexing on both original and translated text, doubling index size and slowing search queries. If using synchronous indexing (blocking translation flow to index in Elasticsearch), translation latency increases by 50-100ms per message. Unbounded search queries without pagination could return 100,000+ results, causing memory exhaustion.

**Recommendations**:
1. Define explicit indexing strategy:
   - Index only searchable fields (original_text, speaker_id, session_id, translated_at)
   - Use asynchronous batch indexing (every 10 seconds or 100 records, whichever comes first)
   - Implement pagination for search results (max 100 results per page)
2. Design search query structure (e.g., match query on original_text with session_id filter)
3. Add search performance target to NFR (e.g., 95th percentile search latency <500ms)
4. Monitor Elasticsearch cluster health and indexing lag

**References**: Section 2 (Elasticsearch 8 for translation history search), Section 5 (API endpoint GET /api/sessions/{id}/history)

---

#### M4: Insufficient Monitoring Coverage for Performance Bottleneck Detection

**Issue**: Section 6 defines logging policies (structured logs, log levels) but does not specify performance monitoring and alerting strategies. Critical metrics missing from the design include:
- Translation API latency percentiles (P50, P95, P99) and error rates
- WebSocket connection count and message throughput per session
- Database query latency and connection pool utilization
- Cache hit rates and Redis memory usage
- External API quota consumption tracking

**Impact**: Without proactive monitoring, performance degradation is detected only through user complaints. If Translation API latency degrades from 500ms to 3 seconds due to quota throttling, the system continues to operate but user experience severely degrades. Without alerting, on-call engineers are not notified until after significant user impact.

**Recommendations**:
1. Define comprehensive performance monitoring strategy:
   - Application metrics: Translation API latency (P50/P95/P99), WebSocket message latency, cache hit rate
   - Infrastructure metrics: Database CPU/connections, Redis memory usage, ECS task CPU/memory
   - Business metrics: Active sessions, messages per second, translation quota consumption
2. Implement alerting thresholds:
   - Translation API P95 latency > 1 second (WARNING), > 2 seconds (CRITICAL)
   - WebSocket connection count > 70% capacity (WARNING), > 90% (CRITICAL)
   - Database connection pool utilization > 80% (WARNING)
   - Translation API quota consumption > 70% daily limit (WARNING)
3. Use AWS CloudWatch or Datadog for centralized monitoring and alerting
4. Create operational dashboard for real-time system health visibility

**References**: Section 6 (Logging policies defined, monitoring not mentioned), Section 7 (Performance targets defined but monitoring strategy missing)

---

### MINOR IMPROVEMENTS

#### I1: Audio Processing Pipeline Efficiency Not Optimized

**Observation**: Section 3 describes real-time voice translation flow using WebRTC and FFmpeg (Section 2), but does not specify audio format, codec, or compression strategy. Audio encoding/decoding and Speech-to-Text processing can be computationally expensive.

**Recommendation**: Specify audio codec (e.g., Opus for low-latency, high-quality compression) and sampling rate (e.g., 16kHz for speech recognition). Consider offloading Speech-to-Text processing to specialized service (Google Cloud Speech-to-Text with streaming recognition) to reduce server CPU load.

**References**: Section 2 (WebRTC, FFmpeg libraries), Section 3 (Real-time voice translation flow)

---

#### I2: Positive Aspects of the Design

**Strengths Identified**:
1. **Explicit Performance Targets**: Section 7 defines measurable NFRs (500ms translation latency, 200ms WebSocket connection establishment, 99.9% availability), providing clear acceptance criteria.
2. **Caching Strategy**: Translation result caching (Section 3) is architecturally appropriate for reducing external API calls and costs.
3. **Retry Logic with Fallback**: 3-retry exponential backoff with fallback translation engine (Section 6) provides resilience against transient API failures.
4. **Load Testing Plan**: Section 6 specifies Locust-based load testing for 500 concurrent sessions, demonstrating performance validation awareness.
5. **Auto-scaling Configuration**: Section 7 defines CPU-based auto-scaling threshold (70% utilization), enabling dynamic capacity management.

**References**: Section 6 (Error handling, testing policies), Section 7 (Non-functional requirements)

---

## Summary

This performance evaluation identified **2 critical issues** requiring immediate architectural revision (API quota management, unbounded data growth), **5 significant issues** affecting scalability and latency (N+1 queries, missing indexes, synchronous blocking, WebSocket scaling, cache invalidation), **4 moderate issues** under specific conditions (connection pooling, race conditions, Elasticsearch strategy, monitoring gaps), and **2 minor improvements** (audio optimization, positive design elements).

**Highest Priority Actions**:
1. Implement Translation API quota management and request throttling to prevent system-wide failure under peak load
2. Design data lifecycle management with partitioning and archival for TranslationHistory table to prevent unbounded growth
3. Add database indexes on high-frequency query paths (session_id, user_id fields)
4. Architect WebSocket horizontal scaling with Redis Pub/Sub and connection state management
5. Design asynchronous translation processing to prevent event loop blocking

The design demonstrates strong foundational awareness of performance considerations (explicit NFRs, caching, load testing) but requires architectural refinements in scalability planning, resource management, and operational observability to meet stated capacity targets.
