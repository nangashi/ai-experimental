# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 382 | スキルのメインワークフロー定義。Phase 0-6の全体制御とサブエージェント委譲指示 |
| approach-catalog.md | 202 | 改善アプローチのカタログ（S/C/N/M カテゴリ、テクニック、バリエーション）。Phase 1で参照 |
| scoring-rubric.md | 70 | 採点基準（検出判定○△×、スコア計算式、推奨判定基準、収束判定）。Phase 4で参照 |
| test-document-guide.md | 254 | テスト対象文書生成ガイド（入力型判定、文書構成、問題埋め込みガイドライン）。Phase 2で参照 |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック（効果テクニック、アンチパターン、条件付き、ベースライン構築ガイド）。Phase 1/6Bで参照/更新 |
| knowledge-init-template.md | 53 | knowledge.md の初期化テンプレート。Phase 0で使用（初回のみ） |
| templates/phase1a-variant-generation.md | 41 | Phase 1A（初回バリアント生成）のサブエージェント指示 |
| templates/phase1b-variant-generation.md | 39 | Phase 1B（継続バリアント生成）のサブエージェント指示 |
| templates/phase2-test-document.md | 33 | Phase 2（テスト文書生成）のサブエージェント指示 |
| templates/phase3-evaluation.md | 7 | Phase 3（評価実行）のサブエージェント指示 |
| templates/phase4-scoring.md | 13 | Phase 4（採点）のサブエージェント指示 |
| templates/phase5-analysis-report.md | 24 | Phase 5（分析・推奨判定）のサブエージェント指示 |
| templates/phase6a-deploy.md | 7 | Phase 6 Step 1（デプロイ）のサブエージェント指示 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6 Step 2A（ナレッジ更新）のサブエージェント指示 |
| templates/phase6b-proven-techniques-update.md | 55 | Phase 6 Step 2B（スキル知見フィードバック）のサブエージェント指示 |
| templates/perspective/generate-perspective.md | 80 | Phase 0 perspective 自動生成のサブエージェント指示 |
| templates/perspective/critic-effectiveness.md | 75 | Phase 0 perspective 自動生成 Step 4（有効性批評）のサブエージェント指示 |
| templates/perspective/critic-completeness.md | 107 | Phase 0 perspective 自動生成 Step 4（網羅性批評）のサブエージェント指示 |
| templates/perspective/critic-clarity.md | 76 | Phase 0 perspective 自動生成 Step 4（明確性批評）のサブエージェント指示 |
| templates/perspective/critic-generality.md | 82 | Phase 0 perspective 自動生成 Step 4（汎用性批評）のサブエージェント指示 |
| perspectives/code/best-practices.md | 34 | コードレビュー向けベストプラクティス観点定義（フォールバック用） |
| perspectives/code/consistency.md | 33 | コードレビュー向け一貫性観点定義（フォールバック用） |
| perspectives/code/maintainability.md | 34 | コードレビュー向け保守性観点定義（フォールバック用） |
| perspectives/code/security.md | 37 | コードレビュー向けセキュリティ観点定義（フォールバック用） |
| perspectives/code/performance.md | 37 | コードレビュー向けパフォーマンス観点定義（フォールバック用） |
| perspectives/design/consistency.md | 51 | 設計レビュー向け一貫性観点定義（フォールバック用） |
| perspectives/design/security.md | 43 | 設計レビュー向けセキュリティ観点定義（フォールバック用） |
| perspectives/design/structural-quality.md | 41 | 設計レビュー向け構造的品質観点定義（フォールバック用） |
| perspectives/design/performance.md | 45 | 設計レビュー向けパフォーマンス観点定義（フォールバック用） |
| perspectives/design/reliability.md | 43 | 設計レビュー向け信頼性・運用性観点定義（フォールバック用） |
| perspectives/design/old/best-practices.md | 34 | （旧版、Phase 0でスキップされる） |
| perspectives/design/old/maintainability.md | 43 | （旧版、Phase 0でスキップされる） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- 各フェーズの目的:
  - **Phase 0**: 初期化・状態検出（エージェント読込、agent_name導出、perspective解決/自動生成、knowledge.md初期化）
  - **Phase 1A**: 初回バリアント生成（ベースライン作成 + 2バリアント）
  - **Phase 1B**: 継続バリアント生成（知見ベースの選定。Broad/Deep モード）
  - **Phase 2**: テスト対象文書と正解キー生成（毎ラウンド実行）
  - **Phase 3**: 並列評価実行（各プロンプト × 2回）
  - **Phase 4**: 採点（並列実行。各プロンプトごとにサブエージェント起動）
  - **Phase 5**: 分析・推奨判定・レポート作成
  - **Phase 6**: プロンプト選択・デプロイ・ナレッジ更新・スキル知見フィードバック・次アクション選択
- データフロー:
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md` を生成/読込
  - Phase 1A/1B → `.agent_bench/{agent_name}/prompts/v{NNN}-baseline.md`, `v{NNN}-variant-*.md` を生成
  - Phase 2 → `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md` を生成
  - Phase 3 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1,2}.md` を生成
  - Phase 4 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md` を生成。Phase 5で参照
  - Phase 5 → `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md` を生成。Phase 6で参照
  - Phase 6 → `knowledge.md`, `proven-techniques.md`, `{agent_path}` を更新。Phase 1Bで再び参照

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 88 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | perspective フォールバック検索（Step 2） |
| SKILL.md | 66-67 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | perspective フォールバック検索（Step 4b） |
| SKILL.md | 95 | `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` | perspective 自動生成の指示テンプレート読込（Step 3） |
| SKILL.md | 106 | `.claude/skills/agent_bench_new/templates/perspective/{critic-*.md}` | perspective 自動生成の批評テンプレート読込（Step 4） |
| SKILL.md | 149 | `.claude/skills/agent_bench_new/approach-catalog.md` | アプローチカタログ読込（Phase 1A） |
| SKILL.md | 174 | `.claude/skills/agent_bench_new/proven-techniques.md` | 実証済みテクニック読込（Phase 1A） |
| SKILL.md | 193 | `.claude/skills/agent_bench_new/approach-catalog.md` | アプローチカタログ読込（Phase 1B） |
| SKILL.md | 194 | `.claude/skills/agent_bench_new/proven-techniques.md` | 実証済みテクニック読込（Phase 1B） |
| SKILL.md | 195-196 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit の分析結果読込（Phase 1B、存在する場合のみ） |
| SKILL.md | 209 | `.claude/skills/agent_bench_new/test-document-guide.md` | テスト対象文書生成ガイド読込（Phase 2） |
| SKILL.md | 234 | `.claude/skills/agent_bench_new/templates/phase3-evaluation.md` | 評価指示テンプレート読込（Phase 3） |
| SKILL.md | 262 | `.claude/skills/agent_bench_new/scoring-rubric.md` | 採点基準読込（Phase 4） |
| SKILL.md | 286 | `.claude/skills/agent_bench_new/scoring-rubric.md` | 採点基準読込（Phase 5） |
| SKILL.md | 347 | `.claude/skills/agent_bench_new/proven-techniques.md` | 実証済みテクニック読込（Phase 6 Step 2B） |

## D. コンテキスト予算分析
- SKILL.md 行数: 382行
- テンプレートファイル数: 15個、平均行数: 50.5行（最大107行 = critic-completeness.md、最小7行 = phase3/phase6a-deploy）
- サブエージェント委譲: あり（Phase 0（初回のみ knowledge 初期化 + perspective 自動生成 × 5タスク）、Phase 1A/1B、Phase 2、Phase 3（並列実行）、Phase 4（並列実行）、Phase 5、Phase 6 Step 1/2A/2B）
- 親コンテキストに保持される情報: agent_name, agent_path, 累計ラウンド数, バリエーションステータステーブル（メタデータのみ、詳細はファイル経由）、Phase 5サブエージェントの7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
- 3ホップパターンの有無: なし（全てファイル経由で直接参照。例: Phase 1 → prompts/ → Phase 3 → results/ → Phase 4 → scoring/ → Phase 5 → report/ → Phase 6）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | perspective 自動生成時のエージェント定義不足のヒアリング | 不明 |
| Phase 0 | AskUserQuestion | perspective 検証失敗時の対応選択（手動修正/削除/中断） | 不明 |
| Phase 1A | AskUserQuestion | 既存プロンプトファイル上書き確認 | 不明 |
| Phase 1B | AskUserQuestion | 既存プロンプトファイル上書き確認 | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の対応選択（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応選択（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時: Phase 0で agent_path 読込失敗時はエラー出力して終了。knowledge.md 不在時は初期化して Phase 1A へ。perspective 不在時は自動生成を実行
- サブエージェント失敗時: Phase 3評価で失敗があり、各プロンプトに最低1回の成功結果がある場合は警告を出力して Phase 4 へ進む。いずれかのプロンプトで成功結果が0回の場合は AskUserQuestion で確認（再試行/除外/中断）。Phase 4採点で一部失敗した場合も AskUserQuestion で確認（再試行/除外/中断）。ただしベースライン採点失敗時は自動的にスキル中断。Phase 6 Step 2A/2B で失敗した場合は警告を出力し、該当更新をスキップして次ステップへ進む
- 部分完了時: Phase 3で成功数 < 総数かつ各プロンプトに最低1回の成功結果がある場合、成功した Run のみで Phase 4 へ進む。Run が1回のみのプロンプトは SD = N/A とする
- 入力バリデーション: agent_path 未指定時は AskUserQuestion で確認。perspective 自動生成時にエージェント定義が200文字未満/見出し2個以下/目的・入力・出力のキーワードを含むセクションがない場合は AskUserQuestion でヒアリング。既存プロンプトファイル存在時は AskUserQuestion で上書き確認

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（初回knowledge初期化） | sonnet | knowledge-init-template.md | 1行（初期化完了通知） | 1 |
| Phase 0（perspective自動生成 Step 3） | sonnet | perspective/generate-perspective.md | 4行（観点サマリ） | 1 |
| Phase 0（perspective自動生成 Step 4） | sonnet | perspective/critic-effectiveness.md | 1行（保存完了通知） | 4並列 |
| Phase 0（perspective自動生成 Step 4） | sonnet | perspective/critic-completeness.md | 1行（保存完了通知） | 4並列 |
| Phase 0（perspective自動生成 Step 4） | sonnet | perspective/critic-clarity.md | 1行（保存完了通知） | 4並列 |
| Phase 0（perspective自動生成 Step 4） | sonnet | perspective/critic-generality.md | 1行（保存完了通知） | 4並列 |
| Phase 1A | sonnet | phase1a-variant-generation.md | サマリ（構造分析結果+バリアント情報） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | サマリ（選定プロセス+バリアント情報） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | サマリ（テスト対象文書サマリ+埋め込み問題一覧+ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | phase3-evaluation.md | 1行（保存完了通知） | (ベースライン + バリアント数) × 2回（全並列） |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ） | プロンプト数（並列） |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1 | haiku | phase6a-deploy.md | 1行（デプロイ完了通知） | 1 |
| Phase 6 Step 2A | sonnet | phase6a-knowledge-update.md | 1行（更新完了通知） | 1 |
| Phase 6 Step 2B | sonnet | phase6b-proven-techniques-update.md | 1行（更新完了通知） | 1 |
