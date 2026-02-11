# Structural Quality Design Review - Smart Building Management System

## Step 1: Structure Analysis

The system follows a 4-layer architecture:

- **Presentation Layer**: REST API Controller + WebSocket Handler for real-time data distribution
- **Application Layer**: Service classes (BuildingService, DeviceService, SensorDataService, AlertService, AnalyticsService)
- **Domain Layer**: Entities (Building, Device, SensorData, Alert, Tenant) + Repository Interfaces
- **Infrastructure Layer**: JPA Repository implementations, Kafka Producer/Consumer, Redis Cache, External API clients
- **Key Integration Points**: Kafka for event streaming, TimescaleDB for time-series data, Redis for caching, External APIs (weather, AI prediction model)

## Step 2: Issue Detection

### Critical Issues

#### 1. BuildingService Violates Single Responsibility Principle (SRP)

**Issue**: BuildingService has multiple responsibilities aggregated into a single service class:
- Sensor data aggregation
- Anomaly detection
- Control instruction generation
- External API calls (weather API, AI prediction API)
- Transaction boundary management

**Impact**: This creates a god class that is difficult to test, maintain, and evolve. Changes to any one aspect (e.g., anomaly detection logic) risk affecting unrelated functionality. The class will have high coupling with multiple external systems and will be difficult to mock for unit testing.

**Improvement**: Apply SRP by decomposing BuildingService into focused services:
- `BuildingManagementService` - core building entity CRUD operations
- `SensorDataAggregationService` - sensor data aggregation logic
- `AnomalyDetectionService` - anomaly detection rules and evaluation
- `ControlInstructionService` - control instruction generation
- `ExternalIntegrationService` - orchestrates external API calls

Each service should have a single reason to change.

**Reference**: Section 3.2 "BuildingService" - lists 5 distinct responsibilities

---

#### 2. Missing Abstraction for External API Dependencies

**Issue**: The design mentions direct calls to "External API Client (気象API, 予測モデルAPI)" without defining abstraction interfaces. This creates tight coupling to specific external API implementations.

**Impact**:
- Impossible to unit test BuildingService without hitting real external APIs
- Cannot swap weather API providers without modifying service code
- Cannot implement fallback strategies or mock responses for testing
- Violates Dependency Inversion Principle (DIP) - high-level modules depend on low-level implementation details

**Improvement**: Define abstraction interfaces:
```java
public interface WeatherDataProvider {
    WeatherForecast getForecast(Location location);
}

public interface PredictionModelClient {
    ControlRecommendation predict(SensorContext context);
}
```

Inject these interfaces into service classes. Provide production implementations (e.g., `OpenWeatherMapClient`, `TensorFlowPredictionClient`) and test implementations (e.g., `MockWeatherProvider`).

**Reference**: Section 3.2 "BuildingService" and Section 3.1 Infrastructure Layer

---

#### 3. Missing Error Classification and Propagation Strategy

**Issue**: The design mentions generic custom exceptions (`ResourceNotFoundException`, `InvalidOperationException`) but lacks:
- Domain-specific error taxonomy (e.g., `SensorDataValidationException`, `DeviceControlFailureException`, `ExternalApiTimeoutException`)
- Distinction between retryable vs non-retryable errors
- Error propagation policy across architectural layers
- Recovery strategies for different error categories

**Impact**:
- Generic exceptions lose context about the actual failure domain
- Clients cannot make informed retry decisions
- Difficult to implement circuit breaker fallback logic correctly
- No guidance for handling partial failures (e.g., 1 out of 10 devices fails to respond)

**Improvement**: Define a structured error hierarchy:
```
ApplicationException (abstract base)
├── RetryableException (network timeouts, temporary service unavailability)
│   ├── ExternalApiTimeoutException
│   └── TemporaryResourceUnavailableException
└── NonRetryableException (validation errors, business rule violations)
    ├── SensorDataValidationException
    ├── InvalidControlOperationException
    └── ResourceNotFoundException
```

Document error handling policy per layer:
- **Presentation Layer**: Convert exceptions to appropriate HTTP status codes (400, 404, 500, 503)
- **Application Layer**: Catch infrastructure exceptions, apply retry/circuit breaker policies, throw domain exceptions
- **Infrastructure Layer**: Throw technical exceptions with root cause details

**Reference**: Section 6.1 "エラーハンドリング方針"

---

#### 4. Circular Dependency Risk Between Services

**Issue**: The architecture shows multiple service classes (BuildingService, DeviceService, SensorDataService, AlertService, AnalyticsService) in the same Application Layer without defining clear dependency directions or interaction contracts.

**Impact**:
- Risk of circular dependencies (e.g., BuildingService calls AlertService, AlertService calls BuildingService to fetch context)
- Unclear transaction boundaries when services call each other
- Difficult to understand data flow and change impact scope
- Prevents modular deployment and testability

**Improvement**:
- Define explicit dependency hierarchy: `Controller → Orchestration Services → Domain Services → Repositories`
- Apply Dependency Inversion: Services should depend on domain events or interfaces, not directly on other services
- Consider event-driven integration: Services publish domain events to Kafka, other services consume asynchronously
- Example: Instead of `AlertService` calling `BuildingService.getBuildingContext()`, publish `SensorAnomalyDetectedEvent` to Kafka, and let `NotificationService` consume it

**Reference**: Section 3.1 "Application Layer" and Section 3.3 "データフロー"

---

### Significant Issues

#### 5. Missing DTO/Entity Separation

**Issue**: The design does not explicitly separate DTOs (Data Transfer Objects) from Domain Entities. Section 3.2 mentions "DTO変換" but doesn't define DTO classes or conversion boundaries.

**Impact**:
- Risk of exposing JPA entities directly to REST API clients, causing Jackson serialization issues (lazy loading, infinite recursion)
- Cannot evolve internal domain model without breaking API contracts
- Public API structure leaks internal database schema details
- Difficult to apply API versioning

**Improvement**:
- Define explicit DTO classes for each API endpoint (e.g., `BuildingResponse`, `CreateBuildingRequest`, `SensorDataResponse`)
- Introduce a dedicated DTO Mapper layer (manual or using MapStruct)
- Enforce rule: Entities never leave the Application/Domain layer boundary
- DTOs should only contain data required by the API contract, not full entity relationships

**Reference**: Section 3.2 "BuildingManagementController" mentions "DTO変換" but no details

---

#### 6. No Strategy for Long-Running Operations

**Issue**: The design includes potentially long-running operations (e.g., bulk control instructions across hundreds of devices, report generation for large time ranges) but does not define asynchronous execution strategy or job management.

**Impact**:
- Synchronous API calls may timeout or block threads
- No way to track progress or cancel in-flight operations
- Poor user experience for batch operations

**Improvement**:
- Introduce async job pattern for long-running operations:
  - Return `202 Accepted` with job ID immediately
  - Provide `GET /jobs/{id}` endpoint to poll status
  - Store job state in Redis or database
- Consider Spring's `@Async` for simple cases or dedicated job queue (e.g., AWS SQS + worker) for complex workflows
- Define timeout policies and cancellation mechanisms

**Reference**: Section 5.2 エンドポイント一覧 (no async endpoints)

---

#### 7. Inadequate State Management Design for Device Control

**Issue**: The design mentions storing control history in PostgreSQL but does not specify:
- How to handle concurrent control requests to the same device
- Whether devices have state machines (e.g., IDLE → PENDING → ACTIVE → COMPLETED)
- How to track control command execution status (sent, acknowledged, completed, failed)
- How to prevent conflicting control instructions

**Impact**:
- Race conditions when multiple users send control commands simultaneously
- No idempotency guarantee for control API (retrying `PUT /devices/{id}/control` may send duplicate commands)
- Cannot distinguish between "command sent" and "command executed"
- Difficult to implement audit trails and compliance requirements

**Improvement**:
- Introduce `ControlCommand` entity with state machine:
  - States: PENDING → IN_PROGRESS → COMPLETED / FAILED / TIMEOUT
  - Include `idempotency_key` field for deduplication
- Implement optimistic locking on Device entity to prevent concurrent control conflicts
- Add `GET /control-commands/{id}` endpoint to query command execution status
- Store command history separately from device state for audit purposes

**Reference**: Section 3.3 "制御指示フロー" lacks state management details

---

#### 8. Missing Versioning Strategy for APIs and Schemas

**Issue**: The API design (Section 5.2) does not include versioning strategy. All endpoints lack version prefixes (e.g., `/v1/buildings`).

**Impact**:
- Cannot evolve API contracts without breaking existing clients
- No backward compatibility guarantees
- Difficult to deprecate old endpoints gracefully
- Mobile app updates (Flutter) cannot coexist with multiple backend API versions

**Improvement**:
- Adopt URL-based versioning: `/api/v1/buildings`, `/api/v2/buildings`
- Define deprecation policy: maintain N-1 versions for 6 months
- Document breaking vs non-breaking changes policy:
  - Adding optional fields = non-breaking
  - Removing fields, changing field types = breaking (requires new version)
- Include `API-Version` response header to indicate active version

**Reference**: Section 5.2 "エンドポイント一覧" and Section 5.3 show no versioning

---

### Moderate Issues

#### 9. No Explicit Dependency Injection Configuration Strategy

**Issue**: The design mentions Spring Boot but does not specify dependency injection strategy (constructor injection vs field injection), scoping (singleton vs prototype), or how to manage configuration for multiple environments.

**Impact**:
- Inconsistent DI patterns lead to difficult-to-test code
- Field injection prevents immutability and makes dependencies implicit
- No guidance for managing environment-specific beans (e.g., mock external API clients in development)

**Improvement**:
- Standardize on constructor injection for mandatory dependencies
- Use `@RequiredArgsConstructor` (Lombok) + `final` fields to enforce immutability
- Define Spring profiles for environment differentiation: `dev`, `staging`, `prod`
- Use `@ConditionalOnProperty` to conditionally enable external API clients vs mocks

**Reference**: Section 6 lacks DI design details

---

#### 10. Insufficient Logging Design for Distributed Tracing

**Issue**: The logging design (Section 6.2) mentions storing request ID in MDC but does not specify:
- How to propagate trace context across Kafka messages
- How to correlate logs across WebSocket connections
- Whether distributed tracing (e.g., AWS X-Ray, Zipkin) is adopted

**Impact**:
- Cannot trace end-to-end data flow from IoT device → Kafka → Service → Database
- Difficult to debug issues involving multiple microservices or async processing
- No visibility into Kafka consumer lag or processing latency

**Improvement**:
- Integrate AWS X-Ray SDK or Spring Cloud Sleuth for distributed tracing
- Propagate trace ID in Kafka message headers
- Include trace ID in WebSocket handshake and subsequent frames
- Add trace ID to all structured logs
- Log Kafka consumer offsets and processing time per message

**Reference**: Section 6.2 "ロギング方針"

---

#### 11. Missing Test Data Management Strategy

**Issue**: The test strategy (Section 6.3) mentions Testcontainers but does not define:
- How to seed test data for integration tests
- How to manage test database schema migrations
- How to handle time-series data in TimescaleDB tests

**Impact**:
- Integration tests become flaky due to inconsistent test data
- Difficult to test time-based queries (e.g., "get sensor data for last 24 hours")
- No reusable test data fixtures for common scenarios

**Improvement**:
- Create test data builders (e.g., `BuildingTestDataBuilder`, `SensorDataTestDataBuilder`)
- Use Flyway test migrations in `src/test/resources/db/migration`
- Introduce time abstraction (`Clock` interface) to control time in tests
- Define test fixtures for common scenarios (e.g., "building with 3 floors, 10 devices, 1 hour of sensor data")

**Reference**: Section 6.3 "テスト方針"

---

#### 12. No Strategy for Configuration Management Across Environments

**Issue**: The design mentions "Spring Cloud Config" but does not specify:
- Where configuration is stored (Git repo, AWS Parameter Store, local files)
- How secrets are managed (database passwords, JWT signing keys, external API credentials)
- How configuration changes are applied (requires restart vs dynamic refresh)

**Impact**:
- Risk of committing secrets to Git
- No audit trail for configuration changes
- Difficult to manage environment-specific settings (e.g., different Kafka brokers per environment)

**Improvement**:
- Store non-secret config in Spring Cloud Config Server (Git-backed)
- Store secrets in AWS Secrets Manager, retrieve via Spring Cloud AWS
- Use `@RefreshScope` for beans that should reload on configuration change
- Document which settings require application restart vs dynamic refresh

**Reference**: Section 2.1 mentions "Spring Cloud Config" without details

---

#### 13. Missing Idempotency Design for Kafka Consumers

**Issue**: SensorDataCollector (Kafka Consumer) processes messages but the design does not specify:
- How to handle duplicate messages (Kafka at-least-once delivery)
- Whether TimescaleDB inserts are idempotent
- How to recover from partial failures (e.g., inserted to TimescaleDB but Redis write failed)

**Impact**:
- Risk of duplicate sensor data records
- Inconsistent state between TimescaleDB and Redis
- Difficult to implement exactly-once processing semantics

**Improvement**:
- Use composite primary key in SensorData table (`time`, `device_id`, `metric_type`) to enforce uniqueness
- Implement idempotent insert logic: `INSERT ... ON CONFLICT DO NOTHING`
- Wrap TimescaleDB + Redis writes in a local transaction (using Spring `@Transactional` + Redis transaction)
- Store Kafka offset in same transaction to ensure exactly-once semantics
- Consider using Kafka transactions (`enable.idempotence=true`)

**Reference**: Section 3.3 "センサーデータ収集フロー"

---

### Minor Issues and Observations

#### 14. GlobalExceptionHandler Design Should Define Standard Error Response Format

**Issue**: Section 6.1 mentions `GlobalExceptionHandler` but does not define the error response schema.

**Improvement**: Define a standard error response DTO:
```json
{
  "error_code": "DEVICE_NOT_FOUND",
  "message": "Device with ID 123 not found",
  "timestamp": "2026-02-11T10:00:00Z",
  "request_id": "abc-123",
  "details": { "device_id": 123 }
}
```

**Reference**: Section 6.1

---

#### 15. Positive Aspect: Clear Layer Separation

The 4-layer architecture (Presentation, Application, Domain, Infrastructure) follows standard architectural patterns and provides clear separation of concerns. This is a solid foundation for maintainability.

---

#### 16. Positive Aspect: Appropriate Technology Choices

The selection of TimescaleDB for time-series data, Kafka for event streaming, and Redis for caching aligns well with the functional requirements (high-throughput sensor data ingestion, real-time processing).

---

## Summary

**Critical Issues** (4 items):
1. BuildingService violates SRP (god class)
2. Missing abstraction for external API dependencies (violates DIP)
3. Missing error classification and propagation strategy
4. Circular dependency risk between services

**Significant Issues** (4 items):
5. Missing DTO/Entity separation
6. No strategy for long-running operations
7. Inadequate state management for device control
8. Missing API versioning strategy

**Moderate Issues** (6 items):
9. No explicit DI configuration strategy
10. Insufficient logging design for distributed tracing
11. Missing test data management strategy
12. No configuration management strategy
13. Missing idempotency design for Kafka consumers
14. GlobalExceptionHandler lacks standard error format

**Positive Aspects**:
- Clear 4-layer architecture
- Appropriate technology stack for requirements

The design demonstrates a reasonable understanding of domain requirements and technology choices, but lacks sufficient detail in structural design principles (SOLID, error handling, state management, API evolution). Addressing the critical issues (especially service decomposition and dependency abstraction) will significantly improve maintainability and testability.
