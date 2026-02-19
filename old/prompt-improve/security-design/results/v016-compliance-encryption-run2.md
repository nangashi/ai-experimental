# Security Design Review: SalesPulse CRM Platform

## Executive Summary

This security evaluation identifies **12 critical issues**, **8 significant issues**, and **6 moderate issues** in the SalesPulse CRM design document. The most severe concerns include insecure JWT storage in localStorage (XSS vulnerability), missing encryption specifications for GDPR/SOC 2 compliance, publicly readable S3 files, missing rate limiting, and inadequate access controls. Immediate action is required to address critical vulnerabilities before production deployment.

## Overall Security Scores

| Evaluation Criterion | Score | Severity |
|---------------------|-------|----------|
| Threat Modeling (STRIDE) | 2 | Significant |
| Authentication & Authorization Design | 1 | Critical |
| Data Protection | 1 | Critical |
| Input Validation Design | 2 | Significant |
| Infrastructure & Dependency Security | 1 | Critical |

**Overall Assessment**: The design document has critical security gaps that pose immediate risk of data breach, privilege escalation, and compliance violations.

---

## Critical Issues (Severity 1)

### 1. Insecure JWT Token Storage in localStorage (XSS Vulnerability)

**Severity**: Critical
**Criterion**: Authentication & Authorization Design
**Section**: 5. API Design - Authentication

**Issue Description**:
The design explicitly specifies storing JWT tokens in browser localStorage (line 169: "Token Storage: Stored in browser localStorage"). This creates a critical XSS vulnerability because:
- localStorage is accessible to any JavaScript code running on the page
- XSS attacks can exfiltrate tokens and impersonate users
- 24-hour token expiration provides a long attack window
- Multi-tenant architecture means one compromised token can access all tenant data

**Why This Is Dangerous**:
According to OWASP, storing authentication tokens in localStorage is considered a critical security anti-pattern. Any successful XSS attack (including via third-party libraries, browser extensions, or injected content) can steal tokens and gain persistent access to user accounts. Given this is a CRM with sensitive customer data, the impact is severe.

**Impact**:
- Complete account takeover via XSS
- Unauthorized access to all tenant data (contacts, deals, emails)
- Persistent session hijacking for 24 hours
- No automatic token invalidation on browser close
- Violation of SOC 2 access control requirements

**Recommendation**:
**IMMEDIATELY change token storage mechanism**:
1. Use httpOnly + Secure + SameSite=Strict cookies for JWT storage
2. Implement CSRF protection with double-submit cookie pattern or synchronizer tokens
3. Reduce token expiration to 15 minutes with refresh token mechanism (refresh tokens in httpOnly cookies)
4. Add token binding to prevent token replay attacks
5. Implement Content Security Policy (CSP) headers to mitigate XSS

**References**: Lines 90-91, 169

---

### 2. Missing Encryption Specifications for GDPR and SOC 2 Compliance

**Severity**: Critical
**Criterion**: Data Protection
**Section**: 7. Non-functional Requirements - Compliance

**Issue Description**:
The design mentions GDPR and SOC 2 compliance (lines 298-299) but provides **no encryption specifications** for data at rest or in transit beyond "HTTPS enforced" (line 281). This violates explicit regulatory requirements.

#### GDPR Encryption Requirements Assessment

| Component | GDPR Article | Encryption Specification | Status | Risk | Recommendation |
|-----------|--------------|--------------------------|--------|------|----------------|
| PostgreSQL (customer data, email credentials) | Art. 32(1)(a): Pseudonymization and encryption of personal data | Not specified | **Non-compliant** | **Critical** | Implement AES-256 encryption at rest using AWS RDS encryption. Specify key management via AWS KMS with automatic key rotation. |
| Redis (sessions, cached personal data) | Art. 32(1)(a): Encryption of personal data | Not specified | **Non-compliant** | **Critical** | Enable Redis encryption at rest and in-transit TLS. Document encryption for cached personal data. |
| Elasticsearch (indexed contact/company data) | Art. 32(1)(a): Encryption of personal data | Not specified | **Non-compliant** | **Critical** | Implement Elasticsearch encryption at rest (node-to-node encryption). Use AWS OpenSearch encryption. |
| S3 (file attachments) | Art. 32(1)(a): Encryption of personal data | Not specified | **Non-compliant** | **Critical** | Enable S3 default encryption (SSE-S3 or SSE-KMS). Specify encryption for backups and versioned objects. |
| Database Backups | Art. 32(1)(a): Encryption of personal data | Not specified | **Non-compliant** | **Critical** | Verify automated snapshots are encrypted. Document backup encryption policy. |
| email_credentials table (access_token, refresh_token) | Art. 32(1)(a): Encryption of personal data + Art. 5(1)(f): Integrity and confidentiality | Not specified | **Non-compliant** | **Critical** | Encrypt access_token and refresh_token columns using application-level encryption (AES-256-GCM) with per-tenant keys stored in AWS KMS. |

#### SOC 2 Encryption Requirements Assessment

| Component | SOC 2 Requirement | Encryption Specification | Status | Risk | Recommendation |
|-----------|-------------------|--------------------------|--------|------|----------------|
| PostgreSQL | CC6.1: Logical and physical access controls | Not specified | **Non-compliant** | **Critical** | Document encryption at rest specification and key access controls in CC6.7 control narrative. |
| Data in Transit (API to DB, API to Redis, API to Elasticsearch) | CC6.7: Transmission of data protection | HTTPS mentioned but internal traffic not specified | **Partial** | **High** | Enforce TLS 1.3 for all internal service communication. Document cipher suites and certificate management. |
| Encryption Key Management | CC6.1 & CC6.7: Cryptographic key management | Not specified | **Non-compliant** | **Critical** | Document AWS KMS key access policies, rotation schedule (annual), and audit logging of key usage. |
| Audit Logs | CC7.2: Monitoring and logging | No encryption specified for logs | **Non-compliant** | **High** | Encrypt CloudWatch logs at rest. Document log retention (1 year minimum for SOC 2). |

**Why This Is Dangerous**:
- GDPR Article 32(1)(a) explicitly requires "encryption of personal data" as a technical measure to ensure security
- SOC 2 CC6.7 requires documented encryption controls for data protection
- Absence of encryption makes data breach impact catastrophic (unencrypted customer data, email credentials)
- Regulatory penalties: GDPR fines up to €20M or 4% of global revenue, SOC 2 audit failure

**Impact**:
- Non-compliance with GDPR and SOC 2 requirements
- Audit failure and inability to obtain SOC 2 certification
- Potential GDPR fines and regulatory action
- Unencrypted sensitive data (passwords, OAuth tokens, customer PII) vulnerable in breach scenarios
- No documented key management practices

**Recommendation**:
1. **Database encryption (PostgreSQL)**: Enable AWS RDS encryption at rest with AWS KMS CMK. Specify key rotation schedule (annual).
2. **Cache encryption (Redis)**: Enable Redis encryption at rest and TLS in-transit encryption.
3. **Search encryption (Elasticsearch)**: Enable AWS OpenSearch encryption at rest and node-to-node encryption.
4. **Object storage encryption (S3)**: Enable S3 default encryption with SSE-KMS. Enforce encryption for all uploads via bucket policy.
5. **Application-level encryption**: Encrypt OAuth tokens (email_credentials.access_token, refresh_token) using AES-256-GCM with AWS KMS per-tenant data keys.
6. **Backup encryption**: Verify PostgreSQL automated snapshots inherit RDS encryption. Document backup encryption in compliance documentation.
7. **Log encryption**: Enable CloudWatch Logs encryption at rest.
8. **Document key management policy**: Key access controls, rotation schedule, audit logging, separation of duties.
9. **TLS specifications**: Document TLS 1.3 requirement, cipher suites (ECDHE-RSA-AES256-GCM-SHA384 minimum), certificate management.

**References**: Lines 41-44, 143-146, 281-283, 298-299

---

### 3. Public-Read ACL on S3 Files Exposes Sensitive Attachments

**Severity**: Critical
**Criterion**: Data Protection
**Section**: 3. Key Components - File Upload Service, 5. API Design

**Issue Description**:
Line 236 explicitly states "Files stored in S3 with public-read ACL." This means **all uploaded files are publicly accessible** to anyone with the S3 URL, including:
- Customer contracts and financial documents
- Personal identification documents
- Internal sales notes and strategy documents
- Email attachments synced from Gmail/Outlook

**Why This Is Dangerous**:
- No access control on file storage violates multi-tenant data isolation
- Public S3 URLs can be guessed or enumerated (tenant-prefixed keys, line 96)
- Shared URLs remain accessible indefinitely (no expiration)
- GDPR Article 32 requires "measures to ensure ongoing confidentiality" - public files violate this
- SOC 2 CC6.1 requires logical access controls - public ACL bypasses all application-level authorization

**Impact**:
- Unauthorized access to sensitive customer documents
- Data breach exposure (customer PII, financial data)
- GDPR Article 32 violation (failure to ensure confidentiality)
- Complete bypass of tenant isolation and user permissions
- Potential competitive intelligence leakage

**Recommendation**:
1. **IMMEDIATELY remove public-read ACL**: Configure S3 bucket with Block Public Access enabled
2. **Implement pre-signed URLs**: Generate time-limited pre-signed URLs (15-minute expiration) for file downloads
3. **Authorization check before URL generation**: Verify user has permission to access file (tenant match + ownership/role check)
4. **S3 bucket policy**: Deny all public access, restrict to application IAM role only
5. **Audit existing files**: Identify and remediate any currently public files
6. **Document access control policy**: Specify who can access files (owner, admins, tenant members with permission)

**References**: Lines 96, 236

---

### 4. Missing Rate Limiting Enables Brute-Force and DoS Attacks

**Severity**: Critical
**Criterion**: Threat Modeling (STRIDE) - Denial of Service / Elevation of Privilege
**Section**: 5. API Design

**Issue Description**:
The design document **does not specify any rate limiting** for API endpoints, despite mentioning Redis for "rate limiting" in the infrastructure (line 42). Critical endpoints have no protection:
- `/api/auth/login` - brute-force password attacks (line 172)
- `/api/auth/password-reset` - email bombing, account enumeration (line 188)
- `/api/webhooks` - webhook endpoint abuse (line 226)
- `/api/files/upload` - resource exhaustion (10MB per file, line 96)

Redis is mentioned for "rate limiting" but no implementation details are provided.

**Why This Is Dangerous**:
- Brute-force attacks can compromise accounts (especially with no MFA requirement)
- Password reset abuse allows email bombing and account enumeration (reveals valid email addresses)
- Webhook creation abuse can exhaust background worker resources
- File upload abuse (50MB per request, line 96) can exhaust storage and bandwidth
- No mention of rate limits at ALB or API layer

**Impact**:
- Account compromise via brute-force (no failed login lockout)
- Service disruption via resource exhaustion (DoS)
- Cost impact (excessive S3 storage, outbound bandwidth)
- Email provider blacklisting (password reset abuse)
- Webhook endpoint DDoS (customer endpoints flooded)

**Recommendation**:
1. **Authentication rate limits**:
   - `/api/auth/login`: 5 attempts per 15 minutes per IP, 10 attempts per hour per email
   - Account lockout: 10 failed attempts = 1 hour lockout
   - `/api/auth/password-reset`: 3 requests per hour per IP, 1 request per 5 minutes per email
2. **API rate limits**:
   - Authenticated users: 1000 requests per hour (sliding window)
   - Unauthenticated: 100 requests per hour per IP
   - Premium tier: 5000 requests per hour
3. **Endpoint-specific limits**:
   - `/api/webhooks`: 10 creations per tenant per day
   - `/api/files/upload`: 20 uploads per hour per user, 100MB total per hour per tenant
   - `/api/contacts`, `/api/deals` POST: 100 creations per hour per user
4. **Infrastructure rate limiting**:
   - Configure ALB rate-based rules (1000 req/5min per IP)
   - Implement Redis-based sliding window counters
   - Return HTTP 429 with Retry-After header
5. **Monitoring**: Alert on rate limit violations (potential attack indicators)

**References**: Lines 42, 172-201, 226-232, 236

---

### 5. No Access Control for Deal Modification and Deletion

**Severity**: Critical
**Criterion**: Authentication & Authorization Design
**Section**: 5. API Design - Key Endpoints

**Issue Description**:
Lines 220 and 224 explicitly state:
- "PUT /api/deals/:id - No ownership verification - any user in the tenant can update any deal"
- "DELETE /api/deals/:id - No ownership verification - any user in the tenant can delete any deal"

This means **any sales representative can modify or delete deals they don't own**, including:
- Changing deal amounts and close dates
- Transferring deals to themselves (changing owner_id)
- Deleting competitors' deals to manipulate pipeline reports
- Tampering with historical records

**Why This Is Dangerous**:
- Violates principle of least privilege (users should only modify their own deals or those explicitly shared)
- No audit trail to detect malicious modifications (logging mentioned but not deal changes)
- Enables insider threats (disgruntled employees, competitive sabotage)
- STRIDE threat: **Tampering** (unauthorized data modification) and **Repudiation** (no accountability)
- SOC 2 CC6.1 violation (lack of logical access restrictions)

**Impact**:
- Data integrity compromise (pipeline reports inaccurate)
- Financial fraud (inflating deal values, manipulating commissions)
- Insider threats (sabotage, competitive intelligence)
- Loss of data accountability (no ownership enforcement)
- Audit trail gaps (who actually modified what?)

**Recommendation**:
1. **Implement role-based access control (RBAC)**:
   - **Sales Reps**: Can only update/delete own deals (owner_id = current user)
   - **Sales Managers**: Can update/delete deals owned by team members
   - **Admins**: Can update/delete any deal within tenant
2. **Authorization middleware**:
   ```typescript
   // Before deal update/delete
   if (user.role === 'user' && deal.owner_id !== user.id) {
     throw new ForbiddenError('Can only modify own deals');
   }
   ```
3. **Audit logging**: Log all deal modifications with before/after values (deal_audit_log table)
4. **Document authorization model**: Create a permission matrix (user role × resource × action)
5. **Extend to other resources**: Apply same RBAC to contacts, companies, webhooks

**References**: Lines 220, 224, 128-137

---

### 6. Missing Infrastructure Encryption and Security Controls

**Severity**: Critical
**Criterion**: Infrastructure & Dependency Security
**Section**: 2. Technology Stack - Database, Infrastructure

**Issue Description**:
The design mentions multiple infrastructure components but **does not specify security controls** for most of them. Only "HTTPS enforced" is mentioned (line 281).

#### Infrastructure Security Assessment

| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| **PostgreSQL 15** | Access Control | Unspecified | **Critical** | Specify database authentication (IAM auth preferred). Document least-privilege access policy. |
| | Encryption (at rest) | **Missing** | **Critical** | Enable AWS RDS encryption at rest with KMS. Document key management. |
| | Encryption (in transit) | Unspecified | **Critical** | Enforce SSL/TLS connections. Specify require_ssl parameter. |
| | Network Isolation | Partial (implied VPC) | **High** | Document VPC private subnets, security group rules (no public access). |
| | Authentication | Unspecified | **Critical** | Use IAM database authentication. Rotate credentials every 90 days. |
| | Monitoring/Logging | Partial (CloudWatch mentioned) | **Medium** | Enable RDS Enhanced Monitoring, Performance Insights, query logging. |
| | Backup/Recovery | Partial (daily snapshots) | **Medium** | Document RPO/RTO targets. Specify cross-region backup replication for DR. |
| **Redis 7.0** | Access Control | **Missing** | **Critical** | Enable Redis AUTH. Use strong password (32+ characters). Restrict to application security group. |
| | Encryption (at rest) | **Missing** | **Critical** | Enable ElastiCache encryption at rest (AES-256). |
| | Encryption (in transit) | **Missing** | **Critical** | Enable in-transit encryption (TLS). Enforce encrypted connections only. |
| | Network Isolation | Unspecified | **Critical** | Document VPC placement, security group rules (deny external access). |
| | Authentication | **Missing** | **Critical** | Enable AUTH. Store password in AWS Secrets Manager. |
| | Monitoring/Logging | Unspecified | **Medium** | Enable CloudWatch metrics for memory, CPU, connection count. |
| | Backup/Recovery | **Missing** | **High** | Enable automatic backups. Single-node (line 289) = no HA, document RTO. |
| **Elasticsearch 8.7** | Access Control | **Missing** | **Critical** | Enable fine-grained access control. Use IAM roles for service authentication. |
| | Encryption (at rest) | **Missing** | **Critical** | Enable encryption at rest for AWS OpenSearch. |
| | Encryption (in transit) | **Missing** | **Critical** | Enable node-to-node encryption. Enforce HTTPS-only. |
| | Network Isolation | Unspecified | **Critical** | Document VPC placement, security group rules (no public access). |
| | Authentication | **Missing** | **Critical** | Enable fine-grained access control with IAM roles. Disable anonymous access. |
| | Monitoring/Logging | Unspecified | **Medium** | Enable audit logging. Monitor search query patterns for abuse. |
| | Backup/Recovery | Unspecified | **High** | Enable automated snapshots. Document restore procedures. |
| **AWS S3** | Access Control | **Critical Issue** | **Critical** | Remove public-read ACL (line 236). Enable Block Public Access. Use IAM roles only. |
| | Encryption (at rest) | **Missing** | **Critical** | Enable S3 default encryption (SSE-KMS). Enforce via bucket policy. |
| | Encryption (in transit) | Partial (HTTPS) | **Medium** | Enforce HTTPS-only via bucket policy (deny non-TLS requests). |
| | Network Isolation | N/A (managed service) | Low | Use VPC endpoint for S3 access (avoid internet gateway). |
| | Authentication | Partial | **High** | Document IAM role policies. Use least-privilege access (no s3:* wildcards). |
| | Monitoring/Logging | Unspecified | **High** | Enable S3 access logging. Enable CloudTrail for data events. Monitor for suspicious access. |
| | Backup/Recovery | Unspecified | **High** | Enable S3 versioning. Document retention policy (comply with GDPR deletion). |
| **ALB (Application Load Balancer)** | Access Control | Unspecified | **Medium** | Document security group rules. Restrict source IPs if applicable. |
| | Encryption (in transit) | Partial (HTTPS) | **Medium** | Specify TLS 1.3, cipher suites, certificate management (ACM). |
| | Network Isolation | Unspecified | **Medium** | Document public vs. internal subnets. Consider WAF attachment. |
| | Authentication | N/A | Low | |
| | Monitoring/Logging | Unspecified | **Medium** | Enable ALB access logs to S3. Monitor 4xx/5xx rates. |
| | Backup/Recovery | N/A | Low | |
| **ECS Fargate** | Access Control | Unspecified | **High** | Document IAM task roles (least privilege). Restrict task execution role permissions. |
| | Encryption (at rest) | Unspecified | **Medium** | Enable ECS task volume encryption. |
| | Encryption (in transit) | Partial | **Medium** | Document service-to-service TLS (ECS to RDS, Redis, ES). |
| | Network Isolation | Unspecified | **High** | Document task security groups, private subnets, no public IPs. |
| | Authentication | Unspecified | **High** | Use IAM roles for AWS service access (no hardcoded credentials). |
| | Monitoring/Logging | Partial (CloudWatch) | **Medium** | Enable Container Insights. Log application output to CloudWatch Logs. |
| | Backup/Recovery | N/A | Low | Document container image backup/scanning policy. |
| **AWS Secrets Manager / Parameter Store** | Access Control | **Not Mentioned** | **Critical** | **CRITICAL**: Design does not mention secret management service. Document use of AWS Secrets Manager for DB credentials, API keys, OAuth secrets. |
| | Encryption (at rest) | **Not Mentioned** | **Critical** | Secrets Manager encrypts by default. Document KMS key usage. |
| | Encryption (in transit) | **Not Mentioned** | **Medium** | Use AWS SDK with TLS for secret retrieval. |
| | Network Isolation | N/A | Low | |
| | Authentication | **Not Mentioned** | **Critical** | Document IAM policies for secret access (least privilege per service). |
| | Monitoring/Logging | **Not Mentioned** | **High** | Enable CloudTrail for secret access audit. Alert on unauthorized access attempts. |
| | Backup/Recovery | **Not Mentioned** | **Medium** | Secrets Manager automatic rotation. Document rotation schedule (90 days). |

**Why This Is Dangerous**:
- No defense-in-depth: If application authentication is bypassed, infrastructure is unprotected
- GDPR/SOC 2 compliance requires documented infrastructure security controls
- Unencrypted inter-service communication exposes data in transit (ECS to RDS, Redis, Elasticsearch)
- Missing AWS Secrets Manager = hardcoded credentials in environment variables (line 269) or code

**Impact**:
- Infrastructure compromise (database, cache, search engine all lack authentication)
- Data exfiltration (no encryption in transit between services)
- Credential exposure (environment variables logged, visible in ECS console)
- Non-compliance with GDPR Article 32 and SOC 2 CC6.1/CC6.7

**Recommendation**:
See detailed recommendations in the table above. **Priority actions**:
1. Enable encryption at rest for all data stores (RDS, Redis, Elasticsearch, S3)
2. Enforce TLS for all service communication (RDS SSL, Redis TLS, ES HTTPS)
3. Implement AWS Secrets Manager for all credentials (not environment variables)
4. Enable authentication for Redis (AUTH) and Elasticsearch (fine-grained access control)
5. Document VPC architecture with private subnets and security group rules
6. Enable comprehensive logging (RDS query logs, S3 access logs, ALB logs, CloudTrail)

**References**: Lines 40-51, 269, 281-295

---

## Significant Issues (Severity 2)

### 7. No CSRF Protection for State-Changing Operations

**Severity**: Significant
**Criterion**: Threat Modeling (STRIDE) - Tampering / Elevation of Privilege
**Section**: 5. API Design, 7. Security

**Issue Description**:
The design does not mention CSRF (Cross-Site Request Forgery) protection, despite:
- Using JWT tokens (line 168) which are vulnerable to CSRF if not properly protected
- State-changing operations (POST/PUT/DELETE for contacts, deals, webhooks)
- JWT stored in localStorage (line 169) means tokens are included in JavaScript fetch() calls

While localStorage storage prevents automatic cookie inclusion (traditional CSRF vector), **attackers can still exploit**:
- XSS to read localStorage token and forge requests
- Confused deputy attacks via third-party integrations
- Webhook SSRF attacks (line 102, "customer-registered endpoints")

**Why This Is Dangerous**:
- No SameSite cookie protection (because using localStorage, not cookies)
- No CSRF token validation mentioned
- Webhook endpoints accept unauthenticated POST requests from background workers (potential SSRF)
- React XSS escaping (line 284) is insufficient if third-party libraries have vulnerabilities

**Impact**:
- Unauthorized state-changing operations (create/update/delete data)
- Webhook abuse (attacker-controlled endpoints flooded with events)
- Potential SSRF via webhook URLs (internal network scanning)

**Recommendation**:
1. **If implementing httpOnly cookies (as recommended in Issue #1)**: Add SameSite=Strict attribute and implement double-submit cookie pattern
2. **For localStorage approach (not recommended)**: Implement custom request headers (X-CSRF-Token) that CORS preflight requires
3. **Webhook SSRF prevention**:
   - Validate webhook URLs (disallow private IP ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8)
   - Implement allow-list of URL schemes (https only)
   - Set timeout (5 seconds) and max redirects (0) for webhook delivery
   - Add User-Agent header to identify webhook source
4. **Content Security Policy**: Implement CSP headers to mitigate XSS (see Issue #1)

**References**: Lines 168-169, 102-103, 226-232, 284

---

### 8. Missing Input Validation Policy and Injection Prevention

**Severity**: Significant
**Criterion**: Input Validation Design
**Section**: 5. API Design, 7. Security

**Issue Description**:
The design mentions "SQL injection prevention via parameterized queries" (line 282) but **does not specify**:
- Input validation rules for user-supplied data
- Email validation (contacts, users, password reset)
- URL validation (webhook endpoints)
- File type validation (beyond size limits, line 96)
- JSONB custom_fields validation (line 124) - arbitrary JSON accepted?
- Output encoding beyond React's "automatic escaping" (line 284)

**Why This Is Dangerous**:
- No documented validation allows developers to skip or inconsistently apply validation
- JSONB custom_fields (line 124) can store arbitrary data - potential for stored XSS, JSON injection
- Webhook URLs (line 150) need validation to prevent SSRF (see Issue #7)
- Email validation gaps can lead to email injection attacks (nodemailer, line 56)
- File upload (line 96) lacks content-type validation - can upload HTML files with XSS payloads

**Impact**:
- Stored XSS via custom_fields JSONB (rendered in React without sanitization)
- Email header injection via unvalidated email fields
- File upload XSS (upload malicious HTML, share public S3 URL)
- Database integrity issues (invalid data formats)
- SSRF via webhook URLs (see Issue #7)

**Recommendation**:
1. **Define input validation policy**:
   - Email: RFC 5322 validation + domain MX record check
   - URLs: Allow https:// only, validate domain (no private IPs)
   - Phone: E.164 format validation
   - Numeric fields: Range validation (deal.amount > 0, stage enum values)
   - Text fields: Max length enforcement (not just database VARCHAR limit)
2. **JSONB custom_fields validation**:
   - Define allowed JSON schema per custom field type
   - Recursive sanitization for nested objects
   - Reject script tags, event handlers, javascript: URLs
   - Validate before storage and before rendering
3. **File upload validation**:
   - Content-Type validation (allow-list: pdf, docx, xlsx, png, jpg only)
   - Magic byte verification (prevent MIME type spoofing)
   - Virus scanning (integrate ClamAV or AWS GuardDuty Malware Protection)
   - Filename sanitization (prevent path traversal)
4. **Output encoding**:
   - Don't rely solely on React escaping - sanitize HTML in JSONB fields with DOMPurify
   - Escape data in CSV exports (prevent Excel formula injection)
   - Sanitize data in email templates (prevent email client XSS)
5. **Error message sanitization**: Don't expose SQL errors, file paths, or stack traces to clients

**References**: Lines 56, 96, 124, 150, 282, 284

---

### 9. No Idempotency Guarantees for State-Changing Operations

**Severity**: Significant
**Criterion**: Threat Modeling (STRIDE) - Tampering
**Section**: 5. API Design - Key Endpoints

**Issue Description**:
The design does not mention idempotency mechanisms for state-changing operations:
- POST /api/contacts (line 208) - duplicate contact creation on retry
- POST /api/deals - duplicate deal creation on retry
- POST /api/webhooks (line 226) - duplicate webhook registration
- PUT /api/deals/:id (line 219) - race conditions on concurrent updates
- Webhook delivery (line 102) - duplicate event delivery on retry

**Why This Is Dangerous**:
- Network failures or client timeouts cause retries
- Users may refresh or double-click submit buttons
- Background job retries (Bull queue, line 33) can reprocess events
- No last-write-wins or optimistic locking mentioned for updates
- Financial impact: Duplicate deal creation inflates pipeline, duplicate webhook delivery triggers duplicate downstream actions

**Impact**:
- Duplicate records (contacts, deals, webhooks)
- Inconsistent state (concurrent updates overwrite each other)
- Data integrity issues (deal amount history lost)
- Customer-facing issues (duplicate webhook events trigger duplicate actions)
- Race conditions in multi-user environment

**Recommendation**:
1. **Idempotency keys for POST requests**:
   - Require X-Idempotency-Key header for POST /api/contacts, /api/deals, /api/webhooks
   - Store idempotency key + response hash in Redis (24-hour TTL)
   - Return cached response if key seen again
   - Generate idempotency keys client-side (UUID v4)
2. **Optimistic locking for PUT/DELETE**:
   - Add version or updated_at field to all entities
   - Require If-Match header with current version/timestamp
   - Return HTTP 409 Conflict if version mismatch (client must refetch and retry)
3. **Webhook delivery idempotency**:
   - Include X-Webhook-Delivery-Id header (UUID per delivery attempt)
   - Document that customers should deduplicate by this header
   - Implement webhook retry with exponential backoff (3 attempts: 1m, 5m, 15m)
4. **Database unique constraints**:
   - Add unique constraint on (tenant_id, email) for contacts/users
   - Add unique constraint on (tenant_id, url, events) for webhooks
5. **Document idempotency policy**: Specify expected behavior and client responsibilities

**References**: Lines 33, 102-103, 208-217, 219-220, 226-232

---

### 10. Missing Audit Logging and PII Masking Policy

**Severity**: Significant
**Criterion**: Threat Modeling (STRIDE) - Repudiation / Infrastructure Security
**Section**: 6. Implementation Guidelines - Logging, 7. Compliance

**Issue Description**:
The design mentions logging user actions (line 258: "User actions logged with user ID and tenant ID") but **does not specify**:
- **What events to log**: Authentication events, permission changes, data access, exports, deletions
- **PII/sensitive data masking**: Should passwords, OAuth tokens, email content be logged?
- **Audit log retention**: SOC 2 requires 1 year minimum (not mentioned)
- **Log immutability**: Can logs be tampered with or deleted?
- **GDPR Article 30 compliance**: Processing activity records

Given SOC 2 and GDPR compliance requirements (lines 298-299), the absence of comprehensive audit logging is a significant gap.

**Why This Is Dangerous**:
- No accountability for security incidents (who accessed what data?)
- Cannot detect insider threats or unauthorized access
- Cannot demonstrate compliance with SOC 2 CC7.2 (monitoring) and GDPR Article 30
- Risk of logging sensitive data (passwords, tokens) without proper protection
- CloudWatch logs not encrypted (see Issue #2)

**Impact**:
- SOC 2 audit failure (CC7.2 control gap)
- GDPR Article 30 violation (lack of processing records)
- Inability to investigate security incidents
- Insider threat detection gaps
- Potential data breach via logs (if OAuth tokens logged)

**Recommendation**:
1. **Define audit logging policy** (document in security section):
   - **Authentication events**: Login success/failure, logout, token refresh, password change, password reset
   - **Authorization events**: Permission denied (403), role changes, admin actions
   - **Data access**: Contact/deal/company view (if PII), bulk exports, API key usage
   - **Data modification**: Create/update/delete for all entities (log before/after values for deals, contacts)
   - **Configuration changes**: Webhook creation/deletion, user invitation, tenant settings
   - **Integration events**: Email sync start/complete, OAuth token refresh, webhook delivery
2. **PII/sensitive data masking policy**:
   - **NEVER log**: Passwords (plaintext or hashed), OAuth access_token/refresh_token (only log token_id), payment card numbers, SSN
   - **Mask in logs**: Email addresses (u***@example.com), phone numbers (***-***-1234), full names (first 3 chars only)
   - **Log metadata only**: For email content, log sender/recipient/subject but not body
3. **Audit log requirements**:
   - **Immutability**: Write-only CloudWatch log streams (prevent deletion via IAM policy)
   - **Retention**: 1 year minimum (SOC 2), 3 years for authentication events (GDPR Article 30)
   - **Encryption**: Enable CloudWatch Logs encryption at rest with KMS (see Issue #2)
   - **Monitoring**: Alert on critical events (admin login, bulk export, failed authentication patterns)
4. **Structured audit log format**:
   ```json
   {
     "timestamp": "2026-02-10T12:34:56Z",
     "event_type": "deal.updated",
     "actor_user_id": "uuid",
     "actor_tenant_id": "uuid",
     "actor_role": "user",
     "resource_type": "deal",
     "resource_id": "uuid",
     "action": "update",
     "changes": {"amount": {"from": 10000, "to": 15000}},
     "ip_address": "203.0.113.42",
     "user_agent": "Mozilla/5.0..."
   }
   ```
5. **GDPR Article 30 records**: Maintain processing activity records (purpose, categories, recipients, retention)

**References**: Lines 255-259, 298-299

---

### 11. Email Credentials Stored in Plain Text (OAuth Tokens)

**Severity**: Significant
**Criterion**: Data Protection
**Section**: 4. Data Model - email_credentials, 5. API Design

**Issue Description**:
The email_credentials table (lines 140-146) stores OAuth access_token and refresh_token as TEXT columns with **no encryption specified**. Line 246 shows tokens are stored directly after OAuth exchange. These tokens provide:
- Full access to user's Gmail/Outlook account
- Ability to read all emails, send emails, access contacts
- Persistent access via refresh tokens (no expiration mentioned)

**Why This Is Dangerous**:
- OAuth tokens are equivalent to passwords - full email account access
- Database breach exposes all connected email accounts (not just CRM data)
- No application-level encryption specified (only relying on database encryption at rest, which is missing - see Issue #2)
- Refresh tokens have long lifetime (typically 6 months to indefinite for Google)
- GDPR Article 32 requires "appropriate security measures" for authentication credentials

**Impact**:
- Complete email account compromise in database breach scenario
- Ability to read sensitive emails (customer communications, internal discussions)
- Ability to send emails as user (phishing, social engineering)
- Persistent access via refresh token (even after user changes password)
- GDPR Article 32 violation (inadequate protection of authentication credentials)

**Recommendation**:
1. **Application-level encryption for OAuth tokens**:
   - Encrypt access_token and refresh_token using AES-256-GCM **before** storing in database
   - Use AWS KMS with per-tenant data encryption keys (DEK)
   - Store only encrypted ciphertext in database TEXT columns
   - Decrypt only when needed for email sync (in-memory, never log decrypted tokens)
2. **Key management**:
   - Generate per-tenant DEK using AWS KMS GenerateDataKey
   - Store encrypted DEK in database (encrypted_dek column)
   - Decrypt DEK using KMS, then use DEK to decrypt OAuth tokens
   - Rotate DEKs annually
3. **Token rotation**:
   - Implement automatic refresh token rotation (exchange old refresh token for new one)
   - Revoke old refresh tokens after rotation
   - Monitor for token refresh failures (indicates revoked token)
4. **Access controls**:
   - Restrict database access to token columns (separate DB role with column-level permissions)
   - Audit all access to email_credentials table (CloudTrail + RDS query logging)
5. **Document encryption specification**: Update data model to show encrypted columns

**References**: Lines 98-100, 140-146, 239-246

---

### 12. Single-Node Redis and Missing High Availability

**Severity**: Significant
**Criterion**: Infrastructure & Dependency Security / Availability
**Section**: 7. Non-functional Requirements - Availability

**Issue Description**:
Line 289 states "Redis: Single-node deployment (non-clustered)" for a system with:
- Session storage (authentication state)
- Rate limiting counters (critical for security)
- Task queue (background jobs)
- Cache (performance-critical)

A single Redis node is a **single point of failure** for critical system functions.

**Why This Is Dangerous**:
- Redis failure = all users logged out (sessions lost)
- Redis failure = rate limiting disabled (security exposure)
- Redis failure = background jobs halted (email sync, webhook delivery)
- No automatic failover (manual recovery required)
- 99.9% uptime target (line 286) requires redundancy - single node cannot meet this

**Impact**:
- Service disruption (authentication failure, no rate limiting)
- Security exposure (rate limiting disabled during outage)
- Data loss (Bull queue jobs lost if not persisted)
- Violates 99.9% uptime SLA (single node doesn't provide HA)
- Long recovery time (manual intervention required)

**Recommendation**:
1. **Upgrade to Redis Cluster or ElastiCache with Auto-Failover**:
   - Use AWS ElastiCache for Redis with Multi-AZ enabled
   - 3-node cluster (1 primary, 2 replicas)
   - Automatic failover in 30-60 seconds
2. **Session persistence**:
   - Enable Redis persistence (RDB snapshots every 5 minutes + AOF log)
   - Or use database-backed sessions for critical data (fallback)
3. **Bull queue durability**:
   - Configure Bull with Redis persistence
   - Implement job status tracking in PostgreSQL (separate from queue)
   - Monitor queue depth and alert on backup
4. **Rate limiting fallback**:
   - If Redis unavailable, fail open with conservative default limits (100 req/hour)
   - Or fail closed for authentication endpoints (deny requests)
5. **Document RTO/RPO**: Specify recovery time objective (RTO: 1 minute) and recovery point objective (RPO: 5 minutes)

**References**: Lines 42, 90-94, 289

---

### 13. No Password Complexity or Rotation Policy

**Severity**: Significant
**Criterion**: Authentication & Authorization Design
**Section**: 4. Data Model - users, 7. Security

**Issue Description**:
The design specifies bcrypt password hashing (line 281: "10 rounds") but **does not specify**:
- Minimum password complexity (length, character requirements)
- Password rotation/expiration policy
- Password history (prevent reuse of last N passwords)
- Weak password detection (common passwords, dictionary words)

**Why This Is Dangerous**:
- Bcrypt protects stored passwords but doesn't prevent weak passwords
- Users may choose easily guessable passwords (password123, company name + year)
- No password rotation = compromised passwords remain valid indefinitely
- No password history = users rotate back to old compromised passwords
- SOC 2 CC6.1 and NIST 800-63B require password complexity controls

**Impact**:
- Account compromise via weak passwords
- Brute-force attacks succeed despite bcrypt (weak password space)
- Compromised passwords remain valid indefinitely
- SOC 2 audit gap (CC6.1 access control requirements)

**Recommendation**:
1. **Password complexity requirements** (NIST 800-63B compliant):
   - Minimum length: 12 characters (recommended: 15+)
   - No complexity requirements (research shows length > complexity)
   - Check against compromised password database (Have I Been Pwned API or similar)
   - Reject passwords containing user email or account name
   - Reject common passwords (top 10,000 most common)
2. **Password rotation policy** (balance security and usability):
   - Optional password expiration (90 days) for admin roles only
   - Force password change if breach detected (monitor HIBP notifications)
   - Do NOT force regular rotation for normal users (NIST 800-63B guidance)
3. **Password history**:
   - Store hash of last 5 passwords (password_history table)
   - Prevent reuse of last 5 passwords
4. **Multi-factor authentication (MFA)**:
   - **CRITICAL ADDITION**: Require MFA for admin accounts (TOTP via Authenticator app)
   - Offer optional MFA for all users
   - Reduces reliance on password strength alone
5. **Breach notification**: Monitor for credential stuffing attacks (failed logins with correct email)

**References**: Lines 112, 281

---

### 14. Missing Security Headers and Content Security Policy

**Severity**: Significant
**Criterion**: Threat Modeling (STRIDE) - Tampering / Information Disclosure
**Section**: 3. Frontend, 7. Security

**Issue Description**:
The design mentions "React's automatic escaping" for XSS prevention (line 284) but does **not specify security headers** for defense-in-depth:
- Content Security Policy (CSP)
- X-Frame-Options (clickjacking protection)
- X-Content-Type-Options (MIME sniffing protection)
- Strict-Transport-Security (HSTS)
- Referrer-Policy
- Permissions-Policy

**Why This Is Dangerous**:
- React XSS escaping is not foolproof (dangerouslySetInnerHTML, third-party libraries, JSONB custom_fields)
- No clickjacking protection = attacker can embed app in iframe and trick users
- No CSP = inline scripts and eval() allowed (XSS amplification)
- No HSTS = users vulnerable to SSL stripping attacks
- Material-UI (line 38) has had XSS vulnerabilities in the past

**Impact**:
- XSS attacks (stored XSS via custom_fields, third-party library vulnerabilities)
- Clickjacking (attacker embeds CRM in iframe, tricks user into changing settings)
- MIME sniffing attacks (browser executes uploaded files as JavaScript)
- Man-in-the-middle attacks (SSL stripping without HSTS)

**Recommendation**:
1. **Implement Content Security Policy** (via ALB response headers or Express middleware):
   ```
   Content-Security-Policy:
     default-src 'self';
     script-src 'self' 'unsafe-inline' https://cdn.example.com;
     style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
     img-src 'self' data: https://s3.amazonaws.com;
     connect-src 'self' https://api.salespulse.com;
     frame-ancestors 'none';
     base-uri 'self';
     form-action 'self';
   ```
   - Start with report-only mode to identify violations
   - Remove 'unsafe-inline' if possible (refactor inline styles/scripts)
2. **Other security headers**:
   ```
   X-Frame-Options: DENY
   X-Content-Type-Options: nosniff
   Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
   Referrer-Policy: strict-origin-when-cross-origin
   Permissions-Policy: geolocation=(), microphone=(), camera=()
   ```
3. **Configure headers at ALB level**:
   - Use ALB response header modification rules
   - Or implement Express middleware (helmet.js)
4. **Test CSP compliance**: Use browser developer tools and CSP Evaluator tool
5. **Monitor CSP violations**: Configure report-uri to collect violation reports

**References**: Lines 38, 124, 284

---

## Moderate Issues (Severity 3)

### 15. Webhook Secret Generation and Rotation Not Specified

**Severity**: Moderate
**Criterion**: Data Protection / Integration Security
**Section**: 4. Data Model - webhooks, 5. API Design

**Issue Description**:
The webhooks table includes a secret field for HMAC signatures (line 152), and the API response shows "generated secret" (line 233), but the design **does not specify**:
- Secret generation method (length, randomness source)
- HMAC algorithm (SHA-256, SHA-512?)
- Secret rotation mechanism (how to update secret without breaking customer integrations)
- Secret storage (encrypted or plaintext?)

**Why This Is Dangerous**:
- Weak secret generation = attackers can guess or brute-force HMAC signatures
- No rotation = compromised secrets remain valid indefinitely
- If stored in plaintext, database breach exposes all webhook secrets
- Customers cannot verify webhook authenticity without strong HMAC

**Impact**:
- Webhook spoofing (attacker sends fake webhook events to customer endpoints)
- Replay attacks (attacker captures and replays legitimate webhooks)
- If webhook secret compromised, attacker can impersonate SalesPulse

**Recommendation**:
1. **Secret generation**:
   - Generate 32-byte random secret using crypto.randomBytes (Node.js)
   - Encode as base64 or hex (64 characters)
   - Use cryptographically secure random number generator (not Math.random)
2. **HMAC algorithm**:
   - Use HMAC-SHA256 (balance of security and compatibility)
   - Include webhook delivery ID in HMAC payload (prevent replay)
   - Format: `HMAC-SHA256(secret, timestamp + delivery_id + body)`
3. **Webhook delivery headers**:
   ```
   X-Webhook-Signature: sha256=<hmac>
   X-Webhook-Timestamp: <unix_timestamp>
   X-Webhook-Delivery-Id: <uuid>
   ```
4. **Secret rotation**:
   - Support two secrets simultaneously (old + new) during rotation period
   - API endpoint: POST /api/webhooks/:id/rotate-secret (returns new secret, old remains valid for 7 days)
   - After 7 days, old secret invalidated
5. **Secret storage**:
   - Encrypt webhook secrets using same application-level encryption as OAuth tokens (see Issue #11)
   - Store only encrypted ciphertext in database
6. **Documentation**: Provide webhook verification code examples for customers (Node.js, Python, Ruby)

**References**: Lines 149-154, 226-233

---

### 16. No Secrets Management Service Specified

**Severity**: Moderate
**Criterion**: Infrastructure & Dependency Security
**Section**: 6. Implementation Guidelines - Deployment

**Issue Description**:
Line 269 states "Environment variables for configuration (DB credentials, API keys)" but **does not specify** a secrets management service. Environment variables are:
- Visible in ECS task definition (AWS console, CLI)
- Logged in ECS task logs (if debugging)
- Accessible to anyone with ECS task read permissions
- Not rotated (require task redeployment to update)

**Why This Is Dangerous**:
- Environment variables are not designed for secrets (visible in many places)
- IAM permissions for ECS describe-tasks exposes all environment variables
- No audit trail for secret access (who read database password?)
- No automatic rotation (credentials become stale)
- Docker image layers may contain environment variables if built with secrets

**Impact**:
- Credential exposure (database password, API keys, JWT signing key)
- No secret rotation = long-lived credentials
- Insider threat (anyone with ECS access can read secrets)
- Audit trail gaps (cannot detect secret access)

**Recommendation**:
1. **Implement AWS Secrets Manager for all secrets**:
   - Database credentials (PostgreSQL, Redis, Elasticsearch)
   - JWT signing key (HS256 secret or RS256 private key)
   - OAuth client secrets (Gmail, Outlook)
   - Third-party API keys (DataDog, email provider)
   - Encryption keys (stored in AWS KMS, not Secrets Manager)
2. **Secrets retrieval at runtime**:
   - Use AWS SDK to retrieve secrets on application startup
   - Store in memory only (never write to disk or logs)
   - Refresh secrets periodically (every 6 hours) to support rotation
3. **Secret rotation**:
   - Enable automatic rotation for database credentials (AWS Secrets Manager Lambda rotation)
   - Rotate JWT signing key annually (or immediately if compromised)
   - Document rotation procedures
4. **IAM permissions**:
   - Grant secretsmanager:GetSecretValue only to ECS task role (least privilege)
   - Use resource-based policies to restrict which secrets each task can access
   - Enable CloudTrail logging for secret access (audit trail)
5. **Remove secrets from environment variables**: Replace with Secrets Manager ARN references only

**References**: Lines 269

---

### 17. No Tenant Data Isolation Testing Strategy

**Severity**: Moderate
**Criterion**: Threat Modeling (STRIDE) - Information Disclosure / Elevation of Privilege
**Section**: 3. Architecture Design - Multi-tenancy Model, 6. Testing

**Issue Description**:
The design specifies schema-per-tenant model (line 72) with "application-level enforcement via tenant context middleware" (line 74), but the testing section (lines 260-264) **does not mention tenant isolation testing**.

**Why This Is Dangerous**:
- Application-level enforcement is error-prone (one missing middleware = data leak)
- No mention of automated tests to verify tenant isolation
- Risk of cross-tenant data access via:
  - Missing tenant_id filter in queries
  - Direct table access bypassing middleware
  - Elasticsearch queries missing tenant filter
  - S3 key enumeration (tenant-prefixed but public-read, see Issue #3)

**Impact**:
- Cross-tenant data leakage (Customer A sees Customer B's data)
- Most severe impact for multi-tenant SaaS (trust violation)
- GDPR Article 32 violation (failure to ensure confidentiality)
- Reputational damage and customer churn

**Recommendation**:
1. **Tenant isolation integration tests**:
   - Create two test tenants with identical data
   - Authenticate as Tenant A, attempt to access Tenant B's data
   - Assert HTTP 404 (not 403, to prevent tenant enumeration)
   - Test all API endpoints (GET, POST, PUT, DELETE)
2. **Automated tenant boundary tests**:
   - Test Elasticsearch queries (verify tenant_id filter always applied)
   - Test direct database access (verify all queries include SET search_path = tenant_schema)
   - Test S3 access (verify tenant prefix in keys, verify no enumeration)
3. **Negative testing**:
   - Test API with manipulated tenant context (forged subdomain, tampered JWT)
   - Test API with missing tenant context (should fail)
4. **Penetration testing**:
   - Include tenant isolation testing in annual penetration test scope
   - Test for Insecure Direct Object Reference (IDOR) across tenants
5. **Code review checklist**: Require tenant isolation verification in all code reviews

**References**: Lines 72-74, 260-264

---

### 18. No Backup Encryption or Retention Policy for GDPR

**Severity**: Moderate
**Criterion**: Data Protection / Compliance
**Section**: 7. Availability, 7. Compliance

**Issue Description**:
Line 288 mentions "Database backups: Daily automated snapshots" but **does not specify**:
- Backup encryption (are snapshots encrypted?)
- Backup retention period (how long are backups kept?)
- Backup access controls (who can restore from backups?)
- Cross-region backup replication (disaster recovery)
- GDPR right to erasure compliance (how to delete data from backups?)

**Why This Is Dangerous**:
- Unencrypted backups = data breach exposure even if production database is encrypted
- Indefinite retention = GDPR violation (Article 5(1)(e): storage limitation)
- No documented policy = compliance audit failure
- GDPR right to erasure (Article 17) requires data deletion from backups (or pseudonymization)

**Impact**:
- GDPR Article 5(1)(e) violation (excessive data retention)
- GDPR Article 17 violation (inability to honor deletion requests)
- Backup breach = exposure of historical data (potentially years of customer data)
- SOC 2 audit gap (CC6.1: lack of documented backup security controls)

**Recommendation**:
1. **Backup encryption**:
   - Verify PostgreSQL automated snapshots inherit RDS encryption (if enabled, see Issue #2)
   - Enable S3 bucket encryption for manually uploaded backups
   - Document backup encryption in security policy
2. **Backup retention policy**:
   - Daily backups: Retain for 30 days (meets RPO/RTO targets)
   - Monthly backups: Retain for 1 year (financial compliance)
   - Annual backups: Retain for 7 years (if required by industry regulations)
   - After retention period, permanently delete backups
3. **GDPR right to erasure compliance**:
   - Option 1: Exclude deleted data from future backups (mark as deleted, don't delete immediately)
   - Option 2: Pseudonymize deleted data in backups (replace PII with random values)
   - Option 3: Document backup retention in GDPR transparency disclosures (users accept 30-day backup retention)
   - Implement "delete after backup expiration" workflow (user deletion request + 30-day wait)
4. **Backup access controls**:
   - Restrict RDS snapshot restore to ops team only (IAM policy)
   - Log all snapshot access (CloudTrail)
   - Require MFA for snapshot restoration (break-glass procedure)
5. **Cross-region replication**:
   - Replicate snapshots to secondary AWS region (us-west-2 if primary is us-east-1)
   - Enables disaster recovery (entire region failure)
   - Document RTO/RPO targets (RTO: 4 hours, RPO: 24 hours)

**References**: Lines 288, 298-299

---

### 19. Missing API Versioning and Deprecation Policy

**Severity**: Moderate
**Criterion**: Availability / API Security
**Section**: 5. API Design

**Issue Description**:
The design shows RESTful API endpoints (lines 171-246) but **does not specify**:
- API versioning strategy (URL path, header, query parameter)
- Deprecation policy (how to sunset old API versions)
- Backward compatibility guarantees
- Version-specific rate limits or access controls

**Why This Is Dangerous**:
- No versioning = breaking changes affect all clients simultaneously
- Cannot gradually migrate customers to new API version
- Security fixes in new version don't reach old API users
- Cannot deprecate insecure endpoints (e.g., if switching from localStorage to cookies)

**Impact**:
- Service disruption (breaking changes break customer integrations)
- Security vulnerability persistence (cannot force migration from vulnerable API version)
- Customer trust loss (unpredictable API changes)

**Recommendation**:
1. **API versioning strategy**:
   - Use URL path versioning: `/api/v1/contacts`, `/api/v2/contacts`
   - Major version = breaking changes (response schema change, authentication change)
   - Minor version = backward-compatible additions (new fields, new endpoints)
2. **Deprecation policy**:
   - Support current + previous version (e.g., v2 + v1)
   - Deprecation timeline: 6 months notice before sunset
   - Include deprecation headers: `Deprecation: true`, `Sunset: 2026-12-31`
   - Email notifications to customers using deprecated API
3. **Version-specific security controls**:
   - Apply security fixes to all supported versions
   - If security fix requires breaking change, force migration (shorter deprecation)
4. **Backward compatibility guidelines**:
   - Additive changes only (new fields optional, old fields retained)
   - Never change field types or required status
   - Never remove endpoints without deprecation
5. **Document versioning policy**: Publish API changelog and versioning policy in developer documentation

**References**: Lines 171-246

---

### 20. No Monitoring for Security Events

**Severity**: Moderate
**Criterion**: Infrastructure & Dependency Security / Threat Modeling
**Section**: 2. Infrastructure - Monitoring, 6. Logging

**Issue Description**:
The design mentions CloudWatch and DataDog for monitoring (line 51) and logging (line 256) but **does not specify**:
- Security event monitoring (failed authentication, authorization failures, unusual access patterns)
- Alerting thresholds (when to alert on-call engineer)
- Incident response procedures (what to do when alert fires)
- Security metrics (failed login rate, 403 responses, rate limit violations)

**Why This Is Dangerous**:
- Cannot detect ongoing attacks (brute-force, data exfiltration)
- Delayed incident response (no real-time alerting)
- No visibility into security control effectiveness (is rate limiting working?)
- SOC 2 CC7.2 requires monitoring of security-relevant events

**Impact**:
- Delayed breach detection (attacks go unnoticed)
- Inability to respond to active attacks
- SOC 2 audit gap (CC7.2: monitoring control missing)
- Compliance violation (PCI-DSS 10.6 requires daily log review)

**Recommendation**:
1. **Security event monitoring** (CloudWatch Alarms + DataDog):
   - Failed authentication rate: Alert if >10 failures/minute per IP or >50/minute globally
   - Authorization failures (403): Alert if >100/hour (indicates permission misconfiguration or attack)
   - Rate limit violations (429): Alert if >1000/hour (indicates DoS attempt or misconfigured client)
   - Unusual data access: Alert on bulk exports, large query result sets (>10k records)
   - Database connection failures: Alert if >10 failures/minute (credential issue or attack)
2. **Infrastructure security metrics**:
   - ALB 5xx errors: Alert if error rate >1% of traffic
   - ECS task failures: Alert if >5 tasks fail in 5 minutes
   - S3 access denied errors: Alert if >100/hour (indicates unauthorized access attempts)
3. **Alerting configuration**:
   - Critical alerts: Page on-call engineer (PagerDuty, Opsgenie)
   - Warning alerts: Create ticket for investigation (Jira, ServiceNow)
   - Info alerts: Log for weekly review
4. **Incident response runbooks**:
   - Document response procedures for each alert type
   - Include escalation path, investigation steps, remediation actions
   - Test runbooks quarterly (tabletop exercises)
5. **Security dashboard**: Create DataDog dashboard with key security metrics (failed logins, 403s, rate limits, etc.)

**References**: Lines 51, 255-259

---

## Positive Security Aspects

Despite the identified issues, the design document demonstrates some security-conscious decisions:

1. **Bcrypt password hashing**: Uses bcrypt with 10 rounds (line 281), which is appropriate for password storage (though complexity requirements are missing)
2. **HTTPS enforcement**: All traffic uses HTTPS (line 281), protecting data in transit at the edge
3. **Parameterized queries**: SQL injection prevention via parameterized queries (line 282)
4. **JWT with role information**: Token payload includes role for authorization (line 168)
5. **Multi-tenancy isolation**: Schema-per-tenant provides database-level isolation (line 72), better than table-level multi-tenancy
6. **File size limits**: Upload limits (10MB per file, 50MB per request) prevent some DoS attacks (line 96)
7. **OAuth2 for email integration**: Uses OAuth2 instead of storing email passwords (lines 98-100)
8. **Webhook HMAC signatures**: Includes webhook secret for signature verification (line 152)

These positive elements provide a foundation, but the critical and significant issues identified above must be addressed before production deployment.

---

## Summary of Recommendations by Priority

### Immediate (Pre-Production Blockers)
1. **Change JWT storage to httpOnly cookies** (Issue #1)
2. **Enable encryption at rest for all data stores** (Issue #2)
3. **Remove S3 public-read ACL, implement pre-signed URLs** (Issue #3)
4. **Implement rate limiting** (Issue #4)
5. **Add access control for deal modification** (Issue #5)
6. **Enable infrastructure encryption and authentication** (Issue #6)

### High Priority (Within 1 Month)
7. **Implement CSRF protection** (Issue #7)
8. **Define input validation policy** (Issue #8)
9. **Add idempotency mechanisms** (Issue #9)
10. **Implement comprehensive audit logging** (Issue #10)
11. **Encrypt OAuth tokens with application-level encryption** (Issue #11)
12. **Upgrade Redis to HA cluster** (Issue #12)

### Medium Priority (Within 3 Months)
13. **Add password complexity requirements and MFA** (Issue #13)
14. **Implement security headers and CSP** (Issue #14)
15. **Specify webhook secret generation and rotation** (Issue #15)
16. **Migrate to AWS Secrets Manager** (Issue #16)
17. **Add tenant isolation testing** (Issue #17)
18. **Document backup encryption and GDPR retention** (Issue #18)
19. **Implement API versioning** (Issue #19)
20. **Configure security event monitoring** (Issue #20)

---

## Compliance Impact Summary

### GDPR Compliance Gaps
- **Article 32(1)(a)**: Missing encryption specifications (Issue #2)
- **Article 32**: Public S3 files (Issue #3), unencrypted infrastructure (Issue #6)
- **Article 30**: Missing comprehensive audit logging (Issue #10)
- **Article 5(1)(e)**: Unspecified backup retention (Issue #18)
- **Article 17**: No documented right to erasure process for backups (Issue #18)

### SOC 2 Compliance Gaps
- **CC6.1**: Missing access controls (Issues #5, #6), missing password policy (Issue #13)
- **CC6.7**: Missing encryption specifications (Issue #2), missing key management (Issue #2)
- **CC7.2**: Missing comprehensive audit logging (Issue #10), missing security monitoring (Issue #20)

**Compliance Risk**: The design document in its current form would likely **fail both GDPR and SOC 2 audits**. Implementing recommendations in Issues #2, #5, #6, #10, #18, and #20 is critical for compliance.

---

**Review completed by**: Security Architecture Review Agent
**Review date**: 2026-02-10
**Design document version**: Round 16 Test Document
