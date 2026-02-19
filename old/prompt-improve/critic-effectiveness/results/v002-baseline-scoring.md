# Scoring Results: v002-baseline

## Executive Summary

**Variant**: v002-baseline
**Mean Score**: 6.36
**Standard Deviation**: 0.58
**Run 1 Score**: 6.01
**Run 2 Score**: 6.71

**Stability**: High (SD = 0.58 < 1.0)

---

## Scenario Scores

| Scenario | Run 1 | Run 2 | Mean |
|----------|-------|-------|------|
| T01 | 10.0 | 8.3 | 9.2 |
| T02 | 7.1 | 7.1 | 7.1 |
| T03 | 8.9 | 8.9 | 8.9 |
| T04 | 7.1 | 7.1 | 7.1 |
| T05 | 4.4 | 5.6 | 5.0 |
| T06 | 5.6 | 7.8 | 6.7 |
| T07 | 0.0 | 1.0 | 0.5 |

**Run Means**:
- Run 1: (10.0+7.1+8.9+7.1+4.4+5.6+0.0)/7 = 42.1/7 = 6.01
- Run 2: (8.3+7.1+8.9+7.1+5.6+7.8+1.0)/7 = 45.8/7 = 6.71

---

## Detailed Scoring by Scenario

### T01: Well-Defined Specialized Perspective (Easy)
Max: 6.0 points | Weights: C1=1.0, C2=1.0, C3=0.5, C4=0.5

| Run | C1 | C2 | C3 | C4 | Raw | Score |
|-----|----|----|----|----|-----|-------|
| R1 | 2 | 2 | 2 | 2 | 6.0/6.0 | 10.0 |
| R2 | 2 | 2 | 1 | 1 | 5.0/6.0 | 8.3 |

**Run 1**: Lists 5+ issues, confirms actionability, verifies boundaries, evaluates criteria → All full
**Run 2**: Same quality but has 2 improvement suggestions affecting C3/C4 → Both partial

---

### T02: Perspective with Scope Overlap (Medium)
Max: 7.0 points | Weights: C1=1.0, C2=1.0, C3=0.5, C4=1.0

| Run | C1 | C2 | C3 | C4 | Raw | Score |
|-----|----|----|----|----|-----|-------|
| R1 | 1 | 2 | 2 | 1 | 5.0/7.0 | 7.1 |
| R2 | 1 | 2 | 2 | 1 | 5.0/7.0 | 7.1 |

**Both**: Identify major overlaps with evidence, verify delegations, judge severity as fundamental. C1 partial (doesn't enumerate all 5 items systematically), C4 partial (states conclusion without comparative analysis).

---

### T03: Perspective with Vague Value Proposition (Medium)
Max: 9.0 points | Weights: C1=1.0, C2=1.0, C3=1.0, C4=0.5, C5=1.0

| Run | C1 | C2 | C3 | C4 | C5 | Raw | Score |
|-----|----|----|----|----|-------|-------|
| R1 | 2 | 2 | 2 | 2 | 2 | 8.0/9.0 | 8.9 |
| R2 | 2 | 2 | 2 | 2 | 2 | 8.0/9.0 | 8.9 |

**Both**: Identify all 5 items as vague, recognize enumeration impossibility, critique actionability (注意すべき pattern), identify redundancy, recommend redesign → All criteria fully met.

---

### T04: Perspective with Inaccurate Cross-References (Medium)
Max: 7.0 points | Weights: C1=1.0, C2=1.0, C3=0.5, C4=1.0

| Run | C1 | C2 | C3 | C4 | Raw | Score |
|-----|----|----|----|----|-----|-------|
| R1 | 2 | 1 | 2 | 1 | 5.0/7.0 | 7.1 |
| R2 | 2 | 1 | 2 | 1 | 5.0/7.0 | 7.1 |

**Both**: Identify 2 inaccurate references clearly, verify 2 accurate ones. C2 partial (mentions error response overlap but not as explicitly missing from out-of-scope), C4 partial (corrections provided but could be more specific).

---

### T05: Minimal Edge Case - Extremely Narrow Perspective (Hard)
Max: 9.0 points | Weights: C1=1.0, C2=1.0, C3=0.5, C4=1.0, C5=1.0

| Run | C1 | C2 | C3 | C4 | C5 | Raw | Score |
|-----|----|----|----|----|-------|-------|
| R1 | 1 | 2 | 2 | 1 | 0 | 4.0/9.0 | 4.4 |
| R2 | 2 | 2 | 2 | 1 | 0 | 5.0/9.0 | 5.6 |

**Run 1**: C1 partial (identifies narrowness but doesn't strongly emphasize integration need), C5 miss (doesn't distinguish enumerable vs valuable)
**Run 2**: C1 full (clearly states excessive narrowness), C5 still miss (mentions mechanical but under "good points")

---

### T06: Complex Overlap - Partially Redundant Perspective (Hard)
Max: 9.0 points | Weights: C1=1.0, C2=1.0, C3=0.5, C4=1.0, C5=1.0

| Run | C1 | C2 | C3 | C4 | C5 | Raw | Score |
|-----|----|----|----|----|-------|-------|
| R1 | 2 | 0 | 2 | 2 | 0 | 5.0/9.0 | 5.6 |
| R2 | 2 | 1 | 2 | 2 | 1 | 7.0/9.0 | 7.8 |

**Run 1**: Identifies 4/5 overlaps, terminology redundancy, missing reference. C2 miss (brief mention of monitoring), C5 miss (lists options without evaluation).
**Run 2**: Same strengths plus C2 partial (discusses monitoring distinction), C5 partial (evaluates options with reasoning).

---

### T07: Perspective with Non-Actionable Outputs (Hard)
Max: 10.0 points | Weights: all 1.0

| Run | C1 | C2 | C3 | C4 | C5 | Raw | Score |
|-----|----|----|----|----|-------|-------|
| R1 | 0 | 0 | 0 | 0 | 0 | 0.0/10.0 | 0.0 |
| R2 | 0 | 1 | 0 | 0 | 0 | 1.0/10.0 | 1.0 |

**Run 1**: Identifies recognition-only pattern and meta-evaluation trap but doesn't meet rubric's specific requirements for explicit pattern detection across ALL criteria, 2-outcome analysis format, or structured 3-point value assessment → All miss.
**Run 2**: C2 partial (provides some actionability analysis), rest miss.

---

## Scoring Methodology

Each criterion scored as:
- **2 (Full)**: Meets all "Full" conditions in rubric
- **1 (Partial)**: Addresses criterion but doesn't meet full conditions
- **0 (Miss)**: Doesn't address criterion or makes incorrect claims

**Raw score** = Σ(rating × weight)
**Scenario score** = (raw score / max possible) × 10
**Run score** = mean of all scenario scores
**Variant mean** = mean(run1, run2)
**Variant SD** = standard deviation(run1, run2)

---

## Performance Analysis

**Strengths**:
- Excellent on easy/medium scenarios (T01-T04 average: 8.05)
- Strong vagueness detection (T03: 8.9)
- Good overlap identification (T02: 7.1)

**Weaknesses**:
- Poor performance on actionability evaluation (T07: 0.5)
- Difficulty with narrow scope edge cases (T05: 5.0)
- Moderate performance on complex overlaps (T06: 6.7)

**Stability**:
- High consistency (SD = 0.58)
- Largest variation in T06 (Run1: 5.6, Run2: 7.8, diff: 2.2)
- Most stable: T02, T03, T04 (identical scores)
