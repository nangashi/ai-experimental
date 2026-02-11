# TravelHub システム設計書

## 1. 概要

### プロジェクトの目的
TravelHubは、航空券・ホテル・レンタカーを一括で検索・予約できる統合型旅行予約プラットフォームです。個人旅行者とビジネス出張者の両方をターゲットとし、複数のサプライヤーと連携して最適な旅行プランを提案します。

### 主要機能
- ユーザー登録・ログイン（メールアドレス、SNSアカウント連携）
- 航空券・ホテル・レンタカーの横断検索
- 予約管理（予約作成、変更、キャンセル）
- 決済処理（クレジットカード、PayPal、銀行振込）
- レビュー・評価投稿
- トラベルポイントプログラム
- ビジネスアカウント向け出張管理機能

### 対象ユーザーと利用シナリオ
- **個人旅行者**: 家族旅行や個人旅行の計画と予約
- **ビジネス出張者**: 出張先の交通・宿泊手配
- **企業管理者**: 社員の出張履歴管理と予算管理

## 2. 技術スタック

### バックエンド
- 言語: Java 17
- フレームワーク: Spring Boot 3.1
- API: RESTful API
- 非同期処理: Spring WebFlux

### フロントエンド
- TypeScript 5.0
- React 18
- Next.js 14

### データベース
- メインDB: PostgreSQL 15
- キャッシュ: Redis 7.0
- 検索エンジン: Elasticsearch 8.7

### インフラ・デプロイ環境
- クラウドプロバイダー: AWS
- コンテナ化: Docker + Kubernetes
- CI/CD: GitHub Actions
- 監視: Datadog

### 主要ライブラリ
- 決済処理: Stripe SDK
- JWT認証: jose (TypeScript), jjwt (Java)
- バリデーション: Hibernate Validator
- HTTP通信: Spring WebClient

## 3. アーキテクチャ設計

### 全体構成
```
[Frontend (Next.js)]
       ↓ HTTPS
[API Gateway (AWS ALB)]
       ↓
[Backend Services]
  - User Service
  - Search Service
  - Booking Service
  - Payment Service
  - Review Service
       ↓
[Database Layer]
  - PostgreSQL (users, bookings, reviews)
  - Redis (session, cache)
  - Elasticsearch (search index)
```

### 主要コンポーネントの責務
- **User Service**: ユーザー認証・認可、プロフィール管理
- **Search Service**: サプライヤーAPIとの連携、検索結果のキャッシング
- **Booking Service**: 予約の作成・変更・キャンセル処理
- **Payment Service**: 決済処理、返金処理
- **Review Service**: レビュー投稿・閲覧、不適切コンテンツフィルタリング

### データフロー
1. ユーザーがフロントエンドで検索条件を入力
2. API Gateway経由でSearch Serviceに検索リクエスト送信
3. Search Serviceが複数サプライヤーAPIを並列呼び出し
4. 結果をElasticsearchにインデックス化し、Redisにキャッシュ
5. ユーザーが予約を確定すると、Booking Serviceが予約情報をPostgreSQLに保存
6. Payment Serviceが決済処理を実行し、完了後に予約を確定

## 4. データモデル

### ユーザーテーブル (users)
| カラム | 型 | 制約 |
|--------|-----|------|
| id | UUID | PRIMARY KEY |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| full_name | VARCHAR(100) | NOT NULL |
| phone | VARCHAR(20) | |
| created_at | TIMESTAMP | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL |

### 予約テーブル (bookings)
| カラム | 型 | 制約 |
|--------|-----|------|
| id | UUID | PRIMARY KEY |
| user_id | UUID | FOREIGN KEY (users.id) |
| booking_type | VARCHAR(20) | NOT NULL (flight/hotel/car) |
| supplier_id | VARCHAR(50) | NOT NULL |
| booking_reference | VARCHAR(50) | UNIQUE |
| total_amount | DECIMAL(10,2) | NOT NULL |
| status | VARCHAR(20) | NOT NULL (pending/confirmed/cancelled) |
| booking_details | JSONB | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |

### 決済テーブル (payments)
| カラム | 型 | 制約 |
|--------|-----|------|
| id | UUID | PRIMARY KEY |
| booking_id | UUID | FOREIGN KEY (bookings.id) |
| amount | DECIMAL(10,2) | NOT NULL |
| payment_method | VARCHAR(20) | NOT NULL |
| stripe_payment_id | VARCHAR(100) | |
| status | VARCHAR(20) | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |

### レビューテーブル (reviews)
| カラム | 型 | 制約 |
|--------|-----|------|
| id | UUID | PRIMARY KEY |
| booking_id | UUID | FOREIGN KEY (bookings.id) |
| user_id | UUID | FOREIGN KEY (users.id) |
| rating | INT | CHECK (rating >= 1 AND rating <= 5) |
| comment | TEXT | |
| created_at | TIMESTAMP | NOT NULL |

## 5. API設計

### 認証エンドポイント
- `POST /api/auth/signup`: 新規ユーザー登録
- `POST /api/auth/login`: ログイン（JWT発行）
- `POST /api/auth/logout`: ログアウト
- `POST /api/auth/password-reset`: パスワードリセット

### 検索エンドポイント
- `GET /api/search/flights`: 航空券検索
- `GET /api/search/hotels`: ホテル検索
- `GET /api/search/cars`: レンタカー検索

### 予約エンドポイント
- `POST /api/bookings`: 予約作成
- `GET /api/bookings/:id`: 予約詳細取得
- `PUT /api/bookings/:id`: 予約変更
- `DELETE /api/bookings/:id`: 予約キャンセル
- `GET /api/users/:userId/bookings`: ユーザーの予約一覧取得

### 決済エンドポイント
- `POST /api/payments`: 決済実行
- `POST /api/payments/:id/refund`: 返金処理

### レビューエンドポイント
- `POST /api/reviews`: レビュー投稿
- `GET /api/reviews`: レビュー一覧取得

### リクエスト/レスポンス形式
すべてのAPIはJSON形式で通信します。

```json
// POST /api/auth/login リクエスト例
{
  "email": "user@example.com",
  "password": "password123"
}

// POST /api/auth/login レスポンス例
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "user@example.com",
    "full_name": "山田太郎"
  }
}
```

### 認証・認可方式
- JWT（JSON Web Token）を使用
- トークンは24時間有効
- フロントエンドはlocalStorageにトークンを保存
- APIリクエスト時は`Authorization: Bearer <token>`ヘッダーで送信
- 管理者APIは追加でロールベースアクセス制御（RBAC）を適用

## 6. 実装方針

### エラーハンドリング方針
- すべての例外を`GlobalExceptionHandler`で集約処理
- ユーザー向けエラーメッセージとログ出力を分離
- 500エラー発生時はエラーIDを発行し、トレース可能にする

### ロギング方針
- すべてのAPIリクエスト/レスポンスをログ出力
- ログレベル: INFO（正常系）、WARN（リトライ可能なエラー）、ERROR（システムエラー）
- ログにはリクエストID、ユーザーID、タイムスタンプを含める

### テスト方針
- ユニットテスト: JUnit 5 + Mockito
- 統合テスト: Spring Boot Test + Testcontainers
- E2Eテスト: Playwright
- カバレッジ目標: 80%以上

### デプロイメント方針
- Blue-Green Deploymentを採用
- デプロイ前に自動テストを実行
- ステージング環境で動作確認後に本番環境にデプロイ

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- 検索API: 1000req/secをサポート
- データベース接続プール: 最大50接続

### セキュリティ要件
- すべての通信はHTTPSで暗号化
- データベース接続は専用のVPC内に閉じる
- 個人情報の暗号化保存

### 可用性・スケーラビリティ
- サービス可用性: 99.9%
- データベースはMulti-AZ構成
- Kubernetesで水平スケーリング（HPA）を設定
- オートスケーリング: CPU使用率70%を閾値
