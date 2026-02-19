# Performance Design Review: Smart Agriculture IoT Platform

## Document Structure Analysis

The design document provides comprehensive coverage across the following areas:
- **Requirements**: User types, feature scope, and scale expectations clearly defined
- **Technical Stack**: Backend, databases, messaging, infrastructure, frontend specified
- **Architecture**: Component diagram and service breakdown provided
- **Data Models**: PostgreSQL and MongoDB schemas detailed
- **API Design**: Endpoints with implementation examples included
- **NFRs**: Performance targets, security requirements, availability goals specified
- **Implementation**: Error handling, logging, testing, deployment approaches outlined

**Missing or Underspecified Areas**:
- Monitoring and observability strategy (mentioned in logging but no metrics/alerting details)
- Capacity planning for data growth and connection scaling
- Caching strategies
- Index design for databases
- Horizontal scaling approach for single EC2 instance architecture
- Real-time WebSocket/event-driven notification architecture

## Performance Issue Detection

### Critical Issues

#### C-1: Severe N+1 Query Problem in Dashboard Endpoint (Lines 118-146)

**Issue**: The `/api/farms/:farmId/dashboard` endpoint executes individual MongoDB queries for each sensor in a loop (lines 129-136). For large agricultural corporations with 50-200 sensors per farm, this creates 50-200 sequential database queries.

**Performance Impact**:
- At 200 sensors with 20ms average MongoDB query latency: **4000ms+ response time**
- Far exceeds the 3-second SLA specified in line 194
- Creates exponential load growth as customer base scales
- Each dashboard refresh generates hundreds of database connections

**Code Evidence**:
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

**Recommendation**: Replace with batch query using `$in` operator:
```javascript
const sensorIds = sensors.rows.map(s => s.id);
const latestReadings = await mongodb.collection('sensor_readings').aggregate([
  { $match: { sensor_id: { $in: sensorIds } } },
  { $sort: { sensor_id: 1, timestamp: -1 } },
  { $group: { _id: "$sensor_id", latest: { $first: "$$ROOT" } } }
]).toArray();
```

This reduces 200 queries to 1 aggregation pipeline, achieving <500ms response time even for large farms.

#### C-2: Unbounded Query Without Pagination in Sensor History (Lines 150-166)

**Issue**: The `/api/farms/:farmId/sensor-history/:sensorId` endpoint loads all sensor readings within a date range with no result limit or pagination mechanism.

**Performance Impact**:
- At 1 reading/minute for 30 days: 43,200 records × 200 sensors = 8.64M records/farm
- A 1-year query returns 525,600 records, potentially **100MB+ response payload**
- Memory exhaustion on single t3.medium instance (4GB RAM)
- Network bandwidth saturation
- Browser crash on frontend rendering

**Recommendation**: Implement mandatory pagination with reasonable defaults:
```javascript
const page = parseInt(req.query.page) || 1;
const limit = Math.min(parseInt(req.query.limit) || 1000, 10000); // cap at 10k
const skip = (page - 1) * limit;

const readings = await mongodb.collection('sensor_readings')
  .find({ /* ... */ })
  .sort({ timestamp: 1 })
  .skip(skip)
  .limit(limit)
  .toArray();

const total = await mongodb.collection('sensor_readings').countDocuments({ /* ... */ });

res.json({
  readings,
  pagination: { page, limit, total, pages: Math.ceil(total / limit) }
});
```

Additionally, implement data aggregation for long date ranges (e.g., hourly averages for >7 days, daily averages for >30 days).

#### C-3: Single Point of Failure with No Horizontal Scaling Strategy (Line 26)

**Issue**: The architecture deploys all services on a single t3.medium EC2 instance with no horizontal scaling design.

**Performance Impact**:
- **CPU bottleneck**: t3.medium (2 vCPUs) cannot handle concurrent:
  - 1000 msg/sec sensor ingestion (line 193)
  - 100+ concurrent dashboard API requests from agricultural corporations
  - Background jobs (report generation, harvest prediction analytics)
- **Memory saturation**: 4GB RAM shared between Node.js, MQTT broker, and RabbitMQ
- **No failover**: Single instance failure causes complete service outage, violating 99.0% availability target (line 202)
- **Cannot meet throughput SLA** during peak usage (morning hours when farmers check dashboards)

**Recommendation**: Redesign for horizontal scalability:

1. **Stateless API tier**: Deploy API Gateway on auto-scaling EC2/ECS behind ALB (target 3+ instances)
2. **Dedicated data ingestion service**: Separate MQTT/data ingestion workers from API servers
3. **Managed services**:
   - Use AWS IoT Core for MQTT (eliminates MQTT broker SPOF)
   - Use Amazon MQ for RabbitMQ (managed, HA)
   - Already using RDS/DocumentDB (managed, but verify Multi-AZ enabled)
4. **Capacity planning**: Define scaling triggers (CPU >70%, memory >80%, API p99 latency >2s)

This architecture supports 10x traffic growth and achieves 99.9% availability.

#### C-4: Missing Database Indexes for Critical Query Paths

**Issue**: No index definitions provided for PostgreSQL or MongoDB, despite frequent queries on foreign keys and timestamp ranges.

**Performance Impact**:
- **PostgreSQL full table scans**:
  - `sensors WHERE farm_id = ?` (line 125) → O(n) scan as farms grow to thousands of sensors
  - `irrigation_schedules WHERE farm_id = ?` (line 139) → unindexed FK lookup
- **MongoDB collection scans**:
  - `sensor_readings WHERE sensor_id = ? AND timestamp BETWEEN ? AND ?` (lines 131-134, 157-159) → O(n) scan on time-series data
  - At 43k readings/sensor/month, queries scan entire collection without compound index

**Expected degradation**: Query latency grows from <50ms (small dataset) to >5000ms (production scale), making 3-second SLA impossible.

**Recommendation**: Create the following indexes immediately:

**PostgreSQL**:
```sql
CREATE INDEX idx_sensors_farm_id ON sensors(farm_id) WHERE status = 'active';
CREATE INDEX idx_irrigation_schedules_farm_id ON irrigation_schedules(farm_id);
CREATE INDEX idx_farms_user_id ON farms(user_id);
```

**MongoDB**:
```javascript
db.sensor_readings.createIndex({ sensor_id: 1, timestamp: -1 });
// Supports both latest-value queries (C-1) and time-range queries (C-2)
```

These indexes reduce query complexity from O(n) to O(log n) and are essential for meeting performance SLAs.

#### C-5: Missing Timeout and Connection Pool Configurations

**Issue**: No timeout settings or connection pool management specified for:
- MongoDB client connections (used in every API request)
- PostgreSQL connections (via node-pg)
- OpenWeatherMap API calls (line 28)
- MQTT broker connections

**Performance Impact**:
- **Resource exhaustion**: Unlimited concurrent connections consume all available database connections (default PostgreSQL max_connections=100)
- **Cascading failures**: Hanging external API calls (OpenWeatherMap timeout) block Node.js event loop
- **Connection leak**: Unclosed connections accumulate until service crashes
- **Unpredictable latency**: No circuit breaker for slow external dependencies

**Recommendation**: Configure resource limits and timeouts:

```javascript
// PostgreSQL connection pool
const pool = new Pool({
  max: 20, // limit connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000
});

// MongoDB connection pool
const mongoClient = new MongoClient(uri, {
  maxPoolSize: 50,
  minPoolSize: 5,
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000
});

// External API with timeout and retry
const axios = require('axios');
const weatherClient = axios.create({
  baseURL: 'https://api.openweathermap.org',
  timeout: 5000,
  retry: 3,
  retryDelay: 1000
});
```

Additionally, implement circuit breaker pattern (e.g., using `opossum` library) for OpenWeatherMap API to prevent cascading failures when external service degrades.

### Significant Issues

#### S-1: Synchronous Report Generation Blocking Request Thread (Line 114)

**Issue**: `POST /api/reports/:farmId/generate` endpoint design mentions RabbitMQ for async execution (line 50), but no explicit async response pattern documented. Risk of synchronous execution blocking API thread.

**Performance Impact**:
- Report generation likely involves:
  - Aggregating 30+ days of sensor data (millions of records)
  - Weather API calls
  - PDF rendering
- Estimated processing time: **30-60 seconds**
- If synchronous: blocks Node.js event loop, causing all other API requests to queue
- Under load, cascading timeout failures across entire API surface

**Recommendation**: Implement explicit async job pattern:

```javascript
// API immediately returns job ID
app.post('/api/reports/:farmId/generate', async (req, res) => {
  const jobId = uuid();
  await rabbitmq.sendToQueue('report_generation', {
    jobId,
    farmId: req.params.farmId,
    userId: req.user.id
  });
  res.status(202).json({ jobId, status: 'queued' });
});

// Polling endpoint for job status
app.get('/api/jobs/:jobId', async (req, res) => {
  const job = await getJobStatus(req.params.jobId);
  res.json(job); // { status: 'pending'|'completed'|'failed', result: {...} }
});
```

This decouples long-running operations from user-facing request threads, preventing performance degradation under load.

#### S-2: Real-Time Alert System Architecture Undefined

**Issue**: "Alert Notifier" component mentioned (line 51) but no architecture details for:
- How threshold violations are detected in real-time
- Whether alerts use polling or event-driven pattern
- How 1000 msg/sec sensor stream is monitored for anomalies

**Performance Impact**:
- **Polling antipattern risk**: If alerts poll MongoDB every N seconds for threshold checks:
  - At 200 sensors × 10-second polling interval = 20 queries/sec per farm
  - Scales to 2000 queries/sec for 100 farms, overwhelming database
- **Stream processing gap**: No mechanism to detect anomalies in 1000 msg/sec ingestion stream without database round-trip latency
- **Notification fanout**: No strategy for broadcasting alerts to multiple users per farm

**Recommendation**: Implement event-driven alerting using stream processing:

```javascript
// In Data Ingestion Service, check thresholds on ingestion
mqttClient.on('message', async (topic, message) => {
  const reading = JSON.parse(message);

  // Check alert conditions in-memory (no DB query)
  const threshold = await cache.get(`threshold:${reading.sensor_id}`); // Redis cache
  if (reading.value > threshold.max || reading.value < threshold.min) {
    await rabbitmq.publish('alerts', {
      sensor_id: reading.sensor_id,
      value: reading.value,
      threshold,
      timestamp: reading.timestamp
    });
  }

  await mongodb.insertOne('sensor_readings', reading);
});
```

Use Redis to cache alert thresholds (loaded from PostgreSQL on startup + invalidation on updates) to avoid database lookups on every message. This achieves <10ms alert detection latency at 1000 msg/sec throughput.

#### S-3: Harvest Prediction Analytics Performance Unspecified (Line 112)

**Issue**: `/api/farms/:farmId/harvest-prediction` endpoint functionality described (lines 13, 112) but no implementation details or performance characteristics.

**Performance Impact Risk**:
- Machine learning inference on months of historical sensor data + weather data likely requires **10-60 seconds**
- If synchronous: blocks API thread (same issue as S-1)
- If uncached: every dashboard refresh triggers expensive ML computation
- For consultants managing 50+ farms: 50 × 60 sec = **50 minutes** to load overview dashboard

**Recommendation**: Implement hybrid caching + async computation:

```javascript
app.get('/api/farms/:farmId/harvest-prediction', async (req, res) => {
  // Check cache (updated daily via background job)
  const cached = await cache.get(`prediction:${req.params.farmId}`);
  if (cached && Date.now() - cached.timestamp < 24 * 3600 * 1000) {
    return res.json(cached);
  }

  // If no cache, trigger async computation and return stale data or placeholder
  const jobId = await triggerPredictionJob(req.params.farmId);
  res.status(202).json({
    status: 'computing',
    jobId,
    message: 'Prediction will be ready in 2-3 minutes. Refresh page or check /api/jobs/:jobId'
  });
});
```

Background job (cron daily at 2am) pre-computes predictions for all active farms, storing results in Redis cache with 24h TTL. This ensures <50ms read latency for 99% of requests.

#### S-4: Missing Data Retention and Archival Strategy

**Issue**: MongoDB stores all sensor readings indefinitely (lines 92-101) with no documented retention policy or archival mechanism.

**Performance Impact**:
- At 1 reading/min × 200 sensors × 365 days = **105M records/year/farm**
- For 100 agricultural corporation clients: **10.5 billion records** in MongoDB
- Collection size: ~1TB (assuming 100 bytes/doc)
- Query performance degrades as collection grows:
  - Index B-tree depth increases → slower lookups
  - Working set no longer fits in memory → disk I/O on every query
- DocumentDB storage costs scale linearly, exceeding cost projections

**Expected Timeline**: Performance degradation becomes severe after 6-12 months of operation.

**Recommendation**: Implement tiered data lifecycle management:

1. **Hot storage** (MongoDB): Last 90 days at full granularity (1 min)
2. **Warm storage** (S3 + Athena): 90 days - 2 years, aggregated to hourly
3. **Cold archive** (S3 Glacier): >2 years, daily aggregates, compliance retention

```javascript
// Nightly aggregation job
const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 3600 * 1000);
const hourlyAggregates = await mongodb.collection('sensor_readings').aggregate([
  { $match: { timestamp: { $lt: ninetyDaysAgo } } },
  { $group: {
    _id: {
      sensor_id: "$sensor_id",
      hour: { $dateTrunc: { date: "$timestamp", unit: "hour" } }
    },
    avg: { $avg: "$value" },
    min: { $min: "$value" },
    max: { $max: "$value" }
  }}
]).toArray();

// Export to S3, then delete from MongoDB
await s3.putObject({ Bucket, Key, Body: JSON.stringify(hourlyAggregates) });
await mongodb.collection('sensor_readings').deleteMany({ timestamp: { $lt: ninetyDaysAgo } });
```

This keeps MongoDB collection size <10GB, ensuring consistent query performance and reducing storage costs by 90%.

#### S-5: Missing Capacity Planning for Connection Scaling

**Issue**: MQTT broker must handle "100センサー同時接続" (line 193), but:
- No MQTT broker implementation specified (open-source Mosquitto? AWS IoT Core?)
- No connection limit analysis for t3.medium instance
- No plan for scaling to 200 sensors/farm × 100 farms = 20,000 persistent connections

**Performance Impact**:
- **Open-source Mosquitto on t3.medium**: Typically maxes out at ~5,000 concurrent connections before CPU saturation
- **Memory per connection**: ~20KB → 20,000 connections = 400MB+ just for connection state
- **TCP socket limits**: Default Linux ulimit (1024) would need tuning to 20,000+
- **Single instance SPOF**: If MQTT broker crashes, no sensor data is collected until manual restart

**Recommendation**: Use AWS IoT Core as managed MQTT broker:
- Supports millions of concurrent connections with auto-scaling
- Built-in device authentication and message routing to downstream services
- 99.9% SLA with automatic failover
- Direct integration with AWS services (can write to DynamoDB Streams, Lambda, Kinesis)

Architecture update:
```
[IoT Sensors] --MQTTS--> [AWS IoT Core] --IoT Rules--> [Kinesis Data Streams]
                                                              |
                                                              v
                                                    [Lambda Data Processor]
                                                              |
                                                              v
                                                    [MongoDB/DocumentDB]
```

This eliminates connection scaling concerns and improves reliability to 99.9%+ availability.

### Moderate Issues

#### M-1: Inefficient Sorting Strategy in Sensor History Query

**Issue**: Line 161 sorts MongoDB query results by `timestamp: 1` (ascending), but frontend likely displays newest-first (descending).

**Performance Impact**: If frontend reverses the array client-side, unnecessary CPU cycles wasted. More importantly, if pagination implemented (per C-2), ascending sort means page 1 shows oldest data (2026-02-01) instead of most recent (2026-02-11), forcing users to navigate to last page.

**Recommendation**: Change sort order to descending by default:
```javascript
.sort({ timestamp: -1 })
```

Add `order` query parameter if both directions needed:
```javascript
const sortOrder = req.query.order === 'asc' ? 1 : -1;
.sort({ timestamp: sortOrder })
```

#### M-2: Missing Cache-Control Headers for Static Dashboard Data

**Issue**: No caching strategy mentioned for API responses. Farm metadata (lines 122-123), sensor configurations (lines 124-125) change infrequently but are fetched on every dashboard load.

**Performance Impact**:
- Unnecessary database queries for static data
- Increased API latency (each query adds 20-50ms)
- Higher database CPU utilization

**Recommendation**: Implement HTTP caching for static endpoints:

```javascript
// Farm metadata changes rarely (only when admin updates)
app.get('/api/farms/:farmId', (req, res) => {
  res.set('Cache-Control', 'public, max-age=3600'); // 1 hour
  // ... fetch and return farm data
});

// Sensor list changes only when sensors added/removed
app.get('/api/farms/:farmId/sensors', (req, res) => {
  res.set('Cache-Control', 'public, max-age=600'); // 10 minutes
  // ... fetch and return sensors
});
```

For current sensor readings (changes every minute), use short TTL:
```javascript
res.set('Cache-Control', 'public, max-age=60'); // 1 minute
```

Additionally, implement application-level caching using Redis for frequently accessed farm metadata to reduce database load by 70-90%.

#### M-3: No Connection Pooling Verification in Code Examples

**Issue**: Code examples (lines 118-146) show `db.query()` and `mongodb.collection()` but do not demonstrate connection pool initialization or reuse pattern.

**Performance Impact**:
- Risk of creating new connection per request if developers misinterpret examples
- Connection establishment overhead: 50-100ms per connection vs <1ms for pooled connection
- Database connection exhaustion (see C-5)

**Recommendation**: Update code examples to show explicit pool initialization:

```javascript
// At application startup (not per-request)
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20
});

// In request handler
app.get('/api/farms/:farmId/dashboard', async (req, res) => {
  const client = await pool.connect();
  try {
    const farm = await client.query('SELECT * FROM farms WHERE id = $1', [farmId]);
    // ... rest of logic
  } finally {
    client.release(); // Critical: return connection to pool
  }
});
```

#### M-4: JWT Token Refresh Strategy Undefined

**Issue**: JWT expiration set to 24 hours (line 169), but no token refresh mechanism documented.

**Performance Impact**:
- Users experience sudden authentication failures after 24 hours, requiring full re-login
- During agricultural work (e.g., monitoring irrigation all day), forced logouts disrupt workflow
- Refresh token absence means more frequent authentication requests to database (user lookup + password verification)

**Recommendation**: Implement refresh token pattern:

```javascript
// Login returns both tokens
{
  accessToken: jwt.sign(payload, secret, { expiresIn: '15m' }),
  refreshToken: jwt.sign(payload, refreshSecret, { expiresIn: '7d' })
}

// Refresh endpoint (low-cost, no DB lookup)
app.post('/api/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  const payload = jwt.verify(refreshToken, refreshSecret);
  const newAccessToken = jwt.sign(payload, secret, { expiresIn: '15m' });
  res.json({ accessToken: newAccessToken });
});
```

This reduces authentication overhead by 95% (1 full auth per 7 days vs per 24 hours) and improves user experience.

#### M-5: Missing Monitoring and Observability Strategy

**Issue**: Logging specified (lines 178-180) but no mention of:
- Performance metrics collection (API latency, database query time, MQTT message processing rate)
- Alerting rules for performance degradation
- Distributed tracing for multi-service requests

**Performance Impact**:
- **Reactive instead of proactive**: Issues discovered by users (complaints) instead of monitoring alerts
- **No performance regression detection**: Deployments that degrade performance go unnoticed until SLA violations
- **Difficult root cause analysis**: When dashboard is slow, no visibility into whether bottleneck is database, MongoDB, or API processing

**Recommendation**: Implement comprehensive observability stack:

1. **Metrics**: Integrate Prometheus + Grafana or AWS CloudWatch
   - API endpoint latency (p50, p95, p99)
   - Database query duration
   - MQTT message processing rate
   - Memory/CPU utilization
   - Error rates

2. **Alerting**: Define thresholds
   - API p99 latency >2 seconds → page on-call
   - MongoDB query time >500ms → warning
   - MQTT message processing lag >60s → critical

3. **Distributed tracing**: Implement OpenTelemetry or AWS X-Ray
   - Trace request flow: API → PostgreSQL → MongoDB
   - Identify slow query hotspots automatically

```javascript
const { metrics } = require('@opentelemetry/api-metrics');
const meter = metrics.getMeter('smart-agriculture');
const apiLatency = meter.createHistogram('api.request.duration', {
  description: 'API request duration in milliseconds'
});

app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    apiLatency.record(Date.now() - start, {
      route: req.route?.path,
      method: req.method,
      status: res.statusCode
    });
  });
  next();
});
```

### Minor Improvements and Positive Aspects

#### Minor-1: Consider Prepared Statements for Repeated Queries

The code examples use parameterized queries (e.g., `$1`, line 122), which is good for SQL injection prevention. To further optimize, implement prepared statements for frequently executed queries:

```javascript
const farmByIdStmt = await client.prepare('SELECT * FROM farms WHERE id = $1');
// Reuse prepared statement (query planner optimization + reduced parsing overhead)
const farm = await farmByIdStmt.execute([farmId]);
```

#### Minor-2: Batch Sensor Data Writes for Improved Throughput

Currently, each MQTT message likely triggers individual MongoDB insert. For 1000 msg/sec (line 193), batch writes can improve throughput:

```javascript
let batchBuffer = [];
mqttClient.on('message', (topic, message) => {
  batchBuffer.push(JSON.parse(message));

  if (batchBuffer.length >= 100) {
    mongodb.collection('sensor_readings').insertMany(batchBuffer);
    batchBuffer = [];
  }
});

// Flush remaining every 1 second
setInterval(() => {
  if (batchBuffer.length > 0) {
    mongodb.collection('sensor_readings').insertMany(batchBuffer);
    batchBuffer = [];
  }
}, 1000);
```

This reduces write overhead by 10-20x while keeping latency under 1 second.

#### Positive-1: Appropriate Database Selection

Using PostgreSQL for relational data (users, farms, sensors) and MongoDB for time-series sensor readings is architecturally sound. This hybrid approach optimizes for:
- ACID transactions for user/farm management (PostgreSQL)
- High write throughput and flexible schema for sensor data (MongoDB)

#### Positive-2: Async/Await Pattern Usage

The code examples consistently use `async/await` syntax (lines 118-146), which is the modern best practice for Node.js async programming. This avoids callback hell and improves code readability.

#### Positive-3: Clear Performance SLA Definition

Line 193-194 explicitly defines performance targets ("100センサー同時接続で秒間1000メッセージ処理", "ダッシュボード表示: 3秒以内のレスポンス"). This is excellent practice for driving architectural decisions and enabling objective performance validation.

## Summary

This design document demonstrates strong foundational architecture with appropriate technology choices for an IoT time-series workload. However, **critical performance issues exist that will prevent meeting stated SLAs at production scale**:

**Must Fix Before Launch**:
- C-1: N+1 query problem (200x database calls per dashboard load)
- C-2: Unbounded queries without pagination (memory exhaustion risk)
- C-3: Single instance architecture with no horizontal scaling path (cannot meet 1000 msg/sec SLA)
- C-4: Missing database indexes (5-10x query latency degradation)
- C-5: No connection pooling or timeout configuration (resource exhaustion)

**High Priority for Production Readiness**:
- S-1: Async job pattern for long-running operations
- S-2: Event-driven alert architecture (avoid polling antipattern)
- S-4: Data retention policy (prevent MongoDB growth to 1TB+)
- S-5: MQTT broker scaling plan (AWS IoT Core recommended)

Addressing these issues will ensure the system can reliably handle the specified workload (200 sensors/farm, 1000 msg/sec, 3-second dashboard SLA) and scale to support 100+ agricultural corporation clients.
