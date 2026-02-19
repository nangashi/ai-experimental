# Security Design Review: Nexamart Platform System Design v1.4.0

**Reviewer**: security-design-reviewer (v003-variant-data-protection-encryption-layers)
**Document**: test-document-2.md (Nexamart Platform System Design v1.4.0)
**Date**: 2026-02-18

---

## Executive Summary

The Nexamart platform design contains multiple critical and significant security issues spanning data protection, authentication, authorization, infrastructure, and input validation. The most severe finding is the explicit decision to store PII in plaintext relying solely on storage-layer (TDE) encryption, which is inadequate for a multi-tenant marketplace handling personal data at scale.

---

## Critical Issues

### CRIT-01: PII Stored in Plaintext Relying Solely on Storage-Layer Encryption

**Section**: 5.1 (保存データの暗号化)

**Issue**: The design explicitly states that personal information fields (name, address, phone number) are stored in plaintext, with the rationale that RDS TDE (Transparent Data Encryption) provides sufficient protection and that field-level encryption is unnecessary.

> 「個人情報フィールドの暗号化: 氏名・住所・電話番号などの個人情報は平文で保存する。RDS暗号化により保護されているため、フィールドレベルでの追加暗号化は不要と判断する」

**Encryption Layer Analysis**:

| Data Category | Encryption Layer Specified | Layer Type | Sufficiency Assessment |
|---|---|---|---|
| 氏名 (Full name) | RDS TDE only | Storage-layer | INSUFFICIENT |
| 住所 (Address) | RDS TDE only | Storage-layer | INSUFFICIENT |
| 電話番号 (Phone number) | RDS TDE only | Storage-layer | INSUFFICIENT |
| メールアドレス (Email) | Not specified | Unspecified | INSUFFICIENT |
| パスワード | bcrypt hash | Application-layer | Sufficient |
| クレジットカード情報 | Delegated to Stripe | N/A | Sufficient |

**Why Storage-Layer Encryption is Insufficient Here**:

RDS TDE (storage-layer encryption) protects data on disk from physical media theft and unauthorized storage-level access. It does NOT protect PII values against:
- An attacker who gains application-level access (e.g., via SQL injection bypassing Prisma, or through a compromised service account)
- Database administrators or AWS personnel with legitimate database credentials
- A compromised ECS container that can make database queries
- Logical access exploits such as tenant isolation bypass (see CRIT-02)

This is a multi-tenant platform where tenant data co-exists in the same database. A tenant isolation failure (logical access) would expose all co-tenants' PII in plaintext. Storage-layer encryption provides zero protection in this scenario.

**Impact**: Data breach exposing PII of all platform users. In a multi-tenant breach scenario, all tenants' customer PII is exposed simultaneously. This creates significant regulatory liability (GDPR, APPI, PCI DSS if applicable).

**Countermeasures**:
1. Implement application-layer field-level encryption for highly sensitive PII fields (address, phone number) using a dedicated encryption key per tenant stored in AWS KMS
2. At minimum, apply column-level encryption at the database level for PII columns, with separate key management from the RDS encryption key
3. Establish a data classification policy that explicitly categorizes PII sensitivity tiers and mandates application-layer encryption for tier-1 PII

---

### CRIT-02: Production Secrets Committed to Version Control Repository

**Section**: 8.1 (シークレット管理)

**Issue**: The design states that production secret values are stored in `config/secrets.prod.yaml` and included in the repository with access controls.

> 「本番環境のシークレット値はデプロイ担当者の参照用に `config/secrets.prod.yaml` へも記録し、アクセス制限を設けたうえでリポジトリに含める」

**Impact**: Committing production secrets (DB passwords, JWT signing keys, external API keys) to version control is a critical anti-pattern. Even with repository access controls:
- Secrets become part of git history and persist even after deletion
- Any developer with repository read access gains production credentials
- CI/CD systems that clone the repository may expose secrets in build logs
- A single repository access control misconfiguration exposes all production systems simultaneously

**Countermeasures**:
1. Remove `config/secrets.prod.yaml` from the repository immediately and rotate all referenced secrets
2. Use AWS Secrets Manager exclusively as the authoritative source for all production secrets (already in use per 8.1)
3. If human-readable reference is needed for operations, use AWS Secrets Manager console access with CloudTrail audit logging

---

### CRIT-03: Tenant Isolation Relies Entirely on Application-Layer Filtering Without Defense-in-Depth

**Section**: 3.2 (マルチテナント分離方式)

**Issue**: The design uses a shared schema approach where tenant isolation is enforced solely by application-layer query filtering on `tenant_id`. There is no database-level enforcement (Row Level Security, separate schemas, or separate databases).

> 「アプリケーション層でのクエリフィルタリングにより他テナントデータへのアクセスを防止する」

Furthermore, the `X-Tenant-ID` header injected by Kong is trusted by the core API service without additional verification for all request types.

**Impact**: A single bug in tenant ID filtering in any query across any service exposes all tenants' data. In a marketplace with multiple services (order service, product service, tenant management service), the attack surface for tenant isolation bypass is proportional to the number of query paths. Combined with CRIT-01 (PII in plaintext), a tenant isolation bypass results in immediate plaintext PII exposure.

**Countermeasures**:
1. Implement PostgreSQL Row Level Security (RLS) as a database-level defense layer for all tenant-scoped tables
2. Conduct a comprehensive audit of all database queries to verify `tenant_id` filters are applied consistently
3. Consider using a dedicated database connection pool per tenant context that enforces RLS at the connection level

---

## Significant Issues

### SIG-01: Access Token Stored in localStorage — XSS Exposure Risk

**Section**: 4.1 (認証フロー)

**Issue**: JWT access tokens are stored in `localStorage`, which is accessible to any JavaScript running on the page.

> 「アクセストークン: ブラウザの `localStorage` に保存」

**Impact**: Any XSS vulnerability (including third-party script compromise, or a bypass of DOMPurify sanitization in rich text fields) allows an attacker to exfiltrate the access token, enabling full account takeover for the 60-minute token lifetime. In a marketplace context, this affects buyer accounts with access to order history and personal addresses.

**Countermeasures**:
1. Store the access token in an `HttpOnly` cookie (same as the refresh token) to prevent JavaScript access
2. If Authorization header-based flow is required, implement in-memory token storage (JavaScript variable) with automatic re-fetch on page load via the HttpOnly refresh token cookie

---

### SIG-02: No Rate Limiting on Authentication Endpoints

**Section**: 4.4 (認証エンドポイント), 6.x

**Issue**: The design does not describe rate limiting for `/api/auth/login`, `/api/auth/register`, `/api/auth/refresh`, or `/api/auth/password-reset` (if it exists). The Kong gateway is mentioned for token verification and routing but rate limiting configuration is not specified.

**Impact**: Authentication endpoints are vulnerable to brute force attacks (credential stuffing against `/api/auth/login`) and resource exhaustion (mass account registration via `/api/auth/register`).

**Countermeasures**:
1. Configure Kong rate limiting plugin for authentication endpoints: max 5 login attempts per IP per minute, with exponential backoff
2. Implement account lockout after N consecutive failures (with CAPTCHA or temporary lockout)
3. Add rate limiting to `/api/auth/refresh` to prevent token refresh abuse

---

### SIG-03: Stripe Webhook Endpoint Lacks Signature Verification Design

**Section**: 7.3 (外部サービス連携)

**Issue**: The design describes a Stripe webhook endpoint at `/api/webhooks/stripe` that updates payment status based on received events, but does not specify Stripe signature verification.

**Impact**: Without signature verification (`Stripe-Signature` header validation using the webhook secret), an attacker can forge payment events (e.g., sending a fake `payment_intent.succeeded` event) to mark orders as paid without actual payment. This is a direct financial fraud vector.

**Countermeasures**:
1. Explicitly specify that all Stripe webhook events must be verified using `stripe.webhooks.constructEvent()` with the webhook signing secret from AWS Secrets Manager
2. Reject any webhook request that fails signature verification with HTTP 400

---

### SIG-04: CORS Configuration Allows Subdomain Takeover Attack

**Section**: 6.4 (CORS設定)

**Issue**: The CORS policy uses a regex match for `*.nexamart.com` and echoes back the `Origin` header with `Access-Control-Allow-Credentials: true`. The regex `\.nexamart\.com$` would match any subdomain.

**Impact**: If any subdomain of `nexamart.com` is compromised or can be registered by an attacker (e.g., a tenant whose slug is removed but DNS record remains, or a subdomain takeover via dangling CNAME), that origin can make credentialed cross-origin requests to the API. With `Allow-Credentials: true`, this means the attacker's site can read authenticated API responses including order details and PII.

**Countermeasures**:
1. Maintain an explicit allowlist of permitted origins rather than regex-based matching
2. Implement subdomain takeover monitoring for all `*.nexamart.com` DNS entries
3. Consider whether wildcard subdomain CORS is necessary; if tenant subdomains only need to access their own API, scope CORS per-tenant

---

### SIG-05: Access Token Cannot Be Immediately Revoked After Privilege Change or Compromise

**Section**: 4.2 (セッション管理)

**Issue**: The design explicitly accepts that compromised access tokens cannot be revoked until expiry (60 minutes):

> 「不正検知や権限変更が発生した場合のトークン即時無効化は、リフレッシュトークンの期限切れに依存する設計とする」

**Impact**: If a `tenant_admin` account is compromised or a role change occurs (e.g., staff termination), the attacker or former employee retains full access for up to 60 minutes after detection. In a platform with access to all tenant orders and customer PII, this window is significant.

**Countermeasures**:
1. Implement a token revocation list in Redis for access tokens (keyed by `jti` claim) with TTL matching the token expiry
2. Check this revocation list on each authenticated request (adds one Redis lookup per request)
3. Reduce access token lifetime to 15 minutes to reduce the impact window if revocation is not feasible

---

## Moderate Issues

### MOD-01: File Upload MIME Type Validation Is Client-Controlled

**Section**: 6.5 (ファイルアップロード)

**Issue**: File type validation relies solely on the `Content-Type` header, which is set by the client and can be spoofed.

> 「MIME型チェック: Content-Type ヘッダーによる判定のみ（拡張子検証なし）」

**Impact**: An attacker can upload malicious files (PHP scripts, HTML files, SVG with embedded JavaScript) by setting a benign `Content-Type`. Files served via CloudFront CDN with an incorrect content type could enable stored XSS or content injection.

**Countermeasures**:
1. Implement server-side magic byte inspection (file signature analysis) to validate actual file content regardless of declared Content-Type
2. Add extension allowlisting (`.jpg`, `.jpeg`, `.png`, `.webp`, `.gif` only for images)
3. Re-process uploaded images through an image transcoding service to strip embedded metadata and ensure the file is a valid image

---

### MOD-02: Audit Log Scope Is Insufficient for Security Monitoring

**Section**: 8.4 (監査ログ), 9.4

**Issue**: The audit log records business events (tenant registration, product publish/unpublish, order status change, data export) but the design is ambiguous about security events. Section 9.4 states authentication failures and role changes should be logged, but section 8.4 does not include these in the enumerated audit events, and both sections route to the same CloudWatch log stream.

**Impact**: Security events (authentication failures, permission changes, tenant isolation attempts) are not clearly separated from application logs. This makes security incident detection and forensic analysis difficult. Mixing audit logs with application logs risks loss of audit trail integrity.

**Countermeasures**:
1. Define an explicit security audit log category separate from business event logs: authentication failures, role/permission changes, admin actions on user data, tenant isolation violations
2. Route security audit logs to a dedicated CloudWatch log group with stricter retention and access controls
3. Set up CloudWatch Alarms for critical security events (authentication failure spikes, repeated permission denied errors)

---

### MOD-03: PII Data Retention Policy Is Undefined

**Section**: 5.3 (個人情報管理)

**Issue**: The design explicitly defers the data retention and deletion policy:

> 「データ保持期間・削除方針: 現時点では未定義。退会申請があった場合の対応フローは今後設計する」

**Impact**: Operating a platform that collects PII without defined retention and deletion policies likely violates GDPR (right to erasure), APPI (Japan's Personal Information Protection Act), and similar regulations. In a multi-tenant marketplace, user data spans multiple tenants, making deletion even more complex.

**Countermeasures**:
1. Define and implement a PII retention policy before launch: maximum retention period, automatic deletion schedule, and account deletion workflow
2. Design the deletion workflow to handle the multi-tenant case (a buyer who has orders across multiple tenants)
3. Consider soft-delete with scheduled hard-delete, ensuring PII fields are nullified or anonymized on deletion

---

### MOD-04: multer@1.4.4 Is a Known Vulnerable Version

**Section**: 8.2 (依存ライブラリ管理)

**Issue**: `multer@1.4.4` is specified in the technology stack. This version has known security vulnerabilities (CVE-2022-24434 and related). The file upload path primarily uses Presigned URL direct upload, but multer may still be used for server-side multipart handling.

**Impact**: If multer is used in any server-side multipart processing path, known vulnerabilities could be exploited for denial of service or file handling bypass.

**Countermeasures**:
1. Upgrade to `multer@2.x` or the latest patched version
2. If multer is not used in any server-side path (all uploads via Presigned URLs), remove the dependency entirely
3. Add automated dependency vulnerability scanning (e.g., `npm audit`, Dependabot, Snyk) to CI/CD pipeline rather than quarterly manual review

---

## Minor Issues and Positive Aspects

### Positive Aspects

- **Password hashing**: bcrypt with cost factor 12 is appropriate and explicitly specified (Section 4.1)
- **Refresh token security**: HttpOnly cookie storage for refresh tokens is correct (Section 4.1)
- **Refresh token blacklist**: Server-side blacklisting in Redis on logout is correctly designed (Section 4.2)
- **Payment card scope reduction**: Delegating card handling to Stripe eliminates PCI DSS scope for card data (Section 5.1)
- **SQL injection prevention**: Prisma ORM parameterized queries are specified (Section 6.1)
- **XSS defense**: JSX auto-escaping plus DOMPurify for rich text plus CSP `default-src 'self'` is a good layered defense (Section 6.2)
- **Secret management**: AWS Secrets Manager for primary secret storage is appropriate (Section 8.1) — however negated by CRIT-02
- **Network segmentation**: Private subnet + VPN for management console + Security Groups follow least privilege principles (Section 8.3)
- **S3 access control**: Private bucket with time-limited signed URLs (7 days) for sensitive documents is appropriate (Section 5.4) — note: 7-day validity may be excessive; consider 1-hour for invoices

### Minor Improvements

- **MIN-01**: KMS key rotation at 1 year is the default but consider 90-day rotation for JWT signing keys specifically, given the long refresh token lifetime (30 days)
- **MIN-02**: Signed URL validity of 7 days for invoices and contracts (Section 5.4) is long; reduce to 1-4 hours to limit exposure window if a signed URL is inadvertently shared
- **MIN-03**: The design does not specify Content-Security-Policy reporting (`report-uri` or `report-to`); adding CSP violation reporting would improve visibility into potential XSS attempts
- **MIN-04**: The design references section 7.4 for security requirements in section 8.4, but section 7.4 does not exist in the document; this is a documentation inconsistency that could cause confusion during implementation

---

## Issue Summary

| ID | Severity | Category | Title |
|---|---|---|---|
| CRIT-01 | Critical | Data Protection | PII stored in plaintext relying solely on storage-layer (TDE) encryption |
| CRIT-02 | Critical | Infrastructure | Production secrets committed to version control |
| CRIT-03 | Critical | Authorization | Tenant isolation relies solely on application-layer filtering |
| SIG-01 | Significant | Authentication | Access token stored in localStorage |
| SIG-02 | Significant | Authentication | No rate limiting on authentication endpoints |
| SIG-03 | Significant | Authorization | Stripe webhook lacks signature verification |
| SIG-04 | Significant | Input Validation | CORS wildcard subdomain with credentials enabled |
| SIG-05 | Significant | Authentication | Access tokens cannot be immediately revoked |
| MOD-01 | Moderate | Input Validation | File upload MIME validation is client-controlled |
| MOD-02 | Moderate | Audit | Security audit log scope insufficient |
| MOD-03 | Moderate | Data Protection | PII retention policy undefined |
| MOD-04 | Moderate | Dependencies | multer@1.4.4 is a known vulnerable version |
