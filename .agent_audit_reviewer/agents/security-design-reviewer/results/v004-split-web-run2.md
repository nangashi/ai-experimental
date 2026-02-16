# Security Design Review: Real-time Medical Appointment System

## Critical Issues

### C1. Missing Authorization Verification on Resource Access Endpoints

**Issue:** The API design (Section 5.1) defines multiple resource access endpoints (`GET /api/patients/{id}`, `GET /api/patients/{id}/records`, `GET /api/records/{id}`) without explicitly specifying ownership or permission verification mechanisms. The authorization model only mentions role-based access control (Section 5.3), but does not detail how to prevent horizontal privilege escalation where a patient could access another patient's medical records.

**Impact:** An attacker could enumerate patient IDs and access sensitive medical information of other patients by simply modifying the ID parameter in API requests. This constitutes a critical data breach risk given the sensitivity of medical records containing personal health information (PHI).

**Countermeasures:**
- Explicitly design ownership verification: For `GET /api/patients/{id}` and `GET /api/patients/{id}/records`, verify that the authenticated user's patient ID matches the requested ID, or that the user has DOCTOR/ADMIN role with legitimate access reason
- For `GET /api/records/{id}`, implement a join query to verify that the requesting user is either the patient associated with that record or an authorized medical staff member at the institution
- Document these authorization checks in the API specification with pseudocode or security annotations
- Implement audit logging for all medical record access attempts

**Reference:** Section 5.1 (API endpoints), Section 4.2 (table design), Evaluation Criteria 2 - API Endpoint Authorization Checklist

### C2. JWT Token Storage in localStorage Exposes XSS Attack Surface

**Issue:** Section 5.3 explicitly states "JWTトークンはlocalStorageに保存し" (JWT tokens are stored in localStorage). This design choice makes the authentication token vulnerable to theft via Cross-Site Scripting (XSS) attacks, as any malicious JavaScript code can read localStorage contents.

**Impact:** If an XSS vulnerability exists anywhere in the React SPA frontend, attackers can steal authentication tokens and impersonate users, including medical staff with access to sensitive patient data. Given that this is a medical system handling protected health information, token theft could lead to unauthorized prescription modifications, medical record tampering, or identity theft.

**Countermeasures:**
- Store JWT tokens in httpOnly cookies instead of localStorage. This prevents JavaScript access while maintaining session persistence
- Implement SameSite=Strict or SameSite=Lax cookie attribute to mitigate CSRF risks
- Add explicit XSS prevention measures: Content Security Policy (CSP) headers, input sanitization using DOMPurify for any user-generated content rendering
- Consider shorter token expiration times (e.g., 15 minutes instead of 1 hour) with transparent refresh mechanism

**Reference:** Section 5.3 (Authentication method), Evaluation Criteria 4 - Web Security Controls

### C3. Missing CSRF Protection Design for State-Changing APIs

**Issue:** The design document does not mention CSRF (Cross-Site Request Forgery) protection mechanisms for state-changing endpoints such as `POST /api/appointments`, `PUT /api/appointments/{id}`, `DELETE /api/appointments/{id}`, `POST /api/records`, and `PUT /api/records/{id}`. With JWT stored in localStorage (Section 5.3), the application relies on JavaScript to attach tokens to requests, but the document does not explicitly verify that only same-origin requests can trigger these operations.

**Impact:** An attacker could craft a malicious website that tricks authenticated users into executing unwanted actions (e.g., canceling appointments, creating fraudulent medical records) without their knowledge. This is particularly severe in medical contexts where appointment cancellations could delay critical care or fraudulent records could lead to incorrect treatment decisions.

**Countermeasures:**
- Explicitly design CSRF token generation and validation for all POST/PUT/DELETE endpoints
- Alternative: If migrating to httpOnly cookies, implement SameSite cookie attributes and verify Origin/Referer headers
- Document CSRF protection strategy in Section 7.2 (Security Requirements)
- Implement double-submit cookie pattern or synchronizer token pattern

**Reference:** Section 5.1 (API endpoints), Evaluation Criteria 4 - CSRF/CORS Checklist

## Significant Issues

### S1. Missing CORS Configuration Specification

**Issue:** While the architecture describes API Gateway (Section 3.2) and cross-origin communication is implied by the React SPA + React Native clients, the document does not specify allowed origins for CORS configuration. This omission creates risk of overly permissive wildcard configuration (`Access-Control-Allow-Origin: *`) being deployed.

**Impact:** Overly permissive CORS allows malicious websites to make authenticated API requests on behalf of users, potentially leading to data exfiltration or unauthorized operations. Given that credentialed requests are used (JWT in Authorization header), wildcard CORS would be particularly dangerous.

**Countermeasures:**
- Explicitly specify allowed origins in the design document (e.g., https://medical-app.example.com, mobile app deep links)
- Document CORS configuration policy in Section 3.1 or Section 7.2
- Ensure `Access-Control-Allow-Credentials: true` is only used with specific origin lists
- Implement origin validation at API Gateway level

**Reference:** Section 3.1 (Architecture), Evaluation Criteria 4 - CSRF/CORS Checklist

### S2. Missing Rate Limiting on Authentication Endpoints

**Issue:** Section 3.2 mentions rate limiting at API Gateway level (100 requests/minute), but this global limit is insufficient to prevent brute force attacks on authentication endpoints. The document does not specify stricter rate limits for `POST /api/auth/login`, `POST /api/auth/register`, or `POST /api/auth/refresh` (Section 5.1).

**Impact:** Attackers can perform credential stuffing attacks or brute force password guessing against patient and medical staff accounts. A successful breach could expose thousands of medical records or allow unauthorized prescription modifications.

**Countermeasures:**
- Implement stricter rate limiting for authentication endpoints: maximum 5 login attempts per IP per 15 minutes, 10 registration attempts per IP per hour
- Add per-account rate limiting: lock account temporarily after 5 failed login attempts within 30 minutes
- Implement CAPTCHA after 3 failed login attempts
- Add account enumeration protection: return identical responses for valid/invalid usernames
- Document these protections in Section 7.2 (Security Requirements)

**Reference:** Section 3.2 (API Gateway), Section 5.1 (Authentication API), Evaluation Criteria 4 - Authentication Endpoint Protection Checklist

### S3. Insufficient Audit Logging Design for Critical Operations

**Issue:** Section 6.2 describes general logging of API requests/responses, but does not explicitly design security audit logs for critical operations such as authentication failures, permission changes, medical record access/modifications, or appointment cancellations. The current design logs "すべてのAPIリクエスト・レスポンス" (all API requests/responses) at INFO level without distinguishing security-relevant events.

**Impact:** Without dedicated audit logs, security incidents cannot be effectively investigated. In a healthcare context, this violates HIPAA audit trail requirements and prevents detection of insider threats, unauthorized access patterns, or data breaches.

**Countermeasures:**
- Design dedicated security audit log stream separate from application logs
- Explicitly log: all authentication attempts (success/failure with timestamp, IP, user agent), medical record access (who accessed which patient's record when), permission/role changes, appointment cancellations/modifications
- Include immutable audit log storage with tamper-evident properties (e.g., append-only S3 bucket with object lock)
- Define log retention period aligned with healthcare regulations (minimum 6 years for medical records access logs)
- Document audit logging requirements in Section 7.2

**Reference:** Section 6.2 (Logging policy), Evaluation Criteria 5 - Security audit logging

### S4. Missing File Upload Security Controls

**Issue:** The architecture mentions "Amazon S3（画像・ドキュメント）" (images and documents in S3, Section 2.3) but the design does not specify security controls for file uploads, such as which endpoints accept files, what file types are allowed, size limits, or malware scanning.

**Impact:** Uncontrolled file uploads could enable malicious file execution, storage exhaustion attacks, or distribution of malware through the medical platform. Medical staff downloading infected files could compromise their workstations and the broader hospital network.

**Countermeasures:**
- Explicitly design file upload endpoints (e.g., `POST /api/attachments`)
- Specify whitelist of allowed MIME types (PDF, JPEG, PNG) and reject executable files
- Implement file size limits (e.g., 10MB per file, 50MB per patient)
- Design virus scanning integration (e.g., AWS Lambda with ClamAV before storing in S3)
- Store uploaded files in isolated S3 bucket with separate domain to prevent same-origin attacks
- Generate random filenames to prevent path traversal
- Document these controls in Section 5 (API design) and Section 7.2

**Reference:** Section 2.3 (Infrastructure), Evaluation Criteria 4 - CSRF/CORS Checklist (file upload restrictions)

## Moderate Issues

### M1. Weak Password Policy Specification

**Issue:** The design specifies bcrypt hashing with cost factor 10 (Section 7.2) but does not define password complexity requirements (minimum length, character classes, prohibition of common passwords). The example password in Section 5.2 ("SecurePass123!") suggests complexity requirements exist, but they are not formally documented.

**Impact:** Weak passwords combined with insufficient rate limiting (see S2) increase the risk of successful brute force attacks. Medical accounts could be compromised, leading to unauthorized data access.

**Countermeasures:**
- Document explicit password policy: minimum 12 characters, require uppercase, lowercase, digit, and special character
- Implement password strength validation at registration/password reset
- Prohibit common passwords using a dictionary check (e.g., top 10,000 common passwords)
- Enforce password history (prevent reuse of last 5 passwords)
- Add these requirements to Section 7.2

**Reference:** Section 7.2 (Security requirements), Section 5.2 (API examples)

### M2. Sensitive Data Exposure in Error Messages and Logs

**Issue:** Section 6.1 states "エラーメッセージには詳細なスタックトレースを含め、デバッグを容易にする" (include detailed stack traces in error messages for easier debugging), and Section 6.2 shows logging example including full requestBody. These practices risk exposing sensitive data in error responses and log files.

**Impact:** Stack traces could reveal internal implementation details aiding attackers. Logging full request bodies could inadvertently log passwords, insurance numbers, or medical diagnosis information, creating compliance issues with data protection regulations.

**Countermeasures:**
- Modify error handling policy: return detailed stack traces only in development environments; production should return generic error messages
- Implement log sanitization: redact sensitive fields (password, insurance_number, diagnosis, prescription) before logging
- Add structured logging with field-level control rather than logging entire request/response objects
- Document sanitization policy in Section 6.2

**Reference:** Section 6.1 (Error handling), Section 6.2 (Logging), Evaluation Criteria 3 - Data Protection

### M3. Missing Secret Management Design for Database Credentials and JWT Signing Keys

**Issue:** Section 6.4 mentions "環境変数はECS Task Definitionに記載し、AWS Systems Manager Parameter Storeから取得" (environment variables retrieved from Parameter Store), but does not specify which secrets are managed this way or whether encryption at rest is used. Critical secrets like database passwords and JWT signing keys are not explicitly identified.

**Impact:** If JWT signing keys are compromised, attackers can forge arbitrary tokens and impersonate any user. If database credentials leak through logs or misconfigured Task Definitions, the entire database could be compromised.

**Countermeasures:**
- Explicitly list managed secrets: database password, JWT signing key, Redis connection string, AWS S3 credentials
- Design key rotation schedule (e.g., JWT signing key rotation every 90 days with dual-key overlap period)
- Use AWS Secrets Manager with automatic rotation instead of Parameter Store for database credentials
- Document secret management architecture in Section 6.4 or new Section 7.2 subsection

**Reference:** Section 6.4 (Deployment policy), Evaluation Criteria 5 - Secret management

### M4. Insufficient Session Management Design

**Issue:** Section 5.3 specifies JWT expiration (1 hour) and refresh token duration (30 days) but does not describe logout mechanism behavior, session revocation on password reset, or concurrent session limits. `POST /api/auth/logout` endpoint exists (Section 5.1) but its implementation is not detailed.

**Impact:** Long-lived refresh tokens without revocation capability could remain valid even after user logs out or password change, allowing prolonged unauthorized access if tokens are stolen. Multiple concurrent sessions could indicate account compromise but won't be detected.

**Countermeasures:**
- Design logout implementation: invalidate refresh token by storing token ID in Redis blacklist with TTL matching refresh token expiration
- Implement "logout from all devices" functionality by storing per-user token family ID and incrementing on password reset
- Add concurrent session limit for medical staff accounts (e.g., maximum 3 active sessions)
- Document session management in Section 5.3

**Reference:** Section 5.3 (Authentication), Section 5.1 (Logout endpoint), Evaluation Criteria 2 - Session management

### M5. Missing Data Retention and Deletion Policy

**Issue:** While Section 4.1 mentions various entities containing personal health information (Patient, MedicalRecord), the design does not specify data retention periods or deletion procedures when patients request account closure or after legal retention requirements expire.

**Impact:** Indefinite retention of medical data increases privacy risk and may violate GDPR/HIPAA right-to-erasure requirements. Lack of secure deletion procedures could leave sensitive data recoverable after account deletion.

**Countermeasures:**
- Define retention periods: medical records (minimum 7 years per legal requirement), appointment records (3 years), user activity logs (1 year)
- Design soft delete mechanism with grace period before permanent deletion
- Implement cascading deletion or anonymization workflow for patient data removal
- Document retention policy in new Section 7.4 (Data Governance)

**Reference:** Section 4 (Data model), Evaluation Criteria 3 - Data protection (retention periods)

## Minor Improvements

### I1. Consider Implementing SQL Injection Defense Beyond PreparedStatement

**Positive Aspect:** Section 7.2 mentions using PreparedStatement for SQL injection prevention, which is appropriate.

**Recommendation:** Additionally consider implementing database user privilege separation (application uses read/write user with no DDL permissions) and query result limiting to mitigate potential injection impact. Document these layered defenses.

### I2. Add Dependency Vulnerability Management Policy

**Issue:** Section 2.4 lists specific library versions but the design does not describe vulnerability management processes for third-party dependencies.

**Recommendation:** Document policy for dependency updates: automated vulnerability scanning with Dependabot/Snyk, monthly review cycle for non-critical updates, emergency patching process for critical CVEs. Add to Section 6 or Section 7.

### I3. Consider Implementing Tenant Isolation Enforcement

**Issue:** While the system manages multiple medical institutions (Section 4.1 - MedicalInstitution entity), the design does not explicitly address tenant isolation to prevent cross-institution data access.

**Recommendation:** Design row-level security policy ensuring medical staff from one institution cannot access patients/appointments from another institution. Add institution_id to session context and enforce in all queries.

### I4. Document Encryption Standards for Data at Rest

**Positive Aspect:** Section 7.2 mentions TLS 1.3 for data in transit.

**Recommendation:** Explicitly specify encryption for data at rest: RDS encryption using AWS-managed keys for database, S3 bucket encryption with KMS for documents. Document key management responsibilities.

## Summary

This medical appointment system design has several critical security gaps that must be addressed before implementation:

**Most Critical:**
1. Missing authorization checks on patient data access endpoints (horizontal privilege escalation risk)
2. JWT storage in localStorage creating XSS vulnerability
3. No CSRF protection for state-changing operations

**Immediate Actions Required:**
- Redesign authentication token storage mechanism (httpOnly cookies)
- Explicitly specify authorization verification for all resource access endpoints
- Add CSRF protection design
- Specify CORS configuration with explicit origin whitelist
- Design comprehensive security audit logging for medical record access
- Implement authentication endpoint rate limiting

The document demonstrates awareness of basic security practices (bcrypt, TLS, PreparedStatement) but lacks detailed security architecture for authorization, session management, and audit logging—critical requirements for healthcare systems handling protected health information. Addressing these gaps is essential for regulatory compliance and patient data protection.
