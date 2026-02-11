# Performance Review: Polyglot Connect システム設計書

## Document Structure Analysis

The design document provides comprehensive coverage of the following architectural aspects:
- System overview with scale targets (5-20 person meetings, 100-500 concurrent support, 1,000-10,000 event viewers)
- Technology stack (FastAPI, React, PostgreSQL, Redis, Elasticsearch)
- Architecture design with clear component responsibilities
- Data models with table schemas
- API design (WebSocket events and REST endpoints)
- Implementation approach (error handling, logging, testing, deployment)
- Non-functional requirements (performance targets, security, availability)

The document explicitly defines performance targets (500ms translation response, 200ms WebSocket connection, 95th percentile API response <1s) and scalability goals (99.9% uptime, 1,000 concurrent sessions).

However, several critical architectural concerns are not explicitly addressed:
- Database indexing strategy
- Connection pooling configuration
- Caching strategy details (TTL, invalidation)
- Capacity planning for data growth
- Horizontal scaling architecture
- Monitoring and alerting strategy

## Performance Issue Detection

### **CRITICAL ISSUES**

#### 1. N+1 Query Problem in Multi-Participant Translation Broadcasting (CRITICAL)
**Location**: Section 3 - チャット翻訳フロー, Step 2

**Issue**: The chat translation flow states "各参加者の言語に翻訳" (translate to each participant's language). For sessions with 20 participants speaking 10 different languages, this creates a potential N+1 problem where each message triggers individual translation API calls for each unique language.

**Performance Impact**:
- For a 20-person meeting with 10 languages: each message = 10 Translation API calls
- At 1 message/second: 600 API calls/minute
- Translation API latency (100-300ms) × 10 = 1-3 seconds total latency
- Exceeds the 500ms performance target by 2-6x
- API rate limits and costs scale linearly with participant count

**Recommendation**:
- Implement batch translation API calls using Google Translation API's batch endpoint (supports up to 1024 texts per request)
- Cache translations by (original_text, target_language) pairs in Redis with 1-hour TTL
- Pre-translate to all session languages in parallel using async/await pattern
- Add circuit breaker for Translation API to prevent cascade failures

#### 2. Unbounded Translation History Table Without Archival Strategy (CRITICAL)
**Location**: Section 4 - TranslationHistory テーブル

**Issue**: The TranslationHistory table uses BIGSERIAL (8 bytes per ID) but lacks partitioning, archival, or retention enforcement despite section 7 stating "翻訳履歴は30日間" retention policy. With 1,000 concurrent sessions each producing 100 messages/hour, this generates 2.4M records/day (72M/month).

**Performance Impact**:
- Table growth: 72M records/month × 500 bytes/record = 36GB/month
- Query performance degradation: full table scans on unpartitioned table
- Index size growth: B-tree indexes become inefficient after 100M+ records
- Backup/restore time increases linearly with table size
- Vacuum operations (PostgreSQL maintenance) take increasingly longer, causing write performance degradation

**Recommendation**:
- Implement PostgreSQL table partitioning by translated_at (monthly partitions)
- Create automated archival job to move records >30 days to cold storage (S3)
- Add TTL-based deletion policy enforced by scheduled batch jobs
- Implement partition pruning to only query active partitions
- Consider TimescaleDB for time-series optimized storage

#### 3. Missing Database Indexes on Critical Query Paths (CRITICAL)
**Location**: Section 4 - All Tables, Section 5 - API Endpoints

**Issue**: No indexes are defined for frequently queried foreign key columns and lookup patterns. Critical missing indexes:

1. `TranslationHistory(session_id, translated_at)` - Required by `GET /api/sessions/{id}/history`
2. `Participant(session_id, joined_at)` - Required for session participant lists
3. `CustomGlossary(organization_id, source_language, target_language)` - Required for real-time glossary lookups
4. `Session(organizer_id, started_at)` - Required for user session history queries
5. `TranslationHistory(speaker_id, translated_at)` - Required for per-user translation history

**Performance Impact**:
- Translation history query on 10,000-message session: full table scan on 72M records = 5-15 seconds (vs <100ms with index)
- Glossary lookup during translation: O(n) linear scan vs O(log n) B-tree lookup
- Missing index on FK columns causes join operations to degrade to nested loops (O(n²) complexity)
- PostgreSQL query planner forced to use sequential scans, consuming significant I/O

**Recommendation**:
```sql
-- Critical indexes for query performance
CREATE INDEX idx_translation_history_session_time ON TranslationHistory(session_id, translated_at DESC);
CREATE INDEX idx_participant_session ON Participant(session_id, joined_at);
CREATE INDEX idx_glossary_org_lookup ON CustomGlossary(organization_id, source_language, target_language);
CREATE INDEX idx_session_organizer ON Session(organizer_id, started_at DESC);
CREATE INDEX idx_translation_history_speaker ON TranslationHistory(speaker_id, translated_at DESC);

-- Consider covering indexes for high-frequency queries
CREATE INDEX idx_translation_history_covering ON TranslationHistory(session_id, translated_at DESC)
  INCLUDE (original_text, translated_text, target_language);
```

#### 4. Stateful WebSocket Design Preventing Horizontal Scaling (CRITICAL)
**Location**: Section 3 - Session Management Service responsibilities

**Issue**: The Session Management Service manages "WebSocket接続管理" without specifying how connection state is shared across multiple backend instances. In a horizontally scaled architecture with multiple ECS tasks, WebSocket connections are pinned to specific instances, creating routing and failover problems.

**Performance Impact**:
- Cannot scale beyond single instance capacity (~1,000 connections/instance limited by memory and CPU)
- Session affinity (sticky sessions) required, preventing even load distribution
- Instance failure causes all connected users to disconnect and reconnect
- Cannot perform zero-downtime deployments for WebSocket service
- Auto-scaling becomes ineffective because new instances cannot serve existing sessions

**Recommendation**:
- Implement Redis-backed WebSocket state sharing using Redis Pub/Sub or Streams
- Use Socket.IO's built-in Redis adapter for multi-node support:
  ```python
  import socketio

  mgr = socketio.AsyncRedisManager('redis://elasticache:6379')
  sio = socketio.AsyncServer(client_manager=mgr)
  ```
- Store session-to-user mappings in Redis for cross-instance lookups
- Implement connection health checks with automatic failover
- Consider using AWS Application Load Balancer (ALB) with WebSocket support instead of sticky sessions

#### 5. Missing Connection Pooling Configuration (CRITICAL)
**Location**: Section 2 - Database selection, Section 6 - Implementation approach

**Issue**: PostgreSQL and Redis are specified as data stores, but no connection pooling configuration is documented. Without pooling, each request creates new database connections, causing connection exhaustion under load and adding 50-100ms connection establishment overhead per request.

**Performance Impact**:
- Connection creation overhead: 50-100ms per request vs <1ms from pool
- PostgreSQL max_connections default (100) exhausted at ~50 concurrent requests
- Connection exhaustion causes cascading failures: requests timeout waiting for connections
- Database server CPU spikes from constant connection handshake operations
- At 1,000 concurrent sessions with 10 requests/second: 10,000 connections needed (100x default limit)

**Recommendation**:
- Configure asyncpg connection pool in FastAPI:
  ```python
  import asyncpg

  pool = await asyncpg.create_pool(
      dsn=DATABASE_URL,
      min_size=10,      # Keep minimum connections warm
      max_size=100,     # Limit per-instance connections
      max_inactive_connection_lifetime=300,
      command_timeout=30
  )
  ```
- Configure Redis connection pool (redis-py):
  ```python
  import redis.asyncio as redis

  redis_pool = redis.ConnectionPool.from_url(
      REDIS_URL,
      max_connections=50,
      decode_responses=True
  )
  ```
- Set PostgreSQL `max_connections = 500` (accounting for multiple ECS tasks)
- Configure PgBouncer as connection proxy for additional pooling layer
- Monitor connection pool metrics (active, idle, waiting) via CloudWatch

### **SIGNIFICANT ISSUES**

#### 6. Real-Time Audio Translation Synchronous I/O Bottleneck (SIGNIFICANT)
**Location**: Section 3 - リアルタイム音声翻訳フロー

**Issue**: The audio translation flow is entirely synchronous: Step 1→2→3→4→5 executes sequentially. Speech-to-Text (200-500ms) + Translation API (100-300ms) + DB write (50ms) = 350-850ms latency. This blocks WebSocket handler threads and prevents handling other requests during processing.

**Performance Impact**:
- Average latency: 575ms exceeds 500ms target
- Blocking I/O prevents FastAPI from processing other WebSocket events during translation
- At 100 concurrent audio streams: requires 100 worker threads (high memory overhead)
- Long tail latency: 95th percentile likely exceeds 1 second
- Poor user experience: noticeable lag in real-time conversations

**Recommendation**:
- Make all external API calls asynchronous using `asyncio` and `aiohttp`:
  ```python
  async def translate_audio_stream(audio_data: bytes, session_id: str):
      # Parallel execution of independent operations
      text_result = await speech_to_text_async(audio_data)
      [translations, db_write] = await asyncio.gather(
          translate_text_async(text_result.text),
          save_to_db_async(text_result)
      )
      await broadcast_to_participants(translations)
  ```
- Implement background task queue (Celery + Redis) for non-critical DB writes
- Use WebSocket streaming responses to send partial results as they arrive
- Consider using WebRTC for peer-to-peer audio streaming to reduce server load

#### 7. Translation Cache Missing TTL and Invalidation Strategy (SIGNIFICANT)
**Location**: Section 3 - Translation Service responsibilities, Section 4 - チャット翻訳フロー

**Issue**: Step 3 of chat translation mentions "翻訳結果をキャッシュ" but provides no TTL, cache key structure, or invalidation strategy. Without proper cache design:
- Custom glossary updates won't be reflected in cached translations
- Cache grows unbounded (memory exhaustion)
- Stale translations served after glossary changes

**Performance Impact**:
- Redis memory exhaustion: at 1M unique messages/day × 10 languages × 500 bytes = 5GB/day growth
- Cache hit rate degradation as memory fills up, causing evictions of hot data
- Inconsistent user experience: some users see updated glossary translations, others see cached versions
- Without LRU eviction policy, OOM kills Redis instance
- After glossary update, inconsistent translations served for hours/days

**Recommendation**:
- Implement structured cache key: `translation:{lang_pair}:{hash(original_text + glossary_version)}`
- Set appropriate TTL based on data characteristics:
  ```python
  # Hot cache for recent translations
  await redis.setex(
      f"translation:{source_lang}:{target_lang}:{text_hash}",
      3600,  # 1 hour TTL
      translation_result
  )

  # Long-term cache for common phrases
  await redis.setex(
      f"translation:common:{lang_pair}:{phrase_hash}",
      86400,  # 24 hour TTL
      translation_result
  )
  ```
- Implement cache invalidation on glossary updates using cache tag versioning
- Configure Redis maxmemory policy: `maxmemory-policy allkeys-lru`
- Set Redis maxmemory limit based on ElastiCache instance size (e.g., 80% of total memory)
- Monitor cache hit rate (target >70% for cost optimization)

#### 8. Missing Translation API Rate Limiting and Circuit Breaker (SIGNIFICANT)
**Location**: Section 2 - External Services, Section 6 - エラーハンドリング方針

**Issue**: While error handling mentions "3回リトライ" and fallback to DeepL API, there's no rate limiting or circuit breaker to prevent overwhelming Translation APIs during traffic spikes. Google Cloud Translation API has quotas (default: 1M characters/day, can be increased).

**Performance Impact**:
- At 1,000 concurrent sessions with 100 characters/message: 100K characters/second
- Exceeds default quota in 10 seconds, causing all translations to fail
- Retry logic amplifies problem: 3 retries × failed requests = 4x API load
- Cascading failure: all users experience translation failures simultaneously
- Cost spike: burst traffic can exceed budget quotas

**Recommendation**:
- Implement token bucket rate limiter at application level:
  ```python
  from aiohttp_retry import RetryClient, ExponentialRetry
  import asyncio

  class RateLimitedTranslationClient:
      def __init__(self, max_requests_per_second: int = 100):
          self.semaphore = asyncio.Semaphore(max_requests_per_second)

      async def translate(self, text: str, target_lang: str):
          async with self.semaphore:
              return await self._call_translation_api(text, target_lang)
  ```
- Implement circuit breaker to fail fast when API is degraded:
  ```python
  from pybreaker import CircuitBreaker

  translation_breaker = CircuitBreaker(
      fail_max=5,           # Open circuit after 5 failures
      timeout_duration=60,  # Keep open for 60 seconds
      expected_exception=TranslationAPIError
  )
  ```
- Pre-purchase Translation API quotas based on expected peak load (10x buffer)
- Implement request queuing with priority (real-time messages > document translation)
- Add CloudWatch alarm for API error rate >5%

#### 9. Elasticsearch Index Design Missing for Translation History Search (SIGNIFICANT)
**Location**: Section 2 - Search Engine: Elasticsearch 8, Section 5 - GET /api/sessions/{id}/history

**Issue**: Elasticsearch is specified for "Translation History Search" but no index mapping, query patterns, or sync strategy with PostgreSQL is documented. Without proper design:
- Full-text search performance unpredictable
- Data consistency issues between PostgreSQL and Elasticsearch
- Missing multi-language tokenization (50 languages supported)

**Performance Impact**:
- Without language-specific analyzers, search quality degrades (e.g., Japanese tokenization fails)
- Bulk indexing from PostgreSQL creates lag between message sent and searchable
- At 72M records/month, reindexing operations take hours and impact query performance
- Missing index sharding causes hot spots on large indices
- Cross-language search (search English, find Japanese) not possible without proper mapping

**Recommendation**:
- Define Elasticsearch index mapping with language-specific analyzers:
  ```json
  {
    "mappings": {
      "properties": {
        "session_id": {"type": "keyword"},
        "original_text": {
          "type": "text",
          "fields": {
            "en": {"type": "text", "analyzer": "english"},
            "ja": {"type": "text", "analyzer": "kuromoji"},
            "zh": {"type": "text", "analyzer": "smartcn"}
          }
        },
        "translated_text": {"type": "text"},
        "translated_at": {"type": "date"}
      }
    },
    "settings": {
      "number_of_shards": 5,
      "number_of_replicas": 1,
      "refresh_interval": "5s"
    }
  }
  ```
- Implement async indexing using PostgreSQL logical replication or Change Data Capture (CDC)
- Use index lifecycle management (ILM) to archive old indices
- Implement pagination for search results (limit 1000 results per query)

#### 10. Document Service Shared Editing Lacks Conflict Resolution Strategy (SIGNIFICANT)
**Location**: Section 3 - Document Service responsibilities ("共同編集の同期処理")

**Issue**: Document Service handles "共同編集の同期処理" but doesn't specify conflict resolution algorithm. For multi-language collaborative editing, concurrent edits to the same document section can cause race conditions and data loss.

**Performance Impact**:
- Last-write-wins approach causes user edits to be silently overwritten
- Optimistic locking with version checks causes high retry rates during concurrent edits
- Pessimistic locking (row-level locks) causes blocking and poor user experience
- At 20 concurrent editors: lock contention increases latency from 100ms to 1-5 seconds
- WebSocket broadcast storms when each character triggers full document sync

**Recommendation**:
- Implement Operational Transformation (OT) or CRDT-based conflict resolution
- Use libraries like Yjs or ShareDB for real-time collaboration:
  ```python
  from yjs import YDoc, YText

  doc = YDoc()
  text = doc.get_text('content')

  # Synchronize only deltas, not full document
  def handle_edit(client_id: str, edit_delta: bytes):
      doc.apply_update(edit_delta)
      broadcast_to_others(client_id, edit_delta)  # ~100 bytes vs full doc (100KB+)
  ```
- Store document snapshots periodically (every 100 operations) to reduce replay time
- Implement presence awareness (show active editors and cursor positions)
- Use binary diff protocol (MessagePack, Protobuf) instead of JSON for efficiency

### **MODERATE ISSUES**

#### 11. Missing Capacity Planning for Data Growth (MODERATE)
**Location**: Section 7 - 可用性・スケーラビリティ

**Issue**: Auto-scaling is configured for compute resources ("CPU使用率70%でスケールアウト") but no capacity planning for database and storage growth. At 2.4M translation records/day, PostgreSQL RDS and ElastiCache will hit storage limits.

**Performance Impact**:
- RDS storage auto-scaling causes brief performance degradation during scaling
- At current growth rate: 72M records/month × 12 = 864M records/year
- PostgreSQL vacuum operations slow down significantly after 1B records
- ElastiCache memory exhaustion causes eviction of hot cache data

**Recommendation**:
- Implement storage capacity monitoring with CloudWatch alarms:
  - PostgreSQL storage >80%: trigger archive/purge jobs
  - Redis memory >70%: review TTL policies
- Project storage needs quarterly: current usage × growth rate × 1.5 safety margin
- Pre-provision RDS storage to avoid auto-scaling performance hits
- Consider Aurora PostgreSQL for storage auto-scaling without downtime

#### 12. WebSocket Connection State Not Backed by Persistent Storage (MODERATE)
**Location**: Section 3 - Session Management Service

**Issue**: WebSocket connection management is mentioned but doesn't specify where connection state is stored. If only in-memory, ECS task restarts cause all users to disconnect. Redis session storage is mentioned but connection-to-session mapping isn't explicitly designed.

**Performance Impact**:
- ECS task deployment/failure causes 1,000 users to disconnect and reconnect
- Reconnection storm: 1,000 × 200ms = 200 seconds to fully restore service
- Users experience 30-60 second interruption during deployments
- No graceful degradation: binary connected/disconnected state

**Recommendation**:
- Store WebSocket connection metadata in Redis:
  ```python
  # On connection
  await redis.hset(f"ws:session:{session_id}", user_id, json.dumps({
      "connected_at": timestamp,
      "instance_id": instance_id,
      "last_heartbeat": timestamp
  }))

  # Heartbeat every 30s
  await redis.hset(f"ws:session:{session_id}", user_id, "last_heartbeat", now())
  ```
- Implement graceful shutdown: on SIGTERM, notify clients to reconnect to new instance
- Use ALB connection draining (300 second timeout) during deployments
- Add reconnection backoff to prevent thundering herd

#### 13. Missing Timeout Configuration for External API Calls (MODERATE)
**Location**: Section 2 - Translation API: Google Cloud Translation API

**Issue**: Error handling mentions retries but no timeout values. Without timeouts, slow Translation API responses can cause request pileup and thread/connection exhaustion.

**Performance Impact**:
- Without timeout, requests wait indefinitely for slow API responses
- At 100 requests/second, 30-second hang causes 3,000 queued requests
- Memory exhaustion from queued request contexts
- Cascading failure: healthy requests blocked by hung requests holding connections

**Recommendation**:
```python
import aiohttp
import asyncio

async def call_translation_api(text: str, target_lang: str):
    timeout = aiohttp.ClientTimeout(
        total=5.0,      # Total request timeout
        connect=1.0,    # Connection establishment timeout
        sock_read=3.0   # Socket read timeout
    )

    async with aiohttp.ClientSession(timeout=timeout) as session:
        try:
            async with session.post(TRANSLATION_API_URL, json={...}) as resp:
                return await resp.json()
        except asyncio.TimeoutError:
            logger.warning(f"Translation API timeout for {text[:50]}")
            raise TranslationTimeoutError()
```

Set timeouts based on SLA requirements:
- Critical path (real-time translation): 2-3 second timeout
- Background operations (document translation): 30 second timeout
- Monitor timeout rate, adjust if >1% of requests timeout

#### 14. Auto-Scaling Policy Based Only on CPU May Miss Memory Bottlenecks (MODERATE)
**Location**: Section 7 - Auto-scaling: CPU使用率70%でスケールアウト

**Issue**: Auto-scaling triggers on CPU only, but WebSocket services are often memory-bound (each connection holds state in memory). At 1,000 connections/instance with 1MB/connection, that's 1GB memory usage. CPU may remain low while memory exhausts.

**Performance Impact**:
- Instance OOM-killed before CPU triggers scale-out
- WebSocket connections dropped abruptly without graceful shutdown
- Service degradation not detected by CPU-based monitoring

**Recommendation**:
- Add memory-based scaling policy:
  ```yaml
  ScalingPolicy:
    MetricType: ECSServiceAverageMemoryUtilization
    TargetValue: 70
  ```
- Configure composite scaling: scale out if CPU >70% OR memory >70%
- Set ECS task memory reservation and limits appropriately:
  ```json
  {
    "memory": 2048,        // Hard limit
    "memoryReservation": 1024  // Soft limit for scaling decisions
  }
  ```
- Monitor per-instance metrics: connections, memory per connection, total memory

#### 15. Full Request/Response Logging Creates Performance Overhead (MODERATE)
**Location**: Section 6 - "翻訳リクエスト・レスポンスの全量ロギング"

**Issue**: Logging all translation requests/responses at high volume creates significant I/O overhead and storage costs. At 1,000 sessions × 100 messages/hour with 500 bytes/log entry: 50MB/hour = 1.2GB/day = 438GB/year of logs.

**Performance Impact**:
- Synchronous logging adds 5-10ms latency per request
- Disk I/O saturation during peak load
- Log shipping to CloudWatch Logs costs ~$0.50/GB ingestion + $0.03/GB storage
- Annual cost: 438GB × $0.50 = $219/year just for translation logs

**Recommendation**:
- Implement sampling for debug logs (log 1% of successful requests, 100% of errors):
  ```python
  import random

  def should_log_success() -> bool:
      return random.random() < 0.01  # 1% sampling

  if translation_succeeded:
      if should_log_success():
          logger.debug("Translation request", extra={...})
  else:
      logger.error("Translation failed", extra={...})  # Always log errors
  ```
- Use async logging (queue-based) to avoid blocking request threads
- Configure log rotation and retention policies (7 days for debug, 30 days for errors)
- Use structured logging with indexed fields for efficient querying

### **POSITIVE ASPECTS**

#### 16. Well-Defined Performance Targets (POSITIVE)
Section 7 defines specific, measurable performance targets:
- Translation response: <500ms average
- WebSocket connection: <200ms
- API response: 95th percentile <1s
- System uptime: 99.9%

These targets enable objective performance validation and provide clear benchmarks for optimization efforts.

#### 17. Appropriate Cache Layer Design (POSITIVE)
The architecture includes Redis as a caching layer between the application and PostgreSQL, which is appropriate for:
- Session state caching (reducing DB load)
- Translation result caching (reducing Translation API costs)
- High-performance key-value lookups

This design pattern aligns with best practices for high-throughput systems.

#### 18. Fallback Translation Engine Strategy (POSITIVE)
Section 6 mentions fallback to DeepL API when Google Translation API fails. This redundancy:
- Improves system resilience
- Maintains service availability during provider outages
- Provides leverage for cost negotiation with vendors

Consider extending this with:
- Active-active load balancing between providers for cost optimization
- Quality scoring to automatically select best provider per language pair

#### 19. WebSocket for Real-Time Communication (POSITIVE)
Using WebSocket (Socket.IO) for real-time translation delivery is the correct architectural choice versus HTTP polling:
- Lower latency: push-based vs polling overhead
- Reduced server load: persistent connection vs repeated HTTP handshakes
- Better user experience: instant message delivery

Socket.IO provides fallback to long-polling for network environments that block WebSocket, ensuring broad compatibility.

#### 20. Appropriate Database Choices (POSITIVE)
Technology stack choices are well-suited to use cases:
- PostgreSQL: ACID compliance for user data and translation history
- Redis: High-performance caching and session state
- Elasticsearch: Full-text search across multilingual content

This polyglot persistence approach optimizes for different data access patterns rather than forcing all data into a single database.

---

## Summary

This design document demonstrates strong foundational architecture with clear component separation and appropriate technology choices. However, it contains **5 critical performance issues** that must be addressed before production deployment:

1. **N+1 translation API calls** per message will cause 2-6x latency target violations
2. **Unbounded translation history table** will degrade query performance as data grows to 72M records/month
3. **Missing database indexes** cause 50-150x slower queries on critical paths
4. **Stateful WebSocket design** prevents horizontal scaling beyond single-instance capacity
5. **Missing connection pooling** causes connection exhaustion at target load (1,000 sessions)

Additionally, **5 significant issues** require attention for production reliability and **5 moderate issues** should be addressed for operational excellence.

The performance targets defined (500ms translation, 99.9% uptime, 1,000 concurrent sessions) are achievable with the recommended optimizations. Priority should be given to implementing database indexes, connection pooling, and resolving the N+1 query antipattern as these have the highest impact on meeting stated SLAs.
