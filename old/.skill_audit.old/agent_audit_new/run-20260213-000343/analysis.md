# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 262 | スキル定義（ワークフロー全体・グループ分類ルール・次元マッピング） |
| agents/evaluator/criteria-effectiveness.md | 184 | evaluator グループ用の CE 次元分析エージェント定義 |
| agents/evaluator/detection-coverage.md | 200 | evaluator グループ用の DC 次元分析エージェント定義 |
| agents/evaluator/scope-alignment.md | 168 | evaluator グループ用の SA 次元分析エージェント定義 |
| agents/producer/workflow-completeness.md | 190 | producer グループ用の WC 次元分析エージェント定義 |
| agents/producer/output-format.md | 195 | producer グループ用の OF 次元分析エージェント定義 |
| agents/shared/instruction-clarity.md | 171 | 全グループ共通の IC 次元分析エージェント定義 |
| agents/unclassified/scope-alignment.md | 150 | unclassified グループ用の SA 次元分析エージェント定義（軽量版） |
| group-classification.md | 21 | グループ分類基準定義（evaluator/producer 特徴リスト） |
| templates/apply-improvements.md | 37 | 承認済み findings を適用するサブエージェント用テンプレート |

## B. ワークフロー概要
- フェーズ構成: Phase 0 (初期化・グループ分類) → Phase 1 (並列分析) → Phase 2 (ユーザー承認 + 改善適用) → Phase 3 (完了サマリ)
- Phase 0: エージェント定義ファイルを読み込み、グループ分類（hybrid/evaluator/producer/unclassified）を実行し、グループに応じた分析次元セットを決定する
- Phase 1: 決定した次元数に応じてサブエージェント（sonnet、general-purpose）を並列起動し、各次元で findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を生成する
- Phase 2: 生成された findings を収集し、ユーザーに承認確認（全て承認/1件ずつ確認/キャンセル、または --fast で自動承認）を行った後、承認済み findings を `.agent_audit/{agent_name}/audit-approved.md` に保存し、サブエージェントに改善適用を委譲する
- Phase 3: 完了サマリを出力し、次のステップ（再監査または agent_bench）を提案する
- データフロー:
  - Phase 0 → Phase 1: agent_path, agent_name, agent_group, dimensions リスト
  - Phase 1 → Phase 2: audit-{ID_PREFIX}.md（各次元の findings ファイル）
  - Phase 2 → Phase 2 Step 4: audit-approved.md（承認済み findings）
  - Phase 2 Step 4: templates/apply-improvements.md を使用してエージェント定義を直接変更

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 86, 90 | `.agent_audit/{agent_name}/` | 出力ディレクトリ（スキル内で定義） |
| SKILL.md | 124, 126 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | 各次元の分析エージェント定義（スキル内） |
| SKILL.md | 213 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | 改善適用テンプレート（スキル内） |

**判定**: 全ての参照先がスキル内部（`{skill_path}` 配下）または動的生成ディレクトリ（`.agent_audit/`）であり、外部スキル・外部システムへの参照はない。

## D. コンテキスト予算分析
- SKILL.md 行数: 262行
- テンプレートファイル数: 7個（agents/ 配下の分析エージェント定義）+ 1個（templates/apply-improvements.md）= 8個、平均行数: (184+200+168+190+195+171+150+37)/8 ≈ 162行
- サブエージェント委譲: あり（Phase 1 で最大5個の並列分析サブエージェント、Phase 2 で1個の改善適用サブエージェント）
- 親コンテキストに保持される情報:
  - エージェント定義ファイルパス（`agent_path`）およびエージェント名（`agent_name`）
  - グループ分類結果（`agent_group`）および分析次元セット（`dimensions`）
  - Phase 1 サブエージェントからの返答（4行フォーマット: dim, critical, improvement, info）
  - Phase 2 の承認結果（承認数、スキップ数）
  - Phase 2 Step 4 サブエージェントからの返答（変更サマリ: 30行以内）
- 3ホップパターンの有無: なし
  - Phase 1 サブエージェントは findings をファイルに保存し、Phase 2 サブエージェントはそのファイルを直接読み込む（親経由の中継なし）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path が未指定の場合にファイルパスを確認 | Fast mode に関わらず実行 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認/1件ずつ確認/キャンセル） | スキップ（全て承認として扱う） |
| Phase 2 Step 2a | AskUserQuestion | 各 finding の承認/スキップ/残りすべて承認/キャンセル（「1件ずつ確認」選択時のみ） | 実行されない（Step 2 でスキップされるため） |

## F. エラーハンドリングパターン
- ファイル不在時: Phase 0 Step 2 で Read 失敗を検出し、エラーメッセージを出力して終了
- サブエージェント失敗時:
  - **Phase 1**: findings ファイルの存在確認・内容検証で成否を判定。全次元失敗の場合は全体終了。部分失敗の場合は警告を出力して継続（成功した次元のみで Phase 2 へ進む）
  - **Phase 2 Step 4**: 改善適用サブエージェント失敗時はエラーメッセージとバックアップ復旧コマンドを出力し、Phase 3 へ進む
- 部分完了時:
  - **Phase 1**: 成功した次元のみで Phase 2 へ進む。失敗次元リストを警告出力する
  - **Phase 2**: 承認数が 0 の場合は改善適用をスキップして Phase 3 へ直行する
- 入力バリデーション: Phase 0 Step 3 でファイル先頭の YAML frontmatter を確認し、存在しない場合は警告を出力（処理は継続）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/{dim_path}.md （dim_path は dimensions リストから動的に決定） | 4行（dim, critical, improvement, info） | 最大5個（hybrid グループの場合）、最小3個（unclassified グループの場合） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 30行以内（modified/skipped サマリ） | 1個 |
