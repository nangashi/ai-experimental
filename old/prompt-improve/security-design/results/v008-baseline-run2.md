# Security Design Review: Real Estate Rental Platform

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Multiple critical STRIDE threats not addressed: no session invalidation design, no idempotency guarantees for payments, no repudiation protection for lease agreements |
| Authentication & Authorization Design | 2 | JWT in localStorage creates XSS vulnerability; 24-hour expiration too long; no token refresh mechanism; no session management |
| Data Protection | 2 | No encryption-at-rest specification for sensitive data (SSN, payment info); no data retention/deletion policy; missing GDPR compliance design |
| Input Validation Design | 3 | No input validation policy defined; missing sanitization strategies for user-generated content; no file upload security controls |
| Infrastructure & Dependencies | 3 | No secret management strategy; dependency security not addressed; missing network security controls; no WAF/DDoS protection |
| **Overall** | **2.4** | |

---

## 1. Critical Issues (design modification required)

### 1.1 JWT Token Storage Vulnerability Enables XSS Account Takeover

**Problem**: Section 3 states "User authenticates via JWT token stored in localStorage" with 24-hour expiration. localStorage is accessible to all JavaScript code, making tokens vulnerable to XSS attacks. The 24-hour expiration window extends the damage period significantly.

**Impact**: If even a single XSS vulnerability exists anywhere in the application (React components, third-party libraries, CDN-served assets), attackers can steal tokens valid for 24 hours and gain complete account takeover, including access to:
- Tenant background check data (SSN, credit reports)
- Property owner financial information
- Payment processing capabilities
- Lease agreement modification rights

**Recommended Countermeasures**:
1. Store tokens in cookies with `HttpOnly`, `Secure`, and `SameSite=Strict` attributes
2. Reduce access token expiration to 15 minutes
3. Implement refresh token mechanism (7-day expiration) with rotation on each use
4. Add token binding to prevent token theft reuse
5. Implement logout endpoint that invalidates tokens server-side (currently missing from design)

**Relevant Section**: Section 3 Architecture Design, Section 5 Authentication and Authorization

---

### 1.2 Missing Idempotency Guarantees for Payment Processing

**Problem**: Section 5 defines `POST /api/payments/process` endpoint but provides no idempotency design. Network failures, user double-clicks, or retry logic could result in duplicate payment charges.

**Impact**:
- Tenants charged multiple times for the same rent payment
- Financial liability and regulatory compliance violations
- Damage to platform trust and potential lawsuits
- Payment reconciliation failures between Stripe and internal records

**Recommended Countermeasures**:
1. Add `idempotency_key` column to Payments table (UNIQUE constraint)
2. Require `Idempotency-Key` header on all payment API calls
3. Check for existing payment with same idempotency key before processing
4. Return existing payment result if key matches (HTTP 200, not 409)
5. Set idempotency key TTL to 24 hours minimum
6. Document idempotency requirements in API specification

**Relevant Section**: Section 5 Payment Endpoints, Section 4 Payments table

---

### 1.3 No Audit Logging Design for Compliance and Dispute Resolution

**Problem**: The design mentions CloudWatch logging (Section 6) but does not specify audit logging for security-critical events. There is no design for:
- Who accessed tenant background checks and when
- Who approved/rejected applications (audit trail)
- Lease agreement modifications and approvals
- Payment transaction history beyond basic `paid_date`
- Admin actions (refunds, data access, dispute resolution)

**Impact**:
- Cannot detect or investigate unauthorized data access
- No compliance with background check regulations (FCRA requires access logs)
- Cannot resolve disputes about application decisions or payment processing
- Insufficient evidence for fraud investigations
- Potential regulatory violations (SOC 2, GDPR access logs)

**Recommended Countermeasures**:
1. Design dedicated audit log table with: `event_type`, `actor_id`, `resource_id`, `action`, `timestamp`, `ip_address`, `user_agent`, `changes` (JSON diff)
2. Define audit event categories: AUTH (login, logout, permission changes), DATA_ACCESS (background check views, financial data access), STATE_CHANGE (application approval, lease termination, payment refund)
3. Implement immutable audit log storage (append-only, tamper-proof)
4. Set retention period: 7 years for financial transactions, 3 years for access logs
5. Protect audit logs with separate access controls (admin cannot delete own audit trail)
6. Include audit log query API for compliance reporting

**Relevant Section**: Section 6 Logging, Section 7 Security

---

### 1.4 Missing Encryption at Rest for Sensitive Personal Data

**Problem**: Section 7 specifies "All data transmitted over HTTPS/TLS 1.3" but does not address encryption at rest. The database stores highly sensitive data:
- Background check results (SSN, credit scores, criminal records)
- Payment information (even if Stripe handles cards, payment history and bank account details may be stored)
- Personal identification documents uploaded for verification
- Lease agreements with signatures

**Impact**:
- Database backup theft exposes plaintext sensitive data
- Insider threat: DBAs or compromised credentials can access all personal data
- Regulatory compliance violations: GDPR Article 32 requires encryption at rest for personal data, FCRA requires protection of consumer reports
- Data breach notification requirements triggered even for backup theft

**Recommended Countermeasures**:
1. Enable PostgreSQL Transparent Data Encryption (TDE) or AWS RDS encryption
2. Implement application-layer encryption for highly sensitive fields:
   - `background_check_status` and results (AES-256-GCM)
   - Uploaded identity documents in S3 (S3 SSE-KMS)
   - Payment details if stored (tokenize via Stripe instead)
3. Design key management strategy: AWS KMS with automatic key rotation
4. Encrypt database backups with separate encryption key
5. Document encryption coverage in data classification policy

**Relevant Section**: Section 4 Data Model, Section 7 Security

---

### 1.5 No CSRF Protection Design for State-Changing Operations

**Problem**: The design specifies JWT tokens in Authorization header but does not mention CSRF protection. State-changing endpoints like application approval (`PUT /api/applications/{id}/approve`), payment processing (`POST /api/payments/process`), and property deletion (`DELETE /api/properties/{id}`) are vulnerable to CSRF attacks if tokens are accessible to JavaScript.

**Impact**:
- Attacker can craft malicious webpage that submits tenant applications without consent
- Unauthorized lease terminations or property deletions
- Fraudulent payment processing if user is logged in
- Especially critical because JWT is in localStorage (accessible to JavaScript), making CSRF easier to exploit

**Recommended Countermeasures**:
1. Implement Double Submit Cookie pattern: Generate random CSRF token on login, store in cookie with `SameSite=Strict`, require matching header `X-CSRF-Token` on all POST/PUT/DELETE requests
2. Add CSRF token validation middleware to Spring Security configuration
3. If switching to HttpOnly cookies (recommended in 1.1), rely on `SameSite=Strict` as primary CSRF defense
4. Validate `Origin` and `Referer` headers as secondary check
5. Document CSRF token requirements in API specification

**Relevant Section**: Section 5 Authentication and Authorization, Section 5 API Design

---

### 1.6 Missing Input Validation Policy and Injection Prevention

**Problem**: Section 6 mentions "Validation errors return detailed field-level messages" but provides no input validation policy or injection prevention design. Critical gaps:
- No specification of allowed characters for address, description, user names
- No file upload validation policy (property photos, identity documents)
- No protection against SQL injection in search queries
- No HTML sanitization for user-generated content (property descriptions)
- No protection against NoSQL injection in Elasticsearch queries

**Impact**:
- SQL injection in property search (`GET /api/properties` with filters) could expose entire database
- Stored XSS in property descriptions affects all users viewing listings
- Path traversal in file uploads could overwrite system files
- XXE attacks if document parsing (lease agreements, identity verification) accepts XML
- Elasticsearch injection could expose sensitive tenant data

**Recommended Countermeasures**:
1. Define input validation policy document with:
   - Allowlist approach for all user inputs (regex patterns for email, phone, address)
   - Maximum length constraints (property description: 5000 chars, address: 500 chars)
   - Forbidden characters in names and addresses (prevent control characters)
2. Use parameterized queries (Spring Data JPA) for all database access - verify no raw SQL
3. Sanitize HTML in property descriptions using OWASP Java HTML Sanitizer
4. Validate file uploads:
   - Allowlist file types: JPEG, PNG, PDF only
   - Maximum size: 10MB per file
   - Scan with antivirus (ClamAV)
   - Store with random UUID filenames, not user-provided names
   - Serve from separate domain to prevent XSS via uploaded HTML
5. Use Elasticsearch Query DSL builders to prevent injection, never concatenate user input into queries
6. Implement Content Security Policy header to mitigate XSS impact

**Relevant Section**: Section 5 API Design, Section 6 Error Handling

---

### 1.7 No Rate Limiting Design for Authentication Endpoints

**Problem**: Section 7 specifies "API rate limiting: 100 requests/minute per IP address" globally, but this is insufficient for authentication endpoints. The login endpoint (`POST /api/auth/login`) is a prime target for:
- Credential stuffing attacks (trying stolen username/password pairs)
- Brute-force attacks against user accounts
- Account enumeration (timing attacks to identify valid emails)

Global rate limit of 100 req/min allows 100 login attempts per minute, which is far too permissive.

**Impact**:
- Successful brute-force attack grants access to tenant background checks, payment information, lease agreements
- Account enumeration enables targeted phishing attacks against confirmed users
- Platform-wide credential stuffing campaign could compromise many accounts simultaneously
- Especially critical for admin accounts (full system access)

**Recommended Countermeasures**:
1. Implement tiered rate limiting:
   - `/api/auth/login`: 5 attempts per 15 minutes per IP
   - `/api/auth/login`: 10 attempts per hour per email address (even from different IPs)
   - `/api/auth/register`: 3 registrations per hour per IP
   - Admin endpoints: 3 login attempts per hour, then 30-minute account lock
2. Add account lockout mechanism: Lock account for 30 minutes after 5 failed login attempts
3. Implement CAPTCHA after 3 failed login attempts (Google reCAPTCHA v3)
4. Add login attempt logging to audit trail
5. Use Redis for distributed rate limiting state (already in tech stack)
6. Implement exponential backoff: 1 min after 3 failures, 5 min after 4 failures, 30 min after 5 failures

**Relevant Section**: Section 7 Security, Section 5 Authentication Endpoints

---

### 1.8 Missing Authorization Design for Resource Ownership

**Problem**: Section 5 states "Each endpoint validates user role and resource ownership" but provides no design for how ownership is validated. Critical scenarios not addressed:
- Can a property owner approve applications for properties they don't own?
- Can a tenant view another tenant's payment history?
- Can a property manager access properties not assigned to them?
- How is "manager manages multiple properties on behalf of owners" relationship modeled?

**Impact**:
- Horizontal privilege escalation: Tenant A views Tenant B's background check results
- Property owner accesses revenue reports for competitors' properties
- Unauthorized lease modifications by malicious tenants
- Property managers exceed authorized property scope
- Privacy violations and regulatory non-compliance

**Recommended Countermeasures**:
1. Add authorization design section documenting ownership validation logic:
   ```
   GET /api/payments/history:
     - Tenants: Can only view payments for leases where tenant_id = authenticated_user.id
     - Owners: Can view payments for leases linked to properties where owner_id = authenticated_user.id
     - Managers: Can view payments for properties in property_manager_assignments table
     - Admins: Can view all payments
   ```
2. Implement Spring Security `@PreAuthorize` annotations with custom expressions: `@PreAuthorize("@propertySecurityService.canAccessProperty(#propertyId, authentication)")`
3. Add ownership check layer before business logic execution
4. Define `PropertyManagerAssignments` table to model manager-property relationships
5. Log all authorization failures to audit trail for investigation
6. Add integration tests verifying authorization boundaries

**Relevant Section**: Section 5 Authentication and Authorization, Section 4 Data Model

---

## 2. Improvement Suggestions (effective for improving design quality)

### 2.1 Add Session Management and Concurrent Login Controls

**Rationale**: The design has no session management beyond JWT tokens. There is no way to:
- Revoke access when user changes password or account is compromised
- Limit concurrent logins per user (prevent account sharing)
- Track active sessions for security monitoring
- Implement "logout all devices" functionality

**Recommended Countermeasures**:
1. Add `Sessions` table: `id`, `user_id`, `token_hash`, `created_at`, `expires_at`, `last_activity`, `ip_address`, `user_agent`
2. Validate token against session table on each request (use Redis cache for performance)
3. Invalidate all sessions when user changes password
4. Limit to 5 concurrent sessions per user, automatically revoke oldest session
5. Provide "View Active Sessions" and "Revoke Session" API endpoints
6. Implement session activity timeout: Auto-logout after 30 minutes of inactivity

---

### 2.2 Design Data Retention and Deletion Policy for GDPR Compliance

**Rationale**: The design has no data retention policy. GDPR requires:
- Right to be forgotten (user can request data deletion)
- Purpose limitation (data deleted when no longer needed)
- Retention limits for different data categories
The platform stores sensitive data that should not be retained indefinitely:
- Background check reports (should be deleted after lease decision)
- Payment history (must be retained for tax/legal purposes)
- Terminated lease records

**Recommended Countermeasures**:
1. Document data retention policy:
   - Background check reports: Delete 90 days after application decision
   - Rejected applications: Delete after 1 year
   - Terminated leases: Retain for 7 years (tax law requirement), then archive/delete
   - User accounts: Soft delete (anonymize personal data) 90 days after account closure
   - Audit logs: Retain for 7 years (financial records) or 3 years (access logs)
2. Implement soft delete mechanism: Add `deleted_at` column, exclude from queries
3. Add scheduled job to permanently delete data past retention period
4. Implement "Request Data Deletion" API for GDPR compliance
5. Document data export functionality for GDPR data portability requirement

---

### 2.3 Add Webhook Signature Verification for Third-Party Integrations

**Rationale**: The design integrates with Stripe (payments), Checkr (background checks), and DocuSign (e-signatures). These services send webhook notifications for event updates (payment succeeded, background check completed, document signed). The design does not specify webhook security.

**Risk**: Attackers could send fake webhook events to:
- Mark unpaid rent as paid
- Approve applications by faking background check success
- Mark unsigned leases as signed

**Recommended Countermeasures**:
1. Verify webhook signatures using provider-specific signing secrets:
   - Stripe: Verify `Stripe-Signature` header using webhook secret
   - Checkr: Verify HMAC signature with shared secret
   - DocuSign: Verify JWT signature with DocuSign public key
2. Implement webhook signature verification middleware
3. Use HTTPS-only webhook URLs
4. Validate webhook payload schema before processing
5. Implement idempotency for webhook processing (deduplicate using event ID)
6. Log all webhook receipts to audit trail

---

### 2.4 Implement Background Check Result Access Logging for FCRA Compliance

**Rationale**: The Fair Credit Reporting Act (FCRA) requires:
- Notice to applicants before obtaining background check
- Applicant consent to background check
- Adverse action notice if application rejected based on background check
- Access logging for who viewed consumer reports

The design integrates Checkr API but does not address FCRA compliance requirements.

**Recommended Countermeasures**:
1. Add `background_check_consent` table: `applicant_id`, `consented_at`, `consent_ip`, `consent_text_version`
2. Require explicit consent checkbox before submitting application
3. Add `background_check_access_log` table: `report_id`, `accessed_by_user_id`, `accessed_at`, `purpose`
4. Implement separate endpoint for viewing background check results (not auto-included in application response)
5. Add "Adverse Action Notice" workflow: If application rejected and background check was factor, system generates required disclosure
6. Document FCRA compliance in legal/compliance section

---

### 2.5 Add Security Headers to API Responses

**Rationale**: The design does not specify HTTP security headers. These headers provide defense-in-depth against common attacks.

**Recommended Countermeasures**:
1. Configure Spring Security to add headers:
   ```
   Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'
   X-Content-Type-Options: nosniff
   X-Frame-Options: DENY
   X-XSS-Protection: 1; mode=block
   Strict-Transport-Security: max-age=31536000; includeSubDomains
   Referrer-Policy: strict-origin-when-cross-origin
   Permissions-Policy: geolocation=(), microphone=(), camera=()
   ```
2. Set `SameSite=Strict` on all cookies (session, CSRF token)
3. Disable CORS or restrict to specific domains (not wildcard `*`)
4. Add security headers to CDN configuration (CloudFront)

---

### 2.6 Design Secret Management Strategy for API Keys and Credentials

**Rationale**: The design mentions AWS Parameter Store (Section 6) but does not specify how secrets are managed:
- Stripe API keys (secret key, webhook secret)
- Checkr API key
- DocuSign integration credentials
- JWT signing secret
- Database passwords
- Redis password

**Risk**: Hardcoded secrets in code or config files could leak via:
- Git repository exposure
- Docker image inspection
- Log files
- Developer workstations

**Recommended Countermeasures**:
1. Use AWS Secrets Manager (not Parameter Store) for sensitive credentials - automatic rotation support
2. Never commit secrets to Git: Use `.env.example` template with placeholder values
3. Implement secret rotation policy:
   - JWT signing key: Rotate every 90 days (support key versioning for gradual rollout)
   - Database passwords: Rotate every 6 months
   - API keys: Rotate when employee leaves or on suspected compromise
4. Use IAM roles for AWS service access (no hardcoded access keys)
5. Implement secret access audit logging (who retrieved which secret when)
6. Use separate secrets for dev/staging/production environments

---

### 2.7 Add Missing Error Handling Design for Security-Critical Failures

**Rationale**: Section 6 describes general error handling but does not specify behavior for security-critical failures:
- What happens if Stripe payment processing fails mid-transaction?
- How does system handle Checkr API timeout during background check?
- What if DocuSign webhook never arrives (signature incomplete)?
- How to handle database connection failures during payment processing?

**Risk**: Improper error handling could result in:
- Inconsistent state (payment charged but not recorded in database)
- Security bypasses (background check failure treated as success)
- Data loss or corruption

**Recommended Countermeasures**:
1. Design failure modes for each critical operation:
   - Payment processing: If Stripe succeeds but database write fails, trigger reconciliation job
   - Background check: If Checkr API timeout, mark application as "pending_verification" and retry
   - E-signature: If DocuSign webhook not received within 24 hours, query DocuSign API for status
2. Implement distributed transaction pattern for multi-step operations (Saga pattern)
3. Add dead letter queue for failed async operations
4. Design manual reconciliation process for stuck transactions
5. Alert operations team on critical error patterns (high failure rate for payments)
6. Never expose internal error details in API responses (stack traces, database errors)

---

### 2.8 Implement Dependency Security Scanning and Update Policy

**Rationale**: The design specifies library versions (Spring Security 6.0, React 18, etc.) but has no dependency security policy. Vulnerable dependencies are a common attack vector:
- Log4Shell (CVE-2021-44228) affected Spring Boot applications
- React and npm ecosystem have frequent security advisories
- Third-party libraries (Stripe SDK, AWS SDK) may have vulnerabilities

**Recommended Countermeasures**:
1. Integrate dependency scanning tools:
   - Backend: OWASP Dependency-Check or Snyk in GitHub Actions pipeline
   - Frontend: `npm audit` and Dependabot alerts
2. Define update policy:
   - Critical security patches: Apply within 24 hours
   - High severity: Apply within 7 days
   - Medium/Low: Review monthly
3. Implement automated dependency update PRs (Dependabot or Renovate)
4. Maintain Software Bill of Materials (SBOM) for compliance
5. Block deployment if critical vulnerabilities detected
6. Subscribe to security advisories for key dependencies

---

### 2.9 Add Property Image Upload Security Controls

**Rationale**: Property owners upload property photos, but Section 5 mentions AWS S3 storage without security controls:
- No file type validation (could upload malicious files)
- No size limits (could exhaust storage)
- No access controls (could property images be accessed without authentication?)
- No malware scanning

**Risk**:
- Uploaded HTML/SVG files could execute JavaScript (XSS)
- Malware distribution via property listings
- DDOS via large file uploads
- Privacy violations if private photos leaked

**Recommended Countermeasures**:
1. Validate file uploads:
   - Allowlist MIME types: `image/jpeg`, `image/png` only (not SVG or GIF due to XSS risk)
   - Validate file magic bytes, not just extension (prevent disguised files)
   - Maximum size: 5MB per image, 10 images per property
   - Re-encode images using ImageMagick to strip EXIF metadata and malicious payloads
2. Store images in S3 with:
   - Private bucket (not public read)
   - Presigned URLs for time-limited access (1-hour expiration)
   - Random UUID filenames (prevent enumeration)
   - Separate S3 bucket from application data
3. Implement virus scanning (ClamAV or AWS S3 antivirus)
4. Serve images via CloudFront with separate domain (prevent XSS affecting main app)
5. Add rate limiting: 10 image uploads per hour per user

---

### 2.10 Design Account Lockout and Suspicious Activity Detection

**Rationale**: Beyond rate limiting (addressed in 1.7), the design lacks proactive security monitoring:
- No account lockout after failed login attempts from multiple IPs (distributed brute-force)
- No detection of unusual access patterns (login from new location/device)
- No notification to users about suspicious activity

**Recommended Countermeasures**:
1. Implement behavioral detection:
   - Track typical login location/IP range per user
   - Alert user via email if login from new device or location
   - Alert if account accessed at unusual time (e.g., 3 AM when user normally logs in at 9 AM)
2. Add progressive account protection:
   - After 3 failed logins: Require CAPTCHA
   - After 5 failed logins: Lock account for 30 minutes
   - After 10 failed logins in 24 hours: Require email verification to unlock
3. Detect impossible travel: If login from US and 10 minutes later from Europe, flag as suspicious
4. Implement "Review Recent Activity" page showing login history, IP addresses, devices
5. Add "This wasn't me" button to security alerts for quick account lockdown

---

## 3. Confirmation Items (requiring user clarification)

### 3.1 Multi-Tenancy Isolation for Property Manager Accounts

**Question**: Section 2 mentions property managers can "manage multiple properties on behalf of owners," but the data model (Section 4) has no table for property manager assignments or owner-manager relationships.

**Options**:
- **Option A**: Property managers are same as property owners (manager creates properties with themselves as owner) - simpler but less accurate
- **Option B**: Add `PropertyManagerAssignments` table linking managers to properties with owner approval - more complex but proper authorization model
- **Option C**: Managers have organizational accounts with sub-accounts for each owner - enterprise multi-tenancy model

**Trade-offs**: Option B is recommended for security (clear authorization boundaries) but requires additional UI for owner to grant/revoke manager access. Option A is simpler but may create confusion about data ownership and GDPR data controller responsibilities.

---

### 3.2 PII Handling for Background Check Integration

**Question**: The design integrates with Checkr API for background checks but does not specify what data is stored locally vs. retrieved on-demand:
- Is SSN stored in the database or only sent to Checkr?
- Are background check reports cached locally or fetched from Checkr API each time?
- How long are background check results retained?

**Options**:
- **Option A**: Store minimal data (application ID and Checkr report ID), fetch full report from Checkr API when needed - reduces data liability
- **Option B**: Cache background check results in database - faster but higher compliance burden
- **Option C**: Store SSN encrypted in database for repeat checks - convenience vs. risk

**Trade-offs**: Option A minimizes PII storage and reduces GDPR/FCRA compliance scope, but increases Checkr API costs and latency. Option B requires encryption at rest, access logging, and data retention policy. Recommended: Option A for reduced liability.

---

### 3.3 Payment Refund Authorization and Audit Trail

**Question**: Section 5 defines `POST /api/payments/refund` (admin only) but provides no refund policy or authorization workflow:
- Can any admin issue refunds without approval?
- What is the maximum refund amount without additional authorization?
- How are refunds reconciled with Stripe payment intents?
- Are refunds audit logged with justification?

**Options**:
- **Option A**: Any admin can refund any amount - fastest but high fraud risk
- **Option B**: Refunds over $1000 require dual approval from two admins - secure but slower
- **Option C**: Implement approval workflow with reason codes and tenant notification - most robust

**Trade-offs**: Option C provides best security and audit trail but adds complexity. Recommend: Option B as minimum (dual approval for large refunds), with audit logging of all refund actions including reason and approver.

---

### 3.4 Lease Agreement E-Signature Workflow Security

**Question**: The design integrates DocuSign for e-signatures but does not specify:
- How are lease documents generated (template? PDF generation?)?
- Are both tenant and owner required to sign?
- What prevents tampering between generation and signing?
- How is completed lease stored (DocuSign only or local copy)?

**Options**:
- **Option A**: Generate PDF from database data, send to DocuSign, store signed copy in S3 - full control but complex
- **Option B**: Use DocuSign templates with field merging - simpler but less flexible
- **Option C**: Store only DocuSign envelope ID, retrieve signed document on-demand - reduces storage but depends on DocuSign availability

**Trade-offs**: Option A provides best non-repudiation (hash of unsigned lease stored before signing, compared to signed version) but requires PDF generation security. Recommended: Option A with document hash verification to detect tampering.

---

## 4. Positive Evaluation (good points)

### 4.1 Appropriate Use of Bcrypt for Password Hashing

The design specifies bcrypt with cost factor 12 (Section 7), which is an industry best practice for password hashing. Bcrypt is resistant to brute-force attacks due to its computational cost, and a cost factor of 12 provides good security without excessive performance impact. This is significantly better than using MD5, SHA-1, or unsalted hashes.

---

### 4.2 PCI-DSS Compliance Through Stripe Integration

The design correctly delegates payment card handling to Stripe (Section 7: "Payment card data handled via Stripe (PCI-DSS compliant), never stored on our servers"). This is the appropriate approach for a rental platform that does not need to store card data directly. By using Stripe's tokenization, the system avoids the significant compliance burden of PCI-DSS certification while still enabling recurring rent payments.

---

### 4.3 HTTPS/TLS 1.3 for Data in Transit

Section 7 specifies TLS 1.3 for all data transmission, which is the latest TLS version with improved security and performance over TLS 1.2. This protects against man-in-the-middle attacks and eavesdropping on sensitive data like background checks and payment information.

---

### 4.4 Structured Logging with Sensitive Data Exclusion

Section 6 explicitly documents that sensitive data (passwords, tokens, SSNs) should be excluded from logs. This is a critical security practice that prevents data leaks through log files, centralized logging systems (CloudWatch), or third-party log analysis tools. The design's awareness of this risk is commendable.

---

### 4.5 Automated Security Testing Integration

Section 6 includes OWASP ZAP for vulnerability scanning as part of the testing strategy. This proactive security testing helps identify common vulnerabilities (XSS, SQL injection, CSRF) before deployment. The integration of security testing into the development workflow demonstrates a security-conscious development culture.

---

### 4.6 Database Backup Strategy

Section 7 specifies regular backups (full daily, incremental every 6 hours), which is essential for disaster recovery and ransomware protection. While the design should also address backup encryption and offsite storage, the existence of a documented backup policy is a positive security control.
