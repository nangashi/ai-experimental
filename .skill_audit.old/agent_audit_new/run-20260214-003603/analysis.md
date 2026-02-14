# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 305 | メインスキル定義。Phase 0-3 のワークフロー、グループ分類ルール、次元マッピング、エラーハンドリングを定義 |
| group-classification.md | 22 | evaluator/producer/hybrid/unclassified 4グループの分類基準 |
| templates/apply-improvements.md | 43 | Phase 2 Step 4: 承認済み findings をエージェント定義に適用するテンプレート |
| antipatterns/instruction-clarity.md | 81 | IC 次元の既知アンチパターンカタログ（Role Definition, Context, Structural 等） |
| antipatterns/criteria-effectiveness.md | 93 | CE 次元の既知アンチパターンカタログ（Vagueness, Feasibility, Efficiency 等） |
| antipatterns/scope-alignment.md | 34 | SA 次元の既知アンチパターンカタログ（Quality Sprawl, Scope Drift, Coverage 等） |
| antipatterns/detection-coverage.md | 73 | DC 次元の既知アンチパターンカタログ（Implicit Detection, Severity Overlap 等） |
| antipatterns/workflow-completeness.md | 87 | WC 次元の既知アンチパターンカタログ（Dependencies, Data Flow, Error Paths 等） |
| antipatterns/output-format.md | 66 | OF 次元の既知アンチパターンカタログ（Infeasible Requirements, Quantitative from Qualitative 等） |
| agents/shared/instruction-clarity.md | 122 | IC 次元エージェント。5検出戦略（Document Structure, Role Definition, Context, Instruction Effectiveness, Antipatterns）× 2フェーズ |
| agents/evaluator/criteria-effectiveness.md | 89 | CE 次元エージェント。5検出戦略（Inventory, Adversarial, Feasibility, Cross-Criteria, Antipatterns）× 2フェーズ |
| agents/evaluator/scope-alignment.md | 105 | SA 次元エージェント（evaluator 用）。5検出戦略（Scope Inventory, Boundary, Consistency, Adversarial Scope, Criteria-Domain Coverage）× 2フェーズ |
| agents/evaluator/detection-coverage.md | 110 | DC 次元エージェント。5検出戦略（Detection Strategy Audit, Severity Robustness, Output Evidence, False Positive, Antipatterns）× 2フェーズ |
| agents/producer/workflow-completeness.md | 107 | WC 次元エージェント。5検出戦略（Topology Mapping, Data Flow Tracing, Error Path, Conditional Logic, Antipatterns）× 2フェーズ |
| agents/producer/output-format.md | 115 | OF 次元エージェント。5検出戦略（Achievability, Downstream Compatibility, Information Completeness, Cross-Section Consistency, Antipatterns）× 2フェーズ |
| agents/unclassified/scope-alignment.md | 81 | SA 次元エージェント（unclassified 用・軽量版）。4検出戦略（Purpose Clarity, Focus Coherence, Boundary Awareness, Antipatterns）× 2フェーズ |
| agent_bench/SKILL.md | 372 | agent_bench スキル本体（構造最適化用の別スキル） |
| agent_bench/approach-catalog.md | 202 | バリアント生成のためのアプローチカタログ（S/C/N/M カテゴリ、102バリエーション） |
| agent_bench/proven-techniques.md | 70 | 実証済みテクニック集（効果テクニック 8件、アンチパターン 8件、条件付き 7件） |
| agent_bench/scoring-rubric.md | 70 | 採点基準（検出判定 ○△×、スコア計算式、推奨判定基準、収束判定） |
| agent_bench/test-document-guide.md | 254 | テスト対象文書生成ガイド（入力型判定、文書構成、問題埋め込みルール） |
| agent_bench/templates/knowledge-init-template.md | 53 | Phase 0: knowledge.md 初期化テンプレート |
| agent_bench/templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回バリアント生成テンプレート |
| agent_bench/templates/phase1b-variant-generation.md | 32 | Phase 1B: 継続バリアント生成テンプレート |
| agent_bench/templates/phase2-test-document.md | 20 | Phase 2: テスト文書生成テンプレート |
| agent_bench/templates/phase4-scoring.md | 13 | Phase 4: 採点テンプレート |
| agent_bench/templates/phase5-analysis-report.md | 20 | Phase 5: 分析レポート生成テンプレート |
| agent_bench/templates/phase6a-knowledge-update.md | 23 | Phase 6A: knowledge.md 更新テンプレート |
| agent_bench/templates/phase6b-proven-techniques-update.md | 51 | Phase 6B: proven-techniques.md 更新テンプレート |
| agent_bench/templates/perspective/generate-perspective.md | 67 | Phase 0: perspective 自動生成テンプレート |
| agent_bench/templates/perspective/critic-completeness.md | 101 | perspective 自動生成の批評エージェント（網羅性評価） |
| agent_bench/templates/perspective/critic-clarity.md | 74 | perspective 自動生成の批評エージェント（明確性評価） |
| agent_bench/templates/perspective/critic-effectiveness.md | 73 | perspective 自動生成の批評エージェント（有効性評価） |
| agent_bench/templates/perspective/critic-generality.md | 81 | perspective 自動生成の批評エージェント（汎用性評価） |
| agent_bench/perspectives/design/security.md | 43 | design 用 security perspective |
| agent_bench/perspectives/design/performance.md | 45 | design 用 performance perspective |
| agent_bench/perspectives/design/structural-quality.md | 41 | design 用 structural-quality perspective |
| agent_bench/perspectives/design/consistency.md | 51 | design 用 consistency perspective |
| agent_bench/perspectives/design/reliability.md | 43 | design 用 reliability perspective |
| agent_bench/perspectives/design/old/maintainability.md | 43 | （旧）design 用 maintainability perspective |
| agent_bench/perspectives/design/old/best-practices.md | 34 | （旧）design 用 best-practices perspective |
| agent_bench/perspectives/code/security.md | 37 | code 用 security perspective |
| agent_bench/perspectives/code/performance.md | 37 | code 用 performance perspective |
| agent_bench/perspectives/code/best-practices.md | 34 | code 用 best-practices perspective |
| agent_bench/perspectives/code/consistency.md | 33 | code 用 consistency perspective |
| agent_bench/perspectives/code/maintainability.md | 34 | code 用 maintainability perspective |

## B. ワークフロー概要
- フェーズ構成: Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）
- 各フェーズの目的:
  - **Phase 0**: エージェント読み込み、agent_name 導出、frontmatter 検証、グループ分類（evaluator/producer/hybrid/unclassified）、分析次元セット決定、出力ディレクトリ作成
  - **Phase 1**: 各次元エージェントを並列起動し、findings ファイルに保存。成功/失敗を判定。全失敗時はエラー終了、部分失敗時は警告継続
  - **Phase 2**: findings 集計 → 承認方針選択（全承認/1件ずつ確認/キャンセル）→ per-item 承認ループ（オプション）→ 承認結果保存 → バックアップ作成 → apply-improvements サブエージェント起動 → 検証（構造検証、成果物検証）→ ロールバック判定
  - **Phase 3**: 完了サマリ出力。承認結果、変更詳細、バックアップパス、次のステップ（critical 承認時は再実行推奨、improvement のみは agent_bench 推奨）
- データフロー:
  - Phase 0 → Phase 1: agent_path, agent_name, dimensions
  - Phase 1 → Phase 2: findings ファイルパス（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）
  - Phase 2 → Phase 3: approved findings, 変更サマリ, backup_path

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 115 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 1 で各次元エージェントを参照 |
| SKILL.md | 174 | `.agent_audit/{agent_name}/audit-*.md` | Phase 1B で agent_bench の audit findings を参照（agent_bench との連携用） |
| agents/shared/instruction-clarity.md | 118 | `.claude/skills/agent_audit_new/antipatterns/instruction-clarity.md` | IC 次元のアンチパターンカタログ参照 |
| agents/evaluator/criteria-effectiveness.md | 84 | `.claude/skills/agent_audit_new/antipatterns/criteria-effectiveness.md` | CE 次元のアンチパターンカタログ参照 |
| agents/evaluator/scope-alignment.md | 80 | `.claude/skills/agent_audit_new/antipatterns/scope-alignment.md` | SA 次元のアンチパターンカタログ参照 |
| agents/evaluator/detection-coverage.md | 105 | `.claude/skills/agent_audit_new/antipatterns/detection-coverage.md` | DC 次元のアンチパターンカタログ参照 |
| agents/producer/workflow-completeness.md | 102 | `.claude/skills/agent_audit_new/antipatterns/workflow-completeness.md` | WC 次元のアンチパターンカタログ参照 |
| agents/producer/output-format.md | 110 | `.claude/skills/agent_audit_new/antipatterns/output-format.md` | OF 次元のアンチパターンカタログ参照 |
| agents/unclassified/scope-alignment.md | 74 | `.claude/skills/agent_audit_new/antipatterns/scope-alignment.md` | SA 次元のアンチパターンカタログ参照 |
| SKILL.md | 174 | `.agent_bench/{agent_name}/` | agent_bench スキルの出力ディレクトリを参照（audit findings 入力用） |

## D. コンテキスト予算分析
- SKILL.md 行数: 305行
- テンプレートファイル数: 1個（apply-improvements.md）、平均行数: 43行
- サブエージェント委譲: あり
  - Phase 1: 3-5個の次元エージェントを並列起動（グループに応じて可変）
  - Phase 2 Step 4: 1個の apply-improvements サブエージェント起動
- 親コンテキストに保持される情報:
  - agent_path, agent_name, agent_group, dim_count, dimensions リスト
  - Phase 1 各次元の返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
  - findings ファイルパスリスト（Read は実行しない）
  - 承認方針とユーザー判定結果（per-item の場合）
  - apply-improvements サブエージェントの返答（変更サマリ）
- 3ホップパターンの有無: なし（全データフローはファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | 引数 agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | frontmatter 不在時の続行確認 | 不明 |
| Phase 1 | AskUserQuestion | いずれかのプロンプトで成功結果が0回の場合の確認（再試行/除外/中断） | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認（承認/スキップ/残りすべて承認/キャンセル） | 不明 |
| Phase 2 Step 4 | AskUserQuestion | 改善適用失敗時の確認（再試行/Phase 3へスキップ/キャンセル） | 不明 |
| Phase 2 検証 | AskUserQuestion | 検証失敗時のロールバック確認 | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時: Phase 0 で agent_path 読み込み失敗 → エラー出力して終了
- サブエージェント失敗時:
  - Phase 1: findings ファイルの存在で判定。全失敗 → エラー終了、部分失敗 → 警告継続
  - Phase 2 Step 4: AskUserQuestion で再試行/スキップ/キャンセル確認
- 部分完了時: Phase 1 で部分失敗の場合、成功した次元のみで Phase 2 続行
- 入力バリデーション: Phase 0 で frontmatter の簡易チェック。不在時は AskUserQuestion で確認

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 1 | 1（共通次元） |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 1 | 1（hybrid/evaluator） |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 1 | 1（hybrid/evaluator） |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 1 | 1（evaluator のみ） |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 1 | 1（hybrid/producer/unclassified） |
| Phase 1 | sonnet | agents/producer/output-format.md | 1 | 1（hybrid/producer） |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 1 | 1（producer/unclassified） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 2 | 1 |
