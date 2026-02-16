# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 369 | メインワークフロー定義（Phase 0-3）、グループ分類、次元マッピング、成功基準 |
| group-classification.md | 21 | グループ分類基準（evaluator/producer/hybrid/unclassified の判定ルール） |
| agents/shared/detection-process-common.md | 29 | 共通分析プロセス（Detection-First, Reporting-Second の2フェーズアプローチ） |
| agents/evaluator/criteria-effectiveness.md | 168 | CE次元（基準有効性）分析エージェント |
| agents/evaluator/detection-coverage.md | 184 | DC次元（検出カバレッジ）分析エージェント |
| agents/evaluator/scope-alignment.md | 152 | SA次元（スコープ整合性・evaluator版）分析エージェント |
| agents/producer/workflow-completeness.md | 174 | WC次元（ワークフロー完全性）分析エージェント |
| agents/producer/output-format.md | 179 | OF次元（出力形式実現性）分析エージェント |
| agents/shared/instruction-clarity.md | 155 | IC次元（指示明確性）分析エージェント（全グループ共通） |
| agents/unclassified/scope-alignment.md | 134 | SA次元（スコープ整合性・軽量版）分析エージェント |
| templates/apply-improvements.md | 42 | Phase 2 Step 4: 承認済み findings をエージェント定義に適用するサブエージェント |
| templates/classify-agent-group.md | 28 | Phase 0: エージェントグループ分類サブエージェント |
| templates/collect-findings.md | 41 | Phase 2 Step 1: 各次元の findings を収集・統合するサブエージェント |
| templates/validate-agent-structure.md | 65 | Phase 2 検証ステップ: 改善適用後の構造検証+ロールバックサブエージェント |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0 (初期化・グループ分類)**: エージェント読み込み → グループ分類サブエージェント委譲 → ユーザー確認 → 次元セット決定 → 出力ディレクトリ作成
  - **Phase 1 (並列分析)**: グループに応じた次元セット（3-5次元）を並列 Task 起動で分析 → 各次元が findings ファイル生成 → 部分失敗時の継続判定
  - **Phase 2 (ユーザー承認 + 改善適用)**: findings 収集サブエージェント → 一覧提示 → ユーザー承認（Fast mode で自動承認可） → バックアップ作成 → 改善適用サブエージェント → 構造検証サブエージェント
  - **Phase 3 (完了サマリ)**: 最終結果サマリ出力、次のステップ提示
- データフロー:
  - Phase 0: エージェント定義 → グループ分類結果 → `.agent_audit/{agent_name}/` ディレクトリ作成
  - Phase 1: 各次元サブエージェント → `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` 生成
  - Phase 2 Step 1: 各 findings ファイル → `.agent_audit/{agent_name}/findings-summary.md`
  - Phase 2 Step 3: 承認結果 → `.agent_audit/{agent_name}/audit-approved.md`
  - Phase 2 Step 4: 承認済み findings + エージェント定義 → 改善適用 → バックアップ作成
  - Phase 2 検証: 改善後エージェント定義 → 構造検証 → 失敗時ロールバック

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 48-49 | `.skill_audit/{skill_name}/run-{timestamp}/analysis.md` | skill_audit スキルが生成した構造分析結果（オプショナル依存） |
| SKILL.md | 328 | `.skill_audit/{skill_name}/run-{timestamp}/analysis.md` | Phase 2 検証ステップで外部参照整合性チェックに使用 |
| SKILL.md | 6 | `agent_bench` | 説明文での言及（構造最適化との分離を説明） |
| SKILL.md | 369 | `agent_bench` | Phase 3 の次ステップ推奨での言及 |

## D. コンテキスト予算分析
- SKILL.md 行数: 369行
- テンプレートファイル数: 4個、平均行数: 44行
- 分析エージェント数: 7個（次元別）、平均行数: 158行
- サブエージェント委譲: あり（Phase 0, 1, 2 で計4種類のテンプレート + Phase 1 で最大5次元並列分析）
- 親コンテキストに保持される情報:
  - agent_path, agent_name, agent_group（グループ分類結果）
  - 次元セット（dimensions リスト、ID_PREFIX マッピング）
  - Phase 1 の各次元サマリ（critical/improvement/info 件数、または失敗理由）
  - Phase 2 の承認統計（total/critical/improvement 件数、承認/スキップ件数）
  - バックアップパス、検証結果
- 3ホップパターンの有無: なし（全てファイル経由のデータ受け渡し）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 Step 1 | AskUserQuestion | agent_path 未指定時の確認 | 同様（必須パラメータ） |
| Phase 0 Step 5 | AskUserQuestion | グループ分類結果の確認・手動変更 | 同様（分類の妥当性確認） |
| Phase 1 部分失敗時 | AskUserQuestion | 部分失敗時の継続/中止確認 | スキップ（自動継続） |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全承認/1件ずつ/キャンセル） | スキップ（全自動承認） |
| Phase 2 Step 2a | AskUserQuestion | Per-item 承認ループ | スキップ（全自動承認） |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0 Step 2: agent_path 読み込み失敗 → エラー出力して終了
  - Phase 2 Step 1: findings-summary.md 不在/空 → エラー出力して Phase 3 へ直行
- サブエージェント失敗時:
  - Phase 1: 各次元の findings ファイル存在・非空チェックで成否判定 → 全失敗時は終了、部分失敗時は成功基準に基づき継続/中止判定（IC 成功 or 成功数≧2 なら継続可）
  - Phase 2 Step 4: 改善適用失敗 → エラー出力 + バックアップからの復旧手順提示 + Phase 3 へ進む
  - Phase 2 検証: 検証失敗 → エラー出力 + Phase 3 へ進む
- 部分完了時:
  - Phase 1 部分失敗: 成功基準（IC 成功 or 成功数≧2）で継続判定 → 失敗次元をスキップして Phase 2 へ進む
  - Phase 2 承認数0: 改善適用なしとして Phase 3 へ直行
- 入力バリデーション:
  - Phase 0 Step 3: YAML frontmatter 不在時は警告のみ（処理継続）
  - Phase 2 Step 4: バックアップ作成失敗 → エラー出力 + Phase 3 へ直行（改善適用中止）
  - Phase 2 検証ステップ: 構造検証失敗時に自動ロールバック実行

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 Step 4 | haiku | templates/classify-agent-group.md | 2 | 1 |
| Phase 1 | sonnet | agents/{dim_path}.md（次元別） | 4 | 3-5（グループ依存） |
| Phase 2 Step 1 | sonnet | templates/collect-findings.md | 3 | 1 |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 上限30行（modified/skipped リスト） | 1 |
| Phase 2 検証 | haiku | templates/validate-agent-structure.md | 4 | 1 |
