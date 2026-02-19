# Real-time Logistics Tracking System 設計書

## 1. 概要

### プロジェクトの目的と背景
物流業界向けのリアルタイム配送追跡システム。配送ドライバー、倉庫スタッフ、顧客が配送状況をリアルタイムで共有し、配送効率を最大化する。

### 主要機能
- 配送ルート最適化エンジン
- リアルタイム位置情報トラッキング
- 配送状況通知（SMS/Email/Push）
- 在庫管理と倉庫連携
- ドライバーパフォーマンス分析

### 対象ユーザー
- 配送ドライバー（モバイルアプリ）
- 倉庫管理者（Webダッシュボード）
- 顧客（トラッキングページ）
- 管理者（分析ツール）

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Java 17, Spring Boot 3.2
- フロントエンド: TypeScript, React 18
- モバイル: React Native

### データベース
- メインDB: PostgreSQL 15
- キャッシュ: Redis 7
- 検索: Elasticsearch 8

### インフラ・デプロイ環境
- AWS (ECS Fargate, RDS, ElastiCache)
- CI/CD: GitHub Actions
- モニタリング: CloudWatch, Datadog

### 主要ライブラリ
- ORM: Spring Data JPA
- HTTP通信: RestTemplate
- WebSocket: Spring WebSocket
- 地図API: Google Maps API

## 3. アーキテクチャ設計

### 全体構成
3層アーキテクチャを採用:
- **Presentation Layer**: REST API Controller
- **Business Logic Layer**: Service
- **Data Access Layer**: Repository

### 主要コンポーネント
- **DeliveryService**: 配送リクエストの作成・更新・状態管理
- **RouteOptimizer**: 配送ルートの最適化アルゴリズム
- **LocationTracker**: ドライバー位置情報のリアルタイム収集
- **NotificationDispatcher**: 通知の配信管理
- **WarehouseConnector**: 倉庫システムとの連携

### データフロー
```
顧客リクエスト → API Gateway → DeliveryService → RouteOptimizer → 配送割当
ドライバー位置 → LocationTracker → Redis (リアルタイムキャッシュ) → WebSocket → 顧客画面
```

## 4. データモデル

### 主要エンティティと関連

#### delivery テーブル
配送リクエストの管理。

| カラム名 | 型 | 制約 | 説明 |
|---------|-------|------|------|
| delivery_id | UUID | PK | 配送ID |
| order_number | VARCHAR(50) | NOT NULL, UNIQUE | 注文番号 |
| customer_id | UUID | FK → customer | 顧客ID |
| warehouse_id | UUID | FK → warehouse.id | 出荷倉庫ID |
| driver_id | UUID | FK → driver | 配送ドライバーID |
| pickup_address | TEXT | NOT NULL | 集荷住所 |
| delivery_address | TEXT | NOT NULL | 配送先住所 |
| status | VARCHAR(20) | NOT NULL | 配送状態（PENDING, IN_TRANSIT, DELIVERED, CANCELLED） |
| priority_level | INT | NOT NULL, DEFAULT 1 | 優先度（1-5） |
| scheduled_pickup_at | TIMESTAMP | NOT NULL | 集荷予定日時 |
| scheduled_delivery_at | TIMESTAMP | NOT NULL | 配送予定日時 |
| actual_pickup_at | TIMESTAMP | | 実際の集荷日時 |
| actual_delivery | TIMESTAMP | | 実際の配送完了日時 |
| created_at | TIMESTAMP | NOT NULL, DEFAULT NOW() | 作成日時 |
| updated | TIMESTAMP | NOT NULL, DEFAULT NOW() | 更新日時 |

#### driver テーブル
配送ドライバーの情報管理。

| カラム名 | 型 | 制約 | 説明 |
|---------|-------|------|------|
| driver_id | UUID | PK | ドライバーID |
| employee_number | VARCHAR(20) | NOT NULL, UNIQUE | 社員番号 |
| full_name | VARCHAR(100) | NOT NULL | 氏名 |
| phone_number | VARCHAR(20) | NOT NULL | 電話番号 |
| vehicle_type | VARCHAR(20) | NOT NULL | 車両タイプ（VAN, TRUCK, BIKE） |
| current_location | POINT | | 現在位置（PostGIS） |
| is_active | BOOLEAN | NOT NULL, DEFAULT TRUE | アクティブ状態 |
| created_date | TIMESTAMP | NOT NULL, DEFAULT NOW() | 登録日時 |
| last_updated | TIMESTAMP | NOT NULL, DEFAULT NOW() | 最終更新日時 |

#### warehouse テーブル
倉庫情報の管理。

| カラム名 | 型 | 制約 | 説明 |
|---------|-------|------|------|
| id | UUID | PK | 倉庫ID |
| warehouse_code | VARCHAR(10) | NOT NULL, UNIQUE | 倉庫コード |
| name | VARCHAR(100) | NOT NULL | 倉庫名 |
| address | TEXT | NOT NULL | 住所 |
| capacity | INT | NOT NULL | 保管容量 |
| createdAt | TIMESTAMP | NOT NULL, DEFAULT NOW() | 作成日時 |
| updatedAt | TIMESTAMP | NOT NULL, DEFAULT NOW() | 更新日時 |

#### customer テーブル
顧客情報の管理。

| カラム名 | 型 | 制約 | 説明 |
|---------|-------|------|------|
| customer_id | UUID | PK | 顧客ID |
| email | VARCHAR(100) | NOT NULL, UNIQUE | メールアドレス |
| name | VARCHAR(100) | NOT NULL | 顧客名 |
| phone | VARCHAR(20) | | 電話番号 |
| created | TIMESTAMP | NOT NULL, DEFAULT NOW() | 登録日時 |
| modified | TIMESTAMP | NOT NULL, DEFAULT NOW() | 最終更新日時 |

## 5. API設計

### エンドポイント一覧

#### 配送管理API
```
POST /api/v1/deliveries
  - 新規配送リクエスト作成
  - Request: { customerId, warehouseId, pickupAddress, deliveryAddress, scheduledPickupAt, scheduledDeliveryAt }
  - Response: { deliveryId, orderNumber, status, estimatedDeliveryTime }

GET /api/v1/deliveries/{deliveryId}
  - 配送詳細取得
  - Response: { deliveryId, orderNumber, customer, driver, status, currentLocation, timeline }

PATCH /api/v1/deliveries/{deliveryId}/status
  - 配送状態更新
  - Request: { status, actualTimestamp }
  - Response: { success, updatedDelivery }

GET /api/v1/deliveries/search
  - 配送検索
  - Query: status, customerId, driverId, dateFrom, dateTo
  - Response: { deliveries: [...], totalCount, page, pageSize }
```

#### ドライバー管理API
```
GET /api/v1/drivers
  - ドライバー一覧取得
  - Response: { drivers: [...], totalCount }

POST /api/v1/drivers
  - 新規ドライバー登録
  - Request: { employeeNumber, fullName, phoneNumber, vehicleType }
  - Response: { driverId, employeeNumber, status }

PUT /api/v1/drivers/{driverId}/location
  - ドライバー位置情報更新
  - Request: { latitude, longitude, timestamp }
  - Response: { success }
```

#### トラッキングAPI
```
GET /track/{orderNumber}
  - 配送追跡情報取得（顧客向け公開API）
  - Response: { orderNumber, status, currentLocation, estimatedArrival, timeline }
```

### レスポンス形式
成功時:
```json
{
  "data": { ... },
  "timestamp": "2026-02-11T10:30:00Z"
}
```

エラー時:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Error description"
  },
  "timestamp": "2026-02-11T10:30:00Z"
}
```

### 認証・認可方式
- JWT トークンベース認証
- トークンは HTTP-only Cookie に保存
- リフレッシュトークンは Redis に保存（TTL: 7日）
- API エンドポイントはロールベースアクセス制御（ADMIN, WAREHOUSE_STAFF, DRIVER, CUSTOMER）

## 6. 実装方針

### エラーハンドリング方針
すべての例外は `@ControllerAdvice` を使用したグローバルエクセプションハンドラーで処理する。各サービス層では業務例外（`BusinessException`）を throw し、コントローラー層での try-catch は使用しない。

### ロギング方針
構造化ログ（JSON形式）を採用。SLF4J + Logback を使用し、各ログエントリには traceId, userId, apiPath を自動付与する。ログレベルは DEBUG / INFO / WARN / ERROR の4段階。

### テスト方針
- ユニットテスト: JUnit 5 + Mockito
- 統合テスト: TestContainers で PostgreSQL/Redis コンテナを起動
- E2Eテスト: Playwright
- カバレッジ目標: 80%以上

### デプロイメント方針
- ブルーグリーンデプロイメント
- 本番環境へのデプロイ前にステージング環境で自動テスト実行
- ロールバック機能を常に有効化

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで 500ms 以内
- 同時接続ドライバー数: 5000+
- リアルタイム位置更新頻度: 10秒ごと

### セキュリティ要件
- すべてのAPIはHTTPSで通信
- パスワードは bcrypt でハッシュ化
- API レート制限: ユーザーあたり 1000リクエスト/時間
- 個人情報は暗号化して保存

### 可用性・スケーラビリティ
- SLA: 99.9% 稼働率
- オートスケーリング設定（CPU 70%でスケールアウト）
- Multi-AZ構成によるフェイルオーバー対応
