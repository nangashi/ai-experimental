# 一貫性レビュー結果: Real Estate Property Management System

## Inconsistencies Identified

### Critical: Architectural Patterns and Implementation Approaches

#### P01: データベーステーブルのタイムスタンプカラム命名規則の不統一
**問題内容**: タイムスタンプカラムの命名に3つの異なるパターンが混在している。

- **Pattern A** (1テーブル): `created`, `updated` (properties, paymentsテーブル)
- **Pattern B** (4テーブル): `created_at`, `updated_at` (tenants, owners, remittancesテーブル)
- **Pattern C** (1テーブル): `created_timestamp`, `modified_timestamp` (contractsテーブル)

**支配的パターン**: Pattern B (`created_at`, `updated_at`) が6テーブル中4テーブル (67%) で使用されている。

**影響分析**:
- 開発者が新しいテーブルを作成する際、どのパターンを選択すべきか判断できない
- ORMマッピングコードで異なるカラム名を扱う必要が生じ、コードの可読性が低下
- 監査ログやタイムスタンプベースのクエリで統一的な処理ができない
- **Adversarial Risk**: 将来のテーブル追加時に開発者が好みのパターンを選択し、さらなる断片化を助長する

**推奨事項**: 全テーブルで `created_at`, `updated_at` に統一する。
```sql
-- Properties テーブル
created → created_at
updated → updated_at

-- Payments テーブル
created → created_at
updated → updated_at

-- Contracts テーブル
created_timestamp → created_at
modified_timestamp → updated_at
```

---

#### P02: 外部キーカラムの命名規則の不統一
**問題内容**: 外部キーカラムの命名に3つの異なるパターンが混在している。

- **Pattern A**: snake_case + `_id` 形式 (例: `owner_id` in properties)
- **Pattern B**: PascalCase + `ID` 形式 (例: `PropertyID`, `TenantID` in contracts)
- **Pattern C**: snake_case + `_fk` 形式 (例: `contract_fk`, `owner_fk` in payments/remittances)

**支配的パターン**: Pattern A (snake_case + `_id`) がより一般的なPostgreSQLの慣習。

**影響分析**:
- JOINクエリ作成時に大文字小文字の混在により可読性が低下
- ORM (Hibernate) のマッピング設定で異なる命名規則への対応が必要
- 外部キー制約名の自動生成時に命名規則が不安定になる
- **Adversarial Risk**: PascalCaseの外部キーがJavaエンティティクラスのフィールド名と混同され、DBとアプリケーションレイヤーの境界が曖昧になる

**推奨事項**: 全外部キーを `{参照先テーブル単数形}_id` 形式に統一する。
```sql
-- Contracts テーブル
PropertyID → property_id
TenantID → tenant_id

-- Payments テーブル
contract_fk → contract_id

-- Remittances テーブル
owner_fk → owner_id
```

---

#### P03: 主キーカラムの命名規則の不統一
**問題内容**: 主キーカラムの命名パターンが不統一。

- **Pattern A** (5テーブル): `{table_name}_id` 形式 (例: `property_id`, `tenant_id`, `payment_id`, `owner_id`, `remittance_id`)
- **Pattern B** (1テーブル): 単なる `id` (contractsテーブル)

**支配的パターン**: Pattern A (`{table_name}_id`) が6テーブル中5テーブル (83%) で使用されている。

**影響分析**:
- JOINクエリで複数テーブルのIDを扱う際、曖昧さが生じる
- ORMによる自動JOIN生成時に予期しない動作を引き起こす可能性
- アプリケーションコード内で「どのテーブルのIDか」が不明瞭になる
- **Adversarial Risk**: `id` という汎用的な名前が他のテーブルに波及し、コードベース全体の可読性が低下する

**推奨事項**: contractsテーブルの主キーを `contract_id` に変更する。
```sql
-- Contracts テーブル
id → contract_id
```

---

#### P10: JWT トークン保存場所の未指定
**問題内容**: 設計書に「JWT（JSON Web Token）による認証」および「セッション管理はステートレス」と記載されているが、クライアント側でのトークン保存場所（localStorage / sessionStorage / httpOnly Cookie）が明示されていない。

**影響分析**:
- XSS攻撃への脆弱性が異なる (localStorage/sessionStorageはXSSで窃取可能、httpOnly CookieはJavaScript経由でアクセス不可)
- CSRF対策の必要性が異なる (Cookie使用時はCSRF対策必須)
- 既存システムが httpOnly Cookie + SameSite 属性を使用している場合、localStorage採用は一貫性違反かつセキュリティ低下を招く
- **Adversarial Risk**: 開発者が「簡単に実装できる」localStorageを選択し、セキュリティベストプラクティスから逸脱する

**推奨事項**:
既存システムのトークン保存方式を確認し、設計書に明記する。一般的なベストプラクティスは httpOnly Cookie + SameSite=Strict 属性の使用。
```markdown
### 認証・認可方式
- JWT（JSON Web Token）による認証
- トークン保存: httpOnly Cookie (SameSite=Strict属性)
- トークン有効期限: 24時間
- リフレッシュトークン: httpOnly Cookie (SameSite=Strict属性、有効期限30日)
```

---

### Significant: Naming Conventions and API Design

#### P04: API エンドポイントの命名パターンの不統一
**問題内容**: RESTful設計とRPC風設計が混在している。

**RESTful パターン** (HTTPメソッドで操作を表現):
- `POST /api/v1/tenants` (登録)
- `PUT /api/v1/tenants/{id}` (更新)
- `POST /api/v1/contracts` (登録)

**RPC風パターン** (URLパスに動詞を含む):
- `POST /api/v1/properties/create` (登録)
- `PUT /api/v1/properties/{id}/update` (更新)
- `POST /api/v1/contracts/{id}/terminate` (解約)
- `PUT /api/v1/payments/{id}/record-payment` (入金記録)

**影響分析**:
- API設計の哲学が不明瞭になり、新規エンドポイント追加時に判断が困難
- クライアント側のAPI呼び出しコードで統一的なパターンが適用できない
- OpenAPI仕様書生成時に操作IDの命名規則が不統一になる
- **Adversarial Risk**: 開発者が「わかりやすい」という理由でRPC風を選択し、RESTful原則が形骸化する

**推奨事項**: 基本的にRESTfulパターンを採用し、HTTPメソッドで操作を表現する。特殊な操作（terminate, record-paymentなど）のみパスに動詞を含める。
```markdown
#### 物件管理
- POST /api/v1/properties (登録) ← /create を削除
- PUT /api/v1/properties/{id} (更新) ← /update を削除

#### 契約管理
- POST /api/v1/contracts/{id}/terminate (解約) ← 特殊操作のため許容

#### 支払管理
- PUT /api/v1/payments/{id}/record-payment (入金記録) ← 特殊操作のため許容
  または POST /api/v1/payments/{id}/records (より RESTful)
```

---

#### P05: カラム名の省略形使用における一貫性の欠如
**問題内容**: 一部のカラムで省略形 (`fk`) が使用されている一方、他のカラムでは完全な説明的名前が使用されている。

- 省略形使用: `contract_fk`, `owner_fk`
- 完全名使用: `emergency_contact_name`, `contract_start_date`, `payment_due_day`

**影響分析**:
- カラム名から意図を推測する際の認知負荷が増加
- 新しいカラム追加時に省略すべきか判断が困難
- **Adversarial Risk**: 開発者が「短く書きたい」という理由で独自の省略形を導入し、可読性が低下

**推奨事項**: 外部キーについては P02 の推奨に従い `{参照先}_id` 形式を使用し、`_fk` 省略形を廃止する。一般的なカラムは説明的な名前を優先する。

---

### Moderate: File Placement and Configuration Patterns

#### P06: エラーハンドリングパターンの未指定
**問題内容**: エラーハンドリング方式（グローバルExceptionHandler vs 個別catch）が設計書に明記されていない。

**影響分析**:
- 既存システムが `@ControllerAdvice` によるグローバルエラーハンドリングを採用している場合、個別catchの追加は一貫性違反
- エラーレスポンス形式は統一されている（セクション5参照）が、例外の捕捉・変換ロジックの配置場所が不明
- **Adversarial Risk**: 開発者が各Controllerに個別のtry-catchを追加し、エラーハンドリングロジックが分散する

**推奨事項**: Spring Boot の `@ControllerAdvice` + `@ExceptionHandler` によるグローバルエラーハンドリングパターンを明記する。
```markdown
### エラーハンドリング方針
- `@ControllerAdvice` によるグローバル例外ハンドリングを採用
- ビジネス例外は独自の例外クラス（例: `PropertyNotFoundException`）を定義
- すべての例外は GlobalExceptionHandler で捕捉し、統一フォーマットに変換
```

---

#### P07: 非同期処理パターンの未指定
**問題内容**: PDF生成（DocumentService）や送金処理（RemittanceService）など、時間のかかる可能性のある処理について、同期/非同期の方針が明記されていない。

**影響分析**:
- 既存システムが Spring の `@Async` アノテーションを使用している場合、同期処理の採用は一貫性違反
- API応答時間の目標（500ms以内）に対してPDF生成処理が同期実行される場合、達成困難
- **Adversarial Risk**: 「後で非同期にすればいい」という考えで同期実装が進み、後からの変更が困難になる

**推奨事項**: 時間のかかる処理（PDF生成、送金実行）は非同期処理とし、Spring の `@Async` を使用する方針を明記する。
```markdown
### 非同期処理方針
- PDF生成処理（DocumentService.generateContractPdf）は `@Async` で非同期実行
- 送金実行処理（RemittanceService.executeRemittance）は `@Async` で非同期実行
- 非同期処理結果は DB のステータスカラムで管理（例: contract_pdf_path が NULL の間は生成中）
```

---

#### P08: 設定ファイル形式（YAML vs JSON）の未指定
**問題内容**: Spring Boot の設定ファイル形式（application.yml vs application.properties vs application.json）が明記されていない。

**影響分析**:
- 既存プロジェクトが `application.yml` を使用している場合、`application.properties` の追加は一貫性違反
- 環境別設定ファイル（dev/stg/prod）の命名規則も不明
- **Adversarial Risk**: 開発者が異なる形式の設定ファイルを混在させ、設定の管理が複雑化

**推奨事項**: Spring Boot の標準である `application.yml` を採用し、環境別プロファイルを使用する方針を明記する。
```markdown
### 設定管理方針
- 設定ファイル形式: YAML (`application.yml`)
- 環境別設定: Spring Profiles を使用 (`application-dev.yml`, `application-prod.yml`)
- 環境変数命名規則: UPPER_SNAKE_CASE (例: `DATABASE_URL`, `JWT_SECRET_KEY`)
```

---

#### P09: 環境変数命名規則の未指定
**問題内容**: 環境変数の命名規則が設計書に明記されていない。

**影響分析**:
- 既存システムが `UPPER_SNAKE_CASE`（例: `DATABASE_URL`）を使用している場合、`camelCase`（例: `databaseUrl`）の採用は一貫性違反
- Terraform の変数名と環境変数名の対応関係が不明瞭になる
- **Adversarial Risk**: 開発者が独自の命名規則を導入し、環境変数の管理が困難になる

**推奨事項**: P08 の推奨事項に環境変数命名規則を追加済み（`UPPER_SNAKE_CASE`）。

---

### Minor: Improvements and Positive Alignment

#### A01: 一貫性の高い設計要素（肯定的評価）

以下の要素は優れた一貫性を示している:

1. **テーブル名の命名規則**: 全テーブルが複数形snake_caseで統一されている（properties, tenants, contracts, payments, owners, remittances）
2. **APIバージョニング**: 全エンドポイントが `/api/v1/` プレフィックスで統一
3. **レスポンス形式**: 成功時・エラー時のレスポンス構造が明確に定義され統一されている
4. **トランザクション管理**: Service層での `@Transactional` 使用が明確
5. **ログ形式**: 構造化JSON形式で統一され、CloudWatch Logs への集約方針も明確

これらの一貫性を維持しながら、上記の問題点を修正することを推奨する。

---

## Pattern Evidence

### タイムスタンプカラムパターンの証拠
- **Pattern A** (`created`, `updated`): properties, payments
- **Pattern B** (`created_at`, `updated_at`): tenants, owners, remittances (4テーブル)
- **Pattern C** (`created_timestamp`, `modified_timestamp`): contracts

支配的パターンはPattern B（67%の採用率）。PostgreSQLおよびRailsコミュニティの標準慣習とも一致。

### 外部キーカラムパターンの証拠
- **snake_case + _id**: properties.owner_id
- **PascalCase + ID**: contracts.PropertyID, contracts.TenantID
- **snake_case + _fk**: payments.contract_fk, remittances.owner_fk

PostgreSQL推奨はsnake_case。PascalCaseは一般的でない。

### APIエンドポイントパターンの証拠
- **RESTful**: POST /api/v1/tenants, PUT /api/v1/tenants/{id}, POST /api/v1/contracts
- **RPC風**: POST /api/v1/properties/create, PUT /api/v1/properties/{id}/update

混在しており、統一された設計哲学が不明瞭。

---

## Impact Analysis

### Critical 問題の影響

**P01, P02, P03（DB命名規則不統一）の統合的影響**:
- ORMマッピングの複雑化により、開発速度が低下
- SQLクエリの可読性低下により、バグ混入リスクが増加
- 新規テーブル追加時に開発者ごとに異なるパターンを選択し、さらなる断片化を招く
- **長期的リスク**: データベーススキーマの全体的な整合性が失われ、大規模リファクタリングが必要になる

**P10（JWT保存場所未指定）の影響**:
- XSS攻撃によるトークン窃取の脆弱性が残る可能性
- 既存システムとセキュリティレベルの不整合が発生
- CSRF対策の要否が不明確になり、脆弱性が混入するリスク

### Significant 問題の影響

**P04（APIパターン不統一）の影響**:
- フロントエンド開発者がAPI呼び出しロジックを統一的に実装できない
- OpenAPI仕様書の自動生成が困難
- 新規API追加時に設計判断が属人化

**P06, P07（実装パターン未指定）の影響**:
- コードレビュー時に「正しい実装」の判断基準が不明瞭
- パフォーマンス目標（500ms以内）の達成可能性が不明
- 後からの変更コストが増大

---

## Recommendations

### 優先度1: Critical問題の解決

1. **P01, P02, P03 の統合修正**: データベーススキーマの命名規則を全面的に統一
   - タイムスタンプ: `created_at`, `updated_at`
   - 外部キー: `{参照先単数形}_id`
   - 主キー: `{テーブル名単数形}_id`

2. **P10 の解決**: JWT保存方式を明記
   - 推奨: httpOnly Cookie + SameSite=Strict 属性
   - 既存システムの実装を確認し、整合性を確保

### 優先度2: Significant問題の解決

3. **P04 の解決**: API設計哲学を統一
   - 基本はRESTfulパターン（HTTPメソッドで操作表現）
   - 特殊操作のみパスに動詞を含める明確な基準を設定

4. **P06, P07 の解決**: 実装パターンを明文化
   - エラーハンドリング: `@ControllerAdvice` 採用
   - 非同期処理: PDF生成・送金処理で `@Async` 使用

### 優先度3: Moderate問題の解決

5. **P08, P09 の解決**: 設定管理規約を明記
   - 設定ファイル: `application.yml`
   - 環境変数: `UPPER_SNAKE_CASE`

### 修正後の再確認事項

- データベースマイグレーションスクリプトの作成（命名規則変更）
- 既存のORMエンティティクラスの修正
- API仕様書（OpenAPI）の更新
- フロントエンドのAPI呼び出しコードへの影響確認
