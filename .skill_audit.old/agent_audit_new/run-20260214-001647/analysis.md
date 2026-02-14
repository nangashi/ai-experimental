# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 298 | メインワークフロー定義（Phase 0-3） |
| group-classification.md | 22 | エージェントグループ分類基準 |
| agents/shared/instruction-clarity.md | 206 | IC次元: 指示明確性分析エージェント |
| agents/evaluator/criteria-effectiveness.md | 185 | CE次元: 基準有効性分析エージェント |
| agents/evaluator/scope-alignment.md | 169 | SA次元: スコープ整合性分析エージェント（evaluator用） |
| agents/evaluator/detection-coverage.md | 201 | DC次元: 検出カバレッジ分析エージェント |
| agents/producer/workflow-completeness.md | 191 | WC次元: ワークフロー完全性分析エージェント |
| agents/producer/output-format.md | 196 | OF次元: 出力形式実現性分析エージェント |
| agents/unclassified/scope-alignment.md | 151 | SA次元: スコープ整合性分析エージェント（unclassified/producer用） |
| templates/apply-improvements.md | 44 | Phase 2 Step 4: 改善適用サブエージェント |
| agent_bench/SKILL.md | 372 | 外部参照: agent_bench スキル定義 |
| agent_bench/approach-catalog.md | 202 | 外部参照: 改善アプローチカタログ |
| agent_bench/scoring-rubric.md | 70 | 外部参照: agent_bench 採点基準 |
| agent_bench/proven-techniques.md | 70 | 外部参照: 実証済みテクニック |
| agent_bench/test-document-guide.md | 254 | 外部参照: テスト文書生成ガイド |
| agent_bench/templates/* | 11ファイル | 外部参照: agent_bench サブエージェントテンプレート |
| agent_bench/perspectives/* | 14ファイル | 外部参照: agent_bench 観点定義群 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0**: 初期化・グループ分類。エージェント定義を読み込み、evaluator/producer/hybrid/unclassified に分類し、グループに応じた分析次元セット（3-5次元）を決定。出力ディレクトリ初期化
  - **Phase 1**: 並列分析。グループに応じた次元セット（IC + グループ固有次元）のエージェントをサブエージェントとして並列実行し、各次元の findings を `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に保存
  - **Phase 2**: ユーザー承認 + 改善適用。findings を一覧提示し、ユーザー承認方針（全承認/1件ずつ確認/キャンセル）を確認。承認された指摘を `audit-approved.md` に保存し、apply-improvements サブエージェントに委譲して改善適用。バックアップ作成と検証を実行
  - **Phase 3**: 完了サマリ。分析結果、承認状況、変更詳細、次ステップ推奨を出力
- データフロー:
  - Phase 0 → Phase 1: エージェントパスとグループ分類結果
  - Phase 1 → Phase 2: 各次元の findings ファイルパス（Read は実行しない）
  - Phase 2 → Phase 3: 承認数、変更詳細、バックアップパス

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 174 | `.agent_audit/{agent_name}/audit-*.md` | Phase 1B のバリアント生成時に audit findings を参照（agent_bench との連携） |
| agents/evaluator/criteria-effectiveness.md | 12 | IC 次元 | スコープ境界の明示（役割定義・ガイドライン・制約等は IC が担当） |
| agents/evaluator/scope-alignment.md | なし | なし | スコープ内で完結 |
| agents/evaluator/detection-coverage.md | なし | なし | スコープ内で完結 |
| agents/producer/workflow-completeness.md | 14 | IC 次元, OF 次元 | スコープ境界の明示（ドキュメント構造は IC、最終出力形式設計は OF が担当） |
| agents/producer/output-format.md | なし | なし | スコープ内で完結 |
| agents/unclassified/scope-alignment.md | なし | なし | スコープ内で完結 |
| agents/shared/instruction-clarity.md | 113 | CE 次元 | スコープ境界の明示（評価基準の品質は CE が担当） |
| SKILL.md（全体） | 全体 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 1 で次元エージェントを Read で読み込む（スキル内参照） |
| SKILL.md（全体） | 全体 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2 Step 4 で改善適用テンプレートを Read で読み込む（スキル内参照） |
| SKILL.md（全体） | 全体 | `.agent_audit/{agent_name}/` | 出力ディレクトリ（プロジェクトルート配下） |

**外部参照の分類**:
- **スキル外への参照**: `.agent_audit/{agent_name}/audit-*.md`（agent_bench スキルとの連携用、ただし存在しない場合は空として扱われるため必須依存ではない）
- **スキル内参照**: agents/, templates/ 配下のファイル（すべて `.claude/skills/agent_audit_new/` 内に存在）

## D. コンテキスト予算分析
- SKILL.md 行数: 298行
- テンプレートファイル数: 1個（apply-improvements.md: 44行）
- 次元エージェントファイル数: 8個、平均行数: 180行（IC: 206行、CE: 185行、SA-evaluator: 169行、DC: 201行、WC: 191行、OF: 196行、SA-unclassified: 151行、分類基準: 22行）
- サブエージェント委譲: あり
  - **Phase 1**: グループに応じて3-5次元のエージェントを並列起動（全て同一メッセージ内）。各サブエージェントは次元エージェント定義を Read し、その指示に従って分析を実行。返答は1行サマリのみ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）。詳細は findings ファイルに保存される
  - **Phase 2 Step 4**: apply-improvements テンプレートを使用して改善適用サブエージェント（model: sonnet）を起動。返答は変更サマリのみ（modified/skipped リスト）
- 親コンテキストに保持される情報:
  - グループ分類結果（evaluator/producer/hybrid/unclassified）
  - 分析次元セット（次元名リスト、3-5個）
  - 各次元のサブエージェント返答（1行サマリ: critical/improvement/info 件数）
  - ユーザー承認結果（承認数/スキップ数）
  - 改善適用結果（modified/skipped リスト）
  - **findings の全内容は保持しない**（ファイル経由でサブエージェントとやり取り）
- 3ホップパターンの有無: なし
  - Phase 1 のサブエージェント結果は findings ファイルに保存され、Phase 2 で直接 Read される（親を中継しない）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | 引数未指定時のエージェントパス確認 | 不明 |
| Phase 0 | AskUserQuestion | frontmatter 欠如時の続行確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認（承認/スキップ/残りすべて承認/キャンセル） | 「1件ずつ確認」選択時のみ |
| Phase 2 Step 4 | AskUserQuestion | 改善適用失敗時の再試行/スキップ/キャンセル確認 | 不明 |
| Phase 2 検証 | AskUserQuestion | 検証失敗時のロールバック確認 | 不明 |

**Fast mode への言及**: なし（SKILL.md に fast mode スキップに関する記述なし）

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - エージェント定義ファイル不在 → エラー出力して終了（Phase 0 Step 2）
  - audit findings ファイル不在 → Phase 1B バリアント生成時に空として扱う（SKILL.md 174行）
- **サブエージェント失敗時**:
  - Phase 1: 各サブエージェントの成否を findings ファイルの存在で判定。findings ファイル不在 → 失敗として扱い「分析失敗（{エラー概要}）」と記録。全て失敗 → エラー出力して終了
  - Phase 2 Step 4: 改善適用サブエージェント失敗時 → AskUserQuestion で再試行/スキップ/キャンセル確認
- **部分完了時**:
  - Phase 1: 一部の次元が失敗しても成功した次元のみで Phase 2 へ進む（全次元失敗の場合のみ終了）
  - Phase 2: 承認数が 0 の場合 → 改善適用をスキップして Phase 3 へ直行
- **入力バリデーション**:
  - Phase 0 Step 3: frontmatter（`---` で囲まれた `description:` を含むブロック）の存在確認。存在しない場合 → AskUserQuestion で続行確認

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 1行（`dim: IC, critical: {N}, improvement: {M}, info: {K}`） | グループに応じて3-5個（hybrid: 5, evaluator: 4, producer: 4, unclassified: 3）|
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 1行 | |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 1行 | |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 1行 | |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 1行 | |
| Phase 1 | sonnet | agents/producer/output-format.md | 1行 | |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 1行 | |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 複数行（modified/skipped リスト） | 1個 |

**並列実行の詳細**:
- Phase 1: 全次元のサブエージェントを同一メッセージ内で並列起動
- 各サブエージェントは独立して動作し、findings ファイルに保存後、1行サマリを返答
- 親は全サブエージェントの完了を待ち、成功数を集計してから Phase 2 へ進む
