# Answer Key - Round 016

## Execution Conditions
- **Perspective**: security
- **Target**: design
- **Embedded Problems**: 10

## Embedded Problems

### P01: JWT Token Storage in localStorage
- **Category**: Authentication & Authorization Design (Data Protection)
- **Severity**: Critical
- **Location**: Section 5 (API Design) - Token Storage specification
- **Problem Description**: The design specifies storing JWT tokens in browser localStorage, which is vulnerable to XSS attacks. If an attacker can inject malicious JavaScript, they can steal tokens and impersonate users. This is particularly concerning for a CRM platform handling sensitive customer data.
- **Detection Criteria**:
  - ○ (Detected): Explicitly identifies the risk of JWT storage in localStorage with XSS vulnerability concern, or recommends httpOnly cookies as alternative, or mentions the inability to protect tokens from JavaScript access
  - △ (Partial): Mentions general XSS risks or token storage concerns without specifically linking localStorage vulnerability to XSS token theft
  - × (Not Detected): No mention of JWT storage security issues

### P02: Insufficient Password Reset Token Expiration
- **Category**: Authentication & Authorization Design
- **Severity**: Medium
- **Severity**: Medium
- **Location**: Section 5 (API Design) - POST /api/auth/password-reset endpoint
- **Problem Description**: Password reset tokens are valid for only 1 hour, which might seem reasonable, but the design doesn't specify single-use enforcement, rate limiting on reset requests, or account lockout mechanisms. This creates potential for account takeover attacks through brute force or token reuse.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing single-use token enforcement, lack of rate limiting on password reset endpoint, or suggests account lockout mechanisms for repeated reset attempts
  - △ (Partial): Mentions general password reset security concerns or token validity period without specific mechanism gaps
  - × (Not Detected): No mention of password reset security issues

### P03: Missing Authorization Checks on Resource Modification
- **Category**: Authentication & Authorization Design (Authorization Model)
- **Severity**: Critical
- **Location**: Section 5 (API Design) - PUT /api/deals/:id and DELETE /api/deals/:id endpoints
- **Problem Description**: The design explicitly states "No ownership verification - any user in the tenant can update any deal" and "No ownership verification - any user in the tenant can delete any deal." This violates the principle of least privilege. While tenant-level isolation exists, role-based access control (RBAC) within the tenant is missing. A regular user should not be able to modify/delete deals owned by managers or other users without proper authorization.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of ownership verification or RBAC within tenant for deal updates/deletions, mentions horizontal privilege escalation risk, or recommends resource-level authorization checks
  - △ (Partial): Mentions general authorization concerns or API security without specifically addressing the missing ownership checks on PUT/DELETE operations
  - × (Not Detected): No mention of authorization issues on deal modification endpoints

### P04: OAuth Token Storage in Plain Text
- **Category**: Data Protection (Credentials Management)
- **Severity**: Critical
- **Location**: Section 4 (Data Model) - email_credentials table and Section 5 - POST /api/integrations/email/connect
- **Problem Description**: OAuth access tokens and refresh tokens for Gmail/Outlook are stored as TEXT in the database without encryption. If the database is compromised, attackers gain access to users' email accounts. These tokens should be encrypted at rest using application-level encryption or a secrets management service like AWS Secrets Manager.
- **Detection Criteria**:
  - ○ (Detected): Identifies the lack of encryption for OAuth tokens in the database, recommends encryption at rest for access_token/refresh_token fields, or suggests using secrets management services
  - △ (Partial): Mentions general credential storage concerns or encryption requirements without specifically addressing OAuth token encryption
  - × (Not Detected): No mention of OAuth token storage security

### P05: Insecure File Upload ACL Configuration
- **Category**: Data Protection (Information Disclosure)
- **Severity**: Critical
- **Location**: Section 5 (API Design) - POST /api/files/upload endpoint
- **Problem Description**: The design specifies that files are stored in S3 with "public-read ACL," making all uploaded files publicly accessible. This is a severe information disclosure risk for a CRM platform where files may contain sensitive customer data, contracts, or proposals. Files should use private ACLs with presigned URLs for authorized access.
- **Detection Criteria**:
  - ○ (Detected): Identifies the public-read ACL as a security issue, mentions information disclosure risk for sensitive files, or recommends private S3 buckets with presigned URLs or access control
  - △ (Partial): Mentions general S3 security concerns or file access control without specifically addressing the public-read ACL problem
  - × (Not Detected): No mention of S3 file access security

### P06: Missing CSRF Protection
- **Category**: Input Validation Design (CSRF)
- **Severity**: Medium
- **Location**: Section 5 (API Design) - State-changing endpoints (POST, PUT, DELETE)
- **Problem Description**: The API design does not mention CSRF protection mechanisms. While using JWT Bearer tokens provides some protection, if the application also uses cookies for any state management or if tokens are accessible via JavaScript (as they are in localStorage), CSRF attacks remain possible. The design should explicitly include CSRF tokens or SameSite cookie attributes.
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of CSRF protection mechanisms, mentions the need for CSRF tokens or SameSite cookie attributes, or discusses CSRF risk in the context of state-changing API endpoints
  - △ (Partial): Mentions general API security or token-based authentication without specifically addressing CSRF protection
  - × (Not Detected): No mention of CSRF protection

### P07: Webhook Secret Generation and Management
- **Category**: Authentication & Authorization Design (API Security)
- **Severity**: Medium
- **Location**: Section 4 (Data Model) - webhooks table and Section 5 - POST /api/webhooks endpoint
- **Problem Description**: The design mentions that webhooks have a "secret (VARCHAR, for HMAC signature)" but doesn't specify how secrets are generated, their entropy requirements, rotation policies, or how they're securely transmitted to customers. Weak secret generation or insecure transmission could allow attackers to forge webhook payloads.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing secret generation standards (cryptographically secure random generation), lack of secret rotation policy, or insecure secret transmission concerns
  - △ (Partial): Mentions general webhook security or HMAC signature concerns without specific secret management requirements
  - × (Not Detected): No mention of webhook secret security

### P08: Insufficient Input Validation for File Uploads
- **Category**: Input Validation Design
- **Severity**: Medium
- **Location**: Section 3 (Architecture Design) - File Upload Service description
- **Problem Description**: The design specifies file size limits (10MB per file, 50MB per request) but does not mention file type validation, content scanning for malware, or filename sanitization. This creates risks of malicious file uploads, path traversal attacks via filenames, or stored XSS through HTML file uploads.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing file type validation, lack of malware scanning, missing filename sanitization, or mentions risks of malicious file uploads and stored XSS
  - △ (Partial): Mentions general file upload security concerns without specific validation requirements
  - × (Not Detected): No mention of file upload input validation

### P09: Missing Rate Limiting on Authentication Endpoints
- **Category**: Threat Modeling (DoS Protection)
- **Severity**: Medium
- **Location**: Section 5 (API Design) - POST /api/auth/login and POST /api/auth/password-reset endpoints
- **Problem Description**: The design does not specify rate limiting for authentication endpoints. The system uses Redis which could support rate limiting, but no rate limiting strategy is defined. This exposes the system to brute force attacks on login and password reset abuse. The design mentions "Redis (session storage, rate limiting, task queue)" but doesn't implement rate limiting in the API design.
- **Detection Criteria**:
  - ○ (Detected): Identifies the absence of rate limiting on authentication endpoints, mentions brute force attack risks, or notes the contradiction between mentioning rate limiting in tech stack but not implementing it in API design
  - △ (Partial): Mentions general rate limiting or authentication security concerns without specifically addressing the missing implementation
  - × (Not Detected): No mention of rate limiting for authentication

### P10: Single-node Redis Deployment Risk
- **Category**: Infrastructure & Dependencies Security (Availability & Data Loss)
- **Severity**: Medium
- **Location**: Section 7 (Non-functional Requirements) - Availability section
- **Problem Description**: The design specifies "Redis: Single-node deployment (non-clustered)" for session storage and rate limiting. A single Redis failure would cause all users to be logged out and lose session state, and rate limiting would fail open (allowing unlimited requests). For a SaaS platform targeting 99.9% uptime, this is a significant availability risk. Redis should use Redis Sentinel or Redis Cluster for high availability.
- **Detection Criteria**:
  - ○ (Detected): Identifies the single-node Redis deployment as an availability risk, mentions session loss or rate limiting failure implications, or recommends Redis Sentinel/Cluster for HA
  - △ (Partial): Mentions general Redis availability or infrastructure redundancy concerns without specifically addressing the single-node limitation
  - × (Not Detected): No mention of Redis deployment architecture risks

## Bonus Problems

Bonus problems are not included in the primary answer key but can provide additional points if detected.

| ID | Category | Content | Bonus Condition |
|----|---------|---------|----------------|
| B01 | Audit Logging | Missing audit trail for sensitive operations (deal deletion, user role changes, data exports) | Identifies the absence of comprehensive audit logging for compliance requirements (SOC 2, GDPR) |
| B02 | Data Protection | Email integration service logs may contain sensitive email content without redaction | Mentions the risk of logging sensitive data from email sync operations |
| B03 | Tenant Isolation | Application-level tenant isolation via middleware could be bypassed if middleware is misconfigured or bypassed | Identifies risks in application-level (vs database-level) tenant isolation enforcement |
| B04 | Encryption in Transit | No mention of TLS version requirements or cipher suite configuration for API traffic | Recommends specific TLS versions (TLS 1.2+) or strong cipher suites |
| B05 | Database Connection Security | Database connection credentials stored in environment variables without secrets manager | Suggests using AWS Secrets Manager or similar for database credentials |
| B06 | Elasticsearch Security | No mention of Elasticsearch authentication, encryption, or access control | Identifies missing authentication/authorization for Elasticsearch cluster |
| B07 | Third-party Integration Security | Axios HTTP client for third-party integrations without timeout or certificate validation configuration | Mentions risks of SSRF or hanging connections in third-party API calls |
| B08 | Password Policy | No password complexity requirements specified (length, special characters) | Recommends explicit password policy beyond bcrypt hashing |
| B09 | Multi-factor Authentication | No MFA support for admin or high-privilege accounts | Suggests implementing MFA for admin/manager roles |
| B10 | JWT Algorithm Specification | No specification of JWT signing algorithm (e.g., RS256 vs HS256) | Recommends using asymmetric algorithms (RS256) over symmetric (HS256) for JWT signing |
