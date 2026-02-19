# Security Design Review: FoodConnect System

**Review Date**: 2026-02-10
**Document**: test-document-round-014.md
**Reviewer**: security-design-reviewer

---

## Executive Summary

This design document presents a multi-sided marketplace platform with significant security gaps at the architecture and design level. The most critical findings include missing authentication token storage specifications, absent CSRF protection, lack of idempotency guarantees, insufficient audit logging design, and missing security policies across multiple domains. The overall security posture requires substantial improvement before production deployment.

**Overall Risk Level**: HIGH

---

## Critical Issues (Score: 1)

### 1. Missing JWT Token Storage Mechanism Specification

**Criterion**: Authentication & Authorization Design
**Score**: 1 (Critical)

**Issue**: The design specifies JWT authentication with 24-hour access tokens and 30-day refresh tokens, but does not specify how these tokens should be stored on the client side.

**Risk**: If tokens are stored in localStorage or sessionStorage (common but insecure practice), they are vulnerable to XSS attacks. Any JavaScript injection can exfiltrate tokens and allow complete account takeover.

**Impact**:
- Complete account compromise through XSS
- Unauthorized access to all user data and operations
- Privilege escalation (if attacker obtains admin tokens)
- Affects all user types: customers, restaurants, drivers, admins

**Recommendation**:
- Explicitly specify httpOnly + Secure cookies for JWT storage
- Set SameSite=Strict or SameSite=Lax attribute to mitigate CSRF
- Document cookie configuration in API design section:
  ```
  Set-Cookie: accessToken=<jwt>; HttpOnly; Secure; SameSite=Strict; Max-Age=86400
  Set-Cookie: refreshToken=<jwt>; HttpOnly; Secure; SameSite=Strict; Max-Age=2592000
  ```
- Update API Gateway and authentication service configurations accordingly

**Reference**: Section 5 (API Design) - Authentication subsection

---

### 2. Missing CSRF Protection Design

**Criterion**: Authentication & Authorization Design
**Score**: 1 (Critical)

**Issue**: No CSRF protection mechanism is designed for state-changing operations (POST/PATCH/DELETE requests). The JWT authentication alone does not protect against CSRF if tokens are sent automatically (e.g., via cookies).

**Risk**: Attackers can craft malicious websites that trigger unauthorized actions (place orders, change passwords, cancel deliveries) on behalf of authenticated users.

**Impact**:
- Unauthorized orders charged to victim's payment method
- Account takeover via password reset
- Delivery cancellations and service disruption
- Financial loss and reputational damage

**Recommendation**:
- Implement CSRF token mechanism:
  - Generate unique CSRF token per session
  - Require CSRF token in custom header (e.g., X-CSRF-Token) for state-changing operations
  - Validate token on server side before processing request
- Alternative: Use SameSite=Strict cookies + custom header requirement
- Document CSRF protection policy in Section 7 (Security Requirements)

**Reference**: Section 5 (API Design) - All POST/PATCH endpoints

---

### 3. Missing Idempotency Guarantees for State-Changing Operations

**Criterion**: Data Protection & Transaction Integrity
**Score**: 1 (Critical)

**Issue**: No idempotency mechanism is designed for critical state-changing operations (order creation, payment processing, status updates). Network failures or client retries could result in duplicate orders or duplicate charges.

**Risk**: Users may be charged multiple times for the same order, or duplicate orders may be created without user intent.

**Impact**:
- Duplicate charges leading to financial disputes
- Inventory depletion from duplicate orders
- Customer trust erosion
- Legal liability for overcharging
- Operational overhead in refund processing

**Recommendation**:
- Design idempotency key mechanism:
  - Accept `Idempotency-Key` header in POST /api/v1/orders and POST /api/v1/payments
  - Store idempotency key + response mapping in database or cache
  - Return cached response if duplicate request detected within TTL (e.g., 24 hours)
- Add idempotency_key column to Orders and Payments tables with unique constraint
- Document retry handling policy in API design section
- Example:
  ```
  POST /api/v1/orders
  Headers:
    Authorization: Bearer <token>
    Idempotency-Key: <uuid>
  ```

**Reference**: Section 5 (API Design) - POST /api/v1/orders, POST /api/v1/payments

---

## Significant Issues (Score: 2)

### 4. Missing Rate Limiting Specifications

**Criterion**: Infrastructure & Dependency Security
**Score**: 2 (Significant)

**Issue**: While the API Gateway is mentioned to provide "rate limiting," the design does not specify:
- Rate limit thresholds (requests per minute/hour)
- Rate limiting scope (per IP, per user, per endpoint)
- Rate limiting response behavior (429 status code, Retry-After header)

**Risk**: Without specific rate limiting design, the system is vulnerable to:
- Brute-force attacks on authentication endpoints
- DoS attacks that exhaust backend resources
- Inventory enumeration attacks

**Impact**:
- Service degradation during peak hours or attacks
- Failed legitimate requests during DoS
- Account takeover via credential stuffing
- Increased infrastructure costs

**Recommendation**:
- Define rate limiting policy per endpoint category:
  - Authentication endpoints: 5 requests/minute per IP
  - Order creation: 10 requests/minute per user
  - Public endpoints (menu browsing): 100 requests/minute per IP
  - Admin endpoints: 50 requests/minute per user
- Specify rate limit headers in responses:
  ```
  X-RateLimit-Limit: 10
  X-RateLimit-Remaining: 7
  X-RateLimit-Reset: 1612345678
  ```
- Document escalating penalties for repeated violations (temporary IP blocking)

**Reference**: Section 3 (Architecture Design) - API Gateway component

---

### 5. Missing Audit Logging Design

**Criterion**: Data Protection & Compliance
**Score**: 2 (Significant)

**Issue**: The logging policy specifies access logs (user ID, request path, status, processing time) but does not define audit logging for security-critical events:
- Authentication events (login, logout, failed attempts)
- Authorization failures (permission denied)
- Data access (viewing order history, payment details)
- Administrative actions (user suspension, dispute resolution)
- Data modification (order cancellation, refund processing)

**Risk**: Without comprehensive audit logs:
- Security incidents cannot be investigated effectively
- Compliance requirements (PCI DSS, GDPR) may not be met
- Insider threats cannot be detected
- Forensic analysis is impossible after breach

**Impact**:
- Regulatory fines for non-compliance
- Inability to prove security controls during audits
- Extended incident response time
- Legal liability in disputes

**Recommendation**:
- Design audit logging policy including:
  - **Events to log**: Authentication attempts, authorization failures, data access (order/payment views), data modifications, admin actions
  - **Log fields**: Timestamp, user ID, action type, resource ID, result (success/failure), source IP, user agent
  - **PII masking**: Mask sensitive data (card numbers, passwords) in logs
  - **Log retention**: 90 days for operational logs, 1 year for audit logs (compliance requirement)
  - **Log protection**: Write-once storage, access control restricted to security team
- Add audit_logs table to data model or use centralized logging service (CloudWatch Logs)
- Document compliance mapping (GDPR Article 30, PCI DSS Requirement 10)

**Reference**: Section 6 (Implementation) - Logging policy

---

### 6. Missing Input Validation Policy

**Criterion**: Input Validation Design
**Score**: 2 (Significant)

**Issue**: The design does not specify input validation rules for critical fields:
- Email format validation
- Password complexity requirements (minimum length, character types)
- Phone number format validation
- Address validation (maximum length, allowed characters)
- Numeric field bounds (order amount, quantity limits)
- File upload restrictions (menu photos)

**Risk**: Missing input validation enables:
- SQL injection via unvalidated string inputs
- Command injection via delivery address fields
- Buffer overflow via oversized inputs
- Business logic bypass (negative order amounts)

**Impact**:
- Data breach via SQL injection
- System compromise via command injection
- Financial loss from negative amount exploits
- Service disruption from malformed data

**Recommendation**:
- Define input validation policy in Section 7 (Security Requirements):
  - **Email**: RFC 5322 compliant, max 255 chars
  - **Password**: Min 12 chars, require uppercase, lowercase, digit, special char
  - **Phone**: E.164 format validation
  - **Address**: Max 500 chars, alphanumeric + common punctuation only
  - **Amount**: Positive decimal, max 999999.99
  - **Files**: Max 5MB, allowed types (JPEG, PNG), virus scanning
- Specify validation layer: API Gateway (basic format) + Service layer (business rules)
- Document output escaping strategy for HTML rendering (if any)

**Reference**: Section 5 (API Design) - All endpoints; Section 7 (Security Requirements)

---

### 7. Missing Authorization Model Specification

**Criterion**: Authentication & Authorization Design
**Score**: 2 (Significant)

**Issue**: The design defines user roles (CUSTOMER, RESTAURANT, DRIVER, ADMIN) but does not specify:
- Permission model (what each role can access)
- Authorization checks at API endpoints
- Resource ownership validation (can user access other user's orders?)
- Admin privilege escalation controls

**Risk**: Without explicit authorization design:
- Horizontal privilege escalation (user A accesses user B's orders)
- Vertical privilege escalation (customer gains admin access)
- Insufficient access control testing
- Inconsistent permission enforcement across services

**Impact**:
- Unauthorized data access (orders, payment info, personal data)
- Privacy violations and GDPR non-compliance
- Account takeover
- Financial fraud

**Recommendation**:
- Document authorization matrix in Section 5 (API Design):
  ```
  | Endpoint | CUSTOMER | RESTAURANT | DRIVER | ADMIN |
  |----------|----------|------------|--------|-------|
  | GET /api/v1/orders | Own only | Own restaurant | Assigned only | All |
  | POST /api/v1/orders | Yes | No | No | Yes |
  | PATCH /api/v1/orders/{id}/status | No | Own restaurant | Assigned only | Yes |
  | GET /api/v1/payments | Own only | Own restaurant | No | All |
  ```
- Specify resource ownership validation:
  - Extract user ID from JWT token
  - Validate customer_id matches authenticated user for order access
  - Validate restaurant_id matches user's restaurant for restaurant operations
- Implement Spring Security method-level authorization with @PreAuthorize annotations
- Add authorization failure audit logging

**Reference**: Section 4 (Data Model) - Users table; Section 5 (API Design)

---

## Moderate Issues (Score: 3)

### 8. Missing Session Management Policy

**Criterion**: Authentication & Authorization Design
**Score**: 3 (Moderate)

**Issue**: The design specifies JWT token expiration (24h access, 30d refresh) but does not address:
- Token revocation mechanism (logout, password change, admin suspension)
- Concurrent session limits
- Token refresh security (refresh token rotation)
- Session timeout on inactivity

**Risk**: Without token revocation, compromised tokens remain valid until expiration, allowing attackers to maintain access even after password change or account suspension.

**Impact**:
- Extended window of compromise (up to 30 days)
- Inability to force logout on security events
- Compliance issues (users cannot "revoke consent")

**Recommendation**:
- Implement token revocation using Redis:
  - Store revoked token IDs in Redis with TTL matching token expiration
  - Check token against revocation list on each request
- Implement refresh token rotation:
  - Issue new refresh token on each refresh operation
  - Invalidate old refresh token immediately
- Add concurrent session limit (e.g., max 3 devices per user)
- Document session management in Section 5 (API Design):
  ```
  POST /api/v1/auth/logout
    Headers: Authorization: Bearer <token>
    Response: { message: "Logged out successfully" }
  ```

**Reference**: Section 5 (API Design) - Authentication subsection

---

### 9. Missing Data Retention and Deletion Policy

**Criterion**: Data Protection
**Score**: 3 (Moderate)

**Issue**: The design does not specify data retention periods or deletion procedures for:
- User account deletion (GDPR "right to be forgotten")
- Order history retention (how long to keep completed orders)
- Payment data retention (PCI DSS requirement: delete after authorization)
- Audit log retention (specified but not enforced in data model)

**Risk**: Indefinite data retention violates GDPR and increases breach impact. Failure to delete payment data violates PCI DSS.

**Impact**:
- GDPR fines (up to 4% of annual revenue)
- PCI DSS non-compliance and potential loss of payment processing ability
- Increased liability in data breaches
- User privacy violations

**Recommendation**:
- Define data retention policy in Section 7 (Security Requirements):
  - **User accounts**: Soft delete with 30-day grace period, then permanent deletion
  - **Order history**: Retain for 7 years (tax/legal requirement), then archive or delete
  - **Payment details**: Delete card_last4 after 90 days; retain transaction_id indefinitely for dispute resolution
  - **Audit logs**: Retain for 1 year, then archive to cold storage
- Implement scheduled deletion jobs (cron or AWS Lambda)
- Add deleted_at timestamp to Users, Orders, Payments tables (soft delete pattern)
- Document user account deletion API endpoint:
  ```
  DELETE /api/v1/users/me
    Headers: Authorization: Bearer <token>
    Response: { message: "Account deletion scheduled" }
  ```

**Reference**: Section 4 (Data Model); Section 7 (Security Requirements)

---

### 10. Missing Encryption at Rest Specification

**Criterion**: Data Protection
**Score**: 3 (Moderate)

**Issue**: The design states "すべての通信は HTTPS で暗号化" (all communication encrypted via HTTPS) for data in transit, but does not specify encryption at rest for:
- PostgreSQL database (RDS encryption)
- Redis cache (ElastiCache encryption)
- S3 storage (server-side encryption)
- Backups

**Risk**: If storage is compromised (snapshot leak, stolen disk, insider threat), sensitive data (passwords, payment info, personal addresses) is exposed in plaintext.

**Impact**:
- Data breach via storage compromise
- Compliance violations (GDPR, PCI DSS)
- Reputational damage

**Recommendation**:
- Specify encryption at rest in Section 7 (Security Requirements):
  - **PostgreSQL (RDS)**: Enable encryption at rest using AWS KMS-managed keys
  - **Redis (ElastiCache)**: Enable encryption at rest + in-transit encryption
  - **S3**: Enable default bucket encryption (AES-256 or KMS)
  - **Backups**: Encrypted backups for RDS (automatic when RDS encryption enabled)
- Add sensitive column-level encryption for highly sensitive data (optional):
  - Encrypt card_last4, phone, delivery_address using application-level encryption
- Document key rotation schedule (e.g., KMS keys rotated annually)

**Reference**: Section 2 (Technology Stack); Section 6 (Deployment); Section 7 (Security Requirements)

---

### 11. Missing Error Handling Security Specification

**Criterion**: Input Validation & Error Handling Design
**Score**: 3 (Moderate)

**Issue**: The error handling policy states "内部エラー詳細（スタックトレース等）はログに記録" (internal error details logged) but does not specify:
- What information is safe to return to clients
- How to prevent information disclosure via error messages
- Standardized error response format
- Error message localization and generic error codes

**Risk**: Detailed error messages can leak sensitive information:
- Database schema details (SQL errors)
- File paths (file not found errors)
- Internal service names and versions
- User enumeration (different errors for "user not found" vs "wrong password")

**Impact**:
- Information disclosure aids attackers in reconnaissance
- User enumeration enables targeted attacks
- Stack traces reveal internal architecture

**Recommendation**:
- Specify error response format in Section 6 (Error Handling):
  ```
  {
    "error": {
      "code": "ORDER_NOT_FOUND",
      "message": "The requested resource could not be found",
      "requestId": "uuid"
    }
  }
  ```
- Define safe error categories:
  - Authentication failures: Generic "Invalid credentials" (no user enumeration)
  - Authorization failures: "Access denied"
  - Validation errors: Field-level errors with generic messages
  - Server errors: "Internal server error" + request ID for support
- Never expose in client responses:
  - Stack traces
  - SQL query details
  - Internal service names
  - File paths or environment variables
- Implement user enumeration protection:
  - Return same error for "user not found" and "wrong password"
  - Constant-time comparison for password verification

**Reference**: Section 6 (Implementation) - Error Handling subsection

---

### 12. Missing Dependency Security Policy

**Criterion**: Infrastructure & Dependency Security
**Score**: 3 (Moderate)

**Issue**: The design lists major dependencies (Spring Boot 3.1, Spring Security 6.1, Hibernate 6.2, Jackson 2.15) but does not specify:
- Dependency vulnerability scanning process
- Dependency update policy
- Third-party library approval process
- SBOM (Software Bill of Materials) generation

**Risk**: Known vulnerabilities in dependencies can be exploited if not monitored and patched promptly.

**Impact**:
- Remote code execution via vulnerable libraries
- Data breach via deserialization attacks (Jackson vulnerabilities)
- Privilege escalation via Spring Security vulnerabilities

**Recommendation**:
- Define dependency security policy in Section 7 (Security Requirements):
  - **Vulnerability scanning**: Run OWASP Dependency-Check or Snyk in CI/CD pipeline
  - **Critical vulnerability SLA**: Patch within 7 days of disclosure
  - **Update cadence**: Review dependency updates quarterly; security patches immediately
  - **Approval process**: Require security review for new third-party libraries
- Generate SBOM using CycloneDX or SPDX format
- Document monitoring tools:
  - GitHub Dependabot for automatic PR creation
  - Snyk or Sonatype for real-time monitoring
- Exclude transitive dependencies with known vulnerabilities

**Reference**: Section 2 (Technology Stack); Section 6 (Deployment)

---

## Infrastructure Security Assessment

| Component | Configuration | Security Measure | Status | Risk Level | Recommendation |
|-----------|---------------|------------------|--------|------------|----------------|
| **PostgreSQL (RDS)** | Multi-AZ, Read Replica | Encryption at rest, backup strategy | Missing | High | Enable RDS encryption at rest (KMS). Document backup retention (30 days) and test restore procedures. Implement connection encryption (SSL/TLS). Restrict security group to backend services only. |
| **Redis (ElastiCache)** | Session/cache storage | Encryption at rest/in-transit, authentication | Missing | High | Enable ElastiCache encryption at rest and in-transit. Enable Redis AUTH with strong password stored in Secrets Manager. Isolate in private subnet with restrictive security group. |
| **S3 + CloudFront** | Static file storage | Bucket policies, encryption, access logging | Partial | Medium | Enable S3 default encryption (AES-256). Block public access at bucket level. Use CloudFront signed URLs for sensitive files. Enable S3 access logging and CloudTrail. Implement CORS policy. |
| **API Gateway** | Routing, rate limiting | Authentication, rate limiting, CORS, WAF | Partial | High | Document rate limiting thresholds (see Issue #4). Enable AWS WAF with OWASP Top 10 rules. Configure CORS policy (allowed origins, methods, headers). Enable request/response logging. |
| **Secrets Management** | Database credentials, API keys | Rotation, access control, encryption | Missing | Critical | Use AWS Secrets Manager for all secrets (DB passwords, API keys, JWT signing key). Enable automatic rotation for RDS credentials (30 days). Restrict IAM access to services only. Never commit secrets to version control. |
| **ECS Fargate** | Container execution | Task role permissions, network isolation | Partial | Medium | Implement least-privilege IAM task roles per service. Run containers in private subnets. Disable task metadata endpoint v1 (use v2 only). Enable container image scanning (ECR). Use read-only root filesystem where possible. |
| **Dependencies** | Spring Boot, Spring Security, Hibernate, Jackson | Version management, vulnerability scanning | Missing | High | Implement dependency vulnerability scanning (OWASP Dependency-Check, Snyk). Document patching SLA. See Issue #12 for full policy. |

---

## Minor Improvements (Score: 4)

### 13. Add Security Headers Specification

**Issue**: The design does not specify HTTP security headers (Content-Security-Policy, X-Frame-Options, Strict-Transport-Security).

**Recommendation**: Document security headers in API Gateway configuration:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Content-Security-Policy: default-src 'self'
```

---

### 14. Add Monitoring and Alerting for Security Events

**Issue**: The design specifies performance monitoring but not security event monitoring (failed login attempts, authorization failures, unusual order patterns).

**Recommendation**: Define security alerting thresholds:
- 5+ failed login attempts from single IP in 5 minutes
- 10+ authorization failures from single user in 1 minute
- Orders exceeding $10,000 (fraud detection)
- API rate limit violations

Integrate with AWS CloudWatch Alarms and SNS for notifications.

---

## Positive Aspects

1. **HTTPS Enforcement**: All communication encrypted via HTTPS (Section 7).
2. **Password Hashing**: bcrypt specified for password storage (Section 4).
3. **JWT Authentication**: Modern token-based authentication (Section 5).
4. **Multi-AZ Database**: High availability configuration for RDS (Section 6).
5. **Blue/Green Deployment**: Zero-downtime deployment strategy (Section 6).

---

## Summary Scores by Criterion

| Criterion | Score | Rationale |
|-----------|-------|-----------|
| **Threat Modeling (STRIDE)** | 2 | Multiple missing countermeasures: CSRF (Tampering/Elevation of Privilege), no audit logging (Repudiation), no idempotency (Tampering), no rate limiting (DoS). |
| **Authentication & Authorization Design** | 1 | Critical: Missing token storage specification, missing CSRF protection, missing authorization model, missing session revocation. |
| **Data Protection** | 2 | Significant: Missing encryption at rest specification, missing data retention policy, missing PII handling in logs. |
| **Input Validation Design** | 2 | Significant: Missing input validation policy, missing file upload security, missing output escaping strategy. |
| **Infrastructure & Dependency Security** | 2 | Significant: Missing secrets management design, missing dependency vulnerability scanning, partial infrastructure security specifications. |

**Overall Assessment**: The design requires substantial security improvements across all evaluation criteria. Critical issues (Score 1-2) must be addressed before production deployment. The architecture foundation is reasonable, but security policies and controls are insufficiently specified.

---

## Priority Recommendations

**Immediate (Before any deployment):**
1. Specify JWT token storage mechanism (httpOnly + Secure cookies)
2. Design and implement CSRF protection
3. Design and implement idempotency guarantees for orders and payments
4. Define and implement authorization model with resource ownership validation
5. Implement secrets management using AWS Secrets Manager

**High Priority (Before production launch):**
6. Define and implement rate limiting specifications
7. Design comprehensive audit logging policy
8. Define input validation policy with specific rules per field
9. Enable encryption at rest for all storage (RDS, ElastiCache, S3)
10. Implement token revocation mechanism

**Medium Priority (Post-launch):**
11. Define data retention and deletion policy with automated enforcement
12. Implement dependency vulnerability scanning in CI/CD
13. Enhance error handling to prevent information disclosure
14. Add security headers and WAF rules
15. Implement security event monitoring and alerting
