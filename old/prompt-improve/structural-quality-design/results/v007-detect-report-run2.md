# Structural Quality Review: E-Learning Content Delivery Platform

**Reviewer**: structural-quality-design-reviewer (v007-variant-detect-report, M1b Deep Mode)
**Document**: test-document-round-007.md
**Review Date**: 2026-02-11

---

## Phase 1: Comprehensive Detection

**All detected issues (unfiltered):**

- CourseService violates Single Responsibility Principle - handles courses, assignments, progress tracking, and certificate issuance
- CourseService directly accesses three different datastores (PostgreSQL, MongoDB, Redis) - violates layering and data access patterns
- Circular dependency risk: CourseService calls UserService for authentication, but enrollment/progress likely requires reverse calls
- Course and Assignment entities mixed in same service - should be separate bounded contexts
- No repository abstraction layer - services directly access databases
- No domain model separation from database entities - changeability risk when schema evolves
- No DTO layer defined - API likely exposes database entities directly
- Global state management strategy undefined - unclear how session, cache, and distributed state are coordinated
- No dependency injection design specified - unclear how services locate each other
- Progress tracking split across PostgreSQL (course_enrollments.progress INT) and MongoDB (learning_progress) - data inconsistency risk
- learning_progress uses string IDs while PostgreSQL uses BIGINT - type inconsistency across datastores
- No versioning strategy for REST APIs - breaking changes will affect all clients
- Error response format too generic - single ERROR_CODE field insufficient for client handling
- Error classification taxonomy undefined - no distinction between business errors, validation errors, infrastructure errors
- No retry strategy defined - unclear which errors are retryable
- Logging policy lacks structured logging - JSON format not specified for machine parsing
- No distributed tracing context propagation design - debugging across services will be difficult
- Test strategy relies entirely on full-stack integration tests with real databases - slow feedback, hard to isolate failures
- No unit test strategy - business logic not isolated from infrastructure
- No mock/stub interfaces defined - testability severely limited
- No interface segregation - services likely have fat interfaces with all operations
- Foreign key constraints not defined in schema - referential integrity at risk
- Schema evolution strategy undefined - no migration plan for backward compatibility
- JWT stored in localStorage - XSS vulnerability (security issue but affects API design)
- No refresh token mechanism - user experience degradation when token expires
- status column in courses uses VARCHAR without CHECK constraint or ENUM - invalid states possible
- role column in users lacks constraints - typos could bypass authorization
- progress field is INT without bounds - could store negative or > 100 values
- No cascade delete strategy defined - orphaned records risk when courses/users deleted
- No optimistic locking / version fields - concurrent update conflicts unhandled
- Video encoding is synchronous in VideoService - blocks API thread, should be async with RabbitMQ
- No plugin/strategy pattern for multiple video formats (HLS/DASH) - hardcoded branching likely
- Configuration management mentions "environment variables" but no centralized config service design
- No feature flag design - cannot enable/disable features per tenant or gradually
- No multi-tenancy design - single database for all organizations limits isolation
- API Gateway mentioned but its responsibilities undefined - might become god object
- No API rate limiting / throttling design
- No pagination strategy defined for list endpoints
- No partial response / field filtering design for large resources
- No bulk operation design - must submit assignments one-by-one
- Certificate issuance coupled to CourseService - should be separate service
- Discussion forum feature mentioned but no data model or API design provided
- LMS integration mentioned but no integration layer architecture specified
- No event sourcing for audit trail - cannot reconstruct historical states
- No CQRS separation - read-heavy and write-heavy operations use same models
- MongoDB used for logs and learning progress - unclear if write-ahead log pattern applied
- Elasticsearch sync strategy from PostgreSQL undefined - data staleness risk
- No compensating transaction design for distributed operations (enrollment + payment)
- No saga pattern for long-running workflows (course completion → certificate issuance)
- No idempotency design for POST operations - duplicate submissions possible
- No correlation ID design for tracing requests across services
- Redis used for both session and API response caching - namespace collision risk
- Cache invalidation strategy undefined - stale data risk
- No circuit breaker pattern mentioned - cascading failures likely
- No bulkhead isolation between course read and video streaming traffic
- No database connection pool configuration specified
- No prepared statement reuse strategy - performance issue
- assignment_submissions.feedback is TEXT without length limit - storage bloat risk
- courses.description is TEXT without limit - same issue
- No JSON schema validation for MongoDB documents - schema drift over time
- No index design documented - query performance at risk
- No database partitioning strategy for time-series data (learning_progress, activity_logs)
- No archival strategy for old data - database growth unbounded
- No soft delete vs hard delete policy - compliance risk (GDPR right to be forgotten)
- No data retention policy defined
- UserService issues JWT but unclear if it validates tokens for other services or each service validates independently - no centralized auth gateway pattern
- RBAC mentioned but permission granularity undefined - cannot express "educator can grade only their own courses"
- No attribute-based access control (ABAC) - cannot handle complex policies
- No API design for partial updates (PATCH) - must send entire resource for updates
- No ETag / If-Match support for conditional requests
- No OPTIONS support documented - CORS preflight handling unclear
- No HATEOAS / hypermedia controls - clients must hardcode all URLs
- No GraphQL consideration mentioned despite variable data access patterns
- courses.instructor_id references users but no foreign key constraint
- course_enrollments references courses and users but no constraints
- assignments.course_id references courses but no constraint
- assignment_submissions.assignment_id and user_id lack constraints
- No composite unique constraint on course_enrollments(course_id, user_id) - duplicate enrollments possible
- No check constraint on assignment_submissions.score <= assignments.max_score
- watched_seconds > total_seconds validation undefined
- No timezone handling strategy - TIMESTAMP without timezone risks
- created_at, enrolled_at, submitted_at use different default strategies - inconsistent
- No updated_at / modified_at tracking - cannot detect stale reads
- No created_by / modified_by audit fields
- FFmpeg mentioned but no abstraction layer - vendor lock-in to specific tool
- Spring Data JPA used but no specification of fetch strategies (lazy/eager) - N+1 query risk
- No mentioned use of Criteria API or QueryDSL - dynamic query construction unclear
- No DAO vs Repository pattern clarification
- No transaction boundary definition - unclear where @Transactional applied
- No transaction isolation level specified - dirty read / phantom read risk
- No distributed transaction coordination (2PC/Saga) - eventual consistency handling unclear
- Logback configuration details missing - no log rotation, retention policy
- No centralized logging aggregation (e.g., ELK stack) mentioned
- No alerting / monitoring design (Prometheus, Grafana)
- No health check endpoint design
- No graceful shutdown handling
- Blue-Green deployment mentioned but no smoke test / health check before traffic switch
- No database migration tool specified (Flyway, Liquibase)
- No backward compatibility testing strategy for API changes
- No canary deployment option
- No rollback strategy if deployment fails
- Environment variable management tool not specified - secrets leakage risk
- No secret rotation strategy
- No API documentation generation strategy (OpenAPI/Swagger)
- No client SDK generation plan
- No API changelog / release notes process
- courses table lacks soft delete flag (is_deleted, deleted_at)
- No composite indexes documented for common query patterns
- No database view definitions for complex joins
- No materialized view strategy for expensive aggregations
- RabbitMQ mentioned for async processing but no queue design, message schema, DLQ strategy
- No message ordering guarantee discussion
- No exactly-once delivery semantics handling
- No poison message handling
- S3 and CloudFront mentioned but no presigned URL generation strategy
- No CDN cache invalidation design
- No origin protection (S3 bucket not publicly accessible)
- No video thumbnail generation design
- No adaptive bitrate streaming (ABR) design for HLS/DASH
- No DRM / content protection design
- No subtitle / closed caption support
- No video progress bookmark sync across devices
- Discussion forum data model completely missing
- Forum search integration with Elasticsearch undefined
- No notification design for forum replies
- No spam / abuse moderation design
- Certificate template design missing
- Certificate verification API missing
- Certificate revocation mechanism undefined
- LMS integration: no SSO design (SAML, OAuth)
- LMS integration: no grade sync design
- LMS integration: no user provisioning (SCIM)
- No webhook design for external system integration
- No batch job design for scheduled tasks (certificate generation, report generation)
- No job scheduling framework mentioned (Quartz, Spring Batch)
- No incremental data load strategy for analytics
- No data export API for compliance (GDPR data portability)
- No user deletion workflow (cascade to enrollments, submissions, logs)
- No course archival workflow
- No instructor transfer workflow (change ownership of courses)
- No merge user account workflow
- No impersonation design for admin troubleshooting
- No audit log for sensitive operations (grade changes, user deletion)
- No rate limiting per user/role
- No quota design (storage, API calls per tenant)
- No billing integration design
- No payment gateway integration design
- No invoice generation design
- No usage metering design for cost allocation
- Email/notification service not mentioned
- Email template design missing
- Email delivery tracking missing
- SMS/push notification design missing
- No i18n/l10n design (internationalization)
- No timezone conversion strategy for global users
- No content localization strategy
- No accessibility compliance design (WCAG)
- No mobile app API considerations (bandwidth, battery)
- No offline mode design
- No conflict resolution for offline edits
- No real-time collaboration design (concurrent editing)
- No WebSocket design for live updates
- No server-sent events for progress notifications
- courses.status values undefined - no enumeration
- users.role values undefined - no enumeration
- assignment_submissions allows NULL score - ambiguous (not graded vs zero score)
- progress INT in course_enrollments overlaps with learning_progress in MongoDB - master source unclear
- No polymorphic design for different assignment types (quiz, essay, coding)
- No assignment versioning (if instructor changes due date / max score after submissions)
- No late submission policy enforcement design
- No plagiarism detection integration
- No peer review workflow design
- No rubric / grading criteria data model
- No learning path / prerequisite course design
- No course recommendation engine design
- No analytics dashboard data model
- No A/B testing framework design
- No user feedback / rating system design
- No course review moderation design
- No instructor verification workflow
- No course approval workflow before publication
- No content copyright verification workflow
- No video transcoding job queue prioritization
- No video storage tiering (hot/cold storage)
- No backup and disaster recovery design
- No point-in-time recovery design
- No cross-region replication design
- No failover automation design
- No data anonymization for test environments
- No synthetic data generation strategy
- No performance testing strategy (load, stress, endurance)
- No capacity planning model
- No cost optimization strategy
- No technical debt tracking approach

---

## Phase 2: Priority-Based Reporting

### Critical Issues

#### 1. CourseService Violates Single Responsibility Principle (God Service Anti-Pattern)

**Issue Description:**
CourseService handles courses, assignments, progress tracking, and certificate issuance. Additionally, it directly accesses three different datastores (PostgreSQL, MongoDB, Redis). This is a textbook violation of the Single Responsibility Principle and creates a god object that will become unmaintainable as the system grows.

**Impact Analysis:**
- **Maintainability**: Any change to assignment logic requires modifying the same class that handles course management, increasing the risk of regression bugs.
- **Changeability**: Cannot independently deploy or scale assignment functionality vs. course management.
- **Testability**: Testing course creation requires setting up MongoDB and Redis even though courses are primarily stored in PostgreSQL.
- **Team Parallelization**: Multiple developers cannot work on assignments and courses simultaneously without merge conflicts.

**Improvement Suggestions:**
1. Split CourseService into distinct bounded contexts:
   - `CourseManagementService` (course CRUD, publishing)
   - `AssignmentService` (assignment CRUD, grading)
   - `ProgressTrackingService` (enrollment, completion tracking)
   - `CertificateService` (certificate generation, verification)
2. Introduce a repository abstraction layer so services don't directly access multiple datastores.
3. Use domain events (e.g., `CourseCompletedEvent`) to trigger certificate issuance asynchronously instead of tight coupling.

**Document References:**
- Section 3 "主要コンポーネント" → "CourseService: コース管理、課題管理、進捗トラッキング、証明書発行を統合したサービス"
- Section 3 "データフロー" Step 3 → "CourseServiceがデータベースに直接クエリを実行"

---

#### 2. No Repository Abstraction Layer / No Domain Model Separation from Database Entities

**Issue Description:**
The design specifies that services directly access databases without a repository abstraction layer. Furthermore, no separation is defined between domain models and database entities, meaning the database schema leaks into business logic.

**Impact Analysis:**
- **Changeability**: Changing the database schema (e.g., renaming a column, migrating from PostgreSQL to a different store) requires changing service logic throughout the codebase.
- **Testability**: Unit testing business logic requires a real database connection, making tests slow and brittle.
- **Violation of Dependency Inversion Principle**: High-level business logic depends on low-level database access details.
- **Implementation Leakage**: API clients might receive database-specific types (e.g., Java entities with JPA annotations), breaking encapsulation.

**Improvement Suggestions:**
1. Introduce a repository interface per aggregate root:
   ```java
   public interface CourseRepository {
       Course findById(CourseId id);
       void save(Course course);
   }
   ```
2. Separate domain models (e.g., `Course` in `domain` package) from persistence entities (e.g., `CourseEntity` in `infrastructure.persistence` package).
3. Use mapper/converter classes to translate between domain models and persistence entities.
4. Services should only depend on repository interfaces, allowing in-memory implementations for unit tests.

**Document References:**
- Section 3 "データフロー" → "CourseServiceがデータベースに直接クエリを実行"
- Section 4 "データモデル" → Only database schemas are defined; no mention of domain models or repositories.

---

#### 3. Progress Tracking Data Inconsistency Risk Across PostgreSQL and MongoDB

**Issue Description:**
Progress tracking is split between two datastores:
- PostgreSQL `course_enrollments.progress` (INT field)
- MongoDB `learning_progress` collection (detailed video watch tracking)

The design does not specify which is the source of truth, how they are synchronized, or how conflicts are resolved. Additionally, MongoDB uses string IDs (`"user_id": "12345"`) while PostgreSQL uses `BIGINT`, creating type inconsistency.

**Impact Analysis:**
- **Data Integrity**: `course_enrollments.progress` and MongoDB's `learning_progress` can diverge, showing different completion percentages to users.
- **Changeability**: Future features (e.g., "resume watching from last position") cannot reliably determine the master source.
- **Eventual Consistency Bugs**: If MongoDB updates succeed but PostgreSQL updates fail (or vice versa), the system enters an inconsistent state with no compensating transaction design.
- **Query Complexity**: Reporting on progress requires joining across two datastores, which is operationally expensive.

**Improvement Suggestions:**
1. **Option A (Single Source of Truth)**: Store fine-grained video progress only in MongoDB. Compute course-level progress on-demand by aggregating MongoDB data. Remove `course_enrollments.progress`.
2. **Option B (CQRS)**: Treat MongoDB as the write model (detailed event log). Use a background process to denormalize into PostgreSQL's `course_enrollments.progress` as a read model. Accept eventual consistency but design for it explicitly with timestamps and version vectors.
3. **Fix Type Inconsistency**: Use `BIGINT` (or UUID if using distributed ID generation) consistently across both datastores.
4. Define a clear synchronization strategy and document the master source in the design.

**Document References:**
- Section 4 PostgreSQL schema → `course_enrollments.progress INT DEFAULT 0`
- Section 4 MongoDB schema → `learning_progress` collection with `"user_id": "12345"` (string)

---

#### 4. No API Versioning Strategy Defined

**Issue Description:**
The API design section lists endpoints but does not define a versioning strategy (e.g., URI versioning, header-based versioning, content negotiation). This means breaking changes will affect all clients simultaneously, causing outages.

**Impact Analysis:**
- **Changeability**: Cannot introduce breaking changes (e.g., renaming fields, changing response structure) without coordinating all clients to upgrade simultaneously.
- **Backward Compatibility**: No path to deprecate old endpoints gradually.
- **Integration Risk**: External LMS integrations mentioned in Section 1 will break if API contracts change.

**Improvement Suggestions:**
1. Adopt URI versioning (e.g., `/v1/courses`, `/v2/courses`) as the most explicit and widely supported approach.
2. Define a deprecation policy: support N-1 versions for at least 6 months.
3. Document version upgrade guides in API documentation.
4. Consider using content negotiation (`Accept: application/vnd.elearning.v1+json`) for more granular control if needed.

**Document References:**
- Section 5 "API設計" → No versioning mentioned in endpoint list or design rationale.

---

#### 5. No Error Classification Taxonomy or Retry Strategy

**Issue Description:**
The error response format is generic (`{"error": "ERROR_CODE", "message": "..."}`), and Section 6 states "例外の種類ごとに異なるメッセージを返す（詳細な分類体系は未定義）". There is no taxonomy distinguishing:
- Business validation errors (retryable after fixing input)
- Transient infrastructure errors (retryable)
- Permanent errors (non-retryable)

**Impact Analysis:**
- **Client Resilience**: Clients cannot implement intelligent retry logic. They may retry non-retryable errors (wasting resources) or fail to retry transient errors (causing poor UX).
- **Observability**: Cannot aggregate errors by category for monitoring/alerting.
- **Changeability**: Adding new error types later requires changing all clients.

**Improvement Suggestions:**
1. Define an error taxonomy with error code ranges:
   - `4xxx` - Client errors (validation, authorization) → non-retryable
   - `5xxx` - Server errors (database timeout, RabbitMQ unavailable) → retryable
2. Add a `retryable: boolean` field to the error response.
3. Include a `correlation_id` field for distributed tracing.
4. Example improved format:
   ```json
   {
       "error_code": "ASSIGNMENT_PAST_DUE",
       "message": "Cannot submit assignment after due date",
       "retryable": false,
       "correlation_id": "abc-123-xyz",
       "timestamp": "2024-01-15T10:30:00Z"
   }
   ```

**Document References:**
- Section 5 "リクエスト/レスポンス形式" → Generic error format shown
- Section 6 "エラーハンドリング方針" → "詳細な分類体系は未定義"

---

#### 6. No Dependency Injection Design / Service Discovery Mechanism Undefined

**Issue Description:**
The design does not specify how services locate each other. Section 3 mentions "CourseServiceがUserServiceに認証リクエストを送信" but does not explain whether this is via:
- Direct HTTP calls with hardcoded URLs
- Service discovery (e.g., Eureka, Consul)
- API Gateway routing
- Dependency injection framework

**Impact Analysis:**
- **Testability**: Cannot inject mock implementations of UserService when testing CourseService.
- **Changeability**: Changing service endpoints requires redeploying all dependent services.
- **Circular Dependency Risk**: CourseService → UserService authentication calls might lead to reverse calls (UserService fetching user's enrolled courses), creating a circular dependency that cannot be resolved without an abstraction layer.

**Improvement Suggestions:**
1. Explicitly design dependency injection using Spring's `@Autowired` or constructor injection.
2. Define service interfaces (e.g., `AuthenticationService` interface implemented by `UserServiceClient`).
3. Use a service registry (AWS Cloud Map, Eureka) for dynamic endpoint resolution.
4. Document the dependency graph to detect and break circular dependencies (use domain events for reverse communication).

**Document References:**
- Section 3 "データフロー" Step 2 → "CourseServiceがUserServiceに認証リクエストを送信"
- Section 6 "テスト方針" → "モックは使用せず、実際のDBに接続してテスト" (indicates no DI design for testing)

---

### Significant Issues

#### 7. Test Strategy Relies Entirely on Full-Stack Integration Tests (No Unit Tests)

**Issue Description:**
Section 6 states "統合テストで全体動作を確認", "DBを含むフルスタックテストを実施", "モックは使用せず、実際のDBに接続してテスト". No unit test strategy is defined.

**Impact Analysis:**
- **Slow Feedback**: Full-stack tests take minutes to run, slowing down development iteration.
- **Failure Isolation**: When a test fails, it's unclear whether the bug is in business logic, database access, or infrastructure configuration.
- **Testability Violation**: The architecture is not designed for testability (no DI, no repository interfaces, no domain model separation).
- **Maintenance Burden**: Integration tests are brittle and require extensive setup/teardown.

**Improvement Suggestions:**
1. Introduce a test pyramid strategy:
   - **Unit tests** (70%): Test domain logic in isolation using in-memory repository implementations.
   - **Integration tests** (20%): Test repository implementations against real databases using Testcontainers.
   - **E2E tests** (10%): Test critical user journeys through the API Gateway.
2. Design services to accept repository interfaces via constructor injection, enabling mock injection for unit tests.
3. Use Spring Boot's `@MockBean` for integration tests when testing service-to-service communication.

**Document References:**
- Section 6 "テスト方針" → Entire section describes only integration tests

---

#### 8. Missing Referential Integrity Constraints (Foreign Keys)

**Issue Description:**
The database schema defines relationships between tables (e.g., `courses.instructor_id → users.id`, `course_enrollments.course_id → courses.id`) but does not include `FOREIGN KEY` constraints.

**Impact Analysis:**
- **Data Integrity**: Orphaned records can exist (e.g., `course_enrollments` referencing deleted courses).
- **Cascade Deletion Undefined**: No strategy for what happens when a course or user is deleted.
- **Query Performance**: Lack of foreign keys means database optimizer cannot leverage constraint information.

**Improvement Suggestions:**
1. Add foreign key constraints with explicit cascade rules:
   ```sql
   ALTER TABLE courses
   ADD CONSTRAINT fk_instructor
   FOREIGN KEY (instructor_id) REFERENCES users(id)
   ON DELETE RESTRICT;

   ALTER TABLE course_enrollments
   ADD CONSTRAINT fk_course
   FOREIGN KEY (course_id) REFERENCES courses(id)
   ON DELETE CASCADE;
   ```
2. Define a cascade deletion policy document:
   - When a course is deleted → archive enrollments, submissions (don't cascade delete)
   - When a user is deleted → anonymize their data (GDPR compliance)

**Document References:**
- Section 4 "データモデル" → All table definitions lack `FOREIGN KEY` constraints

---

#### 9. No Duplicate Enrollment Prevention (Missing Unique Constraint)

**Issue Description:**
The `course_enrollments` table does not have a unique constraint on `(course_id, user_id)`, allowing a user to enroll in the same course multiple times.

**Impact Analysis:**
- **Data Integrity**: Duplicate enrollments can cause incorrect progress calculations, duplicate notifications, and billing errors.
- **Business Logic Complexity**: Application code must handle de-duplication, which should be enforced at the database level.

**Improvement Suggestions:**
1. Add a unique constraint:
   ```sql
   ALTER TABLE course_enrollments
   ADD CONSTRAINT unique_enrollment
   UNIQUE (course_id, user_id);
   ```
2. Handle the constraint violation gracefully in application code (return 409 Conflict with a clear error message).

**Document References:**
- Section 4 `course_enrollments` table definition → No unique constraint defined

---

#### 10. VARCHAR Enum Fields Lack CHECK Constraints (courses.status, users.role)

**Issue Description:**
`courses.status` and `users.role` are defined as `VARCHAR(50)` without CHECK constraints or ENUMs, allowing invalid values like "PBLISHED" (typo) or "super_admin" (unauthorized role).

**Impact Analysis:**
- **Data Integrity**: Invalid states can bypass business logic validation.
- **Authorization Bypass**: A typo in `users.role` could grant unintended permissions.
- **Query Complexity**: Application code must validate all possible values, duplicating validation logic.

**Improvement Suggestions:**
1. Use PostgreSQL ENUM types:
   ```sql
   CREATE TYPE course_status AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');
   ALTER TABLE courses ALTER COLUMN status TYPE course_status USING status::course_status;

   CREATE TYPE user_role AS ENUM ('LEARNER', 'EDUCATOR', 'ADMIN');
   ALTER TABLE users ALTER COLUMN role TYPE user_role USING role::user_role;
   ```
2. Alternatively, add CHECK constraints if ENUMs are not preferred:
   ```sql
   ALTER TABLE courses
   ADD CONSTRAINT valid_status
   CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED'));
   ```

**Document References:**
- Section 4 `courses` table → `status VARCHAR(50)`
- Section 4 `users` table → `role VARCHAR(50) NOT NULL`

---

#### 11. progress Field Lacks Bounds Validation

**Issue Description:**
`course_enrollments.progress` is defined as `INT DEFAULT 0` without a CHECK constraint to ensure `0 <= progress <= 100`.

**Impact Analysis:**
- **Data Integrity**: Negative progress or values > 100 could be stored, causing UI rendering bugs.
- **Business Logic Errors**: Progress calculations might overflow or underflow without validation.

**Improvement Suggestions:**
1. Add a CHECK constraint:
   ```sql
   ALTER TABLE course_enrollments
   ADD CONSTRAINT valid_progress
   CHECK (progress >= 0 AND progress <= 100);
   ```
2. Consider using a SMALLINT instead of INT to save space.

**Document References:**
- Section 4 `course_enrollments` table → `progress INT DEFAULT 0`

---

#### 12. No Transaction Boundary or Isolation Level Specified

**Issue Description:**
The design mentions Spring Data JPA but does not specify where `@Transactional` boundaries are applied or what isolation level is used. This creates risk for dirty reads, phantom reads, and lost updates.

**Impact Analysis:**
- **Concurrency Bugs**: Two educators grading the same assignment simultaneously could overwrite each other's scores (lost update).
- **Inconsistent Reads**: Fetching course progress might read partially committed enrollment records.
- **Performance**: Default isolation level (REPEATABLE READ in PostgreSQL) might cause unnecessary locking.

**Improvement Suggestions:**
1. Document transaction boundaries in the design:
   - Service methods that modify multiple entities should be annotated with `@Transactional`.
   - Read-only methods should use `@Transactional(readOnly = true)` for optimization.
2. Specify isolation levels per use case:
   - `READ_COMMITTED` for most operations
   - `SERIALIZABLE` for critical operations like grading (prevent lost updates)
3. Add optimistic locking with version fields:
   ```sql
   ALTER TABLE assignment_submissions ADD COLUMN version INT DEFAULT 0;
   ```

**Document References:**
- Section 2 "主要ライブラリ" → Spring Data JPA mentioned without transaction design
- Section 6 "実装方針" → No transaction strategy defined

---

#### 13. No Distributed Transaction Coordination for Cross-Service Operations

**Issue Description:**
The design mentions multiple services (CourseService, UserService, VideoService) but does not specify how distributed transactions are handled. For example, enrolling in a paid course might require:
1. Deducting payment (PaymentService)
2. Creating enrollment record (CourseService)
3. Granting access permissions (UserService)

If step 2 fails after step 1 succeeds, the user is charged but not enrolled.

**Impact Analysis:**
- **Data Consistency**: Partial failures leave the system in an inconsistent state.
- **Compensating Transactions Undefined**: No rollback mechanism for distributed operations.
- **Eventual Consistency Not Designed For**: No strategy for detecting and resolving inconsistencies.

**Improvement Suggestions:**
1. Adopt the **Saga pattern** for distributed transactions:
   - **Orchestration**: A saga coordinator service manages the workflow and compensating transactions.
   - **Choreography**: Services publish domain events (e.g., `EnrollmentRequested`, `PaymentCompleted`) and react to them.
2. Example orchestration-based saga for enrollment:
   ```
   EnrollmentSaga:
   1. Reserve payment → if fail, abort
   2. Create enrollment → if fail, refund payment
   3. Grant access → if fail, delete enrollment + refund payment
   ```
3. Use RabbitMQ (already in the tech stack) for event-driven choreography.
4. Implement idempotency keys for all state-changing operations to handle retries safely.

**Document References:**
- Section 3 "主要コンポーネント" → Multiple services defined without distributed transaction design
- Section 6 "実装方針" → No mention of saga, 2PC, or compensating transactions

---

#### 14. No Idempotency Design for POST Operations

**Issue Description:**
The API design does not specify idempotency keys or mechanisms to prevent duplicate submissions. For example, if a user clicks "Submit Assignment" twice due to network latency, two submissions might be created.

**Impact Analysis:**
- **Data Integrity**: Duplicate enrollments, assignments, or submissions.
- **Business Logic Errors**: Grading logic might assume one submission per user per assignment.
- **User Experience**: Users see confusing duplicate records.

**Improvement Suggestions:**
1. Require an `Idempotency-Key` header for all POST/PUT requests:
   ```
   POST /assignments/{id}/submit
   Headers:
     Idempotency-Key: client-generated-uuid
   ```
2. Store processed idempotency keys in Redis with a TTL (e.g., 24 hours):
   ```
   Key: idempotency:submit_assignment:client-uuid
   Value: {response_body}
   TTL: 86400
   ```
3. On duplicate key, return the cached response with 200 OK (not an error).

**Document References:**
- Section 5 "API設計" → No mention of idempotency in any endpoint

---

### Moderate Issues

#### 15. No Logging Design for Structured Logging or Log Levels Per Environment

**Issue Description:**
Section 6 mentions using Logback with INFO level in production and DEBUG in development, but does not specify structured logging format (e.g., JSON), correlation ID propagation, or sensitive data redaction.

**Impact Analysis:**
- **Observability**: Plain text logs are hard to parse and query in centralized log aggregation systems.
- **Compliance**: Logs might inadvertently contain PII (passwords, emails) without redaction policies.
- **Debugging**: No correlation ID makes it impossible to trace a single request across services.

**Improvement Suggestions:**
1. Use JSON structured logging with Logstash encoder:
   ```json
   {
       "timestamp": "2024-01-15T10:30:00Z",
       "level": "INFO",
       "service": "course-service",
       "correlation_id": "abc-123",
       "message": "Course created",
       "course_id": 456,
       "user_id": 789
   }
   ```
2. Inject correlation IDs from API Gateway and propagate through all service calls.
3. Define a sensitive data redaction policy (e.g., mask email addresses in logs).
4. Configure different log levels per package (e.g., DEBUG for `com.example.course` but INFO for `org.springframework`).

**Document References:**
- Section 6 "ロギング方針" → "Spring Bootの標準ロギングフレームワーク（Logback）を使用、ログレベルはINFO（本番環境）、DEBUG（開発環境）"

---

#### 16. No Distributed Tracing Context Propagation Design

**Issue Description:**
The design mentions multiple services but does not specify distributed tracing (e.g., OpenTelemetry, AWS X-Ray, Jaeger). This makes debugging cross-service requests nearly impossible.

**Impact Analysis:**
- **Debugging Difficulty**: When a course enrollment fails, cannot trace whether the issue is in CourseService, UserService, or the database.
- **Performance Analysis**: Cannot identify which service in the call chain is slow.
- **Incident Response**: Mean time to resolution (MTTR) increases significantly without tracing.

**Improvement Suggestions:**
1. Integrate OpenTelemetry with automatic instrumentation for Spring Boot.
2. Propagate trace context via HTTP headers (`traceparent`, `tracestate`).
3. Export traces to a backend (e.g., AWS X-Ray, Jaeger, or DataDog).
4. Ensure RabbitMQ messages include trace context for async operations.

**Document References:**
- Section 3 "全体構成" → Multiple services shown without tracing design
- Section 6 "ロギング方針" → No mention of distributed tracing

---

#### 17. No Configuration Management Service (Secrets Leakage Risk)

**Issue Description:**
Section 6 mentions managing configuration via environment variables, but does not specify a secrets management service (e.g., AWS Secrets Manager, HashiCorp Vault). This creates risk of hardcoding secrets in environment variables visible in Docker inspect or process listings.

**Impact Analysis:**
- **Security Risk**: Database passwords, API keys, and JWT signing keys might be exposed in container orchestration configs or logged accidentally.
- **Changeability**: Rotating secrets requires redeploying all services.
- **Compliance**: Fails audit requirements for secret rotation and access logging.

**Improvement Suggestions:**
1. Use AWS Secrets Manager or Parameter Store for secret storage.
2. Fetch secrets at runtime, not via environment variables:
   ```java
   @Value("${aws.secretsmanager.secret-name}")
   private String secretName;

   // Fetch secret from AWS SDK
   ```
3. Implement automatic secret rotation with zero-downtime deployment.
4. Audit all secret access via CloudTrail.

**Document References:**
- Section 6 "デプロイメント方針" → "環境変数で設定を管理"

---

#### 18. No Schema Evolution or Migration Strategy Defined

**Issue Description:**
The database schema is defined, but there is no mention of a migration tool (e.g., Flyway, Liquibase) or a backward-compatible schema evolution strategy.

**Impact Analysis:**
- **Changeability**: Adding a new column or index requires manual SQL execution in production, risking downtime or errors.
- **Rollback Risk**: No versioned migration history makes it difficult to roll back schema changes.
- **Team Coordination**: Multiple developers might create conflicting schema changes.

**Improvement Suggestions:**
1. Adopt Flyway for versioned database migrations:
   ```
   V001__create_courses_table.sql
   V002__add_status_column.sql
   V003__create_assignments_table.sql
   ```
2. Define a backward compatibility policy:
   - Always add columns as nullable first, then backfill, then make non-nullable.
   - Never rename columns; instead, add a new column and deprecate the old one.
3. Run migrations as part of the deployment pipeline before deploying new application code.

**Document References:**
- Section 4 "データモデル" → Schema defined without migration strategy
- Section 6 "デプロイメント方針" → No mention of database migrations

---

#### 19. No Circuit Breaker or Bulkhead Pattern for Cascading Failure Prevention

**Issue Description:**
The design does not mention resilience patterns like circuit breakers or bulkheads. If VideoService becomes slow (e.g., S3 latency spikes), CourseService might wait indefinitely, exhausting thread pools and causing cascading failures.

**Impact Analysis:**
- **Availability**: A failure in one service can bring down the entire system.
- **Resource Exhaustion**: Thread pools blocked on slow calls cannot serve other requests.
- **Debugging Difficulty**: Cascading failures create confusing error logs.

**Improvement Suggestions:**
1. Integrate Resilience4j (Spring Boot compatible) for circuit breakers:
   ```java
   @CircuitBreaker(name = "videoService", fallbackMethod = "getVideoFallback")
   public Video getVideo(Long id) { ... }
   ```
2. Configure timeouts aggressively (e.g., 2 seconds for inter-service calls).
3. Use bulkhead pattern to isolate thread pools for video streaming vs. course management.
4. Implement graceful degradation (e.g., show "Video temporarily unavailable" instead of crashing).

**Document References:**
- Section 3 "全体構成" → Multiple services without resilience patterns
- Section 7 "可用性・スケーラビリティ" → 99.9% availability goal but no resilience design

---

#### 20. No Pagination or Partial Response Design for List Endpoints

**Issue Description:**
The API design lists endpoints like `GET /courses` but does not specify pagination parameters or partial response mechanisms (e.g., field filtering).

**Impact Analysis:**
- **Performance**: Fetching all courses in a single request is inefficient for large datasets.
- **Client Resource Usage**: Mobile clients waste bandwidth downloading unnecessary data.
- **Changeability**: Adding pagination later is a breaking API change.

**Improvement Suggestions:**
1. Add pagination to all list endpoints:
   ```
   GET /courses?page=1&size=20
   Response:
   {
       "data": [...],
       "page": 1,
       "size": 20,
       "total_pages": 10,
       "total_elements": 200
   }
   ```
2. Support field filtering for partial responses:
   ```
   GET /courses?fields=id,title,instructor_id
   ```
3. Use cursor-based pagination for real-time data (e.g., activity logs) to avoid offset/limit issues.

**Document References:**
- Section 5 "API設計" → No pagination mentioned in endpoint list

---

#### 21. assignment_submissions.score NULL Ambiguity (Not Graded vs. Zero Score)

**Issue Description:**
The `assignment_submissions.score` column allows NULL, but the design does not clarify whether NULL means "not yet graded" or "zero score".

**Impact Analysis:**
- **Business Logic Ambiguity**: Queries like "show all graded assignments" must handle NULL explicitly.
- **Data Integrity**: Application code might misinterpret NULL as 0 or vice versa.

**Improvement Suggestions:**
1. Add a separate `graded_at` timestamp column:
   ```sql
   ALTER TABLE assignment_submissions ADD COLUMN graded_at TIMESTAMP NULL;
   ```
   - NULL `graded_at` → not graded
   - Non-NULL `graded_at` → graded (score can be 0)
2. Add a CHECK constraint: `(score IS NULL AND graded_at IS NULL) OR (score IS NOT NULL AND graded_at IS NOT NULL)`.

**Document References:**
- Section 4 `assignment_submissions` table → `score INT` (nullable)

---

#### 22. No Audit Fields (created_by, updated_at, updated_by)

**Issue Description:**
The schema includes `created_at` but lacks `updated_at`, `updated_by`, and `created_by` fields. This makes it impossible to audit who modified records or when.

**Impact Analysis:**
- **Compliance**: GDPR and SOC2 audits require change tracking.
- **Debugging**: Cannot determine who changed a grade or when a course was last updated.
- **Dispute Resolution**: No evidence for resolving disputes about grade changes.

**Improvement Suggestions:**
1. Add audit columns to all tables:
   ```sql
   ALTER TABLE courses
   ADD COLUMN created_by BIGINT,
   ADD COLUMN updated_at TIMESTAMP,
   ADD COLUMN updated_by BIGINT;
   ```
2. Use database triggers or application-level interceptors to populate these fields automatically.
3. Consider a separate `audit_log` table for sensitive operations (grade changes, user deletion).

**Document References:**
- Section 4 "データモデル" → Only `created_at` defined, no `updated_at` or audit fields

---

#### 23. No Index Design Documented (Query Performance Risk)

**Issue Description:**
The schema defines tables but does not specify indexes beyond implicit primary keys. Common queries (e.g., "find all courses by instructor", "find enrollments by user") will require full table scans.

**Impact Analysis:**
- **Performance**: Queries degrade from milliseconds to seconds as data grows.
- **Scalability**: Cannot scale read replicas effectively if queries are inefficient.
- **Cost**: Unnecessary compute resources spent on table scans.

**Improvement Suggestions:**
1. Add indexes for common query patterns:
   ```sql
   CREATE INDEX idx_courses_instructor ON courses(instructor_id);
   CREATE INDEX idx_enrollments_user ON course_enrollments(user_id);
   CREATE INDEX idx_enrollments_course ON course_enrollments(course_id);
   CREATE INDEX idx_submissions_assignment ON assignment_submissions(assignment_id);
   CREATE INDEX idx_submissions_user ON assignment_submissions(user_id);
   ```
2. Add composite indexes for multi-column queries:
   ```sql
   CREATE INDEX idx_enrollments_user_course ON course_enrollments(user_id, course_id);
   ```
3. Use `EXPLAIN ANALYZE` to validate index usage.

**Document References:**
- Section 4 "データモデル" → No indexes defined

---

#### 24. No Data Retention or Archival Strategy (Unbounded Database Growth)

**Issue Description:**
The design does not specify how old data (e.g., 5-year-old activity logs, archived courses) is handled. Databases will grow indefinitely, degrading performance and increasing costs.

**Impact Analysis:**
- **Performance**: Queries slow down as tables grow to billions of rows.
- **Cost**: Storage costs increase linearly with data growth.
- **Compliance**: GDPR requires data minimization; storing data indefinitely violates this.

**Improvement Suggestions:**
1. Define a data retention policy:
   - `activity_logs`: Keep 1 year, then archive to S3 Glacier.
   - `learning_progress`: Keep for active courses + 2 years post-completion.
   - Archived courses: Soft delete (mark `is_deleted = true`) after 5 years of inactivity.
2. Implement time-based partitioning for `activity_logs` and `learning_progress`:
   ```sql
   CREATE TABLE activity_logs_2024_01 PARTITION OF activity_logs
   FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
   ```
3. Schedule automated archival jobs using Spring Batch or AWS Lambda.

**Document References:**
- Section 4 MongoDB collections → `activity_logs` with no retention policy
- Section 7 "非機能要件" → No mention of data retention

---

### Minor Issues and Positive Aspects

#### 25. Positive: Appropriate Use of PostgreSQL for Relational Data and MongoDB for Logs

The design correctly chooses PostgreSQL for structured, relational data (courses, users, enrollments) and MongoDB for schema-flexible, append-only logs (learning progress, activity logs). This is a sound architectural decision aligned with polyglot persistence best practices.

#### 26. Positive: Redis for Session and Cache Management

Using Redis for session storage and API response caching is appropriate. However, namespace collision risk exists if both use the same Redis instance without key prefixes. Consider prefixing keys (e.g., `session:user123`, `cache:course456`).

#### 27. Minor: TIMESTAMP Fields Lack Timezone Specification

All `TIMESTAMP` fields use the default (no timezone), which can cause bugs for global users. Recommend using `TIMESTAMPTZ` in PostgreSQL to store UTC timestamps and convert to user timezones in the application layer.

**Document References:**
- Section 4 "データモデル" → All timestamps use `TIMESTAMP` instead of `TIMESTAMPTZ`

---

#### 28. Minor: TEXT Fields Without Length Limits (courses.description, assignment_submissions.feedback)

`TEXT` fields have no length limits, allowing unbounded storage. While PostgreSQL handles this efficiently, consider adding application-level validation (e.g., max 10,000 characters) to prevent abuse.

**Document References:**
- Section 4 `courses.description TEXT`
- Section 4 `assignment_submissions.feedback TEXT`

---

#### 29. Minor: No Mention of Health Check Endpoints for Deployment Automation

Blue-Green deployment is mentioned, but no health check endpoint design (e.g., `/health`, `/readiness`) is specified to verify service health before traffic switch.

**Improvement Suggestions:**
1. Implement Spring Boot Actuator health endpoints:
   ```
   GET /actuator/health
   Response: {"status": "UP", "details": {"db": "UP", "redis": "UP"}}
   ```
2. Configure ALB/ECS to use health checks before marking containers as ready.

**Document References:**
- Section 6 "デプロイメント方針" → Blue-Green deployment without health check design

---

#### 30. Minor: RabbitMQ Mentioned but No Queue Design or DLQ Strategy

RabbitMQ is listed in the tech stack for async processing, but no queue names, message schemas, or Dead Letter Queue (DLQ) strategy is defined.

**Improvement Suggestions:**
1. Define queues and exchanges:
   ```
   Exchange: course.events (topic)
   Queue: video.encoding.queue
   Binding: course.video.uploaded → video.encoding.queue
   ```
2. Implement DLQ for poison messages:
   ```
   Queue: video.encoding.dlq (messages that fail 3 retries)
   ```
3. Document message schemas using JSON Schema or Avro.

**Document References:**
- Section 2 "技術スタック" → RabbitMQ mentioned without design details

---

## Summary

This design document exhibits **critical structural issues** that will lead to unmaintainable architecture if not addressed:

1. **God Service Anti-Pattern**: CourseService violates SRP by handling 4+ responsibilities.
2. **No Abstraction Layers**: Direct database access without repositories violates DIP and kills testability.
3. **Data Consistency Risks**: Progress tracking split across datastores without synchronization strategy.
4. **No API Versioning**: Breaking changes will cause outages for all clients.
5. **No Error Taxonomy**: Clients cannot implement intelligent retry logic.
6. **No Dependency Injection Design**: Services are tightly coupled, making testing and changes difficult.

**Significant issues** include lack of unit tests, missing database constraints (foreign keys, unique constraints), no transaction design, and no distributed transaction coordination.

**Moderate issues** cover observability gaps (no structured logging, no distributed tracing), configuration management risks (secrets in environment variables), and resilience pattern omissions (no circuit breakers).

**Recommended next steps**:
1. Refactor CourseService into bounded contexts (CourseManagementService, AssignmentService, ProgressTrackingService, CertificateService).
2. Introduce repository interfaces and separate domain models from database entities.
3. Define API versioning strategy and error taxonomy.
4. Add database constraints (foreign keys, unique constraints, CHECK constraints).
5. Design unit test strategy with dependency injection.

Addressing these structural issues now will prevent technical debt accumulation and ensure long-term maintainability.
