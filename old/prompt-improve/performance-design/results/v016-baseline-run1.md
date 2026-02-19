# Performance Design Review: 企業イベント管理プラットフォーム

## Executive Summary

This enterprise event management platform design contains **3 critical**, **5 significant**, and **4 moderate** performance issues that must be addressed before production deployment. The most severe concerns involve race conditions in registration handling, N+1 query patterns in batch operations, and missing performance specifications that prevent capacity planning.

---

## Critical Issues

### C-1: Race Condition in Registration Capacity Check (Section 6.1)

**Severity**: Critical

**Issue Description**:
The registration creation flow (lines 188-205) performs a check-then-act operation without transaction isolation or row-level locking:

```javascript
const registrations = await registrationRepository.findByEventId(eventId);
if (registrations.length >= event.capacity) {
  throw new Error('Event is full');
}
const registration = await registrationRepository.create({...});
```

Under concurrent load, multiple requests can pass the capacity check simultaneously before any registration is committed, allowing overselling beyond capacity limits.

**Impact Analysis**:
- At 500 concurrent users (stated peak load), race window is significant
- Capacity violations cause business logic failures (oversold events)
- Cascade failures: email notifications to rejected users after "successful" registration
- Reputation damage from double-booking or capacity violations

**Recommendations**:
1. **Immediate**: Implement row-level locking with `SELECT FOR UPDATE` on events table:
   ```sql
   BEGIN TRANSACTION;
   SELECT capacity, (SELECT COUNT(*) FROM registrations WHERE event_id = $1) as current_count
   FROM events WHERE id = $1 FOR UPDATE;
   -- Check capacity, then insert
   COMMIT;
   ```

2. **Alternative**: Use database constraints with optimistic locking:
   ```sql
   ALTER TABLE events ADD COLUMN remaining_capacity INTEGER;
   -- Decrement atomically with CHECK constraint
   UPDATE events SET remaining_capacity = remaining_capacity - 1
   WHERE id = $1 AND remaining_capacity > 0;
   ```

3. Add retry logic with exponential backoff for conflict resolution

---

### C-2: N+1 Query Antipattern in Reminder Batch (Section 6.3)

**Severity**: Critical

**Issue Description**:
The reminder sending logic (lines 246-264) executes queries in nested loops:
- Outer loop: fetch registrations for each event (N events)
- Inner loop: fetch user details for each registration (M registrations per event)

For the stated load of 500 monthly events with average 20 registrations each, this results in **500 + (500 × 20) = 10,500 database queries** in a single batch run.

**Impact Analysis**:
- Database connection pool exhaustion (no pooling config specified)
- Batch job timeout risk (9 AM execution window critical for user experience)
- Database CPU spike affecting concurrent API requests
- Email sending delays (synchronous SES calls in loop)

**Recommendations**:
1. **Immediate**: Batch fetch all data with joins:
   ```javascript
   const eventsWithParticipants = await db.query(`
     SELECT e.*, r.id as reg_id, u.email, u.name
     FROM events e
     JOIN registrations r ON e.id = r.event_id
     JOIN users u ON r.user_id = u.id
     WHERE e.start_datetime::date = $1
       AND r.status = 'registered'
   `, [tomorrow]);
   ```

2. Implement email batching (SES supports batch send API - up to 50 recipients):
   ```javascript
   const emailBatch = participants.map(p => ({
     Destination: { ToAddresses: [p.email] },
     Template: 'ReminderTemplate',
     TemplateData: JSON.stringify({ eventTitle: p.title, ... })
   }));
   await ses.sendBulkTemplatedEmail({ BulkEmailEntries: emailBatch });
   ```

3. Add async queue (SQS) for email delivery to decouple batch processing:
   - Batch job enqueues messages
   - Separate worker processes SQS queue
   - Prevents blocking on email failures

---

### C-3: Missing Performance SLA Specifications (Section 7.1)

**Severity**: Critical

**Issue Description**:
Section 7.1 specifies expected load (500 concurrent users, 10K registrations/month) but provides no performance targets:
- No API response time targets (p50/p95/p99 latency)
- No throughput requirements (requests per second)
- No error rate budgets
- No database query time limits

**Impact Analysis**:
- Cannot validate if architecture meets business requirements
- No objective criteria for performance testing acceptance
- Auto-scaling triggers (CPU 70%) are resource-based, not outcome-based
- Risk of production incidents without clear SLO violations to detect

**Recommendations**:
1. Define quantitative SLAs based on user experience requirements:
   ```
   Critical Paths (user-facing):
   - Registration API: p95 < 500ms, p99 < 1000ms
   - Event listing: p95 < 200ms
   - Dashboard stats: p95 < 2000ms (acceptable for admin view)

   Throughput:
   - Registration endpoint: 50 req/sec sustained, 100 req/sec peak
   - Read endpoints: 200 req/sec sustained

   Availability: 99.5% uptime (43.8 min/month downtime budget)
   ```

2. Add database query timeout configuration:
   ```javascript
   const pool = new Pool({
     statement_timeout: 5000, // 5 second query timeout
     query_timeout: 5000
   });
   ```

3. Implement performance monitoring aligned to SLAs (see M-4 for details)

---

## Significant Issues

### S-1: Unbounded Result Sets in Multiple Endpoints (Sections 5.1, 5.3)

**Severity**: Significant

**Issue Description**:
Critical endpoints lack pagination or result limits:
- `GET /api/events`: Returns all events matching filters (Section 5.1, line 119)
- `GET /api/dashboard/events/:event_id/stats`: Fetches all registrations for event (Section 5.3, lines 211-216)

With 500 monthly events and growing historical data, unbounded queries will degrade linearly with time.

**Impact Analysis**:
- Event listing: 500 events × 200 bytes ≈ 100KB response (manageable now, but compounds monthly)
- Dashboard stats: Large events (200 capacity) fetch 200+ rows, perform client-side aggregation in JS (lines 222-228)
- Memory consumption scales with result set size in Node.js process
- Network latency increases proportionally with payload size

**Recommendations**:
1. **Events endpoint**: Add pagination with cursor or offset-based approach:
   ```javascript
   GET /api/events?limit=50&offset=0&category=seminar
   Response: {
     events: [...],
     pagination: { total: 500, limit: 50, offset: 0, hasNext: true }
   }
   ```

2. **Dashboard stats**: Move aggregation to database:
   ```sql
   SELECT
     COUNT(*) as total_registrations,
     COUNT(checked_in_at) as checked_in_count,
     u.department,
     COUNT(u.id) as dept_count
   FROM registrations r
   JOIN users u ON r.user_id = u.id
   WHERE r.event_id = $1
   GROUP BY u.department;
   ```
   This eliminates client-side iteration (lines 223-228) and reduces memory usage.

3. Add default limit (e.g., 100) even when pagination not requested to prevent accidental unbounded queries

---

### S-2: Missing Database Indexes on Query-Critical Columns (Section 4.1)

**Severity**: Significant

**Issue Description**:
The schema (Section 4.1, lines 72-113) defines tables but does not specify indexes. Critical query paths require indexes:
- `registrations.event_id`: Used in all registration queries (capacity checks, stats, reminders)
- `events.start_datetime`: Used in reminder batch filtering by date
- `events.category` and `events.status`: Used in event listing filters (Section 5.1)
- `registrations.user_id`: Used in user-specific queries

Without indexes, queries perform full table scans.

**Impact Analysis**:
- At 10K monthly registrations, `findByEventId` scans entire registrations table
- Reminder batch (Section 6.3, line 250) scans all events to find tomorrow's events
- Query performance degrades O(n) with data growth
- Database CPU spikes during peak hours (registration rush before popular events)

**Recommendations**:
1. **Immediate**: Add indexes for foreign keys and filter columns:
   ```sql
   CREATE INDEX idx_registrations_event_id ON registrations(event_id);
   CREATE INDEX idx_registrations_user_id ON registrations(user_id);
   CREATE INDEX idx_events_start_datetime ON events(start_datetime);
   CREATE INDEX idx_events_category ON events(category) WHERE status = 'published';
   CREATE INDEX idx_events_status ON events(status);
   CREATE INDEX idx_survey_responses_event_id ON survey_responses(event_id);
   ```

2. For dashboard stats query (lines 211-216), create composite index:
   ```sql
   CREATE INDEX idx_registrations_event_status ON registrations(event_id, status)
   INCLUDE (checked_in_at);
   ```

3. Monitor index usage with PostgreSQL's `pg_stat_user_indexes` and adjust based on actual query patterns

---

### S-3: Synchronous Email Sending in Request Path (Section 6.1)

**Severity**: Significant

**Issue Description**:
The registration creation flow (line 202) performs synchronous email sending within the HTTP request handler:
```javascript
await notificationService.sendRegistrationConfirmation(userId, eventId);
```

**Impact Analysis**:
- SES API latency (50-200ms typical) directly adds to registration response time
- Email delivery failures cause registration rollback or inconsistent state
- Spike in registrations during popular event openings causes request queuing
- Violates separation of concerns: user feedback dependent on email infrastructure availability

**Recommendations**:
1. **Immediate**: Move email sending to async queue:
   ```javascript
   const registration = await registrationRepository.create({...});
   await sqsClient.sendMessage({
     QueueUrl: NOTIFICATION_QUEUE_URL,
     MessageBody: JSON.stringify({
       type: 'REGISTRATION_CONFIRMATION',
       userId, eventId, registrationId: registration.id
     })
   });
   return registration; // Return immediately
   ```

2. Implement background worker to process notification queue:
   - Separate ECS service consuming SQS messages
   - Retry logic with exponential backoff (SQS supports dead-letter queues)
   - Idempotency keys to prevent duplicate emails

3. Add in-app notification as primary confirmation mechanism, with email as secondary channel

---

### S-4: Missing Connection Pooling Configuration (Section 2)

**Severity**: Significant

**Issue Description**:
The tech stack (Section 2) specifies PostgreSQL but does not define connection pooling parameters. The reminder batch (Section 6.3) and concurrent API requests will create connection storms.

**Impact Analysis**:
- PostgreSQL default `max_connections = 100`, but RDS may have lower limits based on instance size
- Each API request may open new connection without pooling, exhausting connection limit
- Connection establishment overhead (TCP handshake + auth) adds 10-50ms per request
- Database rejects connections when limit exceeded, causing 500 errors

**Recommendations**:
1. **Immediate**: Configure connection pool in application:
   ```javascript
   const pool = new Pool({
     host: process.env.DB_HOST,
     database: process.env.DB_NAME,
     max: 20, // Max connections in pool
     min: 5, // Minimum idle connections
     idleTimeoutMillis: 30000, // Close idle connections after 30s
     connectionTimeoutMillis: 5000, // Fail fast if pool exhausted
     maxUses: 7500 // Recycle connections periodically
   });
   ```

2. Size pool based on load: `pool_size = (num_ecs_tasks × connections_per_task) < db_max_connections`
   - Recommended: 10 ECS tasks × 20 connections = 200 total (configure RDS for 250 max)

3. Use RDS Proxy for additional connection pooling at infrastructure level (reduces Lambda/Fargate cold start connection overhead)

---

### S-5: Unbounded Data Growth Without Lifecycle Management (Section 7.4)

**Severity**: Significant

**Issue Description**:
Section 7.4 explicitly states "registrations、survey_responsesなどの履歴データは無期限で保持される" (historical data retained indefinitely). At 10K registrations/month, data volume compounds indefinitely.

**Impact Analysis**:
- Linear degradation: Query performance decreases as table size grows
- 10 years = 1.2M registrations, multi-GB table size
- Index maintenance cost increases with table size
- Backup/restore times increase proportionally
- Storage costs grow unbounded (though RDS storage auto-scaling mitigates cost, not performance)

**Recommendations**:
1. **Immediate**: Define data retention policy based on business/compliance requirements:
   ```
   Hot data (active queries): Events in past 2 years
   Warm data (archival): Events 2-7 years old → move to separate archive table
   Cold data: Events >7 years → export to S3 (Parquet format) and delete from RDS
   ```

2. Implement table partitioning by date:
   ```sql
   CREATE TABLE registrations (
     ...
     registered_at TIMESTAMP NOT NULL
   ) PARTITION BY RANGE (registered_at);

   CREATE TABLE registrations_2026 PARTITION OF registrations
   FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
   ```
   This allows efficient partition pruning in queries and easy archival (detach old partitions).

3. Add automated archival job:
   - Monthly cron job to export old data to S3
   - Delete archived data from RDS
   - Maintain S3 data with Athena for long-term analytics

---

## Moderate Issues

### M-1: Suboptimal Caching Strategy (Section 2, 3)

**Severity**: Moderate

**Issue Description**:
Redis is listed as available infrastructure (Section 2, line 27) but "現時点でキャッシュ戦略は未定義" (no caching strategy currently defined). Event listings and dashboard stats are high-read, low-write workloads ideal for caching.

**Impact Analysis**:
- Event listing API hit on every page view, but event data changes infrequently
- Dashboard stats involve complex joins (lines 211-220), repeated queries for same event
- Database CPU usage higher than necessary for read-heavy workload

**Recommendations**:
1. Implement read-through cache for event listings:
   ```javascript
   async function getEvents(category, status) {
     const cacheKey = `events:${category}:${status}`;
     const cached = await redis.get(cacheKey);
     if (cached) return JSON.parse(cached);

     const events = await eventRepository.find({ category, status });
     await redis.setex(cacheKey, 300, JSON.stringify(events)); // 5 min TTL
     return events;
   }
   ```

2. Cache dashboard stats with write-through invalidation:
   ```javascript
   // Cache stats with 1 hour TTL
   const statsKey = `event:${eventId}:stats`;
   // Invalidate on registration create/checkin
   await redis.del(statsKey);
   ```

3. Use cache-aside pattern for user profile data (department lookups in stats)

4. Monitor cache hit rate - target >80% for event reads

---

### M-2: Missing Concurrency Control in Registration Updates (Section 6.1)

**Severity**: Moderate

**Issue Description**:
While C-1 addresses capacity race conditions, the registration flow does not handle concurrent modifications to the same registration (e.g., simultaneous cancel + checkin operations).

**Impact Analysis**:
- Low probability: Requires user to perform conflicting actions simultaneously
- Moderate consequence: Inconsistent state (checked-in after cancellation)
- Audit trail corruption: Last-write-wins behavior loses update history

**Recommendations**:
1. Add optimistic locking with version column:
   ```sql
   ALTER TABLE registrations ADD COLUMN version INTEGER DEFAULT 1;

   UPDATE registrations
   SET status = $1, version = version + 1
   WHERE id = $2 AND version = $3;
   -- Check affected rows = 1, else retry
   ```

2. Implement state machine validation:
   ```javascript
   const validTransitions = {
     'registered': ['cancelled', 'checked_in'],
     'checked_in': ['cancelled'], // Allow post-event cancellation for no-shows
     'cancelled': [] // Terminal state
   };
   ```

3. Add created/updated audit columns to track modification history

---

### M-3: Inefficient Algorithm in Stats Calculation (Section 6.2)

**Severity**: Moderate

**Issue Description**:
The `getEventStats` function (lines 209-239) fetches all registration data to application memory then iterates to build aggregations:
```javascript
registrations.forEach(reg => {
  if (!statsByDepartment[reg.department]) {
    statsByDepartment[reg.department] = 0;
  }
  statsByDepartment[reg.department]++;
});
```

**Impact Analysis**:
- For 200-person event: 200 row transfers + 200 JS iterations
- Memory consumption: O(n) for registrations array
- CPU usage: JavaScript aggregation slower than PostgreSQL aggregation
- Network latency: Unnecessary data transfer (full row data when only counts needed)

**Recommendations**:
1. **Immediate**: Use SQL aggregation (already covered in S-1, reinforced here):
   ```sql
   SELECT
     COUNT(*) FILTER (WHERE checked_in_at IS NOT NULL) as checked_in_count,
     COUNT(DISTINCT u.id) as total_registrations,
     u.department,
     COUNT(u.id) as dept_count
   FROM registrations r
   JOIN users u ON r.user_id = u.id
   LEFT JOIN survey_responses sr ON sr.event_id = r.event_id AND sr.user_id = r.user_id
   WHERE r.event_id = $1
   GROUP BY u.department;
   ```

2. Use PostgreSQL aggregate functions for survey response rate:
   ```sql
   SELECT
     COUNT(DISTINCT r.user_id) as total_participants,
     COUNT(DISTINCT sr.user_id) as survey_respondents
   FROM registrations r
   LEFT JOIN survey_responses sr ON sr.event_id = r.event_id
   WHERE r.event_id = $1;
   -- Calculate rate in application: survey_respondents / total_participants
   ```

3. Consider materialized view for frequently accessed stats:
   ```sql
   CREATE MATERIALIZED VIEW event_stats_mv AS
   SELECT event_id, COUNT(*) as reg_count, ...
   FROM registrations
   GROUP BY event_id;
   -- Refresh on registration create/update
   ```

---

### M-4: Incomplete Observability for Performance Monitoring (Section 6.5)

**Severity**: Moderate

**Issue Description**:
Logging configuration (Section 6.5) covers error tracking but does not address performance monitoring:
- No response time logging
- No slow query detection
- No distributed tracing (request correlation across services)

**Impact Analysis**:
- Cannot diagnose performance degradation in production
- No data to validate SLA compliance (once defined per C-3)
- Difficult to identify bottleneck between database, API layer, external services (SES)

**Recommendations**:
1. Add request timing middleware:
   ```javascript
   app.use((req, res, next) => {
     const start = Date.now();
     res.on('finish', () => {
       const duration = Date.now() - start;
       logger.info('request', {
         method: req.method,
         path: req.path,
         statusCode: res.statusCode,
         duration,
         userId: req.user?.id
       });
     });
     next();
   });
   ```

2. Enable PostgreSQL slow query log:
   ```sql
   ALTER DATABASE eventdb SET log_min_duration_statement = 1000; -- Log queries >1s
   ```

3. Implement distributed tracing with AWS X-Ray:
   - Automatically captures AWS service calls (RDS, SES, S3)
   - Visualizes request flow across services
   - Identifies latency contributors

4. Add custom metrics for business-critical operations:
   ```javascript
   // CloudWatch Metrics
   await cloudwatch.putMetricData({
     Namespace: 'EventPlatform',
     MetricData: [{
       MetricName: 'RegistrationLatency',
       Value: duration,
       Unit: 'Milliseconds',
       Dimensions: [{ Name: 'EventId', Value: eventId }]
     }]
   });
   ```

---

## Minor Observations and Positive Aspects

### Positive Design Decisions

1. **JWT with 24-hour expiration** (Section 5.2): Reasonable balance between security and user experience for low-sensitivity event management use case

2. **Multi-AZ RDS configuration** (Section 7.3): Provides database high availability without requiring application-level failover logic

3. **ECS Auto Scaling on CPU 70%** (Section 7.3): Conservative threshold reduces risk of capacity exhaustion, though should be complemented with request-rate based scaling (see C-3)

4. **Parameterized queries** (Section 7.2): SQL injection prevention properly addressed

5. **JSONB for survey responses** (Section 4.1, line 112): Flexible schema for varying survey structures, supports GIN indexing for efficient querying

### Minor Improvement Opportunities

1. **JWT refresh token**: Section 5.2 notes "リフレッシュトークン未実装" - While not critical for MVP, 24-hour sessions may frustrate power users. Consider implementing refresh tokens with 7-day validity.

2. **Blue-Green deployment** (Section 6.7): Excellent for zero-downtime releases, but ensure database migrations are backward-compatible (support N and N-1 application versions simultaneously).

3. **Error logging to stdout** (Section 6.4): Works for containerized environments but consider structured logging to CloudWatch Logs with retention policies for compliance.

4. **QR code checkin** (Section 1.2): Design does not specify QR code generation/validation logic. Consider using signed JWTs as QR payload to prevent forgery: `jwt.sign({ registrationId, eventId }, secret, { expiresIn: '24h' })`.

---

## Summary and Prioritization

### Must-Fix Before Production (Critical)
1. **C-1**: Implement transaction isolation for registration capacity checks - Prevents overselling and data corruption
2. **C-2**: Batch queries and async email processing in reminder job - Prevents database overload and batch job failures
3. **C-3**: Define explicit performance SLAs - Enables validation and monitoring

### Should-Fix in MVP (Significant)
4. **S-1**: Add pagination to event listing and move stats aggregation to database - Prevents performance degradation over time
5. **S-2**: Create indexes on foreign keys and filter columns - Essential for query performance at scale
6. **S-3**: Move email sending to async queue - Improves user experience and system resilience
7. **S-4**: Configure connection pooling - Prevents connection exhaustion under load
8. **S-5**: Define data retention policy - Prevents unbounded growth

### Post-MVP Optimization (Moderate)
9. **M-1**: Implement caching strategy for event reads - Reduces database load
10. **M-2**: Add optimistic locking for registrations - Prevents rare edge case data corruption
11. **M-3**: Optimize stats calculation algorithm - Already addressed in S-1, reinforces importance
12. **M-4**: Enhance observability with metrics and tracing - Enables proactive performance management

### Implementation Effort Estimates
- **Quick wins** (< 1 day): S-2 (indexes), S-4 (connection pooling), M-4 (basic logging)
- **Medium effort** (2-3 days): C-1 (transaction fixes), S-1 (pagination), M-1 (caching)
- **Larger effort** (1 week): C-2 (async architecture), S-3 (SQS integration), S-5 (data lifecycle)

### Risk Assessment
Without addressing critical issues:
- **High risk of data corruption** during concurrent registration peaks
- **Database performance degradation** within 6 months as data accumulates
- **Inability to validate production readiness** without defined SLAs

The significant issues represent technical debt that will compound over time - addressing them in MVP is strongly recommended to avoid costly refactoring later.
