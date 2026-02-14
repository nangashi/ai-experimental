# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 370 | スキルの主要ワークフロー定義（Phase 0-6） |
| approach-catalog.md | 202 | 改善アプローチの3階層カタログ（カテゴリ→テクニック→バリエーション） |
| scoring-rubric.md | 70 | 検出判定基準・スコア計算式・推奨判定基準・収束判定 |
| test-document-guide.md | 254 | テスト対象文書生成の入力型判定・問題埋め込みガイドライン |
| proven-techniques.md | 70 | エージェント横断の実証済み知見（自動更新） |
| perspectives/code/best-practices.md | 34 | コードレビュー向け観点定義：ベストプラクティス |
| perspectives/code/maintainability.md | 34 | コードレビュー向け観点定義：保守性 |
| perspectives/code/security.md | 37 | コードレビュー向け観点定義：セキュリティ |
| perspectives/code/performance.md | 37 | コードレビュー向け観点定義：パフォーマンス |
| perspectives/code/consistency.md | 33 | コードレビュー向け観点定義：一貫性 |
| perspectives/design/consistency.md | 51 | 設計レビュー向け観点定義：一貫性 |
| perspectives/design/security.md | 43 | 設計レビュー向け観点定義：セキュリティ |
| perspectives/design/old/maintainability.md | 43 | 設計レビュー向け観点定義：保守性（旧版） |
| perspectives/design/old/best-practices.md | 34 | 設計レビュー向け観点定義：ベストプラクティス（旧版） |
| perspectives/design/performance.md | 45 | 設計レビュー向け観点定義：パフォーマンス |
| perspectives/design/reliability.md | 43 | 設計レビュー向け観点定義：信頼性・運用性 |
| perspectives/design/structural-quality.md | 41 | 設計レビュー向け観点定義：構造的品質 |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成テンプレート |
| templates/perspective/critic-completeness.md | 107 | perspective 批評：網羅性・欠落検出能力 |
| templates/perspective/critic-clarity.md | 76 | perspective 批評：表現の明確性・AI動作一貫性 |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評：有効性・境界明確性 |
| templates/perspective/critic-generality.md | 80 | perspective 批評：汎用性・業界依存性 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A（初回）バリアント生成テンプレート |
| templates/phase1b-variant-generation.md | 33 | Phase 1B（継続）バリアント生成テンプレート |
| templates/phase2-test-document.md | 30 | Phase 2 テスト文書生成テンプレート |
| templates/phase4-scoring.md | 13 | Phase 4 採点テンプレート |
| templates/phase5-analysis-report.md | 22 | Phase 5 分析・推奨判定テンプレート |
| templates/phase6a-knowledge-update.md | 23 | Phase 6A ナレッジ更新テンプレート |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B スキル知見フィードバックテンプレート |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1A/1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
- 各フェーズの目的:
  - Phase 0: 初期化・perspective 解決/生成・knowledge.md 初期化・初回/継続判定
  - Phase 1A: ベースライン作成 + バリアント生成（初回）
  - Phase 1B: 知見ベースのバリアント生成（継続ラウンド）
  - Phase 2: テスト入力文書 + 正解キー生成（毎ラウンド実行）
  - Phase 3: プロンプト×2回の並列評価実行
  - Phase 4: 採点（プロンプトごとに並列実行）
  - Phase 5: 分析・推奨判定・レポート作成
  - Phase 6: プロンプト選択・デプロイ・ナレッジ更新・次アクション選択
- データフロー:
  - Phase 0 生成: `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md`
  - Phase 1A/1B 生成: `.agent_bench/{agent_name}/prompts/v{NNN}-*.md`
  - Phase 2 生成: `test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
  - Phase 3 生成: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1,2}.md`
  - Phase 4 生成: `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md`
  - Phase 5 生成: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
  - Phase 6 参照: knowledge.md, proven-techniques.md を更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | perspective フォールバックパターン検索 |
| SKILL.md | 74 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | perspective 自動生成時の参照データ収集 |
| SKILL.md | 171 | `.agent_audit/{agent_name}/audit-dim1.md` | agent_audit 連携（基準有効性分析） |
| SKILL.md | 172 | `.agent_audit/{agent_name}/audit-dim2.md` | agent_audit 連携（スコープ整合性分析） |
| templates/phase1b-variant-generation.md | 7-8 | `.agent_audit/{agent_name}/audit-dim1.md`, `audit-dim2.md` | agent_audit 結果を参考にバリアント生成 |

## D. コンテキスト予算分析
- SKILL.md 行数: 370行
- テンプレートファイル数: 15個、平均行数: 約50行
- サブエージェント委譲: あり（Phase 0 perspective 自動生成 5並列 + 1統合、Phase 0 knowledge 初期化、Phase 1A/1B バリアント生成、Phase 2 テスト文書生成、Phase 3 評価実行 N×2並列、Phase 4 採点 N並列、Phase 5 分析・推奨判定、Phase 6A ナレッジ更新、Phase 6B スキル知見フィードバック）
- 親コンテキストに保持される情報: エージェント名、agent_path、perspective 解決状態、累計ラウンド数、プロンプト一覧、サブエージェント返答サマリ（7行フォーマット）
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しはファイル経由で行う設計）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が不十分な場合のヒアリング | 不明 |
| Phase 3 | AskUserQuestion | 評価タスク失敗時の再試行/除外/中断選択 | 不明 |
| Phase 4 | AskUserQuestion | 採点タスク失敗時の再試行/除外/中断選択 | 不明 |
| Phase 6 | AskUserQuestion | プロンプト選択（全評価プロンプトから選択、推奨付き） | 不明 |
| Phase 6 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読み込み失敗 → エラー出力して終了
  - perspective-source.md 不在 → フォールバック検索 → 自動生成
  - knowledge.md 不在 → 初期化してPhase 1Aへ
  - audit-dim1/dim2 不在 → 空文字列をサブエージェントに渡す
- サブエージェント失敗時:
  - Phase 3 評価タスク: 成功数に応じて分岐（全成功→続行、部分成功→警告付き続行、全失敗→AskUserQuestion）
  - Phase 4 採点タスク: 一部失敗時に AskUserQuestion で再試行/除外/中断選択
  - Phase 0 perspective 自動生成: 検証失敗時にエラー出力して終了
- 部分完了時: Phase 3/4 で各プロンプトに最低1回の成功結果があればPhase 4/5へ進む（SD=N/Aとして扱う）
- 入力バリデーション: agent_path 必須（未指定時は AskUserQuestion で確認）、エージェント定義が50文字未満または主要要素欠如時にヒアリング

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 perspective 自動生成 Step 3 | sonnet | templates/perspective/generate-perspective.md | サマリのみ（観点/入力型/評価スコープ/問題バンク件数） | 1 |
| Phase 0 perspective 批評（Step 4） | sonnet | templates/perspective/critic-effectiveness.md | 指定フォーマット | 4並列 |
| Phase 0 perspective 批評（Step 4） | sonnet | templates/perspective/critic-completeness.md | 指定フォーマット | 4並列 |
| Phase 0 perspective 批評（Step 4） | sonnet | templates/perspective/critic-clarity.md | 指定フォーマット | 4並列 |
| Phase 0 perspective 批評（Step 4） | sonnet | templates/perspective/critic-generality.md | 指定フォーマット | 4並列 |
| Phase 0 perspective 再生成（Step 5） | sonnet | templates/perspective/generate-perspective.md | サマリのみ | 1（条件付き） |
| Phase 0 knowledge 初期化 | sonnet | templates/knowledge-init-template.md | 1行（バリエーション数） | 1（条件付き） |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | サマリのみ（選定プロセス+生成バリアント情報） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | サマリのみ（選定プロセス+生成バリアント情報） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | サマリのみ（入力型+行数+埋め込み問題一覧+ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | エージェント定義ファイル（プロンプト） | 1行（保存完了メッセージ） | (プロンプト数)×2並列 |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（スコアサマリ） | プロンプト数並列 |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended/reason/convergence/scores/variants/deploy_info/user_summary） | 1 |
| Phase 6 Step 1 デプロイ | haiku | 手順記述（メタデータ除去+上書き） | 1行（デプロイ完了メッセージ） | 1（条件付き） |
| Phase 6 Step 2A ナレッジ更新 | sonnet | templates/phase6a-knowledge-update.md | 1行（更新完了メッセージ） | 1 |
| Phase 6 Step 2B スキル知見フィードバック | sonnet | templates/phase6b-proven-techniques-update.md | 1行（更新完了/更新なしメッセージ） | 1 |
