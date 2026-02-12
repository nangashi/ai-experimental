# Consistency Design Review Report
**Document**: Travel Booking Platform システム設計書
**Review Date**: 2026-02-12
**Reviewer**: Consistency Design Reviewer (Adversarial Mode)

---

## Executive Summary

This design document exhibits **critical inconsistencies** with the existing FlightBooker system across database schema, implementation patterns, and API design. The document demonstrates **systematic pattern fragmentation** that will create technical debt and maintenance burden. Most critically:

1. **Database schema uses THREE different naming conventions** across three tables (mixing singular/plural, snake_case/camelCase, created/created_at/createdAt)
2. **Implementation patterns reverse existing architectural decisions** (individual try-catch vs GlobalExceptionHandler, plain text logs vs JSON structured logs, RestTemplate vs WebClient)
3. **API design mixes HTTP methods and endpoint naming inconsistently** (POST/PUT/DELETE for cancel operations, mixed verb usage)

**Quantitative Evidence**:
- Existing system: 100% plural table names → Design introduces 33% singular (1 of 3 tables)
- Existing system: 100% snake_case columns → Design introduces 33% camelCase (1 of 3 tables)
- Existing system: 100% created_at/updated_at → Design introduces 0% compliance (0 of 3 tables)
- Existing system: 100% id BIGSERIAL primary keys → Design introduces 0% compliance (0 of 3 tables)

**Adversarial Assessment**: These inconsistencies enable developers to justify "local conventions" that fragment the codebase into incompatible subsystems requiring different tooling, ORM configurations, and maintenance procedures.

---

## Inconsistencies Identified

### CRITICAL Severity

#### C-1: Database Table Naming Inconsistency (Singular vs Plural)
**Issue**: `user_review` table uses SINGULAR form, violating existing 100% PLURAL convention.

**Pattern Evidence**:
- Existing system: `flight_bookings`, `passengers`, `airports` (100% plural, 3 of 3 tables documented)
- Design document: `hotel_bookings` (plural), `car_rentals` (plural), `user_review` (SINGULAR)
- Deviation rate: 33% (1 of 3 new tables)

**Impact Analysis**:
- **ORM Configuration Fragmentation**: Requires mixed naming strategies in JPA entity annotations (`@Table(name="user_review")` vs `@Table(name="hotel_bookings")`)
- **Query Pattern Confusion**: Developers must remember which tables are singular vs plural when writing raw SQL
- **Migration Script Inconsistency**: Database migration tools expecting plural forms will generate incorrect table names
- **Adversarial Exploitation**: Developers can cite this precedent to justify arbitrary singular/plural choices in future modules

**Recommendation**:
Rename `user_review` to `user_reviews` to maintain 100% plural table naming consistency.

---

#### C-2: Database Column Naming Case Inconsistency (snake_case vs camelCase)
**Issue**: `car_rentals` table uses camelCase column names (`userId`, `carId`, `pickupDate`, `returnDate`, `createdAt`, `modifiedAt`), violating existing 100% snake_case convention.

**Pattern Evidence**:
- Existing system: 100% snake_case columns (e.g., `user_id`, `flight_id`, `created_at`, `updated_at`)
- Design document:
  - `hotel_bookings`: snake_case (`user_id`, `hotel_id`, `created`, `updated`)
  - `car_rentals`: camelCase (`userId`, `carId`, `pickupDate`, `returnDate`, `createdAt`, `modifiedAt`)
  - `user_review`: snake_case (`user_id`, `booking_ref`, `created`, `updated`)
- Deviation rate: 33% (1 of 3 tables, affecting 9 of 27 total new columns)

**Impact Analysis**:
- **ORM Mapping Fragmentation**: Requires inconsistent `@Column(name="...")` annotation strategies across entities
- **SQL Query Maintenance Burden**: Forces developers to remember different column naming conventions per table
- **Database Tool Incompatibility**: PostgreSQL convention is snake_case; camelCase breaks standard introspection tools
- **Adversarial Exploitation**: Creates precedent for "per-module naming conventions" that fragment the schema

**Recommendation**:
Rename all `car_rentals` columns to snake_case:
- `userId` → `user_id`
- `carId` → `car_id`
- `pickupDate` → `pickup_date`
- `returnDate` → `return_date`
- `createdAt` → `created_at`
- `modifiedAt` → `updated_at`

---

#### C-3: Timestamp Column Naming Inconsistency (created_at vs created vs createdAt)
**Issue**: Design document introduces THREE different timestamp naming patterns, violating existing 100% `created_at`/`updated_at` convention.

**Pattern Evidence**:
- Existing system: 100% uses `created_at` and `updated_at` (explicit documentation in Section 8)
- Design document:
  - `hotel_bookings`: `created`, `updated` (abbreviated form)
  - `car_rentals`: `createdAt`, `modifiedAt` (camelCase)
  - `user_review`: `created`, `updated` (abbreviated form)
- Compliance rate: 0% (0 of 3 tables follow existing convention)

**Impact Analysis**:
- **Audit Trail Fragmentation**: Automated audit triggers expecting `created_at`/`updated_at` will fail on new tables
- **ORM Convention Breaking**: JPA `@CreatedDate`/`@LastModifiedDate` annotations expect consistent column names
- **Query Template Incompatibility**: Existing query templates using `created_at` cannot be reused for new tables
- **Monitoring Tool Failure**: Log aggregation and monitoring tools configured to track `created_at` will miss events from new tables
- **Adversarial Exploitation**: Three different timestamp patterns enable developers to claim "there is no standard"

**Recommendation**:
Standardize ALL tables to use `created_at` and `updated_at`:
- `hotel_bookings`: `created` → `created_at`, `updated` → `updated_at`
- `car_rentals`: `createdAt` → `created_at`, `modifiedAt` → `updated_at`
- `user_review`: `created` → `created_at`, `updated` → `updated_at`

---

#### C-4: Primary Key Naming and Type Inconsistency
**Issue**: Design document uses THREE different primary key patterns (UUID `booking_id`, BIGSERIAL `id`, UUID `review_id`), violating existing 100% `id BIGSERIAL` convention.

**Pattern Evidence**:
- Existing system: 100% uses `id BIGSERIAL PRIMARY KEY` (explicit documentation in Section 8)
- Design document:
  - `hotel_bookings`: `booking_id UUID PK` (different name AND type)
  - `car_rentals`: `id BIGSERIAL PK` (matches existing)
  - `user_review`: `review_id UUID PK` (different name AND type)
- Compliance rate: 33% (1 of 3 tables)

**Impact Analysis**:
- **ORM Configuration Fragmentation**: Requires different `@Id` and `@GeneratedValue` strategies per entity
- **Foreign Key Reference Complexity**: Foreign keys must reference different column names (`booking_id` vs `id` vs `review_id`)
- **URL Routing Inconsistency**: API endpoints use `/bookings/{booking_id}` vs `/reservations/{id}` vs `/reviews/{review_id}`
- **Database Sequence Management**: UUID-based tables don't use PostgreSQL sequences, breaking existing sequence monitoring tools
- **Adversarial Exploitation**: Mixed primary key patterns justify "entity-specific conventions" that prevent generic repository implementations

**Recommendation**:
Standardize ALL tables to use `id BIGSERIAL PRIMARY KEY`:
- `hotel_bookings`: `booking_id UUID` → `id BIGSERIAL`
- `car_rentals`: Keep `id BIGSERIAL` (already compliant)
- `user_review`: `review_id UUID` → `id BIGSERIAL`

Update API endpoints to consistently use `/{resource}/{id}` pattern.

---

#### C-5: Error Handling Pattern Reversal
**Issue**: Design document implements individual try-catch blocks in each Controller method (Section 6), contradicting existing GlobalExceptionHandler pattern.

**Pattern Evidence**:
- Existing system: Uses `@RestControllerAdvice` GlobalExceptionHandler for centralized error handling (documented in Section 8)
- Design document: Explicitly shows try-catch blocks in each Controller method (Section 6, code example provided)
- Pattern reversal: 100% architectural pattern inversion

**Impact Analysis**:
- **Error Handling Logic Fragmentation**: Error responses will be inconsistent across FlightBooker (centralized) and new modules (distributed)
- **Code Duplication**: Same error handling logic repeated in every Controller method
- **Maintenance Burden**: Error format changes require updating every Controller instead of one GlobalExceptionHandler
- **Testing Complexity**: Requires testing error handling in every Controller method instead of centralized handler tests
- **Adversarial Exploitation**: Developers can justify "I followed the design document" when creating inconsistent error responses

**Information Gap**: Design document provides NO justification for reversing this existing architectural pattern.

**Recommendation**:
Remove individual try-catch blocks and extend existing GlobalExceptionHandler to handle new module exceptions. Update Section 6 to state:
```
Error handling follows existing GlobalExceptionHandler pattern (@RestControllerAdvice).
Controllers throw domain exceptions (e.g., BookingNotFoundException, PaymentFailedException)
which are centrally handled and converted to standardized API error responses.
```

---

#### C-6: Logging Format Inconsistency
**Issue**: Design document uses plain text logging format, contradicting existing JSON structured logging.

**Pattern Evidence**:
- Existing system: JSON structured logging `{"timestamp": "...", "level": "INFO", "message": "..."}` (documented in Section 8)
- Design document: Plain text format `2024-03-15 10:30:45 INFO [HotelBookingService] Creating booking for user 12345` (Section 6)
- Format deviation: 100% incompatible format

**Impact Analysis**:
- **Log Aggregation Tool Incompatibility**: ElasticSearch/Splunk/CloudWatch Insights parsers configured for JSON will fail on plain text logs
- **Structured Query Impossibility**: Cannot query by structured fields (e.g., `user_id`, `booking_id`) in plain text logs
- **Monitoring Alert Fragmentation**: Existing alerting rules based on JSON field extraction will not work for new modules
- **Debugging Complexity**: Mixed log formats require different parsing strategies in log analysis tools
- **Adversarial Exploitation**: Plain text logs prevent automated security audit log analysis

**Information Gap**: No justification provided for deviating from existing JSON structured logging.

**Recommendation**:
Adopt existing JSON structured logging format. Update Section 6:
```
Logging follows existing JSON structured format using SLF4J + Logback with JSON encoder:
{
  "timestamp": "2024-03-15T10:30:45.123Z",
  "level": "INFO",
  "logger": "HotelBookingService",
  "message": "Creating booking for user",
  "user_id": 12345,
  "correlation_id": "abc-123"
}
```

---

### SIGNIFICANT Severity

#### S-1: HTTP Client Library Inconsistency
**Issue**: Design document uses `RestTemplate` (Section 2), contradicting existing `WebClient` usage.

**Pattern Evidence**:
- Existing system: Uses `WebClient` (Spring WebFlux) for HTTP communication (documented in Section 8)
- Design document: Lists `RestTemplate` in technology stack (Section 2)
- Library divergence: Different HTTP client libraries

**Impact Analysis**:
- **Dependency Bloat**: Project must include both Spring WebFlux (WebClient) and Spring Web (RestTemplate) dependencies
- **Testing Strategy Fragmentation**: Requires different mock/stub strategies (MockWebServer vs MockRestServiceServer)
- **Performance Characteristic Differences**: RestTemplate is blocking, WebClient is non-blocking (creates inconsistent latency profiles)
- **Maintenance Burden**: Developers must know two different HTTP client APIs
- **Adversarial Exploitation**: Mixed libraries justify "use whatever you're comfortable with" approach

**Information Gap**: No HTTP client selection criteria documented.

**Recommendation**:
Replace `RestTemplate` with `WebClient` for consistency. Update Section 2 to list `Spring WebFlux` and remove `RestTemplate`. Document HTTP client selection policy:
```
HTTP Client Standard: Use WebClient (Spring WebFlux) for all external HTTP communication
to maintain consistency with existing FlightBooker module.
```

---

#### S-2: API Endpoint HTTP Method Inconsistency
**Issue**: Cancellation operations use three different HTTP methods: PUT (hotel), DELETE (car), and POST (existing system).

**Pattern Evidence**:
- Existing system: `POST /api/v1/bookings/cancel` (uses POST for cancellation, documented in Section 8)
- Design document:
  - Hotel: `PUT /api/v1/hotels/bookings/{booking_id}/cancel` (uses PUT)
  - Car: `DELETE /api/v1/cars/reservations/{id}` (uses DELETE)
- HTTP method consistency: 0% (0 of 2 new endpoints follow existing pattern)

**Impact Analysis**:
- **Client Integration Complexity**: Frontend must implement three different cancellation patterns
- **API Gateway Configuration Fragmentation**: Different HTTP methods require different rate limiting and caching rules
- **CORS Policy Complexity**: Must allow PUT, DELETE, and POST methods instead of standardizing on POST
- **Developer Confusion**: No clear rule for when to use PUT vs DELETE vs POST for destructive operations
- **Adversarial Exploitation**: Inconsistent methods enable developers to choose "RESTful" patterns over existing conventions

**Recommendation**:
Standardize ALL cancellation operations to use POST (matching existing system):
- Change `PUT /api/v1/hotels/bookings/{booking_id}/cancel` → `POST /api/v1/hotels/bookings/{booking_id}/cancel`
- Change `DELETE /api/v1/cars/reservations/{id}` → `POST /api/v1/cars/reservations/{id}/cancel`

Document HTTP method selection policy:
```
HTTP Method Standard: Follow existing FlightBooker conventions:
- GET for retrieval operations
- POST for creation, updates, and destructive operations (including cancel)
- Rationale: Simplified client integration and CORS configuration
```

---

#### S-3: API Endpoint Verb Inconsistency
**Issue**: Booking/reservation creation endpoints use three different verbs: `/book`, `/reserve`, `/create`.

**Pattern Evidence**:
- Existing system: `/api/v1/flights/book` (uses "book" verb, documented in Section 8)
- Design document:
  - Hotel: `POST /api/v1/hotels/book` (uses "book" - matches existing)
  - Car: `POST /api/v1/cars/reserve` (uses "reserve" - deviates)
  - Review: `POST /api/v1/reviews/create` (uses "create" - deviates)
- Verb consistency: 33% (1 of 3 endpoints follows existing pattern)

**Impact Analysis**:
- **API Consistency Confusion**: Developers must remember different verbs for similar operations
- **Client Code Fragmentation**: Frontend must use different endpoint patterns for conceptually identical "create booking" operations
- **API Documentation Complexity**: Cannot use generic templates like "POST /{resource}/book"
- **Adversarial Exploitation**: Mixed verbs enable arbitrary endpoint naming in future modules

**Recommendation**:
Standardize ALL booking creation endpoints to use `/book`:
- Keep `POST /api/v1/hotels/book` (already compliant)
- Change `POST /api/v1/cars/reserve` → `POST /api/v1/cars/book`
- Change `POST /api/v1/reviews/create` → `POST /api/v1/reviews` (RESTful resource creation) OR `POST /api/v1/reviews/submit`

Document endpoint verb policy:
```
API Endpoint Naming: Use /book for all booking/reservation creation operations.
For non-booking resources, use RESTful conventions (POST /{resource} for creation).
```

---

#### S-4: API Search Operation HTTP Method Inconsistency
**Issue**: Search operations use inconsistent HTTP methods: POST (hotels) vs GET (cars).

**Pattern Evidence**:
- Design document:
  - Hotel: `POST /api/v1/hotels/search` (uses POST)
  - Car: `GET /api/v1/cars/search` (uses GET)
- Existing system: Implies POST for search operations (Section 8 states "mainly POST and GET, updates also POST")

**Impact Analysis**:
- **Client Code Confusion**: Developers must remember which search endpoints use GET vs POST
- **Caching Strategy Inconsistency**: GET requests are cacheable, POST requests are not (performance implications)
- **API Gateway Behavior**: GET requests may be cached by proxies, POST requests will not be (inconsistent performance)
- **Search Parameter Complexity**: POST allows complex search criteria in body, GET requires query parameters (different client implementation patterns)

**Recommendation**:
Standardize search operations to use POST (supports complex search criteria):
- Keep `POST /api/v1/hotels/search` (already using POST)
- Change `GET /api/v1/cars/search` → `POST /api/v1/cars/search`

Document search operation policy:
```
API Search Operations: Use POST for all search endpoints to support complex search criteria
in request body and maintain consistency across all modules.
```

---

#### S-5: API Resource Naming Inconsistency (bookings vs reservations)
**Issue**: Similar concepts use different resource names: `/bookings` (hotel) vs `/reservations` (car).

**Pattern Evidence**:
- Design document:
  - Hotel: `/api/v1/hotels/bookings/{booking_id}`
  - Car: `/api/v1/cars/reservations/{id}`
- Existing system: `/api/v1/bookings/cancel` (uses "bookings")
- Terminology consistency: 50% (hotel matches existing, car deviates)

**Impact Analysis**:
- **Terminology Confusion**: "Booking" vs "Reservation" are synonyms, using both creates unnecessary cognitive overhead
- **Client Code Pattern Duplication**: Frontend must handle both `/bookings` and `/reservations` resource patterns
- **API Documentation Complexity**: Cannot use generic terminology in API guides
- **Adversarial Exploitation**: Allows arbitrary resource naming for similar concepts in future modules

**Recommendation**:
Standardize ALL booking-related resources to use `/bookings`:
- Keep `POST /api/v1/hotels/bookings` (already uses "bookings")
- Change `/api/v1/cars/reservations` → `/api/v1/cars/bookings`

Document resource naming policy:
```
API Resource Naming: Use "bookings" for all booking/reservation resources to maintain
consistent terminology across flight, hotel, and car rental modules.
```

---

### MODERATE Severity

#### M-1: Configuration Management Documentation Gap
**Issue**: Design document does not specify configuration file format or environment variable naming convention.

**Pattern Evidence**:
- Existing system: Uses `application.properties` (Section 8) and lowercase snake_case environment variables (`database_url`, `jwt_secret`)
- Design document: No configuration management section, no environment variable examples

**Information Gap Impact**:
- **Configuration Format Fragmentation**: Developers might use application.yml or application.properties arbitrarily
- **Environment Variable Inconsistency**: Without documented naming convention, developers might use UPPER_CASE, camelCase, or snake_case
- **Deployment Script Complexity**: Mixed environment variable naming requires custom parsing per module
- **Adversarial Exploitation**: Absence of documentation allows "I didn't know there was a standard" justification

**Recommendation**:
Add Configuration Management section to design document:
```
## Configuration Management

### Configuration Files
- Use application.properties format (matching existing FlightBooker module)
- Profile-specific configs: application-{profile}.properties (e.g., application-prod.properties)

### Environment Variable Naming
- Use lowercase snake_case (e.g., database_url, jwt_secret, hotel_api_key)
- Prefix module-specific variables with module name (e.g., hotel_booking_timeout)
- Follow existing FlightBooker environment variable naming conventions
```

---

#### M-2: File Placement Policy Documentation Gap
**Issue**: Design document does not specify directory structure or file organization conventions.

**Information Gap Impact**:
- **Package Structure Inconsistency**: Without documented conventions, developers might organize by layer (controller/service/repository) or by feature (hotel/car/review)
- **Integration Complexity**: Unclear where shared components (e.g., common error handling, authentication filters) should be placed
- **Adversarial Exploitation**: Allows arbitrary package organization that fragments code discoverability

**Recommendation**:
Add File Organization section to design document:
```
## File Organization

### Package Structure
Follow feature-based organization (aligned with existing FlightBooker structure):
- com.example.booking.hotel.controller
- com.example.booking.hotel.service
- com.example.booking.hotel.repository
- com.example.booking.hotel.entity
- com.example.booking.car.controller
- com.example.booking.car.service
- ...

### Shared Components
- Common error handlers: com.example.booking.common.exception
- Security filters: com.example.booking.common.security
- Shared DTOs: com.example.booking.common.dto
```

---

#### M-3: Transaction Boundary Documentation Gap
**Issue**: Design document states "@Transactional at Service method level" but does not specify transaction boundaries for multi-table operations.

**Information Gap Impact**:
- **Data Consistency Risk**: Unclear whether booking creation + payment processing + notification are in same transaction
- **Rollback Policy Ambiguity**: When external API calls fail (e.g., HotelInventoryAPI), unclear if database changes should rollback
- **Performance Impact**: Overly broad transactions can cause lock contention, unclear where to split transactions
- **Adversarial Exploitation**: Ambiguous boundaries allow developers to create inconsistent transaction scopes

**Recommendation**:
Add Transaction Management section to design document:
```
## Transaction Management

### Transaction Boundaries
- Each public Service method is a transaction boundary (@Transactional)
- External API calls (HotelInventoryAPI, PaymentGateway) are OUTSIDE transaction scope
- Pattern:
  1. Validate input (no transaction)
  2. Call external API (no transaction)
  3. Persist booking (@Transactional)

### Rollback Policy
- RuntimeException triggers automatic rollback
- External API failures do NOT rollback database changes (use compensating transactions)
- Use @Transactional(rollbackFor = Exception.class) for checked exceptions
```

---

#### M-4: JWT Token Storage Location Inconsistency Risk
**Issue**: Design document specifies JWT token storage in `localStorage` (Section 5), but existing FlightBooker token storage location is not documented for verification.

**Information Gap Impact**:
- **Authentication State Fragmentation**: If FlightBooker uses different token storage (e.g., httpOnly cookie), users cannot maintain authentication across modules
- **Security Posture Inconsistency**: localStorage is vulnerable to XSS attacks; if existing system uses httpOnly cookies, new modules reduce security
- **Single Sign-On Complexity**: Different token storage mechanisms prevent shared authentication state

**Recommendation**:
Verify existing FlightBooker token storage mechanism and align design document. If existing uses httpOnly cookies, update Section 5:
```
### Authentication
- JWT authentication using Bearer Token
- Token storage: httpOnly secure cookie (matching FlightBooker authentication)
- Token validity: 24 hours
- CSRF protection: Required for cookie-based authentication
```

If localStorage is confirmed to be existing pattern, document rationale for XSS risk acceptance.

---

### MINOR Severity (Positive Alignments)

#### P-1: API Response Format Consistency
**Positive Finding**: Design document correctly adopts existing API response format `{ "data": ..., "error": ... }`.

**Evidence**:
- Existing system: Uses `{ "data": ..., "error": ... }` response wrapper (Section 8)
- Design document: Section 5 explicitly documents same response format with examples
- Alignment: 100%

**Recommendation**: No change required. This is correct alignment with existing patterns.

---

#### P-2: Technology Stack Alignment
**Positive Finding**: Core technology choices align with existing system (Java, Spring Boot, PostgreSQL).

**Evidence**:
- Existing system: Java, Spring Boot, PostgreSQL (implied in Section 8)
- Design document: Java 17, Spring Boot 3.2, PostgreSQL 15 (Section 2)
- Alignment: Framework consistency maintained

**Recommendation**: No change required. Technology stack alignment is appropriate.

---

#### P-3: Three-Layer Architecture Consistency
**Positive Finding**: Design document adopts standard three-layer architecture (Presentation → Service → Repository).

**Evidence**:
- Design document: Explicitly documents three-layer architecture in Section 3
- Standard pattern: Matches common Spring Boot application structure
- Alignment: Architectural pattern is sound

**Note**: While this is positive, the IMPLEMENTATION of cross-cutting concerns (error handling, logging) within this architecture deviates from existing patterns (see C-5, C-6).

**Recommendation**: Maintain three-layer architecture but fix cross-cutting concern implementations to match existing patterns.

---

## Summary of Recommendations

### Immediate Action Required (Critical Issues)

1. **Standardize Database Naming Conventions** (addresses C-1, C-2, C-3, C-4):
   - Rename `user_review` → `user_reviews`
   - Convert `car_rentals` columns to snake_case
   - Standardize ALL timestamp columns to `created_at`/`updated_at`
   - Standardize ALL primary keys to `id BIGSERIAL`

2. **Restore Architectural Pattern Consistency** (addresses C-5, C-6, S-1):
   - Remove individual try-catch blocks, use GlobalExceptionHandler
   - Adopt JSON structured logging format
   - Replace RestTemplate with WebClient

3. **Standardize API Design** (addresses S-2, S-3, S-4, S-5):
   - Use POST for all cancellation operations
   - Use `/book` verb for all booking creation
   - Use POST for all search operations
   - Use `/bookings` resource name consistently

### Documentation Enhancements Required (Moderate Issues)

4. **Add Missing Policy Documentation** (addresses M-1, M-2, M-3, M-4):
   - Document configuration file format and environment variable naming
   - Document package structure and file organization rules
   - Document transaction boundaries and rollback policies
   - Verify and document JWT token storage consistency

---

## Pattern Evidence Summary

### Database Schema Patterns (Existing System)
- Table naming: 100% plural (flight_bookings, passengers, airports)
- Column naming: 100% snake_case
- Primary keys: 100% `id BIGSERIAL`
- Foreign keys: 100% `{table_singular}_id` format
- Timestamps: 100% `created_at`, `updated_at`

### API Patterns (Existing System)
- Endpoint verbs: Uses `/book`, `/cancel`
- HTTP methods: Primarily POST and GET
- Response format: `{ "data": ..., "error": ... }`

### Implementation Patterns (Existing System)
- Error handling: GlobalExceptionHandler (@RestControllerAdvice)
- Logging: JSON structured format
- HTTP client: WebClient (Spring WebFlux)
- Configuration: application.properties
- Environment variables: lowercase snake_case

---

## Adversarial Risk Assessment

**High-Risk Fragmentation Vectors**:
1. **Database schema fragmentation**: Three different naming conventions enable "per-table standards"
2. **Error handling fragmentation**: Reversal of centralized pattern enables distributed error logic
3. **Logging format fragmentation**: Mixed formats prevent unified log analysis
4. **API method fragmentation**: Inconsistent HTTP methods enable arbitrary client integration patterns

**Exploitation Scenarios**:
- Developer justifies camelCase columns in new table by citing `car_rentals` precedent
- Developer skips GlobalExceptionHandler by citing "design document shows try-catch example"
- Developer uses plain text logging by citing Section 6 example
- Developer chooses PUT method by citing hotel cancellation precedent

**Mitigation**: Address all Critical and Significant severity issues before implementation begins to prevent these patterns from becoming "established precedents."

---

## Conclusion

This design document requires **substantial revision** to align with existing FlightBooker system patterns. The current design would introduce **systematic fragmentation** across database schema, implementation patterns, and API design.

**Compliance Metrics**:
- Database naming: 25% compliant (estimated across all naming dimensions)
- Implementation patterns: 0% compliant (all patterns deviate)
- API design: 40% compliant (4 of 10 aspects aligned)

**Recommended Next Steps**:
1. Revise design document to address all Critical severity issues (C-1 through C-6)
2. Update API design to address Significant severity issues (S-1 through S-5)
3. Add missing documentation sections (M-1 through M-4)
4. Conduct second consistency review after revisions
5. Implement with strict adherence to revised patterns
