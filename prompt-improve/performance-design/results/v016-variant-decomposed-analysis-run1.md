# Performance Design Review - v016 Variant Decomposed Analysis Run 1

## PHASE 1: Architecture Inventory

### 1. Explicitly Documented Components

- **API endpoints defined**: 5 endpoints (`/api/events`, `/api/registrations`, `/api/checkin`, `/api/surveys`, `/api/dashboard`)
- **Database schema specified**: 4 tables (events, registrations, users, survey_responses) with complete column definitions
- **Technology stack specified**: Node.js v20, Express v4.18, Next.js v14, PostgreSQL 15, Redis 7, AWS services
- **Architecture pattern defined**: 3-tier architecture (Frontend → API Layer → Business Logic Layer → Data Access Layer)
- **Authentication flow described**: JWT with 24-hour validity, HTTP header transmission
- **Business logic services defined**: EventService, RegistrationService, CheckinService, SurveyService, NotificationService
- **Deployment strategy defined**: Docker, ECS Fargate, Blue-Green deployment
- **Infrastructure components specified**: AWS (EC2, RDS, S3, SQS, SES), RDS Multi-AZ, ECS Auto Scaling (70% CPU threshold)
- **Implementation code samples provided**: Registration creation, dashboard statistics, reminder batch processing
- **Security measures specified**: HTTPS, SQL injection prevention, XSS prevention, CSRF token validation
- **Testing strategy defined**: Unit tests (Jest), integration tests (Supertest), E2E tests (Playwright)
- **Logging strategy defined**: Winston library, JSON format, info/warn/error levels

### 2. Standard Concerns Present

- **Performance capacity indicators**: Monthly event volume (500 events), monthly registrations (10,000), peak concurrent users (500)
- **Security measures**: Authentication (JWT), encryption (HTTPS), input validation mechanisms
- **High availability design**: RDS Multi-AZ, ECS Auto Scaling
- **Error handling strategy**: HTTP status code conventions (4xx/5xx), error logging to stdout
- **Horizontal scaling mechanism**: ECS Auto Scaling based on CPU usage
- **Batch processing identified**: Daily reminder batch at 9:00 AM

### 3. Standard Concerns Absent or Incomplete

- **No performance SLAs/NFRs defined**: No explicit targets for response time, throughput, or acceptable latency ranges despite concurrent user expectations
- **No caching strategy defined**: Redis 7 infrastructure is available but completely unused; no cache targets, TTL strategies, or invalidation policies specified
- **No data retention/lifecycle policy**: Section 7.4 explicitly states unlimited retention of registrations and survey_responses with no archiving plan
- **No database indexing strategy**: No indexes defined despite JOIN-heavy queries and filter operations (category, status, event_id, user_id)
- **No connection pooling configuration**: Database connection management strategy undefined despite concurrent user load
- **No query optimization plan**: Multi-table JOINs in dashboard queries lack pagination or result set limits
- **No rate limiting**: No API throttling or request rate limits despite public-facing registration endpoints
- **No monitoring/observability plan**: No APM, metrics collection, alerting thresholds, or performance dashboards defined
- **No capacity planning details**: Auto-scaling threshold (70% CPU) defined but no memory limits, instance sizing, or cost analysis
- **No batch job scalability design**: Reminder batch uses nested synchronous loops with no concurrency control or failure handling
- **No concurrency control**: Registration capacity checks lack transaction isolation or optimistic locking
- **No circuit breaker patterns**: External service calls (SES, S3) lack timeout/retry/fallback mechanisms
- **No data volume growth projections**: No plans for handling historical data accumulation or partitioning strategies

### 4. System Scale Indicators

- **Monthly events**: 500 events/month (~16-17 events/day average)
- **Monthly registrations**: 10,000 registrations/month (~330 registrations/day average)
- **Peak concurrent users**: 500 simultaneous users
- **Event capacity example**: 200 participants per event mentioned in API response example
- **Estimated registrations per event**: Average ~20 registrations per event (10,000/500), but capacity examples show up to 200 → suggests high-variance event sizes
- **Dashboard query load**: Per-event statistics require multi-table JOINs across potentially thousands of registration records
- **Batch notification volume**: For large events (200 participants), reminder batch sends 200 sequential emails per event

---

## PHASE 2: Performance Issue Detection

### CRITICAL ISSUES

#### C-1: Race Condition in Registration Capacity Check (High-Severity Data Integrity Risk)

**Location**: Section 6.1 `createRegistration` function

**Issue**: The capacity check uses a non-atomic read-check-write pattern:
```javascript
const registrations = await registrationRepository.findByEventId(eventId);
if (registrations.length >= event.capacity) {
  throw new Error('Event is full');
}
const registration = await registrationRepository.create({...});
```

At 500 concurrent users, multiple requests can pass the capacity check simultaneously before any INSERT occurs, leading to overbooking.

**Impact**:
- **Data integrity violation**: Event capacity exceeded without detection
- **Business logic failure**: Acceptance of more registrations than permitted
- **User trust damage**: Overbooking damages platform credibility
- **At-scale manifestation**: With 500 concurrent users and popular events approaching capacity, probability of race condition increases significantly

**Recommendation**:
1. Implement database-level constraint: `UNIQUE(event_id, user_id)` + capacity enforcement via triggers or CHECK constraints
2. Use optimistic locking with version column on events table
3. Use transaction isolation level SERIALIZABLE or add explicit row locks:
   ```sql
   BEGIN;
   SELECT capacity, (SELECT COUNT(*) FROM registrations WHERE event_id = $1) as current_count
   FROM events WHERE id = $1 FOR UPDATE;
   -- Check capacity in application logic
   INSERT INTO registrations ...;
   COMMIT;
   ```
4. Alternative: Implement distributed lock using Redis (already available) with lock timeout

---

#### C-2: Missing Performance SLAs for User-Facing Operations

**Location**: Section 7.1 (Non-Functional Requirements)

**Issue**: Despite specifying 500 concurrent users and public-facing registration/check-in workflows, no response time SLAs are defined. Critical user flows (registration submission, QR check-in) lack latency targets.

**Impact**:
- **Undetectable performance degradation**: No baseline to measure against or alert on
- **Poor user experience risk**: Registration delays during peak times (event opening, day-before rushes) may go unnoticed until user complaints
- **Incident response blindness**: Unable to distinguish "acceptable slow" from "actionable incident"
- **Scaling trigger uncertainty**: Auto-scaling based on 70% CPU may not correlate with user-perceived performance

**Recommendation**:
1. Define SLAs for critical paths:
   - Registration submission: < 500ms p95 response time
   - Event listing: < 300ms p95 response time
   - Dashboard statistics: < 2000ms p95 response time
   - QR check-in: < 200ms p95 response time (real-time expectation)
2. Establish throughput targets: e.g., "support 50 concurrent registrations/second during peak"
3. Implement APM tooling (e.g., New Relic, Datadog) to track SLA compliance
4. Configure alerting thresholds at 80% of SLA limits

---

#### C-3: Unbounded Query Result Sets and Missing Pagination

**Location**:
- Section 5.1 `GET /api/events` (line 119-139)
- Section 6.2 `getEventStats` function (line 209-239)

**Issue**:
1. Event listing endpoint lacks pagination - returns all matching events
2. Dashboard statistics query loads ALL registrations for an event into memory
3. With 500 events/month accumulating over 12 months = 6,000+ events in database
4. Large events (200 participants) × full dataset JOINs = memory exhaustion risk

**Impact**:
- **Memory exhaustion**: Loading 6,000 events or 200+ joined registration rows into Node.js heap
- **Slow response times**: Full table scans without LIMIT clauses
- **Database load**: Unnecessary I/O for large result sets
- **Frontend rendering issues**: Browser memory pressure from large JSON payloads
- **At 12-month scale**: With no data archiving (section 7.4), problem compounds linearly

**Recommendation**:
1. Implement pagination for `GET /api/events`:
   ```javascript
   GET /api/events?page=1&page_size=20&category=tech&status=published
   ```
2. Add LIMIT/OFFSET to event listing query
3. For dashboard stats, use database aggregation instead of application-side processing:
   ```sql
   SELECT
     u.department,
     COUNT(*) as count,
     COUNT(r.checked_in_at) as checked_in
   FROM registrations r
   JOIN users u ON r.user_id = u.id
   WHERE r.event_id = $1
   GROUP BY u.department
   ```
4. Add database-level row count limits (e.g., `LIMIT 10000`) as safety net
5. Consider cursor-based pagination for real-time data consistency

---

#### C-4: No Caching Strategy Despite Available Infrastructure and High-Read Workload

**Location**: Section 2 (line 27-28) and throughout query implementations

**Issue**: Redis 7 is provisioned but completely unused. Multiple high-frequency read patterns exist with zero cache utilization:
- Event listings (frequently browsed, rarely change)
- Dashboard statistics (computationally expensive JOINs)
- User profile lookups (repeated for notification sends)
- Event detail pages (read:write ratio heavily skewed to reads)

**Impact**:
- **Wasted infrastructure cost**: Paying for unused ElastiCache instances
- **Unnecessary database load**: Every dashboard view triggers multi-table JOIN
- **Slow dashboard response**: Real-time aggregation for every request instead of cached results
- **Poor scalability**: Database becomes bottleneck as concurrent users increase
- **At 500 concurrent users**: Without caching, dashboard queries could overwhelm PostgreSQL connection pool

**Recommendation**:
1. Implement Redis caching for read-heavy data:
   - **Event listings**: Cache filtered results with 5-minute TTL, invalidate on event CRUD
   - **Dashboard statistics**: Cache per-event stats with 15-minute TTL, invalidate on new registration/check-in
   - **User profiles**: Cache user objects with 1-hour TTL, invalidate on profile update
   - **Event details**: Cache individual event records with 10-minute TTL

2. Cache invalidation strategy:
   ```javascript
   async function createRegistration(eventId, userId) {
     const registration = await registrationRepository.create({...});
     await redis.del(`event:${eventId}:stats`); // Invalidate cached stats
     await redis.del(`event:${eventId}:registrations:count`);
     return registration;
   }
   ```

3. Add cache-aside pattern for dashboard:
   ```javascript
   async function getEventStats(eventId) {
     const cached = await redis.get(`event:${eventId}:stats`);
     if (cached) return JSON.parse(cached);

     const stats = await computeStatsFromDB(eventId);
     await redis.setex(`event:${eventId}:stats`, 900, JSON.stringify(stats)); // 15min TTL
     return stats;
   }
   ```

4. Monitor cache hit rates and adjust TTLs based on observed access patterns

---

### SIGNIFICANT ISSUES

#### S-1: Missing Database Indexes for Query Performance

**Location**: Section 4.1 (Database schema), Section 6.2 (queries)

**Issue**: No indexes defined despite multiple filter and JOIN operations:
- `events.status`, `events.category` (used in list filtering)
- `registrations.event_id` (foreign key, used in JOINs and filtering)
- `registrations.user_id` (foreign key)
- `registrations.checked_in_at` (used in statistics filtering)
- `survey_responses.event_id` (used in dashboard JOINs)

**Impact**:
- **Slow query performance**: Full table scans on registrations table (10,000+ rows/month × retention months)
- **Dashboard latency**: Multi-table JOINs without indexes cause O(n²) complexity
- **Event listing slowdown**: Filtering 6,000+ events by status/category without indexes
- **At-scale degradation**: Query times increase quadratically as data accumulates

**Recommendation**:
1. Create essential indexes:
   ```sql
   CREATE INDEX idx_events_status ON events(status);
   CREATE INDEX idx_events_category ON events(category);
   CREATE INDEX idx_events_start_datetime ON events(start_datetime); -- For reminder batch
   CREATE INDEX idx_registrations_event_id ON registrations(event_id);
   CREATE INDEX idx_registrations_user_id ON registrations(user_id);
   CREATE INDEX idx_registrations_status ON registrations(status);
   CREATE INDEX idx_survey_responses_event_id ON survey_responses(event_id);
   ```

2. Add composite index for common query patterns:
   ```sql
   CREATE INDEX idx_registrations_event_status ON registrations(event_id, status);
   CREATE INDEX idx_events_status_start_date ON events(status, start_datetime);
   ```

3. Monitor index usage with PostgreSQL `pg_stat_user_indexes` and adjust based on actual query patterns

---

#### S-2: Inefficient N+1 Query Pattern in Reminder Batch

**Location**: Section 6.3 `sendReminders` function (line 242-264)

**Issue**: Nested loop structure causes N+1 queries:
```javascript
for (const event of events) {
  const registrations = await registrationRepository.findByEventId(event.id); // Query 1 per event
  for (const registration of registrations) {
    const user = await userRepository.findById(registration.user_id); // Query 2 per registration
  }
}
```

For 10 events with 50 registrations each = 1 + 10 + 500 = 511 database queries.

**Impact**:
- **Slow batch execution**: 500+ sequential database round-trips
- **Database connection exhaustion**: May exceed connection pool limits during batch run
- **Network latency amplification**: Each query incurs round-trip overhead
- **Blocking operation**: Synchronous email sending blocks entire batch flow
- **No failure isolation**: One SES failure halts entire batch

**Recommendation**:
1. Use JOIN to fetch all data in 2 queries:
   ```javascript
   async function sendReminders() {
     const tomorrow = new Date();
     tomorrow.setDate(tomorrow.getDate() + 1);

     const eventRegistrations = await db.query(`
       SELECT e.id, e.title, e.start_datetime, u.email, u.name
       FROM events e
       JOIN registrations r ON e.id = r.event_id
       JOIN users u ON r.user_id = u.id
       WHERE DATE(e.start_datetime) = DATE($1)
       AND r.status = 'registered'
     `, [tomorrow]);

     // Process in batches
     for (let i = 0; i < eventRegistrations.length; i += 50) {
       const batch = eventRegistrations.slice(i, i + 50);
       await Promise.all(batch.map(er => ses.sendEmail({...})));
     }
   }
   ```

2. Move email sending to background queue (SQS):
   ```javascript
   const messages = eventRegistrations.map(er => ({
     to: er.email,
     subject: `Reminder: ${er.title}`,
     body: `Your event starts tomorrow at ${er.start_datetime}`
   }));
   await sqs.sendMessageBatch(messages);
   ```

3. Implement retry logic and error handling for individual email failures

---

#### S-3: Synchronous Email Sending in Critical User Flow

**Location**: Section 6.1 `createRegistration` function (line 202)

**Issue**: Registration confirmation email is sent synchronously within the registration transaction:
```javascript
const registration = await registrationRepository.create({...});
await notificationService.sendRegistrationConfirmation(userId, eventId); // Blocks response
return registration;
```

**Impact**:
- **Slow user response**: SES API call (100-500ms) blocks HTTP response
- **Failure cascading**: SES outage or rate limiting causes registration failure despite successful DB insert
- **Poor user experience**: User waits for email delivery before seeing confirmation
- **At 500 concurrent users**: Email sending becomes throughput bottleneck

**Recommendation**:
1. Move notification to background queue:
   ```javascript
   async function createRegistration(eventId, userId) {
     const registration = await registrationRepository.create({...});

     // Enqueue notification instead of blocking
     await sqs.sendMessage({
       type: 'registration_confirmation',
       userId,
       eventId,
       registrationId: registration.id
     });

     return registration; // Immediate response
   }
   ```

2. Create dedicated notification worker to process SQS messages
3. Implement retry logic with exponential backoff for email failures
4. Add dead-letter queue for undeliverable messages

---

#### S-4: Unbounded Data Growth Without Lifecycle Management

**Location**: Section 7.4 (line 306-308)

**Issue**: Explicit statement of unlimited data retention for registrations and survey responses. With 10,000 registrations/month:
- Year 1: 120,000 registration records
- Year 3: 360,000 registration records
- No archiving, partitioning, or purge strategy

**Impact**:
- **Query performance degradation**: JOIN operations on registrations table slow down linearly with row count
- **Database storage costs**: Unlimited growth increases RDS storage costs
- **Backup/restore times**: Full backups take longer as data accumulates
- **Index maintenance overhead**: Larger indexes slow down write operations
- **Analytics queries**: Historical reporting becomes slower without data warehouse separation

**Recommendation**:
1. Define data retention policy:
   - Active events: Keep all data
   - Completed events < 2 years: Keep in primary database
   - Completed events > 2 years: Archive to S3 (Parquet format) and delete from RDS

2. Implement table partitioning by event date:
   ```sql
   CREATE TABLE registrations (
     ...
     registered_at TIMESTAMP
   ) PARTITION BY RANGE (registered_at);

   CREATE TABLE registrations_2026 PARTITION OF registrations
     FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
   ```

3. Create monthly archival batch job:
   ```javascript
   async function archiveOldRegistrations() {
     const cutoffDate = new Date();
     cutoffDate.setFullYear(cutoffDate.getFullYear() - 2);

     const oldRecords = await db.query(`
       SELECT * FROM registrations
       WHERE registered_at < $1
     `, [cutoffDate]);

     await s3.upload({
       Bucket: 'event-archive',
       Key: `registrations-${cutoffDate.getFullYear()}.parquet`,
       Body: convertToParquet(oldRecords)
     });

     await db.query(`DELETE FROM registrations WHERE registered_at < $1`, [cutoffDate]);
   }
   ```

---

#### S-5: Missing Database Connection Pooling Configuration

**Location**: Section 3.2 Data Access Layer, no connection management specified

**Issue**: With 500 concurrent users and multiple database queries per request (registration flow = 3 queries, dashboard = 2-3 queries), connection pooling strategy is undefined.

**Impact**:
- **Connection exhaustion**: Default pool sizes may not support 500 concurrent connections
- **Slow connection establishment**: Creating new connections per request adds 50-100ms overhead
- **Database server overload**: PostgreSQL RDS max_connections limit exceeded
- **Request queueing**: Requests wait for available connections, increasing latency

**Recommendation**:
1. Configure explicit connection pool with pg library:
   ```javascript
   const { Pool } = require('pg');
   const pool = new Pool({
     host: process.env.DB_HOST,
     max: 50, // Maximum pool size
     min: 10, // Minimum idle connections
     idleTimeoutMillis: 30000,
     connectionTimeoutMillis: 2000,
   });
   ```

2. Size pool based on concurrent request estimation:
   - ECS tasks: Assume 4 tasks × 12 connections = 48 connections needed
   - Configure RDS max_connections appropriately (default 100 may suffice)
   - Monitor `pg_stat_activity` for connection usage patterns

3. Implement connection health checks and retry logic
4. Add connection pool metrics to monitoring dashboard

---

#### S-6: No Rate Limiting or Request Throttling

**Location**: API Layer section (Section 3.2, line 48-53)

**Issue**: Public-facing registration endpoints lack rate limiting. Malicious or accidental abuse scenarios:
- Automated bots spamming registration endpoint
- Single user submitting hundreds of requests
- DDoS attacks on event listing endpoint

**Impact**:
- **Service degradation**: Legitimate users experience slow responses during attack
- **Database overload**: Unbounded concurrent queries exhaust database connections
- **Cost increase**: Auto-scaling triggers unnecessarily during abuse
- **Data integrity**: Spam registrations pollute event data

**Recommendation**:
1. Implement API rate limiting with express-rate-limit:
   ```javascript
   const rateLimit = require('express-rate-limit');

   const registrationLimiter = rateLimit({
     windowMs: 15 * 60 * 1000, // 15 minutes
     max: 10, // Limit each IP to 10 registrations per window
     message: 'Too many registration attempts, please try again later'
   });

   app.post('/api/registrations', registrationLimiter, registrationHandler);
   ```

2. Implement per-user rate limits (after authentication):
   ```javascript
   const userLimiter = rateLimit({
     keyGenerator: (req) => req.user.id,
     max: 5, // 5 registrations per user per 15 minutes
   });
   ```

3. Use Redis for distributed rate limiting across multiple ECS tasks:
   ```javascript
   const RedisStore = require('rate-limit-redis');
   const limiter = rateLimit({
     store: new RedisStore({ client: redisClient }),
     max: 100, // Global limit across all instances
   });
   ```

4. Add monitoring/alerting for rate limit trigger frequency

---

### MODERATE ISSUES

#### M-1: Missing Query Timeout Configuration

**Location**: Database query implementations (Section 6.2, 6.3)

**Issue**: No query timeout limits specified. Long-running queries (e.g., dashboard statistics on large events) could block connections indefinitely.

**Impact**:
- **Connection pool exhaustion**: Slow queries hold connections, starving other requests
- **Cascading failures**: Timeouts propagate to dependent services
- **Difficult debugging**: Hung queries are hard to distinguish from legitimate slow operations

**Recommendation**:
1. Set statement timeout at database level:
   ```sql
   ALTER DATABASE event_platform SET statement_timeout = '30s';
   ```

2. Set query timeout in application code:
   ```javascript
   const result = await pool.query({
     text: 'SELECT ...',
     values: [eventId],
     timeout: 5000, // 5 second timeout
   });
   ```

3. Implement timeout monitoring and alerting

---

#### M-2: Inefficient Memory Processing in Dashboard Statistics

**Location**: Section 6.2 `getEventStats` function (line 222-237)

**Issue**: Department aggregation is performed in JavaScript memory instead of database:
```javascript
const statsByDepartment = {};
registrations.forEach(reg => {
  if (!statsByDepartment[reg.department]) {
    statsByDepartment[reg.department] = 0;
  }
  statsByDepartment[reg.department]++;
});
```

**Impact**:
- **Unnecessary data transfer**: Fetches full registration rows when only counts needed
- **CPU waste**: Application server performs aggregation that database can do more efficiently
- **Memory overhead**: For 200 registrations, loads ~20KB of data for simple count operation

**Recommendation**:
Use database aggregation (already mentioned in C-3, but worth emphasizing):
```sql
SELECT
  u.department,
  COUNT(*) as total_count,
  SUM(CASE WHEN r.checked_in_at IS NOT NULL THEN 1 ELSE 0 END) as checked_in_count
FROM registrations r
JOIN users u ON r.user_id = u.id
WHERE r.event_id = $1
GROUP BY u.department
```

---

#### M-3: Missing Monitoring and Observability Infrastructure

**Location**: Section 6.5 (Logging) mentions Winston but no APM or metrics

**Issue**: Logging alone is insufficient for performance monitoring. No mention of:
- Application Performance Monitoring (APM)
- Database query performance tracking
- Cache hit rate monitoring
- API response time metrics
- Error rate tracking

**Impact**:
- **Blind to performance degradation**: Cannot detect gradual slowdowns
- **Slow incident response**: No metrics to pinpoint bottlenecks during outages
- **No baseline for optimization**: Cannot measure impact of performance improvements
- **SLA compliance unknown**: Cannot verify if meeting performance targets (once defined)

**Recommendation**:
1. Implement APM solution (e.g., Datadog, New Relic, AWS X-Ray):
   ```javascript
   const tracer = require('dd-trace').init();
   app.use(tracer.middleware());
   ```

2. Add custom metrics for business-critical flows:
   ```javascript
   const { StatsD } = require('node-statsd');
   const metrics = new StatsD();

   async function createRegistration(eventId, userId) {
     const start = Date.now();
     try {
       const result = await registrationRepository.create({...});
       metrics.timing('registration.create.duration', Date.now() - start);
       metrics.increment('registration.create.success');
       return result;
     } catch (err) {
       metrics.increment('registration.create.error');
       throw err;
     }
   }
   ```

3. Enable PostgreSQL slow query logging and send to CloudWatch
4. Create dashboards for:
   - API response time percentiles (p50, p95, p99)
   - Database connection pool usage
   - Cache hit rates
   - Error rates by endpoint
   - Registration throughput

---

#### M-4: No Circuit Breaker for External Service Calls

**Location**: External service integrations (SES for email, S3 for files) throughout codebase

**Issue**: Direct calls to SES/S3 without timeout, retry, or circuit breaker patterns. Service failures cascade to application failures.

**Impact**:
- **Cascading failures**: SES outage causes registration endpoint failures
- **Resource exhaustion**: Hung HTTP connections to external services
- **Poor fault isolation**: Single service failure affects entire platform

**Recommendation**:
1. Implement circuit breaker with library like `opossum`:
   ```javascript
   const CircuitBreaker = require('opossum');

   const sesBreaker = new CircuitBreaker(ses.sendEmail, {
     timeout: 3000, // 3 second timeout
     errorThresholdPercentage: 50,
     resetTimeout: 30000 // Try again after 30 seconds
   });

   sesBreaker.fallback(() => {
     // Fallback: enqueue to SQS for retry
     return sqs.sendMessage({ type: 'email_retry', ... });
   });

   await sesBreaker.fire({ to: user.email, ... });
   ```

2. Add retry logic with exponential backoff for transient failures
3. Monitor circuit breaker state and alert on open circuits

---

### MINOR IMPROVEMENTS

#### I-1: JWT Refresh Token Implementation Opportunity

**Location**: Section 5.2 (line 181-182)

**Observation**: JWT has 24-hour validity with no refresh token mechanism. Users must re-authenticate daily.

**Suggestion**: Implement refresh token rotation for better security and user experience:
- Short-lived access tokens (15 minutes)
- Long-lived refresh tokens (7 days) with rotation
- Reduces exposure window for compromised tokens
- Improves security posture without degrading UX

---

#### I-2: Consider Read Replicas for Dashboard Queries

**Location**: Dashboard statistics queries (Section 6.2)

**Observation**: Dashboard queries are read-heavy and computationally expensive. RDS Multi-AZ provides high availability but both instances are active-passive.

**Suggestion**: Add read replica for analytics workloads:
- Route dashboard queries to read replica
- Offload reporting load from primary database
- Accept eventual consistency (acceptable for statistics)
- Cost: ~$100-200/month for small replica instance vs. performance benefit

---

#### I-3: Event Listing Could Benefit from Materialized Views

**Location**: GET /api/events endpoint (Section 5.1)

**Observation**: Event listings with registration counts require JOIN or subquery. Frequent reads, infrequent writes.

**Suggestion**: Create materialized view for event listings:
```sql
CREATE MATERIALIZED VIEW event_list_view AS
SELECT
  e.*,
  COUNT(r.id) as registered_count
FROM events e
LEFT JOIN registrations r ON e.id = r.event_id
GROUP BY e.id;

CREATE UNIQUE INDEX ON event_list_view(id);
```

Refresh strategy:
- Refresh on event/registration changes (trigger-based)
- Or schedule refresh every 5 minutes (acceptable staleness)

---

## Summary

This design document demonstrates solid foundational architecture choices (3-tier design, cloud-native infrastructure, multi-AZ RDS) but exhibits **critical gaps in performance engineering** that will manifest at the stated scale of 500 concurrent users and 10,000 monthly registrations.

### Critical Risks Requiring Immediate Attention:
1. **Race condition in capacity check** (C-1) - Data integrity violation at scale
2. **Missing performance SLAs** (C-2) - No measurable targets for success
3. **Unbounded queries and missing pagination** (C-3) - Memory exhaustion risk
4. **No caching strategy despite available infrastructure** (C-4) - Wasted resources and poor scalability

### High-Priority Optimizations:
5. **Missing database indexes** (S-1) - Query performance degrades with data growth
6. **N+1 queries in batch processing** (S-2) - Batch job scalability failure
7. **Synchronous email sending** (S-3) - User experience and throughput bottleneck
8. **Unbounded data growth** (S-4) - Long-term operational risk

### Architectural Patterns to Implement:
- Database connection pooling with explicit sizing
- Redis caching with cache-aside pattern and TTL strategies
- Background job processing with SQS for notifications
- Rate limiting to prevent abuse
- Circuit breakers for external service resilience
- Comprehensive monitoring with APM and custom metrics

**Overall Assessment**: The design is functionally complete but performance-naive. Implementing the critical and significant recommendations will transform this from a prototype-grade design to a production-ready system capable of handling the specified load with acceptable performance characteristics.
