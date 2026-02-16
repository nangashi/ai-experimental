# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 392 | スキル定義メイン（ワークフロー全体、グループ分類、次元マッピング、Phase 0-3 の処理手順） |
| group-classification.md | 22 | グループ分類基準詳細（evaluator/producer 特徴リスト、判定ルール） |
| templates/apply-improvements.md | 38 | Phase 2 Step 4 改善適用サブエージェント用テンプレート（承認済み findings をエージェント定義に適用する手順） |
| templates/collect-findings.md | 58 | Phase 2 Step 1 findings 収集サブエージェント用テンプレート（Phase 1 の findings ファイルから critical/improvement を抽出してサマリ化） |
| agents/shared/common-rules.md | 44 | 全次元エージェント共通ルール（Severity Rules, Impact/Effort 定義, 検出戦略パターン, Adversarial Thinking） |
| agents/evaluator/criteria-effectiveness.md | 188 | CE 次元（基準有効性分析）エージェント定義 |
| agents/evaluator/scope-alignment.md | 173 | SA 次元（スコープ整合性分析・evaluator向け）エージェント定義 |
| agents/evaluator/detection-coverage.md | 206 | DC 次元（検出カバレッジ分析）エージェント定義 |
| agents/producer/workflow-completeness.md | 196 | WC 次元（ワークフロー完全性分析）エージェント定義 |
| agents/producer/output-format.md | 201 | OF 次元（出力形式実現性分析）エージェント定義 |
| agents/shared/instruction-clarity.md | 211 | IC 次元（指示明確性分析）エージェント定義 |
| agents/unclassified/scope-alignment.md | 155 | SA 次元（スコープ整合性分析・軽量版・unclassified/producer向け）エージェント定義 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0 (初期化・グループ分類)**: エージェント定義読み込み、frontmatter チェック、グループ分類（hybrid/evaluator/producer/unclassified）、agent_name 導出、出力ディレクトリ作成、分析次元セット決定
  - **Phase 1 (並列分析)**: グループに応じた複数次元（3-5 次元）のサブエージェントを並列起動し、各次元で findings を生成して `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に保存
  - **Phase 2 (ユーザー承認 + 改善適用)**: Step 1 で findings 収集、Step 2 で一覧提示+承認方針選択（全て承認 / 1件ずつ確認 / キャンセル）、Step 2a で per-item 承認（オプション）、Step 3 で承認結果保存、Step 4 でサブエージェントによる改善適用、検証ステップでエージェント定義の構造チェック
  - **Phase 3 (完了サマリ)**: 検出・承認・適用結果のサマリ表示、次のステップ推奨（critical 適用時は再監査、improvement のみ適用時は agent_bench 推奨）

- データフロー:
  - Phase 0: エージェント定義読み込み → グループ判定 → 次元セット決定
  - Phase 1: 各次元エージェントが `{agent_path}` を Read → findings を `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に Write → 親は件数サマリのみ取得
  - Phase 2 Step 1: findings ファイル群から critical/improvement を抽出 → `.agent_audit/{agent_name}/findings-summary.md` に Write
  - Phase 2 Step 2-2a: findings-summary.md を Read → ユーザー承認 → 承認結果を `.agent_audit/{agent_name}/audit-approved.md` に Write
  - Phase 2 Step 4: audit-approved.md と agent_path を Read → Edit で改善適用 → バックアップは `{agent_path}.backup-YYYYMMDD-HHMMSS`
  - 検証ステップ: agent_path を再 Read → frontmatter チェック

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 96 | `.claude/skills/agent_audit_new/group-classification.md` | Phase 0 Step 4 グループ分類基準参照 |
| SKILL.md | 148-194 | `.claude/skills/agent_audit_new/agents/shared/common-rules.md` | Phase 1 サブエージェントプロンプトに共通ルール埋め込み |
| SKILL.md | 196 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 1 各次元エージェント定義参照 |
| SKILL.md | 231 | `.claude/skills/agent_audit_new/templates/collect-findings.md` | Phase 2 Step 1 サブエージェントテンプレート |
| SKILL.md | 309 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2 Step 4 サブエージェントテンプレート |

## D. コンテキスト予算分析
- SKILL.md 行数: 392 行
- テンプレートファイル数: 2 個（collect-findings.md: 58行, apply-improvements.md: 38行）、平均行数: 48 行
- サブエージェント委譲: あり
  - Phase 1: 3-5 次元のサブエージェントを並列起動（グループにより異なる: unclassified=3, evaluator/producer=4, hybrid=5）。各次元エージェント定義は 155-211 行。共通ルール（44行）を各サブエージェントプロンプトに埋め込む
  - Phase 2 Step 1: findings 収集サブエージェント（haiku, 58 行テンプレート）
  - Phase 2 Step 4: 改善適用サブエージェント（sonnet, 38 行テンプレート）
- 親コンテキストに保持される情報:
  - エージェントメタデータ（agent_path, agent_name, agent_group, dim_count, dimensions）
  - Phase 1 各次元の件数サマリ（critical/improvement/info 各 N 件）
  - Phase 2 承認方針、承認数/スキップ数、適用結果サマリ（成功件数、スキップ件数、エラー概要）
  - バックアップパス
- 3ホップパターンの有無: **なし**。親は Phase 1 サブエージェントが生成した findings ファイルパスを Phase 2 Step 1 サブエージェントに渡し、Step 1 が生成した findings-summary.md を親が Read。Phase 2 Step 4 も audit-approved.md ファイルパス経由で委譲。全てファイルベースの 2 ホップ構造

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 Step 1 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全て承認 / 1件ずつ確認 / キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認（承認 / スキップ / 残りすべて承認 / キャンセル） | 不明 |
| Phase 2 Step 4 エラーハンドリング | AskUserQuestion | 改善適用失敗時の方針確認（リトライ / ロールバック / 強制的に検証へ） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0 Step 2: `{agent_path}` 読み込み失敗時はエラー出力して終了
  - Phase 2 Step 1: findings ファイルが1つも見つからない場合は `total: 0` を返答、findings-summary.md は作成しない（処理継続）
- サブエージェント失敗時:
  - Phase 1: 各次元の findings ファイル存在チェックで成否判定。全次元失敗時はエラー出力して終了。部分失敗時は成功次元のみで Phase 2 へ進む
  - Phase 2 Step 4: 改善適用サブエージェントの返答から失敗キーワード検出 → AskUserQuestion で方針確認（リトライ 1 回 / ロールバック / 強制的に検証ステップへ）
- 部分完了時:
  - Phase 1 部分成功: 成功次元のみで Phase 2 へ進む
  - Phase 2 Step 4 改善適用部分失敗: 検証ステップで frontmatter チェック失敗時は警告のみ表示して Phase 3 へ進む（ロールバックコマンド提示）
- 入力バリデーション:
  - Phase 0 Step 3: frontmatter（`---` + `description:` 存在）チェック。不在時は警告フラグ設定+警告テキスト出力（処理は継続）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/shared/instruction-clarity.md (211行) + common-rules.md (44行) | 4行（`dim: IC, critical: N, improvement: M, info: K`） | グループにより 3-5 並列 |
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md (188行) + common-rules.md (44行) | 4行（`dim: CE, critical: N, improvement: M, info: K`） | hybrid/evaluator のみ |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md (173行) + common-rules.md (44行) | 4行（`dim: SA, critical: N, improvement: M, info: K`） | hybrid/evaluator のみ |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md (206行) + common-rules.md (44行) | 4行（`dim: DC, critical: N, improvement: M, info: K`） | evaluator のみ |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md (196行) + common-rules.md (44行) | 4行（`dim: WC, critical: N, improvement: M, info: K`） | hybrid/producer/unclassified |
| Phase 1 | sonnet | agents/producer/output-format.md (201行) + common-rules.md (44行) | 4行（`dim: OF, critical: N, improvement: M, info: K`） | hybrid/producer のみ |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md (155行) + common-rules.md (44行) | 4行（`dim: SA, critical: N, improvement: M, info: K`） | producer/unclassified のみ |
| Phase 2 Step 1 | haiku | templates/collect-findings.md (58行) | 3行（`total: N, critical: M, improvement: K`） | 1 |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md (38行) | 可変（`modified: N件` + `skipped: K件` のリスト） | 1 |
