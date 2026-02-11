# Answer Key - Round 009

## Execution Context
- **Perspective**: security
- **Target**: design
- **Domain**: Enterprise Content Management System (Legal/Financial)
- **Embedded Problems**: 10

## Embedded Problems

### P01: Password Storage - Missing Key Stretching
- **Category**: Data Protection (Authentication Credentials)
- **Severity**: Critical
- **Location**: Section 4 (Data Model) - users table, password_hash and salt columns
- **Problem Description**: The design specifies password_hash and salt storage but does not specify the hashing algorithm. Without explicit use of key stretching algorithms (bcrypt, Argon2, PBKDF2), the system is vulnerable to brute-force attacks if the database is compromised. Simple hash functions (SHA-256, MD5) with salt are insufficient for password security.
- **Detection Criteria**:
  - ○ (Detected): Points out that password hashing algorithm is not specified AND recommends key stretching algorithms (bcrypt, Argon2, PBKDF2) or explicitly warns against using fast hash functions for passwords
  - △ (Partial): Mentions password hashing or encryption without specifying key stretching algorithms, OR mentions hashing algorithm selection without connecting to password-specific security requirements
  - × (Undetected): No mention of password hashing algorithm or key stretching

### P02: JWT Token Storage - Client-Side Security Gap
- **Category**: Authentication & Authorization Design
- **Severity**: High
- **Location**: Section 3 (Architecture) - Data Flow, and Section 5 (API Design) - Authentication Endpoints
- **Problem Description**: The design does not specify where JWT tokens (access and refresh tokens) should be stored on the client side. Storing JWTs in localStorage makes them vulnerable to XSS attacks. httpOnly cookies with secure flags are the recommended approach for web applications, but this is not mentioned.
- **Detection Criteria**:
  - ○ (Detected): Points out the lack of client-side JWT storage specification AND recommends httpOnly/secure cookies OR explicitly warns against localStorage for token storage
  - △ (Partial): Mentions JWT security or token management without addressing client-side storage, OR mentions XSS risks generally without connecting to JWT storage
  - × (Undetected): No mention of client-side token storage security

### P03: Input Validation - Missing Specification
- **Category**: Input Validation Design
- **Severity**: High
- **Location**: Section 6 (Implementation Guidelines) - No input validation section
- **Problem Description**: The design does not include input validation guidelines. Without explicit validation rules for file uploads (file type whitelist, size limits, content inspection), API parameters, and user inputs, the system is vulnerable to injection attacks, malicious file uploads, and data integrity issues.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of input validation guidelines AND recommends specific validation strategies (file type whitelist, parameter validation, size limits, content inspection for uploads)
  - △ (Partial): Mentions validation generally or specific attack vectors (injection, upload risks) without comprehensive validation design guidance
  - × (Undetected): No mention of input validation requirements

### P04: Encryption Scope - Elasticsearch Data Not Encrypted
- **Category**: Data Protection (Encryption at Rest)
- **Severity**: High
- **Location**: Section 7 (Non-Functional Requirements) - Security Requirements
- **Problem Description**: The design specifies encryption at rest for S3 (AES-256) but does not mention encryption for Elasticsearch indexes, which store sensitive document content for full-text search. Elasticsearch data should also be encrypted at rest to protect against infrastructure-level data exposure.
- **Detection Criteria**:
  - ○ (Detected): Points out that encryption at rest is specified for S3 but not for Elasticsearch AND recommends encrypting Elasticsearch data/indexes
  - △ (Partial): Mentions encryption at rest generally or recommends encrypting all data stores without specifically identifying the Elasticsearch gap
  - × (Undetected): No mention of Elasticsearch encryption

### P05: Audit Log Integrity - Missing Tampering Protection
- **Category**: Threat Modeling (Repudiation, Tampering)
- **Severity**: High
- **Location**: Section 4 (Data Model) - audit_logs table
- **Problem Description**: The audit_logs table design describes "immutable records" but does not specify technical controls to enforce immutability. Without write-once storage, cryptographic signing, or separate append-only storage, attackers with database access can modify or delete audit logs to hide their activities.
- **Detection Criteria**:
  - ○ (Detected): Points out the lack of technical enforcement for audit log immutability AND recommends specific mechanisms (write-once storage, cryptographic signing, append-only log store, blockchain-like hash chains)
  - △ (Partial): Mentions audit log integrity or tamper detection without specific technical controls, OR mentions database access controls without addressing log tampering scenarios
  - × (Undetected): No mention of audit log integrity or tampering protection

### P06: API Rate Limiting - Not Specified
- **Category**: Threat Modeling (Denial of Service, Brute Force)
- **Severity**: Medium
- **Location**: Section 5 (API Design) and Section 7 (Security Requirements)
- **Problem Description**: The design mentions "failed login lockout" (5 attempts → 15 min lockout) but does not specify rate limiting for other API endpoints. Without rate limiting, the system is vulnerable to brute-force attacks on other endpoints, credential stuffing, and application-layer DoS attacks.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of API rate limiting specification AND recommends implementing rate limits beyond just login endpoints (e.g., per-user, per-IP, per-endpoint limits)
  - △ (Partial): Mentions rate limiting or DoS protection generally without identifying the design gap, OR only focuses on login endpoint rate limiting
  - × (Undetected): No mention of API rate limiting

### P07: External Sharing - Missing Access Control and Audit
- **Category**: Authentication & Authorization Design
- **Severity**: Medium
- **Location**: Section 5 (API Design) - POST /api/v1/documents/{id}/share
- **Problem Description**: The external sharing endpoint generates time-limited links but the design does not specify: (1) authentication/authorization requirements for creating share links, (2) audit logging for share link creation and access, (3) access controls on what documents can be shared externally. Without these controls, internal users could leak sensitive documents.
- **Detection Criteria**:
  - ○ (Detected): Points out missing access controls for share link creation OR missing audit logging for external sharing activities OR missing policy on what can be shared
  - △ (Partial): Mentions external sharing risks generally without identifying specific missing controls in the design
  - × (Undetected): No mention of external sharing security

### P08: Database Access - Missing Principle of Least Privilege
- **Category**: Infrastructure & Dependencies Security
- **Severity**: Medium
- **Location**: Section 2 (Technology Stack) and Section 3 (Architecture) - Database connections
- **Problem Description**: The design does not specify database access control strategy for application services. Each microservice should have separate database credentials with minimal privileges (e.g., Document Service should not have access to audit_logs table). Without least-privilege database access, a compromised service can access all data.
- **Detection Criteria**:
  - ○ (Detected): Points out the lack of database access control specification AND recommends service-specific database credentials or least-privilege access per service
  - △ (Partial): Mentions database security or access controls without specifically addressing service-level privilege separation
  - × (Undetected): No mention of database access control strategy

### P09: Secrets in JWT - Information Disclosure Risk
- **Category**: Data Protection (Information Disclosure)
- **Severity**: Medium
- **Location**: Section 5 (API Design) - Authorization Model, JWT contents
- **Problem Description**: The design specifies that JWTs contain "user ID, role, department ID". While these are necessary for authorization, the design does not mention JWT encryption or acknowledge that JWT contents are base64-encoded (not encrypted). If JWTs contain sensitive department information or additional user metadata, this could lead to information disclosure.
- **Detection Criteria**:
  - ○ (Detected): Points out that JWT contents are not encrypted (only base64-encoded) AND recommends either using JWE (encrypted JWTs) or minimizing sensitive data in JWT claims
  - △ (Partial): Mentions JWT security generally or token data minimization without specifically addressing the encryption/encoding distinction
  - × (Undetected): No mention of JWT content security or information disclosure

### P10: CORS Policy - Not Specified
- **Category**: Input Validation Design (Cross-Origin Security)
- **Severity**: Low
- **Location**: Section 3 (Architecture) - API Gateway configuration
- **Problem Description**: The design mentions API Gateway and client apps (React, React Native) but does not specify CORS (Cross-Origin Resource Sharing) policy. Without a restrictive CORS policy, the API could be vulnerable to unauthorized cross-origin requests from malicious websites.
- **Detection Criteria**:
  - ○ (Detected): Points out the absence of CORS policy specification AND recommends defining allowed origins or implementing restrictive CORS headers
  - △ (Partial): Mentions CORS or cross-origin security without identifying the design gap
  - × (Undetected): No mention of CORS policy

## Bonus Problems

Additional security issues that are not explicitly embedded but could be legitimately identified:

| ID | Category | Content | Bonus Condition |
|----|----------|---------|-----------------|
| B01 | Authentication & Authorization | No multi-factor authentication (MFA) requirement for privileged accounts (admin, manager roles) | Points out MFA absence and recommends MFA for admin/privileged accounts |
| B02 | Threat Modeling | No mention of security headers (HSTS, CSP, X-Frame-Options) in API Gateway or application configuration | Recommends implementing security headers to prevent common web attacks |
| B03 | Data Protection | Backup encryption not specified (daily PostgreSQL snapshots, S3 versioning) | Points out that backup data should also be encrypted |
| B04 | Infrastructure Security | Container image vulnerability scanning is mentioned (Trivy) but no policy for handling discovered vulnerabilities or update cadence | Recommends vulnerability remediation policy or blocking deployment on critical CVEs |
| B05 | Input Validation | No mention of Content Security Policy or file content validation beyond "Apache Tika parsing" | Recommends validating parsed file content or implementing CSP for XSS mitigation |
| B06 | Authentication & Authorization | Refresh token rotation not specified (7-day refresh token lifetime) - should rotate refresh tokens on each use to limit exposure window | Recommends refresh token rotation strategy |
| B07 | Threat Modeling | No mention of bot protection or CAPTCHA for authentication endpoints | Recommends bot detection mechanisms for login/signup flows |
