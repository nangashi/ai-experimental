# Enterprise HR & Payroll Management System - システム設計書

## 1. 概要

### 1.1 プロジェクトの目的
中小企業向けの統合型HR・給与管理SaaSプラットフォームを構築する。従業員情報管理、勤怠記録、給与計算、人事評価、採用管理を統合し、人事業務の効率化とコンプライアンス対応を実現する。

### 1.2 主要機能
- 従業員マスター管理（個人情報、雇用契約、組織配属）
- 勤怠管理（打刻、休暇申請、承認ワークフロー）
- 給与計算エンジン（月次給与、賞与、源泉徴収、社会保険）
- 人事評価（目標設定、評価フィードバック、査定管理）
- 採用管理（求人票作成、応募者管理、面接評価）
- レポート生成（給与明細、年末調整、労務報告）

### 1.3 対象ユーザー
- 人事担当者：従業員情報の登録・更新、給与計算実行、レポート出力
- 管理職：部下の勤怠承認、評価実施、採用面接評価
- 一般従業員：勤怠打刻、給与明細閲覧、個人情報変更申請
- システム管理者：テナント設定、ユーザー権限管理、監査ログ確認

## 2. 技術スタック

### 2.1 言語・フレームワーク
- **バックエンド**: Java 17 + Spring Boot 3.2, Spring Security 6.2
- **フロントエンド**: React 18 + TypeScript 5.3, Material-UI
- **バッチ処理**: Spring Batch（月次給与計算、年末調整処理）

### 2.2 データベース
- **メインDB**: PostgreSQL 15（トランザクションデータ）
- **キャッシュ**: Redis 7.2（セッション、一時データ）
- **ドキュメントストア**: Amazon S3（給与明細PDF、契約書類）

### 2.3 インフラ・デプロイ環境
- **クラウド**: AWS（ECS Fargate, RDS, S3, CloudWatch）
- **CI/CD**: GitHub Actions
- **監視**: Datadog（APM, ログ集約）

### 2.4 主要ライブラリ
- 認証: Spring Security + JWT
- PDF生成: Apache PDFBox
- 暗号化: Java Cryptography Extension (JCE)
- API通信: RestTemplate, WebClient

## 3. アーキテクチャ設計

### 3.1 全体構成
```
[React SPA] <--HTTPS--> [API Gateway / ALB]
                              |
                        [Spring Boot API]
                        /     |      \
                   [Redis] [PostgreSQL] [S3]
                              |
                        [Batch Worker]
```

- マルチテナント構成：テナントIDによるデータ分離
- レイヤー構成：Controller → Service → Repository → Entity

### 3.2 主要コンポーネント
- **EmployeeService**: 従業員CRUD、権限チェック、部署異動ワークフロー
- **AttendanceService**: 勤怠打刻、休暇申請、承認フロー
- **PayrollService**: 給与計算ロジック、控除計算、明細生成
- **EvaluationService**: 評価シート作成、フィードバック管理
- **RecruitmentService**: 求人管理、応募者情報管理
- **ReportService**: PDF生成、データエクスポート

### 3.3 データフロー
1. ユーザーがブラウザでログイン → JWT発行（有効期限24時間）
2. APIリクエストにJWTを`Authorization: Bearer <token>`ヘッダーで送信
3. APIゲートウェイでJWT検証、テナントID抽出
4. サービス層で業務ロジック実行、権限チェック
5. データベースアクセス（Row-Level SecurityでテナントID自動フィルタ）
6. レスポンス返却（JSON形式）

## 4. データモデル

### 4.1 主要エンティティ

#### employees（従業員マスター）
| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | UUID | PK | |
| tenant_id | UUID | NOT NULL, INDEX | マルチテナント分離キー |
| employee_code | VARCHAR(20) | UNIQUE | 社員番号 |
| full_name | VARCHAR(100) | NOT NULL | |
| email | VARCHAR(255) | NOT NULL, UNIQUE | ログイン用メールアドレス |
| phone_number | VARCHAR(20) | | |
| hire_date | DATE | NOT NULL | |
| department_id | UUID | FK | 所属部署 |
| salary_amount | DECIMAL(12,2) | | 月給（円） |
| bank_account | VARCHAR(50) | | 振込先口座番号 |
| my_number | VARCHAR(12) | | マイナンバー |
| created_at | TIMESTAMP | NOT NULL | |
| updated_at | TIMESTAMP | NOT NULL | |

#### attendance_records（勤怠記録）
| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | UUID | PK | |
| tenant_id | UUID | NOT NULL, INDEX | |
| employee_id | UUID | FK, NOT NULL | |
| record_date | DATE | NOT NULL | |
| clock_in | TIMESTAMP | | 出勤打刻 |
| clock_out | TIMESTAMP | | 退勤打刻 |
| status | VARCHAR(20) | | PRESENT, ABSENT, LEAVE |
| approved_by | UUID | FK | 承認者ID |
| created_at | TIMESTAMP | NOT NULL | |

#### payroll_records（給与記録）
| カラム | 型 | 制約 | 備考 |
|--------|-----|------|------|
| id | UUID | PK | |
| tenant_id | UUID | NOT NULL, INDEX | |
| employee_id | UUID | FK, NOT NULL | |
| payroll_month | DATE | NOT NULL | 給与月（YYYY-MM-01） |
| base_salary | DECIMAL(12,2) | | 基本給 |
| overtime_pay | DECIMAL(12,2) | | 残業手当 |
| deductions | DECIMAL(12,2) | | 控除額 |
| net_pay | DECIMAL(12,2) | | 手取り額 |
| calculated_by | UUID | FK | 計算実行者 |
| calculated_at | TIMESTAMP | | |
| status | VARCHAR(20) | | DRAFT, APPROVED, PAID |

### 4.2 関連図
- employees 1 --- N attendance_records
- employees 1 --- N payroll_records
- employees N --- 1 departments

## 5. API設計

### 5.1 認証・認可エンドポイント

#### POST /api/auth/login
- **リクエスト**:
  ```json
  {
    "email": "user@example.com",
    "password": "password123"
  }
  ```
- **レスポンス**:
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expiresIn": 86400,
    "user": {
      "id": "uuid",
      "name": "山田太郎",
      "role": "HR_MANAGER"
    }
  }
  ```

#### POST /api/auth/refresh
- **リクエスト**: `Authorization: Bearer <token>`
- **レスポンス**: 新しいJWTトークン

### 5.2 従業員管理エンドポイント

#### GET /api/employees
- **認証**: 必須
- **権限**: HR_MANAGER, ADMIN
- **クエリパラメータ**:
  - `page`: ページ番号（デフォルト: 0）
  - `size`: 1ページあたりの件数（デフォルト: 20）
  - `department_id`: 部署IDでフィルタ（オプション）
- **レスポンス**:
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "employee_code": "E001",
        "full_name": "山田太郎",
        "email": "yamada@example.com",
        "department_name": "営業部",
        "hire_date": "2020-04-01"
      }
    ],
    "total": 150,
    "page": 0,
    "size": 20
  }
  ```

#### POST /api/employees
- **認証**: 必須
- **権限**: HR_MANAGER, ADMIN
- **リクエスト**:
  ```json
  {
    "employee_code": "E100",
    "full_name": "鈴木花子",
    "email": "suzuki@example.com",
    "phone_number": "090-1234-5678",
    "hire_date": "2024-04-01",
    "department_id": "dept-uuid",
    "salary_amount": 350000,
    "bank_account": "1234567",
    "my_number": "123456789012"
  }
  ```
- **レスポンス**: 作成された従業員オブジェクト（201 Created）

#### PUT /api/employees/{id}
- **認証**: 必須
- **権限**: HR_MANAGER, ADMIN（本人は個人情報の一部のみ更新可能）
- **リクエスト**: 更新フィールドを含むJSON
- **レスポンス**: 更新された従業員オブジェクト（200 OK）

#### DELETE /api/employees/{id}
- **認証**: 必須
- **権限**: ADMIN
- **レスポンス**: 204 No Content

### 5.3 給与管理エンドポイント

#### POST /api/payroll/calculate
- **認証**: 必須
- **権限**: HR_MANAGER, ADMIN
- **リクエスト**:
  ```json
  {
    "payroll_month": "2024-12-01",
    "employee_ids": ["uuid1", "uuid2"]
  }
  ```
- **レスポンス**: 計算ジョブID（非同期処理）

#### GET /api/payroll/{employee_id}/{month}
- **認証**: 必須
- **権限**: HR_MANAGER, ADMIN（本人は自分の給与明細のみ閲覧可能）
- **レスポンス**: 給与明細データ

### 5.4 勤怠管理エンドポイント

#### POST /api/attendance/clock-in
- **認証**: 必須
- **権限**: すべてのユーザー
- **リクエスト**:
  ```json
  {
    "employee_id": "uuid",
    "timestamp": "2024-12-10T09:00:00Z",
    "location": "本社"
  }
  ```
- **レスポンス**: 勤怠記録ID

#### POST /api/attendance/clock-out
- 同様の構造

## 6. 実装方針

### 6.1 認証・認可方式
- Spring Securityの`@PreAuthorize`アノテーションで権限チェック
- JWTにテナントID、ユーザーID、ロールを含める
- トークンの署名アルゴリズム: HMAC-SHA256（共通鍵方式）
- リフレッシュトークンは発行せず、期限切れ時は再ログインを要求

### 6.2 エラーハンドリング方針
- `@ControllerAdvice`で例外を集約ハンドリング
- エラーレスポンス形式:
  ```json
  {
    "error": "VALIDATION_ERROR",
    "message": "Invalid employee code format",
    "timestamp": "2024-12-10T10:30:00Z"
  }
  ```
- 4xx: クライアント起因エラー、5xx: サーバー内部エラー
- データベースエラーはスタックトレースを含めてログ出力

### 6.3 ロギング方針
- ログレベル: INFO（通常操作）、WARN（リトライ可能エラー）、ERROR（障害）
- 個人情報（氏名、メール、給与額）はログに出力する
- ログ形式: JSON形式でDatadogに送信
- 監査ログ: 認証イベント、権限エラー、給与計算実行、従業員情報更新をすべて記録

### 6.4 テスト方針
- 単体テスト: JUnit 5 + Mockito（カバレッジ目標: 80%）
- 統合テスト: TestContainersでPostgreSQL起動、APIエンドポイントテスト
- E2Eテスト: Selenium（主要ユーザーフローのみ）

### 6.5 デプロイメント方針
- ブルーグリーンデプロイメント（ダウンタイムゼロ）
- データベースマイグレーション: Flyway（起動時に自動実行）
- 環境変数で設定管理（データベース接続文字列、JWT署名鍵、S3バケット名）
- 秘密情報（JWT署名鍵、データベースパスワード）は環境変数に平文で設定

## 7. 非機能要件

### 7.1 パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- 給与計算バッチ: 1000人規模で30分以内
- 同時接続ユーザー: 500ユーザー

### 7.2 セキュリティ要件
- 通信は全てHTTPSで暗号化
- パスワードはbcryptでハッシュ化（work factor 10）
- マイナンバー・口座番号はデータベースに保存（暗号化なし）
- 定期的な脆弱性スキャン（月次）

### 7.3 可用性・スケーラビリティ
- SLA: 99.5%（月間ダウンタイム約3.6時間）
- データベースバックアップ: 日次フルバックアップ
- オートスケーリング: CPU使用率70%でスケールアウト
- 災害復旧目標（RTO）: 4時間、RPO: 24時間
