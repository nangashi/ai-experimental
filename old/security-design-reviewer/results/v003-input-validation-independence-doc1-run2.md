# Security Design Review: MediConnect システム設計書

## Executive Summary

This review evaluates the MediConnect electronic medical records and telemedicine platform design. The system handles highly sensitive medical and personal information (PHI/PII) in a multi-tenant healthcare context. Multiple critical and significant security issues were identified, several of which represent systemic design weaknesses requiring immediate remediation.

---

## Critical Issues

### C-01: Frontend-Only Input Validation (P09 Pattern — Missing Independent Server-Side Control)

**Location:** Section 7.1 入力検証方針

**Issue:** The design states: "すべてのAPIリクエストにおいて、フロントエンドで入力検証が完了した状態でAPIに送信される設計とする。バックエンドでは基本的な型チェック（JSONスキーマバリデーション）のみ実施する。"

**Independence Assessment:** Server-side validation as described is NOT independent. It is explicitly conditioned on frontend validation having "completed." Backend type checking alone does not constitute independent server-side validation — it provides no protection against:
- Injection attacks (SQL injection, NoSQL injection, command injection, XSS payload injection)
- Malicious clients that bypass frontend validation entirely (curl, Burp Suite, custom API clients)
- Business logic validation bypass (e.g., unauthorized patient_id values, malformed medical record references)

**Impact:** In a medical records system storing diagnosis content, prescriptions, and PHI, injection attacks through inadequately validated backend inputs could lead to complete database compromise, data exfiltration, or data corruption. The design explicitly exposes `diagnosis` (TEXT), `soap_note` (TEXT), and `medications` (JSONB) fields — all high-value injection targets.

**Countermeasures:**
1. Mandate independent server-side input validation for all API endpoints, regardless of client-side validation state
2. Implement input sanitization and parameterized queries at the persistence layer
3. Define explicit validation rules per endpoint (length limits, allowed characters, format constraints) in the design document
4. Treat client-side validation as UX enhancement only, never a security control

---

### C-02: localStorage Token Storage — XSS Exposure of Access Tokens

**Location:** Section 5.1 認証フロー (Step 4)

**Issue:** "クライアントはアクセストークンを `localStorage` に保存し" — access tokens stored in localStorage are fully accessible to JavaScript, making them vulnerable to theft via XSS attacks.

**Independence Assessment:** This creates a cascading failure: any XSS vulnerability (which becomes more likely given the inadequate server-side input validation in C-01) immediately grants an attacker the ability to steal JWT tokens with a 24-hour validity window, enabling full session hijacking.

**Impact:** A stolen JWT grants complete impersonation capability, including access to all patient medical records the user is authorized to view. In a healthcare system, this constitutes a reportable PHI breach.

**Countermeasures:**
1. Store access tokens in `HttpOnly`, `Secure`, `SameSite=Strict` cookies instead of localStorage
2. If localStorage usage is required for architectural reasons, reduce token lifetime significantly (15 minutes) and implement refresh token rotation
3. Implement Content Security Policy (CSP) headers to limit XSS impact

---

### C-03: CSRF Protection Absent for State-Changing Endpoints (P04 Pattern — JWT Does Not Prevent CSRF)

**Location:** Section 7.4 セッション系 API の保護

**Issue:** The design explicitly defers CSRF protection: "state-changingな操作に対するリクエスト保護の設計は現フェーズのスコープ外とする."

**Independence Assessment:** If tokens are stored in cookies (the recommended fix for C-02), CSRF protection becomes mandatory. JWT-based authentication does not inherently prevent CSRF — a CSRF attack causes the victim's browser to automatically attach cookie-stored credentials to the forged request. The CSRF protection mechanism must be independent; it cannot rely on "JWT exists" as a sufficient control.

Specifically at risk:
- `POST /api/v1/prescriptions` — prescription issuance by physician
- `PUT /api/v1/patients/{id}` — patient record modification
- `POST /api/v1/consultations` — consultation creation
- `POST /api/v1/patients/{id}/records` — medical record creation

**Impact:** Attackers can forge requests that create fraudulent prescriptions or modify patient records if a logged-in physician visits a malicious page.

**Countermeasures:**
1. Implement CSRF tokens (synchronizer token pattern) for all state-changing endpoints
2. Alternatively, use `SameSite=Strict` cookie attribute (independent CSRF control that does not rely on token verification)
3. Remove the "スコープ外" deferral — CSRF protection must be in-scope before production deployment

---

### C-04: Wildcard CORS Configuration

**Location:** Section 7.3 CORS設定

**Issue:** "`Access-Control-Allow-Origin: *` を設定する。本番環境では必要に応じて絞り込みを検討する。"

**Independence Assessment:** The CORS misconfiguration is described as a deliberate design choice for "開発効率," with production restriction treated as optional ("必要に応じて"). This is not a missing independent control — it is an explicitly permissive configuration with no design commitment to restrict it.

**Impact:** Wildcard CORS combined with cookie-based credential transmission can enable cross-origin data exfiltration. Even without credentials, open CORS enables any origin to make API requests, removing the browser-enforced origin boundary.

**Countermeasures:**
1. Define an explicit allowlist of permitted origins in the design document
2. Never use `Access-Control-Allow-Origin: *` for endpoints that handle PHI or authenticated sessions
3. Specify `Access-Control-Allow-Credentials: false` for any genuinely public endpoints

---

### C-05: Doctor Role — Missing Patient Ownership Enforcement (Broken Access Control)

**Location:** Section 5.2 認可モデル

**Issue:** "doctor ロールは `patient_id` パラメータによるフィルタリングなしに patient-service の全患者データを参照できる設計とする。"

**Independence Assessment:** The authorization check at the role level ("doctor role allowed") is not independent from the resource-level check ("is this doctor authorized to access this specific patient"). The role check passes, but resource ownership verification is explicitly absent.

**Impact:** In a multi-tenant healthcare system, any authenticated physician can access any patient's records across all tenants. This is a fundamental HIPAA/medical privacy violation in addition to a security flaw. Combined with the tenant isolation design using JWT `tenant_id` claims, a compromised physician account or a JWT manipulation vulnerability could expose all patient data across all tenants.

**Countermeasures:**
1. Implement resource-level authorization: verify doctor-patient relationship or assignment for every record access request
2. For multi-tenant isolation, enforce `tenant_id` verification at the service layer, not only in JWT parsing
3. Document explicit authorization rules per endpoint in the design (e.g., "doctor can access patient/{id} only if doctor_patient_assignment record exists")

---

## Significant Issues

### S-01: No Rate Limiting on Authentication Endpoints

**Location:** Section 8.5 認証エンドポイント保護

**Issue:** "`/api/v1/auth/login` エンドポイントについては、高可用性を優先するため呼び出し制限は設けない設計とする。"

**Impact:** The endpoint is fully open to brute force and credential stuffing attacks. Medical staff credentials, once compromised, grant access to patient records. The justification ("高可用性を優先") conflates availability with unlimited request acceptance — these are not equivalent.

**Independence Assessment:** The "account lock 別途検討" is not an independent control: account locking applied after N failures is reactive and requires tracking, while rate limiting is proactive and stateless. Neither substitutes for the other.

**Countermeasures:**
1. Implement IP-based rate limiting (e.g., 10 attempts per minute per IP) independently from account lockout
2. Implement account-based lockout after 5-10 failed attempts with CAPTCHA or notification-based unlock
3. Add rate limiting to `/api/v1/auth/refresh` and password reset endpoints

---

### S-02: VPC Internal Communication — Plaintext for Sensitive Medical Data

**Location:** Section 6.1 通信の暗号化

**Issue:** "VPC 内部の通信については内部ネットワークであるため平文で行う。"

**Impact:** Internal network compromise (lateral movement, rogue container, misconfigured security group) exposes all inter-service communication in plaintext. Medical records, PHI, and prescription data transiting between microservices would be fully readable. Japanese healthcare guidelines (厚生労働省) require appropriate protection of medical information.

**Countermeasures:**
1. Implement TLS for internal service-to-service communication (mTLS preferred for microservice authentication)
2. At minimum, encrypt application-layer data for medical records and PHI in transit between services
3. Document the threat model justification if internal plaintext is accepted as a known risk

---

### S-03: File Upload — Type and Size Controls Deferred

**Location:** Section 7.2 ファイルアップロード

**Issue:** "ファイル種別・サイズの制限は実装フェーズで決定する。"

**Independence Assessment:** Virus scanning is designed (positive), but it is not independent — it does not prevent malicious file types from being stored or served. File type validation and size limits are independent controls that must function regardless of whether virus scanning succeeds.

**Impact:** Without file type restrictions, an attacker can upload web shells, scripts, or polyglot files that could be executed if served from S3 via CloudFront. Without size limits, storage exhaustion (DoS) is possible.

**Countermeasures:**
1. Define allowed MIME types (e.g., DICOM for medical images, PDF for prescriptions) in the design
2. Set explicit size limits per file type
3. Store uploads in a separate S3 bucket with no public execute permissions and serve only through pre-signed URLs

---

### S-04: PII in Logs — Uncontrolled

**Location:** Section 6.3 個人情報の取り扱い

**Issue:** "患者情報（PII）を含むログ出力については、エンジニアの判断に委ねる運用とする。"

**Impact:** Inconsistent PII handling in logs creates a secondary data exposure vector. CloudWatch Logs may accumulate patient names, insurance numbers, diagnoses, and other PHI without controlled access policies. This violates data minimization principles and Japanese privacy regulations.

**Countermeasures:**
1. Define an explicit log data classification policy: which fields are permitted/prohibited in logs
2. Implement structured logging with PII field masking at the framework level
3. Apply IAM-based access controls to CloudWatch log groups containing application logs

---

### S-05: JWT Token Lifetime — 24 Hours Excessive

**Location:** Section 5.1 認証フロー

**Issue:** Access token validity of 24 hours is excessively long for a healthcare system handling PHI.

**Impact:** Stolen or leaked tokens remain valid for up to 24 hours. Combined with localStorage storage (C-02), a single XSS exploitation yields persistent access throughout a full workday.

**Countermeasures:**
1. Reduce access token lifetime to 15-30 minutes
2. Use silent refresh (background token renewal) to maintain user session without requiring re-login
3. Implement token revocation mechanism (currently not designed)

---

## Moderate Issues

### M-01: Audit Log Insufficient for Security Events

**Location:** Section 8.3 監査ログ

**Issue:** Audit log includes "操作ユーザーID、操作種別、タイムスタンプ" but does not explicitly design for security-relevant events: authentication failures, permission denials, cross-patient record access, prescription issuance, or admin privilege use.

**Countermeasures:**
1. Define specific security event categories that must be logged
2. Include: failed authentication attempts, authorization failures, PHI access events (who accessed which patient record), prescription issuance, admin actions
3. Ensure audit logs are write-protected (separate from application logs)

---

### M-02: Dependency Vulnerability Management Not Designed

**Location:** Section 8.2 サードパーティ依存関係

**Issue:** "脆弱性情報の定期チェック方針は今後の運用フェーズで策定する予定" — no automated vulnerability scanning is designed.

**Countermeasures:**
1. Integrate automated dependency scanning (e.g., npm audit, Dependabot, Snyk) into CI/CD pipeline
2. Define SLA for vulnerability remediation by severity (e.g., critical: 24h, high: 7 days)

---

### M-03: Redis Session Key Design — Single-Key Per User

**Location:** Section 5.3 セッション管理

**Issue:** "ユーザーIDをキーとしてトークン値を管理" — single key per user means a new login overwrites the previous session, preventing multi-device usage and making it impossible to selectively revoke a specific device session.

**Countermeasures:**
1. Use composite key: `{user_id}:{device_id}` or `{user_id}:{token_id}` to support multi-device sessions
2. Design explicit selective revocation capability for compromised sessions

---

## Positive Aspects

- bcrypt with cost factor 12 for password hashing is appropriate
- AWS Secrets Manager for credential management is a sound design
- RDS Multi-AZ and RDS encryption (AES-256) provide baseline data protection
- S3 server-side encryption (SSE-S3) is configured
- Virus scanning on file uploads is explicitly designed
- Multi-schema tenant isolation provides structural data separation
- RDS and Redis placement in VPC private subnets limits direct exposure

---

## Summary Table

| ID | Severity | Section | Issue |
|----|----------|---------|-------|
| C-01 | Critical | 7.1 | Frontend-only input validation; server-side not independent |
| C-02 | Critical | 5.1 | localStorage token storage; XSS-vulnerable |
| C-03 | Critical | 7.4 | CSRF protection absent; JWT alone insufficient |
| C-04 | Critical | 7.3 | Wildcard CORS with no production commitment to restrict |
| C-05 | Critical | 5.2 | Doctor role accesses all patients without ownership check |
| S-01 | Significant | 8.5 | No rate limiting on authentication endpoints |
| S-02 | Significant | 6.1 | VPC internal communication unencrypted |
| S-03 | Significant | 7.2 | File type/size controls deferred to implementation |
| S-04 | Significant | 6.3 | PII in logs left to individual engineer discretion |
| S-05 | Significant | 5.1 | 24-hour access token lifetime excessive for PHI system |
| M-01 | Moderate | 8.3 | Audit log does not cover required security events |
| M-02 | Moderate | 8.2 | Dependency vulnerability management not designed |
| M-03 | Moderate | 5.3 | Single Redis key per user prevents selective revocation |
