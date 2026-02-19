# Security Design Review: Real-time Medical Reservation System

## Critical Issues

### C1. Sensitive Data Exposure in Error Responses and Logs (Information Disclosure)
**Severity: Critical**

**Problem:**
- Section 6.1 specifies including detailed stack traces in error responses: "エラーメッセージには詳細なスタックトレースを含め、デバッグを容易にする"
- Section 6.2 logs all API request/response bodies at INFO level, including potentially sensitive medical data
- Example log format shows `requestBody: "{...}"` being logged for all requests

**Impact:**
- Stack traces may expose internal implementation details, database structure, and file paths to attackers
- Logging request bodies could expose PII (patient names, addresses, insurance numbers) and PHI (medical records, diagnoses) in plaintext logs
- Attackers can use error messages to map system internals and plan targeted attacks
- Violates healthcare privacy regulations (HIPAA, GDPR for medical data)

**Countermeasures:**
1. Remove stack traces from production error responses; log them server-side only
2. Implement PII/PHI redaction in logging system before writing to CloudWatch
3. Use sanitized error messages for clients (e.g., "Internal Server Error" instead of detailed exceptions)
4. Apply field-level masking for sensitive data in audit logs (e.g., mask insurance_number, phone_number)
5. Restrict access to production logs to authorized personnel only with audit trails

**Reference:** Sections 6.1, 6.2

---

### C2. JWT Token Storage in localStorage (Spoofing/Information Disclosure)
**Severity: Critical**

**Problem:**
Section 5.3 specifies storing JWT tokens in localStorage: "JWTトークンはlocalStorageに保存し"

**Impact:**
- Tokens stored in localStorage are vulnerable to XSS attacks - any JavaScript code injection can steal tokens
- Compromised tokens allow attackers to impersonate users and access medical records
- No protection against token theft via malicious browser extensions or XSS vulnerabilities
- Session hijacking becomes trivial once XSS vulnerability exists

**Countermeasures:**
1. Store tokens in httpOnly, secure, SameSite cookies instead of localStorage
2. Implement CSRF protection tokens for state-changing operations
3. Use short-lived access tokens (15 minutes) with httpOnly refresh tokens
4. Implement token binding to prevent token replay attacks
5. Add Content Security Policy (CSP) headers to mitigate XSS risks

**Reference:** Section 5.3

---

### C3. Missing Authorization Checks for Resource Access (Elevation of Privilege)
**Severity: Critical**

**Problem:**
API endpoints lack explicit authorization verification design beyond JWT validation. No ownership/tenant isolation checks are specified for:
- `/api/patients/{id}` - Any authenticated user could access other patients' data
- `/api/appointments/{id}` - No verification that user owns the appointment
- `/api/records/{id}` - Medical records accessible without ownership validation
- `/api/patients/{id}/records` - Patient history accessible across tenant boundaries

**Impact:**
- Horizontal privilege escalation: Patient A can access Patient B's medical records by changing ID parameter
- Medical staff at Institution A can access records from Institution B
- Unauthorized access to diagnosis, prescription, and lab results
- Massive HIPAA/privacy violation with potential legal consequences

**Countermeasures:**
1. For patient endpoints: Verify `patient.user_id == currentUser.id` or `currentUser.role == DOCTOR && patient.institution_id == currentUser.institution_id`
2. For appointment endpoints: Check `appointment.patient_id == currentUser.patient_id` or staff membership
3. For medical records: Enforce strict access control - only owning patient or treating physician can access
4. Implement tenant isolation checks for all cross-institution operations
5. Add authorization unit tests covering all access control paths

**Reference:** Section 5.1 (API endpoints)

---

### C4. No Rate Limiting for Authentication Endpoints (Denial of Service/Spoofing)
**Severity: Critical**

**Problem:**
- Section 3.2 specifies API Gateway rate limit of 100 requests/minute globally
- No specific rate limiting design for authentication endpoints (`/api/auth/login`, `/api/auth/register`, `/api/auth/refresh`)
- No brute-force protection mechanisms mentioned (account lockout, CAPTCHA, progressive delays)
- No authentication failure monitoring or alerting designed

**Impact:**
- Credential stuffing attacks can test thousands of stolen username/password combinations
- Brute-force attacks on patient accounts to access medical records
- Account enumeration via registration endpoint timing differences
- DoS on authentication service by exhausting JWT generation resources
- Global rate limit (100/min) insufficient for targeted auth attacks

**Countermeasures:**
1. Implement strict rate limiting for auth endpoints: 5 login attempts per username per 15 minutes
2. Add progressive delays after failed login attempts (exponential backoff)
3. Implement account lockout after 5 consecutive failures with email notification
4. Add CAPTCHA after 3 failed attempts
5. Monitor and alert on authentication anomalies (multiple failures, credential stuffing patterns)
6. Use time-constant comparison for credential validation to prevent timing attacks

**Reference:** Sections 3.2, 5.1

---

## Significant Issues

### S1. Missing Data Classification and Encryption at Rest Policy (Information Disclosure)
**Severity: Significant**

**Problem:**
- No explicit PII/PHI classification policy defined
- No data classification levels specified (public, internal, confidential, restricted)
- Section 7.2 mentions TLS 1.3 for data in transit but no encryption at rest for database
- No key management design for sensitive data fields

**Impact:**
- Database compromise exposes all medical records, insurance numbers, addresses in plaintext
- Unclear which fields require encryption vs hashing vs plaintext storage
- Compliance risk with healthcare regulations requiring data-at-rest encryption
- Backup files may contain unencrypted PHI

**Countermeasures:**
1. Define PII/PHI classification policy: diagnosis, prescription, lab_results, insurance_number as "Restricted PHI"
2. Enable PostgreSQL transparent data encryption (TDE) or AWS RDS encryption at rest
3. Implement application-layer encryption for highly sensitive fields using AWS KMS
4. Design key rotation policies and access controls for encryption keys
5. Ensure backup encryption with separate encryption keys

**Reference:** Sections 4.2, 7.2

---

### S2. No Data Retention and Deletion Policy (Information Disclosure/Repudiation)
**Severity: Significant**

**Problem:**
- Section 7.3 specifies database backups retained for 30 days, but no data retention policy for production data
- No documented data lifecycle management (archival, deletion procedures)
- No automated deletion policies for expired appointments or inactive accounts
- No right-to-be-forgotten implementation for GDPR compliance

**Impact:**
- Indefinite retention of medical records increases attack surface
- Privacy regulation violations (GDPR right to erasure, HIPAA minimum necessary principle)
- Increased storage costs and backup complexity
- No mechanism to fulfill patient data deletion requests

**Countermeasures:**
1. Define retention periods: active medical records (7 years), cancelled appointments (1 year), inactive accounts (3 years)
2. Implement automated archival process for aged records to separate cold storage
3. Design soft-delete mechanism with audit trail for data deletion requests
4. Create data deletion API for GDPR compliance with verification workflow
5. Document data lifecycle: collection → storage → archival (encrypted, separate DB) → deletion

**Reference:** Section 7.3

---

### S3. No Data Integrity Verification Mechanisms (Tampering)
**Severity: Significant**

**Problem:**
- No explicit design for data integrity verification (checksums, digital signatures, hash verification)
- Critical medical data (diagnosis, prescription, lab_results) have no tamper detection
- No audit trail for medical record modifications
- No mechanism to detect unauthorized database modifications

**Impact:**
- Medical records could be altered without detection, leading to incorrect treatment
- Prescription tampering could result in dangerous medication errors
- No forensic capability to detect insider attacks or database compromises
- Legal liability if tampered records are used for medical decisions

**Countermeasures:**
1. Add `record_hash` column to medical_records table containing SHA-256 hash of (diagnosis + prescription + lab_results + doctor_name + created_at)
2. Implement digital signatures for critical records using doctor's private key
3. Add `updated_at` and `updated_by` audit columns with triggers preventing retroactive changes
4. Design tamper detection scheduled job comparing current hashes with stored hashes
5. Create immutable audit log (separate append-only table) for all medical record access/modifications

**Reference:** Section 4.2 (medical_records table)

---

### S4. Insufficient Input Validation Design (Injection Attacks)
**Severity: Significant**

**Problem:**
- Section 7.2 mentions Spring Validation and PreparedStatement usage but lacks specific validation rules
- No validation design for:
  - Email format, phone number format
  - Date ranges (appointment_time must be future, date_of_birth must be past)
  - Text field length limits (diagnosis, prescription can be unlimited TEXT)
  - File upload restrictions for potential document attachments
- No protection against NoSQL injection in potential Redis cache queries

**Impact:**
- Malformed data in database causing application errors
- Potential injection attacks if PreparedStatement not consistently used
- Resource exhaustion via unlimited text fields
- Malicious file uploads if feature added later without design consideration

**Countermeasures:**
1. Define comprehensive validation rules:
   - Email: RFC 5322 format validation
   - Phone: E.164 international format
   - Dates: appointment_time > now, date_of_birth < now && > 150 years ago
   - Text fields: diagnosis/prescription max 10,000 characters
2. Implement parameterized queries for all database operations with code review enforcement
3. Add input sanitization layer before validation (trim whitespace, normalize encoding)
4. Design file upload restrictions: whitelist allowed MIME types, max size 10MB, antivirus scanning
5. Use Redis command whitelisting and avoid dynamic command construction

**Reference:** Sections 5.2, 7.2

---

### S5. Missing CORS and Origin Control Design (Cross-Site Attacks)
**Severity: Significant**

**Problem:**
No CORS policy, origin validation, or CSRF protection explicitly designed in the architecture.

**Impact:**
- Malicious websites can make unauthorized requests on behalf of authenticated users
- CSRF attacks can trigger appointment cancellations or data modifications
- Cross-origin data exfiltration if CORS misconfigured

**Countermeasures:**
1. Configure CORS to allow only trusted origins (production domains)
2. Implement CSRF tokens for all state-changing operations (POST, PUT, DELETE)
3. Use SameSite cookie attribute for session cookies
4. Validate Origin and Referer headers for sensitive operations
5. Implement anti-CSRF tokens in Spring Security configuration

**Reference:** Section 5.1

---

## Moderate Issues

### M1. Weak Session Management Design (Spoofing)
**Severity: Moderate**

**Problem:**
- JWT expiration (1 hour access, 30 days refresh) specified but no session invalidation mechanism
- No design for logout implementation - Section 5.1 lists `/api/auth/logout` endpoint but no backend logic
- No token revocation strategy for compromised tokens
- No concurrent session limit per user

**Impact:**
- Stolen refresh tokens remain valid for 30 days even after user logout
- No way to invalidate compromised tokens before expiration
- Users cannot remotely logout from other devices
- Account sharing cannot be detected or prevented

**Countermeasures:**
1. Implement Redis-based token blacklist for logout operations
2. Store active refresh tokens with user_id mapping in Redis with TTL
3. Design token revocation endpoint for emergency token invalidation
4. Add device tracking and "logout from all devices" functionality
5. Implement concurrent session limit (max 3 devices) with forced logout of oldest session

**Reference:** Section 5.3

---

### M2. No Secret Management Design Beyond Parameter Store (Information Disclosure)
**Severity: Moderate**

**Problem:**
- Section 6.4 mentions AWS Systems Manager Parameter Store but no detailed secret management design
- No specification of:
  - JWT signing key rotation policy
  - Database credential rotation
  - Encryption key management for sensitive data
  - Secret access control and audit logging

**Impact:**
- Compromised signing keys require manual intervention and system downtime
- Long-lived secrets increase window of compromise
- No audit trail for secret access
- Developer access to production secrets not controlled

**Countermeasures:**
1. Use AWS Secrets Manager instead of Parameter Store for automatic rotation
2. Implement JWT signing key rotation every 90 days with dual-key verification period
3. Enable RDS automatic credential rotation
4. Configure IAM policies for least-privilege secret access with CloudTrail logging
5. Use separate encryption keys per environment with KMS key rotation enabled

**Reference:** Section 6.4

---

### M3. Insufficient Audit Logging for Security Events (Repudiation)
**Severity: Moderate**

**Problem:**
- Section 6.2 logs all requests but no specific security audit logging design
- Critical security events not explicitly logged:
  - Authentication failures with source IP
  - Authorization failures (403 errors)
  - Medical record access attempts (both successful and failed)
  - Administrative actions (user role changes, medical institution registration)
  - Data deletion requests

**Impact:**
- Cannot detect ongoing attacks or brute-force attempts
- No forensic capability for security incident investigation
- Insider threats (medical staff accessing unauthorized records) go undetected
- Compliance violations for audit trail requirements

**Countermeasures:**
1. Implement dedicated security audit log stream separate from application logs
2. Log all authentication failures with: username, source IP, timestamp, user agent, failure reason
3. Log all medical record access with: accessor user_id, patient_id, record_id, access timestamp, operation type
4. Alert on anomalies: 5+ auth failures in 1 minute, mass record access (>50 records in 1 hour)
5. Design immutable audit log storage with restricted access and retention policy (7 years for medical data access logs)

**Reference:** Section 6.2

---

### M4. No Dependency Vulnerability Management Policy (Infrastructure Security)
**Severity: Moderate**

**Problem:**
- Section 2.4 lists major libraries but no vulnerability scanning or update policy
- No design for monitoring security advisories for:
  - Spring Boot, Spring Security, Hibernate
  - Frontend libraries (React, React Native)
  - Base Docker images
  - Database versions

**Impact:**
- Known vulnerabilities in dependencies remain unpatched
- Zero-day exploits in popular frameworks (e.g., Spring4Shell) could compromise system
- No process to rapidly deploy security patches
- Outdated libraries accumulate over time

**Countermeasures:**
1. Integrate dependency scanning tools in CI pipeline (OWASP Dependency-Check, Snyk)
2. Configure automated PR creation for dependency updates (Dependabot)
3. Establish SLA for patching: critical vulnerabilities within 24 hours, high within 7 days
4. Subscribe to security advisories for all major dependencies
5. Design emergency hotfix deployment process bypassing standard release cycle

**Reference:** Sections 2.1, 2.4

---

## Minor Improvements

### I1. Password Complexity Policy Not Specified
Section 5.2 shows example password "SecurePass123!" but no password complexity requirements defined (minimum length, character requirements, password history, expiration).

**Recommendation:** Define password policy: minimum 12 characters, require uppercase + lowercase + digit + special character, prevent reuse of last 5 passwords, no forced expiration (NIST SP 800-63B compliance).

---

### I2. No Multi-Factor Authentication Design
High-risk medical system lacks MFA design for privileged accounts (doctors, administrators).

**Recommendation:** Design TOTP-based MFA for DOCTOR and ADMIN roles, with backup codes and account recovery process.

---

### I3. No Protection Against Automated Bot Attacks
Registration and appointment creation endpoints lack bot protection.

**Recommendation:** Implement CAPTCHA or invisible reCAPTCHA for public-facing endpoints (registration, appointment creation).

---

## Positive Aspects

1. **TLS 1.3 encryption** for data in transit is specified (Section 7.2)
2. **bcrypt password hashing** with appropriate cost factor (10) implemented (Section 7.2)
3. **JWT-based authentication** provides stateless scalability (Section 5.3)
4. **PreparedStatement usage** for SQL injection prevention mentioned (Section 7.2)
5. **Multi-AZ database** configuration provides high availability (Section 7.3)
6. **Structured logging** with JSON format enables security monitoring (Section 6.2)

---

## Summary

This medical reservation system design has **4 critical security flaws** that must be addressed before implementation:
1. Sensitive data exposure through error messages and request/response logging
2. Insecure JWT storage in localStorage vulnerable to XSS
3. Missing authorization checks enabling unauthorized medical record access
4. Insufficient authentication endpoint protection against brute-force attacks

The design also lacks essential security controls for healthcare systems: data classification policies, retention/deletion procedures, data integrity verification, and comprehensive audit logging.

**Immediate Actions Required:**
1. Redesign token storage using httpOnly cookies
2. Implement resource ownership authorization checks in all endpoints
3. Remove sensitive data from error responses and implement PII/PHI redaction in logs
4. Add authentication-specific rate limiting and brute-force protection
5. Design data classification, retention, and integrity verification mechanisms

Without addressing these critical issues, the system poses significant risk of unauthorized access to medical records and privacy regulation violations.
