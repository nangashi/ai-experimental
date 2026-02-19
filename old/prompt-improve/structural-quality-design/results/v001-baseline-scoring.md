# Scoring Results: baseline

## Run 1 Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Notes |
|------------|----------|----------|-----------|-------|-------|
| P01 | SOLID原則 | 重大 | ○ | 1.0 | C-1 "Massive Single Responsibility Principle Violation in LibraryService" - explicitly identifies 5+ distinct responsibilities and proposes service separation into BookLendingService, CollectionManagementService, ReservationService, ReportingService, AuthenticationService |
| P02 | 外部依存 | 重大 | ○ | 1.0 | C-3 "Tight Coupling Between Service and Repository Layers" - identifies direct repository access and proposes abstraction layer with dependency inversion principle |
| P03 | データモデル設計 | 重大 | ○ | 1.0 | C-4 "Data Model Denormalization Without Justification" - specifically identifies user_name and book_title as redundant data in loans table, proposes normalization or documented justification |
| P04 | API・データモデル品質 | 中 | ○ | 1.0 | S-2 "RESTful Design Violations" - identifies verb-based endpoints (/updateBook, /deleteBook, /getUser) and proposes resource-based REST design |
| P05 | テスト設計・テスタビリティ | 中 | ○ | 1.0 | S-4 "Unclear Dependency Injection and Testability Design" - identifies DI design absence and proposes constructor-based injection for mockability |
| P06 | エラー・可観測性 | 中 | ○ | 1.0 | S-3 "Missing Error Classification and Propagation Strategy" - identifies lack of error taxonomy, retry policies, and client response format |
| P07 | インターフェース契約 | 中 | ○ | 1.0 | S-1 "No Clear API Versioning Strategy" - identifies missing version indicators in /api/ prefix and proposes URL-based or content negotiation versioning |
| P08 | 変更影響・DRY | 中 | △ | 0.5 | Partial detection: C-3 and C-1 mention coupling issues, but do not specifically identify the cross-component notification change propagation scenario described in P08 |
| P09 | 設定管理 | 軽微 | ○ | 1.0 | M-1 "Insufficient Configuration Management for Multi-Environment" - identifies limited scope of environment variables and proposes comprehensive configuration strategy |
| P10 | エラー・可観測性 | 軽微 | ○ | 1.0 | M-3 "Observability Gaps" - identifies missing distributed tracing, correlation IDs, and metrics (directly addresses logging design gaps including structured logging and tracing) |

**Detection Subtotal: 9.5/10**

## Run 1 Bonus/Penalty Analysis

### Bonus Items
1. **S-5 "Missing State Management and Concurrency Control"** (+0.5): Identifies concurrent booking scenarios, state transitions, and optimistic/pessimistic locking strategy - valid structural quality concern not in answer key
2. **C-2 "Unauthorized Cross-Service Responsibility Overlap"** (+0.5): Identifies authentication responsibility split between LibraryService and UserService - valid SOLID principle violation (duplicate responsibility)
3. **M-2 "No Extension Points for Future Requirements"** (+0.5): Identifies lack of plugin interfaces for notification channels and strategy patterns - valid extensibility design concern
4. **MI-1 "Schema Evolution Strategy Undefined"** (+0.5): Identifies missing database migration strategy (Flyway/Liquibase) - valid data model evolution concern
5. **MI-2 "API Request/Response Examples Incomplete"** (+0.5): Identifies missing error response examples and edge case documentation - valid API contract quality concern

**Bonus Subtotal: +2.5 (5 items, within 5-item cap)**

### Penalty Items
None detected. All issues raised are within structural-quality scope.

**Penalty Subtotal: 0**

## Run 1 Total Score
**9.5 (detection) + 2.5 (bonus) - 0 (penalty) = 12.0**

---

## Run 2 Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Notes |
|------------|----------|----------|-----------|-------|-------|
| P01 | SOLID原則 | 重大 | ○ | 1.0 | Issue #1 "Massive Single Responsibility Principle Violation in LibraryService" - identifies 6 distinct responsibilities and proposes separation into LoanService, BookInventoryService, ReservationService, ReportService |
| P02 | 外部依存 | 重大 | ○ | 1.0 | Issue #5 "Unclear Module Boundary Between Data Access and Business Logic" - identifies direct repository coupling and proposes Repository Interface Layer abstraction |
| P03 | データモデル設計 | 重大 | ○ | 1.0 | Issue #3 "Data Model Denormalization Without Justification" - specifically identifies user_name and book_title redundancy in loans table, proposes normalization or documented freeze strategy |
| P04 | API・データモデル品質 | 中 | ○ | 1.0 | Issue #4 "API Design Inconsistency: Mixed REST and RPC Styles" - identifies verb-based endpoints (borrowBook, updateProfile, deleteBook/{id} using POST) and proposes consistent REST design |
| P05 | テスト設計・テスタビリティ | 中 | △ | 0.5 | Issue #9 "Test Strategy Lacks Clear Scope Definition" mentions mocking strategy but does not explicitly address DI design architecture gap (constructor injection, interface-based design) |
| P06 | エラー・可観測性 | 中 | ○ | 1.0 | Issue #6 "Missing Error Classification and Recovery Strategy" - identifies lack of error hierarchy, retry strategy, transaction boundaries, and idempotency guarantees |
| P07 | インターフェース契約 | 中 | × | 0.0 | No detection of API versioning strategy absence |
| P08 | 変更影響・DRY | 中 | × | 0.0 | No specific detection of notification change propagation scenario |
| P09 | 設定管理 | 軽微 | ○ | 1.0 | Issue #7 "Configuration Management Strategy Insufficient for Multi-Environment" - identifies limited environment variable scope and proposes comprehensive configuration/secrets management |
| P10 | エラー・可観測性 | 軽微 | ○ | 1.0 | Issue #11 "Logging Policy Missing Structured Logging and Sensitive Data Handling" - directly addresses structured logging, sensitive data masking, and retention policy |

**Detection Subtotal: 7.5/10**

## Run 2 Bonus/Penalty Analysis

### Bonus Items
1. **Issue #2 "Authentication Responsibility Misplacement"** (+0.5): Identifies duplicate authentication claims between LibraryService and UserService - valid SOLID/responsibility assignment concern
2. **Issue #8 "JWT Token Management Design Incomplete"** (+0.5): Identifies missing refresh token strategy, revocation mechanism, and client-side storage security - valid API/security design concern (though closer to security boundary, token lifecycle management is architectural design)
3. **Issue #10 "Missing Schema Versioning and Migration Strategy"** (+0.5): Identifies lack of Flyway/Liquibase for schema evolution - valid data model management concern
4. **Issue #9 sub-point on test pyramid** (+0.5): Proposes explicit test pyramid percentages and coverage goals - valid test strategy elaboration (though main issue was partially credited for P05)

**Bonus Subtotal: +2.0 (4 items)**

### Penalty Items
None detected. All issues are within structural-quality scope (even JWT token management is treated as API lifecycle design rather than pure security).

**Penalty Subtotal: 0**

## Run 2 Total Score
**7.5 (detection) + 2.0 (bonus) - 0 (penalty) = 9.5**

---

## Summary Statistics

| Metric | Run 1 | Run 2 |
|--------|-------|-------|
| Detection Score | 9.5/10 | 7.5/10 |
| Bonus | +2.5 | +2.0 |
| Penalty | 0 | 0 |
| **Total Score** | **12.0** | **9.5** |
| **Mean** | | **10.75** |
| **Standard Deviation** | | **1.25** |

### Variance Analysis
- Run 2 missed P07 (API versioning) and P08 (change propagation) which Run 1 detected
- Run 2 gave partial credit (△) for P05 (DI/testability) while Run 1 gave full credit (○)
- Both runs detected high-severity issues consistently (P01-P03)
- Bonus items were similar in nature (architectural gaps beyond answer key)
- Standard deviation of 1.25 indicates **moderate stability** (between 0.5-1.0 would be high stability threshold)
