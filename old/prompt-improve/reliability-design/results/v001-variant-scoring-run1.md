# Reliability Design Review: RealTimeChat システム設計書

## Executive Summary

This reliability evaluation identifies **5 critical issues**, **4 significant issues**, and **3 moderate issues** across five evaluation dimensions. The design demonstrates baseline awareness of availability concerns (Multi-AZ RDS, auto-scaling) but lacks explicit fault recovery mechanisms, consistency guarantees, and operational observability design. Without circuit breakers, idempotency, or SLO definitions, the system faces high risk of cascading failures and extended recovery times.

---

## Critical Issues (Score 1-2)

### C-1: No Fault Recovery Mechanisms for External Dependencies [Score: 1]

**Evaluation Criterion:** Fault Recovery Design

**Issue Description:**
The design does not specify any fault recovery mechanisms (circuit breakers, retry strategies, timeout specifications, fallback strategies, or backpressure mechanisms) for external dependencies including:
- DocumentDB (MongoDB)
- ElastiCache (Redis)
- RDS (PostgreSQL)
- S3 file storage
- External notification services (FCM, SendGrid)

**Impact Analysis:**
- **Cascading Failures:** When DocumentDB experiences latency spikes during message storage (Section 3, step 3), API Gateway threads will block indefinitely, exhausting connection pools and causing complete service unavailability.
- **Resource Exhaustion:** Without timeout specifications, slow Redis Pub/Sub operations (Section 3, step 4) will accumulate goroutines, leading to memory exhaustion and OOM kills.
- **Notification Service Breakdown:** If SendGrid API becomes unavailable, Notification Service will retry indefinitely without exponential backoff, potentially causing rate limit bans and permanent service degradation.

**Recommended Countermeasures:**
1. **Circuit Breakers:** Implement circuit breaker pattern (e.g., `gobreaker` library) for all external service calls:
   - MongoDB message storage: open circuit after 5 consecutive failures
   - Redis Pub/Sub: open circuit on 50% error rate over 10s window
   - FCM/SendGrid: open circuit after 3 consecutive timeouts
2. **Retry Strategies:** Define exponential backoff with jitter:
   - Database operations: 3 retries with 100ms base delay, 2x multiplier, 5s max delay
   - Notification services: 5 retries with 200ms base delay, 1.5x multiplier
3. **Timeout Specifications:**
   - MongoDB write operations: 2s timeout
   - Redis operations: 500ms timeout
   - External notification APIs: 10s timeout
4. **Fallback Strategies:**
   - Message Service: return 503 with retry-after header when circuit is open
   - Notification Service: queue notifications to SQS when external services are unavailable

**References:** Section 3 (Architecture), Section 6 (Error Handling lacks fault recovery)

---

### C-2: No Idempotency Design for Retryable Operations [Score: 1]

**Evaluation Criterion:** Data Consistency & Idempotency

**Issue Description:**
The design lacks idempotency mechanisms for retryable operations, particularly:
- Message creation API (`POST /api/v1/messages`, Section 5)
- Message editing (`PUT /api/v1/messages/{message_id}`)
- Notification delivery (Section 3, step 6)
- Redis Pub/Sub message publishing (Section 3, step 4)

**Impact Analysis:**
- **Duplicate Messages:** Network retries from clients will create multiple message records in MongoDB (Section 4, messages collection), causing user confusion and data integrity issues.
- **Inconsistent State:** If MongoDB write succeeds but Redis Pub/Sub publish fails (Section 3, steps 3-4), retry attempts will create duplicate database records while only some clients receive updates.
- **Notification Spam:** Retry logic in Notification Service without deduplication will send multiple push notifications/emails for the same event.

**Recommended Countermeasures:**
1. **Idempotency Keys:** Require clients to provide `X-Idempotency-Key` header for POST/PUT operations:
   - Store processed keys in Redis with 24h TTL
   - Return cached response for duplicate requests
2. **Database Constraints:** Add unique composite index on `messages` collection:
   ```javascript
   db.messages.createIndex(
     { channel_id: 1, client_message_id: 1 },
     { unique: true }
   )
   ```
3. **Distributed Deduplication:** Implement deduplication layer for Redis Pub/Sub:
   - Include message UUID in published payload
   - Track processed UUIDs in Redis with 60s sliding window
4. **Notification Deduplication:** Store notification fingerprint (hash of user_id + event_type + timestamp) in Redis before sending to FCM/SendGrid.

**References:** Section 5 (API Design), Section 3 (Message Send Flow)

---

### C-3: No Monitoring Design or SLO Definitions [Score: 1]

**Evaluation Criterion:** Monitoring & Alerting Design

**Issue Description:**
The design mentions "CloudWatch Logs" for log aggregation (Section 6) but provides no:
- SLO/SLA definitions for availability, latency, or error rates
- Metrics collection design (RED metrics: request rate, error rate, duration)
- Alert thresholds or escalation policies
- Health check endpoint specifications

**Impact Analysis:**
- **Blind Spot During Failures:** Without RED metrics, operators cannot detect degraded performance (e.g., message delivery latency exceeding 200ms target from Section 7) until users report issues.
- **Extended MTTR:** Lack of alert routing means reliability incidents may not reach on-call engineers, violating the 99.5% availability target (Section 7, 3.6h monthly downtime budget).
- **SLO Violations Undetected:** The system cannot measure whether p95 API latency remains under 500ms (Section 7), leading to unnoticed degradation.

**Recommended Countermeasures:**
1. **Define SLOs:**
   - Availability: 99.5% success rate (measured as non-5xx responses / total requests)
   - Latency: p95 API response time < 500ms, p99 < 1s
   - Message Delivery: p95 end-to-end latency < 200ms
2. **Implement RED Metrics Collection:**
   - Request Rate: Track requests/sec per endpoint via middleware
   - Error Rate: Count 5xx responses and client-side errors
   - Duration: Histogram of request latency (p50/p95/p99)
   - Export metrics to CloudWatch Metrics with 1-minute resolution
3. **Alert Strategy:**
   - **Critical:** Error rate > 5% for 5 minutes → page on-call (PagerDuty)
   - **Warning:** p95 latency > 500ms for 10 minutes → Slack notification
   - **Info:** Message delivery p95 > 200ms for 15 minutes → ticket creation
4. **Health Check Endpoints:**
   - `GET /health/liveness`: Return 200 if service is running
   - `GET /health/readiness`: Return 200 only if MongoDB, Redis, and PostgreSQL connections are healthy (500ms timeout per check)

**References:** Section 6 (Logging Policy), Section 7 (Performance Goals)

---

### C-4: Undefined Consistency Guarantees for Distributed Operations [Score: 2]

**Evaluation Criterion:** Data Consistency & Idempotency

**Issue Description:**
The design does not specify consistency models for distributed operations across PostgreSQL, MongoDB, and Redis:
- Channel creation (PostgreSQL) and initial message broadcast (MongoDB + Redis Pub/Sub)
- User deletion propagation across users table (PostgreSQL) and message history (MongoDB)
- Team ownership transfer (PostgreSQL teams table) and access control enforcement

**Impact Analysis:**
- **Orphaned Data:** If channel creation succeeds in PostgreSQL but the service crashes before creating the first system message in MongoDB, clients will see an empty channel that cannot receive messages due to missing collection initialization.
- **Access Control Bypass:** Without eventual consistency guarantees, a user removed from a team (PostgreSQL) may still receive real-time messages via active WebSocket connections using stale Redis session data.
- **Data Integrity Violations:** Deleting a user without cascading to MongoDB messages leaves `user_id` references pointing to non-existent users.

**Recommended Countermeasures:**
1. **Define Explicit Consistency Model:**
   - Choose eventual consistency for cross-database operations with compensation mechanisms
   - Document consistency guarantees per operation in API specifications
2. **Implement Saga Pattern for Multi-DB Transactions:**
   - Channel creation: PostgreSQL → MongoDB (create channel document) → Redis (publish channel_created event)
   - Include compensating transactions: if MongoDB fails, delete PostgreSQL record
3. **Event Sourcing for Critical State Changes:**
   - Publish user/team/channel lifecycle events to SQS
   - Implement eventual consistency workers that ensure MongoDB reflects PostgreSQL state
4. **Consistent Reads:**
   - Add `version` field to PostgreSQL entities
   - Cache version in Redis and validate before applying state changes
   - Force WebSocket reconnection when user permissions change

**References:** Section 4 (Data Model), Section 3 (Data Flow)

---

### C-5: No Rollback Plan for Failed Deployments [Score: 2]

**Evaluation Criterion:** Deployment & Rollback

**Issue Description:**
The design specifies Blue/Green deployment (Section 6) but lacks:
- Automated rollback triggers
- Rollback execution procedures
- Database migration backward compatibility strategy
- Feature flag design for staged rollouts

**Impact Analysis:**
- **Extended Outage:** If a new deployment introduces a critical bug (e.g., MongoDB query syntax error causing 100% error rate), manual rollback procedures will take 15-30 minutes, exhausting the monthly 3.6-hour downtime budget (Section 7).
- **Irreversible Migrations:** Adding a non-nullable column to the `messages` collection without backward-compatible schema evolution will prevent rollback to the previous version.
- **All-or-Nothing Risk:** Without feature flags, every deployment exposes 100% of users to potential defects, violating the staged rollout principle.

**Recommended Countermeasures:**
1. **Automated Rollback Triggers:**
   - Deploy monitoring: if error rate > 10% or p95 latency > 2s within 5 minutes post-deployment, trigger automatic rollback
   - Health check failures: if new tasks fail readiness checks 3 consecutive times, abort deployment
2. **Rollback Procedure:**
   - Document one-command rollback: `aws ecs update-service --task-definition previous-revision`
   - Test rollback in staging environment before production deployment
3. **Backward-Compatible Migrations:**
   - **Expand-Contract Pattern:**
     - Phase 1: Add new nullable fields, deploy application supporting both old and new schema
     - Phase 2: Backfill data and enforce constraints
     - Phase 3: Remove old fields after confirming new fields are stable
   - Example: Migrating `messages.content` to `messages.content_v2`:
     - Week 1: Add `content_v2` as nullable field
     - Week 2: Write to both fields, read from `content_v2` if present
     - Week 3: Backfill `content_v2` from `content`
     - Week 4: Remove `content` field
4. **Feature Flags:**
   - Implement feature flag service (e.g., LaunchDarkly, internal Redis-based solution)
   - Wrap new features: `if featureFlags.Enabled("thread-reactions") { ... }`
   - Enable staged rollouts: 5% → 25% → 50% → 100% over 4 hours

**References:** Section 6 (Deployment Policy), Section 7 (Availability Goal)

---

## Significant Issues (Score 2-3)

### S-1: Single Points of Failure in Data Plane [Score: 2]

**Evaluation Criterion:** Availability, Redundancy & Disaster Recovery

**Issue Description:**
While RDS Multi-AZ (Section 7) addresses database availability, the design does not specify redundancy for:
- API Gateway Service: single ECS task configuration not mentioned
- Message Service: WebSocket connection affinity and failover behavior undefined
- Redis Pub/Sub: cluster mode mentioned but failover impact on active subscriptions not addressed

**Impact Analysis:**
- **WebSocket Connection Loss:** If a Message Service task is terminated during deployment, all 50,000 connected clients (Section 7 capacity goal) must reconnect, causing a thundering herd and potentially overwhelming the remaining tasks.
- **Redis Failover Gap:** ElastiCache cluster failover takes 30-60 seconds; during this window, real-time message delivery via Pub/Sub will fail without fallback to polling-based updates.

**Recommended Countermeasures:**
1. **API Gateway Redundancy:**
   - Deploy minimum 3 ECS tasks across 3 availability zones
   - Configure ALB health checks with 10s interval, 2 unhealthy threshold
2. **WebSocket Graceful Degradation:**
   - Implement connection draining: when task receives SIGTERM, send `connection_migration` message to clients
   - Clients reconnect to different task with exponential backoff
3. **Redis Failover Handling:**
   - Detect Redis unavailability via connection errors
   - Fallback to polling: clients switch to `GET /api/v1/channels/{id}/messages?since={timestamp}` with 5s interval
   - Resume Pub/Sub when Redis connection is restored

**References:** Section 3 (Architecture), Section 7 (Capacity Goals)

---

### S-2: No Backpressure Mechanism for WebSocket Broadcast [Score: 2]

**Evaluation Criterion:** Fault Recovery Design

**Issue Description:**
The message broadcast flow (Section 3, step 5) does not specify backpressure handling when WebSocket write buffers are full due to slow clients or network congestion.

**Impact Analysis:**
- **Memory Exhaustion:** A single slow client (e.g., on poor mobile network) will cause buffered messages to accumulate in server memory, potentially consuming GBs of RAM and triggering OOM kills.
- **Good Client Starvation:** Without prioritization, slow clients can block goroutines responsible for broadcasting to healthy clients, degrading overall system throughput.

**Recommended Countermeasures:**
1. **Per-Connection Write Timeout:**
   - Set 5s write deadline: `conn.SetWriteDeadline(time.Now().Add(5 * time.Second))`
   - Close connection if write times out
2. **Buffered Channel with Discard Policy:**
   - Use buffered channel with 100 message capacity per WebSocket connection
   - When buffer is full, discard oldest messages and send `messages_dropped` event to client
3. **Rate Limiting per Connection:**
   - Track messages sent per connection: max 100 messages/sec
   - Clients exceeding limit are disconnected and must reconnect

**References:** Section 3 (Message Send Flow)

---

### S-3: Implicit Timeout Values Create Unpredictable Failure Behavior [Score: 3]

**Evaluation Criterion:** Fault Recovery Design

**Issue Description:**
While the design mentions "timeout specifications" should exist, no explicit timeout values are documented for:
- HTTP client timeouts when calling external services (FCM, SendGrid)
- Database query timeouts
- WebSocket ping/pong intervals and connection timeout

**Impact Analysis:**
- **Stuck Requests:** Default Go HTTP client timeout is infinite; if SendGrid API hangs, Notification Service goroutines will leak indefinitely.
- **Slow Query Accumulation:** Without MongoDB query timeouts, a full-table scan bug will hold connections open until manual intervention.

**Recommended Countermeasures:**
1. **HTTP Client Configuration:**
   ```go
   httpClient := &http.Client{
       Timeout: 10 * time.Second,
       Transport: &http.Transport{
           MaxIdleConns:        100,
           IdleConnTimeout:     90 * time.Second,
           TLSHandshakeTimeout: 3 * time.Second,
       },
   }
   ```
2. **Database Timeouts:**
   - MongoDB: `context.WithTimeout(ctx, 2*time.Second)` for all operations
   - PostgreSQL: `SET statement_timeout = 5000` (5s) in connection string
3. **WebSocket Keepalive:**
   - Ping interval: 30s
   - Pong timeout: 60s
   - Close connection if pong not received

**References:** Section 3 (Data Flow), Section 6 (Error Handling)

---

### S-4: Disaster Recovery RPO/RTO Misalignment with Business Goals [Score: 3]

**Evaluation Criterion:** Availability, Redundancy & Disaster Recovery

**Issue Description:**
The design specifies RPO=24h and RTO=12h for disaster recovery (Section 7), but this conflicts with:
- 99.5% availability target (implies max 3.6h monthly downtime)
- Real-time messaging use case (enterprise teams expect <1h recovery for critical communication)

**Impact Analysis:**
- **Business Continuity Risk:** A regional outage lasting 12 hours violates the monthly downtime budget by 3.3x.
- **Data Loss Exposure:** 24-hour RPO means up to 24 hours of messages could be lost, which is unacceptable for compliance-sensitive industries (finance, healthcare).

**Recommended Countermeasures:**
1. **Revise RPO/RTO Targets:**
   - RTO: 2 hours (manual failover to standby region)
   - RPO: 1 hour (acceptable for chat history, with trade-off documentation)
2. **Implement Multi-Region Active-Passive:**
   - Primary region: us-east-1 (active)
   - Standby region: us-west-2 (passive, receiving continuous replication)
   - Use DMS for PostgreSQL replication and MongoDB change streams for DocumentDB replication
3. **Automated DR Testing:**
   - Monthly DR drill: failover to standby region and validate functionality
   - Document runbook with step-by-step failover procedures

**References:** Section 7 (Disaster Recovery)

---

## Moderate Issues (Score 3-4)

### M-1: No Alert Routing and Escalation Policy [Score: 3]

**Evaluation Criterion:** Monitoring & Alerting Design

**Issue Description:**
The logging strategy (Section 6) mentions CloudWatch Logs but does not define:
- Who receives alerts (on-call rotation, team channels)
- Escalation paths (L1 → L2 → L3 support)
- Severity-based routing (critical → page, warning → Slack)

**Impact Analysis:**
- **Delayed Incident Response:** Alerts may be sent to unmonitored channels, increasing MTTR from minutes to hours.

**Recommended Countermeasures:**
1. **Define Alert Routing:**
   - Critical (error rate > 5%): PagerDuty → on-call engineer
   - Warning (latency > 500ms): Slack #platform-alerts
   - Info (disk usage > 80%): Jira ticket
2. **Escalation Policy:**
   - Primary on-call: 5-minute response SLA
   - If no acknowledgment: escalate to secondary on-call after 10 minutes
   - If unresolved after 30 minutes: escalate to engineering manager

**References:** Section 6 (Logging Policy)

---

### M-2: No Circuit Breaker for S3 File Uploads [Score: 3]

**Evaluation Criterion:** Fault Recovery Design

**Issue Description:**
File attachment uploads to S3 (Section 4, messages collection) lack failure handling. If S3 API is degraded, upload requests will hang.

**Impact Analysis:**
- **User Experience Degradation:** File uploads will time out after default SDK timeout (unclear duration), blocking user workflows.

**Recommended Countermeasures:**
1. Implement circuit breaker for S3 uploads with fallback: reject new uploads with 503 when circuit is open
2. Store upload status in Redis: clients can poll for completion
3. Set explicit S3 client timeout: 30s for PutObject operations

**References:** Section 4 (MongoDB Schema)

---

### M-3: Insufficient Load Balancer Health Check Configuration [Score: 3]

**Evaluation Criterion:** Availability, Redundancy & Disaster Recovery

**Issue Description:**
The design mentions ALB and ECS health checks (Section 3, Section 6) but does not specify:
- Health check endpoint path and response format
- Health check interval and timeout
- Unhealthy threshold before removing task from load balancer

**Impact Analysis:**
- **Premature Traffic Routing:** If health check interval is too short (e.g., 5s), slow application startup may cause healthy tasks to be marked unhealthy.
- **Stuck Unhealthy Tasks:** Without proper health check, tasks with exhausted database connection pools may continue receiving traffic.

**Recommended Countermeasures:**
1. **Define Health Check Endpoint:**
   - Path: `GET /health/readiness`
   - Response: `{"status": "healthy", "dependencies": {"mongodb": "ok", "redis": "ok", "postgres": "ok"}}`
   - Return 200 only if all dependencies are reachable
2. **ALB Health Check Configuration:**
   - Interval: 15s
   - Timeout: 5s
   - Healthy threshold: 2 consecutive successes
   - Unhealthy threshold: 3 consecutive failures
3. **Dependency Check Timeouts:**
   - Each dependency check should have 1s timeout
   - If any dependency is unreachable, return 503

**References:** Section 3 (Architecture), Section 6 (Deployment)

---

## Positive Aspects

1. **Multi-AZ RDS Configuration:** PostgreSQL Multi-AZ setup (Section 7) provides automatic failover for primary database with minimal downtime (typically <60s).
2. **Auto-Scaling Design:** ECS Auto Scaling based on CPU 70% threshold (Section 7) will handle traffic spikes, though memory-based scaling should also be considered for WebSocket-heavy workloads.
3. **Structured Logging:** JSON-formatted logs with request IDs (Section 6) enable effective distributed tracing across services.
4. **Database Backup Strategy:** 30-day retention for daily backups (Section 7) meets compliance requirements for most industries.

---

## Summary and Priority Recommendations

**Critical Path to Production Readiness:**

1. **Immediate (Pre-Beta):**
   - Implement circuit breakers for all external dependencies (C-1)
   - Add idempotency keys to message creation API (C-2)
   - Define SLOs and implement RED metrics collection (C-3)

2. **Before General Availability:**
   - Document consistency guarantees and implement saga pattern (C-4)
   - Create automated rollback procedures and feature flag framework (C-5)
   - Revise DR strategy to align RPO/RTO with availability goals (S-4)

3. **Post-Launch Improvements:**
   - Implement backpressure mechanisms for WebSocket broadcast (S-2)
   - Enhance monitoring with alert routing and escalation policies (M-1)

The design provides a reasonable foundation for a real-time messaging platform but lacks production-grade reliability mechanisms. Without addressing critical issues C-1 through C-5, the system will experience frequent outages and extended recovery times that violate the stated 99.5% availability target.
