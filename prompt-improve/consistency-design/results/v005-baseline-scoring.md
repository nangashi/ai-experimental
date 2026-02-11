# Scoring Report: v005-baseline

**Prompt**: v005-baseline
**Perspective**: consistency
**Target**: design
**Scoring Date**: 2026-02-11

---

## Run 1 Detection Matrix

| Problem ID | Status | Score | Evidence |
|------------|--------|-------|----------|
| P01 | ○ | 1.0 | Section 1.1 explicitly identifies mixed PascalCase/snake_case in table names (Patients, Questionnaires vs medical_institutions, appointment) |
| P02 | × | 0.0 | No specific detection of column naming inconsistencies. The review mentions camelCase/snake_case inconsistency but focuses on API-DB layer mismatch, not within database schema itself |
| P03 | △ | 0.5 | Section 5.3 mentions RestTemplate but frames it as deprecated/maintenance mode issue rather than existing pattern verification. Does not explicitly ask "is this consistent with existing HTTP client choice?" |
| P04 | ○ | 1.0 | Section 5.2 explicitly identifies that API response format lacks documentation of existing pattern alignment and creates inconsistency risk |
| P05 | ○ | 1.0 | Section 3.1 explicitly identifies error handling pattern (individual try-catch) contradicts framework best practices and notes lack of existing pattern documentation |
| P06 | ○ | 1.0 | Section 4.1 explicitly identifies missing directory structure documentation as critical omission |
| P07 | △ | 0.5 | Section 3.4 mentions incomplete logging pattern documentation but focuses on MDC/structured fields rather than existing pattern alignment verification |
| P08 | ○ | 1.0 | Section 2.1 Minor Issue explicitly identifies missing transaction management pattern documentation |
| P09 | × | 0.0 | Section 5.1 notes API endpoints are consistent but does not identify missing documentation of existing pattern or ask for verification against existing APIs |
| P10 | △ | 0.5 | Section 3.2 mentions token storage (HTTP-only Cookie) but frames it as "client-side handling unclear" rather than existing pattern verification |

**Detection Subtotal**: 6.5 / 10.0

---

## Run 1 Bonus/Penalty Analysis

### Bonus Candidates

| ID | Category | Description | Decision | Reason |
|----|----------|-------------|----------|---------|
| B01 | Naming | Section 1.3 identifies undocumented file naming convention (Controller/Service/Repository pattern not explicit) | ✓ +0.5 | Matches B01 - class/interface naming rules missing |
| B02 | Validation | Section 3.3 mentions Jakarta Validation but notes pattern is undocumented | ✓ +0.5 | Matches B02 - validation library pattern verification |
| B03 | API | Section 5.1 notes `/api/v1/` versioning but does not ask if this matches existing | × 0 | Does not meet B03 - no verification of existing pattern |
| B04 | Config | Section 5.4 identifies missing environment variable naming convention | ✓ +0.5 | Matches B04 - environment variable naming missing |
| B05 | Async | Section 2.1 mentions lack of cross-cutting concerns doc including caching but not async | × 0 | Does not match B05 - async not explicitly mentioned |
| Extra-1 | Dependency | Section 2.2 mentions cross-cutting concerns (transaction, caching, security) lack documentation | ✓ +0.5 | Valid consistency issue - implementation patterns missing |
| Extra-2 | API | Section 1.2 identifies camelCase/snake_case inconsistency between API JSON and DB schema | ✓ +0.5 | Valid consistency issue - serialization convention missing |

**Bonus Total**: +2.5 (5 items)

### Penalties

| ID | Description | Decision | Reason |
|----|-------------|----------|---------|
| None detected | All issues fall within consistency scope | No penalties | - |

**Penalty Total**: 0

---

## Run 2 Detection Matrix

| Problem ID | Status | Score | Evidence |
|------------|--------|-------|----------|
| P01 | ○ | 1.0 | "CRITICAL: Inconsistent Table Naming Convention" explicitly identifies mixed styles (PascalCase `Patients`, snake_case `medical_institutions`, etc.) |
| P02 | × | 0.0 | No specific detection of column naming pattern inconsistencies within database schema |
| P03 | △ | 0.5 | "MODERATE: Library Selection Rationale Not Documented" mentions RestTemplate but focuses on deprecated status rather than existing pattern verification |
| P04 | △ | 0.5 | "SIGNIFICANT: Response Format Inconsistency Risk" notes missing documentation but does not explicitly state need to verify existing API pattern |
| P05 | ○ | 1.0 | "CRITICAL: Inconsistent Error Handling Pattern" explicitly identifies individual try-catch approach and notes lack of existing pattern documentation |
| P06 | ○ | 1.0 | "CRITICAL: No Directory Structure Specified" explicitly identifies missing directory/file placement documentation |
| P07 | × | 0.0 | Logging section mentions JSON format and levels but does not identify missing existing pattern documentation |
| P08 | ○ | 1.0 | "SIGNIFICANT: Transaction Management Pattern Not Specified" explicitly identifies missing transaction pattern documentation |
| P09 | × | 0.0 | "MODERATE: REST Maturity Level Not Specified" discusses RPC vs REST but does not identify missing existing endpoint naming convention verification |
| P10 | × | 0.0 | Section 5 mentions JWT token management is "well-documented" but does not identify missing existing pattern verification for storage location |

**Detection Subtotal**: 5.5 / 10.0

---

## Run 2 Bonus/Penalty Analysis

### Bonus Candidates

| ID | Category | Description | Decision | Reason |
|----|----------|-------------|----------|---------|
| B01 | Naming | "MODERATE: Component Naming Pattern Not Documented" - identifies missing {Domain}{LayerType} pattern documentation | ✓ +0.5 | Matches B01 - class naming convention missing |
| B02 | Validation | "MODERATE: Validation Pattern Unclear" - notes Jakarta Validation listed but usage pattern not specified | ✓ +0.5 | Matches B02 - validation library consistency |
| B03 | API | "MODERATE: REST Maturity Level Not Specified" - mentions versioning beyond URL prefix | ✓ +0.5 | Matches B03 - API versioning consistency |
| B04 | Config | "SIGNIFICANT: Configuration File Locations Not Specified" - mentions environment variable mapping strategy | ✓ +0.5 | Matches B04 - environment variable naming |
| B05 | Async | "SIGNIFICANT: Async Pattern Not Documented" - explicitly identifies missing async processing pattern | ✓ +0.5 | Matches B05 - async pattern missing |
| Extra-1 | Dependency | "MODERATE: Dependency Direction Not Explicitly Documented" - DI patterns not specified | ✓ +0.5 | Valid consistency issue - implementation pattern gap |
| Extra-2 | Language | "Issue 1: Documentation Language Inconsistency" - Japanese vs English policy unclear | ✓ +0.5 | Valid consistency issue - language convention missing |
| Extra-3 | Database | "SIGNIFICANT: Mixed Language Usage in Field Names" - "内科" Japanese value in API request | ✓ +0.5 | Valid consistency issue - i18n pattern unclear |

**Bonus Total**: +4.0 (8 items, but capped at 5 items = +2.5)

### Penalties

| ID | Description | Decision | Reason |
|----|-------------|----------|---------|
| None detected | All issues fall within consistency scope | No penalties | - |

**Penalty Total**: 0

---

## Score Calculation

### Run 1
- Detection Score: 6.5
- Bonus: +2.5 (5 items)
- Penalty: -0
- **Run 1 Total**: 9.0

### Run 2
- Detection Score: 5.5
- Bonus: +2.5 (8 items detected, capped at 5)
- Penalty: -0
- **Run 2 Total**: 8.0

### Aggregate Metrics
- **Mean**: (9.0 + 8.0) / 2 = **8.5**
- **Standard Deviation**: sqrt(((9.0-8.5)² + (8.0-8.5)²) / 2) = sqrt(0.5) = **0.71**

---

## Stability Assessment

**SD = 0.71** → **Medium Stability** (0.5 < SD ≤ 1.0)

The results show moderate consistency between runs. Run 1 achieved slightly higher detection rate (6.5 vs 5.5) and identified slightly fewer bonus items (5 vs 8, both capped at 5). The primary variance comes from:
- P04 detection (○ in Run1, △ in Run2)
- P10 detection (△ in Run1, × in Run2)
- P07 detection (△ in Run1, × in Run2)
- Different bonus items identified across runs

---

## Qualitative Analysis

### Strengths
- Both runs consistently detected critical naming convention issues (P01)
- Both runs identified missing directory structure documentation (P06)
- Both runs caught error handling pattern inconsistency (P05)
- Both runs detected missing transaction management documentation (P08)
- Strong bonus detection in both runs (2.5 points added in each)

### Weaknesses
- Neither run detected P02 (column naming within database schema)
- Neither run properly detected P09 (API endpoint naming convention verification)
- Neither run fully detected P10 (token storage pattern verification)
- P03, P04, P07 inconsistently detected (partial or missing)

### Run-to-Run Differences
- Run 1 had broader coverage of partial detections (3× △ scores)
- Run 2 had fewer partial detections but identified more bonus items (8 vs 5)
- Run 1 better caught API response format issue (P04: ○ vs △)
- Run 2 better structured recommendations by priority levels

### Overall Assessment
The v005-baseline prompt shows good detection capability for major consistency issues but struggles with nuanced detection of:
1. Column-level naming convention verification within database schemas
2. Explicit framing of issues as "existing pattern verification" requirements
3. Consistent depth of analysis across all embedded problems

The 0.71 SD indicates acceptable but improvable stability. The mean score of 8.5 is strong, driven by good core problem detection plus substantial bonus coverage.
