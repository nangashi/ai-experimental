# SmartLibrary システム設計書 - 構造品質レビュー結果

## 評価サマリー

| 評価基準 | スコア | 評価 |
|---------|-------|------|
| SOLID原則 & 構造設計 | 1/5 | Critical |
| 変更容易性 & モジュール設計 | 2/5 | Significant |
| 拡張性 & 運用設計 | 2/5 | Significant |
| エラーハンドリング & 可観測性 | 2/5 | Significant |
| テスト設計 & テスタビリティ | 3/5 | Moderate |
| API & データモデル品質 | 2/5 | Significant |

**総合評価: 2.0/5 (Significant structural issues requiring immediate attention)**

---

## Critical Issues

### 1. Single Responsibility Principle 違反 in LibraryService

- **基準**: SOLID原則 & 構造設計
- **スコア**: 1/5 (Critical)
- **問題**: LibraryServiceクラスは、図書の貸出・返却、蔵書管理、予約処理、レポート生成、および利用者認証という5つの異なる責務を担当している。これは重大なSRP違反である。
- **影響**:
  - 認証ロジックの変更が蔵書管理や予約処理に影響を与えるリスク
  - レポート生成ロジック（集計処理、Excel生成）と貸出処理（トランザクション処理）が同一クラスに存在し、テストが困難
  - 各機能を独立してスケーリングできない（例: レポート生成は重い処理だが、貸出処理と同一ポッドで動作）
  - クラスサイズが肥大化し、変更時の影響範囲が予測困難
  - 異なる変更理由（認証ポリシー、業務ロジック、レポート要件、データアクセス）が一つのクラスに集中
- **リファクタリング推奨**: 以下の専任サービスに分割:
  1. **LoanService**: 貸出・返却・延長処理（BookRepository、LoanRepository に依存）
  2. **BookManagementService**: 蔵書登録・更新・廃棄（BookRepository に依存）
  3. **ReservationService**: 予約・キャンセル・順番待ち管理（ReservationRepository、BookRepository に依存）
  4. **ReportService**: レポート生成・統計（LoanRepository、BookRepository に依存）
  5. **AuthenticationService**: ユーザー認証・JWT生成（UserRepository に依存）

  各サービスは依存性注入で必要なリポジトリのみを受け取り、単一の責務に集中する。
- **参照**: セクション 3.2 "主要コンポーネント" - LibraryService

**根拠**: SRP違反は、認証ポリシー変更（セキュリティ要件）、レポート要件変更（ビジネス要件）、貸出ルール変更（業務ロジック）という異なる変更理由が同一クラスに集中することで発生する。分離により、各サービスは独立してテスト、デプロイ、スケーリングが可能になる。

---

## Significant Issues

### 2. データモデルの非正規化による整合性リスク

- **基準**: API & データモデル品質
- **スコア**: 2/5 (Significant)
- **問題**: `loans` テーブルに `user_name` と `book_title` という冗長データが含まれている。これは `users.name` および `books.title` と重複しており、データ整合性リスクを招く。
- **影響**:
  - ユーザー名や書籍タイトルが変更された場合、過去の貸出レコードが古い情報を保持し続ける
  - 履歴データの正確性が損なわれる（例: 学生が改名した場合、過去の貸出記録が古い名前のまま）
  - 非正規化の意図（パフォーマンス最適化）が明示されていないため、設計判断の根拠不明
  - JOIN回避によるパフォーマンス改善効果が定量的に示されていない
- **推奨対応**: 以下のいずれかを選択:
  - **オプション A（推奨）**: 冗長カラムを削除し、JOIN で取得する。貸出履歴表示時に `users` と `books` をJOINするクエリを実装。パフォーマンス要件（「平均200ms以内」）を満たせる場合はこちらを選択。
  - **オプション B**: 非正規化を維持する場合、以下を明記:
    - 非正規化の目的（例: 「大量の貸出履歴検索で JOIN が遅延するため」）
    - スナップショット保存の意図（例: 「貸出時点の書籍タイトルを保存」）
    - データ整合性確保の戦略（例: 「変更時にトリガーで過去レコード更新」または「履歴は不変として扱う」）
- **参照**: セクション 4 "データモデル" - loans テーブル

**根拠**: 非正規化は、パフォーマンス要件と引き換えにデータ整合性リスクを受け入れる設計判断。その判断の根拠（測定データ、ボトルネック特定）が明示されていない場合、YAGNI原則違反となる。

### 3. 循環依存のリスク: LibraryService と UserService

- **基準**: SOLID原則 & 構造設計
- **スコア**: 2/5 (Significant)
- **問題**: LibraryServiceが「利用者認証」を担当し、UserServiceが「ユーザー登録、認証、プロフィール更新」を担当している。両サービスが認証機能を持つため、循環依存やロジック重複のリスクがある。
- **影響**:
  - LibraryServiceがUserServiceに依存し、UserServiceがLibraryServiceに依存する可能性（例: UserService がユーザー削除時に LibraryService の貸出履歴を確認）
  - 認証ロジックが2箇所に分散し、JWT生成ロジックの一貫性が保証されない
  - テスト時に両サービスをモック化する必要があり、単体テストが困難
- **推奨対応**:
  - 認証機能を AuthenticationService に集約（前述のリファクタリング案を参照）
  - UserService は純粋にユーザーデータのCRUD操作のみを担当
  - LibraryService は貸出・返却などの業務ロジックのみを担当し、認証はAuthenticationServiceに委譲
- **参照**: セクション 3.2 "主要コンポーネント" - LibraryService, UserService

### 4. エラーハンドリング戦略の詳細不足

- **基準**: エラーハンドリング & 可観測性
- **スコア**: 2/5 (Significant)
- **問題**: GlobalExceptionHandlerで「データベース接続エラー、バリデーションエラー、業務ロジックエラーなど」を処理するとあるが、以下が不明確:
  - エラーカテゴリの具体的な分類基準
  - 各エラー種別に対するHTTPステータスコード（400? 409? 500?）
  - リトライ可能エラーと不可能エラーの区別
  - クライアントへのエラーレスポンス形式（エラーコード体系、メッセージ多言語化）
- **影響**:
  - 業務ロジックエラー（例: 貸出上限超過）とシステムエラー（DB接続失敗）が区別されず、クライアントが適切な処理を実装できない
  - リトライ不可能なエラー（例: 貸出済み書籍の貸出試行）をクライアントがリトライし続ける可能性
  - エラーメッセージが開発者向けの技術的内容のみで、エンドユーザーに表示できない
- **推奨対応**: エラー分類を以下のように明確化:
  ```
  - 400 Bad Request: バリデーションエラー（必須項目不足、形式不正）
  - 401 Unauthorized: JWT認証失敗、トークン期限切れ
  - 403 Forbidden: 権限不足（STUDENTが管理者専用API実行）
  - 404 Not Found: 書籍ID/ユーザーID不存在
  - 409 Conflict: 業務ロジックエラー（貸出上限超過、既予約済み）
  - 500 Internal Server Error: DB接続エラー、予期しないシステムエラー
  - 503 Service Unavailable: 外部サービス（SMTP）ダウン

  各エラーにエラーコード（例: ERR_LOAN_LIMIT_EXCEEDED）を付与し、
  クライアントがエラーコードベースで処理を分岐できるようにする。
  ```
- **参照**: セクション 6 "実装方針" - エラーハンドリング方針

### 5. NotificationService の外部依存性に対する抽象化不足

- **基準**: 変更容易性 & モジュール設計、テスト設計 & テスタビリティ
- **スコア**: 2/5 (Significant)
- **問題**: NotificationServiceがJavaMailSenderに直接依存しており、メール送信プロバイダの変更（例: SendGrid、AWS SES）やテスト時のモック化が困難。
- **影響**:
  - メール送信プロバイダをSMTPからSendGrid APIに変更する場合、NotificationServiceの大幅な書き換えが必要
  - 単体テスト時に実際のSMTPサーバーが必要となり、テストが遅く不安定になる
  - 将来的に通知手段を追加（SMS、プッシュ通知）する場合、NotificationServiceに条件分岐が増加
- **推奨対応**:
  ```java
  // インターフェース抽出
  public interface NotificationSender {
      void send(String to, String subject, String body);
  }

  // SMTP実装
  public class SmtpNotificationSender implements NotificationSender {
      private final JavaMailSender mailSender;
      // ...
  }

  // NotificationServiceは抽象に依存
  public class NotificationService {
      private final NotificationSender sender;

      public NotificationService(NotificationSender sender) {
          this.sender = sender;
      }

      public void sendOverdueNotice(User user, Loan loan) {
          sender.send(user.getEmail(), "延滞通知", ...);
      }
  }
  ```

  この設計により:
  - テスト時にモック実装を注入可能
  - プロバイダ変更時は実装クラスの差し替えのみで対応
  - 将来的にSMS/プッシュ通知を追加する際、新しい実装クラスを作成するだけで拡張可能
- **参照**: セクション 3.2 "主要コンポーネント" - NotificationService

---

## Moderate Issues

### 6. API設計におけるRESTful原則の不整合

- **基準**: API & データモデル品質
- **スコア**: 3/5 (Moderate)
- **問題**: エンドポイント設計がRESTful原則と不整合:
  - `POST /api/updateBook` → 更新はPUT/PATCHを使うべき
  - `POST /api/deleteBook/{bookId}` → 削除はDELETEメソッドを使うべき
  - `POST /api/user/updateProfile` → 同様にPUT/PATCHを使うべき
  - `GET /api/getUser/{userId}` → "get"プレフィックスは冗長（`GET /api/users/{userId}` が標準）
- **影響**:
  - HTTPメソッドのセマンティクス（冪等性、安全性）が無視され、クライアント実装が混乱
  - API仕様がRESTful標準から逸脱し、OpenAPI/Swagger生成時に警告発生の可能性
  - キャッシュ戦略（GETは安全でキャッシュ可能、PUTは冪等）を活用できない
- **推奨対応**:
  ```
  - PUT /api/books/{bookId} (書籍更新)
  - DELETE /api/books/{bookId} (書籍削除)
  - PUT /api/users/{userId}/profile (プロフィール更新)
  - GET /api/users/{userId} (ユーザー情報取得)
  ```
- **参照**: セクション 5 "API設計" - エンドポイント一覧

### 7. テスト戦略における依存性注入設計の明記不足

- **基準**: テスト設計 & テスタビリティ
- **スコア**: 3/5 (Moderate)
- **問題**: テスト方針で「JUnit 5とMockitoを使用」とあるが、サービスクラスの依存性注入設計（コンストラクタインジェクション、フィールドインジェクション）が明記されていない。
- **影響**:
  - フィールドインジェクション（@Autowired on fields）を使った場合、単体テストでモックを注入するためにリフレクションやSpring TestContextが必要になり、テストが遅くなる
  - コンストラクタインジェクションを使えば、純粋なJUnit + Mockitoでテスト可能
- **推奨対応**:
  ```
  テスト方針に以下を追加:
  - 依存性注入はコンストラクタインジェクションを使用する
  - サービスクラスのコンストラクタで必要な依存をすべて受け取り、イミュータブルに保持
  - これにより単体テストでSpring TestContextを起動せず、純粋なPOJOとしてテスト可能
  ```
- **参照**: セクション 6 "実装方針" - テスト方針

### 8. 環境別設定管理の詳細不足

- **基準**: 拡張性 & 運用設計
- **スコア**: 3/5 (Moderate)
- **問題**: 「環境別設定は環境変数で管理（DATABASE_URL, REDIS_URL等）」とあるが、以下が不明:
  - 開発/ステージング/本番環境で異なる値を持つ設定項目のリスト
  - 機密情報（DBパスワード、JWTシークレット）の管理方法（AWS Secrets Manager? Kubernetes Secrets?）
  - 設定値のバリデーション方法（起動時チェック? デフォルト値の有無?）
- **影響**:
  - 機密情報が環境変数に平文で保存され、コンテナログやシェル履歴から漏洩リスク
  - 必須環境変数が未設定の場合、起動後に初めてエラーが発生し、デプロイ失敗の検知が遅れる
- **推奨対応**:
  ```
  環境別設定管理を以下のように明確化:
  - 機密情報はAWS Secrets Managerに保存し、起動時に取得
  - 環境変数リスト:
    - DATABASE_URL, DATABASE_USERNAME, DATABASE_PASSWORD
    - REDIS_URL, REDIS_PASSWORD
    - JWT_SECRET (Secrets Managerから取得)
    - SMTP_HOST, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD
    - ENVIRONMENT (dev/staging/prod)
  - 起動時に @ConfigurationProperties でバリデーション実施（@NotNull, @Pattern）
  ```
- **参照**: セクション 6 "実装方針" - デプロイメント方針

---

## Minor Improvements

### 9. ロギング設計における構造化ログの検討

- **基準**: エラーハンドリング & 可観測性
- **スコア**: 3/5 (Moderate)
- **問題**: 「すべてのAPIリクエスト/レスポンスをログに記録」とあるが、ログ形式（プレーンテキスト? JSON?）が明記されていない。
- **推奨**:
  - 本番環境では構造化ログ（JSON形式）を採用し、CloudWatch LogsやElasticsearchで検索・集計しやすくする
  - ログに含める情報: requestId, userId, endpoint, method, statusCode, responseTime, errorCode
- **参照**: セクション 6 "実装方針" - ロギング方針

### 10. バックエンド認証とフロントエンド認証の整合性

- **基準**: API & データモデル品質
- **スコア**: 3/5 (Moderate)
- **問題**: JWT認証がバックエンドで実装されるが、フロントエンド（React/Flutter）でのトークン保存方法（localStorage? sessionStorage? HttpOnly Cookie?）が明記されていない。
- **推奨**:
  - XSS対策として、JWT は HttpOnly Cookie に保存し、JavaScript からアクセス不可にする
  - または localStorage 保存の場合、XSS対策（CSP、入力サニタイズ）を徹底する旨を明記
- **参照**: セクション 5 "API設計" - 認証・認可方式

---

## Positive Aspects

以下の設計判断は構造品質の観点から適切である:

1. **3層アーキテクチャの採用**: プレゼンテーション層、アプリケーション層、データアクセス層の分離により、関心の分離が実現されている（セクション 3.1）

2. **Spring Data JPAの活用**: リポジトリパターンによりデータアクセスロジックが抽象化され、ビジネスロジックとの分離が実現されている

3. **統合テストでのTestcontainers使用**: 実際のPostgreSQLを使ったテストにより、プロダクション環境との整合性が確保される（セクション 6 - テスト方針）

4. **Blue-Greenデプロイメント**: 無停止リリースにより、サービス可用性が維持される（セクション 6 - デプロイメント方針）

---

## 総合評価と推奨アクション

本設計書は、基本的なアーキテクチャ構造（3層アーキテクチャ、リポジトリパターン）は適切だが、**SOLID原則違反（LibraryServiceのSRP違反）** が Critical レベルで存在する。

### 最優先で対処すべき項目（Critical/Significant）:
1. **LibraryServiceのSRP違反解消**（Issue #1）: 5つの専任サービスに分割
2. **認証ロジックの一元化**（Issue #3）: AuthenticationServiceへの集約
3. **データモデル非正規化の根拠明確化**（Issue #2）: 設計判断の文書化
4. **エラーハンドリング戦略の詳細化**（Issue #4）: エラーコード体系の定義
5. **NotificationServiceの抽象化**（Issue #5）: NotificationSenderインターフェース導入

これらの対応により、システムの長期的な保守性、テスト容易性、拡張性が大幅に向上する。
