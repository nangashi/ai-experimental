# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 372 | スキル本体。Phase 0-6のワークフロー定義、パースペクティブ解決・自動生成、サブエージェント委譲パターンを含む |
| approach-catalog.md | 202 | 改善アプローチカタログ。S/C/N/Mの4カテゴリ×複数テクニック×バリエーション。共通ルール・推奨構成を含む |
| scoring-rubric.md | 70 | 採点基準。検出判定基準(○△×)、スコア計算式、安定性閾値、推奨判定・収束判定基準を定義 |
| proven-techniques.md | 70 | エージェント横断の実証済み知見。Section 1(効果テクニック)、Section 2(アンチパターン)、Section 3(条件付き)、Section 4(ベースライン構築ガイド) |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成テンプレート、問題埋め込みガイドライン、正解キーフォーマットを定義 |
| templates/knowledge-init-template.md | 53 | knowledge.md初期化テンプレート。バリエーションステータステーブル、スコア推移、考慮事項セクションを定義 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A（初回）のバリアント生成。ベースライン構築ガイド適用、6次元構造分析、2バリアント生成 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B（継続）のバリアント生成。knowledge.mdのバリエーションステータスベースでBroad/Deep選定、audit知見統合 |
| templates/phase2-test-document.md | 33 | Phase 2のテスト文書生成。入力型判定、問題埋め込み、正解キー生成、ドメイン多様性確保 |
| templates/phase4-scoring.md | 13 | Phase 4の採点。検出判定(○△×)、ボーナス/ペナルティ、スコア計算、詳細保存+コンパクトサマリ返答 |
| templates/phase5-analysis-report.md | 22 | Phase 5の分析レポート作成。推奨判定、収束判定、比較レポート生成、7行サマリ返答 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A（ステップ2-A）のknowledge.md更新。効果テーブル、バリエーションステータス、スコア推移、考慮事項更新（preserve + integrate） |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B（ステップ2-B）のproven-techniques.md更新。Tier 1-3昇格条件、統合ルール、サイズ制限遵守 |
| templates/perspective/generate-perspective.md | 67 | パースペクティブ初期生成（Step 3）。必須スキーマ、生成ガイドライン、入力型別問題バンク作成 |
| templates/perspective/critic-effectiveness.md | 75 | パースペクティブ批評（有効性）。4段階分析（理解→寄与度→境界明確性→結論）、重大問題/改善提案/確認の分類 |
| templates/perspective/critic-completeness.md | 未読 | パースペクティブ批評（網羅性） |
| templates/perspective/critic-clarity.md | 未読 | パースペクティブ批評（明確性） |
| templates/perspective/critic-generality.md | 未読 | パースペクティブ批評（汎用性） |
| perspectives/design/security.md | 43 | デザインレベルセキュリティ観点定義。STRIDE脅威モデリング、認証認可設計、データ保護、入力検証、インフラ監査を評価 |
| perspectives/design/consistency.md | 未読 | デザインレベル整合性観点定義 |
| perspectives/design/structural-quality.md | 未読 | デザインレベル構造品質観点定義 |
| perspectives/design/performance.md | 未読 | デザインレベルパフォーマンス観点定義 |
| perspectives/design/reliability.md | 未読 | デザインレベル信頼性観点定義 |
| perspectives/code/security.md | 38 | コードレベルセキュリティ観点定義。インジェクション脆弱性、認証・セッション、機密データ、アクセス制御、依存関係を評価 |
| perspectives/code/maintainability.md | 未読 | コードレベル保守性観点定義 |
| perspectives/code/performance.md | 未読 | コードレベルパフォーマンス観点定義 |
| perspectives/code/best-practices.md | 未読 | コードレベルベストプラクティス観点定義 |
| perspectives/code/consistency.md | 未読 | コードレベル整合性観点定義 |
| perspectives/design/old/maintainability.md | 未読 | 旧バージョン（old/配下） |
| perspectives/design/old/best-practices.md | 未読 | 旧バージョン（old/配下） |

## B. ワークフロー概要
- フェーズ構成: Phase 0（初期化・状態検出）→ 1A/1B（バリアント生成）→ 2（テスト文書生成）→ 3（並列評価）→ 4（採点）→ 5（分析レポート）→ 6（デプロイ・知見更新・次アクション）
- 各フェーズの目的:
  - **Phase 0**: agent_path読込、agent_name導出、perspective解決/自動生成、knowledge.md初期化/読込、初回/継続判定
  - **Phase 1A**: 初回。ベースライン構築（proven-techniques.mdのベースライン構築ガイド適用）+6次元構造分析+2バリアント生成
  - **Phase 1B**: 継続。knowledge.mdのバリエーションステータステーブルからBroad/Deep選定+audit知見統合+2バリアント生成
  - **Phase 2**: 毎ラウンド。テスト対象文書+正解キー生成。入力型判定、perspective問題バンク参照、ドメイン多様性確保
  - **Phase 3**: 各プロンプト×2回並列評価実行。成功数集計、失敗時の再試行/除外/中断分岐
  - **Phase 4**: プロンプトごとに採点サブエージェント並列起動。検出判定(○△×)、ボーナス/ペナルティ、スコア計算
  - **Phase 5**: 分析レポート作成。推奨判定、収束判定、7行サマリ返答
  - **Phase 6 Step 1**: プロンプト選択。ユーザー提示（性能推移テーブル+推奨理由+収束判定）、選択、デプロイ（haiku）
  - **Phase 6 Step 2-A**: knowledge.md更新（sonnet）。累計ラウンド+1、効果テーブル、バリエーションステータス、スコア推移、考慮事項（preserve + integrate、20行上限）
  - **Phase 6 Step 2-B**: proven-techniques.md更新（sonnet、A完了後に並列起動）。Tier 1-3昇格条件、統合ルール、サイズ制限
  - **Phase 6 Step 2-C**: 次アクション選択。次ラウンド/終了。B完了を待機
- データフロー:
  - Phase 0 → knowledge.md生成（初回）/読込（継続）→ Phase 1A/1B分岐
  - Phase 1A/1B → prompts/v{NNN}-baseline.md, v{NNN}-variant-*.md生成 → Phase 2
  - Phase 2 → test-document-round-{NNN}.md, answer-key-round-{NNN}.md生成 → Phase 3
  - Phase 3 → results/v{NNN}-{name}-run{1,2}.md生成 → Phase 4
  - Phase 4 → results/v{NNN}-{name}-scoring.md生成 → Phase 5
  - Phase 5 → reports/round-{NNN}-comparison.md生成、7行サマリ返答 → Phase 6
  - Phase 6 Step 1 → 選択プロンプトをagent_pathにデプロイ（haiku） → Step 2-A
  - Phase 6 Step 2-A → knowledge.md更新 → Step 2-B/C並列起動
  - Phase 6 Step 2-B → proven-techniques.md更新（昇格条件達成時のみ） → 次ラウンド/終了
  - Phase 6 Step 2-C → AskUserQuestion → Phase 1B（次ラウンド）/終了

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | perspective-source.mdが存在しない場合のフォールバック検索（reviewer命名パターン一致時） |
| templates/phase1b-variant-generation.md | 8 | `.agent_audit/{agent_name}/audit-*.md` | agent_auditスキルの分析結果を参照（基準有効性・スコープ整合性の改善推奨をバリアント生成に活用） |

## D. コンテキスト予算分析
- SKILL.md 行数: 372行
- テンプレートファイル数: 13個、平均行数: 38行（最小13行、最大75行）
- サブエージェント委譲: あり（Phase 0: perspective自動生成5ステップ+knowledge初期化、Phase 1A/1B/2/4/5/6A/6B）
- 親コンテキストに保持される情報:
  - agent_path, agent_name（Phase 0で決定、全Phase共通）
  - perspective_source_path, perspective_path（Phase 0で決定、Phase 1/2/4で使用）
  - 累計ラウンド数（knowledge.md読込から抽出、Phase 2/4/5/6で使用）
  - サブエージェント返答サマリ（Phase 1: 構造分析+バリアント情報、Phase 2: 問題サマリ、Phase 4: スコアサマリ、Phase 5: 7行サマリ）
  - プロンプトパス一覧（Phase 3/4で使用）
  - 詳細データはファイル経由で受け渡し（サブエージェント→親の中継なし）
- 3ホップパターンの有無: なし（Phase 6 Step 2でA→B順次実行だが、Bはknowledge.mdをファイル経由で参照するため中継なし）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が実質空/不足の場合のヒアリング（目的・役割、入出力、使用ツール・制約） | 不明 |
| Phase 3 | AskUserQuestion | いずれかのプロンプトで成功結果が0回の場合の確認（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点サブエージェントの一部失敗時の確認（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル+推奨理由+収束判定を提示） | 不明 |
| Phase 6 Step 2-C | AskUserQuestion | 次アクション選択（次ラウンド/終了、収束判定・累計ラウンド数を付記） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path読込失敗 → エラー出力して終了（Phase 0）
  - knowledge.md不在 → 初期化実行してPhase 1Aへ（Phase 0）
  - perspective-source.md不在 → フォールバック検索→自動生成（Phase 0）
- サブエージェント失敗時:
  - Phase 3（評価実行）: 成功数集計→条件分岐（全成功→Phase 4、一部成功かつ各プロンプト最低1回成功→警告+Phase 4、いずれか0回→AskUserQuestion）
  - Phase 4（採点）: 成功数集計→条件分岐（全成功→Phase 5、一部失敗→AskUserQuestion）
  - その他のPhase: 明示的記載なし（失敗時の処理は未定義）
- 部分完了時:
  - Phase 3: 各プロンプトに最低1回の成功結果があれば警告出力+Phase 4へ進む（Run1回のみのプロンプトはSD=N/Aとする）
  - Phase 4: ベースライン失敗時は中断、それ以外は除外して続行可能
- 入力バリデーション:
  - agent_path未指定 → AskUserQuestion（Phase 0）
  - perspective検証: 必須セクション存在確認（Phase 0、検証失敗→エラー出力して終了）
  - 上記以外の入力バリデーション: 未定義

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（perspective自動生成 Step 3） | sonnet | templates/perspective/generate-perspective.md | 4行（観点名、入力型、評価スコープ、問題バンク件数） | 1 |
| Phase 0（perspective自動生成 Step 4） | sonnet | templates/perspective/critic-effectiveness.md, critic-completeness.md, critic-clarity.md, critic-generality.md | 可変（重大問題/改善提案/確認） | 4並列 |
| Phase 0（perspective自動生成 Step 5） | sonnet | templates/perspective/generate-perspective.md（再生成） | 4行 | 1（条件付き、1回のみ） |
| Phase 0（knowledge初期化） | sonnet | templates/knowledge-init-template.md | 1行（初期化完了+バリエーション数） | 1 |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 可変（エージェント定義、構造分析結果、バリアント2個の情報） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 可変（選定プロセス、バリアント2個の情報） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 可変（テスト対象文書サマリ、問題一覧、ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | テンプレートなし（簡易指示） | 1行（保存完了のみ） | (ベースライン1+バリアント数)×2回（全て同一メッセージ内で並列起動） |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（プロンプト名: Mean/SD、Run1/Run2詳細） | プロンプト数（並列起動） |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1（デプロイ） | haiku | テンプレートなし（簡易指示） | 1行（デプロイ完了のみ） | 1 |
| Phase 6 Step 2-A | sonnet | templates/phase6a-knowledge-update.md | 1行（更新完了+累計ラウンド数） | 1 |
| Phase 6 Step 2-B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（更新完了/更新なし） | 1（A完了後に並列起動） |
