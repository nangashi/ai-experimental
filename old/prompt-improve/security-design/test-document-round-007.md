# TaskFlow システム設計書

## 1. 概要

### プロジェクトの目的と背景
TaskFlowは、リモートワークに特化したチーム向けプロジェクト管理SaaSプラットフォームである。タスク管理、ドキュメント共有、リアルタイムコラボレーション機能を統合し、分散チームの生産性向上を支援する。

### 主要機能の一覧
- タスク管理（作成・割り当て・ステータス追跡）
- ドキュメント共有とバージョン管理
- リアルタイムチャット・通知
- プロジェクトダッシュボード・レポート生成
- 組織・チーム管理
- 外部サービス連携（Slack、GitHub、Google Workspace）

### 対象ユーザーと利用シナリオ
- **主要ユーザー**: スタートアップから中規模企業のプロジェクトマネージャー、開発チーム、マーケティングチーム
- **利用シナリオ**:
  - プロジェクト立ち上げから完了までのタスク進捗管理
  - チームメンバー間でのドキュメント共同編集
  - 外部パートナーとの限定的な情報共有

## 2. 技術スタック

### 言語・フレームワーク
- **バックエンド**: Node.js v20 + Express.js v4
- **フロントエンド**: React v18 + TypeScript v5
- **リアルタイム通信**: Socket.IO v4

### データベース
- **メインDB**: PostgreSQL v16（組織・ユーザー・プロジェクト・タスク）
- **キャッシュ**: Redis v7（セッション、リアルタイム状態管理）

### インフラ・デプロイ環境
- **クラウド**: AWS（ap-northeast-1リージョン）
- **コンテナ**: Docker + Kubernetes（EKS）
- **CDN**: CloudFront（静的アセット配信）
- **ストレージ**: S3（ドキュメントファイル保存）

### 主要ライブラリ
- **認証**: Passport.js、jsonwebtoken
- **ファイル処理**: multer、sharp
- **バリデーション**: express-validator
- **ORM**: Sequelize v6

## 3. アーキテクチャ設計

### 全体構成
マイクロサービス志向のモノリシック構成を採用。主要なレイヤーは以下の通り:

```
[クライアント層]
  ↕
[API Gateway層] (Express.js)
  ↕
[ビジネスロジック層]
  ├─ 認証・認可サービス
  ├─ プロジェクト管理サービス
  ├─ ドキュメント管理サービス
  ├─ 通知サービス
  └─ 外部連携サービス
  ↕
[データアクセス層] (Sequelize ORM)
  ↕
[データストア層] (PostgreSQL, Redis, S3)
```

### 主要コンポーネントの責務
- **API Gateway**: リクエストルーティング、レート制限、CORS設定
- **認証・認可サービス**: ユーザー認証、JWT発行、権限チェック
- **プロジェクト管理サービス**: プロジェクト・タスクのCRUD、進捗計算
- **ドキュメント管理サービス**: ファイルアップロード、バージョン管理、プレビュー生成
- **通知サービス**: リアルタイム通知配信、メール通知キュー管理
- **外部連携サービス**: OAuth2.0フロー、Webhook処理

### データフロー
1. クライアントからのHTTPリクエストはAPI Gatewayで受信
2. JWT認証ミドルウェアでトークン検証
3. ビジネスロジック層で処理を実行
4. データアクセス層経由でDB操作
5. レスポンスをクライアントに返却

## 4. データモデル

### 主要エンティティ

#### Organization（組織）
| カラム | 型 | 制約 |
|-------|---|-----|
| id | UUID | PK |
| name | VARCHAR(255) | NOT NULL |
| plan_type | ENUM('free', 'pro', 'enterprise') | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |

#### User（ユーザー）
| カラム | 型 | 制約 |
|-------|---|-----|
| id | UUID | PK |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| password_hash | VARCHAR(255) | NOT NULL |
| full_name | VARCHAR(255) | NOT NULL |
| organization_id | UUID | FK → Organization |
| role | ENUM('owner', 'admin', 'member', 'guest') | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |

#### Project（プロジェクト）
| カラム | 型 | 制約 |
|-------|---|-----|
| id | UUID | PK |
| name | VARCHAR(255) | NOT NULL |
| organization_id | UUID | FK → Organization |
| visibility | ENUM('private', 'org_internal', 'public') | NOT NULL |
| created_by | UUID | FK → User |
| created_at | TIMESTAMP | NOT NULL |

#### Task（タスク）
| カラム | 型 | 制約 |
|-------|---|-----|
| id | UUID | PK |
| title | VARCHAR(500) | NOT NULL |
| description | TEXT | |
| project_id | UUID | FK → Project |
| assigned_to | UUID | FK → User, NULLABLE |
| status | ENUM('todo', 'in_progress', 'done') | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |
| updated_at | TIMESTAMP | NOT NULL |

#### Document（ドキュメント）
| カラム | 型 | 制約 |
|-------|---|-----|
| id | UUID | PK |
| filename | VARCHAR(255) | NOT NULL |
| s3_key | VARCHAR(512) | NOT NULL |
| project_id | UUID | FK → Project |
| uploaded_by | UUID | FK → User |
| file_size | INTEGER | NOT NULL |
| mime_type | VARCHAR(100) | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |

## 5. API設計

### エンドポイント一覧

#### 認証関連
- `POST /api/v1/auth/signup` - 新規ユーザー登録
- `POST /api/v1/auth/login` - ログイン
- `POST /api/v1/auth/logout` - ログアウト
- `GET /api/v1/auth/me` - 現在のユーザー情報取得

#### プロジェクト管理
- `GET /api/v1/projects` - プロジェクト一覧取得
- `POST /api/v1/projects` - プロジェクト作成
- `GET /api/v1/projects/:id` - プロジェクト詳細取得
- `PUT /api/v1/projects/:id` - プロジェクト更新
- `DELETE /api/v1/projects/:id` - プロジェクト削除

#### タスク管理
- `GET /api/v1/projects/:projectId/tasks` - タスク一覧取得
- `POST /api/v1/projects/:projectId/tasks` - タスク作成
- `PUT /api/v1/tasks/:id` - タスク更新
- `DELETE /api/v1/tasks/:id` - タスク削除

#### ドキュメント管理
- `POST /api/v1/projects/:projectId/documents` - ドキュメントアップロード
- `GET /api/v1/documents/:id` - ドキュメント取得
- `DELETE /api/v1/documents/:id` - ドキュメント削除

### リクエスト/レスポンス形式
すべてのAPIはJSON形式でデータを送受信する。

**成功レスポンス例（タスク作成）**:
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "新機能の設計",
    "status": "todo",
    "created_at": "2026-02-10T12:00:00Z"
  }
}
```

**エラーレスポンス例**:
```json
{
  "success": false,
  "error": {
    "code": "INVALID_REQUEST",
    "message": "タスクタイトルは必須です"
  }
}
```

### 認証・認可方式
- **認証方式**: JWT（JSON Web Token）ベース
- **トークン格納**: ブラウザのlocalStorageに保存
- **トークン有効期限**: 24時間
- **認可モデル**:
  - Organization内のroleベース（owner > admin > member > guest）
  - リソース（Project、Task）ごとのアクセスコントロール

## 6. 実装方針

### エラーハンドリング方針
- すべての非同期処理にtry-catchを適用
- 予期しないエラーは500エラーとして返却し、ログに詳細を記録
- バリデーションエラーは400エラーとして返却
- 認証エラーは401、認可エラーは403として返却

### ロギング方針
- **ログライブラリ**: Winston v3
- **ログレベル**: error、warn、info、debug
- **ログ出力先**:
  - 開発環境: コンソール
  - 本番環境: CloudWatch Logs
- **ログ対象イベント**:
  - すべてのAPI呼び出し
  - 認証失敗
  - DB接続エラー
  - 外部API呼び出し失敗

### テスト方針
- **単体テスト**: Jest、カバレッジ80%以上
- **統合テスト**: Supertest（APIエンドポイント）
- **E2Eテスト**: Playwright（主要ユーザーフロー）
- **パフォーマンステスト**: k6（APIレスポンスタイム計測）

### デプロイメント方針
- **デプロイフロー**:
  1. GitHub ActionsでCI/CD実行
  2. Docker imageビルド・ECRプッシュ
  3. Kubernetesマニフェスト更新
  4. EKSクラスターへローリングアップデート
- **環境**: development、staging、production の3環境
- **ブルーグリーンデプロイ**: 本番環境のみ適用

## 7. 非機能要件

### パフォーマンス目標
- **APIレスポンスタイム**: 95パーセンタイルで500ms以下
- **同時接続数**: 10,000ユーザーまで対応
- **ページロード時間**: 初回3秒以内、2回目以降1秒以内（キャッシュ利用）

### セキュリティ要件
- すべてのAPI通信はHTTPS経由
- パスワードはbcryptでハッシュ化（コスト係数10）
- ファイルアップロードは10MB制限
- SQLインジェクション対策としてSequelize ORM使用
- XSS対策としてReactのデフォルトエスケーピング利用

### 可用性・スケーラビリティ
- **SLA**: 99.9%（月間ダウンタイム43分以内）
- **スケーリング**:
  - 水平スケーリング: Pod数を自動調整（CPU使用率70%で増加）
  - データベース: Read Replicaで読み取り負荷分散
- **バックアップ**:
  - PostgreSQL: 毎日自動バックアップ、30日間保持
  - S3: バージョニング有効化
