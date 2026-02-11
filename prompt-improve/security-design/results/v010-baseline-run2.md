# Security Design Review: TravelHub System

## Executive Summary

This security review evaluates the TravelHub travel booking platform design document from an architecture and design perspective. The evaluation identifies **3 critical issues**, **8 significant issues**, and **11 moderate issues** across five security domains: Threat Modeling, Authentication & Authorization, Data Protection, Input Validation, and Infrastructure & Dependency Security.

**Critical Issues Requiring Immediate Action:**
1. Missing idempotency guarantees for payment and booking operations (risk of duplicate charges)
2. Missing CSRF protection design for state-changing operations
3. Missing audit logging design for compliance and security incident response

---

## Overall Security Scores

| Evaluation Criterion | Score | Severity |
|---------------------|-------|----------|
| 1. Threat Modeling (STRIDE) | 2 | Significant |
| 2. Authentication & Authorization Design | 3 | Moderate |
| 3. Data Protection | 2 | Significant |
| 4. Input Validation Design | 2 | Significant |
| 5. Infrastructure & Dependency Security | 3 | Moderate |

**Overall Assessment: 2.4/5.0 (Significant Issues)**

---

## Critical Issues (Score 1: Immediate Action Required)

### C-1: Missing Idempotency Guarantees for Payment Operations
**Severity:** Critical (Score 1)
**Category:** Data Protection, Threat Modeling (Tampering)

**Issue:**
The design document does not specify idempotency mechanisms for payment and booking operations. Without idempotency keys or duplicate detection:
- Network failures during `POST /api/v1/payments` could result in duplicate charges
- Retry logic in clients or middleware could trigger multiple payment transactions
- Users could be charged multiple times for a single booking

**Impact:**
- Financial loss for customers (duplicate charges)
- Compliance violations (PCI DSS, consumer protection laws)
- Reputation damage and loss of customer trust
- Expensive manual refund processes

**Affected Components:**
- `POST /api/v1/payments` (Section 5: API Design)
- `POST /api/v1/bookings` (Section 5: API Design)
- Payment Service (Section 3: Architecture Design)

**Recommended Countermeasures:**
1. **Implement idempotency key design:**
   - Require clients to send `Idempotency-Key` header for all state-changing operations
   - Store idempotency keys in Redis with transaction results (24-48 hour TTL)
   - Return cached response for duplicate requests with same idempotency key

2. **Add transaction deduplication:**
   - Use database constraints (UNIQUE constraint on `stripe_payment_intent_id`)
   - Implement optimistic locking with version columns in `bookings` and `payment_transactions` tables

3. **Design retry handling policy:**
   - Define which operations are safe to retry
   - Document client-side retry behavior expectations
   - Add `Idempotency-Key` to API documentation

**References:**
- Section 5: API Design - POST /api/v1/payments
- Section 4: Data Model - payment_transactions table
- Stripe Best Practices: https://stripe.com/docs/api/idempotent_requests

---

### C-2: Missing CSRF Protection Design
**Severity:** Critical (Score 1)
**Category:** Threat Modeling (Tampering), Input Validation

**Issue:**
The design document does not specify CSRF (Cross-Site Request Forgery) protection mechanisms. While JWT authentication is mentioned, there is no design for:
- CSRF tokens for state-changing operations
- Cookie security attributes (`SameSite`, `Secure`, `HttpOnly`)
- Protection against malicious sites triggering authenticated requests

**Impact:**
- Attackers could trick authenticated users into making unauthorized bookings
- Malicious sites could trigger payment operations using victim's session
- Potential for fraudulent cancellations or account modifications

**Affected Components:**
- All state-changing endpoints (POST/PUT/DELETE in Section 5)
- JWT storage and transmission mechanism (Section 5: Authentication)
- Frontend-backend session management

**Recommended Countermeasures:**
1. **Implement double-submit cookie pattern:**
   - Generate CSRF token on login and store in HttpOnly cookie
   - Require clients to send token in custom header (`X-CSRF-Token`)
   - Validate token server-side for all state-changing operations

2. **Configure secure cookie attributes:**
   - `SameSite=Strict` for session cookies (or `Lax` if cross-site navigation is required)
   - `Secure` flag to enforce HTTPS transmission
   - `HttpOnly` flag to prevent JavaScript access

3. **Add origin/referer validation:**
   - Validate `Origin` and `Referer` headers match expected domains
   - Reject requests from untrusted origins

4. **Document CSRF requirements:**
   - Add CSRF token to API authentication documentation
   - Specify token refresh and expiration policy

**References:**
- Section 5: API Design - All POST/PUT/DELETE endpoints
- OWASP CSRF Prevention Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html

---

### C-3: Missing Audit Logging Design
**Severity:** Critical (Score 1)
**Category:** Threat Modeling (Repudiation), Infrastructure Security

**Issue:**
The design document mentions logging in Section 6 (Implementation Policy) but lacks comprehensive audit logging design for security-critical events:
- No specification of what security events to log (authentication failures, authorization denials, data access)
- No audit trail for admin actions (user suspension, booking modifications)
- No log retention policy for compliance requirements
- No log integrity protection mechanisms

**Impact:**
- Inability to detect security breaches or unauthorized access
- Inability to investigate security incidents (no forensic trail)
- Compliance violations (PCI DSS requires 1 year log retention, GDPR requires audit trails)
- No evidence for dispute resolution (chargebacks, booking conflicts)

**Affected Components:**
- All services (User, Search, Booking, Payment, Admin - Section 3)
- Section 6: Implementation Policy - Logging Policy
- Section 7: Non-functional Requirements - Security Requirements

**Recommended Countermeasures:**
1. **Design comprehensive audit logging policy:**
   - **Authentication events:** Login success/failure, logout, password reset, token refresh
   - **Authorization events:** Access denials, privilege escalation attempts
   - **Data access events:** PII access, payment data access, admin queries
   - **State-changing events:** Booking creation/modification/cancellation, payment transactions, refunds
   - **Admin actions:** User suspension, system configuration changes, bulk operations

2. **Define log retention policy:**
   - Security logs: 1 year minimum (PCI DSS requirement)
   - Audit logs: 3 years for financial transactions (compliance)
   - Archive to S3 with lifecycle policies for cost optimization

3. **Implement log integrity protection:**
   - Use AWS CloudWatch Logs with encryption at rest
   - Enable CloudTrail for AWS API audit logs
   - Consider append-only logging with cryptographic signatures
   - Restrict log deletion permissions to dedicated security role

4. **Add log monitoring and alerting:**
   - Alert on repeated authentication failures (brute-force detection)
   - Alert on admin privilege usage
   - Alert on payment anomalies (large refunds, unusual patterns)

5. **Document audit log schema:**
   - Include: timestamp, user_id, action, resource, IP address, user agent, result (success/failure)
   - Use structured JSON logs for parsing and analysis

**References:**
- Section 6: Implementation Policy - Logging Policy
- PCI DSS Requirement 10: Track and Monitor All Access
- GDPR Article 30: Records of Processing Activities

---

## Significant Issues (Score 2: High Likelihood of Attack)

### S-1: Missing Rate Limiting Design Details
**Severity:** Significant (Score 2)
**Category:** Threat Modeling (Denial of Service)

**Issue:**
Section 7 mentions "100req/min per user" rate limiting at Kong API Gateway, but the design lacks critical details:
- No rate limiting for unauthenticated endpoints (`POST /api/v1/auth/login`, `/register`)
- No specification of rate limiting scope (per IP? per user? per endpoint?)
- No design for distributed rate limiting across multiple Gateway instances
- No handling of brute-force attacks on authentication endpoints

**Impact:**
- Brute-force attacks on login endpoint (credential stuffing)
- Account enumeration via registration endpoint
- DoS attacks via expensive search operations
- Resource exhaustion from unlimited retry attempts

**Affected Components:**
- Section 7: Security Requirements - Rate Limiting
- Section 5: API Design - All endpoints
- Kong API Gateway (Section 2: Technology Stack)

**Recommended Countermeasures:**
1. **Design endpoint-specific rate limits:**
   - `/api/v1/auth/login`: 5 attempts per 15 minutes per IP (brute-force protection)
   - `/api/v1/auth/register`: 3 registrations per hour per IP (spam prevention)
   - `/api/v1/search/*`: 20 requests per minute per user (expensive operations)
   - `/api/v1/bookings`: 10 requests per minute per user
   - `/api/v1/payments`: 5 requests per minute per user

2. **Implement multi-layered rate limiting:**
   - Global rate limit: 1000 req/min per IP (DDoS protection)
   - Per-user rate limit: 100 req/min authenticated requests
   - Per-endpoint rate limit: See above

3. **Use Redis for distributed rate limiting:**
   - Store rate limit counters in Redis with sliding window algorithm
   - Use Kong Redis plugin or implement custom middleware

4. **Add progressive penalties:**
   - Temporary IP bans after repeated violations (exponential backoff)
   - CAPTCHA challenges after suspicious patterns

5. **Document rate limiting in API responses:**
   - Return HTTP 429 (Too Many Requests) with `Retry-After` header
   - Include rate limit headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`

**References:**
- Section 7: Non-functional Requirements - Security Requirements
- OWASP API Security Top 10: API4:2023 Unrestricted Resource Consumption

---

### S-2: Missing Session Management Security Design
**Severity:** Significant (Score 2)
**Category:** Authentication & Authorization, Threat Modeling (Spoofing)

**Issue:**
The design mentions JWT tokens stored in Redis but lacks critical session management security specifications:
- No session timeout policy (only token expiration: 1 hour)
- No design for session termination on logout (Redis invalidation strategy)
- No concurrent session limit per user
- No session hijacking protection (IP/User-Agent binding)
- No design for "remember me" functionality security

**Impact:**
- Stolen tokens could be used for extended periods without detection
- No ability to revoke compromised sessions globally
- Session fixation attacks if token reuse is possible
- Credential stuffing could create unlimited concurrent sessions

**Affected Components:**
- Section 5: Authentication & Authorization - JWT Token Design
- User Service (Section 3: Architecture)
- Redis session storage (Section 2: Technology Stack)

**Recommended Countermeasures:**
1. **Design comprehensive session management policy:**
   - **Absolute session timeout:** 8 hours maximum (force re-login)
   - **Idle timeout:** 1 hour of inactivity (current token expiration)
   - **Concurrent session limit:** 5 active sessions per user
   - **Session rotation:** Generate new token every 15 minutes (refresh token pattern)

2. **Implement secure logout mechanism:**
   - Blacklist revoked tokens in Redis (store until expiration)
   - Provide "logout all devices" functionality
   - Clear tokens from Redis on password change

3. **Add session binding:**
   - Store IP address and User-Agent hash in Redis session metadata
   - Validate on each request (with allowance for legitimate changes)
   - Alert user on suspicious session activity

4. **Design refresh token pattern:**
   - Short-lived access tokens (15 minutes)
   - Long-lived refresh tokens (7 days) stored in HttpOnly cookie
   - Refresh token rotation on each use
   - Store refresh token family in database to detect token replay

**References:**
- Section 5: Authentication & Authorization
- OWASP Session Management Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html

---

### S-3: Missing Input Validation Policy and Specifications
**Severity:** Significant (Score 2)
**Category:** Input Validation, Threat Modeling (Injection)

**Issue:**
The design document does not specify input validation policies or validation rules:
- No validation rules for email format, phone numbers, names (Section 4: users table)
- No length limits for JSON fields (`booking_details` JSONB column)
- No specification of SQL injection prevention measures
- No XSS prevention strategy for user-generated content (reviews, names)
- No file upload validation (passport documents, profile pictures)

**Impact:**
- SQL injection via unsanitized inputs (even with JPA, native queries are vulnerable)
- XSS attacks via stored user data displayed to other users
- DoS via oversized JSON payloads in `booking_details`
- Data integrity issues from invalid email/phone formats

**Affected Components:**
- Section 5: API Design - All request bodies
- Section 4: Data Model - All user-facing columns
- Section 3: All backend services

**Recommended Countermeasures:**
1. **Define input validation policy:**
   - **Email:** RFC 5322 format, max 255 characters, normalize to lowercase
   - **Phone:** E.164 format, 7-15 digits, store country code
   - **Names:** 1-255 characters, Unicode letters/spaces/hyphens only, XSS-encode on output
   - **Passwords:** 12-128 characters, require uppercase/lowercase/digit/special
   - **UUIDs:** Validate UUID format for all ID parameters
   - **Amounts:** Positive decimal, max 999999.99, two decimal places

2. **Design JSON input validation:**
   - Define JSON Schema for `booking_details` column
   - Enforce max size: 100KB per request body
   - Validate nested structure and required fields
   - Reject unknown properties (fail closed)

3. **Implement injection prevention:**
   - Use parameterized queries exclusively (enforce in code review)
   - Escape special characters in native SQL queries (avoid if possible)
   - Validate Elasticsearch queries to prevent script injection
   - Sanitize inputs to external supplier APIs

4. **Design XSS prevention:**
   - Context-aware output encoding (HTML entity encoding for names in UI)
   - Content Security Policy (CSP) headers for React frontend
   - Sanitize HTML in review/comment fields (if rich text is allowed)

5. **Add API request validation:**
   - Use Spring Validation (`@Valid`, `@NotNull`, `@Size`, `@Pattern`)
   - Return structured validation errors (HTTP 400 with field-specific messages)

**References:**
- Section 5: API Design - Request/Response Formats
- OWASP Input Validation Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html

---

### S-4: Missing Data Retention and Deletion Policy
**Severity:** Significant (Score 2)
**Category:** Data Protection, Threat Modeling (Information Disclosure)

**Issue:**
The design does not specify data retention and deletion policies required for GDPR and privacy compliance:
- No retention period for user accounts, booking history, payment records
- No "right to be forgotten" implementation design (GDPR Article 17)
- No specification of what data to delete vs. anonymize (financial records must be retained)
- No design for cascading deletions (user → bookings → payments)

**Impact:**
- GDPR compliance violations (fines up to €20M or 4% of annual revenue)
- Privacy violations from retaining unnecessary personal data
- Increased attack surface (more stored PII = larger breach impact)
- Legal liability from unauthorized data retention

**Affected Components:**
- Section 5: API Design - `DELETE /api/v1/users/account`
- Section 4: Data Model - users, bookings, payment_transactions tables
- All backend services (Section 3)

**Recommended Countermeasures:**
1. **Design data retention policy:**
   - **Active user data:** Retain until account deletion request
   - **Inactive accounts:** Anonymize after 3 years of inactivity
   - **Booking records:** Retain for 7 years (tax/audit requirements)
   - **Payment records:** Retain for 7 years (PCI DSS, financial regulations)
   - **Logs:** 1 year for security logs, 3 years for audit logs

2. **Implement "right to be forgotten" design:**
   - On account deletion: Delete PII (name, email, phone) from `users` table
   - Anonymize associated bookings: Replace name with "Deleted User", nullify phone/email
   - Retain booking and payment records with anonymized user reference (compliance)
   - Delete cached data from Redis and Elasticsearch
   - Provide data export functionality (GDPR Article 20: Data Portability)

3. **Design cascading deletion policy:**
   - Soft delete user accounts (set `deleted_at` timestamp, retain data for 30 days)
   - Scheduled job to anonymize soft-deleted accounts after grace period
   - Prevent hard deletion of users with active bookings
   - Document retention exceptions (legal holds, fraud investigations)

4. **Add data minimization:**
   - Only collect necessary PII (avoid storing passport numbers unless legally required)
   - Use encrypted storage for sensitive fields (phone, passport)
   - Implement field-level access control (limit who can view full PII)

**References:**
- Section 5: API Design - DELETE /api/v1/users/account
- GDPR Article 17: Right to Erasure
- PCI DSS Requirement 3: Protect Stored Cardholder Data

---

### S-5: Missing Error Handling Security Policy
**Severity:** Significant (Score 2)
**Category:** Threat Modeling (Information Disclosure), Input Validation

**Issue:**
Section 6 defines error response format but lacks security-specific error handling policy:
- No specification of what error details to expose vs. hide (stack traces, database errors)
- No design for preventing user enumeration via error messages
- No rate limiting on error responses (error-based DoS)
- No logging of security-relevant errors

**Impact:**
- Information disclosure via verbose error messages (database schema, file paths)
- User enumeration: Different errors for "user not found" vs. "wrong password"
- Brute-force attacks aided by detailed error feedback
- Security incidents undetected due to missing error logging

**Affected Components:**
- Section 6: Implementation Policy - Error Handling Policy
- GlobalExceptionHandler (Section 6)
- All API endpoints (Section 5)

**Recommended Countermeasures:**
1. **Design error exposure policy:**
   - **Production environment:** Generic error messages only ("An error occurred")
   - **Development environment:** Detailed errors (stack traces, SQL errors)
   - **Never expose:** Database schema, file paths, library versions, internal IPs
   - **Sanitize error codes:** Use application-specific codes (not database error codes)

2. **Prevent user enumeration:**
   - Login: Same error for "user not found" and "wrong password" ("Invalid credentials")
   - Registration: Don't reveal if email already exists (send "confirmation email" regardless)
   - Password reset: Same response whether email exists or not

3. **Design error logging policy:**
   - Log all errors with full context (user_id, request_id, stack trace) server-side
   - Correlate client error responses with server logs via request_id
   - Alert on repeated errors from same user/IP (potential attack)

4. **Add error rate limiting:**
   - Limit consecutive errors per user/IP (e.g., 50 errors per 5 minutes)
   - Temporary block IPs generating excessive errors

5. **Define exception handling hierarchy:**
   - Authentication failures: HTTP 401, generic message
   - Authorization failures: HTTP 403, "Access denied"
   - Validation errors: HTTP 400, field-specific messages (safe to expose)
   - Business logic errors: HTTP 409, application-specific error codes
   - Server errors: HTTP 500, generic message + unique error_id for support

**References:**
- Section 6: Implementation Policy - Error Handling Policy
- OWASP Error Handling Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html

---

### S-6: Missing Encryption at Rest Design
**Severity:** Significant (Score 2)
**Category:** Data Protection

**Issue:**
Section 7 specifies TLS 1.3 for data in transit but does not specify encryption at rest for sensitive data:
- No encryption design for PostgreSQL database (users, bookings, payment_transactions)
- No encryption for Redis cache (JWT metadata, session data)
- No encryption for CloudWatch logs (may contain PII)
- No key management design (KMS usage, key rotation)

**Impact:**
- Data breach if database backups are stolen or misconfigured S3 buckets are exposed
- Compliance violations (PCI DSS requires encryption of payment data at rest)
- Credential exposure if Redis snapshots are compromised
- PII exposure from log files

**Affected Components:**
- Section 2: Technology Stack - PostgreSQL, Redis
- Section 7: Security Requirements
- Section 3: Data Layer

**Recommended Countermeasures:**
1. **Enable database encryption:**
   - **PostgreSQL RDS:** Enable encryption at rest with AWS KMS (AES-256)
   - **Redis ElastiCache:** Enable encryption at rest and in-transit encryption
   - Use AWS-managed keys (aws/rds, aws/elasticache) or customer-managed KMS keys

2. **Design field-level encryption:**
   - Encrypt sensitive fields in application layer before storing in database:
     - `users.phone_number` (PII)
     - `bookings.booking_details` (passport numbers, PII)
   - Use AWS Encryption SDK or Spring Crypto utilities
   - Store encryption keys in AWS Secrets Manager

3. **Enable log encryption:**
   - CloudWatch Logs: Enable encryption with KMS key
   - S3 log archives: Enable SSE-KMS encryption
   - Datadog: Use encrypted log forwarding

4. **Design key management policy:**
   - Use AWS KMS for key management (automatic key rotation enabled)
   - Separate keys per environment (dev/staging/production)
   - Key rotation schedule: Automatic annual rotation for data keys
   - Access control: Restrict KMS key usage to specific IAM roles
   - Audit: Enable CloudTrail logging for all KMS operations

5. **Implement backup encryption:**
   - RDS automated backups: Encrypted if database encryption is enabled
   - Manual snapshots: Verify encryption before archival
   - Cross-region replication: Maintain encryption in transit and at rest

**References:**
- Section 7: Security Requirements
- PCI DSS Requirement 3.4: Render PAN Unreadable
- AWS RDS Encryption: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.Encryption.html

---

### S-7: Missing Dependency Security Management Design
**Severity:** Significant (Score 2)
**Category:** Infrastructure & Dependency Security

**Issue:**
Section 2 lists specific library versions but lacks dependency security management design:
- No vulnerability scanning process for Java dependencies
- No policy for updating dependencies with security patches
- No specification of dependency source verification (Maven Central integrity)
- No design for monitoring CVEs affecting used libraries

**Impact:**
- Exploitation of known vulnerabilities in third-party libraries (Log4Shell-type incidents)
- Supply chain attacks via compromised dependencies
- Delayed patching due to missing monitoring process

**Affected Components:**
- Section 2: Technology Stack - Major Libraries
- Section 6: Deployment Policy
- All backend services (Section 3)

**Recommended Countermeasures:**
1. **Implement dependency scanning:**
   - Integrate OWASP Dependency-Check or Snyk in CI/CD pipeline
   - Fail builds with HIGH/CRITICAL vulnerabilities
   - Weekly scheduled scans of production dependencies

2. **Design dependency update policy:**
   - Security patches: Apply within 7 days for CRITICAL, 30 days for HIGH
   - Minor version updates: Monthly review and update
   - Major version updates: Quarterly evaluation (breaking changes)
   - Document exemptions for unfixable vulnerabilities (with compensating controls)

3. **Enable dependency verification:**
   - Use Maven dependency verification (checksums, signatures)
   - Configure private Maven repository (Nexus/Artifactory) as proxy
   - Block unauthenticated dependency downloads

4. **Monitor vulnerability databases:**
   - Subscribe to GitHub Security Advisories for used libraries
   - Monitor NVD (National Vulnerability Database) for CVEs
   - Use automated tools: Dependabot, Renovate Bot

5. **Document approved dependencies:**
   - Maintain allowlist of approved libraries and versions
   - Require security review for new dependencies
   - Avoid dependencies with poor security track records

**References:**
- Section 2: Technology Stack - Major Libraries
- OWASP Dependency-Check: https://owasp.org/www-project-dependency-check/
- NIST NVD: https://nvd.nist.gov/

---

### S-8: Missing Password Reset Security Design
**Severity:** Significant (Score 2)
**Category:** Authentication & Authorization, Threat Modeling (Spoofing)

**Issue:**
Section 5 lists password reset endpoints but lacks critical security design:
- No specification of reset token generation, expiration, or validation
- No rate limiting design for password reset requests (email bombing)
- No session invalidation on password change
- No notification design for suspicious password reset attempts

**Impact:**
- Account takeover via password reset token brute-force or interception
- Email bombing DoS attacks
- Stolen sessions remain valid after password change

**Affected Components:**
- Section 5: API Design - `/api/v1/auth/reset-password`, `/api/v1/auth/confirm-reset`
- User Service (Section 3)

**Recommended Countermeasures:**
1. **Design secure password reset flow:**
   - Generate cryptographically secure random reset token (256-bit minimum)
   - Store hashed token in database (bcrypt/Argon2)
   - Token expiration: 1 hour from generation
   - Single-use tokens (invalidate after successful reset)

2. **Implement reset token transmission security:**
   - Send reset link via email with HTTPS link
   - Include user-specific context in email (username, timestamp, IP address)
   - Do NOT include token in URL query parameters (use POST with token in body)
   - Alternative: Send short-lived code (6 digits, 10-minute expiration) for mobile

3. **Add rate limiting:**
   - Limit password reset requests: 3 per hour per email address
   - Limit confirmation attempts: 5 per token (prevent brute-force)
   - CAPTCHA after failed attempts

4. **Design session invalidation:**
   - Revoke all JWT tokens on password change (clear Redis session data)
   - Require re-login after password reset
   - Send notification email to user on successful password change

5. **Add security monitoring:**
   - Alert on multiple password reset requests for same account
   - Log IP address and User-Agent for all reset requests
   - Notify user via email on password reset initiation (with "not you?" link)

**References:**
- Section 5: API Design - Authentication endpoints
- OWASP Forgot Password Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html

---

## Moderate Issues (Score 3: Exploitable Under Specific Conditions)

### M-1: Missing JWT Security Specifications
**Severity:** Moderate (Score 3)
**Category:** Authentication & Authorization

**Issue:**
Section 5 mentions JWT with HS256 signing but lacks critical JWT security specifications:
- No specification of JWT secret key strength or storage location
- No JWT claims design (iss, aud, exp, nbf, jti)
- No prevention of algorithm confusion attacks (alg: none)
- No design for token refresh without password re-entry

**Recommended Countermeasures:**
- Use strong secret key (256-bit minimum) stored in AWS Secrets Manager
- Define JWT claims: `iss: "travelhub-api"`, `aud: "travelhub-client"`, `exp`, `iat`, `jti` (unique token ID)
- Validate algorithm in JWT verification (reject "none" and asymmetric algorithms)
- Implement refresh token pattern (Section S-2)
- Consider using RS256 (asymmetric) for better key security

**References:** Section 5: Authentication & Authorization

---

### M-2: Missing Content Security Policy Design
**Severity:** Moderate (Score 3)
**Category:** Input Validation, Threat Modeling (Injection)

**Issue:**
No Content Security Policy (CSP) design for React frontend to mitigate XSS attacks.

**Recommended Countermeasures:**
- Define CSP header for React frontend:
  - `default-src 'self'`
  - `script-src 'self' 'sha256-...' (hashes of inline scripts)`
  - `style-src 'self' 'unsafe-inline'` (or use CSS-in-JS with nonces)
  - `img-src 'self' https:`
  - `connect-src 'self' https://api.travelhub.com`
- Use `X-Content-Type-Options: nosniff`
- Use `X-Frame-Options: DENY` (prevent clickjacking)
- Configure CloudFront to add security headers

**References:** Section 2: Technology Stack (React 18)

---

### M-3: Missing Monitoring and Alerting for Security Events
**Severity:** Moderate (Score 3)
**Category:** Infrastructure Security, Threat Modeling (Detection)

**Issue:**
Section 2 mentions CloudWatch and Datadog but lacks security monitoring design:
- No specification of security metrics to monitor
- No alerting for authentication anomalies, privilege escalation attempts
- No integration with SIEM or security incident response tools

**Recommended Countermeasures:**
- Define security metrics:
  - Failed login attempts per user/IP (threshold: 10/5min)
  - Admin privilege usage (alert on any admin action)
  - Unusual payment patterns (large amounts, rapid refunds)
  - API error rate spikes (potential attack)
- Integrate AWS GuardDuty for threat detection
- Set up PagerDuty alerts for critical security events
- Create Datadog dashboards for security metrics

**References:** Section 2: Technology Stack - Monitoring

---

### M-4: Missing API Gateway Security Configuration
**Severity:** Moderate (Score 3)
**Category:** Infrastructure Security

**Issue:**
Kong API Gateway is mentioned but lacks security configuration design:
- No specification of Kong authentication plugins
- No request size limits to prevent large payload DoS
- No IP allowlist/blocklist design for admin endpoints
- No API key management for service-to-service communication

**Recommended Countermeasures:**
- Configure Kong JWT plugin for authentication validation at gateway
- Set request size limits (max 10MB, 1MB for most endpoints)
- Use Kong IP Restriction plugin for `/api/v1/admin/*` endpoints (internal network only)
- Implement Kong Rate Limiting plugin (see S-1)
- Use Kong Request Termination plugin for maintenance mode
- Enable Kong Correlation ID plugin for request tracing

**References:** Section 2: Technology Stack - Kong 3.4

---

### M-5: Missing Database Access Control Design
**Severity:** Moderate (Score 3)
**Category:** Data Protection, Threat Modeling (Elevation of Privilege)

**Issue:**
No specification of database access control beyond connection credentials:
- No least-privilege database user roles
- No read-only replicas for reporting queries
- No network-level access restrictions (VPC, security groups)

**Recommended Countermeasures:**
- Create separate database users per service with minimal privileges:
  - `user_service_user`: SELECT, INSERT, UPDATE on `users` table only
  - `booking_service_user`: SELECT, INSERT, UPDATE on `bookings` table only
- Use read replicas for Admin Service reporting queries
- Configure RDS security groups: Only allow connections from ECS task security groups
- Enable RDS IAM authentication (avoid hardcoded credentials)
- Use AWS Secrets Manager for database credential rotation

**References:** Section 2: Technology Stack - PostgreSQL 15

---

### M-6: Missing Secure Headers Configuration
**Severity:** Moderate (Score 3)
**Category:** Input Validation, Infrastructure Security

**Issue:**
No specification of HTTP security headers beyond TLS:
- No `Strict-Transport-Security` (HSTS) design
- No `X-Content-Type-Options` or `X-Frame-Options`
- No `Permissions-Policy` for browser feature restrictions

**Recommended Countermeasures:**
- Configure security headers at CloudFront or Kong Gateway:
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Permissions-Policy: geolocation=(), microphone=(), camera=()`
  - `Referrer-Policy: strict-origin-when-cross-origin`
- Add to HSTS preload list: https://hstspreload.org/

**References:** Section 7: Security Requirements - HTTPS/TLS 1.3

---

### M-7: Missing Secrets Management Design
**Severity:** Moderate (Score 3)
**Category:** Infrastructure & Dependency Security

**Issue:**
No specification of how secrets (database passwords, API keys, JWT secret) are managed:
- No design for secret storage, rotation, or access control
- No specification of how secrets are injected into ECS tasks

**Recommended Countermeasures:**
- Store all secrets in AWS Secrets Manager:
  - Database credentials (with automatic rotation enabled)
  - JWT signing secret
  - Stripe API keys
  - Third-party supplier API credentials
- Use ECS task role to access Secrets Manager (no hardcoded credentials)
- Configure automatic rotation: 90 days for database credentials, 180 days for API keys
- Audit secret access via CloudTrail logs
- Use separate secrets per environment (dev/staging/production)

**References:** Section 7: Security Requirements

---

### M-8: Missing Supplier API Security Design
**Severity:** Moderate (Score 3)
**Category:** Infrastructure Security, Threat Modeling (Tampering)

**Issue:**
Section 3 mentions integration with supplier APIs but lacks security design:
- No specification of supplier API authentication mechanisms
- No validation of supplier API responses (injection, data integrity)
- No timeout and retry design for supplier API calls
- No isolation design if supplier API is compromised

**Recommended Countermeasures:**
- Design supplier API authentication:
  - Use mutual TLS (mTLS) for supplier connections where supported
  - Store supplier API credentials in AWS Secrets Manager
  - Rotate API keys quarterly
- Validate supplier responses:
  - Define JSON schemas for expected responses
  - Sanitize supplier data before storing in database
  - Reject responses with unexpected fields (fail closed)
- Design timeout and circuit breaker:
  - Timeout: 3 seconds per supplier API call (as mentioned in Section 7)
  - Circuit breaker: Open after 5 consecutive failures
  - Fallback: Return cached results or "temporarily unavailable" message
- Implement network isolation:
  - Use NAT Gateway with static IP for supplier API calls
  - Allowlist TravelHub IPs at supplier firewall

**References:** Section 3: Search Service, Booking Service

---

### M-9: Missing Admin Privilege Design
**Severity:** Moderate (Score 3)
**Category:** Authentication & Authorization, Threat Modeling (Elevation of Privilege)

**Issue:**
Section 5 defines `ADMIN` role but lacks granular privilege design:
- No specification of admin sub-roles (super admin, support admin, read-only admin)
- No audit trail for admin actions
- No multi-factor authentication requirement for admin accounts
- No approval workflow for sensitive admin operations (user suspension)

**Recommended Countermeasures:**
- Design granular admin roles:
  - `SUPER_ADMIN`: Full access to all admin endpoints
  - `SUPPORT_ADMIN`: View bookings, view users, cancel bookings (no user suspension)
  - `READONLY_ADMIN`: View-only access for reporting
- Require MFA for admin accounts (TOTP or hardware token)
- Implement approval workflow for sensitive operations:
  - User suspension requires approval from two admins
  - Bulk refunds require super admin approval
- Add audit logging for all admin actions (see C-3)
- Implement admin session timeout: 30 minutes idle, 4 hours absolute

**References:** Section 5: Authentication & Authorization - Roles

---

### M-10: Missing Backup and Disaster Recovery Security
**Severity:** Moderate (Score 3)
**Category:** Data Protection, Threat Modeling (Denial of Service)

**Issue:**
Section 7 mentions Multi-AZ RDS but lacks comprehensive disaster recovery design:
- No backup retention policy or restoration testing
- No specification of backup encryption
- No design for database restore procedures

**Recommended Countermeasures:**
- Define backup policy:
  - RDS automated backups: 7-day retention, daily snapshots
  - Manual snapshots before major deployments
  - Cross-region backup replication for disaster recovery
  - Backup encryption: Use KMS encryption (see S-6)
- Test restore procedures:
  - Quarterly disaster recovery drills (restore to test environment)
  - Document Recovery Time Objective (RTO): 4 hours
  - Document Recovery Point Objective (RPO): 1 hour (point-in-time recovery)
- Implement backup access control:
  - Restrict snapshot access to dedicated backup IAM role
  - Enable MFA delete for S3 backup archives
  - Audit backup access via CloudTrail

**References:** Section 7: Availability & Scalability

---

### M-11: Missing XSS Protection Design for User-Generated Content
**Severity:** Moderate (Score 3)
**Category:** Input Validation, Threat Modeling (Injection)

**Issue:**
Section 5 mentions review/rating system but lacks XSS protection design:
- No specification of HTML sanitization for review text
- No output encoding design for user names displayed in UI
- No validation of special characters in user inputs

**Recommended Countermeasures:**
- Sanitize user-generated content:
  - Use DOMPurify (frontend) or OWASP Java HTML Sanitizer (backend) for review text
  - Allow only safe HTML tags: `<p>`, `<br>`, `<strong>`, `<em>`
  - Strip all JavaScript, `<script>` tags, event handlers
- Implement context-aware output encoding:
  - HTML context: Encode `<`, `>`, `&`, `"`, `'`
  - JavaScript context: Use JSON.stringify with escaping
  - URL context: Percent-encode special characters
- Configure CSP (see M-2)
- Use React's built-in XSS protection (avoid `dangerouslySetInnerHTML`)

**References:** Section 5: API Design - Review/Rating System

---

## Detailed Analysis by Evaluation Criterion

### 1. Threat Modeling (STRIDE) - Score: 2 (Significant)

**Overall Assessment:** The design document lacks comprehensive threat modeling. Critical threats are not explicitly addressed, leaving significant security gaps.

#### Spoofing (Score: 2)
**Issues Identified:**
- Missing session hijacking protection (S-2)
- Missing password reset security (S-8)
- Missing JWT security specifications (M-1)

**Strengths:**
- JWT authentication is specified
- bcrypt password hashing (cost factor 12)

#### Tampering (Score: 1 - Critical)
**Issues Identified:**
- **CRITICAL:** Missing idempotency guarantees (C-1) - highest severity
- **CRITICAL:** Missing CSRF protection (C-2)
- Missing input validation policy (S-3)
- Missing supplier API response validation (M-8)

**Impact:** Data integrity attacks, duplicate payments, unauthorized state changes

#### Repudiation (Score: 1 - Critical)
**Issues Identified:**
- **CRITICAL:** Missing comprehensive audit logging (C-3)
- Missing admin action audit trail (M-9)

**Impact:** Cannot investigate security incidents or prove/disprove user actions

#### Information Disclosure (Score: 2)
**Issues Identified:**
- Missing encryption at rest (S-6)
- Missing error handling security policy (S-5)
- Missing data retention policy (S-4)
- Missing secure headers (M-6)

**Strengths:**
- TLS 1.3 for data in transit
- No credit card storage (delegated to Stripe)

#### Denial of Service (Score: 2)
**Issues Identified:**
- Incomplete rate limiting design (S-1)
- Missing API Gateway request size limits (M-4)
- No circuit breaker for supplier APIs (M-8)

**Partial Coverage:**
- Basic rate limiting mentioned (100 req/min per user)

#### Elevation of Privilege (Score: 3)
**Issues Identified:**
- Missing database access control (M-5)
- Missing granular admin privileges (M-9)

**Strengths:**
- RBAC with USER/ADMIN roles
- Spring Security `@PreAuthorize` annotations

---

### 2. Authentication & Authorization Design - Score: 3 (Moderate)

**Overall Assessment:** Basic authentication design is present (JWT, bcrypt), but critical security details are missing.

**Issues Identified:**
- Missing session management security (S-2)
- Missing password reset security (S-8)
- Missing JWT specifications (M-1)
- Missing admin privilege design (M-9)
- Missing MFA for admin accounts (M-9)

**Strengths:**
- JWT authentication with 1-hour expiration
- bcrypt password hashing (cost factor 12)
- Role-based access control (RBAC)
- Spring Security integration

**Gap Analysis:**
- No session timeout beyond token expiration
- No concurrent session limits
- No session invalidation on security events
- No refresh token design
- No password reset token security

---

### 3. Data Protection - Score: 2 (Significant)

**Overall Assessment:** Data in transit is protected (TLS 1.3), but data at rest protection is entirely missing.

**Issues Identified:**
- **CRITICAL:** Missing idempotency for payment operations (C-1)
- Missing encryption at rest (S-6) - database, cache, logs
- Missing data retention and deletion policy (S-4)
- Missing key management design (S-6)
- Missing backup encryption (M-10)

**Strengths:**
- TLS 1.3 for data in transit
- Credit card data not stored (delegated to Stripe)
- Password hashing with bcrypt

**Gap Analysis:**
- No encryption for PostgreSQL database containing PII
- No field-level encryption for sensitive data (phone, passport)
- No Redis encryption for session data
- No CloudWatch log encryption
- No data anonymization design for GDPR compliance

---

### 4. Input Validation Design - Score: 2 (Significant)

**Overall Assessment:** Input validation is not designed. This is a significant security gap enabling injection attacks.

**Issues Identified:**
- **CRITICAL:** Missing CSRF protection (C-2)
- Missing input validation policy (S-3) - no validation rules specified
- Missing error handling security (S-5) - user enumeration risk
- Missing CSP design (M-2)
- Missing XSS protection (M-11)

**Gap Analysis:**
- No validation rules for email, phone, names
- No JSON Schema for JSONB columns
- No SQL injection prevention specification
- No XSS sanitization for user-generated content
- No file upload validation
- No output encoding design

**Note:** While Spring Boot provides validation annotations, the design document does not specify their usage or validation rules.

---

### 5. Infrastructure & Dependency Security - Score: 3 (Moderate)

**Overall Assessment:** Basic infrastructure is secure (AWS managed services, Multi-AZ), but operational security practices are underspecified.

**Issues Identified:**
- **CRITICAL:** Missing audit logging infrastructure (C-3)
- Missing dependency security management (S-7)
- Missing secrets management design (M-7)
- Missing API Gateway security configuration (M-4)
- Missing database access control (M-5)
- Missing supplier API security (M-8)
- Missing backup security (M-10)

**Strengths:**
- AWS managed services (RDS, ElastiCache, ECS Fargate)
- Multi-AZ RDS for availability
- CloudFront CDN
- GitHub Actions CI/CD

**Gap Analysis:**
- No vulnerability scanning for dependencies
- No patch management process
- No secret rotation design
- No network segmentation details
- No infrastructure as code (Terraform/CloudFormation) security

---

## Positive Security Aspects

1. **Strong password hashing:** bcrypt with cost factor 12 is industry best practice
2. **TLS 1.3 enforcement:** Latest TLS version provides strong encryption in transit
3. **Managed services:** AWS RDS, ElastiCache reduce operational security burden
4. **No credit card storage:** Delegating to Stripe (PCI DSS compliant) reduces compliance scope
5. **Multi-AZ RDS:** Provides high availability and reduces data loss risk
6. **API Gateway:** Centralized entry point enables consistent security enforcement
7. **Structured logging:** JSON logs with CloudWatch enable security monitoring (if implemented)
8. **Blue/Green deployment:** Reduces deployment risk and enables quick rollback

---

## Compliance Considerations

### PCI DSS (Payment Card Industry Data Security Standard)
**Issues:**
- Missing audit logging (Requirement 10) - **Critical**
- Missing encryption at rest (Requirement 3) - **Significant**
- Missing data retention policy (Requirement 3.1) - **Significant**

**Strengths:**
- No cardholder data storage (reduces compliance scope to SAQ A)
- TLS 1.3 for data in transit (Requirement 4)

### GDPR (General Data Protection Regulation)
**Issues:**
- Missing data retention and deletion policy (Article 17) - **Significant**
- Missing encryption at rest (Article 32) - **Significant**
- Missing audit logging (Article 30) - **Critical**

**Required Actions:**
- Implement "right to be forgotten" design
- Define lawful basis for data processing
- Implement data portability (Article 20)

### OWASP API Security Top 10 (2023)
**Vulnerable to:**
- API1: Broken Object Level Authorization (missing granular authorization checks)
- API2: Broken Authentication (missing session management security)
- API3: Broken Object Property Level Authorization (no input validation policy)
- API4: Unrestricted Resource Consumption (incomplete rate limiting)
- API5: Broken Function Level Authorization (missing admin privilege design)
- API8: Security Misconfiguration (missing secure headers, CSP, error handling)
- API10: Unsafe Consumption of APIs (missing supplier API validation)

---

## Recommendations Summary

### Immediate Actions (Within 1 Week)
1. **Design idempotency mechanism** for payment and booking operations (C-1)
2. **Design CSRF protection** for all state-changing endpoints (C-2)
3. **Design comprehensive audit logging** policy and implementation (C-3)
4. **Design rate limiting** details for all endpoints, especially auth endpoints (S-1)

### Short-term Actions (Within 1 Month)
5. **Design session management security** (timeouts, revocation, binding) (S-2)
6. **Define input validation policy** and validation rules (S-3)
7. **Design data retention and deletion** policy for GDPR compliance (S-4)
8. **Design error handling security** policy (information disclosure prevention) (S-5)
9. **Enable encryption at rest** for database, cache, and logs (S-6)
10. **Implement dependency security** scanning and update policy (S-7)
11. **Design secure password reset** flow with token security (S-8)

### Medium-term Actions (Within 3 Months)
12. **Enhance JWT security** (claims, key management, refresh tokens) (M-1)
13. **Implement Content Security Policy** for React frontend (M-2)
14. **Design security monitoring** and alerting (M-3)
15. **Configure API Gateway security** (Kong plugins, request limits) (M-4)
16. **Design database access control** (least privilege, IAM auth) (M-5)
17. **Configure secure headers** (HSTS, CSP, X-Frame-Options) (M-6)
18. **Implement secrets management** with AWS Secrets Manager and rotation (M-7)
19. **Design supplier API security** (validation, circuit breaker, isolation) (M-8)
20. **Design granular admin privileges** and MFA requirement (M-9)
21. **Define backup security** and disaster recovery procedures (M-10)
22. **Implement XSS protection** for user-generated content (M-11)

---

## Conclusion

The TravelHub design document provides a solid technical foundation but **requires significant security enhancements before production deployment**. With an overall security score of **2.4/5.0**, the design has **significant security issues** that must be addressed.

**Critical gaps** include missing idempotency guarantees (risk of duplicate charges), missing CSRF protection (risk of unauthorized actions), and missing audit logging (inability to detect or investigate breaches). These three critical issues alone could result in **financial loss, compliance violations, and inability to respond to security incidents**.

**Key recommendation:** Conduct a comprehensive security design review addressing all identified issues before proceeding to implementation. Prioritize the critical and significant issues identified in this report.

The design shows good security awareness in some areas (bcrypt, TLS 1.3, no credit card storage) but lacks the **depth and specificity** required for a production-ready system handling financial transactions and personal data.

---

## Appendix: Evaluation Criteria Detailed Scores

| Category | Subcategory | Score | Critical Issues |
|----------|-------------|-------|-----------------|
| **Threat Modeling** | Spoofing | 2 | Session hijacking, password reset |
| | Tampering | 1 | **Idempotency, CSRF** |
| | Repudiation | 1 | **Audit logging** |
| | Information Disclosure | 2 | Encryption at rest, error handling |
| | Denial of Service | 2 | Rate limiting incomplete |
| | Elevation of Privilege | 3 | Database access, admin privileges |
| **Authentication & Authorization** | Overall | 3 | Session management, password reset |
| **Data Protection** | Overall | 2 | **Idempotency**, encryption at rest, retention |
| **Input Validation** | Overall | 2 | **CSRF**, validation policy, XSS |
| **Infrastructure Security** | Overall | 3 | **Audit logging**, dependencies, secrets |

---

**Report Generated:** 2026-02-10
**Reviewer:** Security Design Reviewer (Architecture-level evaluation)
**Document Reviewed:** TravelHub System Design Document (Round 010)
