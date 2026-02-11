# Security Review: TravelConnect System Design - Adversarial Perspective (Run 2)

**Reviewer**: security-design-reviewer
**Variation ID**: C2b (Adversarial Perspective)
**Review Date**: 2026-02-10
**Document**: TravelConnect System Design Document

---

## Executive Summary

From an attacker's perspective, this travel booking platform presents **multiple critical exploitation paths** with high-value targets (payment data, PII, booking records). The design exhibits **severe authorization gaps**, **JWT storage vulnerabilities**, **missing input validation**, and **insufficient audit logging** that enable credential theft, privilege escalation, financial fraud, and undetected data exfiltration.

**Attacker's Recommended Entry Points** (in order of ease):
1. JWT theft via XSS → full account takeover
2. IDOR exploitation on booking endpoints → access to all user bookings
3. Credential stuffing (no rate limiting on authentication)
4. Password reset token enumeration → account takeover
5. SQL injection via unvalidated search parameters

**Overall Exploitability**: High (Score: 1.8/5.0)

---

## 1. Critical Attack Vectors (Immediate Exploitation Opportunities)

### 1.1 JWT Storage Vulnerability → XSS-Based Account Takeover
**Score**: 1/5 (Critical Exposure)

**Attack Scenario**:
1. Attacker identifies XSS vulnerability (missing CSP, no output escaping specified)
2. Injects malicious script that reads JWT from localStorage
3. Exfiltrates token to attacker-controlled server
4. Attacker uses stolen JWT (valid for 24 hours) to access victim's bookings, payment methods, and PII
5. Creates fraudulent bookings or modifies existing reservations

**Attacker Skill Required**: Script kiddie (automated XSS scanners + token theft scripts)

**Expected Impact**: Complete account compromise, financial fraud, PII exposure

**Missing Countermeasures**:
- No JWT storage security specification (localStorage vs httpOnly cookies)
- No Content Security Policy (CSP) to block malicious scripts
- No output escaping policy for user-generated content
- No XSS protection headers (X-XSS-Protection, X-Content-Type-Options)
- 24-hour token lifetime provides large exploitation window

**Design Document References**: Section 5 (Authentication and Authorization), Section 2 (Frontend: React/Next.js)

**Evidence**: "Tokens are passed in Authorization header as Bearer token" without storage security specification.

---

### 1.2 Authorization Bypass via IDOR → Mass Data Exfiltration
**Score**: 1/5 (Critical Exposure)

**Attack Scenario**:
1. Attacker creates legitimate account and makes booking
2. Captures booking ID from `GET /api/v1/bookings/{id}` response
3. Iterates through UUID space or uses sequential enumeration script
4. Discovers "Users can only access their own bookings" relies on client-side check
5. No server-side authorization validation specified for PUT/DELETE operations
6. Attacker accesses/modifies/cancels other users' bookings

**Attacker Skill Required**: Basic scripting (curl + UUID enumeration)

**Expected Impact**: Exposure of all user PII (names, passport numbers, travel itineraries, payment details), booking manipulation, financial fraud

**Missing Countermeasures**:
- No server-side authorization validation logic specified
- No audit logging for authorization failures
- No rate limiting on booking detail requests
- No anomaly detection for unusual access patterns
- UUIDs provide weak protection if generation is predictable

**Design Document References**: Section 5 (API Design - Booking Endpoints), line 169 "Users can only access their own bookings"

**Evidence**: Statement "Users can only access their own bookings" lacks implementation specification. No middleware or authorization service mentioned.

---

### 1.3 Missing Input Validation → SQL Injection
**Score**: 2/5 (High-Value Target)

**Attack Scenario**:
1. Attacker submits malicious search query to `/api/v1/search/flights?departure='OR'1'='1`
2. No input validation policy specified for search parameters
3. If parameterized queries not enforced, SQL injection succeeds
4. Attacker extracts password hashes, payment data, or booking records
5. Uses `booking_data JSONB` field to inject payloads into flexible schema

**Attacker Skill Required**: Moderate (SQL injection knowledge, automated tools like sqlmap)

**Expected Impact**: Full database compromise, credential theft, PII exfiltration

**Missing Countermeasures**:
- No input validation policy for API parameters
- Joi validation library mentioned but not applied to search endpoints
- No parameterized query enforcement
- No Web Application Firewall (WAF) rules
- No database-level query logging for anomaly detection

**Design Document References**: Section 2 (Validation: Joi 17.9.0), Section 5 (Search Endpoints)

**Evidence**: Joi library listed but no validation policy. "All API requests use JSON format" without sanitization requirements.

---

### 1.4 Credential Stuffing → Account Takeover (No Rate Limiting on Auth)
**Score**: 2/5 (High-Value Target)

**Attack Scenario**:
1. Attacker obtains leaked credential list from previous breaches
2. Targets `POST /api/v1/auth/login` with automated credential stuffing tool
3. No rate limiting specified for authentication endpoints (only "100 requests per minute for search APIs")
4. Successfully compromises accounts lacking unique passwords
5. Exfiltrates booking history, loyalty points, stored payment methods

**Attacker Skill Required**: Script kiddie (credential stuffing as a service tools)

**Expected Impact**: Mass account compromise, financial fraud, PII exposure

**Missing Countermeasures**:
- No rate limiting on authentication endpoints (`/auth/login`, `/auth/signup`)
- No account lockout policy after failed attempts
- No CAPTCHA or challenge-response for suspicious login patterns
- No multi-factor authentication (MFA) requirement
- No IP-based throttling or geolocation anomaly detection

**Design Document References**: Section 7 (Rate limiting: 100 requests per minute per user for search APIs), Section 5 (Authentication Endpoints)

**Evidence**: Rate limiting only applies to search APIs, not authentication.

---

### 1.5 Password Reset Token Enumeration → Account Takeover
**Score**: 2/5 (High-Value Target)

**Attack Scenario**:
1. Attacker initiates password reset for target email: `POST /api/v1/auth/reset-password`
2. No rate limiting on reset endpoint → can enumerate valid emails
3. Reset token "valid for 2 hours" but no token complexity/length specified
4. If token is predictable (sequential, timestamp-based), attacker brute-forces
5. Alternatively, attacker intercepts reset email (no TLS for email transport specified)
6. Completes password reset and takes over account

**Attacker Skill Required**: Moderate (token prediction or email interception)

**Expected Impact**: Targeted account takeover, email enumeration for phishing

**Missing Countermeasures**:
- No rate limiting on password reset endpoint
- No token generation specification (entropy, length, format)
- No email transport security (SMTP over TLS)
- No notification to user of password reset attempt
- No secondary verification (security questions, MFA)

**Design Document References**: Section 5 (POST /api/v1/auth/reset-password), line 128

**Evidence**: "sends email with reset link valid for 2 hours" without token security specification.

---

## 2. High-Probability Exploits

### 2.1 Session Hijacking (Weak Session Management)
**Score**: 2/5 (High-Value Target)

**Attack Scenario**:
1. Attacker performs man-in-the-middle attack on public WiFi
2. Captures JWT token from Authorization header
3. JWT has 24-hour expiration → attacker has large window
4. No session invalidation on logout (token remains valid until expiration)
5. No IP binding or device fingerprinting
6. Attacker replays token to access victim's account

**Attacker Skill Required**: Moderate (MITM tools, network sniffing)

**Expected Impact**: Account takeover, unauthorized transactions

**Missing Countermeasures**:
- No session invalidation mechanism on logout
- No token refresh strategy (short-lived access token + refresh token)
- No IP binding or device fingerprinting
- No anomaly detection for session replay from different geolocations
- Redis used for "session management" but token invalidation not specified

**Design Document References**: Section 5 (JWT 24-hour expiration), Section 2 (Redis for session management), Section 7 (Session timeout: 30 minutes)

**Evidence**: Contradiction between 24-hour JWT expiration and 30-minute inactivity timeout. No implementation specified.

---

### 2.2 Payment Idempotency Failure → Duplicate Charging
**Score**: 2/5 (High-Value Target)

**Attack Scenario**:
1. Attacker intercepts `POST /api/v1/bookings` request
2. Replays request multiple times rapidly
3. No idempotency key enforcement specified for payment processing
4. Multiple booking records created with duplicate Stripe charges
5. User charged multiple times for single booking
6. Attacker exploits for profit (book expensive flight, get refund for duplicates)

**Attacker Skill Required**: Basic (HTTP request replay tools)

**Expected Impact**: Financial fraud, user trust erosion, Stripe dispute fees

**Missing Countermeasures**:
- No idempotency key requirement for booking/payment requests
- No duplicate transaction detection
- No Stripe idempotency key usage specified
- No distributed lock for concurrent booking creation

**Design Document References**: Section 5 (POST /api/v1/bookings), Section 6 (Payment failures trigger automatic refund)

**Evidence**: Payment integration with Stripe but no idempotency mechanism.

---

### 2.3 CSRF on State-Changing Operations
**Score**: 3/5 (Moderate Vulnerability)

**Attack Scenario**:
1. Attacker crafts malicious webpage with hidden form
2. Victim visits attacker's site while logged into TravelConnect
3. Malicious JavaScript sends `DELETE /api/v1/bookings/{id}` request
4. No CSRF token validation specified
5. Victim's booking cancelled without consent
6. If JWT in localStorage, attacker can read token via XSS and perform arbitrary actions

**Attacker Skill Required**: Basic (CSRF template scripts)

**Expected Impact**: Unauthorized booking cancellation, financial loss

**Missing Countermeasures**:
- No CSRF protection (SameSite cookie attribute, CSRF tokens)
- JWT in Authorization header (not immune to CSRF if token in localStorage)
- No origin validation for state-changing operations

**Design Document References**: Section 5 (API Design)

**Evidence**: No CSRF protection mechanism specified.

---

### 2.4 Verbose Error Messages → Information Disclosure
**Score**: 3/5 (Moderate Vulnerability)

**Attack Scenario**:
1. Attacker sends malformed requests to API endpoints
2. Error responses include stack traces, database error messages, internal paths
3. Attacker learns database schema, library versions, internal architecture
4. Uses information to refine SQL injection or exploit known CVEs
5. "Database connection errors are retried up to 3 times" may leak retry logic

**Attacker Skill Required**: Basic (trial and error with malformed requests)

**Expected Impact**: Reconnaissance for targeted attacks

**Missing Countermeasures**:
- No error message sanitization policy for production
- No distinction between development and production error verbosity
- "All errors return standard JSON format with error code and message" lacks detail suppression

**Design Document References**: Section 6 (Error Handling), line 174

**Evidence**: "HTTP status codes: 400 (validation), 401 (unauthorized)..." without message content policy.

---

## 3. Attack Chains (Combined Weaknesses)

### Chain 1: XSS → JWT Theft → IDOR → Mass Data Exfiltration
**Combined Score**: 1/5 (Critical)

**Attack Path**:
1. Missing CSP + no output escaping → XSS vulnerability
2. JWT in localStorage → token theft
3. Missing authorization checks → IDOR exploitation
4. No audit logging → undetected access to all user bookings
5. Attacker exfiltrates entire database of bookings with PII

**Why This Chain Is Effective**: Each weakness amplifies the next. XSS alone is limited, but combined with JWT theft and IDOR, it enables mass compromise.

---

### Chain 2: Credential Stuffing → Weak Sessions → Privilege Escalation
**Combined Score**: 2/5 (High-Value)

**Attack Path**:
1. No auth rate limiting → successful credential stuffing
2. No role-based authorization details → attacker tests admin endpoints
3. "Role-based access control for admin endpoints" lacks implementation
4. Attacker discovers `/api/v1/admin/users` endpoint with weak authorization
5. Escalates to admin, accesses all user data

**Why This Chain Is Effective**: Weak authentication defenses lead to initial compromise; missing authorization details enable privilege escalation.

---

### Chain 3: SQL Injection → Credential Theft → Lateral Movement
**Combined Score**: 2/5 (High-Value)

**Attack Path**:
1. Missing input validation → SQL injection in search endpoint
2. Extract password hashes from users table
3. Crack weak passwords (8-character minimum is brute-forceable)
4. Access admin accounts
5. Pivot to AWS infrastructure via exposed credentials in environment variables

**Why This Chain Is Effective**: Database compromise provides credentials for lateral movement to infrastructure.

---

## 4. Infrastructure Targets (Vulnerability Assessment)

| Component | Attack Vector | Missing Protection | Exploitability | Impact | Priority Score |
|-----------|---------------|-------------------|----------------|--------|----------------|
| **PostgreSQL 15.3** | SQL injection, direct access | Input validation, network isolation | Easy | Critical | **2/5** |
| **Elasticsearch 8.9** | Unauthenticated access, data exposure | Authentication, encryption | Easy | High | **2/5** |
| **Redis 7.0** | Unprotected instance, session hijacking | Password auth, TLS | Moderate | High | **3/5** |
| **RabbitMQ** | Message queue poisoning | Authentication, message signing | Moderate | Medium | **3/5** |
| **Stripe SDK** | API key exposure, webhook validation | Secrets management, signature verification | Moderate | Critical | **2/5** |
| **CloudWatch Logs** | PII exposure in logs | Log redaction, access control | Easy | High | **3/5** |
| **ECS Containers** | Privilege escalation, secret exposure | Least privilege IAM, secret rotation | Hard | Critical | **3/5** |
| **Third-Party APIs** | Provider compromise, data leakage | Input validation, sandboxing | Moderate | High | **3/5** |

### Critical Infrastructure Findings:

#### 4.1 PostgreSQL: Direct Database Access
**Attack Vector**: If database connection string exposed, attacker gains direct access.
**Missing Protection**: No network segmentation mentioned. "Database connections encrypted with TLS" but no authentication details (password complexity, rotation).
**Exploitability**: Easy (if credentials leaked via environment variable exposure)
**Why Attack This**: Single point of failure for all user data, payment records, and bookings.

#### 4.2 Elasticsearch: Unauthenticated Search Cluster
**Attack Vector**: Elasticsearch often deployed without authentication in internal networks.
**Missing Protection**: No authentication mechanism specified. No encryption at rest.
**Exploitability**: Easy (if network segmentation missing)
**Why Attack This**: Contains all searchable flight/hotel data, potentially including cached user searches with PII.

#### 4.3 Stripe API Keys: Hardcoded or Environment Exposure
**Attack Vector**: Stripe secret keys in environment variables or committed to git.
**Missing Protection**: "Environment-specific configuration via environment variables" without secrets management (AWS Secrets Manager, Vault).
**Exploitability**: Moderate (requires source code access or container inspection)
**Why Attack This**: Full payment processing control, ability to issue refunds, access to all payment data.

#### 4.4 CloudWatch Logs: PII Leakage
**Attack Vector**: "Sensitive data (passwords, payment details, passport numbers) should be redacted in logs" uses passive voice → likely not enforced.
**Missing Protection**: No log encryption, no access control specification, "should be redacted" is a recommendation not a requirement.
**Exploitability**: Easy (if IAM misconfigured)
**Why Attack This**: Logs contain request/response data with potential PII, useful for reconnaissance.

---

## 5. Defense Gaps (Missing Controls by STRIDE Category)

### Spoofing Threats
**Missing Controls**:
- No multi-factor authentication (MFA)
- No device fingerprinting or trusted device management
- No biometric authentication for high-value operations
- Weak password policy (8-character minimum)

**Attacker Exploitation**: Credential stuffing, phishing, session hijacking all succeed due to single-factor authentication.

### Tampering Threats
**Missing Controls**:
- No message signing for inter-service communication
- No data integrity checks (HMAC) for booking records
- No webhook signature verification for Stripe callbacks
- No audit trail for data modifications

**Attacker Exploitation**: Attacker modifies booking data in transit or at rest; changes go undetected.

### Repudiation Threats
**Missing Controls**:
- No comprehensive audit logging policy
- "Request/response logging for all API calls" but no specification for:
  - User actions (booking creation, cancellation, password reset)
  - Admin actions (role changes, data access)
  - Failed authorization attempts
  - Privilege escalation attempts
- No log integrity protection (tamper-evident logging)
- No log retention policy for compliance

**Attacker Exploitation**: Attacker performs malicious actions without leaving audit trail; cannot attribute actions to specific users.

### Information Disclosure Threats
**Missing Controls**:
- No data classification policy (public, internal, confidential, restricted)
- No field-level encryption for PII (passport numbers, payment details)
- No data masking for non-production environments
- Verbose error messages leak internal details
- No secure header configuration (HSTS, X-Content-Type-Options)

**Attacker Exploitation**: Reconnaissance via error messages; database compromise exposes plaintext PII.

### Denial of Service Threats
**Missing Controls**:
- Rate limiting only on search APIs, not authentication or booking endpoints
- No connection pooling limits for database
- No circuit breaker for third-party provider APIs
- No request size limits specified
- No slowloris/HTTP flood protection

**Attacker Exploitation**: Exhaust database connections, overload authentication service, abuse third-party API rate limits.

### Elevation of Privilege Threats
**Missing Controls**:
- "Role-based access control for admin endpoints" lacks implementation details:
  - No role hierarchy definition
  - No permission model (RBAC vs ABAC)
  - No authorization middleware specification
- No least privilege principle for service-to-service communication
- No IAM role restrictions for ECS containers

**Attacker Exploitation**: Test admin endpoints with user credentials; exploit missing authorization checks to escalate privileges.

---

## 6. Positive Security Controls

Despite critical gaps, the design includes some effective defenses:

1. **TLS Encryption**: "All external communication over HTTPS/TLS 1.3" prevents passive eavesdropping.
2. **Password Hashing**: `password_hash` field indicates hashing (though algorithm not specified).
3. **Database Encryption**: "Database connections encrypted with TLS" protects data in transit to DB.
4. **Payment Delegation**: Using Stripe SDK reduces PCI-DSS scope (assuming proper integration).
5. **Retry Logic**: "Database connection errors are retried up to 3 times" improves resilience.
6. **Log Redaction Guidance**: "Sensitive data should be redacted in logs" (though not enforced).
7. **Containerization**: Docker deployment enables isolation and immutable infrastructure.

**However**: These controls are insufficient without authentication hardening, authorization enforcement, input validation, and audit logging.

---

## 7. Detailed Scoring by Criterion

### 7.1 Threat Modeling (STRIDE)
**Score**: 2/5

**Attacker Assessment**: No explicit threat model present. STRIDE categories not addressed:
- **Spoofing**: Single-factor auth vulnerable to credential stuffing
- **Tampering**: No message integrity checks for inter-service communication
- **Repudiation**: Insufficient audit logging
- **Information Disclosure**: Verbose errors, plaintext PII in database
- **Denial of Service**: Limited rate limiting
- **Elevation of Privilege**: Weak authorization specification

**Attack Scenario**: Absence of threat modeling means no security controls were designed to counter known attack patterns.

**Countermeasures**:
- Conduct STRIDE analysis for each service
- Document threat model with attack trees
- Design security controls per threat category
- Validate design against OWASP Top 10 and CWE Top 25

---

### 7.2 Authentication & Authorization Design
**Score**: 2/5

**Attacker Assessment**:
- **Authentication**: Single-factor, no MFA, weak session management (24h JWT), no logout invalidation
- **Authorization**: "Users can only access their own bookings" lacks enforcement specification; RBAC mentioned without details

**Attack Scenarios**:
1. Credential stuffing (no auth rate limiting)
2. JWT theft via XSS (no storage security)
3. Session hijacking (no IP binding)
4. Password reset token prediction
5. IDOR exploitation (no authorization middleware)

**Countermeasures**:
- **Authentication**:
  - Implement MFA for all accounts
  - Use httpOnly, Secure, SameSite cookies for tokens (not localStorage)
  - Short-lived access tokens (15 min) + refresh tokens
  - Invalidate sessions on logout (Redis blacklist)
  - Rate limit auth endpoints (5 attempts per 15 min)
  - CAPTCHA after 3 failed attempts
- **Authorization**:
  - Implement authorization middleware for all endpoints
  - Define RBAC model with explicit permissions
  - Validate resource ownership server-side
  - Audit all authorization failures

---

### 7.3 Data Protection
**Score**: 3/5

**Attacker Assessment**:
- **At Rest**: PostgreSQL not specified as encrypted at rest; passport numbers, payment details in plaintext
- **In Transit**: TLS 1.3 for external communication (good), database TLS (good), but email transport not secured
- **Data Retention**: No policy → indefinite attack surface expansion

**Attack Scenarios**:
1. Database backup theft → plaintext PII exposure
2. Elasticsearch snapshot access → searchable PII
3. Email interception (password reset) if SMTP not over TLS
4. Expired booking data retained indefinitely → compliance violations

**Countermeasures**:
- Enable PostgreSQL transparent data encryption (TDE)
- Implement field-level encryption for passport numbers, payment tokens
- Use AWS SES with TLS for email transport
- Define data retention policy:
  - Bookings: 7 years (regulatory)
  - PII: Delete after account closure + 90 days
  - Logs: 1 year

---

### 7.4 Input Validation Design
**Score**: 2/5

**Attacker Assessment**:
- Joi validation library mentioned but not applied systematically
- Search endpoints lack input validation specification
- JSONB fields (`booking_data`, `details`) enable flexible schema → injection risk
- No output escaping policy

**Attack Scenarios**:
1. SQL injection via search parameters
2. NoSQL injection via JSONB queries
3. XSS via stored booking data rendered in UI
4. Path traversal if file uploads supported (not specified)
5. XML/JSON bomb attacks (no request size limit)

**Countermeasures**:
- Apply Joi validation to ALL API endpoints
- Parameterize all database queries (no string concatenation)
- Escape output for HTML rendering (React auto-escapes but verify)
- Implement Content Security Policy (CSP)
- Limit request size (1MB for JSON payloads)
- Validate JSONB schema before storage

---

### 7.5 Infrastructure & Dependency Security
**Score**: 3/5

**Attacker Assessment**:
- **Dependencies**: Specific versions listed (good) but no vulnerability scanning policy
- **Secrets**: "Environment variables" without secure storage (AWS Secrets Manager)
- **Network**: No segmentation mentioned; services may be mutually accessible
- **IAM**: No least privilege specification for ECS containers

**Attack Scenarios**:
1. Exploit known CVEs in Express 4.18, Passport.js 0.6.0 if unpatched
2. Extract Stripe keys from environment variables via container inspection
3. Lateral movement from compromised service to PostgreSQL (no network segmentation)
4. Over-privileged ECS task role accesses S3 buckets, RDS, other services

**Countermeasures**:
- **Dependencies**:
  - Implement automated vulnerability scanning (Snyk, Dependabot)
  - Generate SBOM (Software Bill of Materials)
  - Monthly dependency updates with security patches
- **Secrets**:
  - Use AWS Secrets Manager for DB credentials, Stripe keys
  - Rotate secrets quarterly
  - Never commit secrets to git (pre-commit hook)
- **Network**:
  - Segment services into private subnets
  - Database only accessible from application subnet
  - Use AWS Security Groups as firewall
- **IAM**:
  - Least privilege IAM roles per service
  - Deny all by default, allow specific actions
  - No wildcard permissions (`*`)

---

## 8. Summary of Critical Recommendations

### Immediate Actions (Block Trivial Exploits)
1. **JWT Storage**: Use httpOnly, Secure, SameSite cookies (not localStorage)
2. **Authorization Enforcement**: Implement middleware validating resource ownership for all endpoints
3. **Input Validation**: Apply Joi validation to all API endpoints, especially search
4. **Rate Limiting**: Extend to authentication endpoints (5 attempts per 15 min)
5. **CSP Implementation**: Deploy Content Security Policy to block XSS
6. **Audit Logging**: Log all authentication, authorization failures, and privileged actions

### Short-Term Actions (Reduce High-Probability Exploits)
7. **MFA Requirement**: Enforce multi-factor authentication for all accounts
8. **Session Management**: Implement token refresh strategy (15-min access token)
9. **Idempotency Keys**: Require idempotency for payment operations
10. **Secrets Management**: Migrate to AWS Secrets Manager
11. **Network Segmentation**: Isolate database, Redis, Elasticsearch in private subnets
12. **CSRF Protection**: Implement SameSite cookies + CSRF tokens

### Long-Term Actions (Defense in Depth)
13. **Threat Modeling**: Conduct STRIDE analysis for all services
14. **Encryption at Rest**: Enable PostgreSQL TDE, field-level encryption for PII
15. **Dependency Scanning**: Automated CVE detection and patching
16. **RBAC Implementation**: Define explicit role hierarchy and permissions
17. **WAF Deployment**: AWS WAF with OWASP Core Rule Set
18. **Anomaly Detection**: Monitor for unusual access patterns (UEBA)

---

## 9. Exploitability vs. Impact Matrix

| Vulnerability | Exploitability | Impact | Overall Priority |
|---------------|----------------|--------|------------------|
| JWT in localStorage + XSS | Trivial | Critical | **1/5** |
| IDOR on booking endpoints | Trivial | Critical | **1/5** |
| No auth rate limiting | Trivial | High | **2/5** |
| SQL injection (search) | Easy | Critical | **2/5** |
| Password reset token prediction | Easy | High | **2/5** |
| Payment idempotency failure | Easy | High | **2/5** |
| Session hijacking (24h JWT) | Moderate | High | **2/5** |
| CSRF on state-changing ops | Moderate | Medium | **3/5** |
| Verbose error messages | Moderate | Low | **3/5** |
| Infrastructure secrets exposure | Moderate | Critical | **3/5** |

---

## Conclusion

**Attacker's Verdict**: This system is a **high-value, low-effort target**. The combination of weak authentication, missing authorization enforcement, and insufficient input validation creates multiple trivial exploitation paths to sensitive travel data, payment information, and personally identifiable information.

**Most Attractive Attack Path**: XSS → JWT theft → IDOR → mass data exfiltration (fully automated with off-the-shelf tools, undetectable without audit logging).

**Recommended Attacker Investment**: 4-8 hours for initial compromise, automated scripts for mass exploitation.

**Security Posture**: Requires immediate remediation before production deployment. Current design would fail penetration testing and compliance audits (PCI-DSS, GDPR, SOC 2).
