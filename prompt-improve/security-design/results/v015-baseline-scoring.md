# Scoring Report - Round 015: baseline

## Scoring Summary

- **Mean Score**: 7.5
- **Standard Deviation**: 0.5
- **Run 1 Score**: 7.0 (検出7.0 + bonus 0 - penalty 0)
- **Run 2 Score**: 8.0 (検出7.5 + bonus 1 - penalty 0)

---

## Problem Detection Matrix

| Problem ID | Description | Run 1 | Run 2 | Notes |
|------------|-------------|-------|-------|-------|
| P01 | JWT Token Storage in localStorage | ○ | ○ | Both runs identify localStorage XSS vulnerability and recommend httpOnly cookies |
| P02 | Weak Password Policy | ○ | ○ | Both runs identify 6-character minimum as insufficient |
| P03 | Missing Password Reset Token Expiration | ○ | ○ | Run 1 identifies unprotected tokens; Run 2 specifies no expiration |
| P04 | Missing CSRF Protection | ○ | ○ | Both runs identify missing CSRF for state-changing endpoints |
| P05 | Unencrypted Elasticsearch Storage | × | × | Neither run identifies Elasticsearch encryption at rest gap |
| P06 | Inadequate API Rate Limiting Coverage | ○ | ○ | Both runs identify endpoint-specific rate limiting gaps |
| P07 | Sensitive Data Logging | ○ | ○ | Both runs identify PHI exposure in full request body logs |
| P08 | Missing Authorization Check on Document Access | △ | ○ | Run 1 mentions weak authorization model generally; Run 2 identifies document access authorization gaps specifically |
| P09 | Secrets in Kubernetes ConfigMaps | × | × | Neither run identifies ConfigMap vs. Secrets Manager ambiguity |

---

## Detection Score Details

### Run 1 Detection Score: 7.0
- P01: ○ (1.0) - Critical Issue #1 explicitly identifies localStorage JWT storage and XSS risk
- P02: ○ (1.0) - Critical Issue #2 identifies 6-character password minimum as weak
- P03: ○ (1.0) - Critical Issue #5 identifies unprotected password reset tokens
- P04: ○ (1.0) - Critical Issue #6 identifies missing CSRF protection
- P05: × (0.0) - Elasticsearch encryption not mentioned
- P06: ○ (1.0) - Significant Issue #7 identifies inadequate rate limiting for login/prescription endpoints
- P07: ○ (1.0) - Critical Issue #3 identifies sensitive data logging (PHI in request bodies)
- P08: △ (0.5) - Significant Issue #10 mentions weak authorization model but doesn't specifically address document access "care team" ambiguity
- P09: × (0.0) - ConfigMap security issue not mentioned

**Total Detection: 7.0**

### Run 2 Detection Score: 7.5
- P01: ○ (1.0) - Critical Issue #1 identifies localStorage JWT storage and XSS vulnerability
- P02: ○ (1.0) - Critical Issue #2 identifies 6-character password as insufficient
- P03: ○ (1.0) - Significant Issue #12 identifies password reset tokens with "no expiration specified"
- P04: ○ (1.0) - Critical Issue #3 identifies missing CSRF protection
- P05: × (0.0) - Elasticsearch encryption not mentioned
- P06: ○ (1.0) - Critical Issue #8 identifies missing rate limits for login, password reset, prescriptions
- P07: ○ (1.0) - Critical Issue #6 identifies sensitive data exposure in logs (full request bodies with PHI)
- P08: ○ (1.0) - Significant Issue #16 identifies weak authorization model with specific mention of undefined "care team" access privileges
- P09: × (0.0) - ConfigMap security issue not mentioned

**Total Detection: 7.5**

---

## Bonus Points Analysis

### Run 1 Bonus: 0 points (0 issues)

No bonus issues detected.

### Run 2 Bonus: 1 point (2 issues)

| Bonus ID | Issue Description | Bonus? | Justification |
|----------|-------------------|--------|---------------|
| B02 | Long JWT expiration (24 hours) | ○ | Critical Issue #9 discusses weak JWT signing algorithm (HS256) but does NOT identify the 24-hour expiration as excessive. Moderate Issue #13 mentions "24-hour token expiration is too long" and recommends shorter-lived tokens. **Counts as bonus.** Score: +0.5 |
| B05 | Stack traces in development environment | ○ | Significant Issue #13 explicitly mentions "Stack traces are included in development environment responses" and recommends ensuring production safeguards. Bonus Issue B05 specifically addresses ensuring stack traces are disabled in production. **Counts as bonus.** Score: +0.5 |

**Total Bonus: +1.0**

---

## Penalty Points Analysis

### Run 1 Penalties: 0 points (0 issues)

No out-of-scope or incorrect issues detected.

### Run 2 Penalties: 0 points (0 issues)

No out-of-scope or incorrect issues detected.

---

## Detailed Analysis

### Strengths
- Both runs successfully detect 7 of 9 embedded problems (77.8% detection rate)
- Critical authentication and authorization issues consistently identified across runs
- PHI logging exposure detected in both runs
- Rate limiting gaps identified in both runs
- Run 2 shows improved bonus detection with 2 valid bonus issues

### Weaknesses
- **P05 (Unencrypted Elasticsearch)**: Neither run identifies the Elasticsearch encryption at rest gap. Both runs mention general Elasticsearch security configuration needs (authentication, TLS), but miss the specific HIPAA encryption requirement for indexed medical data.
- **P09 (ConfigMap Secrets)**: Neither run identifies the ConfigMap vs. Secrets Manager ambiguity that could lead to unencrypted secrets storage. Run 1 mentions general secrets management issues, but doesn't address the ConfigMap-specific risk.
- **P08 Detection Variance**: Run 1 only partially detects the document access authorization issue (△), while Run 2 fully detects it (○), causing a 0.5-point difference.

### Consistency
- **Standard Deviation: 0.5** - High stability (SD ≤ 0.5)
- Core critical issues (P01, P02, P04, P06, P07) detected consistently
- Variation primarily from P08 partial detection in Run 1 and bonus detection in Run 2
- Stable performance indicates reliable baseline

### Recommendation
- Baseline demonstrates strong performance with 7.5 mean score and high stability
- Continue with variant testing to determine if improvements can achieve > 8.0 score
- Focus variant improvements on:
  1. Infrastructure-level encryption gaps (P05 - Elasticsearch)
  2. Kubernetes-specific security issues (P09 - ConfigMap secrets)
  3. Fine-grained authorization specification gaps (P08 consistency)
