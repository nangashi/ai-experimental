# Structural Quality Review: RealEstateHub System Design

## Critical Issues

### C-1: Severe Single Responsibility Principle Violation in PropertyManagementService

**Issue**: The `PropertyManagementService` violates the Single Responsibility Principle by consolidating multiple unrelated responsibilities into a single class:
- Property CRUD operations
- Customer matching logic
- Appointment availability calculation
- Contract status management
- Statistics aggregation
- Cache management
- Elasticsearch indexing

**Impact**: This creates a highly coupled, unmaintainable "God Object" that:
- Makes testing extremely difficult due to excessive dependencies (6 injected repositories/templates)
- Forces changes in unrelated features to touch the same service class, increasing merge conflicts
- Prevents independent deployment of feature changes
- Violates the Open-Closed Principle as every new feature requires modifying this class

**Recommendation**: Decompose into focused services following SRP:
```java
@Service
public class PropertyService {
    // Only property CRUD operations
}

@Service
public class PropertyMatchingService {
    // Customer matching logic only
    @Autowired PropertyService propertyService;
    @Autowired CustomerService customerService;
}

@Service
public class ContractManagementService {
    // Contract lifecycle management
}

@Service
public class PropertyStatisticsService {
    // Statistics aggregation
}
```

**Reference**: Section 3.2 - PropertyManagementService code example

---

### C-2: Data Model Design Violates Normalization and Creates Redundancy Risks

**Issue**: Critical data model design flaws:
1. `properties` table embeds owner information (owner_name, owner_phone) directly instead of referencing a separate Owner entity
2. `customers` table embeds preference criteria directly instead of using a separate PreferenceProfile entity
3. No foreign key constraints defined, delegating referential integrity to application code

**Impact**:
- **Data redundancy**: Multiple properties with the same owner duplicate owner information, risking inconsistency when owner details change
- **Update anomalies**: Changing an owner's phone number requires updating multiple property records
- **Referential integrity risk**: Without FK constraints, orphaned records (appointments referencing deleted properties) can occur silently
- **Query performance**: Searching properties by owner requires string matching instead of indexed foreign key lookups

**Recommendation**: Normalize the data model:
```sql
CREATE TABLE owners (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255)
);

CREATE TABLE properties (
    id BIGSERIAL PRIMARY KEY,
    -- ... other fields ...
    owner_id BIGINT NOT NULL,
    FOREIGN KEY (owner_id) REFERENCES owners(id)
);

CREATE TABLE customer_preferences (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    preferred_area VARCHAR(500),
    max_price DECIMAL(15, 2),
    min_area DECIMAL(10, 2),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);
```

Add database-level foreign key constraints for data integrity. If application-level control is needed, implement this through database triggers or transaction management, not by omitting constraints entirely.

**Reference**: Section 4.1 (Property, Customer entities) and Section 4.2 (注意事項)

---

### C-3: No API Versioning Strategy Defined

**Issue**: The API design lacks any versioning strategy. All endpoints are defined without version identifiers (e.g., `/properties/create` instead of `/v1/properties`).

**Impact**:
- **Breaking changes**: Any modification to request/response formats will break existing clients
- **Zero backward compatibility**: No path for incremental migration when API changes are needed
- **Deployment coupling**: Frontend and backend must be deployed simultaneously, preventing independent release cycles
- **Technical debt accumulation**: Pressure to maintain backward compatibility through workarounds instead of proper versioning

**Recommendation**: Implement URL-based versioning immediately:
```
POST /v1/properties
PUT /v1/properties/{id}
GET /v1/properties/{id}
```

Define the versioning policy:
- Major version changes (v1 → v2) for breaking changes
- Maintain support for N-1 version for 6 months during transitions
- Document deprecation timelines in API responses via headers
- Use content negotiation (Accept header) for future flexibility

**Reference**: Section 5.1 (API endpoint list) and Section 5.2 (request/response format)

---

### C-4: Hardcoded Configuration in NotificationService Prevents Testability and Environment Management

**Issue**: The `NotificationService` has hardcoded credentials and endpoints:
```java
private final String smtpHost = "smtp.example.com";
private final String smsApiKey = "sk_live_12345";
```

**Impact**:
- **Impossible to test**: Unit tests will attempt real SMTP connections and SMS API calls
- **Security risk**: Live API keys embedded in source code
- **Environment inflexibility**: Cannot use different SMTP servers or SMS providers for dev/staging/production
- **Violates Dependency Inversion Principle**: Service depends on concrete implementations rather than abstractions

**Recommendation**: Implement proper dependency injection and abstraction:
```java
public interface NotificationChannel {
    void send(NotificationMessage message);
}

@Service
public class EmailNotificationChannel implements NotificationChannel {
    @Value("${smtp.host}")
    private String smtpHost;

    @Value("${smtp.username}")
    private String username;

    // Implementation
}

@Service
public class NotificationService {
    private final Map<NotificationType, NotificationChannel> channels;

    @Autowired
    public NotificationService(List<NotificationChannel> channels) {
        // Inject all available channels
    }
}
```

Configuration externalization:
- Use Spring's `@Value` or `@ConfigurationProperties` for externalized config
- Store credentials in AWS Secrets Manager or Parameter Store
- Inject mock implementations in tests via Spring profiles or test configuration

**Reference**: Section 3.2 - NotificationService code example

---

## Significant Issues

### S-1: Missing Domain Model Layer - DTOs Used as Domain Objects

**Issue**: The design shows direct DTO usage throughout the service layer without a separate domain model layer. Services operate on `PropertyDTO`, `CustomerDTO` directly.

**Impact**:
- **Leaking implementation details**: DTOs designed for API contracts influence business logic
- **Change amplification**: API format changes force business logic changes
- **Testability reduction**: Tests depend on API-specific data structures
- **Domain logic dispersion**: Business rules scattered across services without rich domain objects to encapsulate them

**Recommendation**: Introduce a clean domain layer following Domain-Driven Design:
```
Controller Layer → DTO
    ↓ (mapping)
Service Layer → Domain Model (Property, Customer entities)
    ↓ (persistence)
Repository Layer → JPA Entities
```

Example:
```java
// Domain model with behavior
public class Property {
    private PropertyId id;
    private Price price;
    private Area area;
    private PropertyStatus status;

    public boolean isAvailableForViewing(LocalDateTime requestedTime) {
        // Business logic encapsulated in domain model
    }

    public MatchScore calculateMatchScore(CustomerPreferences prefs) {
        // Domain logic here
    }
}

// Service uses domain models
@Service
public class PropertyService {
    public Property findProperty(PropertyId id) {
        // Returns domain model, not DTO
    }
}
```

**Reference**: Section 3.3 (data flow) mentions DTO conversion but no domain layer

---

### S-2: No Error Classification or Recovery Strategy Defined

**Issue**: The error handling design (Section 6.1) only defines a generic `GlobalExceptionHandler` that maps exceptions to HTTP status codes (400, 404, 500) without:
- Application-specific error taxonomy
- Distinction between retryable and non-retryable errors
- Error code system for client-side handling
- Recovery strategies for different failure scenarios

**Impact**:
- **Poor client experience**: Clients receive generic error messages without actionable guidance
- **No automated recovery**: Cannot implement retry logic without distinguishing transient from permanent failures
- **Debugging difficulty**: No structured error codes to track specific failure patterns
- **Inconsistent handling**: Different developers will classify errors differently without guidance

**Recommendation**: Design a comprehensive error classification system:

```java
public abstract class ApplicationException extends RuntimeException {
    private final ErrorCode errorCode;
    private final boolean retryable;

    // Constructor
}

public enum ErrorCode {
    // Domain errors (non-retryable)
    PROPERTY_NOT_FOUND("PROP_001", false),
    INVALID_PRICE_RANGE("PROP_002", false),
    DUPLICATE_PROPERTY("PROP_003", false),

    // Infrastructure errors (retryable)
    DATABASE_TIMEOUT("INFRA_001", true),
    CACHE_UNAVAILABLE("INFRA_002", true),
    EXTERNAL_API_FAILURE("INFRA_003", true);

    private final String code;
    private final boolean retryable;
}

// Error response format
{
    "errorCode": "PROP_001",
    "message": "Property not found",
    "retryable": false,
    "timestamp": "2026-02-11T10:00:00Z",
    "requestId": "req-12345"
}
```

Define recovery strategies:
- Retryable errors: Client should retry with exponential backoff
- Validation errors: Client should correct input
- Not found errors: Client should handle gracefully (show user-friendly message)

**Reference**: Section 6.1 - エラーハンドリング方針

---

### S-3: Circular Dependency Risk Between PropertyManagementService and Customer Matching

**Issue**: The `PropertyManagementService.matchCustomers()` method implements customer matching logic while depending on `CustomerRepository`. This creates potential for circular dependencies when customer-side matching features are added (e.g., "find matching properties for this customer").

**Impact**:
- **Prevents bidirectional matching**: Cannot implement "customer → property" matching without creating circular dependencies
- **Blocks incremental deployment**: Matching logic changes require coordinated deployment of property and customer services
- **Testing complexity**: Must mock customer-related dependencies even for simple property tests

**Recommendation**: Extract matching logic into a separate, dependency-free service:

```java
@Service
public class MatchingService {
    @Autowired
    private PropertyRepository propertyRepository;
    @Autowired
    private CustomerRepository customerRepository;
    @Autowired
    private MatchingAlgorithm matchingAlgorithm; // injected strategy

    public List<MatchResult> findMatchingCustomers(PropertyId propertyId) {
        Property property = propertyRepository.findById(propertyId);
        List<Customer> customers = customerRepository.findActive();
        return matchingAlgorithm.match(property, customers);
    }

    public List<MatchResult> findMatchingProperties(CustomerId customerId) {
        // Symmetric implementation
    }
}

// PropertyManagementService no longer knows about matching
@Service
public class PropertyService {
    // Only property CRUD, no matching logic
}
```

This also enables Strategy pattern for different matching algorithms (AI-based, rule-based, etc.).

**Reference**: Section 3.2 - PropertyManagementService.matchCustomers() method

---

### S-4: No Strategy for Schema Evolution or Data Migration

**Issue**: The database schema design (Section 4) defines initial table structures but provides no guidance on:
- How schema changes will be managed over time
- Migration strategy for adding/removing columns
- Handling backward compatibility during rolling deployments
- Data type changes or constraint additions

**Impact**:
- **Deployment risk**: Schema changes require careful coordination with code deployments
- **Downtime potential**: Incompatible schema changes force downtime during deployments
- **Data loss risk**: No rollback strategy if migrations fail
- **Technical debt**: Pressure to avoid schema changes leads to workarounds in application code

**Recommendation**: Define a schema evolution strategy:

1. **Migration tool**: Use Flyway or Liquibase for versioned migrations
   ```sql
   -- V001__initial_schema.sql
   CREATE TABLE properties (...);

   -- V002__add_property_owner_table.sql
   CREATE TABLE owners (...);
   ALTER TABLE properties ADD COLUMN owner_id BIGINT;
   -- Data migration steps
   ```

2. **Backward-compatible changes only**:
   - New columns must be nullable or have defaults
   - No column removal in same release (deprecate → remove in next major version)
   - Additive changes only (new tables, new columns)

3. **Blue-green deployment compatibility**:
   - Schema changes deployed before code changes
   - Both old and new code versions work with new schema during transition
   - Remove deprecated columns only after all instances use new code

4. **Rollback capability**:
   - Every migration has a corresponding rollback script
   - Test rollback procedures in staging environment

**Reference**: Section 4 (data model) and Section 6.4 (deployment strategy mentions Blue-Green but no schema coordination)

---

## Moderate Issues

### M-1: Missing Dependency Injection Configuration for Testability

**Issue**: The design shows `@Autowired` field injection throughout services but doesn't define:
- How test doubles will be injected
- Configuration for different test contexts (unit vs integration)
- Strategy for mocking external dependencies (Elasticsearch, Redis)

**Impact**:
- **Test setup complexity**: Each test must manually configure all dependencies
- **Brittle tests**: Tests break when new dependencies are added to services
- **Slow test execution**: No guidance on using lightweight test doubles vs. real dependencies

**Recommendation**:
1. **Use constructor injection** (enables immutable dependencies and easier testing):
   ```java
   @Service
   public class PropertyService {
       private final PropertyRepository repository;
       private final CacheService cacheService;

       @Autowired
       public PropertyService(PropertyRepository repository,
                              CacheService cacheService) {
           this.repository = repository;
           this.cacheService = cacheService;
       }
   }
   ```

2. **Define test configuration profiles**:
   ```java
   @Configuration
   @Profile("test")
   public class TestConfiguration {
       @Bean
       public CacheService mockCacheService() {
           return Mockito.mock(CacheService.class);
       }
   }
   ```

3. **Abstract external dependencies**:
   ```java
   public interface SearchIndex {
       void index(Property property);
       List<Property> search(SearchCriteria criteria);
   }

   @Service
   public class ElasticsearchSearchIndex implements SearchIndex {
       // Real implementation
   }

   // In tests
   public class InMemorySearchIndex implements SearchIndex {
       // Fast, in-memory test double
   }
   ```

**Reference**: Section 3.2 (service examples with @Autowired), Section 6.3 (test strategy)

---

### M-2: No Configuration Management Strategy for Multiple Environments

**Issue**: The design mentions deploying to staging and production environments (Section 6.4) but doesn't define:
- How configuration differs between environments
- Where environment-specific settings are stored
- How to prevent production credentials from leaking into lower environments

**Impact**:
- **Security risk**: Developers may accidentally use production credentials in development
- **Configuration drift**: Manual configuration updates lead to inconsistencies between environments
- **Difficult troubleshooting**: Cannot reproduce production issues in staging if configs differ unexpectedly

**Recommendation**: Define a configuration management strategy:

1. **Externalized configuration hierarchy**:
   ```
   application.yml (common defaults)
   application-dev.yml (development overrides)
   application-staging.yml (staging overrides)
   application-prod.yml (production overrides)
   ```

2. **Secrets management**:
   - Use AWS Systems Manager Parameter Store or Secrets Manager
   - Inject secrets at runtime via environment variables
   - Never commit credentials to version control

3. **Configuration validation**:
   ```java
   @Configuration
   @ConfigurationProperties(prefix = "app")
   @Validated
   public class AppConfig {
       @NotNull
       private String smtpHost;

       @Pattern(regexp = "^sk_(live|test)_.*")
       private String smsApiKey;
   }
   ```

4. **Environment parity**: Document which settings must be identical across environments (e.g., JWT algorithm, password hashing) vs. environment-specific (e.g., database URLs)

**Reference**: Section 6.2 (mentions environment-specific log levels), Section 6.4 (deployment environments)

---

### M-3: API Design Lacks Consistency in HTTP Verb Usage

**Issue**: The API endpoints (Section 5.1) use inconsistent HTTP verb patterns:
- `POST /properties/create` - verb in URL path
- `PUT /properties/update/{id}` - verb in URL path
- `DELETE /properties/delete/{id}` - verb in URL path
- `POST /properties/{id}/match-customers` - action-based endpoint

This violates RESTful principles where HTTP verbs should indicate operations, not URL paths.

**Impact**:
- **Developer confusion**: Inconsistent patterns increase cognitive load
- **Client library complexity**: Code generation tools expect standard REST patterns
- **Poor discoverability**: Non-standard endpoints harder to understand without documentation

**Recommendation**: Follow RESTful conventions consistently:

```
Current                          → Recommended
POST /properties/create          → POST /v1/properties
PUT /properties/update/{id}      → PUT /v1/properties/{id}
DELETE /properties/delete/{id}   → DELETE /v1/properties/{id}
GET /properties/search?query=... → GET /v1/properties?q=...

// For non-CRUD actions, use POST with clear action names
POST /properties/{id}/match-customers → POST /v1/properties/{id}/matches
```

Document when action-based endpoints are appropriate (e.g., operations that don't fit CRUD model, like `POST /contracts/{id}/cancel`).

**Reference**: Section 5.1 - エンドポイント一覧

---

### M-4: Missing Logging Design for Distributed Tracing

**Issue**: Section 6.2 defines basic logging (Logback, log levels) but doesn't address:
- How to trace requests across multiple services/components
- Context propagation (user ID, request ID, session ID)
- Structured logging format for machine parsing
- Integration with monitoring tools (mentioned Datadog but no logging integration design)

**Impact**:
- **Difficult debugging**: Cannot trace a single user request through the system
- **Poor observability**: Logs lack context for correlating related events
- **Manual log analysis**: Unstructured logs require manual parsing
- **Incomplete monitoring**: Datadog mentioned but no integration design

**Recommendation**: Design comprehensive logging and tracing:

1. **Request ID propagation**:
   ```java
   @Component
   public class RequestIdFilter extends OncePerRequestFilter {
       @Override
       protected void doFilterInternal(HttpServletRequest request, ...) {
           String requestId = UUID.randomUUID().toString();
           MDC.put("requestId", requestId);
           MDC.put("userId", getCurrentUserId());
           // Continue filter chain
       }
   }
   ```

2. **Structured logging**:
   ```java
   log.info("Property created",
       kv("propertyId", property.getId()),
       kv("brokerId", property.getBrokerId()),
       kv("action", "CREATE_PROPERTY"));
   ```

   Output JSON format:
   ```json
   {
       "timestamp": "2026-02-11T10:00:00Z",
       "level": "INFO",
       "requestId": "req-12345",
       "userId": "broker-123",
       "message": "Property created",
       "propertyId": 456,
       "action": "CREATE_PROPERTY"
   }
   ```

3. **Distributed tracing**:
   - Integrate Spring Cloud Sleuth or OpenTelemetry
   - Propagate trace context to external systems (Elasticsearch, Redis)
   - Define trace spans for key operations (DB queries, external API calls)

4. **Log aggregation**:
   - Ship logs to centralized system (CloudWatch Logs → Datadog)
   - Define log retention policies
   - Set up alerts for error rate thresholds

**Reference**: Section 6.2 - ロギング方針, Section 2.3 (mentions Datadog monitoring)

---

### M-5: No Explicit Data Contract Definition Between Components

**Issue**: The design mentions DTO conversion (Section 3.3) and shows API request/response examples (Section 5.2) but doesn't define:
- Schema validation strategy (JSON Schema, OpenAPI)
- How breaking changes in data contracts are detected
- Version compatibility between frontend and backend DTOs

**Impact**:
- **Runtime failures**: Invalid data not caught until runtime
- **Integration issues**: Frontend and backend may have incompatible expectations
- **No contract testing**: Cannot verify API compatibility without manual testing

**Recommendation**: Define explicit data contracts:

1. **OpenAPI specification**:
   ```yaml
   openapi: 3.0.0
   paths:
     /v1/properties:
       post:
         requestBody:
           content:
             application/json:
               schema:
                 $ref: '#/components/schemas/PropertyCreateRequest'
         responses:
           '201':
             content:
               application/json:
                 schema:
                   $ref: '#/components/schemas/PropertyResponse'

   components:
     schemas:
       PropertyCreateRequest:
         type: object
         required: [title, address, price]
         properties:
           title: {type: string, maxLength: 255}
           price: {type: number, minimum: 0}
   ```

2. **Schema validation**:
   - Use `@Valid` annotations with Bean Validation constraints
   - Generate TypeScript types from OpenAPI spec for frontend
   - Implement contract tests (Pact, Spring Cloud Contract)

3. **Breaking change detection**:
   - Include schema validation in CI/CD pipeline
   - Use tools like `openapi-diff` to detect breaking changes
   - Enforce semantic versioning for API changes

**Reference**: Section 5.2 - リクエスト/レスポンス形式

---

## Minor Improvements

### I-1: Consider Adding Health Check Endpoints for Operational Monitoring

While the design mentions CloudWatch and Datadog monitoring (Section 2.3), it should define explicit health check endpoints for:
- Deep health checks (database connectivity, Redis availability, Elasticsearch status)
- Readiness vs. liveness probes for Kubernetes/ECS
- Dependency health aggregation

Recommendation: Implement Spring Boot Actuator endpoints:
```
GET /actuator/health - Overall health status
GET /actuator/health/liveness - Container liveness
GET /actuator/health/readiness - Ready to accept traffic
```

**Reference**: Section 2.3 (monitoring tools), Section 7.3 (availability requirements)

---

### I-2: JWT Token Storage in Cookies May Limit Mobile App Extensibility

The authentication design (Section 5.3) specifies storing JWT in cookies. While this works for web applications, it limits future mobile app development where cookies are less suitable.

Recommendation: Design for multiple client types:
- Web: HTTP-only cookies (CSRF protection needed)
- Mobile: Authorization header with bearer token
- Refresh token strategy for long-lived sessions

**Reference**: Section 5.3 - 認証・認可方式

---

## Positive Aspects

1. **Clear technology choices**: Well-defined tech stack with specific versions (Java 17, Spring Boot 3.2, PostgreSQL 15)
2. **Comprehensive test strategy**: Defines unit, integration, and coverage goals (Section 6.3)
3. **Security awareness**: Mentions multiple security controls (HTTPS, JWT, SQL injection prevention, XSS protection)
4. **Deployment automation**: Blue-green deployment strategy for zero-downtime releases (Section 6.4)
5. **Performance goals**: Specific, measurable performance targets (API response time, concurrent users)

---

## Summary

This design document exhibits several critical structural issues that will significantly impact long-term maintainability:

**Immediate Action Required**:
1. Decompose `PropertyManagementService` to eliminate God Object anti-pattern (C-1)
2. Normalize database schema and add foreign key constraints (C-2)
3. Implement API versioning before any production deployment (C-3)
4. Externalize configuration and introduce abstraction in `NotificationService` (C-4)

**High Priority**:
5. Introduce domain model layer separate from DTOs (S-1)
6. Design application-specific error taxonomy with retry strategies (S-2)
7. Extract matching logic to prevent circular dependencies (S-3)
8. Define schema evolution and migration strategy (S-4)

Addressing these structural issues early will prevent significant refactoring costs and enable sustainable, maintainable system growth.
