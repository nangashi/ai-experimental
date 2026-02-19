# Consistency Review Report: Travel Booking Platform システム設計書

## Executive Summary

This design document exhibits **critical architectural inconsistencies** across database schema design, API patterns, and implementation approaches when compared with the existing FlightBooker system. The analysis identified **25 distinct consistency issues**, including **10 critical-severity problems** that could fragment the codebase structure and prevent uniform maintenance practices.

The most severe issues involve:
- Mixed database naming conventions (snake_case vs camelCase columns, inconsistent timestamp patterns)
- Conflicting implementation patterns (centralized vs scattered error handling, WebClient vs RestTemplate)
- API design divergence (POST-only updates vs RESTful HTTP methods)
- Logging format incompatibility (structured JSON vs plain text)

---

## Inconsistencies Identified

### Critical Severity

#### 1. Database Column Naming Case Inconsistency
**Issue**: The `car_rentals` table uses camelCase column names (`userId`, `carId`, `pickupDate`, `returnDate`, `createdAt`, `modifiedAt`), while the existing FlightBooker system and the other two new tables (`hotel_bookings`, `user_review`) use snake_case.

**Pattern Evidence**:
- Existing system: 100% snake_case (`created_at`, `updated_at`, `user_id` - line 264)
- New hotel_bookings: snake_case (`booking_id`, `user_id`, `checkin_date`, `total_price`)
- New car_rentals: **camelCase** (`userId`, `carId`, `pickupDate`, `totalPrice`, `createdAt`, `modifiedAt`)
- New user_review: snake_case (`review_id`, `user_id`, `booking_ref`)

**Impact Analysis**:
- Creates fragmented ORM mapping strategies (requires different `@Column` annotation patterns)
- Forces developers to remember which table uses which convention
- Prevents uniform SQL query patterns across modules
- Adversarial risk: Enables developers to justify "this module uses camelCase" for future tables

**Recommendation**: Convert all `car_rentals` columns to snake_case:
```
userId → user_id
carId → car_id
pickupDate → pickup_date
returnDate → return_date
totalPrice → total_price
createdAt → created_at
modifiedAt → modified_at
```

---

#### 2. Timestamp Column Naming Inconsistency
**Issue**: Three different timestamp naming patterns are used across tables, none matching the existing system's `{verb}_at` convention.

**Pattern Evidence**:
- Existing system: `created_at`, `updated_at` (line 264)
- hotel_bookings: `created`, `updated` (missing `_at` suffix)
- car_rentals: `createdAt`, `modifiedAt` (camelCase + different verb "modified")
- user_review: `created`, `updated` (missing `_at` suffix)

**Impact Analysis**:
- Prevents uniform timestamp query patterns (e.g., common utility functions for date range filtering)
- Creates inconsistent entity mapping (`@CreationTimestamp` annotations point to different column names)
- Makes database-level auditing queries fragmented
- Adversarial risk: Three different patterns enable future developers to choose arbitrarily

**Recommendation**: Standardize all timestamp columns to `created_at` and `updated_at`:
```sql
-- hotel_bookings
created → created_at
updated → updated_at

-- car_rentals
createdAt → created_at
modifiedAt → updated_at

-- user_review
created → created_at
updated → updated_at
```

---

#### 3. Primary Key Naming and Type Inconsistency
**Issue**: Mixed primary key naming (simple `id` vs descriptive `booking_id`/`review_id`) and mixed types (BIGSERIAL vs UUID) without documented rationale.

**Pattern Evidence**:
- Existing system: `id BIGSERIAL PRIMARY KEY` (explicit standard - line 263)
- hotel_bookings: `booking_id UUID` - INCONSISTENT (both name and type)
- car_rentals: `id BIGSERIAL` - CONSISTENT
- user_review: `review_id UUID` - INCONSISTENT (both name and type)

**Impact Analysis**:
- Mixed PK types prevent uniform ID generation strategy (sequence vs UUID generator)
- Descriptive PK names create join complexity (must remember `booking_id` vs `id`)
- Foreign key references become inconsistent (some point to `id`, others to `{table}_id`)
- Prevents uniform repository pattern implementations
- Adversarial risk: Mixed naming enables fragmented entity relationship patterns

**Recommendation**:
1. **Naming**: Standardize to simple `id` for all primary keys
2. **Type**: Standardize to `BIGSERIAL` (matches existing system's explicit standard)
3. If UUID is required for specific business reasons (e.g., distributed ID generation), document the rationale explicitly and apply consistently to ALL new tables

```sql
-- hotel_bookings
booking_id UUID → id BIGSERIAL

-- user_review
review_id UUID → id BIGSERIAL
```

---

#### 4. Table Name Plurality Inconsistency
**Issue**: The `user_review` table uses singular naming, while the existing system and other new tables use plural naming.

**Pattern Evidence**:
- Existing system: `flight_bookings`, `passengers`, `airports` - all plural (line 261)
- New hotel_bookings: plural - CONSISTENT
- New car_rentals: plural - CONSISTENT
- New user_review: **singular** - INCONSISTENT

**Impact Analysis**:
- Creates confusion in repository and entity naming (UserReview entity maps to user_review table vs HotelBooking entity maps to hotel_bookings)
- Prevents uniform table discovery patterns
- Adversarial risk: Enables "singular vs plural" debates for future tables

**Recommendation**: Rename `user_review` to `user_reviews` to match the existing plural convention.

---

#### 5. Error Handling Strategy Inconsistency
**Issue**: The design proposes individual try-catch blocks in each controller method (section 6), directly conflicting with the existing FlightBooker system's centralized GlobalExceptionHandler pattern.

**Pattern Evidence**:
- Existing system: "GlobalExceptionHandler（@RestControllerAdvice）による集中管理" (line 268)
- New design: Individual try-catch per controller method (lines 192-204)

**Impact Analysis**:
- **Critical architectural divergence**: Scattered exception handling prevents consistent error response formats
- Duplicates error handling logic across controllers (violates DRY principle)
- Makes global error format changes require updating every controller method
- Prevents centralized logging/monitoring of exceptions
- Adversarial risk: Developers can implement different error responses per endpoint, fragmenting client error handling

**Recommendation**:
1. **Remove individual try-catch blocks** from controller methods
2. **Adopt the existing GlobalExceptionHandler pattern** using `@RestControllerAdvice`
3. Define custom exceptions (e.g., `ValidationException`, `BookingNotFoundException`) and map them in the global handler
4. Document this as the standard error handling pattern in section 6

Example alignment:
```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(ValidationException.class)
    public ResponseEntity<ApiResponse> handleValidation(ValidationException e) {
        return ResponseEntity.badRequest()
            .body(new ApiResponse(null, new ApiError("VALIDATION_ERROR", e.getMessage())));
    }
}
```

---

#### 6. HTTP Client Library Inconsistency
**Issue**: The design specifies RestTemplate for HTTP communication (line 40), while the existing FlightBooker system uses WebClient (Spring WebFlux).

**Pattern Evidence**:
- Existing system: "HTTP通信: WebClient（Spring WebFlux）" (line 270)
- New design: "RestTemplate (HTTP通信)" (line 40)

**Impact Analysis**:
- **Architectural inconsistency**: RestTemplate is synchronous/blocking, WebClient is asynchronous/non-blocking
- Creates performance inconsistency across modules (blocking vs reactive)
- RestTemplate is in maintenance mode (Spring documentation recommends WebClient)
- Prevents uniform HTTP client configuration (timeouts, interceptors)
- Makes future migration to reactive stack more difficult
- Adversarial risk: Mixed client libraries enable inconsistent retry/timeout strategies

**Recommendation**: Replace RestTemplate with WebClient to align with existing system:
```java
// Replace
private final RestTemplate restTemplate;

// With
private final WebClient webClient;
```

Update section 2.4 to reflect this:
```
- WebClient (HTTP通信) // instead of RestTemplate
```

---

#### 7. Logging Format Inconsistency
**Issue**: The design proposes plain-text logging (line 212), while the existing FlightBooker system uses structured JSON logging.

**Pattern Evidence**:
- Existing system: "JSON構造化ログ（`{"timestamp": "...", "level": "INFO", "message": "..."}`）" (line 269)
- New design: Plain text format (`2024-03-15 10:30:45 INFO [HotelBookingService] ...`)

**Impact Analysis**:
- **Critical operational divergence**: JSON logs are machine-parseable, plain text logs are not
- Prevents unified log aggregation in centralized logging systems (CloudWatch Logs Insights, ELK)
- Makes automated alerting/monitoring inconsistent across modules
- Prevents structured field extraction (e.g., filtering by user_id, booking_id)
- Adversarial risk: Mixed log formats require maintaining two parsing pipelines

**Recommendation**: Adopt structured JSON logging using Logback JSON encoder:
1. Add dependency: `logstash-logback-encoder`
2. Configure `logback-spring.xml` to output JSON format
3. Update section 6.2 to specify JSON structure:

```json
{
  "timestamp": "2024-03-15T10:30:45.123Z",
  "level": "INFO",
  "logger": "HotelBookingService",
  "message": "Creating booking for user 12345",
  "userId": 12345,
  "context": "hotel_booking"
}
```

---

#### 8. API HTTP Method Usage Inconsistency
**Issue**: The design uses PUT and DELETE methods for updates/cancellations, while the existing FlightBooker system uses POST for all update operations.

**Pattern Evidence**:
- Existing system: "HTTPメソッド: 主にPOSTとGET（更新系もPOST）" (line 266)
- Examples: `/api/v1/flights/book` (POST), `/api/v1/bookings/cancel` (POST)
- New hotel API: `PUT /api/v1/hotels/bookings/{booking_id}/cancel` - INCONSISTENT
- New car API: `DELETE /api/v1/cars/reservations/{id}` - INCONSISTENT

**Impact Analysis**:
- Creates inconsistent client integration patterns (some modules use POST-only, others use RESTful methods)
- Frontend code must handle different HTTP method conventions per module
- Prevents uniform API client configuration (e.g., CSRF protection strategies differ for PUT/DELETE)
- Adversarial risk: Mixed method usage enables fragmented API testing strategies

**Recommendation**: Align with existing POST-only pattern for consistency:
```
PUT /api/v1/hotels/bookings/{booking_id}/cancel → POST /api/v1/hotels/bookings/{booking_id}/cancel
DELETE /api/v1/cars/reservations/{id} → POST /api/v1/cars/reservations/{id}/cancel
```

Note: If the project wants to adopt RESTful HTTP methods system-wide, this requires:
1. Explicit documentation of the new standard
2. Migration plan for existing FlightBooker APIs
3. Rationale for the change (not just "new module preference")

---

#### 9. API Endpoint Verb Pattern Inconsistency
**Issue**: The car rental API mixes verb-in-path pattern with RESTful resource naming, creating inconsistent endpoint design.

**Pattern Evidence**:
- Existing system: "動詞を含むエンドポイント" (line 265) - `/api/v1/flights/book`, `/api/v1/bookings/cancel`
- New hotel API: `/api/v1/hotels/book`, `/api/v1/hotels/bookings/{booking_id}/cancel` - CONSISTENT
- New car API: `/api/v1/cars/reserve` (has verb) but `/api/v1/cars/reservations/{id}` (RESTful resource) - MIXED
- New review API: `/api/v1/reviews/create` - CONSISTENT (has verb)

**Impact Analysis**:
- Mixed patterns within the same API module (car rental) create confusion
- Prevents uniform API documentation structure
- Makes client SDK generation inconsistent (verb-based vs resource-based routing)
- Adversarial risk: Developers can choose pattern arbitrarily per endpoint

**Recommendation**: Standardize car rental API to verb-in-path pattern:
```
GET /api/v1/cars/search (already consistent)
POST /api/v1/cars/reserve → POST /api/v1/cars/reserve (keep)
GET /api/v1/cars/reservations/{id} → GET /api/v1/cars/reservation/{id} (remove plural resource naming)
POST /api/v1/cars/reservations/{id}/cancel (change from DELETE, add verb in path)
```

---

#### 10. Status Column Naming Inconsistency (Information Gap)
**Issue**: The design uses both `booking_status` (hotel_bookings) and `status` (car_rentals) without documented rationale or convention.

**Pattern Evidence**:
- hotel_bookings: `booking_status VARCHAR(20)`
- car_rentals: `status VARCHAR(20)`
- Existing system: No explicit status column convention documented

**Impact Analysis**:
- Creates inconsistent entity mapping (some entities have `bookingStatus`, others have `status`)
- Prevents uniform status query patterns (e.g., common status filtering utilities)
- Information gap: No documented convention to guide future tables
- Adversarial risk: Enables arbitrary status column naming per table

**Recommendation**:
1. **Document the status column naming convention**: Use simple `status` for all tables (more concise, context is clear from table name)
2. Rename `booking_status` to `status` in hotel_bookings table
3. Add to design document (new section or update section 4):
   > "Status Column Convention: All status-tracking columns should be named `status` (not prefixed with table/entity name). Context is provided by the table name."

---

### Significant Severity

#### 11. API Resource Naming Terminology Inconsistency
**Issue**: The design uses different terminology for semantically identical concepts: "bookings" (hotel) vs "reservations" (car).

**Pattern Evidence**:
- Hotel API: `/api/v1/hotels/bookings/{booking_id}`
- Car API: `/api/v1/cars/reservations/{id}`
- Both represent the same concept: a confirmed purchase/reservation

**Impact Analysis**:
- Creates confusion in API documentation and client code (why different terms?)
- Prevents uniform client-side abstractions (e.g., generic "Booking" interface)
- Makes API evolution inconsistent (should new services use "bookings", "reservations", or "orders"?)
- Adversarial risk: Enables terminology fragmentation across future modules

**Recommendation**: Standardize on single terminology:
- **Option A**: Use "bookings" for all (aligns with hotel_bookings table and existing flight_bookings)
- **Option B**: Use "reservations" for all

Recommended: **Option A (bookings)** to align with existing FlightBooker system's `flight_bookings` table.

```
/api/v1/cars/reservations → /api/v1/cars/bookings
car_rentals table → car_bookings table (if renaming tables is acceptable)
```

---

#### 12. Configuration File Format (Information Gap)
**Issue**: The design does not explicitly state configuration file format, while the existing system uses `application.properties`.

**Pattern Evidence**:
- Existing system: "設定ファイル: application.properties" (line 272)
- New design: No explicit statement (section 6 mentions deployment but not config format)

**Impact Analysis**:
- Information gap prevents verification of configuration consistency
- Developers might default to YAML (common Spring Boot choice) creating mixed formats
- Makes configuration management tooling inconsistent
- Adversarial risk: Enables "this module uses YAML" justifications

**Recommendation**: Add explicit statement to section 6 or section 2:
```
### Configuration Management
- Configuration file format: application.properties (align with existing FlightBooker)
- Environment-specific overrides: application-{profile}.properties
```

---

#### 13. Environment Variable Naming Convention (Information Gap)
**Issue**: No environment variables are documented, and no naming convention is stated.

**Pattern Evidence**:
- Existing system: "環境変数命名: 小文字スネークケース（例: `database_url`, `jwt_secret`）" (line 271)
- New design: No environment variables documented

**Impact Analysis**:
- Information gap prevents verification of environment variable consistency
- Developers might use uppercase or mixed case, creating inconsistent deployment configs
- Makes infrastructure-as-code templates inconsistent
- Adversarial risk: Enables arbitrary naming in deployment scripts

**Recommendation**: Add environment variable documentation to section 6 or section 2:
```
### Environment Variable Naming
- Convention: Lowercase snake_case (align with existing system)
- Examples: `database_url`, `jwt_secret`, `hotel_api_endpoint`, `payment_gateway_key`
- List of required variables:
  - database_url: PostgreSQL connection string
  - jwt_secret: JWT signing secret
  - hotel_inventory_api_url: External hotel system endpoint
  - car_rental_api_url: External car rental system endpoint
```

---

#### 14. Directory Structure and File Placement (Information Gap)
**Issue**: No directory structure or file placement rules are documented in the design.

**Pattern Evidence**:
- No section on project structure
- No guidance on package organization (domain-based vs layer-based)

**Impact Analysis**:
- Critical information gap for implementation phase
- Developers will make arbitrary placement decisions, creating inconsistent organization
- Prevents verification of architectural layer separation
- Adversarial risk: Enables scattered file placement that violates layer boundaries

**Recommendation**: Add new section (e.g., section 3.3) documenting directory structure:
```
### Directory Structure and File Placement

Package organization follows layer-based structure:

src/main/java/com/company/travelbooking/
├── controller/
│   ├── HotelBookingController.java
│   ├── CarRentalController.java
│   └── ReviewController.java
├── service/
│   ├── HotelBookingService.java
│   ├── CarRentalService.java
│   └── ReviewService.java
├── repository/
│   ├── HotelBookingRepository.java
│   ├── CarRentalRepository.java
│   └── ReviewRepository.java
├── entity/
│   ├── HotelBooking.java
│   ├── CarRental.java
│   └── UserReview.java
├── dto/
│   ├── request/
│   └── response/
├── exception/
│   └── GlobalExceptionHandler.java
└── config/
    └── SecurityConfig.java

File Placement Rules:
- Controllers in controller/ package
- Business logic in service/ package
- Data access in repository/ package
- JPA entities in entity/ package
- DTOs separated by request/response
- Exception handling in exception/ package
- Configuration classes in config/ package
```

---

### Moderate Severity

#### 15. Foreign Key Naming Convention Verification (Positive)
**Issue**: None - this is a positive consistency finding.

**Pattern Evidence**:
- Existing convention: `{参照先テーブル名単数形}_id` (line 262)
- All new tables: `user_id` - CONSISTENT

**Impact Analysis**: No negative impact. This demonstrates correct application of the existing convention.

**Recommendation**: No action needed. Document this as a positive example in the final design.

---

#### 16. JWT Token Storage Approach (Information Gap)
**Issue**: The design specifies localStorage for JWT tokens but does not verify consistency with existing system's auth approach.

**Pattern Evidence**:
- New design: "トークンはlocalStorageに保存" (line 181)
- Existing system: JWT authentication mentioned but storage location not stated in provided context

**Impact Analysis**:
- Potential inconsistency if existing system uses different storage (e.g., httpOnly cookies)
- Creates mixed authentication flows if storage differs
- Security implications vary (localStorage vs cookies vs sessionStorage)
- Information gap: No verification with existing system documented

**Recommendation**:
1. Verify existing FlightBooker system's JWT storage approach
2. If different, document rationale for divergence or align with existing approach
3. Add cross-reference in section 5.3:
   > "JWT Storage: Tokens stored in localStorage (consistent with existing FlightBooker system's approach)"

---

#### 17. Response Format vs Error Handling Cross-Reference (Gap)
**Issue**: API response format is documented, but no explicit connection to error handling pattern is stated.

**Pattern Evidence**:
- Section 5.3 documents `{"data": ..., "error": ...}` wrapper format
- Section 6.1 shows individual try-catch returning ApiResponse/ApiError
- No explicit statement that GlobalExceptionHandler should enforce this format

**Impact Analysis**:
- Implementation gap: Developers might not realize global handler should return this format
- Prevents verification that all error responses follow the documented structure
- Makes API contract enforcement implicit rather than explicit

**Recommendation**: Add cross-reference in section 6.1:
```
### Error Handling Integration
All exceptions handled by GlobalExceptionHandler must return responses matching the format documented in section 5.3:
- Success: {"data": {...}, "error": null}
- Error: {"data": null, "error": {"code": "...", "message": "..."}}
```

---

#### 18. Transaction Boundary Definition (Information Gap)
**Issue**: `@Transactional` usage is stated but transaction boundaries are not defined.

**Pattern Evidence**:
- Section 6.3 shows `@Transactional` on service methods
- No guidance on transaction scope for multi-table operations

**Impact Analysis**:
- Information gap: When should transactions span multiple service methods?
- Prevents verification of transaction isolation levels
- Makes rollback behavior unclear for complex operations
- Adversarial risk: Enables inconsistent transaction granularity across services

**Recommendation**: Add transaction boundary guidance to section 6.3:
```
### Transaction Boundaries
- Single-entity operations: @Transactional on service method
- Multi-entity operations: @Transactional on service method coordinating multiple repositories
- Read-only operations: @Transactional(readOnly = true)
- Isolation level: Default (READ_COMMITTED)
- Propagation: Default (REQUIRED)

Example: Booking creation spans hotel_bookings insert + payment record insert → single transaction
```

---

#### 19. Logging and Error Handling Integration (Information Gap)
**Issue**: Logging format and error handling are documented separately with no integration guidance.

**Pattern Evidence**:
- Section 6.1: Error handling pattern
- Section 6.2: Logging format
- No guidance on what to log in exception handlers

**Impact Analysis**:
- Information gap: Should exceptions be logged at controller, service, or global handler?
- Prevents verification of consistent exception logging
- Makes debugging inconsistent across modules

**Recommendation**: Add logging guidance to section 6.1 or 6.2:
```
### Exception Logging Policy
- Log exceptions at GlobalExceptionHandler level (avoid duplicate logging)
- Use ERROR level for 5xx errors, WARN level for 4xx client errors
- Include context: userId, requestId, operation name
- Example: logger.error("Booking creation failed", Map.of("userId", userId, "error", e.getMessage()));
```

---

#### 20. Database Migration Strategy (Information Gap)
**Issue**: No mention of schema versioning tool (Flyway/Liquibase) in the design.

**Pattern Evidence**:
- Section 4 documents table schemas
- No migration tool mentioned
- Existing system's migration approach not stated

**Impact Analysis**:
- Critical implementation gap for database change management
- Prevents verification of migration script organization
- Makes schema evolution strategy unclear
- Adversarial risk: Enables manual SQL execution, creating unversioned schema changes

**Recommendation**: Add database migration section (e.g., section 4.3):
```
### Database Migration Management
- Tool: Flyway (verify alignment with existing FlightBooker system)
- Migration scripts location: src/main/resources/db/migration/
- Naming convention: V{version}__{description}.sql (e.g., V001__create_hotel_bookings.sql)
- Rollback strategy: Not supported (forward-only migrations)
```

---

#### 21. API Versioning Policy (Information Gap)
**Issue**: All endpoints use `/api/v1/` prefix but versioning policy is not explicitly documented.

**Pattern Evidence**:
- All endpoints: `/api/v1/*` prefix
- Existing system: Same prefix (implicit from examples)
- No explicit versioning strategy documented

**Impact Analysis**:
- Information gap: When should version be incremented?
- Prevents verification of backward compatibility requirements
- Makes API evolution strategy unclear

**Recommendation**: Add API versioning section to section 5:
```
### API Versioning Policy
- Current version: v1
- Version increment triggers: Breaking changes to request/response format
- Backward compatibility: Maintain v1 for minimum 6 months after v2 release
- Version detection: Path-based (/api/v1/, /api/v2/)
```

---

#### 22. Authentication Middleware Implementation (Information Gap)
**Issue**: JWT authentication is stated but integration with controllers is not documented.

**Pattern Evidence**:
- Section 5.3: JWT authentication mentioned
- Section 2.4: Spring Security mentioned
- No implementation pattern for JWT validation in controller layer

**Impact Analysis**:
- Information gap: Should JWT validation use interceptors, filters, or annotations?
- Prevents verification of consistent auth enforcement
- Makes protected endpoint declaration unclear

**Recommendation**: Add authentication implementation section to section 6:
```
### Authentication Implementation
- JWT validation: Spring Security filter chain (JwtAuthenticationFilter)
- Protected endpoints: All endpoints except /api/v1/auth/login, /api/v1/auth/register
- Token extraction: Authorization header (Bearer {token})
- Token validation: JwtTokenProvider utility class
- User context: SecurityContextHolder.getContext().getAuthentication()
```

---

### Minor Severity

#### 23. ORM Mapping Fragmentation Risk (Latent)
**Issue**: Mixed column naming conventions require different ORM configuration strategies per entity.

**Pattern Evidence**:
- snake_case columns require default naming strategy or @Column annotations
- camelCase columns (car_rentals) require different naming strategy or explicit @Column mappings

**Impact Analysis**:
- Latent risk: Future developers might apply inconsistent naming strategies
- Makes entity configuration inconsistent across modules
- Prevents uniform repository testing patterns

**Recommendation**: After standardizing column naming to snake_case (see Critical Issue #1), configure uniform naming strategy:
```java
@Configuration
public class JpaConfig {
    @Bean
    public PhysicalNamingStrategy physicalNamingStrategy() {
        return new SnakeCasePhysicalNamingStrategy(); // Consistent for all entities
    }
}
```

---

#### 24. Repository and Entity Naming Consistency (Implicit)
**Issue**: Repository naming follows entity naming, but entity naming consistency depends on table naming fixes.

**Pattern Evidence**:
- HotelBookingRepository → hotel_bookings (consistent)
- CarRentalRepository → car_rentals (consistent)
- ReviewRepository → user_review (inconsistent due to singular table name)

**Impact Analysis**:
- After fixing table name inconsistencies, entity naming will follow naturally
- Minor risk: If table name is `user_reviews`, entity should be `UserReview` (singular entity, plural table)

**Recommendation**: After renaming tables (see Critical Issue #4), verify entity naming:
```
user_reviews table → UserReview entity → UserReviewRepository
```

---

## Pattern Evidence Summary

### Database Naming Patterns
| Pattern | Existing System | hotel_bookings | car_rentals | user_review | Consistency |
|---------|----------------|----------------|-------------|-------------|-------------|
| Table plurality | Plural (100%) | Plural ✓ | Plural ✓ | Singular ✗ | 75% |
| Column case | snake_case (100%) | snake_case ✓ | camelCase ✗ | snake_case ✓ | 67% |
| Primary key name | `id` (100%) | `booking_id` ✗ | `id` ✓ | `review_id` ✗ | 33% |
| Primary key type | BIGSERIAL (100%) | UUID ✗ | BIGSERIAL ✓ | UUID ✗ | 33% |
| Timestamp naming | `{verb}_at` (100%) | `{verb}` ✗ | `{verb}At` ✗ | `{verb}` ✗ | 0% |
| Foreign key naming | `{table}_id` (100%) | `user_id` ✓ | `user_id` ✓ | `user_id` ✓ | 100% |

### Implementation Pattern Adoption
| Pattern | Existing System | New Design | Consistency |
|---------|----------------|------------|-------------|
| Error handling | GlobalExceptionHandler | Individual try-catch | ✗ Inconsistent |
| HTTP client | WebClient | RestTemplate | ✗ Inconsistent |
| Logging format | JSON structured | Plain text | ✗ Inconsistent |
| Config file | application.properties | Not stated | ? Gap |
| Env var naming | lowercase_snake | Not stated | ? Gap |

### API Design Pattern Adoption
| Pattern | Existing System | Hotel API | Car API | Review API | Consistency |
|---------|----------------|-----------|---------|------------|-------------|
| HTTP methods | POST/GET only | PUT used ✗ | DELETE used ✗ | POST/GET ✓ | 33% |
| Verb in path | Yes (100%) | Yes ✓ | Mixed ✗ | Yes ✓ | 67% |
| Response wrapper | {"data","error"} | Same ✓ | Same ✓ | Same ✓ | 100% |

---

## Impact Analysis

### Cumulative Impact of Critical Issues

The combination of critical inconsistencies creates **systemic fragmentation risk**:

1. **Database Layer Fragmentation**: Mixed column naming + timestamp patterns + PK strategies prevent uniform repository and entity patterns
2. **HTTP Communication Fragmentation**: Mixed HTTP client libraries (RestTemplate vs WebClient) create blocking vs non-blocking architecture split
3. **Error Handling Fragmentation**: Scattered try-catch vs centralized handler enables inconsistent error responses across APIs
4. **Observability Fragmentation**: Mixed logging formats (JSON vs plain text) prevent unified monitoring and alerting
5. **API Client Fragmentation**: Mixed HTTP methods + verb patterns require clients to implement module-specific integration logic

### Adversarial Exploitation Scenarios

**Scenario 1: Database Naming Drift**
- Developer A: "hotel_bookings uses snake_case, so I'll use snake_case for tours_bookings"
- Developer B: "car_rentals uses camelCase, so I'll use camelCase for activity_reservations"
- Result: Codebase splits into two naming factions, preventing uniform ORM configuration

**Scenario 2: Error Handling Bypass**
- Developer: "The new modules use individual try-catch, so GlobalExceptionHandler doesn't apply to my feature"
- Result: Inconsistent error response formats, some endpoints return different error structures

**Scenario 3: Log Aggregation Failure**
- Operations team: "FlightBooker logs are JSON, new modules are plain text - we need two parsing pipelines"
- Result: Increased operational complexity, inconsistent alerting across modules

### Information Gap Exploitation

**Gap 1: Missing Directory Structure**
- Without documented file placement rules, developers create arbitrary package organization
- Result: Inconsistent navigation patterns, violated layer boundaries

**Gap 2: Missing Environment Variable Convention**
- Without naming standards, deployment scripts use mixed case (DATABASE_URL vs database_url)
- Result: Infrastructure-as-code templates become inconsistent, error-prone

**Gap 3: Missing Transaction Boundaries**
- Without transaction scope guidance, developers apply @Transactional inconsistently
- Result: Data integrity issues, unpredictable rollback behavior

---

## Recommendations

### Immediate Actions (Critical)

1. **Standardize Database Naming**: Apply existing FlightBooker conventions
   - All columns: snake_case
   - All timestamps: `created_at`, `updated_at`
   - All primary keys: `id BIGSERIAL` (or document UUID rationale)
   - All tables: plural naming

2. **Adopt Existing Implementation Patterns**: Align with FlightBooker
   - Error handling: Switch to GlobalExceptionHandler (@RestControllerAdvice)
   - HTTP client: Switch to WebClient
   - Logging: Switch to JSON structured logging
   - API methods: Use POST for all updates/cancellations (or plan system-wide RESTful migration)

3. **Document Missing Conventions**: Fill critical information gaps
   - Configuration file format: application.properties
   - Environment variable naming: lowercase_snake_case
   - Directory structure and file placement rules
   - Transaction boundary policies

### Documentation Enhancements (Significant)

4. **Add Cross-References**: Connect related patterns
   - Link error handling to API response format
   - Link logging policy to exception handling
   - Link transaction boundaries to data access patterns

5. **Add Versioning Policies**: Make implicit patterns explicit
   - API versioning strategy
   - Database migration tool and conventions
   - Dependency management standards

6. **Add Authentication Integration**: Document implementation details
   - JWT validation filter configuration
   - Protected endpoint declaration pattern
   - User context access pattern

### Validation Steps

7. **Review with Existing FlightBooker Team**: Verify assumptions
   - Confirm all extracted patterns from section 8 are accurate
   - Identify any unstated conventions that should apply
   - Validate recommended changes align with team practices

8. **Create Consistency Checklist**: For future modules
   - Database schema review checklist (naming, types, conventions)
   - API design review checklist (methods, paths, response formats)
   - Implementation review checklist (error handling, logging, HTTP clients)

---

## Conclusion

This design document requires **significant revisions** to achieve consistency with the existing FlightBooker system. The **10 critical issues** identified represent architectural decisions that, if left unaddressed, would create permanent technical debt and fragment the codebase into inconsistent subsystems.

**Priority recommendation**: Address all critical-severity issues before implementation begins. The combination of database naming inconsistencies (#1-4), implementation pattern divergence (#5-7), and API design conflicts (#8-9) would make future maintenance significantly more difficult and costly.

**Secondary recommendation**: Fill the identified information gaps (significant and moderate severity) to provide implementation teams with clear guidance and prevent ad-hoc decision-making that could introduce further inconsistencies.

With these revisions, the Travel Booking Platform can integrate seamlessly with FlightBooker and establish a consistent foundation for future modules.
