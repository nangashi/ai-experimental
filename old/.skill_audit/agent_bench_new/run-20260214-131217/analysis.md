# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 373 | スキル定義。ワークフロー定義（Phase 0-6）、パス変数解決、サブエージェント委譲、perspective解決・自動生成、コンテキスト節約原則を含む |
| approach-catalog.md | 202 | 改善アプローチカタログ。4カテゴリ（S/C/N/M）、テクニック・バリエーション3階層、推奨プロンプト構成、共通ルールを定義 |
| scoring-rubric.md | 70 | 採点基準。検出判定（○△×）、スコア計算式、ボーナス/ペナルティ、安定性閾値、推奨判定基準、収束判定を定義 |
| proven-techniques.md | 70 | エージェント横断知見。実証済み効果テクニック（8件）、アンチパターン（8件）、条件付きテクニック（7件）、ベースライン構築ガイド |
| test-document-guide.md | 254 | テスト文書生成ガイド。入力型判定、文書構成（設計書/コード/要件/エージェント定義/汎用）、問題埋め込み（8-10個）、正解キー、多様性確保 |
| templates/knowledge-init-template.md | 61 | knowledge.md初期化テンプレート。効果テーブル、バリエーションステータス、テスト対象文書履歴、スコア推移、構造分析スナップショット |
| templates/phase1a-variant-generation.md | 42 | Phase 1A（初回）バリアント生成。ベースライン作成（proven-techniques.mdのガイドに従う）、6次元構造分析、2バリアント生成 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B（継続）バリアント生成。Broad/Deep モード判定、バリエーションステータステーブル参照、agent_audit連携 |
| templates/phase2-test-document.md | 33 | テスト文書・正解キー生成。test-document-guide参照、perspective問題バンク活用、ドメイン多様性確保 |
| templates/phase4-scoring.md | 13 | 採点実行。scoring-rubric準拠、検出判定（○△×）、ボーナス/ペナルティ、スコアサマリ返答 |
| templates/phase5-analysis-report.md | 22 | 比較レポート・推奨判定。scoring-rubric参照、収束判定、7行サマリ返答（recommended/reason/convergence/scores/variants/deploy_info/user_summary） |
| templates/phase6a-knowledge-update.md | 27 | knowledge.md更新。累計ラウンド数+1、効果テーブル更新、バリエーションステータス更新、スコア推移追記、改善考慮事項統合（20行上限） |
| templates/phase6b-proven-techniques-update.md | 51 | proven-techniques.md更新。3段階昇格条件（Tier 1: 即時/Tier 2: 条件付き/Tier 3: スキップ）、統合ルール（preserve+integrate）、サイズ制限遵守 |
| templates/perspective/generate-perspective.md | 67 | perspective初期生成。必須スキーマ（概要/評価スコープ5項目/スコープ外3項目/ボーナス・ペナルティ判定指針/問題バンク8-10件）、入力型判定 |
| templates/perspective/critic-effectiveness.md | 75 | 有効性批評。品質寄与度分析（なかった場合に見逃される問題3+）、境界明確性検証（既存観点との重複）、段階的分析プロセス |
| templates/perspective/critic-completeness.md | 107 | 網羅性批評。スコープカバレッジ、Missing Element Detection（必須設計要素5+の検出可能性評価）、問題バンク品質（深刻度分布確認） |
| templates/perspective/critic-clarity.md | 76 | 明確性批評。表現の曖昧性（主観的表現検出）、AI動作一貫性（スコープ項目単体テスト）、実行可能性（検出可能な問題パターンか） |
| templates/perspective/critic-generality.md | 82 | 汎用性批評。3次元評価（Industry/Regulation/Tech Stack）、問題バンク検証（業界中立性・文脈移植性）、S/N閾値、抽象化戦略 |
| perspectives/code/security.md | 38 | セキュリティ（実装レビュー）観点定義。インジェクション/認証/機密データ/アクセス制御/依存関係の5項目、問題バンク8件 |
| perspectives/code/maintainability.md | 未読 | 保守性（実装レビュー）観点定義 |
| perspectives/code/performance.md | 未読 | パフォーマンス（実装レビュー）観点定義 |
| perspectives/code/best-practices.md | 未読 | ベストプラクティス（実装レビュー）観点定義 |
| perspectives/code/consistency.md | 未読 | 一貫性（実装レビュー）観点定義 |
| perspectives/design/security.md | 43 | セキュリティ（設計レビュー）観点定義。脅威モデリング（STRIDE）/認証認可/データ保護/入力検証/インフラ監査の5項目、問題バンク10件 |
| perspectives/design/consistency.md | 未読 | 一貫性（設計レビュー）観点定義 |
| perspectives/design/structural-quality.md | 未読 | 構造品質（設計レビュー）観点定義 |
| perspectives/design/performance.md | 未読 | パフォーマンス（設計レビュー）観点定義 |
| perspectives/design/reliability.md | 未読 | 信頼性（設計レビュー）観点定義 |
| perspectives/design/old/maintainability.md | 未読 | old/配下（非参照） |
| perspectives/design/old/best-practices.md | 未読 | old/配下（非参照） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- 各フェーズの目的:
  - Phase 0: 初期化・状態検出（agent_name導出、perspective解決/自動生成、knowledge.md初期化）
  - Phase 1A: 初回 — ベースライン作成+6次元構造分析+バリアント生成（サブエージェント委譲）
  - Phase 1B: 継続 — knowledge.md参照+Broad/Deep判定+バリアント生成（サブエージェント委譲、agent_audit連携）
  - Phase 2: テスト入力文書+正解キー生成（サブエージェント委譲、毎ラウンド実行）
  - Phase 3: 並列評価実行（プロンプト数×2回、サブエージェント並列起動、結果はファイル保存）
  - Phase 4: 採点（プロンプトごとにサブエージェント並列起動、検出判定○△×）
  - Phase 5: 分析・推奨判定・レポート作成（サブエージェント委譲、7行サマリ返答）
  - Phase 6: プロンプト選択・デプロイ・ナレッジ更新・スキル知見フィードバック・次アクション選択
- データフロー:
  - Phase 0 → perspective-source.md（作成）、perspective.md（作業コピー、問題バンク除外）、knowledge.md（初期化）
  - Phase 1A/1B → prompts/v{NNN}-baseline.md, v{NNN}-variant-*.md（生成）、knowledge.md（構造分析更新）
  - Phase 2 → test-document-round-{NNN}.md, answer-key-round-{NNN}.md（生成）
  - Phase 3 → results/v{NNN}-{name}-run{1,2}.md（生成、各プロンプト×2回）
  - Phase 4 → results/v{NNN}-{name}-scoring.md（生成、Phase 3結果を参照）
  - Phase 5 → reports/round-{NNN}-comparison.md（生成、Phase 4採点結果を参照）
  - Phase 6 → agent_path（デプロイ）、knowledge.md（更新）、proven-techniques.md（更新）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54-59 | `.agent_bench/{agent_name}/perspective-source.md` | perspective検索（Phase 0） |
| SKILL.md | 54-59 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | reviewer パターンフォールバック（Phase 0） |
| SKILL.md | 78-81 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | 既存perspective参照データ収集（Phase 0、自動生成時） |
| SKILL.md | 120-123 | `.agent_bench/{agent_name}/knowledge.md` | 初回/継続判定（Phase 0） |
| SKILL.md | 177-178 | `.agent_audit/{agent_name}/audit-dim1-*.md`, `.agent_audit/{agent_name}/audit-dim2-*.md` | agent_audit連携（Phase 1B） |
| templates/phase1a-variant-generation.md | 3-6 | `{proven_techniques_path}`, `{approach_catalog_path}`, `{perspective_source_path}` | ベースライン構築参照 |
| templates/phase1b-variant-generation.md | 8-9 | `{audit_dim1_path}`, `{audit_dim2_path}` | agent_audit分析結果参照 |
| templates/phase2-test-document.md | 4-7 | `{test_document_guide_path}`, `{perspective_path}`, `{perspective_source_path}`, `{knowledge_path}` | テスト文書生成参照 |
| templates/phase4-scoring.md | 3-6 | `{scoring_rubric_path}`, `{answer_key_path}`, `{perspective_path}`, `{result_run1_path}`, `{result_run2_path}` | 採点実行参照 |
| templates/phase5-analysis-report.md | 3-7 | `{scoring_rubric_path}`, `{knowledge_path}`, `{scoring_file_paths}` | 比較レポート作成参照 |
| templates/phase6a-knowledge-update.md | 3-5 | `{knowledge_path}`, `{report_save_path}` | knowledge.md更新参照 |
| templates/phase6b-proven-techniques-update.md | 3-6 | `{proven_techniques_path}`, `{knowledge_path}`, `{report_save_path}` | proven-techniques.md更新参照 |

## D. コンテキスト予算分析
- SKILL.md 行数: 373行
- テンプレートファイル数: 13個、平均行数: 48.2行（範囲: 13-107行）
- サブエージェント委譲: あり（Phase 0 perspective自動生成、Phase 0 knowledge初期化、Phase 1A/1B バリアント生成、Phase 2 テスト文書生成、Phase 3 並列評価、Phase 4 採点、Phase 5 分析レポート、Phase 6A ナレッジ更新、Phase 6B スキル知見フィードバック）
- 親コンテキストに保持される情報: agent_name、agent_path、perspective_source_path、累計ラウンド数、Phase 5の7行サマリ（recommended/reason/convergence/scores/variants/deploy_info/user_summary）、Phase 3成功数、Phase 4成功数
- 3ホップパターンの有無: なし（Phase 3 → 4 → 5 は全てファイル経由でデータ受け渡し。親は Phase 5 の7行サマリのみ保持し、Phase 6A/6B に直接ファイルパスを渡す）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義実質空時の要件ヒアリング（perspective自動生成 Step 1） | 不明 |
| Phase 3 | AskUserQuestion | いずれかのプロンプトで成功結果が0回の場合の確認（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点一部失敗時の確認（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル+推奨プロンプト提示） | 不明 |
| Phase 6 Step 2-C | AskUserQuestion | 次アクション選択（次ラウンド/終了、収束判定・累計ラウンド数の付記あり） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path読み込み失敗 → エラー出力して終了（Phase 0）
  - perspective検索失敗 → 自動生成フローに進む（Phase 0）
  - knowledge.md不在 → 初期化フローに進む（Phase 0）
  - agent_audit結果ファイル不在 → スキップ（Phase 1B、条件分岐で処理）
- サブエージェント失敗時:
  - Phase 3（並列評価）: 成功数 < 総数の場合、分岐条件に応じて警告出力+Phase 4続行、AskUserQuestion確認（再試行/除外/中断）
  - Phase 4（採点）: 一部失敗時、AskUserQuestion確認（再試行/除外/中断）
  - perspective自動生成 Step 6: 検証失敗 → エラー出力してスキル終了
- 部分完了時:
  - Phase 3: 各プロンプトに最低1回の成功結果がある場合、警告出力+Phase 4続行（SD=N/Aでスコアリング）
  - Phase 4: 成功したプロンプトのみで Phase 5 へ進む（ベースライン失敗時は中断）
- 入力バリデーション: agent_path読み込み失敗時のエラー終了のみ明記。その他は未定義

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（perspective自動生成 Step 3） | sonnet | perspective/generate-perspective.md | 4行（観点名/入力型/評価スコープ/問題バンク件数） | 1 |
| Phase 0（perspective自動生成 Step 4） | sonnet | perspective/critic-effectiveness.md, critic-completeness.md, critic-clarity.md, critic-generality.md | 可変（SendMessage形式） | 4並列 |
| Phase 0（perspective自動生成 Step 5） | sonnet | perspective/generate-perspective.md（再生成） | 4行 | 1（条件付き） |
| Phase 0（knowledge初期化） | sonnet | knowledge-init-template.md | 1行（初期化完了+バリエーション数） | 1（初回のみ） |
| Phase 1A | sonnet | phase1a-variant-generation.md | 可変（エージェント定義サマリ+構造分析テーブル+バリアント2件） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 可変（選定プロセス+バリアント2件） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 可変（テスト対象文書サマリ+埋め込み問題テーブル+ボーナス問題テーブル） | 1 |
| Phase 3 | sonnet | （テンプレートなし、直接指示） | 1行（保存完了: {result_path}） | (ベースライン1+バリアント数)×2回 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（{prompt_name}: Mean={X.X}, SD={X.X} + Run1/Run2詳細） | プロンプト数（並列） |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended/reason/convergence/scores/variants/deploy_info/user_summary） | 1 |
| Phase 6A | sonnet | phase6a-knowledge-update.md | 1行（knowledge.md更新完了+累計ラウンド数） | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update.md | 1行（proven-techniques.md更新完了またはスキップ） | 1 |
