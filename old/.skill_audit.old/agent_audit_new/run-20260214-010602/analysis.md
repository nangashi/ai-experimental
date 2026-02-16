# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 376 | メインワークフロー定義（Phase 0〜3）、グループ分類、次元マッピング、エラーハンドリング |
| group-classification.md | 22 | エージェントグループ判定基準（evaluator/producer/hybrid/unclassified） |
| templates/apply-improvements.md | 44 | Phase 2 改善適用サブエージェント指示 |
| templates/phase1-dimension-analysis.md | 31 | Phase 1 次元分析サブエージェント指示 |
| antipatterns/instruction-clarity.md | 82 | IC次元アンチパターンカタログ（ロール定義、コンテキスト、構造、メタ指示、有効性） |
| antipatterns/criteria-effectiveness.md | 94 | CE次元アンチパターンカタログ（曖昧性、構造、実行可能性、効率性、S/N比評価） |
| antipatterns/scope-alignment.md | 34 | SA次元アンチパターンカタログ（スコープ拡散、境界曖昧性、重複、ドリフト） |
| antipatterns/detection-coverage.md | 74 | DC次元アンチパターンカタログ（暗黙的検出、重大度重複、証拠不足、制限なし検出） |
| antipatterns/workflow-completeness.md | 88 | WC次元アンチパターンカタログ（依存関係、データフロー、エラーパス、分岐、並列化） |
| antipatterns/output-format.md | 72 | OF次元アンチパターンカタログ（実行不可能性、情報損失、矛盾、解析不能） |
| agents/shared/instruction-clarity.md | 136 | IC次元評価エージェント定義（5検出戦略、敵対的思考、構造・ロール・コンテキスト分析） |
| agents/evaluator/criteria-effectiveness.md | 103 | CE次元評価エージェント定義（5検出戦略、基準品質・実行可能性・クロスチェック） |
| agents/evaluator/scope-alignment.md | 119 | SA次元評価エージェント定義（5検出戦略、スコープ境界・一貫性・カバレッジギャップ） |
| agents/evaluator/detection-coverage.md | 124 | DC次元評価エージェント定義（5検出戦略、検出完全性・重大度分類・証拠品質・FP評価） |
| agents/producer/workflow-completeness.md | 122 | WC次元評価エージェント定義（5検出戦略、依存関係・データフロー・エラー・分岐・並列化） |
| agents/producer/output-format.md | 129 | OF次元評価エージェント定義（5検出戦略、実現可能性・下流互換性・完全性・一貫性） |
| agents/unclassified/scope-alignment.md | 95 | SA次元軽量版評価エージェント定義（4検出戦略、目的明確性・焦点一貫性・境界認識） |
| agent_bench/approach-catalog.md | 201 | agent_bench スキルのバリアント生成テクニックカタログ（S/C/N/M分類、実証済み効果記録） |
| agent_bench/SKILL.md | 372 | agent_bench スキルのワークフロー定義（perspective解決、バリアント生成、テスト評価） |
| agent_bench/scoring-rubric.md | 70 | agent_bench スキルの採点基準（検出判定○△×、ボーナス/ペナルティ、推奨判定） |
| agent_bench/proven-techniques.md | 70 | agent_bench スキルの実証済みテクニック自動集約ファイル（Phase 6B更新） |
| agent_bench/test-document-guide.md | 254 | agent_bench スキルのテスト文書生成ガイド（入力型、問題埋め込み、正解キー） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - Phase 0: 初期化・グループ分類（Grep特徴検出→evaluator/producer/hybrid/unclassified判定→次元セット決定）
  - Phase 1: 並列分析（グループに応じた3-5次元をsonnetサブエージェントで並列分析、findings ファイル保存）
  - Phase 2: ユーザー承認 + 改善適用（per-item承認→サブエージェント委譲で改善→検証）
  - Phase 3: 完了サマリ（検出件数、承認結果、変更詳細、バックアップパス、次ステップ提示）
- データフロー:
  - Phase 0 → Phase 1: agent_path, agent_name, 次元リスト, ID_PREFIX, antipattern_catalog_path
  - Phase 1 → Phase 2: findings ファイル（.agent_audit/{agent_name}/audit-{ID_PREFIX}.md）
  - Phase 2 → Phase 3: approved findings（.agent_audit/{agent_name}/audit-approved.md）、変更結果、backup_path

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 127 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 0で決定した次元エージェントファイルパスの解決 |
| SKILL.md | 176-184 | `.claude/skills/agent_audit_new/antipatterns/{ID_PREFIX}.md` | Phase 1で各次元に対応するアンチパターンカタログパスのマッピング |
| SKILL.md | 162 | `.claude/skills/agent_audit_new/templates/phase1-dimension-analysis.md` | Phase 1サブエージェントテンプレート |
| SKILL.md | 295 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2改善適用サブエージェントテンプレート |
| SKILL.md | 114 | `.agent_audit/{agent_name}/` | 出力ディレクトリ（スキル外だがスキル管理下） |

## D. コンテキスト予算分析
- SKILL.md 行数: 376行
- テンプレートファイル数: 2個、平均行数: 37.5行
- サブエージェント委譲: あり（Phase 1で3-5並列、Phase 2で1、全てsonnet）
- 親コンテキストに保持される情報: agent_path, agent_name, agent_group, 次元リスト, ID_PREFIX, findings件数集計（critical/improvement/info）、承認結果（承認数/スキップ数）、変更サマリ（modified/skipped）
- 3ホップパターンの有無: なし（Phase 1 findings → Phase 2でファイル直接参照、サブエージェント間はファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | frontmatter不在時の続行確認 | 不明 |
| Phase 1 | AskUserQuestion | 全次元失敗時のエラー後（再試行/キャンセル） | 不明 |
| Phase 2 | AskUserQuestion | 承認方針選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 | AskUserQuestion | Per-item承認（承認/スキップ/残りすべて承認/キャンセル） | 不明 |
| Phase 2 | AskUserQuestion | 改善適用続行確認 | 不明 |
| Phase 2 | AskUserQuestion | 改善適用失敗時の対処（再試行/Phase 3へスキップ/キャンセル） | 不明 |
| Phase 2 | AskUserQuestion | 検証失敗時のロールバック確認 | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時: Phase 0でBash ls実行→不在ならエラー出力して終了
- サブエージェント失敗時:
  - Phase 1: 全失敗→エラー終了、部分失敗→警告で続行
  - Phase 2: 改善適用失敗時にAskUserQuestion（再試行/Phase 3へスキップ/キャンセル）
- 部分完了時: Phase 1で成功した次元のみで Phase 2 へ進む（失敗次元リストを警告表示）
- 入力バリデーション: frontmatter存在チェック（不在時はAskUserQuestionで続行確認、拒否時は終了）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | phase1-dimension-analysis.md | 1行（`saved: {path}` または `error: {概要}`） | 3-5（グループ依存） |
| Phase 2 | sonnet | apply-improvements.md | 可変（`modified: N件` + `skipped: K件` + 詳細リスト） | 1 |
