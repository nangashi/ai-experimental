# Format Benchmark Scoring Report - Run 2

## Run-by-Run Results

### audit-ce-alpha-run2
- Detector: audit-style (CE)
- Test Agent: api-design-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/audit-ce-alpha-run2.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| P1 | tautology | ○ | CE-01 | Correctly identified circular definition in RESTful principle |
| P2 | vague | ○ | CE-02 | Correctly identified "appropriate" as vague and unactionable |
| P3 | duplicate | × | N/A | Duplication between title and content not explicitly detected |
| P4 | vague | ○ | CE-03 | Correctly identified "best practices" as unexecutable |
| P5 | contradiction | ○ | CE-04 | Correctly identified authentication contradiction |
| P6 | pseudo-precision | ○ | CE-05 | Correctly identified "industry-standard benchmarks" as pseudo-precision |
| P7 | infeasible | ○ | CE-06 | Correctly identified "all possible traffic scenarios" as infeasible |
| P8 | vague | ○ | CE-07 | Correctly identified "as needed" as vague |
| P9 | low-SN | ○ | CE-08 | Correctly identified future-speculative check |
| P10 | missing-context | ○ | CE-09 | Correctly identified missing external reference |
| P11 | cost-ineffective | ○ | CE-10 | Correctly identified cross-microservice tracing as cost-ineffective |
| P12 | unexecutable | ○ | CE-11 | Correctly identified API execution as unexecutable |

Metrics:
- Planted: 12
- Detected (○): 11
- Partial (△): 0
- Missed (×): 1
- False Positives: 1 (CE-12 about multiple criteria duplication, though partially legitimate)
- Bonus Discoveries: 0
- Recall: 11/12 = 0.917
- Recall (lenient, ○+△): 11/12 = 0.917

---

### audit-ce-beta-run2
- Detector: audit-style (CE)
- Test Agent: data-model-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/audit-ce-beta-run2.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| Q1 | vague | △ | CE-01 | Identified "quality" but not specifically as vague/unactionable (CE-01 focuses on tautology) |
| Q2 | tautology | ○ | CE-01 | Correctly identified circular definition in normalization |
| Q3 | contradiction | ○ | CE-02 | Correctly identified NOT NULL contradiction |
| Q4 | duplicate | ○ | CE-07 | Correctly identified duplicate indexing criteria |
| Q5 | pseudo-precision | ○ | CE-03 | Correctly identified "enterprise-grade standards" as pseudo-precision |
| Q6 | cost-ineffective | ○ | CE-03 | Correctly identified "all possible SQL queries" as infeasible (same finding CE-03) |
| Q7 | missing-context | ○ | CE-09 | Correctly identified missing data dictionary reference |
| Q8 | low-SN | ○ | CE-06 | Correctly identified vague compliance check |
| Q9 | unexecutable | ○ | CE-04 | Correctly identified production monitoring as unexecutable |
| Q10 | infeasible | ○ | CE-05 | Correctly identified cross-shard verification as infeasible |

Metrics:
- Planted: 10
- Detected (○): 9
- Partial (△): 1
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 3 (CE-08, CE-10, CE-11, CE-12 - legitimate findings about vague expressions, ER diagrams, cascade rules, and audit columns)
- Recall: 9/10 = 0.900
- Recall (lenient, ○+△): 10/10 = 1.000

---

### design-ce-alpha-run2
- Detector: design-style (CE)
- Test Agent: api-design-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/design-ce-alpha-run2.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| P1 | tautology | ○ | CE-DS-01 | Correctly identified tautological criterion definition |
| P2 | vague | ○ | CE-DS-09 | Correctly identified "appropriate" as aspirational without detection method |
| P3 | duplicate | △ | CE-DS-12 | Identified semantic overlap but not specific title/content duplication |
| P4 | vague | ○ | CE-DS-07 | Correctly identified "best practices" reference without definition |
| P5 | contradiction | ○ | CE-DS-02 | Correctly identified direct contradiction in authentication |
| P6 | pseudo-precision | ○ | CE-DS-06 | Correctly identified "industry-standard benchmarks" as undefined |
| P7 | infeasible | ○ | CE-DS-05 | Correctly identified "all possible traffic scenarios" as infeasible |
| P8 | vague | ○ | CE-DS-08 | Correctly identified "as needed" vague threshold |
| P9 | low-SN | ○ | CE-DS-11 | Correctly identified aspirational future-focused check |
| P10 | missing-context | ○ | CE-DS-10 | Correctly identified external document reference without location |
| P11 | cost-ineffective | ○ | CE-DS-04 | Correctly identified cross-system analysis exceeds scope |
| P12 | unexecutable | ○ | CE-DS-03 | Correctly identified runtime execution in static review context |

Metrics:
- Planted: 12
- Detected (○): 11
- Partial (△): 1
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 2 (CE-DS-13: missing response format consistency, CE-DS-14: missing idempotency requirements - both legitimate gaps)
- Recall: 11/12 = 0.917
- Recall (lenient, ○+△): 12/12 = 1.000

---

### design-ce-beta-run2
- Detector: design-style (CE)
- Test Agent: data-model-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/design-ce-beta-run2.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| Q1 | vague | △ | CE-DS-09 | Identified as aspirational without detection method, but not specifically as vague quality |
| Q2 | tautology | ○ | CE-DS-05 | Correctly identified tautological criterion |
| Q3 | contradiction | ○ | CE-DS-01 | Correctly identified contradictory NOT NULL requirements |
| Q4 | duplicate | ○ | CE-DS-08 | Correctly identified duplicate indexing criteria |
| Q5 | pseudo-precision | ○ | CE-DS-07 | Correctly identified "enterprise-grade" as undefined standard |
| Q6 | cost-ineffective | ○ | CE-DS-02 | Correctly identified exhaustive query analysis as infeasible |
| Q7 | missing-context | ○ | CE-DS-06 | Correctly identified missing data dictionary reference |
| Q8 | low-SN | ○ | CE-DS-09 | Correctly identified aspirational compliance check without detection method |
| Q9 | unexecutable | ○ | CE-DS-03 | Correctly identified runtime monitoring in static review |
| Q10 | infeasible | ○ | CE-DS-04 | Correctly identified distributed shard verification as infeasible |

Metrics:
- Planted: 10
- Detected (○): 9
- Partial (△): 1
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 3 (CE-DS-10: vague normalization, CE-DS-11-12: scope-criteria gaps, CE-DS-13: missing convergence details - all legitimate)
- Recall: 9/10 = 0.900
- Recall (lenient, ○+△): 10/10 = 1.000

---

### audit-sa-alpha-run2
- Detector: audit-style (SA)
- Test Agent: api-design-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/audit-sa-alpha-run2.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| S1 | missing-outofscope | ○ | SA-02 | Correctly identified missing Out of Scope section |
| S2 | scope-creep | ○ | SA-07 | Correctly identified integration testing as scope creep |
| S3 | boundary-ambiguity | ○ | SA-03 | Correctly identified boundary ambiguity with security reviewer |
| S4 | scope-exceed | ○ | SA-05 | Correctly identified performance domain exceeding scope |
| S5 | missing-crossref | ○ | SA-02 | Correctly identified missing cross-references (same as SA-02) |

Metrics:
- Planted: 5
- Detected (○): 5
- Partial (△): 0
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 5 (SA-01: implicit scope, SA-04: internal contradiction, SA-06: high-cost tracing, SA-08-10: broad scope and coverage issues - all legitimate)
- Recall: 5/5 = 1.000
- Recall (lenient, ○+△): 5/5 = 1.000

---

### audit-sa-beta-run2
- Detector: audit-style (SA)
- Test Agent: data-model-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/audit-sa-beta-run2.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| S1 | over-broad | ○ | SA-04 | Correctly identified API response format and capacity planning as over-broad |
| S2 | scope-creep | ○ | SA-07 | Correctly identified distributed systems as scope creep |
| S3 | missing-outofscope | ○ | SA-01 | Correctly identified missing Out of Scope section |
| S4 | boundary-ambiguity | ○ | SA-02 | Correctly identified boundary ambiguity with compliance reviewer |
| S5 | internal-inconsistency | × | N/A | Severity naming inconsistency not detected |

Metrics:
- Planted: 5
- Detected (○): 4
- Partial (△): 0
- Missed (×): 1
- False Positives: 0
- Bonus Discoveries: 5 (SA-03: NOT NULL contradiction, SA-05-09: various scope-criteria inconsistencies - all legitimate)
- Recall: 4/5 = 0.800
- Recall (lenient, ○+△): 4/5 = 0.800

---

### design-sa-alpha-run2
- Detector: design-style (SA)
- Test Agent: api-design-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/design-sa-alpha-run2.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| S1 | missing-outofscope | ○ | SA-DS-01 | Correctly identified missing scope boundary documentation |
| S2 | scope-creep | ○ | SA-DS-05 | Correctly identified integration testing as scope creep |
| S3 | boundary-ambiguity | ○ | SA-DS-03 | Correctly identified territory grab from security domain |
| S4 | scope-exceed | ○ | SA-DS-04 | Correctly identified performance domain territory grab |
| S5 | missing-crossref | ○ | SA-DS-01 | Correctly identified missing cross-references (same as SA-DS-01) |

Metrics:
- Planted: 5
- Detected (○): 5
- Partial (△): 0
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 6 (SA-DS-02: authentication contradiction, SA-DS-06-11: various scope extensions and vague language - all legitimate)
- Recall: 5/5 = 1.000
- Recall (lenient, ○+△): 5/5 = 1.000

---

### design-sa-beta-run2
- Detector: design-style (SA)
- Test Agent: data-model-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/design-sa-beta-run2.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| S1 | over-broad | ○ | SA-DS-01 | Correctly identified scope-criteria contradiction (API response validation) |
| S2 | scope-creep | ○ | SA-DS-04 | Correctly identified distributed systems architecture scope creep |
| S3 | missing-outofscope | ○ | SA-DS-07 | Correctly identified missing Out of Scope documentation |
| S4 | boundary-ambiguity | △ | SA-DS-09 | Identified vague criteria but not specifically boundary ambiguity with compliance |
| S5 | internal-inconsistency | × | N/A | Severity naming inconsistency not detected |

Metrics:
- Planted: 5
- Detected (○): 4
- Partial (△): 1
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 6 (SA-DS-02-03: runtime monitoring and cross-shard issues, SA-DS-05-10: various scope and consistency issues - all legitimate)
- Recall: 4/5 = 0.800
- Recall (lenient, ○+△): 5/5 = 1.000

---

## Comparative Summary - Run 2

### CE Dimension: audit-style vs design-style

| Metric | audit-style (alpha) | design-style (alpha) | audit-style (beta) | design-style (beta) |
|--------|-------------------|---------------------|-------------------|---------------------|
| Recall (strict) | 0.917 (11/12) | 0.917 (11/12) | 0.900 (9/10) | 0.900 (9/10) |
| Recall (lenient) | 0.917 (11/12) | 1.000 (12/12) | 1.000 (10/10) | 1.000 (10/10) |
| False Positives | 1 | 0 | 0 | 0 |
| Bonus | 0 | 2 | 3 | 3 |

**Average audit-style CE (Run 2)**: Recall (strict) = 0.909, Recall (lenient) = 0.959
**Average design-style CE (Run 2)**: Recall (strict) = 0.909, Recall (lenient) = 1.000

### SA Dimension: audit-style vs design-style

| Metric | audit-style (alpha) | design-style (alpha) | audit-style (beta) | design-style (beta) |
|--------|-------------------|---------------------|-------------------|---------------------|
| Recall (strict) | 1.000 (5/5) | 1.000 (5/5) | 0.800 (4/5) | 0.800 (4/5) |
| Recall (lenient) | 1.000 (5/5) | 1.000 (5/5) | 0.800 (4/5) | 1.000 (5/5) |
| False Positives | 0 | 0 | 0 | 0 |
| Bonus | 5 | 6 | 5 | 6 |

**Average audit-style SA (Run 2)**: Recall (strict) = 0.900, Recall (lenient) = 0.900
**Average design-style SA (Run 2)**: Recall (strict) = 0.900, Recall (lenient) = 1.000

### Overall - Run 2

| Metric | audit-style avg | design-style avg |
|--------|----------------|-----------------|
| Recall (strict) | 0.904 | 0.904 |
| Recall (lenient) | 0.929 | 1.000 |
| False Positives | 0.25 | 0.0 |
| Bonus | 3.25 | 4.25 |

---

## Run 1 vs Run 2 Reproducibility Analysis

### CE Dimension Reproducibility

| Test Case | Style | Run 1 Strict | Run 2 Strict | Variance | Run 1 Lenient | Run 2 Lenient | Variance |
|-----------|-------|-------------|-------------|----------|--------------|--------------|----------|
| alpha-ce | audit | 0.917 | 0.917 | 0.000 | 0.917 | 0.917 | 0.000 |
| alpha-ce | design | 0.917 | 0.917 | 0.000 | 1.000 | 1.000 | 0.000 |
| beta-ce | audit | 0.800 | 0.900 | **0.100** | 1.000 | 1.000 | 0.000 |
| beta-ce | design | 0.900 | 0.900 | 0.000 | 1.000 | 1.000 | 0.000 |

**CE Dimension Summary:**
- audit-style alpha: Perfect reproducibility (0.000 variance)
- design-style alpha: Perfect reproducibility (0.000 variance)
- audit-style beta: Improved performance in Run 2 (+0.100 strict recall)
- design-style beta: Perfect reproducibility (0.000 variance)

### SA Dimension Reproducibility

| Test Case | Style | Run 1 Strict | Run 2 Strict | Variance | Run 1 Lenient | Run 2 Lenient | Variance |
|-----------|-------|-------------|-------------|----------|--------------|--------------|----------|
| alpha-sa | audit | 0.600 | 1.000 | **0.400** | 1.000 | 1.000 | 0.000 |
| alpha-sa | design | 1.000 | 1.000 | 0.000 | 1.000 | 1.000 | 0.000 |
| beta-sa | audit | 0.800 | 0.800 | 0.000 | 0.800 | 0.800 | 0.000 |
| beta-sa | design | 0.800 | 0.800 | 0.000 | 0.800 | 1.000 | **0.200** |

**SA Dimension Summary:**
- audit-style alpha: MASSIVE improvement in Run 2 (+0.400 strict recall!)
- design-style alpha: Perfect reproducibility (0.000 variance)
- audit-style beta: Perfect reproducibility (0.000 variance)
- design-style beta: Improved lenient recall in Run 2 (+0.200)

### Overall Reproducibility Summary

**Maximum Variance (Strict Recall)**: 0.400 (audit-style SA-alpha)
**Maximum Variance (Lenient Recall)**: 0.200 (design-style SA-beta)

**Key Findings:**
1. **Design-style shows excellent strict reproducibility** (0.000 variance in 3/4 cases)
2. **Audit-style SA-alpha had dramatic improvement** from Run 1 (0.600) to Run 2 (1.000)
   - This suggests Run 1 may have had a systematic miss that was corrected in Run 2
   - Or there's genuine instability in audit-style SA detection
3. **Lenient recall is highly stable** across both styles (only one 0.200 variance)

---

## 2-Run Average (Final Benchmark Results)

### CE Dimension: 2-Run Average

| Metric | audit-style alpha | design-style alpha | audit-style beta | design-style beta |
|--------|------------------|-------------------|------------------|------------------|
| Avg Strict | (0.917+0.917)/2 = **0.917** | (0.917+0.917)/2 = **0.917** | (0.800+0.900)/2 = **0.850** | (0.900+0.900)/2 = **0.900** |
| Avg Lenient | (0.917+0.917)/2 = **0.917** | (1.000+1.000)/2 = **1.000** | (1.000+1.000)/2 = **1.000** | (1.000+1.000)/2 = **1.000** |

**Average audit-style CE (2-run)**: Recall (strict) = 0.884, Recall (lenient) = 0.959
**Average design-style CE (2-run)**: Recall (strict) = 0.909, Recall (lenient) = 1.000

### SA Dimension: 2-Run Average

| Metric | audit-style alpha | design-style alpha | audit-style beta | design-style beta |
|--------|------------------|-------------------|------------------|------------------|
| Avg Strict | (0.600+1.000)/2 = **0.800** | (1.000+1.000)/2 = **1.000** | (0.800+0.800)/2 = **0.800** | (0.800+0.800)/2 = **0.800** |
| Avg Lenient | (1.000+1.000)/2 = **1.000** | (1.000+1.000)/2 = **1.000** | (0.800+0.800)/2 = **0.800** | (0.800+1.000)/2 = **0.900** |

**Average audit-style SA (2-run)**: Recall (strict) = 0.800, Recall (lenient) = 0.900
**Average design-style SA (2-run)**: Recall (strict) = 0.900, Recall (lenient) = 0.950

### Overall 2-Run Average

| Metric | audit-style | design-style |
|--------|------------|-------------|
| CE Strict (2-run avg) | 0.884 | 0.909 |
| CE Lenient (2-run avg) | 0.959 | 1.000 |
| SA Strict (2-run avg) | 0.800 | 0.900 |
| SA Lenient (2-run avg) | 0.900 | 0.950 |
| **Overall Strict (2-run avg)** | **0.842** | **0.904** |
| **Overall Lenient (2-run avg)** | **0.929** | **0.975** |

---

## Final Conclusion: Design-Style is the Clear Winner

### Performance Gap (2-Run Average)

**Strict Recall**: design-style (0.904) vs audit-style (0.842)
- Design-style shows a **+7.4% advantage** in strict recall (2-run average)
- Design-style achieved **perfect 100% strict recall** on SA-alpha (both runs)

**Lenient Recall**: design-style (0.975) vs audit-style (0.929)
- Design-style shows a **+5.0% advantage** in lenient recall
- Design-style achieved **97.5% lenient recall** vs audit-style's 92.9%

**False Positives**: design-style (0.0) vs audit-style (0.25)
- Design-style had **zero false positives** across all 8 runs
- Audit-style had one false positive (CE-12 in alpha run)

**Bonus Discoveries**: design-style (5.0 avg) vs audit-style (3.0 avg)
- Design-style discovered **67% more** legitimate issues beyond planted problems

### Reproducibility

**Design-style is more reproducible:**
- 3/4 test cases had **perfect 0.000 variance** in strict recall
- Only one case (beta-sa lenient) showed improvement (+0.200)

**Audit-style showed mixed reproducibility:**
- 2/4 test cases had perfect reproducibility
- alpha-sa had **dramatic variance** (0.400 strict recall difference between runs)
- beta-ce improved by 0.100 in Run 2

### Recommendation

**Use design-style as the default format** for agent_audit skill based on:

1. **Higher overall accuracy**: 90.4% strict recall vs 84.2% (2-run average)
2. **Better reproducibility**: More stable results across runs
3. **Zero false positives**: Perfect precision across all runs
4. **More comprehensive**: 67% more bonus discoveries
5. **Superior at scope analysis**: 90% SA strict recall vs 80%

The **adversarial testing lens** in design-style is particularly effective at catching:
- Territory grab and stealth scope creep
- Boundary ambiguities between agents
- Subtle internal contradictions

These are critical issues in multi-agent systems where overlapping responsibilities lead to duplicated effort and conflicting feedback.

### When to Consider Audit-Style

Audit-style may still be useful for:
- Quick initial screening (simpler, fewer findings)
- Single-agent systems with clear boundaries
- Cases where speed > completeness

However, the **performance gap (+7.4%) and reproducibility concerns** make design-style the stronger choice for production use.
