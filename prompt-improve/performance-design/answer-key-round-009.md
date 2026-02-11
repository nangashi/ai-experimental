# Answer Key - Round 009

## Execution Conditions
- **Perspective**: performance
- **Target**: design
- **Embedded Issues**: 10

## Embedded Issues

### P01: Missing Performance Requirements and SLAs
- **Category**: Performance Requirements
- **Severity**: Critical
- **Location**: Section 7 (Non-Functional Requirements)
- **Issue Description**: The design document lacks quantitative performance targets such as:
  - Response time SLAs for API endpoints (e.g., route recommendation latency)
  - Maximum acceptable latency for traffic signal adjustments
  - Time-series data query performance targets
  - System throughput requirements beyond the single "10,000 requests/second" mention in testing
  - Traffic data ingestion lag tolerance
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of specific performance SLAs/targets (e.g., response time requirements, latency targets, throughput goals) in the NFR section and suggests defining them
  - △ (Partial Detection): Mentions performance requirements are important but does not explicitly identify their absence from the design document
  - × (Not Detected): No mention of missing performance SLAs or requirements

### P02: N+1 Query Problem in Route Recommendation Service
- **Category**: I/O and Network Efficiency
- **Severity**: Critical
- **Location**: Section 3 (Architecture Design) - Route Recommendation Service
- **Issue Description**: The Route Recommendation Service "queries current traffic conditions from PostgreSQL" to compute routes. If the service retrieves intersection data one by one for each intersection along candidate routes, this creates an N+1 query pattern. For a typical route spanning 20-30 intersections, this could generate 20-30 individual database queries per route request, significantly increasing latency.
- **Detection Criteria**:
  - ○ (Detected): Identifies potential N+1 query pattern in route recommendation logic when fetching traffic conditions for multiple intersections, suggests batch queries or JOIN operations
  - △ (Partial Detection): Mentions database query efficiency concerns in route recommendation but does not specifically identify the N+1 pattern
  - × (Not Detected): No mention of query efficiency issues in route recommendation

### P03: Missing Cache Strategy for Frequently Accessed Data
- **Category**: Cache and Memory Management
- **Severity**: Critical
- **Location**: Section 3 (Architecture Design) and Section 5 (API Design)
- **Issue Description**: While Redis is listed in the tech stack, there is no explicit cache strategy for frequently accessed data such as:
  - Intersection metadata (static or slowly changing)
  - Recent traffic conditions (queried by thousands of mobile clients)
  - Pre-computed route segments for common origin-destination pairs
  Without caching, every route recommendation request will hit the database, creating excessive load with 500,000+ daily active users.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of cache strategy for intersection metadata, traffic conditions, or route data despite Redis being available, recommends cache implementation
  - △ (Partial Detection): Mentions caching would be beneficial but does not specifically identify the absence of a cache strategy in the design
  - × (Not Detected): No mention of cache strategy or caching issues

### P04: Unbounded Historical Query Risk
- **Category**: I/O and Network Efficiency
- **Severity**: Medium
- **Location**: Section 5 (API Design) - GET /api/analytics/traffic-history
- **Issue Description**: The traffic history endpoint accepts arbitrary date ranges via query parameters without documented limits. City planners could request years of historical data in a single query, potentially causing:
  - Query timeout (especially on InfluxDB time-series data)
  - Memory overflow when loading large result sets
  - Performance degradation for other concurrent queries
- **Detection Criteria**:
  - ○ (Detected): Identifies the risk of unbounded date range queries in the analytics endpoint, recommends query limits (max date range, pagination, result set size limits)
  - △ (Partial Detection): Mentions analytics query performance concerns but does not specifically identify the unbounded query risk
  - × (Not Detected): No mention of historical query efficiency or unbounded query issues

### P05: Inefficient Algorithm Complexity for Route Calculation
- **Category**: Algorithm and Data Structure Efficiency
- **Severity**: Medium
- **Location**: Section 3 (Architecture Design) - Route Recommendation Service
- **Issue Description**: The design specifies using Dijkstra's algorithm for shortest path computation. However, for a city-wide graph with 5,000 intersections, classic Dijkstra has O(V²) or O(E log V) complexity. With 500,000+ daily users generating millions of route requests:
  - Response time could exceed acceptable latency for mobile users (typically <500ms expected)
  - High CPU consumption during peak hours
  The design should consider pre-computation strategies (e.g., contraction hierarchies, A* with landmarks) or approximation algorithms for better performance.
- **Detection Criteria**:
  - ○ (Detected): Points out that Dijkstra's algorithm may be too slow for real-time route queries at scale, suggests more efficient alternatives (A*, contraction hierarchies, pre-computation)
  - △ (Partial Detection): Mentions route calculation performance concerns but does not specifically identify algorithm complexity issues
  - × (Not Detected): No mention of route algorithm efficiency

### P06: Time-Series Data Growth Without Lifecycle Management
- **Category**: Cache and Memory Management
- **Severity**: Medium
- **Location**: Section 4 (Data Model) - TrafficReading in InfluxDB
- **Issue Description**: Traffic sensors generate 10,000+ readings per second (600,000+ per minute, 864 million per day). The design does not specify:
  - Data retention policy (how long to keep raw sensor data)
  - Downsampling strategy (e.g., keep 1-minute granularity for 7 days, then 15-minute granularity for 90 days)
  - Archive/purge policy for old data
  Without lifecycle management, storage costs will grow unbounded and query performance will degrade over time as the dataset size increases.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of data retention/downsampling/archival policy for time-series sensor data, recommends lifecycle management strategy
  - △ (Partial Detection): Mentions time-series data growth concerns but does not specifically recommend retention or downsampling policies
  - × (Not Detected): No mention of data lifecycle or time-series growth issues

### P07: Missing Database Indexes
- **Category**: Latency and Throughput Design
- **Severity**: Medium
- **Location**: Section 4 (Data Model) - SignalAdjustment and RouteRequest tables
- **Issue Description**: The SignalAdjustment and RouteRequest tables lack index definitions, yet they will be queried frequently:
  - SignalAdjustment: Likely queried by `intersection_id` and `adjustment_time` for recent adjustment history
  - RouteRequest: Potentially queried by `user_id` and `request_time` for user history or analytics
  Without proper indexes, these queries will perform full table scans as data volume grows, causing severe latency degradation.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of index definitions on frequently queried columns (e.g., intersection_id, user_id, timestamp columns), recommends adding indexes
  - △ (Partial Detection): Mentions database query performance concerns but does not specifically identify missing indexes
  - × (Not Detected): No mention of index design or database query optimization

### P08: Real-time WebSocket Scalability Not Addressed
- **Category**: Scalability Design
- **Severity**: Medium
- **Location**: Section 3 (Architecture Design)
- **Issue Description**: The design mentions mobile clients receiving real-time route recommendations, but there is no mention of how real-time updates (congestion alerts, route changes) are pushed to clients. If the system uses WebSocket or Server-Sent Events for real-time notifications:
  - With 500,000+ daily active users, maintaining persistent connections requires significant memory and connection management
  - The current REST API design does not address horizontal scaling of WebSocket connections across multiple instances
  - No mention of connection pooling limits or message broker for distributing notifications to multiple app instances
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of real-time notification architecture for mobile clients at scale, mentions WebSocket/SSE scalability concerns or need for pub/sub pattern
  - △ (Partial Detection): Mentions real-time communication or mobile scalability but does not specifically address persistent connection management
  - × (Not Detected): No mention of real-time scalability or WebSocket/persistent connection issues

### P09: Race Condition in Traffic Signal Control
- **Category**: Scalability Design (Concurrency Control)
- **Severity**: Medium
- **Location**: Section 3 (Architecture Design) - Signal Control Service
- **Issue Description**: The Signal Control Service consumes congestion alerts from Kafka and stores control decisions in the `signal_adjustments` table. However, the design does not address concurrent writes:
  - Multiple instances of Signal Control Service could process overlapping congestion events for the same intersection
  - Without distributed locking or idempotency guarantees, duplicate or conflicting signal adjustments could be written to the database
  - Traffic controllers could receive conflicting commands for the same intersection
  The design should specify optimistic locking (version column), distributed locks (Redis), or idempotency keys to prevent race conditions.
- **Detection Criteria**:
  - ○ (Detected): Identifies potential race conditions when multiple service instances write signal adjustments concurrently, recommends locking mechanisms or idempotency
  - △ (Partial Detection): Mentions concurrency concerns in signal control but does not specifically identify race condition risks
  - × (Not Detected): No mention of concurrent write issues or race conditions

### P10: Missing Performance Monitoring Metrics
- **Category**: Latency and Throughput Design (Performance Observability)
- **Severity**: Minor
- **Location**: Section 2 (Technology Stack) and Section 7 (Non-Functional Requirements)
- **Issue Description**: While CloudWatch is mentioned for monitoring, the design does not specify what performance metrics should be collected:
  - API endpoint latency (p50, p95, p99)
  - Kafka consumer lag for real-time processing
  - Database query execution times
  - Route calculation duration
  - Cache hit/miss rates
  Without explicit performance metrics, the team cannot validate whether the system meets performance targets or detect performance degradation proactively.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of specific performance monitoring metrics (latency, throughput, resource utilization) in the monitoring strategy, recommends defining key metrics
  - △ (Partial Detection): Mentions monitoring is important but does not specifically identify missing performance metrics
  - × (Not Detected): No mention of performance monitoring or metrics

## Bonus Issues

Issues not explicitly embedded but represent valuable additional observations if detected:

| ID | Category | Content | Bonus Condition |
|----|---------|---------|----------------|
| B01 | Database Partitioning | Suggest partitioning SignalAdjustment table by time (e.g., monthly partitions) to improve query performance as historical data accumulates | Mentions table partitioning for time-series or large tables |
| B02 | Connection Pool Sizing | Recommend explicit database connection pool configuration for high-concurrency route requests (500,000+ daily users) | Mentions connection pool tuning or sizing strategy |
| B03 | Batch Processing for Analytics | Suggest using batch jobs (e.g., Apache Spark) for heavy analytics queries instead of querying production database directly | Mentions separating analytical workload or batch processing for analytics |
| B04 | API Rate Limiting Granularity | Current rate limit (100 req/min per client) may be insufficient during peak hours; recommend adaptive rate limiting or higher limits for premium users | Mentions rate limiting strategy refinement or differentiated limits |
| B05 | Async Processing for Camera Footage | S3 camera footage storage is mentioned but no processing pipeline; recommend async processing (Lambda, SQS) for video analytics to avoid blocking ingestion | Mentions async processing or decoupling for media/video handling |
| B06 | Geographic Sharding | For future scalability, suggest sharding by city_zone to distribute load across multiple database instances | Mentions database sharding or geographic partitioning strategy |
| B07 | Read Replica for Analytics | Recommend using PostgreSQL read replicas specifically for analytics queries to avoid impacting transactional workload | Mentions read replicas or read/write separation for analytics |
| B08 | Pre-computed Route Cache | Suggest caching popular routes (e.g., morning commute patterns) to reduce computation load | Mentions route pre-computation or route caching strategy |
| B09 | Kafka Consumer Lag Alerting | Recommend alerting on Kafka consumer lag to detect real-time processing delays early | Mentions Kafka lag monitoring or stream processing delay detection |
| B10 | Auto-scaling Policy | Define auto-scaling thresholds (CPU, memory, request count) for ECS Fargate to handle traffic spikes | Mentions auto-scaling configuration or threshold tuning |
