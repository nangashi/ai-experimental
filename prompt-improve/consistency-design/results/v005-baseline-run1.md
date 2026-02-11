# Consistency Review: Online Medical Appointment System Design Document

**Reviewer**: consistency-design-reviewer
**Variant**: v005-baseline
**Date**: 2026-02-11
**Review Method**: Multi-Pass Review (Pass 1: Structural Understanding → Pass 2: Detailed Consistency Analysis)

---

## Executive Summary

This design document describes an online medical appointment reservation system built with Java 17/Spring Boot 3.2 and TypeScript/React 18. The review was conducted against an **experimental AI codebase** that contains **no existing Java, TypeScript, or Spring Boot implementation**. As a result, this review evaluates the document's **internal consistency and explicit pattern documentation** rather than alignment with existing codebase patterns.

**Key Finding**: The document is internally consistent in its architecture, naming, and API design. However, it lacks explicit documentation of critical implementation pattern decisions (error handling, authentication, data access, logging) that would be necessary for maintaining consistency across a development team.

---

## Pass 1 - Structural Understanding (Summary)

The document contains 7 main sections covering scope, technology stack, architecture, data model, API design, implementation policies, and non-functional requirements. The overall structure is logical and well-organized. Notable observations:

- **Present**: Architecture diagram, layer responsibilities, API endpoints, data models, authentication approach, deployment strategy
- **Partially Present**: Implementation pattern decisions (error handling, logging)
- **Missing**: Explicit documentation of consistency rules for naming conventions, directory structure, configuration formats, and dependency injection patterns

---

## Pass 2 - Detailed Consistency Analysis

### 1. Naming Convention Consistency

#### 1.1 Critical Inconsistency: Mixed PascalCase/snake_case in Table Names

**Severity**: Critical
**Location**: Section 4 (Data Model)

**Issue**:
The data model exhibits inconsistent table naming conventions:
- `Patients` (PascalCase)
- `Questionnaires` (PascalCase)
- `medical_institutions` (snake_case)
- `appointment` (lowercase, singular)

**Pattern Evidence**:
No existing codebase pattern to reference. This represents internal inconsistency within the document itself.

**Impact Analysis**:
- ORM mapping confusion: Spring Data JPA default naming strategy expects consistent case styles
- Developer cognitive load: Mixed conventions require mental context-switching
- Migration script errors: Case-sensitive databases (PostgreSQL) may exhibit unexpected behavior

**Recommendation**:
Standardize to snake_case (PostgreSQL convention) or PascalCase (Java entity convention), and document the rule explicitly:
```
Recommended: patients, medical_institutions, appointments, questionnaires
Alternative: Patients, MedicalInstitutions, Appointments, Questionnaires
```
Add explicit table naming policy in Section 6: "All database table names shall use snake_case to align with PostgreSQL conventions."

---

#### 1.2 Significant Inconsistency: Mixed camelCase/snake_case in Request JSON

**Severity**: Significant
**Location**: Section 5 (API Design)

**Issue**:
The example request uses camelCase (`patientId`, `medicalInstitutionId`, `appointmentDate`, `appointmentTime`), but the database schema uses snake_case (`patient_id`, `medical_institution_id`, `appointment_date`, `appointment_time`).

**Pattern Evidence**:
No existing API convention to reference. This represents a potential serialization/deserialization inconsistency.

**Impact Analysis**:
- Requires explicit @JsonProperty annotations or custom Jackson ObjectMapper configuration
- Risk of field mapping errors if serialization configuration is not properly maintained
- Inconsistent developer experience between API and database layers

**Recommendation**:
Document the API-DB naming translation policy explicitly:
```markdown
### Naming Convention Policy
- **API Layer (JSON)**: camelCase (e.g., patientId, appointmentDate)
- **Database Layer**: snake_case (e.g., patient_id, appointment_date)
- **Mapping**: Use Spring Boot's default Jackson configuration (spring.jackson.property-naming-strategy=SNAKE_CASE)
  OR @JsonProperty annotations on entity classes
```

---

#### 1.3 Moderate Issue: Undocumented File Naming Convention

**Severity**: Moderate
**Location**: Section 3 (Architecture Design)

**Issue**:
Controller, Service, and Repository classes follow `{Entity}{Layer}` naming pattern (e.g., `PatientController`, `AppointmentService`), but this convention is not explicitly documented.

**Pattern Evidence**:
No existing codebase to reference.

**Impact Analysis**:
- Low risk in a greenfield project if team follows Java conventions
- Future developers may introduce variations (e.g., `ControllerForPatient`, `PatientMgmtController`)

**Recommendation**:
Add explicit naming convention section:
```markdown
### Class Naming Conventions
- Controllers: {Entity}Controller (e.g., PatientController)
- Services: {Entity}Service (e.g., AppointmentService)
- Repositories: {Entity}Repository (e.g., QuestionnaireRepository)
- Entities: {Entity} (singular, e.g., Patient, Appointment)
```

---

### 2. Architecture Pattern Consistency

#### 2.1 Positive: Clear 3-Layer Architecture

**Severity**: N/A (Positive Observation)
**Location**: Section 3

**Observation**:
The document clearly defines a 3-layer architecture (Presentation → Business Logic → Data Access) with unidirectional dependency flow. This is a standard Spring Boot pattern.

**Evidence**:
- Controller → Service → Repository dependency direction is consistently described
- Each layer's responsibility is clearly separated

**Impact**:
This provides a solid foundation for consistency, assuming all future modules follow the same pattern.

---

#### 2.2 Minor Issue: Lack of Cross-Cutting Concern Documentation

**Severity**: Minor
**Location**: Section 3 (Architecture Design)

**Issue**:
The document does not address architectural patterns for cross-cutting concerns:
- Transaction management (service-level @Transactional?)
- Caching strategy (controller-level, service-level, or repository-level?)
- Security enforcement point (controller-level @PreAuthorize?)

**Pattern Evidence**:
No existing codebase to reference.

**Impact Analysis**:
- Risk of inconsistent transaction boundaries across services
- Unclear caching layer may lead to redundant cache keys or inconsistent TTL policies

**Recommendation**:
Add a "Cross-Cutting Concerns" subsection in Section 3:
```markdown
### Cross-Cutting Concerns
- **Transaction Management**: Apply @Transactional at Service layer (read-only for queries)
- **Caching**: Apply @Cacheable at Service layer for medical institution searches
- **Security**: Enforce authentication at Controller layer using Spring Security method-level annotations
```

---

### 3. Implementation Pattern Consistency

#### 3.1 Critical Inconsistency: Contradictory Error Handling Strategy

**Severity**: Critical
**Location**: Section 6 (Implementation Policy)

**Issue**:
The document states: "各Controllerでtry-catchを実装し、業務エラー・システムエラーを個別にハンドリングする" (Each Controller implements try-catch to handle business and system errors individually).

This contradicts Spring Boot best practices:
- Spring Boot provides `@ControllerAdvice` for centralized error handling
- Individual try-catch in each controller leads to code duplication and inconsistent error responses

**Pattern Evidence**:
No existing codebase, but this represents a deviation from the Spring Boot ecosystem's recommended patterns.

**Impact Analysis**:
- High code duplication (each controller duplicates error handling logic)
- Inconsistent error response formats across endpoints
- Difficult to maintain (changes to error format require updates in all controllers)

**Recommendation**:
Revise the error handling policy to use Spring Boot's global exception handler:
```markdown
### Error Handling Policy
- **Global Exception Handler**: Implement @ControllerAdvice with @ExceptionHandler methods
- **Business Errors**: Throw custom exceptions (e.g., AppointmentConflictException) with 400-series codes
- **System Errors**: Let Spring's default handler catch unexpected exceptions with 500-series codes
- **Validation Errors**: Rely on Spring's @Valid and MethodArgumentNotValidException
```

---

#### 3.2 Significant Issue: Missing Authentication Pattern Documentation

**Severity**: Significant
**Location**: Section 5 (API Design)

**Issue**:
The document specifies JWT authentication but does not document:
- Implementation approach (Filter, Interceptor, or @PreAuthorize annotations?)
- Token storage location (HTTP-only Cookie mentioned, but client-side handling unclear)
- Token refresh flow (is there a dedicated `/refresh` endpoint?)

**Pattern Evidence**:
No existing codebase to reference.

**Impact Analysis**:
- Developers may implement authentication inconsistently across endpoints
- Risk of security vulnerabilities if token validation logic is duplicated
- Unclear client-side implementation (React components may handle tokens differently)

**Recommendation**:
Add detailed authentication pattern documentation:
```markdown
### Authentication Implementation Pattern
- **Filter Chain**: Use Spring Security's JwtAuthenticationFilter before UsernamePasswordAuthenticationFilter
- **Token Validation**: Centralized in JwtTokenProvider utility class
- **Authorization**: Use @PreAuthorize annotations at Controller methods
- **Token Refresh**: Dedicated POST /api/v1/auth/refresh endpoint accepting refresh token from cookie
- **Client-Side**: Store access token in memory, refresh token in HttpOnly cookie
```

---

#### 3.3 Significant Issue: Missing Data Access Pattern Documentation

**Severity**: Significant
**Location**: Section 3 (Architecture Design)

**Issue**:
The document mentions "Spring Data JPA" but does not specify:
- Query method naming convention (e.g., `findByEmailAndStatus` vs `getByEmailAndStatus`?)
- Complex query approach (@Query annotation, Criteria API, or QueryDSL?)
- Pagination pattern (Pageable parameter convention?)

**Pattern Evidence**:
No existing codebase to reference.

**Impact Analysis**:
- Inconsistent query method naming across repositories
- Mixed complex query approaches (some developers use @Query, others use Specifications)
- Inconsistent pagination implementation

**Recommendation**:
Add data access pattern documentation:
```markdown
### Data Access Patterns
- **Simple Queries**: Use Spring Data JPA query methods (e.g., findByEmail, findByStatusAndAppointmentDate)
- **Complex Queries**: Use @Query with JPQL for multi-table joins or aggregations
- **Pagination**: Always use Pageable parameter for list endpoints (e.g., Page<Appointment> findByPatientId(Long id, Pageable pageable))
- **Soft Deletes**: Use status column (e.g., status='DELETED') instead of physical deletion
```

---

#### 3.4 Moderate Issue: Incomplete Logging Pattern Documentation

**Severity**: Moderate
**Location**: Section 6 (Implementation Policy)

**Issue**:
The document specifies JSON-format logging with 4 levels and PII masking, but does not document:
- Logger naming convention (class-based, component-based?)
- Structured logging field names (e.g., `userId` vs `user_id`?)
- MDC (Mapped Diagnostic Context) usage for request tracing

**Pattern Evidence**:
No existing codebase to reference.

**Impact Analysis**:
- Inconsistent log entry structures make log aggregation and searching difficult
- Missing trace IDs prevent request flow tracking in distributed systems

**Recommendation**:
Expand logging policy:
```markdown
### Logging Implementation Pattern
- **Logger Declaration**: Use SLF4J with class-based loggers (private static final Logger log = LoggerFactory.getLogger(ClassName.class))
- **Structured Fields**: Use consistent camelCase keys (e.g., {"userId": 123, "appointmentId": 456})
- **MDC Usage**: Inject traceId and sessionId in Spring Security filter for request tracing
- **PII Masking**: Use custom JsonSerializer for Patient entity fields
```

---

### 4. Directory Structure & File Placement Consistency

#### 4.1 Critical Omission: No Directory Structure Documentation

**Severity**: Critical
**Location**: Entire Document

**Issue**:
The document does not specify:
- Package structure (layer-based vs domain-based?)
- Configuration file locations (application.yml placement?)
- Test directory organization (mirror src structure or separate by test type?)

**Pattern Evidence**:
No existing codebase to reference.

**Impact Analysis**:
- High risk of inconsistent package organization as team grows
- Developers may adopt different structures (some use `com.example.controller`, others use `com.example.patient.controller`)
- Test files may be scattered unpredictably

**Recommendation**:
Add explicit directory structure section:
```markdown
### Directory Structure
**Backend (Layer-First Structure)**:
```
src/main/java/com/example/medical/
  ├── controller/
  │   ├── PatientController.java
  │   ├── AppointmentController.java
  ├── service/
  │   ├── PatientService.java
  │   ├── AppointmentService.java
  ├── repository/
  │   ├── PatientRepository.java
  ├── entity/
  │   ├── Patient.java
  ├── dto/
  │   ├── request/
  │   │   ├── PatientRegisterRequest.java
  │   ├── response/
  │       ├── AppointmentResponse.java
  ├── exception/
  │   ├── AppointmentConflictException.java
  ├── security/
  │   ├── JwtTokenProvider.java
  ├── config/
      ├── SecurityConfig.java
```

**Alternative (Domain-First Structure)**: If project grows, consider domain-based organization:
```
src/main/java/com/example/medical/
  ├── patient/
  │   ├── PatientController.java
  │   ├── PatientService.java
  │   ├── PatientRepository.java
  ├── appointment/
      ├── AppointmentController.java
```

---

### 5. API/Interface Design & Dependency Consistency

#### 5.1 Positive: Consistent API Endpoint Naming

**Severity**: N/A (Positive Observation)
**Location**: Section 5 (API Design)

**Observation**:
API endpoints follow consistent RESTful conventions:
- Resource naming: plural nouns (`/patients`, `/appointments`)
- Version prefix: `/api/v1/`
- Action verbs in URL for non-CRUD operations: `/cancel` (acceptable for RPC-style operations)

**Impact**:
Clear API contract reduces integration errors.

---

#### 5.2 Significant Inconsistency: Inconsistent Response Envelope Usage

**Severity**: Significant
**Location**: Section 5 (API Design)

**Issue**:
The success response example uses a wrapper object:
```json
{
  "success": true,
  "data": { ... }
}
```
But error response uses:
```json
{
  "success": false,
  "errorMessage": "..."
}
```

This creates asymmetry:
- Success has `data` field
- Error has `errorMessage` field (should it be `error` or `message` to match Spring Boot defaults?)

**Pattern Evidence**:
No existing codebase to reference. However, Spring Boot's default error response format is:
```json
{
  "timestamp": "2026-03-15T10:30:00",
  "status": 400,
  "error": "Bad Request",
  "message": "Invalid appointment time",
  "path": "/api/v1/appointments"
}
```

**Impact Analysis**:
- Client-side parsing requires different logic for success vs error
- Deviates from Spring Boot default error format (may confuse developers)

**Recommendation**:
Choose one of two approaches and document explicitly:

**Option A (Consistent Wrapper)**:
```json
// Success
{"success": true, "data": {...}}
// Error
{"success": false, "error": {"code": "INVALID_TIME", "message": "..."}}
```

**Option B (HTTP-Status-Based, No Wrapper)**:
```json
// Success (200)
{"id": 9876, "status": "confirmed", ...}
// Error (400)
{"timestamp": "...", "status": 400, "error": "Bad Request", "message": "..."}
```

Document the choice in API design section:
```markdown
### Response Format Policy
- **Success Responses**: Return data directly without wrapper (rely on 2xx HTTP status)
- **Error Responses**: Use Spring Boot's default ProblemDetail format (RFC 7807)
- **Validation Errors**: Return field-level errors in `errors` array
```

---

#### 5.3 Moderate Issue: Undocumented Dependency Selection Policy

**Severity**: Moderate
**Location**: Section 2 (Technology Stack)

**Issue**:
The document specifies RestTemplate for HTTP client but does not document:
- Why RestTemplate over WebClient? (RestTemplate is in maintenance mode)
- Library version management policy (Spring Boot BOM, manual versioning?)
- Criteria for adding new dependencies (team approval required?)

**Pattern Evidence**:
No existing codebase to reference.

**Impact Analysis**:
- Risk of technical debt (RestTemplate is deprecated in favor of WebClient)
- Unclear process for dependency updates (security patches, breaking changes)

**Recommendation**:
Add dependency policy section:
```markdown
### Dependency Management Policy
- **HTTP Client**: Use RestTemplate for synchronous calls (if blocking I/O is acceptable) OR WebClient for reactive applications
- **Version Management**: Use Spring Boot Dependency Management BOM (no manual version specification)
- **New Dependencies**: Require tech lead approval, document rationale in ADR (Architecture Decision Record)
- **Security Updates**: Monthly dependency scan using Dependabot/Snyk
```

---

#### 5.4 Minor Issue: Missing Configuration Format Documentation

**Severity**: Minor
**Location**: Section 2 (Technology Stack) and Section 6 (Deployment Policy)

**Issue**:
The document does not specify:
- Configuration file format (application.yml vs application.properties?)
- Environment-specific config strategy (profiles, external config server?)
- Secret management approach (AWS Secrets Manager, environment variables?)

**Pattern Evidence**:
No existing codebase to reference.

**Impact Analysis**:
- Developers may use inconsistent configuration formats
- Risk of hardcoded secrets if policy is unclear

**Recommendation**:
Add configuration management section:
```markdown
### Configuration Management
- **Format**: Use application.yml (hierarchical structure preferred over .properties)
- **Profiles**: Use Spring profiles (application-dev.yml, application-prod.yml)
- **Secrets**: Store in AWS Secrets Manager, inject via Spring Cloud AWS
- **Environment Variables**: Use for deployment-specific values (DB endpoints, Redis URLs)
```

---

## Summary of Findings

### Critical Issues (3)
1. **Mixed table naming conventions** (PascalCase/snake_case/lowercase) in data model
2. **Contradictory error handling strategy** (individual try-catch vs @ControllerAdvice)
3. **Missing directory structure documentation** (package organization undefined)

### Significant Issues (4)
1. **Mixed camelCase/snake_case** between API JSON and database schema
2. **Missing authentication pattern documentation** (filter, token flow unclear)
3. **Missing data access pattern documentation** (query methods, pagination)
4. **Inconsistent API response envelope** (success vs error format asymmetry)

### Moderate Issues (3)
1. **Undocumented file naming convention** (entity-layer pattern implicit)
2. **Incomplete logging pattern documentation** (structured fields, MDC missing)
3. **Undocumented dependency selection policy** (RestTemplate choice unexplained)

### Minor Issues (2)
1. **Lack of cross-cutting concern documentation** (transaction, caching, security layers)
2. **Missing configuration format documentation** (yml vs properties, secrets management)

### Positive Observations (2)
1. **Clear 3-layer architecture** with unidirectional dependencies
2. **Consistent RESTful API endpoint naming** with versioning

---

## Overall Assessment

**Internal Consistency Score**: 6.5/10

The design document demonstrates strong internal consistency in architecture and API design but lacks critical implementation pattern documentation that would be necessary for maintaining consistency across a development team. The most severe issues are:
1. Database naming convention inconsistencies (will cause ORM mapping issues)
2. Contradictory error handling approach (will cause code duplication)
3. Missing directory structure guidance (will cause organizational fragmentation)

**Codebase Alignment Score**: N/A (No existing Java/Spring Boot codebase found)

The experimental repository contains no Java, TypeScript, or Spring Boot implementation files, making codebase consistency evaluation impossible.

---

## Recommended Next Steps

1. **Immediate**: Resolve critical naming convention inconsistency in data model (standardize to snake_case)
2. **High Priority**: Add explicit sections for:
   - Directory structure and package organization
   - Error handling pattern (use @ControllerAdvice)
   - Authentication implementation pattern
   - Data access patterns
3. **Medium Priority**: Document API response format policy and dependency management rules
4. **Low Priority**: Add configuration management and logging implementation details

**Estimated Effort**: 4-6 hours to add missing documentation sections and resolve inconsistencies.

---

**Review Completed**: 2026-02-11
**Methodology**: Multi-pass review (structural understanding + detailed analysis)
**Evidence Base**: Internal document consistency analysis (no external codebase reference available)
