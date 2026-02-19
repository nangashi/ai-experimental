# EduStream - オンライン教育プラットフォーム システム設計書

## 1. 概要

### プロジェクトの目的と背景
EduStreamは、教育機関向けのクラウドベースのコンテンツ管理・ライブストリーミングプラットフォームである。教師がオンライン授業を配信し、録画コンテンツを管理し、学生の進捗を追跡できる統合型教育プラットフォームを提供する。

### 主要機能の一覧
- ライブストリーミング配信（講義、ワークショップ）
- 録画コンテンツの管理・配信（オンデマンド視聴）
- 学生管理・進捗追跡
- 課題提出・評価システム
- リアルタイムチャット・Q&Aフォーラム
- 決済処理（コース購入、サブスクリプション）

### 対象ユーザーと利用シナリオ
- **教師**: ライブ授業の配信、コンテンツのアップロード、学生の進捗管理、課題の評価
- **学生**: ライブ授業への参加、録画コンテンツの視聴、課題の提出、フォーラムでの質問
- **管理者**: ユーザー管理、コンテンツの承認・削除、プラットフォームの監視

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Node.js (Express), TypeScript
- フロントエンド: React, TypeScript
- リアルタイム通信: WebSocket (Socket.io)

### データベース
- メインDB: PostgreSQL 14（ユーザー、コース、課題データ）
- キャッシュ: Redis（セッション、リアルタイムデータ）
- ストレージ: AWS S3（録画コンテンツ、課題ファイル）

### インフラ・デプロイ環境
- ホスティング: AWS（EC2, ECS）
- CDN: CloudFront
- ストリーミング: AWS MediaLive / MediaPackage
- CI/CD: GitHub Actions

### 主要ライブラリ
- 認証: Passport.js, jsonwebtoken
- ストリーミング: WebRTC, AWS SDK
- 決済: Stripe API
- ファイルアップロード: multer

## 3. アーキテクチャ設計

### 全体構成
3層アーキテクチャを採用:
- **プレゼンテーション層**: React SPA
- **アプリケーション層**: Express REST API + WebSocket サーバー
- **データ層**: PostgreSQL, Redis, S3

### 主要コンポーネントの責務と依存関係
- **API Gateway**: 全リクエストのルーティング、レート制限
- **Auth Service**: ユーザー認証・認可
- **Content Service**: 録画コンテンツのCRUD、メタデータ管理
- **Streaming Service**: ライブストリーミングの開始・終了、視聴者管理
- **Assignment Service**: 課題の提出・評価
- **Payment Service**: Stripe連携による決済処理
- **Notification Service**: メール・プッシュ通知

### データフロー
1. ユーザーがログインし、JWTトークンを受け取る
2. トークンを使ってAPI Gatewayにリクエストを送信
3. Auth Serviceがトークンを検証
4. 各サービスがビジネスロジックを実行し、DBにアクセス
5. レスポンスをクライアントに返却

## 4. データモデル

### 主要エンティティと関連
- **User**: ユーザー情報（教師・学生・管理者）
- **Course**: コース情報（タイトル、説明、価格）
- **Video**: 録画コンテンツ（URL、長さ、アップロード日）
- **LiveSession**: ライブ配信セッション（開始時刻、ステータス）
- **Assignment**: 課題（タイトル、締切、配点）
- **Submission**: 課題提出（ファイルURL、提出日時、評価）
- **Payment**: 決済記録（金額、ステータス、日時）

### テーブル設計

#### users
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| password_hash | VARCHAR(255) | NOT NULL | ハッシュ化されたパスワード |
| role | ENUM('teacher', 'student', 'admin') | NOT NULL | ユーザー役割 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### courses
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | コースID |
| teacher_id | UUID | FK(users.id) | 教師ID |
| title | VARCHAR(500) | NOT NULL | コースタイトル |
| description | TEXT | | コース説明 |
| price | DECIMAL(10,2) | | 価格（NULL=無料） |
| is_public | BOOLEAN | DEFAULT true | 公開ステータス |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### videos
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | 動画ID |
| course_id | UUID | FK(courses.id) | コースID |
| title | VARCHAR(500) | NOT NULL | 動画タイトル |
| s3_key | VARCHAR(500) | NOT NULL | S3バケットキー |
| duration | INTEGER | | 動画長（秒） |
| uploaded_by | UUID | FK(users.id) | アップロード者 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### assignments
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | 課題ID |
| course_id | UUID | FK(courses.id) | コースID |
| title | VARCHAR(500) | NOT NULL | 課題タイトル |
| description | TEXT | | 課題説明 |
| deadline | TIMESTAMP | | 締切 |
| max_score | INTEGER | NOT NULL | 最大スコア |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### submissions
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | 提出ID |
| assignment_id | UUID | FK(assignments.id) | 課題ID |
| student_id | UUID | FK(users.id) | 学生ID |
| file_url | VARCHAR(1000) | | 提出ファイルURL |
| submitted_at | TIMESTAMP | NOT NULL | 提出日時 |
| score | INTEGER | | 評価スコア |
| feedback | TEXT | | フィードバック |

#### payments
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | UUID | PK | 決済ID |
| user_id | UUID | FK(users.id) | ユーザーID |
| course_id | UUID | FK(courses.id) | コースID |
| amount | DECIMAL(10,2) | NOT NULL | 金額 |
| stripe_payment_id | VARCHAR(255) | UNIQUE | Stripe決済ID |
| status | ENUM('pending', 'completed', 'failed') | NOT NULL | ステータス |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

## 5. API設計

### エンドポイント一覧

#### 認証関連
- `POST /api/auth/register` - ユーザー登録
- `POST /api/auth/login` - ログイン（JWTトークン発行）
- `POST /api/auth/logout` - ログアウト
- `POST /api/auth/refresh` - トークン更新

#### コース管理
- `GET /api/courses` - コース一覧取得
- `GET /api/courses/:id` - コース詳細取得
- `POST /api/courses` - コース作成（教師のみ）
- `PUT /api/courses/:id` - コース更新（教師のみ）
- `DELETE /api/courses/:id` - コース削除（教師・管理者のみ）

#### 動画管理
- `GET /api/videos/:id` - 動画メタデータ取得
- `POST /api/videos` - 動画アップロード（教師のみ）
- `DELETE /api/videos/:id` - 動画削除（教師・管理者のみ）
- `GET /api/videos/:id/stream` - 動画ストリーミングURL取得

#### 課題管理
- `GET /api/assignments/:course_id` - コースの課題一覧
- `POST /api/assignments` - 課題作成（教師のみ）
- `POST /api/submissions` - 課題提出（学生のみ）
- `PUT /api/submissions/:id/grade` - 課題評価（教師のみ）

#### 決済
- `POST /api/payments/create` - 決済セッション作成
- `POST /api/payments/webhook` - Stripe Webhook受信

### リクエスト/レスポンス形式
すべてのAPIはJSON形式でリクエスト・レスポンスを行う。

例: ログインAPI
```json
// Request
POST /api/auth/login
{
  "email": "student@example.com",
  "password": "password123"
}

// Response
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "uuid",
    "email": "student@example.com",
    "role": "student"
  }
}
```

### 認証・認可方式
- **認証**: JWT（JSON Web Token）を使用
- **トークン保存**: クライアント側でlocalStorageに保存
- **トークン有効期限**: 24時間
- **認可**: ロールベースアクセス制御（RBAC）。各エンドポイントでユーザーロールを検証

## 6. 実装方針

### エラーハンドリング方針
- すべてのエラーは集中エラーハンドラーで処理
- エラーレスポンス形式を統一: `{ "error": { "code": "ERROR_CODE", "message": "エラーメッセージ" } }`
- 本番環境ではスタックトレースを含めない

### ロギング方針
- アプリケーションログ: Winston使用
- ログレベル: ERROR, WARN, INFO, DEBUG
- ログ出力先: 開発環境=コンソール、本番環境=CloudWatch Logs
- アクセスログ: すべてのAPIリクエストをログに記録

### テスト方針
- ユニットテスト: Jest
- 統合テスト: Supertest
- E2Eテスト: Playwright
- カバレッジ目標: 80%以上

### デプロイメント方針
- ブルーグリーンデプロイメント
- CI/CDパイプライン: GitHub Actions
- デプロイ前に自動テスト実行
- ロールバック機能を実装

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 平均200ms以下
- 同時ライブ視聴者数: 10,000人対応
- 動画再生開始時間: 3秒以内

### セキュリティ要件
- すべてのAPI通信はHTTPSで暗号化
- パスワードはbcryptでハッシュ化（コスト係数10）
- SQLインジェクション対策: パラメータ化クエリ使用
- XSS対策: 出力時にエスケープ処理

### 可用性・スケーラビリティ
- SLA: 99.9%稼働率
- Auto Scaling: CPU使用率70%でスケールアウト
- データベースレプリケーション: マスター1台、スレーブ2台
- バックアップ: 日次フルバックアップ、トランザクションログの継続的バックアップ
