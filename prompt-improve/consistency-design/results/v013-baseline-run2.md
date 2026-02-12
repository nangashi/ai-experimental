# Consistency Design Review: Travel Booking Platform

## Executive Summary

This design document exhibits **critical architectural inconsistencies** with the existing FlightBooker system, particularly in implementation patterns (error handling, logging, HTTP client) and database schema conventions (column naming, primary key types, timestamp fields). The design proposes 3 different column naming styles across 3 tables and introduces architectural patterns that conflict with established centralized approaches. These inconsistencies create significant maintenance burden and enable future codebase fragmentation.

**Critical Findings**: 6 architectural pattern conflicts, 11 naming convention inconsistencies, 7 documentation gaps

---

## Inconsistencies Identified

### Critical: Architectural & Implementation Pattern Conflicts

#### C-1. Error Handling Pattern Deviation (CRITICAL)
**Issue**: Design proposes individual try-catch blocks in each controller method, but existing FlightBooker uses GlobalExceptionHandler with @RestControllerAdvice for centralized error handling.

**Pattern Evidence**:
- Existing system: GlobalExceptionHandler (line 268: "GlobalExceptionHandler（@RestControllerAdvice）による集中管理")
- Proposed design: Individual try-catch in controllers (lines 192-204)

**Impact**:
- Duplicates error handling logic across all controllers
- Inconsistent error response formats across modules
- Makes it difficult to add cross-cutting concerns (e.g., error logging, monitoring)
- Forces developers to maintain two different error handling patterns in the same codebase

**Adversarial Risk**: Developers could exploit this inconsistency to bypass centralized error handling rules, making debugging and error tracking inconsistent across modules.

**Recommendation**: Adopt GlobalExceptionHandler pattern from existing FlightBooker. Remove individual try-catch blocks from controller examples and document exception types that service layer should throw (ValidationException, BookingException, etc.) that will be caught by @RestControllerAdvice.

---

#### C-2. Logging Format Inconsistency (CRITICAL)
**Issue**: Design proposes plain text logging format, but existing system uses JSON structured logging.

**Pattern Evidence**:
- Existing system: JSON structured logs (line 269: `{"timestamp": "...", "level": "INFO", "message": "..."}`)
- Proposed design: Plain text logs (lines 212-213: `2024-03-15 10:30:45 INFO [HotelBookingService] Creating booking...`)

**Impact**:
- Prevents log aggregation tools from parsing logs consistently
- Makes cross-module log analysis difficult
- Structured logging enables better filtering, searching, and alerting
- Mixed log formats require maintaining two different log parsing configurations

**Adversarial Risk**: Plain text logs make it easier to hide important information or make logs less machine-readable, reducing observability.

**Recommendation**: Document JSON structured logging as the standard format. Specify required fields (timestamp, level, logger, message, context) and show example configuration for Logback to output JSON. Align with existing FlightBooker logging infrastructure.

---

#### C-3. HTTP Client Library Inconsistency (CRITICAL)
**Issue**: Design proposes RestTemplate for external API communication, but existing FlightBooker uses WebClient (Spring WebFlux).

**Pattern Evidence**:
- Existing system: WebClient (line 270: "HTTP通信: WebClient（Spring WebFlux）")
- Proposed design: RestTemplate (line 40: "RestTemplate (HTTP通信)")

**Impact**:
- RestTemplate is in maintenance mode (not actively developed)
- WebClient supports reactive programming and better performance
- Mixed HTTP client libraries require maintaining two different dependency sets
- Inconsistent timeout/retry configurations between modules
- Developers must learn and maintain two different HTTP client patterns

**Adversarial Risk**: Using deprecated RestTemplate could be used to justify technical debt accumulation ("we're already using it in this module").

**Recommendation**: Replace RestTemplate with WebClient to align with existing system. Document WebClient configuration pattern including timeout, retry, and connection pool settings.

---

#### C-4. Database Column Naming Case Inconsistency (CRITICAL)
**Issue**: Three tables use three different column naming conventions within the same design document.

**Pattern Evidence**:
- hotel_bookings: snake_case (checkin_date, total_price, booking_status)
- car_rentals: camelCase (userId, pickupDate, totalPrice)
- user_review: snake_case (user_id, booking_ref)
- Existing system: snake_case (line 264: created_at, updated_at)

**Quantitative Evidence**:
- snake_case: 2 tables (hotel_bookings, user_review) + existing system = 100% existing, 67% proposed
- camelCase: 1 table (car_rentals) = 0% existing, 33% proposed
- Dominant pattern: snake_case (100% existing system adoption)

**Impact**:
- Forces developers to remember different naming conventions per table
- SQL queries mixing tables require mental context switching
- ORM mapping configurations become inconsistent
- Creates precedent for "either style is acceptable" enabling future fragmentation

**Adversarial Risk**: camelCase in car_rentals could encourage developers to use camelCase in future modules, fragmenting the codebase into incompatible subsystems.

**Recommendation**: Standardize ALL columns to snake_case to match existing FlightBooker convention. Update car_rentals table to use: user_id, car_id, pickup_date, return_date, total_price, created_at, modified_at.

---

#### C-5. File Placement Policy Not Documented (CRITICAL)
**Issue**: Design specifies layer architecture (Presentation/Service/Repository) but does not document package structure or file placement rules.

**Information Gap**: No information about:
- Package naming convention (e.g., com.example.travelbooking.hotel.controller)
- Whether to use domain-based organization (hotel/, car/, review/) or layer-based (controller/, service/, repository/)
- File naming conventions for controller/service/repository classes

**Impact**:
- Developers will make inconsistent decisions about where to place new files
- Difficult to navigate codebase without clear organizational rules
- Could lead to mixed organizational patterns (some modules domain-based, others layer-based)

**Adversarial Risk**: Lack of file placement rules enables developers to create isolated module structures that are harder to refactor or integrate.

**Recommendation**: Add "File Organization" section documenting:
1. Root package structure (domain-based or layer-based)
2. Package naming convention
3. Class naming convention (e.g., {Domain}Controller, {Domain}Service)
4. Reference existing FlightBooker package structure if available

---

#### C-6. Mixed Case Conventions Enable Codebase Fragmentation (CRITICAL)
**Issue**: Allowing both snake_case and camelCase database columns creates precedent for "either is acceptable" which prevents standardization.

**Pattern Evidence**: See C-4 for detailed evidence.

**Impact**:
- New developers won't know which convention to follow
- Code reviews become subjective ("we already have camelCase tables")
- Schema evolution becomes inconsistent
- Prevents automated tooling from enforcing naming standards

**Adversarial Risk**: This ambiguity could be exploited to introduce more camelCase tables, eventually fragmenting the schema into two incompatible subsystems.

**Recommendation**: Explicitly document snake_case as the ONLY acceptable database naming convention in section 4. Add rationale: "Aligns with existing FlightBooker system and PostgreSQL ecosystem conventions."

---

### Significant: Naming Convention & API Design Inconsistencies

#### S-1. Primary Key Type Inconsistency
**Issue**: hotel_bookings and user_review use UUID primary keys, car_rentals uses BIGSERIAL, but existing FlightBooker consistently uses BIGSERIAL.

**Pattern Evidence**:
- hotel_bookings: booking_id UUID (line 99)
- car_rentals: id BIGSERIAL (line 113)
- user_review: review_id UUID (line 127)
- Existing system: BIGSERIAL for all (line 263: "id BIGSERIAL PRIMARY KEY")

**Quantitative Evidence**: Existing system = 100% BIGSERIAL, Proposed = 33% BIGSERIAL, 67% UUID

**Impact**:
- UUID primary keys have different performance characteristics (larger index size)
- Mixed primary key types complicate foreign key references
- Prevents standardized ID generation strategy across tables
- Creates confusion about when to use UUID vs BIGSERIAL

**Adversarial Risk**: Mixed primary key types create precedent for "either is acceptable" preventing schema standardization.

**Recommendation**: Standardize ALL tables to use BIGSERIAL primary keys with column name "id" to match existing FlightBooker convention. If UUID is required for specific business reasons (e.g., distributed ID generation), document the rationale explicitly.

---

#### S-2. Table Naming Consistency: Singular vs Plural
**Issue**: user_review table uses SINGULAR form, but hotel_bookings and car_rentals use plural, and existing system uses plural consistently.

**Pattern Evidence**:
- hotel_bookings: plural
- car_rentals: plural
- user_review: SINGULAR (line 124)
- Existing system: plural (flight_bookings, passengers, airports - line 261)

**Quantitative Evidence**: Existing = 100% plural, Proposed = 67% plural, 33% singular

**Impact**:
- Developers won't know whether to look for "user_reviews" or "user_review" table
- SQL queries become harder to read (inconsistent table name patterns)
- ORM entity naming becomes inconsistent

**Recommendation**: Rename user_review to user_reviews to match existing convention.

---

#### S-3. Foreign Key Naming Inconsistency
**Issue**: Foreign key columns use both user_id and userId conventions within the same design.

**Pattern Evidence**:
- hotel_bookings: user_id (line 100)
- car_rentals: userId (line 114)
- user_review: user_id (line 128)
- Existing system: {table_singular}_id pattern (line 262)

**Impact**:
- JOIN queries require remembering different column names per table
- Prevents using consistent foreign key naming in application code
- Creates confusion about foreign key naming rules

**Recommendation**: Standardize ALL foreign keys to snake_case: user_id, hotel_id, car_id, booking_id. Document foreign key naming rule: "{referenced_table_singular}_id".

---

#### S-4. Timestamp Column Naming: Three Different Patterns
**Issue**: Three different timestamp naming patterns used across tables.

**Pattern Evidence**:
- hotel_bookings: created, updated (lines 107-108)
- car_rentals: createdAt, modifiedAt (lines 121-122)
- user_review: created, updated (lines 132-133)
- Existing system: created_at, updated_at (line 264)

**Quantitative Evidence**: Existing = 100% created_at/updated_at, Proposed = 0% match existing

**Impact**:
- Audit logging and change tracking queries must handle three different column names
- ORM base entity classes cannot standardize timestamp fields
- Prevents creating database triggers with consistent column names

**Recommendation**: Standardize ALL timestamp columns to created_at and updated_at to match existing FlightBooker convention.

---

#### S-5. Status Column Naming Inconsistency
**Issue**: hotel_bookings uses booking_status, car_rentals and user_review use status.

**Pattern Evidence**:
- hotel_bookings: booking_status (line 106)
- car_rentals: status (line 120)
- user_review: No status column

**Impact**:
- Queries filtering by status must use different column names per table
- Prevents creating generic status tracking utilities

**Recommendation**: Standardize to "status" column name for all tables. If domain-specific prefixes are needed, document the naming rule explicitly.

---

#### S-6. HTTP Method Inconsistency for Cancellation
**Issue**: Hotels use PUT for cancellation, Cars use DELETE for cancellation, but existing system uses POST.

**Pattern Evidence**:
- Hotels: PUT /api/v1/hotels/bookings/{booking_id}/cancel (line 145)
- Cars: DELETE /api/v1/cars/reservations/{id} (line 151)
- Existing: POST for cancellation (line 266: /api/v1/bookings/cancel)

**Impact**:
- Client code must remember different HTTP methods for the same business operation
- API testing tools require different request configurations per domain
- Inconsistent with REST semantics (DELETE removes resource, cancel might not)

**Adversarial Risk**: Mixed HTTP methods could be used to justify "domain-specific" API patterns that fragment the API design.

**Recommendation**: Standardize cancellation to POST /api/v1/{domain}/{resource_plural}/{id}/cancel to match existing FlightBooker pattern. This aligns with the business action semantics (cancel is an action, not resource deletion).

---

#### S-7. HTTP Method for Search Inconsistency
**Issue**: Hotels use POST for search, Cars use GET for search.

**Pattern Evidence**:
- Hotels: POST /api/v1/hotels/search (line 142)
- Cars: GET /api/v1/cars/search (line 148)

**Impact**:
- Inconsistent API usage patterns force clients to handle search differently per domain
- GET for search with complex filters may hit URL length limits
- POST for search is unconventional but handles complex filter payloads better

**Recommendation**: Standardize search to POST for all domains to handle complex filter payloads consistently. Document rationale: "Search operations use POST to support complex filter criteria without URL length limitations."

---

#### S-8. Endpoint Action Naming Inconsistency
**Issue**: Hotels use /book endpoint, Cars use /reserve endpoint for the same business operation.

**Pattern Evidence**:
- Hotels: POST /api/v1/hotels/book (line 143)
- Cars: POST /api/v1/cars/reserve (line 149)

**Impact**:
- Inconsistent terminology confuses API consumers
- Prevents creating generic booking utilities
- Documentation must explain why different terms are used

**Recommendation**: Standardize to "book" for all domains (/hotels/book, /cars/book) to align with existing FlightBooker pattern (/flights/book). If domain-specific terminology is required, document the rationale.

---

#### S-9. Endpoint Path Structure: Verb in Path
**Issue**: Review API includes verb in path (/reviews/create), but other APIs don't (/hotels/book).

**Pattern Evidence**:
- Reviews: POST /api/v1/reviews/create (line 154)
- Hotels: POST /api/v1/hotels/book (line 143)

**Impact**:
- Inconsistent API path structure
- /reviews/create is redundant (POST already indicates creation)

**Recommendation**: Remove "create" from review endpoint: POST /api/v1/reviews (RESTful convention: POST to collection creates resource).

---

#### S-10. API Design vs Database Naming Mismatch
**Issue**: API paths use /bookings but table is hotel_bookings, /reservations but table is car_rentals.

**Pattern Evidence**:
- API: GET /api/v1/hotels/bookings/{booking_id} (line 144)
- Table: hotel_bookings (line 96)
- API: GET /api/v1/cars/reservations/{id} (line 150)
- Table: car_rentals (line 110)

**Impact**:
- Developer mental model doesn't map cleanly between API and database
- Inconsistent terminology across API and schema layers

**Recommendation**: Align API paths with table names:
- Use /hotel_bookings or keep hotel_bookings as domain concept
- Use /car_rentals instead of /reservations
- Or rename car_rentals table to car_reservations if "reservation" is the preferred domain term

---

#### S-11. Mixed HTTP Method Usage Enables Inconsistent Client Code
**Issue**: Using different HTTP methods for similar operations (PUT vs DELETE for cancellation) forces clients to implement multiple integration patterns.

**Pattern Evidence**: See S-6 for detailed evidence.

**Impact**:
- HTTP client libraries must support multiple methods
- API client SDKs become more complex
- Increases cognitive load for API consumers

**Recommendation**: Establish and document HTTP method usage policy in section 5. Standardize method selection based on operation semantics, not per-domain preferences.

---

### Moderate: Configuration & Documentation Gaps

#### M-1. Environment Variable Naming Convention Not Documented
**Issue**: Design mentions environment variables but doesn't specify naming convention.

**Information Gap**: Existing system uses lowercase snake_case (database_url, jwt_secret - line 271), but design doesn't document this for new services.

**Impact**:
- Developers might use UPPERCASE_SNAKE_CASE, camelCase, or other conventions
- Inconsistent environment variable naming makes deployment scripts fragile

**Recommendation**: Add section documenting environment variable naming: "Use lowercase snake_case (e.g., hotel_api_url, car_rental_api_key) to align with existing FlightBooker convention."

---

#### M-2. JWT Storage Location: Missing Existing System Context
**Issue**: Design specifies localStorage for JWT tokens but doesn't document existing system's approach.

**Information Gap**: Line 181 specifies "トークンはlocalStorageに保存" but section 8 doesn't document existing FlightBooker's token storage approach.

**Impact**:
- If existing system uses different storage (httpOnly cookies, sessionStorage), inconsistency creates security risks
- Cannot verify if localStorage choice aligns with existing security standards

**Recommendation**: Research existing FlightBooker's JWT storage approach and document comparison. If existing system uses different storage, provide rationale for divergence or align with existing approach.

---

#### M-3. Transaction Boundary Documentation Gap
**Issue**: Design documents @Transactional usage but doesn't document transaction boundary strategy or compare with existing system.

**Information Gap**: Line 218 shows @Transactional at service method level, but doesn't explain:
- Should all service methods be transactional?
- How to handle cross-service transactions?
- Read vs write transaction configuration?

**Impact**:
- Developers might apply @Transactional inconsistently
- Missing transaction boundaries could cause data consistency issues

**Recommendation**: Add "Transaction Management Strategy" subsection documenting:
1. Transaction boundary rules (service layer methods only)
2. Read-only transaction configuration
3. Cross-service transaction handling approach
4. Reference existing FlightBooker's transaction management if documented

---

#### M-4. Dependency Injection Pattern Not Documented
**Issue**: Design mentions using Spring but doesn't specify constructor injection vs field injection approach.

**Information Gap**: No documentation about which dependency injection pattern to use.

**Impact**:
- Developers will use mixed injection patterns (constructor, field, setter)
- Constructor injection is Spring best practice but not enforced

**Recommendation**: Add "Dependency Injection" subsection documenting constructor injection as the standard pattern. Provide example:
```java
@Service
public class HotelBookingService {
    private final HotelBookingRepository repository;

    public HotelBookingService(HotelBookingRepository repository) {
        this.repository = repository;
    }
}
```

---

#### M-5. DTO Conversion Pattern Not Documented
**Issue**: MapStruct is mentioned but conversion timing (controller vs service layer) is not specified.

**Information Gap**: Line 43 mentions MapStruct but design doesn't document where DTO conversion happens.

**Impact**:
- Some modules might convert at controller layer, others at service layer
- Inconsistent DTO conversion points make debugging difficult

**Recommendation**: Document DTO conversion pattern: "Use MapStruct mappers at controller layer to convert between API DTOs and domain entities. Service layer operates on domain entities only."

---

#### M-6. Validation Timing Not Documented
**Issue**: Bean Validation mentioned but not clear if validation happens at controller or service layer.

**Information Gap**: Line 248 mentions Bean Validation but doesn't specify where @Valid annotation should be applied.

**Impact**:
- Mixed validation timing (some at controller, some at service)
- Unclear where business validation vs input validation should occur

**Recommendation**: Document validation strategy: "Apply @Valid at controller layer for input validation. Implement business rule validation in service layer throwing domain-specific exceptions."

---

#### M-7. API Versioning Strategy Not Documented
**Issue**: /api/v1 used in all endpoints but versioning policy not documented.

**Information Gap**: When should API version be bumped? How to handle breaking changes?

**Impact**:
- Unclear when to create /api/v2
- Risk of breaking existing clients without versioning policy

**Recommendation**: Add "API Versioning Policy" subsection documenting:
1. When to bump version (breaking changes only)
2. How to deprecate old versions
3. Version support timeline

---

## Pattern Evidence Summary

### Existing FlightBooker Patterns (100% adoption in existing system)
| Pattern Category | Existing Convention | Proposed Design | Alignment |
|-----------------|---------------------|-----------------|-----------|
| Table naming | Plural (flight_bookings, passengers) | 67% plural, 33% singular | ❌ Partial |
| Column naming | snake_case | 67% snake_case, 33% camelCase | ❌ Partial |
| Primary key | BIGSERIAL id | 33% BIGSERIAL, 67% UUID | ❌ Conflict |
| Foreign key | {table_singular}_id | Mixed user_id/userId | ❌ Partial |
| Timestamp columns | created_at, updated_at | created/updated, createdAt/modifiedAt | ❌ No match |
| Error handling | GlobalExceptionHandler | Individual try-catch | ❌ Conflict |
| Logging format | JSON structured | Plain text | ❌ Conflict |
| HTTP client | WebClient | RestTemplate | ❌ Conflict |
| API response format | {data, error} | {data, error} | ✅ Match |
| Environment variables | lowercase_snake_case | Not documented | ⚠️ Gap |

### Quantitative Pattern Adoption
- **Database naming consistency**: 0% match with existing system across all tables
- **Implementation patterns**: 0% match (error handling, logging, HTTP client all conflict)
- **API response format**: 100% match (only consistent pattern)

---

## Impact Analysis

### Critical Business Impact
1. **Maintenance Burden Multiplication**: Mixed naming conventions (snake_case/camelCase) across 3 tables will force every database query to context-switch between naming styles
2. **Observability Degradation**: Plain text logs cannot be parsed by existing log aggregation infrastructure, creating blind spots in monitoring
3. **Technical Debt Accumulation**: Individual error handling blocks duplicate logic across 10+ controllers (3 controllers × 3-4 endpoints each)
4. **Integration Fragility**: RestTemplate vs WebClient difference means timeout/retry configurations must be maintained separately

### Development Velocity Impact
- Onboarding new developers requires learning two error handling patterns, two logging formats, two HTTP client libraries
- Code reviews require checking 8+ naming convention rules per table (vs 1 standard pattern)
- Database migrations become error-prone due to mixed column naming conventions

### Security & Reliability Impact
- Individual error handling increases risk of information disclosure through inconsistent error responses
- Mixed transaction boundary patterns could introduce race conditions
- Lack of structured logging makes security incident investigation difficult

### Long-Term Fragmentation Risk
- Precedent for "multiple acceptable patterns" enables future developers to introduce more variations
- Codebase becomes collection of incompatible subsystems rather than cohesive platform
- Refactoring costs increase exponentially as pattern variations multiply

---

## Recommendations Summary

### Priority 1: Critical Pattern Alignment (Blocking Issues)
1. **Error Handling**: Replace individual try-catch with GlobalExceptionHandler (@RestControllerAdvice)
2. **Logging**: Adopt JSON structured logging format with required fields (timestamp, level, logger, message, context)
3. **HTTP Client**: Replace RestTemplate with WebClient
4. **Database Naming**: Standardize ALL tables and columns to snake_case with existing conventions:
   - Tables: plural form (user_reviews, not user_review)
   - Primary keys: BIGSERIAL id (not UUID booking_id)
   - Foreign keys: {table_singular}_id pattern (user_id, not userId)
   - Timestamps: created_at, updated_at (not created/updated or createdAt/modifiedAt)
   - Status columns: status (not booking_status)
5. **File Placement**: Document package structure and file organization rules

### Priority 2: API Design Standardization
1. Standardize cancellation to POST /{domain}/{resource_plural}/{id}/cancel
2. Standardize search to POST /{domain}/search
3. Standardize booking action to /book across all domains
4. Remove verbs from RESTful resource paths (/reviews not /reviews/create)
5. Align API terminology with database table names

### Priority 3: Documentation Completeness
1. Document environment variable naming convention (lowercase_snake_case)
2. Document transaction management strategy
3. Document dependency injection pattern (constructor injection)
4. Document DTO conversion timing (controller layer)
5. Document validation strategy (input validation at controller, business validation at service)
6. Document API versioning policy
7. Research and document JWT storage approach from existing system

### Priority 4: Establish Explicit Design Principles
Add new section "Design Principles & Conventions" documenting:
1. Naming conventions (comprehensive rules, not examples)
2. Architectural patterns (dependency direction, layer responsibilities)
3. Implementation patterns (error handling, logging, HTTP clients)
4. Configuration management (environment variables, configuration files)
5. Rationale for any intentional divergence from existing patterns

---

## Conclusion

This design document requires **major revisions** before implementation. The proposed patterns conflict with existing FlightBooker system in 8 critical areas and introduce 11 naming inconsistencies across 3 tables. Most critically:

1. **100% mismatch** in implementation patterns (error handling, logging, HTTP client)
2. **0% alignment** with existing database naming conventions
3. **7 critical documentation gaps** enabling inconsistent implementations

**Primary Risk**: If implemented as-is, this design will fragment the codebase into incompatible subsystems, making future maintenance significantly more expensive and error-prone.

**Required Action**: Align ALL implementation patterns and naming conventions with existing FlightBooker system. Document explicit design principles to prevent future fragmentation. Re-review after revisions.

---

**Review Completed**: 2026-02-12
**Reviewer Role**: Consistency Architecture Review
**Document Version**: Round 013, v013-baseline, Run 2
