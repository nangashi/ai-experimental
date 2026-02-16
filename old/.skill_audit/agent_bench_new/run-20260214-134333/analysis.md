# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 386 | スキルメインエントリポイント。ワークフロー定義（Phase 0-6）、パス変数解決ルール、perspective自動生成、サブエージェント委譲パターンを定義 |
| approach-catalog.md | 202 | 改善アプローチカタログ。カテゴリ(S/C/N/M) → テクニック → バリエーション の3階層管理。実証済みテクニックと回避パターンを含む |
| scoring-rubric.md | 70 | 採点基準。検出判定（○/△/×）、スコア計算式、安定性閾値、推奨判定基準、収束判定を定義 |
| proven-techniques.md | 70 | エージェント横断の実証済み知見。効果テクニック（最大8件）、アンチパターン（最大8件）、条件付きテクニック（最大7件）、ベースライン構築ガイドを含む |
| test-document-guide.md | 254 | テスト文書生成ガイド。入力型判定（設計書/コード/要件/エージェント定義/汎用）、問題埋め込みガイドライン（深刻度分布、自然さの原則）、正解キーフォーマットを定義 |
| perspectives/code/maintainability.md | 34 | コードレビュー用保守性観点定義 |
| perspectives/code/security.md | 37 | コードレビュー用セキュリティ観点定義 |
| perspectives/code/performance.md | 37 | コードレビュー用パフォーマンス観点定義 |
| perspectives/code/best-practices.md | 34 | コードレビュー用ベストプラクティス観点定義 |
| perspectives/code/consistency.md | 33 | コードレビュー用一貫性観点定義 |
| perspectives/design/old/maintainability.md | 43 | 旧設計レビュー用保守性観点定義（`old/` 配下、非推奨） |
| perspectives/design/old/best-practices.md | 34 | 旧設計レビュー用ベストプラクティス観点定義（`old/` 配下、非推奨） |
| perspectives/design/consistency.md | 51 | 設計レビュー用一貫性観点定義 |
| perspectives/design/security.md | 43 | 設計レビュー用セキュリティ観点定義 |
| perspectives/design/structural-quality.md | 41 | 設計レビュー用構造的品質観点定義 |
| perspectives/design/performance.md | 45 | 設計レビュー用パフォーマンス観点定義 |
| perspectives/design/reliability.md | 43 | 設計レビュー用信頼性・運用性観点定義 |
| templates/perspective/critic-completeness.md | 107 | perspective批評エージェント（網羅性・未考慮事項検出・問題バンク品質評価） |
| templates/perspective/critic-clarity.md | 75 | perspective批評エージェント（表現明確性・AI動作一貫性評価） |
| templates/perspective/critic-effectiveness.md | 75 | perspective批評エージェント（品質寄与度・他観点との境界評価） |
| templates/phase2-test-document.md | 33 | Phase 2サブエージェント。テスト文書・正解キー生成テンプレート |
| templates/perspective/generate-perspective.md | 67 | perspective初期生成サブエージェント。必須スキーマ、入力型判定、問題バンク生成を含む |
| templates/perspective/critic-generality.md | 82 | perspective批評エージェント（汎用性・業界依存性評価） |
| templates/phase4-scoring.md | 16 | Phase 4サブエージェント。採点実行テンプレート |
| templates/phase6b-proven-techniques-update.md | 51 | Phase 6Bサブエージェント。proven-techniques.md更新ロジック（昇格条件、統合ルール、サイズ制限） |
| templates/phase5-analysis-report.md | 22 | Phase 5サブエージェント。比較レポート作成・推奨判定テンプレート |
| templates/knowledge-init-template.md | 61 | knowledge.md初期化サブエージェント。バリエーションステータステーブル生成を含む |
| templates/phase6a-knowledge-update.md | 27 | Phase 6Aサブエージェント。knowledge.md更新ロジック（preserve + integrate方式） |
| templates/phase1a-variant-generation.md | 42 | Phase 1Aサブエージェント（初回）。ベースライン作成・6次元構造分析・バリアント生成 |
| templates/perspective/orchestrate-perspective-generation.md | 63 | perspective自動生成オーケストレーション（使用されていないテンプレート、SKILL.mdに直接統合済み） |
| templates/phase1b-variant-generation.md | 33 | Phase 1Bサブエージェント（継続）。Broad/Deepモード選定・バリエーションステータステーブル参照・バリアント生成 |

## B. ワークフロー概要

### フェーズ構成
Phase 0（初期化） → 1A/1B（バリアント生成） → 2（テスト文書生成） → 3（並列評価） → 4（採点） → 5（分析・推奨） → 6（デプロイ・ナレッジ更新・次アクション）

### 各フェーズの目的
- **Phase 0**: エージェント読み込み、agent_name導出、perspective解決（検索→フォールバック→自動生成）、knowledge.md存在確認で初回/継続判定
- **Phase 1A（初回専用）**: ベースライン作成、6次元構造分析、approach-catalog参照で2バリアント生成、knowledge.md初期化
- **Phase 1B（継続専用）**: knowledge.mdのバリエーションステータステーブルからBroad/Deepモード選定、2バリアント生成、agent_audit結果統合
- **Phase 2**: perspective + 問題バンク + knowledge.mdからテスト文書・正解キー生成（毎ラウンド実行）
- **Phase 3**: 各プロンプト × 2回の並列評価（サブエージェント大量並列起動）
- **Phase 4**: プロンプトごとに採点サブエージェント並列起動（○/△/× 判定 + ボーナス/ペナルティ計算）
- **Phase 5**: 採点結果からスコアマトリクス生成、推奨判定、収束判定、比較レポート作成
- **Phase 6**: ユーザーがプロンプト選択 → デプロイ → (6A) knowledge.md更新 → (6B + 6C並列) proven-techniques.md更新 + 次アクション選択

### データフロー
- **Phase 0 → 1**: perspective.md（問題バンク除外版）、perspective-source.md（問題バンク含む）、knowledge.md の有無で分岐
- **Phase 1A → 2**: v001-baseline.md, v001-variant-*.md をprompts/配下に生成 → knowledge.mdに構造分析保存
- **Phase 1B → 2**: v{NNN}-baseline.md, v{NNN}-variant-*.md を生成
- **Phase 2 → 3**: test-document-round-{NNN}.md, answer-key-round-{NNN}.md を生成
- **Phase 3 → 4**: results/v{NNN}-{name}-run{1|2}.md を生成
- **Phase 4 → 5**: results/v{NNN}-{name}-scoring.md を生成
- **Phase 5 → 6**: reports/round-{NNN}-comparison.md を生成
- **Phase 6A**: knowledge.md を更新（preserve + integrate、20行上限）
- **Phase 6B**: proven-techniques.md を更新（昇格条件判定、サイズ制限8/8/7）

## C. 外部参照の検出

| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 54 | `.agent_bench/{agent_name}/perspective-source.md` | perspective検索（Step 4a） |
| SKILL.md | 58 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | reviewerパターンフォールバック（Step 4b） |
| SKILL.md | 78 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | 既存perspective参照データ収集（Step 2） |
| SKILL.md | 86 | `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` | perspective初期生成テンプレート（Step 3） |
| SKILL.md | 97-100 | `.claude/skills/agent_bench_new/templates/perspective/critic-*.md` | 批判レビューテンプレート4種（Step 4） |
| SKILL.md | 126 | `.agent_bench/{agent_name}/knowledge.md` | knowledge読み込み（共通処理） |
| SKILL.md | 133 | `.claude/skills/agent_bench_new/templates/knowledge-init-template.md` | knowledge初期化テンプレート |
| SKILL.md | 156 | `.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md` | Phase 1Aサブエージェントテンプレート |
| SKILL.md | 175 | `.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md` | Phase 1Bサブエージェントテンプレート |
| SKILL.md | 184 | `.agent_audit/{agent_name}/audit-dim1-*.md`, `.agent_audit/{agent_name}/audit-dim2-*.md` | agent_audit結果参照（Phase 1B） |
| SKILL.md | 193 | `.claude/skills/agent_bench_new/templates/phase2-test-document.md` | Phase 2サブエージェントテンプレート |
| SKILL.md | 259 | `.claude/skills/agent_bench_new/templates/phase4-scoring.md` | Phase 4採点テンプレート |
| SKILL.md | 281 | `.claude/skills/agent_bench_new/templates/phase5-analysis-report.md` | Phase 5分析レポートテンプレート |
| SKILL.md | 321 | `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` | Phase 6Aナレッジ更新テンプレート |
| SKILL.md | 351 | `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` | Phase 6Bスキル知見フィードバックテンプレート |
| templates/phase1a-variant-generation.md | 3-6 | proven-techniques.md, approach-catalog.md, perspective-source.md, perspective.md | ベースライン構築・バリアント生成の参照ファイル |
| templates/phase1b-variant-generation.md | 3-7 | knowledge.md, agent_path, proven-techniques.md, perspective.md, audit-dim1/dim2 | バリアント選定・生成の参照ファイル |
| templates/phase2-test-document.md | 3-6 | test-document-guide.md, perspective.md, perspective-source.md, knowledge.md | テスト文書生成の参照ファイル |
| templates/phase4-scoring.md | 2-6 | scoring-rubric.md, answer-key.md, perspective.md, result-run1/2 | 採点実行の参照ファイル |
| templates/phase5-analysis-report.md | 3-5 | scoring-rubric.md, knowledge.md, scoring結果ファイル群 | レポート作成の参照ファイル |
| templates/phase6a-knowledge-update.md | 3-5 | knowledge.md, 比較レポート | knowledge更新の参照ファイル |
| templates/phase6b-proven-techniques-update.md | 4-6 | proven-techniques.md, knowledge.md, 比較レポート | proven-techniques更新の参照ファイル |

**注記**: 全ての外部参照は `.claude/skills/agent_bench_new/` 配下（スキル内部）または `.agent_bench/{agent_name}/` 配下（スキル出力ディレクトリ）。プロジェクト外参照なし。

## D. コンテキスト予算分析

- **SKILL.md 行数**: 386行
- **テンプレートファイル数**: 11個（perspective関連5個 + phase関連6個）、平均行数: 52行
- **サブエージェント委譲**: あり（全フェーズで委譲パターン使用）
  - Phase 0: perspective自動生成（初回生成1 + 批評4並列 + 再生成1、knowledge初期化1）
  - Phase 1A/1B: バリアント生成（サブエージェント1）
  - Phase 2: テスト文書生成（サブエージェント1）
  - Phase 3: 並列評価（プロンプト数 × 2回の全並列起動）
  - Phase 4: 採点（プロンプト数分の並列起動）
  - Phase 5: 分析レポート（サブエージェント1）
  - Phase 6: knowledge更新（6A）+ proven-techniques更新（6B）の2並列
- **親コンテキストに保持される情報**:
  - エージェント基本情報（agent_name, agent_path）
  - perspective解決結果（検索/フォールバック/自動生成のパス）
  - 累計ラウンド数（knowledge.mdから抽出）
  - サブエージェントの返答サマリ（各フェーズで要約のみ保持、詳細はファイルに保存）
  - Phase 5の7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
- **3ホップパターンの有無**: なし
  - 全サブエージェント間のデータ受け渡しはファイル経由（Phase 1 → prompts/配下 → Phase 3、Phase 3 → results/配下 → Phase 4、等）
  - 親は各フェーズで必要なファイルパスのみ渡し、サブエージェントが直接ファイルを読み書きする設計

## E. ユーザーインタラクションポイント

| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0（初期化） | AskUserQuestion | agent_path未指定時の確認、エージェント定義が実質空の場合の要件ヒアリング | 不明（Fast mode言及なし） |
| Phase 3（並列評価） | AskUserQuestion | 評価タスク失敗時の再試行/除外/中断の選択 | 不明（Fast mode言及なし） |
| Phase 4（採点） | AskUserQuestion | 採点タスク失敗時の再試行/除外/中断の選択 | 不明（Fast mode言及なし） |
| Phase 6 Step 1（プロンプト選択） | AskUserQuestion | デプロイプロンプトの選択（推奨プロンプトを含む全プロンプトから選択） | 不明（Fast mode言及なし） |
| Phase 6 Step 2-C（次アクション） | AskUserQuestion | 次ラウンドへ/終了の選択（収束判定・累計ラウンド数による推奨付き） | 不明（Fast mode言及なし） |

**注記**: SKILL.md にFast modeでの中間確認スキップに関する明示的な記述なし。全ての `AskUserQuestion` が必須実行と推測される。

## F. エラーハンドリングパターン

### ファイル不在時
- **perspective-source.md不在**: 検索失敗 → reviewerパターンフォールバック → 自動生成（Phase 0、明示的フロー）
- **knowledge.md不在**: 初期化実行 → Phase 1A（初回ルート）に分岐（Phase 0、明示的フロー）
- **agent_path不在**: `AskUserQuestion` で確認（Phase 0）、または新規生成モード（Phase 1A）
- **reference_perspective_path不在**: `{reference_perspective_path}` を空として扱う（Phase 0 Step 2）
- **audit-dim1/dim2不在**: 変数を渡さない（Phase 1B、オプショナル扱い）

### サブエージェント失敗時
- **Phase 3評価タスク失敗**: 成功数を集計 → (1)全成功=Phase 4へ、(2)最低1回成功あり=警告出力してPhase 4へ、(3)0回成功あり=`AskUserQuestion`で再試行/除外/中断
- **Phase 4採点タスク失敗**: 成功数を集計 → (1)全成功=Phase 5へ、(2)一部失敗=`AskUserQuestion`で再試行/除外/中断（ベースライン失敗時は中断）
- **その他フェーズ**: 明示的なエラーハンドリング記載なし（失敗時の挙動未定義）

### 部分完了時
- **Phase 3で一部プロンプトの評価失敗**: 成功結果のみでPhase 4採点（警告出力、Run1回のみのプロンプトはSD=N/A）
- **Phase 4で一部プロンプトの採点失敗**: 成功プロンプトのみでPhase 5へ（ただしベースライン失敗時は中断）

### 入力バリデーション
- **agent_path未指定**: `AskUserQuestion` で確認（Phase 0）
- **perspective必須セクション欠落**: エラー出力してスキル終了（Phase 0 Step 6検証）
- **knowledge.md構造検証**: 8個の必須セクション存在確認 → 欠落時はエラー出力して中断（Phase 6A-1）
- **その他入力**: 明示的なバリデーション記載なし

## G. サブエージェント一覧

| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0（perspective初期生成） | sonnet | templates/perspective/generate-perspective.md | 4行サマリ | 1 |
| Phase 0（perspective批評） | sonnet | templates/perspective/critic-effectiveness.md | 不定（批評レポート） | 4並列 |
| Phase 0（perspective批評） | sonnet | templates/perspective/critic-completeness.md | 不定（批評レポート） | 4並列 |
| Phase 0（perspective批評） | sonnet | templates/perspective/critic-clarity.md | 不定（批評レポート） | 4並列 |
| Phase 0（perspective批評） | sonnet | templates/perspective/critic-generality.md | 不定（批評レポート） | 4並列 |
| Phase 0（perspective再生成） | sonnet | templates/perspective/generate-perspective.md（再実行） | 4行サマリ | 1（条件付き） |
| Phase 0（knowledge初期化） | sonnet | templates/knowledge-init-template.md | 1行確認 | 1（条件付き） |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 不定（構造分析テーブル + バリアント一覧） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 不定（選定プロセス + バリアント一覧） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 不定（テスト文書サマリ + 問題一覧テーブル） | 1 |
| Phase 3 | sonnet | インラインプロンプト（Read + 処理 + Write + 確認） | 1行確認 | (プロンプト数 × 2) 全並列 |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行サマリ | プロンプト数分並列 |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary） | 1 |
| Phase 6A | sonnet | templates/phase6a-knowledge-update.md | 1行確認 | 1 |
| Phase 6B | sonnet | templates/phase6b-proven-techniques-update.md | 1行確認 | 1（6Aと並列） |

**注記**:
- Phase 3の並列数は動的（ベースライン1 + バリアント数）× 2回
- Phase 4の並列数は動的（評価成功したプロンプト数）
- Phase 6A完了後にPhase 6Bと6Cが並列起動（6CはユーザーインタラクションでTask扱いではない）
