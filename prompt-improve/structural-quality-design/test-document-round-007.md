# E-Learning Content Delivery Platform システム設計書

## 1. 概要

### プロジェクトの目的と背景
大学・企業向けのオンライン学習プラットフォームを構築する。動画コンテンツのストリーミング配信、進捗管理、課題提出、ディスカッション機能を提供し、学習者と教育者をつなぐ。既存のLMS（Learning Management System）との統合も想定する。

### 主要機能
- コース管理（作成、公開、アーカイブ）
- 動画コンテンツのストリーミング配信（HLS/DASH）
- 進捗トラッキング（視聴履歴、完了状態）
- 課題管理（提出、採点、フィードバック）
- ディスカッションフォーラム
- 証明書発行

### 対象ユーザー
- **学習者**: コース受講、課題提出、進捗確認
- **教育者**: コース作成、課題管理、学習者の進捗確認
- **管理者**: ユーザー管理、システム設定、レポート生成

## 2. 技術スタック

- **言語・フレームワーク**: Java 17, Spring Boot 3.1, Spring Security
- **データベース**: PostgreSQL 15（メタデータ、ユーザー情報）、MongoDB（ログ、学習履歴）
- **キャッシュ**: Redis（セッション、APIレスポンス）
- **ストレージ**: AWS S3（動画、ドキュメント）、CloudFront（CDN）
- **メッセージング**: RabbitMQ（非同期処理）
- **検索**: Elasticsearch（コース検索、フルテキスト検索）
- **インフラ**: AWS ECS（コンテナ）、RDS、ElastiCache
- **主要ライブラリ**: Spring Data JPA, FFmpeg（動画処理）、JWT

## 3. アーキテクチャ設計

### 全体構成
```
[Frontend] --> [API Gateway] --> [Backend Services]
                                     |
                      +-------------+-------------+
                      |             |             |
                [Course Service] [User Service] [Video Service]
                      |             |             |
               [PostgreSQL]    [Redis]      [S3 + CloudFront]
```

### 主要コンポーネント

#### CourseService
- コース管理、課題管理、進捗トラッキング、証明書発行を統合したサービス
- REST API提供
- PostgreSQL、MongoDB、Redisに直接アクセス

#### UserService
- ユーザー認証・認可、プロフィール管理
- JWT発行、ロール管理（学習者、教育者、管理者）

#### VideoService
- 動画アップロード、エンコーディング、ストリーミングURL生成
- S3へのアップロード、CloudFrontへのキャッシュ設定

### データフロー
1. ユーザーがCourseService APIを呼び出し
2. CourseServiceがUserServiceに認証リクエストを送信
3. CourseServiceがデータベースに直接クエリを実行
4. 結果をクライアントに返却

## 4. データモデル

### PostgreSQL スキーマ

#### courses テーブル
```sql
CREATE TABLE courses (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    instructor_id BIGINT NOT NULL,
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### course_enrollments テーブル
```sql
CREATE TABLE course_enrollments (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    progress INT DEFAULT 0
);
```

#### assignments テーブル
```sql
CREATE TABLE assignments (
    id BIGSERIAL PRIMARY KEY,
    course_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    due_date TIMESTAMP,
    max_score INT
);
```

#### assignment_submissions テーブル
```sql
CREATE TABLE assignment_submissions (
    id BIGSERIAL PRIMARY KEY,
    assignment_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    score INT,
    feedback TEXT
);
```

#### users テーブル
```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### MongoDB コレクション

#### learning_progress
```json
{
    "user_id": "12345",
    "course_id": "67890",
    "video_id": "abc123",
    "watched_seconds": 1200,
    "total_seconds": 1800,
    "last_position": 1200,
    "completed": false,
    "timestamp": "2024-01-15T10:30:00Z"
}
```

#### activity_logs
```json
{
    "user_id": "12345",
    "action": "VIDEO_WATCHED",
    "resource_id": "abc123",
    "timestamp": "2024-01-15T10:30:00Z",
    "metadata": {
        "duration": 1200,
        "completion_rate": 0.67
    }
}
```

## 5. API設計

### エンドポイント一覧

#### Course API
- `POST /courses` - コース新規作成
- `GET /courses/{id}` - コース詳細取得
- `PUT /courses/{id}` - コース更新
- `POST /courses/{id}/enroll` - コース登録
- `GET /courses/{id}/progress` - 進捗取得
- `POST /courses/{id}/complete` - コース完了

#### Assignment API
- `POST /courses/{courseId}/assignments` - 課題作成
- `GET /assignments/{id}` - 課題詳細取得
- `POST /assignments/{id}/submit` - 課題提出
- `POST /assignments/{id}/grade` - 採点

#### Video API
- `POST /videos/upload` - 動画アップロード
- `GET /videos/{id}` - 動画情報取得
- `GET /videos/{id}/stream` - ストリーミングURL取得

### リクエスト/レスポンス形式
すべてのエンドポイントはJSON形式で通信。エラーレスポンスは以下の形式:
```json
{
    "error": "ERROR_CODE",
    "message": "Human-readable error message"
}
```

### 認証・認可方式
- JWT（JSON Web Token）ベースの認証
- トークンはローカルストレージに保存
- リフレッシュトークンは未実装（短期トークンのみ）
- ロールベースのアクセス制御（RBAC）

## 6. 実装方針

### エラーハンドリング方針
- Controllerレイヤーで例外をキャッチし、適切なHTTPステータスコードを返却
- 例外の種類ごとに異なるメッセージを返す（詳細な分類体系は未定義）

### ロギング方針
- Spring Bootの標準ロギングフレームワーク（Logback）を使用
- ログレベルはINFO（本番環境）、DEBUG（開発環境）

### テスト方針
- 統合テストで全体動作を確認
- DBを含むフルスタックテストを実施
- モックは使用せず、実際のDBに接続してテスト

### デプロイメント方針
- ECSにDockerコンテナをデプロイ
- Blue-Greenデプロイメントを採用
- 環境変数で設定を管理（開発環境と本番環境の差分は環境変数で切り替え）

## 7. 非機能要件

### パフォーマンス目標
- APIレスポンスタイム: 95パーセンタイルで500ms以下
- 動画ストリーミング: 初期バッファリング3秒以内
- 同時接続ユーザー数: 10,000人

### セキュリティ要件
- HTTPS通信必須
- SQLインジェクション対策（PreparedStatement使用）
- XSS対策（入力サニタイゼーション）
- CSRF対策（未実装）

### 可用性・スケーラビリティ
- 可用性: 99.9%（月間ダウンタイム43分以内）
- オートスケーリング: CPU使用率70%でスケールアウト
- データベース: リードレプリカ3台
