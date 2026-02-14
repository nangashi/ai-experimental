# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 415 | メインスキル定義。全7フェーズのワークフロー、パス変数、サブエージェント委譲パターンを定義 |
| approach-catalog.md | 202 | 改善アプローチカタログ。S/C/N/Mの4カテゴリ、共通ルール、推奨プロンプト構成を定義 |
| scoring-rubric.md | 70 | 採点基準。検出判定基準（○△×）、スコア計算式、推奨判定基準を定義 |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込みガイドライン、品質チェックリストを定義 |
| proven-techniques.md | 70 | エージェント横断の実証済み知見。効果的テクニック、アンチパターン、条件付きテクニック、ベースライン構築ガイドを定義 |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート。バリエーションステータステーブル初期化ロジックを定義 |
| templates/phase0-perspective-resolution.md | 38 | Phase 0: perspective 解決テンプレート。既存検索→フォールバックパターンマッチ→作業コピー生成 |
| templates/phase0-perspective-generation.md | 64 | Phase 0: perspective 自動生成（標準版、4並列批評レビュー） |
| templates/phase0-perspective-generation-simple.md | 30 | Phase 0: perspective 自動生成（簡略版、批評レビューなし） |
| templates/perspective/generate-perspective.md | 67 | perspective 生成サブエージェント。必須スキーマに従って観点定義を生成 |
| templates/perspective/critic-clarity.md | 76 | 明確性批評エージェント。曖昧性・動作一貫性・実行可能性を評価 |
| templates/perspective/critic-generality.md | 82 | 汎用性批評エージェント。業界依存性・規制依存性・技術スタック依存性を評価 |
| templates/perspective/critic-effectiveness.md | 72 | 有効性批評エージェント。品質寄与度・境界明確性を評価 |
| templates/perspective/critic-completeness.md | 106 | 網羅性批評エージェント。未考慮事項検出能力・問題バンク品質を評価 |
| templates/phase1a-variant-generation.md | 42 | Phase 1A: 初回バリアント生成。ベースライン作成+構造分析+2バリアント生成 |
| templates/phase1b-variant-generation.md | 42 | Phase 1B: 継続バリアント生成。knowledge.md ベース選定+audit統合候補提示 |
| templates/phase2-test-document.md | 28 | Phase 2: テスト対象文書・正解キー生成。入力型判定→文書生成→問題埋め込み→正解キー作成 |
| templates/phase3-evaluation.md | 19 | Phase 3: 並列評価実行。各プロンプトを評価対象文書に適用して結果保存 |
| templates/phase3-error-handling.md | 45 | Phase 3: エラーハンドリング分岐ロジック（親が直接実行） |
| templates/phase4-scoring.md | 15 | Phase 4: 採点実行。検出判定（○△×）+ボーナス/ペナルティ計算 |
| templates/phase5-analysis-report.md | 19 | Phase 5: 分析・推奨判定・比較レポート作成。推奨判定基準に基づく7行サマリ返答 |
| templates/phase6-performance-table.md | 40 | Phase 6 Step 1: 性能推移テーブル生成+AskUserQuestion でプロンプト選択 |
| templates/phase6-deploy.md | 20 | Phase 6 Step 1: プロンプトデプロイ（Benchmark Metadata 除去+エージェント定義上書き） |
| templates/phase6-step2-workflow.md | 80 | Phase 6 Step 2: ナレッジ更新+スキル知見フィードバック+次アクション選択（並列実行） |
| templates/phase6a-knowledge-update.md | 49 | Phase 6 Step 2A: knowledge.md 更新。効果テーブル+バリエーションステータス+改善考慮事項更新 |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6 Step 2B: proven-techniques.md 更新。昇格条件判定+エントリ統合+サイズ制限遵守 |
| perspectives/code/best-practices.md | 34 | コードレビュー観点定義: ベストプラクティス（SOLID、エラー処理、ロギング、テスト、可読性、DRY） |
| perspectives/code/consistency.md | 33 | コードレビュー観点定義: 一貫性（コーディングスタイル、命名規約、エラー処理パターン、インポート整理、ユーティリティ活用） |
| perspectives/code/maintainability.md | 43 | コードレビュー観点定義: 保守性（理解容易性、変更影響範囲、テスタビリティ、技術的負債、ドキュメンテーション、YAGNI） |
| perspectives/code/security.md | 37 | コードレビュー観点定義: セキュリティ（インジェクション、認証・セッション、機密データ、アクセス制御、API安全性） |
| perspectives/code/performance.md | 37 | コードレビュー観点定義: パフォーマンス（クエリ効率、ループ・アルゴリズム、I/O・ネットワーク、メモリ管理、キャッシュ） |
| perspectives/design/consistency.md | 51 | 設計レビュー観点定義: 一貫性（命名規約、アーキテクチャパターン、実装パターン、ディレクトリ構造、API/インターフェース） |
| perspectives/design/security.md | 43 | 設計レビュー観点定義: セキュリティ（脅威モデリング、認証・認可、データ保護、入力検証、インフラ・監査） |
| perspectives/design/structural-quality.md | 40 | 設計レビュー観点定義: 構造的品質（SOLID、変更容易性、拡張性、エラーハンドリング、テスタビリティ、API設計） |
| perspectives/design/old/maintainability.md | 43 | （旧版）設計レビュー観点定義: 保守性 |
| perspectives/design/performance.md | 45 | 設計レビュー観点定義: パフォーマンス（アルゴリズム・データ構造、I/O、キャッシュ、レイテンシ・スループット、スケーラビリティ） |
| perspectives/design/reliability.md | 43 | 設計レビュー観点定義: 信頼性・運用性（障害回復、データ整合性、可用性・冗長性、監視・アラート、デプロイ・ロールバック） |
| perspectives/design/old/best-practices.md | 34 | （旧版）設計レビュー観点定義: ベストプラクティス |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 → (継続時: Phase 1B へ戻る)
- Phase 0: 初期化・perspective解決/生成・knowledge.md 初期化。Phase 1A（初回）または Phase 1B（継続）に分岐
- Phase 1A: ベースライン作成+構造分析+2バリアント生成（初回のみ）
- Phase 1B: knowledge.md ベース選定（Broad/Deep）+2バリアント生成+audit統合候補提示（継続時）
- Phase 2: テスト対象文書・正解キー生成（毎ラウンド実行）
- Phase 3: 全プロンプトを並列評価実行（各プロンプト×2回）
- Phase 4: 採点（各プロンプトごとに並列実行）
- Phase 5: 分析・推奨判定・比較レポート作成
- Phase 6: プロンプト選択・デプロイ・ナレッジ更新・スキル知見フィードバック・次アクション選択。継続の場合 Phase 1B へ戻る

データフロー:
- Phase 0: `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md` を生成
- Phase 1A/1B: `prompts/v{NNN}-*.md` を生成
- Phase 2: `test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md` を生成
- Phase 3: `results/v{NNN}-{name}-run{1,2}.md` を生成
- Phase 4: `results/v{NNN}-{name}-scoring.md` を生成。Phase 5 が参照
- Phase 5: `reports/round-{NNN}-comparison.md` を生成。Phase 6 が参照
- Phase 6: デプロイ時に {agent_path} を上書き。`knowledge.md`, `proven-techniques.md` を更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 209-214 | `.agent_audit/{agent_name}/audit-*.md` | Phase 1B で agent_audit の分析結果を参照してバリアント生成の改善候補に統合 |

## D. コンテキスト予算分析
- SKILL.md 行数: 415行
- テンプレートファイル数: 26個、平均行数: 48.5行
- サブエージェント委譲: あり（Phase 0で最大5並列、Phase 1で1、Phase 2で1、Phase 3で最大20並列、Phase 4で最大10並列、Phase 5で1、Phase 6で最大3並列）
- 親コンテキストに保持される情報: agent_name, agent_path, round_number, 累計ラウンド数, Phase 5 の7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）, Phase 4 の採点ファイルパス一覧（カンマ区切り文字列）、Phase 6 の top_techniques（カンマ区切り）
- 3ホップパターンの有無: なし（Phase 3→4→5の連鎖はファイル経由。Phase 6 Step 2の並列実行もファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | エージェント定義が不足している場合に要件ヒアリング | 不明 |
| Phase 1A | AskUserQuestion | 既存プロンプトファイルがある場合に上書き確認 | 不明 |
| Phase 1B | AskUserQuestion | 既存プロンプトファイルがある場合に上書き確認 | 不明 |
| Phase 1B | AskUserQuestion | audit統合候補の承認/個別選択/スキップ | 不明 |
| Phase 2 | AskUserQuestion | サブエージェント失敗時に再試行/中断選択（1回のみ） | 不明 |
| Phase 4 | AskUserQuestion | 採点サブエージェント部分失敗時に再試行/除外/中断選択 | 不明 |
| Phase 6 Step 2 | AskUserQuestion | knowledge.md 更新サマリの承認/却下 | 不明 |
| Phase 6 Step 2 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | 性能推移テーブル提示+プロンプト選択 | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時: Phase 0 でエージェント定義ファイルが読み込めない場合はエラー出力して終了。perspective-source.md が不在の場合はフォールバック検索、それも失敗すれば自動生成。knowledge.md が不在の場合は初期化して Phase 1A へ
- サブエージェント失敗時:
  - Phase 0（perspective解決）: フォールバック検索へ進む。フォールバックも失敗すればエラーメッセージ出力して終了
  - Phase 0（perspective自動生成）: 簡略版失敗時は標準版（4並列批評）にフォールバック。標準版も失敗時はエラーメッセージ+対処法を出力して終了
  - Phase 0（knowledge初期化）: エラー内容を出力してスキル終了
  - Phase 1A: エラーメッセージ+対処法を出力してスキル終了
  - Phase 1B: エラーメッセージ+対処法を出力してスキル終了
  - Phase 2: AskUserQuestion で再試行/中断選択（再試行は1回のみ。2回目失敗で中断）
  - Phase 4: AskUserQuestion で再試行/除外/中断選択（ベースライン失敗時は中断のみ）
  - Phase 5: エラー内容を出力してスキル終了
  - Phase 6（Step 2A, knowledge更新）: エラー内容を出力してスキル終了
  - Phase 6（Step 2B, proven-techniques更新）: 警告を出力して続行（任意のため）
- 部分完了時: Phase 3 で一部評価失敗した場合、Phase 3 のエラーハンドリングテンプレート（親が実行）で分岐判定。Phase 4 で一部採点失敗した場合、ベースライン成功なら AskUserQuestion で再試行/除外/中断選択
- 入力バリデーション: Phase 0 で perspective.md の必須セクション（評価観点、問題バンク）を Grep で検証。不足時はエラーメッセージ+対処法を出力して終了。Phase 6 Step 2A で knowledge.md 更新後に必須セクション（効果テーブル、バリエーションステータス、改善のための考慮事項、最新ラウンドサマリ、ラウンド別スコア推移）を Grep で検証。不足時はエラーメッセージ+対処法を出力して終了

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 | sonnet | phase0-perspective-resolution.md | 1行 | 1 |
| Phase 0（フォールバック1） | sonnet | phase0-perspective-generation-simple.md | 1行 | 1 |
| Phase 0（フォールバック2） | sonnet | phase0-perspective-generation.md（4並列批評含む） | 1行 | 1（内部で4並列） |
| Phase 0（knowledge初期化） | sonnet | knowledge-init-template.md | 1行 | 1 |
| Phase 1A | sonnet | phase1a-variant-generation.md | サマリ（複数セクション） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | サマリ+audit統合候補（該当時） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | テスト対象文書サマリ+埋め込み問題一覧+ボーナス問題リスト | 1 |
| Phase 3 | sonnet | phase3-evaluation.md | 1行（保存完了メッセージ） | プロンプト数×2回（最大20並列） |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ） | プロンプト数（最大10並列） |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1 | sonnet | phase6-performance-table.md | 1行（selected_prompt） | 1 |
| Phase 6 Step 1（デプロイ） | haiku | phase6-deploy.md | 1行 | 1（選択プロンプトがベースライン以外の場合のみ） |
| Phase 6 Step 2A | sonnet | phase6a-knowledge-update.md | 2行（更新完了+top_techniques） | 1 |
| Phase 6 Step 2B | sonnet | phase6b-proven-techniques-update.md | 1行 | 1（Step 2A と並列） |
| perspective自動生成（標準版） | sonnet | perspective/generate-perspective.md | サマリ | 1 |
| perspective批評（並列4） | sonnet | perspective/critic-*.md | 批評結果（セクション形式） | 4（並列） |
