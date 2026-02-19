# Security Design Review: FoodConnect System

## Review Metadata
- Reviewer: security-design-reviewer (v014-variant-hierarchical-table)
- Document: FoodConnect システム設計書
- Review Date: 2026-02-10

---

## Critical Issues (Score: 1)

| Issue Category | Component/Flow | Missing Security Measure | Impact | Recommendation | Score |
|----------------|----------------|--------------------------|--------|----------------|-------|
| Missing JWT Storage Specification | Authentication Flow (Section 5) | Token storage mechanism (localStorage vs httpOnly cookies) not specified | XSS attacks can steal tokens from localStorage, leading to account takeover and unauthorized access to customer orders, payment information, and delivery tracking | Explicitly specify httpOnly + Secure + SameSite=Strict cookies for JWT storage in web applications. For mobile apps, use secure keychain/keystore APIs. Document this in API design section. | 1 |
| Missing Authorization Model | API Endpoints (Section 5) | No permission check design or authorization policy beyond JWT authentication | Privilege escalation: customers may access restaurant admin functions, drivers may modify order status without assignment, unauthorized role changes possible | Design and document role-based access control (RBAC) model: define permissions per role (CUSTOMER, RESTAURANT, DRIVER, ADMIN), implement permission checks at service layer, document authorization matrix for each endpoint | 1 |
| Missing Input Validation Policy | All API Endpoints (Section 5) | No validation rules, sanitization strategies, or injection prevention measures documented | SQL injection via order parameters, XSS via delivery address/restaurant names, NoSQL injection via Redis queries, payment manipulation via amount tampering | Define comprehensive input validation policy: regex patterns for email/phone, length limits for text fields, numeric range validation for amounts, whitelist validation for enum values (role, status), parameterized queries enforcement | 1 |
| Missing Idempotency Guarantees | Payment Processing (POST /api/v1/payments) | No duplicate detection, idempotency keys, or retry handling for payment operations | Double-charging customers on network retry, duplicate orders on timeout, inconsistent state between Order Service and Payment Service | Implement idempotency keys for payment and order creation endpoints. Store idempotency key + request hash in Redis with 24-hour TTL. Return cached response for duplicate requests. Document retry policy. | 1 |
| Missing Secrets Management Design | Infrastructure (Section 2, 6) | No specification for managing database passwords, JWT signing keys, external API keys, encryption keys | Hardcoded secrets in code or environment variables lead to credential leakage, unauthorized database access, token forgery, payment service compromise | Use AWS Secrets Manager or Parameter Store for all secrets. Implement automatic rotation for database credentials (90 days) and JWT signing keys (365 days). Document access control policies and rotation schedules. | 1 |

---

## Significant Issues (Score: 2)

| Issue Category | Component/Flow | Missing Security Measure | Impact | Recommendation | Score |
|----------------|----------------|--------------------------|--------|----------------|-------|
| Missing CSRF Protection | State-Changing Endpoints (POST/PATCH in Section 5) | No CSRF token mechanism documented | Cross-site request forgery can trigger unauthorized orders, payment modifications, or status changes if user is authenticated | Implement CSRF tokens for web clients: generate token on session creation, validate token on all state-changing requests, use double-submit cookie pattern or synchronizer token pattern | 2 |
| Missing Rate Limiting Specifications | All API Endpoints (Section 5) | Rate limiting mentioned in API Gateway but no specific limits, algorithms, or enforcement policies defined | Brute-force attacks on /auth/login, credential stuffing, API abuse, DoS attacks, excessive password reset requests | Define rate limits per endpoint: /auth/login (5 req/min per IP), /auth/signup (3 req/min per IP), /orders (20 req/min per user), /payments (10 req/min per user). Use token bucket algorithm with Redis. Document response headers (X-RateLimit-*). | 2 |
| Missing Audit Logging Design | All Services (Section 3, 6) | No specification for what events to log, log retention, log protection, or PII masking | Insufficient evidence for fraud investigation, compliance violations (PCI-DSS, GDPR), inability to detect unauthorized access or data breaches | Design audit logging policy: log authentication events (login/logout/password reset), order lifecycle events, payment transactions, admin actions, authorization failures. Mask PII (card numbers, passwords). Store logs in tamper-proof storage (CloudWatch Logs with retention policy). Define 90-day retention for audit logs. | 2 |
| Missing Session Management Policy | Authentication (Section 5) | No session timeout, concurrent session limits, or token revocation mechanism documented | Session hijacking risks, stolen tokens remain valid indefinitely, no way to forcibly logout compromised accounts | Define session policy: JWT access token (15 min TTL), refresh token (7 days TTL with rotation), max 3 concurrent sessions per user, implement token revocation list in Redis, provide explicit logout endpoint that invalidates refresh tokens | 2 |
| Missing Error Exposure Policy | Error Handling (Section 6) | Only mentions hiding stack traces, but no policy for preventing information disclosure through error messages | Error messages may leak database schema, internal paths, user enumeration (different errors for "email not found" vs "wrong password"), system version information | Define error response policy: use generic messages for authentication failures ("Invalid credentials"), sanitize validation errors (no schema hints), implement error code mapping, log detailed errors server-side only, return consistent timing for auth endpoints | 2 |
| Missing Data Retention Policy | User/Order/Payment Data (Section 4) | No specification for how long to retain personal data, order history, payment records, or deleted account handling | GDPR/CCPA compliance violations, unnecessary PII storage increases breach risk, no clear process for user data deletion requests | Define retention policy: active user data (indefinite with annual consent), inactive accounts (3 years then anonymize), order history (7 years for accounting), payment logs (PCI-DSS: 1 year transaction data, 3 months card data), implement soft delete with anonymization pipeline | 2 |

---

## Moderate Issues (Score: 3)

| Issue Category | Component/Flow | Missing Security Measure | Impact | Recommendation | Score |
|----------------|----------------|--------------------------|--------|----------------|-------|
| Missing XSS Protection | API Responses (Section 5) | No Content-Security-Policy, X-Content-Type-Options, or output escaping policy documented | Stored XSS via delivery address or restaurant menu names, reflected XSS in error messages, clickjacking attacks | Implement CSP headers: `Content-Security-Policy: default-src 'self'`, add `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, sanitize user input on storage and output, use framework's built-in escaping (Thymeleaf auto-escaping for web views) | 3 |
| Missing Password Policy | User Registration (Section 4, 5) | No password complexity requirements, no password expiration, no breach detection | Weak passwords enable brute-force attacks, credential stuffing from other breaches | Define password policy: minimum 12 characters, require uppercase/lowercase/digit/special character, check against common password lists (Have I Been Pwned API), enforce password change on breach detection, prevent password reuse (store 5 previous hashes) | 3 |
| Missing Database Encryption | PostgreSQL RDS (Section 2, 7) | Encryption at rest not explicitly specified | Data breach if physical storage is compromised, compliance violations (PCI-DSS requires encryption at rest for payment data) | Enable RDS encryption at rest using AWS KMS with customer-managed keys (CMK). Document key management and rotation policy. Enable TLS for database connections (require SSL mode in connection string). | 3 |
| Missing Payment Data Handling Policy | Payment Service (Section 3, 4) | No PCI-DSS compliance measures, card data storage policy, or tokenization strategy documented | PCI-DSS scope expansion, risk of storing prohibited card data (CVV, full PAN), audit failures | Implement payment tokenization: use external payment gateway (Stripe/PayPal) to tokenize cards, store only payment method tokens and last 4 digits (already in schema), never store CVV or full card numbers, document PCI-DSS SAQ-A compliance approach, implement TLS 1.2+ for payment gateway communication | 3 |
| Missing Dependency Vulnerability Management | Spring Boot, Third-Party Libraries (Section 2) | No vulnerability scanning, patch management, or dependency review process documented | Known CVEs in outdated libraries (e.g., Spring4Shell, Log4Shell), supply chain attacks, transitive dependency vulnerabilities | Implement dependency scanning: use OWASP Dependency-Check or Snyk in CI/CD pipeline, automate security patch updates, define SLA for patching critical vulnerabilities (7 days), maintain Software Bill of Materials (SBOM), enable GitHub Dependabot alerts | 3 |
| Missing API Versioning Strategy | API Endpoints (Section 5) | Version in path (/api/v1/) but no policy for deprecation, breaking changes, or security fixes for old versions | Old API versions with known vulnerabilities remain accessible, inability to enforce security improvements on legacy clients | Define API versioning policy: support N and N-1 versions only, 6-month deprecation notice for old versions, security patches applied to all supported versions, force upgrade for critical security fixes, document version compatibility matrix | 3 |
| Missing CORS Policy | API Gateway (Section 3) | CORS mentioned in infrastructure assessment but not specified in API design | Overly permissive CORS enables unauthorized cross-origin access, CSRF-like attacks from malicious websites | Define CORS policy: whitelist allowed origins (mobile apps use custom schemes), restrict methods (only required HTTP verbs), set `Access-Control-Allow-Credentials: true` for cookie-based auth, define `Access-Control-Max-Age` for preflight caching | 3 |
| Missing Geolocation Privacy | Delivery Service (Section 3) | Real-time location tracking mentioned but no privacy controls, data retention, or access restrictions | Excessive location data collection, privacy violations, potential stalking if driver/customer location exposed | Implement location privacy controls: collect location only during active delivery, delete precise location after delivery completion (retain only city-level for analytics), restrict location access (driver location visible only to assigned customer/restaurant), implement location data encryption in transit and at rest | 3 |

---

## Infrastructure Security Assessment

| Component | Configuration | Security Measure | Status | Risk Level | Recommendation |
|-----------|---------------|------------------|--------|------------|----------------|
| Database (PostgreSQL RDS) | Access control, encryption, backup | Multi-AZ mentioned, Read Replica for scaling | Partial (encryption at rest not specified, network isolation unclear) | High | Enable RDS encryption at rest with KMS. Configure VPC security groups to restrict database access to backend services only. Enable automated backups with 30-day retention. Implement database activity monitoring (AWS RDS Enhanced Monitoring). |
| Storage (S3) | Access policies, encryption at rest | Used for static files (images, menu photos) via CloudFront | Missing (no access control policy, encryption, or versioning specified) | High | Enable S3 bucket encryption (SSE-S3 or SSE-KMS). Implement bucket policies with least privilege (deny public write, allow CloudFront OAI only). Enable versioning for audit trail. Configure lifecycle policies for cost optimization. Block public ACLs. |
| Cache (Redis ElastiCache) | Network isolation, authentication | Used for sessions and cache | Missing (no authentication, encryption in transit, or network isolation specified) | High | Enable Redis AUTH for authentication. Enable encryption in transit (TLS). Configure VPC security groups to restrict access to backend services. Implement automatic failover with Redis Cluster mode. Set appropriate eviction policies for session data. |
| API Gateway | Authentication, rate limiting, CORS | Rate limiting mentioned, routing | Partial (rate limits undefined, CORS policy missing, no WAF mentioned) | Medium | Define specific rate limits per endpoint (see Significant Issues). Configure AWS WAF for common attack protection (SQL injection, XSS). Implement request/response logging. Configure CORS policy with whitelisted origins. Enable CloudWatch alarms for error rates. |
| Secrets Management | Rotation, access control, storage | Not specified | Missing (no secrets management strategy documented) | Critical | Implement AWS Secrets Manager for all credentials. Configure automatic rotation for RDS credentials (90 days), JWT keys (365 days), external API keys (per vendor policy). Use IAM roles with least privilege for secrets access. Enable CloudTrail logging for secret access audit. |
| Dependencies (Spring Boot, Libraries) | Version management, vulnerability scanning | Spring Boot 3.1, Spring Security 6.1 specified | Missing (no scanning, patch management, or update policy) | High | Integrate OWASP Dependency-Check in CI/CD. Enable GitHub Dependabot for automated vulnerability alerts. Define patch SLA: critical (7 days), high (30 days), medium (90 days). Automate minor version updates. Maintain SBOM for supply chain security. |
| Container Images (ECR) | Vulnerability scanning, signing | Docker images stored in ECR | Missing (no image scanning or signing policy) | Medium | Enable ECR image scanning on push. Implement image signing with AWS Signer or Cosign. Define base image update policy. Use distroless or minimal base images. Scan for secrets in images with tools like truffleHog. Implement image retention policy. |
| Network Security | Firewall, segmentation, DDoS protection | AWS infrastructure implied | Partial (VPC design not documented) | Medium | Document VPC architecture with public/private subnet segmentation. Place backend services in private subnets. Use NAT Gateway for egress. Configure NACLs and security groups with least privilege. Enable AWS Shield Standard (automatic). Consider Shield Advanced for DDoS protection. |

---

## Summary: Evaluation Scores by Criterion

| Criterion | Score | Key Issues |
|-----------|-------|------------|
| Threat Modeling (STRIDE) | 2 | No systematic threat analysis documented. Critical gaps: Spoofing (weak session mgmt), Tampering (no input validation), Repudiation (no audit logs), Information Disclosure (weak error handling), DoS (undefined rate limits), Elevation of Privilege (no authorization model) |
| Authentication & Authorization Design | 1 | Critical flaws: JWT storage mechanism undefined (XSS risk), no authorization/permission model beyond authentication, no session timeout policy, no token revocation mechanism, missing CSRF protection |
| Data Protection | 2 | Significant gaps: no data retention policy, PCI-DSS compliance not addressed, encryption at rest not specified, location data privacy missing, no PII masking in logs |
| Input Validation Design | 1 | Critical absence: no input validation policy, no sanitization strategy, no injection prevention measures, no output escaping policy, XSS/SQLi risks across all endpoints |
| Infrastructure & Dependency Security | 2 | Major gaps: no secrets management, no dependency scanning, Redis/S3 encryption missing, network isolation unclear, no container security policy |

---

## Positive Security Aspects

The following security measures are present in the design and represent good practices:

1. **Password Hashing**: bcrypt algorithm specified for password storage (Section 4) - industry standard for password protection
2. **HTTPS Encryption**: All communications encrypted in transit (Section 7) - protects against eavesdropping
3. **JWT Authentication**: Token-based authentication reduces server-side session state (Section 5) - scalable approach
4. **Multi-AZ Database**: High availability configuration reduces downtime risk (Section 6)
5. **Blue/Green Deployment**: Zero-downtime deployment strategy minimizes service disruption (Section 6)
6. **Error Handling Strategy**: Stack traces hidden from clients, detailed errors logged server-side (Section 6) - prevents information leakage
7. **Role-Based User System**: User roles defined in schema (CUSTOMER, RESTAURANT, DRIVER, ADMIN) - foundation for proper authorization
8. **Separate Payment Service**: Payment logic isolated in dedicated service (Section 3) - reduces PCI-DSS scope
9. **CDN for Static Content**: S3 + CloudFront for images (Section 6) - reduces direct S3 exposure
10. **Testing Strategy**: Comprehensive test plan with coverage goals (Section 6) - supports security regression testing

---

## Overall Assessment

**Overall Security Posture: High Risk**

This design document has **5 critical security gaps** that must be addressed before production deployment:

1. **Missing JWT Storage Specification** - XSS token theft risk
2. **No Authorization Model** - Privilege escalation risk
3. **No Input Validation Policy** - Injection attack risk
4. **No Idempotency Guarantees** - Financial integrity risk
5. **No Secrets Management** - Credential leakage risk

Additionally, **6 significant issues** require attention:

- Missing CSRF protection
- Undefined rate limiting specifications
- No audit logging design
- Missing session management policy
- Missing error exposure policy
- No data retention policy

**Recommendation**: Address all critical issues (Score 1) before proceeding to implementation. Prioritize authorization model, input validation policy, and secrets management as foundational security controls. Significant issues (Score 2) should be designed before initial production launch.
