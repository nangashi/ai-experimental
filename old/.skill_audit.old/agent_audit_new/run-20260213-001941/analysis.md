# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 260 | スキルのメインワークフロー定義（Phase 0-3: 初期化・グループ分類・並列分析・承認・改善適用・完了サマリ） |
| group-classification.md | 22 | エージェントグループ分類基準（hybrid/evaluator/producer/unclassified の判定ルール） |
| agents/shared/detection-process-common.md | 30 | Detection-First, Reporting-Second の2段階分析プロセス共通説明 |
| agents/evaluator/criteria-effectiveness.md | 169 | CE 次元: 評価基準の有効性分析（曖昧さ、S/N比、実行可能性、費用対効果、カバレッジギャップ検出） |
| agents/evaluator/detection-coverage.md | 185 | DC 次元: 検出カバレッジ分析（検出戦略完全性、severity分類整合性、出力形式有効性、偽陽性リスク） |
| agents/evaluator/scope-alignment.md | 153 | SA 次元（evaluator用）: スコープ整合性分析（境界明確性、スコープ外文書化、内部整合性、基準-ドメインカバレッジ） |
| agents/producer/workflow-completeness.md | 175 | WC 次元: ワークフロー完全性分析（ステップ順序、エラーパス、データフロー、エッジケース、条件分岐網羅性） |
| agents/producer/output-format.md | 180 | OF 次元: 出力形式実現性分析（形式実現可能性、下流利用可能性、情報完全性、セクション間整合性） |
| agents/shared/instruction-clarity.md | 156 | IC 次元（共通）: 指示明確性分析（ドキュメント構造、役割定義、コンテキスト充足、メタ指示品質） |
| agents/unclassified/scope-alignment.md | 135 | SA 次元（軽量版）: スコープ整合性分析（目的明確性、フォーカス適切性、境界暗黙性） |
| templates/apply-improvements.md | 43 | 承認済み findings のエージェント定義への適用テンプレート（サブエージェント用） |

## B. ワークフロー概要
- **フェーズ構成**: Phase 0 → Phase 1 → Phase 2 → Phase 3
  - **Phase 0（初期化・グループ分類）**: 引数パース、エージェント定義読み込み、グループ判定（group-classification.md参照）、agent_name導出、出力ディレクトリ作成、分析次元セット決定
  - **Phase 1（並列分析）**: グループに応じた次元セット（IC + CE/SA/DC/WC/OF）を並列起動（Task × dim_count）、各サブエージェントが findings を `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に保存、返答サマリ収集、成否判定
  - **Phase 2（ユーザー承認 + 改善適用）**: Fast mode 判定 → findings 収集（critical/improvement） → AskUserQuestion で承認方針選択（全て承認/1件ずつ確認/キャンセル） → 承認結果保存（audit-approved.md） → バックアップ作成 → サブエージェント（apply-improvements.md）で改善適用 → 検証ステップ
  - **Phase 3（完了サマリ）**: 実行結果サマリ出力（グループ、次元数、検出件数、承認件数、バックアップパス、次ステップ推奨）

- **各フェーズの目的**:
  - Phase 0: エージェント定義の種別特定と分析準備
  - Phase 1: グループ特有の品質問題を多次元で検出
  - Phase 2: ユーザー承認に基づく改善の適用
  - Phase 3: 実行結果の完全性確認と次ステップ提示

- **データフロー**:
  - **Phase 0 → Phase 1**: `{agent_path}`, `{agent_name}`, `{agent_group}` を各分析サブエージェントに渡す
  - **Phase 1 生成**: 各サブエージェントが `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` を生成（findings詳細）、親は返答サマリのみ保持（critical/improvement/info件数）
  - **Phase 1 → Phase 2**: Phase 2 が audit-*.md ファイル群を Read で収集（親コンテキストには findings 一覧のみ保持）
  - **Phase 2 生成**: `.agent_audit/{agent_name}/audit-approved.md` を生成、バックアップ作成（`{agent_path}.backup-{timestamp}`）
  - **Phase 2 → サブエージェント**: `{approved_findings_path}`, `{agent_path}`, `{backup_path}` を apply-improvements サブエージェントに渡す
  - **サブエージェント → Phase 2**: 変更サマリ（modified/skipped リスト）のみ返答
  - **Phase 2 検証**: 変更後の `{agent_path}` を Read で再読み込み、構造検証

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 76 | `group-classification.md` | グループ判定基準の参照 |
| SKILL.md | 123 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | 各次元の分析エージェント定義 |
| SKILL.md | 213 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | 改善適用テンプレート |
| agents/evaluator/criteria-effectiveness.md | 23 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 共通分析プロセス |
| agents/evaluator/detection-coverage.md | 137 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 共通分析プロセス |
| agents/evaluator/scope-alignment.md | 23 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 共通分析プロセス |
| agents/producer/workflow-completeness.md | 24 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 共通分析プロセス |
| agents/producer/output-format.md | 24 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 共通分析プロセス |
| agents/shared/instruction-clarity.md | 22 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 共通分析プロセス |
| agents/unclassified/scope-alignment.md | 89 | `.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` | 共通分析プロセス |

**注記**: 全ての外部参照は `{skill_path}` 内のパスであり、スキル外への参照は存在しない。

## D. コンテキスト予算分析
- **SKILL.md 行数**: 260行
- **テンプレートファイル数**: 1個（apply-improvements.md: 43行）
- **エージェント定義ファイル数**: 7次元 + 1共通説明（平均行数: 約150行）
- **サブエージェント委譲**: あり
  - **Phase 1**: 並列分析（dim_count 個の Task、model: "sonnet", subagent_type: "general-purpose"）
    - 各サブエージェントは `agents/{dim_path}.md` を Read で読み込み、その指示に従って分析
    - 返答は4行フォーマット（`dim:`, `critical:`, `improvement:`, `info:`）のみ
    - 詳細は `{findings_save_path}` に保存（親コンテキストに保持しない）
  - **Phase 2 Step 4**: 改善適用（1個の Task、model: "sonnet", subagent_type: "general-purpose"）
    - `templates/apply-improvements.md` を Read で読み込み、その指示に従って適用
    - 返答は変更サマリ（modified/skipped リスト、30行以内）のみ
- **親コンテキストに保持される情報**:
  - Phase 0: `{agent_path}`, `{agent_content}`, `{agent_name}`, `{agent_group}`, dimensions リスト、`{dim_count}`
  - Phase 1: 各次元の返答サマリ（dim名、critical/improvement/info件数、成否、エラー概要）のみ（findings詳細はファイル経由）
  - Phase 2 Step 1: findings 一覧テーブル（ID, severity, title, 次元名）のみ（詳細はファイル経由）
  - Phase 2 Step 4: 変更サマリ（modified/skipped リスト、30行以内）のみ
- **3ホップパターンの有無**: なし
  - Phase 1 サブエージェント → ファイル（findings） → Phase 2 親読み込み（ファイル経由、2ホップ）
  - Phase 2 親 → ファイル（approved） → Phase 2 サブエージェント読み込み（ファイル経由、2ホップ）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認（SKILL.md L64） | Fast mode でも同様（必須引数） |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全て承認/1件ずつ確認/キャンセル）（SKILL.md L190） | **スキップ（全findings自動承認）**（L167） |
| Phase 2 Step 2a | AskUserQuestion | 各findingの個別承認（承認/スキップ/残りすべて承認/キャンセル）（SKILL.md L197） | **スキップ（1件ずつ確認選択時のみ発生するため）** |

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - Phase 0 Step 2: `{agent_path}` 読み込み失敗時 → エラー出力「✗ エラー: {agent_path} が見つかりません。ファイルパスを確認してください。」、処理終了（L66）
  - Phase 0 Step 4: `group-classification.md` 不在時 → エラー出力「✗ エラー: group-classification.md が見つかりません。スキルの初期化に失敗しました。」、処理終了（L76-77）
- **サブエージェント失敗時**:
  - Phase 1: 全次元失敗 → エラー出力「Phase 1: 全次元の分析に失敗しました。失敗理由:\n- {次元名}: {エラー概要}\n（各失敗次元を列挙）」、処理終了（L143）
  - Phase 1: 部分失敗 → 継続条件判定（成功数 ≧ 1、かつ（IC成功 または 成功数 ≧ 2））（L145-149）、継続可能なら Phase 2 へ、中止条件なら処理終了
  - Phase 2 Step 4: 改善適用サブエージェント失敗 → エラー出力「✗ 改善適用に失敗しました: {エラー概要}\nバックアップから復旧できます: `cp {backup_path} {agent_path}`」、Phase 3 へ進む（改善適用なしとして扱う）（L221）
- **部分完了時**:
  - Phase 1 部分失敗: 成功した次元のみで Phase 2 へ継続（L145-159）
  - Phase 2 Step 1: 部分失敗時の整合性チェック → 失敗次元の findings が含まれる場合はエラー出力し処理終了（L177）
  - Phase 2 Step 2: 承認数が0の場合 → 「全ての指摘がスキップされました。改善の適用はありません。」、Phase 3 へ直行（L203）
  - Phase 1 critical + improvement が全て0の場合 → 「対象となる指摘はありませんでした。」、Phase 2 スキップして Phase 3 へ（L161）
- **入力バリデーション**:
  - Phase 0 Step 1a: `--fast` フラグの確認（L65）
  - Phase 0 Step 3: YAML frontmatter 存在確認（警告のみ、処理継続）（L67）
  - Phase 1 エラーハンドリング: findings ファイルの存在・非空・`## Summary` セクション存在を確認（L140）、件数は正規表現抽出 → 抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数をカウント（L141）
  - Phase 2 検証ステップ: 改善適用後、YAML frontmatter 存在・見出し行存在を確認、検証失敗時は警告とロールバック手順提示（L223-230）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/{dim_path}.md（7種類: IC, CE, SA, DC, WC, OF, SA軽量版） | 4行（dim, critical, improvement, info） | {dim_count}（グループにより3-5個） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 30行以内（modified/skipped サマリ） | 1個 |
