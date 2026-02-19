# Security Design Review: MediConnect システム設計書
<!-- prompt: v005-variant-audit-log-gap-first, document: test-document-1, run: 2 -->

---

## Critical Issues

### C-1: JWT Token Storage in localStorage — XSS Exposure Risk
**Section**: 5.1 認証フロー

The design specifies that access tokens are stored in `localStorage`. localStorage is accessible to any JavaScript running in the browser, making it vulnerable to cross-site scripting (XSS) attacks. An attacker who achieves XSS can exfiltrate all stored tokens and fully impersonate the user.

**Impact**: Complete session hijacking. In a medical platform handling patient records, prescriptions, and PHI, this constitutes a critical data breach vector.

**Countermeasures**:
- Store access tokens in memory (JavaScript variable) and refresh tokens in `HttpOnly`, `Secure`, `SameSite=Strict` cookies.
- If `localStorage` must be used, implement strict Content Security Policy (CSP) headers to reduce XSS risk.

---

### C-2: CORS Wildcard (`Access-Control-Allow-Origin: *`) on API Exposing PHI
**Section**: 7.3 CORS設定

The design sets `Access-Control-Allow-Origin: *` explicitly as the production-default configuration ("本番環境では必要に応じて絞り込みを検討する"). For an API that handles protected health information (PHI) and uses `Authorization` headers, wildcard CORS means any web page can make credentialed cross-origin requests. This enables malicious third-party sites to read API responses.

**Impact**: Sensitive patient data (medical records, prescriptions, insurance numbers) accessible to attacker-controlled origins.

**Countermeasures**:
- Define an explicit allowlist of trusted origins before production launch.
- Never use wildcard with credentialed requests; browsers block it by spec, but the intent to use `*` reflects a systemic gap in security posture.

---

### C-3: CSRF Protection Explicitly Deferred for State-Changing Operations
**Section**: 7.4 セッション系 API の保護

The design explicitly excludes CSRF protection for `POST /api/v1/prescriptions` and `PUT /api/v1/patients/{id}` as out of scope for the current phase. These endpoints modify sensitive medical data and patient records.

**Impact**: CSRF attacks can cause unauthorized prescription issuance or patient record modification under a legitimate session.

**Countermeasures** (two independent findings as per Defense Layer Separation rule):

**C-3a: Missing CSRF Token Design**
No CSRF token mechanism (Synchronizer Token Pattern or Double Submit Cookie) is designed for state-changing endpoints. This must be an independent finding.

**C-3b: JWT Statelessness Does Not Substitute CSRF Mitigation**
The design relies on JWT in `Authorization` headers; however, this only protects against form-based CSRF if the client sends the header explicitly. If tokens are in cookies (which may be a remediation for C-1), CSRF tokens or `SameSite` cookie attributes become mandatory. Even with `Authorization` header approach, the explicit deferral of CSRF controls creates a structural gap that must be reported independently.

---

### C-4: No Rate Limiting on Authentication Endpoints
**Section**: 8.5 認証エンドポイント保護

The design explicitly states that `/api/v1/auth/login` has no rate limiting due to high availability priority. The `/api/v1/auth/refresh` endpoint has no stated protection either.

**Impact**: Brute force and credential stuffing attacks against all user accounts (patients, doctors, staff, admins) are unmitigated. For a platform handling PHI with 5,000 concurrent users, this is a direct path to account compromise.

**Countermeasures**:
- Implement rate limiting per IP and per account on `/auth/login` (e.g., 5 failures per 15 minutes triggers temporary lockout or CAPTCHA).
- Apply rate limiting on `/auth/refresh` to prevent token refresh abuse.
- High availability and rate limiting are not mutually exclusive; distributed rate limiting via Redis (already in stack) is feasible.

---

### C-5: Internal VPC Communication in Plaintext
**Section**: 6.1 通信の暗号化

The design explicitly states that VPC internal communications are transmitted in plaintext ("平文で行う"). This affects: auth-service ↔ patient-service, consultation-service ↔ prescription-service, and all services ↔ PostgreSQL/Redis.

**Impact**: An attacker who achieves lateral movement within the VPC (e.g., via a compromised container) can intercept all internal traffic, including PHI transmitted between services and database credentials flowing in queries. For a medical platform with regulatory obligations, this is a critical gap.

**Countermeasures**:
- Enable TLS for all inter-service communication within ECS (mutual TLS via service mesh or at minimum one-way TLS).
- Enable TLS for RDS connections (`ssl=true` in connection string with certificate validation).
- Enable encryption in transit for Redis (ElastiCache supports TLS).

---

## Significant Issues

### S-1: Doctor Role Can Access All Patients Across Tenant — Missing Ownership Check
**Section**: 5.2 認可モデル

The design states: "doctor ロールは `patient_id` パラメータによるフィルタリングなしに patient-service の全患者データを参照できる設計とする". In a multi-tenant system, this means any doctor at any tenant can potentially access any patient record.

**Impact**: A doctor at Clinic A accessing patient records of Clinic B violates tenant isolation, HIPAA-equivalent obligations under Japanese medical law, and the principle of minimum necessary access.

**Countermeasures**:
- Enforce `tenant_id` filtering from the JWT claim on all patient data access, regardless of role.
- For doctor role, additionally enforce that the doctor has an active care relationship with the patient before granting record access.

---

### S-2: Audit Log — Authentication Failure Events Not Specified (Independent Finding)
**Section**: 8.3 監査ログ

**Presence check (Step 1)**: The design specifies that logs include "操作ユーザーID、操作種別、タイムスタンプ" but does not explicitly require recording of **authentication failure events** (failed login attempts, invalid token usage).

**Finding**: Authentication failures are a required security event for detecting brute force attacks and unauthorized access attempts. Their absence from the audit log specification is an independent gap.

**Impact**: No detection capability for credential stuffing, brute force, or account enumeration attacks. Regulatory compliance under Japanese medical information guidelines requires auditability of access attempts.

**Countermeasures**:
- Explicitly specify that authentication failures (wrong password, expired token, invalid token) must be recorded as security audit events with: timestamp, source IP, user identifier (if determinable), failure reason.

---

### S-3: Audit Log — Permission/Role Change Events Not Specified (Independent Finding)
**Section**: 8.3 監査ログ

**Presence check (Step 1)**: The audit log design does not mention recording of **permission or role change events** (user role assignments, privilege modifications).

**Finding**: Role changes (e.g., granting `admin` or `doctor` role) are critical security events. Their absence from the log specification is an independent gap, separate from S-2.

**Impact**: Privilege escalation attacks (unauthorized role assignment) would be undetectable. Post-incident forensics cannot determine when and by whom role changes were made.

**Countermeasures**:
- Explicitly require that all role/permission change events are recorded with: actor user ID, target user ID, previous role, new role, timestamp.

---

### S-4: Audit Log — Sensitive Data Access Events Not Specified (Independent Finding)
**Section**: 8.3 監査ログ

**Presence check (Step 1)**: The audit log design does not mention recording of **sensitive data access events** (PHI access, medical record reads, prescription downloads).

**Finding**: Access to patient medical records, prescriptions, and insurance information constitutes sensitive data access that must be logged for audit purposes under medical information governance requirements. This is an independent gap from S-2 and S-3.

**Impact**: Unauthorized access to patient records (e.g., by a doctor accessing non-assigned patients as in S-1) cannot be detected or investigated retroactively.

**Countermeasures**:
- Explicitly specify that access to `GET /api/v1/patients/{id}`, `GET /api/v1/patients/{id}/prescriptions`, and `GET /api/v1/patients/{id}/records` must generate audit log entries including: accessor user ID, patient ID, resource type, timestamp.

---

### S-5: Audit Log Quality — Security Logs Not Separated from Application Logs
**Section**: 8.3 監査ログ (quality evaluation after gap reporting)

The design consolidates all logs into CloudWatch Logs as application logs without distinguishing security audit logs from general operational logs. No log retention policy specific to security audit purposes is defined.

**Impact**: Security audit logs mixed with application logs are harder to query, protect, and comply with retention obligations. Tampering with or accidental deletion of application log streams would also affect audit trails.

**Countermeasures**:
- Create a dedicated CloudWatch log group for security audit events, separate from application logs.
- Define retention period for security audit logs (at minimum matching the 5-year medical record retention requirement).
- Consider sending security audit logs to an immutable destination (CloudTrail, S3 with Object Lock) to prevent tampering.

---

### S-6: Frontend-Only Input Validation Design
**Section**: 7.1 入力検証方針

The design specifies that "フロントエンドで入力検証が完了した状態でAPIに送信される設計" and backend only performs basic JSON schema validation. This is insufficient as a security control.

**Finding (Defense Layer Separation — two independent items):**

**S-6a: Frontend-Only Input Validation**
Frontend validation can be bypassed by any attacker sending requests directly to the API. All injection attack prevention (SQL injection, command injection, XSS payload storage) must not rely on frontend validation.

**S-6b: Insufficient Server-Side Injection Defense**
The design does not specify server-side parameterized query enforcement, ORM injection prevention, or output encoding policies. These must be independently designed and are not covered by JSON schema type checking alone.

---

### S-7: File Upload — Type and Size Restrictions Not Designed
**Section**: 7.2 ファイルアップロード

The design defers file type validation and size limits to the implementation phase ("実装フェーズで決定する"). While virus scanning is mentioned, the absence of file type allowlisting and size limits at design stage represents a security gap.

**Impact**: Malicious file uploads (polyglot files, web shells disguised as images) and denial-of-service via large file uploads are not mitigated by design.

**Countermeasures**:
- Define allowlist of permitted MIME types and file extensions (e.g., JPEG, PNG, PDF only).
- Specify maximum file size limits.
- Design storage isolation (no public S3 bucket access, pre-signed URL generation for download).

---

## Moderate Issues

### M-1: Access Token Lifetime 24 Hours — Excessive for PHI Platform
**Section**: 5.1 認証フロー

A 24-hour access token lifetime means a stolen token remains valid for up to a day without revocation capability (JWT is stateless).

**Impact**: If a token is compromised (via XSS, logging, or interception), the attacker has extended unauthorized access to patient records.

**Countermeasures**:
- Reduce access token lifetime to 15–30 minutes for a medical platform.
- Implement token revocation via a blocklist (Redis, already in stack) for emergency revocation.

---

### M-2: PII in Logs — Engineer Discretion Without Policy
**Section**: 6.3 個人情報の取り扱い

The design states that PII inclusion in logs is left to "エンジニアの判断". This provides no guardrails against PHI being logged in plaintext.

**Impact**: Patient names, diagnoses, and insurance numbers may appear in CloudWatch Logs, accessible to operational staff and potentially included in log exports, violating data protection obligations.

**Countermeasures**:
- Define explicit policy: PII/PHI fields are prohibited in application logs.
- Implement log scrubbing middleware to detect and mask PHI patterns (names, insurance numbers, diagnosis codes) before logging.

---

### M-3: Dependency Vulnerability Management Deferred
**Section**: 8.2 サードパーティ依存関係

Vulnerability scanning policy is deferred to the operational phase. The design uses Twilio Video SDK v2.27.0 and other fixed versions with no automated update or CVE monitoring process designed.

**Impact**: Known vulnerabilities in dependencies will go undetected until the operational policy is implemented, which may be after production launch.

**Countermeasures**:
- Integrate automated vulnerability scanning (e.g., `npm audit`, Dependabot, Snyk) into the CI/CD pipeline at design stage, not operational phase.
- Define SLA for critical CVE remediation (e.g., patch within 72 hours for CVSS 9.0+).

---

### M-4: Redis Session Key Design — Single Key Per User Allows Session Fixation
**Section**: 5.3 セッション管理

Refresh tokens are stored in Redis with "ユーザーIDをキーとして" — a single key per user. This means issuing a new refresh token overwrites the previous one, invalidating all other sessions. Conversely, it does not support multi-device sessions or concurrent session management.

**Impact**: A single compromised device logout does not invalidate other devices. Session fixation is possible if an attacker can set a known token value.

**Countermeasures**:
- Use a composite key (user_id + session_id) to support multi-device sessions.
- Store token hash rather than token value, and validate by comparison.
- Implement session enumeration endpoint for users to view and revoke individual sessions.

---

## Positive Aspects

- bcrypt with cost factor 12 for password hashing is appropriate.
- AWS Secrets Manager for secret management is a sound choice.
- Multi-schema tenant isolation at the database layer provides strong data separation.
- RDS AES-256 encryption at rest and S3 SSE are baseline-appropriate.
- Virus scanning on file uploads is a good control for malware prevention.
- Network security controls (private subnets for RDS/Redis, security groups) are appropriately designed.

---

## Summary Table

| ID | Severity | Issue |
|----|----------|-------|
| C-1 | Critical | JWT stored in localStorage (XSS exposure) |
| C-2 | Critical | CORS wildcard on PHI API |
| C-3a | Critical | No CSRF token design for state-changing endpoints |
| C-3b | Critical | JWT header reliance not sufficient as CSRF mitigation |
| C-4 | Critical | No rate limiting on authentication endpoints |
| C-5 | Critical | Internal VPC communication in plaintext |
| S-1 | Significant | Doctor role accesses all patients across tenant |
| S-2 | Significant | Auth failure events absent from audit log spec |
| S-3 | Significant | Role/permission change events absent from audit log spec |
| S-4 | Significant | Sensitive data access events absent from audit log spec |
| S-5 | Significant | Security logs not separated from application logs |
| S-6a | Significant | Frontend-only input validation |
| S-6b | Significant | No server-side injection defense design |
| S-7 | Significant | File upload type/size restrictions not designed |
| M-1 | Moderate | 24-hour access token lifetime excessive |
| M-2 | Moderate | PII in logs left to engineer discretion |
| M-3 | Moderate | Dependency vulnerability management deferred |
| M-4 | Moderate | Redis session key design limitations |
