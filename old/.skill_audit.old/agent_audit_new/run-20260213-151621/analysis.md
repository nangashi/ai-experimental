# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 447 | スキルのメインワークフロー定義（Phase 0-6）、パス変数の導出ルール、サブエージェント委譲パターン |
| approach-catalog.md | 202 | 改善アプローチカタログ（4カテゴリ×複数テクニック×バリエーション）、実証済みテクニックのマーカー、共通ルール |
| scoring-rubric.md | 70 | 採点基準（検出判定○△×、スコア計算式、安定性閾値、推奨判定基準、収束判定） |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック（Tier 1-3、アンチパターン、ベースライン構築ガイド）、Phase 6B で自動更新 |
| test-document-guide.md | 254 | テスト文書生成ガイド（入力型判定、文書構成、問題埋め込み、正解キー形式、ラウンド間多様性） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート（バリエーションステータステーブル、スコア推移テーブル） |
| templates/phase1a-variant-generation.md | 29 | Phase 1A（初回）バリアント生成テンプレート（ベースライン構築、2バリアント生成） |
| templates/phase1b-variant-generation.md | 33 | Phase 1B（継続）バリアント生成テンプレート（Deep/Broad モード、audit 結果参照、枯渇処理） |
| templates/phase2-test-document.md | 17 | Phase 2 テスト文書生成テンプレート（入力型判定、問題埋め込み、正解キー生成） |
| templates/phase3-evaluation.md | 12 | Phase 3 評価実行テンプレート（プロンプトに従ってタスク実行、結果保存） |
| templates/phase4-scoring.md | 13 | Phase 4 採点テンプレート（検出判定、スコア計算、詳細結果保存） |
| templates/phase5-analysis-report.md | 27 | Phase 5 分析・推奨判定テンプレート（比較レポート作成、推奨判定、収束判定、7行サマリ） |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A ナレッジ更新テンプレート（knowledge.md 更新、効果テーブル・ステータステーブル・スコア推移更新） |
| templates/phase6b-proven-techniques-update.md | 53 | Phase 6B スキル知見フィードバックテンプレート（proven-techniques.md 更新、Tier 昇格ルール、サイズ制限） |
| templates/perspective/generate-perspective.md | 68 | パースペクティブ生成テンプレート（必須スキーマ、生成ガイドライン、入力型別問題バンク） |
| templates/perspective/critic-completeness.md | 101 | パースペクティブ批評：網羅性（スコープカバレッジ、欠落要素検出能力、問題バンク品質） |
| templates/perspective/critic-clarity.md | 67 | パースペクティブ批評：明確性（表現の曖昧性、AI動作一貫性、実行可能性） |
| templates/perspective/critic-effectiveness.md | 46 | パースペクティブ批評：有効性（寄与度分析、境界明確性、既存観点との重複検証） |
| templates/perspective/critic-generality.md | 61 | パースペクティブ批評：汎用性（業界依存性、規制依存性、技術スタック依存性、汎用化戦略） |
| perspectives/code/maintainability.md | - | 未読 |
| perspectives/code/security.md | - | 未読 |
| perspectives/code/performance.md | - | 未読 |
| perspectives/code/best-practices.md | - | 未読 |
| perspectives/code/consistency.md | - | 未読 |
| perspectives/design/consistency.md | - | 未読 |
| perspectives/design/security.md | - | 未読 |
| perspectives/design/structural-quality.md | - | 未読 |
| perspectives/design/old/maintainability.md | - | 未読 |
| perspectives/design/old/best-practices.md | - | 未読 |
| perspectives/design/performance.md | - | 未読 |
| perspectives/design/reliability.md | - | 未読 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → (1A or 1B) → 2 → 3 → 4 → 5 → 6 → (ループまたは終了)
- 各フェーズの目的:
  - Phase 0: エージェントファイル読み込み、agent_name 導出、perspective 解決/生成、knowledge.md 初期化、初回/継続判定
  - Phase 1A: ベースライン作成+2バリアント生成（初回。proven-techniques ベースライン構築ガイド適用）
  - Phase 1B: ベースラインコピー+2バリアント生成（継続。Deep/Broad モード、audit 結果参照、枯渇処理）
  - Phase 2: テスト入力文書+正解キー生成（毎ラウンド。入力型判定、問題埋め込み、ドメイン多様性確保）
  - Phase 3: 並列評価実行（全プロンプト×2回、成功数判定、失敗時再試行/除外/中断）
  - Phase 4: 採点（並列。検出判定○△×、スコア計算、詳細結果保存）
  - Phase 5: 分析・推奨判定・レポート作成（比較レポート、推奨判定、収束判定、7行サマリ）
  - Phase 6: プロンプト選択・デプロイ（Step 1: AskUserQuestion+デプロイ）、ナレッジ更新・スキル知見フィードバック（Step 2A/2B 並列）、次アクション選択（Step 2C: AskUserQuestion）

- データフロー:
  - Phase 0 → perspective-source.md, perspective.md, knowledge.md を生成/読み込み → 1A/1B へ分岐
  - Phase 1A/1B → prompts/v{NNN}-*.md を生成 → Phase 2
  - Phase 2 → test-document-round-{NNN}.md, answer-key-round-{NNN}.md を生成 → Phase 3
  - Phase 3 → results/v{NNN}-{name}-run{R}.md を生成 → Phase 4
  - Phase 4 → results/v{NNN}-{name}-scoring.md を生成、7行サマリ返答 → Phase 5
  - Phase 5 → reports/round-{NNN}-comparison.md を生成、7行サマリ返答 → Phase 6
  - Phase 6 Step 1 → デプロイ対象を {agent_path} に上書き保存
  - Phase 6 Step 2A → knowledge.md を更新（効果テーブル、ステータステーブル、スコア推移、最新サマリ、一般化原則）
  - Phase 6 Step 2B → proven-techniques.md を更新（Tier 昇格、既存エントリマージ、サイズ制限）
  - Phase 6 Step 2C → 次ラウンドまたは終了判定

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 30 | `.claude/skills/agent_bench_new/proven-techniques.md` | エージェント横断の実証済みテクニック参照 |
| SKILL.md | 71 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | reviewer パターンのフォールバック perspective 参照 |
| SKILL.md | 104 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | perspective 自動生成時の参照データ収集 |
| SKILL.md | 110 | `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` | perspective 生成テンプレート |
| SKILL.md | 121-134 | `.claude/skills/agent_bench_new/templates/perspective/critic-*.md` | 4並列批評テンプレート |
| SKILL.md | 152 | `.claude/skills/agent_bench_new/proven-techniques.md` | proven-techniques.md 初期化処理 |
| SKILL.md | 189 | `.claude/skills/agent_bench_new/templates/knowledge-init-template.md` | knowledge.md 初期化テンプレート |
| SKILL.md | 208 | `.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md` | Phase 1A テンプレート |
| SKILL.md | 214 | `.claude/skills/agent_bench_new/approach-catalog.md` | アプローチカタログ参照（1A） |
| SKILL.md | 215 | `.claude/skills/agent_bench_new/proven-techniques.md` | 実証済みテクニック参照（1A） |
| SKILL.md | 228 | `.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md` | Phase 1B テンプレート |
| SKILL.md | 234 | `.claude/skills/agent_bench_new/approach-catalog.md` | アプローチカタログ参照（1B Deep モード時のみ） |
| SKILL.md | 235 | `.claude/skills/agent_bench_new/proven-techniques.md` | 実証済みテクニック参照（1B） |
| SKILL.md | 237-238 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit スキルの分析結果参照（外部スキル依存） |
| SKILL.md | 256 | `.claude/skills/agent_bench_new/templates/phase2-test-document.md` | Phase 2 テンプレート |
| SKILL.md | 258 | `.claude/skills/agent_bench_new/test-document-guide.md` | テスト文書生成ガイド |
| SKILL.md | 285 | `.claude/skills/agent_bench_new/templates/phase3-evaluation.md` | Phase 3 テンプレート |
| SKILL.md | 316 | `.claude/skills/agent_bench_new/templates/phase4-scoring.md` | Phase 4 テンプレート |
| SKILL.md | 317 | `.claude/skills/agent_bench_new/scoring-rubric.md` | 採点基準参照 |
| SKILL.md | 338 | `.claude/skills/agent_bench_new/templates/phase5-analysis-report.md` | Phase 5 テンプレート |
| SKILL.md | 384 | `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` | Phase 6A テンプレート |
| SKILL.md | 393 | `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` | Phase 6B テンプレート |

**外部スキル依存**:
- `.agent_audit/{agent_name}/` は agent_audit スキルが生成するディレクトリ。agent_bench_new は agent_audit の後に実行することを推奨（SKILL.md 240行目に明記）

## D. コンテキスト予算分析
- SKILL.md 行数: 447行
- テンプレートファイル数: 14個、平均行数: 43.4行（範囲: 12-101行）
- サブエージェント委譲: あり（Phase 0, 1A, 1B, 2, 3, 4, 5, 6A, 6B で委譲）
- 親コンテキストに保持される情報:
  - agent_path, agent_name, agent_exists の導出結果
  - perspective_source_path, perspective_path のパス（内容は Phase 単位で読み込み）
  - knowledge.md の存在判定結果（内容は Phase 単位で読み込み）
  - Phase 5 の7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 6 Step 1 の deployed_prompt_name
  - 累計ラウンド数（knowledge.md から抽出）
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しはファイル経由。親は各 Phase の完了確認とパス変数の受け渡しのみ行う）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | perspective-source.md 不完全時の再生成確認 | 不明 |
| Phase 0 | AskUserQuestion | perspective 自動生成時のヒアリング（エージェント定義が空または不足の場合） | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の再試行/除外/中断確認 | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の再試行/除外/中断確認 | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（推奨情報付き） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | デプロイ最終確認（不可逆操作） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読み込み失敗 → agent_exists = false として新規エージェント生成モードで継続（エラー終了しない）
  - perspective-source.md 不在 → reviewer パターンのフォールバック → 自動生成（4並列批評+再生成1回）
  - knowledge.md 不在 → 初期化テンプレートで自動生成
  - proven-techniques.md 不在 → 初期内容を自動生成
  - audit-*.md 不在 → 空文字列として扱い、knowledge.md の知見のみでバリアント生成
- サブエージェント失敗時:
  - perspective 生成失敗 → 1回再試行。2回とも失敗 → エラー出力して終了
  - Phase 3 評価失敗（一部）→ 成功結果があるプロンプトのみで継続 or 再試行 or 中断（AskUserQuestion で確認）
  - Phase 3 評価失敗（全失敗）→ 再試行 or プロンプト除外 or 中断（AskUserQuestion で確認）
  - Phase 4 採点失敗 → 再試行 or 失敗プロンプト除外 or 中断（AskUserQuestion で確認。ベースライン失敗時は中断）
- 部分完了時:
  - Phase 3 で Run2 失敗、Run1 成功 → SD = N/A として Phase 4/5 続行
  - Deep モード枯渇（EFFECTIVE カテゴリの全バリエーション TESTED） → Broad モードにフォールバック
  - 全カテゴリ全バリエーション TESTED → EFFECTIVE カテゴリの最高スコアバリエーションを RE-TESTED として再テスト
- 入力バリデーション:
  - perspective-source.md の必須セクション検証（Phase 0 Step 6）。欠落時は AskUserQuestion で削除/使用/中断を確認
  - perspective 自動生成後の必須セクション検証。欠落時はエラー出力して終了

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0: perspective 生成 | sonnet | templates/perspective/generate-perspective.md | 4行（観点/入力型/評価スコープ/問題バンク件数） | 1 |
| Phase 0: perspective 批評 | sonnet | templates/perspective/critic-{completeness,clarity,effectiveness,generality}.md | 1行（重大な問題: {N}件） | 4並列 |
| Phase 0: knowledge 初期化 | sonnet | templates/knowledge-init-template.md | 1行（バリエーション数） | 1 |
| Phase 1A: バリアント生成 | sonnet | templates/phase1a-variant-generation.md | 1行（生成完了: 3バリアント） | 1 |
| Phase 1B: バリアント生成 | sonnet | templates/phase1b-variant-generation.md | 1行（生成完了: 3バリアント） | 1 |
| Phase 2: テスト文書生成 | sonnet | templates/phase2-test-document.md | 1行（埋め込み問題: {N}件, ボーナス: {M}件） | 1 |
| Phase 3: 評価実行 | sonnet | templates/phase3-evaluation.md | 1行（保存完了: {result_path}） | (ベースライン1 + バリアント2) × 2回 = 6並列 |
| Phase 4: 採点 | sonnet | templates/phase4-scoring.md | 2行（Mean/SD、Run1/Run2詳細） | ベースライン1 + バリアント2 = 3並列 |
| Phase 5: 分析・推奨判定 | sonnet | templates/phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1: デプロイ | haiku | インライン指示（Benchmark Metadata 除去、上書き保存） | 1行（デプロイ完了: {agent_path}） | 1 |
| Phase 6 Step 2A: knowledge 更新 | sonnet | templates/phase6a-knowledge-update.md | 1行（累計ラウンド数） | 1（並列起動） |
| Phase 6 Step 2B: proven-techniques 更新 | sonnet | templates/phase6b-proven-techniques-update.md | 1行（promoted/updated/skipped件数 or 更新なし） | 1（並列起動） |
