# Answer Key - Round 007

## Execution Context
- **Perspective**: consistency
- **Target**: design
- **Embedded Problems**: 10

## Embedded Problems

### P01: Mixed Table Naming Conventions (Singular vs Plural)
- **Category**: Naming conventions (data model)
- **Severity**: Major
- **Location**: Section 4 (Data Model)
- **Description**: Table names use inconsistent patterns - `Patient` and `Provider` are singular while typical database conventions prefer plural forms. Additionally, `Appointment` follows singular form while `AvailabilitySlot` could be interpreted as conceptually plural.
- **Detection Criteria**:
  - ○ (Detected): Points out that table names mix singular forms (`Patient`, `Provider`, `Appointment`) without explicit plural/singular strategy, and notes this should be standardized OR mentions the need for documentation of naming strategy
  - △ (Partial): Mentions inconsistency in naming but doesn't specify the singular/plural pattern issue, OR only mentions one or two tables
  - × (Not detected): No mention of table naming convention issues

### P02: Inconsistent Column Naming Conventions (camelCase vs snake_case)
- **Category**: Naming conventions (data model)
- **Severity**: Major
- **Description**: Column names are inconsistent across tables - `Patient` uses camelCase (`firstName`, `dateOfBirth`), `Provider` mixes both styles (`first_name`, `createdAt`), and `Appointment` uses primarily snake_case (`scheduled_time`, `duration_minutes`, `created_timestamp`).
- **Detection Criteria**:
  - ○ (Detected): Identifies the mixing of camelCase and snake_case in column names across multiple tables, provides specific examples from at least two different tables
  - △ (Partial): Mentions inconsistency in column naming but provides examples from only one table OR doesn't specify the camelCase vs snake_case distinction
  - × (Not detected): No mention of column naming inconsistency

### P03: Inconsistent Foreign Key Naming Convention
- **Category**: Naming conventions (data model)
- **Severity**: Major
- **Description**: Foreign key columns use inconsistent patterns - `Appointment.patientId` references `Patient.id`, while `Appointment.doctor_id` references `Provider.providerId`. The FK column should match either the target column name or follow a consistent pattern.
- **Detection Criteria**:
  - ○ (Detected): Points out that foreign key naming is inconsistent - specifically notes `patientId → Patient.id` vs `doctor_id → Provider.providerId` discrepancy, AND mentions the need for standardization
  - △ (Partial): Mentions foreign key naming issues but doesn't clearly explain the pattern inconsistency between different FKs
  - × (Not detected): No mention of foreign key naming inconsistency

### P04: Missing Documentation of Data Access Pattern
- **Category**: Implementation patterns (missing information)
- **Severity**: Major
- **Description**: The design document mentions "Repository interfaces following Spring Data JPA patterns" but does not document the specific data access pattern (e.g., direct repository injection in services, repository wrapper pattern, query method naming conventions) that should be followed consistently across the codebase.
- **Detection Criteria**:
  - ○ (Detected): Points out that data access patterns (repository usage pattern, query method naming, transaction boundaries) are not documented, making consistency verification impossible
  - △ (Partial): Mentions repository pattern but doesn't specifically identify the missing documentation of consistent usage patterns across services
  - × (Not detected): No mention of missing data access pattern documentation

### P05: Inconsistent Timestamp Column Naming
- **Category**: Naming conventions (data model)
- **Severity**: Medium
- **Description**: Timestamp columns follow inconsistent naming patterns - `Patient` uses `created_at/updated_at`, `Provider` uses `createdAt/updatedAt`, and `Appointment` uses `created_timestamp/last_modified`.
- **Detection Criteria**:
  - ○ (Detected): Identifies the inconsistent timestamp naming across tables, provides specific examples of at least two different patterns (e.g., `created_at` vs `createdAt` vs `created_timestamp`)
  - △ (Partial): Mentions timestamp naming inconsistency but only provides examples from one or two tables
  - × (Not detected): No mention of timestamp column naming inconsistency

### P06: API Endpoint Inconsistency (Action-Based vs RESTful)
- **Category**: API design
- **Severity**: Medium
- **Description**: Appointment endpoints mix RESTful and action-based styles - `/api/appointments/{id}` follows REST conventions, but `/api/appointments/create`, `/api/appointments/{id}/update`, `/api/appointments/{id}/cancel` use action verbs instead of HTTP methods.
- **Detection Criteria**:
  - ○ (Detected): Points out that appointment endpoints mix action verbs in URLs (`/create`, `/update`, `/cancel`) with RESTful resource paths, creating inconsistency with patient endpoints that follow pure REST style
  - △ (Partial): Mentions endpoint naming inconsistency but doesn't specifically contrast the action-based vs RESTful approaches
  - × (Not detected): No mention of API endpoint style inconsistency

### P07: Missing Error Handling Pattern Documentation
- **Category**: Implementation patterns (missing information)
- **Severity**: Medium
- **Description**: Section 6 states "Each controller method includes try-catch blocks to transform exceptions" but this contradicts the expectation of global exception handlers typically used in Spring Boot applications. The design doesn't document whether the system uses `@ControllerAdvice` for centralized error handling or individual try-catch blocks, making consistency verification impossible.
- **Detection Criteria**:
  - ○ (Detected): Points out that error handling pattern documentation is missing or ambiguous - specifically notes the try-catch approach mentioned doesn't align with Spring Boot conventions and that the existence/usage of `@ControllerAdvice` or global exception handlers is not documented
  - △ (Partial): Mentions error handling documentation issues but doesn't specifically identify the inconsistency with typical Spring Boot patterns or the need for global handler documentation
  - × (Not detected): No mention of missing error handling pattern documentation

### P08: Mixed API Response Structure Documentation
- **Category**: API design
- **Severity**: Medium
- **Description**: The appointment API response shows `{success, data, error}` structure, but this pattern is only shown for one endpoint. The design doesn't document whether ALL endpoints follow this envelope pattern or if different endpoints use different response structures.
- **Detection Criteria**:
  - ○ (Detected): Points out that API response format is shown only for appointment endpoints and it's unclear whether the `{success, data, error}` envelope pattern applies to all endpoints (patients, providers, etc.) or varies by resource
  - △ (Partial): Mentions response format but doesn't specifically identify the missing documentation of consistency across all endpoints
  - × (Not detected): No mention of API response structure documentation issues

### P09: Inconsistent HTTP Client Library Choice
- **Category**: Dependency management
- **Severity**: Minor
- **Description**: The design specifies using `RestTemplate` for HTTP client operations, but Spring Boot 3.x officially recommends `WebClient` (RestTemplate is in maintenance mode). This represents a deviation from current Spring ecosystem conventions.
- **Detection Criteria**:
  - ○ (Detected): Points out that `RestTemplate` is specified despite Spring Boot 3.x context (mentioned in tech stack), and notes this should be documented as either a deliberate decision or updated to match Spring's current recommendations
  - △ (Partial): Mentions RestTemplate but doesn't connect it to Spring Boot 3.x context or current Spring recommendations
  - × (Not detected): No mention of HTTP client library choice

### P10: Missing Directory Structure and File Placement Guidelines
- **Category**: Directory structure (missing information)
- **Severity**: Minor
- **Description**: The design document describes component types (Controllers, Services, Repositories) but doesn't document the directory/package structure or file placement conventions (e.g., package-by-layer vs package-by-feature, naming conventions for implementation classes).
- **Detection Criteria**:
  - ○ (Detected): Points out that package/directory structure is not documented - specifically notes the absence of guidance on whether to use package-by-layer (com.example.controller, com.example.service) vs package-by-feature (com.example.appointment, com.example.patient) or file naming conventions
  - △ (Partial): Mentions missing structure information but doesn't specifically identify the package organization pattern gap
  - × (Not detected): No mention of missing directory/package structure documentation

## Bonus Problems

| ID | Category | Description | Bonus Condition |
|----|----------|-------------|-----------------|
| B01 | Naming | Primary key naming inconsistency - `Patient.id` vs `Provider.providerId` vs `Appointment.appointmentId` vs `AvailabilitySlot.slot_id` | Points out that primary key naming follows at least 3 different patterns across tables |
| B02 | Implementation | JWT token storage inconsistency - Section 7 mentions "JWT tokens stored in httpOnly cookies" while Section 5 says "included in the Authorization header" | Identifies the contradiction between cookie storage and header-based token transmission |
| B03 | API Design | Path prefix inconsistency - Patient endpoints use `/patients` while Appointment endpoints use `/api/appointments` | Notes that some endpoints include `/api` prefix while others don't |
| B04 | Naming | Boolean column naming - `is_available` in `AvailabilitySlot` vs typical Java boolean naming (`available` or `isAvailable`) | Points out the boolean column naming doesn't match typical Java/JPA conventions |
| B05 | Data Model | Cascade deletion and orphan handling strategy not documented | Notes that foreign key relationships don't document cascade behavior or orphan removal strategy |
| B06 | Implementation | Transaction management pattern not documented | Points out that transaction boundaries (@Transactional placement: service vs repository) are not specified |
| B07 | Naming | Enum value naming inconsistency - `status` and `appointment_type` use lowercase_underscore values in examples but typical Java enums use UPPERCASE | Notes potential inconsistency between database values and Java enum naming conventions |