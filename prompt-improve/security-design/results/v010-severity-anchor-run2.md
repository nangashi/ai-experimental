# Security Design Review: TravelHub System

## Executive Summary

This security evaluation identifies **9 critical issues**, **8 significant issues**, and **5 moderate issues** in the TravelHub design. The most severe concerns include missing authorization controls on state-changing operations, inadequate data protection for PII, absent idempotency guarantees for financial transactions, and insufficient infrastructure security configurations.

**Overall Risk Assessment**: HIGH - Immediate action required on critical and significant issues before production deployment.

---

## Critical Issues (Score: 1)

### C1. Missing Authorization Checks on DELETE/PUT Operations

**Severity**: Critical (Score: 1)
**Category**: Authentication & Authorization Design

**Issue**: The design specifies DELETE and PUT endpoints (`DELETE /api/v1/bookings/{id}`, `PUT /api/v1/bookings/{id}`, `DELETE /api/v1/users/account`) but does not describe authorization logic to verify that the authenticated user owns the resource being modified or deleted.

**Impact**: Any authenticated user could potentially cancel or modify other users' bookings, or delete other users' accounts by simply knowing or guessing the resource ID. This constitutes a critical privilege escalation vulnerability.

**Example Attack Scenario**:
- User A (authenticated) sends `DELETE /api/v1/bookings/{user-b-booking-id}`
- Without ownership verification, User A cancels User B's booking
- Financial loss and data breach consequences

**Recommendation**:
1. Document explicit authorization policy: "All DELETE/PUT operations MUST verify resource ownership before execution"
2. Add authorization check specification in API design section:
   ```
   For bookings endpoints:
   - Verify JWT user_id matches booking.user_id from database
   - Return 403 Forbidden if ownership check fails
   - ADMIN role can override ownership for support scenarios
   ```
3. Add to Spring Security configuration design:
   ```java
   @PreAuthorize("@bookingSecurityService.isOwner(#bookingId, authentication.principal.userId) or hasRole('ADMIN')")
   ```

**References**: Section 5 (API設計), booking endpoints lack authorization specifications

---

### C2. JWT Token Stored in Redis Without Encryption

**Severity**: Critical (Score: 1)
**Category**: Data Protection

**Issue**: Section 5 states "Redisにトークンのメタデータ（user_id, 発行時刻）を保存" but does not specify whether the JWT itself or sensitive metadata is encrypted at rest in Redis. The design also does not address network encryption between application and Redis.

**Impact**: If Redis is compromised (through memory dump, unauthorized access, or insider threat), attackers can:
- Extract valid JWT tokens and impersonate any user
- Analyze token metadata to understand user behavior patterns
- Compromise all active sessions simultaneously

**Example Attack Scenario**:
- Attacker gains access to Redis instance (misconfigured security group, stolen credentials)
- Exports all keys containing JWT metadata
- Uses extracted JWTs to access user accounts and booking data
- Exfiltrates PII for thousands of users

**Recommendation**:
1. Specify encryption-at-rest for Redis data:
   ```
   - Use ElastiCache encryption-at-rest feature (AWS-managed KMS keys)
   - Encrypt sensitive JWT metadata before storing in Redis using application-level encryption
   - Store only opaque session IDs in Redis, not actual JWTs
   ```
2. Specify encryption-in-transit:
   ```
   - Enable TLS for all Redis connections
   - Configure Spring Data Redis to use rediss:// protocol
   ```
3. Document key rotation policy:
   ```
   - Rotate JWT signing keys quarterly
   - Invalidate all Redis sessions during key rotation
   ```

**References**: Section 5 (認証・認可方式), Section 3 (データフロー)

---

### C3. Missing Idempotency Guarantees for Payment Operations

**Severity**: Critical (Score: 1)
**Category**: Missing Idempotency Guarantees

**Issue**: The design does not specify idempotency mechanisms for `POST /api/v1/payments` and `POST /api/v1/bookings`. If a user retries a failed payment request (due to network timeout), the system may charge the customer twice or create duplicate bookings.

**Impact**: Financial loss for customers, regulatory compliance violations (PCI-DSS, consumer protection laws), reputational damage, and complex reconciliation processes.

**Example Attack Scenario**:
- User submits payment request
- Network timeout occurs before response is received
- Frontend automatically retries the request
- Stripe processes both requests successfully
- User is charged twice for the same booking
- Customer disputes lead to chargebacks and potential legal issues

**Recommendation**:
1. Document idempotency key requirement in API design:
   ```
   POST /api/v1/payments
   Headers:
   - Idempotency-Key: <client-generated-uuid>

   Backend logic:
   - Store idempotency key + response in Redis (TTL: 24 hours)
   - On duplicate key, return cached response without re-processing
   - Stripe SDK already supports idempotency keys - pass through
   ```
2. Add to payment_transactions table:
   ```
   idempotency_key VARCHAR(255) UNIQUE NOT NULL
   ```
3. Specify retry handling policy:
   ```
   - Frontend must generate idempotency key before first attempt
   - Backend returns 409 Conflict if duplicate detected with different payload
   - Backend returns cached response if duplicate detected with same payload
   ```

**References**: Section 5 (決済 endpoints), Section 4 (payment_transactions table)

---

### C4. Missing Backup Encryption Specification

**Severity**: Critical (Score: 1)
**Category**: Data Protection

**Issue**: Section 7 mentions "RDSはMulti-AZ構成で冗長化" but does not specify encryption for RDS automated backups or snapshots. Unencrypted backups containing PII (email, phone_number, booking_details) are vulnerable to unauthorized access.

**Impact**: Backup data breach exposing PII for all users, regulatory penalties (GDPR fines up to 4% of revenue), loss of customer trust.

**Example Attack Scenario**:
- Misconfigured S3 bucket permissions expose RDS snapshots
- Attacker downloads unencrypted snapshot
- Restores database locally and extracts all user PII
- Sells PII on dark web or uses for identity theft

**Recommendation**:
1. Document RDS encryption requirements:
   ```
   - Enable RDS encryption-at-rest using AWS KMS
   - Automated backups and snapshots inherit encryption from source
   - Manual snapshots must be created with encryption enabled
   ```
2. Add backup access control policy:
   ```
   - Restrict snapshot access to production-admin IAM role only
   - Enable AWS CloudTrail logging for all snapshot operations
   - Set up alerts for snapshot copy/restore operations
   ```
3. Document key management:
   ```
   - Use customer-managed KMS key for RDS encryption
   - Rotate KMS key annually
   - Document key deletion policy for decommissioned environments
   ```

**References**: Section 2 (Primary DB: PostgreSQL), Section 7 (可用性・スケーラビリティ)

---

### C5. Missing SQL Injection Prevention Design

**Severity**: Critical (Score: 1)
**Category**: Input Validation Design

**Issue**: The design specifies using "Spring Data JPA 3.2.0" but does not explicitly document input validation policies or parameterized query requirements. The `booking_details JSONB` field is particularly vulnerable if raw user input is stored without sanitization.

**Impact**: SQL injection vulnerabilities could allow attackers to execute arbitrary SQL, leading to data exfiltration, data manipulation, or database server compromise.

**Example Attack Scenario**:
- Attacker submits malicious input in booking_details:
  ```json
  {
    "flightNumber": "AA123'; DROP TABLE users; --"
  }
  ```
- If the application constructs queries using string concatenation, the malicious SQL executes
- User table is deleted, causing complete service outage

**Recommendation**:
1. Document input validation policy:
   ```
   Input Validation Requirements:
   - ALL database queries MUST use parameterized queries (JPA named parameters)
   - Explicitly prohibit string concatenation in JPQL/native queries
   - Validate all user input against allowlists before persistence
   ```
2. Specify JSONB field validation:
   ```
   booking_details validation:
   - Define JSON schema for each booking_type (FLIGHT/HOTEL/CAR)
   - Reject requests that don't match schema
   - Sanitize string fields (max length, allowed characters)
   - Use Jackson ObjectMapper with secure configuration (FAIL_ON_UNKNOWN_PROPERTIES)
   ```
3. Add code review checklist:
   ```
   - No EntityManager.createNativeQuery() with string concatenation
   - All @Query annotations use :parameter syntax
   - All user input validated before JPA entity mapping
   ```

**References**: Section 2 (Spring Data JPA), Section 4 (booking_details JSONB field)

---

### C6. Missing Admin Endpoint Access Control Design

**Severity**: Critical (Score: 1)
**Category**: Authentication & Authorization Design

**Issue**: Section 5 specifies that admin endpoints (`/api/v1/admin/*`) require `ADMIN` role but does not describe how admin privileges are granted, how admin accounts are created, or what additional controls protect these high-privilege endpoints.

**Impact**: If admin account creation is not properly controlled, attackers could escalate privileges by creating their own admin accounts. The absence of MFA requirements for admin accounts increases risk of account compromise.

**Example Attack Scenario**:
- Attacker discovers unprotected user registration endpoint
- Manipulates registration request to set `role: "ADMIN"`
- Gains admin privileges and accesses all user data
- Suspends legitimate admin accounts and takes over system

**Recommendation**:
1. Document admin account lifecycle:
   ```
   Admin Account Management:
   - Admin accounts created ONLY through secure out-of-band process (manual database insert or dedicated CLI tool)
   - No API endpoint shall allow role elevation from USER to ADMIN
   - User registration endpoint MUST hardcode role='USER' (never trust client input)
   ```
2. Add admin authentication requirements:
   ```
   - Admin endpoints require MFA (TOTP via authenticator app)
   - Admin JWT tokens have shorter lifetime (15 minutes vs 1 hour)
   - Admin actions require re-authentication for sensitive operations
   ```
3. Specify admin action audit logging:
   ```
   - Log all admin endpoint access (user ID, IP, action, timestamp)
   - Retention: 1 year minimum for compliance
   - Real-time alerts for: user suspension, bulk data export, admin role changes
   ```

**References**: Section 5 (認可), Section 4 (users table role field)

---

### C7. Missing PII Encryption at Rest

**Severity**: Critical (Score: 1)
**Category**: Data Protection

**Issue**: The users table contains PII (`email`, `phone_number`, `full_name`) and bookings contain `booking_details` with passenger passport numbers. The design does not specify field-level encryption or application-level encryption for this sensitive data.

**Impact**: Database breach or insider threat could expose PII for all users. Passport numbers in particular are high-value targets for identity theft and fraud.

**Example Attack Scenario**:
- SQL injection vulnerability or compromised DB credentials
- Attacker dumps entire users and bookings tables
- PII sold on dark web, enabling identity theft and fraud
- Regulatory penalties under GDPR, CCPA

**Recommendation**:
1. Specify field-level encryption requirements:
   ```
   Encryption-at-Rest Policy:
   - phone_number: AES-256 application-level encryption before persistence
   - booking_details.passportNumber: Encrypted before JSON serialization
   - Use AWS KMS for key management, per-field data encryption keys
   ```
2. Add encrypted columns to schema:
   ```
   ALTER TABLE users:
   - phone_number_encrypted TEXT
   - encryption_key_id VARCHAR(255)

   Application logic:
   - Decrypt only when displaying to owning user or admin
   - Never log decrypted values
   ```
3. Document key rotation procedure:
   ```
   - Re-encrypt all PII fields quarterly
   - Support dual-key period for zero-downtime rotation
   - Audit trail for all key access operations
   ```

**References**: Section 4 (users table, bookings table), Section 7 (セキュリティ要件)

---

### C8. Missing CSRF Protection Design

**Severity**: Critical (Score: 1)
**Category**: Missing CSRF Protection

**Issue**: The design does not mention CSRF protection for state-changing operations (`POST /api/v1/bookings`, `DELETE /api/v1/bookings/{id}`, `POST /api/v1/payments`). Without CSRF tokens, attackers can trick authenticated users into performing unintended actions.

**Impact**: Attackers can create malicious websites that submit requests on behalf of authenticated users, leading to unauthorized bookings, cancellations, or payments.

**Example Attack Scenario**:
- User is logged into TravelHub (JWT in HttpOnly cookie)
- User visits attacker's website
- Attacker's page submits hidden form: `POST /api/v1/bookings` with attacker's booking details
- Browser automatically includes JWT cookie
- Booking is created using victim's account and payment method
- Attacker receives booked travel products

**Recommendation**:
1. Document CSRF protection strategy:
   ```
   CSRF Protection Requirements:
   - Implement Double Submit Cookie pattern or Synchronizer Token pattern
   - Frontend includes CSRF token in X-CSRF-Token header for all POST/PUT/DELETE requests
   - Backend validates token before processing state-changing operations
   ```
2. Add token generation to authentication flow:
   ```
   Login response includes:
   - JWT token (HttpOnly, Secure, SameSite=Strict cookie)
   - CSRF token (readable by JavaScript for header inclusion)
   - Store CSRF token in Redis with TTL matching JWT expiration
   ```
3. Configure Spring Security:
   ```
   - Enable Spring Security CSRF protection for stateful endpoints
   - Configure CookieCsrfTokenRepository
   - Exempt public endpoints (login, register) from CSRF checks
   ```

**References**: Section 5 (API設計), Section 7 (セキュリティ要件)

---

### C9. Missing Rate Limiting on Authentication Endpoints

**Severity**: Critical (Score: 1)
**Category**: Missing Rate Limiting/DoS Protection

**Issue**: Section 7 specifies "APIリクエストはKong API Gatewayでレート制限を設定（ユーザーあたり100req/min）" but does not specify stricter rate limits for authentication endpoints (`POST /api/v1/auth/login`, `POST /api/v1/auth/reset-password`).

**Impact**: Attackers can perform brute-force password attacks or credential stuffing attacks at 100 requests/minute, which is sufficient to test thousands of passwords per hour.

**Example Attack Scenario**:
- Attacker obtains leaked password list from another service
- Scripts credential stuffing attack against `/api/v1/auth/login`
- Tests 100 email/password combinations per minute (6,000/hour)
- Successfully compromises accounts with reused passwords
- Accesses booking history and PII

**Recommendation**:
1. Specify tiered rate limiting policy:
   ```
   Rate Limiting by Endpoint Type:

   Authentication endpoints:
   - /api/v1/auth/login: 5 requests per IP per minute
   - /api/v1/auth/register: 3 requests per IP per hour
   - /api/v1/auth/reset-password: 3 requests per email per hour

   Standard endpoints:
   - 100 requests per authenticated user per minute (existing)

   Admin endpoints:
   - 50 requests per admin user per minute
   ```
2. Add account lockout policy:
   ```
   Brute-Force Protection:
   - Lock account after 5 failed login attempts within 15 minutes
   - Lockout duration: 30 minutes
   - Notify user via email when account is locked
   - Admin can manually unlock accounts
   ```
3. Implement progressive delays:
   ```
   - First failed login: immediate response
   - Second failed login: 1 second delay
   - Third+ failed login: exponential backoff (2s, 4s, 8s...)
   ```

**References**: Section 7 (セキュリティ要件), Section 5 (認証・ユーザー管理 endpoints)

---

## Significant Issues (Score: 2)

### S1. Missing Audit Logging for Financial Operations

**Severity**: Significant (Score: 2)
**Category**: Missing Audit Logging

**Issue**: The design specifies application logging strategy but does not define audit logging requirements for sensitive operations (payments, refunds, admin actions). No retention policy or compliance requirements are documented.

**Impact**: Without comprehensive audit logs, it is impossible to investigate fraud, comply with PCI-DSS requirements (Requirement 10: Track and monitor all access to network resources and cardholder data), or provide evidence in legal disputes.

**Recommendation**:
1. Define audit logging requirements:
   ```
   Audit Log Events (minimum):
   - All payment transactions (amount, user, Stripe ID, status)
   - All refund operations (reason, approver, amount)
   - All admin actions (user suspend, data export, config changes)
   - All authentication events (login, logout, failed attempts)
   - All authorization failures (403 Forbidden responses)
   ```
2. Specify log protection:
   ```
   - Store audit logs in separate write-once database or S3 bucket
   - Enable AWS CloudTrail for infrastructure-level audit
   - Encrypt audit logs at rest
   - Retention: 7 years for financial records (regulatory requirement)
   ```
3. Add audit log monitoring:
   ```
   - Alert on: multiple refunds by same admin, mass user suspension, failed admin login attempts
   - Weekly review of high-value transaction logs
   ```

**References**: Section 6 (ロギング方針), missing audit requirements

---

### S2. Missing Session Timeout and Concurrent Session Policy

**Severity**: Significant (Score: 2)
**Category**: Authentication & Authorization Design

**Issue**: Section 5 specifies "トークンの有効期限は1時間" but does not address idle timeout, absolute session timeout, or concurrent session limits. Users who forget to log out leave sessions vulnerable to session hijacking.

**Impact**: Stolen or compromised JWTs remain valid for the full 1-hour period. On shared computers, subsequent users can access previous users' accounts if they don't explicitly log out.

**Recommendation**:
1. Implement tiered timeout policy:
   ```
   Session Timeout Requirements:
   - Idle timeout: 15 minutes (refresh JWT on activity)
   - Absolute timeout: 8 hours (force re-authentication regardless of activity)
   - Admin sessions: 15-minute absolute timeout
   ```
2. Add concurrent session limits:
   ```
   - Maximum 3 concurrent sessions per user account
   - On 4th login, invalidate oldest session
   - Provide "Active Sessions" page where users can revoke sessions
   ```
3. Track last activity in Redis:
   ```
   Redis key: session:{jwt_id}
   Value: { user_id, last_activity_timestamp, device_info }
   Middleware: Update last_activity_timestamp on each request
   Background job: Invalidate sessions with last_activity > 15min ago
   ```

**References**: Section 5 (認証・認可方式), Redis session management

---

### S3. Missing Input Validation Specifications for API Endpoints

**Severity**: Significant (Score: 2)
**Category**: Input Validation Design

**Issue**: The API design section shows example requests but does not specify validation rules (max length, format, required fields, allowed values) for input fields. The `booking_details JSONB` field is especially concerning as it accepts arbitrary JSON.

**Impact**: Without documented validation rules, developers may implement inconsistent validation, leading to injection vulnerabilities, DoS through oversized inputs, or data integrity issues.

**Recommendation**:
1. Document validation rules for each endpoint:
   ```
   POST /api/v1/auth/register validation:
   - email: RFC 5322 format, max 255 chars, unique
   - password: 12-128 chars, must contain uppercase, lowercase, digit, special char
   - full_name: 1-255 chars, Unicode letters/spaces only
   - phone_number: E.164 format, optional
   ```
2. Define JSONB validation schema:
   ```
   booking_details JSON Schema:
   FLIGHT type:
   - flightNumber: [A-Z]{2}[0-9]{1,4}, required
   - departureDate: ISO 8601 date, future only, required
   - passengers: array, max 9 items, each with:
     - name: 1-100 chars, required
     - passportNumber: 6-20 alphanumeric, optional

   Max JSON size: 64KB
   ```
3. Specify error responses for validation failures:
   ```
   HTTP 400 Bad Request:
   {
     "error": {
       "code": "VALIDATION_FAILED",
       "message": "Invalid input",
       "details": [
         {"field": "email", "error": "Invalid format"}
       ]
     }
   }
   ```

**References**: Section 5 (API設計), all endpoint specifications

---

### S4. Missing Data Retention and Deletion Policy

**Severity**: Significant (Score: 2)
**Category**: Data Protection

**Issue**: The design does not specify data retention periods or deletion procedures for user accounts, booking history, or payment records. GDPR requires right to erasure ("right to be forgotten").

**Impact**: Indefinite data retention increases breach exposure, violates GDPR Article 17, and exposes the organization to regulatory fines (up to €20 million or 4% of global revenue).

**Recommendation**:
1. Document data retention policy:
   ```
   Retention Requirements:
   - Active user accounts: retained while account is active
   - Deleted user accounts: soft delete for 30 days, then hard delete
   - Booking records: 7 years (tax/accounting compliance)
   - Payment transactions: 7 years (PCI-DSS Requirement 3.1)
   - Application logs: 90 days
   - Audit logs: 7 years
   ```
2. Implement soft delete for users table:
   ```
   ALTER TABLE users ADD COLUMN:
   - deleted_at TIMESTAMP NULL
   - deletion_reason VARCHAR(255)

   DELETE /api/v1/users/account:
   - Set deleted_at = now()
   - Anonymize PII (email -> "deleted_user_UUID@deleted.example.com")
   - Retain booking history for compliance (foreign key preserved)
   ```
3. Add scheduled cleanup job:
   ```
   Daily cron job:
   - Hard delete users where deleted_at < (now() - 30 days)
   - Archive bookings older than 7 years to cold storage
   - Delete expired Redis session keys
   ```

**References**: Section 5 (DELETE /api/v1/users/account), GDPR compliance requirements

---

### S5. Missing Secret Management Strategy

**Severity**: Significant (Score: 2)
**Category**: Infrastructure & Dependency Security

**Issue**: The design mentions "Stripe Java SDK" and "JWT署名" but does not specify how secrets (Stripe API keys, JWT signing keys, database passwords) are managed, rotated, or protected.

**Impact**: Hardcoded secrets in code or environment variables are vulnerable to exposure through version control leaks, container image inspection, or memory dumps. Compromised secrets allow attackers to impersonate the application.

**Recommendation**:
1. Specify secret management solution:
   ```
   Secret Management Requirements:
   - Use AWS Secrets Manager for all secrets
   - Secrets: Stripe API key, JWT signing key, DB password, Redis password
   - Application retrieves secrets at startup using IAM role authentication
   - Never store secrets in environment variables or configuration files
   ```
2. Document secret rotation policy:
   ```
   Rotation Schedule:
   - Database passwords: quarterly
   - JWT signing keys: quarterly (dual-key period for zero downtime)
   - Stripe API keys: annually or immediately on suspected compromise
   - Document rotation procedures in runbook
   ```
3. Add secret access audit:
   ```
   - Enable AWS Secrets Manager audit logging via CloudTrail
   - Alert on: secret access from unexpected IP, secret retrieval failure
   - Review access logs monthly
   ```

**References**: Section 2 (Stripe Java SDK), Section 5 (JWT signature)

---

### S6. Missing TLS Configuration Details

**Severity**: Significant (Score: 2)
**Category**: Data Protection

**Issue**: Section 7 states "すべての通信はHTTPS/TLS 1.3以上を使用" but does not specify cipher suites, certificate management, or TLS configuration for internal service-to-service communication (backend to RDS, Redis, Elasticsearch).

**Impact**: Weak cipher suites or misconfigured TLS enable man-in-the-middle attacks. Unencrypted internal communication exposes sensitive data to network-level attackers.

**Recommendation**:
1. Specify TLS configuration standards:
   ```
   TLS Requirements:
   External (CloudFront):
   - Minimum version: TLS 1.3
   - Cipher suites: TLS_AES_128_GCM_SHA256, TLS_AES_256_GCM_SHA384
   - HSTS header: max-age=31536000; includeSubDomains; preload
   - Certificate: Wildcard cert from AWS ACM, auto-renewed

   Internal (service-to-service):
   - RDS: require SSL, verify-full mode
   - Redis: TLS enabled (rediss:// protocol)
   - Elasticsearch: HTTPS with AWS IAM authentication
   ```
2. Document certificate management:
   ```
   - Use AWS Certificate Manager for automatic renewal
   - Set up CloudWatch alarm for cert expiration (30 days before)
   - Test TLS config with SSL Labs or testssl.sh monthly
   ```
3. Add HSTS and security headers:
   ```
   Required HTTP headers:
   - Strict-Transport-Security: max-age=31536000; includeSubDomains
   - X-Content-Type-Options: nosniff
   - X-Frame-Options: DENY
   - Content-Security-Policy: default-src 'self'
   ```

**References**: Section 7 (セキュリティ要件), infrastructure communication paths

---

### S7. Missing Error Information Disclosure Policy

**Severity**: Significant (Score: 2)
**Category**: Missing Error Handling Design

**Issue**: Section 6 defines error response format but does not specify what information should be excluded from error messages to prevent information disclosure (e.g., database connection strings, internal paths, stack traces).

**Impact**: Verbose error messages can reveal system internals to attackers, enabling reconnaissance and targeted attacks.

**Recommendation**:
1. Define error information disclosure policy:
   ```
   Error Response Policy:
   Production environment:
   - Generic error messages only ("Internal server error")
   - No stack traces, SQL queries, or internal paths
   - No database error messages
   - Assign unique error correlation ID for support troubleshooting

   Development environment:
   - Full stack traces allowed
   - Detailed error messages for debugging
   ```
2. Implement environment-specific error handler:
   ```
   GlobalExceptionHandler:
   - Catch all exceptions
   - Log full details (stack trace, request params) server-side
   - Return sanitized response to client:
     {
       "error": {
         "code": "INTERNAL_ERROR",
         "message": "An unexpected error occurred",
         "correlationId": "uuid-for-support-lookup"
       }
     }
   ```
3. Add validation error guidelines:
   ```
   400 Bad Request responses:
   - Safe: "Invalid email format", "Password too short"
   - Unsafe: "User with email x@y.com already exists" (email enumeration)
   - Use generic message: "Registration failed"
   ```

**References**: Section 6 (エラーハンドリング方針)

---

### S8. Missing Dependency Vulnerability Management

**Severity**: Significant (Score: 2)
**Category**: Infrastructure & Dependency Security

**Issue**: Section 2 lists specific library versions but does not describe how dependencies are monitored for vulnerabilities or how updates are applied.

**Impact**: Unpatched vulnerabilities in dependencies (e.g., Log4Shell in Log4j, Spring4Shell) can lead to remote code execution, data breaches, or service compromise.

**Recommendation**:
1. Implement dependency scanning:
   ```
   Dependency Security Requirements:
   - Integrate OWASP Dependency-Check into GitHub Actions CI pipeline
   - Fail build on HIGH or CRITICAL severity vulnerabilities
   - Run Snyk or Dependabot for automated vulnerability alerts
   - Weekly dependency audit report
   ```
2. Define update policy:
   ```
   Dependency Update Schedule:
   - Security patches: within 48 hours of disclosure
   - Minor version updates: monthly
   - Major version updates: quarterly (with regression testing)
   - Document update process in runbook
   ```
3. Add Software Bill of Materials (SBOM):
   ```
   - Generate SBOM using CycloneDX Maven plugin
   - Include SBOM in deployment artifacts
   - Maintain inventory of all production dependencies
   ```

**References**: Section 2 (主要ライブラリ), dependency versions

---

## Moderate Issues (Score: 3)

### M1. Incomplete Rate Limiting Specification

**Severity**: Moderate (Score: 3)
**Category**: Missing Rate Limiting/DoS Protection

**Issue**: Section 7 specifies "ユーザーあたり100req/min" but does not address rate limiting for unauthenticated endpoints, per-IP limits, or burst allowances. The search endpoints (`/api/v1/search/*`) are expensive operations that should have separate limits.

**Impact**: Unauthenticated attackers can abuse public endpoints (registration, password reset) without restriction. Expensive search operations can be spammed to cause resource exhaustion.

**Recommendation**:
1. Define comprehensive rate limiting policy:
   ```
   Rate Limiting by Authentication Status:

   Unauthenticated requests (per IP):
   - Global: 20 requests per minute
   - Registration: 3 per hour
   - Password reset: 3 per hour

   Authenticated requests (per user):
   - Standard endpoints: 100 per minute (existing)
   - Search endpoints: 30 per minute (expensive operations)
   - Booking creation: 10 per minute
   - Payment operations: 5 per minute

   Burst allowance: 2x sustained rate for 10 seconds
   ```
2. Add Kong rate limiting plugin configuration to design
3. Implement distributed rate limiting using Redis to ensure consistency across multiple backend instances

**References**: Section 7 (セキュリティ要件), Kong API Gateway configuration

---

### M2. Missing Logging Sensitive Data Exclusion Policy

**Severity**: Moderate (Score: 3)
**Category**: Missing Audit Logging

**Issue**: Section 6 specifies JSON structured logging but does not define what data must be excluded from logs (passwords, credit card numbers, PII). Accidental logging of sensitive data is a common compliance violation.

**Impact**: PCI-DSS violation (Requirement 3.4: Render PAN unreadable), GDPR violation (Article 5: data minimization), increased breach exposure if logs are compromised.

**Recommendation**:
1. Define sensitive data exclusion policy:
   ```
   Logging Exclusion Policy:
   Never log:
   - Passwords (plain or hashed)
   - Credit card numbers (even partial)
   - Passport numbers
   - JWT tokens (full value)
   - Session IDs

   Allowed to log:
   - Email (in audit logs only, not application logs)
   - User ID (UUID)
   - Truncated identifiers (last 4 digits of card)
   ```
2. Implement log sanitization:
   ```
   Logback configuration:
   - Custom PatternLayout to mask sensitive fields
   - Regex-based filter for common patterns (credit card regex)
   - Review logs with sample data to verify no leaks
   ```
3. Add developer guidelines:
   ```
   Code review checklist:
   - No log.debug() with request body containing passwords
   - No log.info() with full JWT tokens
   - Use log.trace() (disabled in production) for sensitive debugging
   ```

**References**: Section 6 (ロギング方針), PCI-DSS compliance

---

### M3. Missing Output Encoding/Escaping Policy

**Severity**: Moderate (Score: 3)
**Category**: Input Validation Design

**Issue**: The design does not specify how output is encoded when rendering user-generated content (e.g., review text, user names) in the frontend, creating potential for stored XSS attacks.

**Impact**: If a user submits a booking with malicious JavaScript in the `full_name` field, and this is rendered in the frontend without escaping, it will execute in other users' browsers (stored XSS).

**Recommendation**:
1. Document output encoding requirements:
   ```
   Output Encoding Policy:
   Frontend (React):
   - React JSX auto-escapes by default - rely on this for text nodes
   - NEVER use dangerouslySetInnerHTML with user content
   - Sanitize HTML if rich text is required (use DOMPurify library)

   Backend JSON responses:
   - Jackson ObjectMapper escapes by default
   - Verify HTML special chars are escaped (<, >, &, ", ')
   ```
2. Add Content Security Policy:
   ```
   CSP Header:
   Content-Security-Policy:
     default-src 'self';
     script-src 'self' https://js.stripe.com;
     style-src 'self' 'unsafe-inline';
     img-src 'self' https:;
     connect-src 'self' https://api.stripe.com
   ```
3. Review user-generated content fields for XSS risk:
   ```
   High-risk fields:
   - users.full_name (rendered in profile, bookings)
   - booking_details (rendered in confirmation pages)
   - Review/rating text (if implemented)
   ```

**References**: Section 2 (React frontend), Section 4 (user-generated content fields)

---

### M4. Missing Database Connection Security Configuration

**Severity**: Moderate (Score: 3)
**Category**: Infrastructure & Dependency Security

**Issue**: Section 2 mentions "PostgreSQL 15" and "RDS" but does not specify database connection security (SSL enforcement, IAM authentication, connection pooling limits, network isolation).

**Impact**: Unencrypted database connections expose data in transit within the AWS network. Excessive connection pooling can enable connection exhaustion DoS. Weak authentication allows unauthorized database access if credentials are compromised.

**Recommendation**:
1. Specify database connection security:
   ```
   RDS Connection Requirements:
   - SSL mode: require (enforce encrypted connections)
   - Certificate verification: verify-full
   - Use IAM database authentication instead of password (rotate credentials automatically)
   - Network: Deploy RDS in private subnet, no public IP
   - Security group: Allow inbound 5432 only from backend service security group
   ```
2. Configure connection pooling limits:
   ```
   HikariCP Configuration:
   - maximumPoolSize: 20 (per ECS task)
   - connectionTimeout: 30000ms
   - idleTimeout: 600000ms
   - maxLifetime: 1800000ms
   - Prevent connection exhaustion: max 3 ECS tasks * 20 connections = 60 < RDS max_connections (100)
   ```
3. Add database firewall rules:
   ```
   - VPC security group restricts access to backend subnets only
   - Enable RDS Performance Insights for connection monitoring
   - Alert on connection count > 80% of max
   ```

**References**: Section 2 (PostgreSQL, AWS RDS), infrastructure security

---

### M5. Missing API Versioning and Deprecation Policy

**Severity**: Moderate (Score: 3)
**Category**: Authentication & Authorization Design

**Issue**: APIs are versioned (`/api/v1/*`) but the design does not specify how old versions are deprecated, how long they are supported, or how breaking changes are communicated.

**Impact**: Without a clear deprecation policy, security patches may not reach users on old API versions. Forced breaking changes can disrupt clients without warning.

**Recommendation**:
1. Define API versioning policy:
   ```
   API Versioning Requirements:
   - Support minimum 2 concurrent major versions (v1, v2)
   - New versions for breaking changes only
   - Backward-compatible changes added to existing version
   - Security patches applied to all supported versions
   ```
2. Document deprecation timeline:
   ```
   Deprecation Process:
   - Announce deprecation 6 months before removal
   - Add Deprecation header: "Deprecation: true", "Sunset: 2025-06-01"
   - Provide migration guide in documentation
   - Monitor usage of deprecated endpoints
   - Remove deprecated version after sunset date
   ```
3. Add version sunset monitoring:
   ```
   - CloudWatch metric: requests per API version
   - Alert if deprecated version usage > 5% after sunset date
   - Contact high-volume clients directly for migration support
   ```

**References**: Section 5 (API設計), `/api/v1/*` endpoints

---

## Scoring Summary

| Evaluation Criterion | Score | Justification |
|---------------------|-------|---------------|
| **1. Threat Modeling (STRIDE)** | 2 | Missing threat analysis across STRIDE categories. No documented consideration of Spoofing (session hijacking), Tampering (CSRF), Repudiation (insufficient audit logging), Information Disclosure (error messages, logging), Denial of Service (rate limiting gaps), Elevation of Privilege (admin account management). Critical gaps in multiple threat categories. |
| **2. Authentication & Authorization Design** | 1 | Critical missing authorization checks on DELETE/PUT operations (resource ownership verification). Missing admin account lifecycle management. Significant issues: no session timeout policy, no concurrent session limits. Basic authentication (JWT) is present but authorization design is incomplete and exploitable. |
| **3. Data Protection** | 1 | Critical issues: JWT stored in Redis without encryption specification, missing backup encryption, missing PII field-level encryption for passport numbers. Significant issue: incomplete TLS configuration for internal services. Moderate issue: missing data retention/deletion policy. Passwords are hashed (bcrypt) but overall data protection is inadequate. |
| **4. Input Validation Design** | 1 | Critical: No documented SQL injection prevention strategy, missing input validation specifications for JSONB fields. Moderate: Missing output encoding policy for XSS prevention. The design relies on framework defaults without explicit security requirements. |
| **5. Infrastructure & Dependency Security** | 2 | Significant issues: missing secret management strategy, missing dependency vulnerability scanning. Moderate issues: incomplete database connection security, missing network isolation details. Infrastructure is cloud-based (AWS) which provides security baseline, but explicit security configurations are not documented. |

**Overall Assessment**: The design requires significant security enhancements before production deployment. Critical issues must be addressed immediately.

---

## Positive Aspects

1. **Strong authentication foundation**: Use of JWT with 1-hour expiration and Redis-based revocation provides a solid starting point for session management.

2. **Principle of least privilege in role design**: Clear separation between USER and ADMIN roles, with explicit role checking using Spring Security annotations.

3. **Third-party security delegation**: Credit card data is not stored; payment processing is delegated to Stripe (PCI-DSS compliant provider).

4. **Password security**: bcrypt with cost factor 12 is appropriate for password hashing.

5. **Rate limiting awareness**: The design acknowledges the need for rate limiting and specifies a baseline policy (100 req/min per user).

6. **Infrastructure redundancy**: Multi-AZ RDS configuration and ECS auto-scaling demonstrate awareness of availability requirements.

7. **Monitoring foundation**: CloudWatch and Datadog integration provides visibility for security monitoring.

---

## Recommendations Priority

### Immediate (Before any deployment)
1. C1: Add authorization checks for DELETE/PUT operations (resource ownership verification)
2. C3: Implement idempotency guarantees for payment endpoints
3. C5: Document SQL injection prevention policy (parameterized queries)
4. C6: Document admin account lifecycle and access controls
5. C8: Add CSRF protection for state-changing operations

### High Priority (Before production deployment)
6. C2: Encrypt JWT metadata in Redis, enable TLS for Redis connections
7. C4: Enable RDS backup encryption with KMS
8. C7: Implement field-level encryption for PII (passport numbers, phone)
9. C9: Add strict rate limiting for authentication endpoints
10. S1: Implement comprehensive audit logging for financial operations
11. S3: Document input validation specifications for all endpoints
12. S5: Deploy AWS Secrets Manager for secret management

### Medium Priority (Within first month of production)
13. S2: Implement session timeout and concurrent session limits
14. S4: Document and implement data retention policy
15. S6: Specify TLS configuration details for all services
16. S7: Implement error information disclosure policy
17. S8: Set up dependency vulnerability scanning in CI/CD

### Lower Priority (Within first quarter)
18. M1: Expand rate limiting policy for unauthenticated and expensive endpoints
19. M2: Implement logging sensitive data exclusion policy
20. M3: Add Content Security Policy and output encoding guidelines
21. M4: Document database connection security configuration
22. M5: Define API versioning and deprecation policy

---

## Conclusion

The TravelHub design demonstrates awareness of basic security requirements but lacks critical implementation details and explicit security controls. The most severe concerns are authorization gaps (allowing privilege escalation), data protection weaknesses (unencrypted PII and backups), and missing idempotency guarantees for financial operations.

**Recommended action**: Address all 9 critical issues before proceeding with development. Conduct a design review session with the security team to document missing policies and controls identified in this evaluation.
