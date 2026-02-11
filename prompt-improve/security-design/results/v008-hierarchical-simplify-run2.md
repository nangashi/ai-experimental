# Security Design Review: Real Estate Rental Platform

## Critical Issues (design modification required)

### 1. JWT Token Storage Method and Expiration Period are Dangerous
- **Issue**: JWT tokens stored in localStorage (Section 3, Data Flow step 1) with 24-hour expiration (Section 5.4) exposes severe XSS vulnerability and extended attack window
- **Impact**: Any XSS vulnerability allows attackers to steal tokens valid for 24 hours, enabling complete account takeover. In a financial platform handling rent payments and sensitive tenant data (SSNs, background checks), this is a critical breach vector
- **Recommended Countermeasures**:
  - Switch to cookies with HttpOnly + Secure + SameSite=Strict attributes to prevent JavaScript access
  - Reduce access token expiration to 15 minutes
  - Implement refresh token mechanism (7-day expiration with rotation) stored in HttpOnly cookies
  - Add token binding to prevent token theft reuse
- **Relevant Section**: Section 3 (Data Flow), Section 5.4 (Authentication and Authorization)

### 2. No Authorization Model for Cross-User Resource Access
- **Issue**: Authorization design only mentions "role-based access control" and "resource ownership validation" without specifying the authorization model or how ownership is verified
- **Impact**: Risk of Insecure Direct Object Reference (IDOR) vulnerabilities. Tenant A could access Tenant B's application details, payment history, or lease documents by manipulating IDs in API requests (e.g., `GET /api/applications/{other_user_application_id}`)
- **Recommended Countermeasures**:
  - Implement explicit authorization checks: verify `current_user.id == resource.owner_id` before all read/write operations
  - For property managers managing multiple properties, implement a `manager_properties` join table and verify `property_id IN current_user.managed_properties`
  - Add authorization integration tests covering cross-tenant access attempts
  - Document the authorization matrix specifying which roles can access which resources under what conditions
- **Relevant Section**: Section 5.4 (Authentication and Authorization), Section 5 (API Design)

### 3. Background Check and Payment Data Have No Encryption at Rest
- **Issue**: Database design (Section 4) shows sensitive columns (`background_check_status`, `stripe_payment_intent_id`) stored without encryption at rest. No mention of column-level or database-level encryption
- **Impact**: Database compromise (SQL injection, stolen backups, insider threat) exposes sensitive tenant screening data (credit reports, criminal records) and payment transaction IDs. Violates FCRA requirements for background check data protection and PCI-DSS requirements for payment data security
- **Recommended Countermeasures**:
  - Enable PostgreSQL transparent data encryption (TDE) or AWS RDS encryption at rest
  - Implement application-level encryption for highly sensitive columns: `background_check_status`, `stripe_payment_intent_id`, SSN fields (if collected)
  - Store encryption keys in AWS KMS with automatic rotation
  - Document data classification policy and encryption requirements per classification level
- **Relevant Section**: Section 4 (Data Model), Section 7.2 (Security - only mentions bcrypt for passwords, silent on data at rest)

### 4. Admin Endpoints Lack Elevated Authentication and Audit Logging
- **Issue**: Admin-only endpoints (`POST /api/payments/refund`) have no mention of multi-factor authentication (MFA), IP whitelisting, or audit logging for privileged actions
- **Impact**: Compromised admin credentials allow financial fraud (issuing refunds to attacker-controlled accounts), data exfiltration (accessing all tenant/owner data), and privilege escalation. Without audit logs, detecting and investigating breaches is impossible
- **Recommended Countermeasures**:
  - Require MFA for all admin role accounts (implement via TOTP with libraries like `spring-security-oauth2` or integrate with AWS Cognito MFA)
  - Restrict admin endpoints to VPN or office IP ranges via API Gateway IP whitelisting
  - Implement comprehensive audit logging for all admin actions: log user ID, action, timestamp, IP address, affected resource IDs
  - Store audit logs in immutable storage (AWS S3 with object lock) to prevent tampering
- **Relevant Section**: Section 5.3 (Payment Endpoints), Section 2.4 (Technology Stack mentions admin role but no admin security measures)

### 5. No Input Validation Policy for Property Listings and User Uploads
- **Issue**: No mention of input validation rules, sanitization, or file upload restrictions despite user-generated content (property descriptions, addresses) and likely file uploads (property photos, lease documents)
- **Impact**:
  - **Stored XSS**: Malicious JavaScript in property descriptions executed when other users view listings
  - **SQL Injection**: Unsanitized inputs in search queries or CRUD operations bypass ORM protections
  - **Malicious File Uploads**: Attackers upload web shells disguised as images, gaining server access
- **Recommended Countermeasures**:
  - Define input validation policy: max length limits, allowed character sets, regex patterns for structured fields (email, phone, address)
  - Implement server-side validation for all API inputs using Spring Validation (`@Valid`, `@NotNull`, `@Size`)
  - Sanitize HTML output in property descriptions using libraries like OWASP Java HTML Sanitizer
  - For file uploads: validate file type via magic number (not extension), scan with antivirus (ClamAV), enforce size limits (e.g., 10MB), store in S3 with restricted ACLs (no execute permissions)
  - Use parameterized queries for all database operations (already standard in JPA/Hibernate, but enforce via code review)
- **Relevant Section**: Section 5 (API Design - lacks validation specification), Section 6.1 (Error Handling mentions validation errors but not validation rules)

### 6. Stripe Payment Integration Lacks Idempotency and Webhook Verification
- **Issue**: Payment processing endpoint (`POST /api/payments/process`) has no mention of idempotency keys or webhook signature verification for Stripe callbacks
- **Impact**:
  - **Double Charges**: Network retries or user button mashing cause duplicate payment charges
  - **Webhook Spoofing**: Attackers forge Stripe webhook events to mark unpaid invoices as paid or trigger fraudulent refunds
- **Recommended Countermeasures**:
  - Generate idempotency keys (UUID) client-side and pass in `Idempotency-Key` header. Store processed keys in Redis with 24-hour TTL to reject duplicates
  - Verify Stripe webhook signatures using `stripe.webhooks.constructEvent()` with signing secret from environment variables
  - Implement webhook replay attack protection: check `stripe_event_id` uniqueness before processing
  - Add payment reconciliation job to detect discrepancies between Stripe and internal payment records
- **Relevant Section**: Section 5.3 (Payment Endpoints), Section 2.4 (Key Libraries mentions Stripe API)

## Improvement Suggestions (effective for improving design quality)

### 7. Missing Rate Limiting for Authentication Endpoints
- **Issue**: API rate limiting configured at 100 req/min per IP (Section 7.2) but no mention of endpoint-specific limits for authentication endpoints
- **Rationale**: Login/registration endpoints are prime targets for credential stuffing and brute-force attacks. Generic rate limiting is insufficient for high-value targets
- **Recommended Countermeasures**:
  - Configure stricter rate limits for `/api/auth/login`: 5 attempts per 15 minutes per IP
  - Implement account-level lockout: lock account for 30 minutes after 5 failed login attempts
  - Add CAPTCHA after 3 failed attempts (integrate reCAPTCHA v3)
  - Monitor and alert on distributed brute-force attacks (many IPs targeting same account)
- **Relevant Section**: Section 7.2 (Security - generic rate limiting only)

### 8. No Session Management or Token Revocation Mechanism
- **Issue**: JWT authentication design lacks logout mechanism, token revocation, or session invalidation strategy
- **Rationale**: Tokens remain valid until expiration even after logout. Compromised tokens cannot be revoked. Users cannot remotely log out stolen sessions
- **Recommended Countermeasures**:
  - Maintain active session list in Redis: `sessions:{user_id} -> Set<token_hash>`
  - On logout, delete token from Redis and blacklist token hash with TTL matching token expiration
  - Provide "View Active Sessions" feature allowing users to revoke specific sessions
  - Implement token version claim: increment version on password change/logout to invalidate all existing tokens
- **Relevant Section**: Section 5.1 (Authentication Endpoints - logout exists but implementation unclear)

### 9. Third-Party API Failures Lack Fallback and Security Monitoring
- **Issue**: Design integrates Checkr (background checks), DocuSign (e-signatures), Stripe (payments) but has no mention of circuit breakers, fallback strategies, or security monitoring for third-party failures
- **Rationale**: Third-party API outages can cause denial of service for critical workflows. Compromised third-party credentials can be used to exfiltrate data or manipulate transactions
- **Recommended Countermeasures**:
  - Implement circuit breakers (using Resilience4j) for all third-party API calls with fallback strategies (e.g., queue background check for retry, allow manual document upload if DocuSign fails)
  - Monitor third-party API credentials usage: alert on unusual volumes, geographic anomalies, or credential usage outside business hours
  - Rotate third-party API keys quarterly and store in AWS Secrets Manager with automatic rotation
  - Implement webhook validation for all third-party callbacks (Stripe, Checkr status updates) to prevent spoofing
- **Relevant Section**: Section 2.4 (Key Libraries), Section 3.2 (Core Components mention third-party integration)

### 10. Database Backup Restoration Procedure Not Documented
- **Issue**: Backup frequency defined (daily full, 6-hour incremental) but no mention of restoration testing, retention period, or access controls
- **Rationale**: Untested backups may be corrupted or incomplete. Excessive retention exposes historical data to breach. Unrestricted backup access creates insider threat vector
- **Recommended Countermeasures**:
  - Test backup restoration quarterly with documented runbook
  - Define retention policy: 30 days for incremental backups, 1 year for monthly full backups, then archive to AWS Glacier
  - Encrypt backups at rest (AWS RDS snapshots encrypted via KMS)
  - Restrict backup access to dedicated IAM role with MFA requirement and audit logging
- **Relevant Section**: Section 7.3 (Availability and Scalability - backup frequency only)

### 11. Property Search Injection Risk via Elasticsearch
- **Issue**: Property search uses Elasticsearch (Section 2.3) but no mention of query sanitization or injection prevention for user-supplied search filters
- **Rationale**: Unsanitized inputs in Elasticsearch queries can bypass access controls, exfiltrate data, or cause denial of service via resource-intensive queries
- **Recommended Countermeasures**:
  - Use Elasticsearch client's parameterized query builders (never concatenate user input into query strings)
  - Whitelist allowed search fields: `address`, `monthly_rent`, `bedrooms`, `bathrooms` (reject queries on internal fields like `owner_id`)
  - Implement query complexity limits: max 10 filter clauses, reject wildcard prefixes, limit result size to 1000
  - Add logging and alerting for suspicious search patterns (e.g., attempts to query `*` or administrative indices)
- **Relevant Section**: Section 2.3 (Database - Elasticsearch for search), Section 5.2 (Property Endpoints - search endpoint)

### 12. No CSRF Protection for State-Changing Endpoints
- **Issue**: No mention of CSRF tokens or SameSite cookie attributes for state-changing operations (create property, approve application, process payment)
- **Rationale**: Without CSRF protection, attackers can trick authenticated users into performing unintended actions via malicious websites (e.g., approve fraudulent rental applications, transfer payment to attacker account)
- **Recommended Countermeasures**:
  - Implement CSRF token validation middleware using Spring Security's CSRF protection
  - Use Double Submit Cookie pattern: send CSRF token in cookie and require matching token in request header/body
  - Configure SameSite=Strict for authentication cookies (already recommended in Issue #1)
  - Exempt only truly stateless GET endpoints from CSRF checks
- **Relevant Section**: Section 5 (API Design - no CSRF mention), Section 3 (Architecture - JWT tokens don't inherently prevent CSRF)

### 13. Sensitive Data Logging Risk in Request/Response Logging
- **Issue**: Implementation guidelines specify "Request/response logging for API calls" (Section 6.2) but sensitive data exclusion only mentions passwords, tokens, SSNs
- **Rationale**: Logs may inadvertently capture credit card numbers (partial), background check results, lease terms, addresses. CloudWatch logs accessible to developers create data exposure risk
- **Recommended Countermeasures**:
  - Expand sensitive data exclusion list: credit card numbers, bank account numbers, background check results, full addresses (log city/state only), email addresses (hash or redact)
  - Implement request/response filtering middleware that redacts sensitive fields before logging
  - Use structured logging with field-level redaction (e.g., Logback with custom filters)
  - Restrict CloudWatch logs access to security team only; developers access sanitized logs
- **Relevant Section**: Section 6.2 (Logging - incomplete sensitive data list)

### 14. Missing Lease Document Access Control
- **Issue**: Lease management mentioned (Section 3.2) with DocuSign integration but no specification of document access controls or audit trails
- **Rationale**: Lease documents contain highly sensitive PII (SSNs, income, references). Unauthorized access by property managers, support staff, or attackers exploiting IDOR vulnerabilities is a privacy breach
- **Recommended Countermeasures**:
  - Store lease documents in S3 with private ACLs; generate pre-signed URLs (1-hour expiration) for authorized access only
  - Implement document access logging: record user ID, document ID, access timestamp, IP address
  - Enforce authorization checks: tenant and property owner can access lease document; property manager only if managing that property; admin with MFA and audit log
  - Add watermarking to downloaded documents with user ID and download timestamp to deter unauthorized sharing
- **Relevant Section**: Section 3.2 (Core Components - Lease Service), Section 2.4 (DocuSign API integration)

### 15. No Defense Against Automated Application Submission (Bot Abuse)
- **Issue**: Tenant application endpoint (`POST /api/applications`) has no mention of bot detection or rate limiting
- **Rationale**: Automated bots can spam property owners with fake applications, degrading service quality and incurring background check costs (Checkr API charges per check)
- **Recommended Countermeasures**:
  - Require CAPTCHA (reCAPTCHA v3) for application submission
  - Implement per-user application rate limiting: max 5 applications per day per tenant account
  - Add anomaly detection: flag accounts submitting >10 applications in 1 hour for manual review
  - Require email verification before allowing application submission for new accounts
- **Relevant Section**: Section 5.3 (Application Endpoints), Section 3.2 (Application Service)

## Confirmation Items (requiring user clarification)

### 16. Multi-Tenancy Isolation Strategy Not Specified
- **Question**: Are multiple property owners' data stored in the same database tables with tenant ID filtering, or is there schema-level isolation?
- **Security Implication**: Shared schema without robust row-level security increases risk of cross-tenant data leakage via query bugs or ORM misconfiguration
- **Recommendation if Shared Schema**: Implement PostgreSQL Row-Level Security (RLS) policies to enforce tenant isolation at database level as defense-in-depth
- **Relevant Section**: Section 4 (Data Model - shows `owner_id` foreign keys but no isolation mechanism)

### 17. Mobile App Authentication Flow Not Described
- **Question**: How do React Native mobile apps (Section 2.1) handle JWT token storage and renewal?
- **Security Implication**: Mobile apps cannot use HttpOnly cookies. Token storage in AsyncStorage is vulnerable to device compromise or malware
- **Recommendation**: Use secure device storage (iOS Keychain, Android Keystore) for refresh tokens. Implement certificate pinning for API calls to prevent MITM attacks
- **Relevant Section**: Section 2.1 (Mobile Apps mentioned), Section 5.4 (Authentication design assumes browser context)

### 18. Compliance Requirements (FCRA, FHA) Not Documented
- **Question**: What regulatory compliance requirements govern background check handling (FCRA) and rental discrimination prevention (Fair Housing Act)?
- **Security Implication**: Non-compliance with FCRA (background check disclosure, adverse action notices) or FHA (discriminatory filtering prevention) creates legal liability
- **Recommendation**: Document compliance requirements in dedicated section. Implement consent workflows, adverse action notice automation, and audit logging for protected class filtering
- **Relevant Section**: Section 1 (Overview mentions background checks but not compliance), Section 3.2 (Application Service)

## Positive Evaluation (good points)

### 19. Strong Password Hashing with bcrypt
- The design specifies bcrypt with cost factor 12 (Section 7.2), which is appropriate for password storage and provides sufficient computational cost to resist brute-force attacks. The cost factor should be reviewed annually and increased as hardware improves

### 20. PCI-DSS Compliance via Stripe Delegation
- Delegating payment card handling to Stripe (Section 7.2) eliminates PCI-DSS compliance burden and ensures payment data is never stored on application servers. This is a best practice for applications without dedicated security infrastructure

### 21. Comprehensive Infrastructure Monitoring
- The design includes CloudWatch, Prometheus, and Grafana for monitoring (Section 2.3), which enables detection of anomalous behavior, performance degradation, and security incidents. Ensure security metrics (failed login attempts, authorization failures, rate limit hits) are included in dashboards

### 22. Automated Security Scanning in CI/CD
- Inclusion of OWASP ZAP for vulnerability scanning (Section 6.3) demonstrates proactive security testing. Recommend running ZAP in CI/CD pipeline on every deployment to catch regressions

### 23. Blue/Green Deployment for Availability
- Blue/green deployment strategy (Section 6.4) minimizes downtime and provides rapid rollback capability in case of security incidents or defects introduced in new releases

## Score Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | Critical vulnerabilities: XSS-vulnerable token storage (Spoofing), missing CSRF protection (Tampering), no audit logging for admin actions (Repudiation), unencrypted sensitive data at rest (Information Disclosure), no bot protection (DoS), IDOR authorization gaps (Elevation of Privilege) |
| Authentication & Authorization Design | 1 | Critical flaws: localStorage JWT storage with 24-hour expiration, no authorization model specification, missing MFA for admin, no token revocation, no session management |
| Data Protection | 2 | No encryption at rest for background check/payment data, incomplete logging redaction rules, lease document access controls not specified, partial TLS coverage |
| Input Validation Design | 2 | No input validation policy, no file upload security, Elasticsearch injection risk, missing output sanitization for XSS prevention |
| Infrastructure & Dependencies | 3 | Good use of Stripe for PCI compliance and bcrypt for passwords, but missing third-party API security (circuit breakers, credential rotation, webhook verification), backup restoration testing, Secrets Manager usage |
| **Overall** | **2.0** | Multiple critical vulnerabilities requiring immediate design changes before implementation. Strong foundation in some areas (password hashing, PCI compliance) undermined by fundamental authentication and authorization flaws |
