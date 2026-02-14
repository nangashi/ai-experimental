# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 350 | スキル定義メイン — ワークフロー、グループ分類、次元マッピング |
| group-classification.md | 22 | エージェントグループ分類基準詳細（evaluator/producer/hybrid/unclassified） |
| templates/apply-improvements.md | 38 | Phase 2 Step 4 改善適用テンプレート（承認済み findings の適用ロジック） |
| templates/collect-findings.md | 58 | Phase 2 Step 1 findings 収集テンプレート（critical/improvement 抽出とソート） |
| agents/shared/common-rules.md | 44 | 全次元エージェント共通のルール定義（Severity Rules, Impact/Effort 定義、検出戦略の共通パターン） |
| agents/evaluator/criteria-effectiveness.md | 195 | CE 次元（基準有効性分析）— 評価基準の明確性、S/N比、実行可能性、費用対効果を検証 |
| agents/evaluator/scope-alignment.md | 180 | SA 次元（スコープ整合性分析）— evaluator 向け、スコープ定義・境界・内部整合性を検証 |
| agents/evaluator/detection-coverage.md | 213 | DC 次元（検出カバレッジ分析）— 検出戦略完全性、severity 分類、出力形式、偽陽性リスク |
| agents/producer/workflow-completeness.md | 203 | WC 次元（ワークフロー完全性分析）— ステップ順序、データフロー、エラーパス、条件分岐 |
| agents/producer/output-format.md | 208 | OF 次元（出力形式実現性分析）— 出力形式の実現可能性、下流利用可能性、情報完全性 |
| agents/shared/instruction-clarity.md | 218 | IC 次元（指示明確性分析）— ドキュメント構造、役割定義、コンテキスト充足、指示有効性 |
| agents/unclassified/scope-alignment.md | 162 | SA 次元（スコープ整合性分析・軽量版）— unclassified/producer 向け、目的明確性とフォーカス適切性 |

## B. ワークフロー概要

### フェーズ構成
Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）

### 各フェーズの目的
- **Phase 0**: エージェント定義ファイルの読み込み、YAML frontmatter チェック、グループ分類（hybrid/evaluator/producer/unclassified）、分析次元セットの決定、出力ディレクトリ作成
- **Phase 1**: グループに応じた分析次元セット（3～5次元）を並列起動し、各次元で critical/improvement/info の findings を生成
- **Phase 2**: findings の収集（Step 1）、ユーザー承認方針の選択（Step 2）、per-item 承認（Step 2a）、承認結果の保存（Step 3）、改善適用（Step 4）、検証ステップ
- **Phase 3**: 完了サマリ出力（検出件数、承認件数、変更詳細、次のステップ提案）

### データフロー
- **Phase 0 → Phase 1**: `{agent_path}`（入力ファイル）、`{agent_group}`（分類結果）、`{dimensions}`（次元セット）
- **Phase 1 生成**: `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`（各次元の findings ファイル）
- **Phase 2 Step 1 生成**: `.agent_audit/{agent_name}/findings-summary.md`（対象 findings の一覧）
- **Phase 2 Step 3 生成**: `.agent_audit/{agent_name}/audit-approved.md`（承認済み findings）
- **Phase 2 Step 4 参照**: `audit-approved.md` → 改善適用 → `{agent_path}` の変更、`{backup_path}` の作成
- **Phase 3 参照**: Phase 1 の件数サマリ、Phase 2 の承認結果、Step 4 のサブエージェント返答

## C. 外部参照の検出

| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 96 | `.claude/skills/agent_audit_new/group-classification.md` | グループ分類基準の詳細参照 |
| SKILL.md | 155 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 各次元エージェントに共通ルール定義のパスを渡す |
| SKILL.md | 189 | `.claude/skills/agent_audit_new/templates/collect-findings.md` | Phase 2 Step 1 で findings 収集テンプレートを起動 |
| SKILL.md | 267 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2 Step 4 で改善適用テンプレートを起動 |
| agents/evaluator/criteria-effectiveness.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数経由） |
| agents/evaluator/scope-alignment.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数経由） |
| agents/evaluator/detection-coverage.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数経由） |
| agents/producer/workflow-completeness.md | 18 | `{common_rules_path}` | 共通ルール定義の読み込み（変数経由） |
| agents/producer/output-format.md | 17 | `{common_rules_path}` | 共通ルール定義の読み込み（変数経由） |
| agents/shared/instruction-clarity.md | 15 | `{common_rules_path}` | 共通ルール定義の読み込み（変数経由） |
| agents/unclassified/scope-alignment.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数経由） |

**注記**: 全外部参照は `.claude/skills/agent_audit_new/` 配下に限定されており、スキル外への参照はない。各次元エージェントは `{common_rules_path}` をパス変数で受け取るため、スキル外への依存はない。

## D. コンテキスト予算分析

- **SKILL.md 行数**: 350行
- **テンプレートファイル数**: 2個、平均行数: 48行（apply-improvements: 38行、collect-findings: 58行）
- **サブエージェント委譲**: あり
  - **Phase 1**: グループに応じた3～5次元を並列起動（各 sonnet サブエージェント、返答形式: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
  - **Phase 2 Step 1**: findings 収集（haiku サブエージェント、返答形式: `total: {N}, critical: {M}, improvement: {K}`）
  - **Phase 2 Step 4**: 改善適用（sonnet サブエージェント、返答形式: `modified: {N}件, skipped: {K}件` の詳細リスト）
- **親コンテキストに保持される情報**:
  - グループ分類結果（`{agent_group}`）
  - 分析次元セット（`{dimensions}`、3～5要素のリスト）
  - Phase 1 の各次元の件数サマリ（critical/improvement/info の3値 × 次元数）
  - Phase 2 の承認方針（全承認/1件ずつ確認/キャンセル）、承認結果（承認数/スキップ数/total）
  - Phase 2 Step 4 の変更サマリ（変更件数、スキップ件数）
  - エージェント定義の全文は**保持しない**（サブエージェントが直接 Read する）
- **3ホップパターンの有無**: なし
  - Phase 1 の findings は各次元エージェントが直接ファイルに保存し、Phase 2 Step 1 でファイル経由で収集する
  - Phase 2 Step 3 の承認結果は親がファイルに保存し、Step 4 でファイル経由でサブエージェントに渡す

## E. ユーザーインタラクションポイント

| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | `agent_path` 未指定時の確認 | 不明（fast mode への言及なし） |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全承認/1件ずつ確認/キャンセル） | 不明（fast mode への言及なし） |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認（承認/スキップ/残りすべて承認/キャンセル） | 不明（fast mode への言及なし） |
| Phase 2 Step 4 | AskUserQuestion | 改善適用失敗時の方針確認（リトライ/ロールバックして終了/強制的に検証ステップへ進む） | 不明（fast mode への言及なし） |

**注記**: SKILL.md には fast mode への言及がないため、全ユーザーインタラクションで fast mode スキップのロジックは未定義。

## F. エラーハンドリングパターン

- **ファイル不在時**: Phase 0 でエージェント定義ファイルの Read 失敗時はエラー出力して終了。Phase 2 Step 4 でバックアップ作成前の cp 失敗は未定義（失敗時の処理記載なし）
- **サブエージェント失敗時**:
  - **Phase 1**: 各次元の findings ファイル存在確認で成否を判定。全次元失敗時はエラー出力して終了。一部失敗時は成功した次元のみで継続。
  - **Phase 2 Step 1**: findings 収集失敗時の処理は未定義（返答形式のみ記載）
  - **Phase 2 Step 4**: 改善適用失敗時は失敗キーワード検出でリトライ/ロールバック/強制的に進むの方針をユーザーに確認。リトライは1回のみ。
- **部分完了時**: Phase 1 で一部の次元が失敗した場合、成功した次元の結果で Phase 2 に進む（明示的記載あり）
- **入力バリデーション**: Phase 0 で YAML frontmatter の存在確認を行い、frontmatter 欠落時は警告フラグを設定して処理を継続（エージェント定義でない可能性を警告）

## G. サブエージェント一覧

| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | `agents/{dim_path}.md` (7種類の次元エージェント) | 4行（`dim:`, `critical:`, `improvement:`, `info:`） | 3～5（グループに応じた次元数） |
| Phase 2 Step 1 | haiku | `templates/collect-findings.md` | 3行（`total:`, `critical:`, `improvement:`） | 1 |
| Phase 2 Step 4 | sonnet | `templates/apply-improvements.md` | 可変（`modified:` と `skipped:` のリスト） | 1 |
