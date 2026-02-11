# Structural Quality Design Review: E-Learning Content Delivery Platform

## System Structure Summary

- **Architecture**: Multi-service backend with API Gateway fronting three services (CourseService, UserService, VideoService)
- **Key Components**: CourseService integrates course management, assignments, progress tracking, and certificates; UserService handles auth/authz; VideoService manages video upload/encoding/streaming
- **Technology Stack**: Spring Boot + PostgreSQL (metadata) + MongoDB (logs/history) + Redis (cache) + S3/CloudFront (storage/CDN) + RabbitMQ (async) + Elasticsearch (search)
- **Integration Points**: CourseService directly accesses PostgreSQL, MongoDB, Redis; UserService issues JWT; VideoService interacts with S3/CloudFront
- **Data Model**: Relational schema in PostgreSQL (courses, enrollments, assignments, users) + MongoDB collections (learning_progress, activity_logs)

## Critical Issues

### 1. Massive Single Responsibility Principle Violation in CourseService

**Issue**: CourseService integrates course management, assignment management, progress tracking, and certificate issuance into a single service (Section 3).

**Impact**:
- **Unmaintainable monolith**: A single service with 4+ distinct responsibilities will grow uncontrollably
- **Coupling explosion**: Changes to progress tracking logic require deployment of entire CourseService, affecting course management, assignments, and certificates
- **Team paralysis**: Multiple teams cannot work independently on assignments vs. progress tracking without merge conflicts and coordination overhead
- **Testing nightmare**: Integration tests must cover all permutations of course/assignment/progress/certificate scenarios

**Recommendation**:
Decompose into separate services:
- `CourseService`: Course CRUD, publishing, archiving
- `AssignmentService`: Assignment creation, submission, grading
- `ProgressService`: Progress tracking, completion state
- `CertificateService`: Certificate generation and issuance

Each service should have its own database schema and be independently deployable.

**References**: Section 3 (主要コンポーネント > CourseService)

---

### 2. Direct Multi-Database Access from CourseService Violates Layering

**Issue**: CourseService directly accesses PostgreSQL, MongoDB, and Redis (Section 3), creating tight coupling to three different data stores.

**Impact**:
- **Change amplification**: Schema changes in PostgreSQL, MongoDB, or Redis require changes to CourseService code
- **Testing complexity**: Unit testing CourseService requires mocking/stubbing three different database clients
- **Database migration risk**: Cannot switch from MongoDB to a different log store without rewriting CourseService logic
- **Transaction boundary ambiguity**: No clear transaction management strategy across PostgreSQL + MongoDB

**Recommendation**:
Introduce Repository pattern with clear abstraction:
- `CourseRepository` (PostgreSQL)
- `ProgressRepository` (MongoDB)
- `CacheRepository` (Redis)

Each repository should encapsulate database-specific logic and expose domain-level interfaces (e.g., `CourseRepository.findById(courseId)` instead of exposing JPA `EntityManager`).

**References**: Section 3 (主要コンポーネント > CourseService), Section 3 (データフロー Step 3)

---

### 3. Missing Dependency Injection Design and Testability Strategy

**Issue**: Section 6 states "モックは使用せず、実際のDBに接続してテスト" (no mocks, use real DB for testing), indicating absence of DI and mockability design.

**Impact**:
- **Slow test execution**: Integration tests requiring full database setup take 10-100x longer than unit tests
- **Test flakiness**: Tests dependent on database state (e.g., concurrent test runs) introduce race conditions
- **Impossible unit testing**: Cannot test business logic in isolation (e.g., course enrollment validation, progress calculation) without spinning up PostgreSQL + MongoDB
- **Development feedback loop**: Developers cannot run fast local tests, slowing down TDD/BDD workflows

**Recommendation**:
- Apply Dependency Injection consistently (Spring already supports this, but design doesn't specify DI-friendly interfaces)
- Define repository interfaces (`CourseRepository`, `UserRepository`) that can be mocked
- Separate business logic from data access: `CourseService` should depend on `CourseRepository` interface, not on `JpaRepository<Course, Long>` directly
- Implement unit tests with mocks for business logic + integration tests for database interactions
- Example: `CourseService(CourseRepository courseRepo, UserRepository userRepo)` constructor injection

**References**: Section 6 (テスト方針)

---

### 4. No Error Classification, Propagation, or Recovery Strategy

**Issue**: Section 6 states "Controllerレイヤーで例外をキャッチし、適切なHTTPステータスコードを返却" with "詳細な分類体系は未定義" (no detailed classification system).

**Impact**:
- **Client confusion**: Clients cannot distinguish between retryable errors (503 service unavailable) vs. non-retryable errors (400 bad request)
- **Inconsistent error responses**: Without error taxonomy, different controllers will return inconsistent error codes for the same domain exception
- **No retry logic guidance**: Clients don't know whether to retry 500 errors (some 500s are transient, others are permanent bugs)
- **Debugging hell**: Generic error messages like `"error": "ERROR_CODE"` (Section 5) without correlation IDs make production debugging impossible

**Recommendation**:
Define error classification system:
1. **Domain exceptions**:
   - `CourseNotFoundException` → 404
   - `EnrollmentClosedException` → 409
   - `InvalidAssignmentSubmissionException` → 400
2. **Retryable vs. non-retryable**:
   - Retryable: `DatabaseUnavailableException` (503), `ExternalServiceTimeoutException` (503)
   - Non-retryable: validation errors (400), authorization errors (403)
3. **Error response format**:
   ```json
   {
     "error_code": "ENROLLMENT_CLOSED",
     "message": "Cannot enroll in course after start date",
     "retryable": false,
     "correlation_id": "req-12345"
   }
   ```
4. **Exception hierarchy**: Create base `ApplicationException` with `ErrorCode` enum and `isRetryable()` method

**References**: Section 5 (リクエスト/レスポンス形式), Section 6 (エラーハンドリング方針)

---

### 5. No API Versioning Strategy

**Issue**: API endpoints (Section 5) have no versioning scheme (no `/v1/courses`, `/v2/courses`).

**Impact**:
- **Breaking changes**: Adding required fields to `POST /courses` request breaks existing clients
- **Backward compatibility risk**: Cannot evolve API schema (e.g., changing `progress` from `INT` to `{ current: INT, total: INT }`) without breaking clients
- **Forced client upgrades**: All clients must upgrade simultaneously when API changes, blocking incremental rollout

**Recommendation**:
- Add URL-based versioning: `/v1/courses/{id}`, `/v2/courses/{id}`
- Define versioning policy:
  - Minor changes (adding optional fields): backward compatible, same version
  - Major changes (removing fields, changing types): new version
- Document migration path: How long will v1 be supported after v2 launch?
- Consider header-based versioning (`Accept: application/vnd.elearning.v1+json`) if URL versioning clutters endpoints

**References**: Section 5 (エンドポイント一覧)

---

### 6. Data Model Consistency Risk: Dual Storage of Progress Data

**Issue**: Progress data appears in both PostgreSQL (`course_enrollments.progress INT`) and MongoDB (`learning_progress` collection with `watched_seconds`, `completed` flag).

**Impact**:
- **Eventual inconsistency**: If PostgreSQL update succeeds but MongoDB write fails (or vice versa), progress data diverges
- **Source of truth ambiguity**: Which is authoritative: `course_enrollments.progress` or `learning_progress.completed`?
- **Query complexity**: Clients must join data from PostgreSQL and MongoDB to get full progress picture
- **Synchronization overhead**: Requires distributed transaction or saga pattern to keep both stores consistent

**Recommendation**:
- **Option A (Preferred)**: Store all progress data in MongoDB only, use PostgreSQL for referential integrity (`course_enrollments` just tracks enrollment status, not progress)
  - `course_enrollments.progress` removed
  - Progress queries go to MongoDB `learning_progress` collection
- **Option B**: Store aggregate progress in PostgreSQL, detailed progress in MongoDB
  - PostgreSQL: `course_enrollments.overall_progress_percent INT`
  - MongoDB: Detailed video-level progress (`watched_seconds`, `last_position`)
  - Clear data contract: PostgreSQL is source of truth for "course completion %", MongoDB is audit trail
- **Option C**: Implement event-driven consistency
  - Publish `ProgressUpdated` event to RabbitMQ
  - Separate workers update PostgreSQL and MongoDB
  - Accept eventual consistency with reconciliation jobs

**References**: Section 4 (PostgreSQL スキーマ > course_enrollments), Section 4 (MongoDB コレクション > learning_progress)

---

## Significant Issues

### 7. Circular Dependency Risk: CourseService → UserService Authentication

**Issue**: CourseService calls UserService for authentication (Section 3, データフロー Step 2), but authentication should be handled at API Gateway or authentication middleware layer, not within service-to-service calls.

**Impact**:
- **Tight coupling**: CourseService cannot function without UserService, making independent deployment/testing difficult
- **Latency overhead**: Every CourseService request incurs additional UserService call latency (50-100ms)
- **Circular dependency risk**: If UserService needs to call CourseService (e.g., to check if user is instructor), a circular dependency emerges

**Recommendation**:
- Move authentication to API Gateway or Spring Security filter chain
- JWT validation should happen at the gateway, not in service layer
- CourseService should receive pre-validated user context (user ID, roles) from gateway via HTTP headers or JWT claims
- Example: API Gateway validates JWT, passes `X-User-Id: 12345, X-User-Roles: INSTRUCTOR` headers to CourseService

**References**: Section 3 (データフロー Step 2)

---

### 8. Missing Data Contract Validation Between Services

**Issue**: No schema validation or data contract definition between CourseService, UserService, and VideoService.

**Impact**:
- **Runtime failures**: If UserService changes JWT claim structure (e.g., `role` → `roles`), CourseService breaks at runtime
- **Integration test gaps**: Without contract tests, incompatible changes ship to production
- **Documentation drift**: API documentation becomes stale, developers don't know which fields are required

**Recommendation**:
- Define OpenAPI 3.0 specs for all service APIs
- Implement contract testing with Pact or Spring Cloud Contract
- Validate request/response schemas at service boundaries (e.g., JSON Schema validation)
- Example: UserService publishes `user-api-contract.yaml`, CourseService depends on it

**References**: Section 5 (API設計)

---

### 9. No Distributed Tracing or Context Propagation Design

**Issue**: Section 6 mentions "ロギング方針" but no distributed tracing or context propagation strategy.

**Impact**:
- **Debugging failures**: When a request touches CourseService → UserService → VideoService, cannot correlate logs across services
- **Performance bottleneck identification**: Cannot pinpoint whether latency is in database query, UserService call, or S3 upload
- **Incident response paralysis**: Production issues require manual log grepping across multiple services

**Recommendation**:
- Integrate Spring Cloud Sleuth or OpenTelemetry
- Propagate trace ID and span ID across all service calls (HTTP headers: `X-B3-TraceId`, `X-B3-SpanId`)
- Centralize logs in Elasticsearch with trace ID for correlation
- Example trace:
  ```
  TraceID: abc123
    Span: CourseService.enroll (200ms)
      Span: UserService.authenticate (50ms)
      Span: PostgreSQL.insert (30ms)
  ```

**References**: Section 6 (ロギング方針)

---

### 10. Hardcoded Status Field Without Enum or State Machine

**Issue**: `courses.status VARCHAR(50)` (Section 4) has no defined enum values or state transition rules.

**Impact**:
- **Inconsistent data**: Developers may insert `"ACTIVE"`, `"active"`, `"published"`, `"PUBLISHED"` inconsistently
- **Invalid transitions**: No enforcement of valid state transitions (e.g., cannot go from `"ARCHIVED"` back to `"DRAFT"`)
- **Query errors**: `WHERE status = 'ACTIVE'` may miss lowercase `"active"` entries

**Recommendation**:
- Define enum at database level: `CREATE TYPE course_status AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');`
- OR use CHECK constraint: `CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED'))`
- Document valid state transitions:
  ```
  DRAFT → PUBLISHED → ARCHIVED
  DRAFT → ARCHIVED (direct archival of unpublished courses)
  ```
- Enforce transitions in application logic (e.g., `CourseStateMachine` class)

**References**: Section 4 (PostgreSQL スキーマ > courses テーブル)

---

## Moderate Issues

### 11. JWT Storage in LocalStorage Exposes XSS Risk

**Issue**: Section 5 states "トークンはローカルストレージに保存" (tokens stored in local storage).

**Note**: This is flagged as a structural issue because it affects API design decisions (e.g., token refresh strategy, session management architecture).

**Impact**:
- **XSS vulnerability**: If XSS attack succeeds, attacker can steal JWT from `localStorage`
- **No secure storage**: Unlike HttpOnly cookies, `localStorage` is accessible to JavaScript

**Recommendation**:
- Store JWT in HttpOnly, Secure, SameSite cookies instead of `localStorage`
- Use CSRF tokens to protect cookie-based authentication
- Design refresh token rotation strategy (Section 5 notes "リフレッシュトークンは未実装")

**References**: Section 5 (認証・認可方式)

---

### 12. Missing Configuration Management Strategy for Multiple Environments

**Issue**: Section 6 states "環境変数で設定を管理（開発環境と本番環境の差分は環境変数で切り替え）" but no details on configuration validation or secret management.

**Impact**:
- **Misconfiguration risk**: Missing required environment variable causes runtime crash (e.g., `DATABASE_URL` not set)
- **Secret leakage**: Hardcoded secrets in environment variables (e.g., `AWS_SECRET_ACCESS_KEY`) risk leakage in logs
- **Environment drift**: No enforcement that dev, staging, prod environments have consistent configuration structure

**Recommendation**:
- Use Spring Boot's `@ConfigurationProperties` with validation (`@NotNull`, `@Min`, etc.)
- Integrate AWS Secrets Manager or HashiCorp Vault for secret management
- Define configuration schema in `application.yml`:
  ```yaml
  app:
    database:
      url: ${DATABASE_URL}
      max-connections: ${DB_MAX_CONNECTIONS:20}
  ```
- Fail fast on startup if required configs are missing

**References**: Section 6 (デプロイメント方針)

---

### 13. Missing Schema Evolution Strategy for MongoDB

**Issue**: MongoDB collections (`learning_progress`, `activity_logs`) have no schema versioning or migration strategy.

**Impact**:
- **Schema drift**: Adding new fields (e.g., `learning_progress.quiz_scores`) without versioning makes old documents incompatible
- **Query failures**: Code expecting `learning_progress.completed` fails if old documents lack this field
- **No rollback plan**: Cannot roll back code changes if new schema is incompatible with old data

**Recommendation**:
- Add schema version field: `{ "schema_version": 1, "user_id": "12345", ... }`
- Implement schema migration logic:
  ```java
  if (document.getInteger("schema_version") == 1) {
    // Migrate to schema v2
  }
  ```
- Use MongoDB schema validation rules:
  ```javascript
  db.createCollection("learning_progress", {
    validator: {
      $jsonSchema: {
        required: ["user_id", "course_id", "schema_version"]
      }
    }
  })
  ```

**References**: Section 4 (MongoDB コレクション)

---

### 14. No Pagination or Filtering Strategy for List APIs

**Issue**: No pagination or filtering design for list endpoints (e.g., `GET /courses` is not specified but implied).

**Impact**:
- **Performance degradation**: Fetching all courses without pagination causes memory/network issues at scale
- **Client-side complexity**: Clients must implement their own filtering/pagination logic
- **Inconsistent implementation**: Different developers implement pagination differently across services

**Recommendation**:
- Define standard pagination pattern:
  ```
  GET /courses?page=1&size=20&sort=created_at:desc
  Response:
  {
    "data": [...],
    "pagination": {
      "current_page": 1,
      "total_pages": 10,
      "total_items": 200
    }
  }
  ```
- Use Spring Data's `Pageable` for consistency
- Support filtering: `GET /courses?status=PUBLISHED&instructor_id=123`

**References**: Section 5 (エンドポイント一覧)

---

### 15. Insufficient Foreign Key Constraints

**Issue**: `courses.instructor_id`, `course_enrollments.course_id`, `assignment_submissions.assignment_id` have no explicit foreign key constraints defined.

**Impact**:
- **Orphaned records**: Deleting a course doesn't cascade to `course_enrollments`, leaving orphaned enrollments
- **Referential integrity violations**: Can insert `course_enrollments` with non-existent `course_id`
- **Data cleanup complexity**: Must manually write scripts to clean up orphaned records

**Recommendation**:
Add foreign key constraints with cascading rules:
```sql
ALTER TABLE course_enrollments
ADD CONSTRAINT fk_course
FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE;

ALTER TABLE assignments
ADD CONSTRAINT fk_course
FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE;
```

Choose appropriate cascade behavior:
- `ON DELETE CASCADE`: For child records that should be deleted (e.g., enrollments when course is deleted)
- `ON DELETE RESTRICT`: For records that should prevent deletion (e.g., cannot delete user if they have submissions)

**References**: Section 4 (PostgreSQL スキーマ)

---

## Minor Improvements

### 16. Structured Logging Enhancement

**Issue**: Section 6 mentions "Spring Bootの標準ロギングフレームワーク（Logback）を使用" but no structured logging format (JSON logs).

**Recommendation**:
- Use JSON log format for machine-parseable logs:
  ```json
  {
    "timestamp": "2024-01-15T10:30:00Z",
    "level": "INFO",
    "logger": "CourseService",
    "message": "Course created",
    "course_id": 123,
    "instructor_id": 456
  }
  ```
- Integrate Logstash JSON encoder or SLF4J structured logging
- Benefits: Easier Elasticsearch querying, better log aggregation

**References**: Section 6 (ロギング方針)

---

### 17. Consider CQRS Pattern for Progress Tracking

**Observation**: `learning_progress` in MongoDB is write-heavy (frequent updates) but `course_enrollments.progress` in PostgreSQL is read-heavy (dashboards, reports).

**Recommendation**:
- Evaluate CQRS (Command Query Responsibility Segregation):
  - **Command side**: Write to MongoDB for detailed progress tracking
  - **Query side**: Materialize aggregated progress in PostgreSQL for fast reads
- Use RabbitMQ to propagate events from command side to query side
- Benefits: Optimized read/write performance, clear separation of concerns

**References**: Section 4 (PostgreSQL スキーマ > course_enrollments), Section 4 (MongoDB コレクション > learning_progress)

---

### 18. Positive Aspects

- **Clear separation of concerns at service level**: CourseService, UserService, VideoService have distinct responsibilities (though CourseService needs further decomposition)
- **Appropriate technology choices**: PostgreSQL for transactional data, MongoDB for logs, Redis for caching, S3 for blob storage
- **Security basics covered**: HTTPS, PreparedStatement for SQL injection prevention, JWT-based authentication
- **Infrastructure scalability**: Auto-scaling, read replicas, Blue-Green deployment strategy

**References**: Section 2 (技術スタック), Section 3 (全体構成), Section 7 (セキュリティ要件, 可用性・スケーラビリティ)

---

## Summary

This design document presents a reasonable starting architecture but suffers from critical structural flaws that will hinder long-term maintainability:

**Top 3 Priorities**:
1. **Decompose CourseService** (Issue #1): Split into CourseService, AssignmentService, ProgressService, CertificateService
2. **Introduce Repository abstraction** (Issue #2): Decouple CourseService from direct database access
3. **Define error classification system** (Issue #4): Enable consistent, retryable error handling

Addressing these critical issues will significantly improve changeability, testability, and operational reliability of the system.
