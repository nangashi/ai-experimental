# Real-Time Logistics Tracking Platform システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
物流業界向けのリアルタイム配送追跡プラットフォームを構築する。配送業者、荷主、受取人がリアルタイムで配送状況を追跡し、配送予定時刻の自動更新、配送完了の通知、配送遅延の早期検知を実現する。

### 1.2 主要機能
- 配送オーダー管理（オーダー登録、ステータス更新、履歴管理）
- リアルタイムトラッキング（GPS位置情報の取得、配送状況の可視化）
- 配送予定時刻の自動計算と更新
- 通知機能（SMS、Email、プッシュ通知による配送状況通知）
- 配送業者管理（配送業者の登録、評価、稼働状況管理）

### 1.3 対象ユーザーと利用シナリオ
- **荷主**: 配送オーダーの登録と追跡、配送業者の選定
- **配送業者**: 配送タスクの受領、配送状況の更新、配送完了報告
- **受取人**: 配送状況の確認、配送予定時刻の確認、受取希望時間の変更

## 2. 技術スタック

### 2.1 言語・フレームワーク
- バックエンド: Java 17, Spring Boot 3.2.x
- フロントエンド: React 18, TypeScript
- モバイルアプリ: React Native

### 2.2 データベース
- メインDB: PostgreSQL 15
- キャッシュ: Redis 7

### 2.3 インフラ・デプロイ環境
- クラウド: AWS (ECS Fargate, RDS, ElastiCache)
- CI/CD: GitHub Actions
- コンテナ: Docker

### 2.4 主要ライブラリ
- HTTP通信: Spring WebFlux (既存システムはRestTemplateを使用)
- 非同期処理: CompletableFuture
- 地図サービス連携: Google Maps API Java Client
- 通知: AWS SNS SDK

## 3. アーキテクチャ設計

### 3.1 全体構成
レイヤー構成は以下の通り:
- Presentation Layer (Controller)
- Application Layer (Service)
- Domain Layer (Entity, Repository)
- Infrastructure Layer (External API Client, Messaging)

既存システムは Controller → Service → Repository の依存方向を採用している。

### 3.2 主要コンポーネント

#### 3.2.1 配送オーダー管理
- `DeliveryOrderController`: 配送オーダーのREST APIエンドポイント
- `DeliveryOrderService`: 配送オーダーのビジネスロジック
- `DeliveryOrderRepository`: 配送オーダーのデータアクセス

#### 3.2.2 リアルタイムトラッキング
- `TrackingController`: トラッキング情報のREST APIエンドポイント
- `TrackingService`: GPS位置情報の取得と配送状況の計算
- `LocationUpdateProcessor`: 位置情報更新の非同期処理

#### 3.2.3 通知機能
- `NotificationService`: 通知の送信処理
- `NotificationTemplateRepository`: 通知テンプレートのデータアクセス

### 3.3 データフロー
1. 配送業者がモバイルアプリからGPS位置情報を送信
2. `TrackingController`が位置情報を受信し、`TrackingService`に渡す
3. `TrackingService`が配送状況を計算し、データベースを更新
4. 重要なステータス変更時に`NotificationService`が通知を送信
5. 受取人がWebアプリまたはモバイルアプリで配送状況を確認

## 4. データモデル

### 4.1 主要エンティティ

#### 4.1.1 配送オーダー (DeliveryOrder)
既存システムではテーブル名は複数形（例: `delivery_routes`, `tracking_events`）を使用している。

| カラム名 | 型 | 制約 | 説明 |
|---------|----|----|-----|
| id | UUID | PRIMARY KEY | オーダーID |
| order_number | VARCHAR(50) | UNIQUE NOT NULL | オーダー番号 |
| sender_id | UUID | NOT NULL | 荷主ID |
| receiver_id | UUID | NOT NULL | 受取人ID |
| carrier_id | UUID | NULL | 配送業者ID |
| status | VARCHAR(20) | NOT NULL | 配送ステータス (PENDING, ASSIGNED, IN_TRANSIT, DELIVERED, CANCELLED) |
| pickup_address | TEXT | NOT NULL | 集荷先住所 |
| delivery_address | TEXT | NOT NULL | 配送先住所 |
| scheduled_pickup_time | TIMESTAMP | NOT NULL | 集荷予定時刻 |
| scheduled_delivery_time | TIMESTAMP | NOT NULL | 配送予定時刻 |
| actual_pickup_time | TIMESTAMP | NULL | 実際の集荷時刻 |
| actual_delivery_time | TIMESTAMP | NULL | 実際の配送時刻 |
| createdAt | TIMESTAMP | NOT NULL DEFAULT NOW() | 作成日時 |
| updatedAt | TIMESTAMP | NOT NULL DEFAULT NOW() | 更新日時 |

#### 4.1.2 トラッキングイベント (tracking_event)
| カラム名 | 型 | 制約 | 説明 |
|---------|----|----|-----|
| id | UUID | PRIMARY KEY | イベントID |
| delivery_order_fk | UUID | FOREIGN KEY NOT NULL | 配送オーダーID |
| latitude | DECIMAL(10,7) | NOT NULL | 緯度 |
| longitude | DECIMAL(10,7) | NOT NULL | 経度 |
| event_type | VARCHAR(50) | NOT NULL | イベント種別 (LOCATION_UPDATE, STATUS_CHANGE, EXCEPTION) |
| event_description | TEXT | NULL | イベント詳細 |
| recorded_at | TIMESTAMP | NOT NULL DEFAULT NOW() | 記録日時 |

#### 4.1.3 配送業者 (carrier)
| カラム名 | 型 | 制約 | 説明 |
|---------|----|----|-----|
| id | UUID | PRIMARY KEY | 配送業者ID |
| carrier_name | VARCHAR(100) | NOT NULL | 配送業者名 |
| contact_phone | VARCHAR(20) | NOT NULL | 連絡先電話番号 |
| carrier_rating | DECIMAL(3,2) | NULL | 評価 (0.00-5.00) |
| is_active | BOOLEAN | NOT NULL DEFAULT TRUE | 稼働状況 |
| created_timestamp | TIMESTAMP | NOT NULL DEFAULT NOW() | 作成日時 |
| updated_timestamp | TIMESTAMP | NOT NULL DEFAULT NOW() | 更新日時 |

### 4.2 主要な関連
- `delivery_order.carrier_id` → `carrier.id` (多対一)
- `tracking_event.delivery_order_fk` → `delivery_order.id` (多対一)

## 5. API設計

### 5.1 エンドポイント一覧

#### 5.1.1 配送オーダー管理
既存システムのAPIエンドポイントは `/api/v1/delivery-routes`, `/api/v1/tracking-events` のようにリソース名をkebab-caseで表現している。

| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/v1/deliveryOrders` | 配送オーダーの作成 |
| GET | `/api/v1/deliveryOrders/{id}` | 配送オーダーの取得 |
| PUT | `/api/v1/deliveryOrders/{id}/status` | 配送ステータスの更新 |
| GET | `/api/v1/deliveryOrders` | 配送オーダー一覧の取得 |

#### 5.1.2 トラッキング
| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/v1/tracking/updateLocation` | 位置情報の更新 |
| GET | `/api/v1/tracking/{orderId}` | トラッキング履歴の取得 |

#### 5.1.3 配送業者管理
| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/v1/carriers` | 配送業者の登録 |
| GET | `/api/v1/carriers/{id}` | 配送業者情報の取得 |
| PUT | `/api/v1/carriers/{id}` | 配送業者情報の更新 |

### 5.2 リクエスト/レスポンス形式

#### 5.2.1 配送オーダー作成 (POST /api/v1/deliveryOrders)
既存システムのレスポンス形式は `{data: {...}, error: null}` または `{data: null, error: {...}}` の形式を使用している。

**リクエスト**:
```json
{
  "orderNumber": "ORD-20260211-001",
  "senderId": "uuid-sender-001",
  "receiverId": "uuid-receiver-001",
  "pickupAddress": "東京都港区...",
  "deliveryAddress": "神奈川県横浜市...",
  "scheduledPickupTime": "2026-02-12T09:00:00Z",
  "scheduledDeliveryTime": "2026-02-12T15:00:00Z"
}
```

**レスポンス（成功）**:
```json
{
  "success": true,
  "result": {
    "id": "uuid-order-001",
    "orderNumber": "ORD-20260211-001",
    "status": "PENDING",
    "createdAt": "2026-02-11T10:00:00Z"
  }
}
```

**レスポンス（エラー）**:
```json
{
  "success": false,
  "message": "Invalid pickup address",
  "errorCode": "VALIDATION_ERROR"
}
```

#### 5.2.2 位置情報更新 (POST /api/v1/tracking/updateLocation)
**リクエスト**:
```json
{
  "orderId": "uuid-order-001",
  "latitude": 35.6812,
  "longitude": 139.7671,
  "eventType": "LOCATION_UPDATE"
}
```

**レスポンス**:
```json
{
  "success": true,
  "result": {
    "eventId": "uuid-event-001",
    "recordedAt": "2026-02-12T10:30:00Z"
  }
}
```

### 5.3 認証・認可方式
- 認証: JWT (JSON Web Token)
- 認可: Role-based Access Control (RBAC)
- JWTの保存先: localStorageに保存し、APIリクエストのAuthorizationヘッダーに付与

## 6. 実装方針

### 6.1 エラーハンドリング方針
各コントローラーで個別にtry-catch文を実装し、例外を捕捉してエラーレスポンスを返す。

```java
@PostMapping("/deliveryOrders")
public ResponseEntity<?> createDeliveryOrder(@RequestBody DeliveryOrderRequest request) {
    try {
        DeliveryOrder order = deliveryOrderService.createOrder(request);
        return ResponseEntity.ok(new ApiResponse(true, order));
    } catch (ValidationException e) {
        return ResponseEntity.badRequest().body(new ApiResponse(false, e.getMessage(), "VALIDATION_ERROR"));
    } catch (Exception e) {
        return ResponseEntity.status(500).body(new ApiResponse(false, "Internal server error", "INTERNAL_ERROR"));
    }
}
```

### 6.2 ロギング方針
平文形式でログを出力する。ログレベルはINFO, WARN, ERRORを使い分ける。

```java
logger.info("Creating delivery order: {}", request.getOrderNumber());
logger.error("Failed to create delivery order: {}", e.getMessage());
```

### 6.3 テスト方針
- 単体テスト: JUnit 5, Mockito
- 統合テスト: Spring Boot Test, Testcontainers
- E2Eテスト: Selenium

### 6.4 デプロイメント方針
- Dockerコンテナ化してECS Fargateにデプロイ
- GitHub Actionsでmainブランチへのマージをトリガーに自動デプロイ
- データベースマイグレーション: Flyway

## 7. 非機能要件

### 7.1 パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以下
- 同時接続数: 10,000ユーザー
- 位置情報更新の処理: 毎秒1,000件以上

### 7.2 セキュリティ要件
- HTTPS通信の強制
- JWTの有効期限: 24時間
- パスワードのハッシュ化: bcrypt
- SQL Injection対策: PreparedStatementの使用
- CSRF対策: SameSite Cookieの設定

### 7.3 可用性・スケーラビリティ
- 可用性: 99.9%以上
- Auto Scaling: CPU使用率70%超過時にスケールアウト
- データベースのレプリケーション: Read Replica 2台

## 8. 既存システム前提条件

本設計は既存の物流管理システムの一部機能を拡張する形で開発する。既存システムとの一貫性を保つために以下のパターンを踏襲する必要がある。

### 8.1 既存の命名規約
- **テーブル名**: 複数形（例: `delivery_routes`, `tracking_events`, `carriers`）
- **カラム名**: snake_case
- **外部キー列名**: `{参照先テーブル名}_id` 形式（例: `carrier_id`, `route_id`）
- **タイムスタンプ列**: `created_at`, `updated_at` を標準とする
- **APIエンドポイント**: リソース名をkebab-caseで表現（例: `/api/v1/delivery-routes`）

### 8.2 既存の実装パターン
- **HTTP通信ライブラリ**: RestTemplate（既存システム全体で採用）
- **エラーハンドリング**: グローバル例外ハンドラ（`@ControllerAdvice` + `@ExceptionHandler`）を使用
- **ロギング**: 構造化ログ（JSON形式）をLogbackで出力、MDCでリクエストIDを伝播
- **APIレスポンス形式**: `{data: {...}, error: null}` または `{data: null, error: {...}}` の統一形式

### 8.3 既存のアーキテクチャパターン
- **依存方向**: Controller → Service → Repository の単方向依存
- **トランザクション管理**: Service層メソッドに `@Transactional` アノテーションを付与
- **非同期処理**: `@Async` + `CompletableFuture` を使用

### 8.4 既存のディレクトリ構造
```
src/main/java/com/logistics/
  ├── controller/
  ├── service/
  ├── repository/
  ├── entity/
  ├── dto/
  └── config/
```

レイヤー別のフォルダ構成（controller, service, repository）を採用している。
