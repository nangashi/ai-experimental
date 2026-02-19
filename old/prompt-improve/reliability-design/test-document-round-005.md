# TaskFlow プロジェクト管理SaaS システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
TaskFlowは、中小企業向けのクラウドベースプロジェクト管理SaaSである。チーム協業、タスク管理、リソース配分、進捗可視化を統合的に提供し、複数プロジェクトの同時進行を支援する。既存のスプレッドシート管理から移行する顧客をターゲットとし、初期導入の容易さと段階的な機能拡張を重視する。

### 1.2 主要機能
- プロジェクト・タスク管理（階層構造、依存関係、担当者割り当て）
- リアルタイム協業（コメント、@メンション、活動フィード）
- ダッシュボード（ガントチャート、バーンダウンチャート、リソース使用状況）
- 外部サービス連携（Slack通知、Google Calendar同期、GitHub Issue同期）
- ファイル共有（最大50MB/ファイル、S3保存）
- レポート・分析（週次/月次レポート自動生成、CSV/PDFエクスポート）

### 1.3 対象ユーザーと利用シナリオ
- **プロジェクトマネージャー**: プロジェクト全体の進捗把握、リソース配分最適化
- **チームメンバー**: 自分のタスク管理、進捗更新、コメントでのコミュニケーション
- **経営層**: 複数プロジェクトの横断分析、リソース使用状況の可視化

想定規模: 1組織あたり10-200ユーザー、同時ログイン50ユーザー程度

## 2. 技術スタック

### 2.1 言語・フレームワーク
- **Backend**: Java 17 + Spring Boot 3.2
- **Frontend**: TypeScript + React 18 + TanStack Query
- **Real-time**: WebSocket (Spring WebSocket + STOMP)

### 2.2 データベース
- **Primary DB**: PostgreSQL 15 (RDS Multi-AZ)
- **Cache**: Redis 7 (ElastiCache クラスターモード)
- **Search**: Elasticsearch 8 (タスク全文検索、活動ログ検索)

### 2.3 インフラ・デプロイ環境
- **Cloud Provider**: AWS
- **Container**: ECS Fargate (Application 3 tasks, WebSocket 2 tasks)
- **Load Balancer**: ALB (sticky session有効)
- **Storage**: S3 (ファイル保存)
- **CDN**: CloudFront
- **CI/CD**: GitHub Actions + AWS CodeDeploy

### 2.4 主要ライブラリ・外部サービス
- **認証**: Auth0 (OAuth 2.0 + SAML SSO対応)
- **通知**: Slack API, SendGrid (メール)
- **外部連携**: Google Calendar API, GitHub API
- **監視**: CloudWatch, Datadog APM

## 3. アーキテクチャ設計

### 3.1 全体構成
```
[Frontend (CloudFront + S3)]
         ↓
[ALB (sticky session)]
         ↓ ↓ ↓
[ECS Application Tasks (×3)]  [ECS WebSocket Tasks (×2)]
         ↓ ↓                         ↓
[PostgreSQL Multi-AZ]  [Redis Cluster]  [Elasticsearch]
         ↓
[S3 File Storage]
```

### 3.2 主要コンポーネント

#### Application Server
- **ProjectService**: プロジェクト・タスクのCRUD、依存関係検証
- **CollaborationService**: コメント投稿、@メンション通知
- **IntegrationService**: Slack/GitHub/Google Calendar連携
- **ReportService**: 週次/月次レポート生成（非同期バッチ）
- **FileService**: ファイルアップロード/ダウンロード、S3署名付きURL発行

#### WebSocket Server
- **ActivityFeedHandler**: タスク更新・コメント追加時の全クライアント配信
- **PresenceManager**: ユーザーオンライン状態管理

#### Background Jobs
- **NotificationWorker**: Slack通知・メール送信（SQS経由）
- **SyncWorker**: Google Calendar/GitHub Issue同期（5分間隔ポーリング）
- **ReportGenerator**: 週次レポート生成（月曜朝7:00実行）

### 3.3 データフロー

#### タスク作成フロー
1. Frontend → ALB → Application Server: POST /api/projects/{id}/tasks
2. Application Server: PostgreSQLにタスク保存
3. Application Server: SQSに通知メッセージ送信（担当者へのメンション通知）
4. Application Server: WebSocket経由で活動フィード更新通知
5. NotificationWorker: SQSからメッセージ取得→Slack API呼び出し

#### ファイルアップロードフロー
1. Frontend → Application Server: POST /api/files/upload-url（ファイル名・サイズ送信）
2. Application Server: S3署名付きURL発行（有効期限15分）
3. Frontend → S3: 署名付きURLに直接アップロード
4. Frontend → Application Server: POST /api/files/confirm（アップロード完了通知）
5. Application Server: PostgreSQLにファイルメタデータ保存

## 4. データモデル

### 4.1 主要エンティティ

#### organizations (組織)
- id: UUID (PK)
- name: VARCHAR(255)
- subscription_plan: VARCHAR(50) (free, pro, enterprise)
- created_at: TIMESTAMP

#### users (ユーザー)
- id: UUID (PK)
- organization_id: UUID (FK → organizations.id)
- email: VARCHAR(255) UNIQUE
- auth0_id: VARCHAR(255) UNIQUE
- role: VARCHAR(20) (admin, member, viewer)
- created_at: TIMESTAMP

#### projects (プロジェクト)
- id: UUID (PK)
- organization_id: UUID (FK → organizations.id)
- name: VARCHAR(255)
- status: VARCHAR(20) (active, archived)
- start_date: DATE
- end_date: DATE
- created_by: UUID (FK → users.id)
- created_at: TIMESTAMP
- updated_at: TIMESTAMP

#### tasks (タスク)
- id: UUID (PK)
- project_id: UUID (FK → projects.id)
- parent_task_id: UUID NULL (FK → tasks.id, 階層構造)
- title: VARCHAR(500)
- description: TEXT
- assignee_id: UUID NULL (FK → users.id)
- status: VARCHAR(20) (todo, in_progress, done)
- priority: VARCHAR(10) (low, medium, high)
- due_date: DATE NULL
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
- version: INT (楽観的ロック用)

#### task_dependencies (タスク依存関係)
- id: UUID (PK)
- task_id: UUID (FK → tasks.id)
- depends_on_task_id: UUID (FK → tasks.id)
- created_at: TIMESTAMP

#### comments (コメント)
- id: UUID (PK)
- task_id: UUID (FK → tasks.id)
- user_id: UUID (FK → users.id)
- content: TEXT
- created_at: TIMESTAMP

#### files (ファイル)
- id: UUID (PK)
- task_id: UUID NULL (FK → tasks.id)
- project_id: UUID (FK → projects.id)
- uploader_id: UUID (FK → users.id)
- filename: VARCHAR(500)
- s3_key: VARCHAR(1000)
- size_bytes: BIGINT
- created_at: TIMESTAMP

### 4.2 インデックス設計
- tasks.project_id, tasks.assignee_id, tasks.status (複合インデックス)
- comments.task_id, comments.created_at (複合インデックス)
- files.project_id, files.created_at (複合インデックス)

## 5. API設計

### 5.1 主要エンドポイント

#### プロジェクト管理
- GET /api/projects: プロジェクト一覧取得
- POST /api/projects: 新規プロジェクト作成
- GET /api/projects/{id}: プロジェクト詳細取得
- PUT /api/projects/{id}: プロジェクト更新
- DELETE /api/projects/{id}: プロジェクト削除（論理削除：status = archived）

#### タスク管理
- GET /api/projects/{id}/tasks: タスク一覧取得（フィルタ: status, assignee, due_date）
- POST /api/projects/{id}/tasks: 新規タスク作成
- PUT /api/tasks/{id}: タスク更新（楽観的ロックversion必須）
- DELETE /api/tasks/{id}: タスク削除

#### コメント
- GET /api/tasks/{id}/comments: コメント一覧取得
- POST /api/tasks/{id}/comments: コメント投稿

#### ファイル管理
- POST /api/files/upload-url: アップロード用署名付きURL発行
- POST /api/files/confirm: アップロード完了通知
- GET /api/files/{id}/download-url: ダウンロード用署名付きURL発行（有効期限5分）

#### 外部連携
- POST /api/integrations/slack/connect: Slack連携開始（OAuth）
- POST /api/integrations/github/sync: GitHub Issue同期トリガー

### 5.2 認証・認可
- **認証**: Auth0経由のOAuth 2.0。JWTトークンをBearerヘッダーで送信
- **認可**: ロールベース（admin/member/viewer）+ リソースレベル（同一組織内のみアクセス可能）

## 6. 実装方針

### 6.1 エラーハンドリング
- すべてのAPI呼び出しは標準エラーレスポンス形式を返す（`{error_code, message, details}`）
- 4xxエラー: クライアント側で再送不可（バリデーションエラー、認可エラー等）
- 5xxエラー: サーバー側エラー（ログ出力、アラート通知）

### 6.2 ロギング
- 構造化ログ（JSON形式）でCloudWatch Logsに送信
- ログレベル: DEBUG（開発環境のみ）、INFO（本番環境）、ERROR（例外発生時）
- リクエストごとにrequest_idを生成し、全ログに含める

### 6.3 テスト方針
- 単体テスト: JUnit 5 + Mockito（カバレッジ80%以上）
- 統合テスト: Testcontainers（PostgreSQL, Redis, Elasticsearchをコンテナで起動）
- E2Eテスト: Playwright（主要ユーザーフローのみ）

### 6.4 デプロイメント
- **戦略**: Blue-Green Deployment（ECS Task Definition更新）
- **プロセス**:
  1. GitHub mainブランチへのマージでCI/CD起動
  2. Docker イメージビルド→ECR push
  3. ECS新タスク起動（Green環境）
  4. ヘルスチェック成功後、ALBターゲットグループ切り替え
  5. 旧タスク（Blue環境）は10分間待機後削除

## 7. 非機能要件

### 7.1 パフォーマンス目標
- **API レスポンスタイム**: p95 < 300ms（一覧取得）、p95 < 500ms（詳細取得・更新）
- **WebSocket メッセージ配信**: 1秒以内に全接続クライアントへ配信
- **ファイルアップロード**: 50MBファイルを30秒以内に完了

### 7.2 セキュリティ要件
- すべての通信はTLS 1.2以上で暗号化
- S3署名付きURLは最小限の有効期限（アップロード15分、ダウンロード5分）
- SQLインジェクション対策: ORMのパラメータバインディング使用
- XSS対策: フロントエンドでのサニタイゼーション

### 7.3 可用性・スケーラビリティ
- **目標稼働率**: 99.5%（月間ダウンタイム3.6時間以内）
- **スケーリング**: ECS Auto Scaling（CPU使用率70%でスケールアウト）
- **データベース**: PostgreSQL Multi-AZ構成で自動フェイルオーバー
- **キャッシュ**: Redis クラスターモードで複数ノード構成

### 7.4 バックアップ・復旧
- **PostgreSQL**: 自動バックアップ（1日1回）+ トランザクションログ保持（7日間）
- **S3**: バージョニング有効化
- **RPO**: 1時間、**RTO**: 4時間
