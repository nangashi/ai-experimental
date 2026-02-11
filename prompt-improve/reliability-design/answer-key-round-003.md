# Answer Key - Round 003

## Execution Context
- **Perspective**: reliability
- **Target**: design
- **Embedded Problems**: 10

## Embedded Problems

### P01: External Service Circuit Breaker Absence
- **Category**: Fault Recovery Design
- **Severity**: Critical
- **Location**: Section 3 (Architecture Design) and Section 5 (API Design)
- **Problem Description**: The design describes integration with external services (Twilio, SendGrid, EHR vendor FHIR APIs) but does not specify circuit breaker patterns or fallback strategies. If Twilio or SendGrid experience outages, the Notification Service will repeatedly attempt to send messages, potentially exhausting connection pools and cascading failures to other system components.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of circuit breaker or fallback mechanisms for external service integrations (Twilio, SendGrid, or EHR APIs) AND explains the risk of cascading failures or resource exhaustion
  - △ (Partial): Mentions general need for fault tolerance in external integrations but does not specifically identify circuit breaker patterns or explain cascading failure risks
  - × (Not Detected): No mention of external service fault recovery mechanisms

### P02: RabbitMQ Message Processing Idempotency Missing
- **Category**: Data Consistency & Idempotency
- **Severity**: Critical
- **Problem Description**: The Notification Service consumes reminder messages from RabbitMQ and retries on failures, but there is no mention of idempotency design or duplicate message detection. If the service crashes after sending an SMS but before acknowledging the message, the same reminder may be sent multiple times to patients.
- **Location**: Section 3 (Reminder Service and Notification Service components)
- **Detection Criteria**:
  - ○ (Detected): Identifies the risk of duplicate reminder deliveries due to message reprocessing after failures AND recommends idempotency mechanisms (deduplication keys, idempotency tokens, or at-most-once delivery guarantees)
  - △ (Partial): Mentions message processing reliability concerns but does not specify idempotency requirements or duplicate detection strategies
  - × (Not Detected): No mention of message idempotency or duplicate delivery risks

### P03: Database Transaction Boundary Unclear for Appointment Booking
- **Category**: Data Consistency & Idempotency
- **Severity**: Critical
- **Problem Description**: The appointment creation flow involves coordination between Appointment Service and Availability Service for conflict detection. The design does not clarify whether these operations occur within a single database transaction or require distributed transaction coordination. Without explicit transaction boundaries, race conditions may allow double-booking when two patients simultaneously request the same time slot.
- **Location**: Section 3 (Appointment Service and Availability Service) and Section 5 (POST /api/v1/appointments)
- **Detection Criteria**:
  - ○ (Detected): Identifies the race condition risk in appointment creation due to unclear transaction boundaries AND recommends explicit transactional isolation strategy (optimistic locking with version field, pessimistic locking, or distributed transaction coordination)
  - △ (Partial): Mentions concurrency concerns in appointment booking but does not specify transaction isolation requirements or double-booking prevention mechanisms
  - × (Not Detected): No mention of transaction boundaries or race condition risks

### P04: EHR Integration Timeout and Retry Strategy Undefined
- **Category**: Fault Recovery Design
- **Severity**: Significant
- **Problem Description**: The EHR Integration Service synchronizes appointment data with external EHR systems on a nightly batch schedule using HL7 FHIR APIs. The design does not specify timeout values, retry strategies, or partial failure handling. If an EHR vendor's API responds slowly or returns transient errors, the batch job may hang indefinitely or fail entirely without processing remaining appointments.
- **Location**: Section 3 (EHR Integration Service)
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of timeout specifications, retry policies, or partial failure recovery for EHR batch synchronization AND recommends explicit timeout values and retry strategies (exponential backoff, maximum retry limits)
  - △ (Partial): Mentions reliability concerns for EHR integration but does not specify timeout or retry requirements
  - × (Not Detected): No mention of EHR integration fault recovery

### P05: Redis Single Point of Failure
- **Category**: Availability & Redundancy
- **Severity**: Significant
- **Problem Description**: The design states "Redis runs in single-instance mode for session storage" in Section 7. If Redis crashes, all active user sessions are lost, forcing re-authentication for all users. Rate limiting counters stored in Redis would also be reset, allowing potential abuse until Redis is restored.
- **Location**: Section 7 (Non-Functional Requirements - Availability)
- **Detection Criteria**:
  - ○ (Detected): Identifies Redis single-instance mode as a single point of failure AND explains the impact on session continuity or rate limiting AND recommends redundancy strategies (Redis Sentinel, Redis Cluster, or graceful degradation without cache)
  - △ (Partial): Mentions Redis availability concerns but does not explain session loss impact or recommend specific redundancy approaches
  - × (Not Detected): No mention of Redis as a single point of failure

### P06: RabbitMQ Queue Overflow Handling Strategy Missing
- **Category**: Fault Recovery Design (Backpressure)
- **Severity**: Significant
- **Problem Description**: The design mentions "Alert when queue size exceeds 10,000 messages" but does not define what happens when the queue continues to grow beyond this threshold. Without backpressure mechanisms or overflow policies (dead letter queues, message TTL, queue size limits), the RabbitMQ broker may exhaust memory and crash during traffic spikes (e.g., mass appointment cancellations triggering waitlist rebookings).
- **Location**: Section 7 (Non-Functional Requirements - Scalability)
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of queue overflow handling policies AND recommends specific backpressure mechanisms (dead letter queues, message TTL, max queue length with reject/drop policies)
  - △ (Partial): Mentions queue monitoring but does not specify overflow handling or backpressure strategies
  - × (Not Detected): No mention of queue overflow risks

### P07: Reminder Service Database Polling Scalability and Fault Recovery Gap
- **Category**: Availability & Redundancy
- **Severity**: Significant
- **Problem Description**: The Reminder Service polls the database every 5 minutes for upcoming appointments. The design does not clarify whether multiple instances of this service can run concurrently (potential duplicate reminders) or if a single instance is a SPOF. Additionally, if the polling service crashes mid-cycle, there is no mention of tracking which reminders were already enqueued, risking skipped or duplicate reminders.
- **Location**: Section 3 (Reminder Service)
- **Detection Criteria**:
  - ○ (Detected): Identifies the concurrency/SPOF ambiguity for the Reminder Service AND the lack of progress tracking for fault recovery AND recommends distributed locking (optimistic locking, leader election) or idempotent reminder generation with deduplication
  - △ (Partial): Mentions Reminder Service reliability concerns but does not address both concurrency and progress tracking aspects
  - × (Not Detected): No mention of Reminder Service fault recovery or concurrency issues

### P08: Database Migration Rollback Plan Undefined
- **Category**: Deployment & Rollback
- **Severity**: Moderate
- **Problem Description**: The design states "Database migrations are executed manually before deployment using Flyway" but does not define rollback procedures if a migration introduces data corruption or schema incompatibility. Without explicit rollback strategies (migration reversal scripts, database snapshots before migration), production incidents may require extended downtime.
- **Location**: Section 6 (Implementation Strategy - Deployment)
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of database migration rollback procedures AND recommends explicit rollback strategies (migration reversal scripts, pre-migration snapshots, backward-compatible schema changes)
  - △ (Partial): Mentions deployment risks but does not specifically address database migration rollback
  - × (Not Detected): No mention of migration rollback concerns

### P09: SLO/SLA Monitoring and Alerting Strategy Incomplete
- **Category**: Monitoring & Alerting
- **Severity**: Moderate
- **Problem Description**: The design defines a target uptime of 99.9% and performance targets (p95 < 500ms for appointment booking) but does not specify how these SLOs are monitored, what thresholds trigger alerts, or what escalation procedures exist when SLO budgets are exhausted. Without SLO-based alerting, the team may only discover degradation through user complaints rather than proactive monitoring.
- **Location**: Section 7 (Non-Functional Requirements - Performance and Availability)
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of SLO-based monitoring and alerting configuration AND recommends specific alert thresholds (error budget burn rate, latency percentile degradation) and escalation policies
  - △ (Partial): Mentions monitoring gaps but does not specify SLO-based alerting or escalation procedures
  - × (Not Detected): No mention of SLO/SLA monitoring strategy

### P10: ECS Task Health Check Configuration Missing
- **Category**: Availability & Redundancy
- **Severity**: Moderate
- **Problem Description**: The design states that ECS tasks run across 2 Availability Zones with horizontal scaling based on CPU utilization, but does not define health check endpoints or failure detection thresholds for replacing unhealthy tasks. If a task enters a degraded state (e.g., database connection pool exhaustion) but still consumes CPU, it will not be replaced, reducing effective capacity.
- **Location**: Section 2 (Infrastructure) and Section 7 (Scalability)
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of ECS task health check configuration AND recommends explicit health check endpoints (e.g., /health) with failure thresholds and replacement policies
  - △ (Partial): Mentions task health concerns but does not specify health check configuration requirements
  - × (Not Detected): No mention of ECS task health checks

## Bonus Problems

Bonus problems are not included in the embedded 10 problems but should be awarded points if detected:

| ID | Category | Description | Bonus Condition |
|----|----------|-------------|-----------------|
| B01 | Monitoring & Alerting | Correlation ID tracing exists but no mention of distributed tracing (e.g., AWS X-Ray) for cross-service request flows (Appointment Service → RabbitMQ → Notification Service → Twilio) | Recommends distributed tracing for end-to-end observability |
| B02 | Availability & Redundancy | PostgreSQL RDS automated backups exist but no mention of cross-region replication or disaster recovery plan for regional failures | Recommends cross-region RDS replicas or DR runbooks |
| B03 | Data Consistency & Idempotency | Optimistic locking version field exists in Appointment table but no mention of how version conflicts are resolved or communicated to users | Recommends retry logic with exponential backoff or user-facing conflict resolution UX |
| B04 | Fault Recovery Design | Blue-green deployment strategy exists but no mention of canary deployments, feature flags, or gradual traffic shifting to detect issues before full rollout | Recommends canary analysis or progressive delivery strategies |
| B05 | Deployment & Rollback | Manual database migrations with Flyway create deployment bottleneck; no mention of zero-downtime migration strategies (expand-contract pattern) | Recommends backward-compatible migrations or blue-green database migration strategies |
