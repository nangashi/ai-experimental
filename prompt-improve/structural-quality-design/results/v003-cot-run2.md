# Structural Quality Design Review: Payment Gateway System

## Executive Summary

This review identifies critical architectural issues that fundamentally compromise the system's long-term sustainability. The design exhibits severe violations of SOLID principles, tight coupling to external dependencies, and missing essential architectural elements for a payment gateway system.

**Overall Structural Health: 2.1/5.0** (Critical structural deficiencies requiring immediate architectural refactoring)

## Stage 1: Overall Structure Comprehension

The Payment Gateway System employs a nominal 3-layer architecture (API → Service → Data Access). However, detailed analysis reveals:

1. **Architectural Pattern**: Traditional 3-layer architecture with Spring Boot/WebFlux
2. **Primary Boundaries**: API Layer (PaymentController), Service Layer (PaymentService), Data Access Layer (PaymentRepository)
3. **Key Dependencies**: Direct coupling to Stripe/PayPal SDKs, RabbitMQ for webhooks, PostgreSQL/MongoDB for persistence
4. **Critical Observation**: The architecture claims separation of concerns but violates this through direct SDK calls in the controller layer and massive responsibility concentration in the service layer

## Stage 2: Detailed Section Analysis

### 1. SOLID Principles & Structural Design: **1/5 (Critical)**

**Critical Issue 1: Massive Single Responsibility Principle Violation in PaymentService**

Section Reference: "3. アーキテクチャ設計 → PaymentService"

The PaymentService component aggregates at least 8 distinct responsibilities:
- Payment business logic
- Transaction management
- Payment status updates
- Refund processing
- Subscription management
- Webhook delivery logic
- Email notification
- Merchant balance calculation
- Rate limiting

**Impact**: This creates a God Object anti-pattern with the following consequences:
- Any change to subscription logic requires modifying the same class handling payment processing
- Testing becomes exponentially complex as the class has 8+ reasons to change
- Impossible to scale individual concerns independently (e.g., scaling webhook delivery separately from payment processing)
- High risk of merge conflicts in team environments

**Refactoring Strategy**:
```
PaymentService (coordination only)
├── PaymentProcessor (payment execution)
├── RefundProcessor (refund logic)
├── SubscriptionManager (subscription lifecycle)
├── NotificationService (webhook + email)
├── MerchantAccountService (balance calculation)
└── RateLimitingService (rate limit checks)
```

**Critical Issue 2: Direct External Dependency in Controller Layer**

Section Reference: "3. アーキテクチャ設計 → PaymentController" - "Stripe/PayPal SDKの直接呼び出し（決済プロバイダーとの通信）"

The PaymentController directly invokes Stripe/PayPal SDKs, violating the Dependency Inversion Principle and creating architectural layering violations.

**Impact**:
- Controller layer couples to volatile external dependencies
- Impossible to unit test the controller without real SDK instances
- Cannot switch payment providers without modifying controller code
- Violates the stated 3-layer architecture (controller should only handle HTTP concerns)

**Refactoring Strategy**:
```java
// Define provider abstraction
interface PaymentProviderGateway {
    PaymentResult processPayment(PaymentRequest request);
    RefundResult processRefund(RefundRequest request);
}

// Implementations
class StripePaymentGateway implements PaymentProviderGateway { ... }
class PayPalPaymentGateway implements PaymentProviderGateway { ... }

// Controller delegates to service, service uses abstraction
PaymentController → PaymentService → PaymentProviderGateway
```

**Significant Issue 3: Missing Provider Abstraction Strategy**

Section Reference: "3. アーキテクチャ設計 → 主要コンポーネント"

The design mentions "複数の決済プロバイダー（Stripe、PayPal、Square等）を統合" but provides no abstraction layer or strategy pattern implementation.

**Impact**:
- Adding a new provider (Square) requires modifying existing payment processing code
- Each provider's SDK has different APIs, error handling, and retry semantics
- No unified error handling across providers
- Cannot A/B test providers or implement fallback strategies

**Refactoring Strategy**: Implement Strategy Pattern with Provider Registry:
```
PaymentProviderRegistry
├── registerProvider(name, gateway)
├── getProvider(name) → PaymentProviderGateway

PaymentProviderGateway (interface)
├── StripeAdapter
├── PayPalAdapter
└── SquareAdapter (future)
```

### 2. Changeability & Module Design: **2/5 (Significant Issues)**

**Critical Issue 4: Cross-Component Change Propagation - No Versioning Strategy**

Section Reference: "5. API設計 → エンドポイント一覧"

The API design exposes endpoints without any versioning mechanism (`/payments/create`, `/subscriptions/create`).

**Impact**:
- Adding a new required field to payment creation breaks all existing merchant integrations
- Cannot evolve the API without breaking backward compatibility
- No migration path for merchants to upgrade from v1 to v2
- Violates one of the core promises of a payment gateway (stable integration)

**Cross-Cutting Impact**: This affects:
- API Layer (endpoint URLs)
- Request/Response DTOs (data contracts)
- Service Layer (request processing logic)
- Database Schema (if new fields added)

**Refactoring Strategy**:
```
Versioned endpoints:
POST /v1/payments/create
POST /v2/payments/create (future - supports new fields)

Version routing:
- Header-based: Accept: application/vnd.paymentgateway.v2+json
- URL-based: /v1/..., /v2/...
Recommendation: URL-based for easier merchant debugging
```

**Significant Issue 5: Merchant Information Denormalization**

Section Reference: "4. データモデル → Payment (payments テーブル)"

The `payments` table duplicates merchant information (merchant_name, merchant_email) from what should be a separate `merchants` table.

**Impact**:
- Merchant email change requires updating millions of payment records
- Data inconsistency risk (different payments showing different merchant names)
- Violates database normalization principles (2NF violation)
- Increased storage costs (repeat data in every payment row)

**Refactoring Strategy**:
```sql
-- Create merchants table
CREATE TABLE merchants (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    api_key_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL
);

-- Update payments table
ALTER TABLE payments
    DROP COLUMN merchant_name,
    DROP COLUMN merchant_email,
    ADD CONSTRAINT fk_merchant
        FOREIGN KEY (merchant_id) REFERENCES merchants(id);
```

**Moderate Issue 6: Missing State Machine for Payment Status**

Section Reference: "4. データモデル → Payment (payments テーブル)" - status VARCHAR(20) with values (pending/success/failed/refunded)

The status field is a free-form VARCHAR without enforcement of valid state transitions.

**Impact**:
- No prevention of invalid transitions (e.g., success → pending)
- Cannot audit who changed status and why
- Debugging payment issues requires manual log analysis
- Risk of data corruption from application bugs

**Refactoring Strategy**:
```java
enum PaymentStatus {
    PENDING(Set.of(SUCCESS, FAILED)),
    SUCCESS(Set.of(REFUNDED)),
    FAILED(Set.of()),
    REFUNDED(Set.of());

    private final Set<PaymentStatus> allowedTransitions;

    void validateTransition(PaymentStatus next) {
        if (!allowedTransitions.contains(next)) {
            throw new InvalidStatusTransitionException(...);
        }
    }
}

// Audit trail table
CREATE TABLE payment_status_history (
    id BIGINT PRIMARY KEY,
    payment_id BIGINT REFERENCES payments(id),
    from_status VARCHAR(20),
    to_status VARCHAR(20),
    changed_by VARCHAR(100),
    changed_at TIMESTAMP,
    reason TEXT
);
```

### 3. Extensibility & Operational Design: **2/5 (Significant Issues)**

**Critical Issue 7: Environment Configuration Hardcoded**

Section Reference: "6. 実装方針 → デプロイメント方針" - "環境変数で dev/staging/production の切り替え実施（データベース接続情報、決済プロバイダーAPIキー等をハードコード）"

This statement is contradictory and critically flawed. It mentions using environment variables but then states credentials will be hardcoded.

**Impact**:
- Exposure of production API keys in source code (PCI DSS violation)
- Cannot rotate credentials without code deployment
- High security risk if repository is compromised
- Violates the Twelve-Factor App principle of config separation

**Refactoring Strategy**:
```java
// Use Spring Boot externalized configuration
@ConfigurationProperties(prefix = "payment.providers.stripe")
public class StripeConfig {
    private String apiKey;
    private String webhookSecret;
    // Loaded from environment variables or AWS Secrets Manager
}

// Environment-specific configuration
dev: AWS Secrets Manager → dev/payment/stripe/apikey
staging: AWS Secrets Manager → staging/payment/stripe/apikey
production: AWS Secrets Manager → production/payment/stripe/apikey
```

**Significant Issue 8: Missing Feature Toggle Mechanism**

Section Reference: "3. アーキテクチャ設計" (implicit gap - no mention of feature management)

For a payment gateway handling real money, there's no mechanism to:
- Gradually roll out new payment providers (0% → 10% → 50% → 100%)
- Emergency disable a failing provider
- A/B test provider performance

**Impact**:
- All-or-nothing deployment risk for new providers
- Cannot perform canary deployments for payment logic changes
- No circuit breaker for failing external dependencies
- Increased blast radius of bugs

**Refactoring Strategy**:
```java
interface FeatureToggleService {
    boolean isProviderEnabled(String provider, String merchantId);
    int getProviderTrafficPercentage(String provider);
}

// Usage in provider selection
if (!featureToggle.isProviderEnabled("square", merchantId)) {
    throw new ProviderDisabledException("Square is currently disabled");
}
```

### 4. Error Handling & Observability: **2/5 (Significant Issues)**

**Significant Issue 9: Insufficient Error Classification**

Section Reference: "6. 実装方針 → エラーハンドリング方針"

The error handling strategy only distinguishes by HTTP status code (400, 500), not by business recoverability.

**Impact**:
- Cannot distinguish transient errors (retry) from permanent failures (abort)
- No guidance for merchants on how to handle different error types
- Difficult to implement intelligent retry logic
- Poor debugging experience for merchants

**Refactoring Strategy**:
```java
// Define error taxonomy
enum ErrorCategory {
    TRANSIENT_PROVIDER_ERROR,    // Retry after delay
    PERMANENT_VALIDATION_ERROR,  // Fix request and resubmit
    FRAUD_DETECTION_ERROR,       // Do not retry
    SYSTEM_ERROR                 // Contact support
}

// Error response structure
{
    "error_code": "PROVIDER_TIMEOUT",
    "error_category": "TRANSIENT_PROVIDER_ERROR",
    "message": "Stripe API timed out",
    "retry_after_seconds": 30,
    "merchant_action": "RETRY_WITH_BACKOFF"
}
```

**Significant Issue 10: Sensitive Data Logging Violation**

Section Reference: "6. 実装方針 → ロギング方針" - "決済リクエスト/レスポンスの全フィールドをログ出力（デバッグ用）"

This is a critical PCI DSS compliance violation. Full request/response logging will capture card tokens, CVVs, and other sensitive data.

**Impact**:
- PCI DSS violation (requirement 3.2: Do not store sensitive authentication data after authorization)
- Logs become a high-value target for attackers
- Regulatory fines and potential license revocation
- Cannot use third-party log aggregation services (Datadog, CloudWatch Logs Insights)

**Refactoring Strategy**:
```java
// Implement field masking
class SensitiveDataMasker {
    private static final Set<String> SENSITIVE_FIELDS =
        Set.of("card_token", "cvv", "api_key", "full_card_number");

    public String maskSensitiveFields(String jsonLog) {
        // Replace sensitive field values with "***REDACTED***"
    }
}

// Logging configuration
log.info("Payment request: {}",
    sensitiveDataMasker.mask(paymentRequest));
```

**Moderate Issue 11: Missing Distributed Tracing**

Section Reference: "6. 実装方針 → ロギング方針" (gap - no mention of tracing)

In a distributed system with multiple components (API, Service, RabbitMQ, External Providers), there's no tracing strategy to correlate logs across boundaries.

**Impact**:
- Cannot trace a single payment request through the entire system
- Debugging cross-component issues requires manual log correlation
- No visibility into provider API latency contributions
- Difficult to identify bottlenecks in the request path

**Refactoring Strategy**:
```
Implement distributed tracing:
- Spring Cloud Sleuth for trace/span ID generation
- Propagate trace context to:
  - RabbitMQ messages (message headers)
  - Provider API calls (HTTP headers)
  - Database queries (SQL comments)
- Export to Zipkin or AWS X-Ray for visualization

Example trace:
[trace-id: abc123] API Request → Service → Stripe API (2.1s) → DB Write → RabbitMQ Publish
```

### 5. Test Design & Testability: **1/5 (Critical)**

**Critical Issue 12: Missing Test Strategy**

Section Reference: "6. 実装方針 → テスト方針" - "現時点では未定義。今後検討予定。"

For a financial system handling real money, the complete absence of a test strategy is unacceptable.

**Impact**:
- No regression testing for payment logic changes
- Cannot safely refactor code
- High risk of production bugs (incorrect amounts, double charging)
- Cannot validate PCI DSS compliance controls
- Difficult to onboard new team members

**Refactoring Strategy**:
```
Test Pyramid for Payment Gateway:

1. Unit Tests (70% coverage target)
   - PaymentService business logic (isolated from DB/providers)
   - Status transition validation
   - Amount calculation logic
   - Mock all external dependencies

2. Integration Tests (20% coverage target)
   - Controller → Service → MockRepository
   - Stripe SDK integration (use Stripe test mode)
   - Database transaction rollback testing
   - RabbitMQ message publishing

3. End-to-End Tests (10% coverage target)
   - Full payment flow with test payment provider
   - Webhook delivery and processing
   - Refund flow validation
   - Critical user journeys (happy path + key error scenarios)

4. Contract Tests
   - Provider API response schema validation
   - Merchant-facing API contract tests (Pact)
```

**Critical Issue 13: Direct SDK Coupling Prevents Testability**

Section Reference: "3. アーキテクチャ設計 → PaymentController" - Direct SDK calls

The controller's direct coupling to Stripe/PayPal SDKs makes unit testing impossible without real API keys.

**Impact**:
- Cannot run tests in CI/CD without production credentials
- Test execution depends on external service availability
- Slow test execution (network calls)
- Risk of accidental production charges during testing

**Refactoring Strategy**:
```java
// Extract interface for testing
interface PaymentProviderGateway {
    PaymentResult processPayment(PaymentRequest request);
}

// Test with mock implementation
class MockPaymentGateway implements PaymentProviderGateway {
    @Override
    public PaymentResult processPayment(PaymentRequest request) {
        return PaymentResult.success("mock_tx_123");
    }
}

// Unit test
@Test
void shouldProcessPaymentSuccessfully() {
    PaymentService service = new PaymentService(
        new MockPaymentGateway(),
        mockRepository
    );

    PaymentResult result = service.processPayment(...);

    assertThat(result.isSuccess()).isTrue();
}
```

### 6. API & Data Model Quality: **3/5 (Moderate Issues)**

**Significant Issue 14: Missing API Versioning Strategy** (Duplicate emphasis from Issue 4)

Already covered in Section 2 (Changeability). Cross-cutting impact on API sustainability.

**Moderate Issue 15: Inconsistent RESTful Design**

Section Reference: "5. API設計 → エンドポイント一覧"

The API mixes RESTful resource patterns with RPC-style action endpoints:
- RESTful: `GET /payments/{id}`, `GET /refunds/{id}`
- RPC-style: `POST /payments/create`, `POST /payments/{id}/cancel`

**Impact**:
- Confusing for merchant developers (which pattern to expect?)
- `/payments/create` is redundant (`POST /payments` is standard REST)
- Non-standard patterns increase integration errors

**Refactoring Strategy**:
```
Consistent RESTful design:
- POST /payments (create payment)
- GET /payments/{id} (get payment)
- DELETE /payments/{id} (cancel payment)
- POST /payments/{id}/refunds (create refund for payment)
- GET /refunds/{id} (get refund details)

For non-CRUD actions, use sub-resources:
- POST /subscriptions/{id}/pause
- POST /subscriptions/{id}/resume
(These are acceptable as they represent state transitions, not CRUD)
```

**Moderate Issue 16: Missing Schema Validation and Evolution Strategy**

Section Reference: "4. データモデル" (gap - no mention of schema versioning)

There's no strategy for database schema evolution (adding columns, migrating data, handling backward compatibility).

**Impact**:
- Adding a new column requires downtime for ALTER TABLE on large tables
- Cannot perform zero-downtime deployments with schema changes
- Risk of data migration failures in production

**Refactoring Strategy**:
```
Implement schema migration strategy:
1. Use Flyway or Liquibase for versioned migrations
2. Follow expand-contract pattern:
   - Expand: Add new column (nullable)
   - Deploy code that writes to both old and new columns
   - Backfill data
   - Contract: Remove old column

Example:
V001__initial_schema.sql
V002__add_merchant_tier.sql
V003__backfill_merchant_tier.sql
V004__remove_legacy_status_field.sql
```

**Positive Aspect**: The database schema includes proper indexing considerations (foreign keys defined for refunds), timestamps for audit trails, and appropriate data types for financial amounts (DECIMAL instead of FLOAT).

## Stage 3: Cross-Cutting Issue Detection

### Cross-Cutting Issue 1: Missing Transaction Consistency Across Components

**Affected Components**: PaymentService, WebhookPublisher, PaymentRepository

**Issue**: The data flow (Section 3) describes:
1. Save payment to DB
2. Send webhook to RabbitMQ
3. Return response to merchant

If step 2 (webhook publish) fails, the payment is already committed to the database, but merchants won't receive notification.

**Impact**:
- Webhook delivery failures create phantom payments
- No mechanism to detect and retry failed webhook deliveries
- Merchants implement polling as a workaround, increasing system load
- Violates event sourcing best practices

**Refactoring Strategy**:
```
Implement Transactional Outbox Pattern:

1. In same DB transaction, write:
   - Payment record to payments table
   - Webhook event to outbox table

2. Separate background process:
   - Poll outbox table for undelivered events
   - Publish to RabbitMQ
   - Mark as delivered in outbox
   - Retry failed deliveries with exponential backoff

This guarantees at-least-once delivery semantics.
```

### Cross-Cutting Issue 2: Missing Idempotency Design

**Affected Components**: All POST endpoints, PaymentService, External Provider Integrations

**Issue**: Network failures can cause merchants to retry payment requests. Without idempotency, this causes duplicate charges.

**Impact**:
- Merchant retries create duplicate payments
- End users charged twice for same order
- High volume of refund requests
- Damage to merchant trust and brand reputation

**Refactoring Strategy**:
```java
// Add idempotency key to all mutating operations
POST /payments
Headers:
  Idempotency-Key: <merchant-generated-unique-id>

// Service layer implementation
class PaymentService {
    PaymentResult processPayment(PaymentRequest request, String idempotencyKey) {
        // Check if already processed
        Optional<Payment> existing = repository.findByIdempotencyKey(idempotencyKey);
        if (existing.isPresent()) {
            return PaymentResult.fromExisting(existing.get());
        }

        // Process payment
        Payment payment = executePayment(request);
        payment.setIdempotencyKey(idempotencyKey);
        repository.save(payment);

        return PaymentResult.fromPayment(payment);
    }
}

// Database schema addition
ALTER TABLE payments ADD COLUMN idempotency_key VARCHAR(255) UNIQUE;
```

### Cross-Cutting Issue 3: No Circuit Breaker for Provider Failures

**Affected Components**: PaymentController, PaymentService, External Provider SDKs

**Issue**: Section 6 states "決済プロバイダーAPIエラー時は即座にクライアントへエラーレスポンス返却" with no mention of circuit breaking.

**Impact**:
- When Stripe API goes down, every payment request still attempts to call Stripe
- Cascading failures (thread pool exhaustion waiting for timeouts)
- Cannot automatically failover to backup provider (PayPal)
- Prolonged merchant-facing outages

**Refactoring Strategy**:
```java
// Implement Resilience4j Circuit Breaker
@CircuitBreaker(name = "stripe", fallbackMethod = "fallbackToPayPal")
public PaymentResult processPayment(PaymentRequest request) {
    return stripeGateway.processPayment(request);
}

public PaymentResult fallbackToPayPal(PaymentRequest request, Exception e) {
    log.warn("Stripe circuit open, failing over to PayPal", e);
    return payPalGateway.processPayment(request);
}

// Circuit breaker configuration
circuitbreaker:
  instances:
    stripe:
      failure-rate-threshold: 50
      wait-duration-in-open-state: 60000
      permitted-number-of-calls-in-half-open-state: 10
```

### Cross-Cutting Issue 4: Insufficient Separation of Read and Write Models

**Affected Components**: PaymentRepository, API Layer (GET endpoints)

**Issue**: The same `Payment` entity model is used for both writes (POST /payments) and reads (GET /payments, GET /payments?merchant_id=xxx&date_from=2026-01-01).

**Impact**:
- Complex merchant queries (filtering, pagination, aggregation) slow down OLTP write operations
- Cannot optimize read and write paths independently
- Reporting queries lock transaction tables
- Difficult to scale read and write workloads separately

**Refactoring Strategy** (CQRS - Command Query Responsibility Segregation):
```
Write Model (optimized for consistency):
- payments table (normalized, transactional)
- Strong consistency, immediate writes

Read Model (optimized for queries):
- payments_view materialized view (denormalized)
- Merchant dashboard queries
- Asynchronous updates from write model
- Can use read replicas or separate analytics database

Event Flow:
Payment Created → Event Bus → Update Read Model → Merchant Dashboard Queries
```

## Summary of Scores by Evaluation Criteria

| Criterion | Score | Severity |
|-----------|-------|----------|
| 1. SOLID Principles & Structural Design | 1/5 | Critical |
| 2. Changeability & Module Design | 2/5 | Significant |
| 3. Extensibility & Operational Design | 2/5 | Significant |
| 4. Error Handling & Observability | 2/5 | Significant |
| 5. Test Design & Testability | 1/5 | Critical |
| 6. API & Data Model Quality | 3/5 | Moderate |

**Overall Structural Health: 2.1/5.0**

## Prioritized Refactoring Recommendations

### Immediate (Pre-Production Blockers)

1. **Implement Payment Provider Abstraction Layer** (Issue 2, 3)
   - Extract `PaymentProviderGateway` interface
   - Move SDK calls out of controller
   - Enable unit testing and provider swapping

2. **Define Test Strategy and Implement Critical Tests** (Issue 12, 13)
   - Unit tests for payment amount calculations
   - Integration tests for provider interactions
   - Contract tests for API stability

3. **Fix Sensitive Data Logging** (Issue 10)
   - Implement field masking for PCI DSS compliance
   - Remove full request/response logging

4. **Externalize Configuration** (Issue 7)
   - Move API keys to AWS Secrets Manager
   - Implement proper environment separation

### High Priority (First 2 Sprints)

5. **Decompose PaymentService God Object** (Issue 1)
   - Split into 6 focused services
   - Establish clear module boundaries

6. **Implement API Versioning** (Issue 4, 14)
   - Add /v1/ prefix to all endpoints
   - Define version deprecation policy

7. **Add Idempotency Support** (Cross-Cutting Issue 2)
   - Idempotency-Key header handling
   - Duplicate request detection

8. **Implement Transactional Outbox for Webhooks** (Cross-Cutting Issue 1)
   - Guaranteed webhook delivery
   - Retry mechanism

### Medium Priority (Next 3 Months)

9. **Normalize Merchant Data** (Issue 5)
   - Create merchants table
   - Migrate denormalized data

10. **Implement Circuit Breaker Pattern** (Cross-Cutting Issue 3)
    - Resilience4j integration
    - Provider failover logic

11. **Add Payment Status State Machine** (Issue 6)
    - Transition validation
    - Audit trail

12. **Implement Distributed Tracing** (Issue 11)
    - Spring Cloud Sleuth integration
    - X-Ray or Zipkin export

## Positive Structural Aspects

1. **Appropriate Technology Choices**: Spring WebFlux for async processing, RabbitMQ for event distribution, and PostgreSQL for transactional integrity are suitable for a payment gateway.

2. **Security Awareness**: PCI DSS tokenization approach (not storing raw card data) demonstrates security consciousness.

3. **Database Design Fundamentals**: Use of DECIMAL for financial amounts, proper foreign key relationships, and timestamp audit fields show solid data modeling basics.

4. **Infrastructure Resilience**: AWS Multi-AZ RDS configuration and ECS auto-scaling demonstrate availability awareness.

## Conclusion

The Payment Gateway System design exhibits critical structural deficiencies that require immediate architectural refactoring before production deployment. The most severe issues are:

1. **Violation of Separation of Concerns**: Direct SDK coupling in controller, God Object service layer
2. **Missing Architectural Abstractions**: No provider abstraction, no API versioning, no idempotency
3. **Inadequate Quality Assurance**: Complete absence of test strategy for a financial system
4. **Security and Compliance Risks**: Sensitive data logging violations, hardcoded credentials

The recommended refactoring strategy prioritizes creating the foundational abstractions (provider gateway, service decomposition, test infrastructure) before adding features. Estimated effort to address critical issues: 4-6 weeks for a team of 3 engineers.

Without these refactorings, the system will face:
- High defect rates in production
- Inability to add new payment providers efficiently
- Merchant integration breakages during updates
- PCI DSS audit failures
- Difficulty attracting and retaining engineering talent due to poor codebase maintainability
