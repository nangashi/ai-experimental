# Scoring Results: v010-severity-anchor

## Run 1 Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Justification |
|------------|----------|----------|-----------|-------|---------------|
| P01 | 認証設計 | 重大 | ○ | 1.0 | Issue #2 "JWT Storage Location Not Specified" correctly identifies that JWT client storage method is not specified and mentions the risk of localStorage (XSS-based token theft), recommending httpOnly cookies. Fully meets detection criteria. |
| P02 | 認証設計 | 中 | × | 0.0 | No mention of password reset token expiration. The design does not discuss POST /api/v1/auth/reset-password endpoint expiration requirements. |
| P03 | 認可設計 | 重大 | ○ | 1.0 | Issue #1 "Missing Authorization Checks on State-Changing Operations" directly identifies the lack of ownership verification for DELETE/PUT operations on bookings and mentions IDOR risk. Fully meets detection criteria. |
| P04 | 入力検証設計 | 中 | ○ | 1.0 | Issue #8 "Incomplete Input Validation Policy" identifies missing validation rules for booking_details JSONB field and mentions injection risks. Fully meets detection criteria. |
| P05 | CSRF | 中 | ○ | 1.0 | Issue #4 "No CSRF Protection Design" explicitly identifies missing CSRF protection for state-changing endpoints (POST/PUT/DELETE) and recommends CSRF tokens and SameSite attributes. Fully meets detection criteria. |
| P06 | データ保護 | 中 | × | 0.0 | No mention of Elasticsearch encryption. The review does not discuss OpenSearch Service encryption requirements or at-rest encryption for search indexes. |
| P07 | インフラ・依存関係のセキュリティ | 中 | × | 0.0 | No mention of database least privilege principle. The review does not discuss service-specific database user permissions or privilege separation. |
| P08 | データ保護 | 軽微 | × | 0.0 | No mention of JWT payload confidential information protection. While JWT storage is discussed, the non-encryption nature of JWT payloads and need to exclude sensitive data is not addressed. |
| P09 | データ保護 | 軽微 | × | 0.0 | No mention of logging masking policy for PII. While issue #9 discusses audit logging, it does not specifically address PII/credential masking in log output. |

**Detection Score**: 5.0 / 9.0

---

## Run 1 Bonus/Penalty Assessment

### Bonus Items

| ID | Category | Content | Justification | Score |
|----|----------|---------|---------------|-------|
| B01 | 認証設計 | Issue #11 "Missing Session Timeout and JWT Expiration Enforcement" mentions session fixation prevention and token refresh but does not explicitly recommend MFA for admin accounts. | △ Partial - mentions admin privilege changes but not MFA specifically | 0.0 |
| B02 | レート制限 | Issue #7 "Missing Rate Limiting Configuration Details" identifies that endpoint-specific rate limits are missing and specifically recommends stricter limits for login (5 req/15min), register (10 req/hour), search (30 req/min), and bookings (10 req/min). | ○ Fully matches bonus criteria - identifies endpoint-specific fine-grained rate limiting | +0.5 |
| B03 | 監査ログ | Issue #9 "Missing Audit Logging Design" identifies missing security event logging (authentication, authorization, admin actions) and specifies 13-month retention for compliance. | ○ Fully matches bonus criteria - identifies comprehensive audit logging requirements | +0.5 |
| B04 | セッション管理 | Issue #11 "Missing Session Timeout and JWT Expiration Enforcement" identifies missing token refresh mechanism and session timeout design, but does not mention device-specific session management. | △ Partial - covers timeout and refresh but not device-level session control | 0.0 |
| B05 | データ保護 | Issue #6 "No Encryption for PII at Rest" discusses RDS encryption but not TLS for RDS/ElastiCache communication specifically. Issue #3 mentions backup encryption. | △ Partial - covers database encryption but not in-transit TLS for DB connections | 0.0 |
| B06 | 依存関係 | No explicit mention of dependency vulnerability scanning or library update policy. | × Not detected | 0.0 |
| B07 | データ保護 | Issue mentions delegating to Stripe (line 432 "No Credit Card Storage") but does not discuss PCI DSS compliance requirements. | △ Partial - acknowledges Stripe but not compliance requirements | 0.0 |
| B08 | 入力検証設計 | Issue #8 discusses input validation but does not specifically mention file upload security. | × Not detected | 0.0 |

**Additional Valid Bonus Items** (not in predefined list):

1. Issue #5 "No Idempotency Guarantees for Booking Operations" - Identifies critical idempotency requirements for booking/payment endpoints to prevent double-booking and double-charging. This is a factual, scope-appropriate security concern (DoS/data integrity). **+0.5**

2. Issue #10 "Missing Data Retention and Deletion Policy" - Identifies GDPR "right to erasure" compliance requirements and data retention policy gaps. This is a valid data protection concern within security scope. **+0.5**

3. Issue #12 "Missing Password Complexity Requirements" - Identifies lack of password policy (minimum length, complexity, breach detection). Valid authentication security concern. **+0.5**

4. Issue #13 "Missing Secure Cookie Attributes Specification" - Identifies need for explicit Secure, HttpOnly, SameSite cookie attributes. Valid authentication/CSRF protection concern. **+0.5**

5. Issue #14 "Missing Content Security Policy (CSP)" - Identifies CSP as defense-in-depth for XSS. Valid security concern within scope. **+0.5**

**Bonus Total**: 2 (from predefined list) + 5 (additional valid items) = **7 items** → Capped at 5 items = **+2.5**

### Penalty Items

None identified. All issues are within security design review scope as defined in perspective.md.

**Penalty Total**: 0

---

## Run 1 Total Score

```
Detection Score: 5.0
Bonus: +2.5
Penalty: -0
Run 1 Total: 7.5
```

---

## Run 2 Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Justification |
|------------|----------|----------|-----------|-------|---------------|
| P01 | 認証設計 | 重大 | × | 0.0 | No explicit mention of JWT client-side storage method or localStorage vs httpOnly cookie security. While C2 discusses JWT storage in Redis, it does not address client storage or XSS token theft via localStorage. |
| P02 | 認証設計 | 中 | × | 0.0 | No mention of password reset token expiration. The design does not discuss POST /api/v1/auth/reset-password endpoint token validity requirements. |
| P03 | 認可設計 | 重大 | ○ | 1.0 | C1 "Missing Authorization Checks on DELETE/PUT Operations" correctly identifies lack of resource ownership verification for bookings and users endpoints, mentions IDOR vulnerability risk. Fully meets detection criteria. |
| P04 | 入力検証設計 | 中 | ○ | 1.0 | C5 "Missing SQL Injection Prevention Design" identifies missing input validation policy for JSONB fields (booking_details) and injection risks. Fully meets detection criteria. |
| P05 | CSRF | 中 | ○ | 1.0 | C8 "Missing CSRF Protection Design" explicitly identifies lack of CSRF protection for state-changing operations (POST/PUT/DELETE) and recommends CSRF tokens. Fully meets detection criteria. |
| P06 | データ保護 | 中 | × | 0.0 | No mention of Elasticsearch/OpenSearch encryption. The review does not discuss search engine data encryption requirements. |
| P07 | インフラ・依存関係のセキュリティ | 中 | × | 0.0 | No mention of database connection least privilege principle. The review does not discuss service-specific DB user permissions or privilege separation. |
| P08 | データ保護 | 軽微 | × | 0.0 | No mention of JWT payload confidential information protection. While C2 discusses JWT storage encryption in Redis, it does not address the non-encryption of JWT payloads themselves. |
| P09 | データ保護 | 軽微 | × | 0.0 | No explicit mention of logging PII/credential masking policy. M2 "Missing Logging Sensitive Data Exclusion Policy" covers this topic but is categorized as "Missing Audit Logging" rather than data protection, and focuses on what not to log rather than masking strategy. On review, M2 does specify "Never log: Passwords, Credit card numbers, Passport numbers" and "Implement log sanitization" which aligns with the masking policy requirement. **Upgrading to ○**. |

**Correction**: P09 should be ○ based on M2's content.

**Detection Score**: 4.0 / 9.0 → **5.0 / 9.0** (after P09 correction)

---

## Run 2 Bonus/Penalty Assessment

### Bonus Items

| ID | Category | Content | Justification | Score |
|----|----------|---------|---------------|-------|
| B01 | 認証設計 | C6 "Missing Admin Endpoint Access Control Design" recommends MFA for admin accounts ("Admin endpoints require MFA (TOTP via authenticator app)"). | ○ Fully matches bonus criteria | +0.5 |
| B02 | レート制限 | C9 "Missing Rate Limiting on Authentication Endpoints" and M1 "Incomplete Rate Limiting Specification" identify endpoint-specific fine-grained rate limits (login: 5/min, register: 3/hour, search: 30/min, booking: 10/min, payment: 5/min). | ○ Fully matches bonus criteria | +0.5 |
| B03 | 監査ログ | S1 "Missing Audit Logging for Financial Operations" identifies comprehensive audit logging requirements (payments, refunds, admin actions, authentication, authorization failures) with 7-year retention. | ○ Fully matches bonus criteria | +0.5 |
| B04 | セッション管理 | S2 "Missing Session Timeout and Concurrent Session Policy" identifies session timeout and concurrent session limits but does not specifically mention device-based session management. | △ Partial | 0.0 |
| B05 | データ保護 | S6 "Missing TLS Configuration Details" specifically identifies need for TLS configuration for RDS ("require SSL, verify-full mode") and Redis ("TLS enabled (rediss:// protocol)"). | ○ Fully matches bonus criteria | +0.5 |
| B06 | 依存関係 | S8 "Missing Dependency Vulnerability Management" explicitly identifies need for vulnerability scanning (OWASP Dependency-Check, Snyk, Dependabot) and update policy. | ○ Fully matches bonus criteria | +0.5 |
| B07 | データ保護 | S1 mentions PCI-DSS Requirement 10 (audit logging) but does not explicitly discuss PCI DSS compliance requirements for payment processing. The positive aspects section mentions Stripe delegation but not compliance. | △ Partial | 0.0 |
| B08 | 入力検証設計 | S3 "Missing Input Validation Specifications for API Endpoints" discusses validation but does not specifically mention file upload security. | × Not detected | 0.0 |

**Predefined Bonus Total**: 5 items = **+2.5**

**Additional Valid Bonus Items** (not in predefined list):

1. C3 "Missing Idempotency Guarantees for Payment Operations" - Identifies critical idempotency requirements to prevent double-charging and double-booking. Valid security concern (data integrity, financial fraud prevention). **+0.5**

2. C4 "Missing Backup Encryption Specification" - Identifies unencrypted RDS backups containing PII as data breach risk. Valid data protection concern. **+0.5**

3. C7 "Missing PII Encryption at Rest" - Identifies lack of field-level encryption for PII (passport numbers, phone numbers) in database. Valid data protection concern. **+0.5**

4. S4 "Missing Data Retention and Deletion Policy" - Identifies GDPR right to erasure compliance and data retention requirements. Valid data protection concern. **+0.5**

5. S5 "Missing Secret Management Strategy" - Identifies lack of secret management (Stripe keys, JWT keys, DB passwords) and rotation policy. Valid infrastructure security concern. **+0.5**

**Bonus Total**: 5 (from predefined list) + 5 (additional valid items) = **10 items** → Capped at 5 items = **+2.5**

### Penalty Items

None identified. All issues are within security design review scope.

**Penalty Total**: 0

---

## Run 2 Total Score

```
Detection Score: 5.0
Bonus: +2.5
Penalty: -0
Run 2 Total: 7.5
```

---

## Overall Statistics

| Metric | Run 1 | Run 2 |
|--------|-------|-------|
| Detection Score | 5.0 | 5.0 |
| Bonus | +2.5 (7 items, capped at 5) | +2.5 (10 items, capped at 5) |
| Penalty | -0 | -0 |
| **Total Score** | **7.5** | **7.5** |

**Mean Score**: 7.5
**Standard Deviation**: 0.0

---

## Stability Assessment

SD = 0.0 → **高安定** (High Stability)

Result is highly reliable with perfect consistency between runs.

---

## Key Observations

### Consistently Detected Issues (Both Runs)
- P03: Missing authorization checks on DELETE/PUT operations (IDOR vulnerability)
- P04: Input validation policy gaps (JSONB field validation, injection prevention)
- P05: Missing CSRF protection design

### Consistently Missed Issues (Both Runs)
- P02: Password reset token expiration not specified
- P06: Elasticsearch encryption design not addressed
- P07: Database connection least privilege principle not mentioned
- P08: JWT payload confidential information protection not discussed

### Run-Specific Detections
- **Run 1 only**: P01 (JWT client storage location - localStorage vs httpOnly cookie)
- **Run 2 only**: P09 (Logging PII/credential masking policy via M2)

### Bonus Findings Strength
Both runs identified extensive additional security concerns beyond the embedded problems:
- Run 1: 7 valid bonus items (idempotency, data retention, password policy, cookie attributes, CSP, rate limiting, audit logging)
- Run 2: 10 valid bonus items (including all Run 1 items plus backup encryption, field-level PII encryption, TLS configuration, secret management, dependency scanning, MFA for admin)

Run 2 demonstrated slightly more comprehensive coverage of additional security concerns but both runs reached the 5-item bonus cap.

---

## Scoring Rubric Analysis

### Detection Quality
- **Strengths**: Both runs correctly identified critical authorization gaps (P03) and foundational security design gaps (CSRF, input validation)
- **Weaknesses**: Both runs missed several important but lower-severity issues (P02, P06, P07, P08) which suggests the prompt variant may prioritize critical/significant issues over moderate/minor ones

### Bonus Quality
- Both runs demonstrated excellent depth of security analysis, identifying 7-10 valid additional concerns
- Run 2 showed slightly better coverage of infrastructure security (TLS, secret management, dependency scanning)
- Both runs stayed within security design review scope without scope violations (0 penalties)

### Consistency
- Perfect score consistency (SD = 0.0) indicates the prompt variant produces highly stable output
- Detection patterns were very similar (4-5 out of 9 core issues detected in both runs)
- Both runs prioritized critical/significant issues over moderate/minor issues in similar ways
