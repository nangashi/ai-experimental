# RealTimeChat システム設計書

## 1. 概要

### プロジェクトの目的と背景
RealTimeChat は企業向けリアルタイムメッセージングプラットフォームである。Slack に類似した機能を提供し、チーム内のコミュニケーションを円滑にすることを目的とする。2026年Q2にベータ版をリリースし、500社・5万ユーザーを対象に展開する予定。

### 主要機能の一覧
- チャンネル/ダイレクトメッセージ
- リアルタイムメッセージ配信
- ファイル共有（画像・動画・ドキュメント）
- リアクション・スレッド機能
- 全文検索
- ユーザー・チーム管理
- 通知（プッシュ通知、メール通知）

### 対象ユーザーと利用シナリオ
- 主対象: 50-500名規模の企業チーム
- 主要ユースケース: 日常的なチーム内コミュニケーション、プロジェクト単位の情報共有、リモートワーク時のリアルタイム連携

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Go 1.22、Echo v4
- フロントエンド: React 18、TypeScript 5.2
- WebSocket: gorilla/websocket

### データベース
- PostgreSQL 16（メタデータ、ユーザー情報）
- MongoDB 7.0（メッセージ履歴）
- Redis 7.2（セッション、キャッシュ、Pub/Sub）

### インフラ・デプロイ環境
- AWS ECS Fargate
- Application Load Balancer
- RDS（PostgreSQL）、DocumentDB（MongoDB互換）、ElastiCache（Redis）
- S3（ファイルストレージ）
- CloudFront（CDN）

### 主要ライブラリ
- JWT認証: golang-jwt/jwt
- バリデーション: go-playground/validator
- データベース: gorm、mongo-driver
- テスト: testify

## 3. アーキテクチャ設計

### 全体構成
```
[Client (Web/Mobile)]
       ↓
[CloudFront] → [ALB] → [API Gateway Service]
                           ↓
           ┌───────────────┼───────────────┐
           ↓               ↓               ↓
    [Auth Service]  [Message Service]  [Notification Service]
           ↓               ↓               ↓
    [PostgreSQL]      [MongoDB]        [Redis Pub/Sub]
                           ↓
                      [S3 (Files)]
```

### 主要コンポーネントの責務と依存関係

#### API Gateway Service
- クライアントからのHTTP/WebSocketリクエストを受け付け、適切なサービスにルーティング
- 認証トークンの検証
- レート制限（ユーザーあたり 1000 req/min）

#### Auth Service
- ユーザー認証・認可
- JWT トークン発行
- セッション管理（Redis）

#### Message Service
- メッセージの送受信処理
- メッセージ履歴の保存・取得
- WebSocket接続管理
- チャンネル・スレッド管理

#### Notification Service
- プッシュ通知・メール通知の送信
- 通知設定の管理
- 外部サービス（FCM、SendGrid）との連携

### データフロー

#### メッセージ送信フロー
1. クライアントがWebSocket経由でメッセージ送信リクエストを送信
2. API Gateway が JWT トークンを検証
3. Message Service がメッセージを MongoDB に保存
4. Message Service が Redis Pub/Sub にメッセージをパブリッシュ
5. 同一チャンネルの全接続クライアントに WebSocket でメッセージを配信
6. Notification Service がオフラインユーザーに通知を送信

## 4. データモデル

### PostgreSQL スキーマ

#### users テーブル
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### teams テーブル
```sql
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    owner_id UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### channels テーブル
```sql
CREATE TABLE channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES teams(id),
    name VARCHAR(255) NOT NULL,
    is_private BOOLEAN DEFAULT false,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### MongoDB コレクション

#### messages コレクション
```javascript
{
    _id: ObjectId,
    channel_id: String,
    user_id: String,
    content: String,
    thread_id: String,  // null if not in thread
    attachments: [
        {
            file_id: String,
            file_name: String,
            file_type: String,
            url: String
        }
    ],
    reactions: [
        {
            emoji: String,
            user_ids: [String]
        }
    ],
    created_at: ISODate,
    updated_at: ISODate
}
```

## 5. API設計

### エンドポイント一覧

#### 認証関連
- `POST /api/v1/auth/login` - ログイン
- `POST /api/v1/auth/refresh` - トークンリフレッシュ
- `POST /api/v1/auth/logout` - ログアウト

#### メッセージ関連
- `GET /api/v1/channels/{channel_id}/messages` - メッセージ履歴取得
- `POST /api/v1/messages` - メッセージ送信
- `PUT /api/v1/messages/{message_id}` - メッセージ編集
- `DELETE /api/v1/messages/{message_id}` - メッセージ削除

#### WebSocket
- `WS /api/v1/ws` - リアルタイムメッセージストリーム

### リクエスト/レスポンス形式

#### POST /api/v1/messages
```json
// Request
{
    "channel_id": "ch_12345",
    "content": "Hello, team!",
    "thread_id": null
}

// Response
{
    "message_id": "msg_67890",
    "channel_id": "ch_12345",
    "user_id": "user_123",
    "content": "Hello, team!",
    "created_at": "2026-02-11T10:30:00Z"
}
```

### 認証・認可方式
- JWT ベースの認証（アクセストークン: 1時間、リフレッシュトークン: 7日間）
- アクセストークンは localStorage に保存
- リフレッシュトークンは httpOnly Cookie に保存
- API Gateway でトークン検証を実施

## 6. 実装方針

### エラーハンドリング方針
- HTTP ステータスコードに応じたエラーレスポンス
- 内部エラーは詳細をログに記録し、クライアントには汎用エラーメッセージを返す
- バリデーションエラーは400 Bad Request、認証エラーは401 Unauthorized

### ロギング方針
- 構造化ログ（JSON形式）
- ログレベル: DEBUG, INFO, WARN, ERROR
- CloudWatch Logs に集約
- リクエストID を全ログに付与して追跡可能にする

### テスト方針
- ユニットテスト: カバレッジ 80% 以上
- 統合テスト: 主要エンドポイントの正常・異常系
- E2Eテスト: クリティカルパスのシナリオテスト
- 負荷テスト: JMeter で 10,000同時接続をシミュレート

### デプロイメント方針
- ECS タスク定義の Blue/Green デプロイ
- デプロイ時はヘルスチェックで新バージョンの起動を確認後、旧バージョンを停止

## 7. 非機能要件

### パフォーマンス目標
- メッセージ送信から配信まで平均 200ms 以内
- API レスポンスタイム p95 で 500ms 以内
- WebSocket 接続数: 最大 50,000 同時接続をサポート

### セキュリティ要件
- 通信は全て HTTPS/WSS
- パスワードは bcrypt でハッシュ化（cost factor 12）
- CORS 設定: 許可されたオリジンのみ
- OWASP Top 10 への対策を実施

### 可用性・スケーラビリティ
- 目標稼働率: 99.5%（月間ダウンタイム 3.6時間以内）
- ECS タスクの Auto Scaling: CPU使用率 70% で水平スケール
- RDS: Multi-AZ 構成で自動フェイルオーバー
- ElastiCache: クラスタモードで複数ノード構成
- データベースバックアップ: 日次フルバックアップ（保持期間30日）
- 災害復旧: 別リージョンへのデータベーススナップショット同期（日次）、目標復旧時間（RTO）は12時間、目標復旧時点（RPO）は24時間とする
