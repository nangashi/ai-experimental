# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 396 | メインスキル定義。ワークフロー、Phase 0-6の処理手順、パス変数解決ルール、コンテキスト節約原則を定義 |
| approach-catalog.md | 202 | 構造改善アプローチのカタログ。4カテゴリ(S/C/N/M) × 複数テクニック × バリエーションの3階層で管理。実証済み効果と回避すべきパターンを記載 |
| scoring-rubric.md | 70 | 採点基準。検出判定基準(○/△/×)、スコア計算式、安定性閾値、推奨判定ルール、収束判定ルールを定義 |
| test-document-guide.md | 254 | テスト対象文書生成ガイド。入力型判定、文書構成テンプレート、問題埋め込みガイドライン、正解キーフォーマット、多様性確保ルールを定義 |
| proven-techniques.md | 70 | エージェント横断で実証されたテクニックの知見集約。自動更新対象。実証済み効果テクニック、回避すべきアンチパターン、条件付きテクニック、ベースライン構築ガイドの4セクション |
| templates/knowledge-init-template.md | 53 | knowledge.md初期化テンプレート。効果テーブル、バリエーションステータステーブル、ラウンド別スコア推移、改善のための考慮事項のスキーマ定義 |
| templates/phase1a-variant-generation.md | 41 | Phase 1A (初回ラウンド) のバリアント生成指示。ベースライン構築+2バリアント生成。proven-techniques.mdのベースライン構築ガイドに従う |
| templates/phase1b-variant-generation.md | 36 | Phase 1B (継続ラウンド) のバリアント生成指示。BroadモードとDeepモードの選定ロジック、agent_audit連携、アンチパターン回避 |
| templates/phase2-test-document.md | 33 | Phase 2 のテスト対象文書生成指示。入力型判定、問題埋め込み、正解キー生成、多様性確保 |
| templates/phase4-scoring.md | 13 | Phase 4 の採点指示。検出判定、ボーナス/ペナルティ判定、スコアサマリ返答フォーマット |
| templates/phase5-analysis-report.md | 24 | Phase 5 の分析レポート作成指示。推奨判定、収束判定、7行サマリ返答フォーマット |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A のknowledge.md更新指示。効果テーブル更新、バリエーションステータス更新、ラウンド別スコア推移追記、改善のための考慮事項の統合ルール |
| templates/phase6b-proven-techniques-update.md | 51 | Phase 6B のproven-techniques.md更新指示。昇格条件(Tier 1/2/3)、統合ルール(preserve + integrate)、サイズ制限、メタデータ更新 |
| templates/perspective/generate-perspective.md | 79 | パースペクティブ自動生成指示。必須スキーマ、生成ガイドライン、user_requirements構成例 |
| templates/perspective/critic-effectiveness.md | 75 | パースペクティブ有効性批評指示。段階的分析プロセス(4ステップ)、寄与度分析、境界明確性検証 |
| templates/perspective/critic-completeness.md | 107 | パースペクティブ網羅性批評指示。欠落検出能力評価(最重要)、スコープカバレッジ評価、問題バンク品質評価、Missing Element Detection Evaluation テーブル |
| templates/perspective/critic-clarity.md | 76 | パースペクティブ明確性批評指示。表現の曖昧性検証、AI動作一貫性テスト、実行可能性確認 |
| templates/perspective/critic-generality.md | 82 | パースペクティブ汎用性批評指示。業界依存性フィルタ、評価マトリクス(業界適用性/規制依存/技術スタック)、一般化戦略 |
| perspectives/code/best-practices.md | 34 | コードレビュー用観点定義: ベストプラクティス。SOLID、エラー処理、ロギング、テスト、可読性、DRY |
| perspectives/code/consistency.md | 33 | コードレビュー用観点定義: 一貫性。スタイル、命名規約、エラー処理パターン、既存ユーティリティ活用 |
| perspectives/code/maintainability.md | 34 | コードレビュー用観点定義: 保守性。理解容易性、変更影響範囲、テスタビリティ、技術的負債、YAGNI |
| perspectives/code/security.md | 37 | コードレビュー用観点定義: セキュリティ。インジェクション、認証・セッション、機密データ、アクセス制御、依存関係 |
| perspectives/code/performance.md | 37 | コードレビュー用観点定義: パフォーマンス。クエリ効率、アルゴリズム効率、I/O・ネットワーク、メモリ管理、キャッシュ |
| perspectives/design/consistency.md | 51 | 設計レビュー用観点定義: 一貫性。命名規約、アーキテクチャパターン、実装パターン、ディレクトリ構造、API/依存関係の既存パターンとの一致。共通指針で支配的パターンの定義と一致判断基準を明示 |
| perspectives/design/security.md | 43 | 設計レビュー用観点定義: セキュリティ。脅威モデリング(STRIDE)、認証・認可設計、データ保護、入力検証、インフラ・依存関係・監査 |
| perspectives/design/structural-quality.md | 41 | 設計レビュー用観点定義: 構造的品質。SOLID・構造設計、変更容易性・モジュール設計、拡張性・運用設計、エラーハンドリング・オブザーバビリティ、テスト設計、API・データモデル品質 |
| perspectives/design/performance.md | 45 | 設計レビュー用観点定義: パフォーマンス。アルゴリズム・データ構造、I/O・ネットワーク、キャッシュ・メモリ管理、レイテンシ・スループット、スケーラビリティ |
| perspectives/design/reliability.md | 43 | 設計レビュー用観点定義: 信頼性・運用性。障害回復設計、データ整合性・べき等性、可用性・冗長性・災害復旧、監視・アラート設計、デプロイ・ロールバック |
| perspectives/design/old/best-practices.md | 34 | 旧版: 設計レビュー用観点定義: ベストプラクティス (使用停止、参考用アーカイブ) |
| perspectives/design/old/maintainability.md | 43 | 旧版: 設計レビュー用観点定義: 保守性 (使用停止、参考用アーカイブ) |

## B. ワークフロー概要
- **フェーズ構成**: Phase 0 → Phase 1A (初回) または Phase 1B (継続) → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 (Step 1: デプロイ、Step 2A: ナレッジ更新、Step 2B: スキル知見フィードバック、Step 2C: 次アクション選択)
- **Phase 0: 初期化・状態検出**
  - エージェントファイル読み込み、agent_name導出、perspective解決(検索→フォールバック→自動生成)、ディレクトリ作成、knowledge.md読み込みによる初回/継続判定
  - perspective自動生成の場合: 要件抽出 → 既存参照データ収集 → 初期生成(sonnet) → 4並列批評(effectiveness/completeness/clarity/generality, sonnet) → フィードバック統合・再生成(1回) → 検証
- **Phase 1A: 初回 — ベースライン作成 + バリアント生成**
  - proven-techniques.mdのベースライン構築ガイドに従う。ベースラインがなければ生成+デプロイ。構造分析→ギャップに基づく2バリアント生成
- **Phase 1B: 継続 — 知見ベースのバリアント生成**
  - BroadモードまたはDeepモードを選定。agent_audit結果を考慮。ベースラインコピー+2バリアント生成。アンチパターン回避
- **Phase 2: テスト入力文書生成 (毎ラウンド実行)**
  - 入力型判定→テスト対象文書生成(8-10問題埋め込み)→正解キー生成(検出判定基準○/△/×+ボーナス問題リスト)
- **Phase 3: 並列評価実行**
  - 各プロンプト×2回を並列実行(sonnet)。成功数を集計し、部分失敗時は再試行確認
- **Phase 4: 採点 (サブエージェントの並列実行)**
  - プロンプトごとに採点サブエージェント(sonnet)を並列起動。検出判定+ボーナス/ペナルティ→スコアサマリ返答
- **Phase 5: 分析・推奨判定・レポート作成**
  - 推奨判定(スコア差に基づく)+収束判定→7行サマリ(recommended, reason, convergence, scores, variants, deploy_info, user_summary)
- **Phase 6: プロンプト選択・デプロイ・次アクション**
  - Step 1: 性能推移テーブル提示+ユーザー選択+デプロイ(haiku)
  - Step 2A: ナレッジ更新(sonnet) — 累計ラウンド+1、効果テーブル更新、バリエーションステータス更新、ラウンド別スコア推移追記、改善のための考慮事項統合(preserve + integrate、20行上限)
  - Step 2B: スキル知見フィードバック(sonnet) — 昇格条件判定(Tier 1/2/3)、proven-techniques.md更新(preserve + integrate、サイズ制限: Section 1/2=8件、Section 3=7件)
  - Step 2C: 次アクション選択 — 次ラウンドまたは終了

- **データフロー**:
  - Phase 0 → `.agent_bench/{agent_name}/perspective-source.md`, `perspective.md`, `knowledge.md` (初回のみ生成)
  - Phase 1A/1B → `.agent_bench/{agent_name}/prompts/v{NNN}-baseline.md`, `v{NNN}-variant-*.md` (Benchmark Metadata含む)
  - Phase 2 → `.agent_bench/{agent_name}/test-document-round-{NNN}.md`, `answer-key-round-{NNN}.md`
  - Phase 3 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{1,2}.md` (各プロンプトの評価結果)
  - Phase 4 → `.agent_bench/{agent_name}/results/v{NNN}-{name}-scoring.md` (Phase 5のみ参照)
  - Phase 5 → `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`, 7行サマリ (Phase 6のみ参照)
  - Phase 6 Step 1 → `{agent_path}` (選択されたプロンプトをデプロイ)
  - Phase 6 Step 2A → `knowledge.md` 更新
  - Phase 6 Step 2B → `proven-techniques.md` 更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 66 | `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` | perspective フォールバック検索 (agent_bench_new 配下なので外部ではない) |
| SKILL.md | 86 | `.claude/skills/agent_bench_new/perspectives/design/*.md` | 既存 perspective 参照データ収集 (agent_bench_new 配下なので外部ではない) |
| templates/phase1b-variant-generation.md | 8 | `.agent_audit/{agent_name}/audit-*.md` | agent_audit 連携: 基準有効性・スコープ整合性の改善推奨を考慮 |

**備考**: `.agent_audit/{agent_name}/` へのアクセス (Phase 1B) のみが外部参照。agent_audit スキルの成果物を読み込む。agent_bench_new 配下の perspectives/ と templates/ への参照は内部参照。

## D. コンテキスト予算分析
- **SKILL.md 行数**: 396行
- **テンプレートファイル数**: 13個 (phase1a/1b/2/4/5/6a/6b + perspective系5個 + knowledge-init)
- **テンプレートファイル平均行数**: 約48行 (13〜107行の範囲)
- **サブエージェント委譲**: あり
  - **委譲パターン**: 各Phase(1A/1B/2/4/5/6A/6B)の生成処理をサブエージェントに委譲。親は「テンプレートを読み込み、パス変数を渡す」指示のみ。サブエージェントが大量コンテンツを生成しファイルに保存。親への返答は最小限(1-7行サマリのみ)
  - **perspective 自動生成**: Phase 0 Step 3 で初期生成(sonnet, 1回) → Step 4 で4並列批評(sonnet, 4回) → Step 5 で再生成(1回のみ)
  - **Phase 4 並列採点**: プロンプトごとに1つの採点サブエージェント(sonnet)を並列起動。スコアサマリのみ返答
- **親コンテキストに保持される情報**:
  - agent_name, agent_path, perspective_source_path, perspective_path, cumulative_round, prompts_dir
  - Phase 5 の7行サマリ(recommended, reason, convergence, scores, variants, deploy_info, user_summary)
  - Phase 4 のスコアサマリ(各プロンプトのMean, SD, Run1/Run2の詳細)
  - 詳細な生成コンテンツ(プロンプト本文、テスト文書、正解キー、採点詳細、レポート本文)は親コンテキストに含めず、ファイル経由で受け渡し
- **3ホップパターンの有無**: なし
  - 親→サブエージェント→ファイル保存→次Phase読み込み のパターン。親が中継せず、サブエージェント間のデータ受け渡しはファイル経由

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 記載なし (必須確認) |
| Phase 0 Step 1 | AskUserQuestion | エージェント定義が不十分な場合のヒアリング(目的・役割、想定入出力、使用ツール・制約事項) | 記載なし |
| Phase 3 | AskUserQuestion | 一部プロンプトで評価が全失敗した場合の確認(再試行/除外/中断) | 記載なし |
| Phase 4 | AskUserQuestion | 一部プロンプトで採点が失敗した場合の確認(再試行/除外/中断) | 記載なし |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択(ベースライン/バリアント1/バリアント2) — 性能推移テーブル+推奨理由+収束判定を提示 | 記載なし |
| Phase 6 Step 2C | AskUserQuestion | 次アクション選択(次ラウンドへ/終了) — 収束判定・累計ラウンド数を考慮 | 記載なし |

**Fast mode への言及**: SKILL.md に "fastモードで中間確認をスキップ可能に" の記載があるが、具体的な実装(どの確認をスキップするか)は未定義

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - Phase 0: agent_path 読み込み失敗 → エラー出力して終了
  - Phase 0: perspective-source.md 不在 → フォールバック検索 → 自動生成
  - Phase 0: knowledge.md 不在 → 初期化して Phase 1A へ
  - Phase 0: knowledge.md 存在 → Phase 1B へ
  - Phase 0 perspective 自動生成 Step 6: 必須セクション欠如 → エラー出力して終了
  - Phase 1A: prompts_dir/v001-baseline.md 存在確認 → 既存の場合エラー出力して終了
  - Phase 1B: prompts_dir/v{NNN}-baseline.md 存在確認 → 既存の場合警告+スキップ
  - Phase 1B: agent_audit 結果 (Glob で `.agent_audit/{agent_name}/audit-*.md` 検索) → 見つからない場合は空文字列として渡す
- **サブエージェント失敗時**:
  - Phase 3 (並列評価): 全サブエージェント完了後、成功数を集計。成功数 < 総数 → (a) 各プロンプトに最低1回成功 → 警告+Phase 4へ、(b) いずれかで全失敗 → AskUserQuestion (再試行/除外/中断)
  - Phase 4 (並列採点): 全サブエージェント完了後、成功数を集計。一部失敗 → AskUserQuestion (再試行/除外/中断)
  - Phase 0 perspective 自動生成の再生成: 1回のみ
- **部分完了時**:
  - Phase 3: Run1のみ成功 → SD=N/A として Phase 4 へ進む
  - Phase 4: ベースライン採点が失敗した場合は中断 (ユーザー選択肢に含まれる)
- **入力バリデーション**:
  - Phase 0: エージェント定義ファイルが200文字未満/見出し2個以下/目的・入力・出力セクションなし → AskUserQuestion でヒアリング

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (perspective自動生成 Step 3) | sonnet | templates/perspective/generate-perspective.md | 4行 (観点/入力型/評価スコープ/問題バンク件数) | 1 |
| Phase 0 (perspective自動生成 Step 4) | sonnet | templates/perspective/critic-effectiveness.md | 不定 (批評結果を保存、返答は保存完了のみ) | 4並列 (effectiveness/completeness/clarity/generality) |
| Phase 0 (perspective自動生成 Step 4) | sonnet | templates/perspective/critic-completeness.md | 不定 (批評結果を保存、返答は保存完了のみ) | 同上 |
| Phase 0 (perspective自動生成 Step 4) | sonnet | templates/perspective/critic-clarity.md | 不定 (批評結果を保存、返答は保存完了のみ) | 同上 |
| Phase 0 (perspective自動生成 Step 4) | sonnet | templates/perspective/critic-generality.md | 不定 (批評結果を保存、返答は保存完了のみ) | 同上 |
| Phase 0 (perspective自動生成 Step 5) | sonnet | templates/perspective/generate-perspective.md (再生成) | 4行 | 1 (条件付き: 重大な問題または改善提案がある場合のみ) |
| Phase 0 (knowledge初期化) | sonnet | templates/knowledge-init-template.md | 1行 (knowledge.md 初期化完了 (バリエーション数: N)) | 1 (条件付き: knowledge.md 不在時のみ) |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 不定 (エージェント定義/構造分析結果/生成したバリアント) | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 不定 (選定プロセス/生成したバリアント) | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 不定 (テスト対象文書サマリ/埋め込み問題一覧/ボーナス問題リスト) | 1 |
| Phase 3 | sonnet | なし (直接指示: Read prompt → Read test_doc → Write result → 保存完了のみ返答) | 1行 (保存完了: {result_path}) | (ベースライン1 + バリアント数) × 2回 (全並列) |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行 ({prompt_name}: Mean={X.X}, SD={X.X} / Run1={X.X}(...), Run2={X.X}(...)) | プロンプトごとに1つ (全並列) |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行 (recommended/reason/convergence/scores/variants/deploy_info/user_summary) | 1 |
| Phase 6 Step 1 (デプロイ) | haiku | なし (直接指示: Read selected_prompt → メタデータ除去 → Write agent_path → デプロイ完了のみ返答) | 1行 (デプロイ完了: {agent_path}) | 1 (条件付き: ベースライン以外を選択した場合のみ) |
| Phase 6 Step 2A (ナレッジ更新) | sonnet | templates/phase6a-knowledge-update.md | 1行 (knowledge.md 更新完了 (累計ラウンド数: N)) | 1 |
| Phase 6 Step 2B (スキル知見フィードバック) | sonnet | templates/phase6b-proven-techniques-update.md | 1行 (proven-techniques.md 更新完了/更新なし) | 1 |
