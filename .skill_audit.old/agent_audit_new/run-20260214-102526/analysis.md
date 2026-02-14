# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 319 | スキルのメインエントリポイント、全体ワークフロー定義、グループ分類ロジック |
| group-classification.md | 22 | エージェントのグループ（evaluator/producer/hybrid/unclassified）分類基準 |
| agents/evaluator/criteria-effectiveness.md | 185 | CE次元: 評価基準の有効性（S/N比、実行可能性、費用対効果）を分析するレビューアー |
| agents/evaluator/scope-alignment.md | 169 | SA次元（evaluator用）: スコープ定義の明確性、境界の曖昧さ、ドメインカバレッジを分析するレビューアー |
| agents/evaluator/detection-coverage.md | 200 | DC次元: 検出戦略の完全性、severity分類整合性、出力形式有効性を分析するレビューアー |
| agents/producer/workflow-completeness.md | 191 | WC次元: ワークフロー完全性（ステップ依存、エラーパス、データフロー）を分析するレビューアー |
| agents/producer/output-format.md | 196 | OF次元: 出力形式の実現可能性、下流利用可能性を分析するレビューアー |
| agents/unclassified/scope-alignment.md | 151 | SA次元（unclassified用）: 目的明確性、フォーカス適切性、境界暗黙性を分析する軽量版レビューアー |
| agents/shared/instruction-clarity.md | 206 | IC次元（全グループ共通）: 指示の明確性、役割定義、コンテキスト充足、情報構造を分析するレビューアー |
| templates/apply-improvements.md | 38 | Phase 2 Step 4: 承認済み findings を元にエージェント定義を改善するサブエージェント用テンプレート |
| templates/phase1-parallel-analysis.md | 15 | Phase 1: 各次元分析を並列実行するサブエージェント起動用テンプレート |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的（1行ずつ）:
  - **Phase 0（初期化・グループ分類）**: エージェント定義の読み込み、frontmatter検証、グループ分類（evaluator/producer/hybrid/unclassified）、分析次元セット決定、出力ディレクトリ作成
  - **Phase 1（並列分析）**: グループごとに決定された分析次元セット（3-5次元）をサブエージェントで並列分析し、各次元の findings を `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に保存
  - **Phase 2（ユーザー承認 + 改善適用）**: critical/improvement findings を収集、ユーザーに一覧提示、承認方針選択（全承認/1件ずつ確認/キャンセル）、承認結果保存、バックアップ作成、サブエージェントで改善適用、検証
  - **Phase 3（完了サマリ）**: 検出件数、承認結果、変更詳細、次ステップ（再監査 or agent_bench）を出力
- データフロー:
  - Phase 0 → Phase 1: `{agent_content}`（メインコンテキスト）、`{agent_name}`, `{agent_group}`, `{dimensions}` → サブエージェントへ渡す変数
  - Phase 1 → Phase 2: `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`（各次元の findings ファイル）をサブエージェントが生成 → 親が Read で収集
  - Phase 2 Step 2 → Step 3: ユーザー承認結果（承認/スキップ/修正内容）→ `.agent_audit/{agent_name}/audit-approved.md` に保存
  - Phase 2 Step 3 → Step 4: `.agent_audit/{agent_name}/audit-approved.md` → サブエージェント（apply-improvements）が Read して改善適用
  - Phase 2 Step 4 → Phase 3: 変更サマリ（modified/skipped）→ 親コンテキストに保持

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 70 | `.claude/skills/agent_audit_new/group-classification.md` | グループ分類基準の詳細参照 |
| SKILL.md | 121 | `.claude/skills/agent_audit_new/templates/phase1-parallel-analysis.md` | Phase 1 サブエージェント起動テンプレート |
| SKILL.md | 242 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2 Step 4 改善適用サブエージェント起動テンプレート |
| templates/phase1-parallel-analysis.md | 3 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | 各次元のレビューアーエージェント定義（動的パス） |

**補足**: 外部参照は全て `{skill_path}` 内の相対参照であり、スキル外のパスへの依存はない。

## D. コンテキスト予算分析
- SKILL.md 行数: 319行
- テンプレートファイル数: 2個、平均行数: 26.5行
- サブエージェント委譲: あり（Phase 1 で 3-5次元を並列起動、Phase 2 Step 4 で改善適用を委譲）
  - **Phase 1**: グループごとに 3-5 個の並列サブエージェント（model: "sonnet", subagent_type: "general-purpose"）
  - **Phase 2 Step 4**: 1 個のサブエージェント（model: "sonnet", subagent_type: "general-purpose"）
- 親コンテキストに保持される情報:
  - `{agent_content}`: エージェント定義の全文（Phase 0 で Read、Phase 1 のサブエージェントに渡す）
  - `{agent_group}`, `{agent_name}`, `{dimensions}`: グループ分類結果とメタデータ
  - Phase 1 サブエージェント返答: 各次元の「dim: XX, critical: N, improvement: M, info: K」のみ（詳細は findings ファイルに保存）
  - Phase 2 承認ループ: critical/improvement findings の一覧（severity, ID, title, 次元名）
  - Phase 2 Step 4 サブエージェント返答: 変更サマリ（modified: N件, skipped: K件）のみ
- 3ホップパターンの有無: **なし**
  - Phase 1 サブエージェントは findings ファイルを直接生成、親は Read で収集
  - Phase 2 Step 4 サブエージェントは approved-findings ファイルを直接 Read、親を経由しない

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0, Step 1 | AskUserQuestion | `agent_path` 未指定時に確認 | 不明 |
| Phase 2, Step 2 | AskUserQuestion | 承認方針選択（全承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2, Step 2a | AskUserQuestion | Per-item 承認（承認/スキップ/残り全承認/キャンセル） | 不明 |
| Phase 2, Step 3 | AskUserQuestion | 既存 approved.md 上書き確認 | 不明 |
| Phase 2, Step 4 | AskUserQuestion | バックアップ失敗時の続行確認 | 不明 |

**補足**: SKILL.md に Fast mode での明示的な扱いの記載なし。

## F. エラーハンドリングパターン
- ファイル不在時:
  - `{agent_path}` 読み込み失敗時: エラー出力して終了（Phase 0, Step 2）
  - YAML frontmatter 不在時: 警告出力して処理継続（Phase 0, Step 3）
  - Phase 1 findings ファイル不在時: 該当次元を「分析失敗（{エラー概要}）」として扱う（Phase 1 エラーハンドリング）
  - `.agent_audit/{agent_name}/audit-approved.md` 存在時: 上書き確認 → キャンセル選択時は承認メタデータ設定（{approved}=0, {skip}=0）で Phase 3 へ（Phase 2, Step 3）
- サブエージェント失敗時:
  - Phase 1: 各サブエージェントの成否を findings ファイルの存在・非空で判定。全失敗時はエラー出力して終了。部分失敗時は成功した次元のみ処理継続
  - Phase 2 Step 4: 返答内容に "modified:" 含まず、またはファイル更新時刻がバックアップ作成前 → ロールバック（`cp {backup_path} {agent_path}`）してエラー出力、Phase 3 へ
- 部分完了時:
  - Phase 1 で一部次元のみ成功 → 成功した次元の findings のみ Phase 2 へ進む
  - Phase 2 で承認数 0 → 「全ての指摘がスキップされました」と出力、Phase 3 へ直行
- 入力バリデーション:
  - YAML frontmatter 検証（Phase 0, Step 3）
  - Phase 2 検証ステップ: 改善適用後に frontmatter 再検証、承認 findings の変更対象キーワード 80% 以上存在確認

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1（並列分析） | sonnet | templates/phase1-parallel-analysis.md（15行）→ agents/{dim_path}.md（151-206行） | 4行（"dim: XX, critical: N, improvement: M, info: K"） | 3-5個（グループ依存: hybrid=5, evaluator=4, producer=4, unclassified=3） |
| Phase 2 Step 4（改善適用） | sonnet | templates/apply-improvements.md（38行） | 2セクション（"modified: N件 + 詳細", "skipped: K件 + 詳細"） | 1個 |
