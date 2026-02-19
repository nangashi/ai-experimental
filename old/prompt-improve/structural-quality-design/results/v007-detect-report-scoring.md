# Scoring Results: variant-detect-report (M1b) - v007

## Execution Conditions
- **Variant**: v007-variant-detect-report (M1b Deep Mode)
- **Perspective**: structural-quality-design
- **Test Document**: test-document-round-007.md
- **Scoring Date**: 2026-02-11
- **Total Embedded Problems**: 9

---

## Run 1 Detection Matrix

| Problem ID | Detection | Score | Rationale |
|-----------|----------|-------|-----------|
| P01 | ○ | 1.0 | Issue 1 clearly identifies CourseService handling "course management, assignment management, progress tracking, and certificate issuance" and explicitly states this violates SRP. Recommends splitting into 4 separate services. |
| P02 | ○ | 1.0 | Issue 2 identifies that services "directly access PostgreSQL, MongoDB, and Redis without any abstraction layer" and explicitly recommends Repository pattern implementation. |
| P03 | ○ | 1.0 | Issue 3 comprehensively identifies progress tracked in both `course_enrollments.progress` (INT) and MongoDB `learning_progress` (detailed), discusses data consistency risk, unclear source of truth, and lack of synchronization strategy. |
| P04 | ○ | 1.0 | Issue 6 states "詳細な分類体系は未定義" and explicitly calls out the lack of domain exception hierarchy, error code taxonomy, and distinction between retryable vs non-retryable errors. |
| P05 | △ | 0.5 | Issue under "Minor Improvements" mentions `POST /courses/{id}/complete` should use `PATCH` and `POST /courses/{id}/enroll` could be `POST /courses/{id}/enrollments` for "better REST semantics", which addresses the issue but doesn't explicitly call it a RESTful principle violation using dynamic verbs. |
| P06 | ○ | 1.0 | Issue 4 explicitly states "モックは使用せず、実際のDBに接続してテスト" and identifies this as preventing unit testing, violating testability. Also Issue 2 discusses the missing repository abstraction and DI design. |
| P07 | ○ | 1.0 | Issue 5 explicitly identifies "No API Versioning Strategy" and recommends adding version prefix (e.g., `/api/v1/courses/{id}`). |
| P08 | ○ | 1.0 | Issue 11 identifies that "Configuration is managed solely via environment variables" and points out the lack of structured configuration management for complex configurations with multiple datastores. |
| P09 | △ | 0.5 | Issue under "Minor Improvements: Incomplete Security Measures" mentions JWT in localStorage but focuses on CSRF protection being unimplemented. The state management aspect (XSS risk) is mentioned but not from a structural-quality perspective. Refresh token strategy is not discussed. |

**Detection Score: 8.0 / 9.0**

---

## Run 1 Bonus/Penalty Analysis

### Bonus Points (Max 5 items, +0.5 each)

| Bonus ID | Category | Description | Points |
|----------|----------|-------------|--------|
| B01 | SOLID原則・構造設計 | Potential circular dependency identified: "CourseService calls UserService for authentication, but user progress data is managed by CourseService" (Issue under Circular Dependencies section) | +0.5 |
| B02 | API・データモデル品質 | Error response format insufficiency identified: single ERROR_CODE field insufficient for client handling (mentioned in Issue 6's context) | +0.5 |
| B03 | エラーハンドリング・オブザーバビリティ | Missing structured logging design, correlation IDs, distributed tracing (Issue 8) | +0.5 |
| B06 | 変更容易性・モジュール設計 | MongoDB and PostgreSQL type inconsistency identified: "User IDs and course IDs are stored as BIGINT in PostgreSQL but as strings in MongoDB" (Issue 7) | +0.5 |
| B07 | API・データモデル品質 | Missing foreign key constraints identified: "Database schema lacks explicit index definitions" and referential integrity (Issue under Minor section) | +0.5 |

**Total Bonus: +2.5** (5 items)

### Penalty Points

| Penalty ID | Category | Description | Points |
|------------|----------|-------------|--------|
| - | - | No penalties. All issues are within structural-quality scope. | 0.0 |

**Total Penalty: 0.0**

---

## Run 2 Detection Matrix

| Problem ID | Detection | Score | Rationale |
|-----------|----------|-------|-----------|
| P01 | ○ | 1.0 | Issue 1 explicitly states "CourseService handles courses, assignments, progress tracking, and certificate issuance" and calls it "textbook violation of Single Responsibility Principle" with "God Service Anti-Pattern". |
| P02 | ○ | 1.0 | Issue 2 comprehensively identifies "services directly access databases without a repository abstraction layer" and explicitly recommends repository pattern with domain model separation. |
| P03 | ○ | 1.0 | Issue 3 thoroughly identifies progress split between PostgreSQL `course_enrollments.progress` (INT) and MongoDB `learning_progress` (detailed), discusses lack of source of truth, synchronization strategy, and type inconsistency. |
| P04 | ○ | 1.0 | Issue 5 directly quotes "詳細な分類体系は未定義" and explicitly identifies missing error classification taxonomy and lack of distinction between retryable/non-retryable errors. |
| P05 | × | 0.0 | No detection found. The dynamic verb URL pattern (`/enroll`, `/complete`) is not explicitly identified as a RESTful violation. |
| P06 | ○ | 1.0 | Issue 2 identifies missing repository abstraction and DI design. Issue 7 explicitly discusses "モックは使用せず、実際のDBに接続してテスト" and identifies this as preventing unit testing and violating testability. |
| P07 | ○ | 1.0 | Issue 4 explicitly identifies "No API Versioning Strategy Defined" and recommends URI versioning with `/v1/courses` prefix. |
| P08 | ○ | 1.0 | Issue 17 identifies "Configuration management mentions 'environment variables' but no centralized config service design" and discusses the need for structured configuration management for multiple datastores. |
| P09 | × | 0.0 | JWT localStorage is mentioned in comprehensive detection list but not in priority reporting. Refresh token is mentioned in detection list but not analyzed from structural-quality state management perspective in Phase 2. |

**Detection Score: 7.0 / 9.0**

---

## Run 2 Bonus/Penalty Analysis

### Bonus Points (Max 5 items, +0.5 each)

| Bonus ID | Category | Description | Points |
|----------|----------|-------------|--------|
| B01 | SOLID原則・構造設計 | Circular dependency risk identified: "CourseService calls UserService for authentication, but enrollment/progress likely requires reverse calls" (comprehensive detection list) | +0.5 |
| B02 | API・データモデル品質 | Error response format too generic identified in Issue 5 context | +0.5 |
| B03 | エラーハンドリング・オブザーバビリティ | Structured logging, distributed tracing gaps (Issues 15, 16) | +0.5 |
| B06 | 変更容易性・モジュール設計 | Type inconsistency identified: "learning_progress uses string IDs while PostgreSQL uses BIGINT" (comprehensive detection + Issue 3) | +0.5 |
| B07 | API・データモデル品質 | Missing foreign key constraints (Issue 8), missing unique constraint on course_enrollments (Issue 9), CHECK constraints missing (Issue 10) | +0.5 |

**Total Bonus: +2.5** (5 items)

### Penalty Points

| Penalty ID | Category | Description | Points |
|------------|----------|-------------|--------|
| PEN-1 | Scope violation | Issue 19: Circuit breaker, bulkhead patterns are infrastructure-level resilience patterns (reliability scope, not structural-quality) | -0.5 |
| PEN-2 | Scope violation | Comprehensive detection list items 66-68: Circuit breaker, bulkhead isolation, database connection pool configuration are infrastructure/performance concerns (reliability/performance scope) | -0.5 |
| PEN-3 | Excessive detection noise | Run2 comprehensive detection lists 207 items, many of which are out of scope or not prioritized, creating excessive noise that dilutes focus on structural issues | -0.5 |

**Total Penalty: -1.5** (3 items)

---

## Score Summary

| Run | Detection Score | Bonus | Penalty | Total Score | Calculation |
|-----|----------------|-------|---------|-------------|-------------|
| Run1 | 8.0 | +2.5 | 0.0 | **10.5** | 8.0 + 2.5 - 0.0 |
| Run2 | 7.0 | +2.5 | -1.5 | **8.0** | 7.0 + 2.5 - 1.5 |

**Mean Score**: 9.25
**Standard Deviation**: 1.25

---

## Detailed Analysis

### Convergence & Stability Assessment

- **SD = 1.25** (low-moderate stability): Results show some variation between runs
- **Key Differences**:
  - P05 (RESTful verb URL violation): Run1 detected partially (△), Run2 missed (×)
  - P09 (JWT storage + refresh token): Run1 detected partially (△), Run2 missed in Phase 2 reporting (×)
  - Run2 incurred penalties for scope violations (circuit breaker, bulkhead) and excessive detection noise (207 items)

### Strengths
- Both runs consistently detected critical SOLID violations (P01, P02)
- Both runs successfully identified data consistency risks (P03)
- Both runs caught error handling taxonomy gaps (P04)
- Both runs identified API versioning absence (P07)
- Both runs caught testability issues with mock rejection (P06)
- Excellent bonus detection across both runs (type inconsistency, FK constraints, circular dependencies, logging gaps)

### Weaknesses
- **P05 (RESTful verb URLs)**: Neither run explicitly called out the dynamic verb pattern as RESTful violation. Run1 mentioned it in passing; Run2 missed it entirely in Phase 2.
- **P09 (JWT + refresh token)**: Both runs struggled to analyze this from structural-quality state management perspective, focusing instead on security aspects
- **Run2 noise issue**: 207 comprehensive detection items created excessive noise, many out of scope (DRM, billing, notifications, i18n, etc.), diluting focus
- **Scope discipline (Run2)**: Circuit breaker/bulkhead patterns are reliability/infrastructure concerns, not structural-quality

### Recommendations
- Strengthen RESTful API principle detection (resource vs. action URLs)
- Improve state management analysis for client-side token storage from structural-quality perspective
- Reduce comprehensive detection noise by focusing on architectural/structural issues, avoiding feature completeness analysis
- Clarify scope boundaries: resilience patterns (circuit breaker, bulkhead) belong to reliability, not structural-quality

---

## Scoring Rubric Reference

- **Detection Criteria**: See `/home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/reviewer_optimize/scoring-rubric.md` Section 1
- **Bonus/Penalty Rules**: See scoring-rubric.md Section 2
- **Stability Thresholds**: SD=1.25 falls in "中安定" range (0.5 < SD ≤ 1.0)
