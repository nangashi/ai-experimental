# Answer Key - Round 007

## Execution Context
- **Observation Perspective**: reliability
- **Target**: design
- **Embedded Problems**: 9 problems

## Embedded Problem List

### P01: External API Circuit Breaker Absence
- **Category**: Fault Recovery Design
- **Severity**: Critical
- **Location**: Section 3 (Architecture Design) - Translation Job calling OpenAI API; Section 5 (API Design) - Stripe webhook processing
- **Description**: External API calls (OpenAI for translation, Stripe for subscription webhooks) lack circuit breaker patterns. The Translation Job calls OpenAI API synchronously during event processing without circuit breaker or bulkhead isolation. Stripe webhook processing similarly lacks circuit breaker. When external APIs experience degraded performance or outages, the system will accumulate blocked requests, exhaust thread pools, and propagate cascading failures throughout the processing pipeline.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of circuit breaker/bulkhead for OpenAI API calls in the Translation Job AND explains the risk of cascading failures when external API degrades (thread pool exhaustion, pipeline blockage)
  - △ (Partial): Mentions external API fault handling concerns (e.g., "OpenAI API failures need handling") but does not specifically identify circuit breaker absence or explain cascading failure risk
  - × (Not Detected): No mention of circuit breaker patterns for external API calls

### P02: Kafka Consumer Offset Commit Without Idempotency
- **Category**: Data Integrity & Idempotency
- **Severity**: Critical
- **Description**: Section 6 states "Kafka consumer errors: Commit offset only after successful processing" without addressing idempotency. If a Flink job successfully processes an event and writes to PostgreSQL/InfluxDB but fails before committing the offset (e.g., due to pod termination), the event will be reprocessed on restart. Without idempotency design (deduplication keys, upsert strategies), this causes duplicate event records in PostgreSQL and inflated metrics in InfluxDB, compromising data integrity.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of idempotency design in Kafka event processing AND explains the duplicate data risk when processing succeeds but offset commit fails (e.g., "pod termination between write and commit causes reprocessing without deduplication")
  - △ (Partial): Mentions Kafka offset management concerns or general idempotency needs but does not connect them to the specific "commit after processing" strategy and duplicate data risk
  - × (Not Detected): No mention of idempotency concerns in Kafka event processing

### P03: Redis Pub/Sub Message Loss on Gateway Restart
- **Category**: Fault Recovery Design
- **Severity**: Critical
- **Description**: Section 3 describes "Redis Pub/Sub → WebSocket Gateway → Client applications" data flow. Redis Pub/Sub has fire-and-forget semantics with no message persistence or delivery guarantees. If WebSocket Gateway pods restart during deployment or crash, all messages published to Redis Pub/Sub during the downtime are lost. Clients will miss critical real-time events without notification. The design lacks a durable message queue (e.g., Kafka consumer for WebSocket delivery) or at-least-once delivery guarantee mechanism.
- **Detection Criteria**:
  - ○ (Detected): Identifies Redis Pub/Sub's lack of message persistence AND explains the message loss risk during gateway restarts/crashes (e.g., "Pub/Sub messages lost during pod restart, clients miss events without notification")
  - △ (Partial): Mentions Redis Pub/Sub reliability concerns or WebSocket connection recovery but does not specifically identify message loss during gateway downtime
  - × (Not Detected): No mention of Redis Pub/Sub message loss risk

### P04: Multi-Store Write Consistency Without Distributed Transaction
- **Category**: Data Integrity & Idempotency
- **Severity**: Significant
- **Description**: Section 3 describes Flink Enrichment Job writing to both PostgreSQL (`events` table) AND Redis Pub/Sub channel (`live-events`) in the same processing flow. The design does not specify transaction coordination or consistency guarantees between these writes. If the job successfully writes to PostgreSQL but fails before publishing to Redis (e.g., due to network partition or pod termination), persistent storage is updated but real-time clients receive no notification. This creates inconsistency between historical data (PostgreSQL) and live delivery (Redis Pub/Sub).
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of consistency guarantee for PostgreSQL + Redis Pub/Sub dual writes AND explains the risk of partial write failures creating historical/live data divergence
  - △ (Partial): Mentions transaction boundary concerns or data consistency but does not specifically identify the PostgreSQL + Redis Pub/Sub coordination issue
  - × (Not Detected): No mention of multi-store write consistency

### P05: WebSocket Connection Recovery Strategy Absence
- **Category**: Fault Recovery Design
- **Severity**: Significant
- **Description**: Section 5 describes WebSocket connection establishment and message format but does not specify client-side reconnection strategy, state synchronization after reconnection, or missed message recovery. When WebSocket Gateway pods are terminated during deployment or experience transient failures, clients disconnect. Without explicit reconnection logic (exponential backoff, jitter), state synchronization (last received event_id), and gap-fill mechanism (fetch missed events from REST API), clients will miss events during disconnection periods or experience duplicate deliveries.
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of WebSocket reconnection strategy AND state synchronization/gap-fill mechanisms for handling disconnection during gateway restarts
  - △ (Partial): Mentions WebSocket connection resilience concerns but does not specify reconnection strategy or state synchronization requirements
  - × (Not Detected): No mention of WebSocket reconnection handling

### P06: Ingestion Adapter Timeout Configuration Absence
- **Category**: Fault Recovery Design
- **Severity**: Significant
- **Description**: Section 3 describes three ingestion adapters (Stadium Sensor Adapter polling every 100ms, Broadcast API Adapter receiving webhooks, Social Media Adapter streaming APIs) without specifying timeout configurations for external API calls. When external sources experience latency degradation or hang, adapters will block indefinitely, exhausting connection pools and thread pools. The Stadium Sensor Adapter's 100ms polling interval is particularly vulnerable—if sensor API responses slow to multi-second latency without timeout, the adapter will queue thousands of pending requests within minutes.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of timeout specifications for ingestion adapters' external API calls AND explains the risk of resource exhaustion when upstream services degrade (e.g., "100ms polling + no timeout = request queue buildup during latency spike")
  - △ (Partial): Mentions ingestion adapter fault handling concerns but does not specifically identify timeout configuration absence or explain resource exhaustion risk
  - × (Not Detected): No mention of ingestion adapter timeout design

### P07: InfluxDB Write Failure Handling Absence
- **Category**: Fault Recovery Design
- **Severity**: Moderate
- **Description**: Section 3 describes Flink Metrics Aggregation Job writing to InfluxDB without specifying failure handling strategy. InfluxDB writes can fail due to network issues, resource exhaustion, or cluster unavailability. The design does not specify retry strategy, buffering, or degraded operation mode. If InfluxDB is unavailable, the Aggregation Job will either crash (blocking all metrics processing) or silently drop metrics data (creating monitoring blind spots).
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of failure handling for InfluxDB writes in the Metrics Aggregation Job AND explains the risk of job crash or silent metric loss
  - △ (Partial): Mentions time-series database reliability concerns but does not specifically identify InfluxDB write failure handling
  - × (Not Detected): No mention of InfluxDB write failure handling

### P08: Deployment Rollback Data Compatibility Absence
- **Category**: Deployment & Rollback
- **Severity**: Moderate
- **Description**: Section 6 states "Database migrations: Flyway scripts executed manually before deployment" followed by "Deployment strategy: Update EKS deployment with new image tag, wait for rollout status." This deployment sequence (schema-first, then code) creates rollback risk. If the new code version has critical bugs requiring immediate rollback, the database schema has already been modified. The design does not specify backward compatibility requirements for schema changes (e.g., new columns must be nullable, old columns deprecated but not dropped) or rollback validation procedures. Rolling back code to a previous version after schema migration may cause runtime errors due to schema incompatibility (e.g., new non-nullable columns, removed columns still referenced by old code).
- **Detection Criteria**:
  - ○ (Detected): Identifies the rollback risk of schema-first migration strategy AND explains the need for backward-compatible schema changes (e.g., "new columns must be nullable/default-valued for safe code rollback")
  - △ (Partial): Mentions deployment rollback concerns or database migration risks but does not specifically identify schema-code compatibility issues during rollback
  - × (Not Detected): No mention of deployment rollback data compatibility

### P09: SLO Monitoring and Alerting Design Absence
- **Category**: Monitoring & Alerting
- **Severity**: Moderate
- **Description**: Section 7 specifies "Target availability: 99.9% uptime (43.8 minutes downtime/month allowed)" and "End-to-end latency p95 < 500ms" but does not define corresponding monitoring and alerting strategy. The design lacks SLO-based alert configurations (e.g., "alert when error rate exceeds X% over Y-minute window" or "alert when p95 latency crosses 500ms threshold for Z minutes"), alert routing/escalation paths, or runbook references. Without explicit monitoring-to-SLO mapping, operations teams cannot proactively detect SLO violations before they impact availability budget.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of SLO-based monitoring/alerting configuration for the specified availability and latency targets AND explains the gap between defined SLOs and operational alerting
  - △ (Partial): Mentions general monitoring needs or SLO concerns but does not specifically identify the absence of alerting strategy for the stated 99.9% availability / 500ms latency targets
  - × (Not Detected): No mention of SLO monitoring or alerting design

## Bonus Problem List

Problems not in the formal answer key but worthy of bonus points if detected:

| ID | Category | Description | Bonus Condition |
|----|----------|-------------|-----------------|
| B01 | Availability & Redundancy | Kafka replication factor 2 with 3 brokers provides insufficient durability; if 2 brokers fail simultaneously, data loss occurs | Identifies the risk of data loss with replication factor 2 and recommends replication factor 3 for 3-broker cluster |
| B02 | Fault Recovery Design | PostgreSQL connection pool configuration not specified for Flink jobs; dynamic resource requirements (10,000 events/sec peak) without pool size planning risks exhaustion | Identifies the need for explicit connection pool sizing for Flink → PostgreSQL writes under peak load |
| B03 | Availability & Redundancy | EKS autoscaling policy (HPA based on CPU 70%) does not account for WebSocket connection capacity limits (50,000 per instance); scale-out may occur too late when CPU is still low but connection slots are exhausted | Identifies the mismatch between CPU-based autoscaling and connection capacity limits for WebSocket gateway |
| B04 | Deployment & Rollback | Zero-downtime deployment strategy not specified; direct EKS deployment update may cause brief WebSocket disconnections during pod termination | Recommends gradual rollout strategy (e.g., rolling update with connection draining) to minimize client impact |
| B05 | Monitoring & Alerting | Correlation ID propagation spans only "ingestion boundary → processing stages" but does not extend to external API calls (OpenAI, Stripe), limiting distributed tracing coverage during external service issues | Identifies incomplete correlation ID propagation for external API observability |
