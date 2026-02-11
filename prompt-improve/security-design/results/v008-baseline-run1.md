# Security Design Review: Real Estate Rental Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Missing comprehensive threat modeling coverage with critical gaps in repudiation, DoS protection, and tampering controls |
| Authentication & Authorization Design | 2 | JWT in localStorage creates XSS token theft risk, 24-hour expiration too long, missing session management and MFA |
| Data Protection | 2 | Missing encryption at rest specification, no data retention/deletion policies, inadequate PII protection design |
| Input Validation Design | 1 | No input validation policy defined, missing injection prevention measures, file upload security unspecified |
| Infrastructure & Dependencies | 3 | Third-party APIs used but missing secret rotation, dependency scanning, and network security design |
| **Overall** | **2.0** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Storage in localStorage Creates XSS Vulnerability

**Problem**: The design specifies "JWT token stored in localStorage" (line 66), which exposes tokens to theft via any XSS vulnerability in the frontend application.

**Impact**: If a single XSS vulnerability exists anywhere in the React application (e.g., through user-generated content, third-party scripts, or dependency vulnerabilities), attackers can execute JavaScript to read localStorage and exfiltrate valid JWT tokens. Combined with the 24-hour token expiration, this provides a 24-hour window for complete account takeover, including access to sensitive tenant PII, financial data, and property owner revenue information.

**Recommended Countermeasures**:
- Switch to HttpOnly cookies with Secure and SameSite=Strict attributes for token storage
- Implement short-lived access tokens (15 minutes) with refresh token rotation mechanism
- Add refresh tokens stored in HttpOnly cookies with 7-day expiration and rotation on use
- Implement CSRF protection via Double Submit Cookie pattern for cookie-based authentication

**Relevant Section**: Section 3 (Architecture Design - Data Flow, line 66)

---

### 1.2 No Input Validation Policy or Injection Prevention Design

**Problem**: The design document contains no specification for input validation policies, SQL injection prevention, or command injection protection. While PostgreSQL is used, there is no mention of parameterized queries, ORM usage patterns, or validation frameworks.

**Impact**: Without explicit input validation design:
- SQL injection vulnerabilities in property search filters, user registration, and payment processing
- NoSQL injection risks in Elasticsearch queries (property search)
- Command injection risks if user input reaches system calls
- XSS vulnerabilities in property descriptions, user profiles, and maintenance requests
- Path traversal risks in file upload/download operations

**Recommended Countermeasures**:
- Define comprehensive input validation policy covering all external inputs
- Specify use of Spring JPA with parameterized queries for all database operations
- Implement request validation using javax.validation annotations (@NotNull, @Email, @Pattern, etc.)
- Design output escaping policy: HTML escaping for property descriptions, JSON escaping for API responses
- Implement Content Security Policy (CSP) headers to mitigate XSS impact
- Add input sanitization library (e.g., OWASP Java HTML Sanitizer) for user-generated HTML content

**Relevant Section**: Missing from entire design document

---

### 1.3 Missing Idempotency Guarantees for Payment Processing

**Problem**: The Payment Service processes rent payments via Stripe API (line 155: `POST /api/payments/process`) but the design does not specify idempotency mechanisms to prevent duplicate charges on retry or network failures.

**Impact**:
- Network timeouts or client-side errors may cause tenants to retry payment requests
- Without idempotency keys, duplicate payment processing could charge tenants multiple times
- Financial reconciliation errors and compliance violations
- Loss of user trust and potential legal liability

**Recommended Countermeasures**:
- Design idempotency key mechanism: require clients to send unique `idempotency_key` header for all state-changing operations
- Store processed idempotency keys in Redis with 24-hour TTL
- Before processing payment, check if idempotency key exists; if yes, return cached response
- Pass idempotency keys to Stripe API using their native idempotency support
- Apply same pattern to lease creation, application submission, and maintenance request endpoints

**Relevant Section**: Section 5 (API Design - Payment Endpoints, line 155)

---

### 1.4 Background Check Data Handling Has No Privacy Controls

**Problem**: The system integrates with Checkr API for background checks (line 44, 108) but the design does not specify how sensitive background check data (credit scores, criminal records, SSNs) is stored, accessed, or deleted.

**Impact**:
- Violation of Fair Credit Reporting Act (FCRA) requirements for background check data handling
- GDPR/CCPA violations if data retention and deletion rights are not implemented
- Unauthorized access to highly sensitive tenant PII
- Legal liability and regulatory fines

**Recommended Countermeasures**:
- Design explicit data retention policy: background check data deleted 7 days after application decision
- Implement field-level encryption for background check results using AWS KMS
- Restrict access to background check data to property owners/managers for specific applications only
- Add audit logging for all access to background check data with immutable log storage
- Implement tenant right-to-deletion workflow for GDPR/CCPA compliance
- Document FCRA compliance requirements in design (adverse action notices, dispute process)

**Relevant Section**: Section 3 (Core Components - Application Service, line 59)

---

### 1.5 No Rate Limiting Design for Critical Endpoints

**Problem**: While API rate limiting is mentioned at a generic level (100 requests/minute per IP, line 214), there is no specific rate limiting design for high-risk endpoints such as login, password reset, application submission, and payment processing.

**Impact**:
- Brute-force attacks on `/api/auth/login` to compromise user accounts
- Credential stuffing attacks using leaked password databases
- Application spam flooding property owners with fake applications
- Payment endpoint abuse for card testing or fraud attempts
- Resource exhaustion and service degradation

**Recommended Countermeasures**:
- Design tiered rate limiting strategy:
  - `/api/auth/login`: 5 attempts per 15 minutes per IP, 10 attempts per hour per email
  - `/api/auth/register`: 3 registrations per hour per IP
  - `/api/applications`: 10 submissions per day per tenant account
  - `/api/payments/process`: 5 attempts per hour per lease
- Implement account lockout: 30-minute lock after 5 failed login attempts
- Add CAPTCHA requirement after 3 failed login attempts
- Configure Redis-based distributed rate limiting using Spring annotations
- Design IP reputation scoring to detect and block malicious traffic patterns

**Relevant Section**: Section 7 (Non-Functional Requirements - Security, line 214)

---

### 1.6 Missing CSRF Protection Design

**Problem**: The design does not mention CSRF (Cross-Site Request Forgery) protection for state-changing API endpoints, despite using cookie-based session storage in Redis (line 32).

**Impact**: If JWT tokens are moved to cookies (as recommended in 1.1), without CSRF protection:
- Attackers can craft malicious websites that trigger authenticated requests (property deletion, payment processing, lease termination)
- Users who visit attacker sites while logged in will unknowingly execute harmful actions
- Financial fraud and data manipulation risks

**Recommended Countermeasures**:
- Implement Double Submit Cookie pattern: generate CSRF token on login, store in cookie and require in request header
- Configure Spring Security CSRF protection for all POST/PUT/DELETE endpoints
- Set SameSite=Strict cookie attribute as additional defense layer
- Exempt public endpoints (register, login) from CSRF checks
- Validate CSRF tokens in API Gateway before routing to microservices

**Relevant Section**: Missing from Section 5 (API Design)

---

### 1.7 No Encryption at Rest for Sensitive Data

**Problem**: The design specifies PostgreSQL for user data, properties, and leases (line 31) but does not mention encryption at rest for sensitive data such as SSNs, payment information references, and background check results.

**Impact**:
- Database backups stored unencrypted expose sensitive data if stolen
- Insider threats or compromised database credentials allow access to plaintext sensitive data
- Compliance violations (PCI-DSS, GDPR, CCPA)

**Recommended Countermeasures**:
- Enable AWS RDS encryption at rest using KMS customer-managed keys
- Implement application-layer field-level encryption for highly sensitive fields:
  - User SSN/tax ID
  - Background check results
  - Bank account information (if stored)
- Design key rotation policy: rotate KMS keys annually
- Store encryption keys in AWS KMS with IAM role-based access control
- Document which fields require encryption and key management procedures

**Relevant Section**: Section 2 (Technology Stack - Database, line 31) and Section 4 (Data Model)

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Missing Audit Logging for Financial and Access Control Events

**Problem**: While application logs are sent to CloudWatch (line 184), there is no specific design for audit logging of security-critical events such as payment processing, lease creation, application approvals, and permission changes.

**Rationale**: Audit logs are essential for:
- Forensic investigation of security incidents
- Compliance requirements (SOC 2, PCI-DSS)
- Dispute resolution between tenants and property owners
- Detecting insider threats and unauthorized access

**Recommended Countermeasures**:
- Design comprehensive audit logging policy covering:
  - Authentication events (login, logout, failed attempts, password changes)
  - Authorization decisions (access denials, role changes)
  - Financial transactions (payments, refunds, invoice generation)
  - Data access (who viewed which background check, when)
  - Administrative actions (user deletion, property deletion, lease termination)
- Store audit logs in immutable storage (S3 with object lock or dedicated audit log service)
- Implement log retention: 7 years for financial records, 1 year for access logs
- Add log integrity protection: sign logs with HMAC or use AWS CloudTrail
- Design audit log review workflow for compliance and security monitoring

**Relevant Section**: Section 6 (Implementation Guidelines - Logging, line 183)

---

### 2.2 No Multi-Factor Authentication (MFA) for High-Privilege Accounts

**Problem**: The authentication design only mentions JWT tokens (line 170) with no mention of MFA for property owners, property managers, or admin accounts who have access to sensitive financial and personal data.

**Rationale**: Property owners and managers handle:
- Tenant background check data (SSNs, credit scores, criminal records)
- Payment processing and refunds
- Lease termination and eviction processes
- Access to revenue analytics across multiple properties

A compromised owner/manager account has significantly higher impact than a tenant account.

**Recommended Countermeasures**:
- Design mandatory MFA for admin and property manager roles
- Implement TOTP-based MFA using libraries like Google Authenticator or Authy
- Add SMS-based MFA as fallback option with rate limiting (prevent SMS pumping attacks)
- Store MFA secrets encrypted in database with user association
- Design MFA recovery flow with backup codes (10 single-use codes, securely generated)
- Require MFA re-verification for sensitive actions (refunds, bulk data exports)

**Relevant Section**: Section 5 (API Design - Authentication and Authorization, line 169)

---

### 2.3 File Upload Security Not Designed

**Problem**: The design mentions AWS S3 for file storage (line 36, 46) and likely supports file uploads (property photos, lease documents, tenant ID verification), but there is no security design for file upload validation, storage, or access control.

**Rationale**: File upload vulnerabilities can lead to:
- Malicious file execution if uploaded files are served with incorrect MIME types
- Storage exhaustion through large file uploads
- Malware distribution via uploaded files
- Privacy violations if files are publicly accessible

**Recommended Countermeasures**:
- Design file upload validation policy:
  - Whitelist allowed file types: images (JPEG, PNG, WEBP), documents (PDF only)
  - Maximum file size: 10MB for images, 25MB for documents
  - Validate file content (magic bytes) in addition to extension
  - Scan uploaded files with antivirus (e.g., ClamAV or AWS S3 malware scanning)
- Implement secure storage design:
  - Generate random S3 object keys (UUIDs), never use user-provided filenames
  - Store files in private S3 buckets with no public access
  - Use signed URLs (CloudFront signed URLs) with 1-hour expiration for file access
  - Enable S3 versioning and object lock for lease documents (immutability)
- Design access control: only property owner and associated tenant can access lease documents

**Relevant Section**: Section 2 (Technology Stack - Key Libraries, line 46)

---

### 2.4 Dependency Security and Supply Chain Risk Not Addressed

**Problem**: The design lists multiple third-party libraries and APIs (Spring Security, Stripe, Checkr, DocuSign, lines 42-46) but does not specify dependency vulnerability scanning, version pinning, or supply chain security measures.

**Rationale**: Supply chain attacks and vulnerable dependencies are a leading cause of security incidents:
- Log4Shell (CVE-2021-44228) affected Spring Boot applications
- Vulnerable npm packages in React frontend
- Compromised third-party APIs or SDKs

**Recommended Countermeasures**:
- Integrate OWASP Dependency-Check or Snyk into CI/CD pipeline (GitHub Actions)
- Design dependency update policy: patch critical vulnerabilities within 48 hours, high within 7 days
- Pin all dependency versions in pom.xml and package.json (no version ranges)
- Implement Software Bill of Materials (SBOM) generation for each release
- Design API key rotation policy for third-party services (Stripe, Checkr, DocuSign):
  - Store API keys in AWS Secrets Manager, never in environment variables
  - Rotate API keys every 90 days
  - Implement key rotation without downtime (support both old and new keys during transition)
- Add integrity checking for third-party scripts loaded in frontend (Subresource Integrity)

**Relevant Section**: Section 2 (Technology Stack - Key Libraries, line 42-46)

---

### 2.5 Missing Session Management and Concurrent Session Controls

**Problem**: The design mentions JWT tokens with 24-hour expiration (line 170) but does not specify session management, token revocation, or concurrent session limits.

**Rationale**: Without session management:
- Stolen tokens remain valid until expiration, even after user logout or password change
- No ability to force logout compromised accounts
- Users cannot see or manage active sessions
- No protection against account sharing or credential theft

**Recommended Countermeasures**:
- Design session management using Redis:
  - Store active session metadata in Redis with user_id as key
  - Include: session_id, device info, IP address, login timestamp, last activity timestamp
  - Set Redis TTL equal to token expiration
- Implement token revocation:
  - On logout, add token to Redis blacklist with TTL equal to remaining token lifetime
  - On password change, invalidate all sessions for that user
  - Validate token against blacklist before processing requests
- Add concurrent session limits:
  - Limit to 3 active sessions per user
  - Provide "active sessions" UI showing device, location, last activity
  - Allow users to revoke individual sessions
- Design session timeout: refresh token activity timestamp on each request, invalidate after 30 minutes of inactivity

**Relevant Section**: Section 5 (API Design - Authentication and Authorization, line 169)

---

### 2.6 Error Messages May Leak Sensitive Information

**Problem**: The design states "user-facing error messages sanitized to prevent information disclosure" (line 179) but does not specify what constitutes information disclosure or provide concrete examples.

**Rationale**: Common error message leaks include:
- Login errors revealing whether email exists ("Invalid password" vs "User not found")
- Database error messages exposing table/column names
- Stack traces in production responses
- Detailed validation errors revealing internal business logic

**Recommended Countermeasures**:
- Design error message policy with specific rules:
  - Login failures: always return generic "Invalid email or password" regardless of actual failure reason
  - Database errors: return "An error occurred" to users, log full details server-side
  - Validation errors: return field names and constraint violations but not internal logic
  - Authorization failures: distinguish between "resource not found" (404) and "access denied" (403) only if user should know resource exists
- Implement error response sanitization middleware:
  - Strip stack traces in production environment
  - Remove SQL error details
  - Sanitize file paths from error messages
- Design separate error responses for internal (detailed) and external (sanitized) consumers
- Add unit tests verifying error messages do not leak sensitive information

**Relevant Section**: Section 6 (Implementation Guidelines - Error Handling, line 178)

---

### 2.7 No Data Retention and Deletion Policy

**Problem**: The design mentions database backups (line 221) but does not specify data retention periods, deletion policies, or user data export/deletion rights required by GDPR/CCPA.

**Rationale**: Legal and privacy requirements mandate:
- GDPR right to erasure ("right to be forgotten")
- CCPA right to deletion
- FCRA requirements for background check data retention limits
- Business need to purge old data to reduce storage costs and compliance scope

**Recommended Countermeasures**:
- Design comprehensive data retention policy:
  - Active leases: retain indefinitely while active
  - Terminated leases: retain for 7 years (tax/legal requirements)
  - Rejected applications: delete after 30 days
  - Background check data: delete after 7 days or application decision
  - Payment records: retain for 7 years (PCI-DSS, tax compliance)
  - User accounts: delete 90 days after account closure request
- Implement soft delete with purge workflow:
  - Mark records as deleted (status='deleted', deleted_at timestamp)
  - Scheduled job purges soft-deleted records after retention period
  - Cascade delete related records (user → applications → background checks)
- Design user data export API for GDPR compliance:
  - `GET /api/users/me/export` returns all user data in JSON format
  - Include: profile, applications, leases, payments, messages
- Add admin tools for compliance: search and delete user by email, audit trail of deletions

**Relevant Section**: Missing from entire design document

---

### 2.8 Payment Refund Authorization Insufficient

**Problem**: The design specifies refund endpoint as "admin only" (line 157) but does not detail the authorization model, refund approval workflow, or fraud prevention measures.

**Rationale**: Payment refunds are high-risk operations requiring:
- Strong authorization controls to prevent insider fraud
- Audit trail for financial reconciliation
- Fraud detection to identify suspicious refund patterns
- Compliance with payment processor policies

**Recommended Countermeasures**:
- Design multi-level refund authorization:
  - Refunds < $100: single admin approval
  - Refunds $100-$1000: two-person approval (admin + manager)
  - Refunds > $1000: admin + finance approval + automated fraud check
- Implement refund fraud detection:
  - Flag refunds within 24 hours of payment as suspicious
  - Alert on multiple refunds to same user within 30 days
  - Check if refund recipient matches original payer
- Design refund audit trail:
  - Log: who requested, who approved, timestamp, reason, original payment reference
  - Store refund justification text (required field)
  - Immutable storage for refund audit logs
- Add refund rate limiting: max 10 refunds per admin per day, alert on anomalies

**Relevant Section**: Section 5 (API Design - Payment Endpoints, line 157)

---

### 2.9 Missing Threat Modeling for Privilege Escalation

**Problem**: The design mentions role-based access control (tenant, owner, manager, admin, line 83) but does not address privilege escalation attack vectors or principle of least privilege enforcement.

**Rationale**: Privilege escalation risks include:
- Tenants modifying property listings or approving their own applications
- Property managers accessing properties they don't manage
- Users manipulating role field during registration or profile update
- Horizontal privilege escalation (tenant A accessing tenant B's data)

**Recommended Countermeasures**:
- Design role assignment policy:
  - New users default to 'tenant' role (never allow role selection during registration)
  - Role elevation requires admin approval via secure workflow
  - Implement role change audit logging with email notification to user
- Add resource ownership validation:
  - Property endpoints: verify owner_id matches authenticated user or user is manager for that property
  - Application endpoints: verify tenant_id matches authenticated user (for tenant operations)
  - Lease endpoints: verify user is owner, manager, or tenant associated with lease
- Design authorization service:
  - Centralized permission checking: `hasPermission(user, action, resource)`
  - Define permission matrix: role × action × resource_type
  - Implement attribute-based access control (ABAC) for complex rules
- Add unit tests for authorization: test that users cannot access resources they don't own

**Relevant Section**: Section 5 (API Design - Authentication and Authorization, line 172)

---

### 2.10 Elasticsearch Query Injection Risk

**Problem**: The design uses Elasticsearch for property search (line 33, 142) with "advanced filters" but does not specify how user input is sanitized before building Elasticsearch queries.

**Rationale**: Elasticsearch query injection can allow attackers to:
- Execute arbitrary queries to access unauthorized data
- Cause denial of service through expensive queries
- Bypass access controls by manipulating query structure

**Recommended Countermeasures**:
- Design safe query construction:
  - Use Elasticsearch high-level REST client query builders, never string concatenation
  - Whitelist allowed filter fields (location, price, bedrooms, bathrooms)
  - Validate field names against whitelist before query construction
  - Sanitize special characters in user input (quotes, brackets, operators)
- Implement query complexity limits:
  - Maximum 10 filter conditions per query
  - Limit result set size to 100 properties
  - Set query timeout to 5 seconds
- Design access control:
  - Filter results by property status='available' for tenants
  - Include owner_id filter for property owners viewing their own listings
  - Add tenant_id filter for managers viewing assigned properties
- Add monitoring for suspicious query patterns (detect injection attempts)

**Relevant Section**: Section 3 (Core Components - Property Service, line 58)

---

## 3. Confirmation Items (requiring user confirmation)

### 3.1 Password Complexity and Account Recovery Design

**Issue**: The design specifies bcrypt hashing with cost factor 12 (line 211) but does not define password complexity requirements, password reset workflow, or account recovery mechanisms.

**Confirmation Needed**:
- What are the password complexity requirements? (minimum length, character classes, dictionary check)
- How should password reset be designed? (email-based token, security questions, phone verification)
- Should the system enforce password expiration or rotation?
- How to handle account lockout recovery? (self-service unlock, admin intervention, time-based auto-unlock)

**Options and Trade-offs**:

**Option A: Standard complexity with email-based reset**
- Minimum 12 characters, require uppercase, lowercase, number, special character
- Password reset via time-limited token (1 hour) sent to registered email
- No password expiration for regular users, 90-day rotation for admin/manager
- Auto-unlock after 30 minutes or admin intervention
- *Trade-off*: Email-based reset vulnerable if email account compromised

**Option B: Passphrase approach with multi-factor recovery**
- Minimum 16 characters, no complexity requirements (encourage passphrases)
- Password reset requires email link + SMS verification code
- No password expiration
- Account recovery via security questions + identity verification
- *Trade-off*: More complex recovery flow, SMS vulnerabilities (SIM swapping)

**Option C: Passwordless authentication**
- Use magic links or WebAuthn for authentication
- No passwords to manage or reset
- Account recovery via email or hardware security key
- *Trade-off*: Requires significant architectural changes, user education

**Recommendation**: Option A provides best balance of security and usability for a rental platform. Add optional MFA upgrade path to Option B's multi-factor recovery for high-privilege accounts.

---

### 3.2 DocuSign Integration Security Model

**Issue**: The design mentions DocuSign API for e-signature (line 45) but does not specify how lease documents are generated, who signs first, or how signature verification is handled.

**Confirmation Needed**:
- Should lease documents be generated server-side (to prevent tampering) or uploaded by property owners?
- What is the signing workflow? (owner signs first, then tenant? or tenant initiates?)
- How to verify document integrity between generation and signing?
- Should the system store signed document copies or rely on DocuSign's storage?
- How to handle signature disputes or document modifications?

**Options and Trade-offs**:

**Option A: Server-side generation with sequential signing**
- Generate lease PDF server-side using template + data from Lease table
- Property owner reviews and signs first, then tenant receives signing request
- Store hash of document before sending to DocuSign, verify on return
- Store signed document copy in S3 (immutable, 7-year retention) with DocuSign audit trail
- *Trade-off*: More complex implementation, ensures document integrity

**Option B: Owner-uploaded documents with parallel signing**
- Property owner uploads lease template, system fills in property/tenant data
- Both parties receive signing request simultaneously
- Rely on DocuSign's tamper detection
- Store only DocuSign envelope ID, retrieve documents via API when needed
- *Trade-off*: Simpler, but risk of template tampering, dependency on DocuSign availability

**Option C: Hybrid approach**
- Certified lease templates uploaded and approved by admin
- System generates final document from approved template
- Owner and tenant sign in parallel
- Store both original and signed documents in S3
- *Trade-off*: Balances flexibility and integrity, requires template approval workflow

**Recommendation**: Option C provides best security while allowing customization. Requires admin workflow for template certification and storage of multiple document versions.

---

### 3.3 Background Check Result Storage Duration

**Issue**: Background check data retention is mentioned as a critical gap (see Critical Issue 1.4), but the appropriate retention period depends on legal requirements and business needs.

**Confirmation Needed**:
- How long should background check data be stored after application decision?
- Should rejected applicants' background check data be retained (for legal defense against discrimination claims)?
- What access controls should apply to historical background check data?
- Should background check data be anonymized after a certain period?

**Options and Trade-offs**:

**Option A: Minimal retention (7 days after decision)**
- Delete all background check data 7 days after application approved or rejected
- Retain only application decision (approved/rejected) and timestamp
- Lowest compliance risk and storage cost
- *Trade-off*: Cannot defend against late discrimination claims, no historical reference for repeat applicants

**Option B: Approved application retention (lease duration + 1 year)**
- Delete rejected applicant background checks after 30 days
- Retain approved applicant background checks until 1 year after lease termination
- Useful for lease renewal decisions and legal disputes
- *Trade-off*: Higher FCRA compliance burden, more sensitive data to protect

**Option C: Anonymized long-term retention**
- Delete identifiable background check data after 30 days
- Retain anonymized aggregate data (e.g., "credit score range 700-750") for analytics
- Helps property owners make informed decisions without PII storage
- *Trade-off*: Requires anonymization implementation, limited usefulness of anonymized data

**Recommendation**: Option B for approved applications, Option A for rejected applications. This balances legal defensibility with privacy obligations. Implement automated deletion workflow and audit logging.

---

## 4. Positive Evaluation (good points)

### 4.1 Payment Card Data Handling via Stripe

The design correctly delegates all payment card data handling to Stripe (line 213: "Payment card data handled via Stripe (PCI-DSS compliant), never stored on our servers"). This eliminates PCI-DSS compliance scope for the application and significantly reduces the attack surface for financial fraud. Storing only Stripe payment intent IDs (line 132) is the appropriate pattern.

---

### 4.2 HTTPS/TLS 1.3 for Data in Transit

The design mandates HTTPS/TLS 1.3 for all data transmission (line 210), which is commendable. TLS 1.3 provides improved security over earlier versions by removing weak cipher suites and reducing handshake round trips. This protects against man-in-the-middle attacks and eavesdropping on sensitive data like authentication tokens and personal information.

---

### 4.3 Bcrypt Password Hashing with Appropriate Cost Factor

The design specifies bcrypt with cost factor 12 for password hashing (line 211), which aligns with current OWASP recommendations. Bcrypt's adaptive nature provides protection against brute-force attacks on password databases, and cost factor 12 provides strong security while maintaining acceptable performance (approximately 250-300ms per hash on modern hardware).

---

### 4.4 Database Backup Strategy

The design includes a comprehensive backup strategy with daily full backups and 6-hour incremental backups (line 221). This provides strong disaster recovery capability and limits data loss to a maximum of 6 hours. The backup frequency is appropriate for a financial transaction system where data integrity is critical.

---

### 4.5 Security Testing Integration

The design includes OWASP ZAP vulnerability scanning in the testing strategy (line 193), demonstrating awareness of security testing needs. Integrating automated security scanning into the development lifecycle helps catch common vulnerabilities before production deployment.

---

### 4.6 Separation of Log Levels by Environment

The logging design (line 185) appropriately separates log levels by environment (DEBUG for dev, INFO for staging, WARN/ERROR for production), which reduces noise in production logs and improves incident response efficiency. This also reduces the risk of sensitive data leakage through overly verbose logging in production.

---

### 4.7 Blue/Green Deployment for Availability

The deployment strategy uses blue/green deployments (line 196), which provides zero-downtime releases and quick rollback capability. This is particularly important for a rental platform where users may be accessing the system to make time-sensitive payments or submit applications.
