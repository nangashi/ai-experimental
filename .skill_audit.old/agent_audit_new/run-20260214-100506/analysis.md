# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | スキルのメイン定義。インターフェース、ワークフロー、グループ分類ロジック、各フェーズの手順を定義 |
| group-classification.md | 22 | エージェントグループ分類基準（evaluator/producer/hybrid/unclassified）の特徴定義と判定ルール |
| agents/evaluator/criteria-effectiveness.md | 185 | 評価基準の有効性を分析するレビューアエージェント（基準有効性次元、CE）|
| agents/evaluator/scope-alignment.md | 169 | evaluator エージェントのスコープ整合性を分析するレビューアエージェント（SA次元、evaluator向け）|
| agents/evaluator/detection-coverage.md | 200 | evaluator エージェントの検出カバレッジを分析するレビューアエージェント（DC次元）|
| agents/producer/workflow-completeness.md | 190 | producer エージェントのワークフロー完全性を分析するレビューアエージェント（WC次元）|
| agents/producer/output-format.md | 195 | producer エージェントの出力形式実現性を分析するレビューアエージェント（OF次元）|
| agents/unclassified/scope-alignment.md | 150 | 一般エージェントのスコープ整合性を分析する軽量版レビューアエージェント（SA次元、軽量版）|
| agents/shared/instruction-clarity.md | 206 | 全グループ共通の指示明確性を分析するレビューアエージェント（IC次元）|
| templates/apply-improvements.md | 38 | 承認済み findings に基づいてエージェント定義を改善するサブエージェント用テンプレート |

## B. ワークフロー概要
- フェーズ構成: Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）

### 各フェーズの目的
- **Phase 0**: エージェント定義ファイルを読み込み、グループ分類（evaluator/producer/hybrid/unclassified）を実行し、分析次元セットを決定する
- **Phase 1**: グループに応じた分析次元セット（3-5次元）を並列でサブエージェントに委譲し、各次元の findings を生成する
- **Phase 2**: 全次元の findings を収集し、critical/improvement の指摘をユーザーに提示して承認を取得し、承認された改善をサブエージェントに委譲して適用する
- **Phase 3**: 検出・承認・適用の結果を集計し、完了サマリと次のステップ推奨を出力する

### データフロー
- **Phase 0 → Phase 1**: `{agent_content}`（エージェント定義本文）、`{agent_group}`（分類結果）、`{dimensions}`（分析次元リスト）
- **Phase 1 生成**: 各次元ごとに `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` ファイル（findings）を生成
- **Phase 1 → Phase 2**: 各サブエージェントから返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）を収集
- **Phase 2 Step 1**: 全次元の findings ファイル（`.agent_audit/{agent_name}/audit-*.md`）を Read して critical/improvement 指摘を抽出
- **Phase 2 Step 3**: ユーザー承認結果を `.agent_audit/{agent_name}/audit-approved.md` に Write
- **Phase 2 Step 4**: `audit-approved.md` と `{agent_path}` をサブエージェント（apply-improvements テンプレート）に渡して改善適用
- **Phase 2 検証**: 改善適用後、`{agent_path}` を Read して YAML frontmatter の存在確認
- **Phase 3**: Phase 1・Phase 2 のメタデータ（件数・承認数・スキップ数・バックアップパス）を使用してサマリを生成

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit_new/group-classification.md` | グループ分類基準の詳細ドキュメント参照 |
| SKILL.md | 221 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | 改善適用サブエージェントのテンプレート参照 |

（注: エージェント定義ファイル `{agent_path}` は外部入力であり、スキル構造外のパスとして扱う）

## D. コンテキスト予算分析
- SKILL.md 行数: 279行
- テンプレートファイル数: 1個（apply-improvements.md、38行）
- サブエージェント委譲: あり
  - Phase 1: 3-5個の並列サブエージェント（グループに応じた次元数。各サブエージェントは agents/{dim_path}.md を使用）
  - Phase 2 Step 4: 1個のサブエージェント（templates/apply-improvements.md を使用）
- 親コンテキストに保持される情報:
  - グループ分類結果（`{agent_group}`）
  - 分析次元リスト（`{dimensions}`）
  - 各サブエージェントからの返答サマリ（次元名、critical/improvement/info 件数）
  - ユーザー承認結果（承認数、スキップ数）
  - バックアップファイルパス
- 3ホップパターンの有無: なし（全サブエージェントは findings をファイルに保存し、親は直接ファイルから読み込む）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | `agent_path` が未指定の場合にファイルパスを確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認 / 1件ずつ確認 / キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認ループ（承認 / スキップ / 残りすべて承認 / キャンセル） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: `{agent_path}` の Read 失敗時はエラー出力して終了
  - Phase 2 Step 4: バックアップ失敗時の処理は未定義（Bash コマンド実行のみ）
- サブエージェント失敗時:
  - Phase 1: 各サブエージェントの findings ファイル存在確認により成否判定。全失敗の場合はエラー出力して終了。部分失敗の場合は成功した次元のみで処理継続
  - Phase 2 Step 4: 改善適用サブエージェントの失敗処理は未定義（返答内容をテキスト出力するのみ）
- 部分完了時:
  - Phase 1: 一部のサブエージェントが失敗しても、成功した次元の findings を使用して Phase 2 へ進む
  - Phase 2: 承認数が 0 の場合は改善適用をスキップして Phase 3 へ直行
- 入力バリデーション:
  - Phase 0: YAML frontmatter の存在確認（簡易チェック）。不在時は警告を出力するが処理継続
  - Phase 2 検証ステップ: 改善適用後、YAML frontmatter の存在確認。検証失敗時は警告とロールバックコマンドを出力

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/{dim_path}.md（グループに応じて3-5次元） | 4行（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`） | 3-5個（グループにより変動） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 可変（`modified: {N}件` + `skipped: {K}件` + 各項目） | 1個 |

**注**: Phase 1 の並列数の詳細
- hybrid: 5個（IC, CE, SA, WC, OF）
- evaluator: 4個（IC, CE, SA, DC）
- producer: 4個（IC, WC, OF, SA-軽量版）
- unclassified: 3個（IC, SA-軽量版, WC）
