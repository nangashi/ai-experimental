# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 384 | メインワークフロー定義。Phase 0-6 の処理手順、perspective 解決、パス導出、収束判定を含む |
| approach-catalog.md | 202 | 改善アプローチカタログ。カテゴリ → テクニック → バリエーションの3階層管理 |
| scoring-rubric.md | 70 | 採点基準定義。検出判定基準(○△×)、スコア計算式、推奨判定基準、収束判定を含む |
| proven-techniques.md | 70 | エージェント横断の実証済み知見。効果テクニック、アンチパターン、条件付きテクニック、ベースライン構築ガイド |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成、問題埋め込みガイドライン、正解キーフォーマット |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート。バリエーションステータステーブルの生成 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回ベースライン作成+バリアント生成 |
| templates/phase1b-variant-generation.md | 34 | Phase 1B: 継続時の知見ベースバリアント生成（agent_audit 結果統合を含む） |
| templates/phase2-test-document.md | 33 | Phase 2: テスト入力文書・正解キー生成 |
| templates/phase3-evaluation.md | 12 | Phase 3: 並列評価実行 |
| templates/phase4-scoring.md | 13 | Phase 4: 採点 |
| templates/phase5-analysis-report.md | 20 | Phase 5: 分析・推奨判定・レポート作成 |
| templates/phase6a-deploy.md | 11 | Phase 6 Step 1: プロンプトデプロイ |
| templates/phase6a-knowledge-update.md | 26 | Phase 6 Step 2A: knowledge.md 更新 |
| templates/phase6b-proven-techniques-update.md | 51 | Phase 6 Step 2B: proven-techniques.md 更新 |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成（初期生成） |
| templates/perspective/critic-completeness.md | 107 | perspective 批評: 網羅性・欠落検出能力評価 |
| templates/perspective/critic-clarity.md | 76 | perspective 批評: 表現明確性・AI動作一貫性評価 |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評: 有効性・境界明確性評価 |
| templates/perspective/critic-generality.md | 82 | perspective 批評: 汎用性・業界依存性評価 |
| perspectives/code/maintainability.md | 34 | 観点定義: 保守性（実装レビュー） |
| perspectives/code/best-practices.md | 34 | 観点定義: ベストプラクティス（実装レビュー） |
| perspectives/code/consistency.md | 33 | 観点定義: 一貫性（実装レビュー） |
| perspectives/code/security.md | 37 | 観点定義: セキュリティ（実装レビュー） |
| perspectives/code/performance.md | 37 | 観点定義: パフォーマンス（実装レビュー） |
| perspectives/design/consistency.md | 51 | 観点定義: 一貫性（設計レビュー） |
| perspectives/design/security.md | 43 | 観点定義: セキュリティ（設計レビュー） |
| perspectives/design/structural-quality.md | 41 | 観点定義: 構造的品質（設計レビュー） |
| perspectives/design/performance.md | 45 | 観点定義: パフォーマンス（設計レビュー） |
| perspectives/design/reliability.md | 43 | 観点定義: 信頼性・運用性（設計レビュー） |
| perspectives/design/old/maintainability.md | 43 | 旧観点定義: 保守性（設計レビュー） |
| perspectives/design/old/best-practices.md | 34 | 旧観点定義: ベストプラクティス（設計レビュー） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- 各フェーズの目的:
  - Phase 0: 初期化・状態検出（agent_name 導出、perspective 解決/自動生成、knowledge.md 初期化、初回/継続判定）
  - Phase 1A: 初回 — ベースライン作成 + バリアント生成（新規または existing agent_path をベースライン化）
  - Phase 1B: 継続 — 知見ベースのバリアント生成（Broad/Deep モード切替、agent_audit 結果統合）
  - Phase 2: テスト入力文書生成（毎ラウンド実行、ドメイン多様性確保）
  - Phase 3: 並列評価実行（各プロンプト × 2回実行、収束時は1回のみ）
  - Phase 4: 採点（プロンプトごとに並列採点サブエージェント起動）
  - Phase 5: 分析・推奨判定・レポート作成（推奨判定基準・収束判定を適用）
  - Phase 6: プロンプト選択・デプロイ・次アクション（Step 1: デプロイ、Step 2A: knowledge 更新、Step 2B: proven-techniques 更新、Step 2C: 次アクション選択）
- データフロー:
  - Phase 0: perspective-source.md, perspective.md, knowledge.md 生成 → Phase 1 で参照
  - Phase 1: prompts/*.md 生成 → Phase 3 で実行
  - Phase 2: test-document-round-{NNN}.md, answer-key-round-{NNN}.md 生成 → Phase 3/4 で参照
  - Phase 3: results/v{NNN}-{name}-run{R}.md 生成 → Phase 4 で採点
  - Phase 4: results/v{NNN}-{name}-scoring.md 生成 → Phase 5 で分析
  - Phase 5: reports/round-{NNN}-comparison.md 生成、7行サマリ返答 → Phase 6 で参照
  - Phase 6: 選択プロンプトを agent_path にデプロイ、knowledge.md 更新、proven-techniques.md 更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 59 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | ファイル名パターンからの perspective フォールバック検索 |
| SKILL.md | 79 | `.claude/skills/agent_bench_new/perspectives/design/security.md` | perspective 自動生成時の参照データ（構造とフォーマット参考用） |
| SKILL.md | 184 | `.agent_audit/{agent_name}/run-*/audit-*.md` | agent_audit の分析結果（Phase 1B でバリアント生成の参考に使用） |
| templates/phase1b-variant-generation.md | 8 | `.agent_audit/{agent_name}/run-*/audit-*.md` | agent_audit の基準有効性・スコープ整合性分析結果の読み込み |

注記: 外部参照は agent_audit スキルの出力ディレクトリとの連携に限定されており、明示的なパスで参照している。

## D. コンテキスト予算分析
- SKILL.md 行数: 384行
- テンプレートファイル数: 15個、平均行数: 47行（最大107行: critic-completeness.md、最小11行: phase6a-deploy.md）
- サブエージェント委譲: あり（Phase 0 の knowledge 初期化、Phase 1A/1B のバリアント生成、Phase 2 のテスト文書生成、Phase 3 の並列評価、Phase 4 の並列採点、Phase 5 の分析・推奨判定、Phase 6 Step 1 のデプロイ、Step 2A の knowledge 更新、Step 2B の proven-techniques 更新）
- 親コンテキストに保持される情報:
  - Phase 0: agent_name, agent_path, perspective_source_path, perspective_path, 累計ラウンド数、次フェーズ判定（1A/1B）
  - Phase 1: バリアント生成のテキストサマリ（プロンプト本文は prompts/ に保存）
  - Phase 2: テスト文書の問題サマリ（詳細は test-document-round-{NNN}.md に保存）
  - Phase 3: 成功数集計のみ（評価結果は results/ に保存）
  - Phase 4: 採点サブエージェントの返答（スコアサマリ）
  - Phase 5: 7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 6: ユーザー選択プロンプト名、性能推移テーブル
- 3ホップパターンの有無: なし（全てファイル経由でサブエージェント間のデータ受け渡しを実施）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0（perspective 自動生成 Step 5） | AskUserQuestion | 批評結果に基づく再生成確認 | 不明 |
| Phase 3 | AskUserQuestion | 一部プロンプトで成功結果が0回の場合の対応確認（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応確認（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | 推奨プロンプト選択（性能推移テーブル・推奨理由・収束判定を提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

注記: SKILL.md に Fast mode の明示的な扱いの記載はない。

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読み込み失敗 → エラー出力して終了（Phase 0）
  - perspective-source.md 不在 → ファイル名パターン検索 → 自動生成（Phase 0）
  - knowledge.md 不在 → 初期化して Phase 1A へ（Phase 0）
  - knowledge.md 必須セクション検証失敗 → エラー出力し再初期化して Phase 1A へ（Phase 0）
  - reference_perspective_path 不在 → 空として処理（Phase 0 perspective 自動生成）
- サブエージェント失敗時:
  - Phase 3 評価タスク一部失敗 → 各プロンプトに最低1成功結果あれば警告出力して Phase 4 へ、失敗プロンプトあれば AskUserQuestion で確認（再試行/除外/中断）
  - Phase 4 採点タスク一部失敗 → AskUserQuestion で確認（再試行/除外/中断）
  - ベースライン採点失敗 → 中断（Phase 4）
- 部分完了時: Phase 3/4 で失敗タスクを除外して続行可能（ユーザー選択）
- 入力バリデーション:
  - agent_path 未指定 → AskUserQuestion で確認（Phase 0）
  - perspective 検証失敗（必須セクション欠如）→ エラー出力して終了（Phase 0）
  - knowledge.md 検証失敗 → 再初期化（Phase 0）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（knowledge 初期化） | sonnet | templates/knowledge-init-template.md | 1行（確認メッセージ） | 1 |
| Phase 0（perspective 自動生成 Step 3） | sonnet | templates/perspective/generate-perspective.md | 4行（サマリ） | 1 |
| Phase 0（perspective 批評 Step 4） | sonnet | templates/perspective/critic-*.md （4種） | 未指定（SendMessage で報告） | 4（並列） |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 多行（構造分析結果+バリアント一覧） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 多行（選定プロセス+バリアント一覧） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 多行（テスト文書サマリ+問題一覧+ボーナス問題） | 1 |
| Phase 3 | sonnet | templates/phase3-evaluation.md | 1行（保存完了確認） | (ベースライン1 + バリアント数) × 2回（収束時は×1） |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（スコアサマリ） | ベースライン1 + バリアント数 |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6 Step 1 | haiku | templates/phase6a-deploy.md | 1行（デプロイ完了確認） | 1（ベースライン以外選択時のみ） |
| Phase 6 Step 2A | sonnet | templates/phase6a-knowledge-update.md | 1行（更新完了確認） | 1 |
| Phase 6 Step 2B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（更新完了または更新なし確認） | 1 |
