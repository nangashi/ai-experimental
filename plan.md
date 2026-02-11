# 開発計画: Spring Boot Web API スケルトン

> 作成日: 2026-02-07
> ステータス: レビュー済み（対話的コンフリクト解決済み）

## 1. 概要

### 1.1 目的
Spring Boot 3ベースのWeb API（REST）スケルトンプロジェクトを新規作成する。業務ロジック追加の土台として、ビルド・起動・テスト・ヘルスチェックが動作する最小構成を構築する。

### 1.2 スコープ
**含まれるもの:**
- Gradle (Kotlin DSL) によるビルド構成
- Spring Boot 3.5.10 のWeb APIアプリケーション骨格
- Spring Boot Actuatorによるヘルスチェックエンドポイント（/actuator/health）
- JUnit 5 + MockMvcによるテスト
- Gradle Wrapper

**明示的に含まれないもの:**
- データベース連携（JPA, MySQL, H2, Flyway）
- Docker / compose.yaml
- 業務エンドポイント
- 認証・認可
- CORS設定
- CI/CDパイプライン

### 1.3 前提条件
- Java 21 (LTS) がインストール済み
- Git がインストール済み
- プロジェクトルート: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental
- 既存のJavaコードは存在しない（新規作成）

### 1.4 ユーザー選定事項
| 項目 | 選定 | 理由 |
|---|---|---|
| ビルドツール | Gradle (Kotlin DSL) | 型安全なビルドスクリプト、IDEサポート |
| Javaバージョン | Java 21 (LTS) | 長期サポート、最新言語機能 |
| フレームワーク | Spring Boot 3.5.10 | 最新安定版、長期サポート |
| パッケージ名 | com.example.api | シンプルなパッケージ構造 |
| DB | なし（将来導入） | 最小構成を優先（YAGNI原則） |
| ヘルスチェック | Spring Boot Actuator | 標準的なヘルスチェック機構 |

---

## 2. ディレクトリ構成・ファイル修正一覧

### 2.1 新規作成ファイル
| ファイルパス | 目的 | 主要な型/関数 |
|---|---|---|
| build.gradle.kts | Gradleビルド設定 | plugins, dependencies, java toolchain |
| settings.gradle.kts | プロジェクト名設定 | rootProject.name |
| gradle.properties | Gradleプロパティ | org.gradle.daemon=true 等 |
| .gitignore | Git除外設定 | ビルド成果物、IDE設定、セキュリティファイル |
| gradlew | Gradle Wrapper (Unix) | - |
| gradlew.bat | Gradle Wrapper (Windows) | - |
| gradle/wrapper/gradle-wrapper.properties | Wrapper設定 | distributionUrl |
| gradle/wrapper/gradle-wrapper.jar | Wrapperバイナリ | - |
| src/main/resources/application.yml | アプリケーション設定 | server, management, spring.jackson |
| src/main/java/com/example/api/ApiApplication.java | エントリーポイント | ApiApplication.main() |
| src/test/java/com/example/api/ApiApplicationTests.java | コンテキスト起動テスト | contextLoads() |
| src/test/java/com/example/api/ActuatorHealthTest.java | Actuatorヘルスチェックテスト | healthEndpointReturnsUp() |

### 2.2 修正ファイル
なし（新規プロジェクト）

### 2.3 ディレクトリ構成（変更後）
```
プロジェクトルート/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── .gitignore
├── gradlew
├── gradlew.bat
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
└── src/
    ├── main/
    │   ├── java/
    │   │   └── com/
    │   │       └── example/
    │   │           └── api/
    │   │               └── ApiApplication.java
    │   └── resources/
    │       └── application.yml
    └── test/
        └── java/
            └── com/
                └── example/
                    └── api/
                        ├── ApiApplicationTests.java
                        └── ActuatorHealthTest.java
```

---

## 3. アーキテクチャ設計

### 3.1 全体構成
```
[HTTPクライアント]
       │
       ▼
[Spring Boot 組込みTomcat (port 8080)]
       │
       ├── /actuator/health → [Spring Boot Actuator HealthEndpoint]
       │                       → {"status":"UP"} (HTTP 200)
       │
       └── (将来の業務エンドポイント追加箇所)
```

アプリケーションはSpring Boot 3.5.10の組込みTomcatで起動し、ポート8080でHTTPリクエストを受け付ける。ヘルスチェックはSpring Boot Actuatorが提供する `/actuator/health` エンドポイントを使用する。

### 3.2 主要コンポーネント

#### ApiApplication（エントリーポイント）
- **責務**: Spring Bootアプリケーションの起動
- **アノテーション**: `@SpringBootApplication`
- **依存**: Spring Boot Framework

#### Spring Boot Actuator HealthEndpoint（フレームワーク提供）
- **責務**: アプリケーションのヘルスステータスの提供
- **エンドポイント**: GET /actuator/health
- **レスポンス**: `{"status":"UP"}` (HTTP 200)
- **設定**: application.ymlで公開エンドポイントをhealthのみに制限

### 3.3 データモデル
なし（現時点でDB未使用。Actuatorのレスポンスはフレームワークが自動生成）

### 3.4 エラーハンドリング方針
- 現時点ではSpring Bootのデフォルトエラーハンドリング（BasicErrorController）を使用
- 存在しないパスへのリクエスト: Spring Bootデフォルトの404レスポンス
- サーバー内部エラー: Spring Bootデフォルトの500レスポンス
- **将来方針**: 2つ目の業務エンドポイント追加時に `@RestControllerAdvice` + `@ExceptionHandler` でグローバルエラーハンドリングを導入

---

## 4. 実装詳細仕様

### 4.1 build.gradle.kts

#### 責務
プロジェクトのビルド構成、依存関係管理、Javaバージョン指定を定義する。

#### 内容
```kotlin
plugins {
    java
    id("org.springframework.boot") version "3.5.10"
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
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
}

tasks.withType<Test> {
    useJUnitPlatform()
}
```

#### 設計判断の根拠
- `io.spring.dependency-management` 1.1.7: Spring Boot 3.5.x公式推奨。BOM管理で依存バージョンの一貫性を保証
- `java.toolchain`: JDKの自動検出・ダウンロードに対応。ビルド環境の差異を吸収
- 依存関係は3つのみ（web, actuator, test）。最小構成を維持（YAGNI原則）

### 4.2 settings.gradle.kts

#### 内容
```kotlin
rootProject.name = "ai-experimental"
```

### 4.3 gradle.properties

#### 内容
```properties
org.gradle.daemon=true
org.gradle.parallel=true
```

### 4.4 .gitignore

#### 内容
```gitignore
# Gradle
.gradle/
build/

# IDE
.idea/
*.iml
.vscode/
.settings/
.project
.classpath
*.swp
*~

# OS
.DS_Store
Thumbs.db

# Application
*.log

# Security - credentials and keys
.env
*.pem
*.key
application-local.yml
```

#### 設計判断の根拠
- `.env`, `*.pem`, `*.key`, `application-local.yml` をセキュリティ対策として除外（セキュリティレビュー反映）

### 4.5 application.yml

#### 内容
```yaml
server:
  port: 8080

spring:
  application:
    name: ai-experimental
  jackson:
    serialization:
      write-dates-as-timestamps: false

management:
  endpoints:
    web:
      exposure:
        include: health
  endpoint:
    health:
      show-details: never
```

#### 設計判断の根拠
- `management.endpoints.web.exposure.include: health`: Actuatorエンドポイントをhealthのみに限定。情報漏洩リスクのあるエンドポイントを非公開（セキュリティレビュー反映）
- `management.endpoint.health.show-details: never`: ヘルスチェック詳細情報を非公開。内部構成の推測を防止（セキュリティレビュー反映）
- `spring.jackson.serialization.write-dates-as-timestamps: false`: 日時をISO-8601形式でシリアライズ。将来のAPI応答で一貫した日時フォーマットを保証（ベストプラクティスレビュー反映）

### 4.6 ApiApplication.java

#### 内容
```java
package com.example.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(ApiApplication.class, args);
    }
}
```

### 4.7 ApiApplicationTests.java

#### 内容
```java
package com.example.api;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class ApiApplicationTests {

    @Test
    void contextLoads() {
    }
}
```

### 4.8 ActuatorHealthTest.java

#### 内容
```java
package com.example.api;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ActuatorHealthTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void healthEndpointReturnsUp() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }
}
```

---

## 5. ユニットテスト戦略

### 5.1 テスト方針
| 項目 | 方針 |
|---|---|
| テストフレームワーク | JUnit 5（spring-boot-starter-testに包含） |
| Web層テスト | MockMvcを使用（組込みサーバー不起動で高速） |
| モック | 現時点では外部依存なしのためモック不要 |
| カバレッジ目標 | 全テスト通過。数値目標は業務ロジック追加時に設定 |

### 5.2 テストケース一覧
| テストファイル | テスト対象 | テストケース | 検証内容 |
|---|---|---|---|
| ApiApplicationTests.java | ApiApplication | contextLoads() | Spring Bootコンテキストが例外なく起動すること |
| ActuatorHealthTest.java | /actuator/health | healthEndpointReturnsUp() | HTTP 200が返り、status="UP"であること |

### 5.3 テストデータ
現時点でテスト固有のデータは不要。

---

## 6. 実装順序

### ステップ 1: Gradle Wrapper生成
- **対象ファイル**: gradlew, gradlew.bat, gradle/wrapper/*
- **依存**: なし
- **作業内容**: `gradle wrapper --gradle-version=8.12` を実行してGradle Wrapperを生成する
- **完了条件**: `./gradlew --version` が正常実行されること

### ステップ 2: ビルド設定ファイル作成
- **対象ファイル**: build.gradle.kts, settings.gradle.kts, gradle.properties
- **依存**: ステップ 1
- **作業内容**: セクション4.1〜4.3の内容に従い作成
- **完了条件**: `./gradlew dependencies` で spring-boot-starter-web, spring-boot-starter-actuator が表示されること

### ステップ 3: .gitignore作成
- **対象ファイル**: .gitignore
- **依存**: なし
- **作業内容**: セクション4.4の内容に従い作成
- **完了条件**: ファイルが存在し、セキュリティ関連エントリを含むこと

### ステップ 4: アプリケーション設定ファイル作成
- **対象ファイル**: src/main/resources/application.yml
- **依存**: ステップ 2
- **作業内容**: セクション4.5の内容に従い作成
- **完了条件**: Actuator設定とJackson設定が含まれていること

### ステップ 5: エントリーポイント作成
- **対象ファイル**: src/main/java/com/example/api/ApiApplication.java
- **依存**: ステップ 2
- **作業内容**: セクション4.6の内容に従い作成
- **完了条件**: `./gradlew compileJava` が正常完了すること

### ステップ 6: テスト作成
- **対象ファイル**: src/test/java/com/example/api/ApiApplicationTests.java, ActuatorHealthTest.java
- **依存**: ステップ 4, ステップ 5
- **作業内容**: セクション4.7、4.8の内容に従い作成
- **完了条件**: `./gradlew test` で2テストが全て通過すること

### ステップ 7: 起動確認
- **対象ファイル**: なし
- **依存**: ステップ 6
- **作業内容**: `./gradlew bootRun` で起動し、`curl http://localhost:8080/actuator/health` で確認
- **完了条件**: `{"status":"UP"}` がHTTP 200で返ること

---

## 7. レビューサマリ

### 7.1 レビュー実施状況
| レビュー観点 | 重大な問題 | 改善提案 | 確認事項 |
|---|---|---|---|
| セキュリティ | 2件 | 4件 | 1件 |
| パフォーマンス | 0件 | 2件 | 0件 |
| 既存実装整合性 | 0件(*) | 6件 | 3件(*) |
| ベストプラクティス | 1件 | 5件 | 1件 |
| 保守性 | 0件 | 2件 | 1件 |

(*) consistency-reviewerが既存の別プロジェクト計画(plan.md)との不一致を指摘したが、無関係のため除外

### 7.2 コンフリクト解決
| コンフリクト | 当事者 | 解決方法 | 結果 |
|---|---|---|---|
| Actuator採用 vs 非採用 | practices-reviewer vs security-reviewer | ユーザー判断 | Actuator採用（エンドポイント制限で安全性確保） |

### 7.3 反映した重大な問題
| # | 問題 | 指摘元 | 対応内容 |
|---|---|---|---|
| 1 | DB認証情報のハードコード | security | ユーザー決定によりDB関連を全て除外。将来導入時は.env方式を採用 |
| 2 | useSSL=false設定 | security | ユーザー決定によりDB関連を全て除外 |
| 3 | ddl-auto: updateのデフォルト | security, practices, maintainability | ユーザー決定によりJPAを除外。将来導入時はvalidateを使用 |
| 4 | Jackson日時フォーマット未定義 | practices | write-dates-as-timestamps: false をapplication.ymlに追加 |

### 7.4 反映した改善提案
| # | 提案 | 指摘元 | 対応内容 |
|---|---|---|---|
| 1 | Actuatorセキュリティ設定 | security, practices | exposure.include=health, show-details=neverを設定 |
| 2 | .gitignoreセキュリティエントリ | security | .env, *.pem, *.key, application-local.ymlを追加 |
| 3 | Flyway移行トリガー明確化 | maintainability | 備考セクションにDB導入方針として記載 |
| 4 | エラーハンドリング導入トリガー | maintainability, practices | 「2つ目のエンドポイント追加時」と明記 |
| 5 | H2→Testcontainers移行方針 | practices, maintainability | 備考セクションにDB導入時の方針として記載 |
| 6 | CORS設定方針 | security | 備考セクションにフロントエンド連携時の方針として記載 |
| 7 | JPA/MySQL依存の除外（YAGNI） | maintainability, practices | ユーザー決定により除外。最小構成に変更 |

### 7.5 ユーザー決定事項
| # | 決定事項 | 選択結果 | 理由 |
|---|---|---|---|
| 1 | アプリケーション種別 | Web API (REST) | - |
| 2 | ビルドツール | Gradle (Kotlin DSL) | - |
| 3 | Javaバージョン | Java 21 (LTS) | - |
| 4 | フレームワーク | Spring Boot 3 | - |
| 5 | 機能スコープ | スケルトンのみ | - |
| 6 | データベース | MySQL（将来導入） | - |
| 7 | テストフレームワーク | JUnit 5 + Mockito | - |
| 8 | JPA/MySQL依存の含有 | 除外（最小構成） | YAGNI原則。DB利用時に導入 |
| 9 | ヘルスチェック方式 | Spring Boot Actuator | 標準機構。エンドポイント制限で安全性確保 |

---

## 8. 備考

### 将来の拡張方針

#### DB導入時（データ永続化が必要になった場合）
- **依存追加**: spring-boot-starter-data-jpa + mysql-connector-j + flyway-core + flyway-mysql
- **Docker**: compose.yaml でMySQLコンテナを定義（ポートは `127.0.0.1:3306:3306` でlocalhostバインド）
- **マイグレーション**: Flyway によるスキーマ管理。ddl-auto は `validate` を使用
- **認証情報**: .envファイル方式。compose.yamlから環境変数参照、.envは.gitignoreで除外
- **テストDB**: spring-boot-testcontainers を使用し、テスト時にMySQLコンテナを自動起動

#### エラーハンドリング（2つ目の業務エンドポイント追加時）
- `@RestControllerAdvice` + `@ExceptionHandler` でグローバルエラーハンドリングを導入
- 統一エラーレスポンス形式を定義（例: `{error, message, timestamp, path}`）

#### CORS設定（フロントエンド連携時）
- `WebMvcConfigurer#addCorsMappings` で明示的なCORS設定を追加
- 許可するオリジン、メソッド、ヘッダーを明示的に指定（ワイルドカード禁止）

#### Actuator拡張（運用監視が必要になった場合）
- Prometheus連携: micrometer-registry-prometheus を追加
- 公開エンドポイントの追加は最小限にし、認証を検討する
