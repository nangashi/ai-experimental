# Round 012 Comparison Report

## Executive Summary

**Test Conditions**:
- **Round**: 012
- **Test Document**: Enterprise document management system (same as Round 10-11)
- **Variants Tested**: baseline (control), weighted-scoring, adversarial-perspective
- **Baseline Variation ID**: N/A (current stable baseline)
- **Variant 1**: weighted-scoring (Variation ID: V012-weighted, focusing on severity-weighted detection with explicit scoring instructions)
- **Variant 2**: adversarial-perspective (Variation ID: V012-adversarial, attack chain analysis with STRIDE framework)

**Recommendation**: **v012-baseline**

**Justification**: Mean score difference < 0.5pt for both variants (weighted-scoring: 0.0pt, adversarial-perspective: -2.0pt). Per scoring-rubric.md Section 5, when mean score difference < 0.5pt, baseline is recommended to avoid noise-based misattribution.

**Convergence Status**:継続推奨

**Rationale**: This is a new baseline evaluation round. Baseline score 11.0 (SD=1.0) represents strong performance with high bonus detection (6-7 bonuses per run). The -2.0pt difference with adversarial-perspective is below the 1.0pt threshold but provides valuable insights into scope control challenges.

---

## Scores Summary

| Variant | Mean | SD | Detection | Bonus | Penalty | Stability |
|---------|------|----|-----------| ------|---------|-----------|
| **baseline** | **11.0** | **1.0** | 9.0 | +2.5 (R1), +1.5 (R2) | 0.0 | Medium (0.5 < SD ≤ 1.0) |
| weighted-scoring | 8.5 | 0.0 | 6.0 | +2.5 | 0.0 | High (SD ≤ 0.5) |
| adversarial-perspective | 9.0 | 0.0 | 9.5 avg | +1.75 avg | -2.0 avg | High (SD ≤ 0.5) |

**Key Observations**:
- **Baseline** achieved highest mean score (11.0) with strong bonus detection but moderate stability (SD=1.0) due to P03/P09 detection variance
- **weighted-scoring** achieved perfect stability (SD=0.0) but significantly lower detection score (6.0) with consistent pattern of missing P01/P03/P04/P06
- **adversarial-perspective** balanced detection (9.5 avg) with high stability (SD=0.0) but accumulated penalties (-2.0 avg) for speculative analysis

---

## Detection Matrix

### Baseline Detection Patterns

| Problem | Severity | Run1 | Run2 | Notes |
|---------|----------|------|------|-------|
| P01 | Medium | ○ 1.0 | ○ 1.0 | Run1: Issue #9 explicitly identifies 2-hour expiration as excessive. Run2: Issue #14 addresses token security. |
| P02 | Medium | ○ 1.0 | ○ 1.0 | Run1: Issue #3 comprehensively identifies missing CSRF. Run2: Issue #2 explicitly addresses CSRF. |
| P03 | Medium | ○ 1.0 | △ 0.5 | Run1: Issue #19 questions 8-char minimum, recommends 12 chars. Run2: Treats 8-char as positive without critique. |
| P04 | Medium | × 0.0 | × 0.0 | Both runs acknowledge redaction but miss "should" vs "must" enforcement gap. |
| P05 | Critical | ○ 1.0 | ○ 1.0 | Run1: Issue #4 identifies missing secret management. Run2: Issue #5 addresses secrets management. |
| P06 | Critical | △ 0.5 | △ 0.5 | Both runs mention authorization but miss specific PUT/DELETE endpoint gaps. |
| P07 | Medium | ○ 1.0 | ○ 1.0 | Run1: Issue #16 identifies Elasticsearch security gaps. Run2: Infrastructure table identifies authentication gaps. |
| P08 | Critical | ○ 1.0 | ○ 1.0 | Run1: Issue #1 identifies JWT storage with XSS risk analysis. Run2: Issue #1 explicitly identifies storage gap. |
| P09 | Medium | ○ 1.0 | △ 0.5 | Run1: Issue #6 identifies JSONB field validation. Run2: Mentions policy but not JSONB-specific. |
| P10 | Medium | ○ 1.0 | ○ 1.0 | Both runs identify missing rate limiting for authentication endpoints. |

**Baseline Detection Score**: Run1=9.5, Run2=8.5, Mean=9.0

### weighted-scoring Detection Patterns

| Problem | Severity | Run1 | Run2 | Pattern Analysis |
|---------|----------|------|------|------------------|
| P01 | Medium | × 0.0 | × 0.0 | Both runs mention 2-hour expiration as POSITIVE aspect without identifying risk |
| P02 | Medium | ○ 1.0 | ○ 1.0 | Issue #2 "[HIGH WEIGHT]" fully identifies CSRF protection gap with specific mechanisms |
| P03 | Medium | × 0.0 | × 0.0 | Both runs mention "Password complexity requirements" as positive without identifying undefined requirements or inadequate 8-char minimum |
| P04 | Medium | × 0.0 | × 0.0 | Both runs mention redaction as positive aspect without identifying "should" language weakness |
| P05 | Critical | ○ 1.0 | ○ 1.0 | Issue #4 "[HIGH WEIGHT]" identifies database credential storage gap with AWS Secrets Manager recommendation |
| P06 | Critical | × 0.0 | × 0.0 | Both runs mention "Authorization checks for user-owned resources" as positive without identifying PUT/DELETE endpoint gaps |
| P07 | Medium | ○ 1.0 | ○ 1.0 | Infrastructure table identifies "Elasticsearch: Access control, network security - Missing" |
| P08 | Critical | ○ 1.0 | ○ 1.0 | Issue #1 "[CRITICAL]" identifies JWT storage specification gap with httpOnly cookie recommendation |
| P09 | Medium | ○ 1.0 | ○ 1.0 | Issue #6 "[MEDIUM WEIGHT]" identifies JSONB field validation gap with SQL injection mention |
| P10 | Medium | ○ 1.0 | ○ 1.0 | Issue #7 "[SIGNIFICANT]" identifies rate limiting for authentication endpoints with specific limits |

**weighted-scoring Detection Score**: Run1=6.0, Run2=6.0, Mean=6.0

### adversarial-perspective Detection Patterns

| Problem | Severity | Run1 | Run2 | Attack Chain Context |
|---------|----------|------|------|----------------------|
| P01 | Medium | ○ 1.0 | ○ 1.0 | Run1: Section 2.3 identifies 2-hour window as brute-force opportunity. Run2: Section 1.5 identifies 2-hour expiration as problematic |
| P02 | Medium | ○ 1.0 | ○ 1.0 | Run1: Section 2.1 recommends CSRF tokens. Run2: Section 2.3 explicitly identifies missing CSRF protection |
| P03 | Medium | ○ 1.0 | ○ 1.0 | Run1: Section 6.2 questions 8-char minimum. Run2: Section 5.1 labels weak password policy as defense gap |
| P04 | Medium | ○ 1.0 | △ 0.5 | Run1: Section 6.4 scores redaction as 4/5 (Good). Run2: Section 4.4 identifies passive "should" as weak enforcement |
| P05 | Critical | ○ 1.0 | ○ 1.0 | Run1: Section 4.3 recommends AWS Secrets Manager. Run2: Section 7.5 identifies missing secure storage |
| P06 | Critical | ○ 1.0 | ○ 1.0 | Run1: Section 1.3 identifies IDOR via missing authorization. Run2: Section 1.2 identifies authorization bypass for PUT/DELETE |
| P07 | Medium | × 0.0 | ○ 1.0 | Run1: No mention. Run2: Section 4.2 identifies Elasticsearch authentication gap |
| P08 | Critical | ○ 1.0 | ○ 1.0 | Run1: Section 1.1 identifies JWT storage with XSS risk. Run2: Section 1.1 identifies XSS-based account takeover via JWT storage |
| P09 | Medium | ○ 1.0 | ○ 1.0 | Run1: Section 1.2 identifies injection points. Run2: Section 1.3 and 7.4 identify JSONB injection risk |
| P10 | Medium | ○ 1.0 | ○ 1.0 | Run1: Section 1.4 identifies missing auth endpoint rate limiting. Run2: Section 1.4 identifies auth endpoint gap |

**adversarial-perspective Detection Score**: Run1=9.0, Run2=9.5, Mean=9.25

---

## Bonus and Penalty Details

### Baseline Bonus Performance

**Run1 Bonuses** (7 detected, capped at +2.5):
- B01: Database encryption at rest (Issue #7) ✓
- B02: Security monitoring (Issue #25) ✓
- B03: API request size limits (Issue #12) ✓
- B04: Admin role model undefined (Issue #14) ✓
- B05: RabbitMQ security (Issue #17) ✓
- B06: PCI DSS compliance (Issue #10) ✓
- B07: Audit logging (Issue #5) ✓

**Run2 Bonuses** (3 detected, +1.5):
- B01: Database encryption at rest (Issue #11) ✓
- B04: Admin role model undefined (Issue #9) ✓
- B07: Audit logging (Issue #4) ✓
- B02, B03, B05, B06: Not mentioned ×

**Baseline Penalties**: 0 penalties (both runs)

### weighted-scoring Bonus Performance

**Run1 Bonuses** (6 detected, capped at +2.5):
- B01: Database encryption at rest (Issue #3) ✓
- B02: Security monitoring (Issue #8 real-time alerting) ✓
- B03: API request size limits (Issue #6 max payload 1MB) ✓
- B04: Admin role model undefined × (Not explicitly mentioned)
- B05: RabbitMQ security (Infrastructure table) ✓
- B06: PCI DSS compliance (Issue #5, Issue #8) ✓
- B07: Audit logging (Issue #8) ✓

**Run2 Bonuses** (6 detected, capped at +2.5):
- Identical pattern to Run1 with same 6 bonuses detected
- B04 consistently not mentioned in both runs

**weighted-scoring Penalties**: 0 penalties (both runs)

### adversarial-perspective Bonus and Penalty Performance

**Run1 Bonuses** (3 detected, +1.5):
- B01: Database encryption at rest (Section 4.2) ✓
- B02: Security monitoring (Section 2.4 real-time alerting) ✓
- B07: Audit logging (Section 2.4) ✓
- B03, B04, B05, B06: Not mentioned ×

**Run1 Penalties** (-1.5):
1. Session fixation speculation (Section 2.2) - JWT-based auth doesn't support URL parameter session fixation
2. Infrastructure compromise chain (Section 3) - Hypothetical chain not grounded in specific design flaws
3. Payment idempotency (Section 5.2) - Operational/reliability concern, not strictly security design gap

**Run2 Bonuses** (4 detected, +2.0):
- B01: Database encryption at rest (Section 7.3) ✓
- B02: Security monitoring (Section 8 anomaly detection) ✓
- B04: Admin role model undefined (Section 5.6) ✓
- B07: Audit logging (Section 5.3) ✓
- B03, B05, B06: Not mentioned ×

**Run2 Penalties** (-2.5):
1. MFA absence as "Critical" gap (Section 5.1) - Prescriptive, goes beyond design review
2. Payment idempotency (Section 2.2) - Operational concern, not security design
3. Session hijacking via MITM (Section 2.1) - Contradicts TLS 1.3 specification
4. Verbose error messages (Section 2.4) - Speculates stack traces without design evidence
5. Infrastructure Chain 3 (Section 3) - Hypothetical vulnerability exploitation without CVEs

---

## Comparative Analysis

### Performance Summary by Independent Variables

| Variant | Variation ID | Independent Variables | Mean Score | Effect vs Baseline |
|---------|--------------|----------------------|------------|--------------------|
| baseline | N/A | Current stable baseline | 11.0 | - |
| weighted-scoring | V012-weighted | Severity weighting + explicit scoring instructions | 8.5 | -2.5pt |
| adversarial-perspective | V012-adversarial | Attack chain analysis + STRIDE framework | 9.0 | -2.0pt |

### Detection Capability Analysis

**Baseline Strengths**:
- Highest mean score (11.0) driven by comprehensive bonus detection (Run1: 7 bonuses, Run2: 3 bonuses)
- Strong P01 detection (both runs 100%)
- Perfect critical issue detection (P05, P08, P10: 100%)
- Broad infrastructure coverage with detailed component assessment

**Baseline Weaknesses**:
- P04 consistently missed (0% detection) - "should" vs "must" language analysis gap
- P06 partially detected (50%) - misses specific PUT/DELETE authorization gaps
- Moderate stability (SD=1.0) due to P03/P09 variance between runs

**weighted-scoring Strengths**:
- Perfect stability (SD=0.0) - identical detection patterns across both runs
- Strong critical issue detection (P02, P05, P07, P08, P09, P10: 100%)
- Zero false positives (0 penalties)
- Consistent bonus detection (6 bonuses per run)

**weighted-scoring Weaknesses**:
- **Positive framing bias**: Issues P01/P03/P04/P06 treated as positive aspects instead of identifying gaps
- Lower detection score (6.0) compared to baseline (9.0)
- Struggles with "adequacy evaluation" - excels at identifying missing specs but fails to critique existing weak specifications
- Pattern: "absence detection" strong, "sufficiency analysis" weak

**adversarial-perspective Strengths**:
- High detection score (9.25 avg) close to baseline (9.0)
- Perfect stability (SD=0.0)
- Strong P06 detection (100%) via IDOR exploitation framework - solves baseline's partial detection issue
- Excellent P03 detection (100%) via defense gap analysis

**adversarial-perspective Weaknesses**:
- Accumulates penalties (-2.0 avg) for speculative analysis beyond design document scope
- Lower bonus detection (3-4 bonuses) compared to baseline (3-7) and weighted-scoring (6)
- Tendency to assume worst-case implementations rather than analyzing provided specifications
- Scope discipline issues: MITM attacks despite TLS 1.3, dependency exploits without identified CVEs

### Cross-Variant Problem Analysis

**P01 (Password Reset Token Long Expiration)**:
- baseline: 100% detection (both runs identify 2-hour expiration as excessive)
- weighted-scoring: 0% detection (treats as positive aspect)
- adversarial-perspective: 100% detection (identifies brute-force opportunity)
- **Insight**: Severity weighting causes positive framing bias for medium-severity issues

**P03 (Weak Password Requirements)**:
- baseline: 75% detection (Run1: questions 8-char min; Run2: treats as positive)
- weighted-scoring: 0% detection (both runs treat as positive)
- adversarial-perspective: 100% detection (both runs identify as defense gap)
- **Insight**: Adversarial framing enables consistent password policy critique

**P04 (Log Redaction Not Enforced)**:
- baseline: 0% detection
- weighted-scoring: 0% detection
- adversarial-perspective: 75% detection (Run2 identifies "should" weakness)
- **Insight**: Subtle language analysis challenging for all variants; adversarial perspective improves detection via enforcement focus

**P06 (Missing Authorization Check for Booking Modification)**:
- baseline: 50% detection (partial in both runs)
- weighted-scoring: 0% detection (treats as positive)
- adversarial-perspective: 100% detection (IDOR exploitation framework)
- **Insight**: Attack chain analysis enables endpoint-specific authorization gap detection

**P07 (Elasticsearch Access Control Not Specified)**:
- baseline: 100% detection
- weighted-scoring: 100% detection
- adversarial-perspective: 50% detection (Run1 missed, Run2 detected)
- **Insight**: Infrastructure-focused variants (baseline/weighted-scoring) excel at component security assessment

### Stability vs Performance Trade-off

| Variant | Stability (SD) | Mean Score | Trade-off Pattern |
|---------|---------------|------------|-------------------|
| baseline | 1.0 (Medium) | 11.0 | High performance with acceptable variance |
| weighted-scoring | 0.0 (High) | 8.5 | Perfect consistency at cost of -2.5pt |
| adversarial-perspective | 0.0 (High) | 9.0 | Perfect consistency with -2.0pt, balanced trade-off |

**Analysis**: weighted-scoring achieves perfect stability through deterministic "absence detection" but sacrifices adequacy evaluation capability (-2.5pt). adversarial-perspective achieves perfect stability through consistent attack framing while maintaining higher detection (-2.0pt). baseline's SD=1.0 reflects natural variance in bonus detection (7 vs 3 bonuses) and subtle issue detection (P03/P09 partial), indicating high ceiling with execution variability.

---

## Key Findings

### Insight 1: Positive Framing Bias in Severity-Weighted Approaches
**Evidence**: weighted-scoring consistently treated partially-addressed issues (P01, P03, P04, P06) as positive aspects rather than identifying gaps, resulting in 4 complete detection failures.

**Mechanism**: Explicit severity weighting instruction ("HIGH WEIGHT", "CRITICAL") appears to create binary "present/absent" evaluation rather than "adequate/inadequate" analysis. When a specification mentions a security measure (e.g., "8-character password minimum"), the weighted approach acknowledges presence without questioning sufficiency.

**Impact**: -4.0pt detection score difference (baseline 9.0 vs weighted-scoring 6.0) primarily driven by P01/P03/P04/P06 failures. This represents fundamental evaluation mode shift from "gap identification" to "presence confirmation."

**Knowledge Update Candidate**: New consideration for approach-catalog.md: "Severity weighting can induce positive framing bias where partially-addressed specifications are treated as complete, reducing adequacy evaluation capability."

### Insight 2: Adversarial Framing Solves Endpoint-Specific Authorization Detection
**Evidence**: adversarial-perspective achieved 100% P06 detection (IDOR exploitation framework) vs baseline 50% and weighted-scoring 0%. Attack chain analysis forced explicit enumeration of state-changing endpoints (PUT/DELETE) and authorization verification for each.

**Mechanism**: STRIDE-based analysis and exploit scenario construction require mapping each API operation to potential abuse cases, making endpoint-specific authorization gaps immediately visible. Baseline's general "authorization model" framing allows aggregated assessment without per-endpoint validation.

**Impact**: +0.5pt improvement on P06 (critical severity). Demonstrates adversarial perspective's value for granular authorization analysis.

**Knowledge Update Candidate**: New consideration: "Attack chain analysis improves endpoint-specific authorization gap detection by forcing per-operation exploit scenario construction (P06: 100% vs baseline 50%)."

### Insight 3: Perfect Stability Does Not Guarantee High Performance
**Evidence**: weighted-scoring achieved SD=0.0 (perfect stability) but lowest mean score (8.5), while baseline's SD=1.0 (medium stability) achieved highest mean score (11.0).

**Mechanism**: weighted-scoring's stability stems from deterministic "absence detection" pattern that consistently identifies missing specifications but fails adequacy evaluation. Baseline's variance (SD=1.0) reflects high bonus detection ceiling (7 bonuses in Run1) with execution variability (3 bonuses in Run2), indicating performance ceiling rather than core instability.

**Impact**: Stability metric alone insufficient for prompt optimization decisions. High SD may indicate high-variance bonus detection (desirable) rather than core detection instability (undesirable). Need to decompose SD into "detection variance" vs "bonus variance" for optimization guidance.

**Knowledge Update Candidate**: Refinement to principle: "Perfect stability (SD=0.0) may indicate limited upside potential. Medium stability (SD=0.5-1.0) driven by bonus variance is acceptable for high-ceiling performance (baseline: 7 bonuses, 11.0 mean)."

### Insight 4: Scope Control vs Detection Performance Trade-off in Adversarial Approaches
**Evidence**: adversarial-perspective achieved 9.25 avg detection score (close to baseline 9.0) but accumulated -2.0 avg penalty score for speculative analysis (MITM attacks despite TLS 1.3, hypothetical dependency exploits).

**Mechanism**: Adversarial framing encourages exhaustive threat modeling that extends beyond design document scope. Attack chain construction naturally generates "what-if" scenarios (e.g., "what if attacker MITMs despite TLS?") that contradict stated specifications. This speculation improves detection (P06: 100%) but reduces precision (penalties for out-of-scope analysis).

**Impact**: Net -2.0pt from baseline despite +0.5pt detection improvement, indicating penalty accumulation outweighs detection gains. However, adversarial perspective solves specific detection gaps (P06 IDOR) that baseline consistently struggles with.

**Knowledge Update Candidate**: New consideration: "Adversarial perspective improves granular authorization detection (P06: 100%) but accumulates penalties (-2.0pt avg) for speculative threat modeling. Requires explicit scope boundaries: 'Analyze provided design specifications only; flag missing specs without assuming worst-case implementations.'"

### Insight 5: Bonus Detection Variance Drives Baseline Stability Score
**Evidence**: baseline's SD=1.0 primarily driven by bonus variance (Run1: 7 bonuses capped at +2.5, Run2: 3 bonuses at +1.5) rather than core embedded issue detection (Run1: 9.5, Run2: 8.5, both high).

**Mechanism**: Comprehensive infrastructure review in Run1 led to broader bonus discovery (B02: security monitoring, B03: request size limits, B05: RabbitMQ, B06: PCI DSS) that Run2 missed. Core detection (P01-P10) remained stable except P03/P09 partial detections, indicating high baseline capability with execution-dependent breadth.

**Impact**: baseline achieves highest mean score (11.0) through high bonus ceiling (7 bonuses) with acceptable stability (SD=1.0). Stability metric conflates desirable "high upside variance" with undesirable "detection unreliability."

**Knowledge Update Candidate**: Refinement: "Stability assessment should decompose total SD into 'core detection SD' (embedded issues P01-P10) and 'bonus detection SD' (B01-B07). High bonus SD indicates high ceiling, not instability (baseline: 7 bonuses in Run1, SD=1.0 acceptable)."

---

## Convergence Analysis

### Convergence Check (per scoring-rubric.md Section 5)
**Condition**: 2 rounds consecutive with improvement < 0.5pt → "Convergence"

**Status**: 継続推奨

**Rationale**:
- This is Round 012, a new baseline evaluation with different test variants (weighted-scoring, adversarial-perspective)
- Previous Round 011 tested jwt-storage-explicit (+1.25pt vs baseline) and log-masking-explicit (-1.5pt)
- No direct 2-round consecutive comparison available for convergence assessment
- baseline score 11.0 demonstrates strong performance but weighted-scoring (-2.5pt) and adversarial-perspective (-2.0pt) provide actionable insights for further optimization

**Next Round Recommendation**:
1. Test "scope-bounded adversarial" variant combining adversarial-perspective's P06 detection strength (100%) with explicit scope control to reduce penalties
2. Test "adequacy-evaluation" variant adding explicit instructions to weighted-scoring to critique sufficiency of existing specifications (addressing P01/P03/P04/P06 positive framing bias)
3. Consider hybrid approach: baseline's bonus detection ceiling + adversarial-perspective's authorization granularity + explicit scope boundaries

---

## Recommendations

### Short-term Optimization (Next Round)
1. **Scope-Bounded Adversarial Variant**: Implement adversarial-perspective's attack chain analysis with explicit design-doc-only constraint: "Analyze provided specifications; flag missing specs without assuming worst-case implementations not stated in document."
   - **Target**: Maintain P06 detection (100%) while reducing penalties from -2.0 to -0.5
   - **Expected Impact**: +1.5pt improvement over adversarial-perspective

2. **Adequacy-Evaluation Weighted Variant**: Extend weighted-scoring with explicit instruction: "For each mentioned security measure, evaluate sufficiency and enforcement mechanisms; identify weak language ('should' vs 'must'), inadequate parameters (8-char vs 12-char), and missing enforcement details."
   - **Target**: Improve P01/P03/P04/P06 detection from 0% to 75%
   - **Expected Impact**: +3.0pt improvement over weighted-scoring

### Medium-term Strategy
1. **Hybrid Baseline+Adversarial**: Combine baseline's comprehensive infrastructure assessment (7-bonus ceiling) with adversarial-perspective's endpoint-specific authorization analysis
   - **Implementation**: Add "Per-endpoint authorization checklist" section to baseline while maintaining broad infrastructure table
   - **Target**: 11.0 (baseline) + 0.5 (P06 improvement) = 11.5 expected

2. **Bonus Detection Stabilization**: Investigate baseline Run1 vs Run2 bonus variance (7 vs 3 bonuses) to identify execution factors enabling comprehensive coverage
   - **Analysis**: Run1's "Infrastructure Security Assessment table with 12 components" appears to trigger systematic bonus discovery
   - **Implementation**: Make infrastructure component enumeration mandatory in baseline prompt

### Long-term Considerations
1. **Stability Metric Decomposition**: Develop separate "core detection SD" and "bonus detection SD" metrics to distinguish performance ceiling variance from detection unreliability
2. **Penalty Prevention Framework**: Create explicit scope boundary definitions for adversarial approaches: "speculative attack scenarios require explicit design document evidence"
3. **Adequacy Evaluation Training**: Build prompt library demonstrating weak specification critique patterns (e.g., "should" → "must", "8-char" → "12-char", "general RBAC" → "per-endpoint authorization")

---

## Appendix: Detailed Score Breakdown

### Baseline Detailed Scoring
```
Run1:
  Detection: P01(1.0) + P02(1.0) + P03(1.0) + P04(0.0) + P05(1.0) + P06(0.5) + P07(1.0) + P08(1.0) + P09(1.0) + P10(1.0) = 9.5
  Bonus: B01(0.5) + B02(0.5) + B03(0.5) + B04(0.5) + B05(0.5) [capped at 5 items] = +2.5
  Penalty: 0.0
  Total: 9.5 + 2.5 - 0.0 = 12.0

Run2:
  Detection: P01(1.0) + P02(1.0) + P03(0.5) + P04(0.0) + P05(1.0) + P06(0.5) + P07(1.0) + P08(1.0) + P09(0.5) + P10(1.0) = 8.5
  Bonus: B01(0.5) + B04(0.5) + B07(0.5) = +1.5
  Penalty: 0.0
  Total: 8.5 + 1.5 - 0.0 = 10.0

Mean: (12.0 + 10.0) / 2 = 11.0
SD: sqrt(((12.0-11.0)² + (10.0-11.0)²) / 2) = 1.0
```

### weighted-scoring Detailed Scoring
```
Run1:
  Detection: P01(0.0) + P02(1.0) + P03(0.0) + P04(0.0) + P05(1.0) + P06(0.0) + P07(1.0) + P08(1.0) + P09(1.0) + P10(1.0) = 6.0
  Bonus: B01(0.5) + B02(0.5) + B03(0.5) + B05(0.5) + B06(0.5) [capped at 5 items] = +2.5
  Penalty: 0.0
  Total: 6.0 + 2.5 - 0.0 = 8.5

Run2:
  Detection: P01(0.0) + P02(1.0) + P03(0.0) + P04(0.0) + P05(1.0) + P06(0.0) + P07(1.0) + P08(1.0) + P09(1.0) + P10(1.0) = 6.0
  Bonus: B01(0.5) + B02(0.5) + B03(0.5) + B05(0.5) + B06(0.5) = +2.5
  Penalty: 0.0
  Total: 6.0 + 2.5 - 0.0 = 8.5

Mean: (8.5 + 8.5) / 2 = 8.5
SD: sqrt(((8.5-8.5)² + (8.5-8.5)²) / 2) = 0.0
```

### adversarial-perspective Detailed Scoring
```
Run1:
  Detection: P01(1.0) + P02(1.0) + P03(1.0) + P04(1.0) + P05(1.0) + P06(1.0) + P07(0.0) + P08(1.0) + P09(1.0) + P10(1.0) = 9.0
  Bonus: B01(0.5) + B02(0.5) + B07(0.5) = +1.5
  Penalty: Session fixation(0.5) + Infrastructure chain(0.5) + Payment idempotency(0.5) = -1.5
  Total: 9.0 + 1.5 - 1.5 = 9.0

Run2:
  Detection: P01(1.0) + P02(1.0) + P03(1.0) + P04(0.5) + P05(1.0) + P06(1.0) + P07(1.0) + P08(1.0) + P09(1.0) + P10(1.0) = 9.5
  Bonus: B01(0.5) + B02(0.5) + B04(0.5) + B07(0.5) = +2.0
  Penalty: MFA prescriptive(0.5) + Payment idempotency(0.5) + MITM speculation(0.5) + Verbose errors(0.5) + Infrastructure chain(0.5) = -2.5
  Total: 9.5 + 2.0 - 2.5 = 9.0

Mean: (9.0 + 9.0) / 2 = 9.0
SD: sqrt(((9.0-9.0)² + (9.0-9.0)²) / 2) = 0.0
```
