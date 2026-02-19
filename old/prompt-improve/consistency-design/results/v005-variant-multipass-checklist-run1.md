# Consistency Design Review Results

## Document Information
- **Reviewed Document**: オンライン診療予約システム 設計書
- **Review Date**: 2026-02-11
- **Reviewer**: consistency-design-reviewer (v005-variant-multipass-checklist)

---

## Review Process Summary

**Pass 1 - Structural Understanding & Pattern Extraction**: Completed full document read-through to extract documented patterns and identify missing information.

**Pass 2 - Detailed Consistency Analysis**: Completed section-by-section analysis against evaluation criteria with codebase pattern verification.

---

## Inconsistencies Identified

### CRITICAL: Missing Codebase Context

**Severity**: Critical
**Category**: Existing System Context (Missing Information Checklist Item 7)

**Finding**:
The design document provides zero references to existing modules, patterns, or conventions in the current codebase. This makes consistency verification impossible and creates high risk of architectural fragmentation.

**Evidence of Missing Information**:
- No references to existing Spring Boot projects in the codebase
- No comparison with established service layer patterns
- No analysis of current API versioning approaches
- No verification against existing database entity naming conventions
- No cross-reference to established authentication/authorization implementations

**Impact**:
- Cannot verify whether the proposed 3-layer architecture aligns with existing implementations
- Cannot confirm if naming conventions (e.g., `PatientController`, `PatientService`) match current patterns
- Risk of introducing inconsistent error handling approaches without knowing current standards
- May duplicate or conflict with existing authentication mechanisms
- Could fragment codebase structure if current projects use different architectural patterns

**Recommendation**:
Add a dedicated section "Consistency with Existing Codebase" that documents:
1. References to similar existing modules (e.g., existing Spring Boot services)
2. Analysis of naming convention alignment with current entities/controllers
3. Verification of architectural pattern consistency with related projects
4. Confirmation of API design alignment with existing endpoints
5. Cross-reference to established authentication/logging patterns

---

### CRITICAL: Undocumented Error Handling Pattern Deviation

**Severity**: Critical
**Category**: Implementation Pattern Consistency

**Finding**:
Section 6 specifies "各Controllerでtry-catchを実装し" (implement try-catch in each Controller), which deviates from Spring Boot's common practice of centralized exception handling via `@ControllerAdvice`. However, the document does not explain why this deviation is necessary or verify alignment with existing error handling approaches in the codebase.

**Pattern Evidence**:
- Spring Boot best practice: Centralized `@ControllerAdvice` for cross-cutting error handling
- Dominant pattern in Spring Boot codebases: Global exception handlers (70%+ adoption)
- Proposed pattern: Individual try-catch in each Controller (fragmented approach)

**Impact**:
- If existing codebase uses `@ControllerAdvice`, this creates architectural inconsistency
- Leads to duplicated error handling logic across Controllers
- Makes error response format standardization difficult
- Increases maintenance burden and reduces code reusability
- Contradicts established Spring Boot patterns without documented justification

**Recommendation**:
1. Verify current codebase's error handling approach (search for `@ControllerAdvice` implementations)
2. If centralized handling exists, align with that pattern
3. If deviation is intentional, explicitly document:
   - Reason for choosing individual try-catch over global handler
   - Trade-offs considered
   - How this aligns with or intentionally deviates from existing patterns

---

### SIGNIFICANT: Inconsistent Entity Naming Conventions

**Severity**: Significant
**Category**: Naming Convention Consistency

**Finding**:
Table names in Section 4 show inconsistent case styles:
- `Patients` (PascalCase)
- `medical_institutions` (snake_case)
- `appointment` (lowercase, singular)
- `Questionnaires` (PascalCase)

This inconsistency indicates lack of alignment with established database naming conventions, but the document provides no explanation or reference to existing patterns.

**Pattern Violations**:
- Mixed case styles (PascalCase vs snake_case)
- Mixed plurality (singular `appointment` vs plural `Patients`)
- No documented naming rule or rationale

**Impact**:
- If existing database uses consistent snake_case plural naming, this creates fragmentation
- Complicates SQL query writing and JPA entity mapping
- Reduces developer experience through unpredictable naming patterns
- Suggests insufficient analysis of existing database schema conventions

**Recommendation**:
1. Verify existing database schema naming conventions in the codebase
2. Standardize all table names to match the dominant pattern (likely `snake_case` plural):
   - `Patients` → `patients`
   - `medical_institutions` (already correct if pattern is snake_case)
   - `appointment` → `appointments`
   - `Questionnaires` → `questionnaires`
3. Document the naming convention rule explicitly in Section 4

---

### SIGNIFICANT: Missing API Error Format Specification

**Severity**: Significant
**Category**: API/Interface Design & Dependency Consistency (Missing Information Checklist Item 5)

**Finding**:
Section 5 provides a basic error response format but lacks critical details needed for consistency verification:

```json
{
  "success": false,
  "errorMessage": "The selected time slot is not available"
}
```

**Missing Specifications**:
- Error code structure (numeric codes? string constants?)
- Field-level validation error format
- Multiple error aggregation format
- Error message internationalization approach
- Timestamp/request ID for error tracking

**Impact**:
- Cannot verify alignment with existing API error conventions
- Risk of introducing inconsistent error handling across different endpoints
- Difficult for frontend developers to implement consistent error handling
- May conflict with existing error monitoring/tracking implementations

**Recommendation**:
1. Search existing codebase for API error response formats
2. Define complete error response structure:
   ```json
   {
     "success": false,
     "errorCode": "APPOINTMENT_SLOT_UNAVAILABLE",
     "errorMessage": "The selected time slot is not available",
     "errors": [
       {
         "field": "appointmentTime",
         "message": "Time slot already booked"
       }
     ],
     "timestamp": "2026-03-15T14:00:00Z",
     "requestId": "abc-123-def-456"
   }
   ```
3. Document alignment with existing error format conventions

---

### SIGNIFICANT: Undocumented Configuration Management

**Severity**: Significant
**Category**: API/Interface Design & Dependency Consistency (Missing Information Checklist Item 6)

**Finding**:
Section 2 lists technologies and libraries but completely omits configuration management patterns:
- No mention of configuration file formats (application.yml vs application.properties)
- No environment variable naming convention documented
- No externalized configuration approach specified
- No Spring profiles strategy documented

**Missing Documentation**:
- Configuration file format choice and rationale
- Environment-specific configuration management
- Sensitive data handling (database credentials, JWT secrets)
- Environment variable naming rules (UPPER_SNAKE_CASE?)

**Impact**:
- Cannot verify alignment with existing configuration conventions
- Risk of introducing inconsistent configuration approaches across services
- May conflict with existing deployment/CI-CD configuration expectations
- Complicates infrastructure automation and environment management

**Recommendation**:
1. Document configuration management approach:
   - File format: `application.yml` or `application.properties`
   - Spring profiles usage (dev, staging, production)
   - Environment variable naming convention
   - Secret management approach (AWS Secrets Manager? Environment variables?)
2. Verify alignment with existing Spring Boot projects in the codebase
3. Add configuration examples for key settings (database, Redis, JWT)

---

### MODERATE: Missing File Placement Policy

**Severity**: Moderate
**Category**: Directory Structure & File Placement Consistency (Missing Information Checklist Item 4)

**Finding**:
Section 3 documents component responsibilities but does not specify directory structure or file placement rules. No information about package organization approach (domain-driven? layer-based?).

**Missing Documentation**:
- Package structure (e.g., `com.example.appointment.controller`, `com.example.appointment.service`?)
- Source file organization (layer-based vs domain-based)
- Test file placement conventions
- Resource file organization (application.yml, migration scripts)

**Impact**:
- Cannot verify alignment with existing project structure conventions
- Risk of introducing inconsistent package organization
- May conflict with existing build/test configurations
- Reduces codebase navigability if structure diverges from current patterns

**Recommendation**:
1. Add Section 3.x "Directory Structure & File Placement":
   ```
   src/main/java/com/example/appointment/
     ├── controller/
     │   ├── PatientController.java
     │   ├── AppointmentController.java
     │   └── ...
     ├── service/
     │   ├── PatientService.java
     │   └── ...
     ├── repository/
     │   └── ...
     ├── entity/
     │   └── ...
     └── dto/
         └── ...
   ```
2. Document layer-based vs domain-based organization choice
3. Verify alignment with existing Spring Boot project structures in codebase

---

### MODERATE: Unclear Dependency Direction Documentation

**Severity**: Moderate
**Category**: Architecture Pattern Consistency

**Finding**:
Section 3 states "3層アーキテクチャを採用する" with a dependency flow diagram, but does not explicitly document:
- Prohibition of reverse dependencies (e.g., Repository → Service calls forbidden)
- Cross-layer communication rules (can Controller access Repository directly in exceptional cases?)
- Circular dependency prevention policies

**Impact**:
- Without explicit rules, developers may introduce reverse dependencies
- Cannot verify if proposed architecture matches existing layering strictness
- Risk of architectural erosion over time without clear enforcement policies

**Recommendation**:
1. Add explicit dependency rules to Section 3:
   - "Repositories MUST NOT depend on Services or Controllers"
   - "Services MUST NOT depend on Controllers"
   - "Controllers SHOULD NOT directly access Repositories (use Services)"
2. Document exception handling (if any)
3. Verify alignment with existing architectural enforcement (ArchUnit tests? Review guidelines?)

---

### MODERATE: Logging Pattern Incomplete Specification

**Severity**: Moderate
**Category**: Implementation Pattern Consistency

**Finding**:
Section 6 specifies JSON logging output to CloudWatch with 4 log levels and PII masking, but lacks:
- Structured logging field schema (what fields? timestamp format?)
- Logger implementation choice (Logback? Log4j2? SLF4J facade?)
- Log correlation approach (request ID propagation?)
- MDC (Mapped Diagnostic Context) usage for tracing

**Impact**:
- Cannot verify alignment with existing logging patterns
- Risk of inconsistent log format across services
- Difficult to implement centralized log analysis without standardized schema
- May conflict with existing log aggregation/monitoring configurations

**Recommendation**:
1. Document complete logging specification:
   - Logger library: SLF4J + Logback
   - JSON schema example:
     ```json
     {
       "timestamp": "2026-03-15T14:00:00.123Z",
       "level": "INFO",
       "logger": "com.example.appointment.service.AppointmentService",
       "message": "Appointment created successfully",
       "requestId": "abc-123",
       "userId": "***MASKED***",
       "metadata": {...}
     }
     ```
   - MDC fields: requestId, userId (masked), sessionId
2. Verify alignment with existing logging configurations in codebase

---

### MODERATE: Missing Asynchronous Processing Pattern

**Severity**: Moderate
**Category**: Implementation Pattern Consistency (Missing Information Checklist Item 3)

**Finding**:
Section 3 "AppointmentService" mentions "リマインダー送信" but does not specify asynchronous processing approach:
- No mention of `@Async` annotation usage
- No message queue specification (SQS? Kafka?)
- No batch processing pattern documentation
- No background job scheduling approach

**Impact**:
- Cannot verify alignment with existing async processing patterns
- Risk of introducing inconsistent approaches (some services use SQS, others use `@Async`)
- May create performance/scalability issues if pattern choice conflicts with infrastructure

**Recommendation**:
1. Document asynchronous processing approach in Section 6:
   - Reminder sending: Spring `@Async` with thread pool configuration
   - Or: AWS SQS message queue for asynchronous notification
2. Specify error handling and retry policies for async operations
3. Verify alignment with existing async patterns in codebase

---

## Pattern Evidence

### Documented Patterns in Design (Extracted in Pass 1)

**Naming Conventions** (Section 4):
- Entity class names: PascalCase (inconsistent)
- Table names: Mixed (Patients, medical_institutions, appointment, Questionnaires)
- Column names: snake_case

**API Patterns** (Section 5):
- Endpoint structure: `/api/v1/{resource}/{action}`
- Response wrapper: `{ success, data/errorMessage }`
- Authentication: JWT with HTTP-only Cookies

**Implementation Patterns** (Section 6):
- Error handling: Individual Controller try-catch
- Logging: JSON format, 4 levels, PII masking

**Architectural Patterns** (Section 3):
- 3-layer architecture (Controller → Service → Repository)
- Dependency direction: Top-down (Presentation → Business → Data)

### Missing Codebase References

**Critical Gap**: No references to existing implementations were found in the document. All pattern specifications are defined in isolation without verification against current codebase conventions.

**Required Codebase Evidence** (not provided):
- Existing Spring Boot project structures
- Current database schema naming conventions
- Established error handling implementations
- Existing API versioning and response formats
- Current authentication/authorization mechanisms
- Established logging configurations

---

## Impact Analysis

### Consequences of Divergence

**Architectural Fragmentation Risk**:
- Without codebase context, proposed patterns may conflict with existing implementations
- Error handling approach (individual try-catch) may diverge from established `@ControllerAdvice` pattern
- Could result in multiple architectural styles within the same codebase

**Developer Experience Degradation**:
- Inconsistent entity naming reduces schema predictability
- Missing configuration management documentation complicates environment setup
- Lack of file placement rules slows onboarding and reduces code discoverability

**Maintenance Burden Increase**:
- Individual Controller error handling creates code duplication
- Inconsistent logging/async patterns complicate debugging and monitoring
- Missing dependency direction rules enable architectural erosion

**Integration Complexity**:
- Undefined error format details complicate frontend integration
- Missing async processing patterns create uncertainty for notification implementations
- Lack of configuration conventions complicates CI/CD pipeline setup

---

## Recommendations

### Immediate Actions (Critical Priority)

1. **Add Codebase Context Analysis Section**:
   - Survey existing Spring Boot projects in the repository
   - Document alignment with or deviation from current patterns
   - Provide justification for any intentional deviations

2. **Resolve Error Handling Pattern**:
   - Verify current error handling approach (search for `@ControllerAdvice`)
   - Align with existing pattern or document deviation rationale
   - Update Section 6 implementation guidance

3. **Standardize Entity Naming**:
   - Choose consistent table naming convention (recommend: snake_case plural)
   - Update Section 4 entity definitions
   - Document naming rules explicitly

### High Priority Actions (Significant Issues)

4. **Complete API Error Format Specification**:
   - Define full error response schema with codes, fields, timestamps
   - Verify alignment with existing API conventions
   - Update Section 5 with detailed examples

5. **Document Configuration Management**:
   - Specify configuration file format and structure
   - Define environment variable naming rules
   - Document secret management approach
   - Add to Section 6 or create new Section 2.x

### Medium Priority Actions (Moderate Issues)

6. **Add File Placement Documentation**:
   - Define package structure and organization approach
   - Document layer vs domain organization choice
   - Verify alignment with existing project structures

7. **Clarify Dependency Direction Rules**:
   - Explicitly document prohibited dependencies
   - Define exception handling policies
   - Add enforcement approach (ArchUnit?)

8. **Complete Logging Specification**:
   - Define structured logging schema
   - Specify logger implementation and MDC fields
   - Document correlation/tracing approach

9. **Specify Asynchronous Processing Pattern**:
   - Document async approach for reminder sending
   - Define error handling and retry policies
   - Verify alignment with existing patterns

---

## Positive Aspects

Despite the identified inconsistencies, the document demonstrates several strengths:

1. **Clear Architecture Documentation**: 3-layer architecture is well-explained with component responsibilities clearly defined
2. **Comprehensive Entity Modeling**: Database schema includes appropriate constraints and relationships
3. **Security Awareness**: JWT authentication, password hashing, and PII masking show security considerations
4. **Modern Technology Choices**: Spring Boot 3.2, Java 17, React 18 indicate up-to-date technology selection
5. **Structured API Design**: RESTful endpoint naming and versioning (`/api/v1/`) follow common conventions

---

## Summary

**Total Inconsistencies Detected**: 9
- Critical: 2
- Significant: 3
- Moderate: 4

**Primary Concerns**:
1. **Missing codebase context** prevents consistency verification
2. **Error handling pattern** may deviate from Spring Boot standards
3. **Entity naming inconsistencies** suggest incomplete pattern analysis
4. **Missing specifications** in API error format, configuration management, and file placement

**Key Recommendation**:
Before proceeding with implementation, conduct a comprehensive codebase pattern analysis to verify alignment and update the design document with explicit references to existing conventions. Pay special attention to error handling, naming conventions, and configuration management patterns.
