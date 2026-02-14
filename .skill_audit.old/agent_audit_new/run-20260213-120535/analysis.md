# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | スキルのメインワークフロー定義（Phase 0-3）とグループ分類方式 |
| agents/evaluator/criteria-effectiveness.md | 185 | CE次元: 評価基準の明確性・S/N比・実行可能性・費用対効果を分析するレビューア |
| agents/evaluator/scope-alignment.md | 169 | SA次元（evaluator用）: スコープ定義品質・境界明確性・内部整合性を分析するレビューア |
| agents/evaluator/detection-coverage.md | 200 | DC次元: 検出戦略完全性・severity分類・出力形式・偽陽性リスクを分析するレビューア |
| agents/producer/workflow-completeness.md | 190 | WC次元: ワークフロートポロジ・データフロー・エラーパス・条件分岐を分析するレビューア |
| agents/producer/output-format.md | 195 | OF次元: 出力形式の実現可能性・下流互換性・情報完全性を分析するレビューア |
| agents/unclassified/scope-alignment.md | 150 | SA次元（軽量版）: 目的明確性・フォーカス適切性・境界暗黙性を分析するレビューア |
| agents/shared/instruction-clarity.md | 205 | IC次元: ドキュメント構造・役割定義・コンテキスト・指示有効性を分析するレビューア |
| group-classification.md | 22 | グループ分類基準（evaluator/producer特徴リスト、判定ルール） |
| templates/apply-improvements.md | 38 | 改善適用サブエージェントテンプレート（承認済みfindingsをエージェント定義に適用） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0: 初期化・グループ分類** — エージェント定義読み込み、frontmatter検証、グループ判定（evaluator/producer/hybrid/unclassified）、agent_name導出、出力ディレクトリ作成、分析次元セット決定
  - **Phase 1: 並列分析** — 決定された次元セット（3-5次元）に対応する複数のレビューアサブエージェントを並列起動し、各次元ごとの findings ファイル生成。エラーハンドリング: findingsファイル存在・非空チェック
  - **Phase 2: ユーザー承認 + 改善適用** — Step 1: findings収集、Step 2a: 一覧提示+承認方針選択、Step 2b（条件分岐）: per-item承認、Step 3: 承認結果保存、Step 4: 改善適用サブエージェント起動（バックアップ作成→Edit/Write）、検証ステップ（frontmatter確認）
  - **Phase 3: 完了サマリ** — 検出件数・承認結果・変更詳細・バックアップパス表示、次ステップ推奨（条件分岐: criticalあり→再audit、improvementのみ→agent_bench、なし→推奨なし）
- データフロー:
  - Phase 0 → Phase 1: agent_path, agent_name, agent_group, dimensions
  - Phase 1 → Phase 2: findings files (`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`)
  - Phase 2 → Phase 2 Step 4: approved findings file (`.agent_audit/{agent_name}/audit-approved.md`)
  - Phase 2 Step 4 → Phase 3: 変更サマリ、backup_path
  - Phase 3: 全フェーズの結果を統合して最終サマリ生成

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit/group-classification.md` | グループ分類基準の詳細参照（メモ: 実際のファイルは `.claude/skills/agent_audit_new/group-classification.md` にあり、パスが不整合） |
| SKILL.md | 221 | `.claude/skills/agent_audit/templates/apply-improvements.md` | 改善適用サブエージェント起動（メモ: 実際のファイルは `.claude/skills/agent_audit_new/templates/apply-improvements.md` にあり、パスが不整合） |

## D. コンテキスト予算分析
- SKILL.md 行数: 279行
- テンプレートファイル数: 1個、平均行数: 38行
- サブエージェント委譲: あり
  - Phase 1: 3-5個の並列サブエージェント（分析次元ごと、model: sonnet, subagent_type: general-purpose）
  - Phase 2 Step 4: 1個のサブエージェント（改善適用、model: sonnet, subagent_type: general-purpose）
- 親コンテキストに保持される情報:
  - agent_path, agent_name, agent_group
  - dim_count, dimensions リスト
  - 各次元の返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
  - 承認方針、承認数、スキップ数
  - 変更サマリ（modified/skipped件数）
  - backup_path
- 3ホップパターンの有無: **なし**
  - Phase 1 サブエージェント → findings ファイル → Phase 2 で Read
  - Phase 2 → approved findings ファイル → Phase 2 Step 4 サブエージェントで Read
  - すべてファイル経由の間接参照（親が中継しない）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item承認（承認/スキップ/残りすべて承認/キャンセル）※1件ずつ確認選択時のみ | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: agent_path の Read 失敗時はエラー出力して終了
  - Phase 1: findings ファイル不在時は該当次元を「分析失敗（エラー概要）」扱い。全次元失敗時はエラー出力して終了
  - Phase 2 Step 4: findings ファイル Read 失敗時は未定義（サブエージェントに委譲）
- サブエージェント失敗時:
  - Phase 1: findings ファイル存在・非空チェックで成否判定。失敗次元は「分析失敗（エラー概要）」として記録し、他次元の処理を継続。全次元失敗時のみ終了
  - Phase 2 Step 4: 返答内容（変更サマリ）をテキスト出力するのみ（失敗時の明示的なハンドリングは未定義）
- 部分完了時:
  - Phase 1: 一部次元の分析成功で処理継続（成功数/dim_count を表示）
  - Phase 2: critical + improvement = 0 の場合は Phase 2 をスキップして Phase 3 へ直行
  - Phase 2: 承認数 = 0 の場合は Step 4（改善適用）をスキップして Phase 3 へ直行
- 入力バリデーション:
  - Phase 0: YAML frontmatter 存在チェック（`---` で囲まれ `description:` を含む）。不在時は警告テキスト出力するが処理継続
  - Phase 2 Step 4 後: frontmatter 存在確認による検証ステップあり。失敗時はロールバック方法を出力（処理は継続）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | `.claude/skills/agent_audit/agents/{dim_path}.md` | 4行（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`） | 3-5個（グループごとに異なる: hybrid 5次元、evaluator 4次元、producer 4次元、unclassified 3次元） |
| Phase 2 Step 4 | sonnet | `.claude/skills/agent_audit/templates/apply-improvements.md` | 可変（`modified: {N}件\n  - ...\nskipped: {K}件\n  - ...`） | 1個 |
