# Evaluation Rubric: security-design-reviewer

## Agent Information
- **Agent Name**: security-design-reviewer
- **Agent Type**: Type-A (Document Reviewer)
- **Evaluation Focus**: Architecture-level security evaluation with problem detection, impact analysis, and countermeasure recommendations

## Scoring Methodology

### Criterion Scoring
Each criterion is scored as:
- **Full (2 points)**: Identifies the core security issue with specific attack vector/scenario and provides concrete countermeasures
- **Partial (1 point)**: Mentions related security concerns but lacks specificity or misses the core attack mechanism
- **Miss (0 points)**: Does not identify the security issue

### Weight Application
- **Weight 1.0**: Core security issues directly aligned with agent's evaluation criteria
- **Weight 0.5**: Supporting or supplementary security concerns

### Scenario Score Calculation
`Scenario Score = Σ(Criterion Score × Weight)`

### Total Score
`Total Score = Σ(All Scenario Scores)`

**Maximum Possible Score**: 49.0 points

---

## Test Scenarios Summary

| Scenario | Difficulty | Category | Criteria Count | Max Score |
|----------|-----------|----------|---------------|-----------|
| T01 | Medium | Authentication & Authorization, Data Protection | 5 | 8.0 |
| T02 | Hard | Threat Modeling, Input Validation & Attack Defense | 6 | 9.0 |
| T03 | Easy | Input Validation & Attack Defense | 5 | 8.0 |
| T04 | Hard | Infrastructure/Dependencies/Audit, Authentication | 6 | 9.0 |
| T05 | Medium | Authentication & Authorization, Threat Modeling | 5 | 8.0 |
| T06 | Medium | Input Validation, Data Protection | 5 | 8.0 |
| T07 | Easy | Threat Modeling, Infrastructure/Audit | 5 | 8.0 |

---

## Detailed Evaluation Criteria

### T01: Multi-Tenant SaaS Analytics Platform (8.0 points)

| Criterion ID | Description | Weight | Scoring Guide |
|-------------|-------------|--------|---------------|
| T01-C1 | Tenant Isolation Vulnerability | 1.0 | **Full**: Identifies SQL injection or JWT manipulation enabling cross-tenant data access with specific attack scenario. **Partial**: Mentions authorization concerns without specific attack vector. **Miss**: Does not identify tenant isolation risk. |
| T01-C2 | JWT Token Security | 1.0 | **Full**: Identifies multiple JWT issues including insecure storage, lack of refresh mechanism, and 24-hour expiration risk. **Partial**: Identifies one JWT concern (storage OR expiration OR refresh). **Miss**: Does not address JWT security. |
| T01-C3 | Data Protection at Rest | 1.0 | **Full**: Identifies lack of encryption for PII in both PostgreSQL and S3 with specific recommendations. **Partial**: Mentions encryption need but lacks specificity on data stores. **Miss**: Does not identify encryption requirements. |
| T01-C4 | Export URL Security | 1.0 | **Full**: Identifies predictable S3 paths and lack of signed URLs/access controls with specific attack scenario. **Partial**: Mentions S3 security generically. **Miss**: Does not identify export access control issues. |
| T01-C5 | Session Management | 0.5 | **Full**: Identifies multiple Redis session security issues (encryption in transit/at rest, timeout policy, invalidation mechanism). **Partial**: Mentions one session concern. **Miss**: Does not address session management. |

**Key Issues Embedded**:
- Tenant isolation via SQL injection in `WHERE orgId = ?` query with unvalidated JWT payload
- JWT security gaps (client-side storage, 24-hour expiration, no refresh flow)
- Unencrypted PII in PostgreSQL and S3
- Predictable S3 export paths `s3://bucket/exports/{orgId}/{reportId}.pdf`
- Redis session data security

---

### T02: Healthcare Appointment Booking API (9.0 points)

| Criterion ID | Description | Weight | Scoring Guide |
|-------------|-------------|--------|---------------|
| T02-C1 | SQL Injection via Reason Field | 1.0 | **Full**: Identifies SQL injection risk in unescaped reason field with attack scenario. **Partial**: Mentions input validation need without SQL injection specificity. **Miss**: Does not identify SQL injection. |
| T02-C2 | SSRF in Insurance API Call | 1.0 | **Full**: Identifies SSRF vulnerability in unvalidated insurance provider parameter used in URL construction. **Partial**: Mentions API security without SSRF specificity. **Miss**: Does not identify SSRF. |
| T02-C3 | DoS/Resource Exhaustion | 1.0 | **Full**: Identifies lack of rate limiting and queue flooding risk through appointment spam with attack scenario. **Partial**: Mentions rate limiting need without attack scenario. **Miss**: Does not identify DoS vulnerability. |
| T02-C4 | Authorization Bypass in DELETE | 1.0 | **Full**: Identifies IDOR vulnerability where JWT patientId can be manipulated to cancel others' appointments. **Partial**: Mentions authorization concern without bypass mechanism. **Miss**: Does not identify authorization vulnerability. |
| T02-C5 | Information Disclosure in Errors | 0.5 | **Full**: Identifies security risk of detailed error messages revealing system internals with specific examples. **Partial**: Mentions error handling without security implications. **Miss**: Does not identify information disclosure. |
| T02-C6 | Message Queue Security | 0.5 | **Full**: Identifies lack of authentication/encryption for RabbitMQ notifications containing PII. **Partial**: Mentions notification security generically. **Miss**: Does not address message queue security. |

**Key Issues Embedded**:
- SQL injection in reason field stored as-is
- SSRF via `https://insurance-api.com/verify?provider={insuranceProvider}`
- DoS via unlimited appointment creation → queue flooding
- IDOR in DELETE endpoint JWT validation
- Information disclosure via error messages
- Unencrypted PII in RabbitMQ

---

### T03: Content Management System with File Upload (8.0 points)

| Criterion ID | Description | Weight | Scoring Guide |
|-------------|-------------|--------|---------------|
| T03-C1 | File Extension Bypass | 1.0 | **Full**: Identifies extension bypass techniques (double extensions, MIME mismatch, case sensitivity) and recommends magic byte validation. **Partial**: Mentions need for better validation without bypass techniques. **Miss**: Does not identify file validation vulnerabilities. |
| T03-C2 | Path Traversal | 1.0 | **Full**: Identifies path traversal risk in filename handling and recommends sanitization/random naming. **Partial**: Mentions filename security without attack vector. **Miss**: Does not identify path traversal. |
| T03-C3 | Command Injection in ImageMagick | 1.0 | **Full**: Identifies command injection risk in `convert {filepath} {outputpath}` and recommends sanitization or alternatives. **Partial**: Mentions processing security generically. **Miss**: Does not identify command injection. |
| T03-C4 | Unrestricted File Access | 0.5 | **Full**: Identifies information disclosure from public file access and recommends access controls. **Partial**: Mentions authentication need without impact. **Miss**: Does not identify access control issue. |
| T03-C5 | XSS via Content-Type | 1.0 | **Full**: Identifies XSS risk from auto-detected Content-Type serving HTML/SVG with scripts. **Partial**: Mentions Content-Type security without XSS scenario. **Miss**: Does not identify XSS. |

**Key Issues Embedded**:
- File extension whitelist bypassable (double extensions, case sensitivity)
- Path traversal in `/var/www/uploads/{filename}`
- Command injection in ImageMagick convert command
- Public file access without authentication
- XSS via auto-detected Content-Type serving malicious HTML/SVG

---

### T04: Microservices E-Commerce Platform (9.0 points)

| Criterion ID | Description | Weight | Scoring Guide |
|-------------|-------------|--------|---------------|
| T04-C1 | Hardcoded Secrets | 1.0 | **Full**: Identifies multiple secret leakage risks (hardcoded JWT secret, env files, docker-compose credentials) with remediation using secrets management tools. **Partial**: Mentions secrets management without all exposure points. **Miss**: Does not identify secret management issues. |
| T04-C2 | Weak Service-to-Service Auth | 1.0 | **Full**: Identifies inadequate API key authentication for internal services and recommends mutual TLS or service mesh. **Partial**: Mentions need for internal auth without specific recommendations. **Miss**: Does not identify internal auth weakness. |
| T04-C3 | Shared Database Security | 1.0 | **Full**: Identifies security risks of shared database (privilege escalation, lack of isolation) and recommends dedicated databases or strict access controls. **Partial**: Mentions database security generically. **Miss**: Does not identify shared database risks. |
| T04-C4 | Dependency Vulnerabilities | 1.0 | **Full**: Identifies lack of vulnerability scanning and automated updates with specific tools (Dependabot, Snyk). **Partial**: Mentions dependency management without security implications. **Miss**: Does not identify dependency vulnerability risk. |
| T04-C5 | Security Audit Logging | 0.5 | **Full**: Identifies insufficient audit logging (no centralized logs, no security event monitoring, console-only logging) with recommendations. **Partial**: Mentions logging improvement without security focus. **Miss**: Does not identify audit logging gaps. |
| T04-C6 | Network Segmentation | 0.5 | **Full**: Identifies lack of network isolation between services and external attack surface. **Partial**: Mentions network security generically. **Miss**: Does not identify network segmentation issues. |

**Key Issues Embedded**:
- Hardcoded JWT secret: `const SECRET = "my-jwt-secret-2023"`
- API keys in environment variables and docker-compose.yml
- Weak service-to-service auth via static API keys
- Shared PostgreSQL database across all services
- No dependency vulnerability scanning
- Insufficient security audit logging
- Lack of network segmentation

---

### T05: Mobile Banking App Backend (8.0 points)

| Criterion ID | Description | Weight | Scoring Guide |
|-------------|-------------|--------|---------------|
| T05-C1 | Weak PIN Security | 1.0 | **Full**: Identifies MD5 vulnerability for PIN storage AND plain text PIN transmission. **Partial**: Identifies one PIN security issue (storage OR transmission). **Miss**: Does not identify PIN security weaknesses. |
| T05-C2 | Token Storage and Replay Risk | 1.0 | **Full**: Identifies risks of client-side token storage without guidance on secure mechanisms (Keychain/Keystore). **Partial**: Mentions token security generically. **Miss**: Does not identify token storage issues. |
| T05-C3 | Password Reset Security | 1.0 | **Full**: Identifies weak reset code (6-digit numeric = 1M possibilities) AND lack of rate limiting enabling brute force. **Partial**: Identifies one reset issue (code weakness OR rate limiting). **Miss**: Does not identify password reset vulnerabilities. |
| T05-C4 | Lack of Access Token Revocation | 1.0 | **Full**: Identifies inability to invalidate compromised access tokens and recommends blacklisting or shorter expiration. **Partial**: Mentions token management without revocation-specific issue. **Miss**: Does not identify token revocation gap. |
| T05-C5 | Authorization Logic Vulnerabilities | 0.5 | **Full**: Identifies IDOR risk in accountId validation and recommends user-account relationship verification. **Partial**: Mentions authorization without specific bypass scenario. **Miss**: Does not identify authorization vulnerabilities. |

**Key Issues Embedded**:
- PIN stored as MD5 hash (weak cryptographic algorithm)
- PIN submitted as plain text in request body
- Weak password reset code (6-digit numeric)
- No rate limiting on reset attempts
- No access token revocation capability (stateless JWT)
- IDOR in account access validation
- No guidance on secure token storage on device

---

### T06: Real-Time Collaboration Platform (8.0 points)

| Criterion ID | Description | Weight | Scoring Guide |
|-------------|-------------|--------|---------------|
| T06-C1 | XSS in Content Rendering | 1.0 | **Full**: Identifies stored XSS from unescaped HTML content with specific attack scenario and sanitization recommendations. **Partial**: Mentions XSS risk without specific vector. **Miss**: Does not identify XSS. |
| T06-C2 | JWT Exposure in WebSocket URL | 1.0 | **Full**: Identifies security risk of JWT in query parameter (logged, cached) and recommends header-based auth. **Partial**: Mentions WebSocket auth without query parameter risk. **Miss**: Does not identify JWT exposure. |
| T06-C3 | NoSQL Injection in Mentions | 1.0 | **Full**: Identifies NoSQL injection risk in username lookup from @mention parsing. **Partial**: Mentions input validation without NoSQL injection specificity. **Miss**: Does not identify NoSQL injection. |
| T06-C4 | Race Condition in Access Control | 1.0 | **Full**: Identifies TOCTOU vulnerability where connection-time access check doesn't prevent unauthorized access after permission change. **Partial**: Mentions access control without race condition. **Miss**: Does not identify timing vulnerability. |
| T06-C5 | Data Leakage in History | 0.5 | **Full**: Identifies privacy risk where edit history exposes all contributions even after deletion. **Partial**: Mentions history feature without privacy implications. **Miss**: Does not identify data leakage. |

**Key Issues Embedded**:
- Stored XSS via unescaped HTML fragments in MongoDB
- JWT exposed in WebSocket URL query parameter
- NoSQL injection in @mention username lookup
- TOCTOU race condition in access control (check at connection, not per message)
- Privacy leak in persistent edit history

---

### T07: API Gateway with Rate Limiting (8.0 points)

| Criterion ID | Description | Weight | Scoring Guide |
|-------------|-------------|--------|---------------|
| T07-C1 | SQL Injection in Key Validation | 1.0 | **Full**: Identifies SQL injection in `SELECT * FROM api_keys WHERE key_value = ?` query and recommends parameterized queries. **Partial**: Mentions input validation without SQL injection. **Miss**: Does not identify SQL injection. |
| T07-C2 | Internal Traffic Encryption | 1.0 | **Full**: Identifies lack of encryption for gateway-to-service communication and recommends mutual TLS. **Partial**: Mentions encryption need generically. **Miss**: Does not identify internal traffic exposure. |
| T07-C3 | API Key Management Weaknesses | 1.0 | **Full**: Identifies risks of non-expiring keys, lack of rotation policy, and recommends lifecycle management. **Partial**: Identifies one key management issue. **Miss**: Does not identify key management problems. |
| T07-C4 | Sensitive Data in Logs | 1.0 | **Full**: Identifies API keys logged in plaintext and recommends log sanitization. **Partial**: Mentions logging security without specific data exposure. **Miss**: Does not identify log data leakage. |
| T07-C5 | Missing Security Audit | 0.5 | **Full**: Identifies lack of security event monitoring (key abuse, failed auth, anomaly detection). **Partial**: Mentions monitoring generically. **Miss**: Does not identify security audit gaps. |

**Key Issues Embedded**:
- SQL injection in API key validation query
- Unencrypted internal traffic (gateway to backend services)
- API keys never expire, no rotation policy
- API keys logged in plaintext to Elasticsearch
- No security event monitoring or anomaly detection

---

## Evaluation Guidelines

### Scoring Approach
1. Read the agent's evaluation output completely
2. For each criterion, determine if the agent identified the specific security issue
3. Assess the level of detail and actionability of recommendations
4. Apply the scoring rubric (Full/Partial/Miss) based on specificity and completeness
5. Calculate weighted scores for each scenario
6. Sum all scenario scores for total score

### Full Score Requirements
To achieve **Full (2 points)** on a criterion, the agent must:
- Identify the specific security vulnerability by name or clear description
- Explain the attack vector or exploitation scenario
- Provide concrete, actionable countermeasures
- Reference relevant parts of the design document

### Partial Score Indicators
**Partial (1 point)** is awarded when the agent:
- Mentions the security domain but misses the specific vulnerability
- Identifies the issue but lacks attack vector explanation
- Provides generic recommendations without specificity
- Touches on related concerns without hitting the core issue

### Miss Criteria
**Miss (0 points)** occurs when the agent:
- Does not mention the security issue at all
- Discusses unrelated security concerns
- Misidentifies the vulnerability type

### Quality Assessment Beyond Scoring
In addition to numerical scores, evaluate:
- **Coverage**: Does the agent systematically apply evaluation criteria from agent definition?
- **Prioritization**: Are critical issues highlighted appropriately?
- **Depth**: Are attack scenarios and impacts well-explained?
- **Actionability**: Are countermeasures specific and implementable?
- **Bonus Findings**: Identify security issues beyond embedded problems (award bonus points if discovered valid issues)

---

## Difficulty Distribution

- **Easy (2 scenarios)**: T03, T07 - 3-5 clear vulnerabilities, straightforward attack vectors
- **Medium (3 scenarios)**: T01, T05, T06 - 4-5 vulnerabilities, requires connecting design elements
- **Hard (2 scenarios)**: T02, T04 - 5-6 complex vulnerabilities, requires systematic threat analysis

## Category Coverage

All 5 capability categories from agent definition are covered:
1. **Threat Modeling (STRIDE)**: T02, T05, T07
2. **Authentication & Authorization Design**: T01, T04, T05
3. **Data Protection**: T01, T06
4. **Input Validation & Attack Defense**: T02, T03, T06
5. **Infrastructure, Dependencies & Audit**: T04, T07
