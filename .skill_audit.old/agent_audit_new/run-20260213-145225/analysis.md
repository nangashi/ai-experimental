# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 345 | スキルのメインワークフロー定義（Phase 0-3）、パス変数、グループ分類とマッピング |
| group-classification.md | 24 | エージェントグループ分類基準（evaluator/producer/hybrid/unclassified） |
| templates/apply-improvements.md | 40 | Phase 2 Step 4: 承認済み findings に基づく改善適用ロジック |
| agents/shared/analysis-framework.md | 62 | 全次元共通の分析プロセス（2段階分析、severity分類、Detection Strategies） |
| agents/evaluator/criteria-effectiveness.md | 168 | CE次元: 評価基準の有効性分析（曖昧さ、S/N比、実行可能性、費用対効果） |
| agents/evaluator/scope-alignment.md | 159 | SA次元（evaluator版）: スコープ定義品質、境界明確性、内部整合性、基準-ドメインカバレッジ |
| agents/evaluator/detection-coverage.md | 181 | DC次元: 検出戦略完全性、severity分類整合性、出力形式有効性、偽陽性リスク |
| agents/producer/workflow-completeness.md | 167 | WC次元: ワークフロー完全性（ステップ順序、データフロー、エラーパス、エッジケース） |
| agents/producer/output-format.md | 174 | OF次元: 出力形式実現性（形式実現可能性、下流利用可能性、情報完全性、セクション間整合性） |
| agents/shared/instruction-clarity.md | 184 | IC次元（全グループ共通）: ドキュメント構造、役割定義、コンテキスト完全性、指示有効性 |
| agents/unclassified/scope-alignment.md | 146 | SA次元（軽量版）: 目的明確性、フォーカス適切性、境界暗黙性 |

## B. ワークフロー概要

- **フェーズ構成**: Phase 0 → Phase 1 → Phase 2 → Phase 3
- **各フェーズの目的**:
  - **Phase 0（初期化・グループ分類）**: エージェント定義読み込み、frontmatter検証、グループ分類（haiku Task）、agent_name導出、出力ディレクトリ作成、前回履歴確認、分析次元セット決定
  - **Phase 1（並列分析）**: 共通フレームワーク要約準備 → 分析次元数（3-5次元）の並列 Task 起動（sonnet）→ 各次元が findings ファイルに保存 → 成否判定とサマリ収集
  - **Phase 2（ユーザー承認 + 改善適用）**: findings 収集 → 一覧提示 → 承認方針選択（AskUserQuestion）→ per-item承認ループ（1件ずつ確認選択時）→ 承認結果保存 → バックアップ作成 → 最終確認（AskUserQuestion）→ 改善適用（sonnet Task）→ 検証ステップ
  - **Phase 3（完了サマリ）**: 検出・承認・変更詳細・前回比較・次のステップを統合して表示

- **データフロー**:
  - **Phase 0**: `{agent_path}` 読み込み → group-classification.md 使用 → `{agent_group}` 抽出 → `{run_dir}` 作成 → `{previous_approved_path}` 確認
  - **Phase 1**: analysis-framework.md 読み込み → 各次元エージェント（{dim_path}.md）に共通フレームワーク要約を渡す → 各次元が `{run_dir}/audit-{ID_PREFIX}.md` に保存
  - **Phase 2**: `{run_dir}/audit-{ID_PREFIX}.md` を Read → findings 抽出 → 承認結果を `{agent_name}/audit-approved.md` に保存 → apply-improvements.md 使用（Task）→ `{agent_path}` を Edit/Write で変更 → 検証
  - **Phase 3**: Phase 1・2 のメタデータを使用してサマリ生成

## C. 外部参照の検出

| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 84 | `.claude/skills/agent_audit_new/group-classification.md` | Phase 0: グループ分類サブエージェントに指示ファイルとして渡す |
| SKILL.md | 141 | `.claude/skills/agent_audit_new/agents/shared/analysis-framework.md` | Phase 1: 共通フレームワーク要約を抽出して各次元エージェントに渡す |
| SKILL.md | 152 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | Phase 1: 各次元エージェントファイル（評価次元に応じた相対パス） |
| SKILL.md | 274 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | Phase 2 Step 4: 改善適用サブエージェントに指示ファイルとして渡す |

すべて `{skill_path}` 内のパスであり、スキルディレクトリ外への参照は **なし**。

## D. コンテキスト予算分析

- **SKILL.md 行数**: 345行
- **テンプレートファイル数**: 1個（apply-improvements.md: 40行）、平均行数: 40行
- **サブエージェント委譲**: あり
  - **Phase 0**: グループ分類（haiku、1 Task）
  - **Phase 1**: 次元分析（sonnet、3-5 Task 並列）
  - **Phase 2 Step 4**: 改善適用（sonnet、1 Task）
  - 合計: 最大7 Task（グループ分類1 + 次元分析5 + 改善適用1）
- **親コンテキストに保持される情報**:
  - グループ分類結果（`{agent_group}`）
  - 各次元のサマリ（`critical: N, improvement: M, info: K`）
  - 承認結果メタデータ（承認数、スキップ数、finding ID リスト）
  - 前回実行履歴（`{previous_approved_count}`）
  - 改善適用結果サマリ（modified/skipped の件数と概要、最大30件）
- **3ホップパターンの有無**: なし
  - Phase 1 の各次元エージェントは findings を直接ファイルに保存し、Phase 2 は親が Read して処理する（ファイル経由、2ホップ）
  - Phase 2 の改善適用エージェントは承認済み findings ファイルを直接 Read する（ファイル経由、2ホップ）

## E. ユーザーインタラクションポイント

| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | `agent_path` 引数未指定時にパス確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item承認（Approve/Skip/Approve all remaining/Cancel/Other） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | "Other"入力が不明確な場合の再確認（最大1回） | 不明 |
| Phase 2 Step 4 | AskUserQuestion | 改善適用前の最終確認（Proceed/Cancel） | 不明 |

注: SKILL.md には Fast mode に関する記述がないため、すべて「不明」。

## F. エラーハンドリングパターン

- **ファイル不在時**:
  - Phase 0 Step 2: `{agent_path}` 読み込み失敗時はエラー出力して終了
  - Phase 0 Step 6a: `{previous_approved_path}` 不在時は `{previous_approved_count} = 0` として処理継続
- **サブエージェント失敗時**:
  - Phase 1: 各サブエージェントの成否を findings ファイルの存在・非空で判定。失敗は「分析失敗（{エラー概要}）」として記録。全次元失敗時はエラー出力して終了
  - Phase 2 Step 4: バックアップ作成失敗時（`test -f {backup_path}` が偽）は Phase 3 へ直行
- **部分完了時**:
  - Phase 1: 成功した次元のみを Phase 2 で処理（失敗次元はサマリに記録）
  - Phase 2: 承認数が0の場合は Phase 3 へ直行
  - Phase 2 Step 4 検証: `modified: 0件` の場合は警告表示してバックアップ保持のまま Phase 3 へ進む
- **入力バリデーション**:
  - Phase 0 Step 3: frontmatter 簡易チェック（`---` と `description:` の存在確認）。不在時は警告表示して処理継続
  - Phase 0 グループ分類: 抽出失敗時は `unclassified` をデフォルト値として使用し警告表示
  - Phase 2 Step 1: finding の必須フィールド欠落時はスキップし警告表示
  - Phase 2 Step 4 検証: YAML frontmatter、グループ別必須セクション、変更件数を確認。検証失敗時はロールバック手順を表示してスキル終了

## G. サブエージェント一覧

| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 | haiku | group-classification.md | 1行（`group: {agent_group}`） | 1 |
| Phase 1 | sonnet | agents/{dim_path}.md（3-5種類） | 4行（`dim: {name}, critical: {N}, improvement: {M}, info: {K}`） | 3-5（グループに依存: hybrid=5, evaluator=4, producer=4, unclassified=3） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 最大30行（modified リスト最大20件 + skipped リスト最大10件 + ヘッダー） | 1 |
