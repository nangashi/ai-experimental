# スキル構造分析: agent_bench

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 372 | メインワークフロー定義（Phase 0-6の実行手順、パス変数の導出、サブエージェント起動指示） |
| approach-catalog.md | 202 | 改善アプローチカタログ（4カテゴリ×複数テクニック×バリエーション、共通ルール、推奨プロンプト構成） |
| scoring-rubric.md | 70 | 採点基準（検出判定○△×、スコア計算式、推奨判定基準、収束判定） |
| test-document-guide.md | 254 | テスト文書生成ガイド（入力型判定、文書構成、問題埋め込みガイドライン、正解キー形式） |
| proven-techniques.md | 70 | エージェント横断実証済みテクニック（効果テーブル、アンチパターン、条件付きテクニック、ベースライン構築ガイド） |
| templates/knowledge-init-template.md | 53 | knowledge.md初期化テンプレート（バリエーションステータステーブル生成指示） |
| templates/phase1a-variant-generation.md | 41 | 初回バリアント生成（ベースライン作成+構造分析+2バリアント生成） |
| templates/phase1b-variant-generation.md | 33 | 継続バリアント生成（知見ベース選定、Broad/Deep判定、audit結果統合） |
| templates/phase2-test-document.md | 33 | テスト文書+正解キー生成（入力型判定、問題埋め込み、ドメイン多様性確保） |
| templates/phase4-scoring.md | 13 | 採点実行（検出判定、ボーナス/ペナルティ判定、スコアサマリ返答） |
| templates/phase5-analysis-report.md | 22 | 比較レポート+推奨判定（スコアマトリクス、収束判定、7行サマリ返答） |
| templates/phase6a-knowledge-update.md | 26 | knowledge.md更新（効果テーブル、バリエーションステータス、ラウンド推移、一般化原則） |
| templates/phase6b-proven-techniques-update.md | 51 | proven-techniques.md更新（Tier判定、統合ルール、サイズ制限、メタデータ更新） |
| templates/perspective/generate-perspective.md | 67 | perspective初期生成（必須スキーマ、評価スコープ5項目、問題バンク） |
| templates/perspective/critic-effectiveness.md | 75 | 有効性批評（寄与度分析、境界明確性検証、3例提示） |
| templates/perspective/critic-completeness.md | 106 | 網羅性批評（欠落検出能力評価、missing element detection、問題バンク品質） |
| templates/perspective/critic-clarity.md | 76 | 明確性批評（表現曖昧性、AI動作一貫性、実行可能性、4フェーズチェックリスト） |
| templates/perspective/critic-generality.md | 82 | 汎用性批評（業界依存性フィルタ、3次元マトリクス評価、汎用化戦略） |
| perspectives/design/security.md | 43 | セキュリティ設計レビュー観点（STRIDE脅威モデリング、認証認可、データ保護、入力検証、インフラ） |
| perspectives/design/performance.md | 45 | パフォーマンス設計レビュー観点（アルゴリズム効率、I/O、キャッシュ、スケーラビリティ） |
| perspectives/design/consistency.md | 39 | 一貫性設計レビュー観点（命名規則、アーキテクチャパターン、エラー処理統一） |
| perspectives/design/reliability.md | 42 | 信頼性設計レビュー観点（エラーハンドリング、リトライ、障害分離、監視・アラート） |
| perspectives/design/structural-quality.md | 47 | 構造品質設計レビュー観点（モジュール境界、依存関係、テスト容易性、ドキュメント） |
| perspectives/code/security.md | 未読 | コードセキュリティレビュー観点 |
| perspectives/code/performance.md | 未読 | コードパフォーマンスレビュー観点 |
| perspectives/code/consistency.md | 未読 | コード一貫性レビュー観点 |
| perspectives/code/best-practices.md | 未読 | コードベストプラクティスレビュー観点 |
| perspectives/code/maintainability.md | 未読 | コード保守性レビュー観点 |
| perspectives/design/old/maintainability.md | 未読 | 旧保守性観点（廃止済み） |
| perspectives/design/old/best-practices.md | 未読 | 旧ベストプラクティス観点（廃止済み） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 → (継続時は1Bへループ)
- 各フェーズの目的:
  - Phase 0: エージェント読み込み、agent_name導出、perspective解決/生成、knowledge.md初期化、初回/継続判定
  - Phase 1A: 初回ラウンド — ベースライン作成+構造分析+2バリアント生成（proven-techniques参照）
  - Phase 1B: 継続ラウンド — 知見ベースバリアント選定（Broad/Deep判定、audit結果統合）
  - Phase 2: テスト文書+正解キー生成（ドメイン多様性確保、8-10問題埋め込み）
  - Phase 3: 並列評価実行（全プロンプト×2回、失敗時の再試行/除外/中断分岐）
  - Phase 4: 採点（検出判定○△×、ボーナス/ペナルティ、スコアサマリ）
  - Phase 5: 比較レポート+推奨判定（スコアマトリクス、収束判定、7行サマリ）
  - Phase 6: プロンプト選択・デプロイ（Step 1: ユーザー確認+haikuデプロイ）→（Step 2A: knowledge更新）→（Step 2B: proven-techniques更新、Step 2C: 次アクション選択）
- データフロー:
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md` 生成
  - Phase 1A/1B → `.agent_bench/{agent_name}/prompts/v{NNN}-*.md` 生成
  - Phase 2 → `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md` 生成
  - Phase 3 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1,2}.md` 生成
  - Phase 4 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md` 生成（Phase 5で参照）
  - Phase 5 → `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md` 生成（Phase 6で参照）
  - Phase 6 → `knowledge.md`, `proven-techniques.md`, `{agent_path}` 更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 42-46 | `.claude/` 配下判定（agent_name導出） | エージェントファイルが `.claude/` 配下かどうかで相対パス計算方式を分岐 |
| SKILL.md | 50-54 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | reviewer パターン（`*-design-reviewer`, `*-code-reviewer`）のフォールバック検索 |
| SKILL.md | 74 | `.claude/skills/agent_bench/perspectives/design/*.md` | 既存 perspective の参照データ収集（perspective 自動生成時） |
| SKILL.md | 174 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit の分析結果をバリアント生成の参考にする（Phase 1B） |
| なし | — | — | その他の外部参照なし（全て `.agent_bench/` または `.claude/skills/agent_bench/` 内） |

## D. コンテキスト予算分析
- SKILL.md 行数: 372行
- テンプレートファイル数: 13個、平均行数: 52行（perspective テンプレート4個除く: 13-4=9個, 平均=40行）
- サブエージェント委譲: あり
  - Phase 0: knowledge初期化（1回）、perspective生成（初期生成1回+批評4並列+再生成最大1回）
  - Phase 1A: バリアント生成（1回）
  - Phase 1B: バリアント生成（1回）
  - Phase 2: テスト文書生成（1回）
  - Phase 3: 並列評価（プロンプト数×2回、同一メッセージ内で並列起動）
  - Phase 4: 採点（プロンプト数、並列起動）
  - Phase 5: 比較レポート（1回）
  - Phase 6 Step 1: デプロイ（haikuサブエージェント、1回、ベースライン以外選択時のみ）
  - Phase 6 Step 2A: knowledge更新（1回）
  - Phase 6 Step 2B: proven-techniques更新（1回）
- 親コンテキストに保持される情報:
  - agent_path, agent_name, perspective_source_path, knowledge.md の累計ラウンド数
  - Phase 1サブエージェントの返答（生成バリアントのサマリ、9行程度）
  - Phase 2サブエージェントの返答（埋め込み問題一覧、15-20行程度）
  - Phase 3の成功/失敗ステータス
  - Phase 4サブエージェントの返答（各プロンプトのスコアサマリ、2行×プロンプト数）
  - Phase 5サブエージェントの返答（7行サマリ: recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 6サブエージェントの返答（1行確認メッセージ×3）
- 3ホップパターンの有無: **なし** — サブエージェント間のデータ受け渡しはファイル経由で行う設計（SKILL.md 24行目の原則5に明記）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | エージェント定義が空または不足時の要件ヒアリング | 不明（ドキュメントに記載なし） |
| Phase 0 | AskUserQuestion | 未指定時のエージェントパス確認 | 不明（ドキュメントに記載なし） |
| Phase 3 | AskUserQuestion | いずれかのプロンプトで成功結果が0回時の確認（再試行/除外/中断） | 不明（ドキュメントに記載なし） |
| Phase 4 | AskUserQuestion | 採点一部失敗時の確認（再試行/除外/中断） | 不明（ドキュメントに記載なし） |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（ベースライン/バリアント）とデプロイ | 不明（ドキュメントに記載なし） |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明（ドキュメントに記載なし） |

## F. エラーハンドリングパターン
- ファイル不在時:
  - エージェントファイル（Phase 0）: 読み込み失敗→エラー出力して終了
  - perspective-source.md（Phase 0）: 見つからない→reviewer パターンフォールバック→自動生成
  - knowledge.md（Phase 0）: 読み込み失敗→初期化して Phase 1A へ
  - audit-*.md（Phase 1B）: Glob で検索、見つからなければ空文字列として処理（オプショナル）
- サブエージェント失敗時:
  - Phase 3（並列評価）: 成功数を集計し分岐。各プロンプトに最低1回成功→警告+Phase 4へ。いずれかのプロンプトで0回成功→ユーザー確認（再試行/除外/中断）
  - Phase 4（採点）: 一部失敗→ユーザー確認（再試行/除外/中断）。ベースライン失敗は中断
  - その他のフェーズ: 未定義（ドキュメントに記載なし）
- 部分完了時:
  - Phase 3: 各プロンプトに最低1回の成功結果がある場合は警告出力して Phase 4 へ進む。Run が1回のみのプロンプトは SD = N/A とする
  - Phase 4: 成功したプロンプトのみで Phase 5 へ進む（ベースライン失敗は中断）
- 入力バリデーション:
  - agent_path 未指定: AskUserQuestion で確認
  - perspective 生成後の検証: 必須セクションの存在確認。検証失敗→エラー出力してスキル終了
  - その他: 未定義（ドキュメントに記載なし）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 | sonnet | knowledge-init-template.md | 1行（確認メッセージ） | 1 |
| Phase 0 | sonnet | perspective/generate-perspective.md | 4行（サマリ: 観点、入力型、評価スコープ、問題バンク） | 1（初回生成） |
| Phase 0 | sonnet | perspective/critic-effectiveness.md | 可変（重大な問題/改善提案/確認） | 4並列（批評） |
| Phase 0 | sonnet | perspective/critic-completeness.md | 可変（重大な問題/Missing Element Detection/改善提案/確認） | 4並列（批評） |
| Phase 0 | sonnet | perspective/critic-clarity.md | 可変（重大な問題/改善提案/確認） | 4並列（批評） |
| Phase 0 | sonnet | perspective/critic-generality.md | 可変（重大な問題/Scope Item Generality/Problem Bank Generality/改善提案/確認） | 4並列（批評） |
| Phase 0 | sonnet | perspective/generate-perspective.md | 4行（サマリ） | 1（再生成、最大1回） |
| Phase 1A | sonnet | phase1a-variant-generation.md | 可変（エージェント定義+構造分析+バリアント2個、約20-30行） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 可変（選定プロセス+バリアント2個、約15-20行） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 可変（テスト文書サマリ+埋め込み問題一覧+ボーナス、約15-20行） | 1 |
| Phase 3 | sonnet | なし（直接指示） | 1行（保存完了メッセージ） | (ベースライン1+バリアント数)×2回 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ） | ベースライン1+バリアント数 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1 | haiku | なし（直接指示） | 1行（デプロイ完了メッセージ） | 1（ベースライン以外選択時のみ） |
| Phase 6 Step 2A | sonnet | phase6a-knowledge-update.md | 1行（更新完了メッセージ） | 1 |
| Phase 6 Step 2B | sonnet | phase6b-proven-techniques-update.md | 1行（更新完了メッセージまたは更新なし） | 1 |
