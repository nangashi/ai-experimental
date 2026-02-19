# Security Design Review: TaskFlow システム設計書

## Scoring Table

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | No documented threat analysis; multiple attack vectors unaddressed (session hijacking, privilege escalation, data exfiltration) |
| Authentication & Authorization Design | 1 | Critical JWT storage vulnerability in localStorage enables XSS-based account takeover; no refresh token mechanism |
| Data Protection | 2 | No encryption at rest specified for sensitive data; missing data retention/deletion policies and privacy controls |
| Input Validation Design | 3 | Basic validation library mentioned but no comprehensive injection prevention strategy or file upload security controls |
| Infrastructure & Dependencies | 3 | No secret management solution specified; dependency security scanning and update policies missing |
| **Overall** | **2.2** | |

---

## Critical Issues

### 1. JWT Token Storage in localStorage Enables Account Takeover

**Problem**: Section 5 (API設計 > 認証・認可方式) states "トークン格納: ブラウザのlocalStorageに保存" with 24-hour expiration. This creates two critical vulnerabilities:

1. **XSS Attack Vector**: localStorage is accessible to JavaScript, meaning any XSS vulnerability in the application allows attackers to steal tokens
2. **Extended Attack Window**: 24-hour token lifetime means a single stolen token provides prolonged unauthorized access

**Impact**: A single XSS vulnerability (e.g., in task description rendering, document filename display, or any user-controlled content) enables complete account takeover for 24 hours. Attacker can access all projects, documents, and perform actions as the victim.

**Countermeasures**:
- **Token Storage**: Use cookies with `HttpOnly` + `Secure` + `SameSite=Strict` attributes instead of localStorage
- **Token Lifetime**: Reduce access token to 15 minutes, implement refresh token mechanism (7-day expiration with automatic rotation)
- **Token Binding**: Bind tokens to IP address or user-agent for additional validation
- **Revocation**: Implement token revocation endpoint and server-side token blacklist (Redis-based)

**Relevant Sections**: 5. API設計 > 認証・認可方式

---

### 2. Missing Input Validation Strategy for File Uploads

**Problem**: Section 7 (非機能要件 > セキュリティ要件) only specifies "ファイルアップロードは10MB制限" but lacks comprehensive security controls for document uploads:

1. No MIME type validation (only `mime_type` column exists in schema)
2. No file extension whitelist
3. No virus/malware scanning
4. No filename sanitization policy
5. No content validation (e.g., validating image files are actual images)

**Impact**:
- **Malware Distribution**: Attackers can upload malicious executables disguised as documents
- **Path Traversal**: Unsanitized filenames like `../../etc/passwd` may allow file system access
- **Content-Type Confusion**: Uploading HTML files with JavaScript can create stored XSS vectors when accessed directly
- **Storage Exhaustion**: No per-user/per-organization quota enables DoS via storage consumption

**Countermeasures**:
- **Validation Pipeline**:
  1. Whitelist allowed MIME types (e.g., `application/pdf`, `image/png`, `image/jpeg`, `text/plain`)
  2. Validate file extension matches MIME type (check magic bytes, not just extension)
  3. Sanitize filenames: remove special characters, limit length to 255 bytes
  4. Implement content validation (e.g., use `sharp` library to verify images)
- **Security Scanning**: Integrate ClamAV or AWS GuardDuty for malware scanning
- **Storage Controls**:
  - Set per-user quota (e.g., 1GB for free plan, 10GB for pro)
  - Implement organization-level storage limits
  - Add rate limiting for upload endpoint (e.g., 100 uploads per hour per user)
- **S3 Security**:
  - Configure S3 bucket with `BlockPublicAccess` enabled
  - Use pre-signed URLs with short expiration (5 minutes) for downloads
  - Set `Content-Disposition: attachment` header to force download (prevent inline execution)

**Relevant Sections**: 5. API設計 > ドキュメント管理, 4. データモデル > Document, 7. 非機能要件 > セキュリティ要件

---

### 3. No Rate Limiting Design for Authentication and Critical Endpoints

**Problem**: Section 3 (アーキテクチャ設計 > 主要コンポーネントの責務) mentions "API Gateway: レート制限" but provides no details on rate limiting configuration, particularly for authentication endpoints.

**Impact**:
- **Brute Force Attacks**: Login endpoint (`/api/v1/auth/login`) is vulnerable to credential stuffing and password guessing
- **Account Enumeration**: Signup endpoint (`/api/v1/auth/signup`) can be used to enumerate existing email addresses
- **API Abuse**: No protection against automated scrapers or DoS attacks on resource-intensive endpoints

**Countermeasures**:
- **Authentication Endpoints**:
  - `/api/v1/auth/login`: 5 attempts per 15 minutes per IP, 3 attempts per 15 minutes per email
  - `/api/v1/auth/signup`: 3 attempts per hour per IP
  - Implement progressive delay (100ms → 500ms → 2s) after failed attempts
  - Add account lockout after 5 failures (30-minute duration, with unlock via email)
- **Global Limits**:
  - 100 requests per minute per authenticated user
  - 20 requests per minute per IP for unauthenticated requests
  - 1000 requests per hour per organization
- **Implementation**: Use `express-rate-limit` v7.1.0 with Redis store for distributed rate limiting
- **Response**: Return `429 Too Many Requests` with `Retry-After` header

**Relevant Sections**: 3. アーキテクチャ設計 > 主要コンポーネントの責務, 5. API設計 > 認証関連

---

### 4. Missing Encryption at Rest for Sensitive Data

**Problem**: Section 2 (技術スタック) and Section 7 (非機能要件 > セキュリティ要件) do not mention encryption at rest for:
- User password hashes (only bcrypt mentioned, not storage encryption)
- JWT tokens in Redis
- Documents in S3
- Database backups in PostgreSQL

**Impact**:
- **Database Breach**: If PostgreSQL instance is compromised, all user emails, organization data, and task contents are exposed in plaintext
- **Backup Exposure**: Unencrypted backups stored for 30 days create extended exposure window
- **S3 Breach**: Document files are accessible if S3 credentials are leaked

**Countermeasures**:
- **PostgreSQL**:
  - Enable AWS RDS encryption at rest using KMS (AES-256)
  - Encrypt automated backups and Read Replicas
- **Redis**:
  - Enable ElastiCache encryption at rest for session data
  - Enable in-transit encryption (TLS) for all Redis connections
- **S3**:
  - Enable server-side encryption with AWS KMS (SSE-KMS)
  - Use separate KMS keys per organization for tenant isolation
  - Enable default encryption on bucket
- **Key Management**:
  - Use AWS KMS with automatic key rotation (annual)
  - Implement IAM policies with least privilege access to KMS keys
  - Audit key usage via CloudTrail

**Relevant Sections**: 2. 技術スタック > データベース, 2. 技術スタック > インフラ・デプロイ環境, 7. 非機能要件 > セキュリティ要件

---

### 5. No Audit Logging Design for Security Events

**Problem**: Section 6 (実装方針 > ロギング方針) defines general logging (API calls, auth failures, DB errors) but lacks audit logging for security-critical events:

1. No specification for what to log (e.g., permission changes, data access, deletions)
2. No log retention policy beyond CloudWatch default (indefinite with cost concerns)
3. No log integrity protection (logs can be modified post-incident)
4. No alerting on suspicious patterns

**Impact**:
- **Incident Response Blind Spots**: Cannot trace unauthorized access or data exfiltration after breach
- **Compliance Failures**: GDPR Article 30 requires records of processing activities
- **Privilege Escalation**: No audit trail when user roles change (owner/admin assignment)
- **Data Deletion**: Cannot track who deleted projects, tasks, or documents

**Countermeasures**:
- **Events to Log**:
  - Authentication: login success/failure, logout, password reset, token refresh
  - Authorization: permission denied (403), role changes, organization membership changes
  - Data Access: project access, document downloads, sensitive data queries
  - Modifications: project/task creation/deletion, document uploads/deletions, organization settings changes
  - Admin Actions: user deactivation, plan changes, API key generation
- **Log Format**:
  ```json
  {
    "timestamp": "2026-02-10T12:34:56Z",
    "event_type": "document_download",
    "user_id": "uuid",
    "organization_id": "uuid",
    "resource_id": "document-uuid",
    "ip_address": "1.2.3.4",
    "user_agent": "...",
    "result": "success"
  }
  ```
- **Retention**: 90 days for security logs, 13 months for audit logs (compliance requirement)
- **Integrity**: Use CloudWatch Logs with S3 export and Glacier archival (immutable storage)
- **Alerting**: Configure CloudWatch alarms for:
  - 5+ failed login attempts from same IP in 5 minutes
  - Role changes to 'owner' or 'admin'
  - Bulk document downloads (>50 files in 1 hour)
  - API calls from unexpected geographic locations

**Relevant Sections**: 6. 実装方針 > ロギング方針

---

## Improvement Suggestions

### 6. CSRF Protection Not Specified for State-Changing Operations

**Suggestion**: Add CSRF token mechanism for all POST/PUT/DELETE API requests.

**Rationale**: Although JWT is used for authentication, if tokens are accessible via localStorage (current design), CSRF attacks combined with XSS can enable unauthorized state changes. Even with cookie-based tokens, CSRF protection is defense-in-depth.

**Countermeasures**:
- Implement double-submit cookie pattern or synchronizer token pattern
- Use `csurf` middleware (v1.11.0) or custom implementation
- Include CSRF token in request headers: `X-CSRF-Token`
- Validate token on all non-GET requests
- Alternative: If switching to cookie-based JWT, ensure `SameSite=Strict` is set

**Relevant Sections**: 5. API設計 > 認証・認可方式

---

### 7. SQL Injection Risk Despite ORM Usage

**Suggestion**: Establish guidelines for safe Sequelize query usage and prohibit raw SQL queries.

**Rationale**: Section 7 states "SQLインジェクション対策としてSequelize ORM使用" but ORMs don't prevent all SQL injection:
- Raw queries: `sequelize.query()` without bind parameters
- Unsafe operators: `$regex`, `$like` with user input
- Dynamic column names in `order` clause

**Countermeasures**:
- **Code Guidelines**:
  - Prohibit `sequelize.query()` without parameterized queries
  - Whitelist allowed column names for sorting/filtering
  - Use Sequelize operators (`Op.eq`, `Op.like`) instead of string concatenation
- **Code Review Checklist**: Require security review for all raw SQL usage
- **Static Analysis**: Integrate ESLint plugin to detect unsafe Sequelize patterns
- **Example Safe Pattern**:
  ```javascript
  // Unsafe
  await User.findAll({ where: { name: req.query.name } }); // If name is object

  // Safe
  await User.findAll({
    where: { name: { [Op.eq]: req.query.name } }
  });
  ```

**Relevant Sections**: 7. 非機能要件 > セキュリティ要件

---

### 8. Missing Secret Management Solution

**Suggestion**: Implement AWS Secrets Manager or Parameter Store for managing database credentials, API keys, and JWT signing secrets.

**Rationale**: Design does not specify how sensitive configuration is managed (DB passwords, JWT secret, AWS credentials, third-party API keys for Slack/GitHub/Google).

**Countermeasures**:
- **Secrets Storage**: Use AWS Secrets Manager for:
  - PostgreSQL master password
  - Redis AUTH token
  - JWT signing secret (rotate monthly)
  - OAuth client secrets (Slack, GitHub, Google)
  - Third-party API keys
- **Access Control**: Use IAM roles for EKS pods (avoid hardcoded credentials)
- **Rotation**: Enable automatic rotation for database credentials (90-day cycle)
- **Application Integration**:
  - Use AWS SDK to fetch secrets at runtime
  - Cache secrets in memory (with 5-minute TTL)
  - Handle secret rotation gracefully (retry with new secret on auth failure)
- **Development**: Use `.env` files for local development (never commit to Git; add to `.gitignore`)

**Relevant Sections**: 2. 技術スタック > インフラ・デプロイ環境

---

### 9. No Content Security Policy (CSP) Mentioned

**Suggestion**: Implement Content Security Policy headers to mitigate XSS attacks.

**Rationale**: Section 7 states "XSS対策としてReactのデフォルトエスケーピング利用" but React escaping is not sufficient:
- Unsafe usage: `dangerouslySetInnerHTML`
- Third-party script injection
- Inline event handlers

**Countermeasures**:
- **CSP Header Configuration**:
  ```
  Content-Security-Policy:
    default-src 'self';
    script-src 'self' https://cdn.cloudfront.net;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https://s3.amazonaws.com;
    connect-src 'self' https://api.taskflow.example;
    frame-ancestors 'none';
    base-uri 'self';
    form-action 'self';
  ```
- **Implementation**: Add CSP middleware in Express.js using `helmet` library (v7.1.0)
- **Nonce-based Scripts**: Use nonce for inline scripts instead of `unsafe-inline`
- **Reporting**: Configure `report-uri` to collect CSP violations for monitoring

**Relevant Sections**: 7. 非機能要件 > セキュリティ要件

---

### 10. Organization-Level Data Isolation Not Explicit

**Suggestion**: Document tenant isolation strategy to prevent cross-organization data access.

**Rationale**: Multi-tenant SaaS design (organizations sharing same DB) requires strict isolation. Current design shows `organization_id` foreign keys but doesn't specify enforcement mechanism.

**Countermeasures**:
- **Database-Level Isolation**:
  - Use PostgreSQL Row-Level Security (RLS) policies:
    ```sql
    CREATE POLICY org_isolation ON projects
    USING (organization_id = current_setting('app.current_org_id')::uuid);
    ```
  - Set session variable `app.current_org_id` on each request based on authenticated user
- **Application-Level Checks**:
  - Middleware to inject `organizationId` filter on all queries
  - Validate user's organization matches requested resource's organization
- **Testing**: Create integration tests to verify cross-organization access is blocked
- **S3 Key Prefixing**: Use format `s3://{bucket}/{organization_id}/{document_id}` to segregate files

**Relevant Sections**: 4. データモデル, 3. アーキテクチャ設計

---

### 11. No Dependency Vulnerability Scanning Policy

**Suggestion**: Establish automated dependency scanning and update procedures.

**Rationale**: Design lists specific library versions (Express v4, React v18, etc.) but no security update policy. Known vulnerabilities in dependencies are common attack vectors.

**Countermeasures**:
- **Automated Scanning**:
  - Integrate Dependabot (GitHub) or Snyk for automated vulnerability detection
  - Run `npm audit` in CI/CD pipeline (fail builds on high/critical vulnerabilities)
- **Update Policy**:
  - Security patches: Apply within 48 hours of disclosure
  - Major updates: Quarterly review and testing
  - Pin exact versions in `package-lock.json` to prevent unexpected updates
- **License Compliance**: Scan for restrictive licenses (GPL, AGPL) to avoid legal issues
- **SBOM Generation**: Maintain Software Bill of Materials (SBOM) for compliance and incident response

**Relevant Sections**: 2. 技術スタック > 主要ライブラリ, 6. 実装方針 > デプロイメント方針

---

### 12. Password Policy Not Defined

**Suggestion**: Define password strength requirements and storage parameters.

**Rationale**: Section 7 specifies "bcryptでハッシュ化(コスト係数10)" but lacks password complexity rules, preventing weak passwords.

**Countermeasures**:
- **Password Requirements**:
  - Minimum 12 characters
  - At least one uppercase, lowercase, number, and special character
  - Reject common passwords (use zxcvbn library for strength estimation)
  - Prevent password reuse (store last 5 password hashes)
- **Bcrypt Configuration**:
  - Increase cost factor to 12 (10 is outdated as of 2026)
  - Plan to increase to 13 in 2027 (adjust based on hardware performance)
- **Additional Security**:
  - Implement "forgot password" flow with time-limited tokens (1 hour expiration)
  - Require email verification for password reset
  - Notify users via email on password changes

**Relevant Sections**: 7. 非機能要件 > セキュリティ要件

---

### 13. No Idempotency Mechanism for Critical Operations

**Suggestion**: Implement idempotency keys for project/task creation and document uploads.

**Rationale**: Network retries or duplicate requests can create duplicate resources. For financial or critical operations (e.g., project creation with paid plans), duplicates cause data inconsistency.

**Countermeasures**:
- **Idempotency Key Header**: Require `Idempotency-Key` header (UUID) for POST requests
- **Storage**: Store processed keys in Redis with 24-hour TTL
- **Processing Logic**:
  1. Check if key exists in Redis
  2. If exists, return cached response (avoid re-execution)
  3. If not, execute operation and store result
- **Endpoints**: Apply to:
  - `/api/v1/projects` (POST)
  - `/api/v1/projects/:projectId/tasks` (POST)
  - `/api/v1/projects/:projectId/documents` (POST)
- **Concurrent Request Handling**: Use Redis SETNX for distributed locking

**Relevant Sections**: 5. API設計

---

## Confirmation Items

### 14. OAuth2.0 Security for External Integrations

**Reason**: Section 3 mentions "外部連携サービス: OAuth2.0フロー、Webhook処理" but provides no implementation details. OAuth2.0 has multiple security considerations requiring user confirmation.

**Options and Trade-offs**:

**Option A: Authorization Code Flow (Recommended)**
- **Description**: Standard flow with authorization code exchange
- **Security**: Most secure (token not exposed to browser)
- **Complexity**: Requires backend callback endpoint
- **Use Case**: Slack, GitHub, Google integrations

**Option B: PKCE (Proof Key for Code Exchange)**
- **Description**: Extension of Authorization Code Flow for public clients
- **Security**: Prevents authorization code interception
- **Requirement**: Mandatory for mobile apps, recommended for SPAs
- **Implementation**: Generate code verifier/challenge in frontend

**Key Decisions Needed**:
1. **Token Storage**: Where to store OAuth access tokens and refresh tokens?
   - Database (encrypted column) vs. Redis (TTL-based)
2. **Scope Management**: What scopes to request from each provider?
   - Slack: `chat:write`, `channels:read`
   - GitHub: `repo`, `read:org`
   - Google: `https://www.googleapis.com/auth/drive.readonly`
3. **Token Refresh**: How to handle expired access tokens?
   - Background job vs. on-demand refresh
4. **Webhook Verification**: How to validate webhook signatures?
   - Slack: Verify `X-Slack-Signature` header
   - GitHub: Verify `X-Hub-Signature-256` header

**Recommendation**: Confirm OAuth implementation details including token storage, scope requirements, and webhook security mechanisms.

---

### 15. Data Retention and GDPR Compliance

**Reason**: Design mentions "外部パートナーとの限定的な情報共有" (limited information sharing with external partners) and stores user email/name, but lacks GDPR compliance measures.

**Options and Trade-offs**:

**Option A: Automated Data Deletion (Strict Compliance)**
- **Description**: Automatically delete user data 30 days after account deletion
- **Compliance**: Meets GDPR "right to be forgotten"
- **Risk**: Permanent data loss, no recovery option
- **Implementation Complexity**: High (cascading deletes, S3 cleanup, backup exclusion)

**Option B: Soft Delete with Expiration (Balanced)**
- **Description**: Mark as deleted immediately, hard delete after 90-day grace period
- **Compliance**: Meets GDPR with "right to rectification" window
- **Risk**: Retained data still subject to breach exposure
- **Implementation Complexity**: Medium (scheduled cleanup job)

**Option C: Data Export Only (Minimal)**
- **Description**: Provide data export, manual deletion upon request
- **Compliance**: Does not meet GDPR automation requirements
- **Risk**: Legal liability in EU markets
- **Implementation Complexity**: Low

**Key Decisions Needed**:
1. **Data Retention Policy**: How long to retain deleted user data?
2. **Data Portability**: What format for data export (JSON, CSV, PDF)?
3. **Consent Management**: How to track user consent for data processing?
4. **Data Processing Agreement**: Required for external partners (Slack, GitHub, Google)?
5. **Geographic Restrictions**: Will EU users' data be restricted to EU regions?

**Recommendation**: Confirm data retention policy, GDPR compliance strategy, and consent management approach, especially for EU users.

---

## Positive Evaluation

### 16. Strong Foundation with Industry-Standard Technologies

**Strengths**:
- **Modern Tech Stack**: Node.js v20, React v18, PostgreSQL v16, Redis v7 are all recent, well-maintained versions with active security updates
- **Container Orchestration**: Kubernetes on EKS provides robust deployment isolation and scaling capabilities
- **HTTPS Enforcement**: "すべてのAPI通信はHTTPS経由" ensures transport layer security
- **Password Hashing**: bcrypt usage (though cost factor should increase to 12) is cryptographically sound
- **ORM Usage**: Sequelize protects against most SQL injection when used correctly
- **Backup Strategy**: 30-day PostgreSQL backups and S3 versioning provide data resilience

### 17. Comprehensive Testing Strategy

**Strengths**:
- **Multi-Layer Testing**: Unit (Jest, 80% coverage), integration (Supertest), E2E (Playwright), and performance (k6) testing covers security regressions
- **High Coverage Target**: 80% code coverage helps ensure error handling paths are tested

### 18. Clear Separation of Concerns

**Strengths**:
- **Layered Architecture**: API Gateway, Business Logic, Data Access layers enable security controls at each boundary
- **Service Segmentation**: Separate services for auth, project management, documents, notifications allow fine-grained access control

---

## Summary

**Overall Security Posture**: The design demonstrates basic security awareness (HTTPS, password hashing, ORM usage) but has **critical gaps in authentication mechanism, input validation, and data protection** that require immediate attention before production deployment.

**Top 3 Priorities**:
1. **Fix JWT Storage** (Critical Issue #1): Switch from localStorage to HttpOnly cookies with refresh token mechanism
2. **Implement File Upload Security** (Critical Issue #2): Add MIME validation, malware scanning, and storage quotas
3. **Add Rate Limiting** (Critical Issue #3): Protect authentication endpoints from brute force attacks

**Estimated Remediation Effort**: 3-4 weeks for critical issues, additional 2-3 weeks for improvement suggestions, assuming 2 engineers.
