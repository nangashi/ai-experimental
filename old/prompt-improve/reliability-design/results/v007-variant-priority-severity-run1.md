# Reliability Design Review: Real-Time Event Streaming Platform
**Review Date**: 2026-02-11
**Reviewer**: Reliability Design Reviewer (v007-variant-priority-severity)
**Document**: test-document-round-007.md

---

## Phase 1: Structural Analysis

### System Components
- **Ingestion Layer**: Stadium Sensor Adapter, Broadcast API Adapter, Social Media Adapter
- **Streaming Infrastructure**: Apache Kafka (3 brokers, RF=2), Apache Flink (Enrichment, Aggregation, Translation jobs)
- **Data Stores**: PostgreSQL (Multi-AZ RDS), InfluxDB, Redis Cluster (6 nodes), OpenSearch
- **Delivery Layer**: WebSocket Gateway (Socket.IO + Redis adapter), REST API
- **External Services**: OpenAI API, Stripe API

### Data Flow Paths
1. External sources → Adapters → Kafka topics → Flink jobs → PostgreSQL/InfluxDB
2. Flink → Redis Pub/Sub → WebSocket Gateway → Clients
3. Client queries → REST API → PostgreSQL/Redis → Response
4. Stripe webhooks → REST API → PostgreSQL updates

### External Dependencies (Criticality)
- **Critical**: PostgreSQL (event persistence), Kafka (event backbone), Redis (real-time delivery)
- **High**: Stripe (subscription management), external event sources (sensors, broadcast APIs)
- **Medium**: OpenAI API (translation), InfluxDB (metrics), OpenSearch (search)

### Explicitly Mentioned Reliability Mechanisms
- Multi-AZ RDS with automated failover
- Redis Cluster with replication (3 primary + 3 replica)
- Kafka replication factor 2
- HPA for WebSocket gateway (CPU-based)
- Correlation IDs for tracing
- Offset commit after successful Kafka processing
- 503 responses with retry-after on database failures

---

## Phase 2: Problem Detection (Severity-Ordered)

## Tier 1: Critical Issues (System-Wide Impact)

### C1. Missing Idempotency Keys for Kafka Event Processing
**Component**: Flink Enrichment Job → PostgreSQL `events` table
**Failure Scenario**: Flink job crashes after writing to PostgreSQL but before committing Kafka offset. On restart, the same event is reprocessed and written again to `events` table, creating duplicate records. The `event_id BIGSERIAL` auto-generates new IDs, so duplicate detection is impossible. Downstream consumers (WebSocket clients, analytics) receive duplicate events, corrupting metrics and user experience.

**Impact**: Data integrity violation, metric accuracy degradation, potential billing errors if events are monetized.

**Countermeasures**:
- Add unique constraint on natural key: `UNIQUE(source, event_type, timestamp, hash(payload))` to prevent duplicate inserts
- Implement application-level idempotency keys in payload, check before insertion
- Use Flink's exactly-once semantics with Kafka transactions and 2PC sink

### C2. No Transaction Boundaries for Multi-Table Writes
**Component**: Stripe webhook handler (Section 5, `/subscriptions/webhook`)
**Failure Scenario**: Webhook updates `user_subscriptions.status` to "active", then crashes before updating `user_preferences` or invalidating session cache. User has active subscription in DB but outdated session data in Redis, causing access denial. Stripe sends webhook only once; manual reconciliation required.

**Impact**: Revenue loss (paying users locked out), customer support burden, data inconsistency requiring manual intervention.

**Countermeasures**:
- Wrap all related updates in PostgreSQL transaction with `BEGIN/COMMIT`
- Use outbox pattern: write webhook event to `webhook_events` table in same transaction, async processor reads and applies side effects
- Implement webhook replay mechanism with deduplication based on Stripe event ID

### C3. Missing Circuit Breakers for External API Calls
**Component**: Flink Translation Job → OpenAI API (Section 3)
**Failure Scenario**: OpenAI API becomes slow (5s response time) or returns 500 errors. Translation job threads block waiting for responses, exhausting Flink task slots. All stream processing halts, including non-translation jobs sharing the same cluster. Event processing stops system-wide.

**Impact**: Complete platform outage affecting all users, cascading failure across all Flink jobs.

**Countermeasures**:
- Implement circuit breaker (e.g., Resilience4j) with failure threshold (e.g., 50% errors in 10s window)
- Set aggressive timeout (e.g., 2s) for OpenAI calls
- Degrade gracefully: skip translation on circuit open, serve events in original language
- Isolate translation job in separate Flink cluster to prevent blast radius expansion

### C4. No Distributed Transaction Coordination for Event Enrichment
**Component**: Flink Enrichment Job writing to PostgreSQL + Redis Pub/Sub (Section 3, data flow step 2)
**Failure Scenario**: Enrichment job writes event to PostgreSQL `events` table, then crashes before publishing to Redis Pub/Sub `live-events` channel. PostgreSQL commit succeeds, but WebSocket clients never receive the event. Historical queries show the event, but real-time users miss it. No retry mechanism exists.

**Impact**: Real-time delivery inconsistency, user complaints about missing live updates, data duplication if job restarts and processes again.

**Countermeasures**:
- Implement transactional outbox pattern: write event + outbox entry in single PostgreSQL transaction, separate process reads outbox and publishes to Redis
- Use Kafka as source of truth: WebSocket gateway consumes directly from Kafka instead of Redis Pub/Sub
- Add change data capture (CDC) on PostgreSQL to stream changes to Kafka/Redis

### C5. Missing Timeout Configuration for Database Queries
**Component**: REST API and Flink jobs accessing PostgreSQL/InfluxDB (Sections 3, 5)
**Failure Scenario**: Slow query (e.g., `GET /events/history` with large time range) takes 60s. No timeout configured; connections accumulate in pool. Connection pool exhausted (default max connections ~100). All subsequent requests block waiting for available connections, causing cascading failures across all API endpoints.

**Impact**: Complete API unavailability, WebSocket gateway degradation if sharing same DB pool.

**Countermeasures**:
- Set statement timeout in PostgreSQL (`statement_timeout = 10s`)
- Configure connection pool timeout (e.g., HikariCP `connectionTimeout = 5s`)
- Add application-level query timeout in Spring Data JPA (`@QueryHints(timeout = 5000)`)
- Implement bulkhead isolation: separate connection pools for critical vs. non-critical endpoints

### C6. No Backup and Restore Procedures Defined
**Component**: PostgreSQL (Section 2), InfluxDB
**Failure Scenario**: AZ-wide outage corrupts both PostgreSQL primary and standby replicas. No backup restoration procedure documented. Team scrambles to find latest snapshot, discovers backups are 24 hours old, and restoration process takes 4 hours. 28 hours of event data lost permanently.

**Impact**: Catastrophic data loss, business continuity failure, regulatory compliance violation (if event data is legally required).

**Countermeasures**:
- Define and test backup strategy: automated daily snapshots + PITR with WAL archiving
- Document RPO (e.g., 1 hour) and RTO (e.g., 30 minutes) targets
- Schedule quarterly disaster recovery drills with full restore validation
- Implement cross-region backup replication for multi-region disasters

### C7. Kafka Replication Factor 2 Insufficient for Data Durability
**Component**: Kafka cluster with RF=2 (Section 7)
**Failure Scenario**: Two brokers fail simultaneously (e.g., correlated hardware failure, network partition). With RF=2, partition loses all replicas. Event data in `sensor-events`, `broadcast-events`, `social-events` topics is permanently lost. Flink jobs cannot resume processing; data gap cannot be filled.

**Impact**: Permanent event data loss, violation of SLA, potential regulatory non-compliance.

**Countermeasures**:
- Increase replication factor to 3 (standard for production)
- Configure `min.insync.replicas = 2` to prevent accepting writes when only 1 replica available
- Enable unclean leader election = false to prevent data loss on failover
- Implement broker rack awareness to spread replicas across failure domains

### C8. No Graceful Degradation Strategy for Dependency Failures
**Component**: System-wide (all components depend on PostgreSQL, Kafka, Redis)
**Failure Scenario**: PostgreSQL becomes unreachable. REST API returns 503, but provides no fallback. WebSocket gateway disconnects all clients. Users see blank screens with no explanation. Support tickets flood in.

**Impact**: Complete service outage, poor user experience, reputational damage.

**Countermeasures**:
- Implement fallback responses: serve stale data from Redis cache when DB unavailable
- Design read-only mode: disable writes but allow cached reads
- Add user-facing degradation notices: "Live updates temporarily unavailable"
- Cache critical data (user preferences, subscriptions) in Redis with longer TTL as fallback

---

## Tier 2: Significant Issues (Partial System Impact)

### S1. Missing Retry with Exponential Backoff for Kafka Producer
**Component**: Ingestion Adapters publishing to Kafka (Section 3)
**Failure Scenario**: Kafka broker experiences transient network glitch. Broadcast API Adapter receives webhook, attempts to publish to Kafka, fails immediately. No retry configured; webhook data is silently dropped. Broadcast partner doesn't resend webhooks.

**Impact**: Partial event loss, data gap in event stream, inconsistent user experience.

**Countermeasures**:
- Configure Kafka producer retry with exponential backoff (`retries = 10`, `retry.backoff.ms = 100`)
- Add jitter to prevent thundering herd
- Implement local dead letter queue for events failing after max retries
- Add alerting on DLQ depth

### S2. No Rate Limiting for WebSocket Subscriptions
**Component**: WebSocket Gateway (Section 5)
**Failure Scenario**: Malicious client subscribes to all teams simultaneously, receiving every event. Repeats with 1,000 connections from different IPs. Gateway broadcasts every event to all 1,000 connections, exhausting bandwidth and CPU. Legitimate users experience lag or disconnections.

**Impact**: Resource exhaustion, denial of service for legitimate users, increased infrastructure costs.

**Countermeasures**:
- Implement per-connection subscription limits (e.g., max 10 teams per connection)
- Add rate limiting on subscription requests (e.g., max 5 subscription changes per minute)
- Implement connection-level rate limiting with token bucket (e.g., 100 messages/second per connection)
- Add IP-based connection limits with allowlist for known good actors

### S3. Missing Dead Letter Queue Handling for Flink Jobs
**Component**: Flink Enrichment, Aggregation, Translation jobs (Section 3)
**Failure Scenario**: Malformed event arrives (e.g., invalid JSON in `payload` field). Flink job throws deserialization exception, restarts, re-reads from Kafka, crashes again. Enters crash loop, blocking all downstream event processing.

**Impact**: Pipeline stall, event processing backlog, real-time delivery delays affecting all users.

**Countermeasures**:
- Wrap deserialization in try-catch, route invalid events to dead letter topic `dlq-events`
- Add poison message detection: track failure count per offset, skip after threshold
- Implement schema validation at ingestion boundary to reject malformed events early
- Add monitoring and alerting on DLQ depth

### S4. No Backpressure Mechanism for WebSocket Broadcasting
**Component**: WebSocket Gateway → Client connections (Section 3)
**Failure Scenario**: During high-traffic event (championship game), 50,000 concurrent clients connected. Event rate spikes to 1,000/second. Gateway consumes from Redis Pub/Sub faster than it can broadcast to slow clients (mobile clients on 3G). Memory buffers fill up, gateway OOM kills occur.

**Impact**: Gateway crashes, mass disconnection, poor user experience during peak traffic.

**Countermeasures**:
- Implement per-connection send buffer limits with overflow discard strategy
- Add slow client detection: disconnect clients with sustained send queue depth > threshold
- Use selective broadcasting: rate-limit low-priority events, prioritize critical events
- Implement backpressure signaling: pause Redis Pub/Sub consumption when aggregate send buffer exceeds capacity

### S5. Missing SPOF Analysis for Flink JobManager
**Component**: Apache Flink cluster (Section 2)
**Failure Scenario**: Flink JobManager process crashes (OOM, bug). No high-availability configuration. All stream processing jobs halt. Events accumulate in Kafka, but no processing occurs. Real-time delivery stops.

**Impact**: Real-time feature outage, WebSocket clients receive no updates, metrics not aggregated.

**Countermeasures**:
- Enable Flink HA with ZooKeeper/Kubernetes-based leader election
- Configure JobManager standby instances (3 for quorum)
- Use Flink savepoints for job recovery with exactly-once semantics
- Test failover scenarios: kill JobManager, verify automatic recovery

### S6. No Health Checks for Background Jobs
**Component**: Flink jobs, ingestion adapters (Section 3)
**Failure Scenario**: Flink Translation job enters silent failure state: consumes from Kafka but doesn't process due to uncaught exception in map function. No health check endpoint; Kubernetes considers pod healthy. Translations stop, but no alerts fire.

**Impact**: Partial feature degradation, delayed detection, prolonged user impact.

**Countermeasures**:
- Expose health check endpoints for Flink jobs (e.g., `/health` checking last processed timestamp)
- Configure Kubernetes liveness probe with threshold (e.g., fail if no processing in 60s)
- Add watchdog metrics: track time since last successful event processing
- Alert on processing lag exceeding threshold

### S7. Database Schema Migration Executed Manually Before Deployment
**Component**: Deployment process, Flyway migrations (Section 6)
**Failure Scenario**: Developer deploys new application version with schema change (added column to `events` table). Forgets to run Flyway migration. New pods start, attempt to write to non-existent column, crash. Rollback deployed, but some events were lost during crash loop.

**Impact**: Deployment failure, potential data loss, rollback required.

**Countermeasures**:
- Automate migration execution: run Flyway as Kubernetes init container before app pods start
- Use expand-contract pattern for zero-downtime: add column in migration N, deploy code using column in N+1, remove old code in N+2
- Add pre-deployment validation: check schema version matches expected version
- Test migrations in staging environment with production-like data volume

### S8. No Connection Pool Configuration for Redis
**Component**: WebSocket Gateway, REST API accessing Redis (Sections 3, 5)
**Failure Scenario**: During traffic spike, REST API exhausts default Redis connection pool (often 8 connections). New requests block waiting for available connection. Response times spike to 10s+. Some requests timeout, clients retry, amplifying load.

**Impact**: API latency degradation, cascading retries, poor user experience.

**Countermeasures**:
- Configure Redis connection pool explicitly (e.g., Lettuce `maxTotal = 50`, `maxIdle = 20`)
- Set connection timeout and command timeout (e.g., 2s)
- Add pool exhaustion monitoring and alerting
- Implement circuit breaker on Redis operations to fail fast when pool exhausted

---

## Tier 3: Moderate Issues (Operational Improvement)

### M1. Missing SLO Definitions with Error Budgets
**Component**: System-wide (Section 7 mentions 99.9% uptime but no SLO details)
**Improvement**: Document SLOs for key user journeys (e.g., "99.9% of events delivered within 500ms") with error budgets. Track SLI consumption and use it to prioritize reliability work vs. new features.

**Actionable Steps**:
- Define SLIs: event delivery latency (p50, p95, p99), API error rate, WebSocket connection success rate
- Set SLOs with error budgets (e.g., 99.9% availability = 43.8 min/month budget)
- Implement automated SLO tracking dashboards
- Establish policy: freeze feature work when error budget exhausted

### M2. No Distributed Tracing Implementation
**Component**: Correlation IDs mentioned (Section 6) but no tracing system
**Improvement**: Implement distributed tracing (e.g., OpenTelemetry + Jaeger/Tempo) to debug cross-service latency issues. Enable sampling (e.g., 1% of requests) to minimize overhead.

**Actionable Steps**:
- Integrate OpenTelemetry SDKs in Spring Boot and Flink jobs
- Propagate trace context through Kafka message headers
- Configure tail-based sampling for high-latency traces
- Build tracing dashboards for p95/p99 latency breakdown

### M3. Missing Capacity Planning and Load Testing Details
**Component**: Section 6 mentions Gatling load tests but no capacity validation
**Improvement**: Establish capacity planning process with load testing validating performance targets before scaling events.

**Actionable Steps**:
- Run monthly load tests simulating 2x peak traffic (20,000 events/sec, 100k WebSocket connections)
- Document resource headroom: measure CPU/memory utilization at peak, ensure < 70% capacity
- Build capacity forecasting models based on user growth trends
- Define autoscaling policies for all stateless components

### M4. No Incident Response Runbooks
**Component**: Section 6 mentions chaos experiments but no runbooks
**Improvement**: Create incident runbooks for common failure scenarios to reduce MTTR.

**Actionable Steps**:
- Document runbooks: "WebSocket gateway down", "Kafka broker failure", "Database replication lag spike"
- Include diagnostic commands, escalation procedures, rollback steps
- Test runbooks during game days with simulated incidents
- Maintain runbook repository with version control

### M5. Redis Translation Cache TTL May Cause Inconsistency
**Component**: Translation Job → Redis cache with 5-minute TTL (Section 3)
**Improvement**: Short TTL may cause cache misses during high-traffic events, amplifying OpenAI API calls. Consider longer TTL with cache invalidation on content updates.

**Actionable Steps**:
- Extend TTL to 1 hour for completed events (status=final)
- Implement cache warming: pre-translate known events before broadcast
- Add cache hit rate monitoring and alerting (target > 90%)
- Use cache-aside pattern with fallback to original language on cache miss

### M6. No Resource Quotas Defined for Kubernetes Pods
**Component**: EKS deployment (Section 2, 7)
**Improvement**: Without resource requests/limits, noisy neighbor pods can starve others of CPU/memory, causing unpredictable performance.

**Actionable Steps**:
- Define resource requests/limits for all pods (e.g., WebSocket gateway: 2 CPU request, 4 CPU limit, 4Gi memory)
- Use Vertical Pod Autoscaler for data-driven recommendations
- Implement pod priority classes: critical components get higher priority
- Add resource quota per namespace to prevent runaway resource consumption

### M7. Kafka Consumer Offset Commit After Processing Is Correct but Lacks Details
**Component**: Flink jobs consuming Kafka (Section 6)
**Improvement**: "Commit offset only after successful processing" is correct principle but lacks specifics on commit interval, exactly-once semantics configuration.

**Actionable Steps**:
- Document Flink checkpoint configuration (e.g., interval=60s, timeout=10min)
- Enable exactly-once mode with Kafka transactions
- Configure `isolation.level=read_committed` for consumers
- Test failure recovery: kill job mid-processing, verify no duplicates/data loss

### M8. Missing Multi-Region Disaster Recovery Strategy
**Component**: System-wide (Section 7 mentions Multi-AZ but not multi-region)
**Improvement**: Regional disaster (AWS us-east-1 outage) causes complete unavailability. Multi-region failover would improve disaster resilience.

**Actionable Steps**:
- Design active-passive multi-region architecture
- Replicate critical data (PostgreSQL, Kafka) cross-region with RPO < 5 minutes
- Implement DNS-based failover with health checks
- Schedule quarterly DR drills with regional failover validation

---

## Tier 4: Minor Improvements and Positive Aspects

### Minor Improvement 1: JWT Token Expiry Strategy
**Component**: JWT with 15-minute expiry (Section 7)
**Improvement**: Short expiry is secure but may cause poor UX (frequent re-authentication during live events). Consider refresh token pattern for WebSocket connections.

**Actionable Steps**:
- Implement refresh token with 7-day expiry
- WebSocket gateway validates token on connect, accepts refresh token for re-authentication without disconnect
- Add token refresh endpoint for mobile clients

### Minor Improvement 2: Enhance Structured Logging with Metrics Correlation
**Component**: Structured JSON logs with correlation IDs (Section 6)
**Improvement**: Logs and metrics are mentioned separately. Correlating them improves debugging (e.g., link high error rate spike to specific log patterns).

**Actionable Steps**:
- Add correlation ID to all emitted metrics as tag/label
- Implement exemplar support (Prometheus) to link metrics to trace/logs
- Build unified dashboards showing logs + metrics + traces side-by-side

### Minor Improvement 3: Chaos Engineering Is Mentioned but Needs Formalization
**Component**: Section 6 mentions random pod terminations, network partitions
**Improvement**: Ad-hoc chaos experiments are good start but lack systematic coverage.

**Actionable Steps**:
- Adopt chaos engineering framework (e.g., Chaos Mesh, Litmus)
- Define chaos experiment catalog: CPU stress, memory leak, dependency failure
- Run automated chaos experiments in staging weekly
- Require chaos validation for critical changes before production deployment

---

## Positive Aspects

1. **Multi-AZ deployment** for PostgreSQL, Redis, and EKS provides baseline availability resilience
2. **Kafka offset commit after successful processing** prevents message loss
3. **Correlation IDs propagated through pipeline** enables distributed tracing foundation
4. **Chaos experiments mentioned** shows proactive reliability culture
5. **HPA for WebSocket gateway** provides reactive scaling for traffic spikes
6. **Kafka replication factor configured** (though RF=2 should increase to RF=3)
7. **503 responses with retry-after header** follows HTTP best practices

---

## Summary

This design demonstrates awareness of basic reliability practices (Multi-AZ, replication, correlation IDs) but has **critical gaps** in distributed system resilience patterns. The most severe issues are:

1. **Missing idempotency and transaction guarantees** risking data duplication/inconsistency
2. **No circuit breakers or timeouts** enabling cascading failures
3. **Insufficient failure isolation** (bulkheads, rate limiting) allowing blast radius expansion
4. **Inadequate backup/disaster recovery** procedures risking catastrophic data loss

**Priority Recommendation**: Address all Tier 1 (Critical) issues before production launch. These represent system-wide failure risks that violate the 99.9% availability target. Tier 2 (Significant) issues should follow in next sprint to improve operational resilience.
