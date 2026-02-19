# SmartLibrary システム設計書 - 構造品質レビュー結果

## レビュー実行日
2026-02-11

## 総合評価サマリ

| 評価基準 | スコア | 重要度 |
|---------|--------|--------|
| SOLID原則 & 構造設計 | 1/5 | Critical |
| 変更容易性 & モジュール設計 | 2/5 | Critical |
| 拡張性 & 運用設計 | 2/5 | Significant |
| エラーハンドリング & 可観測性 | 2/5 | Significant |
| テスト設計 & テスタビリティ | 2/5 | Significant |
| API & データモデル品質 | 2/5 | Significant |

---

## Critical Issues

### 1. Single Responsibility Principle違反 in LibraryService

**評価基準**: SOLID原則 & 構造設計
**スコア**: 1/5 (Critical)

**問題**:
`LibraryService`が以下の5つの異なる責務を単一クラスに集約している（セクション3.2 "主要コンポーネント"参照）:
1. 図書の貸出・返却（貸出ビジネスロジック）
2. 蔵書管理（在庫管理、書籍CRUD）
3. 予約処理（予約受付、キャンセル、順番待ち管理）
4. レポート生成（統計計算、データ集計）
5. 利用者認証（認証処理）

**影響**:
- **変更の影響範囲拡大**: 貸出ルール変更時に認証やレポート生成に影響を及ぼすリスク
- **テスト困難**: レポート生成ロジックを単独でテストできず、貸出・予約機能のモックが必要
- **スケーラビリティ制約**: レポート生成（CPU集約的）と貸出処理（トランザクション集約的）を独立してスケーリングできない
- **コード可読性低下**: 単一クラスが1000行超の規模になり、新規開発者の理解を妨げる
- **並行開発困難**: 複数の開発者が同一ファイルを編集するため、競合が頻発

**リファクタリング推奨**:
以下の5つの責務別サービスに分割し、それぞれが単一の変更理由を持つように設計:

1. **LoanService**: 貸出・返却・延長のビジネスロジックを担当
   - `borrowBook(userId, bookId)`
   - `returnBook(loanId)`
   - `extendLoan(loanId)`

2. **BookManagementService**: 蔵書のCRUD操作と在庫管理を担当
   - `addBook(bookDto)`
   - `updateBook(bookId, bookDto)`
   - `deleteBook(bookId)`
   - `updateAvailability(bookId, delta)`

3. **ReservationService**: 予約受付、キャンセル、順番待ち管理を担当
   - `reserveBook(userId, bookId)`
   - `cancelReservation(reservationId)`
   - `processReservationQueue(bookId)`

4. **ReportGenerationService**: 統計レポート生成を担当
   - `generateLoanReport(startDate, endDate)`
   - `getPopularBooks(limit)`

5. **AuthenticationService**: ユーザー認証とセッション管理を担当（現在UserServiceと重複している認証処理を統合）
   - `authenticate(email, password)`
   - `generateToken(user)`
   - `validateToken(token)`

各サービスは必要なRepositoryのみを依存性注入で受け取る。

**参照**: セクション3.2 "主要コンポーネント"

---

### 2. 認証処理の重複と責務の曖昧さ

**評価基準**: SOLID原則 & 構造設計
**スコア**: 1/5 (Critical)

**問題**:
認証処理が`LibraryService`と`UserService`の両方に記載されており（セクション3.2参照）、JWTトークン生成は`UserService`で実施するが、利用者認証は`LibraryService`でも担当するという矛盾した設計になっている。

**影響**:
- **Single Responsibility Principle違反**: 認証という横断的関心事が2つのサービスに散在
- **バグの温床**: トークン検証ロジックが2箇所に存在する場合、片方のみ更新される不整合リスク
- **セキュリティリスク**: 認証ロジックの一貫性が保証されず、脆弱性が混入しやすい
- **テスト重複**: 同じ認証シナリオを2つのサービスでテストする必要がある

**リファクタリング推奨**:
認証処理を専用の`AuthenticationService`に集約し、`LibraryService`と`UserService`から認証処理を削除:

```
AuthenticationService:
- authenticate(email, password): 認証実行
- generateToken(user): JWTトークン生成
- validateToken(token): トークン検証
- refreshToken(oldToken): トークンリフレッシュ

UserService:
- registerUser(userDto): ユーザー登録
- updateProfile(userId, profileDto): プロフィール更新
- getUserInfo(userId): ユーザー情報取得

LibraryService → 削除または上記の細分化されたサービス群に置き換え
```

Spring Securityの`@PreAuthorize`アノテーションとカスタム`AuthenticationFilter`を使用して、コントローラー層で認証を統一的に処理する。

**参照**: セクション3.2 "主要コンポーネント" - LibraryService/UserService

---

### 3. データモデルにおける非正規化の過剰使用

**評価基準**: API & データモデル品質
**スコア**: 2/5 (Critical)

**問題**:
`loans`テーブルに`user_name`と`book_title`という冗長データが含まれている（セクション4 "データモデル"参照）。これはパフォーマンス最適化のための非正規化と推測されるが、設計書に非正規化の理由、更新戦略、整合性保証メカニズムが記載されていない。

**影響**:
- **データ整合性リスク**: `users.name`または`books.title`が更新された場合、過去の`loans`レコードの冗長データが古いままになる
- **更新処理の複雑化**: ユーザー名や書籍タイトル変更時に、関連するすべての`loans`レコードを更新する必要があるが、その処理が設計に含まれていない
- **トランザクション境界の拡大**: 単純な名前変更が複数テーブルにまたがるトランザクションを要求する
- **監査証跡の喪失**: 貸出時点のタイトル/氏名を記録する意図であれば、履歴テーブルとして明示的に設計すべき

**リファクタリング推奨**:

**Option A（監査証跡が目的の場合）**:
貸出時点のスナップショットを記録するための履歴テーブルとして明示的に設計:
```sql
CREATE TABLE loan_snapshots (
  loan_id BIGINT PRIMARY KEY REFERENCES loans(id),
  user_name_at_loan VARCHAR(100) NOT NULL,
  book_title_at_loan VARCHAR(500) NOT NULL,
  created_at TIMESTAMP NOT NULL
);
```
`loans`テーブルから冗長カラムを削除し、履歴が必要な場合のみ`loan_snapshots`をJOINする。

**Option B（パフォーマンス最適化が目的の場合）**:
- 非正規化の理由を設計書に明記（例: レポート生成クエリのJOIN削減）
- 非正規化データの更新戦略を定義（例: 書籍タイトル変更時は過去loansを更新しない、名前変更時は表示名を別管理）
- データベーストリガーまたはアプリケーション層でのイベント駆動更新を実装
- 整合性検証用のバッチジョブを定期実行

**参照**: セクション4 "データモデル" - loansテーブル

---

## Significant Issues

### 4. レイヤー間の依存性方向違反（Dependency Inversion Principle）

**評価基準**: SOLID原則 & 構造設計
**スコア**: 2/5 (Significant)

**問題**:
サービス層が具象的なインフラストラクチャ実装に直接依存している:
- `NotificationService`が`JavaMailSender`（Spring Mail実装）に直接依存（セクション3.2参照）
- リポジトリがSpring Data JPA実装に密結合

**影響**:
- **テスト困難**: SMTPサーバーなしで通知ロジックをテストできない
- **技術スタック変更の困難**: メール送信をAWS SESやSendGridに切り替える際、サービス層の変更が必要
- **モック困難**: `JavaMailSender`の具象実装をモックする必要があり、テストが脆弱

**リファクタリング推奨**:
ドメイン層に抽象インターフェースを定義し、インフラ層が実装を提供する:

```java
// Domain Layer (ビジネスロジック層)
public interface NotificationPort {
    void sendEmail(EmailMessage message);
    void sendSMS(SMSMessage message);
}

// Application Service
@Service
public class NotificationService {
    private final NotificationPort notificationPort;

    public NotificationService(NotificationPort notificationPort) {
        this.notificationPort = notificationPort;
    }

    public void notifyOverdue(Loan loan) {
        EmailMessage email = buildOverdueEmail(loan);
        notificationPort.sendEmail(email);
    }
}

// Infrastructure Layer (実装)
@Component
public class JavaMailNotificationAdapter implements NotificationPort {
    private final JavaMailSender mailSender;

    @Override
    public void sendEmail(EmailMessage message) {
        // JavaMailSender実装
    }
}
```

これにより、テスト時は`NotificationPort`のモック実装を注入し、本番環境では`JavaMailNotificationAdapter`を注入できる。

**参照**: セクション3.2 "主要コンポーネント" - NotificationService

---

### 5. エラーハンドリング戦略の不明確さ

**評価基準**: エラーハンドリング & 可観測性
**スコア**: 2/5 (Significant)

**問題**:
セクション6 "実装方針"に「GlobalExceptionHandlerでキャッチして適切なHTTPステータスコードとエラーメッセージをクライアントに返す」と記載されているが、以下が不明確:
- エラーの分類基準（システムエラー vs ビジネスエラー vs バリデーションエラー）
- リトライ可能エラーとリトライ不可能エラーの区別
- 部分的失敗時の処理（例: 予約処理が成功したが通知送信が失敗）
- 外部サービス（SMTP、データベース）のタイムアウト/サーキットブレーカー戦略

**影響**:
- **障害時の動作不明確**: データベース接続エラー時にトランザクションがロールバックされるか、リトライされるかが不明
- **ユーザー体験の劣化**: すべてのエラーが500 Internal Server Errorで返却される可能性
- **運用困難**: エラーログから障害原因を特定できない

**リファクタリング推奨**:

1. **エラー分類の明確化**:
```java
// Domain Exceptions
public class BusinessException extends RuntimeException {
    private final ErrorCode errorCode;
}

public enum ErrorCode {
    BOOK_NOT_AVAILABLE(409, "Book is currently unavailable"),
    LOAN_LIMIT_EXCEEDED(400, "User has reached loan limit"),
    INVALID_LOAN_EXTENSION(400, "Loan cannot be extended"),
    // ...
}

// Infrastructure Exceptions
public class InfrastructureException extends RuntimeException {
    private final boolean retryable;
}
```

2. **GlobalExceptionHandlerの階層化**:
```java
@ControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(BusinessException ex) {
        // HTTPステータス: 400/409、リトライ不可、ユーザー向けメッセージ
    }

    @ExceptionHandler(InfrastructureException.class)
    public ResponseEntity<ErrorResponse> handleInfrastructureException(InfrastructureException ex) {
        // HTTPステータス: 500/503、リトライ可否を判定、技術的メッセージ
    }
}
```

3. **部分的失敗の処理戦略を定義**:
```
貸出処理:
- 貸出トランザクション成功 → 通知失敗 → 非同期リトライキュー（SQS）に投入
- 在庫更新失敗 → 全体ロールバック

予約処理:
- 予約レコード作成成功 → 通知失敗 → イベントログに記録し、バッチジョブで再送
```

4. **外部サービスのResilience4jによるサーキットブレーカー**:
```java
@CircuitBreaker(name = "emailService", fallbackMethod = "fallbackSendEmail")
public void sendEmail(EmailMessage message) {
    // 通知送信
}

private void fallbackSendEmail(EmailMessage message, Exception ex) {
    // フォールバック: キューに投入
}
```

**参照**: セクション6 "実装方針" - エラーハンドリング方針

---

### 6. テスト設計における依存性注入の不足

**評価基準**: テスト設計 & テスタビリティ
**スコア**: 2/5 (Significant)

**問題**:
セクション6 "実装方針"にMockitoを使用した単体テストの記載があるが、サービス層がRepositoryに直接依存する設計（セクション3.2）では、以下のシナリオでテストが困難:
- 複数のRepositoryを呼び出すトランザクション境界のテスト
- 外部サービス（JavaMailSender）を含むテスト
- 時刻依存のビジネスロジック（延滞判定、予約期限切れ）のテスト

**影響**:
- **テストカバレッジ不足**: リポジトリ実装に依存するため、エッジケース（同時更新、デッドロック）をテストできない
- **テストの脆弱性**: データベースの状態に依存するテストは、他のテストの影響を受けやすい
- **テスト実行時間の増加**: 統合テスト（Testcontainers）なしでビジネスロジックをテストできず、テストが遅い

**リファクタリング推奨**:

1. **時刻抽象化の導入**:
```java
public interface Clock {
    LocalDateTime now();
}

@Service
public class LoanService {
    private final Clock clock;

    public boolean isOverdue(Loan loan) {
        return clock.now().isAfter(loan.getDueDate());
    }
}

// Production
@Component
public class SystemClock implements Clock {
    public LocalDateTime now() { return LocalDateTime.now(); }
}

// Test
public class FixedClock implements Clock {
    private LocalDateTime fixedTime;
    public LocalDateTime now() { return fixedTime; }
}
```

2. **リポジトリインターフェースの明示化**:
Spring Data JPAの自動生成に頼らず、ドメイン層にリポジトリインターフェースを定義:
```java
// Domain Layer
public interface LoanRepository {
    Loan save(Loan loan);
    Optional<Loan> findById(Long id);
    List<Loan> findOverdueLoans(LocalDateTime now);
}

// Infrastructure Layer
@Repository
public interface JpaLoanRepository extends LoanRepository, JpaRepository<Loan, Long> {
    @Query("SELECT l FROM Loan l WHERE l.dueDate < :now AND l.status = 'ACTIVE'")
    List<Loan> findOverdueLoans(@Param("now") LocalDateTime now);
}
```

3. **テストダブルの活用**:
```java
@Test
void shouldMarkLoanAsOverdue() {
    // Arrange
    FixedClock clock = new FixedClock(LocalDateTime.of(2026, 3, 15, 0, 0));
    InMemoryLoanRepository repository = new InMemoryLoanRepository();
    LoanService service = new LoanService(repository, clock);

    Loan loan = new Loan(userId, bookId, LocalDateTime.of(2026, 3, 10, 0, 0));
    repository.save(loan);

    // Act
    service.checkOverdueLoans();

    // Assert
    assertEquals(LoanStatus.OVERDUE, repository.findById(loan.getId()).getStatus());
}
```

**参照**: セクション6 "実装方針" - テスト方針

---

### 7. APIエンドポイント設計のRESTful原則違反

**評価基準**: API & データモデル品質
**スコア**: 2/5 (Significant)

**問題**:
セクション5 "API設計"のエンドポイントがRESTfulな設計原則に準拠していない:
- `POST /api/user/updateProfile` → 動詞ベース、べき等性のあるPUTを使うべき
- `POST /api/deleteBook/{bookId}` → DELETEメソッドを使うべき
- `GET /api/getUser/{userId}` → 冗長な`get`プレフィックス
- `POST /api/borrowBook` → リソース指向でない（`POST /api/loans`が適切）
- `POST /api/returnBook` → 状態遷移を表現していない（`PATCH /api/loans/{loanId}`が適切）

**影響**:
- **キャッシング不可**: すべての操作がPOSTのため、CDNやブラウザキャッシュを活用できない
- **べき等性の欠如**: ネットワークエラー時の安全なリトライができない
- **API利用者の混乱**: REST原則に慣れた開発者がエンドポイントを直感的に理解できない

**リファクタリング推奨**:

| 現在のエンドポイント | 改善後のエンドポイント | HTTPメソッド | 説明 |
|------------------|-------------------|------------|-----|
| POST /api/user/updateProfile | PUT /api/users/{userId} | PUT | ユーザーリソース全体の更新 |
| POST /api/deleteBook/{bookId} | DELETE /api/books/{bookId} | DELETE | 書籍リソースの削除 |
| GET /api/getUser/{userId} | GET /api/users/{userId} | GET | ユーザーリソースの取得 |
| POST /api/borrowBook | POST /api/loans | POST | 新規貸出リソースの作成 |
| POST /api/returnBook | PATCH /api/loans/{loanId} | PATCH | 貸出リソースのステータス更新 |
| POST /api/extendLoan | PATCH /api/loans/{loanId}/due-date | PATCH | 返却期限の部分更新 |
| POST /api/reserveBook | POST /api/reservations | POST | 新規予約リソースの作成 |
| POST /api/cancelReservation | DELETE /api/reservations/{reservationId} | DELETE | 予約リソースの削除 |

**PATCHリクエスト例**:
```json
PATCH /api/loans/111
{
  "status": "RETURNED",
  "returnDate": "2026-03-10T14:30:00"
}
```

**べき等性の保証**:
- GET/PUT/DELETE: 同じリクエストを複数回実行しても同じ結果
- POST: Idempotency-Keyヘッダーを使用して重複リクエストを検出

**参照**: セクション5 "API設計" - エンドポイント一覧

---

### 8. 変更影響範囲の広さ（モジュール境界の不明確さ）

**評価基準**: 変更容易性 & モジュール設計
**スコア**: 2/5 (Significant)

**問題**:
サービス層のコンポーネント図（セクション3.2）に、各サービスが依存するRepositoryのリストが明記されているが、サービス間の依存関係が不明確。例えば:
- 予約が利用可能になった時、誰が通知を送信するか？（ReservationService → NotificationService）
- 貸出時に予約キューを確認するか？（LoanService → ReservationService）
- レポート生成時にUserServiceを呼び出すか？

**影響**:
- **循環依存のリスク**: サービス間の呼び出し関係が設計されていないため、実装時に循環依存が発生しやすい
- **変更影響の予測困難**: 貸出ルール変更時に予約処理やレポート生成に影響するか判断できない
- **トランザクション境界の曖昧さ**: 複数サービスにまたがる処理のトランザクション境界が不明確

**リファクタリング推奨**:

1. **ドメインイベント駆動設計の導入**:
サービス間の直接呼び出しを避け、ドメインイベントで疎結合化:

```java
// Event
public class BookReturnedEvent {
    private final Long bookId;
    private final LocalDateTime returnedAt;
}

// LoanService
@Service
public class LoanService {
    private final ApplicationEventPublisher eventPublisher;

    public void returnBook(Long loanId) {
        Loan loan = loanRepository.findById(loanId);
        loan.markAsReturned(clock.now());
        loanRepository.save(loan);

        eventPublisher.publishEvent(new BookReturnedEvent(loan.getBookId(), clock.now()));
    }
}

// ReservationService
@Service
public class ReservationService {
    @EventListener
    public void onBookReturned(BookReturnedEvent event) {
        processReservationQueue(event.getBookId());
    }
}
```

2. **依存関係図の明示化**:
設計書に以下を追加:
```
サービス依存グラフ:
LoanService → (event) → ReservationService
ReservationService → (event) → NotificationService
BookManagementService → (独立)
ReportGenerationService → (read-only) → すべてのRepository
AuthenticationService → (独立)
```

3. **トランザクション境界の定義**:
```
パターン1（同一トランザクション）: 貸出処理 + 在庫更新
パターン2（結果整合性）: 貸出処理（commit） → イベント発行 → 予約処理（別トランザクション）
パターン3（補償トランザクション）: 予約処理失敗時、貸出をキャンセル
```

**参照**: セクション3.2 "主要コンポーネント"

---

## Moderate Issues

### 9. YAGNI違反の可能性（過剰なインフラストラクチャ）

**評価基準**: SOLID原則 & 構造設計
**スコア**: 3/5 (Moderate)

**問題**:
セクション2 "技術スタック"にRedisがキャッシュとして含まれているが、具体的なキャッシュ戦略、キャッシュ対象データ、キャッシュ無効化ポリシーが設計書に記載されていない。同時接続500人、API応答時間200msという非機能要件（セクション7）を考慮すると、初期段階でRedisが必要かどうか不明確。

**影響**:
- **複雑性の増加**: キャッシュ整合性の管理、Redis障害時のフォールバック処理が必要
- **運用コスト**: Redisインスタンスの監視、バックアップ、バージョン管理が必要
- **初期開発の遅延**: キャッシュレイヤーの実装とテストに時間がかかる

**推奨アプローチ**:

**Phase 1（MVP）**: Redisなしで開始
- PostgreSQLのクエリ最適化（インデックス、EXPLAIN ANALYZE）で200ms目標を達成
- Spring Bootの`@Cacheable`でローカルキャッシュ（Caffeine）を使用
- パフォーマンステストで実測値を取得

**Phase 2（スケール時）**: ボトルネック特定後にRedis導入
- 蔵書検索結果（読み取り頻度が高い、更新頻度が低い）をRedisにキャッシュ
- セッション情報（JWT検証結果）をRedisに保存してスケールアウト対応
- キャッシュ戦略を明記:
  ```
  - TTL: 蔵書検索 = 5分、ユーザー情報 = 1時間
  - 無効化: 書籍更新時に該当キャッシュをDELETE
  - フォールバック: Redis障害時はDBから直接取得
  ```

**参照**: セクション2 "技術スタック" - データベース、セクション7 "非機能要件"

---

### 10. モバイルアプリとWebの共通化戦略の欠如

**評価基準**: 拡張性 & 運用設計
**スコア**: 3/5 (Moderate)

**問題**:
セクション2にReact（Web）とFlutter（モバイル）が記載されているが、両者が同一のREST APIを使用するのか、異なるAPIバージョンを使用するのかが不明確。また、モバイル特有の要件（オフライン対応、プッシュ通知）が設計に含まれていない。

**影響**:
- **API互換性の問題**: Web向けにAPIを変更した際、モバイルアプリが動作しなくなるリスク
- **機能格差**: Webに新機能を追加してもモバイルが未対応になる
- **ユーザー体験の不整合**: オフライン時の動作がWebとモバイルで異なる

**推奨アプローチ**:

1. **APIバージョニング戦略の明確化**:
```
/api/v1/... : Web/モバイル共通エンドポイント
/api/v1/mobile/... : モバイル専用エンドポイント（プッシュ通知登録、オフライン同期）
```

2. **モバイル専用要件の設計**:
- **オフライン貸出履歴**: FlutterのローカルDB（Drift）に最新10件をキャッシュ
- **プッシュ通知**: Firebase Cloud Messaging経由で延滞通知を送信
- **Optimistic UI**: 予約リクエスト送信時に即座にUI更新、バックグラウンドで同期

3. **BFF（Backend for Frontend）パターンの検討**:
Web用とモバイル用で異なるBFFを用意し、共通のコアAPIを呼び出す:
```
React → Web BFF → Core API
Flutter → Mobile BFF → Core API
```

**参照**: セクション2 "技術スタック" - フロントエンド

---

### 11. 設定管理の環境差分戦略の不足

**評価基準**: 拡張性 & 運用設計
**スコア**: 3/5 (Moderate)

**問題**:
セクション6 "デプロイメント方針"に「環境別設定は環境変数で管理」と記載されているが、以下が不明確:
- 開発/ステージング/本番環境で異なる設定項目のリスト
- シークレット管理方法（パスワード、APIキー）
- 機能フラグの管理方法

**影響**:
- **本番環境での設定ミス**: 環境変数の設定漏れで本番デプロイ後に障害発生
- **セキュリティリスク**: シークレットがコードリポジトリやログに漏洩
- **機能リリースの硬直性**: 新機能を段階的にリリースできない

**推奨アプローチ**:

1. **設定項目の分類**:
```yaml
# application.yml (公開可能)
spring:
  datasource:
    url: ${DATABASE_URL}
  mail:
    host: ${SMTP_HOST}
    port: ${SMTP_PORT}

# application-dev.yml
logging:
  level:
    root: DEBUG

# application-prod.yml
logging:
  level:
    root: INFO
```

2. **シークレット管理**:
- AWS Secrets ManagerまたはParameter Storeを使用
- アプリケーション起動時にシークレットを取得し、環境変数に設定
- ローテーション戦略: データベースパスワードは90日ごとに自動更新

3. **機能フラグ**:
```java
@Configuration
public class FeatureFlags {
    @Value("${feature.reservation.enabled:true}")
    private boolean reservationEnabled;

    @Value("${feature.mobile-app.enabled:false}")
    private boolean mobileAppEnabled;
}
```

開発環境では新機能を有効化、本番環境では段階的にロールアウト。

**参照**: セクション6 "実装方針" - デプロイメント方針

---

### 12. ログ設計の可観測性不足

**評価基準**: エラーハンドリング & 可観測性
**スコア**: 3/5 (Moderate)

**問題**:
セクション6 "実装方針"に「すべてのAPIリクエスト/レスポンスをログに記録」と記載されているが、以下の可観測性要件が不足:
- 分散トレーシング（リクエストIDの伝搬）
- 構造化ログ（JSON形式）
- ビジネスメトリクス（貸出数/時間、予約キャンセル率）
- 個人情報のマスキング戦略

**影響**:
- **障害調査の困難**: 複数のAPIコールにまたがるエラーを追跡できない
- **パフォーマンス分析不能**: どのエンドポイントがボトルネックか特定できない
- **コンプライアンス違反**: ログに個人情報が平文で記録される

**推奨アプローチ**:

1. **構造化ログの導入**:
```java
log.info("Loan created",
    kv("loanId", loan.getId()),
    kv("userId", maskUserId(loan.getUserId())),
    kv("bookId", loan.getBookId()),
    kv("dueDate", loan.getDueDate())
);

// Output (JSON):
{
  "timestamp": "2026-02-11T10:30:00Z",
  "level": "INFO",
  "message": "Loan created",
  "loanId": 111,
  "userId": "****5678",
  "bookId": 67890,
  "dueDate": "2026-03-13T23:59:59",
  "traceId": "abc-123-def",
  "spanId": "span-456"
}
```

2. **分散トレーシングの導入**:
Spring Cloud Sleuth + Zipkinを使用:
```java
@Component
public class TraceFilter implements Filter {
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain) {
        String traceId = request.getHeader("X-Trace-Id");
        if (traceId == null) {
            traceId = UUID.randomUUID().toString();
        }
        MDC.put("traceId", traceId);
        chain.doFilter(request, response);
    }
}
```

3. **ビジネスメトリクスの収集**:
Micrometer + Prometheusで以下を計測:
- `library.loans.created` (Counter)
- `library.books.available` (Gauge)
- `library.api.response_time` (Timer)

4. **個人情報マスキング**:
```java
public String maskUserId(Long userId) {
    String str = userId.toString();
    return "****" + str.substring(Math.max(0, str.length() - 4));
}
```

**参照**: セクション6 "実装方針" - ロギング方針

---

## Positive Aspects

### 13. 適切な技術スタック選定

**評価基準**: 全体
**スコア**: 4/5

**良い点**:
- Spring Boot 3.1 + Java 17の組み合わせは、エンタープライズ向け図書館システムに適している
- PostgreSQL 15はリレーショナルデータの整合性保証に優れ、JPA経由での利用が容易
- Kubernetesによる水平スケーリングは、将来の利用者増加に対応可能

**参照**: セクション2 "技術スタック"

---

### 14. 明確な非機能要件の定義

**評価基準**: 拡張性 & 運用設計
**スコア**: 4/5

**良い点**:
セクション7にパフォーマンス目標（API応答時間200ms以内、同時接続500人）、セキュリティ要件（BCryptハッシュ化、JWT認証）、可用性（99.5%稼働率）が具体的に記載されており、実装時の判断基準として有用。

**参照**: セクション7 "非機能要件"

---

### 15. Blue-Greenデプロイメントによる無停止リリース

**評価基準**: 拡張性 & 運用設計
**スコア**: 4/5

**良い点**:
セクション6のデプロイメント方針にBlue-Greenデプロイメントが記載されており、本番環境でのダウンタイムを最小化する戦略が示されている。

**推奨強化**:
- データベースマイグレーション戦略（Flyway/Liquibase）を追加
- ロールバック手順の明記

**参照**: セクション6 "実装方針" - デプロイメント方針

---

## 総評

本設計書は、大学図書館向けシステムとして必要な機能要件と技術スタックを包括的に定義していますが、**構造設計の観点から複数の重大な問題**が存在します。

**最も深刻な問題は、`LibraryService`が5つの異なる責務を持つSRP違反**です。これは、長期的な保守性、テスタビリティ、スケーラビリティに重大な悪影響を及ぼします。早急に責務別のサービスクラスに分割すべきです。

また、**認証処理の重複、非正規化データの整合性戦略の欠如、RESTful API設計の違反**など、実装フェーズで深刻な問題を引き起こす可能性のある設計上の欠陥が複数確認されました。

一方で、技術スタック選定、非機能要件の明確化、Blue-Greenデプロイメント戦略などは適切であり、これらをベースに構造設計を改善することで、持続可能なシステムを構築できます。

**推奨される次のステップ**:
1. LibraryServiceを5つの責務別サービスに分割（Critical Issue #1対応）
2. 認証処理をAuthenticationServiceに統一（Critical Issue #2対応）
3. データモデルの非正規化戦略を明確化（Critical Issue #3対応）
4. RESTful API設計に準拠したエンドポイント再設計（Significant Issue #7対応）
5. ドメインイベント駆動設計の導入によるサービス間疎結合化（Significant Issue #8対応）
