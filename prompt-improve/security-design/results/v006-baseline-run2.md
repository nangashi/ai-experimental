# Security Design Review: EduStream Online Education Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple critical STRIDE threats not addressed: no session invalidation on logout, no audit logging for repudiation, vulnerable to XSS-based token theft |
| Authentication & Authorization Design | 2 | JWT stored in localStorage is vulnerable to XSS attacks; 24-hour token expiration is excessively long; no refresh token rotation or session management |
| Data Protection | 2 | No encryption-at-rest policy for sensitive data; no data retention/deletion policy; missing student privacy protections (FERPA/GDPR compliance) |
| Input Validation Design | 2 | No input validation policy defined; no file upload size limits or type restrictions; missing output escaping specifications beyond generic mention |
| Infrastructure & Dependencies | 3 | Basic security present (HTTPS, bcrypt) but missing secret management design, dependency scanning, and security update policy |
| **Overall** | **2.2** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Storage in localStorage Enables XSS-Based Account Takeover

**Problem Description**:
The design specifies storing JWT tokens in localStorage (Section 5: "トークン保存: クライアント側でlocalStorageに保存") with a 24-hour expiration. This creates two critical vulnerabilities:

1. localStorage is accessible to all JavaScript code, making tokens vulnerable to XSS attacks
2. 24-hour expiration means a stolen token remains valid for an entire day

**Impact**:
If even a single XSS vulnerability exists anywhere in the React application (e.g., unsanitized user content in forums, chat messages, or course descriptions), an attacker can:
- Steal the JWT token via `localStorage.getItem()`
- Use the token to impersonate the victim for up to 24 hours
- Access all victim data, submit assignments as the student, or modify courses as the teacher
- Potentially extract sensitive student information (FERPA violation)

**Recommended Countermeasures**:
1. **Store tokens in HttpOnly cookies** instead of localStorage:
   - Set `HttpOnly`, `Secure`, and `SameSite=Strict` attributes
   - Prevents JavaScript access to tokens
   - Backend must issue cookies on `/api/auth/login` response

2. **Implement short-lived access tokens with refresh token rotation**:
   - Access token: 15 minutes expiration (stored in HttpOnly cookie)
   - Refresh token: 7 days expiration (stored in separate HttpOnly cookie)
   - Refresh token rotation: issue new refresh token on each use, invalidate old one
   - Store refresh token family in Redis with detection of reuse (indicates token theft)

3. **Add token binding** (optional but recommended):
   - Bind tokens to user-agent and IP address hash
   - Detect suspicious token reuse from different locations

**Relevant Section**: Section 5 - API設計 - 認証・認可方式

---

### 1.2 Missing Session Management and Logout Mechanism

**Problem Description**:
The design mentions `POST /api/auth/logout` endpoint but provides no implementation details for session invalidation. With JWT tokens, simply deleting the client-side token does not invalidate it on the server side—the token remains valid until expiration.

**Impact**:
- Logout does not actually end the session—tokens continue working for 24 hours
- If a user logs out on a shared computer, the next user can retrieve the token from browser history or network logs
- Stolen tokens cannot be revoked even after the user reports the theft
- No way to implement "logout from all devices" functionality

**Recommended Countermeasures**:
1. **Implement server-side token blocklist in Redis**:
   - On logout, add token JTI (JWT ID) to Redis blocklist with TTL = remaining token lifetime
   - Auth middleware checks blocklist before accepting token
   - Enables immediate token revocation

2. **Add session table for refresh tokens**:
   ```sql
   CREATE TABLE sessions (
     id UUID PRIMARY KEY,
     user_id UUID REFERENCES users(id),
     refresh_token_hash VARCHAR(255) UNIQUE,
     family_id UUID,  -- for rotation detection
     user_agent VARCHAR(500),
     ip_address INET,
     created_at TIMESTAMP,
     expires_at TIMESTAMP,
     revoked_at TIMESTAMP
   );
   ```

3. **Implement "logout all devices" endpoint**:
   - `POST /api/auth/logout-all` revokes all refresh tokens for the user
   - Add user notification when new login detected from unfamiliar device

**Relevant Section**: Section 5 - API設計 - 認証関連

---

### 1.3 No Rate Limiting Specifications for Authentication and Payment Endpoints

**Problem Description**:
The design mentions "API Gateway: 全リクエストのルーティング、レート制限" but provides no specific rate limits for critical endpoints such as:
- `/api/auth/login` (vulnerable to credential stuffing)
- `/api/auth/register` (vulnerable to bulk account creation)
- `/api/payments/create` (vulnerable to payment spam)

**Impact**:
- Attackers can perform unlimited brute-force attacks on login endpoint
- Bulk account creation for spam or fraud (e.g., creating fake students to access paid courses)
- Payment endpoint abuse could trigger Stripe rate limits or incur excessive fees
- No protection against denial-of-service attacks

**Recommended Countermeasures**:
1. **Implement tiered rate limiting using express-rate-limit**:

   ```javascript
   // Authentication endpoints
   /api/auth/login: 5 requests per 15 minutes per IP
   /api/auth/register: 3 requests per hour per IP
   /api/auth/refresh: 10 requests per 15 minutes per user

   // Payment endpoints
   /api/payments/create: 10 requests per hour per user
   /api/payments/webhook: 1000 requests per minute (Stripe burst traffic)

   // Content upload endpoints
   /api/videos (POST): 5 uploads per hour per teacher
   /api/submissions (POST): 10 submissions per hour per student

   // General API
   All other endpoints: 100 requests per 15 minutes per user
   ```

2. **Add account lockout on repeated failures**:
   - Lock account for 30 minutes after 5 failed login attempts
   - Send email notification to user about lockout
   - Store lockout state in Redis: `auth:lockout:{user_id}` with TTL

3. **Implement CAPTCHA for suspicious traffic**:
   - Trigger CAPTCHA after 3 failed login attempts from same IP
   - Use hCaptcha or reCAPTCHA v3 for minimal user friction

**Relevant Section**: Section 3 - アーキテクチャ設計 - 主要コンポーネントの責務と依存関係

---

### 1.4 Missing File Upload Security Controls

**Problem Description**:
The design allows file uploads for assignments (`POST /api/submissions`, Section 5) and videos (`POST /api/videos`) using multer, but specifies no security controls:
- No file size limits (risk of disk space exhaustion)
- No file type restrictions (risk of malicious file uploads)
- No virus scanning (risk of malware distribution)
- No storage quota per user (risk of abuse)

**Impact**:
- **Denial of Service**: Students upload multi-gigabyte files to exhaust S3 storage quota or bandwidth
- **Malware distribution**: Attackers upload malicious executables disguised as assignment files, then share download links to infect other users
- **XXE/SSRF attacks**: If file processing (e.g., video transcoding) occurs, malicious XML/SVG files could exploit backend services
- **Cost explosion**: Unlimited uploads could result in massive AWS S3/bandwidth bills

**Recommended Countermeasures**:
1. **Define strict file upload policy**:
   ```javascript
   // Assignments (students)
   Allowed types: .pdf, .docx, .txt, .zip (validated by MIME type + magic bytes)
   Max file size: 50 MB
   Max files per submission: 3
   Quota per student: 500 MB total

   // Videos (teachers)
   Allowed types: .mp4, .webm, .mov (validated by ffprobe)
   Max file size: 2 GB
   Quota per teacher: 50 GB total
   Virus scanning: Required (ClamAV or AWS S3 Malware Scanning)
   ```

2. **Implement secure upload workflow**:
   - Generate pre-signed S3 URLs with short expiration (15 minutes)
   - Upload directly to S3 from client (bypasses application server)
   - Validate file type and size server-side after upload
   - Quarantine uploads until virus scan completes
   - Use S3 Object Lock to prevent deletion of submitted assignments (audit trail)

3. **Add content security policy for downloads**:
   - Serve all user-uploaded files from separate domain (`cdn.edustream.com`)
   - Set `Content-Security-Policy: default-src 'none'` to prevent script execution
   - Set `X-Content-Type-Options: nosniff` and `Content-Disposition: attachment`

**Relevant Section**: Section 5 - API設計 - 動画管理, 課題管理

---

### 1.5 No Input Validation Policy or Schema Definitions

**Problem Description**:
The design mentions "SQLインジェクション対策: パラメータ化クエリ使用" and "XSS対策: 出力時にエスケープ処理" (Section 7) but provides no specifications for:
- Input validation rules (length limits, character restrictions, format validation)
- Schema validation for API requests
- Sanitization rules for user-generated content

**Impact**:
- **Second-order injection attacks**: Malicious input stored in database could exploit other systems (e.g., email templates, admin dashboards)
- **Business logic bypass**: Missing length validation could allow excessively long course titles (breaking UI), negative prices (free courses), or future deadlines (assignments never due)
- **Data integrity issues**: Invalid data in database (e.g., email without `@`, negative `max_score`) causes application errors
- **Storage DoS**: Extremely long text fields (e.g., 1 MB course description) could exhaust database storage

**Recommended Countermeasures**:
1. **Define input validation schema using Joi or Zod**:

   ```javascript
   // Example: Course creation validation
   const courseSchema = Joi.object({
     title: Joi.string().min(5).max(200).required(),
     description: Joi.string().max(5000).allow(''),
     price: Joi.number().min(0).max(99999.99).precision(2).allow(null),
     is_public: Joi.boolean().default(true)
   });

   // User registration validation
   const registerSchema = Joi.object({
     email: Joi.string().email().max(255).required(),
     password: Joi.string().min(12).max(128)
       .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/)
       .required(),
     role: Joi.string().valid('teacher', 'student').required()
   });

   // Assignment validation
   const assignmentSchema = Joi.object({
     title: Joi.string().min(5).max(200).required(),
     description: Joi.string().max(10000).allow(''),
     deadline: Joi.date().min('now').required(),
     max_score: Joi.number().integer().min(1).max(1000).required()
   });
   ```

2. **Implement centralized validation middleware**:
   - Apply schema validation before route handlers
   - Return 400 Bad Request with specific field errors
   - Log validation failures for security monitoring

3. **Add sanitization for user-generated content**:
   - Use DOMPurify for HTML content in course descriptions and forum posts
   - Strip all HTML tags from text-only fields (e.g., assignment titles)
   - Implement whitelist-based sanitization (allow only safe HTML tags: `<p>`, `<b>`, `<i>`, `<ul>`, `<ol>`, `<li>`)

4. **Enforce database constraints as last line of defense**:
   - Add CHECK constraints for numerical ranges (e.g., `CHECK (price >= 0)`)
   - Add length limits at database level (prevent bypass of application validation)

**Relevant Section**: Section 7 - 非機能要件 - セキュリティ要件

---

### 1.6 Missing Audit Logging for Repudiation Prevention

**Problem Description**:
The design specifies logging using Winston (Section 6) but only mentions "すべてのAPIリクエストをログに記録" (all API requests). No specifications for:
- What data to log for security-sensitive operations
- How to ensure logs are tamper-proof
- Log retention policy
- Audit trail for sensitive operations (grade changes, payment processing, content deletion)

**Impact**:
- **Repudiation attacks**: Teachers can change student grades without audit trail; students can deny submitting plagiarized work
- **Compliance violations**: Inability to prove FERPA compliance (no audit trail for who accessed student records)
- **Incident response failure**: After a security incident, insufficient logs prevent determining attacker actions or affected data
- **Insider threats**: Admin users can delete content or modify data without accountability

**Recommended Countermeasures**:
1. **Define comprehensive audit logging policy**:

   ```javascript
   // Events requiring audit logs
   - Authentication events (login, logout, password change, MFA changes)
   - Authorization failures (attempted access to forbidden resources)
   - Data modifications (CREATE, UPDATE, DELETE on all entities)
   - Sensitive data access (viewing student records, payment information)
   - Administrative actions (user role changes, content approval/deletion)
   - Payment transactions (all Stripe webhook events)

   // Audit log format
   {
     "timestamp": "ISO 8601",
     "event_type": "GRADE_CHANGED | LOGIN_SUCCESS | ...",
     "actor": {
       "user_id": "UUID",
       "role": "teacher",
       "ip_address": "1.2.3.4",
       "user_agent": "..."
     },
     "resource": {
       "type": "submission",
       "id": "UUID",
       "owner_id": "UUID"  // student who owns the resource
     },
     "changes": {
       "field": "score",
       "old_value": "85",
       "new_value": "90"
     },
     "result": "success | failure",
     "failure_reason": "..."
   }
   ```

2. **Implement tamper-proof audit log storage**:
   - Store audit logs in separate database with append-only permissions
   - Use AWS CloudWatch Logs with log retention = 7 years (FERPA compliance)
   - Implement log integrity verification using HMAC or digital signatures
   - Restrict audit log access to security team only (not application admins)

3. **Add retention policy**:
   - Audit logs: 7 years (FERPA requirement for educational records)
   - Access logs: 1 year
   - Application logs: 90 days
   - Payment logs: 7 years (tax compliance)

**Relevant Section**: Section 6 - 実装方針 - ロギング方針

---

### 1.7 No Idempotency Guarantees for Payment and Submission Operations

**Problem Description**:
The design includes state-changing operations (payment creation, assignment submission) but does not specify idempotency mechanisms. Network retries or duplicate requests could cause:
- Duplicate payments (charging student twice for same course)
- Duplicate submissions (student's assignment recorded multiple times)

**Impact**:
- **Financial loss**: Students charged multiple times; refund processing overhead
- **Data integrity**: Multiple submission records for same assignment confuse grading workflow
- **User trust**: Users lose confidence in platform after being double-charged
- **Stripe disputes**: Increased chargeback rate due to duplicate charges

**Recommended Countermeasures**:
1. **Implement idempotency keys for payment endpoint**:

   ```javascript
   POST /api/payments/create
   Headers:
     Idempotency-Key: <client-generated UUID>

   // Server-side implementation
   - Store idempotency key + response in Redis (TTL = 24 hours)
   - On duplicate request with same key, return cached response (HTTP 200)
   - Pass idempotency key to Stripe API to prevent duplicate charges
   - If different request body with same key, return HTTP 409 Conflict
   ```

2. **Add unique constraint for submissions**:

   ```sql
   ALTER TABLE submissions
   ADD CONSTRAINT unique_student_assignment
   UNIQUE (assignment_id, student_id);
   ```

   - On duplicate submission, update existing record instead of inserting new one
   - Preserve original `submitted_at` timestamp
   - Log resubmission events in audit log

3. **Implement optimistic locking for grade updates**:

   ```sql
   ALTER TABLE submissions ADD COLUMN version INTEGER DEFAULT 1;

   -- Update with version check
   UPDATE submissions
   SET score = ?, feedback = ?, version = version + 1
   WHERE id = ? AND version = ?;

   -- If affected rows = 0, return HTTP 409 Conflict (concurrent modification)
   ```

**Relevant Section**: Section 5 - API設計 - 決済, 課題管理

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Add CSRF Protection for State-Changing Operations

**Suggestion Description**:
While JWT-based APIs are often considered immune to CSRF attacks, the design should explicitly protect against CSRF if cookies are adopted (as recommended in Critical Issue 1.1).

**Rationale**:
If JWT tokens are moved to HttpOnly cookies (recommended), all state-changing endpoints become vulnerable to CSRF attacks. An attacker could trick a logged-in user into making unwanted requests (e.g., enrolling in malicious course, deleting their content).

**Recommended Countermeasures**:
1. **Implement Double Submit Cookie pattern**:
   - On login, generate CSRF token and send in both:
     - HttpOnly cookie: `csrf_token=<random>`
     - Response body: `{ "csrfToken": "<same random>" }`
   - Client includes CSRF token in custom header: `X-CSRF-Token: <token>`
   - Server validates: cookie value === header value

2. **Use SameSite=Strict cookie attribute** (already recommended in 1.1):
   - Prevents cookies from being sent on cross-origin requests
   - Provides defense-in-depth even if CSRF token validation has bugs

3. **Apply CSRF protection to all state-changing endpoints**:
   - POST, PUT, DELETE methods require CSRF token
   - GET methods are exempt (read-only)

---

### 2.2 Implement Stripe Webhook Signature Verification

**Suggestion Description**:
The design includes `POST /api/payments/webhook` for receiving Stripe webhook events but does not specify signature verification.

**Rationale**:
Without signature verification, attackers could forge webhook requests to:
- Mark unpaid courses as paid (access control bypass)
- Trigger refund processing for legitimate payments
- Spam the system with fake payment events (DoS)

**Recommended Countermeasures**:
1. **Verify Stripe webhook signatures**:

   ```javascript
   const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

   app.post('/api/payments/webhook', express.raw({type: 'application/json'}), (req, res) => {
     const sig = req.headers['stripe-signature'];
     const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

     try {
       const event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
       // Process event...
     } catch (err) {
       return res.status(400).send(`Webhook Error: ${err.message}`);
     }
   });
   ```

2. **Implement webhook replay attack protection**:
   - Store processed webhook event IDs in Redis (TTL = 24 hours)
   - Reject duplicate event IDs
   - Check event timestamp (reject events older than 5 minutes)

3. **Add webhook retry handling**:
   - Return HTTP 200 only after successfully processing event
   - Implement idempotent event handlers (use Stripe `event.id` as idempotency key)
   - Use database transactions to ensure atomicity (payment record + course enrollment)

---

### 2.3 Add Content Security Policy (CSP) Headers

**Suggestion Description**:
The design does not specify Content Security Policy headers for the React frontend.

**Rationale**:
CSP headers provide defense-in-depth against XSS attacks by restricting sources from which scripts can be loaded. Even if an XSS vulnerability exists, CSP can prevent malicious script execution.

**Recommended Countermeasures**:
1. **Implement strict CSP policy**:

   ```http
   Content-Security-Policy:
     default-src 'self';
     script-src 'self' 'nonce-{random}';
     style-src 'self' 'nonce-{random}';
     img-src 'self' https://cdn.edustream.com data:;
     media-src 'self' https://cdn.edustream.com;
     connect-src 'self' https://api.stripe.com;
     font-src 'self';
     object-src 'none';
     base-uri 'self';
     form-action 'self';
     frame-ancestors 'none';
     upgrade-insecure-requests;
   ```

2. **Use nonce-based CSP for inline scripts**:
   - Generate random nonce per page load
   - Include nonce in `<script nonce="...">` tags
   - Blocks inline event handlers (`onclick`, etc.) which are common XSS vectors

3. **Enable CSP reporting**:
   - Add `report-uri` directive to log CSP violations
   - Monitor reports to detect XSS attempts or misconfigurations

---

### 2.4 Implement Password Complexity Requirements and Breach Detection

**Suggestion Description**:
The design specifies bcrypt hashing (Section 7) but does not define password complexity requirements or breach detection.

**Rationale**:
Weak passwords remain a major attack vector even with strong hashing. Users often reuse passwords compromised in other breaches, enabling credential stuffing attacks.

**Recommended Countermeasures**:
1. **Define password policy**:
   - Minimum length: 12 characters (NIST SP 800-63B recommendation)
   - Require mix of uppercase, lowercase, digits, and symbols
   - Reject common passwords (use `zxcvbn` library for strength estimation)
   - Reject passwords matching user email or name

2. **Implement Have I Been Pwned (HIBP) integration**:
   - On registration/password change, check password against HIBP API
   - Use k-anonymity model (send only first 5 chars of SHA-1 hash)
   - Reject passwords found in breach databases

3. **Enforce password rotation for privileged accounts**:
   - Require teachers and admins to change passwords every 90 days
   - Send email reminder 7 days before expiration
   - Lock account if password not changed after expiration

---

### 2.5 Add Multi-Factor Authentication (MFA) for Teachers and Admins

**Suggestion Description**:
The design relies solely on password authentication with no mention of MFA.

**Rationale**:
Teachers and admins have elevated privileges (access to student data, ability to modify grades). Compromised credentials for these accounts have high impact. MFA significantly reduces risk of account takeover.

**Recommended Countermeasures**:
1. **Implement TOTP-based MFA** (Time-based One-Time Password):
   - Use `speakeasy` library for TOTP generation/validation
   - QR code enrollment flow (scan with Google Authenticator, Authy, etc.)
   - Backup codes for account recovery (10 codes, each usable once)

2. **MFA enforcement policy**:
   - Required for all teachers and admins (enforced at login)
   - Optional but recommended for students
   - Grace period: 7 days after role upgrade to teacher/admin

3. **Add MFA-aware session management**:
   - Issue separate access token after MFA verification
   - Token claim: `{ "mfa_verified": true }`
   - Sensitive operations (grade changes, user deletion) require `mfa_verified` token

---

### 2.6 Implement Data Retention and Deletion Policy (GDPR/FERPA Compliance)

**Suggestion Description**:
The design includes backup strategy (Section 7) but no data retention or deletion policy.

**Rationale**:
Educational platforms must comply with FERPA (Family Educational Rights and Privacy Act) and potentially GDPR. Users have right to data deletion ("right to be forgotten"). Retaining data indefinitely increases liability in case of breach.

**Recommended Countermeasures**:
1. **Define data retention policy**:
   - Active student data: Retained while enrolled + 5 years after graduation
   - Inactive accounts: Delete after 2 years of inactivity (with 90-day warning email)
   - Payment records: 7 years (tax compliance)
   - Audit logs: 7 years (FERPA compliance)
   - Temporary files (uploads in progress): 7 days

2. **Implement account deletion workflow**:
   - User-initiated deletion: Soft delete for 30 days (recoverable), then hard delete
   - Hard delete process:
     - Anonymize user records (replace email with `deleted_user_{id}@example.com`)
     - Delete uploaded content from S3
     - Preserve submission records for course integrity (anonymized)
     - Delete from backups after 30 days

3. **Add GDPR data export**:
   - `GET /api/users/me/export` endpoint
   - Generate JSON archive of all user data (profile, submissions, payments, access logs)
   - Signed S3 URL with 24-hour expiration
   - Log export requests in audit log

---

### 2.7 Add Secrets Management System

**Suggestion Description**:
The design does not specify how secrets (database passwords, JWT signing keys, Stripe API keys, AWS credentials) are managed.

**Rationale**:
Hardcoded secrets or secrets in environment variables risk exposure through:
- Accidental commit to version control
- Log files or error messages
- Process listing or memory dumps
- Access by unauthorized team members

**Recommended Countermeasures**:
1. **Use AWS Secrets Manager or HashiCorp Vault**:
   - Store all secrets in centralized secret store
   - Application fetches secrets at startup via IAM role (no credentials in code)
   - Automatic secret rotation (database passwords every 90 days)

2. **Implement secret rotation procedure**:
   - JWT signing key rotation: Generate new key monthly, accept tokens signed with previous 2 keys (grace period)
   - Database password rotation: Use AWS RDS automated rotation
   - Stripe API key rotation: Generate new restricted key, deprecate old key after migration

3. **Prevent secret leakage**:
   - Add `.env` to `.gitignore` (enforce via pre-commit hook)
   - Scan commits for secrets using `trufflehog` or `git-secrets`
   - Redact secrets from application logs (use Winston redaction feature)

---

### 2.8 Implement Dependency Vulnerability Scanning

**Suggestion Description**:
The design lists dependencies (Section 2) but does not specify security update or vulnerability scanning procedures.

**Rationale**:
Third-party dependencies frequently have security vulnerabilities. The design uses many dependencies (Express, Passport.js, jsonwebtoken, multer, Socket.io, Stripe SDK, AWS SDK). Failing to update dependencies creates known attack vectors.

**Recommended Countermeasures**:
1. **Integrate automated vulnerability scanning in CI/CD**:
   - Run `npm audit` on every pull request (block merge if HIGH/CRITICAL vulnerabilities)
   - Use Snyk or Dependabot for automated dependency updates
   - GitHub Actions workflow:
     ```yaml
     - name: Security audit
       run: npm audit --audit-level=high
     ```

2. **Define dependency update policy**:
   - Critical security updates: Apply within 24 hours
   - High-severity updates: Apply within 1 week
   - Medium/low-severity: Apply in next sprint
   - Monthly review of outdated dependencies

3. **Pin dependency versions and use lock files**:
   - Use `package-lock.json` (committed to version control)
   - Pin exact versions in `package.json` for production dependencies
   - Allow patch updates only (`~1.2.3` not `^1.2.3`)

---

### 2.9 Add Encryption at Rest for Sensitive Data

**Suggestion Description**:
The design specifies HTTPS for data in transit (Section 7) but does not mention encryption at rest.

**Rationale**:
Sensitive data (student records, payment information, assignment submissions) stored unencrypted in database or S3 could be exposed if:
- Database backup is stolen or leaked
- Attacker gains read access to database (SQL injection, insider threat)
- S3 bucket misconfiguration exposes files

**Recommended Countermeasures**:
1. **Enable database encryption at rest**:
   - Use AWS RDS encryption with AWS KMS
   - Encrypt PostgreSQL data files, backups, and snapshots
   - Use separate KMS key per environment (dev/staging/prod)

2. **Enable S3 server-side encryption**:
   - Use S3 SSE-KMS for all buckets
   - Separate KMS keys for videos vs. assignment submissions
   - Enable S3 bucket versioning + MFA Delete for compliance

3. **Implement application-level encryption for PII**:
   - Encrypt sensitive fields (email, student ID, payment info) before storing in database
   - Use AES-256-GCM with per-record keys (data key encryption with KMS)
   - Store encrypted data as BYTEA or TEXT (base64-encoded)

---

### 2.10 Implement Threat Modeling for Live Streaming Components

**Suggestion Description**:
The design includes live streaming functionality (AWS MediaLive/MediaPackage, WebRTC) but does not address streaming-specific threats.

**Rationale**:
Live streaming introduces unique attack vectors:
- Unauthorized viewing of paid/private streams
- Stream hijacking (attacker replaces legitimate stream with malicious content)
- Zoom-bombing style disruptions (unwanted participants in live session)
- Recording and redistribution of copyrighted content

**Recommended Countermeasures**:
1. **Implement signed streaming URLs**:
   - Generate time-limited signed URLs using CloudFront signed URLs
   - Expiration: 2 hours (duration of typical class session)
   - User must be authenticated and enrolled in course to receive signed URL
   - One URL per user (detect sharing via concurrent IP address monitoring)

2. **Add stream access control**:
   - Verify JWT token before allowing WebRTC connection
   - Implement waiting room for live sessions (teacher approves participants)
   - Ability to kick/ban disruptive participants

3. **Enable stream recording protection**:
   - Watermark streams with viewer's user ID (deter redistribution)
   - Use DRM for premium content (Widevine/FairPlay)
   - Monitor for unauthorized stream recording (detect screen capture software via client-side checks - note: not foolproof)

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Data Residency and Compliance Requirements

**Confirmation Reason**:
The design uses AWS infrastructure but does not specify:
- Geographic region for data storage
- Compliance requirements (GDPR, FERPA, COPPA if serving children under 13)
- Data sovereignty restrictions (e.g., EU data must stay in EU)

**Options and Trade-offs**:

**Option A: US-only deployment (FERPA compliance)**
- Store all data in AWS us-east-1 or us-west-2
- Simpler compliance (only FERPA applicable)
- Lower latency for US users
- Cannot serve EU users (GDPR issues)

**Option B: Multi-region deployment (GDPR + FERPA compliance)**
- EU users: data in AWS eu-west-1 (Frankfurt)
- US users: data in AWS us-east-1 (Virginia)
- Requires data residency routing logic in application
- Higher complexity and cost (duplicate infrastructure)
- Enables global user base

**Option C: Privacy Shield/Standard Contractual Clauses**
- Store all data in US with GDPR compliance via SCCs
- Simpler architecture than Option B
- Legal risk (Privacy Shield invalidated in 2020, SCCs under scrutiny)

**Recommendation**: Clarify target user geography and regulatory requirements before finalizing infrastructure design.

---

### 3.2 Session Timeout and Inactivity Policy

**Confirmation Reason**:
The design specifies 24-hour token expiration but does not address:
- Inactivity timeout (should session expire if user idle for 2 hours?)
- Different timeout requirements for different user roles (students vs. teachers vs. admins)
- Behavior on public/shared computers

**Options and Trade-offs**:

**Option A: Absolute expiration only (current design)**
- Token valid for 24 hours regardless of activity
- Simpler implementation (no server-side session tracking)
- Security risk: Stolen token valid for full 24 hours even if user is idle

**Option B: Sliding window expiration**
- Token expires after 2 hours of inactivity
- Each API request extends expiration by 2 hours (up to 24-hour max)
- Better security (idle sessions expire)
- Requires server-side tracking of last activity time (Redis)

**Option C: Different timeouts per role**
- Students: 24-hour absolute, 2-hour inactivity
- Teachers: 12-hour absolute, 1-hour inactivity
- Admins: 8-hour absolute, 30-minute inactivity (higher privilege = shorter timeout)
- Most secure but most complex

**Recommendation**: Implement Option B (sliding window) with 2-hour inactivity timeout for all users.

---

### 3.3 Open/Closed Course Model Security

**Confirmation Reason**:
The courses table includes `is_public` field, but the design does not clarify:
- Can anyone view content of public courses without paying?
- Are video URLs accessible without authentication?
- How to prevent "paywalled" content from being leaked?

**Options and Trade-offs**:

**Option A: Public = anyone can view all content for free**
- `is_public = true` courses have no access control
- Maximizes discoverability and user acquisition
- No revenue from public courses
- Risk: Teachers accidentally set paid courses to public

**Option B: Public = discoverable, but payment required to access content**
- `is_public = true` means visible in course catalog
- Users must enroll (free or paid) to access videos/assignments
- Prevents accidental content leakage
- Requires clear UI distinction between "discoverable" and "free"

**Option C: Hybrid with preview content**
- Public courses allow viewing first 2 videos (preview)
- Full access requires enrollment (payment for paid courses)
- Balances discoverability with revenue protection

**Recommendation**: Clarify business model and implement appropriate access control checks in video streaming endpoint.

---

## 4. Positive Evaluation (good points)

### 4.1 Use of Bcrypt with Appropriate Cost Factor

The design correctly specifies bcrypt for password hashing with cost factor 10 (Section 7: "パスワードはbcryptでハッシュ化(コスト係数10)"). This is appropriate for 2024 hardware (balances security and performance). The use of a modern KDF (bcrypt) instead of plain SHA-256 prevents rainbow table attacks and makes brute-force attacks computationally expensive.

### 4.2 Parameterized Queries for SQL Injection Prevention

The design explicitly mentions using parameterized queries (Section 7: "SQLインジェクション対策: パラメータ化クエリ使用"). This is the correct approach for preventing SQL injection and shows security awareness. As long as this is consistently enforced throughout the codebase (via ORM like TypeORM or Knex.js), the risk of SQL injection is minimal.

### 4.3 HTTPS Enforcement

The design mandates HTTPS for all API communication (Section 7: "すべてのAPI通信はHTTPSで暗号化"). This protects data in transit from eavesdropping and MITM attacks. Combined with secure JWT storage (after implementing recommendations), this provides strong transport security.

### 4.4 Database Replication for Availability

The design includes database replication strategy (Section 7: "データベースレプリケーション: マスター1台、スレーブ2台"). This not only improves availability but also enables read scaling (route read queries to replicas). From a security perspective, this reduces risk of data loss in case of ransomware or corruption attacks (assuming replicas have delayed synchronization).

### 4.5 Comprehensive Backup Strategy

The design specifies daily full backups and continuous transaction log backups (Section 7). This enables point-in-time recovery, which is crucial for recovering from security incidents (e.g., mass data deletion by compromised admin account). The backup strategy supports disaster recovery and business continuity.

### 4.6 Role-Based Access Control (RBAC) Design

The design implements RBAC with three roles (student, teacher, admin) and enforces authorization checks on endpoints (Section 5: "各エンドポイントでユーザーロールを検証"). This is a solid foundation for access control. The granular endpoint-level permissions (e.g., only teachers can create courses) demonstrate principle of least privilege.

### 4.7 Separation of Concerns in Service Architecture

The design uses a microservices-oriented architecture with clearly separated services (Auth, Content, Streaming, Assignment, Payment, Notification). This separation limits blast radius of security incidents—a vulnerability in Streaming Service does not directly compromise Payment Service. This architecture supports defense-in-depth.

---

## Summary

The EduStream platform design demonstrates foundational security awareness (HTTPS, bcrypt, parameterized queries, RBAC) but requires significant security enhancements before production deployment. The most critical issues are:

1. **Authentication vulnerabilities** (localStorage JWT, no session invalidation)
2. **Missing security controls** (rate limiting, file upload restrictions, input validation)
3. **Insufficient audit logging** (repudiation risks, compliance gaps)
4. **No idempotency mechanisms** (duplicate payment/submission risks)

Implementing the recommended countermeasures—particularly fixing the JWT storage mechanism and adding comprehensive input validation—will substantially improve the platform's security posture. The design shows good architectural foundations (service separation, database replication) that, when combined with the suggested security controls, can support a production-ready educational platform.

**Overall Risk Assessment**: MODERATE-HIGH. The platform should not be deployed to production without addressing the Critical Issues (Section 1). After implementing recommendations, the platform can achieve an acceptable security posture for educational use.
