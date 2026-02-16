# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 376 | スキル本体。Phase 0-6 のワークフロー定義、コンテキスト節約原則、サブエージェント委譲仕様 |
| approach-catalog.md | 202 | 改善アプローチカタログ。カテゴリ→テクニック→バリエーション の3階層管理 |
| scoring-rubric.md | 70 | 採点基準。検出判定（○/△/×）、スコア計算式、安定性閾値、推奨判定基準、収束判定 |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込み、正解キー形式 |
| proven-techniques.md | 70 | 実証済みテクニック。エージェント横断知見、効果データ、アンチパターン、ベースライン構築ガイド |
| templates/knowledge-init-template.md | 61 | knowledge.md 初期化テンプレート。バリエーションステータステーブル作成 |
| templates/phase1a-variant-generation.md | 42 | Phase 1A: ベースライン作成+バリアント生成（初回）。6次元構造分析 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B: 知見ベースバリアント生成（継続）。Broad/Deep モード選定 |
| templates/phase2-test-document.md | 33 | Phase 2: テスト対象文書+正解キー生成。問題埋め込み |
| templates/phase4-scoring.md | 13 | Phase 4: 採点実行。検出判定+ボーナス/ペナルティ |
| templates/phase5-analysis-report.md | 22 | Phase 5: 比較レポート作成+推奨判定。7行サマリ返答 |
| templates/phase6a-knowledge-update.md | 27 | Phase 6A: knowledge.md 更新。効果テーブル+バリエーションステータス更新 |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B: proven-techniques.md 更新。Tier 1-3 昇格条件、統合ルール |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成。必須スキーマ+生成ガイドライン |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評: 有効性。品質寄与度+境界明確性 |
| templates/perspective/critic-completeness.md | 107 | perspective 批評: 完全性。網羅性+欠落検出能力（missing element detection） |
| templates/perspective/critic-clarity.md | 76 | perspective 批評: 明確性。表現曖昧性+AI動作一貫性 |
| templates/perspective/critic-generality.md | 82 | perspective 批評: 汎用性。業界依存性フィルタ |
| perspectives/code/maintainability.md | 未読 | code 用 perspective テンプレート |
| perspectives/code/security.md | 未読 | code 用 perspective テンプレート |
| perspectives/code/performance.md | 未読 | code 用 perspective テンプレート |
| perspectives/code/best-practices.md | 34 | code 用 perspective テンプレート（SOLID、DRY、エラー処理、テスト品質） |
| perspectives/code/consistency.md | 未読 | code 用 perspective テンプレート |
| perspectives/design/old/maintainability.md | 未読 | 非推奨（old/ ディレクトリ） |
| perspectives/design/old/best-practices.md | 未読 | 非推奨（old/ ディレクトリ） |
| perspectives/design/consistency.md | 未読 | design 用 perspective テンプレート |
| perspectives/design/security.md | 43 | design 用 perspective テンプレート（STRIDE、認証認可、データ保護） |
| perspectives/design/structural-quality.md | 未読 | design 用 perspective テンプレート |
| perspectives/design/performance.md | 未読 | design 用 perspective テンプレート |
| perspectives/design/reliability.md | 未読 | design 用 perspective テンプレート |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1A/1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
- 各フェーズの目的:
  - Phase 0: 初期化・状態検出。エージェント読み込み、agent_name 導出、perspective 解決（検索/自動生成）、knowledge.md 存在確認で Phase 1A/1B 分岐
  - Phase 1A: 初回専用。ベースライン作成+6次元構造分析+2バリアント生成（proven-techniques 参照）
  - Phase 1B: 継続専用。knowledge.md のバリエーションステータスから Broad/Deep モード選定+2バリアント生成（audit 結果参照可能）
  - Phase 2: テスト対象文書+正解キー生成（毎ラウンド）。問題埋め込み（8-10問、深刻度分布）
  - Phase 3: 並列評価実行。各プロンプト×2回実行（全サブエージェント同時起動）
  - Phase 4: 採点（サブエージェント並列）。検出判定（○/△/×）+ボーナス/ペナルティ
  - Phase 5: 分析・推奨判定・レポート作成（サブエージェント）。7行サマリ返答
  - Phase 6: プロンプト選択・デプロイ（親）+ ナレッジ更新（6A）+ スキル知見フィードバック（6B）+ 次アクション選択（親）
- データフロー:
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md` 生成
  - Phase 1A/1B → `prompts/v{NNN}-baseline.md`, `prompts/v{NNN}-variant-*.md` 生成、knowledge.md の構造分析スナップショット更新
  - Phase 2 → `test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md` 生成
  - Phase 3 → `results/v{NNN}-{name}-run{1,2}.md` 生成
  - Phase 4 → `results/v{NNN}-{name}-scoring.md` 生成
  - Phase 5 → `reports/round-{NNN}-comparison.md` 生成、7行サマリを親に返答
  - Phase 6 → デプロイ（選択プロンプト → agent_path）、knowledge.md 更新、proven-techniques.md 更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 58 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | Phase 0: reviewer パターンのフォールバック用 perspective ファイル検索。SKILL.md 外のスキルディレクトリ（agent_bench）への参照 |
| SKILL.md | 79 | `.claude/skills/agent_bench/perspectives/design/*.md` | Phase 0: perspective 自動生成時の参照用既存 perspective 検索 |
| SKILL.md | 131 | `.claude/skills/agent_bench/approach-catalog.md` | Phase 0: knowledge 初期化時のアプローチカタログ参照 |
| SKILL.md | 155 | `.claude/skills/agent_bench/proven-techniques.md` | Phase 1A: ベースライン構築ガイド参照 |
| SKILL.md | 177 | `.claude/skills/agent_bench/proven-techniques.md` | Phase 1B: アンチパターン回避参照 |
| SKILL.md | 190 | `.claude/skills/agent_bench/test-document-guide.md` | Phase 2: テスト文書生成ガイド参照 |
| SKILL.md | 254 | `.claude/skills/agent_bench/scoring-rubric.md` | Phase 4: 採点基準参照 |
| SKILL.md | 278 | `.claude/skills/agent_bench/scoring-rubric.md` | Phase 5: 推奨判定基準参照 |
| SKILL.md | 342 | `.claude/skills/agent_bench/proven-techniques.md` | Phase 6B: スキル知見フィードバック |

外部参照の特徴: 全て `.claude/skills/agent_bench/` への参照。スキル名は `agent_bench_new` だが、参照先は `agent_bench`（旧バージョンまたは共有リソース）。perspectives/ ディレクトリのみ agent_bench_new 内に存在し、他の参照ファイル（approach-catalog.md, scoring-rubric.md, test-document-guide.md, proven-techniques.md）は agent_bench_new 内に同名ファイルが存在する。

## D. コンテキスト予算分析
- SKILL.md 行数: 376行
- テンプレートファイル数: 13個、平均行数: 約51行（範囲: 13〜107行）
- サブエージェント委譲: あり（7箇所）
  - Phase 0: knowledge 初期化（model: sonnet）、perspective 生成（model: sonnet, 1回+再生成1回）、perspective 批評4並列（model: sonnet）
  - Phase 1A/1B: バリアント生成（model: sonnet）
  - Phase 2: テスト文書生成（model: sonnet）
  - Phase 3: 並列評価実行（model: sonnet, プロンプト数×2回）
  - Phase 4: 採点（model: sonnet, プロンプト数並列）
  - Phase 5: 分析レポート（model: sonnet）
  - Phase 6: デプロイ（model: haiku）、ナレッジ更新（model: sonnet）、スキル知見フィードバック（model: sonnet）
- 親コンテキストに保持される情報:
  - agent_path, agent_name（Phase 0 で導出、全フェーズで使用）
  - perspective_source_path, perspective_path（Phase 0 で保存、Phase 1A/1B/2 で参照）
  - knowledge_path, prompts_dir（Phase 0 で決定、Phase 1-6 で使用）
  - 累計ラウンド数（knowledge.md から読み取り、ファイル名生成に使用）
  - Phase 5 サブエージェントの7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 4 の採点結果パスリスト（Phase 5 に渡す）
- 3ホップパターンの有無: なし
  - Phase 1-6 の全サブエージェントはファイル経由でデータを受け渡す
  - 親は各サブエージェントへのパス変数を指定するのみ（中継しない）
  - Phase 5 の7行サマリのみ親が保持し、Phase 6A に渡すが、これは要約メタデータであり大量コンテンツの中継ではない

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が実質空または不足時のヒアリング（目的・役割、入出力、ツール・制約） | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の確認（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の確認（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（推奨プロンプトにマーク付き） | 不明 |
| Phase 6 Step 2-C | AskUserQuestion | 次アクション選択（次ラウンド/終了。収束判定・累計ラウンド数による目安表示） | 不明 |

Fast mode 記載: SKILL.md 内に fast mode に関する明示的な記載なし。MEMORY.md には「fastモードで中間確認をスキップ可能に」とあるが、SKILL.md には実装されていない。

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読み込み失敗: エラー出力して終了（Phase 0）
  - perspective-source.md 不在: 自動生成へフォールバック（Phase 0）
  - knowledge.md 不在: 初期化して Phase 1A へ（Phase 0）
  - knowledge.md 存在: Phase 1B へ（Phase 0）
- サブエージェント失敗時:
  - Phase 3 評価失敗（部分）: 警告出力し Phase 4 へ進む（成功 Run のみ採点）。いずれかのプロンプトで成功結果が0回: AskUserQuestion で確認（再試行/除外/中断）
  - Phase 3 評価失敗（全て）: AskUserQuestion で確認（再試行/除外/中断）
  - Phase 4 採点失敗（一部）: AskUserQuestion で確認（再試行/除外/中断）。ベースライン失敗時は中断
  - Phase 4 採点失敗（全て）: AskUserQuestion で確認（再試行/除外/中断）
  - perspective 自動生成検証失敗: エラー出力してスキル終了（Phase 0 Step 6）
- 部分完了時:
  - Phase 3 で一部プロンプトが失敗: 成功したプロンプトのみで Phase 4 以降を継続可能（ユーザー選択により）
  - Phase 4 で一部プロンプトが失敗: 成功したプロンプトのみで Phase 5 以降を継続可能（ベースライン失敗時は除く）
- 入力バリデーション:
  - agent_path 未指定: AskUserQuestion で確認（Phase 0）
  - perspective 必須セクション欠如: 検証失敗として終了（Phase 0）
  - その他の入力バリデーション: 未定義（テンプレート内で各サブエージェントが実施すると推測されるが、SKILL.md には明示なし）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (knowledge 初期化) | sonnet | knowledge-init-template.md | 1 | 1 |
| Phase 0 (perspective 生成) | sonnet | perspective/generate-perspective.md | 4 | 1（初回）+1（再生成） |
| Phase 0 (perspective 批評) | sonnet | perspective/critic-effectiveness.md, critic-completeness.md, critic-clarity.md, critic-generality.md | 不定（SendMessage） | 4並列 |
| Phase 1A | sonnet | phase1a-variant-generation.md | 不定（複数セクション） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 不定（複数セクション） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 不定（複数セクション） | 1 |
| Phase 3 | sonnet | なし（直接指示） | 1（「保存完了: {path}」） | プロンプト数×2回 |
| Phase 4 | sonnet | phase4-scoring.md | 2（Mean/SD + 詳細） | プロンプト数 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 (デプロイ) | haiku | なし（直接指示） | 1（「デプロイ完了: {path}」） | 1 |
| Phase 6A | sonnet | phase6a-knowledge-update.md | 1（「knowledge.md 更新完了（累計ラウンド数: {N}）」） | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update.md | 1（「proven-techniques.md 更新完了（...）」または「更新なし」） | 1 |
