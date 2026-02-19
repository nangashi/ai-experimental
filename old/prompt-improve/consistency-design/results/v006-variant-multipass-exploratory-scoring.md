# Scoring Report: v006-variant-multipass-exploratory

## Evaluation Metadata
- **Variant**: C1c-v3 (Multi-pass with exploratory phase)
- **Round**: 006
- **Perspective**: Consistency (Design Review)
- **Embedded Issues**: 10
- **Scoring Date**: 2026-02-11

---

## Run 1 Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Evidence |
|-----------|----------|----------|-----------|-------|----------|
| **P01** | 命名規約の既存パターンとの一致（データモデル） | 重大 | ○ | 1.0 | **P01-A**: Database Table Name Inconsistency, **P01-B**: Database Column Name Inconsistency で`appointmentId`を含む`appointment`テーブルのcamelCase命名がsnake_caseの既存パターンと異なることを明確に指摘し、`appointment_id`への統一を推奨 |
| **P02** | 命名規約の既存パターンとの一致（データモデル） | 中 | ○ | 1.0 | **P01-B**: Database Column Name Inconsistency で`appointment`テーブルの外部キーカラム（`patientId`, `institutionId`, `doctorId`）がcamelCaseで既存のsnake_case命名規則と異なることを指摘し、snake_caseへの統一を推奨 |
| **P03** | 実装パターンの既存パターンとの一致（情報欠落） | 重大 | △ | 0.5 | Pass 1で「API Error Format Consistency: Error format shown but no reference to existing system patterns」「Existing System Context: No references to existing modules or conventions in current codebase」と指摘しているが、API命名規則の情報欠落という核心的な問題（既存APIの命名パターンとの一貫性が検証できない）を明示的に指摘していない |
| **P04** | API/インターフェース設計の既存パターンとの一致 | 中 | △ | 0.5 | **P05-B**: API Versioning Strategy Not Documented で「Verify if existing APIs use versioning or not」と言及しているが、`{data, error}`構造が既存レスポンス形式と一致しているかの検証必要性という核心的な問題を明示的に指摘していない |
| **P05** | 実装パターンの既存パターンとの一致（エラー処理） | 重大 | ○ | 1.0 | **P03-A**: Global Exception Handler Pattern Not Documented で「Verify if existing codebase uses `@ControllerAdvice` global exception handler or other mechanism」と明記し、既存エラーハンドリングパターンとの一貫性検証の必要性を指摘 |
| **P06** | 実装パターンの既存パターンとの一致（ログ出力） | 軽微 | △ | 0.5 | Pass 1で「Logging: Specific format and level rules per layer documented」と肯定的に評価しており、既存ロギング形式との一貫性検証の必要性を指摘していない。平文形式が既存パターンと一致しているかの確認を求める記述なし |
| **P07** | API/インターフェース設計の既存パターンとの一致 | 中 | △ | 0.5 | **P01-C**: API Endpoint Naming Inconsistency で「`POST /api/appointments/create` uses redundant `/create` suffix」「Check if existing API endpoints use `/create` suffix pattern」と指摘しているが、既存APIの動詞使用パターンが設計書に明記されていないという情報欠落の観点が弱い |
| **P08** | 実装パターンの既存パターンとの一致（情報欠落） | 重大 | ○ | 1.0 | **P08**: Transaction Management Pattern Not Documented で「Section 3.2 mentions "トランザクション管理" as Service responsibility but no documentation on: Transaction boundaries, Isolation levels, Propagation rules」と明記し、既存トランザクション管理パターンとの一貫性が検証できないことを指摘 |
| **P09** | ディレクトリ構造・ファイル配置の既存パターンとの一致（情報欠落） | 中 | ○ | 1.0 | **P06**: No File Placement Policy Documented で「Section 3.2 lists component names but no documentation on: Directory structure (domain-based vs layer-based), Package naming conventions」と明記し、既存プロジェクトのディレクトリ構造との一貫性が検証できないことを指摘 |
| **P10** | 実装パターンの既存パターンとの一致（認証・認可） | 中 | ○ | 1.0 | **P10**: Authentication Token Storage Pattern Risk で「Section 5.3 specifies "トークン保存: クライアント側でlocalStorageに保存"」「Verify if existing client applications use localStorage or httpOnly cookies for token storage」と明記し、既存認証トークン保存方式との一貫性検証の必要性を指摘 |

**Run 1 Detection Score: 8.0 / 10.0**

### Run 1 Bonus/Penalty Analysis

**Bonus Candidates:**

1. **E03: Foreign Key Column Naming Inconsistency** (+0.5)
   - **内容**: `appointment`テーブルのFK列（`patientId`）が参照先のPK列（`patient_id`）と命名パターンが異なる問題を指摘
   - **判定**: ボーナス対象（P01/P02で個別カラム名の不一致は指摘済みだが、FK-PK関係の命名パターン不整合という構造的な視点で追加指摘）
   - **根拠**: 「FK: `patientId` (camelCase) → PK: `patient_id` (snake_case) in PatientAccount」「Align FK column names with referenced PK column names」

2. **E02: UUID Column Naming Suffix Inconsistency** (+0.5)
   - **内容**: ID列のサフィックス命名の不統一（`_id` vs `Id`）を指摘
   - **判定**: ボーナス対象（P01-Bと関連するが、サフィックスパターンの一貫性という追加視点）
   - **根拠**: 「`PatientAccount.patient_id` uses `_id` suffix (snake_case)」「`appointment.appointmentId` uses `Id` suffix (camelCase)」「Unify to snake_case `_id` suffix」

3. **E01: Timestamp Column Naming Inconsistency** (+0.5)
   - **内容**: `medical_institution`テーブルに`updated_at`カラムが欠落している問題を指摘
   - **判定**: ボーナス対象（暗黙的パターンの検出）
   - **根拠**: 「`PatientAccount` and `appointment` tables use `created_at`, `updated_at` (snake_case), but `medical_institution` only has `created_at`」「Expectation that all mutable entities have both `created_at` and `updated_at`」

4. **E04: JSONB Column Usage Without Schema Documentation** (+0.5)
   - **内容**: `business_hours` JSONB列のスキーマが文書化されていないことを指摘
   - **判定**: ボーナス対象（一貫性観点：既存のJSONB列文書化パターンとの整合性検証不能）
   - **根拠**: 「`medical_institution.business_hours` uses JSONB type but no schema documentation」「Check if existing codebase has JSONB column schema documentation patterns」

5. **E06: Authentication Pattern Completeness** (+0.5)
   - **内容**: JWT認証設計でトークンリフレッシュ/失効メカニズムが文書化されていないことを指摘
   - **判定**: ボーナス対象（既存認証モジュールとの一貫性検証不能）
   - **根拠**: 「Section 5.3 documents JWT authentication but no documentation on: Token refresh mechanism, Token expiration handling, Logout implementation」「Verify existing authentication implementation for refresh token pattern」

**Bonus Count: 5件 → スコア上限適用 +2.5点**

**Penalty Candidates:**

- **E05: Logging Pattern vs Error Handling Gap**: ロギングとエラーハンドリングの統合ギャップを指摘しているが、既存パターンとの一貫性検証の観点で述べているためスコープ内 → ペナルティなし
- **E07: WebFlux Reactor Thread Pool Blocking Risk**: パフォーマンスリスクの指摘だが、既存コードベースのスレッドプール戦略との一貫性検証の必要性を述べているためスコープ内 → ペナルティなし
- **E08: Transaction Boundary Ambiguity**: P08と関連するが、複数Repository呼び出し時のトランザクション境界の曖昧さという追加視点で一貫性問題を指摘しているためスコープ内 → ペナルティなし
- **E09: API Response Format vs Exception Handling Pattern Mismatch**: レスポンスラッパー形式とグローバル例外ハンドラーのマッピングが文書化されていないことを指摘しており、スコープ内 → ペナルティなし

**Penalty Count: 0件 → ペナルティなし**

**Run 1 Total Score: 8.0 + 2.5 - 0.0 = 10.5**

---

## Run 2 Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Evidence |
|-----------|----------|----------|-----------|-------|----------|
| **P01** | 命名規約の既存パターンとの一致（データモデル） | 重大 | ○ | 1.0 | **C2**: Table and Column Naming Case Inconsistency で「Mixed PascalCase (PatientAccount) and snake_case (medical_institution) for tables; mixed camelCase (appointmentId) and snake_case (appointment_datetime) for columns」と明記し、既存パターンとの一致確認を推奨 |
| **P02** | 命名規約の既存パターンとの一致（データモデル） | 中 | ○ | 1.0 | **C2**: Table and Column Naming Case Inconsistency で`appointment`テーブルの外部キーカラム（camelCase）と他のカラム（snake_case）の混在を指摘し、既存パターンへの統一を推奨 |
| **P03** | 実装パターンの既存パターンとの一致（情報欠落） | 重大 | × | 0.0 | API命名規則が設計書に明記されていないこと、および既存APIのエンドポイント命名パターンとの一貫性が検証できないことを直接的に指摘していない |
| **P04** | API/インターフェース設計の既存パターンとの一致 | 中 | △ | 0.5 | **S2: Response Format Consistency** で「Pattern is clearly specified and uniform」「Verify this matches existing API response structure in codebase」と言及しているが、既存レスポンス形式が設計書に明記されていないという情報欠落の観点を明示的に指摘していない |
| **P05** | 実装パターンの既存パターンとの一致（エラー処理） | 重大 | ○ | 1.0 | **S3**: Exception Handling Class Names and Structure Undocumented で「Error handling pattern described but custom exception class names and @ControllerAdvice usage not specified」「Check for existing GlobalExceptionHandler or @ControllerAdvice classes」と明記し、既存エラーハンドリングパターンとの一貫性検証の必要性を指摘 |
| **P06** | 実装パターンの既存パターンとの一致（ログ出力） | 軽微 | × | 0.0 | Pass 1で「Logging: SLF4J + Logback with structured format」と肯定的に評価しており、既存ロギング形式が設計書に明記されていないこと、平文形式が既存パターンと一致しているかの検証必要性を指摘していない |
| **P07** | API/インターフェース設計の既存パターンとの一致 | 中 | △ | 0.5 | **S1**: API Endpoint Naming Inconsistency で「`POST /api/appointments/create` uses action verb」「Check existing API endpoint patterns (RESTful vs RPC style)」と指摘しているが、既存APIの動詞使用パターンが設計書に明記されていないという情報欠落の観点が弱い |
| **P08** | 実装パターンの既存パターンとの一致（情報欠落） | 重大 | ○ | 1.0 | **C1**: Transaction Management Pattern Completely Undocumented で「No specification of transaction boundaries, @Transactional placement, or consistency guarantees」「Check existing Service classes for transaction annotation patterns」と明記し、既存トランザクション管理パターンとの一貫性が検証できないことを指摘 |
| **P09** | ディレクトリ構造・ファイル配置の既存パターンとの一致（情報欠落） | 中 | ○ | 1.0 | **C3**: Package Structure and File Placement Completely Undocumented で「No specification of package organization (domain-first vs layer-first), DTO location, Mapper location」「Check existing package structure pattern」と明記し、既存プロジェクトのディレクトリ構造との一貫性が検証できないことを指摘 |
| **P10** | 実装パターンの既存パターンとの一致（認証・認可） | 中 | ○ | 1.0 | **I2**: Authentication Token Storage Pattern Verification Needed で「localStorage usage documented but unclear if this matches existing pattern or is new anti-pattern」「Check existing frontend authentication token storage」と明記し、既存認証トークン保存方式との一貫性検証の必要性を指摘 |

**Run 2 Detection Score: 6.0 / 10.0**

### Run 2 Bonus/Penalty Analysis

**Bonus Candidates:**

1. **E1: Implicit Pattern: Entity-Table Naming Divergence** (+0.5)
   - **内容**: エンティティ名とテーブル名の命名パターンの乖離を指摘
   - **判定**: ボーナス対象（P01で個別のテーブル名不一致は指摘済みだが、Entity-Table命名戦略の体系的な問題として追加指摘）
   - **根拠**: 「Document describes domain entities with simple names (Patient, Appointment, Doctor)」「Tables use either exact lowercase or modified names (PatientAccount vs Patient)」「Should entity class names match table names exactly or use domain names with @Table annotations?」

2. **E2: Cross-Category Issue: FK Column Naming vs Referenced Table Naming** (+0.5)
   - **内容**: FK列名の導出ルールが文書化されておらず、テーブル名の命名パターンとFKカラム名の関係が不明確
   - **判定**: ボーナス対象（P01/P02で個別のFK列名不一致は指摘済みだが、FK命名ルールの体系的な問題として追加指摘）
   - **根拠**: 「FK column names follow camelCase but referenced table names are inconsistent」「No documented rule for deriving FK column names from table names」

3. **E6: Cross-Cutting Issue: Timestamp Column Consistency** (+0.5)
   - **内容**: タイムスタンプ列の自動管理戦略が文書化されていないことを指摘
   - **判定**: ボーナス対象（既存のタイムスタンプ管理パターンとの一貫性検証不能）
   - **根拠**: 「All tables use `created_at` and `updated_at` consistently」「No specification of automatic timestamp management (@CreatedDate, @LastModifiedDate from Spring Data JPA, or database triggers)」「Check if existing entities use JPA lifecycle callbacks, Spring Data JPA auditing, or Database-level DEFAULT CURRENT_TIMESTAMP」

4. **E8: Edge Case: UUID Generation Strategy** (+0.5)
   - **内容**: UUID生成戦略が文書化されていないことを指摘
   - **判定**: ボーナス対象（既存のID生成パターンとの一貫性検証不能）
   - **根拠**: 「All ID columns use UUID type but doesn't specify: Client-generated UUIDs, Database-generated UUIDs, Specific UUID version」「Check existing entity ID generation strategy (@GeneratedValue configuration)」

5. **M5: Dependency Management Policy Undocumented** (+0.5)
   - **内容**: ライブラリ選定基準やバージョン管理方針が文書化されていないことを指摘
   - **判定**: ボーナス対象（正解キーに未掲載かつ一貫性スコープ内）
   - **根拠**: 「No guidance on library selection criteria, version pinning」「Check existing pom.xml or build.gradle for version management patterns」

**Bonus Count: 5件 → スコア上限適用 +2.5点**

**Penalty Candidates:**

- **E4: Edge Case: Async Processing Pattern Mismatch**: WebFlux（リアクティブ）とJPA（ブロッキング）の混在を指摘しているが、既存コードベースのHTTPクライアント選択パターンとの一貫性検証の必要性を述べているためスコープ内 → ペナルティなし
- **E7: Latent Risk: API Versioning Strategy**: APIバージョニング戦略が文書化されていないことを指摘しており、既存APIとの一貫性検証の観点で述べているためスコープ内 → ペナルティなし
- **I2: Authentication Token Storage Pattern Verification Needed**: セキュリティリスク（XSS）に言及しているが、主眼は既存パターンとの一貫性検証であり、「if this matches existing pattern or is new anti-pattern」「If existing uses httpOnly cookies, this is major security regression」と既存との整合性を問題視しているためスコープ内 → ペナルティなし

**Penalty Count: 0件 → ペナルティなし**

**Run 2 Total Score: 6.0 + 2.5 - 0.0 = 8.5**

---

## Overall Summary

| Metric | Run 1 | Run 2 |
|--------|-------|-------|
| **Detection Score** | 8.0 | 6.0 |
| **Breakdown** | ○: 7, △: 3, ×: 0 | ○: 6, △: 2, ×: 2 |
| **Bonus** | +2.5 (5件, 上限適用) | +2.5 (5件, 上限適用) |
| **Penalty** | -0.0 (0件) | -0.0 (0件) |
| **Total Score** | **10.5** | **8.5** |

### Statistical Summary

- **Mean Score**: 9.5
- **Standard Deviation**: 1.0
- **安定性判定**: 中安定（0.5 < SD ≤ 1.0）- 傾向は信頼できるが、個別の実行で変動がある

---

## Key Findings

### Strengths (Both Runs)

1. **命名規約の網羅的検出**: 両実行ともP01/P02（テーブル・カラム命名の不一致）を完全検出し、既存パターンとの一致確認を推奨
2. **情報欠落の体系的検出**: トランザクション管理（P08）、ファイル配置（P09）、認証トークン保存（P10）を両実行で完全検出
3. **エラーハンドリングパターンの検証**: 両実行ともP05（エラーハンドリングパターンの情報欠落）を検出し、既存グローバル例外ハンドラーとの一貫性確認を推奨
4. **多層的な分析構造**: Pass 1（構造理解・パターン抽出）→ Pass 2（詳細一貫性分析）→ Pass 3（探索的検出）の3段階アプローチで、明示的な不一致と暗黙的なパターン違反を両方検出

### Weaknesses (Variability Between Runs)

1. **API命名規則の情報欠落（P03）**: Run 1は△（部分検出）、Run 2は×（未検出）。既存APIのエンドポイント命名パターンとの一貫性が検証できないという核心的な問題を明示的に指摘していない
2. **ロギング形式の情報欠落（P06）**: 両実行とも未検出/部分検出。既存ロギング形式が設計書に明記されていないこと、平文形式が既存パターンと一致しているかの検証必要性を指摘していない
3. **レスポンス形式の情報欠落（P04）**: 両実行とも△（部分検出）。既存APIのレスポンス形式との一貫性検証の観点が弱い
4. **動詞使用パターンの情報欠落（P07）**: 両実行とも△（部分検出）。API設計での動詞使用（`/create`サフィックス）の不一致は指摘しているが、既存APIの動詞使用パターンが設計書に明記されていないという情報欠落の観点が弱い

### Exploratory Phase Effectiveness

- **Run 1**: Pass 3で12件の追加問題を検出（E01-E09）。FK-PK命名不整合（E03）、WebFluxブロッキングリスク（E07）、トランザクション境界の曖昧さ（E08）など、チェックリスト駆動のPass 2では捉えきれない横断的問題や潜在リスクを発見
- **Run 2**: Pass 3で8件の追加問題を検出（E1-E8）。Entity-Table命名戦略の乖離（E1）、FK命名ルール欠落（E2）、タイムスタンプ管理戦略の未文書化（E6）など、体系的なパターン問題を発見

**結論**: 探索的フェーズは正解キー外の有益な追加指摘を生み出しており、マルチパスアプローチの価値を実証している。

---

## Detection Gap Analysis

### Consistently Missed: P03, P06

**P03 (API命名規則の情報欠落)**:
- 両実行とも「既存APIの命名規則が設計書に明記されていない」という情報欠落の核心を捉えきれていない
- 改善案: Pass 1の「Missing Information Detected」セクションで「API命名規則（動詞の使用パターン、リソース名の複数形/単数形等）が設計書に明記されていない」を明示的にチェック項目化する

**P06 (ロギング形式の情報欠落)**:
- 両実行ともロギング形式が「documented」と肯定的に評価し、既存パターンとの一貫性検証の必要性を見落としている
- 改善案: Pass 1で「Logging format specified」と評価する際に、「Existing logging format (plain text vs structured JSON) not referenced」を併記する

### Partially Missed: P04, P07

**P04 (APIレスポンス形式の既存パターンとの不一致)**:
- 「レスポンス形式が明確」と評価しているが、既存APIのレスポンス形式との一致確認が必要という観点が弱い
- 改善案: Pass 2で「API Response Format Consistency」を評価する際に、「Verify existing API response wrapper format」を明示的に追加する

**P07 (API動詞使用パターンの既存との不一致)**:
- `/create`サフィックスの不整合は指摘しているが、「既存APIの動詞使用パターンが設計書に明記されていない」という情報欠落の観点が不足
- 改善案: Pass 2で「API Endpoint Naming Inconsistency」を指摘する際に、「Existing API verb usage pattern not documented in design」を明示的に追加する

---

## Recommendations for Variant Optimization

1. **Pass 1の「Missing Information」チェックリストを強化**:
   - API命名規則（エンドポイント命名パターン、動詞使用ルール）
   - APIレスポンス形式の既存パターン参照
   - ロギング形式の既存パターン参照
   を明示的にチェック項目化する

2. **「documented」と評価した項目でも既存パターンとの一致確認を促す**:
   - 「Pattern is documented BUT not verified against existing codebase」という評価軸を追加

3. **情報欠落問題の優先度を維持**:
   - 現在のPass 1で「Missing Information」を最初に検出する構造は有効。P03/P06の見落としは構造的な問題ではなく、チェック項目の網羅性の問題

4. **探索的フェーズの価値を維持**:
   - 両実行とも探索的フェーズで正解キー外の有益な指摘（ボーナス5件）を生成しており、マルチパスアプローチの価値を実証している
