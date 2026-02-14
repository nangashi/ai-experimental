# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 290 | スキルのメインワークフロー定義（Phase 0-3）。エージェント分類、並列分析、承認フロー、改善適用を統括 |
| agents/evaluator/criteria-effectiveness.md | 184 | 評価基準の有効性分析エージェント。S/N比、実行可能性、費用対効果を二段階検出方式で評価（CE次元） |
| agents/evaluator/scope-alignment.md | 168 | 評価者エージェント向けスコープ整合性分析。境界定義、基準-ドメインカバレッジを評価（SA次元） |
| agents/evaluator/detection-coverage.md | 200 | 検出戦略の完全性・severity分類・出力形式・偽陽性リスクを分析（DC次元） |
| group-classification.md | 22 | エージェント種別判定基準（hybrid/evaluator/producer/unclassified）。evaluator/producer特徴各4項目に基づく判定ルール |
| agents/producer/workflow-completeness.md | 190 | ワークフロー完全性分析。ステップ順序、データフロー、エラーパス、条件分岐網羅性を評価（WC次元） |
| agents/producer/output-format.md | 195 | 出力形式実現性分析。形式の実現可能性、下流利用可能性、情報完全性、セクション間整合性を評価（OF次元） |
| agents/unclassified/scope-alignment.md | 150 | 汎用エージェント向けスコープ整合性分析（軽量版）。目的明確性、フォーカス適切性、境界暗黙性を評価（SA次元） |
| agents/shared/instruction-clarity.md | 205 | 指示明確性分析。ドキュメント構造、役割定義、コンテキスト完全性、指示有効性を評価（IC次元） |
| templates/apply-improvements.md | 37 | 承認済みfindings適用テンプレート。適用順序決定、二重適用チェック、変更適用ルール定義 |
| templates/phase1-parallel-analysis.md | 15 | Phase 1並列分析テンプレート。dim_pathのエージェント定義を読み込み、findings保存、返答フォーマット指定 |

## B. ワークフロー概要
- フェーズ構成: Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）
- Phase 0: agent_path読み込み → frontmatterチェック → グループ分類（group-classification.md参照）→ agent_name導出 → 出力ディレクトリ作成 → 分析次元セット決定
- Phase 1: dim_count個のTaskを並列起動（templates/phase1-parallel-analysis.md使用）→ 各次元のエージェント（agents/{dim_path}.md）が findings 生成 → エラーハンドリング（findingsファイル存在確認）→ サマリ収集
- Phase 2: Step 1（findings収集 - Read）→ Step 2（一覧提示 + AskUserQuestion）→ Step 2a（per-item承認ループ - 条件分岐）→ Step 3（承認結果保存 - Write）→ Step 4（改善適用 - Task with templates/apply-improvements.md）→ 検証ステップ（frontmatter再確認）
- Phase 3: 完了サマリ出力（条件分岐: 改善対象なし / 改善実行 / スキップあり）
- データフロー: Phase 0 → agent_content → Phase 1各Task → .agent_audit/{agent_name}/audit-{ID_PREFIX}.md → Phase 2 Step 1 → audit-approved.md → Phase 2 Step 4 → {agent_path}（更新）→ Phase 3

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 70 | `.claude/skills/agent_audit_new/group-classification.md` | エージェントグループ分類基準の参照（Phase 0） |
| SKILL.md | 121 | `.claude/skills/agent_audit_new/templates/phase1-parallel-analysis.md` | Phase 1並列分析のテンプレート読み込み指示 |
| SKILL.md | 233 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2改善適用のテンプレート読み込み指示 |
| templates/phase1-parallel-analysis.md | 3 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | 各次元のエージェント定義ファイル（動的パス） |

## D. コンテキスト予算分析
- SKILL.md 行数: 290行
- テンプレートファイル数: 2個、平均行数: 26行
- サブエージェント委譲: あり（Phase 1: dim_count個並列Task、Phase 2 Step 4: 1個Task）
  - Phase 1: 各次元の分析を独立したTaskに委譲（model: sonnet, subagent_type: general-purpose）
  - Phase 2 Step 4: 改善適用を1個のTaskに委譲（model: sonnet, subagent_type: general-purpose）
- 親コンテキストに保持される情報: agent_path, agent_name, agent_group, dim_count, dimensions配列, Phase 1各次元の返答サマリ（critical/improvement/info件数）、Phase 2承認結果メタデータ（承認数/スキップ数/total）
- 3ホップパターンの有無: なし（全てファイル経由通信）
  - Phase 1: 親 → Task（dim path指定）→ findings保存 → 親がRead
  - Phase 2 Step 4: 親 → Task（approved findings path指定）→ agent_path更新 → 親が検証

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | 各finding個別の承認確認（承認/スキップ/残りすべて承認/キャンセル） | 不明 |
| Phase 2 Step 4 | AskUserQuestion | バックアップ作成失敗時の続行確認（続行/キャンセル） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: agent_path読み込み失敗時、エラー出力して終了
  - Phase 2 Step 4: バックアップ検証失敗時、AskUserQuestionで続行確認。キャンセル時はPhase 3へ直行
- サブエージェント失敗時:
  - Phase 1: 各次元のfindingsファイル存在・非空チェック。存在しない/空 → 失敗として扱い、Task返答からエラー概要抽出。全次元失敗時はエラー出力して終了
  - Phase 2 Step 4: サブエージェント返答（変更サマリ）をテキスト出力するが、失敗時の明示的な処理は未定義
- 部分完了時:
  - Phase 1: 成功数/dim_countを出力。critical + improvement合計0の場合、Phase 2スキップしてPhase 3へ直行
  - Phase 2 Step 2a: 「残りすべて承認」「キャンセル」でループ途中離脱可能。承認数0の場合、Phase 2残りスキップしてPhase 3へ直行
- 入力バリデーション:
  - Phase 0: ファイル先頭YAML frontmatter（`---`で囲まれ`description:`含む）チェック。不在時は警告出力するが処理継続
  - Phase 2 Step 4後: agent_path再読み込みしfrontmatter存在確認。失敗時は検証失敗メッセージ出力＋ロールバックコマンド提示

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | phase1-parallel-analysis.md | 3行（dim, critical, improvement, info） | dim_count個（hybrid:5, evaluator:4, producer:4, unclassified:3） |
| Phase 2 Step 4 | sonnet | apply-improvements.md | 可変（modified件数 + skipped件数 + 各1行詳細） | 1個 |
