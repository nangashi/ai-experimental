# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 380 | スキルのメインワークフロー定義。Phase 0-6の全フェーズと外部委譲パターンを記述 |
| approach-catalog.md | 202 | 改善アプローチのカタログ（S/C/N/M 4カテゴリ、各カテゴリ複数テクニック+バリエーション） |
| scoring-rubric.md | 70 | 検出判定基準（○△×）、スコア計算式、推奨判定基準、収束判定 |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック（効果/アンチパターン/条件付き/ベースラインガイド） |
| test-document-guide.md | 254 | テスト対象文書と正解キーの生成ガイドライン（入力型判定、問題埋め込み、深刻度分布） |
| templates/knowledge-init-template.md | 53 | knowledge.md の初期化テンプレート（バリエーションステータステーブル生成を含む） |
| templates/phase1a-variant-generation.md | 41 | Phase 1A（初回ラウンド）のバリアント生成手順 |
| templates/phase1b-variant-generation.md | 39 | Phase 1B（継続ラウンド）の知見ベースバリアント生成手順 |
| templates/phase2-test-document.md | 33 | Phase 2 のテスト対象文書と正解キー生成手順 |
| templates/phase3-evaluation.md | 7 | Phase 3 の並列評価実行手順（エージェント定義に従ってタスク実行） |
| templates/phase4-scoring.md | 13 | Phase 4 の採点手順（検出判定○△×とボーナス/ペナルティ計算） |
| templates/phase5-analysis-report.md | 24 | Phase 5 の分析・推奨判定・レポート作成手順 |
| templates/phase6a-deploy.md | 7 | Phase 6 Step 1 のプロンプトデプロイ手順 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6 Step 2A の knowledge.md 更新手順 |
| templates/phase6b-proven-techniques-update.md | 55 | Phase 6 Step 2B の proven-techniques.md 更新手順（昇格条件・統合ルール・サイズ制限） |
| templates/perspective/generate-perspective.md | 80 | perspective 自動生成の手順（必須スキーマと生成ガイドライン） |
| templates/perspective/critic-effectiveness.md | 75 | perspective 有効性批評（寄与度・境界明確性） |
| templates/perspective/critic-completeness.md | 114 | perspective 網羅性批評（欠落検出能力・問題バンク品質）+統合フィードバック生成 |
| templates/perspective/critic-clarity.md | 76 | perspective 明確性批評（表現の曖昧性・AI動作一貫性） |
| templates/perspective/critic-generality.md | 82 | perspective 汎用性批評（業界依存性・技術スタック依存性） |
| perspectives/code/best-practices.md | 34 | コードレビュー観点: ベストプラクティス |
| perspectives/code/consistency.md | 未読 | コードレビュー観点: 一貫性 |
| perspectives/code/maintainability.md | 未読 | コードレビュー観点: 保守性 |
| perspectives/code/security.md | 未読 | コードレビュー観点: セキュリティ |
| perspectives/code/performance.md | 未読 | コードレビュー観点: パフォーマンス |
| perspectives/design/consistency.md | 未読 | 設計レビュー観点: 一貫性 |
| perspectives/design/security.md | 43 | 設計レビュー観点: セキュリティ |
| perspectives/design/structural-quality.md | 未読 | 設計レビュー観点: 構造的品質 |
| perspectives/design/performance.md | 未読 | 設計レビュー観点: パフォーマンス |
| perspectives/design/reliability.md | 未読 | 設計レビュー観点: 信頼性 |
| perspectives/design/old/best-practices.md | 未読 | 旧版（/old/ 配下はスキップ対象） |
| perspectives/design/old/maintainability.md | 未読 | 旧版（/old/ 配下はスキップ対象） |

**注記**: perspectives/ 配下の未読ファイルは参照用データファイルであり、ワークフロー実行には直接関与しない。

## B. ワークフロー概要

### フェーズ構成
Phase 0 → Phase 1A/1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6

### 各フェーズの目的
- **Phase 0: 初期化・状態検出**
  - エージェント定義ファイル読み込み、agent_name 導出、perspective 解決（検索 or 自動生成）、knowledge.md 状態確認
  - perspective 未検出時: 4並列批評レビュー → 統合フィードバック → 再生成（1回のみ）
  - knowledge.md 不在時: 初期化テンプレートでバリエーションステータステーブルを生成
  - 継続/初回判定により Phase 1A または Phase 1B へ分岐
- **Phase 1A: 初回 — ベースライン作成 + バリアント生成**
  - proven-techniques.md のベースライン構築ガイドに従いベースライン作成（エージェント定義不在時は新規生成）
  - 構造分析に基づき approach-catalog.md から2つの独立変数を選定してバリアント生成
  - 全プロンプトを prompts/ に保存（Benchmark Metadata コメント付き）
- **Phase 1B: 継続 — 知見ベースのバリアント生成**
  - knowledge.md のバリエーションステータステーブルから Broad/Deep モード判定
  - Broad: UNTESTED カテゴリの基本バリエーション選択
  - Deep: 最も効果が高かった EFFECTIVE カテゴリ内の UNTESTED バリエーション選択
  - agent_audit 結果（audit-*.md）が存在する場合は改善推奨を考慮
  - ベースライン（比較用コピー）+ 2バリアント生成
- **Phase 2: テスト入力文書生成（毎ラウンド実行）**
  - perspective から入力型判定（設計書/コード/要件/エージェント定義/汎用）
  - test-document-guide.md に従い、8-10個の問題を自然に埋め込んだテスト対象文書生成
  - 正解キー生成（問題ID、検出判定基準○△×、ボーナス問題リスト）
  - knowledge.md の履歴から重複しないドメインを選択（多様性確保）
- **Phase 3: 並列評価実行**
  - 各プロンプト × 2回を並列実行（Task ツール、sonnet）
  - 成功数を集計し、失敗時は再試行 or 除外 or 中断の選択肢を提示
- **Phase 4: 採点（サブエージェントの並列実行）**
  - プロンプトごとに1つの採点サブエージェント起動（並列実行、sonnet）
  - scoring-rubric.md の基準に従い検出判定（○△×）とボーナス/ペナルティを計算
  - Run1/Run2 のスコアと SD を算出
- **Phase 5: 分析・推奨判定・レポート作成**
  - 採点結果から推奨プロンプト判定（scoring-rubric.md の推奨判定基準に従う）
  - 収束判定（直近の改善幅を評価）
  - 比較レポート生成（reports/round-{NNN}-comparison.md）
  - 7行サマリ返答（recommended/reason/convergence/scores/variants/deploy_info/user_summary）
- **Phase 6: プロンプト選択・デプロイ・次アクション**
  - Step 1: ユーザーに性能推移テーブルと推奨を提示 → 選択されたプロンプトをデプロイ（haiku）
  - Step 2A: knowledge.md 更新（累計ラウンド数+1、バリエーションステータス更新、効果テーブル更新、sonnet）
  - Step 2B: proven-techniques.md 更新（昇格条件判定、統合ルール適用、サイズ制限遵守、sonnet）
  - Step 3: 次アクション選択（次ラウンド or 終了）

### データフロー
```
Phase 0:
  Read: エージェント定義 → perspective 検索/生成 → knowledge.md 読み込み
  Write: perspective-source.md, perspective.md, knowledge.md (初期化時)

Phase 1A:
  Read: proven-techniques.md, approach-catalog.md, perspective-source.md, エージェント定義（存在時）
  Write: prompts/v001-baseline.md, prompts/v001-variant-*.md, エージェント定義（新規生成時）

Phase 1B:
  Read: knowledge.md, エージェント定義, proven-techniques.md, perspective.md, audit-*.md（存在時）
  Read (Deep時のみ): approach-catalog.md
  Write: prompts/v{NNN}-baseline.md, prompts/v{NNN}-variant-*.md

Phase 2:
  Read: test-document-guide.md, perspective.md, perspective-source.md, knowledge.md
  Write: test-document-round-{NNN}.md, answer-key-round-{NNN}.md

Phase 3:
  Read: prompt_path, test-doc-path
  Write: results/v{NNN}-{name}-run{1,2}.md

Phase 4:
  Read: scoring-rubric.md, answer-key.md, perspective.md, result-run1.md, result-run2.md
  Write: results/v{NNN}-{name}-scoring.md

Phase 5:
  Read: scoring-rubric.md, knowledge.md, scoring files
  Write: reports/round-{NNN}-comparison.md

Phase 6 Step 1:
  Read: knowledge.md, selected_prompt_path
  Write: エージェント定義ファイル（デプロイ）

Phase 6 Step 2A:
  Read: knowledge.md, comparison report
  Write: knowledge.md（更新）

Phase 6 Step 2B:
  Read: proven-techniques.md, knowledge.md, comparison report
  Write: proven-techniques.md（更新）
```

## C. 外部参照の検出

| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 66-67 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | perspective のフォールバック検索（パターンマッチング） |
| SKILL.md | 87 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | perspective 自動生成時の参照データ収集 |
| SKILL.md | 94 | `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` | perspective 初期生成テンプレート |
| SKILL.md | 105-118 | `.claude/skills/agent_bench_new/templates/perspective/{critic-*.md}` | 4並列批評レビューテンプレート |
| SKILL.md | 110 | `.claude/skills/agent_bench_new/perspectives/{target}/*.md` | 既存 perspective サマリ生成（critic 用） |
| SKILL.md | 132, 147 | `.agent_bench/{agent_name}/` | 出力ディレクトリ（スキルが管理する外部領域） |
| SKILL.md | 195 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit スキルの分析結果（存在時に参照） |
| phase1a-variant-generation.md | 6, 9 | `.claude/skills/agent_bench_new/perspective-source.md`, `perspective.md` | perspective 参照 |
| phase1b-variant-generation.md | 7 | `.claude/skills/agent_bench_new/perspective.md` | perspective 参照 |
| phase2-test-document.md | 8 | `.claude/skills/agent_bench_new/test-document-guide.md` | テスト文書生成ガイド |
| phase4-scoring.md | 3 | `.claude/skills/agent_bench_new/scoring-rubric.md` | 採点基準 |
| phase5-analysis-report.md | 4 | `.claude/skills/agent_bench_new/scoring-rubric.md` | 推奨判定基準 |
| phase6b-proven-techniques-update.md | 4 | `.claude/skills/agent_bench_new/proven-techniques.md` | スキルレベル知見 |

**外部参照パターン**:
- `.claude/skills/agent_bench_new/` 配下のファイル: スキル定義の一部として管理されている静的ファイル（perspectives, templates, カタログ、ルーブリック等）
- `.agent_bench/{agent_name}/` 配下: スキル実行時に生成される動的ファイル（エージェント単位の出力）
- `.agent_audit/{agent_name}/` 配下: 他スキル（agent_audit）との連携ポイント（オプショナル参照）

## D. コンテキスト予算分析

- **SKILL.md 行数**: 380行
- **テンプレートファイル数**: 15個、平均行数: 48行（範囲: 7-114行）
- **サブエージェント委譲**: あり
  - **Phase 0 perspective 自動生成**: 1 initial generation (sonnet) + 4 parallel critics (sonnet) + 1 regeneration (sonnet) = 最大6サブエージェント
  - **Phase 0 knowledge 初期化**: 1サブエージェント (sonnet)
  - **Phase 1A**: 1サブエージェント (sonnet)
  - **Phase 1B**: 1サブエージェント (sonnet)
  - **Phase 2**: 1サブエージェント (sonnet)
  - **Phase 3**: (プロンプト数) × 2 並列サブエージェント (sonnet) = 通常6タスク（ベースライン1 + バリアント2）× 2回
  - **Phase 4**: (プロンプト数) 並列サブエージェント (sonnet) = 通常3タスク
  - **Phase 5**: 1サブエージェント (sonnet)
  - **Phase 6 Step 1**: 1サブエージェント (haiku、デプロイ選択時のみ)
  - **Phase 6 Step 2**: 2並列サブエージェント (sonnet) = knowledge 更新 + proven-techniques 更新
- **親コンテキストに保持される情報**:
  - agent_path, agent_name, perspective_source_path, perspective_path
  - knowledge.md の累計ラウンド数、バリエーションステータステーブル、効果テーブル（Phase 0 で抽出）
  - Phase 3 成功数集計（タスク完了の成否のみ、結果本文は保持しない）
  - Phase 4 採点サブエージェントの返答（スコアサマリ1-2行のみ、詳細は results/ に保存）
  - Phase 5 サブエージェントの返答（7行サマリのみ、詳細は reports/ に保存）
- **3ホップパターンの有無**: なし
  - 全サブエージェント間のデータ受け渡しはファイル経由
  - 親は各サブエージェントの完了確認と最小限のサマリ（1-2行または7行）のみ受け取る
  - Phase 1A/1B → Phase 2: prompts/ ディレクトリ経由
  - Phase 2 → Phase 3: test-document-round-{NNN}.md 経由
  - Phase 3 → Phase 4: results/v{NNN}-{name}-run{1,2}.md 経由
  - Phase 4 → Phase 5: results/v{NNN}-{name}-scoring.md 経由
  - Phase 5 → Phase 6: reports/round-{NNN}-comparison.md 経由

**コンテキスト節約の評価**:
- ✓ 参照ファイルは使用するPhaseでのみ読み込む（先読みしない）
- ✓ 大量コンテンツの生成はサブエージェントに委譲する（全Phase）
- ✓ サブエージェントからの返答は最小限（Phase 4: 1-2行、Phase 5: 7行）
- ✓ 親コンテキストには要約・メタデータのみ保持（knowledge.md からの抽出も最小限）
- ✓ サブエージェント間のデータ受け渡しはファイル経由（親を中継しない）

## E. ユーザーインタラクションポイント

| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 Step 1 | AskUserQuestion | agent_path が未指定の場合の確認 | 不明 |
| Phase 0 Step 1 (自動生成時) | AskUserQuestion | エージェント定義が不十分な場合の要件ヒアリング | 不明 |
| Phase 3 | AskUserQuestion | いずれかのプロンプトで成功結果が0回の場合の対応選択（再試行/除外/中断） | 不明 |
| Phase 4 | AskUserQuestion | 一部の採点タスクが失敗した場合の対応選択（再試行/除外/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（推奨提示+全プロンプト選択肢） | 不明 |
| Phase 6 Step 3 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

**Fast mode に関する記載**: SKILL.md および全テンプレートファイルに Fast mode の明示的な記載なし。

## F. エラーハンドリングパターン

- **ファイル不在時**:
  - エージェント定義ファイル不在（Phase 0 Step 2）: エラー出力して終了
  - perspective 未検出（Phase 0 Step 4c）: 自動生成フロー実行
  - knowledge.md 不在（Phase 0 Step 7）: 初期化テンプレートで新規作成
  - プロンプトファイル既存（Phase 1A Step 3, Phase 1B Step 3-4）: 警告出力、保存スキップ
- **サブエージェント失敗時**:
  - Phase 3（評価実行）: 成功数を集計し、全失敗時は AskUserQuestion で対応選択（再試行/除外/中断）
  - Phase 4（採点）: 成功数を集計し、一部失敗時は AskUserQuestion で対応選択（再試行/除外/中断）
  - Phase 6 Step 2: サブエージェント完了確認後に次アクション選択へ進む（失敗時の明示的ハンドリング記載なし）
- **部分完了時**:
  - Phase 3: 各プロンプトに最低1回の成功結果がある場合、警告を出力して Phase 4 へ進む（SD は N/A とする）
  - Phase 4: 成功したプロンプトのみで Phase 5 へ進む（ベースライン失敗時は中断）
- **入力バリデーション**:
  - Phase 0 Step 2: エージェント定義ファイルの読み込み失敗チェック
  - Phase 0 Step 6 (自動生成): 生成された perspective の必須セクション存在確認、検証失敗時はエラー出力してスキル終了

**改善可能性**: Phase 6 Step 2 のサブエージェント失敗時のハンドリングが明示的でない。knowledge.md または proven-techniques.md の更新失敗時のリカバリー手順が未定義。

## G. サブエージェント一覧

| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (perspective 生成 Step 3) | sonnet | perspective/generate-perspective.md | 4行（観点名/入力型/評価スコープ/問題バンク件数） | 1 |
| Phase 0 (perspective 批評 Step 4) | sonnet | perspective/critic-effectiveness.md | 不定（保存完了メッセージのみ） | 4並列 |
| Phase 0 (perspective 批評 Step 4) | sonnet | perspective/critic-completeness.md | 不定（統合フィードバック内容） | 上記に含む |
| Phase 0 (perspective 批評 Step 4) | sonnet | perspective/critic-clarity.md | 不定（保存完了メッセージのみ） | 上記に含む |
| Phase 0 (perspective 批評 Step 4) | sonnet | perspective/critic-generality.md | 不定（保存完了メッセージのみ） | 上記に含む |
| Phase 0 (perspective 再生成 Step 5) | sonnet | perspective/generate-perspective.md | 4行 | 1（条件付き） |
| Phase 0 (knowledge 初期化) | sonnet | knowledge-init-template.md | 1行（完了メッセージ+バリエーション数） | 1 |
| Phase 1A | sonnet | phase1a-variant-generation.md | 不定（エージェント定義2節+構造分析テーブル+バリアント2-3節） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation.md | 不定（選定プロセス2節+バリアント2節） | 1 |
| Phase 2 | sonnet | phase2-test-document.md | 不定（テスト対象文書サマリ3節+問題一覧テーブル+ボーナステーブル） | 1 |
| Phase 3 | sonnet | phase3-evaluation.md | 1行（保存完了メッセージ） | (プロンプト数) × 2 = 通常6並列 |
| Phase 4 | sonnet | phase4-scoring.md | 2行（スコアサマリ） | (プロンプト数) = 通常3並列 |
| Phase 5 | sonnet | phase5-analysis-report.md | 7行（recommended/reason/convergence/scores/variants/deploy_info/user_summary） | 1 |
| Phase 6 Step 1 | haiku | phase6a-deploy.md | 1行（デプロイ完了メッセージ） | 1（条件付き） |
| Phase 6 Step 2A | sonnet | phase6a-knowledge-update.md | 1行（更新完了+累計ラウンド数） | 1 |
| Phase 6 Step 2B | sonnet | phase6b-proven-techniques-update.md | 1行（更新完了 or 更新なし） | 1 |

**並列パターン**:
- Phase 0 Step 4: 4並列（critic × 4種類）
- Phase 3: (ベースライン1 + バリアント2) × 2回 = 6並列
- Phase 4: (ベースライン1 + バリアント2) = 3並列
- Phase 6 Step 2: 2並列（knowledge 更新 + proven-techniques 更新）

**総サブエージェント数（1ラウンド）**:
- Phase 0（初回のみ、perspective 自動生成あり）: 最大6
- Phase 0（初回のみ、knowledge 初期化）: 1
- Phase 1A（初回のみ）: 1
- Phase 1B（継続時）: 1
- Phase 2-6: 1 + 6 + 3 + 1 + 0-1 + 2 = 13-14
- **初回ラウンド合計**: 最大 6 + 1 + 1 + 13-14 = 21-22
- **継続ラウンド合計**: 1 + 13-14 = 14-15
