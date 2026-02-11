# オンライン診療予約・電子カルテ統合プラットフォーム システム設計書

## 1. 概要

### プロジェクトの目的と背景
本システムは、複数の医療機関が共同利用するクラウド型のオンライン診療予約・電子カルテ統合プラットフォームである。患者は自身のスマートフォンアプリから診療予約を行い、診療後には電子カルテへのアクセスを通じて診療履歴や処方箋を確認できる。医療機関側は患者情報の一元管理と、他院との診療情報共有が可能となる。

### 主要機能の一覧
1. 患者向け機能
   - 診療予約・キャンセル
   - 電子カルテ閲覧（診療履歴、検査結果、処方箋）
   - オンライン問診票の入力
   - 医療費支払い（クレジットカード/銀行振込）

2. 医療機関向け機能
   - 患者情報管理
   - 電子カルテ作成・編集
   - 予約枠管理
   - 処方箋発行
   - 診療情報共有（他院との連携）

3. 管理者機能
   - 医療機関登録・管理
   - 医師アカウント管理
   - システム利用統計

### 対象ユーザーと利用シナリオ
- **患者**: 月間100万人（想定）、年齢層10-80歳、スマートフォンアプリまたはWebブラウザから利用
- **医療従事者**: 登録医療機関500施設、医師・看護師計5,000名
- **管理者**: 運営スタッフ10名

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Java 17, Spring Boot 3.2
- フロントエンド: React 18, TypeScript 5.0
- モバイルアプリ: React Native

### データベース
- メインDB: PostgreSQL 15（患者情報、電子カルテ、予約データ）
- キャッシュ: Redis 7（セッション管理、APIレート制限）

### インフラ・デプロイ環境
- クラウド: AWS（Tokyo Region）
- コンテナ: Docker, AWS ECS Fargate
- CDN: AWS CloudFront
- ストレージ: AWS S3（医療画像、検査結果PDF）

### 主要ライブラリ
- JWT認証: jjwt 0.11
- API文書: Swagger/OpenAPI 3.0
- ロギング: SLF4J + Logback

## 3. アーキテクチャ設計

### 全体構成
```
[患者アプリ/Web] -- HTTPS --> [CloudFront + WAF]
                                      |
                                [ALB] -- HTTPS --> [APIゲートウェイ (Spring Boot)]
                                                         |
                                          +---------------+----------------+
                                          |               |                |
                                  [患者サービス]  [カルテサービス]  [予約サービス]
                                          |               |                |
                                          +-------+-------+-------+--------+
                                                  |               |
                                            [PostgreSQL]      [Redis]
```

### 主要コンポーネントの責務
- **APIゲートウェイ**: 認証・認可、リクエストルーティング、共通エラーハンドリング
- **患者サービス**: 患者登録、ログイン、患者情報CRUD
- **カルテサービス**: 電子カルテCRUD、診療履歴管理、処方箋発行
- **予約サービス**: 予約枠管理、予約作成・キャンセル、リマインダー送信

### データフロー
1. 患者がアプリからログイン → JWTトークン発行（有効期限24時間）
2. 診療予約リクエスト → APIゲートウェイが JWT検証 → 予約サービスが予約枠確認・予約作成
3. 電子カルテ閲覧リクエスト → APIゲートウェイが JWT検証 → カルテサービスが該当患者のカルテを返却

## 4. データモデル

### 主要エンティティと関連

#### patients（患者）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| id | BIGINT | PK, AUTO_INCREMENT | 患者ID |
| name | VARCHAR(100) | NOT NULL | 患者氏名 |
| date_of_birth | DATE | NOT NULL | 生年月日 |
| phone | VARCHAR(20) | NOT NULL | 電話番号 |
| email | VARCHAR(255) | NOT NULL | メールアドレス |
| password_hash | VARCHAR(255) | NOT NULL | パスワードハッシュ（bcrypt） |
| created_at | TIMESTAMP | NOT NULL | 登録日時 |

#### medical_records（電子カルテ）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| id | BIGINT | PK, AUTO_INCREMENT | カルテID |
| patient_id | BIGINT | FK(patients.id) | 患者ID |
| doctor_id | BIGINT | FK(doctors.id) | 担当医ID |
| clinic_id | BIGINT | FK(clinics.id) | 医療機関ID |
| diagnosis | TEXT | NOT NULL | 診断内容 |
| prescription | TEXT | NULL | 処方内容 |
| visit_date | DATE | NOT NULL | 受診日 |
| is_shared | BOOLEAN | DEFAULT FALSE | 他院共有フラグ |

#### appointments（予約）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| id | BIGINT | PK, AUTO_INCREMENT | 予約ID |
| patient_id | BIGINT | FK(patients.id) | 患者ID |
| doctor_id | BIGINT | FK(doctors.id) | 担当医ID |
| clinic_id | BIGINT | FK(clinics.id) | 医療機関ID |
| appointment_time | TIMESTAMP | NOT NULL | 予約日時 |
| status | VARCHAR(20) | NOT NULL | ステータス（pending/confirmed/cancelled） |
| created_at | TIMESTAMP | NOT NULL | 予約作成日時 |

#### doctors（医師）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|-----|------|
| id | BIGINT | PK, AUTO_INCREMENT | 医師ID |
| name | VARCHAR(100) | NOT NULL | 医師氏名 |
| clinic_id | BIGINT | FK(clinics.id) | 所属医療機関ID |
| specialty | VARCHAR(100) | NULL | 専門科 |
| license_number | VARCHAR(50) | NOT NULL | 医師免許番号 |

## 5. API設計

### エンドポイント一覧

#### 患者認証
- `POST /api/v1/auth/login` - ログイン
- `POST /api/v1/auth/register` - 新規患者登録
- `POST /api/v1/auth/refresh` - トークンリフレッシュ

#### 患者情報
- `GET /api/v1/patients/{id}` - 患者情報取得
- `PUT /api/v1/patients/{id}` - 患者情報更新

#### 電子カルテ
- `GET /api/v1/medical-records?patient_id={id}` - 電子カルテ一覧取得
- `GET /api/v1/medical-records/{id}` - 電子カルテ詳細取得
- `POST /api/v1/medical-records` - 電子カルテ作成（医師のみ）

#### 予約
- `GET /api/v1/appointments?patient_id={id}` - 予約一覧取得
- `POST /api/v1/appointments` - 予約作成
- `DELETE /api/v1/appointments/{id}` - 予約キャンセル

### リクエスト/レスポンス形式

#### POST /api/v1/auth/login
```json
// Request
{
  "email": "patient@example.com",
  "password": "password123"
}

// Response
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400
}
```

#### GET /api/v1/medical-records/{id}
```json
// Response
{
  "id": 12345,
  "patient_id": 1001,
  "doctor_name": "田中医師",
  "clinic_name": "〇〇クリニック",
  "diagnosis": "急性上気道炎",
  "prescription": "抗生物質（アモキシシリン）500mg 1日3回 5日分",
  "visit_date": "2026-02-05"
}
```

### 認証・認可方式
- **認証**: JWT（JSON Web Token）を使用。ログイン成功時にアクセストークンを発行
- **認可**: 各エンドポイントでロール（patient/doctor/admin）を確認
  - 患者: 自身の情報のみアクセス可能
  - 医師: 担当患者のカルテ作成・編集可能
  - 管理者: 全データへのアクセス可能

## 6. 実装方針

### エラーハンドリング方針
- 4xx系エラー: クライアント側のエラー（バリデーションエラー、認証エラー等）
- 5xx系エラー: サーバー側のエラー（DB接続エラー、内部処理エラー等）
- エラーレスポンス形式:
  ```json
  {
    "error": "INVALID_REQUEST",
    "message": "The patient ID is required.",
    "timestamp": "2026-02-10T12:34:56Z"
  }
  ```

### ロギング方針
- INFO: APIリクエスト/レスポンス、正常系の重要処理
- WARN: リトライ可能なエラー、リソース不足
- ERROR: システムエラー、DB接続エラー
- ログ出力先: CloudWatch Logs

### テスト方針
- 単体テスト: JUnit 5、Mockito使用、カバレッジ80%以上
- 結合テスト: Testcontainersを使用したDB統合テスト
- E2Eテスト: Seleniumによる主要フロー確認

### デプロイメント方針
- Blue-Greenデプロイメント（ECS Fargateのタスク入れ替え）
- デプロイ前: ステージング環境で結合テスト実行
- ロールバック: 前バージョンのタスク定義に戻す

## 7. 非機能要件

### パフォーマンス目標
- APIレスポンスタイム: 平均200ms以下（95パーセンタイル500ms以下）
- 同時接続数: 10,000セッション
- データベース: 読み取りレプリカ2台でロードバランシング

### セキュリティ要件
- 通信: 全通信HTTPS（TLS 1.2以上）
- データ暗号化: DB内の機密情報（診断内容、処方箋）はAES-256で暗号化
- パスワード: bcryptでハッシュ化（コストファクタ12）
- APIレート制限: 1分間に60リクエスト/ユーザー

### 可用性・スケーラビリティ
- 可用性: 99.9%（年間ダウンタイム8.76時間以内）
- スケーラビリティ: ECS Fargateのオートスケーリング（CPU使用率70%でスケールアウト）
- バックアップ: PostgreSQLの自動バックアップ（日次、30日間保持）
