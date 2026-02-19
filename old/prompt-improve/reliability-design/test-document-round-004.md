# Payment Gateway System 設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
複数の決済手段（クレジットカード、銀行振込、電子マネー）を統合的に扱うペイメントゲートウェイシステムを構築する。加盟店からの決済リクエストを処理し、各決済プロバイダーとの連携を行う。既存の個別決済システムの統合により、加盟店の導入コストを削減し、運用の効率化を図る。

### 1.2 主要機能
- 決済リクエスト受付（クレジットカード、銀行振込、電子マネー）
- 決済プロバイダー連携（Stripe、PayPal、銀行API）
- トランザクション管理（承認、キャプチャ、返金、取り消し）
- 加盟店管理・認証
- 決済履歴照会・レポーティング
- Webhook通知（決済完了、失敗、返金等）

### 1.3 対象ユーザーと利用シナリオ
- **EC事業者**: 商品購入時の決済処理
- **サブスクリプションサービス**: 定期課金処理
- **マーケットプレイス**: 複数店舗の決済統合
- **企業向けSaaS**: B2B決済処理

## 2. 技術スタック

### 2.1 言語・フレームワーク
- **API Server**: Java 17, Spring Boot 3.2
- **Batch Processing**: Java 17, Spring Batch
- **Admin Console**: TypeScript, React 18

### 2.2 データベース
- **Primary DB**: PostgreSQL 15 (決済トランザクション、加盟店情報)
- **Cache**: Redis 7.2 (セッション、レート制限カウンタ)

### 2.3 インフラ・デプロイ環境
- **Container Orchestration**: Kubernetes (GKE)
- **Message Queue**: Google Cloud Pub/Sub
- **External APIs**: Stripe API, PayPal REST API, 各銀行API

### 2.4 主要ライブラリ
- Spring WebFlux (非同期処理)
- Resilience4j (リトライ、タイムアウト)
- Micrometer (メトリクス)

## 3. アーキテクチャ設計

### 3.1 全体構成
レイヤー構成は以下の通り:
- **API Gateway Layer**: 加盟店からのリクエストを受け付け
- **Application Layer**: ビジネスロジック処理
- **Integration Layer**: 外部決済プロバイダーとの通信
- **Data Layer**: PostgreSQL、Redisへのアクセス

### 3.2 主要コンポーネント
- **Payment API Service**: 決済リクエストのエントリーポイント
- **Transaction Manager**: トランザクション状態管理
- **Provider Gateway**: 各決済プロバイダーとの通信抽象化
- **Webhook Processor**: プロバイダーからの非同期通知処理
- **Batch Settlement Service**: 日次決済確定処理

### 3.3 データフロー
1. 加盟店から決済リクエストを受信
2. Transaction Managerがトランザクションレコードを作成（status: PENDING）
3. Provider Gatewayが該当プロバイダーのAPIを呼び出し
4. プロバイダーからの応答を受信し、トランザクションステータスを更新（AUTHORIZED/FAILED）
5. Webhook経由で最終結果を受信し、ステータスを更新（CAPTURED/SETTLED）
6. 加盟店にWebhook通知を送信

## 4. データモデル

### 4.1 主要エンティティ

#### Transactions テーブル
- `id` (UUID, PK)
- `merchant_id` (UUID, FK)
- `provider` (VARCHAR) - "stripe", "paypal", "bank_transfer"
- `amount` (DECIMAL)
- `currency` (VARCHAR)
- `status` (VARCHAR) - "PENDING", "AUTHORIZED", "CAPTURED", "SETTLED", "FAILED", "REFUNDED"
- `provider_transaction_id` (VARCHAR)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

#### Merchants テーブル
- `id` (UUID, PK)
- `name` (VARCHAR)
- `api_key` (VARCHAR)
- `webhook_url` (VARCHAR)
- `created_at` (TIMESTAMP)

#### Refunds テーブル
- `id` (UUID, PK)
- `transaction_id` (UUID, FK)
- `amount` (DECIMAL)
- `status` (VARCHAR) - "PENDING", "COMPLETED", "FAILED"
- `created_at` (TIMESTAMP)

## 5. API設計

### 5.1 エンドポイント一覧

#### POST /v1/payments
決済リクエスト作成

**Request:**
```json
{
  "merchant_id": "uuid",
  "amount": 10000,
  "currency": "JPY",
  "provider": "stripe",
  "payment_method": {
    "type": "card",
    "card_token": "tok_xxxxx"
  }
}
```

**Response:**
```json
{
  "transaction_id": "uuid",
  "status": "PENDING",
  "created_at": "2024-01-01T00:00:00Z"
}
```

#### POST /v1/payments/{transaction_id}/capture
決済確定（オーソリ後のキャプチャ）

#### POST /v1/payments/{transaction_id}/refund
返金処理

#### GET /v1/payments/{transaction_id}
トランザクション詳細取得

#### POST /webhooks/providers/{provider}
プロバイダーからのWebhook受信

### 5.2 認証・認可方式
- **加盟店認証**: API Key (Header: `X-API-Key`)
- **Webhook検証**: HMAC署名検証

## 6. 実装方針

### 6.1 エラーハンドリング方針
- ビジネスロジックエラー: 4xx HTTP ステータス
- システムエラー: 5xx HTTP ステータス
- エラーレスポンス形式:
```json
{
  "error_code": "PAYMENT_FAILED",
  "message": "Payment authorization failed",
  "details": {}
}
```

### 6.2 ロギング方針
- 構造化ログ（JSON形式）
- 各リクエストに correlation_id を付与
- 機密情報（カード番号、API Key）はマスキング

### 6.3 テスト方針
- Unit Test: JUnit 5, Mockito
- Integration Test: Testcontainers (PostgreSQL, Redis)
- E2E Test: プロバイダーSandbox環境を使用

### 6.4 デプロイメント方針
Kubernetes上でローリングアップデートを実施。デプロイ時はPodを順次入れ替え、新バージョンのPodが起動してからトラフィックを流す。

## 7. 非機能要件

### 7.1 パフォーマンス目標
- API応答時間: p95 < 500ms
- スループット: 1000 TPS

### 7.2 セキュリティ要件
- PCI DSS準拠（カード情報は保持しない、トークン化）
- TLS 1.3 による通信暗号化
- API Keyのローテーション機能

### 7.3 可用性・スケーラビリティ
- 可用性目標: 99.9% (月間ダウンタイム43分以内)
- Horizontal Pod Autoscaler で負荷に応じてスケール
- データベースはCloud SQL（マネージドサービス）を使用

### 7.4 障害回復設計
外部プロバイダーAPIへの呼び出しには、Resilience4jを使用したリトライ処理を実装する。リトライ回数は3回、指数バックオフ（初回1秒、最大10秒）を適用する。

タイムアウトは、プロバイダーごとに異なる値を設定する予定だが、具体的な値は実装フェーズで決定する。

### 7.5 監視・アラート設計
PrometheusとGrafanaを使用したメトリクス監視を行う。監視項目は以下を想定:
- HTTP リクエスト数・レスポンスタイム
- エラー率
- データベース接続数

### 7.6 データ整合性設計
決済トランザクションはPostgreSQLのACID特性により整合性を保証する。

返金処理は、元のトランザクションが`SETTLED`状態でない場合は拒否する。返金額の合計が元のトランザクション金額を超えないように、アプリケーションレイヤーでチェックを行う。

### 7.7 バッチ処理設計
日次で決済確定バッチを実行し、`CAPTURED`状態のトランザクションを`SETTLED`に更新する。バッチはSpring Batchで実装し、夜間（AM 2:00 JST）に実行する。処理中に障害が発生した場合は、アラートを発報し、翌朝手動でリカバリを行う。
