# Structural Quality Review: Event Ticketing Platform

## Overall Assessment

This design exhibits multiple critical architectural violations that compromise long-term maintainability and testability. The system shows tight coupling between components, missing abstraction layers, and unclear separation of concerns. Immediate refactoring is required to establish sustainable architecture.

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| **SOLID Principles & Structural Design** | 2/5 | Multiple SRP violations (TicketSalesEngine handles 7+ responsibilities), missing DIP (direct Stripe coupling), unclear module boundaries |
| **Changeability & Module Design** | 2/5 | High coupling causes cross-component change propagation, denormalized data duplication requires synchronized updates |
| **Extensibility & Operational Design** | 2/5 | No payment provider abstraction (locked to Stripe), manual environment configuration management |
| **Error Handling & Observability** | 2/5 | Missing error classification strategy, inadequate propagation design |
| **Test Design & Testability** | 2/5 | Direct external API coupling prevents mockability, unclear test strategy, no mention of DI design |
| **API & Data Model Quality** | 3/5 | Non-RESTful endpoint naming, missing versioning strategy, severe data denormalization issues |

**Overall Score: 2.2/5**

---

## Critical Issues

### 1. TicketSalesEngine: Severe SRP Violation

**Issue**: TicketSalesEngine violates Single Responsibility Principle by handling 7+ distinct responsibilities:
- Inventory management
- Seat reservation
- Payment processing
- QR code generation
- Email notification
- Event organizer notification
- Cancellation logic

**Impact**:
- Any change to notification logic requires modifying payment processing module
- Testing payment flows requires mocking email and QR generation systems
- Component becomes unmaintainable as each responsibility grows in complexity

**Recommendation**:
Decompose into separate focused components:
```
TicketReservationService  → Inventory & seat management
PaymentProcessor         → Payment orchestration only
NotificationService      → Email/SMS notifications
TicketGenerator         → QR code generation
```

**References**: Section 3 (TicketSalesEngine description)

---

### 2. Missing Payment Provider Abstraction (DIP Violation)

**Issue**: TicketSalesEngine directly couples to Stripe API with no abstraction layer:
> "決済処理はStripe APIを直接呼び出し"

**Impact**:
- Impossible to switch payment providers without rewriting TicketSalesEngine
- Cannot implement multi-provider support (e.g., PayPal, local payment methods)
- Testing requires Stripe sandbox environment; cannot use simple mocks
- Vendor lock-in creates business risk

**Recommendation**:
Introduce payment provider abstraction:
```
PaymentGateway (interface)
├── StripePaymentGateway
├── PayPalPaymentGateway
└── MockPaymentGateway (for testing)

TicketSalesEngine depends on PaymentGateway interface, not concrete implementations
```

**References**: Section 3 (TicketSalesEngine), Section 2 (Stripe API)

---

### 3. Data Model Denormalization: Synchronization Risk

**Issue**: Three types of data duplication in tickets table:
- `event_title`, `event_date`, `venue_name` duplicated from events table
- `organizer_name`, `organizer_email` duplicated from users table in events table

**Impact**:
- Event title update requires updating all related ticket records
- Organizer name change requires cascading updates across events → tickets
- Risk of data inconsistency if update logic fails mid-transaction
- Increased storage and index maintenance overhead

**Recommendation**:
**Option A (Preferred)**: Remove denormalized columns, use joins at query time:
```sql
SELECT t.*, e.title, e.event_date, e.venue_name, u.name, u.email
FROM tickets t
JOIN events e ON t.event_id = e.event_id
JOIN users u ON e.organizer_id = u.user_id
```

**Option B**: If read performance is critical, implement view-only read model:
- Keep normalized write model (events, tickets)
- Create denormalized read-only view (ticket_display_view)
- Update view via database triggers or event-driven updates

**References**: Section 4 (tickets table, events table)

---

## Significant Issues

### 4. Circular Dependency Between EventManager and TicketSalesEngine

**Issue**:
- TicketSalesEngine calls EventManager to fetch event data
- TicketSalesEngine notifies EventManager to update inventory
- Creates bidirectional coupling between components

**Impact**:
- Cannot modify EventManager without considering TicketSalesEngine
- Difficult to reuse components independently
- Testing requires both components simultaneously

**Recommendation**:
Introduce unidirectional dependency flow:
```
TicketSalesEngine → EventRepository (read-only interface)
TicketSalesEngine → publishes TicketPurchasedEvent
EventInventoryUpdater → subscribes to TicketPurchasedEvent → updates EventManager
```

**References**: Section 3 (Data Flow step 5)

---

### 5. Missing Error Classification and Propagation Strategy

**Issue**: Error handling described only in terms of HTTP status code mapping:
- Stripe errors → HTTP status codes
- DB errors → 500
- Validation errors → 400

No application-level error classification or recovery strategy defined.

**Impact**:
- Cannot distinguish between retryable vs non-retryable errors
- No guidance for partial failure scenarios (payment succeeded but email failed)
- Client cannot implement appropriate error recovery logic

**Recommendation**:
Define error taxonomy:
```
ApplicationError
├── TransientError (retryable: network failures, timeouts)
├── BusinessRuleViolation (non-retryable: insufficient inventory)
├── ValidationError (non-retryable: invalid input)
└── ExternalServiceError (provider-dependent: payment gateway failures)

Each error type includes:
- Error code (machine-readable)
- User message (human-readable)
- Retry guidance (retryable, backoff strategy)
- Correlation ID for tracing
```

**References**: Section 6 (Error Handling Policy)

---

### 6. JWT Storage in LocalStorage: Security Architecture Flaw

**Issue**: Both Access Token and Refresh Token stored in browser localStorage:
> "Access Token (有効期限: 15分) をローカルストレージに保存"
> "Refresh Token (有効期限: 7日) をローカルストレージに保存"

**Impact**:
- XSS vulnerability allows token theft (localStorage accessible via JavaScript)
- Refresh token compromise grants 7-day unauthorized access
- Violates security best practices for sensitive credentials

**Recommendation**:
Implement secure token storage strategy:
```
Access Token: httpOnly, Secure, SameSite cookie (mitigates XSS)
Refresh Token: httpOnly, Secure, SameSite cookie with additional rotation
```

Or if SPA architecture requires localStorage for access token:
```
Access Token: Short-lived (5 min) in memory only
Refresh Token: httpOnly cookie, implement rotation on each use
```

**References**: Section 5 (Authentication/Authorization Method)

---

### 7. Missing Test Architecture and DI Design

**Issue**: Test strategy states:
> "実装完了後に統合テストを実施する。単体テストの方針は未定。"

No dependency injection design mentioned anywhere in the document.

**Impact**:
- Cannot write unit tests without DI framework
- Direct database/Stripe coupling prevents isolated testing
- "Integration tests only" approach leads to slow, brittle test suites

**Recommendation**:
Define test architecture before implementation:

**Unit Test Layer**:
- Each service receives dependencies via constructor injection
- Use interface types for external dependencies (PaymentGateway, EmailService, Database)
- Test with mocks/stubs

**Integration Test Layer**:
- Test component interactions with test doubles for external services
- Use in-memory database or containers for data layer tests

**E2E Test Layer**:
- Minimal smoke tests covering critical user flows
- Run against staging environment

**DI Design**:
Implement constructor-based dependency injection:
```typescript
class TicketSalesEngine {
  constructor(
    private readonly paymentGateway: PaymentGateway,
    private readonly eventRepository: EventRepository,
    private readonly notificationService: NotificationService
  ) {}
}
```

**References**: Section 6 (Test Policy)

---

## Moderate Issues

### 8. Non-RESTful API Design

**Issue**: Endpoints violate REST conventions:
- `POST /events/create` (should be `POST /events`)
- `PUT /events/{eventId}/update` (should be `PUT /events/{eventId}`)
- `DELETE /events/{eventId}/delete` (should be `DELETE /events/{eventId}`)
- `POST /tickets/{ticketId}/cancel` (should be `DELETE /tickets/{ticketId}` or `PATCH /tickets/{ticketId}` with status update)

**Impact**:
- API consumers expect standard REST patterns
- Increases learning curve for developers
- Harder to generate API clients automatically

**Recommendation**:
Follow RESTful resource naming:
```
POST   /events              → Create event
GET    /events              → List events
GET    /events/{id}         → Get event details
PUT    /events/{id}         → Update entire event
PATCH  /events/{id}         → Partial update
DELETE /events/{id}         → Delete event

PATCH  /tickets/{id}        → Update ticket status (for cancellation)
POST   /tickets/{id}/verify → Non-CRUD action (validation)
```

**References**: Section 5 (Endpoint List)

---

### 9. Missing API Versioning Strategy

**Issue**: No versioning strategy defined in API design section.

**Impact**:
- Breaking changes force all clients to update simultaneously
- Cannot deprecate endpoints gradually
- No backward compatibility plan

**Recommendation**:
Implement URL-based versioning:
```
/v1/events
/v2/events (when breaking changes needed)
```

Or header-based versioning:
```
Accept: application/vnd.ticketing.v1+json
```

Include in design:
- Version deprecation timeline (e.g., support N-1 version for 6 months)
- Breaking vs non-breaking change policy

**References**: Section 5 (API Design)

---

### 10. Manual Environment Configuration Management

**Issue**: Environment variables managed via manual `.env` file switching:
> "環境変数は`.env`ファイルで管理（dev/staging/prodを手動切り替え）"

**Impact**:
- Risk of deploying with wrong environment config
- Manual process prone to human error
- No audit trail for configuration changes

**Recommendation**:
Use environment-specific configuration sources:
```
Development:   Local .env file (gitignored)
Staging/Prod:  AWS Parameter Store or Secrets Manager
CI/CD:         Inject environment-specific configs during deployment
```

Implement configuration validation on startup:
```typescript
const requiredEnvVars = ['DATABASE_URL', 'STRIPE_API_KEY', 'JWT_SECRET'];
requiredEnvVars.forEach(key => {
  if (!process.env[key]) {
    throw new Error(`Missing required env var: ${key}`);
  }
});
```

**References**: Section 6 (Deployment Policy)

---

## Minor Issues

### 11. Missing Idempotency Design for Payment Operations

**Issue**: No mention of idempotency handling for ticket purchase endpoint.

**Impact**:
- Network retry on payment timeout could cause double-charging
- Concurrency issues if user clicks "purchase" multiple times

**Recommendation**:
Require idempotency key in purchase request:
```json
{
  "idempotency_key": "client-generated-uuid",
  "event_id": "uuid",
  ...
}
```

Store payment attempts keyed by idempotency_key to detect duplicates.

**References**: Section 5 (POST /tickets/purchase)

---

## Positive Aspects

1. **Clear System Scope**: Document clearly defines target users and core features
2. **Performance Goals Specified**: Quantitative performance targets (95%ile < 500ms, 100 req/s)
3. **Basic Security Measures**: HTTPS, SQL injection prevention via ORM, XSS sanitization mentioned
4. **Availability Strategy**: Multi-AZ RDS, auto-scaling defined for resilience

---

## Summary of Recommendations by Priority

**Critical (Address Before Implementation)**:
1. Decompose TicketSalesEngine into focused components (SRP)
2. Introduce PaymentGateway abstraction (DIP)
3. Fix data model denormalization or implement read model pattern
4. Move tokens from localStorage to httpOnly cookies (security)
5. Define test architecture and implement DI design

**Significant (Address in First Iteration)**:
6. Break circular dependency between EventManager and TicketSalesEngine
7. Define application-level error classification taxonomy

**Moderate (Address Soon)**:
8. Fix non-RESTful endpoint naming
9. Add API versioning strategy
10. Automate environment configuration management
11. Add idempotency design for payment operations

---

## Conclusion

The current design requires substantial architectural refactoring before implementation. The combination of tight coupling, missing abstraction layers, and unclear component responsibilities will lead to high maintenance costs and testing difficulties. Addressing the critical issues—particularly component decomposition, payment abstraction, and data model normalization—is essential for long-term sustainability.
