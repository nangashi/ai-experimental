# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 340 | スキルのメインワークフロー定義、Phase 0-6 の実行手順 |
| approach-catalog.md | 202 | 改善アプローチカタログ（4カテゴリ×複数テクニック） |
| scoring-rubric.md | 70 | 採点基準、スコア計算式、推奨判定基準 |
| test-document-guide.md | 254 | テスト文書生成ガイド、入力型判定、問題埋め込み原則 |
| proven-techniques.md | 70 | エージェント横断の実証済み知見（自動更新） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート |
| templates/phase0-perspective-resolution.md | 38 | perspective 解決（既存検索・フォールバック） |
| templates/phase0-perspective-generation.md | 66 | perspective 自動生成（4並列批評レビュー含む） |
| templates/perspective/generate-perspective.md | 67 | perspective 生成サブエージェント（スキーマ準拠） |
| templates/perspective/critic-completeness.md | 107 | 網羅性批評（未考慮事項検出能力評価） |
| templates/perspective/critic-clarity.md | 76 | 明確性批評（表現の曖昧性・AI動作一貫性） |
| templates/perspective/critic-effectiveness.md | 75 | 有効性批評（品質寄与度・境界明確性） |
| templates/perspective/critic-generality.md | 82 | 汎用性批評（業界依存性フィルタ） |
| templates/phase1a-variant-generation.md | 41 | ベースライン作成+バリアント生成（初回） |
| templates/phase1b-variant-generation.md | 41 | 知見ベースのバリアント生成（継続） |
| templates/phase2-test-document.md | 33 | テスト入力文書+正解キー生成 |
| templates/phase3-error-handling.md | 43 | 並列評価実行エラーハンドリング分岐 |
| templates/phase4-scoring.md | 12 | 採点サブエージェント（並列） |
| templates/phase5-analysis-report.md | 22 | 分析・推奨判定・レポート作成 |
| templates/phase6-performance-table.md | 40 | 性能推移テーブル生成・プロンプト選択 |
| templates/phase6-deploy.md | 20 | プロンプトデプロイ（Benchmark Metadata除去） |
| templates/phase6a-knowledge-update.md | 29 | knowledge.md 更新（preserve+integrate方式） |
| templates/phase6b-proven-techniques-update.md | 52 | proven-techniques.md 更新（昇格条件・統合ルール） |
| perspectives/code/best-practices.md | 34 | 実装レビュー観点定義（ベストプラクティス） |
| perspectives/code/consistency.md | 33 | 実装レビュー観点定義（一貫性） |
| perspectives/code/maintainability.md | 43 | 実装レビュー観点定義（保守性） |
| perspectives/code/security.md | 43 | 実装レビュー観点定義（セキュリティ） |
| perspectives/code/performance.md | 45 | 実装レビュー観点定義（パフォーマンス） |
| perspectives/design/consistency.md | 51 | 設計レビュー観点定義（一貫性） |
| perspectives/design/security.md | 43 | 設計レビュー観点定義（セキュリティ） |
| perspectives/design/structural-quality.md | 41 | 設計レビュー観点定義（構造的品質） |
| perspectives/design/performance.md | 45 | 設計レビュー観点定義（パフォーマンス） |
| perspectives/design/reliability.md | 43 | 設計レビュー観点定義（信頼性・運用性） |
| perspectives/design/old/best-practices.md | 34 | 旧設計レビュー観点定義（ベストプラクティス） |
| perspectives/design/old/maintainability.md | 43 | 旧設計レビュー観点定義（保守性） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- Phase 0（初期化・状態検出）: エージェントファイル読み込み → agent_name 導出 → perspective 解決/生成 → knowledge.md 読み込み → Phase 1A（初回）/ Phase 1B（継続）分岐
- Phase 1A（初回）: ベースライン作成 + バリアント生成（proven-techniques ガイド準拠）
- Phase 1B（継続）: knowledge.md ベースのバリアント生成（Broad/Deep モード）、agent_audit 統合候補提示（条件付き）
- Phase 2（テスト文書生成）: 入力型判定 → テスト対象文書生成 → 問題埋め込み（8-10個）→ 正解キー生成
- Phase 3（並列評価）: 各プロンプト × 2回を並列実行 → エラーハンドリング分岐
- Phase 4（採点）: プロンプトごとに採点サブエージェントを並列実行 → スコア計算
- Phase 5（分析）: 比較レポート作成 → 推奨判定 → 7行サマリ返答
- Phase 6（デプロイ・次アクション）: 性能推移テーブル生成 → ユーザープロンプト選択 → デプロイ（haiku）→ knowledge.md 更新（sonnet）→ proven-techniques.md 更新（sonnet、並列）→ 次アクション選択

データフロー:
- Phase 0 生成: `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md`
- Phase 1 生成: `.agent_bench/{agent_name}/prompts/v{NNN}-*.md`
- Phase 2 生成: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
- Phase 3 生成: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
- Phase 4 生成: `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md`
- Phase 5 生成: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
- Phase 6 更新: `{agent_path}`, `knowledge.md`, `proven-techniques.md`

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| templates/phase1b-variant-generation.md | 8 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit スキルの分析結果を読み込み、バリアント生成に統合 |
| templates/phase1b-variant-generation.md | 138 | `.agent_audit/{agent_name}/audit-ce-*.md` | 基準有効性分析結果パス |
| templates/phase1b-variant-generation.md | 139 | `.agent_audit/{agent_name}/audit-sa-*.md` | スコープ整合性分析結果パス |

## D. コンテキスト予算分析
- SKILL.md 行数: 340行
- テンプレートファイル数: 19個、平均行数: 48行
- サブエージェント委譲: あり（全7フェーズで合計12種類のサブエージェント委譲パターン）
  - Phase 0: perspective 解決（1）、perspective 自動生成（1 + 4並列批評 + 1再生成）、knowledge 初期化（1）
  - Phase 1A: バリアント生成（1）
  - Phase 1B: バリアント生成（1）
  - Phase 2: テスト文書生成（1）
  - Phase 3: 並列評価実行（N × 2回、親が直接起動）
  - Phase 4: 採点（N並列）
  - Phase 5: 分析レポート（1）
  - Phase 6: 性能テーブル（親が実行）、デプロイ（1、haiku）、knowledge 更新（1、sonnet）、proven-techniques 更新（1、sonnet、並列）
- 親コンテキストに保持される情報: agent_name, agent_path, 累計ラウンド数, Phase 5 サブエージェント返答（7行サマリ）、選択されたプロンプト名
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しは全てファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認、エージェント目的のヒアリング | 不明 |
| Phase 1B | AskUserQuestion | Audit 統合候補の承認選択（全て統合/個別選択/スキップ） | 不明 |
| Phase 2 | AskUserQuestion | テスト文書生成失敗時の再試行/中断選択 | 不明 |
| Phase 3 | AskUserQuestion | 並列評価失敗時のエラーハンドリング分岐選択 | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の再試行/除外/中断選択 | 不明 |
| Phase 6 | AskUserQuestion | プロンプト選択、次ラウンド/終了選択 | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - `agent_path` 不在: エラー出力して終了
  - `perspective-source.md` 不在: フォールバック検索（reviewer パターン）→ 失敗時は自動生成（4並列批評レビュー）→ 失敗時は終了
  - `knowledge.md` 不在: 初期化して Phase 1A へ
- サブエージェント失敗時:
  - Phase 0 perspective 解決失敗: 自動生成に移行
  - Phase 0 perspective 自動生成失敗: エラー出力して終了
  - Phase 0 knowledge 初期化失敗: エラー出力して終了
  - Phase 1A/1B バリアント生成失敗: エラー出力して終了
  - Phase 2 テスト文書生成失敗: AskUserQuestion で再試行（1回のみ）/中断選択
  - Phase 3 並列評価失敗: phase3-error-handling.md に従い分岐（全成功/ベースライン全失敗/部分失敗/バリアント全失敗）
  - Phase 4 採点失敗: AskUserQuestion で再試行（1回のみ）/除外して続行/中断選択
  - Phase 5 分析失敗: エラー出力して終了
  - Phase 6 proven-techniques 更新失敗: 警告を出力して続行（任意のため）
- 部分完了時: Phase 3 で部分成功の場合は成功 Run のみで Phase 4 へ進む（警告付き）
- 入力バリデーション: agent_path の存在確認、perspective 必須セクションの存在確認

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（perspective 解決） | sonnet | phase0-perspective-resolution.md | 1行（成功/失敗） | 1 |
| Phase 0（perspective 生成） | sonnet | phase0-perspective-generation.md | 1行（成功/失敗） | 1 |
| Phase 0（perspective 生成内部） | sonnet | perspective/generate-perspective.md | 4行 | 1 |
| Phase 0（perspective 批評） | sonnet | perspective/critic-completeness.md | 可変 | 4並列 |
| Phase 0（perspective 批評） | sonnet | perspective/critic-clarity.md | 可変 | 4並列 |
| Phase 0（perspective 批評） | sonnet | perspective/critic-effectiveness.md | 可変 | 4並列 |
| Phase 0（perspective 批評） | sonnet | perspective/critic-generality.md | 可変 | 4並列 |
| Phase 0（knowledge 初期化） | sonnet | knowledge-init-template.md | 1行 | 1 |
| Phase 1A | sonnet | phase1a-variant-generation.md | 可変 | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 可変（audit 統合候補含む） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 可変 | 1 |
| Phase 3 | sonnet | （親が直接指示） | 1行（保存完了） | N × 2回並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ） | N並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（固定フォーマット） | 1 |
| Phase 6（デプロイ） | haiku | phase6-deploy.md | 1行 | 1 |
| Phase 6A（knowledge 更新） | sonnet | phase6a-knowledge-update.md | 1行 | 1 |
| Phase 6B（proven-techniques 更新） | sonnet | phase6b-proven-techniques-update.md | 1行 | 1（Phase 6A と並列） |
