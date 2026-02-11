# Answer Key - Round 015

## Execution Context
- **Perspective**: security
- **Target**: design
- **Embedded Problems**: 9

## Embedded Problem List

### P01: JWT Token Storage in localStorage
- **Category**: Authentication Design (Data Protection)
- **Severity**: Critical
- **Location**: Section 3.3 Data Flow, line 2
- **Problem Description**: The design specifies storing JWT tokens in browser localStorage, which exposes tokens to XSS attacks. Malicious JavaScript can read localStorage and exfiltrate tokens, bypassing authentication. HttpOnly cookies are the recommended secure alternative for token storage.
- **Detection Criteria**:
  - ○ (Full Detection): Explicitly identifies the risk of JWT storage in localStorage and mentions XSS vulnerability or recommends HttpOnly cookies as an alternative
  - △ (Partial Detection): Mentions general token storage security concerns or XSS risks without specifically linking to localStorage usage
  - × (No Detection): No mention of JWT storage security issues

### P02: Weak Password Policy
- **Category**: Authentication Design
- **Severity**: Critical
- **Location**: Section 7.2 Security, password policy
- **Problem Description**: The password policy requires only 6 characters minimum with no complexity requirements (uppercase, lowercase, numbers, special characters). This makes accounts vulnerable to brute-force attacks and dictionary attacks. Industry standards (NIST SP 800-63B) recommend minimum 8 characters with complexity or length-based alternatives.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the 6-character minimum as insufficient and mentions brute-force/dictionary attack vulnerability or recommends 8+ characters with complexity requirements
  - △ (Partial Detection): Mentions weak password policy or security concerns without specifying the inadequacy of 6 characters or attack vectors
  - × (No Detection): No mention of password policy weaknesses

### P03: Missing Password Reset Token Expiration
- **Category**: Authentication Design (Session Management)
- **Severity**: Critical
- **Location**: Section 5.1 Authentication Endpoints, POST /api/auth/password-reset
- **Problem Description**: The password reset token has no expiration time specified. Long-lived or non-expiring reset tokens create a persistent attack window - if an attacker intercepts a reset email (e.g., via email compromise or MITM), they can use it indefinitely to hijack the account. Reset tokens should expire within 15-60 minutes.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the lack of expiration for password reset tokens and explains the account takeover risk or recommends specific expiration timeframe (e.g., 15-60 minutes)
  - △ (Partial Detection): Mentions password reset security concerns or token lifecycle issues without specifically addressing expiration
  - × (No Detection): No mention of password reset token expiration

### P04: Missing CSRF Protection
- **Category**: Input Validation Design (API Security)
- **Severity**: High
- **Location**: Section 5.2-5.4 API Design (state-changing endpoints)
- **Problem Description**: State-changing API endpoints (POST /api/consultations, POST /api/prescriptions, PATCH /api/consultations/:id) have no CSRF protection mechanism specified. Since JWT is stored in localStorage (Section 3.3), the API likely accepts tokens from the Authorization header without additional CSRF tokens. However, if the implementation ever uses cookies or mixed authentication methods, CSRF attacks could allow unauthorized actions. Best practice is to implement CSRF tokens (e.g., synchronizer token pattern) for all state-changing operations.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the lack of CSRF protection for state-changing endpoints and explains the risk or recommends CSRF token implementation
  - △ (Partial Detection): Mentions CSRF or cross-site request security concerns without linking to specific endpoints or the design's authentication approach
  - × (No Detection): No mention of CSRF protection

### P05: Unencrypted Elasticsearch Storage
- **Category**: Data Protection (Infrastructure Security)
- **Severity**: High
- **Location**: Section 2.2 Database, Search Engine: Elasticsearch 8.6
- **Problem Description**: Elasticsearch is used in the architecture (likely for medical record search functionality) but there is no mention of encryption at rest for the Elasticsearch cluster. Medical data indexed in Elasticsearch (patient names, diagnoses, consultation notes) would be stored unencrypted on disk, violating HIPAA encryption requirements. Elasticsearch supports encryption at rest via the security plugin.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies that Elasticsearch lacks encryption at rest configuration and mentions HIPAA compliance risk or recommends enabling encryption
  - △ (Partial Detection): Mentions general data encryption concerns for datastores without specifically addressing Elasticsearch
  - × (No Detection): No mention of Elasticsearch encryption

### P06: Inadequate API Rate Limiting Coverage
- **Category**: Infrastructure Security (DoS Prevention)
- **Severity**: Medium
- **Location**: Section 3.2 Component Responsibilities and Section 5.1 Authentication Endpoints
- **Problem Description**: API Gateway applies global rate limiting (100 req/min per IP) and registration endpoint has specific limit (10 req/hour). However, critical endpoints like login (/api/auth/login), password reset (/api/auth/password-reset), and prescription creation (/api/prescriptions) lack endpoint-specific rate limits. This allows brute-force attacks on authentication, credential stuffing, and abuse of prescription APIs. Each sensitive endpoint should have tailored rate limits.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies missing rate limits on login, password reset, or prescription endpoints and explains brute-force/abuse risks or recommends endpoint-specific rate limiting
  - △ (Partial Detection): Mentions general rate limiting gaps or DoS concerns without specifying critical endpoints lacking protection
  - × (No Detection): No mention of rate limiting coverage issues

### P07: Sensitive Data Logging
- **Category**: Data Protection (Information Disclosure)
- **Severity**: Medium
- **Location**: Section 6.2 Logging, line 5
- **Problem Description**: The logging policy states "full request bodies are logged for debugging" with only passwords masked. This means sensitive medical data (consultation notes, prescription details, patient health information) is logged in plaintext. Log aggregation systems (Prometheus/Grafana) and log files become a HIPAA violation risk if compromised. Medical PHI should be masked or excluded from debug logs.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies that logging full request bodies exposes sensitive medical data (PHI/PII) and mentions HIPAA violation risk or recommends masking/excluding medical data from logs
  - △ (Partial Detection): Mentions general logging security concerns or sensitive data exposure without specifically addressing medical data in request bodies
  - × (No Detection): No mention of sensitive data logging issues

### P08: Missing Authorization Check on Document Access
- **Category**: Authorization Design (Access Control)
- **Severity**: Medium
- **Location**: Section 5.4 Medical Document Endpoints, GET /api/documents/:id
- **Problem Description**: The document access endpoint specifies authorization as "Patient owner or their care team" but does not define how "care team" membership is verified. Without proper role-based access control (RBAC) or relationship validation (e.g., active consultation between provider and patient), any provider could potentially access any patient's documents by guessing document IDs. An IDOR (Insecure Direct Object Reference) vulnerability risk exists.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies insufficient authorization specification for document access, mentions IDOR risk or the need for explicit care team relationship validation
  - △ (Partial Detection): Mentions general access control concerns for medical documents without addressing the "care team" authorization ambiguity
  - × (No Detection): No mention of document access authorization issues

### P09: Secrets in Kubernetes ConfigMaps
- **Category**: Infrastructure Security (Secret Management)
- **Severity**: Medium
- **Location**: Section 6.4 Deployment, line 4
- **Problem Description**: The design states "Environment variables managed in Kubernetes ConfigMaps" followed by "Secrets stored in AWS Secrets Manager." This creates ambiguity - some teams might misinterpret this and store sensitive environment variables (database hosts, third-party API endpoints with embedded tokens) in ConfigMaps, which are not encrypted by default in Kubernetes. The design should explicitly state that ConfigMaps are for non-sensitive configuration only and all credentials must use Secrets Manager or Kubernetes Secrets with encryption.
- **Detection Criteria**:
  - ○ (Full Detection): Identifies the risk of storing sensitive configuration in ConfigMaps (unencrypted) and recommends clarifying ConfigMap usage or enforcing Secrets Manager for all sensitive data
  - △ (Partial Detection): Mentions general Kubernetes secret management concerns without specifically addressing ConfigMap vs. Secrets Manager distinction
  - × (No Detection): No mention of ConfigMap security issues

## Bonus Problem List

Bonus problems are NOT included in the primary embedded problem count but can provide additional scoring if detected.

| ID | Category | Content | Bonus Condition |
|----|---------|---------|----------------|
| B01 | Data Protection | Database encryption at rest is specified for PostgreSQL (RDS encryption) but encryption for Redis cache layer is not mentioned | Identifies missing Redis encryption at rest (medical session data might be cached) |
| B02 | Authentication Design | 24-hour JWT token expiration is long-lived for a healthcare application handling sensitive medical data; shorter expiration (1-4 hours) with refresh tokens would reduce attack window | Identifies long JWT expiration as security concern or recommends shorter-lived tokens with refresh mechanism |
| B03 | Authorization Design | Consultation PATCH endpoint allows providers to update status and notes, but there's no validation that the provider is the assigned provider for that consultation (not just any provider) | Identifies missing provider-consultation relationship validation on update operations |
| B04 | Audit & Compliance | HIPAA requires audit logging for all PHI access, but the design only mentions logging API requests without specifying audit log retention, immutability, or access monitoring requirements | Identifies insufficient audit logging specification for HIPAA compliance or recommends detailed audit trail requirements |
| B05 | Infrastructure Security | Stack traces are included in development environment responses (Section 6.1), but there's no mention of ensuring this is disabled in production environments where it could leak sensitive system information | Recommends explicitly disabling stack trace exposure in production or mentions information leakage risk |
| B06 | Input Validation Design | File upload endpoint accepts DICOM medical imaging format but doesn't specify validation of DICOM file structure to prevent malicious payload injection or zip bomb attacks via compressed medical images | Identifies DICOM file validation gap or mentions risks of accepting complex binary formats without deep inspection |
| B07 | Session Management | Single active session per user policy (Section 7.2) doesn't address what happens to active consultations when a user logs in from a new device - abruptly terminating a video consultation for security could disrupt patient care | Identifies conflict between security policy and operational continuity for active medical sessions |
