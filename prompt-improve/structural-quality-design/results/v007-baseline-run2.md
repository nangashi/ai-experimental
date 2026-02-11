# Structural Quality Review: E-Learning Content Delivery Platform

**Reviewer:** structural-quality-design-reviewer (v007-baseline)
**Document:** test-document-round-007.md
**Review Date:** 2026-02-11

---

## Structure Analysis Summary

- **Architectural Pattern**: Microservices-style separation with CourseService, UserService, and VideoService, though CourseService acts as a monolithic component handling multiple domains
- **Data Layer**: Polyglot persistence (PostgreSQL for metadata, MongoDB for logs/history, Redis for caching) with direct database access from services
- **Integration Points**: REST API Gateway, inter-service synchronous calls (CourseService → UserService), message queue (RabbitMQ) for async processing
- **External Dependencies**: AWS S3/CloudFront for content delivery, Elasticsearch for search
- **Technology Stack**: Java 17, Spring Boot 3.1, containerized deployment on AWS ECS

---

## Critical Issues

### 1. Single Responsibility Principle Violation: CourseService as God Object

**Issue**: CourseService combines course management, assignment management, progress tracking, and certificate issuance into a single service. This violates the Single Responsibility Principle at the service level, creating a monolithic component within a supposedly distributed architecture.

**Impact**:
- **Changeability**: Any change in assignment logic, progress tracking algorithms, or certificate generation requires modifying and redeploying the entire CourseService
- **Team Scalability**: Multiple teams cannot work independently on different business domains
- **Testing Complexity**: Testing one feature requires understanding and potentially mocking the entire service's state
- **Deployment Risk**: Bug fixes in one domain affect all other domains

**Referenced Sections**: Section 3 (CourseService description), Section 5 (Course API endpoints mixing multiple concerns)

**Improvement**:
```
Decompose CourseService into bounded contexts:
- CourseManagementService: Course CRUD, publication, archiving
- AssignmentService: Assignment lifecycle, submissions, grading
- ProgressTrackingService: View history, completion state calculation
- CertificationService: Certificate generation and validation

Define clear service boundaries with dedicated databases per service (or schemas) to prevent coupling through shared data structures.
```

### 2. Lack of Dependency Inversion: Direct Database Access from Business Logic

**Issue**: All services directly access databases (PostgreSQL, MongoDB, Redis) without repository abstractions or data access layer interfaces. The document states "CourseServiceがデータベースに直接クエリを実行" (CourseService executes queries directly to database).

**Impact**:
- **Testability**: Unit testing requires actual database instances; mocking is explicitly rejected ("モックは使用せず、実際のDBに接続してテスト")
- **Technology Lock-in**: Switching from PostgreSQL to another RDBMS or MongoDB to another document store requires changes throughout the codebase
- **Test Performance**: Full database integration tests are slow, discouraging comprehensive test coverage
- **Changeability**: Cannot evolve data storage strategy (e.g., add caching layers, implement CQRS) without changing business logic

**Referenced Sections**: Section 3 (Data flow description), Section 6 (Testing policy)

**Improvement**:
```java
// Introduce repository interfaces to invert dependencies
public interface CourseRepository {
    Course findById(Long id);
    void save(Course course);
}

// Spring Data JPA implementation
@Repository
public class JpaCourseRepository implements CourseRepository {
    // JPA-specific implementation
}

// Service depends on abstraction
@Service
public class CourseManagementService {
    private final CourseRepository courseRepository;

    public CourseManagementService(CourseRepository repository) {
        this.courseRepository = repository;
    }
}

// Enable mocking in tests
@Test
void testCourseCreation() {
    CourseRepository mockRepo = mock(CourseRepository.class);
    CourseManagementService service = new CourseManagementService(mockRepo);
    // Test without database
}
```

### 3. Missing Error Handling Strategy and Domain Exception Design

**Issue**: The document mentions "例外の種類ごとに異なるメッセージを返す（詳細な分類体系は未定義）" (different messages per exception type, but detailed classification is undefined). No application-level error taxonomy, retryability classification, or error propagation strategy is defined.

**Impact**:
- **Operational Blindness**: Cannot distinguish between client errors (4xx), server errors (5xx), and transient failures requiring retry
- **Inconsistent Error Handling**: Each developer will create ad-hoc exception classes, leading to fragmented error handling
- **Client Integration Complexity**: API consumers cannot programmatically handle errors without parsing human-readable messages
- **Debugging Difficulty**: No standardized error context (trace IDs, operation context) for distributed troubleshooting

**Referenced Sections**: Section 5 (Error response format), Section 6 (Error handling policy)

**Improvement**:
```java
// Define domain exception hierarchy
public abstract class PlatformException extends RuntimeException {
    private final String errorCode;
    private final boolean retryable;

    protected PlatformException(String errorCode, String message, boolean retryable) {
        super(message);
        this.errorCode = errorCode;
        this.retryable = retryable;
    }

    public abstract HttpStatus getHttpStatus();
}

// Domain-specific exceptions
public class CourseNotFoundException extends PlatformException {
    public CourseNotFoundException(Long courseId) {
        super("COURSE_NOT_FOUND", "Course " + courseId + " not found", false);
    }

    @Override
    public HttpStatus getHttpStatus() { return HttpStatus.NOT_FOUND; }
}

public class EnrollmentQuotaExceededException extends PlatformException {
    public EnrollmentQuotaExceededException() {
        super("ENROLLMENT_QUOTA_EXCEEDED", "Course is full", false);
    }

    @Override
    public HttpStatus getHttpStatus() { return HttpStatus.CONFLICT; }
}

public class VideoProcessingException extends PlatformException {
    public VideoProcessingException(String reason) {
        super("VIDEO_PROCESSING_FAILED", reason, true); // retryable
    }

    @Override
    public HttpStatus getHttpStatus() { return HttpStatus.SERVICE_UNAVAILABLE; }
}

// Standardized error response
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(PlatformException.class)
    public ResponseEntity<ErrorResponse> handle(PlatformException ex, HttpServletRequest request) {
        ErrorResponse response = ErrorResponse.builder()
            .errorCode(ex.getErrorCode())
            .message(ex.getMessage())
            .retryable(ex.isRetryable())
            .traceId(MDC.get("traceId"))
            .path(request.getRequestURI())
            .timestamp(Instant.now())
            .build();

        return ResponseEntity.status(ex.getHttpStatus()).body(response);
    }
}
```

### 4. DTO/Domain Model Separation Absent: Implementation Leakage Risk

**Issue**: The document does not distinguish between API contracts (DTOs), domain models, and persistence entities. Spring Data JPA entities are likely exposed directly in REST responses, leaking implementation details.

**Impact**:
- **API Versioning Difficulty**: Database schema changes force API contract changes, breaking backward compatibility
- **Over-fetching**: JPA lazy-loading issues can cause N+1 queries or Jackson serialization exceptions when entities are returned directly
- **Security Risk**: Sensitive entity fields (password_hash, internal IDs) may be accidentally exposed
- **Changeability**: Cannot evolve internal domain model without affecting API consumers

**Referenced Sections**: Section 4 (Data models), Section 5 (API design)

**Improvement**:
```java
// Persistence entity (internal)
@Entity
@Table(name = "courses")
public class CourseEntity {
    @Id @GeneratedValue
    private Long id;
    private String title;
    private String description;
    private Long instructorId;
    private String status;
    private Instant createdAt;
    // JPA-specific annotations
}

// Domain model (business logic layer)
public class Course {
    private final CourseId id;
    private CourseTitle title;
    private InstructorId instructor;
    private CourseStatus status;

    public void publish() {
        if (status != CourseStatus.DRAFT) {
            throw new InvalidCourseStateException("Cannot publish non-draft course");
        }
        this.status = CourseStatus.PUBLISHED;
    }
}

// API DTO (contract)
public record CourseResponse(
    String id,
    String title,
    String description,
    String instructorName, // Denormalized for client convenience
    String status,
    String createdAt
) {}

// Mapping layer
@Component
public class CourseMapper {
    public CourseResponse toResponse(Course domain) {
        // Map domain to API contract
    }

    public Course toDomain(CourseEntity entity) {
        // Map persistence to domain
    }
}
```

---

## Significant Issues

### 5. Circular Dependency Risk: CourseService ↔ UserService Synchronous Coupling

**Issue**: CourseService calls UserService synchronously for authentication ("CourseServiceがUserServiceに認証リクエストを送信"), creating a runtime dependency. If UserService also needs course information (e.g., for "instructor's course list"), a circular dependency emerges.

**Impact**:
- **Deployment Coupling**: Cannot deploy CourseService without UserService being available
- **Cascading Failures**: UserService downtime immediately breaks CourseService
- **Testing Complexity**: Integration tests require both services running
- **Architectural Integrity**: Violates microservices' independence principle

**Referenced Sections**: Section 3 (Data flow, step 2)

**Improvement**:
```
Option 1: Use API Gateway for authentication
- JWT validation happens at gateway layer
- Services receive pre-validated user context (user ID, roles)
- No inter-service auth calls needed

Option 2: Shared authentication library
- Each service validates JWT independently using shared key
- Services remain autonomous

Option 3: Event-driven user context
- UserService publishes user events (user created, role changed)
- CourseService maintains local read model for user info
- Eventual consistency acceptable for authorization checks
```

### 6. State Management Issues: Progress Tracking in Two Data Stores

**Issue**: Progress data exists in both `course_enrollments.progress` (PostgreSQL INT) and `learning_progress` (MongoDB document with detailed watch history). The relationship between these two representations is undefined, risking inconsistency.

**Impact**:
- **Data Inconsistency**: PostgreSQL progress may diverge from MongoDB aggregated progress
- **Unclear Source of Truth**: Which system should be queried for progress reports?
- **Synchronization Complexity**: Updates must maintain consistency across two databases without distributed transaction support
- **Debugging Difficulty**: Discrepancies between systems are hard to detect and reconcile

**Referenced Sections**: Section 4 (course_enrollments table, learning_progress collection)

**Improvement**:
```
Option 1: Single source of truth with derived views
- MongoDB stores detailed event stream (video watch events)
- PostgreSQL progress field is a denormalized cache, updated via async event handler
- Define reconciliation process for drift detection

Option 2: CQRS pattern
- Write model: All progress events go to MongoDB (event store)
- Read model: PostgreSQL progress is a projection, rebuilt from MongoDB on demand
- Implement projection rebuilding mechanism

Option 3: Eliminate redundancy
- Store only detailed progress in MongoDB
- Remove progress column from PostgreSQL
- API queries MongoDB and caches results in Redis
```

### 7. Testability Issues: Rejection of Mocking and Dependency Injection Gaps

**Issue**: The testing policy explicitly rejects mocking ("モックは使用せず、実際のDBに接続してテスト"), and no dependency injection design for testability is mentioned. This forces all tests to be slow integration tests.

**Impact**:
- **Test Suite Performance**: Full database tests take minutes to hours, discouraging TDD and frequent test runs
- **Test Isolation**: Tests interfere with each other through shared database state
- **Coverage Gaps**: Complex business logic cannot be unit tested independently
- **CI/CD Slowdown**: Long test times delay feedback and reduce deployment frequency

**Referenced Sections**: Section 6 (Testing policy)

**Improvement**:
```
Adopt test pyramid strategy:

1. Unit Tests (70% of tests)
   - Test business logic with mocked repositories
   - Fast (milliseconds), isolated, deterministic

   @Test
   void shouldRejectEnrollmentWhenCourseIsFull() {
       CourseRepository mockRepo = mock(CourseRepository.class);
       when(mockRepo.findById(1L)).thenReturn(fullCourse);

       assertThrows(EnrollmentQuotaExceededException.class,
           () -> enrollmentService.enroll(1L, userId));
   }

2. Integration Tests (20% of tests)
   - Test repository implementations with Testcontainers
   - Verify database queries, transactions

   @Testcontainers
   @SpringBootTest
   class CourseRepositoryIntegrationTest {
       @Container
       static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:15");
       // Test actual SQL behavior
   }

3. E2E Tests (10% of tests)
   - Test critical user journeys with full stack
   - Run against staging environment
```

### 8. Configuration Management Strategy Missing

**Issue**: The document mentions "環境変数で設定を管理" (manage config with environment variables) but does not define configuration schema, secret management, or environment-specific variations (dev/staging/prod).

**Impact**:
- **Deployment Errors**: Missing environment variables cause runtime failures
- **Security Risk**: Secrets (DB passwords, API keys) may be hardcoded or logged
- **Environment Drift**: Differences between dev/staging/prod are undocumented and error-prone
- **Rollback Difficulty**: Configuration changes are not versioned with code

**Referenced Sections**: Section 6 (Deployment policy)

**Improvement**:
```java
// Define type-safe configuration classes
@ConfigurationProperties(prefix = "platform")
@Validated
public class PlatformConfig {
    @NotNull
    private DatabaseConfig database;

    @NotNull
    private JwtConfig jwt;

    @NotNull
    private S3Config storage;

    // Nested configurations with validation
}

// Secret management
- Use AWS Secrets Manager or Parameter Store for sensitive values
- Never commit secrets to version control
- Inject secrets as environment variables in ECS task definitions

// Configuration per environment
/config
  /application.yml (defaults)
  /application-dev.yml
  /application-staging.yml
  /application-prod.yml

// Versioning
- Configuration changes go through same PR review as code
- Tag configuration versions with application releases
- Implement feature flags for gradual rollouts
```

---

## Moderate Issues

### 9. API Versioning Strategy Undefined

**Issue**: REST endpoints lack versioning strategy (e.g., `/v1/courses`). Breaking changes will require deprecating old endpoints without a clear migration path.

**Impact**:
- **Backward Compatibility**: Cannot evolve APIs without breaking existing clients
- **Mobile App Problems**: Apps with old versions cannot be forced to update immediately
- **API Sprawl**: Without versioning discipline, endpoints multiply without deprecation

**Referenced Sections**: Section 5 (API design)

**Improvement**:
```
Option 1: URL versioning
- /v1/courses, /v2/courses
- Simple, explicit, cache-friendly

Option 2: Header versioning
- Accept: application/vnd.platform.v1+json
- Cleaner URLs, versioning orthogonal to resource paths

Option 3: Content negotiation
- Use header-based versioning + OpenAPI spec
- Document API versions and deprecation timelines

Define API lifecycle policy:
- New version introduced: v2 released, v1 enters maintenance
- Deprecation notice: 6 months warning via response headers
- Sunset: v1 removed after 12 months
```

### 10. Logging Design Lacks Structured Logging and Context Propagation

**Issue**: Logging policy only defines log levels (INFO/DEBUG) without structured logging format, correlation IDs, or distributed tracing context. In a multi-service architecture, this makes troubleshooting difficult.

**Impact**:
- **Cross-Service Debugging**: Cannot trace a request across CourseService → UserService → VideoService
- **Log Analysis**: Unstructured logs are hard to query and aggregate
- **Performance Troubleshooting**: Cannot correlate slow responses with specific operations

**Referenced Sections**: Section 6 (Logging policy)

**Improvement**:
```java
// Structured logging with MDC
@Component
public class RequestTraceFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain filterChain) {
        String traceId = UUID.randomUUID().toString();
        MDC.put("traceId", traceId);
        MDC.put("userId", extractUserId(request));
        response.setHeader("X-Trace-Id", traceId);

        try {
            filterChain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}

// Structured log format (JSON)
{
    "timestamp": "2024-01-15T10:30:00Z",
    "level": "INFO",
    "traceId": "abc-123",
    "userId": "12345",
    "service": "CourseService",
    "message": "Course published",
    "courseId": "67890",
    "duration_ms": 45
}

// Distributed tracing
- Integrate Spring Cloud Sleuth or OpenTelemetry
- Propagate trace context across services
- Export traces to AWS X-Ray or Jaeger
```

### 11. Missing Extensibility for LMS Integration

**Issue**: The document mentions "既存のLMS（Learning Management System）との統合も想定する" but does not define integration interfaces, adapter patterns, or how to support multiple LMS vendors (Moodle, Canvas, Blackboard).

**Impact**:
- **Hardcoded Integration**: Each LMS integration will likely be hardcoded in CourseService
- **Change Amplification**: Adding new LMS requires modifying core services
- **Testing Difficulty**: Cannot test LMS integrations independently

**Referenced Sections**: Section 1 (Overview)

**Improvement**:
```java
// Define LMS integration abstraction
public interface LmsIntegrationAdapter {
    void syncCourse(Course course);
    void syncEnrollment(Enrollment enrollment);
    void syncGrade(Grade grade);
}

// Vendor-specific implementations
@Component("moodleAdapter")
public class MoodleLmsAdapter implements LmsIntegrationAdapter {
    // Moodle API integration
}

@Component("canvasAdapter")
public class CanvasLmsAdapter implements LmsIntegrationAdapter {
    // Canvas API integration
}

// Configuration-driven selection
@Service
public class LmsIntegrationService {
    private final Map<String, LmsIntegrationAdapter> adapters;

    @Value("${platform.lms.provider}")
    private String lmsProvider;

    public void syncCourse(Course course) {
        LmsIntegrationAdapter adapter = adapters.get(lmsProvider);
        if (adapter != null) {
            adapter.syncCourse(course);
        }
    }
}
```

### 12. Schema Evolution Strategy Undefined for MongoDB

**Issue**: MongoDB collections (`learning_progress`, `activity_logs`) have example schemas but no versioning or migration strategy. As the application evolves, schema changes will break existing data.

**Impact**:
- **Data Migration Risk**: Cannot add fields or change structure without downtime
- **Version Skew**: Old and new documents coexist, requiring defensive code
- **Rollback Difficulty**: Schema changes are hard to revert

**Referenced Sections**: Section 4 (MongoDB collections)

**Improvement**:
```javascript
// Add schema version field
{
    "_schema_version": "2.0",
    "user_id": "12345",
    "course_id": "67890",
    "video_id": "abc123",
    "watched_seconds": 1200,
    "total_seconds": 1800,
    "last_position": 1200,
    "completed": false,
    "timestamp": "2024-01-15T10:30:00Z",
    // New fields in v2
    "playback_speed": 1.5,
    "quality": "1080p"
}

// Repository handles version migration
@Repository
public class LearningProgressRepository {
    public LearningProgress findById(String id) {
        Document doc = collection.find(eq("_id", id)).first();
        return migrateToLatest(doc);
    }

    private LearningProgress migrateToLatest(Document doc) {
        String version = doc.getString("_schema_version");
        if ("1.0".equals(version)) {
            // Migrate v1 to v2
            doc.put("playback_speed", 1.0); // default value
            doc.put("_schema_version", "2.0");
        }
        return new LearningProgress(doc);
    }
}

// Background migration job
- Identify documents with old schema versions
- Batch update to latest version
- Monitor migration progress
```

---

## Minor Improvements

### 13. JWT Refresh Token Mechanism Missing

**Issue**: The document explicitly states "リフレッシュトークンは未実装（短期トークンのみ）". This forces users to re-authenticate frequently, harming user experience.

**Improvement**: Implement refresh token rotation with Redis storage for token revocation support.

### 14. CSRF Protection Unimplemented

**Issue**: "CSRF対策（未実装）" is acknowledged but not prioritized. For state-changing operations, this is a security gap (though security is noted as out of scope for this structural review).

**Improvement**: Enable Spring Security CSRF protection for non-API endpoints or use same-site cookie attributes.

### 15. Assignment Grading Lacks Workflow State Machine

**Issue**: `assignment_submissions` table has only `score` and `feedback` fields without status tracking (submitted, grading, graded, returned). This makes workflow management implicit.

**Improvement**:
```sql
ALTER TABLE assignment_submissions ADD COLUMN status VARCHAR(50);
-- Values: SUBMITTED, GRADING, GRADED, RESUBMIT_REQUESTED
```

---

## Positive Aspects

1. **Clear Technology Stack**: Well-defined choices (Java 17, Spring Boot 3.1, PostgreSQL, MongoDB) enable team alignment
2. **Polyglot Persistence**: Appropriate use of PostgreSQL for transactional data and MongoDB for time-series logs
3. **Deployment Strategy**: Blue-Green deployment on ECS provides safe rollback capability
4. **Caching Layer**: Redis for session and API response caching shows performance awareness
5. **Search Capability**: Elasticsearch integration for course search is appropriate for full-text search use cases

---

## Summary

This design exhibits significant structural quality issues primarily stemming from:
1. **Weak module boundaries**: CourseService as a monolith violates SRP
2. **Dependency Inversion absence**: Direct database access hinders testability
3. **Error handling gaps**: No domain exception taxonomy or retryability strategy
4. **DTO/Domain separation missing**: API contracts leak implementation details
5. **Testing strategy flaws**: Rejection of mocking leads to slow, brittle tests

The architecture would benefit from:
- Decomposing CourseService into bounded contexts (Assignment, Progress, Certification services)
- Introducing repository abstractions and dependency injection for testability
- Defining a comprehensive domain exception hierarchy with error codes
- Separating API DTOs from domain models and persistence entities
- Adopting a balanced test pyramid with unit, integration, and E2E tests
- Implementing structured logging with distributed tracing support
- Defining API versioning and schema evolution strategies

These improvements would significantly enhance maintainability, changeability, and testability, enabling the system to evolve sustainably over its lifecycle.
