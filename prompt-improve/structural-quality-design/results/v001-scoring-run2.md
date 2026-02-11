# Structural Quality Design Review - SmartLibrary System

**Reviewer:** structural-quality-design-reviewer (v001)
**Review Date:** 2026-02-11
**Document:** SmartLibrary システム設計書

---

## Evaluation Scores

| Criterion | Score | Rating |
|-----------|-------|--------|
| 1. SOLID Principles & Structural Design | 2 | Significant Issues |
| 2. Changeability & Module Design | 2 | Significant Issues |
| 3. Extensibility & Operational Design | 3 | Moderate Issues |
| 4. Error Handling & Observability | 3 | Moderate Issues |
| 5. Test Design & Testability | 3 | Moderate Issues |
| 6. API & Data Model Quality | 2 | Significant Issues |

**Overall Assessment:** The design exhibits significant structural issues that will impact long-term maintainability and sustainability, particularly in SOLID principles adherence, module boundaries, and API design.

---

## Critical Issues

### C1. Severe Single Responsibility Principle Violation - LibraryService God Class

**Severity:** Critical (Score: 1 on SRP dimension)

**Location:** Section 3 - アーキテクチャ設計 > 主要コンポーネント

**Issue Description:**
LibraryService is described as handling 5 distinct responsibilities:
1. 図書の貸出・返却 (Loan operations)
2. 蔵書管理 (Book inventory management)
3. 予約処理 (Reservation processing)
4. レポート生成 (Report generation)
5. 利用者認証 (User authentication)

This is a textbook example of a God Class anti-pattern, where a single service class accumulates multiple unrelated business capabilities.

**Impact Analysis:**
- **Change propagation:** Any modification to loan logic, reservation logic, or reporting logic requires changes to the same class, increasing merge conflicts and regression risk
- **Testing complexity:** Unit testing becomes difficult because the class has 5 different mock dependency sets (BookRepository, LoanRepository, UserRepository, ReservationRepository, plus potentially authentication dependencies)
- **Team parallelization:** Multiple developers cannot work on different features (e.g., one on reporting, another on reservations) without constant merge conflicts
- **Cognitive load:** Understanding and maintaining this class requires knowledge of the entire business domain rather than a focused subset

**Why This Violates Sustainability:**
The fundamental principle "a class should have only one reason to change" is violated 5 times over. When business requirements change for reporting (e.g., add new metrics), the same class that handles critical loan operations must be modified, introducing unnecessary risk.

**Recommended Refactoring:**
```
LibraryService (God Class)
  ↓ Split into:
  - LoanService (borrowBook, returnBook, extendLoan)
  - BookManagementService (addBook, updateBook, deleteBook, searchBooks)
  - ReservationService (reserveBook, cancelReservation, getReservations)
  - ReportGenerationService (generateLoanReport, getPopularBooks)
  - AuthenticationService (login, validateToken) - or integrate with UserService
```

Each service should have a single cohesive responsibility and depend only on the repositories relevant to its domain.

---

### C2. Critical Coupling - Direct Repository Access from Service Layer

**Severity:** Critical (Score: 1 on coupling dimension)

**Location:** Section 3 - アーキテクチャ設計 > LibraryService

**Issue Description:**
LibraryService directly accesses 4 different repositories (BookRepository, LoanRepository, UserRepository, ReservationRepository). This creates tight coupling between the service layer and the persistence layer, and indicates missing domain boundaries.

**Impact Analysis:**
- **Change amplification:** Changes to database schema or repository interfaces require modifications to the God Class LibraryService
- **Transaction management complexity:** Cross-repository operations (e.g., creating a loan record while updating book availability) are scattered across a single large class, making transaction boundaries unclear
- **Domain logic leakage:** Repository-level concerns (queries, persistence) are mixed with business logic in one place

**Why This Violates Sustainability:**
When 4+ repositories are accessed from a single service, it signals that the service is operating at the wrong abstraction level. It's functioning as an orchestration layer for data access rather than encapsulating cohesive business logic.

**Recommended Refactoring:**
1. Split LibraryService into domain-aligned services (as per C1)
2. Each service should access only its primary repository:
   - LoanService → LoanRepository
   - BookManagementService → BookRepository
   - ReservationService → ReservationRepository
3. For cross-cutting queries (e.g., "get all active loans for a user"), introduce:
   - Domain events (e.g., LoanCreatedEvent) for eventual consistency scenarios
   - Facade/orchestration layer for coordinated operations across domains
   - Read models (CQRS pattern) if complex reporting queries are needed

---

## Significant Issues

### S1. API Design Violations - Non-RESTful Endpoints

**Severity:** Significant (Score: 2 on API Quality)

**Location:** Section 5 - API設計 > エンドポイント一覧

**Issue Description:**
Multiple API endpoints violate RESTful design principles:

1. **Verbs in URLs:**
   - `POST /api/login` → should be `POST /api/auth/sessions`
   - `POST /api/borrowBook` → should be `POST /api/loans`
   - `POST /api/returnBook` → should be `PATCH /api/loans/{id}` or `DELETE /api/loans/{id}`
   - `POST /api/reserveBook` → should be `POST /api/reservations`
   - `POST /api/cancelReservation` → should be `DELETE /api/reservations/{id}`
   - `POST /api/extendLoan` → should be `PATCH /api/loans/{id}`

2. **Inconsistent HTTP method usage:**
   - `POST /api/deleteBook/{bookId}` → should be `DELETE /api/books/{bookId}`
   - `POST /api/updateBook` → should be `PUT /api/books/{id}` or `PATCH /api/books/{id}`
   - `POST /api/user/updateProfile` → should be `PATCH /api/users/{id}` or `PATCH /api/users/me`

3. **Missing resource hierarchy:**
   - User-specific resources should be nested: `/api/users/{userId}/loans`, `/api/users/{userId}/reservations`
   - Currently uses inconsistent patterns (`GET /api/user/{userId}/loans` vs `POST /api/borrowBook`)

**Impact Analysis:**
- **API evolution difficulty:** Non-standard endpoints make versioning and backward compatibility harder to manage
- **Client-side confusion:** Developers must memorize custom endpoint conventions rather than following standard REST patterns
- **Tooling incompatibility:** API documentation generators, client SDK generators, and API gateways work best with standard REST conventions

**Why This Violates Sustainability:**
APIs are contracts that last for years. Non-RESTful designs create technical debt that becomes harder to fix over time as client dependencies accumulate. When 10+ mobile apps and web clients depend on these endpoints, refactoring becomes a multi-year migration project.

**Recommended Refactoring:**
```
Standard RESTful Design:
- POST   /api/loans              (borrow a book)
- PATCH  /api/loans/{id}         (return or extend a loan)
- GET    /api/users/{id}/loans   (get user's loans)

- POST   /api/reservations       (reserve a book)
- DELETE /api/reservations/{id}  (cancel reservation)
- GET    /api/users/{id}/reservations

- POST   /api/books              (add book)
- PUT    /api/books/{id}         (update book)
- DELETE /api/books/{id}         (delete book)
- GET    /api/books?keyword=X&category=Y (search)
```

Add API versioning strategy (e.g., `/api/v1/loans`) to enable future evolution without breaking existing clients.

---

### S2. Data Model Denormalization - Redundant Columns in loans Table

**Severity:** Significant (Score: 2 on Data Model Quality)

**Location:** Section 4 - データモデル > loans テーブル

**Issue Description:**
The `loans` table contains redundant columns:
- `user_name VARCHAR(100)` - duplicates `users.name`
- `book_title VARCHAR(500)` - duplicates `books.title`

These are described as "冗長データ" (redundant data), indicating intentional denormalization without clear justification.

**Impact Analysis:**
- **Data consistency risk:** When a user's name is updated in the `users` table, historical loan records retain the old name, creating inconsistent data
- **Update anomalies:** Changing a book title requires updating both `books.title` and all `loans.book_title` records
- **Storage waste:** 600 bytes per loan record for data that already exists in normalized form
- **Query confusion:** Developers must choose between `JOIN users` to get current name or use `loans.user_name` for historical snapshot - inconsistent decisions lead to bugs

**Why This Violates Sustainability:**
Denormalization is a valid performance optimization, but only when:
1. There is measured evidence that JOIN performance is insufficient
2. The denormalized data represents immutable snapshots (e.g., price at time of order)
3. There is a clear update strategy to maintain consistency

In this design, there is no indication that (1) or (3) are satisfied, and (2) is questionable - should loan records show current user name or historical name?

**Recommended Refactoring:**

**Option A (Remove redundancy):**
```sql
-- Remove user_name and book_title columns
-- Use JOINs for queries that need this data
SELECT l.id, u.name, b.title, l.loan_date, l.due_date
FROM loans l
JOIN users u ON l.user_id = u.id
JOIN books b ON l.book_id = b.id
```

**Option B (Intentional snapshot with clear semantics):**
If the requirement is to preserve historical data as it was at loan time:
1. Rename columns to clarify intent: `user_name_at_loan_time`, `book_title_at_loan_time`
2. Add database triggers to populate these values at INSERT time
3. Document that these are immutable snapshots, not current values
4. Add indexed columns `user_id` and `book_id` for JOINs when current data is needed

Prefer Option A unless there is a documented business requirement for historical snapshots.

---

### S3. Cross-Cutting Responsibility Violation - JWT Generation in UserService

**Severity:** Significant (Score: 2 on SRP)

**Location:** Section 3 - アーキテクチャ設計 > UserService

**Issue Description:**
UserService is described as handling both user management (registration, profile updates) and JWT token generation. Token generation is a cross-cutting security concern, not a user management concern.

**Impact Analysis:**
- **Inconsistent authentication flow:** LibraryService also performs "利用者認証", creating duplicate or unclear authentication responsibility
- **Testability:** Testing user profile updates requires mocking JWT libraries, even though profile updates have nothing to do with token generation
- **Change coupling:** Changes to token format (e.g., switching from JWT to OAuth tokens) require modifying UserService, even though user data model is unchanged

**Why This Violates Sustainability:**
Authentication is a cross-cutting concern that should be isolated from domain services. When authentication logic is embedded in UserService, it becomes difficult to:
- Swap authentication mechanisms (e.g., migrate to OAuth2, add SSO)
- Implement multi-factor authentication
- Add token refresh logic without touching user management code

**Recommended Refactoring:**
1. Create separate `AuthenticationService`:
   ```
   AuthenticationService:
     - authenticateUser(email, password) → JWT
     - validateToken(token) → User
     - refreshToken(token) → JWT
   ```
2. UserService should focus on user management:
   ```
   UserService:
     - registerUser(userData) → User
     - updateProfile(userId, updates) → User
     - getUserById(userId) → User
   ```
3. AuthenticationService can depend on UserService to retrieve user data, but not vice versa

---

## Moderate Issues

### M1. Missing Versioning Strategy

**Severity:** Moderate (Score: 3 on API Quality)

**Location:** Section 5 - API設計

**Issue Description:**
API endpoints have no versioning mechanism (e.g., `/api/v1/loans`). The document mentions backward compatibility concerns but provides no strategy for evolving the API over time.

**Impact Analysis:**
- When breaking changes are needed (e.g., changing response format), there is no way to introduce them without breaking existing clients
- Mobile apps with long release cycles (users don't update frequently) will break when API changes are deployed

**Recommended Refactoring:**
Add version prefix to all endpoints: `/api/v1/*`. Document API versioning policy in section 5:
- Breaking changes require new major version (`/api/v2`)
- Backward-compatible additions can be added to existing version
- Old versions are supported for minimum 12 months after new version release

---

### M2. Unclear Error Classification Strategy

**Severity:** Moderate (Score: 3 on Error Handling)

**Location:** Section 6 - 実装方針 > エラーハンドリング方針

**Issue Description:**
The error handling section mentions "データベース接続エラー、バリデーションエラー、業務ロジックエラーなど、エラーの種類に応じて異なる処理を行う" but does not specify:
- Error classification taxonomy (which errors are retryable, which are client errors, which are server errors)
- Mapping from error types to HTTP status codes
- Error response format specification

**Impact Analysis:**
- Developers will implement inconsistent error handling (some returning 500 for validation errors, others returning 400)
- Clients cannot reliably distinguish between retryable errors (503 Service Unavailable) and permanent errors (404 Not Found)

**Recommended Refactoring:**
Add explicit error classification table:
```
| Error Type | HTTP Status | Retryable | Example |
|------------|-------------|-----------|---------|
| Validation Error | 400 | No | Invalid ISBN format |
| Authentication Error | 401 | No | Invalid JWT token |
| Authorization Error | 403 | No | Student trying to delete book |
| Resource Not Found | 404 | No | Book ID does not exist |
| Business Rule Violation | 422 | No | Cannot borrow - already has 5 loans |
| Database Connection Error | 503 | Yes | PostgreSQL connection timeout |
| Internal Error | 500 | Maybe | Unexpected NullPointerException |
```

Define standard error response format:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid ISBN format",
    "details": [
      {"field": "isbn", "issue": "Must be 13 digits"}
    ]
  }
}
```

---

### M3. Incomplete Test Strategy - Missing Test Doubles Design

**Severity:** Moderate (Score: 3 on Test Design)

**Location:** Section 6 - 実装方針 > テスト方針

**Issue Description:**
The test strategy mentions JUnit 5 and Mockito for unit tests, but does not specify:
- Which external dependencies will be mocked (e.g., JavaMailSender, Redis, S3 client)
- How to handle LibraryService's 4 repository dependencies in unit tests
- Test data management strategy (fixtures, builders, factories)

**Impact Analysis:**
- Unit tests for LibraryService will require mocking 4+ repositories, making tests fragile and coupled to implementation details
- Unclear whether external services (email, Redis) should be mocked or use real implementations in integration tests
- Test setup code will become duplicated across test classes without standard fixture patterns

**Recommended Refactoring:**
Add test doubles specification:
1. **Unit Test Mocking Strategy:**
   - Repository interfaces: Use Mockito mocks
   - JavaMailSender: Use Mockito mock (no real emails in tests)
   - Clock/time: Inject `Clock` interface to control time in tests

2. **Integration Test Strategy:**
   - PostgreSQL: Use Testcontainers (real database)
   - Redis: Use embedded Redis or Testcontainers
   - External APIs: Use WireMock for HTTP mocking

3. **Test Data Builders:**
   ```java
   UserBuilder.aStudent()
     .withEmail("test@example.com")
     .withName("Test User")
     .build()

   BookBuilder.anAvailableBook()
     .withISBN("9781234567890")
     .withCopies(5)
     .build()
   ```

Note: This issue severity will increase to Significant once LibraryService is split into smaller services (as per C1), because proper testability requires well-defined module boundaries.

---

### M4. Missing Configuration Management Details

**Severity:** Moderate (Score: 3 on Extensibility)

**Location:** Section 6 - 実装方針 > デプロイメント方針

**Issue Description:**
The deployment section mentions "環境別設定は環境変数で管理（DATABASE_URL, REDIS_URL等）" but does not specify:
- Complete list of environment-specific configuration (SMTP settings, JWT secret, S3 bucket names, etc.)
- Configuration validation strategy (startup fails if required env vars are missing?)
- Secrets management approach (how are DATABASE_URL passwords stored and rotated?)

**Impact Analysis:**
- Production deployment failures due to missing environment variables
- Security risk if JWT secrets are hardcoded in Docker images instead of injected at runtime
- Difficult to test configuration changes without deploying to environment

**Recommended Refactoring:**
Add configuration specification section:
```
Required Environment Variables:
- DATABASE_URL: PostgreSQL connection string
- REDIS_URL: Redis connection string
- JWT_SECRET: Secret key for JWT signing (rotate every 90 days)
- SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD: Email settings
- S3_BUCKET_NAME: Bucket for report storage
- LOG_LEVEL: Logging level (default: INFO)

Secrets Management:
- Use AWS Secrets Manager for DATABASE_URL, JWT_SECRET, SMTP_PASSWORD
- Application loads secrets at startup via AWS SDK
- Secrets are rotated automatically via Lambda function

Startup Validation:
- Application fails to start if any required env var is missing
- Configuration values are logged (except secrets) for audit
```

---

## Minor Issues and Positive Aspects

### Minor Issues

**I1. Logging Policy Lacks Structured Logging Specification**
- The logging section specifies log levels (ERROR, WARN, INFO, DEBUG) but not log format
- Recommend structured logging (JSON format) for better log aggregation in CloudWatch
- Specify what should be logged: request ID, user ID, operation type, duration

**I2. Cache Strategy Underspecified**
- Redis is listed in tech stack but caching strategy is not documented
- Which data will be cached? (Book search results? User profiles?)
- Cache invalidation strategy? (TTL-based? Event-based?)

### Positive Aspects

**P1. Clear Technology Stack Selection**
Section 2 provides a comprehensive list of technologies with specific versions, reducing ambiguity for implementation teams.

**P2. Comprehensive Database Schema**
Section 4 provides detailed column specifications with data types and constraints, enabling database migration scripts to be generated directly from the design.

**P3. Deployment Automation Mindset**
Section 6 specifies Blue-Green deployment strategy and Kubernetes-based infrastructure, indicating awareness of modern DevOps practices.

---

## Summary and Recommendations

### Critical Actions Required

1. **Decompose LibraryService into domain-aligned services** (addresses C1, C2)
   - Estimated effort: 3-5 days
   - Risk if not addressed: Exponential increase in maintenance cost and bug rate as features are added

2. **Redesign API endpoints following REST principles** (addresses S1)
   - Estimated effort: 2-3 days
   - Risk if not addressed: Technical debt that becomes unfixable once clients are deployed

3. **Remove data model redundancy or justify with clear snapshot semantics** (addresses S2)
   - Estimated effort: 1-2 days
   - Risk if not addressed: Data inconsistency bugs in production

### High-Priority Improvements

4. **Extract AuthenticationService** (addresses S3)
5. **Add API versioning strategy** (addresses M1)
6. **Define error classification taxonomy** (addresses M2)

### Recommended Next Steps

1. Revise section 3 (アーキテクチャ設計) to reflect decomposed service architecture
2. Revise section 5 (API設計) to follow RESTful principles and add versioning
3. Revise section 4 (データモデル) to remove redundant columns or justify with clear semantics
4. Add new subsections for error classification, configuration management, and test doubles strategy

This design review identifies foundational structural issues that, if addressed early, will significantly improve the long-term sustainability and maintainability of the SmartLibrary system.
