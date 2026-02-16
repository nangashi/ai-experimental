# リアルタイム医療予約システム設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
地域医療機関の予約管理を統合し、患者が複数の診療科・医療機関をオンラインで検索・予約できるプラットフォームを構築する。医療従事者は予約状況を一元管理し、患者カルテとの連携により効率的な診療準備を実現する。

### 1.2 主要機能
- 患者向け機能: 医療機関検索、診療科別予約、予約変更・キャンセル、診察履歴の閲覧
- 医療機関向け機能: 予約管理、診察記録入力、患者カルテ管理、統計レポート
- 管理者向け機能: 医療機関登録・管理、アクセス解析、システム設定

### 1.3 対象ユーザーと利用シナリオ
- 患者: スマートフォンアプリまたはWebブラウザから医療機関を検索し、24時間いつでも予約
- 医療従事者: 院内PCから予約状況を確認し、診察前に患者情報を閲覧
- 管理者: バックオフィスから医療機関の追加・削除、利用状況モニタリング

## 2. 技術スタック

### 2.1 言語・フレームワーク
- フロントエンド: React 18.3 (TypeScript)
- バックエンド: Spring Boot 3.2 (Java 21)
- モバイルアプリ: React Native 0.73

### 2.2 データベース
- プライマリDB: PostgreSQL 16
- キャッシュ: Redis 7.2

### 2.3 インフラ・デプロイ環境
- クラウドプロバイダ: AWS
- コンテナ: Docker + Amazon ECS
- API Gateway: AWS API Gateway
- ストレージ: Amazon S3（画像・ドキュメント）

### 2.4 主要ライブラリ
- 認証: Spring Security 6.2
- ORM: Spring Data JPA (Hibernate 6.4)
- API文書化: springdoc-openapi 2.3
- ログ: Logback 1.4

## 3. アーキテクチャ設計

### 3.1 全体構成
3層アーキテクチャを採用する:
- プレゼンテーション層: React SPA、React Nativeアプリ
- アプリケーション層: Spring Boot RESTful API（ビジネスロジック、認証・認可制御）
- データ層: PostgreSQL、Redis

コンポーネント間の通信はHTTPS + JSON形式で行う。

### 3.2 主要コンポーネントの責務と依存関係
- **API Gateway**: 外部リクエストの受付、APIキー検証、レート制限（1分あたり100リクエスト）
- **認証サービス**: ユーザー登録、ログイン処理、JWT発行
- **予約管理サービス**: 予約CRUD、空き状況検索、通知処理
- **カルテ管理サービス**: 診察記録の作成・更新、患者データの取得
- **通知サービス**: メール・プッシュ通知の送信

### 3.3 データフロー
1. ユーザーがログインしJWTを取得
2. JWTをAuthorizationヘッダーに含めてAPIリクエスト
3. API Gatewayがリクエストを受け、レート制限チェック後にバックエンドに転送
4. Spring Securityが各エンドポイントでJWT検証
5. ビジネスロジック処理後、結果をJSON形式で返却

## 4. データモデル

### 4.1 主要エンティティと関連
- **User**: ユーザーアカウント（患者、医療従事者、管理者）
- **Patient**: 患者プロフィール（氏名、生年月日、住所、電話番号、メールアドレス、保険情報）
- **MedicalInstitution**: 医療機関（施設名、住所、診療科目、受付時間）
- **Appointment**: 予約（予約日時、診療科、患者ID、医療機関ID、ステータス）
- **MedicalRecord**: 診察記録（診断内容、処方薬、検査結果、担当医師）

### 4.2 テーブル設計

#### users テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | BIGINT | PRIMARY KEY | ユーザーID |
| username | VARCHAR(50) | UNIQUE, NOT NULL | ユーザー名 |
| password | VARCHAR(100) | NOT NULL | パスワード（bcryptハッシュ） |
| role | VARCHAR(20) | NOT NULL | ロール（PATIENT, DOCTOR, ADMIN） |
| email | VARCHAR(100) | UNIQUE, NOT NULL | メールアドレス |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### patients テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | BIGINT | PRIMARY KEY | 患者ID |
| user_id | BIGINT | FOREIGN KEY (users.id) | ユーザーID |
| full_name | VARCHAR(100) | NOT NULL | 氏名 |
| date_of_birth | DATE | NOT NULL | 生年月日 |
| address | TEXT | | 住所 |
| phone_number | VARCHAR(20) | | 電話番号 |
| insurance_number | VARCHAR(50) | | 保険証番号 |

#### appointments テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | BIGINT | PRIMARY KEY | 予約ID |
| patient_id | BIGINT | FOREIGN KEY (patients.id) | 患者ID |
| institution_id | BIGINT | FOREIGN KEY (medical_institutions.id) | 医療機関ID |
| appointment_time | TIMESTAMP | NOT NULL | 予約日時 |
| department | VARCHAR(50) | NOT NULL | 診療科 |
| status | VARCHAR(20) | NOT NULL | ステータス（PENDING, CONFIRMED, CANCELLED） |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### medical_records テーブル
| カラム | 型 | 制約 | 説明 |
|--------|-----|------|------|
| id | BIGINT | PRIMARY KEY | 診察記録ID |
| patient_id | BIGINT | FOREIGN KEY (patients.id) | 患者ID |
| appointment_id | BIGINT | FOREIGN KEY (appointments.id) | 予約ID |
| diagnosis | TEXT | | 診断内容 |
| prescription | TEXT | | 処方薬 |
| lab_results | TEXT | | 検査結果 |
| doctor_name | VARCHAR(100) | | 担当医師名 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

## 5. API設計

### 5.1 エンドポイント一覧

#### 認証API
- `POST /api/auth/register` - 新規ユーザー登録
- `POST /api/auth/login` - ログイン（JWTトークン発行）
- `POST /api/auth/refresh` - トークンリフレッシュ
- `POST /api/auth/logout` - ログアウト

#### 予約API
- `GET /api/appointments` - 予約一覧取得
- `GET /api/appointments/{id}` - 予約詳細取得
- `POST /api/appointments` - 予約作成
- `PUT /api/appointments/{id}` - 予約更新
- `DELETE /api/appointments/{id}` - 予約キャンセル

#### 患者API
- `GET /api/patients/{id}` - 患者情報取得
- `PUT /api/patients/{id}` - 患者情報更新
- `GET /api/patients/{id}/records` - 診察履歴取得

#### カルテAPI
- `GET /api/records/{id}` - 診察記録取得
- `POST /api/records` - 診察記録作成
- `PUT /api/records/{id}` - 診察記録更新

### 5.2 リクエスト/レスポンス形式

#### ログインリクエスト例
```json
POST /api/auth/login
{
  "username": "patient001",
  "password": "SecurePass123!"
}
```

#### ログインレスポンス例
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "refreshToken": "refresh_abc123..."
}
```

### 5.3 認証・認可方式
- JWT (JSON Web Token) ベースの認証を採用
- JWTペイロードにユーザーID、ロール、有効期限を含む
- トークンの有効期限は1時間、リフレッシュトークンは30日間
- JWTトークンはlocalStorageに保存し、各APIリクエストのAuthorizationヘッダーで送信する
- ロールベースアクセス制御（RBAC）により、エンドポイントごとに必要なロールを定義

## 6. 実装方針

### 6.1 エラーハンドリング方針
- すべての例外は統一形式のエラーレスポンスとして返却する
- HTTPステータスコードを適切に設定（400: Bad Request, 401: Unauthorized, 403: Forbidden, 404: Not Found, 500: Internal Server Error）
- エラーメッセージには詳細なスタックトレースを含め、デバッグを容易にする

エラーレスポンス形式:
```json
{
  "error": "Validation Error",
  "message": "Invalid email format",
  "timestamp": "2025-01-15T10:30:00Z",
  "path": "/api/auth/register",
  "details": "..."
}
```

### 6.2 ロギング方針
- すべてのAPIリクエスト・レスポンスをINFOレベルでログ出力する
- エラー発生時はERRORレベルでスタックトレースを含めて記録
- ログはJSON形式で構造化し、CloudWatch Logsに転送する

ログフォーマット例:
```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "level": "INFO",
  "logger": "com.example.controller.AppointmentController",
  "message": "Appointment created",
  "userId": "12345",
  "patientId": "67890",
  "appointmentId": "11111",
  "requestBody": "{...}"
}
```

### 6.3 テスト方針
- ユニットテスト: JUnit 5、Mockito を使用しカバレッジ80%以上を目標とする
- 統合テスト: Testcontainers でPostgreSQL・Redisを起動し、実環境に近い状態でテスト
- E2Eテスト: Selenium を使用した主要ユーザーフローの自動テスト

### 6.4 デプロイメント方針
- GitHub ActionsでCIパイプラインを構築（テスト実行、Docker イメージビルド、ECRへのプッシュ）
- ECSのBlue/Green デプロイメントにより、ダウンタイムなしでリリース
- 環境変数はECS Task Definitionに記載し、AWS Systems Manager Parameter Storeから取得

## 7. 非機能要件

### 7.1 パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- 予約作成処理: 1秒以内に完了
- 同時接続ユーザー数: 10,000人をサポート

### 7.2 セキュリティ要件
- すべての通信をTLS 1.3で暗号化する
- パスワードはbcryptアルゴリズム（コスト係数10）でハッシュ化する
- 外部入力はSpring Validationで検証し、SQLインジェクション対策としてPreparedStatementを使用する

### 7.3 可用性・スケーラビリティ
- 稼働率目標: 99.9%（月間ダウンタイム43分以内）
- ECSオートスケーリングを設定し、CPU使用率70%でスケールアウト
- データベースはMulti-AZ構成により障害時の自動フェイルオーバーを実現
- 定期的なデータベースバックアップ（1日1回、30日間保持）
