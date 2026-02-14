# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 372 | メインワークフロー定義。Phase 0-6の処理フロー、サブエージェント委譲、パス変数、コンテキスト節約原則 |
| approach-catalog.md | 202 | 改善アプローチカタログ。4カテゴリ(S/C/N/M)のテクニック・バリエーション定義、推奨構成、実証済み効果 |
| perspectives/code/best-practices.md | 34 | コードレビュー用観点定義（ベストプラクティス）。評価スコープ、問題バンク |
| perspectives/code/consistency.md | 33 | コードレビュー用観点定義（一貫性）。評価スコープ、問題バンク |
| perspectives/code/maintainability.md | 43 | コードレビュー用観点定義（保守性）。評価スコープ、問題バンク |
| perspectives/code/security.md | 37 | コードレビュー用観点定義（セキュリティ）。評価スコープ、問題バンク |
| perspectives/code/performance.md | 45 | コードレビュー用観点定義（パフォーマンス）。評価スコープ、問題バンク |
| perspectives/design/old/best-practices.md | 33 | 設計レビュー用観点定義（ベストプラクティス、旧版） |
| perspectives/design/consistency.md | 51 | 設計レビュー用観点定義（一貫性）。評価スコープ、問題バンク |
| perspectives/design/security.md | 43 | 設計レビュー用観点定義（セキュリティ）。評価スコープ、問題バンク |
| perspectives/design/structural-quality.md | 40 | 設計レビュー用観点定義（構造的品質）。評価スコープ、問題バンク |
| perspectives/design/old/maintainability.md | 43 | 設計レビュー用観点定義（保守性、旧版） |
| perspectives/design/performance.md | 45 | 設計レビュー用観点定義（パフォーマンス）。評価スコープ、問題バンク |
| perspectives/design/reliability.md | 43 | 設計レビュー用観点定義（信頼性・運用性）。評価スコープ、問題バンク |
| templates/knowledge-init-template.md | 53 | Phase 0 knowledge.md 初期化テンプレート。全バリエーションID一覧生成 |
| scoring-rubric.md | 70 | 採点基準定義。検出判定(○△×)、スコア計算式、ボーナス/ペナルティ、推奨判定、収束判定 |
| proven-techniques.md | 70 | スキル横断実証済み知見。効果テクニック、アンチパターン、条件付きテクニック、ベースラインガイド |
| templates/phase1a-variant-generation.md | 41 | Phase 1A バリアント生成テンプレート（初回）。ベースライン構築＋バリアント2個生成 |
| templates/perspective/generate-perspective.md | 67 | perspective 自動生成テンプレート（Step 3）。必須スキーマ、生成ガイドライン |
| templates/perspective/critic-completeness.md | 107 | perspective 批評テンプレート（完全性）。Missing Element Detection評価、問題バンク品質 |
| templates/perspective/critic-clarity.md | 76 | perspective 批評テンプレート（明確性）。曖昧性検出、AI動作一貫性テスト |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評テンプレート（有効性）。寄与度分析、境界明確性検証 |
| templates/perspective/critic-generality.md | 82 | perspective 批評テンプレート（汎用性）。業界依存性・技術スタック依存性評価 |
| templates/phase2-test-document.md | 33 | Phase 2 テスト文書生成テンプレート。test-document-guide.md 参照、問題埋め込み |
| templates/phase6b-proven-techniques-update.md | 51 | Phase 6B proven-techniques.md 更新テンプレート。昇格条件、統合ルール、サイズ制限 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A knowledge.md 更新テンプレート。効果テーブル、バリエーションステータス、スコア推移 |
| templates/phase5-analysis-report.md | 20 | Phase 5 分析レポートテンプレート。推奨判定、収束判定、7行サマリ |
| templates/phase1b-variant-generation.md | 33 | Phase 1B バリアント生成テンプレート（継続）。Broad/Deep モード選択、バリエーションステータス参照 |
| templates/phase4-scoring.md | 13 | Phase 4 採点テンプレート。検出判定、ボーナス/ペナルティ、スコアサマリ |
| test-document-guide.md | 254 | テスト文書生成ガイド。入力型判定、文書構成、問題埋め込みガイドライン、正解キー形式 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- 各フェーズの目的:
  - **Phase 0**: 初期化・状態検出。エージェントファイル読込、agent_name導出、perspective解決（検索→フォールバック→自動生成）、knowledge.md初期化判定
  - **Phase 1A**: 初回ラウンド。ベースライン作成＋バリアント2個生成（Broad探索）
  - **Phase 1B**: 継続ラウンド。知見ベースのバリアント生成（Broad/Deep選択）
  - **Phase 2**: テスト文書＋正解キー生成（毎ラウンド）
  - **Phase 3**: 並列評価実行。各プロンプト×2回並列実行
  - **Phase 4**: 採点。プロンプトごとに並列採点サブエージェント
  - **Phase 5**: 分析・推奨判定・レポート作成。7行サマリ返答
  - **Phase 6**: プロンプト選択・デプロイ・次アクション。Step 1: デプロイ、Step 2: ナレッジ更新（6A）＋スキル知見フィードバック（6B）並列＋次アクション選択
- データフロー:
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md`（初期化時のみ）生成
  - Phase 1A/1B → `.agent_bench/{agent_name}/prompts/v{NNN}-*.md` 生成
  - Phase 2 → `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md` 生成
  - Phase 3 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1,2}.md` 生成
  - Phase 4 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md` 生成、Phase 5 が参照
  - Phase 5 → `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md` 生成、Phase 6A/6B が参照
  - Phase 6 → デプロイ先 `{agent_path}`、`knowledge.md`（6A）、`proven-techniques.md`（6B）更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | perspective フォールバック検索（パターンマッチ時） |
| SKILL.md | 74 | `.claude/skills/agent_bench/perspectives/design/*.md` | perspective 自動生成時の参照データ（構造フォーマット例） |
| SKILL.md | 174 | `.agent_audit/{agent_name}/audit-*.md` | Phase 1B バリアント生成時の agent_audit 分析結果参照（Glob検索、audit-approved.md除外） |
| templates/phase1b-variant-generation.md | 8 | `.agent_audit/{agent_name}/audit-*.md` | Phase 1B: agent_audit の基準有効性・スコープ整合性分析結果 |

## D. コンテキスト予算分析
- SKILL.md 行数: 372行
- テンプレートファイル数: 14個、平均行数: 50.8行
- サブエージェント委譲: あり（Phase 0 knowledge初期化、Phase 0 perspective自動生成（5ステップ：初期生成1＋批評4並列＋再生成1）、Phase 1A/1B バリアント生成、Phase 2 テスト文書生成、Phase 3 評価実行（プロンプト数×2並列）、Phase 4 採点（プロンプト数並列）、Phase 5 分析、Phase 6 デプロイ（haiku）、Phase 6A ナレッジ更新、Phase 6B スキル知見フィードバック）
- 親コンテキストに保持される情報: agent_name、agent_path、perspective解決フラグ、累計ラウンド数、Phase 5 の7行サマリ、Phase 4 のスコアサマリ一覧、Phase 3 の成功数集計
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しはファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が空または不足の場合のヒアリング（目的・入出力・ツール・制約） | 不明 |
| Phase 3 | AskUserQuestion | 一部プロンプトで成功結果0回時の再試行/除外/中断選択 | 不明 |
| Phase 4 | AskUserQuestion | 採点タスク一部失敗時の再試行/除外/中断選択 | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（性能推移テーブル＋推奨提示） | 不明 |
| Phase 6 Step 2 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - エージェントファイル読込失敗 → エラー出力して終了（Phase 0）
  - perspective-source.md 不在 → フォールバック検索 → 自動生成（Phase 0）
  - knowledge.md 不在 → 初期化して Phase 1A へ（Phase 0）
  - perspective.md 検証失敗（必須セクション欠如）→ エラー出力して終了（Phase 0 Step 6）
- サブエージェント失敗時:
  - Phase 3（評価実行）全失敗 → AskUserQuestion で再試行/除外/中断選択
  - Phase 3 部分失敗かつ各プロンプト最低1回成功 → 警告出力して Phase 4 へ進む
  - Phase 3 いずれかのプロンプトで成功0回 → AskUserQuestion で再試行/除外/中断選択
  - Phase 4（採点）一部失敗 → AskUserQuestion で再試行/除外/中断選択
  - Phase 4 ベースライン採点失敗 → 中断
- 部分完了時: Phase 3/4 の部分失敗は警告または AskUserQuestion で対応
- 入力バリデーション: agent_path 未指定時は AskUserQuestion で確認。エージェント定義が空/不足の場合はヒアリング

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (知見初期化) | sonnet | knowledge-init-template.md | 1行 | 1 |
| Phase 0 (perspective生成 Step 3) | sonnet | perspective/generate-perspective.md | 4行サマリ | 1 |
| Phase 0 (perspective批評 Step 4) | sonnet | perspective/critic-effectiveness.md | 構造化報告 | 4並列 |
| Phase 0 (perspective批評 Step 4) | sonnet | perspective/critic-completeness.md | 構造化報告 | 4並列 |
| Phase 0 (perspective批評 Step 4) | sonnet | perspective/critic-clarity.md | 構造化報告 | 4並列 |
| Phase 0 (perspective批評 Step 4) | sonnet | perspective/critic-generality.md | 構造化報告 | 4並列 |
| Phase 0 (perspective再生成 Step 5) | sonnet | perspective/generate-perspective.md | 4行サマリ | 1（条件付） |
| Phase 1A | sonnet | phase1a-variant-generation.md | 構造化サマリ | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 構造化サマリ | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 問題サマリテーブル | 1 |
| Phase 3 | sonnet | なし（直接指示） | 1行（保存完了） | (プロンプト数×2)並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2行スコアサマリ | プロンプト数並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行サマリ | 1 |
| Phase 6 Step 1 (デプロイ) | haiku | なし（直接指示） | 1行（デプロイ完了） | 1（条件付） |
| Phase 6 Step 2A | sonnet | phase6a-knowledge-update.md | 1行（更新完了） | 1 |
| Phase 6 Step 2B | sonnet | phase6b-proven-techniques-update.md | 1行（昇格件数） | 1 |
