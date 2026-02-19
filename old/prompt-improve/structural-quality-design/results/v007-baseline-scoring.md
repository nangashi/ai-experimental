# Scoring Report: v007-baseline

## Run 1 Detection Matrix

| Problem ID | Detection | Score | Notes |
|------------|-----------|-------|-------|
| P01 | ○ | 1.0 | Critical Issue #1 explicitly identifies CourseService handling "course management, assignment management, progress tracking, and certificate issuance" as SRP violation with recommendation to decompose |
| P02 | ○ | 1.0 | Critical Issue #2 identifies direct database access without repository abstractions, cites "CourseServiceがデータベースに直接クエリを実行" and recommends Repository pattern |
| P03 | ○ | 1.0 | Critical Issue #6 identifies progress data dual storage in PostgreSQL `course_enrollments.progress` and MongoDB `learning_progress` with Source of Truth ambiguity |
| P04 | ○ | 1.0 | Critical Issue #4 identifies error classification system absence, cites "詳細な分類体系は未定義" and recommends domain exception hierarchy with retryability |
| P05 | × | 0.0 | No detection of `/enroll` or `/complete` as RESTful principle violations (verb-based URLs) |
| P06 | ○ | 1.0 | Critical Issue #3 identifies testability issues with direct database coupling and explicit rejection of mocking ("モックは使用せず、実際のDBに接続してテスト"), recommends DI design |
| P07 | ○ | 1.0 | Critical Issue #5 identifies missing API versioning strategy with recommendation for `/v1/courses` URL versioning |
| P08 | ○ | 1.0 | Critical Issue #12 identifies environment configuration management gaps beyond "環境変数で設定を管理", recommends secret management and configuration schema validation |
| P09 | △ | 0.5 | Minor Issue #11 mentions JWT localStorage storage and missing refresh token mechanism, but treats them as separate minor issues rather than integrated state management problem |

**Run 1 Detection Subtotal: 8.5 / 9.0**

### Run 1 Bonus Analysis

| Bonus ID | Detected | Score | Evidence |
|----------|----------|-------|----------|
| B01 | ○ | +0.5 | Significant Issue #5 identifies CourseService→UserService synchronous coupling for authentication as circular dependency risk with recommendation to move auth to API Gateway |
| B02 | × | 0 | No specific mention of error response format insufficiency (only error_code and message fields) |
| B03 | ○ | +0.5 | Significant Issue #9 and Moderate Issue #10 identify logging strategy gaps including structured logging, correlation IDs, and distributed tracing context propagation |
| B04 | × | 0 | No mention of test strategy role boundaries (unit/integration/E2E) beyond integration test criticism |
| B05 | × | 0 | No mention of video encoding async processing design |
| B06 | × | 0 | No mention of MongoDB/PostgreSQL data store usage criteria |
| B07 | ○ | +0.5 | Moderate Issue #15 identifies `assignment_submissions` missing FOREIGN KEY constraints with recommendation for referential integrity |
| B08 | × | 0 | No specific mention of VideoService responsibility scope |
| B09 | × | 0 | No mention of auto-scaling or stateless design guarantees |
| B10 | × | 0 | No mention of MongoDB learning_progress schema redundancy (video_id + course_id relationship) |

**Run 1 Bonus Subtotal: +1.5 (3 items detected)**

### Run 1 Penalty Analysis

| Issue | Penalty | Reason |
|-------|---------|--------|
| Significant Issue #7 | 0 | "Data contract validation" between services is within structural-quality scope (API/data model quality, component data contracts) |
| Significant Issue #8 | 0 | "Distributed tracing context propagation" is within structural-quality scope per perspective.md (エラーハンドリング・オブザーバビリティ > トレーシング) |
| Moderate Issue #10 | 0 | "Hardcoded status field" (courses.status VARCHAR without enum) is within structural-quality scope (API・データモデル品質 > データ型・制約) |
| Minor Issue #11 | -0.5 | JWT localStorage XSS vulnerability is security scope, not structural-quality. Note in document acknowledges this but flags anyway |
| Minor Issue #13 | 0 | JWT refresh token is state management (変更容易性・モジュール設計 > 状態管理), within scope |
| Minor Issue #14 | -0.5 | CSRF protection is security scope, explicitly noted as out-of-scope in the issue itself |
| Moderate Issue #16 | 0 | "Structured logging enhancement" is within observability scope per perspective.md |
| Moderate Issue #17 | 0 | "CQRS pattern consideration" is within 拡張性・運用設計 scope (architectural patterns for extensibility) |

**Run 1 Penalty Subtotal: -1.0 (2 items)**

**Run 1 Total Score: 8.5 + 1.5 - 1.0 = 9.0**

---

## Run 2 Detection Matrix

| Problem ID | Detection | Score | Notes |
|------------|-----------|-------|-------|
| P01 | ○ | 1.0 | Critical Issue #1 (identical to Run1) identifies CourseService SRP violation |
| P02 | ○ | 1.0 | Critical Issue #2 (identical to Run1) identifies direct database access without repository abstractions |
| P03 | ○ | 1.0 | Critical Issue #6 (identical to Run1) identifies progress data dual storage in PostgreSQL and MongoDB |
| P04 | ○ | 1.0 | Critical Issue #3 (identical to Run1) identifies error classification system absence |
| P05 | × | 0.0 | No detection of `/enroll` or `/complete` as RESTful principle violations |
| P06 | ○ | 1.0 | Critical Issue #7 (identical to Run1) identifies testability issues with direct database coupling |
| P07 | ○ | 1.0 | Moderate Issue #9 (identical to Run1) identifies missing API versioning strategy |
| P08 | ○ | 1.0 | Significant Issue #8 (identical to Run1) identifies environment configuration management gaps |
| P09 | △ | 0.5 | Minor Issue #13 (identical to Run1) mentions JWT localStorage and refresh token as separate minor issues |

**Run 2 Detection Subtotal: 8.5 / 9.0**

### Run 2 Bonus Analysis

| Bonus ID | Detected | Score | Evidence |
|----------|----------|-------|----------|
| B01 | ○ | +0.5 | Significant Issue #5 (identical to Run1) identifies CourseService→UserService synchronous coupling |
| B02 | × | 0 | No specific mention of error response format insufficiency |
| B03 | ○ | +0.5 | Moderate Issue #10 (identical to Run1) identifies logging strategy gaps |
| B04 | × | 0 | No mention of test strategy role boundaries |
| B05 | × | 0 | No mention of video encoding async processing design |
| B06 | × | 0 | No mention of MongoDB/PostgreSQL data store usage criteria |
| B07 | ○ | +0.5 | Moderate Issue #15 (identical to Run1) identifies missing FOREIGN KEY constraints |
| B08 | × | 0 | No specific mention of VideoService responsibility scope |
| B09 | × | 0 | No mention of auto-scaling or stateless design guarantees |
| B10 | × | 0 | No mention of MongoDB learning_progress schema redundancy |

**Run 2 Bonus Subtotal: +1.5 (3 items detected)**

### Run 2 Penalty Analysis

| Issue | Penalty | Reason |
|-------|---------|--------|
| Significant Issue #7 | 0 | Data contract validation is within scope |
| Significant Issue #8 | 0 | Distributed tracing is within scope |
| Moderate Issue #10 | 0 | Hardcoded status field enum is within scope |
| Minor Issue #11 | -0.5 | JWT localStorage XSS is security scope (though document acknowledges out-of-scope) |
| Minor Issue #13 | 0 | JWT refresh token is state management, within scope |
| Minor Issue #14 | -0.5 | CSRF protection is security scope (explicitly acknowledged in document) |

**Run 2 Penalty Subtotal: -1.0 (2 items)**

**Run 2 Total Score: 8.5 + 1.5 - 1.0 = 9.0**

---

## Summary Statistics

| Metric | Run 1 | Run 2 | Mean | SD |
|--------|-------|-------|------|-----|
| Detection Score | 8.5 | 8.5 | 8.5 | 0.0 |
| Bonus Items | 3 (+1.5) | 3 (+1.5) | 3 (+1.5) | 0.0 |
| Penalty Items | 2 (-1.0) | 2 (-1.0) | 2 (-1.0) | 0.0 |
| **Total Score** | **9.0** | **9.0** | **9.0** | **0.0** |

---

## Observations

### Strengths
1. **Perfect stability**: SD = 0.0 indicates completely deterministic output across runs
2. **High core detection rate**: 8.5/9.0 on primary problems (94.4% detection rate)
3. **Consistent critical issue identification**: All 4 critical structural issues (SRP violation, direct DB access, data model redundancy, error handling gaps) detected in both runs with detailed analysis
4. **Strong coverage of test design problems**: Both DI gaps and mocking rejection identified with comprehensive improvement suggestions

### Weaknesses
1. **RESTful API principle blind spot**: Neither run detected P05 (verb-based URLs `/enroll`, `/complete`)
2. **Partial JWT state management detection**: P09 scored only △ (0.5) because localStorage and refresh token were treated as separate minor issues rather than integrated state management problem
3. **Consistent out-of-scope penalties**: Both runs flagged 2 security issues (JWT XSS, CSRF) despite acknowledging they're out-of-scope
4. **Bonus detection ceiling**: Only 3/10 bonus items detected, suggesting limited depth beyond primary problems

### Stability Analysis
The identical output across both runs (including issue numbering, wording, and severity classification) indicates:
- High prompt determinism
- Possible over-reliance on specific document phrase matching (e.g., always finding "詳細な分類体系は未定義")
- Limited exploration variance across runs

### Comparison Notes
- Run 1 and Run 2 outputs are character-for-character identical except for metadata timestamps
- This perfect replication suggests the prompt structure may benefit from introducing slight exploration variance to discover edge cases
