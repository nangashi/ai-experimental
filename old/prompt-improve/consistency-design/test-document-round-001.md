# スマートホーム統合プラットフォーム システム設計書

## 1. 概要

### プロジェクトの目的と背景
IoTデバイス（照明、温度センサー、セキュリティカメラ等）を統合管理するクラウドプラットフォームを構築する。複数メーカーのデバイスを統一APIで操作可能にし、ユーザーが自宅のスマートホームデバイスを一元管理できる環境を提供する。

### 主要機能
- デバイス登録・管理（デバイス追加、削除、ステータス確認）
- リアルタイム制御（デバイスへのコマンド送信、ステータス取得）
- 自動化ルール設定（条件トリガーに基づくアクションの実行）
- ユーザー通知（デバイス異常時のアラート）
- データ分析・レポート（使用状況の可視化）

### 対象ユーザーと利用シナリオ
- **一般ユーザー**: スマートフォンアプリから自宅デバイスを操作
- **デバイスメーカー**: API経由で自社デバイスをプラットフォームに統合
- **管理者**: 全体のデバイス状況をモニタリング

## 2. 技術スタック

### 言語・フレームワーク
- **バックエンド**: Node.js 18.x, Express.js 4.x
- **フロントエンド**: React 18.x, TypeScript 5.x

### データベース
- **メインDB**: PostgreSQL 15.x（ユーザー・デバイス・ルール情報）
- **キャッシュ**: Redis 7.x（デバイスステータスのリアルタイムキャッシュ）
- **時系列DB**: InfluxDB 2.x（センサーデータの長期保存）

### インフラ・デプロイ環境
- **ホスティング**: AWS（ECS Fargate）
- **CI/CD**: GitHub Actions
- **監視**: Datadog

### 主要ライブラリ
- **HTTP通信**: node-fetch 3.x
- **認証**: jsonwebtoken 9.x
- **バリデーション**: joi 17.x
- **ORM**: Sequelize 6.x

## 3. アーキテクチャ設計

### 全体構成
3層アーキテクチャを採用。プレゼンテーション層（API Controller）、ビジネスロジック層（Service）、データアクセス層（Repository）で構成する。

### 主要コンポーネント

#### API Layer
- **DeviceController**: デバイス操作用エンドポイント
- **AutomationController**: 自動化ルール管理エンドポイント
- **UserController**: ユーザー管理エンドポイント

#### Service Layer
- **DeviceManagementService**: デバイス登録・削除・更新のビジネスロジック
- **CommandExecutionService**: デバイスへのコマンド送信・結果取得
- **AutomationRuleService**: ルールの評価・実行制御
- **NotificationService**: ユーザーへの通知送信

#### Data Access Layer
- **DeviceRepository**: デバイス情報のCRUD操作
- **UserRepository**: ユーザー情報の永続化
- **RuleRepository**: 自動化ルールの保存・検索

### データフロー
1. クライアント → API Gateway → Controller
2. Controller → Service（ビジネスロジック実行）
3. Service → Repository（データ永続化）
4. Repository → Database（クエリ実行）

依存方向: Controller → Service → Repository → Database

## 4. データモデル

### users テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| userId | UUID | PRIMARY KEY | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| passwordHash | VARCHAR(255) | NOT NULL | パスワードハッシュ |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

### Devices テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| device_id | UUID | PRIMARY KEY | デバイスID |
| user_id | UUID | FOREIGN KEY (users.userId) | 所有ユーザーID |
| DeviceName | VARCHAR(100) | NOT NULL | デバイス名 |
| device_type | VARCHAR(50) | NOT NULL | デバイス種別 |
| manufacturer | VARCHAR(100) | NOT NULL | メーカー名 |
| status | VARCHAR(20) | NOT NULL | ステータス（active/inactive） |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| last_updated | TIMESTAMP | NOT NULL | 最終更新日時 |

### automation_rule テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| rule_id | UUID | PRIMARY KEY | ルールID |
| user_id | UUID | FOREIGN KEY (users.userId) | 所有ユーザーID |
| RuleName | VARCHAR(100) | NOT NULL | ルール名 |
| condition | JSONB | NOT NULL | トリガー条件 |
| actions | JSONB | NOT NULL | 実行アクション |
| is_active | BOOLEAN | NOT NULL DEFAULT true | 有効フラグ |
| createdAt | TIMESTAMP | NOT NULL | 作成日時 |

## 5. API設計

### デバイス管理API

#### デバイス一覧取得
- **エンドポイント**: `GET /api/devices`
- **認証**: 必須（JWT Bearer Token）
- **レスポンス**:
```json
{
  "result": "success",
  "devices": [
    {
      "device_id": "...",
      "DeviceName": "...",
      "device_type": "...",
      "status": "..."
    }
  ],
  "message": "Devices retrieved successfully"
}
```

#### デバイス登録
- **エンドポイント**: `POST /api/devices`
- **認証**: 必須
- **リクエスト**:
```json
{
  "DeviceName": "Living Room Light",
  "device_type": "light",
  "manufacturer": "Philips"
}
```
- **レスポンス**:
```json
{
  "result": "success",
  "device": { "device_id": "...", "DeviceName": "...", ... },
  "message": "Device registered successfully"
}
```

#### デバイス制御
- **エンドポイント**: `POST /api/devices/{deviceId}/control`
- **認証**: 必須
- **リクエスト**:
```json
{
  "command": "turn_on",
  "parameters": { "brightness": 80 }
}
```

### 自動化ルールAPI

#### ルール作成
- **エンドポイント**: `POST /api/automation/rules`
- **認証**: 必須
- **リクエスト**:
```json
{
  "RuleName": "Evening Lighting",
  "condition": { "time": "18:00" },
  "actions": [ { "device_id": "...", "command": "turn_on" } ]
}
```

### 認証・認可方式
- **認証**: JWT（JSON Web Token）方式
- **トークン有効期限**: 24時間
- **トークン更新**: リフレッシュトークンを使用
- **認可**: ロールベースアクセス制御（RBAC）— ユーザー/管理者の2ロール

## 6. 実装方針

### エラーハンドリング方針
各Controllerメソッド内でtry-catchブロックを使用し、エラーを個別にキャッチする。エラー発生時は適切なHTTPステータスコードとエラーメッセージをクライアントに返す。

```javascript
async createDevice(req, res) {
  try {
    const device = await deviceService.register(req.body);
    res.status(201).json({ result: 'success', device });
  } catch (error) {
    res.status(500).json({ result: 'error', message: error.message });
  }
}
```

### ロギング方針
Winston 3.xを使用し、構造化ログをJSON形式で出力する。ログレベルはinfo/warn/error/debugの4段階とし、本番環境ではinfo以上を記録する。

ログ形式例:
```json
{
  "timestamp": "2026-02-11T10:30:00Z",
  "level": "info",
  "message": "Device registered",
  "deviceId": "abc-123",
  "userId": "user-456"
}
```

### テスト方針
- **単体テスト**: Jest 29.x を使用し、Service層のビジネスロジックをテスト
- **統合テスト**: SupertestでAPI層のエンドポイントテスト
- **カバレッジ目標**: 80%以上

### デプロイメント方針
- **デプロイ単位**: Dockerコンテナ
- **デプロイ頻度**: 週次（毎週金曜日）
- **ロールバック戦略**: 前バージョンのコンテナイメージを保持し、問題発生時は即座にロールバック
- **環境変数管理**: AWS Systems Manager Parameter Storeで管理

## 7. 非機能要件

### パフォーマンス目標
- **API応答時間**: 95パーセンタイルで500ms以下
- **デバイス制御遅延**: コマンド送信から実行完了まで2秒以内
- **同時接続数**: 10,000ユーザーまでサポート

### セキュリティ要件
- **通信**: 全てHTTPS（TLS 1.3）で暗号化
- **認証**: パスワードはbcryptでハッシュ化（ソルトラウンド10）
- **トークン保存**: JWTはlocalStorageに保存
- **APIレート制限**: ユーザーあたり100リクエスト/分

### 可用性・スケーラビリティ
- **目標稼働率**: 99.9%（月間ダウンタイム43分以内）
- **スケーリング**: ECS Fargateの自動スケーリング機能を使用（CPU使用率70%でスケールアウト）
- **データバックアップ**: 毎日深夜2時にPostgreSQLの自動バックアップを実行
