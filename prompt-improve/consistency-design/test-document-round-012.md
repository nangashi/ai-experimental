# Content Publishing Platform システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
本プロジェクトは、複数の編集者が協働でコンテンツを作成・管理するためのWebベースのコンテンツ管理プラットフォームを構築する。記事の下書き、レビュー、公開、アーカイブのライフサイクル全体を管理し、SEO最適化やアクセス解析機能を統合する。

### 1.2 主要機能
- 記事作成・編集（Markdown、リッチテキスト対応）
- レビューワークフロー（編集者→レビュアー→承認者）
- メディアライブラリ（画像・動画の一元管理）
- タグ・カテゴリ管理
- 公開スケジューリング
- SEOメタデータ管理
- アクセス解析レポート

### 1.3 対象ユーザー
- コンテンツライター（記事執筆）
- 編集者（記事レビュー・承認）
- 管理者（システム設定・ユーザー管理）

## 2. 技術スタック

### 2.1 言語・フレームワーク
- バックエンド: Java 17, Spring Boot 3.2
- フロントエンド: React 18, TypeScript 5.0
- データベース: PostgreSQL 15

### 2.2 主要ライブラリ
- ORM: JPA (Hibernate 6.2)
- HTTP通信: OkHttp 4.12
- バリデーション: Hibernate Validator
- キャッシュ: Redis
- 検索: Elasticsearch 8.x

### 2.3 インフラ・デプロイ環境
- コンテナ: Docker, Kubernetes
- CI/CD: GitHub Actions
- クラウド: AWS (ECS, RDS, S3, CloudFront)

## 3. アーキテクチャ設計

### 3.1 全体構成
レイヤー構成は以下の通り:

```
Presentation Layer (Controller)
        ↓
Business Logic Layer (Service)
        ↓
Data Access Layer (Repository)
        ↓
Database
```

### 3.2 主要コンポーネント

#### 3.2.1 コンテンツ管理モジュール
- **ArticleController**: 記事のCRUD操作のエンドポイントを提供
- **ArticleService**: 記事のビジネスロジック（バリデーション、ワークフロー制御）
- **ArticleRepository**: 記事データの永続化

#### 3.2.2 ワークフロー管理モジュール
- **WorkflowController**: レビュープロセスのAPI
- **WorkflowService**: ステータス遷移ロジック
- **WorkflowRepository**: ワークフロー履歴の管理

#### 3.2.3 メディア管理モジュール
- **MediaController**: ファイルアップロード・取得API
- **MediaService**: S3への保存処理、サムネイル生成
- **MediaRepository**: メディアメタデータの管理

### 3.3 データフロー
1. クライアントがArticleControllerにリクエスト送信
2. ArticleServiceがビジネスロジックを実行
3. ArticleRepositoryがデータベースにアクセス
4. 結果をレスポンスとして返却

## 4. データモデル

### 4.1 主要エンティティ

#### 4.1.1 Article（記事）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| id | BIGINT | PK | 記事ID |
| title | VARCHAR(200) | NOT NULL | 記事タイトル |
| content | TEXT | NOT NULL | 記事本文 |
| status | VARCHAR(20) | NOT NULL | ステータス（draft/review/published/archived） |
| author_id | BIGINT | FK → user.id | 執筆者ID |
| category | VARCHAR(50) | | カテゴリ名 |
| publish_date | TIMESTAMP | | 公開日時 |
| created | TIMESTAMP | NOT NULL, DEFAULT NOW() | 作成日時 |
| updated | TIMESTAMP | NOT NULL, DEFAULT NOW() | 更新日時 |

#### 4.1.2 User（ユーザー）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| id | BIGINT | PK | ユーザーID |
| user_name | VARCHAR(50) | NOT NULL, UNIQUE | ユーザー名 |
| email | VARCHAR(100) | NOT NULL, UNIQUE | メールアドレス |
| role | VARCHAR(20) | NOT NULL | 権限（writer/editor/admin） |
| createdAt | TIMESTAMP | NOT NULL | 作成日時 |
| updatedAt | TIMESTAMP | NOT NULL | 更新日時 |

#### 4.1.3 Media（メディア）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| media_id | BIGINT | PK | メディアID |
| file_name | VARCHAR(200) | NOT NULL | ファイル名 |
| file_path | VARCHAR(500) | NOT NULL | S3パス |
| file_size | BIGINT | NOT NULL | ファイルサイズ（バイト） |
| mime_type | VARCHAR(50) | NOT NULL | MIMEタイプ |
| uploaded_by | BIGINT | FK → user.id | アップロードユーザーID |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

#### 4.1.4 Review（レビュー）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| review_id | BIGINT | PK | レビューID |
| article_id | BIGINT | FK → article.id | 対象記事ID |
| reviewer | BIGINT | FK → user.id | レビュアーID |
| status | VARCHAR(20) | NOT NULL | レビューステータス（pending/approved/rejected） |
| comment | TEXT | | レビューコメント |
| reviewed_at | TIMESTAMP | | レビュー実施日時 |
| created | TIMESTAMP | NOT NULL | 作成日時 |
| modified | TIMESTAMP | NOT NULL | 更新日時 |

### 4.2 外部キー制約
- `article.author_id` → `user.id`
- `media.uploaded_by` → `user.id`
- `review.article_id` → `article.id`
- `review.reviewer` → `user.id`

## 5. API設計

### 5.1 エンドポイント一覧

#### 5.1.1 記事管理
- `POST /api/articles/new` - 記事作成
- `GET /api/articles/{id}` - 記事取得
- `PUT /api/articles/{id}/edit` - 記事更新
- `DELETE /api/articles/{id}` - 記事削除
- `GET /api/articles/list` - 記事一覧取得

#### 5.1.2 メディア管理
- `POST /api/v1/media` - メディアアップロード
- `GET /api/v1/media/{id}` - メディア取得
- `DELETE /api/v1/media/{id}` - メディア削除

#### 5.1.3 レビューワークフロー
- `POST /api/v1/reviews` - レビュー作成
- `PUT /api/v1/reviews/{id}` - レビューステータス更新
- `GET /api/v1/reviews/article/{articleId}` - 記事のレビュー履歴取得

### 5.2 リクエスト/レスポンス形式

#### 5.2.1 記事作成リクエスト例
```json
{
  "title": "記事タイトル",
  "content": "記事本文",
  "categoryId": 1,
  "tags": ["tech", "tutorial"]
}
```

#### 5.2.2 レスポンス形式
```json
{
  "success": true,
  "data": {
    "id": 123,
    "title": "記事タイトル",
    "status": "draft"
  },
  "message": "Article created successfully"
}
```

#### 5.2.3 エラーレスポンス形式
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Title is required"
  }
}
```

### 5.3 認証・認可方式
- JWT認証を採用
- トークンはリクエストヘッダー `Authorization: Bearer {token}` で送信
- トークン有効期限: 24時間
- トークン保存先: ブラウザのlocalStorageに保存

## 6. 実装方針

### 6.1 エラーハンドリング
各サービス層でビジネス例外をスローし、コントローラー層で個別にcatchしてHTTPステータスコードに変換する。

例:
```java
@RestController
public class ArticleController {
    @PostMapping("/articles")
    public ResponseEntity<?> createArticle(@RequestBody ArticleRequest req) {
        try {
            Article article = articleService.create(req);
            return ResponseEntity.ok(article);
        } catch (ValidationException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        } catch (Exception e) {
            return ResponseEntity.status(500).body("Internal error");
        }
    }
}
```

### 6.2 ロギング方針
- ログレベル: DEBUG, INFO, WARN, ERROR
- ログフォーマット: `[{timestamp}] {level} {class}.{method} - {message}`
- 本番環境ではINFO以上のみ出力

### 6.3 データアクセス
JPA (Hibernate) を使用。複数エンティティの更新が必要な場合は、各Repositoryメソッドを個別に呼び出す。

### 6.4 テスト方針
- 単体テスト: JUnit 5, Mockito
- 統合テスト: Spring Boot Test, Testcontainers
- E2Eテスト: Selenium

### 6.5 デプロイメント方針
- ブルーグリーンデプロイメント
- ヘルスチェックエンドポイント: `/health`
- Kubernetesのローリングアップデート機能を使用

## 7. 非機能要件

### 7.1 パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以下
- 同時接続ユーザー: 1,000ユーザー
- データベースクエリ最適化: N+1問題の回避

### 7.2 セキュリティ要件
- 全通信をHTTPS化
- SQLインジェクション対策（プリペアドステートメント使用）
- XSS対策（出力エスケープ）
- CSRF対策（トークン検証）
- 認証失敗時のレート制限: 5回/分

### 7.3 可用性・スケーラビリティ
- 稼働率目標: 99.9%
- データベースレプリケーション（マスター/スレーブ構成）
- アプリケーションサーバーの水平スケーリング対応
- 静的コンテンツのCDN配信

## 8. 既存システム前提条件

### 8.1 既存コードベースのパターン
本システムは、既存の社内プラットフォーム群に統合される。既存システムとの一貫性を保つため、以下の既存パターンに従う必要がある:

#### 8.1.1 命名規約
- テーブル名: 単数形、スネークケース（例: `user`, `article`, `media_file`）
- カラム名: スネークケース（例: `user_name`, `created_at`, `updated_at`）
- 主キー列名: `id`（テーブル名プレフィックスなし）
- 外部キー列名: `{参照先テーブル名}_id` 形式（例: `user_id`, `article_id`）
- タイムスタンプ列名: `created_at`, `updated_at`（アンダースコア付き、過去分詞形）

#### 8.1.2 APIエンドポイント命名
- パスプレフィックス: `/api/v1/` 形式（バージョニング必須）
- リソース名: 複数形、ケバブケース（例: `/api/v1/articles`, `/api/v1/media-files`）
- HTTPメソッド: RESTful規約に従う（GET/POST/PUT/DELETE）

#### 8.1.3 実装パターン
- HTTP通信ライブラリ: RestTemplateを使用（WebClient不使用）
- レスポンス形式: `{data, error}` 形式（既存APIとの統一）

#### 8.1.4 ディレクトリ構造
- レイヤー別構成: `controller/`, `service/`, `repository/` を最上位に配置
- ドメイン別フォルダは各レイヤー内にサブディレクトリとして作成（例: `service/article/`, `service/media/`）
