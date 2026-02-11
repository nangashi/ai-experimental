# Structural Quality Design Review - RealEstateHub System

## Stage 1: Overall Structure Analysis

The RealEstateHub system adopts a 3-layer architecture (Frontend, Backend Service Layer, Repository Layer) with PostgreSQL, Redis, and Elasticsearch as data stores. The primary structural concern is the apparent violation of Single Responsibility Principle in the Service Layer, particularly in `PropertyManagementService`, which handles property management, customer matching, appointment scheduling, contract status updates, and statistics aggregation. This creates high coupling and low cohesion at the architectural level.

The design lacks explicit dependency injection configuration, domain model/DTO separation strategy, and API versioning strategy. Error handling and logging are mentioned at a high level but lack application-level error classification and propagation design.

## Critical Issues

### C1. Severe SRP Violation in PropertyManagementService

**Issue**: `PropertyManagementService` has excessive responsibilities spanning property CRUD, customer matching, appointment availability calculation, contract status updates, and statistics aggregation (Section 3.2).

**Impact**:
- This God Object pattern makes the class difficult to understand, test, and modify
- Changes to any single feature (e.g., matching algorithm) require modifying a class that handles 5+ distinct responsibilities
- High coupling to 6 different repositories makes unit testing nearly impossible without complex mock setups
- Violates Open/Closed Principle - adding new property-related features forces modification of this monolithic class

**Recommendation**:
Decompose into focused services following SRP:
```java
@Service
public class PropertyService {
    private PropertyRepository propertyRepository;
    private PropertyCacheService cacheService;
    private PropertySearchService searchService;
    // Focus: Property CRUD only
}

@Service
public class PropertyMatchingService {
    private PropertyRepository propertyRepository;
    private CustomerRepository customerRepository;
    private MatchingAlgorithm matchingAlgorithm;
    // Focus: Customer-property matching logic only
}

@Service
public class AppointmentSchedulingService {
    private AppointmentRepository appointmentRepository;
    // Focus: Appointment availability and scheduling only
}

@Service
public class ContractService {
    private ContractRepository contractRepository;
    private NotificationService notificationService;
    // Focus: Contract lifecycle management only
}

@Service
public class PropertyStatisticsService {
    private PropertyRepository propertyRepository;
    private ContractRepository contractRepository;
    // Focus: Statistics aggregation only
}
```

### C2. Missing Dependency Injection Design and Direct Infrastructure Coupling

**Issue**: `NotificationService` hardcodes infrastructure configuration (`smtpHost`, `smsApiKey`) as string literals and directly couples to SMTP and SMS APIs (Section 3.2). No dependency injection design or interface abstraction is defined for external dependencies.

**Impact**:
- Impossible to test notification logic without sending actual emails/SMS
- Cannot swap email providers or SMS services without modifying production code
- Environment-specific configuration is embedded in code rather than externalized
- Violates Dependency Inversion Principle - high-level notification logic depends directly on low-level infrastructure details

**Recommendation**:
Introduce interface abstraction and DI configuration:
```java
public interface EmailSender {
    void send(String to, String subject, String body);
}

public interface SMSSender {
    void send(String phoneNumber, String message);
}

@Service
public class NotificationService {
    private final EmailSender emailSender;
    private final SMSSender smsSender;

    @Autowired
    public NotificationService(EmailSender emailSender, SMSSender smsSender) {
        this.emailSender = emailSender;
        this.smsSender = smsSender;
    }

    public void sendEmail(String to, String subject, String body) {
        emailSender.send(to, subject, body);
    }
}

@Configuration
public class NotificationConfig {
    @Bean
    public EmailSender emailSender(
        @Value("${smtp.host}") String host,
        @Value("${smtp.port}") int port) {
        return new SmtpEmailSender(host, port);
    }

    @Bean
    public SMSSender smsSender(@Value("${sms.api.key}") String apiKey) {
        return new TwilioSMSSender(apiKey);
    }
}
```

This enables:
- Test doubles (mock implementations) for testing
- Easy provider switching via configuration
- Environment-specific configuration via Spring profiles

### C3. RESTful API Design Violations

**Issue**: API endpoints use non-standard HTTP methods and verbs in URLs (Section 5.1):
- `POST /properties/create` (verb in URL)
- `PUT /properties/update/{id}` (verb in URL)
- `DELETE /properties/delete/{id}` (verb in URL)
- `POST /properties/{id}/match-customers` (RPC-style action)

**Impact**:
- Violates REST architectural constraints and HTTP semantics
- Reduces API discoverability and intuitiveness
- Harder to apply standard REST tooling and caching strategies
- Inconsistent with industry best practices for RESTful API design

**Recommendation**:
Follow RESTful conventions using HTTP methods properly:
```
POST   /properties              (create property)
PUT    /properties/{id}         (full update)
PATCH  /properties/{id}         (partial update)
DELETE /properties/{id}         (delete property)
GET    /properties?q={keyword}  (search - use query params)
GET    /properties/{id}         (retrieve single property)
POST   /properties/{id}/matches (create match suggestion - treat as sub-resource)
```

For customer matching, model as a sub-resource or use `POST /matches` with `propertyId` in request body to follow REST principles.

## Significant Issues

### S1. Missing Domain Model and DTO Separation

**Issue**: Section 3.3 mentions "Service → DTOに変換" but Section 4 defines database schemas without corresponding domain entities. The relationship between database tables, JPA entities, and DTOs is undefined.

**Impact**:
- Risk of tight coupling between API contracts and database schema
- Database schema changes force API changes, breaking backward compatibility
- Cannot evolve internal data model independently from public API
- Leaking persistence details (e.g., database IDs, internal status codes) to API clients

**Recommendation**:
Define three distinct layers:
1. **Entity Layer** (JPA): Database mapping with `@Entity` annotations
2. **Domain Model Layer**: Business logic objects (optional for anemic domains)
3. **DTO Layer**: API request/response objects

Establish mapping strategy:
```java
// Entity (persistence layer)
@Entity
@Table(name = "properties")
public class PropertyEntity {
    @Id @GeneratedValue
    private Long id;
    private String title;
    // ... database fields
}

// DTO (API layer)
public class PropertyResponse {
    private Long id;
    private String title;
    private String status; // Translated to human-readable values
    // ... API fields
}

// Mapper
@Mapper
public interface PropertyMapper {
    PropertyResponse toResponse(PropertyEntity entity);
    PropertyEntity toEntity(PropertyRequest request);
}
```

This separation allows independent evolution of database schema and API contracts.

### S2. Missing Error Classification and Propagation Strategy

**Issue**: Error handling is limited to `GlobalExceptionHandler` catching all exceptions and mapping to HTTP status codes (400, 404, 500). No application-level error taxonomy, error codes, or propagation strategy is defined (Section 6.1).

**Impact**:
- Clients cannot programmatically distinguish error types (validation failure vs. business rule violation vs. system error)
- No guidance for which errors are retryable vs. non-retryable
- Missing correlation between logs and client-visible errors for troubleshooting
- Error messages may expose internal implementation details

**Recommendation**:
Design application-level error taxonomy:
```java
// Base application exception
public abstract class ApplicationException extends RuntimeException {
    private final String errorCode;
    private final ErrorCategory category;

    protected ApplicationException(String errorCode, ErrorCategory category, String message) {
        super(message);
        this.errorCode = errorCode;
        this.category = category;
    }
}

// Domain-specific exceptions
public class PropertyNotFoundException extends ApplicationException {
    public PropertyNotFoundException(Long propertyId) {
        super("PROPERTY_NOT_FOUND", ErrorCategory.CLIENT_ERROR,
              "Property with ID " + propertyId + " not found");
    }
}

public class PropertyAlreadyContractedException extends ApplicationException {
    public PropertyAlreadyContractedException(Long propertyId) {
        super("PROPERTY_ALREADY_CONTRACTED", ErrorCategory.BUSINESS_RULE_VIOLATION,
              "Property is already under contract");
    }
}

// Error response structure
public class ErrorResponse {
    private String errorCode;      // Machine-readable code
    private String message;         // Human-readable message
    private boolean retryable;      // Retry guidance
    private String correlationId;   // For log correlation
}
```

Define exception handling policy:
- Client errors (validation, not found) → 400/404, not retryable
- Business rule violations → 409/422, not retryable
- System errors (DB timeout, external API failure) → 500/503, retryable

### S3. Data Model Lacks Referential Integrity and Normalization

**Issue**: Section 4.2 explicitly states "外部キー制約は設定せず、アプリケーション側でデータ整合性を管理". Additionally, `properties` table embeds owner information (`owner_name`, `owner_phone`) and `customers` table embeds preferences as flat columns.

**Impact**:
- No database-level guarantee of referential integrity (orphaned appointments, contracts pointing to deleted properties)
- Application code must manually enforce consistency, increasing bug risk
- Owner information duplication across multiple properties leads to update anomalies
- Cannot query "all properties by owner" efficiently
- Flat preference columns in `customers` table are not extensible (adding new preference types requires schema changes)

**Recommendation**:
1. **Enable foreign key constraints** for data integrity:
```sql
ALTER TABLE appointments
    ADD CONSTRAINT fk_appointment_property
    FOREIGN KEY (property_id) REFERENCES properties(id),
    ADD CONSTRAINT fk_appointment_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id);
```

2. **Normalize owner information**:
```sql
CREATE TABLE property_owners (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255)
);

ALTER TABLE properties
    ADD COLUMN owner_id BIGINT,
    ADD CONSTRAINT fk_property_owner
    FOREIGN KEY (owner_id) REFERENCES property_owners(id),
    DROP COLUMN owner_name,
    DROP COLUMN owner_phone;
```

3. **Normalize customer preferences** (if preferences need to be extensible):
```sql
CREATE TABLE customer_preferences (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT REFERENCES customers(id),
    preference_key VARCHAR(100),  -- 'max_price', 'min_area', 'preferred_area'
    preference_value VARCHAR(500)
);
```

If preferences are truly fixed and simple, keeping them as columns is acceptable, but document this design decision explicitly.

### S4. Missing API Versioning Strategy

**Issue**: Section 5 defines API endpoints but no versioning or backward compatibility strategy is mentioned.

**Impact**:
- Breaking API changes force all clients to upgrade simultaneously
- Cannot support multiple client versions (mobile apps with staged rollout)
- No clear path for deprecating old endpoints
- Risk of production outages when deploying API changes

**Recommendation**:
Define versioning strategy using URL-based versioning:
```
/v1/properties
/v1/customers
/v2/properties  (when breaking changes needed)
```

Document compatibility policy:
- Major version (v1 → v2): Breaking changes allowed
- Within same major version: Only backward-compatible additions
- Deprecation policy: Announce 6 months before removal, provide migration guide
- Support N and N-1 major versions concurrently

Alternative: Use HTTP headers (`Accept: application/vnd.realestatehub.v1+json`) if URL versioning is undesirable.

## Moderate Issues

### M1. No Configuration Management Strategy for Multi-Environment Deployment

**Issue**: Section 2.3 mentions multiple environments (staging, production) and Section 6.2 mentions environment-specific log levels, but no configuration management strategy is defined. Infrastructure credentials are hardcoded in `NotificationService`.

**Impact**:
- Cannot manage environment-specific configurations (DB URLs, API keys, feature flags) systematically
- Risk of deploying production credentials to staging or vice versa
- Difficult to enable/disable features per environment
- No support for local development environment configuration

**Recommendation**:
Adopt Spring Profiles and externalized configuration:
```yaml
# application.yml (defaults)
spring:
  profiles:
    active: local

# application-local.yml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/realestate_dev

# application-staging.yml
spring:
  datasource:
    url: ${DB_URL}  # From environment variable or AWS Secrets Manager

# application-production.yml
spring:
  datasource:
    url: ${DB_URL}
logging:
  level:
    root: INFO
```

Use AWS Systems Manager Parameter Store or Secrets Manager for sensitive credentials. Inject via environment variables in ECS task definitions.

### M2. Missing Distributed Tracing and Observability Design

**Issue**: Section 6.2 mentions basic logging with Logback, and Section 2.3 mentions CloudWatch + Datadog for monitoring, but no distributed tracing, correlation ID propagation, or structured logging design is defined.

**Impact**:
- Cannot trace requests across service boundaries (future microservices migration)
- Difficult to correlate logs across different components (API → Service → Repository → DB)
- No request-level performance profiling to identify bottlenecks
- Harder to diagnose production issues involving multiple operations

**Recommendation**:
Implement distributed tracing with Spring Cloud Sleuth or OpenTelemetry:
```java
// Add dependency
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-brave</artifactId>
</dependency>

// Configuration
management:
  tracing:
    sampling:
      probability: 0.1  # 10% sampling in production

// Structured logging
@Slf4j
public class PropertyService {
    public PropertyDTO getProperty(Long id) {
        log.info("Fetching property",
                 kv("propertyId", id),
                 kv("action", "getProperty"));
    }
}
```

Ensure correlation IDs (trace IDs) are:
- Generated at API gateway/entry point
- Propagated through all service calls
- Included in log entries
- Returned in error responses for client-side debugging

### M3. Lack of Extensibility for Future Requirements

**Issue**: The design lacks plugin points or strategy patterns for features likely to evolve:
- Matching algorithm (Section 3.2 `matchCustomers` is embedded in service)
- Notification channels (only email and SMS, no abstraction for adding push notifications, LINE, etc.)
- Search ranking algorithm (Elasticsearch usage is mentioned but ranking strategy is undefined)

**Impact**:
- Adding new matching algorithms requires modifying `PropertyManagementService`
- Cannot A/B test different matching strategies without code changes
- Adding new notification channels requires modifying `NotificationService` with new hardcoded logic

**Recommendation**:
Introduce Strategy pattern for extensibility:
```java
public interface MatchingStrategy {
    List<Customer> findMatches(Property property, MatchingCriteria criteria);
}

@Component("simpleMatchingStrategy")
public class SimpleMatchingStrategy implements MatchingStrategy {
    // Basic price/area/location matching
}

@Component("aiMatchingStrategy")
public class AIMatchingStrategy implements MatchingStrategy {
    // ML-based matching
}

@Service
public class PropertyMatchingService {
    private final Map<String, MatchingStrategy> strategies;

    @Autowired
    public PropertyMatchingService(Map<String, MatchingStrategy> strategies) {
        this.strategies = strategies;
    }

    public List<Customer> matchCustomers(Long propertyId, String strategyName) {
        MatchingStrategy strategy = strategies.get(strategyName);
        return strategy.findMatches(property, criteria);
    }
}
```

Similarly, apply Strategy pattern to notification channels to support future additions without modifying existing code.

### M4. Test Strategy Lacks Specificity

**Issue**: Section 6.3 mentions unit tests for Service layer and integration tests for Repository/API, but lacks guidance on:
- How to handle external dependencies (Redis, Elasticsearch, external APIs) in tests
- Test data management strategy
- Contract testing for API consumers
- Performance/load testing approach

**Impact**:
- Developers may inconsistently mock external dependencies
- Integration tests may be slow or flaky due to real database/cache usage
- No guarantee that API changes won't break existing clients
- Performance regressions may go undetected until production

**Recommendation**:
Expand test strategy:

**Unit Tests**:
- Mock all external dependencies (repositories, caches, external APIs)
- Use Mockito for service layer logic testing
- Goal: Fast feedback, high code coverage (80%+)

**Integration Tests**:
- Use Testcontainers for PostgreSQL, Redis, Elasticsearch
- Use WireMock for external API stubs
- Test repository layer and full API flows
- Goal: Verify component interactions and data access logic

**Contract Tests**:
- Use Spring Cloud Contract or Pact for consumer-driven contract testing
- Publish API contracts for frontend/mobile teams
- Goal: Catch breaking API changes before deployment

**Performance Tests**:
- Use JMeter or Gatling for load testing
- Test key scenarios: property search, matching algorithm
- Goal: Validate performance targets (200ms p95 response time)

### M5. Cache Invalidation Strategy Not Defined

**Issue**: Section 3.2 shows `PropertyManagementService` uses Redis (`redisTemplate`) for caching, but no cache invalidation strategy, TTL policy, or cache key design is documented.

**Impact**:
- Risk of serving stale data (property price updated in DB but cached value not invalidated)
- Potential cache stampede when popular items expire simultaneously
- Unclear which operations trigger cache updates vs. invalidations
- No strategy for handling cache failures (cache-aside vs. read-through)

**Recommendation**:
Define cache strategy explicitly:

**Cache Keys Design**:
```
property:{id}              → Property entity
property:search:{hash}     → Search results
customer:matches:{customerId} → Match results
```

**Invalidation Policy**:
```java
@Service
public class PropertyService {
    @Cacheable(value = "property", key = "#id")
    public PropertyDTO getProperty(Long id) { ... }

    @CacheEvict(value = "property", key = "#id")
    public void updateProperty(Long id, PropertyRequest request) { ... }

    @CacheEvict(value = "property:search", allEntries = true)
    public void createProperty(PropertyRequest request) {
        // Invalidate all search caches since results may change
    }
}
```

**TTL Strategy**:
- Property details: 1 hour TTL (changes infrequently)
- Search results: 5 minutes TTL (needs freshness)
- Customer matches: 10 minutes TTL (computation-heavy, tolerate slight staleness)

**Fallback Policy**:
- If Redis is unavailable, log warning and fetch from DB (cache-aside pattern)
- Do NOT fail requests due to cache unavailability

## Minor Improvements

### I1. Consider Introducing Domain Events for Decoupling

**Observation**: When `PropertyManagementService` updates contract status, it also handles notifications and statistics updates (Section 3.2). This creates temporal coupling.

**Suggestion**: Use Spring Application Events to decouple:
```java
@Service
public class ContractService {
    private final ApplicationEventPublisher eventPublisher;

    public void updateContractStatus(Long contractId, String status) {
        // Update contract
        eventPublisher.publishEvent(new ContractStatusChangedEvent(contractId, status));
    }
}

@Component
public class ContractNotificationListener {
    @EventListener
    public void handleContractStatusChanged(ContractStatusChangedEvent event) {
        notificationService.sendContractNotification(event);
    }
}

@Component
public class ContractStatisticsListener {
    @EventListener
    public void handleContractStatusChanged(ContractStatusChangedEvent event) {
        statisticsService.updateContractStats(event);
    }
}
```

This improves testability and allows adding new listeners (e.g., audit logging) without modifying contract service.

### I2. Consider Adding Health Check Endpoints

**Observation**: Section 2.3 mentions CloudWatch monitoring but no health check endpoint design.

**Suggestion**: Implement Spring Boot Actuator health checks:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info
  health:
    db:
      enabled: true
    redis:
      enabled: true
```

Create custom health indicators for Elasticsearch and external APIs to enable proactive monitoring and load balancer health checks.

## Positive Aspects

1. **Clear Technology Stack**: Well-defined choices (Spring Boot, PostgreSQL, Redis, Elasticsearch) with appropriate versions
2. **Test Coverage Goal**: 80% coverage target is specified with concrete testing frameworks
3. **Security Basics**: HTTPS, JWT authentication, SQL injection prevention, and XSS/CSRF countermeasures are mentioned
4. **CI/CD Pipeline**: GitHub Actions with automated deployment and Blue-Green deployment strategy
5. **Comprehensive Documentation**: Clear structure covering architecture, data models, APIs, and operational concerns

## Summary

The RealEstateHub design document provides a solid foundation but has critical structural issues that will impede maintainability and testability if not addressed:

**Must Fix (Critical)**:
- Decompose `PropertyManagementService` into focused services (C1)
- Introduce dependency injection design and abstract external dependencies (C2)
- Fix RESTful API violations to follow HTTP semantics properly (C3)

**Should Fix (Significant)**:
- Separate domain models from DTOs to prevent API-DB coupling (S1)
- Design application-level error taxonomy and propagation strategy (S2)
- Add referential integrity constraints and normalize data model (S3)
- Define API versioning and backward compatibility strategy (S4)

**Consider (Moderate)**:
- Implement configuration management for multi-environment deployment (M1)
- Add distributed tracing and structured logging (M2)
- Introduce strategy patterns for matching and notifications (M3)
- Expand test strategy with specific tooling and approaches (M4)
- Define cache invalidation strategy and policies (M5)

Addressing these structural issues now will significantly reduce technical debt and refactoring costs as the system evolves.
