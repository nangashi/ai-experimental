# Answer Key - Round 017

## Execution Conditions
- **Perspective**: security
- **Target**: design
- **Embedded Problems**: 9

## Embedded Problem List

### P01: JWT Access Token Storage in HTTP-only Cookies without XSS Mitigation
- **Category**: 認証・認可設計 (Authentication & Authorization Design)
- **Severity**: 重大 (Critical)
- **Location**: Section 5.4 Authentication Approach
- **Problem Description**: The design specifies storing access tokens in HTTP-only cookies, which prevents JavaScript access and mitigates XSS-based token theft. However, the design lacks explicit XSS prevention measures (Content Security Policy, input sanitization, output encoding). If XSS vulnerabilities exist elsewhere in the application, attackers could still perform authenticated actions on behalf of the victim even without stealing the token itself. The design should explicitly address XSS prevention mechanisms to ensure defense-in-depth.
- **Detection Criteria**:
  - ○ (Detected): Identifies the need for XSS prevention mechanisms (CSP, input sanitization, output encoding) in conjunction with HTTP-only cookie storage, or points out that HTTP-only cookies alone do not prevent XSS-based attacks and requires additional countermeasures
  - △ (Partial): Mentions XSS risks generally or recommends CSP without connecting it to the JWT storage strategy
  - × (Not Detected): No mention of XSS prevention or only praises HTTP-only cookie usage without identifying the gap

### P02: Missing Refresh Token Storage Specification
- **Category**: 認証・認可設計 (Authentication & Authorization Design)
- **Severity**: 重大 (Critical)
- **Location**: Section 5.4 Authentication Approach
- **Problem Description**: The design mentions refresh tokens with 7-day expiry but does not specify where refresh tokens are stored (HTTP-only cookie vs. local storage vs. memory). Refresh tokens are long-lived credentials; improper storage (e.g., localStorage) exposes them to XSS attacks. The design should explicitly define refresh token storage location and justify the security trade-offs.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of refresh token storage specification and recommends secure storage (HTTP-only cookie or secure alternative)
  - △ (Partial): Mentions refresh token security concerns without specifically identifying the missing storage specification
  - × (Not Detected): No mention of refresh token storage

### P03: Creator Video Ownership Authorization Check Not Explicitly Designed
- **Category**: 認証・認可設計 (Authentication & Authorization Design)
- **Severity**: 重大 (Critical)
- **Location**: Section 5.2 Video Management Endpoints, DELETE /api/v1/videos/:id
- **Problem Description**: The API design states "Delete video (creator owner only)" but does not detail how ownership verification is implemented. The design should explicitly specify the authorization check logic: (1) verify JWT role includes "creator", (2) query database to confirm `videos.creator_id == authenticated_user.id`, (3) return 403 if not owner. Without explicit specification, IDOR (Insecure Direct Object Reference) vulnerabilities may be introduced during implementation.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of detailed authorization check design for resource-based access control (video ownership verification) and recommends explicit specification
  - △ (Partial): Mentions IDOR risks generally or authorization concerns without specifically pointing to the missing ownership check design
  - × (Not Detected): No mention of authorization implementation gaps

### P04: Database Connection String Storage Not Specified
- **Category**: データ保護 (Data Protection)
- **Severity**: 中 (Medium)
- **Location**: Section 6.4 Deployment, "Environment-specific ConfigMaps for configuration"
- **Problem Description**: The design uses Kubernetes ConfigMaps for environment-specific configuration but does not clarify whether sensitive credentials (database connection strings, API keys) are stored in ConfigMaps or Secrets. ConfigMaps are not encrypted by default and store data in plaintext. Sensitive credentials should be stored in Kubernetes Secrets (or external secret management like AWS Secrets Manager / Vault) with encryption at rest enabled. The design should explicitly separate sensitive vs. non-sensitive configuration and specify secure storage for credentials.
- **Detection Criteria**:
  - ○ (Detected): Points out that ConfigMaps are not suitable for sensitive credentials and recommends Kubernetes Secrets or external secret management (AWS Secrets Manager, Vault)
  - △ (Partial): Mentions credential management concerns or recommends Secrets without specifically identifying the ConfigMap usage gap
  - × (Not Detected): No mention of ConfigMap vs. Secret distinction or credential storage

### P05: MongoDB Video Metadata Access Control Not Specified
- **Category**: 認証・認可設計 (Authentication & Authorization Design)
- **Severity**: 中 (Medium)
- **Location**: Section 4.1 Data Model, "videos (MongoDB)"
- **Problem Description**: The video metadata model in MongoDB does not specify access control or encryption for premium content metadata. Premium videos require active subscriptions for access (Section 5.2), but the design does not address: (1) MongoDB query-level access control to prevent unauthorized metadata reads, (2) Whether playback URLs for premium content include signed URLs or time-limited tokens. Without these safeguards, attackers could potentially enumerate premium video metadata or access premium playback URLs directly without subscription verification.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of access control design for premium video metadata in MongoDB or points out the need for signed/time-limited playback URLs for premium content
  - △ (Partial): Mentions MongoDB security concerns generally (authentication, encryption) without specifically addressing premium content access control
  - × (Not Detected): No mention of MongoDB access control or premium content protection

### P06: Stripe Webhook Signature Verification Not Specified
- **Category**: 入力検証・攻撃防御 (Input Validation & Attack Defense)
- **Severity**: 中 (Medium)
- **Location**: Section 3.3 Data Flow, "Payment flow: ... → Webhook callback → Update PostgreSQL"
- **Problem Description**: The design includes Stripe webhook callbacks to update subscription status in PostgreSQL but does not specify webhook signature verification. Without verifying the `Stripe-Signature` header using the webhook signing secret, attackers could forge webhook requests to manipulate subscription status (e.g., grant premium access without payment). The design should explicitly require webhook signature verification using Stripe SDK before processing webhook events.
- **Detection Criteria**:
  - ○ (Detected): Identifies the need for Stripe webhook signature verification to prevent forged webhook requests
  - △ (Partial): Mentions webhook security concerns generally without specifically identifying the missing signature verification
  - × (Not Detected): No mention of webhook security or signature verification

### P07: RTMP Ingestion Authentication Not Specified
- **Category**: 認証・認可設計 (Authentication & Authorization Design)
- **Severity**: 中 (Medium)
- **Location**: Section 3.3 Data Flow, "Live stream: RTMP ingestion → MediaLive"
- **Problem Description**: The design specifies RTMP ingestion for live streaming but does not detail the authentication mechanism for RTMP publishers. Without authentication, unauthorized users could publish streams to the platform. The design should specify: (1) Stream key generation and distribution to authorized creators, (2) RTMP authentication at MediaLive ingestion endpoint, (3) Stream key rotation policy.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of RTMP ingestion authentication design and recommends stream key or token-based authentication
  - △ (Partial): Mentions live streaming security concerns without specifically identifying the RTMP authentication gap
  - × (Not Detected): No mention of RTMP or live stream ingestion security

### P08: API Rate Limiting Per-User Implementation Gap
- **Category**: 入力検証・攻撃防御 (Input Validation & Attack Defense)
- **Severity**: 中 (Medium)
- **Location**: Section 7.2 Security, "API rate limiting: 100 requests/minute per user, 1000 requests/minute per IP"
- **Problem Description**: The design specifies per-user rate limiting (100 req/min) but does not detail the implementation mechanism. Key considerations missing: (1) How user identity is determined for rate limiting (JWT sub claim? user_id?), (2) Where rate limiting state is stored (Redis?), (3) How to handle unauthenticated requests (fall back to IP-based limiting only?), (4) Rate limit window reset behavior (sliding window vs. fixed window). Without explicit design, implementation may be inconsistent or bypassable.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of implementation details for per-user rate limiting (identity source, storage backend, window algorithm) and recommends explicit specification
  - △ (Partial): Mentions rate limiting concerns or Redis usage without specifically identifying the per-user implementation gap
  - × (Not Detected): No mention of rate limiting implementation details

### P09: Live Chat Content Moderation Not Addressed
- **Category**: 入力検証・攻撃防御 (Input Validation & Attack Defense)
- **Severity**: 軽微 (Low)
- **Location**: Section 3.1 Service Layer, "Chat Service: Real-time messaging with WebSocket"
- **Problem Description**: The design includes a real-time chat service with WebSocket but does not address content moderation or abuse prevention (spam, profanity, harassment). While not a direct security vulnerability, lack of moderation can lead to platform abuse and user safety issues. The design should consider: (1) Content filtering (profanity, spam detection), (2) User reporting mechanism, (3) Rate limiting for chat messages, (4) Moderation dashboard for administrators.
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of chat content moderation or abuse prevention mechanisms
  - △ (Partial): Mentions chat security (e.g., message encryption, authentication) without addressing content moderation
  - × (Not Detected): No mention of chat moderation or abuse prevention

## Bonus Problem List

Bonus points are awarded if the reviewer detects the following issues, which are not explicitly embedded in the design document but represent implicit security risks:

| ID | Category | Content | Bonus Condition |
|----|---------|---------|-----------------|
| B01 | 脅威モデリング (Threat Modeling) | Lack of STRIDE threat modeling for each service component (Spoofing, Tampering, Repudiation, Information Disclosure, DoS, Elevation of Privilege) | Points out the absence of systematic threat modeling or recommends STRIDE analysis |
| B02 | データ保護 (Data Protection) | PII classification and data retention policy not defined (email, display_name, payment history, viewing history) | Identifies the need for PII classification or data retention/deletion policy |
| B03 | インフラ・依存関係・監査 (Infrastructure, Dependencies, Audit) | Security audit logging design missing (authentication failures, permission changes, subscription changes, video deletions) | Points out the lack of security audit logging for critical operations |
| B04 | 入力検証・攻撃防御 (Input Validation & Attack Defense) | CSRF protection not specified for state-changing APIs (video upload, subscription management) | Identifies the need for CSRF protection (CSRF tokens, SameSite cookie attribute) |
| B05 | データ保護 (Data Protection) | Encryption in transit for internal service communication not specified (service-to-service communication within Kubernetes cluster) | Points out the lack of mTLS or encryption for internal service mesh communication |
| B06 | インフラ・依存関係・監査 (Infrastructure, Dependencies, Audit) | Dependency vulnerability management policy not defined (npm/Go module updates, security scanning) | Identifies the need for dependency scanning or vulnerability management process |
| B07 | 入力検証・攻撃防御 (Input Validation & Attack Defense) | Input validation strategy not specified (video title/description length limits, file type validation, SQL injection prevention) | Points out the absence of input validation design or recommends validation framework |
| B08 | 認証・認可設計 (Authentication & Authorization Design) | Session invalidation mechanism not specified for logout endpoint (JWT revocation list or blacklist) | Identifies the challenge of JWT invalidation and recommends revocation strategy (Redis blacklist, short TTL) |
| B09 | データ保護 (Data Protection) | PostgreSQL encryption at rest not specified (database volume encryption, TDE) | Points out the lack of database encryption at rest design |
| B10 | インフラ・依存関係・監査 (Infrastructure, Dependencies, Audit) | Kubernetes RBAC design not specified (service account permissions, namespace isolation) | Identifies the need for Kubernetes RBAC configuration to limit service privileges |
