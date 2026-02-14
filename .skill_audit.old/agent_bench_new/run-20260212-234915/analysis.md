# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 372 | メインワークフロー定義（Phase 0-6の詳細手順） |
| approach-catalog.md | 202 | 改善アプローチカタログ（S/C/N/M 4カテゴリ、バリエーション階層） |
| scoring-rubric.md | 70 | 採点基準（検出判定○△×、スコア計算式、推奨判定、収束判定） |
| test-document-guide.md | 254 | テスト対象文書生成ガイド（入力型判定、問題埋め込み、正解キー形式） |
| proven-techniques.md | 70 | エージェント横断の実証済み知見（効果テクニック、アンチパターン、条件付き、ベースライン構築ガイド） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート（バリエーションステータステーブル構築） |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回ベースライン作成＋バリアント生成（構造分析→ギャップベース選定） |
| templates/phase1b-variant-generation.md | 33 | Phase 1B: 継続バリアント生成（Broad/Deep モード、audit 統合） |
| templates/phase2-test-document.md | 33 | Phase 2: テスト入力文書＋正解キー生成（ドメイン多様性、問題埋め込み） |
| templates/phase4-scoring.md | 13 | Phase 4: 採点実行（検出判定○△×、ボーナス/ペナルティ、スコアサマリ） |
| templates/phase5-analysis-report.md | 22 | Phase 5: 比較レポート生成（推奨判定、収束判定、7行サマリ） |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A: knowledge.md 更新（効果テーブル、バリエーションステータス、一般化原則） |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B: proven-techniques.md 更新（昇格条件、preserve+integrate、サイズ制限） |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成（必須スキーマ、入力型判定、問題バンク構築） |
| templates/perspective/critic-completeness.md | 107 | perspective 批評: 網羅性＋欠落検出能力（missing element detection） |
| templates/perspective/critic-clarity.md | 76 | perspective 批評: 表現明確性＋AI動作一貫性 |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評: 寄与度＋他観点との境界明確性 |
| templates/perspective/critic-generality.md | 82 | perspective 批評: 汎用性＋業界依存性フィルタ |
| perspectives/design/security.md | 43 | 参照 perspective: セキュリティ（設計レビュー） |
| perspectives/design/consistency.md | （未読） | 参照 perspective |
| perspectives/design/structural-quality.md | （未読） | 参照 perspective |
| perspectives/design/performance.md | （未読） | 参照 perspective |
| perspectives/design/reliability.md | （未読） | 参照 perspective |
| perspectives/code/security.md | 38 | 参照 perspective: セキュリティ（実装レビュー） |
| perspectives/code/best-practices.md | （未読） | 参照 perspective |
| perspectives/code/consistency.md | （未読） | 参照 perspective |
| perspectives/code/maintainability.md | （未読） | 参照 perspective |
| perspectives/code/performance.md | （未読） | 参照 perspective |
| perspectives/design/old/best-practices.md | （未読） | 旧 perspective（old ディレクトリ） |
| perspectives/design/old/maintainability.md | （未読） | 旧 perspective（old ディレクトリ） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 → (1B に戻る or 終了)
- 各フェーズの目的:
  - **Phase 0**: 初期化・状態検出（エージェント読込 → agent_name 導出 → perspective 解決/生成 → knowledge.md 検出 → 初回/継続判定）
  - **Phase 1A**: 初回ベースライン作成＋バリアント生成（構造分析 → ギャップベース選定 → proven-techniques 参照）
  - **Phase 1B**: 継続バリアント生成（knowledge.md のバリエーションステータステーブルで Broad/Deep モード判定 → UNTESTED/EFFECTIVE 選定 → audit 統合）
  - **Phase 2**: テスト入力文書＋正解キー生成（入力型判定 → ドメイン多様性 → 問題埋め込み8-10個 → 検出判定基準○△×）
  - **Phase 3**: 並列評価実行（各プロンプト × 2回並列実行 → 成功数集計 → 失敗時の再試行/除外/中断分岐）
  - **Phase 4**: 採点（各プロンプトに1サブエージェント → 検出判定○△× → ボーナス/ペナルティ → スコアサマリ）
  - **Phase 5**: 分析・推奨判定・レポート作成（推奨判定基準・収束判定適用 → 7行サマリ）
  - **Phase 6**: プロンプト選択・デプロイ・次アクション（Step 1: ユーザー選択＋デプロイ → Step 2A: knowledge 更新 → Step 2B 並列: proven-techniques 更新 + 次アクション選択）
- データフロー:
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md` 生成
  - Phase 1A/1B → `prompts/v{NNN}-*.md` 生成
  - Phase 2 → `test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md` 生成
  - Phase 3 → `results/v{NNN}-{name}-run{R}.md` 生成
  - Phase 4 → `results/v{NNN}-{name}-scoring.md` 生成
  - Phase 5 → `reports/round-{NNN}-comparison.md` 生成（7行サマリは Phase 6 で使用）
  - Phase 6A → `knowledge.md` 更新（Phase 6B で参照）
  - Phase 6B → `proven-techniques.md` 更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | perspective フォールバック検索（パターンマッチによる既存 perspective 検出） |
| SKILL.md | 74 | `.claude/skills/agent_bench/perspectives/design/*.md` | perspective 自動生成時の参照 perspective 収集 |
| SKILL.md | 81 | `.claude/skills/agent_bench/templates/perspective/generate-perspective.md` | perspective 自動生成テンプレート |
| SKILL.md | 92-95 | `.claude/skills/agent_bench/templates/perspective/critic-*.md` | perspective 批評テンプレート（4並列） |
| SKILL.md | 124 | `.claude/skills/agent_bench/templates/knowledge-init-template.md` | knowledge.md 初期化テンプレート |
| SKILL.md | 128 | `.claude/skills/agent_bench/approach-catalog.md` | approach-catalog 参照（Phase 1A/1B） |
| SKILL.md | 146 | `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` | Phase 1A テンプレート |
| SKILL.md | 151 | `.claude/skills/agent_bench/proven-techniques.md` | proven-techniques 参照（Phase 1A/1B） |
| SKILL.md | 165 | `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` | Phase 1B テンプレート |
| SKILL.md | 174 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit 分析結果統合（Phase 1B） |
| SKILL.md | 184 | `.claude/skills/agent_bench/templates/phase2-test-document.md` | Phase 2 テンプレート |
| SKILL.md | 186 | `.claude/skills/agent_bench/test-document-guide.md` | テスト対象文書生成ガイド |
| SKILL.md | 249 | `.claude/skills/agent_bench/templates/phase4-scoring.md` | Phase 4 テンプレート |
| SKILL.md | 251 | `.claude/skills/agent_bench/scoring-rubric.md` | 採点基準（Phase 4/5） |
| SKILL.md | 272 | `.claude/skills/agent_bench/templates/phase5-analysis-report.md` | Phase 5 テンプレート |
| SKILL.md | 324 | `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` | Phase 6A テンプレート |
| SKILL.md | 336 | `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` | Phase 6B テンプレート |

**注**: 全ての外部参照が `.claude/skills/agent_bench/` を指しているが、実際のスキルディレクトリは `.claude/skills/agent_bench_new/` である。これはパス不整合のバグの可能性がある。

## D. コンテキスト予算分析
- SKILL.md 行数: 372行
- テンプレートファイル数: 13個、平均行数: 45.2行
- サブエージェント委譲: あり（Phase 0/1A/1B/2/4/5/6A/6B で委譲）
- 親コンテキストに保持される情報:
  - エージェントパス、agent_name、perspective パス
  - Phase 1/2/4/5/6A/6B のサブエージェント返答（コンパクトサマリのみ）
  - Phase 3 の評価完了数（ファイルパスは保持しない）
  - Phase 5 の7行サマリ（Phase 6 で使用）
  - ラウンド番号（NNN）
- 3ホップパターンの有無: なし（全てファイル経由で委譲）
  - 例: Phase 1 → prompts/ 保存 → Phase 3 が読込
  - 例: Phase 4 → scoring ファイル保存 → Phase 5 が読込
  - 例: Phase 5 → report 保存 → Phase 6A/6B が読込

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が実質空の場合の要件ヒアリング | 不明 |
| Phase 3 | AskUserQuestion | いずれかのプロンプトで成功結果が0回の場合の再試行/除外/中断選択 | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の再試行/除外/中断選択 | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（推奨/代替を提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - エージェントファイル読込失敗: エラー出力して終了（Phase 0）
  - perspective 未検出: 自動生成（Phase 0）
  - knowledge.md 不在: 初期化して Phase 1A へ（Phase 0）
  - reference_perspective 不在: 空として処理（Phase 0 perspective 自動生成）
  - perspective 検証失敗: エラー出力して終了（Phase 0）
- サブエージェント失敗時:
  - Phase 3 評価失敗: 成功数集計 → 条件分岐（全失敗/一部失敗で AskUserQuestion 確認）
  - Phase 4 採点失敗: AskUserQuestion で再試行/除外/中断選択
  - Phase 0/1/2/5/6 の失敗: 明示的な処理記載なし（暗黙的にエラー伝播と推測）
- 部分完了時:
  - Phase 3: 各プロンプトに最低1回の成功結果があれば Phase 4 へ進む（SD=N/A 扱い）
  - Phase 4: ベースラインが失敗した場合は中断（明示的記載あり）
- 入力バリデーション:
  - agent_path 未指定: AskUserQuestion で確認（Phase 0）
  - agent_name 導出: ルールベース（`.claude/` 配下 or それ以外）
  - エージェント定義が実質空: AskUserQuestion で要件ヒアリング（Phase 0）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0: perspective 自動生成 Step 3 | sonnet | templates/perspective/generate-perspective.md | 4行（観点名、入力型、評価スコープ、問題バンク件数） | 1 |
| Phase 0: perspective 批評 Step 4 | sonnet | templates/perspective/critic-*.md（4種） | 形式自由（批評結果） | 4（並列） |
| Phase 0: perspective 再生成 Step 5 | sonnet | templates/perspective/generate-perspective.md | 4行（同上） | 1（条件付き） |
| Phase 0: knowledge.md 初期化 | sonnet | templates/knowledge-init-template.md | 1行（「knowledge.md 初期化完了（バリエーション数: {N}）」） | 1（条件付き） |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 複数セクション（エージェント定義、構造分析、バリアント一覧） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 複数セクション（選定プロセス、バリアント一覧） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 複数セクション（テスト対象文書サマリ、埋め込み問題一覧、ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | （テンプレートなし、直接指示） | 1行（「保存完了: {result_path}」） | (ベースライン1 + バリアント数) × 2回 |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（スコアサマリ） | プロンプト数 |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1: デプロイ | haiku | （テンプレートなし、直接指示） | 1行（「デプロイ完了: {agent_path}」） | 1（条件付き） |
| Phase 6 Step 2A | sonnet | templates/phase6a-knowledge-update.md | 1行（「knowledge.md 更新完了（累計ラウンド数: {N}）」） | 1 |
| Phase 6 Step 2B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（「proven-techniques.md 更新完了 or 更新なし」） | 1 |
