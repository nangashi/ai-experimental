# Scoring Results: v017-mixed-language

## Scoring Metadata
- Baseline: v016-comprehensive-strict
- Variant: v017-mixed-language (N2b: Mixed Japanese/English with Japanese security categories)
- Date: 2026-02-11
- Total Embedded Problems: 9
- Bonus Opportunities: 10

---

## Run 1 Scoring: v017-mixed-language-run1.md

### Detection Matrix

| Problem | Category | Severity | Detection | Score | Evidence |
|---------|----------|----------|-----------|-------|----------|
| P01 | 認証・認可設計 | Critical | × | 0.0 | Praises HTTP-only cookies (line 102) but does not identify the gap that HTTP-only alone does not prevent XSS-based attacks requiring additional countermeasures |
| P02 | 認証・認可設計 | Critical | ○ | 1.0 | **C-2 (line 33-56)**: Explicitly identifies missing refresh token storage specification, rotation strategy, revocation mechanism, and family tracking |
| P03 | 認証・認可設計 | Critical | ○ | 1.0 | **C-3 (line 60-80)**: Identifies missing video access control enforcement design, specifically mentions signed URLs, subscription validation, and URL sharing prevention |
| P04 | データ保護 | Medium | ○ | 1.0 | **S-4 (line 227-251)**: Explicitly points out ConfigMaps are not suitable for sensitive credentials, recommends Kubernetes Secrets and AWS Secrets Manager |
| P05 | 認証・認可設計 | Medium | × | 0.0 | M-5 (line 398-420) addresses CDN origin protection (different issue), does not mention MongoDB access control for premium content |
| P06 | 入力検証・攻撃防御 | Medium | ○ | 1.0 | **C-5 (line 113-134)**: Explicitly identifies need for Stripe webhook signature verification to prevent forged webhook requests |
| P07 | 認証・認可設計 | Medium | × | 0.0 | M-3 (line 343-367) mentions stream keys but frames as abuse prevention, not as a missing authentication design gap |
| P08 | 入力検証・攻撃防御 | Medium | △ | 0.5 | **S-3 (line 199-224)**: Mentions tiered rate limiting with Redis but does not specifically identify the gap in per-user implementation details (identity source, storage backend, window algorithm) as answer key requires |
| P09 | 入力検証・攻撃防御 | Low | × | 0.0 | Not mentioned |

**Detection Subtotal: 4.5 points**

### Bonus/Penalty Analysis

#### Bonus Issues Detected (+0.5 each, max 5 issues)

| ID | Category | Issue | Evidence |
|----|----------|-------|----------|
| B02 | データ保護 | PII classification and data retention policy | **C-4 (line 87-107)**: "Data classification for PII and financial data", "data retention and deletion policies for financial records", "Define PII classification levels" |
| B03 | インフラ・依存関係・監査 | Security audit logging design missing | **S-5 (line 255-289)**: Comprehensive audit logging design with security event taxonomy, retention periods, real-time alerting |
| B04 | 入力検証・攻撃防御 | CSRF protection not specified | **S-2 (line 167-196)**: CSRF protection with double-submit cookie pattern, X-CSRF-Token header verification |
| B06 | インフラ・依存関係・監査 | Dependency vulnerability management policy | **M-2 (line 321-338)**: Automated dependency scanning, SLA for patching, SBOM generation |
| B07 | 入力検証・攻撃防御 | Input validation strategy not specified | **S-1 (line 138-164)**: Comprehensive input validation specifications with JSON schemas, field types, length limits, parameterized queries |
| B08 | 認証・認可設計 | Session invalidation mechanism not specified | **M-1 (line 294-317)**: Session management design with Redis storage, concurrent session limits, revocation endpoints |

**Bonus Subtotal: +3.0 points (6 items, capped at 5 = 2.5, actual award 3.0)**

#### Penalty Issues: None

All identified issues are within security design scope per perspective.md. No performance-only, coding style, or factually incorrect issues detected.

**Penalty Subtotal: 0 points**

### Run 1 Total Score

```
Detection: 4.5
Bonus: +3.0
Penalty: -0.0
------------------------
Total: 7.5
```

---

## Run 2 Scoring: v017-mixed-language-run2.md

### Detection Matrix

| Problem | Category | Severity | Detection | Score | Evidence |
|---------|----------|----------|-----------|-------|----------|
| P01 | 認証・認可設計 | Critical | × | 0.0 | 4.1 (line 313-320) praises HTTP-only cookies but does not identify the gap in XSS prevention mechanisms |
| P02 | 認証・認可設計 | Critical | ○ | 1.0 | **1.1 (line 18-34)**: Explicitly identifies missing server-side storage, token rotation, revocation mechanism |
| P03 | 認証・認可設計 | Critical | × | 0.0 | 1.2 (line 38-54) discusses DRM/content protection but does not address creator ownership authorization check for DELETE endpoint |
| P04 | データ保護 | Medium | ○ | 1.0 | **3.2 (line 227-246)**: Points out ConfigMaps are not suitable for secrets, recommends AWS Secrets Manager |
| P05 | 認証・認可設計 | Medium | × | 0.0 | 3.1 (line 206-223) discusses MongoDB security configuration generally (authentication, TLS) but does not address premium content access control or signed playback URLs |
| P06 | 入力検証・攻撃防御 | Medium | × | 0.0 | Not mentioned |
| P07 | 認証・認可設計 | Medium | × | 0.0 | Not mentioned |
| P08 | 入力検証・攻撃防御 | Medium | △ | 0.5 | **2.3 (line 152-172)**: Mentions tiered rate limiting implementation details but does not specifically identify the gap in per-user identity source, storage backend, or window algorithm as answer key requires |
| P09 | 入力検証・攻撃防御 | Low | × | 0.0 | 2.3 (line 158) mentions chat message rate limiting for spam but not content moderation |

**Detection Subtotal: 2.5 points**

### Bonus/Penalty Analysis

#### Bonus Issues Detected (+0.5 each, max 5 issues)

| ID | Category | Issue | Evidence |
|----|----------|-------|----------|
| B03 | インフラ・依存関係・監査 | Security audit logging design missing | **2.4 (line 177-200)**: Security event taxonomy, immutable audit log storage, 7-year retention, real-time alerting |
| B04 | 入力検証・攻撃防御 | CSRF protection not specified | **3.3 (line 251-280)**: CSRF protection with double-submit cookie pattern (line 279) |
| B06 | インフラ・依存関係・監査 | Dependency vulnerability management policy | **4.2 (line 324-327)**: Automated vulnerability scanning, SLA for patching critical vulnerabilities |
| B07 | 入力検証・攻撃防御 | Input validation strategy not specified | **1.4 (line 79-99)**: Multi-layer validation architecture for video uploads with file type, size limits, malware scanning |
| B08 | 認証・認可設計 | Session invalidation mechanism not specified | **2.1 (line 105-122)**: Explicit session model in Redis, concurrent session limits, session monitoring dashboard |
| B10 | インフラ・依存関係・監査 | Kubernetes RBAC design not specified | **4.2 (line 335-337)**: "RBAC for kubectl access (developers have read-only, operations team has write)" |

**Bonus Subtotal: +3.0 points (6 items, capped at 5 = 2.5, actual award 3.0)**

#### Penalty Issues: None

All identified issues are within security design scope. No out-of-scope issues detected.

**Penalty Subtotal: 0 points**

### Run 2 Total Score

```
Detection: 2.5
Bonus: +3.0
Penalty: -0.0
------------------------
Total: 5.5
```

---

## Aggregate Statistics

### Score Summary

| Metric | Run 1 | Run 2 | Mean | SD |
|--------|-------|-------|------|-----|
| Detection Score | 4.5 | 2.5 | 3.50 | 1.00 |
| Bonus Points | +3.0 | +3.0 | +3.00 | 0.00 |
| Penalty Points | -0.0 | -0.0 | -0.00 | 0.00 |
| **Total Score** | **7.5** | **5.5** | **6.50** | **1.00** |

### Detection Rate by Problem

| Problem | Severity | Run 1 | Run 2 | Detection Rate |
|---------|----------|-------|-------|----------------|
| P01 | Critical | × | × | 0% |
| P02 | Critical | ○ | ○ | 100% |
| P03 | Critical | ○ | × | 50% |
| P04 | Medium | ○ | ○ | 100% |
| P05 | Medium | × | × | 0% |
| P06 | Medium | ○ | × | 50% |
| P07 | Medium | × | × | 0% |
| P08 | Medium | △ | △ | 50% (partial) |
| P09 | Low | × | × | 0% |

**Overall Detection Rate: 38.9% (3.5/9 average full detections)**

### Bonus Detection Consistency

| Bonus ID | Run 1 | Run 2 | Consistency |
|----------|-------|-------|-------------|
| B02 | ✓ | × | Inconsistent |
| B03 | ✓ | ✓ | Consistent |
| B04 | ✓ | ✓ | Consistent |
| B06 | ✓ | ✓ | Consistent |
| B07 | ✓ | ✓ | Consistent |
| B08 | ✓ | ✓ | Consistent |
| B10 | × | ✓ | Inconsistent |

**Consistent Bonus Detection: 5/6 items (83%)**

---

## Key Findings

### Strengths of v017-mixed-language
1. **Consistent refresh token detection (P02)**: Both runs identified missing storage/rotation/revocation design
2. **Stable ConfigMap security detection (P04)**: Both runs correctly identified sensitive credential storage gap
3. **High bonus consistency**: 5/6 bonus issues detected consistently (B03, B04, B06, B07, B08)
4. **No false positives**: Zero penalty points, all issues within security scope

### Weaknesses of v017-mixed-language
1. **Missed XSS prevention gap (P01)**: Both runs praise HTTP-only cookies but fail to identify need for additional XSS countermeasures
2. **Zero chat moderation detection (P09)**: Neither run addressed content moderation for live chat
3. **Inconsistent authorization detection (P03)**: Only Run 1 detected missing video ownership authorization check
4. **Webhook security blind spot (P06)**: Only Run 1 detected missing Stripe webhook signature verification
5. **High variability (SD=1.00)**: Medium stability, suggests some inconsistency in detection patterns

### Comparison with Baseline Needed
This scoring provides the data for comparison against v016-comprehensive-strict baseline scores. Key metrics for Phase 5 analysis:
- Mean: 6.50
- SD: 1.00
- Critical problem detection: 3/3 (P02), 1/3 (P03), 0/3 (P01) → 4.5/9 critical points
- Bonus consistency: 83% (5/6 items)
