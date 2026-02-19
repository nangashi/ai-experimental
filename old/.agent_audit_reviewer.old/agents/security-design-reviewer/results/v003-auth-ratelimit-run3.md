# Security Design Review: リアルタイム医療予約システム

## Critical Issues

### C01: JWT Token Storage in localStorage - XSS Vulnerability (CRITICAL)
**Severity**: Critical
**Category**: Information Disclosure, Authentication & Authorization Design

**Issue Description**:
Section 5.3 explicitly states "JWTトークンはlocalStorageに保存し" (JWT tokens are stored in localStorage). This is a critical security flaw that exposes authentication tokens to XSS attacks. If an attacker injects malicious JavaScript through any XSS vulnerability in the application, they can immediately steal all JWT tokens stored in localStorage, gaining full access to user accounts.

**Impact**:
- Complete account takeover if any XSS vulnerability exists
- Access to sensitive medical records and patient information
- Ability to create/modify appointments and medical records
- No defense-in-depth against XSS attacks

**Countermeasures**:
1. Store JWT tokens in httpOnly, Secure, SameSite cookies instead of localStorage
2. Implement proper CSRF protection (double-submit cookie or synchronizer token pattern)
3. Consider using short-lived access tokens with automatic refresh
4. Implement Content Security Policy (CSP) to mitigate XSS risks

**Reference**: Section 5.3 認証・認可方式

---

### C02: Stack Trace Exposure in Error Responses (CRITICAL)
**Severity**: Critical
**Category**: Information Disclosure

**Issue Description**:
Section 6.1 states "エラーメッセージには詳細なスタックトレースを含め、デバッグを容易にする" (Error messages include detailed stack traces to facilitate debugging). Exposing stack traces to end users in production is a critical information disclosure vulnerability that reveals:
- Internal system architecture and file paths
- Framework and library versions
- Database structure and query details
- Potential attack vectors

**Impact**:
- Attackers gain detailed information about system internals
- Facilitates reconnaissance for targeted attacks
- May expose sensitive database schema information
- Violates security best practices and compliance requirements (HIPAA, GDPR)

**Countermeasures**:
1. Return generic error messages to clients in production
2. Log detailed stack traces server-side only
3. Implement environment-based error handling (detailed errors only in development)
4. Use error codes/IDs that reference server-side logs for debugging
5. Implement proper error sanitization before external exposure

**Reference**: Section 6.1 エラーハンドリング方針

---

### C03: Sensitive Data Logging - Privacy Violation (CRITICAL)
**Severity**: Critical
**Category**: Data Protection, Audit, Repudiation

**Issue Description**:
Section 6.2 logging policy states "すべてのAPIリクエスト・レスポンスをINFOレベルでログ出力" and the example includes "requestBody": "{...}". This practice will log highly sensitive medical information including:
- Patient medical records (診断内容、処方薬、検査結果)
- Personal identifiable information (氏名、住所、電話番号、保険証番号)
- Authentication credentials if included in request bodies

**Impact**:
- HIPAA/GDPR compliance violations
- Unauthorized access to medical records through log files
- Potential data breach through log aggregation systems
- Privacy violations for patients
- Legal liability and regulatory penalties

**Countermeasures**:
1. Implement log sanitization to redact sensitive fields
2. Log only metadata (endpoint, userId, timestamp, status) not full request/response bodies
3. Create separate audit logs for compliance with restricted access
4. Implement field-level encryption for any sensitive data that must be logged
5. Define clear PII/PHI classification and logging policies
6. Ensure log access is restricted and audited

**Reference**: Section 6.2 ロギング方針

---

## Significant Issues

### S01: Missing Authorization Checks for Resource Access (HIGH)
**Severity**: High
**Category**: Authorization, Elevation of Privilege

**Issue Description**:
The API design (Section 5.1) lists endpoints like `GET /api/patients/{id}`, `GET /api/records/{id}`, `GET /api/patients/{id}/records` but the design document does not explicitly describe authorization checks to verify that:
- A patient can only access their own medical records
- A doctor can only access records for their assigned patients
- Administrative users are properly restricted

The design mentions "ロールベースアクセス制御（RBAC）により、エンドポイントごとに必要なロールを定義" but lacks specific ownership/membership verification logic.

**Impact**:
- Insecure Direct Object Reference (IDOR) vulnerabilities
- Patients could access other patients' medical records by manipulating IDs
- Unauthorized access to sensitive health information
- HIPAA compliance violations

**Countermeasures**:
1. Implement explicit authorization logic for each endpoint:
   - `GET /api/patients/{id}`: Verify requesting user owns this patient record OR is authorized medical staff
   - `GET /api/records/{id}`: Verify patient ownership OR doctor assignment
   - `GET /api/patients/{id}/records`: Verify patient ownership OR authorized access
2. Design attribute-based access control (ABAC) policies for healthcare context
3. Implement resource-level permission checks in service layer
4. Document authorization matrix showing which roles can access which resources under what conditions

**Reference**: Section 5.1 エンドポイント一覧, Section 5.3 認証・認可方式

---

### S02: Insufficient Rate Limiting Design (HIGH)
**Severity**: High
**Category**: Denial of Service

**Issue Description**:
While Section 3.2 mentions "レート制限（1分あたり100リクエスト）" at the API Gateway level, this global rate limit is insufficient for a medical system. The design lacks:
- Per-user/per-IP rate limiting
- Different rate limits for different endpoint categories
- Specific rate limiting for authentication endpoints (login, password reset)
- Account lockout policies after failed authentication attempts

**Impact**:
- Brute force attacks on authentication endpoints
- Account enumeration through password reset functionality
- Credential stuffing attacks
- Resource exhaustion through legitimate-looking traffic patterns
- Potential denial of service for legitimate users

**Countermeasures**:
1. Implement multi-layer rate limiting:
   - Global: 100 req/min (existing)
   - Per-user: 60 req/min for authenticated requests
   - Per-IP: 20 req/min for unauthenticated requests
2. Authentication endpoint specific limits:
   - Login: 5 attempts per 15 minutes per username/IP
   - Password reset: 3 attempts per hour per email
   - Token refresh: 10 attempts per hour per user
3. Implement progressive delays after failed authentication
4. Design account lockout after 5 failed login attempts (30-minute lockout)
5. Add CAPTCHA after 3 failed attempts

**Reference**: Section 3.2 主要コンポーネントの責務と依存関係

---

### S03: Missing Input Validation Design (HIGH)
**Severity**: High
**Category**: Input Validation & Attack Defense

**Issue Description**:
Section 7.2 mentions "外部入力はSpring Validationで検証し、SQLインジェクション対策としてPreparedStatementを使用" but lacks comprehensive input validation design. The document doesn't specify:
- Maximum length limits for text fields (diagnosis, prescription, lab_results are TEXT without limits)
- Format validation for structured data (email, phone, insurance_number)
- File upload restrictions (type, size, content validation) for document storage in S3
- API parameter validation rules
- Sanitization policies for output rendering

**Impact**:
- Potential for stored XSS through unvalidated medical records
- Buffer overflow or resource exhaustion through oversized inputs
- Malicious file uploads (malware, executable files)
- Data integrity issues from malformed inputs

**Countermeasures**:
1. Define explicit validation rules for all input fields:
   - TEXT fields: Maximum 10,000 characters for diagnosis/prescription/lab_results
   - Email: RFC 5322 format validation
   - Phone: Country-specific format validation
   - Insurance number: Format validation based on insurance type
2. File upload security design:
   - Allowed file types: PDF, JPEG, PNG only
   - Maximum file size: 10MB
   - Content-type verification (magic number check)
   - Virus scanning integration
   - Generate random filenames to prevent path traversal
3. Implement output encoding for all user-generated content
4. Design CORS policy with specific allowed origins (not wildcard)
5. Add Content Security Policy headers

**Reference**: Section 4.2 テーブル設計, Section 7.2 セキュリティ要件

---

### S04: Missing CSRF Protection Design (HIGH)
**Severity**: High
**Category**: Input Validation & Attack Defense, Tampering

**Issue Description**:
The design document does not mention CSRF (Cross-Site Request Forgery) protection mechanisms. With JWT tokens stored in localStorage (as stated in 5.3), the application is vulnerable to CSRF attacks where malicious sites can trigger authenticated requests.

**Impact**:
- Unauthorized appointment creation/cancellation
- Unauthorized modification of patient information
- Potential medical record tampering
- Account setting changes without user consent

**Countermeasures**:
1. Implement CSRF token validation for all state-changing operations (POST, PUT, DELETE)
2. Use SameSite cookie attribute if switching to cookie-based token storage
3. Require additional confirmation for critical operations (appointment cancellation, record modification)
4. Implement custom request headers that browsers won't send cross-origin

**Reference**: Section 5.3 認証・認可方式

---

## Moderate Issues

### M01: Weak Password Policy (MEDIUM)
**Severity**: Medium
**Category**: Authentication

**Issue Description**:
While the design specifies bcrypt hashing with cost factor 10, there is no mention of password complexity requirements, password history, or password expiration policies. Medical systems handling PHI typically require stronger password policies.

**Impact**:
- Weak passwords may be compromised through dictionary attacks
- Shared or reused passwords across accounts
- Compliance issues with HIPAA security requirements

**Countermeasures**:
1. Enforce password complexity: minimum 12 characters, uppercase, lowercase, numbers, special characters
2. Implement password history (prevent reuse of last 5 passwords)
3. Consider password expiration policy (90 days) for medical staff accounts
4. Implement breach password detection (check against known compromised password databases)
5. Support multi-factor authentication (MFA) especially for medical staff and admin roles

**Reference**: Section 7.2 セキュリティ要件

---

### M02: Missing Data Encryption at Rest (MEDIUM)
**Severity**: Medium
**Category**: Data Protection

**Issue Description**:
Section 7.2 specifies "すべての通信をTLS 1.3で暗号化する" for data in transit, but there is no explicit design for encryption of sensitive data at rest in PostgreSQL and S3. Medical records, PII, and insurance information should be encrypted at rest to comply with HIPAA and protect against database/storage breaches.

**Impact**:
- If database is compromised, all medical records are readable
- Compliance violations (HIPAA requires encryption at rest)
- Increased breach notification requirements
- Potential for insider threats

**Countermeasures**:
1. Enable PostgreSQL Transparent Data Encryption (TDE) or use AWS RDS encryption
2. Enable S3 bucket encryption (SSE-S3 or SSE-KMS)
3. Consider column-level encryption for highly sensitive fields (insurance_number, diagnosis, prescription)
4. Design key management strategy using AWS KMS
5. Document encryption standards and key rotation policies

**Reference**: Section 7.2 セキュリティ要件, Section 2.2 データベース, Section 2.3 インフラ

---

### M03: Insufficient Audit Logging Design (MEDIUM)
**Severity**: Medium
**Category**: Audit, Repudiation

**Issue Description**:
The logging design (Section 6.2) focuses on application logs but doesn't specify security audit logging requirements. For a medical system, explicit audit trails are required for:
- Authentication events (successful/failed logins, logouts)
- Authorization failures (access denied events)
- Sensitive data access (who viewed which patient records)
- Administrative actions (user role changes, system configuration)
- Data modifications (record creation/updates/deletions with before/after values)

**Impact**:
- Inability to detect security incidents
- Compliance violations (HIPAA requires audit trails)
- Forensic investigation difficulties
- No accountability for data access

**Countermeasures**:
1. Design separate security audit log stream with:
   - Authentication events (all login attempts, successes, failures)
   - Authorization failures (which user tried to access what resource)
   - Patient record access logs (doctor viewed patient X's record)
   - Administrative actions with before/after states
2. Ensure audit logs are immutable and tamper-evident
3. Implement log retention policy (minimum 6 years for HIPAA)
4. Design audit log access controls (separate from application logs)
5. Include IP address, user agent, geographic location in audit events

**Reference**: Section 6.2 ロギング方針

---

### M04: Missing Secret Management Design (MEDIUM)
**Severity**: Medium
**Category**: Infrastructure Security

**Issue Description**:
Section 6.4 mentions "環境変数はECS Task Definitionに記載し、AWS Systems Manager Parameter Storeから取得" but lacks detailed secret management design including:
- JWT signing key rotation policy
- Database credential rotation
- API key management for external services
- Secret access controls and audit
- Encryption of secrets in Parameter Store

**Impact**:
- Long-lived secrets increase compromise window
- Difficulty in rotating secrets after breach
- Potential secret exposure through misconfigured ECS tasks
- Insider threat risks

**Countermeasures**:
1. Use AWS Secrets Manager instead of Parameter Store for sensitive credentials (supports automatic rotation)
2. Design JWT signing key rotation policy (rotate every 90 days)
3. Enable automatic database credential rotation
4. Implement secret access auditing
5. Use IAM roles for service-to-service authentication where possible
6. Ensure all secrets are encrypted at rest and in transit

**Reference**: Section 6.4 デプロイメント方針

---

### M05: Token Expiration and Session Management Issues (MEDIUM)
**Severity**: Medium
**Category**: Authentication & Authorization

**Issue Description**:
Section 5.3 specifies "トークンの有効期限は1時間、リフレッシュトークンは30日間" but doesn't describe:
- How refresh tokens are validated and rotated
- Session invalidation on logout
- Token revocation mechanism for compromised accounts
- Maximum concurrent sessions per user

**Impact**:
- Stolen refresh tokens valid for 30 days
- No way to force logout of compromised sessions
- Zombie sessions after logout
- Potential for concurrent access from multiple locations

**Countermeasures**:
1. Implement refresh token rotation (issue new refresh token on each use, invalidate old one)
2. Design token blacklist/revocation registry using Redis
3. Implement proper logout (invalidate both access and refresh tokens)
4. Consider shorter refresh token lifetime for sensitive roles (medical staff: 7 days, admin: 24 hours)
5. Design maximum concurrent session limits
6. Implement "logout all sessions" functionality

**Reference**: Section 5.3 認証・認可方式

---

### M06: Missing Data Retention and Deletion Policies (MEDIUM)
**Severity**: Medium
**Category**: Data Protection, Privacy

**Issue Description**:
The design mentions database backups "30日間保持" but lacks comprehensive data retention and deletion policies for:
- Patient data deletion requests (GDPR right to be forgotten)
- Inactive account data retention
- Backup data retention for compliance
- Secure data deletion procedures

**Impact**:
- GDPR/privacy law compliance violations
- Inability to honor data deletion requests
- Excessive data retention increases breach impact
- Legal liability for improper data handling

**Countermeasures**:
1. Design data retention policies:
   - Active patient records: Indefinite (or per medical regulations)
   - Inactive accounts (no activity 3 years): Archive and anonymize
   - Backup retention: 6 years minimum for HIPAA compliance
2. Implement secure data deletion procedures (cryptographic erasure, multi-pass deletion)
3. Design patient data export functionality (GDPR data portability)
4. Create process for handling deletion requests with medical record retention requirements
5. Implement data minimization principles (only collect/retain necessary data)

**Reference**: Section 7.3 可用性・スケーラビリティ

---

## Minor Improvements

### I01: Consider API Versioning for Security Updates
**Category**: Infrastructure

**Observation**:
The API endpoints (Section 5.1) don't include version prefixes. When security vulnerabilities are discovered, versioned APIs allow graceful deprecation and migration.

**Recommendation**:
- Use versioned API paths: `/api/v1/appointments` instead of `/api/appointments`
- Design API deprecation policy
- Document security update process for breaking changes

**Reference**: Section 5.1 エンドポイント一覧

---

### I02: Consider Database Query Performance and DoS
**Category**: Denial of Service

**Observation**:
While performance goals are specified (Section 7.1), there's no mention of query timeout limits or protection against expensive database queries that could be triggered maliciously.

**Recommendation**:
- Design query timeout limits (5 seconds maximum)
- Implement pagination limits for list endpoints
- Add database query cost analysis in development
- Consider read replicas for expensive reporting queries

**Reference**: Section 7.1 パフォーマンス目標

---

### I03: Dependency Vulnerability Management
**Category**: Infrastructure & Dependencies

**Observation**:
Section 2.4 lists specific library versions but doesn't describe vulnerability management processes for third-party dependencies.

**Recommendation**:
- Implement automated dependency scanning in CI/CD pipeline (Snyk, OWASP Dependency-Check)
- Design process for security patch application
- Document approval process for library version updates
- Consider software bill of materials (SBOM) generation

**Reference**: Section 2.4 主要ライブラリ

---

## Positive Aspects

1. **Strong Cryptographic Choices**: TLS 1.3 and bcrypt with cost factor 10 are industry best practices
2. **Infrastructure Redundancy**: Multi-AZ database configuration provides good availability
3. **API Gateway Usage**: Centralized request handling enables security controls
4. **Structured Error Responses**: Consistent error format facilitates client-side handling (though stack traces should be removed)
5. **Database Backup Strategy**: Regular backups support disaster recovery

---

## Summary

This medical appointment system design has **3 critical security issues** that must be addressed before implementation:
1. JWT storage in localStorage (XSS vulnerability)
2. Stack trace exposure in error responses (information disclosure)
3. Sensitive data logging (privacy violations)

Additionally, there are **5 significant issues** requiring immediate attention:
- Missing authorization checks (IDOR vulnerabilities)
- Insufficient rate limiting (brute force attacks)
- Incomplete input validation design
- No CSRF protection
- (Covered in moderate: weak password policy)

The **6 moderate issues** should be addressed during implementation to meet HIPAA compliance requirements and security best practices, particularly around encryption at rest, audit logging, and secret management.

**Priority Actions**:
1. Change JWT storage mechanism to httpOnly cookies
2. Remove stack trace exposure from production error responses
3. Implement log sanitization for sensitive data
4. Design explicit authorization checks for all resource access endpoints
5. Implement comprehensive rate limiting including authentication endpoint protection
6. Complete input validation and CSRF protection design
