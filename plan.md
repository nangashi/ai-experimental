# 開発計画: タスク管理APIサーバー

> 作成日: 2026-02-06
> ステータス: レビュー済み

## 1. 概要

### 1.1 目的

タスク管理のREST APIサーバーを新規構築する。タスクのCRUD操作、ステータス管理、優先度管理、期限管理、検索・フィルタリング、ページネーションを提供する。認証は設けず、シンプルなAPIサーバーとして稼働させる。

### 1.2 スコープ

**含まれる範囲:**
- タスクエンティティのCRUD API（作成・一覧取得・個別取得・更新・削除）
- ステータス（TODO, IN_PROGRESS, DONE）によるフィルタリング
- 優先度（LOW, MEDIUM, HIGH）によるフィルタリング
- 期限（dueDate）によるフィルタリング（指定日以前、指定日以降）
- ページネーション（ページ番号、ページサイズ上限100、ソート）
- バリデーション（title必須・最大200文字、description最大2000文字）
- グローバルエラーハンドリング
- ユニットテスト・統合テスト

**含まれない範囲:**
- 認証・認可機能
- フロントエンドUI
- Docker / コンテナ化設定
- CI/CD パイプライン
- タスク間の親子関係・依存関係
- ファイル添付機能
- ユーザー管理
- DBマイグレーションツール（将来導入を推奨）

### 1.3 前提条件

- Java 21 (LTS) がインストール済みであること
- MySQL 8.0以上が稼働していること
- Gradle 8.x がインストール済み、または Gradle Wrapper を使用すること
- プロジェクトルート: `/home/r-toyama/work/ai-experimental`
- 用途: 学習・実験用（ローカル環境でのみ使用）

### 1.4 ユーザー選定事項

| 項目 | 選定内容 | 理由 |
|---|---|---|
| 言語 | Java 21 (LTS) | 長期サポート、Record等の最新機能が利用可能 |
| フレームワーク | Spring Boot 3.x系最新安定版 | Java 21完全対応、Jakarta EE 10ベース |
| APIスタイル | REST API | 標準的で広く普及 |
| DB | MySQL | 広く普及した実績のあるRDBMS |
| ORM | Spring Data JPA (Hibernate) | Springエコシステムとの統合が最も優れている |
| ビルドツール | Gradle (Kotlin DSL) | 型安全なビルドスクリプト |
| テスト | JUnit 5 + Mockito | Spring Bootのデフォルト |
| 認証 | なし | シンプルに始めるため |
| 更新API | PUT（全量更新） | 全フィールド必須でシンプル |
| 削除方式 | 物理削除 | シンプルで学習用途に適切 |

---

## 2. ディレクトリ構成・ファイル修正一覧

### 2.1 新規作成ファイル

| ファイルパス | 目的 |
|---|---|
| `build.gradle.kts` | Gradleビルド設定（Kotlin DSL） |
| `settings.gradle.kts` | Gradleプロジェクト設定 |
| `gradle.properties` | Gradle プロパティ設定 |
| `gradlew` / `gradlew.bat` | Gradle Wrapper スクリプト |
| `gradle/wrapper/gradle-wrapper.properties` | Gradle Wrapper 設定 |
| `gradle/wrapper/gradle-wrapper.jar` | Gradle Wrapper JAR |
| `.gitignore` | Git除外設定 |
| `src/main/resources/application.yml` | アプリケーション設定 |
| `src/main/java/com/example/taskapi/TaskApiApplication.java` | Spring Boot エントリーポイント |
| `src/main/java/com/example/taskapi/entity/Task.java` | タスクエンティティ |
| `src/main/java/com/example/taskapi/entity/TaskStatus.java` | ステータス列挙型 |
| `src/main/java/com/example/taskapi/entity/TaskPriority.java` | 優先度列挙型 |
| `src/main/java/com/example/taskapi/repository/TaskRepository.java` | データアクセス層 |
| `src/main/java/com/example/taskapi/repository/TaskSpecifications.java` | JPA Specifications |
| `src/main/java/com/example/taskapi/service/TaskService.java` | ビジネスロジック層 |
| `src/main/java/com/example/taskapi/service/TaskSearchCriteria.java` | 検索条件（Service層所属） |
| `src/main/java/com/example/taskapi/controller/TaskController.java` | REST コントローラ |
| `src/main/java/com/example/taskapi/dto/TaskCreateRequest.java` | タスク作成リクエストDTO |
| `src/main/java/com/example/taskapi/dto/TaskUpdateRequest.java` | タスク更新リクエストDTO |
| `src/main/java/com/example/taskapi/dto/TaskResponse.java` | タスクレスポンスDTO |
| `src/main/java/com/example/taskapi/dto/PagedResponse.java` | ページネーションレスポンスDTO |
| `src/main/java/com/example/taskapi/dto/ErrorResponse.java` | エラーレスポンスDTO（統合版） |
| `src/main/java/com/example/taskapi/exception/TaskNotFoundException.java` | タスク未検出例外 |
| `src/main/java/com/example/taskapi/exception/GlobalExceptionHandler.java` | グローバル例外ハンドラ |
| `src/main/java/com/example/taskapi/mapper/TaskMapper.java` | Entity - DTO 変換 |
| `src/test/java/com/example/taskapi/TaskApiApplicationTests.java` | アプリケーション起動テスト |
| `src/test/java/com/example/taskapi/controller/TaskControllerTest.java` | コントローラ単体テスト |
| `src/test/java/com/example/taskapi/service/TaskServiceTest.java` | サービス単体テスト |
| `src/test/java/com/example/taskapi/repository/TaskRepositoryTest.java` | リポジトリ統合テスト |
| `src/test/java/com/example/taskapi/mapper/TaskMapperTest.java` | マッパー単体テスト |
| `src/test/java/com/example/taskapi/integration/TaskApiIntegrationTest.java` | E2E統合テスト |
| `src/test/resources/application-test.yml` | テスト用DB設定 |

### 2.2 ディレクトリ構成

```
/home/r-toyama/work/ai-experimental/
├── .git/
├── .claude/
├── .gitignore
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── gradlew
├── gradlew.bat
├── plan.md
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
└── src/
    ├── main/
    │   ├── java/
    │   │   └── com/
    │   │       └── example/
    │   │           └── taskapi/
    │   │               ├── TaskApiApplication.java
    │   │               ├── controller/
    │   │               │   └── TaskController.java
    │   │               ├── dto/
    │   │               │   ├── ErrorResponse.java
    │   │               │   ├── PagedResponse.java
    │   │               │   ├── TaskCreateRequest.java
    │   │               │   ├── TaskResponse.java
    │   │               │   └── TaskUpdateRequest.java
    │   │               ├── entity/
    │   │               │   ├── Task.java
    │   │               │   ├── TaskPriority.java
    │   │               │   └── TaskStatus.java
    │   │               ├── exception/
    │   │               │   ├── GlobalExceptionHandler.java
    │   │               │   └── TaskNotFoundException.java
    │   │               ├── mapper/
    │   │               │   └── TaskMapper.java
    │   │               ├── repository/
    │   │               │   ├── TaskRepository.java
    │   │               │   └── TaskSpecifications.java
    │   │               └── service/
    │   │                   ├── TaskSearchCriteria.java
    │   │                   └── TaskService.java
    │   └── resources/
    │       └── application.yml
    └── test/
        ├── java/
        │   └── com/
        │       └── example/
        │           └── taskapi/
        │               ├── TaskApiApplicationTests.java
        │               ├── controller/
        │               │   └── TaskControllerTest.java
        │               ├── integration/
        │               │   └── TaskApiIntegrationTest.java
        │               ├── mapper/
        │               │   └── TaskMapperTest.java
        │               ├── repository/
        │               │   └── TaskRepositoryTest.java
        │               └── service/
        │                   └── TaskServiceTest.java
        └── resources/
            └── application-test.yml
```

**変更点（レビュー反映）:**
- `src/main/resources/application-test.yml` を削除（テスト設定は `src/test/resources` のみ）
- `TaskSearchCriteria` を `dto` パッケージから `service` パッケージに移動
- `ValidationErrorResponse` を `ErrorResponse` に統合
- `TaskApiIntegrationTest` を追加
- `.gitignore` を追加

---

## 3. アーキテクチャ設計

### 3.1 全体構成

レイヤードアーキテクチャを採用し、以下の3層+補助コンポーネントで構成する。

```
HTTP Client
    │
    ▼
┌─────────────────────────────────────┐
│  Controller Layer (TaskController)  │  ← HTTPリクエスト受付、レスポンス返却
│  + GlobalExceptionHandler           │  ← 例外のHTTPレスポンス変換
│  + TaskMapper (補助)                │  ← Entity ↔ DTO 変換
├─────────────────────────────────────┤
│  Service Layer (TaskService)        │  ← ビジネスロジック、トランザクション管理
│  + TaskSearchCriteria               │  ← 検索条件モデル
├─────────────────────────────────────┤
│  Repository Layer (TaskRepository)  │  ← データアクセス、クエリ実行
│  + TaskSpecifications               │  ← 動的検索条件構築
├─────────────────────────────────────┤
│  Entity Layer (Task)                │  ← JPAエンティティ、DBテーブルマッピング
└─────────────────────────────────────┘
    │
    ▼
  MySQL Database
```

### 3.2 主要コンポーネント

#### Controller Layer
- **責務**: HTTPリクエストの受付、パラメータのバインディング、レスポンスのHTTPステータスコード設定
- **依存**: TaskService, TaskMapper
- **ルール**: ビジネスロジックを含まない。DTOの変換はMapperに委譲する

#### Service Layer
- **責務**: ビジネスロジックの実行、トランザクション管理、存在チェック
- **依存**: TaskRepository
- **ルール**: HTTPやDTOに依存しない。Entityとサービス層固有のモデル（TaskSearchCriteria）を使用する

#### Repository Layer
- **責務**: データベースアクセス、CRUD操作、動的クエリの構築・実行
- **依存**: Spring Data JPA, JPA Specification
- **ルール**: ビジネスロジックを含まない

#### Mapper（補助コンポーネント）
- **責務**: Entity - DTO の双方向変換
- **依存**: Entity, DTO クラス
- **ルール**: ステートレスなSpring Bean。手動マッピング

#### Exception / Error Handling
- **責務**: アプリケーション全体の例外をHTTPレスポンスに変換する
- **依存**: Spring MVC `@RestControllerAdvice`
- **ルール**: 全ての例外を統一フォーマットで返却する。500エラーでは内部情報を漏洩させない

### 3.3 データモデル

#### Task エンティティ（DBテーブル: `tasks`）

| カラム名 | Java型 | DB型 | 制約 | 説明 |
|---|---|---|---|---|
| id | Long | BIGINT | PK, AUTO_INCREMENT | 自動採番ID |
| title | String | VARCHAR(200) | NOT NULL | タスクタイトル |
| description | String | VARCHAR(2000) | NULLABLE | タスク詳細説明 |
| status | TaskStatus | VARCHAR(20) | NOT NULL, DEFAULT 'TODO' | ステータス |
| priority | TaskPriority | VARCHAR(10) | NOT NULL, DEFAULT 'MEDIUM' | 優先度 |
| due_date | LocalDate | DATE | NULLABLE | 期限日 |
| created_at | LocalDateTime | DATETIME(6) | NOT NULL | 作成日時 |
| updated_at | LocalDateTime | DATETIME(6) | NOT NULL | 更新日時 |

**インデックス（レビュー反映で追加）:**
- `idx_tasks_status` ON `status`
- `idx_tasks_priority` ON `priority`
- `idx_tasks_due_date` ON `due_date`
- `idx_tasks_created_at` ON `created_at`

### 3.4 エラーハンドリング方針

**統一エラーレスポンス（ErrorResponse に統合）:**
```json
{
  "status": 404,
  "error": "Not Found",
  "message": "Task not found with id: 123",
  "timestamp": "2026-02-06T10:30:00",
  "fieldErrors": null
}
```

**バリデーションエラー時:**
```json
{
  "status": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "timestamp": "2026-02-06T10:30:00",
  "fieldErrors": [
    { "field": "title", "rejectedValue": "", "message": "must not be blank" }
  ]
}
```

#### 例外マッピング

| 例外クラス | HTTPステータス | レスポンスmessage |
|---|---|---|
| `TaskNotFoundException` | 404 | `"Task not found with id: {id}"` |
| `MethodArgumentNotValidException` | 400 | `"Validation failed"` |
| `MethodArgumentTypeMismatchException` | 400 | `"Invalid parameter: {param}"` |
| `HttpMessageNotReadableException` | 400 | `"Malformed JSON request"` |
| `Exception`（その他） | 500 | `"Internal Server Error"`（固定文字列、内部情報を漏洩しない） |

---

## 4. 実装詳細仕様

### 4.1 build.gradle.kts

```kotlin
plugins {
    java
    id("org.springframework.boot") version "3.4.2"
    id("io.spring.dependency-management") version "1.1.7"
}

group = "com.example"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    runtimeOnly("com.mysql:mysql-connector-j")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testRuntimeOnly("com.h2database:h2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}
```

### 4.2 application.yml

```yaml
server:
  port: 8080

spring:
  datasource:
    url: ${DB_URL:jdbc:mysql://localhost:3306/task_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Tokyo}
    username: ${DB_USERNAME:root}
    password: ${DB_PASSWORD:root}
    driver-class-name: com.mysql.cj.jdbc.Driver
  jpa:
    hibernate:
      ddl-auto: ${DDL_AUTO:update}
    show-sql: true
    open-in-view: false
  data:
    web:
      pageable:
        max-page-size: 100

logging:
  level:
    com.example.taskapi: DEBUG
    org.springframework.web: INFO
```

**変更点（レビュー反映）:**
- DB認証情報を環境変数プレースホルダに変更（デフォルト値付き）
- `ddl-auto` を環境変数化（デフォルト `update`、本番では `validate` に変更可能）
- `spring.data.web.pageable.max-page-size: 100` を追加（ページサイズ上限）
- Hibernate dialect の明示指定を削除（自動検出に委任）
- `format_sql` を削除（開発時はshow-sqlで十分）

**注意:** 本番環境では `ddl-auto` を `validate` に設定し、Flyway等のマイグレーションツール導入を推奨する。

### 4.3 application-test.yml（src/test/resources のみ）

```yaml
spring:
  datasource:
    url: jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=false
    username: sa
    password:
    driver-class-name: org.h2.Driver
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true
    open-in-view: false
```

### 4.4 TaskApiApplication.java

```java
package com.example.taskapi;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class TaskApiApplication {
    public static void main(String[] args) {
        SpringApplication.run(TaskApiApplication.class, args);
    }
}
```

### 4.5 Task.java (Entity)

```java
package com.example.taskapi.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "tasks", indexes = {
    @Index(name = "idx_tasks_status", columnList = "status"),
    @Index(name = "idx_tasks_priority", columnList = "priority"),
    @Index(name = "idx_tasks_due_date", columnList = "due_date"),
    @Index(name = "idx_tasks_created_at", columnList = "created_at")
})
public class Task {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(length = 2000)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TaskStatus status = TaskStatus.TODO;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private TaskPriority priority = TaskPriority.MEDIUM;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    protected Task() {}

    public Task(Long id, String title, String description, TaskStatus status,
                TaskPriority priority, LocalDate dueDate,
                LocalDateTime createdAt, LocalDateTime updatedAt) { /* ... */ }

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    // Getter/Setter（全フィールド、idのsetterなし）
}
```

**変更点（レビュー反映）:** `@Table` にインデックス定義を追加。

### 4.6 TaskRepository.java

```java
package com.example.taskapi.repository;

import com.example.taskapi.entity.Task;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface TaskRepository extends JpaRepository<Task, Long>, JpaSpecificationExecutor<Task> {
}
```

**変更点（レビュー反映）:** `@Repository` アノテーションを削除（JpaRepository継承で自動登録されるため不要）。

### 4.7 TaskSpecifications.java

```java
package com.example.taskapi.repository;

import com.example.taskapi.entity.Task;
import com.example.taskapi.entity.TaskPriority;
import com.example.taskapi.entity.TaskStatus;
import org.springframework.data.jpa.domain.Specification;
import java.time.LocalDate;

public final class TaskSpecifications {
    private TaskSpecifications() {}

    public static Specification<Task> hasStatus(TaskStatus status) {
        return (root, query, cb) -> status == null ? cb.conjunction() : cb.equal(root.get("status"), status);
    }

    public static Specification<Task> hasPriority(TaskPriority priority) {
        return (root, query, cb) -> priority == null ? cb.conjunction() : cb.equal(root.get("priority"), priority);
    }

    public static Specification<Task> dueDateBefore(LocalDate date) {
        return (root, query, cb) -> date == null ? cb.conjunction() : cb.lessThanOrEqualTo(root.get("dueDate"), date);
    }

    public static Specification<Task> dueDateAfter(LocalDate date) {
        return (root, query, cb) -> date == null ? cb.conjunction() : cb.greaterThanOrEqualTo(root.get("dueDate"), date);
    }
}
```

### 4.8 DTO クラス群

#### TaskCreateRequest.java
```java
public record TaskCreateRequest(
    @NotBlank(message = "Title must not be blank")
    @Size(max = 200, message = "Title must be at most 200 characters")
    String title,
    @Size(max = 2000, message = "Description must be at most 2000 characters")
    String description,
    TaskStatus status,      // null → デフォルト TODO
    TaskPriority priority,  // null → デフォルト MEDIUM
    LocalDate dueDate
) {}
```

#### TaskUpdateRequest.java（PUT: 全量更新）
```java
public record TaskUpdateRequest(
    @NotBlank(message = "Title must not be blank")
    @Size(max = 200, message = "Title must be at most 200 characters")
    String title,
    @Size(max = 2000, message = "Description must be at most 2000 characters")
    String description,
    @NotNull(message = "Status must not be null")
    TaskStatus status,
    @NotNull(message = "Priority must not be null")
    TaskPriority priority,
    LocalDate dueDate  // nullの場合は期限なし
) {}
```

**変更点（レビュー反映）:** PUTセマンティクスに合わせ、`status`と`priority`に`@NotNull`を追加。

#### TaskResponse.java
```java
public record TaskResponse(
    Long id, String title, String description,
    TaskStatus status, TaskPriority priority,
    LocalDate dueDate, LocalDateTime createdAt, LocalDateTime updatedAt
) {}
```

#### PagedResponse.java
```java
public record PagedResponse<T>(
    List<T> content, int page, int size,
    long totalElements, int totalPages,
    boolean first, boolean last
) {}
```

#### ErrorResponse.java（統合版）
```java
public record ErrorResponse(
    int status,
    String error,
    String message,
    LocalDateTime timestamp,
    List<FieldError> fieldErrors  // バリデーションエラー時のみ非null
) {
    public record FieldError(String field, Object rejectedValue, String message) {}

    // バリデーションエラー以外用のファクトリメソッド
    public static ErrorResponse of(int status, String error, String message) {
        return new ErrorResponse(status, error, message, LocalDateTime.now(), null);
    }

    // バリデーションエラー用のファクトリメソッド
    public static ErrorResponse ofValidation(List<FieldError> fieldErrors) {
        return new ErrorResponse(400, "Bad Request", "Validation failed", LocalDateTime.now(), fieldErrors);
    }
}
```

**変更点（レビュー反映）:** `ValidationErrorResponse` を `ErrorResponse` に統合。

### 4.9 TaskSearchCriteria.java（serviceパッケージ）

```java
package com.example.taskapi.service;

public record TaskSearchCriteria(
    TaskStatus status,
    TaskPriority priority,
    LocalDate dueDateFrom,
    LocalDate dueDateTo
) {}
```

**変更点（レビュー反映）:** `dto`パッケージから`service`パッケージに移動し、Service層固有のモデルとして位置付け。

### 4.10 TaskNotFoundException.java

```java
public class TaskNotFoundException extends RuntimeException {
    private final Long taskId;
    public TaskNotFoundException(Long taskId) {
        super("Task not found with id: " + taskId);
        this.taskId = taskId;
    }
    public Long getTaskId() { return taskId; }
}
```

### 4.11 GlobalExceptionHandler.java

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(TaskNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleTaskNotFound(TaskNotFoundException ex) {
        // 404, ex.getMessage()
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationErrors(MethodArgumentNotValidException ex) {
        // 400, fieldErrorsリスト付き
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorResponse> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        // 400, "Invalid parameter"
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleHttpMessageNotReadable(HttpMessageNotReadableException ex) {
        // 400, "Malformed JSON request"
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(Exception ex) {
        log.error("Unexpected error occurred", ex);  // スタックトレースをログ出力
        // 500, "Internal Server Error"（固定文字列、内部情報を漏洩しない）
    }
}
```

**変更点（レビュー反映）:** 500エラーのメッセージを固定文字列に。ログにスタックトレース出力。

### 4.12 TaskMapper.java

```java
@Component
public class TaskMapper {
    public Task toEntity(TaskCreateRequest request) {
        // status null → TODO, priority null → MEDIUM のデフォルト設定
    }
    public TaskResponse toResponse(Task task) { /* 1対1マッピング */ }
    public PagedResponse<TaskResponse> toPagedResponse(Page<Task> page) { /* ... */ }
    public void updateEntity(Task task, TaskUpdateRequest request) {
        // PUT全量更新: 全フィールドを上書き
        // status, priority は @NotNull で検証済みなので常に上書き
        // dueDate は null で期限なしに設定
    }
}
```

### 4.13 TaskService.java

```java
@Service
@Transactional(readOnly = true)
public class TaskService {

    private static final Logger log = LoggerFactory.getLogger(TaskService.class);
    private final TaskRepository taskRepository;

    public TaskService(TaskRepository taskRepository) {
        this.taskRepository = taskRepository;
    }

    @Transactional
    public Task createTask(Task task) {
        Task saved = taskRepository.save(task);
        log.info("Task created [id={}]", saved.getId());
        return saved;
    }

    public Task getTask(Long id) {
        return taskRepository.findById(id)
            .orElseThrow(() -> new TaskNotFoundException(id));
    }

    public Page<Task> searchTasks(TaskSearchCriteria criteria, Pageable pageable) {
        Specification<Task> spec = Specification
            .where(TaskSpecifications.hasStatus(criteria.status()))
            .and(TaskSpecifications.hasPriority(criteria.priority()))
            .and(TaskSpecifications.dueDateAfter(criteria.dueDateFrom()))
            .and(TaskSpecifications.dueDateBefore(criteria.dueDateTo()));
        return taskRepository.findAll(spec, pageable);
    }

    @Transactional
    public Task updateTask(Long id, String title, String description,
                           TaskStatus status, TaskPriority priority, LocalDate dueDate) {
        Task task = taskRepository.findById(id)
            .orElseThrow(() -> new TaskNotFoundException(id));
        task.setTitle(title);
        task.setDescription(description);
        task.setStatus(status);
        task.setPriority(priority);
        task.setDueDate(dueDate);
        log.info("Task updated [id={}]", id);
        return task; // dirty checking で自動UPDATE
    }

    @Transactional
    public void deleteTask(Long id) {
        Task task = taskRepository.findById(id)
            .orElseThrow(() -> new TaskNotFoundException(id));
        taskRepository.delete(task);
        log.info("Task deleted [id={}]", id);
    }
}
```

**変更点（レビュー反映）:**
- `Consumer<Task>` パターンを廃止し、明示的なパラメータに変更
- `deleteTask` の冗長クエリを修正（`findById` + `delete` の2回に削減）
- 各操作にINFOレベルのログを追加
- `TaskSearchCriteria` はService層に所属

### 4.14 TaskController.java

#### API エンドポイント仕様

| メソッド | パス | 説明 | ステータスコード |
|---|---|---|---|
| POST | `/api/tasks` | タスク作成 | 201 Created |
| GET | `/api/tasks/{id}` | タスク個別取得 | 200 OK |
| GET | `/api/tasks` | タスク一覧・検索 | 200 OK |
| PUT | `/api/tasks/{id}` | タスク全量更新 | 200 OK |
| DELETE | `/api/tasks/{id}` | タスク削除 | 204 No Content |

ページネーション: `page`(default 0), `size`(default 20, max 100), `sort`(default `createdAt,desc`)

```java
@RestController
@RequestMapping("/api/tasks")
public class TaskController {
    private final TaskService taskService;
    private final TaskMapper taskMapper;

    @PostMapping
    public ResponseEntity<TaskResponse> createTask(@Valid @RequestBody TaskCreateRequest request) {
        Task task = taskMapper.toEntity(request);
        Task saved = taskService.createTask(task);
        return ResponseEntity.status(HttpStatus.CREATED).body(taskMapper.toResponse(saved));
    }

    @GetMapping("/{id}")
    public ResponseEntity<TaskResponse> getTask(@PathVariable Long id) {
        return ResponseEntity.ok(taskMapper.toResponse(taskService.getTask(id)));
    }

    @GetMapping
    public ResponseEntity<PagedResponse<TaskResponse>> searchTasks(
            @RequestParam(required = false) TaskStatus status,
            @RequestParam(required = false) TaskPriority priority,
            @RequestParam(required = false) LocalDate dueDateFrom,
            @RequestParam(required = false) LocalDate dueDateTo,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        TaskSearchCriteria criteria = new TaskSearchCriteria(status, priority, dueDateFrom, dueDateTo);
        Page<Task> page = taskService.searchTasks(criteria, pageable);
        return ResponseEntity.ok(taskMapper.toPagedResponse(page));
    }

    @PutMapping("/{id}")
    public ResponseEntity<TaskResponse> updateTask(
            @PathVariable Long id,
            @Valid @RequestBody TaskUpdateRequest request) {
        Task updated = taskService.updateTask(id,
            request.title(), request.description(),
            request.status(), request.priority(), request.dueDate());
        return ResponseEntity.ok(taskMapper.toResponse(updated));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTask(@PathVariable Long id) {
        taskService.deleteTask(id);
        return ResponseEntity.noContent().build();
    }
}
```

---

## 5. ユニットテスト戦略

### 5.1 テスト方針

| 項目 | 方針 |
|---|---|
| Controller テスト | `@WebMvcTest` + `MockMvc` |
| Service テスト | `@ExtendWith(MockitoExtension.class)` |
| Repository テスト | `@DataJpaTest`（H2インメモリDB） |
| Mapper テスト | 純粋なユニットテスト |
| 統合テスト | `@SpringBootTest` + `MockMvc`（H2インメモリDB） |

### 5.2 テストケース一覧

#### TaskControllerTest (18ケース)
- createTask: 正常(201), 空title(400), title長すぎ(400), description長すぎ(400), デフォルト値, 不正JSON(400)
- getTask: 存在するID(200), 存在しないID(404)
- searchTasks: フィルタなし, ステータスフィルタ, 優先度フィルタ, 期限フィルタ, ページサイズ
- updateTask: 正常(200), 存在しないID(404), 空title(400), null status(400)
- deleteTask: 存在するID(204), 存在しないID(404)

#### TaskServiceTest (9ケース)
- createTask, getTask(正常/例外), searchTasks(条件あり/なし), updateTask(正常/例外), deleteTask(正常/例外)

#### TaskRepositoryTest (10ケース)
- save, findById(正常/空), Specification各種, ページネーション, 削除, 更新タイムスタンプ

#### TaskMapperTest (11ケース)
- toEntity(全フィールド/デフォルト値/null), toResponse, toPagedResponse(複数/空), updateEntity(全フィールド/null dueDate)

#### TaskApiIntegrationTest (5ケース)（レビュー反映で追加）
- タスク作成→取得フロー
- タスク作成→更新→取得フロー
- タスク作成→削除→404確認フロー
- 複数タスク作成→フィルタリング検索フロー
- バリデーションエラーの統合確認

---

## 6. 実装順序

1. **プロジェクト初期化**: build.gradle.kts, settings.gradle.kts, Gradle Wrapper, .gitignore
2. **設定 + エントリーポイント**: application.yml, TaskApiApplication.java
3. **Entity + Enum**: TaskStatus, TaskPriority, Task（インデックス定義込み）
4. **Repository + Specifications**: TaskRepository, TaskSpecifications + テスト
5. **DTO + 検索条件**: TaskCreateRequest, TaskUpdateRequest, TaskResponse, PagedResponse, ErrorResponse, TaskSearchCriteria
6. **Mapper**: TaskMapper + テスト
7. **Exception + Handler**: TaskNotFoundException, GlobalExceptionHandler
8. **Service**: TaskService + テスト
9. **Controller**: TaskController + テスト
10. **統合テスト + 動作確認**: TaskApiIntegrationTest, 全テスト実行, curl動作確認

---

## 7. レビューサマリ

### 7.1 レビュー実施状況
| レビュー観点 | 重大な問題 | 改善提案 | 確認事項 |
|---|---|---|---|
| セキュリティ | 3件 | 7件 | 3件 |
| パフォーマンス | 2件 | 4件 | 2件 |
| 既存実装整合性 | 3件 | 7件 | 3件 |
| ベストプラクティス | 3件 | 7件 | 3件 |
| 保守性 | 2件 | 5件 | 3件 |

### 7.2 反映した重大な問題
1. **DBクレデンシャルのハードコード** → 環境変数プレースホルダに変更
2. **`ddl-auto: update` の本番リスク** → 環境変数化し注意書き追加
3. **ページサイズ上限の未定義** → `max-page-size: 100` を追加
4. **ServiceレイヤーのDTO依存** → `TaskSearchCriteria` を `service` パッケージに移動
5. **`application-test.yml` の重複配置** → `src/test/resources` のみに統一
6. **DBインデックスの未定義** → `@Table` にインデックス定義を追加
7. **計画内の自己矛盾（Mapper表現・updateTask設計）** → 文書表現を修正、`Consumer<Task>`を廃止

### 7.3 反映した改善提案
1. **`Consumer<Task>` パターン** → 明示的パラメータに変更（可読性・テスト容易性向上）
2. **PUT全量更新の明確化** → `TaskUpdateRequest` で `status`/`priority` に `@NotNull` 追加
3. **統合テストの追加** → `TaskApiIntegrationTest` を計画に追加
4. **`deleteTask` 冗長クエリ** → `findById` + `delete` に変更（3回→2回に削減）
5. **ログ/監査戦略** → Service層にINFOログ追加、500エラーにERRORログ追加
6. **`@Repository` 削除** → JpaRepository継承で不要
7. **Hibernate dialect自動検出** → 明示指定を削除
8. **`ErrorResponse`/`ValidationErrorResponse` 統合** → 1クラスに統合
9. **500エラーの情報漏洩防止** → 固定メッセージに変更
10. **Mapper文書表現修正** → 「ユーティリティクラス」→「ステートレスなSpring Bean」

### 7.4 ユーザー決定事項
1. **パッケージ名**: `com.example.taskapi`（維持） - 学習・実験用途のため
2. **更新API**: PUT（全量更新） - シンプルで明確なセマンティクス
3. **削除方式**: 物理削除 - シンプルで学習用途に適切
4. **プロジェクト目的**: 学習・実験用（ローカルのみ） - セキュリティ要件を最小限に

## 8. 備考

- **将来の改善候補**: DBマイグレーションツール（Flyway/Liquibase）、Testcontainers、CORS設定、レート制限、APIバージョニング
- **制約**: Java 21が未インストールのため、実装開始前にインストールが必要
- **テスト環境**: H2インメモリDBを使用。MySQL固有の機能は使用しない設計のため、互換性問題は最小限
