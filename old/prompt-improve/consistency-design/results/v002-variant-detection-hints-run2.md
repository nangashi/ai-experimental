# Consistency Design Review: 企業向け予約管理システム

## Inconsistencies Identified

### Critical Inconsistencies

#### C1. Missing Data Access Pattern Documentation
**Category**: Implementation Pattern Consistency
**Severity**: Critical

The design document does not explicitly document the data access pattern approach. While Spring Data JPA is mentioned in the technology stack (line 36), critical implementation details are missing:

- No documentation of whether Repository interfaces will use ORM direct calls or a Repository pattern wrapper
- No specification of transaction management approach (declarative @Transactional vs programmatic)
- No documentation of whether lazy loading or eager loading will be used for entity relationships
- No specification of query method naming conventions or custom query approaches

**Missing from Document**: A dedicated "Data Access Patterns" section in the Implementation Policy (Section 6) that specifies:
- Transaction boundary definitions
- Entity loading strategies
- Query method conventions
- Custom query approaches (JPQL/native SQL policies)

#### C2. Missing HTTP Client/Communication Library Documentation
**Category**: Implementation Pattern Consistency
**Severity**: Critical

The document mentions RestTemplate for HTTP communication (line 39) but provides no context for:

- Why RestTemplate is chosen when Spring recommends WebClient for new projects
- How external API calls will be handled (synchronous/asynchronous)
- Retry policies, timeout configurations, or circuit breaker patterns
- Connection pool management

**Missing from Document**: An "External Communication Patterns" section documenting:
- HTTP client selection rationale
- Communication patterns for the notification component (likely calls external email/SMS services)
- Error handling for external service failures
- Resilience patterns (retries, timeouts, circuit breakers)

### Significant Inconsistencies

#### S1. Inconsistent Error Handling Approach
**Category**: Implementation Pattern Consistency
**Severity**: Significant

The design proposes individual try-catch blocks in each controller method (line 186), which diverges from modern Spring Boot patterns. This approach creates:

- Code duplication across controllers
- Inconsistent error response formatting
- Difficult maintenance when error handling logic changes
- No centralized logging of exceptions

**Expected Pattern**: Spring Boot applications typically use `@ControllerAdvice` with `@ExceptionHandler` methods for centralized exception handling. The design document should explicitly justify why this pattern is not being followed, or adopt it.

**Impact**: If existing codebase modules use `@ControllerAdvice`, this design fragments the error handling approach.

#### S2. Inconsistent Authentication Pattern
**Category**: Implementation Pattern Consistency
**Severity**: Significant

The document states "トークンの検証は各コントローラーメソッド内で個別に実装する" (Token verification is implemented individually in each controller method) (line 181). This approach:

- Contradicts Spring Security best practices
- Creates security risks through implementation inconsistencies
- Requires manual token validation in every endpoint
- Fragments authentication logic

**Expected Pattern**: Spring Security + JWT typically uses Filter chains or `@PreAuthorize` annotations for declarative security. Manual validation in controllers is error-prone and violates DRY principles.

**Impact**: If other modules in the codebase use Spring Security filters, this represents a significant architectural divergence.

#### S3. Missing Asynchronous Processing Pattern Documentation
**Category**: Implementation Pattern Consistency
**Severity**: Significant

The NotificationService component (line 64) likely requires asynchronous processing for email/SMS sending, but the document does not specify:

- Whether notifications are sent synchronously or asynchronously
- If asynchronous, which approach: `@Async`, message queues (RabbitMQ/Kafka), or scheduled jobs
- How notification failures are handled
- If notifications should block the main transaction

**Missing from Document**: A "Asynchronous Processing Patterns" section specifying:
- When to use asynchronous processing
- Framework/library choices (Spring @Async, message brokers)
- Error handling and retry logic for async operations
- Transaction boundary considerations

### Moderate Inconsistencies

#### M1. Naming Convention Inconsistencies
**Category**: Naming Convention Consistency
**Severity**: Moderate

The design document shows inconsistent naming conventions:

**Table Column Naming**:
- `customerId`, `locationId`, `staffId` (camelCase) in reservation table (lines 100-102)
- `reservationDateTime`, `durationMinutes`, `createdAt`, `updatedAt` (camelCase) (lines 103-107)
- `firstName`, `lastName` (camelCase) in customer table (lines 113-114)
- `locationName`, `phoneNumber` (camelCase) in location table (lines 123-125)
- `staffName` (camelCase) in staff table (line 131)

**Verification Needed**: Check existing codebase database schemas. PostgreSQL typically uses `snake_case` for column names (e.g., `customer_id`, `first_name`, `created_at`). If existing tables use snake_case, this design introduces inconsistency.

**Missing from Document**: An explicit naming convention policy section stating:
- Database column naming convention (snake_case vs camelCase)
- Entity field naming convention
- Mapping strategy between Java camelCase and database column names

#### M2. Missing Directory Structure Documentation
**Category**: Directory Structure & File Placement Consistency
**Severity**: Moderate

The design document does not specify:

- Package structure organization (domain-based vs layer-based)
- File placement for controllers, services, repositories
- Where configuration classes should be placed
- Module boundaries if using multi-module Maven/Gradle structure

**Missing from Document**: A "Project Structure" section specifying:
```
src/main/java/com/company/reservation/
  ├── controller/
  ├── service/
  ├── repository/
  ├── entity/
  ├── dto/
  ├── exception/
  └── config/
```
Or domain-based alternative structure.

**Verification Needed**: Check existing modules to determine if they use layer-based (controller/service/repository packages) or domain-based (reservation/customer/notification modules with internal layers) organization.

#### M3. Inconsistent Logging Pattern
**Category**: Implementation Pattern Consistency
**Severity**: Moderate

The design specifies plain text logging format (line 189) and log levels (line 190), but does not document:

- Logger instantiation pattern (static vs instance loggers)
- Log message format templates
- Whether structured logging fields are used (MDC for request IDs, user IDs)
- Correlation ID propagation for distributed tracing

**Expected Information**: If the existing codebase uses structured logging (JSON format with fields) or MDC context, plain text format may be inconsistent. The phrase "既存システムに合わせて平文形式とする" (use plain text format matching existing system) suggests alignment, but lacks verification.

**Missing from Document**: Concrete logging pattern examples showing:
```java
log.info("Starting reservation creation for customer: {}", customerId);
log.error("Failed to send notification", exception);
```

### Minor Improvements

#### I1. Missing Transaction Management Documentation
**Category**: Implementation Pattern Consistency
**Severity**: Minor

While the document mentions Service layer responsibilities, it does not explicitly state:

- Whether transactions are managed at Service or Repository level
- Transaction propagation settings
- Read-only transaction optimization for query methods

**Recommendation**: Add a subsection under "実装方針" (Implementation Policy) titled "トランザクション管理" (Transaction Management) documenting:
- `@Transactional` annotation placement policy
- Default propagation settings
- Read-only transaction usage

#### I2. API Version Management Not Documented
**Category**: API/Interface Design Consistency
**Severity**: Minor

The API endpoints (lines 140-153) do not include version prefixes (e.g., `/api/v1/reservations`). While this may be intentional for initial release, the document should state:

- Whether API versioning is planned
- If yes, the versioning strategy (URL path, header, content negotiation)

**Verification Needed**: Check existing API modules to see if they use versioned endpoints.

## Pattern Evidence

### Evidence Required from Codebase

To complete this consistency evaluation, the following patterns should be verified:

1. **Error Handling Pattern**: Search for `@ControllerAdvice` usage:
   ```bash
   grep -r "@ControllerAdvice" src/
   ```

2. **Authentication Pattern**: Search for Spring Security filter configuration:
   ```bash
   grep -r "SecurityFilterChain\|@PreAuthorize" src/
   ```

3. **Database Column Naming**: Check existing JPA entity definitions:
   ```bash
   grep -r "@Column(name" src/
   ```

4. **Package Structure**: Examine existing module organization:
   ```bash
   tree -L 3 src/main/java
   ```

5. **Transaction Management**: Search for @Transactional usage patterns:
   ```bash
   grep -r "@Transactional" src/
   ```

6. **Logging Format**: Check existing log configuration files:
   ```bash
   cat src/main/resources/logback.xml
   ```

7. **HTTP Client Usage**: Verify RestTemplate vs WebClient usage:
   ```bash
   grep -r "RestTemplate\|WebClient" src/
   ```

## Impact Analysis

### Critical Impact (C1, C2)

**Missing data access and HTTP client documentation** creates:
- **Implementation ambiguity**: Developers may implement inconsistent patterns
- **Performance risks**: Incorrect transaction boundaries or lazy loading misuse can cause N+1 queries
- **Integration issues**: Unclear external communication patterns may lead to timeout/retry inconsistencies

**Risk**: Multiple developers implementing the same system may create fragmented data access patterns if guidelines are unclear.

### Significant Impact (S1, S2, S3)

**Inconsistent error handling and authentication patterns** create:
- **Security vulnerabilities**: Manual authentication validation in each controller is error-prone
- **Maintenance burden**: Individual try-catch blocks require changes in every controller when error handling logic evolves
- **Code duplication**: Repetitive validation and error formatting code across controllers

**Missing asynchronous processing documentation** creates:
- **Performance risks**: Synchronous notification sending blocks request processing
- **User experience issues**: Long response times if notifications are not async
- **Transaction rollback risks**: If notifications fail, should the reservation be rolled back?

### Moderate Impact (M1, M2, M3)

**Naming convention inconsistencies** create:
- **Mapping complexity**: Entity fields using camelCase but database columns using snake_case requires explicit @Column annotations
- **Developer confusion**: Inconsistent conventions slow down development

**Missing directory structure documentation** creates:
- **Merge conflicts**: Developers placing files in different locations
- **Codebase fragmentation**: Difficulty finding related code when structure is unclear

**Incomplete logging pattern documentation** creates:
- **Debugging difficulty**: Inconsistent log messages make troubleshooting harder
- **Monitoring challenges**: Lack of structured fields prevents effective log aggregation

## Recommendations

### Priority 1: Document Critical Implementation Patterns

**Add Section 6.4: データアクセスパターン (Data Access Patterns)**
```markdown
### データアクセスパターン

#### トランザクション管理
- Service層メソッドに @Transactional アノテーションを付与
- デフォルト設定: propagation=REQUIRED, readOnly=false
- 参照系メソッドには @Transactional(readOnly=true) を付与

#### エンティティ関連のローディング
- 基本的に LAZY loading を使用
- N+1問題が予想される箇所では @EntityGraph または JOIN FETCH を使用

#### クエリメソッド規約
- 単純検索: Spring Data JPA のメソッド命名規則を使用 (findByCustomerId 等)
- 複雑検索: @Query アノテーションで JPQL を記述
- ネイティブSQL: パフォーマンス要件で必要な場合のみ使用し、コメントで理由を記載
```

**Add Section 6.5: 外部通信パターン (External Communication Patterns)**
```markdown
### 外部通信パターン

#### HTTP クライアント
- 使用ライブラリ: RestTemplate (既存システムとの統一のため)
- タイムアウト設定: 接続タイムアウト 5秒、読み取りタイムアウト 10秒
- リトライ: Spring Retry を使用し、最大3回リトライ（指数バックオフ）

#### 通知サービス連携
- メール送信: 外部 SMTP サービス (SendGrid) への HTTP API 呼び出し
- SMS送信: Twilio API への HTTP 呼び出し
- 通信エラー時: 通知キューテーブルに記録し、バッチジョブで再送
```

### Priority 2: Adopt Standard Spring Patterns

**Revise Section 6: エラーハンドリング方針**

Replace:
> 各コントローラーメソッド内でtry-catchブロックを使用し、例外を個別にハンドリングする。

With:
```markdown
### エラーハンドリング方針

#### グローバル例外ハンドラー
@ControllerAdvice を使用した集中管理:
- BusinessException → HTTP 400 (Bad Request) + エラーコード返却
- SystemException → HTTP 500 (Internal Server Error) + 汎用エラーメッセージ
- MethodArgumentNotValidException → HTTP 400 + バリデーションエラー詳細

#### コントローラー実装
- 通常のビジネスロジックは try-catch 不要（@ControllerAdvice で捕捉）
- リソースクローズ等の特別な後処理が必要な場合のみ個別 try-catch を使用
```

**Revise Section 5: 認証・認可方式**

Replace:
> トークンの検証は各コントローラーメソッド内で個別に実装する。

With:
```markdown
### 認証・認可方式

JWT(JSON Web Token)を使用したステートレス認証を採用。

#### 認証フロー
1. ログイン時に JwtTokenProvider が JWT トークンを生成
2. クライアントは Authorization ヘッダーに Bearer {token} 形式で送信
3. JwtAuthenticationFilter が全リクエストでトークンを検証
4. 検証成功時は SecurityContext に認証情報を設定

#### 認可制御
- URL ベース: SecurityConfig で /api/admin/** は ADMIN ロール必須
- メソッドベース: @PreAuthorize("hasRole('STAFF')") で細かい制御
```

### Priority 3: Add Missing Documentation Sections

**Add Section 3.6: パッケージ構成 (Package Structure)**
```markdown
### パッケージ構成

レイヤーベースのパッケージ構成を採用:

```
com.company.reservation
├── controller       # REST APIコントローラー
├── service          # ビジネスロジック
├── repository       # データアクセス
├── entity           # JPAエンティティ
├── dto              # データ転送オブジェクト
│   ├── request      # APIリクエストDTO
│   └── response     # APIレスポンスDTO
├── exception        # カスタム例外クラス
├── config           # Spring設定クラス
└── security         # 認証・認可関連
```

各パッケージ内はドメインごとにファイルを配置 (ReservationController, CustomerController 等)。
```

**Add Section 4.6: データベース命名規約 (Database Naming Convention)**
```markdown
### データベース命名規約

#### テーブル名
- 小文字、単数形、スネークケース (例: reservation, customer)

#### カラム名
- 小文字、スネークケース (例: customer_id, first_name, created_at)

#### Java エンティティとのマッピング
- Java: camelCase (customerId, firstName)
- DB: snake_case (customer_id, first_name)
- Spring Data JPA の命名戦略で自動変換: spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.CamelCaseToUnderscoresNamingStrategy
```

**Update Section 4 テーブル設計**: Change all column names to snake_case:
```markdown
| customer_id | BIGINT | NOT NULL, FOREIGN KEY | 顧客ID |
| location_id | BIGINT | NOT NULL, FOREIGN KEY | 拠点ID |
| staff_id | BIGINT | NOT NULL, FOREIGN KEY | スタッフID |
| reservation_date_time | TIMESTAMP | NOT NULL | 予約日時 |
| duration_minutes | INT | NOT NULL | 所要時間(分) |
```

### Priority 4: Clarify Asynchronous Processing

**Add Section 6.6: 非同期処理パターン (Asynchronous Processing Pattern)**
```markdown
### 非同期処理パターン

#### 通知送信の非同期化
- NotificationService のメール・SMS送信メソッドに @Async を付与
- Spring の @EnableAsync で非同期処理を有効化
- ThreadPoolTaskExecutor でスレッドプール設定 (core=5, max=10, queue=100)

#### エラーハンドリング
- 非同期メソッドは CompletableFuture<Void> を返却
- 送信失敗時は notification_queue テーブルに記録
- 夜間バッチジョブで未送信通知を再送

#### トランザクション境界
- 予約作成トランザクションと通知送信は分離
- 予約作成成功後、非同期で通知を送信（通知失敗しても予約は確定）
```

## Summary

This design document shows **7 significant consistency issues** requiring attention before implementation:

- **2 Critical**: Missing data access and HTTP client pattern documentation
- **3 Significant**: Inconsistent error handling, authentication, and missing async patterns
- **3 Moderate**: Naming convention, directory structure, logging pattern gaps

The most critical issue is the **manual authentication validation in controllers** (S2) and **individual try-catch error handling** (S1), both of which diverge from standard Spring Boot patterns and create maintenance and security risks.

**Recommended Action**: Revise Sections 5 and 6 to adopt @ControllerAdvice for error handling and Spring Security filters for authentication, then add detailed data access and external communication pattern documentation.
