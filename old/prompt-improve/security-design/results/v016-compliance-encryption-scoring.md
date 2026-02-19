# Scoring Report: v016-compliance-encryption

## Detection Matrix

| Problem | Run1 | Run2 | Category |
|---------|------|------|----------|
| P01: JWT Token Storage in localStorage | ○ (1.0) | ○ (1.0) | Authentication & Authorization |
| P02: Insufficient Password Reset Token Expiration | × (0.0) | △ (0.5) | Authentication & Authorization |
| P03: Missing Authorization Checks on Resource Modification | ○ (1.0) | ○ (1.0) | Authentication & Authorization |
| P04: OAuth Token Storage in Plain Text | ○ (1.0) | ○ (1.0) | Data Protection |
| P05: Insecure File Upload ACL Configuration | ○ (1.0) | ○ (1.0) | Data Protection |
| P06: Missing CSRF Protection | ○ (1.0) | ○ (1.0) | Input Validation |
| P07: Webhook Secret Generation and Management | ○ (1.0) | ○ (1.0) | Authentication & Authorization |
| P08: Insufficient Input Validation for File Uploads | ○ (1.0) | ○ (1.0) | Input Validation |
| P09: Missing Rate Limiting on Authentication Endpoints | ○ (1.0) | ○ (1.0) | Threat Modeling |
| P10: Single-node Redis Deployment Risk | ○ (1.0) | ○ (1.0) | Infrastructure Security |

### Detection Summary
- **Run 1**: 9 detected (○), 0 partial (△), 1 missed (×)
- **Run 2**: 9 detected (○), 1 partial (△), 0 missed (×)

## Bonus Items

### Run 1 Bonus (+2.5)
1. **Compliance-specific encryption assessment** (+0.5): Detailed SOC 2 and GDPR encryption requirements table (lines 16-44)
2. **Infrastructure security assessment** (+0.5): Comprehensive security table for all infrastructure components (lines 46-86)
3. **Audit logging for compliance** (+0.5): Identifies missing audit trail for sensitive operations beyond operational logging (lines 117-118, 413-424) - related to B01
4. **PII masking policy** (+0.5): Identifies risks of logging sensitive data and recommends masking policy (lines 220, 247-250, 496-561) - related to B02
5. **Multi-factor authentication** (+0.5): Recommends MFA for admin/manager roles (lines 175-176, 704-706) - B09

### Run 2 Bonus (+2.5)
1. **Compliance-specific encryption assessment** (+0.5): Detailed GDPR and SOC 2 encryption requirements (lines 64-111)
2. **Infrastructure security assessment** (+0.5): Comprehensive infrastructure security table (lines 266-341)
3. **Audit logging for compliance** (+0.5): Identifies missing audit logging for SOC 2 (lines 413-424, 496-561) - B01
4. **PII masking policy** (+0.5): Recommends PII masking in logs (lines 536-537) - related to B02
5. **Multi-factor authentication** (+0.5): Suggests MFA for admin accounts (lines 704-706) - B09

## Penalty Items

### Run 1 Penalty (0)
- No scope violations identified. All findings are within security design review scope.

### Run 2 Penalty (0)
- No scope violations identified. All findings are within security design review scope.

## Score Calculation

### Run 1
- **Base Score**: 9.0 (P01=1.0, P02=0.0, P03=1.0, P04=1.0, P05=1.0, P06=1.0, P07=1.0, P08=1.0, P09=1.0, P10=1.0)
- **Bonus**: +2.5 (5 items × 0.5)
- **Penalty**: -0
- **Total**: 9.0 + 2.5 - 0 = **11.5**

### Run 2
- **Base Score**: 9.5 (P01=1.0, P02=0.5, P03=1.0, P04=1.0, P05=1.0, P06=1.0, P07=1.0, P08=1.0, P09=1.0, P10=1.0)
- **Bonus**: +2.5 (5 items × 0.5)
- **Penalty**: -0
- **Total**: 9.5 + 2.5 - 0 = **12.0**

### Statistics
- **Mean**: (11.5 + 12.0) / 2 = **11.75**
- **Standard Deviation**: 0.25

## Detection Details

### P01: JWT Token Storage in localStorage (Critical)
- **Run 1**: ○ - Explicitly identifies XSS vulnerability with JWT in localStorage (lines 26-34, 101-102, 159), recommends httpOnly cookies
- **Run 2**: ○ - Clear identification of XSS risk (lines 23-55), recommends httpOnly cookies with security attributes

### P02: Insufficient Password Reset Token Expiration (Medium)
- **Run 1**: × - Rate limiting mentioned but does not identify missing single-use enforcement, account lockout, or specific password reset security gaps
- **Run 2**: △ - Mentions password reset in rate limiting context (lines 136, 186-187) but doesn't explicitly identify single-use enforcement gap or account lockout mechanisms

### P03: Missing Authorization Checks on Resource Modification (Critical)
- **Run 1**: ○ - Explicitly identifies "No ownership verification - any user in the tenant can update/delete any deal" (lines 109-110, 205-252)
- **Run 2**: ○ - Clear identification of missing ownership verification and RBAC (lines 205-252)

### P04: OAuth Token Storage in Plain Text (Critical)
- **Run 1**: ○ - Extensively covers OAuth token encryption requirements (lines 27, 76, 122-123, 211-212, 564-610)
- **Run 2**: ○ - Comprehensive coverage of OAuth token encryption needs (lines 75-76, 564-610)

### P05: Insecure File Upload ACL Configuration (Critical)
- **Run 1**: ○ - Explicitly identifies public-read ACL as information disclosure risk (lines 71, 88-89, 115-150)
- **Run 2**: ○ - Clear identification of public-read ACL security issue (lines 71-72, 115-150)

### P06: Missing CSRF Protection (Medium)
- **Run 1**: ○ - Identifies absence of CSRF protection mechanisms (lines 345-385)
- **Run 2**: ○ - Discusses CSRF risk and protection mechanisms (lines 345-385)

### P07: Webhook Secret Generation and Management (Medium)
- **Run 1**: ○ - Identifies missing secret generation standards, HMAC algorithm, and rotation policy (lines 777-825)
- **Run 2**: ○ - Comprehensive coverage of webhook secret management gaps (lines 777-825)

### P08: Insufficient Input Validation for File Uploads (Medium)
- **Run 1**: ○ - Mentions file type validation, malware scanning, and filename sanitization (lines 260-264, 289-291, 429-432)
- **Run 2**: ○ - Identifies file validation gaps including malware scanning (lines 260-264, 429-432)

### P09: Missing Rate Limiting on Authentication Endpoints (Medium)
- **Run 1**: ○ - Explicitly identifies missing rate limiting despite Redis mention (lines 132-133, 154-202)
- **Run 2**: ○ - Clear identification with implementation recommendations (lines 154-202)

### P10: Single-node Redis Deployment Risk (Medium)
- **Run 1**: ○ - Identifies session loss and rate limiting failure implications (lines 92-93, 612-660)
- **Run 2**: ○ - Clear identification of availability and security implications (lines 612-660)

## Variant Analysis

**Strengths**:
- Excellent detection rate: 9.0-9.5 out of 10 base problems detected
- Strong compliance focus: Comprehensive GDPR and SOC 2 encryption assessments
- Systematic infrastructure security review with detailed tables
- High-quality bonus findings: 5 additional valuable insights per run
- No scope violations or penalties

**Weaknesses**:
- P02 detection gap: Missed or partially detected the specific password reset security mechanisms (single-use enforcement, account lockout)
- Minor inconsistency between runs on P02 (× vs △)

**Recommendation**: This variant demonstrates strong security analysis capabilities with comprehensive compliance coverage. The only gap is P02, which represents a more nuanced authentication security issue. Overall, this is a high-performing variant.
