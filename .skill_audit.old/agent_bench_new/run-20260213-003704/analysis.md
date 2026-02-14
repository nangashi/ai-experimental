# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 390 | スキルのメインワークフロー定義。Phase 0-6の実行手順、パス変数、サブエージェント委譲パターンを記述 |
| approach-catalog.md | 202 | 改善アプローチカタログ。4カテゴリ(S/C/N/M)のテクニック・バリエーション定義と共通ルール |
| scoring-rubric.md | 70 | 採点基準。検出判定(○△×)、スコア計算式、ボーナス/ペナルティ、推奨判定・収束判定基準 |
| proven-techniques.md | 70 | エージェント横断の実証済み知見。効果テクニック、アンチパターン、条件付きテクニック、ベースライン構築ガイド |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込みルール、正解キーフォーマット |
| perspectives/code/best-practices.md | 34 | コードレビュー観点定義（ベストプラクティス） |
| perspectives/code/consistency.md | 33 | コードレビュー観点定義（一貫性） |
| perspectives/code/maintainability.md | 43 | コードレビュー観点定義（保守性） |
| perspectives/code/security.md | 37 | コードレビュー観点定義（セキュリティ） |
| perspectives/code/performance.md | 37 | コードレビュー観点定義（パフォーマンス） |
| perspectives/design/consistency.md | 51 | 設計レビュー観点定義（一貫性） |
| perspectives/design/security.md | 43 | 設計レビュー観点定義（セキュリティ） |
| perspectives/design/structural-quality.md | 41 | 設計レビュー観点定義（構造的品質） |
| perspectives/design/performance.md | 45 | 設計レビュー観点定義（パフォーマンス） |
| perspectives/design/reliability.md | 43 | 設計レビュー観点定義（信頼性） |
| perspectives/design/old/best-practices.md | 34 | 旧版設計レビュー観点定義（ベストプラクティス、未使用） |
| perspectives/design/old/maintainability.md | 43 | 旧版設計レビュー観点定義（保守性、未使用） |
| templates/knowledge-init-template.md | 52 | knowledge.md初期化手順。バリエーションステータステーブル生成、効果テーブル初期化 |
| templates/phase0-perspective-resolution.md | 40 | perspective解決手順（既存検索→フォールバックパターンマッチ→作業コピー作成） |
| templates/phase0-perspective-generation.md | 88 | perspective自動生成手順（要件抽出→モード選択→初期生成→4並列批評→再生成→検証） |
| templates/phase0-perspective-generation-simple.md | 30 | perspective簡易生成手順（批評スキップ版） |
| templates/phase0-perspective-validation.md | 21 | perspective検証手順（必須セクション確認） |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: ベースライン作成+バリアント生成（初回ラウンド） |
| templates/phase1b-variant-generation.md | 42 | Phase 1B: knowledge.mdベース+audit統合のバリアント生成（継続ラウンド） |
| templates/phase2-test-document.md | 33 | Phase 2: テスト対象文書・正解キー生成手順 |
| templates/phase3-evaluation.md | 19 | Phase 3: サブエージェントによるエージェント実行手順 |
| templates/phase3-error-handling.md | 45 | Phase 3: エラーハンドリング分岐ロジック（親が直接実行） |
| templates/phase4-scoring.md | 13 | Phase 4: 採点手順（問題別検出判定+ボーナス/ペナルティ） |
| templates/phase5-analysis-report.md | 22 | Phase 5: 比較レポート作成・推奨判定手順 |
| templates/phase6a-knowledge-update.md | 29 | Phase 6A: knowledge.md更新手順（効果テーブル・ラウンド別推移・一般化原則） |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B: proven-techniques.md更新手順（昇格条件・統合ルール・サイズ制限） |
| templates/phase6-deploy.md | 20 | Phase 6: プロンプトデプロイ手順（メタデータ除去→上書き） |
| templates/phase6-extract-top-techniques.md | 16 | Phase 6: 効果テーブル上位3件抽出手順 |
| templates/phase6-performance-table.md | 40 | Phase 6: 性能推移テーブル生成+ユーザープロンプト選択手順 |
| templates/perspective/generate-perspective.md | 67 | perspective生成サブエージェント用テンプレート（必須スキーマ・生成ガイドライン） |
| templates/perspective/critic-clarity.md | 76 | perspective批評（表現明確性・AI動作一貫性） |
| templates/perspective/critic-generality.md | 82 | perspective批評（汎用性・業界依存性フィルタ） |
| templates/perspective/critic-effectiveness.md | 73 | perspective批評（有効性・品質寄与度・境界明確性） |
| templates/perspective/critic-completeness.md | 108 | perspective批評（網羅性・未考慮事項検出能力・問題バンク品質） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1A/1B（分岐） → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
- **Phase 0（初期化）**: エージェントファイル読み込み→agent_name導出→perspective解決/自動生成→knowledge.md初期化判定→Phase 1A/1B分岐
- **Phase 1A（初回）**: ベースライン作成（proven-techniques.mdガイド準拠）+バリアント生成（構造ギャップ分析ベース）
- **Phase 1B（継続）**: knowledge.mdベース（Broad/Deep選定）+audit統合候補のバリアント生成
- **Phase 2（テスト文書生成）**: perspective.md+knowledge.mdを参照してテスト対象文書・正解キー生成（毎ラウンド）
- **Phase 3（並列評価）**: 全プロンプト×2回の並列実行→エラーハンドリング分岐（親で実行）
- **Phase 4（採点）**: プロンプトごとに採点サブエージェント並列起動→scoring-rubric.mdに従い採点→失敗時の再試行/除外分岐
- **Phase 5（分析・推奨）**: 比較レポート作成→推奨判定（scoring-rubric.md基準）→収束判定→7行サマリ返答
- **Phase 6（デプロイ・知見蓄積）**: Step 1（性能推移テーブル+ユーザープロンプト選択→デプロイ）→ Step 2（A: knowledge.md更新 → B+C並列: proven-techniques.md更新+次アクション選択）

- データフロー:
  - Phase 0: perspective-source.md/perspective.md/knowledge.md 生成 → Phase 1/2で参照
  - Phase 1: prompts/*.md 生成 → Phase 3で実行
  - Phase 2: test-document-round-{N}.md/answer-key-round-{N}.md 生成 → Phase 3/4で参照
  - Phase 3: results/v{N}-{name}-run{1,2}.md 生成 → Phase 4で採点
  - Phase 4: results/v{N}-{name}-scoring.md 生成 → Phase 5で分析
  - Phase 5: reports/round-{N}-comparison.md 生成 → Phase 6で知見蓄積
  - Phase 6: knowledge.md/proven-techniques.md 更新 → 次ラウンドの Phase 1Bで参照

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 171-174 | `.agent_audit/{agent_name}/audit-*.md` | agent_auditスキルの出力ディレクトリを直接参照してaudit結果を取得（Phase 1B） |

## D. コンテキスト予算分析
- SKILL.md 行数: 390行
- テンプレートファイル数: 23個、平均行数: 47行
- サブエージェント委譲: あり
  - Phase 0: perspective解決（1サブ）、perspective自動生成（1+4並列批評+再生成、または簡易版1サブ）、perspective検証（1サブ）、knowledge初期化（1サブ）
  - Phase 1A/1B: バリアント生成（各1サブ）
  - Phase 2: テスト文書生成（1サブ）
  - Phase 3: 並列評価（全プロンプト×2回の並列サブエージェント）
  - Phase 4: 採点（プロンプトごとに1サブ、並列）
  - Phase 5: 分析・レポート（1サブ）
  - Phase 6: 性能推移テーブル（1サブ）、デプロイ（1サブ、haiku）、knowledge更新（1サブ）、上位3件抽出（1サブ）、proven-techniques更新（1サブ）
- 親コンテキストに保持される情報: agent_name、agent_path、perspective_path、knowledge_path、累計ラウンド数、Phase 5の7行サマリ、選択されたプロンプト名、Phase 3/4の成功数集計
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しはファイル経由に統一済み）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義不足時の要件ヒアリング | 不明 |
| Phase 0 | AskUserQuestion | perspective自動生成モード選択（標準/簡略） | 不明 |
| Phase 1A | AskUserQuestion | 既存プロンプトファイルの上書き確認 | 不明 |
| Phase 1B | AskUserQuestion | 既存プロンプトファイルの上書き確認 | 不明 |
| Phase 1B | AskUserQuestion | audit統合候補の選択（全て統合/個別選択/スキップ） | 不明 |
| Phase 2 | AskUserQuestion | サブエージェント失敗時の再試行/中断選択 | 不明 |
| Phase 3 | AskUserQuestion | ベースライン全失敗時の再試行/中断選択 | 不明 |
| Phase 3 | AskUserQuestion | バリアント全失敗時の再試行/除外/中断選択 | 不明 |
| Phase 4 | AskUserQuestion | 採点サブエージェント一部失敗時の再試行/除外/中断選択 | 不明 |
| Phase 6 | AskUserQuestion | 性能推移テーブル提示+プロンプト選択 | 不明 |
| Phase 6 | AskUserQuestion | 次アクション選択（次ラウンドへ/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: agent_path読み込み失敗→エラー出力して終了
  - Phase 0: perspective-source.md不在→フォールバックパターンマッチ→検索失敗時は自動生成へ
  - Phase 0: knowledge.md不在→初期化して Phase 1Aへ、存在→Phase 1Bへ
  - Phase 0: perspective検証失敗→エラーメッセージ出力して終了
- サブエージェント失敗時:
  - Phase 0 perspective解決: 失敗時→perspective自動生成を実行
  - Phase 0 perspective自動生成: 失敗時→エラーメッセージ+対処法を出力して終了
  - Phase 0 knowledge初期化: 失敗時→エラー出力して終了
  - Phase 1A/1B: 失敗時→エラー出力して終了
  - Phase 2: 失敗時→AskUserQuestionで「再試行（1回のみ）/中断」選択
  - Phase 3: templates/phase3-error-handling.mdの分岐ロジックに従う（全失敗/部分失敗のパターン別処理）
  - Phase 4: ベースライン失敗時→中断、一部失敗時→AskUserQuestionで「再試行（1回のみ）/除外/中断」選択
  - Phase 5: 失敗時→エラー出力して終了
  - Phase 6B proven-techniques更新: 失敗時→警告を出力して続行（任意処理のため）
- 部分完了時:
  - Phase 3: ベースライン最低1回成功かつ各バリアント最低1回成功→警告出力してPhase 4へ（SD=N/Aで採点）
  - Phase 4: ベースライン成功かつバリアント一部失敗→成功プロンプトのみで Phase 5へ
- 入力バリデーション:
  - Phase 0: エージェントファイル行数<10または必要セクション不足→AskUserQuestionで要件ヒアリング
  - Phase 0: perspective-source.md必須セクション不在→エラーメッセージ+対処法を出力して終了

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 | sonnet | phase0-perspective-resolution.md | 1行（成功/失敗） | 1 |
| Phase 0 | sonnet | phase0-perspective-generation.md | 1行（完了通知） | 1 |
| Phase 0 | sonnet | phase0-perspective-generation-simple.md | 1行（完了通知） | 1 |
| Phase 0 | sonnet | perspective/generate-perspective.md | サマリ（観点名、入力型、評価スコープ、問題バンク件数） | 1 |
| Phase 0 | sonnet | perspective/critic-clarity.md | 批評結果（重大な問題、改善提案、確認） | 4並列 |
| Phase 0 | sonnet | perspective/critic-generality.md | 批評結果（重大な問題、スコープ項目分類、問題バンク分類、改善提案、確認） | 4並列 |
| Phase 0 | sonnet | perspective/critic-effectiveness.md | 批評結果（重大な問題、改善提案、確認） | 4並列 |
| Phase 0 | sonnet | perspective/critic-completeness.md | 批評結果（重大な問題、未考慮事項検出評価テーブル、問題バンク改善提案、その他改善提案、確認） | 4並列 |
| Phase 0 | sonnet | phase0-perspective-validation.md | 1行（valid/invalid） | 1 |
| Phase 0 | sonnet | knowledge-init-template.md | 1行（初期化完了通知+バリエーション数） | 1 |
| Phase 1A | sonnet | phase1a-variant-generation.md | サマリ（エージェント定義、構造分析結果、生成バリアント） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | サマリ（選定プロセス、生成バリアント、audit統合候補（該当時）） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | サマリ（入力型、行数、テーマ、埋め込み問題一覧、ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | phase3-evaluation.md | 1行（保存完了通知） | (プロンプト数×2)並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（平均スコア+SD、Run1/Run2詳細） | プロンプト数並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended、reason、convergence、scores、variants、deploy_info、user_summary） | 1 |
| Phase 6 | sonnet | phase6-performance-table.md | 1行（selected_prompt: {name}） | 1 |
| Phase 6 | haiku | phase6-deploy.md | 1行（デプロイ完了通知） | 1 |
| Phase 6 | sonnet | phase6a-knowledge-update.md | 1行（更新完了通知+累計ラウンド数） | 1 |
| Phase 6 | sonnet | phase6-extract-top-techniques.md | 1行（カンマ区切りテクニック名） | 1 |
| Phase 6 | sonnet | phase6b-proven-techniques-update.md | 1行（更新完了通知または更新なし通知） | 1 |
