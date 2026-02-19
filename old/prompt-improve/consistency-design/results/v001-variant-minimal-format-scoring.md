# Scoring Report: v001-variant-minimal-format

## Run 1 Detailed Analysis

### Detection Matrix

| Problem ID | Detection | Score | Justification |
|-----------|-----------|-------|---------------|
| P01: テーブル名の命名規則の不統一 | ○ | 1.0 | C-2で「Inconsistent Table Naming Convention」として明確に検出。`users` (lowercase), `Devices` (PascalCase), `automation_rule` (snake_case)の不統一を具体的に指摘し、既存パターンとの一致の必要性を述べている。 |
| P02: カラム名の命名規則の混在 | ○ | 1.0 | C-1で「Inconsistent Naming Case Convention in Data Models」として明確に検出。camelCase/snake_case/PascalCaseの混在を具体的なカラム名（`userId`, `created_at`, `DeviceName`, `device_id`等）を挙げて詳細に指摘している。 |
| P03: APIレスポンス形式が既存パターンと異なる可能性 | ○ | 1.0 | S-2で「Missing API Response Format Convention Documentation」として検出。`"result": "success"`と`"message"`フィールドの使用について、既存APIとの一致確認が欠落している点を明確に指摘している。 |
| P04: エラーハンドリングパターンが既存の実装方針と異なる可能性 | ○ | 1.0 | M-2で「Error Handling Pattern Not Verified Against Existing Codebase」として検出。個別try-catchの採用について、既存のグローバルエラーハンドラーとの一致確認が欠落している点を指摘している。 |
| P05: データアクセスパターンとトランザクション管理方針の欠落 | × | 0.0 | データアクセスパターン（Repository経由 vs Service層から直接ORM）およびトランザクション管理方針について明示的な指摘がない。S-2でアーキテクチャパターンに言及しているが、データアクセスとトランザクション管理の具体的な欠落には触れていない。 |
| P06: HTTP通信ライブラリの選定が既存と異なる可能性 | × | 0.0 | `node-fetch 3.x`の採用について、既存のHTTP通信ライブラリとの整合性確認の欠落を指摘していない。M-2で依存バージョンに言及しているが、HTTP通信ライブラリの具体的な一致確認には触れていない。 |
| P07: 環境変数命名規則の方針が欠落 | △ | 0.5 | M-3で「Missing Configuration File Format Reference」として環境変数命名規則に言及しているが、「UPPER_SNAKE_CASE vs other styles」と概念的に触れているのみで、既存パターンとの一致確認の必要性が明確に述べられていない。 |
| P08: ログ出力パターンの設計書記載と実装例の不一致 | △ | 0.5 | M-3でロギング設定について「Winston is specified, but the document does not verify whether existing services use the same logger」と言及しているが、エラーハンドリング例でロギング処理が省略されている点（設計書内の不一致）には触れていない。 |
| P09: API命名規則・エンドポイント設計方針の欠落 | ○ | 1.0 | S-3で「API Endpoint Naming Pattern Not Verified」として検出。`/api/devices`と`/api/automation/rules`のパターンについて、既存APIとの一致確認（バージョニング、ネスト構造等）が欠落している点を指摘している。 |

**検出スコア合計**: 6.0

### Bonus Analysis

| Bonus ID | Content | Detected | Score | Justification |
|----------|---------|----------|-------|---------------|
| B01 | 外部キー制約のカラム名が参照先と異なる | ○ | +0.5 | S-1で「Inconsistent Foreign Key Reference Column Naming」として検出。`user_id` (snake_case)が`users.userId` (camelCase)を参照する不一致を明確に指摘している。 |
| B02 | 認証トークンの保存先のセキュリティリスク | × | 0 | localStorageの使用について言及なし。 |
| B03 | バリデーションライブラリ（joi）の選定が既存と異なる可能性 | × | 0 | joiの選定について既存との一致確認の欠落を指摘していない。 |
| B04 | ファイル配置方針が設計書に明記されていない | ○ | +0.5 | M-1で「Directory Structure Not Documented」として検出。ドメイン別/レイヤー別のファイル配置ルールが明記されておらず、既存との一貫性が検証できない点を明確に指摘している。 |
| B05 | 非同期処理パターンが設計書に明記されていない | × | 0 | async/await/Promise/callbackの使用方針について言及なし。 |

**ボーナス合計**: +1.0

### Penalty Analysis

| Category | Content | Score | Justification |
|----------|---------|-------|---------------|
| スコープ外（Security） | なし | 0 | セキュリティ関連の不適切な指摘なし。 |
| スコープ外（Performance） | なし | 0 | パフォーマンス関連の不適切な指摘なし。 |
| 事実に反する指摘 | なし | 0 | 事実誤認による指摘なし。 |

**ペナルティ合計**: 0

### Run 1 Total Score
- 検出スコア: 6.0
- ボーナス: +1.0
- ペナルティ: 0
- **Run 1 総合スコア**: 7.0

---

## Run 2 Detailed Analysis

### Detection Matrix

| Problem ID | Detection | Score | Justification |
|-----------|-----------|-------|---------------|
| P01: テーブル名の命名規則の不統一 | ○ | 1.0 | C-2で「Inconsistent Table Naming Convention」として明確に検出。`users` (lowercase), `Devices` (PascalCase), `automation_rule` (snake_case)の不統一を具体的に指摘し、既存パターンとの一致確認の必要性を述べている。 |
| P02: カラム名の命名規則の混在 | ○ | 1.0 | C-1で「Inconsistent Naming Convention - Mixed Case Styles Across Database Schema」として明確に検出。camelCase/snake_case/PascalCaseの混在を各テーブルの具体的なカラム名を挙げて詳細に指摘している。 |
| P03: APIレスポンス形式が既存パターンと異なる可能性 | ○ | 1.0 | C-2で「Inconsistent API Response Format - No Established Pattern」として検出。`"result": "success"`と`"message"`フィールドについて、既存APIパターンとの一致確認が欠落している点を指摘している。 |
| P04: エラーハンドリングパターンが既存の実装方針と異なる可能性 | ○ | 1.0 | C-3で「Undefined Error Handling Pattern - Controller-Level Try-Catch Without Global Handler Reference」として検出。個別try-catchについて、既存のグローバルエラーハンドラーとの一致確認が欠落している点を明確に指摘している。 |
| P05: データアクセスパターンとトランザクション管理方針の欠落 | × | 0.0 | データアクセスパターンおよびトランザクション管理方針について明示的な指摘がない。S-2でアーキテクチャパターンに言及しているが、データアクセスとトランザクション管理の具体的な欠落には触れていない。 |
| P06: HTTP通信ライブラリの選定が既存と異なる可能性 | × | 0.0 | `node-fetch 3.x`について、既存のHTTP通信ライブラリとの整合性確認の欠落を指摘していない。M-2で依存バージョンに言及しているが、HTTP通信ライブラリの具体的な一致確認には触れていない。 |
| P07: 環境変数命名規則の方針が欠落 | △ | 0.5 | M-3で「Missing Configuration File Format Reference」として環境変数命名規則に言及しているが、概念的な記述にとどまり、既存パターンとの一致確認の必要性が明確に述べられていない。 |
| P08: ログ出力パターンの設計書記載と実装例の不一致 | × | 0.0 | M-3でロギングライブラリについて言及しているが、エラーハンドリング例でロギング処理が省略されている点（設計書内の一貫性の欠如）には触れていない。 |
| P09: API命名規則・エンドポイント設計方針の欠落 | × | 0.0 | API設計について言及はあるが、エンドポイント命名規則の明記が欠落している点、または既存APIとの一致確認が必要という点を明確に指摘していない。 |

**検出スコア合計**: 5.5

### Bonus Analysis

| Bonus ID | Content | Detected | Score | Justification |
|----------|---------|----------|-------|---------------|
| B01 | 外部キー制約のカラム名が参照先と異なる | ○ | +0.5 | I-1で「Partial Foreign Key Reference Consistency」として検出。`user_id` (snake_case)が`users.userId` (camelCase)を参照する不一致を指摘している。 |
| B02 | 認証トークンの保存先のセキュリティリスク | × | 0 | localStorageの使用について言及なし。 |
| B03 | バリデーションライブラリ（joi）の選定が既存と異なる可能性 | × | 0 | joiの選定について既存との一致確認の欠落を指摘していない。 |
| B04 | ファイル配置方針が設計書に明記されていない | ○ | +0.5 | M-1で「Unclear Directory Structure Alignment」として検出。ドメイン別/レイヤー別のファイル配置ルールが明記されておらず、既存との一貫性が検証できない点を指摘している。 |
| B05 | 非同期処理パターンが設計書に明記されていない | × | 0 | async/await/Promise/callbackの使用方針について言及なし。 |

**ボーナス合計**: +1.0

### Penalty Analysis

| Category | Content | Score | Justification |
|----------|---------|-------|---------------|
| スコープ外（Security） | なし | 0 | セキュリティ関連の不適切な指摘なし。 |
| スコープ外（Performance） | なし | 0 | パフォーマンス関連の不適切な指摘なし。 |
| 事実に反する指摘 | なし | 0 | 事実誤認による指摘なし。 |

**ペナルティ合計**: 0

### Run 2 Total Score
- 検出スコア: 5.5
- ボーナス: +1.0
- ペナルティ: 0
- **Run 2 総合スコア**: 6.5

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Run 1 Score | 7.0 (検出6.0 + bonus1.0 - penalty0) |
| Run 2 Score | 6.5 (検出5.5 + bonus1.0 - penalty0) |
| Mean Score | 6.75 |
| Standard Deviation | 0.25 |
| Stability | 高安定 (SD ≤ 0.5) |

---

## Key Observations

### Strengths
1. **Critical問題の高い検出率**: P01, P02, P03, P04の4つのCritical/重大問題を両Run共に検出（Run1: 4/4, Run2: 4/4）
2. **具体的な問題箇所の特定**: カラム名、テーブル名、APIレスポンスフィールドなど、具体的な箇所を明示
3. **既存パターンとの一致確認の欠落を指摘**: 正解キーの評価観点（既存との一貫性検証）に合致した指摘が多数
4. **ボーナス問題の検出**: B01（外部キー命名）、B04（ファイル配置方針）を両Run共に検出
5. **安定性**: SD=0.25で高安定、結果の信頼性が高い

### Weaknesses
1. **P05（データアクセス/トランザクション管理）の未検出**: 両Run共に未検出。アーキテクチャパターンには言及しているが、データアクセス層の実装方針の欠落には触れていない
2. **P06（HTTP通信ライブラリ）の未検出**: 両Run共に未検出。依存バージョンには言及しているが、ライブラリ選定の一貫性確認には触れていない
3. **P08の不安定な検出**: Run1は△（部分検出）、Run2は×（未検出）。ロギング方針自体には言及しているが、エラーハンドリング例との一貫性欠如の指摘が弱い
4. **P09の不安定な検出**: Run1は○（検出）、Run2は×（未検出）。Run間で検出結果が異なり、不安定性が見られる

### Comparison Notes
- Run1はP09を検出したが、Run2は未検出（-0.5pt差の主要因）
- Run1はP08を部分検出（△）、Run2は未検出（×）（-0.5pt差の副次的要因）
- その他の問題については両Run共に同じ判定結果
