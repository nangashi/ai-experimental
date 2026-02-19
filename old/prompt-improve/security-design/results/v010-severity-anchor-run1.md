# Security Design Review: TravelHub System

## Executive Summary

This security evaluation identifies **critical to moderate security gaps** in the TravelHub design document. The system lacks fundamental security controls across multiple layers, with the most severe issues being missing authorization checks on state-changing operations, absent CSRF protection, and insufficient data protection policies. While basic authentication is described, the design fails to specify essential security measures for a payment-processing travel platform handling sensitive PII and financial transactions.

**Overall Risk Level**: High - Multiple critical issues require immediate attention before production deployment.

---

## Critical Issues (Score 1)

### 1. Missing Authorization Checks on State-Changing Operations

**Severity**: Critical (Score 1)
**Category**: Authentication & Authorization Design

**Issue Description**:
The design document does not specify authorization checks for DELETE and PUT operations on bookings. The API endpoints list shows:
- `DELETE /api/v1/bookings/{id}` - Booking cancellation
- `PUT /api/v1/bookings/{id}` - Booking modification

However, there is no explicit design stating that:
- Users can only delete/modify their own bookings
- Ownership verification occurs before state changes
- Admin override rules are defined

**Impact Analysis**:
Without explicit ownership checks, a malicious user could:
- Cancel other users' bookings by iterating through booking IDs
- Modify bookings they don't own, potentially stealing reservations
- Access booking details containing PII (passport numbers shown in API example)

This represents a complete failure of the authorization model for state-changing operations, enabling horizontal privilege escalation.

**Reference**: Section 5 (API設計) lines 172-173

**Countermeasures**:
1. Add explicit authorization design: "Before any DELETE/PUT operation on /api/v1/bookings/{id}, verify that the authenticated user's ID matches bookings.user_id OR user has ADMIN role"
2. Document the authorization flow: API Gateway → JWT validation → Service-level ownership check → Database operation
3. Specify error responses: Return 403 Forbidden (not 404) when authorization fails to prevent booking ID enumeration
4. Add audit logging for all failed authorization attempts

---

### 2. JWT Storage Location Not Specified

**Severity**: Critical (Score 1)
**Category**: Authentication & Authorization Design

**Issue Description**:
The design states "JWT発行・検証" (line 79) and "RedisにJWT情報を保存" (line 104), but critically omits where the client stores the JWT token. The response format (line 201) shows a token is returned, but there is no specification for:
- Client-side storage mechanism (localStorage vs httpOnly cookie)
- Token transmission method (Authorization header vs cookie)
- Protection against XSS-based token theft

**Impact Analysis**:
If tokens are stored in localStorage (common but insecure practice):
- Any XSS vulnerability allows complete account takeover
- Tokens remain accessible to all JavaScript in the origin
- No protection against third-party script compromise

This is particularly critical for a payment platform where account takeover leads to financial fraud.

**Reference**: Section 5.2 (API設計 - 認証・認可方式) lines 237-242

**Countermeasures**:
1. Specify httpOnly cookie storage: "JWTトークンはhttpOnly, Secure, SameSite=Strict属性を持つCookieで送信"
2. Document token transmission: "すべてのAPI呼び出しでCookieは自動送信され、サーバー側で検証"
3. Add cookie configuration to the architecture: "Kong API GatewayまたはBackend Servicesでhttponly Cookieを設定"
4. Specify XSS protection policy (see CSRF/XSS section below)

---

### 3. No Backup Encryption Specified

**Severity**: Critical (Score 1)
**Category**: Data Protection

**Issue Description**:
The design specifies "RDSはMulti-AZ構成で冗長化" (line 301) but does not mention encryption for:
- RDS automated backups
- Manual snapshots
- Point-in-time recovery data

Given that the database contains:
- PII (full names, phone numbers, email addresses)
- Passport numbers (line 220)
- Payment transaction history

Unencrypted backups create a persistent data breach risk.

**Impact Analysis**:
- Backup access (via compromised AWS credentials or insider threat) exposes all historical customer PII
- Compliance violations (GDPR Article 32 requires encryption of personal data)
- Snapshot sharing or accidental public exposure leads to mass data breach

**Reference**: Section 7.3 (非機能要件 - 可用性・スケーラビリティ) line 301

**Countermeasures**:
1. Specify encryption at rest: "RDS automated backups and snapshots use AWS KMS encryption with customer-managed keys (CMK)"
2. Add key rotation policy: "RDS encryption keys are rotated annually with automated re-encryption"
3. Document snapshot access controls: "Snapshot sharing requires explicit ADMIN approval and audit logging"
4. Add to security requirements section: "All backups containing PII must be encrypted with AES-256"

---

## Significant Issues (Score 2)

### 4. No CSRF Protection Design

**Severity**: Significant (Score 2)
**Category**: CSRF/XSS Protection

**Issue Description**:
The design lists state-changing endpoints (POST /api/v1/bookings, DELETE /api/v1/bookings/{id}, POST /api/v1/payments) but does not specify CSRF protection mechanisms. If JWT tokens are transmitted via cookies (which they likely are, given Redis session storage), the system is vulnerable to cross-site request forgery.

**Impact Analysis**:
- Attacker-controlled site can make authenticated booking requests on behalf of victims
- Financial fraud: Attacker books travel using victim's payment method
- Booking cancellation: Attacker cancels legitimate bookings

**Reference**: Section 5.1 (API設計 - エンドポイント一覧) lines 169-177

**Countermeasures**:
1. Add CSRF token design: "Spring Securityの CsrfTokenRepository を使用し、すべてのPOST/PUT/DELETEリクエストにX-CSRF-TOKENヘッダーを要求"
2. Specify token generation: "Kong API GatewayまたはUser ServiceがCSRFトークンを生成し、httpOnly CookieとHTMLメタタグで提供"
3. Document frontend integration: "ReactアプリはメタタグからCSRFトークンを読み取り、Axiosインスタンスにヘッダーとして設定"
4. Add SameSite cookie attribute: "JWTとCSRFトークンはSameSite=Strict属性を持つCookieで送信"

---

### 5. No Idempotency Guarantees for Booking Operations

**Severity**: Significant (Score 2)
**Category**: Missing Idempotency Guarantees

**Issue Description**:
The design shows POST /api/v1/bookings (line 169) and POST /api/v1/payments (line 176) but does not specify idempotency mechanisms. Given that these operations:
- Charge payment methods
- Create binding reservations with suppliers
- Are vulnerable to network retries and duplicate submissions

The absence of idempotency guarantees can lead to double-booking and double-charging.

**Impact Analysis**:
- User retries after network timeout → multiple bookings created → financial dispute
- Frontend double-submit bug → duplicate charges → customer complaints and refund processing costs
- Race condition: Multiple tabs submit same booking → supplier API called multiple times

This is particularly critical because:
- Booking operations interact with external supplier APIs (lines 84-86)
- Payment operations integrate with Stripe (line 94)
- The design mentions "予約情報同期" (line 90) but not duplicate prevention

**Reference**: Section 5.1 (API設計) lines 169, 176

**Countermeasures**:
1. Add idempotency key design: "POST /api/v1/bookings requires X-Idempotency-Key header (UUID v4). Backend stores key in Redis with 24-hour TTL."
2. Specify duplicate detection: "If idempotency key matches existing completed request, return original response (200 OK with cached booking ID). If key matches in-progress request, return 409 Conflict."
3. Document Stripe idempotency: "Stripe payment intent creation includes idempotency_key parameter matching the booking idempotency key"
4. Add to payment_transactions schema: "Add idempotency_key column (VARCHAR(36), UNIQUE) to prevent duplicate payment records"

---

### 6. No Encryption for PII at Rest

**Severity**: Significant (Score 2)
**Category**: Data Protection

**Issue Description**:
The design stores sensitive PII in PostgreSQL (passport numbers in booking_details JSONB, phone numbers in users.phone_number) but does not specify encryption at rest for the RDS instance. Line 301 mentions Multi-AZ configuration but not encryption.

**Impact Analysis**:
- Database compromise (via SQL injection, credential theft, or infrastructure breach) exposes plaintext PII
- Compliance violations: GDPR Article 32, PCI DSS Requirement 3.4 (if cardholder names are stored)
- Passport numbers (line 220) are particularly sensitive and subject to identity theft

**Reference**: Section 4 (データモデル) lines 114-146; Section 7.3 line 301

**Countermeasures**:
1. Enable RDS encryption at rest: "PostgreSQL RDS instance uses AWS KMS encryption (AES-256) for all data volumes and replicas"
2. Specify key management: "Encryption keys are customer-managed keys (CMK) with automatic annual rotation"
3. Add field-level encryption for highly sensitive data: "Passport numbers in booking_details are encrypted with application-level AES-256-GCM before storing in JSONB column"
4. Document encryption in data flow: Update line 107 to include "PostgreSQLに暗号化して予約記録"

---

### 7. Missing Rate Limiting Configuration Details

**Severity**: Significant (Score 2)
**Category**: Missing Rate Limiting/DoS Protection

**Issue Description**:
The design mentions "APIリクエストはKong API Gatewayでレート制限を設定（ユーザーあたり100req/min）" (line 298), but this specification is insufficient:
- No rate limiting for unauthenticated endpoints (login, register, password reset)
- No distinction between read-heavy (search) and write-heavy (booking, payment) operations
- No brute-force protection for authentication endpoints

**Impact Analysis**:
- Credential stuffing attacks on /api/v1/auth/login with leaked password databases
- Account enumeration via /api/v1/auth/register (checking email existence)
- Denial of service by exhausting supplier API quotas via /api/v1/search/* endpoints

**Reference**: Section 7.2 (セキュリティ要件) line 298

**Countermeasures**:
1. Add endpoint-specific rate limits:
   - `/api/v1/auth/login`: 5 requests per 15 minutes per IP (brute-force protection)
   - `/api/v1/auth/register`: 10 requests per hour per IP (prevent automated account creation)
   - `/api/v1/search/*`: 30 requests per minute per user (prevent supplier API abuse)
   - `/api/v1/bookings`: 10 requests per minute per user (prevent booking spam)
2. Specify rate limit enforcement: "Kong API Gateway uses rate-limiting plugin with Redis backend for distributed counting"
3. Document rate limit responses: "Return 429 Too Many Requests with Retry-After header"
4. Add progressive penalties: "After 3 consecutive 429 responses, implement 1-hour IP-level block"

---

## Moderate Issues (Score 3)

### 8. Incomplete Input Validation Policy

**Severity**: Moderate (Score 3)
**Category**: Input Validation Design

**Issue Description**:
The design shows API request/response examples but does not specify:
- Input validation rules for each field
- Sanitization strategies for user-provided content
- Maximum length limits for text fields
- Allowed character sets for names and addresses

For example, the booking request (lines 212-224) accepts arbitrary JSON in bookingDetails with no validation policy.

**Impact Analysis**:
- JSON injection in bookingDetails.passengers[].name could break log parsers
- Overlength inputs (e.g., 10MB booking_details) cause database performance issues
- Script tags in full_name field (if rendered without escaping) enable stored XSS
- SQL injection risk if JSONB queries use dynamic SQL (though JPA mitigates this)

**Reference**: Section 5.1 (API設計 - リクエスト/レスポンス形式) lines 188-234

**Countermeasures**:
1. Add input validation section to implementation policy:
   - "All input fields validated with Hibernate Validator annotations (@NotNull, @Size, @Email, @Pattern)"
   - "email: RFC 5322 validation, max 255 characters"
   - "full_name: Unicode letters, spaces, hyphens only; max 255 characters"
   - "booking_details: Max 10KB JSON; validated against JSON schema per booking_type"
2. Specify sanitization: "All user input in booking_details is HTML-escaped before storing; output escaping is enforced in React components using JSX"
3. Add rejection policy: "Invalid input returns 400 Bad Request with detailed validation errors (e.g., 'passengers[0].name exceeds 255 characters')"
4. Document SQL injection prevention: "All database queries use JPA/Hibernate parameterized queries; no dynamic SQL concatenation"

---

### 9. Missing Audit Logging Design

**Severity**: Moderate (Score 3)
**Category**: Missing Audit Logging

**Issue Description**:
The logging policy (lines 266-270) specifies application logging (SLF4J + Logback → CloudWatch), but does not define:
- What security events to log (authentication failures, authorization denials, admin actions)
- Audit log retention policy (GDPR requires 6+ months for breach investigation)
- Log integrity protection (preventing tampering)
- Compliance requirements (PCI DSS 10.2 requires logging of access to cardholder data)

**Impact Analysis**:
- Inability to detect account takeover attempts (no failed login logging)
- No forensic trail for insider threats (admin actions on user accounts)
- Compliance violations: GDPR Article 33 requires breach detection capability
- Insufficient evidence for dispute resolution (booking modification/cancellation disputes)

**Reference**: Section 6 (実装方針 - ロギング方針) lines 266-270

**Countermeasures**:
1. Add security event logging policy:
   - "Log all authentication events: successful/failed login, logout, password reset requests"
   - "Log all authorization failures: attempted access to bookings owned by other users, admin endpoint access by non-admin users"
   - "Log all state-changing operations: booking creation/modification/deletion, payment processing, refunds"
   - "Log all admin actions: user suspension, system configuration changes"
2. Specify audit log format: "Audit logs include: timestamp (ISO 8601), user_id, IP address, user_agent, action, resource_id, result (success/failure), reason (if failed)"
3. Add log retention policy: "Audit logs retained for 13 months in CloudWatch Logs; exported to S3 Glacier for 7-year archival (compliance with PCI DSS 10.7)"
4. Specify log protection: "CloudWatch Logs streams have resource policies preventing deletion; S3 audit log buckets use Object Lock (WORM mode)"

---

### 10. Missing Data Retention and Deletion Policy

**Severity**: Moderate (Score 3)
**Category**: Data Protection

**Issue Description**:
The design includes `DELETE /api/v1/users/account` (line 161) but does not specify:
- What happens to bookings when a user deletes their account
- How long PII is retained after account deletion
- Whether payment history is anonymized or deleted
- GDPR "right to erasure" compliance mechanisms

**Impact Analysis**:
- GDPR Article 17 violation: User requests account deletion, but passport numbers remain in booking_details indefinitely
- Orphaned bookings: Foreign key constraints may prevent account deletion if bookings.user_id references are not handled
- Over-retention of PII: Payment history retained beyond legal/business necessity increases breach impact

**Reference**: Section 5.1 (API設計 - 認証・ユーザー管理) line 161

**Countermeasures**:
1. Define account deletion policy:
   - "User account deletion soft-deletes the user record (sets deleted_at timestamp, nullifies email/phone_number/full_name)"
   - "Bookings remain in database with anonymized user reference (user_id set to special DELETED_USER UUID)"
   - "Passport numbers and PII in booking_details.passengers are redacted (replaced with '[REDACTED]')"
2. Add data retention policy:
   - "PII retained for 5 years after last booking (for dispute resolution and tax compliance)"
   - "After retention period, booking_details is fully anonymized and user_id is disassociated"
3. Document GDPR compliance:
   - "User can request full data export via GET /api/v1/users/data-export (returns JSON of all bookings, profile, payment history)"
   - "Deletion requests processed within 30 days; user receives confirmation email with audit trail"
4. Add cascading deletion rules: "Payment transactions are retained but anonymized (user identifiers replaced with hashed references for accounting purposes)"

---

### 11. Missing Session Timeout and JWT Expiration Enforcement

**Severity**: Moderate (Score 3)
**Category**: Authentication & Authorization Design

**Issue Description**:
The design specifies "トークンの有効期限は1時間" (line 240) but does not address:
- How expired tokens are handled (graceful re-authentication vs hard logout)
- Redis TTL for JWT metadata (line 104 mentions storing in Redis but not expiration)
- Token refresh mechanism (forcing users to re-login hourly is poor UX)
- Session fixation prevention (whether new tokens are issued on privilege change)

**Impact Analysis**:
- If Redis TTL is longer than JWT expiration, revoked/expired tokens may be accepted
- No token refresh = users forcibly logged out mid-booking, leading to abandoned carts
- Session fixation: User logs in with user@example.com, gains ADMIN role, but retains old token with USER role

**Reference**: Section 5.2 (認証・認可方式) lines 239-242

**Countermeasures**:
1. Align Redis TTL with JWT expiration: "RedisにJWTメタデータを保存時、TTLを1時間に設定（JWT expiresIn と一致）"
2. Add token refresh design:
   - "Add endpoint POST /api/v1/auth/refresh accepting expired-but-valid JWT (within 24-hour grace period)"
   - "Refresh endpoint issues new JWT with extended expiration if user still exists and is not suspended"
   - "Refresh tokens stored in httpOnly cookie separate from access token"
3. Specify token revocation: "ログアウト時、RedisからJWTメタデータを削除し、以降のリクエストで401 Unauthorized返却"
4. Add session fixation prevention: "ロール変更時（USER→ADMIN昇格）、既存JWTを無効化し新規トークンを発行"

---

## Minor Improvements (Score 4)

### 12. Missing Password Complexity Requirements

**Severity**: Minor (Score 4)
**Category**: Authentication & Authorization Design

**Issue Description**:
The design specifies "パスワードはbcryptでハッシュ化（cost factor 12）" (line 295) but does not define:
- Minimum password length
- Complexity requirements (uppercase, lowercase, digits, special characters)
- Password blacklist (common passwords like "Password123")
- Password history (preventing reuse of last N passwords)

**Impact Analysis**:
- Users can set weak passwords ("123456"), reducing bcrypt's effectiveness
- No prevention of compromised passwords from breach databases
- Minor issue because bcrypt cost factor 12 provides reasonable protection even for weak passwords

**Reference**: Section 7.2 (セキュリティ要件) line 295

**Countermeasures**:
1. Add password policy: "Minimum 12 characters; must include uppercase, lowercase, digit; special characters recommended but not required"
2. Integrate breach detection: "Use HaveIBeenPwned API to reject known-breached passwords during registration/password change"
3. Add password history: "Prevent reuse of last 3 passwords (store bcrypt hashes in users.password_history JSONB column)"
4. Document validation: "Password validation enforced in User Service before hashing; frontend provides real-time strength indicator"

---

### 13. Missing Secure Cookie Attributes Specification

**Severity**: Minor (Score 4)
**Category**: CSRF/XSS Protection

**Issue Description**:
While HTTPS is required (line 294 "すべての通信はHTTPS/TLS 1.3以上"), the design does not explicitly specify cookie security attributes:
- Secure flag (cookies only transmitted over HTTPS)
- SameSite attribute (CSRF protection)
- HttpOnly flag (XSS protection) - mentioned in countermeasures above but not in original design

**Impact Analysis**:
- Minor issue because HTTPS requirement (line 294) implicitly protects cookies in transit
- However, misconfiguration could allow cookies to be sent over HTTP in development/staging
- SameSite=Lax would allow CSRF attacks on GET endpoints that change state (if any exist)

**Reference**: Section 7.2 (セキュリティ要件) line 294

**Countermeasures**:
1. Add explicit cookie configuration: "All authentication cookies use Secure, HttpOnly, SameSite=Strict attributes"
2. Document implementation: "Spring Security configures cookie attributes via .sessionManagement().sessionCreationPolicy()"
3. Add to deployment policy: "Verify in staging that cookies are never sent over HTTP connections (automated test in CI/CD pipeline)"

---

### 14. Missing Content Security Policy (CSP)

**Severity**: Minor (Score 4)
**Category**: CSRF/XSS Protection

**Issue Description**:
The design does not mention Content Security Policy headers, which provide defense-in-depth against XSS attacks. Given that React 18 is used (line 27), modern CSP would prevent inline script execution.

**Impact Analysis**:
- Low severity because React's JSX and virtual DOM provide inherent XSS protection
- CSP provides additional layer if XSS bypass is found in third-party libraries
- Absence of CSP does not create immediate vulnerability but removes defense layer

**Reference**: Section 2 (技術スタック) line 27

**Countermeasures**:
1. Add CSP policy: "CloudFront adds Content-Security-Policy header: default-src 'self'; script-src 'self' https://js.stripe.com; connect-src 'self' https://api.stripe.com; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'"
2. Document CSP reporting: "CSP violations are reported to /api/v1/csp-report endpoint for monitoring potential XSS attempts"
3. Add gradual rollout: "Initially deploy CSP in report-only mode (Content-Security-Policy-Report-Only header); promote to enforcement after 2 weeks of monitoring"

---

## Positive Security Aspects

### Well-Designed Elements

1. **Strong Password Hashing**: bcrypt with cost factor 12 (line 295) is current best practice, appropriately resistant to GPU cracking
2. **No Credit Card Storage**: Delegating payment processing to Stripe (line 297) eliminates PCI DSS scope reduction
3. **HTTPS/TLS Enforcement**: Requiring TLS 1.3+ (line 294) protects against downgrade attacks
4. **Role-Based Access Control**: RBAC model (lines 243-247) provides clear separation between user and admin privileges
5. **JWT Revocation Mechanism**: Redis-backed JWT metadata (line 241) enables token revocation on logout, addressing common JWT limitation
6. **Multi-AZ Database Configuration**: RDS Multi-AZ (line 301) provides availability but should be extended to include encryption (see critical issue #3)

---

## Scoring Summary

| Evaluation Criterion | Score | Justification |
|---------------------|-------|---------------|
| **1. Threat Modeling (STRIDE)** | 2 | Missing threat analysis for Tampering (no integrity checks), Repudiation (incomplete audit logging), Information Disclosure (no data classification), and Elevation of Privilege (missing authorization checks on DELETE/PUT operations) |
| **2. Authentication & Authorization Design** | 2 | Critical gaps: JWT storage location unspecified (risk of localStorage use), missing authorization checks on state-changing operations, no token refresh mechanism. Basic authentication design exists but insufficient for production. |
| **3. Data Protection** | 2 | Critical gaps: No encryption at rest for PII, no backup encryption, missing data retention policy. HTTPS requirement is positive but insufficient without at-rest protection. |
| **4. Input Validation Design** | 3 | Moderate issue: No validation policy specified for API inputs, no maximum size limits for JSONB fields, missing sanitization strategy. Spring Boot + JPA provide baseline protection but explicit policy is missing. |
| **5. Infrastructure & Dependency Security** | 3 | Moderate issues: Rate limiting specified but incomplete (no auth endpoint protection), dependency versions listed but no update policy, no secret rotation schedule. CloudWatch monitoring is positive. |

**Overall Average Score**: 2.4 / 5.0

---

## Priority Recommendations

### Immediate Action Required (Pre-Production Deployment)

1. **Add Authorization Checks**: Document ownership verification for DELETE /api/v1/bookings/{id} and PUT /api/v1/bookings/{id}
2. **Specify JWT Storage**: Mandate httpOnly, Secure, SameSite=Strict cookies for token transmission
3. **Enable RDS Encryption**: Configure encryption at rest for PostgreSQL and all backups
4. **Implement CSRF Protection**: Add Spring Security CSRF token mechanism for state-changing endpoints
5. **Add Idempotency Keys**: Require X-Idempotency-Key header for POST /api/v1/bookings and POST /api/v1/payments

### High Priority (Within 1 Sprint)

6. **Enhance Rate Limiting**: Add endpoint-specific limits for /api/v1/auth/login (brute-force protection) and search endpoints
7. **Define Audit Logging**: Specify security events to log (auth failures, authorization denials, admin actions) with 13-month retention
8. **Add Input Validation Policy**: Document validation rules for all API request fields, including JSONB schema validation

### Medium Priority (Within 2-3 Sprints)

9. **Data Retention Policy**: Define PII deletion procedures for account deletion and GDPR compliance
10. **Token Refresh Mechanism**: Implement refresh token flow to avoid forced logout during active sessions
11. **Password Policy**: Add complexity requirements, breach detection, and password history

### Defense-in-Depth Enhancements

12. **Content Security Policy**: Deploy CSP headers via CloudFront
13. **Field-Level Encryption**: Encrypt passport numbers in booking_details at application level
14. **Security Testing**: Add automated security tests (OWASP ZAP, SQL injection tests) to CI/CD pipeline

---

## Conclusion

The TravelHub design demonstrates awareness of basic security practices (HTTPS, password hashing, RBAC) but lacks critical specifications for a production payment platform. The most severe issues—missing authorization checks, unspecified JWT storage, and absent encryption—create immediate data breach risks. Addressing the 5 immediate action items is **mandatory before production deployment**. The system architecture is sound, and the security gaps are primarily documentation issues that can be resolved through design clarification rather than architectural changes.
