# Evaluation Rubric: security-design-reviewer

This document consolidates the evaluation criteria for all test scenarios.

---

## T01: E-Commerce Checkout System

**Difficulty**: Easy | **Category**: Authentication & Authorization Design

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Discount Code Authorization | Identifies lack of user-specific validation on discount codes allowing unlimited reuse or unauthorized access to restricted codes | Mentions discount code validation but lacks specificity about authorization checks or multi-use scenarios | No mention of discount code authorization issues | 1.0 |
| T01-C2 | Price Tampering Prevention | Identifies missing server-side price validation allowing client to manipulate cart item prices before checkout | Mentions need for price validation but lacks detail on server-side enforcement or tampering vectors | No mention of price integrity verification | 1.0 |
| T01-C3 | Session Management Security | Identifies at least two session security issues: excessive 24-hour timeout, lack of session regeneration after privilege change, or missing secure flag specification | Mentions one session security concern but lacks comprehensive coverage | No mention of session security issues | 0.5 |
| T01-C4 | Payment Data Handling | Confirms appropriate use of Stripe integration to avoid PCI DSS scope, notes lack of explicit logging restrictions for payment-related data | Acknowledges Stripe usage reduces risk but lacks detail on data handling policies | No evaluation of payment data security | 0.5 |

### Expected Key Behaviors
- Identify authorization gaps in discount code application (no validation of eligibility, multi-use prevention)
- Detect missing server-side price verification (cart items could be manipulated client-side)
- Recognize session timeout policy may be excessive for financial transactions
- Note lack of rate limiting on checkout endpoints to prevent abuse

### Anti-patterns
- Focusing only on password hashing without evaluating authorization logic
- Accepting parameterized queries as sufficient without examining business logic vulnerabilities
- Overlooking client-server trust boundary issues in e-commerce context
- Generic recommendations without connecting to specific checkout flow risks

---

## T02: Healthcare Patient Portal

**Difficulty**: Medium | **Category**: Data Protection

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Encryption Key Management | Identifies lack of explicit encryption key management strategy for at-rest data (KMS, key rotation policies, separation of data/key storage) | Mentions encryption concerns but lacks specificity on key management controls | No mention of encryption key management | 1.0 |
| T02-C2 | PHI in Logs | Identifies risk of PHI/PII leakage in API gateway logs (headers may contain tokens, query params) and application logs (resource identifiers may reveal sensitive info) | Mentions logging concerns but lacks specific PHI/PII leakage vectors | No mention of sensitive data in logs | 1.0 |
| T02-C3 | Data Segregation | Identifies lack of tenant isolation mechanisms or patient data segregation controls in shared MongoDB/PostgreSQL instances to prevent cross-patient data access | Mentions multi-tenancy concerns but lacks detail on segregation enforcement | No mention of data isolation requirements | 1.0 |
| T02-C4 | Provider Access Scope | Identifies missing fine-grained authorization details for "assigned patients only" policy (assignment mechanism, dynamic access reviews, emergency access controls) | Mentions provider access control but lacks detail on assignment enforcement | No evaluation of provider authorization model | 0.5 |
| T02-C5 | Audit Log Completeness | Identifies insufficient audit scope missing critical events: authentication failures, role changes, consent modifications, or emergency access overrides | Mentions audit logging but lacks critique of comprehensiveness | Accepts audit logging as adequate without evaluation | 0.5 |

### Expected Key Behaviors
- Identify missing encryption key management strategy (KMS usage, rotation policies)
- Detect PHI/PII leakage risk in verbose logging (headers, query parameters)
- Recognize inadequate data segregation controls for multi-patient environment
- Question 90-day log retention vs 7-year compliance requirement mismatch
- Note lack of emergency access ("break-glass") procedures

### Anti-patterns
- Accepting "default encryption settings" as sufficient without key management evaluation
- Overlooking logging verbosity risks in healthcare context
- Assuming RBAC implementation without examining authorization granularity
- Focusing on transport security while missing at-rest protection gaps

---

## T03: Corporate Expense Reimbursement System

**Difficulty**: Medium | **Category**: Input Validation & Attack Defense

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Path Traversal Vulnerability | Identifies path traversal risk in file upload using unsanitized `originalFilename` allowing directory traversal attacks (e.g., `../../etc/passwd`) | Mentions filename validation concerns but lacks specific path traversal attack vector | No mention of path traversal risk | 1.0 |
| T03-C2 | File Type Validation Bypass | Identifies inadequate file validation relying only on extension check, missing content-type verification, magic byte validation, or file size limits | Mentions file validation but lacks detail on bypass techniques or defense-in-depth | No critique of file validation approach | 1.0 |
| T03-C3 | CSV Injection in Export | Identifies CSV injection risk in export functionality where expense descriptions/categories could contain formula injection payloads (=, +, -, @) | Mentions export security or output encoding but lacks specific CSV injection vector | No mention of export-related vulnerabilities | 1.0 |
| T03-C4 | Authorization Enforcement | Identifies missing authorization checks on upload endpoint allowing any authenticated user to upload files, or lack of ownership verification linking uploads to expense reports | Mentions authorization concerns but lacks specificity on endpoint-level enforcement gaps | No evaluation of authorization implementation | 0.5 |
| T03-C5 | File Storage Security | Identifies at least two file storage risks: direct filesystem access bypassing application logic, missing access controls on upload directory, or lack of malware scanning | Mentions one file storage concern but lacks comprehensive coverage | No mention of file storage security | 0.5 |

### Expected Key Behaviors
- Identify path traversal vulnerability in filename handling
- Detect inadequate file type validation (extension-only check)
- Recognize CSV injection risk in export functionality
- Note missing authorization check on upload endpoint
- Recommend virus/malware scanning for uploaded files

### Anti-patterns
- Accepting extension-based validation as sufficient
- Overlooking output encoding issues in export functions
- Assuming JPA/Hibernate usage prevents all injection attacks
- Missing filesystem-level security concerns (permissions, access controls)

---

## T04: Social Media Analytics Dashboard

**Difficulty**: Hard | **Category**: Threat Modeling (STRIDE)

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | STRIDE Threat Coverage | Systematically addresses at least 4 of 6 STRIDE categories with specific issues: Spoofing (JWT implementation), Tampering (data integrity), Repudiation (audit gaps), Information Disclosure (encryption gaps), Denial of Service (rate limit bypass), Elevation of Privilege (tier enforcement) | Addresses 2-3 STRIDE categories with specific concerns | Generic security mentions without STRIDE framework application | 1.0 |
| T04-C2 | Custom JWT Implementation Risks | Identifies specific cryptographic weaknesses in custom JWT implementation (HS256 key management, lack of token rotation/revocation, missing signature verification details, or algorithm confusion risks) | Mentions JWT concerns but lacks cryptographic specificity | No critique of JWT implementation | 1.0 |
| T04-C3 | Social Media Token Protection | Identifies inadequate protection for stored OAuth tokens beyond encryption (key management, token refresh strategy, breach detection, separation of encryption keys from data) | Mentions token encryption but lacks detail on protection strategy | Accepts encryption as sufficient without further analysis | 1.0 |
| T04-C4 | Data Retention and Privacy | Identifies privacy risks in "historical data retained" policy (GDPR right to erasure, data minimization principles, lack of retention limits, user consent model) | Mentions data retention concerns but lacks regulatory or privacy framework connection | No evaluation of data retention policy | 1.0 |
| T04-C5 | Tier Privilege Escalation | Identifies mechanisms for tier privilege escalation or enforcement gaps (API key shared across tiers, rate limit bypass via multiple keys, WebSocket connection not tier-restricted, cached data accessible across tiers) | Mentions tier enforcement but lacks specific escalation vectors | No analysis of tier boundary enforcement | 0.5 |
| T04-C6 | Third-Party Data Exposure | Identifies risks in social media data handling (cached posts in Redis accessible without encryption, Elasticsearch unencrypted full-text content, no data classification policy, cross-tenant data leakage in shared infrastructure) | Mentions data encryption gaps but lacks multi-tenancy or exposure analysis | No evaluation of third-party data protection | 0.5 |

### Expected Key Behaviors
- Apply STRIDE framework systematically to identify threat categories
- Identify cryptographic weaknesses in custom JWT implementation
- Question encryption strategy for OAuth tokens (key management, rotation)
- Recognize GDPR/privacy issues with indefinite data retention
- Detect tier enforcement gaps (API keys, rate limits, data access)
- Note unencrypted data in Redis and Elasticsearch

### Anti-patterns
- Generic security checklist without threat modeling structure
- Accepting "encrypted in database" without examining key management
- Overlooking data retention and privacy implications
- Missing multi-tenancy concerns in shared infrastructure
- Focusing on transport security while ignoring at-rest protection

---

## T05: IoT Device Fleet Management

**Difficulty**: Hard | **Category**: Infrastructure & Dependencies

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Certificate Management Lifecycle | Identifies at least three certificate security issues: excessive 10-year validity period, slow CRL update cycle (monthly), lack of automated revocation distribution, or missing OCSP support | Identifies 1-2 certificate management concerns but lacks comprehensive lifecycle analysis | No critique of certificate management approach | 1.0 |
| T05-C2 | Secrets Management Security | Identifies Kubernetes Secrets inadequacy for production secrets (base64 encoding only, not encrypted at rest by default, etcd exposure) and recommends external secret manager (Vault, AWS Secrets Manager, etc.) | Mentions secrets security concerns but lacks specificity on Kubernetes Secrets limitations | Accepts Kubernetes Secrets as sufficient | 1.0 |
| T05-C3 | Container Image Security | Identifies multiple image security risks: using `latest` tag prevents reproducibility, Alpine base may have vulnerabilities, lack of image signing/verification, missing vulnerability scanning in CI/CD | Mentions image security but lacks detail on specific risks or comprehensive controls | No evaluation of container image security practices | 1.0 |
| T05-C4 | Network Segmentation | Identifies missing network policies allowing unrestricted pod-to-pod communication, risk of lateral movement between namespaces, lack of egress controls, or insufficient database access restrictions | Mentions network security but lacks specific Kubernetes network policy analysis | No mention of network segmentation or isolation | 1.0 |
| T05-C5 | Dependency Vulnerability Management | Identifies inadequate quarterly manual updates, lack of automated vulnerability scanning (Snyk, Trivy, etc.), missing dependency pinning, or absence of SBOM for supply chain risk management | Mentions dependency concerns but lacks detail on vulnerability management process | No evaluation of dependency security practices | 0.5 |
| T05-C6 | MQTT Authorization Model | Identifies lack of topic-level authorization controls allowing devices to subscribe to other devices' command topics or publish to arbitrary topics beyond their device_id | Mentions MQTT security but lacks specific authorization enforcement analysis | No evaluation of MQTT topic access controls | 0.5 |

### Expected Key Behaviors
- Identify excessive certificate validity period and slow revocation mechanisms
- Recognize Kubernetes Secrets limitations for production secret management
- Detect container image security issues (latest tag, missing scanning, no signing)
- Note absence of Kubernetes network policies for pod isolation
- Question quarterly manual dependency updates vs automated scanning
- Identify MQTT topic-level authorization gaps

### Anti-patterns
- Accepting X.509 authentication without examining full PKI lifecycle
- Assuming Kubernetes Secrets are sufficient for production environments
- Overlooking container supply chain security (image provenance, scanning)
- Missing network-level security controls in Kubernetes context
- Focusing on TLS encryption while ignoring authorization and access control

---

## T06: Content Management System with Multi-Language Support

**Difficulty**: Medium | **Category**: Input Validation & Attack Defense

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Stored XSS in Rich Text Content | Identifies stored XSS risk from inadequate HTML sanitization in rich text body, especially with CKEditor's flexible formatting and CSP 'unsafe-inline' allowing script execution | Mentions XSS concerns but lacks connection to rich text context or CSP weakness | No identification of XSS vulnerability | 1.0 |
| T06-C2 | Injection via Translation JSON | Identifies injection risks in jsonb translation storage (second-order SQL injection if translations extracted and used in dynamic queries, or XSS if translation values not escaped on render) | Mentions JSON storage concerns but lacks specific injection vectors | No evaluation of translation data security | 1.0 |
| T06-C3 | Search Query Injection | Identifies Algolia search query injection risks or lack of input validation on search parameters allowing filter bypass or data exposure through query manipulation | Mentions search security but lacks specific query injection analysis | No mention of search-related vulnerabilities | 0.5 |
| T06-C4 | Iframe Sandbox Escape | Identifies risks in preview iframe implementation (missing sandbox attribute, same-origin context allowing parent page access, or lack of CSP for preview) | Mentions preview concerns but lacks iframe security specifics | No evaluation of preview functionality security | 1.0 |
| T06-C5 | CDN Cache Poisoning | Identifies cache poisoning risks through language parameter manipulation, cache key insufficient granularity, or lack of Vary headers causing wrong-language content delivery | Mentions CDN concerns but lacks specific cache poisoning vectors | No mention of CDN security | 0.5 |

### Expected Key Behaviors
- Identify stored XSS vulnerability in rich text HTML storage with weak CSP
- Recognize injection risks in jsonb translation data
- Detect potential search query manipulation in Algolia integration
- Note missing iframe sandbox restrictions in preview functionality
- Consider cache poisoning scenarios in multi-language CDN setup

### Anti-patterns
- Assuming Rails sanitize helper fully prevents XSS without examining CSP
- Overlooking second-order injection from stored JSON data
- Accepting third-party search integration without input validation analysis
- Missing client-side security controls (iframe sandbox, CSP directives)
- Focusing on SQL injection while missing other injection attack surfaces

---

## T07: Real-Time Bidding Platform

**Difficulty**: Hard | **Category**: Authentication & Authorization Design

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Account Manager Authorization Enforcement | Identifies TOCTOU race condition in account manager authorization (assignment table in PostgreSQL may be out of sync with JWT claims, allowing access after de-assignment) or lack of real-time assignment validation | Mentions account manager authorization but lacks specific enforcement gap analysis | No evaluation of account manager access control | 1.0 |
| T07-C2 | Campaign Budget Race Conditions | Identifies race conditions in budget enforcement (5-minute check interval allows overspend, Redis increment not atomic with bid submission, distributed system consistency issues) | Mentions budget concerns but lacks specific race condition or consistency analysis | No critique of budget enforcement mechanism | 1.0 |
| T07-C3 | JWT Token Privilege Escalation | Identifies risks in embedding authorization data (account_assignments) in JWT: stale permissions after reassignment, lack of token revocation mechanism, or excessive token lifetime for high-value operations | Mentions JWT concerns but lacks specific privilege escalation or staleness vectors | No analysis of JWT authorization model | 1.0 |
| T07-C4 | Inter-Service Authorization | Identifies missing fine-grained inter-service authorization (mTLS provides authentication but lacks operation-level authorization, service mesh policies undefined, or principle of least privilege violations) | Mentions service-to-service security but lacks authorization specificity | No evaluation of microservice authorization | 0.5 |
| T07-C5 | Ad Exchange API Key Management | Identifies weaknesses in static API key rotation (annual rotation insufficient, no emergency revocation process, lack of key usage monitoring, or shared keys across exchange endpoints) | Mentions API key concerns but lacks comprehensive key lifecycle analysis | Accepts API key authentication without critique | 0.5 |
| T07-C6 | Audit Trail for Financial Operations | Identifies insufficient audit logging for financial events (budget modifications, bid amount changes, spend tracking adjustments) missing critical fields like before/after values, IP address, or lack of immutability guarantees | Mentions audit logging but lacks financial operation specificity | No evaluation of audit completeness | 0.5 |

### Expected Key Behaviors
- Identify TOCTOU issues in account manager assignment validation
- Recognize race conditions in budget enforcement with 5-minute intervals
- Detect privilege escalation risks from stale JWT claims
- Note missing operation-level authorization in service mesh
- Question annual API key rotation adequacy for high-volume exchanges
- Identify gaps in financial audit trail (budget changes, bid modifications)

### Anti-patterns
- Accepting mTLS as complete inter-service security without authorization analysis
- Overlooking distributed system consistency challenges in real-time bidding
- Missing time-of-check vs time-of-use vulnerabilities in authorization
- Assuming JWT tokens are sufficient without examining revocation and staleness
- Focusing on authentication mechanisms without evaluating authorization enforcement

---

## Summary Statistics

- **Total scenarios**: 7
- **Difficulty distribution**: Easy (1), Medium (3), Hard (3)
- **Total criteria**: 31
- **Weight 1.0 criteria**: 23
- **Weight 0.5 criteria**: 8

### Category Coverage

| Category | Scenarios |
|----------|-----------|
| Authentication & Authorization Design | T01, T07 |
| Data Protection | T02 |
| Input Validation & Attack Defense | T03, T06 |
| Threat Modeling (STRIDE) | T04 |
| Infrastructure & Dependencies | T05 |
