# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | スキルのメインワークフロー定義。Phase 0-3で構成され、グループ分類→並列分析→ユーザー承認→改善適用を実行 |
| group-classification.md | 22 | エージェントグループ分類基準。evaluator/producer特徴を4項目ずつ定義し、hybrid→evaluator→producer→unclassifiedの判定ルールを提供 |
| agents/shared/instruction-clarity.md | 206 | IC次元分析エージェント定義。ドキュメント構造・役割定義・指示の明確性を評価 |
| agents/evaluator/criteria-effectiveness.md | 185 | CE次元分析エージェント定義。評価基準の明確性・S/N比・実行可能性・費用対効果を評価 |
| agents/evaluator/scope-alignment.md | 169 | SA次元分析エージェント定義（evaluator用）。スコープ定義品質・境界明確性・基準-ドメインカバレッジを評価 |
| agents/evaluator/detection-coverage.md | 201 | DC次元分析エージェント定義。検出戦略完全性・severity分類整合性・出力形式有効性・偽陽性リスクを評価 |
| agents/producer/workflow-completeness.md | 191 | WC次元分析エージェント定義。ワークフローステップの完全性・依存関係・エラーハンドリング・エッジケース対応を評価 |
| agents/producer/output-format.md | 196 | OF次元分析エージェント定義。出力形式の実現可能性・下流利用可能性・情報完全性・セクション間整合性を評価 |
| agents/unclassified/scope-alignment.md | 150 | SA次元分析エージェント定義（unclassified用・軽量版）。目的明確性・フォーカス適切性・境界暗黙性を評価 |
| templates/apply-improvements.md | 38 | Phase 2 Step 4サブエージェント。承認済みfindingsに基づいてエージェント定義を改善適用 |
| agent_bench/SKILL.md | 372 | agent_benchスキル定義（エージェント構造最適化スキル） |
| agent_bench/approach-catalog.md | 202 | 改善アプローチカタログ。S/C/N/Mカテゴリの改善テクニックを定義 |
| agent_bench/scoring-rubric.md | 70 | 採点基準定義。検出判定基準・スコア計算式・推奨判定基準・収束判定を含む |
| agent_bench/test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定・文書構成・問題埋め込みガイドラインを提供 |
| agent_bench/proven-techniques.md | 70 | エージェント横断の実証済みテクニック。効果テクニック・アンチパターン・条件付きテクニック・ベースライン構築ガイドを集約 |
| agent_bench/templates/knowledge-init-template.md | 53 | Phase 0ナレッジ初期化サブエージェント |
| agent_bench/templates/phase1a-variant-generation.md | 41 | Phase 1A（初回）バリアント生成サブエージェント |
| agent_bench/templates/phase1b-variant-generation.md | 33 | Phase 1B（継続）バリアント生成サブエージェント |
| agent_bench/templates/phase2-test-document.md | 20 | Phase 2テスト文書生成サブエージェント |
| agent_bench/templates/phase4-scoring.md | 13 | Phase 4採点サブエージェント |
| agent_bench/templates/phase5-analysis-report.md | 20 | Phase 5分析・推奨判定サブエージェント |
| agent_bench/templates/phase6a-knowledge-update.md | 23 | Phase 6Aナレッジ更新サブエージェント |
| agent_bench/templates/phase6b-proven-techniques-update.md | 51 | Phase 6Bスキル知見フィードバックサブエージェント |
| agent_bench/templates/perspective/generate-perspective.md | 67 | パースペクティブ初期生成サブエージェント |
| agent_bench/templates/perspective/critic-completeness.md | 107 | パースペクティブ批評エージェント（網羅性） |
| agent_bench/templates/perspective/critic-clarity.md | 74 | パースペクティブ批評エージェント（明確性） |
| agent_bench/templates/perspective/critic-effectiveness.md | 75 | パースペクティブ批評エージェント（有効性） |
| agent_bench/templates/perspective/critic-generality.md | 82 | パースペクティブ批評エージェント（汎用性） |
| agent_bench/perspectives/design/*.md | - | 設計レビュー用パースペクティブ定義（5観点） |
| agent_bench/perspectives/code/*.md | - | コードレビュー用パースペクティブ定義（5観点） |

## B. ワークフロー概要

### フェーズ構成
Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）

### 各フェーズの目的

- **Phase 0**: エージェント定義読み込み、YAML frontmatter検証、agent_name導出、グループ分類（hybrid/evaluator/producer/unclassified）、出力ディレクトリ作成、分析次元セット決定
- **Phase 1**: グループに応じた次元セット（IC + グループ固有次元）で並列分析実行。各次元について findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を生成
- **Phase 2**: critical/improvement findings の収集→一覧提示→承認方針選択（全承認/1件確認/キャンセル）→承認結果保存（`.agent_audit/{agent_name}/audit-approved.md`）→改善適用サブエージェント委譲→検証ステップ
- **Phase 3**: 検出件数・承認結果・変更詳細・バックアップパス・次ステップ提案を含む完了サマリ出力

### データフロー

| フェーズ | 入力 | 生成ファイル | 参照先フェーズ |
|---------|------|------------|-------------|
| Phase 0 | `{agent_path}` | `.agent_audit/{agent_name}/` ディレクトリ | Phase 1, 2 |
| Phase 1 | `{agent_path}`, `group-classification.md`, `agents/{dim_path}.md` | `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` (各次元) | Phase 2 |
| Phase 2 | Phase 1の findings ファイル, `{agent_path}` | `.agent_audit/{agent_name}/audit-approved.md`, `{agent_path}.backup-*` | Phase 3 |
| Phase 3 | Phase 1/2の結果メタデータ | テキスト出力のみ（ファイル生成なし） | - |

### データ依存パターン

- **Phase 1 並列性**: 各次元の分析タスクは独立実行可能（同一メッセージ内で全次元を並列起動）
- **Phase 2 逐次性**: Step 1（収集）→ Step 2（提示・承認）→ Step 3（保存）→ Step 4（改善適用）→ 検証は順次実行
- **agent_bench連携**: Phase 1の findings ファイル（`audit-*.md`）は agent_bench の Phase 1B でバリアント生成時に参照される（外部スキル間データフロー）

## C. 外部参照の検出

| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit/group-classification.md` | グループ分類基準の詳細参照 |
| SKILL.md | 221 | `.claude/skills/agent_audit/templates/apply-improvements.md` | Phase 2 改善適用サブエージェント定義 |
| agents/evaluator/criteria-effectiveness.md | 12 | （スコープ境界説明でIC/SA次元に言及） | 他次元との責務分担を明示（参照先パスなし） |
| agents/producer/workflow-completeness.md | 14 | （スコープ境界説明でIC/OF次元に言及） | 他次元との責務分担を明示（参照先パスなし） |

（注: agent_bench配下のファイルは外部スキルとして独立しているため、本スキルの外部参照には含めない）

## D. コンテキスト予算分析

- **SKILL.md 行数**: 279行
- **テンプレートファイル数**: 1個（apply-improvements.md）、行数: 38行
- **サブエージェント委譲**: あり
  - Phase 1: N個の並列タスク（N = dim_count、hybrid=5, evaluator=4, producer=4, unclassified=3）
  - Phase 2 Step 4: 1個の改善適用タスク
  - 委譲パターン: テンプレートファイル（.md）をパス変数で指定し、サブエージェントに Read + 処理実行を委譲
- **親コンテキストに保持される情報**:
  - agent_path, agent_name, agent_group, dim_count（Phase 0で決定）
  - 各次元の返答サマリ（`dim: {name}, critical: {N}, improvement: {M}, info: {K}`）
  - 承認方針、承認数、スキップ数、バックアップパス（Phase 2で決定）
  - 詳細データ（findings内容、改善計画、変更詳細）は全てファイル経由で委譲
- **3ホップパターンの有無**: なし
  - Phase 1サブエージェント → ファイル（audit-*.md）← Phase 2サブエージェント（親を中継しない）
  - Phase 2承認済みファイル（audit-approved.md）→ Phase 2改善適用サブエージェント（親は指示とパスのみ提供）

## E. ユーザーインタラクションポイント

| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全承認/1件確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | Per-item承認ループ（承認/スキップ/残り承認/キャンセル、修正内容入力可） | 不明 |
| Phase 3 後の評価実行失敗時 | AskUserQuestion | 再試行/除外/中断選択 | 不明 |

（注: SKILL.md にFast modeに関する記述なし）

## F. エラーハンドリングパターン

- **ファイル不在時**:
  - agent_path 読み込み失敗 → エラー出力して終了（Phase 0, line 57）
  - findings ファイル不在・空 → 該当次元を「分析失敗（{エラー概要}）」として扱う。全次元失敗時はエラー出力して終了（Phase 1, line 125-129）
- **サブエージェント失敗時**:
  - Phase 1: findings ファイルの存在・内容で成否判定。失敗タスクはエラー概要を抽出し続行。全失敗時はエラー出力して終了
  - Phase 2 改善適用: 明示的なエラーハンドリング記述なし（検証ステップで構造破損を検出）
- **部分完了時**:
  - Phase 1: 一部次元の分析失敗を許容し、成功した次元のみで Phase 2 に進む
  - Phase 2: 承認数が0の場合、Phase 3 へ直行（改善適用スキップ）
- **入力バリデーション**:
  - YAML frontmatter 簡易チェック（`---` 区切り + `description:` 含有）。存在しない場合は警告を出力するが処理は継続（Phase 0, line 58）
  - 改善適用後の検証: YAML frontmatter 再確認。失敗時はロールバック手順を表示（Phase 2 検証ステップ, line 230-235）

## G. サブエージェント一覧

| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | `agents/{dim_path}.md` | 1行（`dim: {name}, critical: {N}, improvement: {M}, info: {K}`） | N個（dim_count = 3-5、グループ依存） |
| Phase 2 Step 4 | sonnet | `templates/apply-improvements.md` | 複数行（`modified: {N}件 ... skipped: {K}件 ...`） | 1個 |

（注: agent_bench配下のサブエージェントは外部スキルとして独立しているため除外）
