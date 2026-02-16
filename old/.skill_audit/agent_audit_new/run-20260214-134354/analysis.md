# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 360 | スキル定義メイン（ワークフロー、グループ分類、次元マッピング、Phase 0-3 の詳細手順） |
| group-classification.md | 22 | グループ分類基準詳細（evaluator/producer 特徴定義と判定ルール） |
| templates/apply-improvements.md | 38 | Phase 2 Step 4 改善適用テンプレート（Edit/Write による変更適用ロジック） |
| templates/collect-findings.md | 73 | Phase 2 Step 1 findings 収集テンプレート（critical/improvement 抽出・ソート） |
| agents/shared/common-rules.md | 44 | 全次元エージェント共通のルール定義（Severity/Impact/Effort 定義、検出戦略パターン） |
| agents/evaluator/criteria-effectiveness.md | 195 | CE 次元（基準有効性分析：S/N比、実行可能性、費用対効果） |
| agents/evaluator/scope-alignment.md | 180 | SA 次元（スコープ整合性分析：境界明確性、内部整合性、カバレッジ）- evaluator 向け |
| agents/evaluator/detection-coverage.md | 213 | DC 次元（検出カバレッジ分析：検出戦略完全性、severity 分類、FP リスク） |
| agents/producer/workflow-completeness.md | 203 | WC 次元（ワークフロー完全性分析：依存関係、データフロー、エラーパス） |
| agents/producer/output-format.md | 208 | OF 次元（出力形式実現性分析：実現可能性、下流互換性、情報完全性） |
| agents/shared/instruction-clarity.md | 218 | IC 次元（指示明確性分析：ドキュメント構造、役割定義、コンテキスト充足） |
| agents/unclassified/scope-alignment.md | 162 | SA 次元（スコープ整合性分析・軽量版：目的明確性、フォーカス適切性）- unclassified 向け |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0 (初期化・グループ分類)**: エージェント定義読み込み、YAML frontmatter 検証、グループ分類（hybrid/evaluator/producer/unclassified）、分析次元セット決定、出力ディレクトリ作成
  - **Phase 1 (並列分析)**: グループに応じた 3-5 次元のエージェントを並列起動し、各次元で findings を生成（.agent_audit/{agent_name}/audit-{ID_PREFIX}.md に保存）
  - **Phase 2 (ユーザー承認 + 改善適用)**: Step 1: findings 収集（haiku サブエージェント）→ Step 2: 一覧提示 + 承認方針選択（全承認/1件ずつ/キャンセル）→ Step 2a: per-item 承認ループ（1件ずつ選択時）→ Step 3: 承認結果保存（audit-approved.md）→ Step 4: 改善適用（sonnet サブエージェント）+ 検証ステップ（frontmatter 構造確認）
  - **Phase 3 (完了サマリ)**: 検出件数・承認結果・変更詳細・次のステップを表示

- データフロー:
  - Phase 0 → Phase 1: {agent_path}, {agent_name}, {agent_group}, {dimensions} を各次元サブエージェントに渡す
  - Phase 1 → Phase 2: 各次元が audit-{ID_PREFIX}.md を生成。親は返答サマリ（dim, critical, improvement, info 件数）を収集
  - Phase 2 Step 1: collect-findings テンプレートが audit-*.md を収集し、findings-summary.md を生成
  - Phase 2 Step 3 → Step 4: audit-approved.md を apply-improvements テンプレートが読み込み、{agent_path} に変更を適用
  - Phase 2 検証ステップ: {agent_path} の先頭20行を Read し、YAML frontmatter 構造を検証

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 96 | `.claude/skills/agent_audit_new/group-classification.md` | グループ分類基準の詳細参照 |
| SKILL.md | 149 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | 各次元エージェント定義の読み込み |
| SKILL.md | 155 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | 共通ルール定義の参照 |
| SKILL.md | 189 | `.claude/skills/agent_audit_new/templates/collect-findings.md` | findings 収集テンプレートの読み込み |
| SKILL.md | 273 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | 改善適用テンプレートの読み込み |
| agents/evaluator/criteria-effectiveness.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数で指定） |
| agents/evaluator/scope-alignment.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数で指定） |
| agents/evaluator/detection-coverage.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数で指定） |
| agents/producer/workflow-completeness.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数で指定） |
| agents/producer/output-format.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数で指定） |
| agents/shared/instruction-clarity.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数で指定） |
| agents/unclassified/scope-alignment.md | 16 | `{common_rules_path}` | 共通ルール定義の読み込み（変数で指定） |

（外部参照はスキル内のファイル相互参照のみ。スキル外への参照なし）

## D. コンテキスト予算分析
- SKILL.md 行数: 360行
- テンプレートファイル数: 2個、平均行数: 55.5行
- サブエージェント委譲: あり（Phase 1 で 3-5 個の並列分析エージェント、Phase 2 Step 1 で 1 個の収集エージェント、Phase 2 Step 4 で 1 個の改善適用エージェント）
- 親コンテキストに保持される情報:
  - グループ分類結果（{agent_group}）
  - 分析次元セット（{dimensions}、各次元名のリスト）
  - Phase 1 の各次元の返答サマリ（dim, critical, improvement, info 件数）
  - Phase 2 Step 1 の返答サマリ（total, critical, improvement 件数）
  - 承認方針（全承認/1件ずつ/キャンセル）と承認結果（承認数、スキップ数）
  - Phase 2 Step 4 の返答サマリ（変更概要）
  - **エージェント定義本体は親に保持しない**（各サブエージェントが直接 Read する）
- 3ホップパターンの有無: **なし**（Phase 1 の各次元が直接ファイルに保存、Phase 2 Step 1 がファイルから直接読み込み、親は中継しない）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | 引数未指定時に agent_path を確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全承認/1件ずつ/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認（承認/スキップ/残りすべて承認/キャンセル） | 不明 |
| Phase 2 Step 4 エラー時 | AskUserQuestion | 改善適用失敗時の方針確認（リトライ/ロールバック/強制的に進む） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - **Phase 0**: {agent_path} の Read 失敗時、エラー出力して終了
  - **Phase 0**: YAML frontmatter 不在時、frontmatter-warning.txt を作成し警告出力（処理は継続）
  - **Phase 2 Step 1**: findings ファイルが1つも見つからない場合、total: 0 を返答（findings-summary.md は作成しない）
- サブエージェント失敗時:
  - **Phase 1**: 各次元の findings ファイル存在確認。存在しないまたは空の場合「分析失敗」として扱う。全次元失敗時は「全次元の分析に失敗しました」とエラー出力して終了
  - **Phase 2 Step 4**: 失敗キーワード（`error:`, `failed:`, `skipped: all`）検出時、AskUserQuestion で方針確認（リトライ/ロールバック/強制的に進む）。リトライは1回のみ
- 部分完了時:
  - **Phase 1**: 一部次元が成功した場合、成功した次元の findings のみを Phase 2 で処理
  - **Phase 2 検証ステップ**: frontmatter 検証失敗時、警告を出力し Phase 3 の改善適用結果詳細表示をスキップ（Phase 3 へ進む）
- 入力バリデーション:
  - **Phase 0**: {agent_path} の存在確認（Read 実行）
  - **Phase 0**: YAML frontmatter 存在確認（先頭行が `---`、frontmatter 内に `description:` を含むか）
  - **Phase 2 検証ステップ**: YAML frontmatter 詳細検証（1行目 `---`、2-19行目範囲に終了 `---`、間に非空の `description:` 行）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/{dim_path}.md（次元定義）| 4行（dim, critical, improvement, info） | 3-5個（グループ別：hybrid=5, evaluator=4, producer=4, unclassified=3） |
| Phase 2 Step 1 | haiku | templates/collect-findings.md | 3行（total, critical, improvement） | 1個 |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 可変（modified/skipped サマリ）| 1個 |
