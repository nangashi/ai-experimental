# LiveStream Pro システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
LiveStream Proは、中小規模のコンテンツクリエイター向けのリアルタイム動画配信プラットフォームである。既存の大規模プラットフォーム（YouTube Live、Twitchなど）に対して、よりシンプルで低コストな配信環境を提供することを目指す。

### 1.2 主要機能
- ライブ配信の開始・停止・管理
- 視聴者数の確認とチャット機能
- 配信のアーカイブと録画管理
- 視聴者との投げ銭機能（決済連携）
- 配信スケジュールの管理と通知
- 配信品質の自動調整

### 1.3 対象ユーザーと利用シナリオ
- **配信者**: 個人クリエイター、小規模企業、教育機関など
- **視聴者**: 配信を視聴し、チャットや投げ銭でクリエイターを支援するユーザー
- **想定規模**: 同時配信数500、同時視聴者数50,000、月間アクティブユーザー100,000

## 2. 技術スタック

### 2.1 言語・フレームワーク
- **バックエンド**: Go 1.22（Gin framework）
- **フロントエンド**: React 18 + TypeScript + Next.js 14
- **リアルタイム通信**: WebSocket（gorilla/websocket）

### 2.2 データベース
- **メインDB**: PostgreSQL 15（ユーザー情報、配信メタデータ、決済情報）
- **セッション管理**: Redis 7.0（セッション、配信状態、チャット一時保存）

### 2.3 インフラ・デプロイ環境
- **クラウド**: AWS（ECS on Fargate）
- **ストレージ**: S3（アーカイブ動画）
- **CDN**: CloudFront
- **メディアサーバー**: Ant Media Server（WebRTC配信）

### 2.4 主要ライブラリ
- **認証**: JWT（golang-jwt/jwt）
- **決済**: Stripe API
- **動画処理**: FFmpeg（録画・トランスコード）

## 3. アーキテクチャ設計

### 3.1 全体構成
システムは以下のレイヤーで構成される:
- **プレゼンテーション層**: Next.jsフロントエンド、WebSocketゲートウェイ
- **アプリケーション層**: Goバックエンドサービス（API、配信管理、決済処理）
- **データ層**: PostgreSQL、Redis、S3

### 3.2 主要コンポーネント
- **API Gateway**: フロントエンドからの全HTTPリクエストを受け付ける単一エントリーポイント
- **Stream Manager**: 配信の開始・停止、視聴者数管理を担当
- **Chat Service**: WebSocketを介してチャットメッセージを配信
- **Archive Service**: 配信終了後の録画ファイル処理とS3保存
- **Payment Service**: Stripe APIを呼び出して投げ銭処理を実行
- **Notification Service**: 配信開始通知をユーザーに送信

### 3.3 データフロー

#### 配信開始フロー
1. 配信者がAPI Gatewayに配信開始リクエストを送信
2. Stream Managerが配信セッションを作成し、Ant Media Serverに配信URLを生成
3. 配信メタデータ（配信ID、タイトル、配信者ID）をPostgreSQLに保存
4. Redisに配信状態（配信中、視聴者数0）を記録
5. Notification Serviceがフォロワー全員に通知を送信

#### 視聴者参加フロー
1. 視聴者がフロントエンドから配信ページにアクセス
2. API Gatewayがユーザー情報を取得し、配信メタデータを返却
3. フロントエンドがWebSocketを確立し、Chat Serviceに接続
4. 視聴者数カウントをRedisでインクリメント
5. Ant Media Serverから配信ストリームを取得

#### チャット送信フロー
1. 視聴者がチャットメッセージを送信
2. Chat ServiceがWebSocket経由でメッセージを受信
3. メッセージをRedisに一時保存（5分間のTTL）
4. 同じ配信を視聴中の全視聴者にメッセージをブロードキャスト

## 4. データモデル

### 4.1 主要エンティティ
- **User**: ユーザー（配信者・視聴者共通）
- **Stream**: 配信セッション
- **Archive**: アーカイブ動画
- **Transaction**: 投げ銭取引
- **Notification**: 通知
- **Follow**: フォロー関係

### 4.2 テーブル設計

#### users テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| user_id | UUID | PRIMARY KEY | ユーザーID |
| username | VARCHAR(50) | UNIQUE, NOT NULL | ユーザー名 |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| password_hash | VARCHAR(255) | NOT NULL | ハッシュ化パスワード |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

#### streams テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| stream_id | UUID | PRIMARY KEY | 配信ID |
| user_id | UUID | FOREIGN KEY(users.user_id) | 配信者ID |
| title | VARCHAR(255) | NOT NULL | 配信タイトル |
| status | VARCHAR(20) | NOT NULL | 配信状態（live/ended） |
| started_at | TIMESTAMP | NOT NULL | 配信開始日時 |
| ended_at | TIMESTAMP | NULL | 配信終了日時 |
| viewer_count | INTEGER | DEFAULT 0 | 視聴者数 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### archives テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| archive_id | UUID | PRIMARY KEY | アーカイブID |
| stream_id | UUID | FOREIGN KEY(streams.stream_id) | 配信ID |
| s3_key | VARCHAR(500) | NOT NULL | S3オブジェクトキー |
| duration | INTEGER | NOT NULL | 動画時間（秒） |
| file_size | BIGINT | NOT NULL | ファイルサイズ（バイト） |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### follows テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| follow_id | UUID | PRIMARY KEY | フォローID |
| follower_id | UUID | FOREIGN KEY(users.user_id) | フォロワー |
| following_id | UUID | FOREIGN KEY(users.user_id) | フォロー対象 |
| created_at | TIMESTAMP | NOT NULL | フォロー日時 |

## 5. API設計

### 5.1 エンドポイント一覧

#### 認証・ユーザー管理
- `POST /api/auth/register`: ユーザー登録
- `POST /api/auth/login`: ログイン（JWT発行）
- `GET /api/users/{user_id}`: ユーザー情報取得
- `PUT /api/users/{user_id}`: ユーザー情報更新

#### 配信管理
- `POST /api/streams`: 配信開始
- `PUT /api/streams/{stream_id}/end`: 配信終了
- `GET /api/streams/{stream_id}`: 配信情報取得
- `GET /api/streams`: 配信一覧取得（進行中・過去配信）

#### アーカイブ
- `GET /api/archives/{archive_id}`: アーカイブ動画情報取得
- `GET /api/archives`: アーカイブ一覧取得（ユーザー指定）

#### フォロー
- `POST /api/follows`: フォロー追加
- `DELETE /api/follows/{follow_id}`: フォロー解除
- `GET /api/users/{user_id}/followers`: フォロワー一覧取得
- `GET /api/users/{user_id}/following`: フォロー中一覧取得

#### 投げ銭
- `POST /api/transactions`: 投げ銭実行

### 5.2 リクエスト/レスポンス形式
- **リクエスト**: JSON形式
- **レスポンス**: JSON形式、標準的なHTTPステータスコード使用

### 5.3 認証・認可方式
- **認証**: JWT（アクセストークン有効期限24時間）
- **認可**: ユーザーIDベースのリソース所有権確認
- **トークン保存**: ブラウザのlocalStorage

## 6. 実装方針

### 6.1 エラーハンドリング方針
- **HTTPエラー**: 標準的なステータスコード（400/401/403/404/500）を使用
- **エラーレスポンス形式**: `{"error": "エラーメッセージ", "code": "ERROR_CODE"}`
- **ログ出力**: 全エラーをCloudWatch Logsに記録

### 6.2 ロギング方針
- **ログレベル**: INFO（通常処理）、WARN（警告）、ERROR（エラー）
- **ログ出力先**: CloudWatch Logs
- **構造化ログ**: JSON形式で出力（タイムスタンプ、リクエストID、ユーザーID、メッセージ）

### 6.3 テスト方針
- **単体テスト**: Go標準テストフレームワーク使用、カバレッジ80%以上
- **統合テスト**: APIエンドポイントのE2Eテスト（Postman Collection）
- **負荷テスト**: 未実施（今後検討）

### 6.4 デプロイメント方針
- **CI/CD**: GitHub Actions（テスト→ビルド→ECRプッシュ→ECSデプロイ）
- **デプロイ環境**: 開発環境、本番環境の2環境
- **ロールバック**: ECSタスク定義の前バージョンに切り戻し

## 7. 非機能要件

### 7.1 セキュリティ要件
- **認証**: JWT使用
- **通信暗号化**: HTTPS必須
- **データ暗号化**: PostgreSQLの機密データ（パスワードハッシュ）はbcrypt使用
- **決済情報**: Stripe APIに委譲（PCI DSS準拠）

### 7.2 可用性・スケーラビリティ
- **可用性**: ECS Fargateで複数タスク起動（最小2タスク）
- **スケーリング**: ECSのCPU/メモリ使用率ベースで自動スケーリング
- **データベース**: RDS Multi-AZ構成

### 7.3 データ保持ポリシー
- **配信メタデータ**: 無期限保持
- **アーカイブ動画**: S3 Standard（90日後にS3 Glacierに移行）
- **チャットログ**: Redisに5分間保持後削除（永続化不要）
