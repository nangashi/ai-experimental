# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 370 | スキル全体の定義、ワークフロー、パス変数、各フェーズの詳細手順 |
| group-classification.md | 24 | エージェントグループ（hybrid/evaluator/producer/unclassified）の判定基準 |
| templates/apply-improvements.md | 40 | Phase 2 Step 4: 承認済み findings に基づく改善適用の手順テンプレート |
| templates/analyze-dimensions.md | 19 | Phase 1: 次元分析サブエージェント起動時のテンプレート（返答フォーマット含む） |
| agents/shared/analysis-framework.md | 66 | 全次元共通の2段階分析プロセス（Phase 1: 包括的検出、Phase 2: 整理・報告）と Detection Strategies の概念定義 |
| agents/evaluator/criteria-effectiveness.md | 167 | 基準有効性次元（CE-）の検出ロジック：曖昧さ、S/N比、実行可能性、費用対効果、カバレッジギャップ |
| agents/evaluator/scope-alignment.md | 158 | スコープ整合性次元（SA-、evaluator 版）の検出ロジック：スコープ定義の明確さ、境界の曖昧さ、内部整合性、カバレッジ分析 |
| agents/evaluator/detection-coverage.md | 180 | 検出カバレッジ次元（DC-）の検出ロジック：検出戦略完全性、severity 分類堅牢性、出力形式有効性、偽陽性リスク |
| agents/producer/workflow-completeness.md | 167 | ワークフロー完全性次元（WC-）の検出ロジック：ステップ順序、データフロー、エラーパス、エッジケース対応 |
| agents/producer/output-format.md | 173 | 出力形式実現性次元（OF-）の検出ロジック：形式実現可能性、下流利用可能性、情報完全性、整合性 |
| agents/shared/instruction-clarity.md | 183 | 指示明確性次元（IC-、全グループ共通）の検出ロジック：ドキュメント構造、役割定義、コンテキスト充足、指示有効性 |
| agents/unclassified/scope-alignment.md | 145 | スコープ整合性次元（SA-、unclassified 版・軽量版）の検出ロジック：目的明確性、フォーカス適切性、境界暗黙性 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的（1行ずつ）:
  - **Phase 0 (初期化・グループ分類)**: エージェント定義読み込み、frontmatter チェック、グループ分類（hybrid/evaluator/producer/unclassified）、agent_name 導出、出力ディレクトリ作成、前回実行履歴確認、分析次元セット決定
  - **Phase 1 (並列分析)**: グループに応じた次元セット（3-5次元）をサブエージェント（sonnet, general-purpose）で並列分析し、各次元の findings を `.agent_audit/{agent_name}/run-{timestamp}/audit-{ID_PREFIX}.md` に保存、サマリ（critical/improvement/info 件数）を収集
  - **Phase 2 (ユーザー承認 + 改善適用)**: findings 収集、severity フィルタ（critical/improvement）、一覧提示、承認方針選択（全承認/1件ずつ確認/キャンセル）、per-item 承認ループ、承認結果保存、バックアップ作成、サブエージェント（sonnet）による改善適用、検証（構造検証、audit-approved.md 検証）
  - **Phase 3 (完了サマリ)**: 検出件数・承認件数・変更詳細・バックアップパス・前回比較（解決済み指摘・新規指摘）を出力、次のステップ提示（critical 適用時は再 audit 推奨、improvement のみ適用時は bench 推奨）

- データフロー（どのフェーズがどのファイルを生成し、どのフェーズが参照するか）:
  - **Phase 0**: `.agent_audit/{agent_name}/run-{timestamp}/` ディレクトリ作成、シンボリックリンク `.agent_audit/{agent_name}/audit-approved.md` のリンク先（`{previous_approved_path}`）を Read で参照（前回実行履歴）
  - **Phase 1**: 各次元サブエージェントが `{agent_path}` を Read、`{previous_approved_path}` を参照（解決済み指摘）、`.agent_audit/{agent_name}/run-{timestamp}/audit-{ID_PREFIX}.md` を生成、親は findings ファイルの存在確認とサマリ抽出のみ実行
  - **Phase 2 Step 1**: Phase 1 で生成された全 findings ファイルを Read し、critical/improvement の finding を抽出・ソート
  - **Phase 2 Step 3**: 承認済み findings を `.agent_audit/{agent_name}/run-{timestamp}/audit-approved.md` に Write、シンボリックリンク更新（`ln -sf`）
  - **Phase 2 Step 4**: サブエージェント（apply-improvements）が `{agent_path}` と `{approved_findings_path}` を Read、`{agent_path}` を Edit/Write で更新、`{agent_path}.backup-{timestamp}` を Bash で作成
  - **Phase 2 検証**: `{agent_path}` と `{approved_findings_path}` を Read で再読み込み、構造検証実行
  - **Phase 3**: Phase 2 の承認結果を使用し、`{previous_approved_path}` と `{approved_findings_path}` から finding ID を抽出して差分計算（解決済み・新規指摘）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 30 | `/home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new` | スキルディレクトリの絶対パスとして明記（パス変数 {skill_path} の例） |
| SKILL.md | 31-41 | `.agent_audit/{agent_name}/run-{timestamp}/audit-{ID_PREFIX}.md`, `.agent_audit/{agent_name}/audit-approved.md` | 出力ディレクトリとファイルパス変数定義（プロジェクト内の `.agent_audit/` 配下） |
| SKILL.md | 100-103 | `.claude/agents/security-design-reviewer.md`, `my-agents/custom.md` | agent_name 導出ルールの説明内の例示（`.claude/` 配下とそれ以外の分岐判定） |
| SKILL.md | 152-155 | `{dim_agent_path}`, `{agent_path}`, `{previous_approved_path}`, `{findings_save_path}` | Phase 1 でサブエージェントに渡すパス変数（スキル内ファイルとプロジェクト内ファイルの両方） |
| SKILL.md | 287-291 | `{skill_path}/templates/apply-improvements.md`, `{agent_path}`, `{approved_findings_path}` | Phase 2 Step 4 でサブエージェントに渡すパス変数（スキル内テンプレートとプロジェクト内ファイル） |

備考: 外部参照は全てパス変数として抽象化されており、実行時に解決される。スキル外の絶対パスを直接ハードコードした箇所は行30の例示のみ（実際の処理では変数を使用）。

## D. コンテキスト予算分析
- SKILL.md 行数: 370行
- テンプレートファイル数: 2個、平均行数: 29.5行（apply-improvements.md: 40行、analyze-dimensions.md: 19行）
- サブエージェント委譲: あり（Phase 1 で3-5個の次元分析サブエージェント並列起動、Phase 2 で1個の改善適用サブエージェント起動）
- 親コンテキストに保持される情報:
  - agent_name, agent_group, agent_path（全フェーズで使用）
  - dim_count, dimensions テーブル（グループ別次元セット）
  - run_dir, previous_approved_path, previous_approved_count（前回実行履歴）
  - dim_summaries（Phase 1 各次元の critical/improvement/info 件数サマリ、4行 × 3-5次元 = 12-20行程度）
  - 承認結果メタデータ（total, approved, skip, critical_count, improvement_count）
  - バックアップパス、変更サマリ（Phase 2 から）
- 3ホップパターンの有無: なし（Phase 1 サブエージェントは findings をファイル保存し、親はファイルから読み込む。Phase 2 サブエージェントも同様にファイル経由でデータ受け渡し。親が中継せず、ファイル経由の直接受け渡しを使用）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時にファイルパス確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認ループ（承認/スキップ/残り全承認/キャンセル/修正入力）、入力不明確時の再確認、残り全承認時の確認ダイアログ | 不明 |
| Phase 2 Step 4 | AskUserQuestion | 改善適用前の最終確認（続行/キャンセル） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0 で `{agent_path}` 読み込み失敗 → エラー出力して終了
  - Phase 0 で frontmatter 不在 → 警告表示「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。」（処理は継続）
  - Phase 0 Step 6a で `{previous_approved_path}` 不在（readlink エラー）→ `{previous_approved_count} = 0` として継続
  - Phase 1 で各次元の findings ファイル不在またはサイズ < 10バイト → 該当次元を「分析失敗（{エラー概要}）」として記録、1次元でも成功すれば Phase 2 へ進む
  - Phase 1 で全次元失敗 → 「Phase 1: 全次元の分析に失敗しました。」とエラー出力して終了
  - Phase 2 Step 1 で findings 内の必須フィールド欠落 → 該当 finding をスキップし、警告表示
  - Phase 2 Step 4 でバックアップ作成失敗（`test -f {backup_path}` で不在確認）→ 「✗ バックアップ作成に失敗しました。改善適用を中止します。」とエラー出力し、Phase 3 へ直行
- サブエージェント失敗時:
  - Phase 1 の各次元分析サブエージェント失敗 → findings ファイル存在確認で判定、失敗した次元は `{dim_summaries}` に「分析失敗（{エラー概要}）」として記録、他の次元が成功すれば継続
  - Phase 2 Step 4 の改善適用サブエージェント失敗 → 検証ステップで検出（modified: 0件の警告表示、または構造検証失敗）
- 部分完了時:
  - Phase 1 で一部次元のみ成功 → 成功した次元の findings のみ Phase 2 で使用
  - Phase 2 Step 1 で一部 finding のみバリデーション成功 → バリデーション成功した finding のみ対象とする（スキップされた finding は警告表示）
  - Phase 2 で承認が 0 件 → 「全ての指摘がスキップされました。改善の適用はありません。」と出力し、Phase 3 へ直行
  - Phase 2 検証で `modified: 0件` → 警告表示してバックアップ保持のまま Phase 3 へ進む
- 入力バリデーション:
  - Phase 0 で frontmatter の YAML 構造チェック（`---` で囲まれ、`description:` を含む）
  - Phase 0 のグループ分類失敗 → デフォルト値 "unclassified" を使用し、警告表示
  - Phase 2 Step 1 で severity フィールドバリデーション（critical/improvement/info 以外または欠落時はスキップして警告表示）
  - Phase 2 Step 2a で修正内容入力の不明確性チェック（2行以下で具体性なし → 最大1回再確認、2回目も不明確ならスキップ）
  - Phase 2 検証ステップで構造検証（frontmatter, グループ別必須セクション, audit-approved.md 構造）、失敗時は Phase 3 へ直行またはスキル終了

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | templates/analyze-dimensions.md（次元エージェントファイル参照）| 4行固定（dim, critical, improvement, info） | 3-5個（グループ別: unclassified=3, evaluator/producer=4, hybrid=5） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 可変（modified リスト最大20件 + skipped リスト最大10件 + 超過省略行） | 1個 |
