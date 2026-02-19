# Security Design Review: Online Medical Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple missing threat considerations: no session invalidation (Spoofing), no audit logging (Repudiation), no DoS protection beyond basic rate limiting |
| Authentication & Authorization Design | 2 | JWT tokens stored client-side with 24-hour expiration create extended attack window; no token revocation mechanism; missing MFA for medical staff |
| Data Protection | 3 | AES-256 encryption specified but key management strategy completely absent; missing data retention/deletion policies required for medical data compliance |
| Input Validation Design | 1 | No input validation policy defined; no mention of injection prevention, output escaping, or file upload restrictions despite handling medical images/PDFs |
| Infrastructure & Dependencies | 3 | Missing secret management design (JWT signing keys, DB credentials); no dependency vulnerability scanning mentioned; WAF configured but rules not specified |
| **Overall** | **2.2** | |

## 1. Critical Issues (design modification required)

### 1.1 No Input Validation Policy or Injection Prevention Design

**Problem**: The design document completely lacks any input validation policy or injection prevention measures. Medical records contain TEXT fields (diagnosis, prescription) that will accept user/doctor input, but there is no mention of:
- SQL injection prevention strategy
- XSS prevention in medical record display
- Command injection prevention
- LDAP injection prevention
- Input sanitization rules

**Impact**:
- **SQL Injection**: Attackers could extract entire patient database including 100万人 of sensitive medical records through unvalidated inputs in search/filter endpoints
- **XSS**: Malicious scripts injected into medical records could steal JWT tokens or session data from doctors/patients viewing the records
- **Data Corruption**: Invalid medical data (e.g., negative dosages, invalid dates) could be stored, compromising patient safety

**Recommended Countermeasures**:
1. Define comprehensive input validation policy:
   - Use parameterized queries (JPA/Hibernate prevents SQL injection by default, but verify configuration)
   - Implement server-side validation for all fields with strict whitelists:
     - Name: `^[\p{L}\s]{1,100}$` (Unicode letters and spaces)
     - Phone: `^[0-9-+()]{10,20}$`
     - Email: RFC 5322 compliant validation
     - Diagnosis/Prescription: Maximum length 10,000 characters, strip HTML tags
   - Configure Content-Security-Policy header to prevent XSS: `default-src 'self'; script-src 'self'`
   - Use OWASP Java Encoder for output escaping in all responses
2. Add validation middleware in Spring Boot:
   ```java
   @Component
   public class InputValidationInterceptor implements HandlerInterceptor {
       // Apply validation rules before controller execution
   }
   ```
3. Implement file upload restrictions for medical images/PDFs:
   - Whitelist MIME types: `image/jpeg`, `image/png`, `application/pdf`
   - Maximum file size: 10MB
   - Virus scanning using ClamAV before S3 upload
   - Store files with random UUID filenames (prevent path traversal)

**Relevant Section**: Section 5 (API Design), Section 6 (Implementation Policy)

### 1.2 Missing JWT Signing Key Management and Rotation Strategy

**Problem**: The design specifies JWT authentication with jjwt 0.11 but provides zero details on:
- How JWT signing keys are generated, stored, and rotated
- Whether symmetric (HMAC) or asymmetric (RSA/ECDSA) signing is used
- Where signing keys are stored (hardcoded? environment variables? AWS Secrets Manager?)
- Key rotation schedule

**Impact**:
- If signing key is compromised (leaked in code repository, extracted from memory), attackers can forge unlimited valid JWT tokens for any user (patient/doctor/admin) with 24-hour validity
- No key rotation means compromised keys remain valid indefinitely
- Symmetric keys (HMAC) stored in environment variables can be extracted from ECS task metadata or CloudWatch logs

**Recommended Countermeasures**:
1. Use asymmetric signing (RS256 with 2048-bit RSA keys):
   - Private key stored in AWS Secrets Manager with automatic rotation every 90 days
   - Public key distributed to API Gateway for validation
   - Use separate key pairs for different environments (dev/staging/prod)
2. Implement key rotation mechanism:
   ```java
   @Configuration
   public class JwtConfig {
       @Bean
       public JwtKeyResolver keyResolver(SecretsManagerClient secretsManager) {
           // Fetch current and previous keys from Secrets Manager
           // Support gradual rollover period (7 days)
       }
   }
   ```
3. Add `kid` (key ID) claim to JWT header to identify which key was used
4. Store key rotation events in audit log
5. Emergency key revocation procedure: Invalidate all existing tokens by rotating key and forcing re-authentication

**Relevant Section**: Section 5.3 (Authentication/Authorization), Section 3 (Architecture Design)

### 1.3 No Session Invalidation or Token Revocation Mechanism

**Problem**: JWT tokens have 24-hour expiration, but there is no mechanism to invalidate tokens before expiration in critical scenarios:
- Patient/doctor account compromise detection
- Password change (old tokens should be immediately invalidated)
- Account deletion or suspension
- Logout operation (tokens remain valid for 24 hours after logout)

**Impact**:
- Stolen JWT tokens remain valid for up to 24 hours even after victim changes password or reports compromise
- Deleted/suspended accounts can still access the system for up to 24 hours
- No way to perform emergency security response (e.g., mass token revocation during security incident)

**Recommended Countermeasures**:
1. Implement token revocation using Redis:
   ```
   Key: "revoked_token:{jti}"  // Use JWT ID claim
   Value: "1"
   TTL: Remaining token validity period
   ```
2. Add JWT validation middleware:
   ```java
   public boolean isTokenRevoked(String jti) {
       return redisTemplate.hasKey("revoked_token:" + jti);
   }
   ```
3. Revoke tokens on critical events:
   - Password change: Revoke all tokens for user (`revoked_user:{userId}` with 24h TTL)
   - Account deletion: Permanent revocation
   - Logout: Revoke specific token
4. Reduce access token expiration to 15 minutes and implement refresh token pattern:
   - Access token: 15 min (short-lived, no revocation needed)
   - Refresh token: 7 days, stored in Redis with rotation
   - Refresh endpoint: `/api/v1/auth/refresh` validates refresh token and issues new access token
5. Add `jti` (JWT ID) claim to all tokens for unique identification

**Relevant Section**: Section 5.3 (Authentication/Authorization), Section 3 (Architecture Design)

### 1.4 Missing Audit Logging for Medical Records Access and Modification

**Problem**: The design mentions CloudWatch Logs for INFO/WARN/ERROR logging but does not specify audit logging for security-critical operations:
- Who accessed which patient's medical records and when
- Who modified medical records and what was changed
- Failed authentication attempts
- Authorization failures (e.g., doctor attempting to access non-assigned patient)
- Admin operations (account creation, permission changes)

**Impact**:
- **Compliance Violation**: Medical data regulations (e.g., HIPAA in US, GDPR in EU, Japanese Act on the Protection of Personal Information for medical institutions) require audit trails for all access to personal health information
- **Forensics Impossible**: Cannot investigate security incidents or data breaches (e.g., which staff member leaked patient data)
- **Repudiation Risk**: No evidence if patient claims their medical record was tampered with
- **Insider Threat**: Malicious medical staff can access/modify records without detection

**Recommended Countermeasures**:
1. Design comprehensive audit logging policy:
   - **What to log**:
     - Medical record access: `{timestamp, user_id, user_role, patient_id, record_id, action: "VIEW", ip_address, user_agent}`
     - Medical record modification: `{timestamp, user_id, user_role, patient_id, record_id, action: "CREATE/UPDATE/DELETE", changed_fields, old_value, new_value}`
     - Authentication events: `{timestamp, email, action: "LOGIN_SUCCESS/LOGIN_FAILURE/LOGOUT", ip_address, failure_reason}`
     - Authorization failures: `{timestamp, user_id, requested_resource, action: "ACCESS_DENIED", reason}`
   - **Log storage**:
     - Primary: CloudWatch Logs with 7-year retention (medical records retention requirement)
     - Archive: S3 with Glacier for long-term storage
     - Separate log stream for audit logs (prevent mixing with application logs)
   - **Log protection**:
     - Enable CloudWatch Logs encryption with KMS
     - Restrict log access to dedicated audit role
     - Enable log integrity validation (CloudWatch Logs Insights cannot modify logs)
2. Implement audit logging interceptor:
   ```java
   @Aspect
   @Component
   public class AuditLoggingAspect {
       @Around("@annotation(Auditable)")
       public Object logAudit(ProceedingJoinPoint joinPoint) {
           // Log before and after method execution
           // Capture user context from SecurityContextHolder
       }
   }
   ```
3. Add audit log viewer for administrators and compliance officers
4. Set up alerts for suspicious patterns:
   - Same user accessing >100 patient records in 1 hour
   - After-hours access by medical staff
   - Repeated authorization failures

**Relevant Section**: Section 6.2 (Logging Policy), Section 7.2 (Security Requirements)

### 1.5 No Multi-Factor Authentication for Medical Staff

**Problem**: Medical staff (doctors, nurses, admins) authenticate using only email + password. Given that medical staff have access to sensitive data for thousands of patients, single-factor authentication is insufficient:
- Doctors can access medical records for all their assigned patients
- Admins can access all 100万人 patient records
- No additional verification for high-privilege operations

**Impact**:
- Compromised doctor accounts (phishing, credential stuffing, password reuse) lead to mass patient data breach
- Single point of failure for protecting highly sensitive medical data
- Regulatory non-compliance: Many jurisdictions require MFA for medical data access

**Recommended Countermeasures**:
1. Implement mandatory MFA for all medical staff roles (doctors, nurses, admins):
   - **Primary method**: TOTP (Google Authenticator, Authy) using RFC 6238
   - **Backup method**: SMS OTP (fallback only, not primary due to SS7 vulnerabilities)
   - **Recovery codes**: 10 single-use codes generated during MFA enrollment
2. MFA enrollment flow:
   - Enforce MFA setup on first login for new medical staff accounts
   - Block access until MFA is configured
   - Store TOTP secret encrypted in database with patient-level encryption
3. MFA verification flow:
   - Require MFA code after successful password authentication
   - Limit verification attempts to 5 within 15 minutes (then lock account)
   - Remember device for 30 days using secure cookie (optional, configurable per institution)
4. Step-up authentication for critical operations:
   - Sharing medical records with other institutions: Require fresh MFA challenge
   - Bulk data export: Require fresh MFA challenge
   - Account permission changes: Require fresh MFA challenge
5. Add MFA status to admin dashboard:
   - Show which staff members have/haven't enabled MFA
   - Allow admins to force MFA reset if staff member reports device loss

**Relevant Section**: Section 5.3 (Authentication/Authorization), Section 7.2 (Security Requirements)

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Missing Encryption Key Management Strategy for AES-256

**Problem**: Section 7.2 specifies "DB内の機密情報（診断内容、処方箋）はAES-256で暗号化" but provides no details on:
- How encryption keys are generated and stored
- Who has access to encryption keys
- Key rotation schedule
- Key hierarchy (master key vs. data keys)
- What happens to old encrypted data after key rotation

**Rationale**: Without proper key management, AES-256 encryption provides false security. If encryption keys are hardcoded or stored in environment variables, they are trivially compromised.

**Recommended Countermeasures**:
1. Use AWS KMS with envelope encryption pattern:
   - **Customer Master Key (CMK)**: Managed in AWS KMS, auto-rotates yearly
   - **Data Encryption Keys (DEK)**: Generated per encryption operation, encrypted with CMK
   - Store encrypted DEK alongside encrypted data
2. Implement application-level encryption in JPA:
   ```java
   @Convert(converter = EncryptedStringConverter.class)
   @Column(name = "diagnosis")
   private String diagnosis;

   public class EncryptedStringConverter implements AttributeConverter<String, String> {
       // Uses AWS KMS SDK to decrypt DEK, then decrypt data
   }
   ```
3. Key rotation procedure:
   - Re-encrypt all medical records when CMK rotates (background job)
   - Maintain backward compatibility during rotation period (support decryption with old CMK for 30 days)
4. Access control:
   - Grant KMS decrypt permission only to ECS task execution role
   - Deny KMS access to developers and operators
   - Require approval for emergency KMS access (CloudTrail logging)
5. Consider field-level encryption granularity:
   - Encrypt: diagnosis, prescription, doctor notes
   - Do NOT encrypt: patient_id, visit_date (needed for queries)

### 2.2 Missing Data Retention and Deletion Policy

**Problem**: Medical data has strict regulatory requirements for retention and deletion, but the design does not specify:
- How long patient data is retained after account deletion
- How medical records are deleted (hard delete vs. soft delete)
- Data deletion procedure when patient exercises "right to be forgotten"
- Backup data deletion strategy

**Rationale**:
- Japanese medical law requires medical records to be retained for at least 5 years after final visit
- GDPR-like privacy laws require deletion of personal data upon user request (with exceptions for legal obligations)
- Inconsistent retention leads to compliance violations and unnecessary data exposure

**Recommended Countermeasures**:
1. Define data retention policy:
   - **Active patient accounts**: Retain all data indefinitely
   - **Deleted patient accounts**:
     - Medical records: Retain for 7 years after account deletion (exceeds legal minimum)
     - Personal information (name, contact): Anonymize immediately after deletion request
   - **Inactive accounts**: Auto-delete accounts with no activity for 3 years (with 90-day email warning)
2. Implement soft delete with anonymization:
   ```sql
   UPDATE patients SET
     name = 'DELETED_USER_' || id,
     email = 'deleted_' || id || '@deleted.local',
     phone = 'DELETED',
     deleted_at = NOW()
   WHERE id = ?
   ```
3. Scheduled deletion job:
   - Daily job checks for `deleted_at < NOW() - INTERVAL '7 years'`
   - Hard delete medical records associated with these patients
   - Delete from backups using S3 Object Lock expiration
4. Add deletion audit log:
   - Record which patient data was deleted, when, and by whom
   - Preserve audit logs for 10 years (longer than data retention)
5. Data deletion verification:
   - Quarterly compliance check confirms deleted data is gone from prod DB, backups, and logs
   - Generate deletion certificate for patient upon request

### 2.3 No CSRF Protection Design for State-Changing API Endpoints

**Problem**: The design uses JWT for authentication but does not mention CSRF (Cross-Site Request Forgery) protection for state-changing operations:
- `POST /api/v1/appointments` (予約作成)
- `DELETE /api/v1/appointments/{id}` (予約キャンセル)
- `POST /api/v1/medical-records` (カルテ作成)
- `PUT /api/v1/patients/{id}` (患者情報更新)

**Rationale**: If JWT tokens are stored in localStorage (common pattern with SPAs), they are vulnerable to CSRF attacks. An attacker can trick a logged-in user into visiting a malicious site that sends requests to the medical platform API with the user's token.

**Recommended Countermeasures**:
1. Implement Double Submit Cookie pattern:
   - On login, generate random CSRF token (32-byte hex string)
   - Set token in both:
     - HttpOnly cookie: `csrf-token={token}; SameSite=Strict; Secure`
     - Response body: Include in login response for client storage
   - Client sends token in custom header: `X-CSRF-Token: {token}`
   - Server validates cookie value matches header value
2. Add CSRF validation middleware in Spring Boot:
   ```java
   @Component
   public class CsrfValidationFilter extends OncePerRequestFilter {
       @Override
       protected void doFilterInternal(HttpServletRequest request, ...) {
           if (isStateChangingRequest(request)) {
               String headerToken = request.getHeader("X-CSRF-Token");
               Cookie csrfCookie = getCsrfCookie(request);
               if (!csrfCookie.getValue().equals(headerToken)) {
                   throw new CsrfTokenMismatchException();
               }
           }
       }
   }
   ```
3. Set SameSite=Strict on all cookies (already mentioned in prompt examples, but not in design doc)
4. Alternative: Use SameSite=Strict cookies for JWT storage instead of localStorage:
   - Prevents XSS token theft
   - Provides automatic CSRF protection
   - Trade-off: Cannot send tokens in Authorization header from other domains

### 2.4 Missing Rate Limiting Design for Authentication Endpoints

**Problem**: Section 7.2 mentions "APIレート制限: 1分間に60リクエスト/ユーザー" but this is insufficient for authentication endpoints:
- `POST /api/v1/auth/login` (ログイン)
- `POST /api/v1/auth/register` (新規登録)
- `POST /api/v1/auth/refresh` (トークンリフレッシュ)

These endpoints are prime targets for:
- Credential stuffing attacks (automated login attempts with stolen credentials)
- Brute force attacks (guessing passwords)
- Account enumeration (discovering valid email addresses)

**Rationale**: Standard rate limiting (60 req/min per user) does not apply to login endpoints because attackers don't have valid user tokens yet. They can attempt thousands of logins per minute from distributed IPs.

**Recommended Countermeasures**:
1. Implement multi-layered rate limiting for authentication:
   - **Per-IP rate limiting**:
     - Login: 10 attempts per IP per 15 minutes (stored in Redis)
     - Registration: 3 accounts per IP per hour
   - **Per-email rate limiting**:
     - Login: 5 failed attempts per email per 15 minutes
     - After 5 failures: Lock account for 30 minutes (send email notification)
   - **Global rate limiting**:
     - Login: 1000 requests per minute across all IPs (detect DDoS)
2. Configure Redis-based rate limiter:
   ```java
   @Component
   public class LoginRateLimiter {
       public void checkLimit(String email, String ip) {
           String emailKey = "login:email:" + email;
           String ipKey = "login:ip:" + ip;

           if (redisTemplate.opsForValue().increment(emailKey) > 5) {
               throw new TooManyLoginAttemptsException();
           }
           redisTemplate.expire(emailKey, 15, TimeUnit.MINUTES);

           // Similar for IP-based limiting
       }
   }
   ```
3. Add progressive delays:
   - 1st failure: Immediate response
   - 2nd failure: 1 second delay
   - 3rd failure: 2 seconds delay
   - 4th+ failure: 5 seconds delay
4. Implement CAPTCHA after repeated failures:
   - Show reCAPTCHA v3 after 3 failed login attempts
   - Require CAPTCHA solve before allowing further attempts
5. Monitor and alert:
   - Alert security team if single IP attempts >100 logins in 1 hour
   - Alert if single email receives >20 failed login attempts (account takeover attempt)

### 2.5 Missing Database Connection Encryption and Credential Rotation

**Problem**: The design specifies PostgreSQL 15 as the main database but does not mention:
- Whether database connections are encrypted (TLS)
- How database credentials are stored and rotated
- Whether separate credentials are used for different services (患者サービス, カルテサービス, 予約サービス)

**Rationale**:
- Unencrypted database connections allow network sniffing of sensitive medical data
- Hardcoded or static database credentials create long-term compromise risk
- Overly permissive database credentials (single account with all privileges) violate principle of least privilege

**Recommended Countermeasures**:
1. Enable TLS for all PostgreSQL connections:
   - Configure PostgreSQL to require SSL: `ssl = on, ssl_min_protocol_version = 'TLSv1.2'`
   - Spring Boot configuration:
     ```yaml
     spring:
       datasource:
         url: jdbc:postgresql://db-host:5432/medical_db?ssl=true&sslmode=require
     ```
2. Store database credentials in AWS Secrets Manager:
   - Create separate database users for each service:
     - `patient_service_user`: SELECT/INSERT/UPDATE on patients table only
     - `medical_record_service_user`: Full access to medical_records table
     - `appointment_service_user`: Full access to appointments table
   - Rotate credentials every 90 days using Secrets Manager auto-rotation
3. Use IAM database authentication (RDS-specific):
   - Services authenticate to PostgreSQL using temporary IAM tokens (15-minute validity)
   - No long-lived passwords to manage
   - Requires AWS RDS PostgreSQL (not self-managed EC2 PostgreSQL)
4. Apply least privilege to database accounts:
   - Patient service: `GRANT SELECT, INSERT, UPDATE ON patients TO patient_service_user;`
   - Deny DELETE on all tables except admin service
   - Deny DDL operations (CREATE, ALTER, DROP) on application accounts

### 2.6 No Error Response Information Disclosure Policy

**Problem**: Section 6.1 defines error response format but does not specify what information should be hidden from API responses:
```json
{
  "error": "INVALID_REQUEST",
  "message": "The patient ID is required.",
  "timestamp": "2026-02-10T12:34:56Z"
}
```

Missing specifications:
- Should stack traces be included in error responses?
- Should database error messages be exposed?
- Should authentication failure reasons be detailed (user not found vs. wrong password)?
- Should internal system paths be exposed?

**Rationale**: Verbose error messages aid attackers:
- Stack traces reveal code structure and library versions
- Database errors leak schema information
- Detailed auth errors enable account enumeration
- Internal paths reveal deployment structure

**Recommended Countermeasures**:
1. Define error message sanitization policy:
   - **Never expose**:
     - Stack traces (log them, don't return them)
     - Database error messages (e.g., "column 'ssn' does not exist")
     - Internal file paths (e.g., "/app/src/main/java/...")
     - Library versions or framework details
   - **Generic authentication errors**:
     - ❌ Bad: "User not found" vs. "Invalid password" (enables enumeration)
     - ✅ Good: "Invalid email or password" (same message for both)
   - **Specific validation errors** (safe to expose):
     - "Email format is invalid"
     - "Phone number must be 10-15 digits"
2. Implement error sanitization filter:
   ```java
   @ControllerAdvice
   public class GlobalExceptionHandler {
       @ExceptionHandler(Exception.class)
       public ResponseEntity<ErrorResponse> handleException(Exception e) {
           // Log full exception with stack trace
           logger.error("Unhandled exception", e);

           // Return sanitized response
           return ResponseEntity.status(500).body(
               new ErrorResponse("INTERNAL_ERROR", "An error occurred. Please try again later.")
           );
       }
   }
   ```
3. Add environment-specific behavior:
   - Development: Return detailed errors including stack traces
   - Production: Return only generic error messages
4. Correlation IDs for debugging:
   - Include unique request ID in error response: `"request_id": "abc-123-def"`
   - Users can provide request ID to support team for investigation
   - Support team can look up full error details in logs using request ID

### 2.7 Missing Dependency Vulnerability Scanning in CI/CD Pipeline

**Problem**: Section 6.4 mentions Blue-Green deployment and testing strategy but does not include security scanning:
- No mention of dependency vulnerability scanning (e.g., Spring Boot CVEs)
- No mention of container image scanning (Docker image vulnerabilities)
- No mention of static code analysis (SAST) for security issues

**Rationale**:
- Medical platform will use 50+ dependencies (Spring Boot, PostgreSQL driver, JWT library, etc.)
- Dependencies frequently have security vulnerabilities (e.g., Log4Shell, Spring4Shell)
- Unpatched vulnerabilities in production lead to data breaches

**Recommended Countermeasures**:
1. Integrate OWASP Dependency-Check in CI/CD pipeline:
   ```xml
   <plugin>
       <groupId>org.owasp</groupId>
       <artifactId>dependency-check-maven</artifactId>
       <version>8.4.0</version>
       <configuration>
           <failBuildOnCVSS>7</failBuildOnCVSS> <!-- Fail if high/critical CVE found -->
       </configuration>
   </plugin>
   ```
2. Add container image scanning:
   - Use Trivy to scan Docker images before pushing to ECR
   - Fail build if high/critical vulnerabilities detected
   - Example: `trivy image --severity HIGH,CRITICAL my-app:latest`
3. Implement automated dependency updates:
   - Use Dependabot to create PRs for dependency updates
   - Prioritize security updates (auto-merge patch versions after tests pass)
4. Add static application security testing (SAST):
   - Use SpotBugs with Find Security Bugs plugin
   - Detect common issues: SQL injection, XSS, insecure random, hardcoded credentials
5. Scheduled scans:
   - Daily scan of production dependencies (alert on new CVEs)
   - Weekly scan of container images in ECR
6. Vulnerability remediation SLA:
   - Critical (CVSS 9-10): Patch within 7 days
   - High (CVSS 7-8.9): Patch within 30 days
   - Medium (CVSS 4-6.9): Patch within 90 days

### 2.8 No Idempotency Design for Appointment Creation

**Problem**: The `POST /api/v1/appointments` endpoint creates appointments but does not specify idempotency handling:
- What happens if a patient's network fails after the appointment is created but before receiving the response?
- Patient retries the request → duplicate appointment created
- No idempotency key mechanism mentioned

**Rationale**:
- Network failures and client retries are common in mobile apps
- Duplicate appointments waste doctor time and confuse patients
- Payment endpoint is also vulnerable (duplicate charges)

**Recommended Countermeasures**:
1. Implement idempotency key pattern:
   - Client generates unique UUID and sends in header: `Idempotency-Key: {uuid}`
   - Server stores processed idempotency keys in Redis:
     ```
     Key: "idempotent:appointments:{uuid}"
     Value: {appointment_id: 12345, status: "completed"}
     TTL: 24 hours
     ```
   - If duplicate request detected, return original response from cache
2. Add idempotency middleware:
   ```java
   @Component
   public class IdempotencyInterceptor implements HandlerInterceptor {
       @Override
       public boolean preHandle(HttpServletRequest request, ...) {
           String idempotencyKey = request.getHeader("Idempotency-Key");
           if (idempotencyKey != null) {
               CachedResponse cached = redisTemplate.get("idempotent:" + idempotencyKey);
               if (cached != null) {
                   // Return cached response, skip controller execution
                   return false;
               }
           }
           return true;
       }
   }
   ```
3. Apply to critical state-changing endpoints:
   - `POST /api/v1/appointments` (appointment creation)
   - Payment endpoints (when implemented)
   - Medical record creation (avoid duplicate entries)
4. Client-side implementation:
   - Generate idempotency key on user action (not on retry)
   - Store key in local storage until request succeeds
   - Include key in all retry attempts
5. Handle edge cases:
   - Concurrent requests with same idempotency key: Lock using Redis SETNX
   - Expired idempotency keys: Allow new request with same key after TTL

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Medical Record Sharing Between Institutions Requires Explicit Consent Design

**Confirmation Reason**: The design includes `is_shared` boolean flag in medical_records table (section 4) and mentions "診療情報共有(他院との連携)" as a feature, but does not specify:
- How patient consent is obtained for sharing
- Whether consent is per-record or blanket permission
- Whether patient can revoke sharing consent
- How shared data is audited

**Options and Trade-offs**:

**Option A: Granular per-record consent**
- Patient must explicitly approve sharing of each medical record
- Pros: Maximum patient control, clear consent trail, GDPR-compliant
- Cons: UX friction (patients must approve every share), may reduce adoption
- Implementation: Add `consent_timestamp` and `consent_method` columns to medical_records

**Option B: Institution-level consent**
- Patient grants blanket permission to share all records with specific institutions
- Pros: Better UX (one-time setup), easier for patients with chronic conditions
- Cons: Less granular control, harder to revoke selectively
- Implementation: Add `sharing_consents` table with (patient_id, clinic_id, granted_at, revoked_at)

**Option C: Hybrid approach**
- Default: No sharing
- Patient can enable institution-level sharing
- Patient can revoke sharing at any time (soft delete shared records from recipient institution)
- Critical records (e.g., HIV status, mental health) require explicit per-record consent regardless of blanket setting
- Pros: Balances UX and privacy control
- Cons: More complex implementation

**Recommendation**: Implement Option C (hybrid) to comply with medical privacy regulations while maintaining usability. Requires adding consent management UI and audit logging.

### 3.2 Session Timeout Configuration for Medical Staff

**Confirmation Reason**: JWT tokens have 24-hour expiration, but medical staff often work on shared terminals in hospitals. No mention of:
- Automatic session timeout after inactivity
- Screen lock mechanism
- Concurrent session limits

**Options and Trade-offs**:

**Option A: Keep 24-hour token with no inactivity timeout**
- Pros: Convenient for medical staff (no interruptions during busy shifts)
- Cons: High risk if staff forgets to log out on shared terminal
- Risk: Unauthorized access to patient data for up to 24 hours

**Option B: Short session timeout (15 minutes inactivity)**
- Pros: Strong security, limits exposure window
- Cons: Poor UX for doctors (interrupted during patient consultations), may lead to workarounds
- Implementation: Client-side activity tracking, refresh token on activity

**Option C: Configurable per-institution timeout**
- Allow each medical institution to set their own timeout (range: 5-60 minutes)
- Pros: Flexibility for different security postures, hospitals can balance security vs. workflow
- Cons: More complex configuration management
- Implementation: Add `session_timeout_minutes` to clinics table

**Recommendation**: Implement Option C with default 15-minute timeout. Add "extend session" prompt 2 minutes before timeout (one-click extension for 15 more minutes).

## 4. Positive Evaluation (good points)

### 4.1 Strong Password Hashing with bcrypt

The design appropriately uses bcrypt with cost factor 12 for password hashing (section 4, patients table). This is a modern, secure approach:
- bcrypt is resistant to rainbow table attacks and GPU cracking
- Cost factor 12 provides good balance between security and performance (~250ms per hash)
- Allows future cost increases as hardware improves

This demonstrates awareness of authentication security best practices.

### 4.2 Encryption at Rest for Sensitive Medical Data

The design explicitly specifies AES-256 encryption for sensitive fields (diagnosis, prescription) in section 7.2. While key management details are missing (see improvement suggestion 2.1), the decision to encrypt at the application level rather than relying solely on disk encryption shows defense-in-depth thinking:
- Protects data in database backups
- Protects data if database is compromised
- Allows selective encryption of high-sensitivity fields

### 4.3 Multi-Layered Network Security with WAF and CloudFront

The architecture includes AWS CloudFront + WAF in front of the application (section 3). This provides:
- DDoS protection at the edge
- Protection against common web attacks (SQL injection, XSS) if WAF rules are properly configured
- Geographic filtering capabilities
- TLS termination at edge reduces latency

The inclusion of WAF demonstrates awareness that application-layer attacks require specialized defenses beyond firewalls.

### 4.4 Database Read Replicas for Availability

The design includes 2 read replicas for PostgreSQL (section 7.1). From a security perspective:
- Reduces risk of primary database overload (availability = security for medical platform)
- Allows separation of read-only queries (e.g., patient record lookups) from write operations
- Potential to implement least-privilege by granting some services read-only access

### 4.5 HTTPS for All Communications

The design mandates TLS 1.2+ for all communications (section 7.2). This is correct and necessary for protecting medical data in transit:
- Prevents eavesdropping on patient data
- Protects authentication credentials from network sniffing
- TLS 1.2 minimum excludes weak protocols (SSLv3, TLS 1.0, TLS 1.1)
