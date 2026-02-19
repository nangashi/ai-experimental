# Real Estate Property Management System 設計書

## 1. 概要

本システムは不動産管理会社向けの物件・契約・賃料管理システムである。複数のオーナーから預かる物件を管理し、入居者との賃貸契約締結、家賃の請求・入金管理、オーナーへの送金処理を一元管理する。

### 主要機能
- 物件情報管理（住所、間取り、設備、契約条件）
- 入居者・オーナー情報管理
- 賃貸契約管理（契約締結、更新、解約）
- 家賃請求・入金管理
- オーナー送金処理
- 契約書類のPDF生成・保管

### 対象ユーザー
- 不動産管理会社の担当者（物件管理、契約事務、経理担当）
- オーナー（物件オーナー、収支レポート閲覧のみ）

## 2. 技術スタック

### 言語・フレームワーク
- バックエンド: Java 17, Spring Boot 3.2
- フロントエンド: TypeScript 5.0, React 18

### データベース
- PostgreSQL 15

### インフラ・デプロイ環境
- AWS (ECS Fargate, RDS, S3, CloudFront)
- Terraform によるインフラ管理
- GitHub Actions による CI/CD

### 主要ライブラリ
- ORM: Spring Data JPA (Hibernate)
- HTTP通信: Apache HttpClient 5.2
- PDF生成: iText 7
- 認証: Spring Security + JWT

## 3. アーキテクチャ設計

### 全体構成
本システムは3層アーキテクチャを採用する。

```
Controller層 (REST API)
    ↓
Service層 (ビジネスロジック)
    ↓
Repository層 (データアクセス)
```

### 主要コンポーネント

#### Controller層
- PropertyController: 物件管理API
- TenantController: 入居者管理API
- ContractController: 契約管理API
- PaymentController: 家賃請求・入金管理API
- OwnerController: オーナー管理・レポート参照API

#### Service層
- PropertyService: 物件ビジネスロジック
- TenantService: 入居者ビジネスロジック
- ContractService: 契約処理（契約締結、更新、解約）
- PaymentService: 家賃計算・請求・入金処理
- RemittanceService: オーナー送金処理
- DocumentService: 契約書PDF生成・S3保管

#### Repository層
- PropertyRepository
- TenantRepository
- ContractRepository
- PaymentRepository
- OwnerRepository
- RemittanceRepository

### データフロー
1. Controller が HTTP リクエストを受信
2. Service が Repository を呼び出しデータ取得・更新
3. Service がビジネスロジックを実行
4. Service がトランザクション境界を管理
5. Controller がレスポンスを返却

## 4. データモデル

### Properties（物件）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| property_id | UUID | PK | 物件ID |
| owner_id | UUID | FK (owners) | オーナーID |
| address | VARCHAR(500) | NOT NULL | 住所 |
| building_name | VARCHAR(200) | NULL | 建物名 |
| room_number | VARCHAR(50) | NULL | 部屋番号 |
| floor_plan | VARCHAR(100) | NOT NULL | 間取り (1K, 2LDK等) |
| area_sqm | DECIMAL(6,2) | NOT NULL | 専有面積（㎡） |
| monthly_rent | DECIMAL(10,0) | NOT NULL | 月額賃料（円） |
| management_fee | DECIMAL(10,0) | NULL | 管理費（円） |
| deposit | DECIMAL(10,0) | NULL | 敷金（円） |
| key_money | DECIMAL(10,0) | NULL | 礼金（円） |
| status | VARCHAR(20) | NOT NULL | 状態 (vacant, occupied, maintenance) |
| created | TIMESTAMP | NOT NULL | 作成日時 |
| updated | TIMESTAMP | NOT NULL | 更新日時 |

### Tenants（入居者）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| tenant_id | UUID | PK | 入居者ID |
| full_name | VARCHAR(200) | NOT NULL | 氏名 |
| full_name_kana | VARCHAR(200) | NOT NULL | カナ氏名 |
| phone_number | VARCHAR(20) | NOT NULL | 電話番号 |
| email | VARCHAR(255) | NOT NULL | メールアドレス |
| emergency_contact_name | VARCHAR(200) | NOT NULL | 緊急連絡先氏名 |
| emergency_contact_phone | VARCHAR(20) | NOT NULL | 緊急連絡先電話 |
| date_of_birth | DATE | NOT NULL | 生年月日 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

### Contracts（契約）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| id | UUID | PK | 契約ID |
| PropertyID | UUID | FK (properties) | 物件ID |
| TenantID | UUID | FK (tenants) | 入居者ID |
| contract_start_date | DATE | NOT NULL | 契約開始日 |
| contract_end_date | DATE | NOT NULL | 契約終了日 |
| monthly_rent_amount | DECIMAL(10,0) | NOT NULL | 月額賃料 |
| payment_due_day | INTEGER | NOT NULL | 支払期日（毎月X日） |
| contract_status | VARCHAR(20) | NOT NULL | 契約状態 (active, expired, terminated) |
| contract_pdf_path | VARCHAR(500) | NULL | 契約書PDFパス（S3） |
| created_timestamp | TIMESTAMP | NOT NULL | 作成日時 |
| modified_timestamp | TIMESTAMP | NOT NULL | 更新日時 |

### Payments（支払）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| payment_id | UUID | PK | 支払ID |
| contract_fk | UUID | FK (contracts) | 契約ID |
| billing_year_month | VARCHAR(7) | NOT NULL | 請求年月 (YYYY-MM) |
| billing_amount | DECIMAL(10,0) | NOT NULL | 請求金額 |
| paid_amount | DECIMAL(10,0) | NULL | 入金金額 |
| payment_date | DATE | NULL | 入金日 |
| payment_status | VARCHAR(20) | NOT NULL | 支払状態 (pending, paid, overdue) |
| created | TIMESTAMP | NOT NULL | 作成日時 |
| updated | TIMESTAMP | NOT NULL | 更新日時 |

### Owners（オーナー）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| owner_id | UUID | PK | オーナーID |
| owner_name | VARCHAR(200) | NOT NULL | 氏名 |
| owner_name_kana | VARCHAR(200) | NOT NULL | カナ氏名 |
| phone_number | VARCHAR(20) | NOT NULL | 電話番号 |
| email | VARCHAR(255) | NOT NULL | メールアドレス |
| bank_name | VARCHAR(100) | NOT NULL | 銀行名 |
| branch_name | VARCHAR(100) | NOT NULL | 支店名 |
| account_number | VARCHAR(20) | NOT NULL | 口座番号 |
| account_holder | VARCHAR(200) | NOT NULL | 口座名義 |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

### Remittances（送金）
| カラム名 | 型 | 制約 | 説明 |
|---------|-----|------|------|
| remittance_id | UUID | PK | 送金ID |
| owner_fk | UUID | FK (owners) | オーナーID |
| remittance_year_month | VARCHAR(7) | NOT NULL | 送金年月 (YYYY-MM) |
| total_rent_received | DECIMAL(10,0) | NOT NULL | 受領家賃合計 |
| management_commission | DECIMAL(10,0) | NOT NULL | 管理手数料 |
| remittance_amount | DECIMAL(10,0) | NOT NULL | 送金金額 |
| remittance_date | DATE | NOT NULL | 送金日 |
| remittance_status | VARCHAR(20) | NOT NULL | 送金状態 (scheduled, completed, failed) |
| created_at | TIMESTAMP | NOT NULL | 作成日時 |
| updated_at | TIMESTAMP | NOT NULL | 更新日時 |

## 5. API設計

### エンドポイント一覧

#### 物件管理
- `GET /api/v1/properties` - 物件一覧取得
- `GET /api/v1/properties/{id}` - 物件詳細取得
- `POST /api/v1/properties/create` - 物件登録
- `PUT /api/v1/properties/{id}/update` - 物件更新
- `DELETE /api/v1/properties/{id}` - 物件削除

#### 入居者管理
- `GET /api/v1/tenants` - 入居者一覧取得
- `GET /api/v1/tenants/{id}` - 入居者詳細取得
- `POST /api/v1/tenants` - 入居者登録
- `PUT /api/v1/tenants/{id}` - 入居者更新

#### 契約管理
- `GET /api/v1/contracts` - 契約一覧取得
- `GET /api/v1/contracts/{id}` - 契約詳細取得
- `POST /api/v1/contracts` - 契約登録
- `PUT /api/v1/contracts/{id}` - 契約更新
- `POST /api/v1/contracts/{id}/terminate` - 契約解約

#### 支払管理
- `GET /api/v1/payments` - 支払一覧取得
- `GET /api/v1/payments/{id}` - 支払詳細取得
- `POST /api/v1/payments` - 支払記録作成
- `PUT /api/v1/payments/{id}/record-payment` - 入金記録

#### オーナー管理
- `GET /api/v1/owners` - オーナー一覧取得
- `GET /api/v1/owners/{id}` - オーナー詳細取得
- `POST /api/v1/owners` - オーナー登録
- `PUT /api/v1/owners/{id}` - オーナー更新

#### 送金管理
- `GET /api/v1/remittances` - 送金一覧取得
- `POST /api/v1/remittances` - 送金実行

### レスポンス形式
全APIは以下の統一フォーマットで返却する。

成功時:
```json
{
  "data": { ... },
  "status": "success",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

エラー時:
```json
{
  "error": {
    "code": "PROPERTY_NOT_FOUND",
    "message": "指定された物件が見つかりません"
  },
  "status": "error",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### 認証・認可方式
- JWT（JSON Web Token）による認証
- トークン有効期限: 24時間
- リフレッシュトークン有効期限: 30日
- JWTトークンは `Authorization: Bearer {token}` ヘッダーで送信
- セッション管理はステートレス（サーバー側でセッション情報を保持しない）

## 6. 実装方針

### トランザクション管理
- Service層メソッドに `@Transactional` を付与
- デフォルト伝播レベル: `REQUIRED`
- 読み取り専用メソッドには `@Transactional(readOnly = true)` を指定
- 複数エンティティの更新を含む処理は1つのServiceメソッド内でトランザクション境界を管理

### ロギング方針
各層で以下のログレベルを使用:
- ERROR: システムエラー（例外のスタックトレース含む）
- WARN: ビジネスルール違反、データ不整合の検出
- INFO: API呼び出しの開始・終了、重要な処理の実行
- DEBUG: SQL実行内容、詳細な処理フロー

ログ形式は構造化JSON形式で出力し、CloudWatch Logsに集約する。

```json
{
  "timestamp": "2024-01-15T10:30:00.123Z",
  "level": "INFO",
  "logger": "com.example.realestate.service.ContractService",
  "message": "Contract created successfully",
  "context": {
    "contractId": "123e4567-e89b-12d3-a456-426614174000",
    "tenantId": "123e4567-e89b-12d3-a456-426614174001",
    "propertyId": "123e4567-e89b-12d3-a456-426614174002"
  }
}
```

### テスト方針
- 単体テスト: JUnit 5 + Mockito
- 統合テスト: Spring Boot Test + Testcontainers（PostgreSQL）
- E2Eテスト: Playwright（フロントエンド）
- カバレッジ目標: 行カバレッジ80%以上

### デプロイメント方針
- Blue-Green デプロイ方式
- デプロイ前に統合テストを自動実行
- カナリアリリース: 新バージョンを10%のトラフィックで先行公開

## 7. 非機能要件

### パフォーマンス目標
- API応答時間: 95パーセンタイルで500ms以内
- 同時接続ユーザー数: 100名以上
- データベースコネクションプール: 最小10、最大50

### セキュリティ要件
- HTTPS通信の必須化
- SQLインジェクション対策: Prepared Statementの使用
- XSS対策: 出力時のエスケープ処理
- CSRF対策: SameSite Cookie属性の設定
- パスワードは bcrypt でハッシュ化（ストレッチング回数: 12）
- 個人情報（氏名、電話番号、メールアドレス、口座情報）は暗号化して保存

### 可用性・スケーラビリティ
- 目標稼働率: 99.5%
- RDSマルチAZ構成
- ECS Fargateオートスケーリング（CPU使用率70%でスケールアウト）
- S3バケットのバージョニング有効化
- 日次バックアップ（PostgreSQL自動バックアップ、保持期間7日）
