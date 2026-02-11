# Structural Quality Review - Smart Building Management System

## Structure Analysis

The system follows a 4-layer architecture:
- **Presentation Layer**: REST API Controllers and WebSocket handlers for real-time data streaming
- **Application Layer**: Service classes (BuildingService, DeviceService, SensorDataService, AlertService, AnalyticsService)
- **Domain Layer**: Entity classes and Repository interfaces
- **Infrastructure Layer**: JPA implementations, Kafka producers/consumers, Redis cache manager, external API clients
- **Data Stores**: PostgreSQL (master data), TimescaleDB (time-series sensor data), Redis (cache), Kafka (event streaming)
- **Key Integration Points**: IoT gateways → Kafka → TimescaleDB/Redis, External APIs (weather, AI prediction), Device controller APIs

## Critical Issues

### C-1: BuildingService Violates Single Responsibility Principle (SRP)

**Description**: BuildingService is described as handling "ビル設備の統合管理ロジック" and is responsible for:
- Sensor data aggregation
- Anomaly detection
- Control instruction generation
- External API calls (weather API, AI prediction API)
- Transaction boundary management

This is a severe SRP violation combining data aggregation, domain logic, external integration, and transaction control in a single service.

**Impact**:
- Changes in anomaly detection algorithms force modification of the same class handling external API integration
- Testing becomes difficult as mocking requires complex setup for multiple unrelated concerns
- High coupling makes the service non-reusable and difficult to refactor
- Transaction boundaries become unclear when mixing read-heavy aggregation with write-heavy control logic

**Recommendation**: Decompose BuildingService into:
- `SensorDataAggregationService` (read-only, data collection logic)
- `AnomalyDetectionService` (domain logic for threshold evaluation)
- `DeviceControlService` (control instruction generation and execution)
- `ExternalApiClient` implementations (weather, AI prediction) moved to Infrastructure layer
- Use a facade or orchestration service if coordinated operations are needed

**Reference**: Section 3.2 "BuildingService"

### C-2: Missing Abstraction for External API Dependencies

**Description**: BuildingService directly calls external APIs (weather API, AI prediction API) without an abstraction layer. No interface definition or adapter pattern is mentioned.

**Impact**:
- Impossible to test BuildingService in isolation without hitting real external APIs
- Switching to different weather or AI prediction providers requires modifying service logic
- No fallback mechanism design for API unavailability (only Circuit Breaker for weather API failure is mentioned, but no abstraction for testability)
- Violates Dependency Inversion Principle (DIP) - high-level module depends on low-level implementation details

**Recommendation**:
- Define interfaces `WeatherDataProvider` and `PredictionModelProvider` in the Application or Domain layer
- Implement concrete adapters (`OpenWeatherApiClient`, `TensorFlowPredictionClient`) in Infrastructure layer
- Inject these dependencies into services via constructor injection
- Enable easy mocking for unit tests and support multiple provider implementations

**Reference**: Section 3.2 "BuildingService", Section 6.1 "エラーハンドリング方針"

### C-3: Circular Dependency Risk Between Application and Domain Layers

**Description**: The architecture description states:
- Domain Layer contains "Entity" and "Repository Interface"
- Application Layer contains services that depend on Domain Layer
- However, the design does not clarify whether Repository interfaces are defined in Domain Layer or Infrastructure Layer, creating ambiguity that can lead to circular dependencies if JPA annotations leak into domain entities

**Impact**:
- If JPA annotations are used directly in domain entities, the domain layer depends on infrastructure (JPA), violating Clean Architecture principles
- Difficult to test domain logic without infrastructure setup
- Domain entities become tightly coupled to persistence technology, making it hard to migrate from JPA to other ORM or NoSQL solutions

**Recommendation**:
- Explicitly separate domain entities (pure business objects) from JPA entities (persistence models)
- Use mapper/converter layer to translate between domain models and JPA entities
- Define repository interfaces in Domain Layer, implement them in Infrastructure Layer
- Ensure domain layer has zero dependencies on infrastructure frameworks

**Reference**: Section 3.1 "全体構成", Section 3.2 "Domain Layer"

### C-4: No Versioning Strategy for API Evolution

**Description**: Section 5 defines API endpoints but provides no versioning strategy. No mention of:
- How to introduce breaking changes without disrupting existing clients
- URI versioning (`/v1/buildings`, `/v2/buildings`) vs. header-based versioning
- Deprecation policy for old API versions
- Backward compatibility guarantees

**Impact**:
- First breaking change (e.g., modifying response schema of `/buildings/{id}`) will break all existing mobile apps and web clients
- No graceful migration path for clients
- Forced big-bang updates for all clients, increasing deployment risk
- Impossible to support multiple client versions simultaneously (e.g., old mobile apps that users haven't updated)

**Recommendation**:
- Adopt URI versioning (`/api/v1/...`) or header-based versioning (`Accept: application/vnd.smartbuilding.v1+json`)
- Define deprecation policy: "Old versions supported for 12 months after new version release"
- Document backward compatibility rules: "Additive changes only within a version, breaking changes require new version"
- Plan migration strategy for existing `/buildings` endpoints to `/api/v1/buildings`

**Reference**: Section 5 "API設計"

### C-5: Missing Error Propagation and Classification Strategy

**Description**: Section 6.1 mentions custom exceptions (`ResourceNotFoundException`, `InvalidOperationException`) but does not define:
- Complete error taxonomy (what other exception types exist?)
- Distinguishing between retryable vs. non-retryable errors
- Error codes or structured error responses
- How errors propagate from Infrastructure Layer (JPA exceptions, Kafka exceptions) to Application Layer

**Impact**:
- Clients cannot programmatically distinguish error types, forcing them to parse error messages
- No guidance for retry logic (which errors should clients retry?)
- Infrastructure exceptions may leak to API responses, exposing internal implementation details
- Inconsistent error handling across different endpoints

**Recommendation**:
- Define error taxonomy with error codes:
  - `VALIDATION_ERROR` (400, non-retryable)
  - `RESOURCE_NOT_FOUND` (404, non-retryable)
  - `DEVICE_UNAVAILABLE` (503, retryable)
  - `EXTERNAL_SERVICE_ERROR` (502, retryable)
- Standardize error response schema:
  ```json
  {
    "error_code": "DEVICE_UNAVAILABLE",
    "message": "Device 456 is currently offline",
    "retryable": true,
    "request_id": "abc-123"
  }
  ```
- Create exception mapping layer to convert infrastructure exceptions (e.g., `DataAccessException`) to domain exceptions
- Document retry policy for each error type

**Reference**: Section 6.1 "エラーハンドリング方針"

## Significant Issues

### S-1: State Management Design Missing

**Description**: The design does not specify state management policies:
- Are services stateless or stateful?
- How is `WebSocketHandler` managed (singleton, per-connection instance)?
- How are active WebSocket connections tracked?
- Is there global mutable state (e.g., in-memory cache of active alerts)?

**Impact**:
- Stateful services prevent horizontal scaling (cannot add ECS Fargate tasks arbitrarily)
- WebSocket connection state may be lost during deployment or task restart
- No clear strategy for maintaining WebSocket connections across multiple ECS tasks (sticky sessions? Redis-backed session store?)

**Recommendation**:
- Declare all services as stateless (no instance variables holding mutable state)
- Store WebSocket connection state in Redis (connection ID → user ID, building ID mapping)
- Use Redis Pub/Sub or Kafka to broadcast real-time updates to all ECS tasks, each task then pushes to its connected WebSocket clients
- Document WebSocket reconnection strategy for clients during deployment

**Reference**: Section 3.1 "Presentation Layer - WebSocket Handler"

### S-2: DTO vs. Entity Separation Not Enforced

**Description**: Section 3.2 mentions "リクエストの検証、DTO変換" in Controller, but the design does not clarify:
- Are JPA entities directly exposed in API responses?
- Are DTOs defined for all API endpoints?
- What layer is responsible for DTO ↔ Entity conversion?

**Impact**:
- If entities are exposed directly, adding JPA lazy-loading or bidirectional relationships will cause JSON serialization issues (N+1 queries, circular references)
- Internal schema changes (e.g., renaming entity fields) break API contracts
- Cannot evolve API independently of database schema

**Recommendation**:
- Define separate DTO classes for all API requests/responses (e.g., `BuildingResponseDto`, `CreateBuildingRequestDto`)
- Use MapStruct or manual mappers to convert Entity ↔ DTO in Controller layer
- Never expose JPA entities directly in REST API responses
- Document DTO design guideline: "DTOs are immutable records, entities are mutable objects managed by JPA"

**Reference**: Section 3.2 "BuildingManagementController", Section 5.3 "リクエスト/レスポンス形式例"

### S-3: No Strategy for Handling Schema Evolution in TimescaleDB

**Description**: `SensorData` is stored in TimescaleDB as a hypertable with composite primary key `(time, device_id, metric_type)`. The design does not address:
- How to add new `metric_type` values (e.g., adding `CO2_LEVEL` later)
- How to change data types (e.g., changing `value` from `double precision` to `jsonb` for complex metrics)
- How to migrate historical data when schema changes

**Impact**:
- Adding new metric types requires application code changes but no database migration
- Changing data types requires downtime for TimescaleDB hypertable rewriting (extremely slow for large tables)
- No strategy for querying new metrics vs. old metrics with different schemas
- Risk of data loss or inconsistency during schema migration

**Recommendation**:
- Use a flexible schema design for `SensorData`:
  - Add `metadata` column (JSONB) to store future complex metrics without schema changes
  - Keep `value` as double for backward compatibility, add `value_json` (JSONB) for complex data
- Document metric type registration process: "New metric types must be registered in `metric_type_catalog` table before use"
- Define migration strategy for schema changes: "Create new hypertable, dual-write during migration, cutover after backfill"
- Use Flyway versioned migrations for TimescaleDB schema changes

**Reference**: Section 4.1 "SensorData (センサーデータ)"

### S-4: AlertManager Responsibility Overload

**Description**: AlertManager handles:
- Anomaly detection rule evaluation
- Alert generation and notification (email, Slack, mobile push)
- Escalation processing

This mixes rule evaluation (domain logic) with notification delivery (infrastructure concern).

**Impact**:
- Cannot test alert rule evaluation without setting up email/Slack/push notification infrastructure
- Adding new notification channels (e.g., SMS, MS Teams) requires modifying AlertManager
- Escalation logic is tightly coupled to notification delivery, making it hard to change escalation policies independently

**Recommendation**:
- Split AlertManager into:
  - `AlertEvaluationService` (evaluates rules, generates alert entities)
  - `NotificationService` with strategy pattern for different channels (`EmailNotifier`, `SlackNotifier`, `PushNotifier`)
  - `EscalationPolicyService` (determines escalation logic, e.g., "if unacknowledged for 30 minutes, escalate to senior admin")
- Use event-driven design: `AlertEvaluationService` publishes `AlertCreatedEvent` to Kafka, `NotificationService` subscribes and dispatches notifications

**Reference**: Section 3.2 "AlertManager"

### S-5: No Dependency Injection Design Specified

**Description**: The design mentions Spring Boot but does not specify:
- How services are instantiated (constructor injection, field injection, or setter injection?)
- Are dependencies injected as interfaces or concrete classes?
- How are circular dependencies avoided?
- What is the scope of beans (singleton, prototype, request-scoped)?

**Impact**:
- Developers may inconsistently use field injection, making testing difficult (cannot inject mocks via constructor)
- Circular dependencies may emerge at runtime (e.g., ServiceA depends on ServiceB, ServiceB depends on ServiceA)
- No clear guidance for writing testable code

**Recommendation**:
- Enforce constructor injection for all services: "All dependencies must be final fields injected via constructor"
- Inject interfaces, not concrete classes: "Services should depend on repository interfaces, not JPA repository implementations"
- Declare default bean scope as singleton, document exceptions (e.g., WebSocket handlers may need prototype scope)
- Add ArchUnit tests to enforce: "No field injection allowed, all services must use constructor injection"

**Reference**: Section 2.1 "Backend", Section 6.3 "テスト方針"

## Moderate Issues

### M-1: Missing Configuration Management Design

**Description**: Section 2.4 mentions Spring Cloud Config, but the design does not specify:
- What configuration properties are externalized (database URLs, API keys, thresholds)?
- How are configurations managed across environments (dev, staging, production)?
- Is there a configuration versioning strategy?
- How are sensitive values (API keys, DB passwords) handled?

**Impact**:
- Developers may hardcode configuration values in code, reducing environment portability
- Changing anomaly detection thresholds requires code changes and redeployment
- No audit trail for configuration changes

**Recommendation**:
- Define configuration categories:
  - **Infrastructure**: DB URLs, Kafka brokers, Redis endpoints (managed by Spring Cloud Config)
  - **Feature toggles**: Enable/disable AI prediction, real-time streaming (managed by config server)
  - **Business rules**: Anomaly thresholds, escalation timeouts (stored in database `system_config` table for runtime updates)
- Use AWS Secrets Manager or AWS Systems Manager Parameter Store for sensitive values
- Document configuration management workflow: "Config changes go through PR review, deployed via config server restart"

**Reference**: Section 2.4 "Spring Cloud Config"

### M-2: No Tracing Design for Distributed System

**Description**: Section 6.2 mentions "リクエストIDをMDCに格納" but does not specify:
- How request IDs are propagated across Kafka messages?
- How to trace a sensor data event from IoT gateway → Kafka → SensorDataCollector → TimescaleDB → WebSocket → Client?
- Is distributed tracing (OpenTelemetry, AWS X-Ray) used?

**Impact**:
- Cannot trace end-to-end latency for sensor data pipeline
- Difficult to debug issues spanning multiple services (e.g., "why did alert notification arrive 30 seconds late?")
- Log correlation is limited to synchronous REST API requests, not asynchronous Kafka processing

**Recommendation**:
- Adopt OpenTelemetry for distributed tracing
- Propagate trace context in Kafka message headers (use `traceparent` header per W3C Trace Context spec)
- Instrument key operations: Kafka message consumption, database writes, external API calls, WebSocket sends
- Integrate with AWS X-Ray or Grafana Tempo for trace visualization

**Reference**: Section 6.2 "ロギング方針"

### M-3: Hardcoded Device Control Logic

**Description**: The design mentions "BuildingService" generates control instructions and sends them to device controller API. No mention of:
- Is control logic hardcoded (e.g., "if temperature > 26°C, set AC to 24°C")?
- How to support different control strategies per building or tenant?
- How to add new device types without code changes?

**Impact**:
- Each new building with different control requirements needs code changes
- Cannot A/B test different control strategies (e.g., aggressive vs. energy-saving mode)
- Tight coupling between control logic and API endpoint makes it hard to reuse logic for batch operations

**Recommendation**:
- Introduce strategy pattern for control logic:
  - Define `ControlStrategy` interface with method `generateControlInstruction(SensorData, DeviceState): ControlCommand`
  - Implement concrete strategies: `TemperatureBasedStrategy`, `OccupancyBasedStrategy`, `AiPredictionStrategy`
  - Store strategy selection per building in database (`building.control_strategy_type`)
- Support runtime strategy switching via admin API
- Extract control rule engine (e.g., Drools) for complex rule evaluation if needed

**Reference**: Section 3.3 "制御指示フロー"

### M-4: Lack of Testability Design for Kafka Consumers

**Description**: Section 6.3 mentions Testcontainers for Kafka integration tests, but does not specify:
- How to unit test `SensorDataCollector` (Kafka consumer) without running Kafka?
- How to verify message processing logic independently of Kafka infrastructure?
- How to handle duplicate messages or out-of-order messages in tests?

**Impact**:
- Slow integration tests (spinning up Kafka containers for every test)
- Difficult to reproduce edge cases (message redelivery, consumer rebalancing)
- No clear separation between message handling logic and Kafka infrastructure

**Recommendation**:
- Extract message processing logic into a separate service: `SensorDataProcessor.process(SensorDataMessage)`
- `SensorDataCollector` becomes a thin adapter: deserialize Kafka record → call `SensorDataProcessor.process()`
- Unit test `SensorDataProcessor` with simple POJO inputs (no Kafka dependency)
- Use Testcontainers only for integration tests verifying Kafka consumer configuration (offset management, rebalancing)

**Reference**: Section 3.2 "SensorDataCollector", Section 6.3 "テスト方針"

### M-5: Missing Data Retention Policy

**Description**: SensorData is stored in TimescaleDB with 1-second intervals from thousands of sensors. No mention of:
- How long is raw sensor data retained?
- Is there a data aggregation strategy (e.g., downsample to 1-minute averages after 7 days)?
- How is data deletion handled (manual cleanup, automatic retention policies)?

**Impact**:
- TimescaleDB storage grows indefinitely, increasing costs
- Query performance degrades over time as table size grows
- No compliance with data retention regulations (e.g., GDPR requires data deletion after retention period)

**Recommendation**:
- Define retention policy:
  - Raw 1-second data: retained for 30 days
  - 1-minute aggregated data: retained for 1 year
  - 1-hour aggregated data: retained for 3 years
- Use TimescaleDB continuous aggregates for automatic downsampling
- Enable TimescaleDB retention policies (`add_retention_policy()`) for automatic data deletion
- Document retention policy in data model section

**Reference**: Section 4.1 "SensorData (センサーデータ)"

## Minor Improvements

### I-1: Consider Read Replicas for Analytics Queries

**Description**: Section 5.2 defines analytics endpoints (`/analytics/energy-consumption`, `/analytics/comfort-score`) that may execute heavy queries on TimescaleDB. No mention of read replicas to offload analytical queries.

**Recommendation**:
- Use RDS Read Replica for PostgreSQL to offload reporting queries
- Route analytics queries to read replica via separate DataSource configuration
- Document query routing policy: "Transactional writes → primary, read-only analytics → replica"

**Reference**: Section 5.2 "分析・レポート"

### I-2: Specify Unit of Work Pattern for Transaction Boundaries

**Description**: BuildingService is responsible for "トランザクション境界の管理" but no details on transaction scope or isolation level.

**Recommendation**:
- Use Spring `@Transactional` at service method level, not class level (fine-grained control)
- Document transaction policy: "Read-only operations use `@Transactional(readOnly=true)` for performance optimization"
- Specify isolation level for critical operations: "Device control operations use `REPEATABLE_READ` to prevent lost updates"

**Reference**: Section 3.2 "BuildingService"

### I-3: Positive Aspect - Appropriate Use of Resilience4j Circuit Breaker

**Description**: Section 6.1 mentions using Resilience4j Circuit Breaker for external API calls with fallback to cached values. This is a good practice for handling transient failures.

**Recommendation**:
- Extend Circuit Breaker pattern to AI prediction API as well (currently only mentioned for weather API)
- Document Circuit Breaker configuration: "Open circuit after 5 consecutive failures, half-open after 60 seconds, fallback to last known good prediction"

**Reference**: Section 6.1 "エラーハンドリング方針"

## Summary

This design document demonstrates a reasonable layered architecture but suffers from several critical structural issues:

**Most Critical**:
1. **BuildingService violates SRP** - mixing multiple unrelated responsibilities
2. **No abstraction for external dependencies** - violates DIP, untestable
3. **No API versioning strategy** - will break clients on first breaking change
4. **Missing error taxonomy** - clients cannot distinguish error types or implement retry logic
5. **Potential circular dependency** between Domain and Infrastructure layers due to JPA leakage

**Key Recommendations**:
- Decompose BuildingService into focused services
- Introduce interfaces for all external dependencies
- Adopt API versioning and define backward compatibility policy
- Define comprehensive error taxonomy with error codes
- Enforce DTO separation from entities
- Design testability into Kafka consumers and WebSocket handlers

**Positive Aspects**:
- Clear layered architecture with defined responsibilities
- Appropriate choice of TimescaleDB for time-series data
- Good use of Circuit Breaker for external API resilience

Addressing the critical issues will significantly improve long-term maintainability, changeability, and testability of this system.
