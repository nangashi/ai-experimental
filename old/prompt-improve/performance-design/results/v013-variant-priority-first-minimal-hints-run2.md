# Performance Design Review: Smart Agriculture IoT Platform

## Document Structure Analysis

The design document includes the following sections:
- **Project overview and key features** (real-time sensor data, automated irrigation, harvest prediction)
- **Technology stack** (Node.js, PostgreSQL, MongoDB, MQTT, single EC2 instance)
- **Architecture design** (MQTT ingestion, REST API, async job processing)
- **Data models** (PostgreSQL relational tables, MongoDB time-series sensor data)
- **API design** (dashboard, sensor history, irrigation control endpoints with sample code)
- **NFR specifications** (performance targets: 100 sensors/1000 msg/sec, 3-second dashboard response; availability: 99.0%)

**Missing or incomplete architectural concerns:**
- Scalability strategy for horizontal scaling or multi-instance deployment
- Capacity planning for data growth and archival policies
- Monitoring and alerting infrastructure
- Caching strategy
- Database indexing strategy
- Connection pooling configuration
- Real-time communication mechanism for dashboard updates (polling vs WebSocket)
- Disaster recovery and failover procedures

---

## Performance Issues Detected

### **CRITICAL ISSUES**

#### C1. Single Point of Failure with No Horizontal Scaling Strategy

**Location:** Section 2 (Technology Stack), Section 3 (Architecture Design)

**Issue:**
The infrastructure design specifies a single EC2 instance (`t3.medium × 1インスタンス`) with no horizontal scaling strategy or load balancing mechanism. This creates a system-wide bottleneck where:
- All MQTT connections (100 sensors × 1000 msg/sec = 100,000 msg/sec capacity claim) must be handled by one server
- All API requests for dashboards, sensor history, and predictions are handled by one Node.js process
- Any instance failure results in complete system unavailability

**Impact:**
- **Throughput ceiling:** Single-threaded Node.js event loop can become saturated under claimed load (1000 msg/sec)
- **Availability risk:** Single instance failure violates 99.0% uptime target (allows only 3.65 days downtime/year, but single instance has no failover)
- **Scalability impossibility:** Cannot add capacity for agricultural corporations with 200 sensors/farm or consultants managing multiple clients

**Recommendation:**
1. **Immediate:** Deploy at least 2 EC2 instances behind Application Load Balancer for basic redundancy
2. **Architecture redesign:** Separate MQTT ingestion tier (dedicated instances for Data Ingestion Service) from API tier (stateless web application servers)
3. **Horizontal scaling:** Configure Auto Scaling Groups with CPU/connection count metrics
4. **Session state:** Move JWT validation to stateless design (no server-side session required) to enable true horizontal scaling

---

#### C2. N+1 Query Antipattern in Dashboard API

**Location:** Section 5, `/api/farms/:farmId/dashboard` implementation (lines 129-136)

**Issue:**
The dashboard endpoint executes N+1 queries to fetch the latest sensor reading for each sensor:
```javascript
for (const sensor of sensors.rows) {
  const reading = await mongodb.collection('sensor_readings')
    .find({ sensor_id: sensor.id })
    .sort({ timestamp: -1 })
    .limit(1)
    .toArray();
  sensorReadings.push(reading[0]);
}
```

For a farm with 50 sensors (small agricultural corporation), this results in:
- 1 query to fetch sensors list
- 50 sequential MongoDB queries to fetch latest readings
- **Total: 51 queries instead of 2**

**Impact:**
- **Latency explosion:** 50 sensors × ~10ms MongoDB query = 500ms added latency, exceeding the 3-second SLA leaves only 2.5 seconds for other processing
- **Throughput degradation:** Sequential queries block the event loop, reducing concurrent request capacity
- **Database load:** 50x unnecessary query load on MongoDB

**Recommendation:**
Replace with a single batch query using `$in` operator:
```javascript
const sensorIds = sensors.rows.map(s => s.id);
const readings = await mongodb.collection('sensor_readings')
  .aggregate([
    { $match: { sensor_id: { $in: sensorIds } } },
    { $sort: { sensor_id: 1, timestamp: -1 } },
    { $group: {
        _id: "$sensor_id",
        latest: { $first: "$$ROOT" }
    }}
  ]).toArray();
```
This reduces N+1 queries to a single aggregation pipeline query.

---

#### C3. Missing NFR Specifications for Critical Operations

**Location:** Section 7 (Non-Functional Requirements)

**Issue:**
The NFR section specifies targets for sensor data collection (1000 msg/sec) and dashboard display (3 seconds), but critical operations lack performance specifications:

**Missing SLAs:**
- **Harvest prediction API** (`/api/farms/:farmId/harvest-prediction`): Uses "過去データと気象データに基づく収穫時期・収量予測" but no latency target
- **Report generation** (`POST /api/reports/:farmId/generate`): Async job with no completion time SLA
- **Irrigation execution** (`POST /api/farms/:farmId/irrigation/execute`): Real-time control with no latency requirement
- **Alert notification**: "異常検知時の農業従事者への通知" with no delivery time guarantee

**Impact:**
- **Production risk:** Harvest prediction may execute long-running ML inference without timeout, blocking worker threads
- **User experience:** Report generation may take hours with no user feedback mechanism
- **Safety risk:** Irrigation control delays could damage crops; alerts delays could miss critical thresholds (e.g., frost warnings)

**Recommendation:**
Define explicit SLAs:
1. **Harvest prediction:** < 5 seconds for computation, or async with 30-second completion target + webhook callback
2. **Report generation:** < 2 minutes for weekly report, < 10 minutes for monthly report
3. **Irrigation execution:** < 500ms end-to-end latency (critical safety operation)
4. **Alert notification:** < 30 seconds from threshold breach to email/SMS delivery
5. Add timeout configurations for all external API calls (OpenWeatherMap) and long-running jobs

---

#### C4. Unbounded Sensor Data Growth Without Archival Strategy

**Location:** Section 4 (Data Model), MongoDB `sensor_readings` collection

**Issue:**
The sensor data model has no TTL (Time-To-Live), retention policy, or archival strategy. With the stated requirements:
- 100 sensors × 1000 msg/sec = 100,000 data points/second
- Assuming 1 reading/sensor/minute (more realistic): 100 sensors × 1 reading/min × 60 min × 24 hours = 144,000 readings/day
- **Annual growth:** 52.6 million readings/year/farm
- For agricultural corporations with 200 sensors: **105 million readings/year**

**Impact:**
- **Storage explosion:** MongoDB collection grows unbounded, increasing storage costs linearly
- **Query performance degradation:** Sensor history queries (`/api/farms/:farmId/sensor-history/:sensorId`) scan increasingly large collections, causing latency growth over time
- **Index bloat:** MongoDB indexes grow proportionally, consuming memory and reducing cache hit rates

**Recommendation:**
1. **Immediate:** Implement TTL index on `sensor_readings` collection:
   ```javascript
   db.sensor_readings.createIndex(
     { "timestamp": 1 },
     { expireAfterSeconds: 7776000 } // 90 days
   )
   ```
2. **Data lifecycle policy:**
   - Raw data: 90 days hot storage (MongoDB)
   - Aggregated data (hourly averages): 2 years warm storage (PostgreSQL or S3)
   - Historical archives: Cold storage (S3 Glacier) for compliance
3. **Capacity planning:** Document expected daily data volume and storage growth rate in NFR section

---

### **SIGNIFICANT ISSUES**

#### S1. Missing Database Indexes for Foreign Key Queries

**Location:** Section 4 (Data Model), PostgreSQL tables

**Issue:**
The data model defines foreign key relationships but does not specify indexes on foreign key columns:
- `farms.user_id` (queries by consultant user will scan all farms)
- `sensors.farm_id` (dashboard query scans all sensors without index)
- `irrigation_schedules.farm_id` (dashboard query scans all schedules)

The dashboard API explicitly queries `WHERE farm_id = $1` for sensors and irrigation schedules without documented indexes.

**Impact:**
- **Latency growth with scale:** Consultant managing 50 client farms will experience O(n) table scans instead of O(log n) index lookups
- **Lock contention:** Full table scans hold shared locks longer, blocking writes
- **Dashboard SLA violation:** 3-second dashboard target at risk for consultants with large client portfolios

**Recommendation:**
Add indexes to all foreign key columns:
```sql
CREATE INDEX idx_farms_user_id ON farms(user_id);
CREATE INDEX idx_sensors_farm_id ON sensors(farm_id);
CREATE INDEX idx_irrigation_schedules_farm_id ON irrigation_schedules(farm_id);
```

Additionally, for sensor history queries, create compound index on MongoDB:
```javascript
db.sensor_readings.createIndex({ sensor_id: 1, timestamp: -1 });
```

---

#### S2. Missing Connection Pooling Configuration

**Location:** Section 5 (API Design), database query code

**Issue:**
The sample code shows direct database queries (`await db.query(...)` and `await mongodb.collection(...)`) but does not specify connection pooling configuration. Without proper pooling:
- Each API request may open new database connections
- Connection establishment overhead adds 20-50ms latency per request
- Database connection limits (PostgreSQL default: 100 connections) can be exhausted under load

**Impact:**
- **Latency overhead:** 20-50ms added to every query for connection establishment
- **Connection exhaustion:** Single EC2 instance with 10 concurrent requests × no pooling = 10 connections/request × 5 queries = 50 connections consumed, risking PostgreSQL connection limit
- **Database load:** Constant connection churn increases database CPU usage

**Recommendation:**
Configure connection pooling explicitly:

**PostgreSQL (pg library):**
```javascript
const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  max: 20,  // max connections per instance
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});
```

**MongoDB (native driver):**
```javascript
const client = new MongoClient(uri, {
  maxPoolSize: 50,
  minPoolSize: 5,
  maxIdleTimeMS: 30000,
  serverSelectionTimeoutMS: 5000
});
```

Document pool size calculations based on expected concurrent request load in the design.

---

#### S3. Synchronous External API Call Blocking Request Path

**Location:** Section 1 (Overview), harvest prediction feature using OpenWeatherMap API

**Issue:**
The harvest prediction endpoint (`/api/farms/:farmId/harvest-prediction`) depends on external weather API calls (OpenWeatherMap) but is designed as a synchronous GET endpoint. This creates a blocking dependency:
- External API latency (typically 500ms-2s) directly adds to user-facing response time
- External API failures (rate limits, downtime) cause user-facing endpoint failures
- No caching strategy for weather data (same forecast data reused for multiple farms in same region)

**Impact:**
- **Latency ceiling:** Harvest prediction response time cannot be faster than OpenWeatherMap latency (500ms-2s minimum)
- **Cascading failures:** OpenWeatherMap downtime (outside SLA control) causes user-facing 500 errors
- **Rate limit risk:** Multiple concurrent harvest prediction requests may hit OpenWeatherMap rate limits (free tier: 60 calls/minute)

**Recommendation:**
1. **Async architecture:** Convert harvest prediction to async job pattern:
   - POST `/api/farms/:farmId/harvest-prediction` → returns job ID immediately
   - GET `/api/jobs/:jobId` → polls for completion status
   - Use RabbitMQ worker (already in architecture) to process predictions
2. **Weather data caching:** Cache weather forecast data by location (lat/long) with 1-hour TTL (forecasts update infrequently)
3. **Timeout configuration:** Set 5-second timeout for OpenWeatherMap API calls with exponential backoff retry
4. **Fallback strategy:** Use stale cached weather data if API is unavailable, with "data may be outdated" warning

---

#### S4. Missing Real-Time Update Mechanism for Dashboard

**Location:** Section 3 (Architecture Design), Section 5 (API Design)

**Issue:**
The design shows MQTT for sensor-to-server real-time ingestion (1 msg/sec per sensor), but does not specify how dashboard clients receive real-time updates. The API design only shows REST GET endpoints, implying polling:
- Client polls `/api/farms/:farmId/dashboard` every N seconds to see updated sensor readings
- Polling creates constant unnecessary load even when no data changes

**Impact:**
- **Server load amplification:** 10 concurrent dashboard users polling every 5 seconds = 120 requests/minute baseline load, multiplied by number of farms
- **Stale data:** Polling interval (e.g., 5 seconds) creates latency between sensor reading and dashboard display
- **Network inefficiency:** 95% of polling requests return unchanged data (wasted bandwidth)

**Recommendation:**
Implement WebSocket-based real-time push architecture:

1. **WebSocket endpoint:** `wss://api.example.com/farms/:farmId/live`
2. **Pub-Sub pattern:**
   - Data Ingestion Service publishes new sensor readings to Redis Pub/Sub channel `farm:{farmId}:updates`
   - WebSocket server subscribes to relevant channels and pushes updates to connected clients
3. **Connection management:** Use Socket.IO for reconnection handling and room management
4. **Fallback:** Keep REST polling endpoint for clients without WebSocket support

**Scalability note:** WebSocket connections are stateful, requiring session affinity (sticky sessions) in load balancer or Redis-backed Socket.IO adapter for horizontal scaling.

---

#### S5. Missing Index on MongoDB Sensor History Query

**Location:** Section 5, `/api/farms/:farmId/sensor-history/:sensorId` endpoint

**Issue:**
The sensor history query filters by `sensor_id` and `timestamp` range:
```javascript
.find({
  sensor_id: parseInt(sensorId),
  timestamp: { $gte: new Date(start_date), $lte: new Date(end_date) }
})
.sort({ timestamp: 1 })
```

Without a compound index on `(sensor_id, timestamp)`, MongoDB performs a collection scan followed by in-memory sort.

**Impact:**
- **Query latency:** Collection scan of millions of readings takes seconds instead of milliseconds with index
- **Memory pressure:** In-memory sort requires buffering result set, risking OOM for large date ranges
- **Dashboard performance:** Historical trend charts (common dashboard widget) become unusable at scale

**Recommendation:**
Create compound index optimized for this query pattern:
```javascript
db.sensor_readings.createIndex(
  { sensor_id: 1, timestamp: -1 },
  { name: "sensor_history_idx" }
);
```

Index order `(sensor_id, timestamp)` allows efficient range scans on timestamp after filtering by sensor_id. Descending timestamp (`-1`) optimizes the common "latest data first" access pattern.

---

### **MODERATE ISSUES**

#### M1. Missing Query Result Pagination for Sensor History

**Location:** Section 5, `/api/farms/:farmId/sensor-history/:sensorId` endpoint

**Issue:**
The sensor history endpoint returns unbounded result sets:
```javascript
.find({ sensor_id: ..., timestamp: { $gte: ..., $lte: ... } })
.toArray();
```

For a date range query spanning 90 days with 1 reading/minute:
- 90 days × 24 hours × 60 minutes = **129,600 readings**
- Assuming 100 bytes per document = **12.9 MB response payload**

**Impact:**
- **API response time:** Serializing and transmitting 13 MB JSON takes 2-5 seconds on typical connections
- **Frontend memory:** Large arrays crash browser tabs or cause UI freezing during rendering
- **Network costs:** Unnecessary data transfer costs for users viewing zoomed-in chart views

**Recommendation:**
Implement cursor-based pagination:
```javascript
app.get('/api/farms/:farmId/sensor-history/:sensorId', async (req, res) => {
  const { sensorId } = req.params;
  const { start_date, end_date, limit = 1000, cursor } = req.query;

  const query = {
    sensor_id: parseInt(sensorId),
    timestamp: { $gte: new Date(start_date), $lte: new Date(end_date) }
  };

  if (cursor) {
    query.timestamp = { ...query.timestamp, $lt: new Date(cursor) };
  }

  const readings = await mongodb.collection('sensor_readings')
    .find(query)
    .sort({ timestamp: -1 })
    .limit(parseInt(limit))
    .toArray();

  const nextCursor = readings.length === parseInt(limit)
    ? readings[readings.length - 1].timestamp
    : null;

  res.json({ readings, nextCursor });
});
```

Additionally, consider data aggregation for large time ranges (e.g., return hourly averages instead of raw readings for 30+ day queries).

---

#### M2. Missing Timeout Configuration for External API Calls

**Location:** Section 2 (Technology Stack), OpenWeatherMap API integration

**Issue:**
The design mentions OpenWeatherMap API for weather data but does not specify timeout configuration. Without timeouts:
- Slow API responses can block Node.js event loop indefinitely
- Network issues can cause requests to hang until TCP timeout (typically 60-120 seconds)

**Impact:**
- **Resource exhaustion:** Hanging requests consume Node.js worker thread pool, reducing concurrent request capacity
- **Cascading failures:** One slow external API call can degrade overall system responsiveness
- **Poor user experience:** Users wait indefinitely for harvest prediction results

**Recommendation:**
Configure explicit timeouts for all external HTTP calls:

```javascript
const axios = require('axios');

const weatherApiClient = axios.create({
  baseURL: 'https://api.openweathermap.org/data/2.5',
  timeout: 5000, // 5-second timeout
  headers: { 'User-Agent': 'SmartFarm/1.0' }
});

// With retry logic
const axiosRetry = require('axios-retry');
axiosRetry(weatherApiClient, {
  retries: 3,
  retryDelay: axiosRetry.exponentialDelay,
  retryCondition: (error) => {
    return axiosRetry.isNetworkOrIdempotentRequestError(error)
      || error.code === 'ECONNABORTED';
  }
});
```

Document timeout values in NFR section as part of external dependency SLAs.

---

#### M3. Missing Monitoring and Alerting Strategy

**Location:** Section 7 (Non-Functional Requirements)

**Issue:**
The design includes logging strategy (Winston) but does not define monitoring metrics or alerting rules for performance degradation detection:
- No metrics collection for API response times
- No alerting for sensor data ingestion delays
- No database performance monitoring (slow queries, connection pool exhaustion)

**Impact:**
- **Blind spots:** Performance degradation goes undetected until users report issues
- **Incident response delays:** No proactive alerting for threshold breaches (e.g., dashboard response > 3s)
- **Capacity planning gaps:** No historical metrics to predict when scaling is needed

**Recommendation:**
Define monitoring strategy with key performance metrics:

**Application metrics (use Prometheus + Express middleware):**
- API response time (p50, p95, p99 percentiles) per endpoint
- Request rate and error rate per endpoint
- Active concurrent connections
- RabbitMQ queue depth and processing time

**Infrastructure metrics (CloudWatch):**
- EC2 CPU/memory utilization
- RDS/DocumentDB connection count and query latency
- MQTT broker connection count and message throughput

**Alerting rules:**
- Dashboard API p95 latency > 2.5 seconds (approaching 3s SLA)
- Sensor data ingestion lag > 60 seconds (delayed readings)
- Database connection pool utilization > 80%
- RabbitMQ queue depth > 1000 messages (worker bottleneck)

Integrate with PagerDuty/Slack for incident notification.

---

#### M4. Potential Race Condition in Irrigation Execution

**Location:** Section 4 (Data Model), `irrigation_schedules.last_executed_at` column

**Issue:**
The irrigation schedule design uses `last_executed_at` timestamp to track execution, but does not specify concurrency control mechanism. Potential race conditions:
- Automatic irrigation trigger (soil moisture threshold) + manual execution API call occur simultaneously
- Two workers processing same irrigation schedule from RabbitMQ queue
- Result: Duplicate irrigation execution (water waste, potential crop damage from over-watering)

**Impact:**
- **Resource waste:** Duplicate irrigation commands sent to IoT actuators
- **Crop safety risk:** Over-watering can damage crops, defeating the purpose of precision agriculture
- **Operational cost:** Wasted water and electricity for pump operation

**Recommendation:**
Implement idempotency and concurrency control:

1. **Optimistic locking with version column:**
```sql
ALTER TABLE irrigation_schedules ADD COLUMN version INTEGER DEFAULT 1;

-- In application code
UPDATE irrigation_schedules
SET last_executed_at = NOW(), version = version + 1
WHERE id = $1 AND version = $2
RETURNING *;
```

2. **Idempotency key for irrigation execution:**
```javascript
app.post('/api/farms/:farmId/irrigation/execute', async (req, res) => {
  const idempotencyKey = req.headers['idempotency-key'];

  // Check if already executed within last 5 minutes
  const recent = await db.query(
    'SELECT * FROM irrigation_executions WHERE idempotency_key = $1',
    [idempotencyKey]
  );

  if (recent.rows.length > 0) {
    return res.json({ status: 'already_executed', execution: recent.rows[0] });
  }

  // Proceed with execution...
});
```

3. **Minimum interval constraint:** Add business rule: irrigation cannot execute within 30 minutes of last execution for same schedule.

---

#### M5. Missing Caching Strategy for Frequent Read Operations

**Location:** Section 3 (Architecture Design)

**Issue:**
The architecture does not include a caching layer (e.g., Redis, Memcached) despite having clear caching candidates:
- Farm metadata (changes infrequently, read on every dashboard load)
- Sensor configurations (static data unless admin changes)
- User authentication tokens (JWT validation on every API request)
- Weather forecast data (same forecast reused for multiple predictions)

**Impact:**
- **Database load:** Every dashboard request queries PostgreSQL for farm/sensor metadata (unnecessary read load)
- **Latency overhead:** Database round-trip adds 5-10ms even for simple lookups
- **Scalability ceiling:** Database becomes bottleneck for read-heavy operations

**Recommendation:**
Introduce Redis caching layer for hot data:

1. **Farm/sensor metadata caching:**
```javascript
async function getFarmWithSensors(farmId) {
  const cacheKey = `farm:${farmId}:metadata`;
  const cached = await redis.get(cacheKey);

  if (cached) {
    return JSON.parse(cached);
  }

  const farm = await db.query('SELECT * FROM farms WHERE id = $1', [farmId]);
  const sensors = await db.query('SELECT * FROM sensors WHERE farm_id = $1', [farmId]);

  const result = { farm: farm.rows[0], sensors: sensors.rows };
  await redis.setex(cacheKey, 300, JSON.stringify(result)); // 5-minute TTL

  return result;
}
```

2. **Cache invalidation strategy:**
- TTL-based: Short TTL (5 minutes) for metadata
- Event-driven: Invalidate cache on sensor configuration changes (pub/sub pattern)

3. **Weather data caching:** Cache by location with 1-hour TTL (forecasts update hourly).

---

### **MINOR IMPROVEMENTS**

#### I1. Inefficient Data Structure for Trigger Conditions

**Location:** Section 4, `irrigation_schedules.trigger_condition JSONB` column

**Observation:**
The design stores trigger conditions as JSONB (flexible schema), which is appropriate for extensibility. However, querying schedules that should execute (e.g., "find all schedules where soil moisture < threshold") requires scanning all schedules and parsing JSONB in application code, which is inefficient.

**Recommendation:**
If trigger condition queries become frequent, consider hybrid approach:
- Store structured columns for common conditions (e.g., `soil_moisture_threshold_min`, `soil_moisture_threshold_max`)
- Keep JSONB for additional custom conditions
- Create partial index: `CREATE INDEX ON irrigation_schedules (farm_id) WHERE status = 'active';`

This optimization is low priority unless auto-execution becomes a bottleneck.

---

#### I2. Data Model Design Strengths

**Positive observations:**
1. **Appropriate database selection:** PostgreSQL for relational metadata + MongoDB for time-series data is a good fit for the use case
2. **MQTT for IoT ingestion:** Lightweight protocol appropriate for IoT devices with unreliable networks
3. **Async job processing:** RabbitMQ for report generation decouples heavy tasks from user-facing API
4. **JWT authentication:** Stateless tokens enable horizontal scaling (once single-instance issue is resolved)

These design choices demonstrate good architectural judgment for the problem domain.

---

## Summary

**Critical issues requiring immediate attention:**
1. Single EC2 instance with no failover or horizontal scaling (violates availability SLA)
2. N+1 query antipattern in dashboard API (51 queries instead of 2)
3. Missing NFR specifications for harvest prediction, irrigation, and alerts
4. Unbounded sensor data growth without archival strategy (storage explosion risk)

**Significant issues impacting scalability:**
5. Missing database indexes on foreign keys and time-series queries
6. No connection pooling configuration (connection exhaustion risk)
7. Synchronous external API calls blocking request path
8. Polling-based dashboard updates instead of real-time push
9. Missing compound index on MongoDB sensor history queries

**Recommendations prioritization:**
1. **Week 1:** Fix N+1 query antipattern (S2), add database indexes (S1, S5), configure connection pooling (S2)
2. **Week 2:** Implement multi-instance deployment with load balancer (C1), add data retention policy (C4)
3. **Week 3:** Define missing NFR specifications (C3), implement WebSocket real-time updates (S4)
4. **Week 4:** Add pagination (M1), implement caching layer (M5), configure monitoring/alerting (M3)

Addressing the critical and significant issues will improve performance predictability, eliminate scalability blockers, and ensure the system can meet stated availability and response time targets.
