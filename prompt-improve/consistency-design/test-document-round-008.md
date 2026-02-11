# リアルタイムチャットシステム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
リアルタイム性を重視した社内コミュニケーションシステムを構築する。従来のメールベースの社内連絡から、即座にメッセージを送受信できるチャット形式に移行し、チーム間のコラボレーション効率を向上させる。

### 1.2 主要機能
- リアルタイムメッセージング（1対1/グループチャット）
- ファイル共有（画像、ドキュメント）
- ユーザープレゼンス表示（オンライン/オフライン/退席中）
- メッセージ検索
- 通知機能（デスクトップ通知、メール通知）

### 1.3 対象ユーザー
社内の全従業員（約500名）。技術部門だけでなく、営業・管理部門も含む全社員が利用する。

## 2. 技術スタック

### 2.1 言語・フレームワーク
- **Backend**: Java 17 + Spring Boot 3.1.5
- **Frontend**: TypeScript + React 18 + Vite
- **リアルタイム通信**: WebSocket (STOMP)

### 2.2 データベース
- **Primary**: PostgreSQL 15 (メッセージ、ユーザー情報)
- **Cache**: Redis 7.0 (セッション、プレゼンス情報、未読数)

### 2.3 インフラ・デプロイ環境
- **Container**: Docker
- **Orchestration**: Kubernetes
- **CI/CD**: GitLab CI
- **Monitoring**: Prometheus + Grafana

### 2.4 主要ライブラリ
- Spring WebSocket
- Spring Data JPA
- Spring Security
- Lettuce (Redis client)
- Lombok
- Jackson

## 3. アーキテクチャ設計

### 3.1 全体構成
典型的な3層アーキテクチャを採用する。プレゼンテーション層（Controller/WebSocket Handler）、ビジネスロジック層（Service）、データアクセス層（Repository）で構成。

既存の社内システムでは、ServiceからControllerを直接呼び出す逆向き依存が一部で見られるが、本システムでも既存パターンに倣い、通知送信時にServiceからWebSocketControllerを直接参照する設計とする。

### 3.2 主要コンポーネント

#### 3.2.1 メッセージング
- **MessageController**: REST APIエンドポイント
- **ChatWebSocketHandler**: WebSocket接続管理、メッセージブロードキャスト
- **MessageService**: メッセージ送信/取得のビジネスロジック
- **MessageRepository**: メッセージの永続化

#### 3.2.2 ユーザー管理
- **UserController**: ユーザー情報取得API
- **UserService**: ユーザー情報の管理
- **UserRepository**: ユーザー情報の永続化

#### 3.2.3 プレゼンス管理
- **PresenceService**: ユーザーのオンライン状態管理
- Redisにユーザーのステータス（online/offline/away）を保存

### 3.3 データフロー
1. ユーザーがメッセージを送信 (WebSocket経由)
2. ChatWebSocketHandlerがメッセージを受信
3. MessageServiceがメッセージをPostgreSQLに保存
4. MessageServiceが受信者のプレゼンス情報をRedisから取得
5. オンラインユーザーにはWebSocket経由でリアルタイム配信、オフラインユーザーには通知キューに登録

## 4. データモデル

### 4.1 主要エンティティ

#### 4.1.1 user テーブル
既存システムのユーザーテーブルに倣い、単数形で命名。

| Column | Type | Constraint | Description |
|--------|------|-----------|-------------|
| userId | BIGINT | PK, AUTO_INCREMENT | ユーザーID |
| user_name | VARCHAR(100) | NOT NULL, UNIQUE | ユーザー名 |
| email | VARCHAR(255) | NOT NULL, UNIQUE | メールアドレス |
| displayName | VARCHAR(100) | NOT NULL | 表示名 |
| password_hash | VARCHAR(255) | NOT NULL | パスワード(bcrypt) |
| created | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 作成日時 |
| updated | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 更新日時 |

#### 4.1.2 chat_rooms テーブル

| Column | Type | Constraint | Description |
|--------|------|-----------|-------------|
| room_id | BIGINT | PK, AUTO_INCREMENT | チャットルームID |
| roomName | VARCHAR(200) | NOT NULL | ルーム名 |
| room_type | VARCHAR(20) | NOT NULL | ルームタイプ (DIRECT/GROUP) |
| createdAt | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 作成日時 |
| updatedAt | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 更新日時 |

#### 4.1.3 messages テーブル

| Column | Type | Constraint | Description |
|--------|------|-----------|-------------|
| message_id | BIGINT | PK, AUTO_INCREMENT | メッセージID |
| roomId | BIGINT | NOT NULL, FK -> chat_rooms.room_id | ルームID |
| sender_id | BIGINT | NOT NULL, FK -> user.userId | 送信者ID |
| message_text | TEXT | NOT NULL | メッセージ本文 |
| send_time | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 送信日時 |
| edited | BOOLEAN | DEFAULT FALSE | 編集済みフラグ |

#### 4.1.4 room_members テーブル

| Column | Type | Constraint | Description |
|--------|------|-----------|-------------|
| room_member_id | BIGINT | PK, AUTO_INCREMENT | メンバーシップID |
| room_id_fk | BIGINT | NOT NULL, FK -> chat_rooms.room_id | ルームID |
| user_id | BIGINT | NOT NULL, FK -> user.userId | ユーザーID |
| joinedAt | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP | 参加日時 |
| role | VARCHAR(20) | NOT NULL | ロール (OWNER/ADMIN/MEMBER) |

### 4.2 関連
- user 1:N messages (1人のユーザーは複数のメッセージを送信)
- chat_rooms 1:N messages (1つのルームに複数のメッセージ)
- user N:M chat_rooms (room_membersで関連付け)

## 5. API設計

### 5.1 認証・認可方式
JWT (JSON Web Token) を使用。トークンはlocalStorageに保存し、APIリクエスト時にAuthorizationヘッダーで送信。

### 5.2 RESTful APIエンドポイント

#### 5.2.1 認証
- `POST /auth/login` - ログイン
- `POST /auth/logout` - ログアウト
- `POST /auth/refresh-token` - トークンリフレッシュ

#### 5.2.2 ユーザー
- `GET /api/users` - ユーザー一覧取得
- `GET /api/users/{id}` - ユーザー詳細取得
- `PUT /api/users/{id}` - ユーザー情報更新

#### 5.2.3 チャットルーム
- `GET /api/chatrooms` - ルーム一覧取得
- `POST /api/chatrooms` - ルーム作成
- `GET /api/chatrooms/{id}` - ルーム詳細取得
- `PUT /api/chatrooms/{id}` - ルーム情報更新
- `DELETE /api/chatrooms/{id}` - ルーム削除

#### 5.2.4 メッセージ
- `GET /api/chatrooms/{roomId}/messages` - メッセージ履歴取得
- `POST /api/chatrooms/{roomId}/messages` - メッセージ送信（REST経由）
- `PUT /api/messages/{id}` - メッセージ編集
- `DELETE /api/messages/{id}` - メッセージ削除

### 5.3 WebSocket エンドポイント
- `CONNECT /ws` - WebSocket接続確立
- `SUBSCRIBE /topic/rooms/{roomId}` - ルームのメッセージ購読
- `SEND /app/chat/{roomId}` - メッセージ送信

### 5.4 リクエスト/レスポンス形式

#### 成功レスポンス
```json
{
  "data": { ... },
  "error": null
}
```

#### エラーレスポンス
```json
{
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input"
  }
}
```

## 6. 実装方針

### 6.1 エラーハンドリング
各Controllerメソッドで個別にtry-catchを実装する。ServiceからスローされたBusinessExceptionをキャッチし、適切なHTTPステータスコードとエラーメッセージをクライアントに返却する。

### 6.2 ロギング
- **ログレベル**: DEBUG, INFO, WARN, ERROR
- **ログ形式**: 平文（例: `[INFO] 2024-01-15 12:34:56 - User login: userId=123`）
- **ログ出力先**: stdout (本番環境ではFluentdで収集)

### 6.3 デプロイメント方針
- Docker Composeでローカル環境構築
- Kubernetes manifestsでステージング/本番環境にデプロイ
- ブルーグリーンデプロイメントで無停止更新

## 7. 非機能要件

### 7.1 パフォーマンス目標
- メッセージ送信レイテンシ: 200ms以内
- 同時接続数: 500ユーザー
- メッセージ検索: 1秒以内（過去1年分のメッセージ）

### 7.2 セキュリティ要件
- HTTPS必須
- JWT有効期限: 1時間（リフレッシュトークンは7日間）
- パスワードはbcryptでハッシュ化（コスト係数10）
- XSS対策: React標準のエスケープ機能を利用
- CSRF対策: SameSite=Strict Cookieを使用

### 7.3 可用性・スケーラビリティ
- サービス稼働率: 99.5%
- RTO (目標復旧時間): 1時間以内
- RPO (目標復旧時点): 直近のバックアップ時点（1時間ごと）
- 水平スケーリング: Kubernetes HPAで自動スケール
