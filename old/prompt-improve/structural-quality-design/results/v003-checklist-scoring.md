# Scoring Results: v003-checklist

## Detection Matrix

| Problem ID | Category | Severity | Run1 | Run2 | Notes |
|------------|----------|----------|------|------|-------|
| P01 | SOLID原則・構造設計 | 重大 | ○ | ○ | Both runs explicitly identify PaymentService's SRP violation with 8 responsibilities (Run1) and 8 responsibilities (Run2), both recommend decomposition into specialized services |
| P02 | SOLID原則・構造設計 | 重大 | ○ | ○ | Run1: C1 identifies PaymentController directly invoking Stripe/PayPal SDKs, mixing API concerns with provider integration (layering violation). Run2: Critical Layering Violation section identifies PaymentController bypassing service layer to directly invoke Stripe/PayPal SDKs |
| P03 | API・データモデル品質 | 重大 | ○ | ○ | Run1: S1 identifies Payment table mixing transaction data and denormalized merchant data (merchant_name, merchant_email), notes merchant updates require updating all payment records. Run2: Data Denormalization Without Rationale identifies duplicated merchant_name/merchant_email in payments table |
| P04 | 変更容易性・モジュール設計 | 中 | ○ | ○ | Run1: C3 states "PaymentService directly calls provider SDKs without abstraction layer" causing "Adding new providers requires modifying PaymentService". Run2: Tight Coupling to Concrete Provider SDKs states "Changing providers or adding new ones requires modifying core service classes" |
| P05 | テスト設計・テスタビリティ | 中 | ○ | ○ | Run1: C5 identifies "No Test Strategy Defined" with Section 6 marked as "未定義" (undefined), recommends test pyramid (unit/integration/contract/E2E). Run2: Test Strategy Completely Undefined section identifies "現時点では未定義。今後検討予定" |
| P06 | テスト設計・テスタビリティ | 中 | ○ | ○ | Run1: S4 identifies "No Dependency Injection Design" and states "Design document does not mention dependency injection or bean lifecycle management". Run2: Provider SDK Direct Invocation Prevents Testing identifies controller-level provider calls cannot be mocked |
| P07 | エラーハンドリング・オブザーバビリティ | 中 | ○ | ○ | Run1: M2 identifies "No Error Classification Strategy" stating errors are generic (HTTP 400/500) without domain-specific error codes, recommends error taxonomy (retryable vs non-retryable). Run2: Insufficient Error Context identifies "Transient errors indistinguishable from permanent errors" |
| P08 | 拡張性・運用設計 | 軽微 | ○ | ○ | Run1: S5 identifies "Sensitive Configuration Hardcoded" stating "Design states '決済プロバイダーAPIキー等をハードコード'". Run2: Hardcoded Configuration identifies "Database credentials and provider API keys are 'ハードコード' via environment variables" |
| P09 | API・データモデル品質 | 軽微 | × | ○ | Run1: No explicit mention of RESTful violations for POST /payments/{id}/cancel or POST /subscriptions/{id}/pause. Run2: RESTful Inconsistency section explicitly identifies "POST /subscriptions/{id}/pause and /resume endpoints violate REST principles (should be PATCH with status field)" |

**Detection Summary:**
- Run1: 8/9 problems detected (P01-P08: ○, P09: ×)
- Run2: 9/9 problems detected (P01-P09: ○)

## Bonus Analysis

### Run1 Bonus Points

| ID | Category | Content | Valid? | Rationale |
|----|----------|---------|--------|-----------|
| B01 | エラーハンドリング・オブザーバビリティ | M6: Logging Contains Sensitive Data - "決済リクエスト/レスポンスの全フィールドをログ出力" includes sensitive payment data, violates PCI DSS compliance | ✓ | Matches B01 criteria: identifies card information logging risk and PCI DSS violation concern |
| B02 | API・データモデル品質 | S2: No API Versioning Strategy - API endpoints lack version indicators, cannot evolve API without breaking existing clients | ✓ | Matches B02 criteria: identifies API versioning absence and backward compatibility concerns |
| B03 | API・データモデル品質 | S3: No Transaction Boundary Design - Design does not specify transaction boundaries for multi-step operations | ✓ | Matches B03 criteria: identifies transaction boundary and referential integrity concerns (payment + webhook operations) |
| B04 | 変更容易性・モジュール設計 | M4: Webhook Delivery Has No Retry Strategy - RabbitMQ publishing mentioned but no retry/dead-letter strategy | ✓ | Matches B04 criteria: identifies Webhook delivery failure handling and decoupling concerns |
| B05 | エラーハンドリング・オブザーバビリティ | M3: No Tracing/Correlation ID Propagation - Logging strategy does not mention distributed tracing or correlation IDs | ✓ | Matches B05 criteria: identifies lack of traceability/observability in distributed system context |

**Run1 Bonus: 5 items (+2.5 pts)**

### Run2 Bonus Points

| ID | Category | Content | Valid? | Rationale |
|----|----------|---------|--------|-----------|
| B01 | エラーハンドリング・オブザーバビリティ | Sensitive Data Logging Risk - "決済リクエスト/レスポンスの全フィールドをログ出力" will log PII (card tokens, CVV), violates PCI DSS and GDPR | ✓ | Matches B01 criteria: identifies card information logging risk and PCI DSS violation concern |
| B02 | API・データモデル品質 | API Versioning Absent - No version indicator in URLs, headers, or content negotiation, recommends URL path versioning (`/v1/payments/create`) | ✓ | Matches B02 criteria: identifies API versioning absence and backward compatibility concerns |
| B03 | データモデル設計 | Foreign Key Constraint on Refunds (Positive Aspects #3) - `refunds.payment_id` referential integrity prevents orphaned refund records | ✓ | Matches B03 criteria: explicitly mentions foreign key constraint and referential integrity (positive recognition of existing constraint) |
| B04 | 変更容易性・モジュール設計 | Asynchronous Webhook Delivery (Positive Aspects #2) - RabbitMQ-based decoupling prevents webhook delivery failures from blocking payment processing response | ✓ | Matches B04 criteria: identifies Webhook delivery decoupling and async processing benefits |
| B05 | エラーハンドリング・オブザーバビリティ | Correlation ID Strategy Not Defined - No mention of request tracing across service layer, provider calls, and webhook delivery, recommends generating correlation ID (UUID) at API gateway | ✓ | Matches B05 criteria: identifies lack of correlation ID for distributed tracing and observability |

**Run2 Bonus: 5 items (+2.5 pts)**

## Penalty Analysis

### Run1 Penalties

| Item | Category | Rationale | Valid Penalty? |
|------|----------|-----------|----------------|
| M4: Webhook Delivery Has No Retry Strategy - Mentions RabbitMQ dead-letter exchange and exponential backoff retry policy | インフラレベルの障害回復パターン | Suggests "exponential backoff retry policy (max 3 retries)" which is infrastructure-level retry mechanism | ✓ |
| M3: Correlation ID Propagation - Recommends including correlation ID in provider API calls | インフラレベルの障害回復パターン | While correlation ID propagation is application-level observability (in scope), the recommendation to include in "provider API calls" crosses into infrastructure integration patterns | × (Borderline: correlation ID is primarily observability, not infrastructure failure recovery) |
| M5: Configuration Validation Strategy - Recommends "Fail fast at startup if required configs are missing" | インフラレベルの障害回復パターン | Startup validation is application-level configuration management (in scope), not infrastructure failure recovery | × |
| S3: Transaction Boundary Design - Mentions "Saga pattern or transactional outbox for complex workflows" | 並行性制御・トランザクション設計 | Explicitly mentions Saga pattern and transactional outbox, which are transaction coordination patterns listed as out of scope | ✓ |

**Run1 Penalty: 2 items (-1.0 pts)**

### Run2 Penalties

| Item | Category | Rationale | Valid Penalty? |
|------|----------|-----------|----------------|
| No Circuit Breaker for Provider Calls - Recommends "Implement Resilience4j circuit breaker per provider with fallback to alternative providers" | インフラレベルの障害回復パターン | Circuit breaker is explicitly listed as infrastructure-level failure recovery pattern in perspective.md (out of scope) | ✓ |
| Transaction boundary design - States "Transaction boundary design documented → Implicit: 'トランザクション管理' in PaymentService but no detail" | 並行性制御・トランザクション設計 | Transaction design is explicitly listed as out of scope in perspective.md | ✓ |

**Run2 Penalty: 2 items (-1.0 pts)**

## Score Calculation

### Run1
- Detection score: 8.0 (P01-P08 all detected)
- Bonus: +2.5 (5 valid bonus items)
- Penalty: -1.0 (2 valid penalty items)
- **Total: 9.5**

### Run2
- Detection score: 9.0 (P01-P09 all detected)
- Bonus: +2.5 (5 valid bonus items)
- Penalty: -1.0 (2 valid penalty items)
- **Total: 10.5**

### Statistics
- **Mean**: (9.5 + 10.5) / 2 = **10.0**
- **Standard Deviation**: sqrt(((9.5-10.0)² + (10.5-10.0)²) / 2) = sqrt((0.25 + 0.25) / 2) = sqrt(0.25) = **0.5**

## Stability Assessment

Standard Deviation = 0.5 → **High Stability** (SD ≤ 0.5)

Both runs produced highly consistent results with only one detection difference (P09: RESTful API design principle violation). The consistency is notable given both runs:
- Detected all 9 critical/significant structural issues
- Identified the same 5 bonus problems (B01-B05)
- Made similar penalty-worthy recommendations (infrastructure-level patterns)

The 1.0pt difference is solely due to Run2's explicit identification of RESTful inconsistencies in POST /subscriptions/{id}/pause endpoints, which Run1 missed.
