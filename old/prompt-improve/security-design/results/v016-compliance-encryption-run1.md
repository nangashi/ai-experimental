# Security Design Review: SalesPulse CRM Platform

## Executive Summary

This security evaluation identifies **9 critical issues**, **7 significant issues**, and **8 moderate issues** in the SalesPulse CRM design. The most severe risks include insecure JWT storage in localStorage (XSS vulnerability), missing encryption specifications for GDPR/SOC 2 compliance, public-read ACL on uploaded files, and complete absence of authorization controls allowing any user to modify or delete any data within a tenant.

**Overall Security Score: 1.8/5 (Critical Risk)**

---

## Compliance-Specific Encryption Assessment

### SOC 2 Encryption Requirements

The design document mentions "SOC 2: Audit logging for all data access" as a compliance requirement. SOC 2 Type II requires encryption controls as part of the Trust Services Criteria (CC6.1, CC6.7).

| Component | SOC 2 Requirement | Encryption Specification | Status | Risk | Recommendation |
|-----------|-------------------|--------------------------|--------|------|----------------|
| PostgreSQL (Primary Database) | CC6.1: Logical access controls include encryption | Not specified | **Non-compliant** | **Critical** | Specify encryption at rest using AWS RDS encryption with AES-256. Cite requirement: "SOC 2 CC6.1 requires encryption of sensitive data at rest. Enable RDS encryption with customer-managed KMS keys for audit trail." |
| Redis (Session Storage) | CC6.1: Encryption of data at rest | Not specified | **Non-compliant** | **High** | Specify encryption at rest using AWS ElastiCache encryption feature. Document encryption status in SOC 2 audit reports. |
| Elasticsearch | CC6.1: Encryption of indexed data | Not specified | **Non-compliant** | **High** | Specify encryption at rest for Elasticsearch indices using AWS OpenSearch Service encryption. |
| S3 (File Storage) | CC6.1: Encryption of stored objects | Not specified | **Non-compliant** | **Critical** | Specify S3 server-side encryption (SSE-S3 or SSE-KMS). Cite requirement: "SOC 2 CC6.1 mandates encryption of customer data. Enable default bucket encryption with AES-256." |
| API Transmission | CC6.7: Transmission encryption | HTTPS enforced | **Compliant** | Low | Specify TLS 1.2+ with strong cipher suites (ECDHE-RSA-AES256-GCM-SHA384). Document cipher configuration for SOC 2 audit. |
| Database Backups | CC6.1: Backup encryption | Not specified | **Non-compliant** | **Critical** | Specify encryption for RDS automated snapshots. AWS RDS encrypted instances automatically encrypt backups, but this must be documented. |
| CloudWatch Logs | CC6.1: Log data encryption | Not specified | **Non-compliant** | **High** | Enable CloudWatch Logs encryption using KMS. Logs contain user IDs and tenant IDs (potential PII). |
| Email Credentials (access_token, refresh_token) | CC6.1: Credential encryption | Stored as TEXT in database | **Non-compliant** | **Critical** | Do not store OAuth tokens in database columns as plaintext. Use AWS Secrets Manager or Parameter Store with encryption. Rotate credentials regularly. |

### GDPR Encryption Requirements

The design mentions "GDPR: Data export and deletion endpoints" but does not address GDPR Article 32(1)(a) encryption requirements.

| Component | GDPR Article | Encryption Specification | Status | Risk | Recommendation |
|-----------|--------------|--------------------------|--------|------|----------------|
| Personal Data (contacts, users tables) | Art. 32(1)(a): Pseudonymization and encryption | Not specified | **Non-compliant** | **High** | Implement database encryption at rest (RDS encryption). Consider field-level encryption for highly sensitive fields (email, phone). Cite: "GDPR Art. 32(1)(a) requires appropriate technical measures including encryption." |
| Data Exports (GDPR compliance feature) | Art. 32(1)(a): Encryption of exported data | Not specified | **Non-compliant** | **Medium** | Encrypt GDPR data export files before delivery. Use password-protected archives or provide download links with TLS + short expiration. |
| Data in Transit | Art. 32(1)(a): Transmission security | HTTPS enforced | **Compliant** | Low | Explicitly document TLS configuration (TLS 1.2+) in GDPR compliance documentation. |

**Key Compliance Gaps:**
1. **No Key Management Strategy**: No mention of AWS KMS, key rotation schedules, or access control for encryption keys.
2. **No Backup Encryption Policy**: Daily automated snapshots mentioned but encryption not specified (critical for GDPR/SOC 2).
3. **No Encryption for Logs**: CloudWatch logs contain user/tenant identifiers but encryption not specified.
4. **OAuth Token Storage**: Storing access_token and refresh_token as plaintext TEXT fields violates SOC 2 credential protection requirements.

---

## Infrastructure Security Assessment

| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| **PostgreSQL 15** | Access Control | Partial | **High** | Specify network-level access control (security groups allowing only ECS tasks). Document role-based access (application user vs. admin). No public internet access. |
| | Encryption (at rest) | **Missing** | **Critical** | Enable RDS encryption with AES-256. Use AWS KMS customer-managed keys for SOC 2 audit trail. |
| | Encryption (in transit) | **Unspecified** | **High** | Enforce SSL/TLS connections. Configure `sslmode=require` in connection strings. |
| | Network Isolation | **Unspecified** | **High** | Place database in private subnets with no internet gateway. Document VPC security group rules. |
| | Authentication | **Unspecified** | **High** | Specify password complexity requirements, credential rotation policy (90 days), and storage (AWS Secrets Manager). |
| | Monitoring/Logging | Partial (CloudWatch mentioned) | Medium | Enable RDS Performance Insights and Enhanced Monitoring. Log all connection attempts and DDL changes. Define alert thresholds (failed logins, unusual query patterns). |
| | Backup/Recovery | Partial (daily snapshots) | **High** | Specify backup retention period (minimum 30 days for SOC 2). Define RTO/RPO targets. Test restoration procedures quarterly. Encrypt backups (inherits from RDS encryption if enabled). |
| **Redis 7.0** | Access Control | **Missing** | **Critical** | Enable Redis AUTH with strong password (32+ characters). Restrict security group to ECS tasks only. |
| | Encryption (at rest) | **Missing** | **High** | Enable ElastiCache encryption at rest. Required for SOC 2 compliance. |
| | Encryption (in transit) | **Missing** | **Critical** | Enable ElastiCache in-transit encryption (TLS). Redis stores session tokens—unencrypted transit allows session hijacking on compromised network. |
| | Network Isolation | **Unspecified** | **High** | Deploy in private subnets. No public endpoint. |
| | Authentication | **Missing** | **Critical** | Configure Redis AUTH. Current design likely allows unauthenticated access from ECS tasks. |
| | Monitoring/Logging | **Unspecified** | Medium | Enable CloudWatch metrics for Redis (CPU, memory, connections). Log slow queries and authentication failures. |
| | Backup/Recovery | **Missing** | **High** | Single-node deployment mentioned—specify backup strategy (Redis persistence, RDB snapshots). Define failover procedure. |
| **Elasticsearch 8.7** | Access Control | **Missing** | **Critical** | Enable fine-grained access control. Create separate roles for indexing (write) and search (read). Do not use master credentials in application. |
| | Encryption (at rest) | **Missing** | **High** | Enable encryption at rest for OpenSearch Service. Required for SOC 2. |
| | Encryption (in transit) | **Unspecified** | **High** | Enforce HTTPS for all Elasticsearch API calls. Disable HTTP. |
| | Network Isolation | **Unspecified** | **High** | Deploy in VPC with private subnets. Use VPC endpoint for access. |
| | Authentication | **Missing** | **Critical** | Specify authentication mechanism (IAM roles, basic auth with rotating credentials). No public access. |
| | Monitoring/Logging | **Unspecified** | Medium | Enable audit logging for all index operations. Monitor cluster health and query performance. |
| | Backup/Recovery | Partial (3-node cluster) | Medium | Specify automated snapshot schedule. Define retention policy. Test index restoration. |
| **AWS S3** | Access Control | **Non-compliant** | **Critical** | **URGENT**: Files uploaded with `public-read` ACL (line 236). This exposes all customer files to the internet. Use private ACL + pre-signed URLs for authorized access. |
| | Encryption (at rest) | **Missing** | **Critical** | Enable default bucket encryption (SSE-S3 or SSE-KMS). Required for SOC 2/GDPR. |
| | Encryption (in transit) | Partial (HTTPS) | Medium | Enforce HTTPS-only access via bucket policy (`aws:SecureTransport`). Reject HTTP requests. |
| | Network Isolation | N/A (S3 is public service) | Low | Use VPC endpoint for S3 to avoid internet traffic. |
| | Authentication | **Unspecified** | **High** | Specify IAM role permissions for ECS tasks. Follow least privilege (allow PutObject/GetObject for specific bucket prefix only). No access keys in environment variables. |
| | Monitoring/Logging | **Missing** | **High** | Enable S3 access logging and CloudTrail for data events. Monitor for unusual access patterns (bulk downloads, unauthorized IPs). Required for SOC 2 audit logging. |
| | Backup/Recovery | Partial (S3 durability) | Medium | Enable S3 versioning to protect against accidental deletion. Define lifecycle policy for version retention. |
| **AWS ALB** | Access Control | Partial (HTTPS enforced) | Medium | Specify security group rules (allow 443 from internet, allow backend health checks from ALB only). |
| | Encryption (in transit) | Partial (HTTPS) | Medium | Specify TLS 1.2+ policy. Disable TLS 1.0/1.1. Document cipher suites for SOC 2 (prefer ECDHE-RSA-AES256-GCM-SHA384). |
| | Authentication | N/A (handled by API) | Low | Consider ALB authentication for additional defense layer (Cognito, OIDC). |
| | Monitoring/Logging | **Unspecified** | Medium | Enable ALB access logs to S3. Monitor for DDoS patterns, unusual request rates, error rates (5xx). |
| **ECS Fargate** | Access Control | **Unspecified** | **High** | Specify IAM task roles with least privilege. No instance profiles. Restrict security groups to necessary ports only. |
| | Secrets Management | Partial (env variables) | **Critical** | Do not store DB credentials and API keys in environment variables (line 269). Use ECS Secrets (AWS Secrets Manager or Parameter Store) with encryption. |
| | Monitoring/Logging | Partial (CloudWatch) | Medium | Enable container insights. Log all task start/stop events. Monitor for abnormal container behavior. |
| **AWS Secrets Manager** | | **Missing** | **Critical** | Not mentioned in design. Must be added for storing: DB passwords, Redis AUTH password, JWT signing key, OAuth client secrets, API keys for third-party services. |
| **AWS KMS** | | **Missing** | **Critical** | Not mentioned in design. Required for: RDS encryption keys, S3 encryption keys, Secrets Manager encryption, CloudWatch Logs encryption. Define key rotation policy (annual). |

**Critical Infrastructure Findings:**
1. **Public-read ACL on S3**: All uploaded files are publicly accessible (line 236: "Files stored in S3 with public-read ACL").
2. **No Secrets Management**: Credentials stored in environment variables (line 269) instead of AWS Secrets Manager.
3. **No Encryption Specifications**: None of the data stores specify encryption at rest despite SOC 2/GDPR requirements.
4. **Redis Single Node**: No backup or high-availability strategy for session storage (line 289: "Single-node deployment").
5. **Missing Authentication**: Redis, Elasticsearch lack authentication specifications.

---

## Detailed Security Evaluation by Criterion

### 1. Threat Modeling (STRIDE) - Score: 2/5 (Significant Issue)

#### Spoofing (Score: 2/5)
**Critical Issue**: JWT stored in localStorage (line 169) is vulnerable to XSS attacks. If an attacker injects malicious JavaScript (e.g., via compromised third-party library, stored XSS in custom fields), the script can steal the JWT and impersonate the user.

**Impact**: Complete account takeover. Attacker gains access to all data within the user's tenant.

**Recommendation**: Store JWT in httpOnly cookies with Secure and SameSite=Strict flags. This prevents JavaScript access to the token. Update authentication flow to use cookies instead of Authorization header.

#### Tampering (Score: 2/5)
**Critical Issue**: No authorization controls for data modification. Any user within a tenant can update or delete any deal (lines 219-224: "No ownership verification - any user in the tenant can update any deal").

**Impact**: Malicious or compromised user account can corrupt or delete all sales data within the tenant. No audit trail of who made changes.

**Recommendation**: Implement ownership-based authorization. Only deal owners and managers should update/delete deals. Add `updated_by` field to track changes. Implement soft deletes with `deleted_at` timestamp for audit trail.

#### Repudiation (Score: 3/5)
**Moderate Issue**: Logging mentions user ID and tenant ID (line 258) but no explicit audit trail for data modifications. Cannot prove who deleted a deal or changed a contact's email.

**Recommendation**: Implement comprehensive audit logging table with: user_id, tenant_id, action (CREATE/UPDATE/DELETE), entity_type, entity_id, old_values (JSON), new_values (JSON), timestamp, IP address. Retain audit logs for minimum 1 year (SOC 2 requirement). Protect audit logs from modification (write-only for application, separate admin access).

#### Information Disclosure (Score: 1/5)
**Critical Issues**:
1. **Public S3 files**: All uploaded files have public-read ACL (line 236), exposing sensitive customer documents to anyone with the URL.
2. **OAuth tokens in database**: Access and refresh tokens stored as plaintext TEXT fields (lines 142-144).
3. **No encryption specifications**: PostgreSQL, Redis, Elasticsearch, S3 lack encryption at rest specifications despite storing sensitive customer data.

**Recommendation**:
- S3: Use private ACL. Generate pre-signed URLs (1-hour expiration) for authorized file access.
- OAuth tokens: Store in AWS Secrets Manager with encryption. Reference secrets by ARN in database.
- Enable encryption at rest for all data stores (see Infrastructure Assessment section).

#### Denial of Service (Score: 3/5)
**Moderate Issue**: No rate limiting specifications. API endpoints vulnerable to brute-force attacks (login, password reset) and resource exhaustion (file uploads, webhook registrations).

**Recommendation**: Implement rate limiting per IP and per user:
- Login attempts: 5 failures per 15 minutes per IP
- Password reset: 3 requests per hour per email
- File uploads: 10 requests per minute per user
- Webhook registrations: 10 per tenant
- API calls: 1000 requests per minute per tenant

Use Redis for rate limit counters. Return 429 Too Many Requests with Retry-After header.

#### Elevation of Privilege (Score: 2/5)
**Significant Issue**: No role-based authorization logic specified. Design mentions roles (admin, manager, user) but no permission model. Any authenticated user can access all tenant data regardless of role.

**Recommendation**: Define permission model:
- **user**: CRUD own contacts/deals, read shared contacts/deals
- **manager**: CRUD all contacts/deals in tenant, read reports
- **admin**: All manager permissions + user management + configuration

Implement middleware to check user role before processing requests. Deny access with 403 Forbidden if role insufficient.

---

### 2. Authentication & Authorization Design - Score: 1/5 (Critical Issue)

**Critical Issues**:

1. **Insecure JWT Storage**: Tokens stored in localStorage (line 169) are accessible to JavaScript, enabling XSS-based token theft. This violates OWASP best practices for token storage.

2. **No Authorization Logic**: Design specifies roles (admin, manager, user) but provides no authorization enforcement mechanism. Lines 219-224 explicitly state "No ownership verification - any user in the tenant can update any deal" and "any user in the tenant can delete any deal."

3. **No Token Refresh Mechanism**: JWT expiration set to 24 hours (line 90) with no refresh token flow. Users must re-authenticate daily, poor UX. Long-lived tokens increase attack window.

4. **No Session Revocation**: No mechanism to invalidate JWTs before expiration. If a user's device is compromised or they leave the company, their token remains valid for up to 24 hours.

5. **Password Reset Token Validation**: Reset tokens valid for 1 hour (line 201) but no specification of: token storage mechanism, one-time use enforcement, secure token generation algorithm.

**Specific Missing Specifications**:
- Token signing algorithm (HS256, RS256?)
- JWT signing key storage and rotation policy
- Session storage schema in Redis (if any)
- Account lockout policy after failed login attempts
- Password complexity requirements (mentioned hash algorithm but not requirements)
- Multi-factor authentication for privileged accounts
- API key authentication for programmatic access

**Recommendations**:

1. **Immediate (Critical)**:
   - Migrate JWT storage from localStorage to httpOnly + Secure + SameSite=Strict cookies
   - Implement role-based access control middleware with permission checks before every data-modifying operation
   - Add ownership verification for deal/contact updates/deletes

2. **High Priority**:
   - Implement token refresh flow (short-lived access token 15 minutes, long-lived refresh token 7 days stored in httpOnly cookie)
   - Add token revocation list in Redis (track invalidated JWTs by jti claim)
   - Specify JWT signing with RS256 (asymmetric) and store private key in AWS Secrets Manager
   - Implement password complexity requirements: minimum 12 characters, mix of uppercase, lowercase, numbers, special characters
   - Add account lockout: 5 failed attempts = 15-minute lockout

3. **Medium Priority**:
   - Add MFA for admin and manager roles (TOTP-based)
   - Implement API keys for programmatic access (separate from user JWTs)
   - Add device tracking and anomalous login detection (new location, new device)

---

### 3. Data Protection - Score: 1/5 (Critical Issue)

**Critical Issues**:

1. **No Encryption at Rest**: Despite SOC 2 and GDPR compliance requirements, no encryption is specified for:
   - PostgreSQL (stores customer data, contact information, deal amounts)
   - Redis (stores session tokens, cache data)
   - Elasticsearch (stores full-text indexed customer data)
   - S3 (stores uploaded files)
   - RDS automated snapshots (line 288: "Daily automated snapshots" but no encryption mentioned)

2. **Public File Access**: Line 236 states "Files stored in S3 with public-read ACL." Any person with the S3 object URL can download customer files without authentication. This is a data breach waiting to happen.

3. **OAuth Token Exposure**: Email integration stores access_token and refresh_token as plaintext TEXT fields (lines 142-144). If database is compromised, attacker gains access to users' Gmail/Outlook accounts.

4. **Custom Fields JSONB**: Line 124 shows contacts have `custom_fields (JSONB)` with no specification of what data can be stored. Customers may store PII, PHI, or sensitive data in custom fields with no protection.

5. **No Data Retention Policy**: GDPR requires data minimization and retention limits. Design mentions deletion endpoints (line 298) but no automatic data retention/deletion policy.

6. **No Field-Level Encryption**: Sensitive fields (email, phone, password_hash) stored in plaintext (encrypted only if RDS encryption is enabled, which is not specified).

**Missing Specifications**:
- Encryption algorithms and key lengths
- Key management strategy (AWS KMS not mentioned)
- Data classification policy (what data is considered sensitive?)
- Data masking for logs and error messages
- Secure deletion procedures (cryptographic erasure, overwriting)
- Data residency requirements (which AWS regions?)
- Encryption in transit between services (API to PostgreSQL, API to Redis, API to Elasticsearch)

**Recommendations**:

1. **Immediate (Critical)**:
   - Enable RDS encryption with AWS KMS (customer-managed keys for audit trail)
   - Enable S3 default bucket encryption (SSE-KMS)
   - Change S3 ACL from public-read to private
   - Enable ElastiCache encryption at rest and in transit
   - Enable OpenSearch encryption at rest
   - Migrate OAuth tokens from database to AWS Secrets Manager

2. **High Priority**:
   - Define data classification policy: Public, Internal, Confidential, Restricted
   - Classify fields: email, phone (Confidential), custom_fields (user-defined, assume Confidential), deal amounts (Confidential)
   - Implement field-level encryption for custom_fields JSONB column using application-level encryption (AES-256-GCM)
   - Define key rotation schedule: KMS keys rotated annually, JWT signing keys rotated quarterly
   - Enforce TLS for all internal connections (app to database, app to Redis, app to Elasticsearch)

3. **Medium Priority**:
   - Implement data retention policy: GDPR requires deletion after purpose fulfilled or user request. Define retention periods (e.g., deleted contacts purged after 30 days, audit logs kept for 7 years).
   - Implement PII masking in logs (replace email with email domain, mask phone numbers)
   - Add data residency controls (allow customers to choose AWS region for compliance)
   - Implement backup encryption verification (automated tests to confirm encrypted backups)

---

### 4. Input Validation Design - Score: 2/5 (Significant Issue)

**Significant Issues**:

1. **No Input Validation Policy**: Design mentions "SQL injection prevention via parameterized queries" (line 282) and "XSS prevention via React's automatic escaping" (line 283) but provides no comprehensive input validation strategy.

2. **File Upload Validation**: Only specifies size limits (10MB per file, 50MB per request, line 96) but no validation of:
   - File type restrictions (allow list of extensions)
   - Content-Type validation (check magic bytes, not just HTTP header)
   - Filename sanitization (prevent directory traversal: ../../../etc/passwd)
   - Malware scanning (uploaded files could contain viruses, ransomware)

3. **Webhook URL Validation**: Line 226-232 shows webhook registration accepts arbitrary URLs with no validation. Attacker could register `http://internal-service:8080/admin` to perform SSRF attacks against internal infrastructure.

4. **Email Validation**: Contact email field (line 120) has no format validation specified. Could accept invalid emails, SQL injection attempts, or XSS payloads.

5. **Custom Fields JSONB**: Line 124 allows arbitrary JSON in custom_fields with no validation. Attacker could inject deeply nested JSON to cause DoS (JSON parsing CPU exhaustion) or store malicious scripts.

6. **Search Parameter Injection**: Line 204 shows search parameter `?search=john` with no specification of sanitization. Elasticsearch query injection risk if search term directly interpolated into query DSL.

7. **No Output Encoding Specification**: Line 283 relies on "React's automatic escaping" but no specification for API responses consumed by non-React clients (mobile apps, third-party integrations).

**Missing Specifications**:
- Input validation framework (Joi, Yup, class-validator?)
- Allow-list for file upload types
- Maximum string lengths for all VARCHAR fields
- Email format validation (RFC 5322)
- URL validation for webhooks (protocol allow-list, deny private IP ranges)
- JSON schema validation for custom_fields
- HTML sanitization policy for rich text fields (if any)
- SQL injection prevention beyond parameterized queries (ORM configuration, prepared statements)

**Recommendations**:

1. **Immediate (High Priority)**:
   - Implement webhook URL validation: allow only https:// (no http://), deny private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8), deny localhost and internal AWS metadata endpoints (169.254.169.254)
   - Add file upload type validation: allow list of MIME types (image/jpeg, image/png, application/pdf, text/plain, application/vnd.openxmlformats-officedocument.*), reject executables (.exe, .sh, .bat)
   - Implement filename sanitization: strip directory traversal characters, limit to alphanumeric + underscore + hyphen + period, max 255 characters

2. **High Priority**:
   - Define input validation library (recommend Joi or Zod for TypeScript)
   - Create validation schemas for all API endpoints
   - Implement email format validation using RFC 5322 regex or validator library
   - Add JSON schema validation for custom_fields: maximum nesting depth 5, maximum object size 50KB
   - Implement Elasticsearch query parameterization (use query builders, never string interpolation)
   - Add Content-Type validation: check file magic bytes using library like file-type, reject if mismatch

3. **Medium Priority**:
   - Integrate malware scanning for file uploads (ClamAV, VirusTotal API)
   - Define maximum string lengths: email (254), name (100), phone (20), custom field keys (50)
   - Implement rate limiting on file uploads (see DoS section)
   - Add CSV injection prevention for data export features (prefix =, +, -, @ with single quote)
   - Implement Content Security Policy headers for React SPA (restrict script sources)

---

### 5. Infrastructure & Dependency Security - Score: 2/5 (Significant Issue)

**Significant Issues**:

1. **Outdated Dependencies Risk**: Design specifies exact versions (Express 4.18, React 18, bcrypt 5.1, etc.) but no update policy. Known vulnerabilities:
   - jsonwebtoken 9.0 (current is 9.0.2, line 54) has known vulnerabilities in older 8.x versions
   - axios 1.3 (line 57) is outdated (current 1.6+), older versions have SSRF vulnerabilities

2. **No Dependency Scanning**: No mention of automated vulnerability scanning (Snyk, Dependabot, npm audit in CI/CD).

3. **Secrets in Environment Variables**: Line 269 states "Environment variables for configuration (DB credentials, API keys)." Environment variables are visible in process listings, logs, and error messages. Not appropriate for sensitive credentials.

4. **No Network Segmentation Specified**: Component diagram (lines 77-85) shows connections but no VPC design, security groups, or network isolation strategy.

5. **Redis Single-Node Risk**: Line 289 specifies "Redis: Single-node deployment (non-clustered)." Redis stores session tokens—if Redis fails, all users are logged out. No backup or persistence strategy specified.

6. **Third-Party Integration Security**: Line 19 mentions "Third-party integrations via REST API and webhooks" but no security specifications for:
   - Webhook signature verification (line 152 mentions secret but no HMAC algorithm specified)
   - API rate limiting for third-party consumers
   - OAuth scope restrictions for email integrations

7. **Container Security**: Uses Docker containers (ECS Fargate, line 48) but no specifications for:
   - Base image selection (official Node.js images? Alpine? Minimal distro?)
   - Image scanning for vulnerabilities
   - Non-root user for container processes
   - Read-only root filesystem

**Missing Specifications**:
- Dependency update policy and cadence
- Vulnerability scanning tools and thresholds
- Secrets management solution (AWS Secrets Manager, Parameter Store, Vault)
- VPC design with public/private subnets
- Security group rules for each component
- Redis persistence configuration (RDB, AOF)
- Webhook HMAC algorithm (SHA-256? SHA-512?)
- Container image hardening standards
- Monitoring and alerting for infrastructure components
- Patch management process for OS and dependencies

**Recommendations**:

1. **Immediate (Critical)**:
   - Migrate secrets from environment variables to AWS Secrets Manager: DB password, Redis password, JWT signing key, OAuth client secrets, third-party API keys
   - Update ECS task definitions to reference secrets using secretsManager ARN
   - Implement dependency scanning in CI/CD: run `npm audit` on every commit, fail build if high/critical vulnerabilities
   - Add Dependabot or Renovate to automate dependency updates

2. **High Priority**:
   - Define VPC architecture: API servers and workers in private subnets, ALB in public subnet, databases in isolated private subnets with no internet gateway
   - Specify security groups:
     - ALB SG: allow 443 from 0.0.0.0/0 (internet), allow health checks from VPC CIDR
     - API server SG: allow traffic from ALB SG only, allow outbound to database SGs
     - PostgreSQL SG: allow 5432 from API server SG only
     - Redis SG: allow 6379 from API server SG only
     - Elasticsearch SG: allow 443 from API server SG only
   - Enable Redis persistence: use RDB snapshots every 5 minutes + AOF for durability. Define backup retention (7 days minimum).
   - Implement webhook signature verification: generate HMAC-SHA256 signature using webhook secret, include in `X-Webhook-Signature` header, verify on recipient side

3. **Medium Priority**:
   - Harden container images: use official Node.js Alpine images, run as non-root user (UID 1000), scan images with Trivy or Clair in CI/CD
   - Implement dependency pinning: use package-lock.json, verify checksums, audit new dependencies before adoption
   - Define patch management SLA: critical vulnerabilities patched within 7 days, high within 30 days, medium within 90 days
   - Add infrastructure monitoring: CloudWatch alarms for ECS task failures, RDS CPU/connections, Redis memory, Elasticsearch cluster health
   - Implement log aggregation: centralize logs from all services in CloudWatch Logs or ELK stack for security monitoring

---

## Moderate Issues

### 6. Missing Rate Limiting (Score: 3/5)

**Issue**: No rate limiting specified for any API endpoints. Vulnerable to brute-force attacks (login, password reset) and resource exhaustion (file uploads, search queries).

**Recommendation**: Implement tiered rate limiting:
- Authentication endpoints: 5 login attempts per 15 minutes per IP
- Password reset: 3 requests per hour per email address
- File uploads: 10 requests per minute per user
- Search queries: 100 requests per minute per user (expensive Elasticsearch queries)
- API calls: 1000 requests per minute per tenant

Use Redis for rate limit counters (INCR with TTL). Return 429 status with Retry-After header.

### 7. Missing CSRF Protection (Score: 3/5)

**Issue**: No CSRF protection specified. If JWT is moved to cookies (as recommended), API is vulnerable to CSRF attacks where attacker tricks user into making authenticated requests.

**Recommendation**: Implement CSRF token mechanism:
- Generate random CSRF token on login, store in Redis associated with session
- Include CSRF token in httpOnly cookie (separate from JWT)
- Require `X-CSRF-Token` header on all state-changing requests (POST, PUT, DELETE)
- Verify token matches session before processing request
- Alternatively, rely on SameSite=Strict cookie attribute (blocks cross-site requests entirely)

### 8. Missing Idempotency Guarantees (Score: 3/5)

**Issue**: No idempotency mechanism for state-changing operations. If client retries a failed POST /api/contacts request, duplicate contacts are created. Same risk for deal creation, file uploads, webhook deliveries.

**Recommendation**: Implement idempotency key system:
- Accept optional `Idempotency-Key` header on POST/PUT/DELETE requests (UUID generated by client)
- Store key + request hash + response in Redis with 24-hour TTL
- If duplicate key received, return cached response (same status code and body)
- Required for financial operations (deal amounts) and webhook deliveries (duplicate notifications)

### 9. Missing Audit Logging for Compliance (Score: 3/5)

**Issue**: Design mentions "SOC 2: Audit logging for all data access" (line 299) but audit logging implementation is not designed. Current logging (line 256-258) is operational logging, not compliance audit logging.

**Recommendation**: Implement audit logging table:
- Columns: id, timestamp, user_id, tenant_id, action (CREATE/UPDATE/DELETE), entity_type, entity_id, old_values (JSON), new_values (JSON), ip_address, user_agent
- Log all data modifications: contact created, deal updated, user deleted, permissions changed
- Log all authentication events: login success, login failure, logout, password change, MFA enrollment
- Log all administrative actions: user created, role changed, webhook registered, configuration updated
- Retain logs for minimum 1 year (SOC 2 requirement), recommend 7 years for regulatory compliance
- Protect logs from modification: write-only for application, separate read access for auditors
- Mask sensitive data: hash PII in logs, do not log passwords or tokens

### 10. Missing Error Information Disclosure Policy (Score: 3/5)

**Issue**: Line 251-253 states "Error responses include message and error code" and "Unexpected errors logged to CloudWatch" but no specification of what information is safe to expose in error responses.

**Risk**: Detailed error messages can leak sensitive information:
- Stack traces revealing file paths and framework versions
- Database errors revealing schema information ("column 'admin_flag' does not exist")
- Validation errors revealing business logic ("User must be premium to access this feature")

**Recommendation**: Define error exposure policy:
- **Production**: Return generic error messages to clients ("An error occurred"), log detailed error internally
- **Development**: Return detailed errors for debugging
- **API errors**: Never expose stack traces, database errors, or internal file paths
- **Validation errors**: Safe to return ("Email format invalid", "Password must be 12+ characters")
- **Authentication errors**: Use generic message ("Invalid credentials") to prevent username enumeration
- Implement error sanitization middleware to enforce policy

### 11. Missing Password Policy Specifications (Score: 3/5)

**Issue**: Design specifies bcrypt with 10 rounds (line 281) but no password complexity requirements, no password expiration policy, no password history (prevent reuse).

**Recommendation**:
- Minimum length: 12 characters (NIST recommendation)
- Complexity: At least 3 of 4 categories (uppercase, lowercase, numbers, special characters)
- Password history: Prevent reuse of last 5 passwords
- Password expiration: No forced expiration (causes users to choose weak passwords), only require change if compromised
- Breached password detection: Integrate with HaveIBeenPwned API to reject compromised passwords
- Account recovery: Require email verification + security questions or MFA for password reset

### 12. Missing Multi-Tenancy Security Controls (Score: 3/5)

**Issue**: Design uses schema-per-tenant model (line 72) with tenant resolution from subdomain (line 73), but insufficient security controls:
- No specification of how tenant context is enforced (line 74 mentions middleware but no implementation details)
- No cross-tenant data leakage prevention mechanism
- No tenant isolation testing strategy

**Risk**: If tenant context middleware fails or is bypassed, users could access data from other tenants. This is a catastrophic security failure in multi-tenant systems.

**Recommendation**:
- Implement defense-in-depth for tenant isolation:
  1. Tenant context middleware: Parse subdomain, validate tenant exists, attach tenant_id to request object
  2. Database query enforcement: All queries MUST include `tenant_id` in WHERE clause (use ORM middleware to enforce)
  3. Row-level security: Enable PostgreSQL RLS policies on all tables to enforce tenant_id filtering at database level
  4. Tenant validation: Before returning data, assert response.tenant_id === request.tenant_id
- Add automated cross-tenant access tests: Create test accounts in Tenant A and Tenant B, verify Tenant A cannot access Tenant B's data by manipulating subdomain, JWT, or API parameters
- Implement tenant context audit logging: Log tenant_id on every request, alert on tenant context switching (indicates attack attempt)

### 13. Missing Webhook Security Specifications (Score: 3/5)

**Issue**: Webhook design (lines 148-155, 232) lacks security specifications:
- Webhook secret generation algorithm not specified (line 152: "generated secret")
- No HMAC signature algorithm specified
- No retry policy for failed deliveries (what if customer endpoint is down?)
- No timeout specifications (what if customer endpoint is slow?)
- No webhook delivery authentication (customer endpoint could be accessed by anyone)

**Recommendation**:
- Generate webhook secret: Use cryptographically secure random generator (32 bytes, base64 encoded)
- Implement HMAC signature: Compute `HMAC-SHA256(secret, request_body)`, include in `X-Webhook-Signature` header
- Add retry policy: Retry failed deliveries with exponential backoff (1min, 5min, 15min, 1hour, 6hour), max 5 attempts, disable webhook after repeated failures
- Set timeout: 10 seconds for webhook HTTP requests, fail delivery if timeout exceeded
- Add delivery logs: Store webhook delivery attempts (timestamp, status_code, response_time, error) for debugging
- Implement webhook IP allow-list: Allow customers to restrict webhook sources to SalesPulse IP ranges

### 14. Missing Email Integration OAuth Security (Score: 3/5)

**Issue**: Email integration stores OAuth tokens in database (lines 142-145) but lacks OAuth security specifications:
- No mention of OAuth scope restrictions (what permissions are requested?)
- No token refresh mechanism specified
- No token revocation handling (what if user revokes access in Gmail?)
- Tokens stored as TEXT (plaintext) in database

**Recommendation**:
- Specify OAuth scopes: Request minimal scopes (Gmail: `gmail.readonly` for read access, `gmail.send` for sending; Outlook: `Mail.Read`, `Mail.Send`). Do not request `gmail.modify` or full mailbox access.
- Implement token refresh: Check `expires_at` before using access_token, automatically refresh using refresh_token if expired, update database
- Handle token revocation: Catch OAuth errors (401 Unauthorized), mark integration as disconnected, notify user to re-authenticate
- Migrate tokens to Secrets Manager: Do not store tokens in database, store in AWS Secrets Manager with encryption, reference by secret ARN in database
- Add OAuth consent screen: Display requested scopes and permissions to users before authorization

---

## Positive Security Aspects

1. **HTTPS Enforced**: Line 280 confirms HTTPS for all traffic (though TLS version not specified).
2. **Password Hashing**: Line 281 uses bcrypt with 10 rounds (adequate for current standards, though 12+ rounds recommended).
3. **Parameterized Queries**: Line 282 mentions SQL injection prevention via parameterized queries (good, but ORM configuration not specified).
4. **JWT with Expiration**: Line 90 sets 24-hour token expiration (though refresh flow missing).
5. **Database Backups**: Line 288 specifies daily automated snapshots (though encryption and retention not specified).
6. **Multi-tenancy Architecture**: Schema-per-tenant model (line 72) provides strong data isolation if implemented correctly.
7. **Structured Logging**: Line 256 specifies JSON logs with context (good for security monitoring, but PII masking policy missing).

---

## Summary Scores by Criterion

| Criterion | Score | Severity | Key Issues |
|-----------|-------|----------|------------|
| Threat Modeling (STRIDE) | 2/5 | Significant | JWT in localStorage (XSS risk), no authorization controls, public S3 files, no rate limiting |
| Authentication & Authorization | 1/5 | Critical | JWT in localStorage, no RBAC enforcement, no token refresh, no session revocation |
| Data Protection | 1/5 | Critical | No encryption at rest (PostgreSQL, Redis, Elasticsearch, S3), public S3 ACL, OAuth tokens in plaintext |
| Input Validation | 2/5 | Significant | No validation policy, webhook SSRF risk, file upload validation incomplete, custom fields unvalidated |
| Infrastructure & Dependency Security | 2/5 | Significant | Secrets in env vars, no secrets manager, no network segmentation specified, Redis single-node, no dependency scanning |

**Overall Score: 1.8/5 (Critical Risk)**

---

## Priority Recommendations

### Immediate Actions (Critical Risk)

1. **Change JWT storage from localStorage to httpOnly cookies** (prevents XSS token theft)
2. **Enable encryption at rest for all data stores**: RDS (AES-256), S3 (SSE-KMS), ElastiCache, OpenSearch
3. **Change S3 ACL from public-read to private**, use pre-signed URLs for authorized access
4. **Implement authorization controls**: ownership verification for deal/contact updates/deletes, RBAC middleware
5. **Migrate secrets from environment variables to AWS Secrets Manager**: DB passwords, JWT signing key, OAuth secrets
6. **Migrate OAuth tokens from database TEXT fields to AWS Secrets Manager**

### High Priority (Significant Risk)

7. Implement rate limiting (authentication, file uploads, API calls)
8. Add webhook URL validation (deny private IPs, localhost, metadata endpoints)
9. Define and implement permission model for roles (user, manager, admin)
10. Implement token refresh flow (15-minute access tokens, 7-day refresh tokens)
11. Add CSRF protection (token-based or SameSite=Strict cookies)
12. Enable encryption in transit for internal connections (TLS to database, Redis, Elasticsearch)
13. Define VPC architecture with security groups and network isolation
14. Implement comprehensive audit logging for SOC 2 compliance

### Medium Priority

15. Add file upload malware scanning (ClamAV, VirusTotal)
16. Implement idempotency key system for state-changing operations
17. Add dependency vulnerability scanning in CI/CD (npm audit, Snyk)
18. Harden container images (Alpine, non-root user, vulnerability scanning)
19. Define data retention and deletion policies for GDPR compliance
20. Implement PII masking in logs and error messages
21. Add cross-tenant access prevention tests
22. Define webhook retry policy and delivery logging

---

## Compliance Summary

**SOC 2 Readiness: Non-compliant**
- Missing: Encryption at rest for all data stores
- Missing: Audit logging for all data access
- Missing: Key management strategy (KMS)
- Missing: Backup encryption
- Missing: Access controls for infrastructure components

**GDPR Readiness: Partially Compliant**
- Present: Data export and deletion endpoints (line 298)
- Missing: Encryption for personal data (Art. 32(1)(a))
- Missing: Data retention policies
- Missing: Data minimization controls
- Missing: PII masking in logs
- Missing: Data processing records

**Estimated Remediation Effort**: 6-8 weeks for critical issues, 12-16 weeks for full compliance.

---

## References

- OWASP Top 10 2021: A01 Broken Access Control, A02 Cryptographic Failures, A03 Injection, A07 Identification and Authentication Failures
- NIST SP 800-63B: Digital Identity Guidelines (Authentication and Lifecycle Management)
- CIS AWS Foundations Benchmark v1.5.0
- SOC 2 Trust Services Criteria (CC6.1, CC6.6, CC6.7, CC7.2)
- GDPR Articles 32 (Security of processing), 25 (Data protection by design and by default)
- PCI DSS v4.0 Requirements 3 (Protect stored account data), 4 (Protect cardholder data with strong cryptography during transmission over open, public networks)

---

**Review Date**: 2026-02-10
**Reviewer**: Security Design Reviewer (Variant: compliance-encryption)
**Document Version**: Round 16 Test Document
