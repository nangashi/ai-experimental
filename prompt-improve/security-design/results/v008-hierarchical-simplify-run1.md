# Security Design Review: Real Estate Rental Platform

## Critical Issues (design modification required)

### 1. JWT Token Storage in localStorage Enables XSS-Based Account Takeover
**Severity**: Critical (Score: 1)

**Issue**: Section 3.4 Data Flow states "User authenticates via JWT token stored in localStorage". This storage method combined with the 24-hour token expiration (Section 5.4) creates severe vulnerability to XSS attacks.

**Impact**:
- Any XSS vulnerability in the React application allows attackers to steal JWT tokens via JavaScript
- With 24-hour token validity, stolen tokens provide extended unauthorized access
- Affects all user roles including admins, enabling privilege escalation
- Single XSS exploit can lead to complete account takeover for thousands of users

**Recommended Countermeasures**:
- Switch to HttpOnly cookies with Secure and SameSite=Strict attributes to prevent JavaScript access
- Reduce access token lifetime to 15 minutes
- Implement refresh token rotation mechanism with 7-day expiration stored in HttpOnly cookie
- Add token binding to prevent token theft/replay attacks

**Relevant Section**: Section 3.4 Data Flow, Section 5.4 Authentication and Authorization

---

### 2. Missing Input Validation and Injection Prevention Design
**Severity**: Critical (Score: 1)

**Issue**: The design document lacks any specification for input validation policies, SQL injection prevention, or NoSQL injection prevention despite accepting user-supplied data across multiple endpoints (property search filters, application data, payment amounts, maintenance requests).

**Impact**:
- SQL Injection: Unvalidated input in property search filters (`GET /api/properties`) could allow database manipulation or data exfiltration
- Business logic bypass: Tampering with payment amounts in `POST /api/payments/process` could enable rent payment fraud
- Search injection: Malicious input in Elasticsearch queries could expose unauthorized data or cause DoS
- Data integrity compromise across all entities (Users, Properties, Applications, Leases, Payments)

**Recommended Countermeasures**:
- Adopt parameterized queries/ORM for all database access (JPA/Hibernate properly configured)
- Implement Spring Validation annotations on all DTOs with strict constraints:
  - Email: RFC-compliant validation
  - Phone: E.164 format with country code validation
  - Currency: Positive decimal with max 2 decimal places
  - Dates: Range validation (start_date < end_date)
  - Text fields: Maximum length limits, character whitelist
- For Elasticsearch, use Query DSL builders to prevent injection
- Implement centralized validation middleware that rejects requests before reaching business logic

**Relevant Sections**: Section 5 API Design (all endpoints), Section 4 Data Model

---

### 3. Inadequate Authorization Design - Missing Resource Ownership Verification
**Severity**: Critical (Score: 2)

**Issue**: Section 5.4 mentions "Each endpoint validates user role and resource ownership" but provides no specification of how ownership verification is implemented. Several critical endpoints lack explicit access control design.

**Impact**:
- Horizontal privilege escalation: Tenant A could approve/reject Tenant B's applications if only role is checked
- Property manipulation: Property managers could modify properties they don't manage
- Payment fraud: Users could access/refund payments for leases they don't own
- Privacy breach: Cross-tenant data access to sensitive application information (background checks, financial data)

**Examples of Missing Authorization Specifications**:
- `PUT /api/applications/{id}/approve`: No check that requester owns the property associated with the application
- `GET /api/applications/{id}`: No specification of whether tenants can view other tenants' applications
- `PUT /api/properties/{id}`: No verification that the requester is the owner or designated manager
- `POST /api/payments/refund`: Marked "admin only" but no check that admin is refunding legitimate payment

**Recommended Countermeasures**:
- Implement explicit authorization matrix in design document specifying for each endpoint:
  - Role requirements
  - Ownership verification logic (e.g., lease.tenant_id == authenticated_user.id)
  - Cross-entity checks (e.g., application.property.owner_id == authenticated_user.id)
- Design custom Spring Security authorization annotations (@PreAuthorize with SpEL)
- Implement repository-level access filters to prevent unauthorized data retrieval
- Add authorization audit logging for all access control decisions

**Relevant Section**: Section 5.4 Authentication and Authorization, Section 5 API Design

---

### 4. No Data Encryption at Rest for Sensitive Personal Information
**Severity**: Significant (Score: 2)

**Issue**: While Section 7.2 Security mentions "All data transmitted over HTTPS/TLS 1.3", there is no specification for encryption at rest. The database stores highly sensitive PII including SSN data (implied by background check integration), financial information, and housing application data.

**Impact**:
- Database backup compromise: If S3 backup storage is breached, all tenant PII is exposed in plaintext
- Insider threat: Database administrators have unrestricted access to sensitive data
- Compliance violation: Many jurisdictions require encryption at rest for PII (GDPR, CCPA)
- Extended breach impact: Historical data in backups remains vulnerable indefinitely

**Sensitive Data Requiring Protection**:
- Background check data (likely includes SSN, credit scores, employment history)
- Payment information (bank account details if stored)
- Personal contact information (phone, email, address)
- Lease agreements (income verification, references)

**Recommended Countermeasures**:
- Enable AWS RDS encryption at rest using KMS customer-managed keys
- Implement application-level encryption for high-sensitivity fields (background check data, SSN)
- Use AWS S3 server-side encryption (SSE-KMS) for document storage
- Design key rotation schedule (annually for KMS keys)
- Add column-level encryption for Users.phone and background check results

**Relevant Section**: Section 7.2 Security, Section 4 Data Model

---

### 5. Missing Background Check Data Retention and Deletion Policy
**Severity**: Significant (Score: 2)

**Issue**: The design integrates Checkr API for background verification but provides no specification for how long background check data is retained, how it is securely deleted, or whether tenant consent is obtained.

**Impact**:
- Regulatory non-compliance: FCRA requires specific retention limits and disposal procedures for background check data
- Privacy violation: Indefinite retention of rejected applicants' sensitive data
- Data breach amplification: Unnecessary historical background check data increases breach surface
- Legal liability: Failure to comply with "right to be forgotten" requests

**Recommended Countermeasures**:
- Design explicit data retention policy in compliance with FCRA:
  - Approved applications: Retain background check data for lease duration + 2 years
  - Rejected applications: Delete background check data after 90 days
- Implement automated data deletion job that runs monthly
- Design secure deletion procedure: Overwrite database records before deletion, trigger S3 object permanent deletion
- Add background check consent collection in tenant application workflow
- Create audit log for all background check data access and deletion events

**Relevant Section**: Section 3.6 Application Service, Section 4.3 Applications Table

---

### 6. No Protection Against Automated Application Submission (Bot Attacks)
**Severity**: Significant (Score: 2)

**Issue**: The `POST /api/applications` endpoint has no CAPTCHA, proof-of-work, or bot detection mechanism. Combined with the lack of IP-based rate limiting for application submission specifically.

**Impact**:
- DoS via application spam: Automated bots could submit thousands of fake applications, overwhelming property owners
- Third-party API cost explosion: Each application triggers Checkr API background check request, incurring per-check fees
- Service degradation: Legitimate applications buried in spam, reducing platform usability
- Financial impact: Uncapped background check API costs from bot-generated applications

**Recommended Countermeasures**:
- Implement reCAPTCHA v3 on application submission form (score threshold 0.5)
- Add stricter rate limiting for `/api/applications` endpoint: 3 applications per user per hour
- Design application submission workflow to require email verification before triggering background check
- Implement fraud detection heuristics: Flag multiple applications from same IP, duplicate personal information
- Add manual review queue for flagged applications before initiating paid background check

**Relevant Section**: Section 5.3 Application Endpoints, Section 7.2 Security (rate limiting)

---

### 7. Insufficient Rate Limiting Granularity and Missing Admin Endpoint Protection
**Severity**: Significant (Score: 2)

**Issue**: Section 7.2 specifies "API rate limiting: 100 requests/minute per IP address" but this is insufficient for protecting high-value endpoints. No differentiated rate limiting for admin functions, authentication endpoints, or payment processing.

**Impact**:
- Brute force attacks on authentication: 100 login attempts/minute allows credential stuffing attacks
- Admin account compromise: `/api/payments/refund` (admin only) has same rate limit as public endpoints
- Distributed attacks: Per-IP limiting ineffective against botnet attacks
- Account enumeration: High rate limit on registration/login enables user enumeration

**Recommended Countermeasures**:
- Implement tiered rate limiting strategy:
  - Authentication endpoints (`/api/auth/login`): 5 attempts per 15 minutes per IP + per user
  - Admin endpoints (`/api/*/admin/*`): 20 requests per minute per user
  - Payment endpoints: 10 requests per minute per user
  - Public endpoints: 100 requests per minute per IP
- Add account lockout policy: Lock user account for 30 minutes after 5 failed login attempts
- Implement rate limiting at multiple layers: API Gateway (IP-based) + application layer (user-based)
- Design Redis-based distributed rate limiting with sliding window algorithm

**Relevant Section**: Section 7.2 Security (rate limiting), Section 5.1 Authentication Endpoints

---

### 8. No Defense Against CSRF Attacks on State-Changing Operations
**Severity**: Significant (Score: 2)

**Issue**: The design document does not mention CSRF protection despite numerous state-changing operations (property creation, application approval, payment processing). If JWT is moved to cookies per recommendation #1, CSRF protection becomes critical.

**Impact**:
- Unauthorized property listing: Attacker tricks property owner into creating malicious property listings
- Fraudulent payment processing: Victim tricked into initiating payments via malicious site
- Application manipulation: Attacker forces owner to approve/reject applications without consent
- Lease termination: Unauthorized lease status changes via CSRF

**Recommended Countermeasures**:
- Implement Double Submit Cookie pattern:
  - Generate CSRF token on login, store in HttpOnly cookie
  - Send same token in custom header (X-CSRF-Token) for all state-changing requests
  - Server validates that cookie value matches header value
- Configure SameSite=Strict on all cookies as additional defense layer
- Apply CSRF validation middleware to all POST/PUT/DELETE endpoints
- Exempt only truly stateless read-only GET requests from CSRF checks

**Relevant Section**: Section 5 API Design (all state-changing endpoints)

---

### 9. Missing Audit Logging for Security-Critical Operations
**Severity**: Significant (Score: 2)

**Issue**: Section 6.2 Logging mentions "Request/response logging for API calls" but does not specify security audit logging for critical events. No design for tamper-proof audit trails.

**Impact**:
- Undetectable privilege escalation: No record of authorization changes or admin actions
- Payment fraud investigation hampered: Insufficient audit trail for disputed transactions
- Compliance violation: Many regulations require audit logs for access to PII (GDPR, SOC 2)
- Insider threat blindness: No detection mechanism for malicious admin activity

**Events Requiring Audit Logging**:
- Authentication events (login, logout, failed attempts)
- Authorization failures (attempted access to forbidden resources)
- Admin actions (payment refunds, user role changes, property deletion)
- Sensitive data access (viewing background check results, payment history)
- Configuration changes (rate limit modifications, security settings)
- Data deletion (application rejection, lease termination)

**Recommended Countermeasures**:
- Design dedicated audit log table with immutable records:
  - Columns: timestamp, user_id, action, resource_type, resource_id, ip_address, result, details
  - Append-only with database constraints to prevent modification
- Stream audit logs to separate AWS CloudWatch Logs group with restricted access
- Implement write-ahead logging: Audit entry persisted before action execution
- Set up alerts for suspicious patterns (multiple auth failures, unusual admin activity)
- Design audit log retention: 2 years minimum for compliance

**Relevant Section**: Section 6.2 Logging, Section 7.2 Security

---

### 10. No Idempotency Design for Payment Processing
**Severity**: Significant (Score: 2)

**Issue**: The `POST /api/payments/process` endpoint lacks idempotency guarantees. Network failures or client retries could result in duplicate charges.

**Impact**:
- Duplicate rent charges: Tenant charged twice for same month if request is retried
- Financial reconciliation issues: Payment records misaligned with Stripe transaction history
- Customer service burden: Manual refund processing for duplicate charges
- Trust erosion: Tenants lose confidence in platform after duplicate charges

**Recommended Countermeasures**:
- Design idempotency key mechanism:
  - Client generates UUID and sends in `Idempotency-Key` header
  - Server stores mapping of idempotency key → payment result in Redis (24-hour TTL)
  - Duplicate requests return cached response instead of reprocessing
- Leverage Stripe's idempotency_key parameter in API calls
- Implement database unique constraint on `lease_id + due_date + status=paid` to prevent duplicate paid records
- Add payment reconciliation job to detect and flag anomalies

**Relevant Section**: Section 5.4 Payment Endpoints, Section 3.6 Payment Service

---

### 11. Weak Password Policy and Missing MFA Design
**Severity**: Moderate (Score: 3)

**Issue**: The design specifies bcrypt hashing (Section 7.2) but provides no password complexity requirements, password rotation policy, or multi-factor authentication design.

**Impact**:
- Account compromise via weak passwords: Users choosing "password123" are vulnerable to dictionary attacks
- Credential stuffing success: Weak password policy increases success rate of leaked credential reuse
- Admin account takeover: High-privilege accounts (admin, property managers) lack additional protection layer

**Recommended Countermeasures**:
- Design password policy:
  - Minimum 12 characters
  - Require mix of uppercase, lowercase, numbers, symbols
  - Reject commonly breached passwords using HaveIBeenPwned API
  - No password reuse for last 5 passwords
- Implement TOTP-based MFA (Time-based One-Time Password):
  - Optional for tenants, mandatory for property owners/managers/admins
  - Use Google Authenticator-compatible implementation
  - Backup codes provided at MFA enrollment
- Add "remember this device" option with 30-day expiration

**Relevant Section**: Section 7.2 Security (password hashing), Section 5.1 Authentication Endpoints

---

### 12. Missing Session Management and Token Revocation Design
**Severity**: Moderate (Score: 3)

**Issue**: The design specifies JWT tokens with 24-hour expiration but provides no mechanism for early revocation or session management. No design for "logout all devices" functionality.

**Impact**:
- Stolen tokens remain valid: Even after user reports suspicious activity and changes password, stolen JWT remains usable for up to 24 hours
- No remote session termination: User cannot invalidate sessions on lost/stolen devices
- Insider threat persistence: Terminated employee's JWT continues to work until natural expiration

**Recommended Countermeasures**:
- Implement token revocation mechanism using Redis:
  - Maintain blacklist of revoked tokens (keyed by JWT ID, TTL = remaining token lifetime)
  - Validate each request against blacklist before processing
- Design session management table:
  - Track active sessions per user (device fingerprint, IP, last activity)
  - Enable "view active sessions" and "revoke session" in user profile
- Implement "logout all devices" that blacklists all existing tokens for user
- Add token refresh endpoint that issues new token and blacklists old one

**Relevant Section**: Section 5.1 Authentication Endpoints, Section 3.1 User Service

---

### 13. Insufficient Error Handling - Potential Information Disclosure
**Severity**: Moderate (Score: 3)

**Issue**: Section 6.1 Error Handling mentions "User-facing error messages sanitized to prevent information disclosure" but provides no specific guidelines or examples. Stack traces or verbose error messages could leak sensitive information.

**Impact**:
- Database schema exposure: Verbose SQL errors reveal table structure and column names
- Path disclosure: Stack traces expose internal file paths and framework versions
- User enumeration: Different error messages for "user not found" vs "invalid password" enable account enumeration
- Business logic leakage: Error messages revealing validation rules aid in crafting attacks

**Recommended Countermeasures**:
- Design standardized error response format:
  ```json
  {
    "success": false,
    "error": {
      "code": "AUTH_INVALID_CREDENTIALS",
      "message": "Invalid email or password",
      "request_id": "uuid-for-log-correlation"
    }
  }
  ```
- Implement error code catalog with safe, generic user-facing messages
- Ensure all exceptions caught at top-level filter/interceptor
- Log full exception details server-side with correlation ID for debugging
- Design authentication error responses to be uniform regardless of specific failure reason
- Disable Spring Boot's default error page in production (whitelabel error page disables stack trace)

**Relevant Section**: Section 6.1 Error Handling

---

### 14. Third-Party API Security - Missing Error Handling and Fallback Design
**Severity**: Moderate (Score: 3)

**Issue**: The design integrates multiple third-party APIs (Stripe, Checkr, DocuSign) but does not specify error handling, timeout policies, or security validation of API responses.

**Impact**:
- Service disruption: If Stripe API is unavailable, payment processing completely halts with no fallback
- Security bypass: Malicious responses from compromised third-party could inject fraudulent data
- Webhook vulnerability: No design for verifying webhook authenticity (signature validation)
- Data inconsistency: Failed background check API calls may leave applications in inconsistent state

**Recommended Countermeasures**:
- Design third-party API error handling:
  - Circuit breaker pattern: Open circuit after 5 consecutive failures, retry after 60 seconds
  - Timeout policies: 10s for Stripe, 30s for Checkr (background check), 15s for DocuSign
  - Exponential backoff with jitter for retries
- Implement webhook signature validation:
  - Verify Stripe webhook signatures using stripe-signature header
  - Store webhook secrets in AWS Parameter Store (encrypted)
- Design fallback mechanisms:
  - Payment processing: Queue failed payments for manual review
  - Background checks: Mark as "pending_verification" and alert property owner
- Add API response schema validation to detect tampering

**Relevant Section**: Section 2.4 Key Libraries, Section 3.6 Core Components

---

### 15. Missing File Upload Security Design
**Severity**: Moderate (Score: 3)

**Issue**: The design mentions AWS S3 for file storage (Section 2.4) but does not specify file upload validation, virus scanning, or access control design. Property images and lease documents are likely upload targets.

**Impact**:
- Malware distribution: Attackers upload malicious files disguised as property images or lease documents
- XSS via SVG: Uploaded SVG files can contain JavaScript payloads
- Storage exhaustion: Unvalidated file size limits lead to DoS via large file uploads
- Unauthorized file access: Misconfigured S3 bucket ACLs expose private lease documents

**Recommended Countermeasures**:
- Design file upload validation policy:
  - File type whitelist: Images (JPEG, PNG), documents (PDF)
  - File size limits: 5MB for images, 10MB for documents
  - Magic byte validation: Verify actual file type matches extension
  - Filename sanitization: Remove special characters, limit length to 255 chars
- Implement virus scanning using AWS GuardDuty or ClamAV before S3 storage
- Design S3 security configuration:
  - Block public access on bucket level
  - Use presigned URLs with 1-hour expiration for file downloads
  - Enable S3 versioning and object lock for lease documents
- Store uploaded files in separate S3 bucket from application code/assets
- Add metadata tagging to files (uploader_id, upload_date, content_type) for audit trail

**Relevant Section**: Section 2.4 Key Libraries (AWS SDK), Section 3.6 Core Components

---

## Improvement Suggestions (effective for improving design quality)

### 16. Add IP Geolocation and Anomaly Detection for Login
**Severity**: Minor (Score: 4)

**Issue**: The authentication design lacks geolocation tracking or anomaly detection for suspicious login patterns.

**Impact**: Delayed detection of account compromise. User not alerted to logins from unusual locations (different country, impossible travel time).

**Recommended Countermeasures**:
- Log user's IP geolocation (country, city) at each login using MaxMind GeoIP2
- Send email notification for logins from new locations or devices
- Implement impossible travel detection: Alert if login occurs from Location B within 1 hour of login from Location A where travel time exceeds 1 hour
- Add "was this you?" link in notification for immediate account lockdown

**Relevant Section**: Section 5.1 Authentication Endpoints, Section 3.1 User Service

---

### 17. Implement Content Security Policy (CSP) Headers
**Severity**: Minor (Score: 4)

**Issue**: No mention of Content Security Policy headers to mitigate XSS attack surface in the React SPA.

**Recommended Countermeasures**:
- Configure CSP headers in CloudFront/API Gateway:
  - `Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' https://cdn.example.com; connect-src 'self' https://api.stripe.com`
- Enable CSP violation reporting to monitor for attempted XSS attacks
- Use nonce-based script loading for inline scripts if required
- Enable Subresource Integrity (SRI) for any external JavaScript libraries

**Relevant Section**: Section 7.2 Security, Section 2.3 Infrastructure

---

### 18. Add Security Headers for Defense in Depth
**Severity**: Minor (Score: 4)

**Issue**: The design does not specify security-related HTTP headers beyond HTTPS enforcement.

**Recommended Countermeasures**:
- Implement comprehensive security headers:
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY` (prevent clickjacking)
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy: geolocation=(), camera=(), microphone=()`
- Configure headers at CloudFront level for all responses

**Relevant Section**: Section 7.2 Security

---

### 19. Design Database Connection String Encryption
**Severity**: Minor (Score: 4)

**Issue**: Section 7.2 mentions "Environment-specific configuration via AWS Parameter Store" but does not specify encryption of database credentials.

**Recommended Countermeasures**:
- Store database connection strings in AWS Parameter Store as SecureString type (encrypted with KMS)
- Use IAM roles for RDS authentication instead of username/password where possible
- Implement automatic credential rotation using AWS Secrets Manager
- Ensure database credentials are never logged or exposed in error messages

**Relevant Section**: Section 6.3 Deployment, Section 7.2 Security

---

### 20. Add Database Query Timeout and Connection Limits
**Severity**: Minor (Score: 4)

**Issue**: Section 7.1 specifies connection pooling (min 10, max 50) but does not mention query timeout limits. Long-running queries could cause resource exhaustion.

**Recommended Countermeasures**:
- Set query timeout at 30 seconds for all database operations
- Implement slow query logging: Alert on queries exceeding 5 seconds
- Design read-heavy queries to use read replicas with eventual consistency acceptable
- Add query result pagination for all list endpoints to prevent large result sets

**Relevant Section**: Section 7.1 Performance

---

## Confirmation Items (requiring user clarification)

### 21. Stripe Payment Flow and PCI-DSS Scope
**Issue**: Section 7.2 mentions "Payment card data handled via Stripe (PCI-DSS compliant), never stored on our servers" but the payment endpoint design is unclear.

**Questions**:
- Does the frontend collect card details and tokenize via Stripe.js before sending to backend?
- Or does backend handle raw card data temporarily before forwarding to Stripe?
- What is the exact data flow for `POST /api/payments/process`?

**Recommendation**: If backend handles any card data (even temporarily), PCI-DSS SAQ D compliance is required. Design should explicitly document Stripe Elements integration on frontend with token-based payment processing.

**Relevant Section**: Section 5.4 Payment Endpoints, Section 7.2 Security

---

### 22. Background Check Consent and Disclosure Requirements
**Issue**: Checkr API integration mentioned but no design for tenant consent collection or FCRA-required disclosures.

**Questions**:
- Does the application form include standalone consent for background check?
- Is the FCRA disclosure form presented and acknowledged before check initiation?
- How are adverse action notices sent if application rejected based on background check?

**Recommendation**: FCRA compliance requires specific consent language, disclosure timing, and adverse action procedures. Design should include consent collection workflow, disclosure document delivery, and pre-adverse/adverse action notice automation.

**Relevant Section**: Section 3.6 Application Service

---

### 23. Data Residency and International Users
**Issue**: No mention of data residency requirements or geographic restrictions.

**Questions**:
- Is the platform limited to US users or does it support international properties?
- If international, how is GDPR/regional data protection compliance ensured?
- Where are AWS resources deployed (region)?

**Recommendation**: If international users supported, design should specify data residency policies, GDPR-compliant data processing agreements, and region-specific compliance measures.

**Relevant Section**: Section 2.3 Infrastructure

---

## Positive Evaluation (good points)

### 24. Strong Password Hashing with bcrypt
The design appropriately selects bcrypt with cost factor 12 for password hashing, which is aligned with current OWASP recommendations. The cost factor provides adequate computational resistance against brute-force attacks.

**Relevant Section**: Section 7.2 Security

---

### 25. Separation of Payment Processing via Stripe
The design correctly delegates PCI-DSS compliance to Stripe and avoids storing payment card data on platform servers. This significantly reduces compliance burden and attack surface.

**Relevant Section**: Section 7.2 Security, Section 2.4 Key Libraries

---

### 26. HTTPS/TLS 1.3 for Data in Transit
All data transmission is protected via HTTPS with TLS 1.3, which provides modern cryptographic security and prevents eavesdropping or man-in-the-middle attacks.

**Relevant Section**: Section 7.2 Security

---

### 27. Database Backup Strategy
The design includes comprehensive backup strategy (full daily, incremental every 6 hours) which provides good recovery point objective (RPO) for data loss scenarios.

**Relevant Section**: Section 7.3 Availability and Scalability

---

### 28. Security Testing Integration
The inclusion of OWASP ZAP for vulnerability scanning in the testing strategy demonstrates proactive security validation. This provides automated detection of common vulnerabilities before production deployment.

**Relevant Section**: Section 6.3 Testing

---

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple critical attack vectors unaddressed: XSS-based token theft, CSRF attacks, injection vulnerabilities, session hijacking, DoS via bot applications, privilege escalation via inadequate authorization |
| Authentication & Authorization Design | 2 | JWT in localStorage is critically vulnerable to XSS; 24-hour token lifetime too long; missing MFA, session management, and resource ownership verification; weak password policy |
| Data Protection | 2 | No encryption at rest for sensitive PII including background check data; missing data retention/deletion policy; insufficient file upload security; no data residency specification |
| Input Validation Design | 1 | No input validation policy specified; missing SQL/NoSQL injection prevention design; no sanitization guidelines; unvalidated file uploads; missing output encoding strategy |
| Infrastructure & Dependencies | 3 | Third-party API integration lacks error handling, webhook verification, and fallback design; missing security headers; database credentials encryption not specified; but good use of Stripe for PCI compliance |
| **Overall** | **2.0** | **Multiple critical security gaps require immediate design revision, particularly input validation, authentication token storage, and authorization enforcement** |
