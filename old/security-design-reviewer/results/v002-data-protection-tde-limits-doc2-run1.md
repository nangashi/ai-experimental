# Security Design Review: Nexamart Platform System Design Document

**Reviewer**: security-design-reviewer (v002-variant-data-protection-tde-limits)
**Document**: test-document-2.md (Nexamart Platform System Design v1.4.0)
**Date**: 2026-02-18

---

## Executive Summary

The Nexamart platform design contains multiple critical and significant security issues. The most severe finding is a fundamentally flawed data protection strategy that stores PII in plaintext while relying solely on RDS TDE—a design that provides inadequate protection against logical database access threats. Several additional critical issues compound the risk posture of this multi-tenant marketplace.

---

## Critical Issues

### C-01: PII Stored in Plaintext with Reliance on TDE Only (Section 5.1)

**Issue**: The design explicitly states that personal information fields (name, address, phone number) are stored in plaintext, and that "RDS TDE encryption provides protection, therefore field-level additional encryption is not required."

**Why This Is Insufficient**: RDS Transparent Data Encryption (TDE) is disk-level encryption that protects against physical media theft (e.g., stolen disk drives). TDE does NOT protect against:
- Logical access by any database user with valid credentials
- Compromised application DB credentials (e.g., via credential stuffing, secrets leakage)
- Insider threats from DB administrators or operations staff
- SQL injection that bypasses application logic and accesses the DB directly
- Malicious queries executed by any party with a valid DB connection

In a multi-tenant SaaS environment storing PII for all tenants' end-users in shared tables, a single compromised DB credential exposes the PII of every user across all tenants. This is a mass data breach scenario.

**Impact**: Critical — complete exposure of all users' PII (name, address, phone number, email) upon any DB-level compromise. Regulatory exposure under GDPR, APPI, and similar frameworks.

**Required Countermeasures**:
- Implement field-level or application-level encryption for high-sensitivity PII columns (name, address, phone number) before storage
- Use AWS KMS or a dedicated key management system to encrypt column values at the application layer
- Consider envelope encryption: encrypt individual field values with data encryption keys (DEKs), which are themselves encrypted with KMS-managed key encryption keys (KEKs)
- Apply separate encryption keys per tenant to ensure tenant data isolation even at the cryptographic layer
- Define and document which PII fields require field-level encryption versus those adequately protected by TDE

---

### C-02: Production Secrets Stored in Repository (Section 8.1)

**Issue**: The design states that production secret values are recorded in `config/secrets.prod.yaml` and included in the repository with "access restrictions."

**Why This Is Critical**: Storing plaintext production secrets in a version-control repository is a critical security anti-pattern. Access restrictions on repository files are fragile; any developer with repository access (or anyone who obtains a repository clone or backup) gains access to all production credentials, including DB passwords, JWT signing keys, and external API keys.

**Impact**: Critical — a single repository access breach (e.g., via a leaked personal access token, CI/CD pipeline compromise, or repository misconfiguration) exposes all production credentials simultaneously.

**Required Countermeasures**:
- Remove `config/secrets.prod.yaml` from the repository immediately and rotate all referenced credentials
- Store all production secrets exclusively in AWS Secrets Manager (already referenced in 8.1)
- Implement secret scanning in CI/CD pipelines to prevent future accidental commits of secrets
- Apply least-privilege access controls on AWS Secrets Manager so only the ECS task role can read the required secrets

---

### C-03: Access Token Stored in localStorage (Section 4.1)

**Issue**: JWT access tokens are stored in `localStorage`.

**Why This Is Critical**: `localStorage` is accessible to any JavaScript running in the browser context. An XSS vulnerability (even a minor one) allows an attacker to steal the access token and impersonate the user for up to 60 minutes with no server-side revocation mechanism.

**Impact**: Critical — XSS-based session hijacking leads to account takeover and unauthorized access to user orders, personal data, and purchasing capabilities.

**Required Countermeasures**:
- Store the access token in an `HttpOnly`, `Secure`, `SameSite=Strict` (or `Lax`) cookie, consistent with the refresh token storage strategy
- If cookie-based storage is not feasible, use in-memory storage (JavaScript variable) with the understanding that the token is lost on page refresh
- Implement server-side access token revocation capability (e.g., short-lived tokens with server-side blocklist for critical operations)

---

### C-04: Inadequate CORS Configuration — Regex Bypass Risk (Section 6.4)

**Issue**: The CORS allowed origin is matched using the regex `\.nexamart\.com$`. This pattern matches any domain ending in `.nexamart.com`, but it also matches domains such as `evilnexamart.com` or `attacker-nexamart.com` if not anchored properly. More critically, the regex does not enforce the expected subdomain structure.

**Specific Risk**: The regex `/\.nexamart\.com$/` would match `attacker.evilnexamart.com` only if it literally ends in `.nexamart.com`—however, a domain like `evil.nexamart.com.attacker.io` would not match. The actual vulnerability is that any attacker who can register a subdomain on a shared hosting service or CDN that routes under `nexamart.com` would receive CORS access with credentials. Additionally, since `Access-Control-Allow-Credentials: true` is set alongside the dynamic origin reflection, a mismatch means cross-origin requests from an allowed origin can carry cookies and credentials.

**Impact**: High — credential-bearing cross-origin requests from unintended origins; risk of cross-origin data theft if any subdomain is compromised.

**Required Countermeasures**:
- Maintain an explicit allowlist of permitted origins rather than regex matching
- Ensure the regex anchors to `^https://` to prevent protocol downgrade attacks
- Audit all legitimate subdomains that require CORS and enumerate them explicitly

---

## Significant Issues

### S-01: No Rate Limiting on Authentication Endpoints (Section 4.4)

**Issue**: The design defines authentication endpoints (`/api/auth/login`, `/api/auth/refresh`, `/api/auth/register`) but does not specify rate limiting or brute force protection for any of them.

**Impact**: High — credential stuffing and brute force attacks against the login endpoint; refresh token abuse via rapid token cycling.

**Required Countermeasures**:
- Implement per-IP and per-account rate limiting on `/api/auth/login` (e.g., 5 failed attempts per account per 15 minutes triggers lockout or CAPTCHA)
- Apply rate limiting to `/api/auth/refresh` to prevent token refresh abuse
- Add account enumeration protection to `/api/auth/register` (consistent error responses regardless of whether the email exists)

---

### S-02: Access Token Cannot Be Immediately Revoked (Section 4.2)

**Issue**: The design explicitly states that access token invalidation relies solely on token expiry (60 minutes), with no server-side blocklist for access tokens. In the event of privilege change, account compromise detection, or security incident, the compromised access token remains valid for up to 60 minutes.

**Impact**: Significant — a compromised or stolen access token cannot be invalidated for up to 60 minutes, allowing continued unauthorized access even after detection.

**Required Countermeasures**:
- Implement a server-side access token blocklist in Redis (consistent with the existing refresh token blacklist mechanism)
- Reduce access token lifetime to 15 minutes to limit the exposure window
- Add a mechanism to force-expire all tokens for a specific user (e.g., by rotating the per-user signing secret or incrementing a token version counter stored in the DB)

---

### S-03: MIME Type Validation by Content-Type Header Only for File Uploads (Section 6.5)

**Issue**: File type validation for uploads relies solely on the `Content-Type` request header, with no extension validation and no virus scanning. The `Content-Type` header is fully attacker-controlled.

**Impact**: Significant — an attacker can upload executable files (scripts, HTML, SVG with embedded JavaScript) by setting an arbitrary `Content-Type` header, potentially leading to stored XSS or malicious content distribution via CloudFront.

**Required Countermeasures**:
- Implement server-side magic byte (file signature) validation in addition to MIME type checking
- Validate file extensions against an allowlist of permitted types
- Process uploaded images through an image re-encoding pipeline (e.g., Sharp) to strip embedded malicious content
- Introduce malware scanning (e.g., ClamAV or AWS GuardDuty Malware Protection for S3) as a post-upload validation step
- Store uploaded files in a separate bucket with a distinct CloudFront distribution to isolate from application domains and prevent cookie-bearing requests to uploaded content

---

### S-04: Stripe Webhook Endpoint Signature Verification Not Specified (Section 7.3)

**Issue**: The design mentions a Stripe webhook endpoint at `/api/webhooks/stripe` that receives payment events and updates order status, but does not specify verification of Stripe's webhook signature (`Stripe-Signature` header).

**Impact**: Significant — without signature verification, an attacker can send forged webhook events (e.g., fake payment success events) to manipulate order statuses, obtaining goods without payment.

**Required Countermeasures**:
- Explicitly design Stripe webhook signature verification using `stripe.webhooks.constructEvent()` with the webhook signing secret
- Restrict the webhook endpoint to Stripe's published IP ranges as a defense-in-depth measure

---

### S-05: Shared Audit Log Stream Compromises Integrity (Section 8.4)

**Issue**: Security audit logs are written to the same CloudWatch Logs stream as application logs. This makes it difficult to set appropriate access controls, retention policies, and tamper detection separately for security-relevant events.

**Impact**: Significant — security events (authentication failures, role changes) cannot be independently protected, retained, or monitored; correlation and forensic analysis are impaired.

**Required Countermeasures**:
- Separate security audit logs into a dedicated CloudWatch Logs log group with strict IAM access controls (write-only for applications, read access restricted to security/ops roles)
- Define separate retention policies for security audit logs (e.g., 1 year minimum vs. shorter for application debug logs)
- Enable CloudWatch Logs integrity verification or export to an immutable S3 bucket with Object Lock

---

### S-06: Shared Schema Multi-Tenancy Relies Solely on Application-Layer Filtering (Section 3.2)

**Issue**: Tenant data isolation is enforced exclusively by application-layer query filtering on `tenant_id`. A bug in any query, a missing filter in a new endpoint, or a SQL injection vulnerability that bypasses ORM protections would expose cross-tenant data.

**Impact**: Significant — any failure in application-layer filtering (code bug, ORM misconfiguration, injection bypass) results in cross-tenant data leakage, which in a multi-tenant marketplace represents a severe breach for all affected tenants.

**Required Countermeasures**:
- Implement PostgreSQL Row-Level Security (RLS) as a defense-in-depth mechanism to enforce tenant isolation at the database layer, independent of application logic
- Use per-tenant database roles that can only access rows matching their `tenant_id`
- Add automated tests that verify cross-tenant query isolation for all API endpoints

---

## Moderate Issues

### M-01: multer 1.4.4 Known Vulnerabilities (Section 8.2)

**Issue**: The design specifies `multer@1.4.4`, a version with known security vulnerabilities. The dependency security audit cycle is quarterly, meaning known vulnerabilities may remain unpatched for up to three months.

**Impact**: Moderate — depending on the specific CVEs present in this version, exploitation may allow denial of service or other attacks through malformed multipart requests.

**Required Countermeasures**:
- Upgrade `multer` to a patched version immediately
- Reduce the dependency audit cycle from quarterly to continuous (e.g., via Dependabot or Snyk with automated pull requests for security fixes)

---

### M-02: PII Retention Policy Undefined (Section 5.3)

**Issue**: The design explicitly acknowledges that data retention periods and deletion policies are "currently undefined," with withdrawal handling deferred to future design.

**Impact**: Moderate — regulatory non-compliance (GDPR right to erasure, APPI requirements) and operational risk of retaining PII indefinitely without a defined deletion process.

**Required Countermeasures**:
- Define and document PII retention periods before production launch
- Design a user data deletion workflow that covers all storage locations (PostgreSQL, Redis cache, S3, backup snapshots, logs)
- Ensure PII is not present in application logs (already addressed in 5.3) and validate this in CI/CD

---

### M-03: Signed URL Validity Period for Sensitive Documents Too Long (Section 5.4)

**Issue**: Presigned URLs for invoices and contract documents have a 7-day validity period.

**Impact**: Moderate — a leaked or intercepted presigned URL provides unauthorized access to sensitive business documents for up to 7 days without the ability to revoke access.

**Required Countermeasures**:
- Reduce presigned URL validity for sensitive documents to the minimum necessary (e.g., 15–60 minutes for on-demand access)
- Implement access logging on the private S3 bucket to detect anomalous download patterns

---

## Positive Aspects

- HTTPS enforced for all communications including internal CloudFront-to-ECS segment (Section 5.2)
- bcrypt with cost factor 12 for password hashing is appropriate (Section 4.1)
- Refresh token stored in HttpOnly cookie, preventing JavaScript access (Section 4.1)
- Server-side refresh token blacklisting on logout (Section 4.2)
- Parameterized queries via Prisma ORM for SQL injection prevention (Section 6.1)
- Zod schema validation for all request parameters (Section 6.1)
- DOMPurify sanitization for user-generated rich text (Section 6.2)
- CSP policy configured (Section 6.2)
- AWS Secrets Manager for production secret storage is correctly referenced (Section 8.1) — note however that the `secrets.prod.yaml` practice contradicts this
- Credit card data delegated to Stripe with no local storage (Section 5.1)
- Private subnet placement for ECS containers (Section 8.3)
- VPN requirement for management console access (Section 8.3)
- KMS-based key management with annual rotation (Section 5.1)

---

## Summary of Findings by Severity

| ID | Severity | Section | Issue |
|----|----------|---------|-------|
| C-01 | Critical | 5.1 | PII in plaintext; TDE alone is insufficient protection |
| C-02 | Critical | 8.1 | Production secrets committed to repository |
| C-03 | Critical | 4.1 | Access token in localStorage — XSS theft risk |
| C-04 | Critical | 6.4 | CORS regex allows unintended origins with credentials |
| S-01 | Significant | 4.4 | No rate limiting on authentication endpoints |
| S-02 | Significant | 4.2 | Access tokens cannot be immediately revoked |
| S-03 | Significant | 6.5 | File upload MIME validation bypassable; no virus scanning |
| S-04 | Significant | 7.3 | Stripe webhook signature verification not specified |
| S-05 | Significant | 8.4 | Security audit logs mixed with application logs |
| S-06 | Significant | 3.2 | Tenant isolation relies solely on application-layer filtering |
| M-01 | Moderate | 8.2 | multer 1.4.4 has known vulnerabilities |
| M-02 | Moderate | 5.3 | PII retention and deletion policy undefined |
| M-03 | Moderate | 5.4 | 7-day presigned URL validity for sensitive documents |
