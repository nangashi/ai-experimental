# Security Design Review: TaskFlow システム設計書

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple STRIDE categories lack explicit countermeasures, particularly repudiation, denial of service, and elevation of privilege |
| Authentication & Authorization Design | 2 | JWT in localStorage is vulnerable to XSS, 24-hour token expiration is excessive, no refresh token mechanism, missing session revocation |
| Data Protection | 2 | No encryption at rest specified, missing data retention/deletion policies, no PII handling procedures, missing backup encryption |
| Input Validation Design | 3 | Basic validation exists but lacks comprehensive policies for file uploads, API inputs, and injection prevention strategies beyond ORM usage |
| Infrastructure & Dependencies | 3 | Third-party libraries mentioned but no security vetting process, secrets management not specified, missing security headers and CORS details |
| **Overall** | **2.4** | |

---

## 1. Critical Issues (design modification required)

### 1-1. JWT Token Storage in localStorage is Dangerous

**Problem Description**: Section 5 states "トークン格納: ブラウザのlocalStorageに保存" with a 24-hour expiration period.

**Impact**:
- localStorage is accessible to any JavaScript code, making tokens vulnerable to XSS attacks
- If even one XSS vulnerability exists anywhere in the application, attackers can steal tokens valid for 24 hours
- Complete account takeover is possible during the token validity period
- No mechanism exists to revoke compromised tokens before expiration

**Recommended Countermeasures**:
1. Switch to HttpOnly + Secure + SameSite=Strict cookies for token storage
2. Reduce access token expiration to 15 minutes
3. Implement refresh token mechanism (7-day expiration with rotation on each use)
4. Add token revocation capability (blacklist in Redis with TTL)
5. Implement device/session management so users can view and revoke active sessions

**Relevant Section**: Section 5 - API設計 - 認証・認可方式

---

### 1-2. Missing Authentication Brute-Force Protection

**Problem Description**: No rate limiting or account lockout mechanism is designed for authentication endpoints (`/api/v1/auth/login`, `/api/v1/auth/signup`).

**Impact**:
- Attackers can perform unlimited brute-force attacks on user passwords
- Credential stuffing attacks using leaked password databases are feasible
- No protection against automated account creation abuse

**Recommended Countermeasures**:
1. Implement rate limiting for login endpoint: 5 attempts per 15 minutes per IP + email combination
2. Add progressive delay after failed attempts (exponential backoff)
3. Implement account lockout after 5 consecutive failures (30-minute duration)
4. Add CAPTCHA after 3 failed attempts to prevent automated attacks
5. Log and alert on suspicious patterns (many failures from single IP)

**Relevant Section**: Section 5 - API設計 - 認証関連

---

### 1-3. Missing CSRF Protection Design

**Problem Description**: No CSRF (Cross-Site Request Forgery) protection mechanism is mentioned for state-changing API endpoints.

**Impact**:
- Attackers can trick authenticated users into performing unintended actions (create/delete projects, modify tasks, upload malicious files)
- Particularly dangerous for destructive operations like `DELETE /api/v1/projects/:id`

**Recommended Countermeasures**:
1. Implement Double Submit Cookie pattern or Synchronizer Token pattern
2. Apply CSRF token validation middleware to all POST/PUT/DELETE endpoints
3. Configure SameSite=Strict for all cookies as additional defense layer
4. Consider using `csurf` middleware (v1.11.0) for Express.js

**Relevant Section**: Section 5 - API設計 (all state-changing endpoints)

---

### 1-4. Insufficient File Upload Security Design

**Problem Description**: File upload is limited to 10MB but lacks comprehensive security controls.

**Impact**:
- Malicious file uploads can lead to code execution, XSS via HTML files, or malware distribution
- No validation of file content vs. declared MIME type (magic byte check missing)
- Missing virus/malware scanning
- No access control for viewing uploaded files

**Recommended Countermeasures**:
1. Implement file type whitelist (allow only specific extensions and MIME types)
2. Add magic byte verification to prevent MIME type spoofing
3. Scan all uploads with antivirus (integrate ClamAV or AWS GuardDuty Malware Protection)
4. Store files with randomized names (prevent path traversal and predictable URLs)
5. Implement signed URLs with expiration for S3 access (not public URLs)
6. Add Content-Disposition: attachment header to prevent browser execution
7. Validate image files with `sharp` library (already in tech stack) to detect malformed images

**Relevant Section**: Section 5 - API設計 - ドキュメント管理, Section 2 - 主要ライブラリ (multer, sharp)

---

### 1-5. Missing Secrets Management Specification

**Problem Description**: No design for managing sensitive credentials (database passwords, JWT signing keys, AWS access keys, third-party API keys).

**Impact**:
- Hardcoded secrets in code or environment variables can leak via version control
- Key rotation is difficult without defined procedures
- Compromised keys cannot be quickly revoked and rotated

**Recommended Countermeasures**:
1. Use AWS Secrets Manager or AWS Systems Manager Parameter Store for all secrets
2. Implement automatic secret rotation (90-day cycle for JWT signing keys, database credentials)
3. Use IAM roles for AWS service authentication (EKS pod identity)
4. Never commit secrets to version control (add .env files to .gitignore)
5. Implement secret version control and rollback capability
6. Use different secrets per environment (dev/staging/prod)

**Relevant Section**: Section 2 - インフラ・デプロイ環境, Section 6 - デプロイメント方針

---

### 1-6. Missing Audit Logging Design

**Problem Description**: Logging policy covers technical events (API calls, errors) but lacks security audit logging for compliance and incident investigation.

**Impact**:
- Cannot track who accessed/modified sensitive data
- Difficult to investigate security incidents or insider threats
- Non-compliance with regulations requiring audit trails (GDPR, SOC2)

**Recommended Countermeasures**:
1. Log all authentication events (login success/failure, logout, token refresh)
2. Log all authorization failures (403 responses with user ID, resource, action attempted)
3. Log all data modifications (who changed what, when, old/new values for critical fields)
4. Log administrative actions (role changes, user deletion, organization settings)
5. Log file access (document downloads with user ID, timestamp, file ID)
6. Store audit logs separately from application logs with strict access control
7. Define retention period (7 years for compliance) with tamper-proof storage
8. Implement log integrity verification (hash chains or AWS CloudWatch Logs Insights)

**Relevant Section**: Section 6 - ロギング方針

---

### 1-7. Missing Data Encryption at Rest

**Problem Description**: No specification for encrypting sensitive data in PostgreSQL and S3.

**Impact**:
- If database backups or S3 buckets are compromised, all data is exposed in plaintext
- Password hashes, user PII, project data, uploaded documents are at risk
- Non-compliance with data protection regulations

**Recommended Countermeasures**:
1. Enable PostgreSQL encryption at rest (AWS RDS encryption)
2. Enable S3 bucket encryption with AWS KMS (SSE-KMS)
3. Use customer-managed KMS keys (not AWS-managed) for key rotation control
4. Encrypt database backups with separate keys
5. Document key management procedures (rotation, access control, backup)

**Relevant Section**: Section 2 - データベース, Section 2 - インフラ・デプロイ環境 (S3)

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2-1. Missing Idempotency Guarantees for State-Changing Operations

**Suggestion Description**: No idempotency design for critical operations like project creation, task updates, or payment processing (if added in future).

**Rationale**:
- Network retries can cause duplicate resource creation
- Client-side retry logic may trigger same operation multiple times
- Particularly critical for future payment/billing features

**Recommended Countermeasures**:
1. Add `idempotency_key` header support for POST/PUT/DELETE endpoints
2. Store idempotency keys in Redis with 24-hour TTL
3. Return cached response for duplicate requests within TTL window
4. Use database transactions with unique constraints to prevent duplicates
5. Document idempotency guarantees in API specification

**Relevant Section**: Section 5 - API設計

---

### 2-2. Missing Rate Limiting for General API Endpoints

**Suggestion Description**: Rate limiting is mentioned in API Gateway responsibilities but lacks specific configuration.

**Rationale**:
- Prevents abuse and DoS attacks on public endpoints
- Protects backend resources from excessive load
- Different endpoints require different limits (read vs. write operations)

**Recommended Countermeasures**:
1. Implement tiered rate limiting based on user plan (free: 100 req/min, pro: 500 req/min, enterprise: 2000 req/min)
2. Stricter limits for write operations (POST/PUT/DELETE: 20 req/min)
3. Separate limits for expensive operations (report generation, file uploads)
4. Use Redis for distributed rate limiting across multiple pods
5. Return 429 status with Retry-After header
6. Consider `express-rate-limit` library (v7.1.0)

**Relevant Section**: Section 3 - 主要コンポーネントの責務 (API Gateway)

---

### 2-3. Insufficient Input Validation Policy

**Suggestion Description**: Validation exists (`express-validator`) but lacks comprehensive policies for all input types.

**Rationale**:
- Prevents injection attacks, data corruption, and application errors
- Centralized validation rules improve maintainability

**Recommended Countermeasures**:
1. Define validation schemas for all API endpoints (required fields, types, lengths, formats)
2. Validate UUID format for all ID parameters (prevent injection)
3. Sanitize text inputs (strip HTML tags, limit special characters)
4. Validate email format with strict RFC 5322 compliance
5. Implement maximum length limits for all text fields (title: 500 chars, description: 10000 chars)
6. Validate ENUM values against allowed lists
7. Implement content-type validation (reject non-JSON requests)
8. Add request body size limits (default 100KB, higher for file uploads)

**Relevant Section**: Section 2 - 主要ライブラリ (express-validator), Section 7 - セキュリティ要件

---

### 2-4. Missing Data Retention and Deletion Policy

**Suggestion Description**: No policy for how long data is retained or how to securely delete user/organization data.

**Rationale**:
- GDPR and privacy regulations require data minimization and right to erasure
- Unnecessary data retention increases breach impact

**Recommended Countermeasures**:
1. Define retention periods for each data type (logs: 90 days, deleted projects: 30 days soft delete, backups: 30 days)
2. Implement soft delete for critical resources (set `deleted_at` timestamp, filter from queries)
3. Implement hard delete job for data beyond retention period
4. Support user data export (GDPR right to portability)
5. Implement secure deletion procedures (overwrite S3 objects, purge from backups)
6. Document data deletion workflow for organization closure

**Relevant Section**: Section 4 - データモデル

---

### 2-5. Missing Security Headers Configuration

**Suggestion Description**: No specification for HTTP security headers.

**Rationale**:
- Security headers provide defense-in-depth against common web attacks
- Simple to implement with high security value

**Recommended Countermeasures**:
1. Content-Security-Policy: restrict resource loading to trusted origins
2. X-Frame-Options: DENY (prevent clickjacking)
3. X-Content-Type-Options: nosniff (prevent MIME sniffing)
4. Strict-Transport-Security: max-age=31536000; includeSubDomains (force HTTPS)
5. Referrer-Policy: strict-origin-when-cross-origin
6. Permissions-Policy: restrict dangerous browser features
7. Use `helmet` middleware (v7.1.0) for Express.js

**Relevant Section**: Section 7 - セキュリティ要件 (HTTPS通信)

---

### 2-6. Insufficient CORS Configuration

**Suggestion Description**: CORS is mentioned in API Gateway responsibilities but lacks specific configuration.

**Rationale**:
- Overly permissive CORS allows unauthorized cross-origin access
- Missing CORS allows credential theft and CSRF attacks

**Recommended Countermeasures**:
1. Whitelist specific origins (no wildcard `*` for production)
2. Set `Access-Control-Allow-Credentials: true` only for trusted origins
3. Limit allowed methods to those actually used
4. Set short `Access-Control-Max-Age` (1 hour) for preflight caching
5. Document CORS policy in API specification

**Relevant Section**: Section 3 - 主要コンポーネントの責務 (API Gateway)

---

### 2-7. Missing Password Complexity Policy

**Suggestion Description**: Passwords are hashed with bcrypt but no complexity requirements are specified.

**Rationale**:
- Weak passwords undermine strong hashing algorithms
- Prevents dictionary and brute-force attacks

**Recommended Countermeasures**:
1. Minimum 12 characters (14+ recommended)
2. Require mix of uppercase, lowercase, numbers, special characters
3. Check against common password lists (Have I Been Pwned API)
4. Prevent password reuse (store hash of last 5 passwords)
5. Implement password strength meter on signup page
6. Enforce password rotation every 90 days for admin accounts

**Relevant Section**: Section 7 - セキュリティ要件 (bcryptハッシュ化)

---

### 2-8. Missing Error Information Disclosure Policy

**Suggestion Description**: Error handling returns generic messages but lacks policy on what information to expose.

**Rationale**:
- Detailed error messages can leak system internals to attackers
- Stack traces in production expose file paths and library versions

**Recommended Countermeasures**:
1. Return generic error messages to clients ("Internal server error" for 500)
2. Never expose stack traces, SQL queries, or file paths in responses
3. Log detailed errors server-side only
4. Use error codes instead of descriptive messages for classification
5. Sanitize error messages to remove sensitive data (email addresses, IDs)
6. Different error detail levels for dev vs. prod environments

**Relevant Section**: Section 6 - エラーハンドリング方針

---

### 2-9. Missing Third-Party Dependency Security Vetting

**Suggestion Description**: Multiple libraries are specified but no security vetting or update process is designed.

**Rationale**:
- Vulnerable dependencies are a common attack vector (Log4Shell, etc.)
- Supply chain attacks can compromise entire applications

**Recommended Countermeasures**:
1. Use `npm audit` in CI/CD pipeline (fail build on high/critical vulnerabilities)
2. Implement automated dependency updates (Dependabot or Renovate)
3. Review security advisories before adopting new libraries
4. Pin exact versions in package.json (no `^` or `~`)
5. Use private npm registry with security scanning
6. Document approved libraries list with security review status
7. Regular quarterly security review of all dependencies

**Relevant Section**: Section 2 - 主要ライブラリ

---

### 2-10. Missing Session Management Design

**Suggestion Description**: JWT is stateless but no session management features are designed.

**Rationale**:
- Users cannot view active sessions or revoke compromised devices
- No way to force logout on all devices (account compromise scenario)

**Recommended Countermeasures**:
1. Store active sessions in Redis (user_id → [session_id, device_info, last_active])
2. Implement "View active sessions" page showing device, location, last access time
3. Allow users to revoke individual sessions
4. Implement "Logout all devices" functionality
5. Automatic session cleanup after 30 days of inactivity
6. Notify users via email on new device login

**Relevant Section**: Section 5 - 認証・認可方式, Section 2 - データベース (Redis)

---

### 2-11. Missing Authorization Model Details

**Suggestion Description**: Role-based access control is mentioned but lacks detailed permission matrix.

**Rationale**:
- Ambiguous permissions lead to privilege escalation bugs
- Developers need clear guidance on access control implementation

**Recommended Countermeasures**:
1. Document permission matrix (role × resource × action)
2. Define project-level permissions (owner, editor, viewer) separate from org roles
3. Specify permission inheritance rules (org admin can access all projects?)
4. Design guest user limitations (read-only, limited projects, no exports)
5. Implement attribute-based access control for fine-grained rules (e.g., "only assigned user can mark task done")
6. Add permission check utility functions to prevent authorization bugs

**Relevant Section**: Section 5 - 認証・認可方式

---

## 3. Confirmation Items (requiring user confirmation)

### 3-1. Data Residency and Compliance Requirements

**Confirmation Reason**: Design uses AWS Tokyo region but doesn't specify data residency requirements or compliance standards.

**Options and Trade-offs**:
- **Option A**: Store all data in ap-northeast-1 only (meets Japan APPI requirements, simpler architecture)
- **Option B**: Multi-region deployment (better availability, higher complexity and cost)
- **Question**: Do you need to comply with specific regulations (GDPR, HIPAA, PCI-DSS)? This affects encryption, logging, and retention design.

---

### 3-2. OAuth/SSO Integration Requirements

**Confirmation Reason**: External service integration is mentioned (Slack, GitHub, Google Workspace) but unclear if SSO is needed for authentication.

**Options and Trade-offs**:
- **Option A**: Email/password only (simpler, but users may prefer SSO)
- **Option B**: Add Google/Microsoft SSO (better UX, requires OAuth2 flow design and token linking)
- **Question**: Should users be able to login via Google Workspace or other SSO providers? This affects authentication architecture significantly.

---

### 3-3. Real-time Collaboration Conflict Resolution

**Confirmation Reason**: Socket.IO is used for real-time features but no conflict resolution strategy for concurrent edits.

**Options and Trade-offs**:
- **Option A**: Last-write-wins (simple, may lose user edits)
- **Option B**: Operational Transformation or CRDT (complex, no data loss)
- **Option C**: Optimistic locking with conflict detection (medium complexity, alerts user on conflicts)
- **Question**: How should concurrent edits to the same task/document be handled?

---

## 4. Positive Evaluation (good points)

### 4-1. Strong Password Hashing

The design appropriately uses bcrypt with cost factor 10 for password hashing, which is resistant to brute-force attacks and GPU cracking. The choice of bcrypt over simpler algorithms like MD5 or SHA1 demonstrates security awareness.

---

### 4-2. HTTPS Enforcement

All API communication is enforced over HTTPS, preventing man-in-the-middle attacks and protecting data in transit. This is a fundamental but critical security requirement.

---

### 4-3. Comprehensive Logging Strategy

The logging policy covers important events (API calls, authentication failures, DB errors) with appropriate log levels and centralized storage in CloudWatch Logs. This provides good foundation for security monitoring and incident response.

---

### 4-4. ORM Usage for SQL Injection Prevention

Using Sequelize ORM as the primary data access layer significantly reduces SQL injection risk by parameterizing queries automatically. This is a sound architectural choice for database security.

---

### 4-5. React XSS Protection

Leveraging React's default escaping mechanism provides baseline XSS protection for user-generated content. This is a good example of secure-by-default framework selection.
