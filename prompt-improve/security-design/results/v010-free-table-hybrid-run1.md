# Security Design Review: TravelHub System

## Executive Summary

This security evaluation identifies **10 critical issues**, **8 significant issues**, and **15 moderate issues** in the TravelHub design document. The most severe risks include missing encryption for JWT content, inadequate database privilege separation, unencrypted Elasticsearch data at rest, and absent CSRF protection. The design demonstrates some positive security foundations (TLS 1.3, bcrypt, RDS Multi-AZ) but lacks comprehensive security controls across authentication, data protection, input validation, and infrastructure layers.

---

## Critical Issues (Score: 1-2)

### 1. JWT Content Encryption Missing (Score: 1)

**Issue**: JWT tokens use HS256 signature-only without payload encryption. Sensitive user data (user_id, role, email) in JWT claims is base64-encoded but readable by anyone intercepting the token.

**Impact**:
- Attackers intercepting HTTPS connections (e.g., via compromised CDN, proxy, or client-side malware) can decode JWT payloads and extract user IDs and roles
- Enables targeted privilege escalation attacks and user impersonation
- PII exposure violates privacy requirements

**Evidence**: Line 296 states "JWTトークンはHS256アルゴリズムで署名" (JWT uses HS256 algorithm for signature) but no mention of JWE (JSON Web Encryption).

**Recommendation**:
- Implement JWE (RFC 7516) with A256GCM for JWT payload encryption
- Minimize sensitive data in JWT claims; use opaque token references instead
- Implement short-lived access tokens (15 minutes) with refresh token mechanism

**Category**: Data Protection / Authentication Design

---

### 2. Database Privilege Separation Absent (Score: 1)

**Issue**: No design for database user privilege separation. The design implies a single application database account with unrestricted access to all tables.

**Impact**:
- SQL injection in any service (Search, Booking, Payment) can compromise all data including user credentials, payment transactions, and admin functions
- Insider threat: compromised service container gains full database access
- Violates principle of least privilege

**Evidence**: Section 4 (Data Model) describes tables but no mention of separate database roles or row-level security policies for User/Admin services.

**Recommendation**:
- Create separate PostgreSQL users per service: `user_service_db`, `booking_service_db`, `payment_service_db`, `admin_service_db`
- Grant minimum required privileges (e.g., User Service: SELECT/INSERT on `users`, no access to `payment_transactions`)
- Implement PostgreSQL Row-Level Security (RLS) for `users` table to prevent horizontal privilege escalation
- Document privilege matrix in design

**Category**: Infrastructure Security / Authorization Design

---

### 3. Elasticsearch Data-at-Rest Encryption Missing (Score: 1)

**Issue**: OpenSearch Service configuration does not specify encryption at rest for Elasticsearch indices. Hotel/flight search data may contain sensitive PII (passenger names, travel patterns).

**Impact**:
- EBS volume snapshots expose unencrypted search indices
- Compliance violations (GDPR, PCI-DSS for payment card holder travel data)
- Data breach if AWS account compromised

**Evidence**: Line 33 mentions "Elasticsearch 8.10" and line 36 "OpenSearch Service" but no encryption specification in Section 7 (Security Requirements).

**Recommendation**:
- Enable OpenSearch encryption at rest using AWS KMS
- Implement field-level encryption for PII in search indices (passenger names, passport numbers)
- Define data retention policy for search cache (e.g., 24 hours)

**Category**: Data Protection / Infrastructure Security

---

### 4. CSRF Protection Absent (Score: 1)

**Issue**: No Cross-Site Request Forgery (CSRF) protection mechanism described for state-changing operations (booking creation, payment, account deletion).

**Impact**:
- Attacker tricks logged-in user into visiting malicious site, which sends forged `POST /api/v1/bookings` or `DELETE /api/v1/users/account` requests
- Results in unauthorized bookings charged to victim, account deletion, or privilege escalation

**Evidence**: Section 5 (API Design) lists POST/PUT/DELETE endpoints but no mention of CSRF tokens in request/response examples.

**Recommendation**:
- Implement Double-Submit Cookie pattern or Synchronizer Token for all state-changing endpoints
- Add `X-CSRF-Token` header validation in Kong API Gateway
- Set `SameSite=Strict` cookie attribute for session cookies
- Document CSRF token lifecycle in authentication flow

**Category**: Authentication & Authorization Design

---

### 5. Input Validation Policy Missing (Score: 1)

**Issue**: No input validation policy defined. Section 5 shows endpoints accepting JSON but no validation rules for critical fields (email format, password complexity, booking amounts, SQL injection prevention).

**Impact**:
- SQL injection via unsanitized `email`, `full_name`, or `booking_details` JSONB fields
- NoSQL injection in Elasticsearch queries
- Business logic bypass (negative `totalAmount`, invalid dates)
- XSS via unsanitized user input rendered in admin dashboard

**Evidence**: Lines 189-223 show API request examples with no validation specifications. No mention of Bean Validation (JSR-380) or input sanitization framework.

**Recommendation**:
- Define comprehensive input validation policy:
  - Email: RFC 5322 compliant regex
  - Password: Min 12 chars, complexity requirements (uppercase, lowercase, digit, special char)
  - `totalAmount`: Positive decimal, max 999999.99
  - Dates: ISO 8601 format, future dates only for bookings
- Implement Spring Validation with `@Valid` annotations on all request DTOs
- Add parameterized queries enforcement (prevent string concatenation in SQL/Elasticsearch)
- Document validation rules in API specification

**Category**: Input Validation Design

---

### 6. Idempotency Guarantees Missing (Score: 2)

**Issue**: No idempotency mechanism for critical state-changing operations. `POST /api/v1/bookings` and `POST /api/v1/payments` lack idempotency key design.

**Impact**:
- Network retry/timeout causes duplicate bookings and double charges
- User frustration and customer support burden
- Financial loss from erroneous refunds

**Evidence**: Lines 169-177 list booking and payment endpoints with no mention of idempotency keys or duplicate detection.

**Recommendation**:
- Require `Idempotency-Key` header (UUID) for POST /api/v1/bookings and POST /api/v1/payments
- Store key-response mapping in Redis with 24-hour TTL
- Return cached response for duplicate requests with same key
- Document idempotency behavior in API specification

**Category**: Data Protection / Error Handling Design

---

### 7. Audit Logging Policy Missing (Score: 2)

**Issue**: Section 6 describes general application logging but no audit logging policy for security-critical events (authentication attempts, authorization failures, data access, admin actions).

**Impact**:
- Inability to detect/investigate security incidents (brute force attacks, privilege escalation, data exfiltration)
- Compliance violations (PCI-DSS 10.2, GDPR Article 30)
- No forensic evidence for incident response

**Evidence**: Lines 266-270 describe SLF4J/Logback for application logs but no mention of audit events, log retention, or immutable logging.

**Recommendation**:
- Define audit logging policy covering:
  - Authentication: login success/failure (with source IP, user agent)
  - Authorization: access denied events with requested resource
  - Data access: viewing/modifying sensitive data (user profile, payment info, bookings)
  - Admin actions: all `/api/v1/admin/*` operations
- Implement separate audit log stream (CloudWatch Logs with log retention = 365 days)
- Enable log file integrity validation (CloudWatch Logs Insights with SHA-256 hashing)
- Alert on suspicious patterns (10+ failed login attempts, privilege escalation attempts)

**Category**: Threat Modeling / Infrastructure Security

---

### 8. Secret Rotation Policy Absent (Score: 2)

**Issue**: No secret management or rotation policy described. JWT signing key, database passwords, Stripe API keys, and third-party supplier API credentials lack rotation schedules.

**Impact**:
- Compromised secrets remain valid indefinitely
- Inability to revoke access after employee departure or supplier contract termination
- Increased blast radius of security incidents

**Evidence**: Section 2 lists technologies but no AWS Secrets Manager or rotation strategy. Line 296 mentions JWT but not key management.

**Recommendation**:
- Implement AWS Secrets Manager with automatic rotation:
  - Database credentials: 90-day rotation
  - JWT signing key: 30-day rotation with overlapping grace period
  - Stripe API keys: Manual rotation on security advisories
  - Supplier API credentials: Per-contract rotation schedule
- Document rotation procedures and test restoration from rotated secrets
- Implement secret version tracking in deployment pipeline

**Category**: Infrastructure Security / Data Protection

---

### 9. Rate Limiting Insufficient (Score: 2)

**Issue**: Line 298 specifies "100req/min per user" but no rate limiting for authentication endpoints or unauthenticated APIs (search, password reset).

**Impact**:
- Brute force attacks on `/api/v1/auth/login` and password reset
- Account enumeration via timing attacks
- DDoS via unauthenticated search APIs
- Resource exhaustion of external supplier APIs

**Evidence**: Line 298 states "APIリクエストはKong API Gatewayでレート制限を設定（ユーザーあたり100req/min）" but no per-endpoint or IP-based limits.

**Recommendation**:
- Implement tiered rate limiting in Kong:
  - `/api/v1/auth/login`: 5 attempts per IP per 15 minutes
  - `/api/v1/auth/reset-password`: 3 requests per email per hour
  - `/api/v1/search/*`: 20 requests per IP per minute (unauthenticated), 100 req/min (authenticated)
  - `/api/v1/bookings`, `/api/v1/payments`: 10 requests per user per minute
- Implement exponential backoff for failed authentication
- Add CAPTCHA after 3 failed login attempts

**Category**: Threat Modeling (DoS) / Authentication Design

---

### 10. Error Information Disclosure Risk (Score: 2)

**Issue**: GlobalExceptionHandler returns error codes and messages (lines 256-264) but no specification on preventing sensitive information disclosure (stack traces, SQL queries, internal paths).

**Impact**:
- Stack traces reveal framework versions and internal code structure (aids targeted attacks)
- SQL error messages expose database schema
- File paths disclose deployment environment details

**Evidence**: Lines 256-264 show error response format but no sanitization policy for production environments.

**Recommendation**:
- Implement environment-specific error handling:
  - Production: Return generic error codes only (`INTERNAL_ERROR`, `VALIDATION_FAILED`)
  - Development: Include detailed stack traces
- Log full exception details server-side (CloudWatch) but never expose to client
- Sanitize database error messages to remove query fragments
- Define error code catalog documenting safe client-facing messages

**Category**: Error Handling Design / Information Disclosure

---

## Significant Issues (Score: 3)

### 11. Password Reset Token Security Gaps (Score: 3)

**Issue**: Lines 157-158 describe password reset flow but no token design (expiration time, single-use enforcement, entropy requirements).

**Impact**:
- Long-lived tokens enable account takeover if reset email compromised
- Reusable tokens allow multiple password changes after initial reset
- Weak tokens vulnerable to brute force

**Recommendation**:
- Implement secure token generation (32-byte random, base64-encoded)
- Enforce 15-minute token expiration
- Invalidate token after single use
- Store bcrypt hash of token in database, not plaintext

**Category**: Authentication Design

---

### 12. Session Management Security Incomplete (Score: 3)

**Issue**: Line 241 mentions Redis stores "トークンのメタデータ（user_id, 発行時刻）" but no session fixation prevention, concurrent session limits, or logout mechanism design.

**Impact**:
- Session fixation attacks via stolen JWT
- Account sharing via unlimited concurrent sessions
- Inability to revoke access after password change

**Recommendation**:
- Generate new JWT after password change or role modification
- Limit concurrent sessions to 3 per user
- Implement `/api/v1/auth/logout-all` endpoint to revoke all user sessions
- Add `jti` (JWT ID) claim for per-token revocation

**Category**: Authentication Design

---

### 13. Third-Party Supplier API Authentication Missing (Score: 3)

**Issue**: Lines 84-86 describe Search Service integration with airline/hotel/car rental APIs but no authentication/authorization design for these external calls.

**Impact**:
- Man-in-the-middle attacks on supplier API traffic
- Unauthorized access to TravelHub's supplier accounts
- API key leakage in logs or error messages

**Recommendation**:
- Store supplier API credentials in AWS Secrets Manager
- Implement mutual TLS (mTLS) for supplier API connections
- Validate supplier API SSL certificates (certificate pinning)
- Timeout supplier API calls at 3 seconds (per line 290) with exponential backoff

**Category**: Authentication Design / Infrastructure Security

---

### 14. Booking Status State Machine Vulnerabilities (Score: 3)

**Issue**: Line 133 shows booking statuses (CONFIRMED/CANCELLED/PENDING) but no state transition validation or authorization checks.

**Impact**:
- Users can cancel CONFIRMED bookings without refund policy checks
- Race conditions: concurrent cancellation and modification requests
- Unauthorized status changes (e.g., USER role marking booking as CONFIRMED without payment)

**Recommendation**:
- Define allowed state transitions: PENDING → CONFIRMED, CONFIRMED → CANCELLED (with payment validation)
- Implement optimistic locking (`version` column in `bookings` table)
- Validate state transitions in Booking Service with authorization checks
- Log all status changes to audit trail

**Category**: Authorization Design / Data Protection

---

### 15. Payment Refund Authorization Missing (Score: 3)

**Issue**: Line 177 shows `POST /api/v1/payments/{id}/refund` endpoint but no authorization design (who can initiate refunds, approval workflows, partial refund limits).

**Impact**:
- Users can refund bookings bypassing cancellation policies
- Financial fraud via unauthorized refunds
- Revenue loss from unrestricted refund abuse

**Recommendation**:
- Restrict refund endpoint to ADMIN role only
- Implement refund policy engine (check booking date, cancellation deadline, refund percentage)
- Require manager approval for refunds > $500
- Validate refund amount ≤ original payment amount

**Category**: Authorization Design

---

### 16. Admin Dashboard XSS Risks (Score: 3)

**Issue**: Line 101 mentions admin dashboard displays user data and reports but no output encoding/sanitization specified.

**Impact**:
- Stored XSS via malicious `full_name` or `booking_details` JSONB fields
- Admin account compromise enables full system access
- Privilege escalation and data exfiltration

**Recommendation**:
- Implement React's automatic escaping for all user-generated content
- Use DOMPurify library for rich text fields (reviews, comments)
- Set Content-Security-Policy header: `script-src 'self'; object-src 'none'`
- Validate and sanitize `booking_details` JSONB before rendering

**Category**: Input Validation Design / Threat Modeling

---

### 17. Redis Authentication and Network Isolation Missing (Score: 3)

**Issue**: Line 32 mentions Redis for sessions/cache but no authentication (AUTH command) or network isolation design.

**Impact**:
- Unauthorized access to session data if Redis exposed
- Session hijacking via stolen JWT metadata
- Cache poisoning attacks

**Recommendation**:
- Enable Redis AUTH with strong password (32+ characters)
- Configure ElastiCache in VPC private subnet with security group allowing only backend service access
- Enable encryption in transit (TLS) for Redis connections
- Implement Redis ACL (Access Control Lists) for fine-grained permissions

**Category**: Infrastructure Security

---

### 18. Dependency Vulnerability Management Missing (Score: 3)

**Issue**: Section 2 lists library versions (Spring Boot 3.2, Stripe SDK 23.10.0, Jackson 2.15.3) but no vulnerability scanning or update policy.

**Impact**:
- Exploitation of known CVEs in outdated dependencies
- Supply chain attacks via compromised libraries
- Compliance violations (OWASP Top 10 A06:2021)

**Recommendation**:
- Integrate OWASP Dependency-Check into CI/CD pipeline (fail build on high/critical CVEs)
- Implement automated dependency updates via Dependabot
- Define update SLA: critical CVEs patched within 7 days, high within 30 days
- Document approved library list and security review process for new dependencies

**Category**: Infrastructure Security

---

## Moderate Issues (Score: 4)

### 19. CloudFront CDN Security Headers Missing (Score: 4)

**Issue**: Line 37 mentions CloudFront CDN but no security headers (HSTS, X-Content-Type-Options, X-Frame-Options).

**Impact**: Clickjacking, MIME-sniffing attacks, downgrade attacks to HTTP

**Recommendation**:
- Configure CloudFront to add security headers:
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Content-Security-Policy: default-src 'self'`

**Category**: Infrastructure Security

---

### 20. Database Connection Pool Limits Missing (Score: 4)

**Issue**: No design for PostgreSQL connection pool configuration or limits.

**Impact**: Connection exhaustion DoS, inability to handle traffic spikes

**Recommendation**:
- Configure HikariCP with `maximumPoolSize=20` per service instance
- Set `connectionTimeout=5000ms`, `idleTimeout=300000ms`
- Monitor connection pool metrics in Datadog

**Category**: Infrastructure Security / Threat Modeling (DoS)

---

### 21. JWT Algorithm Confusion Attack Prevention (Score: 4)

**Issue**: Line 296 specifies HS256 but no prevention of "alg=none" bypass or RSA/HMAC confusion.

**Impact**: Attackers modify JWT header to `alg: none` or switch HS256 to RS256, bypassing signature validation

**Recommendation**:
- Explicitly validate `alg` claim is HS256 in JWT verification code
- Reject tokens with `alg: none` or mismatched algorithms
- Use `jjwt` library's strict algorithm validation mode

**Category**: Authentication Design

---

### 22. Booking Modification Race Conditions (Score: 4)

**Issue**: Line 173 shows `PUT /api/v1/bookings/{id}` endpoint but no concurrency control.

**Impact**: Lost updates when user modifies booking while supplier API synchronization is in progress

**Recommendation**:
- Add `version` column to `bookings` table for optimistic locking
- Return `409 Conflict` when version mismatch detected
- Implement `ETag`/`If-Match` headers for concurrent modification prevention

**Category**: Data Protection

---

### 23. Logging PII Without Masking (Score: 4)

**Issue**: Lines 266-270 describe structured logging but no PII masking policy.

**Impact**: GDPR violations, PII exposure in logs accessed by support staff

**Recommendation**:
- Mask sensitive fields in logs: `email → e***@example.com`, `password_hash → [REDACTED]`, `passportNumber → XX***67`
- Implement Logback masking layout for automatic PII redaction
- Define PII classification matrix for all data fields

**Category**: Data Protection

---

### 24. Search Query Injection Prevention Missing (Score: 4)

**Issue**: Lines 163-166 show search endpoints but no Elasticsearch query injection prevention design.

**Impact**: Elasticsearch query DSL injection enables unauthorized data access or cluster DoS

**Recommendation**:
- Use Elasticsearch Query Builders (not string concatenation)
- Sanitize user input for special characters: `{`, `}`, `[`, `]`, `:`, `"`, `*`
- Implement query allowlist (only permit term, match, range queries)

**Category**: Input Validation Design

---

### 25. Account Deletion Data Retention Conflict (Score: 4)

**Issue**: Line 161 shows `DELETE /api/v1/users/account` but no design for associated booking/payment data retention (legal requirements for financial records).

**Impact**: Compliance violations (tax audit trails require 7-year retention), inability to resolve disputes

**Recommendation**:
- Implement soft delete for `users` table (`deleted_at` timestamp)
- Anonymize user PII but retain transactional data (bookings, payments)
- Define data retention policy: financial records = 7 years, PII = 30 days post-deletion

**Category**: Data Protection

---

### 26. API Gateway Kong Security Configuration Missing (Score: 4)

**Issue**: Line 28 mentions Kong API Gateway but no security plugin configuration (JWT validation, request size limits, IP allowlist).

**Impact**: Bypassing authentication, payload bomb DoS, unauthorized admin access

**Recommendation**:
- Configure Kong plugins:
  - JWT plugin for authentication validation
  - Request Size Limiting plugin: 10MB max
  - IP Restriction plugin for `/api/v1/admin/*` (allowlist admin IPs)
  - Bot Detection plugin to block malicious crawlers

**Category**: Infrastructure Security

---

### 27. Stripe Webhook Signature Verification Missing (Score: 4)

**Issue**: Line 94 mentions Stripe integration but no webhook signature verification design.

**Impact**: Attackers forge payment success webhooks, marking unpaid bookings as CONFIRMED

**Recommendation**:
- Validate Stripe webhook signatures using `Stripe-Signature` header and webhook secret
- Implement idempotency for webhook processing (deduplicate by `event.id`)
- Verify webhook events by fetching from Stripe API (don't trust webhook payload alone)

**Category**: Authentication Design / Data Protection

---

### 28. ECS Task Role Least Privilege Missing (Score: 4)

**Issue**: Line 36 mentions ECS Fargate but no IAM role design for service tasks.

**Impact**: Compromised container gains excessive AWS permissions (S3 write, RDS admin, secrets access)

**Recommendation**:
- Create separate IAM roles per service:
  - User Service: `secretsmanager:GetSecretValue` for JWT key only
  - Booking Service: `rds:Connect`, `sqs:SendMessage`
  - Payment Service: No AWS permissions (only Stripe API)
- Deny `sts:AssumeRole`, `iam:PassRole` to prevent privilege escalation

**Category**: Infrastructure Security / Authorization Design

---

### 29. Backup Encryption and Access Control Missing (Score: 4)

**Issue**: Line 301 mentions RDS Multi-AZ but no backup encryption or restoration access control.

**Impact**: Unencrypted backups expose all data if AWS account compromised, unauthorized restoration causes data loss

**Recommendation**:
- Enable RDS automated backups with AWS KMS encryption
- Restrict `rds:RestoreDBInstanceFromDBSnapshot` permission to DBA role only
- Test backup restoration quarterly

**Category**: Data Protection / Infrastructure Security

---

### 30. External Supplier API Timeout and Circuit Breaker Missing (Score: 4)

**Issue**: Line 290 specifies 3-second timeout but no circuit breaker design for failing supplier APIs.

**Impact**: Cascading failures when supplier API is down, poor user experience during outages

**Recommendation**:
- Implement Resilience4j circuit breaker with 50% error threshold (open circuit after 5 failures in 10 seconds)
- Return cached search results when circuit is open
- Implement fallback: display "Supplier temporarily unavailable" with partial results

**Category**: Error Handling Design / Threat Modeling (DoS)

---

### 31. Pagination Security Missing (Score: 4)

**Issue**: Lines 180-182 show list endpoints (`/api/v1/admin/bookings`, `/api/v1/bookings`) but no pagination parameters or limits.

**Impact**: Memory exhaustion DoS via unpaginated queries, horizontal privilege escalation (user accesses other users' bookings)

**Recommendation**:
- Enforce mandatory pagination: `?page=0&size=20` (max size = 100)
- Filter `/api/v1/bookings` by authenticated `user_id` (prevent horizontal access)
- Return `Link` header with `next`/`prev` URLs for pagination

**Category**: Authorization Design / Threat Modeling (DoS)

---

### 32. Development Environment Security Separation Missing (Score: 4)

**Issue**: Lines 278-282 describe CI/CD pipeline but no separation of development/staging/production secrets or access controls.

**Impact**: Developers with staging access can exfiltrate production database credentials, accidental production deployments

**Recommendation**:
- Separate AWS accounts for dev/staging/production (AWS Organizations)
- Use different JWT signing keys per environment
- Restrict production AWS console access to 2-3 SRE personnel with MFA
- Implement environment-specific Secrets Manager namespaces

**Category**: Infrastructure Security

---

### 33. Mobile API Considerations Missing (Score: 4)

**Issue**: Line 56 mentions "Client (Web/Mobile)" but no mobile-specific security design (certificate pinning, jailbreak detection, API key storage).

**Impact**: Mobile app reverse engineering exposes API keys, lack of certificate pinning enables MitM attacks

**Recommendation**:
- Implement certificate pinning in mobile apps for CloudFront and API Gateway
- Use iOS Keychain / Android Keystore for JWT storage (not SharedPreferences)
- Add jailbreak/root detection with warnings
- Implement mobile-specific rate limits (stricter than web)

**Category**: Authentication Design / Infrastructure Security

---

## Infrastructure Security Assessment Table

| Component | Configuration | Security Measure | Status | Risk Level | Recommendation |
|-----------|---------------|------------------|--------|------------|----------------|
| PostgreSQL RDS | Access control, encryption, backup | Encryption at rest (implied), Multi-AZ (line 301) | **Partial** | **Critical** | Enable encryption at rest, implement database user privilege separation, configure RDS Parameter Group with `ssl=on` |
| Redis ElastiCache | Network isolation, authentication | Cluster mode mentioned (line 303) | **Missing** | **High** | Enable AUTH, configure VPC private subnet, enable encryption in transit |
| Elasticsearch OpenSearch | Network isolation, authentication, encryption | Managed service (line 36) | **Missing** | **Critical** | Enable encryption at rest with KMS, configure VPC endpoint, implement field-level encryption for PII |
| Kong API Gateway | Authentication, rate limiting, CORS | Rate limiting 100req/min (line 298), HTTPS/TLS 1.3 (line 294) | **Partial** | **High** | Add per-endpoint rate limits, configure JWT plugin, implement IP allowlist for admin endpoints, add Bot Detection plugin |
| CloudFront CDN | Cache policy, security headers | TLS 1.3 (line 294) | **Partial** | **Medium** | Add security headers (HSTS, CSP, X-Frame-Options), enable AWS WAF integration, configure geo-blocking for high-risk countries |
| AWS Secrets Manager | Rotation, access control, storage | Not mentioned | **Missing** | **Critical** | Implement with 30-90 day rotation schedules, configure IAM policies per service, enable automatic rotation for RDS credentials |
| ECS Fargate | IAM roles, network security | Auto-scaling 3-10 tasks (line 302) | **Partial** | **High** | Create least-privilege IAM task roles per service, configure security groups (deny all inbound, allow outbound to RDS/Redis only), enable container insights |
| Stripe Integration | Webhook verification, PCI compliance | Credit card data delegated to Stripe (line 297) | **Partial** | **High** | Implement webhook signature verification, use Stripe Elements for PCI compliance, configure webhook endpoint allowlist |
| GitHub Actions CI/CD | Secret management, deployment controls | Automated deployment (lines 279-282) | **Missing** | **Medium** | Use GitHub Secrets for credentials, implement branch protection rules (require approval for production), enable Dependabot security alerts |
| CloudWatch / Datadog | Log retention, alerting | Monitoring mentioned (line 39, 269) | **Partial** | **Medium** | Configure log retention (audit logs = 365 days, app logs = 90 days), set up alerts for failed auth attempts, enable CloudWatch anomaly detection |

---

## Evaluation Scores by Criterion

| Criterion | Score | Justification |
|-----------|-------|---------------|
| **1. Threat Modeling (STRIDE)** | **2/5** | **Significant issues**. Missing mitigations for Spoofing (CSRF protection absent), Tampering (no integrity checks for booking modifications), Repudiation (incomplete audit logging), Information Disclosure (JWT content readable, error details exposed), DoS (insufficient rate limiting), Elevation of Privilege (database privilege separation missing). Positive: TLS 1.3 mitigates network-level tampering. |
| **2. Authentication & Authorization** | **2/5** | **Significant issues**. JWT design flawed (no payload encryption, no "alg" validation, no token rotation post-password-change). RBAC model simplistic (only USER/ADMIN roles). Missing: CSRF protection, session concurrency limits, supplier API authentication design, refund authorization policy. Positive: bcrypt password hashing with cost 12. |
| **3. Data Protection** | **1/5** | **Critical issues**. Missing encryption at rest for Elasticsearch (PII exposure). No database privilege separation (SQL injection blast radius). No idempotency guarantees (duplicate charges). Incomplete data retention policy (account deletion conflicts with financial record retention). Positive: TLS 1.3 in transit, Stripe delegates card storage. |
| **4. Input Validation Design** | **1/5** | **Critical issues**. No input validation policy defined. Missing specifications for email format, password complexity, amount limits, date validation. No Elasticsearch query injection prevention. No output encoding for XSS prevention in admin dashboard. No JSONB schema validation for `booking_details`. |
| **5. Infrastructure & Dependency Security** | **2/5** | **Significant issues**. Missing: secrets rotation policy, dependency vulnerability scanning, ECS task role least privilege, Redis authentication, OpenSearch encryption. Partial: RDS Multi-AZ (good), CloudFront CDN (missing security headers), Kong rate limiting (incomplete). Library versions documented but no update policy. |

**Overall Weighted Score: 1.8/5 (Critical to Significant Risk)**

---

## Positive Security Aspects

1. **Strong Password Hashing**: bcrypt with cost factor 12 (line 295) aligns with OWASP recommendations
2. **TLS 1.3 Enforcement**: Modern TLS version (line 294) prevents downgrade attacks
3. **PCI DSS Compliance**: Credit card data delegated to Stripe (line 297) eliminates PCI scope
4. **Multi-AZ Database**: RDS Multi-AZ (line 301) provides high availability
5. **Auto-Scaling**: ECS Fargate 3-10 tasks (line 302) supports traffic spikes
6. **JWT Expiration**: 1-hour token lifetime (line 240) limits exposure window
7. **Rate Limiting Foundation**: 100 req/min user limit (line 298) provides baseline DoS protection

---

## Recommendations Summary

### Immediate Actions (Critical - Complete within 2 weeks)
1. Implement JWT payload encryption (JWE with A256GCM)
2. Configure database privilege separation (separate PostgreSQL users per service)
3. Enable OpenSearch encryption at rest with AWS KMS
4. Implement CSRF protection (Double-Submit Cookie or Synchronizer Token)
5. Define and enforce input validation policy with Bean Validation
6. Add idempotency key support for booking/payment endpoints
7. Implement comprehensive audit logging policy with 365-day retention
8. Configure AWS Secrets Manager with rotation schedules

### Short-Term (Significant - Complete within 1 month)
9. Strengthen rate limiting (per-endpoint limits, exponential backoff for auth)
10. Implement environment-specific error handling (no stack traces in production)
11. Design secure password reset tokens (15-min expiration, single-use)
12. Add session management controls (concurrent session limits, logout-all endpoint)
13. Configure supplier API authentication (mTLS, certificate pinning)
14. Implement booking state machine with optimistic locking
15. Restrict refund endpoint to ADMIN role with policy engine
16. Enable Redis AUTH and VPC isolation
17. Integrate OWASP Dependency-Check into CI/CD

### Medium-Term (Moderate - Complete within 3 months)
18. Add CloudFront security headers (HSTS, CSP, X-Frame-Options)
19. Configure HikariCP connection pool limits
20. Implement JWT algorithm validation (reject "alg=none")
21. Add ETag/If-Match for concurrent booking modification prevention
22. Implement PII masking in logs
23. Use Elasticsearch Query Builders to prevent injection
24. Design account deletion with data retention policy (soft delete)
25. Configure Kong security plugins (JWT validation, request size limits, IP allowlist)
26. Implement Stripe webhook signature verification
27. Create least-privilege ECS task IAM roles
28. Enable RDS backup encryption with restoration access control
29. Implement Resilience4j circuit breaker for supplier APIs
30. Enforce mandatory pagination with authorization filters
31. Separate dev/staging/production AWS accounts and secrets
32. Add mobile-specific security (certificate pinning, Keystore, jailbreak detection)

---

## Conclusion

The TravelHub design demonstrates foundational security awareness (TLS 1.3, bcrypt, Multi-AZ) but exhibits critical gaps across all evaluation criteria. The **10 critical issues**—particularly JWT content exposure, database privilege vulnerabilities, Elasticsearch unencrypted data, and missing CSRF protection—pose immediate risk of data breach, financial fraud, and regulatory non-compliance.

Prioritize remediation of critical and significant issues before production deployment. The hybrid free-form + tabular approach enabled comprehensive detection across authentication, data protection, and infrastructure layers. **Recommendation: Address all Critical (Score 1-2) issues before launch; implement Significant (Score 3) issues within first 3 months post-launch.**
