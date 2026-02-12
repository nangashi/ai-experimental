# スマート農業IoTプラットフォーム システム設計書

## 1. 概要

### プロジェクト背景
農業従事者の高齢化と労働力不足を解消し、データ駆動型の精密農業を実現するため、圃場環境の自動監視・分析・制御を行うIoTプラットフォームを構築する。

### 主要機能
- **環境センサー管理**: 温度・湿度・土壌水分・照度センサーからのリアルタイムデータ収集
- **圃場分析ダッシュボード**: 環境データの可視化・傾向分析
- **自動灌水制御**: 土壌水分値に基づく自動灌水システムの制御
- **異常アラート**: 環境閾値超過時の農業従事者への通知
- **収穫予測**: 過去データと気象データに基づく収穫時期・収量予測
- **レポート生成**: 週次・月次の圃場状態レポート

### 対象ユーザー
- 個人農家（小規模圃場、1-5センサー/圃場）
- 農業法人（大規模圃場、50-200センサー/圃場）
- 農業コンサルタント（複数クライアントの圃場を一括管理）

## 2. 技術スタック

- **バックエンド**: Node.js 18.x, Express.js 4.x
- **データベース**: PostgreSQL 15 (メインDB), MongoDB 6.0 (センサーデータ時系列保存)
- **メッセージブローカー**: MQTT (センサーデータ受信), RabbitMQ (非同期ジョブ)
- **インフラ**: AWS EC2 (t3.medium × 1インスタンス), RDS PostgreSQL, DocumentDB
- **フロントエンド**: React 18, Recharts (グラフ描画)
- **外部API**: OpenWeatherMap API (気象データ取得)

## 3. アーキテクチャ設計

### 全体構成
```
[IoTセンサー] --MQTT--> [MQTTブローカー] --> [データ収集サーバー]
                                                      |
                                                      v
                                              [PostgreSQL] + [MongoDB]
                                                      |
                                                      v
                         [Webアプリケーションサーバー] <-- [RabbitMQ]
                                                      |
                                                      v
                                                 [フロントエンド]
```

### 主要コンポーネント
- **Data Ingestion Service**: MQTTブローカーからセンサーデータを受信し、MongoDBに保存
- **API Gateway**: REST APIエンドポイントの提供（Express.js）
- **Analytics Service**: 収穫予測・傾向分析の実行
- **Report Generator**: 週次・月次レポートの自動生成（RabbitMQ経由で非同期実行）
- **Alert Notifier**: 異常検知時の農業従事者への通知（メール/SMS）

## 4. データモデル

### PostgreSQL (メインDB)
#### users テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | SERIAL | PRIMARY KEY | ユーザーID |
| name | VARCHAR(100) | NOT NULL | 氏名 |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| role | VARCHAR(20) | NOT NULL | ロール (farmer/consultant) |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### farms テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | SERIAL | PRIMARY KEY | 圃場ID |
| user_id | INTEGER | FOREIGN KEY | ユーザーID |
| name | VARCHAR(100) | NOT NULL | 圃場名 |
| location | VARCHAR(255) | | 所在地 |
| area_sqm | DECIMAL | | 面積（平方メートル） |

#### sensors テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | SERIAL | PRIMARY KEY | センサーID |
| farm_id | INTEGER | FOREIGN KEY | 圃場ID |
| sensor_type | VARCHAR(50) | NOT NULL | センサー種別 (temperature/humidity/soil_moisture/light) |
| device_id | VARCHAR(100) | UNIQUE, NOT NULL | デバイス識別子 |
| status | VARCHAR(20) | NOT NULL | 状態 (active/inactive/maintenance) |

#### irrigation_schedules テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | SERIAL | PRIMARY KEY | スケジュールID |
| farm_id | INTEGER | FOREIGN KEY | 圃場ID |
| trigger_condition | JSONB | NOT NULL | 発動条件（土壌水分閾値等） |
| duration_minutes | INTEGER | NOT NULL | 灌水時間 |
| last_executed_at | TIMESTAMP | | 最終実行日時 |

### MongoDB (センサーデータ時系列保存)
#### sensor_readings コレクション
```json
{
  "sensor_id": 123,
  "timestamp": "2026-02-11T10:30:00Z",
  "value": 24.5,
  "unit": "celsius"
}
```

## 5. API設計

### エンドポイント一覧
| メソッド | パス | 説明 |
|---------|------|------|
| GET | /api/farms/:farmId/dashboard | 圃場ダッシュボードデータ取得 |
| GET | /api/farms/:farmId/sensors | センサー一覧取得 |
| GET | /api/farms/:farmId/sensor-history/:sensorId | センサー履歴データ取得 |
| POST | /api/farms/:farmId/irrigation/execute | 手動灌水実行 |
| GET | /api/farms/:farmId/harvest-prediction | 収穫予測取得 |
| GET | /api/reports/:farmId | レポート一覧取得 |
| POST | /api/reports/:farmId/generate | レポート生成リクエスト |

### ダッシュボードデータ取得の実装
```javascript
app.get('/api/farms/:farmId/dashboard', async (req, res) => {
  const { farmId } = req.params;

  // 圃場情報取得
  const farm = await db.query('SELECT * FROM farms WHERE id = $1', [farmId]);

  // センサー一覧取得
  const sensors = await db.query('SELECT * FROM sensors WHERE farm_id = $1', [farmId]);

  // 各センサーの最新値取得
  const sensorReadings = [];
  for (const sensor of sensors.rows) {
    const reading = await mongodb.collection('sensor_readings')
      .find({ sensor_id: sensor.id })
      .sort({ timestamp: -1 })
      .limit(1)
      .toArray();
    sensorReadings.push(reading[0]);
  }

  // 灌水スケジュール取得
  const schedules = await db.query('SELECT * FROM irrigation_schedules WHERE farm_id = $1', [farmId]);

  res.json({
    farm: farm.rows[0],
    sensors: sensors.rows,
    current_readings: sensorReadings,
    irrigation_schedules: schedules.rows
  });
});
```

### センサー履歴データ取得
```javascript
app.get('/api/farms/:farmId/sensor-history/:sensorId', async (req, res) => {
  const { sensorId } = req.params;
  const { start_date, end_date } = req.query;

  const readings = await mongodb.collection('sensor_readings')
    .find({
      sensor_id: parseInt(sensorId),
      timestamp: { $gte: new Date(start_date), $lte: new Date(end_date) }
    })
    .sort({ timestamp: 1 })
    .toArray();

  res.json({ readings });
});
```

### 認証・認可
- **認証方式**: JWT (JSON Web Token)、有効期限24時間
- **認可**: ロールベース (farmer/consultant)、エンドポイントごとにロール制限

## 6. 実装方針

### エラーハンドリング
- API レベルで統一的なエラーレスポンス形式（`{ error: { code, message } }`）
- センサー通信エラー時は MongoDB への書き込み失敗を記録し、手動再送機能を提供

### ロギング
- Winston ライブラリ使用、ログレベル: ERROR, WARN, INFO, DEBUG
- API リクエスト/レスポンスのログ記録（リクエストID、ユーザーID、エンドポイント、レスポンス時間）

### テスト方針
- 単体テスト: Jest によるサービス層のテストカバレッジ 80% 以上
- 統合テスト: Supertest による API エンドポイントのテスト

### デプロイメント
- AWS EC2 への手動デプロイ、デプロイスクリプトで PM2 プロセスマネージャー再起動
- データベースマイグレーション: node-pg-migrate 使用

## 7. 非機能要件

### パフォーマンス
- センサーデータ収集: 100センサー同時接続で秒間1000メッセージ処理
- ダッシュボード表示: 3秒以内のレスポンス

### セキュリティ
- センサーデバイス認証: デバイスIDとプリシェアードキーによる認証
- API通信: HTTPS 必須
- パスワードハッシュ化: bcrypt 使用

### 可用性
- 稼働時間目標: 99.0%（農繁期は特に重視）
- データバックアップ: RDS 自動バックアップ（1日1回）
