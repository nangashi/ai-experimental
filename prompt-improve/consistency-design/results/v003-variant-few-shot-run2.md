# Consistency Design Review: リアルタイム配信プラットフォーム

## Analysis Process Summary

### Stage 1: Overall Structure Analysis
The design document contains 7 main sections covering system overview, technology stack, architecture, data models, API design, implementation policies, and non-functional requirements. The document provides comprehensive information about proposed technical approaches and architectural patterns.

### Stage 2: Section-by-Section Detail Analysis
Identified multiple inconsistencies across naming conventions (database table names, API response formats), architectural patterns (error handling, logging), implementation patterns (error handling strategy), and directory structure (not explicitly documented).

### Stage 3: Cross-Cutting Issue Detection
Systematic naming convention inconsistencies span multiple categories (database tables, API responses). Implementation pattern documentation is incomplete across all technical approach sections.

---

## Inconsistencies Identified

### [CRITICAL] Database Table Naming Convention Inconsistency

**Proposed Pattern**: Mixed naming conventions across tables
- `live_stream` table: snake_case (columns: `stream_id`, `streamer_user_id`, `stream_title`)
- `ChatMessage` table: PascalCase (columns: `messageId`, `streamId`, `messageText` - camelCase)
- `viewer_sessions` table: snake_case (columns: `session_id`, `stream_id`, `user_id`)

**Existing Pattern**: Unable to verify without codebase access, but the document itself shows internal inconsistency, indicating likely divergence from existing standards.

**Pattern Evidence Required**:
- Need to examine existing database schema files (e.g., `src/main/resources/db/migration/*.sql` or similar)
- Need to verify Entity class naming conventions (e.g., `src/main/java/*/entity/*.java`)
- Need to check JPA/Hibernate column naming strategy configuration

**Impact Analysis**:
- Mixed naming conventions create confusion for developers writing queries and Entity mappings
- Increases risk of naming errors when joining tables or writing native queries
- Makes automated schema migration tools harder to configure consistently
- Violates principle of least surprise for database operations

**Recommendations**:
1. Standardize all table names to snake_case: `live_stream`, `chat_message`, `viewer_sessions`
2. Standardize all column names to snake_case: `message_id`, `stream_id`, `user_id`, `message_text`, `sent_at`, `is_deleted`
3. Document database naming convention explicitly in Section 4 (Data Model)
4. Verify alignment with existing Entity classes and JPA naming strategy

---

### [CRITICAL] Error Handling Pattern Divergence

**Proposed Pattern**: Manual try-catch blocks in Controller layer
- Design states: "Controller層の個別 catch ブロックで処理する" (Process in individual catch blocks in Controller layer)
- Service layer throws `BusinessException`
- Controller layer catches and handles exceptions individually

**Existing Pattern Verification Needed**:
- Need to examine existing Controller classes for error handling approach
- Need to check for global exception handler (e.g., `@ControllerAdvice` or `@ExceptionHandler` classes)
- Need to verify existing Service exception throwing patterns

**Impact Analysis**:
- If existing codebase uses centralized exception handling (common in Spring Boot applications), this creates fragmentation
- Duplicates error response formatting logic across multiple Controller methods
- Reduces maintainability when error response format needs updates
- Inconsistent error handling makes debugging more difficult

**Recommendations**:
1. Search for existing error handling patterns: `@ControllerAdvice`, `@ExceptionHandler`, `GlobalExceptionHandler`
2. If centralized pattern exists, align with it and document in Section 6
3. If manual pattern exists, verify consistency with proposed approach
4. Document specific exceptions that require method-level handling with rationale

---

### [SIGNIFICANT] API Response Format Inconsistency

**Proposed Pattern**: Custom wrapper format with `success` flag
```json
{
  "success": true/false,
  "stream": {...},
  "error": {...}
}
```

**Existing Pattern Verification Needed**:
- Need to examine existing REST API response formats in related modules
- Need to check for common response wrapper classes (e.g., `ApiResponse<T>`, `ResponseEntity` usage patterns)
- Need to verify error response format standards

**Pattern Evidence Required**:
- Examine existing Controller response formats (e.g., `src/main/java/*/controller/*.java`)
- Check for DTO classes defining response structures
- Review API documentation or OpenAPI specs for established patterns

**Impact Analysis**:
- If existing APIs use different wrapper format (or no wrapper), creates frontend integration complexity
- Mixed response formats require frontend to handle multiple parsing strategies
- Increases cognitive load for API consumers
- May break existing frontend error handling logic

**Recommendations**:
1. Search for existing API response patterns across all Controllers
2. Identify dominant wrapper format (if any) used in 70%+ of endpoints
3. Align proposed format with existing pattern
4. Document response format convention explicitly in Section 5 (API Design)

---

### [SIGNIFICANT] Logging Format Pattern Verification Required

**Proposed Pattern**: Custom structured format
```
[LEVEL] [YYYY-MM-DD HH:MM:SS] [ClassName.methodName] - Log message (key1=value1, key2=value2)
```

**Existing Pattern Verification Needed**:
- Need to examine existing logging configuration (e.g., `logback.xml`, `log4j2.xml`)
- Need to check existing Service/Controller log statements for format patterns
- Need to verify if structured logging framework is in use (e.g., Logstash, Logback structured logging)

**Pattern Evidence Required**:
- Review logging configuration files in `src/main/resources/`
- Examine existing log statements in similar Service classes
- Check for logging utility classes or helper methods

**Impact Analysis**:
- Custom format conflicts with existing logging infrastructure may break log aggregation
- Inconsistent log formats complicate centralized logging analysis
- May duplicate timestamp information if logging framework already adds it
- Manual formatting reduces maintainability

**Recommendations**:
1. Locate and review existing logging configuration files
2. Examine actual log output from existing services
3. Align with established logging framework configuration
4. If structured logging exists, use provided mechanisms instead of manual formatting
5. Document logging convention with reference to configuration file

---

### [MODERATE] Directory Structure & File Placement Not Documented

**Missing Information**: The design document does not specify proposed file/package placement for new components:
- Where will `LiveStreamController`, `ChatWebSocketHandler` be placed?
- What package structure will Service classes follow?
- Where will Repository interfaces reside?
- How will WebSocket configuration classes be organized?

**Existing Pattern Verification Needed**:
- Need to examine existing package organization (domain-based vs layer-based)
- Example: `com.example.user.controller` vs `com.example.controller.user`
- Need to verify WebSocket-related file placement patterns (if any)

**Impact Analysis**:
- Without explicit file placement, implementation may diverge from established conventions
- Inconsistent organization increases onboarding friction
- IDE navigation patterns become unpredictable

**Recommendations**:
1. Search for existing Controller, Service, Repository package patterns
2. Identify dominant organization strategy (e.g., `src/main/java/com/example/{domain}/{layer}/` vs `src/main/java/com/example/{layer}/{domain}/`)
3. Add explicit "Project Structure" subsection to Section 6 documenting proposed file placement
4. Example format:
   ```
   src/main/java/com/example/
     livestream/
       controller/LiveStreamController.java
       service/LiveStreamService.java
       repository/LiveStreamRepository.java
   ```

---

### [MODERATE] WebSocket Configuration Pattern Not Documented

**Missing Information**: Design specifies "Spring WebSocket" but does not document:
- WebSocket endpoint registration approach
- Message broker configuration (STOMP vs raw WebSocket)
- Session management strategy
- Connection lifecycle handling

**Existing Pattern Verification Needed**:
- Check if existing codebase has WebSocket implementations
- If exists, verify configuration pattern (annotation-based vs programmatic)
- Check for existing WebSocket handler base classes or patterns

**Impact Analysis**:
- WebSocket configuration pattern affects overall architecture consistency
- Inconsistent approaches create maintenance burden
- May conflict with existing real-time communication patterns

**Recommendations**:
1. Search for existing WebSocket configurations: `@EnableWebSocket`, `WebSocketConfigurer`, `WebSocketHandler`
2. If no existing pattern, document proposed configuration approach explicitly
3. If existing pattern found, align with it and reference in Section 3 (Architecture Design)
4. Document WebSocket endpoint naming convention (e.g., `/ws/chat` vs `/websocket/chat`)

---

### [MODERATE] Dependency Injection & Configuration Pattern Not Specified

**Missing Information**: Design does not specify:
- Constructor vs field injection preference
- Configuration class organization (`@Configuration` placement)
- Bean naming conventions
- Profile-specific configuration approach

**Existing Pattern Verification Needed**:
- Examine existing Service/Controller classes for injection patterns
- Check for dominant injection style (constructor injection is Spring best practice)
- Verify configuration class organization patterns

**Impact Analysis**:
- Inconsistent DI patterns reduce code readability
- Mixed injection styles complicate testing
- Configuration organization affects maintainability

**Recommendations**:
1. Search for existing injection patterns in Service/Controller classes
2. Identify dominant pattern (70%+ usage)
3. Document preferred injection style in Section 6 (Implementation Policy)
4. Add configuration organization guidelines

---

## Positive Alignment Aspects

### Technology Stack Consistency
- Uses Spring Boot 3.2, aligning with modern Java enterprise standards
- PostgreSQL, Redis, RabbitMQ are common choices indicating likely alignment with existing infrastructure

### Layered Architecture
- 3-layer architecture (Presentation, Business, Data Access) follows standard Spring Boot patterns
- Clear responsibility separation is documented

### Testing Strategy
- Multi-level testing approach (unit, integration, E2E) indicates maturity
- TestContainers usage shows awareness of modern testing practices

---

## Critical Action Items

Before implementation, the following verifications are **mandatory** to ensure consistency:

1. **[HIGH PRIORITY]** Verify database naming conventions by examining existing schema files and Entity classes
2. **[HIGH PRIORITY]** Verify error handling pattern by searching for `@ControllerAdvice` or global exception handlers
3. **[HIGH PRIORITY]** Verify API response format by examining existing Controller response structures
4. **[MEDIUM PRIORITY]** Verify logging configuration by reviewing `logback.xml` or similar configuration files
5. **[MEDIUM PRIORITY]** Document directory structure and file placement explicitly in design document
6. **[MEDIUM PRIORITY]** Verify WebSocket configuration patterns if any exist in codebase

---

## Summary

This design document demonstrates good coverage of technical requirements but contains several critical consistency gaps requiring verification against existing codebase patterns. The most severe issues are:

1. **Internal inconsistency** in database naming (mixing snake_case and camelCase)
2. **Unverified alignment** with existing error handling, API response, and logging patterns
3. **Missing documentation** of file placement and configuration patterns

**Recommendation**: Before proceeding with implementation, conduct a comprehensive codebase pattern analysis using the verification steps outlined above, then update Section 6 (Implementation Policy) with explicit pattern alignment documentation.
