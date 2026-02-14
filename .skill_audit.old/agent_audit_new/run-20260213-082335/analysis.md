# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 309 | スキルのメインエントリポイント。エージェント定義を静的分析し、グループ分類→並列分析→ユーザー承認→改善適用のワークフローを定義 |
| agents/evaluator/criteria-effectiveness.md | 185 | CE次元の分析エージェント。評価基準の明確性・S/N比・実行可能性・費用対効果を敵対的観点で評価 |
| agents/evaluator/scope-alignment.md | 169 | SA次元の分析エージェント（evaluator版）。スコープ定義品質・境界明確性・内部整合性・ドメインカバレッジを評価 |
| agents/evaluator/detection-coverage.md | 201 | DC次元の分析エージェント。検出戦略完全性・severity分類整合性・出力形式有効性・偽陽性リスクを評価 |
| agents/producer/workflow-completeness.md | 191 | WC次元の分析エージェント。ワークフローのステップ順序・データフロー・エラーパス・条件分岐網羅性を評価 |
| agents/producer/output-format.md | 196 | OF次元の分析エージェント。出力形式の実現可能性・下流利用可能性・情報完全性・セクション間整合性を評価 |
| agents/shared/instruction-clarity.md | 172 | IC次元の分析エージェント（全グループ共通）。ドキュメント構造・役割定義・メタレベル指示品質を評価 |
| group-classification.md | 22 | エージェントグループ分類基準（hybrid/evaluator/producer/unclassified）の定義と判定ルール |
| templates/apply-improvements.md | 38 | 承認済みfindingsをエージェント定義に適用するサブエージェントのテンプレート |
| agents/unclassified/scope-alignment.md | 151 | SA次元の分析エージェント（unclassified/producer版・軽量版）。目的明確性・フォーカス適切性・境界暗黙性を評価 |

## B. ワークフロー概要
- フェーズ構成: Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）
- 各フェーズの目的:
  - Phase 0: エージェント定義を読み込み、内容から4グループ（hybrid/evaluator/producer/unclassified）に分類し、グループに応じた分析次元セット（3-5次元）を決定する
  - Phase 1: グループ別の次元セット（IC + CE/SA/DC/WC/OF の組み合わせ）で並列サブエージェント分析を実行し、findings ファイルに保存する
  - Phase 2: findings を収集し、ユーザーに一覧提示→承認方針選択→per-item承認（オプション）→承認結果保存→改善適用（サブエージェント委譲）→検証を実行する
  - Phase 3: 検出件数・承認件数・適用結果・バックアップパス・次ステップ提案を含む完了サマリを出力する
- データフロー:
  - Phase 0: `{agent_path}` 読込 → `{agent_name}` 導出 → `.agent_audit/{agent_name}/` ディレクトリ作成
  - Phase 1: 各次元エージェント → `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` 生成（IC/CE/SA/DC/WC/OF）
  - Phase 2 Step 1-3: findings ファイル読込 → 承認結果を `.agent_audit/{agent_name}/audit-approved.md` 保存
  - Phase 2 Step 4: `{agent_path}` バックアップ作成（`{agent_path}.backup-{timestamp}`）→ `apply-improvements` サブエージェント → `{agent_path}` 変更 → `{agent_path}` 検証

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | group-classification.md | グループ分類の詳細基準参照 |
| SKILL.md | 115-118 | .claude/skills/agent_audit_new/agents/{dim_path}.md | 次元別分析エージェント定義の参照（Task promptで使用） |
| SKILL.md | 244 | .claude/skills/agent_audit_new/templates/apply-improvements.md | 改善適用サブエージェントのテンプレート参照 |

（全ての外部参照は `{skill_path}` 内にある。スキル外部への参照はなし）

## D. コンテキスト予算分析
- SKILL.md 行数: 309行
- テンプレートファイル数: 1個（apply-improvements.md, 38行）
- サブエージェント委譲: あり
  - Phase 1: 3-5個の並列サブエージェント（次元別分析、各エージェント185-201行のテンプレート、model: "sonnet"）
  - Phase 2 Step 4: 1個のサブエージェント（改善適用、38行テンプレート、model: "sonnet"）
- 親コンテキストに保持される情報:
  - エージェント定義全文（`{agent_content}`）— Phase 0 グループ分類で使用後は保持不要（次元サブエージェントは直接 `{agent_path}` を Read）
  - メタデータ: `{agent_path}`, `{agent_name}`, `{agent_group}`, `{dim_count}`, dimensions リスト
  - Phase 1 結果: 各次元の返答サマリ（1行: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
  - Phase 2 承認結果: 承認数/スキップ数/total（詳細は `audit-approved.md` に保存）
- 3ホップパターンの有無: なし
  - Phase 1 の次元サブエージェントは findings をファイルに保存し、Phase 2 で親が直接 Read する（中継なし）
  - Phase 2 Step 4 の改善適用サブエージェントは `{agent_path}` を直接変更し、結果サマリのみ返答する（中継なし）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item承認（承認/修正して承認/スキップ/残りすべて承認/キャンセル） | 不明 |
| Phase 2 Step 4 | AskUserQuestion | 改善適用の最終確認（適用/キャンセル） | 不明 |

（SKILL.md に Fast mode に関する記載なし）

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: `{agent_path}` 読込失敗時、エラー出力して終了（処理継続しない）
  - Phase 0: frontmatter 不在時、警告出力するが処理は継続する
  - Phase 1: findings ファイル不在時、該当次元を「失敗」として扱い、エラー概要（Task返答の先頭100文字）を表示
- サブエージェント失敗時:
  - Phase 1: findings ファイルの存在と空でないことで成否判定。成功次元が1つでもあれば Phase 2 へ継続
  - Phase 1: 全次元失敗または IC 失敗 + グループ固有次元全失敗時、エラー出力して終了
  - Phase 2 Step 4: 改善適用サブエージェントの返答に `modified:` または `skipped:` が含まれるか検証。失敗時はロールバック手順を表示し Phase 3 へ継続
- 部分完了時:
  - Phase 1: 部分成功判定基準あり（全次元失敗/IC失敗+固有次元全失敗→エラー終了、それ以外→継続）
  - Phase 2 Step 2: critical+improvement 合計が 0 の場合、Phase 2 をスキップして Phase 3 へ直行
  - Phase 2 Step 3: 承認数が 0 の場合、改善適用をスキップして Phase 3 へ直行
- 入力バリデーション:
  - Phase 0: YAML frontmatter の簡易チェックあり（警告のみ、処理は継続）
  - Phase 1: サブエージェント返答フォーマットのバリデーションあり（不正時は件数を「?」とし、ファイルから推定）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 4行（`dim: IC, critical: {N}, improvement: {M}, info: {K}`） | 1（全グループ共通） |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 4行 | 1（hybrid/evaluatorのみ） |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 4行 | 1（hybrid/evaluatorのみ） |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 4行 | 1（evaluatorのみ） |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 4行 | 1（hybrid/producer/unclassifiedに含まれる） |
| Phase 1 | sonnet | agents/producer/output-format.md | 4行 | 1（hybridのみ） |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 4行 | 1（producer/unclassifiedのみ） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 数行（`modified: {N}件\n  - {...}\nskipped: {K}件\n  - {...}`） | 1 |

（Phase 1 の並列数は `{agent_group}` により 3-5 個が同一メッセージ内で並列起動される）
