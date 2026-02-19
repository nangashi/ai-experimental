# Event Ticketing Platform System Design

## 1. 概要

本システムは、イベント主催者とチケット購入者をつなぐオンライン・チケット販売プラットフォームである。主催者はイベント情報を登録し、購入者はチケットを検索・購入・管理できる。

### 主要機能
- イベント管理（作成、編集、公開/非公開制御）
- チケット販売（座席指定、価格設定、在庫管理）
- 決済処理（クレジットカード、電子マネー）
- QRコードチケット発行と検証
- 購入履歴管理

### 対象ユーザー
- イベント主催者（コンサート、スポーツ、演劇、セミナー等）
- チケット購入者（一般消費者）
- 会場スタッフ（チケット検証・入場管理）

---

## 2. 技術スタック

| 項目 | 技術 |
|------|------|
| **言語** | TypeScript (Node.js 20.x) |
| **フレームワーク** | Express.js |
| **データベース** | PostgreSQL 15, Redis (セッション・キャッシュ) |
| **認証** | JWT (Access Token + Refresh Token) |
| **決済** | Stripe API |
| **インフラ** | AWS ECS (Fargate), RDS, ElastiCache, S3 |
| **監視** | CloudWatch, Sentry |

---

## 3. アーキテクチャ設計

### 全体構成
本システムは3層アーキテクチャで構成される:

- **Presentation Layer**: Express.js REST API
- **Business Logic Layer**: EventService, TicketService, PaymentService, AuthService
- **Data Access Layer**: PostgreSQL (Sequelize ORM)

### 主要コンポーネント

#### EventManager
イベント情報の登録・更新・検索を担当する。公開状態の制御、カテゴリ分類、検索フィルタリングを処理する。PostgreSQLに直接接続してイベントデータを保存し、Redisにキャッシュする。

#### TicketSalesEngine
チケット販売ロジックを担当する。在庫確認、座席予約、購入処理、キャンセル処理を行う。イベント情報の取得はEventManagerを直接呼び出す。決済処理はStripe APIを直接呼び出し、結果をデータベースに保存する。購入者へのメール送信、QRコード生成、イベント主催者への通知もこのコンポーネントが行う。

#### UserAuthService
ユーザー認証・認可を担当する。ユーザー登録、ログイン、JWT発行、権限チェックを行う。主催者と購入者の権限を管理する。

### データフロー

1. 購入者がチケット購入リクエストを送信
2. TicketSalesEngineが在庫を確認
3. Stripe APIで決済を実行
4. 決済成功時、チケット発行・QRコード生成・メール送信
5. EventManagerにイベント在庫を更新するよう通知

---

## 4. データモデル

### 主要エンティティ

#### users
| カラム | 型 | 制約 |
|--------|-----|------|
| user_id | UUID | PK |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| user_type | ENUM('organizer', 'customer') | NOT NULL |
| name | VARCHAR(100) | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |

#### events
| カラム | 型 | 制約 |
|--------|-----|------|
| event_id | UUID | PK |
| organizer_id | UUID | FK(users), NOT NULL |
| title | VARCHAR(200) | NOT NULL |
| description | TEXT | |
| venue_name | VARCHAR(200) | NOT NULL |
| venue_address | TEXT | |
| event_date | TIMESTAMP | NOT NULL |
| total_seats | INTEGER | NOT NULL |
| available_seats | INTEGER | NOT NULL |
| base_price | DECIMAL(10,2) | NOT NULL |
| status | ENUM('draft', 'published', 'closed') | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL |
| category | VARCHAR(50) | |
| organizer_name | VARCHAR(100) | |
| organizer_email | VARCHAR(255) | |

#### tickets
| カラム | 型 | 制約 |
|--------|-----|------|
| ticket_id | UUID | PK |
| event_id | UUID | FK(events), NOT NULL |
| purchaser_id | UUID | FK(users), NOT NULL |
| seat_number | VARCHAR(20) | |
| price | DECIMAL(10,2) | NOT NULL |
| purchase_date | TIMESTAMP | NOT NULL |
| qr_code | TEXT | NOT NULL |
| status | ENUM('valid', 'used', 'cancelled') | NOT NULL |
| payment_id | VARCHAR(100) | |
| event_title | VARCHAR(200) | |
| event_date | TIMESTAMP | |
| venue_name | VARCHAR(200) | |

---

## 5. API設計

### エンドポイント一覧

#### イベント管理
- `POST /events/create` - イベント作成
- `PUT /events/{eventId}/update` - イベント更新
- `DELETE /events/{eventId}/delete` - イベント削除
- `GET /events/search` - イベント検索
- `GET /events/{eventId}/details` - イベント詳細取得

#### チケット購入
- `POST /tickets/purchase` - チケット購入
- `POST /tickets/{ticketId}/cancel` - チケットキャンセル
- `GET /tickets/user/{userId}` - ユーザーのチケット一覧取得
- `POST /tickets/{ticketId}/validate` - QRコード検証

#### 認証
- `POST /auth/register` - ユーザー登録
- `POST /auth/login` - ログイン
- `POST /auth/refresh` - トークンリフレッシュ

### リクエスト/レスポンス形式

#### POST /tickets/purchase
```json
{
  "event_id": "uuid",
  "purchaser_id": "uuid",
  "seat_number": "A-12",
  "payment_method": "card"
}
```

#### Response (200 OK)
```json
{
  "ticket_id": "uuid",
  "qr_code": "base64-encoded-image",
  "purchase_date": "2026-02-11T12:00:00Z",
  "price": 5000
}
```

### 認証・認可方式
- JWTベースの認証を採用
- Access Token (有効期限: 15分) をローカルストレージに保存
- Refresh Token (有効期限: 7日) をローカルストレージに保存
- 主催者と購入者の権限を`user_type`フィールドで管理

---

## 6. 実装方針

### エラーハンドリング方針
- 外部API（Stripe）のエラーは呼び出し元でキャッチし、HTTPステータスコードで返す
- データベースエラーは500 Internal Server Errorとして返す
- バリデーションエラーは400 Bad Requestとして返す

### ロギング方針
- すべてのAPIリクエスト/レスポンスをCloudWatchに記録
- エラー発生時はSentryにスタックトレースを送信
- 決済処理の成功/失敗は詳細ログを記録

### テスト方針
実装完了後に統合テストを実施する。単体テストの方針は未定。

### デプロイメント方針
- ECS Fargateでコンテナ化してデプロイ
- Blue/Greenデプロイメントで本番切り替え
- 環境変数は`.env`ファイルで管理（dev/staging/prodを手動切り替え）

---

## 7. 非機能要件

### パフォーマンス目標
- APIレスポンス: 95%ile < 500ms
- 同時購入: 100リクエスト/秒を処理
- チケット検索: 2秒以内

### セキュリティ要件
- HTTPS通信
- SQLインジェクション対策（ORMのパラメータバインディング）
- XSS対策（入力サニタイゼーション）

### 可用性・スケーラビリティ
- 稼働率: 99.5%
- ECS AutoScalingで負荷に応じてスケール
- RDSはMulti-AZ構成
