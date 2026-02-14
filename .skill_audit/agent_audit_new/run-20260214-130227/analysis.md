# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 344 | スキルメイン定義（ワークフロー、グループ分類、次元マッピング、Phase 0-3 の実行手順） |
| group-classification.md | 22 | グループ分類基準詳細（evaluator/producer/hybrid/unclassified 判定ルール） |
| templates/apply-improvements.md | 38 | Phase 2 Step 4 改善適用サブエージェント用テンプレート（承認済み findings の適用手順、順序決定、二重適用チェック） |
| agents/shared/common-rules.md | 44 | 全次元エージェント共通ルール定義（Severity/Impact/Effort 定義、2フェーズアプローチ、Adversarial Thinking） |
| agents/shared/instruction-clarity.md | 211 | IC 次元（指示明確性分析）— ドキュメント構造、役割定義、コンテキスト充足、指示有効性を評価 |
| agents/evaluator/criteria-effectiveness.md | 188 | CE 次元（基準有効性分析）— 評価基準の明確性、S/N比、実行可能性、費用対効果を評価 |
| agents/evaluator/scope-alignment.md | 173 | SA 次元（スコープ整合性分析・evaluator版）— スコープ定義、境界明確性、内部整合性、カバレッジを評価 |
| agents/evaluator/detection-coverage.md | 206 | DC 次元（検出カバレッジ分析）— 検出戦略完全性、severity分類、出力形式、偽陽性リスクを評価 |
| agents/producer/workflow-completeness.md | 196 | WC 次元（ワークフロー完全性分析）— ステップ順序、依存関係、データフロー、エラーパス、条件分岐を評価 |
| agents/producer/output-format.md | 200 | OF 次元（出力形式実現性分析）— 出力形式の実現可能性、下流利用可能性、情報完全性、整合性を評価 |
| agents/unclassified/scope-alignment.md | 155 | SA 次元（スコープ整合性分析・軽量版）— 目的明確性、フォーカス適切性、境界暗黙性を評価 |

## B. ワークフロー概要
- フェーズ構成: Phase 0（初期化・グループ分類） → Phase 1（並列分析） → Phase 2（ユーザー承認 + 改善適用） → Phase 3（完了サマリ）
- 各フェーズの目的:
  - **Phase 0**: エージェント定義ファイルを読み込み、内容に基づき4グループ（hybrid/evaluator/producer/unclassified）に分類し、グループごとの分析次元セットを決定する
  - **Phase 1**: 決定した次元セット（3-5次元）のサブエージェントを並列起動し、各次元の findings を `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に保存する
  - **Phase 2**: 全次元の findings を収集し、ユーザーに一覧提示→承認方針確認（全て承認/1件ずつ確認/キャンセル）→承認済みを audit-approved.md に保存→サブエージェントで改善適用→検証
  - **Phase 3**: 分析・承認・適用結果のサマリを表示し、次のステップ（再監査 or 構造最適化）を提示する
- データフロー:
  - Phase 0: `{agent_path}` を Read → グループ分類 → 分析次元セット決定
  - Phase 1: 各次元サブエージェントが `{agent_path}` を Read → findings を `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に Write
  - Phase 2 Step 1: 収集サブエージェント（haiku）が Phase 1 の全 findings ファイルを Read → critical/improvement 抽出 → 一覧返答
  - Phase 2 Step 2-2a: ユーザー承認ループ → 承認済み findings を `audit-approved.md` に Write
  - Phase 2 Step 4: 改善適用サブエージェント（sonnet）が `audit-approved.md` + `{agent_path}` を Read → Edit/Write で改善適用
  - Phase 2 検証: `{agent_path}` を Read → frontmatter 確認
  - Phase 3: Phase 1/2 で収集したメタデータをサマリ表示

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 96 | `.claude/skills/agent_audit_new/group-classification.md` | グループ分類基準詳細の参照（Phase 0 Step 4 グループ判定） |
| agents/shared/instruction-clarity.md | 27 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 2フェーズアプローチ、Severity Rules、Adversarial Thinking の参照 |
| agents/shared/instruction-clarity.md | 157 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | Severity 定義の参照（Phase 2） |
| agents/evaluator/criteria-effectiveness.md | 27 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 2フェーズアプローチ、Severity Rules、Adversarial Thinking の参照 |
| agents/evaluator/criteria-effectiveness.md | 129 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | Severity 定義の参照（Phase 2） |
| agents/evaluator/scope-alignment.md | 25 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 2フェーズアプローチ、Severity Rules、Adversarial Thinking の参照 |
| agents/evaluator/scope-alignment.md | 120 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | Severity 定義の参照（Phase 2） |
| agents/evaluator/detection-coverage.md | 18 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 2フェーズアプローチ、Severity Rules、Adversarial Thinking の参照 |
| agents/evaluator/detection-coverage.md | 143 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | Severity 定義の参照（Phase 2） |
| agents/producer/workflow-completeness.md | 27 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 2フェーズアプローチ、Severity Rules、Adversarial Thinking の参照 |
| agents/producer/workflow-completeness.md | 144 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | Severity 定義の参照（Phase 2） |
| agents/producer/output-format.md | 27 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 2フェーズアプローチ、Severity Rules、Adversarial Thinking の参照 |
| agents/producer/output-format.md | 150 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | Severity 定義の参照（Phase 2） |
| agents/unclassified/scope-alignment.md | 17 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 2フェーズアプローチ、Severity Rules、Adversarial Thinking の参照 |
| agents/unclassified/scope-alignment.md | 94 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | Severity 定義の参照（Phase 2） |
| SKILL.md | 269 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2 Step 4 改善適用サブエージェント用テンプレート参照 |

**注**: 全ての外部参照はスキルディレクトリ（`.claude/skills/agent_audit_new/`）内の相対パスであり、スキル外部への依存は存在しない。

## D. コンテキスト予算分析
- SKILL.md 行数: 344行
- テンプレートファイル数: 1個（apply-improvements.md）、行数: 38行
- 次元エージェント定義ファイル数: 7個、平均行数: 約 196行（範囲: 155-211行）
- 共通参照ファイル数: 2個（common-rules.md 44行, group-classification.md 22行）
- サブエージェント委譲: あり
  - **Phase 1**: `{dim_count}` 個（3-5個）の並列サブエージェント（sonnet, general-purpose）を起動し、各次元エージェント定義（155-211行）を Read して分析を実行させる。各サブエージェントは `{agent_path}` の全内容を自身のコンテキストに保持する。
  - **Phase 2 Step 1**: 1個のサブエージェント（haiku, general-purpose）が全次元の findings ファイルを Read し、critical/improvement 抽出してテーブル形式で返答
  - **Phase 2 Step 4**: 1個のサブエージェント（sonnet, general-purpose）が apply-improvements.md（38行）+ audit-approved.md + `{agent_path}` を Read して改善適用
- 親コンテキストに保持される情報:
  - パス変数（`{agent_path}`, `{agent_name}`, `{agent_group}`, `{findings_save_path}`, `{approved_findings_path}`, `{backup_path}`）
  - グループ分類結果と分析次元セット（dimensions リスト、`{dim_count}`）
  - Phase 1 各次元の返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` の形式、または「分析失敗」フラグ）
  - Phase 2 承認ステータス（`{total}`, `{承認数}`, `{スキップ数}`）
  - フラグ（`{frontmatter_warning}`）
- 3ホップパターンの有無: なし
  - Phase 1 の各サブエージェントは findings ファイルに Write、Phase 2 Step 1 サブエージェントは findings ファイルから Read して親に返答。親→サブ1→ファイル→サブ2→親のファイル経由2ホップパターンである。

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 Step 1 | AskUserQuestion | `agent_path` が未指定の場合、ファイルパスを確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認（承認/スキップ/残りすべて承認/キャンセル） | 不明 |

**Fast mode 対応なし**: SKILL.md に fast mode スキップに関する記述はない。

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0 Step 2: `{agent_path}` の Read 失敗時、エラー出力して終了
  - Phase 1: findings ファイルが存在しない or 空の場合、該当次元を「分析失敗」として扱う。全次元失敗時はエラー出力して終了
- サブエージェント失敗時:
  - Phase 1: 各サブエージェントの成否を findings ファイルの存在と Summary セクションで判定。失敗時は Task 返答からエラー概要を抽出し、「分析失敗（{エラー概要}）」として Phase 1 完了サマリに記録。全次元失敗時はエラー出力して終了
  - Phase 2 Step 1, Step 4: 明示的なエラーハンドリング記述なし（サブエージェント完了を仮定）
- 部分完了時:
  - Phase 1: 一部の次元が成功すれば Phase 2 に進む（`{成功数}/{dim_count}` を表示）
  - Phase 2 検証失敗時: ロールバックコマンドを表示し、Phase 3 の改善適用結果詳細表示をスキップして警告のみ表示
- 入力バリデーション:
  - Phase 0 Step 3: frontmatter 簡易チェック（`description:` を含む YAML frontmatter の存在確認）。存在しない場合、警告フラグ `{frontmatter_warning}` を設定し警告テキスト出力（処理は継続）
  - Phase 2 検証: 改善適用後に frontmatter 再確認。失敗時はロールバック指示を表示

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/{dim_path}.md（155-211行、次元により異なる） | 4行（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`） | 3-5個（`{dim_count}` に依存、グループにより異なる） |
| Phase 2 Step 1 | haiku | なし（プロンプト内で指示を直接記述） | 可変（テーブル形式、対象 finding 数に依存） | 1個 |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md（38行） | 可変（`modified: {N}件` + `skipped: {K}件` の形式、各 finding ごとに1行） | 1個 |

**注**: Phase 1 の並列数はグループにより異なる（hybrid: 5, evaluator: 4, producer: 4, unclassified: 3）
