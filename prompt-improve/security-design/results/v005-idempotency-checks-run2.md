# Security Architecture Review: オンライン診療予約・電子カルテ統合プラットフォーム

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple threat categories lack explicit mitigation design (Repudiation, DoS, Tampering) |
| Authentication & Authorization Design | 3 | JWT stored client-side with 24h expiration creates extended attack window; no refresh token rotation |
| Data Protection | 3 | AES-256 encryption mentioned but key management design is missing; S3 bucket security not specified |
| Input Validation Design | 2 | No validation policy for external inputs; injection prevention measures not described |
| Infrastructure & Dependencies | 3 | Spring Boot/jjwt versions specified but update policy and CVE monitoring not addressed |
| State Management & Idempotency | 2 | Critical state-changing operations (payment, appointment, prescription) lack idempotency design |
| Error Handling & Information Disclosure | 3 | Error response format shows error codes but detailed error content and logging security not addressed |
| **Overall** | **2.6** | |

## 1. Critical Issues (Design Modification Required)

### 1.1 Payment API Lacks Idempotency Protection

**Problem**: The payment functionality (Section 1.2.1 "医療費支払い") processes credit card payments but the API design (Section 5) does not mention idempotency keys or duplicate transaction prevention.

**Impact**: Network timeouts or client retries could cause duplicate charges, leading to:
- Financial loss for patients (double billing)
- Legal compliance issues under payment card industry (PCI) regulations
- Customer trust erosion and support burden

**Recommended Countermeasures**:
- Implement client-generated idempotency keys (UUID in `Idempotency-Key` request header)
- Store processed payment transaction IDs in Redis with 24-hour TTL
- For duplicate requests within TTL window, return cached response (HTTP 200 with original transaction result)
- For POST `/api/v1/payments`, respond with HTTP 409 Conflict if same request body received without idempotency key

**Relevant Section**: Section 1.2.1 (患者向け機能 - 医療費支払い), Section 5 (API設計)

### 1.2 Appointment Creation/Cancellation Lacks Idempotency Design

**Problem**: `POST /api/v1/appointments` and `DELETE /api/v1/appointments/{id}` endpoints have no protection against duplicate submissions mentioned in the design.

**Impact**:
- Duplicate appointment creation could overbook doctor schedules, causing operational chaos
- Duplicate cancellation requests could corrupt appointment status tracking
- Race conditions in multi-device scenarios (patient canceling from phone while family member confirms from web)

**Recommended Countermeasures**:
- For POST `/api/v1/appointments`: Implement idempotency keys or use database unique constraint on (`patient_id`, `doctor_id`, `appointment_time`, `status='pending'`)
- For DELETE: Make operation idempotent by design - return HTTP 204 No Content even if already cancelled (check current status, only log if already cancelled)
- Add optimistic locking using version column in appointments table to prevent race conditions

**Relevant Section**: Section 5.4 (予約 API), Section 4.3 (appointments テーブル)

### 1.3 Medical Record Creation Lacks Duplicate Prevention

**Problem**: `POST /api/v1/medical-records` (Section 5.3) allows doctors to create electronic medical records, but no idempotency mechanism prevents duplicate record creation from network retries.

**Impact**:
- Duplicate medical records for same visit could cause:
  - Medical errors (conflicting diagnoses in system)
  - Legal compliance issues (medical record integrity requirements)
  - Billing errors (duplicate billing codes)
- Cannot safely retry failed requests during critical care workflows

**Recommended Countermeasures**:
- Require client-provided idempotency key in request header
- Add database unique constraint on (`patient_id`, `doctor_id`, `visit_date`) if business rules allow
- Store idempotency key + response hash in Redis (7-day TTL for medical record creation window)
- Return HTTP 409 Conflict for duplicate medical record attempts with different content

**Relevant Section**: Section 5.3 (電子カルテ API), Section 4.2 (medical_records テーブル)

### 1.4 Error Messages May Leak Sensitive Information

**Problem**: Section 6.1 shows error response format but does not specify what information is safe to expose in the `"message"` field. Medical systems often leak:
- Patient existence (different errors for "patient not found" vs "access denied")
- Internal paths in stack traces
- Database schema details in SQL error messages
- Library version numbers in exception messages

**Impact**:
- Attackers gain reconnaissance information for targeted attacks (framework versions, database type)
- Privacy violations if error messages reveal patient data existence
- Compliance risk under medical privacy regulations (HIPAA-equivalent)

**Recommended Countermeasures**:
- Define error message classification policy:
  - **Client errors (4xx)**: Safe, generic messages only ("Invalid request", "Resource not found")
  - **Server errors (5xx)**: Generic message "Internal server error" with error tracking ID
- Implement centralized error mapper that sanitizes all exception details before response
- Log full exception details (stack trace, SQL queries, internal paths) to CloudWatch Logs with restricted access
- Use error code system (e.g., "ERR-1001") for customer support correlation without exposing internals
- Never include different error messages that reveal user existence (return same "Invalid credentials" for wrong email vs wrong password)

**Relevant Section**: Section 6.1 (エラーハンドリング方針)

### 1.5 JWT Token Storage Location Not Specified

**Problem**: Section 3.3 states JWT tokens are issued with 24-hour expiration, but the design does not specify where tokens are stored on the client side (localStorage, sessionStorage, cookies, or mobile secure storage).

**Impact**:
- If stored in localStorage/sessionStorage: Vulnerable to XSS attacks (attacker can steal token via injected JavaScript)
- 24-hour expiration extends damage window after token theft
- No refresh token design means users must re-authenticate daily (poor UX) or tokens stay valid too long (security risk)

**Recommended Countermeasures**:
- **For web**: Use HTTP-only cookies with `Secure`, `SameSite=Strict` attributes to prevent XSS/CSRF access
- **For mobile**: Use platform secure storage (iOS Keychain, Android Keystore)
- Implement short-lived access tokens (15 minutes) + long-lived refresh tokens (7 days) with rotation
- Refresh token rotation: Issue new refresh token on each refresh, invalidate old one
- Store refresh token mapping in Redis with user association for remote revocation capability

**Relevant Section**: Section 3.3 (データフロー), Section 5.1 (患者認証 API)

### 1.6 Medical Record Sharing Lacks Access Audit Trail

**Problem**: The `medical_records.is_shared` flag (Section 4.2) enables sharing records with other clinics, but the design does not describe:
- Who accessed shared records and when
- How to revoke sharing access
- Patient consent tracking for sharing

**Impact**:
- Cannot detect unauthorized access to sensitive medical data
- Legal compliance risk (medical privacy laws require access logging)
- Cannot fulfill patient requests to know who accessed their data
- No mechanism for patients to revoke sharing consent

**Recommended Countermeasures**:
- Create `medical_record_access_log` table with columns: (record_id, accessed_by_doctor_id, accessed_by_clinic_id, access_timestamp, access_type)
- Log every read access to shared medical records
- Add `shared_with_clinic_ids` JSON column or separate junction table to track specific sharing permissions
- Implement patient-facing UI to view access history and revoke sharing per clinic
- Require explicit patient consent (signed consent record) before setting `is_shared=true`

**Relevant Section**: Section 4.2 (medical_records テーブル)

## 2. Improvement Suggestions (Effective for Improving Design Quality)

### 2.1 No Rate Limiting for Authentication Endpoints

**Problem**: Section 7.2 mentions "APIレート制限: 1分間に60リクエスト/ユーザー" but does not specify separate, stricter limits for authentication endpoints (`/api/v1/auth/login`).

**Rationale**: Login endpoints are prime targets for credential stuffing and brute-force attacks. Generic 60 req/min limit is too permissive for authentication (allows 60 password attempts per minute).

**Recommended Countermeasures**:
- Configure stricter rate limiting for `/api/v1/auth/login`: 5 attempts per 15 minutes per email address
- Implement progressive delays after failed attempts (1st fail: no delay, 2nd: 2s, 3rd: 5s, 4th: 10s)
- Add IP-based rate limiting: 20 failed login attempts per hour from same IP triggers temporary block
- Consider CAPTCHA after 3 failed attempts from same IP
- Alert security team on sustained brute-force patterns (>100 failed attempts across multiple accounts from same IP)

**Relevant Section**: Section 5.1 (患者認証 API), Section 7.2 (セキュリティ要件)

### 2.2 Database Encryption Key Management Not Designed

**Problem**: Section 7.2 states "DB内の機密情報（診断内容、処方箋）はAES-256で暗号化" but does not specify:
- Where encryption keys are stored
- Key rotation policy
- Who has access to keys

**Rationale**: Encryption is ineffective if keys are stored in application code, environment variables, or database itself. Medical data encryption is likely required by regulations but key management is critical for compliance.

**Recommended Countermeasures**:
- Use AWS KMS (Key Management Service) for key storage and rotation
- Implement envelope encryption: Data encrypted with data encryption keys (DEKs), DEKs encrypted with KMS master key
- Enable automatic key rotation (annual rotation of master keys)
- Use separate KMS keys for different data classifications (patient demographics vs medical records)
- Restrict KMS key usage via IAM policies (only application service role can decrypt)
- Log all KMS decrypt operations to CloudTrail for audit

**Relevant Section**: Section 7.2 (セキュリティ要件 - データ暗号化)

### 2.3 S3 Bucket Security Configuration Missing

**Problem**: Section 2.3 mentions "AWS S3（医療画像、検査結果PDF）" but does not specify:
- Bucket access policies (public vs private)
- Encryption at rest
- Versioning and deletion protection
- Access logging

**Rationale**: Medical images and test results are highly sensitive PHI (Protected Health Information). Misconfigured S3 buckets are a common source of data breaches.

**Recommended Countermeasures**:
- Enable S3 bucket encryption at rest (SSE-KMS with dedicated medical data key)
- Block all public access at bucket policy level
- Use presigned URLs with 15-minute expiration for patient/doctor access
- Enable S3 access logging to separate audit bucket
- Enable versioning to protect against accidental deletion
- Configure lifecycle policy to transition old files to Glacier after 1 year (cost optimization + retention compliance)
- Add bucket policy requiring TLS (deny requests with `aws:SecureTransport: false`)

**Relevant Section**: Section 2.3 (インフラ・デプロイ環境)

### 2.4 No Input Validation Policy for External Inputs

**Problem**: Section 5 defines API endpoints but does not describe validation rules for user inputs (email format, phone number format, patient name length, diagnosis text sanitization).

**Rationale**: Lack of input validation enables:
- SQL injection (if ORM is bypassed or raw queries used)
- Stored XSS (if diagnosis/prescription text is not sanitized before storage and display)
- Data integrity issues (invalid email formats, phone numbers)

**Recommended Countermeasures**:
- Define validation rules for all API inputs:
  - **Email**: RFC 5322 regex validation, max 255 chars
  - **Phone**: E.164 format validation (country code required)
  - **Name fields**: Max 100 chars, block special chars except hyphens/apostrophes
  - **Diagnosis/prescription**: Max 10,000 chars, HTML entity encoding, block `<script>` tags
- Use Spring Boot's `@Valid` annotation with Jakarta Bean Validation constraints
- Implement custom validators for medical-specific fields (license_number format)
- Sanitize all text fields before database insertion using OWASP Java Encoder library
- For search functionality, use parameterized queries (JPA Criteria API or named parameters)

**Relevant Section**: Section 5 (API設計), Section 6.1 (エラーハンドリング方針)

### 2.5 No SQL Injection Prevention Measures Documented

**Problem**: The design specifies PostgreSQL (Section 2.2) and shows complex queries with patient_id filtering, but does not explicitly state SQL injection prevention measures.

**Rationale**: Even with modern ORMs, SQL injection is possible through:
- Raw query construction for complex reports
- Dynamic ORDER BY clauses in search functionality
- String concatenation in native queries

**Recommended Countermeasures**:
- Explicitly document policy: "All database queries must use JPA/Hibernate parameterized queries or Criteria API. Raw SQL prohibited except with security review."
- For unavoidable raw queries: Use Spring's `JdbcTemplate` with named parameters
- Enable Hibernate SQL logging in development to audit all generated queries
- Add code review checklist item: "Verify no string concatenation in database queries"
- Consider static analysis tools (SonarQube with SQL injection rules) in CI pipeline

**Relevant Section**: Section 2.2 (データベース), Section 4 (データモデル)

### 2.6 Third-Party Dependency Update Policy Missing

**Problem**: Section 2.4 specifies library versions (jjwt 0.11, React 18, Spring Boot 3.2) but does not describe:
- How often dependencies are updated
- Who monitors CVE announcements
- Process for emergency security patches

**Rationale**: Medical platforms are attractive targets. Delayed patching of known vulnerabilities (e.g., Spring4Shell, Log4Shell) can lead to breaches.

**Recommended Countermeasures**:
- Implement automated dependency scanning in CI/CD (GitHub Dependabot or Snyk)
- Define SLA for applying security patches:
  - **Critical CVE (CVSS 9.0+)**: 48 hours
  - **High CVE (CVSS 7.0-8.9)**: 7 days
  - **Medium CVE**: 30 days
- Subscribe to security mailing lists: Spring Security Advisories, React Security, PostgreSQL announce
- Quarterly dependency update review (minor version bumps for all libraries)
- Maintain dependency inventory document with version justifications

**Relevant Section**: Section 2.4 (主要ライブラリ), Section 6.4 (デプロイメント方針)

### 2.7 Medical License Verification Not Designed

**Problem**: The `doctors` table includes `license_number` (Section 4.4) but the design does not describe:
- How license numbers are verified during doctor registration
- Periodic re-verification of active licenses
- What happens if a license is revoked

**Rationale**: Allowing unlicensed individuals to create medical records or prescriptions has severe legal and patient safety implications.

**Recommended Countermeasures**:
- Integrate with government medical license verification API during doctor registration
- Store license verification status and verification date in doctors table
- Implement annual re-verification job (check license status with government registry)
- If license is revoked: Immediately disable doctor account, flag all their medical records for review, notify clinic administrator
- Add audit trail for all license verification checks

**Relevant Section**: Section 4.4 (doctors テーブル), Section 1.2.2 (医療機関向け機能)

### 2.8 No Session Revocation Mechanism Described

**Problem**: JWT tokens are issued with 24-hour expiration (Section 3.3), but the design does not describe how to revoke tokens before expiration (e.g., when user reports device theft, or admin needs to forcibly logout a user).

**Rationale**: Long-lived tokens without revocation capability mean:
- Stolen tokens remain valid until expiration
- Cannot respond to security incidents (compromised account)
- Regulatory requirement for immediate access termination may not be met

**Recommended Countermeasures**:
- Maintain session revocation list in Redis:
  - Key: `revoked:jwt:{jti}` (JWT ID claim)
  - Value: revocation timestamp
  - TTL: token expiration time
- On logout or admin-forced logout, add JWT ID to revocation list
- Middleware checks revocation list on each authenticated request (add <5ms latency with Redis)
- Add "logout all devices" functionality that revokes all tokens for a user
- For emergency revocation, support revoking all tokens issued before a specific timestamp

**Relevant Section**: Section 3.3 (データフロー), Section 5.1 (患者認証 API)

### 2.9 CloudFront WAF Rules Not Specified

**Problem**: Section 3.1 shows "CloudFront + WAF" in architecture diagram but does not specify what WAF rules are configured.

**Rationale**: WAF without proper rules provides false sense of security. Medical platforms should block common attack patterns.

**Recommended Countermeasures**:
- Enable AWS Managed Rules for WAF:
  - Core Rule Set (CRS) - blocks common exploits (SQLi, XSS)
  - Known Bad Inputs - blocks known malicious patterns
  - SQL Database protection rules
- Add custom rate limiting rules:
  - Block IPs with >100 requests per 5 minutes to auth endpoints
  - Block IPs with >1000 requests per 5 minutes globally
- Configure geo-blocking if service is Japan-only (block requests from non-Japan IPs)
- Enable WAF logging to S3 for security analysis
- Set up CloudWatch alarms for WAF block count spikes (potential attack indicator)

**Relevant Section**: Section 3.1 (全体構成), Section 2.3 (インフラ・デプロイ環境)

### 2.10 No Audit Logging for Administrative Actions

**Problem**: Section 1.2.3 describes admin functions (医療機関登録, 医師アカウント管理) but Section 6.2 logging policy does not mention audit logging for privileged operations.

**Rationale**: Administrative actions (creating doctor accounts, modifying patient records, accessing system statistics) should be audited for:
- Compliance requirements (medical data access tracking)
- Insider threat detection
- Forensic investigation after security incidents

**Recommended Countermeasures**:
- Create separate audit log stream in CloudWatch Logs for:
  - All admin API calls (who, what, when, from which IP)
  - Doctor account creation/modification/deletion
  - Clinic registration and configuration changes
  - Bulk data exports or access to patient lists
- Include in audit log: admin user ID, action type, target entity ID, IP address, timestamp, action result (success/failure)
- Set up CloudWatch Insights queries to detect anomalies (off-hours admin access, bulk patient record access)
- Retain audit logs for 7 years (common medical record retention requirement)
- Make audit logs immutable (write-only access, no deletion permitted)

**Relevant Section**: Section 1.2.3 (管理者機能), Section 6.2 (ロギング方針)

## 3. Confirmation Items (Requiring User Confirmation)

### 3.1 Password Policy Strength

**Current Design**: Section 4.1 shows passwords are hashed with bcrypt (cost factor 12), but no password complexity requirements are specified.

**Confirmation Needed**: What password policy should be enforced?

**Options and Trade-offs**:
- **Option A - Basic policy**: Min 8 characters, no complexity requirements
  - ✅ Better user experience (easier to remember)
  - ❌ Vulnerable to dictionary attacks
  - Suitable for: Low-risk patient accounts with email 2FA backup

- **Option B - Standard policy**: Min 10 characters, must include uppercase, lowercase, number
  - ✅ Balanced security and usability
  - ❌ Some users will use predictable patterns ("Password1")
  - Suitable for: Most production medical platforms

- **Option C - High security**: Min 14 characters, all character types, password strength meter, breach check (Have I Been Pwned API)
  - ✅ Strong protection against all password attacks
  - ❌ High user friction, potential accessibility issues
  - Suitable for: Doctor/admin accounts with access to sensitive data

**Recommendation**: Use Option B for patients, Option C for doctors/admins, and consider adding optional 2FA (TOTP) for enhanced security.

### 3.2 Data Residency and Compliance Framework

**Current Design**: Section 2.3 specifies "AWS（Tokyo Region）" but does not mention specific compliance requirements.

**Confirmation Needed**: What regulatory frameworks must this system comply with?

**Options and Trade-offs**:
- **Japan APPI (Act on the Protection of Personal Information)**: Requires consent for data sharing, purpose limitation, security measures
- **HIPAA-equivalent**: If serving international patients, may need HIPAA compliance (encrypted backups, access controls, audit logs)
- **ISO 27001/27799 (Health Informatics)**: Industry standard for medical information security

**Impact on Design**:
- APPI: Requires explicit consent tracking for medical record sharing (affects `is_shared` flag design)
- HIPAA: Requires BAA (Business Associate Agreement) with AWS, encrypted backups, access termination within 24h
- ISO 27799: Requires formal risk assessment documentation, incident response procedures

**Recommendation**: Clarify compliance requirements to design appropriate consent management, data retention policies, and audit mechanisms.

### 3.3 Medical Image Access Control

**Current Design**: S3 stores medical images and test result PDFs (Section 2.3), but access control mechanism is not described.

**Confirmation Needed**: How should access to S3 objects be controlled?

**Options and Trade-offs**:
- **Option A - Presigned URLs**: Backend generates time-limited URLs (15 min expiration) for authenticated requests
  - ✅ Simple implementation, works with CDN
  - ❌ URLs can be shared within expiration window
  - Suitable for: Low-risk images (X-rays visible to patient and their doctors)

- **Option B - Proxy through API**: All S3 access goes through backend API with authorization checks
  - ✅ Complete access control, audit trail
  - ❌ Increased backend load, slower performance for large files
  - Suitable for: Highly sensitive images requiring strict access control

- **Option C - Presigned URLs + Watermarking**: Presigned URLs with patient name watermarked on image
  - ✅ Prevents unauthorized sharing (watermark identifies leaker)
  - ❌ Additional processing overhead, permanent image modification
  - Suitable for: Environments with insider threat concerns

**Recommendation**: Start with Option A for MVP, evaluate Option B if audit requirements demand it.

## 4. Positive Evaluation (Security Strengths)

### 4.1 Strong Password Hashing

The design specifies bcrypt with cost factor 12 for password hashing (Section 4.1), which is appropriate for 2026 security standards. Bcrypt's adaptive cost factor provides future-proofing against increasing computational power.

### 4.2 TLS Encryption for All Communications

Section 7.2 mandates HTTPS (TLS 1.2+) for all communications, protecting data in transit. The CloudFront + ALB architecture (Section 3.1) ensures TLS termination at edge locations for performance.

### 4.3 Database Encryption at Rest

The design includes AES-256 encryption for sensitive fields (diagnosis, prescription) in Section 7.2, which meets industry standards for medical data protection.

### 4.4 Separation of Patient and Doctor Roles

The authentication/authorization design (Section 5.4) properly separates patient and doctor roles, with patients limited to their own data and doctors limited to assigned patients. This principle of least privilege reduces insider threat risk.

### 4.5 Automated Database Backups

Section 7.3 specifies daily PostgreSQL backups with 30-day retention, providing disaster recovery capability and protection against ransomware/accidental deletion.

### 4.6 Rate Limiting Infrastructure

The design includes Redis-based API rate limiting (Section 7.2: 60 req/min per user), providing basic DoS protection. The infrastructure choice (Redis) supports efficient rate limiting implementation.

### 4.7 Infrastructure as Code Readiness

The containerized architecture (Docker + ECS Fargate, Section 2.3) enables reproducible deployments and security configuration as code, reducing configuration drift risks.

### 4.8 Blue-Green Deployment Strategy

Section 6.4 describes blue-green deployment with rollback capability, enabling safe security patch deployment with minimal downtime risk.
