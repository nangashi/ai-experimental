# Security Design Review: Online Medical Consultation Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple STRIDE categories lack explicit countermeasures, particularly repudiation and DoS protection |
| Authentication & Authorization Design | 2 | JWT stored client-side with 24-hour expiration creates extended compromise window; no refresh token mechanism |
| Data Protection | 3 | Database encryption specified but key management, backup encryption, and S3 access controls are undefined |
| Input Validation Design | 2 | No input validation strategy defined; SQL injection and XSS prevention measures not specified |
| Infrastructure & Dependencies | 3 | Basic infrastructure security present but secrets management, WAF rules, and dependency scanning not defined |
| **Overall** | **2.4** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Security Vulnerabilities

**Problem**: JWT tokens with 24-hour expiration stored client-side (Section 3 "データフロー") create significant security risks.

**Impact**:
- If a token is stolen via XSS, Man-in-the-Middle, or device compromise, attackers have 24 hours of unrestricted access to patient medical records
- No mechanism exists to revoke compromised tokens before expiration
- Patient medical data (PHI) exposure carries legal liability under privacy regulations

**Recommended Countermeasures**:
1. Reduce access token expiration to 15 minutes
2. Implement refresh token mechanism (7-day expiration with rotation)
3. Store refresh tokens securely server-side (Redis) with revocation capability
4. Consider storing tokens in HttpOnly + Secure + SameSite=Strict cookies instead of client-side storage
5. Implement token revocation endpoint for emergency cases

**Relevant Section**: Section 3 データフロー, Section 5 認証・認可方式

---

### 1.2 Insufficient Authorization Controls for Medical Record Sharing

**Problem**: The `is_shared` flag in `medical_records` table (Section 4) lacks detailed access control design for inter-clinic data sharing.

**Impact**:
- Unclear who can set/unset the sharing flag (patient? doctor? both?)
- No audit trail for when sharing was enabled/disabled
- Risk of unauthorized access to patient records by doctors at other clinics
- Potential violation of patient consent requirements under medical privacy laws

**Recommended Countermeasures**:
1. Create separate `medical_record_sharing` table with:
   - `record_id`, `source_clinic_id`, `target_clinic_id`, `authorized_by_patient_id`, `authorized_at`, `expires_at`, `revoked_at`
2. Require explicit patient consent (digital signature) before enabling sharing
3. Implement time-limited sharing (default 30 days, renewable)
4. Add audit logging for all sharing operations
5. API design: `POST /api/v1/medical-records/{id}/share` with patient authentication required

**Relevant Section**: Section 4 medical_records, Section 1.2 診療情報共有

---

### 1.3 Missing SQL Injection Prevention Strategy

**Problem**: No input validation or parameterized query strategy is documented (Section 5 API設計, Section 6 実装方針).

**Impact**:
- Risk of SQL injection attacks that could expose entire patient database
- Attackers could extract sensitive medical records, modify prescriptions, or delete audit logs
- High severity given the volume of user input (patient registration, search queries, medical records)

**Recommended Countermeasures**:
1. Mandate parameterized queries/prepared statements for all database access (enforce via Spring Data JPA or MyBatis)
2. Add input validation layer using Bean Validation (JSR-303) annotations
3. Implement database user with least-privilege permissions (SELECT/INSERT/UPDATE only, no DROP/ALTER)
4. Add SQL injection detection rules to WAF
5. Document validation rules in Section 6 実装方針

**Relevant Section**: Section 5 API設計, Section 6 実装方針

---

### 1.4 No XSS Prevention Measures for Medical Record Display

**Problem**: No output escaping or Content Security Policy is specified for displaying user-generated medical content (diagnosis, prescription fields in Section 4).

**Impact**:
- Stored XSS vulnerability if malicious scripts are injected into medical records
- Attackers could steal JWT tokens, perform actions on behalf of doctors/patients
- Particularly dangerous given the `TEXT` type allows arbitrary content in `diagnosis` and `prescription` fields

**Recommended Countermeasures**:
1. Frontend: Use React's automatic escaping (do NOT use `dangerouslySetInnerHTML` for medical content)
2. Backend: Sanitize input using OWASP Java HTML Sanitizer before storing in database
3. Implement Content Security Policy headers:
   ```
   Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'
   ```
4. Add `X-Content-Type-Options: nosniff` and `X-Frame-Options: DENY` headers
5. Document CSP configuration in Section 6 実装方針

**Relevant Section**: Section 4 データモデル, Section 2 React 18

---

### 1.5 Undefined Secrets Management for Database Credentials and JWT Keys

**Problem**: No design for managing sensitive credentials (DB passwords, JWT signing keys, AWS access keys) is documented.

**Impact**:
- Risk of hardcoded credentials in source code or configuration files
- Compromised JWT signing key allows attackers to forge valid tokens for any user
- Database credential exposure allows direct database access bypassing application logic

**Recommended Countermeasures**:
1. Use AWS Secrets Manager for storing:
   - PostgreSQL credentials
   - JWT signing key (HS256) - rotate monthly
   - Redis password
   - Third-party API keys (payment gateway)
2. Configure ECS Fargate task definitions to inject secrets as environment variables
3. Implement JWT key rotation mechanism (support validating with previous key during rotation window)
4. Document secrets management in Section 6 デプロイメント方針
5. Add pre-commit hooks to prevent committing secrets (use tools like git-secrets)

**Relevant Section**: Section 2 技術スタック, Section 3 インフラ・デプロイ環境

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Add Rate Limiting for Authentication Endpoints

**Problem**: While general API rate limiting is specified (60 req/min per user in Section 7), login endpoints lack brute-force protection.

**Rationale**: Authentication endpoints are prime targets for credential stuffing attacks. Medical systems contain highly valuable PHI data, making them attractive targets. A compromised account gives access to patient medical histories.

**Recommended Countermeasures**:
1. Implement stricter rate limiting for `/api/v1/auth/login`:
   - 5 attempts per 15 minutes per email address
   - 20 attempts per hour per IP address (to prevent distributed attacks)
2. Add account lockout after 10 failed attempts (unlock after 30 minutes or via email verification)
3. Implement CAPTCHA after 3 failed attempts
4. Use Redis for tracking failed login attempts
5. Log all failed authentication attempts to CloudWatch for monitoring

**Relevant Section**: Section 5 患者認証, Section 7 セキュリティ要件

---

### 2.2 Implement Audit Logging for Medical Record Access

**Problem**: No audit trail design for tracking who accessed patient medical records and when.

**Rationale**:
- Legal compliance requirement for medical systems (HIPAA, GDPR Article 15)
- Essential for investigating unauthorized access incidents
- Patients may have legal right to see access logs for their records

**Recommended Countermeasures**:
1. Create `audit_logs` table:
   ```sql
   CREATE TABLE audit_logs (
     id BIGSERIAL PRIMARY KEY,
     user_id BIGINT NOT NULL,
     user_type VARCHAR(20) NOT NULL, -- patient/doctor/admin
     action VARCHAR(50) NOT NULL, -- VIEW/CREATE/UPDATE/DELETE
     resource_type VARCHAR(50) NOT NULL, -- medical_record/patient/appointment
     resource_id BIGINT NOT NULL,
     ip_address VARCHAR(45),
     accessed_at TIMESTAMP NOT NULL,
     INDEX idx_resource (resource_type, resource_id),
     INDEX idx_user (user_id, accessed_at)
   );
   ```
2. Log all medical record access (READ operations, not just modifications)
3. Implement `/api/v1/patients/{id}/access-log` endpoint for patients to view their access history
4. Retain audit logs for 7 years (common medical records retention requirement)
5. Set up CloudWatch alarms for suspicious patterns (e.g., doctor accessing 100+ records in 1 hour)

**Relevant Section**: Section 4 データモデル, Section 6 ロギング方針

---

### 2.3 Add Data Retention and Deletion Policy

**Problem**: No design for handling data retention periods or patient data deletion requests (GDPR "right to erasure").

**Rationale**:
- Medical records have legal retention requirements (typically 5-10 years depending on jurisdiction)
- Patients may request data deletion under privacy regulations
- Conflict between "right to erasure" and medical records retention laws must be resolved

**Recommended Countermeasures**:
1. Implement soft delete mechanism:
   - Add `deleted_at` column to `patients` and `medical_records` tables
   - Archived records remain in database but are inaccessible via normal APIs
2. Create data retention policy:
   - Active patient accounts: retain indefinitely while account is active
   - Inactive accounts (no login for 3 years): prompt patient to confirm account retention
   - Medical records: retain for 10 years after last visit (configurable per jurisdiction)
3. Implement `/api/v1/patients/{id}/data-export` endpoint for GDPR data portability
4. Document data retention policy in privacy policy and system documentation
5. Implement scheduled job to anonymize/archive records past retention period

**Relevant Section**: Section 4 データモデル, Section 1 主要機能

---

### 2.4 Implement CSRF Protection for State-Changing Operations

**Problem**: No CSRF (Cross-Site Request Forgery) protection mechanism is documented for state-changing API endpoints.

**Rationale**:
- State-changing operations (appointment booking, record updates, payment) are vulnerable to CSRF attacks
- Even with JWT authentication, CSRF attacks can succeed if tokens are stored in cookies or localStorage
- High impact: attackers could create fraudulent appointments, modify medical records, or trigger payments

**Recommended Countermeasures**:
1. Implement Double Submit Cookie pattern:
   - Generate random CSRF token on login
   - Send as cookie (`SameSite=Strict`) and require client to echo in `X-CSRF-Token` header
2. Validate CSRF token for all POST/PUT/DELETE requests in Spring Security filter
3. Alternative: Use stateless CSRF token (HMAC of session ID + timestamp)
4. Ensure `SameSite=Strict` attribute on all cookies (session, CSRF token)
5. Document CSRF protection in Section 5 認証・認可方式

**Relevant Section**: Section 5 API設計, Section 2 Spring Boot 3.2

---

### 2.5 Define S3 Bucket Security Configuration

**Problem**: S3 usage for medical images and test results is mentioned (Section 2) but security configuration is not specified.

**Rationale**:
- Medical images and test results are highly sensitive PHI
- Misconfigured S3 buckets are a common source of data breaches
- Public access to medical documents would be catastrophic compliance violation

**Recommended Countermeasures**:
1. S3 bucket configuration:
   - Block all public access (S3 Block Public Access enabled)
   - Enable server-side encryption (SSE-S3 or SSE-KMS with customer-managed key)
   - Enable versioning for accidental deletion protection
   - Enable access logging to separate audit bucket
2. Access control:
   - Use pre-signed URLs (15-minute expiration) for patient downloads
   - ECS task IAM role should have least-privilege S3 permissions (specific bucket/prefix only)
   - Implement bucket policy denying unencrypted uploads
3. Data lifecycle:
   - Transition to S3 Glacier after 1 year (if retention policy allows)
   - Delete or archive after retention period expires
4. Add S3 security configuration to Section 3 インフラ設計

**Relevant Section**: Section 2 ストレージ, Section 3 全体構成

---

### 2.6 Implement Database Connection Security

**Problem**: No mention of database connection security (encryption in transit, connection pooling limits) in Section 2.

**Rationale**:
- Unencrypted database connections expose patient data to network sniffing attacks
- Unlimited connection pooling can lead to connection exhaustion DoS
- Database credentials transmitted in plain text are vulnerable to interception

**Recommended Countermeasures**:
1. Enable PostgreSQL SSL/TLS connections (require mode):
   ```properties
   spring.datasource.url=jdbc:postgresql://host:5432/db?ssl=true&sslmode=require
   ```
2. Configure connection pool limits (HikariCP):
   - Maximum pool size: 20 connections per instance
   - Connection timeout: 30 seconds
   - Idle timeout: 10 minutes
3. Use RDS IAM authentication as alternative to password-based auth (rotates credentials automatically)
4. Implement connection retry logic with exponential backoff
5. Document in Section 2 データベース

**Relevant Section**: Section 2 PostgreSQL 15, Section 3 アーキテクチャ設計

---

### 2.7 Add Dependency Vulnerability Scanning

**Problem**: No process for scanning third-party libraries for known vulnerabilities is documented.

**Rationale**:
- Spring Boot, React, and other dependencies may contain known CVEs
- Medical systems are high-value targets requiring proactive vulnerability management
- Regulatory compliance often requires vulnerability scanning

**Recommended Countermeasures**:
1. Integrate OWASP Dependency-Check into Maven/Gradle build:
   ```xml
   <plugin>
     <groupId>org.owasp</groupId>
     <artifactId>dependency-check-maven</artifactId>
     <executions>
       <execution>
         <goals><goal>check</goal></goals>
       </execution>
     </executions>
   </plugin>
   ```
2. Fail builds on high/critical severity CVEs
3. Use npm audit for frontend dependencies
4. Implement automated dependency updates (Dependabot or Renovate)
5. Document vulnerability scanning in Section 6 テスト方針

**Relevant Section**: Section 2 主要ライブラリ, Section 6 テスト方針

---

### 2.8 Define WAF Rules for Common Attack Patterns

**Problem**: CloudFront + WAF is mentioned (Section 3) but no WAF rule configuration is specified.

**Rationale**:
- WAF without proper rules provides minimal protection
- Medical systems face SQL injection, XSS, and DDoS attacks
- AWS WAF Managed Rules provide pre-configured protection for common threats

**Recommended Countermeasures**:
1. Enable AWS Managed Rules:
   - `AWSManagedRulesCommonRuleSet` (OWASP Top 10)
   - `AWSManagedRulesKnownBadInputsRuleSet` (known malicious patterns)
   - `AWSManagedRulesSQLiRuleSet` (SQL injection)
2. Custom rules:
   - Block requests without `User-Agent` header
   - Rate limiting: 100 requests per 5 minutes per IP for authentication endpoints
   - Geo-blocking (if service is Japan-only)
3. Configure WAF logging to S3 for security analysis
4. Set up CloudWatch alarms for blocked request spikes
5. Document WAF configuration in Section 3 全体構成

**Relevant Section**: Section 3 CloudFront + WAF

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Multi-Factor Authentication (MFA) Requirement

**Confirmation Reason**: Design does not specify whether MFA is required for doctor/admin accounts. Given the sensitivity of medical data and elevated privileges, MFA significantly reduces account takeover risk.

**Options and Trade-offs**:
- **Option A: Mandatory MFA for doctors and admins**
  - Pros: Strong protection against credential theft, compliance best practice
  - Cons: Additional implementation effort, may impact user experience
  - Recommendation: Use TOTP (Time-based One-Time Password) via apps like Google Authenticator
- **Option B: Optional MFA**
  - Pros: Lower implementation effort, better user acceptance initially
  - Cons: Many users won't enable it, leaving accounts vulnerable
- **Option C: Risk-based MFA**
  - Pros: Balance security and UX (prompt MFA only for suspicious logins)
  - Cons: More complex implementation, requires anomaly detection system

**Recommended**: Option A for admin accounts (mandatory), Option C for doctor accounts (risk-based)

---

### 3.2 End-to-End Encryption for Medical Records

**Confirmation Reason**: Current design specifies database-level AES-256 encryption (Section 7), but end-to-end encryption (where records are encrypted with patient's key) is not mentioned.

**Options and Trade-offs**:
- **Option A: Database-level encryption only (current design)**
  - Pros: Simpler implementation, doctors/admins can access records for legitimate operations
  - Cons: Database compromise or insider threat exposes all records
- **Option B: End-to-end encryption with patient-held keys**
  - Pros: Maximum privacy, even database administrators cannot read records
  - Cons: Key management complexity, patients may lose keys, emergency access challenges
- **Option C: Hybrid approach with key escrow**
  - Pros: Balance privacy and operational needs, emergency access possible
  - Cons: Escrow authority becomes single point of trust

**Recommended**: Option A for production medical system (doctors must be able to access records), with strong access controls and audit logging. Option B only if regulatory requirements mandate it.

---

### 3.3 Patient Consent Management for Data Sharing

**Confirmation Reason**: The design mentions inter-clinic sharing (`is_shared` flag) but lacks explicit patient consent workflow.

**Options and Trade-offs**:
- **Option A: Opt-in consent (explicit patient approval required before each share)**
  - Pros: Maximum patient control, clear compliance with privacy laws
  - Cons: May slow down emergency medical situations, administrative overhead
- **Option B: Opt-out consent (sharing enabled by default, patient can revoke)**
  - Pros: Facilitates continuous care across clinics
  - Cons: May not comply with strict privacy regulations (GDPR)
- **Option C: Emergency override with post-access notification**
  - Pros: Allows emergency access, maintains audit trail
  - Cons: Potential for abuse, requires strong monitoring

**Recommended**: Option A with emergency override capability (requires two doctor signatures + notification to patient within 24 hours)

---

## 4. Positive Evaluation (good points)

### 4.1 Strong Password Hashing with bcrypt

The design appropriately specifies bcrypt with cost factor 12 for password hashing (Section 7 セキュリティ要件). This is significantly more secure than legacy hashing algorithms (MD5, SHA-1) and provides adequate protection against brute-force attacks. The cost factor of 12 provides good balance between security and performance.

---

### 4.2 HTTPS Enforcement with TLS 1.2+

All communications are specified to use HTTPS with TLS 1.2 or higher (Section 7). This provides strong protection for data in transit, including patient credentials, medical records, and payment information. The use of CloudFront as CDN with TLS termination is appropriate for the scale.

---

### 4.3 Multi-Region Database Backup Strategy

The design includes daily PostgreSQL backups with 30-day retention (Section 7 可用性・スケーラビリティ). This provides good protection against data loss from operational errors, ransomware attacks, or infrastructure failures. The 30-day retention period allows recovery from delayed-discovery incidents.

---

### 4.4 API Rate Limiting

The specification of 60 requests per minute per user (Section 7) demonstrates awareness of DoS protection. Using Redis for rate limiting (Section 2) is an appropriate choice for distributed rate limiting across multiple ECS instances. This provides basic protection against API abuse.

---

### 4.5 Role-Based Access Control (RBAC)

The design clearly defines three roles (patient/doctor/admin) with appropriate privilege separation (Section 5 認証・認可方式). Patients can only access their own data, doctors have elevated privileges for their patients, and admins have system-wide access. This principle of least privilege reduces the impact of compromised accounts.
