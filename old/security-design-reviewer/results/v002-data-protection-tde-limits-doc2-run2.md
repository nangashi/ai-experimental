# Security Review: Nexamart Platform System Design

**Reviewer**: security-design-reviewer (v002-variant-data-protection-tde-limits)
**Document**: test-document-2.md (Nexamart Platform System Design v1.4.0)
**Run**: doc2-run2

---

## CRITICAL ISSUES

### [CRITICAL] C-01: PII Stored in Plaintext — TDE Protection Insufficient

**Section**: 5.1 (Data Protection — At-rest Encryption)

**Issue**: The design explicitly states that PII fields (name, address, phone number) are stored in plaintext, relying solely on AWS RDS Transparent Data Encryption (TDE) for protection. The document reads:

> "個人情報フィールドの暗号化: 氏名・住所・電話番号などの個人情報は平文で保存する。RDS暗号化により保護されているため、フィールドレベルでの追加暗号化は不要と判断する"

**Why This Is Insufficient**: TDE (disk-level encryption) only protects against physical media theft and physical access to storage. It does NOT protect against:
- Logical database access by any user with DB credentials (including compromised application credentials)
- SQL injection attacks that bypass the application layer
- Insider threats (DBAs, operations staff with direct DB access)
- Application-level breaches where an attacker gains query execution capability
- Data leakage through misconfigured backups or read replicas accessible via DB credentials

In a multi-tenant SaaS context, the risk is amplified: a single compromised DB credential or a tenant-isolation bypass exposes all tenants' PII simultaneously.

**Impact**: Full exposure of all stored PII (names, addresses, phone numbers) for all users across all tenants upon any logical DB compromise. Regulatory exposure under GDPR, APPI, and similar frameworks. Depending on data categories involved, this may violate PCI DSS requirements for cardholder environments adjacent to Stripe integrations.

**Countermeasures**:
1. Implement field-level or application-level encryption for high-sensitivity PII columns (address, phone number at minimum) using AWS KMS managed keys
2. Use envelope encryption: encrypt column values at the application layer before INSERT, decrypt after SELECT
3. At minimum, document the accepted residual risk with an explicit threat model acknowledging that TDE does not protect against logical access — do not present TDE as sufficient protection for PII in plaintext columns

---

### [CRITICAL] C-02: Production Secrets Committed to Repository

**Section**: 8.1 (Secret Management)

**Issue**: The design states:

> "本番環境のシークレット値はデプロイ担当者の参照用に `config/secrets.prod.yaml` へも記録し、アクセス制限を設けたうえでリポジトリに含める"

Storing production secrets (DB passwords, API keys, JWT signing keys) in a version-controlled repository — even with access restrictions — is a critical security antipattern. Git history persists secrets permanently; access controls on the repository do not eliminate the risk of accidental exposure through forks, CI/CD pipeline logs, or compromised developer machines.

**Impact**: Any compromise of the repository or CI/CD system results in full exposure of all production credentials. JWT signing key exposure allows forging of arbitrary tokens for any user or role.

**Countermeasures**:
1. Remove `config/secrets.prod.yaml` from the repository immediately and rotate all secrets it contains
2. Rely exclusively on AWS Secrets Manager (already in use per 8.1) for production secret access at deployment time
3. Use IAM roles for ECS task execution to access Secrets Manager without embedding credentials

---

## SIGNIFICANT ISSUES

### [SIGNIFICANT] S-01: Access Token Stored in localStorage — XSS Theft Risk

**Section**: 4.1 (Authentication Flow — Token Storage)

**Issue**: JWT access tokens are stored in `localStorage`. Any XSS vulnerability (including in third-party scripts loaded via CDN, or bypass of DOMPurify sanitization) can read `localStorage` and exfiltrate the token. The design's CSP (`default-src 'self'`) provides some mitigation but does not eliminate the risk for all attack surfaces.

**Impact**: Token theft enables account takeover for the 60-minute token lifetime. In a multi-tenant marketplace, a compromised buyer token may expose order history and PII.

**Countermeasure**: Store access tokens in `HttpOnly` cookies (same as the refresh token approach). If `localStorage` is preferred for SPA architecture reasons, document the accepted risk and ensure CSP is strictly maintained.

---

### [SIGNIFICANT] S-02: Compromised Access Token Cannot Be Invalidated

**Section**: 4.2 (Session Management)

**Issue**: The design explicitly states:

> "アクセストークンの失効管理はトークン有効期限のみで実施（サーバーサイドのブロックリストなし）"
> "不正検知や権限変更が発生した場合のトークン即時無効化は、リフレッシュトークンの期限切れに依存する設計とする"

Upon detecting a compromised account or performing a privilege change (e.g., role downgrade), the system cannot revoke the active access token for up to 60 minutes.

**Impact**: An attacker who obtains a token (via XSS, C-02 credential compromise, or other means) retains access for up to 60 minutes after detection. A demoted admin retains elevated privileges for the same window.

**Countermeasure**: Implement a server-side token revocation list in Redis (similar to the refresh token blacklist already designed). Alternatively, shorten access token lifetime significantly (e.g., 5–15 minutes) to reduce the exposure window.

---

### [SIGNIFICANT] S-03: CORS Wildcard Subdomain Allows Attacker-Controlled Origins

**Section**: 6.4 (CORS Configuration)

**Issue**: The regex `*.nexamart.com` (implemented as `/\.nexamart\.com$/`) allows any subdomain including attacker-controlled ones. An attacker who registers `attacker.nexamart.com` (if subdomain registration is open to tenants) or exploits a subdomain takeover on an unused tenant slug would have a fully trusted CORS origin with `Access-Control-Allow-Credentials: true`.

**Impact**: Cross-origin requests from a malicious subdomain can read authenticated API responses and exfiltrate data from authenticated sessions.

**Countermeasure**: Maintain an explicit allowlist of valid origins (e.g., `nexamart.com`, `admin.nexamart.com`, and dynamically registered tenant subdomains validated against the tenant registry) rather than pattern-matching all subdomains.

---

### [SIGNIFICANT] S-04: No Rate Limiting on Authentication Endpoints

**Section**: 4.4 (Authentication Endpoints)

**Issue**: No rate limiting is specified for `/api/auth/login`, `/api/auth/register`, or `/api/auth/refresh`. The design does not reference any brute-force protection mechanism (e.g., account lockout, CAPTCHA, or IP-based throttling).

**Impact**: Enables credential stuffing and brute-force attacks against user accounts. The marketplace context (many buyer accounts) makes this a high-value target.

**Countermeasure**: Implement rate limiting at the Kong API gateway layer for authentication endpoints. Apply progressive delays or temporary lockout after N failed attempts. Log authentication failures (partially addressed in 9.4 but without enforcement in the auth design).

---

### [SIGNIFICANT] S-05: Tenant Isolation Relies Solely on Application-Layer Filtering

**Section**: 3.2 (Multi-Tenant Isolation)

**Issue**: All tenant data isolation is implemented via `tenant_id` column filtering in application queries. The design explicitly states "コアAPIサービスはゲートウェイを通過したリクエストを信頼済みとして処理する" — if any service bypasses the filter (due to a bug, ORM query without tenant scope, or raw query), all tenant data is exposed.

**Impact**: A single application-layer bug in any service can result in cross-tenant data exposure for all tenants.

**Countermeasure**: Consider Row-Level Security (RLS) at the PostgreSQL level as a defense-in-depth measure to enforce tenant isolation at the database layer, not solely the application layer. At minimum, implement automated test coverage that verifies tenant isolation boundaries.

---

## MODERATE ISSUES

### [MODERATE] M-01: File Upload MIME Type Check Bypass via Content-Type Header

**Section**: 6.5 (File Upload)

**Issue**: File type validation relies exclusively on the `Content-Type` header, which is user-controlled and trivially spoofed. An attacker can upload a PHP/HTML file with `Content-Type: image/jpeg`.

**Impact**: Depending on S3 bucket configuration and CloudFront behavior, a malicious file served from the CDN could be executed in a victim's browser or used for phishing.

**Countermeasure**: Validate file content using magic bytes (file signature inspection), not the `Content-Type` header. Reject files whose content signature does not match an allowed image format.

---

### [MODERATE] M-02: Stripe Webhook Endpoint Missing Signature Verification Mention

**Section**: 7.3 (External Service Integration)

**Issue**: The design mentions the Stripe webhook endpoint `/api/webhooks/stripe` but does not specify that Stripe's webhook signature (`Stripe-Signature` header, HMAC-SHA256) is verified before processing events.

**Impact**: Without signature verification, an attacker can send crafted webhook payloads to manipulate order payment status (e.g., falsely marking orders as paid).

**Countermeasure**: Explicitly design and document Stripe webhook signature verification using the Stripe SDK's `constructEvent` method as a mandatory processing step.

---

### [MODERATE] M-03: Audit Log Stream Co-mingled with Application Logs

**Section**: 8.4 (Audit Logs)

**Issue**: Security audit events are written to the same CloudWatch Logs stream as application logs. This makes it difficult to protect audit log integrity, apply differential retention policies, or feed events to a SIEM.

**Impact**: An attacker with application-layer log manipulation capability could obscure audit trail evidence.

**Countermeasure**: Write security audit events to a dedicated, write-only CloudWatch Logs stream with CloudTrail-backed integrity validation or S3 export with object lock.

---

### [MODERATE] M-04: PII Retention and Deletion Policy Undefined

**Section**: 5.3 (PII Management)

**Issue**: The design acknowledges that data retention and deletion policy is "未定義" (undefined). For a marketplace handling buyer PII, an undefined deletion policy creates regulatory compliance risk.

**Impact**: Non-compliance with GDPR right-to-erasure, APPI, and similar regulations upon user deletion requests.

**Countermeasure**: Define retention periods and a deletion/anonymization workflow before launch, even if the technical implementation is deferred.

---

### [MODERATE] M-05: S3 Presigned URL Validity Period of 7 Days Is Excessive

**Section**: 5.4 (S3 Storage Security)

**Issue**: Presigned URLs for private documents (invoices, contracts) are valid for 7 days. If a URL is shared or leaked, the recipient has a week of unauthorized access.

**Countermeasure**: Reduce presigned URL validity to the minimum needed for the use case (typically minutes to hours for on-demand document access, not days).

---

## MINOR ISSUES / POSITIVE ASPECTS

### [MINOR] N-01: multer@1.4.4 Is an Outdated and Vulnerable Version

**Section**: 8.2 (Dependency Management)

`multer@1.4.4` has known security vulnerabilities. Given that file uploads are handled through Presigned URLs (client-direct to S3), verify whether multer is actually in the critical path; if not, remove it. If used for any server-side processing, upgrade to a maintained version.

---

### [POSITIVE] Strengths Noted

- bcrypt with cost factor 12 for password hashing is appropriate
- Refresh token blacklisting via Redis is correctly designed
- RBAC model with explicit tenant scoping via JWT claims is sound
- Prisma ORM parameterized queries address SQL injection at the ORM level
- AWS Secrets Manager usage for primary secret storage is correct (undermined by C-02)
- PII exclusion from application logs is explicitly required

---

## Summary

| Severity | Count | Items |
|----------|-------|-------|
| Critical | 2 | C-01 (PII plaintext / TDE insufficient), C-02 (secrets in repo) |
| Significant | 5 | S-01 through S-05 |
| Moderate | 5 | M-01 through M-05 |
| Minor | 1 | N-01 |

**Most Urgent**: C-01 and C-02 require immediate design revision before the system handles real user data. C-01 in particular represents a fundamental misunderstanding of TDE's protection scope that must be corrected: transparent disk-level encryption does not protect PII stored in plaintext columns from any form of logical database access.
