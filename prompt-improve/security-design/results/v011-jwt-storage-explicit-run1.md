# Security Review: TravelHub System Design

## Executive Summary

This security evaluation identifies **6 critical issues** and **5 significant issues** in the TravelHub design document. The most severe concerns include insecure JWT storage in localStorage (XSS vulnerability), missing CSRF protection, absence of rate limiting/brute-force protection, and lack of data protection specifications for sensitive information. Immediate remediation is required before production deployment.

---

## Evaluation Scores

| Criterion | Score | Status |
|-----------|-------|--------|
| 1. Threat Modeling (STRIDE) | 2 | Significant Issue |
| 2. Authentication & Authorization Design | 1 | Critical Issue |
| 3. Data Protection | 2 | Significant Issue |
| 4. Input Validation Design | 2 | Significant Issue |
| 5. Infrastructure & Dependency Security | 3 | Moderate Issue |

**Overall Security Assessment: CRITICAL - Immediate Action Required**

---

## Critical Issues (Score 1)

### C1. Insecure JWT Storage Mechanism (Authentication & Authorization)

**Finding**: Section 5 explicitly states "フロントエンドはlocalStorageにトークンを保存" (Frontend stores tokens in localStorage).

**Impact**:
- **XSS Vulnerability Exposure**: Any XSS vulnerability in the application allows attackers to steal all user JWTs via JavaScript (`localStorage.getItem()`)
- **Session Hijacking**: Stolen tokens are valid for 24 hours (as per design), providing extended unauthorized access
- **Cross-Domain Attack Surface**: localStorage is accessible from any script on the page, including third-party libraries
- **No Browser Protection**: Unlike httpOnly cookies, localStorage has no built-in XSS protection mechanism

**Severity**: Critical - This is a well-known anti-pattern that has led to numerous high-profile breaches.

**Recommendation**:
1. **IMMEDIATE**: Replace localStorage with httpOnly + Secure + SameSite cookies for JWT storage
2. Implementation:
   ```
   Set-Cookie: jwt=<token>; HttpOnly; Secure; SameSite=Strict; Max-Age=86400; Path=/
   ```
3. Update authentication flow:
   - Backend sets cookie in login response (line 175-181)
   - Frontend no longer handles token storage
   - Browser automatically includes cookie in API requests
4. Add complementary measures:
   - Implement CSRF tokens (see C2)
   - Set Content-Security-Policy header to limit XSS attack surface
   - Consider token rotation mechanism for long sessions

**Reference**: Section 5 "認証・認可方式" (lines 184-189)

---

### C2. Missing CSRF Protection (Threat Modeling)

**Finding**: No CSRF protection mechanism is described despite using cookie-based authentication (recommended in C1) and state-changing operations.

**Impact**:
- **Financial Loss**: Attackers can create unauthorized bookings via crafted forms: `<form action="https://travelhub.com/api/bookings" method="POST">`
- **Data Manipulation**: Unauthorized booking modifications and cancellations
- **Payment Fraud**: Forced payment operations using victim's authenticated session
- **Business Account Compromise**: Corporate booking policies can be bypassed

**Attack Scenario**:
1. User is logged into TravelHub
2. User visits malicious site with hidden form
3. Form auto-submits POST request to `/api/bookings` or `/api/payments`
4. Browser includes authentication cookie automatically
5. Booking created/payment processed without user consent

**Severity**: Critical for a payment/booking platform.

**Recommendation**:
1. Implement Synchronizer Token Pattern:
   - Generate unique CSRF token per session
   - Include token in HTML forms and AJAX headers
   - Validate token on all state-changing operations (POST/PUT/DELETE)
2. For Next.js frontend:
   - Use middleware to inject CSRF token into pages
   - Include token in custom header: `X-CSRF-Token: <token>`
3. Backend validation:
   - Compare token from request header/body with session token
   - Reject requests with missing/mismatched tokens
4. Configure SameSite=Strict cookie attribute (see C1)
5. Exclude GET requests from CSRF protection (idempotent by design)

**Reference**: Sections 5 (API Design) and 6 (Implementation Policy)

---

### C3. Missing Rate Limiting and Brute-Force Protection (Threat Modeling - DoS/Elevation of Privilege)

**Finding**: No rate limiting, brute-force protection, or API throttling mechanisms are described.

**Impact**:
- **Credential Stuffing**: Unlimited login attempts enable automated password guessing (line 139: `POST /api/auth/login`)
- **DoS Attack**: 1000req/sec target (line 218) is vulnerable to request flooding
- **Economic DoS**: Search API calls to supplier APIs (lines 82-83) without rate limiting can incur unbounded costs
- **Account Enumeration**: Unlimited password reset requests reveal valid email addresses
- **API Abuse**: No quotas on expensive operations (search, booking creation)

**Attack Scenarios**:
- Attacker tries 10,000 passwords/second against user accounts
- Automated bots flood search API, driving up supplier API costs
- Competitor scrapes pricing data via unrestricted search queries

**Severity**: Critical - combination of authentication bypass risk and financial impact.

**Recommendation**:
1. **Authentication Endpoints**:
   - Login: 5 attempts per IP per 15 minutes
   - Password reset: 3 attempts per email per hour
   - Lockout after repeated failures: account locked for 1 hour
2. **API Gateway Level** (AWS ALB):
   - Global rate limit: 100 req/sec per IP address
   - Burst allowance: 200 requests
3. **Application Level** (Spring Boot):
   - User-based limits: 1000 req/hour per authenticated user
   - Search API: 10 req/minute per user
   - Booking API: 5 bookings per hour per user
4. **Implementation**:
   - Use Redis for distributed rate limit counters
   - Return HTTP 429 (Too Many Requests) with Retry-After header
   - Log rate limit violations for security monitoring
5. **Progressive Delays**:
   - Failed login: exponential backoff (1s → 2s → 4s → 8s)

**Reference**: Sections 5 (API Design) and 7 (Non-functional Requirements)

---

### C4. Missing Idempotency Guarantees for Critical Operations (Threat Modeling - Tampering)

**Finding**: No idempotency mechanism is described for state-changing operations (booking creation, payment processing).

**Impact**:
- **Duplicate Bookings**: Network retries or client errors cause multiple bookings for same reservation
- **Double Charging**: Payment API (line 156: `POST /api/payments`) can charge customers multiple times
- **Race Conditions**: Concurrent requests to booking modification endpoint (line 151) lead to inconsistent state
- **Data Integrity**: booking_reference uniqueness constraint (line 108) can be violated
- **Financial Loss**: Refund operations (line 157) without idempotency enable duplicate refunds

**Attack Scenario**:
1. User submits booking request
2. Response is delayed due to network latency
3. User clicks "Submit" again (or automated retry)
4. Two bookings created with different IDs but same details
5. Two payments processed for identical reservation

**Severity**: Critical for a booking/payment platform.

**Recommendation**:
1. **Implement Idempotency Keys**:
   - Require `Idempotency-Key` header for POST/PUT/DELETE requests
   - Client generates UUID per operation
   - Backend stores key + response in Redis with 24-hour TTL
   - Return cached response if duplicate key detected
2. **API Contract**:
   ```
   POST /api/bookings
   Headers:
     Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
   ```
3. **Database-Level Protection**:
   - Add unique constraint on (user_id, booking_details_hash, created_at)
   - Use database transactions with serializable isolation
4. **Payment-Specific**:
   - Stripe SDK natively supports idempotency keys - pass them through
   - Store payment intent ID before processing
5. **Implementation**:
   ```java
   // Pseudo-code
   String idempotencyKey = request.getHeader("Idempotency-Key");
   Response cachedResponse = redis.get("idempotency:" + idempotencyKey);
   if (cachedResponse != null) return cachedResponse;

   Response response = processBooking(request);
   redis.setex("idempotency:" + idempotencyKey, 86400, response);
   return response;
   ```

**Reference**: Section 5 (API Design, lines 149-157)

---

### C5. Missing Input Validation Policy and Injection Prevention (Input Validation Design)

**Finding**: No comprehensive input validation policy is described. Only one validation rule is mentioned: `CHECK (rating >= 1 AND rating <= 5)` (line 131).

**Impact**:
- **SQL Injection**: JSONB field `booking_details` (line 111) is vulnerable if constructed from user input without parameterization
- **NoSQL Injection**: Elasticsearch queries (lines 70, 84) lack sanitization specifications
- - **XSS**: Review comments (line 132: `comment TEXT`) can inject malicious scripts if not escaped on output
- **XML/JSON Injection**: Supplier API requests (line 82) lack input sanitization
- **Path Traversal**: File upload features (if added) have no restrictions
- **Command Injection**: External API calls without input sanitization

**Attack Scenarios**:
- User enters `'; DROP TABLE bookings; --` in search query
- Review comment contains `<script>steal_jwt()</script>` that executes on other users' browsers
- Malicious JSON in booking_details: `{"flight": {"eval": "malicious_code"}}`

**Severity**: Critical - affects entire attack surface.

**Recommendation**:
1. **Define Comprehensive Validation Policy**:
   - **Email**: RFC 5322 compliance, max 255 chars
   - **Password**: Min 12 chars, complexity requirements (uppercase, lowercase, digit, special)
   - **Phone**: E.164 format validation
   - **Amount**: Decimal(10,2), positive values only
   - **Dates**: ISO 8601 format, range validation (no past bookings)
   - **Strings**: Max length, character whitelist, trim whitespace
2. **Injection Prevention**:
   - SQL: Use parameterized queries exclusively (Spring Data JPA/JDBC)
   - NoSQL: Sanitize Elasticsearch queries via Query DSL (not raw strings)
   - XSS: Apply output encoding (React escapes by default, verify review display)
   - JSON: Validate against JSON schema before parsing booking_details
3. **Implementation**:
   - Use Hibernate Validator annotations: `@Email`, `@Size`, `@Pattern`, `@NotNull`
   - Custom validators for business rules (date ranges, amount limits)
   - Validation groups for different operation contexts
4. **Example**:
   ```java
   @NotNull
   @Size(max=1000)
   @Pattern(regexp="^[a-zA-Z0-9\\s.,!?-]+$") // whitelist
   private String comment;
   ```
5. **Supplier API Input**:
   - Whitelist allowed characters in search queries
   - Encode special characters in API requests
   - Validate response data before storing in database

**Reference**: Sections 4 (Data Model) and 6 (Implementation Policy)

---

### C6. Missing Secret Management Strategy (Infrastructure & Dependency Security)

**Finding**: No secret management, rotation, or access control strategy is described.

**Impact**:
- **Credential Exposure**: Database passwords, JWT signing keys, Stripe API keys, supplier API credentials are at risk if stored in code/config
- **Lateral Movement**: Compromised secrets enable attacker access to all connected systems
- **Compliance Violations**: PCI-DSS requires secure key storage for payment systems
- **Privilege Escalation**: Database credentials in environment variables grant full database access
- **Long-Term Compromise**: No rotation policy means breached secrets remain valid indefinitely

**Attack Scenarios**:
- JWT signing key leaked in Git repository enables token forgery
- Stripe secret key exposed in logs allows unauthorized payment processing
- Database password in Docker image enables data exfiltration
- Supplier API keys in code enable competitor API abuse

**Severity**: Critical for a payment/booking platform handling sensitive data.

**Recommendation**:
1. **Use AWS Secrets Manager**:
   - Store all secrets: DB passwords, JWT keys, Stripe keys, supplier API credentials
   - Grant least-privilege IAM roles to Kubernetes pods
   - Retrieve secrets at runtime (never hardcode)
2. **Secret Rotation**:
   - Database passwords: 90-day rotation
   - JWT signing keys: 30-day rotation with graceful key rollover
   - API keys: 180-day rotation or on-demand if compromised
3. **Access Control**:
   - IAM policy: only Production pods access production secrets
   - Audit log all secret retrievals (AWS CloudTrail)
   - Use separate secrets for staging and production
4. **Implementation**:
   ```java
   // Spring Boot integration
   @Value("${aws.secretsmanager.stripe-api-key}")
   private String stripeApiKey;
   ```
5. **Key Management for JWT**:
   - Use asymmetric keys (RS256) instead of symmetric (HS256)
   - Private key for signing (backend only)
   - Public key for verification (can be distributed)
   - Store private key in AWS Secrets Manager
6. **Environment Variable Restrictions**:
   - Never store secrets in environment variables
   - Use Kubernetes Secrets with encryption at rest
7. **Developer Access**:
   - Developers use separate development keys (lower privileges)
   - Production keys accessible only to CI/CD pipeline and production pods

**Reference**: Section 2 (Technology Stack) and 7 (Security Requirements)

---

## Significant Issues (Score 2)

### S1. Missing Data Protection Specifications (Data Protection)

**Finding**: Section 7 states "個人情報の暗号化保存" (encrypt personal information) but lacks critical specifications.

**Missing Elements**:
- **No encryption algorithm specified**: Which encryption standard (AES-256-GCM, AES-256-CBC)?
- **No key management**: Where are encryption keys stored? Rotation schedule?
- **Unclear scope**: Which fields are encrypted? password_hash (line 95), email (line 94), phone (line 97), booking_details (line 111)?
- **No encryption at rest policy**: Database-level vs application-level encryption?
- **No data retention policy**: How long is personal data retained? GDPR right to deletion?
- **No data masking in logs**: Are emails/phone numbers masked in logs (line 201)?

**Impact**:
- **Compliance Violations**: GDPR Article 32 requires specific encryption measures
- **Breach Amplification**: Database compromise exposes plaintext personal data
- **Regulatory Fines**: GDPR fines up to €20M or 4% of revenue for inadequate protection
- **Audit Failures**: PCI-DSS Level 1 requires documented encryption standards

**Severity**: Significant - affects compliance and data breach impact.

**Recommendation**:
1. **Define Encryption Standards**:
   - **Algorithm**: AES-256-GCM for data at rest
   - **Scope**: Encrypt email, phone, full_name, booking_details, payment_method
   - **password_hash**: Already hashed (bcrypt/argon2), no additional encryption needed
2. **Encryption at Rest**:
   - PostgreSQL: Enable Transparent Data Encryption (TDE) or AWS RDS encryption
   - Redis: Enable encryption in transit (TLS) and at rest
   - Elasticsearch: Enable node-to-node encryption and encryption at rest
3. **Key Management**:
   - Use AWS KMS for encryption keys
   - Automatic 365-day key rotation
   - Separate keys per environment (dev/staging/prod)
4. **Data Retention Policy**:
   - Active user data: retained indefinitely
   - Deleted accounts: personal data purged after 30 days (keep booking records with anonymization)
   - Implement scheduled job for data deletion
5. **Log Masking**:
   - Email: show only domain (`u***@example.com`)
   - Phone: mask middle digits (`+81-***-**-1234`)
   - Payment details: never log card numbers (log only last 4 digits)
6. **Implementation**:
   ```java
   // Application-level encryption for sensitive fields
   @Convert(converter = EncryptedStringConverter.class)
   private String email;
   ```

**Reference**: Section 7 (Security Requirements, line 224)

---

### S2. Missing Audit Logging Specifications (Threat Modeling - Repudiation)

**Finding**: Section 6 describes logging for API requests/responses (line 199) but lacks audit logging for security-critical events.

**Missing Elements**:
- **No authentication events**: Login attempts, logout, password changes
- **No authorization failures**: Unauthorized access attempts to bookings/payments
- **No data access logging**: Who accessed which user's booking data?
- **No admin action logs**: Role changes, permission modifications
- **No payment audit trail**: Payment creation, refund, failure events
- **No log retention policy**: How long are logs kept?
- **No log integrity protection**: Can logs be tampered with?
- **No PII masking in logs**: Sensitive data exposure risk

**Impact**:
- **Incident Response Failure**: Cannot identify attack patterns or compromised accounts
- **Non-repudiation Loss**: No proof of user actions in disputes
- **Compliance Violations**: PCI-DSS 10.x requires comprehensive audit logging
- **Forensics Impairment**: Insufficient data for breach investigation
- **Insider Threats**: No detection of admin abuse or data exfiltration

**Severity**: Significant - critical for security monitoring and compliance.

**Recommendation**:
1. **Define Audit Log Events**:
   - **Authentication**: Login (success/failure), logout, password reset, token refresh
   - **Authorization**: Access denied (resource ID, requested action)
   - **Data Access**: Booking view, payment details access, user profile access
   - **Data Modification**: Booking creation/modification/cancellation, payment processing
   - **Admin Actions**: Role assignment, permission changes, user account modifications
   - **Security Events**: Rate limit violations, input validation failures, CSRF token mismatches
2. **Log Format** (JSON structured logging):
   ```json
   {
     "timestamp": "2026-02-10T12:34:56Z",
     "event_type": "authentication.login.success",
     "user_id": "123e4567-e89b-12d3-a456-426614174000",
     "ip_address": "203.0.113.45",
     "user_agent": "Mozilla/5.0...",
     "request_id": "req-abc-123",
     "resource_id": null,
     "result": "success"
   }
   ```
3. **PII Masking**:
   - Never log passwords or tokens
   - Mask email/phone as per S1 recommendation
   - Hash IP addresses for GDPR compliance (where applicable)
   - Exclude sensitive booking_details fields
4. **Log Retention**:
   - Security logs: 1 year minimum (PCI-DSS requirement)
   - Application logs: 90 days
   - Archive older logs to S3 Glacier
5. **Log Protection**:
   - Send logs to centralized system (Datadog) immediately
   - Use append-only log storage (prevent tampering)
   - Restrict log access to security team only
6. **Monitoring & Alerting**:
   - Alert on multiple failed login attempts
   - Alert on admin permission changes
   - Alert on unusual data access patterns (e.g., 100 bookings viewed in 1 minute)

**Reference**: Section 6 (Logging Policy, lines 198-201)

---

### S3. Missing Error Handling Security Design (Implementation Policy)

**Finding**: Section 6 describes error handling (lines 194-196) but lacks security-specific design.

**Missing Elements**:
- **No error message sanitization**: Do error messages expose sensitive data?
- **No information disclosure policy**: What internal details should never be exposed?
- **No error rate monitoring**: Detection of automated attacks via error patterns
- **No failover security**: What happens to authentication during outages?

**Impact**:
- **Information Disclosure**: Stack traces reveal file paths, library versions, SQL queries
- **Account Enumeration**: "User not found" vs "Invalid password" reveals valid emails
- **System Fingerprinting**: Error messages expose technology stack for targeted attacks
- **Availability Risk**: No defined behavior for authentication failures during outages

**Attack Scenarios**:
- Attacker sends malformed JSON to trigger stack trace exposure
- Login endpoint distinguishes "user not found" from "wrong password" to enumerate accounts
- SQL errors reveal table structure and column names
- 500 errors expose Spring Boot version in response headers

**Severity**: Significant - enables reconnaissance and targeted attacks.

**Recommendation**:
1. **Generic Error Messages for External Users**:
   - Authentication: Always return "Invalid email or password" (never distinguish)
   - Authorization: Return "Access denied" without specifying why
   - Validation: Return field-level errors but no internal logic
   - System errors: Return "Internal server error. Error ID: abc-123" only
2. **Internal Error Logging**:
   - Log full exception details with stack trace
   - Include error ID for correlation
   - Mask sensitive data in logs (see S2)
3. **Error Response Format**:
   ```json
   // Public response (400/401/403/404)
   {
     "error": "INVALID_CREDENTIALS",
     "message": "Invalid email or password",
     "error_id": "err-550e8400"
   }

   // Public response (500)
   {
     "error": "INTERNAL_ERROR",
     "message": "An error occurred. Please contact support with error ID: err-550e8400",
     "error_id": "err-550e8400"
   }

   // Internal log (for err-550e8400)
   {
     "error_id": "err-550e8400",
     "exception": "java.sql.SQLException: Connection timeout...",
     "stack_trace": "...",
     "user_id": "123e4567",
     "request_path": "/api/bookings"
   }
   ```
4. **Remove Sensitive Headers**:
   - Disable `X-Powered-By`, `Server` headers
   - Configure Spring Boot to hide version information
5. **Failover Policy**:
   - Authentication: Cache recent tokens in Redis with 5-minute TTL for database outages
   - Authorization: Deny access if unable to verify permissions (fail-secure)
   - Payment: Queue payment requests for retry rather than failing immediately
6. **Error Rate Monitoring**:
   - Alert on spike in 401 errors (potential brute-force)
   - Alert on spike in 400 errors (potential fuzzing/scanning)

**Reference**: Section 6 (Error Handling Policy, lines 194-196)

---

### S4. Incomplete Infrastructure Security Assessment (Infrastructure & Dependency Security)

**Finding**: Infrastructure components are listed (lines 22-50) but security configurations are not specified.

**Infrastructure Security Analysis**:

| Component | Configuration | Security Measure | Status | Risk Level | Recommendation |
|-----------|---------------|------------------|--------|------------|----------------|
| **PostgreSQL 15** | Access control, encryption, backup | Review specifications | **Missing** | **Critical** | 1. Enable RDS encryption at rest<br>2. Use IAM database authentication<br>3. Network isolation in private subnet<br>4. Automated daily backups with 30-day retention<br>5. Enable query logging for audit |
| **Redis 7.0** | Network isolation, authentication | Review specifications | **Missing** | **High** | 1. Enable AUTH with strong password<br>2. Disable dangerous commands (FLUSHALL, CONFIG)<br>3. Enable TLS for all connections<br>4. Place in private subnet (no public access)<br>5. Enable AOF persistence for session data |
| **Elasticsearch 8.7** | Access control, encryption | Review specifications | **Missing** | **High** | 1. Enable authentication (built-in or SSO)<br>2. Role-based access control per index<br>3. Enable HTTPS for all connections<br>4. Network isolation in private subnet<br>5. Disable dynamic scripting (XSS risk) |
| **AWS ALB** | HTTPS, rate limiting, CORS | Review specifications | **Partial** | **High** | 1. Enforce HTTPS redirect (no HTTP)<br>2. Configure rate limiting rules (see C3)<br>3. Define CORS policy (whitelist origins)<br>4. Enable access logs to S3<br>5. Configure WAF rules (SQL injection, XSS) |
| **Secrets Management** | Rotation, access control, storage | Review specifications | **Missing** | **Critical** | See C6 recommendation |
| **Dependencies** | Version management, vulnerability scanning | Review specifications | **Missing** | **High** | 1. Use Dependabot/Snyk for automated scanning<br>2. Pin dependency versions (no wildcard)<br>3. Verify Stripe SDK integrity (checksum)<br>4. Audit jose/jjwt for known CVEs<br>5. Quarterly dependency updates |

**Additional Missing Infrastructure Security**:
- **Container Security**: No image scanning, no runtime security policy
- **Network Security**: No VPC configuration, no security group definitions
- **Kubernetes Security**: No pod security policies, no network policies
- **Monitoring & Incident Response**: No security alerting rules in Datadog

**Severity**: Significant - affects entire infrastructure attack surface.

**Recommendation**:
1. **Define Security Baseline for Each Component** (see table above)
2. **Container Security**:
   - Scan Docker images for vulnerabilities (Trivy, Snyk)
   - Use minimal base images (distroless or alpine)
   - Run containers as non-root user
   - Apply pod security standards (restricted profile)
3. **Network Security**:
   - Define VPC with public/private subnets
   - Security groups: allow only necessary ports
   - Backend services in private subnet (no internet access)
   - Database in isolated subnet (backend access only)
4. **Kubernetes Security**:
   - Enable RBAC with least-privilege service accounts
   - Apply network policies (isolate services)
   - Enable pod security admission
   - Use secrets for sensitive config (not ConfigMaps)
5. **Security Monitoring**:
   - Configure Datadog security monitoring
   - Alert on authentication failures, privilege escalation, data access anomalies
   - Integrate with AWS GuardDuty for threat detection

**Reference**: Sections 2 (Technology Stack) and 7 (Infrastructure)

---

### S5. Missing Password Security Policy (Authentication & Authorization)

**Finding**: The `password_hash` field (line 95) implies hashing but lacks specification.

**Missing Elements**:
- **No hashing algorithm specified**: bcrypt, scrypt, argon2?
- **No salt strategy**: Unique salt per password?
- **No password complexity requirements**: Minimum length, character requirements?
- **No password reset security**: Token expiration, one-time use?
- **No password history**: Prevent reuse of old passwords?
- **No account lockout policy**: See C3 for brute-force protection

**Impact**:
- **Weak Hash Algorithm**: MD5/SHA-1 are crackable with modern GPUs
- **Rainbow Table Attacks**: Unsalted hashes are vulnerable to precomputed attacks
- **Weak Passwords**: No complexity requirement enables easy guessing
- **Password Reset Abuse**: Long-lived tokens can be leaked and reused

**Severity**: Significant - critical authentication control.

**Recommendation**:
1. **Password Hashing**:
   - Use **argon2id** (best modern choice) or **bcrypt** (widely supported)
   - Minimum cost factor: bcrypt cost=12, argon2 time=2 memory=19456 parallelism=1
   - Unique salt per password (handled automatically by bcrypt/argon2)
2. **Password Complexity Requirements**:
   - Minimum 12 characters
   - At least one uppercase, lowercase, digit, special character
   - No common passwords (check against known breach databases)
   - No personal information (name, email) in password
3. **Password Reset Security**:
   - Generate cryptographically random token (32+ bytes)
   - Token valid for 1 hour only
   - Token is single-use (invalidate after use)
   - Send token via email (not SMS - SIM swap risk)
   - Require email verification before password change
   - Invalidate all existing sessions after password change
4. **Password History**:
   - Store last 5 password hashes
   - Prevent reuse of recent passwords
5. **Implementation** (Java/Spring):
   ```java
   // Use Spring Security's BCryptPasswordEncoder
   @Bean
   public PasswordEncoder passwordEncoder() {
       return new BCryptPasswordEncoder(12);
   }
   ```
6. **MFA Consideration**:
   - Recommend implementing MFA for high-value accounts (corporate bookings)
   - TOTP (authenticator app) or WebAuthn (FIDO2)

**Reference**: Section 4 (Data Model, line 95) and Section 5 (Authentication, line 141)

---

## Moderate Issues (Score 3)

### M1. Insufficient Session Management Design (Authentication & Authorization)

**Finding**: JWT tokens are valid for 24 hours (line 186) with no refresh mechanism described.

**Issues**:
- **Long Token Lifetime**: 24-hour validity window increases risk if token is stolen
- **No Token Revocation**: Cannot invalidate tokens if user logs out or account is compromised
- **No Refresh Token**: Forces user to re-login every 24 hours or accept long-lived access tokens
- **No Device Management**: Users cannot view/revoke active sessions

**Impact** (Moderate because httpOnly cookies mitigate XSS risk):
- Stolen tokens remain valid until expiration
- Compromised accounts cannot be secured until token expires
- Poor user experience (re-login required daily)

**Recommendation**:
1. **Implement Refresh Token Pattern**:
   - Access token: 15-minute lifetime (short-lived)
   - Refresh token: 7-day lifetime (long-lived, stored securely)
   - Automatic token refresh before access token expires
2. **Token Revocation**:
   - Store active refresh tokens in Redis with user_id as key
   - On logout: delete refresh token from Redis
   - On password change: delete all refresh tokens for user
   - On suspicious activity: admin can revoke all tokens
3. **Session Management UI**:
   - Show active sessions (device, location, last access time)
   - Allow user to revoke individual sessions
4. **Implementation**:
   ```
   POST /api/auth/refresh
   Request: { refresh_token: "<token>" }
   Response: { access_token: "<new_token>", expires_in: 900 }
   ```

**Reference**: Section 5 (Authentication, line 186)

---

### M2. Missing CORS Policy Definition (Infrastructure Security)

**Finding**: No CORS (Cross-Origin Resource Sharing) policy is described for the API Gateway (line 58).

**Issues**:
- **Unclear Origin Restrictions**: Which domains can call the API?
- **Credential Sharing Risk**: Will cookies be sent cross-origin?
- **Wildcard Risk**: Using `Access-Control-Allow-Origin: *` with credentials is forbidden

**Impact** (Moderate because httpOnly cookies limit exposure):
- Potential for unauthorized cross-origin API access
- Risk of credential leakage if misconfigured

**Recommendation**:
1. **Define CORS Policy**:
   - **Allowed Origins**: Whitelist only official domains (`https://travelhub.com`, `https://app.travelhub.com`)
   - **Allowed Methods**: `GET, POST, PUT, DELETE, OPTIONS`
   - **Allowed Headers**: `Content-Type, Authorization, X-CSRF-Token`
   - **Credentials**: `Access-Control-Allow-Credentials: true`
   - **Max Age**: 86400 (cache preflight for 24 hours)
2. **Implementation** (Spring Boot):
   ```java
   @Configuration
   public class CorsConfig implements WebMvcConfigurer {
       @Override
       public void addCorsMappings(CorsRegistry registry) {
           registry.addMapping("/api/**")
               .allowedOrigins("https://travelhub.com")
               .allowedMethods("GET", "POST", "PUT", "DELETE")
               .allowCredentials(true);
       }
   }
   ```
3. **No Wildcard**: Never use `*` for origins when credentials are involved
4. **Dynamic Origin Validation**: If multiple subdomains, validate against regex pattern

**Reference**: Section 3 (Architecture, line 58)

---

### M3. Insufficient Logging of Sensitive Operations (Repudiation)

**Finding**: Section 6 specifies logging "すべてのAPIリクエスト/レスポンスをログ出力" (all API requests/responses) but lacks detail on what data is logged.

**Issues**:
- **PII in Logs**: Are request bodies logged? This could include passwords, card numbers, etc.
- **Sensitive Response Data**: Are tokens logged in response bodies?
- **Performance Impact**: Logging every request body for 1000req/sec is expensive

**Impact** (Moderate because primarily a compliance/privacy risk):
- GDPR violations if PII is logged without justification
- Log files become attack target (contain sensitive data)
- Increased storage costs and performance overhead

**Recommendation**:
1. **Selective Request/Response Logging**:
   - **Always Log**: HTTP method, path, status code, duration, request ID, user ID, IP address
   - **Never Log**: Request bodies for `/api/auth/*`, `/api/payments/*`
   - **Conditionally Log**: Request bodies for non-sensitive endpoints (search, reviews) with size limit
2. **Field-Level Masking**:
   - Automatically mask fields named `password`, `token`, `card_number`, `cvv`
   - Use custom annotation: `@SensitiveData` for fields that should never be logged
3. **Structured Logging**:
   - Use JSON format for machine parsing
   - Include fields: timestamp, request_id, user_id, method, path, status, duration_ms
4. **Sampling for High-Volume Endpoints**:
   - Log 100% of errors (4xx, 5xx)
   - Log 10% of successful search requests (sample for performance analysis)
   - Log 100% of authentication, payment, booking events
5. **Log Rotation**:
   - Rotate logs daily
   - Compress and archive to S3
   - Auto-delete logs older than retention policy (see S2)

**Reference**: Section 6 (Logging Policy, line 199)

---

### M4. Missing Content Security Policy (Threat Modeling - XSS)

**Finding**: No Content Security Policy (CSP) is described for the Next.js frontend.

**Issues**:
- **XSS Mitigation**: CSP is a critical defense-in-depth measure against XSS attacks
- **Inline Script Risk**: No restriction on script sources enables various XSS vectors
- **External Resource Loading**: No control over which external resources can be loaded

**Impact** (Moderate because React escapes by default):
- Reduced XSS protection
- Potential data exfiltration via injected scripts

**Recommendation**:
1. **Define CSP Header**:
   ```
   Content-Security-Policy:
     default-src 'self';
     script-src 'self' 'unsafe-inline' https://js.stripe.com;
     style-src 'self' 'unsafe-inline';
     img-src 'self' data: https:;
     connect-src 'self' https://api.travelhub.com;
     frame-src https://js.stripe.com;
     object-src 'none';
     base-uri 'self';
     form-action 'self';
   ```
2. **Next.js Implementation** (next.config.js):
   ```javascript
   module.exports = {
     async headers() {
       return [
         {
           source: '/:path*',
           headers: [
             { key: 'Content-Security-Policy', value: "default-src 'self'; ..." }
           ]
         }
       ];
     }
   };
   ```
3. **Gradual Enforcement**:
   - Start with `Content-Security-Policy-Report-Only` to monitor violations
   - Fix reported violations
   - Switch to enforcement mode
4. **Remove Unsafe Inline** (Long-term):
   - Eliminate `'unsafe-inline'` for scripts
   - Use nonces or hashes for inline scripts
   - Next.js supports nonce-based CSP

**Reference**: Sections 2 (Frontend) and 3 (Architecture)

---

### M5. Unclear Third-Party API Security (Infrastructure Security)

**Finding**: Section 3 mentions "複数サプライヤーAPIを並列呼び出し" (parallel calls to supplier APIs) but lacks security design.

**Issues**:
- **Credential Management**: How are supplier API keys stored? (Partially addressed in C6)
- **API Response Validation**: Are supplier responses validated/sanitized?
- **Rate Limiting**: Could malicious input trigger excessive supplier API calls? (Partially addressed in C3)
- **Failover**: What if supplier API is compromised or returns malicious data?
- **PII Leakage**: What user data is sent to suppliers?

**Impact** (Moderate because primarily affects data integrity):
- Malicious supplier response could inject malicious data
- Excessive API calls could incur high costs
- User PII may be leaked to suppliers without consent

**Recommendation**:
1. **API Response Validation**:
   - Define JSON schema for each supplier API
   - Validate all responses against schema before processing
   - Sanitize HTML/script tags in response data (e.g., hotel descriptions)
   - Set maximum response size (prevent memory exhaustion)
2. **PII Minimization**:
   - Only send necessary data to suppliers (dates, locations, counts)
   - Never send user email, phone, or payment details to search APIs
   - Document what data is shared in privacy policy
3. **Supplier Authentication**:
   - Store API keys in AWS Secrets Manager (see C6)
   - Use separate keys per environment
   - Rotate keys on schedule
4. **Circuit Breaker Pattern**:
   - If supplier API fails repeatedly, temporarily stop calling it
   - Return cached results or partial results
   - Alert operations team
5. **Timeout & Retry**:
   - Set aggressive timeout (2-3 seconds for search)
   - Maximum 2 retries with exponential backoff
   - Prevent cascade failures

**Reference**: Section 3 (Architecture, lines 82-84)

---

## Positive Security Aspects

1. **HTTPS Enforcement**: All communication is HTTPS-encrypted (line 222)
2. **Database Isolation**: Database connections within dedicated VPC (line 223)
3. **Password Hashing**: Passwords are hashed (implied by `password_hash` field)
4. **Structured Logging**: Request ID, user ID, timestamp in logs (line 201)
5. **Deployment Safety**: Blue-Green deployment with automated testing (lines 210-212)
6. **Modern Tech Stack**: Up-to-date frameworks with active security support
7. **Error Handling**: Centralized exception handling (line 194)
8. **Unique Booking References**: Prevents collision attacks (line 108)

---

## Summary of Recommendations by Priority

### Immediate Action Required (Critical Issues)
1. **C1**: Replace localStorage with httpOnly + Secure cookies for JWT storage
2. **C2**: Implement CSRF protection (Synchronizer Token Pattern)
3. **C3**: Add rate limiting and brute-force protection
4. **C4**: Implement idempotency keys for bookings and payments
5. **C5**: Define comprehensive input validation policy
6. **C6**: Implement secret management with AWS Secrets Manager

### High Priority (Significant Issues)
7. **S1**: Specify encryption standards and key management
8. **S2**: Define comprehensive audit logging
9. **S3**: Implement secure error handling with information disclosure prevention
10. **S4**: Complete infrastructure security assessment and configuration
11. **S5**: Define password security policy with strong hashing

### Medium Priority (Moderate Issues)
12. **M1**: Implement refresh token pattern for session management
13. **M2**: Define CORS policy
14. **M3**: Implement selective logging with PII masking
15. **M4**: Define Content Security Policy
16. **M5**: Validate and sanitize third-party API responses

---

## Conclusion

The TravelHub design document requires **significant security enhancements** before production deployment. The most critical issues—insecure JWT storage, missing CSRF protection, and lack of rate limiting—pose immediate risks of account compromise and service abuse. The combination of payment processing and personal data handling makes these vulnerabilities particularly severe.

**Recommended Next Steps**:
1. Address all 6 critical issues (C1-C6) before any deployment
2. Conduct security architecture review with security team
3. Implement comprehensive security testing (penetration testing, code review)
4. Document security policies in dedicated security design document
5. Establish security review process for future changes

**Estimated Effort**: 4-6 weeks for full remediation with proper testing.
