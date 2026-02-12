# Consistency Design Review Report
**Document:** Content Publishing Platform システム設計書
**Review Date:** 2026-02-11
**Reviewer Variant:** v012-variant-adversarial-checklist (Adversarial Mode + Pattern Verification + Information Gap Checklist)

---

## Executive Summary

This design document exhibits **critical consistency violations** across multiple dimensions: data model naming (0% compliance with timestamp standards), API design (45% missing mandatory versioning), and conflicting documentation (HTTP library, response formats). Additionally, **critical information gaps** in transaction management and configuration standards enable inconsistent implementations across modules. Immediate remediation is required before implementation.

**Severity Distribution:**
- Critical: 6 issues
- Significant: 5 issues
- Moderate: 4 issues
- Minor: 3 issues

---

## Inconsistencies Identified

### Critical Issues

#### 1. Timestamp Column Naming Standard Violation (0% Compliance)
**Category:** Naming Convention Consistency
**Type:** Pattern Inconsistency

**Finding:**
Section 8.1.1 explicitly documents the established standard: timestamp columns must use `created_at`/`updated_at` format (snake_case with `_at` suffix). However, ALL four entities in the data model violate this standard:

- **Article table:** Uses `created`, `updated` (missing `_at` suffix)
- **User table:** Uses `createdAt`, `updatedAt` (camelCase instead of snake_case)
- **Review table:** Uses `created`, `modified` (missing `_at` suffix, wrong verb)
- **Media table:** ✓ Uses `created_at`, `updated_at` (ONLY compliant entity)

**Quantitative Evidence:** 0/4 entities follow the documented standard (0% compliance rate)

**Impact:**
This violation creates fragmented timestamp handling across the codebase:
- Database queries requiring timestamp filtering must handle 3 different naming patterns
- ORM mappings become inconsistent
- Developers cannot rely on a uniform timestamp column naming convention
- **Adversarial exploitation:** Future developers could justify any timestamp naming variant by pointing to existing precedents in this module

**Recommendation:**
Standardize ALL timestamp columns to documented pattern:
- Article: `created` → `created_at`, `updated` → `updated_at`
- User: `createdAt` → `created_at`, `updatedAt` → `updated_at`
- Review: `created` → `created_at`, `modified` → `updated_at`

---

#### 2. Primary Key Naming Inconsistency (50% Non-Compliance)
**Category:** Naming Convention Consistency
**Type:** Pattern Inconsistency

**Finding:**
Section 8.1.1 documents: "主キー列名: `id`（テーブル名プレフィックスなし）"

Violations:
- **Media table:** Uses `media_id` (should be `id`)
- **Review table:** Uses `review_id` (should be `id`)
- Article table: ✓ Uses `id` (compliant)
- User table: ✓ Uses `id` (compliant)

**Quantitative Evidence:** 2/4 entities violate standard (50% non-compliance rate)

**Impact:**
- JPA entity mapping becomes inconsistent (some entities use `@Id` on `id`, others on `{table}_id`)
- Generic repository patterns cannot assume uniform primary key naming
- Foreign key references become ambiguous (is it referencing `id` or `{table}_id`?)
- **Adversarial exploitation:** Creates precedent for table-prefixed primary keys, enabling future fragmentation

**Recommendation:**
Rename primary keys to standard `id`:
- Media: `media_id` → `id`
- Review: `review_id` → `id`

---

#### 3. API Versioning Requirement Violation (45% Non-Compliance)
**Category:** API/Interface Design Consistency
**Type:** Pattern Inconsistency

**Finding:**
Section 8.1.2 mandates: "パスプレフィックス: `/api/v1/` 形式（バージョニング必須）"

Violations - ALL Article endpoints lack versioning:
- `/api/articles/new` (should be `/api/v1/articles`)
- `/api/articles/{id}` (should be `/api/v1/articles/{id}`)
- `/api/articles/{id}/edit` (should be `/api/v1/articles/{id}`)
- `/api/articles/{id}` (DELETE, should be `/api/v1/articles/{id}`)
- `/api/articles/list` (should be `/api/v1/articles`)

Compliant endpoints:
- ✓ ALL Media endpoints use `/api/v1/media`
- ✓ ALL Review endpoints use `/api/v1/reviews`

**Quantitative Evidence:** 5/11 endpoints (45%) violate mandatory versioning requirement

**Impact:**
- API versioning strategy becomes fragmented and unenforceable
- Future API version upgrades cannot be managed consistently
- Client code must handle two different URL patterns
- API gateway routing rules become complex and error-prone
- **Adversarial exploitation:** Developers could argue versioning is "optional" based on Article endpoint precedent

**Recommendation:**
Add `/v1` to all Article endpoints:
- `/api/articles/*` → `/api/v1/articles/*`

Additionally, address RESTful design violations (see Issue 5).

---

#### 4. HTTP Library Specification Conflict
**Category:** Implementation Pattern Consistency
**Type:** Combined Issue (Conflicting Documentation)

**Finding:**
Direct contradiction between two sections:

- **Section 2.2 (主要ライブラリ):** Lists "HTTP通信: OkHttp 4.12"
- **Section 8.1.3 (実装パターン):** States "HTTP通信ライブラリ: RestTemplateを使用（WebClient不使用）"

**Impact:**
- Implementation team cannot determine which library to use
- If OkHttp is used, it violates existing system standards (8.1.3)
- If RestTemplate is used, the dependency declaration (2.2) is incorrect
- Mixed HTTP client usage creates inconsistent error handling, timeout configuration, and logging patterns
- **Adversarial exploitation:** Developers could justify using either library by citing different sections

**Recommendation:**
1. **If RestTemplate is the established standard:** Remove OkHttp from section 2.2, confirm RestTemplate usage
2. **If OkHttp is intentionally adopted:** Document explicit justification for deviating from existing RestTemplate standard in section 8.1.3, and update pattern documentation

**Required action:** Clarify which library is authoritative and resolve the documentation conflict.

---

#### 5. Transaction Management Boundary Gap (Critical Documentation Gap)
**Category:** Implementation Pattern Consistency
**Type:** Information Gap

**Finding:**
Section 6.3 states: "複数エンティティの更新が必要な場合は、各Repositoryメソッドを個別に呼び出す"

**Missing critical information:**
- Are these calls wrapped in a `@Transactional` boundary?
- At which layer are transaction boundaries defined? (Service layer? Repository layer? Controller layer?)
- What consistency guarantees exist for multi-entity updates?
- What is the transaction propagation strategy?
- How are transaction rollbacks handled?

**Impact:**
- Developers cannot implement multi-entity operations consistently
- Data consistency guarantees become undefined
- Rollback behavior becomes unpredictable
- Different modules may adopt different transaction strategies
- **Adversarial exploitation:** Developers could justify either transactional or non-transactional implementations, leading to data integrity issues
- **Critical risk:** Workflow module (Article + Review updates) could exhibit race conditions or partial update failures

**Recommendation:**
Add explicit transaction management documentation:
```markdown
### 6.3.1 Transaction Boundary Definition
- Transaction boundaries are defined at the Service layer using `@Transactional`
- Each public service method represents a single transaction boundary
- Repository methods execute within the transaction context of the calling service method
- Multi-entity updates use Service-layer transaction coordination:
  ```java
  @Service
  public class ArticleService {
      @Transactional
      public void publishArticle(Long articleId, Long reviewerId) {
          articleRepository.updateStatus(articleId, "published");
          reviewRepository.createReview(articleId, reviewerId);
          // Both updates commit or rollback together
      }
  }
  ```
- Transaction propagation: REQUIRED (default)
- Rollback policy: RuntimeException triggers rollback
```

---

#### 6. API Response Format Specification Conflict
**Category:** API/Interface Design Consistency
**Type:** Combined Issue (Multiple Conflicting Specifications)

**Finding:**
Three different response format specifications exist in the document:

1. **Section 5.2.2 (success response):**
   ```json
   {
     "success": true,
     "data": { "id": 123, "title": "...", "status": "draft" },
     "message": "Article created successfully"
   }
   ```

2. **Section 5.2.3 (error response):**
   ```json
   {
     "error": { "code": "VALIDATION_ERROR", "message": "Title is required" }
   }
   ```

3. **Section 8.1.3 (established standard):**
   ```
   レスポンス形式: `{data, error}` 形式（既存APIとの統一）
   ```

**Analysis:**
These three formats are **mutually incompatible**:
- Section 5.2.2 uses `success`/`data`/`message` (3 fields)
- Section 5.2.3 uses `error` object (1 field)
- Section 8.1.3 requires `data`/`error` (2 fields, mutually exclusive)

**Impact:**
- API client code cannot parse responses consistently
- Existing system integration will fail (violates 8.1.3 standard)
- Error detection logic becomes ambiguous (check `success === false` or `error !== null`?)
- **Adversarial exploitation:** Developers could implement any of the three formats and cite documentation support

**Recommendation:**
Adopt the established `{data, error}` format (section 8.1.3) for ALL responses:

**Success response:**
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

**Error response:**
```json
{
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Title is required"
  }
}
```

Update sections 5.2.2 and 5.2.3 to reflect this standard. Remove `success` and `message` fields from examples.

---

### Significant Issues

#### 7. Foreign Key Naming Inconsistency (60% Compliance)
**Category:** Naming Convention Consistency
**Type:** Pattern Inconsistency

**Finding:**
Section 8.1.1 documents: "外部キー列名: `{参照先テーブル名}_id` 形式（例: `user_id`, `article_id`）"

**Violations:**
- `uploaded_by` (Media table) - should be `uploader_id` or `user_id`
- `reviewer` (Review table) - should be `reviewer_id`

**Compliant:**
- ✓ `author_id` (Article table)
- ✓ `article_id` (Review table)
- ✓ `uploaded_by` reference (Media table - target is correct: `user.id`)

**Quantitative Evidence:** 2/5 foreign key columns violate naming pattern (40% non-compliance)

**Semantic Analysis:**
- `uploaded_by` uses verb-based naming instead of role-based (`uploader_id`)
- `reviewer` omits `_id` suffix entirely
- Pattern shows inconsistency: `author_id` (role+`_id`) vs `uploaded_by` (verb+`_by`) vs `reviewer` (role, no suffix)

**Impact:**
- Foreign key identification becomes inconsistent (cannot reliably identify FKs by `_id` suffix)
- ORM relationship mapping must handle multiple patterns
- Database schema inspection tools may not recognize all foreign keys
- **Adversarial exploitation:** Future developers could justify any foreign key naming variant

**Recommendation:**
Standardize to role-based `_id` pattern:
- `uploaded_by` → `uploader_id` (alternatively `user_id` if uploader role is not semantically important)
- `reviewer` → `reviewer_id`

---

#### 8. API Action Naming Violation (Non-RESTful Design)
**Category:** API/Interface Design Consistency
**Type:** Pattern Inconsistency

**Finding:**
Section 8.1.2 requires: "HTTPメソッド: RESTful規約に従う（GET/POST/PUT/DELETE）"

**Violations - ALL Article endpoints use action-based paths:**
- `POST /api/articles/new` - action suffix `/new` violates RESTful principles
  - Should be: `POST /api/v1/articles` (resource creation uses POST without action suffix)
- `PUT /api/articles/{id}/edit` - action suffix `/edit` violates RESTful principles
  - Should be: `PUT /api/v1/articles/{id}` (resource update uses PUT without action suffix)
- `GET /api/articles/list` - action suffix `/list` violates RESTful principles
  - Should be: `GET /api/v1/articles` (collection retrieval uses plural resource name)

**Compliant endpoints:**
- ✓ ALL Media endpoints use RESTful resource-based paths (`/api/v1/media`, `/api/v1/media/{id}`)
- ✓ ALL Review endpoints use RESTful resource-based paths

**Impact:**
- Two incompatible API design patterns exist in the same system (action-based vs resource-based)
- API inconsistency confuses developers and clients
- RESTful conventions become unenforceable
- Client code must handle different URL construction patterns for different resources
- **Adversarial exploitation:** Developers could argue action-based URLs are acceptable based on Article precedent

**Recommendation:**
Remove action suffixes from Article endpoints:
- `POST /api/articles/new` → `POST /api/v1/articles`
- `PUT /api/articles/{id}/edit` → `PUT /api/v1/articles/{id}`
- `GET /api/articles/list` → `GET /api/v1/articles`
- `GET /api/articles/{id}` → `GET /api/v1/articles/{id}` (also add `/v1`)
- `DELETE /api/articles/{id}` → `DELETE /api/v1/articles/{id}` (also add `/v1`)

---

#### 9. Response Format Specification Gaps (Incomplete Documentation)
**Category:** API/Interface Design Consistency
**Type:** Information Gap

**Finding:**
Section 5.2.2 provides single-item response example, section 5.2.3 provides error example, but critical response format aspects are undocumented:

**Missing specifications:**
- **List/collection response format:** How are multiple items returned? Directly as array in `data` field?
  ```json
  {"data": [{...}, {...}], "error": null}
  ```
  Or nested under a key?
  ```json
  {"data": {"items": [{...}, {...}]}, "error": null}
  ```

- **Pagination format:** How are paginated lists structured?
  - Cursor-based or offset-based pagination?
  - Where are pagination metadata placed? (`total`, `page`, `pageSize`, `nextCursor`)

- **Empty result format:** Is empty list represented as `{"data": [], "error": null}` or `{"data": null, "error": null}`?

- **Partial success scenarios:** How are batch operations with partial failures represented?

**Impact:**
- List endpoints (`GET /api/articles/list`) implementation becomes inconsistent
- Pagination implementation varies across modules
- Client code cannot handle collections uniformly
- **Adversarial exploitation:** Developers could implement any list format and claim "it wasn't specified"

**Recommendation:**
Add comprehensive response format specification:

```markdown
### 5.2.4 Collection Response Format
**List response (non-paginated):**
```json
{
  "data": [
    {"id": 1, "title": "Article 1"},
    {"id": 2, "title": "Article 2"}
  ],
  "error": null
}
```

**Paginated response:**
```json
{
  "data": {
    "items": [{"id": 1, ...}, {"id": 2, ...}],
    "pagination": {
      "total": 100,
      "page": 1,
      "pageSize": 20,
      "totalPages": 5
    }
  },
  "error": null
}
```

**Empty result:**
```json
{
  "data": [],
  "error": null
}
```
```

---

#### 10. Entity-API Naming Misalignment
**Category:** Naming Convention Consistency + API/Interface Design Consistency
**Type:** Pattern Inconsistency

**Finding:**
Inconsistency between entity naming, table naming, and API resource naming for Media:

- **Entity name:** `Media` (singular)
- **Primary key:** `media_id` (prefixed, violates PK standard - see Issue 2)
- **Table name:** `media` (implied singular)
- **API resource:** `/api/v1/media` (appears singular)
- **Section 8.1.1 example:** Lists `media_file` as table naming example
- **Section 8.1.2 standard:** "リソース名: 複数形、ケバブケース"

**Analysis:**
- API standard requires plural resource names → `/api/v1/media` should be `/api/v1/media-files` or `/api/v1/media-items`
- Existing system example shows `media_file` (compound naming) but design uses `media` (single word)
- Ambiguity: Is `media` singular (like "sheep") or plural? In English, "media" can be plural of "medium"

**Impact:**
- API naming convention becomes unenforceable (is singular `media` acceptable or not?)
- Table naming pattern unclear (when to use compound names like `media_file` vs simple names?)
- Future resources may exhibit similar ambiguity
- **Adversarial exploitation:** Developers could argue singular resource names are acceptable

**Recommendation:**
**Option A (Align with existing `media_file` pattern):**
- Table: `media` → `media_file`
- API: `/api/v1/media` → `/api/v1/media-files`
- Primary key: `media_id` → `id` (standard compliance)

**Option B (Keep `media` if semantically plural):**
- Clarify that `media` is treated as plural form
- API: Keep `/api/v1/media` (acceptable if `media` = plural)
- Primary key: `media_id` → `id` (standard compliance)
- Document this exception explicitly

**Recommended:** Option A for consistency with section 8.1.1 example.

---

#### 11. Dual API Design Pattern (Fragmented API Standards)
**Category:** API/Interface Design Consistency
**Type:** Pattern Inconsistency

**Finding:**
Two incompatible API design patterns coexist in the same system:

**Pattern A (Action-based) - Article endpoints:**
- Uses action suffixes: `/new`, `/edit`, `/list`
- Non-RESTful design
- 5 endpoints follow this pattern

**Pattern B (Resource-based) - Media & Review endpoints:**
- Pure RESTful resource design
- No action suffixes
- 6 endpoints follow this pattern

**Quantitative Evidence:** 45% of endpoints use non-RESTful action-based pattern

**Impact:**
- API design standards cannot be enforced consistently
- New module developers receive mixed signals about API design
- Client code must implement different URL construction logic per resource type
- API documentation appears inconsistent and unprofessional
- **Adversarial exploitation:** Future modules could adopt either pattern and claim precedent

**Recommendation:**
Consolidate to single RESTful pattern (Pattern B):
- Remediate all Article endpoints per Issue 8 recommendations
- Document explicit prohibition of action suffixes in API paths
- Add to section 8.1.2: "パスには動詞を含めない（RESTful原則に従い、HTTPメソッドで動作を表現）"

---

### Moderate Issues

#### 12. Column Case Convention Mixing (Intra-Entity Inconsistency)
**Category:** Naming Convention Consistency
**Type:** Pattern Inconsistency

**Finding:**
User table exhibits mixed case conventions within a single entity:

- `user_name`: snake_case ✓ (compliant with section 8.1.1)
- `createdAt`: camelCase ✗ (violates section 8.1.1)
- `updatedAt`: camelCase ✗ (violates section 8.1.1)

**Impact:**
- Single entity violates its own naming consistency
- Suggests lack of systematic pattern application
- ORM field mapping becomes inconsistent within single entity class
- **Adversarial exploitation:** Could be cited to justify case mixing in future entities

**Recommendation:**
Enforce uniform snake_case across ALL columns in User table:
- `createdAt` → `created_at`
- `updatedAt` → `updated_at`

(Note: This overlaps with Issue 1 remediation)

---

#### 13. Configuration Management Standards Gap
**Category:** Implementation Pattern Consistency
**Type:** Information Gap

**Finding:**
Section 2.3 mentions various infrastructure components (Docker, Kubernetes, AWS), but NO configuration management standards are documented:

**Missing information:**
- Configuration file format standard (YAML vs JSON vs .properties)
- Environment variable naming convention (e.g., `UPPERCASE_SNAKE_CASE` with prefix?)
- Configuration file naming pattern (e.g., `application.yml`, `application-{env}.yml`)
- Configuration file placement directory
- Sensitive credential handling approach (environment variables, secrets management, config server)

**Impact:**
- Configuration files may use mixed formats (some YAML, some JSON, some .properties)
- Environment variable naming becomes inconsistent
- Configuration organization varies across modules
- **Adversarial exploitation:** Developers could use any configuration approach and claim it wasn't specified

**Recommendation:**
Add configuration management section:

```markdown
### 6.6 Configuration Management Standards
- **Configuration file format:** YAML (application.yml) for all application configuration
- **Environment variable naming:** UPPERCASE_SNAKE_CASE with `APP_` prefix (e.g., `APP_DATABASE_URL`, `APP_JWT_SECRET`)
- **Configuration file structure:**
  - Base configuration: `src/main/resources/application.yml`
  - Environment-specific: `application-{env}.yml` (e.g., application-prod.yml)
- **Sensitive credentials:** NEVER commit to repository; use environment variables or AWS Secrets Manager
- **Configuration precedence:** Environment variables override YAML configuration
```

---

#### 14. Logging Implementation Library Gap
**Category:** Implementation Pattern Consistency
**Type:** Information Gap

**Finding:**
Section 6.2 specifies logging policy (levels, format, production output) but omits implementation details:

**Missing information:**
- Which logging library/framework? (SLF4J + Logback, SLF4J + Log4j2, java.util.logging?)
- Structured logging format? (JSON logs for machine parsing?)
- Correlation ID handling for distributed tracing?
- Log aggregation integration? (format requirements for Elasticsearch, CloudWatch Logs)

**Impact:**
- Logging library selection varies across modules
- Log format becomes inconsistent (some JSON, some plain text)
- Distributed tracing cannot correlate requests across services
- Log aggregation parsing may fail
- **Adversarial exploitation:** Developers could use any logging library and claim standard compliance

**Recommendation:**
Add logging implementation specification:

```markdown
### 6.2.1 Logging Implementation
- **Library:** SLF4J (facade) + Logback (implementation)
- **Log format (production):** JSON structured logs
  ```json
  {
    "timestamp": "2024-01-15T10:30:45.123Z",
    "level": "INFO",
    "logger": "com.example.ArticleService",
    "message": "Article created successfully",
    "correlationId": "abc-123-def",
    "userId": 456,
    "articleId": 789
  }
  ```
- **Correlation ID:** Include `X-Correlation-ID` from request header in all log entries
- **MDC (Mapped Diagnostic Context):** Use for correlation ID and user context propagation
```

---

#### 15. Authentication Token Storage Consistency Gap
**Category:** Implementation Pattern Consistency
**Type:** Information Gap

**Finding:**
Section 5.3 specifies: "トークン保存先: ブラウザのlocalStorageに保存"

**Missing information:**
- Is this consistent with existing authentication modules in the platform?
- No reference to existing system's token storage approach
- No documentation in section 8.1 about established authentication patterns

**Impact:**
- Authentication approach may diverge from existing modules
- SSO (Single Sign-On) integration could fail if token storage is inconsistent
- Session management fragmentation across platform modules
- **Potential gap:** If existing modules use httpOnly cookies, this localStorage approach is incompatible

**Recommendation:**
Cross-reference with existing authentication modules:
1. Verify existing platform's token storage approach (localStorage, sessionStorage, httpOnly cookie)
2. If localStorage is established pattern: Document in section 8.1.3 as standard
3. If different approach is established: Update section 5.3 to align with existing pattern
4. Add to section 8.1: "認証トークン保存: [existing pattern] を使用（プラットフォーム全体で統一）"

---

### Minor Issues

#### 16. Implicit Table Naming Pattern (Documentation Enhancement)
**Category:** Naming Convention Consistency
**Type:** Information Gap (Low Impact)

**Finding:**
Section 8.1.1 provides example `media_file` (compound naming with underscore) but design uses simple names (`article`, `user`, `media`, `review`):

**Unclear pattern:**
- When should compound names be used? (`media_file`, `user_profile`, `article_category`)
- When are simple names acceptable? (`article`, `user`, `media`)

**Impact:**
- Future entity naming decisions lack clear guidance
- Developers must guess whether to use compound or simple names
- Minor impact as pattern can be inferred from examples

**Recommendation:**
Add explicit guideline to section 8.1.1:

```markdown
テーブル名:
- 単数形、スネークケース
- 単一概念は単語1つ（例: `article`, `user`）
- 複合概念はアンダースコアで結合（例: `media_file`, `user_profile`）
- 略語は避ける（例: `usr` ✗ → `user` ✓）
```

---

#### 17. Timestamp Field Semantic Inconsistency (Vocabulary Choice)
**Category:** Naming Convention Consistency
**Type:** Pattern Inconsistency (Low Impact)

**Finding:**
Review table uses `modified` instead of `updated` for update timestamp:

- Article: `created`, `updated`
- User: `createdAt`, `updatedAt`
- Media: `created_at`, `updated_at`
- Review: `created`, `modified` ✗

**Analysis:**
All other entities use `update`-based naming, but Review uses `modified` (synonym but inconsistent vocabulary choice).

**Impact:**
- Vocabulary inconsistency creates minor confusion
- Timestamp querying requires remembering different field names per entity
- Minor impact (overlaps with Issue 1 which addresses format)

**Recommendation:**
Standardize verb to `updated`:
- Review: `modified` → `updated_at` (also addresses format issue from Issue 1)

---

#### 18. Foreign Key Semantic Naming Inconsistency (Design Pattern)
**Category:** Naming Convention Consistency
**Type:** Pattern Inconsistency (Low Impact)

**Finding:**
Foreign key naming uses inconsistent semantic approaches:

- **Role-based naming:** `author_id` (role: author), `reviewer_id` (recommended fix for `reviewer`)
- **Verb-based naming:** `uploaded_by` (verb: upload)
- **Generic naming:** Alternative would be `user_id` for all user references

**Analysis:**
Three potential patterns exist:
1. Role-specific: `author_id`, `reviewer_id`, `uploader_id` (most descriptive)
2. Generic: `user_id` everywhere (less descriptive, requires context)
3. Mixed: Current design (inconsistent)

**Impact:**
- Minor semantic inconsistency
- Does not affect functionality but reduces pattern clarity
- Role-based naming is more descriptive (preferred)

**Recommendation:**
Adopt role-based naming consistently:
- Keep: `author_id`, `reviewer_id` (after fixing `reviewer` → `reviewer_id`)
- Change: `uploaded_by` → `uploader_id`
- Document in section 8.1.1: "外部キー列名: ユーザー参照は役割名を使用（例: `author_id`, `reviewer_id`, `uploader_id`）"

---

## Pattern Evidence

### Codebase Pattern References

All pattern evidence is derived from **explicit documentation in section 8.1 (既存システム前提条件)**, which documents established conventions in the existing platform.

#### Database Naming Conventions (Section 8.1.1)
- **Table naming:** 単数形、スネークケース (singular, snake_case)
  - Example provided: `user`, `article`, `media_file`
- **Column naming:** スネークケース (snake_case)
  - Example provided: `user_name`, `created_at`, `updated_at`
- **Primary key:** `id` (no table prefix)
  - Explicitly stated: "テーブル名プレフィックスなし"
- **Foreign key:** `{参照先テーブル名}_id` format
  - Examples provided: `user_id`, `article_id`
- **Timestamp columns:** `created_at`, `updated_at` (underscore, `_at` suffix, past participle)
  - Explicitly stated: "アンダースコア付き、過去分詞形"

**Compliance measurement:**
- Timestamp naming: 1/4 entities compliant (25%)
- Primary key naming: 2/4 entities compliant (50%)
- Foreign key naming: 3/5 columns compliant (60%)

#### API Endpoint Conventions (Section 8.1.2)
- **Path prefix:** `/api/v1/` (versioning mandatory)
  - Explicitly stated: "バージョニング必須"
- **Resource naming:** 複数形、ケバブケース (plural, kebab-case)
  - Examples provided: `/api/v1/articles`, `/api/v1/media-files`
- **HTTP methods:** RESTful standard (GET/POST/PUT/DELETE)
  - Explicitly stated: "RESTful規約に従う"

**Compliance measurement:**
- Versioning: 6/11 endpoints compliant (55% compliance, 45% violation)
- RESTful design: 6/11 endpoints compliant (55%)

#### Implementation Patterns (Section 8.1.3)
- **HTTP client:** RestTemplate (explicitly stated, WebClient not used)
- **Response format:** `{data, error}` format (explicitly stated for platform consistency)

**Conflict detection:**
- Section 2.2 lists OkHttp 4.12 (contradicts RestTemplate requirement)
- Section 5.2.2/5.2.3 show different response formats (contradict `{data, error}` requirement)

#### Architecture Patterns (Section 3.1)
- **Layer composition:** Presentation → Business Logic → Data Access (3-layer)
- **Dependency direction:** Unidirectional top-down

**Gap detection:**
- Transaction boundary layer: NOT documented (critical gap)

---

## Impact Analysis

### High-Impact Consequences

#### 1. Data Model Fragmentation (Issues 1, 2, 3, 7, 12)
**Consequence:**
Database schema exhibits 0-60% compliance with documented naming standards. This creates:
- **ORM mapping inconsistency:** Entity classes cannot use uniform mapping conventions
- **Query complexity:** Timestamp filtering requires entity-specific field names (`created` vs `created_at` vs `createdAt`)
- **Foreign key ambiguity:** Mixed patterns prevent reliable FK identification
- **Maintenance burden:** Future schema changes require tracking multiple naming variants

**Quantitative impact:**
- 9 naming violations across 4 entities
- 0% timestamp standard compliance
- Affects 100% of entities in the data model

**Adversarial exploitation potential:**
Developers adding new entities can point to ANY existing entity as justification for their chosen naming style, enabling progressive codebase fragmentation.

---

#### 2. API Integration Fragmentation (Issues 3, 5, 6, 10, 11)
**Consequence:**
API design exhibits dual incompatible patterns and missing mandatory versioning:

**Client integration impact:**
- Client code must implement two different URL construction patterns (action-based vs resource-based)
- Response parsing must handle three different format specifications
- API version management is impossible for Article endpoints (no `/v1/`)

**Integration testing impact:**
- Test fixtures cannot use uniform API client patterns
- Mock server implementations must handle multiple response formats
- E2E tests become fragile due to inconsistent endpoints

**Platform integration risk:**
- Existing platform modules expect `/api/v1/` prefix (45% of endpoints violate this)
- Existing platform modules expect `{data, error}` response format (100% of example responses violate this)
- **Critical risk:** Production integration failures likely

**Quantitative impact:**
- 5/11 endpoints missing version prefix (45%)
- 5/11 endpoints using non-RESTful design (45%)
- 3 conflicting response format specifications

---

#### 3. HTTP Client Implementation Conflict (Issue 4)
**Consequence:**
Direct contradiction between OkHttp (section 2.2) and RestTemplate (section 8.1.3):

**Development team paralysis:**
- Cannot proceed with HTTP client implementation without clarification
- Risk of mixed implementation (some modules use OkHttp, others use RestTemplate)

**If OkHttp is used:**
- Violates existing platform standard (section 8.1.3)
- Platform-wide HTTP client configuration becomes fragmented
- Error handling, timeout configuration, and retry logic becomes inconsistent

**If RestTemplate is used:**
- Dependency declaration (section 2.2) is incorrect
- Build configuration and dependency management is wrong

**Impact on related patterns:**
- External API integration patterns become inconsistent
- HTTP logging and monitoring cannot be standardized
- Security configurations (SSL, proxy, authentication) vary across modules

---

#### 4. Transaction Consistency Risk (Issue 5 - Information Gap)
**Consequence:**
Missing transaction boundary documentation creates **critical data consistency risk**:

**Multi-entity operation scenarios:**
- Article publication (update Article status + create Review record)
- Media upload (create Media record + update Article media references)
- User deletion (cascade delete across Article, Review, Media)

**Without explicit transaction boundaries:**
- Partial updates possible (Article updated but Review creation fails)
- Race conditions in concurrent workflows
- Data integrity violations
- Rollback behavior undefined

**Adversarial exploitation scenario:**
```java
// Developer A implements with transaction (data safe)
@Transactional
public void publishArticle(Long articleId, Long reviewerId) {
    articleRepository.updateStatus(articleId, "published");
    reviewRepository.createReview(articleId, reviewerId);
}

// Developer B implements without transaction (data unsafe)
public void publishArticle(Long articleId, Long reviewerId) {
    articleRepository.updateStatus(articleId, "published");
    // If this fails, article is published without review record
    reviewRepository.createReview(articleId, reviewerId);
}
```

Both implementations can cite section 6.3 as justification ("各Repositoryメソッドを個別に呼び出す").

**Potential production failures:**
- Inconsistent Article-Review state
- Orphaned records
- Workflow state machine corruption

---

### Moderate-Impact Consequences

#### 5. Configuration Management Fragmentation (Issue 13)
**Consequence:**
Missing configuration standards enable:
- Mixed file formats (YAML, JSON, .properties)
- Inconsistent environment variable naming
- Configuration file placement varies
- Difficult configuration management in Kubernetes environment

**DevOps impact:**
- Configuration deployment scripts must handle multiple formats
- Environment variable injection becomes complex
- Configuration validation cannot be standardized

---

#### 6. Logging Inconsistency (Issue 14)
**Consequence:**
Missing logging implementation standards create:
- Mixed logging libraries across modules
- Log format inconsistency (plain text vs JSON)
- Correlation ID handling varies or absent
- Log aggregation parsing failures

**Operations impact:**
- Elasticsearch log parsing requires multiple parsers
- Distributed tracing impossible without consistent correlation IDs
- Debugging production issues becomes difficult

---

#### 7. Authentication Integration Risk (Issue 15)
**Consequence:**
Token storage approach (localStorage) not verified against existing platform standards:

**Potential integration failure:**
- If existing modules use httpOnly cookies, SSO integration fails
- Session management becomes fragmented across platform
- Authentication state synchronization issues

**User experience impact:**
- Users may need to log in separately for this module vs existing modules
- Session timeout behavior inconsistent

---

## Recommendations

### Immediate Priority (Critical Issues - Block Implementation)

These issues **MUST** be resolved before implementation begins:

#### R1. Database Schema Standardization (Issues 1, 2, 3, 7, 12, 17, 18)
**Action:** Revise section 4 data model to achieve 100% compliance with section 8.1.1 standards.

**Complete entity revisions:**

**Article table:**
```diff
- | created | TIMESTAMP | NOT NULL, DEFAULT NOW() | 作成日時 |
- | updated | TIMESTAMP | NOT NULL, DEFAULT NOW() | 更新日時 |
+ | created_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | 作成日時 |
+ | updated_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | 更新日時 |
```

**User table:**
```diff
- | createdAt | TIMESTAMP | NOT NULL | 作成日時 |
- | updatedAt | TIMESTAMP | NOT NULL | 更新日時 |
+ | created_at | TIMESTAMP | NOT NULL | 作成日時 |
+ | updated_at | TIMESTAMP | NOT NULL | 更新日時 |
```

**Media table:**
```diff
- | media_id | BIGINT | PK | メディアID |
+ | id | BIGINT | PK | メディアID |
```
```diff
- | uploaded_by | BIGINT | FK → user.id | アップロードユーザーID |
+ | uploader_id | BIGINT | FK → user.id | アップロードユーザーID |
```

**Review table:**
```diff
- | review_id | BIGINT | PK | レビューID |
+ | id | BIGINT | PK | レビューID |
```
```diff
- | reviewer | BIGINT | FK → user.id | レビュアーID |
+ | reviewer_id | BIGINT | FK → user.id | レビュアーID |
```
```diff
- | created | TIMESTAMP | NOT NULL | 作成日時 |
- | modified | TIMESTAMP | NOT NULL | 更新日時 |
+ | created_at | TIMESTAMP | NOT NULL | 作成日時 |
+ | updated_at | TIMESTAMP | NOT NULL | 更新日時 |
```

**Update foreign key constraints section 4.2:**
```diff
- media.uploaded_by → user.id
+ media.uploader_id → user.id
- review.reviewer → user.id
+ review.reviewer_id → user.id
```

**Verification:** After changes, ALL entities should match section 8.1.1 standards (100% compliance).

---

#### R2. API Design Standardization (Issues 3, 5, 8, 10, 11)
**Action:** Revise section 5 API design to achieve consistency with section 8.1.2 and RESTful principles.

**Article endpoint revisions:**
```diff
- POST /api/articles/new
+ POST /api/v1/articles

- GET /api/articles/{id}
+ GET /api/v1/articles/{id}

- PUT /api/articles/{id}/edit
+ PUT /api/v1/articles/{id}

- DELETE /api/articles/{id}
+ DELETE /api/v1/articles/{id}

- GET /api/articles/list
+ GET /api/v1/articles
```

**Media endpoint revisions (if adopting media_file naming):**
```diff
- POST /api/v1/media
+ POST /api/v1/media-files

- GET /api/v1/media/{id}
+ GET /api/v1/media-files/{id}

- DELETE /api/v1/media/{id}
+ DELETE /api/v1/media-files/{id}
```

**Prohibit action suffixes - add to section 8.1.2:**
```markdown
- パスには動詞を含めない（`/new`, `/edit`, `/list` 等の動詞サフィックスは使用禁止）
- HTTPメソッドで動作を表現する（POST=作成, GET=取得, PUT=更新, DELETE=削除）
```

---

#### R3. Response Format Standardization (Issue 6)
**Action:** Replace sections 5.2.2 and 5.2.3 with unified `{data, error}` format per section 8.1.3.

**Replace section 5.2.2 (success response):**
```markdown
#### 5.2.2 成功レスポンス形式
**Single resource:**
​```json
{
  "data": {
    "id": 123,
    "title": "記事タイトル",
    "status": "draft"
  },
  "error": null
}
​```

**Collection (non-paginated):**
​```json
{
  "data": [
    {"id": 1, "title": "Article 1"},
    {"id": 2, "title": "Article 2"}
  ],
  "error": null
}
​```

**Collection (paginated):**
​```json
{
  "data": {
    "items": [
      {"id": 1, "title": "Article 1"},
      {"id": 2, "title": "Article 2"}
    ],
    "pagination": {
      "total": 100,
      "page": 1,
      "pageSize": 20,
      "totalPages": 5
    }
  },
  "error": null
}
​```

**Empty result:**
​```json
{
  "data": [],
  "error": null
}
​```
```

**Replace section 5.2.3 (error response):**
```markdown
#### 5.2.3 エラーレスポンス形式
​```json
{
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Title is required",
    "details": {
      "field": "title",
      "rejectedValue": null
    }
  }
}
​```
```

**Note:** Remove `success` and `message` fields entirely. Client checks `error === null` for success detection.

---

#### R4. HTTP Client Library Clarification (Issue 4)
**Action:** Resolve OkHttp vs RestTemplate conflict.

**Decision required:** Choose ONE of the following:

**Option A (Adopt existing standard - RECOMMENDED):**
1. Remove OkHttp from section 2.2
2. Add RestTemplate to section 2.2:
   ```markdown
   - HTTP通信: Spring RestTemplate
   ```
3. Keep section 8.1.3 unchanged

**Option B (Adopt new library with justification):**
1. Keep OkHttp in section 2.2
2. Update section 8.1.3 with explicit deviation justification:
   ```markdown
   - HTTP通信ライブラリ: OkHttp 4.12 を使用
     - 既存標準(RestTemplate)からの変更理由: [具体的な技術的理由を記載]
     - 影響範囲: 本モジュールのみ / プラットフォーム全体への移行計画
   ```

**Implementation team:** Cannot proceed without this decision.

---

#### R5. Transaction Management Documentation (Issue 5)
**Action:** Add explicit transaction boundary specification to section 6.3.

**Add new subsection 6.3.1:**
```markdown
### 6.3.1 トランザクション管理
- **トランザクション境界:** Service層の各publicメソッドが1トランザクション単位
- **アノテーション:** `@Transactional` をService層メソッドに付与
- **伝播方式:** `REQUIRED` (デフォルト) - 既存トランザクションがあれば参加、なければ新規作成
- **ロールバック条件:** `RuntimeException` およびそのサブクラス発生時に自動ロールバック
- **複数エンティティ更新の実装例:**

​```java
@Service
public class ArticleService {
    @Autowired
    private ArticleRepository articleRepository;

    @Autowired
    private ReviewRepository reviewRepository;

    /**
     * 記事公開処理（記事ステータス更新 + レビュー記録作成を1トランザクションで実行）
     */
    @Transactional
    public void publishArticle(Long articleId, Long reviewerId) {
        // 両方の更新が成功するか、両方ロールバックされる
        Article article = articleRepository.findById(articleId)
            .orElseThrow(() -> new EntityNotFoundException("Article not found"));
        article.setStatus("published");
        articleRepository.save(article);

        Review review = new Review();
        review.setArticleId(articleId);
        review.setReviewerId(reviewerId);
        review.setStatus("approved");
        reviewRepository.save(review);
    }
}
​```

- **注意事項:**
  - Repository層メソッドは `@Transactional` を付与しない（Service層のトランザクションに参加）
  - 読み取り専用トランザクションは `@Transactional(readOnly = true)` を使用（パフォーマンス最適化）
```

---

### High Priority (Significant Issues - Complete Before Review)

#### R6. Configuration Management Standards (Issue 13)
**Action:** Add section 6.6 for configuration standards.

**Add new section:**
```markdown
## 6.6 設定管理方針

### 6.6.1 設定ファイル形式
- **形式:** YAML (application.yml) をすべての設定に使用
- **構成:**
  - ベース設定: `src/main/resources/application.yml`
  - 環境別設定: `src/main/resources/application-{env}.yml` (例: application-prod.yml)
- **優先順位:** 環境変数 > 環境別YAML > ベースYAML

### 6.6.2 環境変数命名規約
- **命名規則:** `UPPERCASE_SNAKE_CASE` with `APP_` prefix
- **例:**
  - `APP_DATABASE_URL`: データベース接続URL
  - `APP_JWT_SECRET`: JWT署名鍵
  - `APP_S3_BUCKET_NAME`: S3バケット名

### 6.6.3 機密情報管理
- **禁止事項:** 機密情報（パスワード、APIキー、トークン）をYAMLファイルにコミットしない
- **運用方針:**
  - 開発環境: 環境変数または `application-local.yml` (gitignore対象)
  - 本番環境: AWS Secrets Manager または Kubernetes Secrets
- **設定参照例:**
  ```yaml
  # application.yml
  spring:
    datasource:
      url: ${APP_DATABASE_URL}
      username: ${APP_DATABASE_USER}
      password: ${APP_DATABASE_PASSWORD}
  ```
```

---

#### R7. Logging Implementation Standards (Issue 14)
**Action:** Expand section 6.2 with implementation details.

**Add subsection 6.2.1:**
```markdown
### 6.2.1 ロギング実装仕様
- **ライブラリ:** SLF4J (ファサード) + Logback (実装)
- **設定ファイル:** `src/main/resources/logback-spring.xml`

### 6.2.2 ログ出力形式
- **開発環境:** 人間可読形式（コンソール出力、色付き）
- **本番環境:** JSON構造化ログ（ログ集約・解析対応）

**本番環境JSON形式例:**
​```json
{
  "timestamp": "2026-02-11T10:30:45.123Z",
  "level": "INFO",
  "logger": "com.example.service.ArticleService",
  "thread": "http-nio-8080-exec-1",
  "message": "Article published successfully",
  "correlationId": "abc-123-def-456",
  "userId": 789,
  "articleId": 123,
  "duration": 145
}
​```

### 6.2.3 相関ID管理
- **目的:** 分散トレーシング、リクエスト追跡
- **実装:**
  - リクエストヘッダー `X-Correlation-ID` から取得
  - ヘッダーがない場合はUUID自動生成
  - SLF4J MDC (Mapped Diagnostic Context) に格納
  - すべてのログエントリに自動付与
- **実装例:**
  ```java
  @Component
  public class CorrelationIdFilter extends OncePerRequestFilter {
      @Override
      protected void doFilterInternal(HttpServletRequest request,
                                      HttpServletResponse response,
                                      FilterChain filterChain) {
          String correlationId = request.getHeader("X-Correlation-ID");
          if (correlationId == null) {
              correlationId = UUID.randomUUID().toString();
          }
          MDC.put("correlationId", correlationId);
          try {
              filterChain.doFilter(request, response);
          } finally {
              MDC.clear();
          }
      }
  }
  ```
```

---

#### R8. Authentication Token Storage Verification (Issue 15)
**Action:** Verify localStorage approach with existing platform standards.

**Required investigation:**
1. Check existing platform authentication modules for token storage approach
2. If localStorage is established standard → Document in section 8.1 as standard practice
3. If different approach (e.g., httpOnly cookie) is established → Update section 5.3 to align

**If localStorage is NOT established standard, revise section 5.3:**
```markdown
### 5.3 認証・認可方式
- JWT認証を採用
- トークンはリクエストヘッダー `Authorization: Bearer {token}` で送信
- トークン有効期限: 24時間
- **トークン保存先:** [既存システムと同じ方式を記載]
  - 例1 (httpOnly cookie方式): `Set-Cookie: auth_token=xxx; HttpOnly; Secure; SameSite=Strict`
  - 例2 (localStorage方式): `localStorage.setItem('auth_token', token)`
- **セキュリティ考慮事項:** [選択した方式のセキュリティ対策を記載]
```

**Add to section 8.1:**
```markdown
#### 8.1.5 認証方式
- 認証プロトコル: JWT (JSON Web Token)
- トークン保存: [既存システムと統一した方式]
- トークン有効期限: 24時間（プラットフォーム共通）
```

---

### Medium Priority (Moderate Issues - Improve Clarity)

#### R9. Table Naming Pattern Clarification (Issue 16)
**Action:** Add explicit guideline to section 8.1.1.

**Add to table naming rules:**
```markdown
- 単一概念は単語1つ（例: `user`, `article`, `review`）
- 複合概念はアンダースコアで結合（例: `media_file`, `user_profile`, `article_tag`）
- 略語は避ける（例: `usr` ✗ → `user` ✓, `art` ✗ → `article` ✓）
```

---

### Summary of Required Changes

**Total issues detected:** 18
**Critical (block implementation):** 6 issues → 5 recommendations (R1-R5)
**Significant (complete before review):** 5 issues → 3 recommendations (R6-R8)
**Moderate (improve clarity):** 4 issues → 1 recommendation (R9)
**Minor (low priority):** 3 issues → addressed within R1

**Estimated remediation effort:**
- Critical issues: 4-6 hours (schema redesign, API redesign, response format standardization)
- Significant issues: 2-3 hours (documentation additions)
- Total: 6-9 hours of design document revision

**Validation checklist after remediation:**
- [ ] All timestamp columns use `created_at`/`updated_at` format (100% compliance target)
- [ ] All primary keys use `id` without prefix (100% compliance target)
- [ ] All foreign keys use `{table}_id` format (100% compliance target)
- [ ] All API endpoints use `/api/v1/` prefix (100% compliance target)
- [ ] All API endpoints use RESTful resource-based paths (no action suffixes)
- [ ] All response format examples use `{data, error}` structure
- [ ] Transaction management boundaries explicitly documented
- [ ] HTTP client library conflict resolved (single source of truth)
- [ ] Configuration management standards documented
- [ ] Logging implementation standards documented

---

## Conclusion

This design document requires **significant revision** before implementation. The analysis identified **systematic consistency violations** across database naming (0% timestamp compliance), API design (45% missing versioning), and **critical documentation gaps** in transaction management.

**Key findings:**
1. **Data model:** 0/4 entities comply with timestamp naming standard; requires complete schema revision
2. **API design:** Two incompatible patterns (action-based vs RESTful); 45% missing mandatory versioning
3. **Response format:** Three conflicting specifications across different sections
4. **HTTP library:** Direct contradiction between dependency declaration and implementation requirement
5. **Transaction boundaries:** Critical gap enabling inconsistent multi-entity operation implementations

**Adversarial analysis revealed:** Multiple violations provide precedents that future developers could exploit to justify deviations from standards, progressively fragmenting the codebase.

**Information gap analysis revealed:** Missing documentation in transaction management, configuration standards, and logging implementation enables inconsistent implementations across modules.

**Recommended action:** Complete all R1-R5 (critical) recommendations before implementation begins. Address R6-R8 (significant) before design review approval. This will prevent accumulation of technical debt and ensure platform-wide consistency.
