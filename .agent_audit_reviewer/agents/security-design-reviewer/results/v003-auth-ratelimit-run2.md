# Security Design Review: Real-time Medical Appointment System

## Critical Issues

### C1. JWT Token Storage in localStorage (Information Disclosure)

**Issue**: The design document specifies storing JWT tokens in localStorage (Section 5.3: "JWTトークンはlocalStorageに保存し").

**Impact**: localStorage is vulnerable to XSS attacks. Any JavaScript code executed in the same origin can read the token, leading to complete account takeover. In a medical system handling sensitive patient data (health records, personal information), this represents a critical security vulnerability that could result in unauthorized access to protected health information and HIPAA/privacy regulation violations.

**Countermeasures**:
- Store JWT tokens in httpOnly, secure cookies instead of localStorage
- Implement SameSite cookie attribute (Strict or Lax) to prevent CSRF
- If localStorage must be used, implement additional XSS protections:
  - Content Security Policy (CSP) with strict script-src directives
  - Regular security audits of all client-side dependencies
  - Subresource Integrity (SRI) for external scripts

**Reference**: Section 5.3 (認証・認可方式)

### C2. Detailed Stack Traces in Production Error Responses (Information Disclosure)

**Issue**: The error handling policy states "エラーメッセージには詳細なスタックトレースを含め、デバッグを容易にする" (Section 6.1).

**Impact**: Exposing stack traces to end users reveals internal implementation details, file paths, library versions, and database structure. Attackers can use this information to identify vulnerable components and craft targeted attacks. In a healthcare application, this could facilitate attacks leading to patient data breaches.

**Countermeasures**:
- Return generic error messages to clients in production environments
- Log detailed stack traces server-side only (CloudWatch Logs as mentioned)
- Implement environment-aware error handling:
  - Development: detailed error messages
  - Production: sanitized, user-friendly messages with error codes
- Use correlation IDs to link client errors with server logs for debugging

**Reference**: Section 6.1 (エラーハンドリング方針)

### C3. Missing Authorization Checks for Patient Data Access (Elevation of Privilege)

**Issue**: The API design lists patient data endpoints (`GET /api/patients/{id}`, `GET /api/patients/{id}/records`) but does not specify authorization verification beyond role-based access control. There is no explicit design for ownership verification.

**Impact**: Without explicit ownership checks, a patient with valid authentication could potentially access another patient's medical records by simply changing the ID parameter. This represents a critical privacy violation and potential HIPAA breach, exposing sensitive health information including diagnoses, prescriptions, and lab results.

**Countermeasures**:
- Add explicit authorization check specification for all patient data endpoints:
  - Verify that the requesting user's patient_id matches the resource patient_id
  - For DOCTOR role: verify that the patient has an appointment with this doctor or the doctor's institution
  - For ADMIN role: implement additional audit logging for all patient data access
- Document this authorization model clearly in Section 5.3
- Example specification: "GET /api/patients/{id} requires either: (1) authenticated user's patient_id == {id}, OR (2) DOCTOR role with active appointment relationship, OR (3) ADMIN role with audit log entry"

**Reference**: Section 5.1 (API設計 - 患者API)

### C4. Missing Authorization Checks for Medical Records (Elevation of Privilege)

**Issue**: Medical records endpoints (`GET /api/records/{id}`, `POST /api/records`, `PUT /api/records/{id}`) lack explicit authorization design beyond role checks.

**Impact**: Without ownership/relationship verification, authenticated users could potentially:
- Doctors could access records from patients at other institutions
- Patients could access or modify records they don't own
- Records could be created or modified without proper patient consent or relationship validation
This violates patient privacy rights and medical confidentiality requirements.

**Countermeasures**:
- Design explicit authorization rules for medical records:
  - `GET /api/records/{id}`: Verify requester is the patient owner OR attending doctor OR authorized medical staff at the institution
  - `POST /api/records`: Verify requester is a doctor with active appointment for this patient
  - `PUT /api/records/{id}`: Verify requester is the original creating doctor OR has explicit permission
- Add institution-level isolation: doctors can only access records for patients at their institution
- Document relationship-based access control model in Section 5.3

**Reference**: Section 5.1 (API設計 - カルテAPI)

### C5. Missing Appointment Authorization Checks (Elevation of Privilege)

**Issue**: Appointment endpoints (`GET /api/appointments/{id}`, `PUT /api/appointments/{id}`, `DELETE /api/appointments/{id}`) do not specify ownership or relationship verification in the authorization design.

**Impact**: Without explicit authorization checks:
- Patients could view, modify, or cancel other patients' appointments
- Unauthorized access to appointment data reveals patient-doctor relationships and health conditions (診療科)
- Malicious actors could disrupt healthcare services by canceling legitimate appointments

**Countermeasures**:
- Specify authorization rules for each appointment endpoint:
  - `GET /api/appointments/{id}`: Verify patient_id matches requester OR requester is staff at the institution
  - `PUT /api/appointments/{id}`: Verify patient ownership OR DOCTOR/ADMIN role with institution relationship
  - `DELETE /api/appointments/{id}`: Verify patient ownership OR medical staff authorization
- Document these checks explicitly in Section 5.1 and 5.3
- Consider implementing audit logging for all appointment modifications

**Reference**: Section 5.1 (API設計 - 予約API)

## Significant Issues

### S1. Missing Rate Limiting on Authentication Endpoints (Denial of Service)

**Issue**: The design specifies API Gateway rate limiting at 100 requests/minute globally (Section 3.2), but there is no specific rate limiting design for authentication endpoints (`/api/auth/login`, `/api/auth/register`, `/api/auth/refresh`).

**Impact**:
- Brute force attacks on login endpoints could compromise user accounts through password guessing
- Credential stuffing attacks using leaked password databases could succeed
- Account enumeration through registration endpoint abuse
- Token refresh endpoint abuse could bypass authentication controls
Without endpoint-specific rate limiting, attackers have 100 requests/minute to attempt brute force attacks, which is excessive for authentication operations.

**Countermeasures**:
- Implement stricter rate limiting for authentication endpoints:
  - Login: 5 attempts per IP per 15 minutes
  - Registration: 3 attempts per IP per hour
  - Password reset: 3 attempts per email per hour
  - Token refresh: 10 attempts per user per hour
- Add account lockout policy: lock account after 5 failed login attempts for 30 minutes
- Implement CAPTCHA after 3 failed login attempts
- Design IP-based and user-based rate limiting combinations
- Add detailed audit logging for all authentication failures

**Reference**: Section 3.2 (主要コンポーネントの責務と依存関係), Section 5.1 (認証API)

### S2. Insufficient Session Management Design (Spoofing)

**Issue**: While JWT expiration is specified (1 hour access token, 30 days refresh token), there is no design for session invalidation, concurrent session limits, or token revocation mechanisms.

**Impact**:
- Stolen refresh tokens remain valid for 30 days with no revocation capability
- No mechanism to invalidate sessions when password is changed or account is compromised
- No protection against concurrent session abuse (same account used from multiple locations simultaneously)
- Logout functionality (`POST /api/auth/logout`) is listed but implementation is not specified

**Countermeasures**:
- Design token revocation mechanism:
  - Maintain active refresh token registry in Redis
  - Implement token blacklist for immediate revocation
  - Invalidate all tokens on password change
- Implement concurrent session control:
  - Limit users to N active sessions (e.g., 3 devices)
  - Provide session management UI to view and revoke active sessions
- Design logout implementation:
  - Add refresh token to blacklist
  - Clear client-side token storage
  - Optional: invalidate all sessions for "logout everywhere" functionality
- Store session metadata (IP, user agent, last activity) for security monitoring

**Reference**: Section 5.1 (認証API), Section 5.3 (認証・認可方式)

### S3. Sensitive Data Logging (Information Disclosure)

**Issue**: The logging policy states "すべてのAPIリクエスト・レスポンスをINFOレベルでログ出力" and the example log includes "requestBody" (Section 6.2).

**Impact**: Logging all request bodies will capture sensitive patient information including:
- Passwords (in login/registration requests)
- Patient health information (diagnoses, prescriptions, lab results)
- Personal identifiable information (names, addresses, insurance numbers, phone numbers)
This creates HIPAA violations, exposes data to unauthorized personnel with log access, and increases breach risk if logs are compromised.

**Countermeasures**:
- Implement sensitive data filtering in logging:
  - Exclude password fields entirely
  - Mask/redact PII fields (names → "J***n D**", phone → "***-***-1234")
  - Exclude or hash medical data fields (diagnosis, prescription, lab results)
  - Implement field-level allow-list rather than logging all fields
- Design separate audit logging for compliance:
  - Who accessed which patient records (without including record content)
  - Authentication events (success/failure, IP, timestamp)
  - Data modification events (what changed, not the actual content)
- Add log access controls and encryption for stored logs
- Document specific fields to exclude/mask in Section 6.2

**Reference**: Section 6.2 (ロギング方針)

### S4. Missing Input Validation Specification (Injection Attacks)

**Issue**: While the design mentions "Spring Validation" and "PreparedStatement" for SQL injection prevention (Section 7.2), there is no comprehensive input validation policy or specification for validation rules across API endpoints.

**Impact**: Without explicit validation specifications:
- NoSQL injection risks in unvalidated fields (if document stores are added)
- Command injection through file upload paths or external system integration
- Business logic bypass through invalid data (e.g., negative appointment dates)
- XSS vulnerabilities through unsanitized user input in web views
- Path traversal attacks in file upload/download operations

**Countermeasures**:
- Define input validation policy in Section 7.2:
  - Validation approach: allow-list (whitelist) preferred over deny-list
  - Length limits for all string fields (username: 3-50, email: 5-100, etc.)
  - Format validation: email regex, phone number format, date ranges
  - Business rule validation: appointment_time must be future date, within business hours
- Specify validation for each API endpoint:
  - Registration: username pattern, password complexity (min 8 chars, uppercase, lowercase, number, special char)
  - Appointment creation: valid department enum, valid institution_id exists, time slot available
  - Medical record: maximum text length for diagnosis/prescription fields
- Add output encoding specification:
  - HTML escaping for any user content displayed in web views
  - JSON encoding for API responses (already handled by Spring Boot)
- Design file upload validation (even though not explicitly mentioned, S3 storage is specified):
  - File type validation (whitelist: pdf, jpg, png)
  - File size limits (e.g., 10MB max)
  - Virus scanning integration
  - Randomized storage paths to prevent path traversal

**Reference**: Section 7.2 (セキュリティ要件)

### S5. Missing Audit Logging for Critical Operations (Repudiation)

**Issue**: While general API logging is specified, there is no design for security-focused audit logging of critical operations such as authentication failures, authorization failures, data access, or permission changes.

**Impact**: Without comprehensive audit logs:
- Security incidents cannot be properly investigated
- Insider threats (medical staff accessing unauthorized patient records) cannot be detected
- Compliance requirements (HIPAA audit trails) may not be met
- No evidence for forensic analysis in case of data breaches

**Countermeasures**:
- Design comprehensive audit logging for:
  - Authentication events: all login attempts (success/failure), logout, token refresh, password changes
  - Authorization failures: access denied events with user, resource, and action details
  - Sensitive data access: all patient record views, medical record access (who, when, which patient, purpose)
  - Data modifications: patient info updates, medical record creation/updates (before/after values)
  - Administrative actions: user role changes, medical institution additions/deletions
- Implement separate audit log storage:
  - Append-only storage (cannot be modified or deleted by application)
  - Retention policy: minimum 7 years for medical records compliance
  - Consider AWS CloudTrail, dedicated audit database, or immutable log storage
- Design audit log format with required fields:
  - Timestamp, user ID, user role, action type, resource type, resource ID, result (success/failure), IP address, user agent
- Add audit log query API for compliance officers and security team
- Consider real-time alerting for suspicious patterns (multiple authorization failures, unusual access patterns)

**Reference**: Section 6.2 (ロギング方針)

## Moderate Issues

### M1. Missing CORS Policy Specification (Tampering)

**Issue**: The design mentions "CORS/origin control" should be evaluated (Section 4 evaluation criteria) but the actual design document does not specify CORS configuration.

**Impact**: Without proper CORS configuration:
- Vulnerable to unauthorized cross-origin requests from malicious websites
- Potential for CSRF attacks despite JWT authentication
- Risk of data exfiltration through compromised or malicious sites

**Countermeasures**:
- Define explicit CORS policy in Section 7.2 or 3.2:
  - Allow-list specific origins (e.g., https://app.example.com, https://mobile.example.com)
  - Avoid wildcard (*) origins in production
  - Specify allowed methods (GET, POST, PUT, DELETE)
  - Specify allowed headers (Authorization, Content-Type)
  - Set credentials: true only when necessary
- Consider CSRF token implementation as defense-in-depth despite JWT usage
- Document CORS configuration in API Gateway and Spring Boot application

**Reference**: Evaluation criteria mention CORS, but implementation is missing

### M2. Weak Password Hashing Cost Factor (Spoofing)

**Issue**: The design specifies bcrypt with cost factor 10 (Section 7.2: "コスト係数10").

**Impact**: Cost factor 10 is the minimum recommended value from 2010. With modern hardware (GPUs, ASICs), this provides insufficient protection against brute force attacks on compromised password hashes. For a medical system with high-value data, stronger password hashing is warranted.

**Countermeasures**:
- Increase bcrypt cost factor to 12-14 (industry best practice as of 2025)
- Cost factor 12 provides ~16x more computational cost than factor 10
- Balance security with performance:
  - Test authentication latency with higher cost factors
  - Cost factor 13 typically adds <500ms on modern servers
- Consider migration plan: re-hash passwords at higher cost factor on next successful login
- Document chosen cost factor and rationale in Section 7.2

**Reference**: Section 7.2 (セキュリティ要件)

### M3. Missing Secret Management Implementation Details (Information Disclosure)

**Issue**: The deployment section mentions retrieving environment variables from "AWS Systems Manager Parameter Store" (Section 6.4), but there is no specification for what secrets need protection, encryption at rest, access controls, or rotation policies.

**Impact**: Without explicit secret management design:
- Database credentials, JWT signing keys, API keys could be insufficiently protected
- No key rotation policy increases risk from compromised secrets
- Unclear access control could allow unauthorized access to sensitive configuration

**Countermeasures**:
- Specify which secrets require protection:
  - Database connection strings (PostgreSQL, Redis credentials)
  - JWT signing secret key
  - AWS service credentials
  - Third-party API keys (email service, push notification service)
- Design secret management policy:
  - Use AWS Secrets Manager or Parameter Store with encryption
  - Enable automatic rotation for database credentials (30-90 day cycles)
  - Implement JWT key rotation strategy (e.g., multiple valid keys with key ID in JWT header)
  - Use IAM roles for ECS tasks instead of long-lived credentials where possible
- Add access controls:
  - Restrict Parameter Store/Secrets Manager access to specific ECS task roles
  - Enable CloudTrail logging for all secret access
  - Implement least privilege: different secrets for different services
- Document secret management approach in Section 6.4 or 7.2

**Reference**: Section 6.4 (デプロイメント方針)

### M4. Missing Dependency Vulnerability Management (Infrastructure)

**Issue**: While specific library versions are listed (Section 2.4), there is no policy for dependency vulnerability scanning, update management, or security patching.

**Impact**: Known vulnerabilities in dependencies could be exploited:
- Spring Security, Spring Boot, Hibernate, or other libraries may have CVEs
- Outdated React, React Native versions may have client-side vulnerabilities
- No process to respond to security advisories
- Compliance audits may fail without documented vulnerability management

**Countermeasures**:
- Implement dependency scanning in CI/CD pipeline:
  - Add OWASP Dependency-Check or Snyk to GitHub Actions
  - Fail builds on high/critical severity vulnerabilities
  - Generate dependency reports for security review
- Establish dependency update policy:
  - Security patches applied within 7 days of disclosure
  - Regular dependency updates (monthly or quarterly)
  - Test updates in staging before production deployment
- Use dependency management tools:
  - Renovate or Dependabot for automated update PRs
  - Maven Enforcer Plugin to prevent vulnerable version usage
- Monitor security advisories:
  - Subscribe to Spring Security advisories, CVE databases
  - Track React, React Native security announcements
- Document this policy in Section 6.4 or add new section 7.4 (Dependency Management)

**Reference**: Section 2.4 (主要ライブラリ)

### M5. Insufficient Data Protection Specification (Information Disclosure)

**Issue**: The design specifies TLS 1.3 for data in transit and bcrypt for passwords, but does not specify encryption for sensitive data at rest (patient PII, medical records in database) or data classification policies.

**Impact**: If database storage is compromised (snapshot leaks, backup exposure, insider threats):
- Patient names, addresses, phone numbers, insurance numbers are stored in plaintext
- Medical diagnoses, prescriptions, lab results are unencrypted
- Compliance violations (HIPAA requires safeguards for ePHI at rest)
- Higher breach notification requirements and regulatory penalties

**Countermeasures**:
- Define data classification policy:
  - Critical: Medical records (diagnosis, prescription, lab results)
  - High: Patient PII (full_name, date_of_birth, address, insurance_number)
  - Medium: Contact info (email, phone)
  - Low: Public data (medical institution names, departments)
- Implement encryption at rest:
  - Enable PostgreSQL transparent data encryption (TDE) or AWS RDS encryption
  - Consider application-level encryption for most sensitive fields (e.g., diagnosis, prescription)
  - Use AWS KMS for key management with automatic rotation
- Add data retention and deletion policies:
  - Specify retention periods for different data types (medical records: 7-10 years depending on regulations)
  - Implement secure deletion/anonymization after retention period
  - Design patient data export and deletion API for GDPR/privacy compliance
- Document data protection measures in Section 7.2 or create dedicated Section 7.4

**Reference**: Section 7.2 (セキュリティ要件), Section 4 (データモデル)

### M6. Missing Account Enumeration Protection (Information Disclosure)

**Issue**: The registration and authentication endpoints do not specify protection against account enumeration attacks (determining which usernames/emails exist in the system).

**Impact**: Attackers could:
- Enumerate registered patient/doctor emails through registration or password reset endpoints
- Build target lists for phishing attacks against medical staff and patients
- Identify high-value accounts (doctor accounts) for targeted attacks
- Violate patient privacy by confirming patient status at specific institutions

**Countermeasures**:
- Implement generic responses for authentication endpoints:
  - Login failure: "Invalid username or password" (don't reveal which is incorrect)
  - Registration: accept request regardless of existing email, send confirmation only to valid new accounts
  - Password reset: "If this email exists, a reset link has been sent" (same message for existing and non-existing)
- Add timing attack protection:
  - Ensure similar response times for existing vs. non-existing accounts
  - Use constant-time comparison for password checks
  - Add small random delays or processing simulation
- Design rate limiting to slow enumeration:
  - Strict limits on registration and password reset endpoints (mentioned in S1)
- Consider CAPTCHA for registration and password reset to prevent automated enumeration

**Reference**: Section 5.1 (認証API)

## Minor Improvements and Positive Aspects

### Positive: Strong Foundation Security Measures

The design demonstrates several good security practices:
- **TLS 1.3** for encrypted communications (Section 7.2)
- **bcrypt password hashing** instead of plain text or weak algorithms (Section 7.2)
- **JWT-based authentication** with separate access and refresh tokens (Section 5.3)
- **PreparedStatement** for SQL injection prevention (Section 7.2)
- **Spring Security 6.2** usage, a mature security framework (Section 2.4)
- **API Gateway rate limiting** provides basic DoS protection (Section 3.2)
- **Spring Validation** mentioned for input validation (Section 7.2)
- **Multi-AZ database** for availability (Section 7.3)

### Minor Improvement I1: Token Expiration Policy Refinement

**Observation**: 30-day refresh token lifetime (Section 5.3) is quite long for a medical application handling sensitive data.

**Recommendation**: Consider shorter refresh token lifetime (7-14 days) with automatic renewal on active use, or implement step-up authentication for sensitive operations (e.g., viewing medical records requires re-authentication if session is older than 1 hour).

### Minor Improvement I2: Security Headers

**Observation**: No mention of security HTTP headers in the design.

**Recommendation**: Add security headers specification:
- Content-Security-Policy
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- Strict-Transport-Security: max-age=31536000; includeSubDomains
- Referrer-Policy: no-referrer or strict-origin-when-cross-origin

### Minor Improvement I3: Database Security Hardening

**Observation**: Database security beyond Multi-AZ is not specified.

**Recommendation**: Add database security measures:
- Network isolation (VPC, private subnets)
- Minimal privilege database users (separate read-only vs. read-write credentials)
- Database connection encryption
- Database audit logging for DDL changes
- Regular security patching schedule for PostgreSQL

### Minor Improvement I4: Monitoring and Alerting

**Observation**: No security monitoring or alerting design mentioned.

**Recommendation**: Design security monitoring:
- Failed authentication rate alerts
- Unusual data access patterns (e.g., doctor accessing 100+ patient records in 1 hour)
- Geographic anomaly detection (login from unusual location)
- Privilege escalation attempts
- Integration with AWS GuardDuty, CloudWatch Alarms

## Summary

This medical appointment system design has a reasonable security foundation with TLS, bcrypt, JWT, and Spring Security, but contains **5 critical issues** requiring immediate attention before implementation:

**Critical priorities**:
1. Change JWT storage from localStorage to httpOnly cookies (C1)
2. Remove stack traces from production error responses (C2)
3. Design explicit authorization checks for all patient data, medical records, and appointment endpoints (C3, C4, C5)

**Significant priorities**:
1. Add endpoint-specific rate limiting for authentication (S1)
2. Design session management and token revocation (S2)
3. Implement sensitive data filtering in logs (S3)
4. Specify comprehensive input validation (S4)
5. Design audit logging for compliance (S5)

The moderate and minor issues should be addressed during detailed design phase before development begins. Special attention is needed to HIPAA/privacy compliance requirements given the healthcare context.
