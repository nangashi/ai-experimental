# Security Design Review: EduStream Online Education Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple STRIDE threats lack explicit countermeasures, particularly Repudiation and Denial of Service |
| Authentication & Authorization Design | 2 | JWT in localStorage is vulnerable to XSS; 24-hour token expiration is excessive; no refresh token rotation |
| Data Protection | 3 | TLS for transit is good, but no encryption-at-rest specification for S3/database; unclear PII handling |
| Input Validation Design | 2 | No input validation policy defined; file upload lacks size/type restrictions; no output escaping implementation detail |
| Infrastructure & Dependencies | 3 | Uses established libraries but lacks secret management design, dependency scanning policy, and security update process |
| **Overall** | **2.4** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Storage and Expiration Design is Dangerous

**Problem**: The design specifies storing JWT tokens in localStorage with a 24-hour expiration (Section 5, Authentication & Authorization). This creates two critical vulnerabilities:
1. localStorage is accessible to any JavaScript code on the page, making tokens vulnerable to XSS attacks
2. 24-hour expiration extends the window of compromise after token theft

**Impact**: If even a single XSS vulnerability exists anywhere in the application, attackers can steal tokens valid for 24 hours, enabling complete account takeover for teachers (access to all course data) and students (identity theft, grade manipulation).

**Recommended Countermeasures**:
- Switch to HttpOnly cookies with Secure and SameSite=Strict attributes to prevent XSS-based token theft
- Reduce access token expiration to 15 minutes
- Implement refresh tokens (7-day expiration) with automatic rotation on each use
- Store refresh tokens in HttpOnly cookies separate from access tokens
- Implement token revocation list (blacklist) in Redis for logout functionality

**Relevant Section**: Section 5 - Authentication & Authorization Design

### 1.2 Missing CSRF Protection Design

**Problem**: The design specifies using JWT for authentication but does not mention CSRF (Cross-Site Request Forgery) protection for state-changing operations (POST/PUT/DELETE endpoints).

**Impact**: Attackers can craft malicious websites that trigger authenticated actions (course deletion, grade modification, payment initiation) if a logged-in user visits the attacker's site. For example, an attacker could create a page that automatically submits a course deletion request or modifies assignment grades.

**Recommended Countermeasures**:
- Implement Double Submit Cookie pattern: generate a random CSRF token on login, send it in both a cookie and require it in a custom header (X-CSRF-Token) for all state-changing requests
- Apply CSRF validation middleware to all POST/PUT/DELETE endpoints
- Verify that SameSite=Strict is enforced on authentication cookies (already recommended in 1.1)
- Document CSRF token generation and validation flow in the authentication design

**Relevant Section**: Section 5 - API Design (all POST/PUT/DELETE endpoints)

### 1.3 Stripe Webhook Authentication Not Specified

**Problem**: The design includes a Stripe webhook endpoint (`POST /api/payments/webhook`) but does not specify webhook signature verification (Section 5, Payment API).

**Impact**: Without signature verification, attackers can send forged webhook events to the application, potentially:
- Granting course access without payment
- Marking failed payments as successful
- Creating fraudulent payment records in the database

**Recommended Countermeasures**:
- Implement Stripe webhook signature verification using the webhook secret and `stripe.webhooks.constructEvent()` method
- Reject all webhook requests that fail signature validation
- Store the webhook secret in a secure secret management system (see Infrastructure recommendation)
- Log all webhook verification failures with source IP for security monitoring
- Implement idempotency handling for webhook events using `stripe_payment_id` as idempotency key

**Relevant Section**: Section 5 - Payment API, Section 4 - payments table

### 1.4 File Upload Security Design is Incomplete

**Problem**: The design mentions using multer for file uploads (Section 2, Section 5 - video/assignment uploads) but does not specify:
1. File size limits
2. File type restrictions
3. Filename sanitization
4. Virus/malware scanning
5. Upload rate limiting

**Impact**:
- Unrestricted file sizes can lead to storage exhaustion and DoS attacks
- Unrestricted file types allow uploading of malware or executable files that could be served to other users
- Malicious filenames can cause path traversal vulnerabilities or XSS when displayed
- Students could submit extremely large or numerous files to exhaust teacher/admin resources

**Recommended Countermeasures**:
- Define maximum file sizes: 500MB for video uploads, 10MB for assignment submissions
- Whitelist allowed MIME types: video/* for videos, application/pdf and image/* for assignments
- Sanitize uploaded filenames: remove special characters, enforce UUID-based S3 keys (already in design)
- Integrate ClamAV or AWS S3 Malware Protection for virus scanning before making files accessible
- Implement upload rate limiting: max 5 uploads per hour per user for assignments, max 20 videos per day per teacher
- Store original filename separately from S3 key and escape it when displaying to users

**Relevant Section**: Section 5 - Video Upload API, Assignment Submission API

### 1.5 Missing Audit Logging for Critical Operations

**Problem**: While the design mentions access logging for API requests (Section 6, Logging Policy), there is no specification for audit logging of critical security events:
- Authentication events (login, logout, failed login attempts, token refresh)
- Authorization failures (attempted unauthorized access)
- Data modification events (course deletion, grade changes, user role changes)
- Payment events (payment creation, completion, failures)
- Admin actions (user suspension, content moderation)

**Impact**: Without audit logs, security incidents cannot be detected or investigated effectively. For example:
- Brute-force attacks cannot be detected without failed login logging
- Unauthorized access attempts go unnoticed
- Grade tampering or fraudulent payments cannot be traced
- Insider threats from compromised admin accounts cannot be identified

**Recommended Countermeasures**:
- Design dedicated audit log schema with fields: timestamp, user_id, action, resource_type, resource_id, ip_address, user_agent, result (success/failure), details
- Store audit logs in a separate append-only table or dedicated logging service (CloudWatch Logs with retention policy)
- Log the following events:
  - All authentication events (login, logout, token refresh, password reset)
  - All authorization failures with attempted action and reason
  - All data modifications on sensitive tables (users, courses, submissions, payments)
  - All admin operations
  - All payment webhook events
- Implement log retention policy: 90 days in hot storage, 7 years in cold storage for compliance
- Create automated alerts for suspicious patterns (multiple failed logins, repeated authorization failures)

**Relevant Section**: Section 6 - Logging Policy

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Rate Limiting Design is Missing

**Suggestion**: The design mentions rate limiting in the API Gateway component (Section 3) but does not specify:
- Rate limits per endpoint
- Rate limiting strategy (per IP, per user, per API key)
- Rate limit enforcement mechanism
- Rate limit exceeded responses

**Rationale**: Without explicit rate limits, the platform is vulnerable to:
- Brute-force attacks on login endpoints
- API abuse that degrades service for legitimate users
- DoS attacks exhausting backend resources
- Credential stuffing attacks using leaked password databases

**Recommended Countermeasures**:
- Implement tiered rate limiting using express-rate-limit or AWS API Gateway throttling:
  - Authentication endpoints: 5 requests per 15 minutes per IP (strict)
  - Read endpoints: 100 requests per minute per user (standard)
  - Write endpoints: 20 requests per minute per user (moderate)
  - Video upload: 5 requests per hour per teacher (strict)
  - Payment creation: 10 requests per hour per user (strict)
- After 5 failed login attempts from the same IP or for the same email: implement 30-minute account lock
- Return HTTP 429 (Too Many Requests) with Retry-After header when limits are exceeded
- Log all rate limit violations for security monitoring
- Store rate limit state in Redis for distributed enforcement across multiple API Gateway instances

**Relevant Section**: Section 3 - API Gateway Component

### 2.2 Session Management and Token Revocation Design is Incomplete

**Suggestion**: The design specifies JWT authentication (Section 5) but does not address:
- How logout is implemented (JWTs are stateless)
- Token revocation mechanism for compromised accounts
- Session invalidation when password is reset
- Multi-device session management
- Detection of concurrent sessions from different IPs

**Rationale**: Without proper session management:
- Logout does not actually invalidate tokens (tokens remain valid until expiration)
- Compromised tokens cannot be revoked before expiration
- Password changes do not immediately protect the account
- Attackers can maintain persistent access even after user detects compromise

**Recommended Countermeasures**:
- Implement token blacklist in Redis with TTL matching token expiration
- On logout: add token JTI (JWT ID) to blacklist
- On password reset: add all issued tokens for that user to blacklist
- Add JTI (unique token identifier) claim to all JWTs
- Design token validation middleware to check blacklist before accepting tokens
- Implement session table to track active sessions with: user_id, token_jti, ip_address, user_agent, created_at, last_used_at
- Provide UI for users to view and revoke active sessions
- Implement anomaly detection: alert users when login occurs from new IP/device

**Relevant Section**: Section 5 - Authentication & Authorization Design

### 2.3 Input Validation Policy is Not Defined

**Suggestion**: While the design mentions SQL injection and XSS countermeasures (Section 7, Security Requirements), there is no comprehensive input validation policy specifying:
- Which fields require validation
- Validation rules for each data type
- Where validation occurs (client-side, API layer, service layer)
- How validation errors are reported

**Rationale**: Without a formal input validation policy:
- Developers may inconsistently apply validation
- Edge cases and boundary conditions may be missed
- Second-order injection vulnerabilities may arise from data stored without validation
- Business logic bypasses may occur (e.g., negative prices, future deadlines)

**Recommended Countermeasures**:
- Define input validation policy document specifying:
  - Email: RFC 5322 format validation, maximum 255 characters
  - Password: minimum 12 characters, require uppercase, lowercase, number, special character
  - Course title: 1-500 characters, sanitize HTML
  - Price: non-negative DECIMAL(10,2), range validation 0.00-9999.99
  - Dates: ISO 8601 format, future date validation for deadlines
  - UUIDs: strict UUID v4 format validation
  - File uploads: see Critical Issue 1.4
- Implement validation at multiple layers:
  - Client-side: immediate user feedback (not for security)
  - API layer: express-validator middleware on all endpoints
  - Service layer: additional business logic validation
- Use parameterized queries exclusively (already mentioned for SQL injection)
- Implement output encoding library (e.g., DOMPurify) for user-generated content display
- Validate all data read from database before use (defense against data corruption or past validation bypasses)

**Relevant Section**: Section 5 - API Design, Section 7 - Security Requirements

### 2.4 Data Retention and Deletion Policy is Missing

**Suggestion**: The design does not specify data retention policies for:
- User personal data (GDPR compliance)
- Deleted courses and videos
- Audit logs
- Payment records
- Soft delete vs hard delete strategy

**Rationale**: Without a data retention policy:
- Regulatory compliance risks (GDPR right to erasure, PCI-DSS data retention)
- Storage costs increase indefinitely
- Data breach impact is larger due to unnecessary data retention
- Legal discovery obligations are unclear

**Recommended Countermeasures**:
- Define data retention policy:
  - User personal data: retain while account is active, delete within 30 days of account deletion request
  - Deleted courses/videos: soft delete with 30-day recovery window, then hard delete (remove S3 files)
  - Audit logs: 90 days hot storage, 7 years cold storage (compliance requirement)
  - Payment records: retain for 7 years (tax/legal requirement), anonymize user PII after 3 years
  - Submitted assignments: retain for course duration + 1 year, then delete
- Implement soft delete pattern: add `deleted_at` column to courses, videos, users tables
- Create automated cleanup jobs (cron) to purge expired data
- Implement "right to erasure" API endpoint for GDPR compliance
- Document legal basis for data processing in privacy policy

**Relevant Section**: Section 4 - Data Model, Section 7 - Security Requirements

### 2.5 Secret Management Design is Missing

**Suggestion**: The design mentions using various API keys and secrets (JWT signing key, Stripe API key, AWS credentials, database passwords) but does not specify:
- Where secrets are stored
- How secrets are rotated
- How secrets are accessed by the application
- Environment-specific secret management

**Rationale**: Poor secret management leads to:
- Hardcoded secrets in source code (exposed in version control)
- Secrets leaked in logs or error messages
- Inability to rotate secrets after compromise
- Difficulty managing secrets across multiple environments

**Recommended Countermeasures**:
- Use AWS Secrets Manager or AWS Systems Manager Parameter Store for all secrets:
  - Database credentials
  - JWT signing key (HS256) or private key (RS256)
  - Stripe API secret key
  - Stripe webhook signing secret
  - AWS access keys (use IAM roles instead where possible)
- Never commit secrets to version control; use .env files in .gitignore for local development
- Implement secret rotation policy:
  - JWT signing key: rotate every 90 days
  - Database passwords: rotate every 180 days
  - Stripe API keys: rotate annually or immediately upon suspected compromise
- Retrieve secrets at application startup and cache in memory (not on disk)
- Use IAM roles for EC2/ECS instances instead of hardcoded AWS credentials
- Audit secret access logs in AWS CloudTrail

**Relevant Section**: Section 2 - Technology Stack, Section 3 - Infrastructure

### 2.6 Content Security Policy (CSP) is Not Specified

**Suggestion**: The design does not mention implementing Content Security Policy headers to mitigate XSS attacks.

**Rationale**: Even with output escaping, XSS vulnerabilities can occur. CSP provides defense-in-depth by:
- Restricting sources of JavaScript execution
- Preventing inline script execution (common XSS vector)
- Blocking eval() and similar dangerous functions
- Preventing mixed content (HTTP resources on HTTPS pages)

**Recommended Countermeasures**:
- Implement strict CSP header:
  ```
  Content-Security-Policy:
    default-src 'self';
    script-src 'self' https://js.stripe.com;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https://s3.amazonaws.com;
    media-src 'self' https://cloudfront.net;
    connect-src 'self' https://api.stripe.com;
    frame-src https://js.stripe.com;
    object-src 'none';
    base-uri 'self';
    form-action 'self';
  ```
- Start with CSP in report-only mode to identify violations without breaking functionality
- Monitor CSP violation reports to detect XSS attempts
- Remove 'unsafe-inline' from script-src and style-src if possible (use nonces or hashes)
- Configure CSP to work with Stripe embedded payment forms

**Relevant Section**: Section 7 - Security Requirements (XSS Countermeasures)

### 2.7 Database Security Configuration is Not Detailed

**Suggestion**: The design mentions PostgreSQL as the main database (Section 2) but does not specify:
- Database user privilege separation
- Network isolation
- Encryption at rest
- Backup encryption
- Connection encryption enforcement

**Rationale**: Database compromise can lead to complete data breach. Proper database security prevents:
- Privilege escalation from application compromise
- Network-based attacks on database
- Data exposure from stolen backups
- Interception of unencrypted database connections

**Recommended Countermeasures**:
- Create separate database users with minimal privileges:
  - Application user: SELECT, INSERT, UPDATE, DELETE on application tables only (no DDL, no DROP)
  - Migration user: Full schema modification privileges (used only during deployments)
  - Backup user: SELECT only (for backup processes)
- Place database in private subnet with no internet access
- Use security groups to allow connections only from application tier
- Enable PostgreSQL SSL/TLS connections and enforce with `sslmode=require` connection parameter
- Enable AWS RDS encryption at rest using KMS
- Encrypt database backups using KMS
- Implement database connection pooling with PgBouncer to limit connection count
- Disable default `postgres` superuser account; create named admin users for emergency access

**Relevant Section**: Section 2 - Database, Section 3 - Infrastructure

### 2.8 Dependency Security Management is Not Defined

**Suggestion**: The design lists several third-party libraries (Section 2) but does not specify:
- Dependency vulnerability scanning process
- Update policy for security patches
- Approved library list
- License compliance checking

**Rationale**: Third-party dependencies are a major attack vector:
- Known vulnerabilities in outdated libraries (e.g., Passport.js CVEs)
- Supply chain attacks (malicious packages)
- Transitive dependencies with vulnerabilities

**Recommended Countermeasures**:
- Integrate npm audit or Snyk into CI/CD pipeline; fail builds on high/critical vulnerabilities
- Run weekly scheduled dependency scans and create tickets for vulnerabilities
- Define SLA for patching vulnerabilities:
  - Critical: patch within 7 days
  - High: patch within 30 days
  - Medium: patch within 90 days
- Use package-lock.json and commit it to version control for reproducible builds
- Implement Dependabot or Renovate for automated dependency update PRs
- Review all new dependencies for:
  - Maintenance status (last update, number of maintainers)
  - Security track record (past CVEs)
  - License compatibility
- Use npm scripts to automate security checks: `npm run security-check`

**Relevant Section**: Section 2 - Major Libraries, Section 6 - Deployment Policy

### 2.9 Live Streaming Security is Not Addressed

**Suggestion**: The design includes live streaming functionality using AWS MediaLive/MediaPackage (Section 2, Section 3) but does not address:
- Stream access control (preventing unauthorized viewing)
- Stream URL expiration
- Stream encryption
- Protection against stream piracy

**Rationale**: Live streaming presents unique security challenges:
- Stream URLs can be shared to unauthorized users
- Streams can be recorded and redistributed
- Bandwidth can be exhausted by attackers requesting streams
- Sensitive content (private courses) may be exposed

**Recommended Countermeasures**:
- Implement signed URLs for stream access with 1-hour expiration using AWS CloudFront signed URLs
- Verify course enrollment before generating signed URLs
- Use HLS encryption (AES-128) for stream content
- Implement DRM for premium content using AWS Elemental MediaPackage DRM integration
- Log all stream URL generations with user_id, course_id, timestamp for audit
- Implement stream viewer authentication via WebSocket connection (Socket.io)
- Rate limit stream URL generation to 10 requests per minute per user
- Monitor for unusual streaming patterns (same URL accessed from multiple IPs)

**Relevant Section**: Section 2 - Streaming Infrastructure, Section 3 - Streaming Service

### 2.10 Error Message Security is Not Specified

**Suggestion**: The design mentions suppressing stack traces in production (Section 6, Error Handling) but does not address:
- What information should NOT be included in error messages
- Consistent error responses that don't leak implementation details
- Logging of full error details separately from user-facing messages

**Rationale**: Verbose error messages can leak sensitive information:
- Database errors revealing schema or query structure
- Authentication errors distinguishing between "user not found" and "wrong password" (username enumeration)
- File path errors revealing server directory structure
- Validation errors revealing business logic

**Recommended Countermeasures**:
- Define error message policy:
  - User-facing errors: generic messages only (e.g., "Authentication failed" instead of "User not found")
  - Logged errors: full details including stack trace, request parameters (sanitized), user context
- Implement error message sanitization:
  - Database errors: return "Database error occurred" to user, log full error server-side
  - File system errors: return "File operation failed", never expose file paths
  - Authentication errors: always return "Invalid credentials" regardless of specific failure reason
- Use error codes instead of descriptive messages for client-side error handling
- Example error response structure:
  ```json
  {
    "error": {
      "code": "AUTH_001",
      "message": "Authentication failed",
      "requestId": "uuid"
    }
  }
  ```
- Create error code documentation for internal use only
- Implement correlation IDs (requestId) to link user-facing errors to detailed server logs

**Relevant Section**: Section 6 - Error Handling Policy

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Password Policy Trade-offs

**Question**: Should the system enforce strong password requirements (minimum 12 characters, complexity rules) or support passwordless authentication (email magic links, OAuth)?

**Options**:
1. **Strong password policy**: Requires users to create complex passwords, reduces credential stuffing risk but decreases user convenience
2. **Passwordless authentication**: Uses email magic links or OAuth (Google, Microsoft), improves UX but requires email infrastructure reliability and OAuth provider trust
3. **Hybrid approach**: Allow both traditional passwords and OAuth, maximum flexibility but increases implementation complexity

**Trade-offs**:
- Security: Passwordless is more secure against phishing and password reuse; password policy is more secure against email account compromise
- User experience: Passwordless is more convenient; password policy is familiar but burdensome
- Implementation: Password policy is simpler; passwordless requires email delivery infrastructure and OAuth integration

**Recommendation**: Hybrid approach - implement strong password policy (12+ characters, complexity) for traditional auth, and add OAuth for Google/Microsoft SSO to support institutional users. Prioritize OAuth integration for teacher accounts (higher privilege).

### 3.2 Data Residency and Compliance Requirements

**Question**: What geographical regions will the platform serve, and are there specific data residency requirements (GDPR, FERPA, regional data protection laws)?

**Implications**:
- GDPR (EU): Requires data residency in EU, consent management, right to erasure, data processing agreements
- FERPA (US education): Requires strict access controls on student records, audit logging, parental consent for minors
- Regional laws (China, Russia, etc.): May require local data storage and encryption key escrow

**Recommended Approach**:
- Clarify target regions and compliance requirements before finalizing architecture
- If multi-region: design data partitioning strategy to store user data in home region
- If EU users: implement AWS EU-only regions (eu-west-1, eu-central-1), cookie consent management, GDPR compliance features
- If US K-12: implement FERPA-compliant access controls, parental consent workflow, directory information opt-out

### 3.3 Payment Security and PCI-DSS Compliance

**Question**: Will the system directly handle credit card data or use Stripe's hosted payment pages?

**Options**:
1. **Stripe Checkout (hosted)**: Stripe hosts the payment form, minimal PCI scope, easiest compliance
2. **Stripe Elements (embedded)**: Payment form embedded in application, broader PCI scope (SAQ A-EP), better UX customization
3. **Direct card handling**: Store/process card data directly, full PCI-DSS compliance required (not recommended)

**Current design implication**: The design mentions "Stripe API" but does not specify the integration method. This affects PCI compliance scope.

**Recommendation**: Use Stripe Checkout (hosted) for initial launch to minimize PCI compliance burden. If custom payment UX is required later, upgrade to Stripe Elements with PCI SAQ A-EP compliance (quarterly scans, annual assessments).

### 3.4 Content Moderation and Copyright Protection

**Question**: What policies and technical controls are needed for moderating user-uploaded content (videos, assignments) to prevent copyright infringement, inappropriate content, or malware?

**Considerations**:
- Legal liability: Platform may be liable for hosted infringing content under DMCA
- Safety: Inappropriate content can harm users (especially minors in educational context)
- Malware: Uploaded files could contain malware distributed to other users

**Recommended Approach**:
- Implement pre-publication review for all uploaded videos (teacher/admin approval before public)
- Add reporting mechanism for students to flag inappropriate content
- Integrate automated content moderation:
  - AWS Rekognition for video content analysis (detect inappropriate imagery)
  - ClamAV or AWS S3 Malware Protection for virus scanning
  - Content fingerprinting to detect copyrighted material
- Define DMCA takedown process and designate DMCA agent
- Implement abuse detection: flag users with multiple policy violations for review

---

## 4. Positive Evaluation (good points)

### 4.1 Strong Baseline Security Practices

The design demonstrates several good security fundamentals:
- **HTTPS enforcement**: All API communication is specified to use HTTPS, protecting data in transit (Section 7)
- **Password hashing with bcrypt**: Properly uses bcrypt with cost factor 10 for password storage (Section 7)
- **Parameterized queries**: Explicitly mentions using parameterized queries for SQL injection prevention (Section 7)
- **Output escaping for XSS**: Mentions output escaping to prevent XSS attacks (Section 7)

These are essential baseline protections and their inclusion shows security awareness in the design.

### 4.2 Appropriate Use of UUIDs for Primary Keys

The data model consistently uses UUIDs for primary keys across all tables (Section 4). This provides:
- **Prevention of enumeration attacks**: Prevents attackers from guessing valid resource IDs (e.g., iterating through `/api/courses/1`, `/api/courses/2`)
- **Better security for distributed systems**: UUIDs are globally unique, reducing collision risks in multi-region deployments
- **Privacy protection**: Obscures growth metrics and user counts from external observers

This is a good security-conscious design decision.

### 4.3 Role-Based Access Control (RBAC) Model

The design includes a clear RBAC model with three roles (teacher, student, admin) and specifies role-based authorization for endpoints (Section 5). This provides:
- **Principle of least privilege**: Each role has only the permissions needed for their function
- **Clear authorization boundaries**: API documentation explicitly states which roles can access which endpoints
- **Foundation for audit logging**: Roles provide context for logging and monitoring access patterns

The RBAC design is well-structured for an educational platform's authorization needs.

### 4.4 Structured Logging and Monitoring Foundation

The design includes a comprehensive logging strategy using Winston with multiple log levels and environment-specific outputs (Section 6). This provides:
- **Security monitoring capability**: Centralized logging in CloudWatch enables security event correlation
- **Incident response support**: Structured logs facilitate investigation of security incidents
- **Compliance support**: Access logging provides audit trail for compliance requirements

The logging infrastructure is a solid foundation, though it needs enhancement with specific audit logging (see Critical Issue 1.5).

### 4.5 Separation of Concerns in Architecture

The 3-tier architecture with dedicated services (Auth, Content, Streaming, Payment, etc.) demonstrates good security design (Section 3):
- **Isolation of critical functions**: Authentication and payment processing are separate services, limiting blast radius of vulnerabilities
- **Defense in depth**: API Gateway provides centralized enforcement point for rate limiting and authentication
- **Scalability for security controls**: Services can have different security policies appropriate to their risk level

This architectural separation supports applying security controls proportionally to risk.
