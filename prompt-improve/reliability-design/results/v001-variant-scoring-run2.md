# Reliability Evaluation: RealTimeChat システム設計書

## Executive Summary

This reliability evaluation identifies critical gaps in the RealTimeChat system design that pose significant risks to production operations. The design demonstrates basic infrastructure redundancy but lacks comprehensive fault recovery mechanisms, explicit data consistency guarantees, and operational observability. The most critical concerns are the absence of circuit breaker patterns for external dependencies, undefined idempotency for retryable message operations, and insufficient SLO-based monitoring design.

**Overall Reliability Assessment:**
- Fault Recovery Design: Score 2 (Insufficient)
- Data Consistency & Idempotency: Score 2 (Insufficient)
- Availability, Redundancy & Disaster Recovery: Score 3 (Adequate)
- Monitoring & Alerting Design: Score 2 (Insufficient)
- Deployment & Rollback: Score 4 (Good)

---

## Critical Issues (Score 1-2)

### 1. Fault Recovery Design: Insufficient External Dependency Protection

**Score: 2 (Insufficient)** - No retry strategies; timeout handling not specified; system behavior under failure conditions undefined; creates significant recovery complexity

**Issue Description:**

The design lacks explicit fault recovery mechanisms for external dependencies and inter-service communication:

- **No circuit breaker patterns** for external services (FCM, SendGrid) or internal service calls (Auth Service ↔ Message Service)
- **No retry strategies** specified for database operations (PostgreSQL, MongoDB, Redis) or API calls
- **Timeout specifications missing** for WebSocket connections, HTTP requests, and database queries
- **No fallback strategies** when Redis Pub/Sub fails or MongoDB becomes unavailable
- **No backpressure mechanisms** to protect services during traffic spikes beyond basic rate limiting (1000 req/min)
- **Fault isolation boundaries undefined** - a failure in Notification Service could impact Message Service through Redis Pub/Sub

**Impact Analysis:**

Without these mechanisms, the system is vulnerable to cascading failures:

1. **SendGrid outage scenario**: Notification Service threads could block indefinitely, exhausting connection pools and preventing message delivery notifications from being processed
2. **MongoDB slow query**: Message Service could experience thread pool exhaustion, blocking new message writes and WebSocket message distribution
3. **Redis Pub/Sub failure**: All real-time message distribution stops; no fallback mechanism to notify connected clients
4. **Cascading failure risk**: A slow downstream service (e.g., DocumentDB high latency) could cause API Gateway timeouts, affecting all requests including authentication

The design states "API Gateway が JWT トークンを検証" but does not specify timeout or fallback behavior if Auth Service is slow or unavailable.

**Recommended Countermeasures:**

1. **Implement circuit breaker pattern** for all external dependencies:
   - External services: FCM, SendGrid (open circuit after 5 consecutive failures, half-open retry after 30s)
   - Internal services: Auth Service, Message Service, Notification Service
   - Databases: PostgreSQL, MongoDB, Redis (with connection pool timeout: 5s, query timeout: 10s)

2. **Define retry strategies with exponential backoff**:
   - Idempotent operations (GET, DELETE): 3 retries with exponential backoff (100ms, 200ms, 400ms)
   - Non-idempotent operations (POST message): Require idempotency key (see Issue #2)
   - Database writes: Single retry for transient failures (connection reset, timeout)

3. **Specify timeout values**:
   - API Gateway → Service calls: 10s timeout
   - WebSocket idle timeout: 5 minutes with ping/pong keepalive
   - Database query timeout: 10s for writes, 5s for reads
   - External service calls: 15s for FCM/SendGrid

4. **Design fallback strategies**:
   - Redis Pub/Sub failure: Fall back to direct WebSocket connection registry in Message Service memory (with coordination via PostgreSQL for multi-instance deployments)
   - MongoDB unavailable: Return cached recent messages from Redis; reject new message writes with 503 Service Unavailable
   - SendGrid failure: Queue notifications in Redis list; retry with exponential backoff (max 24h retention)

5. **Implement bulkhead pattern** to isolate Notification Service failures from Message Service core functionality

**Reference:** Section 3 (アーキテクチャ設計) and Section 6 (実装方針 - エラーハンドリング方針)

---

### 2. Data Consistency & Idempotency: Risk of Duplicate Messages and Inconsistent State

**Score: 2 (Insufficient)** - No explicit consistency guarantees; retryable operations lack idempotency design; risk of duplicate data or inconsistent state

**Issue Description:**

The design does not address data consistency guarantees or idempotency mechanisms:

- **No idempotency design** for message POST operations - client retries or API Gateway retries could create duplicate messages in MongoDB
- **No duplicate detection** mechanism for message_id generation or validation
- **Consistency model undefined** between PostgreSQL metadata (channels, users) and MongoDB messages
- **No transaction boundaries** specified for multi-step operations (e.g., message write + Redis Pub/Sub publish)
- **Message editing/deletion consistency** not addressed - `PUT /api/v1/messages/{message_id}` and `DELETE` operations could race with concurrent reads or reactions
- **Reactions array** in MongoDB uses in-place updates (`user_ids: [String]`) without concurrency control - risk of lost updates

**Impact Analysis:**

These gaps create multiple failure scenarios:

1. **Duplicate message scenario**: Client sends message → network timeout → client retries → two identical messages appear in channel
2. **Lost notification scenario**: Message written to MongoDB succeeds → Redis Pub/Sub publish fails → some users never receive real-time notification
3. **Reaction race condition**: Two users simultaneously add reactions → one reaction update overwrites the other due to MongoDB document-level locking
4. **Inconsistent deletion**: Message deleted from MongoDB → WebSocket notification fails → connected clients still display deleted message until page refresh
5. **Orphaned messages**: Channel deleted from PostgreSQL → messages remain in MongoDB → search returns messages from non-existent channels

**Recommended Countermeasures:**

1. **Implement idempotency for message POST**:
   - Add `idempotency_key` field to request body (client-generated UUID)
   - Store `idempotency_key` in MongoDB messages collection with TTL index (24h expiration)
   - On duplicate `idempotency_key`, return existing message (200 OK) instead of creating new message
   - API Gateway should generate idempotency key for retries if client doesn't provide one

2. **Define explicit consistency model**:
   - **Strong consistency** for authentication operations (PostgreSQL synchronous replication)
   - **Eventual consistency** for message delivery (MongoDB → Redis Pub/Sub → WebSocket clients)
   - Document expected propagation delay (target: <200ms)

3. **Implement transactional outbox pattern** for message write + notification:
   - Write message to MongoDB with `notification_status: pending`
   - Publish to Redis Pub/Sub
   - On success, update `notification_status: delivered`
   - Background job retries pending notifications after 5s

4. **Use atomic operations for reactions**:
   - Replace array with `reactions` sub-document: `{reaction_id: {emoji: "👍", user_ids: [...]}}`
   - Use MongoDB `$addToSet` operator for concurrent-safe user_id additions
   - Use `$pull` operator for removals

5. **Implement soft delete with tombstone records**:
   - Add `deleted_at` field to messages instead of hard delete
   - WebSocket broadcasts include `message_deleted` event type
   - Background job purges soft-deleted messages after 30 days

6. **Add referential integrity check**:
   - Before message write, verify channel_id exists in PostgreSQL (with Redis cache, 5-minute TTL)
   - Return 404 if channel not found or user lacks access

**Reference:** Section 4 (データモデル - messages コレクション), Section 5 (API設計 - メッセージ関連), Section 3 (データフロー - メッセージ送信フロー)

---

### 3. Monitoring & Alerting Design: Insufficient Observability for Production Operations

**Score: 2 (Insufficient)** - Minimal observability design; no SLO definitions; alerting strategy absent; difficult to detect degraded performance

**Issue Description:**

The design lacks comprehensive monitoring and alerting mechanisms:

- **No SLO/SLA definitions** with quantified targets (e.g., "メッセージ送信から配信まで平均 200ms 以内" is a goal but not an SLO with error budget)
- **No RED metrics collection design** (Request rate, Error rate, Duration) for each service
- **No alert thresholds or escalation policies** - only mentions "CloudWatch Logs に集約"
- **Health check endpoints not defined** for ECS Fargate tasks - Blue/Green deployment mentions health checks but no implementation details
- **No SLO-based alerting** - no error budget burn rate alerts or latency percentile violations
- **WebSocket connection monitoring missing** - no metrics for active connections, connection churn rate, or message delivery failures
- **Database performance metrics undefined** - no alerting on PostgreSQL replication lag, MongoDB replica set health, or Redis memory usage

**Impact Analysis:**

Without explicit monitoring design, operational issues will be detected late or not at all:

1. **Silent degradation**: Message latency increases from 200ms to 2s due to MongoDB slow queries, but no alerts fire until users complain
2. **Undetected partial failures**: 10% of WebSocket clients fail to receive messages due to Redis Pub/Sub issues, but aggregated metrics appear normal
3. **Extended MTTR**: When Message Service crashes, operators must manually inspect CloudWatch Logs to diagnose root cause instead of receiving targeted alerts
4. **Capacity planning blindness**: No visibility into connection growth rate → sudden traffic spike exhausts ECS task limits
5. **False positives during deployment**: Blue/Green deployment health checks may pass even if new version has elevated error rates

**Recommended Countermeasures:**

1. **Define explicit SLOs with error budgets**:
   - **Message delivery SLO**: 99.9% of messages delivered within 500ms (error budget: 43 minutes/month)
   - **API availability SLO**: 99.5% of API requests succeed (error budget: 3.6 hours/month of 5xx errors)
   - **WebSocket uptime SLO**: 99.9% of established WebSocket connections remain stable for session duration

2. **Design RED metrics collection** for each service:
   - **Request rate**: Messages sent/min, API requests/sec by endpoint
   - **Error rate**: 5xx errors/min, WebSocket disconnection rate, database operation failures
   - **Duration**: p50/p95/p99 latency for message POST, message history GET, WebSocket message delivery

3. **Specify alert thresholds and escalation**:
   - **Critical alerts** (PagerDuty, immediate escalation):
     - Error rate > 5% for 5 minutes (SLO burn rate: 100x)
     - Message delivery latency p95 > 2s for 5 minutes
     - Database connection pool exhausted
   - **Warning alerts** (Slack, 15-minute aggregation):
     - Error rate > 1% for 15 minutes (SLO burn rate: 10x)
     - CPU utilization > 80% for 10 minutes
     - Redis memory usage > 85%

4. **Define health check endpoints**:
   - `GET /health/liveness`: Returns 200 if service process is running (used by ECS for task restart)
   - `GET /health/readiness`: Returns 200 if service can handle traffic (checks database connectivity, Redis availability)
   - Health check implementation:
     - PostgreSQL: `SELECT 1` with 2s timeout
     - MongoDB: Ping with 2s timeout
     - Redis: `PING` command with 1s timeout
   - Blue/Green deployment criteria: 3 consecutive successful readiness checks at 10s intervals

5. **Implement WebSocket-specific metrics**:
   - Active connection count by channel
   - Connection establishment rate and failure rate
   - Message delivery success rate (ack-based confirmation)
   - Connection duration histogram

6. **Add database performance dashboards**:
   - PostgreSQL: Replication lag, connection count, slow query count (>1s)
   - MongoDB: Replica set status, oplog window, index usage
   - Redis: Memory fragmentation ratio, evicted keys, keyspace hit rate

**Reference:** Section 6 (ロギング方針), Section 7 (非機能要件 - パフォーマンス目標), Section 6 (デプロイメント方針)

---

## Significant Issues (Score 3)

### 4. Availability, Redundancy & Disaster Recovery: Regional Single Point of Failure

**Score: 3 (Adequate)** - Some SPOF mitigation; redundancy implied for critical components; backup mentioned without detailed strategy; RPO/RTO not quantified for application-level failures

**Issue Description:**

The design includes basic redundancy mechanisms but has gaps in comprehensive disaster recovery:

**Strengths:**
- RDS Multi-AZ configuration provides automatic failover for PostgreSQL
- ElastiCache cluster mode enables Redis node redundancy
- ECS Auto Scaling addresses compute layer availability
- Daily database backups with 30-day retention
- Cross-region snapshot synchronization with documented RPO (24h) and RTO (12h)

**Gaps:**
- **Single-region deployment** - all services run in one AWS region; regional outage causes complete service unavailability
- **No failover design for MongoDB/DocumentDB** - configuration (single-node vs. replica set) not specified
- **No graceful degradation strategies** - system appears to be all-or-nothing (either fully operational or unavailable)
- **Dependency failure impact not analyzed** - what happens when CloudFront CDN fails, S3 becomes unavailable, or ALB reaches connection limits?
- **No documented failover procedures** for message service or WebSocket connection re-establishment
- **Backup restoration process not documented** - RTO of 12 hours is stated but restoration steps and validation procedures are missing

**Impact Analysis:**

1. **Regional outage**: AWS us-east-1 availability zone failure affects RDS Multi-AZ, but if entire region fails, service is completely unavailable for 12+ hours
2. **S3 file access failure**: Attachments become inaccessible; no fallback to display "file temporarily unavailable" vs. permanent error
3. **DocumentDB single-node failure**: If DocumentDB is not configured as replica set, message history becomes unavailable with no fallback to cached data
4. **ALB connection limit**: During traffic spike, ALB may reject new connections; no queue-based backpressure or graceful rejection message

**Recommended Countermeasures:**

1. **Document MongoDB/DocumentDB high-availability configuration**:
   - Specify replica set with 3 nodes across 3 availability zones
   - Define read preference (primary preferred for consistency, secondary for read-heavy queries)
   - Document automatic failover behavior and expected failover time (<30s)

2. **Design graceful degradation paths**:
   - **Message history unavailable**: Allow new message posting; display "History temporarily unavailable" banner
   - **Notification Service down**: Message delivery continues; notifications queued for retry
   - **Search unavailable**: Disable search UI element; core messaging remains functional
   - **File upload disabled**: Reject uploads with 503; allow text-only messages

3. **Analyze and document dependency failure impact**:
   - **CloudFront failure**: Direct ALB access as fallback (slower but functional)
   - **S3 unavailable**: Reject file uploads; existing files show "Temporarily unavailable"
   - **Redis cluster down**: Degrade to polling-based message retrieval; disable real-time delivery
   - **PostgreSQL read replica lag**: Switch to primary for reads; accept higher load on primary

4. **Implement multi-region failover design (future enhancement)**:
   - Active-passive setup with standby region (us-west-2)
   - Route53 health check-based DNS failover
   - Database replication: PostgreSQL logical replication, MongoDB replica set across regions
   - Target RTO: 5 minutes, RPO: 5 minutes for regional failover

5. **Document disaster recovery runbook**:
   - Backup restoration procedure with step-by-step commands
   - Validation checklist (user login, message send/receive, file access)
   - Rollback procedure if restoration fails
   - Communication plan for user notifications during recovery

**Reference:** Section 7 (可用性・スケーラビリティ), Section 2 (インフラ・デプロイ環境), Section 3 (全体構成)

---

## Positive Aspects (Score 4)

### 5. Deployment & Rollback: Well-Designed Blue/Green Strategy

**Score: 4 (Good)** - Deployment strategy supports gradual rollout; rollback plan documented; migrations designed for compatibility; minor gaps in automation or safety checks

**Strengths:**

The design demonstrates good deployment safety practices:

1. **Blue/Green deployment** for ECS tasks minimizes downtime
2. **Health check verification** before routing traffic to new version
3. **Backward-compatible migrations** implied by gradual rollout approach
4. **Clear rollback mechanism** (stop new tasks, route traffic back to old tasks)

**Minor Gaps:**

1. **No automated rollback triggers** - relies on manual detection of deployment issues
2. **Database migration strategy not detailed** - schema changes could break backward compatibility
3. **No canary deployment phase** - traffic shifts 100% to new version after health checks pass (no gradual 5% → 50% → 100% rollout)
4. **No feature flags mentioned** - cannot disable problematic features without full rollback
5. **No smoke tests or synthetic monitoring** after deployment to validate critical paths

**Recommended Improvements:**

1. **Implement automated rollback triggers**:
   - If error rate > 5% within 10 minutes of deployment, trigger automatic rollback
   - If p95 latency > 2x baseline for 5 minutes, trigger automatic rollback
   - If health check failures > 20%, stop deployment and maintain old version

2. **Document database migration strategy**:
   - **Expand-contract pattern**: Add new columns/indexes before code deployment; remove old columns in subsequent deployment
   - **Dual-write phase**: Write to both old and new schemas during transition period
   - **Migration rollback plan**: Each migration includes `down` script for reversal

3. **Add canary deployment phase**:
   - Deploy to 5% of ECS tasks first; monitor for 15 minutes
   - If metrics are stable, expand to 50%; monitor for 10 minutes
   - If metrics remain stable, complete rollout to 100%

4. **Integrate feature flags**:
   - Use LaunchDarkly or AWS AppConfig for runtime feature toggles
   - Wrap new features in flags: new message reaction UI, experimental search algorithm
   - Allow instant disabling of problematic features without redeployment

5. **Add post-deployment validation**:
   - Synthetic monitoring: Automated test user sends message and verifies delivery within 30s
   - Critical path smoke tests: Login → send message → receive notification → verify file upload
   - Alert if smoke tests fail within 5 minutes of deployment completion

**Reference:** Section 6 (デプロイメント方針), Section 7 (非機能要件 - 可用性・スケーラビリティ)

---

## Summary of Reliability Risks

| Criterion | Score | Key Risk | Priority |
|-----------|-------|----------|----------|
| Fault Recovery Design | 2 | No circuit breakers, retries, or timeouts for external dependencies; cascading failure risk | **Critical** |
| Data Consistency & Idempotency | 2 | Duplicate messages possible; no idempotency design; reaction race conditions | **Critical** |
| Monitoring & Alerting Design | 2 | No SLO-based alerts; insufficient observability; extended MTTR | **Critical** |
| Availability, Redundancy & DR | 3 | Single-region SPOF; no graceful degradation; DocumentDB HA unclear | **Significant** |
| Deployment & Rollback | 4 | Good Blue/Green strategy; minor gaps in automation and canary phases | **Minor** |

---

## Recommended Prioritization

To improve the reliability posture of this system before production launch, address issues in the following order:

1. **Phase 1 (Pre-Beta Critical)**:
   - Implement circuit breakers for external services (SendGrid, FCM)
   - Add idempotency keys for message POST operations
   - Define and implement health check endpoints for ECS deployments
   - Document MongoDB replica set configuration

2. **Phase 2 (Beta Launch)**:
   - Define SLOs and configure SLO-based alerting
   - Implement retry strategies with exponential backoff
   - Design graceful degradation for message history unavailability
   - Add automated rollback triggers for deployments

3. **Phase 3 (Production Hardening)**:
   - Implement transactional outbox pattern for message delivery
   - Add comprehensive RED metrics collection
   - Document disaster recovery runbook with restoration procedures
   - Design multi-region failover strategy (roadmap item)

The current design is **not production-ready** without addressing Phase 1 critical issues. The lack of fault recovery and idempotency mechanisms poses unacceptable risk of data duplication, cascading failures, and extended outages during dependency failures.
