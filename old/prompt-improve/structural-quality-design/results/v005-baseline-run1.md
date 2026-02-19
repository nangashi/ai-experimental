# Structural Quality Design Review: RealEstateHub システム設計書

## Critical Issues

### 1. Severe Single Responsibility Principle Violation in PropertyManagementService

**Issue**: The `PropertyManagementService` class violates SRP by handling property management, customer matching, appointment scheduling, contract status updates, and statistics aggregation within a single service (Section 3.2). This creates a "god class" anti-pattern with at least 6 distinct repositories injected.

**Impact**:
- Extremely high coupling - any change to matching logic, appointments, contracts, or statistics requires modifying and retesting the entire PropertyManagementService
- Poor testability - mocking 6+ dependencies for unit tests becomes unwieldy
- High risk of merge conflicts in team development
- Difficult to maintain and understand - the class has too many reasons to change
- Violates Open/Closed Principle - adding new functionality requires modifying existing code

**Recommended Improvement**:
```java
@Service
public class PropertyManagementService {
    private final PropertyRepository propertyRepository;
    private final CacheService cacheService;
    private final SearchIndexService searchIndexService;
    // Only property-related dependencies
}

@Service
public class PropertyMatchingService {
    private final CustomerRepository customerRepository;
    private final PropertyRepository propertyRepository;
    private final MatchingAlgorithm matchingAlgorithm;
}

@Service
public class ContractManagementService {
    private final ContractRepository contractRepository;
    private final NotificationService notificationService;
}

@Service
public class PropertyStatisticsService {
    private final PropertyRepository propertyRepository;
    private final ContractRepository contractRepository;
}
```

### 2. Hardcoded External Service Credentials in NotificationService

**Issue**: The `NotificationService` class contains hardcoded SMTP host and SMS API keys as class fields (Section 3.2, lines 116-117). This is a severe structural design flaw.

**Impact**:
- Violates Dependency Inversion Principle - high-level notification logic depends on low-level configuration details
- Impossible to change environments (dev/staging/prod) without code changes
- Prevents proper testing - cannot mock or stub external services easily
- Security risk - credentials in source code
- Violates Single Responsibility - service handles both business logic and configuration

**Recommended Improvement**:
```java
@Service
public class NotificationService {
    private final EmailProvider emailProvider;
    private final SmsProvider smsProvider;

    public NotificationService(EmailProvider emailProvider, SmsProvider smsProvider) {
        this.emailProvider = emailProvider;
        this.smsProvider = smsProvider;
    }

    public void sendEmail(String to, String subject, String body) {
        emailProvider.send(to, subject, body);
    }
}

// Configuration externalized
public interface EmailProvider {
    void send(String to, String subject, String body);
}

@Component
public class SmtpEmailProvider implements EmailProvider {
    private final EmailConfig config;
    // Configuration injected from application.yml
}
```

### 3. Missing Dependency Injection Design and Testability Strategy

**Issue**: Despite claiming "dependency injection design exists" (Section 6.3), the design uses field injection (`@Autowired` on fields) throughout, and there's no clear abstraction layer for external dependencies like Elasticsearch, Redis, or notification providers.

**Impact**:
- Services are tightly coupled to concrete implementations
- Cannot easily mock dependencies for unit testing
- Violates Dependency Inversion Principle - high-level modules depend on low-level modules
- Difficult to implement test doubles or alternative implementations
- The claimed 80% test coverage target is unrealistic without proper DI design

**Recommended Improvement**:
1. Replace field injection with constructor injection
2. Define interfaces for all external dependencies
3. Create proper abstraction layers:

```java
// Define interfaces for infrastructure dependencies
public interface PropertySearchIndex {
    void index(Property property);
    List<Property> search(SearchCriteria criteria);
}

public interface PropertyCache {
    void put(String key, PropertyDTO value);
    Optional<PropertyDTO> get(String key);
}

// Implementation with constructor injection
@Service
public class PropertyManagementService {
    private final PropertyRepository propertyRepository;
    private final PropertySearchIndex searchIndex;
    private final PropertyCache cache;

    public PropertyManagementService(
        PropertyRepository propertyRepository,
        PropertySearchIndex searchIndex,
        PropertyCache cache) {
        this.propertyRepository = propertyRepository;
        this.searchIndex = searchIndex;
        this.cache = cache;
    }
}
```

### 4. No Data Model Versioning or Migration Strategy

**Issue**: The design shows SQL schema definitions (Section 4.1) but provides no strategy for schema evolution, data migration, or backward compatibility when the schema changes.

**Impact**:
- High risk of breaking changes during schema updates
- No plan for zero-downtime deployments when data model changes
- Potential data loss or corruption during migration
- Difficult to rollback failed deployments
- Blue-Green deployment (Section 6.4) cannot work properly without schema versioning

**Recommended Improvement**:
1. Adopt Flyway or Liquibase for version-controlled database migrations
2. Define schema versioning strategy (e.g., semantic versioning)
3. Establish backward compatibility rules:
   - Additive changes only (new columns nullable or with defaults)
   - Breaking changes require multi-phase rollout
4. Document migration testing procedures
5. Plan for schema version tracking in production

## Significant Issues

### 5. Lack of Repository Layer Abstraction and Implementation Leakage

**Issue**: The design directly exposes Spring Data JPA repositories without an abstraction layer, and there's no mention of query complexity management or N+1 query prevention strategies.

**Impact**:
- Services become tightly coupled to JPA implementation details
- Difficult to switch persistence technologies
- Risk of N+1 query problems degrading performance
- Transaction boundaries unclear
- Domain logic may leak into repository layer

**Recommended Improvement**:
```java
// Domain repository interface (in domain layer)
public interface PropertyRepository {
    Property save(Property property);
    Optional<Property> findById(Long id);
    List<Property> findByBrokerId(Long brokerId);
}

// JPA implementation (in infrastructure layer)
@Repository
public class JpaPropertyRepository implements PropertyRepository {
    private final SpringDataPropertyRepository springDataRepo;

    @Override
    public List<Property> findByBrokerId(Long brokerId) {
        // Use @EntityGraph or explicit JOIN FETCH to avoid N+1
        return springDataRepo.findByBrokerIdWithDetails(brokerId);
    }
}
```

### 6. Insufficient Error Handling Strategy and Missing Domain Exception Taxonomy

**Issue**: The error handling strategy (Section 6.1) only categorizes errors by HTTP status codes (400, 404, 500) without defining application-level error classification, domain exceptions, or distinguishing between recoverable and non-recoverable errors.

**Impact**:
- Clients cannot distinguish between different error scenarios programmatically
- No clear guidance on which errors are retryable
- Missing domain-specific error contexts (e.g., property not available, booking conflict)
- Poor debugging experience - generic error messages
- Violates Information Expert principle - domain errors should be expressed in domain terms

**Recommended Improvement**:
```java
// Define domain exception hierarchy
public abstract class DomainException extends RuntimeException {
    private final ErrorCode errorCode;
    private final boolean retryable;
}

public enum ErrorCode {
    PROPERTY_NOT_FOUND("E001", false),
    PROPERTY_ALREADY_BOOKED("E002", false),
    INVALID_PRICE_RANGE("E003", false),
    MATCHING_SERVICE_UNAVAILABLE("E004", true),
    EXTERNAL_SERVICE_TIMEOUT("E005", true);

    private final String code;
    private final boolean retryable;
}

// Specific domain exceptions
public class PropertyNotFoundException extends DomainException {
    public PropertyNotFoundException(Long propertyId) {
        super(ErrorCode.PROPERTY_NOT_FOUND, "Property not found: " + propertyId);
    }
}

// Structured error response
{
  "errorCode": "E001",
  "message": "Property not found: 456",
  "retryable": false,
  "timestamp": "2026-02-11T10:00:00Z",
  "details": {
    "propertyId": 456
  }
}
```

### 7. No Clear Layer Separation and Circular Dependency Risk

**Issue**: The design claims "3-layer architecture" (Section 3.1) but shows no package structure, module boundaries, or enforcement of layer dependencies. The PropertyManagementService accessing multiple repositories directly suggests no domain layer exists.

**Impact**:
- Risk of circular dependencies between modules
- No enforcement of dependency direction rules
- Difficult to maintain architectural boundaries over time
- Cannot leverage compile-time architecture validation
- Unclear which components belong to which layer

**Recommended Improvement**:
```
com.realestatehub
├── domain
│   ├── model (Property, Customer, Contract - pure domain objects)
│   ├── repository (interfaces only)
│   └── service (domain services - business logic)
├── application
│   └── service (application services - use case orchestration)
├── infrastructure
│   ├── persistence (JPA implementations, entities)
│   ├── cache (Redis implementations)
│   └── search (Elasticsearch implementations)
└── presentation
    ├── controller (REST controllers)
    └── dto (request/response objects)
```

Use ArchUnit or Spring Modulith to enforce:
```java
@ArchTest
static final ArchRule domain_should_not_depend_on_infrastructure =
    noClasses().that().resideInAPackage("..domain..")
    .should().dependOnClassesThat().resideInAPackage("..infrastructure..");
```

### 8. Missing State Management Policy and Transaction Boundary Design

**Issue**: The design doesn't specify transaction boundaries, propagation policies, or consistency requirements. With multiple data stores (PostgreSQL, Redis, Elasticsearch), there's no strategy for maintaining consistency across them.

**Impact**:
- Risk of data inconsistency between primary DB, cache, and search index
- Unclear where transactions begin and end
- Potential for partial updates leaving system in inconsistent state
- No guidance on optimistic vs pessimistic locking
- Cache invalidation strategy undefined

**Recommended Improvement**:
1. Define transaction boundaries explicitly:
```java
@Service
@Transactional(readOnly = true)
public class PropertyManagementService {

    @Transactional(propagation = Propagation.REQUIRED)
    public PropertyDTO createProperty(PropertyRequest request) {
        // 1. Persist to PostgreSQL (transactional)
        Property property = propertyRepository.save(...);

        // 2. Update cache (best-effort, async)
        cacheService.invalidate("properties");

        // 3. Update search index (eventual consistency via event)
        eventPublisher.publish(new PropertyCreatedEvent(property.getId()));

        return toDTO(property);
    }
}
```

2. Implement eventual consistency pattern:
   - PostgreSQL is source of truth
   - Redis cache invalidation on write
   - Elasticsearch updates via event-driven approach (CDC or domain events)

3. Document consistency guarantees for each operation

## Moderate Issues

### 9. No API Versioning Strategy

**Issue**: API endpoints (Section 5.1) lack versioning scheme. The design mentions "versioning and backward compatibility strategies" as evaluation criteria but doesn't implement them.

**Impact**:
- Difficult to evolve API without breaking existing clients
- No clear migration path for API changes
- Risk of breaking changes in production
- Violates Open/Closed Principle at API level

**Recommended Improvement**:
```
Version in URL path:
- POST /api/v1/properties
- POST /api/v2/properties (when breaking changes needed)

Or version in header:
- Accept: application/vnd.realestatehub.v1+json

Define versioning policy:
- v1 supported for minimum 12 months after v2 release
- Deprecation warnings in response headers
- Clear migration guide published
```

### 10. RESTful API Design Violations

**Issue**: Several endpoints violate REST conventions (Section 5.1):
- `/properties/create` instead of `POST /properties`
- `/properties/update/{id}` instead of `PUT /properties/{id}`
- `/properties/delete/{id}` instead of `DELETE /properties/{id}`
- `/contracts/status/{id}` instead of `PATCH /contracts/{id}`

**Impact**:
- Non-idiomatic API design confuses developers
- Violates principle of least surprise
- HTTP methods not used semantically (all operations could be POST)
- Difficult for API gateway/caching layer to optimize

**Recommended Improvement**:
```
Correct RESTful design:
- POST /api/v1/properties (create)
- PUT /api/v1/properties/{id} (full replace)
- PATCH /api/v1/properties/{id} (partial update)
- DELETE /api/v1/properties/{id} (delete)
- GET /api/v1/properties/{id} (retrieve)
- GET /api/v1/properties?query={keyword} (search)

Sub-resource operations:
- POST /api/v1/properties/{id}/matching (trigger matching)
- GET /api/v1/properties/{id}/appointments (list appointments)
```

### 11. Data Model Denormalization Without Clear Strategy

**Issue**: The design embeds owner information in properties table and customer preferences in customers table (Section 4.2). While denormalization can be appropriate, there's no explanation of the trade-offs or update consistency strategy.

**Impact**:
- Potential data redundancy if owner information changes
- No clear update policy when denormalized data changes
- May violate normal forms without documented reason
- Could lead to data inconsistency bugs

**Recommended Improvement**:
Document denormalization decisions:
```
Decision: Embed owner info in properties table
Rationale: Owner rarely changes; read-heavy access pattern
Trade-off: Accept potential stale data for performance
Consistency strategy: No automatic sync; manual correction if owner updates
Alternative considered: Separate owners table (rejected due to added complexity for rare updates)

Decision: Embed preferences in customers table
Rationale: 1:1 relationship; preferences always loaded with customer
Trade-off: Schema changes affect main table
Consistency strategy: N/A (no denormalization)
Alternative: Could extract to preferences table if multi-profile support needed
```

### 12. Missing Observability Design for Distributed Tracing

**Issue**: While monitoring tools are mentioned (CloudWatch + Datadog, Section 2.3), there's no distributed tracing design for tracking requests across service boundaries, database calls, cache operations, and external API calls.

**Impact**:
- Difficult to debug performance issues across layers
- Cannot identify bottlenecks in multi-step operations (e.g., property creation with cache + search index updates)
- Missing context propagation for async operations
- Poor operational visibility

**Recommended Improvement**:
```java
// Implement distributed tracing
1. Add OpenTelemetry or Spring Cloud Sleuth
2. Propagate trace context through:
   - HTTP headers (trace-id, span-id)
   - Async operations (ThreadLocal or reactive context)
   - Event publishing

3. Define trace structure:
   POST /properties
   ├─ span: http.request
   ├─ span: service.createProperty
   │  ├─ span: db.insert (PostgreSQL)
   │  ├─ span: cache.invalidate (Redis)
   │  └─ span: event.publish
   └─ span: http.response

4. Add custom span attributes:
   - property.id
   - broker.id
   - operation.type
```

### 13. No Configuration Management Strategy for Multiple Environments

**Issue**: The design mentions multiple environments (dev, staging, prod) but doesn't specify how configuration differs across environments or how environment-specific settings are managed.

**Impact**:
- Risk of using wrong configuration in wrong environment
- No clear separation of dev/prod secrets
- Difficult to reproduce production issues in staging
- Potential security issues if dev credentials leak to prod

**Recommended Improvement**:
```yaml
# Use Spring Profiles + external configuration
application.yml (defaults)
application-dev.yml (overrides for dev)
application-staging.yml (overrides for staging)
application-prod.yml (overrides for prod - minimal, secrets externalized)

# Externalize secrets
- Use AWS Secrets Manager or Parameter Store for prod
- Environment variables for staging
- Local file for dev

# Configuration hierarchy
1. Default values (application.yml)
2. Profile-specific (application-{profile}.yml)
3. Environment variables
4. External secrets store (highest priority)
```

### 14. Unclear Module Division for Future Extensions

**Issue**: The design mentions "future expansion" for end-users (Section 1.3) but doesn't architect modules to support this extension without major refactoring.

**Impact**:
- May require significant rework when adding end-user features
- Current broker-centric design may not support multi-tenant scenarios
- Risk of violating Open/Closed Principle when extending

**Recommended Improvement**:
```
Define module boundaries anticipating extension:

Module: property-management-core
- Property CRUD (broker-agnostic)
- Property search

Module: broker-portal
- Broker-specific workflows
- Dashboard/statistics

Module: customer-portal (future)
- Customer-facing property search
- Favorite/bookmark features
- Direct appointment requests

Shared kernel: domain models, interfaces
Each module: independent deployable unit
```

## Minor Improvements

### 15. Missing Structured Logging Design

**Issue**: Logging policy (Section 6.2) mentions log levels but not structured logging format or log aggregation strategy.

**Recommendation**:
```java
// Use structured logging (JSON format)
{
  "timestamp": "2026-02-11T10:00:00Z",
  "level": "INFO",
  "trace_id": "abc123",
  "service": "property-service",
  "operation": "createProperty",
  "property_id": 456,
  "broker_id": 123,
  "duration_ms": 45,
  "message": "Property created successfully"
}

// Benefits:
- Easy to parse and aggregate in Datadog
- Queryable by trace_id, property_id, etc.
- Consistent format across services
```

### 16. No Idempotency Strategy for Critical Operations

**Issue**: No mention of idempotency keys or duplicate request detection for operations like property creation or contract updates.

**Recommendation**:
```java
// Add idempotency support
POST /api/v1/properties
Headers:
  Idempotency-Key: unique-client-generated-uuid

// Server checks if operation with this key already processed
// Returns 200 with original result if duplicate
// Stores key + result for 24 hours
```

### 17. Test Strategy Lacks Component-Level Guidance

**Issue**: Test strategy (Section 6.3) defines coverage target but not which components should have which test types.

**Recommendation**:
```
Unit tests (fast, isolated):
- Domain logic (matching algorithm, validation rules)
- DTO conversions (MapStruct mappers)
- Utility functions

Integration tests (with TestContainers):
- Repository layer (JPA queries)
- Cache behavior (Redis integration)
- Search indexing (Elasticsearch)

End-to-end tests (full stack):
- Critical user journeys (property creation → matching → booking)
- Authentication flows
- Error scenarios

Contract tests:
- API contracts (OpenAPI/Swagger validation)
- Event schemas
```

## Positive Aspects

1. **Clear technology stack selection**: Well-defined choices with specific versions (Java 17, Spring Boot 3.2, PostgreSQL 15)
2. **Appropriate use of caching and search technologies**: Redis for caching and Elasticsearch for full-text search shows understanding of different data access patterns
3. **CI/CD pipeline planned**: GitHub Actions integration and Blue-Green deployment strategy (though requires schema versioning support)
4. **Security basics covered**: HTTPS, JWT, SQL injection prevention, XSS/CSRF protection mentioned

## Summary

This design document demonstrates awareness of modern technology stack and deployment practices but suffers from fundamental structural design flaws that will severely impact maintainability and extensibility:

**Most Critical Concerns**:
1. God class anti-pattern in PropertyManagementService violates SRP
2. Hardcoded credentials violate DIP and prevent proper testing
3. Missing abstraction layers and poor dependency injection design
4. No schema versioning strategy incompatible with stated Blue-Green deployment

**Key Recommendations**:
1. Decompose PropertyManagementService into single-responsibility services
2. Externalize all configuration and define proper abstraction interfaces
3. Implement constructor injection with interface-based dependencies
4. Add database migration tooling (Flyway) and versioning strategy
5. Define clear layer boundaries with architectural enforcement
6. Establish domain exception taxonomy and structured error responses
7. Document transaction boundaries and consistency guarantees

The architecture needs significant restructuring to achieve the stated goals of maintainability and extensibility. The current design will lead to high coupling, difficult testing, and costly refactoring needs as the system evolves.
