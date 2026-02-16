# Security Design Review: 暗号資産取引プラットフォーム

## Critical Issues

### 1. JWT Storage Location Not Specified (Ref: Section 5.3)

**Issue**: The design specifies JWT-based authentication with 15-minute expiration but does not explicitly specify where access tokens should be stored on the client side (browser/mobile app). This is a critical security design gap.

**Impact**: Improper token storage can lead to:
- Token theft via XSS attacks if stored in localStorage
- Session hijacking if accessible to malicious scripts
- Complete account compromise allowing unauthorized trading and withdrawals

**Countermeasure**: Explicitly design token storage mechanism:
- For web: Use httpOnly, Secure, SameSite cookies for token storage
- For mobile: Use platform-specific secure storage (iOS Keychain, Android Keystore)
- Document token transmission method (cookies vs Authorization header)

### 2. No Authorization Design for Resource Ownership Verification (Ref: Sections 5.1, 5.2)

**Issue**: The API endpoints for accessing user resources (`GET /api/v1/orders`, `GET /api/v1/trades`, `GET /api/v1/wallets`, `DELETE /api/v1/orders/{id}`, `GET /api/v1/withdrawals/{id}`) do not explicitly specify ownership verification in their design.

**Impact**: Without explicit ownership checks:
- Users could access other users' orders, trades, and wallet information
- Users could cancel other users' orders
- Users could view other users' withdrawal requests
- Complete breach of user privacy and potential financial manipulation

**Countermeasure**: Explicitly design authorization checks for each endpoint:
- Order access/cancellation: Verify `order.user_id == authenticated_user.id`
- Trade history: Filter by authenticated user ID
- Wallet access: Verify wallet ownership before returning balance
- Withdrawal access: Verify withdrawal belongs to authenticated user

### 3. No Rate Limiting Design for Authentication Endpoints (Ref: Section 5.1)

**Issue**: While API Gateway implements general rate limiting (1000 req/min for authenticated, 100 req/min for unauthenticated), there is no specific rate limiting design for authentication endpoints (`/api/v1/auth/login`, `/api/v1/auth/totp/verify`).

**Impact**:
- Brute force attacks against user passwords
- TOTP code enumeration attacks (1,000,000 possible codes)
- Account takeover leading to unauthorized trading and withdrawals
- Potential for automated large-scale account compromise

**Countermeasure**: Design specific rate limiting for authentication endpoints:
- Login endpoint: 5 attempts per IP per 15 minutes, 10 attempts per account per hour
- TOTP verification: 3 attempts per session, account lockout after 10 failed attempts
- Implement progressive delays (exponential backoff)
- Add CAPTCHA after N failed attempts

### 4. Private Key Management for Hot Wallet Not Designed (Ref: Section 3.2, 3.3)

**Issue**: The Wallet Service design mentions hot wallet and cold wallet management but does not specify how hot wallet private keys are stored, accessed, or protected.

**Impact**: Inadequate private key protection can lead to:
- Complete theft of all assets in hot wallet (10% of total assets per Section 7.3)
- No recovery mechanism if keys are compromised
- Insider threats if keys are accessible to operators
- Multi-million dollar financial loss

**Countermeasure**: Design explicit key management architecture:
- Use Hardware Security Module (HSM) or Cloud KMS for private key storage
- Implement multi-signature wallet requiring M-of-N approvals for withdrawals
- Design key rotation policy and procedures
- Specify access control (who can sign transactions, under what conditions)
- Design audit logging for all key access and signing operations

### 5. No Encryption Design for Sensitive Data at Rest (Ref: Sections 4.2, 7.2)

**Issue**: The database schema includes highly sensitive PII (KYC documents with `file_path` in S3, `password_hash`, `totp_secret`, `destination_address`) but does not specify encryption at rest beyond general "TLS 1.3 for communication."

**Impact**: Database breach or backup exposure would result in:
- Identity theft from KYC documents (passport scans, ID cards, selfies)
- Account compromise via TOTP secret theft
- Regulatory violations (GDPR, financial regulations)
- Severe reputational damage and potential license revocation

**Countermeasure**: Design explicit encryption strategy:
- Database-level encryption: Enable PostgreSQL Transparent Data Encryption (TDE)
- Application-level encryption: Encrypt sensitive fields (`totp_secret`, KYC document references) with AES-256
- Key management: Use Google Cloud KMS for encryption key storage with automatic rotation
- S3 bucket encryption: Enable S3 server-side encryption (SSE-KMS) for KYC documents
- Specify data classification policy and retention/deletion schedules

## Significant Issues

### 6. WebSocket Authentication Not Fully Specified (Ref: Section 3.3)

**Issue**: WebSocket authentication mentions "JWT sent in initial message" but does not specify:
- Message format for JWT transmission
- Re-authentication mechanism if token expires during long session
- Handling of connection after token expiration (15 minutes)

**Impact**:
- Forced disconnection every 15 minutes disrupting trading
- Potential for unauthorized WebSocket connections if implementation is inconsistent
- Poor user experience or security bypass depending on implementation choice

**Countermeasure**: Design WebSocket authentication protocol:
- Specify initial authentication message format (e.g., `{"type":"auth","token":"..."}`)
- Design token refresh mechanism for WebSocket (either extend token lifetime for WS or implement in-band refresh)
- Specify disconnection policy on token expiration
- Add session validation on every critical operation (order placement)

### 7. No Input Validation Design for Order Parameters (Ref: Section 5.1, 5.2)

**Issue**: The order creation endpoint (`POST /api/v1/orders`) does not specify validation rules for critical parameters like `price`, `quantity`, minimum/maximum order sizes, or price deviation limits.

**Impact**:
- Potential for market manipulation via extreme price/quantity values
- System instability from processing invalid orders
- Financial loss from erroneous trades
- Flash crash scenarios from algorithmic trading errors

**Countermeasure**: Design explicit validation rules:
- Price: Must be within ±10% of current market price (circuit breaker)
- Quantity: Minimum order size (e.g., 0.001 BTC), maximum position limits per user
- Order value: Maximum order value limits to prevent fat-finger errors
- Numeric precision: Define decimal place limits per currency pair
- Reject orders during market halt or insufficient liquidity

### 8. No Audit Logging Design for Critical Operations (Ref: Section 6.2)

**Issue**: While the design mentions logging API requests and transactions, it does not explicitly specify security audit logging for critical operations like:
- Failed authentication attempts
- Permission changes (role modifications)
- KYC approval/rejection decisions
- Withdrawal approvals
- Administrative actions

**Impact**:
- Inability to detect insider threats or account compromise
- No forensic trail for regulatory investigations
- Difficult to prove compliance during audits
- Cannot identify patterns of suspicious behavior

**Countermeasure**: Design security audit log requirements:
- Log all authentication events (success/failure, IP, timestamp, user agent)
- Log permission changes with before/after state and approver identity
- Log all withdrawal workflow steps (request, approval, completion, rejection)
- Log KYC review decisions with reviewer identity and justification
- Immutable audit log storage with tamper detection
- Retention period: 7 years per compliance requirements (Section 7.4)

### 9. No Account Enumeration Protection (Ref: Section 5.1)

**Issue**: The authentication endpoints (`POST /api/v1/auth/login`, `POST /api/v1/auth/register`) do not specify protection against account enumeration attacks, where attackers can determine if an email address is registered.

**Impact**:
- Attackers can build database of registered users
- Targeted phishing attacks against confirmed users
- Competitive intelligence (identify trading volumes by user discovery)
- Preparation for credential stuffing attacks

**Countermeasure**: Design enumeration protection:
- Login: Return generic error "Invalid credentials" for both wrong email and wrong password
- Registration: Use consistent response time regardless of email existence
- Password reset: Always show "If account exists, reset link sent" message
- Implement timing attack protection (constant-time comparisons)

### 10. No CORS Policy Design (Ref: Section 3.1, 5.1)

**Issue**: The design mentions "CORS/origin control" in Section 4.4 as an evaluation criterion but does not specify the actual CORS policy for the API.

**Impact**:
- If too permissive (*), allows malicious sites to make authenticated requests
- If too restrictive, breaks legitimate mobile app or web app functionality
- Potential for CSRF-like attacks if origins not properly validated

**Countermeasure**: Design explicit CORS policy:
- Whitelist specific origins: `https://trade.example.com`, `https://app.example.com`
- Disallow wildcard (`*`) for authenticated endpoints
- Set appropriate headers: `Access-Control-Allow-Credentials: true`
- Specify allowed methods and headers explicitly
- Implement origin validation in API Gateway (Kong)

## Moderate Issues

### 11. No Session Invalidation Design for Security Events (Ref: Section 5.3)

**Issue**: The design specifies JWT authentication without refresh tokens and mentions logout endpoint, but does not specify how to invalidate sessions in security-critical scenarios:
- Password change
- 2FA enablement/disablement
- Suspicious activity detection
- Administrative account lockout

**Impact**:
- Active sessions remain valid even after password change
- Compromised accounts cannot be forcibly logged out
- Delayed response to security incidents
- Limited ability to contain account takeover

**Countermeasure**: Design session invalidation mechanism:
- Maintain JWT blocklist in Redis with TTL matching token expiration
- Invalidate all user sessions on password change, 2FA changes
- Design force-logout capability for administrators
- Include session identifier in JWT for targeted revocation
- Consider implementing refresh token pattern for better session control

### 12. No Blockchain Transaction Validation Design (Ref: Section 3.3)

**Issue**: The deposit flow monitors blockchain confirmations (3 for Bitcoin, 12 for Ethereum) but does not specify validation of transaction integrity, amount verification, or handling of chain reorganizations.

**Impact**:
- Credit user for incorrect deposit amount
- Double-spending attacks during chain reorgs
- Loss of funds if transaction is invalidated
- Potential for exploit via malformed transactions

**Countermeasure**: Design blockchain validation requirements:
- Verify transaction amount matches expected deposit
- Validate destination address matches generated address
- Handle chain reorganizations (monitor for deeper confirmations if reorg detected)
- Specify minimum/maximum deposit amounts
- Design handling of overpayment/underpayment scenarios

### 13. Insufficient Withdrawal Security Design (Ref: Section 3.3, 5.1)

**Issue**: Withdrawal design requires "KYC completed + 2FA" but does not specify:
- Whitelisting of withdrawal addresses
- Cooling-off period for new addresses
- Additional verification for large withdrawals
- Detection of address typos or malicious address substitution

**Impact**:
- Compromised accounts can drain funds to attacker-controlled addresses
- No recovery mechanism once blockchain transaction is broadcast
- Potential for clipboard malware attacks
- Difficulty detecting account takeover before funds are lost

**Countermeasure**: Design enhanced withdrawal security:
- Address whitelist: Users pre-register withdrawal addresses with email confirmation
- Cooling-off period: 24-hour delay before new address can be used
- Email/SMS confirmation for each withdrawal request
- Tiered limits: Higher amounts require additional verification (e.g., video call)
- Display destination address prominently, require user to confirm partial match

### 14. No Secrets Rotation Policy (Ref: Section 6.4)

**Issue**: The design specifies using Google Secret Manager but does not mention rotation policy for secrets like:
- JWT signing keys
- Database credentials
- Blockchain node API keys
- Third-party service API keys

**Impact**:
- Prolonged exposure if secret is compromised
- No containment strategy for leaked credentials
- Accumulation of stale credentials over time
- Difficulty responding to supply chain security incidents

**Countermeasure**: Design secret rotation policy:
- JWT signing keys: Rotate monthly, support multiple concurrent keys during transition
- Database credentials: Rotate quarterly using automated tools
- API keys: Rotate on compromise detection or annually
- Document rotation procedures and rollback mechanisms
- Implement zero-downtime rotation strategy

### 15. No Dependency Vulnerability Management Process (Ref: Section 2.4, 5.5)

**Issue**: The design lists specific library versions (golang-jwt/jwt v5, GORM v1.25, gorilla/websocket v1.5) and mentions "vulnerability management policies for third-party libraries" as an evaluation criterion but does not specify the actual process.

**Impact**:
- Delayed patching of critical vulnerabilities (e.g., Log4Shell-class issues)
- Accumulation of known vulnerable dependencies
- Difficulty maintaining compliance with security standards
- Potential for supply chain attacks

**Countermeasure**: Design vulnerability management process:
- Automated scanning: Integrate Dependabot/Snyk in CI/CD pipeline
- SLA for patching: Critical vulnerabilities within 7 days, high within 30 days
- Dependency update policy: Review and update dependencies quarterly
- SCA (Software Composition Analysis) in build pipeline
- Maintain Software Bill of Materials (SBOM)

## Minor Improvements and Positive Aspects

### 16. Strong Password Policy Not Specified

**Issue**: Password requirements are not explicitly designed (complexity, length, common password blocking).

**Recommendation**: Design password policy:
- Minimum 12 characters
- Require mix of uppercase, lowercase, numbers, special characters
- Block common passwords (use "Have I Been Pwned" API)
- Enforce password change on compromise detection

### 17. Consider Implementing Request Signing

**Recommendation**: For high-value operations (withdrawals, large trades), consider implementing request signing (similar to AWS Signature V4) to prevent request tampering and replay attacks.

### 18. Positive: Defense in Depth for Withdrawals

The design appropriately implements multiple layers for withdrawal security:
- KYC requirement
- 2FA requirement
- Administrator approval workflow

This demonstrates good security design principles.

### 19. Positive: Appropriate Use of TLS 1.3

The design specifies TLS 1.3, which is the current best practice for transport encryption, showing awareness of modern cryptographic standards.

### 20. Positive: Role-Based Access Control

The design implements RBAC with distinct roles (USER, ADMIN, COMPLIANCE), which is appropriate for the different access patterns in a financial platform.

---

## Summary

This cryptocurrency trading platform design demonstrates awareness of security requirements but has **5 critical gaps** that must be addressed before implementation:

1. JWT storage location unspecified
2. No authorization design for resource ownership verification
3. No rate limiting for authentication endpoints
4. Private key management for hot wallet not designed
5. No encryption design for sensitive data at rest

Additionally, **10 significant issues** require design attention, particularly around WebSocket authentication, input validation, audit logging, and withdrawal security.

The design shows positive aspects in defense-in-depth for withdrawals, use of modern TLS, and RBAC implementation. However, the critical and significant issues pose substantial risk of data breach, financial loss, and regulatory violations if not addressed in the design phase.

**Recommendation**: Address all critical issues before proceeding to implementation. Prioritize designing JWT storage, resource authorization checks, authentication rate limiting, and encryption at rest in the next iteration.
