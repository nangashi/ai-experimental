# Reliability Design Review: RealTimeChat システム設計書

## Critical Issues

### 1. Single Point of Failure in Message Service WebSocket Layer (Critical)

**Issue**: Section 3 describes Message Service handling WebSocket connections and Redis Pub/Sub for message distribution, but does not specify how WebSocket connection state is shared across multiple Message Service instances. If a Message Service instance fails, all WebSocket connections to that instance are lost with no automatic recovery mechanism.

**Impact**:
- Complete loss of real-time messaging for users connected to the failed instance
- No automatic reconnection coordination—clients must detect disconnection and manually reconnect
- Potential message loss during failover if Redis Pub/Sub messages are published while clients are disconnected
- User experience degradation during scaling or deployment events

**Recommendation**:
- Implement sticky sessions at ALB level to minimize disruption, but design for connection migration across instances
- Add WebSocket connection registry in Redis (user_id → instance_id mapping) to enable connection state tracking
- Implement client-side automatic reconnection with exponential backoff (initial: 1s, max: 30s)
- Design message delivery acknowledgment protocol to detect and recover from missed messages during reconnection
- Add WebSocket health monitoring: track connection count per instance, alert on sudden drops > 20%

---

### 2. Missing Idempotency Design for Message Operations (Critical)

**Issue**: Section 5 defines `POST /api/v1/messages` for message sending and Section 3.3 describes the message flow, but neither specifies idempotency keys or duplicate detection mechanisms. The WebSocket reconnection scenario (see Issue #1) creates high risk of duplicate message submission if clients retry sends after connection loss.

**Impact**:
- Duplicate messages in channels if client retries after network timeout but original request succeeded
- Difficulty diagnosing and removing duplicate messages without explicit deduplication metadata
- Poor user experience: users see their messages appear multiple times
- Database bloat from duplicate message records in MongoDB

**Recommendation**:
- Require client-generated `message_id` (UUID) in POST /api/v1/messages request body
- Implement duplicate detection in Message Service: check MongoDB for existing message_id before insert
- Add unique index on messages.message_id in MongoDB to prevent race conditions
- Store message_id → processing status in Redis with 5-minute TTL for fast duplicate detection
- Return existing message in response if duplicate detected (200 OK with idempotent semantics)

---

### 3. No Retry Strategy for External Notification Dependencies (Critical)

**Issue**: Section 3.3 describes Notification Service integrating with external services (FCM, SendGrid) but provides no specification for retry logic, timeout handling, or fallback strategies when these external dependencies fail.

**Impact**:
- Silent notification delivery failures—users never receive critical alerts
- No visibility into notification system health during external service degradation
- Cascading failures if external API calls block indefinitely (no timeout specified)
- Potential memory exhaustion if notification queue grows unbounded during outages

**Recommendation**:
- Implement retry strategy with exponential backoff: 3 retries (1s, 5s, 15s intervals)
- Set aggressive timeouts: 5s per notification API call, 20s total including retries
- Add dead letter queue (DLQ) in SQS for failed notifications after retry exhaustion
- Implement circuit breaker pattern: open circuit after 5 consecutive failures, half-open retry after 60s
- Monitor notification delivery rates: alert if success rate < 95% over 5-minute window
- Design graceful degradation: log notification failures but do not block message delivery

---

### 4. Missing Transaction Management for Message and Notification Coordination (Significant)

**Issue**: Section 3.3 describes message flow where Message Service writes to MongoDB (step 3), then publishes to Redis Pub/Sub (step 4), then Notification Service sends notifications (step 6). There is no specification of how failures in steps 4-6 are handled after successful MongoDB write in step 3.

**Impact**:
- Message persisted in MongoDB but never delivered via WebSocket if Redis Pub/Sub fails
- Message delivered to online users but offline users never notified if Notification Service fails
- Inconsistent state: message exists in history API but was never received by some users
- Difficult recovery: no mechanism to identify and retry failed deliveries

**Recommendation**:
- Implement outbox pattern: store outbound events (Redis publish, notification triggers) in MongoDB transaction with message insert
- Add background worker to poll outbox table and publish events with retry logic
- Mark outbox entries as processed after successful Redis/notification delivery
- Add compensating transaction support: if MongoDB write succeeds but event publishing fails, flag message for async retry
- Monitor outbox processing lag: alert if unprocessed events > 1000 or oldest event > 5 minutes

---

## Significant Issues

### 5. Insufficient Monitoring Coverage for Real-Time Messaging SLO (Significant)

**Issue**: Section 6 mentions CloudWatch Logs and Section 7.1 defines performance targets (200ms message delivery, 500ms API p95), but the design does not specify:
- SLO/SLA definitions for message delivery reliability
- RED metrics collection (request rate, error rate, latency distribution)
- Alert thresholds and escalation policies for SLO violations
- Health check endpoints for ECS task health monitoring

**Impact**:
- Delayed incident detection—no proactive alerting for degraded message delivery performance
- Difficulty measuring actual performance against 200ms delivery target
- Manual log analysis required during outages (increasing MTTR)
- No clear criteria for rollback decisions during deployments
- Inability to identify WebSocket connection stability issues before user complaints

**Recommendation**:
- Define SLOs: 99.5% message delivery success rate, p95 delivery latency < 300ms, 99.9% API availability
- Implement RED metrics:
  - Request rate: messages/second, WebSocket connections/second
  - Error rate: failed message sends, WebSocket disconnects, database errors
  - Duration: p50/p95/p99 latency for message delivery, API response times
- Configure CloudWatch alarms:
  - Message delivery error rate > 0.5% (5-minute window)
  - WebSocket disconnect rate > 5% (1-minute window)
  - API p95 latency > 700ms (5-minute window)
  - Database connection pool exhaustion
- Add health check endpoints:
  - `/health/liveness`: basic HTTP 200 response
  - `/health/readiness`: verify database connectivity, Redis connectivity
- Integrate with PagerDuty for on-call escalation

---

### 6. No Circuit Breaker for Database Dependencies (Significant)

**Issue**: Section 3 describes dependencies on PostgreSQL (Auth Service), MongoDB (Message Service), and Redis (all services), but does not specify circuit breaker patterns or bulkhead isolation to prevent cascading failures when database connections are exhausted or slow.

**Impact**:
- Thread pool exhaustion if database queries hang indefinitely
- Cascading failures across all services if shared database becomes slow
- Inability to gracefully degrade—entire service becomes unresponsive
- Difficult recovery: service must be restarted to clear blocked threads

**Recommendation**:
- Implement circuit breaker for each database client using go-resiliency/circuitbreaker or hystrix-go
- Configure circuit breaker thresholds:
  - Open after 10 consecutive failures or 50% error rate over 30s window
  - Half-open retry after 30s
  - Close after 5 consecutive successes
- Set database query timeouts: 5s for reads, 10s for writes
- Implement connection pool limits: max 50 connections per service instance to prevent resource exhaustion
- Add bulkhead pattern: separate thread pools for database operations vs. request handling
- Monitor circuit breaker state: alert when circuit opens, log state transitions

---

### 7. Missing Graceful Shutdown for WebSocket Connections During Deployment (Significant)

**Issue**: Section 6.5 specifies Blue/Green deployment with health checks but does not describe how in-flight WebSocket connections are handled when old ECS tasks are terminated. Abrupt termination will disconnect all active users.

**Impact**:
- 50,000 simultaneous WebSocket disconnections during each deployment
- Poor user experience: users see "disconnected" errors during maintenance windows
- Message loss for messages in-flight during termination
- Increased load on new instances as all clients reconnect simultaneously (thundering herd)

**Recommendation**:
- Implement graceful shutdown handler:
  - On SIGTERM signal, stop accepting new WebSocket connections
  - Send "server shutting down" message to all connected clients
  - Allow 30s grace period for clients to close connections and reconnect to new instances
  - Forcefully close remaining connections after grace period
- Configure ALB connection draining: 60s timeout to allow graceful shutdown
- Update ECS task definition: set `stopTimeout: 90` to allow shutdown sequence to complete
- Implement client-side reconnection logic: retry with jitter to avoid thundering herd
- Add deployment monitoring: track reconnection rate, alert if > 10,000 reconnects/minute

---

## Moderate Issues

### 8. Lack of Rate Limiting Granularity (Moderate)

**Issue**: Section 3.3.1 specifies "1000 req/min" rate limiting per user at API Gateway level, but does not specify:
- Rate limits for WebSocket message sends (distinct from HTTP API calls)
- Burst allowance vs. sustained rate
- Differentiated limits for different operations (e.g., file uploads vs. text messages)
- Backpressure strategy when limits are exceeded

**Impact**:
- Single malicious or misbehaving client can send 1000 messages/min, consuming disproportionate resources
- No protection against WebSocket message flooding (separate from HTTP request limit)
- Poor user experience: users receive generic "rate limited" error without retry guidance
- Difficulty diagnosing legitimate traffic spikes vs. abuse

**Recommendation**:
- Implement tiered rate limits:
  - Text messages: 100 messages/min per user (burst: 20 messages/10s)
  - File uploads: 10 uploads/min per user
  - API requests: 1000 req/min per user (existing)
- Add WebSocket-specific rate limiting: track message sends per connection in Redis sliding window
- Return structured rate limit errors with `Retry-After` header and current limit status
- Implement token bucket algorithm for burst handling
- Monitor rate limit violations: track per-user violation counts, alert on patterns

---

### 9. Insufficient Backup and Recovery Documentation (Moderate)

**Issue**: Section 7.3 specifies "日次フルバックアップ（保持期間30日）" and disaster recovery with RTO=12h, RPO=24h, but does not document:
- Backup verification procedures (how to ensure backups are restorable)
- Point-in-time recovery (PITR) capabilities for MongoDB and PostgreSQL
- Recovery runbooks for different failure scenarios
- Backup restore testing schedule

**Impact**:
- Risk of discovering corrupt or incomplete backups during actual disaster recovery
- Inability to recover from logical corruption (e.g., accidental bulk delete) if discovered after 24h RPO window
- Untested recovery procedures may fail during critical incidents
- No clear procedure for partial recovery (e.g., restoring single team's data)

**Recommendation**:
- Enable PostgreSQL Point-in-Time Recovery (PITR) with WAL archiving to S3 for granular recovery
- Enable MongoDB continuous backup with AWS DocumentDB automatic backups
- Implement automated backup verification:
  - Weekly: restore backup to isolated environment and run schema validation
  - Monthly: full disaster recovery drill with RTO/RPO measurement
- Document recovery runbooks:
  - Full database restore procedure
  - Point-in-time recovery for data corruption scenarios
  - Partial team data restore from backup
- Add backup monitoring: alert if backup age > 25 hours or backup size anomaly > 50% deviation

---

### 10. Missing Chaos Engineering and Failure Testing Strategy (Moderate)

**Issue**: Section 6.4 specifies load testing with JMeter for 10,000 concurrent connections but does not describe failure mode testing, dependency failure simulation, or resilience validation.

**Impact**:
- Unknown system behavior under real-world failure conditions (database slowdown, network partitions, etc.)
- False confidence from load testing that only validates happy path scenarios
- Production incidents reveal untested failure modes
- Difficulty validating circuit breaker, retry, and fallback mechanisms

**Recommendation**:
- Implement chaos engineering practices using AWS Fault Injection Simulator (FIS):
  - Inject database latency (simulate slow queries)
  - Terminate random ECS tasks (validate auto-recovery)
  - Inject network packet loss between services
  - Exhaust database connection pools
- Schedule monthly chaos experiments in staging environment
- Define failure test scenarios:
  - MongoDB primary failover during message send
  - Redis cluster node failure during Pub/Sub operation
  - External notification service (FCM/SendGrid) 500 errors
  - ALB instance failure during peak load
- Measure blast radius and MTTR for each failure scenario
- Document failure mode playbooks based on chaos experiment learnings

---

## Minor Improvements and Positive Aspects

### Positive Aspects

1. **Multi-AZ Database Configuration**: Section 7.3 correctly specifies RDS Multi-AZ for automatic failover, reducing database-level SPOF risk.

2. **Auto Scaling Design**: ECS Auto Scaling based on CPU 70% threshold (Section 7.3) provides basic capacity management for traffic spikes.

3. **Blue/Green Deployment**: Section 6.5 specifies Blue/Green deployment with health checks, reducing deployment risk compared to in-place updates.

4. **Security Fundamentals**: Section 7.2 covers basic security hygiene (HTTPS, password hashing, CORS), reducing attack surface.

### Minor Improvements

5. **Add Structured Error Codes**: Section 6.1 describes HTTP status-based errors but should add application-level error codes (e.g., `MSG_DUPLICATE_SEND`, `MSG_CHANNEL_NOT_FOUND`) to enable client-side error handling logic.

6. **Implement Request Tracing**: Section 6.2 mentions request IDs in logs, but should add distributed tracing (AWS X-Ray) to visualize cross-service request flows and identify bottlenecks.

7. **Define Database Connection Retry Logic**: While Multi-AZ failover is specified, the design should explicitly document connection retry strategy during failover events (e.g., retry 3 times with 1s backoff).

8. **Add Feature Flags for Rollout Control**: Section 6.5 deployment strategy should include feature flag system (e.g., LaunchDarkly) to enable gradual rollout and quick rollback without redeployment.

---

## Summary

This design demonstrates baseline infrastructure resilience (Multi-AZ databases, auto-scaling, Blue/Green deployments) but has critical gaps in application-level fault tolerance and operational readiness. The most urgent concerns are:

1. **WebSocket connection state management** during instance failures
2. **Idempotency mechanisms** for message operations
3. **Retry and circuit breaker patterns** for external dependencies
4. **Transaction coordination** between message persistence and delivery

Addressing these issues—particularly implementing idempotency keys, circuit breakers, graceful shutdown, and comprehensive monitoring—will significantly improve the system's resilience to production failures and operational incidents.

The specified RTO/RPO targets (12h/24h) are appropriate for the beta phase scope, but monitoring and alerting gaps create risk of extended MTTR during incidents. Prioritize observability improvements alongside fault tolerance mechanisms.
