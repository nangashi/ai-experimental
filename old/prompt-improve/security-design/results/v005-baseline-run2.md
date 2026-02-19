# Security Design Review: Online Medical Consultation Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple STRIDE categories lack concrete countermeasures, especially repudiation and elevation of privilege risks |
| Authentication & Authorization Design | 2 | JWT in 24-hour tokens without refresh mechanism, no token storage specification, insufficient authorization checks |
| Data Protection | 3 | AES-256 encryption for sensitive data is good, but lacks key management design and encryption-at-rest details |
| Input Validation Design | 1 | No input validation policy described, high risk of SQL injection and XSS attacks |
| Infrastructure & Dependencies | 3 | Modern stack with some security features (WAF, HTTPS), but lacks secret management and dependency update policy |
| **Overall** | **2.2** | |

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Design is Vulnerable to Theft and Abuse

**Problem**: The design specifies JWT tokens with 24-hour expiration (Section 3: "JWTトークン発行（有効期限24時間）"), but does not specify secure storage method or refresh token mechanism.

**Impact**:
- If tokens are stored in localStorage (common React pattern), they are vulnerable to XSS attacks
- 24-hour expiration means stolen tokens remain valid for extended periods
- No refresh token design means users must re-authenticate frequently or security is compromised
- Single JWT compromise allows complete account takeover for 24 hours

**Recommended Countermeasures**:
1. **Storage**: Use HttpOnly + Secure + SameSite=Strict cookies for token storage (prevents JavaScript access)
2. **Token Lifetime**: Reduce access token expiration to 15 minutes
3. **Refresh Token**: Implement refresh token pattern (7-day expiration) with rotation mechanism
4. **Token Revocation**: Add token revocation mechanism (store active tokens in Redis with TTL)

**Relevant Section**: Section 3 (アーキテクチャ設計 - データフロー), Section 5 (API設計 - 認証・認可方式)

### 1.2 No Input Validation Design Against Injection Attacks

**Problem**: The design document contains no mention of input validation, SQL injection prevention, or XSS countermeasures despite handling sensitive medical data through user-facing forms (診療予約, 問診票入力, etc.).

**Impact**:
- **SQL Injection**: Attacker could extract all patient medical records (100万人の患者データ) through malicious query parameters or POST data
- **XSS**: Stored XSS in medical records or patient names could steal JWT tokens from other users
- **HIPAA/Medical Privacy Violation**: Unvalidated input could lead to massive personal health information breach

**Recommended Countermeasures**:
1. **ORM Usage**: Confirm Spring Boot uses JPA/Hibernate with parameterized queries (prevent SQL injection)
2. **Input Validation**: Add Bean Validation (@Valid, @Pattern, @Size) for all API request DTOs
3. **Output Escaping**: Enable Spring Security's XSS protection headers and escape all user-generated content in responses
4. **API Layer Validation**:
   - Email format validation (`@Email`)
   - Phone number format validation (regex pattern)
   - Text field length limits (name: 100 chars, diagnosis: 10,000 chars)
   - Date range validation (appointment_time must be future date)
5. **Medical Record Validation**: Sanitize `diagnosis` and `prescription` TEXT fields to prevent stored XSS

**Relevant Section**: Section 5 (API設計), Section 6 (実装方針)

### 1.3 Authorization Checks are Insufficient

**Problem**: The authorization design states "患者: 自身の情報のみアクセス可能" but provides no implementation details on how this is enforced at the API layer.

**Impact**:
- **Insecure Direct Object Reference (IDOR)**: Patient A could access Patient B's medical records by simply changing the `patient_id` query parameter
- Example: `GET /api/v1/medical-records?patient_id=9999` with Patient A's JWT could expose Patient B's records
- Similar IDOR risk exists for `GET /api/v1/patients/{id}`, `DELETE /api/v1/appointments/{id}`

**Recommended Countermeasures**:
1. **JWT Claims Validation**: Include `patient_id` or `user_id` in JWT payload and validate against requested resource
2. **Service Layer Authorization**:
   ```java
   @PreAuthorize("@authService.canAccessPatient(#patientId, authentication)")
   public Patient getPatient(Long patientId) { ... }
   ```
3. **Medical Records Access Control**: Add database-level row filtering:
   ```sql
   SELECT * FROM medical_records WHERE patient_id = :requestor_patient_id AND id = :record_id
   ```
4. **Doctor Authorization**: Verify doctor has active relationship with patient before allowing medical record creation
5. **Shared Records (`is_shared` flag)**: Define clear access control rules for shared medical records across clinics

**Relevant Section**: Section 5 (API設計 - エンドポイント一覧, 認証・認可方式)

### 1.4 No Audit Logging for Medical Data Access

**Problem**: The logging policy (Section 6) only mentions INFO/WARN/ERROR levels for technical operations, with no mention of audit logging for medical data access.

**Impact**:
- **Compliance Violation**: Medical data access must be auditable for HIPAA/GDPR/Japanese medical privacy regulations
- **Incident Response**: Cannot investigate unauthorized access or data breaches
- **Legal Liability**: No evidence trail for patient consent or doctor access to medical records

**Recommended Countermeasures**:
1. **Audit Log Events**:
   - All medical record access (who, when, which record, IP address)
   - Patient information modifications
   - Authorization failures (attempted IDOR attacks)
   - Admin actions (account creation, role changes)
2. **Immutable Audit Trail**: Store audit logs in separate append-only S3 bucket with Object Lock
3. **Log Retention**: 7 years minimum (medical record retention requirement)
4. **Monitoring**: CloudWatch alarms for unusual access patterns (e.g., doctor accessing 100+ records in 1 minute)

**Relevant Section**: Section 6 (実装方針 - ロギング方針)

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Add Rate Limiting for Authentication Endpoints

**Suggestion**: The design mentions "APIレート制限: 1分間に60リクエスト/ユーザー" but authentication endpoints should have stricter limits to prevent brute-force attacks.

**Rationale**:
- Login endpoints are unauthenticated and vulnerable to credential stuffing
- 60 req/min allows 3,600 password attempts per hour
- Medical platform with 100万患者 is high-value target for attackers

**Recommended Countermeasures**:
1. **Endpoint-Specific Limits**:
   - `POST /api/v1/auth/login`: 5 attempts per 15 minutes per IP
   - `POST /api/v1/auth/register`: 3 attempts per hour per IP
   - Account lockout after 5 failed login attempts (30-minute cooldown)
2. **IP-Based Rate Limiting**: Use Redis for distributed rate limiting across ECS tasks
3. **CAPTCHA**: Add reCAPTCHA v3 after 3 failed login attempts
4. **Monitoring**: Alert on repeated 429 responses from same IP range

**Relevant Section**: Section 7 (非機能要件 - セキュリティ要件)

### 2.2 Specify Secret Management Design

**Problem**: The design mentions "jjwt 0.11" for JWT but does not specify how JWT signing keys, database passwords, or AWS credentials are managed.

**Rationale**:
- Hardcoded secrets in application.properties are major security risk
- ECS Fargate needs secure way to access secrets at runtime
- Key rotation is essential for long-lived systems

**Recommended Countermeasures**:
1. **AWS Secrets Manager**: Store all secrets (DB password, JWT signing key, API keys) in Secrets Manager
2. **ECS Task Role**: Grant ECS tasks IAM role to read specific secrets (principle of least privilege)
3. **Environment Variables**: Inject secrets as environment variables at container startup
4. **Key Rotation**:
   - JWT signing key: rotate every 90 days (implement key versioning to support gradual migration)
   - Database credentials: use AWS RDS IAM authentication or rotate every 30 days
5. **No Secrets in Code**: Add pre-commit hooks to scan for accidentally committed secrets

**Relevant Section**: Section 2 (技術スタック), Section 3 (インフラ・デプロイ環境)

### 2.3 Add Multi-Factor Authentication (MFA) for Medical Staff

**Suggestion**: Require MFA for doctor and admin accounts to prevent credential compromise.

**Rationale**:
- Medical staff accounts have access to sensitive patient data (5,000医師・看護師)
- Single-factor authentication (password only) is insufficient for high-privilege accounts
- Doctors may use shared computers in clinics

**Recommended Countermeasures**:
1. **TOTP-Based MFA**: Implement Time-based One-Time Password (Google Authenticator, Authy)
2. **Mandatory for Roles**: Require MFA for `doctor` and `admin` roles (optional for `patient`)
3. **Backup Codes**: Provide 10 single-use backup codes during MFA enrollment
4. **Session Management**: Shorten session timeout for MFA-authenticated sessions to 8 hours
5. **MFA Enforcement**: Add `mfa_enabled` flag to `doctors` table and block login if MFA is not configured

**Relevant Section**: Section 5 (API設計 - 患者認証)

### 2.4 Implement Database Encryption Key Management

**Problem**: The design specifies "DB内の機密情報（診断内容、処方箋）はAES-256で暗号化" but does not describe key storage, rotation, or field-level encryption implementation.

**Rationale**:
- Application-level encryption requires secure key management
- Key compromise would decrypt all historical medical records
- Different patients may require different encryption keys (data isolation)

**Recommended Countermeasures**:
1. **AWS KMS Integration**: Use AWS Key Management Service for master key storage
2. **Envelope Encryption**:
   - Store data encryption keys (DEK) in database, encrypted by KMS master key
   - Decrypt DEK at application layer when accessing medical records
3. **Per-Clinic Keys**: Use separate DEKs per clinic_id for data isolation
4. **Key Rotation**: Rotate master key annually, re-encrypt DEKs on rotation
5. **Implementation**: Use Spring Boot Jasypt library for transparent field-level encryption
6. **RDS Encryption**: Also enable AWS RDS encryption-at-rest (separate layer from application encryption)

**Relevant Section**: Section 7 (非機能要件 - セキュリティ要件)

### 2.5 Add CORS Policy Design

**Problem**: No Cross-Origin Resource Sharing (CORS) policy is specified for the React frontend and React Native app.

**Rationale**:
- Misconfigured CORS (e.g., `Access-Control-Allow-Origin: *`) allows malicious sites to make authenticated requests
- Medical data APIs should only be accessible from trusted origins

**Recommended Countermeasures**:
1. **Strict Origin Whitelist**:
   ```java
   @CrossOrigin(origins = {"https://patient.example.com", "https://doctor.example.com"})
   ```
2. **No Wildcard**: Never use `*` for medical APIs
3. **Credentials**: Set `Access-Control-Allow-Credentials: true` only for authenticated endpoints
4. **Preflight Caching**: Set `Access-Control-Max-Age: 3600` to reduce preflight OPTIONS requests
5. **Mobile App**: React Native uses native HTTP client (no CORS), but API should validate `Origin` header

**Relevant Section**: Section 3 (アーキテクチャ設計)

### 2.6 Specify Dependency Vulnerability Scanning

**Problem**: The design lists specific library versions (Spring Boot 3.2, jjwt 0.11) but has no policy for security updates or vulnerability scanning.

**Rationale**:
- Third-party libraries have frequent security vulnerabilities (e.g., Log4Shell)
- Medical platform must respond quickly to critical CVEs
- Outdated dependencies increase attack surface

**Recommended Countermeasures**:
1. **Automated Scanning**: Integrate Dependabot or Snyk into CI/CD pipeline
2. **Update Policy**:
   - Critical CVEs: patch within 48 hours
   - High severity: patch within 1 week
   - Medium/Low: address in next sprint
3. **Version Pinning**: Use exact versions in `pom.xml` (not `LATEST` or ranges)
4. **Container Scanning**: Scan Docker images for OS-level vulnerabilities (AWS ECR Image Scanning)
5. **SBOM Generation**: Generate Software Bill of Materials for compliance audits

**Relevant Section**: Section 2 (技術スタック - 主要ライブラリ)

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Shared Medical Records (`is_shared` flag) Access Control

**Confirmation Reason**: The `medical_records` table has `is_shared` BOOLEAN flag for "他院共有", but the authorization model for cross-clinic access is unclear.

**Options and Trade-offs**:
1. **Option A: Explicit Patient Consent**:
   - Require patient to approve each clinic that can view their shared records
   - Store consent in `medical_record_sharing` junction table (patient_id, clinic_id, record_id, consent_date)
   - **Trade-off**: More secure but adds friction to emergency care scenarios

2. **Option B: Network-Based Sharing**:
   - All clinics in the platform can view `is_shared=true` records
   - Log all cross-clinic access for audit
   - **Trade-off**: Simpler workflow but higher privacy risk

3. **Option C: Role-Based Sharing**:
   - Only emergency departments can access shared records without consent
   - Regular clinics require explicit patient authorization
   - **Trade-off**: Balances emergency access with privacy

**Recommendation**: Clarify the intended sharing model and implement appropriate access controls in the authorization layer.

**Relevant Section**: Section 4 (データモデル - medical_records)

### 3.2 Payment Processing Security

**Confirmation Reason**: The design mentions "医療費支払い（クレジットカード/銀行振込）" but does not specify PCI DSS compliance or payment gateway integration.

**Options and Trade-offs**:
1. **Option A: Third-Party Payment Gateway (Stripe, PAY.JP)**:
   - Use tokenization (never store card numbers)
   - Gateway handles PCI DSS compliance
   - **Trade-off**: Third-party dependency, transaction fees

2. **Option B: Direct Payment Processing**:
   - Store payment information in system
   - Requires PCI DSS Level 1 certification (~$200k+ annual cost)
   - **Trade-off**: Full control but massive compliance burden

**Recommendation**: Confirm payment integration design. If handling card data directly, add PCI DSS requirements to security specifications.

**Relevant Section**: Section 1 (概要 - 主要機能の一覧)

### 3.3 Data Retention and Right to Erasure

**Confirmation Reason**: The design specifies 30-day database backups but does not address patient data deletion requests (GDPR "Right to be Forgotten", Japanese APPI compliance).

**Options and Trade-offs**:
1. **Option A: Soft Delete with Retention Period**:
   - Add `deleted_at` timestamp to patients table
   - Retain data for 7 years (medical record requirement), then hard delete
   - **Trade-off**: Balances legal obligations with privacy rights

2. **Option B: Immediate Hard Delete**:
   - Permanently delete patient data on request
   - Anonymize medical records (replace patient_id with null or pseudonym)
   - **Trade-off**: Satisfies privacy but may violate medical record retention laws

3. **Option C: Anonymization**:
   - Replace PII with hashed identifiers
   - Retain anonymized records for research/compliance
   - **Trade-off**: Technical complexity, potential re-identification risk

**Recommendation**: Define data retention policy that complies with both medical regulations and privacy laws.

**Relevant Section**: Section 7 (非機能要件 - 可用性・スケーラビリティ)

## 4. Positive Evaluation (good points)

### 4.1 Strong Password Hashing

The design appropriately uses bcrypt with cost factor 12 for password storage (Section 7: "パスワード: bcryptでハッシュ化（コストファクタ12）"). This is significantly better than SHA-256 or MD5, and the cost factor is appropriate for medical application security.

### 4.2 TLS and HTTPS Enforcement

All communication is enforced over HTTPS with TLS 1.2+ (Section 7: "通信: 全通信HTTPS（TLS 1.2以上）"), and the architecture includes CloudFront + WAF for DDoS protection. The layered approach (CloudFront → ALB → API Gateway) provides defense in depth.

### 4.3 Data Encryption at Rest

The design includes AES-256 encryption for sensitive medical data (診断内容, 処方箋) in the database. This addresses regulatory requirements for protecting personal health information beyond just access controls.

### 4.4 Separation of Concerns in Architecture

The microservices-style separation (患者サービス, カルテサービス, 予約サービス) limits blast radius if one service is compromised. Each service can have independent security policies and resource isolation.

### 4.5 Modern, Maintained Technology Stack

The stack uses current versions with active security support: Java 17 (LTS), Spring Boot 3.2, PostgreSQL 15, React 18. This reduces exposure to known vulnerabilities in outdated frameworks.
