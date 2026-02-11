# リアルタイム配信プラットフォーム システム設計書

## 1. 概要

### プロジェクトの目的と背景
動画クリエイターが視聴者とリアルタイムで交流できるライブ配信プラットフォームを構築する。既存のコンテンツ配信システムに追加する形で、リアルタイム配信機能とチャット機能を実装する。

### 主要機能
- ライブ配信の開始・終了・管理
- リアルタイムチャット機能
- 配信通知機能
- 視聴者数のリアルタイム集計
- 配信アーカイブの自動保存

### 対象ユーザーと利用シナリオ
- **配信者**: ライブ配信を開始し、視聴者とチャットでコミュニケーションを取る
- **視聴者**: ライブ配信を視聴し、チャットで質問やコメントを送信する
- **管理者**: 不適切な配信やチャットを監視・制御する

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Java 17, Spring Boot 3.2
- フロントエンド: TypeScript 5.0, React 18
- リアルタイム通信: WebSocket

### データベース
- メインDB: PostgreSQL 15（配信メタデータ、ユーザー情報）
- キャッシュ: Redis 7（視聴者数集計、セッション管理）
- メッセージキュー: RabbitMQ 3.12（配信イベント処理）

### インフラ・デプロイ環境
- コンテナ: Docker
- オーケストレーション: Kubernetes
- CDN: CloudFront（配信映像の配信）
- ストリーミング: AWS MediaLive + MediaPackage

### 主要ライブラリ
- WebSocket: Spring WebSocket
- HTTP通信: Spring WebClient
- バリデーション: Jakarta Validation
- データマッピング: MapStruct

## 3. アーキテクチャ設計

### 全体構成
既存システムのレイヤー構成に従い、以下の3層で構成する:
- Presentation層: REST Controller, WebSocket Handler
- Business層: Service, Domain Model
- Data Access層: Repository, Entity

### 主要コンポーネントの責務
#### Presentation層
- `LiveStreamController`: ライブ配信のREST APIエンドポイント
- `ChatWebSocketHandler`: WebSocketによるチャット通信の管理

#### Business層
- `LiveStreamService`: 配信開始・終了のビジネスロジック
- `ChatService`: チャットメッセージのフィルタリング・配信
- `NotificationService`: 配信通知の送信
- `ViewerCountService`: 視聴者数の集計

#### Data Access層
- `LiveStreamRepository`: 配信情報のCRUD操作
- `ChatMessageRepository`: チャットメッセージの保存
- `ViewerSessionRepository`: 視聴者セッションの管理

### データフロー
1. 配信者が配信開始リクエストを送信 → `LiveStreamController`
2. `LiveStreamService` が配信メタデータをDBに保存、ストリーミングサービスを初期化
3. 配信開始イベントを RabbitMQ に publish
4. `NotificationService` がイベントを consume し、フォロワーに通知送信
5. 視聴者が WebSocket 接続でチャットに参加
6. `ChatWebSocketHandler` がメッセージを受信、`ChatService` でフィルタリング後ブロードキャスト

## 4. データモデル

### live_stream テーブル
```sql
CREATE TABLE live_stream (
    stream_id BIGSERIAL PRIMARY KEY,
    streamer_user_id BIGINT NOT NULL,
    stream_title VARCHAR(200) NOT NULL,
    stream_status VARCHAR(20) NOT NULL,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    viewer_peak INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### chat_message テーブル
```sql
CREATE TABLE ChatMessage (
    messageId BIGSERIAL PRIMARY KEY,
    streamId BIGINT NOT NULL,
    userId BIGINT NOT NULL,
    messageText TEXT NOT NULL,
    sentAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    isDeleted BOOLEAN DEFAULT FALSE
);
```

### viewer_session テーブル
```sql
CREATE TABLE viewer_sessions (
    session_id UUID PRIMARY KEY,
    stream_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    connected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    disconnected_at TIMESTAMP
);
```

## 5. API設計

### エンドポイント一覧

#### 配信管理API
```
POST /api/v1/streams
GET /api/v1/streams/{streamId}
PATCH /api/v1/streams/{streamId}/status
DELETE /api/v1/streams/{streamId}
GET /api/v1/streams/active
```

#### チャット履歴API
```
GET /api/v1/streams/{streamId}/chat-messages
```

### リクエスト/レスポンス形式

#### 配信開始
```
POST /api/v1/streams
Request:
{
  "title": "今日のライブ配信",
  "streamerId": 12345
}

Response:
{
  "success": true,
  "stream": {
    "streamId": 98765,
    "title": "今日のライブ配信",
    "streamerId": 12345,
    "status": "ACTIVE",
    "startedAt": "2026-02-11T10:00:00Z"
  }
}
```

#### エラーレスポンス
```
{
  "success": false,
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Invalid stream title"
  }
}
```

### 認証・認可方式
既存のJWT認証を使用する。配信開始・終了には配信者ロール、チャット送信には一般ユーザーロールが必要。

## 6. 実装方針

### エラーハンドリング方針
業務例外が発生した場合は、各Service層で `BusinessException` をスローし、Controller層の個別 catch ブロックで処理する。技術的例外（DB接続エラー等）はログ出力後、汎用エラーレスポンスを返却する。

### ロギング方針
以下の形式でログを出力:
```
[LEVEL] [YYYY-MM-DD HH:MM:SS] [ClassName.methodName] - Log message (key1=value1, key2=value2)
```

### テスト方針
- 単体テスト: JUnit 5 + Mockito でService層をテスト
- 統合テスト: TestContainers で DB, Redis を起動してテスト
- E2Eテスト: Playwright でフロントエンドから配信開始→チャット送信→配信終了のシナリオテスト

### デプロイメント方針
- 開発環境: Docker Compose でローカル起動
- 本番環境: Kubernetes にデプロイ、Blue-Green デプロイメントで段階リリース

## 7. 非機能要件

### パフォーマンス目標
- 配信開始APIのレスポンスタイム: 200ms以内
- チャットメッセージの配信遅延: 100ms以内
- 同時視聴者数: 最大10,000人/配信

### セキュリティ要件
- 配信URLにランダムトークンを含め、未認可アクセスを防止
- チャットメッセージにXSSフィルターを適用
- レート制限: チャット送信は1ユーザーあたり3秒に1回まで

### 可用性・スケーラビリティ
- 可用性目標: 99.9%
- 水平スケーリング: Kubernetes HPAで視聴者数に応じてPod数を自動調整
- データベース: Read Replica を使用して読み取り負荷を分散
