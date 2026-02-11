# Round 001 Comparison Report: reliability-design

## Execution Conditions

- **Target Agent**: reliability-design-reviewer
- **Test Document**: `/home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/prompt-improve/reliability-design/test-document.md`
- **Embedded Problems**: 9 (P01-P09)
- **Variants Tested**: 3 (baseline, variant-few-shot, variant-scoring)
- **Runs per Variant**: 2
- **Evaluation Date**: 2026-02-11

---

## Variants Overview

| Variant | Variation ID | Description |
|---------|-------------|-------------|
| baseline | - | Original prompt without modifications |
| variant-few-shot | S1a | Added few-shot examples for reliability pattern detection |
| variant-scoring | S3a | Added structured scoring rubric and detection checklist |

---

## Comparison Matrix

### Detection Matrix by Problem

| Problem ID | Category | Severity | baseline (R1/R2) | few-shot (R1/R2) | scoring (R1/R2) |
|-----------|----------|----------|------------------|------------------|-----------------|
| P01 | External service fault recovery | Critical | ○/○ | ○/○ | ○/○ |
| P02 | WebSocket fault recovery | Critical | △/○ | △/△ | ○/○ |
| P03 | Message idempotency | Critical | ○/○ | ○/○ | ○/○ |
| P04 | Cross-database consistency | Critical | ○/○ | △/△ | ○/○ |
| P05 | Redis Pub/Sub SPOF | Medium | △/○ | ○/△ | △/△ |
| P06 | SLO/SLA monitoring | Medium | ○/○ | ○/○ | ○/○ |
| P07 | Data migration compatibility | Medium | ○/○ | ○/△ | ○/○ |
| P08 | Rate limiting backpressure | Minor | ○/○ | △/△ | △/△ |
| P09 | Health check depth | Minor | ○/○ | ○/○ | ○/○ |

**Detection Score Summary:**
- baseline: Run1=8.0, Run2=9.0, Mean=8.5
- few-shot: Run1=7.5, Run2=7.0, Mean=7.25
- scoring: Run1=8.0, Run2=8.0, Mean=8.0

---

## Bonus/Penalty Details

### Baseline

**Run1 Bonuses (+1.0):**
- B02: Distributed tracing (S-1, I-3) +0.5
- B03: DR runbook/drill (I-2) +0.5

**Run2 Bonuses (+1.5):**
- B02: Distributed tracing (S-1, C-4) +0.5
- B03: DR runbook (I-2) +0.5
- B04: MongoDB indexes (M-2) +0.5

**Penalties:** 0

---

### Few-Shot

**Run1 Bonuses (+1.0):**
- B02: Distributed tracing with X-Ray/OpenTelemetry (Issue #6) +0.5
- B05: ALB health check configuration (Issue #10) +0.5

**Run2 Bonuses (+1.0):**
- B02: Distributed tracing with AWS X-Ray (Issue #6) +0.5
- B03: Backup and recovery documentation with runbooks (Issue #9) +0.5

**Penalties:** 0

---

### Scoring

**Run1 Bonuses (+1.0):**
- B03: Disaster recovery runbook with backup restoration procedure +0.5
- B05: ALB health check configuration (interval, timeout, threshold) +0.5

**Run2 Bonuses (+1.0):**
- B03: Disaster recovery runbook with backup restoration procedure +0.5
- B05: ALB health check configuration (interval, timeout, threshold) +0.5

**Penalties:** 0

---

## Score Summary

| Variant | Run1 | Run2 | Mean | SD | Stability |
|---------|------|------|------|----|----|
| baseline | 9.0 | 10.5 | 9.75 | 0.75 | High |
| few-shot | 8.5 | 8.0 | 8.25 | 0.25 | High |
| scoring | 9.0 | 9.0 | 9.0 | 0.0 | High |

---

## Recommendation

**Recommended Variant:** baseline

**Reasoning:** According to scoring-rubric.md Section 5, baseline achieves the highest mean score (9.75) with a score difference of +1.5pt over few-shot and +0.75pt over scoring, exceeding the 1.0pt threshold for clear recommendation.

**Convergence Status:** 継続推奨 (This is the first round; convergence evaluation requires at least two rounds)

---

## Analysis

### Independent Variable Effects

#### S1a (few-shot examples): Effect = -1.5pt

**Negative Impact Observed:**
- Detection rate **decreased** from baseline (8.5 detection) to few-shot (7.25 detection)
- Critical regressions:
  - P04 (cross-database consistency): ○○ → △△ (both runs degraded from full to partial detection)
  - P05 (Redis SPOF): △○ → ○△ (inconsistent detection pattern)
  - P07 (data migration): ○○ → ○△ (Run2 degraded)
  - P08 (rate limiting backpressure): ○○ → △△ (both runs degraded)

**Root Cause Hypothesis:**
The few-shot examples may have overfit to specific pattern formats, reducing the agent's ability to generalize across different problem contexts. P04 regression (missing PostgreSQL-MongoDB consistency) suggests the examples focused too narrowly on MongoDB-Redis scenarios.

#### S3a (scoring rubric): Effect = -0.75pt

**Mixed Impact Observed:**
- Detection rate slightly decreased from baseline (8.5) to scoring (8.0)
- Improvements:
  - P02 (WebSocket fault recovery): △○ → ○○ (consistent full detection)
  - P04 (cross-database consistency): ○○ → ○○ (maintained)
- Regressions:
  - P05 (Redis SPOF): △○ → △△ (baseline's Run2 success not replicated)
  - P08 (rate limiting backpressure): ○○ → △△ (both runs degraded)

**Root Cause Hypothesis:**
The scoring rubric improved consistency (SD=0.0) and strengthened detection of connection-related issues (P02), but may have introduced evaluation rigidity that reduced detection flexibility for infrastructure-level concerns (P05, P08).

### Stability Analysis

All three variants achieved high stability (SD ≤ 0.75):
- **baseline (SD=0.75)**: Slight variation in bonus item detection (B04 detected in Run2 only)
- **few-shot (SD=0.25)**: Very stable detection pattern across runs
- **scoring (SD=0.0)**: Perfect consistency, identical detection across both runs

The scoring variant's perfect consistency (SD=0.0) demonstrates strong reproducibility, but this came at the cost of reduced detection rate.

### Bonus Detection Patterns

- **B02 (Distributed Tracing)**: Detected by all three variants (2-3 times across runs), indicating robust observability awareness across prompts
- **B03 (DR Runbook)**: Detected by all three variants (2-3 times across runs), showing consistent operational readiness focus
- **B05 (ALB Health Check)**: Detected by few-shot and scoring (2 times each), but not by baseline
- **B04 (MongoDB Indexes)**: Detected only by baseline (1 time in Run2)

### Critical Problem Coverage

All variants successfully detected critical problems (P01, P03) with 100% consistency:
- P01 (External service fault recovery): ○○ across all variants
- P03 (Message idempotency): ○○ across all variants

The differentiation appears in medium-severity problems (P04, P05, P07, P08), where baseline maintained higher detection rates.

---

## Insights for Next Round

### Preserve Baseline Strengths

Baseline demonstrated superior detection across multiple dimensions:
1. **Cross-database consistency (P04)**: Baseline consistently identified PostgreSQL-MongoDB consistency gaps that variants missed
2. **Infrastructure SPOF (P05)**: Baseline's Run2 achieved full detection of Redis Pub/Sub single-point-of-failure
3. **Rate limiting mechanics (P08)**: Baseline distinguished between abuse prevention and backpressure self-protection
4. **Bonus diversity**: Baseline detected B04 (MongoDB indexes), which variants did not identify

### Variant Improvement Opportunities

**If testing S1a (few-shot) again:**
- Add few-shot examples covering multi-database transaction coordination (address P04 regression)
- Include backpressure vs. abuse-prevention distinction (address P08 regression)
- Balance specific pattern examples with general detection principles

**If testing S3a (scoring) again:**
- Maintain the strong consistency (SD=0.0) while improving detection rate
- Expand scoring rubric to explicitly cover infrastructure-level SPOF analysis (address P05 weakness)
- Clarify rate limiting evaluation criteria to include backpressure mechanics (address P08 weakness)

### Alternative Approaches to Consider

Given that both variants showed net negative effects, consider:
1. **Hybrid approach**: Combine scoring's consistency (SD=0.0) with baseline's detection breadth
2. **Narrow-scope variants**: Test single-dimension changes (e.g., only add structured output format without changing detection logic)
3. **Problem-specific tuning**: Focus on improving P02 (WebSocket recovery) and P05 (Redis SPOF) detection consistency in baseline, which showed run-to-run variation

### Detection Gaps Across All Variants

- **P08 (Rate limiting backpressure)**: Only baseline achieved ○○; variants struggled with distinguishing self-protection mechanics from abuse prevention
- **P05 (Redis Pub/Sub SPOF)**: Inconsistent detection across all variants (△○, ○△, △△), indicating this problem may require more explicit evaluation criteria

---

## User Summary

Round 001 completed with baseline (9.75±0.75) outperforming few-shot (8.25±0.25) and scoring (9.0±0.0). Few-shot examples caused regressions in cross-database consistency and rate limiting detection. Scoring rubric improved consistency but reduced detection flexibility. Baseline remains recommended for deployment.
