# Reliability Design Review: Smart Home Energy Management System

## Phase 1: Structural Analysis

### System Components
1. **API Gateway** (Go) - Request routing, JWT validation, rate limiting, WebSocket management
2. **Device Manager** (Go) - Device registration, MQTT command dispatch, Redis state sync, firmware updates
3. **Analytics Engine** (Go) - Historical aggregation, ML predictions, recommendations, reporting
4. **MQTT Broker** (AWS IoT Core) - Bidirectional device communication, topic routing, device shadows
5. **Kinesis Stream** - Real-time event ingestion and fanout
6. **PostgreSQL + TimescaleDB** - User data, device registry, time-series sensor data
7. **Redis Cluster** - Real-time device state, session management

### Data Flow Paths
1. **Sensor Data**: Device → MQTT → Kinesis → TimescaleDB + Redis
2. **User Commands**: Mobile → API Gateway → Device Manager → MQTT → Device
3. **Analytics**: Dashboard → API Gateway → Analytics Engine → TimescaleDB
4. **Predictions**: Analytics Engine → TensorFlow Model → Recommendation API

### External Dependencies
- **Critical**: AWS IoT Core (MQTT), Kinesis, EKS, ECR
- **Significant**: PostgreSQL, Redis Cluster, CloudWatch
- **Monitoring**: Prometheus, Grafana

### Explicitly Mentioned Reliability Mechanisms
- Blue-green deployment for API Gateway/backend
- Kubernetes rolling updates with readiness probes
- Database migrations with backward compatibility (Flyway)
- Canary releases for Analytics Engine (10%→50%→100%)
- Analytics Engine: 3 retries with exponential backoff (1s, 2s, 4s) for database queries
- PostgreSQL read replicas (2 replicas)
- Redis Cluster (3 master + 3 replica)
- Cross-region DR (active-passive, us-east-1 → us-west-2)
- Daily PostgreSQL backups + WAL archiving
- Redis RDB snapshots every 6 hours
- RPO: 1 hour, RTO: 4 hours

---

## Phase 2: Problem Detection

### TIER 1: CRITICAL ISSUES (System-Wide Impact)

#### C1. No Transaction Boundaries or Distributed Transaction Strategy
**Component**: Device Manager, Analytics Engine, Data Flow

**Issue**: The design lacks explicit transaction boundary definitions across critical operations:
- Device command dispatch involves multiple state changes: writing to `device_commands` table, publishing to MQTT, updating Redis device state
- Sensor data ingestion (MQTT → Kinesis → TimescaleDB + Redis) has no consistency guarantees
- User registration involves `users` table + device provisioning, with no transaction coordination described

**Failure Scenario**:
1. Device command is saved to PostgreSQL (`device_commands.status='pending'`) but MQTT publish fails
2. User sees command as "sent" but device never receives it
3. No automatic reconciliation, leaving orphaned pending commands
4. Similar risk: Kinesis writes sensor data to TimescaleDB successfully but Redis update fails, causing stale device state in real-time API

**Impact**: Data inconsistency between PostgreSQL, MQTT, and Redis. Orphaned commands accumulate. Real-time dashboard shows stale data while historical records are correct.

**Countermeasures**:
- Define ACID transaction boundaries for single-database operations (e.g., user registration)
- Implement **Transactional Outbox Pattern** for device commands:
  - Write command to `device_commands` table in same transaction as business logic
  - Background worker polls table for `status='pending'`, publishes to MQTT, updates status to `sent`/`failed`
  - Ensures at-least-once delivery with idempotency at device level
- For Kinesis → (TimescaleDB + Redis): Use **Saga pattern** or accept eventual consistency with monitoring for lag > threshold
- Add idempotency keys to device commands (see C2)

---

#### C2. Missing Idempotency Design for Device Commands
**Component**: Device Manager, Device Command API

**Issue**: Device command API (`POST /api/v1/devices/{id}/commands`) has no idempotency mechanism. Section 5 shows command response includes `command_id` but no mention of client-provided idempotency keys or duplicate detection.

**Failure Scenario**:
1. Mobile app sends "turn off AC" command
2. Network timeout occurs after server receives request but before response reaches client
3. App retries, creating duplicate command
4. Device receives two "turn off" commands, potentially toggling state (off → on → off) or causing unexpected behavior
5. Energy cost impact: AC may stay on when user expects it off

**Impact**: Command duplication can cause:
- Device state flapping (on/off/on)
- Wasted energy and user frustration
- Billing discrepancies if commands are tied to billing events
- Difficult to debug in production (looks like user error)

**Countermeasures**:
- Add `idempotency_key` field to command API (client-generated UUID or hash of command params)
- Store idempotency key in `device_commands` table with unique constraint
- On duplicate key, return existing `command_id` instead of creating new command
- Set idempotency key TTL (e.g., 24 hours) to prevent unbounded table growth
- Document idempotency requirement in API specification

---

#### C3. No Circuit Breaker or Timeout Configuration for External Dependencies
**Component**: API Gateway, Device Manager, Analytics Engine

**Issue**: The design mentions rate limiting but no circuit breakers, timeout values, or bulkhead isolation for external calls:
- Device Manager → MQTT Broker (AWS IoT Core)
- Analytics Engine → TimescaleDB
- API Gateway → Device Manager/Analytics Engine
- Kinesis Stream consumers

**Failure Scenario**:
1. PostgreSQL read replica experiences high latency (10+ seconds) due to runaway query
2. Analytics Engine threads block waiting for query response (no timeout configured)
3. Thread pool exhaustion prevents new analytics requests
4. **Cascading failure**: API Gateway requests to Analytics Engine also time out
5. User-facing dashboard becomes completely unavailable despite MQTT/device commands still working

**Impact**:
- Single slow dependency brings down entire service
- No fault isolation between components
- Difficult to identify root cause (all services appear "hung")
- Recovery requires manual intervention (restart services)

**Countermeasures**:
- **Timeouts**: Define and document timeout values for all external calls:
  - MQTT publish: 5s
  - PostgreSQL queries: Read replicas 10s, primary 5s
  - Redis operations: 1s
  - Kinesis API calls: 30s
  - Inter-service HTTP: 10s
- **Circuit Breakers** (e.g., `gobreaker` library):
  - Wrap all external dependencies
  - Open circuit after 5 consecutive failures or 50% error rate in 10s window
  - Half-open after 30s cooldown, close after 3 successful requests
- **Bulkhead Isolation**:
  - Separate Goroutine pools for MQTT, PostgreSQL, Redis operations
  - Limit concurrent connections to each dependency (e.g., max 100 to PostgreSQL)
- **Graceful Degradation**:
  - Analytics Engine: Return cached predictions from Redis if TimescaleDB unavailable
  - Device status: Serve from Redis even if PostgreSQL down (historical data unavailable but real-time works)

---

#### C4. Insufficient Backup Validation and Restore Testing
**Component**: PostgreSQL, Redis, Disaster Recovery

**Issue**: Section 7 specifies backup schedule (PostgreSQL daily + WAL, Redis every 6 hours) but no mention of:
- Backup integrity verification
- Restore procedure testing
- Recovery time validation
- Data consistency checks post-restore

**Failure Scenario**:
1. Silent corruption in PostgreSQL WAL archiving process (misconfigured S3 bucket permissions)
2. Backups appear successful but WAL files are incomplete/corrupted
3. Primary database fails after 6 months
4. Attempt DR failover to us-west-2 using backups
5. **Discovery**: Backups cannot be restored due to missing WAL segments
6. RPO claim of "1 hour" becomes "6 months" (catastrophic data loss)

**Impact**:
- False sense of security (backups exist but are unusable)
- Actual RPO/RTO far worse than documented
- Potential business failure if historical energy data is unrecoverable
- Regulatory compliance issues (data retention requirements)

**Countermeasures**:
- **Automated Restore Testing**:
  - Weekly: Restore PostgreSQL backup to isolated environment, verify schema + row counts
  - Monthly: Full restore test with application integration (run read-only queries against restored data)
  - Quarterly: DR failover drill (promote us-west-2, run production traffic for 1 hour, failback)
- **Backup Validation**:
  - PostgreSQL: Run `pg_verifybackup` on completed backups
  - Checksum verification for S3 archived WAL files
  - Alert on backup size anomalies (> 20% deviation from 7-day average)
- **Monitoring**:
  - Track `time_since_last_successful_restore_test` metric, alert if > 7 days
  - Monitor WAL archiving lag (should be < 1 minute)
  - Verify backup retention policy enforcement (auto-delete after 30 days)
- **Documentation**:
  - Maintain runbook for restore procedures (step-by-step with screenshots)
  - Update runbook after each restore test with lessons learned

---

#### C5. No Data Validation or Consistency Checks for Sensor Data
**Component**: Kinesis Stream, TimescaleDB, Device Manager

**Issue**: Sensor data flow (Device → MQTT → Kinesis → TimescaleDB) lacks validation:
- No schema validation for MQTT payloads
- No range checks for `power_watts`, `voltage`, `current` values
- No duplicate detection (same timestamp + device_id written twice)
- No handling of out-of-order events

**Failure Scenario**:
1. Firmware bug in smart meter sends corrupted data: `power_watts = -999999`
2. Data is ingested into TimescaleDB without validation
3. Analytics Engine calculates monthly energy cost using corrupted data
4. User receives bill estimate of $-50,000 (negative cost)
5. Optimization recommendations become nonsensical ("use more energy!")
6. Issue undetected for weeks until user reports billing anomaly

**Impact**:
- Corrupted analytics and predictions undermine system value
- User trust erosion when bills/recommendations are wrong
- Difficult to identify and remove bad data retroactively
- Potential legal liability for incorrect billing information

**Countermeasures**:
- **Schema Validation**:
  - Define JSON schema for MQTT payloads, validate before Kinesis write
  - Reject malformed messages, send to dead letter queue for investigation
- **Range Checks**:
  - `power_watts`: 0 to 10,000 (configurable per device type)
  - `voltage`: 100 to 250V (regional standard ± tolerance)
  - `current`: 0 to 100A (typical residential max)
  - Flag values outside range as anomalies, store in separate `anomalies` table
- **Duplicate Detection**:
  - Check for existing `(device_id, time)` tuple before insert (may require deduplication window in Kinesis consumer)
  - Use TimescaleDB unique index on `(device_id, time)` to prevent duplicates
- **Out-of-Order Handling**:
  - TimescaleDB handles out-of-order inserts well, but monitor for excessive lag (> 1 hour)
  - Alert if device consistently sends stale data (clock drift issue)
- **Anomaly Detection**:
  - Run periodic queries to detect sudden spikes (> 10x baseline) or impossible values
  - Surface anomalies in admin dashboard for manual review

---

### TIER 2: SIGNIFICANT ISSUES (Partial System Impact)

#### S1. Rate Limiting Configured Only at API Gateway, Not at Service Level
**Component**: API Gateway, Device Manager, Analytics Engine

**Issue**: Section 3 mentions "rate limiting (1000 req/min per user)" at API Gateway, but no service-level rate limiting or backpressure mechanisms for:
- MQTT command dispatch rate per device
- TimescaleDB query concurrency
- Kinesis write throughput

**Failure Scenario**:
1. Malicious or buggy mobile app bypasses rate limiting (e.g., uses multiple accounts)
2. Floods Device Manager with 10,000 commands/second for a single device
3. MQTT broker becomes overloaded (AWS IoT Core has per-device limits)
4. Device disconnects due to message queue overflow
5. Legitimate users cannot control their devices

**Impact**:
- Single abusive user can cause localized DoS for specific devices
- No protection against internal service abuse (service-to-service calls)
- AWS IoT Core throttling may trigger, affecting all users

**Countermeasures**:
- **Service-Level Rate Limiting**:
  - Device Manager: Max 10 commands/minute per device (Redis-based token bucket)
  - Analytics Engine: Max 100 concurrent TimescaleDB queries (semaphore)
  - MQTT publish rate: 100 msg/second per device topic
- **Backpressure**:
  - Kinesis consumer: Slow down consumption if TimescaleDB write queue > 10,000 events
  - Return HTTP 429 (Too Many Requests) when service-level limits exceeded, include `Retry-After` header
- **Priority Queues**:
  - Separate high-priority (user-initiated commands) from low-priority (scheduled automation) traffic
  - Ensure high-priority commands are processed even during load spikes

---

#### S2. Missing Dead Letter Queue and Poison Message Handling
**Component**: Kinesis Stream, Analytics Engine

**Issue**: No mention of dead letter queue (DLQ) for unprocessable events in Kinesis stream. Section 6 mentions logging MQTT publish failures but not Kinesis consumer failures.

**Failure Scenario**:
1. Kinesis consumer receives event with unexpected schema version (old firmware)
2. Deserialization fails, consumer crashes and restarts
3. Kinesis redelivers same event (at-least-once delivery)
4. Crash loop prevents consumer from processing any subsequent events
5. Real-time data ingestion stops for all users

**Impact**:
- Single bad message blocks entire event stream
- Data loss for all subsequent events until manual intervention
- No visibility into why consumer is failing

**Countermeasures**:
- **DLQ Implementation**:
  - After 3 failed processing attempts, send event to SQS DLQ
  - Log full event payload and error message for debugging
  - Continue processing next event (skip poison message)
- **Poison Message Detection**:
  - Track per-event retry count in consumer state
  - Automatically quarantine events that fail > 3 times
  - Alert ops team when DLQ depth > 100 messages
- **Schema Versioning**:
  - Include `schema_version` field in MQTT payloads
  - Consumer maintains backward compatibility for N-1 versions
  - Reject unsupported versions gracefully (send to DLQ, don't crash)

---

#### S3. No Health Checks for MQTT Broker or Kinesis Stream
**Component**: Device Manager, Kinesis Stream, Monitoring

**Issue**: Section 3 mentions Kubernetes readiness probes but no health checks for external AWS services:
- AWS IoT Core (MQTT Broker) connectivity
- Kinesis Stream availability and throughput
- CloudWatch Logs ingestion

**Failure Scenario**:
1. AWS IoT Core experiences regional outage in us-east-1
2. Device Manager cannot publish commands but passes readiness probe (only checks HTTP endpoint)
3. Kubernetes considers service healthy, continues routing traffic
4. All device commands fail with timeout errors
5. Users experience 100% command failure rate but monitoring shows "all services green"

**Impact**:
- False negative health status delays incident detection
- Auto-scaling may increase pod count, worsening load on failing dependency
- Mean time to detection (MTTD) increases by 10+ minutes

**Countermeasures**:
- **Dependency Health Checks**:
  - Add `/health/deep` endpoint that checks:
    - PostgreSQL connectivity (simple SELECT 1 query)
    - Redis connectivity (PING command)
    - MQTT broker connectivity (publish to test topic, wait for ACK)
    - Kinesis write capability (small test record)
  - Use existing `/health` for Kubernetes liveness (fast, no external deps)
  - Use `/health/deep` for readiness probe (slower, catches dependency failures)
- **Synthetic Monitoring**:
  - Periodically send synthetic commands through full stack (API → MQTT → device simulator)
  - Measure end-to-end latency, alert if > 2x baseline
  - Run from external monitoring service (not on EKS cluster)
- **AWS Service Health Integration**:
  - Subscribe to AWS Health Dashboard events for IoT Core, Kinesis, RDS
  - Auto-page on-call when AWS reports service degradation in us-east-1

---

#### S4. Deployment Strategy Lacks Automated Rollback Triggers
**Component**: Deployment, Canary Releases

**Issue**: Section 6 describes blue-green deployment and canary releases but no automated rollback conditions based on SLI degradation:
- No error rate threshold for aborting canary
- No latency degradation threshold
- Manual monitoring implied ("over 3 days" suggests human oversight)

**Failure Scenario**:
1. Analytics Engine canary deployment (10% traffic) introduces memory leak
2. Memory usage grows slowly over 8 hours, triggering OOM after 12 hours
3. No automated detection during canary phase
4. Canary progresses to 50% traffic
5. Half of Analytics Engine pods crash, causing widespread analytics unavailability

**Impact**:
- Slow-moving bugs reach production before detection
- Canary rollout becomes risk, not safety mechanism
- User impact scales with canary percentage

**Countermeasures**:
- **Automated Rollback Triggers**:
  - Error rate > 1% for 5 consecutive minutes → auto-rollback canary
  - P95 latency > 500ms (2.5x baseline) → auto-rollback
  - Memory usage > 80% → halt rollout, alert ops
  - HTTP 5xx rate > 0.5% → immediate rollback
- **Canary Analysis**:
  - Use progressive delivery tool (Flagger, Argo Rollouts) for automated analysis
  - Compare canary metrics to baseline (current production) in real-time
  - Require statistical significance before progressing (e.g., 95% confidence)
- **Bake Time**:
  - Each canary phase runs minimum 2 hours before progression (allows memory leaks to surface)
  - Analytics Engine: 10% for 8 hours → 50% for 8 hours → 100%
  - API Gateway: 10% for 2 hours → 25% → 50% → 100% (faster progression for stateless service)

---

#### S5. Database Migration Backward Compatibility Not Enforced
**Component**: PostgreSQL, Flyway, Deployment

**Issue**: Section 6 mentions "backward-compatible schema changes" but no enforcement mechanism or specific patterns described. Risk of breaking rolling deployments if incompatible migration is deployed.

**Failure Scenario**:
1. Developer adds `NOT NULL` column to `devices` table without default value
2. Migration runs on database during deployment
3. Old application pods (still running during rolling update) attempt to INSERT without new column
4. INSERTs fail with constraint violation
5. Device registration API returns 500 errors until all pods updated

**Impact**:
- Deployment causes temporary outage even with rolling update strategy
- Violates zero-downtime deployment goal
- Rollback requires manual database rollback (risky)

**Countermeasures**:
- **Expand-Contract Migration Pattern**:
  - Phase 1 (Deploy N): Add column as nullable, deploy application code that writes to new column
  - Phase 2 (Deploy N+1): Backfill data, add NOT NULL constraint, remove old code paths
  - Ensure 2-deployment separation for breaking changes
- **Migration Linting**:
  - CI pipeline runs automated checks for backward-incompatible changes:
    - Adding NOT NULL without DEFAULT
    - Dropping columns (require deprecation period)
    - Renaming columns without alias/view
    - Changing column types
  - Block merge if incompatible migration detected
- **Database Deployment Decoupling**:
  - Migrations run before application deployment (separate CI/CD step)
  - Application deployment waits for migration success + N-minute soak time
  - Allows detection of migration issues before code rollout

---

### TIER 3: MODERATE ISSUES (Operational Improvement)

#### M1. No SLO/SLA Definitions or Error Budgets
**Component**: Monitoring, Operational Readiness

**Issue**: Section 7 defines performance goals (p95 < 200ms) and availability target (99.9%) but no formal SLO definitions with error budgets or alerting thresholds.

**Impact**:
- No objective criteria for incident severity
- Difficult to prioritize reliability work vs. feature development
- No guardrails for deployment velocity

**Countermeasures**:
- Define SLOs with error budgets:
  - **Availability SLO**: 99.9% (43.8 min downtime/month)
  - **Latency SLO**: 95% of API requests < 200ms
  - **Command Success Rate SLO**: 99% of device commands succeed within 5s
- Implement error budget policy:
  - If error budget exhausted, freeze feature releases until budget replenished
  - Dedicate 20% of sprint to reliability improvements when budget < 25%
- Alerting based on error budget burn rate:
  - Alert if projected to exhaust monthly budget in < 3 days (fast burn)
  - Warn if burn rate > 2x expected (slow burn)

---

#### M2. Missing Distributed Tracing for End-to-End Request Flows
**Component**: Logging, Observability

**Issue**: Section 6 mentions "correlation IDs for distributed tracing" but no tracing system (Jaeger, X-Ray) mentioned. Difficult to debug latency issues across multiple services.

**Impact**:
- Cannot identify bottlenecks in multi-hop flows (e.g., API → Device Manager → MQTT → Device)
- Debugging production issues requires correlating logs across 5+ services manually
- High MTTR for complex failures

**Countermeasures**:
- Implement distributed tracing:
  - Use AWS X-Ray SDK for Go services
  - Propagate trace context via HTTP headers (`X-Amzn-Trace-Id`) and MQTT message properties
  - Sample 1% of requests in production, 100% of errors
- Create tracing dashboards:
  - End-to-end latency breakdown (API Gateway → Device Manager → MQTT)
  - Service dependency map with error rates
  - P95/P99 latency per service hop
- Alert on trace anomalies:
  - Any request > 5s total latency
  - MQTT publish step > 1s (indicates broker congestion)

---

#### M3. No Capacity Planning or Load Testing Results
**Component**: Performance, Scalability

**Issue**: Section 6 mentions load testing target (10,000 concurrent users) but no results or capacity planning data. Section 7 defines auto-scaling based on CPU (70%) but no validation that this threshold is appropriate.

**Impact**:
- Unknown headroom before hitting resource limits
- Auto-scaling may trigger too late (70% CPU may already cause latency degradation)
- No confidence in handling Black Friday-style traffic spikes

**Countermeasures**:
- Conduct load testing with documented results:
  - Establish baseline: Current system handles X concurrent users with Y p95 latency
  - Test auto-scaling: Verify HPA triggers before latency SLO violation
  - Test sustained load: 10,000 users for 1 hour (not just peak)
- Capacity planning:
  - Document per-pod resource consumption at 50%, 80%, 100% load
  - Calculate cluster-wide capacity (e.g., "50 API Gateway pods support 50,000 users")
  - Maintain 30% headroom above peak expected load
- Chaos testing:
  - Kill random pods during load test, verify graceful degradation
  - Simulate PostgreSQL read replica failure, measure impact on analytics latency

---

#### M4. No Incident Response Runbooks or On-Call Procedures
**Component**: Operational Readiness

**Issue**: No mention of incident response procedures, runbooks, or on-call rotation. Section 3 lists monitoring tools (Prometheus, Grafana) but no escalation policies.

**Impact**:
- Slow incident response due to knowledge gaps ("who knows how to restore from backup?")
- Inconsistent handling of similar incidents
- On-call engineer burnout (unclear expectations)

**Countermeasures**:
- Create runbooks for common failure scenarios:
  - PostgreSQL primary failure → DR failover procedure
  - Redis cluster node failure → force failover to replica
  - MQTT broker disconnection → check AWS service health, restart Device Manager pods
  - TimescaleDB query timeout → identify slow queries, kill if necessary
- Define on-call rotation:
  - Primary on-call: Responds within 15 minutes for P1 (user-facing outage)
  - Secondary on-call: Escalation after 30 minutes no response
  - Manager escalation: After 1 hour or customer impact > 1000 users
- Blameless postmortem process:
  - Required for all P1 incidents
  - Document timeline, root cause, action items with owners
  - Share postmortems publicly (internal wiki) for learning

---

#### M5. Missing Resource Quotas and Cost Controls
**Component**: Kubernetes, AWS, Scalability

**Issue**: Auto-scaling based on CPU (HPA) with no upper bounds or resource quotas mentioned. Risk of runaway scaling driving excessive AWS costs.

**Impact**:
- Budget overrun if traffic spike or resource leak triggers unbounded scaling
- No guardrails against accidental cost disasters (e.g., Kinesis stream provisioned at 1000 shards)
- Difficult to forecast infrastructure costs

**Countermeasures**:
- Kubernetes resource quotas:
  - Namespace-level limits: Max 100 pods, 200 CPU cores, 400GB memory
  - Per-deployment limits: Max 50 replicas per service
  - PodDisruptionBudget: Ensure minimum 3 replicas always available during disruptions
- AWS cost controls:
  - Budgets with alerts: Warn at 80% monthly budget, alert at 100%
  - Kinesis shard limits: Max 10 shards (manual approval for increase)
  - RDS instance size limits: Max db.r5.4xlarge (prevent accidental upgrade to db.r5.24xlarge)
- Cost monitoring:
  - Track per-service cost attribution (tags on AWS resources)
  - Alert on 50% day-over-day cost increase (indicates leak or attack)

---

## Summary

### Critical Issues Identified: 5
1. No transaction boundaries or distributed transaction strategy
2. Missing idempotency design for device commands
3. No circuit breaker or timeout configuration for external dependencies
4. Insufficient backup validation and restore testing
5. No data validation or consistency checks for sensor data

### Significant Issues Identified: 5
1. Rate limiting only at API Gateway, not service-level
2. Missing dead letter queue and poison message handling
3. No health checks for MQTT broker or Kinesis stream
4. Deployment strategy lacks automated rollback triggers
5. Database migration backward compatibility not enforced

### Moderate Issues Identified: 5
1. No SLO/SLA definitions or error budgets
2. Missing distributed tracing for end-to-end request flows
3. No capacity planning or load testing results
4. No incident response runbooks or on-call procedures
5. Missing resource quotas and cost controls

### Strengths Recognized
- Explicit RPO/RTO targets with backup strategy
- Blue-green deployment and canary releases planned
- Read replicas for analytics workload separation
- Cross-region DR configuration (active-passive)
- Rate limiting at API Gateway
- Retry logic with exponential backoff for database queries

### Recommended Next Steps
1. **Immediate (Before Launch)**: Address C1-C5 (critical issues), especially transaction boundaries and idempotency
2. **Short-term (First Quarter)**: Address S1-S5 (significant issues), focus on automated rollback and service-level rate limiting
3. **Medium-term (Second Quarter)**: Address M1-M5 (moderate issues), establish SLOs and runbooks
4. **Continuous**: Test disaster recovery procedures quarterly, maintain error budgets
