# Security Design Review: Nexamart プラットフォーム システム設計書 v1.4.0

**Reviewer**: security-design-reviewer (v003-variant-data-protection-encryption-layers)
**Document**: test-document-2.md
**Run**: 2

---

## Executive Summary

This design document presents a multi-tenant marketplace platform with several critical security issues that require immediate attention before production deployment. The most severe issues involve PII plaintext storage with insufficient encryption, secrets committed to the repository, and CORS misconfiguration permitting subdomain takeover attacks.

---

## Critical Issues

### [CRITICAL-1] PII Stored in Plaintext with Insufficient Encryption Layer (Section 5.1)

**Issue**: The design explicitly states that personal information fields (name, address, phone number) are stored in plaintext, relying solely on RDS Transparent Data Encryption (TDE) for protection.

**Encryption Layer Analysis**:
- **Current state**: Storage-layer encryption only (AWS RDS TDE)
- **Required state**: Application-layer encryption (field-level encryption)

TDE is a storage-layer mechanism. It protects against physical media theft and unauthorized storage-device access. It does **not** protect against:
- Logical access by any database user with valid credentials
- Compromised application-level credentials
- SQL injection attacks that successfully authenticate as the app user
- Insider threats (DBA or developer with database access)
- Compromised AWS IAM credentials providing RDS access

In this platform's threat model, users' PII (name, address, phone number) is highly sensitive data. An attacker who gains application-level or database-level access can read all PII in plaintext. The design document's assertion that "RDS encryption provides sufficient protection, so no additional field-level encryption is required" is architecturally incorrect.

**Impact**: Full PII exposure for all users across all tenants upon any database-level compromise. In a multi-tenant shared schema, a single breach exposes every tenant's customer data simultaneously.

**Countermeasures**:
1. Implement application-layer field-level encryption for PII fields (name, address, phone number) using AWS KMS with a dedicated encryption key per data category or per tenant
2. Use envelope encryption: generate a data encryption key (DEK) per record or per tenant, encrypt DEK with a KMS CMK
3. Apply envelope encryption at the application layer before writing to the database, and decrypt after reading
4. Consider using AWS Encryption SDK or a vetted library for this purpose

**References**: Section 5.1 ("個人情報フィールドの暗号化")

---

### [CRITICAL-2] Production Secrets Committed to Repository (Section 8.1)

**Issue**: The design specifies that production secret values are recorded in `config/secrets.prod.yaml` and included in the repository with "access restrictions."

**Impact**: Any git repository leak, misconfigured access control, or insider threat exposes all production credentials including database passwords, external API keys, and JWT signing keys. Access restrictions on a file within a version-controlled repository are fundamentally insufficient because:
- Git history is permanent; once committed, secrets persist even after deletion
- Repository access controls are less granular than secrets management systems
- CI/CD systems that clone the repository inherit access to these secrets

**Countermeasures**:
1. Remove `config/secrets.prod.yaml` from the repository immediately and rotate all secrets it contains
2. Use AWS Secrets Manager exclusively for all production secrets (already partially in use per the design)
3. Do not store any secret values in files within version-controlled repositories, even with access restrictions
4. Implement pre-commit hooks (e.g., `git-secrets`, `trufflehog`) to prevent future secret commits

**References**: Section 8.1 ("本番環境のシークレット値はデプロイ担当者の参照用に `config/secrets.prod.yaml` へも記録し")

---

### [CRITICAL-3] CORS Misconfiguration Enabling Subdomain Takeover Attack Vector (Section 6.4)

**Issue**: The CORS configuration uses a regex `\.nexamart\.com$` to match allowed origins and reflects the requesting origin with `Access-Control-Allow-Credentials: true`.

**Vulnerability**: This regex allows **any subdomain** of `nexamart.com`, including attacker-controlled subdomains. If an attacker registers `evil.nexamart.com` (possible if tenant slugs are user-controlled or if subdomain registration is insufficiently protected), they can make credentialed cross-origin requests from that origin to the API, bypassing CORS protection entirely.

Additionally, the regex as written (`\.nexamart\.com$`) matches strings like `evil-nexamart.com` is not an issue due to the escaped dot, but does match `evil.nexamart.com` which may be attacker-controlled.

**Attack scenario**:
1. Attacker creates a tenant with slug `evil` → gains `evil.nexamart.com`
2. Serves malicious JavaScript from `evil.nexamart.com`
3. Victim visits `evil.nexamart.com`; malicious JS makes credentialed API requests to `api.nexamart.com`
4. CORS check passes because `evil.nexamart.com` matches the regex; credentials (JWT from localStorage or cookies) are included
5. Attacker can exfiltrate victim's data or perform actions on their behalf

**Countermeasures**:
1. Enumerate the exact set of allowed origins explicitly (e.g., a whitelist Set of known subdomains)
2. If wildcard subdomain matching is required, implement additional constraints: verify the subdomain prefix against known tenant slugs from the database
3. Never use generic regex subdomain matching with `Allow-Credentials: true`

**References**: Section 6.4 (CORS設定)

---

## Significant Issues

### [HIGH-1] Access Token in localStorage Exposed to XSS (Section 4.1)

**Issue**: JWT access tokens are stored in `localStorage`, which is accessible to any JavaScript running in the browser (including XSS payloads).

**Impact**: Despite CSP and DOMPurify mitigations, any XSS vulnerability — whether in the application itself, in a third-party CDN-loaded script, or in a browser extension — can exfiltrate access tokens from localStorage. Unlike HttpOnly cookies, localStorage provides no browser-enforced boundary against script access.

**Countermeasures**:
1. Store the access token in an `HttpOnly`, `Secure`, `SameSite=Strict` cookie instead of localStorage
2. If localStorage is retained (e.g., for SPA routing reasons), keep token validity window extremely short (5–15 minutes) and rely on the refresh token mechanism
3. Implement token binding or fingerprinting (e.g., bind token to user-agent hash) to limit token reuse if stolen

**References**: Section 4.1 (トークン保存場所)

---

### [HIGH-2] No Rate Limiting on Authentication Endpoints (Section 4.4, 6.x)

**Issue**: The design does not specify rate limiting for `/api/auth/login`, `/api/auth/register`, or `/api/auth/refresh`. These endpoints are directly exposed.

**Impact**:
- `/api/auth/login`: Vulnerable to brute-force and credential stuffing attacks
- `/api/auth/register`: Vulnerable to bulk account creation (spam, fake accounts for platform abuse)
- `/api/auth/refresh`: Vulnerable to token refresh abuse (if stolen refresh tokens are used rapidly)

**Countermeasures**:
1. Apply rate limiting at the Kong API gateway level for authentication endpoints (e.g., 10 attempts per IP per minute for login)
2. Implement account-level lockout after N failed attempts (with exponential backoff)
3. Add CAPTCHA for registration and after repeated login failures
4. Log and alert on authentication anomalies (high failure rate from a single IP or for a single account)

**References**: Section 4.4, Section 9.4

---

### [HIGH-3] Access Token Revocation Gap (Section 4.2)

**Issue**: The design explicitly states that access token revocation relies solely on token expiration (60-minute window). There is no server-side blocklist for access tokens. In cases of compromised accounts or privilege changes, the attacker or former-privileged user retains valid access for up to 60 minutes.

**Impact**: In a multi-tenant platform, a compromised `platform_admin` or `tenant_admin` token cannot be immediately invalidated. An attacker with a stolen access token has a guaranteed 60-minute window to exfiltrate data across all tenants.

**Countermeasures**:
1. Implement a Redis-based access token blocklist for immediate revocation in security-critical events (account compromise, role change, explicit logout from all devices)
2. Reduce access token lifetime to 15 minutes to limit the exposure window
3. Emit a security event and trigger token invalidation upon role changes or suspicious activity detection

**References**: Section 4.2 (セッション管理)

---

### [HIGH-4] Stripe Webhook Endpoint Missing Signature Verification (Section 7.3)

**Issue**: The design mentions a Stripe Webhook endpoint at `/api/webhooks/stripe` but does not describe signature verification. Without verifying the `Stripe-Signature` header using the webhook signing secret, any party can send forged webhook events to this endpoint.

**Impact**: An attacker can forge a `payment_intent.succeeded` event to mark orders as paid without actual payment, resulting in fraudulent order fulfillment across all tenants.

**Countermeasures**:
1. Implement Stripe webhook signature verification using `stripe.webhooks.constructEvent()` with the webhook signing secret for every incoming webhook request
2. Return 400 for any request failing signature verification and log the attempt

**References**: Section 7.3 (外部サービス連携)

---

### [HIGH-5] Tenant Isolation Relies Solely on Application-Layer Filtering (Section 3.2)

**Issue**: Multi-tenant data isolation uses a shared schema with `tenant_id` column filtering at the application layer. There is no database-level enforcement (e.g., Row-Level Security policies in PostgreSQL).

**Impact**: Any bug in the application query layer — missing `WHERE tenant_id = ?` clause, ORM misconfiguration, or raw query bypassing the ORM — results in cross-tenant data leakage. In a multi-tenant SaaS with all tenants sharing one database, this is a high-impact single point of failure.

**Countermeasures**:
1. Enable PostgreSQL Row-Level Security (RLS) policies on all tables containing tenant-scoped data
2. Use a dedicated database role per tenant context, set via `SET app.current_tenant_id` at the start of each request, enforced by RLS policies
3. Add integration tests that explicitly verify cross-tenant query isolation

**References**: Section 3.2 (マルチテナント分離方式)

---

## Moderate Issues

### [MEDIUM-1] File Upload MIME Type Validation via Content-Type Header Only (Section 6.5)

**Issue**: File type validation relies solely on the `Content-Type` request header, which is client-controlled and trivially spoofed. No extension validation or file content (magic bytes) inspection is performed.

**Impact**: An attacker can upload a malicious file (e.g., an HTML page with scripts, a PHP webshell, or a malicious SVG) by setting `Content-Type: image/jpeg` while the actual file content is malicious.

**Countermeasures**:
1. Validate file magic bytes (file signatures) server-side in addition to Content-Type
2. Enforce file extension whitelist (e.g., `.jpg`, `.png`, `.gif`, `.webp` for images)
3. Implement server-side virus/malware scanning (already noted as future work — elevate priority)
4. Store uploaded files under randomized names without original extensions
5. Serve all uploaded files through CloudFront with content-disposition headers

**References**: Section 6.5 (ファイルアップロード)

---

### [MEDIUM-2] PII Retention Policy Undefined (Section 5.3)

**Issue**: The design explicitly defers the data retention and deletion policy to future design. No retention period, deletion mechanism, or right-to-erasure workflow is defined.

**Impact**: Non-compliance with privacy regulations (GDPR Article 17 right to erasure, APPI requirements in Japan). Legal and regulatory risk as the platform operates with real user data lacking a deletion mechanism.

**Countermeasures**:
1. Define maximum PII retention periods before launch (e.g., 3 years post last activity)
2. Design an account deletion flow that anonymizes or deletes PII fields
3. Implement soft-delete with scheduled hard-delete jobs
4. Document the data lifecycle in a privacy policy and ensure technical enforcement

**References**: Section 5.3 (個人情報（PII）管理)

---

### [MEDIUM-3] Signed URL Expiration Too Long for Sensitive Documents (Section 5.4)

**Issue**: Signed URLs for private documents (invoices, contracts) have a 7-day validity period.

**Impact**: If a signed URL is shared, forwarded via email, or intercepted, the document remains accessible for up to 7 days without authentication. For financial documents (invoices) and legal documents (contracts), this is an excessive exposure window.

**Countermeasures**:
1. Reduce signed URL validity for sensitive documents to 15–60 minutes
2. Generate signed URLs on-demand at the point of access (per request) rather than storing long-lived URLs
3. Log all signed URL generation events for audit purposes

**References**: Section 5.4 (S3ストレージセキュリティ)

---

### [MEDIUM-4] Dependency Vulnerability Scan Cadence Too Infrequent (Section 8.2)

**Issue**: Security updates for dependencies are reviewed quarterly. `multer@1.4.4` is specifically listed, which has known vulnerabilities in older versions.

**Impact**: Critical vulnerabilities in dependencies may remain unpatched for up to 3 months, creating exploitation windows. `multer@1.4.4` should be verified against current CVE databases.

**Countermeasures**:
1. Enable automated dependency scanning (GitHub Dependabot, Snyk, or `npm audit` in CI/CD pipeline) to detect vulnerabilities on every commit
2. Define an SLA for critical vulnerability patching (e.g., critical CVEs within 48 hours, high within 1 week)
3. Verify `multer@1.4.4` against current vulnerability databases and upgrade if necessary

**References**: Section 8.2 (依存ライブラリ管理)

---

### [MEDIUM-5] Audit Log Insufficient for Security Events (Section 8.4, 9.4)

**Issue**: The audit log covers business operations (tenant registration, product status changes) but the security-critical events reference in Section 9.4 ("認証失敗・権限変更等の重要イベント") points to "Section 7.4" which does not exist in the document. Authentication failures and role changes are not listed in the Section 8.4 audit log events.

Additionally, audit logs are written to the same CloudWatch Logs stream as application logs, which means security-relevant events can be mixed with or overwritten by high-volume application logging.

**Impact**: Inability to detect or investigate authentication attacks, privilege escalation attempts, or insider threats due to missing or inaccessible audit records.

**Countermeasures**:
1. Explicitly define audit events including: authentication success/failure, token refresh, role/permission changes, admin actions, cross-tenant access attempts, and sensitive data exports
2. Separate security audit logs into a dedicated, tamper-resistant CloudWatch log group with restricted write access (only the application service role) and extended retention
3. Set up real-time alerting on critical security events (multiple authentication failures, admin privilege escalation)

**References**: Section 8.4, Section 9.4

---

## Minor Issues and Positive Aspects

### [MINOR-1] KMS Key Rotation Period Could Be Reduced

Annual KMS key rotation (Section 5.1) is the AWS KMS default. For a multi-tenant platform handling PII, consider quarterly rotation for data encryption keys to limit the blast radius of a key compromise.

### [MINOR-2] bcrypt Cost Factor is Appropriate

bcrypt with cost factor 12 (Section 4.1) is a sound choice for password hashing at current hardware levels. This is a positive security design decision.

### [MINOR-3] Secrets Manager Usage is Appropriate

AWS Secrets Manager for DB passwords, API keys, and JWT signing keys (Section 8.1) is correct. The critical issue is the parallel storage of these secrets in a repository file (see CRITICAL-2).

### [MINOR-4] Internal HTTPS Enforcement is Positive

Enforcing HTTPS between CloudFront and ECS (Section 5.2) is a positive design decision that protects against internal network interception.

### [MINOR-5] Refresh Token Blacklisting Design is Sound

Using Redis to blacklist refresh tokens on logout (Section 4.2) is a good design. The gap is the absence of access token revocation (see HIGH-3).

---

## Threat Modeling Summary (STRIDE)

| Threat | Status | Key Finding |
|--------|--------|-------------|
| Spoofing | Partial | No MFA, access token in localStorage (XSS risk), no brute-force protection |
| Tampering | Partial | Stripe webhook lacks signature verification; no request signing for internal services |
| Repudiation | Insufficient | Audit log incomplete; security events reference non-existent section |
| Information Disclosure | Critical | PII stored in plaintext; TDE insufficient; secrets in repository |
| Denial of Service | Not addressed | No rate limiting on any endpoint documented |
| Elevation of Privilege | Partial | Token revocation gap; tenant isolation relies on application layer only |
