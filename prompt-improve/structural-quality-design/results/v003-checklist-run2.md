# Structural Quality Design Review - Payment Gateway System

## Overall Assessment

This design document presents significant structural risks that will impede long-term maintainability and sustainability. The architecture violates fundamental design principles (SOLID, layering) and lacks comprehensive treatment of cross-cutting architectural concerns essential for production payment systems.

## Evaluation Scores

### 1. SOLID Principles & Structural Design: 2/5

**Critical Issues:**

**Massive Single Responsibility Principle Violation in PaymentService (Section 3)**
- PaymentService consolidates 8 distinct responsibilities: payment business logic, transaction management, status updates, refunds, subscriptions, webhook delivery, email notifications, merchant balance calculation, and rate limiting
- This creates a god object that will become increasingly difficult to test, modify, and reason about
- **Impact**: Any change to one responsibility (e.g., webhook delivery logic) requires modifying and re-testing a class handling 7 other unrelated concerns. This creates high risk of regression and makes parallel development impossible.
- **Recommendation**: Decompose into specialized services:
  - `PaymentService` (core payment processing only)
  - `RefundService` (refund-specific logic)
  - `SubscriptionService` (subscription lifecycle)
  - `NotificationService` (webhook + email)
  - `MerchantAccountService` (balance calculation, rate limiting)

**Critical Layering Violation: PaymentController Bypasses Service Layer (Section 3)**
- PaymentController directly invokes Stripe/PayPal SDKs ("決済プロバイダーとの通信"), bypassing the service layer
- This duplicates provider integration logic across controller and service layers
- **Impact**: Impossible to enforce consistent error handling, retry logic, or circuit breaking across all provider calls. Adding a new provider requires modifying both controller and service layers.
- **Recommendation**: Extract provider SDK calls to a dedicated abstraction layer (`PaymentProviderAdapter` interface with `StripeAdapter`, `PayPalAdapter` implementations). Controller should only delegate to PaymentService.

**Tight Coupling to Concrete Provider SDKs**
- No abstraction layer between business logic and third-party SDKs (Stripe Java SDK, PayPal SDK mentioned in Section 2)
- Changing providers or adding new ones requires modifying core service classes
- **Impact**: Provider-specific exception types, data models, and API idioms will leak throughout the codebase. Testing requires mocking vendor SDK classes directly.
- **Recommendation**: Define provider-agnostic domain interfaces (`PaymentProvider`, `RefundProvider`, `SubscriptionProvider`) that abstract SDK-specific details.

### 2. Changeability & Module Design: 2/5

**Critical Issues:**

**Data Denormalization Without Rationale (Section 4)**
- `payments` table duplicates merchant information (merchant_name, merchant_email) from presumed `merchants` table
- No justification provided for this denormalization
- **Impact**: Merchant name/email changes require updating all historical payment records, or accepting data inconsistency. Query performance rationale (if any) is undocumented, making future optimization decisions impossible.
- **Recommendation**: Remove denormalized columns or explicitly document the read-heavy query pattern that justifies this trade-off and specify a synchronization strategy.

**Undefined Schema Evolution Strategy**
- No versioning strategy for database tables or API contracts
- **Impact**: Adding new payment methods, statuses, or required fields will require destructive migrations that break backward compatibility with deployed clients and running jobs.
- **Recommendation**: Adopt additive schema changes (nullable columns, optional fields) and API versioning from day one.

**Significant Issues:**

**State Management Not Specified**
- No indication whether services are stateless or maintain session state
- **Impact**: Cannot determine if horizontal scaling is safe. Sticky sessions may be required but undocumented.
- **Recommendation**: Explicitly state statelessness of all service components and document any session state management in Spring Security context.

### 3. Extensibility & Operational Design: 2/5

**Critical Issues:**

**Hardcoded Configuration in Environment Variables (Section 6)**
- Database credentials and provider API keys are "ハードコード" via environment variables
- No configuration validation or secret management strategy
- **Impact**: Secret rotation requires redeploying containers. Misconfigured credentials in production can only be detected at runtime when payment calls fail.
- **Recommendation**:
  - Use AWS Secrets Manager or Parameter Store for sensitive configuration
  - Implement configuration validation at application startup with fail-fast behavior
  - Document configuration precedence: Secrets Manager > Environment Variables > Default values

**Significant Issues:**

**Provider Extension Mechanism Unclear**
- Adding support for Square or other providers requires modifying PaymentService and PaymentController
- No extension point defined
- **Impact**: Each new provider integration requires changes to core classes, increasing risk of regression in existing provider support.
- **Recommendation**: Strategy pattern with `PaymentProviderRegistry` that dynamically resolves providers by name.

**Incremental Migration Path Not Defined**
- No discussion of how to migrate existing merchants to new API versions or providers
- **Impact**: Breaking changes cannot be rolled out safely. All merchants must upgrade simultaneously.
- **Recommendation**: Support simultaneous execution of old and new API versions using URL path versioning (`/v1/payments`, `/v2/payments`).

### 4. Error Handling & Observability: 2/5

**Critical Issues:**

**Insufficient Error Context for Payment Failures (Section 6)**
- "決済プロバイダーAPIエラー時は即座にクライアントへエラーレスポンス返却" provides no guidance on error classification
- Transient errors (network timeout, rate limiting) are indistinguishable from permanent errors (invalid card, insufficient funds)
- **Impact**: Clients cannot implement appropriate retry logic. Merchants cannot distinguish between "retry immediately", "retry with backoff", and "user action required" scenarios.
- **Recommendation**: Define error taxonomy:
  - Transient (5xx from provider, timeout) → HTTP 503 with Retry-After header
  - Client error (invalid card, expired token) → HTTP 400 with structured error codes
  - Permanent failure (insufficient funds) → HTTP 402 with user-facing message
  - Include provider error codes in structured response for support troubleshooting

**Sensitive Data Logging Risk (Section 6)**
- "決済リクエスト/レスポンスの全フィールドをログ出力（デバッグ用）" will log PII (customer email, card tokens, amounts)
- Violates PCI DSS and GDPR requirements
- **Impact**: Production log analysis exposes sensitive financial data. Regulatory audit failure.
- **Recommendation**: Implement field-level redaction for PII (card_token → "tok_***", email → "***@example.com"). Use structured logging with explicit field whitelists for payment contexts.

**Significant Issues:**

**Correlation ID Strategy Not Defined**
- No mention of request tracing across service layer, provider calls, and webhook delivery
- **Impact**: Debugging distributed failures (e.g., payment succeeded at provider but webhook delivery failed) requires manual log correlation across multiple systems.
- **Recommendation**: Generate correlation ID (UUID) at API gateway, propagate through MDC/ThreadLocal, include in all log statements and webhook payloads.

**No Circuit Breaker for Provider Calls**
- Provider SDK calls have no fault isolation mechanism
- **Impact**: Provider outage (e.g., Stripe 503 for 30 seconds) will cascade to thread pool exhaustion, blocking all payment processing including healthy providers.
- **Recommendation**: Implement Resilience4j circuit breaker per provider with fallback to alternative providers where applicable.

### 5. Test Design & Testability: 1/5

**Critical Issues:**

**Test Strategy Completely Undefined (Section 6)**
- "現時点では未定義。今後検討予定" abdicates critical architectural decision
- **Impact**: Implementation will proceed without testability considerations, leading to:
  - No dependency injection design (cannot mock provider SDKs)
  - No test database isolation strategy (shared test data corruption)
  - No contract testing with providers (schema drift undetected)
- **Recommendation**: Define before implementation begins:
  - Unit tests mock provider adapters via interfaces
  - Integration tests use provider sandbox APIs
  - Contract tests validate request/response schemas against provider documentation
  - E2E tests use Testcontainers for PostgreSQL and RabbitMQ

**Provider SDK Direct Invocation Prevents Testing**
- Controller-level provider calls cannot be mocked without PowerMock
- **Impact**: Controller tests must hit real provider sandbox APIs, making tests slow, flaky, and dependent on external service availability.
- **Recommendation**: As noted in criterion 1, extract provider calls behind interfaces.

### 6. API & Data Model Quality: 3/5

**Cross-Cutting Architectural Concerns Checklist Results:**

**API Evolution & Compatibility: ❌ Missing**
- [ ] API versioning strategy defined → **Not addressed**
- [ ] Backward compatibility guarantees specified → **Not addressed**
- [ ] Breaking change handling process documented → **Not addressed**
- [ ] Client migration path considered → **Not addressed**

**Change Propagation & Impact: ❌ Missing**
- [ ] Change propagation paths between components identified → **Not addressed**
- [ ] Interface stability contracts defined → **Not addressed**
- [ ] Dependency update strategy specified → **Not addressed**
- [ ] Data schema evolution strategy documented → **Partially: "今後検討予定" indicates awareness but no concrete strategy**

**Configuration Management: ⚠️ Incomplete**
- [ ] Configuration sources and precedence defined → **Partial: mentions environment variables but no precedence rules**
- [ ] Environment-specific configuration strategy specified → **Yes: dev/staging/production via environment variables**
- [ ] Configuration validation approach documented → **Not addressed**
- [ ] Sensitive configuration handling addressed → **Critical flaw: hardcoded in environment variables**

**Data Consistency & Integrity: ⚠️ Incomplete**
- [ ] Data ownership boundaries defined → **Not addressed (merchant data ownership unclear)**
- [ ] Consistency guarantees specified (strong/eventual) → **Not addressed**
- [ ] Transaction boundary design documented → **Implicit: "トランザクション管理" in PaymentService but no detail**
- [ ] Data duplication/denormalization rationale provided → **Missing: merchant data duplicated without justification**

**Observability & Diagnostics: ⚠️ Incomplete**
- [ ] Logging strategy defined → **Partial: log levels per environment, but dangerous "全フィールド" approach**
- [ ] Tracing/correlation ID propagation specified → **Not addressed**
- [ ] Metrics collection points identified → **Not addressed**
- [ ] Error context preservation strategy documented → **Insufficient: no error classification**

**Significant Issues:**

**RESTful Inconsistency**
- `POST /subscriptions/{id}/pause` and `/resume` endpoints violate REST principles (should be PATCH with status field)
- `DELETE /subscriptions/{id}` performs logical deletion (sets status) rather than hard delete, misusing HTTP semantics
- **Impact**: Client developers will have inconsistent mental model of API behavior.
- **Recommendation**: Use `PATCH /subscriptions/{id}` with `{"status": "paused"}` payload.

**API Versioning Absent**
- No version indicator in URLs, headers, or content negotiation
- **Impact**: First breaking change will require coordinated flag-day migration of all clients.
- **Recommendation**: Version in URL path (`/v1/payments/create`) for simplicity and client cache compatibility.

**Moderate Issues:**

**Timestamp Timezone Not Specified (Section 4)**
- `created_at` and `updated_at` columns do not specify UTC storage
- **Impact**: Multi-region deployments may store local timestamps, breaking global transaction history queries.
- **Recommendation**: Explicitly document UTC storage, use `TIMESTAMP WITH TIME ZONE` in PostgreSQL.

**Missing Idempotency Key Support**
- No idempotency mechanism for payment creation
- **Impact**: Network retries after timeout will create duplicate charges.
- **Recommendation**: Require `Idempotency-Key` header, store with payment record, return 409 Conflict on duplicate.

## Positive Structural Aspects

1. **Clear Component Boundaries**: Controller → Service → Repository separation provides good starting point for refactoring (once SRP violations are addressed)
2. **Asynchronous Webhook Delivery**: RabbitMQ-based decoupling prevents webhook delivery failures from blocking payment processing response
3. **Foreign Key Constraint on Refunds**: `refunds.payment_id` referential integrity prevents orphaned refund records
4. **Multi-AZ Database Configuration**: RDS Multi-AZ (Section 7) demonstrates awareness of high availability needs

## Summary

This design requires substantial revision before implementation. The most critical issues are:

1. **SRP violation in PaymentService** (splits into 5 services)
2. **Layering violation** (extract provider abstraction)
3. **Hardcoded secrets** (adopt secret management service)
4. **PII logging risk** (implement field-level redaction)
5. **Test strategy absence** (define before implementation)
6. **Cross-cutting concerns** (address all checklist items, particularly API versioning and configuration validation)

Without addressing these structural defects, the system will accumulate technical debt rapidly, making future feature development increasingly expensive and risky.
