# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 399 | スキル本体。Phase 0-6 のワークフロー定義、パス変数管理、サブエージェント委譲ロジック |
| approach-catalog.md | 202 | 改善アプローチカタログ。S/C/N/M カテゴリの3階層（カテゴリ→テクニック→バリエーション）管理 |
| scoring-rubric.md | 70 | 採点基準。検出判定（○△×）、スコア計算式、ボーナス/ペナルティ、安定性閾値、推奨判定基準、収束判定 |
| proven-techniques.md | 70 | エージェント横断実証済み知見。Section 1-4（実証済み効果/アンチパターン/条件付き/ベースライン構築ガイド） |
| test-document-guide.md | 45 | テスト対象文書生成ガイド（親用）。品質チェックリスト、ラウンド間多様性確保 |
| test-document-guide-subagent.md | 215 | テスト対象文書生成ガイド（サブエージェント用）。入力型判定、文書構成、問題埋め込み、正解キーフォーマット |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート。バリエーションステータステーブル、スコア推移テーブル構造定義 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A サブエージェント指示。ベースライン作成+2バリアント生成（初回、Broad モード） |
| templates/phase1b-variant-generation.md | 34 | Phase 1B サブエージェント指示。知見ベースバリアント生成（継続、Broad/Deep 分岐）、audit 結果参照 |
| templates/phase2-test-document.md | 33 | Phase 2 サブエージェント指示。テスト対象文書+正解キー生成、問題バンク参照 |
| templates/phase3-evaluation.md | 12 | Phase 3 サブエージェント指示。プロンプト実行→結果保存（並列実行） |
| templates/phase4-scoring.md | 19 | Phase 4 サブエージェント指示。採点実行（検出判定+ボーナス/ペナルティ）、スコアサマリ返答 |
| templates/phase5-analysis-report.md | 23 | Phase 5 サブエージェント指示。比較レポート作成、推奨判定、収束判定、7行サマリ返答 |
| templates/phase6a-knowledge-update.md | 27 | Phase 6A サブエージェント指示。knowledge.md 更新（効果テーブル、バリエーションステータス、スコア推移、最新サマリ、改善考慮事項） |
| templates/phase6a-deploy.md | 14 | Phase 6A サブエージェント指示。選択プロンプトのデプロイ（Metadata 除去→上書き） |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B サブエージェント指示。proven-techniques.md 更新（昇格条件判定、preserve+integrate、サイズ制限） |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成テンプレート。必須スキーマ、生成ガイドライン |
| templates/perspective/critic-completeness.md | 107 | perspective 批評（網羅性）。スコープカバレッジ、欠落要素検出能力、問題バンク品質 |
| templates/perspective/critic-clarity.md | 76 | perspective 批評（明確性）。表現曖昧性、AI動作一貫性、実行可能性 |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評（有効性）。品質寄与度、他観点との境界明確性 |
| templates/perspective/critic-generality.md | 82 | perspective 批評（汎用性）。業界依存性、規制依存性、技術スタック依存性 |
| perspectives/design/security.md | 43 | セキュリティ観点定義（設計レビュー用）。参照用サンプル |
| perspectives/design/performance.md | - | パフォーマンス観点定義（設計レビュー用） |
| perspectives/design/consistency.md | - | 一貫性観点定義（設計レビュー用） |
| perspectives/design/structural-quality.md | - | 構造的品質観点定義（設計レビュー用） |
| perspectives/design/reliability.md | - | 信頼性観点定義（設計レビュー用） |
| perspectives/code/security.md | - | セキュリティ観点定義（コードレビュー用） |
| perspectives/code/performance.md | - | パフォーマンス観点定義（コードレビュー用） |
| perspectives/code/consistency.md | - | 一貫性観点定義（コードレビュー用） |
| perspectives/code/best-practices.md | - | ベストプラクティス観点定義（コードレビュー用） |
| perspectives/code/maintainability.md | - | 保守性観点定義（コードレビュー用） |

## B. ワークフロー概要

### フェーズ構成
Phase 0 → Phase 1A/1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → (Phase 1B へループまたは終了)

### 各フェーズの目的
- **Phase 0**: エージェントファイル読み込み、agent_name 導出、perspective 解決（検索→フォールバック→自動生成）、knowledge.md 初期化、Phase 1A/1B 分岐判定
- **Phase 1A**: 初回ラウンド。ベースライン作成（新規/既存）+2バリアント生成（Broad モード、構造ギャップ分析）
- **Phase 1B**: 継続ラウンド。知見ベースバリアント生成（Broad/Deep 分岐、audit 結果参照）、ベースラインコピー
- **Phase 2**: テスト対象文書+正解キー生成（ドメイン多様性、問題バンク参照、8-10問埋め込み）
- **Phase 3**: 並列評価実行（プロンプト×2回、収束時は1回、失敗時再試行/除外/中断分岐）
- **Phase 4**: 採点（検出判定○△×、ボーナス/ペナルティ、並列実行、失敗時再試行/除外/中断分岐）
- **Phase 5**: 分析レポート作成、推奨判定、収束判定、7行サマリ返答
- **Phase 6**: Step 1（プロンプト選択+デプロイ）、Step 2A（knowledge.md 更新）、Step 2B（proven-techniques.md 更新）、Step 2C（次アクション選択）

### データフロー
| 生成フェーズ | 生成ファイル | 参照フェーズ |
|------------|------------|------------|
| Phase 0 | `.agent_bench/{agent_name}/perspective-source.md` | Phase 1A/1B/2 |
| Phase 0 | `.agent_bench/{agent_name}/perspective.md` | Phase 1A/1B/2/4 |
| Phase 0 | `.agent_bench/{agent_name}/knowledge.md` | Phase 1B/2/5/6A/6B |
| Phase 1A/1B | `.agent_bench/{agent_name}/prompts/v{NNN}-baseline.md` | Phase 3/4/5/6 |
| Phase 1A/1B | `.agent_bench/{agent_name}/prompts/v{NNN}-variant-*.md` | Phase 3/4/5/6 |
| Phase 2 | `.agent_bench/{agent_name}/test-document-round-{NNN}.md` | Phase 3 |
| Phase 2 | `.agent_bench/{agent_name}/answer-key-round-{NNN}.md` | Phase 4 |
| Phase 3 | `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md` | Phase 4 |
| Phase 4 | `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md` | Phase 5 |
| Phase 5 | `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md` | Phase 6A/6B |
| Phase 6A | `{agent_path}` （デプロイ） | 次ラウンド Phase 1B |
| Phase 6A | `knowledge.md` （更新） | 次ラウンド Phase 1B/2 |
| Phase 6B | `proven-techniques.md` （更新） | 次ラウンド Phase 1A/1B |

## C. 外部参照の検出

| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | perspective フォールバックパターン（reviewer 命名規則検出時） |
| SKILL.md | 84 | `.claude/skills/agent_bench_new/perspectives/design/security.md` | perspective 自動生成時の参照サンプル |
| SKILL.md | 193 | `.agent_audit/{agent_name}/run-*/audit-*.md` | Phase 1B で agent_audit の分析結果を参照（基準有効性+スコープ整合性） |
| templates/phase1b-variant-generation.md | 8 | `{audit_dim1_path}`, `{audit_dim2_path}` | agent_audit 結果の参照（バリアント生成の参考） |

## D. コンテキスト予算分析

### サイズメトリクス
- **SKILL.md 行数**: 399行
- **テンプレートファイル数**: 16個（knowledge-init, phase1a, phase1b, phase2, phase3, phase4, phase5, phase6a-deploy, phase6a-knowledge, phase6b, perspective/generate, perspective/critic × 4）
- **平均行数**: 約47行（最小12行〜最大107行）
- **参照ファイル**: approach-catalog（202行）、scoring-rubric（70行）、proven-techniques（70行）、test-document-guide-subagent（215行）

### サブエージェント委譲パターン
- **委譲フェーズ**: Phase 0（knowledge 初期化, perspective 自動生成+批評×4）, Phase 1A/1B（バリアント生成）, Phase 2（テスト文書生成）, Phase 3（並列評価）, Phase 4（採点）, Phase 5（分析レポート）, Phase 6A（デプロイ, knowledge 更新）, Phase 6B（proven-techniques 更新）
- **並列実行**: Phase 0（perspective 批評4並列）, Phase 3（プロンプト数×2回並列）, Phase 4（プロンプト数並列）
- **委譲内容**: 大量テキスト生成（バリアント、テスト文書、レポート）、テーブル操作（knowledge.md, proven-techniques.md）、繰り返し実行（評価、採点）

### 親コンテキスト保持情報
- **メタデータのみ**: agent_name, agent_path, 累計ラウンド数, perspective_source_path, perspective_path
- **サマリのみ**: Phase 1A/1B（バリアント生成結果サマリ）, Phase 2（問題サマリ）, Phase 4（スコアサマリ）, Phase 5（7行サマリ）
- **ファイル経由**: 詳細データは全てファイルに保存し、サブエージェント間でファイル経由で受け渡し

### 3ホップパターン
- **なし**: サブエージェント間のデータ受け渡しは全てファイル経由。親は中継せず、パス変数のみ指定

## E. ユーザーインタラクションポイント

| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | エージェント定義が空または不足時のヒアリング（目的・入出力・ツール・制約） | 不明 |
| Phase 0 | AskUserQuestion | perspective 自動生成時の重大問題・改善提案確認（再生成判定） | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の再試行/除外/中断確認 | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の再試行/除外/中断確認 | 不明 |
| Phase 6 | AskUserQuestion | プロンプト選択（性能推移テーブル+推奨理由+収束判定を提示） | 不明 |
| Phase 6 | AskUserQuestion | デプロイ確認（差分プレビュー提示） | 不明 |
| Phase 6 | AskUserQuestion | 次アクション選択（次ラウンド/終了、収束判定・最低ラウンド数達成を付記） | 不明 |

## F. エラーハンドリングパターン

### ファイル不在時
- **agent_path 読み込み失敗**: エラー出力して終了
- **perspective-source.md 不在**: フォールバックパターン検索→自動生成（Step 1-6）
- **knowledge.md 不在**: 初期化（knowledge-init-template サブエージェント）
- **audit 結果不在**: 空文字列として Phase 1B テンプレートに渡す（audit なしでバリアント生成）

### サブエージェント失敗時
- **Phase 0（perspective 自動生成）検証失敗**: エラー出力してスキル終了
- **Phase 3（評価）失敗**: 成功数を集計し分岐（全成功→Phase 4、一部成功→警告+Phase 4、全失敗→再試行/除外/中断）
- **Phase 4（採点）失敗**: 成功数を集計し分岐（全成功→Phase 5、一部失敗→再試行/除外/中断、ベースライン失敗時は中断）

### 部分完了時
- **Phase 3**: 各プロンプトに最低1回の成功結果があれば継続可能（SD = N/A）
- **Phase 4**: ベースライン以外の採点失敗は除外して継続可能

### 入力バリデーション
- **agent_path 未指定**: AskUserQuestion で確認
- **knowledge.md の構造検証**: 必須セクション（「バリエーションステータス」「ラウンド別スコア推移」）の存在確認→失敗時は再初期化
- **perspective 検証**: 必須セクション（「概要」「評価スコープ」「スコープ外」「ボーナス/ペナルティ判定指針」「問題バンク」）の存在確認→失敗時はエラー終了

## G. サブエージェント一覧

| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（knowledge 初期化） | sonnet | knowledge-init-template.md | 1行（確認） | 1 |
| Phase 0（perspective 自動生成） | sonnet | perspective/generate-perspective.md | 4行（サマリ） | 1 |
| Phase 0（perspective 批評） | sonnet | perspective/critic-{completeness,clarity,effectiveness,generality}.md | 可変（批評結果） | 4並列 |
| Phase 1A | sonnet | phase1a-variant-generation.md | 可変（構造分析+バリアント2件） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 可変（選定プロセス+バリアント2件） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 可変（問題サマリ） | 1 |
| Phase 3 | sonnet | phase3-evaluation.md | 1行（保存完了確認） | (プロンプト数 × 2回)〜(プロンプト数 × 1回) 並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2-3行（スコアサマリ） | プロンプト数 並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6A（デプロイ） | haiku | phase6a-deploy.md | 1行（デプロイ完了確認） | 1 |
| Phase 6A（knowledge 更新） | sonnet | phase6a-knowledge-update.md | 1行（更新完了確認） | 1 |
| Phase 6B（proven-techniques 更新） | sonnet | phase6b-proven-techniques-update.md | 1行（更新完了/更新なし確認） | 1 |
