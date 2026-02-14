# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 394 | メインワークフロー定義。Phase 0-6 の全手順、パス変数、サブエージェント委譲パターンを記述 |
| approach-catalog.md | 202 | 改善アプローチの3階層カタログ（カテゴリ/テクニック/バリエーション）。実証済み効果/逆効果テクニックを含む |
| perspectives/code/best-practices.md | 34 | コードレビュー観点定義（ベストプラクティス準拠）。評価スコープ、問題バンク含む |
| perspectives/code/consistency.md | 33 | コードレビュー観点定義（既存コードとの一貫性）。評価スコープ、問題バンク含む |
| perspectives/code/maintainability.md | 34 | コードレビュー観点定義（保守性）。評価スコープ、問題バンク含む |
| perspectives/code/security.md | 37 | コードレビュー観点定義（セキュリティ）。評価スコープ、問題バンク含む |
| perspectives/code/performance.md | 37 | コードレビュー観点定義（パフォーマンス）。評価スコープ、問題バンク含む |
| perspectives/design/security.md | 43 | 設計レビュー観点定義（セキュリティ）。評価スコープ、問題バンク含む |
| perspectives/design/old/maintainability.md | 43 | 設計レビュー観点定義（保守性・旧版）。評価スコープ、問題バンク含む |
| perspectives/design/old/best-practices.md | 34 | 設計レビュー観点定義（ベストプラクティス・旧版）。評価スコープ、問題バンク含む |
| perspectives/design/performance.md | 45 | 設計レビュー観点定義（パフォーマンス）。評価スコープ、問題バンク含む |
| perspectives/design/consistency.md | 51 | 設計レビュー観点定義（既存との一貫性）。評価スコープ、問題バンク含む |
| perspectives/design/reliability.md | 43 | 設計レビュー観点定義（信頼性・運用性）。評価スコープ、問題バンク含む |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート。バリエーションステータステーブル生成手順含む |
| scoring-rubric.md | 70 | 採点基準定義。検出判定基準（○△×）、スコア計算式、推奨判定基準、収束判定を含む |
| perspectives/design/structural-quality.md | 41 | 設計レビュー観点定義（構造的品質）。評価スコープ、問題バンク含む |
| proven-techniques.md | 70 | エージェント横断の実証済み知見。効果テクニック、アンチパターン、条件付きテクニック、ベースライン構築ガイドを含む |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成テンプレート。必須スキーマと生成ガイドライン含む |
| templates/phase2-test-document.md | 16 | Phase 2 サブエージェント指示（テスト文書・正解キー生成） |
| templates/phase4-scoring.md | 12 | Phase 4 サブエージェント指示（採点実行） |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込み、正解キーフォーマットを含む |
| templates/phase3-evaluate.md | 7 | Phase 3 サブエージェント指示（並列評価実行） |
| templates/phase6-deploy.md | 7 | Phase 6 Step 1 サブエージェント指示（プロンプトデプロイ） |
| templates/phase6a-knowledge-update.md | 28 | Phase 6 Step 2A サブエージェント指示（knowledge.md 更新） |
| templates/perspective/critic-effectiveness.md | 82 | perspective 批評テンプレート（有効性・境界明確性） |
| templates/perspective/critic-completeness.md | 112 | perspective 批評テンプレート（網羅性・欠落検出能力） |
| templates/perspective/critic-clarity.md | 80 | perspective 批評テンプレート（表現明確性・AI動作一貫性） |
| templates/perspective/critic-generality.md | 88 | perspective 批評テンプレート（汎用性・業界依存性） |
| templates/phase1a-variant-generation.md | 40 | Phase 1A サブエージェント指示（初回バリアント生成） |
| templates/phase1b-variant-generation.md | 32 | Phase 1B サブエージェント指示（継続バリアント生成） |
| templates/phase5-analysis-report.md | 20 | Phase 5 サブエージェント指示（分析・推奨判定・レポート作成） |
| templates/phase6b-proven-techniques-update.md | 57 | Phase 6 Step 2B サブエージェント指示（proven-techniques.md 更新） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- 各フェーズの目的:
  - Phase 0: 初期化・状態検出（agent_name 導出、perspective 解決または自動生成、knowledge.md 初期化/読み込み）
  - Phase 1A: 初回 — ベースライン作成 + バリアント生成（サブエージェントに委譲）
  - Phase 1B: 継続 — 知見ベースのバリアント生成（knowledge.md の過去知見と agent_audit 結果を参照）
  - Phase 2: テスト入力文書生成（毎ラウンド実行、サブエージェントに委譲）
  - Phase 3: 並列評価実行（各プロンプト×2回を並列サブエージェントで実行）
  - Phase 4: 採点（サブエージェントの並列実行、プロンプトごとに1採点エージェント）
  - Phase 5: 分析・推奨判定・レポート作成（サブエージェントに委譲）
  - Phase 6: プロンプト選択・デプロイ・次アクション（Step 1: デプロイ、Step 2: ナレッジ更新+スキル知見フィードバック+次アクション選択）
- データフロー:
  - Phase 0 → perspective-source.md, perspective.md, knowledge.md を生成/読み込み
  - Phase 1A/1B → prompts/ 配下にプロンプトファイル生成
  - Phase 2 → test-document-round-{N}.md, answer-key-round-{N}.md 生成
  - Phase 3 → results/ 配下に v{NNN}-{name}-run{R}.md 生成
  - Phase 4 → results/ 配下に v{NNN}-{name}-scoring.md 生成、7行サマリを親に返答
  - Phase 5 → reports/round-{N}-comparison.md 生成、7行サマリを親に返答
  - Phase 6 Step 1 → agent_path にデプロイ（ベースライン以外選択時のみ）
  - Phase 6 Step 2A → knowledge.md 更新
  - Phase 6 Step 2B → proven-techniques.md 更新（並列）
  - Phase 6 Step 2C → 次アクション選択で Phase 1B に戻る or 終了

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 188-191 | .agent_audit/{agent_name}/audit-*.md | Phase 1B で agent_audit の分析結果（基準有効性、スコープ整合性）を参照してバリアント生成 |
| templates/phase1b-variant-generation.md | 7-8 | {audit_dim1_path}, {audit_dim2_path} | Phase 1B サブエージェントが agent_audit 結果を読み込む（スキル外ディレクトリ） |

## D. コンテキスト予算分析
- SKILL.md 行数: 394行
- テンプレートファイル数: 15個、平均行数: 48行
- サブエージェント委譲: あり（Phase 0 perspective 自動生成時4並列、Phase 1A/1B/2/4/5/6A/6B で各1サブエージェント、Phase 3 で N×2 並列）
- 親コンテキストに保持される情報: agent_name, agent_path, current_round, perspective_source_path, perspective_path, knowledge_path, サブエージェントからの7行サマリ（Phase 4, 5）
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しはファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が空または不足時の要件ヒアリング（perspective 自動生成時） | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の再試行・除外・中断選択 | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の再試行・除外・中断選択 | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル+推奨理由提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |
| Phase 6 Step 2B | AskUserQuestion | proven-techniques.md 更新内容の承認 | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 不在時（Phase 0）: AskUserQuestion で確認、または Phase 1A で新規作成
  - knowledge.md 不在時（Phase 0）: knowledge-init-template.md で初期化
  - perspective 不在時（Phase 0）: 自動生成（ファイル名パターン検索 → generate-perspective.md + 4批評エージェント並列 → 再生成1回 → 検証）
  - audit-*.md 不在時（Phase 1B）: 空文字列を渡し knowledge.md のみでバリアント生成
- サブエージェント失敗時:
  - Phase 1A/1B/2: 1回リトライ、再失敗時はエラーメッセージ出力してスキル終了
  - Phase 3: 成功数を集計し、各プロンプトに最低1回成功があれば Phase 4 へ進む、成功結果0回のプロンプトがあれば AskUserQuestion で再試行・除外・中断選択
  - Phase 4: 全て成功で Phase 5 へ、一部失敗時は AskUserQuestion で再試行・除外（ベースライン失敗時は中断）・中断選択
  - Phase 5: 1回リトライ、再失敗時はエラーメッセージ出力してスキル終了
  - Phase 6 Step 2B（proven-techniques 更新）: 失敗時は警告出力するが継続（任意処理のため）
- 部分完了時:
  - Phase 3: 各プロンプトに最低1回成功があれば Phase 4 へ進む（SD 計算は両 Run 成功時のみ、1回のみ成功の場合は SD=N/A）
  - Phase 4: ベースラインが成功していれば失敗プロンプト除外で Phase 5 へ進む選択可能
- 入力バリデーション: agent_path が存在しない場合は Read 失敗をキャッチして Phase 1A で新規作成、または AskUserQuestion で確認

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 perspective 自動生成 Step 3 | sonnet | templates/perspective/generate-perspective.md | 4行（観点、入力型、評価スコープ、問題バンク件数） | 1 |
| Phase 0 perspective 自動生成 Step 4 | sonnet | templates/perspective/critic-effectiveness.md | 2行（重大な問題、改善提案） | 4並列 |
| Phase 0 perspective 自動生成 Step 4 | sonnet | templates/perspective/critic-completeness.md | 2行（重大な問題、改善提案） | 4並列 |
| Phase 0 perspective 自動生成 Step 4 | sonnet | templates/perspective/critic-clarity.md | 2行（重大な問題、改善提案） | 4並列 |
| Phase 0 perspective 自動生成 Step 4 | sonnet | templates/perspective/critic-generality.md | 2行（重大な問題、改善提案） | 4並列 |
| Phase 0 knowledge 初期化 | sonnet | templates/knowledge-init-template.md | 1行（knowledge.md 初期化完了（バリエーション数: N）） | 1 |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 26行（見出し+構造分析+バリアント2×9行） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 14行（見出し+選定プロセス+バリアント2×5行） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 複数行（テスト対象文書サマリ+埋め込み問題一覧テーブル+ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | templates/phase3-evaluate.md | 1行（保存完了: {result_path}） | (プロンプト数×2)並列 |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（{prompt_name}: Mean={X.X}, SD={X.X}、Run1={X.X}...） | プロンプト数並列 |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1 | haiku | templates/phase6-deploy.md | 1行（デプロイ完了: {agent_path}） | 1（ベースライン以外選択時のみ） |
| Phase 6 Step 2A | sonnet | templates/phase6a-knowledge-update.md | 1行（knowledge.md 更新完了（累計ラウンド数: N）） | 1 |
| Phase 6 Step 2B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（proven-techniques.md 更新完了/更新なし） | 1（並列） |
