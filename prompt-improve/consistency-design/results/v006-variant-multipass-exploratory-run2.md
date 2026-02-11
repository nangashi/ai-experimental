# Consistency Design Review: Healthcare Appointment Scheduling System

## Pass 1 - Structural Understanding & Pattern Extraction

### Document Scope and Intent
This design document describes a healthcare appointment scheduling platform integrating multiple medical institutions, built with Java 17/Spring Boot 3.2 backend, React 18/TypeScript frontend, PostgreSQL 15 database, and AWS infrastructure.

### Explicitly Documented Patterns
1. **Naming Conventions (Partial)**:
   - Table names: Mixed (snake_case: `medical_institution`, `doctor`, `appointment`; PascalCase: `PatientAccount`)
   - Column names: Mixed (snake_case: `patient_id`, `email_address`; camelCase: `appointmentId`, `patientId`, `institutionId`, `doctorId`)
   - API endpoints: kebab-case with resource pluralization (`/api/appointments`, `/api/institutions`)

2. **Architectural Patterns**:
   - Layer composition: 4-layer architecture (Presentation → Application → Domain ← Infrastructure)
   - Dependency direction: Explicitly documented as "Presentation → Application → Domain ← Infrastructure"

3. **Implementation Patterns**:
   - Error handling: Service-level catch → custom exception conversion, Controller-level no try-catch (throw through)
   - Authentication: Spring Security + JWT, Bearer scheme, localStorage storage
   - Data access: Spring Data JPA (Hibernate)
   - Async processing: Spring WebFlux (WebClient) for HTTP
   - Logging: SLF4J + Logback with structured format

### Missing Information Assessment

**CRITICAL GAPS IDENTIFIED:**

1. **❌ Naming Conventions** (Checklist Item 1): **PARTIALLY MISSING**
   - Table naming: Inconsistent case style documented (PatientAccount vs medical_institution)
   - Column naming: Inconsistent case style documented (snake_case vs camelCase)
   - File naming: NOT documented
   - Class naming: NOT documented

2. **❌ Transaction Management** (Checklist Item 4): **COMPLETELY MISSING**
   - Transaction boundaries: NOT documented
   - Consistency guarantees: NOT documented
   - Transaction scope (@Transactional placement): NOT documented

3. **❌ File Placement Policies** (Checklist Item 5): **COMPLETELY MISSING**
   - Directory structure rules: NOT documented
   - Package organization patterns: NOT documented

4. **❌ API/Interface Design Standards** (Checklist Item 6): **PARTIALLY MISSING**
   - Dependency management policies: NOT documented (no guidance on library selection criteria, version pinning)

5. **❌ Configuration Management** (Checklist Item 7): **COMPLETELY MISSING**
   - Configuration file formats: NOT documented
   - Environment variable naming rules: NOT documented
   - Property management patterns: NOT documented

6. **✓ Existing System Context** (Checklist Item 9): **MISSING**
   - No references to existing modules, patterns, or conventions in current codebase

**PRESENT INFORMATION:**

- ✓ Architectural Patterns (Item 2): Layer composition and dependency direction documented
- ✓ Implementation Patterns (Item 3): Error handling, authentication, data access, async, logging patterns documented
- ✓ API Design (Item 6, partial): API naming and response formats documented
- ✓ Authentication & Authorization (Item 8): Token storage and session management documented

## Pass 2 - Detailed Consistency Analysis

### 1. Naming Convention Consistency

#### 1.1 Table/Column Naming Inconsistency (CRITICAL)

**Evidence of Inconsistency:**
- Table names mix case styles:
  - `PatientAccount` (PascalCase)
  - `medical_institution` (snake_case)
  - `appointment` (snake_case)
  - `doctor` (snake_case)

- Column names mix case styles within appointment table:
  - `appointmentId`, `patientId`, `institutionId`, `doctorId` (camelCase)
  - `appointment_datetime`, `created_at`, `updated_at` (snake_case)

**Pattern Verification Needed:**
Without access to existing codebase, cannot verify which is the dominant pattern. However, within this document itself, there's clear inconsistency:
- PatientAccount table uses snake_case columns (`patient_id`, `email_address`, `date_of_birth`)
- appointment table uses camelCase for FK columns but snake_case for other columns

**Impact:**
- Database schema fragmentation
- ORM mapping complexity
- Developer confusion about which convention to follow

#### 1.2 Entity Name vs Table Name Mismatch

**Evidence:**
- Document mentions "Patient" entity but table is "PatientAccount"
- Document mentions "Appointment" entity but doesn't clarify if Java class is `Appointment` or `AppointmentEntity`

**Pattern Verification Needed:**
Need to check if existing codebase uses Entity/Domain suffix or direct mapping.

### 2. Architecture Pattern Consistency

#### 2.1 Layer Responsibility Clarity (MODERATE)

**Documented Pattern:**
- Domain Layer: "Entity, Repository Interface"
- Application Layer: "Service, UseCase"

**Potential Inconsistency:**
Document shows `AppointmentService` in Application Layer but doesn't clarify the distinction between Service and UseCase. Are they separate classes or is "UseCase" a conceptual label?

**Pattern Verification Needed:**
Need to check if existing codebase uses separate Service and UseCase classes or merges them.

### 3. Implementation Pattern Consistency

#### 3.1 Transaction Management Pattern (CRITICAL - MISSING)

**Missing Documentation:**
- No specification of where `@Transactional` annotations should be placed
- No documentation of transaction propagation requirements
- No guidance on transaction boundary for multi-repository operations

**Impact:**
- Risk of data inconsistency
- Potential for phantom reads or lost updates
- Unclear rollback scope

**Pattern Verification Needed:**
Must check existing codebase for:
- Service-level @Transactional pattern
- Repository-level transaction handling
- Transaction isolation levels

#### 3.2 Error Handling Pattern Inconsistency (MODERATE)

**Documented Pattern:**
"各ServiceメソッドでビジネスロジックのExceptionをcatchし、適切なエラーメッセージを含むカスタム例外に変換して返却する。Controllerレベルでは個別のtry-catch処理は行わず、例外はそのままthrowする。"

**Missing Specification:**
- What is the custom exception class name/structure?
- Does existing codebase use `@ControllerAdvice` global exception handler?
- Are there specific exception types for different error categories?

**Pattern Verification Needed:**
Check if existing code uses:
- Global `@ExceptionHandler` in `@ControllerAdvice` class
- Domain-specific exception classes (e.g., `AppointmentNotFoundException`)
- Exception hierarchy structure

#### 3.3 Authentication Token Storage Anti-Pattern (CRITICAL)

**Documented Pattern:**
"トークン保存: クライアント側でlocalStorageに保存"

**Security Concern:**
localStorage is vulnerable to XSS attacks. However, if this is the existing codebase pattern, the design is "consistent" even though it's an anti-pattern.

**Pattern Verification Needed:**
Must verify if existing codebase actually uses localStorage or if this is a new anti-pattern being introduced.

### 4. Directory Structure & File Placement Consistency

#### 4.1 Package Structure (CRITICAL - COMPLETELY MISSING)

**Missing Documentation:**
- No specification of package organization (domain-based vs layer-based)
- No file naming conventions for Java classes
- No guidance on where to place DTOs, Mappers, Validators

**Examples of Missing Guidance:**
- Should structure be `com.example.appointment.controller`, `com.example.appointment.service`, `com.example.appointment.domain`? (domain-first)
- Or `com.example.controller.appointment`, `com.example.service.appointment`, `com.example.domain.appointment`? (layer-first)

**Impact:**
Developers cannot determine correct file placement without this guidance.

### 5. API/Interface Design & Dependency Consistency

#### 5.1 API Endpoint Naming Inconsistency (SIGNIFICANT)

**Evidence of Inconsistency:**
- `POST /api/appointments/create` - uses action verb "create"
- `PUT /api/appointments/{appointmentId}` - uses HTTP verb without action in path
- `DELETE /api/appointments/{appointmentId}` - uses HTTP verb without action in path
- `GET /api/appointments/{appointmentId}` - uses HTTP verb without action in path

**RESTful Pattern:**
Standard RESTful convention avoids action verbs in paths:
- Should be `POST /api/appointments` instead of `POST /api/appointments/create`

**Pattern Verification Needed:**
Check if existing API endpoints use:
- RESTful style (POST /api/resources)
- RPC style (POST /api/resources/create)

#### 5.2 Response Format Consistency (POSITIVE ALIGNMENT)

**Documented Pattern:**
```json
{
  "data": {...},
  "error": null
}
```

**Consistency Check:**
Pattern is clearly specified and uniform. Good consistency within this design.

**Pattern Verification Needed:**
Verify this matches existing API response structure in codebase.

#### 5.3 Dependency Management (CRITICAL - MISSING)

**Missing Documentation:**
- No library version pinning policy
- No criteria for library selection (e.g., must existing code use specific versions of Spring Boot, React)
- No guidance on when to introduce new dependencies

**Impact:**
Risk of version conflicts and dependency fragmentation.

### 6. Configuration Management Consistency (CRITICAL - COMPLETELY MISSING)

**Missing Documentation:**
- application.yml vs application.properties choice not specified
- Environment variable naming convention not specified (SCREAMING_SNAKE_CASE? camelCase?)
- Configuration profile structure not documented (dev, staging, prod separation)

**Impact:**
Developers cannot create consistent configuration files.

## Pass 3 - Exploratory Detection

### E1. Implicit Pattern: Entity-Table Naming Divergence

**Detection:**
While Pass 2 identified table naming inconsistency, deeper analysis reveals a systematic pattern:
- Document describes domain entities with simple names (Patient, Appointment, Doctor)
- Tables use either exact lowercase (appointment, doctor) or modified names (PatientAccount vs Patient)

**Latent Risk:**
This creates ambiguity in ORM mapping. Without `@Table(name="...")` annotation guidance, developers won't know which naming strategy to follow.

**Missing Specification:**
- Should entity class names match table names exactly (PatientAccount.java)?
- Or should entities use domain names with @Table annotations (Patient.java with @Table(name="PatientAccount"))?

### E2. Cross-Category Issue: FK Column Naming vs Referenced Table Naming

**Detection:**
FK column names follow camelCase (`patientId`, `institutionId`) but referenced table names are inconsistent:
- `patientId` → `PatientAccount` (PascalCase table)
- `institutionId` → `medical_institution` (snake_case table)

**Systematic Problem:**
No documented rule for deriving FK column names from table names. Current approach seems to be:
- Take table name
- Remove underscores
- Convert to camelCase
- Add "Id" suffix

But this breaks when table is already PascalCase (PatientAccount → patientId loses the "Account" part).

### E3. Latent Risk: Repository Method Naming

**Detection:**
Document specifies "AppointmentRepository" but doesn't document method naming conventions for:
- Custom query methods (findByPatientIdAndStatus? findAppointmentsByPatientIdAndStatus?)
- Native query methods
- Derived query methods

**Pattern Verification Needed:**
Check if existing repositories follow Spring Data JPA standard conventions or use custom prefixes/suffixes.

### E4. Edge Case: Async Processing Pattern Mismatch

**Detection:**
Document specifies:
- "HTTP通信: Spring WebFlux (WebClient)" - reactive/async
- "ORM: Spring Data JPA (Hibernate)" - blocking/sync

**Potential Inconsistency:**
Using reactive WebClient in a blocking JPA context creates async/sync boundary issues.

**Pattern Verification Needed:**
Check if existing codebase:
- Uses Spring WebFlux for entire stack (R2DBC instead of JPA)
- Mixes WebClient in MVC context (need to handle blocking properly)
- Uses RestTemplate instead (consistent blocking)

### E5. Implicit Pattern: DTO Naming and Location

**Detection:**
API section shows request/response formats but doesn't specify:
- DTO class naming (AppointmentDTO? AppointmentResponse? AppointmentRequest?)
- DTO package location
- DTO-Entity mapping responsibility (Mapper class? Service method? Controller?)

**Missing Specification:**
No guidance on DTO transformation patterns used in existing codebase.

### E6. Cross-Cutting Issue: Timestamp Column Consistency

**Detection:**
All tables use `created_at` and `updated_at` (snake_case) consistently, but:
- appointment table mixes this with camelCase FK columns
- No specification of automatic timestamp management (@CreatedDate, @LastModifiedDate from Spring Data JPA, or database triggers)

**Pattern Verification Needed:**
Check if existing entities use:
- JPA lifecycle callbacks (@PrePersist, @PreUpdate)
- Spring Data JPA auditing (@CreatedDate, @LastModifiedDate)
- Database-level DEFAULT CURRENT_TIMESTAMP

### E7. Latent Risk: API Versioning Strategy

**Detection:**
All endpoints use `/api/` prefix but no version indicator (`/api/v1/`, `/api/v2/`).

**Pattern Verification Needed:**
Check if existing APIs:
- Use version in path (/api/v1/)
- Use version in header (Accept: application/vnd.company.v1+json)
- No versioning (breaking changes handled differently)

**Impact:**
If existing APIs use versioning, this design is inconsistent.

### E8. Edge Case: UUID Generation Strategy

**Detection:**
All ID columns use UUID type but doesn't specify:
- Client-generated UUIDs (UUID.randomUUID() in application)
- Database-generated UUIDs (gen_random_uuid() in PostgreSQL)
- Specific UUID version (v4 random? v7 time-ordered?)

**Pattern Verification Needed:**
Check existing entity ID generation strategy (@GeneratedValue configuration).

## Inconsistencies Identified (Prioritized by Severity)

### CRITICAL (Must Fix Before Implementation)

**C1. Transaction Management Pattern Completely Undocumented** ⚠️
- **Category:** Implementation Pattern (Missing Checklist Item 4)
- **Issue:** No specification of transaction boundaries, @Transactional placement, or consistency guarantees
- **Codebase Reference Needed:** Check existing Service classes for transaction annotation patterns
- **Impact:** Data corruption risk, lost updates, inconsistent state
- **Recommendation:** Add section 6.5 documenting transaction management pattern

**C2. Table and Column Naming Case Inconsistency** ⚠️
- **Category:** Naming Convention
- **Issue:** Mixed PascalCase (PatientAccount) and snake_case (medical_institution) for tables; mixed camelCase (appointmentId) and snake_case (appointment_datetime) for columns
- **Codebase Reference Needed:** Execute `SELECT table_name FROM information_schema.tables` and `SHOW COLUMNS` to verify existing pattern
- **Impact:** Schema fragmentation, ORM mapping confusion
- **Recommendation:** Standardize on single case style (verify existing pattern first)

**C3. Package Structure and File Placement Completely Undocumented** ⚠️
- **Category:** Directory Structure (Missing Checklist Item 5)
- **Issue:** No specification of package organization (domain-first vs layer-first), DTO location, Mapper location
- **Codebase Reference Needed:** Check existing package structure pattern
- **Impact:** Files placed incorrectly, codebase navigation difficulty
- **Recommendation:** Document package naming convention in section 3.1

**C4. Configuration Management Completely Undocumented** ⚠️
- **Category:** Configuration (Missing Checklist Item 7)
- **Issue:** No specification of application.yml vs .properties, environment variable naming, profile structure
- **Codebase Reference Needed:** Check existing config file format
- **Impact:** Configuration file inconsistency
- **Recommendation:** Add section 6.6 for configuration management

**C5. Async/Sync Pattern Mismatch** ⚠️
- **Category:** Implementation Pattern
- **Issue:** Spring WebFlux (reactive) with Spring Data JPA (blocking) creates execution model conflict
- **Codebase Reference Needed:** Check if existing code uses WebFlux with JPA or uses RestTemplate with JPA
- **Impact:** Performance degradation, potential thread starvation
- **Recommendation:** Verify existing HTTP client choice; if codebase uses RestTemplate, align with that; if using WebFlux, verify R2DBC is not the standard

### SIGNIFICANT (Affects Developer Experience)

**S1. API Endpoint Naming Inconsistency**
- **Category:** API Design
- **Issue:** `POST /api/appointments/create` uses action verb; other endpoints are RESTful
- **Codebase Reference Needed:** Check existing API endpoint patterns (RESTful vs RPC style)
- **Impact:** API design inconsistency
- **Recommendation:** Remove "/create" if existing APIs are RESTful, or add action verbs to all if existing uses RPC style

**S2. Entity-Table Name Mapping Strategy Undocumented**
- **Category:** Naming Convention, Implementation Pattern
- **Issue:** Unclear if entity classes should match table names (PatientAccount.java) or use domain names with @Table (Patient.java)
- **Codebase Reference Needed:** Check existing entity class naming pattern
- **Impact:** ORM configuration confusion
- **Recommendation:** Document entity naming convention and @Table annotation usage

**S3. Exception Handling Class Names and Structure Undocumented**
- **Category:** Implementation Pattern
- **Issue:** Error handling pattern described but custom exception class names and @ControllerAdvice usage not specified
- **Codebase Reference Needed:** Check for existing GlobalExceptionHandler or @ControllerAdvice classes
- **Impact:** Inconsistent exception class proliferation
- **Recommendation:** Document exception class hierarchy and global handler pattern

**S4. DTO Naming and Mapping Pattern Undocumented**
- **Category:** Naming Convention, Implementation Pattern
- **Issue:** No specification of DTO class naming, location, or mapping strategy
- **Codebase Reference Needed:** Check existing DTO naming (suffix? prefix?) and mapper pattern (MapStruct? manual?)
- **Impact:** DTO class naming fragmentation
- **Recommendation:** Document DTO conventions in section 4.1 or 5.2

### MODERATE (Affects Consistency, Lower Immediate Impact)

**M1. Repository Method Naming Convention Undocumented**
- **Category:** Naming Convention
- **Issue:** No guidance on custom query method naming
- **Codebase Reference Needed:** Check existing repository method names
- **Impact:** Method naming inconsistency
- **Recommendation:** Document repository method naming pattern

**M2. Timestamp Management Strategy Undocumented**
- **Category:** Implementation Pattern
- **Issue:** created_at/updated_at columns present but automatic management strategy not specified
- **Codebase Reference Needed:** Check if existing entities use @CreatedDate/@LastModifiedDate or database triggers
- **Impact:** Inconsistent timestamp update mechanisms
- **Recommendation:** Document timestamp auditing pattern

**M3. UUID Generation Strategy Undocumented**
- **Category:** Implementation Pattern
- **Issue:** UUID type used but generation strategy (client vs database, UUID version) not specified
- **Codebase Reference Needed:** Check existing @GeneratedValue configuration
- **Impact:** ID generation inconsistency
- **Recommendation:** Document UUID generation strategy in section 4.2

**M4. API Versioning Strategy Undocumented**
- **Category:** API Design
- **Issue:** No version indicator in API paths
- **Codebase Reference Needed:** Check if existing APIs use /v1/ prefix or header-based versioning
- **Impact:** API evolution difficulty if existing pattern differs
- **Recommendation:** Verify existing versioning approach and document

**M5. Dependency Management Policy Undocumented**
- **Category:** API/Interface Design (Partial Missing Checklist Item 6)
- **Issue:** No guidance on library selection criteria, version pinning
- **Codebase Reference Needed:** Check existing pom.xml or build.gradle for version management patterns
- **Impact:** Dependency version conflicts
- **Recommendation:** Document dependency selection criteria

**M6. Service vs UseCase Distinction Unclear**
- **Category:** Architecture Pattern
- **Issue:** Application Layer lists "Service, UseCase" but doesn't clarify if separate classes
- **Codebase Reference Needed:** Check if existing code has UseCase classes separate from Service
- **Impact:** Layer responsibility confusion
- **Recommendation:** Clarify if UseCase is conceptual or requires separate classes

### INFORMATIONAL (Context Missing)

**I1. No Existing Codebase References**
- **Category:** Existing System Context (Missing Checklist Item 9)
- **Issue:** Design doesn't reference existing modules, patterns, or conventions
- **Impact:** Cannot verify true consistency without codebase access
- **Recommendation:** Add section 1.4 "Existing System Context" referencing established patterns

**I2. Authentication Token Storage Pattern Verification Needed**
- **Category:** Authentication (Security)
- **Issue:** localStorage usage documented but unclear if this matches existing pattern or is new anti-pattern
- **Codebase Reference Needed:** Check existing frontend authentication token storage
- **Impact:** If existing uses httpOnly cookies, this is major security regression
- **Recommendation:** Verify existing token storage pattern before implementation

## Pattern Evidence

All "Codebase Reference Needed" items require actual codebase access. Unable to provide specific file references without access to existing implementation.

**Recommended Verification Commands:**
```bash
# Table naming pattern
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

# Package structure
find src -type f -name "*.java" | head -20

# Transaction annotations
grep -r "@Transactional" src/

# Exception handling
grep -r "@ControllerAdvice" src/

# Repository patterns
find src -name "*Repository.java" -exec head -20 {} \;

# Config files
ls -la src/main/resources/application.*

# DTO patterns
find src -name "*DTO.java" -o -name "*Request.java" -o -name "*Response.java" | head -10
```

## Impact Analysis

### High-Impact Inconsistencies

1. **Transaction Management (C1):** Could lead to data corruption in production
2. **Naming Inconsistency (C2):** Fragments schema, creates long-term maintenance burden
3. **Async/Sync Mismatch (C5):** Performance degradation, potential production issues

### Medium-Impact Inconsistencies

4. **Package Structure (C3):** Slows development, navigation difficulty
5. **Configuration Management (C4):** Deployment errors, environment-specific issues
6. **API Naming (S1):** API consumer confusion

### Low-Impact But Widespread

7. **Missing DTO/Exception/Repository patterns (S2-S4, M1):** Accumulates technical debt over time

## Recommendations

### Immediate Actions (Before Implementation)

1. **Verify Existing Patterns First:**
   Execute pattern verification commands above to check existing codebase conventions for:
   - Table/column naming case style
   - Package organization structure
   - Transaction annotation placement
   - HTTP client choice (WebFlux vs RestTemplate)
   - API endpoint style (RESTful vs RPC)

2. **Document Missing Critical Patterns:**
   Add the following sections to design document:
   - **Section 3.1.1:** Package structure and file placement rules
   - **Section 4.2.1:** Entity-table name mapping strategy
   - **Section 4.2.2:** Database naming conventions (standardize case)
   - **Section 6.5:** Transaction management pattern
   - **Section 6.6:** Configuration management conventions

3. **Resolve Naming Inconsistencies:**
   - Standardize table names to single case style (recommend snake_case for PostgreSQL)
   - Standardize column names to single case style
   - Update appointment table: either all snake_case or all camelCase
   - Fix PatientAccount to patient_account if snake_case is standard

4. **Clarify Implementation Patterns:**
   - Document @Transactional placement (Service-level recommended)
   - Specify exception class naming and @ControllerAdvice structure
   - Document DTO naming and mapping approach
   - Clarify Service vs UseCase usage

### Alignment-Specific Recommendations

**If Existing Codebase Uses:**

- **snake_case tables:** Change PatientAccount → patient_account
- **camelCase columns:** Change all created_at, updated_at, appointment_datetime → createdAt, updatedAt, appointmentDatetime
- **RESTful APIs:** Change `POST /api/appointments/create` → `POST /api/appointments`
- **RPC-style APIs:** Change other endpoints to include action verbs
- **RestTemplate:** Change HTTP client from WebFlux WebClient to RestTemplate
- **Domain-first packages:** Document as `com.example.appointment.controller` pattern
- **Layer-first packages:** Document as `com.example.controller.appointment` pattern

### Quality Gates

Before proceeding with implementation:
- [ ] All CRITICAL inconsistencies (C1-C5) resolved
- [ ] Naming conventions documented and standardized
- [ ] Transaction pattern documented
- [ ] Package structure documented
- [ ] Existing pattern verification completed for all "Codebase Reference Needed" items

## Summary

**Total Issues Detected: 23**
- Critical: 5 (C1-C5)
- Significant: 4 (S1-S4)
- Moderate: 6 (M1-M6)
- Informational: 2 (I1-I2)
- Exploratory Detections: 8 (E1-E8, integrated above)

**Primary Consistency Risks:**
1. Undocumented transaction management creates data integrity risk
2. Mixed naming conventions fragment database schema
3. Async/Sync pattern mismatch creates performance risk
4. Missing package structure guidance prevents consistent file organization
5. No existing codebase references prevent true consistency verification

**Strengths:**
- API response format is well-defined and consistent
- Layer architecture and dependency direction clearly documented
- Error handling flow clearly described (though implementation details missing)
- Logging format specified

**Critical Next Step:**
**Before proceeding with implementation, must verify existing codebase patterns for all "Codebase Reference Needed" items to ensure true consistency.**
