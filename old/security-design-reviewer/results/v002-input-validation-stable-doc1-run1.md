# Security Design Review: MediConnect システム設計書

## Summary

MediConnect is a healthcare platform handling highly sensitive medical information (PHI/PII) for multiple tenants. The design document contains multiple critical and significant security issues that must be addressed before production deployment.

---

## Critical Issues

### CRITICAL-1: Frontend-Only Input Validation Dependency

**Section:** 7.1 入力検証方針

**Issue:** The design explicitly states that all API requests are sent after frontend validation is complete, with the backend performing only basic type checking (JSON schema validation). This is a critical design flaw.

> 「すべてのAPIリクエストにおいて、フロントエンドで入力検証が完了した状態でAPIに送信される設計とする。バックエンドでは基本的な型チェック（JSONスキーマバリデーション）のみ実施する。」

**Why this is dangerous:** Frontend validation can be trivially bypassed by any attacker using tools like curl, Burp Suite, or by modifying requests in browser developer tools. An attacker can send arbitrary payloads directly to the API endpoints without any browser involvement. Backend validation must be fully independent of frontend validation.

**Impact:** SQL injection, NoSQL injection, command injection, XSS via stored content, and other injection attacks become possible against all API endpoints. Given that the system handles medical records, prescriptions, and PII, a successful injection attack could result in complete data breach of all tenants' patient data.

**Countermeasures:**
- Implement comprehensive server-side input validation for all API endpoints, independent of frontend validation
- Use a validation library (e.g., Joi, Zod, or express-validator) to enforce strict schemas for all request bodies, query parameters, and path parameters
- Treat frontend validation as a UX enhancement only, never as a security control
- Add parameterized queries/ORM-level protections for all database operations

---

### CRITICAL-2: CSRF Protection Not Designed for State-Changing Operations

**Section:** 7.4 セッション系 API の保護

**Issue:** The design explicitly defers CSRF protection for state-changing operations (prescription issuance `POST /api/v1/prescriptions`, patient record updates `PUT /api/v1/patients/{id}`) as out of scope.

> 「state-changingな操作に対するリクエスト保護の設計は現フェーズのスコープ外とする。」

**Why this is dangerous:** Given that the design stores access tokens in `localStorage` and uses `Authorization: Bearer` headers, XHR-based CSRF is mitigated for those specific requests. However, the design does not confirm that all state-changing operations exclusively use `Authorization` headers. Cookie-based authentication flows or browser-initiated requests (form submissions, img tags, etc.) would remain vulnerable. Furthermore, deferring this entirely means no protection is designed for the current phase.

**Impact:** Attackers could potentially forge requests on behalf of authenticated doctors to issue prescriptions or modify patient records, constituting a serious patient safety risk in addition to a data integrity violation.

**Countermeasures:**
- Explicitly design CSRF tokens (synchronizer token pattern) or SameSite=Strict/Lax cookie attributes for all state-changing API endpoints
- If JWT via `Authorization` header is consistently used for all state-changing endpoints, document this explicitly as the CSRF mitigation rationale and verify no cookie-based auth paths exist
- Do not defer this to a later phase; include it in the current design

---

### CRITICAL-3: Access Token Stored in localStorage (XSS Vulnerability)

**Section:** 5.1 認証フロー

**Issue:** The design specifies storing access tokens in `localStorage`.

> 「クライアントはアクセストークンを `localStorage` に保存し、以降のAPIリクエストに `Authorization: Bearer` ヘッダーで付与する」

**Why this is dangerous:** `localStorage` is accessible to any JavaScript running on the page. If an XSS vulnerability exists anywhere in the application (or is introduced via a third-party script/CDN), an attacker can steal all users' access tokens. With a 24-hour access token validity and medical record access, this is a critical risk.

**Impact:** Token theft via XSS leads to full account takeover for any authenticated user, including doctors and admins, enabling access to all patient medical records.

**Countermeasures:**
- Store tokens in `HttpOnly` cookies to prevent JavaScript access
- If `localStorage` is retained for architectural reasons, implement a strict Content Security Policy (CSP) to minimize XSS risk, and reduce token lifetime significantly
- Implement token binding or refresh token rotation to limit the window of exposure

---

### CRITICAL-4: Doctor Role Can Access All Patients Across Tenant (Broken Object-Level Authorization)

**Section:** 5.2 認可モデル

**Issue:** The design explicitly states that doctor-role users can access all patient data without filtering by `patient_id`.

> 「doctor ロールは `patient_id` パラメータによるフィルタリングなしに patient-service の全患者データを参照できる設計とする。」

**Why this is dangerous:** Even within a single tenant (hospital/clinic), a doctor should only access records of their assigned patients. Without patient-level access control, any doctor can access all patients' medical records, diagnoses, and prescriptions. This violates the principle of least privilege and constitutes a HIPAA/medical privacy law violation equivalent in the Japanese healthcare context.

**Impact:** A malicious or compromised doctor account gains access to all patient records within the tenant. Cross-tenant isolation via `tenant_id` in JWT helps, but intra-tenant unauthorized access is unrestricted.

**Countermeasures:**
- Implement patient-doctor relationship (care relationship) verification at the API level for each record access
- `GET /api/v1/patients/{id}` and `GET /api/v1/patients/{id}/records` must verify the requesting doctor has an active care relationship with the patient
- Design an explicit authorization matrix that specifies under what conditions doctors may access patient records

---

## Significant Issues

### SIGNIFICANT-1: CORS Wildcard Configuration

**Section:** 7.3 CORS設定

**Issue:** The design sets `Access-Control-Allow-Origin: *` with a note to "consider restricting in production if necessary."

> 「開発効率を優先するため `Access-Control-Allow-Origin: *` を設定する。本番環境では必要に応じて絞り込みを検討する。」

**Why this is dangerous:** Wildcard CORS prevents credentialed requests from working correctly, but it allows any origin to read responses from non-credentialed API calls. For a medical system, this creates risk of cross-origin data leakage. Additionally, "consider restricting if necessary" is insufficient—restriction is mandatory for a healthcare system.

**Impact:** Data leakage potential; non-compliance with healthcare data protection requirements.

**Countermeasures:**
- Define an explicit allowlist of permitted origins (e.g., the specific frontend domain(s))
- Remove wildcard CORS from the design and specify production-ready CORS configuration now
- Ensure credentialed requests use specific origins, not wildcards

---

### SIGNIFICANT-2: No Rate Limiting on Authentication Endpoints

**Section:** 8.5 認証エンドポイント保護

**Issue:** The design explicitly opts out of rate limiting on the login endpoint, citing high availability.

> 「`/api/v1/auth/login` エンドポイントについては、高可用性を優先するため呼び出し制限は設けない設計とする。」

**Why this is dangerous:** Without rate limiting, the login endpoint is vulnerable to brute force and credential stuffing attacks. Medical staff credentials, once compromised, grant access to sensitive patient data.

**Impact:** Brute force attacks can systematically compromise accounts, leading to unauthorized access to medical records.

**Countermeasures:**
- Implement rate limiting on `/api/v1/auth/login` (e.g., 5 attempts per minute per IP, with exponential backoff)
- Implement account lockout after N failed attempts (with secure unlock mechanism)
- Rate limiting is orthogonal to high availability; API Gateway or WAF-level rate limiting does not affect ECS availability
- Similarly, apply rate limiting to `/api/v1/auth/refresh`

---

### SIGNIFICANT-3: Internal VPC Communication Unencrypted

**Section:** 6.1 通信の暗号化

**Issue:** VPC internal communication between services is explicitly designed as plaintext.

> 「VPC 内部の通信については内部ネットワークであるため平文で行う。」

**Why this is dangerous:** VPC-internal traffic is not inherently secure. Compromised instances, misconfigured security groups, network-level attacks within the VPC, or AWS infrastructure events could expose plaintext medical data in transit between services. For a healthcare system handling PHI, defense-in-depth requires encryption at all layers.

**Impact:** If any internal service is compromised, all intra-service communication (including patient records, prescriptions) is readable in plaintext.

**Countermeasures:**
- Enable TLS for service-to-service communication within the VPC (mutual TLS / mTLS preferred)
- At minimum, encrypt PostgreSQL connections (SSL) and Redis connections (TLS) from application services

---

### SIGNIFICANT-4: File Upload Without Type/Size Restrictions Defined

**Section:** 7.2 ファイルアップロード

**Issue:** File type validation and size limits are deferred to the implementation phase.

> 「ファイル種別・サイズの制限は実装フェーズで決定する。」

**Why this is dangerous:** Without defined restrictions, the implementation may omit or incorrectly implement these controls. File upload endpoints are a common attack vector for malicious file upload, resource exhaustion, and storage abuse.

**Impact:** Malicious file upload (executable files, SVG with embedded scripts), storage cost exhaustion, potential server-side execution if files are served without proper isolation.

**Countermeasures:**
- Define in the design document: permitted MIME types (e.g., image/jpeg, image/png, application/pdf), maximum file size, and storage path isolation rules
- Do not rely solely on virus scanning; content-type validation and file extension checks must be implemented server-side
- Ensure S3 URLs for uploaded files are pre-signed and not publicly accessible

---

## Moderate Issues

### MODERATE-1: Access Token Validity Period Too Long

**Section:** 5.1 認証フロー

**Issue:** Access tokens are valid for 24 hours.

**Impact:** A stolen access token (e.g., via XSS, log leakage, or network interception) remains valid for up to 24 hours with no mechanism to revoke it mid-session.

**Countermeasures:**
- Reduce access token validity to 15-60 minutes
- Implement token revocation or short-lived tokens with frequent refresh
- The 30-day refresh token should trigger re-authentication for sensitive operations

---

### MODERATE-2: PII in Logs Delegated to Engineer Judgment

**Section:** 6.3 個人情報の取り扱い

**Issue:** The design delegates the decision of whether to include PII in logs to individual engineers.

> 「患者情報（PII）を含むログ出力については、エンジニアの判断に委ねる運用とする。」

**Impact:** PII (patient names, dates of birth, insurance numbers, diagnoses) may appear in CloudWatch Logs without controls, leading to privacy violations and potential regulatory non-compliance.

**Countermeasures:**
- Define an explicit policy: PII must never appear in logs
- Implement log scrubbing/masking at the framework level
- Use structured logging with defined fields that exclude PII by design

---

### MODERATE-3: Audit Logging Insufficiently Scoped for Healthcare

**Section:** 8.3 監査ログ

**Issue:** The audit log design covers general operations but does not specify security-critical event logging required for healthcare systems.

**Missing events:** Authentication failures, permission denials, sensitive data access (who accessed which patient record), prescription issuance, administrative changes.

**Countermeasures:**
- Define mandatory audit log events: authentication success/failure, patient record access (read), medical record creation/modification, prescription issuance, admin user management operations
- Ensure audit logs are tamper-resistant (separate from application logs, immutable storage)
- Include patient ID and record type in audit events for medical record access

---

### MODERATE-4: Dependency Vulnerability Management Not Defined

**Section:** 8.2 サードパーティ依存関係

**Issue:** Vulnerability monitoring policy is deferred to the operations phase.

> 「脆弱性情報の定期チェック方針は今後の運用フェーズで策定する予定である。」

**Impact:** Known vulnerabilities in Node.js 18, Express 4.18, Twilio Video SDK 2.27.0, and other dependencies may go undetected and unpatched.

**Countermeasures:**
- Implement automated dependency scanning in CI/CD (e.g., `npm audit`, Snyk, or Dependabot)
- Define a patch SLA: critical CVEs within 24-48 hours, high within 1 week
- Pin dependencies and automate update PRs with test validation

---

## Minor Issues / Positive Aspects

### Positive: Secret Management

AWS Secrets Manager usage for database credentials and API keys is a good practice (Section 8.1).

### Positive: Database Encryption

RDS encryption (AES-256) and S3 SSE-S3 provide a baseline for data-at-rest protection (Section 6.2).

### Positive: Multi-Tenant Schema Isolation

Schema-level tenant isolation is a stronger multi-tenancy model than row-level isolation (Section 3.2), though JWT `tenant_id` claim enforcement at the application level requires careful implementation.

### Positive: Network Segmentation

RDS and Redis in VPC private subnets, security group-based access control, and NAT Gateway usage follow good network security practices (Section 8.4).

### MINOR-1: Data Retention — Deletion Policy Undefined

**Section:** 4.2 データ分類

The deletion policy is deferred. For a healthcare system subject to Japanese medical law (医療法施行規則第22条), the deletion policy (including secure deletion of PHI beyond retention period) must be designed explicitly.

### MINOR-2: Refresh Token Key Collision Risk

**Section:** 5.3 セッション管理

Redis stores refresh tokens keyed by user ID. If a user logs in from multiple devices, the previous token is overwritten, causing session invalidation on other devices. More importantly, this design does not support per-device token revocation. Recommend keying by `user_id:device_id` or using a token set per user.

---

## STRIDE Threat Model Summary

| Threat | Countermeasure Status |
|--------|-----------------------|
| Spoofing | Partially addressed (JWT auth); localStorage storage undermines token security |
| Tampering | Not addressed (no backend input validation, no CSRF protection) |
| Repudiation | Partially addressed (CloudWatch logs); insufficient for healthcare audit requirements |
| Information Disclosure | Partially addressed (TLS external, RDS/S3 encryption); VPC internal plaintext is a gap |
| Denial of Service | Not addressed (no rate limiting on auth endpoints) |
| Elevation of Privilege | Significant gap (doctor role has excessive patient access) |

---

## Priority Action Items

1. **Immediately:** Redesign Section 7.1 to mandate comprehensive backend input validation independent of frontend
2. **Immediately:** Define CSRF protection strategy for all state-changing endpoints (Section 7.4)
3. **Immediately:** Change token storage from `localStorage` to `HttpOnly` cookies (Section 5.1)
4. **Immediately:** Restrict doctor access to only their assigned patients (Section 5.2)
5. **Before production:** Restrict CORS to specific origins (Section 7.3)
6. **Before production:** Implement rate limiting on auth endpoints (Section 8.5)
7. **Before production:** Enable TLS for internal VPC service communication (Section 6.1)
8. **Before production:** Define file upload restrictions in the design (Section 7.2)
