# オンライン診療予約システム 設計書

## 1. 概要

### プロジェクトの目的と背景
地域医療機関のDX推進の一環として、患者が医療機関の診察予約・問診票入力・診察券発行をオンラインで行えるシステムを構築する。従来の電話予約からの脱却により、医療機関の業務効率化と患者の利便性向上を実現する。

### 主要機能
- 患者登録・ログイン機能
- 医療機関検索・診療科目選択機能
- 予約枠検索・予約登録機能
- 問診票のオンライン記入機能
- 予約確認・キャンセル機能
- 医療機関側の予約管理・患者情報閲覧機能

### 対象ユーザー
- **患者**: スマートフォンまたはPCから診察予約を行う一般利用者
- **医療機関スタッフ**: 予約状況の確認・患者情報の閲覧を行う受付担当者
- **医師**: 問診票の事前確認を行う診察担当医

## 2. 技術スタック

### 言語・フレームワーク
- **Backend**: Java 17, Spring Boot 3.2
- **Frontend**: TypeScript, React 18, Vite

### データベース
- **Primary DB**: PostgreSQL 15
- **Cache**: Redis 7

### インフラ・デプロイ環境
- **クラウド**: AWS (ECS Fargate, RDS, ElastiCache)
- **CI/CD**: GitHub Actions
- **監視**: CloudWatch, Datadog

### 主要ライブラリ
- **HTTP Client**: RestTemplate
- **ORM**: Spring Data JPA
- **認証**: Spring Security, JWT
- **バリデーション**: Jakarta Validation
- **API Documentation**: SpringDoc OpenAPI

## 3. アーキテクチャ設計

### 全体構成
本システムは3層アーキテクチャを採用する。

```
Presentation Layer (Controller)
    ↓
Business Logic Layer (Service)
    ↓
Data Access Layer (Repository)
```

### 主要コンポーネントの責務

#### Presentation Layer
- **PatientController**: 患者情報のCRUD、ログイン/ログアウト処理
- **AppointmentController**: 予約情報のCRUD、予約枠検索、キャンセル処理
- **MedicalInstitutionController**: 医療機関情報の検索、診療科目一覧取得
- **QuestionnaireController**: 問診票のCRUD

#### Business Logic Layer
- **PatientService**: 患者登録、認証処理、プロフィール更新
- **AppointmentService**: 予約作成、キャンセル、リマインダー送信
- **MedicalInstitutionService**: 医療機関検索、診療科目管理
- **QuestionnaireService**: 問診票テンプレート管理、回答保存

#### Data Access Layer
- **PatientRepository**: 患者データのCRUD
- **AppointmentRepository**: 予約データのCRUD
- **MedicalInstitutionRepository**: 医療機関データのCRUD
- **QuestionnaireRepository**: 問診票データのCRUD

### データフロー
1. ユーザーがフロントエンドから予約リクエストを送信
2. Controllerがリクエストを受け取り、バリデーション実施
3. Serviceが業務ロジック（予約枠の空き確認、二重予約チェック等）を実行
4. Repositoryがデータベースへの永続化を実施
5. レスポンスをフロントエンドに返却

## 4. データモデル

### 主要エンティティ

#### Patients（患者）
```
id (BIGINT, PRIMARY KEY)
family_name (VARCHAR(100))
given_name (VARCHAR(100))
family_name_kana (VARCHAR(100))
given_name_kana (VARCHAR(100))
date_of_birth (DATE)
gender (VARCHAR(10))
email (VARCHAR(255), UNIQUE)
phone_number (VARCHAR(20))
postal_code (VARCHAR(10))
address (TEXT)
password_hash (VARCHAR(255))
created_at (TIMESTAMP)
updated_at (TIMESTAMP)
```

#### medical_institutions（医療機関）
```
id (BIGINT, PRIMARY KEY)
name (VARCHAR(200))
postal_code (VARCHAR(10))
address (TEXT)
phone_number (VARCHAR(20))
departments (TEXT[])
business_hours (JSONB)
created_at (TIMESTAMP)
updated_at (TIMESTAMP)
```

#### appointment（予約）
```
id (BIGINT, PRIMARY KEY)
patient_id (BIGINT, FOREIGN KEY -> Patients.id)
medical_institution_id (BIGINT, FOREIGN KEY -> medical_institutions.id)
department (VARCHAR(100))
doctor_id (BIGINT)
appointment_date (DATE)
appointment_time (TIME)
status (VARCHAR(20))
questionnaire_id (BIGINT, FOREIGN KEY -> Questionnaires.id)
created_at (TIMESTAMP)
updated_at (TIMESTAMP)
cancelled_at (TIMESTAMP)
```

#### Questionnaires（問診票）
```
id (BIGINT, PRIMARY KEY)
appointment_id (BIGINT, FOREIGN KEY -> appointment.id)
chief_complaint (TEXT)
symptoms (TEXT)
medical_history (TEXT)
allergies (TEXT)
current_medications (TEXT)
created_at (TIMESTAMP)
updated_at (TIMESTAMP)
```

## 5. API設計

### エンドポイント一覧

#### 患者関連
- `POST /api/v1/patients/register` - 患者新規登録
- `POST /api/v1/patients/login` - ログイン
- `GET /api/v1/patients/{id}` - 患者情報取得
- `PUT /api/v1/patients/{id}` - 患者情報更新

#### 予約関連
- `POST /api/v1/appointments` - 予約作成
- `GET /api/v1/appointments/{id}` - 予約詳細取得
- `GET /api/v1/appointments/search` - 予約枠検索
- `PUT /api/v1/appointments/{id}/cancel` - 予約キャンセル

#### 医療機関関連
- `GET /api/v1/medical-institutions` - 医療機関一覧取得
- `GET /api/v1/medical-institutions/{id}` - 医療機関詳細取得

#### 問診票関連
- `POST /api/v1/questionnaires` - 問診票作成
- `GET /api/v1/questionnaires/{id}` - 問診票取得
- `PUT /api/v1/questionnaires/{id}` - 問診票更新

### リクエスト/レスポンス形式

#### 予約作成リクエスト例
```json
{
  "patientId": 12345,
  "medicalInstitutionId": 678,
  "department": "内科",
  "appointmentDate": "2026-03-15",
  "appointmentTime": "14:00"
}
```

#### レスポンス形式
成功時:
```json
{
  "success": true,
  "data": {
    "id": 9876,
    "status": "confirmed",
    "appointmentDate": "2026-03-15",
    "appointmentTime": "14:00"
  }
}
```

エラー時:
```json
{
  "success": false,
  "errorMessage": "The selected time slot is not available"
}
```

### 認証・認可方式
- JWT (JSON Web Token) による認証を実装
- アクセストークンの有効期限は30分、リフレッシュトークンは7日間
- トークンはHTTP-only Cookieに保存
- 全APIエンドポイントで認証必須（ログイン・登録を除く）

## 6. 実装方針

### エラーハンドリング方針
各Controllerでtry-catchを実装し、業務エラー・システムエラーを個別にハンドリングする。業務エラーは400系、システムエラーは500系のステータスコードで返却する。

### ロギング方針
アプリケーションログはJSON形式で出力し、CloudWatch Logsに集約する。ログレベルはDEBUG、INFO、WARN、ERRORの4段階とする。個人情報（氏名、生年月日、電話番号等）はマスキング処理を施してログに記録する。

### テスト方針
- 単体テスト: JUnit 5 + Mockito によるService層のテスト
- 結合テスト: Spring Boot Test による Controller〜Repository の結合テスト
- E2Eテスト: Playwright による主要ユーザーシナリオのテスト

### デプロイメント方針
GitHub ActionsでCI/CDパイプラインを構築し、mainブランチへのマージをトリガーにECS Fargateへ自動デプロイを実行する。Blue/Greenデプロイメントにより無停止での切り替えを実現する。

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- データベースクエリ: 複雑な検索クエリでも1秒以内
- 同時接続数: 最大1000ユーザーの同時アクセスに対応

### セキュリティ要件
- 通信は全てHTTPSで暗号化
- パスワードはbcryptでハッシュ化して保存
- CSRF対策としてトークン検証を実装
- SQLインジェクション対策としてJPAのParameterized Queryを使用

### 可用性・スケーラビリティ
- SLA: 99.9%の稼働率を目標
- ECS Fargateのオートスケーリングにより負荷に応じてタスク数を自動調整
- RDS Multi-AZ構成により障害時の自動フェイルオーバーを実現
- 定期的なバックアップ（日次フルバックアップ + トランザクションログの継続バックアップ）
