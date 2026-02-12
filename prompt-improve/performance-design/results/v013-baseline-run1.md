# Performance Review: スマート農業IoTプラットフォーム

## Document Structure Analysis

The design document covers:
- Project overview and target users
- Technology stack
- Architecture design (components and data flow)
- Data models (PostgreSQL and MongoDB schemas)
- API design with implementation samples
- Implementation policies (error handling, logging, testing, deployment)
- Non-functional requirements (performance, security, availability)

Missing or incomplete sections:
- Detailed capacity planning and resource scaling strategies
- Caching strategies
- Monitoring and alerting infrastructure
- Data lifecycle management (archival, retention policies)
- Connection pooling configuration
- Transaction isolation and concurrency control design

---

## Critical Performance Issues

### C-1: N+1 Query Problem in Dashboard API

**Location**: Section 5 - `/api/farms/:farmId/dashboard` implementation (lines 118-147)

**Issue Description**:
The dashboard endpoint exhibits a classic N+1 query antipattern. After retrieving all sensors for a farm, the code iterates through each sensor and issues individual MongoDB queries to fetch the latest reading:

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

**Performance Impact**:
- For a large-scale farm with 200 sensors, this results in 200+ sequential MongoDB queries
- Each query incurs network latency and database overhead
- With average 10ms per query, this adds 2+ seconds of latency
- The 3-second dashboard response target (Section 7) becomes impossible to meet for large farms
- Sequential execution prevents parallelization benefits

**Recommendation**:
Implement batch fetching using MongoDB aggregation pipeline:

```javascript
// Option 1: Single aggregation query with $group
const sensorIds = sensors.rows.map(s => s.id);
const latestReadings = await mongodb.collection('sensor_readings').aggregate([
  { $match: { sensor_id: { $in: sensorIds } } },
  { $sort: { sensor_id: 1, timestamp: -1 } },
  { $group: {
      _id: "$sensor_id",
      latest: { $first: "$$ROOT" }
    }
  }
]).toArray();

// Option 2: Materialized view pattern - maintain a separate collection
// 'latest_sensor_readings' updated on each sensor data ingestion
const latestReadings = await mongodb.collection('latest_sensor_readings')
  .find({ sensor_id: { $in: sensorIds } })
  .toArray();
```

The materialized view approach (Option 2) is recommended for production as it reduces dashboard latency to O(1) regardless of sensor count.

---

### C-2: Missing Database Indexes

**Location**: Section 4 - Data Models

**Issue Description**:
The design document does not specify database indexes for frequently queried columns. Critical missing indexes:

**PostgreSQL:**
- `sensors.farm_id` - queried on every dashboard load
- `farms.user_id` - queried for user's farm list retrieval
- `irrigation_schedules.farm_id` - queried on dashboard load
- `users.email` - queried during authentication

**MongoDB:**
- `sensor_readings.sensor_id` + `timestamp` (compound index) - used in all history queries
- `sensor_readings.timestamp` - used for time-range queries

**Performance Impact**:
- Without indexes, PostgreSQL performs full table scans
- For 1000+ farms/10000+ sensors, query time degrades from milliseconds to seconds
- MongoDB time-series queries without compound index on `(sensor_id, timestamp)` result in collection scans
- Dashboard 3-second SLA becomes unachievable as data volume grows

**Recommendation**:
Add explicit index definitions to the design:

**PostgreSQL indexes:**
```sql
CREATE INDEX idx_sensors_farm_id ON sensors(farm_id);
CREATE INDEX idx_farms_user_id ON farms(user_id);
CREATE INDEX idx_irrigation_schedules_farm_id ON irrigation_schedules(farm_id);
CREATE INDEX idx_users_email ON users(email);
```

**MongoDB indexes:**
```javascript
db.sensor_readings.createIndex({ sensor_id: 1, timestamp: -1 });
db.sensor_readings.createIndex({ timestamp: 1 });
```

Consider adding a TTL index on `sensor_readings.timestamp` for automated data lifecycle management.

---

### C-3: Unbounded Time-Series Data Growth Without Lifecycle Management

**Location**: Section 4 - MongoDB sensor_readings collection

**Issue Description**:
The MongoDB `sensor_readings` collection stores all sensor data indefinitely with no retention or archival policy specified. Given:
- 100-200 sensors per large farm
- Data ingestion at 1 message/second per sensor = 17.3 million records/day for 200 sensors
- ~1KB per document = 17.3GB/day of raw data

**Performance Impact**:
- DocumentDB storage costs escalate rapidly (estimated $5000+/month after 1 year)
- Query performance degrades as collection size grows to billions of documents
- Index size grows proportionally, consuming memory and slowing lookups
- Backup/restore operations become prohibitively slow

**Recommendation**:
Implement a tiered data lifecycle management strategy:

1. **Hot data (recent 30 days)**: Full granularity in MongoDB
   - Apply TTL index: `db.sensor_readings.createIndex({ timestamp: 1 }, { expireAfterSeconds: 2592000 })`

2. **Warm data (30-365 days)**: Aggregated hourly/daily summaries
   - Batch job aggregates old data into summary documents
   - Store in separate `sensor_readings_aggregated` collection
   - Reduces storage by ~95% while preserving trends

3. **Cold data (>365 days)**: Archive to S3 Glacier
   - Export via scheduled batch job
   - Delete from DocumentDB after archive confirmation

Add monitoring for collection size and query performance metrics to trigger optimization actions.

---

### C-4: Single Point of Failure - Single EC2 Instance Architecture

**Location**: Section 2 (Technology Stack) and Section 3 (Architecture Design)

**Issue Description**:
The entire application stack runs on a single `t3.medium` EC2 instance:
- Data Ingestion Service
- API Gateway
- Analytics Service
- Report Generator
- Alert Notifier

**Performance Impact**:
- No fault tolerance: any instance failure results in complete service outage
- Cannot handle traffic spikes (e.g., all farmers checking dashboards during morning hours)
- CPU/memory contention between MQTT ingestion and API requests
- 99.0% availability target (Section 7) requires <87 hours downtime/year, but single-instance MTTR typically exceeds this
- No ability to scale horizontally as user/sensor count grows

**Recommendation**:
Redesign for high availability and horizontal scalability:

1. **Immediate improvement (minimal architecture change)**:
   - Deploy Auto Scaling Group with min 2 instances behind Application Load Balancer
   - Move MQTT broker to AWS IoT Core (managed, auto-scaling)
   - Use ElastiCache Redis for session state sharing

2. **Production-grade architecture**:
   - Separate service tiers:
     * Data ingestion tier (dedicated EC2 instances or Lambda for MQTT handling)
     * API tier (Auto Scaling Group, 2-10 instances)
     * Background job tier (separate worker instances for report generation)
   - Implement health checks and automatic failover
   - Use RDS Multi-AZ for database high availability

3. **Cost optimization for initial deployment**:
   - Start with 2× t3.small instances (cheaper than 1× t3.medium, provides redundancy)
   - Gradually scale up based on actual traffic patterns

---

## Significant Performance Issues

### S-1: Missing Pagination for Sensor History Queries

**Location**: Section 5 - `/api/farms/:farmId/sensor-history/:sensorId` implementation (lines 151-166)

**Issue Description**:
The sensor history endpoint retrieves all readings within a date range without pagination:

```javascript
.find({ sensor_id: parseInt(sensorId), timestamp: { $gte: new Date(start_date), $lte: new Date(end_date) } })
.sort({ timestamp: 1 })
.toArray();
```

For a 1-year date range request:
- 1 reading/second = 31.5 million records
- Even with network compression, response size exceeds 30MB
- Query execution time: 10+ seconds
- Client-side memory exhaustion risk

**Performance Impact**:
- API timeout on wide date ranges
- Poor user experience with multi-second page loads
- Potential DoS vector via intentional wide-range queries
- Excessive network bandwidth consumption

**Recommendation**:
Implement cursor-based pagination with reasonable defaults:

```javascript
app.get('/api/farms/:farmId/sensor-history/:sensorId', async (req, res) => {
  const { sensorId } = req.params;
  const { start_date, end_date, limit = 1000, cursor } = req.query;

  const query = {
    sensor_id: parseInt(sensorId),
    timestamp: { $gte: new Date(start_date), $lte: new Date(end_date) }
  };

  if (cursor) {
    query._id = { $gt: new ObjectId(cursor) };
  }

  const readings = await mongodb.collection('sensor_readings')
    .find(query)
    .sort({ timestamp: 1 })
    .limit(parseInt(limit))
    .toArray();

  const nextCursor = readings.length === parseInt(limit)
    ? readings[readings.length - 1]._id
    : null;

  res.json({
    readings,
    pagination: { next_cursor: nextCursor, has_more: !!nextCursor }
  });
});
```

Consider additional optimizations:
- Default to last 24 hours if no date range specified
- Enforce maximum date range (e.g., 90 days per request)
- Implement data downsampling for visualization (return hourly averages instead of raw readings for >7 day ranges)

---

### S-2: Synchronous External API Calls in Request Path

**Location**: Section 1 - "収穫予測: 過去データと気象データに基づく収穫時期・収量予測"

**Issue Description**:
The harvest prediction feature requires external weather data from OpenWeatherMap API (Section 2), which is likely called synchronously during the `/api/farms/:farmId/harvest-prediction` request. External API characteristics:
- Typical latency: 200-500ms
- Risk of timeout or rate limiting
- No control over availability

**Performance Impact**:
- User-facing request latency increases by external API response time
- Cascade failures if OpenWeatherMap is down or slow
- Rate limit exhaustion with multiple concurrent requests
- Poor user experience during API degradation

**Recommendation**:
Decouple external API calls from user request path:

1. **Background cache refresh pattern**:
```javascript
// Scheduled job (every 6 hours)
async function refreshWeatherCache() {
  const farms = await db.query('SELECT id, location FROM farms');

  for (const farm of farms.rows) {
    try {
      const weather = await openWeatherMap.getForecast(farm.location);
      await redis.setex(`weather:${farm.id}`, 21600, JSON.stringify(weather));
    } catch (error) {
      logger.error(`Weather fetch failed for farm ${farm.id}`, error);
    }
  }
}

// API endpoint uses cached data
app.get('/api/farms/:farmId/harvest-prediction', async (req, res) => {
  const cachedWeather = await redis.get(`weather:${farmId}`);
  const weather = cachedWeather ? JSON.parse(cachedWeather) : null;

  // Generate prediction using cached weather data
  const prediction = await analyticsService.predictHarvest(farmId, weather);
  res.json(prediction);
});
```

2. **Async update with stale data fallback**:
   - Serve cached prediction immediately
   - Trigger background refresh if data is >1 hour old
   - Return `is_updating: true` flag to UI for progress indication

3. **Error handling**:
   - Implement circuit breaker pattern to prevent cascade failures
   - Set aggressive timeout (5 seconds) for external API calls
   - Provide degraded service (prediction without weather data) during API outage

---

### S-3: Missing Connection Pooling Configuration

**Location**: Section 2 (Technology Stack) - PostgreSQL and MongoDB connections not specified

**Issue Description**:
The design does not specify connection pooling configuration for PostgreSQL or MongoDB. Default Node.js database clients often use minimal pooling (e.g., `pg` defaults to 10 connections), which is insufficient for:
- 100+ concurrent API requests during peak hours
- Simultaneous MQTT data ingestion from 100-200 sensors
- Background jobs (report generation, analytics)

**Performance Impact**:
- Connection exhaustion leads to request queuing and timeouts
- Creating new connections on-demand adds 50-100ms latency per request
- Database CPU spikes from excessive connection churn
- API failure cascades during traffic spikes

**Recommendation**:
Explicitly configure connection pooling based on workload:

**PostgreSQL (using `pg` library):**
```javascript
const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  max: 50,  // Maximum pool size
  min: 10,  // Minimum idle connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});
```

**MongoDB (using official driver):**
```javascript
const { MongoClient } = require('mongodb');
const client = new MongoClient(process.env.MONGODB_URI, {
  maxPoolSize: 100,
  minPoolSize: 20,
  maxIdleTimeMS: 60000,
  serverSelectionTimeoutMS: 5000,
});
```

**Sizing guidelines**:
- PostgreSQL pool: 20-50 connections (API concurrency + background workers + MQTT ingestion)
- MongoDB pool: 50-100 connections (higher due to time-series write volume)
- Monitor `pg_stat_activity` and MongoDB connection metrics to tune

Implement connection pool monitoring with alerts for:
- Pool utilization >80%
- Connection wait queue depth
- Connection acquisition timeout errors

---

### S-4: Stateful MQTT Broker Prevents Horizontal Scaling

**Location**: Section 3 - Architecture Design, MQTT Broker component

**Issue Description**:
The design uses an MQTT broker (presumably Mosquitto or similar) running on the single EC2 instance. MQTT is inherently stateful:
- Each sensor maintains persistent WebSocket/TCP connection to broker
- Broker tracks subscriptions and QoS message delivery state
- Connection affinity required for message routing

**Performance Impact**:
- Cannot add API server instances without complex MQTT broker clustering
- Single broker becomes bottleneck as sensor count grows (typically 5000-10000 connections per instance)
- Broker restart disconnects all sensors, causing data loss during reconnection
- Memory consumption grows linearly with sensor count

**Recommendation**:
Migrate to managed IoT service with built-in horizontal scaling:

**Option 1: AWS IoT Core (recommended)**
- Supports millions of concurrent connections
- Auto-scales automatically
- Built-in device authentication and authorization
- Direct integration with AWS services (Lambda, Kinesis, S3)
- Pay only for messages, not infrastructure

**Migration path:**
```javascript
// Replace MQTT broker with IoT Core
// 1. Create IoT Rule to invoke Lambda on message
{
  "sql": "SELECT * FROM 'sensor/+/data'",
  "actions": [{
    "lambda": {
      "functionArn": "arn:aws:lambda:region:account:function:ProcessSensorData"
    }
  }]
}

// 2. Lambda function writes to MongoDB
exports.handler = async (event) => {
  const { sensor_id, value, timestamp, unit } = event;
  await mongodb.collection('sensor_readings').insertOne({
    sensor_id, value, timestamp: new Date(timestamp), unit
  });
};
```

**Option 2: Self-hosted MQTT cluster (if AWS IoT Core cost is prohibitive)**
- Use EMQX or HiveMQ with cluster mode
- Implement sticky sessions via load balancer
- Requires expertise in MQTT cluster management

**Cost comparison:**
- AWS IoT Core: ~$5/1M messages + $0.08/1M action invocations
  * For 100 sensors × 86400 msg/day = 8.64M msg/month = $43/month
- Self-hosted MQTT cluster: 2× t3.medium instances = $120/month + operational overhead

AWS IoT Core is recommended for simplicity and cost-effectiveness.

---

### S-5: Missing Caching Strategy for Dashboard Data

**Location**: Section 5 - Dashboard API, no caching mentioned

**Issue Description**:
The dashboard endpoint (`/api/farms/:farmId/dashboard`) aggregates data from multiple sources (farms, sensors, readings, schedules) on every request. For frequently accessed data:
- Farm metadata rarely changes
- Sensor list changes only when devices are added/removed
- Current readings update every 1-60 seconds

Without caching, every dashboard refresh triggers 3+ database queries even when underlying data hasn't changed.

**Performance Impact**:
- Redundant database load for static data
- Increased API latency (50-100ms for cached vs 200-500ms for database queries)
- Database connection pool exhaustion during peak traffic
- Higher RDS costs due to unnecessary IOPS consumption

**Recommendation**:
Implement tiered caching strategy using Redis:

```javascript
const redis = require('redis').createClient();

app.get('/api/farms/:farmId/dashboard', async (req, res) => {
  const { farmId } = req.params;

  // Try cache first
  const cached = await redis.get(`dashboard:${farmId}`);
  if (cached) {
    return res.json(JSON.parse(cached));
  }

  // Cache miss - fetch from database (existing logic)
  const farm = await db.query('SELECT * FROM farms WHERE id = $1', [farmId]);
  const sensors = await db.query('SELECT * FROM sensors WHERE farm_id = $1', [farmId]);

  // Fetch latest readings (use optimized batch query from C-1 fix)
  const sensorIds = sensors.rows.map(s => s.id);
  const latestReadings = await mongodb.collection('latest_sensor_readings')
    .find({ sensor_id: { $in: sensorIds } })
    .toArray();

  const schedules = await db.query('SELECT * FROM irrigation_schedules WHERE farm_id = $1', [farmId]);

  const response = {
    farm: farm.rows[0],
    sensors: sensors.rows,
    current_readings: latestReadings,
    irrigation_schedules: schedules.rows
  };

  // Cache for 30 seconds
  await redis.setex(`dashboard:${farmId}`, 30, JSON.stringify(response));

  res.json(response);
});
```

**Cache invalidation strategy:**
- Dashboard data: 30-second TTL (balances freshness and cache hit rate)
- Farm/sensor metadata: 5-minute TTL + explicit invalidation on updates
- User permissions: 15-minute TTL + invalidation on role changes

**Additional considerations:**
- Implement cache warming for frequently accessed farms during off-peak hours
- Use Redis Cluster for high availability
- Monitor cache hit rate (target >80%) and tune TTL values

---

### S-6: Report Generation Blocks RabbitMQ Worker Queue

**Location**: Section 3 - Report Generator component, Section 1 - "週次・月次の圃場状態レポート"

**Issue Description**:
Report generation is handled via RabbitMQ asynchronous jobs, but the design doesn't specify:
- Job priority or queue separation
- Timeout/retry configuration
- Resource limits per job

Monthly reports for 200-sensor farms likely require:
- Aggregating 500M+ sensor readings
- Generating statistical analysis
- Rendering PDF/Excel file
- Potential execution time: 5-30 minutes

If high-priority alerts share the same RabbitMQ queue, long-running report jobs block critical notifications.

**Performance Impact**:
- Alert delays of minutes/hours if report jobs monopolize workers
- Resource starvation as memory-intensive report jobs consume all worker capacity
- No SLA guarantee for time-sensitive operations
- Job timeout leads to partial reports and wasted computation

**Recommendation**:
Implement queue separation and resource management:

**1. Separate queues by priority:**
```javascript
// High priority queue for alerts
channel.assertQueue('alerts', { durable: true, priority: 10 });
channel.consume('alerts', handleAlert, { prefetch: 5 });

// Medium priority queue for on-demand reports
channel.assertQueue('reports_ondemand', { durable: true, priority: 5 });
channel.consume('reports_ondemand', handleReport, { prefetch: 1 });

// Low priority queue for scheduled batch reports
channel.assertQueue('reports_batch', { durable: true, priority: 1 });
channel.consume('reports_batch', handleBatchReport, { prefetch: 1 });
```

**2. Implement job timeout and checkpointing:**
```javascript
async function handleReport(msg) {
  const { farmId, reportType, dateRange } = JSON.parse(msg.content);
  const timeout = 30 * 60 * 1000; // 30 minutes

  try {
    await Promise.race([
      generateReport(farmId, reportType, dateRange),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Report timeout')), timeout)
      )
    ]);
    channel.ack(msg);
  } catch (error) {
    if (error.message === 'Report timeout') {
      // Implement retry with exponential backoff
      channel.nack(msg, false, true);
    } else {
      channel.nack(msg, false, false);
      await logFailedJob(farmId, error);
    }
  }
}
```

**3. Optimize report generation performance:**
- Use pre-aggregated data from warm/cold tier (see C-3)
- Stream results instead of loading all data into memory
- Implement incremental report generation (process data in chunks)
- Cache common report components (charts, summary statistics)

**4. Resource allocation:**
- Dedicated worker pool for report generation (separate from alert workers)
- Memory limit per worker: 2GB for reports, 512MB for alerts
- Horizontal scaling: Add workers during scheduled batch report windows

---

## Moderate Performance Issues

### M-1: Missing Indexes on MongoDB for Time-Range Queries

**Location**: Section 4 - MongoDB sensor_readings collection

**Issue Description**:
While covered partially in C-2, MongoDB requires specific index strategies for time-series data. The current design lacks:
- Compound index optimization for covered queries
- Index hinting strategy for complex aggregations
- Partial indexes to reduce index size

**Performance Impact**:
- Queries scanning millions of documents even with basic indexes
- Index bloat consumes memory, reducing working set
- Aggregation pipeline stages unable to use indexes effectively

**Recommendation**:
Implement MongoDB-specific index optimizations:

```javascript
// Compound index for covered queries (no document lookup needed)
db.sensor_readings.createIndex(
  { sensor_id: 1, timestamp: -1, value: 1, unit: 1 },
  { name: 'sensor_timeseries_covered' }
);

// Partial index for active sensors only (reduces index size by ~20%)
db.sensor_readings.createIndex(
  { sensor_id: 1, timestamp: -1 },
  {
    partialFilterExpression: { status: 'active' },
    name: 'active_sensor_timeseries'
  }
);

// TTL index for automatic data expiration (covered in C-3)
db.sensor_readings.createIndex(
  { timestamp: 1 },
  { expireAfterSeconds: 2592000, name: 'ttl_30days' }
);
```

**Query optimization hints:**
```javascript
// Use index hint for aggregations
const readings = await mongodb.collection('sensor_readings').aggregate([
  { $match: { sensor_id: sensorId, timestamp: { $gte: startDate } } },
  { $sort: { timestamp: -1 } },
  { $limit: 1000 }
], { hint: 'sensor_timeseries_covered' }).toArray();
```

---

### M-2: No Monitoring or Performance Metrics Collection

**Location**: Section 6 (Implementation Policies) - Logging section, Section 7 (NFR) - No monitoring specified

**Issue Description**:
The design specifies logging with Winston but does not include:
- Performance metrics collection (response time, throughput, error rate)
- Database query performance monitoring
- Infrastructure metrics (CPU, memory, disk I/O)
- Alerting thresholds for performance degradation

**Performance Impact**:
- Unable to detect gradual performance degradation
- No visibility into which endpoints/queries are slow
- Cannot proactively identify bottlenecks before user complaints
- Difficult to validate that 3-second dashboard SLA is met

**Recommendation**:
Implement comprehensive monitoring strategy:

**1. Application Performance Monitoring (APM):**
```javascript
const prometheus = require('prom-client');

// Request duration histogram
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5, 10]
});

// Middleware to track all requests
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.labels(req.method, req.route?.path || 'unknown', res.statusCode).observe(duration);
  });
  next();
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(await prometheus.register.metrics());
});
```

**2. Database query monitoring:**
```javascript
// PostgreSQL slow query logging
await db.query("ALTER SYSTEM SET log_min_duration_statement = '1000'"); // Log queries >1s

// MongoDB profiling
db.setProfilingLevel(1, { slowms: 1000 });

// Custom query wrapper with timing
async function timedQuery(query, params, context) {
  const start = Date.now();
  try {
    const result = await db.query(query, params);
    const duration = Date.now() - start;
    if (duration > 500) {
      logger.warn(`Slow query detected: ${duration}ms`, { query, context });
    }
    return result;
  } catch (error) {
    logger.error('Query failed', { query, context, error });
    throw error;
  }
}
```

**3. Infrastructure monitoring with CloudWatch:**
- EC2 metrics: CPU utilization, network throughput, disk I/O
- RDS metrics: DatabaseConnections, ReadLatency, WriteLatency, CPUUtilization
- DocumentDB metrics: DatabaseConnections, BufferCacheHitRatio, VolumeBytesUsed

**4. Alerting thresholds:**
- Dashboard response time >3s for 5 consecutive minutes
- API error rate >5% over 5-minute window
- Database connection pool utilization >80%
- MongoDB collection size >100GB (triggers data lifecycle review)
- RabbitMQ queue depth >1000 messages

**5. Tracing for distributed debugging:**
- Implement OpenTelemetry or AWS X-Ray
- Trace request flow: API → PostgreSQL → MongoDB → External API
- Identify which service/query contributes most to latency

---

### M-3: Authentication JWT Validation on Every Request

**Location**: Section 5 - "認証方式: JWT (JSON Web Token)、有効期限24時間"

**Issue Description**:
The design does not specify JWT validation strategy. Typical implementations verify signature and expiration on every API request, which involves:
- Cryptographic signature verification (~1-5ms overhead per request)
- No mention of token caching or session management

For high-throughput endpoints (sensor data retrieval, dashboard), this adds measurable latency.

**Performance Impact**:
- JWT verification adds 1-5ms to every request
- For 1000 req/sec, consumes 1-5 CPU cores just for token validation
- No ability to revoke tokens before expiration (security implication)

**Recommendation**:
Implement JWT validation with short-lived tokens + refresh tokens:

```javascript
const jwt = require('jsonwebtoken');
const redis = require('redis').createClient();

// Cache validated tokens for 5 minutes
async function validateJWT(token) {
  // Check cache first
  const cached = await redis.get(`jwt:${token}`);
  if (cached) {
    return JSON.parse(cached);
  }

  // Verify signature and expiration
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Check revocation list (for logout/security events)
    const revoked = await redis.sismember('jwt_revoked', token);
    if (revoked) {
      throw new Error('Token revoked');
    }

    // Cache for 5 minutes
    await redis.setex(`jwt:${token}`, 300, JSON.stringify(decoded));
    return decoded;
  } catch (error) {
    logger.warn('JWT validation failed', { error });
    throw error;
  }
}

// Middleware
async function authenticate(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: { code: 'NO_TOKEN', message: 'Authentication required' } });
  }

  try {
    req.user = await validateJWT(token);
    next();
  } catch (error) {
    res.status(401).json({ error: { code: 'INVALID_TOKEN', message: 'Token invalid or expired' } });
  }
}
```

**Additional improvements:**
- Use short-lived access tokens (15 minutes) + long-lived refresh tokens (7 days)
- Implement token revocation via Redis set for immediate logout
- Consider API key authentication for IoT devices (simpler, no expiration)

---

### M-4: Inefficient JSONB Query Pattern for Irrigation Triggers

**Location**: Section 4 - irrigation_schedules.trigger_condition JSONB column

**Issue Description**:
The irrigation schedule uses JSONB column for trigger conditions but doesn't specify:
- Index on JSONB fields
- Query pattern for evaluating triggers

Typical usage involves querying all schedules where `trigger_condition->>'soil_moisture_threshold'` matches current sensor reading. Without GIN/GiST index, this requires full table scan and JSON parsing for every row.

**Performance Impact**:
- Evaluating irrigation triggers on every sensor reading becomes O(n) operation
- For 1000 schedules, each sensor update triggers milliseconds of CPU-intensive JSON parsing
- No index support means 100+ sensor updates/sec cause sustained high database CPU

**Recommendation**:
Normalize trigger conditions or add specialized indexes:

**Option 1: Normalize (recommended for performance-critical queries):**
```sql
CREATE TABLE irrigation_triggers (
  id SERIAL PRIMARY KEY,
  schedule_id INTEGER REFERENCES irrigation_schedules(id),
  trigger_type VARCHAR(50) NOT NULL, -- 'soil_moisture_threshold', 'temperature_range', etc.
  sensor_id INTEGER REFERENCES sensors(id),
  threshold_value DECIMAL,
  comparison_operator VARCHAR(10), -- '>', '<', '>=', '<=', '=='
  INDEX idx_triggers_sensor (sensor_id, trigger_type)
);
```

**Option 2: JSONB with GIN index (simpler migration):**
```sql
-- Add GIN index for JSONB containment queries
CREATE INDEX idx_irrigation_triggers_gin ON irrigation_schedules USING GIN (trigger_condition);

-- Query pattern
SELECT * FROM irrigation_schedules
WHERE trigger_condition @> '{"sensor_type": "soil_moisture"}';
```

**Evaluation logic optimization:**
```javascript
// Cache active triggers in memory (refreshed every 5 minutes)
let activeTriggers = [];

async function refreshTriggerCache() {
  activeTriggers = await db.query(`
    SELECT s.id, s.farm_id, t.sensor_id, t.threshold_value, t.comparison_operator
    FROM irrigation_schedules s
    JOIN irrigation_triggers t ON t.schedule_id = s.id
    WHERE s.active = true
  `);
}

// Efficient trigger evaluation on sensor reading
async function evaluateTriggers(sensorId, value) {
  const triggers = activeTriggers.filter(t => t.sensor_id === sensorId);

  for (const trigger of triggers) {
    if (evaluateCondition(value, trigger.comparison_operator, trigger.threshold_value)) {
      await executeIrrigation(trigger.farm_id, trigger.id);
    }
  }
}
```

---

### M-5: No Rate Limiting or Throttling Strategy

**Location**: Section 5 - API Design, no rate limiting mentioned

**Issue Description**:
The API design does not specify rate limiting or throttling mechanisms. Without protection:
- Single user can overwhelm the API with excessive requests
- Accidental infinite loops in client code cause service degradation
- No defense against denial-of-service attacks

**Performance Impact**:
- Legitimate users experience slowness during abusive traffic
- Database connection pool exhaustion
- Increased infrastructure costs from handling unnecessary traffic
- No way to enforce fair usage across tenants

**Recommendation**:
Implement multi-tier rate limiting:

```javascript
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');

// Global rate limiter - protect against DDoS
const globalLimiter = rateLimit({
  store: new RedisStore({ client: redis }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // 1000 requests per 15min per IP
  message: { error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many requests' } },
  standardHeaders: true,
  legacyHeaders: false,
});

// Per-user rate limiter - enforce fair usage
const userLimiter = rateLimit({
  store: new RedisStore({ client: redis }),
  windowMs: 60 * 1000, // 1 minute
  max: 60, // 60 requests per minute per user
  keyGenerator: (req) => req.user.id,
  skip: (req) => !req.user, // Skip for unauthenticated requests
});

// Expensive endpoint limiter - protect resource-intensive operations
const reportLimiter = rateLimit({
  store: new RedisStore({ client: redis }),
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // 5 report generations per hour per user
  keyGenerator: (req) => req.user.id,
});

// Apply limiters
app.use(globalLimiter);
app.use('/api', userLimiter);
app.post('/api/reports/:farmId/generate', reportLimiter, generateReport);
```

**Tiered limits by user role:**
- Free tier: 100 req/hour
- Paid tier: 1000 req/hour
- Enterprise: 10000 req/hour

**Additional considerations:**
- Implement exponential backoff guidance in API documentation
- Return `Retry-After` header for 429 responses
- Whitelist internal services/monitoring probes
- Monitor rate limit hit rate to tune thresholds

---

## Minor Improvements and Positive Aspects

### Positive Aspects

**P-1: Appropriate Database Selection**
The design correctly uses PostgreSQL for relational data (users, farms, sensors) and MongoDB for time-series sensor readings. This hybrid approach leverages the strengths of each database type.

**P-2: Asynchronous Job Queue**
Using RabbitMQ for report generation and potentially alerts is a good architectural decision that prevents blocking user-facing requests.

**P-3: Explicit NFR Targets**
The document specifies concrete performance targets (3-second dashboard, 1000 msg/sec ingestion), which provides clear acceptance criteria.

**P-4: JWT Authentication**
JWT-based authentication is a reasonable choice for stateless API authentication, though implementation details need refinement (see M-3).

---

### Minor Optimization Opportunities

**O-1: Consider MongoDB Time-Series Collections**
MongoDB 5.0+ offers native time-series collections optimized for sensor data. This would provide:
- Better compression (~10× vs regular collections)
- Optimized query patterns for time-range queries
- Automatic bucketing and aggregation

**Migration recommendation:**
```javascript
db.createCollection("sensor_readings", {
  timeseries: {
    timeField: "timestamp",
    metaField: "sensor_id",
    granularity: "seconds"
  }
});
```

**O-2: WebSocket for Real-Time Dashboard Updates**
Instead of polling the dashboard API, consider WebSocket/Server-Sent Events for pushing sensor updates to connected clients. This reduces:
- Unnecessary API requests when data hasn't changed
- Database load from repeated queries
- Network bandwidth from unchanged response payloads

**O-3: Lazy Loading for Dashboard Components**
The dashboard loads all data upfront. Consider:
- Render critical data first (current sensor values)
- Lazy load historical charts on user interaction
- Implement infinite scroll for sensor lists on large farms

---

## Summary

This design document exhibits **multiple critical and significant performance issues** that will prevent the system from meeting its stated 3-second dashboard response target and 1000 msg/sec ingestion capacity, especially as the system scales beyond initial deployment.

**Critical priorities for revision:**
1. **Fix N+1 query antipattern** in dashboard API (C-1) - blocks production readiness
2. **Add database indexes** (C-2) - required for acceptable query performance
3. **Implement data lifecycle management** (C-3) - prevents runaway costs
4. **Redesign single-instance architecture** (C-4) - required for availability SLA

**High-impact improvements:**
- Add pagination to sensor history queries (S-1)
- Decouple external API calls from request path (S-2)
- Configure connection pooling (S-3)
- Migrate to managed IoT service (S-4)
- Implement dashboard caching (S-5)

The design shows good fundamentals (appropriate technology choices, async job processing) but lacks production-grade performance engineering. Addressing the critical and significant issues above will transform this from a prototype-grade design to a production-ready architecture.
