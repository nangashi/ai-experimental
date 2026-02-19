# Answer Key - Round 006

## Execution Conditions
- **Observation Perspective**: reliability (信頼性・運用性)
- **Target**: design
- **Embedded Problems**: 10 issues

## Embedded Problem List

### P01: MQTT Broker Fault Isolation Missing
- **Category**: Fault Recovery Design
- **Severity**: Critical
- **Location**: Section 3 (Architecture Design) + Section 5 (API Design)
- **Problem Description**: The Device Manager sends commands to devices via MQTT (AWS IoT Core) without circuit breaker, retry policy, or timeout configuration. When MQTT broker experiences partial failures or high latency, commands can fail silently or hang indefinitely. There's no fallback mechanism or DLQ (Dead Letter Queue) for failed command delivery. This is a critical fault isolation boundary issue—MQTT should be treated as an unreliable external dependency with explicit resilience patterns.
- **Detection Criteria**:
  - ○ (Detected): Points out the lack of circuit breaker, timeout configuration, or retry strategy for MQTT command publishing; OR identifies the absence of DLQ/fallback handling for failed device commands; OR notes the risk of command loss or indefinite hang when MQTT broker is degraded
  - △ (Partial): Mentions general fault recovery concerns for external services but doesn't specifically address MQTT command publishing resilience
  - × (Undetected): No mention of MQTT fault isolation or command delivery resilience

### P02: Kinesis-TimescaleDB Pipeline Data Consistency Gap
- **Category**: Data Integrity & Idempotency
- **Severity**: Critical
- **Observation**: The data flow describes "Device → MQTT → Kinesis → TimescaleDB + Redis" but provides no specification for guaranteed delivery semantics, idempotency handling, or consistency boundaries. Kinesis consumers can experience:
  1. Duplicate message delivery (at-least-once semantics)
  2. Message ordering issues across shards
  3. Consumer failures mid-processing (partial writes to TimescaleDB)
  4. Clock skew between device timestamps and ingestion timestamps

Without explicit handling (e.g., upsert with unique constraint, deduplication keys, transaction boundaries), duplicate sensor data or data loss can occur during pipeline failures or consumer restarts.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of idempotency handling or deduplication strategy for Kinesis → TimescaleDB ingestion; OR notes the risk of duplicate sensor data writes; OR points out missing transaction/consistency boundaries in the streaming pipeline
  - △ (Partial): Mentions data consistency concerns for real-time ingestion but doesn't specifically address idempotency or duplicate handling in the Kinesis consumer
  - × (Undetected): No mention of data consistency or idempotency in the streaming pipeline

### P03: Device Command Retry Without Idempotency Design
- **Category**: Data Integrity & Idempotency
- **Severity**: Significant
- **Location**: Section 6 (Implementation Strategy - Error Handling) + Section 4 (Data Model - Device Command Log)
- **Problem Description**: The design specifies "Analytics Engine retries failed database queries up to 3 times with exponential backoff" but doesn't address idempotency for device commands. The `device_commands` table tracks command status, but there's no mechanism to prevent duplicate command execution when:
  1. MQTT publish succeeds but ACK is lost
  2. Device receives command but fails to respond (network timeout)
  3. Retry logic re-sends the same command (e.g., "turn on heater" sent 3 times)

For critical operations like firmware updates, power cycling, or thermostat adjustments, duplicate execution can cause safety issues or user experience problems.
- **Detection Criteria**:
  - ○ (Detected): Points out the lack of idempotency design for device command execution; OR identifies the risk of duplicate command delivery due to retry logic without idempotency keys; OR notes the absence of deduplication mechanism in the `device_commands` table
  - △ (Partial): Mentions retry concerns for device commands but doesn't specifically address the need for idempotency or duplicate prevention
  - × (Undetected): No mention of command idempotency or duplicate execution risks

### P04: Cross-Region Failover Coordination Undefined
- **Category**: Availability, Redundancy & DR
- **Severity**: Critical
- **Location**: Section 7 (Non-functional Requirements - Availability & Scalability)
- **Problem Description**: The design specifies "Cross-region failover: Active-passive configuration (primary: us-east-1, DR: us-west-2)" but provides no details on:
  1. Failover trigger conditions (automated vs manual, what metrics indicate primary region failure)
  2. Data replication lag handling (PostgreSQL WAL streaming delay, Redis replication delay)
  3. In-flight transaction handling (API requests in progress during failover)
  4. DNS/load balancer reconfiguration strategy (Route 53 health checks, TTL considerations)
  5. Fallback to primary after recovery (failback plan, data reconciliation)

Without a concrete failover runbook, the stated 99.9% availability (RTO 4 hours) is unachievable. The RPO of 1 hour also conflicts with "continuous WAL archiving" which suggests near-zero data loss capability.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing failover automation details (trigger conditions, orchestration steps, DNS reconfiguration); OR points out the lack of runbook/procedure for executing cross-region failover; OR notes the RPO/RTO inconsistency with stated replication strategy
  - △ (Partial): Mentions general DR concerns or asks about failover testing but doesn't specifically address the lack of failover procedure specification
  - × (Undetected): No mention of cross-region failover coordination or operational procedures

### P05: WebSocket Connection State Recovery Undefined
- **Category**: Fault Recovery Design
- **Severity**: Significant
- **Location**: Section 3 (Architecture Design) + Section 5 (API Design - Real-time Updates)
- **Problem Description**: The API Gateway provides "WebSocket connection management for real-time updates" (`WS /api/v1/stream`) but doesn't specify:
  1. Reconnection strategy when WebSocket disconnects (client-side backoff, server-side session resumption)
  2. Message delivery guarantees (at-most-once, at-least-once)
  3. State synchronization after reconnection (how to catch up on missed events)
  4. Connection heartbeat/keepalive mechanism
  5. Graceful degradation when WebSocket is unavailable (fallback to polling?)

During network interruptions or server restarts, clients can lose real-time updates indefinitely without a recovery mechanism.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing WebSocket reconnection strategy or state recovery mechanism; OR notes the lack of message delivery guarantees for real-time updates; OR points out the absence of catch-up/synchronization logic after disconnection
  - △ (Partial): Mentions WebSocket reliability concerns but doesn't address specific recovery patterns (reconnection, state sync, message guarantees)
  - × (Undetected): No mention of WebSocket fault recovery or connection state management

### P06: Kubernetes HPA Without SLO-Based Alerts
- **Category**: Monitoring & Alerting Design
- **Severity**: Significant
- **Location**: Section 7 (Non-functional Requirements - Availability & Scalability)
- **Problem Description**: The design specifies "Auto-scaling: Kubernetes HPA based on CPU utilization (target 70%)" but doesn't define SLO-based alerting rules. Key gaps:
  1. No SLO/SLA definition for critical user journeys (e.g., "95% of device commands succeed within 500ms")
  2. Monitoring metrics are listed (Prometheus + Grafana) but no alert rules tied to availability targets
  3. CPU-based scaling can miss application-level degradation (e.g., database connection pool exhaustion, memory leaks)
  4. No escalation policy or on-call runbook for alert response

The stated 99.9% uptime target requires proactive monitoring of error budgets and latency SLOs, not just infrastructure metrics.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of SLO/SLA-based alert rules or error budget monitoring; OR identifies the gap between availability target (99.9%) and monitoring strategy (CPU-only HPA); OR notes missing alerting escalation policy or runbook
  - △ (Partial): Mentions monitoring concerns or suggests adding more metrics but doesn't specifically address SLO-based alerting or error budget tracking
  - × (Undetected): No mention of SLO/alerting gaps or operational monitoring strategy

### P07: TimescaleDB Continuous Aggregate Maintenance Window Undefined
- **Category**: Availability, Redundancy & DR
- **Severity**: Moderate
- **Location**: Section 4 (Data Model - Energy Consumption Hypertable)
- **Problem Description**: TimescaleDB hypertables typically use continuous aggregates for efficient historical queries (90-day aggregation as specified). However, the design doesn't address:
  1. Materialized view refresh strategy (real-time vs scheduled, refresh lag)
  2. Query behavior during aggregate refresh (stale data risk, refresh lock impact)
  3. Hypertable chunk retention policy (automatic data deletion for old partitions)
  4. Reindex/vacuum maintenance windows (impact on query performance)

Without explicit aggregate refresh and maintenance planning, the "< 2s for 90-day historical data aggregation" performance goal may degrade over time or cause query inconsistencies.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing continuous aggregate maintenance strategy or refresh policy; OR points out the lack of hypertable chunk retention/archival plan; OR notes potential query consistency issues during aggregate refresh
  - △ (Partial): Mentions TimescaleDB performance concerns or maintenance needs but doesn't specifically address continuous aggregate refresh or retention policies
  - × (Undetected): No mention of TimescaleDB maintenance or aggregate refresh strategy

### P08: PostgreSQL Read Replica Lag Handling Undefined
- **Category**: Fault Recovery Design
- **Severity**: Moderate
- **Location**: Section 7 (Non-functional Requirements - Availability & Scalability)
- **Problem Description**: The design specifies "PostgreSQL read replicas for analytics queries (2 replicas)" but doesn't define:
  1. Acceptable replication lag threshold (seconds? minutes?)
  2. Query routing logic (all analytics queries go to replicas, or only specific types?)
  3. Handling strategy when replica lag exceeds threshold (fallback to primary, reject query, return stale data with warning)
  4. Replica failure scenario (if 1 of 2 replicas fails, does traffic shift to remaining replica or back to primary?)

Analytics queries can return stale or inconsistent data if replica lag is unbounded, especially during high write load or network issues.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing replication lag monitoring or handling strategy; OR points out the lack of query routing policy based on replica health; OR notes potential data staleness issues for analytics queries
  - △ (Partial): Mentions read replica concerns or suggests monitoring replication lag but doesn't address specific handling logic or thresholds
  - × (Undetected): No mention of replication lag or read replica fault handling

### P09: Database Schema Migration Rollback Compatibility Gap
- **Category**: Deployment & Rollback
- **Severity**: Significant
- **Location**: Section 6 (Implementation Strategy - Deployment)
- **Problem Description**: The design specifies "Database migrations: Flyway with backward-compatible schema changes" and "Blue-green deployment strategy" but doesn't define rollback-safe migration patterns. Specifically:
  1. Adding a new NOT NULL column without a default value breaks rollback (old code can't write to new schema)
  2. Renaming columns/tables breaks both forward and backward compatibility unless done in multi-phase migrations
  3. Blue-green deployment assumes both versions can coexist with the same database schema, but Flyway applies migrations immediately (no schema versioning per deployment)

The phrase "backward-compatible schema changes" is vague—it should explicitly require "expand-contract pattern" (additive-only migrations in deploy, remove deprecated columns in later maintenance).
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of explicit expand-contract migration pattern or rollback-safe constraints (e.g., new columns must be nullable/default-valued); OR points out the conflict between blue-green deployment and immediate schema migration application; OR notes the risk of schema incompatibility during rollback
  - △ (Partial): Mentions migration concerns or suggests testing rollback but doesn't specifically address schema compatibility patterns (expand-contract, nullable constraints)
  - × (Undetected): No mention of migration rollback safety or schema compatibility

### P10: Redis Cluster Split-Brain Scenario Unaddressed
- **Category**: Availability, Redundancy & DR
- **Severity**: Moderate
- **Location**: Section 7 (Non-functional Requirements - Availability & Scalability)
- **Problem Description**: The design specifies "Redis Cluster: 3 master + 3 replica nodes" but doesn't address cluster partitioning scenarios:
  1. What happens during network partition (split-brain with multiple masters)?
  2. Redis Cluster's default behavior (majority vote for failover) is mentioned nowhere
  3. No discussion of `cluster-require-full-coverage` setting (default: yes, means cluster is unavailable if any slot is uncovered)
  4. Failover automation vs manual intervention policy
  5. Client-side retry behavior when cluster topology changes (connection pool invalidation, MOVED/ASK redirect handling)

The stated 99.9% availability assumes Redis Cluster is resilient to partial failures, but without explicit failover policies, cache unavailability can cascade to API Gateway failures (if Redis is used for session management).
- **Detection Criteria**:
  - ○ (Detected): Identifies missing Redis Cluster failover policy or split-brain handling; OR points out the lack of `cluster-require-full-coverage` configuration discussion; OR notes the risk of cache unavailability during cluster partitioning
  - △ (Partial): Mentions Redis Cluster resilience concerns but doesn't specifically address split-brain scenarios or failover automation
  - × (Undetected): No mention of Redis Cluster partitioning or failover behavior

## Bonus Problem List

The following are additional issues not included in the answer key. If detected, they will receive bonus points.

| ID | Category | Description | Bonus Condition |
|----|---------|-------------|----------------|
| B01 | Monitoring & Alerting | No incident response runbook or escalation policy defined despite 99.9% uptime SLA | Points out missing operational runbook or on-call procedures for incident response |
| B02 | Fault Recovery Design | Prometheus metrics collection has no failover or HA configuration (single point of failure for observability) | Identifies Prometheus as SPOF or suggests HA setup (Thanos, Cortex, or multi-replica) |
| B03 | Data Integrity | Kinesis shard key strategy undefined—poor key distribution can cause hot shards and uneven processing | Identifies missing shard key design or hot shard risk for Kinesis stream |
| B04 | Availability & DR | RPO of 1 hour conflicts with "continuous WAL archiving" capability—should be near-zero or clarify archival lag | Points out RPO/backup strategy inconsistency |
| B05 | Deployment & Rollback | Canary release for Analytics Engine lacks automated rollback criteria (error rate threshold, performance regression detection) | Identifies missing automated canary evaluation or rollback triggers |
