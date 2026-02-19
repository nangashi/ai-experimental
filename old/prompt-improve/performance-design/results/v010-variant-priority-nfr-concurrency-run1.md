# Performance Design Review: Polyglot Connect System

## Executive Summary

This review evaluates the Polyglot Connect real-time translation platform from a performance architecture perspective. The analysis follows a critical-first detection strategy, identifying issues in order of severity: critical → significant → moderate → minor.

**Overall Assessment**: The design contains several critical performance risks that could cause severe degradation under production load, particularly around concurrency control, NFR specification gaps, and data access patterns.

---

## Critical Issues (System-Wide Impact)

### C1. Missing Race Condition Protection in Real-Time Translation Flow

**Location**: Section 3 (Data Flow) - Real-time audio/chat translation flows

**Issue**: The design describes concurrent translation workflows without any concurrency control mechanisms:
- Step 4 in audio translation flow: "Translation Service: 翻訳結果をDBに保存" - no transaction isolation specified
- Step 5: "Translation Service: 全参加者にWebSocketで配信" - no guarantee of consistent delivery order
- Chat translation flow (steps 2-4) processes translations for multiple participants without coordination

**Performance Impact**:
- **Race conditions in translation history**: Multiple concurrent translations from the same session could cause out-of-order insertions in TranslationHistory table, breaking chronological integrity
- **Duplicate translation API calls**: Without idempotency keys, network retries (section 6: "3回リトライ") could cause redundant API calls, wasting Translation API quota and increasing latency
- **WebSocket message ordering violations**: Concurrent broadcasts to participants may deliver messages out of order, degrading user experience in fast-paced conversations
- **Data inconsistency under load**: At target scale (1,000 sessions × 20 participants = 20,000 concurrent connections), lack of coordination will cause frequent race conditions

**Recommendations**:
1. **Implement optimistic locking** for TranslationHistory writes using version columns or timestamp-based conflict detection
2. **Add idempotency keys** to Translation API requests (hash of session_id + speaker_id + original_text + timestamp) to prevent duplicate translations on retry
3. **Use message sequence numbers** in WebSocket broadcasts to enable client-side reordering
4. **Define transaction isolation level** for translation writes (READ COMMITTED minimum, SERIALIZABLE for critical financial/legal use cases)
5. **Implement distributed locks** (Redis-based) for session-level operations to prevent concurrent state modifications

---

### C2. Critical NFR Gaps Affecting Production Viability

**Location**: Section 7 (Non-Functional Requirements)

**Issue**: Multiple production-critical specifications are missing or incomplete:

**Missing Specifications**:
- **No SLA definition**: Section 7 lists performance targets but no formal SLA commitments (uptime %, error budget, incident response time)
- **No throughput requirements**: Only latency targets specified; missing concurrent request capacity (translations/sec, messages/sec per session)
- **No monitoring strategy**: No mention of performance metrics collection, alerting thresholds, or observability infrastructure
- **No data retention/archival policy details**: Section 7 mentions "30日間" retention for translation history but lacks:
  - Archival strategy for data beyond 30 days
  - Purging mechanism implementation (scheduled job? event-driven?)
  - Impact on Elasticsearch index size and query performance as data approaches retention limit

**Performance Impact**:
- **Undetectable performance degradation**: Without defined throughput SLAs, gradual performance decay (e.g., translation latency creeping from 500ms to 2s) won't trigger alerts until user complaints escalate
- **Capacity planning blindness**: Missing throughput metrics prevent proactive scaling decisions; system may hit hard limits unexpectedly during traffic spikes
- **Operational firefighting**: No monitoring strategy means incident detection relies on user reports rather than automated alerting, increasing MTTR (Mean Time To Repair)
- **Data bloat risk**: Without automated retention enforcement, TranslationHistory and Elasticsearch indexes will grow unbounded, degrading query performance over time

**Recommendations**:
1. **Define formal SLAs**:
   - Availability: 99.9% uptime (43.2 min/month downtime budget)
   - Latency: P95 translation response < 1s, P99 < 2s
   - Error rate: < 0.1% failed translations
2. **Specify throughput requirements**:
   - Per-session capacity: 10 messages/sec sustained, 50 msgs/sec burst
   - System-wide capacity: 10,000 translations/sec across all sessions
3. **Design monitoring strategy**:
   - Metrics: Translation API latency/errors, WebSocket connection count, DB query performance, cache hit rates
   - Alerting: PagerDuty integration for SLA violations, CloudWatch dashboards for real-time visibility
4. **Implement data lifecycle automation**:
   - Daily scheduled job (AWS Lambda) to archive TranslationHistory > 30 days to S3 Glacier
   - Elasticsearch index lifecycle policy (ILM) to auto-delete old data
   - Monitor index size and query latency to detect retention policy failures

---

### C3. Unbounded Data Growth in Translation History

**Location**: Section 4 (Data Model) - TranslationHistory table

**Issue**: The TranslationHistory table design lacks growth controls:
- No pagination mentioned in API design (section 5: `GET /api/sessions/{id}/history`)
- BIGSERIAL primary key suggests anticipation of large volumes, but no partitioning strategy
- TEXT columns for `original_text` and `translated_text` have no size limits
- Elasticsearch indexing (section 3) implies full-text search on all history without bounded queries

**Performance Impact**:
- **Exponential storage growth**: At peak scale (10,000 viewers × 1 event/day × 100 messages/event × 365 days = 365M records/year), table size will exceed terabytes within 2-3 years
- **Query performance degradation**: Without partitioning or pagination, `GET /sessions/{id}/history` will perform full table scans on large sessions, causing timeouts
- **Elasticsearch index bloat**: Full-text indexing of unbounded TEXT fields will cause index size to grow faster than disk provisioning, eventually causing indexing failures
- **Memory exhaustion**: API responses returning full session history could exceed application memory limits for long-running sessions (e.g., 8-hour conference with 5,000 messages)

**Recommendations**:
1. **Implement table partitioning** by `translated_at` (monthly partitions) to limit scan ranges
2. **Add mandatory pagination** to history API: default page_size=50, max_size=500
3. **Add TEXT size limits**: `original_text` and `translated_text` VARCHAR(10000) to prevent abuse
4. **Implement lazy Elasticsearch indexing**: Index only recent data (last 90 days) for search, archive older data to cold storage
5. **Add result count limits** to search queries (max 1000 results per query)

---

### C4. Single Point of Failure in Translation API Dependency

**Location**: Section 3 (External Services), Section 6 (Error Handling)

**Issue**: The design relies on Google Cloud Translation API as the primary service with DeepL as fallback, but lacks critical failure handling details:
- No circuit breaker pattern mentioned
- Fallback logic described (section 6) but no criteria for when to switch
- No quota management strategy (Google Translation API has rate limits and monthly quotas)
- Single Translation Service component (section 3) suggests no redundancy

**Performance Impact**:
- **Cascading failures**: If Google API experiences high latency (e.g., 10s timeout), all translation requests will block, exhausting thread pools and causing system-wide unavailability
- **Quota exhaustion**: Without rate limiting, traffic spikes could exhaust monthly API quota mid-month, causing sudden service degradation
- **Thundering herd on failover**: If primary API fails, all 1,000 concurrent sessions will simultaneously retry against DeepL fallback, likely overwhelming it
- **Cost spike risk**: Uncontrolled fallback to DeepL (typically more expensive) could cause unexpected cost increases during prolonged Google API outages

**Recommendations**:
1. **Implement circuit breaker pattern** (using libraries like `pybreaker`):
   - Open circuit after 5 consecutive failures or 50% error rate in 10s window
   - Half-open state after 30s cooldown
   - Automatic fallback to DeepL when circuit opens
2. **Add quota-aware rate limiting**:
   - Track daily/monthly API usage in Redis
   - Implement token bucket algorithm to smooth request distribution
   - Reject requests with HTTP 429 when approaching quota limits (e.g., 90% consumed)
3. **Implement gradual fallback**:
   - Route 10% of traffic to DeepL initially, ramp up if Google continues failing
   - Use consistent hashing to route specific sessions to specific providers, avoiding thundering herd
4. **Add API timeout controls**: Set aggressive timeouts (2s) with fast-fail to prevent blocking

---

## Significant Issues (High-Impact Scalability Problems)

### S1. N+1 Query Problem in Chat Translation Flow

**Location**: Section 3 (Data Flow) - Chat translation flow step 2

**Issue**: "Translation Service: 各参加者の言語に翻訳" suggests iterative translation for each participant:
- Typical session: 5-20 participants (section 1)
- Large event: Up to 10,000 participants (section 1)
- Current design likely loops: `for participant in session.participants: translate(message, participant.language)`

**Performance Impact**:
- **Latency multiplication**: For 20-participant session, sequential translations cause 500ms × 20 = 10s total latency before any participant receives the message
- **API quota waste**: If 15 participants share the same language (e.g., English), current design may call Translation API 15 times instead of 1
- **Unacceptable delay at scale**: For 10,000-participant event, even with parallel requests, coordinating 10,000 translations will cause multi-second delays

**Recommendations**:
1. **Batch translations by target language**:
   - Group participants by `language` field
   - Single API call per unique target language (typically 3-5 languages per session, not 20)
   - Reduces API calls by 80-90% in typical scenarios
2. **Implement language-based fan-out**:
   - Translate once per language → cache result → broadcast to all participants with that language
   - Use Redis pub/sub with language-specific channels
3. **Pre-translate for large events**:
   - For events with > 100 participants, pre-define target languages (e.g., EN, ES, FR, ZH, JA)
   - Reject participant languages outside pre-defined set or provide view-only access

---

### S2. Missing Database Indexes on Critical Query Paths

**Location**: Section 4 (Data Model) - All tables

**Issue**: No indexes specified beyond primary keys and foreign keys. Critical query patterns lack index support:
- `GET /api/sessions/{id}/history`: Likely queries `TranslationHistory WHERE session_id = ? ORDER BY translated_at DESC`
- Participant lookup: `Participant WHERE session_id = ?` for broadcasting
- User session history: Likely `Session WHERE organizer_id = ?` or `Participant WHERE user_id = ?`

**Performance Impact**:
- **History retrieval slowdown**: `TranslationHistory` query without `(session_id, translated_at)` composite index will perform sequential scan, taking seconds for sessions with 1000+ messages
- **Broadcast latency**: Looking up participants without `(session_id)` index will cause delays in message distribution
- **User dashboard slowness**: Retrieving user's session history without indexes on `organizer_id` / `user_id` will degrade as user accumulates sessions

**Recommendations**:
1. **Add composite index**: `CREATE INDEX idx_translation_session_time ON TranslationHistory(session_id, translated_at DESC)` - supports history queries and sorting
2. **Add covering index**: `CREATE INDEX idx_participant_session ON Participant(session_id) INCLUDE (user_id, language)` - avoids table lookups during broadcast
3. **Add user indexes**:
   - `CREATE INDEX idx_session_organizer ON Session(organizer_id, started_at DESC)`
   - `CREATE INDEX idx_participant_user ON Participant(user_id, joined_at DESC)`
4. **Monitor index usage**: Enable PostgreSQL `pg_stat_user_indexes` to detect missing indexes in production

---

### S3. Synchronous Translation Blocking Real-Time Flow

**Location**: Section 3 (Data Flow) - Steps 2-3 in audio translation flow

**Issue**: The flow describes sequential steps:
1. Speech-to-Text conversion (typically 200-500ms)
2. Translation API call (target: 500ms average, but P95 = ?)
3. DB write
4. Broadcast to participants

All steps appear synchronous within the WebSocket handler, blocking the connection.

**Performance Impact**:
- **Head-of-line blocking**: If one translation request takes 3s (e.g., due to API slowness), all subsequent messages from that speaker queue up, causing compounding delays
- **WebSocket timeout risk**: Browsers typically timeout WebSocket operations after 30-60s; long blocking operations risk connection drops
- **Thread pool exhaustion**: At 1,000 concurrent sessions, blocking I/O operations will exhaust available threads (typical FastAPI/ASGI worker count: 10-20), causing request rejections
- **Poor user experience**: Users expect real-time feedback (< 1s); synchronous 500ms translation + 100ms DB write + 100ms broadcast = 700ms best-case, often exceeding 2s at P95

**Recommendations**:
1. **Implement async/await pattern** throughout translation pipeline:
   - Use `asyncio` for Speech-to-Text, Translation API, and DB operations
   - FastAPI already supports async handlers; ensure all I/O operations are async
2. **Add task queues for non-critical operations**:
   - DB write (step 4) can be asynchronous using Celery/Redis queue
   - Broadcast to participants immediately after translation, persist to DB in background
3. **Implement streaming translation**:
   - Use Google Translation API streaming mode for partial results
   - Broadcast partial translations before full sentence completes (reduces perceived latency)
4. **Add operation timeout controls**: Set per-step timeouts (Speech-to-Text: 1s, Translation: 2s) to prevent indefinite blocking

---

### S4. Stateful WebSocket Design Limiting Horizontal Scaling

**Location**: Section 3 (Architecture) - Session Management Service

**Issue**: WebSocket connections are inherently stateful (persistent TCP connections). The design shows:
- Session Management Service handles "WebSocket接続管理" (section 3)
- No mention of session affinity or distributed session storage
- Auto-scaling based on CPU (section 7) without addressing connection distribution

**Performance Impact**:
- **Uneven load distribution**: When auto-scaling adds new instances, existing WebSocket connections remain on old instances, leaving new instances idle while old ones remain overloaded
- **Connection loss on scale-down**: Scaling in will forcibly disconnect users on terminated instances
- **Hot-spotting**: Popular sessions (e.g., 10,000-participant events) may concentrate on single instance if no connection balancing exists
- **Deployment disruption**: Blue-green deployment (section 6) requires draining all WebSocket connections before switching versions, causing service interruption

**Recommendations**:
1. **Implement sticky sessions with consistent hashing**:
   - Use ALB (Application Load Balancer) with target group session affinity based on session_id
   - Ensures all participants in same session connect to same instance
2. **Add distributed session store**:
   - Store WebSocket connection metadata in Redis (session_id → [connection_ids])
   - Enables cross-instance messaging via Redis pub/sub
3. **Implement graceful connection draining**:
   - Before instance termination, send "reconnect" message to all clients with 30s grace period
   - Clients reconnect to new instances automatically
4. **Use dedicated WebSocket instance pool**:
   - Separate WebSocket handlers from REST API instances
   - Scale WebSocket pool based on connection count, not CPU usage
   - Prevents WebSocket connections from starving REST API resources

---

## Moderate Issues (Conditional Performance Problems)

### M1. Suboptimal Cache Strategy for Translation Results

**Location**: Section 3 (Translation Service responsibilities) - "翻訳結果のキャッシング"

**Issue**: Caching is mentioned but without specifics:
- No cache key design specified
- No TTL (time-to-live) strategy
- No cache invalidation policy for custom glossary updates
- No cache hit/miss ratio targets

**Performance Impact**:
- **Cache key collisions**: If keyed only by `original_text`, translations with different custom glossaries will return incorrect results
- **Stale translations**: If custom glossary updated (section 5: `PUT /api/glossaries/{id}`), cached translations won't reflect new terms until TTL expires
- **Memory waste**: Without TTL, Redis cache will accumulate rare translations that are never reused, eventually exceeding memory limits
- **Low cache hit rate**: If cache key includes session-specific data, hit rate will be poor (each session has unique translations)

**Recommendations**:
1. **Design cache key hierarchy**:
   - Global translations: `translation:{src_lang}:{tgt_lang}:{hash(text)}` → used for common phrases
   - Organization translations: `translation:{org_id}:{src_lang}:{tgt_lang}:{hash(text)}` → includes glossary
   - TTL: 7 days for global, 24 hours for organization-specific
2. **Implement cache warming**:
   - Pre-populate cache with common business phrases during off-peak hours
   - Monitor cache hit rate (target: > 60% for chat translations)
3. **Add cache invalidation on glossary updates**:
   - When `PUT /api/glossaries/{id}` called, purge all keys matching `translation:{org_id}:*`
   - Use Redis keyspace notifications for automated invalidation
4. **Implement cache aside pattern with fallback**:
   - On cache miss, call Translation API, cache result, return to client
   - If Redis unavailable, skip caching and call API directly (don't block on cache failures)

---

### M2. Missing Connection Pooling for Database and External APIs

**Location**: Section 2 (Technology Stack) - No mention of connection pool configuration

**Issue**: Design specifies PostgreSQL, Redis, and Translation API usage but doesn't address connection management:
- FastAPI default DB connection behavior: new connection per request (expensive)
- Translation API client initialization: unclear if reused or recreated per request
- Redis client pooling: not mentioned

**Performance Impact**:
- **Connection establishment overhead**: PostgreSQL connection setup takes 50-100ms; for 100 requests/sec, this adds 5-10s of cumulative latency
- **Connection exhaustion**: PostgreSQL max_connections default is 100; at 1,000 concurrent sessions, connections will be refused
- **API client overhead**: Recreating HTTP clients per request wastes memory and causes TLS handshake delays
- **Redis connection churn**: Without pooling, Redis connections will thrash under load, causing intermittent timeouts

**Recommendations**:
1. **Configure PostgreSQL connection pooling**:
   - Use SQLAlchemy with pool size = 20 per instance, max_overflow = 10
   - Set `pool_pre_ping=True` to detect stale connections
   - Use PgBouncer in transaction pooling mode for additional layer (500 client connections → 20 DB connections)
2. **Configure Redis connection pooling**:
   - Use `redis-py` ConnectionPool with max_connections = 50
   - Set socket keepalive to prevent firewall timeouts
3. **Implement API client singleton**:
   - Initialize Google Translation API client once at application startup
   - Reuse client instance across all requests
   - Configure client connection pool (default: 10 connections per client)
4. **Monitor connection metrics**:
   - Track pool utilization (target: < 80% average, < 95% peak)
   - Alert on connection acquisition timeouts

---

### M3. Inefficient Elasticsearch Indexing Strategy

**Location**: Section 3 (Data Layer) - "Elasticsearch (Translation History Search)"

**Issue**: Design specifies Elasticsearch for translation history search but lacks indexing strategy:
- No mention of index structure (single index vs. time-based indices)
- No query patterns specified (full-text search? filtered by session? date range?)
- Synchronous vs. asynchronous indexing unclear
- No mention of index refresh interval or search-after pagination

**Performance Impact**:
- **Slow search queries**: If using single monolithic index, queries will scan billions of documents as data accumulates, causing 10+ second response times
- **Indexing lag**: Synchronous indexing blocks translation writes; if Elasticsearch slow, entire translation pipeline stalls
- **Index size bloat**: Without lifecycle policies, deleted/expired data remains in indices, wasting disk and memory
- **Poor search relevance**: If indexing raw TEXT without language-specific analyzers, search quality will be poor (e.g., stemming, stopwords)

**Recommendations**:
1. **Implement time-based index structure**:
   - Pattern: `translation-history-YYYY-MM` (monthly indices)
   - Enables efficient date range queries and automated deletion of old indices
   - Index template with 1 primary shard, 1 replica per index
2. **Use asynchronous indexing**:
   - Write to PostgreSQL first (source of truth)
   - Enqueue Elasticsearch indexing as background task (Celery)
   - Prevents translation latency from being coupled to Elasticsearch performance
3. **Configure index lifecycle management (ILM)**:
   - Hot phase (0-7 days): High-performance nodes, frequent refreshes (1s interval)
   - Warm phase (8-30 days): Standard nodes, force merge to 1 segment
   - Delete phase (> 30 days): Auto-delete to match retention policy
4. **Implement language-aware indexing**:
   - Use language-specific analyzers based on `original_language` field
   - Configure multi-field mapping: `original_text.ja`, `original_text.en`, etc.
   - Improves search relevance by 30-40%

---

### M4. Missing Monitoring Coverage for Performance Metrics

**Location**: Section 6 (Implementation) - Logging mentioned, monitoring not specified

**Issue**: Design includes structured logging (section 6) but lacks comprehensive monitoring strategy for performance:
- No APM (Application Performance Monitoring) tool mentioned
- No real-time metrics dashboard specified
- No alerting rules defined
- No distributed tracing for multi-service requests

**Performance Impact**:
- **Slow incident detection**: Without real-time metrics, performance degradation detected only through user complaints (MTTR: hours instead of minutes)
- **Difficult root cause analysis**: When translation latency spikes, lack of distributed tracing makes it unclear whether issue is in Speech-to-Text, Translation API, DB writes, or WebSocket broadcast
- **No proactive optimization**: Without baseline metrics, can't identify gradual performance decay (e.g., cache hit rate dropping from 70% to 40% over weeks)
- **Blind scaling decisions**: Auto-scaling based solely on CPU (section 7) misses other bottlenecks (DB connection pool exhaustion, API rate limiting)

**Recommendations**:
1. **Implement APM solution**:
   - Use AWS X-Ray or Datadog APM for distributed tracing
   - Instrument all critical paths: Translation pipeline, DB queries, API calls
   - Track P50/P95/P99 latencies for each component
2. **Create real-time dashboards**:
   - CloudWatch/Grafana dashboard with key metrics:
     - Translation latency breakdown (Speech-to-Text, API, DB write, broadcast)
     - WebSocket connection count and churn rate
     - Cache hit rates (Redis)
     - Translation API quota consumption
     - DB query performance (slow query log)
3. **Define alerting rules**:
   - Critical: P95 translation latency > 2s, API error rate > 1%, WebSocket connection failures > 5%
   - Warning: Cache hit rate < 50%, DB connection pool > 80%, API quota > 80%
4. **Implement health check endpoints**:
   - `/health/liveness`: Basic service alive check
   - `/health/readiness`: Check dependencies (DB, Redis, Translation API) with 1s timeout
   - Use for ALB health checks and graceful shutdown

---

## Minor Improvements & Positive Aspects

### Positive Aspects

1. **Clear performance targets defined** (Section 7): Specific latency and throughput goals provide measurable success criteria
2. **Multi-tier caching strategy** (Section 3): Both Redis and Translation API result caching mentioned, showing awareness of performance optimization
3. **Retry strategy with exponential backoff** (Section 6): Proper error handling to prevent thundering herd during transient failures
4. **Auto-scaling configuration** (Section 7): Proactive capacity management with CPU-based scaling threshold

### Minor Optimization Opportunities

**O1. Consider CDN caching for static translation assets**
- Custom glossary data rarely changes; cache at CloudFront edge for reduced latency
- Potential benefit: 50-100ms latency reduction for glossary lookups

**O2. Implement database read replicas for history queries**
- `GET /api/sessions/{id}/history` is read-heavy; offload to replicas
- Primary DB reserved for writes (translation results, session management)
- Reduces contention and improves write throughput

**O3. Use protobuf for WebSocket message serialization**
- Current design likely uses JSON (common with Socket.IO)
- Protobuf reduces message size by 50-70%, lowering bandwidth costs at scale
- Especially impactful for 10,000-participant events

---

## Summary & Prioritized Recommendations

### Critical Actions (Fix Before Production)

1. **Add concurrency control**: Implement optimistic locking, idempotency keys, and transaction isolation
2. **Define NFR specifications**: SLA commitments, throughput requirements, monitoring strategy, data retention automation
3. **Implement data growth controls**: Pagination, partitioning, Elasticsearch ILM
4. **Add Translation API resilience**: Circuit breaker, quota management, gradual fallback

### High-Priority Actions (Fix Before Scale)

5. **Optimize chat translation**: Batch by language, eliminate N+1 queries
6. **Add database indexes**: Composite indexes for critical query paths
7. **Implement async translation pipeline**: Eliminate blocking I/O
8. **Enable horizontal WebSocket scaling**: Sticky sessions, distributed session store, graceful draining

### Medium-Priority Actions (Optimize Performance)

9. **Refine cache strategy**: Hierarchical keys, TTL policies, invalidation on glossary updates
10. **Configure connection pooling**: DB, Redis, and API client pools with proper sizing
11. **Implement Elasticsearch best practices**: Time-based indices, async indexing, ILM
12. **Add comprehensive monitoring**: APM, dashboards, alerting rules

### Ongoing Optimization

13. Consider read replicas, protobuf serialization, CDN caching for incremental gains

---

**Review Completed**: 2026-02-11
**Reviewer**: Performance Design Reviewer Agent
**Variant**: v010-variant-priority-nfr-concurrency (Priority-First + NFR-Concurrency Integration)
