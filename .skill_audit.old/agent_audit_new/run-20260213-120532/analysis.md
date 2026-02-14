# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 372 | スキルメインロジック、全Phase定義、ワークフロー制御 |
| approach-catalog.md | 202 | 改善アプローチカタログ（S/C/N/Mカテゴリ、バリエーション定義） |
| scoring-rubric.md | 70 | 採点基準（検出判定基準、スコア計算式、推奨判定基準、収束判定） |
| proven-techniques.md | 70 | 実証済みテクニック・アンチパターン（エージェント横断知見） |
| test-document-guide.md | 254 | テスト対象文書生成ガイド（入力型判定、文書構成、問題埋め込み） |
| templates/knowledge-init-template.md | 53 | Phase 0: knowledge.md 初期化テンプレート |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回ベースライン作成・バリアント生成 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B: 継続バリアント生成（knowledge ベース） |
| templates/phase2-test-document.md | 33 | Phase 2: テスト対象文書・正解キー生成 |
| templates/phase4-scoring.md | 13 | Phase 4: 採点サブエージェント |
| templates/phase5-analysis-report.md | 22 | Phase 5: 比較レポート作成・推奨判定 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A: knowledge.md 更新 |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B: proven-techniques.md 更新（昇格ルール） |
| templates/perspective/generate-perspective.md | 67 | Phase 0: perspective 初期生成 |
| templates/perspective/critic-completeness.md | 107 | Phase 0: 網羅性批評（欠落検出能力評価） |
| templates/perspective/critic-clarity.md | 76 | Phase 0: 明確性批評（AI動作一貫性評価） |
| templates/perspective/critic-effectiveness.md | 75 | Phase 0: 有効性批評（品質寄与度・境界明確性） |
| templates/perspective/critic-generality.md | 82 | Phase 0: 汎用性批評（業界依存性フィルタ） |
| perspectives/code/maintainability.md | 34 | 保守性観点（実装レビュー） |
| perspectives/code/best-practices.md | 34 | ベストプラクティス観点（実装レビュー） |
| perspectives/code/consistency.md | 33 | 一貫性観点（実装レビュー） |
| perspectives/code/security.md | 37 | セキュリティ観点（実装レビュー） |
| perspectives/code/performance.md | 37 | パフォーマンス観点（実装レビュー） |
| perspectives/design/consistency.md | 51 | 一貫性観点（設計レビュー） |
| perspectives/design/security.md | 43 | セキュリティ観点（設計レビュー） |
| perspectives/design/structural-quality.md | 41 | 構造的品質観点（設計レビュー） |
| perspectives/design/performance.md | 45 | パフォーマンス観点（設計レビュー） |
| perspectives/design/reliability.md | 43 | 信頼性・運用性観点（設計レビュー） |
| perspectives/design/old/maintainability.md | (未読) | 旧版観点定義 |
| perspectives/design/old/best-practices.md | (未読) | 旧版観点定義 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6 (ループ可能)
- Phase 0: 初期化・perspective 解決/生成・knowledge.md 初期化・継続判定（1A or 1B）
- Phase 1A: 初回ベースライン作成 + 2バリアント生成（proven-techniques のガイドライン適用）
- Phase 1B: 継続バリアント生成（knowledge のバリエーションステータステーブルから選定）
- Phase 2: 毎ラウンドのテスト入力文書・正解キー生成（perspective + knowledge 参照）
- Phase 3: 並列評価実行（プロンプト数 × 2回）
- Phase 4: 採点（プロンプトごとに並列実行、検出判定 + ボーナス/ペナルティ）
- Phase 5: 比較レポート作成・推奨判定・収束判定（scoring-rubric 基準適用）
- Phase 6: Step 1: プロンプト選択・デプロイ（haiku サブエージェント） → Step 2: ナレッジ更新（sonnet） + スキル知見フィードバック（sonnet 並列） + 次アクション選択

- データフロー:
  - Phase 0 → 1A/1B: agent_path, perspective, knowledge, proven-techniques → prompts/ 生成
  - Phase 2: perspective, knowledge → test-document, answer-key 生成
  - Phase 3: prompts/, test-document → results/ 生成
  - Phase 4: results/, answer-key, perspective → scoring ファイル生成
  - Phase 5: scoring ファイル, knowledge → report 生成
  - Phase 6A: report, knowledge → knowledge 更新
  - Phase 6B: report, knowledge → proven-techniques 更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | perspective フォールバックパターン検索 |
| SKILL.md | 74 | `.claude/skills/agent_bench/perspectives/design/*.md` | perspective 生成時の参照データ収集 |
| SKILL.md | 81-96 | `.claude/skills/agent_bench/templates/perspective/*.md` | perspective 自動生成（4並列批評） |
| SKILL.md | 123 | `.claude/skills/agent_bench/templates/knowledge-init-template.md` | knowledge.md 初期化テンプレート |
| SKILL.md | 146-157 | `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` | Phase 1A バリアント生成テンプレート |
| SKILL.md | 165-175 | `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` | Phase 1B バリアント生成テンプレート |
| SKILL.md | 182-192 | `.claude/skills/agent_bench/templates/phase2-test-document.md` | Phase 2 テスト文書生成テンプレート |
| SKILL.md | 246-256 | `.claude/skills/agent_bench/templates/phase4-scoring.md` | Phase 4 採点テンプレート |
| SKILL.md | 270-277 | `.claude/skills/agent_bench/templates/phase5-analysis-report.md` | Phase 5 分析レポートテンプレート |
| SKILL.md | 322-328 | `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` | Phase 6A ナレッジ更新テンプレート |
| SKILL.md | 334-341 | `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` | Phase 6B スキル知見フィードバックテンプレート |
| SKILL.md | 174 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit 連携（Phase 1B バリアント生成時の参考） |
| phase1b-variant-generation.md | 8-9 | {audit_dim1_path}, {audit_dim2_path} | agent_audit の分析結果参照 |

## D. コンテキスト予算分析
- SKILL.md 行数: 372行
- テンプレートファイル数: 13個、平均行数: 52行
- サブエージェント委譲: あり（全生成処理を委譲）
  - Phase 0: knowledge 初期化（1回）、perspective 生成（1回）+ 4並列批評（必要時）
  - Phase 1A: バリアント生成（1回）
  - Phase 1B: バリアント生成（1回）
  - Phase 2: テスト文書生成（1回）
  - Phase 3: 評価実行（プロンプト数 × 2回、並列）
  - Phase 4: 採点（プロンプト数、並列）
  - Phase 5: 分析レポート（1回）
  - Phase 6: デプロイ（haiku, 1回） + ナレッジ更新（sonnet, 1回） + スキル知見フィードバック（sonnet, 1回並列）
- 親コンテキストに保持される情報: フェーズ遷移制御、agent_name, agent_path, パス変数、サブエージェント返答のサマリ（7行以下）、エラー状態
- 3ホップパターンの有無: なし（全てファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時のパス確認 | 不明 |
| Phase 0 | AskUserQuestion | perspective 自動生成時のエージェント要件ヒアリング | 不明 |
| Phase 3 | AskUserQuestion | 評価実行失敗時の再試行/除外/中断選択 | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の再試行/除外/中断選択 | 不明 |
| Phase 6 | AskUserQuestion | プロンプト選択（性能推移テーブル + 推奨提示） | 不明 |
| Phase 6 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読み込み失敗 → エラー出力して終了
  - knowledge.md 不在 → Phase 1A へ（初期化処理）
  - perspective 不在 → 自動生成（フォールバックパターン検索 → 4並列批評 → 再生成）
- サブエージェント失敗時:
  - Phase 3（評価実行）: 成功数集計 → 全成功: Phase 4、部分成功（各プロンプトに最低1回成功）: 警告+Phase 4、失敗プロンプトあり: AskUserQuestion（再試行/除外/中断）
  - Phase 4（採点）: 全成功: Phase 5、部分失敗: AskUserQuestion（再試行/除外/中断、ベースライン失敗は中断）
  - その他のサブエージェント失敗: 未定義（暗黙的に終了と推測）
- 部分完了時: Phase 3/4 で定義済み（警告 + 継続 or ユーザー選択）
- 入力バリデーション: agent_path 必須確認、perspective 検証（必須セクション存在確認）、その他は未定義

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 | sonnet | knowledge-init-template.md | 1行（確認メッセージ） | 1 |
| Phase 0 | sonnet | perspective/generate-perspective.md | 4行（観点サマリ） | 1（必要時） |
| Phase 0 | sonnet | perspective/critic-*.md × 4 | 複数セクション形式 | 4（並列、必要時） |
| Phase 1A | sonnet | phase1a-variant-generation.md | 複数セクション形式 | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 複数セクション形式 | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 複数セクション形式 | 1 |
| Phase 3 | sonnet | （SKILL.md 直接指示） | 1行（保存完了メッセージ） | (ベースライン + バリアント数) × 2 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ） | ベースライン + バリアント数 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（固定フォーマット） | 1 |
| Phase 6 | haiku | （SKILL.md 直接指示） | 1行（デプロイ完了メッセージ） | 1 |
| Phase 6A | sonnet | phase6a-knowledge-update.md | 1行（更新完了メッセージ） | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update.md | 1行（昇格結果サマリ） | 1（並列） |
