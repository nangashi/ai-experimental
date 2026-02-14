# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | スキル定義・ワークフロー全体の仕様 |
| agents/evaluator/criteria-effectiveness.md | 185 | CE次元: 評価基準の有効性を分析 |
| agents/evaluator/scope-alignment.md | 169 | SA次元: スコープ整合性を分析（evaluator向け） |
| agents/evaluator/detection-coverage.md | 201 | DC次元: 検出カバレッジを分析 |
| agents/producer/workflow-completeness.md | 191 | WC次元: ワークフロー完全性を分析 |
| agents/producer/output-format.md | 196 | OF次元: 出力形式実現性を分析 |
| agents/shared/instruction-clarity.md | 172 | IC次元: 指示明確性を分析（全グループ共通） |
| agents/unclassified/scope-alignment.md | 151 | SA次元: スコープ整合性を分析（unclassified向け軽量版） |
| group-classification.md | 22 | グループ分類基準定義 |
| templates/apply-improvements.md | 38 | Phase 2 Step 4: 承認済みfindingsをエージェント定義に適用 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 (初期化・グループ分類) → Phase 1 (並列分析) → Phase 2 (ユーザー承認 + 改善適用) → Phase 3 (完了サマリ)
- 各フェーズの目的:
  - **Phase 0**: エージェント定義の読み込み、グループ分類（hybrid/evaluator/producer/unclassified）、分析次元セットの決定、出力ディレクトリ作成
  - **Phase 1**: グループに応じた分析次元セット（3-5次元）を並列分析し、findings ファイルを生成
  - **Phase 2**: findings を収集し、ユーザー承認（全承認/1件ずつ確認/キャンセル）後、サブエージェントで改善適用、検証
  - **Phase 3**: 分析・改善結果のサマリ出力、次ステップの提示
- データフロー:
  - Phase 0: `{agent_path}` を Read → グループ分類 → `.agent_audit/{agent_name}/` ディレクトリ作成
  - Phase 1: 各次元サブエージェントが `{agent_path}` を Read → `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` にfindings保存
  - Phase 2 Step 1: Phase 1 で生成されたfindings ファイル（`.agent_audit/{agent_name}/audit-*.md`）を Read → 対象抽出
  - Phase 2 Step 3: 承認結果を `.agent_audit/{agent_name}/audit-approved.md` に Write
  - Phase 2 Step 4: `audit-approved.md` を Read し、apply-improvements サブエージェントが `{agent_path}` を Edit/Write

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit/group-classification.md` | グループ分類基準の詳細を参照（実際は同一スキル内 `group-classification.md` を参照すべき） |
| SKILL.md | 116 | `.claude/skills/agent_audit/agents/{dim_path}.md` | 分析次元のエージェント定義を参照（実際は同一スキル内 `agents/{dim_path}.md`） |
| SKILL.md | 221 | `.claude/skills/agent_audit/templates/apply-improvements.md` | 改善適用テンプレートを参照（実際は同一スキル内 `templates/apply-improvements.md`） |

**注**: 全ての外部参照が `.claude/skills/agent_audit/` を指しているが、スキル名は `agent_audit_new` であるため、パス不整合がある。正しくは `.claude/skills/agent_audit_new/` を参照すべき。

## D. コンテキスト予算分析
- SKILL.md 行数: 279行
- テンプレートファイル数: 1個（apply-improvements.md 38行）、平均行数: 38行
- 分析エージェントファイル数: 8個（CE, SA×2, DC, WC, OF, IC, group-classification）、平均行数: 約166行
- サブエージェント委譲: あり
  - Phase 1: 3-5個の分析サブエージェント（並列、各1回、sonnet、general-purpose）
  - Phase 2 Step 4: 1個の改善適用サブエージェント（逐次、1回、sonnet、general-purpose）
  - 委譲パターン: 分析・改善作業をサブエージェントに委譲し、親は要約サマリのみ受け取る
- 親コンテキストに保持される情報:
  - エージェント定義全文 (`{agent_content}`, Phase 0で保持、Phase 2検証で再読み込み)
  - グループ分類結果 (`{agent_group}`)
  - エージェント名 (`{agent_name}`)
  - 分析次元リスト
  - Phase 1 サブエージェント返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
  - Phase 2 対象findings一覧（critical + improvement のみ）
  - Phase 2 承認結果（承認数、スキップ数）
- 3ホップパターンの有無: なし
  - Phase 1 サブエージェントの findings はファイル保存され、Phase 2 で親が直接 Read
  - Phase 2 承認結果は audit-approved.md に保存され、apply-improvements サブエージェントが直接 Read

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全承認/1件ずつ/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認判定（承認/スキップ/残りすべて承認/キャンセル） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: agent_path 読み込み失敗 → エラー出力して終了
  - Phase 1: findings ファイル不在または空 → 該当次元を「分析失敗」として扱い、エラー概要を記録、他次元は継続
  - Phase 1: 全次元失敗 → エラー出力して終了
- サブエージェント失敗時:
  - Phase 1: findings ファイルの存在・内容で成否判定。失敗時はエラー概要を抽出し、「分析失敗（{エラー概要}）」と表示、他次元は継続
  - Phase 2 Step 4: 未定義（apply-improvements サブエージェントが失敗した場合のフォールバックなし）
- 部分完了時:
  - Phase 1: 一部次元が失敗しても成功次元の findings を使用してPhase 2 へ継続
  - Phase 2 Step 2a: ユーザーが「残りすべて承認」「キャンセル」を選択すると未確認の findings が存在する状態でStep 3へ進む
- 入力バリデーション:
  - Phase 0: YAML frontmatter の存在チェック（`---` と `description:` の確認）。不在時は警告表示するが処理は継続
  - Phase 2 検証: 改善適用後に YAML frontmatter の存在再確認。失敗時はロールバック手順を提示

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 4行（dim, critical, improvement, info） | グループ依存（3-5並列） |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 4行 | hybrid/evaluatorで並列起動 |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 4行 | hybrid/evaluatorで並列起動 |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 4行 | evaluatorで並列起動 |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 4行 | hybrid/producer/unclassifiedで並列起動 |
| Phase 1 | sonnet | agents/producer/output-format.md | 4行 | hybrid/producerで並列起動 |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 4行 | producer/unclassifiedで並列起動 |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 可変（modified/skipped結果） | 1 |
