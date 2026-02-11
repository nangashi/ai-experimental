# Security Design Review: TravelHub システム設計書

## Executive Summary

This security review identifies **critical and significant security gaps** in the TravelHub system design. The design document lacks explicit security policies, controls, and specifications across multiple domains. Most notably, there are missing authentication controls, data protection measures, input validation policies, and infrastructure security specifications.

**Overall Risk Level: HIGH** - Multiple critical issues require immediate attention before production deployment.

---

## Security Evaluation by Criterion

### 1. Threat Modeling (STRIDE) - Score: 2/5 (Significant Issue)

**Status**: The design document does not include explicit threat modeling or STRIDE analysis.

**Issues Identified**:

- **Spoofing (S)**: No explicit session management design, token refresh mechanism, or multi-factor authentication mentioned
- **Tampering (T)**: Missing integrity checks for booking data, payment transactions, and API request tampering protection
- **Repudiation (R)**: Audit logging is not specified - no mention of what events should be logged, log retention policy, or log protection mechanisms
- **Information Disclosure (I)**: No data classification policy, no encryption specifications for sensitive data at rest (e.g., passport numbers, credit card info)
- **Denial of Service (D)**: Rate limiting and throttling mechanisms are not designed for any API endpoints
- **Elevation of Privilege (E)**: RBAC is mentioned only briefly for admin APIs, but permission models, role definitions, and authorization checks are not detailed

**Impact**: Without explicit threat modeling, the system is vulnerable to common attack vectors that could lead to data breaches, service disruption, or unauthorized access.

**Recommendations**:
1. Conduct STRIDE analysis for each major component (User Service, Payment Service, Booking Service)
2. Document specific countermeasures for each identified threat
3. Create a threat model diagram showing trust boundaries and data flows
4. Define attack surface and security controls at each boundary

---

### 2. Authentication & Authorization Design - Score: 1/5 (Critical Issue)

**Status**: Multiple critical authentication and authorization controls are missing.

**Critical Issues**:

#### 2.1 Missing Session Management Design
- **Issue**: JWT validity is mentioned (24 hours), but no session invalidation mechanism, token refresh strategy, or concurrent session handling is specified
- **Impact**: Compromised tokens remain valid for 24 hours with no revocation mechanism
- **Recommendation**: Implement token refresh mechanism with short-lived access tokens (15 minutes) and longer-lived refresh tokens stored securely

#### 2.2 Insecure Token Storage
- **Issue**: "フロントエンドはlocalStorageにトークンを保存" - storing JWT in localStorage is vulnerable to XSS attacks
- **Impact**: Critical - any XSS vulnerability exposes all user tokens
- **Recommendation**: Store tokens in httpOnly, Secure, SameSite cookies instead of localStorage

#### 2.3 Missing Password Security Specifications
- **Issue**: No password complexity requirements, hashing algorithm specification, or password reset flow security measures
- **Impact**: Weak passwords and insecure password reset flows could allow account takeover
- **Recommendation**:
  - Specify password requirements (minimum 12 characters, complexity rules)
  - Document use of bcrypt/Argon2 with appropriate cost factor
  - Design secure password reset flow with time-limited, single-use tokens
  - Implement rate limiting on login and password reset endpoints

#### 2.4 Missing OAuth/SNS Login Security Design
- **Issue**: "SNSアカウント連携" mentioned but no security design for OAuth flow, state parameter validation, or account linking security
- **Impact**: Vulnerable to CSRF attacks on OAuth callback, account hijacking via social login
- **Recommendation**:
  - Document OAuth 2.0 flow with state parameter validation
  - Design account linking security (prevent unauthorized account merging)
  - Specify which OAuth scopes are required and why

#### 2.5 Incomplete RBAC Design
- **Issue**: "管理者APIは追加でロールベースアクセス制御（RBAC）を適用" mentioned but no role definitions, permission models, or authorization check implementation strategy
- **Impact**: Privilege escalation risk if authorization is implemented inconsistently
- **Recommendation**:
  - Define all roles (User, Business User, Company Admin, System Admin)
  - Create permission matrix showing which roles can access which resources
  - Specify where authorization checks occur (API Gateway, service layer, or both)
  - Design authorization for multi-tenant scenarios (company admins should only access their company's data)

#### 2.6 Missing API Authentication for Service-to-Service Communication
- **Issue**: No mention of how backend services authenticate each other
- **Impact**: Internal services could be impersonated
- **Recommendation**: Implement service mesh with mTLS or JWT-based service authentication

---

### 3. Data Protection - Score: 1/5 (Critical Issue)

**Status**: Critical data protection measures are almost entirely missing.

**Critical Issues**:

#### 3.1 Missing Encryption Specifications
- **Issue**: "個人情報の暗号化保存" mentioned but no encryption algorithm, key management, or encryption scope specified
- **Impact**: Cannot verify that sensitive data is properly protected
- **Recommendation**:
  - Specify encryption at rest: AES-256 for database encryption, AWS KMS for key management
  - Define which fields require field-level encryption (credit card numbers, passport data, etc.)
  - Document key rotation policy

#### 3.2 Missing PII/PCI DSS Compliance Design
- **Issue**: System handles payment card information but no PCI DSS compliance measures documented
- **Impact**: Regulatory non-compliance, potential fines, loss of payment processing capability
- **Recommendation**:
  - If storing card data: Implement PCI DSS Level 1 controls (likely infeasible)
  - **Recommended**: Use Stripe tokenization to avoid storing card data entirely
  - Document PCI DSS SAQ (Self-Assessment Questionnaire) type
  - Design card data handling to minimize PCI scope

#### 3.3 Missing Data Retention and Deletion Policy
- **Issue**: No data retention period, deletion policy, or GDPR "right to be forgotten" implementation specified
- **Impact**: GDPR non-compliance, legal liability
- **Recommendation**:
  - Define retention periods for each data type (user data, booking history, payment records, logs)
  - Design data deletion workflow (hard delete vs. soft delete vs. anonymization)
  - Implement user data export and deletion APIs for GDPR compliance

#### 3.4 Missing Data Classification
- **Issue**: No classification of data sensitivity (public, internal, confidential, restricted)
- **Impact**: Cannot determine appropriate protection levels for different data types
- **Recommendation**:
  - Classify data: Public (product info), Internal (booking metadata), Confidential (PII), Restricted (payment data)
  - Apply protection measures based on classification

#### 3.5 Missing Database Security Specifications
- **Issue**: PostgreSQL mentioned but no access control, encryption, or backup security specified
- **Impact**: Database compromise could expose all user data
- **Recommendation**:
  - Enable database-level encryption (AWS RDS encryption)
  - Implement principle of least privilege for database users
  - Secure backup storage with encryption and access controls
  - Enable database audit logging

---

### 4. Input Validation Design - Score: 2/5 (Significant Issue)

**Status**: Input validation policy is almost entirely missing.

**Significant Issues**:

#### 4.1 Missing Input Validation Policy
- **Issue**: "Hibernate Validator" mentioned but no validation rules, sanitization strategy, or validation failure handling specified
- **Impact**: Vulnerable to injection attacks (SQL injection, NoSQL injection, XSS, LDAP injection)
- **Recommendation**:
  - Document validation rules for each API input field
  - Specify allow-list validation approach (validate against expected patterns, not just block known bad inputs)
  - Define server-side validation for all inputs (never rely on client-side validation alone)

#### 4.2 Missing SQL/NoSQL Injection Prevention
- **Issue**: No mention of parameterized queries, ORM security practices, or NoSQL injection prevention
- **Impact**: Critical - SQL injection could lead to complete database compromise
- **Recommendation**:
  - Mandate parameterized queries/prepared statements for all database access
  - Document ORM query security (avoid string concatenation in JPQL/HQL)
  - Specify NoSQL injection prevention for JSONB queries in PostgreSQL

#### 4.3 Missing XSS Protection
- **Issue**: No output encoding/escaping strategy specified
- **Impact**: Stored XSS in review comments, reflected XSS in search results
- **Recommendation**:
  - Implement Content Security Policy (CSP) headers
  - Use React's built-in XSS protection (ensure no use of dangerouslySetInnerHTML without sanitization)
  - Sanitize user-generated content (review comments) before storage and display

#### 4.4 Missing File Upload Security
- **Issue**: System likely handles profile images, travel documents - no file upload security design
- **Impact**: Malicious file upload could lead to RCE, stored XSS, or DoS
- **Recommendation**:
  - Validate file type (check magic bytes, not just file extension)
  - Limit file size (e.g., max 5MB for profile images)
  - Store uploaded files outside web root
  - Scan files for malware
  - Generate random filenames to prevent path traversal

#### 4.5 Missing API Input Size Limits
- **Issue**: No mention of request body size limits, array size limits, or pagination enforcement
- **Impact**: DoS via large payloads
- **Recommendation**:
  - Set request body size limit (e.g., 1MB for API requests)
  - Limit array sizes in requests (e.g., max 100 items)
  - Enforce pagination on list endpoints

---

### 5. Infrastructure & Dependency Security - Score: 2/5 (Significant Issue)

**Status**: Multiple infrastructure security specifications are missing.

| Component | Configuration | Security Measure | Status | Risk Level | Recommendation |
|-----------|---------------|------------------|--------|------------|----------------|
| PostgreSQL | Access control, encryption, backup | Not specified | Missing | Critical | Enable RDS encryption, implement least privilege access, secure backup storage |
| Redis | Network isolation, authentication | Not specified | Missing | High | Enable Redis AUTH, use VPC isolation, enable encryption in transit |
| Elasticsearch | Network isolation, authentication | Not specified | Missing | High | Enable security features (authentication, TLS), restrict network access |
| API Gateway (ALB) | Authentication, rate limiting, CORS | Partially mentioned | Partial | High | Implement rate limiting, define CORS policy, configure WAF |
| AWS Secrets Management | Rotation, access control, storage | Not specified | Missing | Critical | Use AWS Secrets Manager for all secrets, enable automatic rotation |
| Dependencies | Version management, vulnerability scanning | Not specified | Missing | High | Implement dependency scanning in CI/CD, define update policy |
| Container Security | Image scanning, runtime security | Not specified | Missing | High | Scan container images, use minimal base images, implement pod security policies |
| Network Security | VPC design, security groups, network segmentation | "VPC内に閉じる" mentioned | Partial | Medium | Define VPC architecture, security group rules, network ACLs |

**Detailed Issues**:

#### 5.1 Missing Secret Management Design
- **Issue**: No specification for how secrets (DB passwords, API keys, JWT signing keys, Stripe keys) are managed
- **Impact**: Critical - hardcoded secrets or insecure storage could expose entire system
- **Recommendation**:
  - Use AWS Secrets Manager or AWS Systems Manager Parameter Store
  - Rotate secrets automatically (at least every 90 days)
  - Implement secrets access auditing
  - Never commit secrets to git (use git-secrets or similar pre-commit hooks)

#### 5.2 Missing Dependency Security Policy
- **Issue**: No dependency vulnerability scanning, update policy, or supply chain security measures
- **Impact**: Vulnerable dependencies could be exploited (e.g., Log4Shell-type vulnerabilities)
- **Recommendation**:
  - Implement automated dependency scanning (Snyk, Dependabot, OWASP Dependency-Check)
  - Define SLA for patching critical vulnerabilities (e.g., within 7 days)
  - Lock dependency versions in package.json/pom.xml
  - Verify dependency checksums/signatures

#### 5.3 Missing Container Security
- **Issue**: Docker mentioned but no container security practices specified
- **Impact**: Vulnerable container images, container escape vulnerabilities
- **Recommendation**:
  - Scan container images for vulnerabilities
  - Use minimal base images (distroless or Alpine)
  - Run containers as non-root user
  - Implement Kubernetes Pod Security Standards

#### 5.4 Missing WAF Configuration
- **Issue**: ALB mentioned but no WAF (Web Application Firewall) configuration
- **Impact**: No protection against common web attacks (OWASP Top 10)
- **Recommendation**:
  - Deploy AWS WAF in front of ALB
  - Enable AWS Managed Rules for OWASP Top 10
  - Configure rate limiting rules
  - Block requests from known malicious IPs

---

## Additional Critical Security Issues

### 6. Missing Rate Limiting & DoS Protection - Score: 2/5 (Significant Issue)

**Issues**:
- No rate limiting specified for any API endpoint
- No brute-force protection for login/password reset endpoints
- No CAPTCHA or similar bot protection for signup/login
- No resource quotas for search queries (could be expensive if hitting external APIs)

**Impact**: System vulnerable to DoS attacks, credential stuffing, API abuse

**Recommendations**:
1. Implement rate limiting at API Gateway level:
   - Login/signup: 5 requests per 15 minutes per IP
   - Password reset: 3 requests per hour per email
   - Search APIs: 100 requests per minute per user
   - Booking APIs: 10 requests per minute per user
2. Implement CAPTCHA after failed login attempts (e.g., after 3 failures)
3. Design account lockout policy (e.g., lock account after 5 failed login attempts for 30 minutes)
4. Implement cost controls for external API calls (set maximum concurrent requests to supplier APIs)

---

### 7. Missing Audit Logging - Score: 2/5 (Significant Issue)

**Issues**:
- "すべてのAPIリクエスト/レスポンスをログ出力" mentioned, but no security event logging specified
- No audit log for sensitive operations (login, permission changes, payment transactions, data access)
- No log retention policy or log protection mechanism
- No log monitoring/alerting strategy

**Impact**: Cannot detect security incidents, insufficient forensic evidence, compliance violations

**Recommendations**:
1. Design security audit log capturing:
   - Authentication events (login success/failure, logout, token refresh)
   - Authorization failures
   - Data access (who accessed which user's data)
   - Privileged operations (admin actions, role changes)
   - Payment transactions
   - Data modifications (booking creation/cancellation, profile updates)
2. Implement log protection:
   - Store logs in tamper-proof storage (AWS CloudWatch Logs with retention lock)
   - Restrict log access (only security team and automated systems)
3. Define log retention: 90 days for application logs, 1 year for audit logs (adjust based on compliance requirements)
4. Implement security monitoring:
   - Alert on repeated failed login attempts
   - Alert on privilege escalation attempts
   - Alert on unusual data access patterns

---

### 8. Missing Idempotency Guarantees - Score: 2/5 (Significant Issue)

**Issues**:
- No idempotency design for state-changing operations (booking creation, payment processing, cancellation)
- No duplicate detection mechanism
- No idempotency key requirement for API requests
- No retry handling strategy

**Impact**: Duplicate bookings, duplicate charges, inconsistent state after network failures

**Recommendations**:
1. Implement idempotency keys:
   - Require `Idempotency-Key` header for all POST/PUT/DELETE requests
   - Store idempotency key with request hash and response in Redis (TTL 24 hours)
   - Return cached response for duplicate requests with same idempotency key
2. Design database-level duplicate prevention:
   - Add unique constraints where appropriate (e.g., booking_reference)
   - Use database transactions for multi-step operations
3. Document retry behavior:
   - Specify which operations are safe to retry
   - Implement exponential backoff for failed requests to external APIs

---

### 9. Missing CSRF Protection - Score: 3/5 (Moderate Issue)

**Issues**:
- No CSRF protection mechanism specified
- JWT in localStorage makes the application vulnerable to XSS-based token theft, but also CSRF if tokens are moved to cookies

**Impact**: If JWT storage is changed to cookies (recommended), CSRF attacks could perform unauthorized actions

**Recommendations**:
1. If moving to cookie-based authentication (recommended):
   - Implement CSRF tokens (Double Submit Cookie pattern or Synchronizer Token pattern)
   - Set `SameSite=Strict` or `SameSite=Lax` on authentication cookies
2. For state-changing operations, require additional confirmation for sensitive actions (e.g., require password re-entry for booking cancellation with refund)

---

### 10. Missing Error Handling Security - Score: 3/5 (Moderate Issue)

**Issues**:
- "ユーザー向けエラーメッセージとログ出力を分離" is good, but no examples of what information should/should not be exposed
- No specification of how to handle errors from external services (supplier APIs, payment gateway)
- No mention of avoiding timing attacks in authentication

**Impact**: Information leakage via error messages, timing attacks to enumerate valid accounts

**Recommendations**:
1. Define error message policy:
   - Never expose stack traces, SQL queries, or internal paths to users
   - Return generic messages for authentication failures ("Invalid credentials" not "Invalid password" or "User not found")
   - Avoid detailed validation errors that leak schema information
2. Implement timing-safe comparisons for authentication
3. Design error handling for external service failures:
   - Don't expose third-party API errors to users
   - Implement circuit breaker pattern for supplier API calls

---

## Positive Security Aspects

Despite the critical issues identified above, the design includes some positive security foundations:

1. **HTTPS Everywhere**: All communication uses HTTPS encryption
2. **VPC Network Isolation**: Database connections isolated within VPC
3. **JWT for Stateless Authentication**: Modern authentication approach (though implementation details need improvement)
4. **Separation of Concerns**: Microservices architecture allows for better security boundaries
5. **Cloud-Native Architecture**: Using AWS managed services provides baseline security features

---

## Summary of Scores

| Criterion | Score | Risk Level |
|-----------|-------|------------|
| 1. Threat Modeling (STRIDE) | 2/5 | Significant |
| 2. Authentication & Authorization Design | 1/5 | **Critical** |
| 3. Data Protection | 1/5 | **Critical** |
| 4. Input Validation Design | 2/5 | Significant |
| 5. Infrastructure & Dependency Security | 2/5 | Significant |
| 6. Rate Limiting & DoS Protection | 2/5 | Significant |
| 7. Audit Logging | 2/5 | Significant |
| 8. Idempotency Guarantees | 2/5 | Significant |
| 9. CSRF Protection | 3/5 | Moderate |
| 10. Error Handling Security | 3/5 | Moderate |

**Overall Security Posture: 1.8/5 (Critical Issues Present)**

---

## Priority Action Items

### Immediate (Before Any Development)

1. **Fix JWT Storage**: Move from localStorage to httpOnly cookies
2. **Design Secret Management**: Implement AWS Secrets Manager for all secrets
3. **Define Authentication Security**: Password policies, token refresh, session management
4. **Design PCI Compliance Strategy**: Use Stripe tokenization to avoid storing card data
5. **Document Input Validation Rules**: Define validation policy for all API inputs

### High Priority (Before Production)

6. **Implement Rate Limiting**: Add rate limits to all APIs, especially authentication endpoints
7. **Design Audit Logging**: Log all security-relevant events
8. **Implement Idempotency**: Add idempotency keys for state-changing operations
9. **Configure Infrastructure Security**: Secure PostgreSQL, Redis, Elasticsearch with authentication and encryption
10. **Define Data Retention Policy**: Implement GDPR compliance measures

### Medium Priority (First Production Release)

11. **Conduct Threat Modeling**: Perform STRIDE analysis for all components
12. **Implement WAF**: Deploy AWS WAF with OWASP rules
13. **Design Authorization Model**: Define RBAC roles and permissions comprehensively
14. **Implement Dependency Scanning**: Add automated vulnerability scanning to CI/CD
15. **Define Monitoring & Alerting**: Set up security event monitoring

---

## Conclusion

The TravelHub system design document provides a good technical foundation but has **critical security gaps** that must be addressed before development begins. The most significant risks are:

1. **Authentication vulnerabilities** (insecure token storage, missing session management)
2. **Data protection gaps** (no encryption specifications, no PCI compliance design)
3. **Missing security controls** (no rate limiting, no audit logging, no input validation policy)

**Recommendation**: Conduct a thorough security design review with a security architect before proceeding to implementation. The issues identified are design-level concerns that are much easier to address now than after code is written.
