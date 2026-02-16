# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 289 | メインワークフロー定義（Phase 0-3）、グループ分類ロジック、次元マッピング |
| group-classification.md | 22 | グループ分類基準の詳細定義（evaluator/producer特徴、判定ルール） |
| templates/apply-improvements.md | 40 | Phase 2 Step 4 で使用する改善適用サブエージェント用テンプレート |
| agents/evaluator/criteria-effectiveness.md | 173 | CE 次元（基準有効性）分析エージェント定義 |
| agents/evaluator/scope-alignment.md | 164 | SA 次元（スコープ整合性）分析エージェント定義（evaluator向け） |
| agents/evaluator/detection-coverage.md | 186 | DC 次元（検出カバレッジ）分析エージェント定義 |
| agents/producer/workflow-completeness.md | 173 | WC 次元（ワークフロー完全性）分析エージェント定義 |
| agents/producer/output-format.md | 179 | OF 次元（出力形式実現性）分析エージェント定義 |
| agents/shared/instruction-clarity.md | 189 | IC 次元（指示明確性）分析エージェント定義（全グループ共通） |
| agents/unclassified/scope-alignment.md | 151 | SA 次元（スコープ整合性・軽量版）分析エージェント定義（producer/unclassified向け） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0（初期化・グループ分類）**: エージェント定義を読み込み、内容解析してグループ（hybrid/evaluator/producer/unclassified）に分類し、対応する分析次元セットを決定。出力ディレクトリ `.agent_audit/{agent_name}/` を作成
  - **Phase 1（並列分析）**: グループに応じた 3-5 次元の分析エージェントを並列起動（Task ツール）、各次元の findings を個別ファイルに保存
  - **Phase 2（ユーザー承認 + 改善適用）**: critical/improvement findings を収集 → ユーザー承認（全承認/1件ずつ/キャンセル）→ バックアップ作成 → 改善適用サブエージェント実行 → 検証
  - **Phase 3（完了サマリ）**: 検出件数、承認結果、変更詳細、次ステップを出力

- データフロー:
  - Phase 0: `agent_path` → Read → メインコンテキスト保持 → グループ分類・次元決定
  - Phase 1: メインから各次元エージェントに `agent_path` + `findings_save_path` を渡す → 各次元が `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に findings を保存 → 返答サマリ（件数のみ）を親に返す
  - Phase 2 Step 1: Phase 1 で生成された findings ファイルを Read で収集
  - Phase 2 Step 3: 承認結果を `.agent_audit/{agent_name}/audit-approved.md` に保存
  - Phase 2 Step 4: `apply-improvements.md` テンプレート + approved findings → サブエージェントが Edit/Write で `agent_path` を変更 → 返答サマリ（modified/skipped件数）を親に返す

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| なし | — | — | — |

（全参照がスキル内部の相対パス `.claude/skills/agent_audit/` で完結している）

## D. コンテキスト予算分析
- SKILL.md 行数: 289行
- テンプレートファイル数: 1個（apply-improvements.md）、平均行数: 40行
- サブエージェント委譲: あり
  - Phase 1: 3-5 個の次元エージェントを並列起動（次元定義ファイルを Read し指示に従う）
  - Phase 2 Step 4: 1 個の改善適用エージェント（テンプレートファイル apply-improvements.md を Read し指示に従う）
- 親コンテキストに保持される情報:
  - `{agent_content}`: Phase 0 で Read した対象エージェント定義の全文（グループ分類のみに使用、Phase 1 以降は参照しない）
  - `{agent_group}`, `{agent_name}`, `{dim_count}`, `{dimensions}`: Phase 0 で導出したメタデータ
  - Phase 1 各サブエージェントの返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
  - Phase 2 Step 1 で収集した findings の一覧（ID, severity, title, 次元名のみ）
  - Phase 2 Step 4 のサブエージェント返答サマリ（`modified: {N}件`, `skipped: {K}件`）
- 3ホップパターンの有無: なし
  - Phase 1 各サブエージェントは findings をファイルに保存し、親は findings ファイルを Read で取得
  - Phase 2 Step 4 のサブエージェントは変更結果のサマリのみ返答

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | `agent_path` 引数未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全承認/1件ずつ/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認ループ（Approve/Skip/Approve all remaining/Cancel/Other） | 不明 |
| Phase 2 Step 4 | AskUserQuestion | 改善適用前の最終確認（Proceed/Cancel） | 不明 |

（SKILL.md に Fast mode に関する記載なし）

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: `agent_path` の Read 失敗時、エラー出力して終了
  - Phase 2 Step 4: バックアップ作成後の存在確認で失敗時、エラー出力して Phase 3 へ直行
- サブエージェント失敗時:
  - Phase 1: 各次元の findings ファイル存在確認。存在しない/空の場合「分析失敗（{エラー概要}）」として扱う。全次元失敗時はエラー出力して終了
  - Phase 2 Step 4: サブエージェント返答の `modified: 0件` を警告表示し、バックアップ保持のまま Phase 3 へ進む
- 部分完了時:
  - Phase 1: 一部の次元が成功すれば処理継続。成功した次元のみ Phase 2 で扱う
  - Phase 2: 承認数が 0 の場合、改善適用なしで Phase 3 へ直行
- 入力バリデーション:
  - Phase 0: YAML frontmatter の存在確認（不在時は警告表示するが処理継続）
  - Phase 2 Step 4 検証ステップ: 改善適用後、YAML frontmatter の存在確認。検証失敗時はロールバック情報を出力してスキル終了

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/{dim_path}.md（次元定義ファイル） | 4行（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`） | 3-5（グループに応じた次元数） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 2行グループ（`modified: {N}件` + `skipped: {K}件`、各最大20/10件まで列挙） | 1 |
