# Consistency Review Report: Content Publishing Platform

## Inconsistencies Identified

### Critical Severity

#### C1. Timestamp Column Naming Fragmentation (4 Incompatible Patterns)
**Problem**: The design introduces 4 different timestamp naming patterns across 4 tables, creating systematic inconsistency despite documented standards.

**Pattern Evidence**:
- Documented standard (Section 8.1.1, line 269): `created_at`, `updated_at` (snake_case, past participle)
- Article table (lines 93-94): `created`, `updated` (snake_case, no suffix)
- User table (lines 103-104): `createdAt`, `updatedAt` (camelCase)
- Media table (lines 116-117): `created_at`, `updated_at` (COMPLIANT with standard)
- Review table (lines 127-128): `created`, `modified` (mixed terminology)

**Dominant Pattern Analysis**:
- Existing system establishes `created_at`/`updated_at` as the standard (referenced in lines 266, 269)
- Current design compliance: 1/4 tables (25%)
- 3/4 tables violate the documented convention

**Impact Analysis**:
- **Critical fragmentation risk**: Each table uses a different pattern, enabling future developers to claim "consistency" with at least one existing table while fragmenting the codebase
- Cross-table queries require different column names: `SELECT t1.created, t2.createdAt, t3.created_at, t4.modified` - maintenance burden
- ORM mapping complexity: JPA entity classes will have inconsistent field names across the system
- Migration scripts become error-prone due to lack of standardization
- **Adversarial exploitation**: Developers can justify ANY timestamp naming by pointing to precedent in this design

**Recommendations**:
1. Standardize ALL tables to use `created_at`/`updated_at` (snake_case with `_at` suffix)
2. Update Article table: `created` → `created_at`, `updated` → `updated_at`
3. Update User table: `createdAt` → `created_at`, `updatedAt` → `updated_at`
4. Update Review table: `created` → `created_at`, `modified` → `updated_at`

---

#### C2. Primary Key Naming Inconsistency (50% Violation Rate)
**Problem**: Primary key naming violates documented standard in 50% of tables.

**Pattern Evidence**:
- Documented standard (Section 8.1.1, line 267): Primary key column name is `id` (no table name prefix)
- Article table (line 86): `id` (COMPLIANT)
- User table (line 99): `id` (COMPLIANT)
- Media table (line 109): `media_id` (VIOLATION)
- Review table (line 121): `review_id` (VIOLATION)

**Impact Analysis**:
- JOIN query column ambiguity: `SELECT * FROM article a JOIN review r ON a.id = r.article_id` returns two `id` columns when Media/Review use prefixed names
- ORM entity mapping inconsistency: Some entities use `@Id Long id`, others use `@Id Long mediaId`
- **Hidden coupling**: Code expecting `id` field will fail for Media/Review entities
- Foreign key relationship complexity increases unnecessarily

**Recommendations**:
1. Rename `media_id` → `id` in Media table
2. Rename `review_id` → `id` in Review table
3. Ensure all entity primary keys follow the uniform `id` naming convention

---

#### C3. Foreign Key Naming Pattern Violations
**Problem**: Foreign key columns violate the documented `{table}_id` naming pattern.

**Pattern Evidence**:
- Documented standard (Section 8.1.1, line 268): Foreign keys use `{referenced_table}_id` format (e.g., `user_id`, `article_id`)
- Compliant examples: `author_id` (line 90), `article_id` (line 122)
- VIOLATION 1: `uploaded_by` (line 114) should be `user_id` or `uploader_id` following the `{table}_id` pattern
- VIOLATION 2: `reviewer` (line 123) should be `reviewer_id` following the `{table}_id` pattern

**Impact Analysis**:
- Breaks developer expectation: Foreign keys become unpredictable (sometimes `*_id`, sometimes not)
- ORM relationship mapping confusion: `@JoinColumn(name = "uploaded_by")` vs `@JoinColumn(name = "user_id")`
- Database introspection tools may not recognize `uploaded_by` and `reviewer` as foreign keys
- **Fragmentation enabler**: Establishes precedent for arbitrary foreign key naming

**Recommendations**:
1. Rename `uploaded_by` → `uploader_id` (maintains semantic clarity while following pattern)
2. Rename `reviewer` → `reviewer_id`
3. Document semantic naming approach: When referencing same table multiple times, use `{role}_id` pattern (e.g., `author_id`, `uploader_id`, `reviewer_id`)

---

#### C4. API Endpoint Versioning Fragmentation (45% Non-Compliance)
**Problem**: Article management endpoints omit the required `/api/v1/` prefix, creating two incompatible API path patterns.

**Pattern Evidence**:
- Documented standard (Section 8.1.2, lines 272-273): API paths must use `/api/v1/` prefix with versioning
- Article endpoints (lines 141-145): `/api/articles/*` (5/5 endpoints MISSING v1 prefix)
- Media endpoints (lines 148-150): `/api/v1/media/*` (3/3 COMPLIANT)
- Review endpoints (lines 153-155): `/api/v1/reviews/*` (3/3 COMPLIANT)

**Compliance Rate**: 6/11 endpoints follow the standard (55% compliant, 45% non-compliant)

**Impact Analysis**:
- **Critical path fragmentation**: API consumers cannot predict path structure - is versioning required or optional?
- Reverse proxy routing complexity: Must handle both `/api/*` and `/api/v1/*` patterns
- **Future migration burden**: When Article API needs v2, migration path is unclear
- **Adversarial exploitation**: Establishes precedent that versioning is optional, enabling gradual erosion of API standards
- Client SDK generation fails due to inconsistent base paths

**Recommendations**:
1. Add `/v1/` prefix to ALL Article endpoints:
   - `POST /api/articles/new` → `POST /api/v1/articles`
   - `GET /api/articles/{id}` → `GET /api/v1/articles/{id}`
   - `PUT /api/articles/{id}/edit` → `PUT /api/v1/articles/{id}`
   - `DELETE /api/articles/{id}` → `DELETE /api/v1/articles/{id}`
   - `GET /api/articles/list` → `GET /api/v1/articles`

---

#### C5. Response Format Documentation Conflict
**Problem**: The design document specifies two incompatible response formats in different sections.

**Pattern Evidence**:
- Documented standard (Section 8.1.3, line 278): Response format is `{data, error}` structure
- Actual example (Section 5.2.2, lines 171-179): `{success: true, data: {...}, message: "..."}`
- Error response example (Section 5.2.3, lines 183-189): `{error: {code: "...", message: "..."}}`

**Impact Analysis**:
- **Specification conflict**: Two authoritative sections contradict each other
- Frontend developers cannot determine correct response parsing logic
- Middleware/interceptor implementation becomes ambiguous
- **Fragmentation enabler**: Each module can claim compliance with one of the documented formats
- Automated API client generation fails due to conflicting schemas

**Recommendations**:
1. Clarify which response format is authoritative - recommend the `{data, error}` pattern from Section 8.1.3
2. Update success response example to:
   ```json
   {
     "data": {
       "id": 123,
       "title": "記事タイトル",
       "status": "draft"
     },
     "error": null
   }
   ```
3. Update error response example to:
   ```json
   {
     "data": null,
     "error": {
       "code": "VALIDATION_ERROR",
       "message": "Title is required"
     }
   }
   ```
4. Remove `success` and top-level `message` fields from examples

---

### Significant Severity

#### S1. Non-RESTful Article Endpoint Naming
**Problem**: Article endpoints use non-RESTful path conventions despite documented RESTful standard.

**Pattern Evidence**:
- Documented standard (Section 8.1.2, line 274): HTTP methods follow RESTful conventions (GET/POST/PUT/DELETE)
- VIOLATION: `POST /api/articles/new` (line 141) - should be `POST /api/v1/articles`
- VIOLATION: `PUT /api/articles/{id}/edit` (line 143) - should be `PUT /api/v1/articles/{id}`
- VIOLATION: `GET /api/articles/list` (line 145) - should be `GET /api/v1/articles`

**Impact Analysis**:
- Violates REST principles: HTTP methods (POST/PUT/GET) already convey action, no need for `/new`, `/edit`, `/list` suffixes
- Client code confusion: Media/Review use RESTful paths, Articles use RPC-style paths
- API documentation inconsistency across modules
- Developer experience degradation: Must remember two different path patterns

**Recommendations**:
1. Remove action suffixes from Article endpoints:
   - `POST /api/articles/new` → `POST /api/v1/articles`
   - `PUT /api/articles/{id}/edit` → `PUT /api/v1/articles/{id}`
   - `GET /api/articles/list` → `GET /api/v1/articles`
2. Ensure consistency with Media and Review endpoint patterns

---

#### S2. Table Name Documentation Inconsistency
**Problem**: The design document references `media_file` table in Section 8 but defines `media` table in Section 4.

**Pattern Evidence**:
- Section 4.1.3 (line 106): Table defined as `media`
- Section 8.1.1 (line 265): References `media_file` as existing pattern example
- Section 8.1.2 (line 273): References `/api/v1/media-files` endpoint, but actual endpoint is `/api/v1/media` (line 148)

**Impact Analysis**:
- Internal documentation contradiction creates confusion
- Developers may create wrong table name during implementation
- Migration scripts may target non-existent table
- API documentation refers to non-existent resource name

**Recommendations**:
1. Decide authoritative table name: `media` or `media_file`
2. Update Section 8.1.1 line 265 to match actual table name
3. Ensure API endpoint matches table name (either `/media` or `/media-files`)
4. Recommendation: Keep `media` (simpler, already defined in schema)

---

#### S3. HTTP Client Library Ambiguity
**Problem**: Technology stack specifies OkHttp but implementation pattern specifies RestTemplate - unclear which to use.

**Pattern Evidence**:
- Section 2.2 (line 31): Lists "OkHttp 4.12" as HTTP communication library
- Section 8.1.3 (line 277): Specifies "RestTemplateを使用（WebClient不使用）"

**Impact Analysis**:
- Implementation uncertainty: Developers don't know which library to import
- Potential for mixed usage: Some modules use OkHttp, others use RestTemplate
- RestTemplate is Spring's abstraction (can use OkHttp as underlying client), but relationship unclear
- Code review ambiguity: Is OkHttp usage a violation of the RestTemplate standard?

**Recommendations**:
1. Clarify the relationship: "Use Spring RestTemplate with OkHttp as the underlying HTTP client"
2. Document configuration: Provide RestTemplate bean configuration using OkHttpClientHttpRequestFactory
3. Remove OkHttp from "main libraries" list if it's only used internally by RestTemplate

---

#### S4. Category Data Model Inconsistency
**Problem**: Article table uses `category` VARCHAR column but request JSON uses `categoryId` integer, creating type mismatch.

**Pattern Evidence**:
- Article table (line 91): `category VARCHAR(50)` - stores category name as string
- Article creation request (line 164): `"categoryId": 1` - references category by integer ID
- No `category` table defined in data model

**Impact Analysis**:
- API contract doesn't match database schema
- Implementation will fail: Cannot store integer `categoryId` in VARCHAR `category` column
- Missing foreign key relationship: No referential integrity for categories
- **Pattern evasion**: Using VARCHAR instead of FK avoids foreign key naming convention while enabling data inconsistency

**Recommendations**:
1. Add `category` table to data model:
   ```
   category table:
   - id (BIGINT, PK)
   - name (VARCHAR(50), NOT NULL, UNIQUE)
   - created_at (TIMESTAMP)
   - updated_at (TIMESTAMP)
   ```
2. Change Article table: `category VARCHAR(50)` → `category_id BIGINT FK → category.id`
3. Update request JSON to use `category_id` (snake_case to match database convention)

---

### Moderate Severity

#### M1. Request/Response JSON Naming Convention Undefined
**Problem**: No documentation on JSON field naming convention (camelCase vs snake_case).

**Pattern Evidence**:
- Request example (line 164): Uses camelCase (`categoryId`)
- Database columns: Use snake_case (`user_name`, `created_at`)
- No explicit JSON field naming convention documented

**Impact Analysis**:
- DTO mapping uncertainty: Should DTOs match database (snake_case) or frontend (camelCase)?
- Inconsistent API across modules if not standardized
- Frontend-backend contract ambiguity

**Recommendations**:
1. Document JSON field naming standard: "API requests/responses use camelCase for JSON fields"
2. Document DTO mapping responsibility: "Service layer maps between camelCase DTOs and snake_case entities"
3. Add example showing the mapping: `categoryId` (JSON) → `category_id` (database)

---

#### M2. Missing Transaction Management Pattern
**Problem**: Design specifies JPA usage but provides no transaction boundary guidance.

**Pattern Evidence**:
- Section 6.3 (line 227): "JPA (Hibernate) を使用。複数エンティティの更新が必要な場合は、各Repositoryメソッドを個別に呼び出す。"
- No mention of `@Transactional` annotation or transaction scope

**Impact Analysis**:
- Risk of partial updates: Multi-entity operations may leave inconsistent state
- No guidance on transaction isolation levels
- Rollback behavior undefined for multi-repository calls

**Recommendations**:
1. Document transaction pattern: "Service layer methods that modify data should be annotated with `@Transactional`"
2. Specify default isolation level and propagation behavior
3. Provide example:
   ```java
   @Service
   public class ArticleService {
       @Transactional
       public Article createWithReview(ArticleRequest req) {
           Article article = articleRepository.save(...);
           Review review = reviewRepository.save(...);
           return article;
       }
   }
   ```

---

#### M3. Missing Pagination Pattern for List Endpoints
**Problem**: List endpoint (`GET /api/articles/list`) has no pagination specification.

**Pattern Evidence**:
- Line 145: `GET /api/articles/list` defined without pagination parameters
- No documentation on pagination query parameters or response format

**Impact Analysis**:
- Unbounded result sets: Could return thousands of records
- Performance degradation as data grows
- No consistency with other potential list endpoints

**Recommendations**:
1. Document pagination pattern:
   - Query parameters: `page` (0-indexed), `size` (default 20, max 100)
   - Response format: `{data: {items: [...], totalItems: N, totalPages: N}, error: null}`
2. Apply to all list endpoints consistently

---

#### M4. JWT Token Management Incomplete Specification
**Problem**: JWT expiration is documented (24h) but no refresh mechanism specified.

**Pattern Evidence**:
- Line 195: "トークン有効期限: 24時間"
- Line 196: "トークン保存先: ブラウザのlocalStorageに保存"
- No refresh token pattern, no token renewal endpoint

**Impact Analysis**:
- User session expires after 24h with no graceful renewal
- Potential security risk: localStorage persistence without rotation
- Poor UX: Users forced to re-login every 24 hours

**Recommendations**:
1. Add refresh token endpoint: `POST /api/v1/auth/refresh`
2. Document refresh token storage (httpOnly cookie recommended)
3. Document token rotation policy
4. **Security note**: Consider httpOnly cookies instead of localStorage to prevent XSS token theft (though this conflicts with documented pattern - flag for architectural review)

---

#### M5. Missing Environment Variable Naming Convention
**Problem**: No specification for environment variable naming (e.g., DATABASE_URL vs database.url).

**Pattern Evidence**:
- Section 8 documents naming conventions for database, API, but not for environment variables

**Impact Analysis**:
- Configuration inconsistency across deployment environments
- Docker Compose, Kubernetes manifests may use different naming
- Spring Boot property mapping ambiguity

**Recommendations**:
1. Document environment variable standard: "Use UPPER_SNAKE_CASE for environment variables (e.g., DATABASE_URL, JWT_SECRET_KEY)"
2. Provide mapping to Spring Boot properties: `DATABASE_URL` → `spring.datasource.url`

---

### Minor Severity (Positive Observations)

#### P1. Table Naming Consistency
All tables correctly use singular, snake_case naming as documented:
- `article`, `user`, `media`, `review` (all singular)
- Full compliance with Section 8.1.1 line 265 standard

#### P2. Media and Review API Compliance
Media and Review modules demonstrate correct API endpoint patterns:
- Proper `/api/v1/` versioning
- RESTful resource naming
- Consistent HTTP method usage

#### P3. Foreign Key Relationships Documented
All foreign key constraints are explicitly documented in Section 4.2:
- `article.author_id → user.id`
- `media.uploaded_by → user.id` (though naming needs correction)
- `review.article_id → article.id`
- `review.reviewer → user.id` (though naming needs correction)

---

## Summary Statistics

**Total Issues Identified**: 18 (5 Critical, 5 Significant, 5 Moderate, 3 Positive)

**Compliance Analysis**:
- Timestamp naming: 25% compliant (1/4 tables)
- Primary key naming: 50% compliant (2/4 tables)
- Foreign key naming: 50% compliant (2/4 foreign keys)
- API versioning: 55% compliant (6/11 endpoints)
- Table naming: 100% compliant (4/4 tables)

**Adversarial Risk Assessment**:
- **High fragmentation risk**: Multiple inconsistency patterns enable developers to justify arbitrary choices by citing precedent
- **Pattern erosion risk**: Mixed API versioning and timestamp naming create slippery slope for further deviations
- **Hidden coupling risk**: Missing transaction, pagination, and token refresh patterns enable inconsistent implementations across modules

**Priority Recommendations**:
1. **Immediate**: Fix all timestamp column naming to `created_at`/`updated_at` (prevents 4-pattern fragmentation)
2. **Immediate**: Standardize all primary keys to `id` (prevents ORM mapping inconsistency)
3. **Immediate**: Add `/v1/` prefix to Article endpoints (prevents API path fragmentation)
4. **High**: Resolve response format documentation conflict (prevents module-level incompatibility)
5. **High**: Fix foreign key naming (`uploaded_by` → `uploader_id`, `reviewer` → `reviewer_id`)
6. **Medium**: Complete missing pattern documentation (transactions, pagination, JWT refresh, environment variables)
