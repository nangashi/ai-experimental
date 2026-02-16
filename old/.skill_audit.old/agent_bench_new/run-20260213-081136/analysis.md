# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 372 | メインワークフロー定義。Phase 0-6の処理フロー、パス変数、コンテキスト節約原則を記載 |
| approach-catalog.md | 202 | 改善アプローチカタログ。S/C/N/M の4カテゴリ、バリエーション定義、実証済み効果の記録 |
| scoring-rubric.md | 70 | 採点基準。検出判定（○△×）、スコア計算式、安定性閾値、推奨判定基準、収束判定 |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込みガイドライン、正解キーフォーマット |
| proven-techniques.md | 70 | エージェント横断の実証済み知見。効果テクニック、アンチパターン、条件付きテクニック、ベースライン構築ガイド |
| perspectives/code/best-practices.md | 34 | 観点定義（コード）。SOLID、DRY、エラー処理、ロギング、テスト品質、可読性 |
| perspectives/code/consistency.md | 33 | 観点定義（コード）。コーディングスタイル、命名規約、エラーパターン統一、ユーティリティ活用 |
| perspectives/code/maintainability.md | 未読 | 観点定義（コード）。保守性関連 |
| perspectives/code/security.md | 未読 | 観点定義（コード）。セキュリティ脆弱性 |
| perspectives/code/performance.md | 未読 | 観点定義（コード）。パフォーマンス最適化 |
| perspectives/design/security.md | 43 | 観点定義（設計）。脅威モデリング、認証・認可、データ保護、入力検証、インフラ・監査 |
| perspectives/design/performance.md | 45 | 観点定義（設計）。アルゴリズム効率、I/O、キャッシュ、レイテンシ、スケーラビリティ |
| perspectives/design/consistency.md | 未読 | 観点定義（設計）。既存設計との整合性 |
| perspectives/design/reliability.md | 未読 | 観点定義（設計）。信頼性・障害回復 |
| perspectives/design/structural-quality.md | 41 | 観点定義（設計）。SOLID、変更容易性、拡張性、エラーハンドリング、テスタビリティ、API/データモデル |
| perspectives/design/old/maintainability.md | 未読 | 旧版の観点定義（設計） |
| perspectives/design/old/best-practices.md | 未読 | 旧版の観点定義（設計） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート。バリエーションステータステーブル生成 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A（初回）。ベースライン作成+バリアント2個生成 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B（継続）。knowledge.md ベースのバリアント生成（Broad/Deep モード分岐） |
| templates/phase2-test-document.md | 33 | Phase 2。テスト対象文書+正解キー生成（毎ラウンド） |
| templates/phase4-scoring.md | 13 | Phase 4。採点実行（並列、プロンプト毎） |
| templates/phase5-analysis-report.md | 22 | Phase 5。比較レポート作成+推奨判定（7行サマリ返答） |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A。knowledge.md 更新（バリエーションステータス、スコア推移、一般化原則） |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B。proven-techniques.md への知見昇格（Tier 1/2/3 判定、統合ルール） |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成。必須スキーマ、入力型判定、問題バンク作成 |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評（有効性）。寄与度分析、境界明確性検証 |
| templates/perspective/critic-completeness.md | 未読 | perspective 批評（網羅性） |
| templates/perspective/critic-clarity.md | 未読 | perspective 批評（明確性） |
| templates/perspective/critic-generality.md | 未読 | perspective 批評（汎用性） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6（6A+6B+6C）
- 各フェーズの目的:
  - **Phase 0**: 初期化・状態検出（agent_path 読み込み、agent_name 導出、perspective 解決/自動生成、knowledge.md 初期化/継続判定）
  - **Phase 1A**: 初回ベースライン作成+バリアント2個生成（proven-techniques ガイドベース）
  - **Phase 1B**: 継続バリアント生成（knowledge.md ベース、Broad/Deep モード分岐）
  - **Phase 2**: テスト対象文書+正解キー生成（毎ラウンド、ドメイン多様性確保）
  - **Phase 3**: 並列評価実行（各プロンプト×2回、N並列サブエージェント起動）
  - **Phase 4**: 採点（並列、プロンプト毎に採点サブエージェント、○△× 判定+ボーナス/ペナルティ）
  - **Phase 5**: 比較レポート作成+推奨判定（7行サマリ返答: recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - **Phase 6**: デプロイ+ナレッジ更新+次アクション（6A=knowledge.md 更新、6B=proven-techniques.md 昇格、6C=次ラウンド/終了選択）
- データフロー:
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md` (初回のみ)
  - Phase 1A/1B → `.agent_bench/{agent_name}/prompts/v{NNN}-*.md`
  - Phase 2 → `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
  - Phase 3 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1|2}.md`
  - Phase 4 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md`
  - Phase 5 → `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
  - Phase 6A → `knowledge.md` 更新（累計ラウンド数+1、バリエーションステータス更新、スコア推移追記）
  - Phase 6B → `proven-techniques.md` 更新（Tier 1/2/3 昇格判定）
  - Phase 6 デプロイ → `{agent_path}` 上書き（ベースライン以外選択時のみ、haiku サブエージェント）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | Phase 0: perspective フォールバックパターン検索（reviewer パターン一致時） |
| SKILL.md | 74 | `.claude/skills/agent_bench/perspectives/design/*.md` | Phase 0: perspective 自動生成時の参照データ収集 |
| templates/phase1a-variant-generation.md | 9 | `{proven_techniques_path}` = `.claude/skills/agent_bench/proven-techniques.md` | Phase 1A: ベースライン構築ガイド参照 |
| templates/phase1a-variant-generation.md | 9 | `{approach_catalog_path}` = `.claude/skills/agent_bench/approach-catalog.md` | Phase 1A: 推奨構成・改善戦略参照 |
| templates/phase1b-variant-generation.md | 7 | `{proven_techniques_path}` = `.claude/skills/agent_bench/proven-techniques.md` | Phase 1B: アンチパターン回避用 |
| templates/phase1b-variant-generation.md | 14 | `{approach_catalog_path}` = `.claude/skills/agent_bench/approach-catalog.md` | Phase 1B: Deep モード時の詳細参照（条件付き） |
| templates/phase1b-variant-generation.md | 8 | `.agent_audit/{agent_name}/audit-*.md` | Phase 1B: agent_audit 分析結果の参照（存在時のみ） |

**注**: `.claude/skills/agent_bench/` への参照は外部参照（スキルディレクトリが異なるため）。`.agent_bench/` および `.agent_audit/` は作業ディレクトリとして許容範囲内。

## D. コンテキスト予算分析
- SKILL.md 行数: 372行
- テンプレートファイル数: 13個、平均行数: 38行（最小13行 phase4-scoring.md / 最大75行 critic-effectiveness.md）
- サブエージェント委譲: あり
  - **Phase 0**: perspective 自動生成（Step 3: generate-perspective.md, Step 4: 4並列批評, Step 5: 再生成1回）、knowledge.md 初期化
  - **Phase 1A/1B**: バリアント生成（1サブエージェント）
  - **Phase 2**: テスト文書生成（1サブエージェント）
  - **Phase 3**: 並列評価（N = (ベースライン+バリアント数) × 2回）
  - **Phase 4**: 採点（N = プロンプト数、並列）
  - **Phase 5**: 分析レポート（1サブエージェント）
  - **Phase 6**: デプロイ（haiku、1サブエージェント）、6A=knowledge 更新（1サブエージェント）、6B=proven-techniques 更新（1サブエージェント）
- 親コンテキストに保持される情報:
  - agent_path, agent_name, perspective_source_path, perspective_path, knowledge_path
  - 累計ラウンド数（knowledge.md から抽出、各 Phase で使用）
  - Phase 1-5 サブエージェントの返答（要約・メタデータのみ。Phase 5 は7行サマリ）
  - プロンプトファイルパス一覧（Phase 3-4 で使用）
  - Phase 4 スコアサマリ（1行/プロンプト）
- 3ホップパターンの有無: **なし**
  - Phase 1B → Phase 2: `.agent_audit/{agent_name}/audit-*.md` をファイル経由で参照（親は audit ファイルのパスリストのみ保持）
  - Phase 2 → Phase 3: test-document/answer-key ファイルパスを保持
  - Phase 4 → Phase 5: scoring ファイルパスのリストを Phase 5 サブエージェントに渡す（親は1行スコアサマリのみ保持）
  - Phase 5 → Phase 6: report ファイルパスを保持（親は7行サマリのみ保持）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が空/不足の場合のヒアリング（目的、入出力、ツール・制約） | 不明 |
| Phase 3 | AskUserQuestion | いずれかのプロンプトで成功結果が0回の場合の確認（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点タスクが一部失敗した場合の確認（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル+推奨判定+収束判定を提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

**計6箇所**。Fast mode での挙動は SKILL.md に記載なし。

## F. エラーハンドリングパターン
- ファイル不在時:
  - `agent_path` 読み込み失敗 → エラー出力して終了（Phase 0）
  - `knowledge.md` 読み込み失敗 → 初期化して Phase 1A へ（Phase 0）
  - `perspective-source.md` / `perspectives/{target}/{key}.md` 不在 → perspective 自動生成（Phase 0）
  - `.agent_audit/{agent_name}/audit-*.md` 不在 → Phase 1B でスキップ（Glob で検索、なければ空リスト）
- サブエージェント失敗時:
  - Phase 3（評価実行）: 成功数を集計し分岐
    - 全成功 → Phase 4
    - 一部失敗（各プロンプトに最低1回成功） → 警告出力し Phase 4（SD=N/A）
    - いずれかのプロンプトで0回成功 → AskUserQuestion で確認（再試行1回/除外/中断）
  - Phase 4（採点）: AskUserQuestion で確認（再試行1回/除外/中断）、ベースライン失敗時は中断
  - Phase 0 perspective 検証失敗 → エラー出力して終了
  - その他のサブエージェント失敗 → 明示的なハンドリング記載なし
- 部分完了時: Phase 3/4 で明示的に対応（上記）
- 入力バリデーション:
  - `agent_path` 未指定 → AskUserQuestion で確認
  - perspective 必須セクション欠如 → Phase 0 で検証失敗（エラー出力して終了）
  - その他の入力型バリデーション → 明示的な記載なし

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (perspective 自動生成 Step 3) | sonnet | perspective/generate-perspective.md | 4行サマリ | 1 |
| Phase 0 (perspective 批評 Step 4) | sonnet | perspective/critic-effectiveness.md | セクション形式 | 4並列 |
| Phase 0 (perspective 批評 Step 4) | sonnet | perspective/critic-completeness.md | セクション形式 | 4並列 |
| Phase 0 (perspective 批評 Step 4) | sonnet | perspective/critic-clarity.md | セクション形式 | 4並列 |
| Phase 0 (perspective 批評 Step 4) | sonnet | perspective/critic-generality.md | セクション形式 | 4並列 |
| Phase 0 (perspective 再生成 Step 5) | sonnet | perspective/generate-perspective.md | 4行サマリ | 1（条件付き） |
| Phase 0 (knowledge 初期化) | sonnet | knowledge-init-template.md | 1行確認 | 1（条件付き） |
| Phase 1A | sonnet | phase1a-variant-generation.md | 構造化サマリ | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 構造化サマリ | 1 |
| Phase 2 | sonnet | phase2-test-document.md | テーブル形式サマリ | 1 |
| Phase 3 | sonnet | （指示は親で直接記述） | 1行確認 | N = (baseline + variants) × 2 |
| Phase 4 | sonnet | phase4-scoring.md | 2行スコアサマリ | N = prompts 数（並列） |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行サマリ | 1 |
| Phase 6 デプロイ | haiku | （指示は親で直接記述） | 1行確認 | 1（条件付き） |
| Phase 6A | sonnet | phase6a-knowledge-update.md | 1行確認 | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update.md | 1行確認 | 1 |

**合計**: 最小13回（初回、perspective 既存、バリアント2個、評価成功、採点成功） / 最大25回（perspective 自動生成+批評4+再生成+knowledge 初期化+Phase 1-6）
