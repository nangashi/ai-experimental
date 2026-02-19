# スマートビルディング管理システム 設計書

## 1. 概要

### プロジェクトの目的と背景
本システムは、商業ビルや大型施設の省エネルギー化と快適性向上を目的とした統合管理プラットフォームである。各フロアに設置されたセンサー（温度、湿度、CO2濃度、人感）からリアルタイムでデータを収集し、空調・照明の自動制御、エネルギー消費の可視化、異常検知アラートを提供する。

### 主要機能の一覧
- センサーデータ収集・保存（1分間隔でデータ取得）
- リアルタイムダッシュボード表示（温度・湿度・CO2・人数）
- 空調・照明の自動制御（しきい値ベースの制御ロジック）
- エネルギー消費レポート生成（日次・月次・年次）
- 異常検知アラート（温度異常、センサー故障）
- 管理者用Web UI、テナント用モバイルアプリ

### 対象ユーザーと利用シナリオ
- **ビル管理者**: ダッシュボードで全フロアの状況を監視、エネルギー消費傾向を分析
- **テナント**: 自社専有フロアの環境状態を確認、空調設定の調整リクエスト
- **保守担当者**: センサー故障アラートを受信、機器メンテナンス計画を立案

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Python 3.10, FastAPI
- フロントエンド: React 18, TypeScript
- モバイルアプリ: React Native

### データベース
- PostgreSQL 14（センサーデータ、設定情報、ユーザー情報）

### インフラ・デプロイ環境
- クラウド: AWS
- コンピューティング: EC2 (t3.large x1)
- ストレージ: EBS (gp3, 500GB)
- ネットワーク: VPC, ALB

### 主要ライブラリ
- Pandas（データ集計・分析）
- Celery（非同期タスク処理）
- Redis（Celeryブローカー、セッション管理）
- Pydantic（データバリデーション）

## 3. アーキテクチャ設計

### 全体構成
システムは以下の3レイヤーで構成される:

1. **データ収集レイヤー**: IoTゲートウェイがセンサーからMQTTでデータ収集し、HTTP APIでバックエンドに送信
2. **アプリケーションレイヤー**: FastAPI、Celery、PostgreSQLで構成
3. **プレゼンテーションレイヤー**: React Web UI、React Nativeモバイルアプリ

### 主要コンポーネントの責務と依存関係

#### データ収集API
- センサーデータの受信・バリデーション
- データベースへの保存
- 異常検知ロジックの実行

#### ダッシュボードAPI
- フロア別・センサー別のデータ取得
- リアルタイム表示用のデータ変換
- 過去データの時系列グラフ生成

#### レポート生成サービス（Celeryタスク）
- 日次・月次のエネルギー消費レポート生成
- PDF出力・メール配信

#### 制御API
- 空調・照明の制御コマンド送信
- 制御履歴の記録

### データフロー
1. センサーデータ → IoTゲートウェイ → POST /api/sensors/data → バリデーション → PostgreSQL保存
2. Web UI → GET /api/dashboard/floor/{floor_id} → PostgreSQLクエリ → JSON返却
3. 定時バッチ → Celeryタスク → PostgreSQL集計 → PDFレポート生成 → S3保存 → メール送信

## 4. データモデル

### Sensorテーブル
| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | UUID | PK | センサーID |
| floor_id | UUID | FK (floors.id) | フロアID |
| sensor_type | VARCHAR(50) | NOT NULL | センサー種別（temperature, humidity, co2, occupancy） |
| location | VARCHAR(255) | | 設置場所 |
| status | VARCHAR(20) | | 稼働状態（active, inactive, error） |

### SensorDataテーブル
| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | BIGSERIAL | PK | データID |
| sensor_id | UUID | FK (sensors.id) | センサーID |
| timestamp | TIMESTAMP | NOT NULL | 測定日時 |
| value | FLOAT | NOT NULL | 測定値 |
| unit | VARCHAR(20) | | 単位（celsius, %, ppm） |

### Floorsテーブル
| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | UUID | PK | フロアID |
| building_id | UUID | FK (buildings.id) | ビルID |
| floor_number | INT | NOT NULL | フロア番号 |
| area_sqm | FLOAT | | フロア面積 |

### ControlHistoryテーブル
| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | BIGSERIAL | PK | 履歴ID |
| device_id | UUID | FK (devices.id) | デバイスID |
| action | VARCHAR(50) | | 制御アクション（turn_on, turn_off, set_temperature） |
| parameter | JSONB | | パラメータ（温度設定値など） |
| executed_at | TIMESTAMP | NOT NULL | 実行日時 |

## 5. API設計

### エンドポイント一覧

#### データ収集
- `POST /api/sensors/data` - センサーデータ登録（複数センサー分を一括受信）
- `GET /api/sensors/{sensor_id}` - センサー情報取得

#### ダッシュボード
- `GET /api/dashboard/floor/{floor_id}` - フロアのセンサー情報取得
- `GET /api/dashboard/floor/{floor_id}/history?from={start}&to={end}` - フロアの時系列データ取得

#### レポート
- `POST /api/reports/generate` - レポート生成リクエスト（非同期）
- `GET /api/reports/{report_id}` - レポートステータス確認・ダウンロード

#### 制御
- `POST /api/control/hvac/{device_id}` - 空調制御
- `POST /api/control/lighting/{device_id}` - 照明制御

### リクエスト/レスポンス形式（例）

#### POST /api/sensors/data
```json
// Request
{
  "sensor_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-02-11T10:00:00Z",
  "data": {
    "temperature": 22.5,
    "humidity": 55.2
  }
}

// Response (200 OK)
{
  "status": "success",
  "data_id": 123456
}
```

#### GET /api/dashboard/floor/{floor_id}
```json
// Response (200 OK)
{
  "floor_id": "660e8400-e29b-41d4-a716-446655440001",
  "floor_number": 5,
  "sensors": [
    {
      "sensor_id": "...",
      "sensor_type": "temperature",
      "latest_value": 22.5,
      "latest_timestamp": "2026-02-11T10:00:00Z"
    },
    ...
  ]
}
```

### 認証・認可方式
- JWT（JSON Web Token）ベースの認証
- トークン有効期限: 1時間
- リフレッシュトークン: 30日
- ロール: admin, manager, tenant

## 6. 実装方針

### エラーハンドリング方針
- APIレスポンスは統一形式（status, message, data）
- バリデーションエラー: 400 Bad Request
- 認証エラー: 401 Unauthorized
- 権限エラー: 403 Forbidden
- リソース未検出: 404 Not Found
- サーバーエラー: 500 Internal Server Error
- 全エラーをログに記録（ログレベル: ERROR）

### ロギング方針
- 構造化ログ（JSON形式）
- ログレベル: DEBUG（開発）、INFO（本番）
- API呼び出しログ（リクエストID、エンドポイント、レスポンスタイム）
- センサーデータ登録ログ（sensor_id, timestamp, value）
- 制御コマンド実行ログ（device_id, action, parameter）

### テスト方針
- ユニットテスト: pytest（カバレッジ80%以上）
- 統合テスト: TestContainers（PostgreSQL, Redisコンテナ）
- E2Eテスト: Playwright（主要シナリオのみ）

### デプロイメント方針
- Blue-Greenデプロイ（ダウンタイム最小化）
- デプロイ前にステージング環境でE2Eテスト実行
- ロールバック手順の準備（EC2のAMIスナップショット、RDSスナップショット）

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 全エンドポイント平均500ms以下
- ダッシュボード初期表示: 2秒以内
- 同時接続ユーザー数: 100ユーザー

### セキュリティ要件
- 通信暗号化: HTTPS（TLS 1.3）
- パスワードハッシュ化: bcrypt
- SQLインジェクション対策: パラメータ化クエリ（ORMレイヤー）
- XSS対策: React標準のエスケープ
- CSRF対策: SameSite Cookie属性

### 可用性・スケーラビリティ
- 目標稼働率: 99.9%（月次）
- バックアップ: 日次フルバックアップ、トランザクションログ継続バックアップ
- スケーリング方針: 初期は単一EC2インスタンス、負荷増加時にインスタンスサイズを拡大（垂直スケーリング）
- データ保持期間: センサーデータは1年間、制御履歴は3年間
