# Payment Gateway System 設計書

## 1. 概要

### プロジェクトの目的と背景
オンライン決済を処理する統合決済ゲートウェイシステムを構築する。複数の決済プロバイダー（Stripe、PayPal、Square等）を統合し、マーチャント向けに統一APIを提供することで、EC事業者が単一のインテグレーションで複数の決済手段に対応できるようにする。

### 主要機能
- 決済処理（クレジットカード、デビットカード、電子マネー、銀行振込）
- 定期課金管理（サブスクリプション）
- 返金処理
- トランザクション履歴照会
- マーチャント管理（登録、設定、ダッシュボード）
- Webhook通知（決済成功/失敗、返金完了等）

### 対象ユーザーと利用シナリオ
- **マーチャント（EC事業者）**: 自社ECサイトに決済機能を統合
- **エンドユーザー**: ECサイトで商品購入時に決済を実施
- **管理者**: システム全体の監視、トラブルシューティング

## 2. 技術スタック

- **言語**: Java 17
- **フレームワーク**: Spring Boot 3.2, Spring WebFlux (非同期処理)
- **データベース**: PostgreSQL 15 (トランザクションデータ)、MongoDB (ログ保存)
- **メッセージング**: RabbitMQ (Webhook配信)
- **インフラ**: AWS ECS (コンテナオーケストレーション)、RDS、S3
- **主要ライブラリ**: Stripe Java SDK、PayPal SDK、Jackson (JSON処理)

## 3. アーキテクチャ設計

### 全体構成
3層アーキテクチャを採用する:

```
[API Layer] → [Service Layer] → [Data Access Layer]
```

### 主要コンポーネント

#### PaymentController
- REST APIエンドポイントを提供
- リクエストバリデーション
- レスポンスフォーマット変換
- 認証・認可チェック (JWT)
- Stripe/PayPal SDKの直接呼び出し（決済プロバイダーとの通信）

#### PaymentService
- 決済ビジネスロジックの実装
- トランザクション管理
- 決済ステータス更新
- 返金処理
- サブスクリプション管理
- Webhook配信ロジック
- 通知メール送信
- マーチャント残高計算
- レート制限チェック

#### PaymentRepository
- データベースアクセス
- CRUD操作

#### WebhookPublisher
- RabbitMQへのメッセージ送信

### データフロー
1. マーチャントがAPIエンドポイントに決済リクエスト送信
2. PaymentControllerがバリデーション実施後、PaymentServiceを呼び出し
3. PaymentServiceが決済プロバイダーSDKを直接呼び出し
4. 決済結果をPaymentRepositoryでDB保存
5. Webhook通知をWebhookPublisherで配信
6. レスポンスをマーチャントに返却

## 4. データモデル

### Payment (payments テーブル)
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | BIGINT | PK | 決済ID |
| merchant_id | VARCHAR(100) | NOT NULL | マーチャントID |
| merchant_name | VARCHAR(255) | NOT NULL | マーチャント名 |
| merchant_email | VARCHAR(255) | NOT NULL | マーチャントメールアドレス |
| amount | DECIMAL(10,2) | NOT NULL | 決済金額 |
| currency | VARCHAR(3) | NOT NULL | 通貨コード |
| provider | VARCHAR(50) | NOT NULL | 決済プロバイダー名 (stripe/paypal/square) |
| status | VARCHAR(20) | NOT NULL | ステータス (pending/success/failed/refunded) |
| external_transaction_id | VARCHAR(255) | | プロバイダー側トランザクションID |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

### Subscription (subscriptions テーブル)
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | BIGINT | PK | サブスクリプションID |
| merchant_id | VARCHAR(100) | NOT NULL | マーチャントID |
| amount | DECIMAL(10,2) | NOT NULL | 課金金額 |
| interval | VARCHAR(20) | NOT NULL | 課金頻度 (monthly/yearly) |
| status | VARCHAR(20) | NOT NULL | ステータス (active/paused/cancelled) |
| next_billing_date | DATE | | 次回課金日 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

### Refund (refunds テーブル)
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | BIGINT | PK | 返金ID |
| payment_id | BIGINT | FK → payments.id | 元の決済ID |
| amount | DECIMAL(10,2) | NOT NULL | 返金金額 |
| reason | TEXT | | 返金理由 |
| status | VARCHAR(20) | NOT NULL | ステータス (pending/completed/failed) |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

## 5. API設計

### エンドポイント一覧

#### 決済処理
- `POST /payments/create` - 決済作成
- `POST /payments/{id}/cancel` - 決済キャンセル
- `GET /payments/{id}` - 決済詳細取得
- `GET /payments` - 決済一覧取得

#### 返金処理
- `POST /payments/{id}/refund` - 返金処理
- `GET /refunds/{id}` - 返金詳細取得

#### サブスクリプション
- `POST /subscriptions/create` - サブスクリプション作成
- `POST /subscriptions/{id}/pause` - サブスクリプション一時停止
- `POST /subscriptions/{id}/resume` - サブスクリプション再開
- `DELETE /subscriptions/{id}` - サブスクリプション削除

#### Webhook
- `POST /webhooks/stripe` - Stripe Webhook受信
- `POST /webhooks/paypal` - PayPal Webhook受信

### リクエスト/レスポンス形式

#### POST /payments/create
**Request:**
```json
{
  "merchant_id": "m_12345",
  "amount": 10000,
  "currency": "JPY",
  "provider": "stripe",
  "payment_method": "card",
  "card_token": "tok_xxx"
}
```

**Response:**
```json
{
  "payment_id": 12345,
  "status": "success",
  "external_transaction_id": "ch_xxx",
  "created_at": "2026-02-11T10:00:00Z"
}
```

### 認証・認可方式
- API認証: JWT (Access Token有効期限: 1時間、Refresh Token有効期限: 30日)
- マーチャント認証: APIキー (リクエストヘッダー `X-API-Key` で送信)

## 6. 実装方針

### エラーハンドリング方針
- Spring WebFlux の `@ControllerAdvice` でグローバルエラーハンドリング実装
- 決済プロバイダーAPIエラー時は即座にクライアントへエラーレスポンス返却
- データベース接続エラー時は HTTP 500 を返却
- バリデーションエラー時は HTTP 400 を返却

### ロギング方針
- Logback を使用
- ログレベル: DEBUG (dev), INFO (staging), WARN (production)
- 決済リクエスト/レスポンスの全フィールドをログ出力（デバッグ用）

### テスト方針
現時点では未定義。今後検討予定。

### デプロイメント方針
- Docker イメージをビルドし、AWS ECRにプッシュ
- ECS Fargate でコンテナ起動
- Blue-Green デプロイメントを採用
- 環境変数で dev/staging/production の切り替え実施（データベース接続情報、決済プロバイダーAPIキー等をハードコード）

## 7. 非機能要件

### パフォーマンス目標
- 決済API応答時間: 95パーセンタイルで2秒以内
- 最大同時リクエスト数: 1000 req/s

### セキュリティ要件
- PCI DSS準拠（カード情報は自システムで保持せず、トークン化後にプロバイダーへ転送）
- API通信はHTTPS必須
- SQL Injection対策（PreparedStatement使用）

### 可用性・スケーラビリティ
- 可用性目標: 99.9% (年間ダウンタイム8.76時間以内)
- ECS Auto Scaling でコンテナ数を動的調整
- RDS Multi-AZ構成で耐障害性確保
