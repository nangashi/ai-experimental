# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 362 | スキルのメインワークフロー定義（Phase 0-6） |
| approach-catalog.md | 201 | プロンプト改善アプローチカタログ（S/C/N/M 4カテゴリ） |
| proven-techniques.md | 69 | エージェント横断の実証済み知見（自動更新） |
| scoring-rubric.md | 69 | 採点基準と推奨判定ルール |
| test-document-guide.md | 253 | テスト文書生成ガイド（入力型判定・問題埋め込み） |
| templates/knowledge-init-template.md | 52 | knowledge.md 初期化テンプレート |
| templates/phase0-perspective-resolution.md | 37 | perspective 検索・解決ロジック |
| templates/phase0-perspective-generation.md | 87 | perspective 自動生成（標準版・4批評並列） |
| templates/phase0-perspective-generation-simple.md | 29 | perspective 簡易生成（批評スキップ） |
| templates/phase1a-variant-generation.md | 40 | 初回バリアント生成（ベースライン作成含む） |
| templates/phase1b-variant-generation.md | 41 | 継続バリアント生成（knowledge ベース） |
| templates/phase2-test-document.md | 32 | テスト文書・正解キー生成 |
| templates/phase3-evaluation.md | 18 | エージェント評価実行 |
| templates/phase3-error-handling.md | 42 | Phase 3 エラー分岐ロジック |
| templates/phase4-scoring.md | 12 | 採点実行 |
| templates/phase5-analysis-report.md | 21 | 比較レポート作成・推奨判定 |
| templates/phase6-performance-table.md | 39 | 性能推移テーブル生成・プロンプト選択 |
| templates/phase6-deploy.md | 19 | プロンプトデプロイ |
| templates/phase6a-knowledge-update.md | 28 | knowledge.md 更新 |
| templates/phase6b-proven-techniques-update.md | 51 | proven-techniques.md 更新 |
| templates/perspective/generate-perspective.md | 66 | perspective 初期生成 |
| templates/perspective/critic-clarity.md | 75 | 明確性批評（表現の曖昧性） |
| templates/perspective/critic-completeness.md | 107 | 網羅性批評（未考慮事項検出） |
| templates/perspective/critic-effectiveness.md | 72 | 有効性批評（品質寄与度） |
| templates/perspective/critic-generality.md | 81 | 汎用性批評（業界依存性） |
| perspectives/design/consistency.md | 51 | 設計一貫性評価観点 |
| perspectives/design/security.md | 42 | 設計セキュリティ評価観点 |
| perspectives/design/structural-quality.md | 41 | 設計構造品質評価観点 |
| perspectives/design/performance.md | 44 | 設計パフォーマンス評価観点 |
| perspectives/design/reliability.md | 43 | 設計信頼性評価観点 |
| perspectives/code/best-practices.md | 34 | コードベストプラクティス評価観点 |
| perspectives/code/consistency.md | 33 | コード一貫性評価観点 |
| perspectives/code/maintainability.md | 34 | コード保守性評価観点 |
| perspectives/code/security.md | 37 | コードセキュリティ評価観点 |
| perspectives/code/performance.md | 37 | コードパフォーマンス評価観点 |
| perspectives/design/old/best-practices.md | 34 | （旧版・参照不要） |
| perspectives/design/old/maintainability.md | 43 | （旧版・参照不要） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- 各フェーズの目的:
  - **Phase 0**: 初期化・agent_name 導出・perspective 解決/生成・knowledge.md 初期化（初回のみ）・Phase 1A/1B 分岐
  - **Phase 1A**: 初回 — proven-techniques.md ベースのベースライン作成 + 2バリアント生成
  - **Phase 1B**: 継続 — knowledge.md ベースのバリアント生成（Broad/Deep モード切替）+ agent_audit 統合候補の提示
  - **Phase 2**: テスト文書・正解キー生成（perspective の問題バンク参照、過去ドメイン重複回避）
  - **Phase 3**: 並列評価実行（プロンプト数×2回）+ エラーハンドリング（4分岐）
  - **Phase 4**: 採点（並列）→ 検出判定（○△×）+ ボーナス/ペナルティ集計
  - **Phase 5**: 比較レポート作成・推奨判定（scoring-rubric.md の基準に従う）
  - **Phase 6**: プロンプト選択（AskUserQuestion）→ デプロイ（haiku） → knowledge.md 更新 → proven-techniques.md 更新（並列）→ 次アクション選択
- データフロー:
  - Phase 0 → `.agent_bench/{agent_name}/perspective.md`, `knowledge.md` (初回)
  - Phase 1A → `.agent_bench/{agent_name}/prompts/v001-*.md`
  - Phase 1B → `.agent_bench/{agent_name}/prompts/v{NNN}-*.md`
  - Phase 2 → `test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
  - Phase 3 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1,2}.md`
  - Phase 4 → `results/v{NNN}-{name}-scoring.md`
  - Phase 5 → `reports/round-{NNN}-comparison.md`
  - Phase 6 → `{agent_path}` (デプロイ), `knowledge.md`, `proven-techniques.md`

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 161-163 | `.agent_audit/{agent_name}/audit-*.md` | Phase 1B で agent_audit の分析結果を読み込み、改善候補を統合 |
| templates/phase1b-variant-generation.md | 11 | `.agent_audit/{agent_name}/audit-*.md` | 同上（テンプレート側でも参照） |

## D. コンテキスト予算分析
- SKILL.md 行数: 362行
- テンプレートファイル数: 20個、平均行数: 41.7行
- サブエージェント委譲: あり（全Phaseでサブエージェント使用）
  - 委譲パターン: Phase 0-6 の各処理をテンプレートファイル指示 + パス変数で委譲
  - モデル: sonnet（Phase 0-6 主要処理）, haiku（Phase 6 デプロイのみ）
- 親コンテキストに保持される情報:
  - agent_name, agent_path, perspective_path, knowledge_path の絶対パス
  - Phase 5 のサブエージェント返答（7行サマリ: recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - 各 Phase の成功/失敗状態
- 3ホップパターンの有無: なし（サブエージェント間のデータ受け渡しはファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が不足時の要件ヒアリング | 不明 |
| Phase 0 | AskUserQuestion | perspective 自動生成モード選択（標準/簡略） | 不明 |
| Phase 1A | AskUserQuestion | 既存プロンプトファイル上書き/スキップ確認 | 不明 |
| Phase 1B | AskUserQuestion | 既存プロンプトファイル上書き/スキップ確認 | 不明 |
| Phase 1B | AskUserQuestion | Audit 統合候補の承認/却下 | 不明 |
| Phase 2 | AskUserQuestion | サブエージェント失敗時の再試行/中断 | 不明 |
| Phase 3 | AskUserQuestion | ベースライン全失敗時の再試行/中断 | 不明 |
| Phase 3 | AskUserQuestion | バリアント全失敗時の再試行/除外/中断 | 不明 |
| Phase 4 | AskUserQuestion | 一部失敗時の再試行/除外/中断 | 不明 |
| Phase 6 | AskUserQuestion | プロンプト選択（性能推移テーブル提示） | 不明 |
| Phase 6 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- ファイル不在時:
  - agent_path 読み込み失敗: エラー出力して終了
  - perspective-source.md 不在: フォールバック検索（`perspectives/{target}/{key}.md`）→ 失敗時は perspective 自動生成
  - knowledge.md 不在: 初期化して Phase 1A へ
  - knowledge.md 存在: Phase 1B へ
- サブエージェント失敗時:
  - Phase 0（perspective 解決）: perspective 自動生成にフォールバック
  - Phase 0（perspective 自動生成）: エラーメッセージ出力 + 対処法提示して終了
  - Phase 0（knowledge 初期化）: エラー出力して終了
  - Phase 1A/1B: エラー出力して終了
  - Phase 2: AskUserQuestion で再試行/中断（再試行は1回のみ）
  - Phase 3: templates/phase3-error-handling.md の4分岐ロジックに従う（全成功/ベースライン全失敗/部分失敗/バリアント全失敗）
  - Phase 4: ベースライン成功の場合のみ再試行/除外/中断を選択可、ベースライン失敗時は中断
  - Phase 5: エラー出力して終了
  - Phase 6B（proven-techniques 更新）: 警告出力して続行（任意処理のため）
- 部分完了時:
  - Phase 3: 成功した Run のみで Phase 4 へ進む（Run1回のみの場合 SD=N/A）
  - Phase 4: ベースライン成功かつ部分失敗の場合、成功プロンプトのみで Phase 5 へ
- 入力バリデーション:
  - agent_path の存在確認（Phase 0）
  - perspective.md の必須セクション検証（Phase 0 最終ステップ）
  - knowledge.md のバリエーションステータステーブル読み込み（Phase 1B）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 | sonnet | phase0-perspective-resolution.md | 1行 | 1 |
| Phase 0 | sonnet | phase0-perspective-generation.md | 1行 | 1 |
| Phase 0 | sonnet | phase0-perspective-generation-simple.md | 1行 | 1 |
| Phase 0 | sonnet | perspective/generate-perspective.md | 4行 | 1 |
| Phase 0 | sonnet | perspective/critic-clarity.md | 返答形式指定 | 4並列 |
| Phase 0 | sonnet | perspective/critic-completeness.md | 返答形式指定 | 4並列 |
| Phase 0 | sonnet | perspective/critic-effectiveness.md | 返答形式指定 | 4並列 |
| Phase 0 | sonnet | perspective/critic-generality.md | 返答形式指定 | 4並列 |
| Phase 0 | sonnet | knowledge-init-template.md | 1行 | 1 |
| Phase 1A | sonnet | phase1a-variant-generation.md | 返答形式指定 | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 返答形式指定 | 1 |
| Phase 2 | sonnet | phase2-test-document.md | テーブル形式 | 1 |
| Phase 3 | sonnet | phase3-evaluation.md | 1行 | (プロンプト数×2)並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2行 | プロンプト数並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行固定 | 1 |
| Phase 6 | haiku | phase6-deploy.md | 1行 | 1 |
| Phase 6 | sonnet | phase6a-knowledge-update.md | 1行 | 1 |
| Phase 6 | sonnet | phase6b-proven-techniques-update.md | 1行 | 1 |
