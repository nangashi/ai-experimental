# TravelHub システム設計書

## 1. 概要

### プロジェクトの目的と背景
TravelHubは、複数の旅行事業者（航空会社、ホテル、レンタカー）のサービスを統合し、エンドユーザーに一元的な予約体験を提供するB2Cプラットフォームである。既存の旅行予約サイトと異なり、予約後の旅程管理機能（フライト遅延通知、代替便提案、自動リブッキング）を強化し、顧客体験を向上させる。

### 主要機能の一覧
1. 統合検索・予約（航空券、ホテル、レンタカー）
2. リアルタイム在庫管理・価格同期
3. 決済処理（クレジットカード、デジタルウォレット）
4. 旅程管理ダッシュボード
5. フライト遅延・欠航時の自動通知と代替案提示
6. マルチベンダー予約の一括キャンセル・変更
7. ロイヤリティポイント管理
8. モバイルアプリ（iOS/Android）とWebフロントエンド

### 対象ユーザーと利用シナリオ
- **対象ユーザー**: 個人旅行者、法人旅行管理者
- **主要シナリオ**:
  - 複数都市周遊旅行の一括予約（例: 東京→パリ→ロンドン→東京のフライト + 各都市のホテル）
  - フライト遅延時の自動代替便検索と予約変更
  - 旅程変更による関連予約の自動調整（例: フライト変更に伴うホテルチェックイン日の変更）

## 2. 技術スタック

- **言語・フレームワーク**:
  - Backend: Java 17, Spring Boot 3.2, Spring Cloud (Gateway, Circuit Breaker)
  - Frontend: React 18, Next.js 14
  - Mobile: React Native
- **データベース**:
  - PostgreSQL 15 (予約データ、ユーザー情報)
  - MongoDB 6.0 (検索インデックス、キャッシュ)
  - Redis 7.2 (セッション管理、レート制限)
- **メッセージング**: Apache Kafka 3.6 (イベント駆動アーキテクチャ)
- **インフラ**: AWS ECS (Fargate), Application Load Balancer, RDS Multi-AZ, DocumentDB, ElastiCache
- **主要ライブラリ**: Resilience4j (サーキットブレーカー), Spring Retry, Hibernate, Jackson

## 3. アーキテクチャ設計

### 全体構成
```
[Mobile/Web] → [API Gateway] → [Booking Service]
                              → [Payment Service]
                              → [Itinerary Service]
                              → [Notification Service]
                              ↓
                        [External Provider APIs]
                        - Flight API (Amadeus)
                        - Hotel API (Expedia)
                        - Car Rental API (各社API)
```

### 主要コンポーネントの責務と依存関係

#### Booking Service
- 外部プロバイダーAPIへの統合検索リクエスト送信
- 在庫確認・価格取得・予約作成の調整
- 予約状態の管理（検索中、仮予約、確定、キャンセル）
- **外部API依存**: Amadeus Flight API, Expedia Hotel API, レンタカー各社API

#### Payment Service
- 決済処理（Stripe, PayPal連携）
- 決済状態管理（保留、確定、返金）
- PCI DSS準拠のトークン化処理
- **外部API依存**: Stripe API, PayPal REST API

#### Itinerary Service
- 確定済み旅程の管理と変更
- フライト遅延・欠航情報の監視（Amadeus Flight Status API）
- 代替便の自動検索と提案
- 関連予約の整合性チェック（例: ホテルチェックイン日 < フライト到着日）

#### Notification Service
- メール通知（SendGrid）
- プッシュ通知（Firebase Cloud Messaging）
- SMS通知（Twilio）
- WebSocket接続によるリアルタイム更新（Socket.IO）

### データフロー

1. **予約フロー**:
   - ユーザー検索 → Booking Service → 外部プロバイダーAPI並列呼び出し → 結果集約 → MongoDB検索結果キャッシュ（30分TTL）
   - 仮予約作成 → PostgreSQL書き込み（状態: PENDING）
   - 決済実行 → Payment Service → Stripe API → 成功時にBooking Serviceへコールバック → PostgreSQL更新（状態: CONFIRMED）→ Kafkaイベント発行（BookingConfirmed）
   - Itinerary Service がKafkaイベントを消費 → 旅程レコード作成 → Notification Service呼び出し → 確認メール送信

2. **フライト遅延対応フロー**:
   - バックグラウンドジョブ（5分間隔）がAmadeus Flight Status APIをポーリング
   - 遅延検出 → Kafkaイベント発行（FlightDelayed）→ Itinerary Service が代替便検索開始 → Notification Service がユーザーに通知

## 4. データモデル

### PostgreSQL テーブル

#### bookings
| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| id | UUID | PK | 予約ID |
| user_id | UUID | NOT NULL, FK | ユーザーID |
| status | VARCHAR(20) | NOT NULL | PENDING/CONFIRMED/CANCELLED |
| total_amount | DECIMAL(10,2) | NOT NULL | 総額 |
| currency | CHAR(3) | NOT NULL | 通貨コード |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| confirmed_at | TIMESTAMP | NULL | 確定日時 |

#### booking_items
| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| id | UUID | PK | 予約項目ID |
| booking_id | UUID | NOT NULL, FK | 親予約ID |
| item_type | VARCHAR(20) | NOT NULL | FLIGHT/HOTEL/CAR |
| provider_code | VARCHAR(50) | NOT NULL | プロバイダー識別子 |
| provider_booking_ref | VARCHAR(100) | NOT NULL | プロバイダー側予約番号 |
| details | JSONB | NOT NULL | 予約詳細（フライト番号、日時等） |
| status | VARCHAR(20) | NOT NULL | ACTIVE/CANCELLED/MODIFIED |

#### payments
| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| id | UUID | PK | 決済ID |
| booking_id | UUID | NOT NULL, FK | 予約ID |
| amount | DECIMAL(10,2) | NOT NULL | 金額 |
| payment_method | VARCHAR(50) | NOT NULL | STRIPE/PAYPAL |
| transaction_id | VARCHAR(100) | UNIQUE | 決済プロバイダーのトランザクションID |
| status | VARCHAR(20) | NOT NULL | PENDING/COMPLETED/FAILED/REFUNDED |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### itineraries
| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| id | UUID | PK | 旅程ID |
| user_id | UUID | NOT NULL, FK | ユーザーID |
| booking_id | UUID | NOT NULL, FK | 関連予約ID |
| start_date | DATE | NOT NULL | 旅行開始日 |
| end_date | DATE | NOT NULL | 旅行終了日 |
| status | VARCHAR(20) | NOT NULL | ACTIVE/COMPLETED/DISRUPTED |

### MongoDB コレクション

#### search_cache
```json
{
  "_id": "ObjectId",
  "search_params_hash": "string (SHA-256)",
  "results": [
    {
      "provider": "string",
      "items": [/* 検索結果 */],
      "cached_at": "ISODate"
    }
  ],
  "ttl": "ISODate (30分後)"
}
```

## 5. API設計

### エンドポイント一覧

#### POST /api/v1/search
- **説明**: 統合検索（フライト、ホテル、レンタカー）
- **リクエスト**:
  ```json
  {
    "type": "FLIGHT",
    "origin": "NRT",
    "destination": "CDG",
    "departure_date": "2026-06-01",
    "passengers": 2
  }
  ```
- **レスポンス**: 200 OK, 検索結果の配列
- **タイムアウト**: 30秒（外部API呼び出し含む）

#### POST /api/v1/bookings
- **説明**: 予約作成（仮予約状態）
- **リクエスト**:
  ```json
  {
    "items": [
      {
        "type": "FLIGHT",
        "provider_item_id": "AF123-NRT-CDG-20260601",
        "details": { /* ... */ }
      }
    ]
  }
  ```
- **レスポンス**: 201 Created, 予約ID
- **処理フロー**: 外部プロバイダーAPIで仮予約作成 → PostgreSQL書き込み → Kafkaイベント発行

#### POST /api/v1/bookings/{id}/confirm
- **説明**: 予約確定（決済完了後）
- **処理フロー**: Payment Serviceが決済成功後に内部呼び出し → PostgreSQL更新 → Kafkaイベント発行

#### POST /api/v1/payments
- **説明**: 決済実行
- **リクエスト**:
  ```json
  {
    "booking_id": "uuid",
    "payment_method": "STRIPE",
    "token": "tok_xxx"
  }
  ```
- **レスポンス**: 200 OK (決済成功), 402 Payment Required (決済失敗)

#### GET /api/v1/itineraries/{id}
- **説明**: 旅程詳細取得
- **レスポンス**: 200 OK, 旅程情報（予約項目、フライトステータス含む）

### 認証・認可方式
- **認証**: JWT (JSON Web Token), 有効期限24時間
- **認可**: Spring Security, ロールベースアクセス制御（USER, ADMIN）
- **トークン発行**: POST /api/v1/auth/login → JWT返却
- **トークン更新**: POST /api/v1/auth/refresh

## 6. 実装方針

### エラーハンドリング方針
- **外部API障害**: Resilience4j サーキットブレーカーで障害検知 → 5xx応答時は代替プロバイダーへフォールバック（可能な場合）
- **決済失敗**: Stripe API失敗時は即時ユーザーに通知、予約状態をPENDINGのまま保持（30分後に自動キャンセル）
- **データ整合性エラー**: PostgreSQL制約違反時はロールバック、ユーザーに明確なエラーメッセージ返却

### ロギング方針
- **構造化ログ**: JSON形式、correlation_id（トレース用UUID）を全ログに付与
- **ログレベル**: ERROR（即時対応が必要）、WARN（監視が必要）、INFO（正常フロー）、DEBUG（開発時のみ有効化）
- **機密情報**: クレジットカード番号、パスワードは絶対にログ出力しない

### テスト方針
- **単体テスト**: JUnit 5, Mockito によるモック、カバレッジ80%以上
- **統合テスト**: Testcontainers によるPostgreSQL/Kafka のコンテナ起動、外部API はWireMock でスタブ化
- **E2Eテスト**: Selenium によるブラウザ自動化、本番同等環境で実施

### デプロイメント方針
- **デプロイ戦略**: Blue-Green デプロイメント、ALB のターゲットグループ切り替え
- **データベースマイグレーション**: Flyway による自動適用、本番デプロイ前にステージング環境で検証
- **ロールバック**: 前バージョンへのターゲットグループ切り替え（10分以内に実行可能）

## 7. 非機能要件

### パフォーマンス目標
- **API応答時間**: p95 < 500ms (検索API除く), 検索API p95 < 5秒
- **検索API並列実行**: 外部プロバイダーAPI を CompletableFuture で並列呼び出し、最遅プロバイダーを待たない（5秒でタイムアウト）
- **データベース**: PostgreSQL接続プール最大100接続、コネクションタイムアウト10秒

### セキュリティ要件
- **データ暗号化**: 転送時 TLS 1.3, 保管時 RDS 暗号化（AES-256）
- **PCI DSS準拠**: クレジットカード情報は自社サーバーに保存せず、Stripe トークンのみ保持
- **脆弱性スキャン**: 週次で依存ライブラリの脆弱性スキャン実施、Critical/High は48時間以内に対応

### 可用性・スケーラビリティ
- **SLA**: 99.9% 稼働率（月間ダウンタイム43分以内）
- **スケーリング**: ECS Auto Scaling, CPU使用率70%でスケールアウト（最小3タスク、最大20タスク）
- **データベース**: RDS Multi-AZ 構成、自動フェイルオーバー（60秒以内）
- **Redis**: ElastiCache クラスターモード有効化、3ノード構成

### 監視・アラート
- **メトリクス収集**: CloudWatch メトリクス（CPU, メモリ, レイテンシ, エラー率）
- **SLO**:
  - API可用性 > 99.9%
  - API p95レイテンシ < 500ms
  - 決済成功率 > 99%
- **アラート**:
  - API エラー率 > 5% で PagerDuty 通知
  - 外部プロバイダーAPI タイムアウト > 50% で Slack 通知
  - RDS CPU > 90% で 5分継続時に運用チームへ通知
