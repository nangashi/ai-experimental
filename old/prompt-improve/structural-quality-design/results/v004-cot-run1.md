# Structural Quality Design Review: Event Ticketing Platform

## Review Metadata
- Reviewer: structural-quality-design-reviewer (v004-variant-cot)
- Document: Event Ticketing Platform System Design
- Review Date: 2026-02-11

---

## Stage 1: Overall Structure Analysis

The system adopts a 3-layer architecture (Presentation, Business Logic, Data Access) with 3 major components: EventManager, TicketSalesEngine, and UserAuthService. The architecture follows a traditional monolithic service pattern with direct component coupling and no clear dependency injection strategy. The system boundary is well-defined (event ticketing platform) but architectural patterns for cross-cutting concerns (error handling, observability, testing) are underspecified.

## Stage 2: Section-by-Section Analysis

### 3.1 Component Design Issues

**EventManager**: Violates Single Responsibility Principle by handling both business logic (event management) and infrastructure concerns (direct PostgreSQL access, Redis caching). This tight coupling makes the component difficult to test and change.

**TicketSalesEngine**: Exhibits multiple SRP violations:
- Core ticketing logic (inventory, reservation, purchase)
- Direct external API integration (Stripe)
- Notification delivery (email sending)
- Data generation (QR code creation)
- Cross-component coordination (notifying EventManager)

This component has at least 5 distinct responsibilities, creating a maintenance bottleneck and making it nearly impossible to test in isolation.

**Direct coupling**: "イベント情報の取得はEventManagerを直接呼び出す" indicates concrete class dependency rather than interface-based abstraction, violating Dependency Inversion Principle.

### 3.2 Data Model Violations

**Data denormalization without justification**:
- `events.organizer_name`, `events.organizer_email` duplicate data from `users` table
- `tickets.event_title`, `tickets.event_date`, `tickets.venue_name` duplicate data from `events` table

This creates multiple issues:
1. Update anomalies: Changing organizer email requires updating both `users` and all related `events` records
2. Consistency risks: No trigger or application-level guarantee that denormalized data stays synchronized
3. Storage waste and index inefficiency

**Missing constraints**:
- No CHECK constraint ensuring `events.available_seats <= events.total_seats`
- No validation that `tickets.price` matches pricing rules or event base price
- No foreign key constraints documented for payment relationship

### 3.3 API Design Issues

**Non-RESTful endpoints**:
- `POST /events/create` should be `POST /events`
- `PUT /events/{eventId}/update` should be `PUT /events/{eventId}`
- `DELETE /events/{eventId}/delete` should be `DELETE /events/{eventId}`
- `POST /tickets/{ticketId}/cancel` should be `PATCH /tickets/{ticketId}` with status update

**Missing versioning**: No API versioning strategy (e.g., `/v1/events`) makes backward compatibility impossible to maintain.

**Inconsistent resource naming**: `/tickets/user/{userId}` mixes resource and sub-resource patterns; should be `/users/{userId}/tickets` to follow REST hierarchy.

### 3.4 Error Handling Deficiencies

**Insufficient error classification**: Only 3 error types (external API, database, validation) documented. Missing:
- Business logic errors (insufficient inventory, duplicate purchase)
- Authentication/authorization failures
- Rate limiting errors
- Partial failure handling (payment succeeded but email failed)

**No recovery strategy**: "外部API（Stripe）のエラーは呼び出し元でキャッチし、HTTPステータスコードで返す" provides no guidance on:
- Retry logic for transient failures
- Idempotency handling
- Compensation for partially completed operations

**No error propagation design**: With TicketSalesEngine calling EventManager, Stripe, email service, and QR service, there's no documented strategy for how failures cascade or are isolated.

### 3.5 Testing Design Gaps

**Critical gap**: "実装完了後に統合テストを実施する。単体テストの方針は未定。" This is a structural red flag:
1. No unit testing strategy means components cannot be tested in isolation
2. Testing as an afterthought rather than design constraint
3. No testability requirements for component design

**No dependency injection**: Direct component coupling (EventManager calling PostgreSQL, TicketSalesEngine calling Stripe) makes mocking impossible without runtime substitution hacks.

**No test interface design**: Missing abstractions like `PaymentGateway`, `EmailService`, `EventRepository` that would enable test doubles.

### 3.6 Configuration Management Issues

**Environment-specific configuration**: "環境変数は`.env`ファイルで管理（dev/staging/prodを手動切り替え）" creates multiple risks:
1. Manual switching is error-prone (production .env committed by accident)
2. No type safety or validation for configuration values
3. No support for feature flags or gradual rollout
4. Secrets management not addressed (Stripe API keys, JWT secrets)

## Stage 3: Cross-Cutting Concerns Detection

### Architectural Pattern: Missing Dependency Injection Strategy

**Cross-component impact**: Every component (EventManager, TicketSalesEngine, UserAuthService) instantiates its own dependencies. This creates:
- Impossible to substitute test implementations
- No single source of truth for configuration
- Tight coupling throughout the stack

**Recommendation**: Adopt a DI container pattern (e.g., InversifyJS, tsyringe) with interface-based abstractions:
```typescript
interface IEventRepository { /* ... */ }
interface IPaymentGateway { /* ... */ }
interface INotificationService { /* ... */ }
```

### Architectural Pattern: Missing Domain Layer Separation

**Root cause analysis**: The 3-layer architecture conflates business logic with service orchestration. TicketSalesEngine contains both:
- Domain logic (inventory rules, pricing validation)
- Infrastructure coordination (calling Stripe, sending emails)

This violates Clean Architecture principles and makes the core business rules dependent on external services.

**Recommendation**: Introduce a domain layer:
- `Domain Layer`: Pure business entities and rules (no infrastructure dependencies)
- `Application Layer`: Use case orchestration (coordinates domain + infrastructure)
- `Infrastructure Layer`: External integrations (Stripe, email, database)

### Cross-Cutting Concern: Transactional Consistency

**Identified pattern**: The purchase flow (§3, step 2-5) has no documented transaction boundary:
1. Check inventory (read)
2. Call Stripe (external API, non-transactional)
3. Issue ticket (write)
4. Generate QR code (side effect)
5. Send email (side effect)
6. Update event inventory (write in different component)

**Failure scenario**: Payment succeeds, but QR generation fails → customer charged but no ticket. No compensation mechanism documented.

**Recommendation**: Implement Saga pattern or two-phase commit:
- Phase 1: Reserve inventory + initiate payment
- Phase 2: On payment confirmation, finalize ticket issuance
- Compensation: Automatic refund if finalization fails

### Cross-Cutting Concern: Observability

**Missing tracing**: With multi-component workflows (purchase involves TicketSalesEngine → EventManager → Stripe → email), there's no distributed tracing design. CloudWatch logging alone cannot reconstruct request flow.

**Recommendation**: Add OpenTelemetry instrumentation with trace IDs propagated across service boundaries.

---

## Evaluation Scores

### 1. SOLID Principles & Structural Design: 2/5
**Critical violations**:
- Single Responsibility: TicketSalesEngine has 5+ responsibilities
- Dependency Inversion: Direct concrete class coupling throughout
- Interface Segregation: No interfaces defined for dependencies

**Impact**: Changing payment provider requires modifying TicketSalesEngine core logic. Testing any component requires database and external services.

### 2. Changeability & Module Design: 2/5
**Structural brittleness**:
- Change to payment logic affects TicketSalesEngine, which affects EventManager
- No stable interfaces to absorb change impact
- Data denormalization requires synchronized updates across multiple tables

**Impact**: Adding a new payment method (e.g., PayPal) requires modifying TicketSalesEngine's core purchase flow, risking regression in unrelated features.

### 3. Extensibility & Operational Design: 2/5
**Missing extension points**:
- No plugin architecture for payment providers
- No strategy pattern for notification channels
- Configuration management doesn't support feature flags

**Impact**: Cannot incrementally roll out new features or A/B test pricing strategies.

### 4. Error Handling & Observability: 2/5
**Insufficient design**:
- Only basic error categories defined
- No recovery or compensation strategies
- No distributed tracing for multi-component flows

**Impact**: Production incidents will be difficult to diagnose. Partial failures (payment succeeds, email fails) will leave system in inconsistent state.

### 5. Test Design & Testability: 1/5
**Critical gap**:
- "単体テストの方針は未定" with no DI or interfaces
- Components cannot be tested in isolation
- Testing treated as post-implementation activity

**Impact**: Cannot verify business logic without full integration environment. Refactoring will be high-risk due to lack of test coverage.

### 6. API & Data Model Quality: 3/5
**Mixed quality**:
- Data model reasonably structured but has denormalization issues
- API endpoints violate REST conventions
- Missing versioning strategy

**Impact**: API evolution will break clients. Data inconsistencies from denormalization will require manual cleanup.

---

## Priority Issues Summary

### Critical (Immediate Action Required)

**C1. Missing Dependency Injection Architecture**
- **Impact**: Cannot unit test any component; high coupling makes changes risky
- **Refactoring**: Introduce DI container and interface abstractions for all external dependencies
- **Effort**: High (architectural change)

**C2. TicketSalesEngine God Object**
- **Impact**: Single point of failure; testing impossible; any change risks entire purchase flow
- **Refactoring**: Decompose into domain services (InventoryService, PaymentProcessor, TicketIssuer, NotificationService)
- **Effort**: High (requires domain model redesign)

**C3. No Transactional Consistency Strategy**
- **Impact**: Payment succeeds but ticket fails → financial loss and customer support burden
- **Refactoring**: Implement Saga pattern with compensation logic
- **Effort**: Medium (application-level pattern)

### Significant (Address Before Production)

**S1. Data Denormalization Risks**
- **Impact**: Update anomalies will corrupt data over time
- **Refactoring**: Remove denormalized fields; use database views or application-level joins for read optimization
- **Effort**: Medium (schema migration + code changes)

**S2. Testing Strategy Undefined**
- **Impact**: Cannot safely refactor or extend system
- **Refactoring**: Define unit/integration/E2E boundaries; add test interfaces
- **Effort**: Medium (planning + implementation)

**S3. API Design Violations**
- **Impact**: Non-standard API makes integration difficult; no evolution path
- **Refactoring**: Add versioning; fix endpoint naming to follow REST conventions
- **Effort**: Low (routing changes)

### Moderate (Technical Debt)

**M1. Configuration Management**
- **Impact**: Manual .env switching causes deployment errors
- **Refactoring**: Use environment-based config loading (e.g., AWS Parameter Store, Kubernetes ConfigMaps)
- **Effort**: Low

**M2. Missing Observability Patterns**
- **Impact**: Difficult to debug production issues
- **Refactoring**: Add OpenTelemetry with trace correlation
- **Effort**: Medium

---

## Positive Aspects

1. **Clear scope definition**: System boundaries and user types are well-defined
2. **Technology choices**: Modern stack (TypeScript, PostgreSQL, Redis) suitable for domain
3. **Basic security considerations**: HTTPS, SQL injection prevention via ORM
4. **Deployment automation**: Blue/Green deployment strategy defined

---

## Recommendations Summary

### Immediate (Before Implementation)

1. **Introduce layered architecture with DI**: Separate domain, application, and infrastructure layers with dependency injection
2. **Redesign TicketSalesEngine**: Decompose into single-responsibility services
3. **Define transactional boundaries**: Add Saga pattern for purchase flow consistency

### Before Production

4. **Normalize data model**: Remove denormalized fields; use read-optimized views
5. **Define comprehensive testing strategy**: Unit/integration/E2E with clear boundaries
6. **Add API versioning and fix REST violations**

### Post-Launch Optimization

7. **Implement distributed tracing**: Add OpenTelemetry for observability
8. **Enhance configuration management**: Move secrets to secure store; add feature flags
9. **Document error recovery procedures**: Define runbooks for partial failure scenarios

---

## Conclusion

The current design has **fundamental structural issues** that will severely impact long-term maintainability. The lack of dependency injection, god object anti-pattern in TicketSalesEngine, and undefined testing strategy are critical blockers that must be addressed before implementation begins.

The most urgent action is **architectural refactoring to introduce layered design with dependency injection**. Without this foundation, the system will be difficult to test, change, and extend—leading to high development costs and production incidents.

Positive aspects include clear requirements and appropriate technology choices, but these cannot compensate for structural design weaknesses that will compound over time.

**Overall Structural Quality: 2/5 (Requires Major Refactoring)**
