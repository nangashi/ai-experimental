# Security Design Review: Nexamart Platform System Design v1.4.0

**Reviewer**: security-design-reviewer (v005-variant-audit-log-gap-first)
**Document**: test-document-2.md (Nexamart Platform)
**Run**: doc2-run2

---

## Critical Issues

### CRIT-01: Production Secrets Stored in Version-Controlled Repository

**Section**: 8.1 Secret Management

**Issue**: The design explicitly states that production secret values are recorded in `config/secrets.prod.yaml` and included in the repository with access restrictions. Storing actual secret values in a repository — regardless of access controls — creates a persistent, unrevocable exposure risk. Once a secret is committed, it remains in git history even after deletion. Any repository breach, misconfigured permission, or accidental exposure (e.g., CI log output) results in immediate credential compromise across all services using those secrets.

**Impact**: Full credential compromise of database passwords, JWT signing keys, and external API keys. An attacker with repository read access gains immediate access to all protected systems without requiring additional exploitation.

**Countermeasures**:
- Remove `config/secrets.prod.yaml` from the repository entirely. If it currently exists, rotate all referenced secrets immediately.
- Reference secrets exclusively through AWS Secrets Manager at runtime. Use IAM role-based access for ECS tasks rather than embedding values.
- Implement pre-commit hooks (e.g., git-secrets, truffleHog) to prevent accidental secret commits.

---

### CRIT-02: Access Token Stored in localStorage — XSS Token Theft Risk

**Section**: 4.1 Authentication Flow

**Issue**: Access tokens (JWTs) are stored in `localStorage`. JavaScript has unrestricted read access to `localStorage`, meaning any XSS vulnerability (including via third-party scripts, CDN compromise, or DOM-based XSS bypassing DOMPurify) allows an attacker to exfiltrate the access token. With a 60-minute validity window and no server-side revocation mechanism for access tokens, a stolen token provides uninterrupted attacker access for the full duration.

**Impact**: Session hijacking for any authenticated user, including `tenant_admin` and `platform_admin` accounts. Combined with the lack of access token revocation (Section 4.2), the attacker retains access even after the legitimate user logs out.

**Countermeasures**:
- Store access tokens in `HttpOnly` cookies (same approach as refresh tokens) to prevent JavaScript access.
- If in-memory storage is preferred (not persisted), implement token refresh from the `HttpOnly` cookie-stored refresh token on page load.
- Add `Secure` and `SameSite=Strict` or `SameSite=Lax` attributes to all authentication cookies.

---

### CRIT-03: No Access Token Revocation on Privilege Change or Security Event

**Section**: 4.2 Session Management

**Issue**: The design states that "immediate invalidation of tokens when unauthorized access or permission changes occur relies on the refresh token expiry." Access tokens have a 60-minute validity and no server-side blocklist. If a `tenant_admin` account is compromised, a role is demoted, or suspicious activity is detected, the attacker continues operating with full access for up to 60 minutes after detection. For a `platform_admin` role with read/write access to all tenants, this represents a critical exposure window.

**Impact**: Inability to immediately terminate attacker sessions. Security incident response is fundamentally impaired; the system cannot enforce "revoke access now" semantics.

**Countermeasures**:
- Implement a server-side access token blocklist (Redis is already available) for security-critical events: detected compromise, role demotion, account suspension.
- Alternatively, reduce access token lifetime significantly (e.g., 5–15 minutes) to limit the exposure window.
- Design a "force logout" administrative capability that invalidates both access and refresh tokens.

---

### CRIT-04: Tenant Isolation Relies Solely on Application-Layer Query Filtering

**Section**: 3.2 Multi-Tenant Isolation

**Issue**: The design uses a shared schema with `tenant_id` column filtering at the application layer as the sole isolation mechanism. This means a single missing or incorrect `WHERE tenant_id = ?` clause in any query results in cross-tenant data exposure. With multiple microservices (order service, product service, tenant management service) all performing independent filtering, the attack surface is broad. There is no mention of Row-Level Security (RLS) at the database layer as a defense-in-depth measure.

**Impact**: Cross-tenant data exposure. A bug in any service handler could expose another tenant's orders, products, customer data, or financial information. In a multi-tenant marketplace, this constitutes a significant breach for all affected tenants.

**Countermeasures**:
- Enable PostgreSQL Row-Level Security (RLS) with a `tenant_id`-based policy as a database-layer enforcement backstop. Application filtering remains, but RLS prevents any query from accessing data outside the current tenant context, even in the event of application bugs.
- Implement integration tests that verify cross-tenant data isolation for all API endpoints handling tenant-scoped resources.

---

### CRIT-05: Stripe Webhook Endpoint Lacks Signature Verification Design

**Section**: 7.3 External Service Integration

**Issue**: The design mentions a Stripe Webhook endpoint at `/api/webhooks/stripe` that receives events and updates payment status, but provides no design specification for verifying the authenticity of incoming webhook requests. Without Stripe signature verification (`Stripe-Signature` header validation using the webhook signing secret), any actor who discovers the endpoint URL can forge payment success events, causing the system to mark unpaid orders as paid.

**Impact**: Financial fraud via forged webhook events. Attackers can trigger order fulfillment without completing payment by sending crafted `payment_intent.succeeded` events to the public endpoint.

**Countermeasures**:
- Explicitly design Stripe webhook signature verification using the `stripe.webhooks.constructEvent()` method with the webhook signing secret.
- Store the webhook signing secret in AWS Secrets Manager (consistent with Section 8.1 intent).
- Return HTTP 400 for any webhook request that fails signature validation before processing any business logic.

---

## Significant Issues

### SIG-01: Audit Log Gap — Authentication Failures Not Recorded as Structured Security Events

**Section**: 8.4 Audit Log / 9.4 Security Requirements

**Evaluation order per Section 5 criteria — Presence/absence check first:**

The design references authentication failure logging in Section 9.4 ("record important events such as authentication failures and permission changes in application logs") and Section 8.4 states recording follows "Section 7.4" (a non-existent section reference). Neither section specifies:
- Which system records authentication failures (authentication service vs. core API service)
- What fields are captured (timestamp, source IP, user identifier, failure reason, tenant context)
- Whether this constitutes a security audit event distinct from general application logging

**Quality evaluation**: Section 8.4 confirms audit logs are output to the same CloudWatch Logs stream as general application logs ("output to the same CloudWatch Logs stream as normal application logs"). This means security-relevant authentication failure events are not distinguishable from general application noise, preventing effective security monitoring and alerting.

**Impact**: Authentication failures cannot be monitored for brute-force attack patterns. SIEM integration is not feasible without structured, separated audit logs. The reference to "Section 7.4" is a documentation error that leaves the actual implementation undefined.

**Countermeasures**:
- Define authentication failure logging as an explicit requirement: structured JSON log entries with timestamp, event_type, source_IP, user_identifier (not PII), tenant_id, failure_reason.
- Output security audit events to a dedicated CloudWatch Logs stream separate from application logs.
- Configure CloudWatch Metric Filters and alarms for authentication failure rate thresholds (e.g., >10 failures per user per 5 minutes).

---

### SIG-02: Audit Log Gap — Role/Permission Changes Not Recorded as Independent Security Events

**Section**: 8.4 Audit Log / 9.4 Security Requirements

**Evaluation order per Section 5 criteria — Presence/absence check first:**

Section 9.4 mentions "permission changes" in a general statement, but Section 8.4 (the actual audit log design) does not list role or permission change events in the enumerated audit log entries. The four listed events (tenant registration/suspension, product visibility changes, order status changes, user data exports) do not include role assignment or modification events.

**Quality evaluation**: The absence of role change audit logging is particularly severe for a system with a `platform_admin` role that has global read/write access to all tenants. Unauthorized escalation to `platform_admin` would be undetectable without audit records.

**Impact**: Privilege escalation attacks and insider threats involving role manipulation cannot be detected or investigated forensically. Compliance with SOC 2, ISO 27001, and similar frameworks requiring access change audit trails cannot be demonstrated.

**Countermeasures**:
- Add explicit audit log entries for: role assignment, role modification, role revocation, and permission grant/revoke events.
- Include: actor identity, target user, previous role, new role, timestamp, tenant context.
- Ensure these entries go to a dedicated security audit log stream, not the general application log.

---

### SIG-03: Audit Log Gap — Sensitive Data Access Not Recorded

**Section**: 8.4 Audit Log

**Evaluation order per Section 5 criteria — Presence/absence check first:**

Section 8.4 lists "tenant administrator user data export" as an audited event, but does not specify logging for direct sensitive data access events such as: `platform_admin` bulk data access, API-level queries returning PII (customer lists, order details with shipping addresses), or programmatic data access by tenant staff. Individual record-level access to sensitive data is not covered.

**Quality evaluation**: Logging only data exports while omitting API-level sensitive data access creates a gap in data access audit coverage. A malicious insider using normal API calls to exfiltrate customer data one page at a time would leave no audit trail.

**Impact**: Data exfiltration through legitimate API access is undetectable. For a multi-tenant marketplace handling customer PII (name, address, phone number), this represents a significant privacy risk and regulatory exposure.

**Countermeasures**:
- Define and log access to sensitive data endpoints: customer PII retrieval, order history with personal details, bulk data queries by tenant administrators.
- Implement access volume anomaly detection: alert on unusually large query result sets or high-frequency PII access from a single actor.

---

### SIG-04: No Rate Limiting Designed for Authentication Endpoints

**Section**: 4.4 Authentication Endpoints

**Issue**: The design specifies no rate limiting for `/api/auth/login`, `/api/auth/register`, or `/api/auth/refresh` endpoints. The Kong API gateway is mentioned for token validation and routing, but no rate limiting configuration is described. Without rate limiting on the login endpoint, credential stuffing and brute-force attacks are viable. Without rate limiting on the register endpoint, account creation abuse (spam/bot accounts) is possible. Without rate limiting on the refresh endpoint, token refresh abuse can be used to maintain persistent sessions beyond intended limits.

**Impact**: Brute-force attacks against user credentials. Credential stuffing using leaked password lists. Account enumeration via registration endpoint error responses.

**Countermeasures**:
- Design explicit rate limiting for all authentication endpoints, applied at Kong gateway level:
  - `/api/auth/login`: Maximum 10 attempts per IP per 15 minutes, with exponential backoff.
  - `/api/auth/register`: Maximum 5 registrations per IP per hour.
  - `/api/auth/refresh`: Maximum 60 refreshes per token per hour.
- Implement account-level lockout after repeated failures (e.g., 10 consecutive failures triggers 30-minute lockout with notification email).
- Design account enumeration protection: return identical error messages for non-existent accounts and wrong passwords.

---

### SIG-05: CORS Wildcard Subdomain with Credentials Allows Subdomain Takeover Escalation

**Section**: 6.4 CORS Configuration

**Issue**: The CORS policy allows any `*.nexamart.com` subdomain with `Access-Control-Allow-Credentials: true`. If any subdomain can be registered or taken over by an attacker (e.g., through expired tenant slugs that haven't been reclaimed, DNS misconfiguration, or dangling DNS records), that subdomain becomes a valid CORS origin able to make credentialed cross-origin requests to the API. The regex `/\.nexamart\.com$/` also matches constructed strings if validation is not correctly anchored, potentially allowing bypass via hostnames like `evil.nexamart.com.attacker.com` depending on implementation.

**Impact**: A compromised or attacker-controlled `*.nexamart.com` subdomain can make authenticated API requests on behalf of logged-in users, effectively bypassing same-origin protection.

**Countermeasures**:
- Maintain an explicit allowlist of valid tenant subdomains rather than a regex wildcard. Validate the `Origin` header against this allowlist before reflecting it.
- Implement subdomain reclamation policies: when a tenant is suspended/deregistered, the subdomain must be explicitly decommissioned and not made available for reuse.
- Ensure the regex is anchored at the start: `/^https:\/\/[a-z0-9-]+\.nexamart\.com$/` to prevent suffix-match bypass.

---

### SIG-06: CSRF Protection Relies Solely on JWT in Authorization Header — Single Layer

**Section**: 6.3 CSRF Protection

**Issue**: The design asserts that requiring JWT in the `Authorization` header is sufficient CSRF protection. However, the access token is stored in `localStorage` (Section 4.1), where JavaScript can read and attach it to requests. This means the CSRF protection mechanism depends entirely on XSS not occurring. The design does not implement any additional CSRF countermeasure (SameSite cookie attributes, CSRF tokens). Per the Defense Layer Separation reporting rule, the absence of a second layer must be reported as an independent finding.

**Impact**: If XSS occurs (even via a third-party script injection not caught by DOMPurify), the attacker can read the `localStorage` token and forge cross-origin requests with valid authentication. The CSRF defense collapses simultaneously with the XSS defense — two distinct attack vectors share a single point of failure.

**Countermeasures**:
- Add `SameSite=Strict` or `SameSite=Lax` to all cookies, including the `HttpOnly` refresh token cookie, as an independent CSRF layer.
- If access tokens are migrated to `HttpOnly` cookies (recommended per CRIT-02), implement CSRF tokens or the Double Submit Cookie pattern for state-changing API requests.
- Do not rely on a single mechanism for CSRF protection in a credentialed-request environment.

---

## Moderate Issues

### MOD-01: File Upload — MIME Type Validation Based on Content-Type Header Only

**Section**: 6.5 File Upload

**Issue**: File type validation for uploads relies solely on the `Content-Type` request header. This header is attacker-controlled and trivially spoofable: an attacker can upload a PHP shell, JavaScript file, or SVG with embedded scripts by setting `Content-Type: image/jpeg`. The design explicitly notes "no extension validation" and "no virus scanning."

**Impact**: Upload of malicious files disguised as images. If served from a non-isolated domain or if CloudFront serves SVG files with incorrect content-type headers, XSS via uploaded content is possible. Stored malware distribution via the platform.

**Countermeasures**:
- Implement server-side magic byte validation (file signature inspection) independent of the `Content-Type` header.
- Validate file extensions against an allowlist in addition to MIME type checks.
- For images, transcode uploaded files through an image processing pipeline (e.g., Sharp) which strips metadata and confirms valid image format.
- Serve user-uploaded content from an isolated domain (e.g., `static.nexamart.com`) separate from the application domain to prevent cookie-based attacks on uploaded content.
- Prioritize virus scanning implementation (currently deferred).

---

### MOD-02: PII Retention Period and Deletion Policy Undefined

**Section**: 5.3 PII Management

**Issue**: The design explicitly states that data retention periods and deletion policies are "currently undefined" and that the withdrawal request handling flow "will be designed in the future." For a marketplace collecting name, email address, postal address, and phone number, operating without a defined retention and deletion policy violates GDPR Article 5(1)(e) (storage limitation) and equivalent regulations.

**Impact**: Regulatory non-compliance risk. Inability to fulfill user deletion requests (GDPR right to erasure). Accumulation of stale PII increases breach impact scope.

**Countermeasures**:
- Define retention periods before launch: minimum necessary retention for legal/accounting requirements (typically 5–7 years for transaction records, shorter for inactive account PII).
- Design explicit account deletion flow: anonymize or delete PII while retaining transaction records in anonymized form for legal compliance.
- Document the legal basis for PII retention under applicable regulation (GDPR, APPI, etc.).

---

### MOD-03: Signed URL Expiry for Sensitive Documents Is 7 Days — Excessively Long

**Section**: 5.4 S3 Storage Security

**Issue**: Presigned URLs for invoices and contract documents have a 7-day validity period. If a presigned URL is shared, logged in application logs, captured in browser history, or exfiltrated from email, the attacker has a 7-day window to access sensitive documents without authentication.

**Impact**: Unauthorized access to financial and legal documents through URL leakage. Documents may be forwarded outside the intended recipient's control while remaining accessible.

**Countermeasures**:
- Reduce presigned URL expiry to the minimum practical duration: 1 hour or less for on-demand access, 15 minutes for download operations.
- Implement server-side URL generation that validates the requesting user's authorization at generation time, not just at the URL request time.
- Consider generating URLs per-request (each page load generates a fresh short-lived URL) rather than caching long-lived URLs.

---

### MOD-04: multer 1.4.4 — Known Vulnerable Version

**Section**: 8.2 Dependency Management

**Issue**: The design specifies `multer@1.4.4` for multipart form processing. This version has known vulnerabilities. The quarterly security update cycle means vulnerabilities may remain unpatched for up to three months after discovery. Given that file upload handling is a high-risk attack surface, using a version with known issues is particularly concerning.

**Impact**: Exploitation of known multer vulnerabilities, potentially including DoS via malformed multipart requests or path traversal in file handling.

**Countermeasures**:
- Update to the latest stable multer version immediately, or evaluate replacement with an alternative library.
- Reduce the quarterly update cycle to monthly for security-critical dependencies.
- Implement automated vulnerability scanning (e.g., `npm audit`, Dependabot, Snyk) as part of the CI/CD pipeline to detect new CVEs before the next scheduled review.

---

### MOD-05: Internal Service Communication Encryption Not Explicitly Specified

**Section**: 5.2 Transfer Protection / 3.1 Architecture

**Issue**: The design specifies HTTPS/TLS for external communication and CloudFront-to-ECS encryption, but does not address encryption for inter-service communication within the ECS cluster: authentication service to core API, core API to order/product/tenant management services, and all services to SQS. While Security Groups provide network-layer access control, they do not encrypt traffic. Data traversing unencrypted internal paths remains vulnerable to internal network compromise or misconfigured routing.

**Impact**: Internal network interception could expose authentication tokens, customer PII, and order data in transit between microservices.

**Countermeasures**:
- Explicitly specify mTLS for inter-service communication using AWS App Mesh or service mesh equivalent.
- At minimum, specify TLS for all service-to-service HTTP connections within the ECS cluster.
- Ensure SQS message payloads containing sensitive data are encrypted (SQS SSE or application-level encryption).

---

### MOD-06: Order Access Authorization — Buyer Can Access Any Order by ID

**Section**: 7.2 Order API

**Issue**: `GET /api/orders/:id` allows `buyer` role access, but the design does not specify that ownership verification is performed (i.e., that the requesting buyer's user ID matches the order's buyer). If the API returns order details for any order ID presented by an authenticated buyer, an attacker can enumerate order IDs to access other users' order details (which include PII: name, address, items ordered).

**Impact**: Horizontal privilege escalation. Buyers can access other buyers' order details by guessing or enumerating order IDs. This exposes PII and purchase history for all customers.

**Countermeasures**:
- Explicitly specify in the API design that `GET /api/orders/:id` for the `buyer` role must verify `order.buyer_id == authenticated_user_id` before returning data.
- Use non-sequential, non-guessable order IDs (UUID v4) to reduce enumeration risk even if the ownership check is omitted.
- Add this check to the API authorization checklist in Section 4.3.

---

## Minor Issues and Positive Observations

### MIN-01: KMS Key Rotation Cycle Is Annual — Consider Semi-Annual

**Section**: 5.1 Data Encryption at Rest

**Issue**: AWS KMS key rotation is set to annual. While annual rotation is a common baseline, for a platform handling payment-adjacent data and multi-tenant PII, semi-annual or quarterly rotation provides a shorter window of exposure if a key is compromised.

**Recommendation**: Evaluate reducing KMS rotation to every 90 days for sensitive data keys, or implement automatic key rotation policies aligned with sensitivity classification.

---

### MIN-02: ECS Task Definition May Over-Expose Secrets to All Containers

**Section**: 8.1 Secret Management

**Issue**: The design states secrets are injected as environment variables into ECS task definitions, but does not specify that each service only receives the secrets it requires. If all services in a task definition receive all secrets, a compromise of one service exposes credentials for all services.

**Recommendation**: Apply least-privilege secret injection: each microservice ECS task definition should only include the specific secrets required for that service's operation.

---

### Positive Observations

- **bcrypt cost factor 12**: Appropriate for current hardware. Well chosen.
- **Refresh token in HttpOnly cookie**: Correct placement for refresh tokens, though access token storage in localStorage needs correction (CRIT-02).
- **Stripe delegation for card data**: Correct design decision eliminating PCI DSS scope for card storage.
- **Prisma ORM with parameterized queries**: Effective SQL injection prevention.
- **DOMPurify for rich text**: Appropriate sanitization approach for user-generated content.
- **CSP default-src 'self'**: Good baseline CSP, though additional directives may be needed for CDN resources.
- **Private subnet for ECS containers**: Correct network architecture.
- **VPN requirement for admin console**: Appropriate access control for administrative functions.
- **Zod schema validation**: Server-side input validation on all requests is a good security baseline.

---

## Summary

| Severity | Count | Key Issues |
|----------|-------|------------|
| Critical | 5 | Secrets in repository, localStorage token storage, no token revocation, tenant isolation gaps, Stripe webhook forgery |
| Significant | 6 | 3 audit log gaps (auth failures, role changes, sensitive data access), no auth rate limiting, CORS subdomain risk, single-layer CSRF |
| Moderate | 6 | File upload validation, PII retention undefined, long-lived presigned URLs, vulnerable multer version, internal encryption gap, order ownership check |
| Minor | 2 | KMS rotation cycle, ECS secret scoping |

The most urgent issues requiring immediate design revision are CRIT-01 (repository secrets), CRIT-02 (localStorage token storage), and the three audit log gaps (SIG-01, SIG-02, SIG-03) which represent both security monitoring failures and likely compliance violations.
