# Security Design Review: EduStream Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple STRIDE categories lack explicit mitigations, particularly for repudiation, tampering, and DoS scenarios |
| Authentication & Authorization Design | 2 | JWT in localStorage with 24h expiration creates XSS token theft risk; no session management or revocation design |
| Data Protection | 2 | Missing encryption at rest specifications, no data retention policy, and insufficient PII protection measures |
| Input Validation Design | 3 | Basic XSS/SQLi mentioned but missing comprehensive validation policies, file upload restrictions, and size limits |
| Infrastructure & Dependencies | 3 | No secret management design, missing dependency vulnerability scanning, and insufficient deployment security controls |
| **Overall** | **2.4** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Storage in localStorage Enables XSS Token Theft
**Problem**: The design specifies storing JWT tokens in localStorage with a 24-hour expiration (Section 5). This creates a critical security vulnerability because any XSS attack can access localStorage and steal valid tokens for 24 hours.

**Impact**: If even a single XSS vulnerability exists anywhere in the application, attackers can:
- Steal tokens valid for 24 hours
- Perform complete account takeover
- Access student data, payment information, and course materials
- Impersonate teachers and modify grades/content

**Recommended Countermeasures**:
- Switch to HttpOnly cookies with Secure and SameSite=Strict attributes
- Reduce access token expiration to 15 minutes
- Implement refresh token mechanism (7-day expiration, with rotation)
- Add CSRF protection for cookie-based auth (Double Submit Cookie pattern)

**Relevant Section**: Section 5 (API設計 - 認証・認可方式)

### 1.2 No Session Revocation or Logout Mechanism Design
**Problem**: While `/api/auth/logout` endpoint exists, there is no design for how to invalidate JWT tokens. Standard JWTs cannot be revoked before expiration, meaning logged-out users can continue using stolen tokens.

**Impact**:
- Stolen tokens remain valid even after user reports compromise and logs out
- No way to force logout of all sessions when password is changed
- Compromised accounts cannot be secured without waiting 24 hours

**Recommended Countermeasures**:
- Implement token revocation list (blacklist) in Redis with TTL matching token expiration
- Add `jti` (JWT ID) claim to all tokens and check against blacklist on each request
- Design session table in PostgreSQL to track active sessions per user
- On password change, invalidate all existing tokens for that user

**Relevant Section**: Section 5 (API設計 - 認証関連)

### 1.3 Missing Input Validation Policy for File Uploads
**Problem**: The design mentions using `multer` for file uploads (Section 2) and allows video uploads and assignment submissions, but provides no validation specifications for:
- Allowed file types (MIME type validation)
- Maximum file sizes
- File content scanning (malware, polyglot attacks)
- File name sanitization

**Impact**:
- Attackers can upload malicious files (web shells, malware)
- Students can upload executable files disguised as documents
- Uncontrolled file sizes can exhaust storage and bandwidth
- Path traversal via malicious filenames

**Recommended Countermeasures**:
- Video uploads: Allow only video/* MIME types, validate with magic number checking, max 5GB per file
- Assignment submissions: Allow only PDF, DOCX, TXT (whitelist), max 50MB per file
- Scan all uploads with ClamAV or AWS GuardDuty for malware
- Sanitize filenames: strip path characters, limit length to 255 bytes
- Generate random S3 keys instead of using user-provided filenames

**Relevant Section**: Section 2 (主要ライブラリ - multer), Section 4 (videos/submissions tables)

### 1.4 Stripe Webhook Endpoint Lacks Signature Verification Design
**Problem**: `POST /api/payments/webhook` is listed as an endpoint (Section 5) but there is no mention of Stripe webhook signature verification. Without this, attackers can send fake payment confirmation events.

**Impact**:
- Attackers can send forged "payment_succeeded" events to unlock paid courses without paying
- Financial fraud: free access to all premium content
- Data integrity: payment records don't match actual Stripe transactions

**Recommended Countermeasures**:
- Verify Stripe webhook signatures using `stripe.webhooks.constructEvent()` with webhook secret
- Reject any webhook requests with invalid signatures (401 response)
- Log all webhook verification failures with source IP for monitoring
- Use idempotency keys to prevent duplicate processing of same event

**Relevant Section**: Section 5 (API設計 - 決済)

### 1.5 No Rate Limiting Design for Critical Endpoints
**Problem**: API Gateway mentions "レート制限" (Section 3) but provides no specifications for:
- Which endpoints have rate limits
- Rate limit thresholds (requests per minute/hour)
- Rate limiting scope (per IP, per user, per endpoint)
- Response when rate limit is exceeded

**Impact**:
- Brute force attacks on `/api/auth/login` to guess passwords
- Credential stuffing attacks with leaked password databases
- DoS attacks by overwhelming API with requests
- Automated scraping of course content and user data

**Recommended Countermeasures**:
- `/api/auth/login`: 5 attempts per 15 minutes per IP + email combination
- `/api/auth/register`: 3 registrations per hour per IP
- Video upload endpoints: 10 uploads per hour per teacher
- General API endpoints: 1000 requests per hour per authenticated user
- Return 429 Too Many Requests with Retry-After header
- Implement account lockout: 30-minute suspension after 10 failed login attempts

**Relevant Section**: Section 3 (アーキテクチャ設計 - API Gateway)

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Threat Modeling - Missing Repudiation Protection
**Suggestion**: No audit logging design exists for critical actions. Teachers could deny changing grades, admins could deny deleting content, and there would be no proof.

**Rationale**: Educational platforms handle sensitive data (grades, payments, content access). Without audit trails, disputes cannot be resolved, and malicious insiders have no accountability.

**Recommended Countermeasures**:
- Design audit_logs table: (id, user_id, action, resource_type, resource_id, old_value, new_value, ip_address, timestamp)
- Log all state-changing operations: grade updates, content deletion, user role changes, payment processing
- Make logs immutable (append-only table) with write-once permissions
- Retain audit logs for 7 years (common educational compliance requirement)
- Add log integrity verification (hash chain or digital signatures)

### 2.2 Threat Modeling - No Protection Against Video/Content Tampering
**Suggestion**: S3 objects (videos, assignment files) have no integrity verification. Attackers with S3 access or man-in-the-middle could modify content without detection.

**Rationale**: Modified educational content (altered video lectures, tampered assignments) could spread misinformation or academic dishonesty without any way to detect tampering.

**Recommended Countermeasures**:
- Calculate SHA-256 hash of all uploaded files and store in database (add `content_hash` column to videos/submissions tables)
- Verify hash when serving content; reject if mismatch detected
- Use S3 Object Lock for write-once-read-many (WORM) for graded assignments
- Enable S3 versioning to maintain tamper-evident history

### 2.3 Threat Modeling - Missing DoS Mitigation for Live Streaming
**Suggestion**: Streaming Service handles live sessions but has no design for:
- Maximum concurrent viewers per session
- Resource limits for simultaneous live streams
- Handling of connection storms (10,000 students joining at once)

**Rationale**: Design states support for 10,000 concurrent viewers (Section 7) but provides no mechanism to prevent resource exhaustion or cascading failures.

**Recommended Countermeasures**:
- Implement per-session viewer cap with waiting queue UI
- Add connection throttling: max 100 new WebSocket connections per second
- Use AWS Auto Scaling with predictive scaling for scheduled class times
- Design graceful degradation: disable chat/Q&A features if viewer count exceeds 5,000

### 2.4 Threat Modeling - Information Disclosure via Enumeration Attacks
**Suggestion**: UUIDs as primary keys (Section 4) are good, but no protection against enumeration exists. Attackers can probe `/api/courses/:id`, `/api/videos/:id` with random UUIDs to discover hidden/unpublished content.

**Rationale**: Teachers may save draft courses or unlisted videos. Enumeration could expose unreleased content, private course materials, or student submissions.

**Recommended Countermeasures**:
- Add access control checks to ALL read endpoints (not just write endpoints)
- Return 404 for unauthorized access (not 403, to avoid confirming existence)
- Implement signed URLs for video streaming with short expiration (1 hour)
- Add `is_public` checks in database queries, not just application logic

### 2.5 Threat Modeling - Privilege Escalation via Role Manipulation
**Suggestion**: User roles are stored in ENUM field (Section 4) but there is no design for:
- Who can change user roles
- Audit trail for role changes
- Protection against horizontal privilege escalation (teacher accessing another teacher's courses)

**Rationale**: If role change logic has bugs, students could escalate to teacher/admin. Horizontal escalation (teacher A modifying teacher B's content) is equally dangerous.

**Recommended Countermeasures**:
- Design role change endpoint: `PUT /api/admin/users/:id/role` (admin-only)
- Add middleware to verify resource ownership: teachers can only modify their own courses/videos
- Implement principle of least privilege: separate "course_owner" check from "teacher" role
- Add `owner_id` verification to all UPDATE/DELETE endpoints in authorization layer

### 2.6 Authentication - No Multi-Factor Authentication (MFA) Design
**Suggestion**: Teacher and admin accounts have elevated privileges but only use password authentication. No MFA or additional verification exists.

**Rationale**: Teacher accounts can modify grades affecting academic records. Admin accounts can delete all content. Password-only authentication is insufficient for these privilege levels.

**Recommended Countermeasures**:
- Require TOTP-based MFA (using `speakeasy` library) for teacher and admin roles
- Design MFA enrollment flow: `/api/auth/mfa/setup`, `/api/auth/mfa/verify`
- Store MFA secrets encrypted in database with user-specific encryption keys
- Provide backup codes (10 single-use codes) in case of authenticator loss

### 2.7 Authentication - Missing Account Security Features
**Suggestion**: No design exists for:
- Password reset flow security
- Account recovery mechanisms
- Detection of compromised credentials
- Password complexity requirements

**Rationale**: Educational platforms are high-value targets (student PII, payment data). Weak passwords and insecure recovery flows enable account takeover.

**Recommended Countermeasures**:
- Password policy: minimum 12 characters, require mix of uppercase/lowercase/numbers/symbols (enforce with `joi` validation)
- Password reset: Send time-limited token (1 hour expiration) via email, single-use only
- Implement password reset rate limiting: max 3 requests per hour per email
- Check passwords against Have I Been Pwned API during registration/reset
- Design security questions or email + SMS verification for account recovery

### 2.8 Authentication - No Protection Against Session Fixation
**Suggestion**: Token refresh endpoint exists (`/api/auth/refresh`) but no design specifies:
- When old tokens are invalidated
- How to prevent token reuse attacks
- Session rotation on privilege escalation

**Rationale**: If refresh tokens are not properly rotated, stolen refresh tokens provide indefinite access. Session fixation attacks could persist across authentication state changes.

**Recommended Countermeasures**:
- Implement refresh token rotation: each refresh issues new access + refresh tokens and invalidates old refresh token
- Store refresh token hashes (not plaintext) in database with device fingerprint
- Invalidate all sessions when user changes password or email
- Add `last_password_change` timestamp; reject tokens issued before that time

### 2.9 Data Protection - Missing Encryption at Rest Specifications
**Suggestion**: Design mentions HTTPS for data in transit (Section 7) but no encryption at rest for:
- Database containing PII (emails, payment records)
- S3 buckets containing student submissions
- Redis session store

**Rationale**: If AWS infrastructure is compromised or database backups are leaked, plaintext sensitive data would be exposed.

**Recommended Countermeasures**:
- Enable PostgreSQL Transparent Data Encryption (TDE) or AWS RDS encryption
- Enable S3 bucket encryption: SSE-S3 for videos, SSE-KMS for student submissions and payment data
- Use Redis encryption in transit (TLS) and at rest (encrypted snapshots)
- Encrypt sensitive columns (email, payment info) at application level using AES-256-GCM with AWS KMS

### 2.10 Data Protection - No Data Retention and Deletion Policy
**Suggestion**: No design specifies:
- How long to retain student data after course completion
- How to handle deletion requests (GDPR "right to be forgotten")
- Anonymization of historical data
- Backup retention periods

**Rationale**: Educational platforms in EU must comply with GDPR. Indefinite data retention increases breach impact and legal liability.

**Recommended Countermeasures**:
- Retention policy: Student data retained for 2 years after last course enrollment, then anonymized
- Design soft delete: add `deleted_at` timestamp, exclude from queries, hard delete after 90 days
- Implement data export endpoint: `/api/users/me/export` (GDPR data portability)
- Anonymize audit logs: replace user_id with hash after retention period
- Automated cleanup job: monthly cron job to purge expired soft-deleted records

### 2.11 Data Protection - Missing Protection for Sensitive Data in Logs
**Suggestion**: Logging policy mentions recording all API requests (Section 6) but does not specify exclusions for:
- Passwords in request bodies
- JWT tokens in Authorization headers
- Credit card data from Stripe webhooks
- Session tokens in cookies

**Rationale**: Logs stored in CloudWatch Logs could leak credentials if developers accidentally log request bodies or attackers gain log access.

**Recommended Countermeasures**:
- Configure Winston to redact sensitive fields: password, token, authorization, stripe_token
- Use structured logging with allowlist of safe fields instead of logging entire request objects
- Set CloudWatch log retention to 90 days (not indefinite)
- Enable CloudWatch Logs encryption with KMS
- Restrict log access with IAM policies (developers should not access production logs without approval)

### 2.12 Input Validation - No API Request Size Limits
**Suggestion**: Design does not specify maximum request body sizes. Attackers could send gigabyte-sized JSON payloads to exhaust memory.

**Rationale**: Node.js loads entire request body into memory. Unlimited request sizes enable DoS attacks and could crash application servers.

**Recommended Countermeasures**:
- Configure Express `body-parser` with limits: JSON payloads max 1MB, multipart form data max 100MB (for file uploads only)
- Add middleware to reject requests exceeding size limits before parsing
- Separate file upload endpoints (higher limits) from regular API endpoints (lower limits)

### 2.13 Input Validation - Missing Output Encoding for Different Contexts
**Suggestion**: Design mentions "出力時にエスケープ処理" for XSS (Section 7) but does not specify:
- Which contexts require encoding (HTML, JavaScript, URL, CSS)
- Which library to use for encoding
- Where encoding should occur (template layer vs API layer)

**Rationale**: Incorrect escaping causes XSS. Escaping for HTML context is insufficient for JavaScript or URL contexts.

**Recommended Countermeasures**:
- Use context-aware encoding: `DOMPurify` for HTML, `encodeURIComponent` for URLs
- Configure React to use `dangerouslySetInnerHTML` only with sanitized content
- Add Content-Security-Policy header to restrict script sources: `default-src 'self'; script-src 'self'`
- Use `helmet.js` to set secure HTTP headers (X-Content-Type-Options, X-Frame-Options)

### 2.14 Input Validation - No Protection Against Mass Assignment
**Suggestion**: API endpoints for creating/updating resources (courses, users, videos) do not specify which fields are user-controllable. Attackers could set privileged fields via mass assignment.

**Rationale**: If `PUT /api/courses/:id` accepts all fields from request body, students could set `teacher_id` to hijack courses or set `is_public=false` to hide content.

**Recommended Countermeasures**:
- Use explicit field whitelisting with `joi` schemas for all request validation
- Never spread entire request body into database queries: `User.update({...req.body})` is dangerous
- Example: Course update should only allow `title`, `description`, `price` fields (not `teacher_id`, `id`)
- Add middleware to validate request schemas before reaching business logic

### 2.15 Infrastructure - No Secret Management Design
**Suggestion**: Design does not specify how to manage:
- Database credentials
- JWT signing keys
- Stripe API keys
- AWS access keys
- Session encryption keys

**Rationale**: Hardcoded secrets in code or environment variables in GitHub repos lead to credential leaks. Rotation of leaked secrets is manual and error-prone.

**Recommended Countermeasures**:
- Use AWS Secrets Manager for all secrets (DB password, Stripe keys, JWT secret)
- Rotate secrets automatically: database passwords every 90 days, JWT keys every 30 days
- Use IAM roles for EC2/ECS instead of AWS access keys
- Never commit `.env` files; use parameter store for environment-specific config
- Design secret rotation: update Secrets Manager, reload application config without restart

### 2.16 Infrastructure - Missing Dependency Vulnerability Scanning
**Suggestion**: CI/CD mentions running automated tests (Section 6) but no security scanning for:
- Known vulnerabilities in npm packages
- Outdated dependencies
- License compliance issues

**Rationale**: Supply chain attacks via compromised packages are increasing. Critical vulnerabilities in dependencies (e.g., `jsonwebtoken`, `express`) could compromise entire platform.

**Recommended Countermeasures**:
- Integrate `npm audit` into GitHub Actions CI pipeline; fail build on high/critical vulnerabilities
- Add Snyk or Dependabot for automated dependency updates
- Pin exact versions in `package-lock.json` (not semver ranges)
- Review all dependency updates for unexpected code changes before merging
- Use `npm ci` in production deployments (not `npm install`)

### 2.17 Infrastructure - Insufficient Deployment Security Controls
**Suggestion**: Blue-green deployment is mentioned (Section 6) but no pre-deployment security validation such as:
- Security regression testing
- Secrets scanning in repository
- Infrastructure-as-code security validation

**Rationale**: Deployments could introduce vulnerabilities or accidentally expose secrets if no automated checks exist.

**Recommended Countermeasures**:
- Add `gitleaks` or `truffleHog` to GitHub Actions to scan for committed secrets
- Run OWASP Dependency-Check in CI pipeline before deployment
- Use Terraform/CloudFormation with `tfsec` or `cfn-nag` to validate infrastructure security
- Implement smoke tests after blue-green switch to verify authentication still works
- Require manual approval for production deployments (GitHub Environments with protection rules)

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Compliance Requirements Unknown
**Confirmation Reason**: Design does not specify compliance requirements (GDPR, FERPA, COPPA, SOC2). Educational platforms often handle minors' data and cross-border data transfers, which have strict legal requirements.

**Options and Trade-offs**:
- **Option A**: GDPR compliance - Requires data residency in EU, DPO appointment, DPIA for high-risk processing. High implementation cost but necessary for EU students.
- **Option B**: FERPA compliance (US education privacy law) - Requires parental consent for students under 13, strict access controls for educational records. Mandatory for US K-12 schools.
- **Option C**: COPPA compliance (children's privacy) - If platform accepts users under 13, requires verifiable parental consent, no behavioral advertising, limited data collection.

**Recommendation**: Clarify target markets and user age ranges to determine applicable compliance frameworks. This affects authentication design (parental consent flows), data retention policies, and third-party integrations.

### 3.2 Shared Resource Access Control Model
**Confirmation Reason**: Design does not clarify:
- Can multiple teachers co-teach a course?
- Can students access courses after enrollment period ends?
- Can teachers view other teachers' course content?

**Options and Trade-offs**:
- **Option A**: Strict isolation - Each course has single owner, no cross-teacher access. Simpler security model but limits collaboration.
- **Option B**: Role-based collaboration - Add co-teacher role with granular permissions (can grade, cannot delete). More complex authorization logic.
- **Option C**: Institution-level access - Admin can access all courses within their institution. Required for auditing but increases insider threat risk.

**Recommendation**: Define access control matrix for all user role combinations. This affects authorization middleware design and database schema (may need course_permissions junction table).

### 3.3 Video Content DRM Requirements
**Confirmation Reason**: Design uses CloudFront for CDN (Section 2) but does not specify if course videos require DRM or piracy prevention.

**Options and Trade-offs**:
- **Option A**: No DRM - Simple signed URLs with short expiration. Easy to implement but videos can be downloaded and redistributed.
- **Option B**: AWS CloudFront Signed Cookies with geographic restrictions - Prevents hotlinking and limits access by region. Moderate protection.
- **Option C**: Full DRM (Widevine/FairPlay) - Prevents screen recording and unauthorized playback. High cost, requires DRM key management, not supported on all devices.

**Recommendation**: For free/low-cost courses, signed URLs sufficient. For premium courses, implement CloudFront signed cookies + watermarking (add student email overlay to videos).

---

## 4. Positive Evaluation (good points)

### 4.1 Use of Parameterized Queries Prevents SQL Injection
The design explicitly mentions using parameterized queries for SQL injection prevention (Section 7). This is a fundamental security control and indicates awareness of OWASP Top 10 risks. Combined with PostgreSQL as the database choice, this provides strong protection against SQL injection attacks.

### 4.2 Password Hashing with bcrypt and Appropriate Cost Factor
The design specifies using bcrypt with cost factor 10 for password hashing (Section 7). This is current industry best practice and balances security (resistant to brute force) with performance. The choice of bcrypt over weaker algorithms (MD5, SHA1) demonstrates good security awareness.

### 4.3 Comprehensive Logging Strategy with Environment Separation
The logging design (Section 6) properly separates development and production environments, sending production logs to CloudWatch for centralized monitoring. Including access logs for all API requests provides an audit trail for security incident investigation. The use of Winston with multiple log levels allows fine-grained control.

### 4.4 Blue-Green Deployment with Rollback Capability
The deployment strategy (Section 6) includes rollback functionality, which is critical for security. If a deployment introduces a vulnerability, the ability to quickly roll back minimizes exposure time. This demonstrates mature operational security practices.

### 4.5 Database Replication for Availability and Backup Strategy
The design includes master-slave replication and both full and transaction log backups (Section 7). This provides both high availability and point-in-time recovery capability, which is essential for data integrity and ransomware recovery scenarios.
