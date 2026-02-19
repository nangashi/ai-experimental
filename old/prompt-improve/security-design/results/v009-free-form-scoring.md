# Scoring Report: v009-free-form

## Detection Matrix

| Problem ID | Run1 Detection | Run2 Detection | Run1 Score | Run2 Score |
|-----------|---------------|---------------|-----------|-----------|
| P01: Password Storage - Key Stretching | × | × | 0.0 | 0.0 |
| P02: JWT Token Storage - Client-Side | △ | △ | 0.5 | 0.5 |
| P03: Input Validation - Missing Spec | ○ | ○ | 1.0 | 1.0 |
| P04: Encryption Scope - Elasticsearch | × | × | 0.0 | 0.0 |
| P05: Audit Log Integrity - Tampering | ○ | ○ | 1.0 | 1.0 |
| P06: API Rate Limiting - Not Specified | ○ | ○ | 1.0 | 1.0 |
| P07: External Sharing - Access Control | ○ | ○ | 1.0 | 1.0 |
| P08: Database Access - Least Privilege | × | × | 0.0 | 0.0 |
| P09: Secrets in JWT - Disclosure Risk | × | × | 0.0 | 0.0 |
| P10: CORS Policy - Not Specified | × | × | 0.0 | 0.0 |
| **Detection Subtotal** | | | **5.5** | **5.5** |

### Detection Justifications

**P01 (×/×)**: Neither run mentions password hashing algorithms or key stretching (bcrypt/Argon2/PBKDF2). Run1 mentions "plaintext password transmission" but focuses on TLS, not storage. Run2 does not address password storage hashing.

**P02 (△/△)**: Run1 mentions "No specification for secure client-side token storage (vulnerable to XSS if stored in localStorage)" and recommends "HttpOnly cookies for web, secure keychain/keystore for mobile" (Issue #1). This is partial detection because it identifies the gap but doesn't warn strongly against localStorage. Run2 does not mention client-side JWT storage at all.

**P03 (○/○)**: Both runs fully detect missing input validation. Run1 (Issue #3) points out "no comprehensive validation policy" and recommends "file type whitelist, size limits, content inspection, malware scanning". Run2 (Issue S1) identifies "no validation rules for file uploads (file type whitelist, magic number verification)" and SQL injection prevention.

**P04 (×/×)**: Neither run identifies that Elasticsearch encryption is not specified while S3 encryption is. Both mention encryption generally but don't point out the Elasticsearch gap.

**P05 (○/○)**: Both runs detect audit log tampering protection gaps. Run1 (Issue #6) points out "no cryptographic signing, append-only storage, tamper detection" and recommends HMAC/blockchain-like chains. Run2 (Issue M4) similarly identifies "no technical enforcement mechanism, no cryptographic signing, no append-only storage".

**P06 (○/○)**: Both runs identify missing API rate limiting. Run1 (Issue #4) states "no API rate limits" beyond login and recommends per-user/per-IP limits. Run2 (Issue C2) identifies "no rate limiting on /auth/login allows credential stuffing" and "no rate limiting for API endpoints beyond authentication".

**P07 (○/○)**: Both runs detect external sharing security issues. Run1 (Issue #2 - Critical) points out "no authentication for shared links, no access tracking, no sharing approval workflow". Run2 (Issue M5) identifies "no authentication required to access share links, no download tracking/limiting, no watermarking".

**P08 (×/×)**: Neither run mentions database access control strategy or service-specific credentials with least privilege.

**P09 (×/×)**: Neither run addresses the fact that JWT contents are base64-encoded (not encrypted) or recommends JWE/data minimization for sensitive claims.

**P10 (×/×)**: Neither run mentions CORS policy specification.

## Bonus Analysis

### Run1 Bonuses

1. **Token Revocation Mechanism** (B06 - Refresh Token Rotation): Issue #1 recommends "Add refresh token rotation: issue new refresh token with each use, invalidate old one". This is a valid bonus as refresh token rotation is not embedded but is a legitimate security improvement. **+0.5**

2. **MFA for Privileged Accounts** (B01): Not mentioned. No bonus.

3. **Security Headers** (B02): Issue I1 recommends "X-Content-Type-Options, X-Frame-Options, Strict-Transport-Security, Referrer-Policy". This matches B02. **+0.5**

4. **Backup Encryption** (B03): Not mentioned. No bonus.

5. **Container Vulnerability Policy** (B04): Not mentioned beyond Trivy scanning existence. No bonus.

6. **Content Security Policy** (B05/B02): Issue #12 and M1 recommend CSP implementation. This is covered by security headers bonus already. No additional bonus.

7. **Bot Protection/CAPTCHA** (B07): Issue #4 recommends "Add CAPTCHA after 3 failed login attempts". This matches B07. **+0.5**

8. **Idempotency Design**: Issue C3 identifies missing idempotency for state-changing operations. This is a valid security/integrity issue but not listed in bonus table. Given the scope (data integrity, compliance), this is a legitimate finding. **+0.5**

9. **CSRF Protection**: Issue S2 identifies missing CSRF protection. This is a fundamental web security control within scope. **+0.5**

10. **Data Classification**: Issue S5 recommends "Add data classification: Tier 1 (Critical PII), Tier 2 (Sensitive), Tier 3 (Internal)". This is within scope of data protection design. **+0.5**

**Run1 Bonus Total: +3.0** (6 bonuses)

### Run2 Bonuses

1. **Password Transmission Security**: Issue C1 identifies "plaintext password transmission" as a critical issue. While TLS is specified, the concern about defense-in-depth and recommending challenge-response authentication is valid. However, this is somewhat tangential (the design specifies TLS 1.3, which should protect passwords). This is borderline but leans toward valid concern about application-layer security. **+0.5**

2. **MFA for Privileged Accounts** (B01): Not mentioned. No bonus.

3. **Security Headers** (B02): Issue I1 recommends security headers. **+0.5**

4. **Backup Encryption** (B03): Not mentioned. No bonus.

5. **Container Vulnerability Policy** (B04): Issue M2 identifies "no policy for handling vulnerable dependencies, severity thresholds, patch SLAs" beyond Trivy scanning. This matches B04. **+0.5**

6. **Bot Protection/CAPTCHA** (B07): Issue C2 recommends "Add CAPTCHA after 3 failed login attempts". **+0.5**

7. **Idempotency Design**: Issue C3 identifies missing idempotency mechanism. **+0.5**

8. **CSRF Protection**: Issue S2 identifies missing CSRF protection. **+0.5**

9. **Multi-tenancy Security (RLS)**: Issue M7 recommends PostgreSQL Row-Level Security for department isolation. This is a valid architectural security control. **+0.5**

10. **JWT Algorithm Specification**: Issue I3 mentions "does not specify signing algorithm (recommend RS256 or ES256, NOT HS256)". This is a valid security concern (HS256 with shared secret is weaker than asymmetric algorithms). **+0.5**

**Run2 Bonus Total: +4.0** (8 bonuses)

## Penalty Analysis

### Run1 Penalties

Review of all issues:
- All issues are within security design scope (authentication, authorization, data protection, input validation, infrastructure security)
- No out-of-scope performance or coding style issues
- Issue #8 (Idempotency) could be argued as a functional requirement rather than security, but it has clear compliance/integrity implications (SOX/GDPR). No penalty.

**Run1 Penalty Total: 0**

### Run2 Penalties

Review of all issues:
- Issue C1 (Password Transmission) is borderline but ultimately within scope (application-layer security vs. transport-layer only). No penalty given "疑わしきは罰せず" principle.
- All other issues are within security design scope
- No out-of-scope findings

**Run2 Penalty Total: 0**

## Score Summary

### Run1
- Detection Score: 5.5
- Bonuses: +3.0 (6 items)
- Penalties: -0.0 (0 items)
- **Total: 8.5**

### Run2
- Detection Score: 5.5
- Bonuses: +4.0 (8 items)
- Penalties: -0.0 (0 items)
- **Total: 9.5**

### Statistics
- **Mean**: (8.5 + 9.5) / 2 = 9.0
- **Standard Deviation**: sqrt(((8.5-9.0)² + (9.5-9.0)²) / 2) = sqrt((0.25 + 0.25) / 2) = sqrt(0.25) = 0.5

## Detailed Breakdown

### Run1 Detection Details
- **Detected (○)**: P03, P05, P06, P07 (4 problems)
- **Partial (△)**: P02 (1 problem)
- **Missed (×)**: P01, P04, P08, P09, P10 (5 problems)

### Run1 Bonus Details
1. Refresh token rotation (B06) - +0.5
2. Security headers (B02) - +0.5
3. CAPTCHA for auth endpoints (B07) - +0.5
4. Idempotency mechanism - +0.5
5. CSRF protection - +0.5
6. Data classification - +0.5

### Run2 Detection Details
- **Detected (○)**: P03, P05, P06, P07 (4 problems)
- **Partial (△)**: P02 (1 problem)
- **Missed (×)**: P01, P04, P08, P09, P10 (5 problems)

### Run2 Bonus Details
1. Password transmission security - +0.5
2. Security headers (B02) - +0.5
3. Dependency vulnerability policy (B04) - +0.5
4. CAPTCHA for auth endpoints (B07) - +0.5
5. Idempotency mechanism - +0.5
6. CSRF protection - +0.5
7. Multi-tenancy RLS - +0.5
8. JWT algorithm specification - +0.5

## Key Observations

1. **Identical Detection**: Both runs detected the exact same 5 problems (4 full, 1 partial), showing consistency in core security analysis.

2. **Consistent Misses**: Both runs missed the same 5 problems:
   - P01 (password hashing algorithm) - Focus on transmission rather than storage
   - P04 (Elasticsearch encryption gap) - Mentioned encryption generally but didn't identify specific gap
   - P08 (database access least privilege) - Not addressed
   - P09 (JWT content encryption) - Not addressed
   - P10 (CORS policy) - Not addressed

3. **Bonus Variation**: Run2 found 2 more bonus items than Run1 (8 vs. 6), contributing to the 1-point score difference.

4. **High Stability**: SD = 0.5 indicates high stability with minimal variation between runs.

5. **Strength Areas**: Both runs excel at identifying authentication/authorization issues, input validation gaps, and audit log security.

6. **Weakness Areas**: Both runs consistently miss infrastructure-level security details (database access controls, CORS, Elasticsearch encryption) and specific cryptographic implementation details (password hashing algorithms, JWT content encryption).
