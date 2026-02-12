# スキル構造分析: agent_create

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 365 | スキル本体。Phase 0-6のワークフロー定義 |
| approach-catalog.md | 217 | 改善アプローチカタログ（S/C/N/M 4カテゴリ、各テクニック×バリエーション） |
| scoring-rubric.md | 95 | 採点基準（scenario/detection モード別の判定基準、推奨判定、収束判定） |
| test-scenario-guide.md | 154 | テストシナリオ作成ガイド（scenario モード用、6ステップ） |
| test-document-guide.md | 199 | テスト対象文書生成ガイド（detection モード用） |
| proven-techniques.md | 70 | スキル横断の実証済み知見（4セクション、自動更新対象） |
| templates/knowledge-init-template.md | 99 | Phase 0: knowledge.md 初期化テンプレート |
| templates/phase1a-variant-generation.md | 45 | Phase 1A: 初回ベースライン+バリアント生成 |
| templates/phase1b-variant-generation.md | 31 | Phase 1B: 継続ラウンドのバリアント生成 |
| templates/phase2-test-set.md | 29 | Phase 2: テストシナリオセット生成（scenario） |
| templates/phase2-test-document.md | 32 | Phase 2: テスト対象文書生成（detection） |
| templates/phase4-scoring.md | 34 | Phase 4: 採点実行テンプレート |
| templates/phase5-analysis-report.md | 27 | Phase 5: 分析・推奨判定・レポート作成 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A: knowledge.md 更新 |
| templates/phase6b-proven-techniques-update.md | 51 | Phase 6B: proven-techniques.md 更新 |
| perspectives/design/consistency.md | 未読 | 設計レビュー観点定義（consistency） |
| perspectives/design/reliability.md | 未読 | 設計レビュー観点定義（reliability） |
| perspectives/design/security.md | 未読 | 設計レビュー観点定義（security） |
| perspectives/design/performance.md | 未読 | 設計レビュー観点定義（performance） |
| perspectives/design/structural-quality.md | 未読 | 設計レビュー観点定義（structural-quality） |
| perspectives/design/old/maintainability.md | 未読 | 旧版観点定義 |
| perspectives/design/old/best-practices.md | 未読 | 旧版観点定義 |
| perspectives/code/security.md | 未読 | コードレビュー観点定義（security） |
| perspectives/code/performance.md | 未読 | コードレビュー観点定義（performance） |
| perspectives/code/consistency.md | 未読 | コードレビュー観点定義（consistency） |
| perspectives/code/best-practices.md | 未読 | コードレビュー観点定義（best-practices） |
| perspectives/code/maintainability.md | 未読 | コードレビュー観点定義（maintainability） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 → (ループまたは終了)
- 各フェーズの目的:
  - **Phase 0**: 初期化・eval_mode判定（scenario/detection）、knowledge.md初期化（初回のみ）
  - **Phase 1A**: 初回ラウンド - ベースライン作成+バリアント2個生成
  - **Phase 1B**: 継続ラウンド - knowledge.md ベースのバリアント2個生成（Broad/Deep戦略）
  - **Phase 2**: テスト生成（scenario: テストシナリオ+ルーブリック初回のみ、detection: テスト対象文書+正解キー毎ラウンド）
  - **Phase 3**: 並列評価実行（各プロンプト × 2回 × サブエージェント）
  - **Phase 4**: 採点（プロンプトごとに並列サブエージェント、scenario: ルーブリック採点、detection: 検出判定）
  - **Phase 5**: 分析・推奨判定・レポート作成（サブエージェント委譲、7行サマリ返答）
  - **Phase 6**: デプロイ+ナレッジ更新+スキル知見フィードバック+次アクション選択
- データフロー:
  - Phase 0 → knowledge.md 初期化（ファイル不在時）
  - Phase 1A/1B → prompts/ ディレクトリにベースライン+バリアントファイル生成
  - Phase 2 scenario → test-set.md, rubric.md 生成（初回のみ）
  - Phase 2 detection → test-document-round-NNN.md, answer-key-round-NNN.md 生成（毎ラウンド）
  - Phase 3 → results/ ディレクトリに評価結果ファイル生成
  - Phase 4 → results/ ディレクトリに採点結果ファイル生成
  - Phase 5 → reports/ ディレクトリにレポート生成、7行サマリを Phase 6 に返答
  - Phase 6A → knowledge.md 更新
  - Phase 6B → proven-techniques.md 更新（条件満たす場合のみ）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 39 | `.claude/skills/agent_create/perspectives/{target}/{perspective}.md` | eval_mode=detection 時の観点ファイル存在確認 |
| SKILL.md | 62 | `.claude/skills/agent_create/perspectives/{target}/{perspective}.md` | 観点ファイルのコピー元 |
| SKILL.md | 63 | `prompt-improve/{perspective}-{target}/perspective.md` | 観点ファイルのコピー先（作業ディレクトリ） |
| SKILL.md | 67 | `.claude/agents/{perspective}-{target}-reviewer.md` | detection モードのエージェント定義ファイルパス |
| SKILL.md | 71-72 | `prompt-improve/{agent_name}/` | 作業ディレクトリ |
| SKILL.md | 72 | `prompt-improve/{agent_name}/knowledge.md` | 知見ファイル（初回/継続判定用） |
| SKILL.md | 80-108 | `.claude/skills/agent_create/templates/*.md` | 各種テンプレートファイル |
| SKILL.md | 83, 100, 124 | `.claude/skills/agent_create/approach-catalog.md` | アプローチカタログ参照 |
| SKILL.md | 101, 125, 331 | `.claude/skills/agent_create/proven-techniques.md` | 実証済みテクニック参照・更新 |
| SKILL.md | 105 | `.claude/agents/security-design-reviewer.md` | scenario モード新規作成時の構造参考 |
| SKILL.md | 137-147 | `prompt-improve/{agent_name}/test-set.md`, `rubric.md` | テストセット・ルーブリック |
| SKILL.md | 200, 215-216 | `prompt-improve/{agent_name}/test-set.md`, `test-document-round-{NNN}.md`, `results/*.md` | 評価入力・結果ファイル |
| SKILL.md | 234 | `prompt-improve/{agent_name}/results/` | Phase 3 結果ファイル収集 |
| SKILL.md | 245 | `.claude/skills/agent_create/scoring-rubric.md` | 採点基準参照 |
| SKILL.md | 246-253 | `prompt-improve/{agent_name}/results/*.md`, `answer-key-round-{NNN}.md` | 採点対象ファイル |
| SKILL.md | 266-269 | `.claude/skills/agent_create/scoring-rubric.md`, `knowledge.md`, `reports/round-{NNN}-comparison.md` | 分析・レポート関連 |
| SKILL.md | 319-333 | `prompt-improve/{agent_name}/knowledge.md`, `reports/round-{NNN}-comparison.md` | ナレッジ更新関連 |
| templates/phase1a-variant-generation.md | 12 | `.claude/agents/` | detection モード新規作成時の類似エージェント参考 |
| approach-catalog.md | 216 | `prompt-improve/{agent_name}/knowledge.md` | 個別エージェント詳細参照先 |

## D. コンテキスト予算分析
- **SKILL.md 行数**: 365行
- **テンプレートファイル数**: 9個、平均行数: 42行
- **サブエージェント委譲**: あり（Phase 0初期化、1A/1B、2、3並列、4並列、5、6A、6B）
- **親コンテキストに保持される情報**:
  - eval_mode（scenario/detection）
  - agent_name, agent_path
  - scenario の場合: user_requirements
  - detection の場合: perspective, target
  - Phase 1 返答（構造分析結果、バリアント情報）
  - Phase 5 返答（7行サマリ: recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - knowledge.md から抽出したラウンド別性能推移（Phase 6 デプロイ判断用）
- **3ホップパターンの有無**: なし
  - 全データはファイル経由で受け渡し
  - サブエージェント間の直接参照はファイルパス指定で実現
  - 親は Phase 5 の7行サマリと knowledge.md の性能推移のみ保持

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 scenario（新規作成） | AskUserQuestion | エージェントの目的・役割・入出力・ツール・制約をヒアリング | 不明 |
| Phase 0 scenario（既存改善） | AskUserQuestion | エージェント定義の不足要素をヒアリング | 不明 |
| Phase 2 scenario | AskUserQuestion | テストセットの承認 | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル+推奨提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - knowledge.md 不在 → Phase 0 で初期化（サブエージェント委譲）
  - test-set.md 不在（scenario） → Phase 2 実行
  - test-set.md 存在（scenario） → Phase 2 スキップ
  - perspective.md 不在（detection） → エラーメッセージ表示+スキル終了
- **サブエージェント失敗時**: 未定義（Phase 3 で成功数/総数を報告する記述あり）
- **部分完了時**: Phase 3 で「評価完了: {成功数}/{総数} タスク成功」と報告
- **入力バリデーション**:
  - Phase 0: 引数パターンによる eval_mode 判定
  - detection モード: perspective ファイル存在確認、不在時はエラー終了

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 初期化 | sonnet | knowledge-init-template.md | 1 | 1 |
| Phase 1A | sonnet | phase1a-variant-generation.md | 構造分析テーブル+バリアント情報（可変） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 選定プロセス+バリアント情報（可変） | 1 |
| Phase 2 scenario | sonnet | phase2-test-set.md | テーブル形式サマリ（可変） | 1 |
| Phase 2 detection | sonnet | phase2-test-document.md | 問題サマリテーブル（可変） | 1 |
| Phase 3 scenario | sonnet | （プロンプト定義自体） | "保存完了: {N}シナリオ" | (baseline + variants) × 2回 |
| Phase 3 detection | sonnet | （プロンプト定義自体） | "保存完了: {path}" | (baseline + variants) × 2回 |
| Phase 4 | sonnet | phase4-scoring.md | スコアサマリ1-3行 | baseline + variants（各1） |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1 デプロイ | haiku | （直接指示） | "デプロイ完了: {path}" | 0-1（ベースライン以外選択時のみ） |
| Phase 6A | sonnet | phase6a-knowledge-update.md | "knowledge.md 更新完了（累計ラウンド数: {N}）" | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update.md | "proven-techniques.md 更新完了/更新なし" | 1 |
