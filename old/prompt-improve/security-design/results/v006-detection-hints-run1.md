# Security Design Review - EduStream Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple critical threats lack explicit countermeasures, including session hijacking prevention, repudiation controls, and DoS protection mechanisms |
| Authentication & Authorization Design | 2 | JWT in localStorage creates XSS vulnerability window, 24-hour token lifetime is excessive, and no session invalidation mechanism exists |
| Data Protection | 2 | No encryption-at-rest specification for sensitive data, no data retention policy, missing privacy controls for student records and payment data |
| Input Validation Design | 3 | SQL injection and XSS are mentioned but validation policy is not explicitly defined; file upload lacks size limits, type restrictions, and malware scanning |
| Infrastructure & Dependencies | 3 | Secret management strategy is absent, dependency security scanning not mentioned, AWS resource security configurations unspecified |
| **Overall** | **2.4** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Storage and Lifetime Creates Account Takeover Risk

**Problem**: The design specifies storing JWT tokens in localStorage with a 24-hour expiration (Section 5 - Authentication). This combination creates two critical vulnerabilities:

1. **localStorage allows token theft via XSS**: Any XSS vulnerability in the application allows attackers to steal tokens via JavaScript
2. **24-hour expiration extends damage window**: Once stolen, the token remains valid for a full day, allowing prolonged unauthorized access

**Impact**:
- If even one XSS vulnerability exists anywhere in the React SPA, attackers can steal tokens of all users who visit the compromised page
- Stolen tokens grant full account access for 24 hours with no detection or revocation mechanism
- For teachers, this means unauthorized access to student data, grade modification, and course content manipulation
- For students, this means unauthorized course enrollment and payment information exposure

**Recommended Countermeasures**:
1. **Switch to HttpOnly cookies**: Store JWT in cookies with `HttpOnly`, `Secure`, and `SameSite=Strict` attributes to prevent JavaScript access and CSRF attacks
2. **Reduce token lifetime**: Implement short-lived access tokens (15 minutes) with long-lived refresh tokens (7 days)
3. **Implement refresh token rotation**: Issue new refresh token on each refresh, invalidate old one
4. **Add token revocation list**: Store active refresh tokens in Redis with user-initiated logout capability

**Relevant Section**: Section 5 - API Design, Authentication & Authorization

---

### 1.2 Missing Rate Limiting Design Across All Endpoints

**Problem**: The design mentions "API Gateway" performs rate limiting (Section 3) but provides no specifications for:
- Rate limit thresholds per endpoint type
- User-based vs IP-based limiting
- Burst allowance configuration
- Rate limit response handling (429 status, retry-after headers)

**Impact**:
- **Authentication endpoints** (`/api/auth/login`, `/api/auth/register`) vulnerable to credential stuffing and brute-force attacks
- **Payment endpoints** (`/api/payments/create`) vulnerable to payment fraud attempts and cost inflation attacks
- **File upload endpoints** (`/api/videos`, `/api/submissions`) vulnerable to storage exhaustion attacks
- **No protection against application-layer DoS** targeting expensive operations (video transcoding, assignment grading)

**Recommended Countermeasures**:
1. **Tiered rate limiting strategy**:
   - **Auth endpoints**: 5 attempts per 15 minutes per IP + account lockout after 5 failures (30 min)
   - **Public endpoints** (`GET /api/courses`): 100 requests per minute per IP
   - **Authenticated endpoints**: 1000 requests per hour per user
   - **Admin endpoints**: 50 requests per minute per user
   - **Payment endpoints**: 10 requests per hour per user
2. **Use express-rate-limit with Redis store** for distributed rate limiting across multiple servers
3. **Implement progressive delays** for repeated auth failures (exponential backoff)
4. **Add CAPTCHA** after 3 failed login attempts

**Relevant Section**: Section 3 - Architecture Design, Section 5 - API Design

---

### 1.3 Missing CSRF Protection for State-Changing Operations

**Problem**: The design does not mention CSRF (Cross-Site Request Forgery) protection mechanisms for any state-changing API endpoints. While JWT authentication is mentioned, there is no specification for CSRF token validation.

**Impact**:
- If JWT tokens are readable from JavaScript (current localStorage design), CSRF attacks are trivial
- Even with HttpOnly cookies, SameSite=Strict alone may not be sufficient for older browsers
- Critical operations vulnerable to CSRF:
  - Course purchase (`POST /api/payments/create`)
  - Course deletion (`DELETE /api/courses/:id`)
  - Assignment grade modification (`PUT /api/submissions/:id/grade`)
  - Video upload/deletion

**Recommended Countermeasures**:
1. **If using cookies**: Implement Double Submit Cookie pattern:
   - Generate CSRF token on login, store in cookie (non-HttpOnly) and return in response body
   - Client sends token in custom header (`X-CSRF-Token`) on all state-changing requests
   - Server validates cookie value matches header value
2. **If using Authorization header**: CSRF risk is lower, but still implement Origin/Referer header validation
3. **Apply CSRF middleware** to all POST/PUT/DELETE/PATCH endpoints
4. **Configure SameSite=Strict** on all cookies (already recommended in 1.1)

**Relevant Section**: Section 5 - API Design, Section 7 - Security Requirements

---

### 1.4 No Data Encryption at Rest Specification

**Problem**: The design does not specify encryption-at-rest for sensitive data stored in PostgreSQL, Redis, or S3. Only in-transit encryption (HTTPS) is mentioned (Section 7).

**Impact**:
- **Database compromise** (e.g., snapshot theft, insider threat) exposes:
  - User email addresses and password hashes
  - Payment records including Stripe payment IDs
  - Student submissions and teacher feedback
- **S3 bucket misconfiguration** exposes:
  - Student assignment files (may contain personal information)
  - Video content (intellectual property)
- **Redis cache compromise** exposes:
  - Active session tokens
  - Cached user data

**Recommended Countermeasures**:
1. **PostgreSQL**: Enable Transparent Data Encryption (TDE) using AWS RDS encryption with AWS KMS
2. **S3**: Enable default bucket encryption (SSE-S3 or SSE-KMS)
3. **Redis**: Use Redis 6.0+ with TLS encryption for data in transit, consider Redis Enterprise for encryption at rest
4. **Specify KMS key rotation policy**: Automatic annual rotation
5. **Document which fields require additional application-level encryption**:
   - Consider encrypting `submissions.file_url` and `videos.s3_key` at application level for defense in depth

**Relevant Section**: Section 2 - Technology Stack, Section 7 - Non-Functional Requirements

---

### 1.5 Missing Input Validation Policy and File Upload Security

**Problem**: The design mentions using multer for file uploads and "parameter-ized queries" for SQL injection prevention, but lacks explicit validation policies for:

1. **File upload validation**: No specifications for:
   - Allowed file types (MIME type validation)
   - Maximum file size limits
   - Filename sanitization
   - Malware/virus scanning
   - Content type verification (not just extension checking)

2. **Input validation rules**: No validation specifications for:
   - Email format validation
   - Password complexity requirements
   - Course title/description length limits
   - Price value ranges
   - Video duration limits

**Impact**:
- **File upload vulnerabilities**:
  - Malicious file upload (executable disguised as video/document)
  - Zip bomb or storage exhaustion (multi-GB file uploads)
  - Path traversal via malicious filenames (`../../etc/passwd`)
  - XSS via SVG files or HTML files in assignment submissions
- **Input validation gaps**:
  - NoSQL injection if any NoSQL databases are added
  - Command injection if filenames are passed to shell commands
  - Business logic bypass (negative prices, extremely long course descriptions)

**Recommended Countermeasures**:

**File Upload Security**:
1. **Whitelist allowed MIME types**:
   - Videos: `video/mp4`, `video/webm`
   - Assignments: `application/pdf`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
2. **File size limits**:
   - Videos: 5GB maximum
   - Assignments: 50MB maximum
3. **Filename sanitization**: Remove all special characters, enforce UUID-based storage names
4. **Virus scanning**: Integrate ClamAV or AWS S3 Malware Protection
5. **Content type verification**: Check file magic bytes, not just extension
6. **Quarantine uploads**: Store in separate S3 bucket, move to production bucket only after validation

**Input Validation**:
1. **Use validation library** (e.g., Joi, express-validator) on all API endpoints
2. **Define validation schemas** for each request type:
   ```typescript
   registerSchema = {
     email: string, maxLength(255), email format
     password: string, minLength(12), complexity requirements
   }
   courseSchema = {
     title: string, maxLength(500), sanitize HTML
     description: string, maxLength(10000), sanitize HTML
     price: number, min(0), max(100000)
   }
   ```
3. **Reject invalid requests** with 400 status and detailed validation errors

**Relevant Section**: Section 2 - Technology Stack (multer), Section 5 - API Design, Section 7 - Security Requirements

---

### 1.6 Missing Audit Logging Design

**Problem**: The design mentions "access logs" for all API requests (Section 6) but does not specify:
- **Security event logging**: What security-relevant events to log (failed auth, privilege escalation attempts, data access)
- **Log retention policy**: How long logs are kept
- **Log protection**: How logs are protected from tampering or deletion
- **Compliance requirements**: Whether FERPA (student data) or PCI DSS (payment data) logging is needed

**Impact**:
- **Incident response**: Cannot investigate security incidents or unauthorized access
- **Compliance violations**: FERPA requires audit trails for student record access; missing logs may violate regulations
- **Forensics**: Cannot determine scope of breach if compromise occurs
- **Accountability**: Cannot trace which admin deleted courses or modified grades

**Recommended Countermeasures**:

1. **Security Event Logging** - Log the following events with structured JSON format:
   - **Authentication events**: Login success/failure, logout, token refresh, password changes
   - **Authorization failures**: Attempted access to unauthorized resources
   - **Data access**: Access to student records, payment information, grade modifications
   - **Administrative actions**: User creation/deletion, course deletion, content approval/rejection
   - **File operations**: Video uploads, assignment submissions
   - **Payment transactions**: All payment attempts, successes, failures

2. **Log Format** - Include in every log entry:
   ```json
   {
     "timestamp": "ISO8601",
     "event_type": "LOGIN_FAILURE",
     "user_id": "uuid or null",
     "ip_address": "x.x.x.x",
     "user_agent": "...",
     "resource": "/api/auth/login",
     "result": "FAILURE",
     "reason": "invalid_password",
     "metadata": {...}
   }
   ```

3. **Log Retention Policy**:
   - Security logs: 1 year minimum (FERPA requirement)
   - Access logs: 90 days
   - Payment logs: 7 years (PCI DSS + tax requirements)

4. **Log Protection**:
   - Stream logs to **CloudWatch Logs** with write-only IAM permissions
   - Enable **CloudWatch Log Group encryption** with KMS
   - Use **S3 bucket with object lock** for long-term archival
   - Implement **log integrity verification** (digital signatures or Merkle trees)

5. **Log Monitoring**:
   - Set up CloudWatch Alarms for suspicious patterns:
     - 10+ failed logins from same IP in 5 minutes
     - Grade modifications outside business hours
     - Bulk data access attempts
   - Integrate with SIEM if available

**Relevant Section**: Section 6 - Implementation Policy (Logging), Section 7 - Non-Functional Requirements

---

### 1.7 Missing Idempotency Design for Payment Operations

**Problem**: The design does not specify idempotency mechanisms for the payment creation endpoint (`POST /api/payments/create`) or the Stripe webhook handler (`POST /api/payments/webhook`).

**Impact**:
- **Duplicate payments**: Network retry or user double-click can create multiple payment records for same course purchase
- **Race conditions**: Webhook may be processed multiple times if Stripe retries
- **Data inconsistency**: User may be charged multiple times but only granted access once (or vice versa)
- **Refund complexity**: Cannot determine which payment is legitimate vs duplicate

**Recommended Countermeasures**:

1. **Payment Creation Idempotency**:
   - Require `idempotency_key` in request (client-generated UUID)
   - Store idempotency key in Redis with 24-hour TTL, mapping to payment ID
   - On duplicate request with same key, return existing payment record (HTTP 200)
   - Use Stripe's built-in idempotency by passing key to Stripe API

2. **Webhook Idempotency**:
   - Store processed Stripe event IDs in database table `processed_stripe_events`
   - Check if event ID already processed before handling
   - Use database transaction to ensure atomic processing
   - Respond with HTTP 200 even if duplicate (prevents Stripe retry storm)

3. **Database-Level Uniqueness Constraint**:
   - Add unique constraint on `(user_id, course_id, stripe_payment_id)` in payments table
   - Handle unique constraint violation gracefully

**Relevant Section**: Section 5 - API Design (Payment endpoints)

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Add Secret Management Strategy

**Suggestion**: The design does not specify how sensitive credentials are managed:
- Database connection strings
- JWT signing secret
- Stripe API keys
- AWS access keys
- Redis connection password

**Rationale**: Hardcoded secrets or environment variables in source code create risk of:
- Accidental commit to version control
- Exposure in CI/CD logs
- Difficulty in secret rotation
- No audit trail for secret access

**Recommended Countermeasures**:
1. **Use AWS Secrets Manager** for all application secrets
2. **Implement automatic secret rotation**: 90-day rotation for database credentials, 30-day for API keys
3. **Access secrets via IAM roles**: ECS tasks retrieve secrets using task role, no long-lived credentials
4. **Never log secrets**: Implement secret redaction in Winston logging
5. **Use separate secrets per environment**: dev/staging/prod isolation

---

### 2.2 Specify Session Timeout and Concurrent Session Limits

**Suggestion**: The design specifies 24-hour token expiration but does not address:
- Idle session timeout (user inactive for X minutes)
- Concurrent session limits (user logged in from multiple devices)
- Session invalidation on password change

**Rationale**: Long-lived sessions without activity-based timeout increase risk of:
- Unattended session hijacking (user leaves browser open)
- Shared account abuse
- Stolen credentials remaining active after password change

**Recommended Countermeasures**:
1. **Idle timeout**: 30 minutes of inactivity invalidates session (shorter for admin users: 15 minutes)
2. **Concurrent session limit**: Allow 3 active sessions per user, revoke oldest when exceeded
3. **Store active sessions in Redis** with sliding TTL updated on each request
4. **Invalidate all sessions** on password change, email change, or role change
5. **Provide session management UI**: Let users view and revoke active sessions

---

### 2.3 Add Content Security Policy and XSS Defense

**Suggestion**: The design mentions "output escaping" for XSS prevention but lacks comprehensive XSS defense:
- No Content Security Policy (CSP) headers specified
- No specification of escaping library or strategy
- No mention of Trusted Types API

**Rationale**: React provides some XSS protection via auto-escaping, but gaps remain:
- `dangerouslySetInnerHTML` usage
- Dynamic script loading
- User-generated content rendering (course descriptions, forum posts)

**Recommended Countermeasures**:
1. **Implement strict CSP headers**:
   ```
   Content-Security-Policy:
     default-src 'self';
     script-src 'self';
     style-src 'self' 'unsafe-inline';
     img-src 'self' data: https://cdn.example.com;
     media-src 'self' https://mediapackage.amazonaws.com;
     connect-src 'self' https://api.stripe.com;
     frame-ancestors 'none';
   ```
2. **Use DOMPurify** for sanitizing user-generated HTML content
3. **Enable Trusted Types API** to prevent DOM XSS
4. **Set additional security headers**:
   - `X-Content-Type-Options: nosniff`
   - `X-Frame-Options: DENY`
   - `Referrer-Policy: strict-origin-when-cross-origin`

---

### 2.4 Specify Dependency Security Scanning Process

**Suggestion**: The design lists multiple third-party libraries (Passport.js, Stripe, multer, Socket.io) but does not specify:
- How dependencies are monitored for vulnerabilities
- Update/patching cadence
- Vulnerability severity thresholds for action

**Rationale**: Known vulnerabilities in dependencies are common attack vectors (e.g., npm package exploits). Without proactive scanning:
- Application may run with known CVEs
- Supply chain attacks may go undetected
- Compliance audits may fail

**Recommended Countermeasures**:
1. **Integrate npm audit** in CI/CD pipeline, fail build on high/critical vulnerabilities
2. **Use Dependabot or Renovate** for automated dependency updates
3. **Implement SCA (Software Composition Analysis)**: Snyk or GitHub Advanced Security
4. **Define patching SLA**:
   - Critical vulnerabilities: Patch within 7 days
   - High vulnerabilities: Patch within 30 days
   - Medium/Low: Patch in next release cycle
5. **Pin dependency versions** in package.json, use lock files

---

### 2.5 Add Stripe Webhook Signature Verification

**Suggestion**: The design mentions receiving Stripe webhooks (`POST /api/payments/webhook`) but does not specify:
- Webhook signature verification using Stripe signing secret
- Replay attack prevention
- Event type validation

**Rationale**: Without signature verification:
- Attackers can forge webhook events to grant free course access
- Payment status can be manipulated
- No guarantee webhook is from Stripe

**Recommended Countermeasures**:
1. **Verify Stripe signature** on every webhook request:
   ```typescript
   const sig = request.headers['stripe-signature'];
   const event = stripe.webhooks.constructEvent(request.body, sig, webhookSecret);
   ```
2. **Validate event types**: Only process expected events (`payment_intent.succeeded`, `payment_intent.failed`)
3. **Check event timestamp**: Reject events older than 5 minutes to prevent replay
4. **Use webhook secret** stored in AWS Secrets Manager
5. **Log all webhook events** for audit trail

---

### 2.6 Specify Data Retention and Deletion Policy

**Suggestion**: The design includes backup policy (Section 7) but does not address:
- How long user data is retained after account deletion
- GDPR/CCPA right-to-erasure compliance
- Cascade deletion rules for related entities
- Soft delete vs hard delete strategy

**Rationale**: Without defined retention policy:
- May violate GDPR (data must be deleted when no longer needed)
- May violate FERPA (student data retention limits)
- Zombie data accumulates, increasing storage costs and attack surface
- User "delete account" requests have undefined behavior

**Recommended Countermeasures**:
1. **Define retention periods**:
   - Active user data: Retained indefinitely while account active
   - Deleted accounts: 30-day soft delete grace period, then hard delete
   - Payment records: 7 years (legal requirement)
   - Audit logs: 1 year (FERPA requirement)
   - Video content: Delete when course deleted or 1 year after last access
2. **Implement cascade deletion logic**:
   - User deletion → soft delete user record, cascade delete sessions, delete S3 files
   - Course deletion → cascade delete videos, assignments, submissions (archive first)
3. **Use soft delete pattern**: Add `deleted_at` timestamp column, filter in queries
4. **Automated cleanup job**: Daily cron job to hard delete soft-deleted records past grace period
5. **User data export**: Provide API endpoint for users to download their data (GDPR compliance)

---

### 2.7 Add Authorization Matrix Documentation

**Suggestion**: The design mentions RBAC (role-based access control) with three roles (teacher, student, admin) but does not provide:
- Complete authorization matrix showing which roles can access which endpoints
- Permission inheritance rules
- Resource ownership validation (can teacher delete another teacher's course?)

**Rationale**: Without explicit authorization matrix:
- Developers may implement inconsistent permission checks
- Privilege escalation bugs are likely (e.g., student accessing teacher-only endpoints)
- Security testing cannot verify complete coverage

**Recommended Countermeasures**:
1. **Document authorization matrix** in table format:

   | Endpoint | Teacher | Student | Admin | Notes |
   |----------|---------|---------|-------|-------|
   | POST /api/courses | ✓ | ✗ | ✓ | |
   | DELETE /api/courses/:id | ✓ (own only) | ✗ | ✓ (any) | Check teacher_id |
   | PUT /api/submissions/:id/grade | ✓ (own course) | ✗ | ✓ | Check course ownership |
   | ... | ... | ... | ... | ... |

2. **Implement resource ownership validation**:
   ```typescript
   // Example: Only course owner or admin can delete
   if (course.teacher_id !== user.id && user.role !== 'admin') {
     throw new ForbiddenError();
   }
   ```

3. **Use permission middleware factory**:
   ```typescript
   app.delete('/api/courses/:id',
     requireAuth(),
     requireRole(['teacher', 'admin']),
     requireOwnership('course', 'teacher_id'),
     deleteCourse
   );
   ```

4. **Test authorization boundaries**: Include negative test cases (student attempts teacher endpoint)

---

### 2.8 Specify WebSocket Authentication and Message Validation

**Suggestion**: The design mentions WebSocket (Socket.io) for real-time communication but does not specify:
- How WebSocket connections are authenticated
- Whether JWT tokens are reused for WebSocket auth
- Message validation and sanitization
- Rate limiting for WebSocket messages

**Rationale**: WebSocket security is often overlooked:
- Unauthenticated WebSocket allows anonymous users to join chat/Q&A
- No message validation allows XSS via chat messages
- No rate limiting allows spam/DoS via rapid message sending

**Recommended Countermeasures**:
1. **WebSocket authentication**:
   ```typescript
   io.use((socket, next) => {
     const token = socket.handshake.auth.token;
     const user = verifyJWT(token);
     socket.user = user;
     next();
   });
   ```
2. **Message validation**: Validate and sanitize all incoming messages
3. **Rate limiting**: Limit to 10 messages per minute per user
4. **Room-based authorization**: Only enrolled students can join course chat rooms
5. **Message length limits**: 1000 characters per message
6. **Profanity filter**: Optional content moderation

---

### 2.9 Add Video Access Control and Signed URLs

**Suggestion**: The endpoint `GET /api/videos/:id/stream` returns "streaming URL" but does not specify:
- Whether S3 URLs are pre-signed with expiration
- Access control validation (is user enrolled in course?)
- URL sharing prevention

**Rationale**: Without signed URLs and access control:
- Students can share direct S3 URLs with non-enrolled users
- URLs remain valid indefinitely, enabling piracy
- Cannot revoke access after user unenrolls

**Recommended Countermeasures**:
1. **Generate pre-signed S3 URLs** with 1-hour expiration:
   ```typescript
   const url = s3.getSignedUrl('getObject', {
     Bucket: 'edustream-videos',
     Key: video.s3_key,
     Expires: 3600 // 1 hour
   });
   ```
2. **Verify course enrollment** before generating URL:
   ```typescript
   const enrollment = await checkEnrollment(user.id, video.course_id);
   if (!enrollment) throw new ForbiddenError();
   ```
3. **Use CloudFront signed URLs** instead of S3 for additional DRM options
4. **Log video access events** for analytics and abuse detection
5. **Implement concurrent stream limit**: Max 2 simultaneous streams per user

---

### 2.10 Specify Password Policy and Credential Security

**Suggestion**: The design specifies bcrypt with cost factor 10 for password hashing but does not address:
- Password complexity requirements
- Password history (prevent reuse)
- Account lockout policy
- Password change/reset flow security

**Rationale**: Weak passwords are primary attack vector. Without enforcement:
- Users choose weak passwords (password123)
- Attackers reuse leaked credentials
- No defense against credential stuffing

**Recommended Countermeasures**:
1. **Password complexity requirements**:
   - Minimum 12 characters
   - Must contain uppercase, lowercase, digit, special character
   - Reject common passwords (use zxcvbn library or haveibeenpwned API)
2. **Password history**: Prevent reuse of last 5 passwords (store hashes in separate table)
3. **Account lockout**: 5 failed attempts → 30-minute lockout (already mentioned in 1.2)
4. **Password reset flow**:
   - Send reset token (random 32-byte value, hashed in DB) via email
   - Token expires in 1 hour
   - Invalidate all sessions on password change
   - Require old password for password change (vs. reset)
5. **Consider MFA**: Offer optional TOTP-based 2FA for high-value accounts (teachers, admins)

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 FERPA Compliance Requirements

**Confirmation**: The platform handles student data (progress tracking, grades, assignments). Is the platform required to comply with FERPA (Family Educational Rights and Privacy Act)?

**Options and Trade-offs**:
- **If yes**: Must implement additional controls:
  - Parental consent for students under 18
  - Data access audit logs (1-year retention minimum)
  - Student/parent data access portal
  - Annual privacy notice
  - Restrict student data sharing with third parties
  - May require data residency (US-only storage)

- **If no**: Simpler compliance burden, but may limit customer base (US educational institutions require FERPA compliance)

**Recommendation**: Clarify compliance requirements early to avoid costly redesign

---

### 3.2 Data Residency and Internationalization

**Confirmation**: Will the platform serve users outside the US? Are there data residency requirements (GDPR for EU users, LGPD for Brazil, etc.)?

**Options and Trade-offs**:
- **US-only**: Deploy to single AWS region (e.g., us-east-1), simpler architecture
- **Multi-region**: Requires:
  - Database replication across regions
  - Region-aware routing (based on user location)
  - Separate data stores per region (GDPR requirement)
  - Data transfer restrictions (EU user data cannot be stored in US)

**Recommendation**: If international users are planned, design data residency architecture from the start

---

### 3.3 Live Streaming Moderation and Content Filtering

**Confirmation**: Will live streams and chat messages be moderated? Is there a need for automated content filtering (profanity, hate speech, NSFW content)?

**Options and Trade-offs**:
- **No moderation**: Lower cost, but risk of inappropriate content and legal liability
- **Manual moderation**: Hire moderators, higher cost, slower response
- **Automated filtering**:
  - Use AWS Rekognition for video content moderation
  - Use AWS Comprehend for text sentiment analysis
  - Implement profanity filter for chat
  - Trade-off: False positives may block legitimate educational content

**Recommendation**: At minimum, implement user reporting + admin review workflow

---

## 4. Positive Evaluation (good points)

### 4.1 Appropriate Cryptographic Choices

The design appropriately specifies:
- **bcrypt for password hashing** with cost factor 10 (Section 7): Industry-standard choice, resistant to GPU-based brute force
- **HTTPS for all API communication** (Section 7): Prevents man-in-the-middle attacks and credential interception
- **Parameterized queries** (Section 7): Correct approach to prevent SQL injection

These foundational security measures demonstrate awareness of OWASP Top 10 risks.

---

### 4.2 Role-Based Access Control Design

The RBAC model with three distinct roles (teacher, student, admin) is appropriate for the use case. The design correctly identifies role-specific endpoints (e.g., only teachers can create courses, only admins can delete any course). This provides good foundation for authorization logic.

---

### 4.3 Comprehensive Logging Infrastructure

The use of Winston for structured logging with environment-specific outputs (console for dev, CloudWatch for production) demonstrates good operational maturity. Centralized logging in CloudWatch enables security monitoring and incident investigation.

**Recommendation**: Build on this foundation by implementing the security event logging specified in Issue 1.6.

---

### 4.4 Resilient Architecture with Auto-Scaling

The design includes:
- Auto-scaling based on CPU metrics (Section 7)
- Database replication (1 master, 2 slaves)
- Daily backups with transaction logs

This provides good foundation for availability and disaster recovery, which indirectly supports security (DoS resilience, data loss prevention).

**Recommendation**: Extend this by adding explicit DoS protection (rate limiting) as specified in Issue 1.2.
