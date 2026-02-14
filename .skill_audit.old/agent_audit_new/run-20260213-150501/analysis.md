# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 346 | スキル実行のメインワークフロー定義（Phase 0-3: 初期化・グループ分類・並列分析・承認・改善適用・検証・完了サマリ） |
| group-classification.md | 24 | グループ分類基準（evaluator/producer 特徴4項目の判定ルール、hybrid/evaluator/producer/unclassified への分類ロジック） |
| templates/apply-improvements.md | 40 | 承認済み findings をエージェント定義に適用するテンプレート（適用順序決定、Edit/Write ルール、返答フォーマット） |
| templates/analyze-dimensions.md | 19 | 次元分析テンプレート（各次元エージェントへの委譲プロンプト、パス変数展開、4行固定返答フォーマット） |
| agents/shared/analysis-framework.md | 61 | 全次元共通の2段階分析プロセス定義（Phase 1: 包括的検出、Phase 2: 整理・報告、Detection Strategies 概念、敵対的思考） |
| agents/evaluator/criteria-effectiveness.md | 168 | CE次元（基準有効性）: 曖昧さ・S/N比・実行可能性・費用対効果を5戦略で検出（Inventory, Adversarial Testing, Feasibility, Consistency, Antipattern） |
| agents/evaluator/scope-alignment.md | 159 | SA次元（スコープ整合性・evaluator用）: 境界曖昧さ・カバレッジギャップを5戦略で検出（Inventory, Boundary, Consistency, Adversarial, Coverage） |
| agents/evaluator/detection-coverage.md | 180 | DC次元（検出カバレッジ）: 検出戦略完全性・severity分類・出力形式・偽陽性リスクを5戦略で検出（Completeness, Severity, Output, FP Risk, Antipattern） |
| agents/producer/workflow-completeness.md | 168 | WC次元（ワークフロー完全性）: ステップ順序・依存・データフロー・エラーパス・条件分岐を5戦略で検出（Topology, Data Flow, Error Path, Conditional, Antipattern） |
| agents/producer/output-format.md | 174 | OF次元（出力形式実現性）: 実現可能性・下流互換性・情報完全性・整合性を5戦略で検出（Achievability, Compatibility, Completeness, Consistency, Antipattern） |
| agents/shared/instruction-clarity.md | 184 | IC次元（指示明確性）: ドキュメント構造・役割定義・コンテキスト完全性・有効性を5戦略で検出（Structure, Role, Context, Effectiveness, Antipattern） |
| agents/unclassified/scope-alignment.md | 146 | SA次元（スコープ整合性・軽量版）: 目的明確性・フォーカス適切性・境界暗黙性を4戦略で検出（Purpose, Focus, Boundary, Antipattern） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0（初期化・グループ分類）**: 引数検証、agent_path 読込、グループ分類サブエージェント起動（haiku）、分類結果抽出、agent_name 導出、出力ディレクトリ作成（タイムスタンプ付き run-YYYYMMDD-HHMMSS）、前回実行履歴確認（シンボリックリンク読込）、次元セット決定（グループベース）
  - **Phase 1（並列分析）**: 次元数（3-5個）のサブエージェント（sonnet）を並列起動、各次元がエージェント定義を分析し findings ファイルに保存、サブエージェント返答から件数抽出、エラーハンドリング（findings ファイル存在・サイズ確認）
  - **Phase 2（ユーザー承認 + 改善適用）**: findings 収集（critical/improvement のみ対象）、一覧提示、承認方針選択（全て承認/1件ずつ確認/キャンセル）、per-item 承認ループ（オプション）、承認結果保存（audit-approved.md + シンボリックリンク）、バックアップ作成、最終確認、改善適用サブエージェント起動（sonnet）、検証ステップ（YAML frontmatter・グループ別必須セクション・audit-approved.md 構造検証）
  - **Phase 3（完了サマリ）**: 検出件数・承認結果・変更詳細・バックアップパス・前回比較（解決済み指摘・新規指摘の導出）・次のステップ提示（critical 承認時は再実行推奨、improvement のみは agent_bench 推奨）
- データフロー:
  - Phase 0 → Phase 1: agent_path, agent_name, previous_approved_path, run_dir
  - Phase 1 → Phase 2: findings ファイル（.agent_audit/{agent_name}/run-YYYYMMDD-HHMMSS/audit-{ID_PREFIX}.md）、dim_summaries（件数情報）
  - Phase 2 → Phase 3: approved_findings_path, backup_path, 承認数・スキップ数・変更詳細

## C. 外部参照の検出
なし（すべての参照は {skill_path} 配下または .agent_audit/ 配下の作業ディレクトリ内）

## D. コンテキスト予算分析
- SKILL.md 行数: 346行
- テンプレートファイル数: 2個、平均行数: 29.5行
- サブエージェント委譲: あり（Phase 0: 1回 haiku、Phase 1: 3-5回並列 sonnet、Phase 2: 1回 sonnet）
- 親コンテキストに保持される情報:
  - グループ分類結果（agent_group: hybrid/evaluator/producer/unclassified）
  - 次元サマリ（各次元の critical/improvement/info 件数、成功/失敗状態）
  - 承認方針（全て承認/1件ずつ確認/キャンセル）
  - per-item 承認結果（承認/スキップ/残りすべて承認/キャンセル、ユーザー修正内容）
  - 改善適用結果（modified 件数・skipped 件数のサマリ、詳細はファイル保存）
  - 検証結果（成功/失敗、失敗理由）
- 3ホップパターンの有無: なし（サブエージェントは直接ファイル読込・保存を行い、親は保存先パスのみ受け渡す。親は findings 内容を中継せず、ファイルパスのみ伝達）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認（Approve/Skip/Approve all remaining/Cancel/Other） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | 修正内容が不明確な場合の再確認（最大1回） | 不明 |
| Phase 2 Step 4 | AskUserQuestion | 改善適用前の最終確認（Proceed/Cancel） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読込失敗: エラー出力して終了（Phase 0）
  - frontmatter 不在: 警告表示して処理継続（Phase 0）
  - previous_approved_path 不在: {previous_approved_count} = 0 として処理継続（Phase 0）
  - findings ファイル不在またはサイズ <10バイト: 該当次元を「分析失敗」として記録、他次元が1つでも成功すれば Phase 2 へ進む（Phase 1）
- サブエージェント失敗時:
  - グループ分類サブエージェント失敗: 抽出失敗時は unclassified をデフォルト値として使用、警告表示（Phase 0）
  - 次元分析サブエージェント失敗: findings ファイル存在・サイズで成否判定、失敗次元は「分析失敗」として記録、全次元失敗時はエラー出力して終了（Phase 1）
  - 改善適用サブエージェント失敗: 検証ステップで検出（modified:0件の場合は警告表示してバックアップ保持、検証失敗時はエラー出力・ロールバック手順提示して終了）（Phase 2）
- 部分完了時:
  - 一部次元が成功した場合: 成功した次元の findings のみを Phase 2 で処理（Phase 1）
  - 改善適用が部分成功した場合: modified リストと skipped リストを Phase 3 で表示（Phase 2）
- 入力バリデーション:
  - agent_path 未指定時: AskUserQuestion で確認（Phase 0）
  - frontmatter 不在時: 警告表示（エージェント定義ではない可能性）して処理継続（Phase 0）
  - 必須フィールド欠落 finding: 警告表示してスキップ（Phase 2 Step 1）
  - 修正内容が不明確な場合: 再度 AskUserQuestion で確認（最大1回、2回目も不明確ならスキップ）（Phase 2 Step 2a）
  - バックアップ作成失敗時: エラー出力して改善適用を中止、Phase 3 へ直行（Phase 2 Step 4）
  - 検証失敗時: エラー出力・ロールバック手順提示してスキル終了（Phase 2 検証ステップ）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 | haiku | group-classification.md | 1（`group: {agent_group}`） | 1 |
| Phase 1 | sonnet | templates/analyze-dimensions.md → 各次元エージェント（agents/{dim_path}.md） | 4（`dim:`, `critical:`, `improvement:`, `info:`） | 3-5（グループ依存: unclassified=3, evaluator/producer=4, hybrid=5） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 2-30（`modified: {N}件`, `skipped: {K}件` + 変更詳細リスト最大20件+スキップリスト最大10件） | 1 |
