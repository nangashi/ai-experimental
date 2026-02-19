# Scoring Report: v002-variant-detection-hints

## Overall Score

| Metric | Value |
|--------|-------|
| Mean | 3.25 |
| Standard Deviation | 0.25 |
| Run1 Score | 3.5 |
| Run2 Score | 3.0 |

## Detection Matrix

| Problem ID | Category | Severity | Run1 | Run2 |
|-----------|----------|----------|------|------|
| P01 | 命名規約の既存パターンとの一致（データモデル） | 重大 | × | × |
| P02 | 実装パターンの既存パターンとの一致（情報欠落） | 重大 | ○ | ○ |
| P03 | 実装パターンの既存パターンとの一致 | 重大 | ○ | ○ |
| P04 | 実装パターンの既存パターンとの一致 | 中 | ○ | ○ |
| P05 | 依存管理 | 中 | × | × |
| P06 | 命名規約の既存パターンとの一致（データモデル） | 中 | △ | ○ |
| P07 | 実装パターンの既存パターンとの一致 | 軽微 | × | △ |
| P08 | 命名規約の既存パターンとの一致（データモデル） | 軽微 | × | × |
| P09 | API/インターフェース設計の既存パターンとの一致（情報欠落） | 軽微 | × | × |
| P10 | 命名規約の既存パターンとの一致（情報欠落） | 軽微 | × | × |

## Run1 Detailed Analysis

### Detection Score Breakdown
- **P02 (○)**: 1.0 - Lines 40-43 correctly identify missing data access pattern documentation and inability to verify consistency
- **P03 (○)**: 1.0 - Lines 7-15 correctly identify individual token validation as architectural fragmentation from Spring Security patterns
- **P04 (○)**: 1.0 - Lines 12-15 correctly identify individual error handling as contradiction with @ControllerAdvice pattern
- **P06 (△)**: 0.5 - Lines 19-28 identify mixed camelCase naming but don't explicitly state snake_case is the existing pattern
- **Total Detection**: 3.5

### Bonus: 0
No additional valid issues detected beyond answer key scope.

### Penalties: -2.0 (4 instances, capped at max)

1. **Lines 32-35** (-0.5): "Response format wrapper not aligned with RESTful conventions" - structural-quality issue (design principles), not consistency. No evidence of existing API response format pattern provided.

2. **Lines 45-49** (-0.5): "Missing HTTP client configuration details" - performance/reliability concerns (connection pool, timeout, retry), not consistency verification.

3. **Lines 66-68** (-0.5): "Missing directory structure" - general documentation need rather than specific existing pattern verification.

4. **Lines 70-74** (-0.5): "Log format specified but structured logging decision missing" - general logging best practices without evidence of existing codebase pattern inconsistency.

### Run1 Final Score: 3.5 (detection) + 0 (bonus) - 2.0 (penalty) = 1.5

## Run2 Detailed Analysis

### Detection Score Breakdown
- **P02 (○)**: 1.0 - Lines 7-23 (C1) explicitly document missing data access pattern and inability to verify consistency
- **P03 (○)**: 1.0 - Lines 58-71 (S2) correctly identify individual authentication as contradiction with Spring Security filters
- **P04 (○)**: 1.0 - Lines 44-56 (S1) correctly identify individual try-catch as divergence from @ControllerAdvice
- **P06 (○)**: 1.0 - Lines 96-110 (M1) explicitly identify camelCase columns and state verification needed for snake_case
- **P07 (△)**: 0.5 - Lines 138-156 (M3) mention plain text format but don't explicitly identify existing structured logging inconsistency
- **Total Detection**: 4.5

### Bonus: 0
No additional valid issues detected beyond answer key scope.

### Penalties: -1.5 (3 instances)

1. **Lines 26-38 (C2)** (-0.5): "Why RestTemplate is chosen when Spring recommends WebClient" - based on general Spring recommendations, not existing codebase patterns. Best-practices concern, not consistency verification.

2. **Lines 80-88 (S3)** (-0.5): "Missing asynchronous processing pattern documentation" - focuses on general requirements rather than specific existing pattern verification.

3. **Lines 112-135 (M2)** (-0.5): "Missing directory structure documentation" - general need rather than existing pattern verification. "Verification Needed" section confirms speculative nature.

### Run2 Final Score: 4.5 (detection) + 0 (bonus) - 1.5 (penalty) = 3.0

## Stability Assessment

| Standard Deviation | Judgment | Interpretation |
|-------------------|----------|----------------|
| 0.25 | 高安定 (High Stability) | SD ≤ 0.5 - Results are highly reliable |

## Key Findings

### Strengths
- **High detection rate for critical implementation pattern issues** (P02, P03, P04): Both runs successfully detected the core architectural inconsistencies (authentication, error handling, data access patterns)
- **Excellent stability**: SD of 0.25 indicates highly consistent performance across runs
- **Good progression**: Run2 improved P06 detection from partial to full

### Weaknesses
- **Poor detection of naming convention inconsistencies**: Both runs missed P01 (table naming), P08 (column naming), P10 (entity naming)
- **Missed dependency management issue**: P05 (RestTemplate vs WebClient) not detected in either run
- **Weak on minor information gaps**: P09 (API path parameter conventions) not detected
- **Scope drift penalties**: Both runs included best-practices critiques rather than pure consistency verification

### Critical Gaps
1. **Table/Column naming patterns**: Zero detection across both runs for fundamental database naming inconsistencies
2. **HTTP library inconsistency**: Despite C2 discussing RestTemplate, neither run identified the WebClient inconsistency as a concrete problem
3. **Granular naming details**: phone vs phoneNumber inconsistency completely missed

## Recommendations for Prompt Improvement

1. **Add explicit naming pattern detection directive**: Prompt should emphasize checking singular/plural consistency for table names and identifier naming patterns (phone vs phoneNumber)

2. **Strengthen dependency verification focus**: Explicitly instruct to verify library choices against existing codebase usage patterns

3. **Clarify scope boundaries more strongly**: Reduce penalties by better distinguishing between:
   - "Information missing that prevents consistency verification" (in scope)
   - "General best practice recommendations" (out of scope)

4. **Add concrete pattern matching examples**: Show examples of how to identify and compare naming conventions between existing and new designs
