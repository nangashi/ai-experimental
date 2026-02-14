# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 435 | メインワークフロー定義。Phase 0-6 の親エージェント処理を記述 |
| approach-catalog.md | 202 | 改善アプローチカタログ。4カテゴリ（S/C/N/M）の3階層管理 |
| scoring-rubric.md | 70 | 採点基準。検出判定基準（○△×）、スコア計算式、推奨判定基準、収束判定 |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック。Tier別管理（高/中/候補）、ベースライン構築ガイド |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、構成、問題埋め込み原則、正解キーフォーマット |
| perspectives/code/maintainability.md | 34 | コード保守性観点定義 |
| perspectives/code/security.md | 37 | コードセキュリティ観点定義 |
| perspectives/code/performance.md | 37 | コードパフォーマンス観点定義 |
| perspectives/code/best-practices.md | 34 | コードベストプラクティス観点定義 |
| perspectives/code/consistency.md | 33 | コード一貫性観点定義 |
| perspectives/design/consistency.md | 51 | 設計一貫性観点定義 |
| perspectives/design/security.md | 43 | 設計セキュリティ観点定義 |
| perspectives/design/structural-quality.md | 41 | 設計構造的品質観点定義 |
| perspectives/design/performance.md | 45 | 設計パフォーマンス観点定義 |
| perspectives/design/reliability.md | 43 | 設計信頼性・運用性観点定義 |
| perspectives/design/old/maintainability.md | 43 | 旧設計保守性観点定義（アーカイブ） |
| perspectives/design/old/best-practices.md | 34 | 旧設計ベストプラクティス観点定義（アーカイブ） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート |
| templates/perspective/generate-perspective.md | 67 | パースペクティブ初期生成テンプレート |
| templates/perspective/critic-completeness.md | 107 | パースペクティブ批評（網羅性）テンプレート |
| templates/perspective/critic-clarity.md | 76 | パースペクティブ批評（明確性）テンプレート |
| templates/perspective/critic-effectiveness.md | 75 | パースペクティブ批評（有効性）テンプレート |
| templates/perspective/critic-generality.md | 82 | パースペクティブ批評（汎用性）テンプレート |
| templates/phase1a-variant-generation.md | 46 | Phase 1A バリアント生成テンプレート（初回ラウンド） |
| templates/phase1b-variant-generation.md | 44 | Phase 1B バリアント生成テンプレート（継続ラウンド） |
| templates/phase2-test-document.md | 30 | Phase 2 テスト文書生成テンプレート |
| templates/phase4-scoring.md | 13 | Phase 4 採点テンプレート |
| templates/phase5-analysis-report.md | 23 | Phase 5 分析・推奨判定テンプレート |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A ナレッジ更新テンプレート |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B proven-techniques 更新テンプレート |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 → (1B へループ or 終了)
- 各フェーズの目的:
  - **Phase 0**: 初期化・状態検出。エージェントファイル読み込み、agent_name 導出、perspective 解決（フォールバック3段階: 既存/パターンマッチ/自動生成）、proven-techniques 初期化、knowledge.md 初期化。1A/1B 分岐判定
  - **Phase 1A**: 初回ラウンド専用。ベースライン作成 + バリアント生成（subagent に委譲）。proven-techniques のベースライン構築ガイドに従う
  - **Phase 1B**: 継続ラウンド専用。knowledge.md のバリエーションステータステーブルに基づくバリアント選定（Broad/Deep モード）。agent_audit の dim1/dim2 ファイルを参照可能
  - **Phase 2**: テスト対象文書生成（毎ラウンド実行）。test-document-guide に従い、perspective の問題バンクを参照してドメイン多様性を確保
  - **Phase 3**: 並列評価実行。各プロンプトを2回ずつ並列実行（N×2 subagents）
  - **Phase 4**: 採点。プロンプトごとに並列採点 subagent を起動（N subagents）
  - **Phase 5**: 分析・推奨判定・レポート作成（subagent に委譲）。scoring-rubric の推奨判定基準と収束判定を適用
  - **Phase 6**: プロンプト選択・デプロイ・次アクション。Step 1: ユーザー選択（AskUserQuestion）→ デプロイ subagent。Step 2: 並列実行（6A: knowledge 更新、6B: proven-techniques 更新）。Step 3: 次ラウンド or 終了選択
- データフロー:
  - Phase 0 → perspective-source.md/perspective.md/knowledge.md を生成
  - Phase 1A/1B → prompts/ にバリアント生成
  - Phase 2 → test-document.md/answer-key.md を生成
  - Phase 3 → results/ に実行結果生成
  - Phase 4 → results/ に採点結果生成（Phase 5 で参照）
  - Phase 5 → reports/ にレポート生成（Phase 6A/6B で参照）
  - Phase 6A → knowledge.md を更新（Phase 1B/2/5 で参照）
  - Phase 6B → proven-techniques.md を更新（Phase 1A/1B で参照）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 228-232 | `.agent_audit/{agent_name}/audit-ce-*.md` | Phase 1B で基準有効性分析結果を参照（外部スキル agent_audit の出力） |
| SKILL.md | 228-232 | `.agent_audit/{agent_name}/audit-sa-*.md` | Phase 1B でスコープ整合性分析結果を参照（外部スキル agent_audit の出力） |
| templates/phase1b-variant-generation.md | 8-9 | `.agent_audit/{agent_name}/audit-*.md` | バリアント生成時に audit 結果を参照（外部依存明示） |

## D. コンテキスト予算分析
- SKILL.md 行数: 435行
- テンプレートファイル数: 14個、平均行数: 50.9行
- サブエージェント委譲: あり。以下のパターンで委譲:
  - Phase 0 perspective 自動生成: 1 + 4並列 + 1 = 6サブエージェント（generate-perspective → 4 critic 並列 → 再生成）
  - Phase 0 knowledge 初期化: 1サブエージェント
  - Phase 1A: 1サブエージェント
  - Phase 1B: 1サブエージェント
  - Phase 2: 1サブエージェント
  - Phase 3: N×2 並列サブエージェント（N = プロンプト数、各2回実行）
  - Phase 4: N 並列サブエージェント（プロンプトごとに採点）
  - Phase 5: 1サブエージェント
  - Phase 6 Step 1: 1サブエージェント（haiku でデプロイ）
  - Phase 6 Step 2: 2並列サブエージェント（6A knowledge 更新、6B proven-techniques 更新）
- 親コンテキストに保持される情報: agent_name、agent_path、perspective パス、knowledge パス、累計ラウンド数、Phase 5 の7行サマリ（recommended/reason/convergence/scores/variants/deploy_info/user_summary）
- 3ホップパターンの有無: なし。サブエージェント間のデータ受け渡しはファイル経由で行う設計（Phase 1→2→3→4→5→6 全てファイルベース）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | エージェントパス未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | 不完全な perspective-source.md の扱い確認（削除して再生成/そのまま使用/中断） | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が空/不足の場合のヒアリング（目的・役割・入出力・ツール・制約） | 不明 |
| Phase 3 | AskUserQuestion | 評価実行失敗時の対応確認（再試行/除外して続行/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応確認（再試行/除外して続行/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（全プロンプトから選択。推奨プロンプトに「(推奨)」付記） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | デプロイ最終確認（ベースライン以外選択時） | 不明 |
| Phase 6 Step 3 | AskUserQuestion | 次アクション選択（次ラウンドへ/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - エージェントファイル不在: エラー出力して終了（Phase 0）
  - perspective-source.md 不在: フォールバック（パターンマッチ → 自動生成）（Phase 0）
  - knowledge.md 不在: 初期化してPhase 1A へ（Phase 0）
  - proven-techniques.md 不在: 初期内容を Write で保存（Phase 0）
  - perspective 自動生成の必須セクション欠落: エラー出力して終了（Phase 0）
- サブエージェント失敗時:
  - Phase 3 評価実行失敗: 成功数に応じて分岐（全成功/部分成功/全失敗）。部分成功時は警告付きで継続、全失敗時は AskUserQuestion で確認（再試行/除外/中断）
  - Phase 4 採点失敗: 成功数に応じて分岐。部分失敗時は AskUserQuestion で確認（再試行/除外/中断）。ベースライン失敗時は中断
- 部分完了時:
  - Phase 3 で一部プロンプトに成功結果がない場合: AskUserQuestion で確認（再試行/除外/中断）
  - Phase 4 で一部採点が失敗した場合: AskUserQuestion で確認（再試行/除外/中断）。ベースライン失敗時は中断
- 入力バリデーション:
  - agent_path 未指定: AskUserQuestion で確認（Phase 0）
  - perspective-source.md 不完全: 必須セクション検証。欠落時は AskUserQuestion で確認（Phase 0）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0: perspective 初期生成 | sonnet | generate-perspective.md | 4行（観点/入力型/評価スコープ/問題バンク） | 1 |
| Phase 0: perspective 批評 | sonnet | critic-effectiveness.md | SendMessage（重大な問題/改善提案） | 4並列 |
| Phase 0: perspective 批評 | sonnet | critic-completeness.md | SendMessage（重大な問題/改善提案/Missing Element Detection 表） | 4並列 |
| Phase 0: perspective 批評 | sonnet | critic-clarity.md | SendMessage（重大な問題/改善提案/確認） | 4並列 |
| Phase 0: perspective 批評 | sonnet | critic-generality.md | SendMessage（重大な問題/Scope Item Generality 表/問題バンク Generality） | 4並列 |
| Phase 0: perspective 再生成 | sonnet | generate-perspective.md | 4行（観点/入力型/評価スコープ/問題バンク） | 1（条件付き） |
| Phase 0: knowledge 初期化 | sonnet | knowledge-init-template.md | 1行（バリエーション数） | 1（条件付き） |
| Phase 1A | sonnet | phase1a-variant-generation.md | 多行（エージェント定義/構造分析結果/生成バリアント） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 多行（選定プロセス/生成バリアント） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 多行（テスト対象文書サマリ/埋め込み問題一覧/ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | （プロンプトファイル直接実行） | 1行（保存完了メッセージ） | N×2（N=プロンプト数、各2回実行） |
| Phase 4 | sonnet | phase4-scoring.md | 2行（Mean/SD、Run1/Run2 詳細） | N（プロンプトごとに1並列） |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended/reason/convergence/scores/variants/deploy_info/user_summary） | 1 |
| Phase 6 Step 1: デプロイ | haiku | （メタデータ除去+上書き指示） | 1行（デプロイ完了メッセージ） | 1（条件付き） |
| Phase 6 Step 2A | sonnet | phase6a-knowledge-update.md | 1行（累計ラウンド数） | 1 |
| Phase 6 Step 2B | sonnet | phase6b-proven-techniques-update.md | 1行（promoted/updated/skipped 件数） | 1 |
