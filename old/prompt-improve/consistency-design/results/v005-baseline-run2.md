# Consistency Review Report: オンライン診療予約システム

**Review Date**: 2026-02-11
**Reviewer**: consistency-design-reviewer
**Variant**: v005-baseline (Multi-Pass Review structure)
**Run**: 2

---

## Executive Summary

This design document presents an online medical appointment system using Java/Spring Boot backend and React frontend. The review was conducted using a two-pass methodology: Pass 1 for structural understanding and Pass 2 for detailed consistency analysis.

**Key Finding**: Due to the absence of an existing codebase in this repository, consistency evaluation is limited to internal document consistency and identification of areas requiring explicit pattern documentation for future consistency verification.

---

## Pass 1 - Structural Understanding

### Document Scope and Intent
The document describes a comprehensive online medical appointment booking system with:
- Patient registration and authentication
- Medical institution search and department selection
- Appointment booking and cancellation
- Online questionnaire functionality
- Medical staff interfaces for appointment management

### Sections Present
1. Overview (purpose, features, target users)
2. Technology Stack (languages, frameworks, infrastructure)
3. Architecture Design (3-layer architecture, component responsibilities, data flow)
4. Data Model (4 main entities with schema definitions)
5. API Design (endpoint definitions, request/response formats, authentication)
6. Implementation Guidelines (error handling, logging, testing, deployment)
7. Non-functional Requirements (performance, security, availability)

### Missing Information Identified
- **Directory structure**: No explicit file organization or package structure defined
- **Codebase references**: No references to existing modules or patterns
- **Configuration management**: Environment variable naming conventions not specified
- **Exception hierarchy**: Custom exception classes not documented
- **Transaction boundaries**: Transaction management patterns not specified
- **Validation patterns**: Validation implementation details missing
- **Async patterns**: Asynchronous processing approach not specified

### Document Relationships
The document is self-contained with clear hierarchical structure:
- Architecture → Components → Data Model → API → Implementation
- Each section builds upon previous sections logically

---

## Pass 2 - Detailed Consistency Analysis

### 1. Naming Convention Consistency

#### Issues Identified

**CRITICAL: Inconsistent Table Naming Convention**
- **Location**: Section 4 (データモデル)
- **Issue**: Mixed naming styles in table names
  - `Patients` (PascalCase, English singular with capital)
  - `medical_institutions` (snake_case, English plural)
  - `appointment` (snake_case, English singular)
  - `Questionnaires` (PascalCase, English plural with capital)
- **Pattern Evidence**: No existing codebase to reference, but within the document itself, 4 different naming patterns are used
- **Impact**:
  - Database schema inconsistency will cause confusion during development
  - ORM entity mapping will require explicit table name annotations
  - Maintenance difficulty when developers need to remember which naming style each table uses

**SIGNIFICANT: Mixed Language Usage in Field Names**
- **Location**: Section 5 (API設計) request examples
- **Issue**: `department` field uses Japanese value "内科" in request JSON
- **Inconsistency**: All other field names and values in the document are in English
- **Impact**:
  - Unclear whether the API accepts Japanese, English, or both
  - Internationalization strategy not documented
  - Validation rules for department names undefined

**MODERATE: Component Naming Pattern Not Documented**
- **Location**: Section 3 (アーキテクチャ設計)
- **Issue**: Component names follow `{Domain}{LayerType}` pattern but this is not explicitly stated
- **Missing Documentation**:
  - Naming convention for components
  - Whether abbreviations are allowed (e.g., `MedicalInstController` vs `MedicalInstitutionController`)
  - Handling of long domain names

#### Positive Aspects
- Entity field names consistently use snake_case
- API endpoints consistently use kebab-case
- Java class names would follow PascalCase (implied from component names)

### 2. Architecture Pattern Consistency

#### Issues Identified

**MODERATE: Dependency Direction Not Explicitly Documented**
- **Location**: Section 3 (アーキテクチャ設計)
- **Issue**: While the 3-layer architecture is described, dependency injection patterns are not specified
- **Missing Documentation**:
  - Constructor injection vs field injection policy
  - Whether interfaces are required for Service and Repository layers
  - Circular dependency prevention strategies
- **Impact**: Without existing codebase, no verification possible, but inconsistent implementation likely without explicit guidelines

**MODERATE: Cross-Cutting Concerns Not Addressed**
- **Location**: Section 3 and 6
- **Issue**: No mention of how cross-cutting concerns (logging, transaction, security) are implemented
- **Missing Documentation**:
  - Whether AOP is used for logging/transaction management
  - Where authentication filters are applied (Filter vs Interceptor)
  - Exception translation layer placement
- **Impact**: Each developer may implement cross-cutting concerns differently

#### Positive Aspects
- Clear 3-layer architecture with Controller → Service → Repository flow
- Responsibilities well-separated by layer
- Data flow explicitly documented

### 3. Implementation Pattern Consistency

#### Issues Identified

**CRITICAL: Inconsistent Error Handling Pattern**
- **Location**: Section 6 (実装方針 - エラーハンドリング方針)
- **Issue**: "各Controllerでtry-catchを実装" contradicts modern Spring Boot best practices
- **Inconsistency**:
  - Section 2 lists "Jakarta Validation" as a main library, suggesting declarative validation
  - Section 5 shows standardized error response format (`success`, `errorMessage`)
  - Individual try-catch in each Controller would make it difficult to maintain consistent error response formats
- **Pattern Evidence**: Modern Spring Boot applications (3.2) typically use `@ControllerAdvice` for centralized exception handling
- **Impact**:
  - Code duplication across all Controllers
  - Difficult to maintain consistent error response format
  - Higher risk of inconsistent error handling logic

**SIGNIFICANT: Transaction Management Pattern Not Specified**
- **Location**: Section 6 (実装方針)
- **Issue**: No mention of `@Transactional` annotation usage or transaction boundaries
- **Missing Documentation**:
  - Which layer manages transactions (Service vs Repository)
  - Whether read-only transactions are distinguished
  - Transaction isolation levels
- **Impact**: Critical for data consistency but entirely unspecified

**SIGNIFICANT: Async Pattern Not Documented**
- **Location**: Section 3 mentions "リマインダー送信" (reminder sending) in AppointmentService
- **Issue**: No specification of whether this is synchronous or asynchronous
- **Missing Documentation**:
  - Whether Spring `@Async` is used
  - Thread pool configuration
  - Error handling for async operations
- **Impact**: Performance and reliability implications not addressed

**MODERATE: Validation Pattern Unclear**
- **Location**: Section 3 mentions "Controllerがリクエストを受け取り、バリデーション実施"
- **Issue**: Unclear whether using Jakarta Validation annotations or manual validation
- **Inconsistency**: Jakarta Validation is listed in Section 2 but usage pattern not specified
- **Impact**: Mix of declarative and manual validation likely without clear guidelines

#### Positive Aspects
- JWT authentication approach clearly specified
- Token lifetime and storage location documented
- Logging format (JSON) and levels explicitly defined
- Password hashing algorithm (bcrypt) specified

### 4. Directory Structure & File Placement Consistency

#### Issues Identified

**CRITICAL: No Directory Structure Specified**
- **Location**: Missing throughout document
- **Issue**: No package structure or file organization defined
- **Missing Documentation**:
  - Java package naming convention (e.g., `com.example.medicalreservation.controller`)
  - Whether domain-driven or layer-driven package structure
  - Placement of configuration classes
  - Test file organization
  - Frontend component structure (pages, components, hooks, etc.)
- **Impact**:
  - No consistency baseline for future development
  - Each developer will organize code differently
  - Difficult to navigate codebase as it grows

**SIGNIFICANT: Configuration File Locations Not Specified**
- **Location**: Missing from Section 6 (実装方針)
- **Issue**: No mention of where configuration files should be placed
- **Missing Documentation**:
  - `application.yml` vs `application.properties`
  - Profile-specific configuration placement
  - Environment variable mapping strategy
- **Impact**: Configuration management becomes ad-hoc

### 5. API/Interface Design & Dependency Consistency

#### Issues Identified

**SIGNIFICANT: Response Format Inconsistency Risk**
- **Location**: Section 5 (API設計)
- **Issue**: Example shows wrapper response format with `success` and `data`/`errorMessage` fields, but no documentation of when this wrapper is required
- **Missing Documentation**:
  - Whether all endpoints use this wrapper
  - How pagination is handled (wrapper structure for list responses)
  - Standard error codes beyond HTTP status codes
- **Impact**: Without clear specification, some endpoints may return unwrapped responses

**MODERATE: REST Maturity Level Not Specified**
- **Location**: Section 5 (API設計)
- **Issue**: API uses `PUT /appointments/{id}/cancel` instead of `DELETE /appointments/{id}`
- **Inconsistency**: Mix of RPC-style (`/cancel`) and RESTful resource-based design
- **Missing Documentation**:
  - Whether HATEOAS is used
  - Versioning strategy beyond URL prefix (`/api/v1/`)
  - Standard query parameter naming (pagination, filtering, sorting)
- **Impact**: API design philosophy unclear, leading to inconsistent endpoint designs

**MODERATE: Library Selection Rationale Not Documented**
- **Location**: Section 2 (技術スタック)
- **Issue**: Lists `RestTemplate` but this is in maintenance mode since Spring 5.0
- **Inconsistency**: Using legacy library in new Spring Boot 3.2 project (should use `WebClient` or `RestClient`)
- **Missing Documentation**:
  - Criteria for library selection
  - Policy for using maintained vs deprecated libraries
- **Impact**: Technical debt from day one

#### Positive Aspects
- API versioning (`/api/v1/`) explicitly included
- JWT token management (expiration, storage) well-documented
- HTTP status code strategy defined (400 for business errors, 500 for system errors)

---

## Cross-Cutting Consistency Issues

### Issue 1: Documentation Language Inconsistency
- **Locations**: Throughout document
- **Issue**:
  - Document primarily in Japanese with Japanese section headers
  - All code examples, entity names, API endpoints in English
  - One example uses Japanese value ("内科") in API request
- **Impact**: Unclear language policy for code comments, documentation strings, error messages

### Issue 2: Pattern Documentation Gap
- **Locations**: All sections
- **Issue**: Document describes "what to build" but not "how to implement consistently"
- **Gap**: Missing implementation pattern catalog that would enable consistency verification
- **Impact**: Without existing codebase, this document cannot serve as consistency baseline

---

## Recommendations

### Priority 1: Critical Consistency Fixes

1. **Standardize Table Naming Convention**
   - Recommendation: Choose one convention (suggest: `snake_case` singular for tables, e.g., `patient`, `medical_institution`, `appointment`, `questionnaire`)
   - Rationale: snake_case is PostgreSQL convention, singular aligns with entity concept
   - Action: Update all table definitions in Section 4

2. **Adopt Centralized Error Handling Pattern**
   - Recommendation: Replace "各Controllerでtry-catch" with `@ControllerAdvice` pattern
   - Rationale: Aligns with Spring Boot 3.2 best practices and standardized error response format shown in Section 5
   - Action: Add to Section 6 implementation guidelines with example structure

3. **Define Directory Structure**
   - Recommendation: Add Section "6.5 プロジェクト構造" with package organization
   - Suggested structure:
     ```
     src/main/java/com/company/medicalreservation/
       ├── controller/
       ├── service/
       ├── repository/
       ├── domain/entity/
       ├── domain/dto/
       ├── config/
       └── exception/
     ```
   - Action: Document package naming and file placement rules

### Priority 2: Significant Consistency Improvements

4. **Document Transaction Management Pattern**
   - Recommendation: Specify `@Transactional` usage - Service layer manages transactions, default propagation REQUIRED
   - Action: Add transaction section to Section 6 implementation guidelines

5. **Clarify API Response Format Rules**
   - Recommendation: Document when wrapper response is required (all endpoints) and pagination structure
   - Action: Add "Response Structure Guidelines" subsection to Section 5

6. **Specify Async Processing Pattern**
   - Recommendation: Document whether reminder sending is async, Spring `@Async` configuration
   - Action: Add async pattern section to Section 6

7. **Update Library Selections**
   - Recommendation: Replace `RestTemplate` with `RestClient` (new in Spring Boot 3.2) or `WebClient`
   - Rationale: RestTemplate is in maintenance mode since 2018
   - Action: Update Section 2 technology stack

### Priority 3: Moderate Documentation Improvements

8. **Document Component Naming Convention**
   - Recommendation: Add explicit naming pattern rules for components
   - Action: Add to Section 3 architecture design

9. **Specify Validation Pattern**
   - Recommendation: Clarify Jakarta Validation usage (declarative with annotations on DTOs)
   - Action: Add validation section to Section 6

10. **Define Configuration Management**
    - Recommendation: Specify `application.yml`, profile-based configuration, environment variable naming (uppercase with underscores)
    - Action: Add configuration section to Section 6

11. **Clarify Language Policy**
    - Recommendation: Document language policy - code/APIs in English, comments/docs in Japanese
    - Action: Add to Section 6 implementation guidelines

---

## Pattern Evidence Summary

### Evidence from Document Itself
- **Naming styles observed**: PascalCase (entities), snake_case (fields), kebab-case (API paths), camelCase (JSON)
- **Architecture pattern**: 3-layer architecture with clear separation
- **Error response format**: Wrapper structure with `success`, `data`, `errorMessage`
- **Authentication**: JWT with specific token lifetimes documented

### Evidence from External References
- **Spring Boot 3.2 conventions**: `@ControllerAdvice`, Jakarta Validation, `RestClient` over `RestTemplate`
- **PostgreSQL conventions**: snake_case for identifiers
- **REST API best practices**: Resource-based URLs, standard HTTP methods

### Missing Evidence (No Codebase Available)
- Cannot verify against existing implementation patterns
- Cannot check for consistency with related modules
- Cannot validate against established team conventions
- Cannot assess alignment with current system behavior

---

## Impact Analysis

### High Impact Issues (Immediate Attention Required)
1. **Table Naming Inconsistency**: Will cause database schema confusion and require explicit ORM mapping
2. **Error Handling Pattern**: Will lead to code duplication and inconsistent error responses across API
3. **Missing Directory Structure**: Will result in disorganized codebase and navigation difficulty

### Medium Impact Issues (Should Address Before Implementation)
4. **Transaction Pattern**: Risk of data inconsistency bugs without clear transaction boundaries
5. **API Response Format**: Inconsistent response structures will break frontend contracts
6. **Deprecated Library**: Technical debt and migration cost later

### Low Impact Issues (Can Address During Implementation)
7. **Documentation gaps**: Can be clarified as patterns emerge during development
8. **Language policy**: Can be established as team convention

---

## Conclusion

This design document provides a solid foundation for understanding the system's intent and technical choices. However, due to the **absence of an existing codebase**, traditional consistency review focusing on "alignment with existing patterns" cannot be performed.

The review instead focused on:
1. **Internal document consistency**: Identified several critical inconsistencies (table naming, error handling approach)
2. **Alignment with framework conventions**: Flagged deprecated library usage and patterns that conflict with Spring Boot 3.2 best practices
3. **Pattern documentation gaps**: Highlighted missing specifications that will be essential for future consistency verification

**Key Recommendation**: Before implementation begins, this document should be enhanced with explicit pattern guidelines (Priority 1 and 2 recommendations) to serve as the consistency baseline for all future development and reviews.

---

**Review Metadata**:
- Prompt variant: v005-baseline (Multi-Pass Review structure)
- Review methodology: Two-pass (structural understanding → detailed analysis)
- Codebase availability: None (new project)
- Review focus: Internal consistency + framework best practices alignment
