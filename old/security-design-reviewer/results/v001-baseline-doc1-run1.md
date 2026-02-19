# Security Design Review: MediConnect システム設計書

## Summary

This review evaluates the MediConnect electronic medical records and telemedicine platform design document from a security architecture perspective. MediConnect handles highly sensitive medical information (PHI/PII) subject to Japanese healthcare regulations. Multiple critical and significant security gaps were identified.

---

## Critical Issues

### CRIT-1: JWT Token Storage in localStorage — XSS Exposure of Medical Credentials

**Section**: 5.1 認証フロー (Step 4)

**Issue**: The design explicitly stores JWT access tokens in `localStorage`. localStorage is accessible to any JavaScript running on the page, making tokens directly exfiltrable via XSS attacks.

**Impact**: If any XSS vulnerability exists in the React frontend (including third-party scripts, CDN-injected content, or browser extensions), an attacker can steal all active JWT tokens. For a medical platform with 5,000 concurrent users, this represents a mass credential theft vector enabling unauthorized access to patient medical records, diagnoses, prescriptions, and insurance data — all classified as highly sensitive PHI.

**Why this is critical**: The combination of (a) high-sensitivity medical data, (b) multi-tenant architecture where one token breach can expose an entire clinic's patient population, and (c) 30-day refresh tokens means a single XSS incident has prolonged and wide-reaching impact.

**Countermeasures**:
- Store access tokens in memory (JavaScript variable) only; never in localStorage or sessionStorage
- Store refresh tokens in HttpOnly, Secure, SameSite=Strict cookies to prevent JavaScript access
- Implement Content Security Policy (CSP) headers to limit XSS impact

---

### CRIT-2: CORS Wildcard (`*`) on Medical API — Credential Leakage Across Origins

**Section**: 7.3 CORS設定

**Issue**: The design sets `Access-Control-Allow-Origin: *` for the API Gateway, deferred to "if necessary" in production. A wildcard CORS policy allows any origin to make cross-origin requests to the API.

**Impact**: Combined with localStorage token storage (CRIT-1), a malicious website can directly call the MediConnect API using tokens obtained via XSS or CSRF. Even without XSS, wildcard CORS enables cross-site request attacks against authenticated sessions. For a medical platform, this could allow unauthorized third-party sites to exfiltrate patient records.

**Why this is critical**: The "we'll fix it in production" approach is a documented anti-pattern. Medical systems must have strict origin controls from day one because data leakage during development/staging can also be a compliance violation.

**Countermeasures**:
- Define an explicit allowlist of permitted origins (e.g., `https://app.mediconnect.example.com`) from the start
- Never use wildcard for APIs that handle authenticated sessions or sensitive data
- Ensure `Access-Control-Allow-Credentials: true` is never combined with a wildcard origin

---

### CRIT-3: No CSRF Protection on State-Changing Medical Operations

**Section**: 7.4 セッション系 API の保護

**Issue**: The design explicitly defers CSRF protection for state-changing operations — including prescription issuance (`POST /api/v1/prescriptions`) and patient information updates (`PUT /api/v1/patients/{id}`) — as "out of scope for the current phase."

**Impact**: Without CSRF protection, a malicious website can trick an authenticated doctor into submitting a forged prescription or modifying patient records. In a medical context, this could result in fraudulent prescription issuance — a patient safety issue and potential legal violation under Japanese pharmaceutical regulations.

**Why this is critical**: Prescription issuance and patient record modification are high-impact, irreversible operations. CSRF is a well-understood, easily mitigated threat; deferring it entirely for these endpoints is not acceptable for a medical system.

**Countermeasures**:
- Implement CSRF tokens (e.g., Double Submit Cookie pattern) or enforce SameSite=Strict cookie attributes for all state-changing endpoints before launch
- At minimum, require the `Origin` or `Referer` header to match expected values as a fallback check

---

### CRIT-4: Doctor Role Can Access All Patients Without Ownership Verification

**Section**: 5.2 認可モデル

**Issue**: The design explicitly states: "doctor ロールは `patient_id` パラメータによるフィルタリングなしに patient-service の全患者データを参照できる設計とする" (Doctor role can access all patient data without filtering by patient_id).

**Impact**: In a multi-tenant medical system, a doctor at Clinic A should only access patients assigned to or consulting with them. The current design allows any doctor — across all tenants — to access any patient's medical records, diagnoses, prescriptions, and personal information. This violates the principle of minimum necessary access fundamental to healthcare privacy law, and contradicts the stated requirement to comply with Japanese Ministry of Health guidelines.

**Why this is critical**: This is a design-level authorization flaw enabling systematic data exposure. A compromised doctor account, or a malicious insider, can access the entire patient database. This likely violates Japan's Act on the Protection of Personal Information (個人情報保護法) and healthcare-specific guidelines.

**Countermeasures**:
- Implement patient-doctor relationship verification: doctors can only access records of patients who have a current or historical treatment relationship
- Add doctor_id filtering at the query level in patient-service
- Log and alert on cross-tenant access patterns

---

### CRIT-5: No Rate Limiting on Authentication Endpoints — Brute Force Exposure

**Section**: 8.5 認証エンドポイント保護

**Issue**: The design explicitly states no call limits on `/api/v1/auth/login` citing "high availability priority." No mention of rate limiting for `/api/v1/auth/refresh` either.

**Impact**: Unlimited login attempts enable brute-force and credential-stuffing attacks. Medical staff accounts — particularly doctors — provide access to the entire patient record database. A successful brute-force on one account exposes all patients associated with that doctor (or, given CRIT-4, all patients in the system).

**Why this is critical**: Rate limiting and brute-force protection are baseline security controls for any authentication system. The stated justification ("high availability") is a false trade-off: properly implemented rate limiting (per IP, per account) does not impair legitimate availability.

**Countermeasures**:
- Implement per-account lockout or exponential backoff after N failed attempts (e.g., 5 attempts → 15-minute lockout)
- Implement per-IP rate limiting at API Gateway level (e.g., AWS WAF rate-based rules)
- Add CAPTCHA or step-up verification for repeated failures
- Apply equivalent rate limiting to `/api/v1/auth/refresh` and password reset endpoints (if applicable)

---

## Significant Issues

### SIG-1: VPC Internal Traffic Transmitted in Plaintext

**Section**: 6.1 通信の暗号化

**Issue**: The design states VPC internal communications are transmitted in plaintext: "VPC 内部の通信については内部ネットワークであるため平文で行う."

**Impact**: Internal traffic includes service-to-service calls carrying medical record data, database queries containing PHI, and Redis cache entries with session tokens. If any component within the VPC is compromised (container breakout, SSRF exploitation, compromised dependency), all inter-service traffic is exposed without any additional barriers. In a Fargate multi-tenant environment, lateral movement is a realistic threat model.

**Countermeasures**:
- Enforce TLS for all service-to-service communication (mutual TLS preferred for microservices)
- Enforce TLS for application-to-database connections (PostgreSQL SSL mode = verify-full)
- Enforce TLS/TLS-encrypted connections for Redis (AWS ElastiCache supports TLS)
- Use AWS PrivateLink with TLS for internal AWS service endpoints

---

### SIG-2: Application-Level Encryption Explicitly Rejected for Sensitive Medical Data

**Section**: 6.2 保存データの暗号化

**Issue**: The design explicitly states that additional application-level encryption for medical records (診断結果・処方内容) will not be implemented, relying solely on RDS volume encryption.

**Impact**: RDS AES-256 encryption protects against physical disk theft but does not protect against application-level attacks — a compromised database connection, SQL injection, or insider threat with database access can read all medical data in plaintext. For PHI including diagnoses, SOAP notes, and prescriptions, defense-in-depth encryption is standard practice.

**Countermeasures**:
- Implement column-level encryption for the most sensitive fields (diagnosis, soap_note, medications JSONB)
- Use application-managed encryption keys stored separately in AWS KMS with per-tenant key isolation
- Consider envelope encryption to align with multi-tenant data isolation requirements

---

### SIG-3: Frontend-Only Input Validation — Backend Injection Risk

**Section**: 7.1 入力検証方針

**Issue**: The design specifies that input validation is performed only at the frontend, with the backend performing only basic JSON schema type checks.

**Impact**: Frontend validation is trivially bypassed by sending API requests directly (curl, Postman, or a malicious client). The backend processes medical data including SOAP notes (free text), medications (JSONB), and patient demographics — all stored in PostgreSQL. Without server-side sanitization, SQL injection through ORM parameter binding failures, NoSQL injection in JSONB fields, and stored XSS in medical record fields are all realistic risks.

**Countermeasures**:
- Implement comprehensive server-side validation for all inputs, independent of frontend validation
- Apply input length limits, character whitelisting, and semantic validation (e.g., date ranges, enum values for gender/role)
- Use parameterized queries throughout; never construct SQL from user input
- Sanitize all free-text fields before storage to prevent stored XSS

---

### SIG-4: Refresh Token Design Allows Session Fixation and Single-Key Collision

**Section**: 5.3 セッション管理

**Issue**: Refresh tokens are stored in Redis keyed by `user_id`. This means each user has at most one valid refresh token at a time. However, if a user logs in from multiple devices, the previous token is silently overridden without invalidation of the old token.

**Impact**: (a) An attacker who obtains a refresh token can use it until the user next logs in from another device, at which point the legitimate user is silently logged out. (b) Conversely, a user who suspects compromise cannot revoke specific sessions — they can only log out from their current device, which overwrites the Redis entry, potentially disrupting other legitimate sessions. For doctors conducting video consultations, unexpected session invalidation is a patient safety concern.

**Countermeasures**:
- Key refresh tokens by `user_id + device_id` or use a token family approach
- Maintain a set of valid refresh tokens per user to support multiple devices
- Implement token rotation: each refresh generates a new refresh token and invalidates the previous one
- Add an explicit "revoke all sessions" capability for compromised account recovery

---

### SIG-5: PII in Logs — No Governance Policy

**Section**: 6.3 個人情報の取り扱い

**Issue**: The design states that logging of PII-containing information is "left to engineer judgment" (エンジニアの判断に委ねる運用).

**Impact**: Without an explicit policy, patient names, insurance numbers, medical record contents, and other PHI are likely to appear in application logs in CloudWatch Logs. CloudWatch Logs may have broader access than the production database, and log data often has weaker retention and access controls. This is a compliance risk under Japan's healthcare data regulations.

**Countermeasures**:
- Define an explicit PII logging prohibition policy: patient identifiers, medical content, insurance numbers must never appear in logs
- Use structured logging with allowlisted fields only
- Implement log scrubbing/masking in the logging middleware for any field that may contain PHI
- Define log retention periods and access controls for CloudWatch Logs

---

### SIG-6: S3 File Access Control Not Specified — Direct URL Access Risk

**Section**: 4.1, 7.2, 6.2

**Issue**: The prescriptions table stores `pdf_url` as a VARCHAR field pointing to S3. The design does not specify whether S3 objects are private, or how access is controlled. Direct URL access to medical documents is not addressed.

**Impact**: If S3 URLs are public or predictable, any person with a URL (obtained via log exposure, network interception, or link sharing) can access patient prescriptions and medical documents without authentication. S3 URLs are often shared via email or messaging and can persist beyond the intended audience.

**Countermeasures**:
- Set all S3 buckets to private (Block Public Access enabled)
- Generate pre-signed URLs with short expiry (e.g., 15 minutes) for each authorized file access request
- Verify the requesting user's authorization to access the specific patient's documents before issuing a pre-signed URL
- Enable S3 access logging and CloudTrail for all file access events

---

## Moderate Issues

### MOD-1: Access Token Lifetime Too Long (24 Hours)

**Section**: 5.1 認証フロー

**Issue**: Access tokens are valid for 24 hours. If a token is compromised (e.g., via CRIT-1 localStorage theft), it remains valid for up to 24 hours with no revocation mechanism described.

**Countermeasures**: Reduce access token lifetime to 15-30 minutes. Implement token revocation via a deny-list in Redis for compromised tokens.

---

### MOD-2: File Upload — Type and Size Restrictions Deferred

**Section**: 7.2 ファイルアップロード

**Issue**: File type and size restrictions for the `/api/v1/files/upload` endpoint are deferred to the implementation phase. Virus scanning is mentioned but without specifying whether it is synchronous (blocking) or asynchronous.

**Countermeasures**: Define explicit allowlists of permitted MIME types (e.g., image/jpeg, image/png, application/pdf) and maximum file sizes before implementation. If virus scanning is asynchronous, quarantine uploaded files until scanning completes. Store uploads in a separate S3 bucket isolated from application assets.

---

### MOD-3: Third-Party Dependency Vulnerability Management Deferred

**Section**: 8.2 サードパーティ依存関係

**Issue**: Vulnerability scanning for dependencies is deferred to the operational phase. Twilio Video SDK v2.27.0 is a specific pinned version with no update policy defined.

**Countermeasures**: Integrate automated dependency scanning (e.g., AWS CodeGuru, Snyk, or GitHub Dependabot) into the CI/CD pipeline from the start. Define an SLA for critical vulnerability patching (e.g., 72 hours for CVSS 9+).

---

### MOD-4: Audit Log Scope Insufficient for Medical Compliance

**Section**: 8.3 監査ログ

**Issue**: Audit logs record user ID, operation type, and timestamp. However, for medical compliance, the log scope does not explicitly include: patient record access events, prescription issuance events, failed authorization attempts, or data export events.

**Countermeasures**: Define an explicit audit event taxonomy covering: authentication success/failure, patient record access (which patient, by which user), prescription creation/modification, administrative operations (user role changes), and authorization failures. Store audit logs in a write-once, tamper-evident store separate from application logs.

---

### MOD-5: No Multi-Factor Authentication Design

**Section**: 5.1 認証フロー

**Issue**: The authentication design uses only email/password. No MFA is described for any user role, including doctors who access all patient medical records.

**Countermeasures**: Implement TOTP-based MFA (e.g., Google Authenticator compatible) as mandatory for doctor and admin roles. Consider step-up authentication for high-risk operations (prescription issuance, patient record export).

---

## Positive Aspects

- **bcrypt with cost factor 12**: Appropriate password hashing strength for a medical system.
- **JWT with tenant_id claim + schema isolation**: Multi-tenant architecture with JWT-based tenant identification and schema separation is a sound foundational design.
- **AWS Secrets Manager**: Correct approach for secret management; avoids hardcoded credentials.
- **RDS and S3 encryption at rest**: Baseline encryption coverage is present.
- **Network segmentation**: RDS and Redis in private subnets, NAT Gateway for outbound-only external access — correct perimeter design.
- **ウイルススキャン on file upload**: Including virus scanning for uploaded files is a good practice.

---

## STRIDE Threat Coverage Summary

| Threat | Coverage in Design | Gap |
|--------|-------------------|-----|
| Spoofing | Partial — JWT + bcrypt present; no MFA, no rate limiting | MOD-5, CRIT-5 |
| Tampering | Missing — no CSRF protection, frontend-only validation | CRIT-3, SIG-3 |
| Repudiation | Partial — basic audit logs present; scope insufficient | MOD-4 |
| Information Disclosure | Critical gap — localStorage tokens, wildcard CORS, plaintext VPC, no field encryption | CRIT-1, CRIT-2, SIG-1, SIG-2 |
| Denial of Service | Not addressed — no rate limiting on any endpoint | CRIT-5 |
| Elevation of Privilege | Critical gap — doctor accesses all patients without restriction | CRIT-4 |
