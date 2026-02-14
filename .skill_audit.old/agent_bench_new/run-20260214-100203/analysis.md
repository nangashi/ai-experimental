# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 370 | スキル本体。ワークフロー全体（Phase 0-6）の定義とサブエージェント委譲指示 |
| approach-catalog.md | 202 | 改善アプローチカタログ。カテゴリ→テクニック→バリエーションの3階層管理 |
| scoring-rubric.md | 70 | 採点基準。検出判定（○△×）、スコア計算式、推奨判定基準、収束判定 |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック。Phase 6B で自動更新 |
| test-document-guide.md | 254 | テスト文書生成ガイド。入力型判定、文書構成、問題埋め込み、正解キー形式 |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート（Phase 0 初回時） |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回ベースライン作成+バリアント生成 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B: 継続時バリアント生成（knowledge ベース） |
| templates/phase2-test-document.md | 33 | Phase 2: テスト文書+正解キー生成 |
| templates/phase4-scoring.md | 13 | Phase 4: 採点実行 |
| templates/phase5-analysis-report.md | 22 | Phase 5: 分析・推奨判定・レポート作成 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A: knowledge.md 更新 |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B: proven-techniques.md 更新（昇格条件判定） |
| templates/perspective/generate-perspective.md | 67 | perspective 初期生成テンプレート |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評: 有効性（品質寄与度+境界明確性） |
| templates/perspective/critic-completeness.md | 106 | perspective 批評: 網羅性（欠落検出能力+問題バンク） |
| templates/perspective/critic-clarity.md | 76 | perspective 批評: 明確性（表現+AI動作一貫性） |
| templates/perspective/critic-generality.md | 82 | perspective 批評: 汎用性（業界依存性フィルタ） |
| perspectives/code/security.md | 38 | 事前定義 perspective: コード セキュリティ |
| perspectives/code/performance.md | 未読 | 事前定義 perspective: コード パフォーマンス |
| perspectives/code/consistency.md | 未読 | 事前定義 perspective: コード 一貫性 |
| perspectives/code/best-practices.md | 未読 | 事前定義 perspective: コード ベストプラクティス |
| perspectives/code/maintainability.md | 未読 | 事前定義 perspective: コード 保守性 |
| perspectives/design/security.md | 43 | 事前定義 perspective: 設計 セキュリティ |
| perspectives/design/performance.md | 未読 | 事前定義 perspective: 設計 パフォーマンス |
| perspectives/design/consistency.md | 未読 | 事前定義 perspective: 設計 一貫性 |
| perspectives/design/structural-quality.md | 41 | 事前定義 perspective: 設計 構造的品質 |
| perspectives/design/reliability.md | 未読 | 事前定義 perspective: 設計 信頼性 |
| perspectives/design/old/maintainability.md | 未読 | 旧 perspective（アーカイブ） |
| perspectives/design/old/best-practices.md | 未読 | 旧 perspective（アーカイブ） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 → (ループまたは終了)
- 各フェーズの目的:
  - Phase 0: エージェント読み込み、agent_name 導出、perspective 解決/自動生成、knowledge.md の初期化/検出
  - Phase 1A: 初回 — ベースライン作成+構造分析ベースのバリアント生成（サブエージェント委譲）
  - Phase 1B: 継続 — knowledge ベースのバリアント生成（Broad/Deep モード、サブエージェント委譲）
  - Phase 2: テスト入力文書+正解キー生成（毎ラウンド、サブエージェント委譲）
  - Phase 3: 並列評価実行（各プロンプト×2回、全て並列サブエージェント起動）
  - Phase 4: 採点（プロンプトごとに1採点サブエージェント、並列実行）
  - Phase 5: 分析・推奨判定・レポート作成（サブエージェント委譲）
  - Phase 6: プロンプト選択（親で実行）→ デプロイ（haiku サブエージェント）→ ナレッジ更新（6A, 6B 並列サブエージェント）→ 次アクション選択（親で実行）

- データフロー:
  - Phase 0 → perspective-source.md, perspective.md, knowledge.md 生成
  - Phase 1A/1B → prompts/v{NNN}-*.md 生成
  - Phase 2 → test-document-round-{NNN}.md, answer-key-round-{NNN}.md 生成
  - Phase 3 → results/v{NNN}-{name}-run{1,2}.md 生成
  - Phase 4 → results/v{NNN}-{name}-scoring.md 生成（Phase 3 の run1/run2 を参照）
  - Phase 5 → reports/round-{NNN}-comparison.md 生成（Phase 4 の scoring ファイル群を参照）
  - Phase 6A → knowledge.md 更新（Phase 5 の report を参照）
  - Phase 6B → proven-techniques.md 更新（knowledge.md と report を参照）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | perspective フォールバック検索（パターンマッチ時） |
| SKILL.md | 74 | `.claude/skills/agent_bench/perspectives/design/*.md` | 既存 perspective 参照データ収集（自動生成時） |
| SKILL.md | 81 | `.claude/skills/agent_bench/templates/perspective/generate-perspective.md` | perspective 初期生成テンプレート |
| SKILL.md | 92-95 | `.claude/skills/agent_bench/templates/perspective/{critic-*.md}` | 4並列批評テンプレート |
| SKILL.md | 126 | `.claude/skills/agent_bench/approach-catalog.md` | アプローチカタログ（Phase 0 knowledge 初期化時） |
| SKILL.md | 149 | `.claude/skills/agent_bench/approach-catalog.md` | アプローチカタログ（Phase 1A） |
| SKILL.md | 150 | `.claude/skills/agent_bench/proven-techniques.md` | 実証済みテクニック（Phase 1A） |
| SKILL.md | 168 | `.claude/skills/agent_bench/approach-catalog.md` | アプローチカタログ（Phase 1B Deep モード時のみ条件付き） |
| SKILL.md | 169 | `.claude/skills/agent_bench/proven-techniques.md` | 実証済みテクニック（Phase 1B） |
| SKILL.md | 184 | `.claude/skills/agent_bench/test-document-guide.md` | テスト文書生成ガイド（Phase 2） |
| SKILL.md | 249 | `.claude/skills/agent_bench/scoring-rubric.md` | 採点基準（Phase 4） |
| SKILL.md | 272 | `.claude/skills/agent_bench/scoring-rubric.md` | 採点基準（Phase 5） |
| SKILL.md | 336 | `.claude/skills/agent_bench/proven-techniques.md` | 実証済みテクニック（Phase 6B） |
| templates/phase1b-variant-generation.md | 14 | `.claude/skills/agent_bench/approach-catalog.md` | Deep モード時の条件付き参照 |

**パス命名の不一致**: SKILL.md 内で `.claude/skills/agent_bench/` を参照しているが、実際のスキルパスは `.claude/skills/agent_bench_new/`。これは外部参照が機能しない構造的問題。

## D. コンテキスト予算分析
- SKILL.md 行数: 370行
- テンプレートファイル数: 13個、平均行数: 48行（最小13行、最大106行）
- サブエージェント委譲: あり（以下のパターン）
  - Phase 0: knowledge 初期化（1サブエージェント、sonnet）、perspective 自動生成（1+4並列、sonnet）
  - Phase 1A: バリアント生成（1サブエージェント、sonnet）
  - Phase 1B: バリアント生成（1サブエージェント、sonnet）
  - Phase 2: テスト文書生成（1サブエージェント、sonnet）
  - Phase 3: 評価実行（N×2並列、N=プロンプト数、sonnet）
  - Phase 4: 採点（N並列、sonnet）
  - Phase 5: 分析レポート（1サブエージェント、sonnet）
  - Phase 6: デプロイ（1サブエージェント、haiku）、ナレッジ更新（2並列、sonnet）
- 親コンテキストに保持される情報: agent_path, agent_name, perspective 解決状態、累計ラウンド数、Phase 5 の7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
- 3ホップパターンの有無: なし（Phase 5 の7行サマリが Phase 6A に渡されるが、Phase 6A は report ファイルを直接 Read するため実質2ホップ）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が空/不足時の要件ヒアリング（自動生成の場合） | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の再試行/除外/中断選択 | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の再試行/除外/中断選択 | 不明 |
| Phase 6 | AskUserQuestion | プロンプト選択（推奨情報+過去スコア推移を提示） | 不明 |
| Phase 6 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - エージェント定義ファイル（agent_path）: 読み込み失敗時はエラー出力して終了
  - perspective-source.md: フォールバック検索 → 自動生成
  - knowledge.md: 初期化して Phase 1A へ
  - audit-dim1/dim2: 空文字列を渡す（Phase 1B）
  - perspective 参照ファイル: 空とする（Phase 0 自動生成時）
- サブエージェント失敗時:
  - perspective 検証失敗（Step 6）: エラー出力してスキル終了
  - Phase 3 評価失敗: 成功数を集計し、全プロンプトに最低1回の成功結果があれば警告して Phase 4 へ、いずれかのプロンプトで0回なら AskUserQuestion で再試行/除外/中断を確認
  - Phase 4 採点失敗: AskUserQuestion で再試行/除外/中断を確認（ベースライン失敗時は中断）
- 部分完了時:
  - Phase 3: 各プロンプトに最低1回の成功結果があれば Phase 4 へ進む（Run が1回のみのプロンプトは SD = N/A）
  - Phase 4: 成功したプロンプトのみで Phase 5 へ進む（ベースライン失敗時は中断）
- 入力バリデーション: agent_path 未指定時のみ AskUserQuestion で確認。それ以外は未定義

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (knowledge 初期化) | sonnet | templates/knowledge-init-template.md | 1行（確認メッセージ） | 1 |
| Phase 0 (perspective 初期生成) | sonnet | templates/perspective/generate-perspective.md | 4行サマリ | 1 |
| Phase 0 (perspective 批評) | sonnet | templates/perspective/critic-{4種}.md | 批評結果（行数不定） | 4並列 |
| Phase 0 (perspective 再生成) | sonnet | templates/perspective/generate-perspective.md | 4行サマリ | 1（条件付き） |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 構造分析+バリアント情報（行数不定） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 選定プロセス+バリアント情報（行数不定） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 問題サマリ（10-15行） | 1 |
| Phase 3 | sonnet | インラインプロンプト（4ステップ指示） | 1行（保存完了） | N×2並列（N=プロンプト数） |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行スコアサマリ | N並列 |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行サマリ | 1 |
| Phase 6 (デプロイ) | haiku | インラインプロンプト（3ステップ指示） | 1行（確認メッセージ） | 1（条件付き） |
| Phase 6A | sonnet | templates/phase6a-knowledge-update.md | 1行（確認メッセージ） | 1 |
| Phase 6B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（確認メッセージ） | 1 |
