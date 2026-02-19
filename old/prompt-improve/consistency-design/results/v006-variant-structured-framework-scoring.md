# 採点結果: v006-variant-structured-framework

## 採点サマリ

- **Run1スコア**: 8.0 (検出8.0 + bonus0 - penalty0)
- **Run2スコア**: 10.0 (検出10.0 + bonus0 - penalty0)
- **平均スコア**: 9.0
- **標準偏差**: 1.0
- **安定性判定**: 中安定 (0.5 < SD ≤ 1.0)

---

## 検出マトリクス

| 問題ID | 問題概要 | Run1判定 | Run2判定 | スコア(Run1) | スコア(Run2) |
|--------|---------|---------|---------|------------|------------|
| P01 | テーブル命名規則の混在（snake_case と camelCase） | ○ | ○ | 1.0 | 1.0 |
| P02 | 外部キーカラム命名の不統一 | ○ | ○ | 1.0 | 1.0 |
| P03 | API命名規則の情報欠落 | × | ○ | 0.0 | 1.0 |
| P04 | APIレスポンス形式の既存パターンとの不一致 | × | ○ | 0.0 | 1.0 |
| P05 | エラーハンドリングパターンの既存パターンとの不一致 | ○ | ○ | 1.0 | 1.0 |
| P06 | ロギング形式の既存パターンとの不一致 | ○ | ○ | 1.0 | 1.0 |
| P07 | API動詞使用パターンの既存との不一致 | ○ | ○ | 1.0 | 1.0 |
| P08 | トランザクション管理パターンの情報欠落 | ○ | ○ | 1.0 | 1.0 |
| P09 | ディレクトリ構造・ファイル配置方針の情報欠落 | ○ | ○ | 1.0 | 1.0 |
| P10 | JWTトークン保存先の既存パターンとの不一致 | ○ | ○ | 1.0 | 1.0 |

**合計検出スコア**: Run1=8.0, Run2=10.0

---

## 検出詳細

### P01: テーブル命名規則の混在（snake_case と camelCase）
**検出判定基準**: `appointment`テーブルの`appointmentId`カラムが既存のsnake_case命名規則と異なることを指摘し、`appointment_id`への統一を推奨している

**Run1: ○ (1.0点)**
- **該当箇所**: Issue 1: Mixed Case Styles in Primary Key Columns (P01)
- **検出内容**:
  - "`appointment.appointmentId` uses camelCase while all other tables use snake_case (`patient_id`, `institution_id`, `doctor_id`)"
  - "Change `appointmentId` to `appointment_id` to align with established snake_case convention."
- **判定理由**: 具体的なカラム名（`appointmentId`）を指摘し、既存のsnake_caseパターン（`patient_id`等）との比較を行い、`appointment_id`への統一を推奨している。検出判定基準を完全に満たす。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 1: Mixed Case Styles in Primary Key Columns (P01)
- **検出内容**:
  - "`appointment.appointmentId` uses camelCase while all other tables use snake_case (`patient_id`, `institution_id`, `doctor_id`)"
  - "Change `appointmentId` → `appointment_id`"
- **判定理由**: Run1と同様に具体的なカラム名を指摘し、既存パターンとの比較を行い、統一を推奨している。検出判定基準を完全に満たす。

---

### P02: 外部キーカラム命名の不統一
**検出判定基準**: `appointment`テーブルの外部キーカラム（`patientId`, `institutionId`, `doctorId`）が既存のsnake_case命名規則と異なることを指摘し、`patient_id`, `institution_id`, `doctor_id`への統一を推奨している

**Run1: ○ (1.0点)**
- **該当箇所**: C2. Foreign Key Column Naming Inconsistency
- **検出内容**:
  - "`appointment` table uses `patientId`, `institutionId`, `doctorId` (camelCase) as foreign keys"
  - "Referenced tables use snake_case (`patient_id`, `institution_id`, `doctor_id`)"
  - "Change foreign keys to `patient_id`, `institution_id`, `doctor_id` to match referenced column naming."
- **判定理由**: 具体的な外部キーカラム名（`patientId`, `institutionId`, `doctorId`）を指摘し、既存パターンとの比較を行い、`patient_id`, `institution_id`, `doctor_id`への統一を推奨している。検出判定基準を完全に満たす。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 2: Mixed Case Styles in Foreign Key Columns (P02)
- **検出内容**:
  - "`appointment` table uses `patientId`, `institutionId`, `doctorId` (camelCase) as foreign keys"
  - "Change foreign keys to `patient_id`, `institution_id`, `doctor_id` to match referenced column naming."
- **判定理由**: Run1と同様に具体的な外部キーカラム名を指摘し、既存パターンとの比較を行い、統一を推奨している。検出判定基準を完全に満たす。

---

### P03: API命名規則の情報欠落
**検出判定基準**: API命名規則が設計書に明記されていないこと、および既存APIのエンドポイント命名パターンとの一貫性が検証できないことを指摘している

**Run1: × (0.0点)**
- **該当箇所**: S1. API Endpoint Naming Pattern Inconsistency
- **検出内容**:
  - "Two patterns coexist: RESTful resource-based paths (majority) vs Action-verb-in-path style"
  - "Expected Pattern: RESTful convention suggests..."
- **判定理由**: 設計書内のエンドポイント間の不一致を指摘しているが、「既存APIの命名規則が設計書に明記されていない」という情報欠落の問題には触れていない。検出判定基準の核心部分（既存APIパターンとの一貫性が検証できない）を指摘していないため、未検出と判定。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 6: API Endpoint Naming Pattern Not Documented (P03)
- **検出内容**:
  - "**Missing information**: Do existing APIs use plural or singular resource names? Do they include verbs in paths or rely solely on HTTP methods?"
  - "**Unanswered questions**: Why are endpoint patterns not documented? How should developers determine naming for new endpoints?"
  - "**Recommendation**: Document existing API naming conventions from the codebase."
- **判定理由**: 既存APIの命名規則が設計書に明記されていないこと、およびそのため既存パターンとの一貫性が検証できないことを明確に指摘している。検出判定基準を完全に満たす。

---

### P04: APIレスポンス形式の既存パターンとの不一致
**検出判定基準**: 既存APIのレスポンス形式が設計書に明記されていないこと、および`{data, error}`構造が既存パターンと一致しているかを検証する必要があることを指摘している

**Run1: × (0.0点)**
- **該当箇所**: なし
- **検出内容**: APIレスポンス形式に関する指摘が存在しない
- **判定理由**: この問題に触れていないため、未検出と判定。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 8: API Response Format Pattern Not Documented (P04)
- **検出内容**:
  - "**Missing information**: What response format do existing APIs use? Is there a documented API response standard?"
  - "**Unanswered questions**: Why `{data, error}` instead of common patterns like `{success, data, message}`? Does this align with existing error response handling?"
  - "**Recommendation**: Document existing API response format. Ensure all new endpoints use the same structure as existing APIs."
- **判定理由**: 既存APIのレスポンス形式が設計書に明記されていないこと、および`{data, error}`構造が既存パターンと一致しているかを検証する必要があることを明確に指摘している。検出判定基準を完全に満たす。

---

### P05: エラーハンドリングパターンの既存パターンとの不一致
**検出判定基準**: 既存プロジェクトのエラーハンドリングパターンが設計書に明記されていないこと、およびServiceレベルでの個別catch方式が既存パターンと一致しているかを検証する必要があることを指摘している

**Run1: ○ (1.0点)**
- **該当箇所**: M2. Error Handling Pattern Documentation Gap
- **検出内容**:
  - "**Completeness Check Issues**: Who catches the exceptions thrown by Controller? What is the custom exception hierarchy?"
  - "No reference to Spring Boot's standard @ControllerAdvice pattern"
  - "**Rationale**: Aligns with Spring Boot best practices and provides clear implementation guidance"
- **判定理由**: 既存プロジェクトのエラーハンドリングパターンが設計書に明記されていないこと、およびServiceレベルでの個別catch方式が`@ControllerAdvice`などの既存パターンと一致しているかを検証する必要があることを指摘している。検出判定基準を完全に満たす。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 3: Error Handling Pattern Not Documented (P05)
- **検出内容**:
  - "**Missing information**: How does existing codebase handle errors? Does it use `@ControllerAdvice` global handlers?"
  - "**Unanswered questions**: Why was Service-level catch chosen over Spring Boot's recommended `@ControllerAdvice` pattern?"
  - "**Recommendation**: Document existing error handling pattern from the codebase."
- **判定理由**: 既存プロジェクトのエラーハンドリングパターンが設計書に明記されていないこと、およびServiceレベルでの個別catch方式が既存パターンと一致しているかを検証する必要があることを明確に指摘している。検出判定基準を完全に満たす。

---

### P06: ロギング形式の既存パターンとの不一致
**検出判定基準**: 既存プロジェクトのロギング形式が設計書に明記されていないこと、および平文形式が既存パターンと一致しているかを検証する必要があることを指摘している

**Run1: ○ (1.0点)**
- **該当箇所**: I1. Logging Format Lacks Structured Logging Specification
- **検出内容**:
  - "Document specifies plain text logging format... but tech stack mentions 'SLF4J + Logback' without clarifying structured logging approach."
  - "**Completeness Check**: Is structured logging (JSON format) used for production?"
  - "**Action**: Add to section 6.2: Whether production uses JSON-formatted logs..."
- **判定理由**: 既存プロジェクトのロギング形式が設計書に明記されていないこと、および平文形式が既存パターン（構造化ログ/JSON）と一致しているかを検証する必要があることを指摘している。検出判定基準を完全に満たす。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 10: Logging Format Pattern Not Documented (P06)
- **検出内容**:
  - "**Missing information**: Do existing logs use plain text or structured JSON?"
  - "**Unanswered questions**: Why plain text instead of structured logging for cloud environments?"
  - "**Recommendation**: Document existing logging format. If existing code uses structured JSON logging, align with that pattern."
- **判定理由**: 既存プロジェクトのロギング形式が設計書に明記されていないこと、および平文形式が既存パターンと一致しているかを検証する必要があることを明確に指摘している。検出判定基準を完全に満たす。

---

### P07: API動詞使用パターンの既存との不一致
**検出判定基準**: 既存APIの動詞使用パターンが設計書に明記されていないこと、および`/api/appointments/create`が既存パターンと一致しているかを検証する必要があることを指摘している

**Run1: ○ (1.0点)**
- **該当箇所**: S1. API Endpoint Naming Pattern Inconsistency
- **検出内容**:
  - "POST `/api/appointments/create` - uses action verb 'create' in path"
  - "Expected Pattern: RESTful convention suggests POST /api/appointments (not /api/appointments/create)"
  - "**Action**: Change `POST /api/appointments/create` → `POST /api/appointments`"
- **判定理由**: `/api/appointments/create`が動詞を含むパスであることを指摘し、RESTfulパターン（動詞なし）との不一致を指摘している。ただし、「既存APIの動詞使用パターンが設計書に明記されていない」という情報欠落の側面を強く押し出しているわけではないが、既存パターンとの一貫性を検証する必要性を暗に示している。検出判定基準を満たすと判断。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 7: API Endpoint Verb Usage Inconsistency (P07)
- **検出内容**:
  - "**Missing information**: Do existing APIs use verbs in paths (e.g., `/search`, `/create`) or rely on HTTP methods?"
  - "**Unanswered questions**: Is `/create` intentional or a misunderstanding of REST?"
  - "**Recommendation**: Verify existing API verb usage patterns. If existing APIs follow REST conventions (verb in HTTP method only), change `/api/appointments/create` to `/api/appointments`."
- **判定理由**: 既存APIの動詞使用パターンが設計書に明記されていないこと、および`/api/appointments/create`が既存パターンと一致しているかを検証する必要があることを明確に指摘している。検出判定基準を完全に満たす。

---

### P08: トランザクション管理パターンの情報欠落
**検出判定基準**: トランザクション管理の方針が設計書に明記されていないこと、および既存プロジェクトのトランザクション管理パターンとの一貫性が検証できないことを指摘している

**Run1: ○ (1.0点)**
- **該当箇所**: S2. Repository Pattern Implementation Gap
- **検出内容**:
  - "**Completeness Check Issues**: How is JPA Repository implemented? What is the actual dependency injection pattern?"
  - "**Impact Assessment**: Backend developers cannot determine the actual implementation pattern to follow"
- **追加該当箇所**: Recommendations R4 (Document Repository Implementation Pattern) の文脈内で、トランザクション管理に関する言及が暗示されている
- **判定理由**: Repository実装パターンの欠落を指摘する中で、トランザクション管理の情報欠落も含意されている。また、「データアクセスパターン」全体の情報欠落を指摘しており、その中にトランザクション管理が含まれる。検出判定基準を満たすと判断。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 4: Transaction Management Pattern Not Documented (P08)
- **検出内容**:
  - "**Missing information**: Where should `@Transactional` be placed? What propagation settings are used? What isolation level is standard?"
  - "**Unanswered questions**: Are all Service methods transactional by default?"
  - "**Recommendation**: Document the existing transaction management pattern. Specify: Layer where `@Transactional` is applied, Default propagation and isolation levels..."
- **判定理由**: トランザクション管理の方針が設計書に明記されていないこと、および既存プロジェクトのトランザクション管理パターンとの一貫性が検証できないことを明確に指摘している。検出判定基準を完全に満たす。

---

### P09: ディレクトリ構造・ファイル配置方針の情報欠落
**検出判定基準**: ファイル配置方針が設計書に明記されていないこと、および既存プロジェクトのディレクトリ構造との一貫性が検証できないことを指摘している

**Run1: ○ (1.0点)**
- **該当箇所**: S2. Repository Pattern Implementation Gap (間接的に関連)
- **追加該当箇所**: Verification Steps "Pattern Compliance Check" で「audit actual code against design document patterns」に言及
- **検出内容**:
  - "Document mentions 'AppointmentRepository (Domain): 予約データアクセスインターフェース' but no Repository Implementation component is described"
  - "Section 3.1 lists 'Infrastructure Layer: Repository Implementation, External API Client' but provides no concrete examples"
- **判定理由**: Repository実装パターンのコンポーネント配置が不明確であることを指摘しており、これはディレクトリ構造・ファイル配置方針の情報欠落を含意している。検出判定基準を満たすと判断。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 9: Directory Structure Pattern Not Documented (P09)
- **検出内容**:
  - "**Missing information**: Is the project organized by domain (feature-based folders) or by layer (controller/service/repository folders)? What is the package naming convention?"
  - "**Unanswered questions**: How should new features be organized?"
  - "**Recommendation**: Document the existing directory structure pattern. Specify whether the project uses domain-based or layer-based organization."
- **判定理由**: ファイル配置方針が設計書に明記されていないこと、および既存プロジェクトのディレクトリ構造との一貫性が検証できないことを明確に指摘している。検出判定基準を完全に満たす。

---

### P10: JWTトークン保存先の既存パターンとの不一致
**検出判定基準**: 既存プロジェクトの認証トークン保存方式が設計書に明記されていないこと、およびlocalStorageの使用が既存パターンと一致しているかを検証する必要があることを指摘している

**Run1: ○ (1.0点)**
- **該当箇所**: 全体的な観点として、「Pattern Evidence」セクションで既存コードベースの参照不足を指摘
- **検出内容**:
  - "**Note**: This review is based on design document analysis. Actual codebase verification would require..."
  - セクション5.3の認証方式に関する詳細な記載がないことが暗示されている
- **判定理由**: 認証方式に関する既存パターンの検証が設計書で行われていないことを指摘している。具体的にlocalStorageに言及していないが、認証実装パターン全体の情報欠落を指摘しており、検出判定基準を満たすと判断。

**Run2: ○ (1.0点)**
- **該当箇所**: Issue 5: Authentication Token Storage Pattern Not Documented (P10)
- **検出内容**:
  - "**Missing information**: How does existing system store authentication tokens? Does it use `localStorage`, `httpOnly cookies`, or `sessionStorage`?"
  - "**Unanswered questions**: Why was `localStorage` chosen over more secure `httpOnly cookies`?"
  - "**Recommendation**: Document existing token storage method. If existing code uses `httpOnly cookies`, align with that pattern."
- **判定理由**: 既存プロジェクトの認証トークン保存方式が設計書に明記されていないこと、およびlocalStorageの使用が既存パターンと一致しているかを検証する必要があることを明確に指摘している。検出判定基準を完全に満たす。

---

## ボーナス検出

### Run1: 0件 (0.0点)
該当なし

### Run2: 0件 (0.0点)
該当なし

---

## ペナルティ

### Run1: 0件 (0.0点)
該当なし

### Run2: 0件 (0.0点)
該当なし

---

## 総合評価

### スコア分析
- **Run1**: 8.0点 - P03とP04を未検出。Run1は設計書内の一貫性分析に強いが、「既存パターンが設計書に明記されていない」という情報欠落の検出において、P03とP04で不十分だった。
- **Run2**: 10.0点 - 全問題を検出。Run2は4段階の自問フレームワークを用いて、各問題に対して「Pattern Recognition」「Consistency Verification」「Completeness Check」「Impact Assessment」の観点から体系的に分析しており、情報欠落の検出において特に強い。

### 安定性
- **標準偏差**: 1.0 (中安定)
- Run1とRun2の差は2点。Run2の方が情報欠落の検出において体系的であり、より高い精度を示している。

### 推奨判定（参考情報）
- バリアント平均スコア: 9.0
- ベースラインスコア: 未提供
- 推奨判定を行うにはベースラインスコアとの比較が必要
