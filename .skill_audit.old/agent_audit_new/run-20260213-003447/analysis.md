# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 352 | スキルのメインエントリポイント。グループ分類、ワークフロー、インターフェース定義 |
| group-classification.md | 22 | エージェントグループ判定基準（evaluator/producer/hybrid/unclassified） |
| agents/shared/detection-process-common.md | 30 | Detection-First, Reporting-Second プロセスの共通説明 |
| agents/evaluator/criteria-effectiveness.md | 169 | CE次元: 評価基準の有効性分析（曖昧さ、S/N比、実行可能性、費用対効果） |
| agents/evaluator/detection-coverage.md | 185 | DC次元: 検出カバレッジ分析（検出戦略完全性、severity分類、出力形式、偽陽性リスク） |
| agents/evaluator/scope-alignment.md | 153 | SA次元（evaluator版）: スコープ整合性分析（境界明確性、基準-ドメインカバレッジ） |
| agents/producer/workflow-completeness.md | 175 | WC次元: ワークフロー完全性分析（ステップ依存、データフロー、エラーパス、条件分岐） |
| agents/producer/output-format.md | 180 | OF次元: 出力形式実現性分析（達成可能性、下流互換性、情報完全性） |
| agents/shared/instruction-clarity.md | 156 | IC次元: 指示明確性分析（役割定義、コンテキスト充足、情報構造） |
| agents/unclassified/scope-alignment.md | 135 | SA次元（軽量版）: 目的明確性、フォーカス適切性、境界暗黙性 |
| templates/apply-improvements.md | 43 | Phase 2 Step 4: 承認済み findings の適用処理 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0（初期化・グループ分類）**: エージェント定義読み込み、グループ判定、分析次元セット決定、出力ディレクトリ作成
  - **Phase 1（並列分析）**: 決定した次元セットでサブエージェント並列起動。各次元の findings を `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に保存
  - **Phase 2（ユーザー承認 + 改善適用）**:
    - Step 1: findings 収集（サブエージェント委譲、findings-summary.md 生成）
    - Step 2: ユーザー承認方針選択（全承認/1件ずつ/キャンセル）、per-item承認ループ（必要時）
    - Step 3: 承認結果を audit-approved.md に保存
    - Step 4: 改善適用（バックアップ作成 → サブエージェント委譲 → apply-improvements.md テンプレート使用）
    - 検証ステップ: 構造検証（YAML frontmatter、見出し行）、外部参照整合性（analysis.md が存在する場合）
  - **Phase 3（完了サマリ）**: 実行結果サマリ出力（検出件数、承認件数、変更詳細、バックアップパス、次アクション推奨）

- データフロー:
  - Phase 0 → Phase 1: `{agent_path}`, `{agent_name}`, `{agent_group}`, dimensions テーブル
  - Phase 1 → Phase 2: findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）
  - Phase 2 Step 1: findings-summary.md 生成
  - Phase 2 Step 3: audit-approved.md 生成
  - Phase 2 Step 4: バックアップファイル生成、エージェント定義変更

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 105 | `.claude/skills/agent_audit_new/group-classification.md` | グループ分類基準の参照 |
| SKILL.md | 49 | `.skill_audit/{skill_name}/run-{timestamp}/analysis.md` | スキル構造分析結果の参照（外部参照整合性検証用、オプショナル） |
| agents/evaluator/criteria-effectiveness.md | 23 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 検出プロセス共通説明の参照 |
| agents/evaluator/detection-coverage.md | 137 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 検出プロセス共通説明の参照 |
| agents/evaluator/scope-alignment.md | 23 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 検出プロセス共通説明の参照 |
| agents/producer/workflow-completeness.md | 24 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 検出プロセス共通説明の参照 |
| agents/producer/output-format.md | 24 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 検出プロセス共通説明の参照 |
| agents/shared/instruction-clarity.md | 22 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 検出プロセス共通説明の参照 |
| agents/unclassified/scope-alignment.md | 89 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 検出プロセス共通説明の参照 |
| templates/apply-improvements.md | なし | パス変数経由で外部参照（agent_path, approved_findings_path） | 変更対象の指定（サブエージェント実行時にパス変数として解決） |

## D. コンテキスト予算分析
- SKILL.md 行数: 352行
- テンプレートファイル数: 1個（apply-improvements.md: 43行）、分析エージェント数: 8個、平均行数: 約157行
- サブエージェント委譲: あり
  - Phase 1: 次元数（3-5個）の並列サブエージェント（次元分析、model: sonnet）
  - Phase 2 Step 1: 1個のサブエージェント（findings 収集、model: sonnet）
  - Phase 2 Step 4: 1個のサブエージェント（改善適用、model: sonnet）
- 親コンテキストに保持される情報:
  - Phase 0 導出データ: `{agent_name}`, `{agent_group}`, dimensions テーブル, `{dim_count}`, `{fast_mode}`
  - Phase 1 返答サマリ: 各次元の成否、件数（critical/improvement/info）、エラー概要（失敗時）
  - Phase 2 Step 1 返答サマリ: total/critical/improvement 件数
  - Phase 2 Step 2-3: 承認方針、承認/スキップ件数、承認 findings のメタデータ（ID/severity/title/次元名）
  - Phase 2 Step 4 返答サマリ: 変更サマリ（modified/skipped 件数、finding ID リスト）
  - バックアップパス（`{backup_path}`）
  - 検証結果フラグ（`{validation_failed}`）
- 3ホップパターンの有無: なし
  - 全データ交換はファイル経由。サブエージェントは findings/summary/approved ファイルに保存し、親は Read で取得する。親がサブエージェント返答を別サブエージェントに中継するパターンは存在しない

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path が未指定時にパスを確認 | 適用（Fast mode でも未指定時は確認が必要） |
| Phase 1 | AskUserQuestion | 部分失敗時に継続/中止を確認（成功数≧1 かつ（IC成功 または 成功数≧2）の場合） | 不明（SKILL.md に Fast mode での部分失敗時の扱いは未記載） |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全承認/1件ずつ確認/キャンセル） | スキップ（Fast mode では全 findings を自動承認） |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認（承認/スキップ/残りすべて承認/キャンセル/修正して承認） | スキップ（Fast mode では Step 2 自体がスキップされる） |

## F. エラーハンドリングパターン
- ファイル不在時:
  - **{agent_path} 不在**: Phase 0: Read 失敗時、エラー出力して終了
  - **group-classification.md 不在**: Phase 0: エラー出力して終了
  - **analysis.md 不在**: Phase 2 検証ステップ: 外部参照整合性検証をスキップ（警告なし、検証継続）
  - **findings ファイル不在**: Phase 1: 該当次元を失敗として記録、部分失敗判定へ
- サブエージェント失敗時:
  - **Phase 1 全次元失敗**: エラー出力して終了
  - **Phase 1 部分失敗**:
    - 中止条件（成功数=0 または（IC失敗 かつ 成功数=1））: エラー出力して終了
    - 継続条件（上記以外）: AskUserQuestion で継続/中止をユーザーに確認
  - **Phase 2 Step 1 失敗**: 未定義（SKILL.md に記載なし）
  - **Phase 2 Step 4 失敗**: エラー出力（バックアップ復旧コマンド提示）、Phase 3 へ進む（改善適用なしとして扱う）
- 部分完了時:
  - Phase 1 部分失敗時: 成功次元のみで Phase 2 へ進む（ユーザー承認後）
  - Phase 2 承認数0: 改善適用をスキップして Phase 3 へ直行
  - Phase 2 部分スキップ: skipped に理由を記録し、適用可能な findings のみ適用
- 入力バリデーション:
  - **YAML frontmatter 不在**: Phase 0: 警告出力、処理は継続
  - **findings の件数抽出失敗**: Phase 1: 「件数取得失敗」として記録、Phase 2 Step 1 で findings ファイルから再取得
  - **失敗次元の findings 混入**: Phase 2 Step 1: 内部エラー出力、処理中止
  - **バックアップ作成失敗**: Phase 2 Step 4: エラー出力、Phase 3 へ直行（改善適用なし）
  - **検証失敗**: Phase 2 検証ステップ: `{validation_failed} = true` を記録、Phase 3 サマリで警告表示（ロールバックコマンド提示）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1（並列分析） | sonnet | agents/{dim_path}.md（次元ごと）| 4行（dim: {name}, critical: N, improvement: M, info: K） | 次元数（3-5個、グループ依存） |
| Phase 2 Step 1（findings 収集） | sonnet | なし（prompt 直接記述） | 3行（total: N, critical: C, improvement: I） | 1個 |
| Phase 2 Step 4（改善適用） | sonnet | templates/apply-improvements.md | 10行程度（modified: N件, skipped: K件, 各finding ID+変更概要/スキップ理由） | 1個 |
