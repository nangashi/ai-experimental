# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | メインスキル定義 — ワークフロー、グループ分類、並列分析、ユーザー承認の全体制御 |
| agents/evaluator/criteria-effectiveness.md | 185 | 次元: CE（基準有効性）— 評価基準の明確性・S/N比・実行可能性・費用対効果を分析 |
| agents/evaluator/scope-alignment.md | 169 | 次元: SA（スコープ整合性・evaluator版）— スコープ定義品質・境界明確性・内部整合性を分析 |
| agents/evaluator/detection-coverage.md | 201 | 次元: DC（検出カバレッジ）— 検出戦略完全性・severity分類・出力形式・偽陽性リスクを分析 |
| group-classification.md | 22 | グループ分類基準 — evaluator/producer 特徴判定ルール |
| agents/producer/workflow-completeness.md | 191 | 次元: WC（ワークフロー完全性）— ステップ順序・データフロー・エラーパス・条件分岐を分析 |
| agents/producer/output-format.md | 196 | 次元: OF（出力形式実現性）— 形式実現可能性・下流利用可能性・情報完全性を分析 |
| agents/unclassified/scope-alignment.md | 151 | 次元: SA（スコープ整合性・軽量版）— 目的明確性・フォーカス適切性・境界暗黙性を分析 |
| agents/shared/instruction-clarity.md | 206 | 次元: IC（指示明確性）— ドキュメント構造・役割定義・コンテキスト完全性・指示有効性を分析 |
| templates/apply-improvements.md | 38 | 改善適用テンプレート — 承認済み findings に基づくエージェント定義の変更手順 |

## B. ワークフロー概要
- フェーズ構成: Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）
- 各フェーズの目的:
  - Phase 0: agent_path 読み込み → frontmatter検証 → グループ分類（hybrid/evaluator/producer/unclassified）→ 次元セット決定 → 出力ディレクトリ作成
  - Phase 1: グループに応じた3-5次元のサブエージェントを並列起動 → 各次元が findings ファイル生成 → 成否判定（findings ファイル存在確認）
  - Phase 2: Step 1（findings 収集）→ Step 2（一覧提示+承認方針選択）→ Step 2a（per-item 承認）→ Step 3（承認結果保存）→ Step 4（改善適用サブエージェント）→ 検証（frontmatter 再確認）
  - Phase 3: 完了サマリ出力 + 次のステップ推奨（critical 適用 → 再監査 / improvement のみ → agent_bench 推奨）
- データフロー:
  - Phase 0 → Phase 1: `{agent_content}`, `{agent_group}`, `{agent_name}`, `{dim_count}`, dimensions リスト
  - Phase 1: サブエージェントが `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に findings を書き込み
  - Phase 1 → Phase 2: findings ファイルパスリスト、各次元の件数サマリ（critical/improvement/info）
  - Phase 2 Step 1: 各 findings ファイルを Read → severity フィルタ → ソート
  - Phase 2 Step 3: 承認済み findings を `.agent_audit/{agent_name}/audit-approved.md` に Write
  - Phase 2 Step 4: サブエージェントが `{agent_path}` と `audit-approved.md` を Read → Edit/Write で改善適用
  - Phase 2 → Phase 3: 承認数、スキップ数、変更詳細、バックアップパス

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit_new/group-classification.md` | グループ分類基準の詳細参照 |

## D. コンテキスト予算分析
- SKILL.md 行数: 279行
- テンプレートファイル数: 1個（apply-improvements.md）、平均行数: 38行
- サブエージェント委譲: あり
  - Phase 1: 3-5個の並列サブエージェント（グループごとの次元セット）、各サブエージェントが agent 定義ファイル（1-2K行規模）+ 次元定義ファイル（150-200行）を読み込み
  - Phase 2 Step 4: 1個のサブエージェント（改善適用）、agent 定義ファイル + 承認済み findings（可変長）を読み込み
- 親コンテキストに保持される情報: agent_name, agent_group, agent_path, dim_count, dimensions リスト、各次元の件数サマリ（critical/improvement/info のカウント）、承認結果（承認数/スキップ数）、バックアップパス
- 3ホップパターンの有無: なし（サブエージェントは findings をファイルに保存し、親は findings ファイルパスのみ保持。親がサブエージェント結果を別サブエージェントに中継する構造はない）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | `agent_path` 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全て承認 / 1件ずつ確認 / キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認（承認 / スキップ / 残りすべて承認 / キャンセル）、およびユーザー修正内容の入力 | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時: Phase 0 で `agent_path` の Read 失敗 → エラー出力して終了
- サブエージェント失敗時:
  - Phase 1: 各サブエージェントの成否を findings ファイルの存在確認で判定。失敗時は「分析失敗（{エラー概要}）」として記録し、処理継続。全サブエージェント失敗時のみ終了
  - Phase 2 Step 4: 改善適用サブエージェントの失敗処理は明示的に定義されていない（未定義）
- 部分完了時:
  - Phase 1: 成功した次元のみで Phase 2 へ進む（失敗次元は除外）
  - Phase 2: 承認数が 0 の場合 → 改善適用スキップして Phase 3 へ直行
- 入力バリデーション:
  - Phase 0 Step 3: frontmatter 存在チェック（`---` で囲まれた `description:` の有無）。存在しない場合は警告テキスト出力するが処理は継続
  - Phase 2 検証ステップ: 改善適用後に frontmatter 再確認。失敗時はロールバック手順を出力し、Phase 3 で警告表示

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 4行（dim: IC, critical: N, improvement: M, info: K） | 3-5個（グループによる） |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 4行（dim: CE, critical: N, improvement: M, info: K） | 3-5個（グループによる） |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 4行（dim: SA, critical: N, improvement: M, info: K） | 3-5個（グループによる） |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 4行（dim: DC, critical: N, improvement: M, info: K） | 3-5個（グループによる） |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 4行（dim: WC, critical: N, improvement: M, info: K） | 3-5個（グループによる） |
| Phase 1 | sonnet | agents/producer/output-format.md | 4行（dim: OF, critical: N, improvement: M, info: K） | 3-5個（グループによる） |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 4行（dim: SA, critical: N, improvement: M, info: K） | 3-5個（グループによる） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 可変長（modified: N件, skipped: K件のサマリ形式） | 1個 |
