# Scoring Results: v010-baseline

## Run 1 Scoring

### Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Notes |
|-----------|----------|----------|-----------|-------|-------|
| P01 | 命名規約 | 重大 | ○ | 1.0 | M-1: `tracking_event` (singular) vs documented plural pattern explicitly identified |
| P02 | 命名規約 | 中 | ○ | 1.0 | S-3: All three timestamp patterns identified (`created_at`, `createdAt`, `created_timestamp`) |
| P03 | 命名規約 | 中 | ○ | 1.0 | S-4: `delivery_order_fk` with `_fk` suffix vs `_id` pattern explicitly identified |
| P04 | API設計 | 中 | ○ | 1.0 | S-1: `/api/v1/deliveryOrders` camelCase vs kebab-case pattern explicitly identified |
| P05 | API設計 | 軽微 | △ | 0.5 | M-2: Mentions action-based naming but doesn't clearly state verb usage vs resource-oriented pattern |
| P06 | 依存管理 | 中 | ○ | 1.0 | C-1: Spring WebFlux vs RestTemplate explicitly identified |
| P07 | 実装パターン | 重大 | ○ | 1.0 | C-2: Individual try-catch vs @ControllerAdvice global handler explicitly identified |
| P08 | 実装パターン | 軽微 | ○ | 1.0 | C-3: Plain text vs structured JSON logging explicitly identified |
| P09 | API設計 | 重大 | ○ | 1.0 | S-2: `{success, result}` vs `{data, error}` format explicitly identified |
| P10 | 実装パターン | 中 | △ | 0.5 | I-1: Mentions localStorage and cookie ambiguity but doesn't clearly state consistency verification needed |

**Detection Score**: 8.0 + 1.0 = 9.0

### Bonus Issues

| ID | Description | Category | Justification |
|----|-------------|----------|---------------|
| B03 | Async processing pattern consistency | 実装パターン | M-3: Identifies that `LocationUpdateProcessor` doesn't specify if it follows existing `@Async` + `CompletableFuture` pattern |

**Bonus Score**: +0.5 (1 issue)

### Penalties

None detected.

**Penalty Score**: 0

### Run 1 Total Score

**Detection**: 9.0
**Bonus**: +0.5
**Penalty**: -0
**Total**: 9.5

---

## Run 2 Scoring

### Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Notes |
|-----------|----------|----------|-----------|-------|-------|
| P01 | 命名規約 | 重大 | ○ | 1.0 | Issue #6: Singular table names (`delivery_order`, `tracking_event`, `carrier`) vs documented plural pattern |
| P02 | 命名規約 | 中 | ○ | 1.0 | Issue #7: All three timestamp patterns identified across tables |
| P03 | 命名規約 | 中 | ○ | 1.0 | Issue #8: `delivery_order_fk` with `_fk` suffix vs `{table}_id` pattern |
| P04 | API設計 | 中 | ○ | 1.0 | Issue #5: `/api/v1/deliveryOrders` camelCase vs documented kebab-case pattern |
| P05 | API設計 | 軽微 | △ | 0.5 | Issue #5: Mentions action verbs in path but focus is on camelCase rather than verb vs resource-oriented |
| P06 | 依存管理 | 中 | ○ | 1.0 | Issue #1: Spring WebFlux vs RestTemplate explicitly identified |
| P07 | 実装パターン | 重大 | ○ | 1.0 | Issue #2: Individual try-catch blocks vs @ControllerAdvice explicitly identified |
| P08 | 実装パターン | 軽微 | ○ | 1.0 | Issue #4: Plain text logging vs structured JSON with MDC explicitly identified |
| P09 | API設計 | 重大 | ○ | 1.0 | Issue #3: Proposed response format vs existing `{data, error}` pattern |
| P10 | 実装パターン | 中 | △ | 0.5 | Issue #12: Mentions JWT refresh mechanism missing but doesn't clearly state existing pattern verification needed |

**Detection Score**: 8.0 + 1.0 = 9.0

### Bonus Issues

None detected that match the defined bonus criteria.

**Bonus Score**: 0

### Penalties

None detected.

**Penalty Score**: 0

### Run 2 Total Score

**Detection**: 9.0
**Bonus**: +0
**Penalty**: -0
**Total**: 9.0

---

## Statistical Summary

| Metric | Value |
|--------|-------|
| Mean Score | 9.25 |
| Standard Deviation | 0.25 |
| Run 1 Score | 9.5 |
| Run 2 Score | 9.0 |
| Stability | High (SD ≤ 0.5) |

---

## Detailed Analysis

### Common Detections (Both Runs)

All 10 embedded problems were detected by both runs, with 8 problems receiving full marks (○) and 2 receiving partial marks (△) consistently.

**Fully Detected (8/10)**:
- P01: Table naming inconsistency (singular vs plural)
- P02: Timestamp column naming inconsistency
- P03: Foreign key naming pattern violation
- P04: API endpoint naming case inconsistency
- P06: HTTP client library divergence
- P07: Error handling pattern inconsistency
- P08: Logging format inconsistency
- P09: API response format inconsistency

**Partially Detected (2/10)**:
- P05: Action-based endpoint naming (△) - Both runs identified the endpoint but didn't clearly articulate the core issue of verb usage vs resource-oriented pattern
- P10: JWT storage pattern verification (△) - Both runs mentioned JWT-related gaps but didn't clearly state the need to verify consistency with existing JWT storage pattern

### Score Differences

Run 1 achieved a slightly higher score (9.5 vs 9.0) due to detecting one bonus issue:
- **B03**: Async processing pattern consistency verification (M-3 in Run1) - Identified that `LocationUpdateProcessor` doesn't specify if it follows existing `@Async` + `CompletableFuture` pattern

Run 2 did not detect any bonus issues beyond the core 10 embedded problems.

### Quality Assessment

**Strengths**:
- Consistent detection of all embedded problems across both runs
- High accuracy in identifying critical implementation pattern inconsistencies (P06, P07, P08, P09)
- Strong detection of naming convention violations (P01, P02, P03, P04)
- Clear articulation of pattern evidence and impact analysis

**Weaknesses**:
- P05 (action-based endpoint naming): Both runs identified the problematic endpoint but didn't clearly emphasize the verb usage as the core consistency violation
- P10 (JWT storage verification): Both runs identified JWT-related gaps but framed it more as missing documentation rather than a consistency verification gap
- Run 2 missed the async processing pattern bonus that Run 1 detected

**Stability**: Excellent (SD = 0.25) - Results are highly consistent between runs, with only minor variation in bonus issue detection.
