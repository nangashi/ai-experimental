# Consistency Design Review: v002-variant-staged-analysis-run1

**Review Date**: 2026-02-11
**Variant ID**: C1a
**Mode**: Broad
**Round**: 002

---

## Stage 1: Overall Structure Analysis

The design document is well-structured and covers the essential areas for a reservation management system. The document presents a clear three-layer architecture (Presentation → Business Logic → Data Access) and includes comprehensive sections on data models, API design, and implementation policies.

**Present Information**:
- Complete technical stack definition (Java 17 + Spring Boot 3.2)
- Clear layered architecture specification
- Detailed entity relationships and table schemas
- API endpoint definitions with standard response formats
- Explicit implementation policies for error handling, logging, and testing

**Missing or Under-specified Information**:
- No documentation of existing codebase patterns to verify consistency against
- No explicit references to "common framework" mentioned in Section 1
- Limited documentation of specific pattern choices (e.g., why individual try-catch vs global exception handler)
- No explicit directory structure or file placement conventions
- Incomplete specification of configuration management patterns

---

## Stage 2: Section-by-Section Detail Analysis

### 2.1 Naming Convention Consistency (Section 4: Data Model)

**Observation**: The document shows **inconsistent naming patterns** between entity names, table names, and column names:

| Entity Field (Java) | Database Column | Pattern |
|---------------------|-----------------|---------|
| `reservationDateTime` | `reservationDateTime` | camelCase preserved in DB |
| `durationMinutes` | `durationMinutes` | camelCase preserved in DB |
| `customerId` | `customerId` | camelCase preserved in DB |
| N/A (Customer entity) | `firstName`, `lastName` | camelCase preserved in DB |
| N/A (Location entity) | `locationName`, `phoneNumber` | camelCase preserved in DB |
| N/A (Staff entity) | `staffName` | camelCase preserved in DB |

**Issue**: The database schema uses **camelCase column names** throughout. This is inconsistent with common database naming conventions which typically use `snake_case` (e.g., `reservation_date_time`, `customer_id`, `first_name`).

**Missing Documentation**: The design document does not explicitly state:
- Whether the existing codebase uses camelCase or snake_case for database columns
- If this is an intentional deviation or oversight
- If Hibernate/JPA naming strategy is configured to map between Java camelCase and database snake_case

**Status**: **Cannot verify consistency** without accessing existing codebase patterns. If existing tables use snake_case, this represents a **critical inconsistency**.

### 2.2 Architecture Pattern Consistency (Section 3: Architecture Design)

**Issue 1: Bidirectional Service Dependencies**

The document states: "Service層内の相互依存は許容する" (Inter-service dependencies within the Service layer are permitted).

**Concern**: This creates potential for circular dependencies and unclear responsibility boundaries. Typical Spring Boot architectures either:
- Prohibit service-to-service calls entirely (use domain events or orchestration)
- Allow only hierarchical dependencies (e.g., `ReservationService` → `CustomerService`, but not vice versa)

**Missing Documentation**:
- What is the existing pattern in the shared "common framework"?
- How are circular dependencies prevented if service-to-service calls are allowed?
- Is there an orchestration pattern or application service layer?

**Issue 2: Authentication Pattern Inconsistency**

Section 5 (API Design) states: "トークンの検証は各コントローラーメソッド内で個別に実装する" (Token verification will be implemented individually in each controller method).

**Concern**: This contradicts best practices and likely contradicts existing patterns:
- Spring Security typically uses **filters or interceptors** for authentication
- Individual method-level authentication leads to code duplication and maintenance burden
- The document mentions "Spring Security + JWT" in Section 2 but doesn't leverage Spring Security's declarative security model

**Expected Pattern** (common in Spring Boot codebases):
```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    // Global JWT filter chain
}

@RestController
@PreAuthorize("hasRole('USER')") // Declarative security
public class ReservationController { ... }
```

**Status**: **Likely critical inconsistency** if existing codebase uses Spring Security filters.

### 2.3 Implementation Pattern Consistency (Section 6: Implementation Policy)

**Issue 1: Error Handling Pattern**

The document specifies: "各コントローラーメソッド内でtry-catchブロックを使用し、例外を個別にハンドリングする" (Use try-catch blocks in each controller method to handle exceptions individually).

**Concern**: This is inconsistent with modern Spring Boot best practices:
- Spring Boot typically uses `@ControllerAdvice` for global exception handling
- Individual try-catch in every controller method leads to code duplication
- The document already defines custom exception classes (`BusinessException`, `SystemException`) which suggests intent for centralized handling

**Expected Pattern** (Spring Boot standard):
```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(BusinessException e) { ... }
}
```

**Status**: **Critical inconsistency** if existing codebase uses `@ControllerAdvice` (which is standard in Spring Boot projects).

**Issue 2: Logging Pattern**

The document specifies: "ログ形式: 既存システムに合わせて平文形式とする" (Log format: Use plain text format to match existing systems).

**Observation**:
- Explicitly states "match existing systems" → **demonstrates consistency awareness**
- However, plain text format is increasingly rare in modern systems
- No mention of whether logs are structured (JSON) for EKS/CloudWatch integration

**Missing Documentation**:
- Specific log message format examples
- Whether correlation IDs are used for distributed tracing
- How logs are aggregated in Kubernetes environment

### 2.4 Directory Structure & File Placement Consistency (Section 3: Architecture Design)

**Critical Gap**: The design document **completely omits** directory structure and file placement conventions.

**Missing Information**:
- Source directory structure (`src/main/java/...`)
- Package organization (domain-based vs layer-based)
- Configuration file locations
- Test directory structure

**Expected Documentation**:
```
例: Layer-based organization
src/main/java/com/company/reservation/
  ├── controller/
  │   ├── ReservationController.java
  │   └── CustomerController.java
  ├── service/
  │   ├── ReservationService.java
  │   └── CustomerService.java
  └── repository/
      ├── ReservationRepository.java
      └── CustomerRepository.java

または Domain-based organization
src/main/java/com/company/reservation/
  ├── reservation/
  │   ├── ReservationController.java
  │   ├── ReservationService.java
  │   └── ReservationRepository.java
  └── customer/
      ├── CustomerController.java
      ├── CustomerService.java
      └── CustomerRepository.java
```

**Status**: **Cannot verify consistency** without explicit documentation.

### 2.5 API/Interface Design & Dependency Consistency (Section 5: API Design)

**Issue 1: API Naming Convention**

The document uses **kebab-case in URLs** but shows **inconsistent patterns**:
- `POST /api/reservations` - plural noun (REST standard)
- `GET /api/reservations/{id}` - RESTful pattern
- `GET /api/reservations/customer/{customerId}` - nested resource pattern

**Missing Documentation**:
- Whether existing APIs use plural nouns consistently
- Versioning strategy (no `/v1/` prefix shown)
- Query parameter conventions (pagination, filtering, sorting)

**Issue 2: Response Format**

The document defines a **custom response wrapper**:
```json
{
  "data": { ... },
  "status": "success"
}
```

**Concern**: This is **inconsistent with Spring Boot defaults**:
- Spring Boot typically returns data directly without wrapper
- HTTP status codes (200, 400, 500) already indicate success/failure
- Wrapper adds unnecessary nesting

**Question**:
- Is this wrapper pattern used in existing "common framework" APIs?
- If yes, this demonstrates consistency
- If no, this is a **critical inconsistency**

**Issue 3: HTTP Client Library**

The document specifies: "HTTP通信: RestTemplate" (HTTP communication: RestTemplate).

**Concern**:
- `RestTemplate` is in **maintenance mode** since Spring 5.0
- Spring recommends `WebClient` (reactive) or `RestClient` (Spring 6.1+)
- Using deprecated library may indicate following outdated existing patterns

**Status**: If existing codebase uses `RestTemplate`, this is **consistent but technically outdated**. If existing codebase has migrated to `WebClient`, this is a **critical regression**.

### 2.6 Configuration & Environment Management (Section 2 & 6)

**Missing Information**:
- Configuration file format (YAML vs Properties)
- Environment variable naming conventions
- Profile-specific configuration structure
- Secret management approach (mentioned JWT but not secret rotation)

**Expected Documentation**:
```yaml
# application.yml or application.properties?
# Existing pattern: DATABASE_URL or database.url?
# Profile activation: spring.profiles.active?
```

---

## Stage 3: Cross-Cutting Issue Detection

### Cross-Cutting Pattern 1: Systematic Lack of Pattern Justification

**Pattern**: Across all sections, the document **states decisions** but does not **reference existing codebase patterns**:
- "各コントローラーメソッド内でtry-catchブロックを使用" - no reference to existing error handling
- "ログ形式: 既存システムに合わせて平文形式" - explicitly mentions existing system (positive) but no reference to specific examples
- "トークンの検証は各コントローラーメソッド内で個別に実装" - no reference to existing auth pattern

**Impact**: Reviewers cannot verify consistency without codebase access. Design may diverge from "common framework" mentioned in Section 1.

### Cross-Cutting Pattern 2: Modern vs Existing Technology Stack Tension

**Observation**: The document shows tension between modern practices and "match existing systems":
- **Modern**: Java 17, Spring Boot 3.2, Kubernetes, React 18
- **Potentially Outdated**: RestTemplate (deprecated), plain text logs (not structured), individual try-catch (pre-@ControllerAdvice pattern)

**Question**: Is the existing "common framework" legacy, and this design is intentionally maintaining backward compatibility? Or is this design introducing outdated patterns into a modern codebase?

### Cross-Cutting Pattern 3: Missing Cross-Reference to Existing Modules

**Pattern**: The document mentions "社内の他の業務システムと共通のフレームワーク" (common framework with other business systems) but provides:
- **No references** to existing module names
- **No links** to shared libraries or parent POMs
- **No examples** of similar implementations

**Expected**:
- "認証方式は既存の `common-auth-module` の `JwtAuthenticationFilter` を使用"
- "エラーハンドリングは `common-web-module` の `@ControllerAdvice` パターンに従う"
- "ログ形式は `common-logging-module` の `LoggingAspect` に準拠"

---

## Pattern Evidence (References to Existing Codebase)

**Critical Gap**: This review cannot provide specific references because:
1. The design document does not reference existing codebase files
2. Codebase access is required to verify patterns
3. The document mentions "common framework" but does not specify its location or structure

**Required Actions**:
1. Identify existing reservation or customer management modules
2. Extract their patterns for:
   - Database column naming (camelCase vs snake_case)
   - Error handling (@ControllerAdvice vs try-catch)
   - Authentication (filter vs per-method)
   - API response format (wrapper vs direct)
   - Directory structure (domain vs layer-based)

---

## Impact Analysis (Consequences of Divergence)

### High-Severity Impacts

**1. Fragmented Error Handling**
- **Issue**: Individual try-catch in controllers vs potential @ControllerAdvice in existing code
- **Impact**:
  - Code duplication across all 8+ controller methods
  - Inconsistent error responses between new and existing modules
  - Maintenance burden when error format changes

**2. Inconsistent Authentication Pattern**
- **Issue**: Per-method token verification vs Spring Security filters
- **Impact**:
  - Security vulnerabilities (easy to forget authentication on new endpoints)
  - Code duplication across all 8+ endpoints
  - Cannot leverage Spring Security's declarative model (@PreAuthorize)

**3. Database Naming Convention Mismatch**
- **Issue**: Potential camelCase vs snake_case mismatch
- **Impact**:
  - Database migration complexity
  - ORM mapping complexity
  - Developer confusion when working across modules

### Medium-Severity Impacts

**4. API Response Format Inconsistency**
- **Issue**: Custom wrapper vs potential direct responses in existing APIs
- **Impact**:
  - Frontend teams need different parsing logic for different modules
  - API contract inconsistency

**5. Deprecated HTTP Client Usage**
- **Issue**: RestTemplate vs modern WebClient
- **Impact**:
  - Technical debt from day one
  - Performance issues (blocking vs reactive)
  - Incompatibility with reactive Spring stack

### Low-Severity Impacts

**6. Missing Directory Structure Documentation**
- **Impact**: Implementation phase confusion, potential re-organization

---

## Recommendations (Specific Alignment Suggestions)

### Priority 1: Critical Consistency Verification (Before Implementation)

**R-1: Verify Database Naming Convention**
```bash
# Action: Search existing entity/table mappings
grep -r "@Column" existing-module/src/
# Check if columns use snake_case or camelCase
```
**Decision**: If existing uses snake_case, configure Hibernate naming strategy:
```java
spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl
// or CamelCaseToUnderscoresNamingStrategy
```

**R-2: Adopt Existing Error Handling Pattern**
```bash
# Action: Search for @ControllerAdvice in existing code
grep -r "@ControllerAdvice" existing-module/src/
```
**Decision**:
- If exists: Remove "individual try-catch" specification, use @ControllerAdvice
- If not exists: Document why individual handling is the standard

**R-3: Verify Authentication Pattern**
```bash
# Action: Search for JWT filter in existing code
grep -r "JwtAuthenticationFilter\|OncePerRequestFilter" existing-module/src/
```
**Decision**:
- If exists: Remove "per-method verification", use Spring Security filter chain
- If not exists: Document why per-method is chosen over filters

### Priority 2: Alignment Documentation Improvements

**R-4: Add "Consistency with Existing Codebase" Section**

Add new section after Section 3:
```markdown
## 3.5 既存コードベースとの整合性

### 共通フレームワーク参照
- **認証モジュール**: `common-security` モジュールの `JwtAuthenticationFilter` を使用
- **エラーハンドリング**: `common-web` モジュールの `GlobalExceptionHandler` パターンに準拠
- **ログ出力**: `common-logging` モジュールの平文ログ形式に準拠

### パターン継承根拠
- データベース命名規則: 既存の `customer-management` モジュールと同一のcamelCase方式
- APIレスポンス形式: 既存の `order-api` と同一のラッパー形式
- ディレクトリ構成: 既存の `inventory-service` と同一のレイヤーベース構成
```

**R-5: Document Directory Structure Explicitly**
```markdown
## 3.6 ディレクトリ構成

src/main/java/com/company/reservation/
  ├── config/           # Spring設定クラス
  ├── controller/       # REST APIコントローラー
  ├── service/          # ビジネスロジック
  ├── repository/       # データアクセス
  ├── entity/           # JPAエンティティ
  ├── dto/              # データ転送オブジェクト
  └── exception/        # カスタム例外クラス

(既存の `customer-management` モジュールと同一構成)
```

**R-6: Add Configuration File Format Specification**
```markdown
## 6.5 設定ファイル管理

- **形式**: YAML (`application.yml`)  - 既存プロジェクト標準
- **プロファイル**: `application-{env}.yml` (dev, staging, prod)
- **環境変数命名**: `RESERVATION_` プレフィックス + UPPER_SNAKE_CASE
- **シークレット管理**: AWS Secrets Manager経由で取得
```

### Priority 3: Technology Stack Alignment

**R-7: Replace RestTemplate with Modern HTTP Client**
```markdown
## 変更: HTTP通信ライブラリ
- ~~HTTP通信: RestTemplate~~ (非推奨)
- **HTTP通信: RestClient** (Spring Boot 3.2標準) または WebClient
- 根拠: RestTemplateはSpring 5.0以降メンテナンスモード
```

**R-8: Consider Structured Logging for Kubernetes**
```markdown
## 追加検討: ログ形式
- 基本形式: 平文 (既存システム互換性)
- Kubernetes環境: JSON構造化ログも出力 (CloudWatch Insights対応)
- 設定: プロファイル別にログ形式を切替可能にする
```

### Priority 4: Architecture Pattern Clarification

**R-9: Clarify Service Layer Dependency Rules**
```markdown
## 修正: Service層の依存関係ルール
- ~~Service層内の相互依存は許容する~~ (曖昧)
- **Service層の依存ルール**:
  - 階層的依存のみ許容 (例: ReservationService → CustomerService)
  - 循環依存は禁止
  - 複雑な調整が必要な場合は Application Service 層を導入
  - 既存の `order-service` モジュールと同一ルール
```

---

## Summary

### Consistency Assessment

| Category | Status | Confidence |
|----------|--------|------------|
| Naming Conventions | ⚠️ Unverified | Low - Missing codebase reference |
| Architecture Patterns | ❌ Likely Inconsistent | Medium - Authentication & error handling deviate from Spring Boot standards |
| Implementation Patterns | ❌ Inconsistent | High - Individual try-catch contradicts @ControllerAdvice pattern |
| Directory Structure | ⚠️ Undocumented | N/A - Not specified in design |
| API Design | ⚠️ Unverified | Low - Custom wrapper may or may not match existing APIs |
| Dependency Management | ⚠️ Outdated | High - RestTemplate is deprecated |

### Critical Actions Required

1. **Before Implementation**: Verify database naming, error handling, and authentication patterns in existing codebase
2. **Documentation Update**: Add "Consistency with Existing Codebase" section with specific references
3. **Pattern Alignment**: Adopt @ControllerAdvice for error handling and Spring Security filters for authentication
4. **Technology Update**: Replace RestTemplate with RestClient/WebClient

### Positive Aspects

- Explicit mention of "matching existing systems" for log format (demonstrates consistency awareness)
- Comprehensive data model and API documentation
- Clear layered architecture specification

### Key Risk

The design document operates in a vacuum without references to the "common framework" mentioned in Section 1. This creates high risk of accidental divergence during implementation. The document should be revised to include explicit pattern references before development begins.
