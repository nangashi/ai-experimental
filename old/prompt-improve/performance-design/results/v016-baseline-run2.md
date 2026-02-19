# Performance Design Review: 企業イベント管理プラットフォーム

## Document Structure Analysis

The design document includes:
- **Present sections**: Overview, technical stack, architecture (3-tier), data model (4 entities), API design (5 endpoints), implementation details (4 code examples), NFRs (performance targets, security, availability, data retention)
- **Explicitly documented**: Database schema, API endpoints, business logic flow, deployment strategy, error handling
- **Missing or incomplete**: Caching strategy (Redis available but unused), index definitions, query optimization, connection pooling, async processing patterns, monitoring/alerting details, detailed scalability metrics

## Performance Issue Detection

### Critical Issues

#### C-1: Unbounded Result Sets in Event Listing (GET /api/events)
**Location**: Section 5.1 API Design

**Issue**: The `GET /api/events` endpoint lacks pagination, offset, or limit parameters. With 500 events/month (6,000+ events/year), this endpoint will return increasingly large result sets as the platform matures.

**Impact**:
- Linear growth in response payload size over time
- Database query execution time increases with table size
- Memory consumption scales with result set size
- Network bandwidth waste for clients needing only recent/upcoming events

**Recommendation**:
- Add pagination parameters: `?page=1&limit=20`
- Implement cursor-based pagination for stable results during concurrent writes
- Add default limit (e.g., 50) even when not specified
- Consider time-based filtering (upcoming events only) as default

#### C-2: Race Condition in Registration Capacity Check (Section 6.1)
**Location**: Section 6.1 Implementation - `createRegistration` function

**Issue**: The capacity check (lines 189-194) uses a non-atomic read-then-write pattern:
```javascript
const registrations = await registrationRepository.findByEventId(eventId);
if (registrations.length >= event.capacity) {
  throw new Error('Event is full');
}
await registrationRepository.create({...});
```

**Impact**:
- Under concurrent load (500 simultaneous users), multiple requests can pass the capacity check before any completes the insert
- Results in overbooking beyond defined capacity
- Especially problematic for high-demand events approaching capacity limits
- No mention of transaction isolation or locking strategy

**Recommendation**:
- Use database-level concurrency control:
  - Add `registered_count` column to `events` table with CHECK constraint
  - Use atomic increment: `UPDATE events SET registered_count = registered_count + 1 WHERE id = $1 AND registered_count < capacity RETURNING *`
  - Wrap in transaction with SERIALIZABLE isolation level
- Alternative: Implement optimistic locking with version field
- Add unique constraint on `(event_id, user_id)` to prevent duplicate registrations

#### C-3: Missing SLA and Latency Targets
**Location**: Section 7.1 Performance NFRs

**Issue**: The NFR section specifies load volumes (500 concurrent users, 10,000 registrations/month) but defines no latency targets, throughput SLAs, or performance acceptance criteria.

**Impact**:
- No measurable performance goals for development and testing
- Cannot validate if the architecture meets business requirements
- No basis for capacity planning or infrastructure sizing
- Unable to detect performance regressions in production

**Recommendation**:
- Define per-endpoint SLAs:
  - `GET /api/events`: p95 < 200ms, p99 < 500ms
  - `POST /api/registrations`: p95 < 300ms, p99 < 800ms
  - `GET /api/dashboard/stats`: p95 < 500ms, p99 < 1s
- Specify throughput requirements: registrations/second during peak hours
- Set database query timeout thresholds
- Define acceptable degradation modes under overload

### Significant Issues

#### S-1: N+1 Query Pattern in Reminder Batch (Section 6.3)
**Location**: Section 6.3 - `sendReminders` function

**Issue**: The reminder batch exhibits classic N+1 query antipattern with nested loops:
```javascript
for (const event of events) {
  const registrations = await registrationRepository.findByEventId(event.id);
  for (const registration of registrations) {
    const user = await userRepository.findById(registration.user_id);
    await ses.sendEmail({...});
  }
}
```

**Impact**:
- With 10-20 events tomorrow and 50-200 registrations each, this generates 1,000-4,000 sequential database queries
- Execution time: assuming 5ms/query = 5-20 seconds of pure DB time
- Blocks batch completion; if batch exceeds timeout window, reminders are not sent
- Database connection held for extended duration

**Recommendation**:
- Refactor to batch queries:
  ```javascript
  const events = await eventRepository.findByDate(tomorrow);
  const eventIds = events.map(e => e.id);
  const registrations = await registrationRepository.findByEventIds(eventIds);
  const userIds = [...new Set(registrations.map(r => r.user_id))];
  const users = await userRepository.findByIds(userIds);
  ```
- Use asynchronous email dispatch via SQS queue instead of synchronous SES calls
- Implement batch email API if SES supports it
- Add progress tracking and resumability for long-running batches

#### S-2: Dashboard Query Lacks Aggregation (Section 6.2)
**Location**: Section 6.2 - `getEventStats` function

**Issue**: The dashboard statistics are computed in application memory after fetching all registrations and survey responses:
```javascript
const registrations = await db.query(`SELECT r.*, u.department FROM registrations r JOIN users u ...`);
const surveyResponses = await db.query(`SELECT * FROM survey_responses WHERE event_id = $1`);
// In-memory aggregation using forEach
```

**Impact**:
- For popular events (200 participants), transfers 200 full records from database to app server
- Application server performs O(n) iteration for counting and grouping
- Memory consumption proportional to participant count
- Network bandwidth waste (fetches unused columns)
- Scales poorly as event capacity increases

**Recommendation**:
- Push aggregation to database layer:
  ```sql
  SELECT
    COUNT(*) as total_registrations,
    COUNT(checked_in_at) as checked_in_count,
    u.department,
    COUNT(u.id) as dept_count
  FROM registrations r
  LEFT JOIN users u ON r.user_id = u.id
  WHERE r.event_id = $1
  GROUP BY u.department
  ```
- Separate query for survey response rate using COUNT subquery
- Leverage PostgreSQL query planner for optimized execution
- Reduce result set to aggregated values only

#### S-3: Missing Index Definitions
**Location**: Section 4.1 Data Model

**Issue**: The schema defines primary keys and foreign keys but no secondary indexes for frequent query patterns. Critical missing indexes:

1. `registrations.event_id` - queried in every capacity check, dashboard load, reminder batch
2. `registrations.status` - filtered in multiple queries
3. `events.start_datetime` - used in reminder batch date range query
4. `events.category + status` - composite index for filtered event listing
5. `survey_responses.event_id` - queried for response rate calculation

**Impact**:
- Sequential scans on `registrations` table for event lookups (O(n) cost as registrations grow)
- Dashboard stats query will perform full table scan to count registrations by event
- Reminder batch date range query scans all events
- Query performance degrades linearly with data volume

**Recommendation**:
- Add indexes:
  ```sql
  CREATE INDEX idx_registrations_event_id ON registrations(event_id);
  CREATE INDEX idx_registrations_event_status ON registrations(event_id, status);
  CREATE INDEX idx_events_start_datetime ON events(start_datetime);
  CREATE INDEX idx_events_category_status ON events(category, status);
  CREATE INDEX idx_survey_event_id ON survey_responses(event_id);
  ```
- Include columns for covering indexes where beneficial
- Monitor index usage and adjust based on query patterns

#### S-4: Synchronous Email Sending Blocks Registration Flow
**Location**: Section 6.1 - `createRegistration` function line 202

**Issue**: The registration confirmation email is sent synchronously within the registration request handler:
```javascript
await notificationService.sendRegistrationConfirmation(userId, eventId);
```

**Impact**:
- External SES API call (50-200ms latency) blocks HTTP response
- If SES is slow or unavailable, registration requests time out
- User perceives slow registration experience even though core operation (DB write) succeeded
- During high load (500 concurrent users), email sending becomes bottleneck

**Recommendation**:
- Implement asynchronous notification via SQS:
  1. Write registration to database
  2. Enqueue notification job to SQS
  3. Return success response immediately
  4. Background worker processes queue and sends email
- Add retry logic and dead-letter queue for failed notifications
- Decouple user-facing latency from external service dependencies
- Expected improvement: registration latency reduced from ~250ms to <50ms

#### S-5: Undefined Caching Strategy Despite Redis Availability
**Location**: Section 2 (Redis available), Section 3-6 (no cache usage)

**Issue**: Redis ElastiCache is provisioned but no caching layer is designed. High-value caching opportunities are missed:

1. Event details (frequently accessed, low change rate)
2. User profiles (accessed on every registration, dashboard view)
3. Dashboard statistics (expensive aggregation, tolerable staleness)
4. Category/status filter results

**Impact**:
- Repeated database queries for identical data
- Dashboard stats recalculated on every page load despite rarely changing
- Database becomes bottleneck under read-heavy load
- Cannot achieve sub-100ms latency targets without caching

**Recommendation**:
- Implement caching strategy:
  - **Event details**: Cache with TTL 5 minutes, invalidate on update
  - **Dashboard stats**: Cache with TTL 1 minute for recently ended events
  - **User profiles**: Cache with TTL 1 hour, invalidate on profile update
  - **Event listings**: Cache filtered results with TTL 30 seconds
- Use cache-aside pattern with Redis
- Define cache key naming convention: `event:{id}`, `dashboard:{event_id}:stats`
- Implement cache warming for high-traffic events

### Moderate Issues

#### M-1: Missing Connection Pooling Configuration
**Location**: Section 2 (PostgreSQL usage), no connection pool specification

**Issue**: No mention of database connection pooling strategy, pool size, timeout configuration, or connection lifecycle management.

**Impact**:
- Under 500 concurrent users, unmanaged connections can exhaust database connection limits
- Connection establishment overhead (50-100ms) on every request if pooling not configured
- Risk of connection leaks if not properly released

**Recommendation**:
- Configure connection pool (e.g., `pg-pool` for Node.js):
  - Pool size: 10-20 connections per app instance
  - Max wait time: 5 seconds
  - Idle timeout: 30 seconds
- Set database-level connection limit based on instance size
- Monitor connection utilization and adjust pool size
- Implement connection health checks and recycling

#### M-2: No Query Timeout Configuration
**Location**: Section 6.2, 6.3 - Database queries without timeout specification

**Issue**: Database queries have no explicit timeout limits. Long-running queries (e.g., dashboard aggregation on large datasets) can block indefinitely.

**Impact**:
- Slow queries hold database connections and reduce available pool capacity
- No protection against runaway queries from application bugs
- User requests timeout at application server level without query cancellation
- Database resources remain allocated to abandoned queries

**Recommendation**:
- Set statement timeout at connection level: `SET statement_timeout = '30s'`
- Configure per-endpoint timeouts based on expected query duration
- Implement query monitoring and alerting for slow queries (>1s)
- Add circuit breaker pattern for database operations

#### M-3: Unbounded Data Growth Without Lifecycle Management
**Location**: Section 7.4 - Explicit mention of no data retention policy

**Issue**: Historical data (registrations, survey responses) accumulates indefinitely without archival, partitioning, or purging strategy.

**Impact**:
- Database size grows linearly: 10,000 registrations/month = 120,000/year = 1.2M in 10 years
- Query performance degrades as indexes grow larger
- Backup and restore times increase proportionally
- Storage costs scale without bound

**Recommendation**:
- Define data lifecycle policy:
  - Active events: full performance optimization
  - Events >1 year old: move to archive table or partition
  - Events >5 years old: export to cold storage (S3) and purge
- Implement table partitioning by event date (PostgreSQL 10+ declarative partitioning)
- Use archive tables with relaxed indexing for historical reporting
- Schedule periodic archival batch jobs

#### M-4: Missing Observability for Performance-Critical Operations
**Location**: Section 6.5 Logging (basic logging only, no performance metrics)

**Issue**: While error logging is defined, no performance monitoring, metrics collection, or alerting is specified for:
- Database query execution time
- API endpoint latency (p50, p95, p99)
- Cache hit/miss rates
- Queue processing lag
- External service (SES) latency

**Impact**:
- No visibility into performance degradation before user impact
- Cannot diagnose bottlenecks in production
- No data-driven capacity planning
- Unable to validate SLA compliance

**Recommendation**:
- Implement performance instrumentation:
  - Database query duration logging with slow query alerts (>500ms)
  - API endpoint response time tracking with percentile metrics
  - Cache hit rate monitoring
  - SQS queue depth and processing lag monitoring
- Use CloudWatch or similar APM solution
- Set up alerts for SLA violations and anomalies
- Create performance dashboard for operations team

### Minor Improvements

#### I-1: Positive Aspect - JSONB for Flexible Survey Data
**Location**: Section 4.1 - `survey_responses.responses` JSONB column

**Strength**: Using PostgreSQL JSONB for survey responses is appropriate for schema flexibility. This allows different events to have different survey questions without schema migrations.

**Consideration**: Ensure GIN index on JSONB column if filtering or searching within survey content is needed.

#### I-2: Optimization Opportunity - Denormalize Registration Count
**Location**: Section 4.1 - `events` table schema

**Suggestion**: Add `registered_count` column to `events` table (denormalized from registrations count). Benefits:
- Eliminates COUNT query for capacity checks
- Enables atomic capacity enforcement (as mentioned in C-2)
- Improves event listing performance (showing available spots without JOIN)

Trade-off: Requires maintaining count consistency (use database triggers or application-level transaction).

## Summary

This design document identifies a system with **3 critical**, **5 significant**, and **4 moderate** performance issues requiring attention before production deployment.

**Most Critical Priorities**:
1. Fix race condition in registration capacity enforcement (C-2) - directly affects data integrity
2. Add pagination to event listing API (C-1) - prevents unbounded growth
3. Define performance SLAs (C-3) - enables measurable quality goals

**High-Impact Optimizations**:
1. Refactor N+1 queries in reminder batch (S-1) and implement async email (S-4)
2. Add database indexes for primary query patterns (S-3)
3. Design and implement caching strategy (S-5)

The architecture foundation is sound (3-tier separation, appropriate technology choices), but requires performance-focused refinement in data access patterns, concurrency control, and resource management before scaling to production load.
