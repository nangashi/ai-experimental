# Structural Quality Design Review - Smart Building Management System

## Step 1: Structure Analysis

The system exhibits a 4-layer architecture with the following characteristics:

- **Layer organization**: Presentation (REST + WebSocket) → Application (Service classes) → Domain (Entities + Repository interfaces) → Infrastructure (JPA implementations, Kafka, Redis, External API clients)
- **Data pipeline**: Dual-path architecture with IoT sensor ingestion via Kafka → TimescaleDB/Redis storage, and control commands via REST → external device controller APIs
- **Technology boundaries**: Clear separation between time-series data store (TimescaleDB), transactional store (PostgreSQL), cache layer (Redis), and event streaming (Kafka)
- **Integration points**: External API clients for weather forecasting and AI prediction models, IoT gateway for sensor data ingestion, device controller API for command execution
- **Client interfaces**: REST API for management operations, WebSocket for real-time data push, mobile app for tenant interactions

## Step 2: Issue Detection - All Identified Problems

**SOLID & Structural:**
- BuildingService violates SRP by combining building management, sensor data aggregation, anomaly detection, control command generation, external API orchestration, and transaction management
- Circular dependency risk between Domain and Infrastructure layers (Repository interfaces in Domain, implementations in Infrastructure, but entities in Domain may reference infrastructure concerns)
- AlertManager appears to be both a domain concept and application service, blurring layer boundaries
- No clear abstraction for device controller API, external weather API, and AI prediction API - Infrastructure layer directly references concrete external systems

**Changeability & Module Design:**
- Direct exposure of entity classes in API responses (no DTO separation mentioned for outbound data)
- BuildingService directly depends on multiple external APIs without abstraction layer
- No versioning strategy mentioned for entity schema evolution (only database migration tool specified)
- State management for WebSocket connections not addressed (in-memory vs. distributed session store)
- Device control logic likely embedded in BuildingService rather than isolated in device-specific modules

**Extensibility:**
- No plugin/strategy pattern for alert rules evaluation - likely hardcoded if-else branching in AlertManager
- Device types are stored as string literals ('HVAC', 'LIGHTING') without extensibility mechanism for new device types
- No mention of feature flags or configuration-driven behavior for incremental rollout
- Alert notification channels (email, Slack, mobile push) appear to be tightly coupled without adapter pattern

**Error Handling & Observability:**
- Custom exceptions defined (ResourceNotFoundException, InvalidOperationException) but no domain exception taxonomy or error code system
- No distinction between retryable vs. non-retryable errors
- Circuit breaker only mentioned for weather API - unclear if applied consistently to all external dependencies
- Logging policy mentions INFO/DEBUG levels but no guidance on what constitutes ERROR vs. WARN
- No distributed tracing context propagation strategy mentioned (critical for Kafka async flows)
- MDC request ID propagation across Kafka consumer threads not addressed

**Testability:**
- No mention of dependency injection configuration or interface-based design for service layer
- External API clients in Infrastructure layer - unclear if properly abstracted for mocking
- Spring Boot Test + Testcontainers approach is good but lacks clarity on integration test scope
- No mention of test doubles strategy (mock vs. stub vs. fake)

**API & Data Model:**
- No API versioning strategy (URI versioning, header versioning, content negotiation)
- No backward compatibility guarantees or deprecation policy
- JWT refresh token explicitly excluded - forces re-authentication, poor UX for long-running sessions
- No pagination specification for list endpoints (GET /buildings/{id}/devices, GET /alerts)
- No rate limiting or throttling policy
- SensorData schema uses composite primary key (time, device_id, metric_type) - may cause issues with JPA entity identity and caching
- No mention of optimistic locking or concurrency control for Alert status transitions (OPEN → ACKNOWLEDGED → RESOLVED)
- Foreign key from Alert to Device is nullable but semantic relationship is unclear (building-level alerts vs. device-specific alerts)

## Detailed Analysis by Priority

### Critical Issues

#### 1. BuildingService Violates Single Responsibility Principle (SRP)

**Issue**: BuildingService is responsible for building management, sensor data aggregation, anomaly detection, control command generation, external API orchestration, and transaction management. This creates a God Object anti-pattern.

**Impact**:
- High change coupling: modifications to any one concern (e.g., alert rules) require touching a central, high-traffic service
- Difficult to test in isolation - requires mocking multiple external dependencies simultaneously
- Unclear transaction boundaries - mixing read operations (data aggregation) with write operations (control commands) in a single service
- Impossible to scale independently based on workload characteristics (read-heavy aggregation vs. write-heavy control)

**Recommendation**: Decompose BuildingService into focused services:
```java
// Building metadata management
public interface BuildingManagementService {
    Building createBuilding(BuildingRequest request);
    Building getBuilding(Long id);
}

// Sensor data query (read-only)
public interface SensorDataQueryService {
    SensorDataResponse getCurrentStatus(Long buildingId);
    List<SensorData> getHistoricalData(Long deviceId, TimeRange range);
}

// Control command orchestration (write-only)
public interface DeviceControlService {
    ControlResult executeControl(Long deviceId, ControlCommand command);
}

// AI prediction integration
public interface PredictionService {
    PredictionResult predict(Long buildingId, PredictionContext context);
}
```

Each service has a clear responsibility, independent transaction scope, and can be tested/scaled independently.

**Reference**: Section 3.2 "BuildingService" description

---

#### 2. No Abstraction for External Dependencies

**Issue**: Infrastructure layer directly references concrete external systems (weather API, AI prediction API, device controller API) without abstraction layer. BuildingService directly calls these external APIs.

**Impact**:
- Impossible to test BuildingService without hitting real external systems or using complex mocking frameworks
- Cannot switch external API providers without modifying multiple service classes
- No consistent error handling strategy across different external API failures
- Circuit breaker implementation mentioned only for weather API - inconsistent resilience patterns

**Recommendation**: Introduce port/adapter pattern (Hexagonal Architecture):
```java
// Domain layer - interface (port)
public interface WeatherForecastPort {
    WeatherData getForecast(Location location, TimeRange range);
}

// Infrastructure layer - implementation (adapter)
@Component
public class ExternalWeatherApiAdapter implements WeatherForecastPort {
    @CircuitBreaker(name = "weather-api")
    public WeatherData getForecast(Location location, TimeRange range) {
        // External API call
    }
}
```

This allows:
- Service layer to depend only on interfaces (testable with mocks/fakes)
- Consistent application of cross-cutting concerns (circuit breaker, retry, logging) via decorators
- Easy provider switching or A/B testing

**Reference**: Section 3.2 "BuildingService" and Section 6.1 "Circuit Breaker for weather API"

---

#### 3. Missing API Versioning Strategy

**Issue**: API design has no versioning mechanism despite the system's long-term nature and integration with external mobile apps and IoT gateways that cannot be instantly updated.

**Impact**:
- Cannot evolve API contracts without breaking existing clients
- Mobile app updates are asynchronous (users may delay updates) - backward incompatible API changes will break old app versions
- IoT gateway firmware updates may be difficult/risky - API must maintain compatibility
- No deprecation path for old endpoints

**Recommendation**: Implement URI-based versioning with explicit version lifecycle policy:
```
/api/v1/buildings/{id}
/api/v2/buildings/{id}  // New version with enhanced response model
```

Define policy:
- Each major version supported for minimum 12 months after next version release
- Deprecation warnings in response headers: `X-API-Deprecation: version=v1; sunset=2027-06-01`
- Version-specific DTOs to avoid leaking internal model changes
- Automated tests to ensure v1 compatibility when v2 is introduced

**Reference**: Section 5 "API設計" - no versioning strategy mentioned

---

#### 4. Lack of Domain Exception Taxonomy and Error Recovery Strategy

**Issue**: Only two custom exceptions defined (ResourceNotFoundException, InvalidOperationException) without systematic error classification. No distinction between retryable vs. non-retryable errors, no error codes for client-side handling.

**Impact**:
- Clients cannot programmatically distinguish error types (e.g., device offline vs. invalid command vs. authorization failure)
- Retry logic cannot be implemented safely - clients don't know which operations are idempotent/retryable
- Troubleshooting is difficult - no consistent error codes to search in logs or documentation
- Global exception handler maps exceptions to HTTP status codes without structured error response format

**Recommendation**: Design domain exception hierarchy with error codes:
```java
// Base domain exception with error code
public abstract class DomainException extends RuntimeException {
    private final ErrorCode errorCode;
    private final boolean retryable;
}

// Error code taxonomy
public enum ErrorCode {
    // Client errors (4xx) - non-retryable
    DEVICE_NOT_FOUND("E1001", false),
    INVALID_CONTROL_COMMAND("E1002", false),
    DEVICE_NOT_CONTROLLABLE("E1003", false),

    // Server errors (5xx) - retryable
    DEVICE_COMMUNICATION_FAILURE("E2001", true),
    EXTERNAL_API_TIMEOUT("E2002", true),
    DATABASE_UNAVAILABLE("E2003", true),
}

// Structured error response
{
  "error_code": "E1003",
  "message": "Device is in MAINTENANCE status and cannot accept control commands",
  "retryable": false,
  "timestamp": "2026-02-11T10:00:00Z",
  "request_id": "req-123"
}
```

This enables:
- Client-side retry logic based on `retryable` flag
- Consistent error documentation and support troubleshooting
- Operational metrics by error code (e.g., rate of E2001 errors indicates network issues)

**Reference**: Section 6.1 "エラーハンドリング方針"

---

### Significant Issues

#### 5. No DTO Separation for API Responses

**Issue**: Design document does not mention DTOs for outbound API responses, suggesting direct entity exposure (common anti-pattern in Spring Boot JPA projects).

**Impact**:
- Internal entity structure changes (e.g., adding bidirectional JPA relationships) break API clients
- Cannot evolve entity model without API version bump
- Risk of lazy-loading exceptions in JSON serialization
- Cannot provide different response shapes for different API versions or client types
- May expose sensitive entity metadata (e.g., internal IDs, audit timestamps)

**Recommendation**: Introduce explicit response DTOs:
```java
// Entity (internal)
@Entity
public class Building {
    @Id private Long id;
    private String name;
    private String address;
    private Integer totalFloors;
    @OneToMany private List<Device> devices;  // JPA relationship
    private Instant createdAt;
    private Instant updatedAt;
}

// Response DTO (external API contract)
public record BuildingResponse(
    Long id,
    String name,
    String address,
    Integer totalFloors,
    Instant createdAt
    // Excludes devices (separate endpoint), excludes updatedAt
) {
    public static BuildingResponse from(Building entity) { ... }
}
```

Use MapStruct or manual mapping to convert entities to DTOs in controller layer.

**Reference**: Section 5.3 "Response format" - shows entity-like JSON structures

---

#### 6. Alert Rule Engine Lacks Extensibility

**Issue**: AlertManager "evaluates alert rules" without specifying rule definition format or extensibility mechanism. Likely hardcoded if-else logic in Java code.

**Impact**:
- Adding new alert rules requires code changes, testing, and deployment
- Cannot A/B test alert rules or enable them gradually
- Business users (facility managers) cannot customize rules without engineering involvement
- Rule changes bundled with application deployments increase risk

**Recommendation**: Implement rule engine pattern with external rule definition:
```java
// Rule definition (stored in database or config file)
public class AlertRule {
    private String ruleId;
    private String deviceType;
    private String metricType;
    private String condition;  // e.g., "value > 30.0"
    private AlertSeverity severity;
    private String message;
    private boolean enabled;
}

// Rule evaluator (strategy pattern)
public interface AlertRuleEvaluator {
    boolean evaluate(SensorData data, AlertRule rule);
}

public class ThresholdEvaluator implements AlertRuleEvaluator { ... }
public class RateOfChangeEvaluator implements AlertRuleEvaluator { ... }
```

Allows:
- Runtime rule updates via admin UI
- Feature flags to enable/disable rules per building
- Easier testing of individual rules in isolation

Alternatively, consider rules-engine library (Drools, Easy Rules) if complexity grows.

**Reference**: Section 3.2 "AlertManager" and Section 3.3 "異常検知ルールを評価"

---

#### 7. Device Type Extensibility Problem

**Issue**: Device types stored as string literals ('HVAC', 'LIGHTING', 'SECURITY', 'POWER_METER') in database without enum or type registry.

**Impact**:
- Adding new device types requires database updates to existing check constraints (if any)
- No compile-time safety - typos in device type strings cause runtime errors
- Device-specific control logic likely contains switch statements on string literals
- Cannot attach device type metadata (e.g., controllable capabilities, sensor metrics) systematically

**Recommendation**: Introduce device type registry pattern:
```java
// Device type as first-class domain concept
@Entity
public class DeviceType {
    @Id private String code;  // 'HVAC', 'LIGHTING'
    private String displayName;
    private List<String> supportedMetrics;
    private boolean controllable;
}

// Reference from Device
@Entity
public class Device {
    @ManyToOne
    @JoinColumn(name = "device_type_code")
    private DeviceType deviceType;
}

// Plugin mechanism for device-specific behavior
public interface DeviceControlStrategy {
    boolean supports(DeviceType deviceType);
    ControlResult executeControl(Device device, ControlCommand command);
}

@Component
public class HvacControlStrategy implements DeviceControlStrategy {
    public boolean supports(DeviceType deviceType) {
        return "HVAC".equals(deviceType.getCode());
    }
}
```

Allows:
- New device types added via data (DeviceType table) without code deployment
- Device-specific control strategies as plugins
- Validation of control commands against device capabilities

**Reference**: Section 4.1 "Device" entity definition

---

#### 8. Missing Distributed Tracing Context Propagation

**Issue**: MDC request ID mentioned for REST API logging but no strategy for propagating trace context across asynchronous Kafka flows and WebSocket connections.

**Impact**:
- Cannot trace a single sensor data event from ingestion (Kafka consumer) → storage → anomaly detection → alert notification → WebSocket push
- Troubleshooting end-to-end latency issues is extremely difficult
- Correlation between control commands and resulting sensor data changes is manual
- Multi-service debugging requires matching timestamps and guessing event relationships

**Recommendation**: Implement distributed tracing with context propagation:
```java
// Use OpenTelemetry or Spring Cloud Sleuth
@Configuration
public class TracingConfig {
    @Bean
    public KafkaTracingHeadersPropagator kafkaTracingPropagator() {
        // Inject trace ID into Kafka message headers
    }
}

@Component
public class SensorDataCollector {
    @KafkaListener(topics = "sensor-raw-data")
    public void process(ConsumerRecord<String, SensorData> record) {
        // Extract trace context from Kafka headers
        TraceContext context = tracingPropagator.extract(record.headers());
        try (Scope scope = context.makeCurrent()) {
            // All logs and downstream calls inherit trace ID
            logger.info("Processing sensor data");  // Includes trace ID
        }
    }
}
```

Integrate with Grafana Tempo or AWS X-Ray for visualization.

**Reference**: Section 6.2 "リクエストIDをMDCに格納"

---

### Moderate Issues

#### 9. No Pagination for List Endpoints

**Issue**: List endpoints like `GET /buildings/{id}/devices` and `GET /alerts` lack pagination parameters.

**Impact**:
- Large buildings with thousands of devices will cause timeout or memory issues
- Cannot implement efficient infinite scrolling in UI
- Database queries fetch all rows without LIMIT clause

**Recommendation**: Add pagination with RFC 8288 Link headers:
```
GET /buildings/{id}/devices?page=0&size=50&sort=location,asc

Response:
{
  "content": [...],
  "page": { "number": 0, "size": 50, "totalElements": 1200, "totalPages": 24 }
}
Link: </buildings/123/devices?page=1&size=50>; rel="next"
```

**Reference**: Section 5.2 "エンドポイント一覧"

---

#### 10. SensorData Composite Primary Key and JPA Concerns

**Issue**: SensorData uses composite PK (time, device_id, metric_type) which may cause issues with JPA entity identity and caching.

**Impact**:
- JPA requires `@IdClass` or `@EmbeddedId` for composite keys - more verbose entity code
- EntityManager cache (1st-level cache) and 2nd-level cache keying becomes complex
- Equals/hashCode implementation critical for correct behavior in collections
- Hibernate may generate inefficient SQL for composite key lookups

**Recommendation**: Consider surrogate key if JPA is heavily used for time-series queries:
```sql
CREATE TABLE sensor_data (
    id BIGSERIAL PRIMARY KEY,  -- Surrogate key for JPA
    time TIMESTAMPTZ NOT NULL,
    device_id BIGINT NOT NULL,
    metric_type VARCHAR(50) NOT NULL,
    value DOUBLE PRECISION,
    UNIQUE (time, device_id, metric_type)  -- Natural key as unique constraint
);
CREATE INDEX idx_sensor_data_time_device ON sensor_data (time, device_id);
```

Alternatively, if direct SQL is used for time-series queries (recommended with TimescaleDB), keep composite PK but acknowledge JPA entity will be read-only or rarely updated.

**Reference**: Section 4.1 "SensorData" entity

---

#### 11. No Concurrency Control for Alert State Transitions

**Issue**: Alert entity has status field (OPEN → ACKNOWLEDGED → RESOLVED) but no optimistic locking or concurrency control mentioned.

**Impact**:
- Two operators acknowledging the same alert simultaneously may cause lost update
- Race condition between auto-resolution (if alert condition clears) and manual acknowledgment
- No audit trail of who changed status when

**Recommendation**: Add optimistic locking with version field:
```java
@Entity
public class Alert {
    @Id private Long id;
    @Version private Long version;  // Optimistic lock
    private AlertStatus status;
    private Long acknowledgedBy;  // User ID
    private Instant acknowledgedAt;
}
```

Application code:
```java
public void acknowledgeAlert(Long alertId, Long userId) {
    Alert alert = alertRepository.findById(alertId)
        .orElseThrow(() -> new ResourceNotFoundException());
    if (alert.getStatus() != AlertStatus.OPEN) {
        throw new InvalidOperationException("Alert already acknowledged");
    }
    alert.acknowledge(userId);  // Sets status, acknowledgedBy, acknowledgedAt
    alertRepository.save(alert);  // Will throw OptimisticLockException if version changed
}
```

**Reference**: Section 4.1 "Alert" entity

---

#### 12. JWT Refresh Token Explicitly Excluded

**Issue**: Design explicitly states "Refresh Token機能なし（期限切れ時は再ログイン）" - poor UX for 24-hour token expiry.

**Impact**:
- Users must re-authenticate daily even if actively using the system
- Mobile app background state may cause token expiry during user session
- Cannot revoke individual sessions (no session tracking)
- No distinction between "remember me" and temporary sessions

**Recommendation**: Implement refresh token with secure storage:
```
POST /auth/login
Response:
{
  "access_token": "eyJhbG...",  // 1 hour expiry
  "refresh_token": "dGhpc2lz...",  // 7 days expiry
  "expires_in": 3600
}

POST /auth/refresh
Request: { "refresh_token": "dGhpc2lz..." }
Response: { "access_token": "eyJhbG...", "expires_in": 3600 }
```

Store refresh tokens in database with user association for revocation capability.

**Reference**: Section 5.1 "Refresh Token機能なし"

---

#### 13. WebSocket Connection State Management Unclear

**Issue**: WebSocket handler mentioned for real-time data push but no specification of connection state management (in-memory vs. distributed).

**Impact**:
- Horizontal scaling of ECS Fargate tasks may break WebSocket connections (clients connect to task A, but sensor data processed by task B)
- Cannot notify all connected clients in multi-instance deployment
- No reconnection or message delivery guarantee strategy

**Recommendation**: Use Redis pub/sub for distributed WebSocket message broadcasting:
```java
@Component
public class SensorDataCollector {
    @Autowired private RedisTemplate<String, String> redisTemplate;

    public void onSensorData(SensorData data) {
        // Store data...

        // Broadcast to all WebSocket instances
        redisTemplate.convertAndSend("sensor-updates", data);
    }
}

@Component
public class WebSocketHandler {
    @Autowired private RedisMessageListenerContainer listener;

    @PostConstruct
    public void subscribe() {
        listener.addMessageListener((message, pattern) -> {
            // Forward to locally-connected WebSocket clients
        }, new ChannelTopic("sensor-updates"));
    }
}
```

**Reference**: Section 3.1 "WebSocket Handler" and Section 7.3 "ECS Fargateタスク数: 最小2"

---

### Minor Improvements

#### 14. Circuit Breaker Scope Inconsistency

**Issue**: Circuit breaker mentioned only for weather API, but AI prediction API and device controller API also require resilience patterns.

**Recommendation**: Apply consistent resilience patterns to all external dependencies:
```java
@Service
public class ExternalApiClient {
    @CircuitBreaker(name = "weather-api", fallbackMethod = "weatherFallback")
    public WeatherData getWeather(...) { ... }

    @CircuitBreaker(name = "prediction-api", fallbackMethod = "predictionFallback")
    @Retry(name = "prediction-api")
    public PredictionResult predict(...) { ... }

    @CircuitBreaker(name = "device-controller")
    @Timeout(name = "device-controller", duration = 5000)
    public ControlResult control(...) { ... }
}
```

Define fallback strategies per API type.

**Reference**: Section 6.1 "Resilience4jのCircuit Breakerでフォールバック（気象データ取得失敗時はキャッシュ値を使用）"

---

#### 15. Logging Guidance Incomplete

**Issue**: Logging policy mentions INFO/DEBUG levels but no guidance on ERROR vs. WARN usage or what information to include.

**Recommendation**: Define logging guidelines:
- **ERROR**: Unexpected exceptions requiring immediate attention (DB connection failure, external API error after retries exhausted)
- **WARN**: Recoverable issues (circuit breaker open, fallback activated, validation failure)
- **INFO**: Business events (sensor data received, device controlled, alert generated)
- **DEBUG**: Technical details (query parameters, response bodies)

Include context in structured logs:
```java
logger.info("Device controlled",
    kv("device_id", deviceId),
    kv("command", command),
    kv("user_id", userId),
    kv("request_id", MDC.get("request_id")));
```

**Reference**: Section 6.2 "ログレベル: DEBUG（開発）, INFO（本番）"

---

### Positive Aspects

- **Clear layer separation**: Presentation/Application/Domain/Infrastructure layers are well-defined
- **Appropriate technology choices**: TimescaleDB for time-series data, Kafka for event streaming, Redis for caching
- **Testing strategy**: Unit/Integration/E2E tests with Testcontainers approach is good
- **Observability foundation**: Structured logging with request ID, CloudWatch integration
- **Database migration**: Flyway for schema evolution is industry standard

---

## Summary

The design exhibits a solid foundation with appropriate technology choices and clear layer separation, but suffers from critical architectural flaws that will impede long-term maintainability:

1. **God Object anti-pattern** in BuildingService violates SRP and creates high change coupling
2. **Lack of abstraction** for external dependencies prevents testability and provider switching
3. **Missing API versioning** will block contract evolution as mobile apps and IoT gateways cannot be instantly updated
4. **Inadequate error handling taxonomy** prevents clients from implementing safe retry logic

Addressing these critical issues requires refactoring core service boundaries and introducing interface-based design before implementation begins. The moderate and minor issues can be addressed incrementally but should be prioritized before production deployment.
