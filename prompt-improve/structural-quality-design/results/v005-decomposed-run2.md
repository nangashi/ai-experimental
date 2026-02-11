# Structural Quality Review - RealEstateHub システム設計書

## Step 1: Structure Analysis Summary

- **Architecture**: Three-tier architecture (Frontend React, Backend Spring Boot, Data Layer with PostgreSQL/Redis/Elasticsearch)
- **Key Components**: PropertyManagementService (centralized multi-responsibility service), CustomerManagementService, NotificationService
- **Design Decisions**: Direct repository dependency injection via @Autowired, no domain/DTO separation, direct infrastructure client usage, no DI abstraction for external services
- **Integration Points**: REST API boundary, direct database access via Spring Data JPA, direct Redis/Elasticsearch template usage, hardcoded SMTP/SMS credentials in NotificationService
- **Technology Choices**: Spring Boot 3.2, PostgreSQL 15 primary DB, Redis cache, Elasticsearch for search, JWT authentication via cookies

## Step 2: Issue Detection (All Criteria)

**SOLID Principles & Structural Design:**
- PropertyManagementService violates Single Responsibility Principle (handles property CRUD, customer matching, appointment scheduling, contract management, statistics)
- Direct dependency on concrete infrastructure clients (ElasticsearchTemplate, RedisTemplate) violates Dependency Inversion Principle
- Field injection via @Autowired instead of constructor injection
- No interfaces defined for service layer (tight coupling)
- Circular dependency risk between PropertyManagementService and multiple repositories

**Changeability & Module Design:**
- Domain entities used directly as API response (no DTO separation mentioned for entities)
- Implementation details leaked through direct template exposure
- No module boundaries defined (all services in flat structure)
- Stateful NotificationService with hardcoded credentials (mutable global state risk)
- Owner information embedded in Property entity (non-normalized design)

**Extensibility & Operational Design:**
- No strategy/plugin pattern for notification channels (email/SMS logic hardcoded)
- No abstraction for matching algorithm (embedded in PropertyManagementService)
- Configuration management strategy undefined (SMTP host, API keys hardcoded)
- No environment differentiation strategy for credentials
- No design for adding new property types or matching algorithms without modifying existing code

**Error Handling & Observability:**
- No domain exception taxonomy defined (only generic 400/404/500 HTTP status codes)
- No error code design or error classification
- No distinction between retryable/non-retryable errors
- No structured logging policy (only default Logback with log levels)
- No distributed tracing design mentioned (CloudWatch + Datadog mentioned but no context propagation strategy)
- No application-level error propagation strategy across service layers

**Test Design & Testability:**
- No dependency injection abstraction for external services (SMTP, SMS, Elasticsearch)
- Field injection prevents constructor-based test double injection
- Direct infrastructure client usage makes unit testing difficult
- No test strategy for notification delivery verification
- No mock/stub strategy for Elasticsearch and Redis

**API & Data Model Quality:**
- RESTful principle violations: non-resource-oriented endpoints (`/properties/create` instead of `POST /properties`, `/properties/delete/{id}` instead of `DELETE /properties/{id}`)
- Action-based URLs (`/match-customers`, `/update`, `/create`) instead of resource representations
- No API versioning strategy defined
- No schema evolution strategy for database or API contracts
- No foreign key constraints (data integrity delegated to application layer without clear strategy)
- Embedded attributes (owner info in properties, preferences in customers) prevent normalization
- No data type validation strategy or constraint enforcement at schema level

---

## Detailed Findings (Prioritized by Severity)

### Critical Issues

#### C1. Single Responsibility Principle Violation in PropertyManagementService

**Description**: PropertyManagementService handles property CRUD operations, customer matching logic, appointment availability calculation, contract status updates, and statistics aggregation. This creates a god-class anti-pattern with at least 5 distinct responsibilities, each with different change drivers.

**Impact**:
- Any change to matching algorithm, appointment logic, or statistics requires modifying this central service
- High risk of merge conflicts in team development
- Difficult to test individual responsibilities in isolation
- Impossible to scale or optimize individual concerns independently
- Violates Open-Closed Principle (cannot extend behavior without modification)

**Recommendation**:
Decompose into separate services with single responsibilities:
```java
@Service
public class PropertyService {
    // Only property CRUD operations
}

@Service
public class PropertyMatchingService {
    // Only matching logic
}

@Service
public class AppointmentSchedulingService {
    // Only appointment management
}

@Service
public class ContractManagementService {
    // Only contract operations
}

@Service
public class PropertyStatisticsService {
    // Only statistics aggregation
}
```

**References**: Section 3.2, lines 64-94

---

#### C2. RESTful API Design Violations

**Description**: API endpoints use action-based URLs instead of resource-oriented design:
- `/properties/create` instead of `POST /properties`
- `/properties/update/{id}` instead of `PUT /properties/{id}`
- `/properties/delete/{id}` instead of `DELETE /properties/{id}`
- `/properties/{id}/match-customers` (action in URL)
- `/contracts/status/{id}` (partial resource update without clear semantics)

**Impact**:
- Non-standard API design increases learning curve for API consumers
- HTTP method semantics (GET/POST/PUT/DELETE) not properly utilized
- Caching strategies based on HTTP methods cannot be applied
- Violates REST constraint of uniform interface
- Difficult to apply standard REST tooling and middleware

**Recommendation**:
Redesign to resource-oriented endpoints:
```
POST   /properties              (create)
PUT    /properties/{id}         (full update)
PATCH  /properties/{id}         (partial update)
DELETE /properties/{id}         (delete)
GET    /properties?query={q}    (search)
POST   /properties/{id}/matches (trigger matching as sub-resource)
PATCH  /contracts/{id}          (with {"status": "..."} in body)
```

**References**: Section 5.1, lines 212-233

---

#### C3. No Dependency Injection Abstraction for External Services

**Description**: NotificationService directly constructs SMTP connections and SMS API calls with hardcoded credentials. Elasticsearch and Redis clients are injected as concrete template classes without abstraction interfaces.

```java
public class NotificationService {
    private final String smtpHost = "smtp.example.com";
    private final String smsApiKey = "sk_live_12345";

    public void sendEmail(String to, String subject, String body) {
        // Direct SMTP connection
    }
}
```

**Impact**:
- Impossible to unit test notification logic without actual SMTP/SMS infrastructure
- Cannot mock external dependencies in tests
- Hardcoded credentials prevent environment-specific configuration
- Violates Dependency Inversion Principle (high-level policy depends on low-level details)
- Credentials exposure in source code (security risk)

**Recommendation**:
Introduce abstraction interfaces and externalize configuration:
```java
public interface EmailSender {
    void send(String to, String subject, String body);
}

public interface SmsSender {
    void send(String phoneNumber, String message);
}

@Service
public class NotificationService {
    private final EmailSender emailSender;
    private final SmsSender smsSender;

    @Autowired
    public NotificationService(EmailSender emailSender, SmsSender smsSender) {
        this.emailSender = emailSender;
        this.smsSender = smsSender;
    }
}

// Configuration externalized to application.yml
@ConfigurationProperties(prefix = "notification")
public class NotificationConfig {
    private String smtpHost;
    private String smsApiKey;
}
```

**References**: Section 3.2, lines 110-126

---

#### C4. No Domain Exception Taxonomy and Error Classification

**Description**: Error handling design only specifies HTTP status codes (400, 404, 500) and "user-friendly messages" without defining application-level exception hierarchy, error codes, or classification of retryable vs non-retryable errors.

**Impact**:
- Cannot implement sophisticated retry logic (which errors are transient?)
- No machine-readable error codes for client error handling
- Mixing domain errors (business rule violations) with technical errors (DB connection failure)
- Cannot implement error-specific recovery strategies
- Difficult to monitor and alert on specific error categories

**Recommendation**:
Define domain exception taxonomy and error code strategy:
```java
// Base exception with error code
public abstract class RealEstateHubException extends RuntimeException {
    private final String errorCode;
    private final boolean retryable;

    protected RealEstateHubException(String errorCode, String message, boolean retryable) {
        super(message);
        this.errorCode = errorCode;
        this.retryable = retryable;
    }
}

// Domain exceptions (non-retryable)
public class PropertyNotFoundException extends RealEstateHubException {
    public PropertyNotFoundException(Long propertyId) {
        super("PROPERTY_NOT_FOUND", "Property " + propertyId + " not found", false);
    }
}

public class InvalidPriceException extends RealEstateHubException {
    public InvalidPriceException(String reason) {
        super("INVALID_PRICE", reason, false);
    }
}

// Infrastructure exceptions (retryable)
public class DatabaseConnectionException extends RealEstateHubException {
    public DatabaseConnectionException(Throwable cause) {
        super("DB_CONNECTION_FAILED", "Database temporarily unavailable", true);
    }
}

// Error response DTO
public class ErrorResponse {
    private String errorCode;
    private String message;
    private boolean retryable;
    private String timestamp;
}
```

**References**: Section 6.1, lines 276-278

---

### Significant Issues

#### S1. Field Injection Instead of Constructor Injection

**Description**: All service classes use `@Autowired` field injection:
```java
@Service
public class PropertyManagementService {
    @Autowired
    private PropertyRepository propertyRepository;
    @Autowired
    private CustomerRepository customerRepository;
    // ... 6 dependencies
}
```

**Impact**:
- Cannot create instances for unit testing without Spring container
- Dependencies hidden from class signature (not obvious what's required)
- Immutability impossible (fields must be non-final)
- Circular dependency detection delayed until runtime
- Violates principle of making dependencies explicit

**Recommendation**:
Use constructor injection for all dependencies:
```java
@Service
public class PropertyManagementService {
    private final PropertyRepository propertyRepository;
    private final CustomerRepository customerRepository;

    @Autowired // Optional in Spring 4.3+
    public PropertyManagementService(
        PropertyRepository propertyRepository,
        CustomerRepository customerRepository
    ) {
        this.propertyRepository = propertyRepository;
        this.customerRepository = customerRepository;
    }
}
```

**References**: Section 3.2, lines 68-81

---

#### S2. No Versioning Strategy for API and Schema Evolution

**Description**: Design document states "RESTful API" but does not define:
- API versioning mechanism (URI versioning, header-based, media type versioning)
- Backward compatibility policy
- Schema evolution strategy for database changes
- Data migration strategy for breaking changes

**Impact**:
- First breaking change will force all clients to update simultaneously
- Cannot support multiple client versions (mobile app with slower update cycles)
- No strategy for deprecating old fields or endpoints
- Database schema changes will require downtime
- Difficult to coordinate releases between backend and frontend teams

**Recommendation**:
Define explicit versioning strategy:
```
API Versioning:
- Use URI versioning: /v1/properties, /v2/properties
- Maintain N-1 version support policy (support current + previous version)
- Deprecation timeline: 6 months notice before removal

Schema Evolution:
- Additive changes only (new columns nullable or with defaults)
- Breaking changes require new API version
- Dual-write strategy during migration period
- Blue-green deployment with schema compatibility checks

Example:
POST /v1/properties (deprecated)
POST /v2/properties (current)
```

**References**: Section 5, entire API design section lacks versioning

---

#### S3. No Abstraction for External Dependencies (Elasticsearch, Redis)

**Description**: Services directly depend on `ElasticsearchTemplate` and `RedisTemplate<String, Object>` without abstraction layer.

**Impact**:
- Switching search implementation requires changing service layer code
- Cannot unit test PropertyManagementService without Elasticsearch/Redis infrastructure
- Tight coupling to Spring Data Elasticsearch and Spring Data Redis
- Cannot implement fallback strategies for cache/search failures
- Difficult to mock for different test scenarios

**Recommendation**:
Introduce repository abstractions:
```java
public interface PropertySearchRepository {
    List<Property> search(SearchCriteria criteria);
    void index(Property property);
    void delete(Long propertyId);
}

public interface PropertyCacheRepository {
    Optional<Property> get(Long propertyId);
    void put(Long propertyId, Property property);
    void invalidate(Long propertyId);
}

// Elasticsearch implementation
@Repository
public class ElasticsearchPropertySearchRepository implements PropertySearchRepository {
    private final ElasticsearchTemplate template;
    // implementation
}

// Redis implementation
@Repository
public class RedisPropertyCacheRepository implements PropertyCacheRepository {
    private final RedisTemplate<String, Object> template;
    // implementation
}
```

**References**: Section 3.2, lines 78-80

---

#### S4. No Strategy Pattern for Extensible Notification Channels

**Description**: NotificationService hardcodes email and SMS logic without abstraction. Adding new channels (push notifications, LINE, Slack) requires modifying existing code.

**Impact**:
- Violates Open-Closed Principle (not open for extension, not closed for modification)
- Cannot enable/disable channels per environment or per user preference
- Cannot implement channel-specific retry policies
- Adding new notification channel requires code changes to NotificationService
- Cannot test channel logic independently

**Recommendation**:
Implement Strategy pattern for notification channels:
```java
public interface NotificationChannel {
    String getChannelType(); // "email", "sms", "push"
    void send(NotificationMessage message);
    boolean isAvailable();
}

@Service
public class NotificationService {
    private final List<NotificationChannel> channels;

    @Autowired
    public NotificationService(List<NotificationChannel> channels) {
        this.channels = channels;
    }

    public void sendNotification(NotificationRequest request) {
        channels.stream()
            .filter(channel -> request.getChannelTypes().contains(channel.getChannelType()))
            .filter(NotificationChannel::isAvailable)
            .forEach(channel -> channel.send(request.getMessage()));
    }
}

// Implementations
@Component
@ConditionalOnProperty(name = "notification.email.enabled", havingValue = "true")
public class EmailNotificationChannel implements NotificationChannel {
    // email implementation
}

@Component
@ConditionalOnProperty(name = "notification.sms.enabled", havingValue = "true")
public class SmsNotificationChannel implements NotificationChannel {
    // SMS implementation
}
```

**References**: Section 3.2, lines 110-126

---

### Moderate Issues

#### M1. No Foreign Key Constraints Delegation Strategy

**Description**: Section 4.2 states "no foreign key constraints, application layer manages data integrity" but provides no design for how this integrity will be enforced.

**Impact**:
- Orphaned records risk (appointments/contracts referencing deleted properties)
- No database-level referential integrity guarantees
- Application code must manually check existence before creating relationships
- Race conditions possible in concurrent operations
- Inconsistent data state on application bugs or crashes

**Recommendation**:
Either:
1. Add foreign key constraints at database level (preferred):
```sql
ALTER TABLE appointments ADD CONSTRAINT fk_property
    FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE;
```

Or:

2. Define explicit application-level integrity management strategy:
```java
@Service
@Transactional
public class AppointmentService {
    public Appointment createAppointment(AppointmentRequest request) {
        // Explicit existence checks
        Property property = propertyRepository.findById(request.getPropertyId())
            .orElseThrow(() -> new PropertyNotFoundException(request.getPropertyId()));
        Customer customer = customerRepository.findById(request.getCustomerId())
            .orElseThrow(() -> new CustomerNotFoundException(request.getCustomerId()));

        // Create with validated references
        return appointmentRepository.save(new Appointment(property, customer));
    }
}
```

**References**: Section 4.2, line 206

---

#### M2. Embedded Attributes Prevent Normalization

**Description**:
- `properties` table includes `owner_name` and `owner_phone` directly
- `customers` table includes `preferred_area`, `max_price`, `min_area` directly

**Impact**:
- Owner information duplicated if same owner has multiple properties
- Cannot update owner phone number across all properties atomically
- Cannot track customer preference history (only current preferences stored)
- Difficult to support multiple preference sets per customer
- Search performance degraded for complex customer matching queries

**Recommendation**:
Normalize data model:
```sql
-- Separate owner entity
CREATE TABLE property_owners (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255)
);

ALTER TABLE properties ADD COLUMN owner_id BIGINT REFERENCES property_owners(id);

-- Separate customer preferences
CREATE TABLE customer_preferences (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT REFERENCES customers(id),
    preferred_area VARCHAR(500),
    max_price DECIMAL(15, 2),
    min_area DECIMAL(10, 2),
    created_at TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);
```

This enables preference history, batch owner updates, and better query optimization.

**References**: Section 4.1, lines 141-174

---

#### M3. No Configuration Management Strategy

**Description**: Hardcoded credentials and endpoints in code. No mention of how to manage different configurations for dev/staging/prod environments.

**Impact**:
- Cannot deploy same artifact to multiple environments
- Credentials in source code risk security breach
- Cannot rotate credentials without code changes
- No strategy for sensitive data (encryption at rest, secret management)

**Recommendation**:
Define configuration management strategy:
```yaml
# application.yml
notification:
  email:
    host: ${SMTP_HOST:smtp.example.com}
  sms:
    api-key: ${SMS_API_KEY}

# Use AWS Secrets Manager or similar
@Configuration
public class NotificationConfig {
    @Bean
    public EmailSender emailSender(
        @Value("${notification.email.host}") String smtpHost,
        SecretsManagerClient secretsManager
    ) {
        String password = secretsManager.getSecret("smtp-password");
        return new SmtpEmailSender(smtpHost, password);
    }
}
```

**References**: Section 3.2, lines 116-117

---

#### M4. No Distributed Tracing Context Propagation Strategy

**Description**: Document mentions CloudWatch + Datadog for monitoring but does not define how trace context will be propagated across service layers or external calls.

**Impact**:
- Cannot correlate logs across request lifecycle
- Difficult to debug performance issues spanning multiple operations
- Cannot trace request flow through PropertyManagementService → Repository → Cache → DB
- Elasticsearch/Redis operations not associated with originating request

**Recommendation**:
Define tracing strategy using Spring Cloud Sleuth or OpenTelemetry:
```java
// Add dependency
// Spring Cloud Sleuth auto-instruments RestTemplate, WebClient, JPA, Redis

// Configure trace propagation
@Configuration
public class TracingConfig {
    @Bean
    public Tracer tracer() {
        return new DatadogTracer(...);
    }
}

// Manual span creation for business operations
@Service
public class PropertyMatchingService {
    private final Tracer tracer;

    public List<Customer> matchCustomers(Property property) {
        Span span = tracer.buildSpan("matchCustomers").start();
        try {
            // matching logic
        } finally {
            span.finish();
        }
    }
}
```

**References**: Section 2.3, line 37 (monitoring tools listed but no tracing design)

---

#### M5. No Test Strategy for External Dependencies

**Description**: Section 6.3 mentions JUnit + Mockito for service layer and TestContainers for integration tests, but provides no strategy for testing:
- Notification delivery (email/SMS)
- Elasticsearch indexing success
- Redis cache behavior
- External API failures

**Impact**:
- Cannot verify notification logic without sending real emails/SMS
- Integration tests may be flaky due to external dependencies
- Difficult to test error scenarios (Elasticsearch down, Redis connection timeout)
- Cannot test cache eviction policies

**Recommendation**:
Define test strategy for external dependencies:
```java
// Unit tests with mocked dependencies
@Test
void shouldSendEmailWhenPropertyCreated() {
    EmailSender mockEmailSender = mock(EmailSender.class);
    NotificationService service = new NotificationService(mockEmailSender, ...);

    service.notifyPropertyCreated(property);

    verify(mockEmailSender).send(eq("broker@example.com"), anyString(), anyString());
}

// Integration tests with TestContainers
@SpringBootTest
@Testcontainers
class PropertySearchIntegrationTest {
    @Container
    static ElasticsearchContainer elasticsearch = new ElasticsearchContainer(...);

    @Test
    void shouldIndexAndSearchProperty() {
        // test with real Elasticsearch container
    }
}

// Use WireMock for external API testing
@Test
void shouldHandleSmsApiFailure() {
    wireMockServer.stubFor(post("/sms/send")
        .willReturn(aResponse().withStatus(503)));

    assertThrows(SmsDeliveryException.class,
        () -> smsService.send("...", "..."));
}
```

**References**: Section 6.3, lines 286-288

---

### Minor Improvements

#### I1. No Structured Logging Policy Defined

**Description**: Only mentions "Spring Boot default logging (Logback)" with log levels per environment. No guidance on:
- What to log at each level (DEBUG, INFO, WARN, ERROR)
- Structured logging format (JSON for machine parsing)
- Contextual information to include (request ID, user ID, correlation ID)

**Recommendation**:
```java
// Use structured logging with context
@Service
public class PropertyService {
    private static final Logger log = LoggerFactory.getLogger(PropertyService.class);

    public Property createProperty(PropertyRequest request) {
        log.info("Creating property",
            kv("brokerId", request.getBrokerId()),
            kv("price", request.getPrice()),
            kv("area", request.getArea()));
        // implementation
    }
}

// Configure Logback for JSON output
<encoder class="net.logstash.logback.encoder.LogstashEncoder">
    <includeContext>true</includeContext>
    <includeMdc>true</includeMdc>
</encoder>
```

**References**: Section 6.2, lines 281-283

---

#### I2. No Explicit Layer Separation Enforcement

**Description**: Document describes "3-tier architecture" but provides no mechanism to enforce layer boundaries (controllers shouldn't access repositories directly, services shouldn't access HTTP concerns).

**Recommendation**:
Use ArchUnit or similar to enforce architectural rules:
```java
@ArchTest
static final ArchRule controllersDoNotAccessRepositories =
    noClasses().that().resideInAPackage("..controller..")
        .should().dependOnClassesThat().resideInAPackage("..repository..");

@ArchTest
static final ArchRule servicesDoNotDependOnWeb =
    noClasses().that().resideInAPackage("..service..")
        .should().dependOnClassesThat().resideInAPackage("org.springframework.web..");
```

**References**: Section 3.1, lines 49-60

---

## Summary

This design document exhibits several critical architectural flaws that will significantly impact long-term maintainability:

**Most Critical**:
1. PropertyManagementService god-class violates SRP with 5+ responsibilities
2. RESTful API design completely violates REST principles (action-based URLs)
3. No DI abstraction for external services (untestable, hardcoded credentials)
4. No domain exception taxonomy or error classification strategy

**Significant Concerns**:
5. Field injection prevents proper testing and immutability
6. No API/schema versioning strategy
7. External dependencies (Elasticsearch, Redis) tightly coupled
8. No extensibility pattern for notification channels

**Moderate Issues**:
9. No foreign key constraints without clear integrity management
10. Denormalized data model (embedded attributes)
11. No configuration management for multiple environments
12. No distributed tracing context propagation design
13. Insufficient test strategy for external dependencies

**Positive Aspects**:
- Technology stack choices are appropriate for the domain
- Blue-green deployment strategy mentioned
- TestContainers for integration tests is good practice

The design requires significant refactoring before implementation to avoid accumulating technical debt. Priority should be addressing C1-C4 (service decomposition, REST compliance, DI abstraction, error taxonomy) as these will be most difficult to fix after implementation.
