# Consistency Review Report: リアルタイム配信プラットフォーム システム設計書

## Pass 1 - Structural Understanding Summary

The design document describes a live streaming platform with real-time chat functionality. It covers:
- Overview and main features (sections 1)
- Technology stack including Java/Spring Boot backend, TypeScript/React frontend (section 2)
- Three-layer architecture (Presentation, Business, Data Access) (section 3)
- Database schema for three tables (section 4)
- REST API and WebSocket endpoints (section 5)
- Implementation policies for error handling, logging, testing, deployment (section 6)
- Non-functional requirements for performance, security, scalability (section 7)

**Key observations from Pass 1**:
- The document includes specific technology choices but lacks references to existing codebase patterns
- Three data models are presented with inconsistent naming conventions within the document itself
- Error handling and logging approaches are described but not linked to existing system patterns
- No explicit documentation references or existing module comparisons are provided
- API response formats are shown but alignment with existing API conventions is not verified

## Pass 2 - Detailed Consistency Analysis

### Inconsistencies Identified

#### CRITICAL: Data Model Naming Convention Inconsistency (Multiple Patterns)

**Location**: Section 4 - Data Model

**Issue**: Three different naming patterns are used across the three table definitions within the same design document:

1. **live_stream table**: Uses PostgreSQL snake_case convention
   - Table name: `live_stream`
   - Column names: `stream_id`, `streamer_user_id`, `stream_title`, `stream_status`, `started_at`, `ended_at`, `viewer_peak`, `created_at`, `updated_at`

2. **ChatMessage table**: Uses mixed PascalCase for table name and camelCase for column names
   - Table name: `ChatMessage`
   - Column names: `messageId`, `streamId`, `userId`, `messageText`, `sentAt`, `isDeleted`

3. **viewer_session table**: Uses snake_case consistently
   - Table name: `viewer_sessions`
   - Column names: `session_id`, `stream_id`, `user_id`, `connected_at`, `disconnected_at`

**Pattern Evidence Required**:
- Cannot verify alignment with existing database schema without codebase access
- Need to examine existing database migration files or entity definitions to determine the dominant pattern
- Typically in Spring Boot/JPA projects, entity classes use camelCase field names that map to snake_case columns via `@Column` annotations

**Impact**:
- Will cause SQL query failures if table/column names don't match actual database schema
- May require extensive refactoring if ORM mappings are incorrect
- Developers will face confusion about which naming convention to follow
- Database joins across these tables will use inconsistent naming styles

**Recommendation**:
1. Verify existing database schema naming pattern in the codebase (examine existing entities or migration files)
2. Standardize all three table definitions to match the dominant pattern
3. If snake_case is the standard, all table and column names should follow that pattern
4. Document the chosen naming convention explicitly in section 4

---

#### CRITICAL: Error Handling Strategy Inconsistency - Individual Catch vs Global Handler

**Location**: Section 6 - Error Handling Policy

**Issue**: The design specifies using individual catch blocks at the Controller layer:

> "業務例外が発生した場合は、各Service層で `BusinessException` をスローし、Controller層の個別 catch ブロックで処理する"

This approach contradicts modern Spring Boot best practices and may conflict with existing global error handling patterns.

**Pattern Evidence Required**:
- Need to check if existing codebase uses `@ControllerAdvice` or `@RestControllerAdvice` for centralized exception handling
- Need to verify if there are existing exception handler classes (e.g., `GlobalExceptionHandler`, `ApiExceptionHandler`)
- Need to examine existing controllers to see if they use try-catch blocks or rely on global handlers

**Impact**:
- If existing system uses `@ControllerAdvice`, this design will create inconsistent error handling across modules
- Developers will need to duplicate error handling logic in every controller method
- Error response format may vary between existing endpoints and new livestream endpoints
- Maintenance burden increases as error handling logic is scattered across multiple controllers

**Recommendation**:
1. Search codebase for `@ControllerAdvice` or `@RestControllerAdvice` annotations
2. If global handler exists, update design to use the same pattern
3. If individual catch is the dominant pattern, document why this project-specific approach is used
4. Ensure error response format matches existing API error responses (verify the `{"success": false, "error": {...}}` format against actual existing responses)

---

#### SIGNIFICANT: API Response Format Alignment Unverified

**Location**: Section 5 - API Design, Request/Response Format

**Issue**: The design proposes a specific response format:

```json
{
  "success": true,
  "stream": { ... }
}
```

and error format:

```json
{
  "success": false,
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Invalid stream title"
  }
}
```

However, there is no reference to existing API response patterns in the codebase.

**Pattern Evidence Required**:
- Need to examine existing controller response patterns
- Check if existing APIs use wrapper objects with "success" field or return data directly
- Verify if existing error responses use "error.code" and "error.message" structure
- Check if there are existing DTO or response wrapper classes (e.g., `ApiResponse<T>`, `ResponseWrapper<T>`)

**Impact**:
- If existing APIs use different response structure, client applications may need to handle multiple response formats
- Frontend developers will face inconsistent response parsing logic
- API documentation and Swagger/OpenAPI specs may become inconsistent
- Integration testing expectations may differ from actual API behavior

**Recommendation**:
1. Search for existing response wrapper classes or base response types
2. Find existing controller methods and examine their return types and response formats
3. Update API design section to match existing patterns
4. If no standard exists, propose and document this as the new standard for all future APIs

---

#### SIGNIFICANT: Logging Format Alignment Unverified

**Location**: Section 6 - Logging Policy

**Issue**: The design specifies a custom logging format:

```
[LEVEL] [YYYY-MM-DD HH:MM:SS] [ClassName.methodName] - Log message (key1=value1, key2=value2)
```

This format may not align with existing logging configuration (Logback/Log4j2) or structured logging patterns.

**Pattern Evidence Required**:
- Need to check `logback-spring.xml` or `log4j2.xml` configuration files
- Verify if existing system uses structured logging (JSON format) or plain text format
- Check if MDC (Mapped Diagnostic Context) is used for contextual information
- Examine existing log statements to see actual format in use

**Impact**:
- If existing logs use different format, log aggregation and parsing tools (e.g., ELK, Splunk) may fail on new logs
- Developers may be confused about which logging format to use
- Log analysis queries and dashboards may break or require modification
- Operational monitoring and alerting may not work correctly

**Recommendation**:
1. Locate logging configuration files (`logback-spring.xml`, `application.yml` logging section)
2. Examine existing service classes to see actual log statement patterns
3. Update logging policy to match existing format or explicitly document the decision to change logging format system-wide
4. If structured logging is standard, update to use JSON format with consistent fields

---

#### MODERATE: Directory Structure and File Placement Not Documented

**Location**: Section 3 - Architecture Design, Section 6 - Implementation Policy

**Issue**: The design lists component names (e.g., `LiveStreamController`, `LiveStreamService`, `LiveStreamRepository`) but does not specify where these files should be placed within the project structure.

**Missing Information**:
- Package structure (e.g., `com.example.livestream.controller`, `com.example.feature.livestream.controller`)
- Module organization (is this a separate module or part of existing module?)
- Source directory structure (`src/main/java/...` path)
- Whether organization is domain-based (feature folders) or layer-based (controller/service/repository folders)

**Pattern Evidence Required**:
- Need to examine existing project structure (`src/main/java` directory tree)
- Check if packages are organized by feature (e.g., `user/`, `video/`, `payment/`) or by layer (e.g., `controllers/`, `services/`, `repositories/`)
- Verify package naming conventions (domain prefix, module structure)

**Impact**:
- Developers may place files in incorrect locations
- May require restructuring after initial implementation
- Code review friction due to unclear placement expectations
- IDE navigation and package organization may become inconsistent

**Recommendation**:
1. Map existing package structure (use Glob to find existing Java files)
2. Add explicit section "File Placement and Package Structure" to the design
3. Provide full package names for each component
4. Include directory tree example showing where new files will be placed relative to existing files

---

#### MODERATE: Dependency and Library Version Alignment Not Verified

**Location**: Section 2 - Technology Stack, Main Libraries

**Issue**: The design specifies specific libraries:
- Spring WebSocket
- Spring WebClient
- Jakarta Validation
- MapStruct

However, there is no verification that these libraries are already in use or compatible with existing project dependencies.

**Pattern Evidence Required**:
- Need to check `pom.xml` or `build.gradle` for existing dependencies
- Verify Spring Boot version and compatible library versions
- Check if Spring WebSocket is already configured (auto-configuration may be disabled)
- Verify if MapStruct is already in project dependencies or if it needs to be added

**Impact**:
- May introduce dependency conflicts or version mismatches
- If MapStruct is not currently used, it adds build complexity (annotation processing configuration)
- If Spring WebClient is not used (and RestTemplate is standard), this creates inconsistent HTTP client usage
- Library learning curve for developers unfamiliar with newly introduced libraries

**Recommendation**:
1. Read `pom.xml` or `build.gradle` to verify existing dependencies
2. Update technology stack section to note which libraries are new vs. existing
3. If introducing new libraries, document rationale and migration plan
4. Ensure all library versions are compatible with existing Spring Boot version

---

#### MODERATE: Authentication/Authorization Pattern Alignment Unverified

**Location**: Section 5 - Authentication and Authorization Method

**Issue**: The design states:

> "既存のJWT認証を使用する。配信開始・終了には配信者ロール、チャット送信には一般ユーザーロールが必要。"

This is vague and does not specify the implementation pattern (middleware, interceptor, method security annotations).

**Pattern Evidence Required**:
- Need to check if existing authentication uses Spring Security with JWT
- Verify if existing endpoints use `@PreAuthorize` annotations, security interceptors, or custom filters
- Check if role-based access control (RBAC) is already implemented
- Verify role naming conventions (e.g., `ROLE_STREAMER` vs. `streamer` vs. `Streamer`)

**Impact**:
- May implement authorization differently than existing endpoints
- Role names may not match existing user role definitions in database
- Security testing approaches may differ
- Authorization bypass vulnerabilities if pattern is implemented incorrectly

**Recommendation**:
1. Search for existing security configuration classes (`@EnableWebSecurity`, `SecurityFilterChain`)
2. Examine existing protected endpoints to see authorization pattern
3. Document specific implementation approach (e.g., "Use `@PreAuthorize('hasRole(\"STREAMER\")')` annotation on controller methods")
4. Specify exact role names to match existing user role definitions

---

### Pattern Evidence (Codebase Analysis Blocked)

**Critical Limitation**: This review was conducted without access to the actual codebase. All consistency issues identified are flagged as **"requires verification"** because dominant patterns cannot be determined without examining:

1. Existing database schema files (`schema.sql`, migration files, Entity classes)
2. Existing controller implementations to verify response format and error handling patterns
3. Logging configuration files (`logback-spring.xml`, `application.yml`)
4. Project structure (`src/main/java` directory tree)
5. Dependency files (`pom.xml`, `build.gradle`)
6. Security configuration classes

**If codebase access were available**, the following searches would be performed:

```
Glob: **/*Controller.java
Glob: **/*Service.java
Glob: **/*Repository.java
Glob: **/*Entity.java
Read: pom.xml or build.gradle
Read: src/main/resources/logback-spring.xml
Read: src/main/resources/application.yml
Glob: **/GlobalExceptionHandler.java
Glob: **/ApiExceptionHandler.java
Grep: "@ControllerAdvice" pattern across codebase
Grep: "@PreAuthorize" pattern across codebase
```

---

### Impact Analysis

#### High Impact Issues (Require Immediate Verification)

1. **Data Model Naming Inconsistency**: Could cause SQL errors and database access failures immediately upon deployment
2. **Error Handling Pattern**: Could lead to inconsistent API error responses and client integration issues
3. **API Response Format**: Could break existing client applications or require dual response handling logic

#### Medium Impact Issues (Should Be Resolved Before Implementation)

1. **Logging Format**: May cause operational monitoring issues but won't break functionality
2. **Directory Structure**: Will cause friction during development and code review
3. **Library Dependencies**: May introduce build issues or dependency conflicts

#### Low Impact Issues (Can Be Deferred)

1. **Authentication implementation details**: Can be refined during implementation with security testing
2. **Documentation references**: Does not affect functionality but impacts maintainability

---

### Recommendations

#### Immediate Actions (Before Implementation Begins)

1. **Access Existing Codebase**: The review team must have read access to the existing codebase to verify all patterns. This review is incomplete without it.

2. **Resolve Data Model Naming**: Decide on one consistent naming convention for all database tables and columns. Document the decision in the design.

3. **Verify Error Handling Pattern**: Check existing codebase for global exception handlers. Update design to match existing pattern.

4. **Verify API Response Format**: Find examples of existing API responses. Update design to use the same structure.

5. **Verify Logging Configuration**: Check existing logging format and update design to match.

#### Before Code Review

1. **Add Directory Structure Section**: Document exact package names and file locations for all new components.

2. **Verify Dependencies**: Review `pom.xml`/`build.gradle` and confirm all libraries are compatible.

3. **Document Authentication Implementation**: Specify exact implementation approach (annotations, interceptors, filters) based on existing pattern.

#### Positive Alignment Aspects (Pending Verification)

1. **Three-Layer Architecture**: The proposed Presentation-Business-Data Access separation follows standard Spring Boot layering if this matches existing architecture.

2. **Spring Boot Ecosystem**: Using Spring WebSocket, Spring WebClient, and Jakarta Validation is consistent with modern Spring Boot applications, assuming these are already in use.

3. **Testing Strategy**: The proposed JUnit 5 + Mockito + TestContainers approach is industry standard and likely aligns with existing test infrastructure.

---

## Summary

This design document requires **verification against existing codebase patterns** before implementation can begin. Seven consistency issues were identified, ranging from **critical** (data model naming inconsistency) to **moderate** (directory structure not documented).

**Key Blocker**: Without access to the existing codebase, this consistency review cannot determine whether the design aligns with established patterns. The review team must be granted read access to:
- Database schema files
- Existing controller/service/repository implementations
- Logging configuration
- Dependency files
- Project directory structure

**Next Steps**:
1. Grant codebase access to consistency reviewer
2. Perform full pattern verification
3. Update design document to align with verified existing patterns
4. Re-review updated design before implementation kickoff
