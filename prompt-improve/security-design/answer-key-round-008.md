# Answer Key - Round 008

## Execution Context
- **Observation**: security
- **Target**: design
- **Embedded Problems**: 10

## Embedded Problem List

### P01: JWT Token Storage in localStorage
- **Category**: Data Protection
- **Severity**: Critical
- **Location**: Section 3 (Architecture Design - Data Flow, item 1)
- **Problem Description**: The design specifies storing JWT tokens in localStorage, which is vulnerable to XSS attacks. If an attacker can inject JavaScript, they can steal the token and impersonate the user. This is particularly critical given the sensitive nature of financial and personal data in a rental platform.
- **Detection Criteria**:
  - ○ (Detected): Points out the security risk of storing JWT in localStorage and mentions XSS vulnerability, or recommends httpOnly cookies as an alternative
  - △ (Partial): Mentions that JWT storage needs consideration or that localStorage has security implications, but does not explicitly identify XSS risk or provide specific alternatives
  - × (Not Detected): No mention of JWT storage security concerns

### P02: Missing Authorization on DELETE Property Endpoint
- **Category**: Authentication/Authorization Design
- **Severity**: Critical
- **Location**: Section 5 (API Design - Property Endpoints)
- **Problem Description**: The `DELETE /api/properties/{id}` endpoint only checks for owner/manager role but does not verify that the authenticated user owns the specific property being deleted. This allows any property owner to delete other owners' properties.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing resource ownership validation on DELETE endpoint, or notes that role-based check is insufficient without ownership verification
  - △ (Partial): Mentions that API authorization needs to be strengthened or that endpoint security is a concern, but does not specifically identify the DELETE endpoint resource ownership gap
  - × (Not Detected): No mention of property deletion authorization issues

### P03: Lack of Input Validation Strategy for Property Address
- **Category**: Input Validation Design
- **Severity**: Medium
- **Problem Description**: The Properties table defines address as TEXT without length constraints, and there is no mention of validation rules for address format in the API design section. This could lead to injection attacks (e.g., SQL injection if not properly escaped) or storage of malformed/malicious data.
- **Detection Criteria**:
  - ○ (Detected): Points out missing input validation for address field, mentions injection risk, or recommends specific validation rules (length limits, format validation, sanitization)
  - △ (Partial): Mentions general input validation concerns but does not specifically identify the address field vulnerability
  - × (Not Detected): No mention of address field input validation

### P04: Insufficient Backup Encryption Specification
- **Category**: Data Protection
- **Severity**: Medium
- **Problem Description**: Section 7 mentions "Regular database backups: full backup daily, incremental every 6 hours" but does not specify whether backups are encrypted at rest or in transit. Given the sensitive tenant data (SSNs, financial info, background checks), unencrypted backups pose a significant data breach risk.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing backup encryption specification, or notes that backup security measures are undefined
  - △ (Partial): Mentions data-at-rest encryption generally but does not specifically call out backup encryption
  - × (Not Detected): No mention of backup encryption

### P05: Missing API Idempotency Design for Payment Processing
- **Category**: Threat Modeling
- **Severity**: Medium
- **Problem Description**: The `POST /api/payments/process` endpoint has no idempotency mechanism defined. Network retries or duplicate submissions could result in charging tenants multiple times for the same rent payment, leading to financial disputes and reputation damage.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing idempotency for payment processing, mentions risk of duplicate charges, or recommends idempotency key mechanism
  - △ (Partial): Mentions payment processing reliability concerns but does not specifically identify idempotency requirement
  - × (Not Detected): No mention of payment idempotency

### P06: Weak Rate Limiting Granularity
- **Category**: Threat Modeling (DoS Protection)
- **Severity**: Medium
- **Problem Description**: Rate limiting is defined as "100 requests/minute per IP address", which is IP-based only. This does not prevent authenticated attackers from abusing the system, and shared IPs (corporate networks, VPNs) could unfairly block legitimate users. A combination of IP-based and user-based rate limiting would be more robust.
- **Detection Criteria**:
  - ○ (Detected): Points out limitations of IP-only rate limiting, mentions shared IP issues or authenticated user abuse, or recommends user-based rate limiting
  - △ (Partial): Mentions rate limiting needs improvement but does not identify specific IP-only limitation
  - × (Not Detected): No mention of rate limiting granularity

### P07: Insufficient Session Revocation Mechanism
- **Category**: Authentication/Authorization Design
- **Severity**: Medium
- **Problem Description**: JWT tokens have 24-hour expiration, but there is no mention of a session revocation or token invalidation mechanism. If a token is compromised or a user logs out, the token remains valid until expiration, allowing unauthorized access.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing session/token revocation mechanism, or points out that logout does not invalidate JWT
  - △ (Partial): Mentions JWT security concerns or session management issues but does not specifically identify revocation gap
  - × (Not Detected): No mention of session revocation

### P08: Lack of Audit Logging for Sensitive Operations
- **Category**: Threat Modeling (Repudiation)
- **Severity**: Low
- **Problem Description**: Section 6 describes logging strategy but does not specify audit logging for critical security events such as application approval/rejection, payment refunds, lease terminations, or access to tenant background check data. This makes it difficult to investigate security incidents or compliance violations.
- **Detection Criteria**:
  - ○ (Detected): Points out missing audit logging for sensitive operations, mentions compliance or investigation requirements, or lists specific events requiring audit logs
  - △ (Partial): Mentions logging needs improvement but does not specifically identify audit logging for critical security events
  - × (Not Detected): No mention of audit logging

### P09: Third-Party API Credential Storage Not Specified
- **Category**: Infrastructure/Dependencies Security
- **Severity**: Low
- **Problem Description**: The design mentions integration with Stripe, Checkr, and DocuSign APIs but does not specify how API credentials are stored. Section 6 mentions "Environment-specific configuration via AWS Parameter Store", but it is unclear if this applies to third-party API keys, and there is no mention of encryption or access control for these secrets.
- **Detection Criteria**:
  - ○ (Detected): Identifies missing specification for third-party API credential storage, mentions risks of exposed credentials, or recommends secrets management solution (AWS Secrets Manager, encryption, IAM policies)
  - △ (Partial): Mentions general secrets management concerns but does not specifically identify third-party API credential storage gap
  - × (Not Detected): No mention of API credential storage security

### P10: Missing CORS Policy Definition
- **Category**: Input Validation Design
- **Severity**: Low
- **Problem Description**: The API design does not define CORS (Cross-Origin Resource Sharing) policy. Without proper CORS configuration, the API could be vulnerable to cross-origin attacks, or overly permissive CORS settings could allow unauthorized domains to access the API.
- **Detection Criteria**:
  - ○ (Detected): Points out missing CORS policy definition, mentions cross-origin security risks, or recommends specific CORS configuration
  - △ (Partial): Mentions API security concerns but does not specifically identify CORS policy gap
  - × (Not Detected): No mention of CORS policy

## Bonus Problem List

Problems not embedded in the answer key but worth bonus points if detected:

| ID | Category | Description | Bonus Condition |
|----|----------|-------------|-----------------|
| B01 | Data Protection | Background check data retention policy not specified | Points out missing data retention/deletion policy for sensitive background check results |
| B02 | Authentication/Authorization | Multi-factor authentication (MFA) not mentioned | Recommends MFA for high-risk operations (e.g., payment refunds, lease approvals) |
| B03 | Input Validation | Missing file upload validation for property images | Identifies missing file type, size, or malware scanning for user-uploaded images |
| B04 | Threat Modeling | Missing email verification for user registration | Points out that email ownership is not verified, enabling impersonation attacks |
| B05 | Data Protection | Database column-level encryption not specified for SSNs | Recommends encrypting sensitive columns (SSN, background check data) in addition to TLS |
| B06 | Infrastructure/Dependencies | Missing dependency vulnerability scanning | Recommends automated scanning for vulnerable dependencies (Dependabot, Snyk) |
| B07 | Authentication/Authorization | Password reset mechanism not defined | Identifies missing password reset flow, which could have security implications if implemented incorrectly |
| B08 | Threat Modeling | Missing protection against automated application submission (bot protection) | Points out risk of spam applications or automated attacks, recommends CAPTCHA or rate limiting per user |
