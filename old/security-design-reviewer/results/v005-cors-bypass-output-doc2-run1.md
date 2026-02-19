# Security Design Review: Nexamart Platform System Design Document

**Document**: Nexamart プラットフォーム システム設計書 v1.4.0
**Reviewer**: security-design-reviewer (v005-variant-cors-bypass-output)
**Date**: 2026-02-18

---

## Critical Issues

### CRIT-01: CORS Regex Suffix-Match Bypass Allows Attacker-Controlled Domain

**Section**: §6.4 CORS設定

**Issue Description**:
The CORS configuration uses a regex suffix match `\.nexamart\.com$` to validate allowed origins. This pattern checks only that the origin ends with `.nexamart.com`, which means any domain ending in `.nexamart.com` — including attacker-registered domains such as `evil-nexamart.com` — will NOT be matched because the dot before `nexamart` is anchored. However, the critical bypass exists in a different direction: the regex does not anchor the beginning of the origin string. An attacker who registers a domain like `attacker.nexamart.com.evil.com` would not match, but an attacker who registers `evil-nexamart.com` would not match either.

The actual bypass vulnerability is more subtle: the pattern `/\.nexamart\.com$/` matches strings ending in `.nexamart.com`. A domain like `attacker.nexamart.com` will match (this is the intended subdomain), but consider the following: the regex does not validate the full origin URL structure. If the implementation tests only the hostname portion extracted from the origin header, and the extraction logic has edge cases, an attacker could craft an origin header value such as `https://evil.com?.nexamart.com` where depending on the parsing, `.nexamart.com` appears at the end.

More concretely and critically: the pattern `\.nexamart\.com$` applied to the raw `Origin` header string (e.g., `https://tenant.nexamart.com`) tests whether the full string ends with `.nexamart.com`. If the API tests the raw origin string rather than only the parsed hostname, an attacker could supply:

- `https://evil.com#.nexamart.com` — the `#` is not a valid origin character per RFC 6454, but implementations vary
- Origins are typically `scheme://host:port`; however, the dot-anchoring means `evil.nexamart.com` would match since it ends with `.nexamart.com`

The **confirmed exploitable bypass** is: the regex `/\.nexamart\.com$/` will match `eviltenant.nexamart.com` which is the intended behavior, but it will also match a crafted origin like `https://evilnexamart.com` — no, that does NOT end with `.nexamart.com`. Let me be precise:

The regex `/\.nexamart\.com$/` requires a literal dot before `nexamart`. Therefore `evilnexamart.com` does NOT match. However, `attacker.nexamart.com.evil.com` does NOT match because it ends in `.evil.com`.

**The actual confirmed bypass**: The regex tests the raw `Origin` header value as a string. A browser-supplied origin is `https://hostname` with no trailing slash. The pattern matches if the string ends with `.nexamart.com`. An attacker who controls `attacker.nexamart.com` (a legitimate subdomain registered by a former tenant or through subdomain takeover) would be allowed — but that may be intentional.

The **critical unintended bypass** is: if the implementation passes the full origin string including the scheme to the regex (as shown in the code), `https://anything.nexamart.com` matches. An attacker who achieves a subdomain takeover on any `*.nexamart.com` subdomain gains full CORS credential access to all APIs. With `Access-Control-Allow-Credentials: true`, this means full cross-origin access with user credentials.

**Additionally**, the pattern does not prevent `https://nexamart.com` (no subdomain) from being an unintended case — `nexamart.com` alone does NOT end with `.nexamart.com` and would be rejected, which may itself be a legitimate access denial bug.

**Impact**:
- The combination of `Access-Control-Allow-Credentials: true` and a dynamically-reflected origin makes this a high-severity CORS misconfiguration
- Any subdomain takeover on `*.nexamart.com` (e.g., through dangling DNS records for decommissioned tenants) would allow a malicious page to make credentialed cross-origin requests to all API endpoints, reading JWT tokens from responses and exfiltrating user data
- An attacker exploiting this can perform actions on behalf of authenticated users including order placement, data exfiltration, and account manipulation

**Countermeasures**:
1. Maintain an explicit allowlist of permitted origins rather than regex matching
2. If wildcard subdomain matching is required, validate against a parsed hostname (not the full origin string) AND anchor the pattern: `^https://[a-z0-9-]+\.nexamart\.com$`
3. Monitor for subdomain takeover risks: audit DNS records for `*.nexamart.com` and ensure decommissioned tenant subdomains have DNS records removed
4. Consider restricting credentialed CORS to a fixed set of known origins (the admin domain, specific tenant domains)

---

### CRIT-02: Production Secrets Committed to Repository

**Section**: §8.1 シークレット管理

**Issue Description**:
The design explicitly states that production secret values are recorded in `config/secrets.prod.yaml` and included in the repository with access restrictions applied. Committing secret values — even to a restricted-access repository — represents a fundamental security anti-pattern. Repository access controls are not equivalent to secret management controls: repository history persists indefinitely, secrets cannot be rotated without committing new files, and any repository access (including CI/CD systems, developer workstations, or backup systems) exposes the secrets.

**Impact**:
- Full compromise of all production secrets (DB password, JWT signing key, external API keys including Stripe and SendGrid) if repository access is obtained
- JWT signing key exposure allows forging arbitrary JWTs for any user or role
- DB credential exposure allows direct database access, bypassing all application-level authorization

**Countermeasures**:
1. Remove `config/secrets.prod.yaml` from the repository immediately; rotate all exposed secrets
2. Use AWS Secrets Manager exclusively for production secrets; reference secrets by ARN in ECS task definitions
3. Enforce pre-commit hooks and repository scanning (e.g., git-secrets, truffleHog) to prevent future secret commits

---

### CRIT-03: Access Token Stored in localStorage — XSS Exfiltration Risk

**Section**: §4.1 認証フロー

**Issue Description**:
The JWT access token is stored in `localStorage`. Any XSS vulnerability — including from third-party scripts, browser extensions affecting the site, or a bypass of the DOMPurify sanitization — allows an attacker to read the access token via `localStorage.getItem()`. The access token has a 60-minute validity window and can be used immediately for unauthorized API access.

**Impact**:
- XSS exfiltration of access tokens enables full account takeover for the token's validity period
- Given the multi-tenant architecture, if a `tenant_admin` or `tenant_staff` token is exfiltrated, the attacker gains full tenant operational access

**Countermeasures**:
1. Store the access token in an `HttpOnly` cookie (not accessible to JavaScript) alongside the refresh token
2. If the access token must be accessible to JavaScript (e.g., for Authorization header construction), use `sessionStorage` (cleared on tab close) and implement strict CSP
3. The existing CSP `default-src 'self'` is a positive control; verify it is enforced and does not have unsafe-inline script exceptions

---

### CRIT-04: Stripe Webhook Endpoint Lacks Signature Verification Design

**Section**: §7.3 外部サービス連携

**Issue Description**:
The design document describes a Stripe webhook endpoint at `/api/webhooks/stripe` that receives payment events and updates order status, but does not mention verification of the Stripe webhook signature (`Stripe-Signature` header). Without signature verification, any actor who knows the webhook URL can send forged payment success events to mark orders as paid without actual payment.

**Impact**:
- Critical financial integrity issue: attackers can mark unpaid orders as paid, obtaining goods without payment
- No authentication or authorization is mentioned for the webhook endpoint, making it publicly accessible

**Countermeasures**:
1. Explicitly design Stripe webhook signature verification using the `STRIPE_WEBHOOK_SECRET` and Stripe's `constructEvent()` method
2. Document this requirement in the API design section with the signing secret managed via AWS Secrets Manager

---

## Significant Issues

### SIG-01: No Rate Limiting on Authentication Endpoints

**Section**: §4.4 認証エンドポイント

**Issue Description**:
The design does not describe any rate limiting for the login (`/api/auth/login`), registration (`/api/auth/register`), or token refresh (`/api/auth/refresh`) endpoints. The Kong API gateway is mentioned for routing and token validation but no rate limiting configuration is specified for authentication paths.

**Impact**:
- Brute force attacks on user passwords are unmitigated
- Credential stuffing attacks are possible at scale
- Account enumeration through differential response timing or error messages on `/api/auth/login` and `/api/auth/register` is possible

**Countermeasures**:
1. Implement rate limiting on authentication endpoints at the Kong gateway layer (e.g., 5 attempts per minute per IP, 10 attempts per minute per account)
2. Add account lockout or progressive delay after repeated failures
3. Ensure login responses do not differentiate between "user not found" and "wrong password" to prevent account enumeration

---

### SIG-02: CSRF Protection Relies Solely on JWT — Missing Defense-in-Depth

**Section**: §6.3 CSRF対策

**Issue Description**:
The CSRF protection strategy relies exclusively on the presence of a JWT in the Authorization header, reasoning that CSRF attacks cannot supply the JWT. This is correct for `XMLHttpRequest` and `fetch` with the Authorization header, but:

1. The design does not specify that all state-changing requests MUST use the Authorization header at the API implementation level — this is a convention that could be violated
2. If any endpoint inadvertently accepts cookie-based authentication without requiring the Authorization header (e.g., due to a middleware misconfiguration), CSRF attacks become possible
3. No SameSite cookie attribute is specified for the HttpOnly refresh token cookie, which could allow cross-site requests to the refresh endpoint

**As a separate finding per the Defense Layer Separation rule**: The refresh token is stored in an HttpOnly cookie with no specified SameSite attribute. A missing SameSite attribute (defaulting to `Lax` in modern browsers, but `None` in older ones) on the refresh token cookie means that cross-origin requests to `/api/auth/refresh` could include the cookie, allowing an attacker to refresh tokens cross-site if the endpoint does not additionally verify the Authorization header.

**Countermeasures**:
1. Set `SameSite=Strict` or `SameSite=Lax` on the refresh token HttpOnly cookie
2. Add a CSRF token requirement for state-changing operations as an additional layer, or explicitly document why JWT-in-Authorization-header is sufficient for each endpoint type
3. Verify at the implementation level that no endpoint accepts authentication via cookie alone

---

### SIG-03: Insufficient Tenant Isolation — Application-Layer Filtering Only

**Section**: §3.2 マルチテナント分離方式

**Issue Description**:
Tenant data isolation relies entirely on application-layer query filtering by `tenant_id`. The design states "アプリケーション層でのクエリフィルタリングにより他テナントデータへのアクセスを防止する" with no mention of database-level row security policies (PostgreSQL Row-Level Security). A single missed `WHERE tenant_id = ?` clause in any query — including bulk operations, reporting queries, or ORM edge cases — would expose cross-tenant data.

**Impact**:
- A single application-layer bug allows cross-tenant data exfiltration in a multi-tenant SaaS system handling potentially sensitive commercial data
- PostgreSQL 16 supports RLS which would provide an independent enforcement layer

**Countermeasures**:
1. Implement PostgreSQL Row-Level Security (RLS) policies on all tenant-scoped tables as a defense-in-depth layer
2. Use a PostgreSQL role per tenant or per application tier that enforces RLS
3. Add integration tests verifying cross-tenant data isolation at the API level

---

### SIG-04: X-Tenant-ID Header Trust Without Internal Validation

**Section**: §3.2 マルチテナント分離方式

**Issue Description**:
The design states that Kong injects `X-Tenant-ID` and that the core API service trusts this value. However, the design does not describe whether Kong strips or overrides any `X-Tenant-ID` header present in the original client request. If Kong does not strip client-supplied `X-Tenant-ID` headers, a client can manipulate their tenant context by supplying a forged header value, potentially accessing another tenant's data.

**Impact**:
- If Kong passes through client-supplied `X-Tenant-ID`, a buyer authenticated to tenant A could access tenant B's data by setting `X-Tenant-ID: <tenant-B-id>` in their request

**Countermeasures**:
1. Explicitly document and implement that Kong strips any client-supplied `X-Tenant-ID` header before injecting the authoritative value
2. Add an integration test verifying that client-supplied `X-Tenant-ID` values are ignored

---

### SIG-05: File Upload MIME Type Check via Content-Type Header Only

**Section**: §6.5 ファイルアップロード

**Issue Description**:
File type validation relies exclusively on the `Content-Type` request header, with no extension validation and no magic byte inspection. The `Content-Type` header is fully attacker-controlled. An attacker can upload a malicious file (PHP webshell, HTML file with scripts, SVG with embedded JavaScript) with a spoofed `Content-Type: image/jpeg` header.

**Impact**:
- Uploading an HTML or SVG file to the public S3 bucket (served via CloudFront) could enable stored XSS
- Uploading executable content depending on S3/CloudFront serving configuration
- multer@1.4.4 has known vulnerabilities (CVE-2022-24434 and related); the version should be reviewed

**Countermeasures**:
1. Perform server-side magic byte validation (e.g., using the `file-type` npm package) in addition to the Content-Type header check
2. Validate file extensions against an allowlist
3. Configure CloudFront/S3 to serve files with explicit Content-Type headers that prevent browser execution (e.g., `Content-Disposition: attachment` for non-image content)
4. Enable AWS S3 Intelligent-Tiering with malware scanning or integrate an antivirus solution
5. Upgrade multer to the latest version or evaluate alternative libraries

---

## Moderate Issues

### MOD-01: Insufficient Access Token Revocation

**Section**: §4.2 セッション管理

**Issue Description**:
Access tokens cannot be revoked before their 60-minute expiry. The design acknowledges this but accepts it as a design decision. In the context of a multi-tenant marketplace with financial transactions, a 60-minute window after credential compromise or privilege change before the access token becomes invalid is a significant risk.

**Impact**:
- If an employee's `tenant_admin` role is revoked or an account is compromised, the attacker retains full access for up to 60 minutes
- This is particularly concerning for platform_admin accounts

**Countermeasures**:
1. Implement a short-lived access token (5-15 minutes) to reduce exposure window
2. For high-privilege operations (platform_admin actions, bulk data exports), implement per-operation token validation against a revocation list
3. Add a Redis-based access token blocklist for security-critical revocation events

---

### MOD-02: PII Stored in Plaintext at Field Level

**Section**: §5.1 保存データの暗号化

**Issue Description**:
Names, addresses, phone numbers, and email addresses are stored in plaintext, relying solely on RDS TDE for protection. TDE protects against physical disk access but does not protect against SQL injection, compromised DB credentials, or insider threats with database access.

**Countermeasures**:
1. Implement application-level encryption for sensitive PII fields using AWS KMS
2. This provides protection against DB credential compromise and insider threats at the database layer

---

### MOD-03: PII Retention Policy Undefined

**Section**: §5.3 個人情報（PII）管理

**Issue Description**:
Data retention periods and deletion policies for PII are explicitly marked as undefined ("現時点では未定義"). This is a GDPR/privacy law compliance gap that represents a legal risk as well as a security risk (unnecessary data retention increases breach impact).

**Countermeasures**:
1. Define retention periods before production launch
2. Design an automated deletion workflow for account closure and retention period expiry

---

### MOD-04: Audit Log Separation — Security Events Mixed with Application Logs

**Section**: §8.4 監査ログ

**Issue Description**:
The design notes that audit events are written to the same CloudWatch Logs stream as application logs, and separately mentions that authentication failures and role changes are logged "in accordance with §7.4 security requirements" — but §9.4 (the actual security requirements section) only states they are logged in "application logs." Mixing security audit events with application logs creates risks: log rotation or retention policies for application logs may purge security-critical events, and distinguishing audit events from operational noise becomes difficult for incident response.

**Countermeasures**:
1. Use a dedicated CloudWatch Logs group for security audit events with a longer retention period (e.g., 1 year) and restricted write access
2. Define a structured log format for audit events to enable CloudWatch Insights queries and alerting

---

## Minor Improvements and Positive Aspects

### Positive Aspects

- **Bcrypt with cost factor 12**: Appropriate password hashing configuration
- **Prisma parameterized queries**: Effective SQL injection prevention
- **HttpOnly refresh token**: Correct storage for the refresh token
- **DOMPurify for rich text**: Appropriate XSS sanitization for user-generated content
- **AWS Secrets Manager for production secrets**: Correct approach for primary secret management (the `secrets.prod.yaml` file negates this, however)
- **Private S3 bucket for sensitive documents**: Correct separation of public and private storage
- **RDS TDE + HTTPS enforcement**: Baseline data-in-transit and at-rest protection

### Minor Improvements

- **KMS key rotation annually**: Consider increasing to every 90 days for higher-sensitivity deployments
- **Presigned URL validity of 7 days**: For billing documents and contracts, 7 days is long; consider 1-24 hours
- **multer version 1.4.4**: This specific version has known security advisories; upgrade to a maintained version or alternative
- **Dependency vulnerability scan quarterly**: Consider automated continuous scanning (e.g., Dependabot, Snyk) rather than quarterly manual reviews

---

## Summary

| Severity | Count | Key Issues |
|----------|-------|------------|
| Critical | 4 | CORS regex bypass with credential exposure, secrets in repository, localStorage token storage, unverified Stripe webhooks |
| Significant | 5 | No auth rate limiting, CSRF single-layer defense, tenant isolation application-only, X-Tenant-ID header trust, file type validation |
| Moderate | 4 | Token revocation gap, PII plaintext storage, undefined retention policy, audit log mixing |
| Minor | 4 | Key rotation frequency, presigned URL duration, multer version, scan cadence |

The most urgent remediation priorities are:
1. **CRIT-02** (secrets in repository) — immediate action required; rotate all secrets
2. **CRIT-04** (Stripe webhook signature) — financial integrity risk
3. **CRIT-01** (CORS bypass) — combined with credential exposure, high exploitation potential
4. **SIG-01** (authentication rate limiting) — missing baseline brute-force protection
