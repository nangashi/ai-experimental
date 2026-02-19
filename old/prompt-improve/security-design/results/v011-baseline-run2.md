# Security Design Review: TravelHub System

## Executive Summary

This security evaluation identifies **critical gaps** in the TravelHub design document, particularly in authentication security, data protection, and input validation policies. The design lacks explicit security specifications that are essential for a payment-processing travel platform handling sensitive personal and financial data.

**Overall Risk Level: HIGH** - Multiple critical and significant security issues require immediate attention before implementation.

---

## Evaluation Scores

| Criterion | Score | Severity |
|-----------|-------|----------|
| **Threat Modeling (STRIDE)** | 2 | Significant |
| **Authentication & Authorization** | 2 | Significant |
| **Data Protection** | 2 | Significant |
| **Input Validation Design** | 1 | Critical |
| **Infrastructure & Dependency Security** | 2 | Significant |

---

## Critical Issues (Score 1)

### C1. Missing Input Validation Policy and Injection Prevention Design

**Location**: Section 5 (API Design), Section 6 (Implementation)

**Issue Description**:
The design document mentions "Hibernate Validator" in the tech stack but provides **no input validation policy** or injection prevention strategy. For a travel booking platform handling user-generated content (search queries, personal information, review comments), the absence of a validation policy is a critical security gap.

**Missing Elements**:
- No SQL injection prevention strategy despite direct database queries
- No XSS prevention policy for review comments (stored in TEXT field)
- No sanitization rules for user inputs (name, phone, comment fields)
- No file upload validation (if profile pictures or documents are supported)
- No API parameter validation rules (e.g., date range limits, amount limits)
- No output escaping policy for displaying user-generated content
- No validation for external supplier API responses

**Attack Scenarios**:
1. **SQL Injection**: Attacker submits malicious booking_reference or email in search queries
2. **Stored XSS**: Attacker injects script tags in review comments, executed when other users view reviews
3. **NoSQL Injection**: JSONB field `booking_details` vulnerable to injection if not validated
4. **Command Injection**: If system interacts with external commands (e.g., PDF generation), unvalidated input could execute arbitrary commands

**Impact**:
- Data breach through SQL injection
- Session hijacking through XSS
- Defacement of review pages
- Unauthorized data access

**Recommendation**:
```markdown
## Input Validation Policy

### General Validation Rules
- All user inputs MUST be validated on the server side before processing
- Use allowlist validation (define what is allowed) rather than blocklist
- Validate data type, format, length, and range for all fields

### Specific Validation Rules
1. **Email**: RFC 5322 format validation, max 255 chars
2. **Password**: Min 12 chars, must include uppercase, lowercase, number, special char
3. **Name fields**: Alphanumeric + spaces/hyphens only, max 100 chars
4. **Phone**: E.164 format, max 20 chars
5. **Amount**: Positive decimal, max 2 decimal places, max value 999999.99
6. **Dates**: ISO 8601 format, range validation (not in past for bookings)
7. **Review comments**: Max 2000 chars, HTML tag stripping, profanity filter
8. **JSONB fields**: Schema validation against predefined structure

### Injection Prevention
- **SQL Injection**: Use parameterized queries (PreparedStatement) for all database operations
- **XSS Prevention**:
  - HTML-encode all user-generated content before display
  - Implement Content Security Policy (CSP) headers
  - Use React's built-in XSS protection (avoid dangerouslySetInnerHTML)
- **NoSQL Injection**: Validate JSONB fields against strict JSON schema before insertion

### Output Encoding
- HTML context: Use HTML entity encoding
- JavaScript context: Use JavaScript encoding
- URL context: Use URL encoding
- JSON context: Use JSON encoding
```

**Priority**: CRITICAL - Must be implemented before beta release

---

## Significant Issues (Score 2)

### S1. Insecure JWT Token Storage and Missing Token Security Specifications

**Location**: Section 5 (認証・認可方式)

**Issue Description**:
The design specifies storing JWT tokens in localStorage, which is vulnerable to XSS attacks. Additionally, critical JWT security specifications are missing.

**Security Problems**:
1. **localStorage Vulnerability**: If XSS occurs (see C1), attacker can steal tokens via `localStorage.getItem()`
2. **No Token Expiration Strategy**: "24 hours validity" mentioned but no refresh token mechanism
3. **No Token Rotation**: Long-lived tokens increase risk if compromised
4. **No Token Revocation Design**: No mechanism to invalidate tokens on password change or logout from all devices
5. **No HTTPS-only Enforcement**: Document mentions HTTPS but no cookie security attributes specified
6. **No JWT Signature Algorithm Specification**: Missing algorithm (RS256 vs HS256) and key management details

**Missing Specifications**:
- Token signing algorithm (recommend RS256 with key rotation)
- Token payload structure (claims to include: user_id, role, issued_at, expires_at)
- Refresh token mechanism (short-lived access tokens + longer-lived refresh tokens)
- Token revocation strategy (blacklist or token versioning in database)
- Session timeout policy (absolute timeout vs idle timeout)

**Recommendation**:
```markdown
## JWT Token Security Specifications

### Token Storage
- **Access Token**: Store in httpOnly, secure, SameSite=Strict cookies (NOT localStorage)
- **Refresh Token**: Store in httpOnly, secure, SameSite=Strict cookies with separate path

### Token Lifecycle
- **Access Token**: 15-minute expiration
- **Refresh Token**: 7-day expiration
- **Token Rotation**: Issue new refresh token on each refresh operation
- **Signature Algorithm**: RS256 with 2048-bit keys
- **Key Rotation**: Rotate signing keys every 90 days

### Token Revocation
- Store token version in users table
- Increment version on password change or explicit logout
- Validate token version on each request
- Implement token blacklist (Redis) for immediate revocation

### JWT Claims Structure
{
  "sub": "user_id",
  "email": "user@example.com",
  "role": "user|admin",
  "token_version": 1,
  "iat": 1234567890,
  "exp": 1234568790
}
```

**Priority**: SIGNIFICANT - Must be implemented before production launch

---

### S2. Missing Data Protection Specifications for Sensitive Information

**Location**: Section 4 (Data Model), Section 7 (Security Requirements)

**Issue Description**:
The design mentions "個人情報の暗号化保存" (encryption of personal information) but provides **no specifics** on what data to encrypt, encryption algorithms, or key management.

**Missing Specifications**:
1. **Encryption at Rest**: Which fields to encrypt (password_hash only? phone? payment details in JSONB?)
2. **Encryption Algorithm**: No specification (AES-256? Field-level encryption library?)
3. **Key Management**: No key storage strategy (AWS KMS? HashiCorp Vault?)
4. **Data Masking**: No policy for displaying sensitive data (e.g., show last 4 digits of credit card)
5. **Data Retention**: No policy for deleting user data after account deletion
6. **Backup Encryption**: No mention of backup encryption policy
7. **PII Identification**: No clear definition of what constitutes PII in this system

**Data at Risk**:
- `users.password_hash`: Hashing algorithm not specified (bcrypt? Argon2?)
- `users.phone`: Stored in plaintext, vulnerable if database compromised
- `payments.stripe_payment_id`: Sensitive financial data, no encryption specified
- `bookings.booking_details` (JSONB): May contain passport numbers, credit card info - no encryption specified

**Recommendation**:
```markdown
## Data Protection Specifications

### Encryption at Rest
- **Password Storage**: Argon2id with salt (not just hash), cost parameter: 4
- **Phone Numbers**: AES-256-GCM encryption using AWS KMS Data Keys
- **Payment Details**: Never store full credit card numbers; store Stripe tokens only
- **JSONB Fields**: Encrypt PII fields within JSONB using application-level encryption before insertion

### Key Management
- Use AWS KMS for master key storage
- Implement envelope encryption: data encryption keys (DEK) encrypted with KMS master key
- Rotate DEKs every 90 days
- Store encrypted DEKs in database alongside encrypted data

### Data Retention Policy
- Delete user data 30 days after account deletion request
- Retain transaction logs for 7 years (compliance requirement)
- Anonymize old booking data after 2 years (remove PII, keep aggregated data)

### Data Masking Rules
- Email: show first 2 chars + "***" + domain (e.g., "us***@example.com")
- Phone: show last 4 digits (e.g., "***-***-1234")
- Payment: show last 4 digits of card (e.g., "**** **** **** 1234")
```

**Priority**: SIGNIFICANT - Must be implemented before handling production user data

---

### S3. Missing Rate Limiting and DoS Protection Design

**Location**: Section 5 (API Design), Section 7 (Performance)

**Issue Description**:
The design specifies "検索API: 1000req/sec" performance target but provides **no rate limiting strategy** to prevent abuse. For a public-facing API, this is a significant security and operational risk.

**Missing Elements**:
- No rate limiting per user/IP address
- No brute-force protection for login endpoint
- No CAPTCHA or similar challenge-response mechanism
- No API abuse detection (e.g., scraping detection)
- No cost-based rate limiting (expensive operations like search should have lower limits)
- No distributed rate limiting strategy (for Kubernetes multi-pod deployment)

**Attack Scenarios**:
1. **Credential Stuffing**: Attacker tries thousands of email/password combinations on `/api/auth/login`
2. **API Scraping**: Competitor scrapes flight/hotel prices by flooding search endpoints
3. **Resource Exhaustion**: Attacker sends expensive search queries to exhaust database connections
4. **Reservation Hoarding**: Bots create fake reservations to block real users from booking

**Recommendation**:
```markdown
## Rate Limiting Policy

### Per-Endpoint Limits (using Redis-based distributed rate limiter)

| Endpoint | Authenticated | Unauthenticated | Window |
|----------|---------------|-----------------|--------|
| POST /api/auth/login | N/A | 5 attempts / 15 min / IP | Sliding |
| POST /api/auth/signup | N/A | 3 attempts / hour / IP | Fixed |
| GET /api/search/* | 60 req/min | 20 req/min / IP | Sliding |
| POST /api/bookings | 10 req/min | N/A | Sliding |
| POST /api/payments | 5 req/min | N/A | Sliding |
| POST /api/reviews | 5 req/hour | N/A | Fixed |

### Brute-Force Protection
- Implement progressive delays after failed login attempts (1s, 5s, 30s, 5min)
- Temporary account lock after 10 failed attempts (15-minute cooldown)
- Email notification to user on 5+ failed login attempts
- CAPTCHA challenge after 3 failed attempts

### DoS Mitigation
- Implement request queue with max size (reject requests when queue full)
- Use AWS WAF for Layer 7 DDoS protection
- Set per-user max concurrent requests limit (5 concurrent)
- Implement circuit breaker for external supplier APIs (fail fast when supplier is down)
```

**Priority**: SIGNIFICANT - Must be implemented before public beta

---

### S4. Missing Authorization Model and Permission Design

**Location**: Section 5 (認証・認可方式)

**Issue Description**:
The design mentions "管理者APIは追加でロールベースアクセス制御（RBAC）を適用" but provides **no details** on the authorization model, roles, or permission checks.

**Missing Specifications**:
1. **Role Definitions**: What roles exist? (user, admin, business_admin, support?)
2. **Permission Mapping**: What permissions does each role have?
3. **Resource-Level Authorization**: How to check "user can only view their own bookings"?
4. **Multi-Tenant Authorization**: How do business accounts isolate their data?
5. **Permission Check Implementation**: Where to implement checks (controller? service? aspect?)
6. **Privilege Escalation Prevention**: How to prevent users from changing their own roles?

**Vulnerable Scenarios**:
- User A can access User B's booking by guessing UUID in `GET /api/bookings/:id`
- Regular user can access admin endpoints by manipulating JWT payload
- Business user can view other companies' employee travel data
- User can modify booking after it's confirmed (no state transition validation)

**Recommendation**:
```markdown
## Authorization Model

### Role Definitions
- **USER**: Regular customer (can manage own bookings)
- **BUSINESS_USER**: Company employee (can manage own bookings, view company policy)
- **BUSINESS_ADMIN**: Company administrator (can view all employee bookings, manage budget)
- **SUPPORT**: Customer support staff (read-only access to user bookings)
- **ADMIN**: System administrator (full access)

### Permission Matrix

| Resource | USER | BUSINESS_USER | BUSINESS_ADMIN | SUPPORT | ADMIN |
|----------|------|---------------|----------------|---------|-------|
| Own bookings (CRUD) | ✓ | ✓ | ✓ | R only | ✓ |
| Other user bookings | ✗ | ✗ | ✓ (same company) | R only | ✓ |
| User profile | Own only | Own only | Own only | R only | ✓ |
| Reviews | CRUD own | CRUD own | CRUD own | R only | ✓ |
| Admin endpoints | ✗ | ✗ | ✗ | ✗ | ✓ |

### Implementation Strategy
1. **Controller-Level**: Use @PreAuthorize annotation for role checks
2. **Service-Level**: Implement resource ownership checks before operations
3. **Example**:
   ```java
   // Controller
   @PreAuthorize("hasRole('USER')")
   @GetMapping("/api/bookings/{id}")
   public BookingDTO getBooking(@PathVariable UUID id, Authentication auth) {
       return bookingService.getBooking(id, auth.getUserId());
   }

   // Service
   public BookingDTO getBooking(UUID bookingId, UUID requesterId) {
       Booking booking = repository.findById(bookingId)
           .orElseThrow(() -> new NotFoundException("Booking not found"));

       // Authorization check
       if (!booking.getUserId().equals(requesterId) && !hasAdminRole(requesterId)) {
           throw new ForbiddenException("Access denied");
       }

       return toDTO(booking);
   }
   ```

### State Transition Authorization
- PENDING → CONFIRMED: Only Payment Service (after successful payment)
- CONFIRMED → CANCELLED: Only booking owner or admin
- CANCELLED → CONFIRMED: Not allowed (create new booking instead)
```

**Priority**: SIGNIFICANT - Must be implemented to prevent unauthorized data access

---

### S5. Missing Audit Logging and Security Event Monitoring

**Location**: Section 6 (Logging Policy)

**Issue Description**:
The logging policy covers general application logging but **lacks security-specific audit logging requirements**. For a payment platform, audit logs are essential for forensics and compliance.

**Missing Elements**:
- No security event logging (login attempts, permission denials, data access)
- No audit trail for sensitive operations (booking cancellation, refunds)
- No log retention policy for security logs
- No log integrity protection (prevent log tampering)
- No real-time alerting for security events

**Recommendation**:
```markdown
## Security Audit Logging

### Events to Log
1. **Authentication Events**: Login success/failure, logout, password change, token refresh
2. **Authorization Failures**: Permission denials, resource access attempts
3. **Data Access**: View/export of sensitive data (PII, payment info)
4. **Sensitive Operations**: Booking cancellation, refund, role changes, account deletion
5. **Configuration Changes**: Security policy updates, role permission changes

### Log Format (JSON)
{
  "timestamp": "2026-02-10T12:34:56Z",
  "event_type": "LOGIN_FAILED",
  "user_id": "user-123",
  "ip_address": "192.0.2.1",
  "user_agent": "Mozilla/5.0...",
  "resource": "/api/auth/login",
  "result": "FAILURE",
  "reason": "invalid_password",
  "request_id": "req-abc-123"
}

### Log Storage and Retention
- Store security logs in separate S3 bucket with restricted access
- Retention: 1 year for security logs, 7 years for financial transaction logs
- Enable S3 Object Lock to prevent log tampering
- Real-time streaming to SIEM (e.g., AWS Security Hub)

### Alerting Rules
- 5+ failed login attempts from same IP in 5 minutes → Alert security team
- Admin role assignment → Immediate alert
- Bulk data export → Alert and require approval
- Payment refund > $10,000 → Alert finance team
```

**Priority**: SIGNIFICANT - Required for compliance and incident response

---

## Moderate Issues (Score 3)

### M1. Missing CSRF Protection Design

**Location**: Section 5 (API Design)

**Issue Description**:
The design uses JWT in Authorization header, which provides some CSRF protection. However, if tokens are stored in cookies (as recommended in S1), CSRF protection becomes necessary.

**Recommendation**:
- Implement CSRF tokens for state-changing operations (POST/PUT/DELETE)
- Use double-submit cookie pattern or synchronizer token pattern
- Set SameSite=Strict attribute on cookies

**Priority**: Moderate - Implement when switching to cookie-based token storage

---

### M2. Missing Idempotency Design for Payment Operations

**Location**: Section 5 (Payment Endpoints)

**Issue Description**:
No idempotency mechanism specified for `POST /api/payments`. Network failures could result in duplicate charges.

**Recommendation**:
```markdown
## Idempotency Design

### Payment API Idempotency
- Client must provide `Idempotency-Key` header (UUID) for POST /api/payments
- Server stores key + response in Redis (TTL: 24 hours)
- If duplicate key detected, return cached response without re-processing
- Example: `Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000`

### Implementation
- Store mapping: idempotency_key → (payment_id, status, response)
- Check key before processing payment
- Atomic operation: payment + key storage in single transaction
```

**Priority**: Moderate - Important for payment reliability but can be added incrementally

---

### M3. Missing Error Disclosure Policy

**Location**: Section 6 (Error Handling)

**Issue Description**:
The error handling policy mentions "ユーザー向けエラーメッセージとログ出力を分離" but doesn't specify what information is safe to expose to users.

**Recommendation**:
```markdown
## Error Disclosure Policy

### Information to NEVER expose to users:
- Stack traces
- Database query details
- Internal system paths
- Dependency versions
- Server hostnames

### Safe Error Messages:
- Generic: "An error occurred. Please try again later. (Error ID: ERR-12345)"
- Validation: "Email format is invalid" (but not "User does not exist")
- Authentication: "Invalid credentials" (don't distinguish between wrong email vs wrong password)

### HTTP Status Codes:
- 400: Invalid input (with field-level validation errors)
- 401: Unauthenticated (don't specify reason)
- 403: Forbidden (don't specify what permission is missing)
- 404: Not found (for both non-existent and unauthorized resources)
- 500: Internal error (log full details, show generic message to user)
```

**Priority**: Moderate - Prevent information leakage

---

## Infrastructure Security Assessment

| Component | Configuration | Security Measure | Status | Risk Level | Recommendation |
|-----------|---------------|------------------|--------|------------|----------------|
| **PostgreSQL** | Multi-AZ, VPC-isolated | Encryption at rest, access control | Partial | High | Specify encryption algorithm (AES-256), enable SSL/TLS for connections, implement row-level security (RLS) for multi-tenant data |
| **Redis** | Session/cache storage | Authentication, network isolation | Missing | High | Enable Redis AUTH, use TLS for connections, set maxmemory-policy to prevent memory exhaustion, disable dangerous commands (FLUSHALL, CONFIG) |
| **Elasticsearch** | Search index | Authentication, encryption | Missing | High | Enable X-Pack Security, use HTTPS for API calls, implement field-level access control, encrypt indices at rest |
| **AWS ALB** | API Gateway | HTTPS, WAF | Partial | Medium | Configure AWS WAF rules (SQL injection, XSS), enable access logs, set up DDoS protection (AWS Shield), implement request size limits |
| **Docker/K8s** | Container orchestration | Image scanning, secrets | Missing | High | Use private container registry, scan images for vulnerabilities (Trivy), implement Pod Security Policies, use Kubernetes Secrets (not env vars) for sensitive data |
| **Stripe SDK** | Payment processing | PCI DSS compliance | Partial | Critical | Never log full credit card numbers, use Stripe Checkout or Elements (client-side), validate webhook signatures, implement idempotency keys |
| **GitHub Actions** | CI/CD | Secrets management, OIDC | Missing | Medium | Use GitHub Secrets for credentials, enable branch protection rules, require code review before merge, use OIDC for AWS auth (no long-lived credentials) |
| **Datadog** | Monitoring | Log sanitization | Missing | Medium | Scrub sensitive data from logs before sending to Datadog, use Datadog's sensitive data scanner, restrict access to production logs |

**Critical Infrastructure Gaps**:
1. **Secrets Management**: No mention of AWS Secrets Manager or similar for database credentials, API keys, JWT signing keys
2. **Network Security Groups**: No firewall rules specified for VPC
3. **Dependency Vulnerability Scanning**: No mention of Dependabot or Snyk
4. **Container Security**: No image signing or runtime security monitoring

---

## Threat Modeling Analysis (STRIDE)

### Spoofing (Score: 2 - Significant Issue)
- **Weak Authentication**: JWT in localStorage vulnerable to XSS
- **No MFA**: High-value accounts (business admins) lack multi-factor authentication
- **Missing**: Session binding to IP/device, anomaly detection for suspicious logins

### Tampering (Score: 3 - Moderate Issue)
- **JSONB Fields**: booking_details field vulnerable to injection if not validated
- **Missing**: Integrity checks for supplier API responses, request signing for inter-service communication

### Repudiation (Score: 3 - Moderate Issue)
- **Insufficient Audit Logs**: Missing security event logging
- **Missing**: Digital signatures for bookings, non-repudiation for payment confirmations

### Information Disclosure (Score: 2 - Significant Issue)
- **No Encryption Specification**: PII stored in plaintext
- **Verbose Error Messages**: Risk of information leakage through error responses
- **Missing**: Data masking policy, backup encryption, log sanitization

### Denial of Service (Score: 2 - Significant Issue)
- **No Rate Limiting**: Vulnerable to API abuse and credential stuffing
- **Missing**: Request size limits, timeout policies, circuit breakers

### Elevation of Privilege (Score: 2 - Significant Issue)
- **Weak Authorization Model**: No resource-level permission checks specified
- **Missing**: RBAC implementation details, privilege escalation prevention

---

## Positive Aspects

1. **VPC Isolation**: Database isolated in VPC (good network segmentation)
2. **HTTPS Enforcement**: All communication over HTTPS
3. **Exception Handling**: Centralized error handling with GlobalExceptionHandler
4. **Multi-AZ Database**: Good availability design
5. **Monitoring Infrastructure**: Datadog integration for observability

---

## Summary and Prioritized Recommendations

### Immediate Action Required (Critical)
1. **[C1] Define Input Validation Policy** - Prevent SQL injection and XSS attacks
   - Estimated effort: 1 sprint
   - Owner: Backend Team Lead

### Before Production Launch (Significant)
2. **[S1] Secure JWT Token Storage** - Move to httpOnly cookies with refresh token mechanism
3. **[S2] Data Protection Specifications** - Define encryption algorithm, key management, data retention
4. **[S3] Rate Limiting and DoS Protection** - Implement per-endpoint rate limits
5. **[S4] Authorization Model** - Define roles, permissions, resource-level access control
6. **[S5] Security Audit Logging** - Implement comprehensive security event logging

### Follow-up Improvements (Moderate)
7. **[M1] CSRF Protection** - Implement when switching to cookie-based auth
8. **[M2] Payment Idempotency** - Prevent duplicate charges
9. **[M3] Error Disclosure Policy** - Prevent information leakage

### Infrastructure Hardening
10. Implement secrets management solution (AWS Secrets Manager)
11. Configure Redis authentication and TLS
12. Enable Elasticsearch security features
13. Set up dependency vulnerability scanning

---

## Conclusion

The TravelHub design document provides a solid foundation for system architecture but **lacks critical security specifications** required for a production payment platform. The most urgent gap is the **missing input validation policy (C1)**, which exposes the system to injection attacks.

Before proceeding to implementation, the development team must:
1. Define and document all missing security policies identified in this review
2. Conduct a follow-up threat modeling session with the security team
3. Establish security review checkpoints in the development process

**Recommended Next Steps**:
1. Schedule security design workshop to address critical issues
2. Update design document with security specifications
3. Conduct code review focused on input validation during implementation
4. Perform penetration testing before production launch

---

**Reviewer**: Security Design Reviewer Agent
**Review Date**: 2026-02-10
**Document Version**: test-document-round-011.md
