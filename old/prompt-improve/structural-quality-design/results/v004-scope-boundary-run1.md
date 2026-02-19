# Structural Quality Design Review - Event Ticketing Platform

## Executive Summary

This design document exhibits **significant structural deficiencies** that will severely impact long-term maintainability, changeability, and testability. The architecture violates fundamental SOLID principles, demonstrates tight coupling between components, and lacks essential abstraction layers. Critical refactoring is required before implementation.

**Overall Risk Level: HIGH**

---

## Critical Issues (Severity 1)

### 1. Severe Dependency Inversion Principle Violations

**Issue**: TicketSalesEngine directly depends on concrete implementations (Stripe API, EventManager, email service, QRCode generator) without abstraction layers.

**Location**: Section 3 - "TicketSalesEngine" description

**Evidence**:
- "決済処理はStripe APIを直接呼び出し"
- "イベント情報の取得はEventManagerを直接呼び出す"
- "購入者へのメール送信、QRコード生成、イベント主催者への通知もこのコンポーネントが行う"

**Impact on Sustainability**:
- **Changeability**: Switching payment providers requires modifying core business logic in TicketSalesEngine
- **Testability**: Cannot unit test TicketSalesEngine without live Stripe API, database, and email service connections
- **Extensibility**: Adding alternative payment methods (e.g., PayPal, bank transfer) requires invasive changes

**Recommendation**:
Introduce abstraction layers:
```typescript
interface PaymentProvider {
  processPayment(amount: Decimal, method: PaymentMethod): Promise<PaymentResult>
  refund(paymentId: string): Promise<RefundResult>
}

interface EventRepository {
  findById(eventId: UUID): Promise<Event>
  updateAvailableSeats(eventId: UUID, delta: number): Promise<void>
}

interface NotificationService {
  sendTicketConfirmation(ticket: Ticket): Promise<void>
  notifyOrganizer(event: Event, ticket: Ticket): Promise<void>
}

interface TicketGenerator {
  generateQRCode(ticketId: UUID): Promise<string>
}
```

TicketSalesEngine should depend only on these interfaces, with concrete implementations injected via constructor.

**Score Impact**: Critical DIP violation → SOLID Principles: **1/5**

---

### 2. Single Responsibility Principle Violation in TicketSalesEngine

**Issue**: TicketSalesEngine violates SRP by handling 7 distinct responsibilities: inventory management, seat reservation, payment processing, ticket generation, QRCode creation, email notification, and organizer notification.

**Location**: Section 3 - TicketSalesEngine component description

**Evidence**:
"在庫確認、座席予約、購入処理、キャンセル処理を行う...決済処理はStripe APIを直接呼び出し...購入者へのメール送信、QRコード生成、イベント主催者への通知もこのコンポーネントが行う"

**Impact on Sustainability**:
- **Changeability**: Modifying notification logic requires changes to the sales engine core
- **Testability**: Cannot test ticket reservation logic independently from payment and notification logic
- **Cognitive Load**: Future developers must understand payment, inventory, and communication systems to modify any part

**Recommendation**:
Decompose TicketSalesEngine into focused components:
- `InventoryManager`: Seat availability checking and reservation
- `TicketPurchaseOrchestrator`: Coordinates the purchase workflow
- `TicketIssuer`: Generates tickets and QR codes
- `PurchaseNotifier`: Handles customer and organizer notifications

**Score Impact**: Multiple responsibility violation → SOLID Principles: **1/5**, Changeability: **2/5**

---

### 3. Missing Abstraction for Event Repository Access

**Issue**: EventManager directly accesses PostgreSQL and Redis without repository abstraction, and TicketSalesEngine directly calls EventManager for event data retrieval.

**Location**: Section 3 - EventManager description

**Evidence**: "PostgreSQLに直接接続してイベントデータを保存し、Redisにキャッシュする"

**Impact on Sustainability**:
- **Testability**: Cannot test EventManager logic without running PostgreSQL and Redis instances
- **Changeability**: Cannot switch data access patterns (e.g., CQRS, event sourcing) without rewriting EventManager
- **Dependency Direction**: EventManager is coupled to infrastructure concerns (database drivers)

**Recommendation**:
Introduce repository pattern:
```typescript
interface EventRepository {
  save(event: Event): Promise<void>
  findById(id: UUID): Promise<Event | null>
  search(criteria: SearchCriteria): Promise<Event[]>
  updateStatus(id: UUID, status: EventStatus): Promise<void>
}

interface EventCache {
  get(id: UUID): Promise<Event | null>
  set(id: UUID, event: Event, ttl: number): Promise<void>
  invalidate(id: UUID): Promise<void>
}
```

EventManager should orchestrate business logic without knowing PostgreSQL or Redis exist.

**Score Impact**: Missing data access abstraction → SOLID Principles: **1/5**, Testability: **2/5**

---

## Significant Issues (Severity 2)

### 4. Tight Coupling Between TicketSalesEngine and EventManager

**Issue**: Direct invocation creates bidirectional coupling. TicketSalesEngine calls EventManager to fetch events, and EventManager receives inventory update notifications from TicketSalesEngine.

**Location**: Section 3 - Data Flow step 5

**Evidence**:
- "イベント情報の取得はEventManagerを直接呼び出す"
- "EventManagerにイベント在庫を更新するよう通知"

**Impact on Sustainability**:
- **Changeability**: Cannot modify TicketSalesEngine without understanding EventManager's internal state management
- **Circular Dependency Risk**: Bidirectional communication creates potential for circular dependencies
- **Deployment Complexity**: Cannot deploy or scale these components independently

**Recommendation**:
Introduce domain events and event-driven architecture:
```typescript
// TicketSalesEngine publishes events
interface DomainEventPublisher {
  publish(event: DomainEvent): Promise<void>
}

class TicketPurchasedEvent implements DomainEvent {
  constructor(
    public eventId: UUID,
    public ticketId: UUID,
    public seatsReserved: number
  ) {}
}

// EventManager subscribes to domain events
class EventInventoryUpdater {
  async onTicketPurchased(event: TicketPurchasedEvent): Promise<void> {
    await this.eventRepository.updateAvailableSeats(
      event.eventId,
      -event.seatsReserved
    )
  }
}
```

This decouples components and enables asynchronous processing.

**Score Impact**: Component coupling → Changeability: **2/5**, Module Design: **2/5**

---

### 5. Missing Error Classification Strategy

**Issue**: Error handling is defined only by HTTP status codes without application-level error classification, propagation strategy, or recovery design.

**Location**: Section 6 - Error Handling Policy

**Evidence**:
- "外部API（Stripe）のエラーは呼び出し元でキャッチし、HTTPステータスコードで返す"
- "データベースエラーは500 Internal Server Errorとして返す"

**Impact on Sustainability**:
- **Observability**: Cannot distinguish between "payment provider timeout" vs "payment declined" vs "network error" from logs
- **Recoverability**: No guidance on transient vs permanent errors, retry strategies, or compensation
- **Client Experience**: 500 errors provide no actionable information for users or support teams

**Recommendation**:
Design error classification hierarchy:
```typescript
abstract class ApplicationError extends Error {
  abstract readonly code: string
  abstract readonly severity: ErrorSeverity
  abstract readonly recoverable: boolean
}

class PaymentDeclinedError extends ApplicationError {
  code = 'PAYMENT_DECLINED'
  severity = ErrorSeverity.USER_ERROR
  recoverable = false
}

class PaymentProviderTimeoutError extends ApplicationError {
  code = 'PAYMENT_PROVIDER_TIMEOUT'
  severity = ErrorSeverity.EXTERNAL_SERVICE_ERROR
  recoverable = true
}

class InventoryConflictError extends ApplicationError {
  code = 'SEAT_ALREADY_RESERVED'
  severity = ErrorSeverity.BUSINESS_RULE_VIOLATION
  recoverable = true // Client can retry with different seat
}
```

Define propagation rules: business errors → 4xx with error code, infrastructure errors → 5xx with correlation ID.

**Score Impact**: Missing error strategy → Error Handling & Observability: **2/5**

---

### 6. Inadequate Test Architecture Design

**Issue**: Test strategy is undefined ("単体テストの方針は未定") with only integration testing planned post-implementation.

**Location**: Section 6 - Testing Policy

**Evidence**: "実装完了後に統合テストを実施する。単体テストの方針は未定。"

**Impact on Sustainability**:
- **Testability**: Current tight coupling makes unit testing nearly impossible without extensive mocking
- **Regression Risk**: Integration-only testing provides slow feedback and incomplete coverage
- **Refactoring Safety**: Cannot safely refactor without unit test safety net

**Recommendation**:
Define test architecture before implementation:

**Unit Tests (70% coverage target)**:
- Test business logic in isolated components with injected dependencies
- Mock all external services (PaymentProvider, EventRepository, NotificationService)
- Fast feedback (< 1 second total execution time)

**Integration Tests (20% coverage target)**:
- Test API layer → Service layer → Repository layer with test database
- Use testcontainers for PostgreSQL/Redis
- Verify transaction boundaries and error propagation

**E2E Tests (10% coverage target)**:
- Critical user journeys: event creation → ticket purchase → QR validation
- Use staging environment with real external service sandboxes

**Score Impact**: Undefined test architecture → Test Design & Testability: **2/5**

---

### 7. Data Model Denormalization Without Justification

**Issue**: The `events` table duplicates organizer data (organizer_name, organizer_email), and `tickets` table duplicates event data (event_title, event_date, venue_name), violating database normalization principles without documented performance rationale.

**Location**: Section 4 - Data Model

**Evidence**:
- `events` table includes `organizer_name`, `organizer_email` (duplicates data from `users`)
- `tickets` table includes `event_title`, `event_date`, `venue_name` (duplicates data from `events`)

**Impact on Sustainability**:
- **Data Consistency Risk**: Organizer updates require updating all related events; event updates require updating all issued tickets
- **Write Amplification**: Single logical change propagates to multiple tables
- **Schema Evolution**: Adding organizer fields requires migration of historical events

**Recommendation**:
Either:
1. **Normalize** (recommended for initial version):
   - Remove duplicated fields
   - Use JOINs for read queries
   - Add query indexes on frequently joined columns

2. **Denormalize intentionally** (if read performance is critical):
   - Document performance requirements justifying denormalization
   - Implement automated synchronization triggers or event handlers
   - Add data integrity validation to prevent inconsistencies

**Current State**: Denormalized without justification or consistency mechanism.

**Score Impact**: Unexplained denormalization → Data Model Quality: **3/5**

---

## Moderate Issues (Severity 3)

### 8. API Design Violates RESTful Conventions

**Issue**: API endpoints use action verbs in URLs and inconsistent HTTP method usage, violating REST architectural style.

**Location**: Section 5 - API Design

**Evidence**:
- `POST /events/create` (should be `POST /events`)
- `PUT /events/{eventId}/update` (should be `PUT /events/{eventId}`)
- `DELETE /events/{eventId}/delete` (should be `DELETE /events/{eventId}`)
- `POST /tickets/{ticketId}/cancel` (should be `PATCH /tickets/{ticketId}` or `DELETE /tickets/{ticketId}`)
- `POST /tickets/{ticketId}/validate` (should be `POST /tickets/{ticketId}/validations` or `PATCH /tickets/{ticketId}/status`)

**Impact on Sustainability**:
- **API Evolution**: Non-standard endpoints complicate versioning and client SDK generation
- **Developer Experience**: Developers expect standard REST conventions; deviations increase cognitive load
- **Cacheability**: Non-RESTful endpoints may bypass HTTP caching strategies

**Recommendation**:
Align with REST conventions:
```
POST   /events              # Create event
PUT    /events/{eventId}    # Update event
DELETE /events/{eventId}    # Delete event
GET    /events              # Search events
GET    /events/{eventId}    # Get event details

POST   /tickets                      # Purchase ticket
PATCH  /tickets/{ticketId}           # Update ticket status
GET    /users/{userId}/tickets       # Get user's tickets
POST   /tickets/{ticketId}/validations # Validate QR code
```

**Score Impact**: Non-RESTful API design → API & Data Model Quality: **3/5**

---

### 9. Missing Environment Configuration Management Design

**Issue**: Environment differentiation relies on manual `.env` file switching without automated configuration management or validation.

**Location**: Section 6 - Deployment Policy

**Evidence**: "環境変数は`.env`ファイルで管理（dev/staging/prodを手動切り替え）"

**Impact on Sustainability**:
- **Operational Risk**: Manual switching increases risk of deploying dev configuration to production
- **Configuration Drift**: No mechanism to detect configuration differences across environments
- **Secret Management**: `.env` files in version control expose credentials

**Recommendation**:
Design configuration management strategy:
1. Use environment-specific configuration sources (AWS Parameter Store, Secrets Manager)
2. Implement configuration validation at application startup:
   ```typescript
   interface EnvironmentConfig {
     database: { host: string; port: number; sslEnabled: boolean }
     stripe: { apiKey: string; webhookSecret: string }
     redis: { url: string; tls: boolean }
   }

   function validateConfig(config: EnvironmentConfig): ValidationResult {
     // Type checking, required field validation, format validation
   }
   ```
3. Use deployment automation to inject environment variables (ECS task definitions)
4. Never commit `.env` files; use `.env.example` templates

**Score Impact**: Manual configuration management → Operational Design: **3/5**

---

### 10. Insufficient API Versioning Strategy

**Issue**: No API versioning mechanism documented, making backward-incompatible changes risky.

**Location**: Section 5 - API Design (versioning not mentioned)

**Impact on Sustainability**:
- **Breaking Changes**: Cannot evolve API without breaking existing clients
- **Incremental Migration**: No path for gradual client migration to new API versions

**Recommendation**:
Define versioning strategy before first release:
- URI versioning: `/v1/events`, `/v2/events`
- Version deprecation policy: Support N-1 versions for 6 months
- Document breaking vs non-breaking changes

**Score Impact**: Missing versioning → API & Data Model Quality: **3/5**

---

## Positive Aspects

1. **Clear Domain Model**: Event, Ticket, User entities are well-defined with appropriate constraints
2. **3-Layer Architecture**: Separation of presentation, business logic, and data access provides foundation for further refinement
3. **Authentication Strategy**: JWT with refresh token follows industry best practices
4. **Non-Functional Requirements**: Specific performance targets (95%ile < 500ms) and availability goals (99.5%) enable measurable design decisions

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| **1. SOLID Principles & Structural Design** | **1/5** | Critical DIP violations (TicketSalesEngine → Stripe, EventManager → PostgreSQL/Redis), severe SRP violation (TicketSalesEngine with 7 responsibilities), tight coupling between components |
| **2. Changeability & Module Design** | **2/5** | Direct component coupling prevents independent evolution; bidirectional dependencies; missing abstraction layers |
| **3. Extensibility & Operational Design** | **3/5** | No extension points for payment providers or notification channels; manual configuration management increases operational risk |
| **4. Error Handling & Observability** | **2/5** | Missing error classification strategy; no guidance on transient vs permanent errors; HTTP status codes insufficient for observability |
| **5. Test Design & Testability** | **2/5** | Test strategy undefined; tight coupling makes unit testing impractical; no dependency injection design |
| **6. API & Data Model Quality** | **3/5** | RESTful violations in endpoint design; unexplained denormalization; missing API versioning; data model entities well-defined |

**Overall Structural Quality Score: 2.2/5 (Critical Risk)**

---

## Refactoring Roadmap

### Phase 1: Critical Foundation (Before Implementation)
1. Introduce abstraction interfaces for PaymentProvider, EventRepository, NotificationService, TicketGenerator
2. Decompose TicketSalesEngine into InventoryManager, TicketPurchaseOrchestrator, TicketIssuer, PurchaseNotifier
3. Design error classification hierarchy and propagation strategy
4. Define dependency injection architecture (constructor injection)

### Phase 2: Module Decoupling
1. Implement repository pattern for EventRepository and UserRepository
2. Replace direct EventManager calls with domain events (TicketPurchasedEvent)
3. Introduce event-driven architecture for cross-component communication

### Phase 3: Test Architecture
1. Define test strategy with unit/integration/E2E coverage targets
2. Ensure all business logic components are testable in isolation
3. Set up testcontainers for integration tests

### Phase 4: API & Configuration Refinement
1. Align API endpoints with RESTful conventions
2. Implement API versioning (v1 prefix)
3. Replace manual `.env` switching with environment-specific configuration sources
4. Normalize data model or justify denormalization with consistency mechanisms

---

## Conclusion

This design exhibits **fundamental structural deficiencies** that will lead to a fragile, untestable, and difficult-to-evolve system. The violation of SOLID principles, particularly Dependency Inversion and Single Responsibility, combined with tight coupling and missing abstraction layers, creates a high-risk architecture.

**Recommendation**: Perform critical refactoring (Phase 1-2 above) **before implementation**. Proceeding with the current design will accumulate technical debt that becomes exponentially more expensive to address post-implementation.

The 3-layer architecture and clear domain model provide a solid foundation, but the execution lacks the abstraction and separation of concerns necessary for long-term sustainability.
