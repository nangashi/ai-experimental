# Consistency Review Report: Real Estate Property Management System

## Inconsistencies Identified

### Critical: Architectural Patterns and Implementation Approaches

#### C-1: Transaction Boundary Management - Undefined Cross-Entity Transaction Pattern
**Issue**: Service layer transaction boundaries documented, but cross-entity operations unclear
- Contract creation involves multiple entities (Contracts, Payments, potentially Properties status update)
- Design states "複数エンティティの更新を含む処理は1つのServiceメソッド内でトランザクション境界を管理" but doesn't specify which Service owns the transaction when multiple Services are involved
- Example: Contract creation may need to call `ContractService.create()` + `PaymentService.createInitialPayment()` + `PropertyService.updateStatus()` - which Service method should wrap the transaction?

**Adversarial Risk**: Undefined transaction ownership enables inconsistent transaction boundary placement, leading to partial updates and data integrity violations across modules.

**Recommendation**: Document transaction orchestration pattern
- Option A: Coordinator Service pattern (e.g., `ContractOrchestrationService` owns multi-entity transactions)
- Option B: Top-level Service owns transaction (e.g., `ContractService.createContractWithPayment()` calls other Services)
- Specify propagation behavior for nested Service calls

#### C-2: Error Handling Strategy - Global vs Local Exception Handling Undefined
**Issue**: No error handling pattern documented
- Controller layer exception handling: Global `@ControllerAdvice` handler? Or per-Controller try-catch blocks?
- Service layer exception handling: Throw business exceptions to Controller? Or handle locally?
- Repository layer exception handling: Let JPA exceptions propagate? Or wrap in custom exceptions?

**Adversarial Risk**: Missing error handling pattern allows each developer to choose their own strategy, fragmenting exception handling across the codebase and making debugging inconsistent.

**Recommendation**: Document exception handling architecture
- Specify exception hierarchy (e.g., base `BusinessException`, `EntityNotFoundException`, `ValidationException`)
- Define exception translation boundaries (Repository → Service → Controller)
- Document global exception handler responsibilities vs local handling

#### C-3: Directory Structure - Layer-Based vs Domain-Based Organization Undefined
**Issue**: No file placement rules documented
- Should `PropertyController`, `PropertyService`, `PropertyRepository` be organized by layer (`/controller/`, `/service/`, `/repository/`) or by domain (`/property/PropertyController.java`, `/property/PropertyService.java`)?
- Test file placement undefined (mirror production structure? separate layer directories?)

**Adversarial Risk**: Undefined directory structure enables arbitrary file placement, making navigation inconsistent and module boundaries unclear. Different developers can choose different organization styles, fragmenting the codebase structure.

**Recommendation**: Document file organization strategy
- Specify primary organization axis (layer-based vs domain-based vs hybrid)
- Define directory structure conventions for Controllers, Services, Repositories, DTOs, Exceptions
- Document test file placement mirroring rules

#### C-4: Asynchronous Processing Pattern - Undefined Async Strategy for Long-Running Operations
**Issue**: DocumentService PDF generation likely long-running, but async pattern undefined
- Synchronous PDF generation blocks request thread
- If asynchronous: `CompletableFuture`? Spring `@Async`? Message queue (SQS)?
- No guidance on async result handling, timeout strategy, error recovery

**Adversarial Risk**: Missing async pattern allows mixing synchronous/asynchronous implementations, creating unpredictable performance characteristics and making monitoring/debugging inconsistent across modules.

**Recommendation**: Document async processing strategy
- Specify async implementation approach (Spring `@Async` configuration, executor pool settings)
- Define async method return type conventions (`CompletableFuture<T>`, `void` with callback)
- Document error handling and timeout strategies for async operations

#### C-5: ORM Query Pattern - Undefined Complex Query Strategy
**Issue**: Repository layer query implementation pattern unclear
- Simple queries: Spring Data JPA method naming (`findByPropertyId`)?
- Complex queries: `@Query` annotation with JPQL? Native SQL? QueryDSL? Criteria API?
- Example: Monthly rent report aggregation - which pattern should be used?

**Adversarial Risk**: Undefined query pattern enables mixing multiple query styles within the same codebase, making query optimization and maintenance inconsistent. Performance debugging requires understanding multiple query approaches.

**Recommendation**: Document query implementation guidelines
- Define query complexity thresholds (when to use method naming vs `@Query` vs QueryDSL)
- Specify JPQL vs native SQL decision criteria
- Document dynamic query construction approach (Specification pattern, QueryDSL)

### Significant: Naming Conventions and API Design

#### S-1: Database Column Naming - Inconsistent Timestamp Column Names Across Tables
**Issue**: Timestamp columns use 3 different naming patterns
- Pattern A: `created` + `updated` (properties, payments tables)
- Pattern B: `created_at` + `updated_at` (tenants, owners, remittances tables)
- Pattern C: `created_timestamp` + `modified_timestamp` (contracts table)

**Adversarial Risk**: Timestamp naming fragmentation forces developers to remember 3+ patterns when writing queries or JPA mappings. New tables will likely add new variations, further fragmenting conventions.

**Recommendation**: Standardize on single timestamp naming convention
- Dominant pattern appears to be `created_at` + `updated_at` (3 tables: tenants, owners, remittances)
- Migrate properties, payments, contracts tables to use `created_at`/`updated_at`
- Document standard in DB schema guidelines

#### S-2: Database Primary Key Column Naming - Inconsistent ID Column Naming
**Issue**: Primary key columns use inconsistent naming
- Pattern A: `{table}_id` (properties: `property_id`, tenants: `tenant_id`, owners: `owner_id`, payments: `payment_id`, remittances: `remittance_id`)
- Pattern B: `id` (contracts table)

**Adversarial Risk**: ID column naming inconsistency creates confusion in JOIN queries and foreign key references. Developers must remember which tables use which pattern.

**Recommendation**: Standardize on `{table_singular}_id` pattern
- Migrate contracts table `id` → `contract_id`
- Update foreign key references accordingly
- Document standard: "Primary keys should be named `{table_singular}_id`"

#### S-3: Database Foreign Key Column Naming - Mixed Conventions (snake_case, camelCase, suffix patterns)
**Issue**: Foreign key columns use 3 different naming patterns
- Pattern A: snake_case without suffix (properties table: `owner_id`)
- Pattern B: camelCase without suffix (contracts table: `PropertyID`, `TenantID`)
- Pattern C: snake_case with `_fk` suffix (payments table: `contract_fk`, remittances table: `owner_fk`)

**Adversarial Risk**: FK naming fragmentation forces developers to guess naming conventions when writing JOIN queries. The mix of snake_case and camelCase violates PostgreSQL conventions and creates hidden coupling risks.

**Recommendation**: Standardize on `{referenced_table_singular}_id` pattern (snake_case)
- Migrate contracts table: `PropertyID` → `property_id`, `TenantID` → `tenant_id`
- Migrate payments table: `contract_fk` → `contract_id`
- Migrate remittances table: `owner_fk` → `owner_id`
- Document standard: "Foreign keys should be named `{referenced_table_singular}_id` in snake_case"

#### S-4: Database Status Column Naming - Redundant Table Name Prefix in Status Columns
**Issue**: Status columns inconsistently include table name prefix
- Pattern A: Generic `status` (properties table)
- Pattern B: Table-prefixed `{table}_status` (contracts: `contract_status`, payments: `payment_status`, remittances: `remittance_status`)

**Adversarial Risk**: Status column naming inconsistency creates confusion when writing queries and may indicate unclear domain modeling. The redundant prefix pattern fragments naming conventions.

**Recommendation**: Standardize on generic `status` column name
- Rationale: Column name is already scoped by table name (`contracts.status` is unambiguous)
- Migrate contracts, payments, remittances tables to use `status` column name
- If multiple status types needed per table, use descriptive names (`approval_status`, `payment_status`) rather than redundant prefixes

#### S-5: API Endpoint Naming - Mixed RESTful vs Action-Based Conventions
**Issue**: Endpoints mix RESTful resource conventions with explicit action naming
- RESTful pattern: `POST /api/v1/tenants`, `PUT /api/v1/tenants/{id}`, `POST /api/v1/contracts`
- Action-based pattern: `POST /api/v1/properties/create`, `PUT /api/v1/properties/{id}/update`, `POST /api/v1/contracts/{id}/terminate`, `PUT /api/v1/payments/{id}/record-payment`

**Adversarial Risk**: Mixed endpoint conventions enable arbitrary style choices per new endpoint. Client code must handle both patterns, creating integration fragmentation. The action-based pattern violates RESTful principles documented in "REST API" architecture.

**Recommendation**: Standardize on RESTful resource conventions
- Remove redundant action suffixes from standard CRUD operations:
  - `POST /api/v1/properties/create` → `POST /api/v1/properties`
  - `PUT /api/v1/properties/{id}/update` → `PUT /api/v1/properties/{id}`
- For non-CRUD actions, use verb in URL (keep `POST /api/v1/contracts/{id}/terminate` as-is, or consider `PATCH /api/v1/contracts/{id}` with `{status: "terminated"}` body)
- For payment recording, consider `PATCH /api/v1/payments/{id}` with payment details in body

#### S-6: API Response Timestamp Format - Inconsistent with Database Timestamp Columns
**Issue**: API response format uses `timestamp` field name, but database tables use `created_at`/`created`/`created_timestamp`
- API response: `"timestamp": "2024-01-15T10:30:00Z"`
- Database columns: `created_at`, `created`, `created_timestamp`, `updated_at`, `updated`, `modified_timestamp`

**Adversarial Risk**: API-DB naming mismatch forces mapping layer logic, creating maintenance burden. Unclear which database timestamp field maps to response `timestamp` field (created? updated? current server time?).

**Recommendation**: Align API response field names with database conventions
- Option A: Use `created_at` and `updated_at` in API responses (matches dominant DB pattern)
- Option B: Document mapping explicitly: "API response `timestamp` field represents current server time, not entity creation time"
- Specify whether entity creation/update timestamps should be included in API responses as separate fields

### Moderate: File Placement and Configuration Patterns

#### M-1: Configuration Management - Undefined Config File Format and Environment Variable Naming
**Issue**: Configuration strategy undefined
- JWT secret, database credentials, AWS credentials storage format unclear (application.yml? application.properties? .env?)
- Environment variable naming convention undefined (e.g., `JWT_SECRET` vs `jwtSecret` vs `jwt.secret`)
- Spring Boot profiles usage undefined (dev/staging/prod profile file organization)

**Adversarial Risk**: Missing configuration standards enable inconsistent config management across environments. Secret management fragmentation creates security risks (hardcoded secrets, unencrypted storage).

**Recommendation**: Document configuration management strategy
- Specify config file format (e.g., `application.yml` for Spring Boot defaults, environment variables for secrets)
- Define environment variable naming convention (e.g., UPPER_SNAKE_CASE: `JWT_SECRET`, `DATABASE_URL`)
- Document Spring Boot profile usage (`application-{profile}.yml` conventions)
- Specify secret management approach (AWS Secrets Manager integration, encrypted at rest)

#### M-2: Dependency Injection Pattern - Undefined Injection Style
**Issue**: No dependency injection pattern documented
- Constructor injection (recommended by Spring)? Field injection (`@Autowired` on fields)? Setter injection?
- Impacts testability and immutability

**Adversarial Risk**: Missing DI pattern allows mixing injection styles, making test setup inconsistent and creating potential null pointer risks with field injection.

**Recommendation**: Standardize on constructor injection
- Constructor injection enables immutability and required dependency declaration
- Document pattern: "All Service and Repository dependencies should use constructor injection with `@RequiredArgsConstructor` (Lombok) or explicit constructor"

#### M-3: DTO Pattern - Undefined Request/Response Object Strategy
**Issue**: No DTO (Data Transfer Object) pattern documented
- Do Controllers accept/return JPA entity objects directly? Or separate Request/Response DTOs?
- Impacts layer separation, API evolution, and security (preventing mass assignment vulnerabilities)

**Adversarial Risk**: Missing DTO pattern enables direct entity exposure in APIs, creating security risks (mass assignment), tight coupling between API contracts and DB schema, and difficulty evolving APIs independently.

**Recommendation**: Document DTO strategy
- Specify Request/Response DTO usage for all API endpoints (e.g., `CreatePropertyRequest`, `PropertyResponse`)
- Define DTO-Entity mapping approach (MapStruct, manual mapping, BeanUtils)
- Document DTO placement in directory structure (e.g., `/controller/dto/` or `/property/dto/`)

#### M-4: Validation Pattern - Undefined Validation Strategy and Error Response Generation
**Issue**: Validation approach undefined
- Bean Validation (`@Valid` with JSR-380 annotations)? Manual validation in Service layer?
- Where are validation error responses generated? Global `@ControllerAdvice`? Per-Controller?

**Adversarial Risk**: Missing validation pattern allows validation logic scatter across layers (Controller, Service, Repository), making validation inconsistent and error responses non-uniform across endpoints.

**Recommendation**: Document validation architecture
- Specify validation layer (e.g., Bean Validation on DTOs at Controller layer with `@Valid`)
- Document validation exception handling (global `@ControllerAdvice` converts `MethodArgumentNotValidException` to standard error response format)
- Define custom validation annotation placement for business rules (e.g., `@ValidDateRange` on DTO fields)

#### M-5: UUID Generation Strategy - Undefined UUID Generation and Version Selection
**Issue**: All tables use UUID primary keys, but generation strategy unclear
- Database-generated (PostgreSQL `gen_random_uuid()`)? Application-generated (Java `UUID.randomUUID()`)?
- UUID version unclear (v4 random? v7 time-ordered for better DB index performance?)

**Adversarial Risk**: Mixed UUID generation strategies create potential ID collision risks and performance inconsistencies. Application-generated UUIDs prevent database batch insert optimizations. Missing UUID version guidance impacts database index performance.

**Recommendation**: Document UUID generation strategy
- Specify generation location (recommend: application-generated for better control and testing)
- Define UUID version (recommend: UUID v7 for time-ordered IDs, improving database index performance)
- Document JPA entity ID generation annotation: `@GeneratedValue(strategy = GenerationType.UUID)` or custom generator

### Minor: Improvements and Positive Alignment Aspects

#### I-1: Audit Trail Pattern - Missing Created/Updated By Tracking
**Issue**: Tables include `created_at`/`updated_at` timestamps but no `created_by`/`updated_by` user tracking
- Common audit trail pattern includes both timestamp and user information
- Useful for compliance, debugging, and user activity tracking

**Impact**: Limited audit capabilities, cannot trace who made specific changes

**Recommendation**: Consider adding audit columns
- Add `created_by` and `updated_by` UUID columns (FK to users table)
- Use Spring Data JPA auditing (`@CreatedBy`, `@LastModifiedBy` annotations)
- Document auditing strategy in implementation guidelines

#### I-2: Soft Delete Pattern - Hard Delete vs Soft Delete Strategy Undefined
**Issue**: API design includes DELETE endpoints but no `deleted_at` columns in tables
- Hard delete permanently removes records
- Soft delete marks records as deleted without physical removal (preserves audit trail)

**Impact**: Unclear data retention policy, potential loss of historical data for compliance

**Recommendation**: Document delete strategy
- If hard delete intended, confirm compliance/legal requirements for data retention
- If soft delete needed, add `deleted_at` timestamp columns and `deleted_by` user columns
- Document query impact (all queries must filter out soft-deleted records with `WHERE deleted_at IS NULL`)

#### I-3: Foreign Key Constraint Behavior - Undefined ON DELETE/ON UPDATE Cascade Rules
**Issue**: Design specifies foreign key relationships but not constraint behavior
- Example: If Owner is deleted, what happens to Properties? CASCADE delete? RESTRICT?
- Example: If Property is deleted, what happens to Contracts? SET NULL? RESTRICT?

**Impact**: Undefined referential integrity behavior, risk of orphaned records or accidental cascading deletes

**Recommendation**: Document FK constraint policies
- Define ON DELETE behavior per FK (likely: RESTRICT for most relationships to prevent accidental data loss)
- Define ON UPDATE behavior (likely: CASCADE for PK updates, though UUIDs rarely change)
- Document in schema design guidelines

#### I-4: Repository Method Naming - Undefined Custom Query Method Naming Convention
**Issue**: Repository layer defined but method naming conventions unclear
- Spring Data JPA method naming (`findByPropertyId`, `findAllByStatus`)? Custom `@Query` method names?
- Naming consistency across repositories

**Impact**: Minor, but method naming inconsistency makes repository interfaces harder to understand

**Recommendation**: Document repository method naming guidelines
- Use Spring Data JPA method naming conventions for simple queries
- For complex queries with `@Query`, use descriptive method names (e.g., `findMonthlyRentSummaryByOwner`)

#### I-5: Test File Naming and Placement - Undefined Test Conventions
**Issue**: Test strategy mentions JUnit 5 + Mockito, but test file naming/placement undefined
- Test class names: `PropertyServiceTest`? `PropertyServiceTests`? `TestPropertyService`?
- Test method names: `testCreateProperty`? `createProperty_shouldReturnCreatedProperty`? `shouldCreatePropertySuccessfully`?
- Test file directory structure: Mirror production? Separate by test type?

**Impact**: Minor, but inconsistent test naming makes test suites harder to navigate

**Recommendation**: Document test conventions
- Test class naming: `{ClassName}Test` (e.g., `PropertyServiceTest`)
- Test method naming: Use descriptive names with `should` pattern (e.g., `shouldCreatePropertyWhenValidDataProvided`)
- Test directory structure: Mirror production structure in `/test/java/`

## Pattern Evidence

### Naming Convention Evidence
- **Timestamp column naming**: 3 different patterns across 6 tables (detailed in S-1)
- **Primary key naming**: 5 tables use `{table}_id`, 1 table uses `id` (detailed in S-2)
- **Foreign key naming**: 3 different patterns across 4 relationships (detailed in S-3)
- **Status column naming**: 1 table uses generic `status`, 3 tables use `{table}_status` prefix (detailed in S-4)
- **API endpoint conventions**: 60% RESTful pattern, 40% action-based pattern across 14 endpoints (detailed in S-5)

### Architecture Pattern Evidence
- **3-layer architecture**: Explicitly documented (Controller → Service → Repository)
- **Transaction boundaries**: Service layer with `@Transactional`, but cross-entity orchestration undefined (C-1)
- **Error handling**: No existing pattern documented or referenced (C-2)
- **Directory structure**: No existing pattern documented (C-3)

### Implementation Pattern Evidence
- **Logging**: Structured JSON logging documented with CloudWatch Logs aggregation
- **Authentication**: JWT with Bearer token documented
- **ORM**: Spring Data JPA documented, but query pattern undefined (C-5)
- **Async processing**: No pattern documented (C-4)

## Impact Analysis

### Critical Impact (Codebase Fragmentation Risk)
1. **Transaction boundary ambiguity (C-1)**: Enables inconsistent transaction placement, leading to data integrity violations and difficult-to-debug partial update scenarios
2. **Missing error handling pattern (C-2)**: Allows exception handling fragmentation across the codebase, making debugging inconsistent and error responses non-uniform
3. **Undefined directory structure (C-3)**: Enables arbitrary file placement, fragmenting codebase organization and making module boundaries unclear
4. **Missing async pattern (C-4)**: Creates unpredictable performance characteristics and makes monitoring/debugging inconsistent
5. **Undefined ORM query pattern (C-5)**: Enables mixing multiple query styles, making performance optimization and maintenance inconsistent

### Significant Impact (Developer Experience Degradation)
1. **Timestamp naming inconsistency (S-1)**: Forces developers to memorize 3+ patterns, slowing development and increasing cognitive load
2. **ID column naming inconsistency (S-2)**: Creates confusion in JOIN queries and foreign key references
3. **FK naming fragmentation (S-3)**: Mix of snake_case/camelCase violates PostgreSQL conventions, creates hidden coupling risks
4. **Status column naming redundancy (S-4)**: Fragments naming conventions and may indicate unclear domain modeling
5. **API endpoint convention mixing (S-5)**: Violates RESTful principles, forces client code to handle both patterns
6. **API-DB timestamp mismatch (S-6)**: Forces mapping layer logic, unclear which timestamp field maps to which

### Moderate Impact (Configuration and Layer Separation)
1. **Missing configuration management (M-1)**: Enables inconsistent config across environments, creates security risks
2. **Undefined DI pattern (M-2)**: Allows mixing injection styles, impacts testability
3. **Missing DTO pattern (M-3)**: Creates security risks (mass assignment), tight API-DB coupling
4. **Undefined validation strategy (M-4)**: Allows validation logic scatter, makes error responses non-uniform
5. **UUID generation unclear (M-5)**: Potential ID collision risks, performance inconsistencies

### Minor Impact (Audit and Quality of Life)
1. **Missing audit trail (I-1)**: Limited audit capabilities for compliance
2. **Delete strategy undefined (I-2)**: Unclear data retention policy
3. **FK constraint behavior (I-3)**: Risk of orphaned records or accidental cascades
4. **Repository method naming (I-4)**: Minor consistency impact
5. **Test conventions undefined (I-5)**: Makes test suites harder to navigate

## Recommendations

### Immediate Actions (Critical Severity)
1. **Define transaction orchestration pattern** (C-1): Document which Service owns cross-entity transactions (Coordinator pattern or top-level Service pattern)
2. **Document exception handling architecture** (C-2): Define exception hierarchy, translation boundaries, and global handler responsibilities
3. **Establish directory structure standards** (C-3): Specify layer-based vs domain-based organization and document file placement rules
4. **Define async processing strategy** (C-4): Document async implementation approach (Spring `@Async` configuration, return types, error handling)
5. **Establish ORM query guidelines** (C-5): Define query complexity thresholds and when to use each query approach

### High Priority Actions (Significant Severity)
1. **Standardize database timestamp columns** (S-1): Migrate all tables to `created_at` + `updated_at` convention
2. **Standardize primary key naming** (S-2): Migrate contracts table to `contract_id` convention
3. **Standardize foreign key naming** (S-3): Migrate all FKs to `{referenced_table_singular}_id` snake_case pattern
4. **Simplify status column naming** (S-4): Remove redundant table name prefixes, use generic `status` column
5. **Align API endpoint conventions** (S-5): Remove action suffixes from CRUD operations, adopt RESTful resource pattern
6. **Align API-DB timestamp naming** (S-6): Use `created_at`/`updated_at` in API responses or document mapping explicitly

### Medium Priority Actions (Moderate Severity)
1. **Document configuration management** (M-1): Define config file formats, environment variable naming, secret management
2. **Standardize dependency injection** (M-2): Adopt constructor injection pattern
3. **Define DTO strategy** (M-3): Document Request/Response DTO usage and mapping approach
4. **Document validation architecture** (M-4): Specify Bean Validation usage and error response generation
5. **Define UUID generation strategy** (M-5): Document generation location and UUID version selection

### Low Priority Improvements (Minor Severity)
1. **Consider audit trail enhancement** (I-1): Add `created_by`/`updated_by` columns for user tracking
2. **Document delete strategy** (I-2): Clarify hard delete vs soft delete policy and data retention requirements
3. **Define FK constraint behavior** (I-3): Document ON DELETE/ON UPDATE cascade rules
4. **Document repository method naming** (I-4): Establish Spring Data JPA method naming conventions
5. **Define test conventions** (I-5): Document test class/method naming and directory structure

---

## Summary

This design document demonstrates **significant consistency issues** across multiple dimensions, particularly in naming conventions and architectural pattern documentation. The most critical risks are:

1. **Undefined architectural patterns** (transaction orchestration, error handling, directory structure, async processing, query patterns) that enable codebase fragmentation
2. **Naming convention fragmentation** across database columns, particularly timestamp columns (3 patterns), foreign keys (3 patterns), and status columns (2 patterns)
3. **API endpoint convention mixing** (RESTful vs action-based) that violates stated REST architecture
4. **Missing layer separation guidance** (DTO pattern, validation strategy, configuration management)

**Adversarial analysis reveals** that these inconsistencies create multiple opportunities for technical debt accumulation:
- Developers can exploit missing patterns to fragment implementation styles
- Naming variations enable incompatible subsystem development
- Undefined boundaries allow coupling and dependency issues to accumulate

**Recommended next steps**:
1. Establish and document critical architectural patterns (C-1 through C-5) before implementation begins
2. Standardize database naming conventions (S-1 through S-4) in schema migration
3. Align API conventions to RESTful standards (S-5)
4. Define configuration, DTO, and validation strategies (M-1, M-3, M-4)

These changes will significantly improve codebase consistency, reduce maintenance burden, and prevent the hidden coupling and fragmentation risks identified through adversarial analysis.
