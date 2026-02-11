# Security Design Review: Video Streaming Platform System Design

## Executive Summary

This security review identifies **3 critical issues**, **7 significant issues**, and **4 moderate issues** in the video streaming platform design. The most severe concerns involve missing secure video URL access control, unspecified API authentication mechanisms, and lack of content security policies. While the design includes foundational security elements (TLS, JWT, encryption at rest), critical gaps exist in authentication flows, authorization enforcement, input validation policies, and security audit logging.

---

## Critical Issues

### C-1: Missing Secure Video URL Access Control (Tampering, Information Disclosure)

**Issue**: Section 4.1 specifies that video playback URLs are stored directly in MongoDB (`playback_urls: Array of Objects: {resolution, url}`). The design does not specify how these URLs are protected from unauthorized access. CloudFront URLs without signed URLs or authentication tokens can be easily shared, allowing:
- Premium content to be accessed by non-subscribers
- Direct CDN URL access bypassing authorization checks
- Permanent URL leakage enabling indefinite free access

**Impact**: Complete bypass of subscription-based authorization model. Financial loss from unpaid content access. Potential viral sharing of premium content URLs on piracy forums.

**Recommendation**:
1. Implement CloudFront signed URLs with short expiration (e.g., 1-4 hours)
2. Generate signed URLs dynamically in Video Service after authorization check
3. Include user context (user_id, subscription_tier) in signing policy
4. Document URL signing flow: `GET /api/v1/videos/:id → Verify subscription → Generate signed CloudFront URL → Return to client`
5. Rotate CloudFront key pairs quarterly

**Reference**: Section 4.1 (Data Model - videos.playback_urls), Section 5.2 (GET /api/v1/videos/:id endpoint)

---

### C-2: Incomplete API Authentication Mechanism (Spoofing)

**Issue**: Section 5.4 states "API Gateway validates JWT on each request using public key" but critical details are unspecified:
- How does the gateway obtain and refresh the public key?
- What happens when signature verification fails (error code, retry behavior)?
- Is there a mechanism to revoke compromised tokens before expiry?
- How are refresh tokens validated and rotated?

The design also states "Access tokens stored in HTTP-only cookies" but does not specify:
- Cookie SameSite attribute (missing CSRF protection)
- Secure flag enforcement (allows HTTP transmission in dev environments)
- Domain scope (risk of subdomain cookie theft)

**Impact**:
- Inability to revoke access for compromised accounts until token expiry (30 minutes exposure window)
- CSRF attacks on state-changing operations if SameSite is not set
- Token theft via XSS if cookie flags are improperly configured

**Recommendation**:
1. Specify JWT validation flow: `API Gateway → Fetch public key from Auth Service JWKS endpoint → Cache with TTL → Verify signature → Reject with 401 if invalid`
2. Implement token revocation: Maintain Redis blacklist of revoked token JTIs, check on each request
3. Document cookie attributes: `Set-Cookie: access_token=...; HttpOnly; Secure; SameSite=Strict; Domain=.example.com; Path=/api`
4. Design refresh token rotation: Issue new refresh token with each refresh, invalidate old one
5. Add "last password change timestamp" claim in JWT; reject tokens issued before password change

**Reference**: Section 5.4 (Authentication Approach), Section 5.1 (Authentication Endpoints)

---

### C-3: Missing RTMP Ingestion Authentication (Spoofing, Denial of Service)

**Issue**: Section 3.3 describes live streaming as "RTMP ingestion → MediaLive → MediaPackage → CloudFront" but does not specify authentication for RTMP streams. Without stream key validation:
- Attackers can publish unauthorized streams to any channel
- Malicious users can overwrite legitimate creator streams
- Unauthenticated ingestion enables DoS via high-bitrate stream flooding

**Impact**: Platform integrity compromise. Creator trust erosion if their channels are hijacked. AWS MediaLive costs spike from abuse (can reach thousands of dollars per hour for HD streams).

**Recommendation**:
1. Generate unique, unpredictable stream keys per creator: `HMAC-SHA256(creator_id + channel_id + timestamp + secret)`
2. Store stream keys in PostgreSQL with expiration timestamps
3. Configure MediaLive input security: Whitelist creator IP ranges if static, or use AWS Secrets Manager for dynamic key rotation
4. Validate stream key in `POST /api/v1/streams/start` endpoint before provisioning MediaLive channel
5. Implement stream monitoring: Auto-terminate streams exceeding bitrate/duration thresholds
6. Document in Section 5.3: Add `stream_key` parameter to start endpoint, return RTMP URL with embedded key

**Reference**: Section 3.3 (Data Flow - Live stream), Section 5.3 (Streaming Endpoints)

---

## Significant Issues

### S-1: Weak Password Policy (Spoofing)

**Issue**: Section 4.1 specifies `password_hash` storage but does not define:
- Password hashing algorithm (bcrypt, Argon2, PBKDF2?)
- Cost factor / work factor (critical for resistance to brute force)
- Password complexity requirements
- Account lockout policy after failed login attempts

Without strong password policies, attackers can:
- Brute-force weak passwords (especially common for "free" tier users)
- Exploit credential stuffing attacks using leaked password databases

**Impact**: Account takeover leading to unauthorized content access, fraudulent creator payouts, reputation damage.

**Recommendation**:
1. Specify Argon2id as hashing algorithm (OWASP recommendation) with parameters: memory=64MB, iterations=3, parallelism=4
2. Enforce password policy: Minimum 12 characters, complexity check (no common passwords from breach databases)
3. Implement rate limiting on login endpoint: 5 attempts per 15 minutes per email, 20 attempts per 15 minutes per IP
4. Add CAPTCHA after 3 failed attempts
5. Document in Section 5.1: Add password policy validation to signup endpoint

**Reference**: Section 4.1 (users.password_hash), Section 5.1 (POST /api/v1/auth/login)

---

### S-2: Missing Authorization Enforcement Details (Elevation of Privilege)

**Issue**: Section 5.5 describes three authorization models (RBAC, resource-based, subscription-based) but does not specify:
- Where authorization checks are implemented (API Gateway, individual services, or both?)
- How role and subscription information is propagated to services
- Authorization bypass risk: Can services be called directly, bypassing the gateway?
- Permission checking order (role check before resource ownership check?)

**Impact**: Privilege escalation if authorization is inconsistently enforced. For example:
- Free users accessing premium content if subscription checks are missing in Video Service
- Non-creators deleting videos if ownership checks are incomplete
- Admin-only endpoints exposed if role checks fail

**Recommendation**:
1. Implement defense-in-depth: API Gateway performs coarse-grained role checks, services perform fine-grained resource checks
2. Document authorization flow: `Gateway extracts JWT claims (user_id, role, subscription_tier) → Inject into X-User-Context header → Service validates resource ownership + subscription requirements`
3. Mandate network policies: Prevent direct service-to-service calls from outside cluster using Kubernetes NetworkPolicies
4. Design permission matrix table showing required roles/subscriptions per endpoint
5. Add integration tests verifying authorization for each endpoint with multiple permission scenarios

**Reference**: Section 5.5 (Authorization Model), Section 5.2 (Video Management Endpoints)

---

### S-3: Stripe Webhook Authentication Not Specified (Tampering)

**Issue**: Section 3.3 mentions "Webhook callback → Update PostgreSQL" after Stripe payment, but webhook authentication is not specified. Stripe webhooks without signature verification allow:
- Attackers to forge subscription activation events (POST fake webhook payloads)
- Free users gaining premium access without payment
- Fraudulent creator payout events

**Impact**: Financial fraud. Revenue loss from unauthorized subscription activations. Compliance violations (SOC 2, PCI-DSS require payment integrity).

**Recommendation**:
1. Specify Stripe webhook signature verification: `Stripe-Signature header → Verify using Stripe webhook secret → Reject if invalid`
2. Store Stripe webhook secret in AWS Secrets Manager, rotate every 90 days
3. Implement idempotency: Check `stripe_subscription_id` before processing to prevent replay attacks
4. Add event logging: Record all webhook events (success and failure) with full payload for audit
5. Document in Section 3.3: Add webhook authentication step to payment flow

**Reference**: Section 3.3 (Payment flow), Section 3.2 (Payment Service → External: Stripe API)

---

### S-4: Inadequate Rate Limiting Strategy (Denial of Service)

**Issue**: Section 7.2 specifies basic rate limiting (100 req/min per user, 1000 req/min per IP) but lacks:
- Rate limits for resource-intensive operations (video upload, transcoding, live stream start)
- Differentiated limits by subscription tier (free vs. premium)
- Rate limit enforcement points (only at Kong Gateway? What about WebSocket chat?)
- Bypass risk: Distributed attacks from many IPs can still overwhelm backend

**Impact**:
- DoS via video upload flooding (each upload triggers expensive transcoding)
- Live stream DoS (starting 100 streams simultaneously exhausts MediaLive capacity)
- Chat spam degrading real-time service performance
- Cost spike from AWS service abuse

**Recommendation**:
1. Implement tiered rate limits:
   - Free users: 5 video uploads/day, 1 concurrent live stream
   - Premium users: 50 uploads/day, 3 concurrent streams
   - API endpoints: 100 req/min for reads, 20 req/min for writes
2. Add resource-specific limits: Max 5 GB upload per video, max 10 Mbps stream bitrate
3. Rate limit WebSocket connections: 100 messages/minute per user in Chat Service
4. Implement global rate limiting: Use Redis counters to track platform-wide transcoding/streaming capacity
5. Add request cost calculation: Expensive operations (upload, transcode) consume more quota points

**Reference**: Section 7.2 (API rate limiting), Section 3.1 (API Gateway Layer)

---

### S-5: Missing Input Validation Policy (Injection Attacks)

**Issue**: The design document does not specify input validation strategies for any API endpoint. Critical risks include:
- SQL injection in PostgreSQL queries (e.g., email parameter in login endpoint)
- NoSQL injection in MongoDB queries (e.g., video search by title)
- Path traversal in video upload file names
- XSS in video titles/descriptions rendered on frontend
- Command injection if RTMP URLs are constructed from user input

**Impact**:
- Data breach via SQL/NoSQL injection extracting user credentials, payment info
- Stored XSS enabling account takeover (steal JWT from cookies)
- Server compromise via command injection in transcoding pipeline

**Recommendation**:
1. Document input validation policy in Section 6:
   - Use parameterized queries/ORM for all database operations (Prevent SQL/NoSQL injection)
   - Whitelist validation for enum fields (subscription_tier, roles)
   - Sanitize file names: Allow only alphanumeric + `-_.` characters, max 255 bytes
   - Validate video metadata: Max title length 200 chars, description 5000 chars
   - Content-Type validation: Reject non-video MIME types in upload endpoint
2. Implement output escaping: Frontend must HTML-escape all user-generated content (titles, descriptions, display names)
3. Add CORS policy: Specify allowed origins (avoid wildcard `*` for authenticated endpoints)
4. Validate redirect URLs: Whitelist allowed domains for OAuth callbacks if added later

**Reference**: Section 5 (API Design - all endpoints), Section 3.3 (Data Flow - User uploads video)

---

### S-6: Incomplete Secret Management Design (Information Disclosure)

**Issue**: Section 6.4 mentions "Environment-specific ConfigMaps for configuration" but does not distinguish secrets from config. Risks include:
- Database passwords, Stripe API keys, JWT signing keys stored in ConfigMaps (visible to all namespace users)
- Secrets in environment variables logged by application or Kubernetes events
- No secret rotation policy specified
- Unclear how secrets are injected into containers

**Impact**:
- Secret leakage via unauthorized ConfigMap access (Kubernetes RBAC misconfiguration)
- Credential exposure in logs or error messages
- Prolonged compromise if leaked secrets are never rotated

**Recommendation**:
1. Specify secret storage: Use AWS Secrets Manager or Kubernetes Secrets (with encryption at rest enabled)
2. Document secret categories:
   - Database credentials: Rotate every 90 days, use IAM authentication for RDS if possible
   - API keys (Stripe, AWS): Rotate every 180 days
   - JWT signing keys: Rotate every 30 days with overlapping validity for zero-downtime
3. Secret injection: Use External Secrets Operator to sync AWS Secrets Manager → Kubernetes Secrets → Container env vars
4. Implement least privilege: Grant secret read permissions only to specific service accounts
5. Add secret scanning: Run TruffleHog in CI/CD pipeline to detect accidental commits

**Reference**: Section 6.4 (Deployment - ConfigMaps), Section 5.4 (JWT-based authentication)

---

### S-7: Missing Security Audit Logging (Repudiation)

**Issue**: Section 6.2 describes structured logging but does not specify security audit requirements. The design lacks logging for:
- Authentication events (login success/failure, logout, token refresh)
- Authorization failures (e.g., free user attempting to access premium content)
- Sensitive data access (e.g., viewing payment details, creator revenue dashboard)
- Administrative actions (e.g., video deletion, subscription cancellation)
- Anomalous behavior (e.g., login from new country, unusual upload volume)

**Impact**:
- Inability to detect account takeover or insider threats
- Lack of evidence for security incident investigations
- Compliance violations (GDPR Article 30 requires logging of personal data access)

**Recommendation**:
1. Define security log events in Section 6.2:
   - Authentication: `{event: "login", user_id, ip, user_agent, success, failure_reason, timestamp}`
   - Authorization: `{event: "authz_denied", user_id, resource_type, resource_id, required_permission, timestamp}`
   - Data access: `{event: "data_access", user_id, resource: "payment_info", action: "read", timestamp}`
   - Admin actions: `{event: "video_deleted", admin_id, video_id, creator_id, reason, timestamp}`
2. Retention policy: Store security logs for 90 days in ELK, archive to S3 for 1 year
3. Implement anomaly detection: Alert on multiple failed logins, role changes, bulk data exports
4. Ensure log integrity: Use append-only log storage, sign critical log entries with HMAC
5. Restrict log access: Only security team and designated admins can query audit logs

**Reference**: Section 6.2 (Logging), Section 5.1 (Authentication Endpoints), Section 5.2 (DELETE /api/v1/videos/:id)

---

## Moderate Issues

### M-1: Insufficient Session Management Details (Spoofing)

**Issue**: Section 5.4 specifies 30-minute access token and 7-day refresh token expiry but does not address:
- Session fixation protection (token regeneration after login)
- Concurrent session policy (can user be logged in from multiple devices?)
- Session invalidation on password change or account deletion
- Logout implementation (how are tokens invalidated if stored in HTTP-only cookies?)

**Impact**:
- Session hijacking if tokens are not rotated after privilege escalation
- Stolen refresh token remains valid for 7 days even after password reset
- Unable to force logout of compromised sessions

**Recommendation**:
1. Regenerate tokens after authentication: Issue new access + refresh token pair on successful login
2. Implement session tracking: Store active refresh token IDs in Redis with user_id mapping
3. Logout flow: `POST /api/v1/auth/logout → Extract refresh token from cookie → Add to Redis blacklist with 7-day TTL → Clear cookies`
4. On password change: Invalidate all user sessions by adding user_id to Redis blacklist
5. Add concurrent session limit: Max 5 devices per user, revoke oldest session when exceeded

**Reference**: Section 5.4 (Authentication Approach), Section 5.1 (POST /api/v1/auth/logout)

---

### M-2: Missing Content Security Policy (Cross-Site Scripting)

**Issue**: The design does not specify Content Security Policy (CSP) headers for the React frontend. Without CSP:
- Reflected XSS attacks can execute arbitrary JavaScript
- Inline scripts in user-generated content (video descriptions) can steal tokens
- Malicious third-party scripts can exfiltrate data

**Impact**: Account takeover via XSS, especially if HTTP-only cookies have flaws in implementation.

**Recommendation**:
1. Add CSP headers in Section 7.2:
   - `Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' https://cdn.example.com; media-src https://cloudfront.net; connect-src 'self' wss://chat.example.com`
2. Disallow `unsafe-eval` and `unsafe-inline` for scripts
3. Enable CSP reporting: `report-uri /api/v1/csp-report` to detect violations
4. Implement Subresource Integrity (SRI) for third-party libraries loaded from CDN

**Reference**: Section 2 (Frontend: React), Section 7.2 (Security)

---

### M-3: Lack of Video Upload Integrity Verification (Tampering)

**Issue**: Section 3.3 describes video upload flow (`User uploads video → Video Service → S3 bucket → Lambda triggers transcoding`) but does not specify:
- File integrity verification (checksum validation)
- Virus/malware scanning before processing
- Prevention of malicious video files exploiting transcoding library vulnerabilities

**Impact**:
- Malware distribution via platform (legal liability)
- Server compromise via crafted video files exploiting FFmpeg vulnerabilities
- Data corruption if uploads are tampered during transmission

**Recommendation**:
1. Client-side checksum: Frontend calculates SHA-256 of video file before upload, sends in `X-File-Checksum` header
2. Server-side verification: Video Service recalculates checksum after S3 upload, rejects if mismatch
3. Malware scanning: Integrate ClamAV or AWS GuardDuty Malware Protection to scan uploads before transcoding
4. Sandboxed transcoding: Run Lambda transcoding functions with minimal IAM permissions, isolated VPC
5. File type validation: Use magic number detection (not just file extension) to verify video format

**Reference**: Section 3.3 (Data Flow - User uploads video), Section 5.2 (POST /api/v1/videos)

---

### M-4: Third-Party Dependency Vulnerability Management (Information Disclosure, Elevation of Privilege)

**Issue**: Section 2 lists multiple third-party libraries (JWT, Stripe SDK, Socket.IO) but Section 5 (Infrastructure, Dependencies & Audit criteria) is not addressed in the design. Missing:
- Vulnerability scanning policy for dependencies
- Update cadence for security patches
- Approval process for adding new libraries

**Impact**:
- Exploitation of known CVEs in outdated libraries (e.g., Log4Shell-type events)
- Supply chain attacks via compromised npm packages
- Delayed patching of critical vulnerabilities

**Recommendation**:
1. Document dependency management policy in Section 6.4:
   - Run Snyk or Dependabot scans in CI/CD pipeline, fail build on high-severity CVEs
   - Security patch SLA: Critical CVEs patched within 48 hours, high within 1 week
   - Approve new dependencies: Security team review for supply chain risk
2. Use lock files: `package-lock.json`, `go.sum` committed to version control
3. Scan Docker base images: Use AWS ECR image scanning or Trivy
4. Implement SBOM: Generate Software Bill of Materials for compliance and incident response

**Reference**: Section 2 (Main Libraries: JWT, Stripe SDK, Socket.IO), Section 6.4 (Deployment)

---

## Positive Security Aspects

1. **Strong TLS Configuration**: TLS 1.3 specified (Section 7.2), avoiding weak cipher suites
2. **Encryption at Rest**: Sensitive data encrypted using AWS KMS (Section 7.2)
3. **JWT with Asymmetric Keys**: RS256 algorithm prevents signature forgery (Section 7.2)
4. **HTTP-Only Cookies**: Reduces XSS token theft risk (Section 5.4)
5. **API Rate Limiting Baseline**: Basic protection against brute force (Section 7.2)
6. **Database Migration Management**: Flyway usage reduces schema tampering risk (Section 6.4)

---

## Summary

The video streaming platform design demonstrates awareness of core security principles (TLS, JWT, encryption) but requires significant enhancements before production deployment. **Immediate action required** on:

1. **Critical**: Implement CloudFront signed URLs for video access control
2. **Critical**: Complete JWT validation flow and token revocation mechanism
3. **Critical**: Add RTMP stream key authentication
4. **Significant**: Specify password hashing algorithm and policy
5. **Significant**: Document authorization enforcement architecture
6. **Significant**: Add Stripe webhook signature verification
7. **Significant**: Define comprehensive input validation policy

The design would benefit from a dedicated security architecture section explicitly documenting threat model, trust boundaries, and security control mapping to STRIDE categories.
