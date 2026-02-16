# Security Evaluation Report: Real-time Medical Appointment System

## Critical Security Issues

### C1. JWT Token Storage in localStorage (Client-Side Token Exposure)

**Location**: Section 5.3 - Authentication & Authorization

**Issue**: The design explicitly specifies storing JWT tokens in localStorage: "JWTトークンはlocalStorageに保存し、各APIリクエストのAuthorizationヘッダーで送信する" (Section 5.3). This creates a severe vulnerability to XSS attacks.

**Impact**: If an attacker successfully injects malicious JavaScript through any XSS vulnerability, they can trivially access localStorage and steal authentication tokens. This leads to complete account takeover, unauthorized access to sensitive medical records, and potential HIPAA/privacy regulation violations. The 30-day refresh token lifetime amplifies the attack window.

**Countermeasures**:
- Store JWT tokens in httpOnly, Secure, SameSite cookies to prevent JavaScript access
- Implement a cookie-based authentication flow with CSRF protection
- If localStorage must be used, implement short-lived tokens (5-15 minutes) with secure refresh token rotation stored in httpOnly cookies
- Add XSS detection and Content Security Policy headers as defense-in-depth

### C2. Sensitive Data Exposure in Error Responses and Logs

**Location**: Section 6.1 (Error Handling), Section 6.2 (Logging)

**Issue**: The design specifies including "詳細なスタックトレースを含め、デバッグを容易にする" in error responses and logging complete request bodies including sensitive data:
- Error responses include stack traces (Section 6.1)
- All API requests/responses logged at INFO level (Section 6.2)
- Request bodies are logged verbatim including patient data, passwords, etc.

**Impact**:
- Stack traces in production error responses leak internal implementation details (file paths, class names, library versions) to attackers, enabling targeted attacks
- Logging PII (patient names, insurance numbers, medical records) and authentication credentials in plaintext violates data protection regulations
- CloudWatch Logs become a high-value attack target containing complete medical histories and authentication data

**Countermeasures**:
- Remove stack traces from production error responses; return generic error messages to clients
- Implement log sanitization to redact sensitive fields (password, full_name, date_of_birth, insurance_number, diagnosis, etc.)
- Create separate security audit logs with controlled access for authentication events
- Use structured logging with field-level classification to automatically mask PII
- Implement log access controls and encryption at rest for CloudWatch Logs

### C3. Missing Authorization Checks on Resource Access Endpoints

**Location**: Section 5.1 (API Endpoints)

**Issue**: The design specifies JWT validation and RBAC role checks but does not explicitly design resource ownership verification for critical endpoints:
- `GET /api/patients/{id}` - No design for verifying the requesting user can access this specific patient's data
- `GET /api/patients/{id}/records` - No ownership/permission check design
- `GET /api/appointments/{id}` - No verification that the requester is authorized to view this appointment
- `GET /api/records/{id}` - No access control beyond role check

**Impact**: A malicious or compromised patient account could access other patients' medical records simply by iterating through patient IDs. This is an Insecure Direct Object Reference (IDOR) vulnerability leading to:
- Complete medical record database enumeration
- Privacy regulation violations (HIPAA, GDPR)
- Reputational damage and legal liability

**Countermeasures**:
- Design explicit authorization logic for all resource endpoints:
  - Patient endpoints: Verify `patient.user_id == requesting_user_id` OR requester has DOCTOR/ADMIN role with institution access
  - Appointment endpoints: Verify requester is the patient OR the assigned doctor OR admin of the institution
  - Record endpoints: Verify doctor-patient relationship and institution membership
- Implement an Authorization Service component with these ownership verification rules
- Document the authorization matrix: which roles can access which resources under what conditions
- Add access control integration tests for each endpoint

### C4. Missing Audit Logging for Security-Critical Operations

**Location**: Section 6.2 (Logging), Overall Design

**Issue**: The design specifies general application logging but lacks explicit design for security audit logs tracking:
- Authentication failures and account lockouts
- Authorization failures (attempted unauthorized access)
- Privilege escalation attempts
- Medical record access (who viewed which patient data when)
- Sensitive data modifications (record updates, patient info changes)
- Administrative actions (user role changes, institution management)

**Impact**:
- No forensic capability to investigate security incidents or data breaches
- Cannot detect ongoing attacks or compromised accounts
- Compliance violations (HIPAA requires audit trails for medical record access)
- No evidence for legal proceedings in case of breach

**Countermeasures**:
- Design a dedicated Security Audit Log with immutable storage (write-only S3 bucket with object lock)
- Define audit event schema including: timestamp, user ID, IP address, action type, resource ID, result (success/failure), before/after values for modifications
- Specify logging requirements for each security-critical operation:
  - All authentication attempts (login, logout, token refresh) including failures
  - All medical record access (read, create, update)
  - All administrative actions
  - All authorization failures
- Implement centralized audit log aggregation separate from application logs
- Add audit log monitoring and alerting for suspicious patterns

## Significant Security Issues

### S1. Insufficient Rate Limiting Scope

**Location**: Section 3.2 (API Gateway rate limiting)

**Issue**: The design specifies "レート制限（1分あたり100リクエスト）" at the API Gateway level but does not specify:
- Rate limiting granularity (per IP? per user? global?)
- Different rate limits for authentication endpoints vs. general APIs
- Account lockout policy after repeated authentication failures

**Impact**:
- Brute force attacks on authentication endpoints remain feasible (100 attempts/minute = 6000 password guesses/hour)
- No protection against credential stuffing attacks
- Potential for targeted DoS against specific user accounts

**Countermeasures**:
- Design stricter rate limits for authentication endpoints (e.g., 5 attempts per 5 minutes per IP/username)
- Implement progressive account lockout after repeated failures (temporary suspension, CAPTCHA)
- Specify per-user rate limits for resource-intensive operations
- Add IP-based rate limiting with allowlist for trusted networks

### S2. Missing CORS Configuration Design

**Location**: Section 3.1 (Architecture), Section 5 (API Design)

**Issue**: The design does not specify CORS (Cross-Origin Resource Sharing) policy for the RESTful API, which is critical given the SPA frontend and React Native mobile app architecture.

**Impact**:
- Without explicit CORS configuration, either:
  1. CORS is left wide open (`Access-Control-Allow-Origin: *`), allowing any malicious website to make requests to the API from a victim's browser
  2. CORS blocks legitimate requests from the intended frontend applications
- Enables cross-site request forgery and data exfiltration attacks

**Countermeasures**:
- Design explicit CORS policy with allowlist of permitted origins (production/staging frontend domains)
- Specify `Access-Control-Allow-Credentials: true` for cookie-based sessions
- Define allowed methods and headers
- Document CORS configuration in API Gateway and Spring Boot security configuration

### S3. No CSRF Protection Design

**Location**: Section 5.3 (Authentication), Overall API Design

**Issue**: The design uses stateless JWT authentication but does not specify CSRF protection mechanisms. While JWT in Authorization headers provides some CSRF resistance, the design does not address:
- CSRF protection if cookies are used (as recommended in C1 countermeasures)
- Protection for state-changing operations

**Impact**: If authentication moves to cookies (secure pattern), without CSRF tokens, an attacker can craft malicious websites that perform unauthorized actions (create appointments, modify patient data) when logged-in users visit the attacker's site.

**Countermeasures**:
- Design CSRF token generation and validation for all non-GET requests
- Implement SameSite cookie attribute (already recommended in C1)
- Add double-submit cookie pattern or synchronizer token pattern
- Document CSRF protection implementation in Spring Security configuration

### S4. Missing Data-at-Rest Encryption Design

**Location**: Section 4 (Data Model), Section 2.2 (Database), Section 7.2 (Security Requirements)

**Issue**: Section 7.2 specifies TLS 1.3 for data-in-transit but does not specify encryption for data-at-rest in:
- PostgreSQL database (contains all patient PII and medical records)
- Redis cache (may contain session data or temporary sensitive information)
- S3 storage (document/image uploads may contain medical documents)
- Database backups

**Impact**: If an attacker gains physical access to storage media, cloud snapshots, or backups, all patient medical records and PII are exposed in plaintext. This violates HIPAA technical safeguards requirements.

**Countermeasures**:
- Enable RDS encryption at rest using AWS KMS with customer-managed keys
- Enable ElastiCache encryption at rest for Redis
- Enable S3 default encryption with SSE-KMS for all buckets
- Specify that all database backups must be encrypted
- Document key rotation policies and access control for KMS keys

### S5. Incomplete Input Validation Design

**Location**: Section 7.2 (Security Requirements), Section 5 (API Design)

**Issue**: The design mentions "外部入力はSpring Validationで検証し、SQLインジェクション対策としてPreparedStatementを使用する" but does not specify:
- Validation rules for each input field (format, length, allowed characters)
- File upload restrictions (size limits, type whitelist, malware scanning)
- Output encoding/escaping to prevent XSS

**Impact**:
- Insufficient validation may allow injection attacks beyond SQL (NoSQL injection, command injection in external integrations)
- File upload vulnerabilities (malicious file execution, DoS through large uploads)
- Stored XSS if medical records contain attacker-controlled data rendered in frontend

**Countermeasures**:
- Define validation schemas for all API inputs (email format, phone number format, date ranges, text length limits)
- Specify file upload security: max size (e.g., 10MB), allowed MIME types (PDF, JPEG, PNG), virus scanning integration
- Design output encoding for rendering user-generated content (diagnosis, prescription notes)
- Implement Content Security Policy headers to mitigate XSS impact

### S6. Missing Secret Management Lifecycle Design

**Location**: Section 6.4 (Deployment), Section 2.3 (Infrastructure)

**Issue**: The design specifies "環境変数はECS Task Definitionに記載し、AWS Systems Manager Parameter Storeから取得" but does not design:
- Secret rotation policies (database passwords, JWT signing keys, API keys)
- Access control for Parameter Store (which roles/services can read which secrets)
- Secrets revocation process
- Separation of secrets by environment (dev/staging/production)

**Impact**:
- Long-lived secrets increase risk if compromised
- Overly permissive IAM policies may allow unauthorized secret access
- Difficult incident response if secret compromise detected (no rotation procedure)

**Countermeasures**:
- Design automatic secret rotation schedule (database passwords: 90 days, JWT keys: 30 days)
- Specify IAM policies for Parameter Store access (principle of least privilege)
- Document secret revocation and emergency rotation procedures
- Use AWS Secrets Manager for automatic database password rotation
- Implement separate parameter namespaces per environment with strict IAM boundaries

## Moderate Security Issues

### M1. JWT Signing Algorithm Not Specified

**Location**: Section 5.3 (Authentication)

**Issue**: The design specifies JWT usage but does not specify the signing algorithm. If a weak algorithm like HS256 with a short secret is used, or if "none" algorithm is accepted, JWTs can be forged.

**Impact**: Token forgery leading to authentication bypass and privilege escalation.

**Countermeasures**:
- Specify RS256 (asymmetric) or HS512 (symmetric with strong key) for JWT signing
- Document key generation requirements (minimum 256-bit entropy)
- Explicitly disable "none" algorithm acceptance in JWT validation

### M2. No Design for Preventing Information Disclosure Through Timing Attacks

**Location**: Section 5.1 (Authentication API)

**Issue**: No specification of constant-time comparison for authentication or protection against user enumeration through different response times/messages for valid vs. invalid usernames.

**Impact**: Attackers can enumerate valid usernames, reducing brute force attack space.

**Countermeasures**:
- Design authentication responses to be identical for invalid username vs. invalid password
- Use constant-time comparison for password verification
- Add random delay jitter to authentication responses

### M3. Multi-AZ Configuration Does Not Address Data Tampering Protection

**Location**: Section 7.3 (Availability), Section 4 (Data Model)

**Issue**: The design includes Multi-AZ failover for availability but does not address integrity verification mechanisms to detect unauthorized data modification in the database.

**Impact**: If an attacker gains write access to the database (through SQL injection, compromised credentials, or insider threat), there is no mechanism to detect tampering of medical records.

**Countermeasures**:
- Design cryptographic signatures or checksums for critical records (medical records, appointments)
- Implement immutable audit trail with hash chains
- Add database activity monitoring and anomaly detection
- Consider blockchain or append-only log for medical record history

### M4. Insufficient Session Management Design

**Location**: Section 5.3 (Authentication)

**Issue**: The design specifies token expiration (1 hour access, 30 day refresh) but does not specify:
- Concurrent session limits per user
- Session invalidation on password change
- Refresh token rotation (to prevent token replay attacks)
- Logout implementation (token revocation mechanism)

**Impact**: Stolen refresh tokens can be used for 30 days, compromised sessions persist after password changes, and logout may not actually invalidate tokens.

**Countermeasures**:
- Design refresh token rotation: issue new refresh token on each use, invalidate old one
- Implement token revocation list (Redis-based) for logout
- Specify concurrent session limits (e.g., max 3 active devices per user)
- Add forced logout on password change or role modification

## Minor Improvements and Positive Aspects

### Positive Security Measures Identified

1. **Strong Password Hashing**: bcrypt with cost factor 10 is appropriate (Section 7.2)
2. **TLS 1.3 for Transit**: Modern encryption protocol specified (Section 7.2)
3. **PreparedStatement for SQL Injection Prevention**: Explicitly mentioned (Section 7.2)
4. **RBAC Implementation**: Role-based access control design present (Section 5.3)
5. **Multi-AZ for Availability**: Resilience against infrastructure failures (Section 7.3)
6. **Automated Backups**: Data recovery capability (Section 7.3)

### Minor Recommendations

1. **Specify Password Complexity Requirements**: Define minimum length, character requirements for user passwords
2. **Add Security Headers**: Design Content-Security-Policy, X-Frame-Options, X-Content-Type-Options headers
3. **Specify Dependency Vulnerability Management**: While Spring Boot and libraries are specified, add continuous dependency scanning (e.g., OWASP Dependency Check)
4. **Add Penetration Testing Phase**: Include security testing in deployment pipeline before production releases
5. **Document Incident Response Plan**: Add procedures for handling security incidents and data breaches

## Summary

This medical appointment system design has several strong security foundations (bcrypt, TLS 1.3, PreparedStatements) but contains **4 critical vulnerabilities** that must be addressed before implementation:

1. JWT in localStorage enabling XSS-based account takeover
2. Sensitive data exposure in error responses and logs
3. Missing resource-level authorization checks (IDOR vulnerability)
4. Absence of security audit logging

Additionally, **6 significant issues** require design-level fixes to meet healthcare data protection standards (HIPAA compliance):
- Insufficient authentication rate limiting
- Missing CORS/CSRF protection
- No data-at-rest encryption specification
- Incomplete input validation design
- Inadequate secret management lifecycle

The design should be revised to address all critical and significant issues before proceeding to implementation, with particular focus on authorization controls and audit logging given the sensitive nature of medical data.
