# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 372 | スキル定義・ワークフロー全体の記述 |
| approach-catalog.md | 202 | 改善アプローチカタログ（S/C/N/M 4カテゴリ・3階層構成） |
| scoring-rubric.md | 70 | 採点基準・推奨判定・収束判定ルール |
| test-document-guide.md | 254 | テスト文書生成ガイド（入力型判定・問題埋め込みルール） |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック（自動更新） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回バリアント生成指示 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B: 継続バリアント生成指示 |
| templates/phase2-test-document.md | 33 | Phase 2: テスト文書生成指示 |
| templates/phase4-scoring.md | 13 | Phase 4: 採点指示 |
| templates/phase5-analysis-report.md | 22 | Phase 5: 分析レポート作成指示 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A: ナレッジ更新指示 |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B: proven-techniques 更新指示 |
| templates/perspective/generate-perspective.md | 67 | perspective 初期生成指示 |
| templates/perspective/critic-completeness.md | 107 | perspective 批評: 網羅性評価 |
| templates/perspective/critic-clarity.md | 76 | perspective 批評: 明確性評価 |
| templates/perspective/critic-effectiveness.md | 75 | perspective 批評: 有効性評価 |
| templates/perspective/critic-generality.md | 82 | perspective 批評: 汎用性評価 |
| perspectives/code/maintainability.md | 34 | 観点定義: 保守性（実装） |
| perspectives/code/security.md | 37 | 観点定義: セキュリティ（実装） |
| perspectives/code/performance.md | 37 | 観点定義: パフォーマンス（実装） |
| perspectives/code/best-practices.md | 34 | 観点定義: ベストプラクティス（実装） |
| perspectives/code/consistency.md | 33 | 観点定義: 一貫性（実装） |
| perspectives/design/consistency.md | 51 | 観点定義: 一貫性（設計） |
| perspectives/design/security.md | 43 | 観点定義: セキュリティ（設計） |
| perspectives/design/structural-quality.md | 41 | 観点定義: 構造的品質（設計） |
| perspectives/design/performance.md | 45 | 観点定義: パフォーマンス（設計） |
| perspectives/design/reliability.md | 43 | 観点定義: 信頼性・運用性（設計） |
| perspectives/design/old/maintainability.md | 43 | 観点定義: 保守性（設計）（旧版） |
| perspectives/design/old/best-practices.md | 34 | 観点定義: ベストプラクティス（設計）（旧版） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6A → 6B/6C
- 各フェーズの目的:
  - **Phase 0**: 初期化（agent_path 読込、agent_name 導出、perspective 解決/生成、knowledge.md 状態判定）
  - **Phase 1A**: 初回バリアント生成（ベースライン構築 + 2バリアント）
  - **Phase 1B**: 継続バリアント生成（知見ベース + agent_audit 統合）
  - **Phase 2**: テスト文書生成（毎ラウンド実行、問題埋め込み + 正解キー）
  - **Phase 3**: 並列評価実行（プロンプト × 2回並列タスク）
  - **Phase 4**: 採点（サブエージェント並列実行、検出判定 + ボーナス/ペナルティ）
  - **Phase 5**: 分析レポート作成（推奨判定 + 収束判定）
  - **Phase 6A**: knowledge.md 更新（効果テーブル + バリエーションステータス）
  - **Phase 6B**: proven-techniques.md 更新（スキル横断知見フィードバック）
  - **Phase 6C**: 次アクション選択（次ラウンド/終了）

- データフロー:
  - Phase 0 → perspective-source.md, perspective.md, knowledge.md（初期化時）
  - Phase 1A/1B → prompts/v{NNN}-*.md（ベースライン + バリアント）
  - Phase 2 → test-document-round-{NNN}.md, answer-key-round-{NNN}.md
  - Phase 3 → results/v{NNN}-{name}-run{1,2}.md
  - Phase 4 → results/v{NNN}-{name}-scoring.md
  - Phase 5 → reports/round-{NNN}-comparison.md
  - Phase 6A → knowledge.md 更新
  - Phase 6B → proven-techniques.md 更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.claude/skills/agent_bench/perspectives/{target}/{key}.md` | perspective フォールバックパターン検索 |
| SKILL.md | 74 | `.claude/skills/agent_bench/perspectives/design/*.md` | 参照 perspective のサンプル収集（構造参考用） |
| SKILL.md | 174 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit の分析結果統合（Phase 1B） |
| templates/phase1b-variant-generation.md | 9 | `.agent_audit/{agent_name}/audit-*.md` | 同上 |

## D. コンテキスト予算分析
- SKILL.md 行数: 372行
- テンプレートファイル数: 13個、平均行数: 52行
- サブエージェント委譲: あり（Phase 0初期化、1A/1B、2、4、5、6A、6B、perspective生成・批評）
- 親コンテキストに保持される情報: エージェント名・パス、perspective解決ステータス、累計ラウンド数、プロンプトリスト、採点サマリ（7行サマリ形式）、デプロイ確認
- 3ホップパターンの有無: なし（サブエージェント間データ受け渡しは全てファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時のパス確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が空/不足時の要件ヒアリング（perspective 自動生成時） | 不明 |
| Phase 3 | AskUserQuestion | 一部プロンプトで成功結果が0回の場合の対応選択（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応選択（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | デプロイプロンプト選択（性能推移テーブル + 推奨を提示） | 不明 |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path が存在しない → エラー出力して終了（Phase 0）
  - perspective 未検出 → 自動生成実行（Phase 0 Step 4-6）
  - knowledge.md 不在 → 初期化処理実行（Phase 0）
- サブエージェント失敗時:
  - Phase 3（並列評価）: 成功数を集計し分岐（全失敗時は AskUserQuestion、一部成功時は警告して継続可能）
  - Phase 4（採点）: 失敗時は AskUserQuestion（再試行/除外/中断）
  - その他フェーズ: 記載なし（未定義）
- 部分完了時:
  - Phase 3/4: 最低1回の成功結果があれば継続可能（SD=N/A として扱う）
- 入力バリデーション:
  - agent_path の存在確認（Phase 0）
  - perspective 生成後の必須セクション検証（Phase 0 Step 6）
  - その他: 未定義

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（knowledge初期化） | sonnet | knowledge-init-template.md | 1行 | 1 |
| Phase 0（perspective生成） | sonnet | perspective/generate-perspective.md | 4行サマリ | 1 |
| Phase 0（perspective批評） | sonnet | critic-effectiveness.md, critic-completeness.md, critic-clarity.md, critic-generality.md | 各批評結果 | 4並列 |
| Phase 0（perspective再生成） | sonnet | perspective/generate-perspective.md | 4行サマリ | 1（条件付き） |
| Phase 1A | sonnet | phase1a-variant-generation.md | テーブル形式サマリ | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | テーブル形式サマリ | 1 |
| Phase 2 | sonnet | phase2-test-document.md | テーブル形式サマリ | 1 |
| Phase 3 | sonnet | 各プロンプト実行 | 「保存完了: {path}」のみ | (プロンプト数 × 2)並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2行スコアサマリ | プロンプト数並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行サマリ | 1 |
| Phase 6 Step 1（デプロイ） | haiku | インライン指示 | 1行確認 | 1（条件付き） |
| Phase 6 Step 2A | sonnet | phase6a-knowledge-update.md | 1行確認 | 1 |
| Phase 6 Step 2B | sonnet | phase6b-proven-techniques-update.md | 1行確認 | 1 |
