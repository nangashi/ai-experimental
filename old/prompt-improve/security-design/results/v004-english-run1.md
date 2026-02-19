# Security Design Review: Enterprise HR & Payroll Management System

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple critical threats unaddressed: session fixation (Spoofing), log injection (Tampering), no audit integrity (Repudiation), sensitive data exposure in logs and storage (Information Disclosure), no DoS protection (Denial of Service), insufficient privilege separation (Elevation of Privilege) |
| Authentication & Authorization Design | 2 | 24-hour JWT without refresh mechanism creates extended attack window; no session invalidation; authorization relies solely on annotations without defense-in-depth |
| Data Protection | 1 | Critical: My Number and bank account stored unencrypted; PII leaked in application logs; no encryption key rotation; JWT signed with symmetric key stored in plaintext environment variable |
| Input Validation Design | 3 | No explicit input validation policy; injection prevention measures not described; file upload security missing; output escaping not mentioned |
| Infrastructure & Dependencies | 2 | Secrets stored as plaintext environment variables; no dependency vulnerability scanning mentioned; missing security headers and CORS policy |
| **Overall** | **2.0** | |

---

## 1. Critical Issues (design modification required)

### 1.1 Unencrypted Storage of Highly Sensitive PII

**Problem**: My Number (`my_number`) and bank account numbers (`bank_account`) are stored in PostgreSQL without encryption (Section 4.1, 7.2)

**Impact**:
- My Number is legally protected under Japan's "Act on the Use of Numbers to Identify a Specific Individual" with strict handling requirements
- Database dump leakage or SQL injection attack exposes this irrecoverable identifier
- Bank account leakage enables direct financial fraud
- Violation may result in regulatory penalties and loss of customer trust

**Recommended Countermeasures**:
1. Implement field-level encryption using AES-256-GCM for `my_number` and `bank_account` columns
2. Use AWS KMS for encryption key management with automatic rotation (90-day cycle)
3. Store only encrypted ciphertext in database; decrypt in application layer only when HR_MANAGER role accesses with audit logging
4. Consider tokenization service (e.g., AWS Payment Cryptography) for bank accounts to avoid storing actual numbers
5. Implement column-level access control and trigger audit logs on decryption operations

**Relevant Section**: Section 4.1 (employees table schema), Section 7.2 (Security requirements)

---

### 1.2 PII Leakage in Application Logs

**Problem**: Section 6.3 explicitly states "Personal information (name, email, salary amount) is output to logs"

**Impact**:
- Logs aggregated in Datadog become permanent record of PII accessible to operations team
- Log retention policies typically span months/years, violating data minimization principle
- Regulatory compliance risk under GDPR, APPI (Japan's Personal Information Protection Act)
- Insider threats can easily extract bulk PII from centralized log storage

**Recommended Countermeasures**:
1. Immediately remove PII from log output; use surrogate identifiers (employee_code, UUIDs only)
2. Implement structured logging with field-level redaction using library like Logback's `MaskingConverter`
3. Example log format: `"Employee updated: employee_code=E001, fields=[email, department]"` instead of actual values
4. If PII logging is necessary for debugging, use separate audit logs with encryption at rest, strict access control (MFA required), and 90-day retention maximum
5. Configure Datadog's Sensitive Data Scanner to detect and redact leaked PII patterns

**Relevant Section**: Section 6.3 (Logging policy)

---

### 1.3 JWT Signature Key Stored as Plaintext Environment Variable

**Problem**: Section 6.5 states "Secrets (JWT signature key, database password) are stored as plaintext in environment variables"

**Impact**:
- Anyone with access to ECS task definition or container inspection can retrieve the signing key
- Compromised key allows attacker to forge valid JWTs for any user/tenant with any role
- 24-hour token expiration (Section 6.1) amplifies damage window
- Key rotation requires application redeployment, discouraging regular rotation

**Recommended Countermeasures**:
1. Migrate to AWS Secrets Manager for JWT signing key and database credentials
2. Use IAM role-based retrieval (no hardcoded credentials)
3. Enable automatic rotation (90 days) with dual-key validation period to avoid service disruption
4. Alternative: Switch to RS256 (asymmetric) signing algorithm; store private key in AWS KMS, distribute public key for validation
5. Implement key version tracking in JWT header to support gradual key rotation

**Relevant Section**: Section 6.5 (Deployment policies), Section 6.1 (Authentication design)

---

### 1.4 Extended Attack Window from 24-Hour JWT Without Refresh Token

**Problem**: Section 6.1 specifies "No refresh token issued; re-login required on expiration" with 24-hour access token validity

**Impact**:
- Stolen JWT (via XSS, MITM, or log leakage) remains valid for 24 hours with no revocation mechanism
- User logout does not invalidate token (no session tracking)
- Malicious insider can extract their own token and maintain access for 24 hours after termination
- Cross-device token sharing cannot be detected or prevented

**Recommended Countermeasures**:
1. Reduce access token expiration to 15 minutes maximum
2. Implement refresh token pattern with 7-day expiration:
   - Store refresh tokens in Redis with user/device fingerprint binding
   - Enable immediate revocation on logout, password change, or role update
   - Implement refresh token rotation (issue new refresh token on each use, invalidate old one)
3. Add token binding to device fingerprint (User-Agent + IP subnet) to detect token theft
4. Implement token family tracking to detect concurrent use across devices
5. Add logout endpoint that blacklists tokens in Redis until expiration

**Relevant Section**: Section 6.1 (Authentication and authorization design)

---

### 1.5 Missing Input Validation and Injection Prevention Design

**Problem**: No input validation policy described; no mention of prepared statements, parameterized queries, or ORM-level injection prevention

**Impact**:
- Spring Data JPA's native query feature allows SQL injection if not properly parameterized
- API endpoints accepting free-text fields (employee names, department names) vulnerable to stored XSS in React frontend
- File upload endpoints (e.g., contract documents to S3 in Section 2.2) lack security controls: no file type validation, size limits, or malware scanning
- Potential for NoSQL injection in Redis if query strings are user-controlled

**Recommended Countermeasures**:
1. **Input Validation**:
   - Define validation rules per field: employee_code (alphanumeric, 3-20 chars), email (RFC 5322 format), phone_number (E.164 format)
   - Use Bean Validation (JSR 380) annotations: `@Pattern`, `@Email`, `@Size`, `@NotNull`
   - Whitelist validation for enum fields (status, role)
2. **SQL Injection Prevention**:
   - Enforce Spring Data JPA's JPQL or Criteria API (prohibit native SQL in code review)
   - If native queries required, use `@Query` with named parameters (`:param`) only
3. **XSS Prevention**:
   - Sanitize all user input on backend using OWASP Java Encoder
   - Frontend: React's default escaping is active, but ensure `dangerouslySetInnerHTML` is never used
   - Implement Content Security Policy header: `Content-Security-Policy: default-src 'self'; script-src 'self'`
4. **File Upload Security**:
   - Restrict MIME types to whitelisted values (application/pdf, image/jpeg, image/png)
   - Maximum file size: 10MB
   - Scan uploads with ClamAV or AWS GuardDuty Malware Protection
   - Store files with UUID-based names (prevent path traversal)
   - Set S3 bucket policies to block public access and require object-level encryption
5. **Output Encoding**: Explicitly configure Jackson to escape HTML in JSON responses

**Relevant Section**: Section 5 (API design - all endpoints), Section 2.2 (S3 document storage)

---

### 1.6 No Rate Limiting or Brute-Force Protection

**Problem**: API endpoints lack rate limiting design; login endpoint (`/api/auth/login`) has no brute-force protection

**Impact**:
- Credential stuffing attacks can test thousands of leaked passwords against user accounts
- Enumeration attacks can identify valid email addresses via login response timing
- Resource exhaustion attacks on expensive endpoints (e.g., `/api/payroll/calculate` triggers asynchronous batch job)
- No defense against DDoS at application layer

**Recommended Countermeasures**:
1. **Login Endpoint Protection** (`/api/auth/login`):
   - Implement account-level rate limiting: 5 failed attempts within 15 minutes → 30-minute account lock
   - IP-based rate limiting: 20 failed attempts per IP per hour → temporary IP block
   - Add progressive delay: 1st failure = 0s, 2nd = 1s, 3rd = 2s, 4th = 4s, 5th = 8s delay before response
   - Use Redis for distributed rate limit tracking (sorted sets with TTL)
2. **API-Wide Rate Limiting**:
   - Implement Spring Cloud Gateway or Bucket4j library
   - Per-tenant limits: 1000 requests per hour per tenant
   - Per-user limits: 100 requests per minute per authenticated user
   - Expensive endpoint limits: `/api/payroll/calculate` → 10 requests per day per HR_MANAGER
3. **DDoS Protection**:
   - Enable AWS WAF on ALB with AWS Managed Rules for rate limiting (Core Rule Set + Known Bad Inputs)
   - Configure CloudFront in front of ALB for edge-level DDoS mitigation
4. **Account Enumeration Prevention**:
   - Return generic error message for invalid credentials: "Invalid email or password" (do not specify which)
   - Ensure response time is constant regardless of whether email exists (use dummy password hash comparison)

**Relevant Section**: Section 5.1 (Authentication endpoints), Section 5.3 (Payroll calculation API)

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Lack of Session Management and Token Revocation

**Suggestion**: Implement server-side session tracking for active JWTs to enable immediate revocation

**Rationale**:
- Stateless JWT design prevents logout enforcement, password change invalidation, or emergency access revocation
- HR system handles sensitive data requiring ability to immediately terminate sessions (e.g., employee termination, security incident)
- Multi-device session management allows detection of anomalous login patterns

**Recommended Countermeasures**:
1. Store active sessions in Redis: key = `session:{userId}:{tokenId}`, value = `{deviceFingerprint, issuedAt, lastActivity, ipAddress}`
2. Set TTL matching JWT expiration (24 hours currently, 15 minutes if recommendation 1.4 adopted)
3. On each API request, validate JWT signature AND check Redis session existence
4. Implement `/api/auth/logout` endpoint that deletes Redis session
5. Implement `/api/admin/sessions/{userId}` endpoint for HR_MANAGER to view/revoke user sessions
6. Add automatic session termination on password change, role update, or account suspension

---

### 2.2 Missing Multi-Factor Authentication (MFA) for Privileged Roles

**Suggestion**: Require MFA for HR_MANAGER and ADMIN roles, especially for sensitive operations (payroll calculation, employee data export, audit log access)

**Rationale**:
- HR_MANAGER role has access to all employee PII, salary data, and My Numbers
- Password compromise (phishing, credential stuffing) is common attack vector
- Regulatory frameworks (NIST SP 800-63B) recommend MFA for access to PII

**Recommended Countermeasures**:
1. Implement TOTP-based MFA using Google Authenticator (library: `dev.samstevens.totp`)
2. Require MFA during login for HR_MANAGER and ADMIN roles
3. Step-up authentication: Require re-authentication with MFA for high-risk operations:
   - Bulk employee data export (`/api/employees/export`)
   - Payroll calculation execution (`/api/payroll/calculate`)
   - Audit log access (`/api/audit/logs`)
   - User permission changes
4. Store MFA secrets encrypted in database (use AWS KMS for key management)
5. Provide backup codes (10 single-use codes) for MFA device loss recovery

---

### 2.3 Insufficient Authorization Defense-in-Depth

**Suggestion**: Implement layered authorization checks beyond `@PreAuthorize` annotations

**Rationale**:
- Relying solely on annotation-based authorization is vulnerable to developer mistakes (forgotten annotation, incorrect role name)
- Business logic in service layer should enforce tenant isolation and resource ownership checks
- Defense-in-depth principle requires multiple independent security controls

**Recommended Countermeasures**:
1. **Database-Level Enforcement**:
   - Enable PostgreSQL Row-Level Security (RLS) policies on all tables:
     ```sql
     CREATE POLICY tenant_isolation ON employees
     FOR ALL
     USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
     ```
   - Set `app.current_tenant_id` session variable on each request in connection pool
2. **Service Layer Checks**:
   - Create `@TenantIsolation` aspect that automatically verifies `tenantId` in request matches authenticated user's tenant
   - Implement resource ownership checks: e.g., employee can only access their own payroll records, manager can only approve subordinates' attendance
3. **API Gateway Validation**:
   - Add ALB-level request validation for JWT structure before reaching application
4. **Audit Logging**:
   - Log all authorization failures with context: userId, requestedResource, deniedPermission, timestamp
   - Create alerts for repeated authorization failures (potential privilege escalation attempt)

---

### 2.4 Missing Security Headers and CORS Policy

**Suggestion**: Implement comprehensive security headers and strict CORS policy

**Rationale**:
- Missing security headers leave frontend vulnerable to clickjacking, MIME sniffing attacks, XSS
- Undefined CORS policy may allow unintended cross-origin requests or be overly permissive

**Recommended Countermeasures**:
1. Configure Spring Security to add security headers:
   ```java
   http.headers()
       .contentSecurityPolicy("default-src 'self'; script-src 'self'; object-src 'none'")
       .and()
       .frameOptions().deny()  // X-Frame-Options: DENY
       .xssProtection().block(true)  // X-XSS-Protection: 1; mode=block
       .contentTypeOptions()  // X-Content-Type-Options: nosniff
       .and()
       .referrerPolicy(ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN)
       .and()
       .permissionsPolicy("geolocation=(), microphone=(), camera=()");
   ```
2. Add HSTS header: `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
3. Configure CORS policy:
   ```java
   @CrossOrigin(
       origins = {"https://hr-app.example.com"},  // Whitelist specific frontend origin
       allowedMethods = {"GET", "POST", "PUT", "DELETE"},
       allowCredentials = "true",  // Required for cookie-based auth (if migrating from JWT)
       maxAge = 3600
   )
   ```
4. Ensure `Access-Control-Allow-Origin` is never set to `*` in production

---

### 2.5 No Audit Trail for Sensitive Data Access

**Suggestion**: Implement comprehensive audit logging for all access to PII, salary data, and My Numbers beyond Section 6.3's limited scope

**Rationale**:
- Section 6.3 mentions logging "authentication events, permission errors, payroll calculation, employee info updates" but not read access
- Regulatory compliance (GDPR Article 30, Japan's APPI) requires audit trails for PII access
- Insider threat detection requires visibility into who accessed which employee's data when

**Recommended Countermeasures**:
1. Create `audit_logs` table:
   ```sql
   CREATE TABLE audit_logs (
       id UUID PRIMARY KEY,
       tenant_id UUID NOT NULL,
       user_id UUID NOT NULL,
       action VARCHAR(50) NOT NULL,  -- READ, CREATE, UPDATE, DELETE
       resource_type VARCHAR(50) NOT NULL,  -- EMPLOYEE, PAYROLL, ATTENDANCE
       resource_id UUID,
       accessed_fields TEXT[],  -- ['salary_amount', 'my_number']
       ip_address INET,
       user_agent TEXT,
       timestamp TIMESTAMP NOT NULL,
       INDEX (tenant_id, timestamp),
       INDEX (resource_type, resource_id)
   );
   ```
2. Implement `@Audited` aspect using Spring AOP:
   - Trigger on service layer methods accessing employees, payroll_records tables
   - Automatically capture userId, accessed resource IDs, operation type
3. Special alerting for bulk access patterns:
   - Alert if single user accesses >50 employee records within 1 hour (potential data exfiltration)
   - Alert if user downloads payroll data for employees outside their department
4. Retention: Store audit logs for 7 years (typical regulatory requirement), separate from application logs
5. Provide audit report API for compliance audits: `/api/audit/reports?userId=X&startDate=Y&endDate=Z`

---

### 2.6 Weak Password Policy and No Credential Breach Detection

**Suggestion**: Strengthen password requirements and integrate credential breach detection

**Rationale**:
- Section 7.2 specifies bcrypt hashing (good) but no password strength requirements
- Common weak passwords (e.g., "password123" in Section 5.1 example) are easily cracked
- NIST SP 800-63B recommends checking passwords against breach databases

**Recommended Countermeasures**:
1. Enforce password policy:
   - Minimum length: 12 characters (not 8)
   - Require mix of uppercase, lowercase, numbers, and symbols
   - Prohibit common patterns: sequential characters, repeated characters, keyboard patterns
   - Prohibit inclusion of username or email in password
2. Integrate HaveIBeenPwned Passwords API:
   - On registration/password change, check if password hash appears in breach database
   - Use k-Anonymity model (send first 5 characters of SHA-1 hash, receive matching suffixes)
   - Reject passwords found in breaches
3. Implement password history: Prevent reuse of last 5 passwords (store bcrypt hashes in `password_history` table)
4. Force password rotation every 90 days for HR_MANAGER and ADMIN roles
5. Provide password strength meter in UI using zxcvbn library

---

### 2.7 Lack of Encryption for Data in Transit to S3

**Suggestion**: Enforce encryption in transit for S3 uploads/downloads and enable S3 server-side encryption

**Rationale**:
- Section 2.2 mentions S3 for storing payroll PDFs and contract documents (highly sensitive)
- No mention of encryption in transit (TLS) or at rest for S3 objects
- S3 bucket misconfiguration is common attack vector

**Recommended Countermeasures**:
1. **Encryption in Transit**:
   - Configure S3 bucket policy to deny non-TLS requests:
     ```json
     {
       "Effect": "Deny",
       "Principal": "*",
       "Action": "s3:*",
       "Resource": "arn:aws:s3:::hr-documents-bucket/*",
       "Condition": {
         "Bool": {"aws:SecureTransport": "false"}
       }
     }
     ```
   - Use AWS SDK with enforced HTTPS endpoints
2. **Encryption at Rest**:
   - Enable S3 bucket default encryption with SSE-KMS (not SSE-S3):
     ```bash
     aws s3api put-bucket-encryption --bucket hr-documents-bucket \
       --server-side-encryption-configuration '{
         "Rules": [{"ApplyServerSideEncryptionByDefault":
           {"SSEAlgorithm": "aws:kms", "KMSMasterKeyID": "arn:aws:kms:..."}
         }]
       }'
     ```
   - Use customer-managed KMS key with automatic rotation enabled
3. **Access Control**:
   - Block all public access (bucket policy + ACL)
   - Use IAM roles for EC2/ECS service access (no access keys in code)
   - Enable S3 Object Lock for payroll PDFs (WORM mode, 7-year retention for compliance)
4. **Audit**: Enable S3 access logging and CloudTrail S3 data events

---

### 2.8 Missing Database Connection Security

**Suggestion**: Enforce TLS for PostgreSQL connections and implement least-privilege database credentials

**Rationale**:
- Section 2.2 mentions "RDS" but no mention of encrypted connections
- MITM attacks on VPC-internal traffic are possible in compromised environments
- Single database credential for application has excessive permissions

**Recommended Countermeasures**:
1. **TLS Enforcement**:
   - Configure RDS to require SSL: `rds.force_ssl = 1`
   - Set Spring Boot datasource URL: `jdbc:postgresql://...?sslmode=require&sslrootcert=/path/to/rds-ca-cert.pem`
2. **Credential Separation**:
   - Create separate database users for application vs. migration:
     - `hr_app_user`: SELECT, INSERT, UPDATE, DELETE on application tables (no DDL)
     - `hr_migration_user`: Full DDL permissions (only used by Flyway)
   - Use AWS Secrets Manager to rotate credentials automatically
3. **Network Isolation**:
   - Place RDS in private subnet (no public IP)
   - Security group: only allow inbound 5432 from ECS task security group
4. **Connection Pooling Security**:
   - Set HikariCP minimum idle connections = 5 (prevent connection exhaustion DoS)
   - Set connection timeout = 10s, max lifetime = 30min (force credential refresh)

---

## 3. Confirmation Items (requiring user clarification)

### 3.1 Data Residency and Cross-Border Transfer Requirements

**Question**: Are there legal restrictions on storing employee data (especially My Number) in specific AWS regions?

**Context**:
- Japan's My Number Act requires strict handling of My Number data
- Some interpretations suggest data should remain in Japan
- Current design (Section 2.3) mentions "AWS" without specifying region

**Options and Trade-offs**:
1. **Option A**: Use AWS Tokyo region (ap-northeast-1) exclusively
   - Pros: Ensures data residency compliance, lower latency for Japan-based users
   - Cons: Single-region deployment reduces disaster recovery options
2. **Option B**: Multi-region with data classification
   - Pros: Store My Number/sensitive PII in Tokyo region only; non-sensitive data replicated to other regions for DR
   - Cons: Complex data classification logic, requires encryption key management per region
3. **Recommendation**: Clarify legal requirements with compliance team; default to Option A unless DR requires Option B

---

### 3.2 Retention Period for Audit Logs and Payroll Records

**Question**: What is the required retention period for audit logs, payroll records, and employee data after termination?

**Context**:
- Section 7.3 mentions "daily full backups" but no retention policy
- Labor Standards Act (Japan) requires payroll record retention for 5 years
- Tax law requires withholding records for 7 years
- GDPR/APPI "right to erasure" may conflict with legal retention requirements

**Options and Trade-offs**:
1. **Option A**: 7-year retention for all payroll and tax records (compliant with Japanese tax law)
   - Implement automated archival to S3 Glacier after 1 year
   - Purge employee personal data (name, email) after termination + 7 years, retain anonymized payroll data
2. **Option B**: Separate retention policies by data type
   - Payroll/tax records: 7 years
   - Audit logs: 3 years (security investigation window)
   - Employee master data: Delete 90 days after termination (unless payroll records exist)
3. **Recommendation**: Consult legal team; implement automated retention policy enforcement via scheduled jobs

---

### 3.3 Disaster Recovery and Backup Encryption

**Question**: Should database backups be encrypted, and what is the acceptable RPO/RTO?

**Context**:
- Section 7.3 specifies RTO = 4 hours, RPO = 24 hours (daily backups)
- No mention of backup encryption
- 24-hour RPO means potential loss of full day's payroll calculations and attendance records

**Options and Trade-offs**:
1. **Option A**: Enable RDS automated backups with encryption
   - Pros: Point-in-time recovery within backup retention window (35 days max), encrypted at rest
   - Cons: Restore time for large databases may exceed 4-hour RTO
2. **Option B**: Implement continuous replication to standby RDS instance in second AZ
   - Pros: RPO < 5 minutes, RTO < 1 hour (automatic failover), consistent with critical nature of payroll data
   - Cons: ~2x database cost
3. **Option C**: Hybrid approach
   - Real-time replication for production database (minimizes RPO/RTO)
   - Daily encrypted snapshots to S3 for long-term compliance retention (7 years)
4. **Recommendation**: Given financial impact of payroll data loss, recommend Option C

---

## 4. Positive Evaluation (good points)

### 4.1 Multi-Tenant Architecture with Tenant Isolation

The design correctly implements tenant isolation via `tenant_id` column in all tables (Section 4.1) with indexing for query performance. The mention of Row-Level Security in Section 3.3 indicates awareness of defense-in-depth, though implementation details should be formalized (see recommendation 2.3).

### 4.2 Use of Bcrypt for Password Hashing

Section 7.2 specifies bcrypt with work factor 10 for password hashing, which is a security best practice (OWASP recommendation). Work factor 10 provides good balance between security and performance for authentication flows.

### 4.3 HTTPS Enforcement

Section 7.2 requires all communication over HTTPS, preventing MITM attacks and eavesdropping on sensitive data in transit. This is a fundamental but critical security control.

### 4.4 Separation of Responsibilities in Role Model

The design (Section 1.3) clearly separates HR_MANAGER, ADMIN, manager, and employee roles with distinct permissions, following principle of least privilege. For example, only ADMIN can delete employees (Section 5.2), and employees can only view their own payroll (Section 5.3).

### 4.5 Audit Logging of Critical Operations

Section 6.3 includes audit logging for authentication events, permission errors, payroll calculation, and employee updates. While improvements are needed (see recommendation 2.5), the foundation for audit trail is present.

---

## Summary of Recommended Priorities

**Immediate Action Required (Severity: Critical)**:
1. Encrypt My Number and bank account fields (Issue 1.1)
2. Remove PII from application logs (Issue 1.2)
3. Migrate secrets to AWS Secrets Manager (Issue 1.3)
4. Implement input validation and injection prevention (Issue 1.5)

**High Priority (Implement in Sprint 1)**:
5. Reduce JWT expiration and add refresh token (Issue 1.4)
6. Add rate limiting and brute-force protection (Issue 1.6)
7. Implement session management (Suggestion 2.1)
8. Add MFA for privileged roles (Suggestion 2.2)

**Medium Priority (Implement in Sprint 2-3)**:
9. Implement database-level RLS and authorization defense-in-depth (Suggestion 2.3)
10. Add security headers and CORS policy (Suggestion 2.4)
11. Expand audit logging coverage (Suggestion 2.5)
12. Strengthen password policy (Suggestion 2.6)

**Ongoing**:
13. Encrypt S3 objects and enforce TLS (Suggestion 2.7)
14. Secure database connections (Suggestion 2.8)
15. Clarify data residency, retention policies, and DR requirements (Confirmation items 3.1-3.3)
