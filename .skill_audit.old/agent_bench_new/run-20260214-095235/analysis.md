# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 372 | スキル定義メインファイル。全体ワークフロー（Phase 0-6）と実行ロジックを定義 |
| approach-catalog.md | 202 | 改善アプローチカタログ。4カテゴリ（S/C/N/M）の改善テクニックと実証済み効果・注意事項を定義 |
| scoring-rubric.md | 70 | 採点基準。検出判定（○△×）、スコア計算式、推奨判定基準、収束判定を定義 |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込み原則、正解キー形式を定義 |
| proven-techniques.md | 70 | エージェント横断の実証済み知見。Phase 6B で自動更新される効果テクニック・アンチパターン一覧 |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート。バリエーションステータステーブルと初期構造を定義 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A（初回）バリアント生成テンプレート。ベースライン構築 + 2バリアント生成 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B（継続）バリアント生成テンプレート。knowledge ベースのバリアント選定（Broad/Deep モード） |
| templates/phase2-test-document.md | 33 | Phase 2 テスト対象文書生成テンプレート。入力型判定 + 問題埋め込み + 正解キー生成 |
| templates/phase4-scoring.md | 13 | Phase 4 採点テンプレート。検出判定（○△×）+ ボーナス/ペナルティ + スコア計算 |
| templates/phase5-analysis-report.md | 22 | Phase 5 分析レポートテンプレート。推奨判定 + 収束判定 + 比較レポート生成 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A ナレッジ更新テンプレート。knowledge.md の全セクション更新ロジック |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B スキル知見フィードバックテンプレート。proven-techniques.md への昇格判定（Tier 1-3） |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成テンプレート。スキーマ定義 + 生成ガイドライン |
| templates/perspective/critic-completeness.md | 107 | perspective 批評（網羅性）テンプレート。欠落検出能力・問題バンク品質の評価 |
| templates/perspective/critic-clarity.md | 未読 | perspective 批評（明確性）テンプレート |
| templates/perspective/critic-effectiveness.md | 未読 | perspective 批評（効果性）テンプレート |
| templates/perspective/critic-generality.md | 未読 | perspective 批評（汎用性）テンプレート |
| perspectives/code/security.md | 38 | perspective 定義（実装レビュー：セキュリティ）。評価スコープ + 問題バンク |
| perspectives/code/performance.md | 未読 | perspective 定義（実装レビュー：パフォーマンス） |
| perspectives/code/consistency.md | 未読 | perspective 定義（実装レビュー：一貫性） |
| perspectives/code/best-practices.md | 未読 | perspective 定義（実装レビュー：ベストプラクティス） |
| perspectives/code/maintainability.md | 未読 | perspective 定義（実装レビュー：保守性） |
| perspectives/design/security.md | 43 | perspective 定義（設計レビュー：セキュリティ）。STRIDE 脅威モデリング含む詳細スコープ |
| perspectives/design/performance.md | 未読 | perspective 定義（設計レビュー：パフォーマンス） |
| perspectives/design/consistency.md | 未読 | perspective 定義（設計レビュー：一貫性） |
| perspectives/design/structural-quality.md | 未読 | perspective 定義（設計レビュー：構造品質） |
| perspectives/design/reliability.md | 未読 | perspective 定義（設計レビュー：信頼性） |
| perspectives/design/old/maintainability.md | 未読 | 旧 perspective 定義（非推奨） |
| perspectives/design/old/best-practices.md | 未読 | 旧 perspective 定義（非推奨） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1A/1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
- 各フェーズの目的（1行ずつ）
  - **Phase 0**: 初期化・状態検出。agent_name 導出、perspective 解決/自動生成、knowledge.md 存在確認で Phase 1A/1B 分岐
  - **Phase 1A**: 初回ベースライン作成 + バリアント生成（2個）。proven-techniques.md のベースライン構築ガイドに従う
  - **Phase 1B**: 継続知見ベースのバリアント生成（2個）。knowledge.md のバリエーションステータスから Broad/Deep モード選定
  - **Phase 2**: テスト入力文書生成（毎ラウンド）。入力型判定 + 8-10問題埋め込み + 正解キー生成
  - **Phase 3**: 並列評価実行。(ベースライン1 + バリアント2) × 2回 = 6タスクを並列起動
  - **Phase 4**: 採点（並列）。プロンプトごとに採点サブエージェント起動、検出判定（○△×）+ ボーナス/ペナルティ
  - **Phase 5**: 分析・推奨判定・レポート作成。scoring-rubric.md の推奨判定基準 + 収束判定
  - **Phase 6**: プロンプト選択・デプロイ・次アクション。Step 1: ユーザー選択 → デプロイ（haiku）、Step 2: 並列（A: knowledge 更新、B: proven-techniques 更新 + C: 次アクション選択）
- データフロー: どのフェーズがどのファイルを生成し、どのフェーズが参照するか
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md`（初期化時のみ）
  - Phase 1A/1B → `.agent_bench/{agent_name}/prompts/v{NNN}-*.md`（3ファイル: baseline + variant × 2）
  - Phase 2 → `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
  - Phase 3 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1|2}.md`（6ファイル: 3プロンプト × 2回）
  - Phase 4 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md`（3ファイル: 各プロンプト）
  - Phase 5 → `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
  - Phase 6 → デプロイ先（`{agent_path}`）、`knowledge.md`（更新）、`proven-techniques.md`（更新）

## C. 外部参照の検出
（{skill_path} 外のパスを参照する箇所を全て列挙）
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 174 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit スキルの分析結果を Phase 1B のバリアント生成で参考にする（audit-approved.md は除外） |
| SKILL.md | 309 | `{agent_path}` | ユーザー指定のエージェント定義ファイル。Phase 0 で読み込み、Phase 6 でデプロイ先として使用 |
| SKILL.md | 36-46 | プロジェクトルート | agent_name 導出ロジックで `.claude/` 配下以外のエージェント定義パスを相対パス化 |

## D. コンテキスト予算分析
- SKILL.md 行数: 372行
- テンプレートファイル数: 13個、平均行数: 47行
- サブエージェント委譲: あり（Phase 0: 1-6個、Phase 1A/1B: 1個、Phase 2: 1個、Phase 3: 6個並列、Phase 4: 3個並列、Phase 5: 1個、Phase 6: 3個）
- 親コンテキストに保持される情報: agent_name, agent_path, 累計ラウンド数, Phase 5 の7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
- 3ホップパターンの有無: なし（サブエージェント間のデータはファイル経由。Phase 6 の A→B 依存はファイル経由で解決）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0（perspective 自動生成 Step 1） | AskUserQuestion | エージェント定義が空/不足時の要件ヒアリング | 不明 |
| Phase 0（引数未指定） | AskUserQuestion | agent_path の確認 | 不明 |
| Phase 3（部分失敗時） | AskUserQuestion | 失敗タスク再試行 or 除外 or 中断の選択 | 不明 |
| Phase 4（部分失敗時） | AskUserQuestion | 失敗採点タスク再試行 or 除外 or 中断の選択 | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル + 推奨理由 + 収束判定を提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次ラウンド or 終了の選択（収束判定・累計ラウンド数を付記） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読み込み失敗 → エラー出力して終了（Phase 0）
  - knowledge.md 不在 → 初期化して Phase 1A へ（Phase 0）
  - perspective-source.md 不在 → パターンマッチ検索 → 自動生成（Phase 0）
  - perspective 検証失敗（必須セクション不在）→ エラー出力して終了（Phase 0）
- サブエージェント失敗時:
  - Phase 3（評価実行）部分失敗 → AskUserQuestion で再試行/除外/中断選択。各プロンプトで最低1回成功が必要
  - Phase 4（採点）部分失敗 → AskUserQuestion で再試行/除外/中断選択。ベースライン失敗時は中断
  - その他のサブエージェント失敗 → 未定義（暗黙的に中断と推測）
- 部分完了時:
  - Phase 3: 各プロンプトで最低1回成功があれば Phase 4 続行（SD = N/A）
  - Phase 4: ベースライン成功があれば Phase 5 続行（失敗バリアントは除外）
- 入力バリデーション: agent_path 未指定時に AskUserQuestion で確認（Phase 0）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（perspective 自動生成 Step 3） | sonnet | templates/perspective/generate-perspective.md | 4行（観点名、入力型、評価スコープ、問題バンク） | 1 |
| Phase 0（perspective 自動生成 Step 4） | sonnet | templates/perspective/critic-*.md（4種） | 不明（SendMessage でレポート送信） | 4並列 |
| Phase 0（perspective 自動生成 Step 5） | sonnet | templates/perspective/generate-perspective.md（再生成） | 4行 | 1（条件付き: 重大な問題がある場合のみ） |
| Phase 0（knowledge 初期化） | sonnet | templates/knowledge-init-template.md | 1行（初期化完了） | 1（条件付き: knowledge.md 不在時のみ） |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 構造化サマリ（エージェント定義、構造分析、生成バリアント2個） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 構造化サマリ（選定プロセス、生成バリアント2個） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 構造化サマリ（テスト対象文書、埋め込み問題一覧、ボーナス問題リスト） | 1 |
| Phase 3 | sonnet | （テンプレートなし: 直接指示） | 1行（保存完了パス） | 6並列（3プロンプト × 2回） |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（スコアサマリ） | 3並列（各プロンプト） |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1（デプロイ） | haiku | （テンプレートなし: 直接指示） | 1行（デプロイ完了） | 1（条件付き: ベースライン以外選択時のみ） |
| Phase 6 Step 2A | sonnet | templates/phase6a-knowledge-update.md | 1行（更新完了） | 1 |
| Phase 6 Step 2B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（更新完了 or 更新なし） | 1 |
