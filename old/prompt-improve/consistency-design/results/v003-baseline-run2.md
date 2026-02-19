# Consistency Design Review: リアルタイム配信プラットフォーム

## Inconsistencies Identified

### Critical Inconsistencies

#### C-1: Inconsistent Table Naming Convention
**Severity**: Critical
**Location**: Section 4 - Data Model

The three table definitions use different naming conventions:
- `live_stream`: snake_case with underscores
- `ChatMessage`: PascalCase
- `viewer_sessions`: snake_case with underscores (plural form)

This creates a systematic inconsistency in the database schema. Two tables follow snake_case convention while one uses PascalCase, which will cause confusion and potential errors in ORM mapping and SQL query generation.

**Missing Documentation**: The design document does not specify or justify the chosen table naming convention, nor does it reference existing database naming patterns in the codebase.

#### C-2: Inconsistent Column Naming Convention Across Tables
**Severity**: Critical
**Location**: Section 4 - Data Model

Column naming conventions are inconsistent across the three tables:
- `live_stream` table: snake_case (e.g., `stream_id`, `streamer_user_id`, `created_at`)
- `ChatMessage` table: camelCase (e.g., `messageId`, `streamId`, `userId`, `messageText`, `sentAt`, `isDeleted`)
- `viewer_sessions` table: snake_case (e.g., `session_id`, `stream_id`, `user_id`, `connected_at`)

This creates a fundamental inconsistency in database schema design that will affect ORM entity mapping, query generation, and data access patterns throughout the application.

**Missing Documentation**: No explanation for why different column naming conventions are used, and no reference to existing patterns in the database.

### Significant Inconsistencies

#### S-1: Mixed API Response Structure Pattern
**Severity**: Significant
**Location**: Section 5 - API Design

The success response wraps data in a `success` + `stream` structure:
```json
{
  "success": true,
  "stream": { ... }
}
```

While the error response uses `success` + `error`:
```json
{
  "success": false,
  "error": { ... }
}
```

This mixed pattern creates inconsistency in response handling. The success response uses a domain-specific wrapper (`stream`), while the error uses a generic wrapper (`error`). This suggests potential inconsistency with existing API response conventions.

**Missing Documentation**: The design document does not reference existing API response format conventions or explain why this particular structure was chosen.

#### S-2: Incomplete Error Handling Pattern Documentation
**Severity**: Significant
**Location**: Section 6 - Implementation Guidelines

The error handling approach specifies:
- Business exceptions: `BusinessException` thrown in Service layer, caught in Controller's individual catch blocks
- Technical exceptions: Logged and return generic error response

However, the document does not address:
- Whether a global exception handler exists or should be used
- How the "individual catch blocks" pattern aligns with existing error handling in the codebase
- How to handle validation errors (Jakarta Validation is listed but not integrated into the error handling flow)
- Transaction rollback patterns for business exceptions

**Missing Documentation**: No reference to existing error handling patterns or architectural decision records explaining why individual catch blocks are preferred over a global handler.

#### S-3: Missing Dependency Injection Pattern Documentation
**Severity**: Significant
**Location**: Section 3 - Architecture Design, Section 6 - Implementation Guidelines

The document describes component responsibilities and layer structure but does not document:
- How dependencies are injected (constructor injection, field injection, setter injection)
- Whether interfaces should be defined for Services and Repositories
- Component scanning and configuration patterns
- Bean lifecycle management for WebSocket handlers and singleton services

**Missing Documentation**: No explicit documentation of dependency injection patterns or reference to existing Spring configuration conventions in the codebase.

### Moderate Inconsistencies

#### M-1: Inconsistent File Naming Convention Across Layers
**Severity**: Moderate
**Location**: Section 3 - Architecture Design

Component names suggest potential file naming inconsistencies:
- Controllers: `LiveStreamController` (PascalCase with "Controller" suffix)
- Handlers: `ChatWebSocketHandler` (PascalCase with "Handler" suffix)
- Services: `LiveStreamService`, `ChatService` (PascalCase with "Service" suffix)
- Repositories: `LiveStreamRepository` (PascalCase with "Repository" suffix)

While class names appear consistent in PascalCase with role suffixes, the document does not specify:
- File naming convention (e.g., `LiveStreamController.java` vs `live-stream-controller.java`)
- Whether file names match class names exactly
- Package naming conventions (e.g., `com.example.livestream` vs `com.example.live_stream`)

**Missing Documentation**: No documentation of file naming conventions or reference to existing file organization patterns in the codebase.

#### M-2: Missing Transaction Management Pattern
**Severity**: Moderate
**Location**: Section 6 - Implementation Guidelines

The document mentions:
- Data access patterns using Repository
- Business logic in Service layer
- Database operations across multiple tables (live_stream, chat_message, viewer_session)

However, it does not specify:
- Transaction boundary definition (@Transactional at Service layer or Repository layer)
- Transaction propagation rules
- How to handle distributed transactions (e.g., DB write + RabbitMQ publish)
- Rollback rules for business vs technical exceptions

**Missing Documentation**: No documentation of transaction management patterns or reference to existing transactional approaches in the codebase.

#### M-3: Incomplete Directory Structure Documentation
**Severity**: Moderate
**Location**: Section 3 - Architecture Design

The document describes layer composition (Presentation, Business, Data Access) but does not document:
- Whether organization is domain-based (e.g., `/livestream`, `/chat`) or layer-based (e.g., `/controller`, `/service`)
- Where WebSocket handlers should be placed (with controllers, separate package, or dedicated websocket package)
- Where configuration classes should reside
- Where DTOs/request-response models should be placed

**Missing Documentation**: No explicit directory structure specification and no reference to existing file placement conventions in the codebase.

#### M-4: Missing Asynchronous Processing Pattern Documentation
**Severity**: Moderate
**Location**: Section 3 - Data Flow, Section 6 - Implementation Guidelines

The data flow describes asynchronous operations:
- Publishing events to RabbitMQ
- NotificationService consuming events
- WebSocket message broadcasting

However, the document does not specify:
- Async execution pattern (Spring @Async, CompletableFuture, reactive approach)
- Thread pool configuration
- Error handling in async operations
- Whether async processing aligns with evaluation criterion #3 (async/await/Promise/callback patterns)

**Missing Documentation**: No explicit documentation of asynchronous processing patterns or reference to existing async approaches in the codebase.

### Minor Improvements

#### I-1: Configuration Management Pattern Not Documented
**Severity**: Minor
**Location**: Section 2 - Technology Stack, Section 6 - Implementation Guidelines

The document lists infrastructure components (PostgreSQL, Redis, RabbitMQ, AWS MediaLive) but does not document:
- Configuration file format (application.yml vs application.properties)
- Environment-specific configuration approach (Spring Profiles, environment variables)
- Environment variable naming convention (e.g., `SPRING_DATASOURCE_URL` vs `DATABASE_URL`)
- Secret management approach

**Missing Documentation**: No reference to existing configuration management patterns in the codebase.

#### I-2: Logging Pattern Partially Documented
**Severity**: Minor
**Location**: Section 6 - Implementation Guidelines

The logging format is documented:
```
[LEVEL] [YYYY-MM-DD HH:MM:SS] [ClassName.methodName] - Log message (key1=value1, key2=value2)
```

However, the document does not specify:
- Logging library (SLF4J, Logback, Log4j2)
- Log level usage guidelines (when to use INFO vs DEBUG vs WARN)
- Whether structured logging library is used (or manual key-value formatting)
- How this format aligns with existing logging patterns in the codebase

**Missing Documentation**: Incomplete logging pattern documentation and no reference to existing logging conventions.

## Pattern Evidence

**Note**: This review cannot provide concrete pattern evidence from the existing codebase as the actual codebase was not analyzed. The inconsistencies identified are based on internal inconsistencies within the design document itself and missing references to existing patterns.

To verify alignment with existing codebase patterns, the following investigation is required:

### Required Codebase Analysis

1. **Database Schema Patterns**:
   - Analyze existing table definitions to determine dominant naming convention (snake_case vs PascalCase)
   - Check existing column naming patterns across all tables
   - Verify primary key naming conventions

2. **API Response Format Patterns**:
   - Review existing REST API endpoints to identify dominant response structure
   - Check if `success` wrapper pattern exists in current APIs
   - Verify error response format consistency

3. **Error Handling Patterns**:
   - Search for `@ControllerAdvice` or global exception handler implementations
   - Analyze existing Controller methods to check if individual catch blocks are used
   - Review exception hierarchy and business exception handling

4. **Dependency Injection Patterns**:
   - Check existing Service and Repository implementations
   - Verify if interfaces are defined for Services
   - Analyze constructor injection vs field injection usage

5. **File Organization Patterns**:
   - Analyze package structure to determine domain-based vs layer-based organization
   - Check file naming conventions in existing modules
   - Verify directory placement rules

6. **Transaction Management Patterns**:
   - Search for `@Transactional` annotations to identify transaction boundaries
   - Review existing Service layer transaction patterns

7. **Asynchronous Processing Patterns**:
   - Search for `@Async`, `CompletableFuture`, or reactive patterns
   - Check existing message queue integration patterns

8. **Configuration Patterns**:
   - Check if `application.yml` or `application.properties` is used
   - Analyze environment variable naming conventions
   - Review Spring Profile usage

## Impact Analysis

### Impact of C-1 and C-2 (Table and Column Naming Inconsistencies)

**Consequences**:
- **ORM Mapping Complexity**: Entity classes will require complex `@Table` and `@Column` annotations to map between Java naming conventions and inconsistent database names
- **Developer Confusion**: Team members will struggle to predict table/column names, requiring constant reference to schema documentation
- **Query Generation Issues**: Dynamic query builders and criteria APIs will require special handling for different naming patterns
- **Migration Risk**: Future schema changes may inadvertently follow the wrong convention, compounding the inconsistency
- **Code Review Overhead**: Reviewers must verify correct naming for each new table/column addition

**Estimated Effort to Remediate Later**: High (requires database migration, entity refactoring, and query updates across the entire codebase)

### Impact of S-1 (Mixed API Response Structure)

**Consequences**:
- **Frontend Integration Complexity**: Frontend code must handle different response structures for different endpoints
- **API Client Code Duplication**: Generic response handlers cannot be created due to inconsistent wrapper structure
- **Documentation Burden**: API documentation must explain multiple response patterns
- **Testing Complexity**: Test utilities must account for varying response structures

**Estimated Effort to Remediate Later**: Medium (requires API contract changes, frontend code updates, and versioning considerations)

### Impact of S-2 (Incomplete Error Handling Pattern)

**Consequences**:
- **Inconsistent Error Responses**: Individual catch blocks in different controllers may return different error formats
- **Code Duplication**: Error handling logic may be repeated across multiple controllers
- **Maintenance Burden**: Changes to error response format require updates in multiple locations
- **Incomplete Error Coverage**: Some exception types may not be caught, resulting in unhandled 500 errors

**Estimated Effort to Remediate Later**: Medium (requires refactoring of error handling across all controllers)

### Impact of S-3 (Missing Dependency Injection Pattern)

**Consequences**:
- **Inconsistent Component Configuration**: Different developers may choose different injection patterns
- **Testing Difficulty**: Field injection makes unit testing harder compared to constructor injection
- **Circular Dependency Risk**: Without clear patterns, circular dependencies may be introduced
- **Code Maintainability**: Unclear dependency patterns make code harder to understand and refactor

**Estimated Effort to Remediate Later**: Low to Medium (requires refactoring of service/repository construction but does not affect external contracts)

### Impact of M-1 to M-4 (Moderate Inconsistencies)

**Consequences**:
- **Onboarding Friction**: New team members cannot rely on consistent patterns
- **Code Navigation Difficulty**: Inconsistent file placement makes code harder to locate
- **Potential Runtime Issues**: Inconsistent async patterns may lead to thread pool exhaustion or deadlocks
- **Transaction Boundary Confusion**: Missing transaction patterns may lead to data consistency issues

**Estimated Effort to Remediate Later**: Low to Medium (depends on specific issue; some require architectural changes, others just documentation)

### Cross-Cutting Impact

The identified inconsistencies span multiple categories, suggesting a **systematic lack of pattern documentation**. This creates a compounding effect where:
- Developers cannot reference a single source of truth for technical decisions
- Inconsistencies accumulate over time as different developers make different assumptions
- Code review effectiveness decreases due to absence of objective consistency criteria
- Refactoring becomes riskier as implicit patterns are not documented

## Recommendations

### Priority 1: Critical - Remediate Before Implementation

#### R-1: Standardize Database Naming Convention
**Action**: Choose a single naming convention for all tables and columns, and update the schema definitions.

**Recommended Approach**:
1. Investigate existing database schema to identify dominant pattern (snake_case vs camelCase)
2. If snake_case is dominant (most PostgreSQL projects use snake_case):
   - Update `ChatMessage` table to `chat_message`
   - Update all columns in `chat_message` to snake_case (`message_id`, `stream_id`, `user_id`, `message_text`, `sent_at`, `is_deleted`)
3. Document the chosen convention in the design document with explicit justification
4. Consider creating a schema naming convention guideline document for the entire codebase

**Alternative**: If camelCase is the existing dominant pattern:
- Update `live_stream` to `LiveStream` and all its columns to camelCase
- Update `viewer_sessions` to `ViewerSession` and all its columns to camelCase

**Documentation Addition**:
```markdown
### Database Naming Convention
All table names use snake_case singular form (e.g., `live_stream`, `chat_message`).
All column names use snake_case (e.g., `stream_id`, `created_at`).
This aligns with existing PostgreSQL schema conventions in [reference existing tables].
```

#### R-2: Standardize Column Naming Pattern
**Action**: Ensure all tables use the same column naming convention (snake_case recommended for PostgreSQL).

**Recommended Implementation**:
```sql
-- Updated chat_message table
CREATE TABLE chat_message (
    message_id BIGSERIAL PRIMARY KEY,
    stream_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    message_text TEXT NOT NULL,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);
```

### Priority 2: Significant - Document Before Implementation

#### R-3: Document and Align API Response Format
**Action**: Investigate existing API response patterns and document the chosen format.

**Investigation Steps**:
1. Review existing REST endpoints in the codebase
2. Identify dominant response structure pattern
3. Document the pattern with examples

**If Existing Pattern Uses Standard REST Format (no `success` wrapper)**:
```json
// Success response (200 OK)
{
  "streamId": 98765,
  "title": "今日のライブ配信",
  "streamerId": 12345,
  "status": "ACTIVE",
  "startedAt": "2026-02-11T10:00:00Z"
}

// Error response (4xx/5xx with consistent error object)
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Invalid stream title",
    "timestamp": "2026-02-11T10:00:00Z",
    "path": "/api/v1/streams"
  }
}
```

**If Existing Pattern Uses `success` Wrapper**:
- Ensure wrapper structure is consistent between success and error responses
- Consider using generic `data` field instead of domain-specific `stream` field

#### R-4: Document Error Handling Architecture
**Action**: Explicitly document error handling pattern and verify alignment with existing approach.

**Recommended Documentation**:
```markdown
### Error Handling Pattern

#### Business Exceptions
- Thrown in Service layer as `BusinessException` or domain-specific exceptions
- Handled by `@ControllerAdvice` global exception handler
- Mapped to appropriate HTTP status codes and error response format

#### Validation Errors
- Jakarta Validation annotations on request DTOs
- Handled by `@ControllerAdvice` with `@ExceptionHandler(MethodArgumentNotValidException.class)`
- Returns 400 Bad Request with field-level error details

#### Technical Exceptions
- Logged with ERROR level
- Handled by global exception handler fallback
- Returns 500 Internal Server Error with generic message (no internal details exposed)

#### Transaction Rollback
- Business exceptions trigger automatic rollback
- Technical exceptions trigger automatic rollback
- Use `@Transactional(noRollbackFor = {...})` for exceptions that should not trigger rollback
```

**Alternative (if existing codebase uses individual catch blocks)**:
Document the rationale and provide consistent exception handling utility to avoid code duplication.

#### R-5: Document Dependency Injection Pattern
**Action**: Specify dependency injection approach and verify alignment with existing codebase.

**Recommended Pattern (Spring Best Practice)**:
```markdown
### Dependency Injection Pattern

All components use **constructor injection** with final fields:

```java
@Service
public class LiveStreamService {
    private final LiveStreamRepository repository;
    private final NotificationService notificationService;

    public LiveStreamService(
        LiveStreamRepository repository,
        NotificationService notificationService
    ) {
        this.repository = repository;
        this.notificationService = notificationService;
    }
}
```

**Rationale**: Constructor injection enables:
- Immutable dependencies (final fields)
- Easy unit testing (constructor-based mocking)
- Clear dependency declaration
- Compile-time circular dependency detection

This aligns with existing Service layer implementations in [reference existing modules].
```

### Priority 3: Moderate - Document During Implementation

#### R-6: Document Directory Structure Convention
**Action**: Define and document file placement rules.

**Recommended Approach**:
1. Analyze existing project structure
2. Choose domain-based or layer-based organization
3. Document the convention with examples

**Example Documentation (Domain-Based)**:
```markdown
### Directory Structure

Project follows **domain-based organization**:

```
src/main/java/com/example/
├── livestream/
│   ├── controller/
│   │   └── LiveStreamController.java
│   ├── service/
│   │   └── LiveStreamService.java
│   ├── repository/
│   │   └── LiveStreamRepository.java
│   ├── model/
│   │   ├── entity/
│   │   │   └── LiveStreamEntity.java
│   │   └── dto/
│   │       ├── CreateStreamRequest.java
│   │       └── StreamResponse.java
│   └── websocket/
│       └── ChatWebSocketHandler.java
├── notification/
│   └── ...
└── common/
    ├── config/
    ├── exception/
    └── util/
```

This aligns with existing module organization in [reference existing domains].
```

#### R-7: Document Transaction Management Pattern
**Action**: Define transaction boundary and propagation rules.

**Recommended Pattern**:
```markdown
### Transaction Management

- **Transaction Boundary**: Service layer methods annotated with `@Transactional`
- **Propagation**: Default `REQUIRED` (join existing transaction or create new)
- **Read-Only Optimization**: Query methods use `@Transactional(readOnly = true)`
- **Isolation Level**: Default `READ_COMMITTED`

**Example**:
```java
@Service
public class LiveStreamService {
    @Transactional
    public StreamResponse startStream(CreateStreamRequest request) {
        // DB write + event publish
    }

    @Transactional(readOnly = true)
    public StreamResponse getStream(Long streamId) {
        // Read-only query
    }
}
```

**Distributed Transaction Handling**:
For operations spanning DB + RabbitMQ, use eventual consistency pattern:
1. Save to DB within transaction
2. Publish event after transaction commit using `@TransactionalEventListener`
3. Implement idempotency in event consumers
```

#### R-8: Document Asynchronous Processing Pattern
**Action**: Define async execution approach and align with existing patterns.

**Recommended Pattern**:
```markdown
### Asynchronous Processing Pattern

#### Async Method Execution
Use Spring `@Async` for non-blocking operations:

```java
@Service
public class NotificationService {
    @Async("notificationExecutor")
    public CompletableFuture<Void> sendNotification(Long userId, String message) {
        // Async notification logic
    }
}
```

#### Thread Pool Configuration
```java
@Configuration
@EnableAsync
public class AsyncConfig {
    @Bean("notificationExecutor")
    public Executor notificationExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("notification-");
        return executor;
    }
}
```

#### Error Handling
Implement `AsyncUncaughtExceptionHandler` for unhandled async exceptions.
```

### Priority 4: Minor - Document Post-Implementation

#### R-9: Document Configuration Management Pattern
**Action**: Specify configuration file format and environment variable conventions.

**Recommended Investigation**:
1. Check if existing project uses `application.yml` or `application.properties`
2. Verify environment-specific configuration approach
3. Document environment variable naming convention

**Example Documentation**:
```markdown
### Configuration Management

- **Format**: application.yml (Spring Boot standard)
- **Environment Profiles**: dev, staging, production
- **Environment Variables**: UPPERCASE_SNAKE_CASE (e.g., `DATABASE_URL`, `RABBITMQ_HOST`)
- **Secret Management**: AWS Secrets Manager for production credentials

**Example Configuration**:
```yaml
spring:
  datasource:
    url: ${DATABASE_URL}
  rabbitmq:
    host: ${RABBITMQ_HOST}
```
```

#### R-10: Enhance Logging Pattern Documentation
**Action**: Specify logging library and usage guidelines.

**Recommended Enhancement**:
```markdown
### Logging Pattern

**Library**: SLF4J with Logback

**Log Level Usage**:
- `ERROR`: System errors requiring immediate attention
- `WARN`: Unexpected situations that don't prevent operation
- `INFO`: Important business events (stream start/stop, user actions)
- `DEBUG`: Detailed diagnostic information (for development)

**Format**: Structured logging with key-value pairs
```java
log.info("Stream started (streamId={}, userId={}, title={})",
    streamId, userId, title);
```

**Output Format** (configured in logback.xml):
```
[INFO] [2026-02-11 10:00:00] [LiveStreamService.startStream] - Stream started (streamId=98765, userId=12345, title=今日のライブ配信)
```
```

### Summary of Recommendations

| Priority | Recommendation | Action Required | Estimated Effort |
|----------|---------------|-----------------|------------------|
| P1 | R-1: Standardize DB table naming | Schema refactoring | 2-4 hours |
| P1 | R-2: Standardize DB column naming | Schema refactoring | 2-4 hours |
| P2 | R-3: Document API response format | Investigation + Documentation | 2-3 hours |
| P2 | R-4: Document error handling | Architecture decision + Documentation | 3-4 hours |
| P2 | R-5: Document dependency injection | Pattern documentation | 1-2 hours |
| P3 | R-6: Document directory structure | Investigation + Documentation | 2-3 hours |
| P3 | R-7: Document transaction management | Pattern documentation | 2-3 hours |
| P3 | R-8: Document async processing | Pattern documentation | 2-3 hours |
| P4 | R-9: Document configuration management | Investigation + Documentation | 1-2 hours |
| P4 | R-10: Enhance logging documentation | Documentation enhancement | 1 hour |

**Total Estimated Effort**: 18-30 hours

**Critical Path**: Address P1 recommendations (database naming) before schema creation to avoid costly migration later.
