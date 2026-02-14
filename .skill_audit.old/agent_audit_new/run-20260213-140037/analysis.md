# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | メインスキル定義（ワークフロー、グループ分類、インターフェース） |
| agents/evaluator/criteria-effectiveness.md | 185 | evaluator用分析次元：評価基準の有効性・実行可能性・S/N比を分析 |
| agents/evaluator/scope-alignment.md | 169 | evaluator用分析次元：スコープ定義品質・境界明確性を分析 |
| agents/evaluator/detection-coverage.md | 201 | evaluator用分析次元：検出戦略完全性・severity分類・偽陽性リスクを分析 |
| agents/producer/workflow-completeness.md | 190 | producer用分析次元：ワークフロー完全性・依存関係・エラーパスを分析 |
| agents/producer/output-format.md | 196 | producer用分析次元：出力形式の実現可能性・下流利用可能性を分析 |
| group-classification.md | 22 | グループ分類基準（evaluator/producer/hybrid/unclassified） |
| templates/apply-improvements.md | 38 | Phase 2 Step 4で使用：承認済みfindingsの適用処理 |
| agents/unclassified/scope-alignment.md | 151 | unclassified用分析次元：目的明確性・フォーカス適切性（軽量版） |
| agents/shared/instruction-clarity.md | 206 | 全グループ共通分析次元：指示明確性・役割定義・ドキュメント構造 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的（1行ずつ）:
  - **Phase 0（初期化・グループ分類）**: エージェント定義を読み込み、グループ（hybrid/evaluator/producer/unclassified）に分類し、分析次元セットを決定する
  - **Phase 1（並列分析）**: 決定した次元セット（3-5個）をサブエージェントに並列委譲し、各次元のfindings（critical/improvement/info）を収集する
  - **Phase 2（ユーザー承認 + 改善適用）**: 収集したfindingsをユーザーに提示し承認を得た後、サブエージェントに改善適用を委譲する（検証ステップ含む）
  - **Phase 3（完了サマリ）**: 分析結果・承認状況・適用結果をサマリ表示し、次のステップを提示する
- データフロー:
  - Phase 0 → `.agent_audit/{agent_name}/` ディレクトリ作成
  - Phase 1 → 各次元が `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` 生成（CE, SA, DC, WC, OF, IC）
  - Phase 2 Step 1 → 各次元のfindings読み込み
  - Phase 2 Step 3 → `.agent_audit/{agent_name}/audit-approved.md` 生成
  - Phase 2 Step 4 → `{agent_path}` に改善適用、`{agent_path}.backup-{timestamp}` 作成
  - Phase 3 → 全フェーズの結果を参照してサマリ生成

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit/group-classification.md` | グループ分類の詳細基準を参照（実際は同一スキル内の `group-classification.md` を参照すべき） |
| なし | - | - | 他の外部参照なし（全てスキル内部で完結） |

## D. コンテキスト予算分析
- SKILL.md 行数: 279行
- テンプレートファイル数: 1個、平均行数: 38行
- サブエージェント委譲: あり
  - Phase 1: {dim_count}個（3-5個）を並列委譲（model: sonnet, subagent_type: general-purpose）
  - Phase 2 Step 4: 1個（改善適用、model: sonnet, subagent_type: general-purpose）
- 親コンテキストに保持される情報:
  - エージェント定義全体（`{agent_content}`） — Phase 0で読み込み、Phase 0グループ分類で使用
  - グループ名（`{agent_group}`）、エージェント名（`{agent_name}`）、分析次元セット（dimensions）
  - Phase 1各サブエージェントの返答サマリ（`dim: {name}, critical: N, improvement: M, info: K`）
  - Phase 2 Step 1で読み込んだfindingsリスト（critical/improvementのみ）
  - Phase 2 Step 2でのユーザー承認判定結果（承認/スキップ）
- 3ホップパターンの有無: なし（全てファイル経由の連携）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 Step 1 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item承認（承認/スキップ/残りすべて承認/キャンセル） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0 Step 2: agent_path読み込み失敗 → エラー出力して終了
  - Phase 2 Step 1: findings ファイル不在 → Phase 1の失敗として扱う（findings収集済みの場合は該当せず）
- サブエージェント失敗時:
  - Phase 1: 各次元のfindings ファイル存在確認。不在/空 → 失敗として扱い、例外情報抽出。全失敗時はエラー出力して終了
  - Phase 2 Step 4: サブエージェント返答内容をテキスト出力（失敗時の詳細処理は未定義）
- 部分完了時:
  - Phase 1: 一部次元失敗でも成功した次元があればPhase 2へ進行
  - Phase 2 Step 3: 承認数0件の場合、Phase 3へ直行（改善適用スキップ）
  - Phase 2 Step 4: 適用スキップされたfindingsはskippedリストに記録し、返答に含める
- 入力バリデーション:
  - Phase 0 Step 3: YAML frontmatter存在確認。不在時は警告表示して処理継続
  - Phase 2 Step 4: 検証ステップ（YAML frontmatter再確認、失敗時はロールバック手順提示）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 4行（`dim: IC, critical: N, improvement: M, info: K`） | {dim_count}（3-5個）を並列実行 |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 4行（同上） | 同上に含まれる |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 4行（同上） | 同上に含まれる |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 4行（同上） | 同上に含まれる |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 4行（同上） | 同上に含まれる |
| Phase 1 | sonnet | agents/producer/output-format.md | 4行（同上） | 同上に含まれる |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 4行（同上） | 同上に含まれる |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 可変（`modified: N件, skipped: K件`形式） | 1個 |
