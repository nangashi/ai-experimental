# Reliability Design Review: Smart Home Energy Management System

**Review Date**: 2026-02-11
**Reviewer**: Reliability Design Reviewer (v006-variant-explicit-priority)
**Document**: Smart Home Energy Management System - System Design Document

---

## Phase 1: Structural Analysis

### System Components Identified
1. **API Gateway** (Go) - Request routing, JWT validation, rate limiting, WebSocket management
2. **Device Manager** (Go) - Device registration, MQTT command dispatch, state sync, firmware updates
3. **Analytics Engine** (Go) - Data aggregation, ML inference, recommendations, reporting
4. **MQTT Broker** (AWS IoT Core) - Device communication, topic routing, shadow management
5. **Kinesis Stream** - Real-time event ingestion and fanout
6. **PostgreSQL + TimescaleDB** - User data, device registry, time-series sensor data
7. **Redis Cluster** - Real-time device state cache, session management
8. **Mobile/Web Frontend** - React/React Native clients

### Data Flow Paths
1. **Sensor Data Ingestion**: Device → MQTT → Kinesis → TimescaleDB + Redis
2. **Command Execution**: App → API Gateway → Device Manager → MQTT → Device
3. **Analytics Query**: Dashboard → API Gateway → Analytics Engine → TimescaleDB
4. **Predictions**: Analytics Engine → TensorFlow Model → Recommendation API

### External Dependencies
- **AWS IoT Core** (MQTT broker) - Critical path for all device communication
- **AWS Kinesis** - Real-time event streaming backbone
- **AWS EKS** - Kubernetes orchestration platform
- **Third-party services**: OAuth providers, potentially energy market APIs (planned)

### Explicitly Mentioned Reliability Mechanisms
- API rate limiting (1000 req/min per user)
- Database query retry with exponential backoff (3 attempts: 1s, 2s, 4s) - Analytics Engine only
- PostgreSQL read replicas (2 replicas)
- Redis Cluster (3 master + 3 replica)
- Blue-green deployment for API Gateway and backend
- Canary releases for Analytics Engine (10% → 50% → 100%)
- Database migrations with backward compatibility
- Daily PostgreSQL backups + WAL archiving
- Redis RDB snapshots (6 hours)
- RPO: 1 hour, RTO: 4 hours
- Cross-region DR (us-east-1 primary, us-west-2 passive)
- Auto-scaling via Kubernetes HPA (70% CPU target)

---

## Phase 2: Problem Detection

### Tier 1 - Critical Issues

#### Critical Issue #1: Distributed Transaction Consistency Gap in Command Execution Path

**Problem Description**
The device command execution flow (`device_commands` table → MQTT publish → device acknowledgment) lacks distributed transaction coordination. The design shows:
- Command records created in PostgreSQL with `status='pending'`
- MQTT message published independently
- Acknowledgment timestamp (`acked_at`) updated separately

This creates multiple failure scenarios:
1. Command written to DB, but MQTT publish fails → orphaned "pending" commands
2. MQTT publish succeeds, but DB update fails → duplicate command execution on retry
3. Network partition between Device Manager and PostgreSQL during acknowledgment → inconsistent state

**Impact Analysis**
- **Data Consistency**: Command log becomes unreliable audit trail, regulatory compliance risk for energy management systems
- **User Experience**: Commands appear "stuck" in pending state, users retry → duplicate device actions (e.g., HVAC turned off twice)
- **Operational Complexity**: Manual reconciliation required, no clear recovery path documented

**Referenced Design Section**
- Section 4: `device_commands` table schema (lines 150-161)
- Section 3: Data Flow #2 (line 104)
- Section 6: Error Handling - "Device Manager logs all MQTT publish failures" (line 218)

**Actionable Countermeasures**
1. **Implement Transactional Outbox Pattern**:
   - Add `outbox_events` table in PostgreSQL
   - Write command + outbox event atomically in single transaction
   - Separate outbox processor polls table and publishes to MQTT
   - Mark events as published only after MQTT broker confirms

2. **Add Idempotency Keys**:
   - Include `command_id` (UUID) in MQTT payload
   - Device stores last 1000 executed command IDs in local cache
   - Reject duplicate commands based on ID match

3. **Implement Command Reconciliation**:
   - Background job scans `pending` commands older than 5 minutes
   - Query device shadow in AWS IoT Core for actual state
   - Mark stale commands as `failed` or `timeout`
   - Alert on-call engineer if reconciliation rate exceeds 1% of total commands

---

#### Critical Issue #2: No Circuit Breaker for Critical External Dependencies

**Problem Description**
The design lacks circuit breaker patterns for critical external dependencies:

1. **AWS IoT Core (MQTT Broker)**: Device Manager directly publishes to MQTT without failure isolation. If IoT Core experiences partial outage or rate limiting, the Device Manager will experience thread pool exhaustion from blocked MQTT publish calls.

2. **AWS Kinesis**: Real-time ingestion path has no documented circuit breaker. If Kinesis experiences backpressure (shard throughput exceeded), upstream MQTT bridge will accumulate unbounded buffered events, leading to memory exhaustion.

3. **PostgreSQL Primary**: Analytics Engine queries hit primary database without circuit breaker. Slow queries or connection pool exhaustion cascades to all API Gateway requests waiting for analytics responses.

**Impact Analysis**
- **Cascading Failures**: Single dependency failure (e.g., Kinesis shard iterator timeout) propagates to all dependent services
- **Resource Exhaustion**: Thread pools, memory, and connection pools exhausted waiting for unresponsive dependencies
- **Extended Outage**: Recovery requires manual intervention (service restarts) instead of automatic failure isolation
- **Blast Radius**: Entire system becomes unavailable even when most components are healthy

**Referenced Design Section**
- Section 3: System Components and Data Flow (lines 49-106)
- Section 6: Error Handling - only mentions Analytics Engine DB retry, no circuit breakers (lines 217-219)

**Actionable Countermeasures**
1. **Implement Circuit Breakers Using go-resilience or hystrix-go**:
   - **AWS IoT Core**: 5-second timeout, open circuit after 50% failure rate over 10 requests, half-open after 30 seconds
   - **Kinesis**: 10-second timeout, open after 3 consecutive failures, half-open after 60 seconds
   - **PostgreSQL**: 5-second query timeout, open circuit after 40% failure rate over 20 queries

2. **Add Bulkhead Isolation**:
   - Separate goroutine pools for MQTT publish (100 workers), Kinesis ingestion (50 workers), DB queries (200 workers)
   - Limit blast radius to specific functionality, prevent cross-contamination

3. **Define Graceful Degradation**:
   - **MQTT circuit open**: Buffer commands in PostgreSQL `outbox_events`, retry when circuit closes
   - **Kinesis circuit open**: Fallback to direct TimescaleDB write (slower path), log backlog for later replay
   - **PostgreSQL primary circuit open**: Route analytics queries to read replicas, accept stale data (document staleness SLA)

4. **Expose Circuit Breaker Metrics**:
   - Prometheus metrics: `circuit_breaker_state{service="mqtt"}` (closed/open/half-open)
   - Alert when circuit remains open for >5 minutes

---

#### Critical Issue #3: Backup Recovery Path Not Tested

**Problem Description**
The design specifies PostgreSQL backup strategy (daily full + WAL archiving, 30-day retention) and DR metrics (RPO: 1 hour, RTO: 4 hours), but contains no evidence of tested recovery procedures:

- No mention of **Point-in-Time Recovery (PITR)** testing schedule
- No validation that WAL replay actually achieves 1-hour RPO
- No documented runbook for failover to us-west-2 DR region
- No mention of backup verification (corrupted backups discovered only during emergency)
- Redis RDB snapshots mentioned but no recovery procedure documented

**Impact Analysis**
- **Unrecoverable Data Loss**: Untested backups may be corrupted, incomplete, or incompatible with production schema
- **RTO Violation**: Actual recovery time unknown, 4-hour RTO likely unachievable without practiced procedures
- **Regulatory Risk**: Energy management systems may face compliance requirements for data retention/recovery
- **Business Continuity**: Home automation unavailable during extended outage = safety risk (HVAC, security systems)

**Referenced Design Section**
- Section 7: Disaster Recovery (lines 261-264)
- Section 7: Availability & Scalability - Cross-region failover (line 258)

**Actionable Countermeasures**
1. **Implement Quarterly DR Drills**:
   - **Full Recovery Test**: Restore production-sized dataset from S3 backup to staging environment
   - **PITR Validation**: Test recovery to specific timestamp (simulate 30-minute-old data loss)
   - **Measure Actual RTO**: Document time from "initiate recovery" to "service restored"
   - **Verify Data Integrity**: Run checksum validation on restored data, compare row counts with production

2. **Automate Backup Verification**:
   - Daily automated restore of latest backup to ephemeral test database
   - Run smoke test queries (count tables, validate schema, check latest timestamp)
   - Alert if restore fails or data integrity check fails

3. **Document Failover Runbooks**:
   - **PostgreSQL Failover**: Step-by-step procedure to promote us-west-2 replica to primary
   - **DNS Cutover**: Update Route53 records to point API Gateway to DR region
   - **Data Synchronization**: Procedure to sync back to us-east-1 after primary region recovery
   - **Redis Recovery**: Document procedure to restore from RDB snapshot (including cache warming strategy)

4. **Add Backup Monitoring**:
   - Alert if WAL archiving to S3 is delayed >15 minutes (indicates RPO violation risk)
   - Alert if daily full backup fails or exceeds expected duration
   - Track backup size growth trend (detect anomalies)

---

#### Critical Issue #4: No Conflict Resolution Strategy for Eventual Consistency

**Problem Description**
The design uses Redis Cluster for real-time device state cache (3 master + 3 replica) but does not address conflict resolution for eventual consistency scenarios:

1. **Concurrent Command Execution**: User issues command via mobile app, property manager issues conflicting command via web dashboard simultaneously
   - Both writes hit different Redis master nodes
   - No vector clocks, no last-write-wins timestamp, no conflict detection

2. **Cache-DB Divergence**: Device state updated in Redis but TimescaleDB write fails
   - API returns "device on" from Redis cache
   - Analytics query shows "device off" from PostgreSQL
   - No reconciliation mechanism documented

3. **Network Partition**: Redis cluster experiences split-brain during network partition
   - Different replicas accept conflicting writes
   - Cluster merge after partition → which state wins?

**Impact Analysis**
- **Data Integrity**: Source of truth becomes ambiguous, analytics/billing calculations incorrect
- **User Trust**: Mobile app shows different state than web dashboard
- **Operational Impact**: Energy optimization algorithms make wrong decisions based on stale/incorrect cache data
- **Debugging Difficulty**: Inconsistent state makes troubleshooting nearly impossible

**Referenced Design Section**
- Section 2: Databases - Redis 7.0 Cluster (line 31)
- Section 3: Component Responsibilities - Device Manager "Device state synchronization with Redis" (line 83)
- Section 3: Data Flow #1 - "Device → MQTT → Kinesis → TimescaleDB + Redis" (line 103)

**Actionable Countermeasures**
1. **Define Source of Truth**:
   - **PostgreSQL + TimescaleDB** = authoritative source for all device state and commands
   - **Redis** = read-through cache only, never accepts direct writes
   - Update data flow: Device → MQTT → Kinesis → TimescaleDB → Redis cache invalidation

2. **Implement Cache Invalidation Pattern**:
   - After TimescaleDB write succeeds, publish cache invalidation event to Redis
   - Use Redis pub/sub or cache-aside pattern with TTL (e.g., 30 seconds)
   - API reads check cache, on miss fetch from TimescaleDB and populate cache

3. **Add Conflict Detection for Commands**:
   - Implement optimistic locking with `version` column in `device_commands` table
   - Include expected device state in command payload
   - Reject command if actual state doesn't match expected state (return 409 Conflict)

4. **Implement Reconciliation Job**:
   - Hourly background job compares Redis cache with TimescaleDB latest state
   - Log discrepancies to monitoring system
   - Alert if divergence rate exceeds 0.1% of devices
   - Auto-correct cache from DB source of truth

---

### Tier 2 - Significant Issues

#### Significant Issue #1: No Dead Letter Queue for Unprocessable Kinesis Events

**Problem Description**
The Kinesis → TimescaleDB ingestion pipeline lacks dead letter queue (DLQ) handling for poison messages:

- Malformed sensor data from buggy device firmware blocks Kinesis consumer
- No documented retry logic or error handling for deserialization failures
- Failed events are either lost (if consumer skips) or cause infinite retry (if consumer crashes)
- No quarantine mechanism to isolate bad messages for offline analysis

**Impact Analysis**
- **Data Loss**: Valid events behind poison message are never processed (head-of-line blocking)
- **Consumer Crash Loop**: Kinesis consumer repeatedly fails on same message, prevents processing of entire shard
- **Delayed Detection**: No visibility into message processing failures, silent data loss
- **Root Cause Analysis Difficulty**: Cannot inspect original malformed payload to fix device firmware bug

**Referenced Design Section**
- Section 3: Data Flow #1 - "Device → MQTT → Kinesis → TimescaleDB + Redis" (line 103)
- Section 3: Kinesis Stream responsibilities (lines 97-99)

**Actionable Countermeasures**
1. **Implement DLQ with SQS**:
   - After 3 failed deserialization/processing attempts, publish message to SQS DLQ
   - Include metadata: original Kinesis sequence number, error message, timestamp, device_id
   - Configure SQS message retention: 14 days

2. **Add Poison Message Detection**:
   - Identify messages causing repeated failures (same sequence number retried >3 times)
   - Automatically quarantine to DLQ after threshold
   - Continue processing subsequent messages (prevent shard starvation)

3. **Build DLQ Monitoring Dashboard**:
   - Grafana panel showing DLQ depth over time
   - Alert if DLQ receives >100 messages/hour (indicates widespread device firmware issue)
   - Group alerts by `device_type` to identify problematic device models

4. **Create Replay Mechanism**:
   - Admin API endpoint to replay messages from DLQ after fix deployed
   - Include manual review step to validate message before replay
   - Log all replayed messages for audit trail

---

#### Significant Issue #2: Single Point of Failure - Device Manager Component

**Problem Description**
The Device Manager is a critical component in the command execution path (App → API Gateway → **Device Manager** → MQTT → Device), but the design does not specify:

- Redundancy/replication strategy for Device Manager instances
- Leader election mechanism if multiple instances deployed
- State coordination for in-flight commands during instance failure
- How API Gateway routes requests to Device Manager (single instance vs load-balanced pool)

If Device Manager is a single Kubernetes pod:
- Pod crash → all device commands fail until pod restarts (30-60s minimum)
- Deployment/update → service downtime during rolling update
- Node failure → longer recovery time (pod reschedule + readiness probe)

**Impact Analysis**
- **Service Unavailability**: Home automation commands (HVAC, security, lighting) unavailable during Device Manager outage
- **User Frustration**: Mobile app commands timeout without explanation
- **Safety Risk**: Cannot control critical systems (HVAC failure in extreme weather)
- **Competitive Disadvantage**: 99.9% uptime SLA requires <8.76 hours downtime/year, single SPOF makes this unachievable

**Referenced Design Section**
- Section 3: Component Responsibilities - Device Manager (lines 80-84)
- Section 3: Data Flow #2 (line 104)
- Section 6: Deployment - Rolling updates with readiness probes (line 235)

**Actionable Countermeasures**
1. **Deploy Device Manager as Stateless Replicas**:
   - Kubernetes Deployment with `replicas: 3` minimum
   - Load balanced via Kubernetes Service (ClusterIP)
   - API Gateway uses service DNS for routing (no sticky sessions needed)

2. **Externalize Command State**:
   - Remove in-memory tracking of pending commands
   - Use PostgreSQL `device_commands` table as single source of truth
   - Each Device Manager instance polls outbox table independently (no coordination required)

3. **Implement Anti-Affinity Rules**:
   - Spread Device Manager pods across availability zones
   - Use Kubernetes pod anti-affinity to prevent co-location on same node
   - Ensure at least 1 instance survives zone/node failure

4. **Add Health Checks**:
   - **Liveness probe**: HTTP `/healthz` endpoint (basic process health)
   - **Readiness probe**: Check MQTT broker connectivity + PostgreSQL connection pool health
   - Fail readiness if dependency unavailable (remove pod from load balancer rotation)

5. **Test Failure Scenarios**:
   - Chaos engineering: Randomly kill Device Manager pods during load test
   - Verify zero dropped commands (all retried successfully)
   - Measure maximum command latency spike during pod restart

---

#### Significant Issue #3: Database Schema Backward Compatibility Not Enforced

**Problem Description**
The design mentions "Flyway with backward-compatible schema changes" but does not specify:

- **Compatibility validation**: How is backward compatibility verified before deployment?
- **Rolling update contract**: What schema changes are safe during blue-green/canary deployment?
- **Failure scenarios**: What happens if new code deployed but migration fails mid-flight?

Example risky scenario:
1. Canary deployment adds required `NOT NULL` column to `devices` table
2. Old API Gateway instances (90% of traffic) write new device records without the column → constraint violation
3. Migration rollback difficult (data already written with new schema assumptions)

**Impact Analysis**
- **Deployment Failure**: Schema migration failure mid-deployment causes partial outage
- **Data Corruption**: Incompatible schema + code versions write invalid data
- **Rollback Complexity**: Cannot rollback code without also rolling back schema (high risk operation)
- **Extended Downtime**: Failed deployment requires manual intervention to reconcile schema state

**Referenced Design Section**
- Section 6: Deployment - "Database migrations: Flyway with backward-compatible schema changes" (line 235)

**Actionable Countermeasures**
1. **Adopt Expand-Contract Migration Pattern**:
   - **Phase 1 (Expand)**: Add new column as nullable, deploy code that writes both old+new columns
   - **Phase 2 (Migrate)**: Backfill data, add constraints after all code deployed
   - **Phase 3 (Contract)**: Remove old column in subsequent release

2. **Automated Compatibility Validation**:
   - CI/CD pipeline runs compatibility check:
     - Spin up old code version against new schema
     - Spin up new code version against old schema
     - Run integration test suite for both combinations
   - Block deployment if either direction fails

3. **Schema Change Checklist**:
   - Document prohibited changes during rolling update:
     - ❌ Adding required columns
     - ❌ Renaming columns (requires two-phase deployment)
     - ❌ Changing column types (incompatible with old code)
     - ✅ Adding nullable columns
     - ✅ Adding indexes (online DDL)
     - ✅ Adding new tables

4. **Migration Observability**:
   - Flyway migration logs published to CloudWatch
   - Alert on migration failure with automatic rollback trigger
   - Track migration duration (alert if exceeds baseline by 2x, indicates lock contention)

---

#### Significant Issue #4: No Rate Limiting for MQTT Device Commands (Abuse Prevention)

**Problem Description**
The API Gateway implements rate limiting for user requests (1000 req/min per user), but there is no rate limiting documented for device command dispatch:

- Malicious user could script rapid-fire commands to MQTT broker via API
- Buggy mobile app could send duplicate commands in tight loop
- Compromised user account could overwhelm device with commands (DoS attack on home network)
- AWS IoT Core has undocumented rate limits → sudden throttling without backpressure handling

**Impact Analysis**
- **Device Stability**: Consumer IoT devices (smart plugs, thermostats) have limited processing capacity, command flood causes firmware crash or network stack exhaustion
- **MQTT Broker Overload**: AWS IoT Core throttles account, affecting all users system-wide
- **Cost Spike**: AWS IoT Core charges per message published, runaway command loop = unexpected bill
- **User Safety**: Rapid HVAC/lighting commands cause physical wear on devices, potential safety hazard

**Referenced Design Section**
- Section 3: API Gateway responsibilities - "Rate limiting for API endpoints (1000 req/min per user)" (line 77)
- Section 3: Device Manager - "Command dispatch to IoT devices via MQTT" (line 82)

**Actionable Countermeasures**
1. **Implement Device-Level Rate Limiting**:
   - Redis-based sliding window rate limiter: 10 commands per device per minute
   - Return `429 Too Many Requests` when limit exceeded
   - Include `Retry-After` header with seconds until quota resets

2. **Add Command Deduplication Window**:
   - Track recent command hashes (type + payload) in Redis with 10-second TTL
   - Reject duplicate commands within window (idempotency protection)
   - Useful for mobile app retry logic gone wrong

3. **Implement Token Bucket for Burst Tolerance**:
   - Allow burst of 5 commands immediately, then 1 command every 6 seconds
   - Accommodates legitimate use cases (user adjusts thermostat multiple times while finding comfortable setting)

4. **Monitor MQTT Publish Rate**:
   - Prometheus metric: `mqtt_commands_published_total{device_type, user_id}`
   - Alert if any single device exceeds 100 commands/hour
   - Dashboard showing top 10 "chattiest" devices for anomaly detection

---

### Tier 3 - Moderate Issues

#### Moderate Issue #1: No SLO/SLA Definitions with Error Budgets

**Problem Description**
The design specifies raw performance goals (p95 API latency <200ms, 99.9% uptime) but lacks SLO/SLA framework:

- No definition of **SLI (Service Level Indicators)** being measured
- No **error budget** policy (how much failure is acceptable before deployment freeze?)
- No distinction between internal SLOs and customer-facing SLAs
- No tiered SLA for different subscription tiers (mentioned "subscription_tier" in DB schema but no reliability differentiation)

**Impact Analysis**
- **Lack of Accountability**: Engineering team has no clear reliability target to optimize for
- **Deployment Risk**: No quantitative criteria for rolling back canary deployment
- **Customer Expectations**: Users don't know what reliability to expect (especially "free" tier vs paid)
- **Toil Accumulation**: Without error budget, teams over-invest in reliability at expense of feature development

**Referenced Design Section**
- Section 7: Performance Goals (lines 240-244)
- Section 7: Availability & Scalability - "Target uptime: 99.9%" (line 254)
- Section 4: User schema - `subscription_tier` column (line 119)

**Actionable Countermeasures**
1. **Define SLIs for Core User Journeys**:
   - **Device Command Success Rate**: % of commands successfully executed within 500ms
   - **Real-time Data Freshness**: % of devices with state updated within 60 seconds
   - **API Availability**: % of requests returning non-5xx status codes
   - **Analytics Query Latency**: % of queries completing within 2 seconds

2. **Establish SLO Targets by Subscription Tier**:
   - **Free Tier**: 99.0% availability (87.6 hours downtime/year), p95 latency <1s
   - **Premium Tier**: 99.9% availability (8.76 hours downtime/year), p95 latency <200ms
   - **Enterprise Tier**: 99.95% availability (4.38 hours downtime/year), p95 latency <100ms

3. **Implement Error Budget Policy**:
   - **100% of error budget remaining**: Normal feature development velocity
   - **<50% remaining**: Freeze on risky features, focus on reliability improvements
   - **Exhausted**: Deploy freeze, all hands on reliability remediation
   - Burn rate alerting: Alert if error budget will be exhausted in <7 days at current rate

4. **Publish Customer-Facing SLA**:
   - Document uptime commitments with financial credits for breaches
   - Monthly SLA report published to enterprise customers
   - Transparent incident postmortems for all SLA violations

---

#### Moderate Issue #2: No Capacity Planning or Resource Quotas

**Problem Description**
The design mentions auto-scaling (Kubernetes HPA at 70% CPU) and load testing (10,000 concurrent users) but lacks capacity planning:

- No documented **resource quotas** per user/home (prevent single user from exhausting system)
- No **shard/partition strategy** for TimescaleDB as data grows (what happens at 1 billion rows?)
- No **Kinesis shard capacity calculation** (100,000 events/sec target, but how many shards required?)
- No **connection pool sizing** documented (PostgreSQL max_connections, Redis connection limits)

**Impact Analysis**
- **Resource Exhaustion**: Single high-traffic user (e.g., property management company with 1000 homes) starves other users
- **Performance Degradation**: TimescaleDB queries slow down as hypertable grows without partition pruning strategy
- **Unexpected Throttling**: Kinesis shard throughput exceeded during peak usage (evenings when everyone adjusts HVAC)
- **Database Connection Exhaustion**: Connection pool starvation during traffic spike

**Referenced Design Section**
- Section 7: Performance Goals - "100,000 events/second via Kinesis" (line 243)
- Section 7: Scalability - "Kubernetes HPA based on CPU utilization (target 70%)" (line 255)
- Section 6: Testing - "Load testing: k6 for API endpoints (target: 10,000 concurrent users)" (line 230)

**Actionable Countermeasures**
1. **Define Resource Quotas by Tier**:
   - **Free Tier**: 5 devices, 1000 API calls/hour, 30 days data retention
   - **Premium Tier**: 20 devices, 10,000 API calls/hour, 90 days retention
   - **Enterprise Tier**: Unlimited devices, 100,000 API calls/hour, 1 year retention
   - Enforce in API Gateway middleware, return `429` when exceeded

2. **Design TimescaleDB Partition Strategy**:
   - Partition energy_consumption hypertable by time (1-week chunks)
   - Auto-drop chunks older than retention policy
   - Calculate storage growth: 100,000 events/sec × 100 bytes/event × 86400 sec/day = 864 GB/day
   - Size S3 archival for compressed historical data (Parquet format)

3. **Calculate Kinesis Shard Capacity**:
   - 1 shard = 1 MB/sec ingest, 1000 records/sec
   - 100,000 events/sec ÷ 1000 = 100 shards minimum
   - Configure auto-scaling: target 70% utilization, scale out when exceeded
   - Cost analysis: 100 shards × $0.015/hour = $36/hour = $26k/month (validate business case)

4. **Size Connection Pools**:
   - **PostgreSQL**: `max_connections=500`, split across services:
     - API Gateway: 200 connections
     - Device Manager: 150 connections
     - Analytics Engine: 100 connections
     - Background jobs: 50 connections
   - **Redis**: 1000 max connections per node, 10 connections per service instance
   - Load test to validate pool sizing under peak load

---

#### Moderate Issue #3: No Incident Response Runbooks or Escalation Procedures

**Problem Description**
The design includes monitoring infrastructure (Prometheus + Grafana) and mentions CloudWatch logging, but does not specify:

- **Incident response runbooks** for common failure scenarios (DB failover, Kinesis backlog, Redis cluster split-brain)
- **On-call rotation** and escalation policies
- **Incident severity classification** (SEV0, SEV1, SEV2 definitions)
- **Blameless postmortem process** for production outages
- **Customer communication plan** during major incidents

**Impact Analysis**
- **Slow MTTR (Mean Time To Recovery)**: On-call engineer unfamiliar with system spends 30 minutes finding right runbook
- **Escalation Delays**: No clear policy on when to escalate to senior engineers/management
- **Recurring Incidents**: No postmortem process means same failures repeat
- **User Frustration**: No status page or communication during outages

**Referenced Design Section**
- Section 2: Monitoring - "Prometheus + Grafana" (line 38)
- Section 6: Logging - "Centralized logging via CloudWatch Logs" (line 224)
- Section 7: Disaster Recovery mentions RTO but no operational procedures (lines 261-264)

**Actionable Countermeasures**
1. **Create Incident Response Runbooks**:
   - **PostgreSQL Primary Failure**: Step-by-step failover to DR region, DNS cutover, replication lag check
   - **Kinesis Consumer Lag Spike**: Identify slow consumer, scale out processing, enable enhanced fanout
   - **Redis Cluster Split-Brain**: Detect conflicting masters, force quorum election, resync replicas
   - **MQTT Broker Throttling**: Check AWS IoT Core limits, identify top publishers, enable backpressure
   - Store runbooks in Git-versioned repository, link from Grafana dashboard alerts

2. **Define Incident Severity Levels**:
   - **SEV0 (Critical)**: Complete service outage, affects all users, revenue impact >$10k/hour
   - **SEV1 (High)**: Major functionality unavailable (device commands fail), affects >50% users
   - **SEV2 (Medium)**: Degraded performance (slow analytics queries), affects <50% users
   - **SEV3 (Low)**: Minor issues, no user impact, can wait for business hours

3. **Establish On-Call Rotation**:
   - Follow-the-sun rotation across 3 time zones
   - Primary on-call: Acknowledges alert within 5 minutes, resolves within SLA
   - Secondary on-call: Escalation after 15 minutes if primary non-responsive
   - Manager escalation: SEV0 incidents or unresolved SEV1 after 1 hour
   - Use PagerDuty or Opsgenie for automated escalation

4. **Implement Blameless Postmortem Process**:
   - Required for all SEV0/SEV1 incidents
   - Template: Timeline, Root Cause, Impact, Action Items (with owners + due dates)
   - Review in weekly team meeting
   - Track action item completion rate (target: 90% completed within 30 days)

---

#### Moderate Issue #4: No Distributed Tracing Implementation Details

**Problem Description**
The design mentions "correlation IDs for distributed tracing" in logging section but lacks implementation specifics:

- No tracing framework specified (Jaeger, Zipkin, AWS X-Ray?)
- No propagation mechanism for trace context across service boundaries (HTTP headers, MQTT message properties?)
- No sampling strategy (100% sampling = massive overhead, 1% sampling = miss rare bugs)
- No integration with frontend (React/React Native) for end-to-end traces

**Impact Analysis**
- **Debugging Difficulty**: Cannot trace user request across API Gateway → Device Manager → MQTT → Device
- **Performance Troubleshooting**: Cannot identify which service in call chain is slow during latency spike
- **Incomplete Traces**: Trace context lost at MQTT boundary, async Kinesis processing not linked to original request
- **Monitoring Overhead**: 100% sampling generates excessive data volume, increases infrastructure cost

**Referenced Design Section**
- Section 6: Logging - "Structured JSON logging with correlation IDs for distributed tracing" (line 222)

**Actionable Countermeasures**
1. **Adopt AWS X-Ray for Tracing**:
   - Native integration with AWS services (EKS, IoT Core, Kinesis)
   - Use X-Ray SDK for Go (instrument HTTP handlers, MQTT publish, DB queries)
   - Annotate traces with custom metadata: `user_id`, `device_id`, `command_type`

2. **Implement Trace Context Propagation**:
   - **HTTP**: Inject `X-Amzn-Trace-Id` header in API Gateway, extract in Device Manager
   - **MQTT**: Add trace context to MQTT message payload (e.g., `{"trace_id": "...", "span_id": "...", "data": {...}}`)
   - **Kinesis**: Include trace context in event metadata, link async processing to parent span

3. **Configure Intelligent Sampling**:
   - **Head-based sampling**: 5% of all requests (cost control)
   - **Tail-based sampling**: 100% of failed requests (capture all errors)
   - **Priority sampling**: 100% of device commands (critical path)
   - Adjust sampling rates based on traffic volume and storage costs

4. **Frontend Integration**:
   - React: Use `aws-xray-sdk-browser` to trace API calls from web dashboard
   - React Native: Integrate mobile SDK to trace end-to-end user journey (button tap → device state change)
   - Link frontend span ID to backend trace ID via HTTP header

---

## Verification Summary

### Tier 1 - Critical Issues: 4 identified (minimum 2 required) ✓
1. Distributed transaction consistency gap in command execution path
2. No circuit breaker for critical external dependencies
3. Backup recovery path not tested
4. No conflict resolution strategy for eventual consistency

### Tier 2 - Significant Issues: 4 identified (minimum 2 required) ✓
1. No dead letter queue for unprocessable Kinesis events
2. Single point of failure - Device Manager component
3. Database schema backward compatibility not enforced
4. No rate limiting for MQTT device commands (abuse prevention)

### Tier 3 - Moderate Issues: 4 identified (minimum 2 required) ✓
1. No SLO/SLA definitions with error budgets
2. No capacity planning or resource quotas
3. No incident response runbooks or escalation procedures
4. No distributed tracing implementation details

**All mandatory reporting requirements satisfied.**

---

## Checklist Patterns Verified as Acceptable

The following patterns from the Critical Reliability Patterns Checklist were found to be adequately addressed in the design:

### Tier 1 Patterns - Acceptable
- **Timeout configurations**: Implicitly covered by circuit breaker recommendations, though not explicitly documented in original design
- **Graceful degradation**: Covered by circuit breaker countermeasures

### Tier 2 Patterns - Acceptable
- **Retry with exponential backoff**: Analytics Engine implements 3 retries with 1s, 2s, 4s backoff (Section 6, line 219)
- **Rate limiting (API level)**: API Gateway rate limits user requests at 1000 req/min (Section 3, line 77)
- **Health checks**: Kubernetes readiness probes mentioned (Section 6, line 235)
- **Zero-downtime deployment**: Blue-green strategy for API/backend, canary for Analytics Engine (Section 6, lines 233-236)

### Tier 3 Patterns - Acceptable
- **Log aggregation and correlation IDs**: Structured JSON logging with correlation IDs via CloudWatch (Section 6, lines 222-224)
- **Configuration as code**: Kubernetes with Helm charts (Section 2, line 39)
- **RED metrics foundation**: Prometheus + Grafana monitoring infrastructure in place (Section 2, line 38)

---

## Summary

This reliability review identified **12 significant issues** across all severity tiers in the Smart Home Energy Management System design. The most critical gaps are:

1. **Distributed consistency**: No transactional coordination for command execution, no conflict resolution for eventual consistency
2. **Failure isolation**: Missing circuit breakers for AWS IoT Core, Kinesis, and PostgreSQL dependencies
3. **Operational readiness**: Untested backup recovery, missing incident response procedures, no SLO/error budget framework
4. **Resilience patterns**: No dead letter queue, SPOF in Device Manager, insufficient rate limiting for device commands

The design demonstrates good awareness of some reliability concerns (blue-green deployment, read replicas, DR region), but lacks depth in distributed system resilience patterns critical for a production IoT system managing home automation and energy systems where failures can have safety implications.

**Recommended Priority**: Address all 4 Tier 1 critical issues before production launch, implement Tier 2 significant issues during initial operational period, and adopt Tier 3 moderate improvements within first 6 months of operation.
