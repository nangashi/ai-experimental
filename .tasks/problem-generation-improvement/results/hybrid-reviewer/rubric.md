# Scoring Rubric: security-design-reviewer

Generated using: v001-variant-type-bank-hybrid
Agent Type: Type-A (Document Reviewer)

## Scoring Formula

```
scenario_score = (Σ(rating × weight) + bonus - penalty) / max_possible × 10
rating: ○=2, △=1, ×=0
bonus: +0.5pt each (capped per scenario)
penalty: -0.5pt each
```

---

## Problem Bank

### PB-01: SMS-based MFA Vulnerability
- **Category**: Authentication & Authorization Design
- **Importance**: High
- **○ (Full)**: Identifies SMS as weak MFA method with specific risks (SIM swap, interception) AND recommends stronger alternatives (hardware token, push notification, WebAuthn)
- **△ (Partial)**: Notes MFA security concern but lacks specificity on SMS risks OR doesn't provide concrete stronger alternatives
- **× (Miss)**: No mention of MFA method security

### PB-02: JWT Token Storage in localStorage
- **Category**: Authentication & Authorization Design
- **Importance**: High
- **○ (Full)**: Identifies XSS vulnerability from localStorage token storage AND recommends httpOnly cookies or secure alternative with XSS risk mitigation
- **△ (Partial)**: Mentions token storage security issue OR XSS risk but lacks specific secure alternative recommendation
- **× (Miss)**: No mention of token storage vulnerability

### PB-03: Weak Password Policy
- **Category**: Authentication & Authorization Design
- **Importance**: Medium
- **○ (Full)**: Identifies insufficient password requirements for healthcare system AND recommends stronger policy aligned with NIST/HIPAA guidance (complexity, length, common password checks)
- **△ (Partial)**: Notes password weakness but lacks healthcare context OR doesn't provide specific policy recommendations
- **× (Miss)**: No mention of password policy

### PB-04: Price Manipulation Vulnerability
- **Category**: Input Validation & Attack Defense
- **Importance**: High
- **○ (Full)**: Identifies client-controlled price parameter as tampering risk AND recommends server-side price lookup from product catalog
- **△ (Partial)**: Notes price validation concern but lacks specificity on tampering risk OR solution
- **× (Miss)**: No mention of price parameter security

### PB-05: Refresh Token Not Rotated
- **Category**: Authentication & Authorization Design
- **Importance**: High
- **○ (Full)**: Identifies lack of refresh token rotation as token theft risk AND recommends one-time-use tokens with rotation on each refresh
- **△ (Partial)**: Notes refresh token security concern but lacks specificity on rotation requirement
- **× (Miss)**: No mention of refresh token rotation

### PB-06: Missing Step-up Authentication
- **Category**: Authentication & Authorization Design
- **Importance**: Medium
- **○ (Full)**: Identifies inconsistent re-authentication (present for some operations but missing for high-risk operations) AND recommends consistent step-up auth policy
- **△ (Partial)**: Notes authentication concern but lacks specificity on step-up requirement OR inconsistency
- **× (Miss)**: No mention of step-up authentication

### PB-07: Device Command Injection
- **Category**: Input Validation & Attack Defense
- **Importance**: High
- **○ (Full)**: Identifies lack of input validation on command parameters AND risk of command injection to MQTT devices with specific validation requirements
- **△ (Partial)**: Mentions need for command validation OR security concern but lacks specificity on injection risk OR validation approach
- **× (Miss)**: No mention of command parameter validation

### PB-08: Insufficient Data Classification
- **Category**: Data Protection
- **Importance**: High
- **○ (Full)**: Identifies lack of PII/PHI classification and retention policies required for HIPAA compliance AND recommends data classification framework with retention periods
- **△ (Partial)**: Mentions missing data classification OR retention but lacks HIPAA compliance context
- **× (Miss)**: No mention of data classification or retention

### PB-09: SQL Injection Risk
- **Category**: Input Validation & Attack Defense
- **Importance**: High
- **○ (Full)**: Identifies potential SQL injection from specific parameters AND recommends parameterized queries or ORM usage
- **△ (Partial)**: Mentions SQL injection risk generally but doesn't tie to specific parameters OR doesn't provide concrete solution
- **× (Miss)**: No mention of SQL injection

### PB-10: Insufficient Audit Logging
- **Category**: Infrastructure, Dependencies & Audit
- **Importance**: Medium
- **○ (Full)**: Identifies missing audit events (role changes, policy modifications, MFA resets) critical for security monitoring AND recommends comprehensive audit logging for privileged operations
- **△ (Partial)**: Notes incomplete logging but lacks specificity on missing critical events
- **× (Miss)**: No mention of audit logging gaps

### PB-11: Sensitive Data in Email Notifications
- **Category**: Data Protection
- **Importance**: Medium
- **○ (Full)**: Identifies message preview in email as PHI leakage risk AND recommends notification without sensitive content (portal link only)
- **△ (Partial)**: Notes email security concern but doesn't specifically identify preview leakage risk
- **× (Miss)**: No mention of email notification security

### PB-12: Insecure Authorization on Cancel Order
- **Category**: Authentication & Authorization Design
- **Importance**: High
- **○ (Full)**: Identifies missing order ownership verification on DELETE endpoint AND recommends authorization check before cancellation (IDOR vulnerability)
- **△ (Partial)**: Notes authorization concern but lacks specificity on order ownership check
- **× (Miss)**: No mention of cancel order authorization

### PB-13: Secrets in ConfigMaps
- **Category**: Infrastructure, Dependencies & Audit
- **Importance**: High
- **○ (Full)**: Identifies ConfigMaps as inappropriate for secrets storage AND recommends Kubernetes Secrets or external secret manager with encryption at rest
- **△ (Partial)**: Mentions secret management concern OR ConfigMaps issue but lacks specific secure alternative
- **× (Miss)**: No mention of ConfigMaps security issue

### PB-14: Missing Webhook Signature Verification
- **Category**: Input Validation & Attack Defense
- **Importance**: High
- **○ (Full)**: Identifies lack of authentication/signature verification on webhook AND recommends HMAC signature validation or shared secret
- **△ (Partial)**: Notes webhook security concern but lacks specificity on signature verification
- **× (Miss)**: No mention of webhook security

### PB-15: Session Token in Configuration File
- **Category**: Data Protection
- **Importance**: Medium
- **○ (Full)**: Identifies session token storage in config file as credential exposure risk AND recommends secure storage (OS keychain, encrypted credential store)
- **△ (Partial)**: Mentions token storage concern but lacks specificity on exposure risk OR secure alternative
- **× (Miss)**: No mention of token storage security

### PB-16: Database Backup Encryption
- **Category**: Data Protection
- **Importance**: High
- **○ (Full)**: Identifies missing encryption for backups in S3 AND recommends encryption at rest with key management (KMS)
- **△ (Partial)**: Mentions backup security concern but lacks specificity on encryption requirement
- **× (Miss)**: No mention of backup security

### PB-17: WebSocket Re-authentication Gap
- **Category**: Authentication & Authorization Design
- **Importance**: Medium
- **○ (Full)**: Identifies lack of periodic re-authentication on long-lived WebSocket connections as session hijacking risk AND recommends periodic token refresh or connection time limits
- **△ (Partial)**: Notes WebSocket security concern but lacks specificity on re-authentication requirement
- **× (Miss)**: No mention of WebSocket authentication

### PB-18: Race Condition in Inventory
- **Category**: Threat Modeling (STRIDE)
- **Importance**: Medium
- **○ (Full)**: Identifies background inventory update creating race condition (overselling risk) AND recommends atomic operations or pessimistic locking
- **△ (Partial)**: Mentions inventory synchronization issue but lacks specificity on race condition OR solution
- **× (Miss)**: No mention of inventory concurrency issue

### PB-19: Self-signed Certificate Authority
- **Category**: Infrastructure, Dependencies & Audit
- **Importance**: Medium
- **○ (Full)**: Identifies self-signed CA as trust and key management risk AND recommends enterprise CA or managed PKI service with proper key protection
- **△ (Partial)**: Notes certificate security concern but lacks specificity on self-signed risks
- **× (Miss)**: No mention of CA security

### PB-20: No Pagination on Transaction History
- **Category**: Threat Modeling (STRIDE) - Denial of Service
- **Importance**: Medium
- **○ (Full)**: Identifies missing pagination as DoS risk (memory exhaustion, slow queries) AND recommends pagination with reasonable limits
- **△ (Partial)**: Notes transaction query concern but lacks specificity on DoS risk OR pagination
- **× (Miss)**: No mention of transaction query issues

### PB-21: Vulnerable Dependencies
- **Category**: Infrastructure, Dependencies & Audit
- **Importance**: High
- **○ (Full)**: Identifies outdated dependency (Lodash 4.17.0) with known vulnerabilities AND recommends dependency scanning, version updates, and automated vulnerability monitoring
- **△ (Partial)**: Notes dependency security concern but lacks specificity on vulnerability risk OR scanning process
- **× (Miss)**: No mention of dependency vulnerabilities

### PB-22: Secrets in Git Repository
- **Category**: Infrastructure, Dependencies & Audit
- **Importance**: High
- **○ (Full)**: Identifies .env file committed to git as credential exposure risk AND recommends secret manager with git history cleanup
- **△ (Partial)**: Notes secret management concern but lacks specificity on git exposure OR secure alternative
- **× (Miss)**: No mention of secrets in git

### PB-23: SQL Injection in Query Interface
- **Category**: Input Validation & Attack Defense
- **Importance**: High
- **○ (Full)**: Identifies free-form SQL input as injection risk even for read-only queries (data exfiltration) AND recommends parameterized query builder or pre-defined templates
- **△ (Partial)**: Notes SQL query security concern but lacks specificity on injection risk despite read-only context
- **× (Miss)**: No mention of SQL query interface security

### PB-24: Stored XSS Vulnerability
- **Category**: Input Validation & Attack Defense
- **Importance**: High
- **○ (Full)**: Identifies unsanitized HTML storage and rendering as XSS risk AND recommends input sanitization (DOMPurify) or CSP with output escaping
- **△ (Partial)**: Notes XSS concern but lacks specificity on stored XSS risk OR sanitization approach
- **× (Miss)**: No mention of XSS vulnerability

### PB-25: SSRF in Export Function
- **Category**: Input Validation & Attack Defense
- **Importance**: High
- **○ (Full)**: Identifies Puppeteer rendering user content as SSRF risk (malicious HTML with external resource fetches) AND recommends sandboxing or content validation
- **△ (Partial)**: Notes export security concern but lacks specificity on SSRF risk
- **× (Miss)**: No mention of export function security

### PB-26: SQL Injection in Search
- **Category**: Input Validation & Attack Defense
- **Importance**: High
- **○ (Full)**: Identifies raw SQL string concatenation in search as SQL injection risk AND recommends parameterized queries or ORM
- **△ (Partial)**: Notes search security concern but lacks specificity on SQL injection OR solution
- **× (Miss)**: No mention of search function security

### PB-27: Path Traversal in File Storage
- **Category**: Input Validation & Attack Defense
- **Importance**: Medium
- **○ (Full)**: Identifies use of original filename in S3 key as path traversal risk AND recommends UUID-based keys or filename sanitization
- **△ (Partial)**: Notes file storage concern but lacks specificity on path traversal OR solution
- **× (Miss)**: No mention of file storage security

### PB-28: Command Injection in Webhook
- **Category**: Input Validation & Attack Defense
- **Importance**: Medium
- **○ (Full)**: Identifies unvalidated user input in webhook payload as command injection risk AND recommends input validation or structured format
- **△ (Partial)**: Notes webhook security concern but lacks specificity on injection risk
- **× (Miss)**: No mention of webhook security

### PB-29: Weak Tenant Isolation
- **Category**: Data Protection
- **Importance**: High
- **○ (Full)**: Identifies SQL string concatenation for tenant filtering as tenant data leakage risk (SQL injection can bypass tenant_id filter) AND recommends database-level isolation (RLS policies, separate schemas) or parameterized queries with defense-in-depth
- **△ (Partial)**: Notes tenant isolation concern but lacks specificity on SQL injection bypass risk OR architectural solution
- **× (Miss)**: No mention of tenant isolation security

### PB-30: Shared Database Credentials
- **Category**: Infrastructure, Dependencies & Audit
- **Importance**: Medium
- **○ (Full)**: Identifies single database user for all queries as privilege escalation and isolation risk AND recommends per-tenant database roles or connection pooling with tenant-specific credentials
- **△ (Partial)**: Notes database access concern but lacks specificity on shared credential risk
- **× (Miss)**: No mention of database credential model

### PB-31: Missing PII Detection and Masking
- **Category**: Data Protection
- **Importance**: High
- **○ (Full)**: Identifies lack of PII detection/masking as privacy compliance risk (GDPR, CCPA) AND recommends automated PII scanning with masking or tokenization policies
- **△ (Partial)**: Notes PII handling concern but lacks specificity on detection/masking requirement
- **× (Miss)**: No mention of PII handling

### PB-32: Insecure File Storage
- **Category**: Data Protection
- **Importance**: Medium
- **○ (Full)**: Identifies shared S3 bucket with predictable filenames as cross-tenant file access risk AND recommends tenant-specific prefixes or separate buckets with IAM policies
- **△ (Partial)**: Notes file storage concern but lacks specificity on cross-tenant access risk
- **× (Miss)**: No mention of file storage security

### PB-33: Shared Redis Cache Without Tenant Isolation
- **Category**: Data Protection
- **Importance**: Low
- **○ (Full)**: Identifies shared Redis instance without tenant key namespacing as cache poisoning/data leakage risk AND recommends tenant-prefixed keys or separate cache instances
- **△ (Partial)**: Notes cache security concern but lacks specificity on tenant isolation in cache
- **× (Miss)**: No mention of cache security

---

## Answer Keys by Scenario

### T01: IoT Smart Home Hub API (Easy)

**AK-T01-01 (PB-02): JWT Token Storage in localStorage** [Weight: 1.0]
- ○: Identifies XSS vulnerability from localStorage token storage AND recommends httpOnly cookies or secure alternative with XSS risk mitigation
- △: Mentions token storage security issue OR XSS risk but lacks specific secure alternative recommendation
- ×: No mention of token storage vulnerability

**AK-T01-02 (PB-07): Device Command Injection** [Weight: 1.0]
- ○: Identifies lack of input validation on command parameters AND risk of command injection to MQTT devices with specific validation requirements
- △: Mentions need for command validation OR security concern but lacks specificity on injection risk or validation approach
- ×: No mention of command parameter validation

**AK-T01-03 (PB-13): Secrets in ConfigMaps** [Weight: 1.0]
- ○: Identifies ConfigMaps as inappropriate for secrets storage AND recommends Kubernetes Secrets or external secret manager with encryption at rest
- △: Mentions secret management concern OR ConfigMaps issue but lacks specific secure alternative
- ×: No mention of ConfigMaps security issue

**Max Score**: 6.0pt (3 problems × 2pt) + 1.5pt bonus = 7.5pt

---

### T02: Healthcare Patient Portal (Medium)

**AK-T02-01 (PB-03): Weak Password Policy** [Weight: 1.0]
- ○: Identifies insufficient password requirements (only 8 chars + number) for healthcare system AND recommends stronger policy aligned with NIST/HIPAA guidance
- △: Notes password weakness but lacks healthcare context or specific policy recommendations
- ×: No mention of password policy

**AK-T02-02 (PB-08): Insufficient Data Classification** [Weight: 1.0]
- ○: Identifies lack of PII/PHI classification and retention policies required for HIPAA compliance AND recommends data classification framework with retention periods
- △: Mentions missing data classification OR retention but lacks HIPAA compliance context
- ×: No mention of data classification or retention

**AK-T02-03 (PB-11): Sensitive Data in Email Notifications** [Weight: 1.0]
- ○: Identifies message preview in email as PHI leakage risk AND recommends notification without sensitive content
- △: Notes email security concern but doesn't specifically identify preview leakage risk
- ×: No mention of email notification security

**AK-T02-04 (PB-16): Database Backup Encryption** [Weight: 1.0]
- ○: Identifies missing encryption for backups in S3 AND recommends encryption at rest with key management
- △: Mentions backup security concern but lacks specificity on encryption requirement
- ×: No mention of backup security

**Max Score**: 8.0pt (4 problems × 2pt) + 2.0pt bonus = 10.0pt

---

### T03: E-commerce Order Processing API (Medium)

**AK-T03-01 (PB-04): Price Manipulation Vulnerability** [Weight: 1.0]
- ○: Identifies client-controlled price parameter as tampering risk AND recommends server-side price lookup
- △: Notes price validation concern but lacks specificity on tampering risk or solution
- ×: No mention of price parameter security

**AK-T03-02 (PB-09): SQL Injection Risk** [Weight: 1.0]
- ○: Identifies potential SQL injection from specific parameters AND recommends parameterized queries or ORM
- △: Mentions SQL injection risk generally but doesn't tie to specific parameters or provide concrete solution
- ×: No mention of SQL injection

**AK-T03-03 (PB-14): Missing Webhook Signature Verification** [Weight: 1.0]
- ○: Identifies lack of authentication/signature verification on inventory webhook AND recommends HMAC signature validation
- △: Notes webhook security concern but lacks specificity on signature verification
- ×: No mention of webhook security

**AK-T03-04 (PB-18): Race Condition in Inventory** [Weight: 1.0]
- ○: Identifies background inventory update creating race condition AND recommends atomic operations or pessimistic locking
- △: Mentions inventory synchronization issue but lacks specificity on race condition or solution
- ×: No mention of inventory concurrency issue

**Max Score**: 8.0pt (4 problems × 2pt) + 2.0pt bonus = 10.0pt

---

### T04: Corporate VPN Access System (Medium)

**AK-T04-01 (PB-01): SMS-based MFA Vulnerability** [Weight: 1.0]
- ○: Identifies SMS as weak MFA method (SIM swap, interception risks) AND recommends hardware token, push notification, or WebAuthn
- △: Notes MFA security concern but lacks specificity on SMS risks or stronger alternatives
- ×: No mention of MFA method security

**AK-T04-02 (PB-10): Insufficient Audit Logging** [Weight: 1.0]
- ○: Identifies missing audit events (role changes, policy modifications, MFA resets) critical for security monitoring AND recommends comprehensive audit logging
- △: Notes incomplete logging but lacks specificity on missing critical events
- ×: No mention of audit logging gaps

**AK-T04-03 (PB-15): Session Token in Configuration File** [Weight: 1.0]
- ○: Identifies session token storage in config file as credential exposure risk AND recommends secure storage
- △: Mentions token storage concern but lacks specificity on exposure risk or secure alternative
- ×: No mention of token storage security

**AK-T04-04 (PB-19): Self-signed Certificate Authority** [Weight: 1.0]
- ○: Identifies self-signed CA as trust and key management risk AND recommends enterprise CA or managed PKI service
- △: Notes certificate security concern but lacks specificity on self-signed risks
- ×: No mention of CA security

**Max Score**: 8.0pt (4 problems × 2pt) + 2.0pt bonus = 10.0pt

---

### T05: Financial Trading Platform (Hard)

**AK-T05-01 (PB-05): Refresh Token Not Rotated** [Weight: 1.0]
- ○: Identifies lack of refresh token rotation as token theft risk AND recommends one-time-use tokens with rotation
- △: Notes refresh token security concern but lacks specificity on rotation requirement
- ×: No mention of refresh token rotation

**AK-T05-02 (PB-06): Missing Step-up Authentication** [Weight: 1.0]
- ○: Identifies inconsistent re-authentication AND recommends consistent step-up auth policy
- △: Notes authentication concern but lacks specificity on step-up requirement or inconsistency
- ×: No mention of step-up authentication

**AK-T05-03 (PB-12): Insecure Authorization on Cancel Order** [Weight: 1.0]
- ○: Identifies missing order ownership verification AND recommends authorization check (IDOR vulnerability)
- △: Notes authorization concern but lacks specificity on order ownership check
- ×: No mention of cancel order authorization

**AK-T05-04 (PB-17): WebSocket Re-authentication Gap** [Weight: 1.0]
- ○: Identifies lack of periodic re-authentication on WebSocket connections as session hijacking risk AND recommends periodic token refresh
- △: Notes WebSocket security concern but lacks specificity on re-authentication requirement
- ×: No mention of WebSocket authentication

**AK-T05-05 (PB-20): No Pagination on Transaction History** [Weight: 1.0]
- ○: Identifies missing pagination as DoS risk AND recommends pagination with reasonable limits
- △: Notes transaction query concern but lacks specificity on DoS risk or pagination
- ×: No mention of transaction query issues

**Max Score**: 10.0pt (5 problems × 2pt) + 2.5pt bonus = 12.5pt

---

### T06: SaaS Admin Dashboard (Easy)

**AK-T06-01 (PB-21): Vulnerable Dependencies** [Weight: 1.0]
- ○: Identifies outdated dependency with known vulnerabilities AND recommends dependency scanning and automated monitoring
- △: Notes dependency security concern but lacks specificity on vulnerability risk or scanning process
- ×: No mention of dependency vulnerabilities

**AK-T06-02 (PB-22): Secrets in Git Repository** [Weight: 1.0]
- ○: Identifies .env file committed to git as credential exposure risk AND recommends secret manager with git history cleanup
- △: Notes secret management concern but lacks specificity on git exposure or secure alternative
- ×: No mention of secrets in git

**AK-T06-03 (PB-23): SQL Injection in Query Interface** [Weight: 1.0]
- ○: Identifies free-form SQL input as injection risk even for read-only queries AND recommends parameterized query builder
- △: Notes SQL query security concern but lacks specificity on injection risk despite read-only context
- ×: No mention of SQL query interface security

**Max Score**: 6.0pt (3 problems × 2pt) + 1.5pt bonus = 7.5pt

---

### T07: Real-time Collaboration Platform (Hard)

**AK-T07-01 (PB-24): Stored XSS Vulnerability** [Weight: 1.0]
- ○: Identifies unsanitized HTML storage and rendering as XSS risk AND recommends input sanitization or CSP with output escaping
- △: Notes XSS concern but lacks specificity on stored XSS risk or sanitization approach
- ×: No mention of XSS vulnerability

**AK-T07-02 (PB-25): SSRF in Export Function** [Weight: 1.0]
- ○: Identifies Puppeteer rendering user content as SSRF risk AND recommends sandboxing or content validation
- △: Notes export security concern but lacks specificity on SSRF risk
- ×: No mention of export function security

**AK-T07-03 (PB-26): SQL Injection in Search** [Weight: 1.0]
- ○: Identifies raw SQL string concatenation as SQL injection risk AND recommends parameterized queries
- △: Notes search security concern but lacks specificity on SQL injection or solution
- ×: No mention of search function security

**AK-T07-04 (PB-27): Path Traversal in File Storage** [Weight: 1.0]
- ○: Identifies use of original filename in S3 key as path traversal risk AND recommends UUID-based keys
- △: Notes file storage concern but lacks specificity on path traversal or solution
- ×: No mention of file storage security

**AK-T07-05 (PB-28): Command Injection in Webhook** [Weight: 1.0]
- ○: Identifies unvalidated user input in webhook payload as command injection risk AND recommends input validation
- △: Notes webhook security concern but lacks specificity on injection risk
- ×: No mention of webhook security

**Max Score**: 10.0pt (5 problems × 2pt) + 2.5pt bonus = 12.5pt

---

### T08: Multi-tenant SaaS Analytics Platform (Hard)

**AK-T08-01 (PB-29): Weak Tenant Isolation** [Weight: 1.0]
- ○: Identifies SQL string concatenation for tenant filtering as tenant data leakage risk AND recommends database-level isolation or parameterized queries
- △: Notes tenant isolation concern but lacks specificity on SQL injection bypass risk or architectural solution
- ×: No mention of tenant isolation security

**AK-T08-02 (PB-30): Shared Database Credentials** [Weight: 1.0]
- ○: Identifies single database user as privilege escalation risk AND recommends per-tenant database roles
- △: Notes database access concern but lacks specificity on shared credential risk
- ×: No mention of database credential model

**AK-T08-03 (PB-31): Missing PII Detection and Masking** [Weight: 1.0]
- ○: Identifies lack of PII detection/masking as privacy compliance risk AND recommends automated PII scanning with masking
- △: Notes PII handling concern but lacks specificity on detection/masking requirement
- ×: No mention of PII handling

**AK-T08-04 (PB-32): Insecure File Storage** [Weight: 1.0]
- ○: Identifies shared S3 bucket with predictable filenames as cross-tenant file access risk AND recommends tenant-specific prefixes
- △: Notes file storage concern but lacks specificity on cross-tenant access risk
- ×: No mention of file storage security

**AK-T08-05 (PB-33): Shared Redis Cache Without Tenant Isolation** [Weight: 1.0]
- ○: Identifies shared Redis without tenant key namespacing as cache poisoning risk AND recommends tenant-prefixed keys
- △: Notes cache security concern but lacks specificity on tenant isolation
- ×: No mention of cache security

**Max Score**: 10.0pt (5 problems × 2pt) + 2.5pt bonus = 12.5pt

---

## Category Distribution

| Category | Problems | Percentage |
|----------|----------|------------|
| Authentication & Authorization Design | 8 | 24.2% |
| Input Validation & Attack Defense | 11 | 33.3% |
| Data Protection | 8 | 24.2% |
| Infrastructure, Dependencies & Audit | 5 | 15.2% |
| Threat Modeling (STRIDE) | 1 | 3.0% |

## Importance Distribution

| Importance | Count | Percentage |
|------------|-------|------------|
| High | 20 | 60.6% |
| Medium | 11 | 33.3% |
| Low | 2 | 6.1% |

## Scenario Summary

| ID | Title | Difficulty | Problems | Max Score |
|----|-------|-----------|----------|-----------|
| T01 | IoT Smart Home Hub API | Easy | 3 | 7.5pt |
| T02 | Healthcare Patient Portal | Medium | 4 | 10.0pt |
| T03 | E-commerce Order Processing API | Medium | 4 | 10.0pt |
| T04 | Corporate VPN Access System | Medium | 4 | 10.0pt |
| T05 | Financial Trading Platform | Hard | 5 | 12.5pt |
| T06 | SaaS Admin Dashboard | Easy | 3 | 7.5pt |
| T07 | Real-time Collaboration Platform | Hard | 5 | 12.5pt |
| T08 | Multi-tenant SaaS Analytics Platform | Hard | 5 | 12.5pt |

**Total Problems**: 33
**Total Scenarios**: 8
