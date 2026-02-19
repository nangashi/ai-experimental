# SmartHome IoTデバイス管理プラットフォーム システム設計書

## 1. 概要

### プロジェクトの目的と背景
SmartHome IoTデバイス管理プラットフォームは、家庭用IoTデバイス（スマート照明、温度センサー、カメラ、ドアロック等）を一元管理するクラウドプラットフォームである。デバイスメーカーがAPIを通じてデバイスを登録し、エンドユーザーがモバイルアプリ経由でデバイスを制御・監視できる。

### 主要機能
- デバイス登録・認証
- リアルタイムデバイス制御（照明ON/OFF、温度設定変更等）
- センサーデータ収集・可視化
- デバイスファームウェアOTA（Over-The-Air）更新
- ユーザー招待・権限管理（家族共有）
- アラート・通知機能

### 対象ユーザーと利用シナリオ
- **エンドユーザー**: スマートフォンアプリでデバイスを制御・監視
- **デバイスメーカー**: REST API経由でデバイスを登録・管理
- **家族メンバー**: 主ユーザーからの招待により、限定的な制御権限を取得

## 2. 技術スタック

### 言語・フレームワーク
- **バックエンド**: Node.js (Express 4.x)
- **フロントエンド**: React Native (モバイルアプリ)
- **リアルタイム通信**: Socket.IO

### データベース
- **メインDB**: PostgreSQL 14.x（デバイス登録情報、ユーザー管理）
- **時系列DB**: InfluxDB 2.x（センサーデータ蓄積）
- **キャッシュ**: Redis 7.x（セッション、リアルタイムステータス）

### インフラ・デプロイ環境
- **クラウド**: AWS
- **コンテナ**: ECS Fargate
- **ロードバランサ**: ALB
- **ストレージ**: S3（ファームウェアイメージ）

### 主要ライブラリ
- JWT認証: `jsonwebtoken` (v9.0)
- データ検証: `joi` (v17.x)
- MQTT通信: `mqtt` (v5.x)
- 暗号化: Node.js組み込み `crypto` モジュール

## 3. アーキテクチャ設計

### 全体構成
```
[Mobile App] --HTTPS--> [ALB] ---> [API Server (ECS)]
                                    |
                                    +--> [PostgreSQL]
                                    +--> [Redis]
                                    +--> [InfluxDB]

[IoT Device] --MQTT/TLS--> [MQTT Broker (ECS)] ---> [Device Gateway Service]
                                                      |
                                                      +--> [PostgreSQL]
                                                      +--> [Redis]
```

### 主要コンポーネント
- **API Server**: REST API（ユーザー認証、デバイス管理、データ取得）
- **MQTT Broker**: デバイスとの双方向通信（制御コマンド送信、テレメトリ受信）
- **Device Gateway Service**: デバイス認証、コマンド検証、データ正規化
- **OTA Update Service**: ファームウェア配信管理

### データフロー
1. ユーザーがモバイルアプリでデバイス制御リクエストを送信（REST API）
2. API ServerがRedisを通じてMQTT Brokerにコマンドを伝達
3. MQTT Brokerがデバイスにコマンドを送信
4. デバイスが状態変更を返信し、Device Gateway Serviceが検証・記録
5. 変更がSocket.IO経由でモバイルアプリにリアルタイム通知

## 4. データモデル

### 主要エンティティ

#### users テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| password_hash | VARCHAR(255) | NOT NULL | パスワードハッシュ（bcrypt） |
| created_at | TIMESTAMP | NOT NULL | 登録日時 |

#### devices テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | デバイスID |
| device_key | VARCHAR(64) | UNIQUE, NOT NULL | デバイス認証キー |
| owner_id | UUID | FK(users.id) | オーナーユーザー |
| type | VARCHAR(50) | NOT NULL | デバイスタイプ（light/sensor/camera） |
| firmware_version | VARCHAR(20) | | 現在のファームウェアバージョン |
| last_seen | TIMESTAMP | | 最終接続日時 |

#### device_access テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | アクセス権ID |
| device_id | UUID | FK(devices.id) | デバイスID |
| user_id | UUID | FK(users.id) | ユーザーID |
| permission | VARCHAR(20) | NOT NULL | 権限レベル（owner/write/read） |

#### ota_updates テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | 更新ID |
| device_type | VARCHAR(50) | NOT NULL | 対象デバイスタイプ |
| version | VARCHAR(20) | NOT NULL | ファームウェアバージョン |
| s3_url | VARCHAR(512) | NOT NULL | S3ダウンロードURL |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

## 5. API設計

### エンドポイント一覧

#### 認証系
- `POST /api/auth/signup` - ユーザー登録
- `POST /api/auth/login` - ログイン（JWT発行）
- `POST /api/auth/refresh` - トークンリフレッシュ

#### デバイス管理
- `GET /api/devices` - デバイス一覧取得
- `POST /api/devices` - デバイス登録（デバイスメーカー向け）
- `GET /api/devices/:id` - デバイス詳細取得
- `PUT /api/devices/:id/settings` - デバイス設定変更
- `POST /api/devices/:id/command` - デバイス制御コマンド送信

#### ユーザー招待・権限管理
- `POST /api/devices/:id/invite` - ユーザー招待
- `DELETE /api/devices/:id/access/:userId` - アクセス権削除

#### センサーデータ
- `GET /api/devices/:id/telemetry` - センサーデータ取得（時系列）

#### OTA更新
- `GET /api/ota/check` - 利用可能な更新確認（デバイス向け）
- `POST /api/ota/updates` - 更新パッケージ登録（管理者向け）

### 認証・認可方式

#### ユーザー認証
- JWT（JSON Web Token）を使用
- アクセストークン: 有効期限15分
- リフレッシュトークン: 有効期限7日間、Redisに保存

```javascript
// JWTペイロード例
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "iat": 1708000000,
  "exp": 1708000900
}
```

#### デバイス認証
- デバイスごとに一意の `device_key` を発行
- MQTT接続時に `device_key` をクライアントIDとして使用
- Device Gateway Serviceがデバイスキーの有効性を検証

#### APIアクセス制御
- ユーザーAPI: JWTトークンをAuthorizationヘッダーで送信
- デバイスAPI: `device_key` をAPIキーとして使用
- 権限レベル（owner/write/read）に応じてアクセス可否を判定

### リクエスト/レスポンス形式

#### デバイス制御コマンド送信
```json
// POST /api/devices/:id/command
Request:
{
  "command": "set_brightness",
  "params": {
    "brightness": 80
  }
}

Response:
{
  "status": "success",
  "executed_at": "2026-02-10T12:34:56Z"
}
```

#### センサーデータ取得
```json
// GET /api/devices/:id/telemetry?start=2026-02-09T00:00:00Z&end=2026-02-10T00:00:00Z
Response:
{
  "device_id": "device-uuid",
  "data": [
    {"timestamp": "2026-02-09T00:00:00Z", "temperature": 22.5},
    {"timestamp": "2026-02-09T01:00:00Z", "temperature": 22.3}
  ]
}
```

## 6. 実装方針

### エラーハンドリング方針
- 全てのAPIエンドポイントで統一的なエラーレスポンス形式を使用
```json
{
  "error": {
    "code": "DEVICE_NOT_FOUND",
    "message": "指定されたデバイスが見つかりません"
  }
}
```
- クライアント側エラー（4xx）とサーバー側エラー（5xx）を明確に区別
- 例外は最上位のエラーハンドラで捕捉し、適切なHTTPステータスコードを返す

### ロギング方針
- 構造化ログ（JSON形式）を使用
- ログレベル: DEBUG / INFO / WARN / ERROR
- 記録する情報:
  - リクエストID（X-Request-IDヘッダー）
  - ユーザーID
  - デバイスID
  - APIエンドポイント
  - レスポンスタイム
  - エラー詳細（スタックトレース含む）

### テスト方針
- ユニットテスト: Jest
- 統合テスト: Supertest（APIエンドポイント）
- E2Eテスト: Detox（モバイルアプリ）
- デバイスシミュレータを用いたMQTT通信テスト

### デプロイメント方針
- Blue/Greenデプロイメント
- ECS Fargateのタスク定義を更新し、新バージョンを段階的にロールアウト
- ロールバック可能な構成（前バージョンのタスク定義を保持）

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- デバイスコマンド実行: 平均1秒以内
- 同時接続デバイス数: 最大10万台
- API RPS: 最大5000リクエスト/秒

### セキュリティ要件
- 全ての通信をTLS 1.2以上で暗号化
- パスワードはbcryptでハッシュ化（コストファクタ10）
- APIレート制限: 同一IPから1分間に100リクエストまで
- デバイスファームウェア更新パッケージの署名検証

### 可用性・スケーラビリティ
- サービス稼働率: 99.9%（月間ダウンタイム43分以内）
- ECS Fargateのオートスケーリング設定（CPU使用率70%でスケールアウト）
- データベースのリードレプリカ（読み取り負荷分散）
- InfluxDBのシャーディング設定（デバイスタイプごとに分割）
