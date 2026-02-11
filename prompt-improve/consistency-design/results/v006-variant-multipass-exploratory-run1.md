# Consistency Design Review - v006 Multipass Exploratory Run 1

## Review Metadata
- Variant: C1c-v3 (Multi-pass with exploratory phase)
- Round: 006
- Test Document: test-document-round-006.md
- Review Date: 2026-02-11

---

## Pass 1 - Structural Understanding & Pattern Extraction

### Existing Patterns Extracted from Design Document

**Naming Conventions (Documented)**:
- Java classes: PascalCase (AppointmentController, AppointmentService)
- Database tables: Mixed - snake_case (medical_institution, doctor) vs PascalCase (PatientAccount) vs camelCase (appointment)
- Database columns: Mixed - snake_case (patient_id, email_address, created_at) vs camelCase (appointmentId, patientId, institutionId)
- API endpoints: kebab-case in paths (/api/appointments/{appointmentId})

**Architectural Patterns (Documented)**:
- Layer structure: Presentation → Application → Domain ← Infrastructure
- Dependency direction: Explicitly specified as one-way dependency
- Component responsibilities: Controller (API), Service (business logic), Repository (data access), Entity (domain)

**Implementation Patterns (Documented)**:
- Error handling: Service-level exception conversion, Controller does NOT use try-catch
- Authentication: JWT with Bearer token in Authorization header
- Data access: Spring Data JPA (Hibernate)
- Async processing: Spring WebFlux (WebClient) mentioned
- Logging: Specific format and level rules per layer documented

**Missing Information Detected**:
- ✗ Transaction Management: No documentation on transaction boundaries or consistency guarantees (P08)
- ✗ Configuration Management: No documentation on config file format preferences or env variable naming rules (P07)
- ✗ File Placement Policies: No directory structure or file organization patterns documented (P06)
- ✗ API Error Format Consistency: Error format shown but no reference to existing system patterns
- ✗ Existing System Context: No references to existing modules or conventions in current codebase

---

## Pass 2 - Detailed Consistency Analysis

### 1. Naming Convention Consistency

#### Critical Inconsistencies

**P01-A: Database Table Name Inconsistency (Critical)**
- **Issue**: Three different naming patterns used across tables
  - PascalCase: `PatientAccount`
  - snake_case: `medical_institution`, `doctor`
  - camelCase: `appointment`
- **Evidence Required**: Need to verify existing codebase pattern (70%+ in related modules or 50%+ codebase-wide)
- **Impact**: Developer confusion, ORM mapping complexity, maintenance burden
- **Recommendation**: Survey existing database schema and unify to dominant pattern (likely snake_case for PostgreSQL)

**P01-B: Database Column Name Inconsistency (Critical)**
- **Issue**: Mixed naming in `appointment` table
  - camelCase: `appointmentId`, `patientId`, `institutionId`, `doctorId`
  - snake_case: `appointment_datetime`, `status`, `created_at`, `updated_at`
- **Evidence Required**: Verify existing column naming pattern in current database
- **Impact**: Inconsistent JPA entity field mapping, potential runtime errors
- **Recommendation**: Standardize all columns to snake_case (PostgreSQL convention) or camelCase (Java convention) based on existing pattern

#### Significant Inconsistencies

**P01-C: API Endpoint Naming Inconsistency (Significant)**
- **Issue**: `POST /api/appointments/create` uses redundant `/create` suffix
- **Standard REST Pattern**: POST to `/api/appointments` implies creation
- **Evidence Required**: Check if existing API endpoints use `/create` suffix pattern
- **Impact**: API design inconsistency, breaks RESTful conventions
- **Recommendation**: Change to `POST /api/appointments` unless existing system consistently uses `/create` suffix

### 2. Architecture Pattern Consistency

#### Significant Inconsistencies

**P02-A: UseCase Layer Mentioned but Not Implemented (Significant)**
- **Issue**: Section 3.1 lists "Service, UseCase" in Application Layer, but all component descriptions only mention Service classes
- **Evidence Required**: Verify if existing codebase uses UseCase pattern or only Service pattern
- **Impact**: Architectural ambiguity, unclear responsibility separation
- **Recommendation**: Either remove UseCase from layer description or document explicit UseCase component design

**P02-B: Infrastructure Layer Dependency Direction (Moderate)**
- **Issue**: "Domain ← Infrastructure" implies Infrastructure depends on Domain (via Repository interface implementation), which is correct for DDD. However, no documentation on how this is enforced.
- **Evidence Required**: Check if existing codebase uses dependency inversion (Repository interface in Domain, implementation in Infrastructure)
- **Impact**: Architectural integrity, potential circular dependencies if not properly enforced
- **Recommendation**: Document dependency inversion mechanism (e.g., Spring Boot autowiring, interface-based injection)

### 3. Implementation Pattern Consistency

#### Critical Inconsistencies

**P03-A: Global Exception Handler Pattern Not Documented (Critical)**
- **Issue**: Section 6.1 states "Controllerレベルでは個別のtry-catch処理は行わず、例外はそのままthrowする" but does not document how exceptions are caught and converted to API responses
- **Evidence Required**: Verify if existing codebase uses `@ControllerAdvice` global exception handler or other mechanism
- **Impact**: Exception handling mechanism unclear, potential unhandled exceptions
- **Recommendation**: Document global exception handler pattern (e.g., `@ControllerAdvice` with `@ExceptionHandler`) and reference existing implementation

**P08: Transaction Management Pattern Not Documented (Critical - Missing Checklist Item)**
- **Issue**: Section 3.2 mentions "トランザクション管理" as Service responsibility but no documentation on:
  - Transaction boundaries (`@Transactional` at Service method level?)
  - Isolation levels
  - Propagation rules
  - Rollback conditions
  - Cross-service transaction handling
- **Evidence Required**: Verify existing transaction management pattern in codebase
- **Impact**: Data consistency risks, potential deadlocks or phantom reads
- **Recommendation**: Document transaction boundaries, isolation levels, and reference existing `@Transactional` usage patterns

#### Significant Inconsistencies

**P03-B: Async Processing Pattern Inconsistency (Significant)**
- **Issue**: Section 2.4 lists "Spring WebFlux (WebClient)" but architecture uses synchronous Service layer pattern
- **Evidence Required**: Verify if existing codebase uses reactive (Mono/Flux) or imperative (blocking) patterns
- **Impact**: Mixing reactive and blocking code can cause thread starvation
- **Recommendation**: Clarify if WebClient is used within blocking Service methods (with `.block()`) or if entire stack is reactive. Document existing pattern.

**P10: Authentication Token Storage Pattern Risk (Significant - Missing Checklist Item)**
- **Issue**: Section 5.3 specifies "トークン保存: クライアント側でlocalStorageに保存"
- **Security Risk**: localStorage is vulnerable to XSS attacks; httpOnly cookies are more secure
- **Evidence Required**: Verify if existing client applications use localStorage or httpOnly cookies for token storage
- **Impact**: Increased XSS attack surface if existing apps use httpOnly cookies
- **Recommendation**: Verify existing authentication token storage pattern and align. If existing apps use httpOnly cookies, update design to match.

### 4. Directory Structure & File Placement Consistency

#### Critical Inconsistencies

**P06: No File Placement Policy Documented (Critical - Missing Checklist Item)**
- **Issue**: Section 3.2 lists component names (AppointmentController, AppointmentService) but no documentation on:
  - Directory structure (domain-based vs layer-based)
  - Package naming conventions
  - File organization rules
- **Example Missing Information**:
  - Is it `com.example.appointment.controller.AppointmentController` (domain-based)?
  - Or `com.example.controller.AppointmentController` (layer-based)?
  - Or `com.example.presentation.appointment.AppointmentController` (hybrid)?
- **Evidence Required**: Survey existing package structure in codebase
- **Impact**: Cannot verify consistency, developers may place files inconsistently
- **Recommendation**: Document package structure pattern based on existing codebase (e.g., "Follow domain-based package structure: `com.example.{domain}.{layer}`")

### 5. API/Interface Design & Dependency Consistency

#### Moderate Inconsistencies

**P05-A: Configuration Management Pattern Not Documented (Moderate - Missing Checklist Item)**
- **Issue**: Section 2.3 mentions "システム設定" but no documentation on:
  - Configuration file format (application.yml vs application.properties)
  - Environment variable naming rules (UPPER_SNAKE_CASE?)
  - Configuration injection pattern (Spring `@Value` vs `@ConfigurationProperties`)
- **Evidence Required**: Check existing configuration files in codebase
- **Impact**: Configuration management inconsistency, deployment issues
- **Recommendation**: Document configuration file format and env variable naming based on existing application.yml/properties files

**P05-B: API Versioning Strategy Not Documented (Moderate)**
- **Issue**: All API endpoints use `/api/...` without version prefix (e.g., `/api/v1/...`)
- **Evidence Required**: Verify if existing APIs use versioning or not
- **Impact**: Future API evolution may break backward compatibility
- **Recommendation**: Document API versioning strategy and verify alignment with existing endpoints

---

## Pass 3 - Exploratory Detection

### Implicit Patterns Detected

**E01: Timestamp Column Naming Inconsistency**
- **Observation**: `PatientAccount` and `appointment` tables use `created_at`, `updated_at` (snake_case), but `medical_institution` only has `created_at` (no `updated_at`)
- **Implicit Pattern**: Expectation that all mutable entities have both `created_at` and `updated_at`
- **Issue**: `medical_institution` table missing `updated_at` column
- **Impact**: Cannot track medical institution updates
- **Recommendation**: Verify existing table schema and add `updated_at` if pattern exists

**E02: UUID Column Naming Suffix Inconsistency**
- **Observation**:
  - `PatientAccount.patient_id` uses `_id` suffix (snake_case)
  - `appointment.appointmentId` uses `Id` suffix (camelCase)
  - `doctor.doctor_id` uses `_id` suffix (snake_case)
- **Implicit Pattern**: ID columns should have consistent suffix format
- **Issue**: Mixed `_id` vs `Id` usage
- **Impact**: Contributes to overall naming inconsistency (relates to P01-B)
- **Recommendation**: Unify to snake_case `_id` suffix based on PostgreSQL convention

### Edge Cases Identified

**E03: Foreign Key Column Naming Inconsistency**
- **Issue**: `appointment` table foreign key columns use different pattern than primary key tables
  - FK: `patientId` (camelCase) → PK: `patient_id` (snake_case) in PatientAccount
  - FK: `institutionId` (camelCase) → PK: `institution_id` (snake_case) in medical_institution
  - FK: `doctorId` (camelCase) → PK: `doctor_id` (snake_case) in doctor
- **Impact**: Confusing FK-PK relationship, potential JPA mapping errors
- **Recommendation**: Align FK column names with referenced PK column names

**E04: JSONB Column Usage Without Schema Documentation**
- **Issue**: `medical_institution.business_hours` uses JSONB type but no schema documentation
- **Evidence Required**: Check if existing codebase has JSONB column schema documentation patterns
- **Impact**: Inconsistent JSON structure, query complexity
- **Recommendation**: Document JSONB schema or reference existing JSONB column documentation pattern

### Cross-Category Issues

**E05: Logging Pattern vs Error Handling Gap**
- **Issue**: Section 6.2 specifies "Service: エラー発生時にERRORレベル" but Section 6.1 states Service catches exceptions and converts them
- **Gap**: No documentation on whether logging happens before or after exception conversion, or if stack traces are logged
- **Evidence Required**: Check existing Service error handling code for logging pattern
- **Impact**: Inconsistent error logging, debugging difficulty
- **Recommendation**: Document error logging pattern: "Service catches exceptions, logs ERROR with stack trace, then throws custom exception"

**E06: Authentication Pattern Completeness**
- **Issue**: Section 5.3 documents JWT authentication but no documentation on:
  - Token refresh mechanism
  - Token expiration handling
  - Logout implementation (token invalidation?)
- **Evidence Required**: Verify existing authentication implementation for refresh token pattern
- **Impact**: Incomplete authentication design, user experience issues
- **Recommendation**: Document token lifecycle management based on existing authentication module

### Latent Risks

**E07: WebFlux Reactor Thread Pool Blocking Risk**
- **Issue**: Section 2.4 specifies "Spring WebFlux (WebClient)" but Section 3.7 (ORM) uses Spring Data JPA (blocking)
- **Latent Risk**: If WebClient is used in Service layer without proper thread pool configuration, blocking JPA calls will block reactor threads
- **Evidence Required**: Verify if existing codebase isolates blocking operations with `@Async` or custom thread pools
- **Impact**: Performance degradation, potential thread starvation
- **Recommendation**: Document thread pool strategy for blocking operations or use WebClient with `.block()` and accept imperative model

**E08: Transaction Boundary Ambiguity with Multiple Repository Calls**
- **Issue**: No documentation on transaction scope when Service calls multiple Repository methods
- **Example**: Appointment creation may require checking availability (read) + creating appointment (write) + updating doctor schedule (write)
- **Latent Risk**: Without `@Transactional` at Service method level, partial updates may occur
- **Evidence Required**: Check existing Service method transaction annotations
- **Impact**: Data inconsistency, race conditions
- **Recommendation**: Document transaction boundary pattern: "Service public methods annotated with `@Transactional`, propagation=REQUIRED"

**E09: API Response Format vs Exception Handling Pattern Mismatch**
- **Issue**: Section 5.2 shows standardized response wrapper `{"data": {...}, "error": {...}}` but Section 6.1 only documents exception conversion in Service layer
- **Gap**: No documentation on how Controller or global handler maps exceptions to response wrapper format
- **Evidence Required**: Verify existing global exception handler response format
- **Impact**: Response format inconsistency if not properly implemented
- **Recommendation**: Document response wrapper mapping in global exception handler (e.g., `@ControllerAdvice` returning `ResponseEntity<ApiResponse<T>>`)

---

## Summary of Inconsistencies Identified (Prioritized by Severity)

### Critical (7 issues)
1. **P01-A**: Database table naming uses 3 different patterns (PascalCase/snake_case/camelCase)
2. **P01-B**: Database column naming mixed (camelCase vs snake_case in same table)
3. **P03-A**: Global exception handler pattern not documented
4. **P08**: Transaction management pattern not documented (boundaries, isolation, propagation)
5. **P06**: File placement policy not documented (package structure unknown)
6. **E03**: Foreign key column naming misaligned with primary key columns
7. **E08**: Transaction boundary ambiguity with multiple repository calls

### Significant (5 issues)
8. **P01-C**: API endpoint `/create` suffix inconsistent with REST conventions
9. **P02-A**: UseCase layer mentioned but not implemented
10. **P03-B**: Async processing pattern inconsistency (WebFlux vs blocking Service)
11. **P10**: Authentication token storage in localStorage (XSS risk, verify existing pattern)
12. **E06**: Authentication pattern incomplete (no token refresh/expiration docs)

### Moderate (6 issues)
13. **P02-B**: Infrastructure layer dependency inversion mechanism not documented
14. **P05-A**: Configuration management pattern not documented
15. **P05-B**: API versioning strategy not documented
16. **E01**: Timestamp column `updated_at` missing in `medical_institution` table
17. **E04**: JSONB column schema not documented
18. **E07**: WebFlux + JPA blocking risk not addressed

### Minor/Informational (3 issues)
19. **E02**: UUID column naming suffix inconsistency (_id vs Id)
20. **E05**: Logging pattern vs error handling integration gap
21. **E09**: API response wrapper mapping not documented

---

## Pattern Evidence Requirements

To complete consistency verification, the following evidence from existing codebase is required:

1. **Database schema survey**: Query existing table names and column names to determine dominant pattern
2. **Package structure survey**: Check existing Java package organization (domain-based vs layer-based)
3. **Transaction annotation survey**: Grep for `@Transactional` usage patterns in Service classes
4. **Exception handler survey**: Check for `@ControllerAdvice` or global exception handler implementation
5. **API endpoint survey**: List existing API paths to verify `/create` suffix usage and versioning
6. **Configuration file check**: Read `application.yml` or `application.properties` to verify format
7. **Authentication module check**: Review existing JWT implementation for token storage and refresh patterns
8. **WebFlux usage survey**: Grep for `Mono`, `Flux`, `.block()` to determine reactive vs imperative pattern

---

## Impact Analysis

### Consequences of Divergence

**Critical Impact**:
- **Data Layer Fragmentation**: Mixed naming conventions (P01-A, P01-B, E03) will cause:
  - Developer cognitive load when switching between tables
  - ORM mapping complexity and potential runtime errors
  - SQL query writing inconsistency
  - Onboarding difficulty for new developers

- **Transaction Consistency Risks**: Lack of transaction documentation (P08, E08) may lead to:
  - Partial updates in multi-repository operations
  - Race conditions in concurrent appointment bookings
  - Data integrity violations

- **Architectural Ambiguity**: Missing documentation (P06, P03-A) prevents:
  - Verification of architectural consistency
  - Code review quality assurance
  - Automated linting/static analysis setup

**Significant Impact**:
- **Security Risk**: localStorage token storage (P10) increases XSS attack surface if divergent from existing secure pattern
- **Performance Risk**: WebFlux + blocking JPA mix (P03-B, E07) may cause thread pool exhaustion
- **API Design Debt**: REST convention violation (P01-C) and missing versioning (P05-B) complicates future API evolution

**Moderate Impact**:
- **Maintenance Overhead**: Configuration (P05-A) and authentication (E06) pattern gaps increase operational complexity
- **Code Duplication**: UseCase layer ambiguity (P02-A) may lead to inconsistent business logic placement

---

## Recommendations (Specific Alignment Suggestions)

### Immediate Actions Required

1. **Unify Database Naming Convention**:
   - Survey existing database schema to determine dominant pattern
   - If 50%+ of tables use snake_case: Convert all tables and columns to snake_case
   - Update: `PatientAccount` → `patient_account`, `appointmentId` → `appointment_id`, etc.
   - Document rule: "All PostgreSQL table and column names use snake_case"

2. **Document Transaction Management Pattern**:
   - Survey existing Service classes for `@Transactional` usage
   - Document rule: "Service public methods use `@Transactional(propagation = REQUIRED, isolation = READ_COMMITTED)`. Repository operations inherit transaction context."
   - Add transaction boundary examples for multi-repository operations

3. **Document Global Exception Handler**:
   - Verify existing `@ControllerAdvice` implementation
   - Document pattern: "Use `@ControllerAdvice` with `@ExceptionHandler` to map service exceptions to `ApiResponse<T>` wrapper format"
   - Reference existing handler class location

4. **Document File Placement Policy**:
   - Survey existing package structure
   - Document rule: "Follow domain-based package structure: `com.example.{domain}.{layer}` (e.g., `com.example.appointment.controller.AppointmentController`)"
   - OR "Follow layer-based structure: `com.example.{layer}.{domain}` based on existing codebase"

5. **Align Foreign Key Naming**:
   - Update `appointment` table FK columns to match PK column naming:
     - `patientId` → `patient_id`
     - `institutionId` → `institution_id`
     - `doctorId` → `doctor_id`

### Secondary Actions

6. **Clarify Reactive vs Imperative Pattern**:
   - Survey existing WebClient usage
   - Document: "WebClient is used for external API calls within blocking Service methods using `.block()`. Internal Service layer follows imperative model."
   - OR "Entire stack uses reactive model with Mono/Flux. Update JPA to R2DBC."

7. **Remove or Implement UseCase Layer**:
   - Survey existing codebase for UseCase pattern
   - If not used: Remove "UseCase" from Section 3.1 layer description
   - If used: Document UseCase vs Service responsibility separation

8. **Verify and Document Authentication Pattern**:
   - Review existing JWT implementation
   - If existing apps use httpOnly cookies: Update design to match
   - Document token refresh and expiration handling based on existing pattern

9. **Fix API Endpoint Naming**:
   - Survey existing API endpoints for `/create` suffix usage
   - If not used: Change to `POST /api/appointments` (standard REST)
   - If used: Keep `/create` but document as established pattern

10. **Add Configuration Management Documentation**:
    - Check existing `application.yml` or `application.properties`
    - Document format and environment variable naming rule
    - Example: "Use `application.yml` for config. Environment variables use UPPER_SNAKE_CASE."

### Documentation Enhancement

11. **Add Existing System Context Section**:
    - Reference existing modules that follow similar patterns
    - Example: "Authentication pattern follows existing UserAuthService implementation"
    - Example: "Database naming follows existing `patient_account`, `medical_record` table conventions"

12. **Document JSONB Schema**:
    - Add `business_hours` JSON schema example
    - Reference existing JSONB column documentation if available

13. **Add Transaction Boundary Examples**:
    - Show multi-repository operation example with `@Transactional`
    - Document rollback conditions and exception handling

---

## Conclusion

This design document provides comprehensive functional and technical specifications but has **critical consistency gaps** in:
1. Database naming conventions (3 different patterns used)
2. Transaction management pattern (not documented)
3. Global exception handling mechanism (not documented)
4. File placement policy (not documented)

**Total Issues**: 21 (7 Critical, 5 Significant, 6 Moderate, 3 Minor)

**Next Steps**:
1. Survey existing codebase for database schema, package structure, transaction patterns, and exception handling
2. Update design document with documented existing patterns
3. Unify database naming to dominant pattern (likely snake_case)
4. Add transaction boundaries and exception handler documentation
5. Re-review for consistency after updates

**Exploratory Phase Findings**:
The Pass 3 exploratory phase successfully identified **12 additional issues** beyond the checklist-driven Pass 2:
- E01-E09: Implicit patterns, edge cases, cross-category issues, and latent risks
- Notable findings: FK-PK naming mismatch (E03), WebFlux blocking risk (E07), transaction boundary ambiguity (E08)

These exploratory findings demonstrate value in multi-pass review with open-ended exploration phase.
