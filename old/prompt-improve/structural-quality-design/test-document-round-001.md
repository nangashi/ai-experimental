# SmartLibrary システム設計書

## 1. 概要

SmartLibraryは、大学図書館向けの包括的な図書館管理システムである。

### プロジェクトの目的と背景
- 従来の紙ベースの図書管理業務をデジタル化し、業務効率を向上させる
- 学生・教員向けにオンライン蔵書検索、予約、貸出延長機能を提供する
- 図書館スタッフの業務負担を軽減し、利用者サービスの質を向上させる

### 主要機能
- 蔵書管理（登録、更新、廃棄、在庫管理）
- 利用者管理（学生・教員登録、アカウント管理、利用履歴）
- 貸出・返却処理（バーコードスキャン、貸出期限管理、延滞通知）
- オンライン予約・リクエスト（予約、予約キャンセル、順番待ち管理）
- 蔵書検索（タイトル、著者、ISBN、カテゴリ検索）
- レポート生成（貸出統計、人気書籍ランキング、延滞レポート）

### 対象ユーザー
- 図書館利用者（学生、教員）: 蔵書検索、予約、貸出履歴確認
- 図書館スタッフ: 貸出・返却処理、蔵書管理、利用者管理
- 図書館管理者: 統計レポート確認、システム設定管理

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Java 17 + Spring Boot 3.1
- フロントエンド: React 18 + TypeScript
- モバイルアプリ: Flutter 3.10

### データベース
- メインDB: PostgreSQL 15
- キャッシュ: Redis 7.0

### インフラ・デプロイ環境
- クラウド: AWS (EC2, RDS, S3, CloudFront)
- コンテナ: Docker + Kubernetes
- CI/CD: GitHub Actions

### 主要ライブラリ
- Spring Data JPA
- Spring Security
- JWT (io.jsonwebtoken:jjwt)
- Apache POI (レポート生成)

## 3. アーキテクチャ設計

### 全体構成
システムは以下の3層アーキテクチャで構成される:
- プレゼンテーション層: React/Flutter UI
- アプリケーション層: Spring Boot REST API
- データアクセス層: Spring Data JPA + PostgreSQL

### 主要コンポーネント
#### LibraryService
図書の貸出・返却、蔵書管理、予約処理、レポート生成、および利用者認証を担当する中核サービス。BookRepository、LoanRepository、UserRepository、ReservationRepositoryに直接アクセスしてデータを操作する。

#### UserService
ユーザー登録、認証、プロフィール更新を担当。JWTトークン生成もこのサービスで実施する。

#### NotificationService
メール通知（延滞通知、予約完了通知）を担当。JavaMailSenderを使用してSMTP経由で送信する。

### データフロー
1. ユーザーがWebブラウザ/モバイルアプリからリクエストを送信
2. Spring Boot APIがリクエストを受け取り、LibraryServiceまたはUserServiceを呼び出す
3. サービスがRepositoryを介してPostgreSQLにアクセス
4. 結果をJSON形式でクライアントに返却

## 4. データモデル

### users テーブル
| カラム | 型 | 制約 | 説明 |
|-------|-----|-----|------|
| id | BIGINT | PRIMARY KEY | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| password | VARCHAR(255) | NOT NULL | ハッシュ化パスワード |
| name | VARCHAR(100) | NOT NULL | 氏名 |
| role | VARCHAR(20) | NOT NULL | ロール (STUDENT, STAFF, ADMIN) |
| status | VARCHAR(20) | | ステータス (ACTIVE, SUSPENDED) |
| created_at | TIMESTAMP | | 作成日時 |
| student_id | VARCHAR(20) | | 学籍番号 |
| department | VARCHAR(100) | | 所属学部 |

### books テーブル
| カラム | 型 | 制約 | 説明 |
|-------|-----|-----|------|
| id | BIGINT | PRIMARY KEY | 書籍ID |
| isbn | VARCHAR(13) | | ISBN |
| title | VARCHAR(500) | NOT NULL | タイトル |
| author | VARCHAR(200) | | 著者 |
| publisher | VARCHAR(200) | | 出版社 |
| category | VARCHAR(50) | | カテゴリ |
| status | VARCHAR(20) | | ステータス (AVAILABLE, BORROWED, LOST) |
| location | VARCHAR(50) | | 配架場所 |
| total_copies | INT | | 所蔵数 |
| available_copies | INT | | 貸出可能数 |

### loans テーブル
| カラム | 型 | 制約 | 説明 |
|-------|-----|-----|------|
| id | BIGINT | PRIMARY KEY | 貸出ID |
| user_id | BIGINT | FOREIGN KEY | ユーザーID |
| book_id | BIGINT | FOREIGN KEY | 書籍ID |
| loan_date | TIMESTAMP | NOT NULL | 貸出日 |
| due_date | TIMESTAMP | NOT NULL | 返却期限 |
| return_date | TIMESTAMP | | 返却日 |
| status | VARCHAR(20) | | ステータス (ACTIVE, RETURNED, OVERDUE) |
| user_name | VARCHAR(100) | | 利用者名（冗長データ） |
| book_title | VARCHAR(500) | | 書籍タイトル（冗長データ） |

### reservations テーブル
| カラム | 型 | 制約 | 説明 |
|-------|-----|-----|------|
| id | BIGINT | PRIMARY KEY | 予約ID |
| user_id | BIGINT | FOREIGN KEY | ユーザーID |
| book_id | BIGINT | FOREIGN KEY | 書籍ID |
| reservation_date | TIMESTAMP | NOT NULL | 予約日時 |
| status | VARCHAR(20) | | ステータス (PENDING, READY, CANCELLED) |

## 5. API設計

### エンドポイント一覧

#### 認証・ユーザー管理
- POST /api/login - ユーザーログイン
- POST /api/register - ユーザー登録
- POST /api/user/updateProfile - プロフィール更新
- GET /api/getUser/{userId} - ユーザー情報取得

#### 蔵書検索・管理
- GET /api/searchBooks?keyword={keyword}&category={category} - 蔵書検索
- POST /api/addBook - 新規書籍登録
- POST /api/updateBook - 書籍情報更新
- POST /api/deleteBook/{bookId} - 書籍削除

#### 貸出・返却
- POST /api/borrowBook - 図書貸出
- POST /api/returnBook - 図書返却
- POST /api/extendLoan - 貸出期限延長
- GET /api/user/{userId}/loans - ユーザーの貸出履歴取得

#### 予約
- POST /api/reserveBook - 図書予約
- POST /api/cancelReservation - 予約キャンセル
- GET /api/user/{userId}/reservations - ユーザーの予約一覧

#### レポート
- GET /api/generateLoanReport?startDate={start}&endDate={end} - 貸出レポート生成
- GET /api/getPopularBooks?limit={limit} - 人気書籍ランキング

### リクエスト/レスポンス形式
すべてのAPIはJSON形式でデータを送受信する。

#### 貸出リクエスト例
```json
{
  "userId": 12345,
  "bookId": 67890
}
```

#### 貸出レスポンス例
```json
{
  "success": true,
  "loanId": 111,
  "dueDate": "2026-03-13T23:59:59"
}
```

### 認証・認可方式
- JWT (JSON Web Token) を使用した認証
- トークンはログイン時に生成され、各APIリクエストのAuthorizationヘッダーに含めて送信
- トークンの有効期限は24時間

## 6. 実装方針

### エラーハンドリング方針
各サービスクラスのメソッドで発生する例外は、GlobalExceptionHandlerでキャッチして適切なHTTPステータスコードとエラーメッセージをクライアントに返す。データベース接続エラー、バリデーションエラー、業務ロジックエラーなど、エラーの種類に応じて異なる処理を行う。

### ロギング方針
- Logback + SLF4Jを使用
- ログレベル: ERROR, WARN, INFO, DEBUG
- 本番環境ではINFOレベル以上を出力
- すべてのAPIリクエスト/レスポンスをログに記録

### テスト方針
単体テスト、統合テスト、E2Eテストを実施する。単体テストではJUnit 5とMockitoを使用し、各サービスクラスのロジックを検証する。統合テストではTestcontainersを使用してPostgreSQLコンテナを起動し、実際のデータベースを使ったテストを実施する。

### デプロイメント方針
- Dockerイメージをビルドし、ECRにプッシュ
- Kubernetesマニフェストを適用してEKSクラスターにデプロイ
- Blue-Green デプロイメントで無停止リリースを実現
- 環境別設定は環境変数で管理（DATABASE_URL, REDIS_URL等）

## 7. 非機能要件

### パフォーマンス目標
- API レスポンスタイム: 平均 200ms 以内
- 同時接続ユーザー数: 500人
- 蔵書検索レスポンス: 1秒以内

### セキュリティ要件
- パスワードはBCryptでハッシュ化して保存
- JWT認証によるAPIアクセス制御
- SQL インジェクション対策（プリペアドステートメント使用）
- XSS対策（入力値のサニタイズ）

### 可用性・スケーラビリティ
- 稼働率: 99.5% 以上
- データベースの自動バックアップ（日次）
- アプリケーションサーバーの水平スケーリング（負荷に応じて Pod 数を自動調整）
