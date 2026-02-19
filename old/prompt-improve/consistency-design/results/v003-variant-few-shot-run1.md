# Consistency Design Review: リアルタイム配信プラットフォーム

## Analysis Process Summary

### Stage 1: Overall Structure Analysis
The design document contains comprehensive sections covering overview, tech stack, architecture, data models, API design, implementation policies, and non-functional requirements. Key observations:
- Data model definitions present (Section 4)
- API endpoint specifications present (Section 5)
- Implementation policies specified (Section 6)
- File placement/directory structure not explicitly documented
- Library version and configuration format details partially documented

### Stage 2: Section-by-Section Detail Analysis
Conducted detailed analysis of naming conventions (API endpoints, database tables/columns), architecture patterns (layer composition, error handling), implementation patterns (WebSocket handling, logging), and API design consistency against typical Spring Boot + React codebase patterns.

### Stage 3: Cross-Cutting Issue Detection
Identified systematic inconsistencies spanning multiple sections: mixed naming conventions across database tables, inconsistent error handling pattern specification, and missing directory structure documentation.

---

## Inconsistencies Identified

### [CRITICAL] Database Table Naming Convention Inconsistency

**Issue**: The design proposes three database tables with mixed naming conventions:
- `live_stream`: snake_case (table and all columns)
- `ChatMessage`: PascalCase table name with camelCase columns (`messageId`, `streamId`, `userId`, `messageText`, `sentAt`, `isDeleted`)
- `viewer_sessions`: snake_case (table and all columns)

**Expected Pattern**: Spring Boot projects with PostgreSQL typically follow snake_case for all database identifiers (tables and columns) to align with SQL conventions and avoid case-sensitivity issues.

**Pattern Evidence**:
Without access to the existing codebase, typical Spring Boot + PostgreSQL projects follow these patterns:
- Database: snake_case for tables/columns (`user_accounts`, `order_items`, `created_at`)
- Entity Classes: PascalCase class names with camelCase properties mapped via `@Column(name = "snake_case")`
- Standard convention: JPA naming strategy (`SpringPhysicalNamingStrategy`) automatically converts camelCase to snake_case

**Impact Analysis**:
- The `ChatMessage` table with camelCase columns will create inconsistency in SQL queries and schema management
- Mixed conventions require developers to remember different naming rules for different tables
- ORM mapping complexity increases when conventions are not uniform
- Schema migration scripts become error-prone with mixed case styles

**Recommendations**:
1. Change `ChatMessage` table definition to snake_case:
   ```sql
   CREATE TABLE chat_message (
       message_id BIGSERIAL PRIMARY KEY,
       stream_id BIGINT NOT NULL,
       user_id BIGINT NOT NULL,
       message_text TEXT NOT NULL,
       sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
       is_deleted BOOLEAN DEFAULT FALSE
   );
   ```
2. Document the database naming convention explicitly: "All database tables and columns use snake_case to align with PostgreSQL conventions"
3. Specify JPA naming strategy in design document: "Use `SpringPhysicalNamingStrategy` for automatic camelCase to snake_case conversion"

---

### [SIGNIFICANT] Error Handling Pattern Inconsistency

**Issue**: The design specifies manual try-catch error handling in Controller layer: "Controller層の個別 catch ブロックで処理する" (Process in individual catch blocks at Controller layer). This approach contrasts with typical Spring Boot error handling patterns.

**Expected Pattern**: Spring Boot projects commonly use centralized error handling via `@ControllerAdvice` and `@ExceptionHandler` to:
- Centralize error response formatting
- Apply consistent error logging
- Reduce boilerplate code in controllers
- Ensure uniform error response structure across all endpoints

**Pattern Evidence**:
Standard Spring Boot error handling pattern:
```java
@ControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(BusinessException ex) {
        // Centralized error formatting and logging
    }
}
```

Typical existing codebase would have:
- `src/main/java/com/example/exception/GlobalExceptionHandler.java`
- Controllers remain clean without try-catch blocks
- 90%+ of error handling logic centralized

**Impact Analysis**:
- Duplicates error formatting logic across 7+ controller endpoints (POST/GET/PATCH/DELETE streams, GET chat-messages, etc.)
- Inconsistent error response formats if each controller implements catch blocks differently
- Maintenance burden: changing error response structure requires updating all controller catch blocks
- Higher risk of missing error cases in individual controllers

**Recommendations**:
1. Adopt `@ControllerAdvice` pattern for centralized error handling:
   - Create `GlobalExceptionHandler` class with `@ControllerAdvice` annotation
   - Define `@ExceptionHandler` methods for `BusinessException` and technical exceptions
   - Let controllers throw exceptions naturally without try-catch blocks
2. Update design document Section 6 error handling policy: "業務例外と技術例外は`@ControllerAdvice`で一元的にハンドリングし、統一的なエラーレスポンス形式で返却する"
3. Document exception-specific handling: "個別のエラー処理が必要な場合のみ、Controller メソッドで try-catch を使用し、その理由を明記する"

---

### [SIGNIFICANT] API Response Format Inconsistency Concern

**Issue**: The design proposes a custom wrapper response format with `success` boolean field:
```json
{
  "success": true,
  "stream": { ... }
}
```

**Typical Spring Boot Pattern**: Most Spring Boot REST APIs follow one of these conventions:
1. **Unwrapped resource responses**: Return the resource object directly (status code indicates success/failure)
   ```json
   { "streamId": 98765, "title": "...", "status": "ACTIVE" }
   ```
2. **Spring HATEOAS**: Use standard hypermedia formats
3. **Problem Details (RFC 7807)**: Use standardized error format for failures

**Verification Required**: This requires checking existing API endpoints in the codebase to determine the actual pattern:
- If existing APIs use unwrapped resources → This design is inconsistent
- If existing APIs use wrapper format → This design is consistent

**Impact Analysis** (if inconsistent):
- Mixed response formats force frontend developers to handle different parsing logic
- Inconsistent success/error detection patterns across API calls
- Cannot leverage standard HTTP status codes effectively

**Recommendations**:
1. **Priority Action**: Verify existing API response format by checking:
   - `src/main/java/com/example/controller/*.java` (existing controllers)
   - API documentation or OpenAPI specs
   - Frontend API client code patterns
2. **If existing APIs use unwrapped format**: Align this design to remove wrapper:
   - Success case: Return resource directly with 2xx status codes
   - Error case: Use `@ControllerAdvice` to return consistent error format with 4xx/5xx status codes
3. **Document the decision**: Add "API Response Format Convention" section specifying the standard format and rationale

---

### [MODERATE] Missing Directory Structure Documentation

**Issue**: The design document does not specify file placement and package structure for the new components. While Section 3 names the components (`LiveStreamController`, `ChatWebSocketHandler`, `LiveStreamService`, etc.), it does not document where these files should be placed.

**Expected Documentation**: Design documents should explicitly specify:
- Package structure (e.g., `com.example.streaming.controller`, `com.example.streaming.service`)
- File organization pattern (layer-based vs feature-based)
- Alignment with existing modules

**Typical Spring Boot Patterns**:
- **Layer-based**: `src/main/java/com/example/[layer]/[Feature][Layer].java`
  - `controller/LiveStreamController.java`
  - `service/LiveStreamService.java`
  - `repository/LiveStreamRepository.java`
- **Feature-based**: `src/main/java/com/example/[feature]/[Layer][Feature].java`
  - `streaming/controller/LiveStreamController.java`
  - `streaming/service/LiveStreamService.java`
  - `streaming/repository/LiveStreamRepository.java`

**Impact Analysis**:
- Implementation teams may place files inconsistently with existing codebase structure
- Code review friction increases when file placement doesn't match expectations
- IDE navigation and search patterns become unpredictable
- Future refactoring requires moving files to align structure

**Recommendations**:
1. Add "6.5 Directory Structure & Package Organization" section specifying:
   - Root package name
   - Organization pattern (layer-based or feature-based)
   - Specific package names for each component
2. Verify alignment with existing codebase organization:
   - Check existing feature modules (user, content, etc.)
   - Adopt the dominant pattern (layer-based vs feature-based)
3. Example documentation:
   ```
   ## Directory Structure
   This module follows layer-based organization consistent with existing modules:
   - `com.example.streaming.controller` - REST controllers and WebSocket handlers
   - `com.example.streaming.service` - Business logic services
   - `com.example.streaming.repository` - Data access repositories
   - `com.example.streaming.domain` - Domain models and entities
   ```

---

### [MODERATE] Logging Format Pattern Undocumented

**Issue**: The design specifies a custom logging format in Section 6:
```
[LEVEL] [YYYY-MM-DD HH:MM:SS] [ClassName.methodName] - Log message (key1=value1, key2=value2)
```

**Verification Required**: This requires checking existing logging configuration to determine the actual pattern:
- Log format configuration (logback.xml or log4j2.xml)
- Structured logging library usage (Logstash Logback Encoder, etc.)
- Existing log output examples

**Typical Spring Boot Logging Patterns**:
1. **Default Spring Boot format**: `2026-02-11 10:00:00.123 INFO 12345 --- [main] com.example.ClassName : Log message`
2. **Structured JSON logging**: `{"timestamp":"2026-02-11T10:00:00Z","level":"INFO","class":"ClassName","message":"..."}`
3. **Custom format with MDC**: Varies by project

**Impact Analysis** (if inconsistent):
- Mixed log formats complicate log aggregation and parsing
- Log analysis tools may fail to parse custom format
- Developers must remember different logging conventions

**Recommendations**:
1. **Priority Action**: Verify existing logging configuration:
   - Check `src/main/resources/logback-spring.xml` or equivalent
   - Review existing service classes for logging patterns
   - Check if structured logging (JSON) is used for production
2. **If existing format differs**: Align with existing pattern and document it
3. **Document structured logging guidelines**: Specify when to use structured fields (key=value pairs) vs plain messages
4. Add reference to logging configuration file in design document

---

### [MINOR] WebSocket Library Selection Rationale Missing

**Issue**: The design specifies "Spring WebSocket" as the WebSocket library (Section 2) but does not document why this was chosen over alternatives.

**Context**: For Spring Boot WebSocket implementations, teams typically choose between:
1. **Spring WebSocket + STOMP**: Higher-level protocol with pub/sub support
2. **Raw Spring WebSocket**: Lower-level control, manual message routing
3. **Third-party libraries**: Socket.IO, etc.

**Verification Required**: Check existing real-time communication implementations to determine:
- Whether STOMP protocol is used codebase-wide
- Whether raw WebSocket is the established pattern
- Configuration patterns in existing WebSocket endpoints

**Impact Analysis**:
- If existing codebase uses STOMP protocol but design uses raw WebSocket, clients must handle different connection patterns
- Inconsistent message routing patterns increase maintenance complexity
- Switching between STOMP and raw WebSocket requires significant refactoring

**Recommendations**:
1. Verify existing WebSocket usage:
   - Search for `@EnableWebSocketMessageBroker` (STOMP) vs `@EnableWebSocket` (raw)
   - Check if message broker (RabbitMQ, Redis) is integrated with WebSocket
2. Document the decision with rationale: "Spring WebSocket (raw) is used to align with existing chat implementation in [module name]. STOMP protocol was not adopted because [reason]."
3. If STOMP is the existing pattern: Consider migrating this design to use STOMP for consistency

---

### [MINOR] Configuration File Format Not Specified

**Issue**: The design references multiple external services (RabbitMQ, Redis, AWS MediaLive) but does not specify the configuration file format or location.

**Typical Spring Boot Patterns**:
- `application.yml` or `application.properties` for configuration
- Profile-specific files: `application-dev.yml`, `application-prod.yml`
- External configuration: ConfigMap (Kubernetes), AWS Parameter Store, etc.

**Verification Required**: Check existing configuration patterns:
- YAML vs Properties format preference
- Environment-specific configuration approach
- Secret management patterns

**Impact Analysis**:
- Inconsistent configuration formats require different parsing logic
- Mixed environment variable naming conventions (SCREAMING_SNAKE_CASE vs spring.config.style)

**Recommendations**:
1. Add "Configuration Management" subsection in Section 6 specifying:
   - Configuration file format (YAML or Properties)
   - Environment-specific configuration approach
   - Secret management (Kubernetes Secrets, AWS Secrets Manager, etc.)
2. Document environment variable naming convention
3. Example: "Configuration follows existing pattern: application.yml for defaults, environment-specific overrides in application-{profile}.yml, secrets managed via Kubernetes Secrets"

---

## Positive Consistency Alignments

### Architecture Layer Composition
The design correctly adopts the existing 3-layer architecture (Presentation, Business, Data Access) as stated: "既存システムのレイヤー構成に従い、以下の3層で構成する". This demonstrates proper alignment with established architectural patterns.

### Authentication Pattern
The design references existing JWT authentication: "既存のJWT認証を使用する" (Section 5). This shows appropriate reuse of established security mechanisms rather than introducing new authentication approaches.

### Testing Framework Alignment
The design specifies JUnit 5 + Mockito for unit testing and TestContainers for integration testing (Section 6), which are standard choices for modern Spring Boot projects and likely align with existing test infrastructure.

### Technology Stack Consistency
The design uses Spring Boot 3.2 and Java 17, which suggests alignment with the existing technology stack baseline (referenced as "既存のコンテンツ配信システムに追加する形で").

---

## Summary of Findings

**Critical Issues**: 1
- Database table naming convention inconsistency (snake_case vs camelCase columns)

**Significant Issues**: 2
- Error handling pattern (individual catch blocks vs @ControllerAdvice)
- API response format wrapper (requires verification against existing APIs)

**Moderate Issues**: 2
- Missing directory structure documentation
- Logging format pattern (requires verification)

**Minor Issues**: 2
- WebSocket library selection rationale missing
- Configuration file format not specified

**Positive Alignments**: 4
- Architecture layer composition
- Authentication pattern reuse
- Testing framework selection
- Technology stack baseline

**Priority Recommendations**:
1. **Immediate**: Fix database naming convention to snake_case across all tables
2. **High**: Verify and align error handling pattern (adopt @ControllerAdvice)
3. **High**: Verify and align API response format with existing endpoints
4. **Medium**: Document directory structure and package organization
5. **Medium**: Verify and document logging format pattern
6. **Low**: Document WebSocket and configuration management decisions

**Next Steps**:
To complete consistency verification, the following codebase elements should be examined:
1. Existing database schema files (migrations, entity classes)
2. Existing controller implementations (error handling, response formats)
3. Existing API response examples (OpenAPI specs, integration tests)
4. Logging configuration files (logback.xml)
5. Package structure of existing feature modules
