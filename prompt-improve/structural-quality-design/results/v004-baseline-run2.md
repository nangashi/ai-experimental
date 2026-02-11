# Structural Quality Design Review - Event Ticketing Platform

## Overall Assessment

This design exhibits **significant structural issues** that will substantially impact long-term maintainability, changeability, and testability. The architecture violates fundamental SOLID principles, exhibits tight coupling, lacks clear boundaries, and demonstrates insufficient consideration for extensibility and error resilience.

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| SOLID Principles & Structural Design | 2/5 | Multiple SRP violations, tight coupling, God Object pattern in TicketSalesEngine |
| Changeability & Module Design | 2/5 | High coupling causes cascading changes, poor module boundaries |
| Extensibility & Operational Design | 2/5 | Hardcoded dependencies, no clear extension points, manual environment management |
| Error Handling & Observability | 2/5 | Inadequate error classification, missing recovery strategies, insufficient structured logging |
| Test Design & Testability | 1/5 | No dependency injection, direct external API calls, undefined unit test strategy |
| API & Data Model Quality | 3/5 | Basic REST structure exists but lacks versioning, inconsistent naming, data denormalization issues |

**Overall Structural Quality: 2.0/5** - Requires substantial architectural refactoring before production deployment.

---

## Critical Issues (Severity: High)

### 1. TicketSalesEngine Violates Single Responsibility Principle (God Object)

**Location**: Section 3 - TicketSalesEngine component description

**Issue**: TicketSalesEngine handles multiple unrelated responsibilities:
- Inventory management
- Payment processing
- Email notification
- QR code generation
- Event notifications

**Impact**:
- Any change to one responsibility (e.g., switching email providers) requires modifying this component
- High risk of regression bugs
- Impossible to test individual responsibilities in isolation
- Cannot scale or deploy these concerns independently

**Recommendation**:
```
Decompose into focused services:
- TicketInventoryService: Stock management, reservation
- PaymentOrchestrator: Payment workflow coordination
- NotificationService: Email/SMS sending
- TicketIssuanceService: QR code generation, ticket creation
- EventPublisher: Event-driven notifications to other components
```

### 2. Tight Coupling Through Direct Component Calls

**Location**: Section 3 - "EventManager を直接呼び出す", "Stripe API を直接呼び出す"

**Issue**:
- TicketSalesEngine directly calls EventManager (violates Dependency Inversion Principle)
- Direct Stripe API calls without abstraction layer
- No interfaces or dependency injection mentioned

**Impact**:
- Cannot replace EventManager implementation without modifying TicketSalesEngine
- Cannot mock Stripe for testing
- Circular dependency risk (EventManager notified by TicketSalesEngine, which calls EventManager)
- Impossible to test in isolation

**Recommendation**:
```typescript
// Introduce abstractions
interface IEventInventoryRepository {
  checkAvailability(eventId: string): Promise<number>;
  reserveSeats(eventId: string, count: number): Promise<void>;
}

interface IPaymentGateway {
  processPayment(request: PaymentRequest): Promise<PaymentResult>;
}

class TicketPurchaseService {
  constructor(
    private eventRepo: IEventInventoryRepository,
    private paymentGateway: IPaymentGateway,
    private ticketRepo: ITicketRepository
  ) {}
}
```

### 3. Untestable Architecture - No Dependency Injection

**Location**: Section 6 - "実装完了後に統合テストを実施する。単体テストの方針は未定。"

**Issue**:
- No dependency injection strategy defined
- Direct database connections mentioned ("PostgreSQLに直接接続")
- Direct external API calls without abstraction
- No mention of test doubles, mocks, or interfaces

**Impact**:
- Unit testing is structurally impossible as designed
- Must rely on expensive integration tests
- Slow test execution, difficult local development
- Cannot test error scenarios (payment failures, network issues) without hitting real services

**Recommendation**:
```
1. Adopt dependency injection framework (e.g., tsyringe, InversifyJS)
2. Define interfaces for all external dependencies:
   - IDatabase, ICache, IPaymentGateway, IEmailService
3. Use repository pattern for data access
4. Implement test doubles for unit testing
5. Reserve integration tests for critical paths only
```

### 4. Data Denormalization Creates Consistency Risks

**Location**: Section 4 - Data Model

**Issues**:
- `events` table contains redundant `organizer_name`, `organizer_email` (duplicates `users` table data)
- `tickets` table contains redundant `event_title`, `event_date`, `venue_name` (duplicates `events` table data)

**Impact**:
- Data inconsistency risk when organizer updates their email
- Update anomalies (must update multiple places)
- Increased storage and maintenance cost
- Violates database normalization principles

**Recommendation**:
```sql
-- Remove denormalized columns
ALTER TABLE events DROP COLUMN organizer_name, organizer_email;
ALTER TABLE tickets DROP COLUMN event_title, event_date, venue_name;

-- Use JOIN queries or materialized views for read-heavy queries
CREATE MATERIALIZED VIEW ticket_details AS
SELECT t.*, e.title, e.event_date, e.venue_name, u.email
FROM tickets t
JOIN events e ON t.event_id = e.event_id
JOIN users u ON t.purchaser_id = u.user_id;

-- Refresh strategy for caching
REFRESH MATERIALIZED VIEW ticket_details;
```

---

## Significant Issues (Severity: Medium)

### 5. Missing API Versioning Strategy

**Location**: Section 5 - API Design

**Issue**: API endpoints lack versioning (e.g., `/events/create` instead of `/v1/events`)

**Impact**:
- Cannot introduce breaking changes without disrupting existing clients
- Forces indefinite backward compatibility or client disruption
- Difficult to deprecate old behavior

**Recommendation**:
```
Adopt URL versioning: /v1/events, /v1/tickets
Plan migration strategy:
- v1: Current design
- v2: Introduce when breaking changes needed
- Deprecation policy: Support N-1 versions for 6 months
```

### 6. Inconsistent REST API Design

**Location**: Section 5 - Endpoint naming

**Issues**:
- Verbs in URLs: `/events/create`, `/events/{eventId}/update`, `/events/{eventId}/delete`
- Should use HTTP methods instead: `POST /events`, `PUT /events/{eventId}`, `DELETE /events/{eventId}`
- Inconsistent patterns: `/events/search` (OK) vs `/tickets/user/{userId}` (resource-oriented)

**Impact**:
- Confusing API contract for clients
- Violates REST principles
- Harder to implement standard HTTP caching

**Recommendation**:
```
Standardize to RESTful design:
POST   /v1/events              (create)
PUT    /v1/events/{eventId}    (update)
DELETE /v1/events/{eventId}    (delete)
GET    /v1/events?q=keyword    (search)
GET    /v1/users/{userId}/tickets (user tickets)
POST   /v1/tickets/{ticketId}/cancellations (cancel)
```

### 7. Inadequate Error Handling Strategy

**Location**: Section 6 - "外部API（Stripe）のエラーは呼び出し元でキャッチし、HTTPステータスコードで返す"

**Issues**:
- No error classification taxonomy (retryable vs. non-retryable, transient vs. permanent)
- No retry logic or circuit breaker pattern mentioned
- Missing compensation logic for partial failures (payment succeeds but email fails)
- No saga pattern for distributed transactions

**Impact**:
- Inconsistent ticket state when downstream services fail
- User charged but no ticket issued (payment succeeded, DB write failed)
- Cascading failures under load
- Poor user experience during transient failures

**Recommendation**:
```typescript
// Implement error classification
enum ErrorCategory {
  RETRYABLE_TRANSIENT,    // Network timeout
  RETRYABLE_RATE_LIMIT,   // 429 from Stripe
  NON_RETRYABLE_CLIENT,   // Invalid card
  NON_RETRYABLE_SERVER    // Payment gateway down
}

// Add circuit breaker for Stripe calls
class StripePaymentGateway implements IPaymentGateway {
  private circuitBreaker = new CircuitBreaker({
    failureThreshold: 5,
    resetTimeout: 60000
  });

  async processPayment(req: PaymentRequest): Promise<PaymentResult> {
    return this.circuitBreaker.execute(() =>
      this.stripe.charges.create(req)
    );
  }
}

// Implement compensation for ticket purchase saga
class TicketPurchaseSaga {
  async execute(request: PurchaseRequest): Promise<TicketResult> {
    const reservation = await this.reserveSeats(request);
    try {
      const payment = await this.processPayment(request);
      try {
        const ticket = await this.issueTicket(reservation, payment);
        await this.sendEmail(ticket); // Async, non-blocking
        return ticket;
      } catch (ticketError) {
        await this.refundPayment(payment); // Compensate
        throw ticketError;
      }
    } catch (paymentError) {
      await this.releaseReservation(reservation); // Compensate
      throw paymentError;
    }
  }
}
```

### 8. Security Vulnerability - Token Storage in LocalStorage

**Location**: Section 5 - "Access Token をローカルストレージに保存", "Refresh Token をローカルストレージに保存"

**Issue**: Storing JWT tokens in localStorage exposes them to XSS attacks

**Impact**:
- If any XSS vulnerability exists, attacker can steal tokens
- Session hijacking risk
- Violates security best practices

**Recommendation**:
```
Use httpOnly cookies for token storage:
- Access Token: httpOnly, secure, SameSite=Strict cookie
- Refresh Token: httpOnly, secure, SameSite=Strict cookie
- CSRF protection: Double-submit cookie pattern or SameSite attribute
```

### 9. Manual Environment Configuration Management

**Location**: Section 6 - "環境変数は`.env`ファイルで管理（dev/staging/prodを手動切り替え）"

**Issue**: Manual environment switching increases risk of production misconfiguration

**Impact**:
- Human error risk (deploy dev config to production)
- Difficult to audit configuration changes
- Cannot reliably reproduce environments

**Recommendation**:
```
Use environment-specific config files with automated injection:
- Use AWS Systems Manager Parameter Store or Secrets Manager
- CI/CD pipeline injects correct config per environment
- Immutable deployments (bake config into container image per environment)
```

---

## Moderate Issues

### 10. Missing Transaction Boundary Definition

**Location**: Section 3 - Data Flow describes multi-step process without transaction guarantees

**Issue**: No mention of database transactions, isolation levels, or consistency guarantees for ticket purchase flow

**Impact**:
- Race conditions during concurrent purchases of last ticket
- Inconsistent state if process fails mid-flow

**Recommendation**:
```typescript
// Define transaction boundaries
async purchaseTicket(request: PurchaseRequest): Promise<Ticket> {
  return await this.db.transaction(async (trx) => {
    // SELECT FOR UPDATE to prevent concurrent purchases
    const event = await trx.events
      .where({ event_id: request.eventId, status: 'published' })
      .forUpdate()
      .first();

    if (event.available_seats < 1) {
      throw new InsufficientInventoryError();
    }

    const payment = await this.paymentGateway.charge(request);

    const ticket = await trx.tickets.insert({
      event_id: request.eventId,
      payment_id: payment.id,
      ...
    });

    await trx.events
      .where({ event_id: request.eventId })
      .decrement('available_seats', 1);

    return ticket;
  });
}
```

### 11. Missing Cache Invalidation Strategy

**Location**: Section 3 - "Redisにキャッシュする" without invalidation logic

**Issue**: No cache invalidation strategy when events are updated

**Impact**:
- Stale data served to users (outdated event details, wrong available seats)
- Cache-database inconsistency

**Recommendation**:
```typescript
// Cache-aside pattern with TTL and active invalidation
class EventRepository {
  async updateEvent(eventId: string, updates: Partial<Event>): Promise<void> {
    await this.db.events.update(eventId, updates);
    await this.cache.del(`event:${eventId}`); // Invalidate
    await this.cache.del(`event:search:*`);   // Invalidate search cache
  }

  async getEvent(eventId: string): Promise<Event> {
    const cached = await this.cache.get(`event:${eventId}`);
    if (cached) return JSON.parse(cached);

    const event = await this.db.events.findById(eventId);
    await this.cache.setex(`event:${eventId}`, 300, JSON.stringify(event));
    return event;
  }
}
```

### 12. Lack of Idempotency Guarantees

**Location**: Section 5 - POST /tickets/purchase endpoint

**Issue**: No idempotency key mechanism to prevent duplicate purchases on retry

**Impact**:
- Network timeout causes client retry
- User charged twice for same ticket
- Double-booking

**Recommendation**:
```
Implement idempotency:
1. Client generates idempotency key (UUID)
2. Include in request header: Idempotency-Key: <uuid>
3. Server stores key + result in Redis for 24 hours
4. Retry with same key returns cached result

POST /v1/tickets
Headers:
  Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

### 13. Missing Distributed Tracing Context

**Location**: Section 6 - Logging mentions CloudWatch and Sentry but no trace IDs

**Issue**: Cannot correlate logs across services and async operations

**Impact**:
- Difficult to debug cross-component issues
- Cannot trace request flow through system
- Slow incident response

**Recommendation**:
```
Implement distributed tracing:
- Use AWS X-Ray or OpenTelemetry
- Propagate trace context through all service calls
- Include trace ID in all log entries
- Correlate Stripe payment ID with ticket ID in logs
```

---

## Positive Aspects

1. **Clear separation of concerns at layer level**: Presentation, Business Logic, and Data Access layers are clearly identified
2. **Appropriate technology choices**: PostgreSQL for transactional data, Redis for caching, Stripe for payments are industry-standard
3. **JWT-based authentication**: Modern, stateless authentication approach (though implementation details need improvement)
4. **Infrastructure scalability**: ECS AutoScaling and RDS Multi-AZ demonstrate consideration for availability
5. **Security basics covered**: HTTPS, SQL injection prevention via ORM, XSS mitigation mentioned

---

## Refactoring Roadmap (Priority Order)

### Phase 1: Foundational Fixes (Critical)
1. Decompose TicketSalesEngine into focused services
2. Implement dependency injection framework
3. Define interfaces for all external dependencies
4. Fix token storage vulnerability (use httpOnly cookies)

### Phase 2: Data Integrity (Critical)
5. Remove denormalized columns, implement materialized views
6. Define transaction boundaries with proper isolation
7. Implement idempotency for purchase endpoint

### Phase 3: Resilience & Testability (Significant)
8. Implement error classification and retry logic
9. Add circuit breakers for external service calls
10. Implement saga pattern for ticket purchase flow
11. Create test strategy with unit test plan
12. Add cache invalidation strategy

### Phase 4: API & Operational Quality (Moderate)
13. Introduce API versioning (/v1/...)
14. Standardize REST endpoints
15. Implement distributed tracing
16. Automate environment configuration management

---

## Summary

This design requires **substantial architectural refactoring** before production deployment. The most critical issues are:

1. **God Object anti-pattern** in TicketSalesEngine
2. **No dependency injection**, making unit testing impossible
3. **Tight coupling** through direct component calls
4. **Data denormalization** creating consistency risks

The current architecture will lead to:
- High maintenance costs due to tight coupling
- Frequent production bugs due to untestability
- Slow feature development due to change propagation
- Data inconsistency due to denormalization

**Recommended Action**: Allocate 3-4 weeks for architectural refactoring before proceeding with implementation. The investment will pay off in reduced bugs, faster feature development, and easier maintenance.
