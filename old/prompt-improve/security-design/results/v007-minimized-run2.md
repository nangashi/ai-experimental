# Security Design Review - TaskFlow System

## Scoring Summary

| Criterion | Score (1-5) | Main Reason |
|-----------|-------------|-------------|
| Threat Modeling (STRIDE) | 2 | No explicit threat model; multiple STRIDE categories not addressed (spoofing via token storage, repudiation without audit logging, DoS without rate limiting) |
| Authentication & Authorization Design | 2 | Critical JWT storage vulnerability (localStorage + 24h expiration), no token refresh mechanism, no session revocation capability |
| Data Protection | 3 | Basic encryption for transit (HTTPS) and passwords (bcrypt), but no encryption at rest for S3 documents, no data retention/deletion policies, no privacy controls |
| Input Validation Design | 3 | Partial validation via express-validator and ORM, but no file type validation beyond MIME, no size validation for description fields, no output sanitization policy |
| Infrastructure & Dependencies | 3 | Third-party dependencies listed but no version pinning policy, no secret management solution (AWS Secrets Manager/Parameter Store), no security scanning in CI/CD |
| **Overall** | **2.6** | |

## 1. Critical Issues

### 1.1 JWT Token Storage Method Creates XSS Vulnerability Window
**Problem**: Section 5 specifies storing JWT tokens in browser localStorage with 24-hour expiration. This enables complete account takeover via any XSS vulnerability for the entire token lifetime.

**Impact**:
- A single XSS attack (e.g., malicious script in task description or document name) allows attacker to steal tokens from localStorage
- 24-hour validity period extends damage window significantly
- No token revocation mechanism means stolen tokens remain valid even after password change

**Countermeasures**:
1. **Cookie-based storage**: Use `httpOnly`, `secure`, `sameSite=Strict` cookies to prevent JavaScript access
2. **Short-lived tokens**: Reduce access token lifetime to 15 minutes
3. **Refresh token rotation**: Implement 7-day refresh tokens with rotation on each use
4. **Token revocation**: Add token blacklist in Redis with user logout/password change

**Relevant Sections**: 5. API Design > Authentication & Authorization

### 1.2 Missing Authorization Checks Enable Privilege Escalation
**Problem**: Design describes role-based access (owner > admin > member > guest) but provides no implementation details for permission checks on resource operations.

**Impact**:
- Guest users may be able to delete projects/tasks they shouldn't access
- Cross-organization data leakage (e.g., user A accessing organization B's projects via direct API calls with valid project IDs)
- Horizontal privilege escalation (member modifying owner-only organization settings)

**Countermeasures**:
1. **Middleware implementation**: Create `checkProjectAccess(requiredRole)` middleware for all `/api/v1/projects/:id/*` endpoints
2. **Resource ownership validation**:
   ```javascript
   // Example implementation
   const project = await Project.findByPk(req.params.id);
   if (project.organization_id !== req.user.organization_id) {
     return res.status(403).json({ error: 'FORBIDDEN' });
   }
   ```
3. **Explicit permission matrix**: Document which roles can perform which operations (e.g., only owner/admin can DELETE projects)
4. **Unit tests for authorization**: Test each endpoint with all role levels to verify access control

**Relevant Sections**: 5. API Design > Authentication & Authorization, 4. Data Model

### 1.3 File Upload Lacks Security Controls
**Problem**: Document upload endpoint (`POST /api/v1/projects/:projectId/documents`) has only 10MB size limit. No file type validation, no malware scanning, no access control on S3 objects.

**Impact**:
- Malicious file uploads (`.exe`, `.sh` scripts) can be distributed to team members
- Uploaded HTML files with JavaScript can bypass CSP if served from S3 with incorrect MIME types
- S3 objects may be publicly accessible if bucket policy misconfigured
- Filename injection attacks (e.g., `../../etc/passwd` in S3 key generation)

**Countermeasures**:
1. **File type whitelist**: Allow only document types (PDF, DOCX, TXT, PNG, JPG, etc.) via MIME type and magic number validation
2. **S3 security settings**:
   - Block public access at bucket level
   - Use pre-signed URLs (15-minute expiration) for downloads
   - Set `Content-Disposition: attachment` to force download, not inline rendering
3. **Filename sanitization**: Strip path traversal characters, limit to alphanumeric + safe characters
4. **Malware scanning**: Integrate ClamAV or AWS S3 Object Lambda for virus scanning
5. **Upload permission check**: Verify user has write access to project before allowing upload

**Relevant Sections**: 5. API Design > Document Management, 7. Non-functional Requirements > Security

### 1.4 No Audit Logging for Security Events
**Problem**: Logging policy (Section 6) covers operational events but omits security-critical events like permission changes, failed authorization attempts, data exports, or admin actions.

**Impact**:
- No forensic trail after security incident (e.g., who deleted all projects in organization?)
- Insider threats undetectable (e.g., admin exfiltrating all documents)
- Compliance violations (GDPR Article 30 requires logging of personal data access)

**Countermeasures**:
1. **Security event types to log**:
   - Authentication (login/logout, failed attempts with IP)
   - Authorization failures (403 responses with user ID, resource ID, attempted action)
   - Resource modifications (project/task deletion, organization settings changes)
   - Data exports (document downloads, API bulk queries)
   - Role changes (user promoted to admin)
2. **Immutable audit log storage**: Use separate CloudWatch Logs stream with retention policy (7 years for compliance)
3. **Structured logging format**: Include `event_type`, `user_id`, `resource_id`, `action`, `ip_address`, `timestamp`
4. **Alerting**: Configure CloudWatch Alarms for suspicious patterns (e.g., 10+ failed logins in 5 minutes)

**Relevant Sections**: 6. Implementation > Logging Policy

## 2. Improvement Suggestions

### 2.1 Add Rate Limiting to Prevent Brute-Force and DoS
**Suggestion**: Implement per-endpoint rate limiting, especially for authentication and resource-intensive operations.

**Rationale**:
- Login endpoint (`POST /api/v1/auth/login`) vulnerable to credential stuffing attacks
- No protection against automated task creation spam or API abuse
- Document upload endpoint could be abused to exhaust S3 storage quota

**Countermeasures**:
1. **express-rate-limit configuration** (v7.1.0):
   - `/api/v1/auth/login`: 5 attempts per 15 minutes per IP
   - `/api/v1/auth/signup`: 3 attempts per hour per IP
   - `/api/v1/projects/:projectId/documents`: 20 uploads per hour per user
   - Global limit: 1000 requests per hour per user
2. **Account lockout**: Temporarily lock user account after 5 failed login attempts (30-minute cooldown)
3. **CAPTCHA**: Add reCAPTCHA to signup/login after 2 failed attempts
4. **Cost-based limits**: Tie rate limits to organization plan (free: 100 API calls/hour, pro: 1000, enterprise: unlimited)

**Relevant Sections**: 3. Architecture Design > API Gateway Layer, 7. Non-functional Requirements > Performance

### 2.2 Implement Dependency Security Scanning
**Suggestion**: Add automated vulnerability scanning for Node.js dependencies in CI/CD pipeline.

**Rationale**:
- Project uses 10+ third-party libraries (Express, Passport, multer, etc.) with potential vulnerabilities
- No mention of dependency update policy or security monitoring
- CVE-2024-XXXX in jsonwebtoken v8.x could compromise all user tokens

**Countermeasures**:
1. **GitHub Dependabot**: Enable automated vulnerability alerts and security updates
2. **npm audit in CI**: Fail builds on high/critical vulnerabilities (`npm audit --audit-level=high`)
3. **SBOM generation**: Generate Software Bill of Materials using `cyclonedx-npm` for compliance
4. **Version pinning**: Use exact versions in `package.json` (not `^` or `~` ranges) and commit `package-lock.json`
5. **Regular updates**: Schedule monthly dependency review and update cycle

**Relevant Sections**: 2. Technology Stack > Main Libraries, 6. Implementation > Deployment

### 2.3 Add CSRF Protection for State-Changing Operations
**Suggestion**: Implement CSRF tokens for all non-GET API requests.

**Rationale**:
- Cookie-based authentication (recommended in 1.1) makes application vulnerable to CSRF attacks
- Attacker can craft malicious page that sends `DELETE /api/v1/projects/:id` on behalf of authenticated user
- No mention of `SameSite` cookie attribute or CSRF token validation

**Countermeasures**:
1. **Double-submit cookie pattern**:
   - Generate random CSRF token on login, send as both cookie and response body
   - Require client to send token in `X-CSRF-Token` header for POST/PUT/DELETE
   - Validate header matches cookie on server side
2. **Synchronizer token pattern (alternative)**:
   - Store CSRF token in Redis session
   - Validate against session on each request
3. **SameSite cookie**: Set `SameSite=Strict` on authentication cookies (already recommended in 1.1)
4. **Library**: Use `csurf` middleware (or newer alternative like `@edge-csrf/express`)

**Relevant Sections**: 5. API Design > Authentication

### 2.4 Encrypt Sensitive Data at Rest
**Suggestion**: Enable server-side encryption for S3 documents and consider encryption for sensitive database columns.

**Rationale**:
- Design mentions documents may contain confidential project information
- S3 bucket compromise (misconfigured IAM policy) would expose all documents
- Database backup files contain unencrypted user data (names, emails, task descriptions)

**Countermeasures**:
1. **S3 encryption**: Enable SSE-S3 (AES-256) or SSE-KMS for compliance requirements
2. **Database field encryption**: Encrypt `User.email`, `Task.description` using application-level encryption (e.g., `@47ng/codec` library with KMS-managed keys)
3. **Encryption key rotation**: Configure AWS KMS automatic key rotation (yearly)
4. **Backup encryption**: Ensure RDS automated backups use encryption at rest

**Relevant Sections**: 2. Technology Stack > Infrastructure, 7. Non-functional Requirements > Security

### 2.5 Define Data Retention and Deletion Policies
**Suggestion**: Document data lifecycle policies for user data, especially for GDPR compliance.

**Rationale**:
- No policy for deleting user data after account closure
- Task/document history may accumulate indefinitely (storage cost and privacy risk)
- GDPR "right to be forgotten" requires complete data deletion within 30 days

**Countermeasures**:
1. **Soft delete implementation**:
   - Add `deleted_at` column to User, Project, Task, Document tables
   - Exclude soft-deleted records from queries (`WHERE deleted_at IS NULL`)
2. **Hard delete schedule**:
   - Permanently delete soft-deleted records after 30 days via scheduled Lambda function
   - Delete associated S3 objects using lifecycle rules
3. **User data export**: Implement `GET /api/v1/users/me/export` endpoint to provide data portability
4. **Retention policy documentation**:
   - Active projects: Retained indefinitely
   - Closed projects: Retained for 2 years, then soft-deleted
   - Deleted user accounts: All data hard-deleted after 30 days

**Relevant Sections**: 4. Data Model, 7. Non-functional Requirements > Security

## 3. Confirmation Items

### 3.1 Secret Management Strategy
**Question**: How will database passwords, JWT signing keys, and third-party API credentials be managed in production?

**Options**:
1. **AWS Secrets Manager**: Automatic rotation for RDS passwords, versioned secret storage, audit trail ($0.40/secret/month)
2. **AWS Systems Manager Parameter Store**: Free for standard parameters, integrated with ECS/EKS, no automatic rotation
3. **Environment variables**: Simplest approach but secrets exposed in EKS manifests and container inspect

**Trade-offs**:
- Secrets Manager provides rotation but adds infrastructure cost
- Parameter Store requires manual rotation scripts
- Environment variables acceptable for low-sensitivity environments (development/staging) but risky for production

**Recommendation**: Use Secrets Manager for production database passwords and JWT keys; Parameter Store for non-critical configs (API endpoints, feature flags).

### 3.2 Multi-Factor Authentication Requirement
**Question**: Should MFA be enforced for admin/owner roles or optional for all users?

**Options**:
1. **Mandatory for admin/owner**: Reduces risk of account takeover for privileged accounts
2. **Optional for all users**: Better user experience but lower security baseline
3. **Conditional MFA**: Require MFA when accessing from new device/IP

**Trade-offs**:
- Mandatory MFA increases security but may frustrate users (support burden for recovery codes)
- Optional MFA requires careful UX design to encourage adoption
- Conditional MFA balances security and usability but adds implementation complexity

**Recommendation**: Mandate MFA for owner/admin roles; make it optional with incentives (e.g., priority support) for members.

### 3.3 External API Webhook Validation
**Question**: Section 3 mentions webhook processing for external services (Slack, GitHub). How will webhook authenticity be verified?

**Options**:
1. **HMAC signature validation**: Each service signs payloads with shared secret (GitHub: `X-Hub-Signature-256`, Slack: `X-Slack-Signature`)
2. **IP allowlisting**: Restrict webhook endpoints to known service IP ranges
3. **Timestamp validation**: Reject webhooks older than 5 minutes to prevent replay attacks

**Trade-offs**:
- HMAC is standard practice but requires storing shared secrets securely
- IP allowlisting fragile (service IP ranges change) and ineffective against compromised infrastructure
- Timestamp validation alone insufficient without signature check

**Recommendation**: Implement HMAC signature validation for all webhook endpoints; add timestamp check as defense-in-depth.

## 4. Positive Evaluation

### 4.1 Secure Password Handling
**Strength**: Design specifies bcrypt with cost factor 10 for password hashing (Section 7). This is industry best practice and resistant to brute-force attacks.

**Rationale**: Bcrypt's adaptive cost factor ensures passwords remain secure as computing power increases. Cost factor 10 provides good balance between security and performance (~100ms per hash).

### 4.2 HTTPS Enforcement for All Communications
**Strength**: All API communication required over HTTPS (Section 7), preventing man-in-the-middle attacks.

**Rationale**: TLS encryption protects JWT tokens, passwords, and sensitive project data in transit. Combined with HSTS headers (though not mentioned), this provides strong transport security.

### 4.3 ORM-Based SQL Injection Prevention
**Strength**: Use of Sequelize ORM (Section 2) provides parameterized queries by default, mitigating SQL injection risks.

**Rationale**: ORM abstracts direct SQL construction, reducing likelihood of injection vulnerabilities. However, raw query usage should still be audited.

### 4.4 Comprehensive Test Strategy
**Strength**: Test plan includes integration tests for API endpoints (Section 6), which should cover authentication/authorization flows.

**Rationale**: Supertest-based integration tests can verify that unauthorized users receive 403 responses, ensuring security controls are tested before deployment.

---

**Overall Assessment**: The design has a solid foundation (HTTPS, bcrypt, ORM) but contains critical vulnerabilities in authentication (localStorage JWT), authorization (missing implementation details), and operational security (no audit logging, rate limiting). Addressing the 4 critical issues and 5 improvement suggestions would elevate the security posture from "moderate risk" to "production-ready".
