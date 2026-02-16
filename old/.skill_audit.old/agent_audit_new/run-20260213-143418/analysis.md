# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 322 | スキルのメインワークフロー定義。Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（承認+改善適用）→ Phase 3（完了サマリ）を記述 |
| group-classification.md | 24 | グループ分類基準。evaluator/producer/hybrid/unclassified の4グループへの分類ルールを定義 |
| templates/apply-improvements.md | 40 | 改善適用サブエージェント用テンプレート。承認済み findings をエージェント定義に適用する手順を定義 |
| agents/shared/analysis-framework.md | 54 | 全次元共通の分析フレームワーク。2段階プロセス（Phase 1: 包括的問題検出、Phase 2: 整理と報告）と Detection Strategies の概念を定義 |
| agents/evaluator/criteria-effectiveness.md | 162 | 基準有効性分析次元。評価基準の明確性・S/N比・実行可能性・費用対効果を評価 |
| agents/evaluator/scope-alignment.md | 153 | スコープ整合性分析次元（evaluator向け）。明示的なスコープ定義・境界・内部整合性・基準-ドメインカバレッジを評価 |
| agents/evaluator/detection-coverage.md | 175 | 検出カバレッジ分析次元。検出戦略の完全性・severity分類整合性・出力形式・偽陽性リスクを評価 |
| agents/producer/workflow-completeness.md | 162 | ワークフロー完全性分析次元。ステップ順序・データフロー・エラーパス・条件分岐の網羅性を評価 |
| agents/producer/output-format.md | 168 | 出力形式実現性分析次元。出力形式の実現可能性・下流利用可能性・情報完全性・セクション間整合性を評価 |
| agents/shared/instruction-clarity.md | 178 | 指示明確性分析次元（全グループ共通）。ドキュメント構造・役割定義・コンテキスト充足・指示有効性を評価 |
| agents/unclassified/scope-alignment.md | 140 | スコープ整合性分析次元（unclassified/producer向け・軽量版）。目的明確性・フォーカス適切性・境界暗黙性を評価 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0（初期化・グループ分類）**: エージェント定義を読み込み、グループ（hybrid/evaluator/producer/unclassified）に分類。グループに基づき分析次元セットを決定し、出力ディレクトリを作成。前回実行履歴を確認
  - **Phase 1（並列分析）**: 決定した次元数（3-5個）のサブエージェントを並列起動し、各次元で静的分析を実行。findings ファイルに結果を保存
  - **Phase 2（承認+改善適用）**: findings を収集・一覧提示し、ユーザーに承認を確認（全承認/1件ずつ/キャンセル）。承認された findings をバックアップ作成後、サブエージェントに委譲して適用。検証ステップで構造チェックを実行
  - **Phase 3（完了サマリ）**: 分析結果・承認数・適用結果・バックアップパスを出力。次のステップを提案（critical適用時は再audit推奨、improvement適用時はbench推奨）
- データフロー:
  - Phase 0: `{agent_path}` 読み込み → グループ分類結果 → 次元セット決定 → `.agent_audit/{agent_name}/` 作成 → `audit-approved.md` 読み込み（前回履歴）
  - Phase 1: 各次元サブエージェント → `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` （findings 保存）
  - Phase 2: findings 読み込み → 承認結果 → `audit-approved.md` 書き込み → バックアップ作成 → 改善適用サブエージェント → `{agent_path}` 変更 → 検証読み込み
  - Phase 3: Phase 1/2 の結果を集約してサマリ出力

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 71 | `.claude/skills/agent_audit_new/group-classification.md` | Phase 0 でのグループ分類サブエージェント用テンプレート |
| SKILL.md | 95-100 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 1 での次元別分析サブエージェント用テンプレート（相対パス形式） |
| SKILL.md | 123 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 1 Task prompt 内での次元エージェント読み込み指示 |
| agents/evaluator/criteria-effectiveness.md | 6 | `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` | 共通分析フレームワークへの参照 |
| agents/evaluator/scope-alignment.md | 6 | `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` | 共通分析フレームワークへの参照 |
| agents/evaluator/detection-coverage.md | 6 | `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` | 共通分析フレームワークへの参照 |
| agents/producer/workflow-completeness.md | 6 | `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` | 共通分析フレームワークへの参照 |
| agents/producer/output-format.md | 6 | `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` | 共通分析フレームワークへの参照 |
| agents/shared/instruction-clarity.md | 6 | `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` | 共通分析フレームワークへの参照 |
| agents/unclassified/scope-alignment.md | 6 | `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` | 共通分析フレームワークへの参照 |

（備考：すべての外部参照はスキルディレクトリ `.claude/skills/agent_audit_new/` 内のファイルへの相対参照）

## D. コンテキスト予算分析
- SKILL.md 行数: 322行
- テンプレートファイル数: 8個（1個の共通フレームワーク + 7個の次元エージェント）、平均行数: 149行
- サブエージェント委譲: あり（3種類のサブエージェント使用）
  - Phase 0: グループ分類サブエージェント（haiku、1個）
  - Phase 1: 次元別分析サブエージェント（sonnet、3-5個並列）
  - Phase 2: 改善適用サブエージェント（sonnet、1個）
- 親コンテキストに保持される情報:
  - エージェント名・パス・グループ
  - 分析次元リストと次元数
  - 各次元の findings サマリ（critical/improvement/info 件数のみ、詳細はファイル）
  - 承認/スキップの判定結果（finding ID とユーザー判定）
  - 改善適用結果サマリ（modified/skipped 件数、詳細はファイル）
  - バックアップパス
- 3ホップパターンの有無: **なし**（全てファイル経由でデータを受け渡し。親は各サブエージェントのサマリ返答のみ受け取る）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全承認/1件ずつ/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認（Approve/Skip/Approve all/Cancel/Other） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | "Other" 入力が不明確な場合の再確認（最大1回） | 不明 |
| Phase 2 Step 4 | AskUserQuestion | 改善適用前の最終確認（Proceed/Cancel） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: `{agent_path}` 読み込み失敗 → エラー出力して終了
  - Phase 0: `{previous_approved_path}` 不在 → `previous_approved_count = 0` として処理継続
  - Phase 1: findings ファイル不在または空 → 該当次元を「分析失敗」として記録、他次元は継続
- サブエージェント失敗時:
  - Phase 0: グループ分類失敗時の処理は未定義（抽出失敗の可能性）
  - Phase 1: 各次元ごとに成否判定。全次元失敗時はエラー出力して終了。一部成功時は成功分のみ継続
  - Phase 2: 改善適用サブエージェント失敗時の処理は未定義（検証ステップで間接的に検出）
- 部分完了時:
  - Phase 1: 一部次元が成功した場合、成功分のみで Phase 2 に進む
  - Phase 2: バックアップ作成失敗 → 改善適用を中止して Phase 3 へ
  - Phase 2: `modified: 0件` の場合 → 警告表示してバックアップ保持のまま Phase 3 へ
  - Phase 2: 検証失敗 → エラー出力してスキル終了（ロールバック手順を表示）
- 入力バリデーション:
  - Phase 0: frontmatter チェック（`description:` フィールドの有無）。不在時は警告表示して処理継続
  - Phase 2: 検証ステップでエージェント定義の構造を確認（frontmatter、必須セクション）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 | haiku | group-classification.md | 1行（`group: {agent_group}`） | 1 |
| Phase 1 | sonnet | agents/{dim_path}.md | 4行（`dim:`, `critical:`, `improvement:`, `info:`） | 3-5（グループに応じて変動） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 可変（modified/skipped リスト、最大30件） | 1 |
