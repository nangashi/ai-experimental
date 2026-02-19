# Answer Key - Round 006

## Execution Context
- **Perspective**: performance
- **Target**: design
- **Embedded Problems**: 10

## Embedded Problems

### P01: Missing Performance SLA Definition
- **Category**: Performance Requirements (Non-Functional Requirements)
- **Severity**: Critical
- **Location**: Section 7 (Non-Functional Requirements)
- **Problem Description**: The design document lacks explicit performance targets for key metrics such as API response time, data ingestion latency, and query performance. While scalability targets (50 buildings/tenant, 1000 sensors/building) are mentioned, there are no defined Service Level Agreements (SLAs) for response times, throughput requirements, or latency constraints. This makes it impossible to validate whether the architecture can meet business requirements or to establish performance monitoring baselines.
- **Detection Criteria**:
  - ○ (Detected): Explicitly identifies missing performance SLA/targets for API response time, ingestion latency, or query performance, AND explains the impact on system validation or monitoring
  - △ (Partial): Mentions performance requirements should be defined OR suggests adding metrics, but doesn't identify specific missing SLA categories (API latency, ingestion throughput, query time)
  - × (Not Detected): No mention of performance SLA or target definition requirements

### P02: N+1 Query Problem in Tenant Buildings List
- **Category**: I/O Efficiency (Query Optimization)
- **Severity**: Critical
- **Location**: Section 5 (API Design - Get Tenant Buildings List endpoint)
- **Problem Description**: The endpoint `GET /api/v1/tenants/{tenant_id}/buildings` returns `sensor_count` for each building. With a naive implementation, this would require 1 query to fetch buildings + N queries to count sensors for each building, resulting in an N+1 query problem. For a tenant with 50 buildings (target scale), this means 51 database queries per API call. The design should specify use of JOIN with COUNT aggregation or batch loading to fetch all sensor counts in a single query.
- **Detection Criteria**:
  - ○ (Detected): Identifies N+1 query risk in the tenant buildings list endpoint specifically mentioning sensor_count aggregation, AND suggests JOIN/subquery/batch loading solution
  - △ (Partial): Mentions general N+1 query risks in the system OR suggests eager loading without connecting it to the specific endpoint design
  - × (Not Detected): No mention of N+1 query problem

### P03: Missing Cache Strategy for Building Metadata
- **Category**: Cache & Memory Management
- **Severity**: Critical
- **Location**: Section 4 (Data Model - Building entity) and Section 5 (API endpoints)
- **Problem Description**: Building metadata (name, address, tenant_id) is frequently accessed by multiple API endpoints but has no caching strategy defined. Every energy data query, analytics report, and dashboard view requires fetching building details from PostgreSQL. Given the target of 50 buildings × 1000 sensors with continuous data ingestion, building lookups become a significant bottleneck. Building metadata is read-heavy with infrequent updates (ideal cache candidate), yet Redis infrastructure is only mentioned for Celery task queue usage.
- **Detection Criteria**:
  - ○ (Detected): Identifies lack of caching for building/sensor metadata that is frequently accessed but rarely modified, AND explains the performance impact with read-heavy access pattern
  - △ (Partial): Suggests caching in general OR mentions Redis could be used for caching, without identifying building metadata as a specific cache candidate
  - × (Not Detected): No mention of caching strategy for frequently accessed reference data

### P04: Synchronous Analytics Report Generation Blocking
- **Category**: Latency & Throughput (Async Processing)
- **Severity**: Medium
- **Location**: Section 6 (Implementation Guidelines - Analytics Report Generation)
- **Problem Description**: The design specifies "API Service synchronously calls Analytics Service" for report generation. Analytics reports involve loading large volumes of historical data, applying ML models, and generating PDFs—operations that can take 10-30 seconds. This blocks the API request thread and user session during generation. With concurrent users requesting reports simultaneously, this can exhaust API service thread pool and cause timeouts. The design should use async job pattern (Celery task) with job status polling or webhook notification.
- **Detection Criteria**:
  - ○ (Detected): Identifies synchronous analytics/report generation as blocking operation causing timeout risk or thread exhaustion, AND suggests async job pattern with status polling
  - △ (Partial): Suggests analytics should be async OR mentions potential timeout, without explaining thread blocking impact or proposing specific async implementation
  - × (Not Detected): No mention of synchronous report generation issue

### P05: Unbounded Time Range Query Risk
- **Category**: I/O Efficiency (Query Boundaries)
- **Severity**: Medium
- **Location**: Section 5 (API Design - Get Building Energy Data)
- **Problem Description**: The `GET /api/v1/buildings/{building_id}/energy` endpoint accepts `start_date` and `end_date` parameters without documented maximum range limits. With 90 days of raw data retention and 15-minute reading intervals (96 readings/day), a full 90-day query would return 8,640 records per sensor. For a building with 1000 sensors, this could result in attempting to fetch and serialize 8.64 million rows. The design should specify maximum query range (e.g., 31 days) and require pagination for large result sets.
- **Detection Criteria**:
  - ○ (Detected): Identifies unbounded date range risk in energy data query endpoint, mentions potential for returning excessive records (thousands/millions), AND suggests maximum range limit or pagination requirement
  - △ (Partial): Mentions pagination should be added OR suggests limiting query ranges in general, without analyzing the specific scale risk (90 days × 96 readings/day × 1000 sensors)
  - × (Not Detected): No mention of unbounded query range issue

### P06: Missing Index on Time-Series Query Patterns
- **Category**: Database Design (Index Strategy)
- **Severity**: Medium
- **Location**: Section 4 (Data Model - energy_readings table)
- **Problem Description**: The energy_readings table has a composite primary key (sensor_id, timestamp) which provides an index on sensor_id prefix. However, common query patterns include filtering by building_id and timestamp range (e.g., "get all sensors in building X for date range Y"). This requires joining with sensors table to resolve building_id, then filtering energy_readings. Without a dedicated index on (building_id, timestamp) or materialized aggregation by building, these queries will be slow. At scale (1000 sensors/building × 8640 readings/90 days = 8.64M rows per building), full table scans become prohibitive.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing index for building-level time-range queries on energy_readings, explains the join inefficiency or scan cost, AND suggests building_id-based index or materialized view
  - △ (Partial): Mentions indexes should be added for time-series queries OR suggests general indexing strategy without identifying the specific building_id + timestamp access pattern
  - × (Not Detected): No mention of indexing strategy for query optimization

### P07: Database Connection Pool Exhaustion Risk
- **Category**: I/O Efficiency (Connection Management)
- **Severity**: Medium
- **Location**: Section 3 (Architecture Design) and Section 6 (Aggregation Process)
- **Problem Description**: The design mentions multiple services (Ingestion, Processing, Analytics, API) all connecting to PostgreSQL, but does not specify connection pool configuration or limits. With continuous sensor data ingestion (10M readings/day) and concurrent API requests, database connections can be exhausted. Specifically, the aggregation process runs "in a single database transaction" every hour—long-running transactions hold connections and locks. The design should specify connection pool sizes per service, use of connection pooling middleware (PgBouncer), and transaction timeout limits.
- **Detection Criteria**:
  - ○ (Detected): Identifies connection pool exhaustion risk from multiple services or long-running transactions, AND suggests connection pool configuration or pooling middleware (PgBouncer/PgPool)
  - △ (Partial): Mentions connection management in general OR suggests using connection pools, without analyzing the specific risk from concurrent services or long transactions
  - × (Not Detected): No mention of database connection management strategy

### P08: Alert Processing Polling Overhead
- **Category**: Latency & Throughput (Polling vs Event-Driven)
- **Severity**: Medium
- **Location**: Section 6 (Implementation Guidelines - Alert Processing)
- **Problem Description**: The design specifies "Every 15 minutes, Processing Service queries latest readings" to check alert thresholds. With 50 buildings/tenant and 1000 sensors/building (50,000 sensors total at target scale), this polling approach requires scanning 50,000 sensor readings every 15 minutes (96 times/day) even when no alerts are triggered. This creates unnecessary database load. An event-driven approach (trigger alerts during data ingestion when threshold exceeded) or incremental windowed queries (only check sensors with new readings) would be more efficient.
- **Detection Criteria**:
  - ○ (Detected): Identifies polling-based alert processing as inefficient at scale, mentions unnecessary database scans, AND suggests event-driven triggers or incremental queries
  - △ (Partial): Mentions polling might be inefficient OR suggests using event-driven architecture, without quantifying the scale impact (50,000 sensors × 96 checks/day)
  - × (Not Detected): No mention of alert processing efficiency

### P09: Missing Time-Series Data Lifecycle Management
- **Category**: Data Retention & Capacity Planning
- **Severity**: Medium
- **Location**: Section 7 (Non-Functional Requirements - Data Retention)
- **Problem Description**: The design specifies "Raw energy_readings: 90 days" and "Archived data moved to S3 after 90 days" but does not define the automated process for data archival or deletion. TimescaleDB hypertable will continuously grow with incoming data (10M readings/day). Without automated retention policies (TimescaleDB's `drop_chunks` or scheduled purge jobs), the table will accumulate data indefinitely, degrading query performance and increasing storage costs. The design should specify use of TimescaleDB retention policies or scheduled archival jobs.
- **Detection Criteria**:
  - ○ (Detected): Identifies lack of automated data archival/purge mechanism for time-series data, explains continuous growth impact on performance/cost, AND suggests TimescaleDB retention policy or scheduled cleanup job
  - △ (Partial): Mentions data archival should be automated OR suggests TimescaleDB features, without connecting it to the performance/cost impact of unbounded growth
  - × (Not Detected): No mention of data lifecycle automation

### P10: Concurrent Write Contention on Daily Summaries
- **Category**: Database Design (Concurrency Control)
- **Severity**: Minor
- **Location**: Section 6 (Aggregation Process) and Section 4 (daily_summaries table)
- **Problem Description**: The aggregation process "updates daily_summaries table with rolled-up metrics" every hour. Multiple aggregation jobs (hourly roll-ups for different buildings) may attempt to update the same daily_summaries row concurrently (updating cumulative totals). Without explicit concurrency control (optimistic locking with version column, or database-level row locking), concurrent updates can result in lost updates or deadlocks. The design should specify use of `SELECT ... FOR UPDATE` or optimistic locking pattern for safe concurrent aggregation.
- **Detection Criteria**:
  - ○ (Detected): Identifies concurrent write risk on daily_summaries from parallel aggregation jobs, explains lost update or deadlock potential, AND suggests row-level locking or optimistic locking mechanism
  - △ (Partial): Mentions concurrent writes might be an issue OR suggests locking in general, without identifying the specific daily_summaries update pattern
  - × (Not Detected): No mention of concurrent write management

## Bonus Problems

Problems not explicitly embedded in the test document, but worthy of bonus credit if detected:

| ID | Category | Content | Bonus Condition |
|----|---------|---------|-----------------|
| B01 | API Efficiency | Batch sensor ingestion endpoint accepts unbounded array size, risking memory exhaustion and timeout | Identifies unbounded batch size risk and suggests request size limit (e.g., max 1000 readings/request) |
| B02 | Database Design | Missing composite index on (building_id, date) for daily_summaries table, causing slow lookups for building-level reports | Identifies missing index on daily_summaries for building report queries |
| B03 | Cache Strategy | JWT token validation on every API request requires database lookup; should use in-memory cache or stateless validation | Identifies JWT validation overhead and suggests caching or stateless approach |
| B04 | Async Processing | Sensor data validation in ingestion pipeline is blocking; should move validation to async worker for better throughput | Suggests async validation to improve ingestion throughput |
| B05 | Query Optimization | Alert threshold checks query all sensors regardless of recent activity; should maintain "active sensors" bitmap or last-update tracking | Suggests incremental/filtered alert checking instead of full scan |
| B06 | Capacity Planning | 10M readings/day growth rate not analyzed against database storage capacity and query performance degradation timeline | Identifies need for capacity planning with growth projections |
| B07 | Monitoring | Missing definition of performance monitoring metrics (API latency percentiles, ingestion lag, query duration) | Identifies lack of performance-specific monitoring metrics definition |
| B08 | Database Design | TimescaleDB continuous aggregates (materialized views) could pre-compute hourly/daily summaries instead of Celery jobs | Suggests using TimescaleDB continuous aggregates for better efficiency |
| B09 | Scalability | Single-region AWS deployment creates latency for geographically distributed buildings; multi-region strategy needed | Identifies geographic latency issue and suggests multi-region architecture |
| B10 | API Design | Analytics report endpoint lacks rate limiting; concurrent report requests could overwhelm Analytics Service | Suggests rate limiting for expensive analytics operations |
