# Healthcare Appointment Scheduling System 設計書

## 1. 概要

### 1.1 プロジェクトの目的と背景
複数の医療機関（クリニック、病院）の予約を統合的に管理するプラットフォームを構築する。患者は複数の医療機関の空き状況を一括で確認し、オンライン予約を完了できる。医療機関側は予約管理、患者情報管理、診療スケジュール管理を行う。

### 1.2 主要機能
- 患者向け機能: 医療機関検索、空き枠確認、予約作成・変更・キャンセル、診療履歴参照
- 医療機関向け機能: スケジュール管理、予約確認・承認、患者情報管理、診療記録入力
- 管理者向け機能: 医療機関登録・管理、システム設定、統計レポート

### 1.3 対象ユーザーと利用シナリオ
- **患者**: スマホアプリまたはWebブラウザから予約を検索・作成
- **医療機関スタッフ**: Web管理画面から予約状況を確認し、診療記録を入力
- **システム管理者**: 医療機関のアカウント管理、システム設定変更

## 2. 技術スタック

### 2.1 言語・フレームワーク
- バックエンド: Java 17, Spring Boot 3.2
- フロントエンド: TypeScript, React 18
- モバイルアプリ: React Native

### 2.2 データベース
- メインDB: PostgreSQL 15
- キャッシュ: Redis 7

### 2.3 インフラ・デプロイ環境
- クラウド: AWS (ECS Fargate, RDS, ElastiCache, CloudFront)
- CI/CD: GitHub Actions
- コンテナ: Docker

### 2.4 主要ライブラリ
- 認証: Spring Security, JWT
- HTTP通信: Spring WebFlux (WebClient)
- ORM: Spring Data JPA (Hibernate)
- バリデーション: Jakarta Bean Validation
- ログ: SLF4J + Logback

## 3. アーキテクチャ設計

### 3.1 全体構成
レイヤー構成:
- Presentation Layer: REST API Controller
- Application Layer: Service, UseCase
- Domain Layer: Entity, Repository Interface
- Infrastructure Layer: Repository Implementation, External API Client

### 3.2 主要コンポーネントの責務と依存関係
- **AppointmentController** (Presentation): 予約関連APIエンドポイント、リクエスト/レスポンス変換
- **AppointmentService** (Application): 予約ビジネスロジック、トランザクション管理
- **AppointmentRepository** (Domain): 予約データアクセスインターフェース
- **Appointment** (Domain): 予約エンティティ、ドメインロジック

依存方向: Presentation → Application → Domain ← Infrastructure

### 3.3 データフロー
1. クライアントがREST APIにリクエスト送信
2. Controllerがリクエストを受信、DTOに変換
3. Serviceがビジネスロジックを実行、Repositoryを呼び出し
4. Repositoryがデータベースアクセス実行
5. Serviceが結果を返却、Controllerが整形してクライアントに返答

## 4. データモデル

### 4.1 主要エンティティと関連
- **Patient**: 患者情報
- **MedicalInstitution**: 医療機関情報
- **Doctor**: 医師情報
- **Appointment**: 予約情報
- **MedicalRecord**: 診療記録

関連:
- Patient - Appointment (1対多)
- MedicalInstitution - Appointment (1対多)
- Doctor - Appointment (1対多)
- Appointment - MedicalRecord (1対1)

### 4.2 テーブル設計

#### PatientAccount テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| patient_id | UUID | PK | 患者ID |
| email_address | VARCHAR(255) | NOT NULL, UNIQUE | メールアドレス |
| full_name | VARCHAR(100) | NOT NULL | 患者氏名 |
| date_of_birth | DATE | NOT NULL | 生年月日 |
| phone_number | VARCHAR(20) | | 電話番号 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

#### medical_institution テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| institution_id | UUID | PK | 医療機関ID |
| institution_name | VARCHAR(200) | NOT NULL | 医療機関名 |
| address | VARCHAR(500) | NOT NULL | 住所 |
| phone | VARCHAR(20) | NOT NULL | 電話番号 |
| business_hours | JSONB | | 営業時間 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

#### appointment テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| appointmentId | UUID | PK | 予約ID |
| patientId | UUID | FK → PatientAccount | 患者ID |
| institutionId | UUID | FK → medical_institution | 医療機関ID |
| doctorId | UUID | FK → doctor | 医師ID |
| appointment_datetime | TIMESTAMP | NOT NULL | 予約日時 |
| status | VARCHAR(20) | NOT NULL | 予約状態 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

#### doctor テーブル
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| doctor_id | UUID | PK | 医師ID |
| institution_id | UUID | FK → medical_institution | 所属医療機関ID |
| name | VARCHAR(100) | NOT NULL | 医師氏名 |
| specialization | VARCHAR(100) | | 専門分野 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |

## 5. API設計

### 5.1 エンドポイント一覧

#### 予約関連API
- `POST /api/appointments/create` - 予約作成
- `GET /api/appointments/{appointmentId}` - 予約詳細取得
- `PUT /api/appointments/{appointmentId}` - 予約更新
- `DELETE /api/appointments/{appointmentId}` - 予約キャンセル
- `GET /api/appointments/patient/{patientId}` - 患者の予約一覧取得

#### 医療機関関連API
- `GET /api/institutions/search` - 医療機関検索
- `GET /api/institutions/{institutionId}` - 医療機関詳細取得
- `GET /api/institutions/{institutionId}/available-slots` - 空き枠一覧取得

#### 患者関連API
- `POST /api/patients` - 患者登録
- `GET /api/patients/{patientId}` - 患者情報取得
- `PUT /api/patients/{patientId}` - 患者情報更新

### 5.2 リクエスト/レスポンス形式
全APIのレスポンス形式は以下の共通構造を使用:

```json
{
  "data": {...},
  "error": null
}
```

エラー時:
```json
{
  "data": null,
  "error": {
    "code": "ERR_001",
    "message": "エラーメッセージ"
  }
}
```

### 5.3 認証・認可方式
- 認証方式: JWT (JSON Web Token)
- トークン配送: Authorization ヘッダー (Bearer スキーム)
- トークン保存: クライアント側でlocalStorageに保存
- セッション管理: ステートレス (JWTのみ)

## 6. 実装方針

### 6.1 エラーハンドリング方針
各ServiceメソッドでビジネスロジックのExceptionをcatchし、適切なエラーメッセージを含むカスタム例外に変換して返却する。Controllerレベルでは個別のtry-catch処理は行わず、例外はそのままthrowする。

### 6.2 ロギング方針
以下の形式でログを出力:
```
[timestamp] [level] [thread] [class] - message
```

各レイヤーでのログ出力:
- Controller: リクエスト受信時とレスポンス返却時にINFOレベル
- Service: ビジネスロジック開始/終了時にDEBUGレベル、エラー発生時にERRORレベル
- Repository: DB操作時にDEBUGレベル

### 6.3 テスト方針
- 単体テスト: JUnit 5, Mockito
- 統合テスト: Spring Boot Test, Testcontainers
- E2Eテスト: Selenium
- カバレッジ目標: 80%以上

### 6.4 デプロイメント方針
- ブランチ戦略: Git Flow
- デプロイ環境: development, staging, production
- デプロイトリガー: mainブランチへのマージ時に自動デプロイ
- ロールバック: 前バージョンのDockerイメージを再デプロイ

## 7. 非機能要件

### 7.1 パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- 同時接続数: 1,000リクエスト/秒
- データベースクエリ: N+1問題の回避、適切なインデックス設定

### 7.2 セキュリティ要件
- 通信: HTTPS必須
- パスワード: bcryptでハッシュ化
- SQLインジェクション対策: Prepared Statementの使用
- XSS対策: 入力値のサニタイズ、出力時のエスケープ
- CSRF対策: CSRF tokenの使用

### 7.3 可用性・スケーラビリティ
- 稼働率: 99.9%以上
- スケーリング: ECS Fargateのオートスケーリング設定
- データバックアップ: 日次バックアップ、7日間保持
- 障害復旧: RTO 4時間以内、RPO 1時間以内
