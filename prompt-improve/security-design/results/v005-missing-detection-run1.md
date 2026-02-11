# Security Design Review: オンライン診療予約・電子カルテ統合プラットフォーム

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple critical threats not addressed: no session invalidation (Spoofing), missing audit logging (Repudiation), no DoS protection design (DoS) |
| Authentication & Authorization Design | 2 | JWT stored in unspecified location with 24-hour expiration poses XSS/theft risk, no token rotation or refresh token design, no MFA for high-privilege accounts |
| Data Protection | 3 | AES-256 encryption mentioned but key management strategy completely missing, no backup encryption policy, insufficient data retention/deletion policy |
| Input Validation Design | 2 | No input validation policy defined, no SQL injection prevention measures specified, file upload security not designed despite medical image storage |
| Infrastructure & Dependencies | 3 | Using specific library versions (jjwt 0.11) but no vulnerability scanning process, AWS secret management not designed, no network segmentation policy |
| **Overall** | **2.4** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Storage and Session Management Security Gap

**Problem**: The design specifies 24-hour JWT token expiration (Section 3) but does not specify where tokens are stored (localStorage/sessionStorage/cookies), lacks token rotation mechanism, and has no session invalidation design.

**Impact**:
- If tokens are stored in localStorage (common React pattern), they are vulnerable to XSS attacks
- 24-hour expiration means stolen tokens remain valid for a full day, enabling prolonged unauthorized access to medical records
- No logout mechanism or token revocation means compromised tokens cannot be invalidated
- No refresh token design means users must re-authenticate every 24 hours or accept long-lived tokens

**Recommended Countermeasures**:
1. **Token Storage**: Use HttpOnly + Secure + SameSite=Strict cookies instead of localStorage
2. **Token Lifetime**: Reduce access token to 15 minutes, implement refresh token (7-day expiration with rotation)
3. **Session Invalidation**: Add `POST /api/v1/auth/logout` endpoint that blacklists tokens in Redis (with TTL matching token expiration)
4. **Token Rotation**: Implement refresh token rotation (issue new refresh token on each refresh, invalidate old one)

**Relevant Sections**: Section 3 (Data Flow), Section 5 (Authentication API)

---

### 1.2 Missing Audit Logging for Medical Record Access

**Problem**: No audit logging design for access to medical records (`medical_records` table), which is a legal requirement under most healthcare regulations (HIPAA, GDPR for health data).

**Impact**:
- Cannot detect unauthorized access to patient medical records
- Cannot comply with regulatory requirements for access audit trails
- No evidence for forensic investigation in case of data breach
- Violates non-repudiation principle (cannot prove who accessed what data when)

**Recommended Countermeasures**:
1. **Audit Log Table**: Create `audit_logs` table with columns:
   - `id`, `user_id`, `user_role`, `resource_type`, `resource_id`, `action` (read/create/update/delete), `ip_address`, `timestamp`, `result` (success/failure)
2. **Automatic Logging**: Implement AOP (Aspect-Oriented Programming) interceptor for all medical record endpoints to automatically log access
3. **Log Retention**: Store audit logs for minimum 7 years (typical healthcare regulation requirement), separate from operational logs
4. **Immutability**: Design audit logs as append-only (no UPDATE/DELETE permissions for application users)

**Relevant Sections**: Section 4 (Data Model), Section 5 (Medical Records API)

---

### 1.3 Missing Key Management Strategy for Data Encryption

**Problem**: Section 7 specifies "AES-256 encryption for diagnosis and prescription data" but provides no design for encryption key generation, storage, rotation, or access control.

**Impact**:
- If encryption keys are hardcoded or stored in application code/environment variables, they are vulnerable to exposure
- No key rotation means a single key compromise affects all historical data
- Cannot meet compliance requirements for key management (e.g., HIPAA requires documented key management)
- Database-level encryption without proper key separation provides minimal security benefit

**Recommended Countermeasures**:
1. **Key Storage**: Use AWS KMS (Key Management Service) for master key storage
2. **Envelope Encryption**: Generate data encryption keys (DEKs) per medical institution using KMS master key, store encrypted DEKs in database
3. **Key Rotation**: Implement annual key rotation schedule with re-encryption of active records
4. **Access Control**: Restrict KMS key access to specific ECS task roles, enable CloudTrail logging for all KMS operations
5. **Key Hierarchy**: Use separate KMS keys per environment (dev/staging/prod)

**Relevant Sections**: Section 7 (Security Requirements - Data Encryption)

---

### 1.4 Missing Input Validation Policy and SQL Injection Prevention

**Problem**: No input validation policy is defined for API endpoints. Section 5 shows endpoints accepting user input (`patient_id`, `email`, etc.) but lacks validation rules, parameterized query design, or ORM safety measures.

**Impact**:
- SQL injection vulnerabilities if queries are constructed with string concatenation
- No defense against malformed input causing application errors or crashes
- No specification for maximum input lengths, allowed characters, or format validation
- Medical record data corruption if invalid data is stored

**Recommended Countermeasures**:
1. **Parameterized Queries**: Enforce Spring JPA/Hibernate for all database access (no raw SQL), explicitly document use of `@Query` with named parameters
2. **Input Validation Layer**:
   - Add Bean Validation (JSR-380) annotations to request DTOs
   - Example: `@Email` for email, `@NotNull`, `@Size(max=100)` for names, `@Pattern` for phone numbers
3. **Validation Policy**: Document validation rules in API spec:
   - Email: RFC 5322 compliant
   - Phone: E.164 format (+81-90-1234-5678)
   - Patient names: UTF-8, max 100 chars, reject control characters
   - Date of birth: ISO 8601 format, reject future dates
4. **Error Handling**: Return 400 Bad Request with validation errors (without exposing internal structure)

**Relevant Sections**: Section 5 (API Design), Section 6 (Error Handling)

---

### 1.5 Missing File Upload Security for Medical Images

**Problem**: Section 2 mentions "medical images and test result PDFs stored in S3" and data model shows medical records, but file upload security is not designed (no file type validation, size limits, malware scanning, or access control).

**Impact**:
- Uploading malicious files (e.g., executable disguised as PDF) could compromise server or other users
- Unrestricted file sizes could cause DoS through storage exhaustion
- No access control on S3 objects could expose patient data to unauthorized users
- Missing content-type validation could allow upload of arbitrary data

**Recommended Countermeasures**:
1. **File Type Validation**:
   - Whitelist: Only allow `.pdf`, `.jpg`, `.png`, `.dcm` (DICOM for medical images)
   - Verify file content (magic bytes) matches extension, don't trust client-provided MIME type
2. **File Size Limits**:
   - Images: max 10MB per file
   - PDFs: max 50MB per file
3. **Malware Scanning**: Integrate AWS S3 with ClamAV or third-party scanning service (scan on upload)
4. **S3 Security**:
   - Block public access on bucket level
   - Generate pre-signed URLs (15-minute expiration) for file access instead of direct S3 URLs
   - Enable S3 server-side encryption (SSE-KMS)
   - Implement S3 bucket policy restricting access to specific ECS task roles
5. **Upload API Design**: Add `POST /api/v1/medical-records/{id}/attachments` with multipart/form-data validation

**Relevant Sections**: Section 2 (Infrastructure - S3), Section 4 (Data Model)

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Missing Rate Limiting for Authentication Endpoints

**Suggestion**: Add brute-force protection for `/api/v1/auth/login` and other authentication endpoints.

**Rationale**: Section 7 specifies "60 requests/minute per user" rate limiting, but this is insufficient for login endpoints where the attacker doesn't have a valid user token yet. Login endpoints are prime targets for credential stuffing and brute-force attacks with high impact (access to medical records).

**Recommended Countermeasures**:
1. **IP-based Rate Limiting**: Limit `/api/v1/auth/login` to 5 attempts per 15 minutes per IP address (using Redis)
2. **Account Lockout**: After 5 failed login attempts for the same email, lock the account for 30 minutes (store lockout state in Redis)
3. **CAPTCHA**: Require CAPTCHA after 3 failed attempts from the same IP
4. **Monitoring**: Alert security team when 100+ failed logins from single IP within 1 hour (potential attack)

**Relevant Sections**: Section 5 (Authentication API), Section 7 (Security Requirements)

---

### 2.2 Missing CSRF Protection Design

**Suggestion**: Add CSRF (Cross-Site Request Forgery) protection for state-changing endpoints.

**Rationale**: If JWT tokens are stored in cookies (as recommended in 1.1), the application becomes vulnerable to CSRF attacks. Section 5 shows multiple state-changing endpoints (`POST`, `PUT`, `DELETE`) but no CSRF protection design.

**Recommended Countermeasures**:
1. **Double Submit Cookie Pattern**:
   - Generate random CSRF token on login, store in both cookie (SameSite=Strict) and response body
   - Require `X-CSRF-Token` header matching cookie value for all POST/PUT/DELETE requests
2. **SameSite Attribute**: Already mitigates CSRF in modern browsers, but add explicit token validation for older browser support
3. **Middleware**: Implement Spring Security CSRF filter for all non-GET endpoints except `/api/v1/auth/login`

**Relevant Sections**: Section 5 (API Design), Section 6 (Implementation - Error Handling)

---

### 2.3 Missing Idempotency Design for Payment and Appointment Operations

**Suggestion**: Add idempotency key mechanism for payment processing and appointment creation.

**Rationale**: Section 1 mentions "credit card/bank transfer payments" and Section 5 shows `POST /api/v1/appointments` endpoint. Network failures or user double-clicks could cause duplicate payments or double-booking without idempotency guarantees.

**Recommended Countermeasures**:
1. **Idempotency Key Header**: Require `Idempotency-Key` header (UUID v4) for:
   - `POST /api/v1/payments` (new endpoint, currently missing from API design)
   - `POST /api/v1/appointments`
2. **Key Storage**: Store idempotency keys in Redis with 24-hour TTL, mapping key → response
3. **Duplicate Detection**: If same key received within 24 hours, return cached response (200 OK with original result) instead of re-executing
4. **Database Constraint**: Add unique constraint on `appointments.patient_id + appointment_time` to prevent double-booking at DB level

**Relevant Sections**: Section 1 (Payment Feature), Section 5 (Appointments API)

---

### 2.4 Missing Access Control for Medical Record Sharing

**Suggestion**: Add explicit patient consent mechanism for `is_shared` flag in medical records.

**Rationale**: Section 4 shows `medical_records.is_shared` boolean flag for inter-clinic sharing, but no design for how consent is obtained, who can toggle the flag, or audit trail for consent changes.

**Recommended Countermeasures**:
1. **Consent API**: Add `POST /api/v1/medical-records/{id}/consent` endpoint (patient-only access)
   - Request body: `{"is_shared": true, "consent_granted_at": "2026-02-10T12:34:56Z"}`
2. **Consent Audit**: Log all consent changes in `audit_logs` table
3. **Access Control**: Only patient (not doctor or admin) can change `is_shared` status
4. **Explicit Consent**: Default `is_shared` to `false`, require explicit opt-in
5. **Consent Expiration**: Add `consent_expires_at` column, require re-consent every 2 years

**Relevant Sections**: Section 4 (Data Model - medical_records), Section 5 (API Design)

---

### 2.5 Missing Database Connection Security

**Suggestion**: Add database connection encryption and secret management design.

**Rationale**: Section 2 specifies PostgreSQL 15 but doesn't specify connection security (SSL/TLS), credential storage, or rotation strategy.

**Recommended Countermeasures**:
1. **Encrypted Connections**: Enable PostgreSQL SSL mode (`sslmode=require` in connection string)
2. **Secret Management**: Store DB credentials in AWS Secrets Manager (not environment variables)
3. **Credential Rotation**: Enable automatic rotation every 90 days via Secrets Manager
4. **IAM Authentication**: Consider RDS IAM database authentication instead of static passwords
5. **Connection Pooling**: Configure HikariCP with `maxLifetime=30min` to prevent stale connections after credential rotation

**Relevant Sections**: Section 2 (Database), Section 3 (Architecture)

---

### 2.6 Missing Specification for Session Timeout

**Suggestion**: Add inactivity timeout for user sessions.

**Rationale**: 24-hour JWT expiration (Section 3) is a maximum lifetime, but no inactivity timeout is specified. User sessions should expire after a period of inactivity to prevent session hijacking on shared/public devices.

**Recommended Countermeasures**:
1. **Inactivity Timeout**: Add 30-minute inactivity timeout for patients, 15-minute for doctors/admins
2. **Activity Tracking**: Store last activity timestamp in Redis (key: `session:{user_id}`, value: timestamp, TTL: 30min)
3. **Middleware**: Update timestamp on every API request, reject requests if gap > 30 minutes
4. **Sliding Window**: Reset inactivity timer on each request (sliding window pattern)

**Relevant Sections**: Section 3 (Data Flow - JWT)

---

### 2.7 Missing WAF Rules Specification

**Suggestion**: Define AWS WAF rules for common web attacks.

**Rationale**: Section 3 mentions "CloudFront + WAF" but doesn't specify WAF rule configuration. Without explicit rules, WAF provides minimal protection.

**Recommended Countermeasures**:
1. **AWS Managed Rules**: Enable AWS Managed Rules for WAF:
   - Core Rule Set (CRS) - OWASP Top 10 protection
   - Known Bad Inputs - common malicious patterns
   - SQL Database - SQL injection patterns
2. **Custom Rules**:
   - Block requests with `User-Agent: sqlmap` (common SQL injection tool)
   - Block requests with more than 2048 characters in query string
   - Rate limit: 2000 requests per 5 minutes per IP
3. **Geo-Blocking**: If service is Japan-only, block requests from other countries (reduce attack surface)

**Relevant Sections**: Section 3 (Architecture - CloudFront + WAF)

---

### 2.8 Missing Error Information Leakage Prevention

**Suggestion**: Specify what information should NOT be exposed in error messages.

**Rationale**: Section 6 defines error response format but doesn't specify information leakage prevention. Detailed error messages can reveal system internals to attackers.

**Recommended Countermeasures**:
1. **Generic External Errors**: Return generic messages to clients:
   - DB errors → "Internal server error. Please try again later." (500)
   - Not found → "Resource not found." (404) - don't specify if patient/appointment/record
2. **Detailed Internal Logs**: Log full stack traces and SQL errors to CloudWatch Logs (not in response)
3. **Avoid Information Leakage**:
   - Login failure → "Invalid email or password" (don't reveal if email exists)
   - Authorization failure → "Access denied" (don't reveal resource existence)
4. **Custom Exception Handler**: Implement Spring `@ControllerAdvice` to sanitize all exceptions before returning to client

**Relevant Sections**: Section 6 (Error Handling)

---

### 2.9 Missing Doctor/Admin Multi-Factor Authentication (MFA)

**Suggestion**: Add MFA requirement for doctor and admin accounts.

**Rationale**: Section 5 shows authentication API but doesn't differentiate security requirements by role. Doctors and admins have privileged access to patient data and should have stronger authentication.

**Recommended Countermeasures**:
1. **MFA Enforcement**: Require TOTP (Time-based One-Time Password) for doctor/admin accounts
2. **MFA Endpoints**: Add `POST /api/v1/auth/mfa/setup` and `POST /api/v1/auth/mfa/verify`
3. **Backup Codes**: Generate 10 one-time backup codes during MFA setup
4. **Login Flow**: After password validation, require MFA code before issuing JWT
5. **Grace Period**: Allow 30-day grace period for existing accounts to set up MFA, then enforce

**Relevant Sections**: Section 5 (Authentication API)

---

### 2.10 Missing Network Segmentation Design

**Suggestion**: Add VPC network segmentation and security group design.

**Rationale**: Section 3 shows architecture diagram but doesn't specify network-level isolation between components (API, database, cache).

**Recommended Countermeasures**:
1. **VPC Subnets**:
   - Public subnet: ALB only
   - Private subnet: ECS tasks (API gateway, services)
   - Isolated subnet: RDS, Redis (no internet access)
2. **Security Groups**:
   - ALB: Allow 443 from 0.0.0.0/0, outbound to ECS security group only
   - ECS: Allow inbound from ALB security group only, outbound to RDS/Redis security groups
   - RDS: Allow 5432 from ECS security group only
   - Redis: Allow 6379 from ECS security group only
3. **Private Endpoints**: Use VPC endpoints for S3/KMS access (no internet gateway)

**Relevant Sections**: Section 3 (Architecture)

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Medical Data Retention and Deletion Policy

**Confirmation Reason**: Section 7 mentions "30-day database backup retention" but doesn't specify retention policy for active medical records or patient data deletion workflow.

**Options and Trade-offs**:

**Option A: Indefinite Retention (Common in Healthcare)**
- Retain all medical records indefinitely for legal/medical history purposes
- Pros: Complete medical history available, meets most healthcare regulations
- Cons: Increasing storage costs, potential GDPR "right to be forgotten" conflicts
- Implementation: No deletion logic needed

**Option B: GDPR-Compliant Deletion (Patient Right to Erasure)**
- Allow patients to request account deletion, anonymize medical records after 7 years
- Pros: GDPR-compliant, reduces long-term storage
- Cons: Complex implementation (anonymization vs deletion), potential medical-legal issues
- Implementation: Add `DELETE /api/v1/patients/{id}` endpoint, anonymize related records

**Option C: Hybrid (Anonymization After Inactivity)**
- Keep active records for 10 years, anonymize (remove PII) after patient inactivity
- Pros: Balances medical needs with privacy regulations
- Cons: Requires complex anonymization logic
- Implementation: Scheduled job to anonymize `patients` table after 10 years inactivity

**Recommendation**: Confirm with legal/compliance team which policy applies to target markets (Japan/EU/US have different requirements).

---

### 3.2 Third-Party Library Vulnerability Management

**Confirmation Reason**: Section 2 specifies library versions (jjwt 0.11, Spring Boot 3.2) but doesn't specify vulnerability scanning process or update policy.

**Options and Trade-offs**:

**Option A: Automated Dependency Scanning (Recommended)**
- Integrate Dependabot/Snyk/OWASP Dependency-Check in CI/CD pipeline
- Pros: Automated vulnerability detection, PR-based updates
- Cons: Requires pipeline integration, potential false positives
- Implementation: Add GitHub Dependabot config, fail builds on high/critical vulnerabilities

**Option B: Manual Quarterly Reviews**
- Schedule quarterly security reviews of dependencies
- Pros: No automation overhead, controlled update schedule
- Cons: Delayed vulnerability detection, manual effort
- Implementation: Add calendar reminder, use `mvn versions:display-dependency-updates`

**Option C: No Active Scanning (Not Recommended)**
- Update libraries only when bugs are encountered
- Pros: Minimal effort
- Cons: High risk of running vulnerable dependencies
- Implementation: None

**Recommendation**: Option A (automated scanning) is industry standard for healthcare systems handling sensitive data.

---

### 3.3 Backup Encryption and Disaster Recovery Testing

**Confirmation Reason**: Section 7 mentions "daily PostgreSQL backups, 30-day retention" but doesn't specify backup encryption, off-site storage, or recovery testing.

**Options and Trade-offs**:

**Option A: Encrypted Backups with Cross-Region Replication**
- Enable RDS automated backups with KMS encryption, replicate to different region
- Pros: Protection against regional outages, encrypted at rest
- Cons: Higher AWS costs (cross-region data transfer)
- Implementation: Enable RDS cross-region backup replication, quarterly recovery drills

**Option B: Same-Region Encrypted Backups**
- Enable RDS automated backups with KMS encryption, same region only
- Pros: Lower cost, meets basic compliance
- Cons: No protection against regional disasters
- Implementation: Enable KMS encryption for RDS backups

**Option C: Default RDS Backups (No Additional Encryption)**
- Use RDS default backup (encrypted with AWS-managed keys)
- Pros: No additional configuration
- Cons: No custom key control, no disaster recovery for regional outage
- Implementation: None (default behavior)

**Recommendation**: Option A for production healthcare system with 99.9% availability requirement. Add quarterly RTO/RPO testing.

---

## 4. Positive Evaluation (good points)

### 4.1 Strong Password Hashing

The design appropriately specifies bcrypt with cost factor 12 for password hashing (Section 4, `patients.password_hash`). This is significantly more secure than legacy hashing algorithms (MD5, SHA-1) and provides protection against brute-force attacks even if the database is compromised. The cost factor 12 strikes a good balance between security and performance.

---

### 4.2 HTTPS Enforcement

Section 7 explicitly requires TLS 1.2+ for all communications, which protects data in transit from eavesdropping and man-in-the-middle attacks. Using CloudFront CDN also provides DDoS protection at the edge.

---

### 4.3 Role-Based Access Control (RBAC) Design

Section 5 appropriately defines role-based authorization (patient/doctor/admin) with clear access boundaries. The principle of least privilege is evident (patients can only access their own data, doctors can only modify records for their patients).

---

### 4.4 Database Read Replica for Performance

Section 7's design of 2 read replicas for PostgreSQL is a good practice that not only improves performance but also provides failover capability and reduces load on the primary database during potential DoS attacks.

---

### 4.5 API Rate Limiting

The inclusion of Redis-based rate limiting (60 requests/minute per user) shows awareness of DoS protection, though it needs enhancement for authentication endpoints as noted in section 2.1.
