# TravelHub システム設計書

## 1. 概要

### プロジェクトの目的と背景
TravelHubは、航空券・ホテル・レンタカーを一括検索・予約できるオンライン旅行プラットフォームです。ユーザーは単一のインターフェースで複数のサプライヤーの在庫を横断検索し、最適な旅行プランを組み立てることができます。

### 主要機能
- 航空券・ホテル・レンタカーの横断検索
- 予約管理（作成、変更、キャンセル）
- ユーザーアカウント管理（プロフィール、予約履歴）
- 決済処理（クレジットカード、デジタルウォレット）
- レビュー・評価システム
- 管理者用ダッシュボード（予約管理、レポート生成）

### 対象ユーザーと利用シナリオ
- **一般ユーザー**: 旅行の検索から予約、決済までを完結
- **ビジネスユーザー**: 出張の予約管理、経費精算データの出力
- **管理者**: 予約状況の監視、サプライヤー情報の管理

---

## 2. 技術スタック

### 言語・フレームワーク
- **Backend**: Java 17, Spring Boot 3.2, Spring Security
- **Frontend**: React 18, TypeScript 5.2
- **API Gateway**: Kong 3.4

### データベース
- **Primary DB**: PostgreSQL 15（予約データ、ユーザー情報）
- **Cache**: Redis 7.2（セッション、検索結果キャッシュ）
- **Search Engine**: Elasticsearch 8.10（ホテル・航空便検索）

### インフラ・デプロイ環境
- **Cloud Provider**: AWS（ECS Fargate, RDS, ElastiCache, OpenSearch Service）
- **CDN**: CloudFront
- **CI/CD**: GitHub Actions, AWS CodeDeploy
- **Monitoring**: CloudWatch, Datadog

### 主要ライブラリ
- Spring Data JPA 3.2.0
- Stripe Java SDK 23.10.0（決済処理）
- Lombok 1.18.30
- Apache Commons Lang 3.12
- Jackson 2.15.3

---

## 3. アーキテクチャ設計

### 全体構成
TravelHubは3層アーキテクチャを採用し、API Gatewayがすべてのクライアントリクエストのエントリーポイントとなります。

```
[Client (Web/Mobile)]
    ↓
[CloudFront (CDN)]
    ↓
[Kong API Gateway]
    ↓
[Backend Services Layer]
    ├── User Service (認証・アカウント管理)
    ├── Search Service (在庫検索)
    ├── Booking Service (予約管理)
    ├── Payment Service (決済処理)
    └── Admin Service (管理機能)
    ↓
[Data Layer]
    ├── PostgreSQL (主要データ)
    ├── Redis (キャッシュ・セッション)
    └── Elasticsearch (検索インデックス)
```

### 主要コンポーネントの責務

#### User Service
- ユーザー登録・ログイン処理
- JWTトークン発行・検証
- プロフィール管理
- パスワードリセット機能

#### Search Service
- サプライヤーAPIとの統合（航空会社、ホテルチェーン、レンタカー会社）
- 検索結果の集約とフィルタリング
- Elasticsearchへの検索クエリ実行

#### Booking Service
- 予約の作成・変更・キャンセル
- サプライヤーとの予約情報同期
- 予約状態管理

#### Payment Service
- Stripe決済APIとの連携
- 決済トランザクション記録
- 払い戻し処理

#### Admin Service
- 予約データのレポート生成
- ユーザー管理（アカウント停止など）
- システム設定の管理

### データフロー
1. ユーザーがログイン → User ServiceがJWT発行 → RedisにJWT情報を保存
2. 検索リクエスト → API Gateway → Search Service → Elasticsearch検索 + サプライヤーAPI呼び出し
3. 予約リクエスト → Booking Service → Payment Service → サプライヤーAPI → PostgreSQLに予約記録

---

## 4. データモデル

### 主要エンティティ

#### users テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| password_hash | VARCHAR(255) | NOT NULL | bcryptハッシュ化パスワード |
| full_name | VARCHAR(255) | NOT NULL | 氏名 |
| phone_number | VARCHAR(20) | | 電話番号 |
| role | VARCHAR(50) | NOT NULL | ロール（USER/ADMIN） |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

#### bookings テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | 予約ID |
| user_id | UUID | FK(users.id), NOT NULL | ユーザーID |
| booking_type | VARCHAR(50) | NOT NULL | 予約種別（FLIGHT/HOTEL/CAR） |
| supplier_id | VARCHAR(100) | NOT NULL | サプライヤー識別子 |
| status | VARCHAR(50) | NOT NULL | 予約状態（CONFIRMED/CANCELLED/PENDING） |
| total_amount | DECIMAL(10,2) | NOT NULL | 総額 |
| booking_details | JSONB | NOT NULL | 予約詳細（フライト情報等） |
| created_at | TIMESTAMP | NOT NULL | 予約日時 |

#### payment_transactions テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | トランザクションID |
| booking_id | UUID | FK(bookings.id), NOT NULL | 予約ID |
| stripe_payment_intent_id | VARCHAR(255) | UNIQUE, NOT NULL | Stripe PaymentIntent ID |
| amount | DECIMAL(10,2) | NOT NULL | 決済金額 |
| status | VARCHAR(50) | NOT NULL | 決済状態（SUCCESS/FAILED/REFUNDED） |
| created_at | TIMESTAMP | NOT NULL | 決済日時 |

---

## 5. API設計

### エンドポイント一覧

#### 認証・ユーザー管理
- `POST /api/v1/auth/register` - ユーザー登録
- `POST /api/v1/auth/login` - ログイン（JWT発行）
- `POST /api/v1/auth/reset-password` - パスワードリセットリンク送信
- `POST /api/v1/auth/confirm-reset` - パスワードリセット確定
- `GET /api/v1/users/profile` - プロフィール取得
- `PUT /api/v1/users/profile` - プロフィール更新
- `DELETE /api/v1/users/account` - アカウント削除

#### 検索
- `GET /api/v1/search/flights` - 航空券検索
- `GET /api/v1/search/hotels` - ホテル検索
- `GET /api/v1/search/cars` - レンタカー検索

#### 予約管理
- `POST /api/v1/bookings` - 予約作成
- `GET /api/v1/bookings` - 予約一覧取得
- `GET /api/v1/bookings/{id}` - 予約詳細取得
- `DELETE /api/v1/bookings/{id}` - 予約キャンセル
- `PUT /api/v1/bookings/{id}` - 予約変更

#### 決済
- `POST /api/v1/payments` - 決済実行
- `POST /api/v1/payments/{id}/refund` - 払い戻し

#### 管理
- `GET /api/v1/admin/bookings` - 全予約一覧
- `GET /api/v1/admin/users` - 全ユーザー一覧
- `PUT /api/v1/admin/users/{id}/suspend` - ユーザー停止

### リクエスト/レスポンス形式

すべてのAPIはJSON形式でリクエスト・レスポンスを処理します。

#### POST /api/v1/auth/login
**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "user@example.com",
    "fullName": "John Doe",
    "role": "USER"
  }
}
```

#### POST /api/v1/bookings
**Request:**
```json
{
  "bookingType": "FLIGHT",
  "supplierId": "AA",
  "bookingDetails": {
    "flightNumber": "AA123",
    "departureDate": "2024-12-01",
    "passengers": [{"name": "John Doe", "passportNumber": "X1234567"}]
  },
  "totalAmount": 45000.00
}
```

**Response:**
```json
{
  "id": "booking-uuid",
  "status": "CONFIRMED",
  "confirmationCode": "ABC123"
}
```

### 認証・認可方式

#### 認証
- JWT（JSON Web Token）を使用
- トークンはログイン時にUser Serviceが発行
- トークンの有効期限は1時間
- Redisにトークンのメタデータ（user_id, 発行時刻）を保存し、ログアウト時に無効化

#### 認可
- ロールベースアクセス制御（RBAC）を採用
- ロールは `USER` と `ADMIN` の2種類
- 各エンドポイントで必要なロールをSpring Securityの `@PreAuthorize` アノテーションで定義
- 管理者用エンドポイント（`/api/v1/admin/*`）は `ADMIN` ロールのみアクセス可能

---

## 6. 実装方針

### エラーハンドリング方針
- すべての例外を `GlobalExceptionHandler` で集約し、統一されたエラーレスポンスを返す
- エラーレスポンス形式:
  ```json
  {
    "error": {
      "code": "BOOKING_NOT_FOUND",
      "message": "指定された予約が見つかりません",
      "timestamp": "2024-11-15T10:30:00Z"
    }
  }
  ```

### ロギング方針
- SLF4J + Logbackを使用
- ログレベル: 本番環境はINFO、開発環境はDEBUG
- アプリケーションログは標準出力に出力し、CloudWatchで収集
- ログ形式: JSON構造化ログ（timestamp, level, message, context）

### テスト方針
- ユニットテスト: JUnit 5 + Mockitoで各レイヤーをテスト
- 統合テスト: Testcontainersで実際のPostgreSQL・Redisコンテナを使用
- E2Eテスト: Seleniumで主要な予約フローをテスト
- カバレッジ目標: 80%以上

### デプロイメント方針
- GitHub ActionsでCI/CDパイプラインを構築
- mainブランチへのpushでステージング環境に自動デプロイ
- 本番環境へはタグ付けでデプロイを実行
- Blue/Greenデプロイメントで無停止デプロイを実現

---

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- 検索処理: 3秒以内（外部サプライヤーAPIのタイムアウト含む）
- 同時接続数: 10,000接続を想定

### セキュリティ要件
- すべての通信はHTTPS/TLS 1.3以上を使用
- パスワードはbcryptでハッシュ化（cost factor 12）
- JWTトークンはHS256アルゴリズムで署名
- クレジットカード情報は保存せず、Stripeに委譲
- APIリクエストはKong API Gatewayでレート制限を設定（ユーザーあたり100req/min）

### 可用性・スケーラビリティ
- RDSはMulti-AZ構成で冗長化
- ECS Fargateは最小3タスク、最大10タスクで自動スケーリング
- RedisはElastiCacheのクラスターモードで可用性を確保
- CloudFrontでスタティックコンテンツをキャッシュ
