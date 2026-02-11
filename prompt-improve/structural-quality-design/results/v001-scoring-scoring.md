# Scoring Report: v001-scoring vs v001-scoring

**Evaluation Date**: 2026-02-11
**Perspective**: structural-quality (design review)
**Baseline**: v001-scoring
**Variant**: v001-scoring
**Evaluator**: Phase 4 Scoring Agent

---

## Run 1 Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Evidence |
|-----------|----------|----------|-----------|-------|----------|
| P01 | SOLID原則 | 重大 | ○ | 1.0 | Section "C1. Severe Single Responsibility Principle Violation - LibraryService God Class" explicitly identifies LibraryService handling 5+ responsibilities and proposes splitting into LoanService, BookManagementService, ReservationService, ReportGenerationService |
| P02 | 外部依存 | 重大 | ○ | 1.0 | Section "C2. Critical Coupling - Direct Repository Access from Service Layer" identifies LibraryService accessing 4 repositories directly and recommends abstraction layer/domain service split |
| P03 | データモデル設計 | 重大 | ○ | 1.0 | Section "S2. Data Model Denormalization - Redundant Columns in loans Table" identifies user_name and book_title redundancy in loans table and recommends removal or intentional snapshot with clear semantics |
| P04 | API・データモデル品質 | 中 | ○ | 1.0 | Section "S1. API Design Violations - Non-RESTful Endpoints" identifies verb-based URLs (/api/borrowBook, /api/updateBook, /api/deleteBook) and proposes resource-based design (POST /api/loans, PUT /api/books/{id}) |
| P05 | テスト設計・テスタビリティ | 中 | △ | 0.5 | Section "M3. Incomplete Test Strategy - Missing Test Doubles Design" mentions LibraryService's 4 repository dependencies making unit tests complex, but does not explicitly call out missing DI design in architecture section |
| P06 | エラー・可観測性 | 中 | ○ | 1.0 | Section "M2. Unclear Error Classification Strategy" identifies that error handling mentions different error types but lacks specific classification taxonomy, recovery strategy, and client notification method |
| P07 | インターフェース契約 | 中 | ○ | 1.0 | Section "M1. Missing Versioning Strategy" identifies lack of API versioning (/api prefix without version) and recommends /api/v1/* with version policy |
| P08 | 変更影響・DRY | 中 | △ | 0.5 | Section "S3. Cross-Cutting Responsibility Violation" discusses authentication logic embedded in UserService causing change coupling, but does not specifically address notification function change propagation across multiple components |
| P09 | 設定管理 | 軽微 | ○ | 1.0 | Section "M4. Missing Configuration Management Details" identifies that deployment section only lists DATABASE_URL/REDIS_URL but lacks comprehensive environment-specific configuration management (SMTP, JWT, S3, log level, etc.) |
| P10 | エラー・可観測性 | 軽微 | △ | 0.5 | Section "I1. Logging Policy Lacks Structured Logging Specification" mentions logging section lacks structured logging (JSON format), distributed tracing, and PII masking, but less detailed than answer key requirements |

**Detection Subtotal**: 8.5/10

---

## Run 1 Bonus/Penalty Analysis

### Bonus Candidates

| ID | Category | Content | Bonus | Justification |
|----|----------|---------|-------|---------------|
| B1 | SOLID原則 | UserService also handles both user management and JWT generation (SRP violation) - Section "S3. Cross-Cutting Responsibility Violation - JWT Generation in UserService" | +0.5 | Matches B01: UserService responsibility separation proposed (AuthenticationService extraction) |
| B2 | YAGNI・過剰設計 | Section "3. Extensibility & Operational Design" mentions "No Plugin Architecture" - cannot add notification channels without modifying NotificationService | +0.5 | Matches B02: NotificationService abstraction proposed via NotificationChannel interface |
| B3 | インターフェース契約 | Section "S2" mentions "Missing Schema Evolution Strategy" - no discussion of database migration tools, backward compatibility | +0.5 | Matches B06: API/schema definition clarity (within perspective scope) |
| B4 | テスト戦略 | Section "M3" mentions E2E test strategy exists but lacks test data management details | +0.0 | Does not match B05 (E2E test scope undefined) - focuses on test data builders instead |

**Bonus Subtotal**: +1.5 (3 items)

### Penalty Candidates

None identified. All issues raised are within structural-quality scope.

**Penalty Subtotal**: -0.0 (0 items)

---

## Run 2 Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Evidence |
|-----------|----------|----------|-----------|-------|----------|
| P01 | SOLID原則 | 重大 | ○ | 1.0 | Section "1. SOLID Principles & Structural Design" / "LibraryService God Class (Severe SRP Violation)" identifies 6 responsibilities and proposes split into LoanManagementService, CollectionService, ReservationService, ReportingService |
| P02 | 外部依存 | 重大 | ○ | 1.0 | Section "1. SOLID Principles & Structural Design" / "Tight Repository Coupling" identifies direct access to 4 repositories and recommends domain service layer abstraction |
| P03 | データモデル設計 | 重大 | ○ | 1.0 | Section "6. API & Data Model Quality" / "Data Model Denormalization Issues" identifies user_name, book_title redundancy in loans table and proposes removal or documented performance justification |
| P04 | API・データモデル品質 | 中 | ○ | 1.0 | Section "6. API & Data Model Quality" / "Non-RESTful Endpoint Design" identifies verb-based URLs and proposes resource-based design (POST /api/loans, PUT /api/loans/{loanId}) |
| P05 | テスト設計・テスタビリティ | 中 | ○ | 1.0 | Section "5. Test Design & Testability" / "Dependency Injection Not Specified" explicitly states "design does not explicitly state Constructor injection vs field injection strategy" and recommends constructor-based DI |
| P06 | エラー・可観測性 | 中 | ○ | 1.0 | Section "4. Error Handling & Observability" / "Generic Exception Handling" identifies lack of error classification taxonomy (transient vs permanent, client vs server), retry policies, and compensation logic |
| P07 | インターフェース契約 | 中 | ○ | 1.0 | Section "6. API & Data Model Quality" / "No API Versioning Strategy" identifies lack of version prefix (/api without /v1/) and recommends versioning with deprecation policy |
| P08 | 変更影響・DRY | 中 | ○ | 1.0 | Section "2. Changeability & Module Design" / "Pervasive Cross-Component Coupling" provides concrete example: notification function change requires modifying NotificationService, LibraryService, UserService, and API endpoints; recommends domain events for cross-service coordination |
| P09 | 設定管理 | 軽微 | △ | 0.5 | Section "3. Extensibility & Operational Design" mentions extension points and configuration but does not specifically address environment-specific configuration management scope (only DATABASE_URL/REDIS_URL vs comprehensive list) |
| P10 | エラー・可観測性 | 軽微 | ○ | 1.0 | Section "4. Error Handling & Observability" / "Logging Design Deficiencies" explicitly mentions "No distributed tracing strategy (correlation IDs)", "No discussion of sensitive data masking (passwords, user PII)", and recommends structured logging (JSON format) |

**Detection Subtotal**: 9.5/10

---

## Run 2 Bonus/Penalty Analysis

### Bonus Candidates

| ID | Category | Content | Bonus | Justification |
|----|----------|---------|-------|---------------|
| B1 | SOLID原則 | Section "1. SOLID Principles" recommends "UserService → Split authentication into AuthenticationService (JWT generation, login) + UserProfileService (registration, profile updates)" | +0.5 | Matches B01: UserService responsibility separation |
| B2 | 外部依存 | Section "3. Extensibility & Operational Design" / "No Plugin Architecture" states "Cannot add new notification channels (SMS, push notifications) without modifying NotificationService" and proposes NotificationChannel interface | +0.5 | Matches B02: NotificationService abstraction |
| B3 | インターフェース契約 | Section "6. API & Data Model Quality" / "Missing Schema Evolution Strategy" identifies "No discussion of Database migration tools (Flyway, Liquibase), Backward compatibility for schema changes" | +0.5 | Matches B06: API/schema definition clarity |
| B4 | YAGNI・過剰設計 | Section "3. Extensibility & Operational Design" / "Monolithic Incremental Implementation Barrier" discusses deployment independence issues | +0.0 | Does not match B04 (over-abstraction for current requirements) - focuses on deployment modularity instead |
| B5 | データモデル設計 | Section "2. Changeability & Module Design" / "Unstable State Management" mentions "Transaction boundary strategy not specified" and "Document state mutation ownership (who owns book.available_copies updates?)" | +0.0 | Partially related to B03 (available_copies computed from loans) but does not explicitly call it out as redundancy - no bonus |

**Bonus Subtotal**: +1.5 (3 items)

### Penalty Candidates

None identified. All issues raised are within structural-quality scope.

**Penalty Subtotal**: -0.0 (0 items)

---

## Score Calculation

### Run 1
- Detection Score: 8.5
- Bonus: +1.5 (3 items)
- Penalty: -0.0 (0 items)
- **Run 1 Total**: 8.5 + 1.5 - 0.0 = **10.0**

### Run 2
- Detection Score: 9.5
- Bonus: +1.5 (3 items)
- Penalty: -0.0 (0 items)
- **Run 2 Total**: 9.5 + 1.5 - 0.0 = **11.0**

### Summary Statistics
- **Mean Score**: (10.0 + 11.0) / 2 = **10.5**
- **Standard Deviation**: sqrt(((10.0-10.5)² + (11.0-10.5)²) / 2) = sqrt(0.25) = **0.5**
- **Stability Assessment**: SD = 0.5 → **高安定** (結果が信頼できる)

---

## Comparative Analysis

### Run Differences

**Run 1 Strengths**:
- More detailed section structure with Critical/Significant/Moderate tiering
- Provides explicit refactoring cost estimates and impact analysis percentages
- Includes "Positive Aspects" section highlighting strengths

**Run 2 Strengths**:
- More complete detection of P05 (DI design) and P08 (change propagation) - full score instead of partial
- More complete detection of P10 (logging design) - explicitly mentions all three aspects (tracing, PII masking, structured logging)
- Provides concrete example scenario for P08 (adding new loan type requires 6 component changes)

**Key Difference**: Run 2 provides more explicit and complete detection of moderate-severity issues (P05, P08, P10), leading to 1.0pt higher detection score.

### Stability Analysis

- SD = 0.5 is within "高安定" threshold (SD ≤ 0.5)
- Both runs detected the same bonus issues (UserService SRP, NotificationService abstraction, schema evolution)
- Core structural issues (P01, P02, P03, P04, P06, P07) detected consistently across both runs
- Variation comes from partial vs full detection of 3 moderate/minor issues (P05, P08, P10)

---

## Conclusion

The variant prompt **v001-scoring** demonstrates high stability (SD=0.5) and strong overall performance (Mean=10.5), detecting all 10 embedded problems with 9/10 achieving full or partial detection in Run 1 and all 10 detected in Run 2. The variant also consistently identified 3 valuable bonus issues across both runs. This indicates a robust structural analysis capability with reliable output quality.
