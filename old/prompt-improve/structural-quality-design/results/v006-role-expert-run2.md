# Structural Quality Review - Smart Building Management System

## Step 1: Structure Analysis

The system exhibits a 4-layer architecture with the following key characteristics:

- **Layered Architecture**: Presentation (REST/WebSocket) → Application (Services) → Domain (Entities/Repositories) → Infrastructure (JPA/Kafka/Redis/External APIs)
- **Event-Driven Components**: Kafka-based sensor data ingestion with separate consumer components (SensorDataCollector, AlertManager)
- **Multi-Store Data Strategy**: PostgreSQL for transactional data, TimescaleDB for time-series sensor data, Redis for real-time caching
- **Integration Points**: External weather API, AI prediction model API, device controller API (external system), mobile apps (Flutter), web dashboard (React)
- **Technology Stack**: Spring Boot 3.2 monolith deployed on AWS ECS Fargate with managed services (RDS, ElastiCache, MSK)

## Step 2: Issue Detection - Comprehensive Findings

### Critical Issues

**C1. Service Layer Violates Single Responsibility Principle**
- BuildingService described as handling "ビル設備の統合管理ロジック", "センサーデータ集約", "異常検知", "制御指示の生成", "外部API呼び出し", "トランザクション境界の管理"
- This component has at least 6 distinct responsibilities spanning orchestration, data aggregation, anomaly detection, control logic, integration, and transaction management

**C2. Missing Domain Layer - Anemic Domain Model**
- Domain Layer lists only "Entity" and "Repository Interface" with no mention of domain services, value objects, or domain logic
- All business logic appears concentrated in Application Layer services, indicating anemic entities serving as data containers
- No evidence of domain-driven design patterns (Aggregates, Factories, Domain Events)

**C3. Undefined Error Handling Strategy for Distributed Components**
- No error classification taxonomy defined (retryable vs non-retryable errors)
- Kafka consumer error handling strategy not specified (dead letter queues, retry policies, poison message handling)
- WebSocket disconnection/reconnection error handling not addressed
- External API failures mention Circuit Breaker fallback only for weather API, but not for device controller API or AI prediction API

**C4. Layer Dependency Violation - Infrastructure Leakage**
- Application Layer services directly call "External API Client" listed in Infrastructure Layer
- No abstraction (domain interface) mentioned between Application and Infrastructure for external integrations
- Technology-specific implementations (Kafka, Redis) potentially leak into Application Layer

**C5. Missing Data Consistency Strategy Across Multi-Store Architecture**
- No saga pattern, two-phase commit, or eventual consistency strategy defined for operations spanning PostgreSQL + TimescaleDB + Redis
- Sensor data write flow (step 3: "TimescaleDB + Redis に保存") lacks transaction semantics definition
- Potential inconsistency when TimescaleDB write succeeds but Redis write fails, or vice versa

### Significant Issues

**S1. Tight Coupling Between Application Services**
- BuildingService calls DeviceService, SensorDataService, AlertService, and AnalyticsService (implied from endpoint mapping), but no dependency inversion via interfaces
- No mention of service boundaries or anti-corruption layers preventing cascading changes

**S2. Insufficient Testability Design**
- Test strategy mentions unit tests with Mockito but doesn't specify DI strategy (constructor injection vs field injection)
- No mention of repository abstractions for external dependencies (weather API, AI model API, device controller API)
- Integration tests use Testcontainers for infrastructure, but no strategy for mocking external third-party APIs

**S3. State Management Not Designed**
- No discussion of stateful vs stateless service design
- WebSocket session state management strategy undefined
- Potential Singleton anti-pattern risk: Redis Cache Manager, Kafka Producer/Consumer lifecycle not specified

**S4. Missing API Versioning and Backward Compatibility Strategy**
- No versioning scheme in API endpoints (no /v1/, /v2/ prefix)
- No deprecation policy or compatibility guarantees defined
- Breaking changes to DTOs would force all clients to update simultaneously

**S5. Incomplete Error Propagation Design**
- Custom exceptions (ResourceNotFoundException, InvalidOperationException) lack domain error code design
- No distinction between client errors (400-level) vs server errors (500-level) in exception taxonomy
- GlobalExceptionHandler mentioned but error response schema not specified (no error code, request ID, retry guidance)

**S6. Missing Distributed Tracing Context Propagation**
- Logging section mentions "リクエストIDをMDCに格納" for synchronous requests
- No mention of trace context propagation to Kafka messages, external API calls, or WebSocket streams
- Distributed tracing tools listed (no explicit OpenTelemetry or AWS X-Ray integration mentioned beyond Prometheus/Grafana for metrics)

### Moderate Issues

**M1. Extensibility Constraints - Hardcoded Device Types and Alert Types**
- Device.device_type uses varchar enum ('HVAC', 'LIGHTING', 'SECURITY', 'POWER_METER') stored as strings
- Alert.alert_type similarly hardcoded ('DEVICE_FAILURE', 'ENERGY_SPIKE', 'COMFORT_VIOLATION')
- Adding new device/alert types requires code changes in multiple layers (validation, service logic, frontend display)
- No plugin architecture or strategy pattern for extensible device/alert type handlers

**M2. Missing Schema Evolution Strategy**
- TimescaleDB sensor data schema (metric_type varchar) may require migration when adding new sensor types
- No mention of backward-compatible schema changes, online migration strategy, or blue-green database deployment
- Flyway migrations run on app startup (blocking operation during deployment)

**M3. Insufficient Configuration Management Design**
- Spring Cloud Config mentioned in libraries but no environment differentiation strategy explained
- Externalized configuration scope not defined (feature flags, rate limits, alert thresholds, API endpoints)
- No mention of configuration versioning or rollback strategy

**M4. Missing Idempotency Design for Control Operations**
- PUT /devices/{id}/control endpoint lacks idempotency key or operation tracking mechanism
- Risk of duplicate control commands if client retries on network timeout
- Control history recording (step 3 in control flow) may not prevent duplicate device state changes

**M5. Lack of Pagination and Filtering Strategy**
- GET /buildings/{id}/devices has no pagination parameters
- GET /alerts endpoint has basic status filter but no limit/offset or cursor-based pagination
- Potential performance degradation and unbounded response size as data grows

**M6. Insufficient Observability Design for Asynchronous Flows**
- Kafka consumer lag monitoring strategy not mentioned
- No discussion of alerting on processing delays (sensor data collection → anomaly detection → alert notification latency)
- WebSocket connection metrics and health checks not addressed

### Minor Improvements

**I1. Lack of Explicit Repository Abstraction**
- Domain Layer lists "Repository Interface" but doesn't show separation from JPA implementation
- Testability would benefit from clarifying that repositories are interfaces implemented by Infrastructure Layer

**I2. Missing DTO/Entity Separation Guidance**
- API section shows JSON request/response examples but doesn't specify whether these are domain entities or separate DTOs
- Risk of leaking JPA annotations (e.g., @OneToMany, @JsonIgnore) into API contracts

**I3. Incomplete Authentication/Authorization Design**
- Role-based access control mentioned (ADMIN, TENANT_USER, MAINTENANCE) but no authorization enforcement strategy
- No discussion of method-level security annotations, aspect-oriented enforcement, or tenant data isolation

**I4. No Bulk Operation Support**
- All endpoints operate on single resources (single building, single device, single alert)
- Batch sensor data insertion or bulk device control operations may be needed for operational efficiency

### Positive Aspects

**P1. Clear Layer Separation Attempt**
- 4-layer architecture provides initial structure for separation of concerns

**P2. Appropriate Technology Choices for Use Case**
- TimescaleDB for time-series data, Kafka for event streaming, Redis for real-time caching are well-suited

**P3. Circuit Breaker Pattern for Resilience**
- Resilience4j Circuit Breaker for external weather API shows awareness of failure isolation

**P4. Structured Logging with Correlation IDs**
- Request ID in MDC and JSON structured logging enable troubleshooting in distributed context

---

## Detailed Analysis by Priority

### Priority 1: Critical Architectural Flaws

#### Issue C1: BuildingService God Object Anti-Pattern

**Problem Description:**
BuildingService violates Single Responsibility Principle by aggregating unrelated responsibilities:
1. Data aggregation ("センサーデータ集約")
2. Anomaly detection logic ("異常検知")
3. Control command generation ("制御指示の生成")
4. External API orchestration ("外部API呼び出し")
5. Transaction management ("トランザクション境界の管理")

**Impact:**
- **Unmaintainability**: Any change to anomaly detection logic requires modifying the same class handling transaction boundaries, increasing regression risk
- **Poor Testability**: Unit tests must mock all dependencies simultaneously (repositories, external APIs, alert services)
- **Team Velocity**: Multiple developers cannot work on different features concurrently without merge conflicts
- **Changeability**: Adding a new control strategy requires navigating a large, complex service class

**Recommended Improvements:**
1. Extract `AnomalyDetectionService` with responsibility limited to evaluating sensor data against detection rules
2. Extract `DeviceControlOrchestrator` responsible for validating and dispatching control commands
3. Extract `ExternalIntegrationFacade` wrapping third-party API calls with domain interfaces
4. Keep BuildingService as thin orchestration layer coordinating these specialized services
5. Apply Command pattern for control instructions to decouple generation from execution

**Reference:** Section 3.2 "BuildingService" description lists 6 distinct responsibilities

---

#### Issue C2: Anemic Domain Model - Missing Business Logic Encapsulation

**Problem Description:**
Domain Layer contains only "Entity" and "Repository Interface" with no domain services, value objects, or rich entity behaviors. All business logic resides in Application Layer services, making entities mere data containers.

**Impact:**
- **Broken Encapsulation**: Business invariants (e.g., "Device status can only transition from ACTIVE→MAINTENANCE→ACTIVE") cannot be enforced within entities, requiring all callers to duplicate validation logic
- **Scattered Domain Knowledge**: Alert escalation rules, comfort score calculation, energy consumption analysis logic all exist in application services rather than domain model
- **Difficult Testing**: Domain logic tests require instantiating entire service classes with their infrastructure dependencies
- **Impedance Mismatch**: Translation between anemic entities and DTOs provides no value, merely copies fields

**Recommended Improvements:**
1. Introduce value objects: `Temperature`, `PowerConsumption`, `FloorRange`, `AlertSeverity` with validation logic
2. Add entity methods: `Device.transitionToMaintenance()`, `Alert.acknowledge(UserId)`, `Building.isComfortableAt(Floor, Timestamp)`
3. Extract domain services for complex multi-entity operations: `EnergyOptimizationService.recommendControlStrategy(Building, WeatherForecast)`
4. Introduce domain events: `DeviceFailureDetected`, `ComfortThresholdViolated` to decouple anomaly detection from alert notification
5. Create aggregates with consistency boundaries: `Building` aggregate root managing `Device` lifecycle

**Reference:** Section 3.1 Domain Layer definition, Section 4.1 entity schemas show only data fields

---

#### Issue C3: Undefined Distributed Error Handling Strategy

**Problem Description:**
Error handling strategy only addresses synchronous REST API errors. Critical gaps exist for:
- **Kafka consumer errors**: No dead letter queue, retry policy, or poison message handling mentioned
- **Partial failure scenarios**: Sensor data write succeeds to TimescaleDB but fails to Redis - no compensation or consistency check
- **External API cascading failures**: Circuit Breaker defined only for weather API, not for device controller API (critical for control flow) or AI prediction API
- **WebSocket error handling**: No reconnection strategy, missed message recovery, or client-side buffering

**Impact:**
- **Data Loss**: Kafka consumer crash loses in-flight sensor data if offset commit strategy not defined
- **Inconsistent State**: Redis cache miss after TimescaleDB write success causes dashboard to show stale data
- **Control Failure Blindness**: Device controller API timeout leaves control command in unknown state (was it applied or not?)
- **User Experience Degradation**: WebSocket disconnection requires full page reload if no auto-reconnect

**Recommended Improvements:**
1. Define error taxonomy:
   - Retryable: Network timeouts, transient DB deadlocks, rate limit errors (429)
   - Non-retryable: Validation failures, resource not found, authentication errors
2. Kafka consumer resilience:
   - Configure dead letter topic for messages failing after N retries
   - Implement idempotent processing with deduplication key (deviceId + timestamp)
   - Use manual offset commit after successful TimescaleDB write
3. External API Circuit Breaker:
   - Apply to device controller API with fallback: log command to persistent queue, retry asynchronously
   - AI prediction API: degrade to rule-based heuristic if model unavailable
4. Multi-store write consistency:
   - Write-ahead log pattern: Persist to PostgreSQL audit table, then async flush to TimescaleDB + Redis
   - Or accept eventual consistency with background reconciliation job
5. WebSocket resilience:
   - Server-side: send heartbeat every 30s, client auto-reconnect on timeout
   - Client-side: buffer last 100 messages, resend sequence number on reconnect

**Reference:** Section 6.1 error handling, Section 3.3 data flow steps 3-4 (no error path), Section 2.4 Resilience4j only for weather API

---

#### Issue C4: Infrastructure Layer Leakage into Application Layer

**Problem Description:**
Application Layer services directly depend on Infrastructure Layer components without abstraction:
- BuildingService calls "External API Client (気象API, 予測モデルAPI)" from Infrastructure Layer
- No domain interfaces defined for Kafka Producer, Redis Cache Manager, or external integrations
- Technology choices (Kafka topic names, Redis key patterns) potentially hardcoded in service logic

**Impact:**
- **Vendor Lock-in**: Switching from Kafka to AWS Kinesis or Redis to Memcached requires changing Application Layer code
- **Difficult Unit Testing**: Cannot test BuildingService without mocking Kafka/Redis-specific classes
- **Violation of Dependency Rule**: High-level business logic depends on low-level infrastructure details (Clean Architecture violation)
- **Poor Portability**: Cannot reuse domain logic in different deployment contexts (e.g., on-premise vs cloud)

**Recommended Improvements:**
1. Define domain interfaces in Domain Layer:
   ```java
   // Domain Layer
   interface WeatherForecastProvider {
     WeatherForecast getForecast(Location location, TimeRange range);
   }
   interface EventPublisher {
     void publish(DomainEvent event);
   }
   interface SensorDataCache {
     Optional<SensorReading> getLatest(DeviceId deviceId);
   }
   ```
2. Implement adapters in Infrastructure Layer:
   ```java
   // Infrastructure Layer
   class OpenWeatherMapAdapter implements WeatherForecastProvider { ... }
   class KafkaEventPublisher implements EventPublisher { ... }
   class RedisSensorCache implements SensorDataCache { ... }
   ```
3. Inject via constructor in Application Layer:
   ```java
   class BuildingService {
     BuildingService(WeatherForecastProvider weather, EventPublisher events, ...) { ... }
   }
   ```
4. Use Spring profiles to bind concrete implementations: `@Profile("production")` for Redis, `@Profile("test")` for in-memory

**Reference:** Section 3.1 shows Application Layer calling Infrastructure Layer directly, Section 3.2 BuildingService responsibilities include "外部API呼び出し"

---

#### Issue C5: Missing Multi-Store Data Consistency Strategy

**Problem Description:**
Sensor data collection flow (Section 3.3 step 3) writes to both TimescaleDB and Redis without defining transactional semantics or consistency guarantees. No saga pattern, compensating transactions, or eventual consistency reconciliation mentioned.

**Impact:**
- **Data Inconsistency**: TimescaleDB write succeeds but Redis write fails → Dashboard shows stale/missing data while historical queries work
- **Anomaly Detection Failure**: Alert rules evaluate against Redis cache; if cache outdated, critical alarms may not trigger
- **Debugging Difficulty**: No audit trail of partial write failures makes troubleshooting data discrepancies hard
- **Race Conditions**: Concurrent writes from multiple Kafka consumer instances may result in inconsistent Redis cache state

**Recommended Improvements:**
1. **Option A - Eventual Consistency with Compensation**:
   - Write to TimescaleDB first (source of truth)
   - Publish `SensorDataRecorded` event to Kafka
   - Separate cache updater consumer reads event and updates Redis
   - If Redis write fails, retry with exponential backoff; log to monitoring if retry exhausted
2. **Option B - Transactional Outbox Pattern**:
   - Single database transaction: Write sensor data + outbox event to PostgreSQL
   - Outbox processor reads events and updates TimescaleDB + Redis asynchronously
   - Guarantees at-least-once delivery with idempotent handling
3. **Option C - Accept Read Inconsistency, Add Cache-Aside**:
   - Write only to TimescaleDB synchronously
   - Update Redis cache asynchronously (best-effort)
   - Dashboard query falls back to TimescaleDB if Redis cache miss (slower but consistent)
4. **Monitoring & Reconciliation**:
   - Track Redis write failure rate in Prometheus
   - Daily reconciliation job: Compare TimescaleDB vs Redis for last 24h, repair mismatches
   - Include data consistency SLI in operational metrics

**Reference:** Section 3.3 "センサーデータ収集フロー" step 3, no consistency strategy in Section 6 implementation policies

---

### Priority 2: Significant Structural Issues

#### Issue S1: Tightly Coupled Application Services - No Dependency Inversion

**Problem Description:**
Service-to-service dependencies (BuildingService → AlertService, DeviceService, SensorDataService, AnalyticsService) appear to be concrete class dependencies with no interface abstraction mentioned.

**Impact:**
- **Circular Dependency Risk**: If AnalyticsService later needs BuildingService, creates circular reference
- **Cascading Changes**: Interface changes in AlertService force recompilation and retesting of BuildingService
- **Difficult Substitution**: Cannot replace AlertService with MockAlertService in integration tests without Spring test context
- **Deployment Coupling**: Cannot deploy AlertService improvements independently if BuildingService depends on new methods

**Recommended Improvements:**
1. Define service interfaces in Application Layer:
   ```java
   interface AlertingService {
     void raiseAlert(Alert alert);
   }
   interface DeviceControlService {
     void sendControlCommand(DeviceId id, ControlCommand command);
   }
   ```
2. Implement with concrete classes: `DefaultAlertingService implements AlertingService`
3. Inject via constructor: `BuildingService(AlertingService alerting, DeviceControlService control, ...)`
4. Consider event-based decoupling: `BuildingService` publishes `AnomalyDetectedEvent`, `AlertService` subscribes and handles notification logic independently

**Reference:** Section 3.2 lists services without interfaces, Section 3.1 shows Application Layer as monolithic service classes

---

#### Issue S2: Insufficient Dependency Injection and Testability Design

**Problem Description:**
Test strategy mentions Mockito for unit tests but doesn't specify:
- Constructor injection vs field injection strategy
- How external APIs (weather, AI model, device controller) are mocked
- Whether repositories are interfaces or concrete JPA classes
- Test double strategy (mocks vs stubs vs fakes)

**Impact:**
- **Fragile Tests**: Field injection with `@Autowired` prevents constructor-based dependency mocking in plain JUnit tests (requires Spring test context even for unit tests)
- **Slow Test Execution**: If external API clients are not abstracted, every BuildingService test makes real HTTP calls or requires WireMock setup
- **Low Test Coverage**: 80% coverage goal may be achieved through integration tests only, missing fast unit tests for business logic
- **Difficult Test Data Setup**: Lack of repository abstractions means every test needs to interact with real database schemas

**Recommended Improvements:**
1. **Mandatory Constructor Injection**:
   - Declare all service dependencies in constructor (enables plain Java instantiation in tests)
   - Avoid field injection (`@Autowired` on fields) for services
2. **Repository Abstractions**:
   - Define repository interfaces in Domain Layer: `interface BuildingRepository { ... }`
   - Implement in Infrastructure Layer: `class JpaBuildingRepository implements BuildingRepository { ... }`
   - Use in-memory fake implementations for unit tests: `class InMemoryBuildingRepository implements BuildingRepository { ... }`
3. **External Dependency Test Doubles**:
   - Create `WeatherForecastProvider` interface with `StubWeatherProvider` returning fixed forecast
   - Create `DeviceControllerGateway` interface with `FakeDeviceController` tracking sent commands in memory
4. **Test Pyramid Enforcement**:
   - Unit tests (fast, isolated): 70% of tests, pure business logic with fakes
   - Integration tests (Testcontainers): 25% of tests, repository + messaging layer
   - E2E tests (Selenium): 5% of tests, critical user workflows only

**Reference:** Section 6.3 test strategy lacks DI details, Section 3.2 shows services without interface-based design

---

#### Issue S3: Stateful Component Design Not Addressed

**Problem Description:**
No discussion of:
- Whether services are stateless (request-scoped) or maintain in-memory state
- WebSocket connection session state storage (in-memory, Redis, sticky sessions)
- Kafka Consumer group coordination and partition assignment strategy
- Singleton vs prototype Spring bean scopes

**Impact:**
- **Scalability Ceiling**: If WebSocket session state is in-memory, horizontal scaling breaks (client reconnects to different ECS task, loses session)
- **Memory Leaks**: Unbounded in-memory caching (e.g., "recent sensor readings") in services causes OutOfMemoryError under load
- **Concurrency Bugs**: Shared mutable state in @Service beans (e.g., static Map) causes race conditions in multi-threaded request handling
- **Kafka Consumer Imbalance**: If consumers maintain local state, partition rebalancing causes state loss

**Recommended Improvements:**
1. **Enforce Stateless Services**:
   - All `@Service` beans must be stateless (no instance fields except injected dependencies)
   - Code review checklist: "Does this service have any mutable fields?"
2. **Externalize WebSocket Session State**:
   - Option A: Use Spring Session with Redis backend, store session attributes externally
   - Option B: Use AWS ALB sticky sessions (stickiness based on cookie) + graceful shutdown for connection draining
3. **Kafka Consumer State**:
   - Use Kafka's built-in consumer group coordination (no custom state needed)
   - If local aggregation needed (e.g., windowed metrics), use Kafka Streams state stores with changelog topics for recovery
4. **Document Bean Scopes**:
   - Explicitly annotate: `@Service @Scope("prototype")` if per-request state needed
   - Default to stateless singleton scope, document exceptions

**Reference:** Section 3.1 WebSocket Handler mentioned without session strategy, Section 3.2 services lack scope definition

---

#### Issue S4: No API Versioning Strategy - Breaking Change Risk

**Problem Description:**
API endpoints (Section 5.2) have no version prefix (e.g., `/v1/buildings`). No deprecation policy, compatibility guarantees, or migration plan for breaking changes.

**Impact:**
- **Forced Client Updates**: Renaming `total_floors` to `floor_count` requires all mobile apps and web clients to update simultaneously
- **Deployment Coordination**: Cannot deploy backend changes independently of frontend changes (tight coupling)
- **Third-Party Integration Breakage**: External systems (partner integrations, tenant custom apps) break on schema changes without notice
- **Rollback Difficulty**: If breaking change deployed, rollback requires reverting client apps too

**Recommended Improvements:**
1. **Introduce URL Versioning**:
   - Prefix all endpoints with `/api/v1/` (e.g., `/api/v1/buildings`)
   - Commit to maintaining v1 compatibility for minimum 12 months after v2 release
2. **Define Breaking vs Non-Breaking Changes**:
   - Non-breaking (backward compatible): Adding optional fields, new endpoints, new enum values
   - Breaking (requires new version): Removing fields, renaming fields, changing field types, removing endpoints
3. **Deprecation Policy**:
   - Mark deprecated endpoints with HTTP header: `Deprecation: true`, `Sunset: 2027-01-01`
   - Return warning in response body for 6 months before removal
4. **Schema Evolution Rules**:
   - DTOs use `@JsonInclude(NON_NULL)` to allow gradual field additions
   - Clients ignore unknown fields (`@JsonIgnoreProperties(ignoreUnknown = true)`)
5. **Consider GraphQL or API Gateway**:
   - If frequent schema changes expected, GraphQL allows client-specified fields
   - AWS API Gateway can route `/v1/` and `/v2/` to different backend versions during migration

**Reference:** Section 5.2 endpoint list lacks versioning, Section 6.4 deployment mentions rollback but not API compatibility

---

#### Issue S5: Incomplete Error Response Design - No Error Codes or Retry Guidance

**Problem Description:**
Custom exceptions (`ResourceNotFoundException`, `InvalidOperationException`) lack:
- Machine-readable error codes (e.g., `DEVICE_NOT_FOUND`, `INVALID_TEMPERATURE_RANGE`)
- Correlation IDs in error responses
- Retry guidance (is this error transient or permanent?)

**Impact:**
- **Poor Client Error Handling**: Mobile app cannot distinguish between "building not found" vs "server error" without parsing error message strings
- **Difficult Debugging**: Support team investigating user-reported error has no correlation ID to search logs
- **Inefficient Retries**: Client retries "validation failed" error (permanent) wasting resources, but doesn't retry "database deadlock" (transient)
- **Internationalization Impossible**: Error messages hardcoded in English cannot be localized for Japanese/Chinese tenants

**Recommended Improvements:**
1. **Define Error Code Enum**:
   ```java
   enum ErrorCode {
     BUILDING_NOT_FOUND("E1001", "Specified building does not exist"),
     INVALID_DEVICE_TYPE("E2001", "Device type must be HVAC, LIGHTING, SECURITY, or POWER_METER"),
     DATABASE_UNAVAILABLE("E9001", "Temporary database error"),
     ...
   }
   ```
2. **Standardized Error Response Schema**:
   ```json
   {
     "error_code": "E1001",
     "message": "Specified building does not exist",
     "details": {"building_id": 999},
     "request_id": "req-abc-123",
     "retryable": false,
     "timestamp": "2026-02-11T10:30:00Z"
   }
   ```
3. **GlobalExceptionHandler Enrichment**:
   - Automatically inject `request_id` from MDC
   - Map exception types to error codes and retryable flag
   - Log full stack trace with ERROR level, return sanitized message to client
4. **Client SDK Error Handling**:
   - Provide example code for mobile/web clients: `if (error.retryable) { scheduleRetry(); } else { showUserError(); }`

**Reference:** Section 6.1 mentions custom exceptions without error code design, Section 5.3 response examples lack error schema

---

#### Issue S6: Distributed Tracing Context Propagation Missing

**Problem Description:**
Logging strategy includes request ID in MDC for synchronous REST calls, but:
- No mention of trace context propagation to Kafka messages
- External API calls (weather, AI model, device controller) may not include trace headers
- WebSocket messages lack correlation to originating request
- Cross-service trace visualization (e.g., request → BuildingService → DeviceControllerAPI → Kafka event → AlertService) not designed

**Impact:**
- **Blind Spots in Troubleshooting**: Cannot trace sensor data flow from Kafka ingestion → TimescaleDB write → anomaly detection → alert generation
- **Performance Bottleneck Identification**: Cannot identify which external API call (weather vs AI model) caused slow response
- **Alert Root Cause Analysis**: When alert notification delayed, cannot trace back to originating sensor reading
- **Operational Dashboard Gaps**: Prometheus + Grafana mentioned but no trace-based SLO dashboards (e.g., p95 latency from control command to device actuation)

**Recommended Improvements:**
1. **Adopt OpenTelemetry or AWS X-Ray**:
   - Auto-instrument Spring Boot with OpenTelemetry Java agent
   - Propagate W3C Trace Context headers to external HTTP calls
   - Inject trace context into Kafka message headers: `traceparent: 00-{trace-id}-{span-id}-01`
2. **Kafka Message Tracing**:
   - Consumer extracts trace context from headers, continues span
   - Publish child span when writing to TimescaleDB (span name: "sensor-data-write")
3. **External API Client Instrumentation**:
   - Wrap RestTemplate/WebClient with trace interceptor
   - Tag spans with `http.url`, `http.status_code`, `error` attributes
4. **WebSocket Correlation**:
   - Include `trace_id` in WebSocket message payload
   - Client-side logging includes trace ID for debugging
5. **Trace Backend**:
   - Send traces to AWS X-Ray or Jaeger
   - Create dashboard: "End-to-end control latency" (REST request → device controller response)

**Reference:** Section 6.2 logging mentions request ID but not distributed tracing, Section 2.3 lists Prometheus/Grafana for metrics only

---

### Priority 3: Moderate Extensibility and Operational Issues

#### Issue M1: Hardcoded Device and Alert Type Enums - Extensibility Constraint

**Problem Description:**
Device types ('HVAC', 'LIGHTING', 'SECURITY', 'POWER_METER') and alert types ('DEVICE_FAILURE', 'ENERGY_SPIKE', 'COMFORT_VIOLATION') stored as varchar enums in database. No plugin architecture for handling new types.

**Impact:**
- **Deployment Required for New Device Types**: Adding 'ELEVATOR' or 'WATER_METER' device type requires:
  1. Code changes in validation logic
  2. Database enum extension (if using PostgreSQL enum type)
  3. Service logic updates for device-specific handling
  4. Frontend display logic updates
- **Tenant-Specific Customization Impossible**: Cannot allow Tenant A to define custom alert types without core platform changes
- **A/B Testing Difficult**: Cannot gradually roll out new alert type to subset of buildings

**Recommended Improvements:**
1. **Strategy Pattern for Device Handlers**:
   ```java
   interface DeviceHandler {
     void handleControlCommand(Device device, ControlCommand command);
     SensorValidation validateSensorData(SensorData data);
   }
   class HvacDeviceHandler implements DeviceHandler { ... }
   class LightingDeviceHandler implements DeviceHandler { ... }
   // Registry
   Map<DeviceType, DeviceHandler> deviceHandlers;
   ```
2. **Database Enum Table**:
   - Create `device_types` table with `(id, code, display_name, handler_class)`
   - `Device.device_type_id` references this table (allows runtime additions)
3. **Plugin Architecture** (advanced):
   - Load device handlers from classpath scanning: `@DeviceTypePlugin("ELEVATOR")`
   - Allow JAR drop-in for new device types without recompilation
4. **Alert Type Configuration**:
   - Move alert types to `alert_rules` table with JSON configuration: `{"type": "TEMPERATURE_SPIKE", "threshold": 30, "window": "5m"}`
   - UI allows admin to create custom alert rules

**Reference:** Section 4.1 Device.device_type and Alert.alert_type varchar enums

---

#### Issue M2: Missing Schema Evolution and Migration Strategy

**Problem Description:**
Flyway migrations run at application startup (blocking). No strategy for:
- Online schema changes (adding column to large TimescaleDB hypertable)
- Blue-green database deployment
- Backward compatibility during rolling deployment (old app version + new schema)

**Impact:**
- **Downtime During Migration**: Adding non-null column to `sensor_data` hypertable (billions of rows) causes 10+ minute app startup delay → violates 99.5% availability SLA
- **Deployment Rollback Risk**: Deploy new app version with schema change, then rollback app but cannot rollback database migration → old app crashes on new schema
- **Zero-Downtime Deployment Impossible**: Rolling deployment starts task with new schema; old tasks still running expect old schema → connection errors

**Recommended Improvements:**
1. **Expand-Contract Migration Pattern**:
   - Phase 1 (Expand): Add new column as nullable, deploy app reading both old/new columns
   - Phase 2 (Migrate): Background job backfills new column
   - Phase 3 (Contract): Remove old column in next release
2. **Separate Migration Execution from App Startup**:
   - Run Flyway migrations in separate CI/CD step before app deployment
   - App startup validates schema version matches expected version, fails fast if mismatch
3. **Online Schema Change Tools**:
   - Use `gh-ost` or `pt-online-schema-change` for large table alterations (creates shadow table, copies rows incrementally)
4. **Hypertable-Specific Strategy**:
   - TimescaleDB: Add column only to new chunks, query handles nullable columns gracefully
   - Use partitioning strategy to limit blast radius (e.g., only migrate last 30 days of data)
5. **Schema Compatibility Matrix**:
   - Document: "App version 2.1 supports DB schema 10-12, App version 2.0 supports DB schema 9-11"
   - Ensure 1-version overlap during rolling deployment

**Reference:** Section 6.4 "Flyway（アプリ起動時に自動実行）", Section 2.1 TimescaleDB hypertable with billions of rows

---

#### Issue M3: Insufficient Externalized Configuration Strategy

**Problem Description:**
Spring Cloud Config mentioned but scope undefined:
- Which configurations are externalized (alert thresholds, API endpoints, rate limits)?
- How are feature flags managed (enable new AI model, disable email notifications)?
- Configuration versioning and rollback strategy not specified

**Impact:**
- **Slow Incident Response**: Adjusting alert threshold (e.g., energy spike from 10% to 20%) requires code change + deployment instead of config update
- **Environment Drift**: Hardcoded timeouts in code differ between dev/staging/prod, causing prod-only bugs
- **A/B Testing Infeasible**: Cannot enable new comfort optimization algorithm for 10% of buildings without code deployment
- **Ops Team Dependency**: Changing external API endpoint (weather service migration) requires engineering team instead of ops config update

**Recommended Improvements:**
1. **Define Configuration Scope**:
   - **Level 1 (Rebuild Required)**: Database connection pool size, thread pool config → application.yml
   - **Level 2 (Restart Required)**: External API endpoints, retry policies → Spring Cloud Config
   - **Level 3 (Runtime Hot-Reload)**: Alert thresholds, feature flags → Database config table with cache invalidation
2. **Feature Flag Framework**:
   - Integrate LaunchDarkly or AWS AppConfig for feature toggles
   - Example: `if (featureFlags.isEnabled("ai-prediction-v2", buildingId)) { useNewModel(); }`
3. **Configuration Versioning**:
   - Store config in Git (Spring Cloud Config backed by Git repo)
   - Tag config versions: `config-v1.2.3`
   - Deployment specifies config version (rollback reverts both app and config)
4. **Environment-Specific Overrides**:
   - Base config: `application.yml`
   - Environment overrides: `application-prod.yml`
   - Per-building overrides: Database table `building_config`
5. **Config Change Audit Trail**:
   - Log all config changes with timestamp, user, old/new value
   - Alert on sensitive config changes (e.g., JWT secret rotation)

**Reference:** Section 2.4 lists Spring Cloud Config but Section 6 lacks configuration management details

---

#### Issue M4: Missing Idempotency Design for Control Commands

**Problem Description:**
`PUT /devices/{id}/control` endpoint lacks idempotency mechanism. If client retries on timeout, duplicate control commands may be sent to physical device.

**Impact:**
- **Double Actuation**: Network timeout after sending HVAC control command, client retries → temperature setpoint changed twice (e.g., 20°C → 18°C → 16°C instead of 20°C → 18°C)
- **Control History Pollution**: Database records duplicate control events, skewing analytics
- **Safety Risk**: Emergency lighting control command retried multiple times may cause rapid on/off cycling, damaging equipment
- **Difficult Debugging**: Cannot distinguish between intentional re-control vs accidental duplicate

**Recommended Improvements:**
1. **Client-Generated Idempotency Key**:
   - Client includes `X-Idempotency-Key: {uuid}` header in request
   - Server stores key in Redis with 24h TTL: `SET control:idempotency:{key} {result} EX 86400`
   - If duplicate key received, return cached result (201 or 409 if different payload)
2. **Command ID in Request Body**:
   ```json
   {
     "command_id": "cmd-abc-123",
     "target_temperature": 22.5
   }
   ```
   - Check `control_history` table for existing command_id before execution
   - Return existing result if found
3. **Compare-and-Set Device State**:
   - Include expected current state in request: `{"expected_temperature": 20, "target_temperature": 22}`
   - Reject if actual state differs (prevents applying stale commands)
4. **Control Command Deduplication Window**:
   - Track (device_id, command_type, timestamp) in last 5 minutes
   - Reject duplicate if same device controlled with identical command within window
5. **Asynchronous Command Status**:
   - Return `202 Accepted` with command ID immediately
   - Client polls `GET /control-commands/{id}` for status: PENDING, IN_PROGRESS, COMPLETED, FAILED

**Reference:** Section 5.2 `PUT /devices/{id}/control` lacks idempotency design, Section 3.3 control flow step 3 records history but doesn't prevent duplicates

---

#### Issue M5: Missing Pagination and Query Optimization Strategy

**Problem Description:**
Endpoints like `GET /buildings/{id}/devices` and `GET /alerts` lack pagination, filtering, and projection parameters. Unbounded result sets risk performance degradation.

**Impact:**
- **Slow Response Times**: Building with 10,000 devices returns entire list → 5MB JSON response, 2s serialization time
- **Mobile App Timeout**: 3G network cannot download 5MB device list within 30s timeout
- **Database Load**: `SELECT * FROM devices WHERE building_id = ?` fetches all columns including BLOBs (device firmware metadata)
- **Client Memory Exhaustion**: React app rendering 10,000 devices in table causes browser tab crash

**Recommended Improvements:**
1. **Cursor-Based Pagination**:
   ```
   GET /buildings/{id}/devices?limit=50&cursor={opaque-token}
   Response:
   {
     "data": [...],
     "next_cursor": "eyJpZCI6MTIzfQ==",
     "has_more": true
   }
   ```
   - Advantages: Consistent results during concurrent inserts, efficient DB queries
2. **Offset-Based Pagination** (simpler alternative):
   ```
   GET /buildings/{id}/devices?limit=50&offset=100
   ```
   - Include `X-Total-Count` header for UI page count display
3. **Field Projection**:
   ```
   GET /devices/{id}?fields=id,name,status
   ```
   - Omit heavy fields (firmware_metadata, installation_photo)
4. **Rich Filtering**:
   ```
   GET /alerts?building_id=1&status=OPEN,ACKNOWLEDGED&severity=CRITICAL&created_after=2026-02-01
   ```
5. **Default Limits**:
   - Apply server-side default: `limit=50` if not specified
   - Maximum limit: 500 (reject requests exceeding this)
6. **GraphQL Alternative** (if frequent custom queries):
   - Allow clients to specify exact fields and relations needed
   - Built-in pagination with `first`/`after` arguments

**Reference:** Section 5.2 `GET /buildings/{id}/devices` and `GET /alerts` lack pagination parameters

---

#### Issue M6: Insufficient Asynchronous Processing Observability

**Problem Description:**
No observability design for:
- Kafka consumer lag (how far behind is sensor data processing?)
- End-to-end latency (sensor reading → anomaly detection → alert notification)
- WebSocket connection health and message delivery success rate

**Impact:**
- **Silent Degradation**: Kafka consumer falls 10 minutes behind due to database slowness, but monitoring doesn't alert → critical equipment failures detected too late
- **SLA Violation Blindness**: Promise "alerts within 30 seconds" but no metric tracking actual latency
- **Incident Diagnosis Delay**: When users report "I didn't receive alert", no dashboard showing WebSocket connection status or notification delivery failures
- **Capacity Planning Difficulty**: Cannot predict when to scale ECS tasks without throughput/lag metrics

**Recommended Improvements:**
1. **Kafka Consumer Metrics**:
   - Expose `kafka_consumer_lag{topic, partition, consumer_group}` to Prometheus
   - Alert when lag > 10,000 messages or growing for 5 minutes
   - Dashboard: Consumer throughput (messages/sec), processing time per message
2. **End-to-End Latency Tracking**:
   - Inject timestamp in sensor message: `{"device_id": 1, "timestamp": "2026-02-11T10:00:00Z", ...}`
   - Record latency metrics at each stage:
     - `sensor_ingestion_lag_seconds`: now() - message.timestamp
     - `anomaly_detection_duration_seconds`: detection end - detection start
     - `alert_notification_duration_seconds`: notification sent - alert created
   - SLO dashboard: "95% of critical alerts delivered within 30s"
3. **WebSocket Health**:
   - Metrics: `websocket_connections_active`, `websocket_messages_sent_total`, `websocket_errors_total`
   - Heartbeat mechanism: Server sends ping every 30s, record `websocket_ping_timeout_total` if no pong response
   - Client-side metric: Report to backend if WebSocket disconnected for >60s
4. **Dead Letter Queue Monitoring**:
   - Track `kafka_dlq_messages_total{topic}` for poison messages
   - Alert on any DLQ activity (investigate immediately)
5. **Async Job Tracking**:
   - If background jobs exist (e.g., daily energy report generation), store job status in database with retry count, last error
   - Dashboard showing job success rate, average duration

**Reference:** Section 2.3 lists Prometheus/Grafana but Section 6 lacks async processing metrics, Section 3.3 data flow has no latency SLOs

---

## Summary Assessment

This design document demonstrates a reasonable understanding of modern cloud-native architecture with appropriate technology choices (TimescaleDB for time-series, Kafka for streaming, ECS Fargate for deployment). However, it exhibits **critical structural weaknesses** that will severely impede long-term maintainability:

**Most Critical Concerns:**
1. **Anemic domain model** with all business logic in application services, breaking encapsulation
2. **God object anti-pattern** in BuildingService violating Single Responsibility Principle
3. **Missing distributed error handling strategy** for Kafka consumers, multi-store writes, and external APIs
4. **Infrastructure leakage** into application layer without dependency inversion
5. **Undefined data consistency model** across PostgreSQL/TimescaleDB/Redis

**Recommended Immediate Actions:**
1. Refactor to rich domain model with value objects, entity behaviors, and domain events
2. Extract specialized services from BuildingService (AnomalyDetectionService, DeviceControlOrchestrator, ExternalIntegrationFacade)
3. Define error taxonomy (retryable vs non-retryable) and implement dead letter queue for Kafka consumers
4. Introduce domain interfaces for all infrastructure dependencies (WeatherForecastProvider, EventPublisher, SensorDataCache)
5. Document multi-store consistency strategy (eventual consistency with reconciliation or transactional outbox pattern)

**Long-Term Sustainability Risks:**
- Without refactoring domain model, adding new business rules (e.g., dynamic pricing for energy optimization) will scatter logic across service classes
- Tight coupling between services will make independent deployment impossible, slowing team velocity
- Missing API versioning will force coordinated client-server deployments, increasing deployment risk
- Lack of idempotency and pagination will cause production incidents under load

The system requires **significant architectural investment** before scaling to production workloads or expanding to additional building types.
