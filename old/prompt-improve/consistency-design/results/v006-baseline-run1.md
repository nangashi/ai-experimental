# Consistency Review Report: Healthcare Appointment Scheduling System

## Review Metadata
- Document: Healthcare Appointment Scheduling System 設計書
- Reviewer: consistency-design-reviewer
- Review Date: 2026-02-11
- Variation ID: baseline (v006)
- Analysis Method: Two-pass review (structural understanding → detailed consistency analysis)

---

## Executive Summary

This design document lacks critical information about existing codebase patterns and conventions, making it impossible to verify consistency with established practices. The document appears to be written in isolation without referencing any existing system context, modules, or established patterns. Multiple severe inconsistencies exist within the document itself, particularly in naming conventions across database schema design.

**Critical Findings**: 7 critical inconsistencies identified
**Significant Findings**: 3 significant inconsistencies identified
**Moderate Findings**: 2 moderate inconsistencies identified

---

## Inconsistencies Identified

### CRITICAL INCONSISTENCIES

#### C-1: Database Naming Convention Inconsistency (Severity: Critical)

**Issue**: Three different naming conventions are used for database columns within the same schema:
- **snake_case**: `patient_id`, `email_address`, `full_name`, `date_of_birth`, `phone_number`, `created_at`, `updated_at` (PatientAccount table)
- **camelCase**: `appointmentId`, `patientId`, `institutionId`, `doctorId` (appointment table - PK and FKs)
- **snake_case**: `appointment_datetime`, `status`, `created_at`, `updated_at` (appointment table - other columns)

**Evidence from Document**:
- PatientAccount table: All columns use snake_case consistently
- medical_institution table: All columns use snake_case consistently
- doctor table: All columns use snake_case consistently
- appointment table: Mixed camelCase for IDs and snake_case for other columns

**Impact**:
- Database queries will be error-prone with mixed conventions
- ORM mapping becomes inconsistent and confusing
- Migration scripts and manual SQL queries require developers to remember which columns use which convention
- Violates the principle of least surprise

**Recommendation**: Standardize all database column names to snake_case (matching the dominant pattern: 18 out of 22 columns use snake_case, representing 82% of the schema).

---

#### C-2: Table Naming Convention Inconsistency (Severity: Critical)

**Issue**: Two different conventions for table naming:
- **PascalCase**: `PatientAccount`
- **snake_case**: `medical_institution`, `appointment`, `doctor`

**Evidence from Document**:
- Section 4.2 shows one table using PascalCase and three using snake_case
- FK references mix conventions: `FK → PatientAccount` vs `FK → medical_institution`

**Impact**:
- SQL joins and foreign key definitions become inconsistent
- ORM entity mapping requires special configuration for mixed conventions
- Database migration tools may handle conventions differently
- Team members will be uncertain which convention to use for new tables

**Recommendation**: Standardize all table names to snake_case (matching the dominant pattern: 75% of tables use snake_case).

---

#### C-3: API Endpoint Naming Inconsistency (Severity: Critical)

**Issue**: No consistent pattern for API endpoint structure:
- **Verb in path**: `/api/appointments/create` (section 5.1)
- **RESTful resource**: `/api/appointments/{appointmentId}` (section 5.1)
- **Mixed pattern**: Using POST with `/create` suffix instead of RESTful convention of POST to `/api/appointments`

**Evidence from Document**:
- `POST /api/appointments/create` - includes verb in path
- `POST /api/patients` - RESTful, no verb in path
- Both endpoints perform creation operations but follow different conventions

**Impact**:
- API design violates REST principles inconsistently
- Developers cannot predict endpoint patterns
- API documentation and client code become confusing
- Future endpoint additions will lack clear guidance

**Recommendation**: Adopt pure RESTful convention: `POST /api/appointments` instead of `POST /api/appointments/create`.

---

#### C-4: Missing Existing Codebase Context (Severity: Critical)

**Issue**: The design document provides zero references to existing modules, patterns, or conventions in the current codebase. This makes consistency verification impossible.

**Missing Information**:
- No references to existing projects or modules in the same codebase
- No comparison with established patterns in related systems
- No justification for technology stack choices based on existing infrastructure
- No mention of existing authentication/authorization implementations
- No reference to existing logging or error handling infrastructure

**Evidence**: Sections 2.4, 3.1, 6.1, 6.2 describe patterns but never reference whether these align with existing implementations.

**Impact**:
- Cannot verify if the design aligns with organizational standards
- Risk of introducing incompatible patterns that fragment the codebase
- Developers cannot determine if proposed patterns follow or diverge from existing conventions
- Knowledge transfer from existing systems is not leveraged

**Recommendation**: Add section "7. Alignment with Existing Systems" that documents:
- Which existing modules/services this integrates with
- How authentication aligns with current auth infrastructure
- How logging format matches existing services
- How error handling follows established patterns
- References to similar projects that can serve as implementation examples

---

#### C-5: Incomplete Naming Convention Documentation (Severity: Critical)

**Issue**: While some naming patterns can be inferred from examples, explicit naming rules are not documented for:
- Java class naming conventions (Service, Repository, Controller suffixes)
- Variable naming in Java code
- DTO/Request/Response object naming
- Package naming structure
- Enum naming patterns
- Constant naming conventions

**Evidence**: Section 3.2 mentions classes like `AppointmentController`, `AppointmentService`, `AppointmentRepository` but never states the naming rule. Database schema shows naming patterns but no explicit rules.

**Impact**:
- Developers must infer conventions from limited examples
- Risk of inconsistent naming as codebase grows
- Code review discussions will lack authoritative reference
- New team members cannot learn conventions from design document

**Recommendation**: Add section "6.5 Naming Conventions" with explicit rules:
- Class naming: `{Entity}Controller`, `{Entity}Service`, `{Entity}Repository`
- Variables: camelCase for local variables and fields
- Constants: UPPER_SNAKE_CASE
- Packages: snake_case or lowercase
- Database: snake_case for all tables and columns
- API endpoints: kebab-case for path segments

---

#### C-6: Incomplete Implementation Pattern Documentation (Severity: Critical)

**Issue**: While section 6.1 mentions error handling approach, several critical implementation patterns are not documented:

**Missing Patterns**:
1. **Transaction Management**: No specification of where transactions begin/end (@Transactional placement)
2. **Async Processing Approach**: Section 2.4 mentions WebFlux but no guidance on when to use reactive vs blocking patterns
3. **Data Validation Strategy**: Mentions Jakarta Bean Validation but not where validation occurs (Controller/Service/Entity)
4. **Authentication Filter/Interceptor Pattern**: Mentions Spring Security but not the implementation approach
5. **Database Connection Pooling Configuration**: Not specified
6. **Cache Usage Pattern**: Redis is mentioned but no pattern for when/how to cache

**Evidence**:
- Section 6.1 only covers error handling
- Section 6.2 only covers logging format
- Section 3.2 mentions Service "トランザクション管理" but no implementation details

**Impact**:
- Inconsistent implementation across different modules
- Developers will implement patterns differently leading to fragmented codebase
- Cannot verify if patterns align with existing services

**Recommendation**: Expand section 6 to document:
- Transaction boundary rules (Service layer with @Transactional)
- Validation placement (Controller level for request validation)
- When to use reactive patterns vs blocking
- Authentication/authorization implementation approach
- Caching strategy and cache key patterns

---

#### C-7: Missing File Placement Policy Documentation (Severity: Critical)

**Issue**: No documentation of directory structure or file organization rules.

**Missing Information**:
- Package structure pattern (domain-based vs layer-based)
- Where to place different file types (configs, utilities, constants)
- Module organization approach
- Test file placement rules
- Configuration file locations

**Evidence**: The document mentions layers (Presentation, Application, Domain, Infrastructure) in section 3.1 but provides no package structure examples.

**Impact**:
- Developers cannot determine where to place new files
- Risk of inconsistent file organization
- Cannot verify alignment with existing project structure
- Code navigation becomes difficult as files are placed inconsistently

**Recommendation**: Add section "6.6 Directory Structure and File Placement" with:
```
src/main/java/com/{company}/{project}/
├── presentation/
│   └── controller/
├── application/
│   └── service/
├── domain/
│   ├── entity/
│   └── repository/
└── infrastructure/
    ├── repository/
    └── client/
```

---

### SIGNIFICANT INCONSISTENCIES

#### S-1: Inconsistent ID Column Naming Reference Pattern (Severity: Significant)

**Issue**: Primary key columns and their foreign key references use inconsistent patterns:
- PatientAccount table: PK = `patient_id`, but FK reference in appointment = `patientId` (camelCase)
- medical_institution table: PK = `institution_id`, but FK reference = `institutionId` (camelCase)
- doctor table: PK = `doctor_id`, but FK reference = `doctorId` (camelCase)

**Evidence**: All primary keys use snake_case with `_id` suffix, but foreign keys drop the underscore.

**Impact**:
- JOIN queries become confusing (different column name formats)
- ORM relationship mapping requires custom configuration
- Developers must mentally map between snake_case and camelCase versions

**Recommendation**: Use identical naming for PK and FK: `patient_id` in both tables, `institution_id` in both tables, etc.

---

#### S-2: Inconsistent Term Usage for Patient Identifier (Severity: Significant)

**Issue**: Patient entity is referred to inconsistently:
- Domain entity name: `Patient` (section 4.1)
- Table name: `PatientAccount` (section 4.2)
- Column name: `patient_id` (not `account_id`)

**Evidence**: Section 4.1 lists "Patient: 患者情報" but section 4.2 shows table name as `PatientAccount`.

**Impact**:
- Entity-to-table mapping is not intuitive
- Developers unsure whether to use "Patient" or "PatientAccount" in code
- Terminology inconsistency across documentation

**Recommendation**: Align entity name with table name (both `Patient` or both `PatientAccount`) or document the mapping rule explicitly.

---

#### S-3: Missing Configuration Management Documentation (Severity: Significant)

**Issue**: Section 2.8 mentions configuration requirements but no documentation of:
- Configuration file format (YAML vs properties vs JSON)
- Environment variable naming convention
- Where configuration files are placed
- How environment-specific configs are managed

**Evidence**: No section on configuration management exists despite multiple environment deployments mentioned (development, staging, production in section 6.4).

**Impact**:
- Inconsistent configuration file formats across modules
- Environment variable naming follows no standard
- Cannot verify alignment with existing configuration approaches

**Recommendation**: Add section "6.7 Configuration Management" documenting:
- File format: `application.yml` (YAML)
- Environment variables: UPPER_SNAKE_CASE with `APP_` prefix
- Profile-specific configs: `application-{profile}.yml`
- Sensitive data handling: Environment variables for credentials

---

### MODERATE INCONSISTENCIES

#### M-1: Logging Format Not Fully Specified (Severity: Moderate)

**Issue**: Section 6.2 shows log format template but lacks specification for:
- Thread name format
- Logger name format (full class name vs simple name)
- Structured logging field format (if using JSON logging)
- Correlation ID inclusion for request tracing

**Evidence**: Template shows `[timestamp] [level] [thread] [class] - message` but timestamp format not specified (ISO8601? Custom format?).

**Impact**:
- Log parsing and aggregation tools may require specific format
- Cannot verify if format matches existing services' logging
- Troubleshooting distributed requests becomes difficult without correlation IDs

**Recommendation**: Specify:
- Timestamp format: ISO8601 (`yyyy-MM-dd'T'HH:mm:ss.SSSZ`)
- Logger name: Full class name
- Add correlation ID field for request tracing
- Specify whether JSON structured logging is used

---

#### M-2: Incomplete Dependency Version Management Policy (Severity: Moderate)

**Issue**: Section 2.1-2.4 lists specific versions for major components (Java 17, Spring Boot 3.2, React 18, PostgreSQL 15, Redis 7) but no policy for:
- How library versions are determined and updated
- Whether to use BOM (Bill of Materials) for dependency management
- Version pinning vs version range strategy
- Security update policy

**Evidence**: Specific versions listed but no explanation of version selection rationale or update policy.

**Impact**:
- Cannot determine if versions align with existing projects
- No guidance for developers on when to update dependencies
- Risk of version conflicts in multi-module projects

**Recommendation**: Add policy statement:
- Use Spring Boot BOM for Spring ecosystem version management
- Pin major versions, allow patch updates
- Monthly security update review cycle
- Document alignment with organization-wide dependency standards

---

## Pattern Evidence

Due to the absence of existing codebase references in the design document, pattern evidence is limited to internal document consistency analysis:

### Internal Pattern Evidence

**Database Schema Patterns (Analyzed from Section 4.2)**:
- snake_case columns: 18 occurrences (82%)
- camelCase columns: 4 occurrences (18%)
- Dominant pattern: snake_case

**Table Naming Patterns (Analyzed from Section 4.2)**:
- snake_case tables: 3 occurrences (75%)
- PascalCase tables: 1 occurrence (25%)
- Dominant pattern: snake_case

**API Endpoint Patterns (Analyzed from Section 5.1)**:
- RESTful endpoints (no verb): 9 occurrences (90%)
- Verb-in-path endpoints: 1 occurrence (10%)
- Dominant pattern: RESTful (verb-free)

### Missing Pattern Evidence

The following pattern evidence **should be present** but is missing:

1. **Existing codebase references**: No file paths, module names, or code examples from current system
2. **Similar module comparisons**: No references to how similar features are implemented
3. **Architectural decision records**: No links to ADRs or design decision history
4. **Existing API examples**: No references to current API patterns in production
5. **Current infrastructure patterns**: No references to existing AWS resource naming, deployment patterns, or monitoring setup

---

## Impact Analysis

### Critical Impacts (Require Immediate Action)

1. **Codebase Fragmentation Risk**: Mixed naming conventions in database schema will create two parallel patterns, forcing developers to remember context-specific rules and leading to frequent mistakes.

2. **Implementation Uncertainty**: Lack of implementation pattern documentation means each developer will implement error handling, validation, and transaction management differently, creating inconsistent module behavior.

3. **Integration Failure Risk**: Without existing system context, the design may introduce incompatible patterns that conflict with current authentication, logging, or API infrastructure.

4. **Maintenance Burden**: Inconsistent naming (C-1, C-2, S-1, S-2) will increase cognitive load for developers, slow down code reviews, and make refactoring difficult.

5. **Onboarding Friction**: New developers cannot learn conventions from this document, requiring extensive code archaeology to understand unstated patterns.

### Significant Impacts

1. **API Client Confusion**: Inconsistent endpoint naming (C-3) will confuse API consumers and require documentation of exceptions to RESTful conventions.

2. **Configuration Drift**: Without configuration management standards (S-3), each environment may develop different configuration approaches, complicating deployments.

3. **Terminology Confusion**: Patient vs PatientAccount inconsistency (S-2) will create confusion in code discussions and documentation.

### Moderate Impacts

1. **Operational Difficulty**: Incomplete logging specification (M-1) may hinder troubleshooting in production environments.

2. **Dependency Management Uncertainty**: Lack of version update policy (M-2) may lead to inconsistent dependency versions across modules.

---

## Recommendations

### Immediate Actions (Before Implementation Begins)

1. **Standardize Database Naming (Addresses C-1, C-2, S-1)**:
   - Change all table names to snake_case: `patient_account`, `medical_institution`, `appointment`, `doctor`
   - Change all column names to snake_case: `appointment_id`, `patient_id`, `institution_id`, `doctor_id`
   - Update FK references to match PK naming exactly

2. **Fix API Endpoint Inconsistency (Addresses C-3)**:
   - Change `POST /api/appointments/create` to `POST /api/appointments`
   - Document RESTful convention as the standard

3. **Add Existing System Context Section (Addresses C-4)**:
   - Document which existing modules this integrates with
   - Reference existing authentication, logging, and error handling implementations
   - Provide code repository links to similar modules

4. **Document Missing Conventions (Addresses C-5, C-6, C-7)**:
   - Add section 6.5: Naming Conventions (class names, variables, constants, packages)
   - Expand section 6: Implementation Patterns (transactions, validation, async processing, caching)
   - Add section 6.6: Directory Structure and File Placement
   - Add section 6.7: Configuration Management

### Short-term Actions (Before Code Review)

5. **Align Terminology (Addresses S-2)**:
   - Decide on `Patient` or `PatientAccount` and use consistently
   - Update entity name and table name to match

6. **Complete Configuration Documentation (Addresses S-3)**:
   - Document configuration file format (YAML)
   - Define environment variable naming convention
   - Specify profile-based configuration approach

### Medium-term Actions (Before Production)

7. **Enhance Logging Specification (Addresses M-1)**:
   - Specify timestamp format (ISO8601)
   - Add correlation ID for distributed tracing
   - Document structured logging approach if applicable

8. **Define Dependency Management Policy (Addresses M-2)**:
   - Document version selection and update policy
   - Specify use of Spring Boot BOM
   - Define security update review cycle

---

## Positive Aspects

Despite the identified inconsistencies, the document demonstrates several strengths:

1. **Comprehensive Scope**: Covers architecture, data model, API design, implementation, and non-functional requirements
2. **Clear Layer Separation**: Well-defined layered architecture with explicit dependency direction
3. **Detailed API Documentation**: Includes endpoint list, request/response formats, and authentication approach
4. **Security Awareness**: Addresses HTTPS, password hashing, SQL injection, XSS, and CSRF
5. **Operational Readiness**: Includes deployment, monitoring, backup, and disaster recovery considerations

---

## Conclusion

This design document requires significant consistency improvements before implementation. The **7 critical inconsistencies** must be addressed immediately to prevent codebase fragmentation and implementation uncertainty. Most critically, the document must establish references to existing codebase patterns and conventions (C-4), as consistency cannot be verified in isolation.

The internal inconsistencies (particularly database naming conventions C-1, C-2, S-1) demonstrate that the document was not reviewed for self-consistency. These issues are straightforward to fix but will cause significant technical debt if implemented as-is.

**Recommendation**: **Do not proceed with implementation** until critical inconsistencies C-1 through C-7 are resolved and the design is verified against existing codebase patterns.

---

## Review Process Notes

**Pass 1 - Structural Understanding**: Identified missing information across all checklist categories (naming, architecture, implementation, file placement, API design, configuration, existing context). Noted dominant patterns within the document itself.

**Pass 2 - Detailed Consistency Analysis**: Conducted section-by-section analysis, finding systematic naming inconsistencies across database schema and API design. Unable to verify alignment with existing codebase due to absence of references to current system.

**Limitation**: This review is based solely on the design document's internal consistency and general best practices. True consistency verification requires access to the existing codebase, which is not referenced in the document.
