# Performance Design Review: Enterprise Event Management Platform

## Executive Summary

This design document contains **7 critical performance issues** and **5 significant performance risks** that will impact system scalability, reliability, and user experience. The most severe issues are unbounded data growth without lifecycle management, N+1 query patterns in core features, and missing cache strategy despite Redis availability.

---

## Critical Issues

### P01: Unbounded Data Growth Without Lifecycle Management (CRITICAL)

**Issue Description:**
Section 7.4 explicitly states "現時点では明示的なデータ保持期限・アーカイブポリシーは未定義。registrations、survey_responsesなどの履歴データは無期限で保持される" (no explicit data retention policy; historical data retained indefinitely). With 10,000 monthly registrations, the `registrations` table will accumulate 120,000 records annually, growing indefinitely without archival or purging strategy.

**Performance Impact:**
- **Query degradation over time**: All queries on `registrations` table (event statistics, participant lists, dashboard aggregations) will progressively slow as table size grows from thousands to millions of rows
- **Index bloat**: Indexes on `event_id`, `user_id`, and composite indexes will grow proportionally, increasing memory footprint and reducing cache hit rates
- **Backup/restore degradation**: Database backup windows will expand, increasing RTO/RPO risks
- **Storage cost escalation**: 5+ years of accumulated data will consume significant storage without business value

**Why This Matters:**
The `getEventStats` function (lines 210-239) performs full table scans filtered by `event_id`. For popular events with 500+ registrations each, and with 3-5 years of historical events accumulating, a single query could scan 50,000+ rows even with proper indexes. The `registrations_by_department` aggregation becomes increasingly expensive as it must process and group all matching rows in memory.

**Recommendation:**
1. **Define data lifecycle policy**: Implement 2-year active retention + archival to cold storage (S3) for older data
2. **Partition strategy**: Partition `registrations` and `survey_responses` by year (`PARTITION BY RANGE (EXTRACT(YEAR FROM registered_at))`) to isolate historical data
3. **Implement soft delete + archival job**: Monthly batch job to move records older than 2 years to archive tables or S3 Parquet files
4. **Add `archived` boolean column**: Enable efficient filtering of active vs archived data in queries

**Cost-Benefit Analysis:**
- Implementation: 2-3 days (partitioning, archival job, query updates)
- Ongoing maintenance: Minimal (automated archival)
- Performance gain: 10-100x query improvement for multi-year datasets; prevents gradual system degradation

---

### P02: N+1 Query Pattern in Reminder Batch Processing (CRITICAL)

**Issue Description:**
The `sendReminders` function (lines 246-264) contains a nested loop with database queries inside:
```javascript
for (const event of events) {
  const registrations = await registrationRepository.findByEventId(event.id); // Query 1
  for (const registration of registrations) {
    const user = await userRepository.findById(registration.user_id);        // Query 2 (N+1)
    await ses.sendEmail(...);                                                 // I/O 3
  }
}
```

For 10 events with 100 participants each, this executes:
- 1 query to fetch events
- 10 queries to fetch registrations (one per event)
- **1,000 queries to fetch users** (N+1 pattern)
- 1,000 SES API calls (synchronous)

Total: **1,011 database queries** for a single batch run.

**Performance Impact:**
- **Batch timeout risk**: With 10ms per query + 50ms per SES call, total execution time = 60 seconds for 1,000 participants. Scales linearly with participant count, risking Lambda/ECS task timeouts
- **Database connection exhaustion**: 1,000+ sequential queries consume connection pool resources, blocking other application queries
- **Cascading failures**: If batch runs during peak hours (9 AM send time coincides with user activity), it can saturate the database and degrade API response times for interactive users

**Why This Matters:**
The design specifies 10,000 monthly registrations (Section 7.1), which averages ~17 events/day with ~20 participants each. During conference-heavy periods (e.g., quarterly all-hands), this could spike to 50 events/day with 200 participants each = **10,000 user queries** in a single batch run.

**Recommendation:**
1. **Batch load users with JOIN**:
   ```javascript
   const events = await eventRepository.findByDate(tomorrow);
   const eventIds = events.map(e => e.id);

   const registrationsWithUsers = await db.query(`
     SELECT r.*, u.email, u.name, e.title, e.start_datetime
     FROM registrations r
     JOIN users u ON r.user_id = u.id
     JOIN events e ON r.event_id = e.id
     WHERE r.event_id = ANY($1)
   `, [eventIds]);
   ```
   Reduces 1,011 queries to **2 queries** (events + bulk JOIN).

2. **Asynchronous email sending**:
   - Push email tasks to SQS queue instead of synchronous SES calls
   - Separate worker processes consume queue and send emails in parallel
   - Decouples batch job from email delivery latency

3. **Add observability**:
   - Log batch execution metrics: event count, participant count, duration, errors
   - Alert if batch duration exceeds 5 minutes

**Cost-Benefit Analysis:**
- Implementation: 4-6 hours (query refactoring, SQS integration)
- Performance gain: 1,011 queries → 2 queries (500x reduction); batch time from 60s → <5s
- Reliability gain: Eliminates connection pool exhaustion risk; graceful degradation if SES rate limits hit

---

### P03: Missing Cache Strategy Despite Redis Availability (CRITICAL)

**Issue Description:**
Section 2 states "Cache: Redis 7（ElastiCache）が利用可能だが、現時点でキャッシュ戦略は未定義" (Redis available but cache strategy undefined). The design does not specify which data to cache, cache invalidation rules, or TTL policies. This is a **missing design element**, not a misconfiguration.

**Performance Impact:**
- **Repeated expensive queries**: The `GET /api/events` endpoint (lines 119-139) likely fetches all events with registration counts on every request. For a dashboard page making 3-5 API calls on load, this redundantly executes the same queries
- **Database load amplification**: With 500 concurrent users (Section 7.1), popular endpoints like event listings and dashboard stats create 100+ QPS to PostgreSQL for read-only data that changes infrequently
- **Wasted infrastructure**: Paying for ElastiCache without utilizing it = dead cost

**Why This Matters:**
Consider the event listing scenario:
1. **Event metadata** (title, date, capacity) changes rarely (only when organizers edit events)
2. **Registration counts** change frequently (every new signup) but exact real-time accuracy is not critical (showing "150 registrations" vs "152" is acceptable)
3. Without caching, every user viewing the event list triggers a database query, even if the data is identical to the previous 100 requests

**High-Value Cache Opportunities:**
1. **Event listings** (cache key: `events:list:{category}:{status}`, TTL: 5 minutes)
   - Invalidate on event creation/update/deletion
   - Registration count can be slightly stale
2. **Event details** (cache key: `events:{event_id}`, TTL: 10 minutes)
   - Invalidate on event update
3. **Dashboard statistics** (cache key: `stats:{event_id}`, TTL: 30 minutes)
   - Expensive aggregations (department breakdown, survey rates)
   - Invalidate on new registrations/check-ins (or accept eventual consistency)
4. **User profiles** (cache key: `users:{user_id}`, TTL: 1 hour)
   - Reduces repeated lookups in batch jobs and API calls

**Recommendation:**
1. **Define cache-first read pattern for event listings**:
   ```javascript
   async function getEvents(category, status) {
     const cacheKey = `events:list:${category}:${status}`;
     const cached = await redis.get(cacheKey);
     if (cached) return JSON.parse(cached);

     const events = await eventRepository.find({ category, status });
     await redis.setex(cacheKey, 300, JSON.stringify(events)); // 5 min TTL
     return events;
   }
   ```

2. **Implement write-through cache invalidation**:
   - On event update: `await redis.del(`events:${eventId}`, `events:list:*`)`
   - Use Redis key patterns for bulk invalidation

3. **Document cache coherence rules**:
   - Which data is cacheable (events, users, stats)
   - Which data must be real-time (registrations during signup to prevent overselling)
   - TTL values and invalidation triggers

4. **Add cache metrics**:
   - Cache hit rate by key pattern
   - Average response time with/without cache
   - Alert if hit rate <70%

**Cost-Benefit Analysis:**
- Implementation: 1-2 days (cache integration, invalidation logic, testing)
- Performance gain: 50-80% reduction in database queries for read-heavy endpoints
- Latency improvement: Event listing response time from 100-200ms → 5-10ms (cache hit)
- Infrastructure efficiency: Reduces RDS provisioned IOPS/capacity requirements

---

### P04: Race Condition in Registration Capacity Check (CRITICAL)

**Issue Description:**
The `createRegistration` function (lines 188-205) has a time-of-check-time-of-use (TOCTOU) race condition:
```javascript
const event = await eventRepository.findById(eventId);           // Step 1
const registrations = await registrationRepository.findByEventId(eventId); // Step 2

if (registrations.length >= event.capacity) {                    // Step 3: Check
  throw new Error('Event is full');
}

const registration = await registrationRepository.create({...}); // Step 4: Use
```

**Failure Scenario:**
1. Event has 199/200 capacity filled
2. Users A and B simultaneously submit registration requests (t=0)
3. Both requests pass Steps 1-3 (see 199 < 200) at t=1ms
4. Both requests execute Step 4 at t=2ms
5. **Result**: Event now has 201 registrations (oversold by 1)

With 500 concurrent users (Section 7.1), this race window becomes statistically significant during high-demand events (e.g., limited-seat executive sessions, popular conferences).

**Performance Impact:**
- **Data integrity violations**: Overselling leads to logistical failures (not enough seats/materials), damaging user trust
- **Compensating transaction overhead**: Requires manual intervention to resolve oversold events (refunds, apologies, waitlists)
- **Increased contention under load**: Higher concurrency amplifies race probability

**Why This Matters:**
The check-then-act pattern is executed across 2-3 separate database queries with no transactional isolation. PostgreSQL's default `READ COMMITTED` isolation level does not prevent this race. Even with a transaction wrapper, the gap between SELECT (count) and INSERT (registration) allows interleaving.

**Recommendation:**
1. **Database-level atomic constraint**:
   ```sql
   -- Option A: Materialized registration count with CHECK constraint
   ALTER TABLE events ADD COLUMN current_registrations INTEGER DEFAULT 0;
   ALTER TABLE events ADD CONSTRAINT check_capacity
     CHECK (current_registrations <= capacity);

   -- Increment count atomically on registration insert (trigger)
   CREATE TRIGGER update_registration_count
     AFTER INSERT ON registrations
     FOR EACH ROW EXECUTE FUNCTION increment_event_count();
   ```

2. **Optimistic locking with version field**:
   ```javascript
   // Add version column to events table
   const result = await db.query(`
     UPDATE events
     SET current_registrations = current_registrations + 1, version = version + 1
     WHERE id = $1 AND current_registrations < capacity AND version = $2
     RETURNING *
   `, [eventId, expectedVersion]);

   if (result.rowCount === 0) {
     throw new Error('Event is full or version conflict');
   }
   ```

3. **Distributed lock (Redis-based)**:
   ```javascript
   const lock = await redlock.lock(`event:${eventId}:register`, 1000);
   try {
     // Perform capacity check and registration
   } finally {
     await lock.unlock();
   }
   ```
   Note: This adds latency (lock acquisition overhead) but guarantees correctness.

**Recommended Approach**: Option 1 (database constraint) is most robust and performant. The trigger maintains consistency without application-level coordination, and the CHECK constraint provides a final safety net.

**Cost-Benefit Analysis:**
- Implementation: 3-4 hours (schema migration, trigger development, testing)
- Performance impact: Negligible (trigger executes in <1ms)
- Reliability gain: Eliminates race condition; prevents overselling

---

### P05: Inefficient Dashboard Statistics Query (HIGH)

**Issue Description:**
The `getEventStats` function (lines 210-239) executes 2 separate queries and performs client-side aggregation:
```javascript
const registrations = await db.query(`
  SELECT r.*, u.department
  FROM registrations r
  JOIN users u ON r.user_id = u.id
  WHERE r.event_id = $1
`, [eventId]);

const surveyResponses = await db.query(`
  SELECT * FROM survey_responses WHERE event_id = $1
`, [eventId]);

// Client-side aggregation (lines 223-237)
registrations.forEach(reg => { ... }); // Department grouping
registrations.filter(r => r.checked_in_at).length; // Check-in count
```

**Performance Issues:**
1. **Over-fetching**: Retrieves all columns (`r.*`, `u.department`) when only specific fields are needed for aggregation
2. **Client-side processing**: JavaScript loops over potentially 500+ rows to compute statistics that the database can calculate in a single pass
3. **Missing indexes**: No evidence of index on `survey_responses.event_id` or composite index on `registrations(event_id, status)`

**Performance Impact:**
- **Network overhead**: Fetching 500 full registration records (with all user fields) = 50-100KB transferred from RDS to application
- **Memory consumption**: Loading entire result set into memory before aggregation
- **CPU waste**: Client-side grouping and filtering instead of database-optimized aggregation
- **Response latency**: For large events (200 participants), query + transfer + processing = 200-500ms vs optimized query at 50-100ms

**Why This Matters:**
Dashboard endpoints are frequently accessed by event organizers to monitor real-time participation. The `/api/dashboard/events/:event_id/stats` endpoint (lines 158-172) is likely called every time an organizer views an event page. With 500 monthly events and 5 organizer views per event = 2,500 expensive queries per month.

**Recommendation:**
1. **Single optimized aggregation query**:
   ```javascript
   async function getEventStats(eventId) {
     const stats = await db.query(`
       SELECT
         COUNT(*) as total_registrations,
         COUNT(*) FILTER (WHERE checked_in_at IS NOT NULL) as checked_in_count,
         u.department,
         COUNT(u.department) as dept_count
       FROM registrations r
       JOIN users u ON r.user_id = u.id
       WHERE r.event_id = $1
       GROUP BY u.department
     `, [eventId]);

     const surveyCount = await db.query(`
       SELECT COUNT(*) as count FROM survey_responses WHERE event_id = $1
     `, [eventId]);

     return {
       total_registrations: stats[0]?.total_registrations || 0,
       checked_in_count: stats[0]?.checked_in_count || 0,
       survey_response_rate: surveyCount[0].count / (stats[0]?.total_registrations || 1),
       registrations_by_department: stats.map(s => ({
         department: s.department,
         count: s.dept_count
       }))
     };
   }
   ```

2. **Add missing indexes**:
   ```sql
   CREATE INDEX idx_registrations_event_checkin
     ON registrations(event_id, checked_in_at);
   CREATE INDEX idx_survey_responses_event
     ON survey_responses(event_id);
   ```

3. **Cache results** (combines with P03):
   Cache dashboard stats with 15-minute TTL, invalidate on new registration/check-in.

**Cost-Benefit Analysis:**
- Implementation: 2-3 hours (query refactoring, index creation)
- Performance gain: 200-500ms → 50-100ms (3-5x improvement)
- Network reduction: 50-100KB → 1-2KB (50x less data transfer)
- Database load: Reduces CPU cycles by offloading aggregation to PostgreSQL optimizer

---

### P06: Unbounded Event Listing Without Pagination (HIGH)

**Issue Description:**
The `GET /api/events` endpoint (lines 119-139) has no pagination parameters (no `limit`, `offset`, `page`, or cursor). The response shows an array of events (`"events": [...]`) with no indication of pagination metadata (total count, next page, etc.).

**Performance Impact:**
- **Initial load**: Fetching all 500 monthly events (Section 7.1) in a single response = 50-100KB payload
- **Growth trajectory**: As the platform matures, historical events accumulate. Without archival (see P01), the events table could contain 5,000-10,000 events after 1-2 years
- **Client-side rendering overhead**: Frontend must parse and render potentially thousands of events, causing browser jank
- **Wasted bandwidth**: Users typically view only the first 10-20 events; fetching all is inefficient

**Why This Matters:**
The API design shows optional filters (`category`, `status`) but no result limiting. A query like `GET /api/events?status=published` could return all published events across all time. The response format `{"events": [...]}` suggests a flat array, not a paginated structure.

**Recommendation:**
1. **Add cursor-based pagination** (preferred for performance):
   ```javascript
   // GET /api/events?limit=20&cursor=<last_event_id>
   async function getEvents(category, status, limit = 20, cursor = null) {
     const query = `
       SELECT * FROM events
       WHERE ($1::varchar IS NULL OR category = $1)
         AND ($2::varchar IS NULL OR status = $2)
         AND ($3::uuid IS NULL OR id > $3)
       ORDER BY id ASC
       LIMIT $4
     `;
     const events = await db.query(query, [category, status, cursor, limit]);
     return {
       events,
       next_cursor: events.length === limit ? events[events.length - 1].id : null
     };
   }
   ```

2. **Default limit**: Enforce `limit=50` if not specified to prevent accidental full scans

3. **Add index**: `CREATE INDEX idx_events_status_id ON events(status, id)` to support cursor pagination efficiently

**Cost-Benefit Analysis:**
- Implementation: 3-4 hours (API changes, frontend pagination UI)
- Performance gain: 100KB response → 10KB response (10x reduction)
- Scalability: Prevents degradation as dataset grows from 500 to 10,000+ events

---

### P07: Synchronous Email Sending in Request Path (HIGH)

**Issue Description:**
The `createRegistration` function (lines 188-205) calls `notificationService.sendRegistrationConfirmation` synchronously within the registration request:
```javascript
const registration = await registrationRepository.create({...});
await notificationService.sendRegistrationConfirmation(userId, eventId); // Blocking call
return registration;
```

**Performance Impact:**
- **Latency inflation**: User waits for database INSERT (50ms) + SES API call (100-300ms) + email delivery acknowledgment
- **Timeout risk**: If SES experiences slowness or rate limiting (10 emails/sec burst limit for standard accounts), registration requests fail with 500 errors
- **User experience degradation**: Registration should feel instant; waiting 300-500ms for email confirmation creates perceived slowness

**Why This Matters:**
Email delivery is a non-critical side effect. Users expect registration confirmation to be sent, but they don't need to wait for it to complete before receiving a success response. The registration is "done" once the database record is committed; email is an async follow-up.

**Recommendation:**
1. **Push email tasks to SQS queue**:
   ```javascript
   const registration = await registrationRepository.create({...});

   await sqs.sendMessage({
     QueueUrl: process.env.NOTIFICATION_QUEUE_URL,
     MessageBody: JSON.stringify({
       type: 'registration_confirmation',
       user_id: userId,
       event_id: eventId,
       registration_id: registration.id
     })
   });

   return registration; // Respond immediately
   ```

2. **Separate worker process**:
   - Dedicated ECS task or Lambda function consumes notification queue
   - Sends emails via SES with retry logic (exponential backoff)
   - Logs failures to DLQ for manual review

3. **Add observability**:
   - CloudWatch metric: notification queue depth
   - Alert if queue depth >1,000 or email failure rate >5%

**Cost-Benefit Analysis:**
- Implementation: 4-6 hours (SQS integration, worker deployment)
- Latency improvement: 300-500ms → 50ms (6-10x faster registration response)
- Reliability: Decouples registration success from email delivery; graceful degradation if SES fails

---

## Significant Performance Risks

### R01: Missing Database Index Strategy

**Issue**: The database schema (Section 4.1) defines tables but does not specify indexes beyond primary keys. Critical foreign keys (`registrations.event_id`, `registrations.user_id`, `survey_responses.event_id`) likely lack indexes.

**Impact**:
- Full table scans on JOIN operations (e.g., `getEventStats` query)
- O(n) lookup for `findByEventId` queries instead of O(log n)

**Recommendation**:
```sql
CREATE INDEX idx_registrations_event_id ON registrations(event_id);
CREATE INDEX idx_registrations_user_id ON registrations(user_id);
CREATE INDEX idx_survey_responses_event_id ON survey_responses(event_id);
CREATE INDEX idx_registrations_status ON registrations(event_id, status);
```

---

### R02: Missing NFR Specifications

**Issue**: Section 7.1 lists "想定負荷" (expected load) but no concrete SLAs or performance targets:
- No API response time targets (e.g., p95 <200ms)
- No throughput requirements (e.g., 100 registrations/min)
- No capacity planning for peak scenarios (e.g., Black Friday-style event launches)

**Impact**:
- Cannot validate whether the design meets performance requirements (no requirements defined)
- No basis for load testing or capacity planning
- Risk of discovering performance issues in production

**Recommendation**:
Define measurable NFRs:
- **API latency**: p95 response time <300ms for all endpoints
- **Throughput**: Support 50 concurrent registrations/sec (3,000/min peak)
- **Database capacity**: <70% CPU utilization at peak load
- **Cache hit rate**: >80% for event listings

---

### R03: No Connection Pooling Configuration Specified

**Issue**: The design mentions Express and PostgreSQL but does not specify connection pool settings (min/max connections, idle timeout, connection lifetime).

**Impact**:
- Default pool settings (often 10 connections) may be insufficient for 500 concurrent users
- Connection exhaustion under load causes cascading failures (requests queue waiting for free connections)

**Recommendation**:
Document connection pool configuration:
```javascript
const pool = new Pool({
  max: 50,              // Max connections (tune based on RDS instance size)
  min: 10,              // Min idle connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000
});
```

Rule of thumb: `max_connections = (RDS instance cores * 2) + effective_spindle_count`

---

### R04: Missing Monitoring and Alerting Strategy

**Issue**: Section 6.5 mentions logging (Winston) but no discussion of application performance monitoring (APM), query performance tracking, or alerting thresholds.

**Impact**:
- Performance degradation goes unnoticed until users complain
- No visibility into slow queries, high error rates, or resource saturation
- Cannot proactively identify issues before they cause outages

**Recommendation**:
1. **Add APM instrumentation**: Integrate New Relic, Datadog, or AWS X-Ray for distributed tracing
2. **Database query monitoring**: Enable RDS Performance Insights; alert on slow queries >1s
3. **Key metrics to track**:
   - API endpoint latency (p50, p95, p99)
   - Database connection pool utilization
   - Cache hit rate
   - Error rate by endpoint
   - SQS queue depth (if implementing async email)

---

### R05: ECS Auto Scaling Based Solely on CPU (Reactive, Not Predictive)

**Issue**: Section 7.3 states "ECS Auto Scaling（CPU使用率70%以上で追加インスタンス起動）" (scale when CPU >70%). This is a reactive scaling policy.

**Impact**:
- **Scale-out lag**: New instances take 2-5 minutes to provision, register, and start serving traffic. During this window, existing instances are overloaded
- **Thundering herd**: If a popular event opens for registration, sudden traffic spike can overwhelm the system before auto-scaling triggers
- **Mismatch with workload**: CPU may not correlate with load (e.g., I/O-bound workloads have low CPU but high latency)

**Recommendation**:
1. **Add target tracking on request count**: Scale based on requests/target (e.g., 1,000 requests/task) in addition to CPU
2. **Implement scheduled scaling**: If event launches are predictable (e.g., Mondays at 10 AM), pre-scale capacity before peak
3. **Use step scaling**: Multiple thresholds (70% = +1 instance, 85% = +2 instances) for faster response
4. **Add warmup time**: Configure `estimated_instance_warmup = 120s` to account for task startup

---

## Summary Table

| ID | Issue | Severity | Estimated Impact | Fix Effort |
|----|-------|----------|------------------|------------|
| P01 | Unbounded data growth | Critical | Query degradation over time; 10-100x slowdown in 2-3 years | 2-3 days |
| P02 | N+1 query in reminder batch | Critical | 1,011 queries per batch; connection exhaustion risk | 4-6 hours |
| P03 | Missing cache strategy | Critical | 50-80% wasted database load; paying for unused Redis | 1-2 days |
| P04 | Race condition in capacity check | Critical | Overselling events; data integrity violations | 3-4 hours |
| P05 | Inefficient dashboard query | High | 3-5x slower than necessary; 50x data over-fetch | 2-3 hours |
| P06 | Unbounded event listing | High | 100KB responses; degrades to 1MB+ as data grows | 3-4 hours |
| P07 | Synchronous email in request path | High | 300-500ms latency inflation; timeout risk | 4-6 hours |
| R01 | Missing database indexes | Medium | Full table scans on foreign key lookups | 1 hour |
| R02 | Missing NFR specifications | Medium | Cannot validate performance; no testing baseline | 2-3 hours |
| R03 | No connection pool config | Medium | Connection exhaustion under load | 1 hour |
| R04 | Missing monitoring strategy | Medium | Blind to performance degradation | 1-2 days |
| R05 | Reactive-only auto scaling | Low | 2-5 min scale-out lag during traffic spikes | 2-3 hours |

**Total estimated fix effort**: 6-8 days (critical issues only: 4-5 days)

---

## Prioritized Remediation Plan

### Phase 1: Pre-Launch Critical Fixes (Must-Have)
1. **P04** (Race condition): Implement database constraint to prevent overselling
2. **P03** (Cache strategy): Define cache-first pattern for event listings and dashboard
3. **P02** (N+1 queries): Refactor reminder batch to use JOINs and async email queue
4. **R01** (Indexes): Add missing foreign key indexes

**Outcome**: System is functionally correct and can handle stated load (500 concurrent users).

### Phase 2: Post-Launch Optimization (First Month)
5. **P05** (Dashboard query): Optimize with database-side aggregation
6. **P06** (Pagination): Add cursor-based pagination to event listing
7. **P07** (Async email): Decouple email sending from request path
8. **R02** (NFRs): Define SLAs and conduct load testing

**Outcome**: System is performant and meets latency/throughput targets.

### Phase 3: Long-Term Sustainability (Quarterly)
9. **P01** (Data lifecycle): Implement partitioning and archival strategy
10. **R04** (Monitoring): Deploy APM and query monitoring
11. **R05** (Auto scaling): Add predictive and scheduled scaling policies

**Outcome**: System remains performant and cost-efficient as data grows and usage scales.
