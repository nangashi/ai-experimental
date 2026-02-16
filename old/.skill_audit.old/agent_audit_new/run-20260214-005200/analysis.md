# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 350 | スキルの実行ワークフロー定義（Phase 0-3、グループ分類、次元マッピング） |
| group-classification.md | 60 | エージェントグループ分類基準（evaluator/producer/hybrid/unclassified） |
| templates/apply-improvements.md | 44 | Phase 2 Step 4: 承認済み findings に基づく改善適用テンプレート |
| antipatterns/instruction-clarity.md | 82 | IC 次元のアンチパターンカタログ |
| antipatterns/criteria-effectiveness.md | 94 | CE 次元のアンチパターンカタログ |
| antipatterns/scope-alignment.md | 34 | SA 次元のアンチパターンカタログ |
| antipatterns/detection-coverage.md | 76 | DC 次元のアンチパターンカタログ |
| antipatterns/workflow-completeness.md | 88 | WC 次元のアンチパターンカタログ |
| antipatterns/output-format.md | 67 | OF 次元のアンチパターンカタログ |
| agents/shared/instruction-clarity.md | 122 | IC 次元: 全グループ共通の分析エージェント定義 |
| agents/evaluator/criteria-effectiveness.md | 89 | CE 次元: evaluator/hybrid グループ向け分析エージェント定義 |
| agents/evaluator/scope-alignment.md | 110 | SA 次元: evaluator/hybrid グループ向け分析エージェント定義 |
| agents/evaluator/detection-coverage.md | 110 | DC 次元: evaluator グループ向け分析エージェント定義 |
| agents/producer/workflow-completeness.md | 107 | WC 次元: producer/hybrid/unclassified グループ向け分析エージェント定義 |
| agents/producer/output-format.md | 115 | OF 次元: producer/hybrid グループ向け分析エージェント定義 |
| agents/unclassified/scope-alignment.md | 81 | SA 次元: unclassified/producer グループ向け軽量版分析エージェント定義 |
| agent_bench/SKILL.md | 372 | 関連スキル: エージェント構造最適化（agent_bench） |
| agent_bench/approach-catalog.md | 202 | agent_bench 用: 改善アプローチカタログ |
| agent_bench/scoring-rubric.md | 70 | agent_bench 用: 採点基準 |
| agent_bench/proven-techniques.md | 70 | agent_bench 用: 実証済みテクニック |
| agent_bench/test-document-guide.md | 254 | agent_bench 用: テスト文書生成ガイド |
| agent_bench/perspectives/code/*.md | 23-37 | agent_bench 用: コードレビュー観点定義（5ファイル） |
| agent_bench/perspectives/design/*.md | 26-51 | agent_bench 用: 設計レビュー観点定義（7ファイル） |
| agent_bench/templates/*.md | 32-101 | agent_bench 用: Phase 別テンプレート（10ファイル） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0**: 初期化・グループ分類・分析次元セット決定・出力ディレクトリ準備
  - **Phase 1**: 並列分析（グループに応じた3-5次元を同時並列実行）
  - **Phase 2**: ユーザー承認（findings 収集 → 承認方針選択 → per-item 承認 → 改善適用 → 検証）
  - **Phase 3**: 完了サマリ（検出結果・承認結果・変更詳細・次ステップ提示）

- データフロー:
  - Phase 0: エージェントファイル読み込み → Grep でグループ判定 → 次元セット決定 → `.agent_audit/{agent_name}/` ディレクトリ作成
  - Phase 1: 各次元エージェント（agents/{dim_path}.md）が独立に `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` を生成
  - Phase 2: Phase 1 の findings ファイルを収集 → ユーザー承認 → `.agent_audit/{agent_name}/audit-approved.md` 生成 → apply-improvements テンプレートで改善適用 → バックアップファイル生成
  - Phase 3: Phase 1-2 の結果を集計してサマリ出力

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 127-172 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 1 で使用する分析次元エージェント定義 |
| SKILL.md | 156 | `.claude/skills/agent_audit_new/antipatterns/{ID_PREFIX の対応カタログ}.md` | 各次元のアンチパターンカタログ参照 |
| SKILL.md | 281 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2 Step 4 の改善適用テンプレート |
| agents/shared/instruction-clarity.md | 117 | `{antipattern_catalog_path}` | IC 次元でアンチパターンカタログ参照 |
| agents/evaluator/criteria-effectiveness.md | 84 | `{antipattern_catalog_path}` | CE 次元でアンチパターンカタログ参照 |
| agents/evaluator/scope-alignment.md | 80 | `{antipattern_catalog_path}` | SA 次元でアンチパターンカタログ参照 |
| agents/evaluator/detection-coverage.md | 105 | `{antipattern_catalog_path}` | DC 次元でアンチパターンカタログ参照 |
| agents/producer/workflow-completeness.md | 102 | `{antipattern_catalog_path}` | WC 次元でアンチパターンカタログ参照 |
| agents/producer/output-format.md | 110 | `{antipattern_catalog_path}` | OF 次元でアンチパターンカタログ参照 |
| agents/unclassified/scope-alignment.md | 74 | `{antipattern_catalog_path}` | SA 軽量版でアンチパターンカタログ参照 |
| agent_bench/* | 多数 | `.agent_bench/{agent_name}/` | agent_bench スキル用の出力ディレクトリ（agent_audit とは独立） |

**外部参照の特徴**: スキル内のテンプレート・エージェント・カタログファイルを動的に参照する設計。エージェント定義ファイルパスは実行時に決定されるため、`.claude/skills/agent_audit_new/` 配下のファイル構成が依存関係となる。

## D. コンテキスト予算分析
- SKILL.md 行数: 350行
- テンプレートファイル数: 1個（apply-improvements.md）、44行
- 分析次元エージェント数: 7個（IC, CE, SA, DC, WC, OF, SA軽量版）、平均行数: 107行
- アンチパターンカタログ数: 6個、平均行数: 74行
- サブエージェント委譲: あり
  - Phase 1: グループに応じた3-5次元の並列実行（各次元が独立して分析 → findings ファイル保存 → 1行サマリ返答）
  - Phase 2 Step 4: 改善適用エージェント（1エージェント、テンプレート読み込み → 改善適用 → 変更サマリ返答）
- 親コンテキストに保持される情報: グループ判定結果、次元リスト、各次元のサマリ（critical/improvement/info 件数）、承認結果カウント
- 3ホップパターンの有無: なし（全サブエージェントがファイル経由でデータ共有、親は中継しない）

**コンテキスト効率化の特徴**:
- Phase 1 サブエージェントは詳細な findings をファイルに保存し、親には1行サマリのみ返答
- Phase 2 で findings ファイルを直接 Read し、親コンテキストには保持しない
- 改善適用エージェントも findings ファイルから直接読み込む（親経由でデータを中継しない）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 Step 1 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 Step 3 | AskUserQuestion | frontmatter 不在時の続行確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認（承認/スキップ/残りすべて承認/キャンセル）× findings 数 | 不明 |
| Phase 2 Step 4 | AskUserQuestion | サブエージェント失敗時の再試行/スキップ/キャンセル確認 | 不明 |
| Phase 2 検証 | AskUserQuestion | 検証失敗時のロールバック確認 | 不明 |

**Fast mode での扱いについて**: SKILL.md に fast mode の記載なし。agent_bench スキルの MEMORY 記録では「fastモードで中間確認をスキップ可能に」とあるが、agent_audit には未適用。

## F. エラーハンドリングパターン
- ファイル不在時: Phase 0 Step 2 で `ls {agent_path}` を実行し、存在しない場合はエラー出力して終了
- サブエージェント失敗時:
  - Phase 1: findings ファイルの存在で成否判定。全失敗時はエラー出力して終了、部分失敗時は警告出力して続行
  - Phase 2 Step 4: 改善適用サブエージェント失敗時は AskUserQuestion で「再試行/Phase 3へスキップ/キャンセル」を確認
- 部分完了時: Phase 1 で一部次元が失敗しても、成功した次元で Phase 2 へ進む（警告付き）
- 入力バリデーション:
  - Phase 0 Step 3: YAML frontmatter の存在確認、不在時は AskUserQuestion で続行確認
  - Phase 0 Step 4: Grep でグループ判定、どのグループにも該当しない場合は unclassified に分類（エラーではない）
  - Phase 2 検証: 改善適用後、YAML frontmatter と description フィールドの存在を Grep で確認、失敗時はロールバック確認

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/{dim_path}.md（3-5次元、グループに応じて変動） | 1行（dim: {次元名}, critical: {N}, improvement: {M}, info: {K}） | 3-5（グループに応じて変動） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 複数行（modified: {N}件 + リスト、skipped: {K}件 + リスト） | 1 |

**並列実行の特徴**:
- Phase 1: 全次元を同一メッセージ内で並列起動（hybrid=5次元、evaluator=4次元、producer=4次元、unclassified=3次元）
- Phase 2: サブエージェントは1つのみ、並列実行なし
