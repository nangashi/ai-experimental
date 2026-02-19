# Smart Building Management System 設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
本システムは、商業ビル・オフィスビルの設備（空調、照明、セキュリティ、電力）を統合管理し、エネルギー効率の最適化と運用コストの削減を実現するクラウドベースの管理プラットフォームである。IoTセンサーからのデータ収集、AI予測による自動制御、管理者向けダッシュボード、テナント向けモバイルアプリを提供する。

### 1.2 主要機能
- リアルタイムセンサーデータ収集・可視化（温度、湿度、照度、人感、電力消費）
- AI予測による空調・照明の自動制御（在室パターン学習、気象データ連携）
- 設備異常検知とアラート通知（設備故障予兆、エネルギー消費異常）
- テナント毎の利用状況分析・レポート生成
- モバイルアプリによる室温調整リクエスト

### 1.3 対象ユーザーと利用シナリオ
- **ビル管理者**: ダッシュボードで全設備の稼働状況を監視、異常発生時の対応
- **テナント**: モバイルアプリで室温調整リクエスト、電力使用状況の確認
- **保守業者**: 設備メンテナンス履歴の参照、作業報告の登録

## 2. 技術スタック

### 2.1 Backend
- **言語・フレームワーク**: Java 17, Spring Boot 3.2
- **データベース**:
  - PostgreSQL 15（設備マスタ、ユーザー管理、設定情報）
  - TimescaleDB（センサーデータの時系列保存、1秒間隔×数千センサー）
- **キャッシュ**: Redis 7（リアルタイムセンサー値、セッション管理）
- **メッセージング**: Apache Kafka（センサーデータストリーム、イベント駆動処理）

### 2.2 Frontend
- **Web管理画面**: React 18 + TypeScript + Material-UI
- **モバイルアプリ**: Flutter 3.x（iOS/Android）

### 2.3 インフラ・デプロイ環境
- **クラウド**: AWS（ECS Fargate, RDS, ElastiCache, MSK）
- **CI/CD**: GitHub Actions + AWS CodeDeploy
- **監視**: CloudWatch, Prometheus + Grafana

### 2.4 主要ライブラリ
- Spring Data JPA, Spring Security, Spring Cloud Config
- Jackson（JSON処理）, Lombok
- Resilience4j（Circuit Breaker）
- TensorFlow Lite（エッジAI予測モデル）

## 3. アーキテクチャ設計

### 3.1 全体構成
システムは以下の4レイヤーで構成される:

```
[Presentation Layer]
  - REST API Controller
  - WebSocket Handler (リアルタイムデータ配信)

[Application Layer]
  - BuildingService, DeviceService, SensorDataService
  - AlertService, AnalyticsService

[Domain Layer]
  - Entity (Building, Device, SensorData, Alert, Tenant)
  - Repository Interface

[Infrastructure Layer]
  - JPA Repository Implementation
  - Kafka Producer/Consumer
  - Redis Cache Manager
  - External API Client (気象API, 予測モデルAPI)
```

### 3.2 主要コンポーネントの責務

#### BuildingManagementController
- REST APIのエントリーポイント
- リクエストの検証、DTO変換
- BuildingServiceへの処理委譲

#### BuildingService
- ビル設備の統合管理ロジック
- センサーデータ集約、異常検知、制御指示の生成
- 外部API（気象予報、AI予測）の呼び出し
- トランザクション境界の管理

#### SensorDataCollector (Kafka Consumer)
- センサーデータストリームの受信
- データの正規化・バリデーション
- TimescaleDB + Redisへの保存

#### AlertManager
- 異常検知ルールの評価
- アラート生成・通知（メール、Slack、モバイルプッシュ）
- エスカレーション処理

### 3.3 データフロー

#### センサーデータ収集フロー
1. IoTゲートウェイがセンサーデータをKafka Topic `sensor-raw-data` に送信
2. SensorDataCollector (Kafka Consumer) がデータを受信
3. 正規化・バリデーション後、TimescaleDB + Redis に保存
4. 異常検知ルールを評価、閾値超過時はAlertManager にイベント発行
5. WebSocketで接続中のクライアントにリアルタイム配信

#### 制御指示フロー
1. 管理者またはAI予測エンジンが制御指示をBuildingServiceに送信
2. BuildingServiceが制御内容をデバイスコントローラーAPI（外部システム）に送信
3. 制御履歴をPostgreSQLに記録
4. Kafka Topic `device-control-events` にイベント発行

## 4. データモデル

### 4.1 主要エンティティ

#### Building（ビル）
- `id` (bigint, PK)
- `name` (varchar(255), NOT NULL)
- `address` (text)
- `total_floors` (int)
- `created_at`, `updated_at` (timestamp)

#### Device（設備・デバイス）
- `id` (bigint, PK)
- `building_id` (bigint, FK)
- `device_type` (varchar(50), NOT NULL) // 'HVAC', 'LIGHTING', 'SECURITY', 'POWER_METER'
- `location` (varchar(255))
- `status` (varchar(20)) // 'ACTIVE', 'INACTIVE', 'MAINTENANCE'
- `created_at`, `updated_at` (timestamp)

#### SensorData（センサーデータ）
- `time` (timestamptz, PK part)
- `device_id` (bigint, PK part)
- `metric_type` (varchar(50), PK part) // 'TEMPERATURE', 'HUMIDITY', 'POWER_CONSUMPTION'
- `value` (double precision)
- (TimescaleDB hypertable, partitioned by `time`)

#### Alert（アラート）
- `id` (bigint, PK)
- `building_id` (bigint, FK)
- `device_id` (bigint, FK, nullable)
- `alert_type` (varchar(50)) // 'DEVICE_FAILURE', 'ENERGY_SPIKE', 'COMFORT_VIOLATION'
- `severity` (varchar(20)) // 'CRITICAL', 'WARNING', 'INFO'
- `message` (text)
- `status` (varchar(20)) // 'OPEN', 'ACKNOWLEDGED', 'RESOLVED'
- `created_at`, `acknowledged_at`, `resolved_at` (timestamp)

#### Tenant（テナント）
- `id` (bigint, PK)
- `building_id` (bigint, FK)
- `name` (varchar(255), NOT NULL)
- `floor_numbers` (int[])
- `contact_email` (varchar(255))
- `created_at`, `updated_at` (timestamp)

### 4.2 データ整合性制約
- 外部キー制約: `Device.building_id` → `Building.id`, `Alert.building_id` → `Building.id`
- Unique制約: なし（同一ビルに同じ名前のデバイスが複数存在可能）

## 5. API設計

### 5.1 認証・認可方式
- JWT Bearer Token認証
- トークンはログイン時に発行、有効期限24時間
- Refresh Token機能なし（期限切れ時は再ログイン）
- ロール: `ADMIN`, `TENANT_USER`, `MAINTENANCE`

### 5.2 エンドポイント一覧

#### ビル管理
- `POST /buildings` - ビル登録 (ADMIN)
- `GET /buildings/{id}` - ビル詳細取得
- `GET /buildings/{id}/devices` - ビル内デバイス一覧
- `GET /buildings/{id}/current-status` - リアルタイム状況取得

#### デバイス管理
- `POST /devices` - デバイス登録 (ADMIN)
- `GET /devices/{id}` - デバイス詳細
- `PUT /devices/{id}/control` - デバイス制御指示
- `GET /devices/{id}/sensor-data?start={timestamp}&end={timestamp}` - センサーデータ取得

#### アラート管理
- `GET /alerts?buildingId={id}&status={status}` - アラート一覧
- `PUT /alerts/{id}/acknowledge` - アラート確認
- `PUT /alerts/{id}/resolve` - アラート解決

#### 分析・レポート
- `GET /analytics/energy-consumption?buildingId={id}&period={daily|monthly}` - エネルギー消費分析
- `GET /analytics/comfort-score?buildingId={id}&floor={number}` - 快適度スコア

### 5.3 リクエスト/レスポンス形式例

#### POST /buildings
```json
Request:
{
  "name": "Midtown Office Tower",
  "address": "1-1-1 Akasaka, Minato-ku, Tokyo",
  "total_floors": 30
}

Response: 201 Created
{
  "id": 123,
  "name": "Midtown Office Tower",
  "address": "1-1-1 Akasaka, Minato-ku, Tokyo",
  "total_floors": 30,
  "created_at": "2026-02-11T10:00:00Z"
}
```

#### GET /devices/{id}/sensor-data
```json
Response: 200 OK
{
  "device_id": 456,
  "data": [
    {"time": "2026-02-11T10:00:00Z", "metric_type": "TEMPERATURE", "value": 22.5},
    {"time": "2026-02-11T10:01:00Z", "metric_type": "TEMPERATURE", "value": 22.6}
  ]
}
```

## 6. 実装方針

### 6.1 エラーハンドリング方針
- Controllerで基本的なバリデーションエラーを捕捉、400 Bad Requestを返却
- Serviceレイヤーでビジネスロジックエラーを検出、カスタム例外（`ResourceNotFoundException`, `InvalidOperationException`）をスロー
- GlobalExceptionHandlerで集約処理、適切なHTTPステータスコードとエラーメッセージを返却
- 外部API呼び出し失敗時はResilience4jのCircuit Breakerでフォールバック（気象データ取得失敗時はキャッシュ値を使用）

### 6.2 ロギング方針
- ログレベル: DEBUG（開発）, INFO（本番）
- 構造化ログ（JSON形式）を採用、CloudWatch Logsに送信
- リクエストIDをMDCに格納、全ログに付与
- センサーデータ受信・デバイス制御・アラート生成のタイミングでINFOレベル出力

### 6.3 テスト方針
- 単体テスト: JUnit 5 + Mockito, カバレッジ目標80%
- 統合テスト: Spring Boot Test + Testcontainers（PostgreSQL, Redis, Kafka）
- E2Eテスト: Selenium（主要フロー: ログイン→ビル一覧→デバイス制御）

### 6.4 デプロイメント方針
- Blue/Greenデプロイ（ECS Fargateタスク定義更新）
- データベースマイグレーション: Flyway（アプリ起動時に自動実行）
- ロールバック: 旧タスク定義に切り戻し

## 7. 非機能要件

### 7.1 パフォーマンス目標
- API応答時間: 95%ile < 200ms
- センサーデータ書き込みスループット: 10,000 records/sec
- リアルタイムダッシュボード更新遅延: < 1秒

### 7.2 セキュリティ要件
- 通信は全てHTTPS
- JWT署名アルゴリズム: HS256
- パスワードはBCryptでハッシュ化（strength=10）
- SQLインジェクション対策: JPA Criteria API使用

### 7.3 可用性・スケーラビリティ
- 可用性目標: 99.5%（月間ダウンタイム < 4時間）
- ECS Fargateタスク数: 最小2, 最大10（CPU使用率70%で自動スケール）
- RDS: Multi-AZ配置
- Redis: Cluster Mode有効（3ノード構成）
