# E-Learning Platform システム設計書

## 1. 概要

### プロジェクトの目的
社会人向けのオンライン学習プラットフォームを構築する。法人契約による企業研修コースと、個人向けのスキルアップコースの両方を提供する。

### 主要機能
- コース管理（作成、公開、受講登録）
- 動画配信（ストリーミング、進捗管理）
- クイズ・課題の提出と採点
- 受講証明書の発行
- 法人向け学習データ分析ダッシュボード

### 対象ユーザー
- 受講者（個人ユーザー、法人所属社員）
- コース作成者（講師）
- 法人管理者（企業の人事・研修担当）
- プラットフォーム管理者

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: TypeScript, NestJS
- フロントエンド: TypeScript, Next.js 14 (App Router)
- データベース: PostgreSQL 15
- キャッシュ: Redis 7

### インフラ・デプロイ環境
- クラウドプラットフォーム: AWS
- コンテナ: Docker, ECS Fargate
- CI/CD: GitHub Actions
- CDN: CloudFront

### 主要ライブラリ
- ORM: Prisma
- 動画処理: FFmpeg, AWS MediaConvert
- 認証: Passport.js
- バリデーション: class-validator

## 3. アーキテクチャ設計

### 全体構成
3層アーキテクチャを採用する。

- **Presentation層**: REST API（NestJS Controllers）
- **Business層**: Service層（ビジネスロジック）
- **Data層**: Repository層（データアクセス）

### 主要コンポーネント

#### コース管理モジュール
- CourseService: コースのCRUD、公開制御
- EnrollmentService: 受講登録、受講者管理
- CertificateService: 証明書発行

#### 動画配信モジュール
- VideoService: 動画アップロード、エンコーディング処理
- StreamingService: 署名付きURL生成、視聴進捗記録
- ProgressTracker: 視聴履歴の集計

#### 認証・認可モジュール
- AuthService: JWT発行、リフレッシュトークン管理
- RoleGuard: ロールベースのアクセス制御

### データフロー
1. クライアント → API Gateway → NestJS Controller
2. Controller → Service → Repository → Prisma → PostgreSQL
3. 動画視聴時: CloudFront → S3 (署名付きURL)
4. 非同期処理: SQS → Lambda (動画エンコーディング)

## 4. データモデル

### User（ユーザー）
| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| userId | UUID | PK | ユーザーID |
| email | VARCHAR(255) | UNIQUE, NOT NULL | メールアドレス |
| passwordHash | VARCHAR(255) | NOT NULL | パスワードハッシュ |
| displayName | VARCHAR(100) | NOT NULL | 表示名 |
| role | ENUM | NOT NULL | ロール (student, instructor, admin) |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

### Course（コース）
| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| course_id | UUID | PK | コースID |
| title | VARCHAR(200) | NOT NULL | コースタイトル |
| description | TEXT | - | コース説明 |
| instructor_id | UUID | FK → User.userId | 講師ID |
| status | ENUM | NOT NULL | 公開状態 (draft, published, archived) |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

### Enrollment（受講登録）
| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| enrollment_id | UUID | PK | 受講登録ID |
| user_id | UUID | FK → User.userId | ユーザーID |
| course_id | UUID | FK → Course.course_id | コースID |
| enrolled_at | TIMESTAMP | NOT NULL | 登録日時 |
| completion_status | VARCHAR(50) | NOT NULL | 進捗状態 |

### Video（動画）
| カラム名 | 型 | 制約 | 説明 |
|---------|---|------|------|
| videoId | UUID | PK | 動画ID |
| courseId | UUID | FK → Course.course_id | コースID |
| title | VARCHAR(200) | NOT NULL | 動画タイトル |
| s3Key | VARCHAR(500) | NOT NULL | S3オブジェクトキー |
| durationSeconds | INTEGER | NOT NULL | 再生時間（秒） |
| uploadedAt | TIMESTAMP | NOT NULL | アップロード日時 |

## 5. API設計

### エンドポイント一覧

#### コース管理
- `GET /api/v1/courses` - コース一覧取得
- `GET /api/v1/courses/:id` - コース詳細取得
- `POST /api/v1/courses` - コース作成
- `PUT /api/v1/courses/:id` - コース更新
- `DELETE /api/v1/courses/:id` - コース削除

#### 受講登録
- `POST /api/v1/courses/:id/enroll` - 受講登録
- `GET /api/v1/enrollments` - 自分の受講中コース一覧

#### 動画視聴
- `GET /api/v1/videos/:id/stream-url` - ストリーミングURL取得
- `POST /api/v1/videos/:id/progress` - 視聴進捗記録

#### 認証
- `POST /api/v1/auth/login` - ログイン
- `POST /api/v1/auth/refresh` - トークンリフレッシュ

### レスポンス形式
成功時:
```json
{
  "success": true,
  "data": { ... },
  "timestamp": "2026-02-11T10:30:00Z"
}
```

エラー時:
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input"
  },
  "timestamp": "2026-02-11T10:30:00Z"
}
```

### 認証・認可方式
- JWT Bearer Token による認証
- アクセストークン有効期限: 15分
- リフレッシュトークン有効期限: 7日
- ロールベースアクセス制御（RBAC）を実装

## 6. 実装方針

### ロギング方針
Winston を使用した構造化ログを出力する。

```typescript
logger.info('Course created', {
  courseId: course.id,
  instructorId: user.id,
  timestamp: new Date()
});
```

ログレベル:
- ERROR: システムエラー、例外
- WARN: 想定外の状態、リトライ処理
- INFO: 主要な処理の開始/終了
- DEBUG: 詳細なトレース情報（開発環境のみ）

### テスト方針
- ユニットテスト: Jest（カバレッジ目標80%以上）
- E2Eテスト: Playwright
- 統合テスト: テストコンテナを使用したDB統合テスト

### デプロイメント方針
- ブランチ戦略: GitHub Flow
- main ブランチへのマージで自動デプロイ
- ステージング環境での動作確認後、本番環境へ手動承認デプロイ

## 7. 非機能要件

### パフォーマンス目標
- API レスポンスタイム: P95 < 200ms
- 動画ストリーミング開始時間: < 2秒
- 同時接続ユーザー数: 10,000人以上

### セキュリティ要件
- HTTPS通信の強制
- SQL インジェクション対策（Prismaの自動エスケープ）
- XSS対策（サニタイゼーション）
- CORS設定による外部アクセス制限
- レート制限: 1 IP あたり 100 req/min

### 可用性・スケーラビリティ
- 目標稼働率: 99.9%
- ECS タスクのオートスケーリング（CPU使用率70%で拡張）
- データベースのリードレプリカ構成
- Redis によるセッション管理とクエリキャッシュ
