# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 311 | スキル全体のエントリポイント。ワークフロー定義、グループ分類ロジック、Phase 0-3の実行手順を記述 |
| group-classification.md | 22 | グループ分類基準の参照ドキュメント（evaluator/producer/hybrid/unclassified の特徴と判定ルール） |
| templates/apply-improvements.md | 37 | Phase 2 Step 4 で使用される改善適用サブエージェントのテンプレート |
| agents/shared/instruction-clarity.md | 192 | 共通次元: 指示明確性（IC）分析エージェント定義 |
| agents/evaluator/criteria-effectiveness.md | 165 | evaluator/hybrid 次元: 基準有効性（CE）分析エージェント定義 |
| agents/evaluator/scope-alignment.md | 154 | evaluator/hybrid 次元: スコープ整合性（SA）分析エージェント定義 |
| agents/evaluator/detection-coverage.md | 187 | evaluator 固有次元: 検出カバレッジ（DC）分析エージェント定義 |
| agents/producer/workflow-completeness.md | 177 | producer/hybrid 次元: ワークフロー完全性（WC）分析エージェント定義 |
| agents/producer/output-format.md | 182 | producer/hybrid 次元: 出力形式実現性（OF）分析エージェント定義 |
| agents/unclassified/scope-alignment.md | 137 | producer/unclassified 次元: スコープ整合性・軽量版（SA）分析エージェント定義 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 (初期化・グループ分類) → Phase 1 (並列分析) → Phase 2 (ユーザー承認 + 改善適用) → Phase 3 (完了サマリ)
- 各フェーズの目的:
  - **Phase 0**: エージェント定義ファイルを読み込み、内容から agent_group (hybrid/evaluator/producer/unclassified) を判定し、分析次元セットを決定する
  - **Phase 1**: グループに応じた分析次元（3-5個）のサブエージェントを並列起動し、各次元の findings ファイルを生成する
  - **Phase 2**: Phase 1 の findings を収集し、ユーザーが per-item で承認・スキップを選択。承認済み findings を改善適用サブエージェントに渡してエージェント定義を修正する
  - **Phase 3**: 検出数、承認数、変更詳細、バックアップパスを含む完了サマリを出力する
- データフロー:
  - Phase 0 → Phase 1: `{agent_path}`, `{agent_name}`, `{agent_group}`, dimensions テーブル
  - Phase 1 → Phase 2: 各次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）
  - Phase 2 → Phase 3: 承認結果（承認数/スキップ数）、変更詳細（modified/skipped リスト）、バックアップパス

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 243 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2 Step 4 の改善適用サブエージェントテンプレート読み込み |
| SKILL.md | 137-138 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 1 の各次元分析サブエージェントテンプレート読み込み |

**補足**: すべての外部参照は同一スキルディレクトリ (`.claude/skills/agent_audit_new/`) 内であり、真の外部依存はない。

## D. コンテキスト予算分析
- SKILL.md 行数: 311行
- テンプレートファイル数: 7個（分析次元エージェント）+ 1個（改善適用）、平均行数: 166行
- サブエージェント委譲: あり（Phase 1 で 3-5個並列、Phase 2 で 1個直列）
  - Phase 1: グループ判定結果に基づき 3-5 個の分析エージェントを並列起動（model: "sonnet", subagent_type: "general-purpose"）
  - Phase 2: 改善適用エージェントを起動（model: "sonnet", subagent_type: "general-purpose"）
- 親コンテキストに保持される情報:
  - `{agent_content}` (Phase 0 で読み込んだエージェント定義全文、Phase 0 のグループ分類で使用)
  - `{agent_group}`, `{agent_name}`, `{agent_path}` (全フェーズで使用)
  - dimensions テーブル（グループごとの分析次元リスト、Phase 1 のサブエージェント起動に使用）
  - Phase 1 の各サブエージェント返答サマリ（dim, critical, improvement, info 件数）
  - Phase 2 の findings 内容（1回だけ Read し、以降は保持内容を使用）
  - Phase 2 の承認結果（承認/スキップの finding ID リスト、ユーザー修正内容）
  - バックアップパス（Phase 2 で生成、Phase 3 で出力）
- 3ホップパターンの有無: なし（サブエージェントは findings をファイルに保存し、親は findings ファイルを Read して次フェーズに渡す。親が中継する情報は要約のみ）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（1件ずつ確認 / キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認（承認 / スキップ / 残りすべて承認 / キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | 「残りすべて承認」選択時の再確認（はい / いいえ） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: `agent_path` 読み込み失敗時はエラー出力して終了
  - Phase 2 Step 1: findings ファイル不在または空の場合、該当次元を「分析失敗」として扱う
- サブエージェント失敗時:
  - Phase 1: 各サブエージェントの返答フォーマット検証（dim, critical, improvement, info を抽出）。不正な返答または findings ファイル不在/空の場合は「分析失敗（{エラー概要}）」として扱う。全次元失敗時はエラー出力して終了。部分失敗時は成功次元のみ継続
  - Phase 2 Step 4: 改善適用サブエージェントの返答に「modified: 0件」「skipped: {全件数}件」が含まれる場合、全失敗と判定し警告出力。部分成功（modified > 0 かつ skipped > 0）の場合も警告出力
- 部分完了時:
  - Phase 1 で一部の次元が失敗した場合、成功次元のみで Phase 2 へ進む。Phase 3 で失敗次元を明示
  - Phase 2 で一部の改善が skipped された場合、Phase 3 で skipped リストを明示
- 入力バリデーション:
  - Phase 0: ファイル先頭10行以内に `---`、その後100行以内に `description:` が存在するか確認。存在しない場合は警告出力（処理は継続）
  - Phase 2 検証ステップ: 改善適用後、frontmatter セクション比較と変更行数チェック（変更行数が元行数の50%超で警告）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 4行（dim: IC\ncritical: {N}\nimprovement: {M}\ninfo: {K}） | 1-1個（全グループ共通） |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 4行 | 0-1個（evaluator/hybrid のみ） |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 4行 | 0-1個（evaluator/hybrid のみ） |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 4行 | 0-1個（evaluator のみ） |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 4行 | 0-1個（producer/hybrid/unclassified） |
| Phase 1 | sonnet | agents/producer/output-format.md | 4行 | 0-1個（producer/hybrid のみ） |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 4行 | 0-1個（producer/unclassified のみ） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 2行（modified: {N}件\nskipped: {K}件） | 1個 |

**補足**: Phase 1 の並列数は agent_group によって 3-5個に変動する（hybrid: 5個、evaluator: 4個、producer: 4個、unclassified: 3個）
