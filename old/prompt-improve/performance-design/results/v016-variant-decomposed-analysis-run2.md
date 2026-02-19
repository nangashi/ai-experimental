# Performance Review: 企業イベント管理プラットフォーム

**Reviewer**: performance-design-reviewer (v016-variant-decomposed-analysis)
**Date**: 2026-02-11

---

## PHASE 1: Architecture Inventory

### 1. Explicitly Documented Components

- **API endpoints defined**: `/api/events`, `/api/registrations`, `/api/checkin`, `/api/surveys`, `/api/dashboard` (Section 3.2, 5.1)
- **Database schema specified**: Four main tables (events, registrations, users, survey_responses) with columns, types, and constraints defined (Section 4.1)
- **Authentication flow described**: JWT-based authentication with 24-hour token expiration (Section 5.2)
- **Technology stack specified**: Node.js, Express, Next.js, PostgreSQL, Redis, AWS services (Section 2)
- **Architecture pattern defined**: 3-tier architecture with API/Business Logic/Data Access layers (Section 3.1)
- **Service layer structure**: Five services defined (EventService, RegistrationService, CheckinService, SurveyService, NotificationService) (Section 3.2)
- **Implementation examples provided**: Registration processing, dashboard statistics, reminder batch (Section 6.1-6.3)
- **Deployment strategy**: Docker + ECS Fargate with Blue-Green deployment (Section 6.7)
- **Scalability mechanisms**: RDS Multi-AZ, ECS Auto Scaling at 70% CPU (Section 7.3)

### 2. Standard Concerns Present

- **Performance SLAs defined**: Expected load specified (500 events/month, 10,000 registrations/month, 500 concurrent users at peak) (Section 7.1)
- **Security measures specified**: HTTPS, SQL injection prevention, XSS/CSRF protection (Section 7.2)
- **High availability design**: RDS Multi-AZ configuration (Section 7.3)
- **Auto-scaling policy**: ECS Auto Scaling triggered at 70% CPU (Section 7.3)
- **Error handling strategy**: HTTP error code ranges and logging approach (Section 6.4)
- **Logging strategy**: Winston with JSON format (Section 6.5)
- **Testing strategy**: Unit/Integration/E2E test frameworks specified (Section 6.6)

### 3. Standard Concerns Absent or Incomplete

- **No caching strategy defined**: Redis is available but usage is undefined (Section 2 notes "キャッシュ戦略は未定義")
- **No data retention/archival policy**: Historical data (registrations, survey_responses) retained indefinitely (Section 7.4 explicitly states "未定義")
- **No database indexing strategy**: No indexes defined despite frequent queries by event_id, user_id, date ranges
- **No connection pooling specification**: No mention of database connection limits or pooling configuration
- **No query optimization strategy**: JOIN-heavy queries without optimization plans
- **No capacity planning details**: Auto-scaling CPU threshold (70%) provided but no memory limits, no disk I/O considerations, no network bandwidth planning
- **No monitoring/observability plan**: Logging specified but no metrics collection, alerting thresholds, or performance monitoring strategy
- **No rate limiting**: No API rate limits defined despite public-facing endpoints
- **No API pagination**: Event list endpoint (GET /api/events) returns unbounded result sets
- **No timeout/circuit breaker configuration**: No mention of timeout policies for external dependencies (SES, database)
- **No backup/disaster recovery plan**: Multi-AZ mentioned but no backup frequency, RPO/RTO targets, or disaster recovery procedures
- **No asynchronous processing strategy**: Email notifications sent synchronously in critical paths

### 4. System Scale Indicators

**Documented Scale**:
- Monthly events: 500 (~16-17 events/day)
- Monthly registrations: 10,000 (~330 registrations/day, ~20 registrations/event on average)
- Peak concurrent users: 500

**Inferred Scale from Use Cases**:
- Individual events can have capacity up to 200 participants (Section 5.1 example)
- Event statistics require aggregating all registrations per event (potentially 200+ records)
- Batch reminder processing loops through all events and all their registrations (nested loops, potentially 17 events × 20 registrations = 340 emails per batch)
- Dashboard queries join multiple tables (registrations + users + survey_responses)

**Growth Implications**:
- No mention of expected growth trajectory
- No discussion of how architecture scales beyond stated load
- No data volume projections for long-term historical data accumulation

---

## PHASE 2: Performance Issue Detection

### CRITICAL ISSUES

#### C-1: N+1 Query Problem in Reminder Batch Processing
**Location**: Section 6.3 - `sendReminders()` function

**Issue**: The reminder batch implementation has three nested loops that execute database queries:
```javascript
for (const event of events) {
  const registrations = await registrationRepository.findByEventId(event.id); // Query per event
  for (const registration of registrations) {
    const user = await userRepository.findById(registration.user_id); // Query per registration
    await ses.sendEmail(...); // Synchronous email per registration
  }
}
```

For 17 events/day × 20 registrations/event:
- **Events query**: 1
- **Registration queries**: 17 (1 per event)
- **User queries**: 340 (1 per registration)
- **Total database queries**: 358 queries executed sequentially

**Impact**:
- Batch processing time grows linearly with event count and registration count (O(n*m) complexity)
- Database connection held for extended duration during sequential queries
- High latency (assuming 10ms per query: 358 × 10ms = 3.58 seconds minimum, excluding email sending)
- Risk of batch timeout if event/registration volume increases

**Recommendation**:
1. Use a single JOIN query to fetch all necessary data:
```javascript
SELECT e.*, r.*, u.email, u.name
FROM events e
JOIN registrations r ON e.id = r.event_id
JOIN users u ON r.user_id = u.id
WHERE e.start_datetime BETWEEN $1 AND $2
  AND r.status = 'registered'
```
2. Group results in application memory
3. Send emails in batches using SES bulk API if available

**Expected improvement**: 358 queries → 1 query (99.7% reduction)

---

#### C-2: Registration Race Condition and Capacity Check Inefficiency
**Location**: Section 6.1 - `createRegistration()` function

**Issue**: The capacity check implementation has two critical problems:

**Problem 1 - Race Condition**:
```javascript
const registrations = await registrationRepository.findByEventId(eventId);
if (registrations.length >= event.capacity) {
  throw new Error('Event is full');
}
// GAP: Multiple concurrent requests can pass this check simultaneously
const registration = await registrationRepository.create({...});
```

With 500 concurrent users at peak, multiple requests for the same event can pass the capacity check before any INSERT completes, allowing overbooking.

**Problem 2 - Inefficient Capacity Check**:
The function fetches all registration records (`SELECT * FROM registrations WHERE event_id = $1`) to count them in application memory. For a 200-capacity event:
- Fetches 200 full records (including all columns: id, event_id, user_id, status, registered_at, checked_in_at)
- Transfers unnecessary data over network
- Performs count in application layer

**Impact**:
- **Functional impact**: Overbooking can occur under concurrent load
- **Performance impact**: O(n) data transfer where n = current registration count (up to 200 records/event)
- **Scalability impact**: Problem worsens with larger event capacities

**Recommendation**:
1. Use database-level atomic operation with optimistic locking:
```javascript
const result = await db.query(`
  INSERT INTO registrations (event_id, user_id, status)
  SELECT $1, $2, 'registered'
  WHERE (SELECT COUNT(*) FROM registrations WHERE event_id = $1) <
        (SELECT capacity FROM events WHERE id = $1)
  RETURNING *
`, [eventId, userId]);

if (result.rowCount === 0) {
  throw new Error('Event is full or does not exist');
}
```

2. Alternative: Use PostgreSQL advisory locks:
```javascript
await db.query('SELECT pg_advisory_lock($1)', [eventId]);
try {
  const count = await db.query('SELECT COUNT(*) FROM registrations WHERE event_id = $1', [eventId]);
  if (count.rows[0].count >= event.capacity) {
    throw new Error('Event is full');
  }
  // Proceed with insert
} finally {
  await db.query('SELECT pg_advisory_unlock($1)', [eventId]);
}
```

**Expected improvement**: Eliminates race condition, reduces data transfer by ~95% (full records → count only)

---

#### C-3: Missing Database Indexes for High-Frequency Queries
**Location**: Section 4.1 - Data model definition

**Issue**: The schema defines no indexes beyond primary keys, but the implementation shows multiple high-frequency queries that require table scans:

**Unindexed query patterns identified**:
1. **Registration lookups by event_id** (Section 6.1, 6.2, 6.3):
   - `SELECT * FROM registrations WHERE event_id = $1`
   - Executed in: registration creation, statistics calculation, reminder batch
   - Frequency: Every registration check + every dashboard view + daily batch

2. **Event lookups by date range** (Section 6.3):
   - `SELECT * FROM events WHERE start_datetime BETWEEN $1 AND $2`
   - Executed in: Daily reminder batch
   - Frequency: Daily

3. **Survey response lookups** (Section 6.2):
   - `SELECT * FROM survey_responses WHERE event_id = $1`
   - Executed in: Dashboard statistics
   - Frequency: Every dashboard view

4. **User lookups by email** (implied by authentication flow):
   - Email has UNIQUE constraint but no explicit index mention
   - Frequency: Every login

**Impact**:
- **Registration queries**: For 500 events with average 20 registrations each, full table scan of 10,000 records per query
- **Event date queries**: Full table scan of 500+ events daily
- **Query performance degradation**: As data accumulates without archival policy (Section 7.4), table scans will grow indefinitely
  - Year 1: 10,000 registrations
  - Year 2: 20,000 registrations
  - Year 3: 30,000 registrations (3x slower queries)

**Recommendation**:
Create covering indexes:
```sql
-- High-priority indexes
CREATE INDEX idx_registrations_event_id ON registrations(event_id) INCLUDE (user_id, status, checked_in_at);
CREATE INDEX idx_registrations_user_id ON registrations(user_id);
CREATE INDEX idx_events_start_datetime ON events(start_datetime) WHERE status != 'cancelled';
CREATE INDEX idx_survey_responses_event_id ON survey_responses(event_id);

-- Authentication optimization (if not auto-created by UNIQUE)
CREATE INDEX idx_users_email ON users(email);
```

**Expected improvement**:
- Query time reduction from O(n) table scan to O(log n) index lookup
- For 10,000 registrations: ~10,000 row scans → ~10 row accesses (99.9% reduction)

---

#### C-4: Undefined Caching Strategy Despite Available Redis
**Location**: Section 2 - Technology stack

**Issue**: Redis 7 (ElastiCache) is listed as available infrastructure but caching strategy is explicitly undefined ("キャッシュ戦略は未定義"). The design shows multiple high-frequency, read-heavy access patterns that would benefit from caching:

**Cacheable data patterns identified**:
1. **Event details** (Section 5.1, 6.1):
   - Accessed in: Event listing, registration process, statistics
   - Characteristics: Read-heavy, infrequent updates, small payload (~500 bytes)
   - Cache key: `event:{event_id}`

2. **Event registration count** (Section 6.1):
   - Accessed in: Every registration attempt for capacity check
   - Characteristics: High-frequency reads, frequent updates
   - Cache key: `event:{event_id}:count`

3. **Dashboard statistics** (Section 5.1, 6.2):
   - Accessed in: Dashboard views
   - Characteristics: Computation-intensive (multiple JOINs + aggregation), tolerate staleness
   - Cache key: `stats:{event_id}`

4. **User profile data** (Section 6.3):
   - Accessed in: Reminder batch, check-in process
   - Characteristics: Read-heavy, infrequent updates
   - Cache key: `user:{user_id}`

**Impact**:
- **Database load**: Every request hits PostgreSQL even for cacheable data
  - Event details: 500 concurrent users × multiple page views = thousands of duplicate queries
  - Registration count checks: 330 registrations/day = 330 count queries
- **API latency**: Every response includes database round-trip latency (typically 5-20ms)
- **Scalability bottleneck**: Database becomes single point of contention as load increases
- **Cost**: Higher RDS instance requirements without caching layer

**Recommendation**:
Implement tiered caching strategy:

```javascript
// 1. Event details cache (long TTL)
async function getEvent(eventId) {
  const cached = await redis.get(`event:${eventId}`);
  if (cached) return JSON.parse(cached);

  const event = await eventRepository.findById(eventId);
  await redis.setex(`event:${eventId}`, 3600, JSON.stringify(event)); // 1 hour TTL
  return event;
}

// 2. Registration count cache (short TTL + invalidation)
async function getRegistrationCount(eventId) {
  const cached = await redis.get(`event:${eventId}:count`);
  if (cached !== null) return parseInt(cached);

  const count = await db.query('SELECT COUNT(*) FROM registrations WHERE event_id = $1', [eventId]);
  await redis.setex(`event:${eventId}:count`, 60, count.rows[0].count); // 1 minute TTL
  return count.rows[0].count;
}

// Invalidate on new registration
async function createRegistration(eventId, userId) {
  // ... registration logic ...
  await redis.del(`event:${eventId}:count`); // Invalidate cache
}

// 3. Dashboard statistics cache (medium TTL, tolerate staleness)
async function getEventStats(eventId) {
  const cached = await redis.get(`stats:${eventId}`);
  if (cached) return JSON.parse(cached);

  const stats = await computeStats(eventId); // Expensive computation
  await redis.setex(`stats:${eventId}`, 300, JSON.stringify(stats)); // 5 minutes TTL
  return stats;
}
```

**Expected improvement**:
- Database query reduction: 70-90% for cached endpoints
- API latency reduction: ~15ms database latency → ~1ms cache latency (93% improvement)
- Horizontal scalability: Application layer can scale without proportional database load increase

---

#### C-5: Synchronous Email Sending in Critical Path
**Location**: Section 6.1 - `createRegistration()` function

**Issue**: The registration flow sends confirmation email synchronously within the API request:
```javascript
const registration = await registrationRepository.create({...});
await notificationService.sendRegistrationConfirmation(userId, eventId); // Blocks response
return registration;
```

**Impact**:
- **User-facing latency**: Registration API response time = database write time + email sending time
  - Database write: ~10-20ms
  - SES API call: ~50-200ms (network latency + SMTP handshake)
  - Total: 60-220ms per registration
- **Failure coupling**: If SES is unavailable, registration appears to fail even though database write succeeded
- **Throughput limitation**: Synchronous processing limits concurrent registration capacity
- **Timeout risk**: At peak load (500 concurrent users), SES throttling or slow response can cause API timeouts

**Recommendation**:
Implement asynchronous notification using SQS:

```javascript
async function createRegistration(eventId, userId) {
  const event = await getEvent(eventId); // Use cached version
  const count = await getRegistrationCount(eventId); // Use cached version

  if (count >= event.capacity) {
    throw new Error('Event is full');
  }

  const registration = await registrationRepository.create({
    event_id: eventId,
    user_id: userId,
    status: 'registered'
  });

  // Non-blocking: Publish to SQS queue
  await sqs.sendMessage({
    QueueUrl: process.env.NOTIFICATION_QUEUE_URL,
    MessageBody: JSON.stringify({
      type: 'registration_confirmation',
      userId,
      eventId,
      registrationId: registration.id
    })
  });

  return registration; // Return immediately
}

// Separate worker process consumes queue
async function notificationWorker() {
  while (true) {
    const messages = await sqs.receiveMessage({
      QueueUrl: process.env.NOTIFICATION_QUEUE_URL,
      MaxNumberOfMessages: 10 // Batch processing
    });

    for (const msg of messages.Messages || []) {
      const { type, userId, eventId } = JSON.parse(msg.Body);
      await notificationService.sendRegistrationConfirmation(userId, eventId);
      await sqs.deleteMessage({ QueueUrl: ..., ReceiptHandle: msg.ReceiptHandle });
    }
  }
}
```

**Expected improvement**:
- API response time: 60-220ms → 10-20ms (73-91% reduction)
- Decoupled failure handling: Registration succeeds even if email fails
- Better throughput: Async processing enables higher concurrent registrations
- Scalability: Worker can scale independently based on queue depth

---

### SIGNIFICANT ISSUES

#### S-1: Unbounded Result Sets in Event Listing API
**Location**: Section 5.1 - `GET /api/events`

**Issue**: The event listing endpoint returns all matching events without pagination:
```json
{
  "events": [
    { "id": "uuid", "title": "...", ... }
  ]
}
```

With optional filters (`category`, `status`) but no `limit` or `offset` parameters.

**Impact**:
- **Current scale**: 500 events/month → 6,000 events/year
  - Without data archival policy (Section 7.4), year 1 = 6,000 events, year 3 = 18,000 events
- **Response payload size**: Assuming 500 bytes per event summary:
  - Year 1: 6,000 events × 500 bytes = 3 MB
  - Year 3: 18,000 events × 500 bytes = 9 MB
- **Frontend rendering**: Rendering thousands of events in browser causes UI freeze
- **Network transfer time**: On 10 Mbps connection, 9 MB = 7.2 seconds transfer time

**Recommendation**:
Implement cursor-based pagination:

```javascript
// API design
GET /api/events?limit=50&cursor=2026-03-15T09:00:00Z:uuid-123&category=conference

// Implementation
async function listEvents(filters) {
  const { limit = 50, cursor, category, status } = filters;

  let query = 'SELECT * FROM events WHERE 1=1';
  const params = [];

  if (category) {
    params.push(category);
    query += ` AND category = $${params.length}`;
  }

  if (cursor) {
    const [timestamp, id] = cursor.split(':');
    params.push(timestamp, id);
    query += ` AND (start_datetime, id) > ($${params.length-1}, $${params.length})`;
  }

  query += ` ORDER BY start_datetime, id LIMIT $${params.length+1}`;
  params.push(limit);

  const events = await db.query(query, params);

  const nextCursor = events.length === limit
    ? `${events[limit-1].start_datetime}:${events[limit-1].id}`
    : null;

  return { events, nextCursor };
}

// Required index
CREATE INDEX idx_events_pagination ON events(start_datetime, id);
```

**Expected improvement**:
- Response payload: 9 MB → 25 KB (99.7% reduction)
- API response time: Consistent regardless of total event count
- Frontend performance: Smooth rendering with lazy loading

---

#### S-2: Dashboard Statistics Query Inefficiency
**Location**: Section 6.2 - `getEventStats()` function

**Issue**: The implementation performs three separate full-table operations:
1. **Full JOIN query**: Fetches all registration records with user data (`SELECT r.*, u.department FROM registrations r JOIN users u ...`)
2. **Separate survey query**: Fetches all survey responses (`SELECT * FROM survey_responses WHERE event_id = $1`)
3. **In-memory aggregation**: Loops through results to compute statistics

For a 200-participant event:
- Query 1 transfers 200 registration records + user department data
- Query 2 transfers 170 survey response records (assuming 85% response rate)
- Total network transfer: ~370 records
- Application memory: Holds 370 records during aggregation

**Impact**:
- **Inefficient data transfer**: Fetching full records when only aggregates are needed
- **Redundant computation**: Database can perform aggregation more efficiently than application layer
- **Memory consumption**: O(n) memory usage where n = participant count
- **Multiple round trips**: Two separate queries instead of one

**Recommendation**:
Consolidate into single aggregation query:

```javascript
async function getEventStats(eventId) {
  const stats = await db.query(`
    WITH event_registrations AS (
      SELECT
        r.user_id,
        r.checked_in_at,
        u.department
      FROM registrations r
      JOIN users u ON r.user_id = u.id
      WHERE r.event_id = $1 AND r.status = 'registered'
    ),
    survey_count AS (
      SELECT COUNT(*) as response_count
      FROM survey_responses
      WHERE event_id = $1
    )
    SELECT
      COUNT(*) as total_registrations,
      COUNT(checked_in_at) as checked_in_count,
      (SELECT response_count FROM survey_count) as survey_responses,
      jsonb_object_agg(
        COALESCE(department, 'Unknown'),
        dept_count
      ) as registrations_by_department
    FROM (
      SELECT
        department,
        COUNT(*) as dept_count
      FROM event_registrations
      GROUP BY department
    ) dept_stats
  `, [eventId]);

  const result = stats.rows[0];

  return {
    total_registrations: parseInt(result.total_registrations),
    checked_in_count: parseInt(result.checked_in_count),
    survey_response_rate: result.total_registrations > 0
      ? result.survey_responses / result.total_registrations
      : 0,
    registrations_by_department: Object.entries(result.registrations_by_department).map(
      ([department, count]) => ({ department, count: parseInt(count) })
    )
  };
}
```

**Expected improvement**:
- Data transfer: 370 records → 1 aggregated result row (99.7% reduction)
- Query execution: Database-level aggregation is significantly faster than application-level loops
- Memory consumption: O(n) → O(1)
- Network round trips: 2 queries → 1 query

**Additional recommendation**: Cache this expensive query result (see C-4) with 5-minute TTL since dashboard statistics tolerate slight staleness.

---

#### S-3: Missing Connection Pooling Configuration
**Location**: Section 2 - Technology stack, Section 3.2 - Data Access Layer

**Issue**: The design specifies PostgreSQL RDS but provides no connection pooling configuration. The code examples show direct database queries without pool management.

**Impact**:
- **Connection exhaustion risk**: PostgreSQL default max_connections = 100
  - Peak load: 500 concurrent users
  - Average requests/user session: ~5 (browse events, view details, register, view dashboard, check email)
  - Without pooling: Potential 500+ concurrent connection attempts → Connection refused errors
- **Connection overhead**: Creating new PostgreSQL connection = ~50-100ms overhead
  - Without pooling: Every query pays this cost
  - With pooling: Reuse existing connections = ~1ms overhead
- **Resource waste**: Each idle connection consumes ~10MB PostgreSQL memory
  - 100 connections × 10 MB = 1 GB memory for connection management alone

**Recommendation**:
Configure connection pooling with appropriate limits:

```javascript
// Using pg-pool (Node.js)
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,

  // Connection pool settings
  max: 20,                    // Max connections per application instance
  min: 5,                     // Minimum idle connections
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 5000, // Fail fast if no connection available

  // Query timeout
  statement_timeout: 10000    // Kill queries running longer than 10s
});

// Usage in repositories
async function findById(id) {
  const client = await pool.connect();
  try {
    const result = await client.query('SELECT * FROM events WHERE id = $1', [id]);
    return result.rows[0];
  } finally {
    client.release(); // Return to pool
  }
}
```

**Configuration rationale**:
- **max: 20 per instance**: With ECS Auto Scaling, assume 3-5 instances at peak → 60-100 total connections (within PostgreSQL max_connections limit)
- **min: 5**: Keep warm connections for immediate request handling
- **statement_timeout: 10000ms**: Prevent runaway queries from holding connections indefinitely

**Expected improvement**:
- Connection establishment time: 50-100ms → ~1ms (98% reduction)
- Connection exhaustion prevention: Graceful degradation with queue instead of hard failures
- Memory efficiency: 100 connections → 20-25 connections per instance (75-80% reduction)

---

#### S-4: No Rate Limiting on Public-Facing APIs
**Location**: Section 5.1 - API endpoints, Section 5.2 - Authentication

**Issue**: The design specifies public-facing APIs (`/api/events`, `/api/registrations`) with JWT authentication but no rate limiting strategy.

**Impact**:
- **Abuse vulnerability**: Malicious actors can overwhelm the system
  - Registration endpoint: Spam registrations to fill events
  - Dashboard endpoint: Expensive queries (see S-2) can be repeatedly triggered
  - Event listing: Unbounded queries (see S-1) can be repeatedly requested
- **Resource exhaustion**: Without limits, a single client can consume disproportionate resources
  - Example: Automated script makes 1000 requests/second → Database connection pool exhausted
- **Cost implications**: AWS API Gateway, ECS, RDS charges scale with request volume

**Recommendation**:
Implement tiered rate limiting:

```javascript
// Using express-rate-limit
const rateLimit = require('express-rate-limit');

// Tier 1: Global rate limit (coarse-grained)
const globalLimiter = rateLimit({
  windowMs: 60 * 1000,        // 1 minute
  max: 100,                    // 100 requests per minute per IP
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
});

// Tier 2: Expensive endpoint limits (fine-grained)
const dashboardLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,                     // 10 dashboard requests per minute
  message: 'Dashboard access rate limit exceeded'
});

const registrationLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,                      // 5 registrations per minute per user
  keyGenerator: (req) => req.user.id, // Rate limit by authenticated user
  message: 'Registration rate limit exceeded'
});

// Application
app.use('/api', globalLimiter);
app.use('/api/dashboard', dashboardLimiter);
app.use('/api/registrations', registrationLimiter);
```

**Additional recommendation**: For production, use Redis-backed rate limiting for consistency across ECS instances:

```javascript
const RedisStore = require('rate-limit-redis');
const redis = require('redis');

const client = redis.createClient({
  host: process.env.REDIS_HOST,
  port: 6379
});

const limiter = rateLimit({
  store: new RedisStore({
    client: client,
    prefix: 'rl:' // rate-limit prefix
  }),
  windowMs: 60 * 1000,
  max: 100
});
```

**Expected improvement**:
- Abuse prevention: Limits blast radius of malicious/misconfigured clients
- Fair resource distribution: Prevents single client from monopolizing system
- Cost control: Caps maximum request volume per time window

---

#### S-5: No Timeout Configuration for External Dependencies
**Location**: Section 6.1, 6.3 - SES email sending, Section 3.2 - Database queries

**Issue**: The code examples show calls to external dependencies (SES, PostgreSQL) without timeout configuration:
```javascript
await ses.sendEmail({...}); // No timeout
await db.query(`SELECT ...`); // No timeout
```

**Impact**:
- **Cascade failures**: If SES or database becomes slow/unresponsive, API requests hang indefinitely
  - Without timeouts: Request waits until TCP socket timeout (~60-120 seconds)
  - User experience: 60-second wait before receiving error
- **Thread/connection exhaustion**: Hanging requests occupy ECS task resources
  - Express default: Unlimited pending requests
  - Result: All ECS task memory consumed by blocked requests → No capacity for new requests
- **Cascading load**: Slow dependency response causes request backlog → Auto-scaling triggers → More instances hit same slow dependency → System-wide outage

**Recommendation**:
Configure timeouts at multiple layers:

```javascript
// 1. Database query timeout (already recommended in S-3)
const pool = new Pool({
  statement_timeout: 10000 // 10 second max query time
});

// 2. SES client timeout
const AWS = require('aws-sdk');
const ses = new AWS.SES({
  httpOptions: {
    timeout: 5000,           // 5 second socket timeout
    connectTimeout: 2000     // 2 second connection timeout
  },
  maxRetries: 2              // Retry on timeout
});

// 3. Express global timeout middleware
const timeout = require('connect-timeout');
app.use(timeout('15s')); // 15 second max request duration
app.use((req, res, next) => {
  if (req.timedout) {
    return res.status(503).json({ error: 'Request timeout' });
  }
  next();
});

// 4. Circuit breaker for SES (advanced)
const CircuitBreaker = require('opossum');

const sesBreaker = new CircuitBreaker(
  async (params) => ses.sendEmail(params).promise(),
  {
    timeout: 5000,           // 5 second operation timeout
    errorThresholdPercentage: 50, // Open circuit if 50% fail
    resetTimeout: 30000      // Try again after 30 seconds
  }
);

sesBreaker.fallback(() => {
  // Fallback: Queue email for later retry instead of failing
  return sqs.sendMessage({...});
});
```

**Expected improvement**:
- **Fail fast**: 60-120 second hangs → 5-15 second timeouts
- **Resource protection**: Prevents thread/connection exhaustion
- **Graceful degradation**: Circuit breaker enables fallback strategies

---

### MODERATE ISSUES

#### M-1: Inefficient Date Range Query in Reminder Batch
**Location**: Section 6.3 - `sendReminders()` function

**Issue**: The reminder batch constructs tomorrow's date in application code and passes as parameter:
```javascript
const tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
const events = await eventRepository.findByDate(tomorrow);
```

This likely translates to a query like:
```sql
SELECT * FROM events WHERE DATE(start_datetime) = '2026-03-15'
```

Using `DATE()` function prevents index usage even if `idx_events_start_datetime` exists.

**Impact**:
- **Index invalidation**: Function on indexed column prevents index seek → Full table scan
- **Performance degradation**: 500 events → Full scan daily
- **Growth impact**: As events accumulate (no archival policy), scan time grows linearly

**Recommendation**:
Use range comparison to enable index usage:

```javascript
async function sendReminders() {
  const tomorrowStart = new Date();
  tomorrowStart.setDate(tomorrowStart.getDate() + 1);
  tomorrowStart.setHours(0, 0, 0, 0);

  const tomorrowEnd = new Date(tomorrowStart);
  tomorrowEnd.setHours(23, 59, 59, 999);

  const events = await db.query(`
    SELECT id, title, start_datetime
    FROM events
    WHERE start_datetime >= $1 AND start_datetime <= $2
      AND status NOT IN ('cancelled', 'draft')
  `, [tomorrowStart, tomorrowEnd]);

  // Rest of logic
}
```

**Expected improvement**:
- Query execution: Full table scan → Index range scan
- Performance: O(n) → O(log n + k) where k = events on that date (~17 events)

---

#### M-2: JWT Token Management Without Refresh Strategy
**Location**: Section 5.2 - Authentication

**Issue**: JWT implementation specified with 24-hour expiration but no refresh token mechanism:
```
- JWT（JSON Web Token）をHTTP Headerで送信
- トークン有効期限: 24時間
- リフレッシュトークン未実装
```

**Impact**:
- **User experience**: User must re-authenticate every 24 hours even during active session
  - Scenario: User starts event at 9 AM, finishes at 5 PM → Token expired mid-event
- **Security vs. usability trade-off**:
  - Short expiration (secure): Frequent re-authentication (poor UX)
  - Long expiration (good UX): Stolen token remains valid longer (security risk)
- **Mobile app impact**: Without refresh tokens, mobile apps must store raw credentials to re-authenticate automatically (insecure)

**Recommendation**:
Implement refresh token pattern:

```javascript
// Login endpoint returns both tokens
POST /api/auth/login
{
  "email": "user@example.com",
  "password": "..."
}

Response:
{
  "accessToken": "eyJhbG...",   // Short-lived (15 minutes)
  "refreshToken": "dGhpcyBp..." // Long-lived (7 days), stored in httpOnly cookie
}

// Refresh endpoint
POST /api/auth/refresh
Headers: Cookie: refreshToken=dGhpcyBp...

Response:
{
  "accessToken": "eyJhbG..."  // New access token
}

// Implementation
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

async function login(email, password) {
  const user = await authenticateUser(email, password);

  const accessToken = jwt.sign(
    { userId: user.id, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );

  const refreshToken = crypto.randomBytes(40).toString('hex');

  // Store refresh token in database with expiration
  await db.query(`
    INSERT INTO refresh_tokens (token, user_id, expires_at)
    VALUES ($1, $2, NOW() + INTERVAL '7 days')
  `, [refreshToken, user.id]);

  return { accessToken, refreshToken };
}

async function refreshAccessToken(refreshToken) {
  const result = await db.query(`
    SELECT user_id FROM refresh_tokens
    WHERE token = $1 AND expires_at > NOW()
  `, [refreshToken]);

  if (result.rows.length === 0) {
    throw new Error('Invalid or expired refresh token');
  }

  const user = await userRepository.findById(result.rows[0].user_id);
  const accessToken = jwt.sign(
    { userId: user.id, email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );

  return { accessToken };
}
```

**Expected improvement**:
- Security: Short-lived access tokens (15 minutes) minimize stolen token damage
- User experience: Transparent token refresh without re-authentication
- Mobile app security: No need to store raw credentials

---

#### M-3: Missing Data Archival Strategy
**Location**: Section 7.4 - Data retention

**Issue**: The design explicitly states no data retention policy:
```
現時点では明示的なデータ保持期限・アーカイブポリシーは未定義。
registrations、survey_responsesなどの履歴データは無期限で保持される。
```

**Impact**:
- **Database growth**: 10,000 registrations/month × 12 months = 120,000 records/year
  - 5 years: 600,000 registrations
  - Assuming 200 bytes/record: 600,000 × 200 = 120 MB (registrations alone)
  - Including survey_responses, events: ~200-300 MB total
- **Query performance degradation**: All queries scan growing tables
  - Index size grows proportionally
  - Cache hit rate decreases (more data to cache)
- **Backup/restore time**: Larger database = longer backup/restore cycles
- **Cost**: RDS storage costs grow linearly with data volume

**Recommendation**:
Implement archival strategy with three tiers:

```javascript
// 1. Hot data: Recent events (last 6 months) - Keep in main tables
// 2. Warm data: Historical events (6 months - 3 years) - Archive tables in same DB
// 3. Cold data: Old events (3+ years) - S3 Glacier

// Archive table schema
CREATE TABLE events_archive (LIKE events INCLUDING ALL);
CREATE TABLE registrations_archive (LIKE registrations INCLUDING ALL);
CREATE TABLE survey_responses_archive (LIKE survey_responses INCLUDING ALL);

// Monthly archival job
async function archiveOldData() {
  const archiveDate = new Date();
  archiveDate.setMonth(archiveDate.getMonth() - 6);

  // Move events and related data to archive tables
  await db.query(`
    WITH archived_events AS (
      DELETE FROM events
      WHERE end_datetime < $1
      RETURNING *
    )
    INSERT INTO events_archive SELECT * FROM archived_events
  `, [archiveDate]);

  // Cascade to registrations
  await db.query(`
    WITH archived_regs AS (
      DELETE FROM registrations
      WHERE event_id IN (SELECT id FROM events_archive)
      RETURNING *
    )
    INSERT INTO registrations_archive SELECT * FROM archived_regs
  `);

  // Similar for survey_responses
}

// For cold data: Export to S3 after 3 years
async function exportColdData() {
  const coldDate = new Date();
  coldDate.setFullYear(coldDate.getFullYear() - 3);

  const oldEvents = await db.query(`
    SELECT * FROM events_archive WHERE end_datetime < $1
  `, [coldDate]);

  // Export to S3 as Parquet or JSON
  const s3Key = `archives/${coldDate.getFullYear()}/events.json`;
  await s3.putObject({
    Bucket: 'event-platform-archives',
    Key: s3Key,
    Body: JSON.stringify(oldEvents.rows),
    StorageClass: 'GLACIER'
  });

  // Delete from archive table
  await db.query(`DELETE FROM events_archive WHERE end_datetime < $1`, [coldDate]);
}
```

**Expected improvement**:
- **Active database size**: Stabilizes at ~6 months of data instead of growing indefinitely
- **Query performance**: Maintains consistent performance over time
- **Cost optimization**: S3 Glacier storage = ~$0.004/GB vs RDS = ~$0.10/GB (96% cheaper for cold data)

---

#### M-4: No Monitoring and Alerting Strategy
**Location**: Section 6.5 - Logging policy

**Issue**: Design specifies logging (Winston, JSON format) but no performance monitoring, metrics collection, or alerting strategy.

**Impact**:
- **Blind spots**: Cannot detect performance degradation until users complain
- **No capacity planning data**: Cannot make informed scaling decisions
- **Difficult troubleshooting**: Logs show errors but not performance trends
- **SLA compliance**: Cannot verify if system meets performance expectations (Section 7.1)

**Recommendation**:
Implement observability stack:

```javascript
// 1. Application metrics (using prom-client)
const promClient = require('prom-client');

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_ms',
  help: 'Duration of HTTP requests in ms',
  labelNames: ['method', 'route', 'status_code']
});

const dbQueryDuration = new promClient.Histogram({
  name: 'db_query_duration_ms',
  help: 'Duration of database queries in ms',
  labelNames: ['query_type']
});

const registrationCounter = new promClient.Counter({
  name: 'registrations_total',
  help: 'Total number of registrations',
  labelNames: ['event_id', 'status']
});

// Middleware to track request duration
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    httpRequestDuration.labels(req.method, req.route?.path || 'unknown', res.statusCode).observe(duration);
  });
  next();
});

// Expose metrics endpoint for Prometheus scraping
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

```yaml
# 2. CloudWatch Dashboard (using AWS CDK/CloudFormation)
Dashboard:
  - Widget: API Latency (P50, P95, P99)
  - Widget: Error Rate by Endpoint
  - Widget: Database Connection Pool Usage
  - Widget: Cache Hit Rate
  - Widget: Registration Success Rate
  - Widget: ECS CPU/Memory Utilization

# 3. Alerting Rules
Alarms:
  - API_P95_Latency > 500ms for 5 minutes → PagerDuty
  - Error_Rate > 5% for 3 minutes → Slack
  - Database_Connection_Pool_Usage > 80% → Email
  - Registration_Failure_Rate > 10% → PagerDuty
  - ECS_CPU_Usage > 80% for 10 minutes → Auto-scaling + Email
```

**Expected improvement**:
- **Proactive issue detection**: Alerts fire before users notice problems
- **Data-driven optimization**: Metrics identify actual bottlenecks (vs. guessing)
- **SLA verification**: Can measure and report against performance targets

---

### MINOR IMPROVEMENTS

#### I-1: Optimize QR Code Check-in Endpoint
**Location**: Section 3.2 - `/api/checkin` endpoint

**Issue**: No implementation details provided, but typical QR check-in pattern has potential optimization.

**Recommendation**:
- Use optimistic locking to prevent duplicate check-ins:
```javascript
async function checkin(registrationId) {
  const result = await db.query(`
    UPDATE registrations
    SET checked_in_at = NOW()
    WHERE id = $1 AND checked_in_at IS NULL
    RETURNING *
  `, [registrationId]);

  if (result.rowCount === 0) {
    throw new Error('Already checked in or registration not found');
  }

  return result.rows[0];
}
```

- Cache registration lookups by QR code to avoid repeated database queries at entrance

---

#### I-2: Consider Read Replicas for Dashboard Queries
**Location**: Section 7.3 - Availability

**Issue**: RDS Multi-AZ provides high availability but not read scalability. Dashboard queries (Section 6.2) are read-heavy and could benefit from read replicas.

**Recommendation**:
- Add RDS read replica for analytical/dashboard queries
- Route `/api/dashboard/*` requests to read replica
- Accept eventual consistency for dashboard statistics (already acceptable given cache strategy in C-4)

**Expected improvement**:
- Offload read traffic from primary database
- Better write performance on primary (fewer competing queries)
- Improved horizontal read scalability

---

#### I-3: Batch Email Sending Optimization
**Location**: Section 6.3 - Reminder batch

**Issue**: Even after fixing N+1 query (C-1) and making emails async (C-5), sending emails one-by-one is inefficient.

**Recommendation**:
Use SES batch sending API (up to 50 recipients per call):

```javascript
const AWS = require('aws-sdk');
const ses = new AWS.SES();

async function sendBatchReminders(reminders) {
  // Group into batches of 50
  const batches = [];
  for (let i = 0; i < reminders.length; i += 50) {
    batches.push(reminders.slice(i, i + 50));
  }

  for (const batch of batches) {
    const destinations = batch.map(r => ({
      Destination: { ToAddresses: [r.email] },
      ReplacementTemplateData: JSON.stringify({
        event_title: r.eventTitle,
        start_time: r.startTime
      })
    }));

    await ses.sendBulkTemplatedEmail({
      Source: 'noreply@eventplatform.com',
      Template: 'event-reminder',
      Destinations: destinations
    }).promise();
  }
}
```

**Expected improvement**:
- 340 individual SES API calls → 7 batch calls (98% reduction)
- Lower cost (batch sending often cheaper)
- Faster execution

---

## SUMMARY

### Critical Issues Requiring Immediate Attention
1. **C-1**: N+1 query in reminder batch (358 queries → 1 query)
2. **C-2**: Race condition in registration capacity check (overbooking risk)
3. **C-3**: Missing database indexes (10,000x performance impact)
4. **C-4**: No caching strategy despite available Redis (70-90% database load reduction)
5. **C-5**: Synchronous email sending blocks API responses (73-91% latency reduction)

### Significant Issues for Near-Term Implementation
1. **S-1**: Unbounded API result sets (9 MB → 25 KB responses)
2. **S-2**: Inefficient dashboard aggregation (370 records → 1 result row)
3. **S-3**: Missing connection pooling (connection exhaustion risk)
4. **S-4**: No rate limiting (abuse vulnerability)
5. **S-5**: No timeout configuration (cascade failure risk)

### Architecture Recommendations
- Implement comprehensive caching strategy using Redis
- Adopt async processing pattern for all non-critical operations (emails, notifications)
- Add database indexes before launch
- Configure connection pooling and timeouts
- Implement API pagination and rate limiting
- Establish monitoring and alerting before production deployment

### Performance Characteristics
**Current design limitations**:
- Cannot safely handle stated load (500 concurrent users) due to connection exhaustion risk
- Database will become bottleneck without caching and indexing
- User-facing latency impacted by synchronous email sending
- System vulnerable to abuse without rate limiting

**With recommended improvements**:
- Can scale horizontally by decoupling email processing
- Database load reduced by 70-90% with caching
- API response times reduced by 73-91%
- Stable performance as data volume grows (with archival strategy)
