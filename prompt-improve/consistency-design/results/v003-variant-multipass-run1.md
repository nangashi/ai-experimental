# Consistency Design Review - v003-variant-multipass-run1

**Reviewer**: consistency-design-reviewer
**Prompt Version**: v003-variant-multipass (C1c - Multi-Pass Review)
**Test Document**: test-document-round-003.md
**Review Date**: 2026-02-11

---

## Pass 1 - Structural Understanding (Completed)

The design document covers a real-time live streaming platform with the following structure:
- Overview (purpose, features, users)
- Technology stack (languages, databases, infrastructure)
- Architecture design (layered structure, components, data flow)
- Data models (3 tables with SQL schemas)
- API design (endpoints, request/response formats, authentication)
- Implementation policies (error handling, logging, testing, deployment)
- Non-functional requirements (performance, security, scalability)

**Scope**: Adding live streaming and chat functionality to an existing content delivery system using Java/Spring Boot backend and React frontend.

**Missing Information Noted**:
- No reference to existing codebase structure or patterns
- No documentation of existing conventions being followed
- No justification for technology/pattern choices relative to existing system
- Configuration file format decisions not documented

---

## Pass 2 - Detailed Consistency Analysis

### Inconsistencies Identified (Prioritized by Severity)

#### CRITICAL INCONSISTENCIES

**C1. Inconsistent Table Naming Conventions Across Data Model**

**Location**: Section 4 (Data Models)

**Issue**: Three tables use three different naming conventions:
- `live_stream` - snake_case with underscore separator
- `ChatMessage` - PascalCase
- `viewer_sessions` - snake_case plural form

**Evidence Absent**: The design document provides no reference to existing database naming patterns in the codebase. Without evidence, we cannot verify:
- Does the existing system use snake_case (e.g., `user_profile`, `content_metadata`)?
- Does it use PascalCase (e.g., `UserProfile`, `ContentMetadata`)?
- Are table names singular or plural?
- Are column names snake_case or camelCase?

**Pattern Conflict**: Within the same design document:
- `live_stream` table uses `stream_id`, `streamer_user_id` (snake_case columns)
- `ChatMessage` table uses `messageId`, `streamId`, `userId`, `messageText`, `sentAt`, `isDeleted` (camelCase columns)
- `viewer_sessions` table uses `session_id`, `stream_id`, `user_id`, `connected_at`, `disconnected_at` (snake_case columns)

**Impact**:
- Database migration scripts will create tables with mixed naming styles
- JPA/Hibernate entity mapping will require extensive manual annotation overrides
- Developers must remember different naming patterns per table
- SQL queries joining these tables will have inconsistent syntax
- Future schema evolution will lack clear naming guidance

**Recommendation**:
1. Document the existing database naming convention (verify with `information_schema.tables` and `information_schema.columns`)
2. Standardize all table names to match the dominant pattern (likely snake_case for PostgreSQL)
3. Standardize all column names consistently
4. If existing system uses PascalCase, justify PostgreSQL-specific deviation or align to existing pattern

---

**C2. Missing Architectural Pattern Documentation for WebSocket Layer**

**Location**: Section 3 (Architecture Design)

**Issue**: The design introduces `ChatWebSocketHandler` in the Presentation layer but provides no documentation of:
- How the existing system handles real-time/stateful connections (if at all)
- Whether this is the first WebSocket implementation or follows existing patterns
- How WebSocket handlers relate to the existing 3-layer architecture
- Whether existing systems use filters, interceptors, or handlers for cross-cutting concerns

**Evidence Absent**: No reference to:
- Existing authentication middleware/interceptor patterns for REST controllers
- How existing controllers handle session management
- Whether the existing system uses Spring WebSocket or a different WebSocket library
- Existing connection lifecycle management patterns

**Pattern Conflict**: The document states "既存システムのレイヤー構成に従い" (follows existing system's layer structure) but introduces a new component type (`WebSocketHandler`) without explaining:
- Is this equivalent to a Controller in the existing architecture?
- Should it be `ChatWebSocketController` to match `LiveStreamController` naming?
- Does the existing system have any real-time communication handlers?

**Impact**:
- Unclear how WebSocket components fit into existing code organization
- Inconsistent component naming and responsibility boundaries
- Potential architectural fragmentation (REST uses one pattern, WebSocket uses another)
- Developers cannot determine correct placement of future WebSocket features

**Recommendation**:
1. Document whether existing system has any WebSocket/SSE/polling mechanisms
2. If first real-time implementation, document architectural decision to add WebSocket layer
3. Specify whether `WebSocketHandler` should follow Controller naming conventions
4. Define where WebSocket-specific concerns (authentication, session management) are handled relative to existing patterns

---

**C3. Undefined Error Handling Pattern Relative to Existing System**

**Location**: Section 6 (Implementation Policies - Error Handling)

**Issue**: The design specifies "各Service層で `BusinessException` をスローし、Controller層の個別 catch ブロックで処理する" (throw BusinessException from Service layer, handle in Controller's individual catch blocks).

**Evidence Absent**: No documentation of:
- Does the existing system use a global exception handler (e.g., `@ControllerAdvice` with `@ExceptionHandler`)?
- Does the existing system use individual catch blocks in each controller?
- What is the existing exception class hierarchy (`BusinessException`, `ApplicationException`, etc.)?
- How do existing services signal business rule violations?

**Pattern Conflict**: The "individual catch block" approach conflicts with Spring Boot best practices and suggests:
- Either the existing system uses an anti-pattern (individual catch blocks)
- Or the new feature is intentionally deviating from a global exception handler pattern

**Impact**:
- If existing system uses `@ControllerAdvice`: New feature will duplicate error handling logic across individual controllers, creating maintenance burden
- If existing system uses individual catch blocks: No impact, but design document should explicitly acknowledge this is an anti-pattern alignment
- Developers cannot reuse existing error handling infrastructure
- Error response formats may diverge if not centrally managed

**Recommendation**:
1. Verify existing error handling approach (check for `@ControllerAdvice` annotations, `@ExceptionHandler` methods)
2. If global handler exists: Align new feature to use global handler
3. If individual catch blocks exist: Document this as consistency with existing anti-pattern and consider documenting it as technical debt
4. Document existing exception class hierarchy and reuse existing exception types

---

#### SIGNIFICANT INCONSISTENCIES

**S1. API Response Format Lacks Alignment Evidence**

**Location**: Section 5 (API Design - Response Format)

**Issue**: The design specifies a response format with `success` boolean and nested `stream` or `error` objects, but provides no evidence this matches existing API conventions.

**Evidence Absent**:
- Existing API response structure (flat vs nested, success flags, error code formats)
- Whether existing APIs use `success: true/false` or rely on HTTP status codes
- Existing error code naming patterns (`INVALID_REQUEST`, `BUSINESS_ERROR`, etc.)
- Whether existing APIs wrap responses in a root object or return data directly

**Pattern Examples from Design**:
```json
// Success response
{"success": true, "stream": {...}}

// Error response
{"success": false, "error": {"code": "INVALID_REQUEST", "message": "..."}}
```

**Verification Needed**:
- Do existing APIs use `{"data": {...}}` or `{"result": {...}}` or direct object return?
- Do existing error responses include `errorCode`, `code`, or `type` fields?
- Are error messages in `message`, `errorMessage`, or `detail` fields?

**Impact**:
- Frontend code must handle different response formats for new vs existing APIs
- Error handling logic cannot be unified across API client
- API consistency decreases developer experience

**Recommendation**:
1. Review existing API responses (search for existing Controller return types)
2. Document the dominant response wrapper pattern (or absence of wrapper)
3. Align new API responses to match existing format exactly
4. If changing format, document rationale and migration plan

---

**S2. Authentication Pattern Not Verified Against Existing Implementation**

**Location**: Section 5 (API Design - Authentication)

**Issue**: Design states "既存のJWT認証を使用する" (use existing JWT authentication) but provides no details on:
- How JWT is attached to requests (header name, format)
- How WebSocket connections authenticate (same JWT in handshake headers?)
- How role checks are implemented (annotations, manual code, filters)
- Whether existing system uses Spring Security or custom JWT filter

**Evidence Absent**:
- Existing authentication middleware/filter implementation
- Existing authorization annotation patterns (`@PreAuthorize`, `@RolesAllowed`, custom annotations)
- How existing WebSocket endpoints (if any) handle authentication
- Where role definitions are stored and checked

**Pattern Verification Needed**:
- REST API: "配信開始・終了には配信者ロール、チャット送信には一般ユーザーロール" (start/stop requires streamer role, chat requires user role)
- WebSocket: No authentication mechanism documented

**Impact**:
- WebSocket security implementation may differ from REST API patterns
- Role checking may be inconsistent (some endpoints use annotations, others manual checks)
- Authentication token handling in WebSocket handshake may not follow existing patterns

**Recommendation**:
1. Document existing authentication filter/interceptor chain
2. Specify exact authentication pattern for WebSocket connections
3. Document existing authorization annotation patterns and apply consistently
4. Verify whether existing system has any stateful connection authentication patterns

---

**S3. Logging Format Specification Without Codebase Validation**

**Location**: Section 6 (Implementation Policies - Logging)

**Issue**: Design specifies a structured logging format:
```
[LEVEL] [YYYY-MM-DD HH:MM:SS] [ClassName.methodName] - Log message (key1=value1, key2=value2)
```

**Evidence Absent**:
- Existing logging framework (Logback, Log4j2, slf4j implementation)
- Existing log format pattern configuration
- Whether existing system uses structured logging (JSON logs, key-value pairs)
- Existing MDC (Mapped Diagnostic Context) usage patterns

**Pattern Verification Needed**:
- Does existing system use bracket-delimited fields or JSON?
- Are class and method names logged automatically via pattern or manually inserted?
- Is structured data logged as `key=value` or as JSON fields?
- What log levels are used for what purposes?

**Impact**:
- Log aggregation/parsing tools may not handle mixed formats correctly
- Developers must remember different logging patterns for different modules
- Log analysis becomes difficult with inconsistent structure
- Monitoring alerts may not trigger correctly on new log formats

**Recommendation**:
1. Review existing logging configuration (logback.xml, log4j2.xml)
2. Extract exact log pattern format from existing configuration
3. Align new logging format to match existing pattern exactly
4. If changing format, document rationale and update log parsing infrastructure

---

**S4. File Placement Conventions Not Documented**

**Location**: Throughout (Component Names)

**Issue**: The design lists component names (`LiveStreamController`, `ChatWebSocketHandler`, `LiveStreamService`, etc.) but does not specify:
- Package structure (e.g., `com.example.stream.controller` vs `com.example.controller.stream`)
- Whether existing system uses domain-based packaging or layer-based packaging
- Where WebSocket handlers are placed relative to REST controllers
- Naming conventions for related files (DTOs, request/response objects)

**Evidence Absent**:
- Existing package structure from any existing controller/service
- File organization pattern (e.g., feature folders vs layer folders)
- Co-location patterns (are tests next to source or in separate tree?)

**Pattern Verification Needed**:
- Does existing system use `com.example.{layer}.{domain}` or `com.example.{domain}.{layer}`?
- Are related classes grouped by feature or by technical role?
- Where do configuration classes live?

**Impact**:
- Developers may place new files inconsistently
- Import statements may become long and unorganized
- Package-level visibility controls may not work as intended
- IDE navigation becomes difficult with inconsistent structure

**Recommendation**:
1. Document existing package structure from at least 2-3 existing features
2. Specify exact package paths for all new components
3. Document any package structure changes with rationale
4. Define naming conventions for supporting classes (DTOs, mappers, validators)

---

#### MODERATE INCONSISTENCIES

**M1. Technology Stack Alignment Not Justified**

**Location**: Section 2 (Technology Stack)

**Issue**: Lists technology choices (RabbitMQ, Redis, Spring WebClient, MapStruct) without documenting:
- Whether these libraries are already used in the existing system
- If new libraries, why they were chosen over existing alternatives
- Version compatibility with existing dependencies
- Whether existing system uses different libraries for same purposes

**Evidence Absent**:
- Existing dependency management file (pom.xml, build.gradle)
- Existing message queue solution (if any)
- Existing HTTP client (RestTemplate, WebClient, OkHttp)
- Existing DTO mapping approach (manual, MapStruct, ModelMapper)

**Pattern Verification Needed**:
- If existing system uses Kafka, why introduce RabbitMQ?
- If existing system uses RestTemplate, why introduce WebClient?
- Are library versions compatible with existing Spring Boot version?

**Impact**:
- Multiple libraries serving the same purpose increase maintenance burden
- Different teams may use different tools for the same job
- Dependency conflicts may arise during integration
- Learning curve increases for developers switching between modules

**Recommendation**:
1. Document existing messaging/queue solution
2. Document existing HTTP client library
3. If introducing new libraries, justify choice and document migration plan
4. Ensure version compatibility with existing Spring Boot version

---

**M2. Test Strategy Not Aligned with Existing Practices**

**Location**: Section 6 (Implementation Policies - Testing)

**Issue**: Lists test tools (JUnit 5, Mockito, TestContainers, Playwright) without documenting:
- What test frameworks are currently used in the existing codebase
- Whether existing tests use JUnit 4 or JUnit 5
- What existing integration test approach is (in-memory DB, TestContainers, test environment)
- Whether existing E2E tests use Playwright or other tools (Selenium, Cypress)

**Evidence Absent**:
- Existing test file structure and naming conventions
- Existing test base classes or test utilities
- Existing test data management approach
- Existing CI/CD test execution strategy

**Pattern Verification Needed**:
- If existing system uses JUnit 4, migrating to JUnit 5 requires annotation changes
- If existing system uses H2 for integration tests, introducing TestContainers changes test execution time
- If existing system uses Selenium, introducing Playwright fragments E2E test infrastructure

**Impact**:
- Developers must learn multiple test frameworks
- Test execution time may increase inconsistently
- CI/CD pipelines may need updates to support new test infrastructure
- Test patterns become inconsistent across modules

**Recommendation**:
1. Document existing test framework versions and patterns
2. Align test tools with existing testing infrastructure
3. If introducing new test tools, document rationale and provide migration guide
4. Ensure test naming and organization matches existing patterns

---

**M3. Deployment Strategy Not Verified Against Existing Process**

**Location**: Section 6 (Implementation Policies - Deployment)

**Issue**: Specifies "Blue-Green deployment" for production without documenting:
- What deployment strategy the existing system uses
- Whether existing infrastructure supports Blue-Green deployment
- Whether existing deployment is managed by Kubernetes, or different orchestration
- How database migrations are handled in existing deployments

**Evidence Absent**:
- Existing Kubernetes manifests or Helm charts
- Existing deployment pipeline configuration
- Existing rollback procedures
- Existing environment management (dev, staging, production)

**Pattern Verification Needed**:
- If existing system uses Rolling Update, introducing Blue-Green requires infrastructure changes
- If existing system is not on Kubernetes, this represents major infrastructure change
- Database migration strategy must align with existing schema evolution approach

**Impact**:
- Infrastructure team must support multiple deployment strategies
- Rollback procedures become inconsistent
- Deployment automation cannot be shared across features
- Production deployment risk increases with inconsistent processes

**Recommendation**:
1. Document existing deployment strategy and tools
2. Align new feature deployment to existing approach
3. If changing deployment strategy, document infrastructure changes required
4. Document database migration strategy alignment with existing approach

---

### Pattern Evidence

**Note**: This review was conducted in an experimental repository without actual codebase files. In a real consistency review, this section would include:

- Specific file paths and line numbers showing existing patterns
- Code snippets demonstrating naming conventions
- Configuration file excerpts showing format decisions
- SQL schema excerpts showing table/column naming patterns
- Test file examples showing test framework usage

**Attempted Codebase Search**:
- Searched for `.java`, `.ts`, `.tsx`, `.sql`, `pom.xml`, `package.json` files
- No application code found in repository
- Repository appears to be for prompt engineering experiments

**Consequence**: All inconsistencies identified are based on:
1. Internal inconsistencies within the design document itself
2. Absence of documented alignment with "existing system"
3. Missing justification for technology and pattern choices

---

### Impact Analysis

#### Critical Impact (C1, C2, C3)

**Database Schema Fragmentation (C1)**:
- Immediate impact on all database access code
- Affects ORM mapping configuration complexity
- Creates inconsistent developer experience across tables
- Difficult to remediate post-deployment (requires schema migration)

**Architectural Ambiguity (C2)**:
- Blocks accurate implementation of WebSocket layer
- Creates risk of parallel architecture patterns (REST vs WebSocket)
- Future WebSocket features lack clear guidance
- Code review cannot validate architectural alignment

**Error Handling Duplication (C3)**:
- May result in duplicated error handling code if misaligned with existing pattern
- Risk of inconsistent error responses to API consumers
- Maintenance burden increases with scattered error handling logic

#### Significant Impact (S1, S2, S3, S4)

**API Consumer Confusion (S1)**: Frontend must handle multiple response formats, error handling cannot be centralized

**Security Implementation Risk (S2)**: WebSocket authentication may be implemented differently from REST, creating security gaps

**Observability Degradation (S3)**: Mixed log formats break log aggregation and monitoring

**Code Organization Confusion (S4)**: Inconsistent file placement increases onboarding time and reduces navigability

#### Moderate Impact (M1, M2, M3)

**Dependency Bloat (M1)**: Multiple libraries for same purpose increase bundle size and complexity

**Test Infrastructure Fragmentation (M2)**: Slows down test execution and CI/CD pipelines

**Deployment Process Divergence (M3)**: Increases operational complexity and deployment risk

---

### Recommendations

#### Immediate Actions Required (Before Implementation)

1. **Document Existing Patterns**: Create a "Consistency Checklist" section in the design document that explicitly documents:
   - Existing database naming convention with 3 examples
   - Existing error handling pattern with code reference
   - Existing API response format with example
   - Existing logging format from configuration file
   - Existing package structure from 2 features

2. **Resolve Critical Inconsistencies**:
   - Standardize all database table and column names (C1)
   - Document WebSocket architectural fit (C2)
   - Verify and document error handling pattern (C3)

3. **Validate Technology Choices**:
   - Verify all libraries in technology stack are already in use or document introduction rationale
   - Check version compatibility with existing Spring Boot version
   - Document any new library additions in architecture decision record

#### Design Document Improvements

1. **Add "Alignment with Existing System" Section**:
   - List existing patterns being followed
   - List deviations with rationale
   - Include references to existing code examples

2. **Add "Pattern References" to Each Section**:
   - Naming: "Following pattern in `User` and `Content` tables"
   - Error Handling: "Following pattern in `UserController` line 45-60"
   - Logging: "Following pattern in `logback.xml` line 12"

3. **Document Decision Rationale**:
   - Why RabbitMQ vs existing message queue?
   - Why Blue-Green vs existing deployment strategy?
   - Why these specific Spring Boot libraries?

#### Verification Process

Before development starts:
1. Run database schema query to extract existing table/column naming patterns
2. Grep for `@ControllerAdvice` and `@ExceptionHandler` to verify error handling pattern
3. Review existing `pom.xml` or `build.gradle` to verify dependency alignment
4. Check existing `logback.xml` or `log4j2.xml` to verify logging format
5. Review existing controller packages to verify package structure pattern

---

## Positive Alignment Aspects

Despite the consistency issues identified, the design document demonstrates strengths in:

1. **Layered Architecture Awareness**: Explicitly states intention to follow existing 3-layer structure
2. **Technology Stack Clarity**: Clearly lists all technologies (though alignment not verified)
3. **Comprehensive Coverage**: Includes all necessary sections for a complete design document
4. **Specific Examples**: Provides concrete SQL schemas and API examples (though internally inconsistent)

---

## Review Summary

**Total Inconsistencies Identified**: 10
- Critical: 3 (C1, C2, C3)
- Significant: 4 (S1, S2, S3, S4)
- Moderate: 3 (M1, M2, M3)

**Primary Root Cause**: Design document lacks explicit documentation of existing codebase patterns and verification evidence for alignment claims.

**Key Recommendation**: Before implementation, create a "Consistency Validation Checklist" that documents existing patterns with specific code references, then update design document to explicitly show alignment or justified deviation for each pattern.

**Estimated Remediation Effort**:
- Critical inconsistencies: 4-8 hours (research existing patterns + update design)
- Significant inconsistencies: 2-4 hours (document existing patterns)
- Moderate inconsistencies: 1-2 hours (verify tool versions)

**Review Confidence**: Medium (identified internal inconsistencies confidently, but cannot verify external consistency without codebase access)
