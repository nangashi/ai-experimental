# Consistency Design Review Report

## Phase 1: Comprehensive Problem Detection

### Detection Strategy 1: Structural Analysis & Pattern Extraction

**Document Structure Identified**:
- Section 1: Overview
- Section 2: Technology Stack
- Section 3: Architecture Design
- Section 4: Data Model
- Section 5: API Design
- Section 6: Implementation Policy
- Section 7: Non-functional Requirements

**Explicitly Documented Patterns**:

**Naming Conventions**:
- Database table names: Mixed case styles detected
  - Properties: snake_case columns (property_id, owner_id, created, updated)
  - Tenants: snake_case columns with _at suffix (created_at, updated_at)
  - Contracts: Mixed naming (id, PropertyID, TenantID, created_timestamp, modified_timestamp)
  - Payments: Mixed naming (payment_id, contract_fk, created, updated)
  - Owners: snake_case columns with _at suffix (created_at, updated_at)
  - Remittances: snake_case columns with _at suffix (created_at, updated_at)

- API endpoint naming: Inconsistent action verb placement
  - Standard REST: `POST /api/v1/tenants`, `PUT /api/v1/tenants/{id}`
  - Verb suffix: `POST /api/v1/properties/create`, `PUT /api/v1/properties/{id}/update`
  - Verb suffix: `PUT /api/v1/payments/{id}/record-payment`
  - Verb suffix: `POST /api/v1/contracts/{id}/terminate`

- Foreign key naming: Inconsistent patterns
  - owner_id (in Properties)
  - PropertyID, TenantID (in Contracts)
  - contract_fk, owner_fk (in Payments/Remittances)

**Architectural Patterns**:
- 3-layer architecture documented (Controller → Service → Repository)
- Service layer owns transaction boundaries
- Repository layer uses Spring Data JPA

**Implementation Patterns**:
- ORM: Spring Data JPA
- HTTP client: Apache HttpClient 5.2
- Authentication: JWT with stateless session management
- Transaction management: @Transactional on Service methods
- Logging: Structured JSON format

**Missing Information Checklist Results**:
- ❌ JWT token storage location (localStorage vs sessionStorage vs httpOnly cookie) not specified
- ❌ File naming conventions for Java classes not documented
- ❌ Error handling pattern (global handler vs individual catch) not documented
- ❌ Asynchronous processing patterns not documented
- ✓ Transaction boundaries documented
- ✓ API response formats documented
- ✓ Configuration management partially documented (CloudWatch Logs)
- ✓ Authentication mechanism documented (JWT)

**Adversarial Pattern Violation Checks**:
- Timestamp field naming allows developers to choose between `created`/`updated` vs `created_at`/`updated_at` vs `created_timestamp`/`modified_timestamp`
- Foreign key naming allows developers to choose between `_id`, `ID`, or `_fk` suffixes
- API endpoint design allows developers to add verb suffixes inconsistently
- Primary key naming allows choosing between descriptive name (`property_id`) and generic name (`id`)

### Detection Strategy 2: Pattern-Based Detection with Existing System Verification

**Extract ALL instances - Database Entities**:

**Table Names**: All plural (Properties, Tenants, Contracts, Payments, Owners, Remittances) - **CONSISTENT**

**Primary Key Naming**:
- `property_id` (Properties)
- `tenant_id` (Tenants)
- `id` (Contracts) ← **DEVIATION**
- `payment_id` (Payments)
- `owner_id` (Owners)
- `remittance_id` (Remittances)
**Pattern**: 5 tables use descriptive `{entity}_id`, 1 table uses generic `id` - **INCONSISTENT (83% vs 17%)**

**Foreign Key Naming**:
- `owner_id` (Properties)
- `PropertyID` (Contracts) ← **DEVIATION (PascalCase)**
- `TenantID` (Contracts) ← **DEVIATION (PascalCase)**
- `contract_fk` (Payments)
- `owner_fk` (Remittances)
**Pattern**: Mixed styles - `_id` (1 instance), `ID` (2 instances), `_fk` (2 instances) - **FRAGMENTED**

**Timestamp Field Naming**:
- `created`, `updated` (Properties table)
- `created_at`, `updated_at` (Tenants table)
- `created_timestamp`, `modified_timestamp` (Contracts table)
- `created`, `updated` (Payments table)
- `created_at`, `updated_at` (Owners table)
- `created_at`, `updated_at` (Remittances table)
**Pattern**: 3 tables use `created`/`updated`, 3 tables use `created_at`/`updated_at`, 1 table uses `created_timestamp`/`modified_timestamp` - **FRAGMENTED (50% vs 50% with 1 outlier)**

**API Endpoint Patterns**:

**Standard REST (implicit action from HTTP method)**:
- `POST /api/v1/tenants`
- `PUT /api/v1/tenants/{id}`
- `POST /api/v1/contracts`
- `PUT /api/v1/contracts/{id}`
- `POST /api/v1/payments`
- `POST /api/v1/owners`
- `PUT /api/v1/owners/{id}`
- `POST /api/v1/remittances`
(8 endpoints)

**Explicit verb suffix**:
- `POST /api/v1/properties/create`
- `PUT /api/v1/properties/{id}/update`
- `PUT /api/v1/payments/{id}/record-payment`
- `POST /api/v1/contracts/{id}/terminate`
(4 endpoints)

**Pattern**: 67% follow standard REST (action implicit), 33% use explicit verb suffixes - **INCONSISTENT**

**Adversarial Verification Questions**:

1. **Table naming - Are ALL tables consistently singular/plural?**
   - ✓ All tables are plural - CONSISTENT

2. **JWT storage - Is the token storage approach explicitly stated AND consistent with existing modules?**
   - ❌ Token storage approach NOT documented (critical security decision left implicit)
   - Adversarial risk: Frontend developers could choose localStorage (vulnerable to XSS) vs httpOnly cookies (more secure)

3. **Environment variables - Do ALL variables follow the same naming convention?**
   - ❌ Environment variable naming convention NOT documented

4. **Foreign key naming - Do ALL foreign keys follow the same pattern?**
   - ❌ NO - Mixed `_id`, `ID`, `_fk` patterns detected
   - Adversarial risk: Each new table can introduce a new foreign key style

### Detection Strategy 3: Cross-Reference Detection

**Pattern Conflicts Across Sections**:

1. **Timestamp naming conflict between Data Model and API Response**:
   - Data Model: Uses `created`/`updated` OR `created_at`/`updated_at` OR `created_timestamp`/`modified_timestamp`
   - API Response format: Shows `"timestamp": "2024-01-15T10:30:00Z"` (singular `timestamp`)
   - Adversarial risk: No clear mapping between database field names and API response field names

2. **Case style conflict within Contracts table**:
   - Same table uses both snake_case (`contract_start_date`, `created_timestamp`) and PascalCase (`PropertyID`, `TenantID`)
   - Adversarial risk: Developers might assume "foreign keys use PascalCase, own fields use snake_case" rule that's never documented

3. **API endpoint action naming conflict**:
   - Properties API uses explicit verbs (`/create`, `/update`)
   - Other APIs use implicit REST semantics (HTTP method determines action)
   - Adversarial risk: New APIs can follow either pattern without clear guidance

### Detection Strategy 4: Gap-Based Detection

**Critical Gaps Preventing Consistency Verification**:

1. **JWT Token Storage Location** (CRITICAL):
   - Impact: Different frontend modules could store tokens differently
   - Security implication: localStorage exposes tokens to XSS attacks
   - No existing system reference to verify consistency

2. **Java Class Naming Conventions** (SIGNIFICANT):
   - Controller/Service/Repository class names not documented
   - Impact: Cannot verify if class names match table names or follow different convention

3. **Error Handling Pattern** (SIGNIFICANT):
   - Document shows error response format but doesn't specify WHERE error handling occurs
   - Global exception handler vs individual try-catch not documented
   - Impact: Inconsistent error handling across controllers

4. **Asynchronous Processing Pattern** (MODERATE):
   - Document doesn't specify if async operations exist
   - Impact: Future async features might use inconsistent patterns

**Adversarial Lens - Gaps Enabling Inconsistent Implementations**:

1. **Missing primary key naming rule** enables mixing `id` and `{entity}_id`
2. **Missing foreign key naming rule** enables mixing `_id`, `ID`, `_fk`
3. **Missing timestamp field naming rule** enables 3-way fragmentation
4. **Missing API endpoint naming rule** enables REST vs verb-suffix mixing
5. **Missing JWT storage rule** enables security vulnerability introduction

### Detection Strategy 5: Exploratory Detection

**Unstated Patterns**:

1. **Implicit pattern: UUID for all primary keys** (POSITIVE):
   - All tables use UUID type for primary keys
   - This pattern is followed consistently but not explicitly documented

2. **Implicit pattern: VARCHAR(20) for phone numbers** (POSITIVE):
   - Tenants and Owners both use VARCHAR(20) for phone_number
   - Consistent but not documented as a standard

3. **Implicit pattern: VARCHAR(255) for email** (POSITIVE):
   - Tenants and Owners both use VARCHAR(255) for email
   - Consistent but not documented as a standard

**Edge Cases & Unusual Scenarios**:

1. **"id" vs "{entity}_id" for primary keys**:
   - Contracts table breaks the pattern used by 5 other tables
   - Adversarial risk: This creates precedent for using generic "id" in future tables

2. **"contract_fk" and "owner_fk" vs standard foreign key naming**:
   - Only Payments and Remittances use `_fk` suffix
   - Other tables use `_id` or `ID` suffix
   - Adversarial risk: Creates 3-way split in naming convention

3. **API versioning is present (/api/v1/) but version management policy is not documented**:
   - Impact: No guidance on when to increment version, backward compatibility rules

**Cross-Category Issues**:

1. **Naming + API Design**: PascalCase in database (PropertyID, TenantID) doesn't match API naming patterns
   - APIs use kebab-case paths but database uses mixed case
   - Potential mapping confusion

2. **Architecture + Implementation**: Transaction boundary documented at Service layer, but error handling layer not specified
   - If global exception handler exists, it could interfere with @Transactional rollback

**Adversarial "Near-Misses"**:

1. **Timestamp naming "almost" consistent**:
   - 3 tables use `created`/`updated`
   - 3 tables use `created_at`/`updated_at`
   - 1 table uses `created_timestamp`/`modified_timestamp`
   - Adversarial interpretation: Developer could argue "both patterns exist in codebase" to justify either choice

2. **Foreign key naming "almost" has pattern**:
   - Could argue: "FK to another service's table uses `_fk`, FK to same service uses `_id`"
   - But PropertyID/TenantID break this interpretation

3. **API endpoints "almost" follow REST**:
   - Most endpoints follow REST semantics
   - But Properties API breaks pattern with `/create` and `/update` suffixes
   - Adversarial interpretation: "Complex operations get verb suffixes" (but no clear definition of "complex")

---

## Phase 2: Organization & Reporting

### Inconsistencies Identified

#### Critical (Architectural Structure Fragmentation Risk)

**C1. Mixed Foreign Key Naming Pattern (3-way fragmentation)**

**Evidence**:
- Contracts table: `PropertyID`, `TenantID` (PascalCase with ID suffix)
- Properties table: `owner_id` (snake_case with _id suffix)
- Payments table: `contract_fk` (snake_case with _fk suffix)
- Remittances table: `owner_fk` (snake_case with _fk suffix)

**Pattern Analysis**:
- `_id` suffix: 1 instance (20%)
- `ID` suffix: 2 instances (40%)
- `_fk` suffix: 2 instances (40%)
- No dominant pattern (none exceeds 50%)

**Impact**:
- Creates precedent for 3 different foreign key naming styles
- Each new table can arbitrarily choose any of the 3 patterns
- ORM relationship mapping code will be inconsistent
- Database schema readability severely degraded
- **Adversarial exploitation**: Developer can justify any choice by pointing to existing examples, fragmenting the schema further

**C2. Inconsistent Timestamp Field Naming (3-way fragmentation)**

**Evidence**:
- Properties, Payments: `created`, `updated`
- Tenants, Owners, Remittances: `created_at`, `updated_at`
- Contracts: `created_timestamp`, `modified_timestamp`

**Pattern Analysis**:
- `created`/`updated`: 2 tables (33%)
- `created_at`/`updated_at`: 3 tables (50%)
- `created_timestamp`/`modified_timestamp`: 1 table (17%)
- Weak majority for `created_at`/`updated_at` but not dominant

**Impact**:
- Audit logging queries cannot use consistent field names
- Generic timestamp handling code (base entity class, audit interceptor) cannot be implemented
- Database triggers or functions for timestamp management must handle 3 different naming patterns
- **Adversarial exploitation**: Developer can claim "all three patterns exist in production" to avoid refactoring effort

**C3. Undocumented JWT Token Storage Location (Security Risk)**

**Evidence**:
- Section 5 documents JWT authentication mechanism
- Token transmission method documented (Authorization: Bearer header)
- **Token storage location (client-side) not specified**

**Missing Information**:
- localStorage vs sessionStorage vs httpOnly cookie not documented
- No reference to existing authentication modules

**Impact**:
- **CRITICAL SECURITY RISK**: If developers choose localStorage, JWT tokens are vulnerable to XSS attacks
- httpOnly cookie is the secure standard but requires explicit documentation
- Different frontend modules could store tokens differently, creating security inconsistency
- **Adversarial exploitation**: Security-unaware developer might choose localStorage for "convenience", introducing XSS vulnerability vector

#### Significant (Developer Experience & API Consistency)

**S1. Inconsistent API Endpoint Action Naming**

**Evidence**:
- **Explicit verb suffix pattern** (4 endpoints, 33%):
  - `POST /api/v1/properties/create`
  - `PUT /api/v1/properties/{id}/update`
  - `PUT /api/v1/payments/{id}/record-payment`
  - `POST /api/v1/contracts/{id}/terminate`

- **Standard REST pattern** (8 endpoints, 67%):
  - `POST /api/v1/tenants` (create implied)
  - `PUT /api/v1/tenants/{id}` (update implied)
  - `POST /api/v1/contracts` (create implied)
  - Others follow same pattern

**Pattern Analysis**:
- Majority (67%) follow standard REST semantics
- Properties module breaks pattern with `/create` and `/update` suffixes
- No documented rule for when to use explicit verb suffixes

**Impact**:
- API inconsistency confuses frontend developers
- New API endpoints lack clear naming guidance
- Cannot generate API client code with consistent conventions
- URL routing rules become complex (some paths have verbs, some don't)
- **Adversarial exploitation**: Developer can add verb suffixes claiming "Properties API does it" without justification

**S2. Primary Key Naming Inconsistency**

**Evidence**:
- **Descriptive naming** (5 tables, 83%): `property_id`, `tenant_id`, `payment_id`, `owner_id`, `remittance_id`
- **Generic naming** (1 table, 17%): `id` (Contracts table)

**Pattern Analysis**:
- Strong majority (83%) use descriptive `{entity}_id` pattern
- Contracts table is an outlier using generic `id`

**Impact**:
- Join queries become inconsistent (contracts.id vs properties.property_id)
- Generic "id" naming makes SQL queries less self-documenting
- ORM entity base class design becomes unclear (should it provide generic "id" field?)
- **Adversarial exploitation**: Developer can use generic "id" in new tables citing Contracts as precedent

**S3. Undocumented Error Handling Pattern**

**Evidence**:
- Section 5 documents error response format
- Section 6 documents logging levels for errors
- **Error handling architecture not documented** (global exception handler vs controller-level try-catch)

**Missing Information**:
- No mention of @ControllerAdvice or global exception handler
- No guidance on where to catch exceptions (Controller vs Service layer)
- No reference to existing error handling implementation

**Impact**:
- Inconsistent exception handling across controllers
- Some controllers might have try-catch blocks, others rely on global handler
- Error response format might not be enforced consistently
- **Adversarial exploitation**: Developer can add controller-level try-catch that bypasses global error handling standards

#### Moderate (File Organization & Configuration)

**M1. Undocumented Java Class Naming Conventions**

**Evidence**:
- Section 3 lists Controller/Service/Repository class names (e.g., PropertyController, PropertyService)
- Naming pattern appears to be `{Entity}{Layer}` but not explicitly documented

**Missing Information**:
- Class naming convention rule not stated
- File naming convention not stated
- Package structure conventions not documented

**Impact**:
- Cannot verify if class names consistently match entity names
- New developers lack guidance on naming conventions
- Code review cannot reference documented naming standards

**M2. Undocumented Environment Variable Naming Convention**

**Evidence**:
- Section 6 mentions structured JSON logging output to CloudWatch Logs
- No environment variable naming conventions documented

**Missing Information**:
- UPPER_SNAKE_CASE vs camelCase not specified
- Prefix conventions for different config categories not documented

**Impact**:
- Inconsistent environment variable naming across deployment configs
- Configuration management becomes difficult to maintain

**M3. Undocumented API Version Management Policy**

**Evidence**:
- All endpoints use `/api/v1/` prefix
- Version increment policy not documented
- Backward compatibility policy not documented

**Missing Information**:
- When to increment API version (breaking change vs non-breaking)
- How to maintain multiple API versions
- Deprecation policy for old versions

**Impact**:
- No guidance on API evolution strategy
- Risk of breaking changes without version increment

#### Minor (Documentation & Implicit Patterns)

**P1. Positive: Consistent UUID Usage for Primary Keys**

**Evidence**: All tables use UUID type for primary keys

**Note**: This pattern is followed consistently but not explicitly documented as a design decision. Recommend documenting this as a standard pattern.

**P2. Positive: Consistent Table Name Plurality**

**Evidence**: All tables use plural naming (Properties, Tenants, Contracts, Payments, Owners, Remittances)

**Note**: This pattern is followed consistently but not explicitly documented.

**P3. Positive: Consistent Phone/Email Field Types**

**Evidence**:
- Phone numbers: VARCHAR(20) in both Tenants and Owners
- Email addresses: VARCHAR(255) in both Tenants and Owners

**Note**: These data type choices are consistent but not documented as standards.

---

### Pattern Evidence

#### Existing Codebase Pattern References

**Dominant Pattern Analysis (from design document internal consistency)**:

1. **Primary Key Naming**:
   - Dominant pattern: `{entity}_id` (83% - 5 out of 6 tables)
   - Outlier: `id` (17% - Contracts table)

2. **Timestamp Field Naming**:
   - Weak majority: `created_at`/`updated_at` (50% - 3 out of 6 tables)
   - Alternative: `created`/`updated` (33% - 2 out of 6 tables)
   - Outlier: `created_timestamp`/`modified_timestamp` (17% - 1 table)

3. **Foreign Key Naming**:
   - No dominant pattern
   - `_id` suffix: 20%
   - `ID` suffix: 40%
   - `_fk` suffix: 40%

4. **API Endpoint Naming**:
   - Dominant pattern: Standard REST (67% - 8 endpoints)
   - Alternative: Explicit verb suffix (33% - 4 endpoints)

5. **Table Name Plurality**:
   - Consistent pattern: Plural naming (100% - all 6 tables)

**Note**: No external codebase references are available in the design document. Pattern analysis is based on internal consistency within the document itself. This makes consistency verification limited to identifying internal contradictions.

---

### Impact Analysis

#### Critical Issues - Consequences of Divergence

**C1. Foreign Key Naming Fragmentation**

**Immediate Impact**:
- JPA entity relationship annotations will use 3 different naming patterns
- Database documentation and ER diagrams become harder to read
- New developers must memorize 3 patterns instead of 1

**Long-term Impact**:
- Schema refactoring cost increases (cannot apply bulk rename scripts)
- Database migration scripts must handle multiple patterns
- Automated schema validation tools cannot enforce consistent naming

**Adversarial Exploitation Scenario**:
Developer adding new "maintenance_requests" table references multiple tables:
- Could use `property_id` (following Properties pattern)
- Could use `PropertyID` (following Contracts pattern)
- Could use `contract_fk` (following Payments pattern)
- No documented rule prevents any choice, leading to 4-way fragmentation

**C2. Timestamp Naming Fragmentation**

**Immediate Impact**:
- Cannot implement generic audit logging with consistent field names
- JPA @MappedSuperclass for base entity cannot be used effectively
- Hibernate Envers (audit framework) configuration becomes complex

**Long-term Impact**:
- Temporal queries (e.g., "find all records created this month") require table-specific logic
- Database triggers for automatic timestamp updates must handle 3 patterns
- Reporting queries become more complex

**Adversarial Exploitation Scenario**:
Developer can introduce 4th variant (`creation_date`/`modification_date`) citing "all variants exist in production" as justification, further fragmenting the pattern.

**C3. JWT Token Storage Security Risk**

**Immediate Impact**:
- **HIGH SECURITY RISK**: Unguided developers likely choose localStorage (simpler) over httpOnly cookie (more secure)
- localStorage exposes JWT to XSS attacks (any injected script can steal tokens)

**Long-term Impact**:
- Security audit identifies vulnerability, requires expensive frontend refactoring
- Different frontend modules might use different storage methods, creating security inconsistency
- Compliance issues (GDPR, PCI-DSS) if sensitive tokens are stored insecurely

**Adversarial Exploitation Scenario**:
Malicious developer or attacker can inject XSS payload that steals JWT from localStorage, enabling session hijacking and unauthorized access to all API endpoints.

#### Significant Issues - Developer Experience Impact

**S1. API Endpoint Naming Inconsistency**

**Immediate Impact**:
- Frontend developers must memorize which modules use verb suffixes vs standard REST
- API client code generation tools produce inconsistent method names
- API documentation appears unprofessional

**Long-term Impact**:
- New API endpoints lack clear naming guidance
- Code review friction increases (subjective debates about naming)
- API versioning decisions become unclear

**Adversarial Exploitation Scenario**:
Developer can add unnecessary verb suffixes (e.g., `/api/v1/tenants/create-new-tenant`) claiming consistency with Properties API, creating verbose and redundant endpoint names.

**S2. Primary Key Naming Inconsistency**

**Immediate Impact**:
- SQL join queries mix descriptive and generic naming (`properties.property_id = contracts.id`)
- ORM entity design unclear (should base class provide `id` field or should each entity define its own?)

**Long-term Impact**:
- Cannot implement generic repository methods that rely on consistent primary key naming
- Database schema readability decreases

**S3. Undocumented Error Handling Pattern**

**Immediate Impact**:
- Each developer implements error handling differently
- Error response format might not be consistently enforced
- Exception logging might occur at multiple layers (duplication)

**Long-term Impact**:
- Debugging becomes difficult (no consistent error handling flow)
- Global error handling standards cannot be enforced
- Error monitoring and alerting systems receive inconsistent data

---

### Recommendations

#### Critical Priority

**R1. Establish and Document Consistent Foreign Key Naming Convention**

**Recommendation**: Standardize on `{referenced_table_singular}_id` pattern (e.g., `owner_id`, `property_id`, `tenant_id`, `contract_id`)

**Rationale**:
- Matches the dominant primary key naming pattern (`{entity}_id`)
- Self-documenting (foreign key name indicates referenced table)
- Widely used in Rails, Django, and other ORM conventions

**Specific Changes**:
- Contracts table: Rename `PropertyID` → `property_id`, `TenantID` → `tenant_id`
- Payments table: Rename `contract_fk` → `contract_id`
- Remittances table: Rename `owner_fk` → `owner_id`

**Documentation Addition**: Add to Section 4 or new "Naming Conventions" subsection:
```
Foreign Key Naming Rule: Use `{referenced_table_singular}_id` format
Examples: owner_id, property_id, tenant_id, contract_id
```

**R2. Establish and Document Consistent Timestamp Field Naming**

**Recommendation**: Standardize on `created_at` / `updated_at` pattern (50% current usage)

**Rationale**:
- Most widely adopted in Rails, Laravel, Django ecosystems
- Clear semantic meaning (`_at` suffix indicates timestamp)
- Currently used by 3 out of 6 tables (weak majority)

**Specific Changes**:
- Properties table: Rename `created` → `created_at`, `updated` → `updated_at`
- Payments table: Rename `created` → `created_at`, `updated` → `updated_at`
- Contracts table: Rename `created_timestamp` → `created_at`, `modified_timestamp` → `updated_at`

**Documentation Addition**: Add to Section 4:
```
Timestamp Field Naming Rule: Use `created_at` and `updated_at` for all tables
Type: TIMESTAMP, NOT NULL
Automatically managed by JPA @CreatedDate and @LastModifiedDate annotations
```

**R3. Document JWT Token Storage Location and Security Policy**

**Recommendation**: Mandate httpOnly cookie storage for JWT tokens (CRITICAL SECURITY)

**Rationale**:
- httpOnly cookies are NOT accessible to JavaScript, preventing XSS-based token theft
- Cookies are automatically sent with requests (no manual Authorization header management)
- Industry best practice for session token storage (OWASP recommendation)

**Documentation Addition**: Add to Section 5 "Authentication" subsection:
```
JWT Token Storage Policy:
- Access Token: Stored in httpOnly cookie (name: `access_token`, SameSite: Strict, Secure: true)
- Refresh Token: Stored in httpOnly cookie (name: `refresh_token`, SameSite: Strict, Secure: true)
- DO NOT store JWT in localStorage or sessionStorage (XSS vulnerability risk)
- Token transmission: Cookies are automatically sent; no Authorization header required
- CSRF protection: SameSite=Strict cookie attribute prevents CSRF attacks
```

#### Significant Priority

**R4. Standardize API Endpoint Naming on REST Semantics**

**Recommendation**: Remove explicit verb suffixes; rely on HTTP methods to convey action semantics

**Rationale**:
- 67% of endpoints already follow this pattern (dominant convention)
- Standard REST practice (HTTP POST = create, PUT = update, DELETE = delete)
- Simpler, more concise endpoint paths

**Specific Changes**:
- `POST /api/v1/properties/create` → `POST /api/v1/properties`
- `PUT /api/v1/properties/{id}/update` → `PUT /api/v1/properties/{id}`
- `PUT /api/v1/payments/{id}/record-payment` → `PUT /api/v1/payments/{id}/payment-record` (if recording payment is a sub-resource) OR `PUT /api/v1/payments/{id}` (if it's a standard update)
- `POST /api/v1/contracts/{id}/terminate` → Consider `DELETE /api/v1/contracts/{id}` OR keep as-is if termination is semantically different from deletion (business logic distinction)

**Exception Rule**: Use verb suffixes ONLY for actions that don't map to CRUD operations (e.g., `/execute`, `/calculate`, `/export`)

**Documentation Addition**: Add to Section 5:
```
API Endpoint Naming Convention:
- Use HTTP methods to convey action semantics (POST=create, GET=read, PUT=update, DELETE=delete)
- Do NOT add verb suffixes for standard CRUD operations
- Use verb suffixes ONLY for non-CRUD actions (e.g., POST /api/v1/reports/generate, POST /api/v1/invoices/{id}/send)
```

**R5. Standardize Primary Key Naming on Descriptive Pattern**

**Recommendation**: Use `{entity}_id` pattern for all primary keys (83% current usage)

**Rationale**:
- Matches dominant pattern (5 out of 6 tables)
- Self-documenting in SQL queries
- Consistent with foreign key naming recommendation

**Specific Changes**:
- Contracts table: Rename `id` → `contract_id`

**Documentation Addition**: Add to Section 4:
```
Primary Key Naming Rule: Use `{entity_singular}_id` format
Examples: property_id, tenant_id, contract_id, payment_id
Type: UUID
All primary keys use UUID type for global uniqueness and distributed system compatibility
```

**R6. Document Error Handling Architecture**

**Recommendation**: Specify global exception handler pattern with centralized error response formatting

**Rationale**:
- Ensures consistent error response format
- Prevents exception handling code duplication across controllers
- Aligns with Spring Boot best practices (@ControllerAdvice)

**Documentation Addition**: Add to Section 6:
```
Error Handling Pattern:
- Global exception handler: Use @ControllerAdvice with @ExceptionHandler methods
- Controller layer: Do NOT add try-catch blocks; let exceptions propagate to global handler
- Service layer: Throw domain-specific exceptions (e.g., PropertyNotFoundException, InvalidContractException)
- Global handler converts exceptions to standard error response format (Section 5)
- Logging: Global handler logs all exceptions with ERROR level before returning response
```

#### Moderate Priority

**R7. Document Java Class and File Naming Conventions**

**Recommendation**: Explicitly document the apparent `{Entity}{Layer}` pattern

**Documentation Addition**: Add to Section 3 or new "Code Organization" section:
```
Class Naming Conventions:
- Controller classes: {Entity}Controller (e.g., PropertyController, TenantController)
- Service classes: {Entity}Service (e.g., PropertyService, ContractService)
- Repository interfaces: {Entity}Repository (e.g., PropertyRepository, TenantRepository)
- Entity classes: {Entity} (singular, PascalCase) (e.g., Property, Tenant, Contract)

File Naming Conventions:
- Java files: {ClassName}.java (e.g., PropertyController.java)
- Test files: {ClassName}Test.java (e.g., PropertyServiceTest.java)
```

**R8. Document Environment Variable Naming Convention**

**Recommendation**: Standardize on UPPER_SNAKE_CASE (industry standard)

**Documentation Addition**: Add to Section 6:
```
Environment Variable Naming Convention:
- Use UPPER_SNAKE_CASE format (e.g., DATABASE_URL, JWT_SECRET_KEY)
- Prefix by category: DB_ for database, AWS_ for AWS resources, JWT_ for authentication
Examples: DB_HOST, DB_PORT, AWS_S3_BUCKET_NAME, JWT_TOKEN_EXPIRATION_HOURS
```

**R9. Document API Version Management Policy**

**Recommendation**: Specify version increment and deprecation rules

**Documentation Addition**: Add to Section 5:
```
API Version Management Policy:
- Version increment: Create new version (v2) for breaking changes (field removal, type change, endpoint removal)
- Non-breaking changes: Add to current version (new optional fields, new endpoints)
- Version support: Maintain N-1 version for 6 months after new version release
- Deprecation notice: Add `X-API-Deprecation-Notice` header 3 months before sunset
- Version selection: Client specifies version in URL path (/api/v1/, /api/v2/)
```

#### Positive Acknowledgments

**A1. Excellent: Consistent UUID Primary Key Usage**
All tables use UUID primary keys, providing global uniqueness and distributed system compatibility. Recommend explicitly documenting this as a design decision.

**A2. Excellent: Consistent Table Name Plurality**
All tables use plural naming convention, which is a widely adopted standard. Recommend documenting this explicitly.

**A3. Excellent: Consistent Phone/Email Field Types**
VARCHAR(20) for phone numbers and VARCHAR(255) for email addresses are consistently applied. Recommend documenting these as data type standards.

---

## Summary

This design document exhibits **critical inconsistencies in database naming conventions** and **critical missing security documentation** that could lead to codebase fragmentation and security vulnerabilities.

**Most Critical Issues**:
1. **Foreign key naming has 3-way fragmentation** (_id, ID, _fk) with no dominant pattern
2. **Timestamp field naming has 3-way fragmentation** (created/updated, created_at/updated_at, created_timestamp/modified_timestamp)
3. **JWT token storage location is undocumented**, creating XSS vulnerability risk

**Key Strengths**:
- Consistent table naming (all plural)
- Consistent primary key types (all UUID)
- Well-documented transaction boundaries and logging patterns

**Recommended Actions**:
1. **Immediately** document JWT token storage policy (httpOnly cookie mandate)
2. **Before implementation** standardize foreign key naming and timestamp field naming
3. **Before implementation** standardize API endpoint naming to follow REST semantics
4. Add comprehensive "Naming Conventions" section to design document covering all database, API, and code naming rules
