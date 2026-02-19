# Security Design Review: HealthHub Telemedicine Platform

## Executive Summary

This security evaluation identifies **9 critical issues**, **6 significant issues**, and **8 moderate issues** in the HealthHub telemedicine platform design. The platform handles highly sensitive Protected Health Information (PHI) under HIPAA regulations but exhibits fundamental security design gaps that create immediate risk of data breach, privilege escalation, and regulatory non-compliance.

**Critical vulnerabilities require immediate remediation** before production deployment. Most severe issues include insecure JWT token storage in localStorage (enabling XSS token theft), missing CSRF protection, absence of encryption for PHI in transit to S3, no audit logging specification, and missing idempotency guarantees for prescription operations.

---

## Overall Security Scores

| Evaluation Criterion | Score | Severity |
|---------------------|-------|----------|
| Threat Modeling (STRIDE) | **2/5** | Significant |
| Authentication & Authorization Design | **1/5** | Critical |
| Data Protection | **2/5** | Significant |
| Input Validation Design | **2/5** | Significant |
| Infrastructure & Dependency Security | **2/5** | Significant |

**Overall Assessment: 1.8/5 (Critical) - Immediate security design improvements required before production deployment**

---

## Critical Issues (Score 1/5)

### C1. Insecure JWT Token Storage in localStorage (Authentication & Authorization)

**Section Reference**: 3.3 Data Flow, 5.1 Authentication Endpoints

**Issue Description**:
The design explicitly stores JWT tokens in browser localStorage (§3.3: "receives JWT token stored in browser localStorage"). This represents a **critical XSS vulnerability** in a HIPAA-regulated healthcare application.

**Impact**:
- **Attack Vector**: Any XSS vulnerability in the frontend (including third-party libraries like nodemailer, stripe, or twilio-video) allows attackers to exfiltrate authentication tokens via `localStorage.getItem('token')`
- **Consequence**: Complete account takeover with 24-hour window (token expiration), enabling unauthorized access to all patient medical records, prescription history, and consultation recordings
- **HIPAA Impact**: Constitutes a breach notification triggering event under 45 CFR §164.402

**Recommendation**:
```
IMMEDIATE ACTION REQUIRED:
1. Store JWT tokens in httpOnly cookies with Secure and SameSite=Strict flags
2. Implement CSRF token mechanism for state-changing operations
3. Configure cookie attributes:
   Set-Cookie: token=<jwt>; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=86400
4. Update API Gateway to read tokens from Cookie header instead of Authorization header
5. Implement token refresh mechanism with short-lived access tokens (15 min) and longer-lived refresh tokens (7 days) in separate httpOnly cookies
```

**Risk Level**: Critical - Enables complete authentication bypass via common XSS attacks

---

### C2. Missing CSRF Protection (Threat Modeling - Tampering)

**Section Reference**: 5.2 Consultation Endpoints, 5.3 Prescription Endpoints

**Issue Description**:
No CSRF protection mechanism is specified for any state-changing operations. All API endpoints rely solely on JWT bearer tokens, which are automatically sent by browsers if stored in localStorage (as designed).

**Impact**:
- **Attack Vector**: Attacker hosts malicious page that triggers authenticated requests to HealthHub API (e.g., `POST /api/prescriptions` to issue fraudulent prescriptions)
- **Consequence**: Unauthorized prescription creation, consultation cancellation, medical document deletion, all executed with victim's authenticated session
- **Real-world Scenario**: Phishing email with embedded form auto-submitting to `/api/prescriptions` endpoint

**Recommendation**:
```
1. Implement Double-Submit Cookie pattern:
   - Generate random CSRF token on login
   - Store in httpOnly cookie AND return in response body
   - Require X-CSRF-Token header matching cookie value for all POST/PATCH/DELETE operations

2. OR implement Synchronizer Token pattern:
   - Generate unique token per session stored server-side in Redis
   - Require token in custom header for state-changing requests

3. Configure Kong API Gateway to validate CSRF tokens before routing requests
4. Add CSRF token validation to all endpoints in §5.2, §5.3, §5.4
```

**Risk Level**: Critical - Enables unauthorized medical operations in HIPAA-regulated system

---

### C3. Missing Audit Logging Specification (Threat Modeling - Repudiation)

**Section Reference**: 6.2 Logging (incomplete specification)

**Issue Description**:
No audit logging specification exists for HIPAA-required security events. §6.2 describes general application logging but does not specify:
- What security events must be logged (authentication, authorization failures, PHI access)
- Audit log retention requirements (HIPAA mandates 6 years)
- Audit log integrity protection mechanisms
- PII/PHI masking policies in audit logs

**Impact**:
- **Compliance Failure**: Violates HIPAA Security Rule §164.312(b) audit controls and §164.308(a)(1)(ii)(D) information system activity review
- **Forensic Gap**: Cannot investigate security incidents or demonstrate compliance during OCR audits
- **Legal Liability**: Cannot prove or disprove unauthorized PHI access in breach investigations

**Recommendation**:
```
REQUIRED AUDIT LOG SPECIFICATION:

1. Events to Log (write-once, tamper-evident log):
   - Authentication: login attempts (success/failure), logout, token refresh, password reset
   - Authorization: access denied events with requested resource and user identity
   - PHI Access: every read/write of consultations, prescriptions, medical documents (log: user_id, resource_id, action, timestamp, IP address)
   - Administrative: user role changes, provider verification, account deletion
   - Configuration: security policy changes, API key rotation

2. Log Retention:
   - Minimum 6 years for HIPAA compliance (7 years recommended for legal hold)
   - Store in write-once storage (S3 Object Lock or AWS CloudWatch Logs with retention policy)

3. Log Protection:
   - Separate logging infrastructure with restricted access (dedicated AWS account)
   - Cryptographic signing of log entries (HMAC with rotated keys)
   - Immutable log storage preventing deletion/modification

4. PII/PHI Masking:
   - Never log: passwords, full SSNs, full credit card numbers, full medication details
   - Hash identifiers: patient_id → SHA256(patient_id + salt)
   - Log metadata only: document accessed (document_id) but not document content

5. Log Monitoring:
   - Real-time alerts for: repeated authentication failures (>5/hour), authorization violations, bulk PHI downloads
   - Daily automated compliance reports showing access patterns
```

**Risk Level**: Critical - HIPAA compliance blocker, prevents breach detection and investigation

---

### C4. Prescription API Missing Idempotency Guarantees (Threat Modeling - Tampering)

**Section Reference**: 5.3 POST /api/prescriptions

**Issue Description**:
The prescription creation endpoint (`POST /api/prescriptions`) has no idempotency mechanism specified. Network retries, client bugs, or duplicate submissions could result in duplicate prescriptions sent to pharmacies.

**Impact**:
- **Patient Safety**: Duplicate prescriptions lead to medication overdose risk (especially for controlled substances like opioids checked against DEA list in §5.3)
- **Regulatory Impact**: Violates 21 CFR Part 1306 (DEA prescription regulations) by enabling duplicate controlled substance prescriptions
- **Attack Amplification**: Attacker exploiting CSRF vulnerability (C2) can submit duplicate prescription requests

**Recommendation**:
```
IMMEDIATE IMPLEMENTATION REQUIRED:

1. Add Idempotency Key to Prescription API:
   POST /api/prescriptions
   Headers:
     - Authorization: Bearer <jwt>
     - Idempotency-Key: <client-generated-uuid>

   Server-side logic:
   - Store idempotency key in Redis with 24-hour TTL
   - Key format: "idempotency:prescription:{idempotency_key}" → prescription_id
   - On duplicate key: return 200 OK with original prescription_id
   - On new key: create prescription and store mapping atomically

2. Client Implementation:
   - Generate UUID on prescription form submission
   - Retry with same idempotency key on network failure
   - Display warning on retry: "Retrying prescription submission..."

3. Database Constraint:
   - Add unique index: (consultation_id, medication_name, dosage, created_at)
   - Prevent duplicate prescriptions within same consultation

4. Pharmacy Integration:
   - Add idempotency key to SureScripts API calls (§8.1)
   - Verify pharmacy API supports duplicate detection
```

**Risk Level**: Critical - Direct patient safety risk and controlled substance regulation violation

---

### C5. Medical Document Upload Missing Encryption in Transit to S3 (Data Protection)

**Section Reference**: 3.3 Data Flow, 5.4 POST /api/documents/upload

**Issue Description**:
§3.3 states "Medical documents are uploaded directly to S3 with pre-signed URLs" but does not specify:
- Whether pre-signed URLs enforce HTTPS (S3 pre-signed URLs can be HTTP by default)
- Whether client-side encryption is required before upload
- Whether S3 bucket policy enforces `aws:SecureTransport` condition

§7.2 only specifies "All external communication over HTTPS" but S3 uploads are **not** external communication—they are direct client-to-S3 uploads bypassing the API Gateway.

**Impact**:
- **HIPAA Violation**: PHI transmitted in clear text violates HIPAA Security Rule §164.312(e)(1) transmission security
- **Attack Vector**: Man-in-the-middle attacks on public WiFi networks (common in healthcare settings) can intercept unencrypted medical documents
- **Regulatory Penalty**: OCR fines for technical safeguard failures ($100–$50,000 per violation)

**Recommendation**:
```
IMMEDIATE REMEDIATION:

1. S3 Bucket Policy - Enforce HTTPS:
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Deny",
       "Principal": "*",
       "Action": "s3:*",
       "Resource": "arn:aws:s3:::healthhub-documents/*",
       "Condition": {
         "Bool": { "aws:SecureTransport": "false" }
       }
     }]
   }

2. Pre-signed URL Generation - Force HTTPS:
   const s3Params = {
     Bucket: 'healthhub-documents',
     Key: documentKey,
     Expires: 900, // 15 minutes
     Protocol: 'https' // Explicitly set HTTPS protocol
   };
   const presignedUrl = s3.getSignedUrl('putObject', s3Params);

3. Client-Side Validation:
   - Verify pre-signed URL starts with https:// before upload
   - Reject HTTP URLs with error: "Insecure upload URL detected"

4. Consider Client-Side Encryption:
   - Encrypt documents in browser before S3 upload using Web Crypto API
   - Store encryption keys in AWS KMS (separate key per patient)
   - Benefits: Zero-knowledge architecture, stronger HIPAA compliance posture
```

**Risk Level**: Critical - Direct HIPAA violation, PHI exposure in transit

---

### C6. Password Reset Token Has No Expiration (Authentication & Authorization)

**Section Reference**: 5.1 POST /api/auth/password-reset

**Issue Description**:
§5.1 explicitly states password reset tokens have "no expiration specified". This creates an indefinite authentication bypass window.

**Impact**:
- **Attack Vector**: Attacker intercepts password reset email (via compromised email account, email server breach, or email forwarding rule)
- **Persistence**: Token remains valid indefinitely, allowing attacker to reset password weeks/months after initial email compromise
- **Privilege Escalation**: Can be used to target high-value provider accounts for long-term persistence

**Recommendation**:
```
IMMEDIATE IMPLEMENTATION:

1. Token Expiration:
   - Generate time-limited reset tokens (15-minute expiration recommended)
   - Store in Redis with TTL: "password_reset:{user_id}" → {token_hash, expires_at}

2. Token Format:
   - Use cryptographically random token (32 bytes, base64url encoded)
   - DO NOT use predictable tokens (e.g., JWT with user_id in payload)

3. Token Validation:
   POST /api/auth/password-reset/verify
   - Check token exists and not expired
   - Invalidate after successful password change
   - Invalidate all user sessions on password change (revoke existing JWTs)

4. Rate Limiting:
   - Limit password reset requests to 3 per hour per email
   - Implement CAPTCHA after 2 failed attempts

5. Security Notifications:
   - Send email to old address on successful password change
   - Include account recovery instructions if change was unauthorized
```

**Risk Level**: Critical - Enables persistent account takeover vector

---

### C7. Weak Password Policy (Authentication & Authorization)

**Section Reference**: 5.1 POST /api/auth/register, 7.2 Security

**Issue Description**:
§5.1 specifies "minimum 6 characters" and §7.2 explicitly states "no complexity requirements". This is **grossly inadequate** for a healthcare application handling PHI.

**Impact**:
- **Brute Force**: 6-character passwords have only ~95^6 = 735 billion combinations, easily crackable with modern GPU computing (hours to days)
- **Dictionary Attacks**: Common passwords like "password", "123456", "healthcare" are allowed
- **Compliance Risk**: May not satisfy HIPAA Security Rule §164.308(a)(5)(ii)(D) password management requirements as interpreted by OCR

**Recommendation**:
```
IMMEDIATE POLICY UPDATE:

1. Minimum Password Requirements:
   - Length: 12 characters minimum (16 recommended for providers)
   - Complexity: Require 3 of 4 categories (uppercase, lowercase, numbers, symbols)
   - Block common passwords: integrate "Have I Been Pwned" API or use zxcvbn library
   - Block username/email in password

2. Password Validation:
   POST /api/auth/register
   - Return specific error messages:
     * "Password too short (minimum 12 characters)"
     * "Password too common (found in breach databases)"
     * "Password must not contain your email address"

3. Password Expiration (for providers):
   - Mandatory 90-day password rotation for provider accounts
   - Optional for patient accounts (user experience balance)

4. Password History:
   - Store hash of last 10 passwords
   - Prevent password reuse within 10 changes

5. Account Lockout:
   - Lock account after 5 failed login attempts
   - 30-minute lockout period or admin unlock required
   - Send security alert email on lockout
```

**Risk Level**: Critical - Enables trivial brute force attacks against healthcare accounts

---

### C8. Error Handling Exposes Stack Traces in Development Mode (Information Disclosure)

**Section Reference**: 6.1 Error Handling

**Issue Description**:
§6.1 states "Stack traces are included in development environment responses". The design does not specify:
- How development mode is determined (environment variable? configuration?)
- Whether staging/QA environments are considered "development"
- What prevents accidental deployment with development mode enabled

**Impact**:
- **Information Disclosure**: Stack traces reveal internal file paths, library versions, database schema details
- **Attack Surface Mapping**: Attackers can identify vulnerable dependencies (e.g., specific bcrypt or jsonwebtoken versions with known CVEs)
- **Deployment Risk**: High likelihood of accidentally deploying with development mode enabled (common misconfiguration)

**Recommendation**:
```
SECURE ERROR HANDLING SPECIFICATION:

1. Environment Detection:
   - Use NODE_ENV environment variable with strict values: "production", "staging", "development"
   - Default to "production" if NODE_ENV not set (secure by default)
   - Explicitly validate environment in application startup:
     if (!['production', 'staging', 'development'].includes(process.env.NODE_ENV)) {
       throw new Error('Invalid NODE_ENV');
     }

2. Production Error Responses:
   {
     "error": {
       "code": "INTERNAL_SERVER_ERROR",
       "message": "An unexpected error occurred. Reference ID: <uuid>",
       "request_id": "<uuid-for-log-correlation>"
     }
   }
   - NEVER include: stack traces, file paths, SQL queries, internal variable names

3. Error Logging:
   - Log full error details server-side with request_id
   - Include: stack trace, request headers (sanitized), request body (sanitized)
   - Store in separate error tracking system (e.g., Sentry)

4. Deployment Safeguard:
   - Add CI/CD pipeline check in GitHub Actions:
     - script: |
         if grep -q 'NODE_ENV=development' k8s/*.yaml; then
           echo "ERROR: Development mode detected in production configs"
           exit 1
         fi

5. Database Error Sanitization:
   - Catch PostgreSQL errors and translate to generic messages
   - Example: "duplicate key value" → "Resource already exists"
   - Log original error with correlation ID
```

**Risk Level**: Critical - Directly enables reconnaissance for targeted attacks

---

### C9. Kong API Gateway Rate Limit Insufficient for Authentication Endpoints (DoS Protection)

**Section Reference**: 3.2 Component Responsibilities, 5.1 Authentication Endpoints

**Issue Description**:
§3.2 specifies global rate limit of "100 req/min per IP" but §5.1 specifies more restrictive "10 requests per hour per IP" for `/api/auth/register`. The design does not clarify:
- Which rate limit takes precedence
- How Kong is configured to apply endpoint-specific limits
- Whether 100 req/min is sufficient to prevent brute force attacks on login endpoint

**Impact**:
- **Brute Force**: 100 req/min allows 6,000 password attempts per hour against single account (sufficient to crack weak 6-character passwords)
- **Account Enumeration**: Attacker can enumerate all registered email addresses by testing 100 emails per minute
- **DoS**: Attacker can exhaust API capacity by distributing requests across 10 IP addresses (1,000 req/min total)

**Recommendation**:
```
TIERED RATE LIMITING SPECIFICATION:

1. Global Rate Limits (Kong API Gateway):
   - Default: 1000 req/min per IP (increased from 100 for legitimate users)
   - Authenticated: 2000 req/min per user_id (extracted from JWT)

2. Endpoint-Specific Rate Limits:

   POST /api/auth/login:
   - 5 attempts per 15 minutes per IP address
   - 10 attempts per hour per email address (track server-side in Redis)
   - Implement exponential backoff: 1min, 5min, 15min, 1hr lockout
   - Return 429 Too Many Requests with Retry-After header

   POST /api/auth/register:
   - 3 attempts per hour per IP address
   - 1 attempt per 5 minutes per email address
   - Require CAPTCHA after first attempt (prevent automated account creation)

   POST /api/auth/password-reset:
   - 3 attempts per hour per email address
   - Implement CAPTCHA on all requests

   POST /api/prescriptions:
   - 10 prescriptions per hour per provider_id
   - Alert security team on threshold violation

3. Distributed Rate Limiting:
   - Use Redis for rate limit counters (shared across Kong instances)
   - Key pattern: "ratelimit:{endpoint}:{identifier}:{window}"
   - Implement sliding window algorithm for accurate rate limiting

4. Dynamic Rate Limiting:
   - Reduce limits by 90% during detected attack (automatic threat response)
   - Whitelist known provider IP ranges for higher limits
```

**Risk Level**: Critical - Enables brute force authentication bypass and DoS attacks

---

## Significant Issues (Score 2/5)

### S1. PostgreSQL Access Control and Encryption Unspecified (Infrastructure Security)

**Section Reference**: 2.2 Database, 7.2 Security

**Issue Description**:
§2.2 lists "PostgreSQL 15.2" but provides no access control specifications. §7.2 mentions "Database encryption at rest using AWS RDS encryption" but does not specify encryption key management, network access controls, or authentication mechanisms.

**Gaps Identified**:
- **Missing**: Network isolation (VPC configuration, security groups)
- **Missing**: Database user privilege model (least privilege access per microservice)
- **Missing**: Encryption key rotation schedule
- **Missing**: TLS enforcement for database connections
- **Missing**: Database activity monitoring/logging

**Impact**:
- **Lateral Movement**: Compromised microservice can access all database tables (no per-service isolation)
- **Compliance Gap**: HIPAA Security Rule §164.312(a)(1) requires unique user identification for database access

**Recommendation**:
```
COMPLETE INFRASTRUCTURE SECURITY SPECIFICATION:

| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| PostgreSQL 15.2 | Access Control | Unspecified | High | 1. Create separate database users per microservice (auth_service_user, ehr_service_user, etc.) with least-privilege grants<br>2. Revoke public schema access<br>3. Use AWS IAM database authentication for password-less auth |
| | Encryption (at rest) | Present | Low | Already using AWS RDS encryption - add key rotation schedule (annual rotation required) |
| | Encryption (in transit) | Unspecified | High | Enforce TLS 1.3 connections: require_ssl=on in PostgreSQL config, verify client certificates |
| | Network Isolation | Unspecified | High | 1. Deploy in private VPC subnet (no internet gateway)<br>2. Security group: allow port 5432 only from EKS node security group<br>3. Enable AWS RDS VPC endpoint |
| | Authentication | Unspecified | High | 1. Disable password authentication for production<br>2. Use AWS IAM database authentication<br>3. Rotate credentials automatically every 90 days |
| | Monitoring/Logging | Unspecified | High | 1. Enable PostgreSQL audit logging (pgaudit extension)<br>2. Log all DDL and failed authentication attempts<br>3. Export logs to CloudWatch Logs with 6-year retention |
| | Backup/Recovery | Partial | Medium | Daily snapshots specified but add: 1. Cross-region backup replication<br>2. Automated restore testing (monthly)<br>3. Point-in-time recovery enabled |
```

**Risk Level**: Significant - Missing defense-in-depth, inadequate HIPAA technical safeguards

---

### S2. Redis Cache Access Control and Data Protection Unspecified (Infrastructure Security)

**Section Reference**: 2.2 Database (Cache Layer: Redis 7.0)

**Issue Description**:
Redis is used as cache layer but design provides zero security specifications. Redis likely stores sensitive session data, rate limit counters, and potentially PHI.

**Gaps Identified**:
- **Missing**: Authentication mechanism (Redis password/ACL configuration)
- **Missing**: Encryption at rest
- **Missing**: Encryption in transit (TLS configuration)
- **Missing**: Network isolation
- **Missing**: Data classification policy (what data is cached?)
- **Missing**: Cache eviction policy for PHI

**Impact**:
- **PHI Exposure**: If Redis contains PHI (e.g., cached consultation data) without encryption, violates HIPAA
- **Session Hijacking**: If Redis is compromised, attacker gains access to all active sessions

**Recommendation**:
```
| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| Redis 7.0 | Access Control | Missing | Critical | 1. Enable Redis ACL with unique passwords per service<br>2. Create separate ACL users: auth_service (access to session:* keys only), rate_limiter (access to ratelimit:* keys only)<br>3. Disable default user: `ACL SETUSER default off` |
| | Encryption (at rest) | Missing | High | 1. Use AWS ElastiCache with encryption-at-rest enabled<br>2. Verify KMS key rotation enabled<br>3. Document: Redis should NEVER cache raw PHI - cache only pseudonymized identifiers |
| | Encryption (in transit) | Missing | High | 1. Enable TLS mode: `tls-port 6379`<br>2. Enforce TLS in ElastiCache cluster configuration<br>3. Update client libraries to use rediss:// protocol |
| | Network Isolation | Missing | High | 1. Deploy in private VPC subnet<br>2. Security group: allow port 6379 only from EKS node security group<br>3. Disable Redis CLUSTER MEET to prevent unauthorized node joins |
| | Authentication | Missing | Critical | Configure strong Redis password (64-character random string) stored in AWS Secrets Manager |
| | Monitoring/Logging | Missing | Medium | 1. Enable Redis slow log (`slowlog-log-slower-than 10000`)<br>2. Monitor AUTH failures with CloudWatch alarms<br>3. Export metrics to Prometheus for anomaly detection |
| | Backup/Recovery | Missing | Medium | 1. Enable ElastiCache automated backups (daily)<br>2. Document: Redis is cache only, data loss acceptable<br>3. Implement cache warming on cold start |
```

**Risk Level**: Significant - Session data and potentially PHI at risk without access controls

---

### S3. Amazon S3 Bucket Security Controls Inadequate (Infrastructure Security)

**Section Reference**: 2.2 Database (Document Storage: Amazon S3)

**Issue Description**:
§2.2 lists "Amazon S3 (us-east-1)" but provides no security specifications. §5.4 mentions pre-signed URLs but bucket-level security is unspecified.

**Gaps Identified**:
- **Missing**: Public access block configuration
- **Missing**: Bucket versioning (required for HIPAA business continuity)
- **Missing**: Object lock configuration (immutability for audit logs)
- **Missing**: Access logging
- **Missing**: Cross-region replication for disaster recovery
- **Missing**: Lifecycle policies for HIPAA retention (6-year minimum)

**Impact**:
- **Data Breach**: Misconfigured bucket policy could expose all medical documents publicly
- **Compliance Failure**: Without versioning and lifecycle policies, cannot meet HIPAA 6-year retention requirement

**Recommendation**:
```
| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| Amazon S3 (Medical Docs) | Access Control | Unspecified | Critical | 1. Enable Block Public Access (all 4 settings)<br>2. Bucket policy: deny all access except from VPC endpoint<br>3. Require MFA for object deletion<br>4. Use separate buckets per data classification (PHI vs. non-PHI) |
| | Encryption (at rest) | Unspecified | High | 1. Enable default encryption: AES-256 (SSE-S3) minimum, SSE-KMS preferred<br>2. Use customer-managed KMS key for audit trail<br>3. Deny unencrypted object uploads: `s3:x-amz-server-side-encryption` condition |
| | Encryption (in transit) | Unspecified | Critical | Enforce HTTPS-only (see C5 recommendation) |
| | Network Isolation | Unspecified | Medium | 1. Create VPC endpoint for S3<br>2. Bucket policy: allow access only from VPC endpoint<br>3. Disable direct internet access to bucket |
| | Authentication | Partial | Medium | Pre-signed URLs specified but add: 1. Short expiration (5 minutes for uploads, 15 minutes for downloads)<br>2. Require JWT validation before generating pre-signed URL<br>3. Log all pre-signed URL generation events |
| | Monitoring/Logging | Missing | High | 1. Enable S3 access logging to separate audit bucket<br>2. Enable CloudTrail data events for PutObject/GetObject<br>3. Monitor for: bulk downloads, deletion events, public access changes |
| | Backup/Recovery | Missing | High | 1. Enable versioning on all buckets (HIPAA requirement)<br>2. Configure cross-region replication to us-west-2<br>3. Lifecycle policy: transition to Glacier after 1 year, retain 7 years total<br>4. Enable S3 Object Lock for audit logs (compliance mode) |
```

**Risk Level**: Significant - Direct exposure risk for all patient medical documents

---

### S4. Elasticsearch Security Controls Completely Missing (Infrastructure Security)

**Section Reference**: 2.2 Database (Search Engine: Elasticsearch 8.6)

**Issue Description**:
Elasticsearch is listed for search functionality but has **zero security specifications**. Elasticsearch likely indexes PHI for search (patient names, provider names, consultation notes).

**Gaps Identified**:
- **Missing**: Authentication and authorization (X-Pack Security)
- **Missing**: Encryption at rest and in transit
- **Missing**: Network isolation
- **Missing**: Index-level access controls
- **Missing**: Audit logging
- **Missing**: Data classification (what PHI is indexed?)

**Impact**:
- **PHI Breach**: Unsecured Elasticsearch cluster is searchable by anyone with network access
- **Historical Risk**: Elasticsearch clusters are frequent targets of ransomware (Meow attack campaign)

**Recommendation**:
```
| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| Elasticsearch 8.6 | Access Control | Missing | Critical | 1. Enable X-Pack Security (included in Elasticsearch 8.6)<br>2. Create role-based access: read-only for consultation search, write for indexing service<br>3. Implement field-level security: mask SSNs, full names in search results<br>4. Use API keys with IP restrictions per microservice |
| | Encryption (at rest) | Missing | High | 1. Enable encryption at rest for Elasticsearch data directory<br>2. Use encrypted EBS volumes for AWS deployment<br>3. Consider AWS OpenSearch Service with encryption enabled |
| | Encryption (in transit) | Missing | Critical | 1. Enable HTTPS for all Elasticsearch API calls<br>2. Configure TLS 1.3 with valid certificates<br>3. Disable HTTP port (9200) and use HTTPS port only (9243) |
| | Network Isolation | Missing | Critical | 1. Deploy in private VPC subnet<br>2. Security group: allow ports 9243 (HTTPS) and 9343 (transport) only from EKS nodes<br>3. Disable discovery via multicast |
| | Authentication | Missing | Critical | 1. Enable X-Pack authentication with unique passwords per service<br>2. Integrate with Kong API Gateway for centralized auth<br>3. Rotate Elasticsearch passwords every 90 days |
| | Monitoring/Logging | Missing | High | 1. Enable Elasticsearch audit logging (X-Pack Audit)<br>2. Log: authentication failures, index creation/deletion, search queries with usernames<br>3. Export audit logs to separate S3 bucket |
| | Backup/Recovery | Partial | Medium | 3-node cluster with replication specified but add: 1. Automated snapshots to S3 (daily)<br>2. Cross-region snapshot replication<br>3. Verify snapshot restoration (monthly testing) |
```

**Risk Level**: Significant - Searchable PHI database with no access controls

---

### S5. Kong API Gateway Security Configuration Underspecified (Infrastructure Security)

**Section Reference**: 3.2 Component Responsibilities (API Gateway: Kong 3.2)

**Issue Description**:
Kong API Gateway is listed with rate limiting (100 req/min per IP) but lacks comprehensive security configuration specifications.

**Gaps Identified**:
- **Missing**: TLS termination configuration (certificate management, cipher suites)
- **Missing**: JWT validation configuration (signature verification, token expiration enforcement)
- **Missing**: Request/response transformation security (header sanitization)
- **Missing**: DDoS protection mechanisms beyond basic rate limiting
- **Missing**: Geographic blocking capabilities (HIPAA may require US-only access)
- **Missing**: Kong admin API security

**Impact**:
- **Gateway Bypass**: Misconfigured Kong could allow unauthenticated access to backend services
- **Admin API Exposure**: Unsecured Kong admin API allows complete gateway reconfiguration

**Recommendation**:
```
| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| Kong API Gateway 3.2 | Access Control | Partial | High | 1. Separate Kong data plane (public) from control plane (admin API in private network)<br>2. Admin API: IP whitelist only from bastion host, require mTLS<br>3. Implement Kong RBAC for multi-admin scenarios |
| | Encryption (at rest) | N/A | N/A | Stateless component (uses PostgreSQL for config) |
| | Encryption (in transit) | Unspecified | Critical | 1. TLS termination: use Let's Encrypt with auto-renewal or AWS ACM<br>2. Cipher suites: TLS_AES_128_GCM_SHA256, TLS_AES_256_GCM_SHA384 only<br>3. HSTS header: `Strict-Transport-Security: max-age=31536000; includeSubDomains`<br>4. Backend communication: enforce HTTPS to microservices (no HTTP fallback) |
| | Network Isolation | Unspecified | Medium | 1. Deploy in public subnet (for internet-facing API) with security group<br>2. Backend communication through private subnet only<br>3. Use AWS Network Load Balancer with TLS passthrough |
| | Authentication | Partial | High | 1. Kong JWT plugin: configure to validate signature against JWKS endpoint<br>2. Enforce token expiration: reject tokens older than 24 hours<br>3. Implement token blacklist in Redis for revoked tokens<br>4. Add Kong Basic Auth plugin for internal microservice-to-microservice calls |
| | Monitoring/Logging | Unspecified | Medium | 1. Enable Kong logging plugin (file or syslog)<br>2. Log: request_id, user_id (from JWT), endpoint, status_code, response_time, client_ip<br>3. Export logs to CloudWatch for centralized monitoring<br>4. Alert on: 401/403 spikes, 5xx errors, rate limit violations |
| | Backup/Recovery | Unspecified | Low | 1. Kong config stored in PostgreSQL - backup covered by database backups<br>2. Maintain Kong declarative config in Git (Infrastructure as Code)<br>3. Implement blue-green deployment for zero-downtime updates |
```

**Risk Level**: Significant - Gateway is single point of failure for all authentication/authorization

---

### S6. Full Request Body Logging Exposes PHI (Logging Policy)

**Section Reference**: 6.2 Logging

**Issue Description**:
§6.2 explicitly states "full request bodies are logged for debugging" with only password masking. This directly violates HIPAA minimum necessary principle.

**Impact**:
- **HIPAA Violation**: Logging full request bodies captures PHI in application logs (patient names, consultation notes, medication details)
- **Breach Amplification**: If application logs are compromised, attacker gains access to all historical PHI (not just current database state)
- **Compliance Risk**: OCR audit would identify this as willful neglect (Tier 4 penalty: $50,000 per violation)

**Recommendation**:
```
REVISED LOGGING POLICY:

1. Request Body Logging - Selective Approach:

   NEVER LOG (even in development):
   - POST /api/consultations → consultation notes, reason
   - POST /api/prescriptions → medication_name, dosage
   - PATCH /api/consultations/:id → notes field
   - Any field identified as PHI in data model

   LOG ONLY METADATA:
   - Logged: { "endpoint": "/api/consultations", "patient_id": "<hash>", "provider_id": "<hash>", "scheduled_at": "2026-02-10T10:00:00Z", "body_size": 1024 }
   - NOT logged: { "reason": "chest pain and shortness of breath" }

2. Structured Logging Format:
   {
     "timestamp": "2026-02-10T10:30:45.123Z",
     "request_id": "uuid",
     "user_id_hash": "SHA256(user_id)",
     "endpoint": "/api/prescriptions",
     "method": "POST",
     "status_code": 201,
     "response_time_ms": 145,
     "client_ip_anonymized": "192.168.1.0/24",
     "phi_accessed": true,  // boolean flag for audit purposes
     "body_size": 512
   }

3. Development Environment Logging:
   - Use separate logging level: "DEBUG_PHI" that is NEVER enabled in production
   - Require explicit opt-in per developer workstation (not in shared configs)
   - Display WARNING banner in terminal when DEBUG_PHI logging is enabled

4. Log Sanitization Function:
   function sanitizeRequestBody(endpoint, body) {
     const phiEndpoints = ['/api/consultations', '/api/prescriptions', '/api/documents'];
     if (phiEndpoints.some(e => endpoint.startsWith(e))) {
       return { sanitized: true, endpoint, body_keys: Object.keys(body) };
     }
     return body;  // Log full body only for non-PHI endpoints
   }
```

**Risk Level**: Significant - Direct HIPAA violation, creates secondary PHI exposure vector

---

## Moderate Issues (Score 3/5)

### M1. Third-Party Dependency Security Not Specified (Supply Chain Security)

**Section Reference**: 2.4 Key Libraries

**Issue Description**:
§2.4 lists critical security libraries (jsonwebtoken, bcrypt, stripe) but provides no dependency management security policies.

**Gaps Identified**:
- **Missing**: Dependency vulnerability scanning process
- **Missing**: Dependency pinning policy (exact versions vs. semver ranges)
- **Missing**: Dependency update review process
- **Missing**: License compliance verification
- **Missing**: Private npm registry for internal packages

**Impact**:
- **Supply Chain Attack**: Compromised npm packages can inject malicious code (e.g., event-stream incident)
- **Vulnerable Dependencies**: Outdated libraries with known CVEs (e.g., jsonwebtoken <9.0.0 has algorithm confusion vulnerability)

**Recommendation**:
```
DEPENDENCY SECURITY POLICY:

1. Automated Vulnerability Scanning:
   - Integrate npm audit in CI/CD pipeline (fail build on high/critical vulnerabilities)
   - Use Snyk or GitHub Dependabot for continuous monitoring
   - Weekly automated dependency update PRs

2. Dependency Pinning:
   - Use exact versions in package.json (no ^ or ~ prefixes)
   - Lock file: commit package-lock.json to Git and verify integrity in CI
   - Rationale: Prevents unexpected updates with security regressions

3. Dependency Review Process:
   - Manual review required for: major version updates, new dependencies, any dependency with >10M weekly downloads
   - Review criteria: license compatibility (MIT/Apache 2.0), last commit date (<6 months), maintainer reputation

4. Critical Dependencies - Extra Scrutiny:
   - jsonwebtoken: Pin to 9.0.2+, verify no algorithm confusion vulnerability
   - bcrypt: Pin to 5.1.0+, verify no timing attack vulnerabilities
   - stripe: Keep updated for PCI DSS compliance

5. Private Registry:
   - Host private npm registry (e.g., Verdaccio) for internal packages
   - Proxy public npm through private registry for audit trail
   - Cache packages to prevent disappearance attacks (left-pad incident)
```

**Risk Level**: Moderate - Indirect attack vector, but healthcare applications are high-value targets

---

### M2. Jitsi Meet Security Configuration Not Specified (Infrastructure Security)

**Section Reference**: 2.1 Backend (WebRTC Server: Jitsi Meet self-hosted)

**Issue Description**:
Self-hosted Jitsi Meet is listed for video consultations but provides no security configuration details. Jitsi handles real-time PHI (video/audio of medical consultations).

**Gaps Identified**:
- **Missing**: Authentication integration with HealthHub (JWT verification)
- **Missing**: Room access controls (who can join consultations?)
- **Missing**: Recording encryption and storage policy
- **Missing**: Network isolation (STUN/TURN server configuration)
- **Missing**: WebRTC signaling security

**Impact**:
- **Unauthorized Access**: Without room access controls, attacker can join consultations by guessing room IDs
- **PHI Exposure**: Unencrypted recordings violate HIPAA

**Recommendation**:
```
| Component | Security Aspect | Status | Risk | Recommendation |
|-----------|-----------------|--------|------|----------------|
| Jitsi Meet (WebRTC) | Access Control | Missing | High | 1. Enable Jitsi JWT authentication (verify HealthHub JWT before allowing room join)<br>2. Room naming: use cryptographically random room IDs (UUID v4), not predictable names<br>3. Implement waiting room: provider must admit patient to consultation |
| | Encryption (at rest) | Missing | High | 1. Recording storage: upload to S3 with SSE-KMS encryption<br>2. Store recording URLs in consultation table (§4.1) with access controls<br>3. Automatic recording deletion after 7 years (HIPAA retention) |
| | Encryption (in transit) | Unspecified | Medium | 1. Enforce DTLS-SRTP for WebRTC media encryption (enabled by default in Jitsi)<br>2. TLS 1.3 for signaling (WebSocket connections)<br>3. Verify end-to-end encryption enabled for peer-to-peer mode |
| | Network Isolation | Missing | Medium | 1. Deploy Jitsi in private VPC subnet<br>2. TURN server: dedicated EC2 instances with security group allowing UDP ports 10000-20000 from anywhere (required for WebRTC)<br>3. STUN server: use Google STUN (stun.l.google.com) for NAT traversal |
| | Authentication | Missing | High | Integrate Jitsi with HealthHub JWT (see Access Control) - pass JWT in room URL query parameter |
| | Monitoring/Logging | Missing | Medium | 1. Log: room creation, participant join/leave, recording start/stop<br>2. Monitor: concurrent consultation count, bandwidth usage, failed authentication attempts<br>3. Alert on: >5 participants in room (should only be patient + provider), recording failures |
| | Backup/Recovery | N/A | N/A | Real-time service - no backup needed (recordings backed up separately) |
```

**Risk Level**: Moderate - Video consultations contain PHI, but attack requires active targeting

---

### M3. Database Migration Automation Security Risk (Deployment Process)

**Section Reference**: 6.4 Deployment

**Issue Description**:
§6.4 states "Database migrations run automatically on deployment via Flyway" without specifying:
- What happens if migration fails mid-deployment?
- Who can create/approve migrations?
- Are migrations tested on staging before production?
- Rollback procedure for failed migrations

**Impact**:
- **Data Loss**: Destructive migrations (DROP COLUMN) executed automatically without validation could delete PHI
- **Downtime**: Failed migration locks database, preventing all API access
- **Audit Gap**: No approval trail for schema changes affecting PHI storage

**Recommendation**:
```
SECURE DATABASE MIGRATION POLICY:

1. Migration Review Process:
   - All migrations require: code review by senior engineer + security review for PHI-affecting changes
   - Destructive operations (DROP, DELETE) require: written approval from data protection officer
   - Store migrations in Git with commit message explaining business rationale

2. Staging Validation:
   - Mandatory testing: all migrations must run successfully on staging environment 24 hours before production
   - Validate: no data loss, no performance regression, no breaking changes to existing APIs

3. Production Migration Execution:
   - Separate migration job from application deployment (decouple schema changes from code changes)
   - Use database transactions where possible (PostgreSQL supports transactional DDL)
   - Backup database immediately before migration execution
   - Automated rollback: if migration fails, restore from backup automatically

4. Migration Monitoring:
   - Track migration execution time (alert if >30 seconds, may indicate table lock)
   - Log migration success/failure to audit log
   - Send Slack notification on production migration completion

5. Emergency Rollback:
   - Document rollback procedure for last 5 migrations in runbook
   - Test rollback procedure quarterly (disaster recovery drill)
   - Example: If migration adds column, rollback script drops column
```

**Risk Level**: Moderate - Indirect risk, but PHI data loss would be catastrophic

---

### M4. Environment Variable Security in Kubernetes ConfigMaps (Secret Management)

**Section Reference**: 6.4 Deployment

**Issue Description**:
§6.4 states "Environment variables managed in Kubernetes ConfigMaps" but ConfigMaps are **not encrypted** and should not store secrets. This contradicts the next sentence stating "Secrets stored in AWS Secrets Manager".

**Gap**: Design does not clarify which environment variables go in ConfigMaps (non-sensitive) vs. Secrets Manager (sensitive).

**Impact**:
- **Credential Exposure**: If database passwords or JWT signing keys are accidentally stored in ConfigMaps, they are readable by anyone with Kubernetes API access
- **Git Leak Risk**: ConfigMaps are often committed to Git (Infrastructure as Code), exposing secrets in version control

**Recommendation**:
```
KUBERNETES SECRET MANAGEMENT POLICY:

1. Classification of Environment Variables:

   CONFIGMAPS (non-sensitive, can be committed to Git):
   - NODE_ENV=production
   - LOG_LEVEL=info
   - API_GATEWAY_URL=https://api.healthhub.com
   - DATABASE_HOST=postgres.healthhub.internal (hostname only, no credentials)

   AWS SECRETS MANAGER (sensitive, never in Git):
   - DATABASE_PASSWORD
   - JWT_SIGNING_KEY
   - REDIS_PASSWORD
   - STRIPE_API_KEY
   - SURESCRIPTS_API_KEY

2. Secrets Injection into Pods:
   - Use External Secrets Operator or AWS Secrets Store CSI Driver
   - Mount secrets as files in /etc/secrets/ (not environment variables)
   - Rationale: Environment variables visible in process list, files have stricter permissions

3. Secret Rotation:
   - Automated rotation every 90 days for: database passwords, JWT keys, API keys
   - Use AWS Secrets Manager automatic rotation feature
   - On rotation: rolling restart of Kubernetes pods to reload secrets

4. Access Control:
   - Kubernetes RBAC: restrict access to ConfigMaps/Secrets to ServiceAccount per namespace
   - AWS IAM: grant secret read permission only to EKS node IAM role
   - Audit: log all secret read operations in CloudTrail
```

**Risk Level**: Moderate - Common misconfiguration, but AWS Secrets Manager usage suggests awareness

---

### M5. Stripe Webhook Signature Validation Specified but Insufficient Details (Third-Party Integration Security)

**Section Reference**: 8.2 Payment Processing

**Issue Description**:
§8.2 states webhook endpoint "validates signature with webhook secret" but does not specify:
- Replay attack prevention (timestamp validation)
- What happens if signature validation fails (logging, alerting)
- Webhook retry handling (idempotency)

**Impact**:
- **Payment Fraud**: Attacker replays old webhook event to mark unpaid consultation as paid
- **Audit Gap**: Failed validation attempts not logged, preventing fraud detection

**Recommendation**:
```
STRIPE WEBHOOK SECURITY SPECIFICATION:

1. Signature Validation (expand existing specification):
   POST /api/webhooks/stripe
   - Verify Stripe-Signature header using webhook secret (already specified)
   - Validate timestamp: reject events older than 5 minutes (prevent replay attacks)
   - Code example:
     const event = stripe.webhooks.constructEvent(
       req.body, req.headers['stripe-signature'], webhookSecret
     );
     if (Date.now() - event.created * 1000 > 300000) {
       throw new Error('Webhook event too old');
     }

2. Idempotency Handling:
   - Store processed event IDs in Redis with 24-hour TTL
   - Key: "stripe_event:{event_id}" → "processed"
   - On duplicate event: return 200 OK immediately (already processed)
   - Rationale: Stripe retries webhooks on non-2xx response

3. Failure Handling:
   - Log all validation failures with: timestamp, source IP, event_id, failure reason
   - Alert security team on: >10 validation failures per hour (potential attack)
   - Return 400 Bad Request on validation failure (do not retry)

4. Webhook Endpoint Security:
   - IP whitelist: accept webhooks only from Stripe IP ranges (published at https://stripe.com/files/ips/ips_webhooks.txt)
   - Rate limiting: 100 webhooks per minute per event type
   - Disable endpoint in development/staging (use Stripe CLI for testing)
```

**Risk Level**: Moderate - Payment fraud risk, but Stripe integration is relatively secure

---

### M6. No Security Headers Specified for HTTP Responses (Web Application Security)

**Section Reference**: Missing entirely from design

**Issue Description**:
The design does not specify any security headers for HTTP responses (Content-Security-Policy, X-Frame-Options, etc.). This is especially critical for frontend serving medical consultation interfaces.

**Impact**:
- **Clickjacking**: Attacker embeds HealthHub interface in iframe on malicious site, tricks users into authorizing prescriptions
- **XSS Amplification**: Missing Content-Security-Policy allows inline scripts, increasing XSS attack surface

**Recommendation**:
```
REQUIRED HTTP SECURITY HEADERS:

1. Kong API Gateway Configuration:
   Add response-transformer plugin to inject security headers:

   Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
   - Enforces HTTPS for 1 year

   Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' wss://jitsi.healthhub.com; frame-src 'self' https://jitsi.healthhub.com; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'
   - Prevents inline scripts, restricts resource loading
   - Allows WebRTC connections to Jitsi
   - Prevents clickjacking via frame-ancestors 'none'

   X-Content-Type-Options: nosniff
   - Prevents MIME type sniffing attacks

   X-Frame-Options: DENY
   - Additional clickjacking protection

   Referrer-Policy: no-referrer
   - Prevents leaking sensitive URLs in Referer header

   Permissions-Policy: geolocation=(), microphone=(self), camera=(self), payment=()
   - Limits browser feature access (allow camera/mic for consultations)

2. Custom Headers:
   X-Content-Type-Options: nosniff
   X-XSS-Protection: 1; mode=block (legacy browsers)
```

**Risk Level**: Moderate - Defense-in-depth measure, not direct vulnerability

---

### M7. Provider License Verification Process Not Specified (Business Logic Security)

**Section Reference**: 4.1 Provider Table (verified BOOLEAN)

**Issue Description**:
§4.1 includes "verified BOOLEAN" field for provider licenses but design does not specify:
- Who performs verification (manual admin review? automated API check?)
- What documents are required (license scan, DEA certificate?)
- How often is re-verification performed?
- Can unverified providers access patient data?

**Impact**:
- **Fraudulent Providers**: Without robust verification, attackers can register as providers and access patient PHI
- **Regulatory Risk**: State medical boards require license verification for telemedicine platforms

**Recommendation**:
```
PROVIDER VERIFICATION SPECIFICATION:

1. Verification Workflow:
   - On provider registration: require upload of medical license scan (PDF/JPG) to S3
   - Admin review: care coordinator verifies license against state medical board database (e.g., NPDB)
   - Automated check: integrate with National Practitioner Data Bank API (if available)
   - Approval: set verified=true in provider table, send email notification

2. Required Documents:
   - State medical license (MD, DO, NP, PA)
   - DEA certificate (for providers prescribing controlled substances)
   - Malpractice insurance certificate
   - Professional liability insurance (minimum $1M/$3M coverage)

3. Re-verification Schedule:
   - Annual re-verification required (licenses expire)
   - Automated email reminder 30 days before license expiration
   - On failure to re-verify: set verified=false, disable provider account

4. Access Controls:
   - Unverified providers: cannot access patient data, cannot schedule consultations, cannot issue prescriptions
   - Display banner on unverified provider dashboard: "Account pending verification"
   - Audit: log all verification state changes with admin user_id
```

**Risk Level**: Moderate - Business logic gap, but fraud detection should catch fake providers

---

### M8. EHR Integration OAuth 2.0 Token Storage Not Specified (Third-Party Integration Security)

**Section Reference**: 8.4 EHR Integration

**Issue Description**:
§8.4 states EHR integration uses "OAuth 2.0 client credentials flow" but does not specify:
- Where are client credentials stored? (Secrets Manager? Kubernetes secrets?)
- Where are access tokens cached? (Redis? In-memory?)
- Token refresh logic?
- Token scope restrictions?

**Impact**:
- **Excessive Permissions**: If EHR access token has overly broad scope, compromised token allows access to all patients' EHRs (not just HealthHub patients)
- **Token Leakage**: If tokens stored insecurely, attacker can access external EHR systems

**Recommendation**:
```
EHR INTEGRATION SECURITY SPECIFICATION:

1. Credential Storage:
   - Client ID: store in Kubernetes ConfigMap (non-sensitive)
   - Client Secret: store in AWS Secrets Manager
   - Rotate client secret annually (coordinate with EHR provider)

2. Access Token Management:
   - Cache access tokens in Redis with TTL matching token expiration
   - Key pattern: "ehr_token:{tenant_id}" → {access_token, expires_at}
   - Refresh tokens: store in AWS Secrets Manager (long-lived credentials)

3. Token Refresh Logic:
   - Proactive refresh: renew token 5 minutes before expiration
   - On API error (401 Unauthorized): refresh token and retry request once
   - On refresh failure: alert engineering team, fall back to manual EHR entry

4. Scope Restrictions:
   - Request minimum necessary scopes: patient/*.read, MedicationRequest.write
   - Avoid: patient/*.* (wildcard), user/*.* (administrative scopes)
   - Validate scope in OAuth response matches requested scope

5. Rate Limit Handling:
   - EHR API limits: 100 req/min per tenant (§8.4)
   - Implement exponential backoff on 429 Too Many Requests
   - Queue non-urgent EHR writes (e.g., consultation notes sync) for batch processing
```

**Risk Level**: Moderate - Third-party integration, limited blast radius

---

## Minor Improvements & Positive Aspects

### Positive Security Aspects

1. **HIPAA Compliance Awareness** (§7.4): Design explicitly calls out HIPAA, GDPR, and SOC 2 Type II requirements, demonstrating security consciousness
2. **JWT Token Expiration** (§5.1): 24-hour token expiration specified (though storage mechanism is insecure)
3. **2FA for Providers** (§7.2): Mandatory 2FA for provider accounts reduces credential theft risk
4. **Database Encryption at Rest** (§7.2): AWS RDS encryption enabled
5. **TLS 1.2+ for External Communication** (§7.2): Modern TLS version enforced
6. **Pre-signed S3 URLs** (§5.4): Time-limited document access (15 minutes) reduces exposure window
7. **Password Hashing with bcrypt** (§2.4): Industry-standard password hashing (though password policy is weak)
8. **DEA Controlled Substance Check** (§5.3): Prescription API validates against DEA list
9. **Separate Microservices Architecture** (§3.1): Reduces blast radius of service-level compromise
10. **Multi-region Deployment** (§7.3): Active-passive disaster recovery improves availability

### Minor Improvements

1. **Session Invalidation on Login** (§7.2): "New login invalidates previous token" - consider allowing multiple active sessions for mobile + web use cases
2. **Database Read Replicas** (§7.3): Consider encrypting replication traffic (currently unspecified)
3. **Prometheus/Grafana Monitoring** (§2.3): Add security-focused dashboards (failed logins, authorization denials)
4. **GitHub Actions CI/CD** (§2.3): Implement SAST scanning (e.g., Semgrep, CodeQL) in pipeline
5. **Blue-Green Deployment** (§6.4): Consider canary deployments for gradual rollout with security monitoring

---

## Summary Recommendations by Priority

### Immediate Action Required (Pre-Launch Blockers):
1. **Migrate JWT storage from localStorage to httpOnly cookies** (C1)
2. **Implement CSRF protection** (C2)
3. **Define comprehensive audit logging specification** (C3)
4. **Add idempotency keys to prescription API** (C4)
5. **Enforce HTTPS for S3 pre-signed URLs** (C5)
6. **Add password reset token expiration** (C6)
7. **Strengthen password policy to 12+ characters** (C7)
8. **Remove stack traces from all environments except local development** (C8)
9. **Implement tiered rate limiting per endpoint** (C9)

### High Priority (Complete Before HIPAA Audit):
1. **Specify complete infrastructure security table for all components** (S1-S6)
2. **Revise logging policy to exclude PHI from application logs** (S6)
3. **Define dependency security scanning and update process** (M1)
4. **Secure Jitsi Meet WebRTC configuration** (M2)

### Medium Priority (Include in Security Roadmap):
1. **Database migration review and rollback procedures** (M3)
2. **Kubernetes secret management clarification** (M4)
3. **Enhanced Stripe webhook security** (M5)
4. **HTTP security headers** (M6)
5. **Provider verification workflow** (M7)
6. **EHR integration token management** (M8)

---

## Conclusion

The HealthHub telemedicine platform design demonstrates awareness of healthcare security requirements (HIPAA compliance mentions, 2FA for providers, encryption at rest) but exhibits **critical security design gaps** that must be addressed before production deployment.

**The most severe issue is insecure JWT token storage in localStorage (C1)**, which enables trivial XSS-based account takeover in a healthcare application handling highly sensitive PHI. This must be remediated immediately alongside CSRF protection (C2) and comprehensive audit logging (C3).

Infrastructure security specifications are largely absent—while components like PostgreSQL, Redis, S3, Elasticsearch, and Jitsi Meet are listed, critical security configurations (access controls, encryption in transit, network isolation) are unspecified. This creates significant HIPAA compliance risk.

**Recommended immediate actions:**
1. Conduct security design review workshop to address all Critical (C1-C9) issues
2. Create comprehensive infrastructure security specification using tabular format
3. Implement HIPAA-compliant audit logging before beta launch
4. Engage third-party HIPAA security consultant for design validation
5. Schedule penetration testing only AFTER addressing C1-C9 issues

**Overall Security Posture: Inadequate for production healthcare application.** With critical issues resolved, platform could achieve acceptable security baseline for beta launch with limited user base.
