# Consistency Review Report: Content Publishing Platform

## Inconsistencies Identified

### Critical Issues

#### 1. Timestamp Column Naming Fragmentation (4 Different Patterns)

**Finding**: The design document exhibits systematic inconsistency in timestamp column naming across all four tables:

- **Article table** (section 4.1.1): `created`, `updated`
- **User table** (section 4.1.2): `createdAt`, `updatedAt`
- **Media table** (section 4.1.3): `created_at`, `updated_at`
- **Review table** (section 4.1.4): `created`, `modified`

**Documented Standard** (section 8.1.1): "タイムスタンプ列名: `created_at`, `updated_at`（アンダースコア付き、過去分詞形）"

**Pattern Adoption Rate**: Only 1/4 tables (Media, 25%) follow the documented standard. The remaining 75% use divergent patterns.

**Adversarial Risk**: This fragmentation enables developers to justify any of four patterns when extending the system, making timestamp queries inconsistent across modules. JOIN operations and audit log implementations will require table-specific logic.

#### 2. API Versioning Inconsistency (5/11 Endpoints Omit Version Prefix)

**Finding**: Article management endpoints completely omit the `/v1/` version prefix:

**Non-compliant endpoints:**
- `POST /api/articles/new` (should be `POST /api/v1/articles`)
- `GET /api/articles/{id}` (should be `GET /api/v1/articles/{id}`)
- `PUT /api/articles/{id}/edit` (should be `PUT /api/v1/articles/{id}`)
- `DELETE /api/articles/{id}` (should be `DELETE /api/v1/articles/{id}`)
- `GET /api/articles/list` (should be `GET /api/v1/articles`)

**Compliant endpoints:**
- `/api/v1/media/*` (6 endpoints)
- `/api/v1/reviews/*` (3 endpoints)

**Documented Standard** (section 8.1.2): "パスプレフィックス: `/api/v1/` 形式（バージョニング必須）"

**Pattern Adoption Rate**: 54.5% (6/11) endpoints follow the documented standard.

**Adversarial Risk**: Unversioned endpoints cannot evolve without breaking changes. Client code will need to implement two different base URL patterns, fragmenting API integration logic.

#### 3. HTTP Library Conflict (OkHttp vs RestTemplate)

**Finding**: The documented implementation standard conflicts with the declared dependency:

- **Section 2.2**: Lists "HTTP通信: OkHttp 4.12" as a primary library
- **Section 8.1.3**: States "HTTP通信ライブラリ: RestTemplateを使用（WebClient不使用）"

**Adversarial Risk**: Developers can justify either library choice, leading to two parallel HTTP client patterns. This doubles the debugging complexity and prevents centralized HTTP interceptor logic (logging, authentication, retry).

#### 4. Response Format Fragmentation (3 Incompatible Structures)

**Finding**: The design document presents three mutually incompatible response formats:

**Format 1** - Success response (section 5.2.2):
```json
{
  "success": true,
  "data": {...},
  "message": "Article created successfully"
}
```

**Format 2** - Error response (section 5.2.3):
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Title is required"
  }
}
```

**Format 3** - Documented standard (section 8.1.3):
```json
{
  "data": {...},
  "error": {...}
}
```

**Adversarial Risk**: Client code cannot use a unified response handler. Success responses require checking `success` field, while error responses require checking `error` field existence, and the documented standard uses yet another structure. This forces clients to implement three parsing strategies.

### Significant Issues

#### 5. Primary Key Naming Inconsistency (50% Non-Compliance)

**Finding**: Two of four tables violate the documented primary key naming standard:

**Compliant tables:**
- `article.id` ✓
- `user.id` ✓

**Non-compliant tables:**
- `media.media_id` ✗ (should be `media.id`)
- `review.review_id` ✗ (should be `review.id`)

**Documented Standard** (section 8.1.1): "主キー列名: `id`（テーブル名プレフィックスなし）"

**Impact**: ORM relationship mappings and JOIN queries must handle two different primary key naming patterns. This inconsistency propagates to foreign key references and makes generic repository patterns impossible.

#### 6. Table Naming Deviation (media vs media_file)

**Finding**: The Media table is named `media` (section 4.1.3), but the documented example shows compound table names should be underscored:

**Documented Standard** (section 8.1.1): "テーブル名: 単数形、スネークケース（例: `user`, `article`, `media_file`）"

The example explicitly lists `media_file` as the correct form, not `media`.

**Impact**: Compound table names will be inconsistent. If future tables for `media_category` or `media_tag` are added, developers can justify either `mediacategory` or `media_category` based on precedent.

#### 7. API Endpoint Style Mixing (RPC vs REST)

**Finding**: Article endpoints use RPC-style action suffixes while Media/Review use RESTful conventions:

**RPC-style (Article):**
- `POST /api/articles/new` (action suffix)
- `PUT /api/articles/{id}/edit` (action suffix)
- `GET /api/articles/list` (action suffix)

**RESTful (Media/Review):**
- `POST /api/v1/media` (resource-oriented)
- `PUT /api/v1/reviews/{id}` (resource-oriented)

**Documented Standard** (section 8.1.2): "HTTPメソッド: RESTful規約に従う（GET/POST/PUT/DELETE）"

**Impact**: Client SDKs and API documentation generators cannot assume a consistent style. The `/new`, `/edit`, `/list` suffixes violate REST principles where HTTP verbs should convey actions.

#### 8. Foreign Key Column Naming Ambiguity

**Finding**: The Review table uses `reviewer` instead of `reviewer_id`:

**Documented Standard** (section 8.1.1): "外部キー列名: `{参照先テーブル名}_id` 形式（例: `user_id`, `article_id`）"

**Pattern Application:**
- `article.author_id` ✓ (references user.id)
- `media.uploaded_by` ✗ (should be `uploader_id` or `uploaded_by_user_id`)
- `review.reviewer` ✗ (should be `reviewer_id`)

**Adversarial Risk**: The column name `reviewer` obscures that it is a foreign key. Developers unfamiliar with the schema might treat it as a VARCHAR username field. The `uploaded_by` pattern is slightly better but still deviates from the `{table}_id` standard.

### Moderate Issues

#### 9. Transaction Boundary Documentation Gap

**Finding**: Section 6.3 states "複数エンティティの更新が必要な場合は、各Repositoryメソッドを個別に呼び出す" but provides no guidance on transaction management.

**Missing Information:**
- Should services be annotated with `@Transactional`?
- What is the transaction isolation level?
- How should distributed transactions (S3 upload + database) be handled?

**Impact**: Without explicit transaction boundaries, article creation with workflow state and media associations could leave partial data if any step fails. The example code in section 6.1 shows no transaction annotation.

#### 10. Category Reference Inconsistency

**Finding**: The Article table and API request present incompatible category references:

- **Article table** (section 4.1.1): `category VARCHAR(50)` (stores category name as string)
- **API request** (section 5.2.1): `"categoryId": 1` (implies reference to category table)

No `category` table is defined in section 4.

**Impact**: This design conflict prevents referential integrity. If `categoryId` should reference a category table, the Article schema must use `category_id BIGINT FK`. If categories are free-text, the API should accept `"category": "tech"` instead of `categoryId`.

#### 11. Case Transformation Strategy Gap

**Finding**: The API layer uses camelCase JSON while the database uses snake_case columns, but no transformation strategy is documented:

- **JSON**: `categoryId`, `tags`, `authorId`
- **Database**: `category`, `author_id`, `created_at`

**Missing Information:**
- Does JPA handle this automatically via `@Column` naming strategy?
- Is Jackson configured with `PropertyNamingStrategy.SNAKE_CASE`?
- Are DTO classes responsible for transformation?

**Impact**: Without documented transformation rules, developers may implement inconsistent mapping logic (some manual, some automatic), leading to serialization bugs.

### Minor Issues

#### 12. Environment Variable Naming Pattern Gap

**Finding**: Section 8.1.1 states that existing systems have environment variable naming conventions, but no pattern is documented.

**Missing Information:**
- Format: `UPPER_SNAKE_CASE` vs `camelCase` vs `kebab-case`?
- Prefix conventions: `APP_`, `SERVICE_`, no prefix?
- Example: Database URL as `DATABASE_URL` or `DB_URL` or `POSTGRES_CONNECTION_STRING`?

#### 13. Validation Pattern Placement Gap

**Finding**: Hibernate Validator is listed (section 2.2), but validation placement is not specified:

**Missing Information:**
- Should controllers use `@Valid` on request parameters?
- Should services perform manual validation?
- Where should business rule validation occur vs syntactic validation?

## Pattern Evidence

### Timestamp Column Evidence
**Documented standard** (section 8.1.1):
> タイムスタンプ列名: `created_at`, `updated_at`（アンダースコア付き、過去分詞形）

**Implementation evidence:**
- Article: `created TIMESTAMP`, `updated TIMESTAMP` (section 4.1.1 lines 93-94)
- User: `createdAt TIMESTAMP`, `updatedAt TIMESTAMP` (section 4.1.2 lines 103-104)
- Media: `created_at TIMESTAMP`, `updated_at TIMESTAMP` (section 4.1.3 lines 115-116)
- Review: `created TIMESTAMP`, `modified TIMESTAMP` (section 4.1.4 lines 127-128)

### API Versioning Evidence
**Documented standard** (section 8.1.2):
> パスプレフィックス: `/api/v1/` 形式（バージョニング必須）

**Implementation evidence:**
- Article endpoints (section 5.1.1): All 5 endpoints use `/api/articles/` without version
- Media endpoints (section 5.1.2): All 3 endpoints use `/api/v1/media`
- Review endpoints (section 5.1.3): All 3 endpoints use `/api/v1/reviews`

### HTTP Library Evidence
**Dependency declaration** (section 2.2 line 31):
> HTTP通信: OkHttp 4.12

**Implementation standard** (section 8.1.3 lines 277-278):
> HTTP通信ライブラリ: RestTemplateを使用（WebClient不使用）

### Response Format Evidence
**Documented standard** (section 8.1.3 lines 278-279):
> レスポンス形式: `{data, error}` 形式（既存APIとの統一）

**Implementation examples:**
- Success format (section 5.2.2 lines 170-179): Uses `{success, data, message}` structure
- Error format (section 5.2.3 lines 183-190): Uses `{error: {code, message}}` structure

## Impact Analysis

### Critical Impact: Data Layer Fragmentation
The timestamp naming inconsistency has cascading effects:

1. **Query Complexity**: Time-range queries must use different column names per table:
   - `WHERE article.created > ?`
   - `WHERE user.createdAt > ?`
   - `WHERE media.created_at > ?`

2. **Audit Trail Fragmentation**: Generic audit logging cannot rely on consistent column names

3. **ORM Mapping Inconsistency**: Entity base classes cannot share `@Column` annotations for timestamps

4. **Migration Scripts**: Database migration tools cannot apply consistent timestamp indexing strategies

**Estimated Technical Debt**: High. Every module touching multiple tables requires table-specific timestamp logic.

### Critical Impact: API Client Fragmentation
The API versioning and endpoint style inconsistencies create client-side complexity:

1. **Dual Base URL Management**: Clients must maintain both `/api/articles` and `/api/v1/media` paths
2. **Breaking Change Risk**: Unversioned article endpoints cannot evolve without breaking existing clients
3. **SDK Generation Failure**: OpenAPI generators cannot produce consistent client methods when mixing RPC and REST styles

**Estimated Technical Debt**: High. Every API consumer must implement custom routing logic per resource type.

### Critical Impact: HTTP Client Duplication
The OkHttp vs RestTemplate conflict prevents centralized HTTP configuration:

1. **Duplicate Interceptor Logic**: Authentication, logging, retry, and timeout logic must be implemented twice
2. **Dependency Bloat**: Both libraries must remain in the classpath indefinitely
3. **Testing Complexity**: Integration tests must verify behavior for both client types

**Estimated Technical Debt**: Medium-High. Ongoing maintenance burden for two parallel HTTP client implementations.

### Significant Impact: Response Parsing Complexity
The three response format structures force clients to implement multiple parsing strategies:

```typescript
// Clients must implement all three patterns:
function parseResponse(response: any) {
  if (response.success !== undefined) {
    return response.data; // Format 1
  } else if (response.error !== undefined) {
    throw new Error(response.error.message); // Format 2
  } else if (response.data !== undefined || response.error !== undefined) {
    return response.data; // Format 3
  }
}
```

**Estimated Technical Debt**: Medium. Every API client must maintain format detection logic.

### Moderate Impact: ORM Mapping Complexity
The primary key naming inconsistency prevents generic repository patterns:

```java
// Cannot use generic base repository
public interface BaseRepository<T, ID> extends JpaRepository<T, ID> {
  // Fails because some entities use 'id', others use 'media_id'
  @Query("SELECT e FROM #{#entityName} e WHERE e.id = :id")
  T findByPrimaryKey(@Param("id") ID id);
}
```

**Estimated Technical Debt**: Low-Medium. Affects repository abstraction but can be worked around with per-entity repositories.

## Recommendations

### Priority 1: Standardize Timestamp Columns (Critical)

**Action**: Revise all table schemas to use `created_at` and `updated_at`:

```sql
-- Article table
created_at TIMESTAMP NOT NULL DEFAULT NOW()
updated_at TIMESTAMP NOT NULL DEFAULT NOW()

-- User table
created_at TIMESTAMP NOT NULL
updated_at TIMESTAMP NOT NULL

-- Media table (already correct)
created_at TIMESTAMP NOT NULL
updated_at TIMESTAMP NOT NULL

-- Review table
created_at TIMESTAMP NOT NULL
updated_at TIMESTAMP NOT NULL
```

**Rationale**: Aligns with documented standard (section 8.1.1) and enables consistent audit logging across all tables.

### Priority 2: Add `/v1/` Prefix to Article Endpoints (Critical)

**Action**: Revise all article endpoints:

```
POST /api/v1/articles          (was /api/articles/new)
GET /api/v1/articles/{id}      (was /api/articles/{id})
PUT /api/v1/articles/{id}      (was /api/articles/{id}/edit)
DELETE /api/v1/articles/{id}   (was /api/articles/{id})
GET /api/v1/articles           (was /api/articles/list)
```

**Rationale**: Ensures all endpoints follow the mandatory versioning standard (section 8.1.2) and enables future API evolution without breaking changes.

### Priority 3: Resolve HTTP Library Conflict (Critical)

**Action**: Choose one library and update documentation:

**Option A** (Recommended): Use RestTemplate for consistency with existing systems
- Remove OkHttp from section 2.2
- Add RestTemplate configuration documentation
- Justify: Section 8.1.3 explicitly states existing systems use RestTemplate

**Option B**: Use OkHttp for modern features
- Update section 8.1.3 to document OkHttp as the new standard
- Provide migration plan for existing system integration
- Document how existing RestTemplate code will interoperate

**Rationale**: Maintaining both libraries doubles testing and maintenance overhead.

### Priority 4: Unify Response Format (Critical)

**Action**: Adopt the documented `{data, error}` format consistently:

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

**Rationale**: Aligns with documented standard (section 8.1.3) and enables unified client-side response handling.

### Priority 5: Standardize Primary Key Naming (Significant)

**Action**: Rename primary key columns to `id`:

```sql
-- Media table
id BIGINT PRIMARY KEY  (was media_id)

-- Review table
id BIGINT PRIMARY KEY  (was review_id)
```

**Rationale**: Aligns with documented standard (section 8.1.1) and enables generic ORM repository patterns.

### Priority 6: Rename Media Table (Significant)

**Action**: Rename table from `media` to `media_file`:

```sql
CREATE TABLE media_file (
  id BIGINT PRIMARY KEY,
  -- ... rest of columns
);
```

**Rationale**: Matches the documented example in section 8.1.1 and establishes clear precedent for compound table names.

### Priority 7: Standardize Foreign Key Naming (Significant)

**Action**: Revise foreign key columns to use `{table}_id` format:

```sql
-- Media table
uploaded_by_user_id BIGINT REFERENCES user(id)  (was uploaded_by)

-- Review table
reviewer_id BIGINT REFERENCES user(id)  (was reviewer)
```

**Alternative**: If semantic clarity is preferred over mechanical consistency, document the exception:
> Foreign key columns may use semantic names (e.g., `reviewer`, `author_id`) when the relationship role is clearer than the table name. In such cases, add foreign key suffix: `reviewer_id`, `author_id`.

**Rationale**: Eliminates ambiguity about whether columns are foreign keys or VARCHAR fields.

### Priority 8: Resolve Category Reference (Moderate)

**Action**: Choose one approach and update both schema and API:

**Option A** (Recommended): Reference a category table
```sql
-- Add category table
CREATE TABLE category (
  id BIGINT PRIMARY KEY,
  name VARCHAR(50) NOT NULL UNIQUE
);

-- Update article table
ALTER TABLE article ADD category_id BIGINT REFERENCES category(id);
```

**Option B**: Use free-text categories
```json
// Update API request format
{
  "title": "記事タイトル",
  "content": "記事本文",
  "category": "tech",  // String instead of ID
  "tags": ["tech", "tutorial"]
}
```

**Rationale**: Eliminates the type mismatch between API (`categoryId`) and database (`category VARCHAR`).

### Priority 9: Document Transaction Boundaries (Moderate)

**Action**: Add transaction management section to 6.3:

```markdown
### 6.3 データアクセス
JPA (Hibernate) を使用。サービス層メソッドに `@Transactional` を付与し、トランザクション境界を明示する。

例:
@Service
public class ArticleService {
    @Transactional
    public Article create(ArticleRequest req) {
        Article article = articleRepository.save(...);
        workflowRepository.save(...);
        return article;
    }
}

トランザクション分離レベル: READ_COMMITTED
外部システム（S3アップロード）との連携時は、補償トランザクション（Saga）パターンを使用。
```

**Rationale**: Prevents partial data commits and clarifies rollback behavior.

### Priority 10: Document Case Transformation Strategy (Moderate)

**Action**: Add transformation strategy to section 6.3:

```markdown
### 6.3.3 JSONとデータベース列名のマッピング
- DTOクラスはcamelCaseフィールドを使用
- Entityクラスは `@Column(name="snake_case")` アノテーションで明示的にマッピング
- Jackson設定: デフォルトのPropertyNamingStrategyを使用（設定変更なし）

例:
@Entity
public class Article {
    @Column(name = "author_id")
    private Long authorId;

    @Column(name = "created_at")
    private Timestamp createdAt;
}
```

**Rationale**: Eliminates ambiguity in JSON-to-database field mapping.

### Priority 11: Document Environment Variable Pattern (Minor)

**Action**: Add to section 8.1.1:

```markdown
#### 8.1.5 環境変数命名規約
- 形式: UPPER_SNAKE_CASE
- プレフィックス: APP_ （アプリケーション固有設定）、DB_ （データベース）、AWS_ （クラウドリソース）
- 例: APP_JWT_SECRET, DB_CONNECTION_URL, AWS_S3_BUCKET_NAME
```

**Rationale**: Ensures consistent configuration management across services.

### Priority 12: Document Validation Placement (Minor)

**Action**: Add to section 6:

```markdown
### 6.6 バリデーション方針
- コントローラー層: `@Valid` アノテーションで構文検証（必須項目、型、形式）
- サービス層: ビジネスルール検証（重複チェック、状態遷移、権限）
- エンティティ: `@Column` 制約で最終保証

例:
@PostMapping("/articles")
public ResponseEntity<?> create(@Valid @RequestBody ArticleRequest req) {
    // Syntax validation handled by @Valid
    Article article = articleService.create(req); // Business validation
    return ResponseEntity.ok(article);
}
```

**Rationale**: Clarifies validation responsibility boundaries and prevents duplicate validation logic.
