# Consistency Design Review: v002-variant-detection-hints-run1

## Inconsistencies Identified

### CRITICAL: Architecture Pattern Fragmentation

**Issue**: Individual token validation in controller methods (Section 5, Line 181-182)
- Design states: "トークンの検証は各コントローラーメソッド内で個別に実装する"
- This introduces architectural fragmentation compared to established Spring Security patterns
- **Severity**: Critical - Creates maintenance burden across all API endpoints

**Issue**: Individual error handling in controller methods (Section 6, Line 186)
- Design states: "各コントローラーメソッド内でtry-catchブロックを使用し、例外を個別にハンドリングする"
- Contradicts Spring Boot's global exception handler pattern (@ControllerAdvice)
- **Severity**: Critical - Duplicates error handling logic across controllers

### SIGNIFICANT: Naming Convention Inconsistencies

**Issue**: Mixed naming conventions in database columns
- camelCase: `customerId`, `locationId`, `staffId`, `reservationDateTime`, `durationMinutes`
- snake_case expected pattern not documented
- **Pattern Gap**: Design document lacks explicit database naming convention specification

**Issue**: Inconsistent naming patterns across entity fields
- Entity reference: `customerId` (camelCase with "Id" suffix)
- Other fields: `firstName`, `lastName` (camelCase)
- Table name fields: `locationName`, `staffName`, `phoneNumber` (camelCase with descriptive suffix)
- **Missing Documentation**: No rationale for when to use descriptive suffixes vs. abbreviated forms

### SIGNIFICANT: API Design Consistency Gaps

**Issue**: Response format wrapper not aligned with RESTful conventions
- Proposed format includes top-level `status` field: `{"data": {...}, "status": "success"}`
- Standard REST pattern: HTTP status codes without redundant status fields
- **Missing Documentation**: No justification for wrapper format choice or comparison with existing API patterns

### MODERATE: Implementation Pattern Documentation Gaps

**Issue**: Missing data access pattern specification (Detection Category: Line 48)
- Design specifies "Spring Data JPA (Hibernate)" but lacks detail on:
  - Direct repository injection vs. repository abstraction layer
  - Transaction boundary definition strategy
  - Lazy/Eager loading policy

**Issue**: Missing HTTP client configuration details (Detection Category: Line 49)
- `RestTemplate` specified (Line 39) but lacks:
  - Connection pool configuration
  - Timeout settings
  - Error handling strategy for external API calls
  - Retry policy

**Issue**: Transaction management pattern not documented (Detection Category: Line 52)
- No specification of `@Transactional` boundary placement
- Service-level vs. repository-level transaction scope undefined

**Issue**: Asynchronous processing approach missing (Detection Category: Line 53)
- `NotificationService` (Line 64-65) implies async operations
- No documentation of async pattern: `@Async`, CompletableFuture, message queue
- Threading model undefined

### MODERATE: Directory Structure Not Specified

**Issue**: File placement policies missing
- No specification of package structure (domain-based vs. layer-based)
- Component organization within layers undefined
- Configuration file locations not documented

### MINOR: Logging Pattern Partial Specification

**Issue**: Log format specified but structured logging decision missing
- States "平文形式" (plain text format) but:
  - No specification of log message templates
  - Missing field ordering conventions
  - No guidance on contextual information inclusion (e.g., request IDs, user IDs)

## Pattern Evidence

### Spring Security Standard Pattern
**Dominant Pattern**: Spring Security filter chain with JWT authentication filter
- Authentication at infrastructure layer, not controller layer
- Configuration in security configuration class
- Reference: Spring Security documentation, Spring Boot security starters

### Global Exception Handling Pattern
**Dominant Pattern**: `@ControllerAdvice` with `@ExceptionHandler` methods
- Centralized error response formatting
- Separation of business logic from error handling concerns
- Reference: Spring Framework documentation on exception handling

### Database Naming Conventions
**Codebase Pattern Investigation Required**:
- Need to verify existing table definitions
- Check for snake_case vs. camelCase consistency in columns
- Examine existing entity-to-table mappings

### API Response Format
**Codebase Pattern Investigation Required**:
- Verify if existing APIs use response wrappers
- Check consistency of error response structures
- Determine if HTTP status codes alone are used or supplemented with body status fields

## Impact Analysis

### Authentication Fragmentation Impact
**Consequences**:
- Code duplication across 11+ controller methods (based on API endpoint count)
- Inconsistent token validation logic risk
- Higher maintenance cost when authentication logic changes
- Security vulnerability risk from implementation inconsistency

### Error Handling Fragmentation Impact
**Consequences**:
- Inconsistent error response formats across endpoints
- Duplicated try-catch blocks in every controller method
- Difficult to enforce uniform error logging
- Client integration complexity due to response format variations

### Naming Convention Impact
**Consequences**:
- Developer confusion when writing queries
- Inconsistent field references between Java entities and SQL
- Code review friction
- Potential ORM mapping issues

### Missing Pattern Documentation Impact
**Consequences**:
- Implementation phase ambiguity
- Developer-dependent pattern choices
- Inconsistent code submissions
- Higher code review cycle count

## Recommendations

### Immediate Alignment Required

**R1: Adopt Spring Security Filter-Based Authentication**
- Remove individual controller token validation
- Implement `JwtAuthenticationFilter` extending `OncePerRequestFilter`
- Configure filter in `SecurityConfig` class
- **Rationale**: Aligns with Spring Security architectural pattern, eliminates code duplication

**R2: Implement Global Exception Handler**
- Create `@ControllerAdvice` class with `@ExceptionHandler` methods
- Remove individual try-catch blocks from controllers
- Centralize error response formatting
- **Rationale**: Follows Spring Boot best practices, ensures consistent error responses

**R3: Document and Enforce Database Naming Convention**
- Explicitly specify: snake_case for columns, camelCase for Java fields
- Add `@Column(name = "customer_id")` annotations if needed
- Update table definitions in Section 4 to reflect chosen convention
- **Rationale**: Prevents implementation inconsistency, aligns with common database conventions

### Documentation Enhancement Required

**R4: Specify Data Access Pattern**
- Document transaction boundary placement (service-level recommended)
- Specify repository injection approach (direct vs. abstraction)
- Define lazy/eager loading policy
- **Rationale**: Ensures consistent data access implementation

**R5: Specify HTTP Client Configuration**
- Document RestTemplate configuration: connection pool, timeouts, retry policy
- Specify error handling strategy for external API calls
- Consider WebClient if reactive patterns are needed
- **Rationale**: Prevents network-related production issues

**R6: Specify Asynchronous Processing Pattern**
- Document notification service async implementation approach
- Choose: `@Async`, message queue (e.g., RabbitMQ), or synchronous with fast timeout
- Define threading pool configuration
- **Rationale**: Critical for notification reliability and performance

**R7: Document Directory Structure**
- Specify package organization: `com.company.reservation.{domain|layer}`
- Define file placement rules for controllers, services, repositories
- Document configuration file locations
- **Rationale**: Ensures codebase navigability and consistency

### Verification Required

**R8: Investigate Existing API Response Format**
- Check existing codebase for API wrapper pattern
- If wrappers exist, verify exact format match
- If not, reconsider wrapper necessity or document divergence rationale
- **Rationale**: Alignment with existing client integration patterns

**R9: Investigate Existing Logging Format**
- Verify existing log message templates
- Check for structured logging usage (JSON, key-value pairs)
- Document decision rationale for plain text vs. structured
- **Rationale**: Ensures log aggregation and monitoring tool compatibility
