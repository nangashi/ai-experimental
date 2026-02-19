# Security Design Review: SalesPulse CRM Platform

## Executive Summary

This security evaluation identifies **multiple critical and significant security issues** in the SalesPulse CRM design document. The most severe findings include:

1. **Critical**: JWT tokens stored in localStorage (XSS vulnerability)
2. **Critical**: S3 files configured with public-read ACL (data exposure)
3. **Critical**: Missing permission model for deal operations (authorization bypass)
4. **Critical**: OAuth tokens stored in plaintext (credential exposure)
5. **Significant**: No CSRF protection mechanism
6. **Significant**: Missing rate limiting design
7. **Significant**: No input validation policy
8. **Significant**: Missing audit logging for sensitive operations
9. **Significant**: Single-node Redis deployment (session hijacking risk)
10. **Significant**: Webhook URL validation missing (SSRF vulnerability)

**Overall Security Posture**: The design requires substantial security hardening before production deployment.

---

## Detailed Security Analysis

### 1. Threat Modeling (STRIDE) - Score: 2/5 (Significant Issue)

**Issues Identified:**

#### Spoofing Threats
- **JWT Storage in localStorage**: Tokens stored in localStorage (Line 169) are vulnerable to XSS attacks. Any injected JavaScript can steal tokens and impersonate users.
- **Missing Token Revocation**: No token revocation mechanism described. Compromised tokens remain valid for 24 hours (Line 90).
- **No Multi-Factor Authentication**: High-value sales data accessible with single-factor authentication only.

#### Tampering Threats
- **S3 Public-Read ACL**: Files uploaded with public-read ACL (Line 236) allow unauthorized access and potential tampering.
- **Missing Integrity Checks**: No mention of checksums or integrity validation for file uploads or webhook payloads.
- **No Request Signing**: Webhook deliveries lack signed payloads initially; secret only for HMAC signature (Line 152) but implementation not specified.

#### Repudiation Threats
- **Insufficient Audit Logging**: Logging mentions "user actions logged with user ID and tenant ID" (Line 259) but lacks specifics on:
  - Which actions are logged (data exports, deletions, permission changes)
  - Log immutability guarantees
  - Log retention periods
  - PII/sensitive data masking in logs
- **Missing Idempotency Guarantees**: No mention of idempotency keys for deal updates/deletions, making duplicate operations undetectable.

#### Information Disclosure Threats
- **OAuth Tokens in Plaintext**: email_credentials table stores access_token and refresh_token as TEXT (Lines 143-144) without encryption at rest.
- **Missing Encryption Specifications**: No mention of field-level encryption for sensitive data (passwords, tokens, custom fields that may contain PII).
- **Error Information Leakage**: Error handling (Lines 250-253) doesn't specify what information is exposed in error messages.
- **Search Index Security**: Elasticsearch (Line 43) contains indexed contact/deal data, but access control and encryption not specified.

#### Denial of Service Threats
- **No Rate Limiting**: Design lacks any rate limiting mechanism for authentication endpoints, file uploads, API calls, or webhook deliveries.
- **Unprotected Password Reset**: Password reset endpoint (Line 188) has no rate limiting, enabling account enumeration and DoS attacks.
- **File Upload Limits**: 10MB per file, 50MB per request (Line 96) but no mention of:
  - Total storage quota per tenant
  - Concurrent upload limits
  - File type restrictions
  - Malicious file scanning

#### Elevation of Privilege Threats
- **Missing Authorization Model**: Deal operations (Lines 219-224) explicitly state "No ownership verification - any user in the tenant can update any deal." This violates principle of least privilege.
- **Role-Based Access Control Gaps**: Users have roles (admin, manager, user) (Line 113) but no authorization matrix defining what each role can do.
- **Missing Field-Level Permissions**: No mention of which users can modify custom_fields, change deal ownership, or access specific reports.

**Impact**: High likelihood of successful attacks including account takeover, data breach, service disruption, and privilege escalation.

**Recommendations:**
1. Implement comprehensive threat model covering all STRIDE categories for each component
2. Document specific countermeasures for each identified threat
3. Create attack surface analysis for multi-tenant boundaries
4. Define incident response procedures for each threat category

---

### 2. Authentication & Authorization Design - Score: 1/5 (Critical Issue)

**Critical Issues:**

#### JWT Token Storage (Critical)
- **Location**: Line 169 states "Token Storage: Stored in browser localStorage"
- **Vulnerability**: localStorage is accessible to any JavaScript code, including malicious scripts injected via XSS
- **Impact**: Complete account takeover if XSS vulnerability exists anywhere in the React application
- **Recommendation**: **Immediately change to httpOnly + Secure cookies**
  ```
  Set-Cookie: token=<jwt>; HttpOnly; Secure; SameSite=Strict; Max-Age=86400
  ```
  This prevents JavaScript access while maintaining CSRF protection with SameSite attribute.

#### Missing Authorization Model (Critical)
- **Location**: Lines 219-224 explicitly document "No ownership verification"
- **Vulnerability**: Any user can modify/delete any deal within their tenant, regardless of ownership or role
- **Impact**: Data integrity violation, unauthorized modifications, insider threats
- **Recommendation**: Implement permission checks:
  ```
  - Read: All users in tenant
  - Update: Deal owner, managers, admins
  - Delete: Managers, admins only
  - Transfer ownership: Managers, admins only
  ```

#### OAuth Credentials in Plaintext (Critical)
- **Location**: Lines 142-144 store OAuth tokens as TEXT without encryption
- **Vulnerability**: Database compromise or backup exposure reveals all user email credentials
- **Impact**: Attackers gain full access to users' Gmail/Outlook accounts
- **Recommendation**: Encrypt at rest using AWS KMS or application-level encryption:
  - Use field-level encryption for access_token and refresh_token
  - Store encryption keys in AWS Secrets Manager
  - Rotate encryption keys quarterly

**Significant Issues:**

#### Missing Token Specifications
- **Token Expiration**: 24 hours mentioned (Line 90) but no refresh token mechanism
- **Token Revocation**: No logout mechanism or token blacklist
- **Token Rotation**: No automatic rotation on privilege escalation
- **Session Management**: Redis used for sessions (Line 42) but no session timeout, concurrent session limits, or session fixation protection mentioned

#### Missing Authentication Policies
- **Password Policy**: No minimum length, complexity requirements, or password history
- **Account Lockout**: No protection against brute-force attacks
- **Password Reset Security**: Reset tokens valid for 1 hour (Line 201) but no mention of:
  - Single-use token enforcement
  - Account lockout after multiple reset attempts
  - Token invalidation on password change

#### Missing Multi-Factor Authentication
- No MFA design for high-privilege accounts (admins, managers)
- No step-up authentication for sensitive operations (bulk delete, data export)

**Recommendations:**
1. **Token Storage**: Migrate to httpOnly cookies immediately
2. **Authorization Matrix**: Define complete RBAC model with operation-level permissions
3. **OAuth Encryption**: Implement field-level encryption for all credentials
4. **Token Management**: Add refresh tokens, revocation API, and rotation policies
5. **Authentication Policies**: Document password requirements, lockout thresholds, MFA requirements
6. **Session Security**: Define session timeout (15 min idle, 24 hour absolute), concurrent session limits (3 per user)

---

### 3. Data Protection - Score: 2/5 (Significant Issue)

**Critical Issues:**

#### S3 Public-Read ACL (Critical)
- **Location**: Line 236 states "Files stored in S3 with public-read ACL"
- **Vulnerability**: All uploaded files (attachments, profile images) are publicly accessible without authentication
- **Impact**: Confidential sales documents, contracts, customer PII exposed to internet
- **Recommendation**: **Immediately change to private ACL**
  - Use S3 bucket policy to deny public access
  - Generate pre-signed URLs for authenticated access (1-hour expiration)
  - Implement access control checks before URL generation

#### Missing Encryption at Rest
- **PostgreSQL**: No mention of encryption at rest (Line 41)
- **Redis**: Session data unencrypted (Line 42)
- **Elasticsearch**: Indexed data encryption not specified (Line 43)
- **S3**: Server-side encryption not specified (Line 44)
- **Recommendation**: Enable encryption for all storage:
  - PostgreSQL: Enable AWS RDS encryption with KMS keys
  - Redis: Enable encryption at rest (Redis 6.0+)
  - Elasticsearch: Enable encryption at rest with node-to-node encryption
  - S3: Enable SSE-KMS encryption with customer-managed keys

**Significant Issues:**

#### Missing Data Retention Policy
- No retention periods defined for:
  - User data after account deletion
  - Audit logs
  - File attachments
  - Email credentials after integration disconnection
  - Deleted records (soft delete vs hard delete)

#### Missing Data Privacy Controls
- **GDPR Compliance**: Mentions data export/deletion endpoints (Line 298) but lacks:
  - Right to be forgotten implementation details
  - Data portability format (structured export)
  - Consent management for data processing
  - Cross-border data transfer safeguards
  - Third-party data processor agreements
- **PII Identification**: No inventory of PII fields or handling requirements
- **Data Minimization**: No policy on limiting collected data to necessary fields

#### Missing Field-Level Encryption
- **Custom Fields**: JSONB custom_fields (Lines 124, custom data) may contain sensitive PII but no encryption
- **Email/Phone**: Contact information stored in plaintext
- **Sensitive Metadata**: Deal amounts, expected close dates visible to all tenant users

#### Missing Backup Security
- **Backup Encryption**: Daily snapshots mentioned (Line 288) but encryption not specified
- **Backup Access Control**: No policy on who can restore backups
- **Backup Retention**: No retention period or secure deletion policy
- **Backup Testing**: No mention of recovery testing or RTO/RPO targets

**Recommendations:**
1. **S3 Security**: Change to private ACL, implement pre-signed URLs with authentication
2. **Encryption at Rest**: Enable for all data stores (PostgreSQL, Redis, Elasticsearch, S3)
3. **Data Retention**: Define 90-day soft delete for user data, 7-year audit log retention
4. **Privacy Controls**: Document GDPR implementation, PII inventory, consent flows
5. **Field-Level Encryption**: Encrypt custom_fields, OAuth tokens, sensitive contact data
6. **Backup Security**: Encrypt backups with separate KMS keys, implement RBAC for restore operations

---

### 4. Input Validation Design - Score: 2/5 (Significant Issue)

**Critical Gap: No Input Validation Policy**

The design document lacks any explicit input validation policy, exposing the system to multiple injection attack vectors.

**Missing Validation Specifications:**

#### Email Input Validation
- **Contact Email** (Line 121): No format validation, length limits, or disposable email blocking
- **Webhook URL** (Line 150): No URL validation, protocol restrictions, or SSRF protection
- **Risk**: Malformed data, database bloat, SSRF attacks against internal services

#### JSONB Custom Fields Validation
- **Location**: Lines 124 (contacts), no validation rules specified
- **Risk**: Arbitrary JSON injection, deeply nested objects causing DoS, oversized payloads
- **Recommendation**: Define schema validation:
  ```
  - Maximum nesting depth: 3 levels
  - Maximum field count: 50 fields
  - Maximum value size: 1KB per field
  - Type constraints: string, number, boolean, date only
  - Deny functions, URLs, scripts in values
  ```

#### File Upload Validation
- **Partial Specification**: 10MB per file limit (Line 96) but missing:
  - Allowed file types (whitelist: pdf, docx, xlsx, png, jpg)
  - Filename sanitization (prevent directory traversal: ../../../etc/passwd)
  - Content-type validation (verify MIME matches file content)
  - Malware scanning integration
  - Image processing (strip EXIF metadata, resize to prevent zip bombs)

#### Search Input Validation
- **Location**: Line 204 allows `?search=john` query parameter
- **Risk**: Elasticsearch injection, regex DoS, wildcard abuse
- **Recommendation**: Implement query sanitization:
  - Escape special characters: +, -, =, &&, ||, !, (, ), {, }, [, ], ^, ", ~, *, ?, :, \, /
  - Limit query length to 100 characters
  - Restrict to alphanumeric + whitespace
  - No raw user input in Elasticsearch DSL

#### SQL Injection Prevention
- **Current Mitigation**: "Parameterized queries" mentioned (Line 282)
- **Gap**: No enforcement mechanism, code review process, or ORM usage specified
- **Recommendation**: Mandate ORM usage (TypeORM, Sequelize) and automated SAST scanning

#### XSS Prevention
- **Current Mitigation**: "React's automatic escaping" (Line 283)
- **Gaps**:
  - No Content Security Policy (CSP) headers specified
  - No sanitization for user-generated HTML (email bodies, notes with formatting)
  - No dangerouslySetInnerHTML usage policy
- **Recommendation**: Implement defense-in-depth:
  ```
  Content-Security-Policy:
    default-src 'self';
    script-src 'self' 'unsafe-inline' cdn.example.com;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    connect-src 'self' *.salespulse.com;
  ```

#### NoSQL Injection (JSONB)
- **Risk**: PostgreSQL JSONB queries vulnerable to injection if user input concatenated
- **Example Vulnerable Query**: `WHERE custom_fields @> '{"role": "' + userInput + '"}'`
- **Recommendation**: Use parameterized JSONB queries, validate JSON structure before storage

#### Command Injection
- **Risk**: File upload service (Line 95) may invoke system commands for processing
- **Recommendation**: Avoid shell commands; use libraries for file operations

#### Output Encoding
- **Gap**: No mention of output encoding for:
  - CSV exports (prevent formula injection: =cmd|'/c calc')
  - PDF reports (XSS in PDF metadata)
  - Webhook payloads (JSON encoding)
  - Email notifications (HTML injection)

**Recommendations:**
1. **Create Input Validation Policy Document** defining rules for all input types
2. **Implement Centralized Validation**: Create validation middleware for common patterns
3. **Whitelist Approach**: Define allowed characters/patterns, reject everything else
4. **File Upload Security**: Implement type whitelist, malware scanning, sandboxed processing
5. **Search Query Sanitization**: Escape Elasticsearch special characters, limit complexity
6. **Output Encoding**: Context-aware encoding for CSV, HTML, JSON, URL outputs
7. **Automated Testing**: Add SAST/DAST scanning for injection vulnerabilities

---

### 5. Infrastructure & Dependency Security - Score: 2/5 (Significant Issue)

**Systematic Infrastructure Security Assessment:**

#### PostgreSQL Database

| Security Aspect | Status | Risk | Recommendation |
|-----------------|--------|------|----------------|
| **Access Control** | Unspecified | **Critical** | Implement principle of least privilege: API servers get schema-specific roles, read-only replicas for reporting, deny public access via VPC security groups |
| **Encryption at Rest** | Unspecified | **High** | Enable AWS RDS encryption with KMS customer-managed keys, rotate keys annually |
| **Encryption in Transit** | Unspecified | **High** | Enforce SSL/TLS connections (require_ssl=on), use RDS certificate validation in connection string |
| **Network Isolation** | Unspecified | **Critical** | Deploy in private subnets with no internet gateway, allow connections only from ECS security group |
| **Authentication** | Partial | **High** | Use IAM database authentication instead of passwords, rotate credentials monthly via Secrets Manager |
| **Monitoring/Logging** | Unspecified | **Medium** | Enable CloudWatch logs for slow queries (>1s), failed login attempts, DDL changes |
| **Backup/Recovery** | Partial | **Medium** | Daily snapshots mentioned (Line 288) but add: 35-day retention, cross-region replication, quarterly restore testing, encrypted backups |

#### Redis Cache/Session Store

| Security Aspect | Status | Risk | Recommendation |
|-----------------|--------|------|----------------|
| **Access Control** | Unspecified | **Critical** | Enable Redis AUTH, use strong password (32+ chars), rotate quarterly |
| **Encryption at Rest** | Missing | **High** | Enable encryption at rest (Redis 6.0+) or use AWS ElastiCache encryption |
| **Encryption in Transit** | Unspecified | **Critical** | Enable TLS for all client connections (Redis 6.0+), verify certificates |
| **Network Isolation** | Unspecified | **Critical** | Deploy in private subnet, security group allows only ECS cluster access |
| **Authentication** | Unspecified | **Critical** | Enforce AUTH, disable FLUSHALL/FLUSHDB commands, use separate credentials per environment |
| **Monitoring/Logging** | Unspecified | **Medium** | Monitor failed AUTH attempts, slow commands, memory usage alerts |
| **Backup/Recovery** | Missing | **High** | **Critical Gap**: Single-node deployment (Line 289) means session data loss on failure. Implement Redis Cluster or ElastiCache with automatic failover, enable AOF persistence |

**Critical Issue**: Redis single-node deployment creates session availability risk and prevents persistent session storage. If Redis crashes, all users are logged out and lose session state.

#### Elasticsearch Search Engine

| Security Aspect | Status | Risk | Recommendation |
|-----------------|--------|------|----------------|
| **Access Control** | Unspecified | **Critical** | Enable X-Pack Security: create read-only role for API servers, restrict admin access to DevOps team, deny wildcard delete operations |
| **Encryption at Rest** | Unspecified | **High** | Enable node-level encryption or use AWS Elasticsearch encryption at rest |
| **Encryption in Transit** | Unspecified | **High** | Enable HTTPS for all API calls, configure node-to-node TLS encryption |
| **Network Isolation** | Unspecified | **Critical** | Deploy in private subnet with VPC access only, no public endpoint |
| **Authentication** | Unspecified | **Critical** | Enable HTTP basic auth or AWS Signature V4, rotate credentials quarterly |
| **Monitoring/Logging** | Unspecified | **Medium** | Enable audit logging for index operations, failed auth attempts, query performance |
| **Backup/Recovery** | Unspecified | **Medium** | Configure automated snapshots to S3, test restore quarterly, retain 30 days |

**Data Exposure Risk**: Elasticsearch indexes contain full-text searchable contact/company/deal data (Line 43). Without access control, an internal attacker or compromised API key can query all tenant data.

#### AWS S3 File Storage

| Security Aspect | Status | Risk | Recommendation |
|-----------------|--------|------|----------------|
| **Access Control** | **Misconfigured** | **CRITICAL** | **Files set to public-read (Line 236) - immediate fix required**: Change to private ACL, implement IAM-based access for API servers, generate pre-signed URLs for authenticated downloads |
| **Encryption at Rest** | Unspecified | **High** | Enable SSE-KMS with customer-managed keys, require encryption for all PutObject operations via bucket policy |
| **Encryption in Transit** | Partial | **Medium** | Enforce TLS 1.2+ via bucket policy (deny requests without SecureTransport) |
| **Network Isolation** | N/A | N/A | S3 is internet-facing by design; rely on IAM policies and bucket policies |
| **Authentication** | Partial | **High** | Use IAM roles for ECS tasks (no hardcoded keys), implement S3 access points with VPC endpoints for network isolation |
| **Monitoring/Logging** | Unspecified | **Medium** | Enable S3 server access logs and CloudTrail S3 data events, alert on unauthorized access |
| **Backup/Recovery** | Unspecified | **Medium** | Enable versioning to protect against accidental deletion, configure lifecycle policies for cost optimization, replicate critical files cross-region |

#### AWS Application Load Balancer

| Security Aspect | Status | Risk | Recommendation |
|-----------------|--------|------|----------------|
| **Access Control** | Unspecified | **Medium** | Configure security group to allow 443 from 0.0.0.0/0, deny 80 or redirect to 443 |
| **Encryption in Transit** | Partial | **High** | HTTPS enforced (Line 280) but specify: TLS 1.2+ only, strong cipher suites (no RC4/3DES), use AWS ACM certificates with auto-renewal |
| **Authentication** | N/A | N/A | ALB handles TLS termination; authentication at application layer |
| **Monitoring/Logging** | Unspecified | **Medium** | Enable ALB access logs to S3, alert on 4xx/5xx spike, DDoS detection via CloudWatch metrics |
| **DDoS Protection** | Unspecified | **High** | Enable AWS Shield Standard (free), consider Shield Advanced for L7 DDoS protection, implement WAF rules (see below) |

**Missing Web Application Firewall (WAF):**
- No AWS WAF integration mentioned for ALB
- **Recommendation**: Implement WAF with managed rule groups:
  - Core Rule Set (CRS) for OWASP Top 10
  - Known Bad Inputs (SQLi, XSS patterns)
  - Rate-limiting rules (100 req/min per IP)
  - Geographic blocking if applicable
  - IP reputation lists

#### AWS ECS Fargate Containers

| Security Aspect | Status | Risk | Recommendation |
|-----------------|--------|------|----------------|
| **Access Control** | Unspecified | **High** | Use IAM task roles with least privilege, deny root user in containers, run as non-root user (USER node in Dockerfile) |
| **Image Security** | Unspecified | **High** | Scan images for vulnerabilities (AWS ECR image scanning or Trivy), rebuild weekly for security patches, use official base images only (node:18-alpine) |
| **Network Isolation** | Unspecified | **High** | Deploy tasks in private subnets, use VPC endpoints for AWS services (no internet gateway for egress), security groups allow only ALB → ECS traffic |
| **Secrets Management** | Partial | **Critical** | Environment variables mentioned (Line 270) - **Do NOT use for secrets**: Migrate to AWS Secrets Manager or Parameter Store with encryption, inject at runtime, rotate automatically |
| **Monitoring/Logging** | Partial | **Medium** | CloudWatch mentioned (Line 52) but specify: container stdout/stderr to CloudWatch Logs, enable ECS Container Insights, alert on task failures |
| **Runtime Security** | Unspecified | **Medium** | Enable read-only root filesystem where possible, use AWS Fargate platform version 1.4+ with security patches, implement container resource limits (CPU, memory) to prevent noisy neighbor |

**Critical Gap - Secrets Management:**
- **Current Design**: "Environment variables for configuration (DB credentials, API keys)" (Line 270)
- **Risk**: Secrets visible in ECS task definitions, CloudFormation templates, container inspection
- **Impact**: Leaked credentials via logs, task definition exports, compromised containers
- **Recommendation**: Migrate to AWS Secrets Manager:
  ```
  // Task definition
  secrets: [
    { name: "DB_PASSWORD", valueFrom: "arn:aws:secretsmanager:..." }
  ]

  // Enable automatic rotation every 90 days
  ```

#### Third-Party Dependencies

| Dependency | Version | Known Vulnerabilities | Recommendation |
|------------|---------|----------------------|----------------|
| **jsonwebtoken** | 9.0 | Check CVE database | Enable Dependabot/Snyk for automated vulnerability scanning, update monthly, pin major versions |
| **bcrypt** | 5.1 | Generally secure | Verify cost factor (10 rounds, Line 281) is current best practice, increase to 12 rounds |
| **nodemailer** | 6.9 | Check for SMTP injection | Validate email recipients against whitelist, use authenticated SMTP with TLS, avoid user input in headers |
| **axios** | 1.3 | Check for SSRF issues | Configure timeout (5s), disable redirects for sensitive calls, validate response content-type |
| **multer** | 1.4 | File upload vulnerabilities | Implement file type validation (magic bytes, not extension), size limits, sandboxed processing |
| **Bull (task queue)** | 4.10 | Check for deserialization issues | Validate job payloads before processing, use separate Redis instance for queue vs sessions |

**Missing Dependency Security Measures:**
- No automated dependency scanning (Snyk, Dependabot, npm audit)
- No supply chain attack protection (package lock verification, subresource integrity)
- No private npm registry or proxy for supply chain control
- No policy on dependency update cadence or EOL library handling

#### External Integrations (Gmail/Outlook OAuth)

| Security Aspect | Status | Risk | Recommendation |
|-----------------|--------|------|----------------|
| **Access Control** | Partial | **High** | Request minimum OAuth scopes (read-only email access), implement token revocation on user disconnect, audit scope usage quarterly |
| **Token Storage** | **Missing Encryption** | **CRITICAL** | OAuth tokens stored as plaintext TEXT (Lines 143-144) - **Encrypt immediately** using AWS KMS envelope encryption or application-level encryption |
| **Token Rotation** | Unspecified | **High** | Implement automatic refresh token rotation, detect and alert on revoked tokens, expire tokens on password change |
| **Network Security** | Unspecified | **Medium** | Use OAuth 2.0 PKCE flow for additional security, validate redirect URIs strictly, implement state parameter for CSRF protection |

#### Webhook Delivery

| Security Aspect | Status | Risk | Recommendation |
|-----------------|--------|------|----------------|
| **URL Validation** | **Missing** | **CRITICAL** | **SSRF Risk**: Validate webhook URLs before registration: deny private IP ranges (10.x, 172.16.x, 192.168.x, 127.0.0.1, ::1, metadata endpoints 169.254.169.254), enforce HTTPS only, implement URL reputation checking |
| **Request Signing** | Partial | **High** | HMAC secret mentioned (Line 152) but implementation unspecified - use: `HMAC-SHA256(secret, timestamp + payload)`, include signature in X-Webhook-Signature header, verify timestamp within 5 minutes |
| **Retry Logic** | Unspecified | **Medium** | Implement exponential backoff (1s, 5s, 25s, 2m, 10m), max 5 retries, disable webhook after 10 consecutive failures, alert customer |
| **DoS Protection** | Unspecified | **High** | Rate limit webhook deliveries (100/min per tenant), timeout after 10s, limit payload size to 1MB, queue webhooks asynchronously |

**Recommendations Summary:**

1. **Immediate Critical Fixes** (within 24 hours):
   - Change S3 ACL from public-read to private, implement pre-signed URLs
   - Encrypt OAuth tokens in database using KMS
   - Migrate secrets from environment variables to AWS Secrets Manager
   - Implement SSRF protection for webhook URLs

2. **High Priority** (within 1 week):
   - Enable encryption at rest for all data stores (PostgreSQL, Redis, Elasticsearch, S3)
   - Enforce TLS for all service-to-service communication
   - Deploy Redis in clustered mode with automatic failover
   - Implement network isolation (private subnets, security groups)
   - Add Elasticsearch access control

3. **Standard Priority** (within 1 month):
   - Implement comprehensive monitoring/alerting for all components
   - Configure automated backups with encryption and cross-region replication
   - Add dependency vulnerability scanning
   - Deploy AWS WAF with managed rule groups
   - Enable audit logging for all infrastructure access

---

### 6. Missing Rate Limiting & DoS Protection - Score: 2/5 (Significant Issue)

**Critical Gap: No Rate Limiting Design**

The design document contains no rate limiting mechanism, exposing the system to multiple DoS attack vectors.

**Attack Vectors Without Rate Limiting:**

#### Authentication Endpoints
- **POST /api/auth/login** (Line 172): No limit on failed login attempts
  - **Attack**: Credential stuffing, brute-force attacks, account enumeration
  - **Impact**: Account takeover, service degradation, credential database leaks
  - **Recommendation**: Implement rate limiting:
    ```
    - 5 failed attempts per email per 15 minutes → account lockout
    - 100 requests per IP per minute → temporary IP ban
    - Progressive delays: 1s, 5s, 30s after failures
    ```

- **POST /api/auth/password-reset** (Line 188): No limit on reset requests
  - **Attack**: Account enumeration (valid emails receive reset), email bombing, DoS
  - **Recommendation**: 3 requests per email per hour, same response for valid/invalid emails

#### API Endpoints
- **GET /api/contacts** (Line 203): No rate limit on queries
  - **Attack**: Data exfiltration via automated scraping, resource exhaustion
  - **Recommendation**: 1000 requests per user per hour, exponential backoff on burst

#### File Upload
- **POST /api/files/upload** (Line 235): 10MB per file but no rate limit
  - **Attack**: Storage exhaustion, bandwidth consumption, cost inflation
  - **Recommendation**:
    - 50 uploads per user per day
    - 500MB total upload per tenant per day
    - 10 concurrent uploads per user
    - Storage quota alerts at 80% tenant limit

#### Webhook Deliveries
- **Line 102**: Background workers deliver webhooks but no rate limit specified
  - **Attack**: Customer webhook endpoints attack origin system, retry storms
  - **Recommendation**: 100 deliveries per minute per tenant, exponential backoff, circuit breaker pattern

#### Search Queries
- **GET /api/contacts?search=...** (Line 204): No limit on Elasticsearch queries
  - **Attack**: Complex regex queries causing CPU exhaustion, wildcard abuse
  - **Recommendation**: 100 search queries per user per minute, limit query complexity

**Missing DoS Protection Mechanisms:**

#### Application-Level Protection
- No connection limits per IP
- No request size limits (except file uploads)
- No query complexity limits (prevent deeply nested filters)
- No concurrent request limits per user

#### Infrastructure-Level Protection
- AWS Shield Standard mentioned (implicit with ALB) but not explicit
- No AWS WAF rate limiting rules
- No CloudFront rate limiting policies
- No mention of DDoS mitigation runbooks

**Recommendations:**
1. **Implement Redis-Based Rate Limiting**: Use Redis counters with sliding window algorithm
2. **Authentication Protection**: Account lockout (5 failures), IP-based limiting (100/min), CAPTCHA after 3 failures
3. **API Rate Limits**: Tiered limits by user role (user: 1000/hour, admin: 5000/hour)
4. **File Upload Quotas**: Daily per-user limit (50 files), tenant storage quota (10GB base + scaling)
5. **Webhook Rate Limiting**: 100/min per tenant, circuit breaker after 10 consecutive failures
6. **Infrastructure Protection**: Deploy AWS WAF with rate-based rules, enable CloudFront rate limiting
7. **Monitoring**: Alert on rate limit threshold breaches, track top offending IPs/users

---

### 7. Missing CSRF Protection - Score: 2/5 (Significant Issue)

**Critical Gap: No CSRF Protection Mechanism**

The design relies on JWT tokens in Authorization header (Line 167) but lacks CSRF protection for browser-based requests.

**Why CSRF Protection is Needed:**

Even with JWT in Authorization header, CSRF attacks are possible if:
1. JWT is also accessible via JavaScript (localStorage, Line 169)
2. Malicious site tricks browser into making authenticated request
3. Cookies are used for session management (conflicting information: Line 42 mentions Redis for sessions, but Line 169 uses localStorage)

**Vulnerable Endpoints:**

#### State-Changing Operations
- **PUT /api/deals/:id** (Line 219): Update deal without CSRF token
- **DELETE /api/deals/:id** (Line 223): Delete deal without CSRF token
- **POST /api/webhooks** (Line 226): Register malicious webhook URL
- **POST /api/files/upload** (Line 235): Upload malicious files

**Attack Scenario:**
```html
<!-- Malicious site: attacker.com -->
<script>
  // If JWT in localStorage, attacker can't access it
  // But if browser makes request with cookies, CSRF possible
  fetch('https://victim.salespulse.com/api/deals/123', {
    method: 'DELETE',
    credentials: 'include' // Sends cookies automatically
  });
</script>
```

**Current Mitigation Analysis:**

1. **JWT in Authorization Header** (Line 167): Provides some CSRF protection since custom headers require CORS preflight
2. **However**: localStorage JWT (Line 169) doesn't prevent CSRF if site is compromised via XSS
3. **SameSite Cookies**: Not mentioned in design

**Recommendations:**

#### Option 1: Double-Submit Cookie Pattern (if keeping localStorage)
```
- Generate CSRF token on login, store in httpOnly cookie
- Return CSRF token in response body, store in React state
- Require X-CSRF-Token header on all state-changing requests
- Verify header matches cookie server-side
```

#### Option 2: httpOnly Cookie + SameSite (Recommended)
```
- Migrate JWT from localStorage to httpOnly cookie with SameSite=Strict
- Eliminates CSRF risk (browser prevents cross-site cookie sending)
- Removes XSS token theft risk
- Add CSRF token for additional defense-in-depth
```

#### Option 3: Origin Validation
```
- Verify Origin and Referer headers on all POST/PUT/DELETE requests
- Reject requests from untrusted origins
- Configure CORS to whitelist only customer subdomains
```

**Missing CORS Policy:**
- No CORS configuration specified for API
- Risk: Open CORS (Access-Control-Allow-Origin: *) enables CSRF-like attacks
- Recommendation: Whitelist only customer subdomains (*.salespulse.com), require credentials

**Recommendations:**
1. **Immediate**: Migrate JWT to httpOnly + Secure + SameSite=Strict cookies
2. **Add CSRF Tokens**: Implement double-submit cookie pattern for defense-in-depth
3. **CORS Policy**: Explicitly whitelist *.salespulse.com origins only
4. **Origin Validation**: Verify Origin/Referer headers on state-changing operations
5. **Security Headers**: Add X-Frame-Options, X-Content-Type-Options

---

### 8. Missing Audit Logging & Compliance - Score: 2/5 (Significant Issue)

**Partial Specification:**

The design mentions logging (Lines 255-259) but lacks critical details for security audit and compliance requirements.

**Current Logging Specification:**
- "User actions logged with user ID and tenant ID" (Line 259)
- "Structured JSON logs" (Line 256)
- "CloudWatch" destination (Line 253)

**Missing Audit Logging Requirements:**

#### Which Events to Log
- **Authentication Events**: Login success/failure, logout, password change, password reset, MFA enrollment, session expiration
- **Authorization Events**: Permission denied, privilege escalation, role changes
- **Data Access Events**: View/export sensitive data (contact lists, deal reports), bulk data access, API key usage
- **Data Modification Events**: Create/update/delete for all entities, bulk operations, import/export
- **Administrative Events**: User creation/deletion, permission changes, integration setup, webhook registration, tenant configuration changes
- **Security Events**: Rate limit breaches, failed authentication attempts, suspicious patterns, CSRF token mismatches, invalid JWT tokens

**Recommendation**: Define comprehensive audit event taxonomy covering all CRUD operations on sensitive data.

#### Log Content Requirements
- **Who**: User ID, tenant ID, role, IP address, user agent
- **What**: Action type, resource type, resource ID, field changes (before/after)
- **When**: Timestamp (UTC), session ID, request ID
- **Where**: Source IP, geographic location, subdomain
- **Why**: Context (API vs UI, bulk operation, automated job)
- **Result**: Success/failure, error code, reason

**Critical Gap - PII/Sensitive Data Masking:**
- No policy on masking sensitive fields in logs
- Risk: Passwords, OAuth tokens, credit card numbers, SSNs logged in plaintext
- **Recommendation**: Implement field-level masking:
  ```
  - Passwords: Never log, redact completely
  - Tokens: Log first 8 characters only (abc123ef...)
  - Email: Mask domain (user@*****.com)
  - Phone: Mask middle digits (555-***-1234)
  - Custom fields: Inspect for PII patterns, mask automatically
  ```

#### Log Retention & Protection
- **Retention Period**: Not specified
- **Recommendation**:
  - Security logs: 13 months (compliance requirement)
  - Audit logs: 7 years (financial data retention)
  - Debug logs: 30 days
- **Log Protection**: No immutability guarantee
- **Risk**: Attackers delete logs to hide evidence
- **Recommendation**:
  - Stream logs to WORM (write-once-read-many) storage
  - Enable CloudWatch Logs encryption
  - Restrict log deletion to security team only
  - Implement log integrity verification (digital signatures)

#### Log Access Control
- **Current**: No policy on who can access logs
- **Risk**: Developers access production logs containing PII
- **Recommendation**:
  - Security team: Full access to security/audit logs
  - Developers: Access to debug logs only, redacted PII
  - Compliance team: Read-only access to audit logs
  - All access logged to separate audit trail

#### GDPR/SOC 2 Compliance Gaps

**GDPR (Line 298):**
- **Data Export**: Endpoint mentioned but format not specified
  - Recommendation: Structured JSON export including all PII, audit logs, third-party data processor disclosures
- **Data Deletion**: Endpoint mentioned but scope unclear
  - Recommendation: Right to be forgotten includes: user data, contact references, deal history, file attachments, audit logs (retain only pseudonymized compliance records)
- **Missing Requirements**:
  - Consent management for data processing
  - Legitimate interest assessments
  - Data processing records (Article 30)
  - Breach notification procedures (72-hour requirement)
  - Data protection impact assessments (DPIA)
  - Cross-border transfer mechanisms (SCCs, BCRs)

**SOC 2 (Line 299):**
- **Audit Logging**: Mentioned but incomplete
- **Missing Controls**:
  - User access reviews (quarterly)
  - Privileged access monitoring
  - Change management audit trail
  - Incident response procedures
  - Vulnerability management logs
  - Backup/restore audit trail

**Recommendations:**
1. **Define Comprehensive Audit Event Taxonomy**: Cover all security-relevant events
2. **Implement PII Masking**: Automatic detection and redaction in logs
3. **Log Retention Policy**: 13 months security, 7 years audit, encrypted storage
4. **Log Integrity Protection**: WORM storage, digital signatures, tamper detection
5. **Access Control**: Role-based log access, separate audit trail for log access
6. **GDPR Compliance**: Document consent flows, breach procedures, DPIA, DPO appointment
7. **SOC 2 Compliance**: Implement all Trust Services Criteria controls with audit evidence
8. **Monitoring & Alerting**: Real-time alerts for critical security events (failed admin login, bulk delete, privilege escalation)

---

### 9. Additional Security Concerns

#### Missing Idempotency Guarantees
- **Risk**: Duplicate deal creation, double charging, data inconsistency on retry
- **Affected Endpoints**: POST /api/contacts, POST /api/deals, PUT /api/deals/:id, DELETE /api/deals/:id
- **Recommendation**: Implement idempotency keys:
  ```
  POST /api/deals
  Idempotency-Key: <client-generated-uuid>

  // Server stores key + response for 24 hours
  // Duplicate requests return cached response
  ```

#### Missing API Versioning
- **Risk**: Breaking changes affect existing integrations
- **Recommendation**: Use URL versioning (/api/v1/contacts) with deprecation policy

#### Missing Security Headers
- **X-Frame-Options**: Not specified (clickjacking protection)
- **X-Content-Type-Options**: Not specified (MIME-sniffing protection)
- **Referrer-Policy**: Not specified (information leakage)
- **Permissions-Policy**: Not specified (browser feature control)
- **Recommendation**: Implement comprehensive security headers:
  ```
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=()
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  ```

#### Missing Content Security Policy
- **Risk**: XSS attacks via injected scripts
- **Recommendation**: Implement strict CSP (see Section 4 for details)

#### Missing Password Hashing Configuration
- **Current**: bcrypt with 10 rounds (Line 281)
- **Assessment**: Adequate but should be increased
- **Recommendation**: Increase to 12 rounds, document rationale, plan future increases

#### Missing Session Security Measures
- **No Session Timeout**: No idle timeout (15 min) or absolute timeout (24 hours) specified
- **No Concurrent Session Limits**: Users can have unlimited active sessions
- **No Session Revocation**: No "logout all devices" functionality
- **Recommendation**: Implement session management best practices

#### Missing Secure Development Practices
- **No Code Review Process**: No security-focused code review mentioned
- **No SAST/DAST**: No static or dynamic security testing in CI/CD
- **No Penetration Testing**: No periodic security assessments
- **No Security Training**: No developer security awareness program
- **Recommendation**: Implement security development lifecycle (SDLC)

#### Missing Incident Response Plan
- **No Detection Procedures**: How to identify security incidents
- **No Response Procedures**: Roles, communication, containment, eradication
- **No Recovery Procedures**: Backup restoration, service recovery
- **No Post-Incident Review**: Root cause analysis, lessons learned
- **Recommendation**: Document incident response plan with quarterly drills

---

## Positive Security Aspects

Despite numerous gaps, the design includes some positive security practices:

1. **HTTPS Enforced**: All traffic uses TLS (Line 280)
2. **Password Hashing**: bcrypt with reasonable cost factor (Line 281)
3. **Parameterized Queries**: SQL injection prevention via parameterized queries (Line 282)
4. **React XSS Protection**: Automatic escaping of user input (Line 283)
5. **Multi-tenancy Data Isolation**: Schema-per-tenant model provides strong isolation (Line 72)
6. **File Upload Limits**: 10MB per file prevents basic DoS (Line 96)
7. **JWT Expiration**: 24-hour token expiration limits exposure window (Line 90)
8. **Webhook Secrets**: HMAC signature support for webhook verification (Line 152)
9. **Structured Logging**: JSON logs facilitate security monitoring (Line 256)
10. **Elasticsearch Replication**: 3-node cluster with 2 replicas provides availability (Line 294)

---

## Overall Security Assessment Scores

| Evaluation Criterion | Score | Justification |
|---------------------|-------|---------------|
| **Threat Modeling (STRIDE)** | 2/5 | Multiple STRIDE categories lack explicit countermeasures (token revocation, audit logging, authorization model, rate limiting) |
| **Authentication & Authorization** | 1/5 | **Critical issues**: JWT in localStorage (XSS risk), no authorization model for deals, OAuth tokens in plaintext |
| **Data Protection** | 2/5 | **Critical issues**: S3 public-read ACL, missing encryption at rest for all data stores, no data retention policy |
| **Input Validation** | 2/5 | No input validation policy, missing file type validation, no Elasticsearch query sanitization, partial XSS protection |
| **Infrastructure & Dependency Security** | 2/5 | **Critical issues**: Secrets in environment variables, S3 public ACL, missing encryption, single-node Redis, no SSRF protection for webhooks |
| **Rate Limiting & DoS Protection** | 2/5 | No rate limiting mechanism for any endpoint, exposing authentication brute-force, data exfiltration, storage exhaustion |
| **CSRF Protection** | 2/5 | No explicit CSRF protection, conflicting session management design (localStorage vs cookies), missing SameSite attribute |
| **Audit Logging & Compliance** | 2/5 | Partial audit logging, missing PII masking policy, incomplete GDPR/SOC 2 requirements, no log retention/protection policy |

**Overall Security Score: 1.75/5 (Significant Issues Requiring Immediate Action)**

---

## Critical Action Items (Prioritized)

### Immediate (24-48 hours)
1. Change JWT storage from localStorage to httpOnly + Secure + SameSite=Strict cookies
2. Change S3 ACL from public-read to private, implement pre-signed URLs
3. Encrypt OAuth tokens in database using AWS KMS
4. Migrate secrets from environment variables to AWS Secrets Manager
5. Implement authorization checks for deal operations (ownership/role-based)

### High Priority (1 week)
6. Enable encryption at rest for PostgreSQL, Redis, Elasticsearch, S3
7. Enforce TLS for all service-to-service communication
8. Implement SSRF protection for webhook URL validation
9. Deploy Redis in clustered mode with automatic failover
10. Add rate limiting for authentication endpoints (account lockout, IP-based)
11. Implement network isolation (VPC, private subnets, security groups)

### Standard Priority (1 month)
12. Create comprehensive input validation policy
13. Implement CSRF protection (double-submit cookie pattern)
14. Add rate limiting for all API endpoints
15. Enable WAF with managed rule groups
16. Implement comprehensive audit logging with PII masking
17. Add dependency vulnerability scanning (Snyk, Dependabot)
18. Configure CSP headers
19. Implement session security (timeouts, concurrent limits, revocation)
20. Document GDPR compliance procedures (consent, breach notification, DPIA)

### Long-term (3 months)
21. Implement field-level encryption for sensitive data
22. Add MFA for admin/manager accounts
23. Deploy SIEM for security monitoring
24. Conduct penetration testing
25. Implement security development lifecycle (SDLC)
26. Document and test incident response plan
27. Achieve SOC 2 Type II certification
28. Implement comprehensive backup/disaster recovery testing

---

## Conclusion

The SalesPulse CRM design document requires **substantial security hardening** before production deployment. The system contains **multiple critical vulnerabilities** that could lead to:

- **Account Takeover**: JWT in localStorage (XSS), no token revocation, no MFA
- **Data Breach**: S3 public-read ACL, OAuth tokens in plaintext, missing encryption at rest
- **Authorization Bypass**: No permission model for deals, any user can modify/delete any data
- **Service Disruption**: No rate limiting, single-node Redis, no DDoS protection
- **Compliance Violations**: Incomplete GDPR/SOC 2 controls, insufficient audit logging

**Recommendation**: Address all critical and high-priority issues before launching to production. Implement a security review process for all future design documents and code changes.

The design demonstrates some positive security practices (HTTPS, password hashing, parameterized queries) but these are overshadowed by fundamental gaps in authentication security, access control, data protection, and infrastructure security.

**Security posture must be elevated from current 1.75/5 to minimum 4/5 before production deployment.**
