# Security Design Review: Nexamart Platform v1.4.0

**Document**: test-document-2.md (Nexamart Platform System Design)
**Reviewer Variant**: v004-variant-input-finding-separation
**Date**: 2026-02-18

---

## Critical Issues

### [CRITICAL-01] JWT-based CSRF Mitigation Reported as Sole Defense Layer

**Issue**: Section 6.3 states that requiring Authorization header with JWT for all state-changing operations (POST/PUT/PATCH/DELETE) is "sufficient as CSRF protection." No additional CSRF countermeasures (CSRF tokens, SameSite cookie attributes) are explicitly designed.

**Impact**: While JWT in Authorization headers mitigates traditional CSRF for API calls, this defense relies entirely on the assumption that attackers cannot set custom headers cross-origin. If any subresource loading, CORS misconfiguration (see CRITICAL-02), or browser behavior change occurs, this single layer provides no fallback. State-changing operations for authenticated users remain at risk if the JWT-only assumption is violated.

**Countermeasures**:
- Add `SameSite=Strict` or `SameSite=Lax` attribute to the HttpOnly refresh token cookie (section 4.1 specifies HttpOnly but not SameSite)
- Implement Double Submit Cookie or Synchronizer Token Pattern as an independent second layer for state-changing operations
- Document explicitly why JWT-in-header is considered sufficient and under what browser/protocol assumptions

**Design Document Reference**: Section 6.3

---

### [CRITICAL-02] Missing SameSite Cookie Attribute as Independent CSRF Defense Layer

**Issue**: The refresh token is stored as `HttpOnly` Cookie (section 4.1), but no `SameSite` attribute is specified. The absence of an explicit `SameSite` attribute design means the cookie may default to `SameSite=None` or browser-default behavior depending on the client environment, allowing cross-site requests to include the refresh token.

**Impact**: Even if state-changing API calls require JWT in the Authorization header, the refresh token endpoint (`POST /api/auth/refresh`) does not require a custom header — it relies on the cookie. Without `SameSite` protection, an attacker can trigger token refresh from a cross-site context, potentially obtaining a new access token or extending session lifetime.

**Countermeasures**:
- Explicitly specify `SameSite=Strict` or `SameSite=Lax` for the refresh token cookie
- Document the intended SameSite policy as part of the session management design in section 4.2

**Design Document Reference**: Section 4.1, Section 4.2

*Note: This is reported as a separate finding from CRITICAL-01. CRITICAL-01 concerns the absence of CSRF protection for state-changing API operations; CRITICAL-02 concerns the absence of SameSite protection on the refresh token cookie as an independent defense layer for the token refresh endpoint.*

---

### [CRITICAL-03] CORS Wildcard Subdomain with Credentials Enabled

**Issue**: Section 6.4 permits any origin matching `*.nexamart.com` via regex. Combined with `Access-Control-Allow-Credentials: true`, this means any subdomain (including tenant subdomains that could be compromised or maliciously registered) can make credentialed cross-origin requests to the API.

**Impact**: If an attacker creates or compromises a tenant with subdomain `evil.nexamart.com`, they can make credentialed API requests to other tenant APIs or the core API service on behalf of authenticated users. In a multi-tenant marketplace, this creates cross-tenant data exfiltration risk via CORS abuse.

**Countermeasures**:
- Enumerate explicitly allowed origins rather than using wildcard regex matching with credentials
- Separate public API origins (where credentials are not needed) from authenticated API origins with strict origin allowlists
- For credentialed requests, require exact origin match against a maintained allowlist

**Design Document Reference**: Section 6.4

---

### [CRITICAL-04] Production Secrets Stored in Version-Controlled Repository

**Issue**: Section 8.1 states: "Production secret values are also recorded in `config/secrets.prod.yaml` for deployment personnel reference, included in the repository with access restrictions."

**Impact**: Storing production secrets (DB passwords, API keys, JWT signing keys) in a version-controlled repository — even with access restrictions — creates persistent exposure risk. Git history retains secrets even after removal. Repository access controls can be misconfigured. This contradicts the stated use of AWS Secrets Manager and creates a parallel secret store that may become the actual source of truth.

**Countermeasures**:
- Remove `config/secrets.prod.yaml` from the repository immediately and purge git history
- Use AWS Secrets Manager as the single source of truth; deployment personnel should access secrets via IAM-controlled Secrets Manager APIs
- If documentation is needed, reference secret names and rotation policies, never values

**Design Document Reference**: Section 8.1

---

### [CRITICAL-05] Tenant Isolation Relies Solely on Application-Layer Query Filtering

**Issue**: Section 3.2 uses a shared schema with `tenant_id` columns. Tenant isolation is enforced by "application-layer query filtering." No database-level Row Level Security (RLS), separate database users per tenant, or additional enforcement mechanism is described.

**Impact**: A single application bug (missing WHERE clause, ORM misconfiguration, or raw query) can expose all tenants' data. In a multi-tenant marketplace with sensitive order, PII, and financial data, a single bypass of the application-layer filter results in complete cross-tenant data breach.

**Countermeasures**:
- Implement PostgreSQL Row Level Security (RLS) as a database-level enforcement layer independent of application logic
- Use separate database roles per tenant with RLS policies to prevent any query from returning cross-tenant data even if application filtering fails
- Conduct regular tests with intentionally missing tenant_id filters to validate defense-in-depth

**Design Document Reference**: Section 3.2

---

### [CRITICAL-06] X-Tenant-ID Header Trusted Without End-to-End Validation

**Issue**: Section 3.2 states that Kong gateway attaches the `X-Tenant-ID` header, and the core API service trusts this value for data scoping. Section 3.3 confirms that requests passing through the gateway are treated as trusted. No mention of validating that the `X-Tenant-ID` value was actually set by Kong and not injected or overridden by the client.

**Impact**: If a client can inject or override the `X-Tenant-ID` header before Kong processes it, they can cause the API to scope all data access to any arbitrary tenant. This enables complete cross-tenant data access by any authenticated user.

**Countermeasures**:
- Configure Kong to strip any client-provided `X-Tenant-ID` header before attaching its own verified value
- Validate at the API service level that the `X-Tenant-ID` is consistent with the JWT `tenantId` claim for tenant-scoped operations
- Document the trust model explicitly: which headers are client-controlled vs. gateway-controlled

**Design Document Reference**: Section 3.2, Section 3.3

---

## Significant Issues

### [HIGH-01] Access Token in localStorage — XSS Exfiltration Risk

**Issue**: Section 4.1 stores the JWT access token in `localStorage`. While XSS countermeasures exist (CSP, DOMPurify), `localStorage` is fully accessible to any JavaScript executing in the page context.

**Impact**: A successful XSS attack (including via third-party scripts, CDN compromise, or DOMPurify bypass) can silently exfiltrate the access token, enabling session hijacking without the victim's knowledge. The 60-minute expiry limits but does not eliminate the window.

**Countermeasures**:
- Store the access token in a `HttpOnly` memory-equivalent or use the BFF (Backend For Frontend) pattern where tokens are kept server-side
- If localStorage must be used, document the explicit risk acceptance and compensating controls (short expiry, anomaly detection)

**Design Document Reference**: Section 4.1

---

### [HIGH-02] No Rate Limiting on Authentication Endpoints

**Issue**: Sections 4.4 and 6 describe login (`POST /api/auth/login`), registration (`POST /api/auth/register`), and token refresh (`POST /api/auth/refresh`) endpoints, but no rate limiting design is mentioned for any of these endpoints.

**Impact**: Without rate limiting, brute-force attacks on login, credential stuffing attacks, and abuse of the token refresh endpoint are possible at scale.

**Countermeasures**:
- Implement rate limiting at the Kong gateway level for `/api/auth/login` and `/api/auth/refresh` (e.g., 10 attempts per minute per IP)
- Implement account lockout or CAPTCHA after repeated login failures
- Add rate limiting for `/api/auth/register` to prevent account creation abuse

**Design Document Reference**: Section 4.4, Section 9.4

---

### [HIGH-03] No Rate Limiting on Login Endpoint as Independent Finding from Account Lockout

**Issue**: Section 4.4 defines the login endpoint without any design for per-account rate limiting or lockout distinct from IP-based rate limiting. IP-based throttling alone can be bypassed by distributed attacks, while account-level lockout is a separate defense layer.

**Impact**: Distributed credential stuffing attacks using multiple IPs can bypass IP-based rate limits. Without per-account lockout or progressive delay, attackers can attempt unlimited passwords against any single account by rotating IP addresses.

**Countermeasures**:
- Implement per-account login attempt tracking (e.g., 5 failed attempts trigger account lockout with notification)
- Design lockout and unlock flows explicitly in section 4.4 or 9.4

**Design Document Reference**: Section 4.4

*Note: This is reported as a separate finding from HIGH-02. HIGH-02 concerns absence of IP-based rate limiting at the endpoint level; HIGH-03 concerns absence of per-account lockout as an independent, complementary defense layer.*

---

### [HIGH-04] Immediate Token Revocation Not Possible for Access Tokens

**Issue**: Section 4.2 explicitly states that access token revocation relies on expiry only ("no server-side blocklist"), and that immediate revocation in case of unauthorized access or permission change depends on refresh token expiry (up to 30 days).

**Impact**: If a user's account is compromised, a tenant admin is revoked, or a platform admin role is changed, the existing access token remains valid for up to 60 minutes. For high-privilege operations (platform_admin, tenant_admin), this window represents significant risk.

**Countermeasures**:
- Implement a short-lived token blocklist in Redis for critical revocation events (compromise detection, admin role changes)
- Alternatively, significantly shorten access token lifetime (e.g., 5-10 minutes) to reduce the revocation window
- Design an explicit flow for forced revocation in security incident response

**Design Document Reference**: Section 4.2

---

### [HIGH-05] File Upload MIME Type Validation Relies on Client-Provided Header Only

**Issue**: Section 6.5 states MIME type checking uses `Content-Type` header only, with no extension validation. The `Content-Type` header is entirely client-controlled and can be spoofed.

**Impact**: An attacker can upload a malicious file (e.g., a PHP script, HTML with embedded JavaScript, or SVG with script tags) by setting `Content-Type: image/jpeg` while the actual file content is malicious. Files served via CloudFront CDN from the public bucket could execute in victim browsers.

**Countermeasures**:
- Perform server-side magic bytes (file signature) validation in addition to or instead of Content-Type header checking
- Validate file extensions against an allowlist
- Re-process uploaded images through an image transcoding pipeline to strip any embedded malicious content before serving
- Prioritize introduction of virus scanning (currently "future work") given public CDN serving

**Design Document Reference**: Section 6.5

---

### [HIGH-06] File Upload Extension Validation Absent as Separate Defense Layer

**Issue**: Section 6.5 explicitly states "extension validation: none." File extension checking is a defense layer independent from MIME type checking. Its absence is noted as a distinct gap.

**Impact**: Even if magic bytes validation is added for MIME types, absence of extension validation means filenames like `shell.php.jpg` or `malicious.svg` may be accepted and served with unexpected interpretations by the CDN or downstream systems.

**Countermeasures**:
- Enforce allowlist-based extension validation (e.g., `.jpg`, `.jpeg`, `.png`, `.webp` only) at the server side before issuing Presigned URLs or processing uploads

**Design Document Reference**: Section 6.5

*Note: This is reported as a separate finding from HIGH-05. HIGH-05 concerns reliance on the client-controlled Content-Type header; HIGH-06 concerns the independent absence of extension-based validation.*

---

### [HIGH-07] Stripe Webhook Endpoint Missing Signature Verification Design

**Issue**: Section 7.3 mentions that Stripe Webhook events are received at `/api/webhooks/stripe` and used to update payment status. No mention of verifying the `Stripe-Signature` header to authenticate that requests originate from Stripe.

**Impact**: Without webhook signature verification, any party can send forged webhook events to `/api/webhooks/stripe` to fraudulently mark orders as paid without actual payment.

**Countermeasures**:
- Explicitly design Stripe webhook signature verification using the `stripe-signature` header and the Stripe webhook signing secret
- Require this verification before any business logic (payment status update) is executed

**Design Document Reference**: Section 7.3

---

### [HIGH-08] Security Audit Log Separation and Integrity Not Designed

**Issue**: Section 8.4 states security audit logs are output to the same CloudWatch Logs stream as application logs. Section 9.4 references audit logging of auth failures and permission changes. No design for log integrity protection, tamper detection, or separation from operational logs is described.

**Impact**: Commingling security audit logs with operational logs makes forensic investigation difficult, allows operational noise to obscure security events, and does not protect against insider log tampering. If the application is compromised, an attacker with log access can alter or delete security events.

**Countermeasures**:
- Use a dedicated CloudWatch Logs log group for security audit events, separate from application logs
- Enable CloudWatch Logs log group encryption and consider shipping to immutable storage (S3 with Object Lock) for tamper protection
- Define explicitly which events constitute security audit log entries (auth failures, role changes, sensitive data access, admin operations)

**Design Document Reference**: Section 8.4, Section 9.4

---

## Moderate Issues

### [MOD-01] PII Stored in Plaintext — RDS TDE as Sole Protection Layer

**Issue**: Section 5.1 states PII fields (name, address, phone number) are stored in plaintext, relying solely on RDS Transparent Data Encryption. No field-level encryption is designed.

**Impact**: RDS TDE protects against physical media theft but does not protect against SQL injection, compromised DB credentials, misconfigured access controls, or insider threats with database access. PII is fully readable to anyone with database query access.

**Countermeasures**:
- Implement application-level field encryption (AES-256) for PII fields with keys managed in AWS KMS
- At minimum, document the explicit risk acceptance that RDS TDE is the sole PII protection layer and ensure compensating controls (DB access auditing, IAM restrictions) are designed

**Design Document Reference**: Section 5.1

---

### [MOD-02] Data Retention and Deletion Policy Undefined

**Issue**: Section 5.3 explicitly states the data retention period and deletion policy are "currently undefined," and the user account deletion flow is "future design."

**Impact**: Without defined retention and deletion policies, the system accumulates PII indefinitely, creating compliance risk (GDPR right to erasure, Japanese Personal Information Protection Act) and expanding the attack surface. A data breach affecting historical records compounds impact.

**Countermeasures**:
- Define retention periods for each PII category before production launch
- Design account deletion flow including cascading deletion or anonymization of associated PII
- Document regulatory requirements applicable to the jurisdiction(s) of operation

**Design Document Reference**: Section 5.3

---

### [MOD-03] Signed URL Validity Period for Private Documents Is Excessive

**Issue**: Section 5.4 grants signed URL validity of 7 days for private documents (invoices, contracts).

**Impact**: A signed URL shared or leaked (via browser history, email forward, server log) remains valid for 7 days, giving unauthorized parties extended access to sensitive business documents.

**Countermeasures**:
- Reduce signed URL validity to the minimum operationally required (e.g., 15-60 minutes for on-demand access, 24 hours maximum for download flows)
- Implement signed URL revocation or one-time-use tokens for highly sensitive documents

**Design Document Reference**: Section 5.4

---

### [MOD-04] multer 1.4.4 Known Vulnerability — Outdated Dependency

**Issue**: Section 8.2 lists `multer@1.4.4`. This version has known security issues. The current stable version is 1.4.5-lts.1 or later, which addresses ReDoS and other vulnerabilities.

**Impact**: Using a vulnerable file upload library increases risk for a component that handles untrusted file uploads from the internet.

**Countermeasures**:
- Upgrade to `multer@1.4.5-lts.1` or the latest stable version immediately
- Add multer to the priority list for the quarterly security update process

**Design Document Reference**: Section 8.2

---

### [MOD-05] No Frontend Input Validation Design Noted, But Backend Validation Exists

**Issue**: Section 6.1 confirms Zod schema validation at the backend API level, which is the correct and sufficient layer. However, no mention of frontend validation is present. This is noted as an informational gap — the absence of frontend validation is not a security issue, but its design relationship should be documented.

**Note**: The backend-only validation design is architecturally correct. This item is included for completeness to confirm that the design intentionally relies on backend validation as the authoritative layer.

**Design Document Reference**: Section 6.1

---

## Positive Aspects

- Backend API uses Zod schema validation for all request parameters — correct enforcement at the authoritative layer (Section 6.1)
- Prisma ORM parameterized queries prevent SQL injection (Section 6.1)
- bcrypt with cost factor 12 for password hashing is appropriate (Section 4.1)
- Refresh token stored as HttpOnly cookie reduces XSS exfiltration risk for long-lived credentials (Section 4.1)
- Refresh token blacklisted in Redis on logout — prevents reuse after logout (Section 4.2)
- AWS Secrets Manager for secret management is appropriate (Section 8.1)
- HTTPS enforced end-to-end including internal CloudFront → ECS segment (Section 5.2)
- PII excluded from application logs — reduces log-based data exposure (Section 5.3)
- DOMPurify sanitization for rich text user content (Section 6.2)
- CSP `default-src 'self'` provides baseline XSS mitigation (Section 6.2)
- Admin console access restricted via VPN/IP control (Section 8.3)
- Credit card data fully delegated to Stripe — PCI scope reduction (Section 5.1)

---

## Summary

| Severity | Count | Key Areas |
|----------|-------|-----------|
| Critical | 6 | CSRF single-layer reliance, CORS wildcard+credentials, secrets in repo, tenant isolation app-layer only, X-Tenant-ID header trust |
| High | 8 | localStorage JWT, no rate limiting (IP-level and account-level as separate findings), token revocation, file upload validation (MIME and extension as separate findings), Stripe webhook, audit log integrity |
| Moderate | 5 | PII plaintext, retention policy undefined, signed URL validity, multer outdated, frontend validation note |

**Most urgent actions**: Remove `config/secrets.prod.yaml` from repository (CRITICAL-04), add SameSite attribute to refresh token cookie (CRITICAL-02), add independent CSRF protection layer (CRITICAL-01), configure Kong to strip client `X-Tenant-ID` headers (CRITICAL-06), implement PostgreSQL RLS for tenant isolation (CRITICAL-05), restrict CORS to explicit origin allowlist (CRITICAL-03).
