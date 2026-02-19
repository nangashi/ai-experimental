# Security Design Review: MediConnect システム設計書

**Reviewer Prompt:** v005-variant-audit-log-finding-separation
**Target Document:** test-document-1.md (MediConnect システム設計書)
**Run:** doc1-run2

---

## Critical Issues

### [CRITICAL-01] JWT Token Storage in localStorage — XSS-Exploitable Token Theft

**Section:** 5.1 認証フロー

**Issue:** The design explicitly stores access tokens in `localStorage`. Unlike `HttpOnly` cookies, `localStorage` is accessible from JavaScript, making stored tokens trivially exfiltrable via any XSS vulnerability in the application.

**Impact:** An attacker who achieves XSS execution can steal the 24-hour access token and 30-day refresh token, gaining persistent, full-privilege access to patient medical records, prescriptions, and consultation data. In a healthcare platform with highly sensitive PHI, this constitutes a severe breach vector.

**Countermeasures:**
- Store access tokens in `HttpOnly`, `Secure`, `SameSite=Strict` cookies.
- If `localStorage` is retained for architectural reasons, implement a token-binding or proof-of-possession mechanism.
- At minimum, document the explicit risk acceptance with compensating controls (strict CSP, sub-resource integrity).

---

### [CRITICAL-02] Doctor Role Can Access All Patients Across Tenant — Missing Patient-Level Authorization

**Section:** 5.2 認可モデル

**Issue:** The design states: "doctor ロールは `patient_id` パラメータによるフィルタリングなしに patient-service の全患者データを参照できる設計とする." This means any authenticated doctor within a tenant can access every patient's medical records and prescriptions, not just patients under their care.

**Impact:** A malicious or compromised doctor account can exfiltrate the complete patient database of the tenant. In a multi-tenant healthcare environment this violates the minimum-privilege principle and likely violates applicable medical privacy obligations (厚生労働省ガイドライン). A single compromised doctor credential results in full tenant-scope PHI exposure.

**Countermeasures:**
- Implement patient-doctor relationship enforcement: `GET /api/v1/patients/{id}/records` must verify that the requesting doctor has an active care relationship with the patient.
- `GET /api/v1/patients/{id}/prescriptions` and related endpoints must enforce the same ownership/membership check.
- Design an explicit "care relationship" or "assigned patients" data model and enforce it at the service layer, not only at the role-middleware level.

---

### [CRITICAL-03] Wildcard CORS Policy on Production-Intended API Gateway

**Section:** 7.3 CORS設定

**Issue:** `Access-Control-Allow-Origin: *` is set on the API Gateway. The design acknowledges this as a development-convenience setting with only a vague "本番環境では必要に応じて絞り込みを検討する" comment — no binding commitment or mechanism to enforce restriction before go-live.

**Impact:** Credentialed cross-origin requests from any origin are permitted. Combined with the XSS risk (CRITICAL-01), any malicious page can issue authenticated requests to the API on behalf of a logged-in user. For a healthcare API exposing PHI, this is an unacceptable open perimeter.

**Countermeasures:**
- Explicitly enumerate allowed origins (e.g., the production domain(s)) in the design.
- Add a deployment gate: CI/CD pipeline must reject wildcard CORS configuration in production environments.
- If a broad origin list is required for mobile app deep-links, enumerate each origin explicitly.

---

### [CRITICAL-04] No CSRF Protection for State-Changing Operations

**Section:** 7.4 セッション系 API の保護

**Issue:** The design explicitly defers CSRF protection for state-changing operations (`POST /api/v1/prescriptions`, `PUT /api/v1/patients/{id}`) as "現フェーズのスコープ外." No CSRF countermeasure (CSRF token, `SameSite` cookie attribute) is designed anywhere in the document. The design does not claim JWT statelessness as a CSRF mitigation, leaving the gap completely unaddressed.

**Impact:** If tokens are moved to cookies (as recommended in CRITICAL-01), absent CSRF protection means a forged cross-site request can issue prescriptions, modify patient records, or change user data on behalf of authenticated users. Even with `localStorage`-based tokens, the gap represents a missing design decision that will persist into implementation.

**Countermeasures:**
- Design explicit CSRF tokens for all state-changing endpoints, OR
- Design `SameSite=Strict` cookie attributes as the CSRF mitigation layer (requires token migration from localStorage to cookies), OR
- Document a deliberate architectural decision if relying on JWT in `Authorization` header (which does inherently resist CSRF) and confirm this decision is binding for all state-changing APIs.

---

## Significant Issues

### [SIGNIFICANT-01] Internal VPC Communication is Plaintext — No Encryption for PHI in Transit

**Section:** 6.1 通信の暗号化

**Issue:** "VPC 内部の通信については内部ネットワークであるため平文で行う." This means traffic between microservices (auth-service, patient-service, consultation-service, prescription-service), between the application layer and PostgreSQL RDS, and between the application layer and Redis carries PHI in plaintext within the VPC.

**Impact:** A VPC-internal attacker (e.g., a compromised container, lateral movement from another ECS task, or a misconfigured security group) can passively intercept all medical records, prescriptions, and session tokens without any cryptographic barrier. AWS VPC network isolation is a perimeter control, not a substitute for in-transit encryption of highly sensitive PHI.

**Countermeasures:**
- Enable TLS for RDS PostgreSQL connections (AWS RDS supports `ssl-mode=require`).
- Enable TLS for Redis (ElastiCache supports in-transit encryption).
- Enforce mTLS or TLS between ECS microservices (e.g., via AWS App Mesh or service mesh sidecar).

---

### [SIGNIFICANT-02] No Login Rate Limiting — Brute Force on Healthcare Credentials

**Section:** 8.5 認証エンドポイント保護

**Issue:** "高可用性を優先するため呼び出し制限は設けない設計とする." The login endpoint `/api/v1/auth/login` has no rate limiting by explicit design choice. Account lockout is deferred to "別途検討."

**Impact:** An attacker can perform unlimited credential-stuffing or brute-force attacks against doctor and admin accounts. bcrypt with cost factor 12 provides some resistance but does not substitute for rate limiting in production. Compromised admin accounts give full system access; compromised doctor accounts expose patient data (amplified by CRITICAL-02).

**Countermeasures:**
- Implement IP-based rate limiting at the API Gateway level (e.g., AWS WAF rate-based rules): e.g., max 10 login attempts per IP per minute.
- Implement per-account lockout after N consecutive failures with exponential backoff.
- Design CAPTCHA or device fingerprinting for repeated failures.
- High availability and rate limiting are not mutually exclusive; distributed rate limiting (e.g., via Redis counters with TTL) maintains HA while protecting against brute force.

---

### [SIGNIFICANT-03] No Server-Side Input Validation — Injection Attack Surface

**Section:** 7.1 入力検証方針

**Issue:** "バックエンドでは基本的な型チェック（JSONスキーマバリデーション）のみ実施する." Frontend validation is the primary defense. The design explicitly relies on frontend validation having "completed" before the API receives input.

**Impact:** Frontend validation is trivially bypassed by direct API calls (curl, Burp Suite, etc.). SQL injection, NoSQL injection, and command injection against `diagnosis`, `soap_note`, `medications` (JSONB), and `pdf_url` fields are fully exposed at the API layer. The `medications` JSONB field in particular represents a high-value injection target affecting prescription integrity.

**Countermeasures:**
- Design mandatory server-side validation for all API inputs: field-level sanitization, parameterized queries enforced by ORM policy, content-type enforcement.
- Explicitly design injection-prevention policies: parameterized queries for all DB operations, disallow raw string interpolation in query construction.
- Frontend validation should be treated as UX enhancement, not a security control.

---

### [SIGNIFICANT-04] File Upload — No File Type or Size Restrictions at Design Level

**Section:** 7.2 ファイルアップロード

**Issue:** "ファイル種別・サイズの制限は実装フェーズで決定する." The design defers file type validation and size limits entirely to implementation. Only virus scanning is mentioned as a pre-S3 control.

**Impact:** Without explicit design constraints, implementation may omit or underspecify these controls. Unrestricted file uploads to a healthcare platform enable: polyglot file attacks bypassing virus scanners, storage exhaustion (DoS), server-side file inclusion if file paths are ever served directly, and MIME-type confusion vulnerabilities.

**Countermeasures:**
- Define in the design: permitted MIME types (e.g., `image/jpeg`, `image/png`, `application/pdf`), maximum file size (e.g., 50 MB), and storage path isolation (no publicly guessable S3 key patterns).
- Design pre-signed S3 upload URLs with server-side policy enforcement rather than accepting file content through the application layer.
- Verify file type using magic bytes server-side, not only by extension or client-supplied MIME type.

---

### [SIGNIFICANT-05] No Dependency Vulnerability Management Policy

**Section:** 8.2 サードパーティ依存関係

**Issue:** "脆弱性情報の定期チェック方針は今後の運用フェーズで策定する予定である." Version pinning at development time is the only control described. No automated scanning, no CVE monitoring process, no remediation SLA is designed.

**Impact:** Twilio Video SDK v2.27.0, Express 4.18, Node.js 18, React 18, PostgreSQL 15 driver — any of these may accumulate known CVEs between development and production, and throughout the operational lifetime of the system. A healthcare platform with PHI is a high-value target; unpatched dependencies are a primary initial-access vector.

**Countermeasures:**
- Design an automated dependency scanning pipeline (e.g., `npm audit`, Snyk, Dependabot) integrated into CI/CD.
- Define a remediation SLA: critical CVEs within N days, high CVEs within M days.
- Design a process for monitoring upstream security advisories for direct dependencies (especially Twilio SDK).

---

## Independent Finding — Audit Log Gap

### [AUDIT-01] Audit Log Lacks Recording Requirements for Authentication Failures, Privilege Changes, and Sensitive Data Access

**Section:** 8.3 監査ログ

**Issue:** Section 8.3 describes a general audit logging design: "操作ユーザーID、操作種別、タイムスタンプ" are recorded in CloudWatch Logs. This is a positive structural foundation. However, the design **does not explicitly specify recording requirements** for the following security-critical event categories:

1. **Authentication failures** — failed login attempts (essential for detecting brute-force and credential-stuffing attacks)
2. **Privilege changes** — role assignments, user permission modifications by admin users
3. **Sensitive data access** — access to patient medical records (`GET /api/v1/patients/{id}/records`), prescriptions, and diagnostic images

This gap is reported as an independent finding, not as a supplementary note to the general logging design.

**Impact:** Without explicit logging of authentication failures, security operations cannot detect or alert on credential attacks. Without privilege change logging, unauthorized role escalation is undetectable after the fact. Without sensitive data access logging, insider-threat detection and breach forensics are impossible — a critical gap for a platform subject to medical information governance obligations (厚生労働省ガイドライン).

**Countermeasures:**
- Explicitly specify in Section 8.3 that the following events MUST be logged with defined fields:
  - `auth.login.failure`: timestamp, user_id (if determinable), IP address, failure reason
  - `auth.token.refresh.failure`: timestamp, token_id, IP address
  - `admin.role.change`: timestamp, actor_user_id, target_user_id, old_role, new_role, tenant_id
  - `patient.record.access`: timestamp, actor_user_id, patient_id, record_type, tenant_id
  - `prescription.access`: timestamp, actor_user_id, prescription_id, patient_id, tenant_id
- Design log integrity protection: CloudWatch Logs cannot be modified retroactively, but access controls on log groups must be designed explicitly.
- Consider a separate security audit log stream (distinct from general application logs) to prevent mixing PHI-bearing operational logs with security event records.

---

## Moderate Issues

### [MODERATE-01] PII Logging Policy Delegated to Individual Engineers

**Section:** 6.3 個人情報の取り扱い

**Issue:** "患者情報（PII）を含むログ出力については、エンジニアの判断に委ねる運用とする." There is no designed policy, no automated PII scrubbing, and no enforcement mechanism.

**Impact:** Inconsistent log output will inevitably include patient names, insurance numbers, or diagnostic content in CloudWatch Logs, creating a secondary PHI exposure surface accessible to anyone with CloudWatch read access.

**Countermeasures:**
- Design a mandatory PII scrubbing layer in the logging framework (e.g., log middleware that redacts fields matching PII patterns).
- Enumerate fields that must never appear in logs: `full_name`, `insurance_number`, `date_of_birth`, `diagnosis`, `soap_note`.
- Design role-based access controls on CloudWatch log groups.

---

### [MODERATE-02] Refresh Token Storage Allows Session Fixation via Key Collision

**Section:** 5.3 セッション管理

**Issue:** "ユーザーIDをキーとしてトークン値を管理する." Storing refresh tokens by user ID as key means only one refresh token per user exists in Redis. If a new login overwrites the previous token, concurrent sessions are invalidated silently. More critically, this design does not address session fixation: if an attacker pre-places a token value and the implementation does not validate token provenance before writing, token injection is possible.

**Impact:** Session management under this design is fragile. Concurrent legitimate sessions (e.g., a doctor using both mobile and web) will collide. The design provides no token rotation policy, no device binding, and no maximum concurrent session limit.

**Countermeasures:**
- Store refresh tokens with a composite key of `user_id:token_id` (or use a token hash as the key) to support multiple concurrent sessions.
- Design explicit token rotation: each use of a refresh token issues a new refresh token and invalidates the old one (refresh token rotation).
- Design a maximum concurrent session count per user with explicit eviction policy.

---

### [MODERATE-03] Application-Level Encryption Explicitly Rejected for Medical Data

**Section:** 6.2 保存データの暗号化

**Issue:** "診断結果・処方内容などの医療機密情報については、アプリケーションレベルでの追加暗号化は行わず、RDS暗号化で十分と判断している." This explicit design decision accepts RDS storage-level encryption as the sole protection for the most sensitive PHI fields.

**Impact:** RDS encryption (AES-256 at storage level) does not protect data from: application-layer SQL injection, compromised database credentials, unauthorized access by AWS account users with RDS describe/query permissions, or lateral movement within the VPC. Field-level or column-level encryption for `diagnosis`, `soap_note`, `insurance_number` would be a significant defense-in-depth layer.

**Countermeasures:**
- Evaluate field-level encryption for highest-sensitivity columns (`diagnosis`, `soap_note`, `insurance_number`) using application-managed keys stored in AWS KMS.
- At minimum, document the explicit threat model that RDS encryption is considered sufficient for, and identify what threats it does not address.

---

## Positive Aspects

- **AWS Secrets Manager** for secret management (Section 8.1): Appropriate use of managed secret storage rather than environment variable files or hardcoded values.
- **bcrypt with cost factor 12** (Section 5.1): Appropriate password hashing algorithm and cost factor selection.
- **RDS Multi-AZ and private subnet placement** (Sections 8.4, 9.1): Network isolation and HA for data layer are correctly designed.
- **VPC internal service communication** (Section 3.2): Microservice communication is scoped to VPC internal network, reducing external attack surface.
- **Redis-backed refresh token invalidation** (Section 5.3): Logout invalidation via Redis deletion is correctly designed for stateless JWT architecture.
- **Multi-schema tenant isolation** (Section 3.2): Schema-level isolation for multi-tenant data is a stronger isolation model than row-level filtering alone.
- **S3 server-side encryption** (Section 6.2): SSE-S3 enabled for file storage.
- **Virus scanning for file uploads** (Section 7.2): Pre-storage virus scanning is a relevant control for a healthcare platform.
