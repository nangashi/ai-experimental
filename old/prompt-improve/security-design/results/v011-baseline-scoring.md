# Scoring Report: v011-baseline

## Detection Matrix

| Problem ID | Description | Run 1 | Run 2 | Score Notes |
|------------|-------------|-------|-------|-------------|
| P01 | JWT localStorage vulnerability | ○ | ○ | Both runs explicitly identify XSS risk and recommend httpOnly cookies (Run1: §2.2, Run2: §S1) |
| P02 | Password reset token expiration | △ | △ | Both mention time-limited tokens but don't emphasize missing expiration spec (Run1: §2.3, Run2: §2.3) |
| P03 | Booking cancellation authorization | ○ | ○ | Both identify resource ownership check gap with code examples (Run1: §S4, Run2: §S4) |
| P04 | DB connection string storage | ○ | ○ | Both identify secrets management gap, recommend AWS Secrets Manager (Run1: §5.1, Run2: infra table) |
| P05 | Input validation policy | ○ | ○ | Both provide comprehensive validation policy covering SQL injection/XSS (Run1: §C1, Run2: §C1) |
| P06 | PII in logs | × | × | Neither identifies missing PII masking policy in logging section (only generic "log sanitization" for Datadog) |
| P07 | Elasticsearch access control | ○ | ○ | Both identify missing auth/encryption in infrastructure table (Run1 & Run2: infra table) |
| P08 | Payment API rate limiting | ○ | ○ | Both provide detailed rate limiting policy with payment endpoint specifics (Run1: §S3, Run2: §S3) |
| P09 | Supplier API timeout | × | × | Neither identifies missing timeout design for supplier API parallel calls (only generic circuit breaker mention) |

**Detection Scores**:
- Run 1: 6.5 (6 full + 1 partial)
- Run 2: 6.5 (6 full + 1 partial)

---

## Bonus/Penalty Analysis

### Run 1 Bonuses

| ID | Category | Description | Judgment | Rationale |
|----|----------|-------------|----------|-----------|
| B01 | Audit logging | Security event logging gap identified | ○ | §S5 comprehensively covers audit logging requirements with event types, format, retention |
| B02 | Database encryption | PostgreSQL/Redis encryption at rest | ○ | §3.1 + infrastructure table specify encryption at rest requirements |
| B03 | CSRF | Missing CSRF protection | ○ | §M1 explicitly addresses CSRF protection with double-submit cookie pattern |
| B04 | OAuth security | SNS login OAuth implementation | ○ | §2.4 discusses OAuth flow security, state parameter validation, PKCE |
| B05 | PCI DSS | Payment data tokenization | ○ | §3.2 extensively covers PCI DSS compliance and Stripe tokenization strategy |
| B06 | RBAC | Business account role separation | ○ | §S4 defines BUSINESS_ADMIN role with company-level data isolation in permission matrix |
| B07 | Content filtering | Review comment filtering | △ | §C1 mentions "profanity filter" for review comments but doesn't elaborate on implementation |

**Bonus Count**: 6 full + 0.5 partial = 6.5 → **Capped at 5** → **+2.5 points**

### Run 1 Penalties

| Issue | Category | Description | Judgment | Rationale |
|-------|----------|-------------|----------|-----------|
| MFA recommendation | Out of scope | §2.1 recommends MFA for high-value accounts | -0.5 | While security-related, MFA is an operational/availability concern rather than a design document gap. The perspective focuses on design-level specifications. |

**Penalty Score**: **-0.5 points**

### Run 2 Bonuses

| ID | Category | Description | Judgment | Rationale |
|----|----------|-------------|----------|-----------|
| B01 | Audit logging | Security event logging gap | ○ | §S5 comprehensively addresses security audit logging with event list, format, retention |
| B02 | Database encryption | Encryption at rest | ○ | Infrastructure table + §S2 mention encryption at rest for PostgreSQL |
| B03 | CSRF | CSRF protection | ○ | §M1 addresses CSRF protection design |
| B04 | OAuth security | OAuth implementation security | ○ | §2.4 discusses OAuth flow security and state parameter |
| B05 | PCI DSS | Payment tokenization | ○ | Infrastructure table Stripe row mentions PCI DSS compliance and tokenization approach |
| B06 | RBAC | Business account role separation | ○ | §S4 permission matrix shows BUSINESS_ADMIN with company-level access control |
| B07 | Content filtering | Review filtering | × | Not mentioned |

**Bonus Count**: 6 full → **Capped at 5** → **+2.5 points**

### Run 2 Penalties

No penalties identified. All recommendations are within security design scope.

**Penalty Score**: **-0.0 points**

---

## Score Calculation

### Run 1
- Detection: 6.5
- Bonus: +2.5 (6 items, capped at 5)
- Penalty: -0.5
- **Total: 8.5**

### Run 2
- Detection: 6.5
- Bonus: +2.5 (6 items, capped at 5)
- Penalty: -0.0
- **Total: 9.0**

### Statistics
- **Mean**: (8.5 + 9.0) / 2 = **8.75**
- **Standard Deviation**: sqrt(((8.5-8.75)² + (9.0-8.75)²) / 2) = **0.35**
- **Stability**: High (SD ≤ 0.5)

---

## Key Observations

### Strengths
1. **Consistent core detection**: Both runs identified 6 out of 9 problems with high precision
2. **Comprehensive bonus coverage**: Both detected 6+ bonus issues (audit logging, encryption, CSRF, OAuth, PCI DSS, RBAC)
3. **Structured approach**: Both runs organized findings into severity categories (Critical/Significant/Moderate)
4. **Actionable recommendations**: Both provided implementation-ready specifications (code examples, configuration details)

### Weaknesses
1. **P06 (PII in logs) missed**: Neither run identified the specific missing PII masking policy in the logging section, only mentioning generic "log sanitization" for Datadog
2. **P09 (Supplier API timeout) missed**: Neither run identified the missing timeout/circuit breaker design for supplier API parallel calls in the architecture section
3. **P02 partial detection**: Both runs mentioned password reset security but didn't emphasize the missing expiration specification

### Quality Differences
- **Run 1 penalty**: MFA recommendation slightly outside core design specification scope (-0.5)
- **Run 2 cleaner**: All recommendations within scope, no penalties

---

## Recommendation for Variant Comparison

This baseline score (Mean=8.75, SD=0.35) establishes a high-performing benchmark. Variants should aim to:
1. **Improve P06/P09 detection**: Address the two missed problems
2. **Upgrade P02 to full detection**: More explicitly identify missing expiration specification
3. **Maintain bonus coverage**: Keep the strong performance on audit logging, encryption, CSRF, OAuth, PCI DSS, RBAC
4. **Avoid scope penalties**: Stay within design-level security evaluation

**Target improvement**: Mean ≥ 9.25 (detecting P06 or P09 would add +1.0, upgrading P02 would add +0.5)
