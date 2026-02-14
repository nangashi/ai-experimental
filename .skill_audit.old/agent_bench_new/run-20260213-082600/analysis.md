# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 388 | メインワークフロー定義（Phase 0-6） |
| approach-catalog.md | 202 | 改善アプローチカタログ（S/C/N/M カテゴリ、バリエーション定義） |
| scoring-rubric.md | 70 | 採点基準（検出判定、スコア計算、推奨判定、収束判定） |
| test-document-guide.md | 254 | テスト対象文書生成ガイド（入力型判定、問題埋め込み、正解キー作成） |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック（自動更新） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回ベースライン作成+バリアント生成 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B: 継続知見ベースバリアント生成 |
| templates/phase2-test-document.md | 33 | Phase 2: テスト入力文書生成 |
| templates/phase3-evaluate.md | 7 | Phase 3: 評価実行 |
| templates/phase4-scoring.md | 13 | Phase 4: 採点 |
| templates/phase5-analysis-report.md | 22 | Phase 5: 分析レポート作成 |
| templates/phase6-deploy.md | 7 | Phase 6: プロンプトデプロイ |
| templates/phase6a-knowledge-update.md | 28 | Phase 6A: ナレッジ更新 |
| templates/phase6b-proven-techniques-update.md | 57 | Phase 6B: スキル知見フィードバック |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成（初期生成） |
| templates/perspective/critic-completeness.md | 107 | perspective 批評（網羅性） |
| templates/perspective/critic-clarity.md | 76 | perspective 批評（明確性） |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評（有効性） |
| templates/perspective/critic-generality.md | 82 | perspective 批評（汎用性） |
| perspectives/design/security.md | 43 | 設計書セキュリティレビュー観点定義 |
| perspectives/design/performance.md | 読込未実施 | 設計書パフォーマンスレビュー観点定義 |
| perspectives/design/consistency.md | 読込未実施 | 設計書一貫性レビュー観点定義 |
| perspectives/design/structural-quality.md | 読込未実施 | 設計書構造品質レビュー観点定義 |
| perspectives/design/reliability.md | 読込未実施 | 設計書信頼性レビュー観点定義 |
| perspectives/design/old/maintainability.md | 読込未実施 | 旧版（参照のみ） |
| perspectives/design/old/best-practices.md | 読込未実施 | 旧版（参照のみ） |
| perspectives/code/security.md | 38 | コードセキュリティレビュー観点定義 |
| perspectives/code/best-practices.md | 読込未実施 | コードベストプラクティスレビュー観点定義 |
| perspectives/code/consistency.md | 読込未実施 | コード一貫性レビュー観点定義 |
| perspectives/code/maintainability.md | 読込未実施 | コード保守性レビュー観点定義 |
| perspectives/code/performance.md | 読込未実施 | コードパフォーマンスレビュー観点定義 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1A/1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
- 各フェーズの目的:
  - **Phase 0**: 初期化・状態検出（agent_name 導出、perspective 解決/自動生成、knowledge.md 初期化/継続判定）
  - **Phase 1A**: 初回ベースライン作成+バリアント生成（proven-techniques ベースライン構築ガイドに従う）
  - **Phase 1B**: 継続知見ベースバリアント生成（knowledge.md のバリエーションステータステーブルに基づき Broad/Deep モード選定）
  - **Phase 2**: テスト入力文書生成（perspective の問題バンクを参照し、8-10個の問題を自然に埋め込む）
  - **Phase 3**: 並列評価実行（全プロンプト × 2回）
  - **Phase 4**: 採点（問題別検出判定 ○/△/× + ボーナス/ペナルティ、Mean/SD 計算）
  - **Phase 5**: 分析レポート作成（推奨判定、収束判定、考察）
  - **Phase 6**: プロンプト選択・デプロイ・ナレッジ更新・スキル知見フィードバック・次アクション選択

- データフロー:
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md` 生成
  - Phase 1A/1B → `.agent_bench/{agent_name}/prompts/v{NNN}-*.md` 生成
  - Phase 2 → `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md` 生成
  - Phase 3 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md` 生成
  - Phase 4 → Phase 3 の結果ファイルを参照し、`.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md` 生成
  - Phase 5 → Phase 4 の採点ファイルを参照し、`.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md` 生成
  - Phase 6 → Phase 5 のレポートを参照し、knowledge.md 更新、proven-techniques.md 更新（承認制）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 181 | `.agent_audit/{agent_name}/audit-*.md` | Phase 1B でバリアント生成時に agent_audit の分析結果を参照（audit-ce-*.md, audit-sa-*.md など） |

## D. コンテキスト予算分析
- SKILL.md 行数: 388行
- テンプレートファイル数: 15個、平均行数: 47行
- サブエージェント委譲: あり（Phase 0 knowledge 初期化、Phase 0 perspective 自動生成 Step 3/4、Phase 1A/1B、Phase 2、Phase 3（並列）、Phase 4（並列）、Phase 5、Phase 6A/6B）
- 親コンテキストに保持される情報: agent_name, agent_path, perspective 解決状態（検索/自動生成）、knowledge.md 存在判定（累計ラウンド数含む）、Phase 5 サブエージェント返答（7行サマリ: recommended, reason, convergence, scores, variants, deploy_info, user_summary）
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しはファイル経由で統一）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が空/不足時の要件ヒアリング | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の対応確認（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応確認（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |
| Phase 6B | AskUserQuestion | proven-techniques.md 更新承認 | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0 agent_path 読み込み失敗 → エラー出力して終了
  - Phase 0 knowledge.md 不在 → 初期化処理に分岐（Phase 1A へ）
  - Phase 0 perspective 未検出 → 自動生成処理（Step 1-6）
  - Phase 0 perspective 自動生成検証失敗 → エラー出力してスキル終了
- サブエージェント失敗時:
  - Phase 1A/1B サブエージェント失敗 → 1回リトライ。再失敗時はエラーメッセージを出力してスキル終了
  - Phase 2 サブエージェント失敗 → 1回リトライ。再失敗時はエラーメッセージを出力してスキル終了
  - Phase 3 評価失敗 → AskUserQuestion で確認（再試行/除外/中断）
  - Phase 4 採点失敗 → AskUserQuestion で確認（再試行/除外/中断）
  - Phase 5 サブエージェント失敗 → 1回リトライ。再失敗時はエラーメッセージを出力してスキル終了
  - Phase 6A ナレッジ更新失敗 → 1回リトライ。再失敗時はエラーメッセージを出力してスキル終了
  - Phase 6B proven-techniques 更新失敗 → 警告メッセージを出力するが、スキルは継続する（任意処理のため）
- 部分完了時:
  - Phase 3 一部評価成功（各プロンプトに最低1回の成功結果） → 警告を出力し Phase 4 へ進む（採点は成功した Run のみで実施）
  - Phase 4 一部採点成功（ベースラインが成功） → AskUserQuestion で確認（再試行/除外/中断）
- 入力バリデーション:
  - Phase 0 agent_path 未指定 → AskUserQuestion で確認
  - Phase 0 エージェント定義が実質空または不足 → AskUserQuestion で要件ヒアリング

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 knowledge 初期化 | sonnet | knowledge-init-template.md | 1行 | 1 |
| Phase 0 perspective Step 3 | sonnet | perspective/generate-perspective.md | 4行 | 1 |
| Phase 0 perspective Step 4 | sonnet | perspective/critic-effectiveness.md, critic-completeness.md, critic-clarity.md, critic-generality.md | 批評結果 | 4並列 |
| Phase 0 perspective Step 5 | sonnet | perspective/generate-perspective.md（再生成） | 4行 | 1（条件付き） |
| Phase 1A | sonnet | phase1a-variant-generation.md | 26行 | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 14行 | 1 |
| Phase 2 | sonnet | phase2-test-document.md | テストサマリ | 1 |
| Phase 3 | sonnet | phase3-evaluate.md | 1行（保存完了メッセージ） | (プロンプト数 × 2) 並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ） | プロンプト数並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行 | 1 |
| Phase 6 デプロイ | haiku | phase6-deploy.md | 1行 | 1（条件付き） |
| Phase 6A | sonnet | phase6a-knowledge-update.md | 1行 | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update.md | 1行 | 1 |
