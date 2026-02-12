# Performance Design Review: Smart Agriculture IoT Platform

## Document Structure Analysis

The design document covers the following architectural aspects:
- **System Overview**: Background, key features, target users with scale indicators (1-5 sensors for small farms, 50-200 for large farms)
- **Technology Stack**: Backend (Node.js/Express), databases (PostgreSQL + MongoDB), message brokers (MQTT, RabbitMQ), infrastructure (AWS EC2 t3.medium × 1), frontend (React)
- **Architecture Design**: Component diagram showing data flow from IoT sensors through MQTT to backend services
- **Data Model**: PostgreSQL schema (users, farms, sensors, irrigation_schedules) and MongoDB schema (sensor_readings)
- **API Design**: REST endpoints with sample implementations for dashboard and sensor history retrieval
- **Non-Functional Requirements**: Performance targets (1000 messages/sec for 100 sensors, 3-second dashboard response), security, availability (99.0%)

**Missing architectural concerns:**
- No explicit capacity planning for data growth over time
- No monitoring/alerting strategy
- No horizontal scaling strategy
- No caching strategy
- No database indexing strategy
- No connection pooling configuration
- No timeout/retry policies for external services
- No data lifecycle management (archival, retention policies)

---

## Performance Issues by Severity

### Critical Issues

**C1: Missing NFR Specification - Throughput Under Growth Conditions**

The design specifies "100 sensors, 1000 messages/sec" as a performance target, but the system is expected to serve agricultural corporations with "50-200 sensors/farm" (line 18). There is no specification for:
- Expected concurrent users (individual farmers + consultants managing multiple clients)
- Data growth trajectory (sensor readings accumulate indefinitely in MongoDB)
- Peak load scenarios (e.g., harvest season with all sensors active)

**Impact:** Without throughput specifications for realistic production scenarios, the single t3.medium EC2 instance (line 26) may become a bottleneck under actual load. The 1000 msg/sec target appears insufficient for 200 sensors × multiple farms × consultants managing multiple clients.

**Recommendation:**
1. Define NFR scenarios explicitly:
   - "Support 500 concurrent users with 50 farms × 100 sensors average"
   - "Handle 10,000 messages/sec peak load during agricultural peak seasons"
2. Conduct load testing to validate single-instance capacity limits
3. Document when horizontal scaling becomes necessary (e.g., "scale out at 70% CPU utilization")

---

**C2: Unbounded Data Growth in MongoDB Without Lifecycle Management**

The `sensor_readings` collection (line 93-101) stores time-series data indefinitely with no retention policy, archival strategy, or TTL indexes. With 100 sensors generating 1 reading/minute, the system accumulates:
- 100 sensors × 1 reading/min × 60 min × 24 hr × 365 days = 52.6 million documents/year
- For agricultural corporations (200 sensors/farm × multiple farms), this grows exponentially

**Impact:**
- MongoDB query performance degrades as collection size grows (even with indexes, working set may exceed RAM)
- Storage costs increase indefinitely
- The 3-second dashboard response target (line 194) will be impossible to maintain after 1-2 years of operation without data lifecycle management

**Recommendation:**
1. Implement TTL index on `sensor_readings.timestamp` with 90-day retention for raw data
2. Design aggregation strategy: store 1-minute averages for 90 days, 1-hour averages for 1 year, daily averages indefinitely
3. Archive cold data to AWS S3 with lifecycle policies
4. Document storage capacity planning: "Expect 2GB/month per farm, provision 50GB minimum"

---

**C3: Single EC2 Instance - No Horizontal Scaling Strategy**

The infrastructure design specifies "AWS EC2 (t3.medium × 1 instance)" (line 26) with no horizontal scaling strategy, while the architecture includes stateful components:
- MQTT broker stores active connections
- Express.js application server has no session store mentioned (JWT in line 169 suggests stateless, but no explicit design)

**Impact:**
- Single point of failure: any EC2 instance failure causes complete service outage (conflicts with 99.0% availability target in line 202)
- Cannot scale horizontally to handle peak loads
- Maintenance deployments require downtime (PM2 restart in line 187)

**Recommendation:**
1. Design for horizontal scalability:
   - Use external MQTT broker (AWS IoT Core or managed MQTT service)
   - Ensure Express.js is fully stateless (confirm JWT validation does not depend on local state)
   - Use Redis for shared session store if needed
2. Deploy behind AWS Application Load Balancer with auto-scaling group (min 2 instances)
3. Separate data ingestion service from API gateway service for independent scaling

---

### Significant Issues

**S1: N+1 Query Pattern in Dashboard Data Retrieval**

The dashboard endpoint implementation (lines 118-147) exhibits a classic N+1 query pattern:
```javascript
const sensors = await db.query('SELECT * FROM sensors WHERE farm_id = $1', [farmId]);
for (const sensor of sensors.rows) {
  const reading = await mongodb.collection('sensor_readings')
    .find({ sensor_id: sensor.id })
    .sort({ timestamp: -1 })
    .limit(1)
    .toArray();
  sensorReadings.push(reading[0]);
}
```

For a farm with 200 sensors, this executes:
- 1 PostgreSQL query (sensors)
- 200 MongoDB queries (one per sensor)

**Impact:**
- Dashboard response time grows linearly with sensor count: 200 sensors × ~10ms per MongoDB query = 2+ seconds just for sensor readings (approaching the 3-second SLA)
- Network round-trip overhead between application and MongoDB multiplies the latency
- Under concurrent load, this pattern causes connection pool exhaustion

**Recommendation:**
Replace the loop with a single batch query:
```javascript
const sensorIds = sensors.rows.map(s => s.id);
const readings = await mongodb.collection('sensor_readings').aggregate([
  { $match: { sensor_id: { $in: sensorIds } } },
  { $sort: { timestamp: -1 } },
  { $group: { _id: "$sensor_id", latest: { $first: "$$ROOT" } } }
]).toArray();
```
This reduces 200 MongoDB queries to 1, cutting dashboard latency by 80-90%.

---

**S2: Missing Database Indexes on Frequently Queried Columns**

The data model (lines 55-101) defines table structures but specifies no indexes beyond primary keys and unique constraints. Critical missing indexes:

**PostgreSQL:**
- `sensors.farm_id` (queried in every dashboard load, line 125)
- `irrigation_schedules.farm_id` (queried in every dashboard load, line 139)
- `farms.user_id` (required for user-to-farms lookup when consultants manage multiple clients)

**MongoDB:**
- `sensor_readings.sensor_id` (queried in every sensor history retrieval, line 158)
- Compound index `(sensor_id, timestamp)` for time-range queries (lines 158-162)

**Impact:**
- PostgreSQL performs full table scans on `sensors` and `irrigation_schedules` tables as farm count grows
- MongoDB performs collection scans on `sensor_readings` (with millions of documents) for every dashboard load
- The 3-second dashboard SLA becomes unattainable at scale

**Recommendation:**
1. Add indexes in PostgreSQL migration:
   ```sql
   CREATE INDEX idx_sensors_farm_id ON sensors(farm_id);
   CREATE INDEX idx_irrigation_schedules_farm_id ON irrigation_schedules(farm_id);
   CREATE INDEX idx_farms_user_id ON farms(user_id);
   ```
2. Add MongoDB indexes:
   ```javascript
   db.sensor_readings.createIndex({ sensor_id: 1, timestamp: -1 });
   ```
3. Document index strategy in design document

---

**S3: Synchronous External API Call in Critical Path**

The harvest prediction feature (line 13) requires "weather data retrieval from OpenWeatherMap API" (line 28), but the API design (line 112) shows a synchronous GET endpoint:
```
GET /api/farms/:farmId/harvest-prediction
```

With no caching or async processing strategy mentioned, this implies:
- User request → calls OpenWeatherMap API synchronously → waits for response → returns prediction
- OpenWeatherMap API has rate limits and variable latency (200-1000ms typical)

**Impact:**
- User-facing request latency directly depends on third-party API performance
- API rate limit breaches during peak usage (multiple farms requesting predictions simultaneously)
- Timeout failures cascade to user experience

**Recommendation:**
1. **Cache weather data**: Implement Redis cache with 1-hour TTL for weather data per location
2. **Pre-fetch strategy**: Background job fetches weather data for all active farms every hour
3. **Async prediction**: POST endpoint queues prediction job via RabbitMQ, GET endpoint retrieves cached result
4. **Timeout configuration**: Set 5-second timeout for OpenWeatherMap API calls with fallback to cached data

---

**S4: Missing Connection Pooling Configuration**

The technology stack mentions PostgreSQL and MongoDB (lines 24-26) but the design document contains no connection pooling configuration. The sample code (lines 118-147) uses `db.query()` and `mongodb.collection()` without showing pool management.

**Impact:**
- Without connection pooling, each API request creates a new database connection, causing:
  - High connection establishment overhead (TCP handshake + auth)
  - Database connection limit exhaustion under concurrent load
  - Potential connection leaks if connections are not properly closed
- PostgreSQL default `max_connections=100` may be exhausted by a single EC2 instance under load

**Recommendation:**
1. Configure PostgreSQL connection pool (using `pg` library):
   ```javascript
   const pool = new Pool({
     max: 20,  // max connections
     idleTimeoutMillis: 30000,
     connectionTimeoutMillis: 2000
   });
   ```
2. Configure MongoDB connection pool:
   ```javascript
   const client = new MongoClient(uri, {
     maxPoolSize: 50,
     minPoolSize: 10,
     maxIdleTimeMS: 60000
   });
   ```
3. Document recommended pool sizes for different deployment scales

---

**S5: Missing Timeout and Retry Policies for External Services**

The architecture includes multiple external dependencies (lines 28, 34-36):
- MQTT broker (sensor data ingestion)
- OpenWeatherMap API (weather data)
- RabbitMQ (async jobs)
- Email/SMS providers for alerts (line 51)

No timeout or retry policies are specified in the design.

**Impact:**
- Hung requests waiting indefinitely for unresponsive services
- Cascading failures when external service degrades
- Resource exhaustion (threads/connections blocked on slow external calls)

**Recommendation:**
1. Define timeout policy for all external calls:
   - MQTT broker: 5s connection timeout, 30s keepalive
   - OpenWeatherMap API: 5s request timeout
   - RabbitMQ: 10s publish timeout
   - Email/SMS: 10s send timeout
2. Implement exponential backoff retry:
   - 3 retries with 1s, 2s, 4s delays
   - Circuit breaker pattern for repeated failures (fail fast after 5 consecutive failures)
3. Document fallback strategies:
   - Use cached weather data if API unavailable
   - Queue alerts for retry if notification service fails

---

### Moderate Issues

**M1: Inefficient Sensor History Query Without Pagination**

The sensor history endpoint (lines 151-166) retrieves all readings within a date range without pagination:
```javascript
.find({ sensor_id: parseInt(sensorId), timestamp: { $gte: start_date, $lte: end_date } })
.toArray();
```

For a 30-day query on a sensor reporting every minute:
- 30 days × 24 hours × 60 minutes = 43,200 documents
- With 50-byte average document size: 2.1 MB response payload
- With 200 sensors queried concurrently: 420 MB memory usage + network transfer

**Impact:**
- Large response payloads cause high memory usage and slow network transfer
- Browser/client may freeze rendering 40,000+ data points
- No limit on query range allows abusive queries (e.g., 1-year range = 525,600 documents)

**Recommendation:**
1. Implement pagination with default limit:
   ```javascript
   const page = parseInt(req.query.page) || 1;
   const limit = Math.min(parseInt(req.query.limit) || 1000, 10000);
   const skip = (page - 1) * limit;

   const readings = await mongodb.collection('sensor_readings')
     .find({ sensor_id, timestamp: { $gte: start_date, $lte: end_date } })
     .sort({ timestamp: 1 })
     .skip(skip)
     .limit(limit)
     .toArray();
   ```
2. Return total count for pagination UI
3. Document max query range (e.g., 90 days) and auto-downsample for longer ranges

---

**M2: Missing Monitoring and Alerting Strategy**

The design includes logging with Winston (line 179) but no monitoring/alerting strategy for performance metrics:
- No APM (Application Performance Monitoring) tools mentioned
- No database performance monitoring
- No infrastructure metrics (CPU, memory, disk I/O)
- No SLA breach alerting

**Impact:**
- Cannot detect performance degradation before users complain
- No visibility into database slow queries or connection pool saturation
- Reactive incident response instead of proactive optimization

**Recommendation:**
1. Integrate APM tool:
   - AWS CloudWatch for EC2/RDS/DocumentDB metrics
   - Application-level metrics: request latency (p50/p95/p99), throughput, error rate
2. Configure alerting thresholds:
   - API endpoint latency p95 > 2 seconds
   - Database connection pool usage > 80%
   - MQTT message queue depth > 10,000
3. Dashboard for real-time monitoring: database query performance, API endpoint latency distribution

---

**M3: Suboptimal Data Model for Time-Series Queries**

The `sensor_readings` collection (lines 93-101) stores one document per reading with flat structure:
```json
{ "sensor_id": 123, "timestamp": "...", "value": 24.5, "unit": "celsius" }
```

MongoDB is used for time-series data, but the schema does not leverage bucketing strategies for efficient range queries.

**Impact:**
- Index size grows proportionally to document count (52M documents = large index overhead)
- Range queries scan more documents than necessary
- Higher memory pressure for index + working set

**Recommendation:**
1. Use MongoDB Time-Series Collections (available in MongoDB 5.0+):
   ```javascript
   db.createCollection("sensor_readings", {
     timeseries: {
       timeField: "timestamp",
       metaField: "sensor_id",
       granularity: "minutes"
     }
   });
   ```
2. Alternative bucketing strategy: group readings into hourly buckets (reduces document count by 60x):
   ```json
   {
     "sensor_id": 123,
     "hour": "2026-02-11T10:00:00Z",
     "readings": [
       { "minute": 0, "value": 24.5 },
       { "minute": 1, "value": 24.6 },
       ...
     ]
   }
   ```
3. Evaluate if InfluxDB or TimescaleDB (PostgreSQL extension) is more appropriate for time-series workload

---

**M4: Missing Idempotency for Irrigation Control**

The manual irrigation execution endpoint (line 111) `POST /api/farms/:farmId/irrigation/execute` has no idempotency design:
- No request deduplication mechanism
- No idempotency key in API design

**Impact:**
- If user double-clicks or network timeout causes retry, duplicate irrigation commands may be sent
- Potential over-watering if control system executes duplicate commands
- No way to safely retry failed requests

**Recommendation:**
1. Add idempotency key to request:
   ```javascript
   POST /api/farms/:farmId/irrigation/execute
   Headers: { "Idempotency-Key": "uuid-v4" }
   ```
2. Store idempotency key with 24-hour TTL in Redis
3. If duplicate key detected, return original response without re-executing
4. Document idempotency requirement in API design

---

**M5: Lack of Caching Strategy for Dashboard Data**

The dashboard endpoint (lines 118-147) performs database queries on every request with no caching strategy:
- Farm metadata (rarely changes)
- Sensor list (changes only when sensors added/removed)
- Current sensor readings (updated every minute but acceptable staleness)

**Impact:**
- Unnecessary database load for static/quasi-static data
- Slower dashboard response time than necessary
- Database becomes bottleneck under read-heavy load

**Recommendation:**
1. Implement Redis cache with tiered TTL:
   - Farm metadata: 1-hour TTL (invalidate on farm update)
   - Sensor list: 5-minute TTL (invalidate on sensor add/remove)
   - Current sensor readings: 30-second TTL (acceptable staleness for dashboard)
2. Cache key strategy: `farm:{farmId}:dashboard`, `farm:{farmId}:sensors`
3. Cache invalidation on relevant write operations
4. Document expected cache hit rate (target 80%+ for dashboard loads)

---

### Minor Improvements

**I1: Consider WebSocket for Real-Time Dashboard Updates**

The current design uses REST API polling for dashboard updates (implied by GET endpoint in line 108). For real-time sensor monitoring, WebSocket connections would reduce latency and server load.

**Recommendation:**
- Evaluate WebSocket or Server-Sent Events for pushing sensor updates to connected dashboards
- Consider per-farm topic subscriptions to avoid broadcasting all sensor data to all clients
- Document connection limit planning (e.g., AWS ALB supports 100K WebSocket connections per instance)

---

**I2: Positive Aspects**

The design demonstrates several performance-conscious decisions:
1. **Asynchronous job processing**: Report generation uses RabbitMQ (line 50) to avoid blocking user requests
2. **Dual database strategy**: PostgreSQL for relational data + MongoDB for time-series data aligns with access patterns
3. **Explicit NFR targets**: Specifies concrete throughput (1000 msg/sec) and latency (3-second dashboard) targets
4. **Sensor data separation**: MQTT ingestion path is decoupled from user-facing API, preventing sensor load from degrading UI responsiveness

---

## Summary

This design contains **3 critical**, **5 significant**, **5 moderate**, and **2 minor** performance issues. The most urgent concerns are:

1. **N+1 query pattern** in dashboard retrieval (S1) - directly violates 3-second SLA at scale
2. **Missing database indexes** (S2) - causes full table scans as data grows
3. **Unbounded data growth** (C2) - threatens system viability after 1-2 years
4. **Single-instance architecture** (C3) - conflicts with 99.0% availability target and limits scalability

Addressing the critical and significant issues is essential before production deployment for agricultural corporations with 50-200 sensors per farm. The current architecture may suffice for small-scale pilots (1-5 sensors) but requires substantial optimization for the stated scale targets.
