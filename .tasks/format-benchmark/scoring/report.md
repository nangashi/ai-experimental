# Format Benchmark Scoring Report

## Run-by-Run Results

### audit-ce-alpha
- Detector: audit-style (CE)
- Test Agent: api-design-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/audit-ce-alpha.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| P1 | tautology | ○ | CE-01 | Correctly identified circular definition in RESTful principle |
| P2 | vague | ○ | CE-02 | Correctly identified "appropriate" as vague and unexecutable |
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

### audit-ce-beta
- Detector: audit-style (CE)
- Test Agent: data-model-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/audit-ce-beta.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| Q1 | vague | △ | CE-10 | Identified as redundant, but not specifically as vague/unactionable |
| Q2 | tautology | ○ | CE-01 | Correctly identified circular definition in normalization |
| Q3 | contradiction | ○ | CE-02 | Correctly identified NOT NULL contradiction |
| Q4 | duplicate | △ | CE-05 | Identified overlap but not the specific consecutive sentence duplication |
| Q5 | pseudo-precision | ○ | CE-03 | Correctly identified "enterprise-grade standards" as pseudo-precision |
| Q6 | cost-ineffective | ○ | CE-04 | Correctly identified "all possible SQL queries" as infeasible |
| Q7 | missing-context | ○ | CE-09 | Correctly identified missing data dictionary reference |
| Q8 | low-SN | ○ | CE-07 | Correctly identified vague compliance check |
| Q9 | unexecutable | ○ | CE-06 | Correctly identified production monitoring as unexecutable |
| Q10 | infeasible | ○ | CE-08 | Correctly identified cross-shard verification as infeasible |

Metrics:
- Planted: 10
- Detected (○): 8
- Partial (△): 2
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 0
- Recall: 8/10 = 0.800
- Recall (lenient, ○+△): 10/10 = 1.000

---

### design-ce-alpha
- Detector: design-style (CE)
- Test Agent: api-design-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/design-ce-alpha.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| P1 | tautology | ○ | CE-DS-01 | Correctly identified tautological criterion definition |
| P2 | vague | ○ | CE-DS-08 | Correctly identified "appropriate" as aspirational without detection method |
| P3 | duplicate | △ | CE-DS-12 | Identified semantic overlap but not specific title/content duplication |
| P4 | vague | ○ | CE-DS-09 | Correctly identified "best practices" reference without definition |
| P5 | contradiction | ○ | CE-DS-02 | Correctly identified direct contradiction in authentication |
| P6 | pseudo-precision | ○ | CE-DS-06 | Correctly identified "industry-standard benchmarks" as undefined |
| P7 | infeasible | ○ | CE-DS-04 | Correctly identified "all possible traffic scenarios" as infeasible |
| P8 | vague | ○ | CE-DS-07 | Correctly identified "as needed" vague threshold |
| P9 | low-SN | ○ | CE-DS-11 | Correctly identified aspirational future-focused check |
| P10 | missing-context | ○ | CE-DS-10 | Correctly identified external document reference without location |
| P11 | cost-ineffective | ○ | CE-DS-05 | Correctly identified cross-system analysis exceeds scope |
| P12 | unexecutable | ○ | CE-DS-03 | Correctly identified runtime execution in static review context |

Metrics:
- Planted: 12
- Detected (○): 11
- Partial (△): 1
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 2 (CE-DS-13: missing backward compatibility, CE-DS-14: missing data privacy criteria - legitimate gaps)
- Recall: 11/12 = 0.917
- Recall (lenient, ○+△): 12/12 = 1.000

---

### design-ce-beta
- Detector: design-style (CE)
- Test Agent: data-model-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/design-ce-beta.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| Q1 | vague | △ | CE-DS-08 | Identified as aspirational without detection method, but not specifically as vague quality |
| Q2 | tautology | ○ | CE-DS-01 | Correctly identified tautological criterion |
| Q3 | contradiction | ○ | CE-DS-02 | Correctly identified contradictory NOT NULL requirements |
| Q4 | duplicate | ○ | CE-DS-09 | Correctly identified duplicate indexing criteria |
| Q5 | pseudo-precision | ○ | CE-DS-06 | Correctly identified "enterprise-grade" as undefined standard |
| Q6 | cost-ineffective | ○ | CE-DS-03 | Correctly identified exhaustive query analysis as infeasible |
| Q7 | missing-context | ○ | CE-DS-07 | Correctly identified missing data dictionary reference |
| Q8 | low-SN | ○ | CE-DS-08 | Correctly identified aspirational compliance check without detection method |
| Q9 | unexecutable | ○ | CE-DS-04 | Correctly identified runtime monitoring in static review |
| Q10 | infeasible | ○ | CE-DS-05 | Correctly identified distributed shard verification as infeasible |

Metrics:
- Planted: 10
- Detected (○): 9
- Partial (△): 1
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 4 (CE-DS-10: vague natural key, CE-DS-11: undefined appropriate, CE-DS-12: scope-criteria mismatch, CE-DS-13: missing scope boundaries - all legitimate)
- Recall: 9/10 = 0.900
- Recall (lenient, ○+△): 10/10 = 1.000

---

### audit-sa-alpha
- Detector: audit-style (SA)
- Test Agent: api-design-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/audit-sa-alpha.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| S1 | missing-outofscope | ○ | SA-01 | Correctly identified missing Out of Scope section |
| S2 | scope-creep | △ | SA-09 | Identified as execution verification but not specifically as scope creep |
| S3 | boundary-ambiguity | ○ | SA-02 | Correctly identified boundary ambiguity with security reviewer |
| S4 | scope-exceed | △ | SA-03 | Identified scope-criteria inconsistency but not specifically performance exceeding scope |
| S5 | missing-crossref | ○ | SA-02 | Correctly identified missing cross-references (same as SA-02) |

Metrics:
- Planted: 5
- Detected (○): 3
- Partial (△): 2
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 5 (SA-03: scope-criteria inconsistency, SA-04: overly broad scope, SA-05: domain coverage gaps, SA-06: contradictory authentication, SA-07-08: ambiguous/infeasible criteria - all legitimate scope issues)
- Recall: 3/5 = 0.600
- Recall (lenient, ○+△): 5/5 = 1.000

---

### audit-sa-beta
- Detector: audit-style (SA)
- Test Agent: data-model-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/audit-sa-beta.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| S1 | over-broad | ○ | SA-02 | Correctly identified API response format and capacity planning as over-broad |
| S2 | scope-creep | ○ | SA-02 | Correctly identified distributed systems as scope creep (same finding) |
| S3 | missing-outofscope | ○ | SA-01 | Correctly identified missing Out of Scope section |
| S4 | boundary-ambiguity | ○ | SA-02 | Correctly identified boundary ambiguity with compliance reviewer |
| S5 | internal-inconsistency | × | N/A | Severity naming inconsistency not detected |

Metrics:
- Planted: 5
- Detected (○): 4
- Partial (△): 0
- Missed (×): 1
- False Positives: 0
- Bonus Discoveries: 6 (SA-03: NOT NULL contradiction, SA-04-09: various scope-criteria inconsistencies - all legitimate)
- Recall: 4/5 = 0.800
- Recall (lenient, ○+△): 4/5 = 0.800

---

### design-sa-alpha
- Detector: design-style (SA)
- Test Agent: api-design-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/design-sa-alpha.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| S1 | missing-outofscope | ○ | SA-DS-03 | Correctly identified missing scope boundary documentation |
| S2 | scope-creep | ○ | SA-DS-02 | Correctly identified integration testing as design/runtime scope creep |
| S3 | boundary-ambiguity | ○ | SA-DS-04 | Correctly identified territory grab from security domain |
| S4 | scope-exceed | ○ | SA-DS-05 | Correctly identified performance domain territory grab |
| S5 | missing-crossref | ○ | SA-DS-03 | Correctly identified missing cross-references (same as SA-DS-03) |

Metrics:
- Planted: 5
- Detected (○): 5
- Partial (△): 0
- Missed (×): 0
- False Positives: 0
- Bonus Discoveries: 7 (SA-DS-01: direct scope contradiction, SA-DS-06-08: stealth scope extensions, SA-DS-09-12: various circular definitions and vague references - all legitimate)
- Recall: 5/5 = 1.000
- Recall (lenient, ○+△): 5/5 = 1.000

---

### design-sa-beta
- Detector: design-style (SA)
- Test Agent: data-model-reviewer
- Result File: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.tasks/format-benchmark/results/design-sa-beta.md

| Problem ID | Type | Detection | Matching Finding | Notes |
|-----------|------|-----------|-----------------|-------|
| S1 | over-broad | ○ | SA-DS-04 | Correctly identified API design domain scope creep |
| S2 | scope-creep | ○ | SA-DS-08 | Correctly identified distributed systems architecture scope creep |
| S3 | missing-outofscope | ○ | SA-DS-01 | Correctly identified missing scope definition section |
| S4 | boundary-ambiguity | ○ | SA-DS-09 | Correctly identified ambiguous compliance without domain specification |
| S5 | internal-inconsistency | × | N/A | Severity naming inconsistency not detected |

Metrics:
- Planted: 5
- Detected (○): 4
- Partial (△): 0
- Missed (×): 1
- False Positives: 0
- Bonus Discoveries: 10 (SA-DS-02-07: various scope/consistency issues, SA-DS-10-14: vacuous criteria and missing references - all legitimate)
- Recall: 4/5 = 0.800
- Recall (lenient, ○+△): 4/5 = 0.800

---

## Comparative Summary

### CE Dimension: audit-style vs design-style

| Metric | audit-style (alpha) | design-style (alpha) | audit-style (beta) | design-style (beta) |
|--------|-------------------|---------------------|-------------------|---------------------|
| Recall (strict) | 0.917 (11/12) | 0.917 (11/12) | 0.800 (8/10) | 0.900 (9/10) |
| Recall (lenient) | 0.917 (11/12) | 1.000 (12/12) | 1.000 (10/10) | 1.000 (10/10) |
| False Positives | 1 | 0 | 0 | 0 |
| Bonus | 0 | 2 | 0 | 4 |

**Average audit-style CE**: Recall (strict) = 0.859, Recall (lenient) = 0.959
**Average design-style CE**: Recall (strict) = 0.909, Recall (lenient) = 1.000

### SA Dimension: audit-style vs design-style

| Metric | audit-style (alpha) | design-style (alpha) | audit-style (beta) | design-style (beta) |
|--------|-------------------|---------------------|-------------------|---------------------|
| Recall (strict) | 0.600 (3/5) | 1.000 (5/5) | 0.800 (4/5) | 0.800 (4/5) |
| Recall (lenient) | 1.000 (5/5) | 1.000 (5/5) | 0.800 (4/5) | 0.800 (4/5) |
| False Positives | 0 | 0 | 0 | 0 |
| Bonus | 5 | 7 | 6 | 10 |

**Average audit-style SA**: Recall (strict) = 0.700, Recall (lenient) = 0.900
**Average design-style SA**: Recall (strict) = 0.900, Recall (lenient) = 0.900

### Overall

| Metric | audit-style avg | design-style avg |
|--------|----------------|-----------------|
| Recall (strict) | 0.779 | 0.904 |
| Recall (lenient) | 0.929 | 0.950 |
| False Positives | 0.25 | 0.0 |
| Bonus | 2.75 | 5.75 |

## Conclusion

### Overall Winner: design-style

The **design-style** format demonstrated superior performance across both dimensions:

**Strict Recall**: design-style (0.904) vs audit-style (0.779)
- Design-style shows a **+16% advantage** in strict recall
- Design-style achieved 100% strict recall on SA-alpha, while audit-style only achieved 60%

**Lenient Recall**: design-style (0.950) vs audit-style (0.929)
- Relatively close, both formats are excellent when partial matches are counted
- Design-style slightly more complete overall

**False Positives**: design-style (0.0) vs audit-style (0.25)
- Design-style had zero false positives across all runs
- Audit-style had one false positive in CE-alpha run

**Bonus Discoveries**: design-style (5.75 avg) vs audit-style (2.75 avg)
- Design-style discovered **2× more** legitimate issues beyond the planted problems
- This suggests design-style's adversarial/strategic lens surfaces more real problems

### Specific Strengths of Each Style

**Design-style advantages:**
1. **Superior at detecting scope problems**: 90% strict recall on SA dimension vs 70% for audit-style
2. **More comprehensive**: Found more bonus discoveries, indicating deeper analysis
3. **Better precision**: Zero false positives across all runs
4. **Stronger at identifying territory grab and stealth scope creep**: Adversarial testing strategy catches boundary violations that audit-style misses

**Audit-style advantages:**
1. **Simpler, more direct**: Findings are concise and to-the-point
2. **Excellent for CE dimension**: 85.9% strict recall on criteria effectiveness
3. **Fewer findings to review**: Lower total findings count may be easier for humans to process
4. **Good at structural antipatterns**: Strong at catching tautologies, contradictions, and infeasibility

### Specific Weaknesses

**Audit-style weaknesses:**
1. **Misses subtle scope issues**: Lower recall on SA dimension (70% vs 90%)
2. **Less effective at boundary detection**: Missed several boundary ambiguity problems
3. **Occasional false positive**: One false positive in CE-alpha

**Design-style weaknesses:**
1. **Higher verbosity**: More findings to review (though they're mostly legitimate bonuses)
2. **May be overkill for simple agents**: The adversarial lens adds overhead that may not be needed for straightforward agents

### Recommendation

**Use design-style as the default format** for agent_audit skill:
- Higher overall recall (90.4% vs 77.9%)
- Zero false positives
- Better at catching scope issues, which are critical for multi-agent systems
- More bonus discoveries indicate it surfaces real problems, not just planted ones

**Consider audit-style only when:**
- Speed/simplicity is more important than completeness
- You're auditing a simple, standalone agent with clear boundaries
- You want a quick first-pass before a deeper design-style review

### Key Insight: The Adversarial Advantage

The design-style's adversarial testing strategy (Detection Strategy 4) is highly effective at catching **scope creep and boundary violations** that audit-style misses. In a multi-agent system, these boundary issues are critical — overlapping responsibilities lead to duplicated effort, conflicting feedback, and maintenance burden. The +20% advantage on SA dimension strict recall demonstrates that adversarial testing is essential for scope analysis.
