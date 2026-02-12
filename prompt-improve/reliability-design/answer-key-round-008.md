# Answer Key - Round 008

## Execution Conditions
- **Perspective**: reliability
- **Target**: design
- **Embedded Problems**: 9

## Embedded Problem Details

### P01: No circuit breaker for WeatherAPI calls
- **Category**: Fault Recovery Design
- **Severity**: Critical
- **Location**: Section 6 - Implementation Details, Error Handling
- **Problem Description**: The Forecast Service calls WeatherAPI.com with exponential backoff retries (max 3 attempts) but lacks circuit breaker protection. If WeatherAPI experiences prolonged outages or rate limiting, repeated retry attempts from all forecast computation jobs (100 facilities × every 15 minutes) will compound load on the failing service and delay failure detection. Circuit breaker pattern would prevent cascading failures and enable faster graceful degradation.
- **Detection Criteria**:
  - ○ (Detected): Explicitly identifies the absence of circuit breaker for WeatherAPI integration and explains the risk of cascading failures or retry storm scenarios
  - △ (Partial): Mentions need for fault isolation or retry improvements but does not specifically recommend circuit breaker pattern or identify WeatherAPI as critical external dependency requiring protection
  - × (Not Detected): No mention of circuit breaker, fault recovery for external API calls, or retry storm risks

### P02: Missing idempotency design for DR event webhook processing
- **Category**: Data Integrity & Idempotency
- **Severity**: Critical
- **Location**: Section 5 - API Design, Webhook Endpoints
- **Problem Description**: The `/webhooks/utility/dr-notification` endpoint returns 200 immediately for async processing but lacks idempotency guarantees. If the utility grid operator retries the webhook due to network issues or timeout (before seeing 200 response), duplicate DR events could be created, leading to redundant BMS commands (e.g., double load reduction causing facility disruption). The endpoint should implement idempotency key validation (e.g., using event_id from payload) to ensure duplicate webhook deliveries are safely ignored.
- **Detection Criteria**:
  - ○ (Detected): Identifies webhook idempotency concerns, specifically mentioning duplicate delivery risks for DR event processing and need for idempotency key mechanism
  - △ (Partial): Mentions general idempotency concerns or webhook reliability but does not connect to DR event duplication risk or propose specific mitigation (idempotency key validation)
  - × (Not Detected): No mention of webhook idempotency, duplicate delivery handling, or DR event processing risks

### P03: Kafka consumer offset management and exactly-once semantics undefined
- **Category**: Data Integrity & Idempotency
- **Severity**: Critical
- **Location**: Section 3 - Architecture Design, Aggregation Service
- **Problem Description**: The Aggregation Service consumes from Kafka topic `sensor-readings` and writes rollups to InfluxDB, but the design does not specify offset commit strategy or transactional guarantees. If the service crashes after writing to InfluxDB but before committing Kafka offsets, reprocessing the same messages on restart will cause duplicate rollup data. Conversely, committing offsets before InfluxDB write completion risks data loss. The design should specify exactly-once semantics using Kafka transactions or implement idempotent write patterns with deduplication keys in InfluxDB.
- **Detection Criteria**:
  - ○ (Detected): Identifies Kafka consumer offset commit timing and exactly-once semantics concerns, mentioning duplicate data or data loss risks for InfluxDB writes
  - △ (Partial): Mentions Kafka reliability or consumer fault recovery but does not address offset commit coordination with InfluxDB writes or exactly-once processing requirements
  - × (Not Detected): No mention of Kafka consumer offset management, exactly-once semantics, or duplicate/data loss risks

### P04: PostgreSQL single primary instance creates SPOF
- **Category**: Availability & Redundancy
- **Severity**: Significant
- **Location**: Section 7 - Availability & Scalability
- **Problem Description**: The design explicitly states "PostgreSQL: Single primary instance (no read replicas)" while targeting 99.5% uptime and deploying services across 3 availability zones. PostgreSQL failure would cause complete outage of critical features (DR event management, forecast storage, user authentication). The absence of read replicas also eliminates failover capability. For production systems with availability targets, PostgreSQL should use Multi-AZ deployment with automatic failover (e.g., RDS Multi-AZ) or implement read replica promotion procedures.
- **Detection Criteria**:
  - ○ (Detected): Identifies PostgreSQL single primary instance as SPOF, mentioning impact on availability targets and recommending Multi-AZ configuration or read replica failover strategy
  - △ (Partial): Mentions database availability concerns or general SPOF risks but does not specifically call out PostgreSQL single instance or connect to 99.5% uptime target inconsistency
  - × (Not Detected): No mention of PostgreSQL SPOF, database failover, or availability architecture concerns

### P05: No timeout configuration for BMS SOAP API calls
- **Category**: Fault Recovery Design
- **Severity**: Significant
- **Location**: Section 2 - Technology Stack, External Dependencies; Section 6 - Implementation Details
- **Problem Description**: The DR Coordinator sends HVAC/lighting control commands to Building Management System via SOAP API, but the design does not specify timeout values or failure handling. If BMS API becomes unresponsive (network partition, API server overload), DR Coordinator goroutines could hang indefinitely, exhausting connection pools and preventing subsequent DR events from being processed. The design should specify request timeouts (e.g., 5-second connect timeout, 30-second read timeout) and define fallback behavior (log failure, mark event as failed, trigger alert).
- **Detection Criteria**:
  - ○ (Detected): Identifies missing timeout configuration for BMS SOAP API calls, explaining goroutine hang or resource exhaustion risks and recommending specific timeout values
  - △ (Partial): Mentions timeout concerns for external API calls or BMS integration reliability but does not detail resource exhaustion scenario or propose timeout configuration
  - × (Not Detected): No mention of timeout design, BMS API fault handling, or goroutine blocking risks

### P06: InfluxDB write failure handling not defined
- **Category**: Fault Recovery Design
- **Severity**: Significant
- **Location**: Section 3 - Architecture Design, Aggregation Service
- **Problem Description**: The Aggregation Service writes sensor data rollups to InfluxDB every 15 minutes, but the design does not specify behavior when InfluxDB is unavailable or write operations fail (disk full, network timeout, cluster degradation). Critical operational questions are unaddressed: (1) Are failed writes retried? (2) Is data buffered in memory or persisted to dead-letter queue? (3) Does the service block Kafka consumption during InfluxDB outage? Without explicit failure handling design, InfluxDB outages could cause data loss (dropped rollups) or cascading failures (Kafka consumer lag explosion, OOM from unbounded buffering).
- **Detection Criteria**:
  - ○ (Detected): Identifies undefined InfluxDB write failure handling, mentioning specific failure modes (disk full, network timeout) and data loss or buffering risks
  - △ (Partial): Mentions general time-series database reliability or write failure concerns but does not detail specific failure scenarios or propose buffering/retry strategy
  - × (Not Detected): No mention of InfluxDB write failure handling, data loss risks, or Kafka-InfluxDB coordination

### P07: Missing SLO/SLA definitions and alerting thresholds
- **Category**: Monitoring & Alerting
- **Severity**: Significant
- **Location**: Section 7 - Monitoring
- **Problem Description**: The design specifies performance targets (p95 API latency < 500ms, 10,000 readings/sec ingestion) and basic alerts (Kafka lag > 10k, error rate > 5%) but lacks formal SLO/SLA definitions tied to business requirements. Critical gaps: (1) No SLO for DR event processing latency (utility webhook → BMS command completion), (2) No availability measurement methodology (uptime percentage calculation excludes "planned maintenance" but criteria undefined), (3) No alert escalation policy or on-call procedures. Without SLO-driven monitoring, the team cannot distinguish between acceptable degradation and SLA violations requiring immediate response.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing SLO/SLA definitions, specifically mentioning DR event processing latency or availability measurement gaps and need for SLO-based alerting
  - △ (Partial): Mentions general monitoring improvements or alerting gaps but does not connect to SLO/SLA framework or DR event processing criticality
  - × (Not Detected): No mention of SLO/SLA definitions, DR event monitoring, or business-aligned alerting requirements

### P08: Deployment rollback plan lacks data migration compatibility validation
- **Category**: Deployment & Rollback
- **Severity**: Significant
- **Location**: Section 6 - Deployment
- **Problem Description**: The deployment process uses Flyway SQL migrations executed before rolling update, but there is no validation that schema changes are backward-compatible with the previous application version. If a migration adds a non-nullable column without default value (e.g., new column in `load_forecasts` table) and deployment is then rolled back due to application bugs, the old application version will fail when attempting INSERT operations (missing required column). The deployment plan should include: (1) Schema compatibility testing (new schema × old code), (2) Expand-contract migration pattern enforcement, (3) Rollback runbook with database state rollback procedures.
- **Detection Criteria**:
  - ○ (Detected): Identifies schema migration backward compatibility risks for rollback scenarios, mentioning specific failure modes (non-nullable columns, old code × new schema) and recommending expand-contract pattern
  - △ (Partial): Mentions general rollback concerns or database migration risks but does not detail schema compatibility validation or backward compatibility requirements
  - × (Not Detected): No mention of rollback data compatibility, schema migration risks, or deployment backward compatibility

### P09: Redis cache invalidation strategy undefined for forecast updates
- **Category**: Data Integrity & Idempotency
- **Severity**: Moderate
- **Location**: Section 5 - API Design, GET /api/facilities/{facility_id}/current
- **Problem Description**: The `/api/facilities/{facility_id}/current` endpoint caches responses in Redis with 10-second TTL, but the design does not specify cache invalidation strategy when underlying data changes (e.g., InfluxDB receives late-arriving sensor readings with backdated timestamps, forecast model updates historical baseline). Stale cache could display incorrect contract utilization percentage, causing facility operators to miss overload warnings. The design should either: (1) Implement event-driven cache invalidation (pub/sub on data updates), (2) Reduce TTL to acceptable staleness threshold aligned with operational requirements, (3) Document acceptable staleness and display cache timestamp in UI.
- **Detection Criteria**:
  - ○ (Detected): Identifies cache invalidation concerns for real-time data, mentioning stale data risks for operational decisions and proposing event-driven invalidation or TTL tuning
  - △ (Partial): Mentions general caching concerns or data freshness but does not connect to facility monitoring criticality or propose specific invalidation strategy
  - × (Not Detected): No mention of cache invalidation, data staleness, or Redis coordination with InfluxDB updates

## Bonus Problem Candidates

| ID | Category | Content | Bonus Criteria |
|----|---------|---------|----------------|
| B01 | Availability & Redundancy | Multi-AZ deployment for stateless services but no discussion of cross-AZ failure scenarios (entire AZ outage, inter-AZ network partition) and impact on service availability | Identifies need for cross-AZ failure testing or quantifies availability impact of AZ-level failures |
| B02 | Monitoring & Alerting | Prometheus/Grafana monitoring architecture but no mention of monitoring system itself being highly available (Prometheus SPOF, Grafana unavailable during incidents) | Points out monitoring infrastructure SPOF or recommends Prometheus federation/Thanos for HA monitoring |
| B03 | Deployment & Rollback | Rolling update strategy with maxUnavailable:1 but no validation of zero-downtime compatibility (e.g., API contract changes, WebSocket connection handling during pod termination) | Recommends pre-deployment validation of graceful shutdown behavior or API versioning for zero-downtime deployments |
| B04 | Data Integrity & Idempotency | Kafka partitioning by facility_id ensures ordering within facility but no discussion of partition rebalancing impact on exactly-once processing or consumer group coordination | Identifies partition rebalancing risks or recommends sticky partition assignment strategies |
| B05 | Fault Recovery Design | Auto-scaling based on CPU utilization (target 70%) but no consideration of cold start latency for forecast service (ML model loading time) during scale-out events | Mentions cold start impact on SLO during traffic spikes or recommends pre-warming strategies |
| B06 | Availability & Redundancy | S3 archival for historical data but no discussion of restore procedures, RTO for analytics queries after primary InfluxDB failure, or validation of archive completeness | Proposes disaster recovery testing for S3 restore path or quantifies RTO for historical data access |
| B07 | Monitoring & Alerting | InfluxDB disk usage alert at 80% but no proactive capacity planning process or trend analysis to predict storage exhaustion timeline | Recommends capacity forecasting based on retention policy and ingestion rate growth trends |
