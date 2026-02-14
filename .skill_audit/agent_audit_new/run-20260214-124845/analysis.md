# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | スキル定義メイン（ワークフロー、グループ分類、次元マッピング） |
| agents/evaluator/criteria-effectiveness.md | 185 | CE 次元エージェント（評価基準の有効性分析） |
| agents/evaluator/scope-alignment.md | 169 | SA 次元エージェント（evaluator 向けスコープ整合性分析） |
| agents/evaluator/detection-coverage.md | 201 | DC 次元エージェント（検出カバレッジ分析） |
| agents/producer/workflow-completeness.md | 191 | WC 次元エージェント（ワークフロー完全性分析） |
| agents/producer/output-format.md | 196 | OF 次元エージェント（出力形式実現性分析） |
| agents/unclassified/scope-alignment.md | 151 | SA 次元エージェント（unclassified 向けスコープ整合性分析・軽量版） |
| agents/shared/instruction-clarity.md | 206 | IC 次元エージェント（指示明確性分析・全グループ共通） |
| group-classification.md | 22 | グループ分類基準定義（evaluator/producer 特徴、判定ルール） |
| templates/apply-improvements.md | 38 | Phase 2 Step 4 改善適用テンプレート（サブエージェントが findings を適用） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的（1行ずつ）
  - **Phase 0（初期化・グループ分類）**: エージェント定義を読み込み、グループ（hybrid/evaluator/producer/unclassified）に分類し、分析次元セットを決定する
  - **Phase 1（並列分析）**: グループに応じた次元エージェントを並列起動し、各次元の品質分析を実行、findings を生成する
  - **Phase 2（ユーザー承認 + 改善適用）**: 検出された findings をユーザーに提示し、承認された指摘に基づいてエージェント定義を改善する
  - **Phase 3（完了サマリ）**: 分析結果と改善内容を集計し、次のステップ（再監査 or 構造最適化）を提示する
- データフロー:
  - Phase 0 → Phase 1: {agent_content}, {agent_group}, {agent_name}, {dim_count}, dimensions リスト
  - Phase 1: 各次元エージェントが `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` を生成（ファイル経由で親に返答）
  - Phase 2 Step 1: 全次元の findings ファイルを Read して critical/improvement を抽出
  - Phase 2 Step 3: 承認済み findings を `.agent_audit/{agent_name}/audit-approved.md` に保存
  - Phase 2 Step 4: apply-improvements テンプレートが audit-approved.md を参照してエージェント定義を直接変更

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit/group-classification.md` | グループ分類基準の詳細参照（説明文内、実際のファイルパスは本スキル内の `group-classification.md`） |

**注**: 行64の参照は旧パスを記載しているが、実際には同一スキル内の `group-classification.md` が使用される（外部依存なし）。

## D. コンテキスト予算分析
- SKILL.md 行数: 279行
- テンプレートファイル数: 1個（apply-improvements.md）、平均行数: 38行
- サブエージェント委譲: あり（Phase 1 で最大5次元並列、Phase 2 Step 4 で1エージェント）
  - Phase 1: グループごとに 3-5 個の次元エージェントを並列起動（sonnet, general-purpose）
  - Phase 2 Step 4: 改善適用エージェント（sonnet, general-purpose）
  - 委譲パターン: サブエージェントはエージェント定義ファイル（agents/{category}/{dimension}.md）を Read し、その指示に従って分析実行
- 親コンテキストに保持される情報:
  - {agent_content}（Phase 0 で Read、Phase 1 サブエージェントに渡す）
  - {agent_group}, {agent_name}, {dim_count}, dimensions リスト（メタデータ）
  - Phase 1 サブエージェント返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
  - Phase 2 で抽出した findings リスト（タイトル、severity、次元名のみ）
  - 承認/スキップ結果の件数集計
- 3ホップパターンの有無: なし
  - Phase 1 の各次元エージェントは findings ファイルに保存し、親はファイル経由で Phase 2 に引き継ぐ
  - Phase 2 Step 4 のサブエージェントは audit-approved.md を Read し、エージェント定義を直接変更（結果は返答サマリのみ）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認 / 1件ずつ確認 / キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認（承認 / スキップ / 残りすべて承認 / キャンセル） | 不明 |

**注**: Fast mode での中間確認スキップに関する記載は SKILL.md 内にない。

## F. エラーハンドリングパターン
- ファイル不在時: Phase 0 Step 2 で `{agent_path}` 読み込み失敗時はエラー出力して終了（処理継続なし）
- サブエージェント失敗時:
  - Phase 1: 各次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）の存在・非空で成否判定
  - 失敗次元は「分析失敗（{エラー概要}）」として扱い、Task ツール返答からエラーメッセージを抽出
  - 全次元失敗時: エラー出力して終了
  - 一部成功時: 成功した次元のみで処理継続
- 部分完了時:
  - Phase 1 で一部次元が失敗した場合、成功した次元の findings のみで Phase 2 に進む
  - Phase 2 で全指摘がスキップされた場合（承認数 0）、改善適用をスキップして Phase 3 へ直行
- 入力バリデーション:
  - Phase 0 Step 3: YAML frontmatter（`---` で囲まれた `description:` 含むブロック）の存在確認
  - frontmatter 不在時: 警告テキスト出力して処理継続（エラー終了はしない）
  - Phase 2 Step 4 検証: 改善適用後に再度 frontmatter 存在確認、破損時は警告とロールバック手順を表示

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 1（`dim: IC, critical: {N}, improvement: {M}, info: {K}`） | 1（全グループ共通） |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 1（`dim: CE, critical: {N}, improvement: {M}, info: {K}`） | 1（hybrid/evaluator のみ） |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 1（`dim: SA, critical: {N}, improvement: {M}, info: {K}`） | 1（hybrid/evaluator のみ） |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 1（`dim: DC, critical: {N}, improvement: {M}, info: {K}`） | 1（evaluator のみ） |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 1（`dim: WC, critical: {N}, improvement: {M}, info: {K}`） | 1（hybrid/producer/unclassified） |
| Phase 1 | sonnet | agents/producer/output-format.md | 1（`dim: OF, critical: {N}, improvement: {M}, info: {K}`） | 1（hybrid/producer のみ） |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 1（`dim: SA, critical: {N}, improvement: {M}, info: {K}`） | 1（producer/unclassified のみ） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 1（`modified: {N}件\n  - {finding ID} → ...\nskipped: {K}件\n  - {finding ID}: ...`） | 1 |

**注**: Phase 1 の並列数はグループによって異なる（hybrid: 5, evaluator: 4, producer: 4, unclassified: 3）
