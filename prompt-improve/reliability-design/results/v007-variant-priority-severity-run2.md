# Reliability Design Review: Real-Time Event Streaming Platform
**Variant**: v007-variant-priority-severity (C3a)
**Run**: 2
**Date**: 2026-02-11

---

## Phase 1: Structural Analysis

### System Components
1. **Ingestion Layer**: 3 adapters (Stadium Sensor, Broadcast API, Social Media)
2. **Streaming Infrastructure**: Kafka 3.6 (3 brokers, RF=2), Flink 1.18 (3 jobs)
3. **Data Stores**: PostgreSQL Multi-AZ RDS, InfluxDB 2.7, Redis Cluster (6 nodes), OpenSearch 2.11
4. **Delivery Layer**: WebSocket Gateway (Socket.IO + Redis adapter), REST API (Spring Boot)
5. **Infrastructure**: EKS (3 AZs, min 6 nodes), ALB, CloudFront
6. **External Dependencies**: OpenAI API (translation), Stripe (subscriptions)

### Data Flow Paths
- **Primary Path**: External sources → Adapters → Kafka → Flink Enrichment → PostgreSQL + Redis Pub/Sub → WebSocket Gateway → Clients
- **Analytics Path**: Kafka → Flink Aggregation → InfluxDB
- **Translation Path**: Flink Translation Job → OpenAI API → Redis cache
- **Query Path**: Client → REST API → PostgreSQL/Redis → Response
- **Billing Path**: Stripe webhook → REST API → PostgreSQL subscriptions table

### External Dependencies (Criticality)
- **Critical**: Kafka (event backbone), PostgreSQL (source of truth), Redis Cluster (real-time delivery)
- **High**: WebSocket Gateway (client connectivity), Flink (stream processing)
- **Medium**: InfluxDB (metrics), OpenSearch (search), OpenAI (translation enhancement)
- **Low**: CloudFront (asset delivery), Stripe webhooks (eventual consistency acceptable)

### Explicitly Mentioned Reliability Mechanisms
- Kafka: 3 brokers, replication factor 2
- PostgreSQL: Multi-AZ RDS with automated failover
- Redis: 6-node cluster (3 primary + 3 replica)
- EKS: 3 availability zones, minimum 6 nodes
- HPA: CPU-based autoscaling for WebSocket gateway (70% target)
- Error handling: 503 on DB failures, continue on external API errors, offset commit after successful processing
- Correlation IDs for request tracing
- Manual database migrations via Flyway before deployment

---

## Phase 2: Problem Detection

### **TIER 1: CRITICAL ISSUES (System-Wide Failure / Data Loss Risk)**

#### **C1: Distributed Transaction Coordination Completely Missing**
**Severity**: Critical
**Section**: Architecture Design (3.3, 3.4), Data Flow (3.5)

**Problem Description**:
The design describes a multi-step distributed transaction across Kafka, Flink, PostgreSQL, and Redis without any distributed transaction coordination mechanism. The Flink Enrichment Job writes to both PostgreSQL (`events` table) and Redis Pub/Sub (`live-events` channel) with no guarantee of atomicity.

**Failure Scenario**:
1. Flink job successfully writes enriched event to PostgreSQL
2. Network partition occurs before Redis Pub/Sub publish
3. PostgreSQL commit succeeds, Redis publish fails
4. **Result**: Event persisted in database but never delivered to connected WebSocket clients
5. Historical queries show event exists, but live viewers never received it
6. No automatic reconciliation mechanism to detect or recover from this inconsistency

**Operational Impact**:
- **Silent data loss**: Live viewers miss critical events (e.g., goal scored) with no error indication
- **Customer experience degradation**: Inconsistent delivery undermines platform reliability perception
- **Debugging complexity**: Requires manual correlation of PostgreSQL writes with Redis Pub/Sub logs across distributed systems
- **No recovery path**: Once delivery window passes, event cannot be "replayed" to affected clients

**Countermeasures**:
1. **Transactional Outbox Pattern**: Write both event record and outbox entry to PostgreSQL in single transaction. Separate relay service reads outbox and publishes to Redis with at-least-once delivery guarantee.
2. **Idempotency Keys**: Add `delivery_token` UUID to event records and Redis messages. WebSocket gateway deduplicates using token.
3. **Saga Orchestration**: Use Flink state to track write phases (PostgreSQL → Redis) with compensating actions on partial failure.
4. **Dual-Write Validation**: Background monitor queries recent PostgreSQL events and verifies corresponding Redis publish occurred within SLA window. Alerts on gaps.

---

#### **C2: No Idempotency Guarantees for Kafka Message Processing**
**Severity**: Critical
**Section**: Error Handling (6.1), Stream Processors (3.3.2)

**Problem Description**:
The design states "Commit offset only after successful processing" but provides no idempotency mechanism for the write operations themselves. Kafka consumers can receive duplicate messages after rebalances, crashes, or network timeouts, leading to duplicate event writes.

**Failure Scenario**:
1. Flink Enrichment Job processes event from Kafka, writes to PostgreSQL
2. Job crashes before committing Kafka offset
3. On restart, Kafka redelivers the same message (at-least-once delivery)
4. Flink writes duplicate row to `events` table
5. **Result**: Same event appears multiple times in history queries, metrics double-counted, clients potentially receive duplicate push notifications

**Operational Impact**:
- **Data integrity corruption**: Historical analytics and replay features show incorrect event sequences
- **Billing errors**: Duplicate subscription events could trigger multiple Stripe charges
- **Cascading duplication**: Translation cache misses cause redundant OpenAI API calls for same event
- **Client confusion**: Mobile apps display duplicate notifications for same goal/score update

**Countermeasures**:
1. **Natural Idempotency Key**: Use `(source, event_type, timestamp, external_event_id)` composite key from upstream source. Add unique constraint to PostgreSQL schema:
   ```sql
   ALTER TABLE events ADD COLUMN source_event_id VARCHAR(255);
   CREATE UNIQUE INDEX idx_events_dedup ON events(source, event_type, source_event_id);
   ```
2. **Upsert Semantics**: Change Flink job to use `INSERT ... ON CONFLICT DO NOTHING` for event writes
3. **State-Based Deduplication**: Use Flink keyed state to track processed event IDs within sliding window (e.g., 1 hour)
4. **Idempotency Tokens**: Generate deterministic hash from message content as deduplication key stored in Redis with TTL

---

#### **C3: Circuit Breaker Pattern Missing for External API Dependencies**
**Severity**: Critical
**Section**: Stream Processors (3.3.2), External Dependencies (2.6)

**Problem Description**:
The Translation Job calls OpenAI API synchronously within the Flink stream processing pipeline with no circuit breaker or timeout configuration. When OpenAI experiences slowdowns or outages, the entire Flink job backpressures and blocks all event processing.

**Failure Scenario**:
1. OpenAI API latency increases from 200ms to 30 seconds due to their service degradation
2. Flink Translation Job threads block waiting for API responses
3. Kafka consumer lag increases as processing throughput drops from 10,000 events/sec to ~30 events/sec
4. **Cascading effect**: Enrichment Job also slows down due to Kafka topic backpressure
5. **Complete system freeze**: Real-time event delivery stops entirely for 30+ seconds
6. Users perceive platform as "down" despite internal services being healthy

**Operational Impact**:
- **Cascading failure**: Single external dependency failure brings down entire real-time pipeline
- **Recovery delay**: Even after OpenAI recovers, Kafka lag requires hours to drain at normal processing rates
- **SLA violation**: 99.9% uptime target breached (requires <43.8 min/month downtime, but single incident could exceed this)
- **Operational overhead**: Manual intervention required to restart Flink jobs and clear backlogs

**Countermeasures**:
1. **Circuit Breaker with Hystrix/Resilience4j**:
   - Failure threshold: 50% error rate over 10-second window
   - Open state: Skip translation, publish original language content with flag `translation_unavailable: true`
   - Half-open retry: Attempt single request after 30-second cooldown
2. **Aggressive Timeouts**: Set 2-second timeout for OpenAI API calls with exponential backoff (max 3 retries)
3. **Asynchronous Translation**: Decouple translation from critical path:
   - Enrichment Job publishes events immediately without translation
   - Separate Translation Consumer processes asynchronously, updates Redis cache on completion
   - WebSocket Gateway checks cache, sends translations as secondary update if available
4. **Bulkhead Isolation**: Dedicated thread pool for OpenAI calls (max 10 concurrent) to prevent resource exhaustion

---

#### **C4: Kafka Replication Factor 2 Creates Split-Brain Risk**
**Severity**: Critical
**Section**: Scalability & Availability (7.3), Streaming Infrastructure (2.4)

**Problem Description**:
Kafka cluster configured with 3 brokers but replication factor 2. With `min.insync.replicas` unspecified (likely defaults to 1), this creates split-brain scenarios during network partitions where two brokers each believe they are the leader.

**Failure Scenario**:
1. Network partition isolates Broker-1 from Broker-2 and Broker-3
2. With RF=2 and `min.insync.replicas=1`, both partitions can accept writes
3. Ingestion Adapters connected to Broker-1 publish events to partition A
4. Flink jobs connected to Broker-2/3 publish to partition A (different leader)
5. **Result**: Two divergent streams of events, data loss when partition heals and one broker's data is discarded

**Operational Impact**:
- **Permanent data loss**: Events published during split-brain to "losing" broker partition are irretrievably lost
- **Event ordering corruption**: When partition heals, event sequence is non-deterministic
- **Recovery impossibility**: No way to reconstruct lost events as external sources (stadium sensors) provide real-time data only
- **Compliance risk**: Historical audit trail broken, potential regulatory violations for sports betting integrations

**Countermeasures**:
1. **Increase Replication Factor to 3**: Requires `min.insync.replicas=2` to guarantee quorum-based writes
2. **Configure Kafka Producer Settings**:
   ```properties
   acks=all  # Wait for all in-sync replicas
   min.insync.replicas=2  # Require 2 replicas to acknowledge
   enable.idempotence=true  # Exactly-once producer semantics
   ```
3. **Topic Configuration**:
   ```bash
   kafka-topics --alter --topic sensor-events --config min.insync.replicas=2
   ```
4. **Broker Rack Awareness**: Configure `broker.rack` to ensure replicas span availability zones
5. **Monitoring**: Alert on `UnderReplicatedPartitions` metric (should always be 0)

---

#### **C5: No Backup Strategy or RPO/RTO Definition**
**Severity**: Critical
**Section**: Data Stores (2.3), Non-Functional Requirements (7)

**Problem Description**:
The design does not mention backup procedures, point-in-time recovery, or disaster recovery planning for any data store (PostgreSQL, InfluxDB, Redis). No RPO (Recovery Point Objective) or RTO (Recovery Time Objective) defined.

**Failure Scenario**:
1. PostgreSQL Multi-AZ RDS experiences regional outage (AWS us-east-1 incident precedent)
2. Automated failover succeeds, but last 5 minutes of writes lost due to replication lag
3. No recent backup available for point-in-time recovery
4. **Result**:
   - 5 minutes of event history permanently lost
   - User subscriptions created during window lost (billing disputes)
   - User preference updates lost (customer complaints)

**Operational Impact**:
- **Permanent data loss**: Events during disaster window cannot be reconstructed from source systems (real-time feeds)
- **Financial liability**: Lost subscription records lead to billing errors and potential legal disputes
- **Regulatory non-compliance**: Sports betting integrations require auditable event history
- **Trust erosion**: Data loss incident requires public disclosure, damages brand reputation
- **Recovery time unknown**: Without defined RTO, business cannot plan for acceptable downtime

**Countermeasures**:
1. **PostgreSQL Backup Strategy**:
   - Enable automated RDS backups with 7-day retention
   - Point-in-time recovery (PITR) enabled with 5-minute granularity
   - Weekly full snapshots copied to separate AWS region (cross-region disaster recovery)
   - **Defined RPO**: 5 minutes (acceptable loss window)
   - **Defined RTO**: 15 minutes (restoration from snapshot)
2. **InfluxDB Backup**:
   - Daily snapshots to S3 with 30-day retention
   - Replicate to second InfluxDB cluster in standby region (eventual consistency acceptable for metrics)
3. **Redis Persistence**:
   - Enable AOF (Append-Only File) with `appendfsync everysec`
   - Daily RDB snapshots to S3
   - Session data loss acceptable (users re-authenticate), but translation cache should be reconstructible
4. **Disaster Recovery Testing**:
   - Quarterly DR drill: Restore production backup to staging environment
   - Validate data integrity and measure actual RTO
   - Document runbook with step-by-step recovery procedures

---

#### **C6: Database Schema Backward Compatibility Not Addressed**
**Severity**: Critical
**Section**: Deployment (6.4), PostgreSQL Schema (4.1)

**Problem Description**:
Deployment strategy states "Flyway scripts executed manually before deployment" but provides no guidance on backward-compatible schema changes. With rolling deployments to EKS, old and new application versions run simultaneously during rollout, creating schema compatibility conflicts.

**Failure Scenario**:
1. New schema migration adds non-nullable column `events.sequence_number BIGINT NOT NULL`
2. Migration executed before EKS deployment begins
3. Old application pods (50% still running) attempt to write events without `sequence_number`
4. **Result**: `INSERT` statements fail with constraint violation error, all event writes blocked for 5-10 minutes during rollout
5. Real-time event delivery completely stops, customers see "service unavailable"

**Operational Impact**:
- **Service outage**: Event ingestion pipeline blocks until all pods upgraded
- **Kafka lag accumulation**: 5-10 minutes of downtime at 10,000 events/sec = 300,000+ buffered events requiring hours to drain
- **Data loss risk**: If Kafka retention policy expires before lag cleared, events lost
- **Rollback complexity**: Cannot rollback application without also rolling back schema, requiring downtime
- **Deployment failure cascade**: Failed deployments block future releases until coordination issues resolved

**Countermeasures**:
1. **Expand-Contract Migration Pattern**:
   - **Phase 1 (Week 1)**: Add column as nullable `ALTER TABLE events ADD COLUMN sequence_number BIGINT NULL`
   - **Phase 2 (Week 2)**: Deploy application code that populates new column
   - **Phase 3 (Week 3)**: Backfill historical nulls with background job
   - **Phase 4 (Week 4)**: Add NOT NULL constraint after verifying 100% population
2. **Automated Compatibility Checks**:
   - CI pipeline validates migrations using `flyway validate` with dry-run
   - Schema diff tool compares old/new versions, fails build if breaking changes detected
3. **Blue-Green Schema Strategy**:
   - Run separate database instances for blue/green deployments
   - After validating new version, migrate traffic and promote new database to primary
4. **Feature Flags for Schema Changes**:
   - Use flags to gradually enable code paths using new columns
   - Allows instant rollback by disabling flag without database changes

---

#### **C7: No Poison Message Handling or Dead Letter Queue**
**Severity**: Critical
**Section**: Error Handling (6.1), Stream Processors (3.3.2)

**Problem Description**:
The design specifies "Commit offset only after successful processing" but does not address how to handle poison messages (malformed events that repeatedly cause processing failures). A single bad message can block the entire Kafka partition indefinitely.

**Failure Scenario**:
1. Stadium Sensor Adapter publishes malformed JSON event to `sensor-events` topic (missing required field)
2. Flink Enrichment Job attempts to parse, throws `JsonParseException`
3. Job retries processing indefinitely (no offset commit)
4. **Result**: Partition blocked, all subsequent valid events on same partition cannot be processed
5. 1/3 of stadium sensors affected (assuming 3 Kafka partitions), real-time updates for those sensors stop completely

**Operational Impact**:
- **Partial service outage**: Affected partitions block indefinitely until manual intervention
- **Detection delay**: No automatic alerting for "stuck consumer" condition in design
- **Manual remediation required**: On-call engineer must identify poison message, manually skip offset, redeploy consumer
- **SLA violation**: Each incident requires 30-60 minutes to detect and resolve, exceeding monthly downtime budget
- **Cascading failures**: Other consumers reading same partition also blocked

**Countermeasures**:
1. **Dead Letter Queue (DLQ) Pattern**:
   - After 3 consecutive failures for same offset, publish message to `sensor-events-dlq` topic
   - Commit original offset to unblock partition
   - Separate monitoring job processes DLQ for analysis and manual recovery
2. **Configurable Retry Policy**:
   ```java
   FlinkKafkaConsumer
     .setDeserializationSchema(new ErrorTolerantDeserializer())
     .setCommitOffsetsOnCheckpoints(true)
     .setStartFromGroupOffsets();
   ```
3. **Graceful Degradation**:
   - Flink job catches deserialization errors, logs error with message payload
   - Publishes synthetic "error event" downstream with `{type: "processing_error", original_payload: ...}`
   - Continues processing next message
4. **Schema Validation at Ingestion**:
   - Ingestion Adapters validate against JSON Schema before publishing to Kafka
   - Reject malformed events at boundary, return 400 to upstream source
5. **Monitoring Alerts**:
   - Alert on `kafka_consumer_lag > 1000` for more than 2 minutes
   - Alert on `deserialization_error_rate > 1%`

---

#### **C8: No Timeout Configuration for External API Calls**
**Severity**: Critical
**Section**: Implementation Guidelines (6.1), External APIs (2.6)

**Problem Description**:
The design mentions OpenAI and Stripe API calls but does not specify timeout configurations. Without timeouts, threads can hang indefinitely on network issues, exhausting connection pools and causing service-wide outages.

**Failure Scenario**:
1. OpenAI API experiences partial outage where TCP connections accepted but no response sent
2. Flink Translation Job threads wait indefinitely (default JVM socket timeout is infinite)
3. All available worker threads blocked on hung connections
4. **Result**: Flink job stops processing entirely, Kafka consumer lag increases, entire real-time pipeline frozen

**Operational Impact**:
- **Complete service outage**: All stream processing stops when thread pool exhausted
- **Resource starvation**: Hung connections consume memory and file descriptors, can cause OOM crashes
- **Slow failure detection**: Without timeouts, monitoring sees "processing" state but no actual progress
- **Manual restart required**: Hung threads may not respond to graceful shutdown, require kill -9 and redeployment
- **Cascading resource exhaustion**: Other services sharing infrastructure affected by resource starvation

**Countermeasures**:
1. **Aggressive Timeout Configuration**:
   ```java
   RestTemplate restTemplate = new RestTemplateBuilder()
     .setConnectTimeout(Duration.ofSeconds(2))
     .setReadTimeout(Duration.ofSeconds(5))
     .build();
   ```
2. **Per-Service Timeout Tuning**:
   - OpenAI API: 5-second read timeout (translation non-critical)
   - Stripe API: 10-second read timeout (payment operations require reliability)
   - Database connections: 30-second query timeout
3. **Circuit Breaker with Timeout**:
   ```java
   @CircuitBreaker(name = "openai", fallbackMethod = "skipTranslation")
   @TimeLimiter(name = "openai", fallbackMethod = "skipTranslation")
   public String translateContent(String content) { ... }
   ```
4. **Bulkhead Thread Pools**:
   - Isolate external API calls to dedicated thread pools
   - OpenAI pool: Max 10 threads (limits blast radius)
   - Stripe pool: Max 5 threads
5. **Monitoring**:
   - Alert on `http_request_duration_seconds{quantile="0.99"} > 10s`
   - Alert on `thread_pool_active_threads / thread_pool_max_threads > 0.9`

---

### **TIER 2: SIGNIFICANT ISSUES (Partial System Impact / Difficult Recovery)**

#### **S1: Redis Pub/Sub Single Point of Failure for Real-Time Delivery**
**Severity**: Significant
**Section**: Component Responsibilities (3.3.3), WebSocket Gateway design

**Problem Description**:
The WebSocket Gateway relies on Redis Pub/Sub as the exclusive mechanism for receiving events to broadcast. Redis Pub/Sub is fire-and-forget with no persistence or replay capability. If a gateway instance experiences momentary Redis disconnection, all events published during that window are permanently lost to connected clients.

**Failure Scenario**:
1. Redis cluster node undergoes failover (primary → replica promotion)
2. WebSocket Gateway loses Redis connection for 2-3 seconds during failover
3. Flink Enrichment Job continues publishing to Redis Pub/Sub during this window
4. **Result**: 2-3 seconds of events (20-30 events at 10/sec rate) never reach gateway, connected clients miss critical updates

**Operational Impact**:
- **Intermittent data loss**: Clients miss events during Redis transient failures
- **Silent failures**: No error indication to clients that events were dropped
- **Recovery complexity**: Requires client-side gap detection and history API polling to backfill
- **Customer complaints**: Users report "missed goals" or delayed notifications

**Countermeasures**:
1. **Hybrid Delivery Architecture**:
   - Primary: Redis Pub/Sub for best-effort real-time delivery
   - Fallback: Kafka consumer in WebSocket Gateway subscribes to `live-events` Kafka topic
   - If Redis unavailable, gateway automatically switches to Kafka consumption
2. **Persistent Event Queue**:
   - Replace Pub/Sub with Redis Streams (supports consumer groups and replay)
   - Gateway tracks last consumed event ID, can resume from last position after reconnection
3. **Client-Side Heartbeat & Gap Detection**:
   ```json
   {"type": "heartbeat", "last_event_id": 12345, "timestamp": "..."}
   ```
   - Gateway sends heartbeat every 5 seconds with last published event ID
   - Client detects gap in event sequence, requests backfill via REST API
4. **Dual Pub/Sub Channels**:
   - Publish to both Redis and Kafka topic simultaneously
   - Gateway consumes from both, deduplicates using event IDs

---

#### **S2: No Rate Limiting or Backpressure for Ingestion Adapters**
**Severity**: Significant
**Section**: Ingestion Adapters (3.3.1), Performance Targets (7.1)

**Problem Description**:
Ingestion Adapters poll/stream from external sources without rate limiting or backpressure mechanisms. During major sporting events (e.g., World Cup final), upstream sources may send 10x normal traffic, overwhelming Kafka and downstream processors.

**Failure Scenario**:
1. Major sports event triggers 100,000 events/sec (10x normal peak of 10,000/sec)
2. Stadium Sensor Adapter publishes all events to Kafka without throttling
3. Kafka brokers accept writes but disk I/O saturates, write latency increases from 5ms to 500ms
4. Flink jobs fall behind (cannot process 100k/sec), consumer lag grows to millions of messages
5. **Result**: Real-time delivery degrades to 10+ second delays, system appears "frozen" to users

**Operational Impact**:
- **SLA violation**: p95 latency target of 500ms exceeded by 20x (10+ seconds)
- **Resource exhaustion**: Kafka disk fills up, triggering emergency log retention policies and potential data loss
- **Recovery time**: Hours required to drain backlog at normal processing rates
- **Cost spike**: Auto-scaling triggers scale-out of Flink/EKS to handle load, unexpected cloud bills

**Countermeasures**:
1. **Ingestion Rate Limiting**:
   ```java
   RateLimiter rateLimiter = RateLimiter.create(10000.0); // 10k events/sec
   for (Event event : upstreamSource) {
     rateLimiter.acquire();
     kafkaProducer.send(event);
   }
   ```
2. **Backpressure from Kafka**:
   - Monitor Kafka `ProduceRequestsWaitingInPurgatory` metric
   - If backpressure detected, adapter pauses polling for 1 second
3. **Priority-Based Ingestion**:
   - High-priority events (goals, penalties) bypass rate limit
   - Low-priority events (social media mentions) throttled first during overload
4. **Adaptive Rate Limiting**:
   - Dynamically adjust limit based on downstream Kafka consumer lag
   - If lag > 10,000 messages, reduce ingestion rate by 50%
5. **Event Sampling**:
   - For high-volume low-value events (social media), sample 1-in-10 during peak load

---

#### **S3: Kafka Single Region Deployment Without Disaster Recovery**
**Severity**: Significant
**Section**: Streaming Infrastructure (2.4), Scalability & Availability (7.3)

**Problem Description**:
Kafka deployment configured with 3 brokers across 3 availability zones within single AWS region. No cross-region replication or disaster recovery plan. Regional outage (precedent: AWS us-east-1 multi-hour outage) would cause complete platform failure.

**Failure Scenario**:
1. AWS region experiences major outage affecting all availability zones (networking or control plane failure)
2. Kafka cluster becomes completely unavailable
3. All ingestion adapters fail to publish events
4. All Flink jobs stop processing
5. **Result**: Complete platform outage lasting duration of AWS regional incident (potentially 4-8 hours based on historical precedents)

**Operational Impact**:
- **Extended outage**: Regional disaster exceeds 99.9% uptime target (43.8 min/month) by 10x
- **Revenue loss**: Subscription platform unavailable during critical live events
- **Data loss**: Real-time event sources (stadium sensors) cannot be replayed, events during outage permanently lost
- **Competitor advantage**: Users switch to alternative platforms during extended outage
- **Recovery complexity**: Multi-hour RTO to restore from backups and restart all services

**Countermeasures**:
1. **Multi-Region Kafka Deployment with MirrorMaker 2**:
   - Primary region: us-east-1 (active)
   - DR region: us-west-2 (standby)
   - MirrorMaker 2 replicates topics with <1 second lag
   - DNS failover switches ingestion endpoints to DR region
2. **Active-Active Multi-Region**:
   - Deploy full stack (ingestion, Flink, databases) in two regions
   - Use global load balancer (Route53 latency-based routing)
   - Conflict-free replicated data types (CRDTs) for cross-region consistency
3. **Degraded Mode Operation**:
   - During regional outage, fail over to backup REST API in secondary region
   - Serve cached/historical data only (no real-time updates)
   - Display banner: "Real-time updates temporarily unavailable"
4. **Quarterly DR Testing**:
   - Simulate regional failure by blocking traffic to primary region
   - Measure actual failover time and data loss
   - Document runbook with automated failover scripts

---

#### **S4: WebSocket Gateway Has No Connection-Level Health Checks**
**Severity**: Significant
**Section**: API Services (3.3.3), WebSocket Protocol (5.1)

**Problem Description**:
The WebSocket Gateway maintains persistent connections but does not implement connection-level health checks or heartbeats. Clients behind NATs or mobile networks may experience silent connection drops, leading to extended periods without updates.

**Failure Scenario**:
1. Mobile client connects via cellular network with aggressive NAT timeout (60 seconds)
2. No traffic flows on WebSocket for 65 seconds during slow match period
3. NAT gateway silently drops connection without sending TCP FIN
4. **Client believes connected but receives no updates for 30+ minutes**
5. User misses critical event (goal), complains on social media

**Operational Impact**:
- **Silent failures**: Clients unaware they are disconnected, no automatic reconnection
- **Customer complaints**: "Platform doesn't work" reports during live events
- **Support burden**: Customer service team inundated with connectivity issues
- **Churn risk**: Users abandon platform after poor experience

**Countermeasures**:
1. **Bidirectional Heartbeat (WebSocket Ping/Pong)**:
   ```javascript
   // Server-side
   setInterval(() => {
     socket.ping();
   }, 30000); // 30-second heartbeat

   socket.on('pong', () => {
     socket.lastPong = Date.now();
   });

   setInterval(() => {
     if (Date.now() - socket.lastPong > 60000) {
       socket.disconnect();
     }
   }, 60000);
   ```
2. **Client-Side Reconnection Logic**:
   ```javascript
   // Client-side
   socket.on('disconnect', () => {
     setTimeout(() => {
       socket.connect();
       // Request events since last received event_id
       socket.emit('backfill', {last_event_id: lastEventId});
     }, 5000);
   });
   ```
3. **Application-Level Keepalive**:
   - Gateway sends `{"type": "keepalive", "timestamp": "..."}` every 30 seconds
   - Client expects keepalive within 60 seconds, reconnects if missing
4. **Connection Quality Monitoring**:
   - Track client-side metric: `time_since_last_message`
   - Display warning in UI if >90 seconds without message: "Connection may be unstable"

---

#### **S5: Flink Job State Not Configured for Failure Recovery**
**Severity**: Significant
**Section**: Stream Processors (3.3.2), Implementation Guidelines (6)

**Problem Description**:
The design describes three Flink jobs but does not mention checkpointing, state backend configuration, or savepoint strategies. Without checkpointing, Flink job failures require reprocessing from earliest Kafka offset, causing duplicate event deliveries.

**Failure Scenario**:
1. Flink Enrichment Job processes 1 million events, writing to PostgreSQL
2. Job crashes due to OOM error before committing Kafka offsets
3. On restart, Flink replays from last committed offset (1 hour ago)
4. **Result**: 1 million duplicate event writes to PostgreSQL, customers receive duplicate notifications

**Operational Impact**:
- **Data integrity corruption**: Historical queries return duplicate events
- **Duplicate notifications**: Users receive same alert 2-3 times (negative UX)
- **Processing delays**: Reprocessing backlog delays new events by 10-30 minutes
- **Cascading failures**: Duplicate translation API calls trigger OpenAI rate limits

**Countermeasures**:
1. **Enable Flink Checkpointing**:
   ```java
   StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
   env.enableCheckpointing(60000); // Checkpoint every 60 seconds
   env.getCheckpointConfig().setCheckpointingMode(CheckpointingMode.EXACTLY_ONCE);
   env.getCheckpointConfig().setMinPauseBetweenCheckpoints(30000);
   env.getCheckpointConfig().setCheckpointTimeout(120000);
   env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
   ```
2. **State Backend Configuration**:
   - Use RocksDB state backend for large state (streaming joins, aggregations)
   - Store checkpoints in S3 for durability
   ```java
   env.setStateBackend(new EmbeddedRocksDBStateBackend());
   env.getCheckpointConfig().setCheckpointStorage("s3://flink-checkpoints/");
   ```
3. **Externalized Checkpoints**:
   - Retain checkpoints after job cancellation for manual recovery
   ```java
   env.getCheckpointConfig().setExternalizedCheckpointCleanup(
     ExternalizedCheckpointCleanup.RETAIN_ON_CANCELLATION
   );
   ```
4. **Savepoint Strategy**:
   - Trigger savepoint before each deployment
   - Restart job from savepoint to ensure exactly-once semantics
   ```bash
   flink savepoint <job-id> s3://flink-savepoints/
   flink run -s s3://flink-savepoints/savepoint-123 enrichment-job.jar
   ```

---

#### **S6: PostgreSQL Connection Pool Not Sized for Burst Traffic**
**Severity**: Significant
**Section**: Data Stores (2.3), Performance Targets (7.1)

**Problem Description**:
The design specifies PostgreSQL as primary data store but does not mention connection pool sizing or configuration. Default Spring Boot HikariCP pool (10 connections) is insufficient for 10,000 events/sec throughput, causing connection exhaustion and query queueing.

**Failure Scenario**:
1. Major sports event triggers 10,000 events/sec load
2. Flink Enrichment Job attempts to write to PostgreSQL with 10-connection pool
3. Each write takes ~5ms, pool supports max 2,000 writes/sec (10 connections * 200 writes/sec/conn)
4. **Result**: Connection pool exhausted, queries queue for 5+ seconds, Flink job backpressures, Kafka lag increases

**Operational Impact**:
- **Latency spike**: p95 latency increases from 500ms to 10+ seconds
- **Throughput degradation**: System cannot handle rated 10,000 events/sec capacity
- **Cascading backpressure**: Kafka lag triggers auto-scaling, cost spike
- **Error rate increase**: Connection timeouts trigger retries, duplicate writes

**Countermeasures**:
1. **Right-Size Connection Pool**:
   ```yaml
   spring:
     datasource:
       hikari:
         maximum-pool-size: 50  # Tune based on load testing
         minimum-idle: 10
         connection-timeout: 5000
         idle-timeout: 300000
         max-lifetime: 600000
   ```
2. **Connection Pool Sizing Formula**:
   - `pool_size = (throughput_rps * avg_query_time_ms) / 1000`
   - For 10,000 rps at 5ms avg: `10,000 * 0.005 = 50 connections`
3. **Batch Writes**:
   - Flink job batches 100 events per PostgreSQL transaction
   - Reduces connection pressure: 10,000 events/sec → 100 transactions/sec
   ```java
   env.addSink(JdbcSink.sink(
     "INSERT INTO events ...",
     (ps, event) -> { ... },
     JdbcExecutionOptions.builder()
       .withBatchSize(100)
       .withBatchIntervalMs(1000)
       .build(),
     ...
   ));
   ```
4. **Read Replica for Queries**:
   - Route user queries to PostgreSQL read replica
   - Flink writes to primary only
   - Reduces connection contention

---

#### **S7: No Distributed Tracing for Multi-Hop Request Debugging**
**Severity**: Significant
**Section**: Logging (6.2), Correlation IDs

**Problem Description**:
The design mentions correlation IDs for request tracing but does not specify distributed tracing implementation (e.g., OpenTelemetry, Jaeger). Without trace context propagation, debugging latency issues across ingestion → Kafka → Flink → PostgreSQL → WebSocket requires manual log correlation across 5+ services.

**Failure Scenario**:
1. Customer reports 10-second delay between goal scored and notification received
2. Engineer investigates by searching logs across 6 services using correlation ID
3. **Correlation ID not propagated through Kafka message headers**
4. Cannot trace request across Flink job boundary
5. Debugging requires 2-3 hours of manual log analysis to identify bottleneck (turns out: OpenAI API timeout)

**Operational Impact**:
- **Extended MTTR**: Incident resolution takes hours instead of minutes
- **Customer satisfaction**: Cannot provide timely root cause explanations
- **Operational overhead**: Senior engineers required for routine debugging tasks
- **Latency regression risk**: Performance degradations difficult to detect and isolate

**Countermeasures**:
1. **Implement OpenTelemetry Distributed Tracing**:
   ```java
   // Ingestion Adapter
   Span span = tracer.spanBuilder("ingest-sensor-event").startSpan();
   try (Scope scope = span.makeCurrent()) {
     ProducerRecord<String, Event> record = new ProducerRecord<>("sensor-events", event);
     record.headers().add("traceparent", span.getSpanContext().toString().getBytes());
     producer.send(record);
   } finally {
     span.end();
   }
   ```
2. **Flink Trace Context Propagation**:
   ```java
   // Extract trace context from Kafka headers
   env.addSource(new FlinkKafkaConsumer<>(...))
     .map(record -> {
       String traceparent = new String(record.headers().lastHeader("traceparent").value());
       Context context = TraceContextPropagators.extract(traceparent);
       Span span = tracer.spanBuilder("enrich-event").setParent(context).startSpan();
       // Processing logic
       span.end();
       return enrichedEvent;
     });
   ```
3. **WebSocket Gateway Trace Injection**:
   - Include trace ID in WebSocket event payload
   - Client logs include trace ID for customer support correlation
4. **Jaeger/Tempo Deployment**:
   - Central trace collection backend
   - UI for visualizing request flow and latency breakdown

---

#### **S8: Stripe Webhook Processing Not Idempotent**
**Severity**: Significant
**Section**: REST API Endpoints (5.2), POST /subscriptions/webhook

**Problem Description**:
The design states webhooks "update user_subscriptions table based on event type" but does not mention idempotency handling. Stripe may send duplicate webhook events (network retries, infrastructure issues), leading to duplicate subscription activations or cancellations.

**Failure Scenario**:
1. User subscribes to premium plan, Stripe sends `customer.subscription.created` webhook
2. API updates `user_subscriptions` table, returns 200 OK
3. Network issue causes Stripe to not receive 200 response (timeout)
4. Stripe retries webhook, API processes again
5. **Result**: Duplicate subscription record created, user billed twice for same subscription

**Operational Impact**:
- **Financial errors**: Double billing leads to customer disputes and refunds
- **Support burden**: Manual reconciliation required for each duplicate event
- **Audit trail corruption**: Subscription history shows incorrect duplicate entries
- **Legal risk**: Payment processing errors may violate financial regulations

**Countermeasures**:
1. **Stripe Event ID Deduplication**:
   ```sql
   CREATE TABLE stripe_webhook_events (
     event_id VARCHAR(255) PRIMARY KEY,
     event_type VARCHAR(100) NOT NULL,
     processed_at TIMESTAMPTZ DEFAULT NOW()
   );
   CREATE INDEX idx_stripe_events_processed ON stripe_webhook_events(processed_at);
   ```
   ```java
   @Transactional
   public void processWebhook(StripeEvent event) {
     // Check if already processed
     if (stripeEventRepository.existsById(event.getId())) {
       log.info("Duplicate webhook ignored: {}", event.getId());
       return;
     }
     // Process event
     updateSubscription(event);
     // Record processing
     stripeEventRepository.save(new StripeWebhookEvent(event.getId(), event.getType()));
   }
   ```
2. **Stripe Idempotency Keys**:
   - For outbound Stripe API calls, generate deterministic idempotency key
   ```java
   RequestOptions options = RequestOptions.builder()
     .setIdempotencyKey(generateIdempotencyKey(subscriptionId, operationType))
     .build();
   Subscription.create(params, options);
   ```
3. **Webhook Event Table Retention**:
   - Retain deduplication records for 30 days (Stripe retry window)
   - Background job purges old records
4. **Upsert Semantics for Subscription Updates**:
   ```sql
   INSERT INTO user_subscriptions (stripe_subscription_id, ...)
   VALUES (?, ...)
   ON CONFLICT (stripe_subscription_id) DO UPDATE SET
     status = EXCLUDED.status,
     updated_at = NOW();
   ```

---

### **TIER 3: MODERATE ISSUES (Operational Improvement Opportunities)**

#### **M1: No SLO/SLA Definition with Error Budgets**
**Severity**: Moderate
**Section**: Non-Functional Requirements (7.3)

**Problem Description**:
The design specifies 99.9% uptime target but does not define SLOs (Service Level Objectives), SLIs (Service Level Indicators), or error budgets. Without these, the team cannot make data-driven decisions about release velocity vs. reliability trade-offs.

**Operational Impact**:
- **No objective release gating**: Cannot determine if reliability budget allows risky deployment
- **Alert fatigue**: All incidents treated equally urgent without SLO-based prioritization
- **Toil accumulation**: Team focuses on firefighting instead of strategic reliability improvements
- **Customer dissatisfaction**: Implicit SLA expectations misaligned with actual service behavior

**Countermeasures**:
1. **Define SLIs**:
   - **Availability SLI**: Ratio of successful requests to total requests (5xx errors excluded)
   - **Latency SLI**: 95th percentile end-to-end event delivery time < 500ms
   - **Completeness SLI**: Ratio of events delivered to events ingested (tracks data loss)
2. **Define SLOs**:
   - Availability SLO: 99.9% of requests succeed (43.2 minutes downtime/month)
   - Latency SLO: 99% of events delivered within 500ms
   - Completeness SLO: 99.99% of events delivered (max 1 dropped event per 10,000)
3. **Error Budget Policy**:
   - 100% budget remaining: Fast release cadence (daily deployments)
   - 50-100% budget: Normal cadence (2-3 deployments/week)
   - 0-50% budget: Reliability freeze, focus on postmortems and fixes
   - Budget exhausted: Emergency freeze, executive approval required for deploys
4. **SLO Monitoring Dashboard**:
   - Real-time error budget burn rate
   - Trend analysis: Project budget exhaustion date
   - Alert when burn rate exceeds 2x normal rate

---

#### **M2: No Capacity Planning or Autoscaling for Flink Jobs**
**Severity**: Moderate
**Section**: Stream Processors (3.3.2), Scalability (7.3)

**Problem Description**:
The design specifies HPA for WebSocket Gateway but does not mention autoscaling or capacity planning for Flink jobs. Peak load of 10,000 events/sec requires manual capacity provisioning, creating risk of under-provisioning during viral events.

**Operational Impact**:
- **Performance degradation**: Under-provisioned Flink jobs cause Kafka lag during unexpected traffic spikes
- **Cost inefficiency**: Over-provisioned jobs waste resources during off-peak hours (80% of time)
- **Manual intervention**: On-call engineer must manually scale Flink parallelism during incidents
- **Slow response**: Manual scaling takes 10-15 minutes, during which SLA violated

**Countermeasures**:
1. **Flink Adaptive Scaling (Kubernetes Operator)**:
   ```yaml
   apiVersion: flink.apache.org/v1beta1
   kind: FlinkDeployment
   spec:
     job:
       parallelism: 4
       scalingPolicy:
         enabled: true
         metricsWindow: 5m
         scalingThreshold:
           busyTime: 0.8  # Scale up if busy >80%
           lag: 10000     # Scale up if consumer lag >10k
   ```
2. **Kafka Consumer Lag-Based Autoscaling**:
   - Monitor `kafka_consumergroup_lag` metric
   - Trigger Flink job scale-up when lag exceeds 5,000 messages for >2 minutes
   - Scale down when lag <500 for >10 minutes
3. **Capacity Planning Model**:
   - Baseline capacity: Handle 5,000 events/sec continuously (50% headroom)
   - Burst capacity: Scale to 20,000 events/sec within 2 minutes
   - Load testing: Validate capacity model quarterly with realistic traffic patterns
4. **Predictive Scaling**:
   - Use historical event data to predict traffic patterns (e.g., match schedules)
   - Pre-scale Flink jobs 15 minutes before major events

---

#### **M3: No Runbook or Incident Response Procedures**
**Severity**: Moderate
**Section**: Implementation Guidelines (6), Operational Readiness

**Problem Description**:
The design does not mention runbooks, incident response procedures, or on-call escalation policies. During production incidents, on-call engineers must improvise response, increasing MTTR and risk of incorrect remediation.

**Operational Impact**:
- **Extended MTTR**: Engineers waste time investigating known issues
- **Inconsistent response**: Different engineers use different remediation approaches
- **Knowledge silos**: Tribal knowledge not documented, team scaling blocked
- **Burnout risk**: On-call engineers stressed by lack of clear procedures

**Countermeasures**:
1. **Create Service Runbooks**:
   - **Kafka Partition Lag**: Symptoms, diagnosis steps, remediation (scale Flink, skip bad offset)
   - **PostgreSQL Connection Exhaustion**: Symptoms, emergency connection increase procedure
   - **Redis Failover**: Expected impact, monitoring dashboard links, rollback steps
   - **WebSocket Gateway OOM**: Heap dump collection, memory leak analysis procedure
2. **Incident Response Framework**:
   - **Severity Definitions**: SEV1 (user-facing outage), SEV2 (degraded), SEV3 (minor)
   - **Escalation Policy**: SEV1 auto-pages team lead, SEV2 alerts on-call, SEV3 ticket queue
   - **Communication Templates**: Status page updates, customer-facing messaging
3. **Postmortem Process**:
   - Blameless postmortem required for all SEV1/SEV2 incidents
   - Template: Timeline, root cause, impact, action items with owners
   - Review in weekly team meeting, track action items to completion
4. **On-Call Rotation**:
   - Primary/secondary on-call engineers
   - Weekly rotation with handoff meeting
   - Compensation: Time-off in lieu or on-call pay

---

#### **M4: Log Retention and Aggregation Strategy Not Defined**
**Severity**: Moderate
**Section**: Logging (6.2), Correlation IDs

**Problem Description**:
The design specifies structured JSON logging with correlation IDs but does not mention log retention policies, aggregation backend (e.g., ELK, CloudWatch Logs Insights), or query capabilities. Without centralized logging, debugging distributed issues requires SSH access to individual pods.

**Operational Impact**:
- **Debugging inefficiency**: Engineers SSH to multiple pods to correlate logs
- **Log loss**: Ephemeral pod logs lost on pod termination
- **Compliance risk**: Audit requirements may mandate log retention (e.g., 90 days for financial transactions)
- **Security investigation**: Cannot reconstruct attack timeline from historical logs

**Countermeasures**:
1. **Centralized Log Aggregation**:
   - Deploy Fluent Bit daemonset on EKS to ship logs to CloudWatch Logs
   - Alternative: ELK stack (Elasticsearch, Logstash, Kibana) on separate cluster
2. **Log Retention Policy**:
   - **Application logs**: 30-day retention in hot storage, 1-year in S3 cold storage
   - **Audit logs** (subscriptions, payments): 7-year retention for compliance
   - **Debug logs**: 7-day retention (verbose, high volume)
3. **Structured Logging Standard**:
   ```json
   {
     "timestamp": "2026-02-11T10:30:00Z",
     "level": "ERROR",
     "service": "enrichment-job",
     "correlation_id": "abc-123",
     "trace_id": "xyz-789",
     "event_id": 12345,
     "message": "Failed to write to PostgreSQL",
     "error": {
       "type": "SQLException",
       "message": "Connection timeout"
     }
   }
   ```
4. **Log Query Dashboards**:
   - Pre-built queries: "All errors in last 1 hour", "Events for correlation ID", "Slow queries >1s"
   - Saved searches for common debugging patterns

---

#### **M5: No Feature Flag System for Progressive Rollout**
**Severity**: Moderate
**Section**: Deployment (6.4), Non-Functional Requirements (7)

**Problem Description**:
The deployment strategy mentions rolling updates but does not include feature flags for progressive rollout or instant rollback. High-risk features (e.g., new translation provider) require full redeployment to disable, causing extended downtime if issues discovered.

**Operational Impact**:
- **Risky deployments**: All-or-nothing rollouts increase blast radius of bugs
- **Slow rollback**: Kubernetes rollback takes 5-10 minutes, during which service degraded
- **A/B testing blocked**: Cannot test new features on subset of users
- **Emergency changes**: Requires emergency deployment to disable problematic feature

**Countermeasures**:
1. **Feature Flag Service**:
   - Use LaunchDarkly, Split.io, or self-hosted Unleash
   - Flags stored in Redis with real-time updates (no service restart required)
   ```java
   if (featureFlags.isEnabled("new-translation-provider", userId)) {
     return newTranslationService.translate(content);
   } else {
     return openAIService.translate(content);
   }
   ```
2. **Progressive Rollout Strategy**:
   - 1% rollout for 1 hour, monitor error rates
   - 10% rollout for 6 hours, monitor latency and customer feedback
   - 50% rollout for 24 hours, monitor business metrics
   - 100% rollout if all SLIs healthy
3. **Automated Rollback**:
   - Monitor SLI during rollout
   - If error rate >2x baseline, automatically disable feature flag
   - Alert on-call engineer with rollback summary
4. **Kill Switch for Critical Paths**:
   - Global kill switch for external dependencies (OpenAI, Stripe)
   - If dependency degraded, instantly disable features depending on it
   - Graceful degradation: Show "translation unavailable" instead of errors

---

#### **M6: No Resource Quotas or Cost Controls**
**Severity**: Moderate
**Section**: Infrastructure & Deployment (2.5), Scalability (7.3)

**Problem Description**:
The design specifies autoscaling for WebSocket Gateway but does not mention resource quotas, cost budgets, or protection against runaway scaling. Misconfigured HPA could scale to hundreds of pods, causing unexpected $10,000+ daily cloud bills.

**Operational Impact**:
- **Cost spike**: Autoscaling bug or DDoS attack triggers massive scale-out
- **Budget overrun**: Monthly cloud spend exceeds budget by 10x, requires emergency cost-cutting
- **Resource exhaustion**: Runaway scaling consumes all available EKS node capacity
- **Service impact**: Other services starved of resources due to quota exhaustion

**Countermeasures**:
1. **Kubernetes Resource Quotas**:
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: compute-quota
     namespace: production
   spec:
     hard:
       requests.cpu: "100"
       requests.memory: 200Gi
       pods: "100"
   ```
2. **HPA Max Replicas**:
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   spec:
     minReplicas: 3
     maxReplicas: 20  # Hard cap to prevent runaway scaling
   ```
3. **AWS Budget Alerts**:
   - Create AWS Budget with $5,000 monthly threshold
   - Alert at 80% ($4,000) and 100% ($5,000) utilization
   - Automated alert to engineering and finance teams
4. **Cost Attribution Tags**:
   - Tag all resources with `service`, `environment`, `team`
   - Weekly cost reports showing per-service spend
   - Identify cost anomalies early (10x increase week-over-week)

---

#### **M7: OpenSearch Not Utilized for Event Search**
**Severity**: Moderate
**Section**: Technology Stack (2.3), GET /events/history endpoint

**Problem Description**:
The design includes OpenSearch 2.11 in technology stack but GET /events/history endpoint queries PostgreSQL directly. Complex search queries (full-text, fuzzy matching, aggregations) on PostgreSQL are slow and resource-intensive.

**Operational Impact**:
- **Poor query performance**: Full-text search on JSONB payload requires sequential scans
- **Database load**: Heavy analytics queries impact real-time write performance
- **Limited search capabilities**: Cannot provide advanced features like typo tolerance, synonyms
- **Wasted infrastructure**: OpenSearch cluster provisioned but underutilized

**Countermeasures**:
1. **Implement Change Data Capture (CDC)**:
   - Use Debezium to stream PostgreSQL changes to Kafka topic `postgres.events.cdc`
   - Flink job consumes CDC stream, writes to OpenSearch index
   - Near real-time search index (<5 second lag)
2. **OpenSearch Index Schema**:
   ```json
   {
     "mappings": {
       "properties": {
         "event_id": {"type": "long"},
         "event_type": {"type": "keyword"},
         "timestamp": {"type": "date"},
         "payload": {"type": "nested"},
         "enriched_metadata": {"type": "nested"},
         "full_text": {"type": "text", "analyzer": "standard"}
       }
     }
   }
   ```
3. **Query Routing**:
   - Simple queries (by ID, timestamp range): PostgreSQL
   - Complex queries (full-text, aggregations): OpenSearch
   - Client specifies query complexity in API request
4. **Search API Endpoint**:
   ```
   GET /events/search?q=team:barcelona&event_type=goal&time_range=24h
   ```

---

#### **M8: No Chaos Engineering or Resilience Testing**
**Severity**: Moderate
**Section**: Testing Strategy (6.3)

**Problem Description**:
The testing strategy mentions "random pod terminations, network partition simulations" but does not specify chaos engineering framework (e.g., Chaos Mesh, Gremlin), test scenarios, or success criteria.

**Operational Impact**:
- **Unvalidated resilience**: Fault tolerance mechanisms not tested until real incident
- **Unknown failure modes**: Team discovers reliability gaps during production outages
- **False confidence**: Design assumes mechanisms work, but never validated under realistic failure conditions
- **High-severity incidents**: First failure of redundancy design happens in production with customer impact

**Countermeasures**:
1. **Deploy Chaos Mesh on EKS**:
   ```yaml
   apiVersion: chaos-mesh.org/v1alpha1
   kind: PodChaos
   metadata:
     name: kill-enrichment-job
   spec:
     action: pod-kill
     mode: one
     selector:
       namespaces: ["production"]
       labelSelectors:
         app: enrichment-job
     scheduler:
       cron: "@hourly"
   ```
2. **Chaos Experiment Scenarios**:
   - **Kafka broker failure**: Kill 1 broker, verify partition re-election and continued processing
   - **PostgreSQL failover**: Trigger RDS failover, measure downtime and data loss
   - **Redis cluster failure**: Kill primary node, verify replica promotion and Pub/Sub continuity
   - **Network partition**: Isolate WebSocket gateway from Redis, verify fallback to Kafka
   - **Latency injection**: Add 5-second delay to OpenAI API, verify circuit breaker activates
3. **Game Day Exercises**:
   - Quarterly team exercise simulating major incident (e.g., regional outage)
   - Team practices runbooks, measures MTTR, identifies gaps
   - Update procedures based on lessons learned
4. **Success Criteria**:
   - Zero data loss during infrastructure failures
   - Automatic recovery within 5 minutes (no manual intervention)
   - Customer-facing SLIs remain within SLO during failures

---

### **TIER 4: MINOR IMPROVEMENTS & POSITIVE OBSERVATIONS**

#### **Minor Improvement 1: Correlation IDs Should Include User Context**
**Severity**: Minor
**Section**: Logging (6.2)

**Enhancement Opportunity**:
Current correlation ID design covers request tracing but does not include user context (user_id, session_id). Adding user context improves customer support debugging.

**Recommendation**:
Extend correlation ID to structured format:
```
correlation_id: {trace_id}-{user_id}-{session_id}
Example: abc-123-user-456-sess-789
```

---

#### **Minor Improvement 2: Translation Cache TTL May Be Too Short**
**Severity**: Minor
**Section**: Translation Job (3.3.2)

**Enhancement Opportunity**:
Translation cache configured with 5-minute TTL. For historical event replay (common use case), users may request same event multiple times within 1-2 hour window, requiring redundant OpenAI API calls.

**Recommendation**:
Implement tiered cache:
- Hot cache: Redis 5-minute TTL for real-time events
- Warm cache: Redis 24-hour TTL for events <7 days old
- Cold cache: PostgreSQL permanent storage for events >7 days old

---

#### **Minor Improvement 3: WebSocket Message Compression Not Mentioned**
**Severity**: Minor
**Section**: WebSocket Protocol (5.1)

**Enhancement Opportunity**:
WebSocket messages transmit full event payload including translations. For mobile clients on cellular networks, bandwidth optimization via compression (permessage-deflate) could reduce data usage by 60-70%.

**Recommendation**:
Enable WebSocket per-message compression:
```javascript
const io = require('socket.io')(server, {
  perMessageDeflate: {
    threshold: 1024  // Compress messages >1KB
  }
});
```

---

#### **Positive Observation 1: Multi-AZ PostgreSQL with Automated Failover**
The design correctly specifies Multi-AZ RDS deployment with automated failover, providing ~1-2 minute RTO for database availability. This is appropriate for the target 99.9% SLA.

---

#### **Positive Observation 2: Redis Cluster Replication**
The 6-node Redis cluster (3 primary + 3 replica) provides good availability for the cache and Pub/Sub layers. Replica promotion on primary failure should occur within 5-10 seconds.

---

#### **Positive Observation 3: Structured Logging with Correlation IDs**
The design includes structured JSON logging with correlation IDs propagated through processing stages, which is essential for distributed system observability. This demonstrates awareness of operational debugging requirements.

---

#### **Positive Observation 4: Kafka Offset Commit Strategy**
The design specifies "commit offset only after successful processing," which is the correct approach for at-least-once delivery semantics. Combined with idempotency mechanisms (recommended above), this can achieve effectively-once processing.

---

#### **Positive Observation 5: Appropriate Use of Reactive Streams**
Spring WebFlux for reactive streams is well-suited for the WebSocket Gateway's use case (50,000 concurrent connections). Non-blocking I/O will significantly reduce memory footprint compared to traditional thread-per-connection models.

---

## Summary Statistics

### Issues Detected by Severity
- **Critical (Tier 1)**: 8 issues - System-wide failure risk, data loss, or unrecoverable states
- **Significant (Tier 2)**: 8 issues - Partial system impact with difficult recovery
- **Moderate (Tier 3)**: 8 issues - Operational improvement opportunities
- **Minor (Tier 4)**: 3 improvements + 5 positive observations

### Critical Issue Categories
- **Transaction & Consistency**: C1 (distributed transactions), C2 (idempotency)
- **Failure Isolation**: C3 (circuit breakers), C8 (timeouts)
- **Data Integrity**: C5 (backup/RPO/RTO)
- **Availability**: C4 (Kafka split-brain)
- **Deployment Safety**: C6 (schema compatibility)
- **Fault Recovery**: C7 (poison messages)

### Recommended Priority Order for Remediation
1. **Week 1**: C2 (idempotency), C3 (circuit breakers), C8 (timeouts) - Prevents cascading failures
2. **Week 2**: C1 (distributed transactions), C7 (DLQ) - Prevents data loss
3. **Week 3**: C4 (Kafka RF=3), C5 (backup strategy) - Disaster recovery foundation
4. **Week 4**: C6 (schema compatibility), S5 (Flink checkpointing) - Deployment safety
5. **Weeks 5-8**: Address Significant and Moderate issues based on operational pain points

---

## Conclusion

This design demonstrates solid foundational understanding of event streaming architectures with appropriate technology choices (Kafka, Flink, PostgreSQL Multi-AZ). However, **8 critical reliability gaps** must be addressed before production deployment, particularly around distributed transaction coordination, idempotency guarantees, circuit breakers, and disaster recovery planning.

The most severe risks are:
1. Silent data loss from missing distributed transaction coordination (C1)
2. Cascading failures from unprotected external API dependencies (C3, C8)
3. Kafka split-brain scenarios from RF=2 configuration (C4)
4. Permanent data loss from undefined backup/recovery procedures (C5)

Implementing the recommended countermeasures—especially transactional outbox pattern, circuit breakers with timeouts, Kafka RF=3 with min.insync.replicas=2, and comprehensive backup strategy—will elevate this design to production-ready status aligned with the 99.9% availability target.
