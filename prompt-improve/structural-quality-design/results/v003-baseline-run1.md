# Structural Quality Design Review: Payment Gateway System

## Overall Assessment

This design document presents a payment gateway system with several critical structural issues that significantly impact long-term maintainability, testability, and sustainability. The architecture violates fundamental design principles and lacks clear separation of concerns.

---

## Evaluation Scores

| Criterion | Score | Justification |
|-----------|-------|---------------|
| SOLID Principles & Structural Design | 2/5 | Multiple violations including Single Responsibility Principle (SRP) in PaymentService and tight coupling in PaymentController |
| Changeability & Module Design | 2/5 | High coupling with external SDKs, poor module boundaries, data model includes unnecessary denormalization |
| Extensibility & Operational Design | 2/5 | Hardcoded provider logic, no clear extension mechanism for adding new payment providers |
| Error Handling & Observability | 2/5 | Simplistic error handling strategy with no retry logic, excessive logging of sensitive data |
| Test Design & Testability | 1/5 | No test strategy defined, direct SDK calls prevent effective mocking |
| API & Data Model Quality | 3/5 | Basic RESTful design present but lacks versioning and backward compatibility strategy |

**Average Score: 2.0/5**

---

## Critical Issues (Priority 1)

### 1. Severe Single Responsibility Principle (SRP) Violation in PaymentService

**Issue:**
PaymentService (Section 3, line 48-57) is responsible for an excessive number of unrelated concerns:
- Payment business logic
- Transaction management
- Refund processing
- Subscription management
- Webhook delivery logic
- Email notification sending
- Merchant balance calculation
- Rate limit checking

**Impact:**
- **Changeability**: Any modification to one responsibility (e.g., email notification) requires touching the same class handling critical payment logic, increasing risk of regression
- **Testability**: Testing payment logic requires setting up dependencies for email, webhooks, rate limiting, and balance calculations
- **Team Collaboration**: Multiple developers cannot work independently on different features without merge conflicts
- **Code Complexity**: The class will grow to thousands of lines, making it incomprehensible

**Recommendation:**
Decompose PaymentService into focused services:
```
- PaymentProcessingService (payment execution only)
- RefundService (refund logic)
- SubscriptionService (subscription management)
- NotificationService (email and webhook orchestration)
- MerchantAccountService (balance and rate limiting)
```

Each service should have a single, well-defined responsibility.

**Reference:** Section 3, PaymentService component description

---

### 2. Tight Coupling: Direct SDK Calls in Controller Layer

**Issue:**
PaymentController (Section 3, line 46) directly calls Stripe/PayPal SDKs, bypassing the Service layer. This creates:
- **Layer violation**: Controller should delegate to Service, not directly interact with external APIs
- **Tight coupling**: Controller becomes dependent on specific provider SDKs
- **Impossible mocking**: Cannot test controller without real provider connections

**Impact:**
- **Changeability**: Switching or adding payment providers requires modifying controller code
- **Testability**: Cannot unit test controller endpoints without live API credentials
- **Violates Dependency Inversion Principle**: Controller depends on concrete implementations (SDKs) rather than abstractions

**Recommendation:**
1. Remove all SDK calls from PaymentController
2. Create a `PaymentProviderGateway` interface:
```java
interface PaymentProviderGateway {
    PaymentResult charge(PaymentRequest request);
    RefundResult refund(RefundRequest request);
}
```
3. Implement provider-specific gateways:
```java
class StripePaymentGateway implements PaymentProviderGateway { ... }
class PayPalPaymentGateway implements PaymentProviderGateway { ... }
```
4. Controller calls Service layer only, Service layer uses PaymentProviderGateway abstraction

**Reference:** Section 3, PaymentController description (line 46)

---

### 3. Missing Abstraction Layer for Payment Providers

**Issue:**
The design lacks an abstraction layer for payment providers. Providers are selected via string-based discrimination (Section 5, line 145: `"provider": "stripe"`), suggesting conditional logic scattered throughout the codebase.

**Impact:**
- **Open/Closed Principle Violation**: Adding a new provider requires modifying existing code rather than extending
- **Changeability**: Each new provider adds branching complexity to existing services
- **Error-Prone**: String-based provider selection is fragile and prevents compile-time validation

**Recommendation:**
Implement a Strategy Pattern with Factory:
1. Define provider abstraction (as shown above)
2. Create `PaymentProviderFactory` to return appropriate implementation based on provider name
3. All payment logic delegates to the abstraction, never directly to SDKs

**Reference:** Section 3 (data flow), Section 5 (API design)

---

### 4. Data Model Denormalization: Merchant Information in Payment Table

**Issue:**
The `payments` table (Section 4, lines 82-83) stores redundant merchant information:
- `merchant_name`
- `merchant_email`

This is denormalization without documented justification.

**Impact:**
- **Data Integrity**: Merchant name/email changes require updating all historical payment records, risking inconsistency
- **Storage Waste**: Duplicate data across potentially millions of records
- **Changeability**: Adding merchant fields requires schema migration for payments table

**Recommendation:**
1. Create a separate `merchants` table with all merchant attributes
2. `payments` table should only reference `merchant_id` (FK)
3. If merchant snapshot at payment time is required for regulatory reasons, document this explicitly as a design decision and consider a separate `payment_merchant_snapshots` table

**Reference:** Section 4, Payment table definition

---

## Significant Issues (Priority 2)

### 5. No Test Strategy Defined

**Issue:**
Section 6, line 179 states: "現時点では未定義。今後検討予定。" (Currently undefined. To be considered in the future.)

**Impact:**
- **Quality Risk**: No guidance on how to verify system correctness
- **Regression Risk**: Refactoring without tests is dangerous
- **Technical Debt**: Retrofitting tests is significantly more expensive than test-driven development

**Recommendation:**
Define test strategy immediately:
- **Unit Tests**: Test service layer logic with mocked repositories and provider gateways (target: 80%+ coverage)
- **Integration Tests**: Test database interactions with test containers (PostgreSQL, MongoDB)
- **Contract Tests**: Verify provider SDK integration with recorded responses (Wiremock or similar)
- **E2E Tests**: Test critical payment flows end-to-end in staging environment

**Reference:** Section 6, line 179

---

### 6. Configuration Management Anti-Pattern: Hardcoded Credentials

**Issue:**
Section 6, line 185 states environment variables will be used, but then mentions "データベース接続情報、決済プロバイダーAPIキーをハードコード" (database connection information and provider API keys will be hardcoded).

**Impact:**
- **Security Risk**: Credentials in source code can be leaked via version control
- **Changeability**: Rotating credentials requires code changes and redeployment
- **Environment Mismatch**: Difficult to use different credentials per environment

**Recommendation:**
1. Use AWS Secrets Manager or Parameter Store for sensitive configuration
2. Never hardcode credentials in application code
3. Implement a configuration service that loads secrets at runtime
4. Document configuration loading strategy explicitly in design

**Reference:** Section 6, Deployment section (line 185)

---

### 7. Excessive Logging of Sensitive Data

**Issue:**
Section 6, line 176 states: "決済リクエスト/レスポンスの全フィールドをログ出力" (Log all fields of payment requests/responses).

**Impact:**
- **Compliance Violation**: Logging full payment data likely violates PCI DSS requirements
- **Security Risk**: Logs containing sensitive data are high-value targets
- **Privacy Risk**: Customer PII (email, names) should not be logged unnecessarily

**Recommendation:**
1. Define logging policy that explicitly excludes sensitive fields
2. Implement structured logging with field-level control
3. Log only transaction IDs and status for debugging, not full payloads
4. If detailed logging is required for debugging, use tokenized/redacted representations

**Reference:** Section 6, Logging section (line 176)

---

### 8. Missing Error Classification and Retry Strategy

**Issue:**
Section 6, line 169 describes simplistic error handling: "決済プロバイダーAPIエラー時は即座にクライアントへエラーレスポンス返却" (Return error response immediately to client on provider API error).

**Impact:**
- **User Experience**: Transient network errors result in payment failures that could have succeeded with retry
- **Revenue Loss**: Retryable errors (e.g., 503 from provider) cause unnecessary payment failures
- **Operational Burden**: No distinction between client errors (non-retryable) and server errors (retryable)

**Recommendation:**
1. Classify errors into categories:
   - **Client errors (4xx)**: Invalid request, return immediately
   - **Transient errors (503, timeout)**: Implement exponential backoff retry (3 attempts)
   - **Server errors (5xx)**: Log, alert, return failure
2. Implement circuit breaker pattern for provider resilience
3. Define idempotency strategy for safe retries
4. Document error response format with error codes

**Reference:** Section 6, Error Handling section (line 169)

---

## Moderate Issues (Priority 3)

### 9. Lack of API Versioning Strategy

**Issue:**
Section 5 (API Design) does not specify versioning strategy for the REST API.

**Impact:**
- **Breaking Changes**: No safe way to evolve API without breaking existing clients
- **Backward Compatibility**: Cannot maintain multiple API versions for gradual migration

**Recommendation:**
- Use URI versioning: `/v1/payments/create`, `/v2/payments/create`
- Document deprecation policy (e.g., support N-1 versions for 12 months)
- Include version in response headers

**Reference:** Section 5, API Design

---

### 10. Unclear Transaction Boundary Definition

**Issue:**
PaymentService is described as handling "トランザクション管理" (transaction management) but the design does not specify transaction boundaries or isolation levels.

**Impact:**
- **Data Consistency Risk**: Without clear transaction boundaries, race conditions may corrupt payment state
- **Concurrency Issues**: No guidance on handling concurrent refund requests for the same payment

**Recommendation:**
1. Document transaction boundaries explicitly:
   - Payment creation: single transaction (insert payment, send to provider, update status)
   - Refund: transaction spans payment update + refund insert
2. Specify isolation level requirements (e.g., READ_COMMITTED for payment queries)
3. Consider optimistic locking for concurrent updates to payment status

**Reference:** Section 3, PaymentService description

---

### 11. Lack of State Machine for Payment Status Transitions

**Issue:**
Payment status (Section 4, line 86) allows values: pending/success/failed/refunded, but no state transition rules are documented.

**Impact:**
- **Invalid States**: Without rules, code could transition payment from "failed" to "success"
- **Business Logic Errors**: Unclear whether "refunded" payment can be refunded again
- **Testability**: Cannot verify correct state transitions without specification

**Recommendation:**
1. Document valid state transitions:
   ```
   pending → success
   pending → failed
   success → refunded (partial or full)
   ```
2. Implement state machine validation in domain model
3. Prevent invalid transitions at application level

**Reference:** Section 4, Payment table

---

## Minor Improvements (Priority 4)

### 12. Webhook Publisher Design Lacks Detail

**Issue:**
WebhookPublisher (Section 3, line 63) is described only as "RabbitMQへのメッセージ送信" with no detail on message format, routing, or error handling.

**Recommendation:**
- Define webhook message schema (JSON structure)
- Specify routing strategy (topic exchange? direct?)
- Document retry policy for failed webhook deliveries
- Consider implementing dead letter queue for failed webhooks

**Reference:** Section 3, WebhookPublisher

---

### 13. Subscription Next Billing Date Calculation Unclear

**Issue:**
Subscription table (Section 4, line 99) includes `next_billing_date` but no service is explicitly responsible for calculating and updating this field.

**Recommendation:**
- Document which component updates `next_billing_date`
- Consider scheduled job for recurring billing execution
- Define behavior when billing fails (retry policy, grace period)

**Reference:** Section 4, Subscription table

---

## Positive Aspects

1. **PCI DSS Compliance Awareness**: Section 7 correctly identifies that card information should not be stored, using tokenization instead
2. **Clear 3-Layer Architecture**: The intent to use Controller → Service → Repository is stated clearly
3. **Multi-AZ Database Configuration**: RDS Multi-AZ provides good foundational resilience
4. **Authentication Strategy**: JWT + API Key approach is reasonable for merchant authentication

---

## Summary of Recommended Refactoring Priorities

1. **Immediate (Week 1-2)**:
   - Decompose PaymentService into focused services
   - Introduce PaymentProviderGateway abstraction
   - Remove SDK calls from PaymentController
   - Define test strategy

2. **Short-term (Week 3-4)**:
   - Implement error classification and retry logic
   - Fix configuration management (remove hardcoded credentials)
   - Normalize Payment table (remove redundant merchant fields)
   - Define logging policy to exclude sensitive data

3. **Medium-term (Month 2)**:
   - Implement API versioning
   - Define transaction boundaries
   - Implement payment state machine
   - Document webhook delivery architecture

---

## Conclusion

The current design has significant structural weaknesses that will severely impact long-term sustainability. The most critical issues are:
1. Massive SRP violation in PaymentService
2. Tight coupling due to direct SDK calls in wrong layers
3. Missing provider abstraction layer

These issues must be addressed before implementation begins. The architecture requires substantial refactoring to achieve acceptable maintainability and testability.

**Recommended Action**: Revise design document to address all Priority 1 and Priority 2 issues before proceeding to implementation phase.
