# Reliability Design Review: RealTimeChat システム設計書

## Critical Issues

### C-1: WebSocket Connection Fault Recovery Not Designed

**Issue**: The design document does not specify fault recovery mechanisms for WebSocket connections. The message flow (Section 3, lines 88-94) describes the happy path but omits:
- Automatic reconnection strategies when connections drop
- Client-side message buffering during disconnection
- Message delivery acknowledgment mechanisms
- Handling of connection failures during message transmission

**Impact**:
- Users may lose messages during network interruptions without realizing it
- No guarantee that sent messages are actually delivered to the server
- Degraded user experience as clients must manually refresh to reconnect
- Potential message duplication if clients retry without deduplication

**Countermeasures**:
1. Implement exponential backoff reconnection strategy with configurable max retry attempts
2. Design client-side message queue for pending messages during disconnection
3. Add message acknowledgment protocol (server confirms receipt with message ID)
4. Implement server-side deduplication using client-generated idempotency keys
5. Define connection heartbeat/ping-pong mechanism to detect stale connections

**References**: Section 3 (lines 88-94), API Design WebSocket endpoint (line 180)

---

### C-2: No Idempotency Design for Critical Operations

**Issue**: The design lacks idempotency mechanisms for message operations (POST /api/v1/messages, PUT /api/v1/messages, DELETE /api/v1/messages). Given the retry-prone nature of WebSocket and HTTP operations:
- Message creation (POST) could result in duplicate messages if client retries after timeout
- Message edits/deletions could fail inconsistently during network issues
- No client-generated idempotency keys are specified in the API design

**Impact**:
- Duplicate messages appearing in channels when clients retry failed sends
- Inconsistent message state if edit/delete operations are retried
- Poor user experience requiring manual cleanup of duplicates
- Potential data integrity issues in threaded conversations

**Countermeasures**:
1. Add `idempotency_key` field to POST /api/v1/messages request (client-generated UUID)
2. Store processed idempotency keys in Redis with TTL (e.g., 24 hours)
3. Design message edit/delete to use version numbers or last_modified timestamps
4. Implement conditional update semantics (e.g., If-Match headers with ETags)
5. Document idempotency guarantees in API specification

**References**: Section 5 API Design (lines 167-201)

---

### C-3: Redis Pub/Sub Single Point of Failure

**Issue**: The architecture relies on Redis Pub/Sub for real-time message distribution (line 93), but:
- No redundancy design for Redis Pub/Sub is mentioned
- ElastiCache cluster mode (line 249) doesn't guarantee Pub/Sub message delivery during failover
- Redis Pub/Sub is fire-and-forget; messages are lost if no subscribers are connected
- No fallback mechanism if Redis Pub/Sub is unavailable

**Impact**:
- Complete loss of real-time messaging capability during Redis failures
- Messages saved to MongoDB but never delivered to connected clients
- Users see stale state until manual refresh
- System-wide communication outage despite other components being healthy

**Countermeasures**:
1. Design fallback polling mechanism for clients to fetch missed messages from MongoDB
2. Implement server-side message delivery tracking (track last delivered message ID per connection)
3. Add heartbeat mechanism to detect Pub/Sub connection failures
4. Consider dual-write to persistent queue (e.g., SQS) in addition to Pub/Sub for durability
5. Design graceful degradation mode with increased polling frequency when Pub/Sub is down
6. Implement circuit breaker pattern to detect Pub/Sub failures and activate fallback

**References**: Section 3, lines 93 and 249

---

### C-4: No Transaction Management for Cross-Database Operations

**Issue**: The system uses PostgreSQL (metadata), MongoDB (messages), and Redis (cache/pub-sub), but the design doesn't specify:
- How consistency is maintained across these databases
- Transaction boundaries for operations spanning multiple stores
- Compensation logic if one database operation succeeds but another fails

For example, when creating a channel:
- Channel metadata goes to PostgreSQL (line 125-132)
- First message might go to MongoDB
- Cache invalidation in Redis

**Impact**:
- Orphaned data if PostgreSQL commits but MongoDB fails
- Inconsistent state between metadata and message stores
- Difficult to debug and recover from partial failures
- Users may see channels without messages or messages in non-existent channels

**Countermeasures**:
1. Adopt Saga pattern with compensation logic for multi-database operations
2. Design explicit consistency models for each operation type (eventual vs. strong)
3. Implement outbox pattern for reliable cross-database event publishing
4. Add reconciliation jobs to detect and fix inconsistencies
5. Document which operations are atomic and which are eventually consistent
6. Implement retry with exponential backoff for cross-database operations
7. Add distributed tracing to track operation success/failure across stores

**References**: Section 2 (lines 28-31), Section 4 (lines 97-162)

---

### C-5: No Circuit Breaker or Timeout Specifications

**Issue**: The design doesn't specify:
- Timeout values for external service calls (MongoDB, PostgreSQL, Redis, S3, FCM, SendGrid)
- Circuit breaker patterns to protect against cascading failures
- Bulkhead patterns to isolate failure domains
- Backpressure mechanisms when downstream services are slow

**Impact**:
- Thread pool exhaustion if database queries hang indefinitely
- Cascading failures when one service degrades affecting entire system
- No protection against slow external services (FCM, SendGrid) blocking request handlers
- Difficult to maintain availability SLO (99.5%, line 246) without fault isolation

**Countermeasures**:
1. Define explicit timeout policy for all external calls:
   - Database queries: 5-10 seconds
   - External APIs: 30 seconds
   - File uploads to S3: 60 seconds
2. Implement circuit breaker for each external dependency with thresholds:
   - Error rate threshold (e.g., 50% failures in 10s window)
   - Open circuit duration (e.g., 30 seconds)
   - Half-open state testing strategy
3. Design bulkhead pattern: separate thread pools for different services
4. Add backpressure: return 503 Service Unavailable when queues are full
5. Implement timeout-aware context propagation in Go using context.WithTimeout

**References**: Section 3 Architecture (lines 49-94), Section 7 (line 246)

---

## Significant Issues

### S-1: Insufficient Monitoring and Alerting Design

**Issue**: The monitoring design is minimal:
- CloudWatch Logs mentioned (line 219) but no metrics design
- No SLI/SLO specifications beyond availability target (99.5%, line 246)
- No alert definitions for critical failure scenarios
- Health check mentioned only in deployment context (line 230)

Missing critical signals:
- WebSocket connection count and churn rate
- Message delivery success rate
- Database query latency (p50, p95, p99)
- Redis Pub/Sub lag
- API error rates by endpoint

**Impact**:
- Unable to detect degradation before users complain
- No data to diagnose incidents or optimize performance
- Cannot validate if 99.5% availability SLO is met
- Reactive rather than proactive incident response

**Countermeasures**:
1. Define RED metrics for each service:
   - Request rate (messages/sec, API requests/sec)
   - Error rate (% of failed requests, by error type)
   - Duration (p50, p95, p99 latency for all operations)
2. Define SLOs for critical operations:
   - Message delivery latency: p95 < 200ms (per line 235)
   - API availability: 99.5% (per line 246)
   - WebSocket connection success rate: > 99%
3. Design health check endpoints:
   - Shallow: /health (service is running)
   - Deep: /health/ready (all dependencies reachable)
4. Specify alert rules:
   - Error rate > 5% for 5 minutes → Page on-call
   - p95 latency > 500ms for 5 minutes → Warning
   - Database connection pool exhaustion → Critical
   - Redis Pub/Sub lag > 10 seconds → Critical
5. Implement distributed tracing (e.g., AWS X-Ray) for request flows

**References**: Section 6 (lines 216-220), Section 7 (lines 234-237, 246)

---

### S-2: Database Failover Impact Not Analyzed

**Issue**: While Multi-AZ RDS is mentioned (line 248), the design doesn't address:
- Expected failover duration (typically 60-120 seconds for RDS)
- Application behavior during failover (connection pool refresh strategy)
- Message delivery impact during PostgreSQL failover
- Impact of MongoDB/DocumentDB failover on message history access

**Impact**:
- Message service may be unavailable for 1-2 minutes during database failover
- Existing connections will fail until application reconnects
- Users may experience authentication failures during Auth Service database failover
- Unclear if 99.5% availability SLO (line 246) accounts for failover time

**Countermeasures**:
1. Document expected failover behavior for each database:
   - RDS: 60-120 seconds, requires connection pool refresh
   - DocumentDB: failover time and client driver requirements
   - ElastiCache: cluster mode failover characteristics
2. Implement connection pool health checks and automatic refresh on failure
3. Design retry logic with exponential backoff for database operations
4. Add circuit breaker to prevent request pile-up during failover
5. Consider read replicas for PostgreSQL to serve read-only operations during failover
6. Define graceful degradation: allow message reading from replicas while writes are unavailable
7. Update SLO calculation to explicitly include failover windows

**References**: Section 7 (lines 246, 248-249)

---

### S-3: File Upload Reliability Not Addressed

**Issue**: File sharing is a core feature (line 11), but the design lacks:
- Retry strategy for failed S3 uploads
- Handling of partial uploads
- Cleanup of orphaned files (S3 files without corresponding messages)
- Validation of file integrity after upload
- Behavior when S3 is unavailable

**Impact**:
- Files may be partially uploaded but marked as complete in database
- Orphaned S3 objects consuming storage costs
- Messages may reference non-existent files if upload fails after message save
- No user feedback on upload progress or failure recovery

**Countermeasures**:
1. Implement two-phase file upload:
   - Phase 1: Client uploads to S3, receives file_id
   - Phase 2: Client sends message with file_id; server validates file exists
2. Add S3 object lifecycle policy to delete unattached files after 24 hours
3. Design retry with exponential backoff for S3 operations (timeout: 60s)
4. Implement multipart upload with resume capability for large files
5. Add file integrity check: store SHA-256 hash in message metadata
6. Design fallback: if S3 is unavailable, queue upload for later and notify user
7. Add background job to reconcile S3 objects with message attachments

**References**: Section 1 (line 11), Section 3 (line 60), Section 4 (lines 145-151)

---

### S-4: Notification Service Failure Isolation

**Issue**: Notification Service depends on external providers (FCM, SendGrid, line 84), but:
- No failure isolation between notification failures and core messaging
- No retry strategy for failed notifications
- No dead-letter queue for undeliverable notifications
- External service failures could block notification worker threads

**Impact**:
- Slow or failing external services (FCM, SendGrid) could degrade core messaging
- Users may miss notifications without any indication
- No visibility into notification delivery success rate
- Potential thread pool exhaustion if external services hang

**Countermeasures**:
1. Isolate Notification Service with separate ECS tasks and connection pool
2. Implement asynchronous notification delivery using SQS or Redis queue
3. Add circuit breaker for each external provider (FCM, SendGrid):
   - Open circuit after 50% failures in 10-second window
   - Fallback: queue notifications in DLQ for later retry
4. Design retry policy with exponential backoff (max 3 retries)
5. Add dead-letter queue for notifications that fail after max retries
6. Implement notification delivery tracking: store status in database
7. Add monitoring for notification delivery rate and lag time
8. Design graceful degradation: core messaging works even if notifications fail

**References**: Section 3 (lines 81-84, 94)

---

### S-5: No Rollback Plan for Data Migrations

**Issue**: While Blue/Green deployment is mentioned (line 229), the design doesn't address:
- Database schema migration strategy during deployments
- Rollback procedures if new schema is incompatible
- Backward compatibility requirements for schema changes
- Zero-downtime migration techniques

**Impact**:
- Unable to rollback deployment if new schema breaks application
- Potential data loss if migration fails mid-process
- Downtime required for schema changes violates zero-downtime goal
- Risk of application crashes if old code encounters new schema

**Countermeasures**:
1. Adopt backward-compatible migration strategy:
   - Phase 1: Add new columns/tables (nullable)
   - Phase 2: Deploy code that writes to both old and new schema
   - Phase 3: Migrate data in background
   - Phase 4: Deploy code that reads from new schema
   - Phase 5: Remove old columns/tables
2. Use database migration tools with rollback support (e.g., golang-migrate)
3. Test rollback procedures in staging environment for every migration
4. Implement feature flags to control which schema version is used
5. Design migrations to be idempotent and resumable
6. Add migration status tracking table to monitor progress
7. Document rollback procedures for each deployment

**References**: Section 6 (lines 228-230)

---

## Moderate Issues

### M-1: Rate Limiting Granularity

**Issue**: Rate limiting is specified at 1000 req/min per user (line 68), but:
- No distinction between read and write operations
- No protection against WebSocket connection flooding
- No team-level or IP-based rate limiting

**Impact**:
- Single user could exhaust message write capacity affecting others
- WebSocket connection storms could overwhelm server resources
- Abusive teams could impact other tenants

**Countermeasures**:
1. Implement tiered rate limits:
   - Message sends: 100/min per user
   - API reads: 1000/min per user
   - WebSocket connections: 10 concurrent per user
2. Add team-level quotas to prevent tenant-level abuse
3. Implement token bucket or leaky bucket algorithm for smooth rate limiting
4. Add IP-based rate limiting for unauthenticated endpoints
5. Design backpressure response: return 429 with Retry-After header

**References**: Section 3 (line 68)

---

### M-2: Message Search Performance Under Load

**Issue**: Full-text search is a core feature (line 13), but:
- No index design for MongoDB message search
- No caching strategy for common search queries
- No pagination or result limit specifications
- No timeout for long-running search queries

**Impact**:
- Slow search queries could degrade database performance
- Users may experience timeouts on complex searches
- High memory usage for large result sets
- Risk of database overload during peak search usage

**Countermeasures**:
1. Add text index on message content field in MongoDB
2. Implement search result pagination (max 100 results per page)
3. Add search query timeout (e.g., 10 seconds)
4. Cache frequent search queries in Redis with TTL
5. Consider Elasticsearch for advanced full-text search if performance is insufficient
6. Add search rate limiting (e.g., 10 searches/min per user)
7. Implement search result ranking to return most relevant results first

**References**: Section 1 (line 13)

---

### M-3: Logging Volume Management

**Issue**: Structured logging to CloudWatch (lines 216-220) is mentioned, but:
- No log retention policy specified
- No sampling strategy for high-volume debug logs
- No cost estimation for log storage
- Request ID tracing is good, but no correlation across services

**Impact**:
- CloudWatch Logs costs may grow unbounded
- High log volume could impact application performance
- Difficult to trace requests across multiple services
- Debug logs in production may leak sensitive information

**Countermeasures**:
1. Define log retention policy (e.g., 30 days for INFO, 7 days for DEBUG)
2. Implement log sampling: sample 10% of DEBUG logs in production
3. Use different log levels per environment (DEBUG in dev, INFO in prod)
4. Implement correlation ID propagation across all services
5. Add log filtering to exclude sensitive data (passwords, tokens)
6. Set CloudWatch log group retention policies
7. Consider log aggregation and archival to S3 for cost optimization

**References**: Section 6 (lines 216-220)

---

### M-4: Session Management Edge Cases

**Issue**: JWT-based auth with 1-hour access token and 7-day refresh token (line 204), but:
- No handling of concurrent sessions from same user
- No session invalidation mechanism on password change
- No protection against token theft or replay attacks
- Refresh token rotation strategy not specified

**Impact**:
- Stolen refresh tokens remain valid for 7 days
- Users cannot force logout of other sessions
- Password changes don't invalidate existing sessions
- Risk of session fixation attacks

**Countermeasures**:
1. Implement refresh token rotation: issue new refresh token on each use
2. Store active refresh tokens in Redis with user_id:token_id mapping
3. Add session list endpoint: users can view and revoke active sessions
4. Invalidate all sessions on password change by incrementing user version number
5. Add device fingerprinting to detect token theft
6. Implement sliding window for access token refresh (allow refresh before expiry)
7. Add logout endpoint that blacklists tokens in Redis

**References**: Section 5 (lines 203-207)

---

### M-5: Auto-Scaling Lag

**Issue**: CPU-based auto-scaling at 70% threshold (line 247), but:
- No consideration of scaling lag time (typically 3-5 minutes for ECS)
- CPU may not be the best metric for message-heavy workload
- No scale-down protection during traffic spikes
- No pre-scaling strategy for predictable load patterns

**Impact**:
- System may be overloaded before new tasks start
- Aggressive scale-down may cause instability during variable load
- WebSocket connections may be dropped during scaling events

**Countermeasures**:
1. Use multiple scaling metrics:
   - Active WebSocket connection count
   - Message queue depth
   - CPU and memory utilization
2. Set lower scaling threshold (e.g., 60% CPU) to scale proactively
3. Implement target tracking scaling for smoother scaling behavior
4. Add scale-down cooldown period (e.g., 10 minutes)
5. Pre-scale for predictable patterns (e.g., business hours)
6. Implement connection draining during scale-down to avoid abrupt disconnections
7. Monitor scaling events and adjust thresholds based on observed patterns

**References**: Section 7 (line 247)

---

## Minor Improvements

### I-1: Enhanced Deployment Safety

**Current State**: Blue/Green deployment with health checks (line 229-230)

**Enhancement Opportunities**:
1. Implement canary deployment: route 5% traffic to new version first
2. Add automated rollback triggers (e.g., error rate > 5%)
3. Define deployment windows (e.g., avoid peak hours)
4. Implement feature flags for gradual feature rollout
5. Add smoke tests that run post-deployment

**References**: Section 6 (lines 228-230)

---

### I-2: Disaster Recovery Testing

**Current State**: Cross-region snapshot sync with RTO 12h, RPO 24h (line 251)

**Enhancement Opportunities**:
1. Schedule regular DR drills (e.g., quarterly)
2. Automate DR failover procedures
3. Document detailed runbook for disaster recovery
4. Consider reducing RPO to 1 hour with continuous replication
5. Test data restore procedures from backups

**References**: Section 7 (line 251)

---

### I-3: Observability Enhancements

**Enhancement Opportunities**:
1. Add user-facing status page showing system health
2. Implement synthetic monitoring to detect issues proactively
3. Add performance budgets for critical operations
4. Implement alerting escalation policy
5. Create runbooks for common incident scenarios

**References**: Section 6 (lines 216-220), Section 7

---

## Positive Aspects

1. **Multi-AZ RDS configuration** (line 248) provides automated failover for PostgreSQL
2. **Daily backups with 30-day retention** (line 250) enable point-in-time recovery
3. **Request ID tracing** (line 220) facilitates debugging and issue correlation
4. **Blue/Green deployment** (line 229) reduces deployment risk
5. **Rate limiting** (line 68) provides basic protection against abuse
6. **HTTPS/WSS enforcement** ensures encrypted communication
7. **Structured logging** (line 217) enables effective log analysis
8. **Cross-region DR** (line 251) provides disaster recovery capability

---

## Summary

This design document provides a solid architectural foundation but has significant **reliability gaps** that must be addressed before production deployment:

**Critical priorities**:
1. Design WebSocket reconnection and message delivery acknowledgment mechanisms
2. Implement idempotency for all write operations
3. Add circuit breaker and timeout policies for all external dependencies
4. Design fallback mechanisms for Redis Pub/Sub failures
5. Define transaction boundaries and consistency models for multi-database operations

**Operational priorities**:
1. Specify comprehensive monitoring, metrics, and alerting strategy
2. Document database failover behavior and application recovery procedures
3. Design backward-compatible schema migration and rollback procedures
4. Implement notification service failure isolation
5. Add file upload reliability mechanisms

Addressing these issues will significantly improve the system's ability to handle failures gracefully and meet the 99.5% availability SLO.
