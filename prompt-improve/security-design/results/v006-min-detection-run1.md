# Security Evaluation: EduStream Online Education Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple STRIDE threat categories lack explicit mitigation strategies in the design |
| Authentication & Authorization Design | 2 | JWT in localStorage creates critical XSS exposure risk; 24-hour token expiration too long |
| Data Protection | 2 | No encryption-at-rest policy, missing data retention/deletion policies, PII handling undefined |
| Input Validation Design | 2 | No input validation policy defined; file upload restrictions missing; injection risks present |
| Infrastructure & Dependencies | 3 | Missing secret management strategy, no dependency security policy, deployment security incomplete |
| **Overall** | **2.2** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Storage in localStorage Enables XSS-based Account Takeover

**Problem Description**: The design specifies storing JWT tokens in client-side localStorage with a 24-hour expiration (Section 5, Authentication). This creates a critical vulnerability where any XSS attack can extract tokens valid for an entire day.

**Impact**:
- Any XSS vulnerability (e.g., in chat, Q&A forum, course descriptions) allows attackers to steal valid tokens
- 24-hour validity window amplifies damage: attackers gain full account access for extended periods
- Educational platform context increases risk: stolen teacher accounts could modify grades, access student PII, inject malicious content into course materials

**Recommended Countermeasures**:
- Switch to HttpOnly + Secure + SameSite=Strict cookies for token storage (prevents JavaScript access)
- Reduce access token lifetime to 15 minutes
- Implement refresh token rotation (7-day refresh token with single-use rotation)
- Add CSRF protection for state-changing operations when using cookies

**Relevant Section**: Section 5 (API Design), Authentication & Authorization

---

### 1.2 File Upload System Lacks Security Controls

**Problem Description**: The design mentions file uploads via multer for assignment submissions (Section 2) but provides no security controls for file validation, size limits, or content inspection.

**Impact**:
- Malicious file uploads could enable:
  - Storage-based attacks (zip bombs, billion laughs XML)
  - Content-based XSS (SVG files with embedded scripts)
  - Server-side code execution (PHP/JSP files if misconfigured)
  - Denial of service via storage exhaustion
- Student-submitted files distributed to teachers create supply-chain attack vectors

**Recommended Countermeasures**:
- Define explicit file type whitelist (e.g., PDF, DOCX, PNG, JPG only)
- Implement strict file size limits (e.g., 10MB per file, 50MB per submission)
- Add content-type validation (check magic bytes, not just extension)
- Store uploaded files with randomized names outside web root
- Implement virus scanning for uploaded content (ClamAV integration)
- Add rate limiting: 10 submissions per student per hour

**Relevant Section**: Section 4 (Data Model - submissions.file_url), Section 5 (API - POST /api/submissions)

---

### 1.3 Stripe Webhook Lacks Signature Verification Design

**Problem Description**: The design includes a Stripe webhook endpoint (`POST /api/payments/webhook`) but does not specify webhook signature verification, enabling payment manipulation attacks.

**Impact**:
- Attackers can forge webhook events to:
  - Grant free course access without payment
  - Manipulate payment status from 'pending' to 'completed'
  - Trigger refund processing without actual Stripe refunds
- No authentication on webhook endpoint allows unauthorized external requests

**Recommended Countermeasures**:
- Implement Stripe webhook signature verification using `stripe.webhooks.constructEvent()`
- Store Stripe webhook signing secret in secure configuration (not in code)
- Add idempotency handling using `stripe_payment_id` to prevent duplicate processing
- Log all webhook events with full payload for audit trails
- Implement webhook retry logic with exponential backoff

**Relevant Section**: Section 5 (API Design - POST /api/payments/webhook)

---

### 1.4 Missing Rate Limiting on Authentication Endpoints

**Problem Description**: While the design mentions rate limiting at the API Gateway level (Section 3), no specific rate limits are defined for authentication endpoints (`/api/auth/login`, `/api/auth/register`).

**Impact**:
- Enables credential stuffing attacks using leaked password databases
- Allows account enumeration via registration/login response timing
- Teacher/admin account compromise has severe impact (grade manipulation, access to all student data)

**Recommended Countermeasures**:
- Implement strict rate limiting on `/api/auth/login`: 5 attempts per 15 minutes per IP
- Add account-level lockout: lock account for 30 minutes after 5 failed attempts
- Implement CAPTCHA after 3 failed login attempts
- Rate limit `/api/auth/register`: 3 registrations per hour per IP
- Add distributed rate limiting using Redis to prevent bypass via load balancer

**Relevant Section**: Section 3 (Architecture - API Gateway), Section 5 (API - Authentication endpoints)

---

### 1.5 No Encryption-at-Rest for Sensitive Educational Data

**Problem Description**: The design specifies PostgreSQL for storing user data, payment records, and grades but does not mention encryption-at-rest policies.

**Impact**:
- Database backup compromise exposes:
  - Student personally identifiable information (email, potentially SSNs if added later)
  - Payment information (amounts, transaction IDs)
  - Educational records (grades, submissions, feedback)
- Regulatory compliance risk: FERPA (Family Educational Rights and Privacy Act) requires protection of student records

**Recommended Countermeasures**:
- Enable AWS RDS encryption-at-rest using AES-256
- Encrypt S3 buckets storing video content and submission files (S3-SSE or KMS)
- Implement application-level encryption for highly sensitive fields (e.g., `bcrypt` for passwords already mentioned, consider encrypting email addresses)
- Document data classification policy: Public, Internal, Confidential, Restricted

**Relevant Section**: Section 2 (Technology Stack - Database), Section 7 (Security Requirements)

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Add Comprehensive Audit Logging for Security-Critical Operations

**Suggestion Description**: Design an audit log system capturing authentication events, authorization failures, data access, and administrative actions.

**Rationale**:
- Educational platforms are subject to compliance requirements (FERPA, GDPR)
- Audit logs enable forensic analysis after security incidents
- Required for detecting insider threats (e.g., teachers accessing unauthorized student records)

**Recommended Countermeasures**:
- Log the following events with timestamp, user ID, IP address, action, result:
  - All authentication attempts (success and failure)
  - Authorization failures (attempted access to forbidden resources)
  - Grade modifications (original value, new value, modifier ID)
  - Course content modifications
  - Payment transactions
  - Administrative actions (user deletions, role changes)
- Store audit logs separately from application logs (immutable log storage)
- Implement log retention policy: 2 years for compliance
- Add real-time alerting for suspicious patterns (e.g., mass data downloads, role escalation attempts)

**Relevant Section**: Section 6 (Implementation - Logging Policy)

---

### 2.2 Implement Row-Level Security (RLS) for Multi-Tenant Data Isolation

**Suggestion Description**: Add database-level access controls to prevent horizontal privilege escalation where users access other users' data.

**Rationale**:
- Application-layer authorization bugs can bypass access controls
- Database-level RLS provides defense-in-depth
- Prevents accidental data leakage via query errors

**Recommended Countermeasures**:
- Enable PostgreSQL Row-Level Security on tables containing user-specific data:
  - `submissions`: Students can only see their own submissions
  - `payments`: Users can only see their own payment records
  - `courses`: Teachers can only modify their own courses
- Create security policies using `CREATE POLICY` with user context from `current_setting()`
- Test RLS policies with automated tests simulating cross-user access attempts
- Document RLS policies in database migration files

**Relevant Section**: Section 4 (Data Model), Section 7 (Security Requirements)

---

### 2.3 Add CSRF Protection for State-Changing Operations

**Suggestion Description**: Implement CSRF token validation for all state-changing API endpoints (POST/PUT/DELETE).

**Rationale**:
- If switching to cookie-based authentication (as recommended in 1.1), CSRF protection becomes essential
- Educational platform context: attackers could trick teachers into unknowingly submitting grades or deleting content via malicious sites

**Recommended Countermeasures**:
- Implement Double Submit Cookie pattern:
  - Generate random CSRF token on login
  - Send token in both cookie (SameSite=Strict) and custom header (X-CSRF-Token)
  - Validate token match on server for all POST/PUT/DELETE requests
- Alternative: Use SameSite=Strict cookies alone for modern browsers (still vulnerable in older browsers)
- Add CSRF middleware to Express application before route handlers
- Exclude webhook endpoints from CSRF validation (use signature verification instead)

**Relevant Section**: Section 5 (API Design), Section 7 (Security Requirements - XSS prevention)

---

### 2.4 Define Data Retention and Deletion Policy

**Suggestion Description**: Establish clear policies for how long user data is retained and how it is securely deleted.

**Rationale**:
- GDPR Article 17 (Right to Erasure) requires ability to delete user data
- Educational records have specific retention requirements under FERPA
- Minimizes data exposure surface area (less data = less risk)

**Recommended Countermeasures**:
- Define retention periods by data type:
  - Active user data: Retained while account is active
  - Inactive accounts: Anonymize after 3 years of inactivity
  - Payment records: Retain for 7 years (tax compliance)
  - Video content: Retain while course is active + 1 year
  - Audit logs: Retain for 2 years
- Implement "Right to Erasure" workflow:
  - User-initiated deletion request via API endpoint
  - 30-day grace period before permanent deletion
  - Anonymize data instead of deletion where legal retention required (replace email with hash, remove PII)
- Add scheduled jobs to automatically purge expired data
- Document deletion procedures in compliance documentation

**Relevant Section**: Section 4 (Data Model), Section 7 (Security Requirements)

---

### 2.5 Implement Input Validation Policy at API Layer

**Suggestion Description**: Define and enforce comprehensive input validation rules for all API endpoints.

**Rationale**:
- Prevents injection attacks (SQL injection, NoSQL injection, command injection)
- Protects against business logic flaws (negative prices, invalid email formats)
- Currently only SQLi prevention via parameterized queries is mentioned (Section 7)

**Recommended Countermeasures**:
- Define validation schema for each API endpoint using `joi` or `zod`:
  - Email format validation (RFC 5322)
  - Password complexity: min 12 characters, must include uppercase, lowercase, digit, special character
  - Course price: non-negative decimal with max 2 decimal places
  - UUIDs: validate format before database queries
  - Text fields: max length limits (title: 500 chars, description: 5000 chars)
- Implement centralized validation middleware
- Reject requests with unexpected fields (strict schema validation)
- Add input sanitization for user-generated content displayed in HTML (course titles, descriptions, chat messages)
- Document validation rules in API specification (OpenAPI/Swagger)

**Relevant Section**: Section 5 (API Design), Section 7 (Security Requirements)

---

### 2.6 Add Secret Management Strategy

**Suggestion Description**: Design secure storage and rotation procedures for secrets (database passwords, API keys, JWT signing keys).

**Rationale**:
- Currently no mention of how secrets are managed
- Hardcoded secrets in code/config files are common vulnerability sources
- Secret rotation is essential for limiting exposure window

**Recommended Countermeasures**:
- Use AWS Secrets Manager or AWS Systems Manager Parameter Store for secret storage
- Never commit secrets to version control (add `.env` to `.gitignore`)
- Implement automatic secret rotation:
  - Database passwords: rotate every 90 days
  - JWT signing keys: rotate every 6 months with key versioning
  - Stripe API keys: rotate annually
- Use different secrets per environment (dev, staging, production)
- Implement secret access auditing (log all secret retrievals)
- Add startup validation to ensure all required secrets are present

**Relevant Section**: Section 2 (Technology Stack - AWS), Section 6 (Deployment)

---

### 2.7 Implement Content Security Policy (CSP) Headers

**Suggestion Description**: Define CSP headers for the React frontend to mitigate XSS attacks.

**Rationale**:
- Educational platform has multiple user-generated content sources (course descriptions, chat, Q&A forums)
- CSP provides defense-in-depth against XSS even if output escaping fails

**Recommended Countermeasures**:
- Configure CSP headers on API Gateway/CloudFront:
  ```
  Content-Security-Policy:
    default-src 'self';
    script-src 'self' 'unsafe-inline' https://js.stripe.com;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https://*.cloudfront.net;
    media-src 'self' https://*.cloudfront.net;
    connect-src 'self' https://api.stripe.com;
    frame-ancestors 'none';
  ```
- Remove `'unsafe-inline'` by using nonce-based CSP for production
- Add CSP violation reporting: `report-uri /api/csp-violations`
- Test CSP in report-only mode before enforcement

**Relevant Section**: Section 7 (Security Requirements - XSS prevention)

---

### 2.8 Add Session Management Controls

**Suggestion Description**: Implement session invalidation, concurrent session limits, and session timeout policies.

**Rationale**:
- Current design mentions JWT but no session management lifecycle
- Educational context: shared computer labs require robust logout mechanisms

**Recommended Countermeasures**:
- Implement server-side session tracking in Redis:
  - Store active session IDs mapped to user IDs
  - Invalidate sessions on logout (add to blacklist with TTL)
  - Enable "logout from all devices" functionality
- Add concurrent session limits: max 3 active sessions per user
- Implement idle timeout: 30 minutes of inactivity invalidates session
- Add absolute session timeout: 24 hours max session lifetime even with activity
- Notify users of new login from unrecognized device/location

**Relevant Section**: Section 5 (Authentication), Section 2 (Redis for sessions)

---

### 2.9 Implement Video Access Control and Watermarking

**Suggestion Description**: Add access control checks before generating video streaming URLs and implement video watermarking to prevent unauthorized redistribution.

**Rationale**:
- Paid courses require protection against content piracy
- `/api/videos/:id/stream` endpoint needs authorization beyond basic authentication

**Recommended Countermeasures**:
- Implement enrollment verification before generating streaming URLs:
  - Check if user has active payment record for the course
  - Verify course is not expired (if time-limited subscriptions exist)
- Generate time-limited signed URLs for S3/CloudFront (expire after 1 hour)
- Add dynamic watermarking with user email/ID embedded in video stream
- Implement concurrent viewer limits per account (prevent credential sharing)
- Add DRM (Digital Rights Management) for high-value content using AWS MediaPackage encryption

**Relevant Section**: Section 5 (API - GET /api/videos/:id/stream)

---

### 2.10 Add Dependency Vulnerability Scanning

**Suggestion Description**: Integrate automated dependency vulnerability scanning into CI/CD pipeline.

**Rationale**:
- Node.js ecosystems have frequent security updates
- Libraries like `jsonwebtoken`, `multer`, `passport.js` have had historical vulnerabilities

**Recommended Countermeasures**:
- Add `npm audit` to CI/CD pipeline (fail build on high/critical vulnerabilities)
- Integrate Snyk or Dependabot for automated dependency updates
- Establish dependency update policy:
  - Security patches: apply within 7 days
  - Minor version updates: monthly review
  - Major version updates: quarterly review
- Pin exact dependency versions in `package-lock.json`
- Monitor security advisories for critical dependencies (GitHub Security Advisories, Node Security Project)

**Relevant Section**: Section 6 (Deployment - CI/CD), Section 2 (Libraries)

---

### 2.11 Implement Idempotency Keys for Payment Operations

**Suggestion Description**: Add idempotency key support for payment creation to prevent duplicate charges.

**Rationale**:
- Network failures can cause clients to retry payment requests
- Without idempotency, users could be charged multiple times for the same course

**Recommended Countermeasures**:
- Require `Idempotency-Key` header on `POST /api/payments/create`
- Store idempotency key in Redis with 24-hour TTL
- Return cached response if duplicate request detected (same key)
- Use Stripe's built-in idempotency support by passing key to Stripe API
- Document idempotency key format requirements (UUID v4)

**Relevant Section**: Section 5 (API - POST /api/payments/create)

---

### 2.12 Add Database Connection Pool Limits and Timeout Configuration

**Suggestion Description**: Define explicit connection pool limits and query timeout settings to prevent resource exhaustion.

**Rationale**:
- Unbounded connection pools can exhaust database resources under high load
- Long-running queries can cause cascading failures

**Recommended Countermeasures**:
- Configure PostgreSQL connection pool settings:
  - Max pool size: 20 connections per instance
  - Connection timeout: 5 seconds
  - Idle connection timeout: 10 minutes
  - Query timeout: 30 seconds (fail slow queries)
- Implement circuit breaker pattern for database connections
- Add database connection health checks in load balancer
- Monitor connection pool metrics (active connections, queue depth)

**Relevant Section**: Section 2 (Database - PostgreSQL), Section 3 (Architecture)

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Multi-Factor Authentication (MFA) for High-Privilege Accounts

**Confirmation Reason**: The design does not mention MFA for teacher or admin accounts. Educational platforms store sensitive student data and financial information, making teacher/admin accounts high-value targets.

**Options and Trade-offs**:
- **Option A - MFA Required for Teachers/Admins**:
  - Pros: Significantly reduces account takeover risk; industry best practice
  - Cons: Additional implementation complexity; may inconvenience users
  - Implementation: TOTP-based MFA using `speakeasy` library, backup codes, SMS fallback
- **Option B - MFA Optional**:
  - Pros: Better user experience; faster rollout
  - Cons: Weaker security posture; may not meet compliance requirements
- **Option C - Risk-Based MFA**:
  - Pros: Balance security and UX; only prompt for MFA on suspicious activity (new device, unusual location)
  - Cons: More complex implementation; requires IP geolocation and device fingerprinting

**Recommendation**: Option A (required MFA) for admin accounts at minimum; Option C for teacher accounts.

---

### 3.2 Real-Time Chat Moderation and Content Filtering

**Confirmation Reason**: The design includes real-time chat/Q&A forums but no content moderation strategy. Educational platforms are vulnerable to abuse (harassment, spam, malicious links).

**Options and Trade-offs**:
- **Option A - Automated Content Filtering**:
  - Pros: Scalable; real-time protection
  - Cons: False positives; requires maintenance
  - Implementation: AWS Comprehend for toxic content detection, regex for malicious URLs
- **Option B - Manual Moderation Only**:
  - Pros: No false positives; human judgment
  - Cons: Not scalable; delayed response
- **Option C - Hybrid Approach**:
  - Pros: Best balance of automation and accuracy
  - Cons: Highest complexity
  - Implementation: Automated flagging + teacher/admin review queue

**Recommendation**: Option C for production deployment; start with Option A for MVP.

---

### 3.3 Data Residency and Geographic Restrictions

**Confirmation Reason**: No mention of data residency requirements. Educational institutions may have restrictions on where student data can be stored (GDPR for EU users, state laws in US).

**Options and Trade-offs**:
- **Option A - Single Global Region (US East)**:
  - Pros: Simple architecture; lower cost
  - Cons: May violate compliance requirements; higher latency for international users
- **Option B - Multi-Region Deployment**:
  - Pros: Compliance with data residency laws; better global performance
  - Cons: Significant infrastructure complexity; higher cost; cross-region data synchronization challenges
- **Option C - Regional Isolation**:
  - Pros: Maximum compliance; clear data boundaries
  - Cons: Highest complexity; separate deployments per region

**Recommendation**: Clarify target market before deciding. For US-only MVP, Option A is acceptable. For EU/international markets, Option B is required.

---

### 3.4 Video Content DRM and Anti-Piracy Measures

**Confirmation Reason**: The design stores video content in S3 with CloudFront distribution but does not specify DRM or anti-piracy measures. This may be acceptable for free content but problematic for paid courses.

**Options and Trade-offs**:
- **Option A - No DRM (Signed URLs Only)**:
  - Pros: Simple implementation; broad device compatibility
  - Cons: Vulnerable to URL sharing; no protection against screen recording
  - Best for: Free or low-value content
- **Option B - Basic DRM (Encrypted HLS)**:
  - Pros: Prevents casual piracy; supported by AWS MediaPackage
  - Cons: Still vulnerable to screen recording; some device compatibility issues
  - Best for: Moderately priced content
- **Option C - Enterprise DRM (Widevine/FairPlay)**:
  - Pros: Strong content protection; prevents most piracy
  - Cons: High complexity; licensing costs; limited device support
  - Best for: High-value premium content

**Recommendation**: Clarify content pricing model. Start with Option B for paid content; Option A for free/preview content.

---

## 4. Positive Evaluation (good points)

### 4.1 Parameterized Queries for SQL Injection Prevention

The design explicitly mentions using parameterized queries for SQL injection prevention (Section 7). This is a fundamental security best practice that prevents one of the most common web application vulnerabilities.

---

### 4.2 Password Hashing with bcrypt

The design specifies bcrypt with cost factor 10 for password storage (Section 7). This demonstrates proper understanding of password security (salted hashing with adaptive cost function). Cost factor 10 is reasonable for current hardware (authentication time ~100ms).

---

### 4.3 HTTPS Encryption for All API Communication

The design mandates HTTPS for all API communication (Section 7), ensuring confidentiality and integrity of data in transit. This is essential for protecting authentication tokens and sensitive user data.

---

### 4.4 Separation of Concerns via Service-Oriented Architecture

The architecture separates concerns into distinct services (Auth Service, Content Service, Payment Service, etc. - Section 3). This provides security benefits through isolation: compromise of one service doesn't automatically compromise others.

---

### 4.5 Use of AWS Managed Services

The design leverages AWS managed services (RDS, S3, MediaLive) instead of self-managed alternatives (Section 2). This shifts security responsibility for infrastructure patching and maintenance to AWS, reducing the attack surface.

---

### 4.6 Database Replication for Availability

The design includes database replication (1 master, 2 slaves - Section 7), providing both performance benefits and disaster recovery capabilities. This protects against data loss and enables faster recovery from incidents.

---

### 4.7 Output Escaping for XSS Prevention

The design mentions output escaping for XSS prevention (Section 7). While implementation details are not provided, the awareness of this requirement is positive.

---

### 4.8 Automated Testing with Coverage Goals

The testing strategy includes unit, integration, and E2E tests with 80% coverage target (Section 6). Comprehensive testing helps identify security flaws before production deployment.

---

### 4.9 Blue-Green Deployment for Safe Rollouts

The deployment strategy uses blue-green deployment (Section 6), enabling zero-downtime deployments and fast rollback if security issues are discovered post-deployment.

---

### 4.10 Unique Constraint on stripe_payment_id

The payments table includes a UNIQUE constraint on `stripe_payment_id` (Section 4), preventing duplicate payment processing even without explicit idempotency key handling. This provides basic protection against double-charging.
