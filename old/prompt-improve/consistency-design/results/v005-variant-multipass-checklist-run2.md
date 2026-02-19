# Consistency Design Review Report

**Review Date**: 2026-02-11
**Document**: オンライン診療予約システム 設計書
**Reviewer**: consistency-design-reviewer (v005-variant-multipass-checklist)

---

## Review Process Summary

**Pass 1 - Structural Understanding & Pattern Extraction**:
Completed full document read. Extracted documented patterns and checked for missing information against the checklist.

**Pass 2 - Detailed Consistency Analysis**:
Completed section-by-section analysis with codebase pattern verification and cross-cutting detection.

---

## Inconsistencies Identified

### CRITICAL: Architectural Pattern Consistency

#### Issue 1: Missing Codebase Context References
**Severity**: Critical
**Category**: Architectural Patterns (Checklist Item #7)

**Description**:
The design document completely lacks references to existing modules, patterns, or conventions in the current codebase. Section 3 (アーキテクチャ設計) documents a 3-layer architecture but does not reference:
- Whether this matches existing systems in the organization
- Which existing modules follow similar patterns
- How this system integrates with existing infrastructure
- What existing libraries or frameworks are already in use

**Missing Information**:
- No references to existing medical system modules
- No mention of existing authentication/authorization infrastructure
- No references to existing API gateway or service mesh patterns
- No connection to existing monitoring/logging infrastructure patterns

**Impact**:
Without existing system context, developers cannot verify if this design aligns with established organizational patterns. This could lead to:
- Duplicate authentication mechanisms
- Incompatible API standards across systems
- Divergent monitoring and logging approaches
- Integration challenges with existing medical systems

**Recommendation**:
Add a "Existing System Integration" section that documents:
- Reference implementations in the current codebase (e.g., "follows pattern established in [existing-service-name]")
- Existing shared libraries to reuse
- Existing infrastructure components (API gateway, auth service, etc.)
- Similar modules for pattern reference

---

### CRITICAL: Implementation Pattern Consistency

#### Issue 2: Inconsistent Error Handling Pattern Documentation
**Severity**: Critical
**Category**: Implementation Patterns (Checklist Item #3)

**Description**:
Section 6 (実装方針) states: "各Controllerでtry-catchを実装し、業務エラー・システムエラーを個別にハンドリングする"

This indicates individual error handling at the Controller level. However:
1. No verification against existing codebase error handling patterns
2. Spring Boot conventionally uses `@ControllerAdvice` for global exception handling
3. No documentation of which approach the existing codebase uses

**Pattern Conflict**:
The design proposes individual try-catch blocks, but without codebase verification:
- If existing services use `@ControllerAdvice`, this creates inconsistency
- If existing services use individual try-catch, this is consistent
- No evidence provided either way

**Missing Information**:
- Does the existing codebase use global error handlers (`@ControllerAdvice`)?
- What error response format do existing APIs use?
- Are there existing exception class hierarchies to reuse?
- What error logging patterns are established?

**Impact**:
- Potential fragmentation of error handling approaches across services
- Duplicate error response format definitions
- Inconsistent error logging across the system
- Difficulty maintaining unified error handling policies

**Recommendation**:
1. Document the dominant error handling pattern in existing codebase
2. If existing systems use `@ControllerAdvice`, adopt that pattern
3. Reference existing exception class hierarchies
4. Document alignment with established error response formats

---

### CRITICAL: Implementation Pattern Consistency

#### Issue 3: Missing Transaction Management Pattern
**Severity**: Critical
**Category**: Implementation Patterns (Checklist Item #3)

**Description**:
Section 6 mentions "data access patterns (Repository/ORM direct calls) and transaction management" as a key pattern, but the design document provides:
- Zero documentation of transaction management approach
- No mention of `@Transactional` usage
- No discussion of transaction boundaries
- No verification against existing codebase patterns

**Missing Information**:
- Where are transaction boundaries defined (Service layer/Repository layer)?
- What is the default propagation behavior?
- Are there established patterns for read-only vs. read-write transactions?
- How are long-running transactions handled?
- What isolation levels are used?

**Impact**:
Transaction management is fundamental to data integrity in a medical appointment system:
- Inconsistent transaction boundaries could cause data corruption
- Race conditions in appointment booking without proper isolation
- Performance issues from inappropriate transaction scope
- Difficulty maintaining data consistency across services

**Recommendation**:
Add explicit transaction management documentation:
1. Document where `@Transactional` annotations are placed
2. Reference existing codebase transaction patterns
3. Define transaction boundaries for critical operations (appointment booking, cancellation)
4. Specify isolation levels for concurrent operations

---

### SIGNIFICANT: Naming Convention Consistency

#### Issue 4: Inconsistent Entity Naming Convention
**Severity**: Significant
**Category**: Naming Conventions (Checklist Item #1)

**Description**:
Section 4 (データモデル) shows inconsistent table naming conventions:
- `Patients` (PascalCase)
- `medical_institutions` (snake_case)
- `appointment` (singular snake_case)
- `Questionnaires` (PascalCase)

**Pattern Issues**:
1. Mixed case styles (PascalCase vs snake_case)
2. Mixed singular/plural forms (`appointment` vs `Patients`)
3. No documentation of the intended naming convention
4. No verification against existing database schema patterns

**Missing Information**:
- What is the established table naming convention in the existing database?
- Are table names singular or plural?
- What case style is used (snake_case/PascalCase/kebab-case)?

**Impact**:
- Query confusion due to inconsistent naming
- Join complexity when mixing naming styles
- Code review burden to remember which tables use which convention
- Migration script errors due to case sensitivity

**Recommendation**:
1. Verify existing database schema naming conventions
2. Standardize all table names to match existing pattern
3. Document the chosen convention explicitly (e.g., "all table names use snake_case plural form")
4. Update all four entity definitions consistently

---

### SIGNIFICANT: API Design Consistency

#### Issue 5: Missing API Error Format Documentation
**Severity**: Significant
**Category**: API/Interface Design (Checklist Item #5)

**Description**:
Section 5 (API設計) provides a basic error response format:
```json
{
  "success": false,
  "errorMessage": "The selected time slot is not available"
}
```

However, critical API error details are missing:
- No error codes for programmatic handling
- No error field for form validation errors
- No standardized error message structure
- No reference to existing API error format conventions

**Missing Information**:
- Do existing APIs use error codes (e.g., "ERR_TIMESLOT_UNAVAILABLE")?
- How are validation errors formatted (field-level errors)?
- What HTTP status codes map to which error types?
- Is there an existing error format standard across APIs?

**Pattern Verification Needed**:
Without checking existing APIs, we cannot verify if this format is consistent with:
- Existing patient registration APIs
- Existing appointment systems
- Organizational API standards

**Impact**:
- Frontend error handling fragmentation
- Inability to implement consistent error UI across applications
- Difficulty internationalizing error messages
- Debugging challenges without error codes

**Recommendation**:
1. Reference existing API error format standards
2. Add error codes for programmatic handling
3. Document field-level validation error format
4. Create error code catalog (or reference existing one)
5. Example enhanced format:
```json
{
  "success": false,
  "error": {
    "code": "ERR_TIMESLOT_UNAVAILABLE",
    "message": "The selected time slot is not available",
    "details": {
      "field": "appointmentTime",
      "requestedTime": "14:00",
      "availableSlots": ["10:00", "15:00"]
    }
  }
}
```

---

### SIGNIFICANT: API Design Consistency

#### Issue 6: Unverified HTTP Client Library Choice
**Severity**: Significant
**Category**: API/Interface Design & Dependency (Checklist Item #5)

**Description**:
Section 2 (技術スタック) specifies "HTTP Client: RestTemplate" without justification or codebase verification.

**Pattern Concerns**:
1. RestTemplate is in maintenance mode as of Spring Framework 5.0
2. Spring recommends WebClient for new projects
3. No documentation of what existing services use
4. No explanation of why RestTemplate was chosen

**Missing Information**:
- What HTTP client do existing Spring Boot services in the codebase use?
- Is there an established library selection policy?
- Are there shared HTTP client configurations to reuse?

**Impact**:
- Using deprecated libraries in new development
- Inconsistency if existing services have migrated to WebClient
- Missing reactive capabilities if needed for scalability
- Difficulty maintaining unified HTTP client configuration

**Recommendation**:
1. Survey existing codebase for HTTP client usage
2. If existing services use WebClient, adopt that
3. If existing services use RestTemplate, document the reason for continuing this pattern
4. If no existing pattern, consider WebClient for new development
5. Document library selection rationale

---

### MODERATE: Configuration Management Consistency

#### Issue 7: Missing Configuration Management Documentation
**Severity**: Moderate
**Category**: Configuration Management (Checklist Item #6)

**Description**:
The design document lacks any documentation of:
- Configuration file formats (application.yml vs application.properties)
- Environment variable naming conventions
- Secrets management approach
- Configuration organization patterns

**Missing Information**:
- Does the existing codebase use YAML or Properties files?
- What environment variable prefix is used (e.g., `APP_`, `MEDICAL_`)?
- How are database credentials managed?
- Where are configuration files stored?
- What configuration management tools are used (Spring Cloud Config, etc.)?

**Impact**:
- Inconsistent configuration file formats across services
- Environment variable naming conflicts
- Duplicate secrets management implementations
- Deployment configuration drift

**Recommendation**:
Add a "Configuration Management" section documenting:
1. Reference to existing configuration patterns
2. File format choice (YAML/Properties) with rationale
3. Environment variable naming convention
4. Secrets management approach (AWS Secrets Manager, etc.)
5. Configuration file organization

---

### MODERATE: Directory Structure Consistency

#### Issue 8: Missing File Placement Documentation
**Severity**: Moderate
**Category**: Directory Structure & File Placement (Checklist Item #4)

**Description**:
Section 3 documents component responsibilities but provides zero guidance on:
- Directory structure organization
- File placement rules
- Package naming conventions
- Resource file organization

**Missing Information**:
- Is the codebase organized by layer or by domain?
- Example: `/controller/patient/` vs `/patient/controller/`
- What package naming pattern is used?
- Example: `com.medical.appointment.patient.controller` vs `com.medical.appointment.controller.patient`
- Where are configuration files placed?
- Where are test files organized?

**Impact**:
- Developers cannot determine where to place new files
- Inconsistent package structures across features
- Difficulty navigating codebase
- Code review friction on file placement decisions

**Recommendation**:
Add a "Project Structure" section:
1. Document the dominant organizational pattern (layer-based vs domain-based)
2. Provide example directory tree
3. Reference existing modules with similar structure
4. Document package naming conventions with examples

---

### MODERATE: Naming Convention Consistency

#### Issue 9: Missing Java Class Naming Documentation
**Severity**: Moderate
**Category**: Naming Conventions (Checklist Item #1)

**Description**:
While Section 3 lists component names (PatientController, PatientService, PatientRepository), there is no explicit documentation of:
- Class naming conventions (suffix patterns)
- Interface naming conventions (prefix/suffix)
- DTO naming patterns
- Exception class naming patterns

**Missing Information**:
- Are interfaces prefixed with "I" (IPatientService)?
- What suffix do DTOs use (PatientDto, PatientResponse, PatientVO)?
- How are request/response objects named?
- What naming pattern do custom exceptions follow?

**Pattern Verification Needed**:
Cannot verify if "PatientService", "AppointmentService" matches existing service class naming without codebase reference.

**Impact**:
- Inconsistent class naming across features
- Code generation tool incompatibility
- Import confusion with similar names
- Difficulty establishing naming conventions for new developers

**Recommendation**:
Document explicit naming conventions:
1. Reference existing codebase naming patterns
2. Provide naming rules: "All service classes use [Entity]Service pattern"
3. Document DTO suffixes (e.g., "Request/Response/Dto")
4. Provide counter-examples (what NOT to name things)

---

### MODERATE: Implementation Pattern Consistency

#### Issue 10: Missing Asynchronous Processing Pattern
**Severity**: Moderate
**Category**: Implementation Patterns (Checklist Item #3)

**Description**:
Section 3 mentions "AppointmentService: 予約作成、キャンセル、リマインダー送信" which suggests asynchronous operations (reminder sending), but:
- No documentation of async processing approach
- No mention of `@Async`, CompletableFuture, or message queues
- No verification against existing async patterns

**Missing Information**:
- How are reminder emails sent (sync/async)?
- What async processing framework is used (Spring `@Async`, RabbitMQ, SQS)?
- What is the retry strategy for failed async operations?
- How are async operation results tracked?

**Impact**:
- Synchronous reminder sending could block appointment creation
- Inconsistent async patterns across services
- Difficulty troubleshooting failed background jobs
- Performance bottlenecks if async operations are synchronous

**Recommendation**:
Document asynchronous processing patterns:
1. Reference existing background job implementations
2. Specify async framework choice (Spring @Async, message queue)
3. Document retry and error handling for async operations
4. Define monitoring approach for background jobs

---

## Pattern Evidence

The following evidence gaps were identified during the review:

### No Codebase References Found
- Zero references to existing modules or services
- No mention of existing authentication infrastructure
- No reference to existing API patterns
- No connection to existing database schemas
- No mention of existing configuration management

### Documented Patterns (from design document)
- 3-layer architecture (Controller → Service → Repository)
- JWT authentication with HTTP-only cookies
- JSON logging with CloudWatch
- Spring Data JPA for data access
- Individual try-catch error handling

### Verification Gaps
Without access to the existing codebase, the following patterns could not be verified:
1. Whether 3-layer architecture matches existing services
2. Whether JWT auth approach aligns with existing auth services
3. Whether JSON logging format matches existing log aggregation
4. Whether JPA usage patterns align with existing data access
5. Whether error handling approach matches existing controllers

---

## Impact Analysis

### High Impact Issues (Must Address)

**Issue 1 (Missing Codebase Context)**: Without existing system references, this design operates in a vacuum. Integration failures, duplicate implementations, and pattern divergence are highly likely.

**Issue 2 (Error Handling Pattern)**: Inconsistent error handling creates maintenance burden and makes it difficult to implement cross-cutting concerns like monitoring and alerting.

**Issue 3 (Transaction Management)**: Missing transaction documentation risks data corruption in a medical system where data integrity is critical (appointment conflicts, double-booking).

### Medium Impact Issues (Should Address)

**Issue 4 (Table Naming)**: Inconsistent naming creates immediate friction in development and increases cognitive load for all database operations.

**Issue 5 (API Error Format)**: Insufficient error formatting makes frontend error handling inconsistent and creates poor user experience.

**Issue 6 (HTTP Client)**: Using deprecated libraries in new development creates technical debt from day one.

### Lower Impact Issues (Recommended to Address)

**Issues 7-10**: Missing documentation for configuration, file structure, class naming, and async patterns will create friction during implementation but won't block development.

---

## Recommendations

### Immediate Actions (Before Implementation Starts)

1. **Add Existing System Integration Section**: Document all existing modules, patterns, and infrastructure this system will integrate with or follow.

2. **Verify and Document Error Handling Pattern**: Check existing codebase for error handling approach (global vs individual). Align this design with the dominant pattern.

3. **Document Transaction Management**: Add explicit transaction boundary definitions, isolation levels, and reference existing transaction patterns.

4. **Standardize Table Naming**: Choose one naming convention (recommend: snake_case plural) and apply consistently. Verify against existing database schema.

5. **Enhance API Error Format**: Add error codes, field-level validation errors, and reference existing API error standards.

6. **Verify HTTP Client Choice**: Check existing services for HTTP client usage. Document rationale for RestTemplate or migrate to WebClient.

### Secondary Actions (Before Feature Development)

7. **Add Configuration Management Section**: Document configuration file formats, environment variable conventions, and secrets management aligned with existing patterns.

8. **Document File Placement Rules**: Add project structure section with package naming and directory organization patterns from existing codebase.

9. **Explicit Class Naming Conventions**: Document all class, interface, DTO, and exception naming patterns with examples from existing code.

10. **Document Async Processing Pattern**: Add asynchronous operation handling approach for reminders and other background jobs.

---

## Positive Observations

The design document demonstrates several strengths:

1. **Clear Layering**: The 3-layer architecture is clearly documented with component responsibilities
2. **Comprehensive Scope**: Covers all major system aspects (architecture, data model, API, deployment)
3. **Security Awareness**: Includes security requirements (HTTPS, bcrypt, CSRF, SQL injection protection)
4. **Non-Functional Requirements**: Documents performance, availability, and scalability goals
5. **Structured API Design**: Provides clear endpoint definitions with request/response examples

These elements provide a solid foundation. The primary gap is **lack of connection to existing codebase patterns**, which is critical for consistency.

---

## Summary

**Total Issues Identified**: 10
- **Critical**: 3 (Codebase context, error handling, transaction management)
- **Significant**: 3 (Table naming, API error format, HTTP client)
- **Moderate**: 4 (Configuration, file structure, class naming, async patterns)

**Primary Concern**: The design document operates in isolation without any references to existing codebase patterns. This is the root cause of most inconsistency risks.

**Key Recommendation**: Before proceeding with implementation, conduct a codebase pattern survey and update this design document with explicit references to existing modules and conventions. This will ensure consistency and prevent fragmentation.
