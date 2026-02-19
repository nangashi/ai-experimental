# Scoring Report: v012-baseline

## Detection Matrix

| Problem ID | Run1 | Run2 | Category | Severity |
|-----------|------|------|----------|----------|
| P01 (テーブル名命名規約混在) | × | × | 命名規約 | 重大 |
| P02 (タイムスタンプカラム名不統一) | ○ | ○ | 命名規約 | 重大 |
| P03 (主キーカラム名不統一) | ○ | ○ | 命名規約 | 重大 |
| P04 (APIパスプレフィックス不統一) | ○ | ○ | API設計 | 中 |
| P05 (APIエンドポイント動詞使用) | ○ | ○ | API設計 | 中 |
| P06 (APIレスポンス形式不一致) | ○ | ○ | API設計 | 中 |
| P07 (HTTP通信ライブラリ選定不一致) | △ | △ | 依存管理 | 中 |
| P08 (エラーハンドリングパターン明記不足) | × | × | 実装パターン | 中 |
| P09 (トランザクション管理方針明記不足) | △ | △ | 実装パターン | 軽微 |
| P10 (JWT保存先セキュリティリスク) | △ | △ | 実装パターン | 軽微 |

## Detailed Analysis

### P01: テーブル名の命名規約混在（複数形使用）
- **Run1**: × 未検出
  - 理由: Report P1ではテーブル名が単数形であることを肯定的に評価している（"All tables correctly use singular, snake_case naming"）。しかし、正解キーの問題は「既存システムは単数形スネークケース（例: `user`, `media_file`）」を採用しているにも関わらず、設計書の4.1では `article`, `user`, `media`, `review` と**複数形なしの単数形**で記載されているが、正解キーが指摘している「複数形使用」の問題点を検出していない。実際の問題は「設計書内に複数形テーブル名が記載されている」という事実に基づくべきだが、Run1はこの問題を検出していない。

- **Run2**: × 未検出
  - 理由: 同様にテーブル名の単数形使用を肯定的に評価（P1: "All tables correctly use singular, snake_case naming"）。正解キーが指摘する「複数形使用の混在」問題を検出していない。

### P02: タイムスタンプカラム名の不統一
- **Run1**: ○ 検出
  - 検出箇所: C1 "Timestamp Column Naming Fragmentation"
  - 根拠: 4つの異なるパターン（`created`/`updated`, `createdAt`/`updatedAt`, `created_at`/`updated_at`, `created`/`modified`）を明示し、既存パターン `created_at`/`updated_at` との不一致を指摘。

- **Run2**: ○ 検出
  - 検出箇所: C1 "Timestamp Column Naming Fragmentation (4 Incompatible Patterns)"
  - 根拠: 4つの異なるパターンを具体的に列挙し、既存標準（Section 8.1.1の `created_at`/`updated_at`）との不一致を明示。

### P03: 主キーカラム名の不統一
- **Run1**: ○ 検出
  - 検出箇所: C2 "Primary Key Naming Inconsistency"
  - 根拠: `media_id` と `review_id` が既存パターン `id`（プレフィックスなし）と異なることを指摘。

- **Run2**: ○ 検出
  - 検出箇所: C2 "Primary Key Naming Inconsistency (50% Violation Rate)"
  - 根拠: Media/Reviewテーブルの `media_id`/`review_id` が既存標準 `id` と異なることを明示。

### P04: APIエンドポイントのパスプレフィックス不統一
- **Run1**: ○ 検出
  - 検出箇所: C4 "API Versioning Inconsistency"
  - 根拠: 記事管理APIの `/api/articles/` が既存の `/api/v1/` プレフィックスパターンと異なることを指摘。

- **Run2**: ○ 検出
  - 検出箇所: C4 "API Endpoint Versioning Fragmentation"
  - 根拠: Article endpointsが `/api/v1/` プレフィックスを欠落していることを指摘し、既存標準との不一致を明示。

### P05: APIエンドポイントのアクション動詞使用
- **Run1**: ○ 検出
  - 検出箇所: S1 "Non-RESTful Article Endpoint Naming"
  - 根拠: `/new`, `/edit`, `/list` サフィックスが既存のRESTful名詞ベース設計と異なることを指摘。

- **Run2**: ○ 検出
  - 検出箇所: S1 "Non-RESTful Article Endpoint Naming"
  - 根拠: `/new`, `/edit`, `/list` サフィックスが既存のRESTful規約と矛盾することを指摘。

### P06: APIレスポンス形式の不一致
- **Run1**: ○ 検出
  - 検出箇所: C5 "Response Format Fragmentation"
  - 根拠: 成功レスポンス `{success, data, message}` が既存の `{data, error}` 形式と異なることを指摘し、セクション8.1.3の矛盾を明示。

- **Run2**: ○ 検出
  - 検出箇所: C5 "Response Format Documentation Conflict"
  - 根拠: Section 5.2.2の `{success, data, message}` がSection 8.1.3の `{data, error}` 標準と矛盾することを指摘。

### P07: HTTP通信ライブラリの選定不一致
- **Run1**: △ 部分検出
  - 検出箇所: C3 "HTTP Library Conflict"
  - 理由: OkHttpとRestTemplateの競合を指摘しているが、正解キーの要求する「OkHttpの採用が既存のRestTemplateパターンと異なる」という既存パターンとの不一致を明示的に述べている。ただし、RestTemplateの内部実装としてOkHttpを使う可能性にも言及しており、問題の核心（別ライブラリ新規導入による依存関係複雑化）の理解が部分的。

- **Run2**: △ 部分検出
  - 検出箇所: S3 "HTTP Client Library Ambiguity"
  - 理由: OkHttpとRestTemplateの矛盾を指摘し、RestTemplateが既存パターンであることに言及。ただし、「RestTemplateがSpringの抽象化でOkHttpを内部利用可能」という解釈も提示しており、既存パターンとの不一致の深刻さの認識が部分的。

### P08: エラーハンドリングパターンの明記不足（情報欠落）
- **Run1**: × 未検出
  - 理由: Section 6.1のエラーハンドリングについて、既存システムのパターンとの一貫性検証が欠落していることを指摘していない。

- **Run2**: × 未検出
  - 理由: エラーハンドリングパターンの既存システムとの一貫性検証の欠落を指摘していない。

### P09: トランザクション管理方針の明記不足（情報欠落）
- **Run1**: △ 部分検出
  - 検出箇所: M2 "Missing Transaction Management Pattern"
  - 理由: トランザクション管理方針が明記されていないことを指摘しているが、「既存システムのトランザクション管理パターンとの一貫性が検証できない」という正解キーの核心（既存パターンとの一貫性検証の欠落）を明示していない。情報欠落の指摘はあるが、一貫性検証の観点が不明確。

- **Run2**: △ 部分検出
  - 検出箇所: M2 "Missing Transaction Management Pattern"
  - 理由: Run1と同様に、トランザクション管理方針の欠落を指摘しているが、既存パターンとの一貫性検証が欠落している点を明示していない。

### P10: JWT保存先のセキュリティリスク
- **Run1**: △ 部分検出
  - 検出箇所: M4 "JWT Token Management Incomplete Specification"
  - 理由: localStorageの使用について言及し、セキュリティリスク（httpOnlyクッキーとの比較）にも触れているが、「既存システムのパターンとの一貫性検証が必要」という正解キーの核心（一貫性検証の観点）を明示していない。セキュリティリスクのみを指摘。

- **Run2**: △ 部分検出
  - 検出箇所: M4 "JWT Token Management Incomplete Specification"
  - 理由: Run1と同様に、localStorageの使用とセキュリティリスクを指摘しているが、既存パターンとの一貫性検証の観点が不明確。

## Bonus Detection

### B01: 外部キー列名の命名パターン不統一
- **Run1**: ○ ボーナス加点 (+0.5)
  - 検出箇所: C3 "Foreign Key Column Naming Ambiguity"
  - 根拠: `author_id`, `uploaded_by`, `reviewer` の不統一を指摘し、既存パターン `{参照先テーブル名}_id` との整合性について言及。

- **Run2**: ○ ボーナス加点 (+0.5)
  - 検出箇所: C3 "Foreign Key Naming Pattern Violations"
  - 根拠: `uploaded_by`, `reviewer` が既存の `{table}_id` パターンと異なることを明示。

### B02: カラム名のケース不統一
- **Run1**: × ボーナス対象外
  - 理由: M1でJSON命名規約の未定義を指摘しているが、user.user_nameとuser.createdAt/updatedAtのケース混在という特定の問題は指摘していない。

- **Run2**: × ボーナス対象外
  - 理由: Run1と同様、カラム名のケース混在を具体的に指摘していない。

### B03: ディレクトリ構造の記載矛盾
- **Run1**: × ボーナス対象外
  - 理由: セクション8.1.4のレイヤー別構成とセクション3.2のモジュール説明の矛盾を指摘していない。

- **Run2**: × ボーナス対象外
  - 理由: ディレクトリ構造の記載矛盾を指摘していない。

### B04: ログ出力パターンの明記不足
- **Run1**: × ボーナス対象外
  - 理由: ログ出力パターンの明記不足と既存パターンとの一貫性検証について指摘していない。

- **Run2**: × ボーナス対象外
  - 理由: ログ出力パターンの明記不足を指摘していない。

### B05: エラーレスポンスのコード形式検証欠落
- **Run1**: × ボーナス対象外
  - 理由: エラーコード形式（"VALIDATION_ERROR"）の既存システムとの一貫性検証欠落を指摘していない。

- **Run2**: × ボーナス対象外
  - 理由: エラーコード形式の一貫性検証欠落を指摘していない。

### B06: ステータス値の命名スタイル不統一
- **Run1**: × ボーナス対象外
  - 理由: review.statusとarticle.statusの命名スタイル不統一を指摘していない。

- **Run2**: × ボーナス対象外
  - 理由: ステータス値の命名スタイル不統一を指摘していない。

## Additional Detections (スコープ外チェック)

### Run1 追加検出
1. S2 "Table Name Documentation Inconsistency" - `media` vs `media_file` の矛盾
   - **判定**: ボーナス対象外（正解キーに含まれず、perspective.mdの評価スコープ内だが既に検出済み問題の別側面）

2. S4 "Category Data Model Inconsistency" - category VARCHARとcategoryId integerの型不一致
   - **判定**: ボーナス対象外（データモデル設計の問題で、一貫性というより設計品質の問題）

3. M1 "Request/Response JSON Naming Convention Undefined" - JSON命名規約の未定義
   - **判定**: ボーナス対象外（正解キーに含まれず、命名規約の明記不足だが一般的すぎる）

4. M3 "Missing Pagination Pattern for List Endpoints" - ページネーションパターン未定義
   - **判定**: ペナルティ対象外（スコープ内だが新機能の設計不足であり、既存パターンとの不一致ではない）

5. M5 "Missing Environment Variable Naming Convention" - 環境変数命名規約の未定義
   - **判定**: ボーナス対象外（正解キーに含まれず、一般的な指摘）

### Run2 追加検出
1. S2 "Table Name Documentation Inconsistency" - `media` vs `media_file` の矛盾
   - **判定**: ボーナス対象外（Run1と同じ）

2. S4 "Category Data Model Inconsistency" - category VARCHARとcategoryId integerの型不一致
   - **判定**: ボーナス対象外（Run1と同じ）

3. M1 "Request/Response JSON Naming Convention Undefined" - JSON命名規約の未定義
   - **判定**: ボーナス対象外（Run1と同じ）

4. M3 "Missing Pagination Pattern for List Endpoints" - ページネーションパターン未定義
   - **判定**: ペナルティ対象外（Run1と同じ）

5. M5 "Missing Environment Variable Naming Convention" - 環境変数命名規約の未定義
   - **判定**: ボーナス対象外（Run1と同じ）

## Penalty Assessment

### Run1
- **ペナルティなし**: 全指摘がconsistency観点内に収まっている。セキュリティ・パフォーマンス関連の独立指摘なし。

### Run2
- **ペナルティなし**: 全指摘がconsistency観点内に収まっている。セキュリティ・パフォーマンス関連の独立指摘なし。

## Score Calculation

### Run1
- 検出スコア: P02(1.0) + P03(1.0) + P04(1.0) + P05(1.0) + P06(1.0) + P07(0.5) + P09(0.5) + P10(0.5) = 7.5
- ボーナス: B01(+0.5) = 0.5
- ペナルティ: 0
- **合計: 7.5 + 0.5 - 0 = 8.0**

### Run2
- 検出スコア: P02(1.0) + P03(1.0) + P04(1.0) + P05(1.0) + P06(1.0) + P07(0.5) + P09(0.5) + P10(0.5) = 7.5
- ボーナス: B01(+0.5) = 0.5
- ペナルティ: 0
- **合計: 7.5 + 0.5 - 0 = 8.0**

### Statistics
- **Mean**: (8.0 + 8.0) / 2 = 8.0
- **SD**: sqrt(((8.0-8.0)² + (8.0-8.0)²) / 2) = 0.0

## Summary

v012-baselineは両実行で完全に同一の検出パターンと採点結果を示した。主な特徴:

1. **高検出率**: 10問中7問を検出（うち5問完全検出、2問部分検出）
2. **未検出問題**: P01（テーブル名複数形使用）、P08（エラーハンドリング明記不足）
3. **安定性**: SD=0.0 により、極めて高い安定性を示す
4. **ボーナス獲得**: B01（外部キー列名不統一）を両実行で検出
5. **ペナルティなし**: スコープ外指摘なし

v012-baselineの強みは一貫性検出の正確性と安定性にあるが、情報欠落系の問題（P08, P09の「既存パターンとの一貫性検証が欠落」という観点）の検出に弱みがある。
