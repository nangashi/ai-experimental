# Scoring Report: table-centric

## Detection Matrix

### Run 1 Results

| Problem | Category | Severity | Detection | Score | Rationale |
|---------|----------|----------|-----------|-------|-----------|
| P01: JWT Token Storage in localStorage | Data Protection | Critical | △ | 0.5 | Row 33 mentions JWT in localStorage with XSS vulnerability, but recommendation is "Consider migrating to httpOnly cookies" (not definitive), and mentions CSP as alternative - partial detection |
| P02: Missing Authorization on DELETE Property Endpoint | Authentication/Authorization | Critical | × | 0.0 | No specific mention of DELETE endpoint resource ownership validation gap |
| P03: Lack of Input Validation Strategy for Property Address | Input Validation | Medium | ○ | 1.0 | Row 26 "No specification for validation rules... across all user inputs" with specific mention of "max length limits" - covers address field validation |
| P04: Insufficient Backup Encryption Specification | Data Protection | Medium | ○ | 1.0 | Row 46 "Database backup encryption not specified" - explicitly identifies this gap |
| P05: Missing API Idempotency Design for Payment Processing | Threat Modeling | Medium | ○ | 1.0 | Row 22 "No idempotency guarantees for payment processing" with duplicate charge risk - full detection |
| P06: Weak Rate Limiting Granularity | Threat Modeling | Medium | × | 0.0 | Row 30 mentions "No DoS protection beyond basic rate limiting" but does not identify IP-only limitation or shared IP issues |
| P07: Insufficient Session Revocation Mechanism | Authentication/Authorization | Medium | ○ | 1.0 | Row 28 "Session management specifications missing" mentions "No session timeout, concurrent session limits, or session invalidation strategy" |
| P08: Lack of Audit Logging for Sensitive Operations | Threat Modeling | Low | ○ | 1.0 | Row 24 "No audit logging design" with specific examples of security events to log |
| P09: Third-Party API Credential Storage Not Specified | Infrastructure/Dependencies | Low | ○ | 1.0 | Row 29 "Missing secrets management strategy" - AWS Parameter Store mentioned but no secret rotation/access controls |
| P10: Missing CORS Policy Definition | Input Validation | Low | ○ | 1.0 | Row 40 "No Cross-Origin Resource Sharing (CORS) policy" - explicit identification |

**Detection Score: 8.5 / 10**

### Run 2 Results

| Problem | Category | Severity | Detection | Score | Rationale |
|---------|----------|----------|-----------|-------|-----------|
| P01: JWT Token Storage in localStorage | Data Protection | Critical | ○ | 1.0 | Row 18 explicitly identifies "JWT tokens stored in localStorage vulnerable to XSS attacks" with full impact analysis and httpOnly cookie recommendation |
| P02: Missing Authorization on DELETE Property Endpoint | Authentication/Authorization | Critical | △ | 0.5 | Row 28 "Missing authorization for resource ownership validation" mentions horizontal privilege escalation and owners modifying other owners' properties, but doesn't specifically call out DELETE endpoint |
| P03: Lack of Input Validation Strategy for Property Address | Input Validation | Medium | ○ | 1.0 | Row 20 "Missing input validation policy enables injection attacks" covers all input fields including property data |
| P04: Insufficient Backup Encryption Specification | Data Protection | Medium | ○ | 1.0 | Row 40 "Database backup encryption not specified" - explicit identification |
| P05: Missing API Idempotency Design for Payment Processing | Threat Modeling | Medium | ○ | 1.0 | Row 22 "Payment processing lacks idempotency guarantees" with duplicate payment scenario - full detection |
| P06: Weak Rate Limiting Granularity | Threat Modeling | Medium | × | 0.0 | Row 24 mentions stricter rate limiting for auth endpoints but does not identify IP-only limitation weakness |
| P07: Insufficient Session Revocation Mechanism | Authentication/Authorization | Medium | ○ | 1.0 | Row 21 "No session revocation mechanism" - explicitly identifies that logout doesn't invalidate JWT |
| P08: Lack of Audit Logging for Sensitive Operations | Threat Modeling | Low | ○ | 1.0 | Row 25 "Missing audit logging for sensitive operations" with specific examples and compliance mention |
| P09: Third-Party API Credential Storage Not Specified | Infrastructure/Dependencies | Low | ○ | 1.0 | Row 27 "Third-party API keys and secrets management not specified" - identifies Stripe/Checkr/DocuSign keys with storage recommendations |
| P10: Missing CORS Policy Definition | Input Validation | Low | × | 0.0 | No mention of CORS policy in Run 2 results |

**Detection Score: 8.5 / 10**

## Bonus Analysis

### Run 1 Bonuses

| ID | Issue | Category | Bonus | Rationale |
|----|-------|----------|-------|-----------|
| B01 | Background check data retention policy | Data Protection | ✓ +0.5 | Row 25 "Insufficient data retention and deletion policies" mentions "application rejection" and "user account closure" with GDPR/CCPA compliance |
| B02 | Multi-factor authentication (MFA) | Authentication/Authorization | ✗ 0 | Not mentioned |
| B03 | File upload validation for property images | Input Validation | ✓ +0.5 | Row 27 "File upload security not addressed" with comprehensive validation recommendations (MIME types, size, virus scanning, EXIF stripping) |
| B04 | Email verification for user registration | Threat Modeling | ✗ 0 | Not mentioned |
| B05 | Database column-level encryption for SSNs | Data Protection | ✓ +0.5 | Row 18 "No encryption at rest specification" mentions "Use envelope encryption for highly sensitive fields (SSN, payment details)" |
| B06 | Dependency vulnerability scanning | Infrastructure/Dependencies | ✗ 0 | Not mentioned (OWASP ZAP mentioned but not dependency scanning) |
| B07 | Password reset mechanism | Authentication/Authorization | ✓ +0.5 | Row 37 "No specification for password complexity requirements" mentions "secure reset flow with time-limited tokens (1 hour expiry)" |
| B08 | Bot protection for applications | Threat Modeling | ✗ 0 | Not mentioned |

**Bonus Count: 4 bonuses = +2.0**

### Run 1 Penalties

| Issue | Rationale | Penalty |
|-------|-----------|---------|
| None detected | All findings are within security-design scope | 0 |

**Penalty Count: 0 penalties = -0.0**

### Run 2 Bonuses

| ID | Issue | Category | Bonus | Rationale |
|----|-------|----------|-------|-----------|
| B01 | Background check data retention policy | Data Protection | ✓ +0.5 | Row 26 "No data retention and deletion policies defined" with GDPR/CCPA requirements and data export API |
| B02 | Multi-factor authentication (MFA) | Authentication/Authorization | ✗ 0 | Not mentioned |
| B03 | File upload validation for property images | Input Validation | ✓ +0.5 | Row 32 "File upload security not specified" with antivirus scanning, MIME validation, size limits |
| B04 | Email verification for user registration | Threat Modeling | ✗ 0 | Not mentioned |
| B05 | Database column-level encryption for SSNs | Data Protection | ✓ +0.5 | Row 19 "implement application-layer field-level encryption for SSNs and sensitive PII using AWS KMS" |
| B06 | Dependency vulnerability scanning | Infrastructure/Dependencies | ✗ 0 | Not mentioned |
| B07 | Password reset mechanism | Authentication/Authorization | ✓ +0.5 | Row 38 "enforce password change on first login" implies password reset flow consideration |
| B08 | Bot protection for applications | Threat Modeling | ✗ 0 | Not mentioned |

**Bonus Count: 4 bonuses = +2.0**

### Run 2 Penalties

| Issue | Rationale | Penalty |
|-------|-----------|---------|
| None detected | All findings are within security-design scope | 0 |

**Penalty Count: 0 penalties = -0.0**

## Score Summary

### Run 1
- Detection Score: 8.5
- Bonuses: +2.0 (4 items)
- Penalties: -0.0 (0 items)
- **Total: 10.5**

### Run 2
- Detection Score: 8.5
- Bonuses: +2.0 (4 items)
- Penalties: -0.0 (0 items)
- **Total: 10.5**

### Overall
- **Mean: 10.5**
- **SD: 0.0**
- **Stability: High (SD = 0.0)**

## Key Observations

### Detection Patterns
1. **Consistent strengths**: Both runs detected 8/10 embedded problems with identical scores (8.5)
2. **P01 (JWT localStorage)**: Run 1 partial (△), Run 2 full (○) - but both scored 8.5 due to different misses
3. **P02 (DELETE authorization)**: Run 1 missed (×), Run 2 partial (△) - both struggled with this endpoint-specific issue
4. **P06 (Rate limiting granularity)**: Both runs missed the IP-only limitation weakness
5. **P10 (CORS)**: Run 1 detected (○), Run 2 missed (×) - complementary detection

### Bonus Patterns
1. **Identical bonus performance**: Both runs detected 4/8 bonus items
2. **Strong alignment**: Background check retention (B01), file upload validation (B03), SSN encryption (B05), password reset (B07)
3. **Consistent misses**: MFA (B02), email verification (B04), dependency scanning (B06), bot protection (B08)

### Stability Analysis
- **Perfect stability (SD = 0.0)**: Identical total scores despite different detection patterns on individual problems
- **Complementary detection**: Run 1 and Run 2 compensated for each other's weaknesses (P01 vs P10)
- **No penalties**: Both runs stayed within security-design scope
