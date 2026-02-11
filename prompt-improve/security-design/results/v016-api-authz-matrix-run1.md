# Security Design Review: SalesPulse CRM Platform

**Review Date**: 2026-02-10
**Reviewer**: Security Design Reviewer (v016-api-authz-matrix)
**Document**: test-document-round-016.md

---

## Executive Summary

The SalesPulse CRM design document contains **multiple critical security vulnerabilities** that require immediate attention before production deployment. The most severe issues include insecure JWT token storage in localStorage (XSS attack vector), complete absence of API endpoint authorization controls, publicly readable S3 files, unencrypted OAuth tokens, and missing rate limiting. The design demonstrates basic awareness of some security practices (HTTPS, bcrypt) but lacks systematic security architecture across authentication, authorization, data protection, and infrastructure layers.

**Overall Security Posture**: High Risk
**Recommended Action**: Address all critical issues before production deployment

---

## Security Evaluation Scores

| Criterion | Score | Severity |
|-----------|-------|----------|
| Threat Modeling (STRIDE) | 2 | Significant |
| Authentication & Authorization Design | 1 | **Critical** |
| Data Protection | 1 | **Critical** |
| Input Validation Design | 2 | Significant |
| Infrastructure & Dependency Security | 2 | Significant |

**Overall Score: 1.6 / 5.0** (Critical issues present)

---

## Critical Issues (Score 1-2)

### 1. Insecure JWT Token Storage in localStorage

**Severity**: CRITICAL (Score: 1)
**STRIDE**: Spoofing, Information Disclosure, Elevation of Privilege

**Issue**: The design explicitly specifies storing JWT tokens in browser localStorage (Section 5, line 168):
> "**Token Storage**: Stored in browser localStorage"

**Impact**:
- Any XSS vulnerability (malicious script injection) can steal tokens from localStorage
- Stolen tokens provide complete account takeover for 24 hours (token expiration period)
- Attacker gains full tenant access, can read/modify all CRM data
- Multi-tenant architecture means a single XSS could potentially pivot across tenants if token validation is weak

**Why This Is Dangerous**:
localStorage is accessible to any JavaScript executing in the same origin. React's XSS protection (mentioned in Section 7) is not foolproof—third-party libraries, CDN compromises, or developer errors can introduce XSS vectors. The 24-hour token lifetime amplifies the attack window.

**Recommendation**:
1. **Immediately change token storage to httpOnly + Secure cookies**:
   - Set `HttpOnly` flag (prevents JavaScript access)
   - Set `Secure` flag (HTTPS-only transmission)
   - Set `SameSite=Strict` or `SameSite=Lax` (CSRF mitigation)
   - Store in domain-scoped cookie (not subdomain-accessible for tenant isolation)

2. **Reduce token expiration from 24 hours to 15 minutes** with refresh token rotation:
   - Short-lived access token (15 min) in httpOnly cookie
   - Long-lived refresh token (7 days) in separate httpOnly cookie
   - Refresh endpoint with rotation to detect token theft

3. **Implement token binding** (optional but recommended):
   - Bind tokens to IP address or device fingerprint
   - Detect suspicious token usage patterns

**References**:
- OWASP Authentication Cheat Sheet: httpOnly cookies for session tokens
- Section 5: "Token Storage: Stored in browser localStorage"

---

### 2. Complete Absence of API Endpoint Authorization

**Severity**: CRITICAL (Score: 1)
**STRIDE**: Elevation of Privilege, Information Disclosure, Tampering

**Issue**: The design document specifies **zero authorization checks** for API endpoints. The following critical gaps are present:

#### API Endpoint Authorization Matrix

| Endpoint | HTTP Method | Resource Type | Authorization Check | Status | Risk | Recommendation |
|----------|-------------|---------------|---------------------|--------|------|----------------|
| `PUT /api/deals/:id` | PUT | Deal | **None specified** | **Missing** | **Critical** | Require ownership verification: `deal.owner_id === req.user.id OR req.user.role === 'admin'` |
| `DELETE /api/deals/:id` | DELETE | Deal | **None specified** (explicitly states "No ownership verification") | **Missing** | **Critical** | Require ownership verification: `deal.owner_id === req.user.id OR req.user.role === 'admin'` |
| `POST /api/contacts` | POST | Contact | **None specified** | **Missing** | **Critical** | Verify `company_id` exists and belongs to tenant, validate owner assignment |
| `GET /api/contacts` | GET | Contact | Tenant-scoped only | **Partial** | **High** | Add role-based filtering: users should only see contacts they own or are assigned to their team (unless admin/manager) |
| `POST /api/webhooks` | POST | Webhook | **None specified** | **Missing** | **Critical** | Require admin role: `req.user.role === 'admin'` |
| `POST /api/files/upload` | POST | File | **None specified** | **Missing** | **Critical** | Verify user is authenticated, enforce tenant isolation, validate file associations |
| `POST /api/integrations/email/connect` | POST | Email Credentials | **None specified** | **Missing** | **Critical** | Verify OAuth code belongs to requesting user, validate state parameter (CSRF protection) |
| `POST /api/auth/password-reset` | POST | Password Reset | **None specified** | **Unspecified** | **High** | Implement rate limiting (5 requests/hour per IP), CAPTCHA after 3 attempts, email enumeration protection |

**Impact**:
- **Horizontal privilege escalation**: Any user can modify/delete deals owned by other users in the same tenant (Section 5, lines 219-223 explicitly state "No ownership verification")
- **Vertical privilege escalation**: Regular users can register webhooks (should be admin-only), exposing sensitive tenant data
- **Data exfiltration**: Lack of fine-grained access control on GET endpoints allows users to access data outside their authorization scope
- **Webhook abuse**: Attackers can register webhooks to external servers, receiving real-time CRM data updates

**Why This Is Dangerous**:
The design relies solely on tenant-level isolation (Section 3, line 74) without user-level or role-based authorization. In a CRM with 5-200 users per tenant, this means **any sales representative can delete their manager's deals**, view competing team members' pipelines, or export the entire customer database.

**Recommendations**:
1. **Implement Resource Ownership Verification**:
   ```typescript
   // Example for PUT /api/deals/:id
   const deal = await dealRepository.findById(dealId, tenantId);
   if (deal.owner_id !== req.user.id && req.user.role !== 'admin') {
     throw new ForbiddenError('You do not own this deal');
   }
   ```

2. **Implement Role-Based Access Control (RBAC)**:
   - Define permission matrix: admin (full access), manager (read all + modify own team), user (read/modify own records)
   - Create middleware: `requireRole(['admin'])`, `requireOwnership(resource)`
   - Apply to all state-changing endpoints

3. **Add Cross-Resource Authorization**:
   - When creating contacts with `company_id`, verify company exists and belongs to tenant
   - When linking deals to contacts, verify contact ownership/visibility

4. **Implement Admin-Only Endpoints**:
   - `/api/webhooks/*` should require admin role
   - `/api/integrations/*` configuration endpoints should require admin role

**References**:
- Section 5: "PUT /api/deals/:id - No ownership verification - any user in the tenant can update any deal" (line 220)
- Section 5: "DELETE /api/deals/:id - No ownership verification - any user in the tenant can delete any deal" (line 223)
- Section 3: Target users include sales representatives and managers with different authorization needs (lines 22-24)

---

### 3. Public-Read S3 Files with No Access Control

**Severity**: CRITICAL (Score: 1)
**STRIDE**: Information Disclosure

**Issue**: Files uploaded to S3 are stored with **public-read ACL** (Section 5, line 236):
> "Files stored in S3 with public-read ACL"

**Impact**:
- **Anyone on the internet can access uploaded files** if they know/guess the S3 URL
- CRM files may contain sensitive customer data: contracts, proposals, financial documents, PII
- No authentication required to download files
- No audit trail of who accessed files externally
- Potential GDPR/compliance violations (unauthorized data exposure)

**Why This Is Dangerous**:
S3 object keys are often predictable (tenant-prefixed UUIDs). Attackers can:
1. Enumerate uploaded files by guessing UUIDs or scraping references
2. Access files directly via S3 URLs without authenticating to the API
3. Download entire tenant file repositories

**Recommendations**:
1. **Remove public-read ACL immediately**:
   - Store files with **private ACL** (default secure)
   - Never expose direct S3 URLs to clients

2. **Implement Pre-Signed URL Generation**:
   ```typescript
   // API endpoint: GET /api/files/:fileId/download
   // Generate time-limited pre-signed URL (expires in 5 minutes)
   const presignedUrl = s3.getSignedUrl('getObject', {
     Bucket: 'salespulse-files',
     Key: fileKey,
     Expires: 300 // 5 minutes
   });
   ```

3. **Add Authorization Checks Before Generating URLs**:
   - Verify user has access to the resource (deal, contact) the file is attached to
   - Check ownership or role-based permissions
   - Log all file access requests for audit

4. **Implement S3 Bucket Policies**:
   - Deny all public access at bucket level
   - Require VPC endpoint access or IAM role authentication
   - Enable S3 access logging

**References**:
- Section 5: "POST /api/files/upload - Files stored in S3 with public-read ACL" (line 236)
- Section 2: S3 used for "document attachments, profile images" (line 44)

---

### 4. Unencrypted OAuth Tokens in Database

**Severity**: CRITICAL (Score: 1)
**STRIDE**: Information Disclosure

**Issue**: Email OAuth tokens (Gmail, Outlook) are stored in database without encryption (Section 4, lines 140-146):
```sql
email_credentials
- access_token (TEXT)
- refresh_token (TEXT)
```

No encryption specification provided. Section 7 mentions general security but doesn't address data-at-rest encryption for sensitive credentials.

**Impact**:
- **Database compromise = complete email account takeover** for all users
- Attackers can read all user emails, send emails as users, access corporate email systems
- Refresh tokens often have long lifetimes (months to years)
- Lateral movement to other corporate systems via compromised email accounts
- Potential access to sensitive business communications, trade secrets, customer data

**Why This Is Dangerous**:
OAuth tokens are bearer tokens—possession equals access. Storing them in plaintext means:
1. Database backups contain plaintext tokens (Section 7: "Daily automated snapshots")
2. DBAs or compromised admin accounts can steal tokens
3. SQL injection vulnerabilities could leak tokens (even with parameterized queries, logic bugs exist)
4. Log files might accidentally expose tokens

**Recommendations**:
1. **Implement Application-Level Encryption for Tokens**:
   ```typescript
   import { encrypt, decrypt } from './encryption-service';

   // Before storage
   const encryptedToken = encrypt(accessToken, tenantEncryptionKey);

   // After retrieval
   const accessToken = decrypt(encryptedToken, tenantEncryptionKey);
   ```

2. **Use AWS KMS for Encryption Key Management**:
   - Generate per-tenant data encryption keys (DEKs) using AWS KMS
   - Store encrypted DEKs in database, decrypt using KMS master key when needed
   - Enable automatic key rotation

3. **Implement Token Encryption at Rest in PostgreSQL**:
   - Use PostgreSQL's `pgcrypto` extension for transparent column encryption
   - Or implement application-layer encryption before INSERT/UPDATE

4. **Additional Controls**:
   - Enable PostgreSQL Transparent Data Encryption (TDE) for defense-in-depth
   - Restrict database access to application service accounts only
   - Enable audit logging for all access to `email_credentials` table
   - Implement token refresh rotation to limit lifetime exposure

**References**:
- Section 4: `email_credentials` table schema (lines 140-146)
- Section 3: Email Integration Service stores credentials (lines 98-99)
- Section 7: No encryption-at-rest specification for sensitive data

---

## Significant Issues (Score 2)

### 5. Missing Rate Limiting and Brute-Force Protection

**Severity**: SIGNIFICANT (Score: 2)
**STRIDE**: Denial of Service, Spoofing

**Issue**: No rate limiting specified for authentication endpoints or API access. The design mentions Redis for "rate limiting" (Section 2, line 42) but provides **zero implementation details**:
- No rate limits defined for `/api/auth/login`
- No rate limits for `/api/auth/password-reset`
- No API-wide rate limiting strategy
- No account lockout policy after failed attempts

**Impact**:
- **Brute-force password attacks** on login endpoint
- **Credential stuffing attacks** using leaked credential databases
- **Account enumeration** via password reset endpoint timing differences
- **API abuse** leading to resource exhaustion (10,000 concurrent users target means abuse can cause outages)
- **Webhook spam** if attackers can register unlimited webhooks

**Recommendations**:
1. **Implement Authentication Rate Limiting**:
   - Login: 5 attempts per IP per 15 minutes
   - Login: 10 attempts per email per hour (account-level)
   - Password reset: 3 requests per IP per hour
   - Password reset: 5 requests per email per day

2. **Implement API-Wide Rate Limiting**:
   - Per user: 1000 requests/hour (normal users)
   - Per user: 5000 requests/hour (API integrations)
   - Per IP: 10000 requests/hour (prevent distributed abuse)
   - Use Redis with sliding window algorithm

3. **Add Progressive Delays**:
   - 2-second delay after 3 failed login attempts
   - 10-second delay after 5 failed attempts
   - CAPTCHA requirement after 5 attempts

4. **Implement Account Lockout**:
   - Temporary lockout (15 minutes) after 10 failed attempts
   - Require email verification to unlock
   - Alert user via email of suspicious activity

**References**:
- Section 2: Redis mentioned for "rate limiting" but no details (line 42)
- Section 5: No rate limiting on authentication endpoints (lines 172-200)
- Section 7: No rate limiting in Non-functional Requirements

---

### 6. Missing CSRF Protection for State-Changing Operations

**Severity**: SIGNIFICANT (Score: 2)
**STRIDE**: Tampering, Elevation of Privilege

**Issue**: No CSRF protection mechanism specified for POST/PUT/DELETE endpoints. The design uses JWT in Authorization header (Section 5, line 167), but **no explicit CSRF token implementation**:
- No SameSite cookie attributes mentioned (if cookies were used)
- No anti-CSRF token generation/validation
- No Origin/Referer header validation

**Current Risk with localStorage Tokens**: Medium (Authorization header not sent automatically by browser)
**Future Risk if Migrating to Cookies**: High (cookies sent automatically, vulnerable to CSRF)

**Impact**:
- If design migrates to cookies (recommended for XSS protection), without CSRF protection:
  - Attacker website can trigger authenticated requests (create/update/delete deals, contacts)
  - User clicking malicious link while logged in triggers unwanted actions
  - Webhook registration to attacker-controlled servers
  - Email integration connection hijacking

**Recommendations**:
1. **When Migrating to httpOnly Cookies** (as recommended in Issue #1):
   - Set `SameSite=Strict` or `SameSite=Lax` on all cookies
   - `SameSite=Strict`: Most secure, blocks cross-site requests entirely
   - `SameSite=Lax`: Allows top-level navigation (GET), blocks forms/AJAX

2. **Implement Double-Submit Cookie Pattern** (defense-in-depth):
   ```typescript
   // Set CSRF token cookie (not httpOnly, readable by JS)
   res.cookie('XSRF-TOKEN', csrfToken, { sameSite: 'strict' });

   // Client sends token in header
   // X-XSRF-TOKEN: <token>

   // Server validates match
   if (req.cookies['XSRF-TOKEN'] !== req.headers['x-xsrf-token']) {
     throw new ForbiddenError('CSRF token mismatch');
   }
   ```

3. **Validate Origin and Referer Headers**:
   - Whitelist allowed origins (https://app.salespulse.com, subdomain patterns)
   - Reject requests with missing or mismatched Origin/Referer

4. **Current Mitigation** (with localStorage):
   - Document that CSRF protection is partially provided by Authorization header (not sent automatically)
   - Warn developers not to fall back to cookie-based auth without CSRF tokens

**References**:
- Section 5: JWT in Authorization header, no CSRF discussion (line 167)
- Section 5: Multiple state-changing endpoints (POST/PUT/DELETE) without protection

---

### 7. Insufficient Input Validation Policy

**Severity**: SIGNIFICANT (Score: 2)
**STRIDE**: Injection, Denial of Service

**Issue**: Minimal input validation specifications. The design mentions:
- SQL injection prevention via parameterized queries (Section 7, line 282) ✓
- XSS prevention via React escaping (Section 7, line 283) ✓
- File upload limits: 10MB/file, 50MB/request (Section 3, line 96) ✓

**Missing**:
- Email format validation (multiple email fields in API)
- Phone number format validation
- URL validation for webhook endpoints (no whitelist/blacklist)
- JSONB custom_fields validation (arbitrary JSON accepted?)
- File type validation (what file types are allowed?)
- Content validation for uploaded files (virus scanning?)
- String length limits (deal name, contact name, etc.)
- Numeric range validation (deal amount, pagination limits)
- HTML sanitization policy (if any user-provided HTML is rendered)

**Impact**:
- **Webhook SSRF attacks**: Attacker registers webhook pointing to internal services (AWS metadata endpoint, internal databases)
- **File upload abuse**: Upload of malware, phishing pages, illegal content
- **Database bloat**: Unlimited string lengths or JSONB sizes consume storage
- **Second-order XSS**: Malicious content stored in custom_fields, rendered later without proper escaping
- **ReDoS attacks**: Malicious regex patterns in search queries

**Recommendations**:
1. **Define Comprehensive Input Validation Policy**:
   - Email: RFC 5322 format, max 254 characters
   - Phone: E.164 format or regional validation, max 20 characters
   - URLs: HTTPS-only, whitelist domains (no internal IPs, no localhost, no metadata endpoints)
   - JSONB custom_fields: Max 10KB size, max 50 keys, key length < 100 chars
   - File uploads: Whitelist extensions (.pdf, .docx, .xlsx, .png, .jpg), MIME type validation

2. **Implement Webhook URL Validation**:
   ```typescript
   // Blacklist dangerous URLs
   const blockedPatterns = [
     /^https?:\/\/169\.254\.169\.254/, // AWS metadata
     /^https?:\/\/(localhost|127\.0\.0\.1)/, // localhost
     /^https?:\/\/192\.168\./, // private networks
     /^https?:\/\/10\./, // private networks
   ];

   for (const pattern of blockedPatterns) {
     if (pattern.test(webhookUrl)) {
       throw new ValidationError('Invalid webhook URL');
     }
   }
   ```

3. **Add File Content Validation**:
   - Integrate with AWS Macie or ClamAV for virus scanning
   - Validate file headers match declared MIME type (detect disguised files)
   - Strip EXIF metadata from images (privacy protection)

4. **Implement String Length Limits**:
   - Deal name: 200 chars, Contact name: 100 chars
   - Email: 254 chars, Phone: 20 chars
   - Reject requests exceeding limits at application layer

5. **Add Output Encoding Policy**:
   - Document that all user-provided content must be escaped when rendered
   - Define Content Security Policy (CSP) headers to mitigate XSS

**References**:
- Section 5: API endpoints lack input validation details (lines 170-246)
- Section 3: File upload limits but no type validation (line 96)
- Section 4: JSONB custom_fields with no constraints (line 124)
- Section 5: Webhook URL with no validation (line 229)

---

### 8. Missing Audit Logging for Sensitive Operations

**Severity**: SIGNIFICANT (Score: 2)
**STRIDE**: Repudiation

**Issue**: Logging specification is insufficient for security and compliance (Section 6, lines 255-259):
> "User actions logged with user ID and tenant ID"

**Missing Details**:
- **What user actions are logged?** (login, data access, modifications, deletions, admin actions?)
- **PII masking policy**: Are passwords, tokens, email content logged? (Privacy risk)
- **Log retention period**: How long are logs kept? (SOC 2/GDPR requirement)
- **Log integrity protection**: Can logs be tampered with? (Repudiation risk)
- **Security event logging**: Failed logins, authorization failures, suspicious patterns
- **Data export/deletion logging**: GDPR requires audit trail of data access/deletion

**Impact**:
- **Insufficient forensic evidence** after security incidents
- **SOC 2 audit failure**: Design mentions "SOC 2: Audit logging for all data access" (Section 7, line 299) but doesn't specify implementation
- **Compliance violations**: GDPR Article 30 requires logging of data processing activities
- **No detection of insider threats**: Can't identify users abusing access
- **Repudiation attacks**: Users can deny actions (no non-repudiation)

**Recommendations**:
1. **Define Security Audit Events to Log**:
   - Authentication: login (success/failure), logout, password reset, token refresh
   - Authorization: permission denied, role changes, admin actions
   - Data Access: view PII (contact details, deals > $100K), data export
   - Data Modification: create/update/delete contacts, deals, webhooks
   - Configuration: webhook registration, email integration, user provisioning
   - Security Events: rate limit exceeded, validation failures, suspicious patterns

2. **Implement PII Masking in Logs**:
   ```typescript
   // Example log entry
   logger.info('User updated contact', {
     userId: req.user.id,
     tenantId: req.user.tenantId,
     contactId: contact.id,
     email: maskEmail(contact.email), // john***@example.com
     action: 'contact.update',
     timestamp: new Date().toISOString(),
     ipAddress: req.ip,
     userAgent: req.headers['user-agent']
   });
   ```

3. **Define Log Retention Policy**:
   - Security logs: 1 year retention (SOC 2 requirement)
   - General logs: 90 days retention
   - Archive to S3 Glacier for long-term storage (7 years for compliance)

4. **Implement Log Integrity Protection**:
   - Send logs to immutable storage (AWS CloudWatch Logs with log retention policies)
   - Use AWS CloudTrail for infrastructure access logs
   - Sign log entries with HMAC for tamper detection (optional)

5. **Enable Real-Time Security Monitoring**:
   - Alert on: 10+ failed logins in 5 minutes, admin actions, webhook registrations, large data exports
   - Integrate with DataDog or AWS GuardDuty for anomaly detection

**References**:
- Section 6: "User actions logged with user ID and tenant ID" (line 259) - insufficient detail
- Section 7: "SOC 2: Audit logging for all data access" (line 299) - no implementation specified
- Section 7: GDPR compliance required (line 298) but no GDPR-specific logging

---

## Infrastructure Security Assessment

### Infrastructure Component Security Matrix

| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| **PostgreSQL 15** | Access Control | Unspecified | **Critical** | Implement least-privilege IAM roles, restrict to VPC, no public access, require TLS connections |
| | Encryption (at rest) | Unspecified | **Critical** | Enable AWS RDS encryption at rest (AES-256), encrypt automated backups |
| | Encryption (in transit) | Unspecified | **High** | Enforce TLS 1.2+ for all database connections, verify server certificates |
| | Network Isolation | Partial (schema-per-tenant) | **High** | Deploy in private VPC subnet, use Security Groups to restrict access to API servers only, no internet access |
| | Authentication | Unspecified | **High** | Use IAM database authentication (not password), rotate credentials via AWS Secrets Manager |
| | Monitoring/Logging | Unspecified | **Medium** | Enable PostgreSQL audit logs, log all DDL/DML, monitor slow queries, enable Enhanced Monitoring |
| | Backup/Recovery | Present (daily snapshots) | **Medium** | Add point-in-time recovery (PITR), test restoration procedures, encrypt backups, cross-region replication |
| **Redis 7.0** | Access Control | Unspecified | **Critical** | Enable AUTH command, require password, use IAM roles if ElastiCache, restrict to VPC |
| | Encryption (at rest) | Unspecified | **High** | Enable ElastiCache encryption at rest (if using AWS) |
| | Encryption (in transit) | Unspecified | **Critical** | Enable TLS for Redis connections (Redis sessions contain JWT tokens!) |
| | Network Isolation | Unspecified | **Critical** | Deploy in private VPC subnet, Security Groups allow only API servers, no public access |
| | Authentication | Unspecified | **Critical** | Enable Redis AUTH, rotate passwords via Secrets Manager |
| | Monitoring/Logging | Unspecified | **Medium** | Enable slow log, monitor memory usage, alert on eviction policies |
| | Backup/Recovery | Missing | **High** | Enable Redis persistence (AOF + RDB), automated backups (if ElastiCache), disaster recovery plan |
| **Elasticsearch 8.7** | Access Control | Unspecified | **Critical** | Enable Security features (X-Pack), create role-based access, least-privilege service accounts |
| | Encryption (at rest) | Unspecified | **High** | Enable encryption at rest for indices (AWS Elasticsearch Service encryption) |
| | Encryption (in transit) | Unspecified | **Critical** | Enforce HTTPS for all API requests, enable node-to-node TLS encryption |
| | Network Isolation | Unspecified | **Critical** | Deploy in private VPC subnet, Security Groups restrict to API servers, no public endpoints |
| | Authentication | Unspecified | **Critical** | Enable Elasticsearch authentication (X-Pack Security), use IAM roles (if AWS), rotate credentials |
| | Monitoring/Logging | Unspecified | **Medium** | Enable audit logs for search queries (may contain PII), monitor cluster health, slow query logs |
| | Backup/Recovery | Missing | **High** | Configure automated snapshots to S3, test index restoration, define RPO/RTO |
| **AWS S3** | Access Control | **Broken** (public-read ACL) | **Critical** | Remove all public ACLs, block public access at bucket level, use private ACLs, IAM policies for access |
| | Encryption (at rest) | Unspecified | **High** | Enable S3 default encryption (SSE-S3 or SSE-KMS), enforce encryption via bucket policy |
| | Encryption (in transit) | Unspecified | **Medium** | Enforce HTTPS-only access via bucket policy (`aws:SecureTransport: true`) |
| | Network Isolation | Unspecified | **Medium** | Use VPC endpoint for S3 access (avoid internet routing), restrict bucket access to VPC |
| | Authentication | Partial (tenant-prefixed keys) | **High** | Implement pre-signed URLs with authorization checks, use IAM roles for API server access |
| | Monitoring/Logging | Unspecified | **High** | Enable S3 access logging, AWS CloudTrail for S3 data events, monitor for unusual access patterns |
| | Backup/Recovery | Unspecified | **Medium** | Enable S3 versioning (protect against accidental deletion), cross-region replication for disaster recovery |
| **AWS Application Load Balancer** | Access Control | Unspecified | **Medium** | Configure security groups to allow only HTTPS (443), restrict admin endpoints, implement IP whitelisting for admin routes |
| | Encryption (in transit) | Present (HTTPS enforced) | **Low** | Verify TLS 1.2+ only, disable weak ciphers, use strong cipher suites (ECDHE+AES128-GCM-SHA256) |
| | Network Isolation | Unspecified | **Medium** | Deploy in public subnet with WAF (Web Application Firewall), restrict backend to private subnets |
| | Authentication | N/A | N/A | ALB forwards requests to API servers for authentication |
| | Monitoring/Logging | Unspecified | **Medium** | Enable ALB access logs to S3, monitor 4xx/5xx errors, integrate with AWS WAF for attack detection |
| | Backup/Recovery | N/A | N/A | ALB is managed service with built-in availability |
| **AWS ECS Fargate** | Access Control | Unspecified | **High** | Use IAM roles for task execution (least privilege), restrict ECS API access, implement task IAM roles for S3/DB access |
| | Encryption (at rest) | Unspecified | **Medium** | Enable EFS encryption if using shared storage, encrypt ECS task logs |
| | Encryption (in transit) | Present (internal TLS to ALB) | **Low** | Verify all inter-service communication uses TLS |
| | Network Isolation | Unspecified | **High** | Deploy tasks in private subnets, use Security Groups to restrict traffic, no public IP assignment |
| | Authentication | Unspecified | **High** | Use IAM roles for ECS tasks (not environment variable credentials), rotate IAM credentials automatically |
| | Monitoring/Logging | Present (CloudWatch logs) | **Medium** | Enable ECS container insights, monitor task failures, log all container stdout/stderr |
| | Backup/Recovery | Unspecified | **Medium** | Document container image versioning, use immutable image tags, blue-green deployment strategy (mentioned, good) |
| **AWS Secrets Manager / KMS** | Access Control | **Missing** | **Critical** | **NOT MENTIONED IN DESIGN** - Implement Secrets Manager for all credentials (DB, Redis, API keys), use KMS for encryption keys |
| | Encryption (at rest) | **Missing** | **Critical** | Store all secrets in Secrets Manager (encrypted with KMS), never use environment variables for secrets |
| | Encryption (in transit) | **Missing** | **High** | Access Secrets Manager via VPC endpoint, enforce TLS |
| | Network Isolation | **Missing** | **Medium** | Use VPC endpoint for Secrets Manager (avoid internet routing) |
| | Authentication | **Missing** | **Critical** | Use IAM roles for secrets access (least privilege per service) |
| | Monitoring/Logging | **Missing** | **High** | Enable CloudTrail logging for all secrets access, alert on secret retrieval |
| | Backup/Recovery | **Missing** | **Medium** | Secrets Manager has built-in versioning, implement secret rotation (30-90 days) |

**Critical Gaps**:
1. **No secrets management solution specified**: Database passwords, Redis AUTH, API keys stored in "environment variables" (Section 6, line 269) - highly insecure
2. **Redis encryption in transit missing**: Critical because Redis stores session tokens and JWT data
3. **Elasticsearch exposed without authentication**: Default Elasticsearch has no authentication, must enable X-Pack Security
4. **S3 public-read ACL**: Already covered in Critical Issue #3

---

## Moderate Issues (Score 3)

### 9. Missing Session Management and Invalidation

**Severity**: MODERATE (Score: 3)

**Issue**: No session management strategy beyond JWT tokens:
- No session storage in Redis (despite Redis being mentioned for "session storage" in Section 2, line 42)
- No session invalidation mechanism (logout, password change, admin revoke)
- No concurrent session limits
- No session hijacking detection

**Impact**:
- Stolen tokens remain valid for 24 hours even after logout
- Password reset doesn't invalidate existing tokens
- Admin cannot revoke user access immediately (must wait for token expiration)

**Recommendations**:
1. Implement token blacklisting in Redis for immediate invalidation
2. Store active sessions in Redis with session IDs
3. Implement "logout from all devices" functionality
4. Invalidate all tokens on password change
5. Limit concurrent sessions per user (e.g., 5 devices)

---

### 10. Insufficient Email Integration OAuth Security

**Severity**: MODERATE (Score: 3)

**Issue**: OAuth flow implementation (Section 5, lines 238-246) lacks security measures:
- No state parameter validation (CSRF protection for OAuth)
- No PKCE (Proof Key for Code Exchange) mentioned
- Credentials stored unencrypted (covered in Critical Issue #4)

**Impact**:
- OAuth authorization code interception attacks
- CSRF attacks during OAuth flow
- Attacker can link their email account to victim's CRM account

**Recommendations**:
1. Implement state parameter: random token stored in session, validated after callback
2. Use PKCE for OAuth flow (prevents authorization code interception)
3. Validate redirect_uri matches registered URI
4. Implement user consent confirmation before storing credentials

---

### 11. Missing Data Retention and Deletion Policies

**Severity**: MODERATE (Score: 3)

**Issue**: Section 7 mentions "GDPR: Data export and deletion endpoints" (line 298) but provides no implementation details:
- How is "right to be forgotten" implemented in multi-tenant schema-per-tenant model?
- Are backups scrubbed of deleted data?
- What is the data retention period?
- How are deleted deals/contacts removed from Elasticsearch?

**Recommendations**:
1. Define data retention policy (e.g., 7 years for financial records, 90 days for logs)
2. Implement soft deletes with tombstoning (mark deleted, purge after retention period)
3. Create GDPR deletion workflow: mark for deletion → purge from DB → purge from backups → purge from Elasticsearch
4. Document that point-in-time backup restoration may contain deleted data (GDPR compliance risk)

---

## Minor Issues and Improvements (Score 4)

### 12. Weak Password Policy

**Issue**: Password hashing uses bcrypt with 10 rounds (Section 7, line 281) but no password complexity requirements specified.

**Recommendation**:
- Require minimum 12 characters, mix of upper/lower/numbers/symbols
- Check against common password lists (e.g., haveibeenpwned)
- Implement password history (prevent reuse of last 5 passwords)

---

### 13. Missing Content Security Policy (CSP)

**Issue**: No CSP headers specified for React SPA.

**Recommendation**: Implement strict CSP to mitigate XSS:
```
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://api.salespulse.com
```

---

### 14. Missing Security Headers

**Issue**: No mention of security response headers.

**Recommendation**: Implement:
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: strict-origin-when-cross-origin`

---

### 15. Single-Node Redis Deployment Risk

**Issue**: Section 7 specifies "Redis: Single-node deployment (non-clustered)" (line 289).

**Impact**: Redis failure causes:
- Loss of all sessions (all users logged out)
- Rate limiting data loss (bypass protection temporarily)
- Background job queue loss

**Recommendation**:
- Use Redis Cluster or AWS ElastiCache with Multi-AZ for high availability
- Implement graceful degradation (allow login even if Redis is down, skip rate limiting)
- Use Redis persistence (AOF) to recover data after failure

---

## Positive Security Aspects

1. **HTTPS Enforced**: All traffic uses TLS (Section 7, line 280) ✓
2. **Password Hashing**: bcrypt with 10 rounds (reasonable for performance) ✓
3. **Parameterized Queries**: SQL injection prevention (Section 7, line 282) ✓
4. **React XSS Protection**: Automatic output escaping (Section 7, line 283) ✓
5. **JWT Token Expiration**: 24-hour limit (though too long, see Issue #1)
6. **Multi-Tenant Isolation**: Schema-per-tenant architecture provides database-level isolation ✓
7. **Database Backups**: Daily automated snapshots (Section 7, line 288) ✓
8. **Blue-Green Deployment**: Reduces deployment risk (Section 6, line 267) ✓

---

## Summary of Recommendations by Priority

### Immediate (Pre-Production Blockers)
1. Change JWT storage from localStorage to httpOnly + Secure + SameSite cookies
2. Remove S3 public-read ACL, implement pre-signed URLs with authorization
3. Encrypt OAuth tokens at rest using application-layer encryption + KMS
4. Implement authorization checks for all API endpoints (ownership verification, RBAC)
5. Implement secrets management using AWS Secrets Manager (not environment variables)
6. Enable Redis AUTH and TLS encryption (session data protection)
7. Enable Elasticsearch authentication and TLS (X-Pack Security)

### High Priority (Within 30 Days)
8. Implement comprehensive rate limiting (authentication, API, webhooks)
9. Add CSRF protection (SameSite cookies + double-submit pattern)
10. Implement comprehensive audit logging with PII masking
11. Add webhook URL validation (SSRF prevention)
12. Enable database encryption at rest and in transit (PostgreSQL, Redis, Elasticsearch)
13. Implement session invalidation mechanism (logout, token blacklist)

### Medium Priority (Within 90 Days)
14. Implement OAuth state parameter validation and PKCE
15. Define and implement GDPR data deletion workflow
16. Add input validation policy (file types, string lengths, URL whitelist)
17. Enable infrastructure monitoring and security logging (CloudTrail, GuardDuty)
18. Implement Redis clustering/Multi-AZ for high availability
19. Add security response headers (CSP, HSTS, X-Frame-Options)

---

## Conclusion

The SalesPulse CRM design requires **significant security hardening** before production deployment. The most critical issues—insecure token storage, missing authorization controls, public file access, and unencrypted OAuth tokens—represent **severe security vulnerabilities** that could lead to data breaches, account takeovers, and compliance violations.

**Recommended Next Steps**:
1. Address all 7 immediate blockers (estimated 2-4 weeks development time)
2. Conduct security architecture review with senior security engineer
3. Perform threat modeling workshop using STRIDE framework
4. Create security implementation checklist for development team
5. Plan penetration testing after security controls are implemented

**Risk Assessment**: Without addressing critical issues, the platform is **not suitable for production use** handling customer data. The multi-tenant architecture amplifies risk—a single vulnerability could compromise multiple organizations' data.
